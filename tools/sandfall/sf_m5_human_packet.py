#!/usr/bin/env python3
"""Prepare immutable machine inputs for a pending, genuine human Gallery review.

Input layout: SCENE/browser.json, SCENE/browser.png and
SCENE/downloads/gallery-SCENE.sandfall-run.json beneath --captures-root.
All seven receipts must bind the supplied M5 verifier or a retained original
SCENE/artifact-verification.json M4 verifier for the identical candidate bytes,
plus one browser, URL, viewport and worker condition. No receipt is rewritten.
Successful preparation returns 2 (human review remains pending), failure 1.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
from urllib.parse import parse_qs, urlsplit

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.sandfall import sf_m5_human_review as review


def encoded(value: object) -> bytes:
    return (json.dumps(value, indent=2, allow_nan=False) + "\n").encode()


def bounded_file(path: Path, maximum: int = review.MAX_JSON) -> bytes:
    review.require(path.is_file() and not path.is_symlink() and 0 < path.stat().st_size <= maximum,
                   "Missing, symlink or oversized packet input: " + str(path))
    data = path.read_bytes()
    review.require(0 < len(data) <= maximum, "Packet input changed size beyond its bound")
    return data


def input_inventory(directory: Path) -> list[dict]:
    """Observe every immediate entry without following links or filtering extras."""
    review.require(directory.is_dir() and not directory.is_symlink(), "Input candidate must be a regular directory")
    rows = []
    with os.scandir(directory) as children:
        for entry in children:
            review.require(len(rows) < 65, "Input candidate exceeds the 64-asset plus manifest inventory bound")
            kind = ("symlink" if entry.is_symlink() else "file" if entry.is_file(follow_symlinks=False)
                    else "directory" if entry.is_dir(follow_symlinks=False) else "other")
            rows.append({"path": entry.name, "kind": kind, "bytes": entry.stat(follow_symlinks=False).st_size})
    return sorted(rows, key=lambda row: row["path"])


def build_packet(web_root: Path, verification_path: Path, captures_root: Path,
                 output: Path, platform: str) -> dict:
    output.mkdir(parents=True, exist_ok=False)
    inputs = [Path(__file__), Path(review.__file__), review.SCHEMA_PATH]
    build = {"schema": "sandfall-sf-m5-human-packet-build-v1", "status": "failed",
             "human_origin_authenticated": False, "release_ready": False,
             "builder_source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
             "builder_dirty_paths": subprocess.check_output(["git", "status", "--porcelain", "--",
                                      *[str(path.relative_to(ROOT)) for path in inputs]], cwd=ROOT, text=True).splitlines(),
             "builder_inputs": [{"path": str(path.relative_to(ROOT)), "sha256": review.sha(path.read_bytes())} for path in inputs],
             "input_paths": {"web_root": str(web_root.resolve()), "verification": str(verification_path.resolve()),
                             "captures_root": str(captures_root.resolve())}}

    def keep(relative: str, data: bytes) -> dict:
        target = review.safe_path(output, relative)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        return {"path": relative, "sha256": review.sha(data), "bytes": len(data)}

    try:
        verification_bytes = bounded_file(verification_path)
        verification_ref = keep("artifact-verification.json", verification_bytes)
        verified = review.load_json(verification_bytes)
        review.require(verified.get("schema") == "sandfall-sf-m5-web-artifact-verification-v1"
                       and verified.get("status") == "passed", "A passing exact-source M5 artifact verification is required")
        identity = verified["project_source_identity"]
        record = review.template()
        record["candidate"] = {"source_commit": verified["build_source_commit"], "source_tree": identity["source_tree"],
                               "profile": verified["profile"], "artifact_directory": "candidate", "verification": verification_ref}
        artifacts = verified["artifacts"]
        review.require(0 < len(artifacts) <= 64 and len({row["path"] for row in artifacts}) == len(artifacts)
                       and sum(row["size"] for row in artifacts) <= 512 * 1024 * 1024, "Invalid or oversized candidate inventory")
        expected_names = {row["path"] for row in artifacts} | {"SHA256SUMS"}

        def check_input_inventory(phase: str) -> None:
            observed = input_inventory(web_root)
            build["input_inventory_" + phase] = observed
            review.require({row["path"] for row in observed} == expected_names
                           and all(row["kind"] == "file" for row in observed),
                           "Input candidate directory differs from its complete verified inventory (" + phase + ")")

        check_input_inventory("before")
        for row in artifacts:
            ref = {"path": row["path"], "sha256": row["sha256"], "bytes": row["size"]}
            keep("candidate/" + row["path"], review.read_ref(web_root, ref, 128 * 1024 * 1024))
        manifest = bounded_file(review.safe_path(web_root, "SHA256SUMS"), 65536)
        review.require(review.sha(manifest) == verified["manifest_sha256"], "Candidate manifest mismatch")
        keep("candidate/SHA256SUMS", manifest)
        for row in record["scenes"]:
            scene = row["id"]
            browser_bytes = bounded_file(review.safe_path(captures_root, scene + "/browser.json"))
            receipt = review.load_json(browser_bytes)
            row["browser_receipt"] = keep(scene + "/browser.json", browser_bytes)
            if receipt["verification"]["sha256"] != verification_ref["sha256"]:
                original = scene + "/artifact-verification.json"
                row["browser_verification"] = keep(original, bounded_file(review.safe_path(captures_root, original)))
            row["screenshot"] = keep(scene + "/browser.png", bounded_file(review.safe_path(captures_root, scene + "/browser.png")))
            run_path = scene + "/downloads/gallery-" + scene + ".sandfall-run.json"
            row["run_evidence"] = keep(run_path, bounded_file(review.safe_path(captures_root, run_path)))
            if record["environment"] is None:
                requested = parse_qs(urlsplit(receipt["url"]).query).get("workers", ["auto"])
                review.require(len(requested) == 1, "Ambiguous worker request in browser receipt")
                record["environment"] = {"url": receipt["url"], "browser_product": receipt["browser_version"]["product"],
                                         "user_agent": receipt["browser_version"]["userAgent"], "platform": platform,
                                         "viewport": receipt["requested_viewport"], "workers_requested": requested[0],
                                         "workers_configured": receipt["final_state"]["workers"]}
        check_input_inventory("after")
        result, code = review.validate_packet(record, output)
        review.require(code == 2 and result["release_ready"] is False, "Packet validation supplied an invalid acceptance disposition")
        keep("review.pending.json", encoded(record))
        keep("packet-validation.json", encoded(result))
        build.update(status="machine-evidence-bound-human-pending", candidate=record["candidate"],
                     record_payload_sha256=review.payload_digest(record), scene_count=len(record["scenes"]))
        return build
    except Exception as error:
        build["error"] = str(error)
        raise
    finally:
        (output / "packet-build.json").write_bytes(encoded(build))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--web-root", type=Path, required=True)
    parser.add_argument("--verification", type=Path, required=True)
    parser.add_argument("--captures-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True, help="New directory; existing evidence is never replaced")
    parser.add_argument("--platform", required=True, help="Actual platform of the recorded browser executions")
    args = parser.parse_args()
    try:
        result = build_packet(args.web_root, args.verification, args.captures_root, args.output, args.platform)
        code = 2
    except (OSError, ValueError, KeyError, TypeError, IndexError, AttributeError, OverflowError, RecursionError) as error:
        result = {"schema": "sandfall-sf-m5-human-packet-build-v1", "status": "invalid-machine-packet",
                  "error": str(error), "human_origin_authenticated": False, "release_ready": False}
        code = 1
    print(encoded(result).decode(), end="")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
