"""Only a fresh exporter-owned, correctly identified temporary pack is removed."""
from pathlib import Path
import tempfile
import unittest
from tools.web.sandfall_export import remove_export_temporaries

HEADER = b"GDPC\x04\x00\x00\x00\x04\x00\x00\x00\x07\x00\x00\x00"


class ExportTemporaries(unittest.TestCase):
    def test_known_shadow_pack_removed_and_delivery_unchanged(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            data = HEADER + b"actual delivery pack"
            (root / "index.pck").write_bytes(data)
            (root / "index.pck-aB123x").write_bytes(HEADER + b"different temporary pack")
            (root / "index.js").write_text("actual engine")
            removed = remove_export_temporaries(root)
            self.assertEqual([row["path"] for row in removed], ["index.pck-aB123x"])
            self.assertEqual(len(removed[0]["sha256"]), 64)
            self.assertEqual((root / "index.pck").read_bytes(), data)
            self.assertEqual((root / "index.js").read_text(), "actual engine")
            self.assertEqual(remove_export_temporaries(root), [])

    def test_unrecognized_sibling_or_header_refuses_without_deletion(self):
        for name, data in (("index.pck-unknown", HEADER + b"pack"), ("index.pck-aB123x", b"unexpected")):
            with tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                (root / "index.pck").write_bytes(HEADER + b"delivery")
                suspect = root / name
                suspect.write_bytes(data)
                with self.assertRaises(RuntimeError):
                    remove_export_temporaries(root)
                self.assertEqual(suspect.read_bytes(), data)

    def test_symlink_refuses_and_preserves_target(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            target = root / "index.pck"
            target.write_bytes(HEADER + b"delivery")
            (root / "index.pck-aB123x").symlink_to(target)
            with self.assertRaises(RuntimeError):
                remove_export_temporaries(root)
            self.assertEqual(target.read_bytes(), HEADER + b"delivery")


if __name__ == "__main__":
    unittest.main()
