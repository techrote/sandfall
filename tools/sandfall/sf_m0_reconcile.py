#!/usr/bin/env python3
"""SF-M0 narrow pre-build reconciliation, never a replacement release validator.

Run the original checker against the full source checkout and retain *all*
observed failures. Continue a fresh Web build only when the failures are
exactly the inherited, source-pinned absent-workspace references and stale
*desktop* DLL/SO manifests. Any new failure refuses the Web build.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]

EXPECTED_DOC_ERRORS = frozenset({
    "Q01: missing expected-fact source ../../SOURCE-PROVENANCE.json",
    "Q04: missing expected-fact source ../../docs/WEB_THREADING.md",
    "Q28: missing expected-fact source ../../tools/dev.py",
    "Q28: missing expected-fact source ../../docs/LOCAL_DEVELOPMENT.md",
    "Q29: missing expected-fact source ../../tools/dev.py",
    "Q30: missing expected-fact source ../../validation/browser-results.json",
})
DESKTOP_PLATFORMS = (
    "Windows x86_64 Godot 4.7 (actual GitHub-hosted headless execution)",
    "Linux x86_64 Godot 4.7 (actual GitHub-hosted headless execution)",
)
DESKTOP_INPUTS = (
    "godot/native_extension/cyber_demo_bridge.hpp",
    "godot/native_extension/cyber_native_cell_world.cpp",
    "godot/native_extension/cyber_native_cell_world.hpp",
    "native/include/cybersand/prepared_world.hpp",
)
EXPECTED_RUNTIME_ERRORS = frozenset(
    platform + " requires rebuild for source input: " + path
    for platform in DESKTOP_PLATFORMS
    for path in DESKTOP_INPUTS
)
EXPECTED = EXPECTED_DOC_ERRORS | EXPECTED_RUNTIME_ERRORS

def run(root: Path, output: Path) -> int:
    process = subprocess.run(
        [sys.executable, "tools/ci/check_repository.py", "--root", str(root),
         "--require-materialized"], cwd=root, text=True, capture_output=True,
        timeout=150, check=False,
    )
    record = {
        "schema": "sandfall-sf-m0-imported-checker-reconciliation-v1",
        "status": "unrecognized_failure",
        "scope": "baseline identity only; does not qualify stale desktop binary execution",
        "source_commit": subprocess.check_output(
            ["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip(),
        "exact_upstream_parent": "1d376fb38ff5df83691e468baa0639270a5f40e6",
        "checker_exit": process.returncode,
        "stderr": process.stderr[-4000:],
    }
    try:
        original = json.loads(process.stdout)
    except json.JSONDecodeError:
        original = {"errors": ["Invalid checker output"], "raw_stdout": process.stdout[-4000:]}
    errors = list(original.get("errors", []))
    record["original_checker"] = original
    record["unexpected_errors"] = sorted(set(errors) - EXPECTED)
    record["missing_expected_errors"] = sorted(EXPECTED - set(errors))
    record["current_lfs_count"] = len(original.get("materialized_runtime_files", []))
    # Document list order is not semantic: exact error contents still checked above.
    record["safe_for_fresh_web_build"] = (
        process.returncode == 1 and len(errors) == len(EXPECTED)
        and set(errors) == EXPECTED and not record["unexpected_errors"]
        and not original.get("unmaterialized_runtime_files")
        and record["current_lfs_count"] == 18
        and set(original.get("documentation", {}).get("errors", [])) == EXPECTED_DOC_ERRORS
    )
    record["status"] = "inherited_blockers_acknowledged_for_fresh_web_only" if record["safe_for_fresh_web_build"] else "refused"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps({
        "status": record["status"],
        "current_lfs_count": record["current_lfs_count"],
        "original_checker_status": original.get("status"),
        "inherited_documentation_failures": len(EXPECTED_DOC_ERRORS),
        "inherited_stale_desktop_source_digests": len(EXPECTED_RUNTIME_ERRORS),
        "unexpected_errors": record["unexpected_errors"],
        "missing_expected_errors": record["missing_expected_errors"],
        "saved": str(output),
    }))
    return 0 if record["safe_for_fresh_web_build"] else 1

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--output", type=Path, default=ROOT / "sf-m0-evidence" / "reconciliation.json")
    args = parser.parse_args()
    raise SystemExit(run(args.root.resolve(), args.output.resolve()))
