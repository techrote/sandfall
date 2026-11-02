#!/usr/bin/env python3
"""Bind a real human Gallery review to retained candidate/browser evidence.

This checks a review record, not a person's identity. Only a genuine reviewer
can supply the attestation; the integrating owner authenticates its origin.
Pending records return 2, rejected/invalid records 1, complete accepted records
0. The packet command validates complete machine evidence while all human
fields remain empty. No command creates a verdict or claims release readiness.
"""
from __future__ import annotations

import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import struct
from urllib.parse import parse_qs, urljoin, urlsplit

ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = Path(__file__).with_suffix(".schema.json")
SCENES = ("gravity_cascade", "fluid_messenger", "passive_subject_ride",
          "endless_kinetic_loop", "intervention", "time_controls", "sixteen_body")
CRITERIA = ("visual_legibility", "interaction_navigation", "labels_viewport",
            "physical_causality", "pacing_responsiveness", "reset_presentation",
            "errors_refusals")
STATEMENT = "I personally ran and reviewed all seven Gallery scenes in the recorded browser conditions."
MAX_JSON = 64 * 1024 * 1024


def require(value: bool, message: str) -> None:
    if not value:
        raise ValueError(message)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def unique_object(pairs: list) -> dict:
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON key: " + key)
        result[key] = value
    return result


def load_json(data: bytes) -> dict:
    require(len(data) <= MAX_JSON, "JSON evidence exceeds 64 MiB")
    return json.loads(data, object_pairs_hook=unique_object,
                      parse_constant=lambda value: (_ for _ in ()).throw(ValueError("Nonfinite JSON: " + value)))


def check_shape(value: object, spec: dict, definitions: dict, path: str = "record") -> None:
    """Enforce the small, closed JSON-Schema subset used by this record."""
    if "$ref" in spec:
        require(spec["$ref"].startswith("#/$defs/"), "External schema reference refused")
        return check_shape(value, definitions[spec["$ref"].split("/")[-1]], definitions, path)
    if "anyOf" in spec:
        for choice in spec["anyOf"]:
            try:
                check_shape(value, choice, definitions, path)
                return
            except ValueError:
                pass
        raise ValueError(path + " does not match any permitted shape")
    kind = spec.get("type")
    valid = {"null": value is None, "object": isinstance(value, dict), "array": isinstance(value, list),
             "string": isinstance(value, str), "integer": isinstance(value, int) and not isinstance(value, bool),
             "boolean": isinstance(value, bool)}
    require(kind in valid and valid[kind], path + " has the wrong type")
    if "const" in spec:
        require(type(value) is type(spec["const"]) and value == spec["const"], path + " has the wrong constant")
    if "enum" in spec:
        require(any(type(value) is type(item) and value == item for item in spec["enum"]), path + " has an unsupported value")
    if kind == "object":
        require(set(spec["required"]) <= value.keys(), path + " lacks required fields")
        require(spec.get("additionalProperties") is False and set(value) <= spec["properties"].keys(), path + " has unknown fields")
        for key, child in value.items():
            check_shape(child, spec["properties"][key], definitions, path + "." + key)
    elif kind == "array":
        require(spec.get("minItems", 0) <= len(value) <= spec.get("maxItems", 10000), path + " has an invalid item count")
        for index, child in enumerate(value):
            check_shape(child, spec["items"], definitions, f"{path}[{index}]")
    elif kind == "string":
        require(spec.get("minLength", 0) <= len(value) <= spec.get("maxLength", 65536), path + " has an invalid length")
        if "pattern" in spec:
            require(re.fullmatch(spec["pattern"], value) is not None, path + " has invalid syntax")
    elif kind == "integer":
        require(spec.get("minimum", 0) <= value <= spec.get("maximum", 2**53 - 1), path + " is out of range")


def shape(record: dict) -> None:
    schema = load_json(SCHEMA_PATH.read_bytes())
    check_shape(record, schema, schema["$defs"])
    require(tuple(row["id"] for row in record["scenes"]) == SCENES, "All seven exact Gallery IDs must occur once in source order")


def template() -> dict:
    return {"schema": "sandfall-sf-m5-human-review-v1", "status": "pending",
            "candidate": None, "environment": None, "reviewer": None,
            "scenes": [{"id": scene, "status": "pending",
                        "criteria": {key: None for key in CRITERIA}, "notes": None,
                        "browser_receipt": None, "screenshot": None, "run_evidence": None}
                       for scene in SCENES],
            "decision": None, "overall_notes": None, "attestation": None}


