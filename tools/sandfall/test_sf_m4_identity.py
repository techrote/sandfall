"""SF-M4 build identity must identify real bytes without asserting qualification."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("sandfall_m4_build", Path(__file__).resolve().parents[1] / "build_web.py")
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


class ProjectBuildIdentityTests(unittest.TestCase):
    def test_staged_project_identity_measures_actual_native_and_pinned_rapier(self):
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            native = root / "fresh.wasm"
            native.write_bytes(b"\x00asmfresh-exact-source-bytes")
            args = argparse.Namespace(source_commit=None, profile="compat")
            with patch.object(BUILDER, "output", side_effect=["a" * 40, "b" * 40]), \
                    patch.object(BUILDER, "verify_rapier", return_value={"sha256": "c" * 64}) as rapier:
                value = BUILDER.write_sandfall_identity(root, native, args)
            self.assertEqual(value, json.loads((root / "sandfall_build_identity.json").read_text()))
            self.assertEqual(value["native_runtime_sha256"], hashlib.sha256(native.read_bytes()).hexdigest())
            self.assertEqual(value["native_source_commit"], value["source_commit"])
            self.assertEqual(value["source_tree"], "b" * 40)
            self.assertEqual(value["rapier_runtime_sha256"], "c" * 64)
            self.assertEqual(value["build_profile"], "compat")
            self.assertNotIn("qualified", json.dumps(value))
            rapier.assert_called_once_with(False)

    def test_unverified_rapier_cannot_publish_project_identity(self):
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            native = root / "fresh.wasm"
            native.write_bytes(b"\x00asmfresh")
            with patch.object(BUILDER, "output", return_value="a" * 40), \
                    patch.object(BUILDER, "verify_rapier", side_effect=RuntimeError("mismatched Rapier")):
                with self.assertRaisesRegex(RuntimeError, "mismatched Rapier"):
                    BUILDER.write_sandfall_identity(root, native, argparse.Namespace(source_commit=None, profile="compat"))
            self.assertFalse((root / "sandfall_build_identity.json").exists())


if __name__ == "__main__":
    unittest.main()
