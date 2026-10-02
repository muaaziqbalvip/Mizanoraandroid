#!/usr/bin/env bash
# Runs inside the booted emulator. Starts ws-scrcpy + Cloudflare tunnel,
# publishes the URL to the `status` branch, then hands over to a fresh run.
set -uo pipefail

RUN_ID="${GITHUB_RUN_ID}"
START=$(date +%s)
HANDOVER_AT=$((START + 5*3600 + 30*60))   # start the next run at 5h30
HARD_END=$((START + 5*3600 + 52*60))      # never run past 5h52
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

remote_run_id() { sync_status; jq -r '.run_id // empty' "$S/status.json" 2>/dev/null; }

publish() {
  sync_status
  jq -n --arg url "$1" --arg run "$RUN_ID" --argjson ts "$(date +%s)" \
    '{url:$url, run_id:$run, ts:$ts}' > "$S/status.json"
  git -C "$S" add status.json
  git -C "$S" commit -q --amend -m status 2>/dev/null || git -C "$S" commit -q -m status
  git -C "$S" push -q -f origin status
}

echo "== devices"; adb devices

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

HANDED=0
while [ "$(date +%s)" -lt "$HARD_END" ]; do
  if [ "$HANDED" = 0 ] && [ "$(date +%s)" -ge "$HANDOVER_AT" ]; then
    echo "== handover: starting next run"
    gh workflow run emulator.yml -R "$GITHUB_REPOSITORY" && HANDED=1
  fi
  if ! kill -0 "$CF_PID" 2>/dev/null; then echo "tunnel died"; exit 1; fi
  RID=$(remote_run_id)
  if [ "$HANDED" = 1 ] && [ -n "$RID" ] && [ "$RID" != "$RUN_ID" ]; then
    echo "new run is live, shutting down"; break
  fi
  [ "$HANDED" = 0 ] && publish "$URL"   # heartbeat
  sleep 120
done
