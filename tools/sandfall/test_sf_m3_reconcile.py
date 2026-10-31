"""Fail-closed gate negatives. Synthetic Git fixtures are not physics evidence."""
from __future__ import annotations

import copy
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tools.sandfall import sf_m3_reconcile as r
from tools.sandfall import sf_m0_native_smoke as old_smoke
from tools.sandfall import sf_m3_native_smoke as new_smoke


class Classification(unittest.TestCase):
    def payload(self):
        return {"checker_exit": 1, "status": "refused", "safe_for_fresh_web_build": False,
                "original_m0_disposition": "refused", "current_lfs_count": 18,
                "source_checks": {"exact_registration_delta": True,
                                  "unchanged_runtime_payloads_and_manifests": True,
                                  "unchanged_native_core": False},
                "original_checker": {"status": "failed", "errors": sorted(r.EXPECTED),
                                     "documentation": {"errors": sorted(r.m2.m0.EXPECTED_DOC_ERRORS)},
                                     "unmaterialized_runtime_files": []}}

    def checks(self):
        return {key: True for key in ("exact_baseline_tree", "baseline_is_ancestor",
                "no_untracked_native_sources", "exact_reviewed_native_delta",
                "unchanged_runtime_payloads_manifests_and_pins", "unchanged_inherited_gates")}

    def test_positive_keeps_original_m0_and_m2_refusals_and_records(self):
        original = self.payload()
        result = r.classify(original, self.checks())
        self.assertTrue(result["safe_for_fresh_web_build"])
        self.assertEqual(result["original_m2_reconciliation"], original)
        self.assertEqual(result["original_m0_disposition"], "refused")
        self.assertEqual(result["original_m2_disposition"], "refused")
        self.assertEqual(len(r.EXPECTED), 20)
        self.assertFalse(r.m2.classify(original, original["source_checks"])["safe_for_fresh_web_build"])

    def test_unknown_missing_duplicate_or_relabelled_errors_refuse(self):
        for mutation in (lambda e: e.append("new corruption"), lambda e: e.pop(),
                         lambda e: e.append(e[0]), lambda e: e.__setitem__(0, "claimed pass")):
            value = self.payload()
            mutation(value["original_checker"]["errors"])
            self.assertFalse(r.classify(value, self.checks())["safe_for_fresh_web_build"])

    def test_every_source_gate_is_required(self):
        for key in self.checks():
            for value in (False, None, "true"):
                checks = self.checks()
                checks[key] = value
                self.assertFalse(r.classify(self.payload(), checks)["safe_for_fresh_web_build"], key)

    def test_altered_original_gate_disposition_or_flags_refuse(self):
        for key, value in (("checker_exit", 0), ("status", "passed"),
                           ("original_m0_disposition", "passed"),
                           ("safe_for_fresh_web_build", True), ("current_lfs_count", 17)):
            original = self.payload()
            original[key] = value
            self.assertFalse(r.classify(original, self.checks())["safe_for_fresh_web_build"])
        for key in self.payload()["source_checks"]:
            original = self.payload()
            original["source_checks"][key] = not original["source_checks"][key]
            self.assertFalse(r.classify(original, self.checks())["safe_for_fresh_web_build"])

    def test_unmaterialized_or_altered_documentation_refuse(self):
        for field, value in (("unmaterialized_runtime_files", ["missing.wasm"]),
                             ("documentation", {"errors": []}), ("status", "passed")):
            original = self.payload()
            original["original_checker"][field] = value
            self.assertFalse(r.classify(original, self.checks())["safe_for_fresh_web_build"])

    def test_native_filters_and_success_markers_remain_exact(self):
        self.assertEqual(new_smoke.FILTERS, old_smoke.FILTERS)
        self.assertEqual(new_smoke.BINARIES, old_smoke.BINARIES)
        self.assertEqual(sum(len(row[2]) for row in new_smoke.FILTERS), 12)

    def test_reviewed_pins_require_exact_files_bytes_and_patch(self):
        self.assertTrue(r.REVIEWED_NATIVE_SHA256, "Native delta has not yet been independently reviewed/pinned")
        before = copy.deepcopy(r.REVIEWED_BASE_SHA256)
        after = copy.deepcopy(r.REVIEWED_NATIVE_SHA256)
        names = sorted(after)
        self.assertTrue(r.approved_native_delta(before, after, names, r.REVIEWED_NATIVE_PATCH_SHA256))
        for kind in ("baseline", "current", "extra", "missing", "duplicate", "patch"):
            b, a, n, p = copy.deepcopy(before), copy.deepcopy(after), names[:], r.REVIEWED_NATIVE_PATCH_SHA256
            if kind == "baseline": b[n[0]] = "0" * 64
            if kind == "current": a[n[0]] = "0" * 64
            if kind == "extra": n.append("native/src/unreviewed.cpp")
            if kind == "missing": n.pop()
            if kind == "duplicate": n.append(n[0])
            if kind == "patch": p = "0" * 64
            self.assertFalse(r.approved_native_delta(b, a, n, p), kind)


