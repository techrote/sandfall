---
title: SF-M5 independent technical review checkpoints
status: Current
document-kind: audit
scope: Commit-bound independent source review, retained failures and observed qualification scopes before final candidate closure
canonical-for: []
last-reviewed: 2026-11-01
related-documents: [../SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md, ../SF-M5-WEB-QUALIFICATION.md, 2026-11-01-sf-m5-c01-archive-lifecycle.md, 2026-11-01-sf-m5-scientific-acceptance.md, 2026-11-01-sf-m4-final-reconciliation.md]
---

# SF-M5 independent technical review — 1 November 2026

**Technical source review passes for the exact checkpoints identified below.
This is not a final candidate qualification or human Gallery verdict.** At this
audit's 21:15 UTC live-CI observation, C01 was merged, its actual merged-main
qualification was still running, and B01's Linux aggregate and the integrated
A01/A02 qualification were incomplete. A subsequent fresh `05fb7ee`
compatibility export also failed the strict artifact inventory check, as
recorded below. The v1 publication disposition therefore remains **NO-GO
pending the remaining release gates**.

This record is written by the C01 review agent. It distinguishes that agent's
independent review of other owners' changes from the B01 agent's independent
review of C01/D02 changes. These are technical agent reviews, not GitHub account
approvals or authenticated human acceptance. The integrating owner retains sole
responsibility for guarded publication of engineering branches, exact-head
checks, merges and post-merge qualification.

## 1. Reviewed sources and independence

The source and tree identities below were read from Git objects; the C01 merge
identity and parents were additionally read from GitHub. Equal trees establish
equal reviewed source bytes, not equivalence of separate workflow executions.

| Package / review scope | Exact source | Source tree | Independent disposition |
|---|---|---|---|
| Accepted M0–M4 main | `ec94dfa50525135375dd6e35d1c5fca55c412544` | `fb077c33386a6020d9eef91304227304cd135513` | Starting post-merge qualification independently reverified; unchanged acceptance is retained. |
| C01 lifecycle tests and audit | Local `ef81c2076a1c6c4fcb11832c7b0a96ed4bbfa983`; published `43055dcc9d98bc4e4e461d91c0140d7fb5f7d922` | `0d2bf2e661c75d16d543c75e8fd6812fbcf8e6f2` for both | C01 author; B01 independent reviewer: PASS, no blocking findings. |
| C01 normal merge, PR #9 | `35377bb420c94aa82bc09fc289a1bef6b825d2fc` | `0d2bf2e661c75d16d543c75e8fd6812fbcf8e6f2` | Parents are accepted `ec94dfa` and qualified `43055dc`; merge preserves the reviewed tree. Actual post-merge CI is separately tracked below. |
| B01 scientific implementation | `4a3acd91ca7a957a7c78167bfa5f83e6464adc0c` | `88d00bb0d67b9fe029e055d99064722a37ac436f` | B01 author; C01 independent source, oracle, arithmetic and evidence review: PASS. |
| B01 evidence documentation | `8da850814711739f687bc0e2b4477c3d5ba5ff4a` | `234de8257b5cf20af3c4fadde2953bbff1558fdf` | C01 review of measured claims and source/log custody: PASS; executable source unchanged from `4a3acd9`. |
| B01+C01 published integration, PR #10 | `b29dd3aef4c470d4ac47e9c18557195059890c54` | `4cb70efa577141149950535d9590a7550ad551d0` | C01 reviewed concatenated documentation routes and scientific-suite registration/weight. Reviewed test bytes retained; CI scope below. |
| D01 performance instrumentation / reducer | `2c2c94a9f5ff5c6ec8431faca01c3355cd3f3bcf` | `dd3e5d37466ff4a0c365f919a4930c8921378d95` | D01 author; B01 production-source review and C01 subsequent instrumentation/tooling review: PASS within their stated scopes. |
| D01 published stack, PR #11 | `7c9cfe3004054f4fb8b8733f6cee18ae7bc1d164` | `94ab3f518a7e0d8a91f944d3545e3176b38c002c` | C01 reviewed preserved B/C stack, registration, full-M4 trigger and explicit profile-field correction. A separate CI test correction is recorded below. |
| A01 initial runtime / hosting | `366ece7b337505cfa04abdd5c3f6560a19bfb0ba` | `ff9b51e9b3f1641837e6f1c2b4f7a2b2edbde694` | Integrator author; C01 independent implementation review after corrective changes: PASS. Earlier actual threaded evidence retains this source identity. |
| Integrated A/B/C/D runtime and scientific browser | `aeee039100a837b38cb60d25b1e87a39262d3f0f` | `c21efb00bec3d6da3a339ef17fcbbfe25e4878e8` | C01 independently reviewed the combined source and the actual integrated Linux/compatibility evidence described below. |
| Reviewed A01/A02 published candidate, PR #12 | Local `6ca0fe72e6bc67d398d542e340aff5f3b09c5978`; published `05fb7ee86a592ff4557cdf165e02a478824e4c54` | `84f48b7181f6efa1e77e90b6ffa286da23f9d9d8` for both | C01 reviewed source, CI wiring, secure-origin correction, source gates and final documentation delta: PASS. Final full runtime qualification remains open. |
| D02 human-review protocol / validator | `4de296e89955a238cb9c35252dc7d7dfb34a4819` | `c7598d0865c8cf284313aae7371e5f16312c7fdb` | C01 author; B01 independently reran eleven validator tests and pending-record CLI: PASS for machinery only. |
| R01 initial source-scoped ledger | `9f5ac54d068b81bc13828d2d8df228302cade21b` | `9c53134abd6d89d79f686a85a9f5d97c496586e3` | B01 author; C01 evidence/scope review: PASS. Later ledger or packet changes require their own review. |

