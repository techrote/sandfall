"""Ensure SF-M4's five real browser workloads never reuse a live Chrome CDP port.

This checks deterministic launch wiring. Actual Chrome/physics/browser receipt
qualification is mandatory in the dedicated workflow and is never substituted.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/sf-m4-web.yml"


class BrowserPortIsolationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = WORKFLOW.read_text(encoding="utf-8")
        cls.body = cls.source.split("for bodies in 0 1 3 8 16; do", 1)[1].split("done", 1)[0]

    def test_each_capacity_has_unique_port(self):
        self.assertIn("CDP_PORT=$((9231 + bodies))", self.body)
        ports = [9231 + bodies for bodies in (0, 1, 3, 8, 16)]
        self.assertEqual(len(set(ports)), 5)
        self.assertTrue(all(1 <= port <= 65535 for port in ports))

    def test_browser_launch_and_client_use_same_isolated_port(self):
        self.assertIn('--remote-debugging-address=127.0.0.1', self.body)
        self.assertIn('--remote-debugging-port="$CDP_PORT"', self.body)
        self.assertIn('--port "$CDP_PORT"', self.body)
        self.assertIn('echo "$CDP_PORT" > "$evidence/cdp-port.txt"', self.body)
        self.assertNotIn('--port 9231', self.body)
        self.assertNotIn('--remote-debugging-port=9231', self.body)

    def test_browser_is_retired_without_weakening_result(self):
        self.assertIn('kill "$CHROME_PID"', self.body)
        self.assertIn('wait "$CHROME_PID"', self.body)
        self.assertIn('failed=1', self.body)
        self.assertIn('--screenshot "$evidence/browser.png"', self.body)
        self.assertIn('--timeout-ms 540000', self.body)
        self.assertIn('for bodies in 0 1 3 8 16; do', self.source)


if __name__ == "__main__":
    unittest.main()
