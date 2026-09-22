#!/usr/bin/env nu
# LocalSend protocol v2 client for the dani/localsend noctalia plugin.
#
# The plugin's Luau entries cannot do any of this themselves: noctalia has no
# UDP sockets (so discovery is impossible), and no way to stream a file body or
# observe an upload in flight. This script is the only place the protocol
# lives; the Luau side just spawns it and reads JSON.
#
# Subcommands
#   discover   announce over multicast, collect the replies, print a device array
#   stage      expand paths (recursing into directories) into a staged-file array
#   send       prepare-upload handshake + one upload per file, streaming progress
#
# `send` prints one JSON object per line (an event stream) and everything else
# prints a single JSON value. nu's stdout is unbuffered through a pipe, so
# noctalia.runStream sees each event as it happens.

const GROUP = "224.0.0.167"
const PORT = 53317
const PROTO_VERSION = "2.1"

# ─────────────────────────────────────────────────────────────── helpers ───

# LocalSend shows a file-type icon based on this; it does not have to be
# exact, so an extension table beats depending on `file` being installed.
def mime-for [name: string]: nothing -> string {
    let ext = ($name | path parse | get extension | str lowercase)
    match $ext {
        "jpg" | "jpeg" => "image/jpeg"
        "png" => "image/png"
        "gif" => "image/gif"
        "webp" => "image/webp"
        "svg" => "image/svg+xml"
        "heic" => "image/heic"
        "mp4" | "m4v" => "video/mp4"
        "mkv" => "video/x-matroska"
        "webm" => "video/webm"
        "mov" => "video/quicktime"
        "mp3" => "audio/mpeg"
        "flac" => "audio/flac"
        "ogg" | "opus" => "audio/ogg"
        "wav" => "audio/wav"
        "pdf" => "application/pdf"
        "zip" => "application/zip"
        "tar" => "application/x-tar"
        "gz" | "tgz" => "application/gzip"
        "zst" => "application/zstd"
        "7z" => "application/x-7z-compressed"
        "txt" | "md" | "log" => "text/plain"
        "json" => "application/json"
        "html" | "htm" => "text/html"
        "csv" => "text/csv"
        _ => "application/octet-stream"
    }
}

# One line of the event stream.
def emit [rec: record] {
    print ($rec | to json --raw)
}

# Single-quote a string for /bin/sh. Everything this script passes to sh is
# user-controlled (file paths, aliases), so nothing is interpolated raw.
def shq [s: string]: nothing -> string {
    "'" + ($s | str replace --all "'" "'\\''") + "'"
}

def pid-alive [pid: string]: nothing -> bool {
    if ($pid | str trim | is-empty) { return false }
    (^kill -0 $pid | complete | get exit_code) == 0
}

# Our identity on the network, shared with receiver.py (which serves it on
# /info and /register). Plain HTTP because there is no certificate.
def self-info [alias: string, fingerprint: string]: nothing -> record {
    {
        alias: $alias
        version: $PROTO_VERSION
        deviceModel: "noctalia"
        deviceType: "desktop"
        fingerprint: $fingerprint
        port: $PORT
        protocol: "http"
        download: false
    }
}

# ────────────────────────────────────────────────────────────── discover ───

# One sh per datagram. The whole line goes out in a single printf: with the
# prefix and the body as two writes, two datagrams landing together (our own
# announcement looping back plus a reply) interleave and the reply loses its
# PEER= prefix.
const UDP_HANDLER = r#'
body=$(cat | tr -d '\r\n')
printf 'PEER=%s %s\n' "$SOCAT_PEERADDR" "$body" >> __TMP__
'#

