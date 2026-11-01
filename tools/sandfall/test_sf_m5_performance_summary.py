"""Synthetic reducer negatives; these fixtures are not browser qualification."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from tools.sandfall.sf_m5_performance_summary import reduce


def receipt(repetition):
    names = ["index.pck", "index.js", "index.wasm", "index.side.wasm", "godot_rapier.wasm",
             "libcybersand_native.web.nothreads.wasm", "SHA256SUMS"]
    return {"schema": "sandfall-sf-m5-performance-browser-v1", "status": "passed", "failures": [],
            "source_commit": "a" * 40, "profile": "compat", "workers_configured": 1,
            "workload": "sixteen_body", "speed": 1, "repetition": repetition,
            "viewport": {"width": 800, "height": 450, "dpr": 1},
            "browser": {"product": "Synthetic oracle fixture only"},
            "runner": {"cpu_model": "Synthetic", "logical_cpus": 8, "available_parallelism": 4,
                       "platform": "synthetic", "arch": "synthetic"}, "registered_duration_ms": 30000,
            "harness_checkout": {"dirty_paths": []}, "input": [{"synthetic_oracle_only": True}],
            "served_identity": [{"path": name, "sha256": hashlib.sha256(name.encode()).hexdigest(), "bytes": 100} for name in names],
            "summary": {"wall_seconds": 30, "achieved_ticks_per_second": 20 + repetition,
                        "achieved_speed": 0.4, "achieved_fraction_of_requested": 0.4,
                        "frame_callbacks_per_second": 30, "render_payload_bytes_per_second": 1000},
            "samples": [{"godot_memory_static_bytes": 0, "godot_memory_static_available": False,
                         "cdp_metrics": {"JSHeapUsedSize": 100, "TaskDuration": 0}},
                        {"godot_memory_static_bytes": 0, "godot_memory_static_available": False,
                         "cdp_metrics": {"JSHeapUsedSize": 200, "TaskDuration": 10}}],
            "terminal": {"performance": {"host": {"metrics": {"native_tick_ms": {
                "p50": 5, "p95": 7, "max": 10, "window_count": 600, "count": 600}}}}}}


class PopulationIdentity(unittest.TestCase):
    def run_rows(self, rows):
        with tempfile.TemporaryDirectory() as folder:
            paths = []
            for index, row in enumerate(rows):
                path = Path(folder) / f"run-{index}.json"
                path.write_text(json.dumps(row))
                paths.append(path)
            return reduce(paths)

    def test_repeated_population_preserves_actual_artifact_identity(self):
        result = self.run_rows([receipt(i) for i in [1, 2, 3]])
        self.assertEqual(len(result["populations"]), 1)
        self.assertEqual(len(result["populations"][0]["served_artifacts"]), 7)
        self.assertFalse(result["populations"][0]["resource_trends"][0]["godot_allocator_bytes"]["available"])

    def test_different_native_or_pck_bytes_cannot_be_pooled(self):
        for name in ["index.pck", "libcybersand_native.web.nothreads.wasm"]:
            rows = [receipt(i) for i in [1, 2, 3]]
            next(row for row in rows[2]["served_identity"] if row["path"] == name)["sha256"] = "b" * 64
            with self.assertRaisesRegex(ValueError, "independent runs"):
                self.run_rows(rows)

    def test_available_parallelism_is_part_of_population(self):
        rows = [receipt(i) for i in [1, 2, 3]]
        rows[2]["runner"]["available_parallelism"] = 2
        with self.assertRaisesRegex(ValueError, "independent runs"):
            self.run_rows(rows)

    def test_duplicate_failed_dirty_and_missing_inventory_are_refused(self):
        first = receipt(1)
        with self.assertRaisesRegex(ValueError, "Duplicate receipt"):
            self.run_rows([first, copy.deepcopy(first), receipt(3)])
        for mutate in [lambda r: r.update(status="failed"),
                       lambda r: r["harness_checkout"].update(dirty_paths=["modified harness"]),
                       lambda r: r.update(served_identity=r["served_identity"][:-1])]:
            rows = [receipt(i) for i in [1, 2, 3]]
            mutate(rows[2])
            with self.assertRaises(ValueError):
                self.run_rows(rows)


if __name__ == "__main__":
    unittest.main()
