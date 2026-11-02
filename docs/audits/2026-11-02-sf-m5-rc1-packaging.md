---
title: SF-M5-RC1 immutable final-main Web packaging and custody
status: Current
document-kind: audit
scope: Exact-source original and final Web archive verification; no release approval
canonical-for: []
last-reviewed: 2026-11-02
related-documents: [../SF-M5-RELEASE-CANDIDATE.md, ../SF-M5-WEB-QUALIFICATION.md, ../SF-M5-RELEASE-LEDGER.md]
---

# Sandfall SF-M5-RC1 — dated packaging and custody review

**Reviewed:** 2026-11-02T19:51:55.392775+00:00  
**Verdict:** **RC1 ARTIFACTS QUALIFIED**. **v1.0 publication remains NO-GO.**

## Immutable source and original custody

The full frozen source is `a0363cda2f2508289fd0a75fe529dbeba1d6df52`, tree `fa0bdb721949000fe5130da0e0e002cd4e77a09b`. Git and live GitHub metadata agree on parents `d40c55d3fc15cbbacb3bd158524f791db9f319b8`, `4972dfd5bf7c7e9058a055eeb053bf68110acda9`. Reviewed source `4972dfd5bf7c7e9058a055eeb053bf68110acda9` has the identical tree. Main had not advanced at the final check. Packaging used the complete immutable SHA, and no later documentation commit is the runtime's build source.

Compatibility originates exclusively from run 41405111535, artifact 13124205206, `sandfall-sf-m4-fresh-web`. Threaded originates exclusively from run 41405111530, artifact 13123202848, `sandfall-sf-m5-threaded-web`. Both original ZIP hashes and lengths equal GitHub's authenticated artifact metadata. Neither the legacy export nor a similarly named earlier artifact was used.

| Profile | Original ZIP SHA-256 | Original bytes | Finished RC1 ZIP SHA-256 | Finished bytes |
|---|---|---:|---|---:|
| compat | ac249e4b7a1b7fa94963c2cf5dc28aa4dba7caf37aed02329838e52439ff0ca1 | 17493136 | bbf2928c34c91328f5888aa7a978235dd975e5025d18819ea3e98401d1b475a6 | 17323974 |
| threaded | 676fce179c712690dd29045f354f73ce487357b6927a1315b7fb13f55e86c4da | 17513892 | a55146dbdcf40e5092c40303afef4d341adfd8169cf31a9abdbce7c047599b88 | 17344073 |

## Original-to-final verification

Safe extraction rejected traversal, absolute/ambiguous paths, duplicate case-normalized entries, symlinks/special objects, encryption and unexpected entry types. CRC was checked by reading every member. Every original export contains 23 files, 22 SHA256SUMS rows plus the separately hashed manifest. Compatibility expands to 60,428,580 bytes; Threaded to 59,824,917 bytes.

Both original exports passed frozen strict M5 verification, which chains M4/M1 identity, inventory, pin and source checks. All delivered Godot JavaScript/WASM, side modules, native cellular WASM, Rapier WASM, PCK, workers/worklets, HTML, contract and notices are separately recorded. The same-named cross-profile comparison found 10 byte-identical files and 12 different files; native modules have distinct profile-specific names. No cross-profile hash identity was assumed.

The completed archives preserve every file byte. A fresh extraction of each finished archive passed M5, full hashes and direct byte equality against the original export. A separate reviewer independently repeated original/final ZIP inspection, CRC, private extraction, full inventory and M5 verification. The finished archives change only outer ZIP ordering/compression/timestamp/permissions. No runtime was rebuilt, patched, filtered or relabelled.

Original build-evidence artifacts 13124100605 and 13122949022 were also authenticated and retained. All identity-bearing fields in their original CI verifier receipts agree with independent receipts. Their historical 38 generated build-output paths remain distinguished from the clean verifier checkout. SCons is documented as a frozen pin without inventing a measured-version receipt.

## Qualification evidence retained

