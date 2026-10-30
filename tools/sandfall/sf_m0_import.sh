#!/usr/bin/env bash
set -euo pipefail
SOURCE_REPO="https://github.com/techrote/cybersand.git"
SOURCE_SHA="1d376fb38ff5df83691e468baa0639270a5f40e6"
SOURCE_TREE="97eb0f4eeedde9bbe8b83047ca45c82d8a377d66"
SANDFALL_BASE="34e9f9e30ebf9fde65565993f55dde571514ec93"
TARGET_BRANCH="sf-m0/source-import-20261030"
fail() { echo "::error::$*" >&2; exit 1; }
echo "SF-M0 begin: $(git rev-parse HEAD) on $GITHUB_REF_NAME"
test "$GITHUB_REF_NAME" = "$TARGET_BRANCH" || fail "Wrong branch"
git merge-base --is-ancestor "$SANDFALL_BASE" HEAD || fail "Sandfall baseline not ancestor"
git diff --quiet && git diff --cached --quiet || fail "Dirty checkout before merge"
if git cat-file -e "$SOURCE_SHA^{commit}" 2>/dev/null && git merge-base --is-ancestor "$SOURCE_SHA" HEAD; then
  echo "SF-M0 source already imported; no second merge attempted"
  exit 0
fi

git lfs version || fail "git-lfs missing"
git lfs install --local
# git merge --no-commit still requires a committer identity for merge state.
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git remote add cybersand "$SOURCE_REPO"
# Full commit/tree ancestry, with blobs fetched only as needed by the pinned tree.
git -c protocol.version=2 fetch --no-tags --filter=blob:none cybersand \
  refs/heads/main:refs/remotes/cybersand/main

git cat-file -e "$SOURCE_SHA^{commit}" || fail "Frozen CyberSand commit unreachable"
test "$(git rev-parse "$SOURCE_SHA^{tree}")" = "$SOURCE_TREE" || fail "Unexpected source tree"
git merge-base --is-ancestor "$SOURCE_SHA" refs/remotes/cybersand/main || fail "Frozen SHA not in fetched main"
merge_result=0
GIT_LFS_SKIP_SMUDGE=1 git -c merge.renames=true \
  merge --allow-unrelated-histories --no-ff --no-commit "$SOURCE_SHA" || merge_result=$?
if test "$merge_result" -ne 0; then
  conflicts="$(git diff --name-only --diff-filter=U)"
  test "$conflicts" = "README.md" || fail "Unexpected source conflicts: $conflicts"
  git checkout --ours -- README.md
  git add -- README.md
fi
test -z "$(git diff --name-only --diff-filter=U)" || fail "Unresolved conflicts"
test "$(git rev-parse MERGE_HEAD)" = "$SOURCE_SHA" || fail "Wrong merge second parent"

mkdir -p docs/audits
source_entries="$(git ls-tree -r --name-only "$SOURCE_SHA" | wc -l | tr -d ' ')"
cat > docs/audits/2026-10-30-sf-m0-source-import.md <<RECEIPT
# SF-M0 — exact history-preserving CyberSand source import

- Status: real Git merge from the exact frozen upstream commit, source-checked in the import workflow.\n- Retained failed first bootstrap attempt: run 41106067342 (missing Git committer identity, rejected before any merge/push); corrected in next source run.
- Sandfall first-parent baseline: $SANDFALL_BASE
- CyberSand exact second parent: $SOURCE_SHA
- CyberSand source tree: $SOURCE_TREE
- Upstream source: $SOURCE_REPO
- Upstream source entries (recursive blobs): $source_entries
- Merge method: Git unrelated-history two-parent merge, not a snapshot/squash.
- README: Sandfall-specific README retained in sole expected add/add conflict.
- Other imported source: byte-identical objects at frozen parent, except Sandfall-only additions.
- LFS policy: unchanged upstream attributes and artifact pointer identities; transfer must be verified by workflow.
- Workflow: .github/workflows/sf-m0-import.yml
- Web runtime proof: **NOT established by import**. Actual native, Rapier and Web export acceptance is separate.
- Retained failure 41106067342: no runner Git committer identity; no merge was made.
- Retained failure 41106167212: local exact merge succeeded and 18 LFS objects were uploaded, but reference-based LFS push refused a missing historical object (69714ced...) before pushing the Git merge.
- Retained failure 41106418749: the ref-based LFS push again requested the same missing historical object despite transferring all 18 current OIDs; corrected to explicit OID-scoped transfer.