# LocalSend's own fallback: ask every host on our /24 for its /info. Needed
# when receiver.py is not listening (the LocalSend app holds 53317) and when
# the access point drops multicast between clients. Prints one
# "<ip> <protocol> <json>" line per LocalSend host; ~2-3s for a /24.
def subnet-scan [curl: string, only: string]: nothing -> list {
    let hosts = if ($only | is-not-empty) {
        $only | split row ","
    } else {
        let src = (try { ^ip -j route get $GROUP | from json | get 0.prefsrc } catch { "" })
        if ($src | is-empty) { return [] }
        let prefix = ($src | split row "." | first 3 | str join ".")
        1..254 | each {|n| $"($prefix).($n)" } | where {|h| $h != $src }
    }
    # Only a successful probe prints a line, protocol first so the body can be
    # anything. https is what LocalSend ships with; http is its
    # encryption-off mode.
    let probe = "c=" + (shq $curl) + "; b=$($c -skf -m 1.5 \"https://$1:53317/api/localsend/v2/info\" 2>/dev/null) && printf '%s https %s\\n' \"$1\" \"$b\" || { b=$($c -sf -m 1.5 \"http://$1:53317/api/localsend/v2/info\" 2>/dev/null) && printf '%s http %s\\n' \"$1\" \"$b\"; }; true"
    $hosts | str join "\n"
    | ^xargs -P 128 -I{} sh -c $probe _ {}
    | lines
    | each {|line|
        let m = ($line | parse --regex '^(?<ip>[0-9.]+) (?<protocol>https?) (?<body>\{.*\})$')
        if ($m | is-empty) { return null }
        let row = ($m | first)
        let payload = (try { $row.body | from json } catch { null })
        if $payload == null { return null }
        {alias: "unknown", deviceType: "desktop", deviceModel: "", port: $PORT, protocol: $row.protocol, fingerprint: "", download: false}
        | merge $payload
        | insert ip $row.ip
    }
    | compact
}

# Announce ourselves on the multicast group and collect the answers. Since the
# LocalSend core rewrite a device answers an announcement in exactly one way:
# `POST /api/localsend/v2/register` to the announcer's ip:port, over the
# protocol the announcement named. That endpoint is receiver.py (spawned by
# service.luau), which appends "<epoch ms> <ip> <body>" to --registrations for
# every register it gets; a sweep reads the lines newer than itself. The UDP
# listener stays for pre-rewrite builds that still reply by multicast, and the
# /info subnet scan covers the receiver being down (LocalSend app holding the
# port) and access points that drop multicast.
export def "main discover" [
    --socat: string = "socat"
    --curl: string = "curl"
    --alias: string = "noctalia"
    --fingerprint: string = ""
    --window: int = 2000 # ms to listen after announcing
    --registrations: string = "" # receiver.py's registrations.log
    --receiver-up # the service believes receiver.py is listening
    --scan-hosts: string = "" # tests: comma-separated hosts to probe instead of the /24
]: nothing -> nothing {
    let start = ((date now | into int) / 1_000_000 | math floor)
    let tmp = (mktemp -t "localsend-discover-XXXXXX")
    let errf = (mktemp -t "localsend-discover-err-XXXXXX")
    let udp_handler = (mktemp -t "localsend-udp-XXXXXX")
    let secs = ($window / 1000 + 0.4)

    let me = (self-info $alias $fingerprint)
    $UDP_HANDLER | str replace --all "__TMP__" (shq $tmp) | save --force $udp_handler

    # Listener first, so it is up before our announcement provokes the
    # answers. `timeout` bounds it instead of a kill, so no pid bookkeeping.
    let udp = $"timeout ($secs) (shq $socat) -u 'UDP4-RECVFROM:($PORT),ip-add-membership=($GROUP):0.0.0.0,reuseaddr,fork' SYSTEM:(shq $"sh ($udp_handler)") 2>> (shq $errf) &"
    ^sh -c $udp
    sleep 250ms

    # Twice, like LocalSend's own burst: a peer that was mid-scan on the first
    # datagram answers the second.
    let announcement = ($me | merge {announce: true, announcement: true} | to json --raw)
    for delay in [0ms 600ms] {
        sleep $delay
        $announcement | ^$socat -u - $"UDP4-DATAGRAM:($GROUP):($PORT),ip-multicast-ttl=4"
    }

    sleep (($window * 1ms) - 600ms)

    let raw = (try { open --raw $tmp | lines } catch { [] })
    let errs = (try { open --raw $errf | str trim } catch { "" })
    let registered = (try { open --raw $registrations | lines } catch { [] })
    # Diagnostics on stderr: the caller logs them when a sweep comes back
    # empty, which is the difference between "nobody answered" and "the
    # listener never started".
    # NB no "(s)" in these strings: parentheses inside $"..." are evaluated.
    print --stderr $"discover: ($raw | length) udp lines, ($registered | length) registration lines"
    if not $receiver_up {
        print --stderr "discover: receiver is not running (LocalSend app holding 53317?), peers cannot register; scanning the subnet instead"
    } else if ($errs | is-not-empty) {
        print --stderr $"discover: listener: ($errs | str substring 0..300)"
    }
    rm --force $tmp $errf $udp_handler

    # Defaults first, parsed payload over them: announcements from
    # older/other implementations may omit fields.
    let defaults = {alias: "unknown", deviceType: "desktop", deviceModel: "", port: $PORT, protocol: "https", fingerprint: "", download: false}
    let from_udp = ($raw
        | each {|line|
            let m = ($line | parse --regex '^PEER=(?<ip>[0-9.]+)\s*(?<body>\{.*\})$')
            if ($m | is-empty) { return null }
            let row = ($m | first)
            let payload = (try { $row.body | from json } catch { null })
            if $payload == null { return null }
            $defaults | merge $payload | insert ip $row.ip
        }
        | compact)
    let from_register = ($registered
        | each {|line|
            let m = ($line | parse --regex '^(?<ts>\d+) (?<ip>[0-9.]+) (?<body>\{.*\})$')
            if ($m | is-empty) { return null }
            let row = ($m | first)
            if ($row.ts | into int) < $start { return null }
            let payload = (try { $row.body | from json } catch { null })
            if $payload == null { return null }
            $defaults | merge $payload | insert ip $row.ip
        }
        | compact)
    let announced = ($from_udp ++ $from_register)

    let scanned = if (not $receiver_up) or ($announced | where fingerprint != $fingerprint | is-empty) {
        let found = (subnet-scan $curl $scan_hosts)
        print --stderr $"discover: subnet scan answered by ($found | length) hosts"
        $found
    } else {
        []
    }

    let devices = ($announced ++ $scanned
        | where fingerprint != $fingerprint
        | where fingerprint != ""
        | uniq-by fingerprint
        | select alias fingerprint ip port protocol deviceType deviceModel download)

    print ($devices | to json --raw)
}

