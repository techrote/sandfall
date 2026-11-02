#!/usr/bin/env python3
"""Retain complete selected Godot command blocks from the original build log.

This does not delete or forgive diagnostics. The five selected suites have no
expected engine errors, and the scientific reducer validates their full blocks.
The original whole-build log, including witnessed archive refusals, stays intact.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

NAMES = frozenset({"authoring", "objects", "projects", "gallery", "scientific"})


def extract(data: bytes) -> dict[str, bytes]:
    lines = data.splitlines(keepends=True)
    commands = [index for index, line in enumerate(lines) if line.startswith(b"+ ")]
    blocks = {}
    for start, stop in zip(commands, commands[1:] + [len(lines)]):
        match = re.search(rb" --script res://tests/test_sandfall_([a-z_]+)\.gd\r?\n?$", lines[start])
        if match is None or match[1].decode() not in NAMES:
            continue
        name = match[1].decode()
        if name in blocks:
            raise ValueError("Duplicate executed scientific suite: " + name)
        blocks[name] = b"".join(lines[start:stop])
    if set(blocks) != NAMES:
        raise ValueError("Incomplete scientific command blocks: " + ", ".join(sorted(NAMES - set(blocks))))
    return blocks


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    data = args.log.read_bytes()
    blocks = extract(data)
    args.output.mkdir(parents=True, exist_ok=False)
    record = {"source_log": str(args.log.resolve()), "sha256": hashlib.sha256(data).hexdigest(),
              "bytes": len(data), "blocks": {}}
    for name, block in sorted(blocks.items()):
        path = args.output / (name + ".log")
        path.write_bytes(block)
        record["blocks"][name] = {"path": path.name, "bytes": len(block), "sha256": hashlib.sha256(block).hexdigest()}
    (args.output / "extraction.json").write_text(json.dumps(record, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
