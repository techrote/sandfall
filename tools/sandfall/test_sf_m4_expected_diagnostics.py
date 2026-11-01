import copy
import json
import unittest

try:
    from sf_m4_expected_diagnostics import validate, BEGIN, END, CASES
except ModuleNotFoundError:
    from tools.sandfall.sf_m4_expected_diagnostics import validate, BEGIN, END, CASES


class ExpectedInflaterDiagnosticTests(unittest.TestCase):
    def output(self, *, begin=None, end=None, diagnostic="ERROR: Decompression failed."):
        b = {"case": "external_crc", "fixture_sha256": "a" * 64}
        e = {**b, "refused": True, "error": "zip_decompression_size_or_crc", "input_unchanged": True, "retained_candidate_unchanged": True}
        b.update(begin or {})
        e.update(end or {})
        return "\n".join([BEGIN + json.dumps(b), diagnostic, END + json.dumps(e),
            'SF_M4_INTEROP_RESULT {"checks":76,"failures":[],"status":"passed"}'])

    def test_precise_witnessed_refusal_is_retained(self):
        result = validate(self.output(), "test_sandfall_archive_interop.gd")
        self.assertEqual(result[0]["diagnostics"], ["ERROR: Decompression failed."])
        self.assertEqual(result[0]["fixture_sha256"], "a" * 64)

    def test_other_errors_are_never_hidden(self):
        for diagnostic in ["ERROR: Other failure", "SCRIPT ERROR: Parse Error", "ERROR: Decompression failed.\nERROR: Decompression failed."]:
            with self.subTest(diagnostic=diagnostic), self.assertRaises(ValueError):
                validate(self.output(diagnostic=diagnostic), "test_sandfall_archive_interop.gd")
        with self.assertRaises(ValueError):
            validate(self.output() + "\nERROR: Decompression failed.", "test_sandfall_archive_interop.gd")
        with self.assertRaises(ValueError):
            validate(self.output(), "test_sandfall_session.gd")

    def test_only_successful_bounded_known_refusal_qualifies(self):
        for end in [{"refused": False}, {"input_unchanged": False}, {"retained_candidate_unchanged": False},
                    {"error": "other"}, {"fixture_sha256": "b" * 64}, {"case": "not-a-registered-negative"}]:
            with self.subTest(end=end), self.assertRaises(ValueError):
                validate(self.output(end=end), "test_sandfall_archive_interop.gd")
        for output in [self.output().split(END)[0], self.output().replace('"failures":[]', '"failures":["refusal failed"]'),
                       self.output().replace('"status":"passed"', '"status":"failed"')]:
            with self.assertRaises(ValueError):
                validate(output, "test_sandfall_archive_interop.gd")

    def test_archive_suite_requires_explicit_passing_verdict(self):
        script = "test_sandfall_archive.gd"
        sections = []
        for case in sorted(CASES[script]):
            sections.append(self.output().split("SF_M4_INTEROP_RESULT ")[0].replace("external_crc", case))
        prefix = "\n".join(sections) + "\nSANDFALL_ARCHIVE_TEST "
        passed = {"checks": 175, "failures": [], "ok": True}
        self.assertEqual(len(validate(prefix + json.dumps(passed), script)), 4)
        for verdict in [False, None, 1, "true"]:
            with self.subTest(verdict=verdict), self.assertRaises(ValueError):
                validate(prefix + json.dumps({**passed, "ok": verdict}), script)
        del passed["ok"]
        with self.assertRaises(ValueError):
            validate(prefix + json.dumps(passed), script)


if __name__ == "__main__":
    unittest.main()
