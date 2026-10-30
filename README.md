# Sandfall

**Status: SF-M0 source import and compatibility Web bootstrap are on
[draft PR #2](https://github.com/techrote/sandfall/pull/2). The Sandfall application
host and editor remain subsequent implementation milestones.**

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
suite. The ordinary browser coordinate defect is corrected in the test harness;
the first real-Chrome retest resumed through Continue, advanced 28 ticks,
responded to Escape/P and rendered visible material content. Exact CI receipts,
original failures and remaining qualification boundaries are in the
[dated ordinary-Web audit](docs/audits/2026-10-30-sf-m0-ordinary-web.md).

**Next engineering step:** complete the recorded ordinary-Web executable gates,
then follow [SF-M1 — Sandfall application host and input cut](docs/SF-M1-HOST-INPUT-CUT.md).
The inherited player-capable Web scene is bootstrap evidence, not the final
zero-player Sandfall host. Threaded Web, human exhibition review, the full
editor, sixteen-body authoring and portable archive remain separate milestones.
**PR #2 stays draft and unmerged until the owner explicitly authorizes otherwise.**

This root filename is deliberately **README.md**, matching normal Git conventions and avoiding the prior **readme.md / README.md** case conflict on Windows during upstream import.
