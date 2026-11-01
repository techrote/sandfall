---
title: SF-M5 C01 — Archive coverage and retired project operations
status: Current
document-kind: audit
scope: Existing archive qualification, narrow late-callback regressions and verified merged-M4 baseline
canonical-for: []
last-reviewed: 2026-11-01
related-documents: [../SANDFALL-PROJECT-FORMAT.md, ../SF-M4-PROJECTS-EXHIBITIONS.md, ../SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md, 2026-11-01-sf-m4-final-reconciliation.md]
---

# SF-M5 C01 — Archive coverage and retired project operations

**Disposition:** retain the accepted archive implementation and its hostile-input
campaign. C01 adds narrowly missing lifecycle assertions; it changes no parser,
archive format, application owner, solver, browser harness or diagnostic allowlist.
This is one contribution to SF-T09/SF-T10/SF-T12, not a v1 release decision.

## Verified starting source and post-merge qualification

The independently fetched starting `main` is
`ec94dfa50525135375dd6e35d1c5fca55c412544`, tree
`fb077c33386a6020d9eef91304227304cd135513`. Its merge parents are accepted
SF-M3 `72e9e1118fd06ef6026a9ef8dea3864128b2c54d` and reviewed SF-M4 candidate
`0cc6b54d7361fd4781978ae84b803c6213a8648b`. There were no open PRs when this
tranche started. Every required post-merge job was read from the actual `push`
run at this merged SHA, rather than inferred from the candidate's earlier result.

