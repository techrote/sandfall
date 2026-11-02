"""Exact observation-delta and retained-refusal negatives; no execution claims."""
import copy
import unittest
from tools.sandfall import sf_m5_reconcile as r
from tools.sandfall.test_sf_m3_reconcile import Classification as OldFixture


class ObservationAdmission(unittest.TestCase):
    def payload(self):
        fixture = OldFixture()
        prior_checks = fixture.checks()
        prior_checks["exact_reviewed_native_delta"] = False
        return r.m3.classify(fixture.payload(), prior_checks)

    def checks(self):
        return {key: True for key in r.REQUIRED_CHECKS}

    def test_exact_delta_only_admits_fresh_build(self):
        result = r.classify(self.payload(), self.checks())
        self.assertTrue(result["safe_for_fresh_web_build"])
        self.assertEqual(result["original_m3_disposition"], "refused")
        self.assertEqual(result["expected_checker_error_count"], 20)

    def test_every_source_guard_is_strict(self):
        for key in self.checks():
            for value in (False, None, "true"):
                checks = self.checks(); checks[key] = value
                self.assertFalse(r.classify(self.payload(), checks)["safe_for_fresh_web_build"], key)

    def test_additional_old_error_or_weakened_guard_refuses(self):
        for key in r.REQUIRED_CHECKS:
            original = self.payload()
            original["source_checks"][key] = key == "exact_reviewed_native_delta"
            self.assertFalse(r.classify(original, self.checks())["safe_for_fresh_web_build"])
        original = self.payload()
        original["original_m2_reconciliation"]["original_checker"]["errors"].append("new runtime failure")
        self.assertFalse(r.classify(original, self.checks())["safe_for_fresh_web_build"])

    def test_any_new_native_byte_file_or_patch_refuses(self):
        before, after = r.REVIEWED_BASE_SHA256, r.REVIEWED_NATIVE_SHA256
        self.assertTrue(r.approved_native_delta(before, after, sorted(after), r.REVIEWED_NATIVE_PATCH_SHA256))
        changed = copy.deepcopy(after); changed[next(iter(changed))] = "0" * 64
        self.assertFalse(r.approved_native_delta(before, changed, sorted(after), r.REVIEWED_NATIVE_PATCH_SHA256))
        self.assertFalse(r.approved_native_delta(before, after, sorted(after) + ["native/src/new.cpp"], r.REVIEWED_NATIVE_PATCH_SHA256))
        self.assertFalse(r.approved_native_delta(before, after, sorted(after), "0" * 64))


if __name__ == "__main__":
    unittest.main()
