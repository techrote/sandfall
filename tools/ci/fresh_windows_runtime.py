#!/usr/bin/env python3
"""Source-pinned Windows DLL bundle for the existing headless Godot runner.

A fresh build is not a retained LFS runtime: it carries its own exact-head,
whole-native-source SHA-256 inventory and is never written to tracked provenance.
The unchanged historical Windows-LFS checker remains a separate gate.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = "sandfall-fresh-windows-runtime-v1"
DLL_NAME = "cybersand_native.windows.x86_64.dll"
DLL_PATH = "godot/addons/cybersand_native/bin/" + DLL_NAME
GODOT_CPP_COMMIT = "101ae38034304346a46ea9ea84ae156d3e860496"
LLVM_MINGW_SHA256 = "cee8d2ce3da5145ce4dc882e70d0b0719a783d53a99752c60948fc0659975a65"
EXTENSIONS = frozenset({".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp"})
NATIVE_DIRS = ("native/include", "native/src", "godot/native_extension")
FIELDS = frozenset({"schema", "source_commit", "source_tree", "artifact", "sha256",
                    "size", "source_inputs", "godot_cpp_commit", "llvm_mingw_sha256"})


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *args], text=True, stderr=subprocess.PIPE, timeout=60).strip()


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def native_inputs(root: Path) -> dict[str, str]:
    inputs = {}
    for directory in NATIVE_DIRS:
        for path in sorted((root / directory).rglob("*")):
            if path.is_file() and path.suffix in EXTENSIONS:
                if path.is_symlink():
                    raise ValueError("Symlinked native input: " + str(path))
                relative = path.relative_to(root).as_posix()
                inputs[relative] = sha(path.read_bytes().replace(b"\r\n", b"\n"))
    if not inputs:
        raise ValueError("No native source inputs")
    return dict(sorted(inputs.items()))


def clean_native_checkout(root: Path) -> None:
    subprocess.run(["git", "-C", str(root), "diff", "--exit-code", "HEAD", "--", *NATIVE_DIRS],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=60)
    tracked = set(filter(None, git(root, "ls-files", "--", *NATIVE_DIRS).splitlines()))
    untracked = sorted(set(native_inputs(root)) - tracked)
    if untracked:
        raise ValueError("Untracked native source inputs: " + ", ".join(untracked))


def bundle_manifest(root: Path, dll: Path) -> dict:
    clean_native_checkout(root)
    data = dll.read_bytes()
    if dll.is_symlink() or not data.startswith(b"MZ") or not (2 < len(data) <= 100 * 1024 * 1024):
        raise ValueError("Fresh Windows DLL is not a bounded PE candidate")
    return {"schema": SCHEMA, "source_commit": git(root, "rev-parse", "HEAD"),
            "source_tree": git(root, "rev-parse", "HEAD^{tree}"),
            "artifact": DLL_PATH, "sha256": sha(data), "size": len(data),
            "source_inputs": native_inputs(root),
            "godot_cpp_commit": GODOT_CPP_COMMIT,
            "llvm_mingw_sha256": LLVM_MINGW_SHA256}


def build(root: Path, dll: Path, directory: Path) -> dict:
    manifest = bundle_manifest(root, dll)
    if directory.exists() and any(directory.iterdir()):
        raise ValueError("Fresh Windows runtime output directory must be empty")
    directory.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(dll, directory / DLL_NAME)
    (directory / "manifest.json").write_text(json.dumps(manifest, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    return manifest


def verify(root: Path, directory: Path, expected_source_sha: str) -> dict:
    if not directory.is_dir() or {p.name for p in directory.iterdir()} != {DLL_NAME, "manifest.json"}:
        raise ValueError("Fresh Windows runtime bundle file inventory differs")
    if any(p.is_symlink() for p in directory.iterdir()):
        raise ValueError("Fresh Windows runtime bundle contains symlinks")
    raw = (directory / "manifest.json").read_bytes()
    if len(raw) > 300_000:
        raise ValueError("Fresh Windows runtime manifest exceeds bound")
    manifest = json.loads(raw)
    if not isinstance(manifest, dict) or set(manifest) != FIELDS or manifest["schema"] != SCHEMA:
        raise ValueError("Unsupported or altered fresh Windows runtime manifest")
    if manifest["source_commit"] != expected_source_sha or git(root, "rev-parse", "HEAD") != expected_source_sha:
        raise ValueError("Fresh Windows DLL was built from a different commit")
    if manifest["source_tree"] != git(root, "rev-parse", "HEAD^{tree}"):
        raise ValueError("Fresh Windows DLL was built from a different tree")
    if manifest["artifact"] != DLL_PATH or manifest["godot_cpp_commit"] != GODOT_CPP_COMMIT or manifest["llvm_mingw_sha256"] != LLVM_MINGW_SHA256:
        raise ValueError("Fresh Windows DLL artifact or dependency pins differ")
    clean_native_checkout(root)
    inputs = native_inputs(root)
    if inputs != manifest["source_inputs"]:
        raise ValueError("Fresh Windows DLL source-input hash/inventory mismatch")
    data = (directory / DLL_NAME).read_bytes()
    if not data.startswith(b"MZ") or not (2 < len(data) <= 100 * 1024 * 1024):
        raise ValueError("Fresh Windows DLL has invalid PE candidate bytes")
    if manifest["size"] != len(data) or manifest["sha256"] != sha(data):
        raise ValueError("Fresh Windows DLL digest or byte length differs")
    if not isinstance(manifest["sha256"], str) or not re.fullmatch(r"[0-9a-f]{64}", manifest["sha256"]):
        raise ValueError("Fresh Windows DLL has malformed digest")
    return {
        "runtime_source_commit": expected_source_sha,
        "runtime_build_commit": expected_source_sha,
        "runtime_provenance": {"path": str(directory / "manifest.json"),
                               "sha256": sha(raw), "scheme": SCHEMA},
        "native_source_inputs": inputs,
        "cybersand_runtime": {"path": DLL_PATH, "sha256": sha(data), "size": len(data)},
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    cmd_build = sub.add_parser("build")
    cmd_build.add_argument("--dll", type=Path, required=True)
    cmd_build.add_argument("--output-dir", type=Path, required=True)
    cmd_verify = sub.add_parser("verify")
    cmd_verify.add_argument("--bundle-dir", type=Path, required=True)
    cmd_verify.add_argument("--expected-source-sha", required=True)
    args = parser.parse_args()
    report = (build(ROOT, args.dll.resolve(), args.output_dir.resolve())
              if args.command == "build"
              else verify(ROOT, args.bundle_dir.resolve(), args.expected_source_sha))
    print(json.dumps({"status": "passed", "source_commit": report.get("source_commit", report.get("runtime_source_commit")),
                      "dll_sha256": report.get("sha256", report.get("cybersand_runtime", {}).get("sha256")),
                      "input_count": len(report.get("source_inputs", report.get("native_source_inputs", {})))}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
