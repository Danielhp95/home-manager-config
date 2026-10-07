#!/usr/bin/env nu

def ansi_foreground [color: string] { $"\e[38;2;($color)m" }
def ansi_background [color: string] { $"\e[48;2;($color)m" }
def ansi_bold [] { "\e[1m" }
def ansi_reset [] { "\e[0m" }

def collapse_home_prefix [path: string, home_dir: string] {
  if $path == $home_dir {
    "~"
  } else if ($path | str starts-with $"($home_dir)/") {
    $"~($path | str substring ($home_dir | str length)..)"
  } else {
    $path
  }
}

def truncate_path_segments [path: string, keep_segments: int] {
  mut stripped = $path
  if ($stripped | str starts-with "/") { $stripped = ($stripped | str substring 1..) }
  let segments = ($stripped | split row "/")
  let segment_count = ($segments | length)
  if $segment_count <= $keep_segments or $segment_count == 0 {
    return $path
  }
  let first_kept = $segment_count - $keep_segments
  let kept_segments = ($segments | skip $first_kept)
  $"…/($kept_segments | str join '/')"
}

def format_reset_time [epoch_seconds: int] {
  let local_time = ($epoch_seconds * 1_000_000_000 | into datetime | date to-timezone local)
  if ($local_time - (date now)) < 24hr {
    $local_time | format date "%H:%M"
  } else {
    $local_time | format date "%a"
  }
}

def git_output [...git_args] {
  let result = (do { ^git --no-optional-locks ...$git_args } | complete)
  if $result.exit_code == 0 { $result.stdout | str trim } else { "" }
}

