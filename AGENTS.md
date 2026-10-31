# Sandfall — active repository instructions

This is a **history-preserving CyberSand fork**. **Sandfall's project-specific
requirements and release/qualification gates take precedence over the inherited
CyberSand project programme.** Read
[Sandfall v1 architecture and implementation](docs/SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md)
and the [SF-M0 browser/source evidence](docs/audits/2026-10-30-sf-m0-browser-timeout.md)
before working. The imported upstream agent guide follows as a technical
reference; its CyberSand issue numbering, owners, historical handover and release
milestones are **not Sandfall assignments**.

## Sandfall-specific requirements

- **Current integration reconciliation, 31 October 2026:** SF-M0/M1/M2 PRs
  #2/#3/#4 are merged by their separately authorized owner. Historical holds
  below are retained chronology. **SF-M3 PR #5 and SF-M4 remain draft/unmerged.**
  SF-M4 starts from verified SF-M3 `0dd5d0606c92b37d3abbf6e252eae9977c1807bd`;
  do not move dependency refs or merge either milestone.
- [SF-M4 projects/exhibitions](docs/SF-M4-PROJECTS-EXHIBITIONS.md) and the
  [portable format](docs/SANDFALL-PROJECT-FORMAT.md) own initial project storage,
  staged native/Rapier replacement, same-document presentation history,
  Gallery/evidence and confirmed declarative intervention promotion. Keep ZIP
  parsing data-only and bounded; failed candidates must preserve the active
  owner. Save during Run uses the frozen authored document. Preserve precise
  negative diagnostics and source-bound file/browser qualification. The
  [dated audit](docs/audits/2026-10-31-sf-m4-projects-exhibitions.md) distinguishes
  local development, terminal exact-head gates and remaining SF-M5 acceptance.

- Audit actual live Sandfall main/branch/PR SHAs, exact-head GitHub Actions,
  reviews, repo instructions, LFS materialization, source/runtime provenance
  and competing owners before every implementation or merge.
- **Frozen upstream source:** CyberSand commit
  **1d376fb38ff5df83691e468baa0639270a5f40e6**. Preserve original Git
  ancestry and object IDs. Never silently merge moving CyberSand main, rewrite
  historical negative evidence or fabricate absent workspace files.
- **Pinned UI and experience:** specdocz revision
  **039008723172a951c7694079cd06c7a2ea137d40** (MZPaint and Zero-Player
  Level study). The Sandfall v1 spec defines their normative/research roles.
- Sandfall v1 is **zero-player**: no player movement, jetpack or actor-action
  controls in its application host. Painting, camera, simulation time and
  Rapier object authoring remain. The dedicated entry is `godot/sandfall_main.tscn`;
  compose its neutral services in `godot/scripts/sandfall/`. Do not reintroduce
  inherited host/controller or `FeatureNavigation` authority. Legacy scenes
  remain explicit regression references.
- Preserve authoritative native cell semantics, immutable copied render
  snapshots and main-thread Rapier ownership. Use fixed-step coupling; test
  interventions/reset without claiming full-stack deterministic rewind.
