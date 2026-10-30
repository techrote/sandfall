#!/usr/bin/env python3
"""Source-bound SF-M0 native smoke; not the complete suite or a browser proof."""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import signal
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
BASELINE = "6352756931c58e702eb5c15c05d44515091274b2"
FILTERS = [
    ("render", "render", ["immutable render snapshots", "concurrent render leases"]),
    ("dirty_rectangles", "dirty rectangles", ["dirty rectangles"]),
    ("rgba", "C API and RGBA", ["C API and RGBA"]),
    ("masked_source", "physics masked source", ["physics masked source characterisation"]),
    ("body_capacity", "ACT-004", ["ACT-004 articulated body identity capacity"]),
    ("body_contact", "LCB-005 inertial body contact", ["LCB-005 inertial body contact"]),
    ("body_barrier", "LCB-001 pressure walls and body masks block head",
     ["LCB-001 pressure walls and body masks block head"]),
    ("tick_failure", "issue #1", ["issue #1 failed tick stop/reset",
     "issue #1 late failure and publication", "issue #1 C API failure/recovery"]),
    ("pause_unmask", "material deadlines pause and unmask", ["material deadlines pause and unmask"]),
]
BINARIES = ["build/tests", "build/test_soliding_lifecycle", "build/test_settled_regions"]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True,
                                   stderr=subprocess.PIPE).strip()


def paths(*args: str) -> list[str]:
    return sorted(p for p in git(*args).split("\0") if p)


def snapshot() -> dict[str, str]:
    return {p: sha256(ROOT / p) for p in paths("ls-files", "-z", "--", "native", "Makefile")}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "sf-m0-native-smoke")
    parser.add_argument("--baseline-sha", default=BASELINE)
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    record = {"schema": "sandfall-sf-m0-focused-native-v1", "status": "failed",
              "scope": "12 focused native tests plus C header/lifecycle/settled checks; not the full suite or Godot/Rapier/browser acceptance",
              "baseline_source": args.baseline_sha, "started_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
              "platform": platform.platform(), "compiler_override": os.environ.get("CXX"),
              "runner_sha256": sha256(Path(__file__)), "commands": [], "failures": []}

    def save() -> None:
        (out / "receipt.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")

    def guard() -> None:
        if git("rev-parse", "HEAD") != record["source_commit_start"]:
            raise RuntimeError("HEAD changed during native qualification")
        if snapshot() != record["inputs"]:
            raise RuntimeError("Native input bytes or tracked inventory changed during qualification")
        if sha256(Path(__file__)) != record["runner_sha256"]:
            raise RuntimeError("Native qualification runner changed during execution")
        drift = set(paths("diff", "--name-only", "--no-renames", "-z", "HEAD", "--", "native", "Makefile"))
        drift.update(paths("diff", "--cached", "--name-only", "--no-renames", "-z", "HEAD", "--", "native", "Makefile"))
        drift.update(paths("ls-files", "--others", "--exclude-standard", "-z", "--", "native", "Makefile"))
        record["native_worktree_drift"] = sorted(drift)
        if drift:
            raise RuntimeError("Native staged/unstaged/untracked inputs differ: " + ", ".join(sorted(drift)))

    def run(label: str, argv: list[str], timeout: int, expected: list[str] | None = None,
            marker: str | None = None) -> None:
        guard()
        entry = {"label": label, "argv": argv, "timeout_seconds": timeout, "log": label + ".log"}
        record["commands"].append(entry)
        save()
        started = time.monotonic()
        with (out / entry["log"]).open("w", encoding="utf-8") as log:
            process = subprocess.Popen(argv, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                entry["exit_code"] = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
                entry.update(exit_code=124, timed_out=True)
        entry["duration_seconds"] = round(time.monotonic() - started, 3)
        text = (out / entry["log"]).read_text(encoding="utf-8", errors="replace")
        entry["log_sha256"] = sha256(out / entry["log"])
        entry["passed_test_names"] = re.findall(r"^\[pass\] (.+)$", text, re.MULTILINE)
        entry["test_count"] = len(entry["passed_test_names"])
        save()
        if entry["exit_code"] != 0:
            raise RuntimeError(f"{label} exited {entry['exit_code']}; see {entry['log']}")
        if expected is not None and (entry["passed_test_names"] != expected or
                not re.search(rf"^{len(expected)} tests passed$", text, re.MULTILINE)):
            raise RuntimeError(f"{label} did not execute its exact expected test names/count")
        if marker is not None and marker not in text:
            raise RuntimeError(f"{label} omitted its expected successful terminal marker")
        guard()
        print(json.dumps({"label": label, "exit_code": 0, "tests": entry["test_count"]}), flush=True)

    save()
    try:
        if not re.fullmatch(r"[0-9a-f]{40}", args.baseline_sha):
            raise ValueError("Baseline must be a full lowercase Git SHA")
        if git("rev-parse", "--verify", args.baseline_sha + "^{commit}") != args.baseline_sha:
            raise ValueError("Baseline commit is unavailable")
        record["source_commit_start"] = git("rev-parse", "HEAD")
        record["inputs"] = snapshot()
        record["input_count"] = len(record["inputs"])
        if "Makefile" not in record["inputs"] or record["input_count"] < 2:
            raise RuntimeError("Native source input inventory is empty or incomplete")
        record["native_diff_from_full_baseline"] = paths("diff", "--name-only", "--no-renames", "-z", args.baseline_sha, "HEAD", "--", "native", "Makefile")
        if record["native_diff_from_full_baseline"]:
            raise RuntimeError("Native source differs from the retained full-suite baseline")
        run("build", ["make", "-j2", "c-header-check", *BINARIES], 600)
        for label, name_filter, expected in FILTERS:
            run(label, ["./build/tests", name_filter], 120, expected)
        run("soliding_lifecycle", ["./build/test_soliding_lifecycle"], 90,
            marker="PASS soliding lifecycle model: 384 complete transitions, 12 prepare/ack/commit guard refusals, 8 finalize quarantine guards")
        run("settled_regions", ["./build/test_settled_regions"], 90, marker="settled region tests passed")
        record["filtered_main_tests_passed"] = sum(c["test_count"] for c in record["commands"] if c["label"] in {f[0] for f in FILTERS})
        if record["filtered_main_tests_passed"] != 12:
            raise RuntimeError("Focused main-test total is not 12")
        guard()
        record["source_commit_end"] = git("rev-parse", "HEAD")
        record["artifacts"] = {p: {"size": (ROOT / p).stat().st_size, "sha256": sha256(ROOT / p)} for p in BINARIES}
        record["status"] = "passed"
    except Exception as exc:
        record["failures"].append(f"{type(exc).__name__}: {exc}")
    finally:
        record["finished_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
        save()
    print(json.dumps({"status": record["status"], "receipt": str(out / "receipt.json"), "failures": record["failures"]}))
    return 0 if record["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
