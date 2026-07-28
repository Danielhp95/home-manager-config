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

cleanup() { pkill -f "fake_receiver.py --port $PORT" 2>/dev/null; rm -rf "$WORK"; }
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

echo
if [ "$FAILED" -eq 0 ]; then echo "ALL TESTS PASSED"; else echo "FAILURES"; fi
exit $FAILED
