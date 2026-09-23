--!strict
--[[
Type definitions for the noctalia v5 Luau plugin API.

noctalia injects these globals into every plugin entry VM; without this file
luau-lsp reports every one as an unknown global. Loaded into the global
namespace via `luau-lsp lsp --definitions=` (see
danvim/lua/danvim/plugins/lsp.lua).

Hand-written from the C++ bindings, since noctalia ships no definitions:
  src/scripting/luau_host.cpp        noctalia.*
  src/scripting/plugin_bindings.cpp  barWidget.* panel.* shortcut.* launcher.* desktopWidget.*
  src/scripting/ui_prelude.h         ui.*
  src/ui/ui_tree_reconciler.cpp      per-control props and callback props
  src/shell/**/plugin_*.cpp          the hooks noctalia calls back into
  docs/plugin-api.json               which plugin_api level introduced what
Last checked against noctalia d6607b4 (2026-09-08, plugin API 30). Re-check
after a version bump; a stale entry here type-checks clean and then fails at
runtime.

All the globals are registered for every entry kind, so they are all declared
unconditionally here. Availability is by effect, not existence: calling
barWidget.* from a service entry type-checks and silently does nothing.
]]

-- ## noctalia.* payloads

-- Callback arg of noctalia.runAsync. stdout/stderr are truncated at 1 MiB, with
-- the matching *Truncated flag set.
export type RunResult = {
	exitCode: number,
	stdout: string,
	stderr: string,
	timedOut: boolean,
	stdoutTruncated: boolean,
	stderrTruncated: boolean,
}

export type FileInfo = {
	size: number,
	mtime: number, -- unix seconds
	isDir: boolean,
}

export type OutputInfo = {
	name: string, -- connector, e.g. "eDP-1"
	description: string,
	width: number,
	height: number,
	x: number,
	y: number,
	scale: number,
	focused: boolean,
}

-- NB: snake_case keys, and `headers` is an array of raw "Name: value" strings
-- rather than a map. method defaults to "GET", follow_redirects to false.
export type HttpRequest = {
	url: string,
	method: string?,
	body: string?,
	basic_username: string?,
	basic_password: string?,
	follow_redirects: boolean?,
	-- Skips certificate-chain and hostname checks, redirects included (API 7).
	allow_insecure_tls: boolean?,
	headers: { string }?,
}

export type HttpResponse = {
	ok: boolean, -- transport-level success; check `status` for HTTP errors
	status: number,
	body: string,
}

-- noctalia.httpStream's onClose payload. Non-2xx is not special-cased: a
-- rejected token arrives as ok = true, status = 401.
export type HttpStreamClose = {
	ok: boolean,
	status: number,
}

export type HttpStreamHandle = {
	-- Cancel; idempotent, and suppresses onClose.
	stop: () -> (),
}

-- noctalia.systemStats() snapshot. Absent probes are nil, never 0, so "no
-- sensor" and "idle" stay distinguishable.
export type SystemStats = {
	sampledAtMs: number?, -- API 16
	cpu: { usagePercent: number, tempC: number?, freqMhz: number?, maxFreqMhz: number? },
	ram: { usagePercent: number, usedMb: number, totalMb: number },
	swap: { usedMb: number, totalMb: number },
	gpu: { tempC: number?, usagePercent: number?, vramUsedBytes: number?, vramTotalBytes: number? },
	-- `interfaces` (API 16) holds per-interface rates keyed by interface name.
	net: { rxBytesPerSec: number, txBytesPerSec: number, interfaces: { [string]: any }? },
	loadAvg: { number }, -- 1, 5 and 15 minute
}

export type DiskMount = {
	path: string,
	source: string,
	filesystem: string,
}

export type DiskStats = {
	usagePercent: number,
	totalBytes: number,
	freeBytes: number,
	availableBytes: number,
}

-- noctalia.setWallpaperMask payload. `wallpaperPath` must equal
-- noctalia.wallpaperPath(connector) exactly, or the mask is rejected.
export type WallpaperMask = {
	path: string,
	wallpaperPath: string,
}

-- barWidget.setTooltip row. The `key`/`value` fields win; the positional form
-- ({ "left", "right" }) is the fallback when they are empty.
export type TooltipRow = {
	key: string?,
	value: string?,
	[number]: string,
}

-- ## noctalia.* sub-tables