Source-qualified CyberSand instructions, CI, historical failures and runtime provenance are retained;
Sandfall-specific requirements live in docs/SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md.
RECEIPT
git add docs/audits/2026-10-30-sf-m0-source-import.md

git -c user.name="github-actions[bot]" \
  -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  commit -m "SF-M0: merge exact CyberSand ancestor with complete Git history"
test "$(git rev-parse HEAD^2)" = "$SOURCE_SHA" || fail "Second parent is not frozen CyberSand"
git merge-base --is-ancestor "$SOURCE_SHA" HEAD || fail "Upstream not an ancestor"
test "$(git rev-parse 'HEAD^2^{tree}')" = "$SOURCE_TREE" || fail "Upstream tree differs"

git diff --name-only "$SOURCE_SHA" HEAD > "$RUNNER_TEMP/sf-m0-delta-names.txt"
cat "$RUNNER_TEMP/sf-m0-delta-names.txt"
while IFS= read -r path; do
  case "$path" in
    README.md|docs/SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md|\
    docs/audits/2026-10-30-sf-m0-source-import.md|\
    .github/workflows/sf-m0-import.yml|tools/sandfall/sf_m0_import.sh) ;;
    *) fail "Unexpected edits to frozen upstream source: $path" ;;
  esac
done < "$RUNNER_TEMP/sf-m0-delta-names.txt"

# GitHub LFS storage is repository-scoped: transfer runtime payloads required
# by the exact selected revision, never leave unresolvable LFS pointers behind.
git lfs fetch cybersand "$SOURCE_SHA"
# `git lfs push origin HEAD` traverses LFS in historical commits
# and can request an old object not retained by the frozen-current fetch.
# Push ONLY the exact OIDs present at the imported commit, not a ref walk.
python3 - <<'PYOIDS' > "$RUNNER_TEMP/sf-m0-current-lfs-oids.txt"
import re, subprocess
paths=subprocess.check_output(['git','lfs','ls-files','--name-only'],text=True).splitlines()
assert len(paths)==18, f'Expected 18 pinned-current LFS artifacts, got {len(paths)}'
for path in paths:
    pointer=subprocess.check_output(['git','show','HEAD:'+path])
    match=re.fullmatch(rb'version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n',pointer)
    assert match, f'Not an LFS pointer: {path}'
    print(match[1].decode())
PYOIDS
mapfile -t oids < "$RUNNER_TEMP/sf-m0-current-lfs-oids.txt"
test "18" -eq "${#oids[@]}" || fail "Expected 18 runtime OIDs"
git lfs push --object-id origin "${oids[@]}"
git lfs checkout
python3 - <<'PYLFS'
import hashlib, pathlib, re, subprocess
paths = subprocess.check_output(['git','lfs','ls-files','--name-only'],text=True).splitlines()
assert len(paths) == 18, f'Expected 18 tracked release-runtime objects, got {len(paths)}'
bytes_total = 0
for path in paths:
    pointer = subprocess.check_output(['git','show','HEAD:' + path])
    match = re.fullmatch(rb'version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n', pointer)
    assert match, f'Not an LFS pointer: {path}'
    payload = pathlib.Path(path).read_bytes()
    assert len(payload) == int(match[2]), f'Wrong release size: {path}'
    assert hashlib.sha256(payload).hexdigest().encode() == match[1], f'Wrong release digest: {path}'
    bytes_total += len(payload)
print(f'VERIFIED_PINNED_LFS_RUNTIME_OBJECTS={len(paths)} BYTES={bytes_total}')
PYLFS
echo "SF-M0: frozen ancestry and current LFS identity verified"
git push origin "HEAD:refs/heads/$TARGET_BRANCH"
echo "SF-M0 completed and pushed $(git rev-parse HEAD)"
