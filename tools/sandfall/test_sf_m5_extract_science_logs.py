"""Extraction preserves every byte in selected command blocks, including errors."""
from pathlib import Path
import tempfile
import unittest
try:
    from sf_m5_extract_science_logs import NAMES, extract
    from sf_m5_science_report import read_receipts
except ModuleNotFoundError:
    from tools.sandfall.sf_m5_extract_science_logs import NAMES, extract
    from tools.sandfall.sf_m5_science_report import read_receipts


class WholeCommandBlocks(unittest.TestCase):
    def fixture(self, error=b""):
        return b"compiler output\n" + b"".join(
            b"+ /pinned/godot --headless --path /stage --script res://tests/test_sandfall_" + name.encode()
            + b".gd\noriginal whole suite output\n" + error for name in sorted(NAMES))

    def test_full_blocks_and_unrelated_archive_diagnostics_are_retained_separately(self):
        source = self.fixture() + b"+ /pinned/godot --headless --script res://tests/test_sandfall_archive.gd\nERROR: expected archive diagnostic\n"
        blocks = extract(source)
        self.assertEqual(set(blocks), NAMES)
        self.assertTrue(all(b"original whole suite output\n" in value for value in blocks.values()))
        self.assertIn(b"ERROR: expected archive diagnostic", source)

    def test_missing_and_duplicate_suite_commands_refuse(self):
        with self.assertRaisesRegex(ValueError, "Incomplete"):
            extract(b"no actual Godot invocation")
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            extract(self.fixture() + self.fixture())

    def test_selected_errors_survive_and_fail_the_scientific_reducer(self):
        for error in (b"ERROR: genuine engine failure\n", b"SCRIPT ERROR: genuine script failure\n"):
            block = extract(self.fixture(error))["scientific"]
            self.assertIn(error, block)
            with tempfile.TemporaryDirectory() as folder:
                path = Path(folder) / "scientific.log"
                path.write_bytes(block)
                with self.assertRaisesRegex(ValueError, "engine/script failure"):
                    read_receipts([path])


if __name__ == "__main__":
    unittest.main()
