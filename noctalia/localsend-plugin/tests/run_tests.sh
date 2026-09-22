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

# Discovery: the fake answers our multicast announcement the way current
# LocalSend does, with an HTTP register POST to our ip:53317. receiver.py (the
# plugin's own server, see the receive section below) is that endpoint; a
# sweep reads its registrations.log. Both 53317 cases are skipped while the
# live plugin holds the port.
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
  if grep -q '"event": "port_busy"' "$1/events.jsonl" 2>/dev/null; then
    echo "  SKIP  53317 is in use (the live plugin?), cannot run this case"; return 2
  fi
  echo "receiver.py failed to start on 53317"; cat "$1/events.jsonl" "$1/err.log"; return 1
}

echo "== discover: peer registers over HTTP with receiver.py =="
start_receiver_53317 "$WORK/rdisco"; RC=$?
if [ "$RC" -eq 1 ]; then exit 1; elif [ "$RC" -eq 0 ]; then
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
fi

echo "== discover: legacy receiver replies over UDP =="
start_receiver accept --announce --udp-reply --alias fake-udp || exit 1
$NU --no-config-file "$SCRIPT" discover --alias noctalia-test --fingerprint TESTFINGERPRINT --window 1500 > "$WORK/disco.json" 2> "$WORK/disco.err"
check "found fake-udp" '"alias":"fake-udp"' "$WORK/disco.json"

# The LocalSend app scenario: something else answers /info on 53317 and the
# service knows its receiver is down, so discovery falls back to the subnet
# scan. receiver.py stands in for the app here (it serves /info too).
echo "== discover: receiver down -> subnet scan fallback =="
start_receiver_53317 "$WORK/rscan"; RC=$?
if [ "$RC" -eq 1 ]; then exit 1; elif [ "$RC" -eq 0 ]; then
  $NU --no-config-file "$SCRIPT" discover --alias noctalia-test --fingerprint OTHERFINGERPRINT --window 800 \
    --registrations "$WORK/nonexistent.log" --scan-hosts 127.0.0.1 > "$WORK/disco.json" 2> "$WORK/disco.err"
  kill $DISCO_PID 2>/dev/null; wait $DISCO_PID 2>/dev/null
  check "reported receiver down" 'receiver is not running' "$WORK/disco.err"
  check "found fake-laptop by scan" '"alias":"fake-laptop"' "$WORK/disco.json"
fi

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

ONE="[{\"path\": \"$WORK/a.txt\", \"name\": \"a.txt\", \"size\": $(stat -c%s "$WORK/a.txt"), \"type\": \"text/plain\"}]"
# curl as the sender, for the cases where the sender must misbehave.
PREP='{"info":{"alias":"curl-sender","fingerprint":"CURLFP","deviceType":"desktop","port":1},"files":{"f0":{"id":"f0","fileName":"c.txt","size":3,"fileType":"text/plain"}}}'
prep_url="http://127.0.0.1:$RPORT/api/localsend/v2/prepare-upload"

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

echo "== receive: pinned sender is auto-accepted (pin check disabled) =="
echo '[{"fingerprint": "SENDERFINGERPRINT", "alias": "noctalia-test"}]' > "$WORK/favs.json"
start_receiver_py --no-verify-pins || exit 1
$NU --no-config-file "$SCRIPT" send "$(rjob "$FILES")" > "$WORK/out.jsonl" 2>&1
check "auto true"   '"auto": true'          "$WORK/recv_events.jsonl"
check "sender done" '"event":"done","sent":2' "$WORK/out.jsonl"

# A fingerprint is just a string in the request body; anyone on the LAN who
# has seen the phone announce can claim it. Auto-accept therefore only
# applies when the sender proves it: its TLS certificate's SHA-256 must be
# the pinned fingerprint. A sender with no TLS server gets the prompt.
echo "== receive: pinned fingerprint without proof is still prompted =="
start_receiver_py || exit 1
$NU --no-config-file "$SCRIPT" send "$(rjob "$FILES")" > "$WORK/out.jsonl" 2>&1 &
SEND_PID=$!; decide accept; wait $SEND_PID
check "auto false without TLS proof" '"auto": false' "$WORK/recv_events.jsonl"
check "sender done after prompt"     '"event":"done","sent":2' "$WORK/out.jsonl"

