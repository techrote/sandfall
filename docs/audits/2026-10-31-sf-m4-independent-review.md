---
title: SF-M4 independent source and qualification review
status: Current
document-kind: audit
scope: Cross-author review of portable archives, ownership, presentation, promotion and qualification boundaries
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [../SF-M4-PROJECTS-EXHIBITIONS.md, ../SANDFALL-PROJECT-FORMAT.md, 2026-10-31-sf-m4-projects-exhibitions.md]
---

# SF-M4 independent engineering review — 31 October 2026

This review covers source on the dedicated SF-M4 branch based on
`0dd5d0606c92b37d3abbf6e252eae9977c1807bd`. The archive, exhibition/UI,
qualification and integration engineers reviewed code owned by other engineers.
Each retained review distinguishes its author's implementation from independent
inspection. Local source/log digest indices accompany the development evidence.
The final exact-head COMMENT review must bind this record to the published
commit and terminal native/Web/browser artifacts; this checkpoint does not
claim unexecuted final-head results.

**SF-M3 and SF-M4 stay draft and unmerged.** No technical result changes the
integration boundary or authorizes moving dependency refs.

## Independent coverage

| Reviewer | Independently inspected boundaries |
|---|---|
| Archive engineer | Session, document, isolated host installation, promotion, file UI and browser qualification |
| Exhibition/UI engineer | Session, document, host ownership, initial-state promotion and evidence semantics |
| Qualification engineer | Archive parsing, file chooser/download ownership, isolated reconstruction, promotion summaries and provenance |
| Integration engineer | ZIP/JSON/codec admission, presentation bounds and rendering, file UI, Gallery recipes, browser assertions and exact-source build gates |

The ZIP parser checks a bounded central directory and every local range before
decompression. Canonical paths, file inventory, supported methods/flags,
link attributes, duplicate paths, declared/actual sizes, CRC and SHA-256 are
independent admission checks. JSON parsing is bounded and rejects duplicate
keys and values outside the supported numeric domain. Native tuple validation
and stable-ID object validation precede any live owner change. Imported source
fields are provenance claims, not signatures or trusted code.

Candidate construction owns a separate native World and private manual Rapier
space. Copied document allocation, initial projection equality, body creation
and collider readiness precede old-owner retirement. Successful adoption moves
the complete viewport/owner graph while its physical subtree stays attached.
The emptied candidate retains no solver handles and serves as one inert
container, retired after the owned viewport at the next shutdown. Rejected setup retires temporary
RIDs/shapes and leaves the active scene operational. Genuine post-mutation
failure uses the existing Fault path and reports its actual partial outcome.

Presentation is a bounded non-physical model. Edit transactions share the
material/object chronology and capacity accounting. Run decoration is an
observation and cannot change the frozen Save source. The first advancement
fence still retires history across all domains, including coupled failure.

Promotion reads frozen initial tuples and explicit accepted commands. Complete
material footprints are retained and charged before mutation; evolved chemistry
and physical caches are never copied. Runtime-dependent selections are visibly
excluded. Stable IDs and only explicitly changed object fields replay in order.
The preview lease binds generation, input epoch, journal sequence and tick;
confirmation installs a fresh paused Edit baseline through the staged path.

## Material findings and corrections

