#!/usr/bin/env python3
"""Verify a freshly built SF-M1 Sandfall export before ordinary-browser qualification.

This verifies export bytes, the dedicated entry, and source equivalence. It
does not establish browser execution, threaded Web or human visual acceptance.
"""
from __future__ import annotations

import argparse
import ast
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
NATIVE_WASM = "libcybersand_native.web.nothreads.wasm"
BUILD_PREFIXES = ("godot/", "native/", "third_party/", "tools/web/")
BUILD_FILES = frozenset({
    "Makefile", ".gitattributes", ".gitmodules", "tools/build_web.py",
    "tools/requirements-build.txt", "tools/serve_web.py",
    "THIRD_PARTY_NOTICES.md", "LICENSE_STATUS.md",
})
REQUIRED_EXPORTS = frozenset({
    "index.html", "index.js", "index.wasm", "index.side.wasm", "index.pck",
    "build-info.json", "godot_rapier.wasm", "RAPIER_LICENSE.txt",
    "RAPIER_THIRDPARTY.txt", "THIRD_PARTY_NOTICES.md", "LICENSE_STATUS.md",
    "serve_web.py", "export-project.godot",
})
PINS = {
    "godot": "4.7.stable.official.5b4e0cb0f",
    "godot_cpp": "101ae38034304346a46ea9ea84ae156d3e860496",
    "emscripten": "4.0.20", "profile": "compat", "rapier": "0.35.2",
    "native_worker_threads": 1,
}


class VerificationError(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise VerificationError(message)


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(root), *args], text=True, encoding="utf-8",
        stderr=subprocess.PIPE,
    ).strip()


def build_sensitive(path: str) -> bool:
    return path.startswith(BUILD_PREFIXES) or path in BUILD_FILES


def changed_paths(root: Path, *args: str) -> list[str]:
    raw = git(root, "diff", "--name-only", "--no-renames", "-z", *args, "--")
    return sorted(x for x in raw.split("\0") if x)


def source_file(root: Path, commit: str, path: str) -> str:
    return git(root, "show", f"{commit}:{path}")


def settings(text: str) -> dict[str, str]:
    result: dict[str, str] = {}
    section = ""
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith(";"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
        elif "=" in line:
            key, value = line.split("=", 1)
            result[f"{section}/{key.strip()}"] = value.strip().strip('"')
    return result


def source_bytes(root: Path, commit: str, path: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(root), "show", f"{commit}:{path}"],
                                   stderr=subprocess.PIPE)


def logical_viewport(root: Path, commit: str, exported_project: bytes) -> dict:
    project_path = "godot/project.godot"
    builder_path = "tools/build_web.py"
    preset_path = "godot/export_presets.cfg"
    project = source_bytes(root, commit, project_path).decode("utf-8")
    cfg = settings(project)
    require(cfg.get("application/run/main_scene") == "res://sandfall_main.tscn",
            "Source does not select the dedicated Sandfall entry")
    require("autoload/FeatureNavigation" not in cfg,
            "Sandfall source retains the inherited application navigation autoload")
    builder = source_file(root, commit, builder_path)
    parsed = ast.parse(builder)
    stage = next((n for n in parsed.body if isinstance(n, ast.FunctionDef)
                  and n.name == "stage_project"), None)
    require(stage is not None, "Pinned builder has no stage_project function")
    replacements = []
    for node in sorted(ast.walk(stage), key=lambda n: getattr(n, "lineno", 0)):
        if not isinstance(node, ast.Call) or len(node.args) != 2:
            continue
        func = node.func
        if (isinstance(func, ast.Attribute) and func.attr == "replace"
                and isinstance(func.value, ast.Name) and func.value.id == "project"
                and all(isinstance(a, ast.Constant) and isinstance(a.value, str)
                        for a in node.args)):
            before, after = (a.value for a in node.args)
            if any(key in before or key in after for key in
                   ("viewport_width", "viewport_height", "window_width_override",
                    "window_height_override", "window/stretch/")):
                require(before in project or after in project,
                        f"Staging dimension does not match pinned project: {before}")
                project = project.replace(before, after)
                replacements.append({"before": before, "after": after})
    require(len(replacements) >= 4, "Pinned Web dimension staging cannot be established")
    project = project.replace("native_worker_threads=0", "native_worker_threads=1\nweb_demo=true")
    require(project.encode("utf-8") == exported_project,
            "Exported project settings differ from source-bound Sandfall staging")
    cfg = settings(project)
    width = int(cfg["display/window/size/viewport_width"])
    height = int(cfg["display/window/size/viewport_height"])
    mode = cfg["display/window/stretch/mode"]
    aspect = cfg.get("display/window/stretch/aspect", "keep")
    require((width, height, mode, aspect) == (1280, 800, "canvas_items", "keep"),
            "SF-M1 export does not have the qualified 1280x800 canvas_items/keep layout")
    require(cfg.get("cybersand/native_worker_threads") == "1",
            "SF-M1 compatibility staging must use exactly one native worker")
    preset = settings(source_file(root, commit, preset_path))
    require(preset["preset.0.options/html/canvas_resize_policy"] == "2",
            "Pinned export does not resize its canvas to the browser")
    require(preset["preset.0.options/html/focus_canvas_on_start"] == "true",
            "Pinned export does not focus its canvas on start")
    return {
        "width": width, "height": height, "stretch_mode": mode,
        "stretch_aspect": aspect,
        "aspect_source": "explicit-project-setting" if "display/window/stretch/aspect" in cfg else "godot-4.7-default",
        "aspect_default_source": "https://github.com/godotengine/godot/blob/5b4e0cb0f/core/config/project_settings.cpp",
        "canvas_resize_policy": 2, "focus_canvas_on_start": True,
        "staging_replacements": replacements,
        "source_blobs": {p: git(root, "rev-parse", f"{commit}:{p}")
                         for p in (project_path, builder_path, preset_path, "godot/sandfall_main.tscn")},
    }


