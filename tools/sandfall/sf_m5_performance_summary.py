#!/usr/bin/env python3
"""Reduce genuine SF-M5 browser measurements without pooling incompatible runs.

Inputs remain separate receipts. Median-of-run p95 is explicitly labelled; it is
not a pooled tick p95. This reduction cannot establish browser execution itself.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import hashlib
import json
import math
from pathlib import Path
import re
import statistics


def distribution(values: list[float]) -> dict:
    if not values or any(not isinstance(x, (float, int)) or not math.isfinite(x) for x in values):
        raise ValueError("Missing/nonfinite measured values")
    ordered = sorted(values)
    return {"count": len(values), "min": min(values), "p50": statistics.median(values),
            "p95_nearest_rank": ordered[math.ceil(0.95 * len(ordered)) - 1],
            "max": max(values), "mean": statistics.mean(values),
            "sample_stddev": statistics.stdev(values) if len(values) > 1 else None}


def runtime_identity(receipt: dict) -> tuple:
    rows = receipt["served_identity"]
    result = []
    for row in rows:
        path, digest, size = row["path"], row["sha256"], row["bytes"]
        if not isinstance(path, str) or not re.fullmatch(r"[A-Za-z0-9_.-]+", path) or not re.fullmatch(r"[a-f0-9]{64}", digest):
            raise ValueError("Invalid served artifact identity")
        if not isinstance(size, int) or isinstance(size, bool) or size < 1:
            raise ValueError("Missing served artifact byte length")
        result.append((path, digest, size))
    if len({row[0] for row in result}) != len(result):
        raise ValueError("Duplicate served artifact paths")
    if not {"index.pck", "index.js", "index.wasm", "index.side.wasm", "godot_rapier.wasm", "SHA256SUMS"} <= {row[0] for row in result}:
        raise ValueError("Incomplete source/runtime inventory")
    native = "libcybersand_native.web." + ("threads" if receipt["profile"] == "threaded" else "nothreads") + ".wasm"
    if native not in {row[0] for row in result}:
        raise ValueError("Missing profile-matched native runtime")
    return tuple(sorted(result))


def reduce(paths: list[Path], minimum_repetitions: int = 3) -> dict:
    if minimum_repetitions < 2:
        raise ValueError("A repeated-run report requires at least two independent runs")
    inputs = []
    groups: dict[tuple, list] = defaultdict(list)
    digests: set[str] = set()
    for path in paths:
        data = path.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        if digest in digests:
            raise ValueError("Duplicate receipt bytes cannot count as another run")
        digests.add(digest)
        value = json.loads(data)
        if value.get("schema") != "sandfall-sf-m5-performance-browser-v1" or value.get("status") != "passed" or value.get("failures"):
            raise ValueError(f"Unqualified performance receipt: {path}")
        if not value.get("samples") or not value.get("input") or not value.get("served_identity"):
            raise ValueError(f"Missing executed browser/input/artifact evidence: {path}")
        if value.get("harness_checkout", {}).get("dirty_paths"):
            raise ValueError(f"Uncommitted browser harness: {path}")
        if not value.get("summary") or not value.get("terminal", {}).get("performance"):
            raise ValueError(f"Missing source-observed performance summary: {path}")
        vp, browser, runner = value["viewport"], value["browser"], value["runner"]
        artifacts = runtime_identity(value)
        # Device/viewport/duration/source/profile are parts of the population,
        # never silently collapsed into a misleading all-machines number.
        key = (value["source_commit"], value["profile"], value["workers_configured"], value["workload"],
               value["speed"], vp["width"], vp["height"], vp["dpr"], browser["product"],
               runner["cpu_model"], runner["logical_cpus"], runner["available_parallelism"], runner["platform"], runner["arch"],
               value["registered_duration_ms"], artifacts)
        groups[key].append(value)
        inputs.append({"path": str(path), "sha256": digest, "source_commit": value["source_commit"],
                       "repetition": value["repetition"]})
    summaries = []
    for key, rows in groups.items():
        if len(rows) < minimum_repetitions:
            raise ValueError(f"Only {len(rows)} independent runs for {key}; require {minimum_repetitions}")
        if len({row["repetition"] for row in rows}) != len(rows):
            raise ValueError(f"Repeated run identifiers in population {key}")
        first = rows[0]
        measures = {}
        for field in ["achieved_ticks_per_second", "achieved_speed", "achieved_fraction_of_requested",
                      "frame_callbacks_per_second", "render_payload_bytes_per_second"]:
            measures[field] = distribution([row["summary"][field] for row in rows])
        native = [row["terminal"]["performance"]["host"]["metrics"]["native_tick_ms"] for row in rows]
        measures["native_tick_p50_ms_across_runs"] = distribution([m["p50"] for m in native])
        measures["native_tick_p95_ms_across_runs"] = distribution([m["p95"] for m in native])
        measures["native_tick_lifetime_max_ms_across_runs"] = distribution([m["max"] for m in native])
        resource_trends = []
        for row in rows:
            samples = row["samples"]
            memory = [sample["godot_memory_static_bytes"] for sample in samples]
            heaps = [sample["cdp_metrics"].get("JSHeapUsedSize") for sample in samples]
            tasks = [sample["cdp_metrics"].get("TaskDuration") for sample in samples]
            span = row["summary"]["wall_seconds"]
            resource_trends.append({"repetition": row["repetition"],
                "godot_allocator_bytes": {"available": all(sample.get("godot_memory_static_available", False) for sample in samples),
                    "first": memory[0], "last": memory[-1], "min": min(memory), "max": max(memory),
                    "limit": "Zero/unsupported monitors are unavailable evidence, not zero browser memory"},
                "js_heap_bytes": {"first": heaps[0], "last": heaps[-1]},
                "renderer_main_thread_task_seconds": None if None in (tasks[0], tasks[-1]) else tasks[-1] - tasks[0],
                "renderer_main_thread_task_fraction": None if None in (tasks[0], tasks[-1]) else (tasks[-1] - tasks[0]) / span})
        summaries.append({"source_commit": first["source_commit"], "profile": first["profile"],
            "workers_configured": first["workers_configured"], "workload": first["workload"],
            "speed": first["speed"], "viewport": first["viewport"], "browser": first["browser"],
            "runner": first["runner"], "registered_duration_ms": first["registered_duration_ms"],
            "served_artifacts": [{"path": path, "sha256": digest, "bytes": size}
                                 for path, digest, size in runtime_identity(first)],
            "repetitions": [row["repetition"] for row in rows], "measures": measures,
            "native_latency_windows": [{"repetition": row["repetition"], **metric} for row, metric in zip(rows, native)],
            "resource_trends": resource_trends})
    return {"schema": "sandfall-sf-m5-performance-summary-v1", "status": "passed",
        "minimum_repetitions": minimum_repetitions, "inputs": inputs, "populations": summaries,
        "acceptance": "Complete source-bound measurements and owner/capacity integrity; no FPS threshold asserted",
        "limits": ["Small-sample run distributions do not establish a confidence interval or universal device performance.",
                   "Per-run latency quantiles retain individual bounded-window scope; they are not pooled tick quantiles.",
                   "CDP renderer TaskDuration and JS heap do not measure all CPU cores, WASM memory or process RSS.",
                   "Headless/software-rendered results cannot be relabelled physical user-device exhibition acceptance."]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("receipts", nargs="+", type=Path)
    parser.add_argument("--minimum-repetitions", type=int, default=3)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = reduce(args.receipts, args.minimum_repetitions)
    except (OSError, KeyError, TypeError, ValueError) as error:
        result = {"schema": "sandfall-sf-m5-performance-summary-v1", "status": "failed", "error": str(error)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"status": result["status"], "output": str(args.output), "error": result.get("error")}))
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
