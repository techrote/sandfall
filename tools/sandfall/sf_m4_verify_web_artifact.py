#!/usr/bin/env python3
"""Verify SF-M4's in-application project/evidence identity against actual Web bytes.

The inherited verifier retains its source, file-inventory and viewport gates.
This additional gate binds the data included in the PCK to its independently
served copy, exact Git tree and freshly built native/Rapier modules. Browser
acceptance must additionally compare the application's observed identity.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess

try:
    from sf_m1_verify_web_artifact import verify as verify_base, require, git, VerificationError, ROOT
except ModuleNotFoundError:
    from tools.sandfall.sf_m1_verify_web_artifact import verify as verify_base, require, git, VerificationError, ROOT


def verify(web_root: Path, repo_root: Path, expected_build_sha: str) -> dict:
    receipt = verify_base(web_root, repo_root, expected_build_sha)
    identity_path = web_root / "sandfall_build_identity.json"
    require(identity_path.is_file(), "SF-M4 project/evidence identity is absent")
    identity = json.loads(identity_path.read_text(encoding="utf-8"))
    info = json.loads((web_root / "build-info.json").read_text(encoding="utf-8"))
    entries = {value["path"]: value for value in receipt["artifacts"]}
    require(identity == info.get("sandfall_identity"), "Project identity differs from export receipt")
    expected = {
        "source_commit": expected_build_sha,
        "native_source_commit": expected_build_sha,
        "source_tree": git(repo_root, "rev-parse", f"{expected_build_sha}^{{tree}}"),
        "native_runtime_sha256": entries["libcybersand_native.web.nothreads.wasm"]["sha256"],
        "rapier_version": "0.35.2",
        "rapier_runtime_sha256": entries["godot_rapier.wasm"]["sha256"],
        "godot_version": "4.7.stable.official.5b4e0cb0f",
        "build_profile": "compat",
    }
    require(identity == expected, "Project identity is not the measured exact-head native/Rapier build")
    require("sandfall_build_identity.json" in entries, "Project identity is outside the export inventory")
    receipt.update(schema="sandfall-sf-m4-web-artifact-verification-v1", project_source_identity=identity)
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--web-root", type=Path, default=ROOT / "build/web-sandfall")
    parser.add_argument("--repo-root", type=Path, default=ROOT)
    parser.add_argument("--expected-build-sha", required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "sf-m4-evidence/artifact-verification.json")
    args = parser.parse_args()
    try:
        receipt = verify(args.web_root.resolve(), args.repo_root.resolve(), args.expected_build_sha)
    except (VerificationError, OSError, ValueError, KeyError, subprocess.SubprocessError) as exc:
        receipt = {"schema": "sandfall-sf-m4-web-artifact-verification-v1", "status": "failed",
                   "build_source_commit": args.expected_build_sha, "error": str(exc)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": receipt["status"], "receipt": str(args.output), "error": receipt.get("error")}))
    return 0 if receipt["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