def safe_path(root: Path, relative: str) -> Path:
    path = PurePosixPath(relative)
    require(not path.is_absolute() and path.parts and all(part not in (".", "..") for part in path.parts)
            and path.as_posix() == relative and "\\" not in relative, "Noncanonical evidence path")
    current = root.resolve()
    for part in path.parts:
        current = current / part
        require(not current.is_symlink(), "Symlink evidence path refused")
    require(current.resolve().is_relative_to(root.resolve()), "Evidence path escapes bundle")
    return current


def read_ref(root: Path, ref: dict, maximum: int = MAX_JSON) -> bytes:
    require(isinstance(ref["bytes"], int) and not isinstance(ref["bytes"], bool)
            and isinstance(ref["sha256"], str) and re.fullmatch(r"[0-9a-f]{64}", ref["sha256"]) is not None,
            "Invalid evidence length/digest")
    path = safe_path(root, ref["path"])
    require(path.is_file() and 0 < ref["bytes"] <= maximum, "Missing or oversized evidence: " + ref["path"])
    require(path.stat().st_size == ref["bytes"], "Evidence byte length mismatch: " + ref["path"])
    data = path.read_bytes()
    require(len(data) == ref["bytes"] and sha(data) == ref["sha256"], "Evidence SHA-256 mismatch: " + ref["path"])
    return data


def instant(value: str) -> datetime:
    require(isinstance(value, str) and value.endswith("Z"), "Review/capture time must explicitly use UTC Z")
    return datetime.fromisoformat(value[:-1] + "+00:00")


def payload_digest(record: dict) -> str:
    # The external statement signs all source, conditions, evidence and verdicts.
    # Its own locator/hash is excluded to avoid a self-hash cycle.
    payload = dict(record, attestation=None)
    return sha(json.dumps(payload, sort_keys=True, ensure_ascii=False,
                          separators=(",", ":"), allow_nan=False).encode("utf-8"))


def candidate_evidence(record: dict, root: Path) -> tuple[dict, dict]:
    candidate = record["candidate"]
    verified = load_json(read_ref(root, candidate["verification"]))
    require(verified["schema"] == "sandfall-sf-m5-web-artifact-verification-v1" and verified["status"] == "passed",
            "A passing exact-source M5 artifact verification is required")
    require(verified["build_source_commit"] == candidate["source_commit"] and verified["profile"] == candidate["profile"],
            "Candidate source/profile mismatch")
    require(verified["application_entry"] == "sandfall" and verified["entry_scene"] == "res://sandfall_main.tscn",
            "Candidate is not the dedicated Sandfall application")
    identity = verified["project_source_identity"]
    require(identity["source_commit"] == identity["native_source_commit"] == candidate["source_commit"]
            and identity["source_tree"] == candidate["source_tree"] and identity["build_profile"] == candidate["profile"],
            "Candidate PCK/runtime identity mismatch")
    rows = verified["artifacts"]
    require(0 < len(rows) <= 64 and len({row["path"] for row in rows}) == len(rows), "Invalid artifact inventory")
    entries = {row["path"]: row for row in rows}
    native = "libcybersand_native.web." + ("threads" if candidate["profile"] == "threaded" else "nothreads") + ".wasm"
    require({"index.html", "index.js", "index.wasm", "index.side.wasm", "index.pck", "godot_rapier.wasm", native,
             "startup-contract.json", "Caddyfile.example"} <= entries.keys(),
            "Incomplete engine/PCK/native/Rapier inventory")
    require(entries[native]["sha256"] == identity["native_runtime_sha256"]
            and entries["godot_rapier.wasm"]["sha256"] == identity["rapier_runtime_sha256"], "Runtime identity disagrees with inventory")
    require(sum(row["size"] for row in rows) <= 512 * 1024 * 1024, "Candidate inventory exceeds 512 MiB")
    for row in rows:
        require(re.fullmatch(r"[A-Za-z0-9_.-]+", row["path"]) is not None, "Invalid candidate filename")
        read_ref(root, {"path": candidate["artifact_directory"] + "/" + row["path"],
                       "sha256": row["sha256"], "bytes": row["size"]}, 128 * 1024 * 1024)
    manifest_path = safe_path(root, candidate["artifact_directory"] + "/SHA256SUMS")
    require(manifest_path.is_file() and 0 < manifest_path.stat().st_size <= 65536, "Missing/oversized candidate manifest")
    manifest = manifest_path.read_bytes()
    require(len(manifest) <= 65536 and sha(manifest) == verified["manifest_sha256"], "Candidate manifest mismatch")
    directory = safe_path(root, candidate["artifact_directory"])
    require(all(path.is_file() and not path.is_symlink() for path in directory.iterdir())
            and {path.name for path in directory.iterdir()} == set(entries) | {"SHA256SUMS"},
            "Candidate directory differs from its complete inventory")
    contract = load_json(read_ref(root, {"path": candidate["artifact_directory"] + "/startup-contract.json",
                                       "sha256": entries["startup-contract.json"]["sha256"],
                                       "bytes": entries["startup-contract.json"]["size"]}))
    require(contract == verified["startup_contract"] and contract["schema"] == "sandfall-web-startup-v1"
            and contract["source_commit"] == candidate["source_commit"] and contract["profile"] == candidate["profile"],
            "M5 startup contract differs from the retained candidate")
    runtime = {name: value for name, value in entries.items() if Path(name).suffix in {".wasm", ".pck", ".js"}}
    require(len(contract["assets"]) == len(runtime)
            and len({item["path"] for item in contract["assets"]}) == len(runtime), "Incomplete M5 startup asset inventory")
    for item in contract["assets"]:
        require(item["path"] in runtime and item["sha256"] == runtime[item["path"]]["sha256"]
                and item["size"] == runtime[item["path"]]["size"], "M5 startup asset identity mismatch")
    entries["SHA256SUMS"] = {"sha256": verified["manifest_sha256"], "size": len(manifest)}
    return verified, entries


