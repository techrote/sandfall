# SF-M0 source import — live provenance record (2026-10-30)

Status: **source-history import candidate, subject to post-commit/branch verification**. This record is not Web/browser qualification.

## Frozen authority and exact ancestry

- Sandfall initial main: 34e9f9e30ebf9fde65565993f55dde571514ec93 (approved Sandfall spec from PR #1).
- Candidate first parent: d6ecc8f64d8b16b5e46a22ae952f77f34dd6ee8b (Sandfall SF-M0 bootstrap scripts).
- Exact CyberSand second parent: 1d376fb38ff5df83691e468baa0639270a5f40e6.
- Frozen CyberSand tree SHA: 97eb0f4eeedde9bbe8b83047ca45c82d8a377d66.
- Upstream source: https://github.com/techrote/cybersand
- Target: https://github.com/techrote/sandfall, branch sf-m0/source-import-20261030.
- All 1,656 frozen upstream blob entries and underlying commit ancestry are inherited by referencing the unchanged source tree and exact Git parent, not by flattening or copying recent files.

## Exact imports and approved Sandfall-only overrides

The merge tree is constructed from the exact frozen CyberSand source tree. Its only path differences are:

1. README.md: preserve Sandfall-specific project identity and links to the approved v1 specification.
2. docs/SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md: retain the owner-approved contract.
3. .github/workflows/sf-m0-import.yml: preserve the reproducible import workflow.
4. tools/sandfall/sf_m0_import.sh: preserve the exact-source import audit apparatus.
5. This dated audit document, absent upstream.

The old CyberSand README and all of its original workflows remain available in the immutable CyberSand parent. Imported active workflow files are not silently rewritten. The exact source tree, dependency locks, Git LFS pointers, native source and tests are unchanged.

## Actual GitHub Actions evidence and negative history

- First probe run [41106067342](https://github.com/techrote/sandfall/actions/runs/41106067342) stopped before merge due to unconfigured committer identity.
- Run [41106167212](https://github.com/techrote/sandfall/actions/runs/41106167212) successfully formed a local real two-parent commit and uploaded 18 pinned LFS binaries, but ref-based LFS pushing requested older historical object 69714ced…; Git ref was not pushed.
- Runs [41106418749](https://github.com/techrote/sandfall/actions/runs/41106418749) and [41106692801](https://github.com/techrote/sandfall/actions/runs/41106692801) established that current-only LFS delivery could not satisfy GitHub's historical LFS checks. The latter verified **all 18 pinned current runtime files**, totalling **269,259,259 bytes**, against committed size and SHA-256.
- Run [41106838912](https://github.com/techrote/sandfall/actions/runs/41106838912) was rejected by GitHub GH008 for **at least 96 older missing LFS objects** when the full original history was pushed with current-only LFS.
- Run [41107163311](https://github.com/techrote/sandfall/actions/runs/41107163311) failed a history-wide LFS scan on a blob-filtered Git fetch.
- Run [41107335682](https://github.com/techrote/sandfall/actions/runs/41107335682) fetched full Git objects and successfully scanned **115 historical LFS objects**. It downloaded approximately **537,786,523 bytes** locally and transferred **114/114 historical uploads (~538 MB)** to Sandfall, rechecking the 18 currently required files. Its Git ref push was refused solely because the GitHub Actions app token lacks permission to import upstream .github/workflows/documentation.yml.
- Recovery: the original Git commits, trees and blobs became readable in Sandfall despite the refused Actions-token ref push. The connected GitHub API is used to create the same exact-source two-parent merge and update the branch ref with its authorized repository permission. Record any API refusal as a separate gate; do not claim merge if refused.

## Verification and qualification boundaries

After branch creation, verify the complete first/second parent SHA, tree diff against frozen CyberSand (only the five approved changes), current 18 LFS pointers versus target remote bytes, and accessible historical commits. Do not equate source identity with application execution.

The inherited CyberSand Web build uses Godot 4.7 (5b4e0cb0f), godot-cpp 101ae38034304346a46ea9ea84ae156d3e860496, Emscripten 4.0.20, SCons 4.10.1 and Rapier2D 0.35.2. A fresh actual Web build, browser Rapier proof and source-matched artifact identities are **separate SF-M0 gates not established by this import record**.

The inherited CLI/workflow files may still use original project names. No Sandfall no-player-input UI, sixteen-body enhancement, file codec or v1 gallery is claimed at SF-M0.
