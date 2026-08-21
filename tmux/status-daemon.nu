# Feeds the dynamic status-line segments from one background process.
#
# The bar used to carry three #() jobs: continuum's autosave hook, a
# `git rev-parse` for the branch, and `free -m | awk` for the RAM. tmux
# re-runs a #() job whenever a status redraw lands in a new second, and
# *every* keypress that produces pane output forces a redraw, because
# automatic-rename re-evaluates #{pane_current_command} on pane activity.
# Measured on this config: 0.10 job-fires/s sitting idle (correct for
# status-interval 15) but 1.05/s while typing -- and continuum_save.sh
# alone costs ~25ms and spawns 33 processes per fire, several of them
# tmux clients making synchronous round trips back into the very server
# that also has to service the keystrokes.
#
# So the jobs move off the render path and into this loop, which parks
# finished strings in @st_git / @st_ram for the format to read back with
# no fork at all. A redraw is now pure string work. The clock was always
# a native strftime and is untouched.
#
# Nushell suits this better than a POSIX shell does: everything a tick
# needs apart from talking to tmux is a builtin. `open` reads /proc and
# .git/HEAD in process, arithmetic and string work never spawn anything,
# calling a `def` is not a subshell the way `$(f)` is, and `sleep` is a
# command rather than /usr/bin/sleep. So a tick costs exactly the tmux
# round trips it makes -- one, most of the time.
#
# Argv: <socket path> <path to continuum_save.sh> <path to the tmux binary>

# Shown when the pane isn't in a repo -- the same en dash the old job's
# `|| echo '-'` fallback printed. As an escape rather than the literal
# character because non-ASCII in this tree has a habit of being mangled by
# whatever writes the file next.
const NO_REPO = "\u{2013}"

# Tick length when @st-interval isn't set, in seconds.
const DEFAULT_INTERVAL = 2

# How often continuum's save script gets called. It runs its own
# @continuum-save-interval check, so this only has to be finer than that.
const SAVE_EVERY = 60

# One line per attached client. `#{pane_current_path}` resolves against the
# client's own session here, which is the whole reason the tick asks
# list-clients rather than display-message: display-message with no target
# answers for whichever session tmux considers current, and with more than
# one session that is regularly not the one the client is looking at.
const CLIENT_FMT = "#{client_name}|#{client_session}|#{pane_current_path}"

# Every tmux call funnels through here. `complete` is what stops a nonzero
# exit from raising: each caller decides what a failure means, and for the
# loop's one mandatory call it means the server is gone.
def tmux-run [args: list<string>] {
  ^$env.ST_TMUX -S $env.ST_SOCKET ...$args | complete
}

# Same, for the calls we want the trimmed stdout of. Null on failure.
def tmux-out [args: list<string>] {
  let r = (tmux-run $args)
  if $r.exit_code != 0 { return null }
  $r.stdout | str trim --char "\n"
}

# ── continuum: take its save hook off the render path ──────────────────
# continuum.tmux prepends "#(continuum_save.sh)" to status-right, and that
# interpolation is the *only* thing that ever triggers a save -- so it
# can't merely be deleted, the loop below has to call the same script.
# Once a minute instead of once a second; continuum_save.sh still does its
# own @continuum-save-interval check, so the save cadence stays 5 minutes.
#
# Re-run on every invocation rather than only the first, because
# `prefix + r` re-sources tmux.conf, which reloads the plugins and lets
# continuum put its interpolation straight back.
def strip-save-hook [continuum_save: string] {
  let before = (tmux-out ["show-option" "-gqv" "status-right"])
  if $before == null { return }
  # Concatenated rather than interpolated: "#(" would open a subexpression
  # inside a $"..." string.
  let hook = ("#(" + $continuum_save + ")")
  let after = ($before | str replace $hook "")
  if $after != $before {
    tmux-run ["set" "-gq" "status-right" $after] | ignore
  }
}

# One feeder per server. A reload re-runs this script; that copy strips the
# hook above and then gets out of the way of the feeder already running.
# /proc rather than `kill -0` so the check spawns nothing, and the cmdline
# test stops a recycled pid from passing for a live feeder.
def feeder-running [] {
  let pid = (tmux-out ["show-option" "-gqv" "@st_daemon_pid"])
  if ($pid | is-empty) { return false }
  let cmdline = $"/proc/($pid)/cmdline"
  if not ($cmdline | path exists) { return false }
  (open --raw $cmdline | str contains "tmux-status-daemon")
}

# First line of a file, or "" if it is empty or unreadable. `first` returns
# nothing on an empty list and the next `str` command then fails on null,
# which would take the whole feeder down -- and a half-written .git/HEAD
# mid-checkout is exactly the sort of thing that produces one.
def first-line [file: string] {
  if not ($file | path exists) { return "" }
  open --raw $file | lines | get -o 0 | default "" | str trim
}

# The branch without forking git: walk up to the repo and read HEAD. A
# `git rev-parse --abbrev-ref HEAD` only costs ~2ms, but that is 2ms of
# fork out of the tmux server, where this is two file reads.
def git-branch [start: string] {
  if ($start | is-empty) { return null }
  mut dir = $start
  loop {
    let dotgit = ($dir | path join ".git")
    let kind = (if ($dotgit | path exists) { $dotgit | path type } else { null })
    if $kind != null {
      let gitdir = (if $kind == "dir" {
        $dotgit
      } else {
        # worktrees and submodules leave a "gitdir: <path>" pointer file
        let ptr = (first-line $dotgit | str replace "gitdir: " "")
        if ($ptr | is-empty) {
          ""
        } else if ($ptr | str starts-with "/") {
          $ptr
        } else {
          $dir | path join $ptr
        }
      })
      if ($gitdir | is-empty) { return null }
      let head = (first-line ($gitdir | path join "HEAD"))
      if ($head | is-empty) { return null }
      return (if ($head | str starts-with "ref: refs/heads/") {
        $head | str replace "ref: refs/heads/" ""
      } else {
        # detached HEAD, where rev-parse --abbrev-ref printed a bare "HEAD".
        # The short sha costs the same and says more.
        $head | str substring 0..<7
      })
    }
    let parent = ($dir | path dirname)
    # `path dirname` of "/" is "/", which is this walk's floor
    if $parent == $dir { return null }
    $dir = $parent
  }
}

