"""Custody and real process-lifetime negatives; no simulated browser PASS."""
from __future__ import annotations

import json
import os
from pathlib import Path
import selectors
import subprocess
import sys
import tempfile
import unittest

from tools.sandfall.sf_m5_bootstrap_ci import read_cdp_port as bootstrap_cdp_port, sha256, stop_group, verify_export
from tools.sandfall.sf_m5_browser_ci import read_cdp_port as browser_cdp_port


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
            # A uniquely inherited pipe remains open while the real descendant
            # is alive. Unlike /proc/<pid>, this evidence cannot accidentally
            # refer to a host PID when execution uses a different PID namespace.
            controller = subprocess.Popen([sys.executable, "-c", script, str(marker)],
                                          stdout=subprocess.PIPE, start_new_session=True)
            try:
                controller.wait(timeout=5)
                self.assertEqual(controller.returncode, 0)
                child_pid = json.loads(marker.read_text())["pid"]
                self.assertEqual(os.getpgid(child_pid), controller.pid)
                stop_group(controller)
                with selectors.DefaultSelector() as selector:
                    selector.register(controller.stdout, selectors.EVENT_READ)
                    self.assertTrue(selector.select(timeout=5),
                                    "Owned child retained its live pipe after controller-exit cleanup")
                    self.assertEqual(controller.stdout.read(1), b"",
                                     "Owned descendant did not close its inherited pipe")
            finally:
                stop_group(controller)
                controller.stdout.close()



class ChromiumActivePortReadinessTests(unittest.TestCase):
    def test_incomplete_or_invalid_publication_is_not_a_cdp_port(self) -> None:
        # Chromium can create the file before writing its first line; both M5
        # launchers must wait instead of raising IndexError or using a partial port.
        cases = (
            ("", None),
            ("23456", None),
            ("23456\n", None),
            ("23456\n/devtools/browser/", None),
            ("not-a-port\n/devtools/browser/ready", None),
            ("0\n/devtools/browser/ready", None),
            ("65536\n/devtools/browser/ready", None),
            ("23456\n/devtools/other/ready", None),
            ("23456\n/devtools/browser/ready", 23456),
            ("23456\n/devtools/browser/ready\n", 23456),
        )
        for read_port in (bootstrap_cdp_port, browser_cdp_port):
            with self.subTest(reader=read_port.__module__):
                with tempfile.TemporaryDirectory() as directory:
                    path = Path(directory) / "DevToolsActivePort"
                    self.assertIsNone(read_port(path))  # Not yet created.
                    for contents, expected in cases:
                        path.write_text(contents)
                        self.assertEqual(read_port(path), expected, contents)
                    path.unlink()
                    self.assertIsNone(read_port(path))  # Removed while polling.

if __name__ == "__main__":
    unittest.main()
