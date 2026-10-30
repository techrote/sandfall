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

- Status: real Git merge from the exact frozen upstream commit, source-checked in the import workflow.
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
git lfs push origin HEAD
git lfs fsck || fail "Imported LFS identity check failed"
echo "SF-M0: frozen ancestry and current LFS identity verified"
git push origin "HEAD:refs/heads/$TARGET_BRANCH"
echo "SF-M0 completed and pushed $(git rev-parse HEAD)"