-- Cross-VM state bus, JSON-encoded under the hood: a plugin's entries share one
-- namespace, so the service publishes and the widget/panel watch. Values must
-- be JSON-representable (tables with non-string keys are dropped, depth cap 32).
-- In-memory only: it survives a service restart but not a plugin stop.
export type NoctaliaState = {
	set: (key: string, value: any) -> (),
	get: (key: string) -> any,
	-- Fires on every subsequent set of `key`, including from another entry's VM.
	watch: (key: string, callback: (value: any) -> ()) -> (),
}

export type NoctaliaJson = {
	-- Returns (nil, errorMessage) on malformed input.
	decode: (text: string) -> (any, string?),
	encode: (value: any, pretty: boolean?) -> (string?, string?),
}

export type NoctaliaString = {
	trim: (s: string) -> string,
	urlEncode: (s: string) -> string,
	urlDecode: (s: string) -> string,
}

-- Plugin audio (API 20). Names are scoped to the runtime and released on reload.
export type NoctaliaSound = {
	-- Async decode. true means accepted, not decoded: onLoaded reports that.
	-- At most 8 loads pending per runtime; a name already pending returns false.
	load: (name: string, path: string, onLoaded: (ok: boolean, err: string?) -> ()) -> boolean,
	-- Honors [audio].enable_sounds / sound_volume; a sound still playing is not restarted.
	play: (name: string) -> (),
}

