# Focuses an app's window when one of its notifications is clicked.
#
# Noctalia only tells the app about the click (ActionInvoked, plus an
# activation token); raising the window is left to the app, and most don't
# manage it: GTK drops the token and asks Hyprland with a token of its own,
# which Hyprland refuses, and kitty never asks. So this watches the session bus
# instead, remembers which app each notification came from, and focuses that
# app's window itself when its notification is clicked.
#
# Argv: <path to busctl> <path to hyprctl>

# The app id goes into Lua source, so only a plain one gets through.
const APP_ID = '^[A-Za-z0-9._-]+$'

# The focus dispatcher, not an activation request: it also switches to a hidden
# workspace on another monitor and brings up a hidden hy3 tab.
def focus-app [hyprctl: string, app: string] {
  if $app !~ $APP_ID { return }
  # Already in that app: leave it alone, the first window of that class may not
  # be the one the notification is about.
  let active = (^$hyprctl activewindow -j | complete).stdout
  if (try { $active | from json | get -o class } catch { null }) == $app { return }
  let class = ($app | str replace --all "." "[.]")
  ^$hyprctl eval ('hl.dispatch(hl.dsp.focus({ window = "class:^' + $class + '$" }))') | complete | ignore
}

def main [busctl: string, hyprctl: string] {
  let rules = [
    "type='method_call',interface='org.freedesktop.Notifications',member='Notify'"
    "type='method_return',sender='org.freedesktop.Notifications'"
    "type='signal',interface='org.freedesktop.Notifications'"
  ]
  let matches = ($rules | each {|rule| ["--match" $rule] } | flatten)

  # A Notify call names the app (its desktop-entry hint, which is also its
  # window class), but the notification's id only comes back in the reply.
  mut calls = {} # "<caller>_<cookie>" of a Notify call awaiting its reply -> app
  mut apps = {} # id of a notification still showing -> app

  for line in (^$busctl --user monitor --json=short ...$matches | lines) {
    let msg = (try { $line | from json } catch { null })
    if $msg == null { continue }

    if $msg.type == "method_call" {
      let app = ($msg.payload.data | get 6 | get -o "desktop-entry" | get -o data)
      if $app != null {
        $calls = ($calls | upsert (call-key $msg.sender $msg.cookie) $app)
      }
    } else if $msg.type == "method_return" {
      let key = (call-key $msg.destination $msg.reply_cookie)
      let app = ($calls | get -o $key)
      if $app != null {
        $calls = ($calls | reject $key)
        $apps = ($apps | upsert $"n($msg.payload.data.0)" $app)
      }
    } else if $msg.member == "ActionInvoked" {
      # "default" is the click on the notification itself; its buttons (mark
      # as read, archive, ...) have other keys and should not steal focus.
      let app = ($apps | get -o $"n($msg.payload.data.0)")
      if $app != null and $msg.payload.data.1 == "default" { focus-app $hyprctl $app }
    } else if $msg.member == "NotificationClosed" {
      $apps = ($apps | reject -o $"n($msg.payload.data.0)")
    }
  }
}

# Record keys are cell paths, where a dot would nest: ":1.70" must not.
def call-key [peer: string, cookie: int] {
  $"($peer | str replace --all '.' '_')_($cookie)"
}