# ───────────────────────────────────────────────────────────────── stage ───

# Paths stay UNRESOLVED so the receiver gets a sensible name: on NixOS most of
# /etc is a symlink into the store, and `path expand` would name the file after
# a store hash. Only the size lookup follows the link.
def stage-entry [full: string, name: string]: nothing -> record {
    {
        path: $full
        name: $name
        size: (ls --directory --full-paths ($full | path expand) | get 0.size | into int)
        type: (mime-for $name)
    }
}

# Expand one path into staged entries. A directory becomes all of its files,
# named relative to the directory's parent, so dropping ~/pics/holiday sends
# "holiday/day1/a.jpg" and the receiver rebuilds the tree.
def stage-one [p: string]: nothing -> list {
    # A path that does not exist (deleted since the drop, a stray line) makes
    # `path expand` yield nothing and would abort the whole batch; skip it.
    if not ($p | path exists) { return [] }
    let full = ($p | path expand --no-symlink)
    let kind = ($p | path expand | path type) # follow the link to classify it
    if $kind == "dir" {
        let base = ($full | path dirname)
        # cd first: the directory name must not be part of the glob pattern,
        # or a folder called "shots [1]" matches nothing.
        do { cd $full; glob "**/*" --no-dir }
        | each {|f| stage-entry $f ($f | path relative-to $base) }
    } else if $kind == "file" {
        [(stage-entry $full ($full | path basename))]
    } else {
        []
    }
}

# --from-file reads one path per line, which is exactly what ripdrag and
# zenity print. Going through a file (rather than a pipe) keeps the caller a
# single /bin/sh command and avoids depending on xargs/stdin semantics.
export def "main stage" [
    ...paths: string
    --from-file: string = ""
]: nothing -> nothing {
    let list = if ($from_file | is-not-empty) {
        try { open --raw $from_file | lines | where {|l| ($l | str trim) != "" } } catch { [] }
    } else {
        $paths
    }
    let out = ($list | each {|p| stage-one $p } | flatten)
    print ($out | to json --raw)
}

# ────────────────────────────────────────────────────────────────── send ───