echo "== receive: pinned fingerprint proven by the sender's certificate =="
if command -v openssl >/dev/null 2>&1; then
  openssl req -x509 -newkey rsa:2048 -nodes -keyout "$WORK/tls.key" -out "$WORK/tls.crt" -days 1 -subj "/CN=LocalSend User" >/dev/null 2>&1
  TLSFP=$(openssl x509 -in "$WORK/tls.crt" -outform DER | sha256sum | cut -d' ' -f1 | tr a-f A-F)
  openssl s_server -accept 8396 -cert "$WORK/tls.crt" -key "$WORK/tls.key" -quiet > /dev/null 2>&1 &
  TLS_PID=$!; sleep 0.5
  echo "[{\"fingerprint\": \"$TLSFP\", \"alias\": \"tls-phone\"}]" > "$WORK/favs.json"
  start_receiver_py || exit 1
  cat > "$WORK/tlsjob.json" <<EOF
{"device": {"ip": "127.0.0.1", "port": $RPORT, "protocol": "http", "alias": "fake-laptop"},
 "pin": null, "alias": "tls-phone", "fingerprint": "$TLSFP", "port": 8396,
 "files": $ONE}
EOF
  $NU --no-config-file "$SCRIPT" send "$WORK/tlsjob.json" > "$WORK/out.jsonl" 2>&1
  check "auto true with TLS proof" '"auto": true' "$WORK/recv_events.jsonl"
  check "sender done"              '"event":"done","sent":1' "$WORK/out.jsonl"
  kill $TLS_PID 2>/dev/null
else
  echo "  SKIP  openssl not on PATH"
fi

echo "== receive: pinned sender still prompted with --no-auto-accept =="
start_receiver_py --no-auto-accept || exit 1
$NU --no-config-file "$SCRIPT" send "$(rjob "$FILES")" > "$WORK/out.jsonl" 2>&1 &
SEND_PID=$!; decide accept; wait $SEND_PID
check "auto false" '"auto": false' "$WORK/recv_events.jsonl"
echo '[]' > "$WORK/favs.json"

echo "== receive: name collision gets (1) suffix =="
start_receiver_py || exit 1
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

echo "== receive: sender vanishes while the prompt is up =="
start_receiver_py || exit 1
curl -s -m 1 -X POST -H 'Content-Type: application/json' --data "$PREP" "$prep_url" >/dev/null 2>&1
decide accept
sleep 1
check "cancelled instead" '"event": "cancelled"' "$WORK/recv_events.jsonl"
if grep -q '"event": "accepted"' "$WORK/recv_events.jsonl"; then echo "  FAIL  accepted a vanished sender"; FAILED=1; else echo "  PASS  no accepted event"; fi
$NU --no-config-file "$SCRIPT" send "$(rjob "$ONE")" > "$WORK/out.jsonl" 2>&1 &
SEND_PID=$!; decide accept; wait $SEND_PID
check "next sender not told busy" '"event":"done","sent":1' "$WORK/out.jsonl"

echo "== receive: an accepted session that never uploads is reaped =="
start_receiver_py --idle-timeout 2 || exit 1
curl -s -m 5 -X POST -H 'Content-Type: application/json' --data "$PREP" "$prep_url" > "$WORK/prep.json" 2>/dev/null &
CP=$!; decide accept; wait $CP
check "accepted" '"event": "accepted"' "$WORK/recv_events.jsonl"
sleep 3.5
check "reaped as cancelled" '"event": "cancelled"' "$WORK/recv_events.jsonl"
$NU --no-config-file "$SCRIPT" send "$(rjob "$ONE")" > "$WORK/out.jsonl" 2>&1 &
SEND_PID=$!; decide accept; wait $SEND_PID
check "next sender not told busy" '"event":"done","sent":1' "$WORK/out.jsonl"

echo "== receive: cancel from the panel before the first upload =="
start_receiver_py || exit 1
curl -s -m 5 -X POST -H 'Content-Type: application/json' --data "$PREP" "$prep_url" > "$WORK/prep.json" 2>/dev/null &
CP=$!; decide accept; wait $CP
SID=$(python3 -c "import json,sys; d=json.load(open('$WORK/prep.json')); print(d['sessionId'])")
TOK=$(python3 -c "import json,sys; d=json.load(open('$WORK/prep.json')); print(d['files']['f0'])")
echo cancel > "$RDATA/decisions/$SID"
CODE=$(printf 'abc' | curl -s -o /dev/null -w '%{http_code}' -m 5 -X POST -T - "http://127.0.0.1:$RPORT/api/localsend/v2/upload?sessionId=$SID&fileId=f0&token=$TOK")
[ "$CODE" = "500" ] && echo "  PASS  upload refused with 500" || { echo "  FAIL  upload got $CODE"; FAILED=1; }
check "cancelled event" '"event": "cancelled"' "$WORK/recv_events.jsonl"
[ ! -e "$RDL/c.txt" ] && echo "  PASS  nothing written" || { echo "  FAIL  c.txt written"; FAILED=1; }

