# Sandfall

**Status: SF-M0 remains on held [draft PR #2](https://github.com/techrote/sandfall/pull/2).
The dedicated zero-player host is implemented and compatibility-Web qualified on
stacked [draft PR #3](https://github.com/techrote/sandfall/pull/3). The full editor
remains a later milestone. Neither PR is merged or ready for review.**

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

**Next engineering task:** SF-M2's authored initial document and exact Edit
transactions/history, before expanding the material tools. Owner human visual
acceptance and threaded/unisolated-hosting qualification remain separate gates.

This root filename is deliberately **README.md**, matching normal Git conventions and avoiding the prior **readme.md / README.md** case conflict on Windows during upstream import.
