-- user@host in the header (left of cwd)
Header:children_add(function()
	if ya.target_family() ~= "unix" then
		return ""
	end
	return ui.Span(ya.user_name() .. "@" .. ya.host_name() .. ":"):fg("blue")
end, 500, Header.LEFT)

-- hovered file name (+ symlink target) in the status bar
Status:children_add(function(self)
	local h = self._current.hovered
	if not h then
		return ""
	end

	local linked = ""
	if h.link_to ~= nil then
		linked = " -> " .. tostring(h.link_to)
	end
	return ui.Span(" " .. h.name .. linked)
end, 3300, Status.LEFT)

-- owner:group in the status bar
Status:children_add(function()
	local h = cx.active.current.hovered
	if h == nil or ya.target_family() ~= "unix" then
		return ""
	end

	return ui.Line({
		ui.Span(ya.user_name(h.cha.uid) or tostring(h.cha.uid)):fg("magenta"),
		":",
		ui.Span(ya.group_name(h.cha.gid) or tostring(h.cha.gid)):fg("magenta"),
		" ",
	})
end, 500, Status.RIGHT)

-- rounded borders around all panes
require("full-border"):setup({ type = ui.Border.ROUNDED })

-- git status signs in the file list (fetchers registered in yazi.toml)
require("git"):setup()

-- bookmarks
require("yamb"):setup({
	bookmarks = {},
	jump_notify = true,
	cli = "fzf",
	keys = "asdfghjklqwertyuiopzxcvbnm",
	path = os.getenv("HOME") .. "/.config/yazi/bookmark",
})

-- keep zoxide db in sync while browsing (z / Z builtin jumps)
require("zoxide"):setup({ update_db = true })