--[[
The core API, available in every entry.

Filesystem paths resolve as: "~" -> $HOME, "/..." -> absolute, anything else ->
relative to the plugin directory. Nothing is sandboxed.

The fs and json calls follow a two-return error convention -- (value, nil) on
success, (nil/false, errorMessage) on failure -- rather than raising.

The async calls (runAsync, runStream, readFileAsync, http, httpStream, download,
processMatches, openColorPicker, sound.load) return false (httpStream: nil) when
a concurrency cap is hit, so a plugin under load can see them refuse to start;
they do not queue.
]]
declare noctalia: {
	log: (msg: string) -> (),

	-- ### Processes
	-- A string runs through /bin/sh -c. An argv table (API 24) is execvp'd
	-- directly: PATH lookup, no shell parsing, every element one argument --
	-- prefer it whenever a setting, path, URL or user input is involved.
	-- Detached when `callback` is omitted (no capture, no slot, no timeout).
	-- timeoutMs defaults to 5000 and is clamped to [50, 60000]. Returns false
	-- if the cap (8 per VM) is hit.
	runAsync: (cmd: string | { string }, callback: ((result: RunResult) -> ())?, timeoutMs: number?) -> boolean,
	-- Shell string only; there is no argv form. The callback fires per stdout
	-- line as it arrives; streams die with the runtime.
	runStream: (cmd: string, callback: (line: string) -> ()) -> boolean,
	-- $TERMINAL (without -e in the value), else a terminal found on PATH.
	runInTerminal: (cmd: string) -> boolean,
	commandExists: (name: string) -> boolean,
	-- NOTE: callback FIRST, then the process names -- inverted vs every other
	-- async call here. `matched` is true if any needle matches a running process.
	processMatches: (callback: (matched: boolean) -> (), ...string) -> boolean,
	flatpakAppInstalled: (appId: string) -> boolean,
	portalAvailable: () -> boolean,

	-- ### System stats (API 12; disks, sampledAtMs and net.interfaces API 16)
	-- nil when [system.monitor] is disabled. The first call opts the plugin into
	-- the CPU-temperature and GPU probes; values refresh on the monitor's poll
	-- intervals, not per call.
	systemStats: () -> SystemStats?,
	-- Per-core usage %, /proc/stat order. nil until two samples exist (~1 s);
	-- the first call opts into per-core sampling for the plugin's lifetime.
	cpuCores: () -> { number }?,
	diskMounts: () -> { DiskMount },
	-- Absolute or "~/" path (anything else raises); nil when unavailable.
	diskStats: (path: string) -> DiskStats?,
	-- Wall-clock ms since the epoch: the only sub-second clock available.
	nowMs: () -> number,

	-- ### Outputs / wallpaper
	focusedOutputName: () -> string?,
	outputs: () -> { OutputInfo },
	-- sizePx defaults to 0 (largest available).
	appIconPath: (appIdOrIconName: string, sizePx: number?) -> string?,
	setWallpaperEnabled: (connector: string, enabled: boolean) -> (),
	-- One arg sets every output; two targets a single connector.
	setWallpaper: (pathOrConnector: string, path: string?) -> (),
	wallpaperDirectory: () -> string?,
	-- Exact configured wallpaper source for a connector (API 25).
	wallpaperPath: (connector: string) -> string?,
	-- Source-aligned desktop-widget occlusion mask; nil clears this runtime's
	-- mask on that output (API 25).
	setWallpaperMask: (connector: string, mask: WallpaperMask?) -> (),
	isDarkMode: () -> boolean,

	-- ### Shell
	-- panelId is fully qualified, e.g. "dani/dart:panel".
	togglePanel: (panelId: string) -> (),
	-- Settings window at this plugin's own page; no id, so a plugin can only
	-- open itself (API 15).
	openSettings: () -> (),
	-- No actions: a plugin cannot make these toasts clickable.
	notify: (title: string, body: string?) -> (),
	notifyError: (title: string, body: string?) -> (),
	copyToClipboard: (text: string, mimeType: string) -> boolean,
	clipboardText: () -> string?,
	-- Raises on a hex that is not exactly "#RRGGBB". The callback gets nil if
	-- the user cancels. Only one picker may be pending per entry.
	openColorPicker: (hex: string, callback: (color: string?) -> ()) -> boolean,
	-- Clamped to a 16 ms floor; drives the `update` hook.
	setUpdateInterval: (ms: number) -> (),
	-- Value of a plugin.toml [[setting]] key, nil (plus a logged warning) if the
	-- key is undeclared. Typed `any` deliberately: the value's type is
	-- whatever `type =` the key declares in plugin.toml, which is out of reach
	-- here, so a union would just force a cast at every call site.
	getConfig: (key: string) -> any,
	-- Any effective SHELL config value by TOML dotted path, e.g.
	-- "shell.offline_mode" or "bar.order[0]" (indices zero-based). Tables and
	-- arrays come back as Luau tables; nil (plus a warning) when nothing
	-- matches. API 26.
	getSetting: (path: string) -> any,

	-- ### Environment / time
	getenv: (name: string) -> string?,
	expandPath: (path: string) -> string,
	-- Same tokens as the clock settings, e.g. "{:%H:%M}"; "%s" is epoch
	-- seconds. unixSeconds defaults to now. `timezone` (API 19) is an IANA name
	-- such as "Europe/Berlin"; an unknown one silently falls back to local
	-- time, so check isValidTimezone when that matters.
	formatTime: (pattern: string, unixSeconds: number?, timezone: string?) -> string,
	-- [shell].time_format / date_format, with the host defaults (API 19).
	timeFormat: () -> string,
	dateFormat: () -> string,
	-- True for "" (system local) or a known IANA zone (API 19).
	isValidTimezone: (name: string) -> boolean,

	-- ### Filesystem
	readFile: (path: string) -> (string?, string?),
	-- Off-VM read for sysfs/procfs and other files that may block (API 23):
	-- 4 MiB cap, at most 4 outstanding per runtime, late completions dropped on
	-- reload. The callback gets (contents, nil) or (nil, err).
	readFileAsync: (path: string, callback: (contents: string?, err: string?) -> ()) -> boolean,
	writeFile: (path: string, data: string) -> (boolean, string?),
	removeFile: (path: string) -> (boolean, string?),
	renameFile: (from: string, to: string) -> (boolean, string?),
	fileExists: (path: string) -> boolean,
	fileInfo: (path: string) -> (FileInfo?, string?),
	listDir: (path: string) -> ({ string }?, string?),
	mkdirAll: (path: string) -> (boolean, string?),
	-- Not optional in practice: the binding only yields nil when the VM has no
	-- host attached, which cannot happen from inside a plugin. Typing it
	-- `string?` would force an `or ""` on every concat for an unreachable nil.
	pluginDir: () -> string,
	-- Persistent per-plugin directory, created on demand; survives updates,
	-- unlike pluginDir() for git-installed plugins.
	pluginDataDir: () -> (string?, string?),
	-- Returns the font family name to pass to setFont / the fontFamily prop.
	loadFont: (path: string) -> (string?, string?),

	-- ### i18n (translations/*.json)
	tr: (key: string, subst: { [string]: any }?) -> string,
	-- Plural form: picks "<key>.one" or "<key>.other" and injects subst.count.
	trp: (key: string, count: number, subst: { [string]: any }?) -> string,

	-- ### Network
	http: (request: HttpRequest, callback: (response: HttpResponse) -> ()) -> boolean,
	-- Long-lived line stream, e.g. server-sent events (API 4). nil when it could
	-- not start. No transfer timeout; reconnecting after onClose is on the caller.
	httpStream: (
		request: HttpRequest,
		onLine: (line: string) -> (),
		onClose: (result: HttpStreamClose) -> ()
	) -> HttpStreamHandle?,
	download: (url: string, destPath: string, callback: (ok: boolean) -> ()) -> boolean,

	-- Fuzzy match score, or nil when the pattern does not match.
	fuzzyScore: (pattern: string, text: string) -> number?,

	state: NoctaliaState,
	json: NoctaliaJson,
	string: NoctaliaString,
	sound: NoctaliaSound,
}

