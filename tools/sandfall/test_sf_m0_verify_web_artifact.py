"""Artifact/source drift refusals using small synthetic exports and real Git diffs."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory
import unittest

from tools.sandfall import sf_m0_verify_web_artifact as verifier


class WebArtifactVerificationTests(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repo"
        self.root.mkdir()
        self.web = Path(self.temp.name) / "export"
        self.web.mkdir()
        self.git("init", "-q")
        self.git("config", "user.email", "test@example.invalid")
        self.git("config", "user.name", "Artifact verifier tests")
        self.write("godot/project.godot", '''[display]
window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/window_width_override=1920
window/size/window_height_override=1080
window/stretch/mode="canvas_items"
''')
        self.write("tools/build_web.py", '''def stage_project():
    project = "unused"
    project = project.replace("viewport_width=1920", "viewport_width=1280")
    project = project.replace("viewport_height=1080", "viewport_height=800")
    project = project.replace("window_width_override=1920", "window_width_override=1280")
    project = project.replace("window_height_override=1080", "window_height_override=800")
''')
        self.write("godot/export_presets.cfg", '''[preset.0.options]
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
''')
        self.write("tools/web/build_profile.json", '{"enabled_classes": []}\n')
        self.write("tools/requirements-build.txt", "SCons==4.10.1\n")
        self.write("README.md", "Fixture\n")
        wasm = b"\x00asm\x01\x00\x00\x00"
        digest = hashlib.sha256(wasm).hexdigest()
        self.write("godot/third_party/rapier2d.lock.json", json.dumps({
            "web_libraries": {"compat": {"sha256": digest}},
        }))
        self.commit("source fixture")
        self.source = self.git("rev-parse", "HEAD")
        for name in verifier.REQUIRED_EXPORTS:
            (self.web / name).write_bytes(wasm if name.endswith(".wasm") else b"fixture\n")
        (self.web / "libcybersand_native.web.nothreads.wasm").write_bytes(wasm)
        self.info = dict(verifier.PINS, source_commit=self.source,
                         source_identity_kind="git-checkout", rapier_sha256=digest,
                         water_runtime={"source_commit": self.source, "profile": "compat",
                                        "artifact": "libcybersand_native.web.nothreads.wasm",
                                        "sha256": digest, "size": len(wasm)})
        self.refresh()

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], text=True,
                                       stderr=subprocess.PIPE).strip()

    def write(self, path, text):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)

    def commit(self, message):
        self.git("add", ".")
        self.git("commit", "-qm", message)

    def refresh(self):
        (self.web / "build-info.json").write_text(json.dumps(self.info))
        (self.web / "SHA256SUMS").write_text("".join(
            hashlib.sha256(p.read_bytes()).hexdigest() + "  " + p.name + "\n"
            for p in sorted(self.web.iterdir()) if p.name != "SHA256SUMS"))

    def verify(self):
        return verifier.verify(self.web, self.root, self.source)

    def test_valid_bytes_keep_original_build_sha_after_harness_commit(self):
        self.write("tools/sandfall/harness.mjs", "// New harness only\n")
        self.commit("test harness")
        receipt = self.verify()
        self.assertEqual(receipt["status"], "passed")
        self.assertEqual(receipt["build_source_commit"], self.source)
        self.assertNotEqual(receipt["harness_source_commit"], self.source)
        self.assertEqual(receipt["logical_viewport"]["width"], 1280)
        self.assertEqual(receipt["logical_viewport"]["height"], 800)
        self.assertEqual(receipt["logical_viewport"]["stretch_aspect"], "keep")
        self.assertEqual(len(receipt["artifacts"]), len(verifier.REQUIRED_EXPORTS) + 1)

    def test_corrupt_runtime_bytes_refuse(self):
        (self.web / "index.wasm").write_bytes(b"\x00asmcorrupt")
        with self.assertRaisesRegex(verifier.VerificationError, "SHA256 mismatch"):
            self.verify()

    def test_missing_or_unlisted_export_refuses(self):
        (self.web / "unlisted.js").write_text("extra")
        with self.assertRaisesRegex(verifier.VerificationError, "complete export file inventory"):
            self.verify()
        (self.web / "unlisted.js").unlink()
        (self.web / "index.pck").unlink()
        with self.assertRaisesRegex(verifier.VerificationError, "complete export file inventory"):
            self.verify()

    def test_duplicate_or_traversing_manifest_refuses(self):
        manifest = self.web / "SHA256SUMS"
        original = manifest.read_text()
        manifest.write_text(original + original.splitlines()[0] + "\n")
        with self.assertRaisesRegex(verifier.VerificationError, "Duplicate"):
            self.verify()
        manifest.write_text(original + "0" * 64 + "  ../elsewhere\n")
        with self.assertRaisesRegex(verifier.VerificationError, "Invalid export manifest path"):
            self.verify()

    def test_wrong_source_or_profile_refuses_despite_rehashed_manifest(self):
        self.info["source_commit"] = "0" * 40
        self.refresh()
        with self.assertRaisesRegex(verifier.VerificationError, "source SHA mismatch"):
            self.verify()
        self.info["source_commit"] = self.source
        self.info["profile"] = "threaded"
        self.refresh()
        with self.assertRaisesRegex(verifier.VerificationError, "profile pin mismatch"):
            self.verify()

    def test_rehashed_wrong_rapier_refuses_source_lock(self):
        payload = b"\x00asmchanged"
        (self.web / "godot_rapier.wasm").write_bytes(payload)
        self.info["rapier_sha256"] = hashlib.sha256(payload).hexdigest()
        self.refresh()
        with self.assertRaisesRegex(verifier.VerificationError, "pinned source lock"):
            self.verify()

    def test_native_receipt_cannot_name_base_engine_instead_of_side_module(self):
        self.info["water_runtime"]["artifact"] = "index.wasm"
        self.refresh()
        with self.assertRaisesRegex(verifier.VerificationError, "artifact name differs"):
            self.verify()

    def test_malformed_receipt_shapes_refuse_with_validation_error(self):
        original = self.info
        self.info = []
        self.refresh()
        with self.assertRaisesRegex(verifier.VerificationError, "build-info must be a JSON object"):
            self.verify()
        self.info = dict(original, water_runtime=[])
        self.refresh()
        with self.assertRaisesRegex(verifier.VerificationError, "runtime receipt must be a JSON object"):
            self.verify()

    def test_committed_build_profile_change_refuses(self):
        self.write("tools/web/build_profile.json", '{"enabled_classes":["NewClass"]}\n')
        self.commit("changed build profile")
        with self.assertRaisesRegex(verifier.VerificationError, "Build-sensitive source drift.*build_profile"):
            self.verify()

    def test_unstaged_and_staged_build_inputs_refuse_even_if_head_matches(self):
        self.write("tools/requirements-build.txt", "SCons==different\n")
        with self.assertRaisesRegex(verifier.VerificationError, "Build-sensitive source drift"):
            self.verify()

        self.git("add", "tools/requirements-build.txt")
        # Restore the worktree bytes while leaving the index changed: the
        # combined HEAD->worktree diff alone would miss this staged input.
        self.write("tools/requirements-build.txt", "SCons==4.10.1\n")
        with self.assertRaisesRegex(verifier.VerificationError, "Build-sensitive source drift"):
            self.verify()

    def test_untracked_godot_source_copied_by_builder_refuses(self):
        self.write("godot/new_source.gd", "extends Node\n")
        with self.assertRaisesRegex(verifier.VerificationError, "Build-sensitive source drift.*new_source"):
            self.verify()

    def test_export_symlink_refuses(self):
        target = self.web / "index.js"
        target.unlink()
        target.symlink_to(self.root / "README.md")
        with self.assertRaisesRegex(verifier.VerificationError, "Unexpected export entry"):
            self.verify()

    def test_wrong_source_bound_layout_refuses(self):
        self.write("godot/project.godot", (self.root / "godot/project.godot").read_text()
                   + 'window/stretch/aspect="expand"\n')
        self.commit("different layout")
        with self.assertRaisesRegex(verifier.VerificationError, "qualified 1280x800"):
            verifier.logical_viewport(self.root, self.git("rev-parse", "HEAD"))


if __name__ == "__main__":
    unittest.main()
