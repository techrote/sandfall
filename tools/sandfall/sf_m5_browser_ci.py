#!/usr/bin/env python3
"""Run an existing strict Sandfall browser oracle against either verified profile.

Every invocation owns an ephemeral HTTP port, an isolated Chromium process
group and a unique output directory. Compatibility uses no isolation headers.
This runner supplies no application mutations; the selected harness owns its
trusted input, source-derived geometry, physical assertions and terminal capture.
"""
from __future__ import annotations

import argparse
from functools import partial
import hashlib
from http.server import ThreadingHTTPServer
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.serve_web import WebHandler
from tools.sandfall.sf_m5_verify_web_artifact import verify

SUITES = {
    "m1": ("sf_m1_browser.mjs", 1200000),
    "m2": ("sf_m2_browser.mjs", 1200000),
    "workshop": ("sf_m3_browser.mjs", 540000),
    "projects": ("sf_m4_browser.mjs", 1620000),
    "gallery": ("sf_m4_browser.mjs", 1620000),
    "science": ("sf_m5_scientific_browser.mjs", 420000),
    "performance": ("sf_m5_performance.mjs", 420000),
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require_clean_tracked_source(verification: dict) -> None:
    """Qualification executes committed harness bytes as well as build inputs."""
    source = verification.get("source_equivalence")
    if verification.get("status") != "passed" or not isinstance(source, dict):
        raise RuntimeError("Missing passing source/artifact verification")
    for key in ("tracked_dirty_paths", "staged_changed_paths", "unstaged_changed_paths",
                "build_sensitive_changed_paths"):
        if source.get(key) != []:
            raise RuntimeError("Qualification requires clean tracked source: " + key)


def compare_verifications(before: dict, after: dict, repo_root: Path, owned_output: Path) -> dict:
    """Permit only this invocation's newly created, non-source evidence files.

    Both original receipts remain intact. Every other verifier field, including
    the full artifact inventory/hashes and all outside untracked paths, must be
    identical. The caller created owned_output with exist_ok=False.
    """
    require_clean_tracked_source(before)
    require_clean_tracked_source(after)
    try:
        relative = owned_output.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        relative = None  # An external output cannot add any repository path.
    if relative == ".":
        raise RuntimeError("The repository cannot be its own evidence directory")
    prefix = relative + "/" if relative is not None else None

    def comparable(receipt: dict) -> tuple[dict, list[str]]:
        source = receipt["source_equivalence"]
        paths = source.get("untracked_paths")
        if not isinstance(paths, list) or any(not isinstance(path, str) for path in paths):
            raise RuntimeError("Malformed untracked source inventory")
        owned = [path for path in paths if prefix is not None and path.startswith(prefix)]
        other = [path for path in paths if path not in owned]
        return {**receipt, "source_equivalence": {**source, "untracked_paths": other}}, owned

    initial, initial_owned = comparable(before)
    terminal, terminal_owned = comparable(after)
    if initial != terminal:
        raise RuntimeError("Source/artifact verification changed outside this invocation's evidence directory")
    return {"owned_output_relative": relative, "owned_untracked_before": initial_owned,
            "owned_untracked_after": terminal_owned, "all_other_verifier_fields_identical": True}


def retain_post_verification(path: Path, web_root: Path, repo_root: Path, build_sha: str, profile: str) -> dict:
    """Retain the terminal verifier result, including a precise failed attempt."""
    try:
        result = verify(web_root, repo_root, build_sha, profile)
    except Exception as exc:
        path.write_text(json.dumps({"schema": "sandfall-sf-m5-post-verification-failure-v1",
                                    "status": "failed", "build_source_commit": build_sha, "profile": profile,
                                    "error": f"{type(exc).__name__}: {exc}"}, indent=2) + "\n")
        raise
    path.write_text(json.dumps(result, indent=2) + "\n")
    return result


def stop_group(child: subprocess.Popen | None) -> None:
    if child is None:
        return
    # Always address this invocation's group, including surviving grandchildren
    # after a browser controller exits. Never kill another owner's browser.
    try:
        os.killpg(child.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        child.wait(timeout=10)
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(child.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    child.wait(timeout=5)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--web-root", type=Path, required=True)
    parser.add_argument("--profile", choices=("compat", "threaded"), required=True)
    parser.add_argument("--workers", type=int, choices=(1, 2, 4, 6), required=True)
    parser.add_argument("--build-sha", required=True)
    parser.add_argument("--chrome", type=Path, required=True)
    parser.add_argument("--suite", choices=SUITES, required=True)
    parser.add_argument("--width", type=int, choices=(800, 640), required=True)
    parser.add_argument("--height", type=int, choices=(450, 400), required=True)
    parser.add_argument("--dpr", type=int, choices=(1, 2), required=True)
    parser.add_argument("--bodies", type=int, choices=(0, 1, 3, 8, 16), default=16)
    parser.add_argument("--gallery-entry")
    parser.add_argument("--workload", choices=("blank", "material_lab", "sixteen_body"), default="sixteen_body")
    parser.add_argument("--duration-ms", type=int, default=30000)
    parser.add_argument("--repetition", type=int, default=1)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if (args.width, args.height, args.dpr) not in ((800, 450, 1), (640, 400, 2)):
        parser.error("Select one of the two established viewport/DPR contracts")
    if args.profile == "compat" and args.workers != 1:
        parser.error("Compatibility qualification requires one native worker")
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    record = {"schema": "sandfall-sf-m5-browser-orchestrator-v1", "status": "failed",
              "source_commit": args.build_sha, "profile": args.profile, "suite": args.suite,
              "workers_requested": args.workers, "viewport": [args.width, args.height, args.dpr],
              "orchestrator_sha256": digest(Path(__file__)), "failure": None}
    server = None
    thread = None
    chrome = None
    harness = None
    chrome_profile = out / "chrome-profile"
    started = time.monotonic()
    http_log = (out / "http.log").open("w")
    try:
        verification = verify(args.web_root.resolve(), ROOT, args.build_sha, args.profile)
        verification_path = out / "artifact-verification.json"
        verification_path.write_text(json.dumps(verification, indent=2) + "\n")
        record["verification_sha256"] = digest(verification_path)
        require_clean_tracked_source(verification)
        record["harness_head"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()

        class Handler(WebHandler):
            def log_message(self, fmt: str, *values: object) -> None:
                http_log.write((fmt % values) + "\n")
                http_log.flush()

        server = ThreadingHTTPServer(("127.0.0.1", 0), partial(Handler, directory=str(args.web_root.resolve())))
        server.daemon_threads = True
        server.isolation = args.profile == "threaded"
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        url = f"http://127.0.0.1:{server.server_port}/?test=1&workers={args.workers}"
        record.update(url=url, isolation_headers=server.isolation)
        command = [str(args.chrome.resolve()), "--headless=new", "--no-sandbox", "--disable-dev-shm-usage",
                   "--enable-unsafe-swiftshader", "--use-gl=angle", "--use-angle=swiftshader",
                   "--remote-debugging-address=127.0.0.1", "--remote-debugging-port=0",
                   "--user-data-dir=" + str(chrome_profile), "about:blank"]
        record["chrome_command"] = command
        with (out / "chrome.log").open("w") as log:
            chrome = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        deadline = time.monotonic() + 30
        while True:
            active = chrome_profile / "DevToolsActivePort"
            if active.is_file():
                port = int(active.read_text().splitlines()[0])
                break
            if chrome.poll() is not None:
                raise RuntimeError("Browser exited before exposing its isolated CDP port")
            if time.monotonic() >= deadline:
                raise TimeoutError("Browser did not expose a CDP port in 30 seconds")
            time.sleep(0.1)
        name, budget = SUITES[args.suite]
        extra = []
        if args.suite in ("projects", "gallery"):
            extra = ["--scenario", args.suite, "--download-dir", str(out / "downloads")]
        if args.gallery_entry:
            if args.suite != "gallery":
                raise ValueError("A Gallery entry belongs only to the Gallery suite")
            extra += ["--gallery-entry", args.gallery_entry]
            budget = 540000
        if args.suite == "performance":
            extra += ["--profile", args.profile, "--workers", str(args.workers), "--workload", args.workload,
                      "--duration-ms", str(args.duration_ms), "--repetition", str(args.repetition)]
        command = ["node", str(ROOT / "tools/sandfall" / name), "--port", str(port), "--url", url,
                   "--verification", str(verification_path), "--width", str(args.width), "--height", str(args.height),
                   "--dpr", str(args.dpr), "--bodies", str(args.bodies), "--output", str(out / "browser.json"),
                   "--screenshot", str(out / "browser.png"), "--timeout-ms", str(budget), *extra]
        record["harness_command"] = command
        with (out / "harness.log").open("w") as log:
            harness = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            # Preserve the inherited phase and terminal-capture budgets. This
            # bound is their sum, not a retry or a wider physics acceptance.
            record["harness_exit"] = harness.wait(timeout=budget / 1000 + 240)
        browser = json.loads((out / "browser.json").read_text())
        if record["harness_exit"] != 0 or browser.get("status") != "passed":
            raise RuntimeError("Browser oracle failed; original receipt, captures and logs retained")
        after_path = out / "artifact-verification-after.json"
        try:
            after = retain_post_verification(after_path, args.web_root.resolve(), ROOT, args.build_sha, args.profile)
        finally:
            if after_path.is_file():
                record["post_verification_sha256"] = digest(after_path)
        record["verification_comparison"] = compare_verifications(verification, after, ROOT, out)
        if subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip() != record["harness_head"]:
            raise RuntimeError("Harness source HEAD changed during qualification")
        record.update(status="passed", browser_receipt_sha256=digest(out / "browser.json"))
    except Exception as exc:
        record["failure"] = f"{type(exc).__name__}: {exc}"
    finally:
        stop_group(harness)
        stop_group(chrome)
        if server is not None:
            server.shutdown()
            server.server_close()
        if thread is not None:
            thread.join(timeout=5)
        http_log.close()
        if chrome_profile.exists():
            shutil.rmtree(chrome_profile)
        record["duration_seconds"] = time.monotonic() - started
        (out / "result.json").write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps(record))
    return 0 if record["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