| Run | Original build/source SHA | Total jobs | Observed conclusions |
|---|---|---:|---|
| [41401276654](https://github.com/techrote/sandfall/actions/runs/41401276654) | `4972dfd5bf7c7e9058a055eeb053bf68110acda9` | 71 | 71 success |
| [41405111530](https://github.com/techrote/sandfall/actions/runs/41405111530) | `a0363cda2f2508289fd0a75fe529dbeba1d6df52` | 9 | 5 success, 4 skipped |
| [41405111535](https://github.com/techrote/sandfall/actions/runs/41405111535) | `a0363cda2f2508289fd0a75fe529dbeba1d6df52` | 17 | 15 success, 2 skipped |
| [41405111592](https://github.com/techrote/sandfall/actions/runs/41405111592) | `a0363cda2f2508289fd0a75fe529dbeba1d6df52` | 1 | 1 success |

The 71-job pre-merge result is bound to its original commit and identical reviewed tree. The merged-main workflows succeeded, but their skipped jobs remain skipped. No broad CI campaign was repeated or triggered for runtime qualification in this packaging task. Documentation-only PR automation, if any, is separate from that frozen runtime qualification.

Additional execution passed 68 independent host/source checks, 20 exact expected negative refusals, four actual loopback host/path cases, 92 byte-exact asset GETs and 100 total HTTP requests. Independent reports retain configured-versus-participating-worker, public-host and browser-performance limitations.

## Failed checks and bounded corrections

The first strict M5 attempts failed source cleanliness because two untracked temporary-looking desktop payload fragments appeared after materialization. Their bytes, hashes, sizes and failed receipts were retained, and only those untracked fragments were moved outside the verifier checkout. Tracked source and verifier requirements were unchanged.

Two shared Threaded extraction directories later acquired unlisted temporary-looking fragments. Independent inventory checks rejected both; neither became an accepted candidate by removing unwanted files. The fragments are absent from both authenticated originals and both final archives. Their exact identities and raw bytes are preserved as rejected staging evidence. Their origin is unknown; no root-cause claim is made.

The bounded corrective workflow read the exact original ZIPs again, extracted every member into fresh private temporary directories and completed checks in one uninterrupted process. Final packaging, post-packaging verification, independent review and HTTP qualification used this intact-original lineage. No artifact defect or runtime correction was required.

Local browser provisioning failed with invalid/truncated downloads before any application execution. The failure is preserved as **UNAVAILABLE**, without claiming a new browser startup or runtime-refusal pass. This was optional where practical in the packaging request; original exact-source browser CI remains separate evidence.

## Durable preservation and machine-verifiable handover

Both original archives and both final packages were stored as separate persistent owner-authorized files outside GitHub Actions retention. Each was then materialized by its exact returned file/version identity into a fresh directory and compared in full: byte length, SHA-256 and byte-for-byte equality all passed. Stable destinations, exact file IDs and returned versions are recorded in `preservation/durable-preservation-receipt.json` and the inventory.

The inventory, checksums, separate M5 receipts, hosting report, reproduction tools, original build evidence, failed checks and dated independent reviews form the custody dossier. Immutable identity means exact source, version and hashes; it does not claim cryptographic signing or WORM storage. Neither an ephemeral workspace nor an Actions expiry date is counted as durable custody.

## Remaining release blockers and integration boundary

No artifact-integrity or core preservation blocker remains. Genuine human acceptance of all seven Gallery scenes is outstanding, and no acceptance record was submitted or authenticated. The retained licensing-status file also requires owner license selection, contributor-rights confirmation and third-party bundle review before public release/distribution. Separate owner authorization is still required for v1.0 publication, a tag or public deployment.

No application, renderer, simulation, physics, runtime architecture or acceptance threshold changed. The frozen source checkout remains clean. Any accompanying documentation-only draft is separately identified and cannot change the source identity of these already-built archives. No GitHub Release, v1.0 tag or public deployment was created.

## Repository record

The [machine-readable summary](2026-11-02-sf-m5-rc1-artifacts.json) records all package/file identities without personal storage identifiers. The [distribution checksums](2026-11-02-sf-m5-rc1-checksums.sha256) cover the two final ZIPs. Detailed paths such as `evidence/`, `reviewer/` and `preservation/` above refer to the separate owner-preserved custody dossier, not uncommitted repository directories. Full original archives and binaries are preserved outside this repository.