# Run curl detached and poll it, so that a cancel request can land WHILE the
# request is in flight. That matters most for prepare-upload, which blocks
# until the person on the other end taps Accept.
#
# Returns {code, body, cancelled}.
def curl-poll [
    curl: string
    argv: list<string>
    cancel_file: string
    --progress: record # {index, name, size} -> emit progress events, or null
]: nothing -> record {
    let body_f = (mktemp -t "localsend-body-XXXXXX")
    let status_f = (mktemp -t "localsend-status-XXXXXX")
    let meter_f = (mktemp -t "localsend-meter-XXXXXX")
    let pid_f = (mktemp -t "localsend-pid-XXXXXX")

    let quoted = ($argv | each {|a| shq $a } | str join " ")
    # -w writes the status code only once the transfer completes, so a
    # non-empty status file is an unambiguous "curl finished" signal.
    ^sh -c $"(shq $curl) ($quoted) -o (shq $body_f) -w '%{http_code}' > (shq $status_f) 2> (shq $meter_f) & echo $! > (shq $pid_f)"
    sleep 120ms
    let pid = (try { open --raw $pid_f | str trim } catch { "" })

    mut cancelled = false
    mut last_pct = -1
    loop {
        let status = (try { open --raw $status_f | str trim } catch { "" })
        if ($status | is-not-empty) { break }

        if ($cancel_file | is-not-empty) and ($cancel_file | path exists) {
            if (pid-alive $pid) { ^kill $pid }
            $cancelled = true
            break
        }

        if not (pid-alive $pid) {
            # Died without writing a status (connection refused, TLS failure).
            sleep 150ms
            break
        }

        if $progress != null {
            let pct = (read-meter-pct $meter_f)
            if $pct >= 0 and $pct != $last_pct {
                $last_pct = $pct
                emit {
                    event: "progress"
                    index: $progress.index
                    name: $progress.name
                    percent: $pct
                    speed: (read-meter-speed $meter_f)
                }
            }
        }

        sleep 250ms
    }

    let code = (try { open --raw $status_f | str trim } catch { "" })
    let body = (try { open --raw $body_f } catch { "" })
    rm --force $body_f $status_f $meter_f $pid_f
    {code: $code, body: $body, cancelled: $cancelled}
}

# curl's progress meter is \r-separated; the last complete row wins.
# Columns: [0]=% total [1]=total ... [11]=current speed.
def meter-cols [meter_f: string]: nothing -> list {
    let raw = (try { open --raw $meter_f } catch { "" })
    if ($raw | is-empty) { return [] }
    let rows = ($raw | str replace --all "\r" "\n" | lines | where {|l| ($l | str trim) != "" })
    if ($rows | is-empty) { return [] }
    $rows | last | str trim | split row --regex '\s+'
}

def read-meter-pct [meter_f: string]: nothing -> int {
    let cols = (meter-cols $meter_f)
    if ($cols | is-empty) { return (-1) }
    let first = ($cols | first)
    if ($first =~ '^[0-9]+$') { $first | into int } else { -1 }
}

def read-meter-speed [meter_f: string]: nothing -> string {
    let cols = (meter-cols $meter_f)
    if ($cols | length) < 12 { return "" }
    $cols | get 11
}

# Send the staged files described by a job JSON file:
#   {device: {ip, port, protocol, alias}, pin?: string,
#    alias: string, fingerprint: string,
#    files: [{path, name, size, type, preview?}]}
export def "main send" [
    job: string # path to the job JSON
    --curl: string = "curl"
    --cancel-file: string = "" # touch this path to abort in flight
]: nothing -> nothing {
    # The Luau side only ever sees stdout lines, and treats the stream as live
    # until a terminal event arrives. An uncaught nu error would go to stderr
    # and leave the plugin waiting forever, so every failure becomes an event.
    try {
        send-job $job $curl $cancel_file
    } catch {|e|
        emit {event: "error", stage: "internal", code: 0, message: $"internal error: ($e.msg)"}
    }
}