def main [] {
  let input = ($in | from json)

  let cwd = ($input | get -o cwd | default ($input | get -o workspace.current_dir))
  let model_name = ($input | get -o model.display_name)
  let session_limit_percent = ($input | get -o rate_limits.five_hour.used_percentage)
  let weekly_limit_percent = ($input | get -o rate_limits.seven_day.used_percentage)
  let session_limit_resets_at = ($input | get -o rate_limits.five_hour.resets_at)
  let weekly_limit_resets_at = ($input | get -o rate_limits.seven_day.resets_at)
  let effort_level = ($input | get -o effort.level)
  let session_name = ($input | get -o session_name)
  let worktree_name = ($input | get -o worktree.name | default ($input | get -o workspace.git_worktree))

  if ($cwd | is-not-empty) {
    cd $cwd
  }

  # At-sign placeholders are palette/ colours (replaceVars in default.nix):
  # the slots by name, and extra.heat for the three hotter effort steps.
  let ash = "@ash@"
  let bg = "@bg@"
  let surface = "@surface@"
  let accent = "@accent@"
  let accent_dim = "@accentDim@"
  let heat_high = "@heatHigh@"
  let heat_xhigh = "@heatXhigh@"
  let heat_max = "@heatMax@"
  let error = "@error@"
  let fg_dim = "@fgDim@"
  let fg_soft = "@fgSoft@"
  let gold = "@gold@"
  let mauve = "@mauve@"
  let sage = "@sage@"
  let steel = "@steel@"

  let glyph_pill_open = (char -u "e0b6")
  let glyph_pill_close = (char -u "e0b4")
  let glyph_wedge = (char -u "e0b0")

  let glyph_lock = (char -u "f033e")
  let glyph_git_branch = (char -u "f02a2")
  let glyph_git_commit = (char -u "f0718")
  let glyph_nix = (char -u "f1105")
  let glyph_direnv = (char -u "f032a")

  def pill_open [color: string] { $"(ansi_foreground $color)($glyph_pill_open)(ansi_reset)" }
  def pill_close [color: string] { $"(ansi_foreground $color)($glyph_pill_close)(ansi_reset)" }
  def pill_wedge [from_color: string, to_color: string] { $"(ansi_foreground $from_color)(ansi_background $to_color)($glyph_wedge)(ansi_reset)" }
  def pill_text [text: string, foreground: string, background: string, bold: bool] {
    let bold_prefix = (if $bold { ansi_bold } else { "" })
    $"($bold_prefix)(ansi_foreground $foreground)(ansi_background $background)($text)(ansi_reset)"
  }

  def effort_color [level: string] {
    match ($level | str lowercase) {
      "low" => $accent_dim,
      "medium" => $accent,
      "high" => $heat_high,
      "xhigh" => $heat_xhigh,
      "max" => $heat_max,
      _ => $accent,
    }
  }

  mut line = ""

  if ("SSH_CONNECTION" in $env) or ("SSH_TTY" in $env) {
    let user_name = (^whoami | str trim)
    let host_name = (^hostname -s | str trim)
    $line = $line + (pill_open $gold) + (pill_text $user_name $bg $gold true) + (pill_close $gold) + " "
    $line = $line + (pill_open $gold) + (pill_text $host_name $bg $gold false) + (pill_close $gold) + " "
  }

  let current_dir = $env.PWD
  mut read_only_marker = ""
  let dir_is_writable = (do { ^test -w $current_dir } | complete | get exit_code) == 0
  if not $dir_is_writable { $read_only_marker = $" ($glyph_lock)" }

  let git_root = (git_output -- rev-parse --show-toplevel)

  if ($git_root | is-not-empty) {
    let ancestor_path = (truncate_path_segments (collapse_home_prefix ($git_root | path dirname) $env.HOME) 3)
    let repo_name = ($git_root | path basename)

    $line = $line + (pill_open $ash)
    $line = $line + (pill_text $" ($ancestor_path)" $bg $ash true)
    $line = $line + (pill_wedge $ash $accent_dim)
    $line = $line + (pill_text $" ($repo_name)" $bg $accent_dim true)
    $line = $line + (pill_wedge $accent_dim $accent)
    mut last_pill_color = $accent
    if ($model_name | is-not-empty) {
      $line = $line + (pill_wedge $last_pill_color $gold)
      $line = $line + (pill_text $" ($model_name)" $bg $gold true)
      $last_pill_color = $gold
    }
    if ($effort_level | is-not-empty) {
      let effort_pill_color = (effort_color $effort_level)
      $line = $line + (pill_wedge $last_pill_color $effort_pill_color)
      $line = $line + (pill_text $" ($effort_level)" $bg $effort_pill_color true)
      $last_pill_color = $effort_pill_color
    }
    $line = $line + (pill_wedge $last_pill_color $accent_dim)
    $line = $line + (pill_wedge $accent_dim $ash)
    $line = $line + (pill_close $ash) + " "
  } else {
    let display_path = (truncate_path_segments (collapse_home_prefix $current_dir $env.HOME) 3)
    $line = $line + (pill_open $accent)
    $line = $line + (pill_text $" ($display_path)($read_only_marker)" $bg $accent true)
    mut last_pill_color = $accent
    if ($model_name | is-not-empty) {
      $line = $line + (pill_wedge $last_pill_color $gold)
      $line = $line + (pill_text $" ($model_name)" $bg $gold true)
      $last_pill_color = $gold
    }
    if ($effort_level | is-not-empty) {
      let effort_pill_color = (effort_color $effort_level)
      $line = $line + (pill_wedge $last_pill_color $effort_pill_color)
      $line = $line + (pill_text $" ($effort_level)" $bg $effort_pill_color true)
      $last_pill_color = $effort_pill_color
    }
    $line = $line + (pill_wedge $last_pill_color $accent_dim)
    $line = $line + (pill_wedge $accent_dim $ash)
    $line = $line + (pill_close $ash) + " "
  }

  if ($git_root | is-not-empty) {
    mut git_segment = ""
    let branch_name = (git_output -- symbolic-ref -q --short HEAD)
    if ($branch_name | is-not-empty) {
      $git_segment = $git_segment + (pill_text $"($glyph_git_branch) " $accent_dim $surface false)
      $git_segment = $git_segment + (pill_text $branch_name $fg_soft $surface false)
    } else {
      let short_commit = (git_output -- rev-parse --short HEAD)
      if ($short_commit | is-not-empty) {
        $git_segment = $git_segment + (pill_text $"($glyph_git_commit) ($short_commit)" $fg_soft $surface false)
      }
    }

    if ($git_segment | is-not-empty) {
      $line = $line + (pill_open $surface) + $git_segment + (pill_close $surface) + " "
    }
  }

  if ($session_name | is-not-empty) or ($worktree_name | is-not-empty) {
    mut identity_segment = ""
    if ($session_name | is-not-empty) {
      $identity_segment = $identity_segment + (pill_text $session_name $gold $surface false)
    }
    if ($worktree_name | is-not-empty) {
      if ($identity_segment | is-not-empty) {
        $identity_segment = $identity_segment + (pill_text " " $surface $surface false)
      }
      $identity_segment = $identity_segment + (pill_text $"($glyph_git_branch) ($worktree_name)" $mauve $surface false)
    }
    $line = $line + (pill_open $surface) + $identity_segment + (pill_close $surface) + " "
  }

  if "IN_NIX_SHELL" in $env {
    let nix_shell_state = (match $env.IN_NIX_SHELL {
      "pure" => "pure",
      "impure" => "impure",
      _ => "shell",
    })
    $line = $line + (pill_open $surface) + (pill_text $"($glyph_nix) ($nix_shell_state)" $steel $surface false) + (pill_close $surface) + " "
  }

  if "DIRENV_DIR" in $env {
    $line = $line + (pill_open $surface) + (pill_text $"($glyph_direnv) env" $sage $surface false) + (pill_close $surface) + " "
  }

  if ($session_limit_percent | is-not-empty) or ($weekly_limit_percent | is-not-empty) {
    mut usage_segment = ""
    if ($session_limit_percent | is-not-empty) {
      let session_percent_rounded = ($session_limit_percent | math round)
      let session_limit_color = (if $session_percent_rounded >= 85 { $error } else if $session_percent_rounded >= 60 { $gold } else { $fg_soft })
      $usage_segment = $usage_segment + (pill_text $"5h ($session_percent_rounded)%" $session_limit_color $surface false)
      if ($session_limit_resets_at | is-not-empty) {
        $usage_segment = $usage_segment + (pill_text $"·(format_reset_time ($session_limit_resets_at | into int))" $fg_dim $surface false)
      }
    }
    if ($weekly_limit_percent | is-not-empty) {
      let weekly_percent_rounded = ($weekly_limit_percent | math round)
      if ($usage_segment | is-not-empty) {
        $usage_segment = $usage_segment + (pill_text " " $surface $surface false)
      }
      let weekly_limit_color = (if $weekly_percent_rounded >= 85 { $error } else if $weekly_percent_rounded >= 60 { $gold } else { $fg_soft })
      $usage_segment = $usage_segment + (pill_text $"7d ($weekly_percent_rounded)%" $weekly_limit_color $surface false)
      if ($weekly_limit_resets_at | is-not-empty) {
        $usage_segment = $usage_segment + (pill_text $"·(format_reset_time ($weekly_limit_resets_at | into int))" $fg_dim $surface false)
      }
    }
    $line = $line + (pill_open $surface) + $usage_segment + (pill_close $surface)
  }

  print ($line | str trim -r)
}
