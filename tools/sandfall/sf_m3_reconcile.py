#!/usr/bin/env python3
"""Permit only the reviewed SF-M3 restore delta for fresh source builds.

The unchanged M0 and M2 reconcilers must still refuse this source checkout.
Their original records are retained. This gate does not qualify a stale desktop
binary, rewrite a manifest, or turn a build into an execution result. It admits
only the exact reviewed native patch plus the exact inherited checker failures;
fresh native/Godot/Web execution remains a separate mandatory gate.
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
from tools.sandfall import sf_m2_reconcile as m2

BASE = "32efe3142e557180b1777817f250f342b5b820de"
BASE_TREE = "ddc2e9b3c7dd30dc10f98a30aa5e50291f4c0d46"
NATIVE_SCOPES = ("native", "Makefile", "godot/native_extension")
RUNTIME_SCOPES = ("godot/addons", "godot/third_party", "third_party")
INHERITED_GATES = ("tools/sandfall/sf_m0_reconcile.py", "tools/sandfall/sf_m2_reconcile.py",
                   "tools/sandfall/sf_m0_native_smoke.py", "tools/sandfall/sf_m2_ci.sh",
                   "tools/ci/check_repository.py", "tools/ci/check_docs.py")
# Reviewed restore-only occupancy construction and its registered native test.
# Updating any byte or protected path requires a new independent delta review.
REVIEWED_NATIVE_SHA256: dict[str, str] = {
    "godot/native_extension/cyber_demo_bridge.hpp": "822171492650882b14fbb36b11436a5d80bc938ad3c1e31ee3b9b3422113ff91",
    "godot/native_extension/cyber_native_cell_world.cpp": "113d3eca82d975122cff4cf8733ce6d4c15d2e4ba73fd0ebed2b8d7702c8d23b",
    "godot/native_extension/cyber_native_cell_world.hpp": "0028be999b1a39d584670f8df3e51bab291b367545d7800ae20dc1ec07f614c7",
    "native/include/cybersand/world.hpp": "767615d9ff0e37c482d1127bb123ce6d66957dff1b094febc1486cd46f33ac8f",
    "native/src/world_pressure.inc": "b60823316d813bf712ace04a961bc83e3e00dff110da90b58905bbe9d242ba08",
    "native/tests/test_world.cpp": "ae7667e1e3ac2872db457c9ab513e063d017a126c8466a3ea36293a6fda21812"
}
REVIEWED_BASE_SHA256: dict[str, str | None] = {
    "godot/native_extension/cyber_demo_bridge.hpp": "bbfb59ad74c9156b3b70d5c973159d9d1a5a4f9cf2865620a1ca273036084371",
    "godot/native_extension/cyber_native_cell_world.cpp": "0085475d766b78efc7635ccea4089aeea00b16ba4e7f880046287e55a4f82163",
    "godot/native_extension/cyber_native_cell_world.hpp": "910f3981115853ff56abbd3e6dad06e8022f10d17e179b8c3f26bede89bed7fb",
    "native/include/cybersand/world.hpp": "c2299260851d003471977f9175b5f452c9badb277d07e056db148329faec55e9",
    "native/src/world_pressure.inc": "c8cb11512e935d05e099d8f155c1659473a7f61aa301e2e4900e55bdcfe4024b",
    "native/tests/test_world.cpp": "761df87f755d8678ef03aab805783b5ab7c0a15a1eda9e03b5640a826245498a"
}
REVIEWED_NATIVE_PATCH_SHA256 = '96f0f6dcb3a9d7eb20d5f924cf378cfc87aadcacb367e42bb431aa84a9618917'
NEW_DESKTOP_INPUTS = ("native/include/cybersand/world.hpp", "native/src/world_pressure.inc")
NEW_ERRORS = frozenset(platform + " requires rebuild for source input: " + path
                       for platform in m2.m0.DESKTOP_PLATFORMS
                       for path in NEW_DESKTOP_INPUTS)
EXPECTED = m2.EXPECTED | NEW_ERRORS


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
    original = record.get("original_checker", {})
    errors = original.get("errors", [])
    old_checks = record.get("source_checks", {})
    safe = (record.get("checker_exit") == 1 and original.get("status") == "failed"
            and record.get("status") == "refused"
            and record.get("original_m0_disposition") == "refused"
            and record.get("safe_for_fresh_web_build") is False
            and len(errors) == len(EXPECTED) and set(errors) == EXPECTED
            and set(original.get("documentation", {}).get("errors", [])) == m2.m0.EXPECTED_DOC_ERRORS
            and record.get("current_lfs_count") == 18 and not original.get("unmaterialized_runtime_files")
            and old_checks.get("exact_registration_delta") is True
            and old_checks.get("unchanged_runtime_payloads_and_manifests") is True
            and old_checks.get("unchanged_native_core") is False
            and all(checks.get(key) is True for key in (
                "exact_baseline_tree", "baseline_is_ancestor", "no_untracked_native_sources",
                "exact_reviewed_native_delta", "unchanged_runtime_payloads_manifests_and_pins",
                "unchanged_inherited_gates")))
    return {
        "schema": "sandfall-sf-m3-fresh-build-reconciliation-v1",
        "status": "reviewed_restore_delta_retained_for_fresh_build_only" if safe else "refused",
        "safe_for_fresh_web_build": safe,
        "scope": "fresh native/Godot/Web rebuild admission only; stale desktop execution, threaded Web and human acceptance remain unqualified",
        "source_commit": record.get("source_commit"),
        "inherited_documentation_failures": 6,
        "inherited_stale_desktop_digests": 8,
        "sf_m2_registration_desktop_errors": sorted(m2.NEW_ERRORS),
        "sf_m3_restore_desktop_errors": sorted(NEW_ERRORS),
        "expected_checker_error_count": len(EXPECTED),
        "unexpected_errors": sorted(set(errors) - EXPECTED),
        "missing_expected_errors": sorted(EXPECTED - set(errors)),
        "current_lfs_count": record.get("current_lfs_count"),
        "original_m0_disposition": record.get("original_m0_disposition"),
        "original_m2_disposition": record.get("status"),
        "original_m2_reconciliation": record,
        "source_checks": checks,
    }


def run(root: Path, output: Path) -> int:
    output.parent.mkdir(parents=True, exist_ok=True)
    m2_output = output.with_name(output.stem + "-original-m2-refusal.json")
    m2.run(root, m2_output)
    record = json.loads(m2_output.read_text())
    checks, patch = source_identity(root)
    result = classify(record, checks)
    patch_output = output.with_name(output.stem + "-reviewed-native.patch")
    patch_output.write_bytes(patch)
    result["original_m2_record"] = {"path": str(m2_output), "sha256": digest(m2_output.read_bytes())}
    result["native_patch_record"] = {"path": str(patch_output), "sha256": digest(patch), "bytes": len(patch)}
    output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"status": result["status"], "expected_errors": len(EXPECTED),
                      "original_m0_status": result["original_m0_disposition"],
                      "original_m2_status": result["original_m2_disposition"],
                      "unexpected_errors": result["unexpected_errors"],
                      "missing_expected_errors": result["missing_expected_errors"],
                      "source_checks": checks, "saved": str(output)}))
    return 0 if result["safe_for_fresh_web_build"] else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--output", type=Path, default=ROOT / "sf-m3-evidence/reconciliation.json")
    args = parser.parse_args()
    raise SystemExit(run(args.root.resolve(), args.output.resolve()))
