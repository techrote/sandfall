---
title: SF-M5 D02 and R01 — Pending human packet machinery
status: Current
document-kind: audit
scope: Exact source reader execution, unchanged historical visual references and unresolved current-candidate human acceptance
canonical-for: []
last-reviewed: 2026-11-01
related-documents: [../SF-M5-HUMAN-ACCEPTANCE.md, ../SF-M5-RELEASE-LEDGER.md, ../SF-M5-RELEASE-CANDIDATE.md, 2026-11-01-sf-m5-independent-review.md]
---

# SF-M5 D02/R01 — Human packet preparation

**Human Gallery acceptance remains outstanding.** This increment prepares
consistent machine inputs for an eventual live human review and records its
refusals. It supplies neither a human verdict nor final candidate acceptance.
The [protocol](../SF-M5-HUMAN-ACCEPTANCE.md) defines the seven scenes, live
interactions, explicit criteria and original human statement required later.

## Source and bounded change

Executable checkpoint `d16fa5a28e2ab8a02a5da5b2fc29498e25cc2738` is based on
published application source `05fb7ee86a592ff4557cdf165e02a478824e4c54`. It adds
only human-review tooling, a strict machine-packet reader and documentation.
It carries the previously independently reviewed D02 protocol/validator and
source-scoped release ledger, plus the unchanged independent review audit.
There is no application, native, physics, Gallery-content or workflow change.

The packet builder copies original verifier, browser, screenshot, downloaded
Run-evidence and complete candidate bytes into a new directory. It refuses an
existing output directory. Its successful machine disposition exits **2** and
leaves every reviewer, criterion, note, verdict and attestation field pending
or null. `human_origin_authenticated` and `release_ready` stay false.

Direct M5-bound browser receipts are supported. Existing **current-candidate**
M4 receipts can also be reused with their original verifier files and original
digest bindings, provided a separate passing M5 verifier identifies the exact
same source, full project identity, profile, pins, logical viewport, manifest
and complete artifact inventory. Neither receipt is rewritten. The retained
M5 startup contract must match its actual file and every runtime asset. This
reuse does not make historical M4 candidate bytes current, waive the M5 contract
gate or supply a human observation.

## Executed exact-source reader checks

The clean checkpoint ran the following commands. The enclosing execution
receipt records exact arguments, source/tree, input hashes, exit codes,
durations and complete log hashes.

| Command / input | Observed disposition |
|---|---|
| `python3 -m unittest tools.sandfall.test_sf_m5_human_review -v` | **23 tests passed.** Fixtures are explicitly synthetic; they are not browser captures or human reviews. |
| `sf_m5_human_review.py validate` with the committed empty record | Exit **2**, `pending-human-review`; no human verdict. |
| `sf_m5_human_review.py packet` with the same empty record | Exit **1**, precise missing candidate/conditions/scene-files refusal. |
| `sf_m5_human_packet.py` supplied the original accepted M4 verifier, without an M5 verifier | Exit **1**, `A passing exact-source M5 artifact verification is required`. This is an actual old-receipt reader refusal, not a current-candidate browser execution. |
| `python3 tools/ci/check_docs.py` | Exit **1**, exactly the six inherited missing companion-workspace references; no new documentation error. |
| `python3 tools/ci/check_m11_consistency.py` | Passed historical integrity: 18 records and 28 source hashes; no new runtime claim. |
| `python3 tools/sandfall/sf_m5_reconcile.py` | Exit **0**, only the exact reviewed additive worker-observation delta admitted for a fresh build. Original M0/M2/M3 refusals and stale desktop limitations remain retained. |

The reader tests include missing or changed candidate files, incorrect M5
startup identity, different source/tree/profile/viewport, bad original-verifier
binding, source drift, failed browser execution, differing browser conditions,
changed image bytes, unsafe paths, absent original statement and any attempted
machine prefill of human findings. The independent M4/M5 route has positive
synthetic custody checks and negative mismatches; a final current-candidate
positive packet still requires the actual final delivered artifacts.

## Original visual reference custody

