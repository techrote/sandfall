#!/usr/bin/env python3
"""Source-matched SF-M5 browser bootstrap and adverse static-host runner.

Each invocation owns one isolated browser process group, one ephemeral loopback
HTTP listener, and one immutable source export. Adverse responses are generated
in the host; application state and Web platform capabilities are never mocked.
The threaded worker is the pinned engine's index.js, not a fictitious worker.js.
"""
from __future__ import annotations

import argparse
import hashlib
import http.server
import json
import mimetypes
import os
from pathlib import Path
import re
import shutil
import signal
import socketserver
import subprocess
import threading
import time
import urllib.parse


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n")


def verify_export(root: Path, receipt: dict) -> tuple[list[dict], dict[str, bytes]]:
    if receipt.get("status") != "passed" or receipt.get("profile") not in ("compat", "threaded"):
        raise ValueError("A passed profile-specific independent export verifier receipt is required")
    manifest = root / "SHA256SUMS"
    manifest_bytes = manifest.read_bytes()
    if sha256(manifest_bytes) != receipt["manifest_sha256"]:
        raise ValueError("Export SHA256SUMS differs from its passed verifier")
    rows = receipt["artifacts"]
    if not rows or len({row["path"] for row in rows}) != len(rows):
        raise ValueError("Artifact inventory is absent or ambiguous")
    immutable = {"SHA256SUMS": manifest_bytes}
    for row in rows:
        rel = Path(row["path"])
        if rel.is_absolute() or ".." in rel.parts:
            raise ValueError("Unsafe export inventory path")
        path = root / rel
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"Export asset is not a regular file: {rel}")
        data = path.read_bytes()
        if len(data) != row["size"] or sha256(data) != row["sha256"]:
            raise ValueError(f"Export bytes differ from passed verifier: {rel}")
        immutable[row["path"]] = data
    return rows, immutable


CASES = ("positive", "toctou", "compat-no-isolation",
         "no-isolation", "no-coop", "no-coep", "insecure-origin",
         "missing-rapier", "corrupt-rapier", "missing-worker", "corrupt-worker",
         "missing-pck", "corrupt-pck", "hash-rapier", "hash-worker", "hash-pck",
         "bad-mime", "worker-blocked", "invalid-workers", "duplicate-workers")
TARGETS = {"rapier": "godot_rapier.wasm", "worker": "index.js", "pck": "index.pck"}


def refusal_pattern(case: str) -> str:
    if case in ("no-isolation", "no-coop", "no-coep"):
        return "requires COOP same-origin and COEP require-corp"
    if case == "insecure-origin":
        return r"Sandfall Web requires HTTPS or a loopback secure origin \(Godot 4\.7\)"
    if case.startswith("missing-"):
        return "Missing runtime asset: " + re.escape(TARGETS[case.removeprefix("missing-")])
    if case.startswith(("corrupt-", "hash-")):
        return "Runtime SHA-256/size mismatch: " + re.escape(TARGETS[case.split("-", 1)[-1]])
    if case == "bad-mime":
        return "Incorrect MIME for index\\.pck"
    if case == "worker-blocked":
        return "(Worker startup refused|Failed to construct 'Worker'|violates the following Content Security Policy directive)"
    if case == "invalid-workers":
        return "(Supported native worker requests: auto, 1, 2, 4, 6|Requested native workers exceed reported logical processors|Compatibility Web supports exactly one native worker)"
    if case == "duplicate-workers":
        return "Duplicate native worker request"
    return ""


