#!/usr/bin/env bash
# Final-source M1 geometry qualification before the full M4 browser matrix.
# Each entry is a separate complete workload, never a retry of a failed click.
set -euo pipefail
evidence_root='sf-m4-build/m1-layout-preflight'
mkdir -p "$evidence_root"
python3 tools/sandfall/sf_m4_verify_web_artifact.py \
  --web-root build/web-sandfall --expected-build-sha "$(git rev-parse HEAD)" \
  --output "$evidence_root/artifact-verification.json"
node --version > "$evidence_root/node-version.txt"
git rev-parse HEAD > "$evidence_root/source-sha.txt"
chrome="$(command -v google-chrome-stable || command -v google-chrome)"
"$chrome" --version > "$evidence_root/chrome-version.txt"
python3 tools/serve_web.py --directory build/web-sandfall --port 8040 \
  > "$evidence_root/http.log" 2>&1 &
server_pid=$!
chrome_pid=''
trap 'kill "$server_pid" ${chrome_pid:+"$chrome_pid"} 2>/dev/null || true' EXIT

# First the exact formerly failing profile; then both complete profiles.
# Unique ports and awaited retirement preserve the accepted CDP lifecycle fix.
for trial in focused-dpr1 profiles-dpr1 profiles-dpr2; do
  case "$trial" in
    focused-dpr1) width=800; height=450; dpr=1; port=9251 ;;
    profiles-dpr1) width=800; height=450; dpr=1; port=9252 ;;
    profiles-dpr2) width=640; height=400; dpr=2; port=9253 ;;
  esac
  evidence="$evidence_root/$trial"
  mkdir -p "$evidence"
  echo "SF_M1_LAYOUT_PREFLIGHT $trial $width $height $dpr $port"
  "$chrome" --headless=new --no-sandbox --disable-dev-shm-usage \
    --enable-unsafe-swiftshader --use-gl=angle --use-angle=swiftshader \
    --remote-debugging-address=127.0.0.1 --remote-debugging-port="$port" \
    --user-data-dir="$RUNNER_TEMP/sf-m1-layout-$trial" \
    about:blank > "$evidence/chrome.log" 2>&1 &
  chrome_pid=$!
  timeout 1740 node tools/sandfall/sf_m1_browser.mjs \
    --port "$port" --url 'http://127.0.0.1:8040/?test=1' \
    --verification "$evidence_root/artifact-verification.json" \
    --width "$width" --height "$height" --dpr "$dpr" \
    --output "$evidence/browser.json" --screenshot "$evidence/browser.png" \
    --timeout-ms 1200000 2>&1 | tee "$evidence/harness.log"
  kill "$chrome_pid" 2>/dev/null || true
  wait "$chrome_pid" 2>/dev/null || true
  chrome_pid=''
done
