--!nonstrict
--[[
Helpers shared by the dani/dart entries, loaded with
`require("./common.luau")` (plugin API 22).

require caches per entry, so the widget, panel and service each get their own
copy of this table: nothing here is shared state. The entries still talk to
each other only over noctalia.state.
]]

local M = {}

-- Run details page. The panel's open button, its context menu and the service's
-- transition toasts all land here.
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

-- Split text into words the way /bin/sh would, minus every expansion: blanks
-- separate words, '...' is literal, "..." is literal except for \" \\ \$ \`,
-- and a backslash outside quotes escapes the next character. Adjacent quoted
-- and bare segments join into one word (a'b'"c" -> abc). Returns nil plus a
-- message on an unterminated quote.
--
-- This is what lets the free-form filter bar and $BROWSER go out as argv
-- spawns (plugin API 24): the text is tokenized here instead of by a shell, so
-- $(...), ; and | are just characters inside an argument.
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
	-- The panel quotes one tag per rendered chip, and gsub measured ~25 us per
	-- call against ~0.3 us for a plain concat - enough across 100 cards to blow
	-- the 25 ms render budget. Most tags hold no quote, so skip it for those.
	if not s:find("'", 1, true) then
		return "'" .. s .. "'"
	end
	return "'" .. (s:gsub("'", "'\\''")) .. "'"
end

-- argv that opens `url` in $BROWSER, which may carry its own arguments
-- ("firefox --new-window"), falling back to xdg-open.
function M.browserArgv(url)
	local argv = M.splitWords(noctalia.getenv("BROWSER") or "")
	if not argv or #argv == 0 then
		argv = { "xdg-open" }
	end
	argv[#argv + 1] = url
	return argv
end

return M
