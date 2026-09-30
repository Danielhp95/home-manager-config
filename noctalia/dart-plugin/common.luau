--!nonstrict
--[[
Helpers shared by the dani/dart entries (`require("./common.luau")`, plugin API
22). require caches per entry, so each entry gets its own copy: nothing here is
shared state, and the entries still talk only over noctalia.state.
]]

local M = {}

-- Run details page: the panel's open button, its context menu and the toasts.
M.DETAILS_URL = "https://dart.platform.research.sony/en/details/"

-- A run id becomes a URL path segment, so anything that is not
-- alphanumeric-with-dashes is refused rather than opened.
function M.validRunId(id)
	return type(id) == "string" and id:match("^[%w%-]+$") ~= nil
end

-- Ask service.luau for a re-poll. The nonce makes every set() distinct so the
-- state watcher always fires.
function M.requestRefresh()
	noctalia.state.set("command", { op = "refresh", nonce = os.clock() })
end

-- Split text into words like /bin/sh minus every expansion: blanks separate
-- words, '...' is literal, "..." honours only \" \\ \$ \`, a bare backslash
-- escapes the next character, adjacent segments join (a'b'"c" -> abc). Returns
-- nil plus a message on an unterminated quote. No shell ever sees the text.
function M.splitWords(text)
	local words, cur, inWord = {}, {}, false
	local i, n = 1, #text
	while i <= n do
		local c = text:sub(i, i)
		if c == "'" then
			local close = text:find("'", i + 1, true)
			if not close then
				return nil, "unterminated ' quote"
			end
			cur[#cur + 1] = text:sub(i + 1, close - 1)
			inWord, i = true, close + 1
		elseif c == '"' then
			i += 1
			while true do
				if i > n then
					return nil, 'unterminated " quote'
				end
				local d = text:sub(i, i)
				if d == '"' then
					break
				elseif d == "\\" and i < n and text:sub(i + 1, i + 1):match('["\\$`]') then
					cur[#cur + 1] = text:sub(i + 1, i + 1)
					i += 2
				else
					cur[#cur + 1] = d
					i += 1
				end
			end
			inWord, i = true, i + 1
		elseif c == "\\" and i < n then
			cur[#cur + 1] = text:sub(i + 1, i + 1)
			inWord, i = true, i + 2
		elseif c:match("%s") then
			if inWord then
				words[#words + 1] = table.concat(cur)
				cur, inWord = {}, false
			end
			i += 1
		else
			cur[#cur + 1] = c
			inWord, i = true, i + 1
		end
	end
	if inWord then
		words[#words + 1] = table.concat(cur)
	end
	return words
end

-- The inverse of splitWords for a single word: POSIX single quotes, with an
-- embedded ' written as '\''. splitWords(quoteWord(s)) == { s } for any s.
function M.quoteWord(s)
	-- Called per rendered tag chip: gsub (~25 us vs ~0.3 us for a concat) would
	-- blow the 25 ms render budget across 100 cards, and most tags hold no quote.
	if not s:find("'", 1, true) then
		return "'" .. s .. "'"
	end
	return "'" .. (s:gsub("'", "'\\''")) .. "'"
end

-- Prefix for spawns that must outlive noctalia: a runAsync child lives in
-- noctalia.service's cgroup and dies with it; a transient scope avoids that.
M.DETACH = { "systemd-run", "--user", "--scope", "--quiet", "--collect", "--" }

-- argv that opens `url` in $BROWSER, which may carry its own arguments
-- ("firefox --new-window"), falling back to xdg-open.
function M.browserArgv(url)
	local words = M.splitWords(noctalia.getenv("BROWSER") or "")
	if not words or #words == 0 then
		words = { "xdg-open" }
	end
	local argv = table.clone(M.DETACH)
	for _, word in ipairs(words) do
		argv[#argv + 1] = word
	end
	argv[#argv + 1] = url
	return argv
end

return M
