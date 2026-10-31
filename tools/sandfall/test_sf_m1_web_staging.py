"""Verify dedicated/legacy entry separation and refusal of inherited native bytes."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("sandfall_build_web", Path(__file__).resolve().parents[1] / "build_web.py")
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


class SandfallStagingTests(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.project = self.root / "godot/project.godot"
        self.project.parent.mkdir()
        self.source = '[application]\nrun/main_scene="res://sandfall_main.tscn"\n[cybersand]\nnative_worker_threads=0\n'
        self.project.write_text(self.source)
        (self.project.parent / "sandfall_main.tscn").write_text('[gd_scene format=3]\n')
        (self.project.parent / "web_main.tscn").write_text('[gd_scene format=3]\n')
        self.binaries = self.root / "godot/addons/cybersand_native/bin"
        self.binaries.mkdir(parents=True)
        (self.binaries / "stale-linux.so").write_bytes(b"inherited-unqualified")
        (self.binaries / "stale-windows.dll").write_bytes(b"inherited-unqualified")
        (self.root / "godot/addons/godot-rapier2d").mkdir()
        self.wasm = self.root / "libcybersand_native.web.nothreads.wasm"
        self.wasm.write_bytes(b"\x00asmfresh-web")
        self.native = self.root / "libcybersand_native.linux.x86_64.so"
        self.native.write_bytes(b"\x7fELFfresh-native")

    def stage(self, entry):
        with patch.object(BUILDER, "ROOT", self.root):
            return BUILDER.stage_project(self.wasm, self.native, True, False, entry)

    def test_dedicated_stage_contains_only_supplied_native_artifacts(self):
        stage = self.stage("sandfall")
        binaries = stage / "addons/cybersand_native/bin"
        self.assertEqual({p.name for p in binaries.iterdir()}, {self.wasm.name, self.native.name})
        self.assertEqual((binaries / self.native.name).read_bytes(), self.native.read_bytes())
        self.assertIn('run/main_scene="res://sandfall_main.tscn"', (stage / "project.godot").read_text())
        self.assertEqual(self.project.read_text(), self.source)
        self.assertEqual((self.binaries / "stale-linux.so").read_bytes(), b"inherited-unqualified")

    def test_legacy_export_remains_explicit_and_isolated_from_new_stage(self):
        dedicated = self.stage("sandfall")
        legacy = self.stage("legacy")
        self.assertNotEqual(dedicated, legacy)
        self.assertTrue(dedicated.is_dir())
        self.assertIn('run/main_scene="res://web_main.tscn"', (legacy / "project.godot").read_text())

    def test_unknown_or_missing_new_entry_is_refused(self):
        with self.assertRaisesRegex(RuntimeError, "Unknown Web application entry"):
            self.stage("other")
        (self.project.parent / "sandfall_main.tscn").unlink()
        with self.assertRaisesRegex(RuntimeError, "Unexpected project main-scene"):
            self.stage("sandfall")

    def test_runtime_identity_names_actual_application_without_claiming_browser_pass(self):
        stage = self.stage("sandfall")
        args = argparse.Namespace(source_commit="a" * 40, profile="compat", entry="sandfall")
        identity = BUILDER.write_runtime_identity(stage, self.wasm, args)
        self.assertEqual(identity["application_entry"], "sandfall")
        self.assertEqual(identity["entry_scene"], "res://sandfall_main.tscn")
        self.assertEqual(identity["sha256"], hashlib.sha256(self.wasm.read_bytes()).hexdigest())
        self.assertEqual(identity["browser_execution_status"], "not-established-by-export")
        self.assertEqual(identity, json.loads((stage / "addons/cybersand_native/runtime-provenance.web.json").read_text()))


if __name__ == "__main__":
    unittest.main()
