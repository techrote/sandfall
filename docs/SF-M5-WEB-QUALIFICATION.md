---
status: Current
owner: Sandfall SF-M5 A01/A02
---

# SF-M5 Web delivery and qualification

Sandfall has two explicit Web exports using the retained build machinery and
the frozen toolchain. A successful export establishes artifact identity. Actual
browser, physical, performance and human acceptance are separate gates.

## Production ownership and worker truth

| Profile | Native cellular ownership | Godot and Rapier ownership | Hosting |
|---|---|---|---|
| Compatibility, mandatory | Exactly one native worker | Synchronous Godot owner; main-thread Rapier | HTTPS or a loopback secure origin, no cross-origin-isolation dependency |
| Threaded, additional | Existing native persistent pool; requests `1`, `2`, `4`, `6` or `auto` | Same synchronous owner and main-thread Rapier | Secure origin plus COOP `same-origin` and COEP `require-corp` |

`?workers=N` selects a supported native count before construction. Explicit
requests above the browser's reported logical-processor count refuse. Auto
selects 1 below two logical processors, 2 below four, 4 below twelve, otherwise
6. Compatibility accepts one or auto only. Invalid or duplicate requests refuse;
there is no successful-threaded label for a compatibility fallback.

The application displays its profile, configured workers and Rapier readiness.
The read-only observer additionally records the original request, browser
capabilities, configured count, last native tick's actual worker participation
and observed participation peak. These observations come from the existing
native scheduler's task-participation counter. A configured pool of six does
not imply all six took work in every tick. Reports must retain both values.

The new native interface is one additive read-only getter. Cellular algorithms,
fixed 1/60-second steps, immutable copied rendering, solver ordering and Rapier
ownership remain unchanged. The exact M5 source reconciler admits only that
reviewed two-file patch and retains the original M0/M2/M3 refusals and stale
desktop warnings. It does not certify inherited desktop binaries.

## Reproducible build and artifact custody

Use pinned Godot **4.7.stable.official.5b4e0cb0f**, godot-cpp
**101ae38034304346a46ea9ea84ae156d3e860496**, Emscripten **4.0.20**, SCons
**4.10.1**, and the vendored Rapier addon **0.35.2** lock and runtime bytes.
The existing builder rejects dirty/uncommitted build inputs and a changing HEAD.
Sandfall exports require fresh native builds and actual Godot tests.

```sh
python3 tools/build_web.py --cpp /pinned/godot-cpp-web \
  --native-cpp /pinned/godot-cpp-native --godot /pinned/Godot_v4.7-stable_linux.x86_64 \
  --templates /pinned/web-templates --entry sandfall --profile compat --native-tests

python3 tools/build_web.py --cpp /pinned/godot-cpp-web \
  --native-cpp /pinned/godot-cpp-native --godot /pinned/Godot_v4.7-stable_linux.x86_64 \
  --templates /pinned/web-templates --entry sandfall --profile threaded --native-tests
```

The outputs are `build/web-sandfall/` and `build/web-sandfall-threaded/`.
Each includes PCK, engine and side WASM, the profile-specific native module,
pinned Rapier WASM, engine/worker/worklet JavaScript, source/runtime identities,
license notices, `startup-contract.json`, hosting example and complete
`SHA256SUMS`. Pinned Godot 4.7 uses **index.js itself as its pthread worker
script**; do not invent an `index.worker.js` requirement.

Before Godot loads, the startup wrapper checks required host capabilities and
the actual size, SHA-256 and MIME of every runtime asset. A real Worker probe
must start on threaded hosts. Verified bytes are retained privately and supplied
to subsequent runtime fetches; engine, worker and worklet scripts consume
verified immutable Blob URLs. A changed second server response cannot replace
the bytes used by that session. This adds a bounded startup copy of the runtime
payloads; report its resource cost in performance measurements.

The HTML is the trust root of this static delivery, not a signed distribution.
Independent verification binds its bytes and all package files. A malicious
publisher replacing both HTML and its expected digests is outside that trust
model. The startup check establishes delivery integrity, not physical correctness.