The integration review checked that the only conflict in `simulation_host.gd`
was adjacent declarations, preserving all four Web-profile/worker-observation
and performance/tick-start fields. It did not replace the separate native,
Godot, browser or performance execution gates. No review in this table certifies
an unlisted later source head merely because its branch has the same name.

## 2. Material findings and corrections

The following findings received corrections at reviewed source checkpoints. Their
original failures remain evidence; correcting a harness or contract does not
convert its earlier execution into a pass.

| Finding | Reviewed correction and retained boundary |
|---|---|
| Automatic worker policy could request two workers when the browser reported only one logical processor. | A01 now requests one in that case and preserves the existing 2/4/6 policy above it. Runtime reports requested/configured participation separately from actual observed workers. |
| Startup verification initially left a gap between hashing payloads and Godot fetching them again. | Verified payload buffers are privately retained; actual WASM/PCK/side-module fetches consume their copies, and executable loader/worklet/pthread paths use verified immutable Blob URLs. Persistent and real-host TOCTOU cases exercise later changed responses. |
| A presumed separate worker script did not match the pinned Godot 4.7 template. | The implementation verifies the actual template mechanism, which uses `index.js` for pthread startup. No nonexistent worker asset is accepted as evidence. |
| Performance populations could combine different runtime payloads. | Reducer grouping includes native and PCK identities, browser/profile, hardware allocation and workload. Mismatched runtime hashes and available parallelism are rejected. Instrumentation does not change fixed dt or skip simulation work. |
| New CI wiring originally lacked a repeated-performance reduction and omitted some source-sensitive triggers. | Three repetitions per workload feed the reducer; build-file paths and Sandfall tooling are included, and the full A01 branch trigger matches routine-Web suppression. Full-only jobs may be skipped only in the explicitly routine scope. |
| C01's first modal-input test observed geometry before layout settled. | The test waits for two stable eligible rectangles before one genuine click. It does not retry state-changing input, add arbitrary sleep, relax the production owner contract or erase the original four-failure run. |
| The first B01 constant-velocity comparator assumed double-precision whole-step arithmetic. | Pinned Rapier's four float32 substeps were independently traced and reproduced. Position tolerance remains 0.002 cells and angle tolerance 0.0001 radians. Neither the solver nor dt changed. Addon 0.35.2's locked Rapier crate 0.35.1 is explicitly distinguished from the addon version. |
| The first browser chemistry fixture incorrectly assumed Home selected the first material. | The corrected trusted-input sequence asserts Wall before the bounded ArrowDown traversal; exact chemical/thermal tuple and history/reset oracles remain unchanged. The original failed browser receipt is archived. |
| A compatibility-over-insecure-HTTP positive was unsupported by the pinned engine. | Actual `aeee039` execution failed because Godot 4.7 itself requires a secure context. Shared preflight now requires HTTPS or a loopback secure origin for both profiles; COOP/COEP remains threaded-only. Insecure origin is a precise negative, not an engine check bypass. |
| Browser descendant processes can outlive their controller. | Both new runners retire their own process group even after the controller exits and remove only their own temporary Chrome profile. Logs, screenshots and receipts remain. A real child-lifetime negative exercises the obsolete `poll()` guard. |
| A cleanup test read host-mounted `/proc/<namespace-pid>` in a sandbox. | Test-only `b411ba966ce6ca7188bbb808c8f89e3f309430c3` instead observes EOF on the actual child's uniquely inherited stdout pipe, retains the process-group assertion and five-second deadline, and changes no cleanup implementation. C01 independently reran both tests and proved the obsolete guard still fails. |
| Godot left a random shadow PCK in a freshly recreated export directory. | Cleanup is restricted to regular, nonsymlink `index.pck-` plus six-alphanumeric suffix files with the pinned Godot 4.7 pack header. Removed size/hash/path are logged. Canonical output and historical exports remain unchanged; three negative tests pass. |
| The active CI contract test still required only the original M4 qualification branch. | Local correction `f19a97e538adb09a64e5153c621618655554ecc6`, tree `057cf1f3cb82ef0e9310adb7c5c84aa8a65ea5f1`, requires exactly one push declaration containing `sf-m4/**` and the reviewed exact `sf-m5/d01-qualification` branch. Existing 36/15 job counts and source assertions are untouched. B01 independently approved this one-file test delta. |

