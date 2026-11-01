#!/usr/bin/env python3
"""Fail-closed M5-B01 reducer for actual retained and new Godot test receipts.

Run the production tests first. This tool reads their original logs, checks the
actual staged source/runtime bytes, measures repeated Gallery outcome variance,
and emits a local scientific receipt. It never turns an export or model fixture
into browser, human, cross-platform or whole-stack bitwise qualification.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
MARKERS = {
    "authoring": "SANDFALL_AUTHORING_TEST ",
    "objects": "SANDFALL_OBJECT_TEST ",
    "projects": "SANDFALL_PROJECTS_TEST ",
    "gallery": "SANDFALL_GALLERY_RESULT ",
    "scientific": "SANDFALL_SCIENTIFIC_TEST ",
}
# Declared before this reducer's first measurement. The two selected outcomes
# have controlled initial data and no actor authority; 1/64 cell is smaller
# than a material cell. Other Gallery scenes report variance without silently
# acquiring this repeatability claim. These are local, not cross-platform limits.
GOLDEN_SCENES = ("fluid_messenger", "endless_kinetic_loop")
GALLERY_SCENES = ("gravity_cascade", "fluid_messenger", "passive_subject_ride",
                  "endless_kinetic_loop", "intervention", "time_controls", "sixteen_body")
GOLDEN_LIMITS = {
    "position_cells": 1.0 / 64.0,
    "linear_velocity_cells_per_second": 1.0 / 64.0,
    "rotation_radians": 0.0001,
    "angular_velocity_radians_per_second": 0.0001,
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def git(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True, timeout=30).strip()


def finite(value: object) -> float:
    require(isinstance(value, (int, float)) and not isinstance(value, bool), "non-numeric physical observation")
    require(math.isfinite(float(value)), "nonfinite physical observation")
    return float(value)


def read_receipts(logs: list[Path]) -> tuple[dict, list[dict]]:
    records: dict[str, dict] = {}
    custody = []
    for path in logs:
        data = path.read_text(encoding="utf-8")
        # These selected suites do not exercise malformed decompression. No
        # engine-error exception applies, even if Godot returned exit zero.
        require(not re.search(r"(?:SCRIPT ERROR:|^ERROR:|handle_crash:)", data, re.MULTILINE),
                f"engine/script failure retained in {path}")
        found = []
        for line in data.splitlines():
            for name, marker in MARKERS.items():
                if not line.startswith(marker):
                    continue
                require(name not in records, f"duplicate terminal receipt: {name}")
                record = json.loads(line[len(marker):])
                require(record.get("ok") is True and record.get("failures") == [], f"failed {name} receipt")
                records[name] = record
                found.append(name)
        custody.append({"path": str(path), "sha256": digest(path), "size": path.stat().st_size, "receipts": found})
    require(set(records) == set(MARKERS), "missing executed suites: " + ", ".join(sorted(set(MARKERS) - set(records))))
    return records, custody


def _component_span(values: list[list], indices: tuple[int, ...]) -> float:
    return max(max(finite(pose[index]) for pose in values) - min(finite(pose[index]) for pose in values)
               for index in indices)


def gallery_variance(receipt: dict) -> dict:
    groups: dict[tuple, list] = defaultdict(list)
    runs = receipt["runs"]
    for run in runs:
        groups[(run["scene"], run["ticks"])].append(run)
    require(set(groups) == {(scene, 600) for scene in GALLERY_SCENES}
            | {("passive_subject_ride", 1200), ("fluid-messenger-no-water-control", 600)},
            "incomplete/unknown retained Gallery workload inventory")
    for scene in GALLERY_SCENES:
        require(sorted(r["repetition"] for r in groups[(scene, 600)]) == [1, 2],
                "missing genuine repeated Gallery executions: " + scene)
    result = {}
    for (scene, ticks), observations in sorted(groups.items()):
        if len(observations) < 2:
            continue
        require(len({r["repetition"] for r in observations}) == len(observations), "duplicate Gallery repetition")
        initial = observations[0]["initial_body_poses"]
        ids = observations[0]["final"]["body_ids"]
        spans = {key: 0.0 for key in GOLDEN_LIMITS}
        for run in observations:
            final = run["final"]
            require(run["initial_body_poses"] == initial and run["reset_body_poses"] == initial,
                    "repeated Gallery initial/reset poses differ")
            require(final["body_ids"] == ids and len(final["body_states"]) == len(initial), "repeated Gallery IDs differ")
            require(final["native_tick"] == ticks and final["rapier_steps"] == ticks and final["workers"] == 1,
                    "Gallery solver/worker observations do not match registered local conditions")
        for index in range(len(initial)):
            poses = [r["final"]["body_states"][index] for r in observations]
            spans["position_cells"] = max(spans["position_cells"], _component_span(poses, (0, 1)))
            spans["linear_velocity_cells_per_second"] = max(spans["linear_velocity_cells_per_second"], _component_span(poses, (3, 4)))
            # Compare recorded angles at equal ticks; no modulo hides turns.
            spans["rotation_radians"] = max(spans["rotation_radians"], _component_span(poses, (2,)))
            spans["angular_velocity_radians_per_second"] = max(spans["angular_velocity_radians_per_second"], _component_span(poses, (5,)))
        selected = scene in GOLDEN_SCENES and ticks == 600
        within = all(spans[key] <= GOLDEN_LIMITS[key] for key in spans)
        if selected:
            require(within, f"registered local Golden Run tolerance failed: {scene}: {spans}")
        material_hashes = [r["final"]["current_material_sha256"] for r in observations]
        counters = {}
        for counter in ("moves_total", "contacts_total", "displaced_total"):
            values = [finite(r["final"][counter]) for r in observations]
            counters[counter] = {"values": values, "min": min(values), "max": max(values), "span": max(values) - min(values)}
        result[f"{scene}:{ticks}"] = {
            "runs": len(observations), "ticks_per_run": ticks, "body_ids": ids,
            "maximum_component_spans": spans, "counters": counters,
            "material_sha256": material_hashes, "material_hashes_identical": len(set(material_hashes)) == 1,
            "registered_local_tolerance": selected, "within_registered_tolerance": within if selected else None,
            "final_body_poses": [r["final"]["body_states"] for r in observations],
        }
    require(all(f"{scene}:600" in result for scene in GOLDEN_SCENES), "missing repeated registered Golden Runs")
    controls = [r for r in runs if r["scene"] == "fluid-messenger-no-water-control" and r["ticks"] == 600]
    require(len(controls) == 1, "missing/duplicate executed no-Water control")
    control = controls[0]
    final = control["final"]
    require(final["native_tick"] == 600 and final["rapier_steps"] == 600 and final["contacts_total"] == 0,
            "no-Water control counters/contacts are wrong")
    require(all(row["applications"] == 0 for row in final["object_feedback"].values()), "no-Water control has applied feedback")
    require(math.dist(control["initial_body_poses"][0][:2], final["body_states"][0][:2]) < 0.001,
            "no-Water control moved without native force")
    for run in groups[("fluid_messenger", 600)]:
        observed = run["final"]
        feedback = observed["object_feedback"][observed["body_ids"][0]]
        require(observed["contacts_total"] > 0 and feedback["applications"] > 0,
                "Fluid Messenger has no actual contact/feedback")
        require(math.hypot(finite(feedback["accepted_impulse_x"]), finite(feedback["accepted_impulse_y"])) > 0,
                "Fluid Messenger accepted no nonzero native impulse")
        require(math.dist(run["initial_body_poses"][0][:2], observed["body_states"][0][:2]) > 0.1,
                "Fluid Messenger did not move the real body")
    return {"limits": GOLDEN_LIMITS, "selected_scenes": list(GOLDEN_SCENES), "groups": result,
            "no_water_control": control, "scope": "repeated local outcomes; hashes reported, whole-stack bitwise replay not asserted"}


def validate_scientific(receipt: dict) -> dict:
    presets = receipt["receipts"]["fixed_step_presets"]
    cases = presets["cases"]
    require([c["speed"] for c in cases] == [0.25, 0.5, 1.0, 2.0, 4.0], "incomplete five-speed scientific matrix")
    for case in cases:
        require(case["actual_native_ticks"] == case["actual_rapier_steps"] == 61 and case["single_step"] == 1,
                "wrong actual fixed-step counters")
        require(case["paced_ticks"] == sum(case["steps_by_frame"]) == 60, "wrong paced tick inventory")
        require(case["frames"] == len(case["steps_by_frame"]) == int(60 / case["speed"]), "wrong pacing frame count")
        require(abs(finite(case["fixed_delta"]) - 1.0 / 60) < 1e-12 and case["solver_iterations"] == 4,
                "pinned fixed-dt/substep conditions changed")
        require(case["post_step_chemical"]["id"] == 3 and case["post_step_thermal"]["temperature"] == 777,
                "chemical/thermal observation missing")
        require(case["reset_initial_cells_exact"] is True and case["reset_initial_poses_exact"] is True,
                "authored reconstruction failed")
    require(len({c["final_cells_sha256"] for c in cases}) == 1, "equal-tick local material identities differ")
    stress = receipt["receipts"]["capacity_replacement"]
    require(stress["repetitions"] == 2 and stress["ticks_per_owner"] == 120
            and stress["sequence"] == [16, 0, 1, 3, 8, 16], "wrong repeated-owner workload")
    require([(c["repetition"], c["body_count"]) for c in stress["cases"]]
            == [(r, n) for r in (1, 2) for n in (16, 0, 1, 3, 8, 16)], "incomplete repeated-owner cases")
    for case in stress["cases"]:
        require(case["ticks"] == 120 and case["rapier_steps"] == (120 if case["body_count"] else 0), "wrong stress counters")
        require(case["bounded_container_count"] == 1, "owner container depth grew")
        require(len(case["initial_body_poses"]) == len(case["final_body_poses"]) == case["body_count"], "stress body count changed")
        if case["body_count"] == 16:
            require(bool(case["body_body_pairs"]) and case["contacts"] > 0, "sixteen-body stress lacks actual contact")
    return {"fixed_step_presets": presets, "capacity_replacement": stress}


def source_custody(args: argparse.Namespace) -> dict:
    head = git("rev-parse", "HEAD")
    require(head == args.source_commit, "current HEAD differs from requested source")
    require(not git("status", "--porcelain", "--untracked-files=normal"), "source checkout is not clean")
    require(not git("diff", args.native_source_commit, head, "--", "native", "godot/native_extension"),
            "reused native artifact source differs from current native source")
    project = args.project.resolve()
    mismatches = [str(path.relative_to(ROOT / "godot")) for path in (ROOT / "godot").rglob("*.gd")
                  if not (project / path.relative_to(ROOT / "godot")).is_file()
                  or digest(path) != digest(project / path.relative_to(ROOT / "godot"))]
    require(not mismatches, "staged scripts differ from committed source: " + ", ".join(mismatches))
    native = project / "addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
    require(digest(native) == args.native_sha256 and native.read_bytes()[:4] == b"\x7fELF", "native payload mismatch")
    rapier_record = json.loads((ROOT / "godot/addons/godot-rapier2d/runtime-provenance.linux.json").read_text())
    rapier = project / Path(rapier_record["artifact"]).relative_to("godot")
    require(digest(rapier) == rapier_record["sha256"] and rapier.stat().st_size == rapier_record["size"], "pinned Rapier payload mismatch")
    version = subprocess.check_output([str(args.godot), "--version"], text=True, timeout=30).strip()
    require(version == GODOT_VERSION, "Godot pin differs")
    return {"source_commit": head, "source_tree": git("rev-parse", "HEAD^{tree}"),
            "native_source_commit": args.native_source_commit, "native_inputs_equal_to_current_source": True,
            "native_runtime_sha256": digest(native), "native_runtime_size": native.stat().st_size,
            "rapier_runtime_sha256": digest(rapier), "rapier_version": "0.35.2", "godot": version,
            "godot_binary_sha256": digest(args.godot), "stage": str(project),
            "staged_project_sha256": digest(project / "project.godot"),
            "test_script_sha256": {p.name: digest(p) for p in sorted((ROOT / "godot/tests").glob("test_sandfall*.gd"))},
            "scope": "Linux local scientific execution; source/runtime association also requires the enclosing CI/build record"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, action="append", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--native-source-commit", required=True)
    parser.add_argument("--native-sha256", required=True)
    args = parser.parse_args()
    result = {"schema": "sandfall-m5-b01-scientific-v1", "status": "failed", "failures": [],
              "browser_qualified": False, "human_exhibition_accepted": False,
              "cross_platform_outcome_qualified": False, "whole_stack_bitwise_replay": False}
    try:
        result["source"] = source_custody(args)
        records, logs = read_receipts(args.log)
        result["logs"] = logs
        result["executed_suites"] = {name: {"ok": value["ok"], "checks": value.get("checks")} for name, value in records.items()}
        result["retained_chemical_thermal_and_partial_failure"] = records["authoring"]["receipts"]
        result["scientific"] = validate_scientific(records["scientific"])
        result["golden_local_variance"] = gallery_variance(records["gallery"])
        result["status"] = "passed-local-scientific-contracts"
    except (ValueError, KeyError, TypeError, IndexError, OSError, subprocess.SubprocessError) as exc:
        result["failures"].append(f"{type(exc).__name__}: {exc}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, allow_nan=False) + "\n")
    print(json.dumps({"status": result["status"], "failures": result["failures"], "output": str(args.output)}))
    return 0 if result["status"] == "passed-local-scientific-contracts" else 1


if __name__ == "__main__":
    sys.exit(main())
