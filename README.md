# Sandfall

**Status: SF-M0 remains on held [draft PR #2](https://github.com/techrote/sandfall/pull/2).
The dedicated zero-player host is implemented and compatibility-Web qualified on
stacked [draft PR #3](https://github.com/techrote/sandfall/pull/3). SF-M2 authoring/history and the material workshop are implemented on stacked [draft PR #4](https://github.com/techrote/sandfall/pull/4), with bounded compatibility-Web executable qualification passed at `533a3de6` and exact-source evidence in its dated audit. All three PRs remain draft and unmerged.**

Sandfall is a Web-native, interactive, **zero-player cellular + Rapier physics exhibition and editor** derived from CyberSand. “Zero-player” removes player/actor movement and action controls, **not** painting, object creation, time control or camera interaction.

The normative v1 project-specific contract is:

**[Sandfall v1 — Architecture, UI/UX and Implementation Specification](docs/SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md)**

It fixes the agreed design: separate **Edit / Run** modes; Gallery autoplay and paused Sandbox; MZPaint-derived precision-first material editing with a separate decorative layer; optional passive subjects; sixteen coupled Rapier boxes; fixed-step 0.25×–4× pacing; pristine/modified run provenance; and **undo/redo only in Edit at tick zero**. After a simulation tick, no physical-history undo is attempted. Reset returns to an authored initial state.

Portable **.sandfall** files are ordinary **ZIP archives containing a structured project folder** with human-readable JSON definitions and separate material/asset data, not an opaque proprietary save format.

## Pinned provenance

| Source | Immutable baseline |
|---|---|
| CyberSand upstream | [techrote/cybersand @ 1d376fb38ff5df83691e468baa0639270a5f40e6](https://github.com/techrote/cybersand/tree/1d376fb38ff5df83691e468baa0639270a5f40e6) — 2026-10-25 |
| UI/UX reference | [specdocz MZPaint @ 039008723172a951c7694079cd06c7a2ea137d40](https://github.com/techrote/specdocz/tree/039008723172a951c7694079cd06c7a2ea137d40/uiuxs/mzpaint) |
| Experience research | [specdocz Zero-Player Level Design @ same pin](https://github.com/techrote/specdocz/tree/039008723172a951c7694079cd06c7a2ea137d40/gametypes/zeroplayerlevel) |

## Engineering evidence and next step

The exact CyberSand history is imported. A source-matched compatibility Web
export and 600-tick native/Rapier fixture passed, as did the full 164-test native
suite. The ordinary browser blocker is resolved at `86f4c942...`: both
800 × 450 / DPR 1 and 640 × 400 / DPR 2 passed real Continue/Escape/P input,
advanced at least 18 / 24 normal native ticks and captured visible material
content within the actual world viewport. Exact CI receipts, durable raw
evidence, original failures and remaining qualification boundaries are in the
[dated ordinary-Web audit](docs/audits/2026-10-30-sf-m0-ordinary-web.md).

The dedicated `godot/sandfall_main.tscn` now owns Gallery/Sandbox, separate initial
Edit/Run state, camera, pause, exact Step and reset without inherited actor or
launcher authority. See the [SF-M1 milestone](docs/SF-M1-HOST-INPUT-CUT.md) and
[dated implementation/qualification audit](docs/audits/2026-10-30-sf-m1-host-input.md)
for current source, executed checks and fresh-export identity. The ordinary
800×450/DPR1 and 640×400/DPR2 runs pass 54 checks each, including real UI/focus
input, exact Step/reset, at least 600 actual coupled ticks and visible world
screenshots. The retained legacy
scene is used explicitly for historical regression contracts. Threaded Web,
human exhibition review, full editing, sixteen-body authoring and the portable
archive retain their separate gates.
**PR #2 stays draft and unmerged until the owner explicitly authorizes otherwise.**

The [fresh Web export at bbe72707](https://github.com/techrote/sandfall/actions/runs/41139800406/artifacts/13017918272)
contains the runnable application and its SHA-256 manifest. After extracting it,
serve the directory over HTTP with `python3 serve_web.py --directory . --port 8040`
and open `http://127.0.0.1:8040/`. Gallery autoplays after readiness; Sandbox
starts in Edit at tick zero. Run, Pause, Step, Reset, Reset & Edit and camera
controls are clickable; P toggles pause, Escape opens the menu, and middle drag/
wheel control the camera. No painting/history or arbitrary object-authoring UI
is claimed in this initial host cut.

## SF-M2 material authoring

The [SF-M2 implementation](docs/SF-M2-AUTHORING-HISTORY.md) adds copied initial documents, exact signed material/state/temperature transactions, one-gesture history, complete first-tick history retirement and bounded journalled Run interventions. The Control sidebar provides catalogue/search, pencil/erase, circle/square/ratio footprints, lines/rectangles, picker, cancellable category fill and exact selection copy/cut/paste/move/delete. Grid/rulers and camera remain presentation-only. Reset restores the frozen design; Reset & Edit starts a new empty undo history. Pacing preserves fixed dt.

[The dated audit](docs/audits/2026-10-31-sf-m2-authoring-history.md) separates development results from exact-SHA native/Web/browser qualification and retained failures. The SF-M1 export linked above predates these tools and cannot demonstrate SF-M2. The [fresh SF-M2 export and full qualification run](https://github.com/techrote/sandfall/actions/runs/41163426571) pass at `533a3de6352074f0cd68faca94417e80f041080e`; use its `sandfall-sf-m2-fresh-web` artifact, not the older SF-M1 package. After extraction, run `python3 serve_web.py --directory . --port 8040`. Open Sandbox, then Tools, to edit the initial scene. Undo/Redo are Edit-only; after Run, Reset & Edit restores a new editable baseline with empty history. The durable evidence manifest and original failures are linked in the dated audit.

**Next:** SF-M3's generalized stable-ID Rapier workshop, including 0-16 coupled boxes and refusal of body 17. Human visual acceptance, threaded/unisolated hosting, broad desktop qualification and the SF-M4 archive/presentation/exhibition work remain separate. All three PRs remain draft and unmerged.

This root filename is deliberately **README.md**, matching normal Git conventions and avoiding the prior **readme.md / README.md** case conflict on Windows during upstream import.
