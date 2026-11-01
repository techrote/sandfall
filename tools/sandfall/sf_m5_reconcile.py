#!/usr/bin/env python3
"""SF-M5 exact additive worker-observation delta; preserve every older refusal.

Build admission only. Independent review and actual-browser qualification remain
mandatory. No stale desktop runtime is relabelled as source matched.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.sandfall import sf_m3_reconcile as m3
BASE = "ec94dfa50525135375dd6e35d1c5fca55c412544"
BASE_TREE = "fb077c33386a6020d9eef91304227304cd135513"
NATIVE_SCOPES = m3.NATIVE_SCOPES
RUNTIME_SCOPES = m3.RUNTIME_SCOPES
INHERITED_GATES = (*m3.INHERITED_GATES, "tools/sandfall/sf_m3_reconcile.py")
REVIEWED_BASE_SHA256 = {
    "godot/native_extension/cyber_native_cell_world.cpp": "113d3eca82d975122cff4cf8733ce6d4c15d2e4ba73fd0ebed2b8d7702c8d23b",
    "godot/native_extension/cyber_native_cell_world.hpp": "0028be999b1a39d584670f8df3e51bab291b367545d7800ae20dc1ec07f614c7",
}
REVIEWED_NATIVE_SHA256 = {
    "godot/native_extension/cyber_native_cell_world.cpp": "3a81c1e5f3e5f6d2c15d4df1a8f96796c9f5ec04fc42c15b483b084dfc012a61",
    "godot/native_extension/cyber_native_cell_world.hpp": "3cb45e7012b8d11a44d4a28c94cbedb9d989ebcdc1bd87d99f7e7ae0c319e5f1",
}
REVIEWED_NATIVE_PATCH_SHA256 = "8e52ba731b4257cbfc29b0e5ce4e8e81724b425e5c7112744362905c3412f38b"
REQUIRED_CHECKS = ("exact_baseline_tree", "baseline_is_ancestor", "no_untracked_native_sources",
                   "exact_reviewed_native_delta", "unchanged_runtime_payloads_manifests_and_pins", "unchanged_inherited_gates")
EXPECTED = m3.EXPECTED

def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def approved_native_delta(before: dict[str, str | None], after: dict[str, str],
                          changed: list[str], patch_sha256: str) -> bool:
    """Exact identities, file set and patch; no path-only allowance is sufficient."""
    return (bool(REVIEWED_NATIVE_SHA256)
            and before == REVIEWED_BASE_SHA256
            and after == REVIEWED_NATIVE_SHA256
            and len(changed) == len(REVIEWED_NATIVE_SHA256)
            and set(changed) == set(REVIEWED_NATIVE_SHA256)
            and patch_sha256 == REVIEWED_NATIVE_PATCH_SHA256)


def source_identity(root: Path) -> tuple[dict, bytes]:
    def git(*args: str) -> bytes:
        return subprocess.check_output(["git", "-C", str(root), *args], stderr=subprocess.PIPE)

    checks: dict = {"baseline": BASE}
    patch = b""
    try:
        checks["baseline_tree"] = git("rev-parse", BASE + "^{tree}").decode().strip()
        checks["exact_baseline_tree"] = checks["baseline_tree"] == BASE_TREE
        checks["baseline_is_ancestor"] = subprocess.run(
            ["git", "-C", str(root), "merge-base", "--is-ancestor", BASE, "HEAD"],
            check=False, capture_output=True).returncode == 0
        changed = git("diff", "--name-only", "-z", BASE, "--", *NATIVE_SCOPES)
        checks["changed_native_paths"] = sorted(p.decode() for p in changed.split(b"\0") if p)
        # Nontracked source cannot slip past Git's patch identity. Ignored build
        # objects are harmless, but an ignored new C++/build script is not.
        untracked = git("ls-files", "--others", "--exclude-standard", "-z", "--", *NATIVE_SCOPES)
        ignored = git("ls-files", "--others", "--ignored", "--exclude-standard", "-z", "--", *NATIVE_SCOPES)
        ignored_sources = [p.decode() for p in ignored.split(b"\0") if p
                           and (Path(p.decode()).suffix in {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".ipp", ".py"}
                                or Path(p.decode()).name in {"SConstruct", "SCsub", "Makefile", "CMakeLists.txt"})]
        checks["untracked_native_paths"] = sorted(p.decode() for p in untracked.split(b"\0") if p)
        checks["ignored_native_source_paths"] = sorted(ignored_sources)
        checks["no_untracked_native_sources"] = not untracked and not ignored_sources
        patch = git("diff", "--no-ext-diff", "--no-textconv", "--no-color", "--no-renames",
                    "--binary", "--full-index", "--unified=3", "--src-prefix=a/", "--dst-prefix=b/",
                    BASE, "--", *NATIVE_SCOPES)
        checks["native_patch_sha256"] = digest(patch)
        before = {}
        for path, expected in REVIEWED_BASE_SHA256.items():
            if expected is None:
                before[path] = None if not git("ls-tree", BASE, "--", path).strip() else "unexpected baseline file"
            else:
                before[path] = digest(git("show", BASE + ":" + path))
        after = {p: digest((root / p).read_bytes()) for p in REVIEWED_NATIVE_SHA256}
        checks["baseline_source_sha256"] = before
        checks["current_source_sha256"] = after
        checks["exact_reviewed_native_delta"] = approved_native_delta(
            before, after, checks["changed_native_paths"], checks["native_patch_sha256"])
        runtime_diff = git("diff", "--name-only", "-z", BASE, "--", *RUNTIME_SCOPES)
        runtime_new = git("ls-files", "--others", "--exclude-standard", "-z", "--", *RUNTIME_SCOPES)
        checks["changed_runtime_paths"] = sorted(p.decode() for p in runtime_diff.split(b"\0") if p)
        checks["untracked_runtime_paths"] = sorted(p.decode() for p in runtime_new.split(b"\0") if p)
        checks["unchanged_runtime_payloads_manifests_and_pins"] = not runtime_diff and not runtime_new
        inherited_diff = git("diff", "--name-only", "-z", BASE, "--", *INHERITED_GATES)
        checks["changed_inherited_gate_paths"] = sorted(p.decode() for p in inherited_diff.split(b"\0") if p)
        checks["unchanged_inherited_gates"] = not inherited_diff
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        checks["error"] = str(exc)
    return checks, patch


def classify(record: dict, checks: dict) -> dict:
    old = record.get("original_m2_reconciliation", {})
    original = old.get("original_checker", {})
    errors = original.get("errors", [])
    prior_checks = record.get("source_checks", {})
    # The M3 guard must refuse specifically because its exact native patch has
    # changed. Every independent inherited byte/pin/provenance condition remains.
    safe = (record.get("status") == "refused" and record.get("safe_for_fresh_web_build") is False
            and record.get("original_m0_disposition") == "refused"
            and record.get("original_m2_disposition") == "refused"
            and record.get("current_lfs_count") == 18
            and prior_checks.get("exact_reviewed_native_delta") is False
            and all(prior_checks.get(key) is True for key in REQUIRED_CHECKS if key != "exact_reviewed_native_delta")
            and m3.classify(old, {**prior_checks, "exact_reviewed_native_delta": True})["safe_for_fresh_web_build"] is True
            and len(errors) == len(EXPECTED) and set(errors) == EXPECTED
            and all(checks.get(key) is True for key in REQUIRED_CHECKS))
    return {
        "schema": "sandfall-sf-m5-fresh-build-reconciliation-v1",
        "status": "reviewed_observation_delta_retained_for_fresh_build_only" if safe else "refused",
        "safe_for_fresh_web_build": safe,
        "scope": "exact additive native getter; fresh build admission only; all runtime/release gates separate",
        "source_commit": record.get("source_commit"), "current_lfs_count": record.get("current_lfs_count"),
        "expected_checker_error_count": len(EXPECTED),
        "unexpected_errors": sorted(set(errors) - EXPECTED),
        "missing_expected_errors": sorted(EXPECTED - set(errors)),
        "original_m0_disposition": record.get("original_m0_disposition"),
        "original_m2_disposition": record.get("original_m2_disposition"),
        "original_m3_disposition": record.get("status"),
        "original_m3_reconciliation": record, "source_checks": checks,
    }


def run(root: Path, output: Path) -> int:
    output.parent.mkdir(parents=True, exist_ok=True)
    prior = output.with_name(output.stem + "-original-m3-refusal.json")
    m3.run(root, prior)
    original = json.loads(prior.read_text())
    checks, patch = source_identity(root)
    result = classify(original, checks)
    patch_output = output.with_name(output.stem + "-reviewed-native.patch")
    patch_output.write_bytes(patch)
    result["original_m3_record"] = {"path": str(prior), "sha256": digest(prior.read_bytes())}
    result["native_patch_record"] = {"path": str(patch_output), "sha256": digest(patch), "bytes": len(patch)}
    output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"status": result["status"], "source_checks": checks,
                      "unexpected_errors": result["unexpected_errors"], "missing_expected_errors": result["missing_expected_errors"],
                      "saved": str(output)}))
    return 0 if result["safe_for_fresh_web_build"] else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--output", type=Path, default=ROOT / "build/sf-m5/reconciliation.json")
    args = parser.parse_args()
    raise SystemExit(run(args.root.resolve(), args.output.resolve()))
