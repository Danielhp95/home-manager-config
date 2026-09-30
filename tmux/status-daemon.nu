# Feeds the status line's @st_git / @st_ram and continuum's autosave from one
# background loop. As #() jobs they re-ran on every redraw in a new second
# (~1/s while typing), each forking tmux clients back into the server. In
# nushell a tick forks nothing apart from its tmux round trips.
#
# Argv: <socket path> <path to continuum_save.sh> <path to the tmux binary>

# Shown outside a repo. An escape, not the literal en dash: non-ASCII in this
# tree tends to get mangled by whatever writes the file next.
const NO_REPO = "\u{2013}"

# Tick length when @st-interval isn't set, in seconds.
const DEFAULT_INTERVAL = 2

# How often continuum's save script gets called. It runs its own
# @continuum-save-interval check, so this only has to be finer than that.
const SAVE_EVERY = 60

# One line per attached client. list-clients, not display-message: only there
# does #{pane_current_path} resolve in each client's own session.
const CLIENT_FMT = "#{client_name}|#{client_session}|#{pane_current_path}"

# Every tmux call goes through here; `complete` keeps a nonzero exit from
# raising, so each caller decides what a failure means.
def tmux-run [args: list<string>] {
  ^$env.ST_TMUX -S $env.ST_SOCKET ...$args | complete
}

# Same, for the calls we want the trimmed stdout of. Null on failure.
def tmux-out [args: list<string>] {
  let r = (tmux-run $args)
  if $r.exit_code != 0 { return null }
  $r.stdout | str trim --char "\n"
}

# continuum's own #() save hook is patched out (default.nix), so the loop
# below is the only thing that calls continuum_save.sh.

# One feeder per server: a reload re-runs this script, and that copy exits.
# /proc, not `kill -0`, so the check forks nothing; the cmdline test keeps a
# recycled pid from passing for a live feeder.
def feeder-running [] {
  let pid = (tmux-out ["show-option" "-gqv" "@st_daemon_pid"])
  if ($pid | is-empty) { return false }
  let cmdline = $"/proc/($pid)/cmdline"
  if not ($cmdline | path exists) { return false }
  (open --raw $cmdline | str contains "tmux-status-daemon")
}

# First line of a file, or "" if it is empty or unreadable: a null here would
# crash the feeder, and a half-written .git/HEAD mid-checkout produces one.
def first-line [file: string] {
  if not ($file | path exists) { return "" }
  open --raw $file | lines | get -o 0 | default "" | str trim
}

# The branch without forking git: walk up to the repo and read HEAD.
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
        # detached HEAD: show the short sha
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

# free(1)'s "used" (MemTotal - MemAvailable), from kB straight to tenths of a
# GiB; the + 2**19 rounds to nearest instead of truncating.
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

# A tick as data: a signature to compare with the last one, and the tmux argv
# that applies it. Pure, so main can `try` it and a transient failure only
# skips a tick. @st_git is per session (each client sees its own repo; tmux
# falls back to the global seed), @st_ram global.
def tick-plan [clients: list<record>] {
  let ram = (ram-used)
  mut sig = $ram
  mut cmd = ["set" "-gq" "@st_ram" $ram]
  mut seen = []
  for c in $clients {
    if not ($c.session in $seen) {
      $seen = ($seen | append $c.session)
      # Per client, so one pane's half-written HEAD can't freeze every
      # session's @st_git
      let branch = (try { git-branch $c.path | default $NO_REPO } catch { $NO_REPO })
      $sig = ($sig + "|" + $c.session + "=" + $branch)
      $cmd = ($cmd | append [";" "set" "-q" "-t" $c.session "@st_git" $branch])
    }
  }
  # Setting an option redraws nothing, so repaint each client's status line
  # (best-effort: a client that detached meanwhile just fails)
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
  # A `def` can't close over locals, so tmux's path and socket ride in the
  # environment. PATH stays untouched: continuum_save.sh needs date/ps/grep/sed.
  $env.ST_TMUX = $tmux_bin
  $env.ST_SOCKET = $sock

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

    # Nobody attached: nothing to render, just this one call per tick
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