-- ## Bar widget entry ([[widget]])

--[[
A bar widget gets one VM per output, so anything shared (polling, caching)
belongs in a service entry published over noctalia.state instead.

`role` accepts a palette role ("primary", "on_surface", "error", ... -- see the
ColorRole list in palette.h) or a "#rrggbb"/"#rrggbbaa" literal. Unlike the ui
color props, the "role/alpha" suffix form is NOT accepted here.

`mode` is "auto" (default: an on_surface role yields to the user's per-widget
color setting) or "script" (the plugin's choice always wins).
]]
declare barWidget: {
	setText: (text: string) -> (),
	-- Clears any image.
	setGlyph: (name: string) -> (),
	-- Clears any glyph. `watch` hot-reloads the file on change. Passing only
	-- `width` sets both dimensions; `height` overrides it.
	setImage: (path: string, watch: boolean?, width: number?, height: number?) -> (),
	-- A plain string, one row, or a list of rows. nil/""/{} clears it.
	setTooltip: (tooltip: (string | TooltipRow | { TooltipRow })?) -> (),
	clearTooltip: () -> (),
	-- baseline: "text" | "textFixedHeight" | "inkCentered" | "pictographic"
	setFont: (family: string, baseline: string?) -> (),
	setColor: (role: string, mode: string?) -> (),
	setGlyphColor: (role: string, mode: string?) -> (),
	-- True on a left/right-edge bar, where a wide widget should go vertical.
	isVertical: () -> boolean,
	outputName: () -> string?,
	setVisible: (visible: boolean) -> (),
	-- Declarative alternative to the setters above; once called, the tree
	-- replaces the built-in glyph/text row. See `ui`.
	render: (tree: UiNode) -> (),
}

-- ## Panel entry ([[panel]])

-- One item of a panel.openContextMenu request. `kind` defaults to "item" and
-- `enabled` to true; action ids must be unique.
export type ContextMenuItem = {
	kind: string?, -- "item" | "header" | "separator"
	id: string?,
	label: string?,
	enabled: boolean?,
}

export type ContextMenuRequest = {
	-- 1..64 items, at least one of them an enabled action.
	items: { ContextMenuItem },
	-- Global callback NAME, not a closure: onActivate(actionId, context).
	onActivate: string,
	-- Scalar handed back as onActivate's second argument.
	context: (string | number | boolean)?,
	maxVisible: number?, -- 1..30, default 12; longer menus scroll
}

declare panel: {
	render: (tree: UiNode) -> (),
	-- Closing in the same callback that opens a context menu discards the menu.
	close: () -> (),
	-- Native menu at the pointer (API 28). Only works from inside a ui.button's
	-- onRightClick callback, which is what holds a live pointer serial; anywhere
	-- else it returns false. Invalid requests raise.
	openContextMenu: (request: ContextMenuRequest) -> boolean,
	-- Opt into the `update` hook firing on second boundaries while open.
	setWantsSecondTicks: (wants: boolean) -> (),
	-- Opt into `onFrameTick(deltaMs)` every frame while open (API 18).
	setNeedsFrameTick: (needs: boolean) -> (),
}

-- ## Control-center shortcut entry ([[shortcut]])

declare shortcut: {
	setLabel: (label: string) -> (),
	-- `off` defaults to `on`.
	setIcon: (on: string, off: string?) -> (),
	setActive: (active: boolean) -> (),
	setEnabled: (enabled: boolean) -> (),
}

-- ## Desktop widget entry ([[desktop_widget]])

declare desktopWidget: {
	render: (tree: UiNode) -> (),
	setWantsSecondTicks: (wants: boolean) -> (),
	-- Opt into the `onFrameTick` hook (per-frame; keep the work tiny).
	setNeedsFrameTick: (needs: boolean) -> (),
}

-- ## Launcher entry ([[launcher_provider]])

-- A row is dropped unless `id` or `title` is non-empty. `category` must match a
-- [[launcher_provider.category]] label in plugin.toml. `presentation` only
-- recognises "detail". Setting `query` rewrites the launcher input on activate
-- instead of firing onActivate.
export type LauncherResult = {
	id: string?,
	title: string?,
	subtitle: string?,
	glyph: string?,
	icon: string?,
	badge: string?,
	category: string?,
	presentation: string?,
	score: number?,
	query: string?,
}

declare launcher: {
	-- `query` must echo the onQuery text these results answer, or they are
	-- discarded as stale.
	setResults: (query: string, results: { LauncherResult }) -> (),
	-- Rewrites the sub-query, i.e. the text after the provider prefix.
	setQuery: (text: string) -> (),
}

-- ## ui.* -- declarative tree for render()

export type UiNode = {
	type: string,
	props: { [string]: any },
	children: { UiNode },
}

--[[
Node constructors, all `(props?, children?) -> UiNode`. Only column, row,
scroll, dragSource and dropZone take children; depth is capped at 32 and
children at 256 per node.

Every node takes width, height, flexGrow, opacity and visible; the rest of the
props are per-type and an unknown one is skipped with a logged warning rather
than an error, so a typo is silent here -- check the noctalia log.

Prop values must be boolean | number | string | {number} | {string}, or a
function for a callback prop; arrays have to be uniformly typed. `props.key` is
reserved for reconciliation identity.

Callback props take a closure (API 9) or the NAME of a plugin global:

    ui.button({ text = "Refresh", onClick = function() refresh() end })
    ui.button({ text = "Refresh", onClick = "handleRefresh" })

A closure belongs to the render that produced it; give repeated nodes a `key`
so their handlers survive re-renders. A closure still receives the same string
arguments a named handler does.

Click targets: ui.button (onClick, onRightClick, onHover, plus `tooltip`), and
ui.row / ui.column / ui.box / ui.image (onClick and onHover only -- no
tooltip, no right-click).

Levels: dragSource / dropZone are panel-only (API 5); markdown, input
submitOnEnter and scroll stickToBottom / onScroll / scrollToBottomRev are API
21; input frameVisible is API 27; graph onPointerMove / onPointerLeave are
API 29.
]]
declare ui: {
	column: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
	row: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
	scroll: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
	box: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
	label: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
	markdown: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
	glyph: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
	image: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
	separator: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
	spacer: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
	progress: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
	button: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
	graph: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
	input: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
	select: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
	slider: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
	toggle: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
	dragSource: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
	dropZone: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
}

--[[
## Hooks -- reference only, deliberately NOT declared

These are globals the PLUGIN defines and noctalia calls by name; an undefined
one is a silent no-op. They are documented rather than declared because a
definitions file describes what the environment provides, and `declare`-ing them
would make Luau treat each one as a built-in and then flag the plugin's own
definition with the BuiltinGlobalWrite lint.

Most hooks are dispatched with string arguments, so a numeric-looking payload
arrives as a string -- but not all of them any more: the arguments marked
NUMBER / BOOLEAN below are real Luau values. A hook overrunning its time budget
(12 ms, 25 ms for a direct call) is killed with "script callback timed out".

  All entries
    update()                 once after load, then on the setUpdateInterval timer
    onIpc(event, payload)    `noctalia msg plugin <id>:<entry> <target> <ev> <pl>`
    onExit(signal, reason)   teardown. signal is a NUMBER: 0, 2 (SIGINT) or 15
                             (SIGTERM). reason (API 17) is "reload" | "disable" |
                             "uninstall" | "shutdown"
  Widget, shortcut
    onClick(), onRightClick()    a user gesture binding takes precedence
  Widget
    onMiddleClick()          only once a `middle = "none"` binding frees it
    onHover(entered)         entered is a BOOLEAN
    onScroll(axis, steps, startsGesture)
                             steps a NUMBER (negative = up/left), startsGesture
                             a BOOLEAN
    onAudioSpectrum(values, state)   state is "<audioActive>,<mprisPlaying>"
  Panel
    onOpen(context), onClose()
    onKey(chord, pressed)    a capture_keys chord; pressed is a BOOLEAN (API 13)
  Panel, desktop widget
    onFrameTick(deltaMs)     needs setNeedsFrameTick(true)
  Launcher provider
    onQuery(text)            debounced
    onActivate(id)
  Service
    onEnable()               explicit enable only, not ordinary startup (API 17)
    onConfigChanged()        a setting changed; without it the service restarts
    onOutputsChanged()

Handlers named by (or passed as) a ui callback prop:
    onClick/onRightClick/onDragEnd  ("", "")
    onHover                         ("true"|"false", key)
    toggle onChange                 ("true"|"false", "")
    slider onChange                 (tostring(value), "")
    select onChange                 (tostring(index), text)   -- index is 0-based
    input onChange/onSubmit         (value, "")
    scroll onScroll                 (offset, maxOffset)
    graph onPointerMove             (normX, normY), "0.0000".."1.0000"
    graph onPointerLeave            ()
    dropZone onDrop                 (payload, value)
    openContextMenu onActivate      (actionId, context)
]]
