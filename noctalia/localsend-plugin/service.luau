--!nonstrict
--[[
Agent service (entry "agent" of dani/localsend).

The only entry that touches the network or spawns a process. Bar widgets get
one VM per output, so anything shared has to live in the singleton service —
and a transfer MUST live here rather than in the panel, because
prepare-upload blocks until the person on the other end taps Accept. If the
panel owned that stream, closing the panel would kill the upload.

Publishes over noctalia.state (shared by all entries of this plugin):
  "staged"    array of {path, name, size, type, preview?} queued to send
  "devices"   array of {alias, fingerprint, ip, port, protocol, deviceType,
                        fav, online}
  "transfer"  {state, device, index, total, name, percent, speed, message}
              state: idle | prepare | uploading | done | error | cancelled
  "scanning"  true while a discovery sweep is in flight
  "error"     user-facing error string, nil when healthy

Listens on "command":
  {op="discover"}                    announce + collect replies
  {op="drop"}                        ripdrag target window -> stage what lands
  {op="pick", kind="files"|"folder"} zenity picker -> stage the selection
  {op="clip"}                        stage the clipboard as a text payload
  {op="unstage", index=n} {op="clear"}
  {op="send", fingerprint=fp, pin=?}
  {op="cancel"}
  {op="fav", fingerprint=fp, on=bool}
]]

local ALIAS = noctalia.getConfig("alias") or "noctalia"
local NU = noctalia.getConfig("nu_path")
local SOCAT = noctalia.getConfig("socat_path")
local CURL = noctalia.getConfig("curl_path")
local RIPDRAG = noctalia.getConfig("ripdrag_path")
local ZENITY = noctalia.getConfig("zenity_path")
local DISCOVER_MS = math.max(500, noctalia.getConfig("discover_ms") or 2000)
local CLEAR_AFTER = noctalia.getConfig("clear_after_send")
if CLEAR_AFTER == nil then
	CLEAR_AFTER = true
end

local PLUGIN = noctalia.pluginDir()
local SCRIPT = PLUGIN .. "/localsend.nu"

local dataDir = noctalia.pluginDataDir() or "/tmp/noctalia-localsend"
noctalia.mkdirAll(dataDir)
local FAV_PATH = dataDir .. "/favourites.json"
local FP_PATH = dataDir .. "/fingerprint"
local JOB_PATH = dataDir .. "/job.json"
local CANCEL_PATH = dataDir .. "/cancel.flag"

-- ══════════════════════════════════════════════════════════════ helpers ═══

-- Single-quote for /bin/sh. Every command here is assembled as a string and
-- run through sh -c, so anything that came from disk or the user is quoted.
local function shq(s)
	return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function trim(s)
	return noctalia.string.trim(s or "")
end

-- Stable identity across restarts. LocalSend derives this from the TLS cert;
-- a sender that runs no server just needs it to be unique and unchanging.
local function ensureFingerprint()
	local existing = noctalia.readFile(FP_PATH)
	if type(existing) == "string" and #trim(existing) >= 32 then
		return trim(existing)
	end
	math.randomseed(os.time() + math.floor(os.clock() * 1000000))
	local out = {}
	for i = 1, 64 do
		out[i] = string.format("%X", math.random(0, 15))
	end
	local fp = table.concat(out)
	noctalia.writeFile(FP_PATH, fp)
	return fp
end

local FINGERPRINT = ensureFingerprint()

-- ═══════════════════════════════════════════════════════════════ state ═══

local staged = {}
local discovered = {}
local favourites = {}
local transfer = { state = "idle" }
local sending = false

local function loadFavourites()
	local raw = noctalia.readFile(FAV_PATH)
	if type(raw) ~= "string" or trim(raw) == "" then
		return {}
	end
	local parsed = noctalia.json.decode(raw)
	return type(parsed) == "table" and parsed or {}
end

local function saveFavourites()
	local encoded = noctalia.json.encode(favourites, true)
	if encoded then
		noctalia.writeFile(FAV_PATH, encoded)
	end
end

