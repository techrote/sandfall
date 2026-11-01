#!/usr/bin/env python3
"""Build the retained native engine and either application entry for Godot Web.

Requires pinned godot-cpp, activated Emscripten 4.0.20, SCons 4.10.1,
Godot 4.7 and its Web templates. See ../../docs/LOCAL_DEVELOPMENT.md
(relative to this script) for the configured workspace workflow.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CPP_REV = "101ae38034304346a46ea9ea84ae156d3e860496"
GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
SOURCES = [
    "godot/native_extension/cyber_native_cell_world.cpp",
    "godot/native_extension/cyber_world_generator.cpp",
    "godot/native_extension/register_types.cpp",
    "native/src/world.cpp", "native/src/render_snapshot.cpp", "native/src/settled_world_discovery.cpp",
    "native/src/world_generation.cpp",
    "native/src/generation_fields.cpp",
    "native/src/generation_typed_fields.cpp",
    "native/src/generation_spatial.cpp",
    "native/src/generation_grammar.cpp",
    "native/src/generation_planes.cpp",
    "native/src/material_rules.cpp", "native/src/scheduler_geometry.cpp",
]

def run(args: list[str], *, cwd: Path = ROOT, timeout: int = 1200) -> None:
    print("+", " ".join(map(str, args)), flush=True)
    if "--headless" in args:
        result = subprocess.run(resolve_command(args), cwd=cwd, timeout=timeout,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, encoding="utf-8", errors="replace")
        print(result.stdout, end="", flush=True)
        result.check_returncode()
        # Godot can return zero and write a PCK despite GDScript parse errors.
        if "ERROR:" in result.stdout:
            script = Path(args[args.index("--script") + 1]).name if "--script" in args else ""
            try:
                from sandfall.sf_m4_expected_diagnostics import validate
            except ModuleNotFoundError:
                from tools.sandfall.sf_m4_expected_diagnostics import validate
            try:
                diagnostics = validate(result.stdout, script)
            except (ValueError, KeyError, TypeError) as exc:
                raise RuntimeError("Godot reported errors outside the witnessed malformed-archive matrix: " + str(exc)) from exc
            print("SF_M4_EXPECTED_DIAGNOSTICS_RETAINED", json.dumps(diagnostics, sort_keys=True), flush=True)
    else:
        subprocess.run(resolve_command(args), cwd=cwd, check=True, timeout=timeout)

def resolve_command(args: list[str]) -> list[str]:
    # CreateProcess does not search PATHEXT for Emscripten's Windows .bat tools.
    executable = shutil.which(str(args[0]))
    if executable is None:
        raise RuntimeError(f"Executable not found on PATH: {args[0]}")
    return [executable, *map(str, args[1:])]

def output(args: list[str]) -> str:
    return subprocess.check_output(resolve_command(args), text=True, timeout=30).strip()

def compile_extension(cpp: Path, dest: Path, platform: str, threaded: bool) -> Path:
    if output(["git", "-C", str(cpp), "rev-parse", "HEAD"]) != CPP_REV:
        raise RuntimeError("godot-cpp revision does not match M11")
    if output(["git", "-C", str(cpp), "status", "--porcelain", "--untracked-files=no"]):
        raise RuntimeError("godot-cpp tracked source is dirty")
    web = platform == "web"
    target = "template_release" if web else "template_debug"
    arch = "wasm32" if web else "x86_64"
    run([sys.executable, "-m", "SCons", "-C", str(cpp), f"platform={platform}",
         f"target={target}", f"arch={arch}", f"threads={'yes' if threaded else 'no'}",
         "api_version=4.7", f"build_profile={ROOT / 'tools/web/build_profile.json'}",
         "lto=none", "debug_symbols=no", "-j", os.environ.get("SCONS_JOBS", "2")])
    libs = list((cpp / "bin").glob(f"libgodot-cpp.{platform}.{target}.{arch}*.a"))
    libs = [p for p in libs if ("nothreads" not in p.name) == threaded]
    if len(libs) != 1:
        raise RuntimeError(f"Ambiguous godot-cpp library: {libs}")
    dest.mkdir(parents=True, exist_ok=True)
    name = ("libcybersand_native.web." + ("threads" if threaded else "nothreads") + ".wasm"
            if web else "libcybersand_native.linux.x86_64.so")
    artifact = dest / name
    flags = ["-std=c++20", "-O3", "-DNDEBUG", "-fPIC", "-fno-math-errno"]
    if web:
        # Match the existing Windows bridge build's Vector2 narrowing policy.
        flags += ["-Wno-c++11-narrowing", "-sSIDE_MODULE=1", "-sWASM_BIGINT", "-sMEMORY64=0",
                  "-sSUPPORT_LONGJMP=wasm", "-fwasm-exceptions", "-sWASM_LEGACY_EXCEPTIONS=1", "-fvisibility=hidden"]
        if threaded:
            flags += ["-pthread"]
    else:
        flags += ["-shared", "-pthread"]
    includes = [ROOT / "native/include", cpp / "include", cpp / "gen/include", cpp / "gdextension"]
    command = ["em++" if web else os.environ.get("CXX", "g++"), *flags]
    command += [f"-I{p}" for p in includes]
    command += [str(ROOT / p) for p in SOURCES] + [str(libs[0])]
    if web:
        # SIDE_MODULE omits system libraries. The official Godot template has
        # no C++ exception runtime, while the solver validates by throwing.
        # Own the matching SDK runtime and bind it within this module; C++
        # exceptions and STL objects never cross the C GDExtension boundary.
        suffix = "-mt-legacyexcept" if threaded else "-legacyexcept"
        runtime = ["libc++" + suffix, "libc++abi" + suffix, "libunwind" + suffix]
        embuilder = Path(resolve_command(["em++"])[0]).with_name("embuilder.py")
        run([sys.executable, str(embuilder), "--pic", "build", *runtime])
        command += ["-Wl,-Bsymbolic", *("-l" + name[3:] for name in runtime)]
    command += ["-o", str(artifact)]
    run(command)
    data = artifact.read_bytes()
    if web and data[:4] != b"\x00asm":
        raise RuntimeError("Compiler output is not WebAssembly")
    print("BUILT", artifact.name, len(data), hashlib.sha256(data).hexdigest(), flush=True)
    return artifact

def stage_project(library: Path, native_library: Path | None, cellular_only: bool, threaded: bool,
                  entry: str = "legacy") -> Path:
    if entry not in ("legacy", "sandfall"):
        raise RuntimeError(f"Unknown Web application entry: {entry}")
    if not cellular_only:
        verify_rapier(threaded)
    prefix = "web-sandfall-project" if entry == "sandfall" else "web-project"
    stage = ROOT / "build" / (prefix + ("-threaded" if threaded else ""))
    if not stage.resolve().is_relative_to((ROOT / "build").resolve()):
        raise RuntimeError("Web staging path escapes the build directory")
    if stage.exists():
        shutil.rmtree(stage)  # Only this tool's disposable, fixed staging directory.
    shutil.copytree(ROOT / "godot", stage, ignore=shutil.ignore_patterns(".godot", "native_extension"))
    binaries = stage / "addons/cybersand_native/bin"
    if entry == "sandfall":
        # Never execute or export inherited desktop libraries while qualifying
        # the replacement host. The source build below supplies its own bytes.
        shutil.rmtree(binaries)
        binaries.mkdir(parents=True)
    shutil.copy2(library, binaries / library.name)
    if native_library:
        shutil.copy2(native_library, binaries / native_library.name)
    project = (stage / "project.godot").read_text()
    scene = "sandfall_main.tscn" if entry == "sandfall" else "web_main.tscn"
    for desktop_scene in ("main.tscn", "feature_launcher.tscn", "web_main.tscn", "sandfall_main.tscn"):
        project = project.replace(f'run/main_scene="res://{desktop_scene}"', f'run/main_scene="res://{scene}"')
    if (f'run/main_scene="res://{scene}"' not in project
            or (entry == "sandfall" and not (stage / scene).is_file())):
        raise RuntimeError("Unexpected project main-scene configuration")
    project = project.replace('FeatureNavigation="*res://scripts/feature_navigation.gd"\n', '')
    if cellular_only:
        shutil.rmtree(stage / "addons/godot-rapier2d")
        project = project.replace('"Rapier2D"', '"GodotPhysics2D"')
    # Only the disposable Web project overrides desktop settings.
    project = project.replace("native_worker_threads=0", f"native_worker_threads={0 if threaded else 1}\nweb_demo=true")
    project = project.replace("viewport_width=1920", "viewport_width=1280")
    project = project.replace("viewport_height=1080", "viewport_height=800")
    project = project.replace("window_width_override=1920", "window_width_override=1280")
    project = project.replace("window_height_override=1080", "window_height_override=800")
    (stage / "project.godot").write_text(project)
    return stage

def verify_rapier(threaded: bool) -> dict:
    lock = json.loads((ROOT / "godot/third_party/rapier2d.lock.json").read_text())
    artifact = lock["web_libraries"]["threaded" if threaded else "compat"]
    path = ROOT / "godot/addons/godot-rapier2d" / artifact["path"]
    data = path.read_bytes()
    if data[:4] != b"\x00asm" or hashlib.sha256(data).hexdigest() != artifact["sha256"]:
        raise RuntimeError(f"Restore the pinned Rapier v0.35.2 release binary: {path}")
    return artifact

def write_runtime_identity(stage: Path, library: Path, args: argparse.Namespace) -> dict:
    data = library.read_bytes()
    entry = getattr(args, "entry", "legacy")
    identity = {
        "schema_version": 1,
        "status": "source-built-web-export-unqualified",
        "source_commit": args.source_commit or output(["git", "-C", str(ROOT), "rev-parse", "HEAD"]),
        "source_identity_kind": "snapshot-base-with-local-setup-changes" if args.source_commit else "git-checkout",
        "artifact": library.name,
        "sha256": hashlib.sha256(data).hexdigest(),
        "size": len(data),
        "build_target": "Godot Web " + args.profile,
        "browser_execution_status": "not-established-by-export",
        "profile": args.profile,
        "godot": GODOT_VERSION,
        "godot_cpp": CPP_REV,
        "emscripten": "4.0.20",
        "native_worker_threads": "auto" if args.profile == "threaded" else 1,
        "application_entry": entry,
        "entry_scene": "res://sandfall_main.tscn" if entry == "sandfall" else "res://web_main.tscn",
    }
    destination = stage / "addons/cybersand_native/runtime-provenance.web.json"
    destination.write_text(json.dumps(identity, indent=2) + "\n", encoding="utf-8")
    return identity

def write_sandfall_identity(stage: Path, library: Path, args: argparse.Namespace) -> dict:
    """Expose measured build identity to authored projects and run receipts.

    This is data in the exported PCK, never an assertion of browser acceptance.
    The archive's creation identity may differ from the importing application;
    both identities remain available to the session/evidence owner.
    """
    commit = args.source_commit or output(["git", "-C", str(ROOT), "rev-parse", "HEAD"])
    tree = output(["git", "-C", str(ROOT), "rev-parse", f"{commit}^{{tree}}"])
    data = library.read_bytes()
    rapier = verify_rapier(args.profile == "threaded")
    identity = {
        "source_commit": commit,
        "native_source_commit": commit,
        "source_tree": tree,
        "native_runtime_sha256": hashlib.sha256(data).hexdigest(),
        "rapier_version": "0.35.2",
        "rapier_runtime_sha256": rapier["sha256"],
        "godot_version": GODOT_VERSION,
        "build_profile": args.profile,
    }
    (stage / "sandfall_build_identity.json").write_text(
        json.dumps(identity, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return identity

def clean_sandfall_source(expected_commit: str) -> None:
    # This script is executable directly (tools/ is then the import root), and
    # is also imported by staging tests from the repository root.
    try:
        from sandfall.sf_m0_verify_web_artifact import build_sensitive, changed_paths, git
    except ModuleNotFoundError:
        from tools.sandfall.sf_m0_verify_web_artifact import build_sensitive, changed_paths, git
    if git(ROOT, "rev-parse", "HEAD") != expected_commit:
        raise RuntimeError("Sandfall source HEAD changed during its Web build")
    dirty = set(changed_paths(ROOT, "HEAD") + changed_paths(ROOT, "--cached", "HEAD"))
    dirty.update(git(ROOT, "ls-files", "--others", "--exclude-standard", "-z").split("\0"))
    sensitive = sorted(path for path in dirty if build_sensitive(path))
    if sensitive:
        raise RuntimeError("Sandfall Web source is not committed: " + ", ".join(sensitive))

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cpp", type=Path, default=os.environ.get("GODOT_CPP_ROOT"))
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--templates", type=Path, default=os.environ.get("WEB_TEMPLATE_ROOT"))
    parser.add_argument("--profile", choices=["compat", "threaded"], default="compat")
    parser.add_argument("--entry", choices=["legacy", "sandfall"], default="legacy",
                        help="Dedicated Sandfall host or retained SF-M0 fixture (default)")
    parser.add_argument("--cellular-only", action="store_true")
    parser.add_argument("--compile-only", action="store_true")
    parser.add_argument("--export-only", action="store_true", help="Export the already-built side module")
    parser.add_argument("--source-commit", help="Base commit of a source snapshot without Git history")
    parser.add_argument("--native-cpp", type=Path, help="Separate native godot-cpp checkout for --native-tests")
    parser.add_argument("--native-tests", action="store_true")
    args = parser.parse_args()
    if not args.cpp or not args.cpp.is_dir():
        parser.error("Set GODOT_CPP_ROOT or --cpp to the pinned godot-cpp checkout")
    if args.compile_only and args.export_only:
        parser.error("Choose either --compile-only or --export-only")
    if args.native_tests and (not args.native_cpp or args.native_cpp.resolve() == args.cpp.resolve()):
        parser.error("--native-tests requires a separate --native-cpp checkout")
    if args.source_commit and not re.fullmatch(r"[0-9a-f]{40}", args.source_commit):
        parser.error("--source-commit must be a full Git commit ID")
    build_source_commit = args.source_commit or output(["git", "-C", str(ROOT), "rev-parse", "HEAD"])
    if args.entry == "sandfall":
        if args.export_only or args.source_commit or args.cellular_only:
            parser.error("Sandfall qualification requires a fresh Git-checkout build with Rapier")
        # Copying uncommitted or untracked source into a PCK cannot establish an
        # exact build SHA. Generated ignored imports are excluded by staging.
        clean_sandfall_source(build_source_commit)
        if not args.native_tests:
            parser.error("Sandfall export requires --native-tests and a fresh --native-cpp checkout")
    for compiler in ("emcc", "em++"):
        if not re.search(r"\b4\.0\.20\b", output([compiler, "--version"]).splitlines()[0]):
            raise RuntimeError("Emscripten 4.0.20 is required by the M13 handover")
    import SCons
    if SCons.__version__ != "4.10.1":
        raise RuntimeError("SCons 4.10.1 is required")
    threaded = args.profile == "threaded"
    libs = ROOT / "build/web-libs"
    library = libs / ("libcybersand_native.web." + ("threads" if threaded else "nothreads") + ".wasm")
    if args.export_only:
        if not library.is_file() or library.read_bytes()[:4] != b"\x00asm":
            raise RuntimeError("Build the Web side module before --export-only")
    else:
        library = compile_extension(args.cpp.resolve(), libs, "web", threaded)
    native_library = None
    if args.native_tests:
        if args.entry == "sandfall":
            # Both the Godot encoder and the independent Python ZIP reader
            # retain exact bytes. Use a reproducible absolute path so separate
            # native processes can consume the same interchange fixtures.
            codec_output = Path(os.environ.get("SF_M4_TEST_OUTPUT", str(ROOT / "build/sf-m4-codec"))).resolve()
            codec_output.mkdir(parents=True, exist_ok=True)
            os.environ["SF_M4_TEST_OUTPUT"] = str(codec_output)
        native_library = compile_extension(args.native_cpp.resolve(), libs, "linux", True)
    if args.compile_only:
        return
    if output([args.godot, "--version"]) != GODOT_VERSION:
        raise RuntimeError(f"Expected Godot {GODOT_VERSION}")
    if args.templates is None:
        parser.error("Set WEB_TEMPLATE_ROOT or --templates to extracted Godot 4.7 Web templates")
    if args.entry == "sandfall":
        clean_sandfall_source(build_source_commit)
    stage = stage_project(library, native_library, args.cellular_only, threaded, args.entry)
    web_runtime_identity = write_runtime_identity(stage, library, args)
    sandfall_identity = write_sandfall_identity(stage, library, args) if args.entry == "sandfall" else None
    output_name = "web-sandfall" if args.entry == "sandfall" else "web"
    output_dir = ROOT / "build" / (output_name + ("-threaded" if threaded else ""))
    if output_dir.exists():
        shutil.rmtree(output_dir)  # This tool's fixed disposable export only.
    output_dir.mkdir(parents=True, exist_ok=True)
    preset = (ROOT / "godot/export_presets.cfg").read_text()
    if args.entry == "sandfall":
        # JSON is a plain data asset, not an imported Godot resource. Include it
        # explicitly so the application's archive/evidence path reads the same
        # measured source/native/Rapier identity as the outer export manifest.
        preset = preset.replace('include_filter=""', 'include_filter="sandfall_build_identity.json"')
    for kind in ("debug", "release"):
        template = args.templates / f"web_dlink_{'' if threaded else 'nothreads_'}{kind}.zip"
        if not template.is_file():
            raise RuntimeError(f"Missing template: {template}")
        preset = preset.replace(f'custom_template/{kind}=""', f'custom_template/{kind}="{template.resolve().as_posix()}"')
    if threaded:
        preset = preset.replace("variant/thread_support=false", "variant/thread_support=true")
        # Prewarm enough pthreads for the native persistent pool and Godot.
        # Includes the live world and transactional benchmark replacement worlds.
        preset += "\nthreads/emscripten_pool_size=32\nthreads/godot_pool_size=2\n"
    (stage / "export_presets.cfg").write_text(preset)
    run([args.godot, "--headless", "--editor", "--path", str(stage), "--import"], timeout=240)
    if args.native_tests:
        tests = ["test_cell_world.gd", "test_material_appearance_lut.gd",
                 "test_native_render_bridge_regression.gd", "test_render_patch_handoff_regression.gd",
                 "test_native_fire_presentation_regression.gd", "test_native_edge_contact_regression.gd",
                 "test_web_demo_setup.gd"]
        if not args.cellular_only:
            tests += ["test_rapier_backend_preflight.gd", "test_rapier_drop_in.gd", "test_rapier_manual_step.gd"]
        if args.entry == "sandfall":
            tests += ["test_sandfall_simulation_host.gd", "test_sandfall_session.gd", "test_sandfall_authoring.gd", "test_sandfall_editor_input.gd",
                      "test_sandfall_objects.gd", "test_sandfall_object_history.gd", "test_sandfall_object_input.gd",
                      "test_sandfall_archive.gd", "test_sandfall_projects.gd", "test_sandfall_promotion.gd",
                      "test_sandfall_presentation.gd", "test_sandfall_gallery.gd", "test_sandfall_project_input.gd"]
        for name in tests:
            # Seven curated scenes each run twice for 600 real coupled ticks,
            # plus the independent no-water physical control. This sustained
            # 9,000-tick test has its own bounded budget; other gates retain 240s.
            budget = 900 if name == "test_sandfall_gallery.gd" else 240
            run([args.godot, "--headless", "--path", str(stage), "--script", f"res://tests/{name}"], timeout=budget)
        if args.entry == "sandfall":
            interop = codec_output / "external-interop"
            run([sys.executable, str(ROOT / "tools/sandfall/sf_m4_archive_fixture.py"), "interop", str(codec_output),
                 "--destination", str(interop), "--output", str(codec_output / "python-interop-receipt.json")], timeout=240)
            os.environ["SF_M4_INTEROP_DIR"] = str(interop)
            run([args.godot, "--headless", "--path", str(stage), "--script",
                 "res://tests/test_sandfall_archive_interop.gd"], timeout=240)
    run([args.godot, "--headless", "--path", str(stage), "--export-release", "Web Demo", str(output_dir / "index.html")], timeout=240)
    for name in ("index.html", "index.js", "index.wasm", "index.pck"):
        if not (output_dir / name).is_file():
            raise RuntimeError(f"Export missing {name}")
    for name in ("THIRD_PARTY_NOTICES.md", "LICENSE_STATUS.md"):
        shutil.copy2(ROOT / name, output_dir / name)
    if not args.cellular_only:
        artifact = verify_rapier(threaded)
        exported = output_dir / "godot_rapier.wasm"
        if not exported.is_file() or hashlib.sha256(exported.read_bytes()).hexdigest() != artifact["sha256"]:
            raise RuntimeError("Export omitted or selected the wrong Rapier Web binary")
        for source_name, export_name in (("LICENSE", "RAPIER_LICENSE.txt"), ("THIRDPARTY.txt", "RAPIER_THIRDPARTY.txt")):
            shutil.copy2(ROOT / "godot/addons/godot-rapier2d" / source_name, output_dir / export_name)
    shutil.copy2(ROOT / "tools/serve_web.py", output_dir / "serve_web.py")
    if args.entry == "sandfall":
        clean_sandfall_source(build_source_commit)
    identity = {"source_commit": args.source_commit or output(["git", "-C", str(ROOT), "rev-parse", "HEAD"]),
                "source_identity_kind": "snapshot-base-with-local-setup-changes" if args.source_commit else "git-checkout",
                "godot": GODOT_VERSION, "godot_cpp": CPP_REV,
                "emscripten": "4.0.20", "profile": args.profile,
                "native_worker_threads": "auto" if threaded else 1,
                "auto_worker_policy": "logical<4:2; logical<12:4; otherwise:6",
                "rapier": "disabled" if args.cellular_only else "0.35.2",
                "rapier_sha256": None if args.cellular_only else artifact["sha256"],
                "application_entry": args.entry,
                "entry_scene": "res://" + ("sandfall_main.tscn" if args.entry == "sandfall" else "web_main.tscn"),
                "staged_project_sha256": hashlib.sha256((stage / "project.godot").read_bytes()).hexdigest(),
                "water_runtime": web_runtime_identity}
    shutil.copy2(stage / "project.godot", output_dir / "export-project.godot")
    if sandfall_identity is not None:
        shutil.copy2(stage / "sandfall_build_identity.json", output_dir / "sandfall_build_identity.json")
        identity["sandfall_identity"] = sandfall_identity
    (output_dir / "build-info.json").write_text(json.dumps(identity, indent=2) + "\n")
    (output_dir / "SHA256SUMS").write_text("".join(
        f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n"
        for p in sorted(output_dir.iterdir()) if p.is_file() and p.name != "SHA256SUMS"))
    print("WEB_EXPORT", output_dir, flush=True)

if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
        print(f"Web build failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
