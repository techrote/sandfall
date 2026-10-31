---
title: SF-M2 — Authored initial document and material workshop
status: Current
document-kind: design
scope: Implemented authoring ownership, exact transactions and material tools; qualification tracked separately
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md, SF-M1-HOST-INPUT-CUT.md, audits/2026-10-31-sf-m2-authoring-history.md]
---

# SF-M2 — Authored initial document and material workshop

The [approved v1 specification](SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md) remains the normative authority. This is its bounded SF-M2 implementation map, not a replacement architecture. Implementation is on stacked **draft PR #4**. PR #2 and #3 remain draft, unmerged and unchanged. Source implementation and qualified execution must not be conflated; the [dated audit](audits/2026-10-31-sf-m2-authoring-history.md) owns results and limitations.

## Ownership and interfaces

`SandfallAuthoringDocument` owns copied initial material tuples and scene definitions. The five-byte logical tuple is material ID/u8, state_a/u8, state_b/u8, signed temperature/i16 little-endian. The native catalogue validates material IDs, including refusal of reserved ID 10 and Water states that would be normalized rather than restored exactly. Temperatures are displayed in **native integer units**; no Celsius conversion is invented. This is an in-memory logical schema, not implementation of the SF-M4 archive codec.

The document has monotonically increasing revisions, private prepared candidates and sparse before/after patches. A complete gesture commits once. Undo/redo restores every affected byte, not an inverse chemistry operation. Public snapshots and prepared patch arrays cannot alias the owner. History permits 512 transactions and 64 MiB of tuple/index payload; exceeding the limit refuses before world mutation instead of silently losing reversibility. Allocation overhead is additional, not falsely counted as part of that payload budget.

`SandfallEditBridge` is a narrow main-thread native adapter, not a second solver. Its capture operation reads stored cells without clearing transient body occupancy or feedback. Batch edits validate size, unique sorted coordinates, exact before values, native revision and tick, complete desired tuples and body occupancy before semantic writes. It performs one bounded native batch, not one Web call per painted/flooded cell. Native C++ core physics and the Rapier bridge are unchanged. A failure after actual writes or solver advancement is explicitly partial and stops the session; no cross-solver rollback is claimed.

`SandfallSessionController` exclusively admits generation/input-epoch/mode/document-revision matched commands. The queue is capped at 32 commands and one pending mutation. Retired commands already drained into a batch still refuse. Hard terrain edits complete required collider readiness before success or enter Fault. Capturing/editing under an occupied body is refused rather than discarding its collision mask.

## Edit, Run and history

Edit constructs a static native preview and runs **zero native or Rapier ticks**. Run copies/freezes the document and constructs a clean session. Undo and Redo are immediately unavailable in Run, even before its first tick. The first actual advancement of either solver retires both stacks, including a native0/Rapier1 partial failure. Pause and pacing changes cannot resurrect them.

Reset reconstructs the frozen initial material/thermal payload and body definitions. Reset & Edit produces a new zero-tick document with empty history. A paused Run mutation is a physical intervention, not Edit undo history: accepted operations make Modified sticky and enter an exact tuple journal. The accepted journal has 256 entries/32 MiB payload; capacity refusal occurs before mutation. Rejections retain diagnostic reasons; the journal does not assert arbitrary whole-stack replay or implement intervention promotion.

The authored simulation-interest window now covers the complete 1024×1024 authoring domain, independent of the initial 480×270 camera. A cell painted off camera must participate when Run starts. Pacing 0.25×/0.5×/1×/2×/4× selects a bounded number of unchanged 1/60-second requests; a paused Step always requests exactly one coupled tick.

## Material tools and controls

The Godot Control sidebar provides searchable native materials by ID/name/family with colour swatches, primary/secondary slots, native rule-availability tooltips and exact temperature. Filtering cannot silently relabel the active material. The canvas remains the material authority; swatches and gizmos do not change semantics.

Tools: interpolated Pencil, semantic Erase, Picker, Line, filled/outline Rectangle, category Flood Fill, rectangular Select, Copy, Cut, Paste, Move and Delete. Circle/square/ratio-rectangle brush footprints are 1–32 cells and match the frozen CyberSand lattice convention (including odd circles and even positive-axis bias). Selection moves capture source values before clearing and therefore handle overlaps exactly. Out-of-bounds paste/move refuses instead of silently clipping data. The clipboard is a copied logical payload, not OS/system clipboard integration.

Flood Fill snapshots values, visits at most 4096 cells and normally at most 2000 microseconds per pump, with explicit world-size bounds; the commit is one exact transaction only after completion. Cancel, Escape, focus loss, menu, reset, tool change or a stale owner discards uncommitted work. During Run fill preview the solver is held until commit/cancel, without changing fixed dt. Brush/shape previews, grid/rulers, selection outlines, cursor coordinates and camera are nonphysical. Undo/Redo and all essential commands are clickable; Ctrl+Z/Ctrl+Y are optional shortcuts. Reset remains distinct from Reset & Edit.

## Qualification and retained contracts

Run the new authoring and real Godot Input tests with a freshly compiled native extension. Model-only capacity checks and intentionally injected refusal cases are explicitly labelled. Thermochemical coverage includes real Steam-to-Water transition, transported hot Sand, exact signed-temperature restoration, full-world fill and one-step off-camera evolution.

`.github/workflows/sf-m2-web.yml` builds fresh compatibility native/Web adapters and PCK from the exact commit, then independently verifies served bytes. It executes the SF-M2 ordinary editing harness at 800×450/DPR1 and 640×400/DPR2, the retained SF-M1 ordinary harness at both profiles, and the unchanged legacy600 functional oracle. Each ordinary lane uses genuine browser events and source-bound measured canvas/Control geometry. Read-only `?test=1` exposes observations only. All input precedes a sole terminal capture; the world crop excludes UI and terminal editing gizmos.

Native-focused checks are scoped to the unchanged core, not relabelled full-suite execution. The historical 164-test SF-M0 result retains its identity. A passing native UI test or build export is not actual-browser acceptance. Exact terminal receipts, source/hash identity, original failures and screenshots are required before declaring SF-M2 executable completion.

## Remaining milestones and platform boundaries

Generalized stable-ID 0–16-body editing/inspection stays SF-M3. Portable ZIP projects, presentation overlay, exhibition curation and explicit safe intervention promotion stay SF-M4. Threaded Web, unisolated hosting, platform-wide desktop qualification and owner human visual acceptance remain separate unqualified gates. The six missing companion-workspace references and eight historical stale desktop digests remain intact; no desktop binary has been reattested.


### SF-M2 provenance delta

The unchanged SF-M0 reconciler correctly refuses the new source tree: registering `SandfallEditBridge` changes `register_types.cpp`, adding **two** stale desktop input errors (Windows and Linux) beyond the original **six missing companion references plus eight stale desktop digests**. The SF-M2 reconciler retains that original refusal and permits only those exact two additional errors, after checking the reviewed two-line registration delta against SF-M1, unchanged native core and unchanged runtime payloads/manifests. Six synthetic negative tests refuse unknown/missing/duplicate errors, source or runtime drift and incomplete LFS. This enables a **fresh rebuild only**; it neither repairs nor qualifies the retained desktop binaries. The original M0 allowlist is not widened.
