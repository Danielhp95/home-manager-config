#!/usr/bin/env bash
# Exercises localsend.nu send against fake_receiver.py: the accept path plus
# the failure branches that are impractical to trigger against the real app.
#
#   ./tests/run_tests.sh
#
# Needs nu and curl on PATH. Prints PASS/FAIL per case; exits nonzero on any
# failure.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
NU="${NU:-nu}"
SCRIPT="$HERE/../localsend.nu"
WORK="$(mktemp -d -t localsend-tests-XXXXXX)"
PORT=8399
FAILED=0

cleanup() { pkill -f "fake_receiver.py --port $PORT" 2>/dev/null; [ -n "${RECV_PID:-}" ] && kill "$RECV_PID" 2>/dev/null; rm -rf "$WORK"; }
trap cleanup EXIT

start_receiver() { # mode [extra args...]
  local mode="$1"; shift
  pkill -f "fake_receiver.py --port $PORT" 2>/dev/null
  rm -rf "$WORK/out"; mkdir -p "$WORK/out"
  python3 "$HERE/fake_receiver.py" --port "$PORT" --out "$WORK/out" --mode "$mode" "$@" \
    > "$WORK/receiver.log" 2>&1 &
  for _ in $(seq 1 40); do
    grep -q "listening" "$WORK/receiver.log" 2>/dev/null && return 0
    sleep 0.1
  done
  echo "receiver failed to start"; cat "$WORK/receiver.log"; return 1
}

job() { # pin files-json -> job file
  local pin="$1" files="$2"
  cat > "$WORK/job.json" <<EOF
{"device": {"ip": "127.0.0.1", "port": $PORT, "protocol": "http", "alias": "fake"},
 "pin": $pin, "alias": "noctalia-test", "fingerprint": "TESTFINGERPRINT",
 "files": $files}
EOF
  echo "$WORK/job.json"
}

check() { # name expected-substring file
  local name="$1" needle="$2" file="$3"
  if grep -qF -- "$needle" "$file"; then
    echo "  PASS  $name"
  else
    echo "  FAIL  $name (no '$needle')"; sed 's/^/        /' "$file"; FAILED=1
  fi
}

