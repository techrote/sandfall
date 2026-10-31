---
title: Sandfall portable project format, schema 1
status: Current
document-kind: reference
scope: Implemented authored initial-state JSON and ordinary ZIP contract
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md, SF-M3-RAPIER-WORKSHOP.md]
---

# Sandfall portable project format

A `.sandfall` file is an ordinary ZIP containing exactly one `project/`
directory. Renaming it to `.zip` permits inspection and extraction with ordinary
ZIP software. This document specifies the implemented version 1 data contract;
the [approved specification](SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md#9-portable-sandfall-projects)
owns product requirements. Runtime qualification is recorded separately in the
SF-M4 audit.

The file contains an **authored initial scene**. It contains no Edit history,
live native continuation, pending feedback, transient body masks, Rapier RIDs,
contact caches or running chemistry snapshot. Save during Run uses the frozen
authored initial definition. Run evidence is a separately labelled JSON export.

## Folder contents

| Relative path inside `project/` | Requirement and meaning |
|---|---|
| `manifest.json` | Required format/version, identity, source provenance, complete file inventory and hashes |
| `scene/scene.json` | Required initial world, fixed timestep, supported policy, camera/startup, passive subject and declared expectations |
| `scene/objects.json` | Required copied version-1 logical object graph; zero through sixteen boxes |
| `world/cells.bin` | Required exactly 5,242,880 bytes of row-major material/thermal initial state |
| `presentation/style.json` | Required separately versioned cosmetic theme and annotation visibility |
| `presentation/annotations.json` | Required separately versioned label/stroke data |
| `assets/*.png` | Optional self-contained PNG assets; nested asset directories are allowed within the path bound |
| `README.md` | Optional UTF-8 human-authored notes |

Required JSON files exist even for an empty body graph or annotation list.
The current annotation tools use labels and strokes. PNG assets may be retained
and round-tripped without being displayed; importing one never converts it to
semantic materials or executes it.

## Manifest

All listed members are required; unknown members refuse. Paths in the inventory
are relative to `project/`. The manifest has no self-hash.

```json
{
  "format": "sandfall-project",
  "schema_version": 1,
  "project": {"id": "my-project", "title": "My project"},
  "scene": "scene/scene.json",
  "versions": {"cells": 1, "objects": 1, "presentation": 1},
  "source": {"source_commit": "...", "source_tree": "...", "native_source_commit": "...", "native_runtime_sha256": "...", "rapier_version": "0.35.2", "rapier_runtime_sha256": "...", "godot_version": "4.7.stable.official.5b4e0cb0f", "build_profile": "compat"},
  "files": {
    "scene/scene.json": {"sha256": "...", "bytes": 1234},
    "scene/objects.json": {"sha256": "...", "bytes": 100},
    "world/cells.bin": {"sha256": "...", "bytes": 5242880},
    "presentation/style.json": {"sha256": "...", "bytes": 100},
    "presentation/annotations.json": {"sha256": "...", "bytes": 100}
  }
}
```

The example hash placeholders and illustrative JSON byte lengths must be replaced
with actual values; it is a schema illustration, not an importable fixture.
Project IDs have 1–64 ASCII letters, digits, hyphens or underscores. Titles have
1–128 characters without NUL. Every file other than the manifest, including
optional assets and notes, must have exactly one size/SHA-256 record. Missing,
additional or mismatched entries refuse before a host is staged.

Source revisions are lowercase 40-digit Git hashes. Runtime digests are
lowercase 64-digit SHA-256 hashes. Production `compat` and `threaded` identities
require all hashes. An honest local-development file can use profile `local`,
revision marker `local-unpublished`, and runtime marker `unattested`; it does not
acquire source-matched qualification by being importable. Runtime version fields
currently require the pinned Godot/Rapier versions above. A different source
commit is allowed: portability does not require the exporting and importing app
commits to be identical.

`manifest.source` and `scene.source` identify the writer's build. The scene's
`origin_source` retains the original project's source record on subsequent
imports/exports. It has exactly the same eight-field structure and validation.
The active session's evidence additionally records its actual current runtime.

## Scene and supported initial policies

`scene.json` has exactly these members:

| Member | Accepted value |
|---|---|
| `schema_version` | Integer 1 |
| `kind` | `kinetic_sandbox` or `zero_input` |
| `world_size` | `[1024, 1024]` |
| `fixed_hz` | Integer 60 |
| `seed` | Integer 0, the reserved baseline with no procedural scene generator |
| `solver` | `{"policy":"cybersand-default-v1","cadence_lod":false}` |
| `interest` | `{"policy":"authored-window-v1","origin":[x,y],"size":[w,h],"margin":[mx,my]}`; integer coordinates, positive size wholly inside the world, margins 0–1024 |
| `camera` | `{"origin":[x,y],"size":[480,270],"zoom":z}`; finite zoom 0.5–4 and the resulting `480/z` by `270/z` view wholly inside the world |
| `startup` | `edit_paused` or `run_autoplay`; autoplay waits for full candidate readiness |
| `events` | Empty array; no environment-script/event executor is admitted in this revision |
| `passive_subject_id` | Empty string or the ID of the single object marked `passive_subject` |
| `expectations` | At most sixteen nonempty strings, each at most 256 characters; declared observational criteria, never executable predicates |
| `source` | Current writer identity, equal to `manifest.source` |
| `origin_source` | Retained initial source identity |

Unsupported seeds, solver parameters, event records and `triggered_automatic`
refuse explicitly. The importer does not silently accept settings that the
host cannot apply. This does not remove the approved demonstration class;
a future supported one-shot trigger policy needs a versioned implementation
and its own evidence. Camera and presentation settings never alter native
simulation interest or Pristine/Modified physical status.

The current `WorldConfig` has no mutable RNG seed. Native
`World::deterministic_random()` mixes coordinates, native tick and the rule's
stream identifier with fixed constants. `seed:0` records the supported authored
baseline; it does not claim to call a nonexistent RNG-seeding API.

## Exact logical cells

`cells.bin` has no header and no inner compression. For cell `(x,y)`, its tuple
starts at byte offset `5 * (y * 1024 + x)`:

| Byte within tuple | Meaning |
|---|---|
| 0 | Native material ID, unsigned 8-bit; palette-slot indices are never IDs |
| 1 | Native `state_a`, unsigned 8-bit |
| 2 | Native `state_b`, unsigned 8-bit |
| 3–4 | Signed 16-bit temperature, little endian, in native integer units |

This is a logical five-byte tuple, not the native in-memory cell ABI. Material
IDs and state bytes are checked by the actual `SandfallEditBridge` catalogue and
tuple validator. Reserved ID 10, unknown IDs and Water state values that would
be normalized instead of exactly restored refuse. No Celsius conversion is
implied. The payload is exactly 1,048,576 tuples; truncation, padding and extra
initial-state fields are not accepted under schema 1.

## Objects, presentation and assets

`objects.json` is the existing registry's
`{"schema_version":1,"objects":[...]}` logical representation. Vector fields are
two-element numeric arrays. Stable IDs and creation order, supported box
geometry, initial pose/velocities, physical parameters and metadata obey the
[SF-M3 object contract](SF-M3-RAPIER-WORKSHOP.md#stable-logical-objects-and-supported-units).
IDs are never Rapier RIDs or transient native sample slots. Canonical order is
ascending `creation_order`, independent of JSON array order. Duplicate IDs/order,
unsupported fields, invalid dimensions/parameters and body 17 refuse.

Positions/dimensions use native cells/Godot pixels, linear velocities use cells
per second, angular values use radians/radians per second, and mass uses the
existing Godot/Rapier mass unit. No additional SI conversion is invented.

`style.json` contains `schema_version:1` and `style` with exactly `theme`
(`classic`, `muted`, `contrast`) and Boolean `annotations_visible`.
`annotations.json` contains `schema_version:1` and `annotations`. Every item has
exactly `id`, `type`, `points`, `color`, `width` and `text`. IDs are unique within
the overlay. Labels contain one point and nonempty text up to 128 characters;
strokes contain 2–256 points and empty text. Points are finite `[x,y]` coordinates
from 0 through 1024; width is 1–32; colour is `#rrggbbaa`. The whole overlay is
bounded to 128 annotations and 4096 points. These values never write native
cells or body definitions.

Each PNG is at most 16 MiB and has width and height from 1 through 4096. Signature
and IHDR dimensions are checked before decoding; actual image decoding must
then succeed with the same dimensions. SVG, scripts, resource files, other image
formats and external asset URLs are not accepted. Notes are plain UTF-8, at most
1 MiB, without NUL. They are never evaluated as code.

## ZIP and JSON admission

The in-memory ZIP reader checks all central and local records before any entry
is decompressed. No pathname is passed to filesystem extraction. The current
bounds and refusal rules are:

| Boundary | Implementation limit |
|---|---|
| Entries, including directory records | 256 |
| Expanded total | 128 MiB |
| Compressed archive | 129 MiB |
| Each JSON/notes file | 1 MiB |
| Each PNG | 16 MiB plus the dimension bound above |
| Filename | At most 160 ASCII characters and eight slash-separated components |
| Compression ratio | At most 1100:1 for exact-size `cells.bin`; 200:1 for other files |
| JSON structure | At most 32 nested levels and 65,536 values |

An almost-empty valid material world can approach DEFLATE's approximately
1032:1 maximum ratio, so its special 1100:1 ceiling is combined with the exact
5,242,880-byte length. Other highly repetitive optional data is exported using
ZIP STORE if needed to remain within the lower ratio limit. The world uses
ordinary ZIP DEFLATE with no nested compression.

Classic single-disk STORE and DEFLATE entries are supported, including bounded
ordinary data descriptors. Encryption, ZIP64, unsupported methods/flags, links,
devices, overlapping entries, unlisted bytes, conflicting local/central names,
wrong CRCs and mismatched sizes refuse. Root siblings, absolute or parent/dot
paths, backslashes, colons, empty components, case-fold duplicates, file/directory
path conflicts and Windows device names refuse. Timestamp/owner-ID extras are
accepted; alternate filename extras and unknown extra types refuse.

Empty files may use STORE, or the standard exact empty DEFLATE fixed block
(`03 00`) or stored block (`01 00 00 ff ff`) with CRC zero. Other zero-output
DEFLATE encodings refuse as unsupported. This explicit admission rule avoids
confusing the pinned engine's empty return on decompression failure with a
successful empty file; ordinary ZIP tools' usual empty fixed block remains
interoperable. The exporter writes empty files using STORE.

UTF-8 and JSON grammar are validated before schema interpretation. Duplicate
members, including differently escaped spellings of the same member, refuse.
Comments, trailing commas, nonfinite/out-of-range numeric tokens, invalid
surrogates, embedded NUL and excessive nesting refuse. No Variant/object
deserializer or Godot resource/script loader is used.

## Logical identity and reconstruction

Canonical JSON uses sorted keys, full numeric precision, UTF-8 and a final
newline. Cell endianness and registry creation order are fixed. The logical
project digest hashes the canonical manifest, which commits to every other
logical file's bytes and SHA-256 digest. Recompression or ZIP timestamps do not
change this identity. Reformatting an extracted JSON file is accepted after
updating its manifest digest; the imported project is normalized before its
canonical identity is calculated.

A separate physical digest commits to exact initial cells, stable object IDs,
creation order and physical parameters, world size, fixed step, seed, solver,
interest and events. It excludes cosmetic names, passive-role labels, camera,
title, assets and presentation. Run evidence binds that physical definition to
the actual executing runtime separately; neither digest claims whole-stack
bitwise replay.

An imported source record is project provenance data, not an authenticated
attestation. File SHA-256 digests establish byte integrity against the supplied
manifest. Actual execution evidence must bind independently measured source and
runtime artifacts, as the source-matched qualification pipeline does.

`SandfallArchiveCodec.decode_bytes()` returns a copied logical candidate or a
precise refusal. `decode_files()` applies the identical validator to an already
read file map for developer folder workflows. The session then constructs a
separate native/Rapier host and checks all terrain/body readiness before it
replaces the old session. A codec success alone does not authorize mutation and
does not prove readiness. Failed parsing, native construction, body construction,
asset decode or readiness must leave the prior session installed.

An ordinary extracted-folder edit therefore consists of modifying supported
JSON or exact tuples, recalculating the affected file lengths/SHA-256 digests,
and zipping the `project/` folder. No proprietary archive wrapper or hidden
runtime dependency is required. The independent Python ZIP fixture tool and
Godot cross-encoder tests exercise this workflow separately from same-codec
roundtrips.
