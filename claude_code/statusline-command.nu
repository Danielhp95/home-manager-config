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
  let context_used_percent = ($input | get -o context_window.used_percentage)
  let session_limit_percent = ($input | get -o rate_limits.five_hour.used_percentage)
  let weekly_limit_percent = ($input | get -o rate_limits.seven_day.used_percentage)
  let session_limit_resets_at = ($input | get -o rate_limits.five_hour.resets_at)
  let weekly_limit_resets_at = ($input | get -o rate_limits.seven_day.resets_at)
  let effort_level = ($input | get -o effort.level)
  let session_name = ($input | get -o session_name)
  let worktree_name = ($input | get -o worktree.name | default ($input | get -o workspace.git_worktree))
  let session_duration_ms = ($input | get -o cost.total_duration_ms)

  if ($cwd | is-not-empty) {
    cd $cwd
  }

  let color_ash = "138;90;60"
  let color_bg0 = "28;27;25"
  let color_bg1 = "42;40;37"
  let color_ember = "224;128;96"
  let color_ember_dim = "184;101;76"
  let color_ember_hot = "255;143;102"
  let color_error = "224;82;82"
  let color_fg1 = "154;146;136"
  let color_fg_soft = "184;176;160"
  let color_gold = "200;180;104"
  let color_mauve = "152;128;144"
  let color_olive = "138;152;104"
  let color_sage = "122;168;138"
  let color_steel = "239;127;56"

  let glyph_pill_open = (char -u "e0b6")
  let glyph_pill_close = (char -u "e0b4")
  let glyph_wedge = (char -u "e0b0")

  let glyph_lock = (char -u "f033e")
  let glyph_git_branch = (char -u "f02a2")
  let glyph_git_commit = (char -u "f0718")
  let glyph_conflict = (char -u "f0156")
  let glyph_deleted = (char -u "f01b4")
  let glyph_renamed = (char -u "f0455")
  let glyph_modified = (char -u "f0238")
  let glyph_staged = (char -u "f012c")
  let glyph_untracked = (char -u "f0415")
  let glyph_stashed = (char -u "f0193")
  let glyph_ahead = (char -u "f0167")
  let glyph_behind = (char -u "f0162")
  let glyph_nix = (char -u "f1105")
  let glyph_direnv = (char -u "f032a")
  let glyph_battery_low = (char -u "f007e")
  let glyph_battery_charging = (char -u "f0084")
  let glyph_battery_full = (char -u "f0079")

  def pill_open [color: string] { $"(ansi_foreground $color)($glyph_pill_open)(ansi_reset)" }
  def pill_close [color: string] { $"(ansi_foreground $color)($glyph_pill_close)(ansi_reset)" }
  def pill_wedge [from_color: string, to_color: string] { $"(ansi_foreground $from_color)(ansi_background $to_color)($glyph_wedge)(ansi_reset)" }
  def pill_text [text: string, foreground: string, background: string, bold: bool] {
    let bold_prefix = (if $bold { ansi_bold } else { "" })
    $"($bold_prefix)(ansi_foreground $foreground)(ansi_background $background)($text)(ansi_reset)"
  }

  mut line = ""

  if ("SSH_CONNECTION" in $env) or ("SSH_TTY" in $env) {
    let user_name = (^whoami | str trim)
    let host_name = (^hostname -s | str trim)
    $line = $line + (pill_open $color_gold) + (pill_text $user_name $color_bg0 $color_gold true) + (pill_close $color_gold) + " "
    $line = $line + (pill_open $color_gold) + (pill_text $host_name $color_bg0 $color_gold false) + (pill_close $color_gold) + " "
  }

  let current_dir = $env.PWD
  mut read_only_marker = ""
  let dir_is_writable = (do { ^test -w $current_dir } | complete | get exit_code) == 0
  if not $dir_is_writable { $read_only_marker = $" ($glyph_lock)" }

  let git_root = (git_output -- rev-parse --show-toplevel)

  if ($git_root | is-not-empty) {
    let ancestor_path = (truncate_path_segments (collapse_home_prefix ($git_root | path dirname) $env.HOME) 3)
    let repo_name = ($git_root | path basename)
    mut path_within_repo = ($current_dir | str replace $git_root "")
    $path_within_repo = ($path_within_repo | str trim -c "/" -l)
    $path_within_repo = (truncate_path_segments $path_within_repo 3)

    $line = $line + (pill_open $color_ash)
    $line = $line + (pill_text $" ($ancestor_path) " $color_bg0 $color_ash true)
    $line = $line + (pill_wedge $color_ash $color_ember_dim)
    $line = $line + (pill_text $" ($repo_name) " $color_bg0 $color_ember_dim true)
    $line = $line + (pill_wedge $color_ember_dim $color_ember)
    $line = $line + (pill_text $"($path_within_repo)($read_only_marker) " $color_bg0 $color_ember true)
    $line = $line + (pill_wedge $color_ember $color_ember_dim)
    $line = $line + (pill_wedge $color_ember_dim $color_ash)
    $line = $line + (pill_close $color_ash) + " "
  } else {
    let display_path = (truncate_path_segments (collapse_home_prefix $current_dir $env.HOME) 3)
    $line = $line + (pill_open $color_ember)
    $line = $line + (pill_text $" ($display_path)($read_only_marker) " $color_bg0 $color_ember true)
    $line = $line + (pill_wedge $color_ember $color_ember_dim)
    $line = $line + (pill_wedge $color_ember_dim $color_ash)
    $line = $line + (pill_close $color_ash) + " "
  }

  if ($git_root | is-not-empty) {
    mut git_segment = ""
    let branch_name = (git_output -- symbolic-ref -q --short HEAD)
    if ($branch_name | is-not-empty) {
      $git_segment = $git_segment + (pill_text $"($glyph_git_branch) " $color_ember_dim $color_bg1 false)
      $git_segment = $git_segment + (pill_text $branch_name $color_fg_soft $color_bg1 false)
    } else {
      let short_commit = (git_output -- rev-parse --short HEAD)
      if ($short_commit | is-not-empty) {
        $git_segment = $git_segment + (pill_text $"($glyph_git_commit) ($short_commit)" $color_fg_soft $color_bg1 false)
      }
    }

    let git_dir = (git_output -- rev-parse --git-dir)
    mut operation_state = ""
    if ($git_dir | is-not-empty) {
      if ($"($git_dir)/MERGE_HEAD" | path exists) {
        $operation_state = "MERGING"
      } else if (($"($git_dir)/rebase-merge" | path exists) or ($"($git_dir)/rebase-apply" | path exists)) {
        $operation_state = "REBASING"
      } else if ($"($git_dir)/CHERRY_PICK_HEAD" | path exists) {
        $operation_state = "CHERRY-PICKING"
      } else if ($"($git_dir)/REVERT_HEAD" | path exists) {
        $operation_state = "REVERTING"
      } else if ($"($git_dir)/BISECT_LOG" | path exists) {
        $operation_state = "BISECTING"
      }
    }
    if ($operation_state | is-not-empty) {
      $git_segment = $git_segment + (pill_text $" ($operation_state)" $color_mauve $color_bg1 false)
    }

    mut conflicted_count = 0
    mut deleted_count = 0
    mut renamed_count = 0
    mut modified_count = 0
    mut staged_count = 0
    mut untracked_count = 0
    let porcelain_output = (git_output -- status --porcelain=v1)
    if ($porcelain_output | is-not-empty) {
      for entry in ($porcelain_output | lines) {
        if ($entry | is-empty) { continue }
        let index_char = ($entry | str substring 0..0)
        let worktree_char = ($entry | str substring 1..1)
        let status_pair = $"($index_char)($worktree_char)"
        if $status_pair == "??" {
          $untracked_count = $untracked_count + 1
          continue
        }
        if $status_pair in ["UU" "AA" "DD" "AU" "UA" "DU" "UD"] {
          $conflicted_count = $conflicted_count + 1
          continue
        }
        if $index_char != " " and $index_char != "?" { $staged_count = $staged_count + 1 }
        if $index_char == "R" { $renamed_count = $renamed_count + 1 }
        if $worktree_char == "M" { $modified_count = $modified_count + 1 }
        if $worktree_char == "D" { $deleted_count = $deleted_count + 1 }
      }
    }
    let stashed_count = (git_output -- stash list | lines | where {|entry| $entry | is-not-empty} | length)

    mut commits_ahead = 0
    mut commits_behind = 0
    let upstream_ref = (git_output -- rev-parse --abbrev-ref "@{upstream}")
    if ($upstream_ref | is-not-empty) {
      let ahead_behind_raw = (git_output -- rev-list --left-right --count "HEAD...@{upstream}")
      if ($ahead_behind_raw | is-not-empty) {
        let ahead_behind_parts = ($ahead_behind_raw | split row -r '\s+' | where {|part| $part | is-not-empty})
        if ($ahead_behind_parts | length) >= 2 {
          $commits_ahead = ($ahead_behind_parts | get 0 | into int)
          $commits_behind = ($ahead_behind_parts | get 1 | into int)
        }
      }
    }

    mut status_summary = ""
    if $conflicted_count > 0 { $status_summary = $status_summary + (pill_text $"($glyph_conflict)($conflicted_count) " $color_error $color_bg1 false) }
    if $deleted_count > 0 { $status_summary = $status_summary + (pill_text $"($glyph_deleted)($deleted_count) " $color_error $color_bg1 false) }
    if $renamed_count > 0 { $status_summary = $status_summary + (pill_text $"($glyph_renamed)($renamed_count) " $color_mauve $color_bg1 false) }
    if $modified_count > 0 { $status_summary = $status_summary + (pill_text $"($glyph_modified)($modified_count) " $color_gold $color_bg1 false) }
    if $staged_count > 0 { $status_summary = $status_summary + (pill_text $"($glyph_staged)($staged_count) " $color_sage $color_bg1 false) }
    if $untracked_count > 0 { $status_summary = $status_summary + (pill_text $"($glyph_untracked)($untracked_count) " $color_fg1 $color_bg1 false) }
    if $stashed_count > 0 { $status_summary = $status_summary + (pill_text $"($glyph_stashed)($stashed_count) " $color_steel $color_bg1 false) }
    if $commits_ahead > 0 and $commits_behind > 0 {
      $status_summary = $status_summary + (pill_text $"($glyph_ahead)($commits_ahead) ($glyph_behind)($commits_behind) " $color_ember_hot $color_bg1 false)
    } else if $commits_ahead > 0 {
      $status_summary = $status_summary + (pill_text $"($glyph_ahead)($commits_ahead) " $color_ember_hot $color_bg1 false)
    } else if $commits_behind > 0 {
      $status_summary = $status_summary + (pill_text $"($glyph_behind)($commits_behind) " $color_ember_hot $color_bg1 false)
    }
    if ($status_summary | is-not-empty) {
      $git_segment = $git_segment + (pill_text " " $color_bg1 $color_bg1 false) + $status_summary
    }

    if ($git_segment | is-not-empty) {
      $line = $line + (pill_open $color_bg1) + $git_segment + (pill_close $color_bg1) + " "
    }
  }

  if ($session_name | is-not-empty) or ($worktree_name | is-not-empty) {
    mut identity_segment = ""
    if ($session_name | is-not-empty) {
      $identity_segment = $identity_segment + (pill_text $session_name $color_gold $color_bg1 false)
    }
    if ($worktree_name | is-not-empty) {
      if ($identity_segment | is-not-empty) {
        $identity_segment = $identity_segment + (pill_text " " $color_bg1 $color_bg1 false)
      }
      $identity_segment = $identity_segment + (pill_text $"($glyph_git_branch) ($worktree_name)" $color_mauve $color_bg1 false)
    }
    $line = $line + (pill_open $color_bg1) + $identity_segment + (pill_close $color_bg1) + " "
  }

  if "IN_NIX_SHELL" in $env {
    let nix_shell_state = (match $env.IN_NIX_SHELL {
      "pure" => "pure",
      "impure" => "impure",
      _ => "shell",
    })
    $line = $line + (pill_open $color_bg1) + (pill_text $"($glyph_nix) ($nix_shell_state)" $color_steel $color_bg1 false) + (pill_close $color_bg1) + " "
  }

  if "DIRENV_DIR" in $env {
    $line = $line + (pill_open $color_bg1) + (pill_text $"($glyph_direnv) env" $color_sage $color_bg1 false) + (pill_close $color_bg1) + " "
  }

  let looks_like_python_project = (["pyproject.toml" "requirements.txt" "Pipfile" "setup.py"] | any {|f| $f | path exists}) or ((glob *.py) | is-not-empty)
  if $looks_like_python_project and ((which python3) | is-not-empty) {
    let python_version = (^python3 --version | str trim | split row " " | get 1)
    $line = $line + (pill_open $color_bg1) + (pill_text $" ($python_version)" $color_sage $color_bg1 false) + (pill_close $color_bg1) + " "
  }
  if ("package.json" | path exists) and ((which node) | is-not-empty) {
    let node_version = (^node --version | str trim)
    $line = $line + (pill_open $color_bg1) + (pill_text $" ($node_version)" $color_olive $color_bg1 false) + (pill_close $color_bg1) + " "
  }
  if ("Cargo.toml" | path exists) and ((which rustc) | is-not-empty) {
    let rust_version = (^rustc --version | str trim | split row " " | get 1)
    $line = $line + (pill_open $color_bg1) + (pill_text $" ($rust_version)" $color_mauve $color_bg1 false) + (pill_close $color_bg1) + " "
  }
  let looks_like_lua_project = ("init.lua" | path exists) or ((glob *.lua) | is-not-empty)
  if $looks_like_lua_project and ((which lua) | is-not-empty) {
    let lua_version = (^lua -v | complete | get stderr | str trim | split row " " | get 1)
    $line = $line + (pill_open $color_bg1) + (pill_text $" ($lua_version)" $color_steel $color_bg1 false) + (pill_close $color_bg1) + " "
  }

  let battery_dirs = (glob /sys/class/power_supply/BAT*)
  if ($battery_dirs | is-not-empty) {
    let battery_path = ($battery_dirs | get 0)
    let capacity_file = $"($battery_path)/capacity"
    if ($capacity_file | path exists) {
      let battery_percent = (open $capacity_file | into string | str trim | into int)
      let battery_status = (try { open $"($battery_path)/status" | str trim } catch { "" })
      if $battery_percent <= 30 {
        mut battery_icon = $" ($glyph_battery_low)"
        if $battery_status == "Charging" { $battery_icon = $" ($glyph_battery_charging)" }
        if $battery_status == "Full" { $battery_icon = $" ($glyph_battery_full)" }
        let battery_color = (if $battery_percent <= 15 { $color_error } else { $color_gold })
        let battery_bold = ($battery_percent <= 15)
        $line = $line + (pill_open $color_bg1) + (pill_text $"($battery_icon)($battery_percent)%" $battery_color $color_bg1 $battery_bold) + (pill_close $color_bg1) + " "
      }
    }
  }

  if ($session_duration_ms | is-not-empty) and $session_duration_ms > 0 {
    let uptime_minutes = ($session_duration_ms / 60000 | math floor)
    let uptime_label = (if $uptime_minutes >= 60 { $"($uptime_minutes // 60)h($uptime_minutes mod 60)m" } else { $"($uptime_minutes)m" })
    $line = $line + (pill_open $color_bg1) + (pill_text $"up ($uptime_label)" $color_fg1 $color_bg1 false) + (pill_close $color_bg1) + " "
  }

  if ($session_limit_percent | is-not-empty) or ($weekly_limit_percent | is-not-empty) {
    mut usage_segment = ""
    if ($session_limit_percent | is-not-empty) {
      let session_percent_rounded = ($session_limit_percent | math round)
      let session_limit_color = (if $session_percent_rounded >= 85 { $color_error } else if $session_percent_rounded >= 60 { $color_gold } else { $color_fg_soft })
      $usage_segment = $usage_segment + (pill_text $"5h ($session_percent_rounded)%" $session_limit_color $color_bg1 false)
      if ($session_limit_resets_at | is-not-empty) {
        $usage_segment = $usage_segment + (pill_text $"·(format_reset_time ($session_limit_resets_at | into int))" $color_fg1 $color_bg1 false)
      }
    }
    if ($weekly_limit_percent | is-not-empty) {
      let weekly_percent_rounded = ($weekly_limit_percent | math round)
      if ($usage_segment | is-not-empty) {
        $usage_segment = $usage_segment + (pill_text "  " $color_bg1 $color_bg1 false)
      }
      let weekly_limit_color = (if $weekly_percent_rounded >= 85 { $color_error } else if $weekly_percent_rounded >= 60 { $color_gold } else { $color_fg_soft })
      $usage_segment = $usage_segment + (pill_text $"7d ($weekly_percent_rounded)%" $weekly_limit_color $color_bg1 false)
      if ($weekly_limit_resets_at | is-not-empty) {
        $usage_segment = $usage_segment + (pill_text $"·(format_reset_time ($weekly_limit_resets_at | into int))" $color_fg1 $color_bg1 false)
      }
    }
    $line = $line + (pill_open $color_bg1) + $usage_segment + (pill_close $color_bg1) + " "
  }

  if ($context_used_percent | is-not-empty) {
    let context_percent_rounded = ($context_used_percent | math round)
    let context_color = (if $context_percent_rounded >= 85 { $color_error } else if $context_percent_rounded >= 60 { $color_gold } else { $color_sage })
    let context_bold = ($context_percent_rounded >= 85)
    $line = $line + (pill_open $color_bg1) + (pill_text $"ctx ($context_percent_rounded)%" $context_color $color_bg1 $context_bold) + (pill_close $color_bg1) + " "
  }

  if ($model_name | is-not-empty) {
    $line = $line + (pill_open $color_gold) + (pill_text $" ($model_name) " $color_bg0 $color_gold true) + (pill_close $color_gold)
  }

  if ($effort_level | is-not-empty) {
    $line = $line + " " + (pill_open $color_mauve) + (pill_text $" ($effort_level) " $color_bg0 $color_mauve false) + (pill_close $color_mauve)
  }

  print $line
}