echo "work dir: $WORK"
printf 'hello localsend\n' > "$WORK/a.txt"
head -c 3000000 /dev/urandom > "$WORK/b.bin"
FILES="[{\"path\": \"$WORK/a.txt\", \"name\": \"a.txt\", \"size\": $(stat -c%s "$WORK/a.txt"), \"type\": \"text/plain\"},
        {\"path\": \"$WORK/b.bin\", \"name\": \"sub/b.bin\", \"size\": $(stat -c%s "$WORK/b.bin"), \"type\": \"application/octet-stream\"}]"

echo "== accept: two files, one nested =="
start_receiver accept || exit 1
$NU --no-config-file "$SCRIPT" send "$(job null "$FILES")" > "$WORK/out.jsonl" 2>&1
check "prepare event"  '"event":"prepare"'   "$WORK/out.jsonl"
check "accepted event" '"event":"accepted"'  "$WORK/out.jsonl"
check "file_done a"    '"name":"a.txt"'      "$WORK/out.jsonl"
check "done sent=2"    '"event":"done","sent":2' "$WORK/out.jsonl"
if cmp -s "$WORK/a.txt" "$WORK/out/a.txt" && cmp -s "$WORK/b.bin" "$WORK/out/sub/b.bin"; then
  echo "  PASS  bytes match on both files (nested path preserved)"
else
  echo "  FAIL  received bytes differ"; FAILED=1
fi

echo "== decline (403) =="
start_receiver decline || exit 1
$NU --no-config-file "$SCRIPT" send "$(job null "$FILES")" > "$WORK/out.jsonl" 2>&1
check "error declined" '"message":"declined"' "$WORK/out.jsonl"

echo "== PIN required (401), then correct PIN =="
start_receiver pin || exit 1
$NU --no-config-file "$SCRIPT" send "$(job null "$FILES")" > "$WORK/out.jsonl" 2>&1
check "error pin" '"message":"PIN required or incorrect"' "$WORK/out.jsonl"
$NU --no-config-file "$SCRIPT" send "$(job '"1234"' "$FILES")" > "$WORK/out2.jsonl" 2>&1
check "pin accepted" '"event":"done","sent":2' "$WORK/out2.jsonl"

echo "== busy (409) =="
start_receiver busy || exit 1
$NU --no-config-file "$SCRIPT" send "$(job null "$FILES")" > "$WORK/out.jsonl" 2>&1
check "error busy" 'busy with another transfer' "$WORK/out.jsonl"

echo "== unreachable device =="
pkill -f "fake_receiver.py --port $PORT" 2>/dev/null; sleep 0.3
$NU --no-config-file "$SCRIPT" send "$(job null "$FILES")" > "$WORK/out.jsonl" 2>&1
check "error unreachable" 'unreachable' "$WORK/out.jsonl"

echo "== cancel while waiting for accept =="
start_receiver slow --delay 8 || exit 1
CANCEL="$WORK/cancel.flag"; rm -f "$CANCEL"
$NU --no-config-file "$SCRIPT" send "$(job null "$FILES")" --cancel-file "$CANCEL" > "$WORK/out.jsonl" 2>&1 &
SEND_PID=$!
sleep 2; touch "$CANCEL"
wait $SEND_PID
check "cancelled in prepare" '"event":"cancelled","stage":"prepare"' "$WORK/out.jsonl"

# curl only writes a progress row about once a second, so the transfer has to
# last several seconds for intermediate progress to exist at all.
echo "== progress events on a throttled upload =="
start_receiver accept --throttle 0.08 || exit 1
$NU --no-config-file "$SCRIPT" send "$(job null "$FILES")" > "$WORK/out.jsonl" 2>&1
N=$(grep -c '"event":"progress"' "$WORK/out.jsonl")
if [ "$N" -ge 2 ]; then
  echo "  PASS  $N progress events"
else
  echo "  FAIL  only $N progress events"; sed 's/^/        /' "$WORK/out.jsonl"; FAILED=1
fi

# Discovery: the receiver answers our multicast announcement the way current
# LocalSend does, with an HTTP register POST to our ip:53317, so this also
# covers the responder localsend.nu runs for the length of a sweep.
# receiver.py (the plugin's own server, see the receive section below) is the
# register endpoint peers answer to; a sweep reads its registrations.log.
RDL="$WORK/downloads"; mkdir -p "$RDL"
echo '[]' > "$WORK/favs.json"
start_receiver_53317() { # data-dir -> starts receiver.py on the real port, waits for listening
  rm -rf "$1"; mkdir -p "$1"
  python3 "$HERE/../receiver.py" --port 53317 --alias fake-laptop --fingerprint TESTFINGERPRINT \
    --download-dir "$RDL" --data-dir "$1" --favourites "$WORK/favs.json" > "$1/events.jsonl" 2> "$1/err.log" &
  DISCO_PID=$!
  for _ in $(seq 1 40); do
    grep -q '"event": "listening"' "$1/events.jsonl" 2>/dev/null && return 0
    sleep 0.1
  done
  echo "receiver.py failed to start on 53317"; cat "$1/events.jsonl" "$1/err.log"; return 1
}

echo "== discover: peer registers over HTTP with receiver.py =="
start_receiver_53317 "$WORK/rdisco" || exit 1
start_receiver accept --announce --alias fake-disco || exit 1
$NU --no-config-file "$SCRIPT" discover --alias noctalia-test --fingerprint TESTFINGERPRINT --window 1500 \
  --registrations "$WORK/rdisco/registrations.log" --receiver-up > "$WORK/disco.json" 2> "$WORK/disco.err"
kill $DISCO_PID 2>/dev/null; wait $DISCO_PID 2>/dev/null
check "found fake-disco" '"alias":"fake-disco"' "$WORK/disco.json"
if grep -q "registered with" "$WORK/receiver.log"; then
  echo "  PASS  receiver used HTTP register"
else
  echo "  FAIL  receiver did not register"; cat "$WORK/receiver.log" "$WORK/disco.err"; FAILED=1
fi

echo "== discover: legacy receiver replies over UDP =="
start_receiver accept --announce --udp-reply --alias fake-udp || exit 1
$NU --no-config-file "$SCRIPT" discover --alias noctalia-test --fingerprint TESTFINGERPRINT --window 1500 > "$WORK/disco.json" 2> "$WORK/disco.err"
check "found fake-udp" '"alias":"fake-udp"' "$WORK/disco.json"

# The LocalSend app scenario: something else holds 53317, so the register
# responder cannot bind and discovery must fall back to the /info subnet scan.
# The LocalSend app scenario: something else answers /info on 53317 and the
# service knows its receiver is down, so discovery falls back to the subnet
# scan. receiver.py stands in for the app here (it serves /info too).
echo "== discover: receiver down -> subnet scan fallback =="
start_receiver_53317 "$WORK/rscan" || exit 1
$NU --no-config-file "$SCRIPT" discover --alias noctalia-test --fingerprint OTHERFINGERPRINT --window 800 \
  --registrations "$WORK/nonexistent.log" --scan-hosts 127.0.0.1 > "$WORK/disco.json" 2> "$WORK/disco.err"
kill $DISCO_PID 2>/dev/null; wait $DISCO_PID 2>/dev/null
check "reported receiver down" 'receiver is not running' "$WORK/disco.err"
check "found fake-laptop by scan" '"alias":"fake-laptop"' "$WORK/disco.json"

# ───────────────────────────────────────────────── receive (receiver.py) ───
# receiver.py is driven by our own sender. A decision is a file the panel
# would write; here the test writes it once the receiver has emitted the
# `request` event (which carries the session id).
RPORT=8398
RDATA="$WORK/rdata"
RECV_PID=""

start_receiver_py() { # extra args...
  [ -n "$RECV_PID" ] && kill "$RECV_PID" 2>/dev/null
  rm -rf "$RDATA" "$RDL"; mkdir -p "$RDATA" "$RDL"
  python3 "$HERE/../receiver.py" --port "$RPORT" --alias fake-laptop --fingerprint RECVFINGERPRINT \
    --download-dir "$RDL" --data-dir "$RDATA" --favourites "$WORK/favs.json" --decision-timeout 3 "$@" \
    > "$WORK/recv_events.jsonl" 2> "$WORK/recv.err" &
  RECV_PID=$!
  for _ in $(seq 1 40); do
    grep -q '"event": "listening"' "$WORK/recv_events.jsonl" 2>/dev/null && return 0
    sleep 0.1
  done
  echo "receiver.py failed to start"; cat "$WORK/recv.err"; return 1
}

LAST_SID=""
decide() { # accept|decline|cancel -> waits for a new request event, writes the decision
  local sid=""
  for _ in $(seq 1 50); do
    sid=$(grep -o '"session": "[0-9a-f]*"' "$WORK/recv_events.jsonl" 2>/dev/null | tail -1 | grep -o '[0-9a-f]\{32\}')
    [ -n "$sid" ] && [ "$sid" != "$LAST_SID" ] && [ "$1" != "cancel" ] && break
    [ -n "$sid" ] && [ "$1" = "cancel" ] && break
    sleep 0.1
  done
  [ -z "$sid" ] && { echo "  FAIL  no request event to decide on"; FAILED=1; return 1; }
  LAST_SID="$sid"
  echo "$1" > "$RDATA/decisions/$sid"
}

rjob() { # files-json -> job file targeting receiver.py
  cat > "$WORK/rjob.json" <<EOF
{"device": {"ip": "127.0.0.1", "port": $RPORT, "protocol": "http", "alias": "fake-laptop"},
 "pin": null, "alias": "noctalia-test", "fingerprint": "SENDERFINGERPRINT",
 "files": $1}
EOF
  echo "$WORK/rjob.json"
}

echo "== receive: accept two files, one nested =="
start_receiver_py || exit 1
$NU --no-config-file "$SCRIPT" send "$(rjob "$FILES")" > "$WORK/out.jsonl" 2>&1 &
SEND_PID=$!; decide accept; wait $SEND_PID
check "request event"   '"event": "request"'   "$WORK/recv_events.jsonl"
check "not auto"        '"auto": false'         "$WORK/recv_events.jsonl"
check "accepted event"  '"event": "accepted"'  "$WORK/recv_events.jsonl"
check "done received=2" '"received": 2'        "$WORK/recv_events.jsonl"
check "sender done"     '"event":"done","sent":2' "$WORK/out.jsonl"
if cmp -s "$WORK/a.txt" "$RDL/a.txt" && cmp -s "$WORK/b.bin" "$RDL/sub/b.bin"; then
  echo "  PASS  received bytes match (nested path preserved)"
else
  echo "  FAIL  received bytes differ"; ls -R "$RDL"; FAILED=1
fi
[ -z "$(ls "$RDL" | grep '\.part$')" ] && echo "  PASS  no .part left behind" || { echo "  FAIL  .part left"; FAILED=1; }

echo "== receive: decline =="
start_receiver_py || exit 1
$NU --no-config-file "$SCRIPT" send "$(rjob "$FILES")" > "$WORK/out.jsonl" 2>&1 &
SEND_PID=$!; decide decline; wait $SEND_PID
check "declined event" '"event": "declined"' "$WORK/recv_events.jsonl"
check "sender got 403" '"message":"declined"' "$WORK/out.jsonl"

echo "== receive: no decision -> timeout =="
start_receiver_py || exit 1
$NU --no-config-file "$SCRIPT" send "$(rjob "$FILES")" > "$WORK/out.jsonl" 2>&1
check "timeout event"  '"event": "timeout"'  "$WORK/recv_events.jsonl"
check "sender got 403" '"message":"declined"' "$WORK/out.jsonl"

echo "== receive: pinned sender is auto-accepted =="
echo '[{"fingerprint": "SENDERFINGERPRINT", "alias": "noctalia-test"}]' > "$WORK/favs.json"
start_receiver_py || exit 1
$NU --no-config-file "$SCRIPT" send "$(rjob "$FILES")" > "$WORK/out.jsonl" 2>&1
check "auto true"   '"auto": true'          "$WORK/recv_events.jsonl"
check "sender done" '"event":"done","sent":2' "$WORK/out.jsonl"

echo "== receive: pinned sender still prompted with --no-auto-accept =="
start_receiver_py --no-auto-accept || exit 1
$NU --no-config-file "$SCRIPT" send "$(rjob "$FILES")" > "$WORK/out.jsonl" 2>&1 &
SEND_PID=$!; decide accept; wait $SEND_PID
check "auto false" '"auto": false' "$WORK/recv_events.jsonl"
echo '[]' > "$WORK/favs.json"

echo "== receive: name collision gets (1) suffix =="
start_receiver_py || exit 1
ONE="[{\"path\": \"$WORK/a.txt\", \"name\": \"a.txt\", \"size\": $(stat -c%s "$WORK/a.txt"), \"type\": \"text/plain\"}]"
for _ in 1 2; do
  $NU --no-config-file "$SCRIPT" send "$(rjob "$ONE")" > "$WORK/out.jsonl" 2>&1 &
  SEND_PID=$!; decide accept; wait $SEND_PID
done
[ -f "$RDL/a.txt" ] && [ -f "$RDL/a (1).txt" ] && echo "  PASS  a.txt and a (1).txt" || { echo "  FAIL  collision"; ls "$RDL"; FAILED=1; }

echo "== receive: empty file =="
start_receiver_py || exit 1
: > "$WORK/empty.bin"
EMPTY="[{\"path\": \"$WORK/empty.bin\", \"name\": \"empty.bin\", \"size\": 0, \"type\": \"application/octet-stream\"}]"
$NU --no-config-file "$SCRIPT" send "$(rjob "$EMPTY")" > "$WORK/out.jsonl" 2>&1 &
SEND_PID=$!; decide accept; wait $SEND_PID
[ -f "$RDL/empty.bin" ] && [ ! -s "$RDL/empty.bin" ] && echo "  PASS  empty file created" || { echo "  FAIL  empty file"; FAILED=1; }
check "file_done for empty" '"event": "file_done"' "$WORK/recv_events.jsonl"

echo "== receive: traversal and bad parent rejected =="
start_receiver_py || exit 1
BAD="[{\"path\": \"$WORK/a.txt\", \"name\": \"../escape.txt\", \"size\": 16, \"type\": \"text/plain\"}]"
$NU --no-config-file "$SCRIPT" send "$(rjob "$BAD")" > "$WORK/out.jsonl" 2>&1
check "sender got 400"     '"code":400'          "$WORK/out.jsonl"
check "error names file"   'rejected file name'  "$WORK/recv_events.jsonl"
[ ! -e "$WORK/escape.txt" ] && echo "  PASS  nothing written outside" || { echo "  FAIL  escaped"; FAILED=1; }
touch "$RDL/blocker"
BADP="[{\"path\": \"$WORK/a.txt\", \"name\": \"blocker/inner.txt\", \"size\": 16, \"type\": \"text/plain\"}]"
$NU --no-config-file "$SCRIPT" send "$(rjob "$BADP")" > "$WORK/out.jsonl" 2>&1 &
SEND_PID=$!; decide accept; wait $SEND_PID
check "error event on bad parent" '"event": "error"' "$WORK/recv_events.jsonl"
check "sender got 500" '"code":500' "$WORK/out.jsonl"

echo "== receive: busy while a session is open =="
start_receiver_py || exit 1
$NU --no-config-file "$SCRIPT" send "$(rjob "$FILES")" > "$WORK/out.jsonl" 2>&1 &
SEND_PID=$!; sleep 0.5
$NU --no-config-file "$SCRIPT" send "$(rjob "$ONE")" > "$WORK/out2.jsonl" 2>&1
check "second sender busy" 'busy with another transfer' "$WORK/out2.jsonl"
decide accept; wait $SEND_PID

# Localhost moves 40 MB in well under the 250 ms progress interval, so the
# receiver is throttled (20 ms per 256 KiB chunk, ~3 s per file) to make
# intermediate progress and a mid-upload cancel observable at all.
echo "== receive: progress events on a big file =="
start_receiver_py --throttle 0.02 || exit 1
head -c 40000000 /dev/urandom > "$WORK/big.bin"
BIG="[{\"path\": \"$WORK/big.bin\", \"name\": \"big.bin\", \"size\": 40000000, \"type\": \"application/octet-stream\"}]"
$NU --no-config-file "$SCRIPT" send "$(rjob "$BIG")" > "$WORK/out.jsonl" 2>&1 &
SEND_PID=$!; decide accept; wait $SEND_PID
N=$(grep -c '"event": "progress"' "$WORK/recv_events.jsonl")
[ "$N" -ge 1 ] && echo "  PASS  $N progress events" || { echo "  FAIL  no progress events"; FAILED=1; }
cmp -s "$WORK/big.bin" "$RDL/big.bin" && echo "  PASS  big file intact" || { echo "  FAIL  big file differs"; FAILED=1; }

echo "== receive: cancel from the panel mid-upload =="
start_receiver_py --throttle 0.02 || exit 1
$NU --no-config-file "$SCRIPT" send "$(rjob "$BIG")" > "$WORK/out.jsonl" 2>&1 &
SEND_PID=$!; decide accept
for _ in $(seq 1 50); do grep -q '"event": "file"' "$WORK/recv_events.jsonl" && break; sleep 0.05; done
decide cancel; wait $SEND_PID
check "cancelled event" '"event": "cancelled"' "$WORK/recv_events.jsonl"
[ -z "$(ls "$RDL" | grep '\.part$')" ] && echo "  PASS  .part removed" || { echo "  FAIL  .part left"; FAILED=1; }

echo "== receive: register is logged, log truncated on restart =="
start_receiver_py || exit 1
curl -s -m 2 -X POST -H 'Content-Type: application/json' --data '{"alias":"reg","fingerprint":"REGFP","port":1,"protocol":"http"}' "http://127.0.0.1:$RPORT/api/localsend/v2/register" -o "$WORK/reg.json"
check "register answered with our info" '"alias": "fake-laptop"' "$WORK/reg.json"
grep -q ' 127.0.0.1 {"alias":"reg"' "$RDATA/registrations.log" && echo "  PASS  registration logged" || { echo "  FAIL  not logged"; cat "$RDATA/registrations.log"; FAILED=1; }
curl -s -m 2 "http://127.0.0.1:$RPORT/api/localsend/v2/info" -o "$WORK/info.json"
check "info endpoint" '"fingerprint": "RECVFINGERPRINT"' "$WORK/info.json"
kill "$RECV_PID"; wait "$RECV_PID" 2>/dev/null
python3 "$HERE/../receiver.py" --port "$RPORT" --alias x --fingerprint y --download-dir "$RDL" --data-dir "$RDATA" --favourites "$WORK/favs.json" > "$WORK/recv_events.jsonl" 2>/dev/null &
RECV_PID=$!; sleep 0.5
[ ! -s "$RDATA/registrations.log" ] && echo "  PASS  registrations.log truncated" || { echo "  FAIL  log kept"; FAILED=1; }

echo "== receive: port busy =="
python3 "$HERE/../receiver.py" --port "$RPORT" --alias x --fingerprint y --download-dir "$RDL" --data-dir "$WORK/rdata2" --favourites "$WORK/favs.json" > "$WORK/busy.jsonl" 2>/dev/null
RC=$?
check "port_busy event" '"event": "port_busy"' "$WORK/busy.jsonl"
[ "$RC" -eq 2 ] && echo "  PASS  exit code 2" || { echo "  FAIL  exit $RC"; FAILED=1; }
kill "$RECV_PID" 2>/dev/null; RECV_PID=""

echo
if [ "$FAILED" -eq 0 ]; then echo "ALL TESTS PASSED"; else echo "FAILURES"; fi
exit $FAILED
