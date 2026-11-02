"""SF-M5 generated startup/hosting contract for the existing Godot exporter."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re


def remove_export_temporaries(destination: Path) -> list[dict]:
    """Discard only pinned Godot's leftover temporary PCKs, before packaging.

    The builder creates an empty destination before invoking Godot. A generated
    six-character PCK sibling with the same pinned pack header is not referenced
    by the loader. Unexpected names, links or headers refuse rather than being
    silently discarded. Original earlier exports are never processed in place.
    """
    header = (destination / "index.pck").read_bytes()[:16]
    if header != b"GDPC\x04\x00\x00\x00\x04\x00\x00\x00\x07\x00\x00\x00":
        raise RuntimeError("Pinned Godot 4.7 PCK header changed")
    removed = []
    for path in sorted(destination.glob("index.pck-*")):
        if (not re.fullmatch(r"index\.pck-[A-Za-z0-9]{6}", path.name)
                or path.is_symlink() or not path.is_file()):
            raise RuntimeError("Unexpected export PCK sibling: " + path.name)
        data = path.read_bytes()
        if data[:16] != header or len(data) <= 16:
            raise RuntimeError("Unexpected temporary PCK payload: " + path.name)
        removed.append({"path": path.name, "size": len(data), "sha256": hashlib.sha256(data).hexdigest()})
        path.unlink()
    return removed


def install_preflight(destination: Path, source_root: Path, identity: dict) -> dict:
    """Embed immutable expected runtime digests before the engine script loads.

    HTML is the trust root for this static delivery, not a signed distribution.
    A hostile server replacing both HTML and payloads is outside this contract.
    The independent release verifier binds HTML and every other delivered byte.
    """
    removed = remove_export_temporaries(destination)
    if removed:
        print("SF_M5_EXPORT_TEMPORARIES_REMOVED", json.dumps(removed, sort_keys=True), flush=True)
    assets = []
    for path in sorted(destination.iterdir()):
        if path.suffix not in {".wasm", ".pck", ".js"}:
            continue
        mime = (["application/wasm"] if path.suffix == ".wasm" else
                ["application/octet-stream"] if path.suffix == ".pck" else
                ["text/javascript", "application/javascript"])
        data = path.read_bytes()
        assets.append({"path": path.name, "sha256": hashlib.sha256(data).hexdigest(),
                       "size": len(data), "mime": mime})
    expected = {"schema": "sandfall-web-startup-v1", "source_commit": identity["source_commit"],
                "profile": identity["profile"], "assets": assets}
    required = {"index.js", "index.wasm", "index.side.wasm", "index.pck", "godot_rapier.wasm",
                "libcybersand_native.web." + ("threads" if identity["profile"] == "threaded" else "nothreads") + ".wasm"}
    if not required <= {row["path"] for row in assets}:
        raise RuntimeError("SF-M5 export lacks mandatory engine/native/Rapier/PCK assets")
    # Pinned Godot 4.7/Emscripten pthreads reuse index.js as the worker script.
    # There is no separate index.worker.js in this template; require the actual
    # implementation, rather than inventing a worker filename.
    if identity["profile"] == "threaded":
        js = (destination / "index.js").read_text()
        if 'new Worker(pthreadMainJs' not in js or 'mainScriptUrlOrBlob' not in js:
            raise RuntimeError("Pinned Godot pthread loader contract changed")
        expected["worker_runtime"] = "index.js"
    html = (destination / "index.html").read_text(encoding="utf-8")
    marker = '<script src="index.js"></script>\n\t\t<script>'
    if html.count(marker) != 1 or html.count("</script>") != 2:
        raise RuntimeError("Godot HTML template changed; review the startup injection")
    preflight = (source_root / "tools/web/sandfall_preflight.js").read_text(encoding="utf-8")
    if "</script" in preflight.lower():
        raise RuntimeError("Unsafe inline preflight source")
    bootstrap = '''<script>
__PREFLIGHT__
const SANDFALL_WEB_EXPECTED = __EXPECTED__;
(async function () {
  try {
    await SandfallWebPreflight.run(SANDFALL_WEB_EXPECTED);
    await new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = SandfallWebPreflight.assetUrl('index.js');
      script.onload = resolve;
      script.onerror = () => reject(new Error('Verified Godot engine script could not load'));
      document.head.appendChild(script);
    });
  } catch (error) {
    const message = 'Sandfall startup refused: ' + String(error.message || error);
    globalThis.sandfallWebFailure = {schema:'sandfall-web-refusal-v1',status:'refused',message};
    const overlay = document.getElementById('status');
    overlay.style.visibility = 'visible';
    const notice = document.getElementById('status-notice');
    notice.textContent = message; notice.style.display = 'block';
    document.getElementById('status-progress').style.display = 'none';
    console.error('SF_M5_WEB_REFUSAL', message);
    return;
  }
'''.replace("__PREFLIGHT__", preflight).replace("__EXPECTED__", json.dumps(expected, separators=(",", ":")))
    html = html.replace(marker, bootstrap)
    html = html.replace("</script>", "})();\n\t\t</script>")
    html = html.replace("const engine = new Engine(GODOT_CONFIG);",
                        "const engine = new Engine(GODOT_CONFIG);\nSandfallWebPreflight.bindEngine(engine);")
    (destination / "index.html").write_text(html, encoding="utf-8")
    (destination / "startup-contract.json").write_text(json.dumps(expected, indent=2) + "\n", encoding="utf-8")
    return expected


def write_host_contract(destination: Path, profile: str) -> None:
    # Caddy serves MIME by extension and uses HTTPS for a supplied public domain.
    # Users replace only their domain/root; both contracts support a subdirectory.
    headers = """    header {
        Cross-Origin-Opener-Policy same-origin
        Cross-Origin-Embedder-Policy require-corp
        Cross-Origin-Resource-Policy same-origin
    }
""" if profile == "threaded" else ""
    (destination / "Caddyfile.example").write_text(
        "sandfall.example.org {\n    root * /srv/sandfall\n" + headers +
        "    @wasm path *.wasm\n    header @wasm Content-Type application/wasm\n"
        "    @pck path *.pck\n    header @pck Content-Type application/octet-stream\n"
        "    header Cache-Control no-cache\n    file_server\n}\n", encoding="utf-8")
