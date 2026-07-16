--!strict
--[[
Type definitions for the noctalia v5 Luau plugin API.

noctalia injects these globals into every plugin entry VM; there is no `require`
to import them, so without this file luau-lsp reports every one as an unknown
global. Loaded into the global namespace via `luau-lsp lsp --definitions=`
(see danvim/lua/danvim/plugins/lsp.lua).

Hand-written from the C++ bindings, since noctalia ships no definitions:
  src/scripting/luau_host.cpp        noctalia.*
  src/scripting/plugin_bindings.cpp  barWidget.* panel.* shortcut.* launcher.*
  src/scripting/ui_prelude.h         ui.*
  src/shell/**/plugin_*.cpp          the hooks noctalia calls back into
Re-check against the noctalia source after a version bump; a stale entry here
type-checks clean and then fails at runtime.

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
	headers: { string }?,
}

export type HttpResponse = {
	ok: boolean, -- transport-level success; check `status` for HTTP errors
	status: number,
	body: string,
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

--[[
The core API, available in every entry.

Filesystem paths resolve as: "~" -> $HOME, "/..." -> absolute, anything else ->
relative to the plugin directory. Nothing is sandboxed.

The fs and json calls follow a two-return error convention -- (value, nil) on
success, (nil/false, errorMessage) on failure -- rather than raising.

The async calls (runAsync, runStream, http, download, processMatches,
openColorPicker) return false when a concurrency cap is hit, so a plugin under
load can see them refuse to start; they do not queue.
]]
declare noctalia: {
	log: (msg: string) -> (),

	-- ### Processes
	-- Detached when `callback` is omitted. timeoutMs defaults to 5000 and is
	-- clamped to [50, 60000]. Returns false if the cap (8 per VM) is hit.
	runAsync: (cmd: string, callback: ((result: RunResult) -> ())?, timeoutMs: number?) -> boolean,
	-- Line-buffered; the callback fires per stdout line as it arrives.
	runStream: (cmd: string, callback: (line: string) -> ()) -> boolean,
	runInTerminal: (cmd: string) -> boolean,
	commandExists: (name: string) -> boolean,
	-- NOTE: callback FIRST, then the process names -- inverted vs every other
	-- async call here. `matched` is true if any needle matches a running process.
	processMatches: (callback: (matched: boolean) -> (), ...string) -> boolean,
	flatpakAppInstalled: (appId: string) -> boolean,
	portalAvailable: () -> boolean,

	-- ### Outputs / wallpaper
	focusedOutputName: () -> string?,
	outputs: () -> { OutputInfo },
	-- sizePx defaults to 0 (natural size).
	appIconPath: (appIdOrIconName: string, sizePx: number?) -> string?,
	setWallpaperEnabled: (connector: string, enabled: boolean) -> (),
	-- One arg sets every output; two targets a single connector.
	setWallpaper: (pathOrConnector: string, path: string?) -> (),
	wallpaperDirectory: () -> string?,
	isDarkMode: () -> boolean,

	-- ### Shell
	-- panelId is fully qualified, e.g. "dani/dart:panel".
	togglePanel: (panelId: string) -> (),
	notify: (title: string, body: string?) -> (),
	notifyError: (title: string, body: string?) -> (),
	copyToClipboard: (text: string, mimeType: string) -> boolean,
	clipboardText: () -> string?,
	-- Raises on a hex that is not exactly "#RRGGBB". The callback gets nil if
	-- the user cancels. Only one picker may be open shell-wide.
	openColorPicker: (hex: string, callback: (color: string?) -> ()) -> boolean,
	-- Clamped to a 16 ms floor; drives the `update` hook.
	setUpdateInterval: (ms: number) -> (),
	-- Value of a plugin.toml [[setting]] key, nil if the key is undeclared. The
	-- per-global getConfig variants (barWidget.getConfig etc.) were removed in
	-- v5. Typed `any` deliberately: the value's type is whatever `type =` the
	-- key declares in plugin.toml (bool/int/float/string/list), which is out of
	-- reach here, so a union would just force a cast at every call site.
	getConfig: (key: string) -> any,

	-- ### Environment / time
	getenv: (name: string) -> string?,
	expandPath: (path: string) -> string,
	-- strftime-style; unixSeconds defaults to now.
	formatTime: (pattern: string, unixSeconds: number?) -> string,

	-- ### Filesystem
	readFile: (path: string) -> (string?, string?),
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
	pluginDataDir: () -> (string?, string?),
	-- Returns the font family name to pass to setFont / the fontFamily prop.
	loadFont: (path: string) -> (string?, string?),

	-- ### i18n (translations/*.json)
	tr: (key: string, subst: { [string]: any }?) -> string,
	-- Plural form: picks "<key>.one" or "<key>.other" and injects subst.count.
	trp: (key: string, count: number, subst: { [string]: any }?) -> string,

	-- ### Network
	http: (request: HttpRequest, callback: (response: HttpResponse) -> ()) -> boolean,
	download: (url: string, destPath: string, callback: (ok: boolean) -> ()) -> boolean,

	-- Fuzzy match score, or nil when the pattern does not match.
	fuzzyScore: (pattern: string, text: string) -> number?,

	state: NoctaliaState,
	json: NoctaliaJson,
	string: NoctaliaString,
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
	isVertical: () -> (boolean),
	outputName: () -> string?,
	setVisible: (visible: boolean) -> (),
	-- Declarative alternative to the setters above; see `ui`.
	render: (tree: UiNode) -> (),
}

-- ## Panel entry ([[panel]])

declare panel: {
	render: (tree: UiNode) -> (),
	close: () -> (),
	-- Opt into the `update` hook firing once a second while open.
	setWantsSecondTicks: (wants: boolean) -> (),
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
Node constructors, all `(props?, children?) -> UiNode`. Only column, row and
scroll may take children; depth is capped at 32 and children at 256 per node.

Every node takes width, height, flexGrow, opacity and visible; the rest of the
props are per-type and an unknown one is skipped with a warning rather than an
error, so a typo is silent here -- check the noctalia log.

Prop values must be boolean | number | string | {number} | {string}; arrays have
to be uniformly typed. `props.key` is reserved for reconciliation identity.

The `on*` props (onClick, onChange, ...) take the NAME of a plugin global as a
string, not a function value:

    ui.button({ text = "Refresh", onClick = "handleRefresh" })
    function handleRefresh() end

Handlers are always invoked with two string args, so a numeric value such as a
slider position or a select index arrives as a string.
]]
declare ui: {
	column: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
	row: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
	scroll: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
	box: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
	label: (props: { [string]: any }?, children: { UiNode }?) -> UiNode,
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
}

--[[
## Hooks -- reference only, deliberately NOT declared

These are globals the PLUGIN defines and noctalia calls by name; an undefined
one is a silent no-op. They are documented rather than declared because a
definitions file describes what the environment provides, and `declare`-ing them
would make Luau treat each one as a built-in and then flag the plugin's own
definition with the BuiltinGlobalWrite lint.

Hooks are dispatched with exactly two string arguments, always. That is the
trap worth remembering: a numeric-looking payload arrives as a string
(onFrameTick's deltaMs is "16.667", onScroll's steps is "1"), and several hooks
have a trailing argument that is always "". A hook overrunning its time budget
(12 ms, 25 ms for a direct call) is killed with "script callback timed out".

  All entries
    update()                 once after load, then on the setUpdateInterval timer
    onConfigChanged()        a plugin.toml setting changed
    onExit(signal)           teardown; signal is 0, SIGINT or SIGTERM
  Widget, panel, desktop widget, service
    onIpc(event, payload)    `noctalia msg plugin <id>:<entry> <target> <ev> <pl>`
  Widget, shortcut
    onClick(), onRightClick()
  Widget
    onMiddleClick(), onHover(entered), onScroll(axis, steps)
    onAudioSpectrum(values, state)   state is "<audioActive>,<mprisPlaying>"
  Panel
    onOpen(context), onClose()
  Desktop widget
    onFrameTick(deltaMs)     needs setNeedsFrameTick(true)
  Launcher provider
    onQuery(text)            debounced
    onActivate(id)
  Service
    onOutputsChanged()

Handlers named by a ui `on*` prop follow the same two-string contract:
    onClick/onRightClick/onDragEnd  ("", "")
    toggle onChange                 ("true"|"false", "")
    slider onChange                 (tostring(value), "")
    select onChange                 (tostring(index), text)   -- index is 0-based
    input onChange/onSubmit         (value, "")
]]
