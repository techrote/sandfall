"""Regression checks for the generic SF-M0 -> SF-M2 -> SF-M3 provenance dispatcher.

These are wiring tests, not a substitute for the source-pinned runtime gate.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/documentation.yml"


class DocumentationDispatcher(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workflow = WORKFLOW.read_text(encoding="utf-8")

    def test_latest_source_pinned_gate_is_selected_first(self):
        block = self.workflow.split("Retain original checker refusals and admit only an exact reviewed milestone delta", 1)[1]
        branches = (
            "if test -f tools/sandfall/sf_m3_reconcile.py; then",
            "elif test -f tools/sandfall/sf_m2_reconcile.py; then",
            "else\n            python3 tools/sandfall/sf_m0_reconcile.py",
        )
        offsets = [block.index(branch) for branch in branches]
        self.assertEqual(offsets, sorted(offsets))
        for name in ("sf_m3_reconcile.py", "sf_m2_reconcile.py", "sf_m0_reconcile.py"):
            self.assertIn(f"python3 tools/sandfall/{name} --output", block)

    def test_m3_requires_original_refusals_and_exact_native_delta(self):
        for item in (
            "record['schema']=='sandfall-sf-m3-fresh-build-reconciliation-v1'",
            "record['expected_checker_error_count']==20",
            "record['original_m0_disposition']=='refused'",
            "record['original_m2_disposition']=='refused'",
            "old['safe_for_fresh_web_build'] is False",
            "no_untracked_native_sources",
            "exact_reviewed_native_delta",
            "unchanged_runtime_payloads_manifests_and_pins",
            "unchanged_inherited_gates",
            "record['native_patch_record']['sha256']==checks['native_patch_sha256']",
            "assert not record['unexpected_errors'] and not record['missing_expected_errors']",
        ):
            with self.subTest(condition=item):
                self.assertIn(item, self.workflow)

    def test_original_doc_and_lfs_controls_are_retained(self):
        self.assertIn("python3 tools/ci/check_ci_provider_policy.py", self.workflow)
        self.assertIn("git lfs checkout", self.workflow)
        self.assertIn("record['current_lfs_count']==18", self.workflow)
        self.assertIn("len(original['documentation']['errors'])==6", self.workflow)
        self.assertIn("assert original['status']=='failed'", self.workflow)
        self.assertIn("original['errors'])==(16 if sf_m2 else 14)", self.workflow)


if __name__ == "__main__":
    unittest.main()