The last CI correction passed all five commands actually registered in
`ci-validation.yml`: 6 provider-policy, 8 native-inventory, 9 workflow-contract,
35 sharding and 6 fresh-Windows-custody tests. This is **63 passes and one
unchanged Windows-only process-observation skip on Linux**. Actionlint and the
provider-policy checker passed. Removing either admitted branch, widening to
`sf-m5/**`, adding `main`, or duplicating the branch declaration each failed the
corrected oracle.

A broader, unregistered discovery of all `tools/ci` tests retained six errors
from old LCB005 tests referring to two retired workflow files, plus that same
Windows-only skip. No historical test, retired workflow or skip policy was
changed to hide those errors. The original D01/A01 active-CI failure logs are
jobs [124977837872](https://github.com/techrote/sandfall/actions/runs/41349972502/job/124977837872) and
[124978222101](https://github.com/techrote/sandfall/actions/runs/41350098900/job/124978222101);
the narrow branch-test fix needs its own current-head CI execution after
integration.

### Open fresh-export inventory failure

After the CI snapshot above, the full local `05fb7ee` compatibility builder
returned zero, but the unchanged M5 verifier correctly refused an unlisted
`index.pck-IXPUKD`. It is 4,685,936 bytes with SHA-256
`faa1bba217bdb2e066273a87d090581e8ab4639bb2be458f417209684114d794`;
the canonical PCK is separately 4,852,716 bytes with SHA-256
`3e5bd367a670414f37d265836b46fd936c2374aec07ca73a0150592440f0f296`.
The original export, manifest and failure remain unchanged.

Independent read-only diagnosis confirmed that the current module and valid
Python cache contain the reviewed cleanup call; its exact glob matches this
filename and its pack header is valid. Nevertheless the original build log
contains no cleanup marker and the 22-file manifest omits the extra file.
The manifest enumerates every regular output file, independently of the
cleanup's PCK pattern. The extra file's observed ctime
`1793567768925515525` is 164,803,889 nanoseconds after the manifest ctime
`1793567768760711636`, while its mtime is earlier; its observed inode directly
follows the manifest's. This suggests later insertion/restoration or metadata
change, but does not identify the responsible process or filesystem mechanism.

The integrating owner is conducting a separately labelled diagnostic export
with inventories before preflight, after preflight and after manifest creation,
plus a whole-directory archive made inside the same process. This is mechanism
investigation, not an export-only qualification shortcut. The earlier cleanup
source/unit-test review does not clear this runtime failure. A fresh strict
candidate execution is still required; no manual deletion, rewritten manifest,
extra-file allowlist or relabelling of this failed result supplies a pass.

## 3. Executed evidence independently checked

### Retained baseline and C01

All five accepted `ec94dfa` push workflows were independently read before
implementation: [Native 41336369369](https://github.com/techrote/sandfall/actions/runs/41336369369)
retains four suites and the fail-closed aggregate;
[Godot 41336369405](https://github.com/techrote/sandfall/actions/runs/41336369405)
has seven required successful jobs and five documented optional/scope skips;
[Web 41336369410](https://github.com/techrote/sandfall/actions/runs/41336369410)
has fifteen representative successful jobs and two full-only skips;
[CI configuration 41336369310](https://github.com/techrote/sandfall/actions/runs/41336369310)
and [Documentation 41336369348](https://github.com/techrote/sandfall/actions/runs/41336369348)
passed. The retained complete [M4 36/36 run 41333628953](https://github.com/techrote/sandfall/actions/runs/41333628953)
belongs to its original qualified candidate; it is not relabelled as a new main
or M5 execution.

C01 changed two tests and their documentation, not the archive codec or product
owner. Independent review found its stale-callback checks nonvacuous: a current
chooser exists, valid current bytes stage successfully, and one current
confirmation installs exactly once. Four retired callback cycles preserve
native bytes, object poses/RIDs, document/history and current owner identity.
The test labels callback injection as native lifecycle evidence, separately
from genuine browser file delivery. Local 84 input and 932 project assertions
passed, with the original geometry failure retained. Existing precise archive
refusal/diagnostic and independent ZIP interoperability coverage is reused.

### Scientific evidence

The original B01 local source `4a3acd9` passed 6,603 assertions across its five
suites; the later combined source includes C01's added project assertion.
The exact `b29dd3a` fresh CI export job
[124971846494](https://github.com/techrote/sandfall/actions/runs/41347969681/job/124971846494)
was independently read and its five complete executed command blocks were
reprocessed with the reviewed scientific reader: **230 authoring + 1,779
objects + 932 projects + 203 Gallery + 3,460 science = 6,604**. GitHub timestamp
prefixes were removed for parsing; the complete original job log, including
separate archive decompression negatives, was retained.

That recheck confirmed all five speed presets, 61 real native and Rapier steps
per equal-tick case, actual chemical/thermal changes, exact authored reset, and
twelve physical-owner replacements. All seven Gallery scenes had two actual
600-tick executions with observed component spans of zero in this local
one-worker condition. The two registered Golden scenes retain 1/64-cell
position/linear-velocity and 0.0001-radian angular limits. Fluid Messenger has
actual native contacts, applied nonzero feedback and displacement; its
no-Water control remains stationary without applied feedback. These observations
do not establish cross-platform or whole-stack bitwise replay.

The integrated `aeee039` local export was independently crosschecked against
its clean detached source, every staged GDScript, actual Godot/Rapier payloads
and native ELF `8e5f3b775afb399ceabe0b1589f11518e3a33f2e64bfc03d7a64cc9c4d53680a`.
Its same five-suite report also has 6,604 passing assertions. The original
complete build log retains C01's separate 84-assertion input receipt and the
strict expected-error archive records.

### Actual browser scopes

The independently checked chemical browser evidence comprises eight threaded
cases at runtime `366ece7`, workers requested 1/2/4/6, and two compatibility
cases at runtime `aeee039`. Each has 48 assertions and uses 800×450 DPR1 or
640×400 DPR2, trusted input, source-derived geometry, served-byte hashes and
terminal screenshots. Compatibility was genuinely nonisolated with
`SharedArrayBuffer=false`, on a secure loopback origin. Its Steam-to-Water
transition was observed at ticks 210/209, and full reset restored authored cell
hash `3f0491144dfea99f6e10c324cca6502fcf61eed0daceecf114693c991b7dec2d`.

The small threaded chemistry fixture observed only two participating workers
for requests above one. The separate earlier Gallery/material bootstrap matrix
completed sixteen positives and seventeen strict host negatives; six requested
workers produced observed peaks five or six depending on the case. Requested
counts are never substituted for actual participation. Nested-path TOCTOU
execution verifies the consumed immutable bytes. These Chromium results remain
bound to their actual source and browser, not to a final changed export or to
unexecuted browser engines.

The separate archived D01 measurement coordinator at
`42e17f82f383120a8b9341856af9b49e94612d6c` also received C01 source review.
It runs the requested target checkout's own M4 verifier and unchanged
performance harness, records its separate coordinator/helper identities, serves
immutable verified bytes, and requires matching target HEAD, clean harness and
post-run byte checks. It adds no A01 startup policy to D01's earlier source.
An executed wrong-head negative refused before browser launch. This review is
not a production PR #11 source change or a completed repeated-performance result.

### Actual integrated source gate

At published source `05fb7ee`, completed M5 source/native job
[124978136241](https://github.com/techrote/sandfall/actions/runs/41350071260/job/124978136241)
was independently inspected. M0, M2 and M3 refusals remain present; M5 admits
only the reviewed getter additions in `cyber_native_cell_world.cpp` and `.hpp`,
with native patch SHA-256
`8e52ba731b4257cbfc29b0e5ce4e8e81724b425e5c7112744362905c3412f38b`.
The receipt reports no changed runtime/pin or inherited-gate paths and eighteen
materialized LFS payloads. Its 109 Python tests, two bootstrap tests, JavaScript
oracle tests and fresh focused native receipt passed. The original native-M0
refusal remains a failed receipt. This successful focused job is not the full
four-suite Native aggregate or the complete M5 workflow.

## 4. CI checkpoint and retained evidence identities

| Source / gate | Independently observed result at 21:15 UTC |
|---|---|
| C01 published `43055dc` | [Docs 41346984200](https://github.com/techrote/sandfall/actions/runs/41346984200), [Godot 41346984368](https://github.com/techrote/sandfall/actions/runs/41346984368) and [Web 41346984372](https://github.com/techrote/sandfall/actions/runs/41346984372) passed: 23 required successful checks, seven explicit optional/scope skips. The original native inputs remain unchanged; no fresh four-suite Native run is asserted for this tests-only head. |
| C01 actual merged main `35377bb` | [Docs 41350170152](https://github.com/techrote/sandfall/actions/runs/41350170152) passed. [Godot 41350170388](https://github.com/techrote/sandfall/actions/runs/41350170388) and [Web 41350170196](https://github.com/techrote/sandfall/actions/runs/41350170196) were still running. Previous-head results do not close this gate. |
| B01+C01 `b29dd3a` | [CI configuration 41347969708](https://github.com/techrote/sandfall/actions/runs/41347969708), [Docs 41347969686](https://github.com/techrote/sandfall/actions/runs/41347969686) and [routine Web 41347969681](https://github.com/techrote/sandfall/actions/runs/41347969681) passed; Web has fifteen required successes and two full-only skips. [Linux/Godot 41347969397](https://github.com/techrote/sandfall/actions/runs/41347969397) remains incomplete. Earlier superseded/cancelled runs remain cancelled, not passing. |
| A01/A02 `05fb7ee` | [Docs 41350098660](https://github.com/techrote/sandfall/actions/runs/41350098660) and the focused source job above passed. [Native 41350098958](https://github.com/techrote/sandfall/actions/runs/41350098958), [Godot 41350098755](https://github.com/techrote/sandfall/actions/runs/41350098755) and [full M5 41350071260](https://github.com/techrote/sandfall/actions/runs/41350071260) remain incomplete. [CI configuration 41350098900](https://github.com/techrote/sandfall/actions/runs/41350098900) failed the stale branch test; the reviewed correction must be qualified at the subsequent actual head. Routine Web suppression is intentional because the full M5 workflow owns this branch. |

Selected retained evidence identities make the review traceable without making
temporary workspace paths a public download promise. The final candidate
packet must carry its relevant original evidence and inventory.

| Retained record | SHA-256 |
|---|---|
| C01 evidence archive, `sandfall-m5-c01-evidence.zip` | `c21ff0d4b8d9da19b9fea836a491b6357998bc3896eec958a72844a39ea110f9` |
| Original C01 input geometry failure | `1fdea139d980523fa6d86dd8d250b4a3174522896c2def480ceb54ec82be21c9` |
| Original scientific-browser negative archive | `5456ccfb15757deb36fcab9f9ac5b5abf1d318716ac057bdf42ba04fdadcbcb1` |
| Compatibility chemistry `aeee039` evidence archive | `989326684652808882c7c9be8263013c2c7b701c7f59591505478c1779e777a4` |
| Integrated `aeee039` five-suite scientific report | `b1cf61a48b60fa895d353024af3c266dfa280bec7922fa3611409dc9dd418481` |
| Integrated `aeee039` complete compatibility build log | `5a5ebf96e37a39c787fd7050b096b03afedaed1b14578c900ca4afc8c001897f` |
| `b29dd3a` downloaded complete CI build log reviewed above | `d974c78a34053d1af37a0a7f1c204ee6bef7afa47a3b779a6c02035f2f73249b` |
| Original insecure-origin compatibility browser receipt | `aaa492691b725ea29109ff0bcc45ff468c55058f0754a358aeb68a3594d2b3ef` |
| Original insecure-origin compatibility result | `b872b9681d830ba1dac31799bcb4e352973d88c85e4b4739797773d6414cf500` |
| Fresh `05fb7ee` compatibility build log with the later inventory refusal | `5e4bdf61a619744676e3d56813d81d70a0f53563f8572687cbd7b01f046b0f30` |
| Original `05fb7ee` compatibility manifest before the extra-file refusal | `c09eee4d631e580f7235508ccb922b76e7ee0877f0d8fedd8d189fc2c6128c98` |
| Local reproduction of original stale CI branch assertion | `cf12bca3bcbb293bfab038eb57e82dab623c1dd249f70685a2696b8782cf4a22` |
| Broader discovery retaining six retired-workflow errors | `6e4d4842e3e0fb6e796a59efab6a5feb009efcb912e75cf68337d3fea1961851` |

## 5. Remaining acceptance and integration boundaries

The independent source reviews above support continued guarded engineering
integration. They do not waive any remaining execution gate:

1. Finish applicable exact-head CI after the final source/test corrections,
   including the preserved complete 36-job M4 scope for application changes,
   four Native suites and fail-closed aggregate, Linux/Godot, documentation,
   both actual Web profiles and all newly applicable M5 jobs. Preserve and
   investigate failures before considering a merge.
2. Verify every actual merge's resulting main and required mainline execution.
   At this checkpoint C01's post-merge gate is open; B01 and later engineering
   heads must not inherit a synthetic post-merge pass.
3. Finish fresh candidate exports and the actual profile/worker/viewport,
   hosted-byte, isolation, refusal, archive and physical evidence. Changed
   build/export inputs require new artifacts; `366ece7`/`aeee039` evidence
   keeps its original identity.
4. Complete repeated production performance measurements and their strict
   reduction, including source/runtime/hardware identity, outliers and
   falling-behind behavior. Instrumentation review and local unit tests do not
   establish a measured frame-rate or throughput claim.
5. Review the final R01/D02 tooling integration and assemble a candidate-bound
   seven-scene human packet. The reviewed D02 pending record exits 2 and always
   reports `human_origin_authenticated=false` and `release_ready=false`.
   Consistency validation cannot authenticate a person; an owner must obtain
   and authenticate a genuine human's explicit live-review verdict.
6. Bind final source/PCK/native WASM/Rapier/worker assets, pins, provenance,
   licenses, downloadable candidate packages and release notes to one release
   ledger, then make the final GO / CONDITIONAL GO / NO-GO decision.

No agent image inspection in this review supplies a human PASS. Alternate
browser engines, optional Windows desktop, cross-browser equivalence, exact
live-state continuation and complete bitwise replay remain separately
unqualified unless actually executed and supported. Optional desktop scope is
not promoted into a mandatory Web-only gate. Publication or a v1.0 tag still
requires separate explicit release authorization.

## 6. Review addendum — 1 November 2026, 21:38 UTC

This addendum preserves the earlier checkpoint and records subsequent evidence.
It does not turn an earlier failed workflow or changed delivery directory into
a passing one.

### Completed C01 and B01 integration gates

C01's actual merge `35377bb420c94aa82bc09fc289a1bef6b825d2fc` completed
[Linux 41350170388](https://github.com/techrote/sandfall/actions/runs/41350170388)
with seven required successes and five documented optional skips, and
[Web 41350170196](https://github.com/techrote/sandfall/actions/runs/41350170196)
with fifteen required successes and two full-only skips. Its documentation
gate also passed. These were independently read at the actual merged source.

B01's exact `b29dd3a` Linux run subsequently completed with the same seven
required successes and five optional skips. Together with its already passed
configuration, documentation and routine Web gates, this supports the owner's
guarded B01 merge **`2a9d9d7952f554a12092abf607e63a18b398f930`**, preserving
reviewed tree **`4cb70efa577141149950535d9590a7550ad551d0`**. Its actual
post-merge [Linux 41352225827](https://github.com/techrote/sandfall/actions/runs/41352225827)
and [Web 41352225833](https://github.com/techrote/sandfall/actions/runs/41352225833)
remain in progress at this addendum. Head execution is not substituted for
those mainline executions.

### Original workflow failures and reviewed browser corrections

The full [M5 run 41350071260](https://github.com/techrote/sandfall/actions/runs/41350071260)
at `05fb7ee` completed **failed**. Passing individual browser assertions do not
override its failed custody checks or the M2 readiness failure.

The generic runner included its own new untracked evidence and browser-profile
files in its final whole-verifier comparison. Correction
**`079dc18a0b6c235b34308c29c52624cdd00e01ae`** retains both raw verifier
receipts, requires every tracked/staged/unstaged/build-sensitive source list
to be empty before and after execution, and compares all other verifier fields
exactly. Only untracked paths beneath the exact new owned output directory
may differ. Added or removed outside paths, runtime hashes, manifests, source
identities and all browser assertions remain strict. Seven focused negatives
and eighteen existing artifact tests passed; B01 independently reviewed this
C01-authored correction. Original failed CI artifacts remain unchanged.

The corrected runner actually executed the zero-body workshop at 800×450/DPR1
against the CI-produced `05fb7ee` threaded package: **42 browser assertions
passed**, with two requested, configured and observed participating workers.
Its retained evidence archive is 175,514 bytes, SHA-256
`aa700f905f0fb33b4af7a975c031f62f16c9c0501d1ec83d3ae03ae790ca7e7c`.
This is a bounded actual-browser qualification of the correction, not a
replacement for the full workflow.

The original M2 640×400/DPR2 failure clicked a frame-zero temporary Sandbox
rectangle and remained on Home. The owner's correction
**`35c6f2af132821d1bc6995968fa681402fff77c9`** reuses the unchanged M3
layout sampler, exact geometry comparator and two-frame readiness predicate
before each single-shot M2 input. The new readiness observation is bounded by
20 seconds within the unchanged global deadline. C01 reviewed this one-file
delta and reran all ten M2 and thirteen M3 negative tests. It changes no
application code or physical oracle and adds no state-changing input retry.

The owner's actual rerun of the failed configuration passes **79 assertions**,
with **649 native and 649 Rapier steps**. C01 independently read the raw
receipt: the first Sandbox action used `(649, 16, 88, 40)` after observing
stable geometry from frames 2 to 12, followed by one trusted action. Its clean
harness is `35c6f2a`; runtime remains `05fb7ee`. Before/after verification is
identical except the exact owned output's untracked inventory. Browser receipt
SHA-256 is `faddb148f65f8a91f26e0217a994ff6bc07071e680c325dfc1f359841d315014`;
orchestrator result is
`80da5138215e2f52e131c0fd3faec184f08a4b8c4de29a885d54ff983ea7ddf1`.

These reviewed tooling changes are published in A01 head
**`742b730b855650118acd6b6aa1eaffcf9f3e6a1a`**, tree
**`6c4df1198da4dbe7050397a237146fc890c98fe6`**, independently confirmed
through GitHub's commit object. There is no application/runtime delta from
`05fb7ee`; applicable exact-head CI must still pass.

### Delivery-directory diagnosis and captured artifact scope

The original local compatibility directory with its unlisted PCK remains
refused and unrepaired. Its retained archive SHA-256 is
`a233abeb0ad776c80a5d65181a0e658b855d4908d2636f6bf9b772a32ce16bb6`.
Metadata places the extra file's ctime after the manifest; a separate isolated
raw export reproduced neither the extra file nor the refusal. This narrows
the observations but does not identify the responsible mechanism or writer.

A subsequently reviewed capture wrapper runs the complete pinned native/Web
build and required native/Godot tests, strict artifact verification, complete
directory inventory, byte-preserving ZIP capture and a second unchanged
verification in the same process. It never excludes an unexpected sibling or
repairs the original failed directory. The owner's full fresh threaded run
passed this sequence at `05fb7ee`; extracting its archive also produced the
identical strict verifier receipt, SHA-256
`4cc5ea4b3466785dd2f9582941b9b9ccec287ce99011d3b0cf343edca12540bc`.
The archive is **17,440,996 bytes**, SHA-256
`702f9817b8595f4559610570dea6e85d8b96fa144bed23aa81c50991c64c810d`.
C01 read both receipts and the complete 23-file capture inventory.

The later raw threaded directory contains a twenty-fourth, temporary
42,991,616-byte WASM sibling absent from the captured inventory. Its metadata
also postdates the manifest. That raw directory is not qualified. The captured
archive and independently clean CI packages retain their own identities;
neither proves a repaired raw directory or an identified external cause.
No source fix, ignore rule or weaker inventory oracle was introduced. Browser
performance measurements use the independently verified CI-produced packages.

### Corrected hosting and human-packet review

C01 independently checked both actual corrected insecure-origin negatives
against CI-produced `05fb7ee` profiles. Each passes four assertions: actual
non-loopback insecure HTTP, one precise secure-origin refusal, no application
authority and no consumed runtime. The host serves only HTML and two PNG
presentation resources. The compatibility and threaded browser receipt hashes
are respectively
`aec44934cf841c7fcc7323d3c5bf32c716d1c0564db9f10d217778e18d69f289` and
`42d0fc7796202526f4d7ac8b0477b6e94d3c79b449632f3c909f3d49156185e6`.
The original insecure-HTTP positive remains failed. Both profiles require
HTTPS or a secure loopback origin; compatibility remains independent of
COOP/COEP and SharedArrayBuffer.

Independent review of the initial human-packet builder found a blocking gap:
copying only listed assets could silently omit an unexpected input file before
validating the copied directory. A retained synthetic reproduction demonstrated
the false acceptance. B01's corrected source
**`bafab0cf3396ec436100a6251662a51b4023f583`** checks the entire input
directory before and after copying, requires exactly the verified asset names
plus `SHA256SUMS`, refuses every extra file/directory/symlink, and retains both
inventories and the failed build receipt. It preserves the original input.

C01 independently reran **25 reader tests**, repeated the original probe and
reviewed the complete packet/dual-verifier change: **PASS**, with no blocking
finding remaining. The final docs-only checkpoint
**`0baca0a74bed482b927eaa22422dbac25faee88b`** retains identical executable
human-tool bytes and also passes factual/scope review. Its 4,003,041-byte
materials archive has SHA-256
`12a5ec5c4fba9834f5a10e0199973234c07786c1b6819a64e8ea72d643eda0f6`;
C01 rechecked all 254 manifest payload hashes/sizes and archive CRC. Exact
clean-source execution receipt SHA-256 is
`286d826d9e7792208291800de109fa1f5ab997656135db02bdcb4c4694466cee`.

The archive's fourteen Gallery portraits remain explicitly historical M4
reference evidence. No final-candidate packet or human verdict is inferred.
All human fields remain pending, and successful machine packet preparation
still exits 2 with `human_origin_authenticated=false` and `release_ready=false`.
Final same-source CI, repeated performance reduction, candidate packaging and
genuine human Gallery acceptance therefore remain separate release gates.

## 7. Cache correction and D01 measurement checkpoint — 21:45 UTC

### Preserve the generated-cache refusal

The exact D01 `f59ca79` [Linux run 41350726226](https://github.com/techrote/sandfall/actions/runs/41350726226)
completed **failed**. All four shards completed their assigned regressions
(184 distinct cases across the four shards) and strict source/runtime readback,
then the unchanged dirty-source check refused the same generated class-cache
delta. The only changed path was the tracked Godot class cache; the new
`SandfallPerformanceSampler` entry was absent from the committed cache.
The four complete original logs and their identical patch are retained in
`sandfall-m5-d01-f59-cache-original-review.json`, SHA-256
`977ed2024819c48c0651681dfa785c2d5c5a87e769ef84ce65ca10c5e58da1a2`.
Existing archive decompressor diagnostics remained precisely validated; there
was no additional regression failure in these logs. The job and aggregate
failures remain failures.

B01 supplied two separate corrections. C01 independently compared the complete
D01 patch against **all four** actual Godot-generated CI patches and compared
the complete A01 cache with the already-generated pinned-Godot `05fb7ee`
threaded staging cache. The published GitHub commit/tree/parent identities were
also independently read:

| Reviewed correction | Published identity and bounded disposition |
|---|---|
| D01 local `cd77ca2f93b17a8bc170067f8de837591c87bf67` | Published **`b5861efc248fad0d125a1de46a3623f469cb0c2f`**, tree **`c38457ed1f01d9ea2f4f1aa6501041d8d1bc542b`**, parent `f59ca79`. Only eight generated sampler-entry lines; complete diff equals all four original CI diffs. Resulting Git blob `7341ed1e40b54fa502003ce702f069a235cf356c`. Independent source review **PASS**. |
| A01 local `024d906d3e3a450844dbbf1a6eedc7649ab63672`, including D01 cache cherry-pick `edff126` | Published **`8236a4771dab2a472d75cb17b9c77cb76402d325`**, tree **`422e97480541d65f174ccfdc615944344d07d226`**, parents `742b730` and `b5861ef`. Adds the corresponding eight-line `SandfallWebProfile` registration as well. The complete 26,684-byte cache equals observed pinned-Godot output, SHA-256 `1189cb7aa5c16b1c44410f2cfb519894227fa355b529622927aa2c48b881a901`, Git blob `a2466997c9b13d38d6a3c3be61d7d1da0c1a28f4`. Independent source review **PASS**. |

Both declarations and `RefCounted` bases match the actual scripts. Neither
correction changes application logic, the dirty-source guard, workflows,
diagnostic matching or physical assertions. No new local engine execution was
performed during the registered performance window. Fresh clean-tree pinned
Godot execution and applicable corrected-head CI remain mandatory.

### Nine actual D01 measurements, exact original `f59ca79`

D01's first formal tranche completed **nine browser measurements**: Blank,
Material Lab and the existing sixteen-body Gallery scene, each repeated three
times at 800×450/DPR1, compatibility profile, one native worker and speed 1.
The registered duration is 30 seconds per run, with actual monotonic wall
intervals retained. The pre-existing plan and serial batch-driver identities
are respectively
`2885a1a5da70f871dea6e7c747ab2b391b656396c728feba33ed5e99e80f7ab2` and
`8441724ea8bcff9c09531786e009fccc1ce832c7a46fad9bdd728d5c50373c66`.
The criteria require complete measurements and correct ownership/capacity;
they do not introduce a throughput threshold after measurement.

These measurements use **`f59ca79bf83e9c0a381c295452ea75d6771fb1f9`**,
its own committed observer/oracles and its actual CI-produced compatibility
package. GitHub confirms producer artifact **13101409753** from
[run 41350726320](https://github.com/techrote/sandfall/actions/runs/41350726320)
at that source, archive SHA-256
`aab68a51803c08956ab3e1b251670c9b44d062debabd4e0cd078c7506b1c0104`.
The separate reviewed coordinator is `42e17f82f383120a8b9341856af9b49e94612d6c`.
The original D01 Linux/cache failure does not invalidate these named actual
measurements, and these measurements do not qualify the complete D01 source.
They are not relabelled to `b5861ef`, A01 or a final release candidate.

C01 independently recomputed all nine rates from actual native counters and
the application monotonic wall intervals, checked all three population means
and sample standard deviations, and matched browser/result/verifier digests.
All six observer input hashes match `f59ca79` Git blobs; both separate
coordinator inputs match its recorded source. Batch result hashes and every
reported native-latency window match the original terminal receipts. Zero-body
cases retain zero Rapier steps; each sixteen-body measured interval has equal
native and Rapier advancement, sixteen stable bodies and fixed `1/60` dt.
Trusted DOM input and clean harness identities are retained.

| Existing workload | Actual native ticks/s, mean ± sample SD, n=3 | Frame callbacks/s, mean | Per-run native tick p50 / p95 range; largest lifetime maximum |
|---|---:|---:|---|
| Blank | **60.00268 ± 0.00592** | 53.37504 | 0 / 0.1 ms; 1.3 ms |
| Material Lab | **59.98787 ± 0.00792** | 52.10816 | 4.6–4.9 / 6.5–6.7 ms; 46.1 ms |
| Sixteen bodies | **43.19446 ± 0.42733** | **5.42393** | 12.0–12.1 / 16.4–17.4 ms; 36.5 ms |

The sixteen-body result achieves **71.99% of the requested simulation rate**
on this host. Frame callbacks are not GPU-presented FPS. Native latency windows
cover the recorded scene lifetime including warmup and terminal observation;
they are neither pooled tick quantiles nor distributions restricted to the
30-second rate interval. A recorded zero does not prove zero execution cost.

The environment is Linux x86_64, Chrome for Testing 156.0.8078.80 in headless
SwiftShader mode, an AMD EPYC 9V74 host with nine visible logical CPUs and eight
reported available parallelism/cgroup CPU capacity. Original receipts retain
host and cgroup observations before and after each run. Unsupported Godot
allocator monitors are marked unavailable; JS heap and renderer TaskDuration
are separately limited observations, not total process memory or all-core CPU.

The exact summary SHA-256 is
`afe1fc8ed776ed929462d5a740a76e639a98a3c0202f6ce878b8bf01f2399f24`.
C01's read-only numerical/custody review receipt is
`sandfall-m5-d01-f59-performance-independent-review.json`, SHA-256
`6ca230947698839a83f30e7a8085f480880f5dcc5e6d7983dfbfd7aebbb74a8d`.
Independent review of this bounded measured scope is **PASS**. The integrated
profile/worker/viewport measurements remain in progress. No 60 FPS guarantee,
physical-device exhibition verdict, cross-browser equivalence or human
acceptance follows from this headless sample.