class EvidenceHost(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True


def stop_group(child: subprocess.Popen | None) -> None:
    """Retire this invocation's process group even if its controller exited."""
    if child is None:
        return
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
    parser.add_argument("--verification", type=Path, required=True)
    parser.add_argument("--chrome", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True, help="Unique directory for this case")
    parser.add_argument("--case", choices=CASES, default="positive")
    parser.add_argument("--workers", default="1")
    parser.add_argument("--workload", choices=("material_lab", "sixteen_body"), default="sixteen_body")
    parser.add_argument("--width", type=int, default=800)
    parser.add_argument("--height", type=int, default=450)
    parser.add_argument("--dpr", type=int, choices=(1, 2), default=1)
    parser.add_argument("--ticks", type=int, default=60)
    parser.add_argument("--timeout-ms", type=int, default=240000)
    parser.add_argument("--path-prefix", default="", help="Optional ordinary subfolder hosting path")
    args = parser.parse_args()
    root = args.web_root.resolve()
    verification_bytes = args.verification.read_bytes()
    verification_sha256 = sha256(verification_bytes)
    verification = json.loads(verification_bytes)
    inventory, immutable = verify_export(root, verification)
    orchestrator_sha256 = sha256(Path(__file__).read_bytes())
    if args.case.startswith("compat-") and (verification["profile"] != "compat" or args.workers != "1"):
        raise ValueError("Unisolated compatibility positives require the compatibility export and exactly one worker")
    prefix = "/" + args.path_prefix.strip("/") if args.path_prefix.strip("/") else ""
    if prefix and not re.fullmatch(r"/[a-zA-Z0-9_-]+(?:/[a-zA-Z0-9_-]+)*", prefix):
        raise ValueError("Hosting prefix must contain ordinary path segments")
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    verification_copy = out / "artifact-verification.json"
    verification_copy.write_bytes(verification_bytes)
    # Serve the exact byte objects that passed verification, without another
    # filesystem read between their custody check and HTTP delivery.
    log: list[dict] = []
    counts: dict[str, int] = {}
    lock = threading.Lock()
    started = time.monotonic()

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *_: object) -> None:
            pass

        def do_GET(self) -> None:
            parsed = urllib.parse.urlsplit(self.path)
            path = urllib.parse.unquote(parsed.path)
            rel = path.removeprefix(prefix + "/") if path.startswith(prefix + "/") else ""
            if path in (prefix, prefix + "/"):
                rel = "index.html"
            with lock:
                counts[rel] = counts.get(rel, 0) + 1
                ordinal = counts[rel]
            status = 200
            data = immutable.get(rel)
            served_kind = "verified-original"
            if data is None:
                data = b"Unknown static resource\n"
                status = 404
                served_kind = "not-found"
            target = TARGETS.get(args.case.split("-", 1)[-1])
            if args.case.startswith("missing-") and rel == target:
                data, status, served_kind = b"Deliberately absent runtime asset\n", 404, "required-asset-absent"
            elif args.case.startswith("corrupt-") and rel == target:
                data, served_kind = b"SF-M5 deliberately corrupted runtime asset\n", "required-asset-corrupt"
            elif args.case.startswith("hash-") and rel == target:
                changed = bytearray(data)
                changed[len(changed) // 2] ^= 1
                data, served_kind = bytes(changed), "same-size-hash-mismatch"
            elif args.case == "toctou" and ordinal > 1 and rel.endswith((".wasm", ".pck", ".js")):
                data, served_kind = b"SF-M5 changed second host response\n", "second-response-substituted"
            content_type = {".wasm": "application/wasm", ".pck": "application/octet-stream", ".js": "application/javascript"}.get(
                Path(rel).suffix, mimetypes.guess_type(rel)[0] or "application/octet-stream")
            if args.case == "bad-mime" and rel == "index.pck":
                content_type, served_kind = "text/plain", "incorrect-runtime-mime"
            with lock:
                log.append({"path": rel, "request_path": self.path, "ordinal": ordinal,
                            "elapsed_ms": (time.monotonic() - started) * 1000, "status": status,
                            "mime": content_type, "bytes": len(data), "sha256": sha256(data), "kind": served_kind})
            try:
                self.send_response(status)
                self.send_header("Content-Type", content_type)
                self.send_header("Content-Length", str(len(data)))
                self.send_header("Cache-Control", "no-store")
                if args.case not in ("no-isolation", "no-coop", "compat-no-isolation"):
                    self.send_header("Cross-Origin-Opener-Policy", "same-origin")
                if args.case not in ("no-isolation", "no-coep", "compat-no-isolation"):
                    self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
                self.send_header("Cross-Origin-Resource-Policy", "same-origin")
                if args.case == "worker-blocked":
                    self.send_header("Content-Security-Policy", "worker-src 'none'")
                self.end_headers()
                self.wfile.write(data)
            except (BrokenPipeError, ConnectionResetError):
                # A precise refusal can cancel other already-started fetches.
                pass

    server = EvidenceHost(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, name="sf-m5-evidence-http", daemon=True)
    thread.start()
    insecure_origin = args.case == "insecure-origin"
    host = "sandfall.invalid" if insecure_origin else "127.0.0.1"
    query = "test=1&workers=" + urllib.parse.quote(args.workers)
    if args.case == "duplicate-workers":
        query += "&workers=2"
    url = f"http://{host}:{server.server_port}{prefix}/?{query}"
    profile = out / "chrome-profile"
    chrome_cmd = [str(args.chrome.resolve()), "--headless=new", "--no-sandbox", "--disable-dev-shm-usage",
                  "--enable-unsafe-swiftshader", "--use-gl=angle", "--use-angle=swiftshader",
                  "--remote-debugging-port=0", "--remote-debugging-address=127.0.0.1",
                  "--user-data-dir=" + str(profile), "--no-proxy-server"]
    if insecure_origin:
        chrome_cmd += ["--host-resolver-rules=MAP sandfall.invalid 127.0.0.1"]
    chrome_cmd.append("about:blank")
    child = None
    failure = None
    exit_code = None
    node_cmd: list[str] = []
    browser = None
    try:
        with (out / "chrome.log").open("w") as chrome_log:
            child = subprocess.Popen(chrome_cmd, stdout=chrome_log, stderr=subprocess.STDOUT, start_new_session=True)
        until = time.monotonic() + 30
        while time.monotonic() < until:
            active = profile / "DevToolsActivePort"
            if active.is_file():
                cdp_port = int(active.read_text().splitlines()[0])
                break
            if child.poll() is not None:
                raise RuntimeError(f"Chromium exited before CDP discovery: {child.returncode}")
            time.sleep(0.1)
        else:
            raise TimeoutError("Chromium CDP port discovery exceeded 30 seconds")
        positive = args.case in ("positive", "toctou", "compat-no-isolation")
        harness = Path(__file__).with_name("sf_m5_bootstrap_browser.mjs").resolve()
        node_cmd = ["node", str(harness), "--port", str(cdp_port), "--url", url, "--output", str(out / "browser.json"),
                    "--expect", "positive" if positive else "refused", "--case", args.case,
                    "--verification", str(verification_copy), "--workers", args.workers, "--workload", args.workload,
                    "--width", str(args.width), "--height", str(args.height), "--dpr", str(args.dpr),
                    "--ticks", str(args.ticks), "--timeout-ms", str(args.timeout_ms)]
        if not positive:
            node_cmd += ["--refusal-pattern", refusal_pattern(args.case)]
        with (out / "harness.log").open("w") as harness_log:
            result = subprocess.run(node_cmd, stdout=harness_log, stderr=subprocess.STDOUT,
                                    timeout=args.timeout_ms / 1000 + 45)
        exit_code = result.returncode
        if (out / "browser.json").is_file():
            browser = json.loads((out / "browser.json").read_text())
        if exit_code or browser is None or browser.get("status") != "passed":
            raise RuntimeError(f"Actual browser case failed (exit={exit_code}); see original browser receipt and logs")
        if browser.get("verification_sha256") != verification_sha256:
            raise RuntimeError("Browser verifier identity changed from the immutable host inventory")
        if args.case == "toctou":
            probes = {row["path"] for row in browser["corruption_probes"]}
            if len(probes) != 4:
                raise RuntimeError("TOCTOU case did not probe all four intentionally changed host responses")
            for path, count in counts.items():
                if path.endswith((".wasm", ".pck", ".js")) and count != (2 if path in probes else 1):
                    raise RuntimeError(f"Runtime unexpectedly re-fetched host bytes outside verified cache: {path} ({count})")
    except Exception as error:
        failure = str(error)
    finally:
        stop_group(child)
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)
        # Only this case's newly created browser cache is disposable. Original
        # observations, screenshots, host replies and failure logs are retained.
        if profile.exists():
            shutil.rmtree(profile)
        write_json(out / "host.json", {"schema": "sandfall-sf-m5-bootstrap-host-v1", "case": args.case, "url": url,
                   "source_commit": verification["build_source_commit"], "profile": verification["profile"],
                   "verification_sha256": verification_sha256, "requests": log, "counts": counts,
                   "source_assets": inventory, "file_mutations": False,
                   "adverse_response_scope": "HTTP responses only; Web platform and application state unchanged"})
        receipt = {"schema": "sandfall-sf-m5-bootstrap-orchestrator-v1", "status": "failed" if failure else "passed",
                   "case": args.case, "failure": failure, "source_commit": verification["build_source_commit"],
                   "profile": verification["profile"], "workload": args.workload, "workers_requested": args.workers,
                   "viewport": {"width": args.width, "height": args.height, "dpr": args.dpr},
                   "browser_receipt": "browser.json", "host_receipt": "host.json", "node_exit": exit_code,
                   "chrome_command": chrome_cmd, "harness_command": node_cmd,
                   "orchestrator_sha256": orchestrator_sha256,
                   "elapsed_ms": (time.monotonic() - started) * 1000}
        write_json(out / "result.json", receipt)
        print(json.dumps({"status": receipt["status"], "case": args.case, "output": str(out), "failure": failure}, indent=2))
    return 1 if failure else 0


if __name__ == "__main__":
    raise SystemExit(main())
