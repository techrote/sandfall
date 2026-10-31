#!/usr/bin/env bash
# One genuine-browser SF-M4 workload; every negative and download is retained.
set -euo pipefail
scenario="${1:?projects|gallery}"
case "$scenario" in projects|gallery) ;; *) exit 2 ;; esac
evidence=sf-m4-project-browser
mkdir -p "$evidence"
python3 tools/sandfall/sf_m4_verify_web_artifact.py \
  --web-root build/web-sandfall --expected-build-sha "$(git rev-parse HEAD)" \
  --output "$evidence/artifact-verification.json"
git rev-parse HEAD > "$evidence/source-sha.txt"
node --version > "$evidence/node-version.txt"
uname -a > "$evidence/environment.txt"
python3 tools/serve_web.py --directory build/web-sandfall --port 8040 > "$evidence/http.log" 2>&1 &
SERVER_PID=$!
CHROME="$(command -v google-chrome-stable || command -v google-chrome)"
"$CHROME" --version > "$evidence/chrome-version.txt"
CHROME_PID=''
trap 'kill "$SERVER_PID" ${CHROME_PID:+"$CHROME_PID"} 2>/dev/null || true' EXIT
"$CHROME" --headless=new --no-sandbox --disable-dev-shm-usage \
  --enable-unsafe-swiftshader --use-gl=angle --use-angle=swiftshader \
  --remote-debugging-port=9231 --user-data-dir="$RUNNER_TEMP/sf-m4-chrome" \
  about:blank > "$evidence/chrome.log" 2>&1 &
CHROME_PID=$!
timeout 1860 node tools/sandfall/sf_m4_browser.mjs \
  --port 9231 --url 'http://127.0.0.1:8040/?test=1' \
  --verification "$evidence/artifact-verification.json" \
  --width "$VIEW_WIDTH" --height "$VIEW_HEIGHT" --dpr "$VIEW_DPR" \
  --bodies "${BODY_COUNT:-16}" --scenario "$scenario" \
  --output "$evidence/browser.json" --screenshot "$evidence/browser.png" \
  --download-dir "$evidence/downloads" --timeout-ms 1620000 \
  2>&1 | tee "$evidence/harness.log"
