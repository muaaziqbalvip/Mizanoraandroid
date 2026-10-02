#!/usr/bin/env bash
# Runs inside the booted emulator: stream + tunnel, then a CLEAN shutdown so
# the workflow can save the phone's data and start the next run.
set -uo pipefail

RUN_ID="${GITHUB_RUN_ID}"
START=$(date +%s)
END=$((START + 5*3600 + 15*60))           # leave ~30 min for save + restart
REMOTE="https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
S=/tmp/status

sync_status() {
  rm -rf "$S"
  if git ls-remote --exit-code --heads "$REMOTE" status >/dev/null 2>&1; then
    git clone -q --branch status --single-branch --depth 1 "$REMOTE" "$S"
  else
    mkdir -p "$S"; git -C "$S" init -q -b status; git -C "$S" remote add origin "$REMOTE"
  fi
  git -C "$S" config user.name "mizanora-bot"
  git -C "$S" config user.email "bot@users.noreply.github.com"
}

publish() {
  sync_status
  jq -n --arg url "$1" --arg run "$RUN_ID" --argjson ts "$(date +%s)" \
    '{url:$url, run_id:$run, ts:$ts}' > "$S/status.json"
  git -C "$S" add status.json
  git -C "$S" commit -q --amend -m status 2>/dev/null || git -C "$S" commit -q -m status
  git -C "$S" push -q -f origin status
}

echo "== devices"; adb devices

echo "== speed tweaks (smaller screen = much faster stream)"
adb shell wm size 720x1600 || true
adb shell wm density 280 || true
adb shell svc power stayon true || true
adb shell settings put system screen_off_timeout 2147483647 || true

echo "== ws-scrcpy"
( cd /tmp/ws-scrcpy/dist && PORT=8000 node index.js > /tmp/wsscrcpy.log 2>&1 & )
for i in $(seq 1 30); do curl -fs http://localhost:8000 >/dev/null && break; sleep 2; done

echo "== tunnel"
/tmp/cloudflared tunnel --url http://localhost:8000 --no-autoupdate > /tmp/cf.log 2>&1 &
CF_PID=$!
URL=""
for i in $(seq 1 40); do
  URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' /tmp/cf.log | head -n1 || true)
  [ -n "$URL" ] && break; sleep 2
done
if [ -z "$URL" ]; then echo "tunnel failed"; cat /tmp/cf.log; exit 1; fi
echo "tunnel: $URL"
publish "$URL"

while [ "$(date +%s)" -lt "$END" ]; do
  if ! kill -0 "$CF_PID" 2>/dev/null; then echo "tunnel died"; exit 1; fi
  sleep 120
  publish "$URL"   # heartbeat
done

echo "== clean shutdown (so data is flushed to disk)"
kill "$CF_PID" 2>/dev/null || true
adb emu kill || true
for i in $(seq 1 60); do pgrep -f 'qemu-system' >/dev/null || break; sleep 2; done
echo "emulator stopped"