def browser_verification(row: dict, record: dict, root: Path, verified: dict) -> dict:
    """Retain original M4 custody while independently requiring M5 artifact checks.

    M5 wraps the M4 verifier. Its original M4 receipt can therefore support a
    browser run when every candidate identity field agrees; it never supplies
    the added M5 startup-contract gate on its own. Harness-only commit/path
    bookkeeping may differ and remains visible in each original verifier.
    """
    candidate_ref = record["candidate"]["verification"]
    original_ref = row.get("browser_verification") or candidate_ref
    original = load_json(read_ref(root, original_ref))
    if original_ref["sha256"] == candidate_ref["sha256"]:
        return original_ref
    require(original["schema"] == "sandfall-sf-m4-web-artifact-verification-v1" and original["status"] == "passed",
            "Supplemental browser verification must be an original passing M4 receipt")
    for key in ("build_source_commit", "profile", "rapier", "application_entry", "entry_scene",
                "project_source_identity", "manifest_sha256", "artifacts", "logical_viewport"):
        require(original[key] == verified[key], "M4/M5 verifier candidate mismatch: " + key)
    for receipt in (original, verified):
        require(receipt["source_equivalence"]["build_sensitive_changed_paths"] == [],
                "Verifier reports build-sensitive source drift")
        require(re.fullmatch(r"[0-9a-f]{40}", receipt["harness_source_commit"]) is not None,
                "Verifier harness commit is not identified")
    return original_ref


