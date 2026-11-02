"""Fail-closed custody comparisons; these fixtures do not qualify a browser."""
from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tools.sandfall import sf_m5_browser_ci as runner


def receipt(paths: list[str] | None = None) -> dict:
    return {"status": "passed", "build_source_commit": "a" * 40, "harness_source_commit": "b" * 40,
            "profile": "threaded", "manifest_sha256": "c" * 64,
            "artifacts": [{"path": "index.pck", "sha256": "d" * 64, "size": 123},
                          {"path": "libcybersand_native.web.threads.wasm", "sha256": "e" * 64, "size": 456}],
            "source_equivalence": {"committed_changed_paths": ["tools/sandfall/sf_m5_browser_ci.py"],
                                   "tracked_dirty_paths": [], "staged_changed_paths": [],
                                   "unstaged_changed_paths": [], "build_sensitive_changed_paths": [],
                                   "untracked_paths": paths or []}}


class BrowserCustodyTests(unittest.TestCase):
    def test_actual_git_evidence_inventory_can_grow_only_in_the_owned_subtree(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            (root / "previous-case.json").write_text("retained other case")
            owned = root / "evidence" / "case-1"
            owned.mkdir(parents=True, exist_ok=False)

            def observed():
                raw = subprocess.check_output(["git", "-C", str(root), "ls-files", "--others", "--exclude-standard", "-z"])
                return receipt(sorted(path.decode() for path in raw.split(b"\0") if path))

            before = observed()
            (owned / "browser.json").write_text("actual evidence output")
            (owned / "chrome-profile").mkdir()
            (owned / "chrome-profile" / "DevToolsActivePort").write_text("12345")
            after = observed()
            originals = deepcopy((before, after))
            comparison = runner.compare_verifications(before, after, root, owned)
            self.assertEqual((before, after), originals)
            self.assertEqual(comparison["owned_output_relative"], "evidence/case-1")
            self.assertEqual(comparison["owned_untracked_before"], [])
            self.assertEqual(len(comparison["owned_untracked_after"]), 2)
            self.assertTrue(comparison["all_other_verifier_fields_identical"])
            (root / "evidence" / "case-10.json").write_text("different owner")
            with self.assertRaisesRegex(RuntimeError, "outside this invocation"):
                runner.compare_verifications(before, observed(), root, owned)

    def test_outside_additions_and_removals_refuse(self):
        for paths in (["previous.json", "unrelated.py"], []):
            with self.subTest(paths=paths), self.assertRaisesRegex(RuntimeError, "outside this invocation"):
                runner.compare_verifications(receipt(["previous.json"]), receipt(paths), Path("/repo"), Path("/repo/evidence"))

    def test_manifest_pck_native_source_and_profile_changes_refuse(self):
        for key in ("manifest", "pck", "native", "head", "build", "profile", "committed"):
            before = receipt()
            after = deepcopy(before)
            if key == "manifest":
                after["manifest_sha256"] = "f" * 64
            elif key in ("pck", "native"):
                after["artifacts"][0 if key == "pck" else 1]["sha256"] = "f" * 64
            elif key in ("head", "build"):
                after["harness_source_commit" if key == "head" else "build_source_commit"] = "f" * 40
            elif key == "profile":
                after["profile"] = "compat"
            else:
                after["source_equivalence"]["committed_changed_paths"].append("tools/unexpected.py")
            with self.subTest(change=key), self.assertRaisesRegex(RuntimeError, "outside this invocation"):
                runner.compare_verifications(before, after, Path("/repo"), Path("/repo/evidence"))

    def test_dirty_tracked_harness_refuses_even_if_the_path_inventory_is_unchanged(self):
        for key in ("tracked_dirty_paths", "staged_changed_paths", "unstaged_changed_paths", "build_sensitive_changed_paths"):
            value = receipt()
            value["source_equivalence"][key] = ["tools/sandfall/sf_m5_browser_ci.py"]
            with self.subTest(field=key), self.assertRaisesRegex(RuntimeError, "clean tracked source"):
                runner.compare_verifications(value, deepcopy(value), Path("/repo"), Path("/repo/evidence"))

    def test_external_output_exempts_no_repository_path(self):
        with self.assertRaisesRegex(RuntimeError, "outside this invocation"):
            runner.compare_verifications(receipt(), receipt(["evidence/new.json"]), Path("/repo"), Path("/elsewhere/evidence"))
        with self.assertRaisesRegex(RuntimeError, "repository cannot"):
            runner.compare_verifications(receipt(), receipt(), Path("/repo"), Path("/repo"))

    def test_missing_or_failed_receipts_and_malformed_inventory_refuse(self):
        for value in ({}, {**receipt(), "status": "failed"},
                      {**receipt(), "source_equivalence": {}}):
            with self.subTest(value=value), self.assertRaises(RuntimeError):
                runner.compare_verifications(receipt(), value, Path("/repo"), Path("/repo/evidence"))
        value = receipt()
        value["source_equivalence"]["untracked_paths"] = "evidence/new.json"
        with self.assertRaisesRegex(RuntimeError, "Malformed untracked"):
            runner.compare_verifications(receipt(), value, Path("/repo"), Path("/repo/evidence"))

    def test_terminal_runtime_refusal_is_preserved_and_propagated(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "artifact-verification-after.json"
            with patch.object(runner, "verify", side_effect=ValueError("Export SHA256 mismatch: index.pck")):
                with self.assertRaisesRegex(ValueError, "Export SHA256 mismatch"):
                    runner.retain_post_verification(path, Path("/web"), Path("/repo"), "a" * 40, "threaded")
            retained = json.loads(path.read_text())
            self.assertEqual(retained["status"], "failed")
            self.assertEqual(retained["error"], "ValueError: Export SHA256 mismatch: index.pck")
            self.assertEqual(retained["build_source_commit"], "a" * 40)


if __name__ == "__main__":
    unittest.main()
