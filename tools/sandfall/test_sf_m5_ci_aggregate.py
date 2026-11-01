"""A skipped, absent, failed or cancelled required gate never becomes a pass."""
import copy
import unittest
try:
    from sf_m5_ci_aggregate import ROUTINE, FULL, validate
except ModuleNotFoundError:
    from tools.sandfall.sf_m5_ci_aggregate import ROUTINE, FULL, validate


class MachineAggregate(unittest.TestCase):
    def setUp(self):
        self.complete = {name: {"result": "success"} for name in ROUTINE | FULL}

    def test_complete_machine_result_has_no_release_or_human_verdict(self):
        result = validate(self.complete, True)
        self.assertEqual(result["status"], "passed")
        self.assertIs(result["release_ready"], False)
        self.assertEqual(result["human_acceptance"], "separate-required-gate")

    def test_every_required_job_refuses_skipped_cancelled_failed(self):
        for name in self.complete:
            for disposition in ("skipped", "failure", "cancelled"):
                with self.subTest(name=name, disposition=disposition):
                    bad = copy.deepcopy(self.complete)
                    bad[name]["result"] = disposition
                    self.assertEqual(validate(bad, True)["status"], "failed")

    def test_routine_scope_records_full_matrix_as_unexecuted(self):
        for name in FULL:
            self.complete[name]["result"] = "skipped"
        self.assertEqual(validate(self.complete, False)["status"], "passed")
        self.assertEqual(validate(self.complete, True)["status"], "failed")

    def test_missing_added_or_unidentified_results_refuse(self):
        for value in ({}, {**self.complete, "unregistered-gate": {"result": "success"}},
                      {**self.complete, "performance": {}},
                      {**self.complete, "performance": {"result": "pending"}}):
            with self.assertRaises(ValueError):
                validate(value, True)
        for flag in (None, "false", "true", 0, 1):
            with self.assertRaises(ValueError):
                validate(self.complete, flag)


if __name__ == "__main__":
    unittest.main()