def scene_evidence(row: dict, record: dict, root: Path, verified: dict, entries: dict) -> datetime:
    receipt = load_json(read_ref(root, row["browser_receipt"]))
    environment, candidate = record["environment"], record["candidate"]
    require(receipt["schema"] == "sandfall-sf-m4-browser-v1" and receipt["status"] == "passed" and receipt["failures"] == [],
            "A passing ordinary-browser receipt is required")
    require(receipt["scope"]["scenario"] == "gallery" and receipt["scope"]["gallery_entry"] == row["id"],
            "Each scene needs its own isolated Gallery receipt/capture")
    require(receipt["scope"]["compatibility_web"] is (candidate["profile"] == "compat")
            and receipt["scope"]["threaded_web"] is (candidate["profile"] == "threaded"), "Browser receipt does not qualify the declared profile")
    original_verification = browser_verification(row, record, root, verified)
    require(receipt["verification"]["sha256"] == original_verification["sha256"]
            and receipt["verification"]["build_source_commit"] == candidate["source_commit"], "Browser verified another candidate")
    require(receipt["requested_viewport"] == environment["viewport"] and receipt["url"] == environment["url"],
            "Browser viewport/URL differs from human review conditions")
    require(receipt["browser_version"]["product"] == environment["browser_product"]
            and receipt["browser_version"]["userAgent"] == environment["user_agent"], "Browser engine/version differs from human conditions")
    require(receipt["harness_checkout"]["dirty_paths"] == [] and receipt["harness_checkout"]["identity_kind"] == "committed-harness",
            "Uncommitted browser harness")
    require(bool(receipt["input_events"]) and bool(receipt["expected_dom_delivery"])
            and any(event.get("isTrusted") is True for event in receipt["dom_input_events"]), "No retained trusted browser input")
    served = receipt["served_identity"]
    require(len(served) == len(entries), "Served runtime inventory is incomplete")
    by_url = {item["url"]: item for item in served}
    require(len(by_url) == len(served), "Duplicate served runtime URLs")
    for name, entry in entries.items():
        item = by_url[urljoin(receipt["url"], name)]
        require(item["sha256"] == item["expected_sha256"] == entry["sha256"] and item["size"] == entry["size"],
                "Served runtime differs from retained candidate: " + name)
    final = receipt["final_state"]
    require(final["source_commit"] == candidate["source_commit"] and final["scene_id"] == row["id"]
            and final["native_sha256"] == verified["project_source_identity"]["native_runtime_sha256"], "Observed application source/scene mismatch")
    require(final["provenance"]["build_profile"] == candidate["profile"] and final["workers"] == environment["workers_configured"],
            "Observed export/worker profile mismatch")
    require(final["ready"] is True and final["actor_count"] == 0 and final["render_rejections"] == 0,
            "Capture is not a ready zero-actor application")
    capabilities = final["native"]["web_profile"]["capabilities"]
    require(capabilities["secure_context"] is True, "Pinned Godot 4.7 requires a secure review origin for both profiles")
    if candidate["profile"] == "compat":
        require(environment["workers_configured"] == 1, "Compatibility review cannot claim multiple native workers")
    else:
        require(capabilities["cross_origin_isolated"] is True, "Unqualified threaded review host")
        if environment["workers_configured"] > 1:
            require(final["native"]["web_profile"]["observed_workers_peak"] >= 2, "No actual multiworker participation")
    requests = parse_qs(urlsplit(environment["url"]).query).get("workers", ["auto"])
    require(requests == [environment["workers_requested"]], "Worker request differs from actual browser URL")
    require(environment["workers_requested"] == "auto" or int(environment["workers_requested"]) == environment["workers_configured"],
            "Actual workers differ from the explicit request")
    image = read_ref(root, row["screenshot"])
    require(len(image) >= 33 and image[:8] == b"\x89PNG\r\n\x1a\n" and image[8:16] == b"\x00\x00\x00\rIHDR", "Screenshot is not a PNG")
    width, height = struct.unpack(">II", image[16:24])
    matches = [capture for capture in receipt["captures"] if capture.get("sha256") == row["screenshot"]["sha256"]]
    require(len(matches) == 1, "Screenshot is absent/ambiguous in actual browser capture receipt")
    capture = matches[0]
    require(capture["name"] == "world" and capture["size_bytes"] == len(image) and capture["screenshot"] == {"width": width, "height": height}
            and 0 < width <= 8192 and 0 < height <= 8192 and "completed_elapsed_ms" in capture and "error" not in capture,
            "Screenshot capture was incomplete or its dimensions differ")
    require(capture["state"]["scene_id"] == row["id"] and capture["state"]["source_commit"] == candidate["source_commit"],
            "Screenshot is associated with another scene/source")
    evidence = load_json(read_ref(root, row["run_evidence"]))
    require(evidence["type"] == "sandfall-run-evidence" and evidence["schema_version"] == 1
            and evidence["source"] == verified["project_source_identity"] and evidence["project"]["id"] == row["id"]
            and evidence["project"]["identity_valid"] is True, "Run evidence source/scene identity mismatch")
    require(any(item["sha256"] == row["run_evidence"]["sha256"] and item["evidence"] == evidence
                for item in receipt["run_receipts"]), "Run evidence bytes were not retained as a browser download")
    return instant(receipt["observed_at"])


