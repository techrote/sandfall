#!/usr/bin/env python3
"""Verify both SF-M5 Web exports, complete worker assets and startup digests."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re
import subprocess
try:
    from sf_m4_verify_web_artifact import verify as verify_base, require, VerificationError, ROOT
except ModuleNotFoundError:
    from tools.sandfall.sf_m4_verify_web_artifact import verify as verify_base, require, VerificationError, ROOT


def verify(web_root: Path, repo_root: Path, expected_build_sha: str, profile: str) -> dict:
    result = verify_base(web_root, repo_root, expected_build_sha, profile)
    files = {entry["path"]: entry for entry in result["artifacts"]}
    require({"startup-contract.json", "Caddyfile.example"} <= files.keys(), "SF-M5 startup/host contract is missing")
    contract = json.loads((web_root / "startup-contract.json").read_text())
    require(contract.get("schema") == "sandfall-web-startup-v1", "Unexpected startup contract schema")
    require(contract.get("source_commit") == expected_build_sha and contract.get("profile") == profile,
            "Startup profile/source differs from the verified export")
    expected_names = {name for name in files if Path(name).suffix in {".wasm", ".pck", ".js"}}
    actual_names = [entry["path"] for entry in contract["assets"]]
    require(len(actual_names) == len(set(actual_names)) and set(actual_names) == expected_names,
            "Startup contract omits or duplicates a runtime asset")
    for entry in contract["assets"]:
        require(entry["sha256"] == files[entry["path"]]["sha256"] and entry["size"] == files[entry["path"]]["size"],
                "Startup runtime digest/size disagrees with actual bytes: " + entry["path"])
    html = (web_root / "index.html").read_text()
    embedded = re.search(r"^const SANDFALL_WEB_EXPECTED = (.+);$", html, re.M)
    require(embedded is not None and json.loads(embedded[1]) == contract, "HTML does not bind the startup contract")
    require("await SandfallWebPreflight.run(SANDFALL_WEB_EXPECTED)" in html, "Startup preflight is not awaited")
    require(f"const GODOT_THREADS_ENABLED = {'true' if profile == 'threaded' else 'false'};" in html,
            "Godot loader thread capability differs from declared profile")
    if profile == "threaded":
        require(contract.get("worker_runtime") == "index.js", "Threaded worker runtime is not identified")
        require('new Worker(pthreadMainJs' in (web_root / "index.js").read_text(), "Pinned pthread loader is absent")
        config_match = re.search(r"^const GODOT_CONFIG = (.+);$", html, re.M)
        require(config_match is not None, "Missing Godot engine configuration")
        config = json.loads(config_match[1])
        require(config.get("emscriptenPoolSize") == 32 and config.get("godotPoolSize") == 2,
                "Threaded pool reservation differs from pinned ownership budget")
    result.update(schema="sandfall-sf-m5-web-artifact-verification-v1", startup_contract=contract)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--web-root", type=Path, required=True)
    parser.add_argument("--repo-root", type=Path, default=ROOT)
    parser.add_argument("--expected-build-sha", required=True)
    parser.add_argument("--profile", choices=("compat", "threaded"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = verify(args.web_root.resolve(), args.repo_root.resolve(), args.expected_build_sha, args.profile)
    except (VerificationError, OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        result = {"schema": "sandfall-sf-m5-web-artifact-verification-v1", "status": "failed", "error": str(error)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"status": result["status"], "error": result.get("error"), "receipt": str(args.output)}))
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
