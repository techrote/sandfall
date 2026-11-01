---
title: SF-M4 final reconciliation and permanent mainline qualification
status: Current
document-kind: audit
scope: Preserved SF-M4 source, accepted SF-M3 ancestry, browser geometry repair and CI coverage
last-reviewed: 2026-11-01
related-documents: [../SF-M4-PROJECTS-EXHIBITIONS.md, ../SANDFALL-PROJECT-FORMAT.md, 2026-10-31-sf-m4-projects-exhibitions.md, 2026-11-01-ci-rehabilitation.md]
---

# SF-M4 final reconciliation — 1 November 2026

This record describes the integration delta and its qualification contract.
Execution results belong to their actual source SHA and Actions artifacts in
[PR #6](https://github.com/techrote/sandfall/pull/6). It does not convert an
earlier green run into qualification of the reconciled source.

## Source authority and preserved implementation

| Role | Immutable source |
|---|---|
| Accepted SF-M3 source | `93f5b50f4c4a48b0cf196d146331ba1621c2757d` |
| Accepted SF-M3 merge/main | `72e9e1118fd06ef6026a9ef8dea3864128b2c54d` |
| Incoming SF-M4 | `b57738eb128ab5a82f5153fee1ba4c093f3996c2` |
| Actual reconciliation merge base | `44f28cb6894803e4bf40ce329fcbf5d7eadd1fcd` |
| Original independently reviewed M4 | `c45b5c2cb75c69de6b37bd7de3ac2954de140a58` |
| Original reviewed M3 dependency | `0dd5d0606c92b37d3abbf6e252eae9977c1807bd` |

The original M4 delta has 46 paths. Forty-three retain the original reviewed
bytes at the incoming head, including all fourteen production GDScripts,
seven new Godot tests, the archive parser/fixtures, project/Gallery harness,
physical coupling, promotion, presentation, Web builder and M2 geometry repair.
The three later changes are the M4 workflow's CDP lifecycle correction,
updated owner authorization and the complete generated class registry.

The reconciliation keeps all production/native/bridge/dependency bytes intact.
Native code remains the strict reviewed M3 delta on the frozen CyberSand base;
no moving upstream source or desktop player owner is imported. A sorted list
of the fourteen M4 production paths and their original Git blob IDs, encoded
as `path + " " + blob + "\n"`, has SHA-256
`30e40e8cbf69db34759d83a837d40c8e0a614bc86ddc3298e5f408c649d87ca7`.

The incoming class registry is intentionally retained instead of restoring the
incomplete original cache. It registers all eighteen Sandfall classes:
Git blob `cda721085608fd2db67ff0332f6abb10a5c02b20`, SHA-256
`61133bfc5043b7ce2ef267927486925852a266ac18cf56915535f7b5a3434456`.

## Reconciled CI contracts

The normal merge preserves both parents and accepted PR #7/M3 CI behavior:
four Native suites, fail-closed `native` aggregate, strict documentation/native
source reconciliation, fresh Linux runtime custody, all `sandfall-current`
shards and the current Web-owner replacement for inherited desktop fixtures.

M4's runner additions coexist with profile selection: real Godot/Python ZIP
interchange, exact malformed-archive diagnostic validation, and one strictly
validated passing terminal JSON whose domain-level `skipped` field does not
mean its test was skipped. Other skip messages, unknown errors, missing or
malformed results and nonzero exits still fail. Gallery retains its 1,200 s
case bound and 450 s scheduling weight. Linux, optional Windows and optional
serial job budgets retain the existing M4 values; no physical case is omitted.
Source-bound optional Windows artifact verification remains intact.

Native trigger paths now include the targeted M4 qualification workflow. A
change to that full-native qualification owner therefore executes the four
core suites at the same head, without changing their architecture or commands.
Documentation retains accepted dispatch concurrency and honest M3 provenance
classification, including historical M0/M2 refusals and stale desktop warnings.

## Measured SF-M1 browser race and correction

[Run 41288106201](https://github.com/techrote/sandfall/actions/runs/41288106201)
has 35 successful jobs and one failed SF-M1 800×450/DPR1 job. Its original
[artifact 13076900635](https://github.com/techrote/sandfall/actions/runs/41288106201/artifacts/13076900635)
has SHA-256 `32a0640e7741ea840238a7b728308d7aa08dd854d8dab58046e003cf041f4afe`.

Home and the pre-click sample both reported frame 0. The harness mapped the
provisional Sandbox rectangle `[0,0,88,40]` into CSS `(64.75,11.25)` and sent
one click. Trusted DOM pointer events acknowledge precisely those coordinates.
Godot subsequently settled the button at `[649,16,88,40]`; Home continued
through frame 4558 without entering Sandbox. This is a deferred-layout race,
not lost browser delivery or a failed physical workload.

The passing DPR2 counterpart sampled its click at frame 3 after layout. Its
browser version differs from the failed job (156 versus 155), so those records
are not described as a controlled DPR-only comparison.

SF-M1 now reuses the unchanged M3 geometry-readiness helpers. Before each
single genuine Control click, geometry and semantic context must be unchanged
across at least two newer application frames within the existing M3 15 s bound.
Reflow/context changes replace the baseline. Receipts include initial and
confirmed frames, settled rectangles, measured browser geometry and CSS mapping;
the full transitive helper hashes join harness custody. Trusted pointer checks
and the existing actual Sandbox acknowledgement remain mandatory. No click
retry, startup sleep, hardcoded target or enlarged acceptance timeout is added.

The deterministic regression uses the original frame-zero/reflow trace in both
viewport profiles. Full targeted CI then runs the narrow DPR1 workload,
followed by both complete M1 profiles, sequentially on the fresh source export
before releasing any of the original browser matrix jobs. These are distinct
complete trials, with separate CDP ports and evidence directories; a failure
ends the preflight. All three run the unchanged 54-check M1 workload.

## Full and routine coverage

The dedicated full workflow retains all **36 jobs**. Its export job additionally
owns the preceding M1 geometry qualification; original browser cases are not
replaced by that preflight. Failed preflight evidence is uploaded with the
build evidence and prevents the dependent matrix from starting.

The reusable mainline route executes **15 substantive jobs**:

| Scope | Routine execution |
|---|---|
| Source and build | Source/native negative controls; fresh native/Godot/Web build |
| Retained ordinary input | M1 and M2, both viewport/DPR profiles |
| M3 workshop | Both profiles, all 0/1/3/8/16 capacities and body-17 refusal |
| M4 projects | Zero and sixteen bodies in both profiles, hostile ZIPs, frozen Save and safe promotion |
| Gallery/presentation | Both complete Gallery navigation workloads and real physical evidence |
| Legacy physics | Unchanged 600-tick save/restore/reset oracle |

Routine calls omit the duplicate full-native target, three extra M1 preflight
trials and separate per-scene portraits. The four Native suites protect their
applicable source changes; full targeted M4 qualification retains all capacities
and portraits. Optional omissions are explicit and are never reported as a
36/36 full-suite pass. Every reusable checkout selects the exact invoking PR
head or push commit; each browser job consumes its own run's verified export.

## Review, provenance and remaining release scope

Independent reviewers first compared immutable feature blobs, the overlapping
CI contracts and original failed browser receipts. Final reconciliation review
must cover the new harness, runner composition, routine coverage and preflight,
separately from the original M4 implementation review. The merge remains gated
on applicable exact-head CI, complete dedicated M4 qualification and resolved
independent findings. Final-main Web execution is also required.

Native, Linux Godot, compatibility Web and any explicitly executed Windows
lane keep separate identities. A skipped optional Windows, serial or stress
lane supplies no platform qualification. Source/tree/PCK/native-WASM/Rapier
and harness hashes remain attached to actual artifacts; failures retain their
original source identities.

SF-M5 still owns threaded Web, alternate hosting/browser engines, human
exhibition acceptance, broader desktop release certification and any additional
repeatability/performance claims. This integration does not establish
cross-platform bitwise replay or arbitrary live-state continuation.