-- Published device list: favourites first (kept even while offline, so a
-- phone that is asleep stays clickable), then everything else discovery saw.
local function publishDevices()
	local byFp, out = {}, {}
	for _, d in ipairs(discovered) do
		byFp[d.fingerprint] = d
	end
	for _, f in ipairs(favourites) do
		local live = byFp[f.fingerprint]
		local entry = {
			alias = (live and live.alias) or f.alias,
			fingerprint = f.fingerprint,
			-- Prefer the address discovery just saw: DHCP moves devices around.
			ip = (live and live.ip) or f.ip,
			port = (live and live.port) or f.port,
			protocol = (live and live.protocol) or f.protocol,
			deviceType = (live and live.deviceType) or f.deviceType,
			fav = true,
			online = live ~= nil,
		}
		out[#out + 1] = entry
		byFp[f.fingerprint] = nil
	end
	for _, d in ipairs(discovered) do
		if byFp[d.fingerprint] then
			out[#out + 1] = {
				alias = d.alias,
				fingerprint = d.fingerprint,
				ip = d.ip,
				port = d.port,
				protocol = d.protocol,
				deviceType = d.deviceType,
				fav = false,
				online = true,
			}
		end
	end
	noctalia.state.set("devices", out)
end

local function publishStaged()
	noctalia.state.set("staged", staged)
end

local function publishTransfer()
	noctalia.state.set("transfer", transfer)
end

-- ═══════════════════════════════════════════════════════════ discovery ═══

local scanning = false

local function discover()
	if scanning then
		return
	end
	scanning = true
	noctalia.state.set("scanning", true)

	local cmd = table.concat({
		shq(NU),
		"--no-config-file",
		shq(SCRIPT),
		"discover",
		"--socat",
		shq(SOCAT),
		"--alias",
		shq(ALIAS),
		"--fingerprint",
		shq(FINGERPRINT),
		"--window",
		tostring(DISCOVER_MS),
	}, " ")

	-- The script sleeps for the discovery window, so the timeout has to clear
	-- it with room for nu startup and socat teardown.
	local ok = noctalia.runAsync(cmd, function(res)
		scanning = false
		noctalia.state.set("scanning", false)
		if res.timedOut then
			noctalia.log("discover: timed out")
			noctalia.state.set("error", "discovery timed out")
			return
		end
		if res.exitCode ~= 0 then
			local hint = res.stderr:find("socat", 1, true) and " (is socat installed?)" or ""
			noctalia.log("discover: exit " .. res.exitCode .. ": " .. trim(res.stderr):sub(-300))
			noctalia.state.set("error", "discovery failed" .. hint .. "\n" .. res.stderr:sub(-300))
			return
		end
		local list = noctalia.json.decode(res.stdout)
		if type(list) ~= "table" then
			noctalia.log("discover: bad JSON: " .. res.stdout:sub(1, 200))
			noctalia.state.set("error", "bad JSON from discover")
			return
		end
		noctalia.state.set("error", nil)
		discovered = list
		noctalia.log("discover: found " .. #list .. " device(s)")
		if #list == 0 and res.stderr ~= "" then
			-- The helper's stderr line is already prefixed "discover: ".
			noctalia.log(trim(res.stderr):sub(1, 300))
		end
		publishDevices()
	end, DISCOVER_MS + 6000)

	if not ok then
		scanning = false
		noctalia.state.set("scanning", false)
	end
end

-- ═════════════════════════════════════════════════════════════ staging ═══

local function appendStaged(list)
	local seen = {}
	for _, f in ipairs(staged) do
		seen[f.path] = true
	end
	local added = 0
	for _, f in ipairs(list) do
		if type(f) == "table" and f.path and not seen[f.path] then
			staged[#staged + 1] = f
			seen[f.path] = true
			added += 1
		end
	end
	if added > 0 then
		publishStaged()
	end
	return added
end

-- ripdrag and zenity both print one path per line; localsend.nu expands those
-- into staged entries (recursing into directories, resolving sizes). The
-- whole thing is one sh command so noctalia only has to watch a single
-- stream, whose sole output line is the resulting JSON array.
local function stagePipeline(producer)
	local tmp = dataDir .. "/paths.txt"
	local cmd = table.concat({
		producer,
		" > ",
		shq(tmp),
		" 2>/dev/null; ",
		shq(NU),
		" --no-config-file ",
		shq(SCRIPT),
		" stage --from-file ",
		shq(tmp),
		"; rm -f ",
		shq(tmp),
	})
	local ok = noctalia.runStream(cmd, function(line)
		if trim(line) == "" then
			return
		end
		local list = noctalia.json.decode(line)
		if type(list) ~= "table" then
			return
		end
		local n = appendStaged(list)
		noctalia.log("stage: added " .. n .. " of " .. #list .. " (staged now " .. #staged .. ")")
		if n > 0 then
			noctalia.notify("LocalSend", n .. (n == 1 and " file staged" or " files staged"))
		end
	end)
	if not ok then
		noctalia.notifyError("LocalSend", "could not start the picker (too many running commands)")
	end
end

local function dropWindow()
	if not noctalia.commandExists(RIPDRAG) then
		noctalia.notifyError("LocalSend", "ripdrag is not installed — add it to home.packages")
		return
	end
	-- Target mode prints each dropped path and exits on the first drop.
	stagePipeline(shq(RIPDRAG) .. " --target --and-exit --resizable -W 420 -H 220")
end

local function pick(kind)
	if not noctalia.commandExists(ZENITY) then
		noctalia.notifyError("LocalSend", "zenity is not installed — add it to home.packages")
		return
	end
	local args = "--file-selection --separator='\\n' --title='LocalSend: choose files'"
	if kind == "folder" then
		args = "--file-selection --directory --separator='\\n' --title='LocalSend: choose a folder'"
	else
		args = args .. " --multiple"
	end
	stagePipeline(shq(ZENITY) .. " " .. args)
end

-- Clipboard text becomes a real file on disk (the protocol uploads bytes),
-- with `preview` carrying the text so the receiver shows it as a message.
local function stageClipboard()
	local text = noctalia.clipboardText()
	if type(text) ~= "string" or trim(text) == "" then
		noctalia.notifyError("LocalSend", "clipboard is empty")
		return
	end
	local path = dataDir .. "/clipboard-" .. tostring(os.time()) .. ".txt"
	local ok, err = noctalia.writeFile(path, text)
	if not ok then
		noctalia.notifyError("LocalSend", "could not stage clipboard: " .. tostring(err))
		return
	end
	appendStaged({
		{
			path = path,
			name = "message.txt",
			size = #text,
			type = "text/plain",
			preview = text:sub(1, 1000),
		},
	})
	noctalia.notify("LocalSend", "clipboard staged (" .. #text .. " chars)")
end

-- ═══════════════════════════════════════════════════════════ transfers ═══

local function deviceByFingerprint(fp)
	for _, d in ipairs(discovered) do
		if d.fingerprint == fp then
			return d
		end
	end
	for _, f in ipairs(favourites) do
		if f.fingerprint == fp then
			return f
		end
	end
	return nil
end

local function finishTransfer(state, message)
	sending = false
	transfer = { state = state, message = message, device = transfer.device }
	publishTransfer()
end

local function handleEvent(ev)
	if ev.event == "prepare" then
		transfer = { state = "prepare", device = ev.device, total = ev.files, percent = 0 }
		publishTransfer()
	elseif ev.event == "accepted" then
		transfer.state = "uploading"
		transfer.session = ev.session
		publishTransfer()
	elseif ev.event == "file" then
		transfer.state = "uploading"
		transfer.index = ev.index
		transfer.name = ev.name
		transfer.size = ev.size
		transfer.total = ev.total
		transfer.percent = 0
		transfer.speed = ""
		publishTransfer()
	elseif ev.event == "progress" then
		transfer.percent = ev.percent
		transfer.speed = ev.speed
		publishTransfer()
	elseif ev.event == "file_done" then
		transfer.percent = 100
		publishTransfer()
	elseif ev.event == "skipped" then
		noctalia.notify("LocalSend", "skipped " .. tostring(ev.name) .. " (" .. tostring(ev.reason) .. ")")
	elseif ev.event == "done" then
		noctalia.notify("LocalSend", "sent " .. tostring(ev.sent) .. " to " .. tostring(transfer.device))
		if CLEAR_AFTER then
			staged = {}
			publishStaged()
		end
		finishTransfer("done", "sent " .. tostring(ev.sent))
	elseif ev.event == "cancelled" then
		noctalia.notify("LocalSend", "transfer cancelled")
		finishTransfer("cancelled", "cancelled")
	elseif ev.event == "error" then
		local msg = tostring(ev.message or "failed")
		-- A PIN prompt is a state the panel can act on, not a dead end.
		if ev.code == 401 then
			transfer = { state = "error", device = transfer.device, message = msg, needsPin = true }
			sending = false
			publishTransfer()
		else
			noctalia.notifyError("LocalSend", msg)
			finishTransfer("error", msg)
		end
	end
end

local function send(fingerprint, pin)
	if sending then
		return
	end
	if #staged == 0 then
		noctalia.notifyError("LocalSend", "nothing staged to send")
		return
	end
	local dev = deviceByFingerprint(fingerprint)
	if not dev then
		noctalia.log("send: unknown fingerprint " .. tostring(fingerprint) .. " (" .. #discovered .. " discovered)")
		noctalia.notifyError("LocalSend", "device is no longer visible — rescan")
		return
	end
	noctalia.log("send: " .. #staged .. " file(s) to " .. tostring(dev.alias) .. " at " .. tostring(dev.ip))

	local job = {
		device = { ip = dev.ip, port = dev.port, protocol = dev.protocol, alias = dev.alias },
		pin = pin,
		alias = ALIAS,
		fingerprint = FINGERPRINT,
		files = staged,
	}
	local encoded, encErr = noctalia.json.encode(job)
	if not encoded then
		noctalia.notifyError("LocalSend", "could not build job: " .. tostring(encErr))
		return
	end
	local ok, writeErr = noctalia.writeFile(JOB_PATH, encoded)
	if not ok then
		noctalia.notifyError("LocalSend", "could not write job: " .. tostring(writeErr))
		return
	end
	noctalia.removeFile(CANCEL_PATH)

	sending = true
	transfer = { state = "prepare", device = dev.alias, percent = 0 }
	publishTransfer()

	local cmd = table.concat({
		shq(NU),
		"--no-config-file",
		shq(SCRIPT),
		"send",
		shq(JOB_PATH),
		"--curl",
		shq(CURL),
		"--cancel-file",
		shq(CANCEL_PATH),
	}, " ")

	local started = noctalia.runStream(cmd, function(line)
		if trim(line) == "" then
			return
		end
		local ev = noctalia.json.decode(line)
		if type(ev) == "table" and ev.event then
			if ev.event == "error" or ev.event == "done" or ev.event == "cancelled" then
				noctalia.log("send: " .. line:sub(1, 300))
			end
			handleEvent(ev)
		else
			-- nu itself failed (bad path, syntax error): its stderr is not a
			-- JSON event, and silently dropping it is how this gets mystifying.
			noctalia.log("send: non-event output: " .. line:sub(1, 300))
		end
	end)
	if not started then
		finishTransfer("error", "could not start the transfer")
		noctalia.notifyError("LocalSend", "could not start the transfer")
	end
end

-- ════════════════════════════════════════════════════════════ commands ═══

local function toggleFavourite(fingerprint, on)
	local kept = {}
	for _, f in ipairs(favourites) do
		if f.fingerprint ~= fingerprint then
			kept[#kept + 1] = f
		end
	end
	if on then
		local d = deviceByFingerprint(fingerprint)
		if d then
			kept[#kept + 1] = {
				fingerprint = d.fingerprint,
				alias = d.alias,
				ip = d.ip,
				port = d.port,
				protocol = d.protocol,
				deviceType = d.deviceType,
			}
		end
	end
	favourites = kept
	saveFavourites()
	publishDevices()
end

noctalia.state.watch("command", function(cmd)
	if type(cmd) ~= "table" then
		return
	end
	local op = cmd.op
	if op == "discover" then
		discover()
	elseif op == "drop" then
		dropWindow()
	elseif op == "pick" then
		pick(cmd.kind)
	elseif op == "clip" then
		stageClipboard()
	elseif op == "unstage" then
		local idx = tonumber(cmd.index)
		if idx and staged[idx] then
			table.remove(staged, idx)
			publishStaged()
		end
	elseif op == "clear" then
		staged = {}
		publishStaged()
	elseif op == "send" then
		send(cmd.fingerprint, cmd.pin)
	elseif op == "cancel" then
		noctalia.writeFile(CANCEL_PATH, "1")
	elseif op == "dismiss" then
		if not sending then
			transfer = { state = "idle" }
			publishTransfer()
		end
	elseif op == "fav" then
		toggleFavourite(cmd.fingerprint, cmd.on == true)
	end
end)

-- ══════════════════════════════════════════════════════════════ startup ═══

favourites = loadFavourites()
staged = {}
publishStaged()
publishTransfer()
publishDevices()
discover()

-- No periodic poll: discovery is an active announce/reply round trip that
-- takes ~1s, so the panel asks for a fresh sweep when it opens rather than
-- keeping a background timer running for a list nobody is looking at.
-- Scripting surface. The service is the entry that is always running, so
-- these work whether or not the panel has ever been opened:
--   noctalia msg plugin dani/localsend:agent all discover ""
--   noctalia msg plugin dani/localsend:agent all stage /path/to/file
--   noctalia msg plugin dani/localsend:agent all send <fingerprint>
--   noctalia msg plugin dani/localsend:agent all drop|clip|cancel ""
function onIpc(event, payload)
	if event == "discover" then
		discover()
	elseif event == "drop" then
		dropWindow()
	elseif event == "clip" then
		stageClipboard()
	elseif event == "cancel" then
		noctalia.writeFile(CANCEL_PATH, "1")
	elseif event == "clear" then
		staged = {}
		publishStaged()
	elseif event == "send" and payload and payload ~= "" then
		send(payload, nil)
	elseif event == "stage" and payload and payload ~= "" then
		local cmd = table.concat({
			shq(NU),
			"--no-config-file",
			shq(SCRIPT),
			"stage",
			shq(payload),
		}, " ")
		local ok = noctalia.runStream(cmd, function(line)
			if trim(line) == "" then
				return
			end
			local list = noctalia.json.decode(line)
			if type(list) == "table" then
				local n = appendStaged(list)
				noctalia.log("stage(ipc): added " .. n .. " (staged now " .. #staged .. ")")
			else
				noctalia.log("stage(ipc): bad JSON: " .. line:sub(1, 200))
			end
		end)
		if not ok then
			noctalia.log("stage(ipc): could not start nu")
		end
	end
end