def send-job [job: string, curl: string, cancel_file: string]: nothing -> nothing {
    let j = (open --raw $job | from json)
    let dev = $j.device
    let base = $"($dev.protocol)://($dev.ip):($dev.port)/api/localsend/v2"
    let pin = ($j.pin? | default "")

    if ($j.files | is-empty) {
        emit {event: "error", stage: "prepare", code: 0, message: "no files staged"}
        return
    }

    # ── prepare-upload: ids are positional so the response tokens map back ──
    let entries = ($j.files | enumerate | each {|it|
        let f = $it.item
        let id = $"f($it.index)"
        let core = {id: $id, fileName: $f.name, size: $f.size, fileType: $f.type}
        let preview = ($f.preview? | default "")
        {id: $id, entry: (if ($preview | is-empty) { $core } else { $core | insert preview $preview })}
    })
    let body = {
        # `port` in the job overrides ours: the receiver proves a pinned
        # sender by a TLS handshake to info.port, which tests point elsewhere.
        info: (self-info ($j.alias? | default "noctalia") ($j.fingerprint? | default "") | merge {port: ($j.port? | default $PORT)})
        files: ($entries | reduce --fold {} {|it, acc| $acc | insert $it.id $it.entry })
    }

    let prep_url = if ($pin | is-empty) { $"($base)/prepare-upload" } else { $"($base)/prepare-upload?pin=($pin)" }
    emit {event: "prepare", device: $dev.alias, files: ($j.files | length)}

    let prep = (curl-poll $curl [
        "-sk" "-X" "POST" "-H" "Content-Type: application/json"
        "--data-binary" ($body | to json --raw) "--max-time" "300" $prep_url
    ] $cancel_file)

    if $prep.cancelled {
        emit {event: "cancelled", stage: "prepare"}
        return
    }
    if $prep.code != "200" {
        emit {
            event: "error"
            stage: "prepare"
            code: (if ($prep.code | is-empty) { 0 } else { $prep.code | into int })
            message: (prepare-error $prep.code $prep.body)
        }
        return
    }

    let session = (try { $prep.body | from json } catch { null })
    if $session == null or ($session.sessionId? | default "" | is-empty) {
        emit {event: "error", stage: "prepare", code: 200, message: "unparseable prepare-upload response"}
        return
    }
    emit {event: "accepted", session: $session.sessionId}

    # ── upload, one request per file ──
    mut sent = 0
    for it in ($entries | enumerate) {
        let idx = $it.index
        let id = $it.item.id
        let f = ($j.files | get $idx)
        let token = ($session.files | get --optional $id)
        if ($token | is-empty) {
            # The receiver may decline individual files; skip rather than abort.
            emit {event: "skipped", index: $idx, name: $f.name, reason: "no token"}
            continue
        }

        emit {event: "file", index: $idx, name: $f.name, size: $f.size, total: ($entries | length)}
        let url = $"($base)/upload?sessionId=($session.sessionId)&fileId=($id)&token=($token)"
        # -T streams from disk (--data-binary would read the whole file into
        # memory) and still sends a real Content-Length.
        let up = (curl-poll $curl [
            "-k" "-X" "POST" "-T" $f.path "-H" "Expect:" "--max-time" "3600" $url
        ] $cancel_file --progress {index: $idx, name: $f.name, size: $f.size})

        if $up.cancelled {
            cancel-session $curl $base $session.sessionId
            emit {event: "cancelled", stage: "upload", index: $idx}
            return
        }
        if not ($up.code in ["200" "202" "204"]) {
            emit {
                event: "error"
                stage: "upload"
                index: $idx
                name: $f.name
                code: (if ($up.code | is-empty) { 0 } else { $up.code | into int })
                message: (if ($up.code in ["" "000"]) { "upload failed (connection lost)" } else { $up.body | str substring 0..200 })
            }
            return
        }
        emit {event: "file_done", index: $idx, name: $f.name}
        $sent += 1
    }

    emit {event: "done", sent: $sent}
}

def prepare-error [code: string, body: string]: nothing -> string {
    match $code {
        # curl reports 000 when it never got a response at all (refused,
        # TLS handshake failure, timeout); empty means it died before -w ran.
        "" | "000" => "no response (device unreachable)"
        "401" => "PIN required or incorrect"
        "403" => "declined"
        "409" => "device is busy with another transfer"
        "429" => "too many requests, try again"
        _ => (if ($body | str trim | is-empty) { $"HTTP ($code)" } else { $body | str substring 0..200 })
    }
}

# Best-effort: tell the receiver to drop the session so it does not sit on a
# half-open transfer waiting for bytes that will never arrive.
def cancel-session [curl: string, base: string, session: string] {
    ^sh -c $"(shq $curl) -sk -X POST (shq $"($base)/cancel?sessionId=($session)") -o /dev/null --max-time 5 &"
}

export def main []: nothing -> nothing {
    print "usage: localsend.nu [discover|stage|send] ..."
}