def validate_packet(record: dict, root: Path) -> tuple[dict, int]:
    """Check a complete machine packet without inventing any human fields."""
    shape(record)
    require(record["status"] == "pending"
            and all(record[key] is None for key in ("reviewer", "decision", "overall_notes", "attestation"))
            and all(row["status"] == "pending" and row["notes"] is None
                    and all(value is None for value in row["criteria"].values()) for row in record["scenes"]),
            "Machine packet must leave every human field pending or null")
    require(record["candidate"] is not None and record["environment"] is not None
            and all(row[key] is not None for row in record["scenes"]
                    for key in ("browser_receipt", "screenshot", "run_evidence")),
            "Machine packet lacks candidate, conditions or scene files")
    verified, entries = candidate_evidence(record, root)
    observed = [scene_evidence(row, record, root, verified, entries) for row in record["scenes"]]
    return {"schema": "sandfall-sf-m5-human-validation-v1",
            "status": "machine-evidence-bound-human-pending", "record_payload_sha256": payload_digest(record),
            "candidate": record["candidate"], "conditions": record["environment"],
            "scenes_bound": list(SCENES), "latest_browser_observation": max(observed).isoformat().replace("+00:00", "Z"),
            "human_origin_authenticated": False, "release_ready": False,
            "limit": "Only source/file/condition consistency is checked; a genuine live human review and its original statement remain absent."}, 2


def validate(record: dict, root: Path, allow_unsigned: bool = False) -> tuple[dict, int]:
    shape(record)
    result = {"schema": "sandfall-sf-m5-human-validation-v1", "record_payload_sha256": payload_digest(record),
              "status": "pending-human-review", "human_origin_authenticated": False, "release_ready": False,
              "limit": "The owner must authenticate the original human attestation; this validator proves record/file consistency only."}
    if record["status"] == "pending":
        require(record["decision"] is None and record["attestation"] is None, "Pending records cannot carry a verdict or attestation")
        return result, 2
    require(all(record[key] is not None for key in ("candidate", "environment", "reviewer", "decision", "overall_notes")),
            "Submitted review lacks candidate, conditions or human fields")
    require(record["reviewer"]["mode"] == "live-browser", "Still images or agent inspection cannot establish human responsiveness acceptance")
    require(all(row["status"] == "reviewed" and row["notes"] and all(value in ("pass", "fail") for value in row["criteria"].values())
                and all(row[key] is not None for key in ("browser_receipt", "screenshot", "run_evidence")) for row in record["scenes"]),
            "Every scene/criterion requires an explicit human finding and bound evidence")
    all_pass = all(value == "pass" for row in record["scenes"] for value in row["criteria"].values())
    require(record["decision"] == ("accept" if all_pass else "reject"), "Human decision contradicts a scene criterion")
    verified, entries = candidate_evidence(record, root)
    for row in record["scenes"]:
        observed_at = scene_evidence(row, record, root, verified, entries)
        require(instant(record["reviewer"]["reviewed_at"]) >= observed_at, "Human review predates its visual evidence")
    result.update(candidate=record["candidate"], conditions=record["environment"], decision=record["decision"])
    if allow_unsigned:
        result["status"] = "evidence-bound-awaiting-human-statement"
        return result, 2
    require(record["attestation"] is not None, "Explicit original human attestation is absent")
    statement = read_ref(root, record["attestation"]["statement"], 1024 * 1024).decode("utf-8")
    lines = statement.splitlines()
    require(STATEMENT in lines and "Reviewer: " + record["reviewer"]["name"] in lines
            and "SF-M5 review payload SHA-256: " + result["record_payload_sha256"] in lines,
            "Human statement does not explicitly bind this complete review")
    result["status"] = "complete-accepted-human-record" if all_pass else "complete-rejected-human-record"
    return result, 0 if all_pass else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("template", "packet", "validate", "digest"))
    parser.add_argument("--record", type=Path)
    parser.add_argument("--bundle-root", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "template":
            result, code = template(), 0
            shape(result)
        else:
            require(args.record is not None and args.bundle_root is not None, "--record and --bundle-root are required")
            require(args.record.stat().st_size <= 1024 * 1024, "Review record exceeds 1 MiB")
            record = load_json(args.record.read_bytes())
            if args.command == "packet":
                result, code = validate_packet(record, args.bundle_root)
            else:
                result, code = validate(record, args.bundle_root, allow_unsigned=args.command == "digest")
    except (OSError, ValueError, KeyError, TypeError, IndexError, AttributeError, OverflowError, RecursionError) as error:
        result, code = {"schema": "sandfall-sf-m5-human-validation-v1", "status": "invalid-review-record",
                        "error": str(error), "human_origin_authenticated": False, "release_ready": False}, 1
    encoded = json.dumps(result, indent=2, allow_nan=False) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded)
    print(encoded, end="")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