echo "== receive: oversized bodies are refused =="
start_receiver_py || exit 1
CODE=$(curl -s -o /dev/null -w '%{http_code}' -m 3 -X POST -H 'Content-Length: 100000000' -H 'Content-Type: application/json' --data '{}' "http://127.0.0.1:$RPORT/api/localsend/v2/register")
[ "$CODE" = "413" ] && echo "  PASS  register 413" || { echo "  FAIL  register got $CODE"; FAILED=1; }
curl -s -m 5 -X POST -H 'Content-Type: application/json' --data "$PREP" "$prep_url" > "$WORK/prep.json" 2>/dev/null &
CP=$!; decide accept; wait $CP
SID=$(python3 -c "import json; print(json.load(open('$WORK/prep.json'))['sessionId'])")
TOK=$(python3 -c "import json; print(json.load(open('$WORK/prep.json'))['files']['f0'])")
head -c 100000 /dev/zero > "$WORK/toobig.bin"
CODE=$(curl -s -o /dev/null -w '%{http_code}' -m 5 -X POST -T "$WORK/toobig.bin" -H 'Expect:' "http://127.0.0.1:$RPORT/api/localsend/v2/upload?sessionId=$SID&fileId=f0&token=$TOK")
[ "$CODE" = "413" ] && echo "  PASS  upload larger than announced -> 413" || { echo "  FAIL  upload got $CODE"; FAILED=1; }
check "error names the file" 'larger than announced' "$WORK/recv_events.jsonl"
[ ! -e "$RDL/c.txt" ] && echo "  PASS  nothing written" || { echo "  FAIL  c.txt written"; FAILED=1; }

echo "== receive: multicast responder registers with an announcing peer =="
start_receiver_py || exit 1
rm -rf "$WORK/rdata_b"; mkdir -p "$WORK/rdata_b"
python3 "$HERE/../receiver.py" --port 8397 --alias fake-phone-server --fingerprint PHONEFP --download-dir "$RDL" --data-dir "$WORK/rdata_b" --favourites "$WORK/favs.json" --no-multicast > "$WORK/rb.jsonl" 2>/dev/null &
RB_PID=$!; sleep 0.5
printf '{"alias":"fake-phone","version":"2.1","deviceModel":"x","deviceType":"mobile","fingerprint":"PHONEFP","port":8397,"protocol":"http","download":false,"announce":true,"announcement":true}' \
  | socat -u - UDP4-DATAGRAM:224.0.0.167:53317,ip-multicast-ttl=1
sleep 1.5
grep -q '"alias": "fake-laptop"' "$WORK/rdata_b/registrations.log" 2>/dev/null && echo "  PASS  registered with the announcer" || { echo "  FAIL  no registration"; cat "$WORK/rdata_b/registrations.log" 2>/dev/null; FAILED=1; }
kill $RB_PID 2>/dev/null

echo "== receive: port busy leaves the running receiver's data alone =="
start_receiver_py || exit 1
echo accept > "$RDATA/decisions/keepme"; echo "1 1.2.3.4 {}" >> "$RDATA/registrations.log"
python3 "$HERE/../receiver.py" --port "$RPORT" --alias x --fingerprint y --download-dir "$RDL" --data-dir "$RDATA" --favourites "$WORK/favs.json" > "$WORK/busy.jsonl" 2>/dev/null
RC=$?
check "port_busy event" '"event": "port_busy"' "$WORK/busy.jsonl"
[ "$RC" -eq 2 ] && echo "  PASS  exit code 2" || { echo "  FAIL  exit $RC"; FAILED=1; }
[ -f "$RDATA/decisions/keepme" ] && echo "  PASS  decision kept" || { echo "  FAIL  decision wiped"; FAILED=1; }
grep -q 1.2.3.4 "$RDATA/registrations.log" && echo "  PASS  registrations kept" || { echo "  FAIL  registrations truncated"; FAILED=1; }
[ -s "$RDATA/receiver.pid" ] && echo "  PASS  pid file kept" || { echo "  FAIL  pid file gone"; FAILED=1; }
kill "$RECV_PID" 2>/dev/null; wait "$RECV_PID" 2>/dev/null; RECV_PID=""
[ ! -e "$RDATA/receiver.pid" ] && echo "  PASS  pid file removed on SIGTERM" || { echo "  FAIL  pid file left after SIGTERM"; FAILED=1; }

echo
if [ "$FAILED" -eq 0 ]; then echo "ALL TESTS PASSED"; else echo "FAILURES"; fi
exit $FAILED