def meminfo-kb [meminfo: list<string>, key: string] {
  let row = ($meminfo | where {|l| $l | str starts-with $key } | get -o 0 | default "")
  if ($row | is-empty) { return 0 }
  $row | split row -r '\s+' | get -o 1 | default "0" | into int
}

# free(1)'s "used" column is MemTotal - MemAvailable on procps >= 3.3.10;
# reproduced from /proc/meminfo so the number stays what `free -m | awk`
# printed, minus its two forks. Integer math throughout, kB straight to
# tenths of a GiB in one step: the old awk ended in printf "%.1fG", so the
# + 2**19 rounds to nearest instead of truncating.
def ram-used [] {
  let meminfo = (open --raw /proc/meminfo | lines)
  let used_kb = ((meminfo-kb $meminfo "MemTotal:") - (meminfo-kb $meminfo "MemAvailable:"))
  let tenths = (($used_kb * 10 + 524288) // 1048576)
  $"($tenths // 10).($tenths mod 10)G"
}

# Split CLIENT_FMT back apart. The path is rejoined from everything after
# the second field, so a directory with a "|" in its name still parses.
def parse-clients [out: string] {
  $out | lines | where {|l| not ($l | is-empty) } | each {|l|
    let parts = ($l | split row "|")
    {
      name: ($parts | get -o 0 | default "")
      session: ($parts | get -o 1 | default "")
      path: ($parts | skip 2 | str join "|")
    }
  }
}

# Everything a tick computes, as data: a signature to compare against the
# previous tick, and the tmux argv that would apply it. Pure, so main can
# run it inside a `try` -- then a transient failure (a pane dying mid-read,
# a HEAD half-written during a checkout) costs one skipped tick instead of
# killing the feeder for the rest of the server's life.
#
# @st_git is set per *session*, not globally: two clients on two sessions
# must each see their own repo. tmux resolves #{@st_git} through the
# session's option set and falls back to the global seed in tmux.conf.
# @st_ram is machine-wide, so it stays global.
def tick-plan [clients: list<record>] {
  let ram = (ram-used)
  mut sig = $ram
  mut cmd = ["set" "-gq" "@st_ram" $ram]
  mut seen = []
  for c in $clients {
    if not ($c.session in $seen) {
      $seen = ($seen | append $c.session)
      let branch = (git-branch $c.path | default $NO_REPO)
      $sig = ($sig + "|" + $c.session + "=" + $branch)
      $cmd = ($cmd | append [";" "set" "-q" "-t" $c.session "@st_git" $branch])
    }
  }
  # Setting an option redraws nothing, so ask each client to repaint its
  # status line. Best-effort: a client that detaches between listing and
  # here just makes refresh-client fail, and the result is `ignore`d.
  for c in $clients {
    $cmd = ($cmd | append [";" "refresh-client" "-S" "-t" $c.name])
  }
  {sig: $sig, cmd: $cmd}
}

def tick-interval [] {
  let configured = (try { (tmux-out ["show-option" "-gqv" "@st-interval"]) | into int } catch { 0 })
  if $configured >= 1 { $configured } else { $DEFAULT_INTERVAL }
}

def main [sock: string, continuum_save: string, tmux_bin: string] {
  # A `def` can't close over a local, so the two things every tmux call
  # needs ride in the environment instead. Calling the binary by its
  # absolute store path rather than through PATH pins this to the tmux the
  # config was built against -- and leaves PATH itself alone, which
  # continuum_save.sh depends on, being a bash script that shells out to
  # date/ps/grep/sed on its way to saving.
  $env.ST_TMUX = $tmux_bin
  $env.ST_SOCKET = $sock

  strip-save-hook $continuum_save
  if (feeder-running) { return }
  tmux-run ["set" "-gq" "@st_daemon_pid" ($nu.pid | into string)] | ignore

  let interval = (tick-interval)
  mut last = ""
  mut since_save = 0

  loop {
    # The one tmux round trip a tick always makes, and the liveness check:
    # this exits 0 with no clients attached and 1 once the server is gone.
    let listed = (tmux-run ["list-clients" "-F" $CLIENT_FMT])
    if $listed.exit_code != 0 { break }

    # Nobody attached means nothing to render, so a detached server's feeder
    # costs exactly this one call per tick.
    let clients = (parse-clients $listed.stdout)
    if not ($clients | is-empty) {
      let plan = (try { tick-plan $clients } catch { null })
      if $plan != null {
        # Skipped when nothing moved, so a quiet session writes nothing to
        # the server and sends nothing to the terminal.
        if $plan.sig != $last {
          tmux-run $plan.cmd | ignore
          $last = $plan.sig
        }
      }
    }

    if $since_save >= $SAVE_EVERY {
      try { ^$continuum_save | complete | ignore }
      $since_save = 0
    }
    $since_save = $since_save + $interval

    sleep ($interval * 1sec)
  }
}
