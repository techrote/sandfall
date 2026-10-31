"""Fail-closed synthetic checks for newly cross-built Windows DLL custody.

These tests prove the manifest contract, not actual Windows execution.
"""
import copy
from pathlib import Path
import subprocess
import tempfile
import unittest

from fresh_windows_runtime import build, verify, sha, DLL_NAME, native_inputs, bundle_manifest


class FreshWindowsRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repo"
        self.root.mkdir()
        path = self.root / "native/include/synthetic.hpp"
        path.parent.mkdir(parents=True)
        path.write_bytes(b"class Native {} ;\n")
        cpp = self.root / "native/src/synthetic.cpp"
        cpp.parent.mkdir(parents=True)
        cpp.write_bytes(b'#include "synthetic.hpp"\n')
        gd = self.root / "godot/native_extension/synthetic.cpp"
        gd.parent.mkdir(parents=True)
        gd.write_bytes(b"// extension\n")
        self.git("init", "-q")
        self.git("add", ".")
        self.git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                 "commit", "-qm", "source baseline")
        self.head = self.git("rev-parse", "HEAD").strip()
        self.dll = Path(self.temp.name) / "build.dll"
        self.dll.write_bytes(b"MZ\x90\x00fabricated-non-executable-test-bytes")
        self.bundle = Path(self.temp.name) / "bundle"
        self.manifest = build(self.root, self.dll, self.bundle)

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], text=True)

    def test_exact_head_full_native_inputs_pass(self):
        result = verify(self.root, self.bundle, self.head)
        self.assertEqual(result["runtime_build_commit"], self.head)
        self.assertEqual(result["cybersand_runtime"]["sha256"], sha(self.dll.read_bytes()))
        self.assertEqual(result["native_source_inputs"], native_inputs(self.root))
        self.assertEqual(len(result["native_source_inputs"]), 3)

    def test_changed_source_added_untracked_source_or_head_refuses(self):
        path = self.root / "native/src/synthetic.cpp"
        path.write_bytes(b"unreviewed edit")
        with self.assertRaises((ValueError, subprocess.CalledProcessError)):
            verify(self.root, self.bundle, self.head)
        path.write_bytes(b'#include "synthetic.hpp"\n')
        extra = self.root / "native/src/extra.cpp"
        extra.write_bytes(b"untracked")
        with self.assertRaises(ValueError):
            verify(self.root, self.bundle, self.head)
        extra.unlink()
        with self.assertRaises(ValueError):
            verify(self.root, self.bundle, "0" * 40)

    def test_manifest_digest_missing_file_or_extra_file_refuses(self):
        data = self.bundle / DLL_NAME
        data.write_bytes(data.read_bytes() + b"tampered")
        with self.assertRaises(ValueError):
            verify(self.root, self.bundle, self.head)
        data.write_bytes(self.dll.read_bytes())
        (self.bundle / "extra.txt").write_bytes(b"surprise")
        with self.assertRaises(ValueError):
            verify(self.root, self.bundle, self.head)
        (self.bundle / "extra.txt").unlink()
        (self.bundle / "manifest.json").unlink()
        with self.assertRaises(ValueError):
            verify(self.root, self.bundle, self.head)

    def test_manifest_tampering_and_pin_change_refuses(self):
        import json
        path = self.bundle / "manifest.json"
        original = json.loads(path.read_text())
        for key, value in (("source_tree", "f" * 40), ("godot_cpp_commit", "f" * 40),
                           ("artifact", "../changed.dll"), ("size", 2)):
            manifest = {**original, key: value}
            path.write_text(json.dumps(manifest))
            with self.assertRaises(ValueError):
                verify(self.root, self.bundle, self.head)
        path.write_text(json.dumps({**original, "unreviewed": True}))
        with self.assertRaises(ValueError):
            verify(self.root, self.bundle, self.head)

    def test_non_pe_candidate_refuses(self):
        self.dll.write_bytes(b"not a PE")
        with self.assertRaises(ValueError):
            bundle_manifest(self.root, self.dll)

    def test_bundle_writes_are_not_overwritten(self):
        with self.assertRaises(ValueError):
            build(self.root, self.dll, self.bundle)


if __name__ == "__main__":
    unittest.main()
