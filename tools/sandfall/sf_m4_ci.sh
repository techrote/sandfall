#!/usr/bin/env bash
# Exact-source SF-M4 source/build gates. M0/M2/M3 reconcilers remain unchanged.
# This milestone changes no native source; its fresh build uses the exact reviewed M3 admission gate;
# retained browser/legacy execution delegates to the unchanged M2 runner.
set -euo pipefail
mode="${1:?source|build|browser|legacy}"
case "$mode" in
source)
echo 'SF_M4_CI Verify frozen history, actual LFS bytes and documented exceptions'
set -euo pipefail
git merge-base --is-ancestor 1d376fb38ff5df83691e468baa0639270a5f40e6 HEAD
test "$(git rev-parse '1d376fb38ff5df83691e468baa0639270a5f40e6^{tree}')" = 97eb0f4eeedde9bbe8b83047ca45c82d8a377d66
git lfs fetch origin "$(git rev-parse HEAD)"
git lfs checkout
python3 tools/ci/check_ci_provider_policy.py
python3 tools/sandfall/sf_m3_reconcile.py --output sf-m4-evidence/source-reconciliation.json

echo 'SF_M4_CI Execute build identity, geometry, pixel and input assertion negatives'
set -euo pipefail
mkdir -p sf-m4-evidence
node --version > sf-m4-evidence/node-version.txt
python3 -m unittest discover -s tools/sandfall -p 'test_sf_m*.py' 2>&1 | tee sf-m4-evidence/python-tests.log
python3 -m unittest tools.ci.test_feature_web_staging 2>&1 | tee sf-m4-evidence/legacy-staging-tests.log
for test in tools/sandfall/test_sf_m*.mjs; do
  node "$test"
done 2>&1 | tee sf-m4-evidence/browser-helper-tests.log
node --check tools/sandfall/sf_m1_browser.mjs
node --check tools/sandfall/sf_m2_browser.mjs
node --check tools/sandfall/sf_m3_browser.mjs
node --check tools/sandfall/sf_m4_browser.mjs

echo 'SF_M4_CI Retain original frozen-source refusal, then freshly execute reviewed native regressions'
set -euo pipefail
if python3 tools/sandfall/sf_m0_native_smoke.py --output-dir sf-m4-evidence/native-original-m0-refusal; then
  echo 'Original M0 guard unexpectedly accepted the changed native baseline' >&2
  exit 1
fi
python3 - <<'PYCODE'
import json
from pathlib import Path
record=json.loads(Path('sf-m4-evidence/native-original-m0-refusal/receipt.json').read_text())
assert record['status']=='failed'
assert record['failures']==['RuntimeError: Native source differs from the retained full-suite baseline'], record['failures']
assert not record['commands'], 'Original baseline refusal must precede execution'
PYCODE
python3 tools/sandfall/sf_m3_native_smoke.py --output-dir sf-m4-evidence/native-focused

;;
build)
echo 'SF_M4_CI Restore and verify pinned native and Rapier dependencies'
set -euo pipefail
git lfs fetch origin "$(git rev-parse HEAD)"
git lfs checkout
python3 tools/sandfall/sf_m3_reconcile.py --output sf-m4-build/reconciliation.json

echo 'SF_M4_CI Provision pinned Godot, SCons and separate Web/native godot-cpp builds'
set -euo pipefail
python3 -m venv "$RUNNER_TEMP/sf-web-python"
"$RUNNER_TEMP/sf-web-python/bin/pip" install --require-hashes -r tools/requirements-build.txt
for checkout in godot-cpp-web godot-cpp-native; do
  git init "$RUNNER_TEMP/$checkout"
  git -C "$RUNNER_TEMP/$checkout" remote add origin https://github.com/godotengine/godot-cpp.git
  git -C "$RUNNER_TEMP/$checkout" fetch --depth=1 origin 101ae38034304346a46ea9ea84ae156d3e860496
  git -C "$RUNNER_TEMP/$checkout" checkout --detach FETCH_HEAD
  test "$(git -C "$RUNNER_TEMP/$checkout" rev-parse HEAD)" = 101ae38034304346a46ea9ea84ae156d3e860496
done
curl -fL --retry 3 'https://downloads.godotengine.org/?flavor=stable&platform=linux.64&slug=linux.x86_64.zip&version=4.7' -o "$RUNNER_TEMP/godot.zip"
echo "0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c  $RUNNER_TEMP/godot.zip" | sha256sum -c -
mkdir -p "$RUNNER_TEMP/godot"
unzip -q "$RUNNER_TEMP/godot.zip" -d "$RUNNER_TEMP/godot"
GODOT_BIN="$RUNNER_TEMP/godot/Godot_v4.7-stable_linux.x86_64"
chmod +x "$GODOT_BIN"
test "$("$GODOT_BIN" --version)" = 4.7.stable.official.5b4e0cb0f
echo "GODOT_BIN=$GODOT_BIN" >> "$GITHUB_ENV"
git rev-parse HEAD > sf-m4-build/source-sha.txt
g++ --version > sf-m4-build/compiler-version.txt

