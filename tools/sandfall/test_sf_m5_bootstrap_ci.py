"""Custody and real process-lifetime negatives; no simulated browser PASS."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

from tools.sandfall.sf_m5_bootstrap_ci import sha256, stop_group, verify_export


class BootstrapCustodyTests(unittest.TestCase):
    def test_verified_byte_objects_do_not_change_with_later_disk_responses(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            original = b"Original pinned PCK fixture"
            (root / "index.pck").write_bytes(original)
            manifest = f"{sha256(original)}  index.pck\n".encode()
            (root / "SHA256SUMS").write_bytes(manifest)
            receipt = {"status": "passed", "profile": "threaded", "manifest_sha256": sha256(manifest),
                       "artifacts": [{"path": "index.pck", "sha256": sha256(original), "size": len(original)}]}
            rows, frozen = verify_export(root, receipt)
            self.assertEqual(rows, receipt["artifacts"])
            changed = bytearray(original)
            changed[4] ^= 1
            (root / "index.pck").write_bytes(changed)
            self.assertEqual(frozen["index.pck"], original)
            self.assertEqual(frozen["SHA256SUMS"], manifest)
            with self.assertRaisesRegex(ValueError, "bytes differ from passed verifier"):
                verify_export(root, receipt)

    def test_shutdown_retires_child_after_controller_already_exited(self) -> None:
        # The child belongs only to this test's new process group. Its parent
        # exits first, reproducing the lifecycle that a poll()-guard misses.
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "child.json"
            script = "import pathlib,subprocess,sys,json; child=subprocess.Popen([sys.executable,'-c','import time; time.sleep(60)']); pathlib.Path(sys.argv[1]).write_text(json.dumps({'pid':child.pid}))"
            controller = subprocess.Popen([sys.executable, "-c", script, str(marker)], start_new_session=True)
            try:
                controller.wait(timeout=5)
                self.assertEqual(controller.returncode, 0)
                child_pid = json.loads(marker.read_text())["pid"]
                self.assertEqual(os.getpgid(child_pid), controller.pid)
                stop_group(controller)
                until = time.monotonic() + 5
                while time.monotonic() < until:
                    stat = Path(f"/proc/{child_pid}/stat")
                    if not stat.exists() or stat.read_text().split(")", 1)[1].split()[0] == "Z":
                        break
                    time.sleep(0.01)
                else:
                    self.fail("Owned child retained live CPU authority after controller-exit cleanup")
            finally:
                stop_group(controller)


if __name__ == "__main__":
    unittest.main()
