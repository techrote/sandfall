"""Negative tests for the evidence reducer, not synthetic physical evidence."""
from copy import deepcopy
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from tools.sandfall import sf_m5_science_report as report


def model_gallery():
    runs = []
    for scene in report.GALLERY_SCENES:
        for repetition in (1, 2):
            runs.append(model_run(scene, 600, repetition))
    runs.append(model_run("passive_subject_ride", 1200, 3))
    control = model_run("fluid-messenger-no-water-control", 600, 1)
    control["final"]["body_states"] = deepcopy(control["initial_body_poses"])
    control["final"]["contacts_total"] = 0
    control["final"]["object_feedback"]["subject"]["applications"] = 0
    runs.append(control)
    return {"ok": True, "failures": [], "runs": runs}


def model_run(scene, ticks, repetition):
    initial = [[100, 100, 0, 0, 0, 0, False]]
    return {"scene": scene, "ticks": ticks, "repetition": repetition,
            "initial_body_poses": initial, "reset_body_poses": deepcopy(initial),
            "final": {"native_tick": ticks, "rapier_steps": ticks, "workers": 1,
                      "body_ids": ["subject"], "body_states": [[101, 100, 0, 1, 0, 0, False]],
                      "current_material_sha256": "a" * 64, "moves_total": 5,
                      "contacts_total": 2, "displaced_total": 1,
                      "object_feedback": {"subject": {"applications": 2,
                                                     "accepted_impulse_x": 1, "accepted_impulse_y": 0}}}}


class EvidenceReducerTests(unittest.TestCase):
    def test_registered_repeated_outcomes_report_observed_variance(self):
        data = model_gallery()
        second = next(r for r in data["runs"] if r["scene"] == "fluid_messenger" and r["repetition"] == 2)
        second["final"]["body_states"][0][0] += 0.001
        measured = report.gallery_variance(data)
        fluid = measured["groups"]["fluid_messenger:600"]
        self.assertAlmostEqual(fluid["maximum_component_spans"]["position_cells"], 0.001)
        self.assertTrue(fluid["within_registered_tolerance"])
        self.assertEqual(fluid["runs"], 2)
        self.assertNotIn("bitwise_deterministic", measured)

    def test_real_numeric_divergence_is_not_a_pass(self):
        data = model_gallery()
        data["runs"][3]["final"]["body_states"][0][0] += 0.1
        with self.assertRaisesRegex(ValueError, "tolerance failed"):
            report.gallery_variance(data)

    def test_nan_cannot_pass_comparison(self):
        data = model_gallery()
        data["runs"][3]["final"]["body_states"][0][0] = float("nan")
        with self.assertRaisesRegex(ValueError, "nonfinite"):
            report.gallery_variance(data)

    def test_missing_repeated_workload_refuses(self):
        data = model_gallery()
        data["runs"].pop(3)
        with self.assertRaisesRegex(ValueError, "missing genuine repeated"):
            report.gallery_variance(data)

    def test_control_with_synthetic_force_refuses(self):
        data = model_gallery()
        data["runs"][-1]["final"]["object_feedback"]["subject"]["applications"] = 1
        with self.assertRaisesRegex(ValueError, "applied feedback"):
            report.gallery_variance(data)

    def test_worker_or_tick_mismatch_refuses(self):
        for field, value in (("workers", 2), ("native_tick", 599), ("rapier_steps", 0)):
            data = model_gallery()
            data["runs"][2]["final"][field] = value
            with self.assertRaisesRegex(ValueError, "solver/worker"):
                report.gallery_variance(data)

    def test_missing_terminal_suite_refuses_even_if_other_suites_pass(self):
        with TemporaryDirectory() as tmp:
            path = Path(tmp) / "partial.log"
            path.write_text(report.MARKERS["authoring"] + json.dumps({"ok": True, "failures": []}) + "\n")
            with self.assertRaisesRegex(ValueError, "missing executed"):
                report.read_receipts([path])

    def test_error_after_successful_receipt_is_retained_as_failure(self):
        with TemporaryDirectory() as tmp:
            path = Path(tmp) / "errors.log"
            path.write_text(report.MARKERS["authoring"] + '{"ok":true,"failures":[]}\nSCRIPT ERROR: broken\n')
            with self.assertRaisesRegex(ValueError, "engine/script failure"):
                report.read_receipts([path])

    def test_receipt_failure_cannot_hide_under_top_level_true(self):
        with TemporaryDirectory() as tmp:
            path = Path(tmp) / "false-success.log"
            path.write_text(report.MARKERS["authoring"] + '{"ok":true,"failures":["unclosed failure"]}\n')
            with self.assertRaisesRegex(ValueError, "failed authoring"):
                report.read_receipts([path])

    def test_duplicate_terminal_receipts_refuse(self):
        with TemporaryDirectory() as tmp:
            path = Path(tmp) / "duplicate.log"
            path.write_text((report.MARKERS["authoring"] + '{"ok":true,"failures":[]}\n') * 2)
            with self.assertRaisesRegex(ValueError, "duplicate terminal"):
                report.read_receipts([path])


if __name__ == "__main__":
    unittest.main()
