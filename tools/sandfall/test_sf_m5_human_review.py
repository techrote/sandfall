"""Synthetic validator fixtures only: no browser run or human verdict is supplied."""
import copy
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
import tempfile
import unittest
from unittest.mock import patch
import zlib

from tools.sandfall import sf_m5_human_review as h
from tools.sandfall import sf_m5_human_packet as packet


def png() -> bytes:
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"\x00\xff\xff\xff")) + chunk(b"IEND", b""))


class HumanRecordContract(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        self.record = h.template()
        source, tree = "a" * 40, "b" * 40
        self.record.update(status="submitted", decision="accept", overall_notes="SYNTHETIC validator fixture only.",
            reviewer={"kind": "human", "mode": "live-browser", "name": "SYNTHETIC REVIEWER — NO REAL VERDICT",
                      "reviewed_at": "2026-11-01T12:00:00Z"},
            environment={"url": "http://127.0.0.1:8040/?test=1", "browser_product": "Synthetic/1",
                         "user_agent": "Synthetic parser fixture", "platform": "Synthetic", "viewport": {"width": 800, "height": 450, "dpr": 1},
                         "workers_requested": "auto", "workers_configured": 1})
        self.artifacts = []
        for name in ["index.html", "index.js", "index.wasm", "index.side.wasm", "index.pck", "godot_rapier.wasm",
                     "libcybersand_native.web.nothreads.wasm"]:
            ref = self.write("candidate/" + name, ("SYNTHETIC ONLY " + name).encode())
            self.artifacts.append({"path": name, "sha256": ref["sha256"], "size": ref["bytes"]})
        self.identity = {"source_commit": source, "native_source_commit": source, "source_tree": tree, "build_profile": "compat",
                         "native_runtime_sha256": self.artifacts[-1]["sha256"], "rapier_runtime_sha256": self.artifacts[-2]["sha256"]}
        contract = {"schema": "sandfall-web-startup-v1", "source_commit": source, "profile": "compat",
                    "assets": [row for row in self.artifacts if Path(row["path"]).suffix in {".wasm", ".pck", ".js"}]}
        for name, data in [("startup-contract.json", json.dumps(contract).encode()),
                           ("Caddyfile.example", b"Synthetic hosting example")]:
            ref = self.write("candidate/" + name, data)
            self.artifacts.append({"path": name, "sha256": ref["sha256"], "size": ref["bytes"]})
        manifest = self.write("candidate/SHA256SUMS", b"Synthetic manifest; no runtime qualification\n")
        self.verification = {"schema": "sandfall-sf-m5-web-artifact-verification-v1", "status": "passed",
                             "build_source_commit": source, "profile": "compat", "application_entry": "sandfall",
                             "entry_scene": "res://sandfall_main.tscn", "project_source_identity": self.identity,
                             "artifacts": self.artifacts, "manifest_sha256": manifest["sha256"],
                             "rapier": "0.35.2", "startup_contract": contract,
                             "logical_viewport": {"width": 1280, "height": 800, "synthetic_only": True},
                             "source_equivalence": {"build_sensitive_changed_paths": []}, "harness_source_commit": source}
        verification_ref = self.write_json("verification.json", self.verification)
        self.record["candidate"] = {"source_commit": source, "source_tree": tree, "profile": "compat",
                                    "artifact_directory": "candidate", "verification": verification_ref}
        served = [{"url": "http://127.0.0.1:8040/" + row["path"], "sha256": row["sha256"],
                   "expected_sha256": row["sha256"], "size": row["size"]} for row in self.artifacts]
        served.append({"url": "http://127.0.0.1:8040/SHA256SUMS", "sha256": manifest["sha256"],
                       "expected_sha256": manifest["sha256"], "size": manifest["bytes"]})
        for row in self.record["scenes"]:
            scene = row["id"]
            image = self.write(scene + ".png", png())
            run = {"type": "sandfall-run-evidence", "schema_version": 1, "source": self.identity,
                   "project": {"id": scene, "identity_valid": True}}
            run_ref = self.write_json(scene + "-run.json", run)
            final = {"source_commit": source, "scene_id": scene, "native_sha256": self.identity["native_runtime_sha256"],
                     "provenance": {"build_profile": "compat"}, "workers": 1, "ready": True, "actor_count": 0, "render_rejections": 0,
                     "native": {"web_profile": {"capabilities": {"secure_context": True, "cross_origin_isolated": False},
                                                "observed_workers_peak": 1}}}
            receipt = {"schema": "sandfall-sf-m4-browser-v1", "status": "passed", "failures": [],
                       "url": self.record["environment"]["url"], "observed_at": "2026-11-01T11:00:00Z",
                       "scope": {"scenario": "gallery", "gallery_entry": scene, "compatibility_web": True, "threaded_web": False},
                       "verification": {"sha256": verification_ref["sha256"], "build_source_commit": source},
                       "requested_viewport": self.record["environment"]["viewport"],
                       "browser_version": {"product": "Synthetic/1", "userAgent": "Synthetic parser fixture"},
                       "harness_checkout": {"dirty_paths": [], "identity_kind": "committed-harness"},
                       "input_events": [{"synthetic_only": True}], "expected_dom_delivery": [{"synthetic_only": True}],
                       "dom_input_events": [{"isTrusted": True, "synthetic_only": True}],
                       "served_identity": served, "final_state": final,
                       "captures": [{"name": "world", "sha256": image["sha256"], "size_bytes": image["bytes"],
                                     "screenshot": {"width": 1, "height": 1}, "completed_elapsed_ms": 1, "state": final}],
                       "run_receipts": [{"sha256": run_ref["sha256"], "evidence": run}]}
            row.update(status="reviewed", criteria={key: "pass" for key in h.CRITERIA}, notes="SYNTHETIC validator fixture only.",
                       browser_receipt=self.write_json(scene + "-browser.json", receipt), screenshot=image, run_evidence=run_ref)
        self.sign()

    def write(self, name, data):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return {"path": name, "sha256": h.sha(data), "bytes": len(data)}

    def write_json(self, name, value):
        return self.write(name, json.dumps(value).encode())

    def sign(self):
        statement = ("SYNTHETIC UNIT TEST — NOT A HUMAN REVIEW\n" + h.STATEMENT + "\nReviewer: " + self.record["reviewer"]["name"]
                     + "\nSF-M5 review payload SHA-256: " + h.payload_digest(self.record) + "\n")
        self.record["attestation"] = {"origin_kind": "signed_file", "origin_locator": "synthetic-unit-test-only",
                                      "statement": self.write("synthetic-statement.txt", statement.encode())}

    def mutate_receipt(self, mutate):
        row = self.record["scenes"][0]
        receipt = json.loads((self.root / row["browser_receipt"]["path"]).read_text())
        mutate(receipt)
        row["browser_receipt"] = self.write_json(row["browser_receipt"]["path"], receipt)
        self.sign()

    def test_committed_template_is_pending_without_human_fields(self):
        pending = h.template()
        self.assertEqual(pending, json.loads(Path(h.__file__).with_suffix(".pending.json").read_text()))
        result, code = h.validate(pending, self.root)
        self.assertEqual(code, 2)
        self.assertEqual(result["status"], "pending-human-review")
        self.assertFalse(result["release_ready"])

    def test_complete_synthetic_record_validates_consistency_only(self):
        result, code = h.validate(self.record, self.root)
        self.assertEqual(code, 0)
        self.assertFalse(result["human_origin_authenticated"])
        self.assertFalse(result["release_ready"])

    def machine_packet(self):
        pending = copy.deepcopy(self.record)
        pending.update(status="pending", reviewer=None, decision=None, overall_notes=None, attestation=None)
        for row in pending["scenes"]:
            row.update(status="pending", notes=None, criteria={key: None for key in h.CRITERIA})
        return pending

    def test_complete_machine_packet_stays_pending_without_creating_human_fields(self):
        pending = self.machine_packet()
        original = copy.deepcopy(pending)
        result, code = h.validate_packet(pending, self.root)
        self.assertEqual(code, 2)
        self.assertEqual(result["status"], "machine-evidence-bound-human-pending")
        self.assertEqual(result["scenes_bound"], list(h.SCENES))
        self.assertFalse(result["human_origin_authenticated"])
        self.assertFalse(result["release_ready"])
        self.assertEqual(pending, original)

    def test_packet_refuses_missing_evidence_or_any_prefilled_human_fields(self):
        for mutate in [lambda r: r["scenes"][0].update(screenshot=None),
                       lambda r: r["scenes"][0]["criteria"].update(visual_legibility="pass"),
                       lambda r: r["scenes"][0].update(notes="An agent inspected the image"),
                       lambda r: r.update(reviewer=self.record["reviewer"]),
                       lambda r: r.update(decision="accept")]:
            pending = self.machine_packet(); mutate(pending)
            with self.assertRaises(ValueError):
                h.validate_packet(pending, self.root)

    def test_packet_refuses_historical_verifier_and_changed_runtime_bytes(self):
        pending = self.machine_packet()
        historical = dict(self.verification, schema="sandfall-sf-m4-web-artifact-verification-v1")
        pending["candidate"]["verification"] = self.write_json("historical-verification.json", historical)
        with self.assertRaisesRegex(ValueError, "exact-source M5"):
            h.validate_packet(pending, self.root)
        pending = self.machine_packet()
        (self.root / "candidate/index.pck").write_bytes(b"changed after candidate verification")
        with self.assertRaisesRegex(ValueError, "length mismatch"):
            h.validate_packet(pending, self.root)

    def test_packet_refuses_failed_browser_receipt(self):
        self.mutate_receipt(lambda receipt: receipt.update(status="failed"))
        with self.assertRaisesRegex(ValueError, "passing ordinary-browser"):
            h.validate_packet(self.machine_packet(), self.root)

    def test_secure_origin_required_for_both_machine_and_human_compatibility_records(self):
        self.mutate_receipt(lambda receipt: receipt["final_state"]["native"]["web_profile"]["capabilities"].update(secure_context=False))
        with self.assertRaisesRegex(ValueError, "secure review origin"):
            h.validate_packet(self.machine_packet(), self.root)
        with self.assertRaisesRegex(ValueError, "secure review origin"):
            h.validate(self.record, self.root)

    def use_original_m4_verifiers(self):
        for row in self.record["scenes"]:
            original = {key: copy.deepcopy(value) for key, value in self.verification.items() if key != "startup_contract"}
            original.update(schema="sandfall-sf-m4-web-artifact-verification-v1", harness_source_commit="d" * 40)
            ref = self.write_json(row["id"] + "-verification.json", original)
            row["browser_verification"] = ref
            receipt = h.load_json((self.root / row["browser_receipt"]["path"]).read_bytes())
            receipt["verification"]["sha256"] = ref["sha256"]
            row["browser_receipt"] = self.write_json(row["browser_receipt"]["path"], receipt)
        self.sign()

    def test_original_current_m4_receipts_reuse_only_with_independent_identical_m5_candidate(self):
        self.use_original_m4_verifiers()
        originals = {row["id"]: (self.root / row["browser_receipt"]["path"]).read_bytes() for row in self.record["scenes"]}
        result, code = h.validate_packet(self.machine_packet(), self.root)
        self.assertEqual((result["status"], code), ("machine-evidence-bound-human-pending", 2))
        self.assertEqual(h.validate(self.record, self.root)[1], 0)
        for row in self.record["scenes"]:
            self.assertEqual((self.root / row["browser_receipt"]["path"]).read_bytes(), originals[row["id"]])
            self.assertNotEqual(row["browser_verification"]["sha256"], self.record["candidate"]["verification"]["sha256"])

    def test_dual_verifier_mismatch_failed_drift_and_unbound_original_refuse(self):
        self.use_original_m4_verifiers()
        row = self.record["scenes"][0]
        original = h.load_json((self.root / row["browser_verification"]["path"]).read_bytes())
        mutations = [lambda v: v.update(status="failed"), lambda v: v.update(build_source_commit="c" * 40),
                     lambda v: v.update(profile="threaded"), lambda v: v.update(rapier="unqualified"),
                     lambda v: v["project_source_identity"].update(source_tree="c" * 40),
                     lambda v: v.update(manifest_sha256="e" * 64), lambda v: v["artifacts"].pop(),
                     lambda v: v["artifacts"][0].update(sha256="e" * 64),
                     lambda v: v["logical_viewport"].update(width=640),
                     lambda v: v["source_equivalence"].update(build_sensitive_changed_paths=["godot/project.godot"]),
                     lambda v: v.update(harness_source_commit="unknown")]
        for mutate in mutations:
            changed = copy.deepcopy(original); mutate(changed)
            row["browser_verification"] = self.write_json("changed-verification.json", changed)
            with self.assertRaises((ValueError, KeyError)):
                h.validate_packet(self.machine_packet(), self.root)
        row["browser_verification"] = self.record["candidate"]["verification"]
        with self.assertRaisesRegex(ValueError, "Browser verified another candidate"):
            h.validate_packet(self.machine_packet(), self.root)

    def test_independent_m5_startup_contract_and_complete_files_remain_required(self):
        self.use_original_m4_verifiers()
        changed = copy.deepcopy(self.verification); changed["startup_contract"]["profile"] = "threaded"
        self.record["candidate"]["verification"] = self.write_json("bad-startup-verification.json", changed)
        with self.assertRaisesRegex(ValueError, "M5 startup contract"):
            h.validate_packet(self.machine_packet(), self.root)
        self.record["candidate"]["verification"] = self.write_json("verification.json", self.verification)
        (self.root / "candidate/unknown-file").write_bytes(b"not in original inventory")
        with self.assertRaisesRegex(ValueError, "complete inventory"):
            h.validate_packet(self.machine_packet(), self.root)

    def builder_inputs(self):
        captures = self.root / "captures"
        for row in self.record["scenes"]:
            target = captures / row["id"]
            (target / "downloads").mkdir(parents=True)
            for field, relative in [("browser_receipt", "browser.json"), ("screenshot", "browser.png"),
                                    ("run_evidence", "downloads/gallery-" + row["id"] + ".sandfall-run.json")]:
                shutil.copyfile(self.root / row[field]["path"], target / relative)
            if row.get("browser_verification") is not None:
                shutil.copyfile(self.root / row["browser_verification"]["path"], target / "artifact-verification.json")
        return captures

    def test_builder_preserves_original_m4_verifiers_alongside_m5_gate(self):
        self.use_original_m4_verifiers()
        captures = self.builder_inputs()
        destination = self.root / "m4-bound-packet"
        result = packet.build_packet(self.root / "candidate", self.root / "verification.json", captures, destination, "SYNTHETIC")
        self.assertEqual(result["status"], "machine-evidence-bound-human-pending")
        pending = h.load_json((destination / "review.pending.json").read_bytes())
        for row in pending["scenes"]:
            self.assertEqual((destination / row["browser_verification"]["path"]).read_bytes(),
                             (captures / row["id"] / "artifact-verification.json").read_bytes())
            self.assertEqual((destination / row["browser_receipt"]["path"]).read_bytes(),
                             (captures / row["id"] / "browser.json").read_bytes())
        self.assertEqual(h.validate_packet(pending, destination)[1], 2)

    def test_builder_refuses_unlisted_input_file_directory_and_symlink_without_filtering(self):
        captures = self.builder_inputs()
        for kind in ("file", "directory", "symlink"):
            extra = self.root / "candidate" / ("unlisted-" + kind)
            if kind == "file": extra.write_bytes(b"unlisted candidate bytes")
            elif kind == "directory": extra.mkdir()
            else: extra.symlink_to(self.root / "candidate/index.pck")
            output = self.root / ("refused-" + kind)
            try:
                with self.subTest(kind=kind), self.assertRaisesRegex(ValueError, r"Input candidate.*inventory \(before\)"):
                    packet.build_packet(self.root / "candidate", self.root / "verification.json", captures, output, "SYNTHETIC")
                failed = h.load_json((output / "packet-build.json").read_bytes())
                self.assertEqual(failed["status"], "failed")
                self.assertIn({"path": extra.name, "kind": kind, "bytes": extra.lstat().st_size}, failed["input_inventory_before"])
                self.assertTrue(extra.is_symlink() or extra.exists())
                self.assertFalse((output / "review.pending.json").exists())
            finally:
                extra.rmdir() if kind == "directory" else extra.unlink()

    def test_builder_refuses_extra_input_created_during_copy(self):
        captures = self.builder_inputs()
        original = packet.bounded_file
        extra = self.root / "candidate/late-shadow.pck"

        def insert_after_manifest(path, maximum=h.MAX_JSON):
            data = original(path, maximum)
            if path == self.root / "candidate/SHA256SUMS":
                extra.write_bytes(b"SYNTHETIC late-created input; no current candidate")
            return data

        output = self.root / "refused-late-input"
        with patch.object(packet, "bounded_file", side_effect=insert_after_manifest):
            with self.assertRaisesRegex(ValueError, r"Input candidate.*inventory \(after\)"):
                packet.build_packet(self.root / "candidate", self.root / "verification.json", captures, output, "SYNTHETIC")
        failed = h.load_json((output / "packet-build.json").read_bytes())
        self.assertEqual(failed["status"], "failed")
        self.assertNotIn(extra.name, [row["path"] for row in failed["input_inventory_before"]])
        self.assertIn(extra.name, [row["path"] for row in failed["input_inventory_after"]])
        self.assertTrue(extra.exists())
        self.assertFalse((output / "review.pending.json").exists())

    def test_builder_freezes_exact_input_bytes_and_keeps_review_pending(self):
        output = self.root / "packet"
        result = packet.build_packet(self.root / "candidate", self.root / "verification.json",
                                     self.builder_inputs(), output, "SYNTHETIC parser fixture")
        self.assertEqual(result["status"], "machine-evidence-bound-human-pending")
        prepared = json.loads((output / "review.pending.json").read_bytes())
        self.assertIsNone(prepared["reviewer"])
        self.assertIsNone(prepared["decision"])
        self.assertTrue(all(value is None for row in prepared["scenes"] for value in row["criteria"].values()))
        (self.root / "candidate/index.pck").write_bytes(b"Changed original after copying")
        checked, code = h.validate_packet(prepared, output)
        self.assertEqual(code, 2)
        self.assertFalse(checked["release_ready"])

    def test_builder_preserves_failed_input_and_never_overwrites_an_existing_packet(self):
        captures = self.builder_inputs()
        original = (captures / h.SCENES[0] / "browser.json").read_bytes()
        changed = json.loads(original); changed["status"] = "failed"
        (captures / h.SCENES[0] / "browser.json").write_text(json.dumps(changed))
        output = self.root / "failed-packet"
        with self.assertRaisesRegex(ValueError, "passing ordinary-browser"):
            packet.build_packet(self.root / "candidate", self.root / "verification.json", captures, output, "SYNTHETIC")
        self.assertEqual(json.loads((output / "packet-build.json").read_text())["status"], "failed")
        self.assertFalse((output / "packet-validation.json").exists())
        retained = (output / h.SCENES[0] / "browser.json").read_bytes()
        with self.assertRaises(FileExistsError):
            packet.build_packet(self.root / "candidate", self.root / "verification.json", captures, output, "SYNTHETIC")
        self.assertEqual((output / h.SCENES[0] / "browser.json").read_bytes(), retained)

    def test_builder_refuses_receipts_from_different_browser_conditions(self):
        captures = self.builder_inputs()
        path = captures / h.SCENES[1] / "browser.json"
        changed = json.loads(path.read_bytes()); changed["url"] = "http://127.0.0.1:8041/?test=1"
        path.write_text(json.dumps(changed))
        with self.assertRaisesRegex(ValueError, "viewport/URL"):
            packet.build_packet(self.root / "candidate", self.root / "verification.json", captures,
                                self.root / "mismatched-packet", "SYNTHETIC")

    def test_absent_statement_never_becomes_acceptance(self):
        self.record["attestation"] = None
        with self.assertRaisesRegex(ValueError, "attestation"):
            h.validate(self.record, self.root)
        result, code = h.validate(self.record, self.root, allow_unsigned=True)
        self.assertEqual(code, 2)
        self.assertEqual(result["status"], "evidence-bound-awaiting-human-statement")

    def test_agent_and_partial_unknown_duplicate_scene_records_refuse(self):
        for change in [lambda r: r["reviewer"].update(kind="agent"), lambda r: r.update(invented_pass=True),
                       lambda r: r["scenes"].pop(), lambda r: r["scenes"][1].update(id=r["scenes"][0]["id"]),
                       lambda r: r["scenes"][0]["criteria"].update(physical_causality=None),
                       lambda r: r["scenes"][0].update(notes="   ")]:
            value = copy.deepcopy(self.record); change(value)
            with self.assertRaises(ValueError):
                h.validate(value, self.root)

    def test_failed_criterion_cannot_be_overridden_by_overall_accept(self):
        self.record["scenes"][0]["criteria"]["pacing_responsiveness"] = "fail"
        with self.assertRaisesRegex(ValueError, "contradicts"):
            h.validate(self.record, self.root)
        self.record["decision"] = "reject"; self.sign()
        result, code = h.validate(self.record, self.root)
        self.assertEqual(code, 1)
        self.assertEqual(result["status"], "complete-rejected-human-record")

    def test_changed_review_invalidates_original_human_statement(self):
        self.record["overall_notes"] = "Different finding after the recorded statement"
        with self.assertRaisesRegex(ValueError, "bind this complete review"):
            h.validate(self.record, self.root)

    def test_wrong_source_profile_browser_viewport_input_and_capture_refuse(self):
        baseline = copy.deepcopy(self.record)
        for change in [lambda r: r.update(status="failed"), lambda r: r["final_state"].update(source_commit="c" * 40),
                       lambda r: r["scope"].update(threaded_web=True), lambda r: r["scope"].update(gallery_entry="sixteen_body"),
                       lambda r: r["browser_version"].update(product="Different/2"), lambda r: r["requested_viewport"].update(dpr=2),
                       lambda r: r["harness_checkout"].update(dirty_paths=["modified harness"]),
                       lambda r: r.update(dom_input_events=[]), lambda r: r["served_identity"].pop(),
                       lambda r: r["captures"][0].update(error="capture deadline"),
                       lambda r: r["captures"].append(copy.deepcopy(r["captures"][0])),
                       lambda r: r["run_receipts"].clear()]:
            self.setUp_receipt_from_baseline(baseline)
            self.mutate_receipt(change)
            with self.assertRaises((ValueError, KeyError)):
                h.validate(self.record, self.root)

    def setUp_receipt_from_baseline(self, baseline):
        # Keep original bytes independently of subsequent mutations in this case.
        if not hasattr(self, "_original_browser"):
            self._original_browser = (self.root / baseline["scenes"][0]["browser_receipt"]["path"]).read_bytes()
        self.record = copy.deepcopy(baseline)
        self.write(baseline["scenes"][0]["browser_receipt"]["path"], self._original_browser)

    def test_candidate_and_image_byte_corruption_refuse(self):
        path = self.root / "candidate/index.pck"
        original = path.read_bytes(); path.write_bytes(b"wrong")
        with self.assertRaisesRegex(ValueError, "length mismatch"):
            h.validate(self.record, self.root)
        path.write_bytes(original)
        image = self.root / self.record["scenes"][0]["screenshot"]["path"]
        image.write_bytes(b"x" * image.stat().st_size)
        with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
            h.validate(self.record, self.root)

    def test_escaped_symlink_paths_and_nonfinite_duplicate_json_refuse(self):
        for path in ["../outside", "/tmp/outside", "candidate//index.pck", "candidate/./index.pck"]:
            with self.assertRaises(ValueError): h.safe_path(self.root, path)
        (self.root / "alias").symlink_to(self.root / "candidate", target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "Symlink"):
            h.safe_path(self.root, "alias/index.pck")
        for data in [b'{"a":1,"a":2}', b'{"a":NaN}', b'{"a":Infinity}']:
            with self.assertRaises(ValueError): h.load_json(data)

    def test_human_time_cannot_precede_supporting_browser_evidence(self):
        self.record["reviewer"]["reviewed_at"] = "2026-10-31T12:00:00Z"; self.sign()
        with self.assertRaisesRegex(ValueError, "predates"):
            h.validate(self.record, self.root)

    def test_registered_scene_ids_are_existing_source_gallery(self):
        source = (h.ROOT / "godot/scripts/sandfall/gallery.gd").read_text()
        self.assertEqual(tuple(re.findall(r'\{"id": "([a-z0-9_]+)"', source)), h.SCENES)


if __name__ == "__main__":
    unittest.main()