class SyntheticSourceIdentity(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.path = "native/src/world_pressure.inc"
        self.write(self.path, b"before\n")
        self.write("Makefile", b"# unchanged build\n")
        self.write(".gitignore", b"native/ignored.cpp\n")
        self.runtime = "godot/addons/cybersand_native/runtime-provenance.json"
        self.write(self.runtime, b'{"fixture":true}\n')
        for name in r.INHERITED_GATES:
            self.write(name, b"# unchanged synthetic gate\n")
        self.git("init", "-q")
        self.git("add", ".")
        self.git("-c", "user.name=Sandfall fixture", "-c", "user.email=fixture@example.invalid", "commit", "-qm", "synthetic baseline")
        base = self.git("rev-parse", "HEAD").decode().strip()
        tree = self.git("rev-parse", "HEAD^{tree}").decode().strip()
        self.write(self.path, b"reviewed after\n")
        self.git("add", self.path)
        self.git("-c", "user.name=Sandfall fixture", "-c", "user.email=fixture@example.invalid", "commit", "-qm", "synthetic reviewed delta")
        delta = self.git("diff", "--no-ext-diff", "--no-textconv", "--no-color", "--no-renames",
                         "--binary", "--full-index", "--unified=3", "--src-prefix=a/", "--dst-prefix=b/",
                         base, "--", *r.NATIVE_SCOPES)
        mocked = patch.multiple(r, BASE=base, BASE_TREE=tree,
                               REVIEWED_BASE_SHA256={self.path: r.digest(b"before\n")},
                               REVIEWED_NATIVE_SHA256={self.path: r.digest(b"reviewed after\n")},
                               REVIEWED_NATIVE_PATCH_SHA256=r.digest(delta))
        mocked.start()
        self.addCleanup(mocked.stop)

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], stderr=subprocess.PIPE)

    def write(self, name, data):
        destination = self.root / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)

    def test_exact_synthetic_reviewed_source_passes_identity_checks(self):
        checks, delta = r.source_identity(self.root)
        self.assertEqual(checks["native_patch_sha256"], r.digest(delta))
        for key in Classification().checks():
            self.assertIs(checks[key], True, key)

    def test_unreviewed_native_byte_or_build_file_change_refuses(self):
        self.write(self.path, b"unreviewed after\n")
        checks, _ = r.source_identity(self.root)
        self.assertFalse(checks["exact_reviewed_native_delta"])
        self.write(self.path, b"reviewed after\n")
        self.write("Makefile", b"# unreviewed build change\n")
        checks, _ = r.source_identity(self.root)
        self.assertFalse(checks["exact_reviewed_native_delta"])

    def test_untracked_and_gitignored_native_sources_cannot_evade_patch(self):
        self.write("native/extra.cpp", b"unreviewed\n")
        checks, _ = r.source_identity(self.root)
        self.assertFalse(checks["no_untracked_native_sources"])
        (self.root / "native/extra.cpp").unlink()
        self.write("native/ignored.cpp", b"unreviewed ignored\n")
        checks, _ = r.source_identity(self.root)
        self.assertFalse(checks["no_untracked_native_sources"])
        self.assertEqual(checks["ignored_native_source_paths"], ["native/ignored.cpp"])

    def test_runtime_manifest_or_inherited_gate_edit_refuses(self):
        self.write(self.runtime, b'{"reattested":true}\n')
        checks, _ = r.source_identity(self.root)
        self.assertFalse(checks["unchanged_runtime_payloads_manifests_and_pins"])
        self.write(r.INHERITED_GATES[0], b"# silently weakened\n")
        checks, _ = r.source_identity(self.root)
        self.assertFalse(checks["unchanged_inherited_gates"])

    def test_wrong_baseline_tree_refuses(self):
        with patch.object(r, "BASE_TREE", "0" * 40):
            checks, _ = r.source_identity(self.root)
            self.assertFalse(checks["exact_baseline_tree"])


if __name__ == "__main__":
    unittest.main()
