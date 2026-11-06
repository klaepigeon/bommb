#!/bin/bash
# Network test on one machine: a relay, a host and N-1 clients as separate processes.
#   tools/net_test.sh relay 3      # 3 humans through the relay (+1 AI seat)
#   tools/net_test.sh lan 4        # 4 humans, joined by room code over the LAN beacon
#   tools/net_test.sh ip 3         # 3 humans, joined by address
#   tools/net_test.sh rejoin 3     # a client drops mid-match and comes back
#   tools/net_test.sh noderelay 4  # 4 humans through the Node relay (server/relay)
# This proves the protocol and the match flow; it is NOT the real-device / real-internet
# test (docs/NETWORKING.md).
cd "$(dirname "$0")/.." || exit 1
VIA=${1:-relay}; N=${2:-3}; FAST=${FAST:---fast}
W=$(mktemp -d); PORT=$((19000 + RANDOM % 1000))
trap 'kill $(jobs -p) 2>/dev/null' EXIT
G="godot --headless"
if [ "$VIA" = noderelay ]; then
  # the Node relay (server/relay), as deployed
  PORT=$PORT node server/relay/relay.js > $W/relay.log 2>&1 &
  sleep 1.0
  HVIA=relay
  VIA=relay
elif [ "$VIA" = relay ] || [ "$VIA" = rejoin ]; then
  $G --script server/relay_server.gd -- --port=$PORT > $W/relay.log 2>&1 &
  sleep 1.5
  HVIA=relay
else
  HVIA=lan
fi
$G res://tests/net_test.tscn -- --role=host --via=$HVIA --humans=$N --relay=ws://127.0.0.1:$PORT --codefile=$W/code --out=$W/host.txt --name=HOST $FAST > $W/host.log 2>&1 &
for i in $(seq 1 40); do [ -s $W/code ] && break; sleep 0.25; done
CODE=$(cat $W/code); echo "room code: $CODE"
for i in $(seq 2 $N); do
  EXTRA=""
  [ "$VIA" = ip ] && EXTRA="--ip=127.0.0.1"
  [ "$VIA" = rejoin ] && [ $i = 2 ] && EXTRA="--drop_at=25"
  $G res://tests/net_test.tscn -- --role=client --code=$CODE --relay=ws://127.0.0.1:$PORT --out=$W/c$i.txt --name=CLIENT$i $EXTRA > $W/c$i.log 2>&1 &
  sleep 0.5
done
for i in $(seq 1 1200); do
  done_all=1
  for f in host $(seq -f "c%g" 2 $N); do [ -s $W/$f.txt ] || done_all=0; done
  [ $done_all = 1 ] && break
  sleep 0.5
done
ok=1
for f in host $(seq -f "c%g" 2 $N); do
  r=$(cat $W/$f.txt 2>/dev/null); echo "$f: ${r:-NO RESULT}"
  echo "$r" | grep -q "^ENDING" || ok=0
done
[ $ok = 1 ] && echo "NET TEST PASSED ($VIA, $N humans)" || { echo "NET TEST FAILED ($VIA, $N humans), logs in $W"; for l in $W/*.log; do echo "== $l"; tail -n 5 $l; done; exit 1; }
