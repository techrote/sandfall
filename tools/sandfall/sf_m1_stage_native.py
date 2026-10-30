#!/usr/bin/env python3
"""Stage current Sandfall scripts with an explicitly identified fresh Linux build.

This development helper never rewrites the tracked desktop runtime or its
historical provenance. Its receipt reports local source deltas; it is not an
exact-commit Web qualification or a desktop release attestation.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native-library", type=Path, required=True)
    parser.add_argument("--expected-native-sha", required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "build/sf-m1-native-stage.json")
    args = parser.parse_args()
    library = args.native_library.resolve()
    if library.is_relative_to(ROOT / "godot"):
        raise ValueError("Use the fresh build outside the inherited Godot runtime directory")
    if digest(library) != args.expected_native_sha or library.read_bytes()[:4] != b"\x7fELF":
        raise ValueError("Fresh native artifact SHA or ELF format mismatch")
    rapier_record = json.loads((ROOT / "godot/addons/godot-rapier2d/runtime-provenance.linux.json").read_text())
    rapier = ROOT / rapier_record["artifact"]
    if digest(rapier) != rapier_record["sha256"] or rapier.stat().st_size != rapier_record["size"]:
        raise ValueError("Pinned Rapier Linux payload is not materialized or does not match its receipt")
    stage = ROOT / "build/sf-m1-native-project"
    if stage.exists():
        shutil.rmtree(stage)
    shutil.copytree(ROOT / "godot", stage, ignore=shutil.ignore_patterns(".godot", "native_extension"))
    binary_root = stage / "addons/cybersand_native/bin"
    shutil.rmtree(binary_root)
    binary_root.mkdir(parents=True)
    shutil.copy2(library, binary_root / "libcybersand_native.linux.x86_64.so")
    project = (stage / "project.godot").read_text()
    project = project.replace('FeatureNavigation="*res://scripts/feature_navigation.gd"\n', '')
    project = project.replace("native_worker_threads=0", "native_worker_threads=1")
    (stage / "project.godot").write_text(project)
    tracked_delta = subprocess.check_output(["git", "-C", str(ROOT), "status", "--porcelain"], text=True)
    source = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()
    record = {
        "schema": "sandfall-sf-m1-local-native-stage-v1",
        "scope": "fresh local native development runtime; not historical desktop qualification",
        "source_commit": source, "working_tree_status": tracked_delta.splitlines(),
        "source_identity_kind": "git-checkout-with-local-deltas" if tracked_delta else "git-checkout",
        "artifact": "libcybersand_native.linux.x86_64.so",
        "sha256": digest(library), "size": library.stat().st_size,
        "stage": str(stage),
        "native": {"path": str(library), "sha256": digest(library), "size": library.stat().st_size},
        "rapier": {"path": rapier_record["artifact"], "sha256": digest(rapier), "size": rapier.stat().st_size},
        "staged_project_sha256": digest(stage / "project.godot"),
        "script_sha256": {p.relative_to(stage).as_posix(): digest(p)
                          for p in sorted(stage.rglob("*.gd"))},
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(record, indent=2) + "\n")
    # The separate filename avoids altering the inherited historical receipt.
    (stage / "addons/cybersand_native/runtime-provenance.sandfall-native.json").write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps({"stage": str(stage), "receipt": str(args.output), "native_sha256": digest(library)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