| Finding | Corrected behavior and inspected evidence |
|---|---|
| Oversized JSON exponent could overflow before validation and be read as an unrelated finite number | Significant exponent digits are bounded before integer conversion. Original false acceptance and engine diagnostic retained; positive leading-zero exponent and overflow negatives added. |
| Empty inflater output could accept a corrupt empty DEFLATE member | Empty STORE or exact standard empty fixed/stored DEFLATE blocks with CRC zero are admitted before inflation; corrupt/trailing/unsupported empty streams refuse. Common Python ZIP output remains interoperable. |
| Diagnostic validator could accept a terminal record without explicit success | Exact named fixture/hash boundaries, unchanged data and `ok: true` are all required. Extra/unmatched/script errors fail; original malformed-DEFLATE output remains visible. |
| Passive-subject promotion could produce two subjects | Explicit role transfer is replayed for both spawn and update; frozen original is unchanged, one role remains and the confirmed draft is exportable. |
| Object intervention provenance could be an empty backing dictionary | Entries use normalized `source_identity()` and copied-data ownership is tested. |
| Candidate tests did not cover partial body allocation | Three attempts fail after two real bodies/shapes exist. Candidate RIDs/shapes retire, old physical/document state remains exact and the old scene continues stepping. |
| New zero-body World2D could remain automatically active without a bridge | Private spaces are explicitly deactivated before setup. Direct PhysicsServer2D activity readback is false for all capacities. |
| Promotion preview counted intermediate writes instead of final differences | Final five-byte tuples are compared to the frozen baseline; cancellation reports zero changed cells and empty bounds while retaining declared commands. |
| Authored zero damping inherited hidden Godot damping | Sandfall uses REPLACE. A real pinned-runtime probe confirms Physics Pit's prior effective totals; its recipe explicitly preserves them and the unchanged 600-tick fixture passes. |
| Staged file confirmation could outlive its scene generation | Confirmation rechecks staged generation. Same-generation explicit confirmation after legitimate focus/input retirement remains possible; both cases have Control regressions. |
| UI always promised preservation after project refusal | Only pre-mutation failures say the old scene survives. Actual partial mutation reports Fault and the real outcome. |
| File bridge size cap diverged from codec | Bridge derives its archive limit from the codec; no separate inconsistent admission limit remains. |
| Evidence omitted current logical properties and refusal context | Initial definitions, current objects, observed presentation, bounded command context and dropped-event counts are separate fields. Malformed omitted parameters and replay limits are explicit. |
| Browser tool names and feedback checks were incomplete | Harness uses the application's real pencil command; all admitted stable IDs must equal feedback keys before per-body assertions. |
| Detailed promotion preview could include Run-only metadata not replayed into the candidate | Serialize the actual post-replay row. A real five-tick session with a cosmetic name/subject change followed by mass editing reproduces the original discrepancy and verifies the corrected preview, candidate and confirmed draft agree. |
| File-change verification could match an earlier equal-sized upload | Bind one trusted current event to fresh start/end indices and exact filename/size; retained event receipt and stale/wrong/untrusted/duplicate/absent negatives enforce the boundary. |
| Reparenting a staged viewport reset actual initial body velocities despite correct logical definitions | Keep the complete physical subtree continuously attached in one inert candidate holder. Direct backend parameter/pose/velocity/RID/shape/space probes, first-step analytic motion, fixed/frozen bodies and repeated holder retirement now pass. The cache-only repair attempt failed and is retained. |
| Browser observer rounded values differently from full-precision project/evidence exports | The shared read-only observer now uses full-precision JSON. Original project/Gallery exact-equality failures are retained; no numeric tolerance was widened. |
| Zero-body browser paint assertion omitted its expected command kind | The assertion explicitly requires `pencil_stroke` and its exact one-cell result. The original failure after genuine import, frozen Save and live interventions remains retained. |

## Executed development evidence

The freshly compiled Linux GDExtension has SHA-256
`3ee1edd373c40a6299aecb66598fda9055d0bb1788355d97d033f716650722cc`.
Pinned inputs are Godot `4.7.stable.official.5b4e0cb0f`, Rapier `0.35.2`,
godot-cpp `101ae38034304346a46ea9ea84ae156d3e860496` and SCons 4.10.1.

| Latest local suite | Result |
|---|---|
| Archive | 184 checks, 93 negative cases; four exact expected malformed-DEFLATE diagnostics |
| Independent Python ZIP interchange | 83 checks; five capacity fixtures and fourteen hostile archives; exact initial tuple SHA for every positive |
| Isolated project reconstruction | 531 checks; 0/1/3/8/16 bodies, actual nonzero initial velocity and first-step motion, imported autoplay with Run history locked at zero, capacity/malformed refusal, temporary allocation and repeated container retirement, inactive manual spaces |
| History and declarative promotion | 116 checks; copied ownership, first-tick fence, capacity, subject transfer, cancellation, exact candidate preview and fresh-draft confirmation |
| Presentation / project Control input | 18 / 39 checks |
| Repeated Gallery | 189 checks, 15 runs, 9,000 actual native/Rapier coupled ticks, including no-Water causal control |
| Unchanged Sandfall Physics Pit | 600/600 ticks, 106,717 contacts, 149 displaced cells and physical save/restore passed |

Original negatives remain in the evidence bundle, including oversized exponent,
empty DEFLATE, CRC diagnostics, an invalid review fixture caught by the engine
error gate, the original damped-loop outcome and the subsequent unchanged
Physics Pit failure before explicit recipe migration, and the first published
head's detailed promotion-preview and actual adoption-velocity discrepancies,
including the failed cache-only velocity repair. A terminal JSON marker
alone is never sufficient when the same log contains an unexpected engine error.

## Required exact-head closure

The branch-scoped workflow must freshly build and test the exact published
source, retain native and Web binary custody, and execute both compatibility
profiles. The independent final review must inspect actual uploaded/downloaded
ZIP bytes, browser source/geometry/trusted-input receipts, world pixels, all
admitted bodies, material feedback and body contacts, repeated Gallery outcomes,
frozen Save, refusal invariance and promotion. Retained SF-M1/M2/M3 and legacy
physical oracles remain unchanged requirements. Each Gallery scene/profile also
has an isolated terminal-capture job so every scene's original world PNG can be
reviewed without violating the no-input-after-capture rule. Full navigation runs
are retained separately; the expanded lane has 36 jobs.

Run evidence records actual local outcomes and source/runtime identities; it
does not establish cross-platform bitwise replay, arbitrary continuation or
human exhibition acceptance. Threaded Web, alternate hosting and broad desktop
release qualification remain separate. The final PR ledger must retain failed
attempts and identify unresolved limits explicitly.