- **Edit / Run** is a separate authoring boundary. Undo/redo is permitted
  only in Edit at tick zero; once physics has advanced, history cannot be
  re-enabled by pause or rate changes. Sandfall project files will be ordinary
  ZIPs containing one structured **project/** folder. **16 simultaneous
  coupled Rapier boxes** is a v1 target, not the legacy three-body proof.
- Git LFS runtime files require actual payload SHA-256 and size verification;
  committed pointers alone cannot establish a runnable platform.
- On SF-M0, consult the [source import audit](docs/audits/2026-10-30-sf-m0-source-import.md).
  Keep **native**, **actual-browser coupled physics**, **ordinary visual/browser**,
  **threaded** and **human visual** evidence separate. A skipped draft workflow
  or successful build-only export is not a browser pass.
- The [ordinary-Web audit](docs/audits/2026-10-30-sf-m0-ordinary-web.md)
  records the logical-Control/CSS coordinate correction. Real browser tests
  must use source-bound viewport geometry, measured canvas/backing dimensions,
  genuine application input, and pixels inside the actual world viewport.
  Never use raw `Control.get_global_rect()` values directly as CDP coordinates
  or count menu/UI pixels as simulation rendering. A reused artifact keeps its
  original build SHA; changed Godot/native/build inputs require a fresh export.
  Complete genuine input before terminal CDP capture: a timed-out screenshot
  promise does not cancel an underlying capture or temporary DPR emulation.
  Never send later input or start overlapping captures after capture begins;
  verify trusted DOM pointer coordinates against the intended CSS targets.
- [SF-M1 preparation](docs/SF-M1-HOST-INPUT-CUT.md) is a bounded host/input-cut
  contract; its [dated audit](docs/audits/2026-10-30-sf-m1-host-input.md) owns
  current implementation and qualification. The SF-M1 branch starts only after
  fresh terminal SF-M0 gates and must not advance held PR #2. Keep full editing,
  sixteen-body authoring and archive work in later milestones. New host exports
  use `tools/build_web.py --entry sandfall --native-tests`; default legacy
  exports are not evidence for the new entry. Session/input epochs retire queued
  commands and pressed UI gestures on blur/modal/reset/fault. Camera operations
  must not move native simulation interest.
- [SF-M2 authoring/history](docs/SF-M2-AUTHORING-HISTORY.md) owns the current editor implementation map. Keep copied authored documents distinct from live native/Rapier state; capture must not clear transient body masks/feedback. Edit is zero-tick only. Run locks history immediately, and either solver's first advancement retires both stacks even on partial failure. All tools use exact validated generation/input/revision-matched batches; Run edits are bounded journalled interventions, never Edit undo. Capacity refusal precedes mutation; partial physical effects enter Fault with truthful counters. The [SF-M2 audit](docs/audits/2026-10-31-sf-m2-authoring-history.md) owns execution evidence, not a green build badge. PR #3 and #4 remain draft and unmerged alongside the existing PR #2 hold.
- SF-M2 registration adds two separately documented stale desktop input errors for `register_types.cpp`. Use `tools/sandfall/sf_m2_reconcile.py` only for the exact reviewed source delta and a fresh rebuild; preserve the original SF-M0 refusal and do not widen its historical allowlist or qualify desktop binaries.
- [SF-M3 workshop](docs/SF-M3-RAPIER-WORKSHOP.md) extends the existing document/session/editor owners with stable logical object IDs and 0–16 Rapier boxes. Preserve versioned copied definitions, explicit dense-slot mapping/retirement, zero-body no-Rapier stepping, prevalidated graph/history/journal capacity, truthful partial Fault and shared exact Edit history. The [dated audit](docs/audits/2026-10-31-sf-m3-rapier-workshop.md) separates development, exact-source native/Godot, actual-browser physical/input/pixel and remaining platform evidence. **SF-M3 must remain draft and unmerged.** The owner separately authorized the SF-M0→M1→M2 merge-down; historical holds below do not authorize this task to modify those dependency PRs.
- The imported checker has six missing *companion-workspace* references
  and eight stale **desktop** source/runtime digests. The narrow
  Sandfall SF-M0 reconciliation allowlist permits a fresh Web build only
  when these are the exact sole errors; it does not declare inherited
  desktop binaries qualified. Retain original errors and negative tests.
- **Owner hold:** [SF-M0 PR #2](https://github.com/techrote/sandfall/pull/2)
  remains **DRAFT and UNMERGED** until explicitly authorized. Do not
  auto-merge, mark ready, or imply full v1 completion.

## Historical upstream instructions retained below

The following CyberSand guide is retained for native technical invariants,
existing CI controls, and scientific provenance. Where it describes active
CyberSand-specific issues, desktop publication, workspace files or owners,
treat it as historical source context, not a Sandfall work assignment.

---

# CyberSand repository guide for coding agents

Before changes, read the [handover](docs/operations/cybersand-codex-development-handover.md),
[README](README.md), [documentation index](docs/README.md), [roadmap](docs/reference/status-and-roadmap.md),
and relevant subsystem/ADRs. Inspect actual Git root, HEAD, branch, status, tags,
remotes, dependency pins and required LFS state. The companion workspace repository
is separate from this source repository; [identity](docs/operations/source-checkpoint-and-recovery.md)
explains the established checkpoints. Preserve unrelated work.

## Development-order safety

GitHub issue numbers are identifiers, **not a serial execution order**. Before
selecting work in or adjacent to #24/#27-#30, read the canonical
[MicroScenarios and intermaterial-interactions programme](docs/operations/microscenarios-programme.md)
as well as the roadmap. It owns that programme's dependency graph; the
[architecture programme](docs/operations/architecture-programme.md) separately
owns the scientific gates/semantics of #14/#18/#20. Do not reconstruct order from
issue numbers, creation dates or stale issue comments. If an issue mirror conflicts
with either canonical programme, reconcile the planning documents and issue text
before changing implementation.

Source defines Current behavior; Approved requirements may be partly implemented.
Use Current, Approved, Planned, Deferred and Rejected claim by claim. Frontmatter
`Approved design` is the checker-compatible alias; `Ambiguous` means unresolved.
Runtime results need dated source/artifact/platform evidence. Investigate and
record contradictions before changing implementation; do not silently choose a
design from conflicting source, ADR or historical claims.

## CI and merge safety

Routine active CI is GitHub-hosted. Do not add `.circleci/config.yml`, external
runner labels, self-hosted/custom runner routing or `*_RUNNER` indirection unless
an explicit owner-approved provider-migration task first changes the canonical
policy and its checker. Run `python3 tools/ci/check_ci_provider_policy.py` when CI
configuration changes.

Draft PRs intentionally suppress expensive Native/GDExtension/Water execution;
use draft state during iterative debugging. Before an implementation PR merges,
move it to ready-for-review and record the exact-head Documentation/provenance
result plus every applicable Native, GDExtension/Godot and scoped apparatus gate.
A stale source-sensitive runtime/provenance check is a blocker, not a bookkeeping
failure. See [repository development and release](docs/operations/github-development-and-release.md).
Completion/ownership/validation-premise semantics remain separately owned by the
[development-claims remediation programme](docs/operations/development-claims-remediation-programme.md).

## Water successor safety

Issue #26 remains closed as a valid negative experiment for its two exact tested
local candidates, but its retained apparatus v1 is historical/qualified evidence.
Before any #45 Water head-transmission implementation or acceptance work, read the
[post-merge #26 review](docs/audits/2026-09-19-issue-26-post-merge-review.md),
the [#49 v2 correction registration](docs/audits/2026-09-20-issue-49-water-apparatus-v2-registration.md)
and the [source-matched #49 v2 Current-Water baseline](docs/audits/2026-09-20-issue-49-water-apparatus-v2-baseline.md).
The corrected #49 apparatus is the successor control; #95 remains the decision
join before #45 may proceed, narrow, recharter, defer or no-go.

The 2026-09-20 [Water hybrid/pressure extension](docs/operations/water-hybrid-pressure-extension-programme.md)
adds a parallel evidence lane. Current generic Rapier↔Water behavior is first
captured in #91; #92 may test at most roughly 3-5 segmented upper-volume Water
sheet tiers only by reusing a suitable generic #12 hybrid substrate. #93 is an
independent research-only lumped gas-region feasibility lane; #94 is conditional.

**Do not treat #45 as an inevitable pressure implementation.** Architecture/read-only
analysis may continue, but selecting or accepting a #45 implementation must consume
the corrected #49 apparatus and the #95 WEX synthesis (or its explicit
blocked/no-go disposition). Equal liquid levels are a vented/shared-pressure
control, not a universal sealed-room target.

The [2026-10-23 WEX-005 synthesis](docs/audits/2026-10-23-wex005-water-evidence-synthesis.md)
routes **#45 to NARROW**: admission/design only, under shared/vented-atmosphere
assumptions, with deep-release surge registered as its own fixture family. The
opt-in Liquid Comparison Build pressure family (#200) is a separate experimental
lane bounded by the [LCB-000 Gate A record](docs/audits/2026-10-23-lcb000-gate-a-water-pressure-admission.md).
It is not #45 selection. All five #213 gates passed; on 2026-10-24 the owner
authorized the bounded LCB implementation (pressure reference #200, inertial #212)
without default changes, generic #12 Stage 4, or a production carrier migration.
The implemented family is described in [pressure_flow_v1](docs/architecture/pressure-flow-v1.md).

Do not freeze #45 numeric thresholds from apparatus-v1 settling/U-tube metrics,
rewrite old #26 artifacts, duplicate #49/#12 ownership, silently unify Water
FreeMass with other-liquid CellularYield, or start #18 compact history merely to
preserve the old dependency ladder.

## Architectural constraints

- Native C++ owns authoritative cells; Godot owns presentation/input/UI/adapters.
- Native pool workers call no Godot APIs. The desktop GDScript owner may call its
  exclusive adapter/value APIs; live scene-tree and Rapier objects stay main-thread owned.
- Rapier is replaceable behind engine-owned interfaces. Do not erase/restore bodies
  into cell authority or introduce per-cell physics objects.
- Snapshot payloads remain immutable and owned until consumption ends. Expose no
  mutable World storage to rendering or gameplay consumers.
- Preserve exact fixture comparison and explicit bounded approximation. Strict
  runtime controls and complete serialized replay are Planned; level saves do not supply them.
- Desktop rendering/simulation are independently paced; Web currently waits for
  native ticks. Asynchronous Web ownership is Deferred.
- Preserve bounded work and explicit capacity outcomes. Avoid hidden tick-time
  allocation, per-cell locks, per-material threads and full-world sparse work.
  These are requirements, not proof that every prototype path already meets them;
  preserve the failed-world quarantine and region pause/re-entry contracts; inspect
  the roadmap for remaining allocation and physics gaps.

Keep changes focused and add meaningful regressions for changed behavior. During
iteration run the relevant tests; before release complete the feasible intended
platform matrix. Do not commit generated imports beyond the three portable Godot
bootstrap files, native build output, toolchains, environments, caches, archives,
logs, crash dumps, credentials or machine-local configuration. Required runtime
libraries use Git LFS; preserve dependency versions, hashes, licenses and provenance.

## Documentation obligations

Complete the canonical [documentation-update checklist](docs/operations/documentation-maintenance.md#documentation-update-checklist)
at every implementation checkpoint. In particular:

1. Record actual source/local-delta and tested runtime identities plus the recoverable checkpoint.
2. Map changes to canonical subsystem, ownership/lifetime, interfaces, invariants,
   configuration/capacity, ADR, roadmap, build/tests and user controls.
3. Update source-backed claims, status/platform qualifiers, corpus/index routes and
   affected retrieval questions together. Search old values, aliases and reverse links.
4. Preserve historical records and failures; add dated evidence with command,
   timeout, tools, fixture/profile/workers, hashes and explicit gaps.
5. Run `python tools/ci/check_docs.py`, `python tools/ci/check_m11_consistency.py`,
   `python tools/ci/check_repository.py`, the retrieval evaluation and appropriate
   focused tests. M11 checks retained records against the audited historical Git
   revision; `--compare-working-tree` explicitly reports current-versus-M11 drift.
   Never rewrite historical hashes. Follow the [separate validation gates](docs/operations/current-and-historical-validation.md)
   and review `git diff --check` and unintended source changes.

Keep the focused RAG hierarchy. Canonical ownership and the explicit retrieval
manifest prevent duplicate answers; do not replace the hierarchy with one large document.
