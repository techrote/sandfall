# Sandfall

**Status: design approved; engine import and implementation pending.**

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

**Next engineering step:** history-preserving import of the *exact* CyberSand source pin, source-matched Web/Rapier bootstrap, then the implementation milestones in §12 of the specification. Do not claim Sandfall source, Web binaries, or new UI/16-body qualification has already been produced.

This root filename is deliberately **README.md**, matching normal Git conventions and avoiding the prior **readme.md / README.md** case conflict on Windows during upstream import.