Fourteen original Gallery artifacts—seven scenes at each established
viewport—were copied from accepted M4 run
[41333628953](https://github.com/techrote/sandfall/actions/runs/41333628953),
source `0cc6b54d7361fd4781978ae84b803c6213a8648b`. Each original ZIP was checked
against the GitHub artifact digest. Browser, PNG, downloaded Run evidence and
original M4 verifier identities were independently matched. The static index
uses those original images; it generates no replacement screenshot.

These references use Chrome `156.0.8078.47` on Linux and retain their actual
800×450/DPR1 or 640×400/DPR2 conditions. The index and bundle explicitly state
`historical-reference-only`, no current-candidate packet qualification and no
human verdict. The accompanying current-review template has empty candidate,
environment and human fields.

| Retained artifact | SHA-256 / size |
|---|---|
| Exact-source `execution.json` | `f394a9ee679e2ad9f39441ab4c12718f9b4c92893e4f467b51e259ced335f0fe` |
| Historical reference index | `3756068f8ebb32e3a7d6e8ea2662615053f36968fca05b570089786fbe6f3ec5` |
| Original M4 verifier used by the refusal | `655a1a1dcf45ab5fc9a0ab3623e59cd692eb65706d1f6c6c925f82a3e3529ae3` |
| `sandfall-m5-human-reference-and-machinery-d16fa5a.zip` | **3,974,122 bytes**, `319bd790217ef03abf5559363936ed798736820a94752d2bd1f03eb4df1e5821` |

The archive contains 198 entries: unchanged historical artifacts, original
reader receipts/logs, the pending template and exact checkpoint machinery.
Its complete internal manifest records every file digest and size. Archive
CRC and all manifest identities were rechecked after creation. It is retained
evidence, not a promised published release download.

## Independent inventory finding and corrected checkpoint

Independent C01 review found a blocking builder gap in the original `d16fa5a`
code: copying only verifier-listed files could silently omit an extra file
already present in the input export. The copied output then passed the strict
directory check, hiding the source directory's incomplete inventory. A
separate synthetic reproduction retained the original input, falsely accepted
pending output and finding; it is not relabelled as a valid candidate.

Correction **`bafab0cf3396ec436100a6251662a51b4023f583`** requires the entire
input directory to match the exact verified asset names plus `SHA256SUMS`, all
regular nonsymlink files, both before and after copying. It records both
observed inventories and preserves a failed build receipt on refusal. The
original unlisted-file input now refuses before copying, remains unchanged,
and produces no pending review record. New tests also refuse an extra directory,
a symlink and a file inserted during copying. **All 25 reader tests pass.**
C01 independently reran them and its original probe, reviewed the complete
packet/dual-verifier change and supplied an exact-source technical **PASS**.
This closes the reader defect; it does not supply a final candidate packet or
a human Gallery verdict.

| Corrected / original evidence | SHA-256 / size |
|---|---|
| Retained original inventory finding | `e4406a0be96cc799e31cc71522a01888c2979863f31f6346e0b8d16f45e09bf0` |
| Corrected exact-source `execution.json` | `286d826d9e7792208291800de109fa1f5ab997656135db02bdcb4c4694466cee` |
| `sandfall-m5-human-review-materials-bafab0c.zip` | **4,003,041 bytes**, `12a5ec5c4fba9834f5a10e0199973234c07786c1b6819a64e8ea72d643eda0f6` |

The corrected 255-entry archive contains the exact reviewed machinery,
historical portraits, original and corrected execution receipts and original
inventory failure. Its CRC and every internal manifest digest were rechecked.
Use the corrected source for new packet preparation; the earlier archive
retains its original checkpoint and known defect as historical evidence.

## Remaining gate

The reviewed packet code still needs applicable exact-head CI before guarded
integration. The integrating owner must then assemble a packet
from the actual qualified final candidate, preserve both original verifier
identities where M4 receipts are reused, and obtain an authentic person's
explicit live-review findings. Conditions different from the recorded machine
environment require matching evidence and a separately scoped record. The
owner must verify the origin of the eventual human statement; the reader only
checks consistency. Final release disposition remains **NO-GO** while the
candidate execution, performance or genuine human gates are incomplete.