```sh
python3 tools/sandfall/sf_m5_verify_web_artifact.py \
  --web-root build/web-sandfall-threaded --profile threaded \
  --expected-build-sha FULL_BUILD_COMMIT --output build/threaded-verification.json
```

This verifier retains the original build SHA and requires source equivalence
for any newer harness checkout. PCK/native/Rapier and actual served-file hashes
stay in browser receipts. A later source revision must not relabel an old export.

## Static-host contract

Deploy one complete export directory at a stable same-origin path, including
all generated JavaScript and WASM side modules. The generated
`Caddyfile.example` uses automatic HTTPS for a supplied public domain, sets
`application/wasm` for WASM and `application/octet-stream` for PCK, and adds
COOP/COEP/CORP only for the threaded profile. Replace its example domain and root
with the actual deployment values. Nested ordinary paths are supported and
qualified separately by the hostile-host runner.

For local delivery:

```sh
python3 tools/serve_web.py --directory build/web-sandfall --port 8000 --isolation off
python3 tools/serve_web.py --directory build/web-sandfall-threaded --port 8001 --isolation on
```

Loopback is a browser secure context. Pinned Godot 4.7 also requires a secure
origin for its nonthreaded engine: an actual insecure-HTTP compatibility
experiment reached the engine's missing-feature refusal and never started the
application. Its original failed positive receipt is retained. The supported
contract now refuses insecure origins explicitly before loading either engine;
it does not bypass Godot's feature check. Compatibility's separate no-isolation
positive still passes without COOP/COEP or SharedArrayBuffer. A host applying
CSP must allow the generated inline loader and its
verified script/worker/worklet Blob URLs; a denied Worker is a refusal, not a
fallback. Do not remove isolation errors or MIME/hash checks to make a host pass.

## Executable browser gates

The M5 workflow preserves the complete **36-job M4** compatibility workflow for
release branches and dispatch. It adds threaded execution of the original
M1–M4 input, geometry, history, physics, project and rendering oracles at
**800×450 DPR1** and **640×400 DPR2**, with 0/1/3/8/16-body controls. New chemical
and thermal browser tests cover full authored tuples, exact Undo/Redo, first
advancement, actual material conversion/transport and exact Reset.

`sf_m5_browser_ci.py` selects an existing strict harness, creates a unique
Chromium process group and ephemeral CDP/HTTP ports, verifies the artifact before
and after execution, and retains the original outcome. Compatibility is served
without isolation headers. It never retries state-changing input or manufactures
physical observations. Terminal captures remain after genuine input.

`sf_m5_bootstrap_ci.py` additionally executes actual-browser missing-header,
insecure-origin, blocked-worker, missing/corrupt/hash-only runtime, bad-MIME and
invalid-request cases. The nested-path TOCTOU positive deliberately changes the
host's second response and requires continued consumption of original verified
bytes. Positive one-worker controls and multiworker cases record actual native
participation; higher counts are qualified only on hosts that actually ran them.

Routine mainline keeps the accepted 15 compatibility jobs, adds a practical
threaded startup/chemistry/host-refusal lane, and discovers the new scientific
and bounded-performance Godot suites in the existing Linux architecture.
Full threaded regression and repeated-performance workloads remain release or
explicit-dispatch scope. Their routine skip is recorded as unexecuted, not pass.
Windows, serial-equivalence and physical-stress lanes retain their existing
optional trigger semantics.

The M5 aggregate fails for any missing, skipped, failed or cancelled required
job. Its success explicitly sets `release_ready: false`: the complete release
ledger, independent exact-head review, post-merge execution and genuine human
Gallery acceptance remain required. Chromium receipts do not qualify Firefox,
WebKit, every public host, cross-browser equivalence or bitwise replay.

## Related owners

- [Normative v1 architecture and SF-T01–SF-T12](SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md)
- [Workshop and retained physical/browser contracts](SF-M3-RAPIER-WORKSHOP.md)
- [Portable projects, Gallery and evidence](SF-M4-PROJECTS-EXHIBITIONS.md)
- [Performance measurements and acceptance limits](SF-M5-PERFORMANCE.md)