def verify(web_root: Path, repo_root: Path, expected_build_sha: str) -> dict:
    require(bool(re.fullmatch(r"[0-9a-f]{40}", expected_build_sha)), "Expected build SHA must be a full lowercase Git commit ID")
    require(git(repo_root, "rev-parse", f"{expected_build_sha}^{{commit}}") == expected_build_sha,
            "Expected build commit is unavailable")
    head = git(repo_root, "rev-parse", "HEAD")
    committed = changed_paths(repo_root, expected_build_sha, head)
    staged = changed_paths(repo_root, "--cached", "HEAD")
    unstaged = changed_paths(repo_root)
    # Untracked Godot source would also enter stage_project's copytree. Ignored
    # generated imports/caches are excluded by Git's ordinary source inventory.
    untracked = sorted(p for p in git(repo_root, "ls-files", "--others", "--exclude-standard", "-z").split("\0") if p)
    sensitive = sorted(p for p in set(committed + staged + unstaged + untracked) if build_sensitive(p))
    require(not sensitive, "Build-sensitive source drift: " + ", ".join(sensitive))

    manifest = web_root / "SHA256SUMS"
    require(manifest.is_file() and not manifest.is_symlink(), "Missing or symlinked SHA256SUMS")
    entries = {}
    for row in manifest.read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  (.+)", row)
        require(match is not None, "Malformed SHA256SUMS row")
        digest, name = match.groups()
        path = PurePosixPath(name)
        require(not path.is_absolute() and len(path.parts) == 1
                and name not in {".", "..", "SHA256SUMS"} and "\\" not in name,
                f"Invalid export manifest path: {name}")
        require(name not in entries, f"Duplicate export manifest path: {name}")
        entries[name] = digest
    require(REQUIRED_EXPORTS <= entries.keys(),
            "Required export files missing: " + ", ".join(sorted(REQUIRED_EXPORTS - entries.keys())))
    files = set()
    for path in web_root.iterdir():
        require(path.is_file() and not path.is_symlink(), f"Unexpected export entry: {path.name}")
        if path.name != "SHA256SUMS":
            files.add(path.name)
    require(files == set(entries), "SHA256SUMS is not the complete export file inventory")
    artifacts = []
    for name, digest in sorted(entries.items()):
        data = (web_root / name).read_bytes()
        require(hashlib.sha256(data).hexdigest() == digest, f"Export SHA256 mismatch: {name}")
        if name.endswith(".wasm"):
            require(data[:4] == b"\x00asm", f"Export is not WASM: {name}")
        artifacts.append({"path": name, "sha256": digest, "size": len(data)})
    info = json.loads((web_root / "build-info.json").read_text(encoding="utf-8"))
    require(isinstance(info, dict), "Export build-info must be a JSON object")
    require(info.get("source_commit") == expected_build_sha, "Export build source SHA mismatch")
    require(info.get("source_identity_kind") == "git-checkout", "Export is not an identified Git checkout build")
    for key, value in PINS.items():
        require(info.get(key) == value, f"Export {key} pin mismatch")
    runtime = info.get("water_runtime", {})
    require(isinstance(runtime, dict), "Native Web runtime receipt must be a JSON object")
    require(runtime.get("source_commit") == expected_build_sha, "Native Web runtime source SHA mismatch")
    require(runtime.get("source_identity_kind") == "git-checkout", "Native Web runtime is not a Git-checkout build")
    for key in ("profile", "godot", "godot_cpp", "emscripten", "native_worker_threads"):
        require(runtime.get(key) == PINS[key], f"Native Web runtime {key} pin mismatch")
    require(runtime.get("status") == "source-built-web-export-unqualified"
            and runtime.get("browser_execution_status") == "not-established-by-export",
            "Export runtime receipt must not claim browser qualification")
    native_name = runtime.get("artifact")
    require(native_name == NATIVE_WASM, "Native Web runtime artifact name differs from pinned compatibility builder")
    require(native_name in entries, "Native Web runtime missing from manifest")
    require(entries[native_name] == runtime.get("sha256"), "Native Web runtime digest differs from build receipt")
    require((web_root / native_name).stat().st_size == runtime.get("size"), "Native Web runtime size differs from build receipt")
    lock = json.loads(source_file(repo_root, expected_build_sha, "godot/third_party/rapier2d.lock.json"))
    rapier_digest = lock["web_libraries"]["compat"]["sha256"]
    require(info.get("rapier_sha256") == rapier_digest == entries["godot_rapier.wasm"],
            "Rapier Web runtime differs from pinned source lock")
    require(info.get("application_entry") == "sandfall" and info.get("entry_scene") == "res://sandfall_main.tscn",
            "Export is not the dedicated Sandfall application")
    require(runtime.get("application_entry") == "sandfall" and runtime.get("entry_scene") == "res://sandfall_main.tscn",
            "Native runtime receipt does not identify the dedicated Sandfall application")
    require(info.get("staged_project_sha256") == entries["export-project.godot"],
            "Staged project digest differs from build receipt")
    viewport = logical_viewport(repo_root, expected_build_sha, (web_root / "export-project.godot").read_bytes())
    return {
        "schema": "sandfall-sf-m1-web-artifact-verification-v1", "status": "passed",
        "scope": "export identity and source equivalence; browser execution separately required",
        "build_source_commit": expected_build_sha, "harness_source_commit": head,
        "profile": "compat", "rapier": "0.35.2",
        "application_entry": "sandfall", "entry_scene": "res://sandfall_main.tscn",
        "manifest_sha256": hashlib.sha256(manifest.read_bytes()).hexdigest(),
        "artifacts": artifacts, "logical_viewport": viewport,
        "source_equivalence": {
            "committed_changed_paths": committed,
            "tracked_dirty_paths": sorted(set(staged + unstaged)),
            "staged_changed_paths": staged, "unstaged_changed_paths": unstaged,
            "untracked_paths": untracked,
            "build_sensitive_changed_paths": sensitive,
            "checked_prefixes": list(BUILD_PREFIXES), "checked_files": sorted(BUILD_FILES),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--web-root", type=Path, default=ROOT / "build/web-sandfall")
    parser.add_argument("--repo-root", type=Path, default=ROOT)
    parser.add_argument("--expected-build-sha", required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "sf-m1-evidence/artifact-verification.json")
    args = parser.parse_args()
    try:
        receipt = verify(args.web_root.resolve(), args.repo_root.resolve(), args.expected_build_sha)
    except (VerificationError, OSError, ValueError, KeyError, subprocess.SubprocessError) as exc:
        receipt = {
            "schema": "sandfall-sf-m1-web-artifact-verification-v1", "status": "failed",
            "build_source_commit": args.expected_build_sha, "error": str(exc),
        }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": receipt["status"], "receipt": str(args.output),
                      "error": receipt.get("error")}))
    return 0 if receipt["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