echo 'SF_M4_CI Obtain checksum-validated Godot 4.7 Web export templates'
set -euo pipefail
base='https://github.com/godotengine/godot-builds/releases/download/4.7-stable'
curl -fL --retry 3 "$base/SHA512-SUMS.txt" -o "$RUNNER_TEMP/SHA512-SUMS.txt"
curl -fL --retry 3 "$base/Godot_v4.7-stable_export_templates.tpz" -o "$RUNNER_TEMP/Godot_v4.7-stable_export_templates.tpz"
(cd "$RUNNER_TEMP"; grep ' Godot_v4.7-stable_export_templates.tpz$' SHA512-SUMS.txt | sha512sum --check --strict)
python3 - <<'PYCODE'
import os, pathlib, zipfile
root=pathlib.Path(os.environ["RUNNER_TEMP"])
out=root/"web-templates"
out.mkdir(exist_ok=True)
with zipfile.ZipFile(root/"Godot_v4.7-stable_export_templates.tpz") as archive:
    for member in archive.namelist():
        name=pathlib.PurePosixPath(member).name
        if name.startswith("web_dlink") and name.endswith(".zip"):
            (out/name).write_bytes(archive.read(member))
expected={f"web_dlink_{kind}.zip" for kind in ("debug","release")}
expected|={f"web_dlink_nothreads_{kind}.zip" for kind in ("debug","release")}
assert expected<=set(p.name for p in out.iterdir()), expected
PYCODE
cp "$RUNNER_TEMP/SHA512-SUMS.txt" sf-m4-build/godot-release-checksums.txt

echo 'SF_M4_CI Install Emscripten 4.0.20'
set -euo pipefail
git clone --depth 1 --branch 4.0.20 https://github.com/emscripten-core/emsdk.git "$RUNNER_TEMP/emsdk"
"$RUNNER_TEMP/emsdk/emsdk" install 4.0.20
"$RUNNER_TEMP/emsdk/emsdk" activate 4.0.20
source "$RUNNER_TEMP/emsdk/emsdk_env.sh"
emcc --version > sf-m4-build/emscripten-version.txt

echo 'SF_M4_CI Build the new host from this SHA and execute actual Godot native/Rapier tests'
set -euo pipefail
source "$RUNNER_TEMP/emsdk/emsdk_env.sh"
export SF_M4_TEST_OUTPUT="$PWD/sf-m4-build/project-codec"
"$RUNNER_TEMP/sf-web-python/bin/python" tools/build_web.py \
  --cpp "$RUNNER_TEMP/godot-cpp-web" --native-cpp "$RUNNER_TEMP/godot-cpp-native" \
  --godot "$GODOT_BIN" --templates "$RUNNER_TEMP/web-templates" \
  --profile compat --entry sandfall --native-tests \
  2>&1 | tee sf-m4-build/sandfall-build-and-godot-tests.log
python3 tools/sandfall/sf_m4_verify_web_artifact.py \
  --web-root build/web-sandfall --expected-build-sha "$(git rev-parse HEAD)" \
  --output sf-m4-build/artifact-verification.json
cp build/web-libs/libcybersand_native.linux.x86_64.so sf-m4-build/libcybersand_native.linux.x86_64.so
sha256sum sf-m4-build/libcybersand_native.linux.x86_64.so > sf-m4-build/native-gdextension.sha256

echo 'SF_M4_CI Export the retained legacy fixture using the same freshly compiled side module'
set -euo pipefail
source "$RUNNER_TEMP/emsdk/emsdk_env.sh"
"$RUNNER_TEMP/sf-web-python/bin/python" tools/build_web.py \
  --cpp "$RUNNER_TEMP/godot-cpp-web" --native-cpp "$RUNNER_TEMP/godot-cpp-native" \
  --godot "$GODOT_BIN" --templates "$RUNNER_TEMP/web-templates" \
  --profile compat --entry legacy --export-only --native-tests \
  2>&1 | tee sf-m4-build/legacy-export-and-godot-tests.log

;;
browser|legacy)
exec bash tools/sandfall/sf_m2_ci.sh "$mode"
;;
*) echo "Unknown CI mode" >&2; exit 2 ;;
esac
