#!/usr/bin/env python3
"""Independent ordinary-ZIP inspection and negative browser project fixtures.

Uses Python's standard ZIP reader, not Godot's importer. Mutated projects are
test inputs only: they are uploaded through the application's real file picker.
No fixture can write application state or manufacture acceptance receipts.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import io
import json
from pathlib import Path
import stat
import struct
import zipfile

WORLD_BYTES = 1024 * 1024 * 5
REQUIRED = {
    "manifest.json", "scene/scene.json", "scene/objects.json", "world/cells.bin",
    "presentation/style.json", "presentation/annotations.json",
}


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def decode_json(data: bytes):
    def reject_constant(value):
        raise ValueError(f"Nonfinite JSON value {value}")
    def reject_duplicate(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"Duplicate JSON key {key}")
            result[key] = value
        return result
    return json.loads(data.decode("utf-8"), parse_constant=reject_constant, object_pairs_hook=reject_duplicate)


def json_bytes(value) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False, allow_nan=False) + "\n").encode("utf-8")


def read_files(path: Path) -> dict[str, bytes]:
    if path.stat().st_size > 128 * 1024 * 1024:
        raise ValueError("Archive exceeds independent fixture inspection bound")
    with zipfile.ZipFile(path) as archive:
        entries = archive.infolist()
        assert 0 < len(entries) <= 256, "Invalid ZIP entry count"
        assert sum(value.file_size for value in entries) <= 128 * 1024 * 1024, "Expanded ZIP bound exceeded"
        assert len({value.filename.casefold() for value in entries}) == len(entries), "Duplicate case-folded ZIP paths"
        for value in entries:
            assert value.filename.startswith("project/"), "Archive contains a sibling payload"
            assert not any(part in {".", "..", ""} for part in value.filename.rstrip("/").split("/")), "Unsafe ZIP path"
            assert "\\" not in value.filename and ":" not in value.filename, "Platform-dependent ZIP path"
            assert not stat.S_ISLNK(value.external_attr >> 16), "ZIP symlink"
            assert value.compress_type in {zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED}, "Not ordinary STORE/DEFLATE ZIP"
        # Python independently verifies local names, inflated sizes and CRC32.
        assert archive.testzip() is None, "ZIP CRC failure"
        return {value.filename.removeprefix("project/"): archive.read(value)
                for value in entries if not value.is_dir()}


def inspect(path: Path) -> dict:
    files = read_files(path)
    assert REQUIRED <= files.keys(), "Missing required project files"
    manifest = decode_json(files["manifest.json"])
    assert manifest["format"] == "sandfall-project" and manifest["schema_version"] == 1
    assert manifest["scene"] == "scene/scene.json"
    assert set(manifest["files"]) == set(files) - {"manifest.json"}, "Incomplete file digest inventory"
    for name, value in manifest["files"].items():
        assert value == {"sha256": digest(files[name]), "bytes": len(files[name])}, f"Bad manifest identity: {name}"
    assert len(files["world/cells.bin"]) == WORLD_BYTES, "World tuple size is not 1024x1024x5"
    scene = decode_json(files["scene/scene.json"])
    objects = decode_json(files["scene/objects.json"])
    style = decode_json(files["presentation/style.json"])
    annotations = decode_json(files["presentation/annotations.json"])
    assert objects["schema_version"] == 1 and len(objects["objects"]) <= 16
    ids = [value["id"] for value in objects["objects"]]
    assert len(ids) == len(set(ids)), "Duplicate logical object IDs"
    assert scene["source"] == manifest["source"]
    return {
        "schema": "sandfall-sf-m4-independent-zip-v1", "status": "passed",
        "path": str(path), "archive_sha256": digest(path.read_bytes()),
        "archive_bytes": path.stat().st_size, "manifest": manifest, "scene": scene,
        "manifest_bytes_sha256": digest(files["manifest.json"]),
        "objects": objects, "style": style, "annotations": annotations,
        "world_sha256": digest(files["world/cells.bin"]), "world_bytes": WORLD_BYTES,
        "logical_files": {name: {"sha256": digest(data), "bytes": len(data)}
                          for name, data in sorted(files.items()) if name != "manifest.json"},
    }


def encode_files(files: dict[str, bytes], *, extra: tuple[zipfile.ZipInfo, bytes] | None = None) -> bytes:
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for name, data in sorted(files.items()):
            archive.writestr("project/" + name, data)
        if extra is not None:
            archive.writestr(*extra)
    return stream.getvalue()


def mutate(source: Path, destination: Path, kind: str) -> dict:
    source, destination = source.resolve(), destination.resolve()
    files = read_files(source)
    manifest = decode_json(files["manifest.json"])
    objects = decode_json(files["scene/objects.json"])
    scene = decode_json(files["scene/scene.json"])
    extra = None
    if kind == "editable-folder":
        manifest["project"]["title"] = "Edited outside Sandfall"
        files["README.md"] = b"This project was edited with Python's ordinary ZIP/JSON tools.\n"
        if objects["objects"]:
            objects["objects"][0]["name"] = "External stable-ID box"
            objects["objects"][0]["mass"] = 3.25
        files["scene/objects.json"] = json_bytes(objects)
    elif kind == "body17":
        assert len(objects["objects"]) == 16, "Capacity negative must start with the observed sixteen-body project"
        value = copy.deepcopy(objects["objects"][-1])
        value["id"] = "external-body-17"
        value["creation_order"] = max(row["creation_order"] for row in objects["objects"]) + 1
        objects["objects"].append(value)
        files["scene/objects.json"] = json_bytes(objects)
    elif kind in {"bad-mass", "duplicate-id", "bad-shape"}:
        assert objects["objects"], "Object negative needs a real object"
        if kind == "bad-mass":
            objects["objects"][0]["mass"] = 0
        elif kind == "bad-shape":
            objects["objects"][0]["shape"] = "circle"
        else:
            assert len(objects["objects"]) >= 2
            objects["objects"][1]["id"] = objects["objects"][0]["id"]
        files["scene/objects.json"] = json_bytes(objects)
    elif kind == "bad-material":
        cells = bytearray(files["world/cells.bin"])
        cells[0] = 10  # Reserved native catalogue ID, never a paintable material.
        files["world/cells.bin"] = bytes(cells)
    elif kind == "unsupported-solver":
        scene["solver"]["policy"] = "unreviewed-solver"
        files["scene/scene.json"] = json_bytes(scene)
    elif kind == "unsupported-schema":
        manifest["schema_version"] = 999
    elif kind == "traversal":
        extra = (zipfile.ZipInfo("project/../escape.txt"), b"Must never be extracted\n")
    elif kind == "symlink":
        entry = zipfile.ZipInfo("project/assets/link.png")
        entry.create_system = 3
        entry.external_attr = (stat.S_IFLNK | 0o777) << 16
        extra = (entry, b"../../escape")
    elif kind == "case-duplicate":
        extra = (zipfile.ZipInfo("project/SCENE/scene.json"), files["scene/scene.json"])
    elif kind in {"wrong-digest", "crc", "local-name", "declared-bomb"}:
        pass
    else:
        raise ValueError("Unknown negative fixture " + kind)
    manifest["files"] = {name: {"sha256": digest(data), "bytes": len(data)}
                         for name, data in sorted(files.items()) if name != "manifest.json"}
    if kind == "wrong-digest":
        manifest["files"]["world/cells.bin"]["sha256"] = "0" * 64
    files["manifest.json"] = json_bytes(manifest)
    raw = bytearray(encode_files(files, extra=extra))
    if kind in {"crc", "local-name", "declared-bomb"}:
        central = raw.index(b"PK\x01\x02")
        local = struct.unpack_from("<I", raw, central + 42)[0]
        if kind == "crc":
            crc = struct.unpack_from("<I", raw, central + 16)[0] ^ 1
            struct.pack_into("<I", raw, central + 16, crc)
            struct.pack_into("<I", raw, local + 14, crc)
        elif kind == "local-name":
            raw[local + 30] = ord("q")
        else:
            struct.pack_into("<I", raw, central + 24, 128 * 1024 * 1024 + 1)
            struct.pack_into("<I", raw, local + 22, 128 * 1024 * 1024 + 1)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(raw)
    return {"schema": "sandfall-sf-m4-external-fixture-v1", "operation": kind,
            "source": str(source), "source_sha256": digest(source.read_bytes()),
            "path": str(destination), "sha256": digest(raw), "bytes": len(raw),
            "expected": "accepted" if kind == "editable-folder" else "refused-before-scene-replacement"}


def prepare_interop(source: Path, destination: Path) -> dict:
    destination.mkdir(parents=True, exist_ok=True)
    originals, fixtures = [], []
    for count in [0, 1, 3, 8, 16]:
        path = source / f"roundtrip-{count}.sandfall"
        receipt = inspect(path)
        assert len(receipt["objects"]["objects"]) == count
        originals.append(receipt)
        edited = destination / f"edited-{count}.sandfall"
        fixture = mutate(path, edited, "editable-folder")
        external = inspect(edited)
        fixture.update(body_count=count, expected_title="Edited outside Sandfall", expected_first_mass=3.25,
                       world_sha256=receipt["world_sha256"], object_ids=[value["id"] for value in receipt["objects"]["objects"]])
        assert receipt["world_sha256"] == external["world_sha256"]
        fixtures.append(fixture)
    for kind in ["body17", "bad-mass", "duplicate-id", "bad-shape", "bad-material", "unsupported-solver",
                 "unsupported-schema", "traversal", "symlink", "case-duplicate", "wrong-digest", "crc", "local-name", "declared-bomb"]:
        fixtures.append(mutate(source / "roundtrip-16.sandfall", destination / (kind + ".sandfall"), kind))
    value = {"schema": "sandfall-sf-m4-external-interop-v1", "originals": originals, "fixtures": fixtures}
    (destination / "interop.json").write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
    return value


def changed_cells(source: Path, after: Path) -> dict:
    before_bytes = read_files(source)["world/cells.bin"]
    after_bytes = read_files(after)["world/cells.bin"]
    assert len(before_bytes) == len(after_bytes) == WORLD_BYTES
    indices = [index for index in range(1024 * 1024)
               if before_bytes[index * 5:index * 5 + 5] != after_bytes[index * 5:index * 5 + 5]]
    return {"changed_cells": len(indices), "indices": indices[:100],
            "tuples": [{"index": index, "before": list(before_bytes[index * 5:index * 5 + 5]),
                        "after": list(after_bytes[index * 5:index * 5 + 5])} for index in indices[:100]],
            "truncated": len(indices) > 100}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["inspect", "mutate", "interop", "diff-cells"])
    parser.add_argument("source", type=Path)
    parser.add_argument("--destination", type=Path)
    parser.add_argument("--kind")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.command == "inspect":
        value = inspect(args.source)
    elif args.command == "interop":
        value = prepare_interop(args.source, args.destination)
    elif args.command == "diff-cells":
        value = changed_cells(args.source, args.destination)
    else:
        value = mutate(args.source, args.destination, args.kind)
    result = json.dumps(value, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(result)
    else:
        print(result, end="")


if __name__ == "__main__":
    main()
