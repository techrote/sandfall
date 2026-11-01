# SF-M3 source and CI reconciliation — 1 November 2026

## Source selection

The accepted CI rehabilitation is `main` commit
`674101cd63780edb57361b8f265ec831a1ca1f17`.
The original full SF-M3 milestone head is
`744227deb015c3a87a79e55e0271d28c5e2d310b`;
both descend from common Sandfall baseline
`4a01a00d1f457576e1d911ef08c45b4c0aaf3347`.

The existing SF-M3 branch has been reconciled through ordinary file commits,
without rebasing, force-updating or changing the SF-M4 dependent branch.
This preserves all original SF-M3 implementation and audit history. It is
not yet a merge into `main`.

## Explicit overlap resolution

Of 39 files changed by accepted PR #7, the reconciled branch contains exactly
its accepted blobs or documented deliberate combinations:

- `documentation.yml`: original SF-M3 source-pinned six-file native delta
  admission, strict M0/M2 failure retention and CI's manual-run concurrency.
- `gdextension.yml`, the Windows runner, and the two legacy Godot project-entry
  test assertions: accepted CI versions. The required `sandfall-current` profile
  retains current product tests and excludes only the documented desktop-only
  launcher/Tower fixtures; `full` remains available.
- Tracked `global_script_class_cache.cfg`: original SF-M3 superset of
  accepted CI class records, adding `SandfallRapierObjectRegistry`.
- `docs/README.md`: M3 workshop references plus the accepted CI documentation
  navigation. Audit status claims retain the distinction between earlier
  milestone evidence and final integrated source.
- `web-acceptance.yml`: promotes routine mainline coverage from the
  M2-only native-source baseline to source-matched SF-M3 acceptance.
- `test_ci_workflow_contract.py`: requires that mainline M3 reusable workflow,
  exact head checkouts, original 0/1/3/8/16-body physical browser matrix,
  M1/M2 ordinary browser compatibility, and bounded source/native gates.

The SF-M3 workflow is reusable with a `routine` input. The routine wrapper
omits redundant `make test` already run by the accepted parallel Native
workflow, while preserving source, pinned Web export, actual M3 browser
workloads and the legacy 600-tick physical save/restore oracle.
The dedicated SF-M3 branch workflow retains its full Native job and all ten
milestone jobs after qualification is re-enabled.

Nine CyberSand-only/obsolete workflows remain retired as approved by PR #7.
No merged mainline Native, Linux, Web, or Windows integrity requirement is
removed. The six-file SF-M3 native restore patch and its pinned digest remain
unchanged. The old desktop publication and LFS blockers are preserved as
negative controls rather than silently marked passing.

## Qualification boundary

This is a source-level reconciliation record, **not** acceptance evidence.
Before merging #5, require all exact-head cheap CI and provenance checks,
four Native suites plus fail-closed aggregate, actual Linux GDExtension host
and all Sandfall-current shards plus fail-closed aggregate, complete SF-M3
source/native/Godot compatibility export and 10-job real-browser matrix, and
documented independent final reconciliation review.

Optional Windows portability was source-custody repaired by PR #7 but is not
claimed to have passed actual Windows execution. Threaded Web, external
hosting and human exhibition acceptance remain future programme gates.
SF-M4 is an untouched downstream branch until #5 acceptance.
