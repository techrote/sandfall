---
title: SF-M5 release qualification ledger
status: Current
document-kind: audit
scope: Exact-source acceptance coverage and outstanding v1.0 candidate gates
canonical-for: []
last-reviewed: 2026-11-01
related-documents: [SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md, SF-M3-RAPIER-WORKSHOP.md, SF-M4-PROJECTS-EXHIBITIONS.md, SANDFALL-PROJECT-FORMAT.md, audits/2026-11-01-sf-m4-final-reconciliation.md, audits/2026-11-01-sf-m5-scientific-acceptance.md]
---

# SF-M5 release qualification ledger

**Checkpoint decision: NO-GO for v1.0 publication.** Substantial machine
qualification is established below; combined-source CI, remaining Web execution,
the repeated Web-profile performance comparison and genuine human exhibition acceptance are still
open. This is an execution ledger, not a replacement for the
[normative SF-T01–SF-T12 matrix](SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md#111-executable-test-matrix).
The integrating owner must update candidate heads, exact-head runs and resulting
merged-main executions before changing this decision. No tag or release is
authorized by this document.

## 1. Source authority and accepted baseline

The starting merged `main` is **`ec94dfa50525135375dd6e35d1c5fca55c412544`**,
tree **`fb077c33386a6020d9eef91304227304cd135513`**. It preserves accepted M3
merge `72e9e1118fd06ef6026a9ef8dea3864128b2c54d`, M4 candidate
`0cc6b54d7361fd4781978ae84b803c6213a8648b`, and frozen CyberSand ancestor
`1d376fb38ff5df83691e468baa0639270a5f40e6`.

| Baseline execution | Actual result and scope |
|---|---|
| [M4 candidate 41333628953](https://github.com/techrote/sandfall/actions/runs/41333628953) | **36/36 jobs passed** at the reviewed candidate; retained as candidate evidence |
| [Merged-main Native 41336369369](https://github.com/techrote/sandfall/actions/runs/41336369369) | All four suites and fail-closed `native` aggregate passed; PR-only scope job skipped |
| [Merged-main GDExtension 41336369405](https://github.com/techrote/sandfall/actions/runs/41336369405) | Linux build, four regression shards, timing report and aggregate passed; optional Windows, serial-equivalence and physical-stress lanes skipped |
| [Merged-main Web 41336369410](https://github.com/techrote/sandfall/actions/runs/41336369410) | All **15** routine jobs passed, including M1/M2, workshop capacities, project bytes, Gallery and legacy 600-tick physics |
| [Merged-main CI contracts 41336369310](https://github.com/techrote/sandfall/actions/runs/41336369310) | Passed |
| [Merged-main Documentation 41336369348](https://github.com/techrote/sandfall/actions/runs/41336369348) | Passed with the established strict provenance reconciliation |

These are actual post-merge executions, independently checked at the start of
M5. The 36-job candidate result is not relabelled as a merged-main execution.
The [M4 reconciliation](audits/2026-11-01-sf-m4-final-reconciliation.md) owns the
preserved feature/CI contract; all application-affecting M5 integration must
repeat its full qualification and the relevant post-merge checks.

### Guarded integration checkpoints — 1 November 2026

The guarded main reverified at 21:29 UTC is
**`2a9d9d7952f554a12092abf607e63a18b398f930`**,
tree **`4cb70efa577141149950535d9590a7550ad551d0`**. GitHub confirms parents
`35377bb420c94aa82bc09fc289a1bef6b825d2fc` and exact qualified B01 head
`b29dd3aef4c470d4ac47e9c18557195059890c54`. B01 post-merge execution is still
a separate pending gate; its head checks are not relabelled as main checks.

| Package | Published source / merge | Actual disposition at this checkpoint |
|---|---|---|
| [C01 PR #9](https://github.com/techrote/sandfall/pull/9) | Head `43055dcc9d98bc4e4e461d91c0140d7fb5f7d922`; guarded merge **`35377bb420c94aa82bc09fc289a1bef6b825d2fc`** | Exact-head [Documentation 41346984200](https://github.com/techrote/sandfall/actions/runs/41346984200), [Linux 41346984368](https://github.com/techrote/sandfall/actions/runs/41346984368) and [Web 41346984372](https://github.com/techrote/sandfall/actions/runs/41346984372) passed; Linux's seven applicable jobs and all 15 routine Web jobs are complete. The merge retains reviewed tree `0d2bf2e661c75d16d543c75e8fd6812fbcf8e6f2`. Actual post-merge [Linux 41350170388](https://github.com/techrote/sandfall/actions/runs/41350170388), [15-job Web 41350170196](https://github.com/techrote/sandfall/actions/runs/41350170196) and [Documentation 41350170152](https://github.com/techrote/sandfall/actions/runs/41350170152) have now passed at that merge. |
| [B01 PR #10](https://github.com/techrote/sandfall/pull/10) | Qualified head `b29dd3aef4c470d4ac47e9c18557195059890c54`; guarded merge **`2a9d9d7952f554a12092abf607e63a18b398f930`** | All four exact-head runs passed: [CI contracts 41347969708](https://github.com/techrote/sandfall/actions/runs/41347969708), [Documentation 41347969686](https://github.com/techrote/sandfall/actions/runs/41347969686), [Web 41347969681](https://github.com/techrote/sandfall/actions/runs/41347969681) and [Linux 41347969397](https://github.com/techrote/sandfall/actions/runs/41347969397). The actual fresh export executes **6,604 scientific checks**; independent source/evidence review passed. Merge preserves reviewed tree `4cb70efa577141149950535d9590a7550ad551d0`; post-merge checks remain pending. Earlier cancelled runs retain their dispositions. |
| [D01 PR #11](https://github.com/techrote/sandfall/pull/11) | Measured source `f59ca79bf83e9c0a381c295452ea75d6771fb1f9`; current **`b5861efc248fad0d125a1de46a3623f469cb0c2f`**, tree `c38457ed1f01d9ea2f4f1aa6501041d8d1bc542b` | Earlier profile/diagnostic and exact-list CI contract corrections are retained. The current correction adds only the exact pinned-Godot sampler class registration; the original Linux clean-source failure remains failed. Nine formal Compatibility browser runs passed at f59. All applicable current-head Native, Linux, full M4 and routine Web gates remain required. |
| [A01/A02 PR #12](https://github.com/techrote/sandfall/pull/12) | Published application/build checkpoint `05fb7ee86a592ff4557cdf165e02a478824e4c54`, tree `84f48b7181f6efa1e77e90b6ffa286da23f9d9d8`; reviewed harness head `742b730b855650118acd6b6aa1eaffcf9f3e6a1a`; current **`8236a4771dab2a472d75cb17b9c77cb76402d325`**, tree `422e97480541d65f174ccfdc615944344d07d226` | Current source also retains the exact generated sampler and WebProfile class registrations. Full [M5 run 41350071260](https://github.com/techrote/sandfall/actions/runs/41350071260) completed **FAILED** at `05fb7ee`; original browser-custody and M2 readiness failures remain retained. Fresh current-head CI is pending. No final candidate execution PASS is inferred. |

The local `05fb7ee` compatibility builder returned zero but the strict verifier
**refused the delivered directory** because unlisted `index.pck-IXPUKD` was
outside its 22-file manifest. The original bytes and refusal are retained;
no file was removed to convert that directory into a pass. Its recorded inode
change time after the manifest is an observation, not proof of an actor or cause.
Separately, both independently produced CI `05fb7ee` profiles have complete
23-file inventories and pass strict verification. A fresh full local threaded
build also passed strict verification before and after immutable capture;
the retained ZIP passes independent extracted-byte verification. A later extra
file in the raw threaded directory does not qualify that changed directory or
invalidate the separately captured bytes. The immutable captured ZIP is
`Sandfall-05fb7ee-threaded-verified.zip`, SHA-256
`702f9817b8595f4559610570dea6e85d8b96fa144bed23aa81c50991c64c810d`.
The [independent review audit](audits/2026-11-01-sf-m5-independent-review.md)
separates each original refusal, observation and accepted delivery scope.

### Generated-class registration and first formal performance population

At D01 source `f59ca79`, all four Linux regression shards completed their assigned
tests and independent readback, then the unchanged clean-source check refused
the missing tracked `SandfallPerformanceSampler` cache entry. Original
[Linux run 41350726226](https://github.com/techrote/sandfall/actions/runs/41350726226)
remains **FAILED**. Correction `cd77ca2f93b17a8bc170067f8de837591c87bf67`
adds exactly the eight generated lines observed identically in all four jobs;
its published tree is the current D01 tree above. A01 additionally retains the
`SandfallWebProfile` registration. The complete corrected cache at local
`024d906d3e3a450844dbbf1a6eedc7649ab63672` is byte-identical to the already-executed
pinned Godot `05fb7ee` threaded stage. Independent review passed both corrections;
no script, regression assertion, clean-source guard or workflow was weakened.
New-head Godot/CI execution is still required.

Formal Compatibility measurements at exact `f59ca79` completed **9/9 actual
Chromium runs**, three workloads with three fresh-browser repetitions and
registered 30-second measurement windows. The reducer reports achieved native
ticks/s as mean ± sample standard deviation: Blank **60.00268 ± 0.00592**,
Material Lab **59.98787 ± 0.00792**, and sixteen bodies **43.19446 ± 0.42733**
(range **42.80639–43.65244**). Sixteen-body native p50 values span 12.0–12.1 ms,
p95 16.4–17.4 ms and lifetime maxima 28.4–36.5 ms. Timing windows and lifetime
maxima retain warmup observations; achieved-rate calculations use only the
registered measurement interval. The mean sixteen-body frame-callback rate is
5.42393/s. The recorded host uses headless SwiftShader; these are simulation
throughput and callback measurements, not a 60 FPS or GPU-frame-rate claim.
Zero reported short-tick timings reflect browser timer quantization. Summary
SHA-256 is `afe1fc8ed776ed929462d5a740a76e639a98a3c0202f6ce878b8bf01f2399f24`.
The distinct 36-run integrated-profile comparison remains in progress and is
not pooled with or relabelled as this source population.

Original CI contract failures [41349972502](https://github.com/techrote/sandfall/actions/runs/41349972502)
and [41350098900](https://github.com/techrote/sandfall/actions/runs/41350098900)
are retained. The assertion still expected only `sf-m4/**` after the reviewed
workflow added exactly `sf-m5/d01-qualification` to preserve full 36-job scope.
The independently reviewed correction requires exactly those two branch entries;
it does not broaden a wildcard, skip qualification or alter the workflow.
Its new-head CI must pass. None of these engineering merges publishes v1.0.

### Failed full workflow and bounded browser corrections

The completed full `05fb7ee` M5 workflow is **failed**, even though individual
physical/browser assertions passed in several affected jobs. The generic
runner originally compared its own newly generated untracked evidence paths
as if they were external source drift. Correction
`079dc18a0b6c235b34308c29c52624cdd00e01ae`, independently reviewed, retains both
original verifier receipts, requires clean tracked source before and after
execution, and compares every other verifier field exactly. Only untracked
paths beneath the exact newly created invocation output directory are excluded
from that comparison. It does not waive artifact hashes, outside paths or
browser assertions. Its corrected actual workshop smoke passes 42 assertions
at two workers and 800×450/DPR1; that scope does not relabel the failed workflow.

The M2 640×400/DPR2 failure sent its first trusted click against a frame-zero
temporary Control rectangle `(0, 0, 88, 40)` and remained on Home. Correction
`35c6f2af132821d1bc6995968fa681402fff77c9` reuses the existing strict M3 settled
layout observer before each single-shot M2 click and records its observed
frames/geometry. It adds no input retry or physical-oracle relaxation.
Independent review passed. The integrating owner executed the failed
configuration again: 79 assertions passed, with 649 matched native/Rapier
steps and the first stable rectangle `(649, 16, 88, 40)`, observed from frames
2 to 12. The original negative remains retained. Current A01 head `742b730`
contains these tooling corrections without a runtime/application delta;
its applicable exact-head CI must complete independently.

## 2. Evidence checkpoints

| Ref | Recoverable source and actual evidence |
|---|---|
| **E1** | Accepted baseline runs above; `.github/workflows/sf-m4-web.yml` retains 36 jobs, `web-acceptance.yml` retains the 15-job route. Actual Chromium compatibility execution covers 800×450/DPR1 and 640×400/DPR2. |
| **E2** | B01 executable `4a3acd91ca7a957a7c78167bfa5f83e6464adc0c`; audit-only head `8da850814711739f687bc0e2b4477c3d5ba5ff4a`. Five actual Linux suites pass **6,603 checks**; ten reducer negatives pass. Independent source/evidence review passed. Commands, runtimes, original failures and seven evidence-file hashes are in the [scientific audit](audits/2026-11-01-sf-m5-scientific-acceptance.md). |
| **E2b** | Exact B01/C01 CI source `b29dd3aef4c470d4ac47e9c18557195059890c54`, [actual export job 124971846494](https://github.com/techrote/sandfall/actions/runs/41347969681/job/124971846494): five original command blocks pass **6,604 checks** (230 + 1,779 + 932 + 203 + 3,460), five speed presets, twelve owner replacements, seven Gallery repeat pairs and the unchanged no-Water control. Independent reduction/log review passed; original log SHA-256 `d974c78a34053d1af37a0a7f1c204ee6bef7afa47a3b779a6c02035f2f73249b`. This later 932-check projects suite does not rewrite E2's original 931-check result. |
| **E3** | Scientific browser harness `339ae06922512f5e631221719da0b580e5bc66b0`, independently reviewed; threaded runtime/export `366ece7b337505cfa04abdd5c3f6560a19bfb0ba`: **8/8 cases**, workers requested 1/2/4/6 at both established viewports. Compatibility runtime `aeee039100a837b38cb60d25b1e87a39262d3f0f`: **2/2 cases**, one worker, actual isolation and SharedArrayBuffer both false. Its clean harness `9f5ac54` changes only documentation; all eight executable input hashes equal `339ae06`. All ten cases use Chrome for Testing 156.0.8078.80, pass 48 assertions each, and retain isolated CDP processes, trusted input, source-derived geometry, served asset hashes, observations and terminal PNGs. Independent raw-evidence review passed. |
| **E4** | C01 reviewed `ef81c2076a1c6c4fcb11832c7b0a96ed4bbfa983`; published head `43055dcc9d98bc4e4e461d91c0140d7fb5f7d922` and guarded merge `35377bb420c94aa82bc09fc289a1bef6b825d2fc` retain the reviewed tree. No product changes. **84 input + 932 project checks** and six strict diagnostic-validator tests pass locally and in the applicable exact-head lanes above. [C01 audit](audits/2026-11-01-sf-m5-c01-archive-lifecycle.md) records the retained archive coverage and original negative. Actual C01 merged-main Linux, Web and Documentation qualification has now passed at the runs above. |
| **E5** | A01/bootstrap runtime `366ece7b337505cfa04abdd5c3f6560a19bfb0ba`: **16 positive threaded cases**, 17 precise hostile-host/worker refusals and nested-path verified-byte TOCTOU execution. Positive cases cover two existing workloads × four requested worker counts × two viewports. Bootstrap source review passed through `b400953c3ce51ed288173ceeb248f599c449187f`; the added immutable-verifier custody check was executed in fresh TOCTOU-positive and same-size-PCK-hash-negative cases at `755bdd42f617c3fbf4091b4add7e1800c016aab4`. Each earlier receipt retains its actual harness identity. |
| **E5b** | Corrected hosting negatives actually executed against both **CI-produced `05fb7ee86a592ff4557cdf165e02a478824e4c54` exports**: insecure non-loopback HTTP refuses before application authority, with exactly the secure-origin diagnostic and no consumed runtime. Each case passes four browser assertions. Compatibility browser receipt SHA-256 `aec44934cf841c7fcc7323d3c5bf32c716d1c0564db9f10d217778e18d69f289`; threaded `42d0fc7796202526f4d7ac8b0477b6e94d3c79b449632f3c909f3d49156185e6`. This closes the corrected host-negative scope only. |
| **E6** | D01 instrumentation/reducer reviewed through `2c2c94a`; the bounded browser profile/diagnostic correction is `755bdd42f617c3fbf4091b4add7e1800c016aab4`. Exact `f59ca79` Compatibility execution has **9/9 formal runs**, three workloads × three repetitions, independently recomputed and reviewed. Source-specific distributions and original runtime identities are recorded above. The separate integrated-profile comparison remains **in progress**; backend fixtures and earlier development smokes are excluded from these populations. |
| **E7** | D02 protocol/schema/validator `4de296e89955a238cb9c35252dc7d7dfb34a4819` was independently reviewed with eleven passing reader tests. Corrected R01/D02 executable **`bafab0cf3396ec436100a6251662a51b4023f583`** adds a strict packet builder, machine-only preflight, secure-origin checks and original-M4-plus-identical-M5 verifier custody. **25 reader tests and independent source review pass.** The [packet preparation audit](audits/2026-11-01-sf-m5-human-packet-preparation.md) retains the original `d16fa5a` unlisted-input filtering defect, its before/after-inventory correction, exact commands, historical-verifier refusal and 14-portrait reference archive. Every human field stays empty; successful packet preparation exits **2**, with `human_origin_authenticated=false` and `release_ready=false`. Exact-head CI and an actual final-candidate packet remain required. No genuine human verdict has been supplied. |

E3's full source/runtime split is intentional: its threaded observer harness runs
E5's original export; its compatibility pair runs the later integrated `aeee039`
export. The former does not contain later integrated application changes, and
neither is relabelled as the final `05fb7ee` candidate. The eight-case
outer receipt is `build/sf-m5-scientific-browser/qualification-339ae06/threaded-execution.json`,
SHA-256 `769697f587cdcbd08b331ffc7e400bfa136f9f0ae77b118941229eb61f00a0ea`.
All eight transitive harness inputs match retained committed byte snapshots.
The two-case compatibility outer receipt is
`build/sf-m5-scientific-browser/qualification-compat-aeee039/compat-execution.json`,
SHA-256 `c052e2daa6b7c96f40e0eff7fdb9bc9bf7e4f73e25f59b2cc66d4acd0f9b78f3`.

## 3. SF-T01–SF-T12 coverage

**Qualified** below means the exact named scope has executed and passed;
**partially qualified** means a required part of the named M5 scope remains;
**unqualified** means no qualifying execution is retained; **blocked** identifies
an external acceptance dependency. A qualified row does not attest a later
integration commit. Section 5 applies to every row before release.

Production paths below are under `godot/scripts/sandfall/`; Godot test names are
under `godot/tests/`; browser tools are under `tools/sandfall/`.

| Requirement | Status at recorded scope | Source, executable oracle and measured evidence | Remaining candidate scope |
|---|---|---|---|
| **SF-T01 — source import / Web boot** | **Qualified: E1 compatibility baseline.** E5 threaded startup is separately qualified. | `tools/build_web.py`, runtime manifests and strict source reconciliation; actual E1 native/Rapier launch, frozen ancestry and pinned payloads. E5 requires secure origin, real isolation, complete bytes and supported workers before engine authority. | Fresh combined-source compatibility delivery, candidate packages and final dependency/license/provenance inventory. |
| **SF-T02 — zero actor input** | **Qualified: E1 and E2.** | `application.gd`, `session_controller.gd`, passive-subject definitions; `test_sandfall_editor_input.gd`, `test_sandfall_object_input.gd`, retained M1/M3 browser tests and `test_sandfall_gallery.gd`. Actual passive trajectory, zero actor trace, focus/modal leases and a no-Water control establish environmental motion. | Repeat applicable integrated-source input/Gallery lanes; keep optional subject metadata separate from actor authority. |
| **SF-T03 — exact Edit at tick zero** | **Qualified: E2/E2b Linux and E3's two explicitly named Web sources.** | `authoring_document.gd`, `editor_controller.gd`, material/object editors; authoring/history/input/object suites retain footprints, fill and selection. E2 exact material/state/temperature history; E3 single-cell Steam at temperature 1500 and Sand at 777, full-payload hash Undo/Redo, no solver advancement. | Execute chemical, ordinary editing and workshop coverage on both final same-candidate profiles. |
| **SF-T04 — first-advancement fence** | **Qualified: E1/E2 and E3's stated browser scope.** | `session_controller.gd`; `test_sandfall_authoring.gd` retains real native0/Rapier1 partial-failure retirement. E2 covers speed/pause boundaries. E3 observes first actual Run advancement retiring both stacks, rejects Run Undo and verifies Reset & Edit starts empty. | Integrated-source Linux failure injections and browser regressions. E3's exactly-one-Step control follows a real Reset; it does not claim the original unpaused Run stopped after one tick. |
| **SF-T05 — pause / Step / five presets** | **Qualified: E2 fixed-step arithmetic and E3 one-Step execution.** | `session_controller.gd`, `simulation_host.gd`; `test_sandfall_scientific.gd` executes 0.25×/0.5×/1×/2×/4×, each with **61 native + 61 Rapier steps**, exact requested pacing, zero paused advancement, real phase/thermal effects and reset velocities. E3 zero-body Step gives native1/Rapier0. | Integrated-source regression and D01 achieved-rate/backlog measurement. Never equate requested 60 Hz with measured throughput. |
| **SF-T06 — Pristine → Modified → Reset** | **Qualified: E1/E2 and E3.** | Document/session owners, authoring/object/project/promotion suites; immutable initial Save, physical interventions, nonphysical camera/style and explicit confirmed promotion remain distinct. E3 restores the exact authored full-world hash and Steam/Sand tuples after real conversion; E2 restores initial body poses and velocities. | Repeat project/promotion and chemical Reset on the combined candidate in both profiles. |
| **SF-T07 — 0/1/3/8/16 bodies; atomic 17** | **Qualified: E1 compatibility and E2 Linux lifecycle.** | `rapier_object_registry.gd`, `simulation_host.gd`, native coupling; objects/history/projects tests and M3/M4 browser harnesses check IDs, true motion/contact, visible pixels, Save/import/reset and atomic body17 refusal. E2 repeats **[16,0,1,3,8,16] twice**, 1,440 native/1,200 Rapier ticks, 10,560 body samples, retirement and collider rebuilds. | Full threaded workshop/project/input matrix and measured sixteen-body workload at the integrated source. E5's real sixteen-body startup does not replace every capacity assertion. |
| **SF-T08 — actual fluid/body feedback** | **Qualified: E1 and E2.** | Production feedback owner and `test_sandfall_gallery.gd`; Fluid Messenger **600 actual ticks**, 57,746 contacts, 590 feedback applications, actual displacement; matching no-Water control stays fixed with zero feedback. Passive subject remains in camera through 1,200 real ticks. | Integrated-source Fluid Messenger/Gallery in both profiles; no scripted transforms or inferred impulses. |
| **SF-T09 — ZIP-of-folder round trip** | **Qualified: E1's existing archive and browser scope.** | `archive_zip.gd`, `archive_codec.gd`, `archive_json.gd`, session/file owners; archive/projects/interop tests, `sf_m4_archive_fixture.py`, M4 real chooser and download workloads. Retained five capacity round trips, independently authored Python ZIPs, editable folder identity and initial-state reconstruction. | Re-execute applicable combined-source browser upload/download, including threaded profile; attach actual bytes and logical identities to final packages. |
| **SF-T10 — bounded hostile refusal** | **Qualified: E1 and E4's merged lifecycle additions.** | Retained codec **184 checks / 93 refusals**, interop **19 dispositions / 83 checks**, browser **14 mutated archives**. Traversal/collisions/links, ZIP64/encryption/metadata, CRC/DEFLATE, size/ratio, schema/hash/material/body parameters and old-session preservation are covered. E4 adds stale input-epoch staging and four chooser cancellation/replacement cycles, consumed confirmation and stale callbacks. | Relevant combined-source browser archive jobs and subsequent merged-main checks; C01's own post-merge qualification has passed. `sf_m4_expected_diagnostics.py` must retain precise fixture/error matching. New callback injections are Linux production-owner tests, not fabricated browser upload claims. |
| **SF-T11 — browser / profile coverage** | **Partially qualified.** | E1 actual compatibility Chromium; E3 eight threaded and two unisolated compatibility chemical cases; E5 16 threaded startup/physics cases with actual requested/resolved/participating worker counts and real COOP/COEP/security observations. Same-size hash tampering and worker/CSP/host failures refuse before application authority. Later `aeee039` sixteen-body compatibility positives also pass both viewports without isolation. | Complete declared profile/worker/viewport feature matrix at the final candidate, while E5b separately qualifies the corrected both-profile insecure-origin refusal at `05fb7ee`. Other browser engines and public hosting arrangements remain unqualified unless actually executed. |
| **SF-T12 — scientific / evidence integrity** | **Partially qualified for final release.** Local named evidence is source-bound and reviewed. | Exact runtime/payload/harness identities, command/input traces, original failures and honest platform scopes are retained in E1–E5. E2 reducer records local selected Golden Run tolerances and two actual repetitions; E3 records trusted DOM input and actual native tuple changes. | One candidate identity, all applicable exact-head/post-merge CI URLs, measured performance distributions, downloadable package custody and final independent integration review. Human presentation acceptance remains separately blocked below. |

## 4. Scientific and runtime limits

E2's seven Gallery scenes each execute twice for 600 ticks. Their measured pose
component spans and final native-hash differences are zero in those **two local
observations**. The selected Fluid Messenger and Endless Kinetic Loop limits
remain **1/64 cell (or cell/s)** and **1e-4 rad (or rad/s)**; unselected scenes
have descriptive variance only. This does not establish whole-stack bitwise
replay, exact live-state continuation or cross-browser equivalence. The existing
sixteen-body fixture records 1,870,280 contacts and 15 contacting body pairs.

The trajectory-oracle development failure remains in the B01 audit. The
correction models the pinned single-precision solver's four integration
substeps; the original 0.002-cell/1e-4-radian limits are unchanged. The **Godot
Rapier addon is pinned at 0.35.2** (`172c66f5a88bf1164c2b8cf2d775ed889edefd75`);
its vendored lock names the **rapier2d 0.35.1 crate**. These are distinct source
identities, not a substituted addon dependency.

E3's small chemistry fixture resolves all requested pools correctly but observes
peak participation **1 for worker1, 2 for worker2/4/6**. E5's larger fixtures
observe broader participation, including six workers; two configured-six cases
observe five. No receipt substitutes the configured pool size for actual work.
E3's converted Water is observed at native ticks **197–219**, after the 180-tick
Steam lifetime has actually elapsed. Its first-step exact tuple and authored
Reset hashes agree across these cases; this is not a cross-browser replay claim.
The compatibility pair observes conversion at ticks **210/209** and restores
the same authored hash, with actual one-worker execution and no isolation.

### Hosting correction and retained genuine failure

The attempted `aeee039` **non-loopback insecure HTTP compatibility positive
failed**: pinned Godot 4.7's loader requires a secure context even when engine
threads are disabled. The original browser receipt runs for 150,230 ms and
retains the loader diagnostic; `pinned-godot-secure-context.json` binds the served
`index.js` bytes and the actual engine check. It is not a successful hosting
configuration. Both-profile preflight correction `85f1555717034826a3ea6d8ee53a41707a2d08e7`
and harness correction `7ed150075c8af103698572789d737278f64962ac` are incorporated
in the published A01 candidate. E5b now qualifies the corrected refusal on
both CI-produced `05fb7ee` profiles. The real browser/host records retain the
precise secure-origin error, no application observation and only HTML/icon
requests. Their separate verifier SHA-256 values are
`af123876e10eaa18ed6e501571e69ad37c1f1a1cdc2f64750a39218813435c4b`
(compatibility) and
`2305e27df0622ce9a0e4659efc3eea6cdbd5ca22ec3d65aa55de2f40ee626f65`
(threaded). The earlier insecure-HTTP positive remains failed.

The supported contract is **HTTPS or a loopback secure origin for both profiles**.
Compatibility works without COOP/COEP or SharedArrayBuffer; `aeee039` actual
sixteen-body controls report 108/110 native and matching Rapier ticks at the two
viewports. Threaded Web additionally requires COOP `same-origin`, COEP
`require-corp` and supported workers. No engine feature check is bypassed.
See the [Web qualification contract](SF-M5-WEB-QUALIFICATION.md).

| Runtime identity | SHA-256 |
|---|---|
| E2 Linux Godot 4.7 | `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |
| E2/E4 merged-main Linux native | `9a6915e508afe25a5ebee5461f6cadb160976320a0f9eb28e13bd7b7534703e3` |
| E2/E4 Linux Rapier | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |
| E3/E5 threaded verifier | `519362fbf9bdd02cfba42bcdadc0a1f7ad6222618064b9912c04ae0c093d0b6e` |
| E3/E5 complete `SHA256SUMS` | `9110ff3dbc468618d28cf20953ef276d45687d32e9e7cc51b30340d83eb0bf57` |
| E3/E5 native threaded WASM | `7a9ab24c1da31774003cdb3864fca52ce943315fb908ef9027bac158748d38e0` |
| E3/E5 PCK | `1847705d9c3251f9ce54003fa76b3f4759e941c515af7f26b5cb07ed9491f2b1` |
| E3/E5 Rapier WASM | `b4020962f6ff6c5f2c07436a94cdbf7b5e2096a5fc5832e4ff5526378ce88528` |
| E3 compatibility verifier (`aeee039`) | `64a3071df1d15df584cebbcdbaa4bbfdcf1fc747eadff9c2049c89a9d08d15b2` |
| E3 compatibility native WASM | `09f7b89af5c94127b8f7a0d720e28224836dac5e815eb174c29b8a8ddc5e467c` |
| E3 compatibility PCK | `7eebb17185a8094d4d3064e9dc2ab4ea521f7f6122d5f4a5fe07a507b7ce5296` |
| E3 compatibility Rapier WASM | `5ff6933670c1377c24dcbac30d67758a307165eacdcbd33b25bf01669577c4c2` |

The original E3 palette-selection failure is preserved under
`build/sf-m5-scientific-browser/dev-threaded-w2-dpr1/`: `browser.json`
SHA-256 `eb8996d376d064573f88ed28e1f3f909b2fedc13d15207386b1e7e22e86c89fc`,
`commands.json` SHA-256 `d3f9e9c38d562279e861a178b481714b184a96d992f7eaad16e9ed98bbf22ef7`.
Its real keyboard sequence selected Salt because PopupMenu Home did not establish
the assumed baseline. The corrected harness starts from asserted Wall and moves
exactly 20 valid palette entries to Steam, once. The original failed receipt,
PNG and all original helper byte identities remain; no failed click is retried
or physical assertion weakened. The fourteen original evidence files and their
summary are archived as `sandfall-m5-scientific-browser-original-negative.zip`
(101,761 bytes), SHA-256
`5456ccfb15757deb36fcab9f9ac5b5abf1d318716ac057bdf42ba04fdadcbcb1`.

## 5. Candidate closure and owner-dependent acceptance

| Gate | Current disposition | Required completion |
|---|---|---|
| Combined-source and guarded integration | **Partially qualified** | Record exact PR heads/review dispositions; run applicable four-way Native, Linux/Godot, Documentation/provenance and source-specific Web gates; repeat all 36 M4 jobs for application-affecting changes; merge only the reviewed passing expected head and verify resulting `main`. No earlier runtime is relabelled as later-source execution. |
| Mandatory compatibility delivery | **Partially qualified** | `aeee039` qualifies E3 chemistry and real sixteen-body startup without COOP/COEP. Fresh final-candidate exports and complete ordinary browser execution still require their own verified bytes and gates. HTTPS/loopback remains required. |
| Additional threaded delivery | **Partially qualified** | Finish declared feature coverage and candidate-host/package validation. E3/E5 establish actual supported multiworker mechanism and precise refusals, not every host/browser configuration. |
| Production Web performance | **Unqualified at this checkpoint** | Execute E6 on Blank, Material Lab and sixteen-body Gallery in both profiles; retain repeated distributions, actual ticks/s versus requested rate, native/Rapier/rebuild timing, render/frame/backlog/resource observations, CPU/browser/workers/toolchain/source/duration and outliers. Establish criteria from measured baselines and the normative policy without changing fixed dt or capacity. |
| Human Gallery exhibition review | **Blocked: genuine human verdict outstanding** | Use the [human protocol](SF-M5-HUMAN-ACCEPTANCE.md), `sf_m5_human_packet.py` and `sf_m5_human_review.py packet` with one candidate plus seven matching browser/PNG/Run-evidence sets. Fourteen original M4 portraits are prepared as clearly historical references, source `0cc6b54`, index SHA-256 `3756068f8ebb32e3a7d6e8ea2662615053f36968fca05b570089786fbe6f3ec5`; they are not relabelled as current M5 evidence. Current-candidate M4 portraits may be reused only with their unchanged original verifiers plus a separate passing M5 verifier for the identical source and complete delivered inventory, as defined by the protocol. Every human field remains empty. Preserve the eventual original human statement and verify its origin. |
| Release package and notes | **Partially prepared; final candidate unqualified** | [Draft candidate notes](SF-M5-RELEASE-CANDIDATE.md) describe actual features, hosting and limitations without a tag or publication. Bind final source/PCK/native/Rapier/worker assets, pins, licenses/provenance, reproducible commands, downloadable packages and independent review after exact-source gates. Publishing/tagging needs separate explicit authorization. |

Optional Windows desktop, serial-equivalence and physical-stress lanes keep their
existing triggers. Their skipped state is not PASS and does not by itself block
a declared Web-only release. Alternate browser engines, unexecuted public hosts,
whole-stack bitwise replay and exact live-state continuation are not promoted
into supported claims. The mandatory human/performance/candidate gates above
remain visible regardless of a green compatibility build.
