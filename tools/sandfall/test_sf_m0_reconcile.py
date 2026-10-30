"""Synthetic, self-contained negative tests for SF-M0 reconciliation.

These tests do NOT claim the real inherited CyberSand workspace/desktop
errors are repaired; the actual checker is run separately and retained.
"""
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import json
import unittest
from unittest.mock import patch

from tools.sandfall import sf_m0_reconcile as reconcile


class ReconciliationTests(unittest.TestCase):
    def _payload(self):
        docs = sorted(reconcile.EXPECTED_DOC_ERRORS)
        return {
            "status": "failed",
            "errors": sorted(reconcile.EXPECTED),
            "documentation": {"status": "failed", "errors": docs},
            "materialized_runtime_files": [f"native-or-rapier-{i}" for i in range(18)],
            "unmaterialized_runtime_files": [],
        }

    def _invoke(self, payload, exitcode=1):
        with TemporaryDirectory() as folder:
            root = Path(folder)
            destination = root / "diagnostic.json"
            with patch.object(reconcile.subprocess, "run", return_value=SimpleNamespace(
                returncode=exitcode, stdout=json.dumps(payload), stderr="")), \
                patch.object(reconcile.subprocess, "check_output",
                             return_value="0123456789abcdef0123456789abcdef01234567"):
                status = reconcile.run(root, destination)
            record = json.loads(destination.read_text())
            self.assertEqual(record["original_checker"], payload)
            return status, record

    def test_exact_known_inherited_failures_are_retained_but_scoped(self):
        rc, record = self._invoke(self._payload())
        self.assertEqual(rc, 0)
        self.assertTrue(record["safe_for_fresh_web_build"])
        self.assertEqual(record["original_checker"]["status"], "failed")
        self.assertEqual(record["unexpected_errors"], [])
        self.assertEqual(record["missing_expected_errors"], [])

    def test_unexpected_checker_error_refuses(self):
        p = self._payload()
        p["errors"].append("New missing source input: changed-source.cpp")
        rc, record = self._invoke(p)
        self.assertEqual(rc, 1)
        self.assertIn("New missing source input: changed-source.cpp", record["unexpected_errors"])

    def test_missing_expected_failure_refuses(self):
        p = self._payload()
        p["errors"].pop()
        rc, record = self._invoke(p)
        self.assertEqual(rc, 1)
        self.assertTrue(record["missing_expected_errors"])

    def test_unmaterialized_runtime_refuses(self):
        p = self._payload()
        p["materialized_runtime_files"].pop()
        p["unmaterialized_runtime_files"] = ["missing.so"]
        rc, record = self._invoke(p)
        self.assertEqual(rc, 1)
        self.assertEqual(record["current_lfs_count"], 17)

    def test_checker_success_requires_reassessment(self):
        rc, record = self._invoke(self._payload(), exitcode=0)
        self.assertEqual(rc, 1)
        self.assertEqual(record["status"], "refused")

    def test_documentation_error_scope_must_match(self):
        p = self._payload()
        p["documentation"]["errors"].append("Unexpected fixture path")
        rc, _ = self._invoke(p)
        self.assertEqual(rc, 1)

    def test_invalid_json_cannot_be_accepted(self):
        with TemporaryDirectory() as folder:
            root = Path(folder)
            output = root / "failed.json"
            with patch.object(reconcile.subprocess, "run", return_value=SimpleNamespace(
                returncode=1, stdout="{not json", stderr="parse-error")), \
                patch.object(reconcile.subprocess, "check_output", return_value="0" * 40):
                status = reconcile.run(root, output)
            self.assertEqual(status, 1)
            self.assertEqual(json.loads(output.read_text())["status"], "refused")


if __name__ == "__main__":
    unittest.main()