| Workflow | Observed result and retained scope |
|---|---|
| [Native 41336369369](https://github.com/techrote/sandfall/actions/runs/41336369369) | Four suites and `native` aggregate passed; the PR-only scope job skipped |
| [GDExtension 41336369405](https://github.com/techrote/sandfall/actions/runs/41336369405) | Linux build, four regression shards, timing report and Linux aggregate passed; optional Windows, serial-equivalence and physical-stress lanes skipped |
| [Web 41336369410](https://github.com/techrote/sandfall/actions/runs/41336369410) | Exactly 15 required jobs passed: source/build, legacy coupled fixture, M1/M2 controls, 0/1/3/8/16-body workshop, 0/16-body ZIP, Gallery at both viewports |
| [CI contracts 41336369310](https://github.com/techrote/sandfall/actions/runs/41336369310) | Passed |
| [Documentation 41336369348](https://github.com/techrote/sandfall/actions/runs/41336369348) | Passed with the established explicit provenance reconciliation |

The separate [complete M4 run 41333628953](https://github.com/techrote/sandfall/actions/runs/41333628953)
retains all 36 jobs at the reviewed candidate. It is not relabelled as a merged-main
run. The merged tree matches that candidate's reviewed application tree. Optional
skipped lanes above do not establish desktop release or serial-equivalence support.

## Coverage comparison and bounded implementation

| C01 requirement | Existing source/test evidence | C01 action |
|---|---|---|
| Traversal, absolute paths, duplicates/case collisions, links/devices, executable/remote assets | `archive_zip.gd`; `_zip_structural_negatives()` and `_logical_negatives()` in `test_sandfall_archive.gd`; genuine browser negatives | Retained unchanged |
| ZIP64/encryption, mismatched local/central names, unsupported compression, multipart/truncation/trailing bytes | `_zip_structural_negatives()` | Retained unchanged |
| CRC and corrupt/truncated/oversize DEFLATE | `_corrupt_deflate_negatives()`; Python-generated CRC fixture; `sf_m4_expected_diagnostics.py` | Retained strict case/fixture/error boundaries |
| Entry count, expanded total, ratio, per-entry limits and nested/malformed data | 257-entry, 128 MiB expansion and declared-bomb fixtures; exact world bytes; JSON depth and syntax cases; closed asset path/type schema | Retained unchanged; nested archives cannot become executable or recursively expanded assets |
| Bad hashes, schema/policy, invalid material and object values | Self-consistent invalid-manifest fixtures, native tuple validator, 17-body and invalid mass tests | Retained unchanged |
| Valid external ZIP/folder edits and byte identity | `test_sandfall_archive_interop.gd` and independent `sf_m4_archive_fixture.py`; real browser chooser/Blob downloads | Retained unchanged |
| Candidate failure before mutation | `test_sandfall_projects.gd`: isolated candidate, readiness/allocation failure, raw body RIDs, native payload and old-scene continuation | Added explicit retired **input epoch**, alongside the existing retired generation |
| Late chooser callbacks and rapid cancellation/replacement | Serial, generation and active-operation guards in `browser_file_bridge.gd`/`application.gd` | Added four cancel/reopen cycles covering stale success/error/cancel delivery while closed, choosing and staged |
| Consumed confirmation | Existing modal/lease retirement after adoption | Added repeated confirmation and consumed callback checks: exactly one import and one generation increment |

The retained M4 codec receipt has **184 checks**, **93 refused cases** and five
0/1/3/8/16-body round trips. Independent Python/Godot interchange has **19 fixture
dispositions** and **83 Godot checks**. The 16-body actual-browser workload uploads
14 independently mutated archives, checks their precise refusal, and compares the
previous physical/document observation before and after refusal/dismissal.
These counts describe those particular fixtures, not exhaustive security proof.

New C01 lifecycle assertions are deliberately inside the existing two test scripts,
so the established source-build and applicable Godot lanes execute them without a
new expensive workflow or a second importer. Exact full native physical snapshots,
body RIDs, authored documents, history state, tick counters and generation are
compared across refusal/cancellation. Modal entry legitimately retires input leases;
the UI snapshot intentionally excludes the changing input epoch while the direct
session test proves that an obsolete epoch refuses before mutation.

## Executed local qualification and original negative

The changed tests ran on Linux with pinned Godot
`4.7.stable.official.5b4e0cb0f`. Their disposable script stage used the actual
merged-main Linux artifact from run `41336369405`:

| Input | SHA-256 / identity |
|---|---|
| Native shared library | `9a6915e508afe25a5ebee5461f6cadb160976320a0f9eb28e13bd7b7534703e3` |
| Rapier Linux 0.35.2 | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |
| Runtime source | `ec94dfa50525135375dd6e35d1c5fca55c412544`; C01 changes no native/build inputs |
| `test_sandfall_project_input.gd` | `accacf28faf8425ff479b85843f0803875ea9aed01091acbfa1ff893f5c83f92` |
| `test_sandfall_projects.gd` | `efb26234b0ace02f3fb6b3903bce3d73baf8efc3e50acec431f78667ee3c0bd6` |

The qualification receipt compares each tested staged script with these source
bytes. No changed script is presented as the old native artifact's source.

Focused commands, after staging the verified runtime with
`tools/sandfall/sf_m1_stage_native.py` and importing the disposable project:

```sh
"$GODOT_BIN" --headless --path build/sf-m1-native-project --script res://tests/test_sandfall_project_input.gd
"$GODOT_BIN" --headless --path build/sf-m1-native-project --script res://tests/test_sandfall_projects.gd
python3 -m unittest tools.sandfall.test_sf_m4_expected_diagnostics tools.sandfall.test_sf_m4_identity
python3 tools/ci/check_m11_consistency.py
```

Results: **84 project-input checks**, **932 project/session checks**, six Python
diagnostic/identity tests, and historical M11 integrity passed. Neither changed
Godot suite emitted engine errors. The ordinary documentation checker still
reported exactly its six retained missing companion-workspace references; these
are not new C01 failures or rewritten historical passes.

The first new UI fixture failed four cancellation assertions: it injected a file
selection and immediately clicked using the chooser's previous modal layout.
The original log is retained in the qualification bundle, SHA-256
`1fdea139d980523fa6d86dd8d250b4a3174522896c2def480ceb54ec82be21c9`.
The correction waits
for the visible enabled action's actual rectangle to be stable across consecutive
frames, with a 30-frame refusal bound, before sending one input gesture. It does
not repeat clicks, add wall-clock sleeps, relax the cancellation/ownership oracle
or modify product layout. The corrected test observes monotonic retired/current
serial pairs `9/11`, `13/15`, `17/19`, `21/23` and passes all four ownership checks.

## Integration and claim boundary

New lifecycle injections are **native tests of production callback owners**.
They are labelled as such in the receipt. They do not claim an actual browser
file read race was exercised. Existing M4 browser upload/download and hostile
replacement evidence remains the browser delivery proof and must remain green on
the final integrated source/profile matrix. C01 introduces no broad expected-error
allowlist and does not suppress decompressor diagnostics.

The integrator must obtain independent review and applicable exact-head CI before
merging this test delta. A01's native or application changes require a fresh
source-matched runtime for the integrated C01 tests; the merged-M4 runtime used
here is not evidence for those later source changes. Threaded hosting, alternate
browsers, performance and human Gallery acceptance remain separate SF-M5 gates.
