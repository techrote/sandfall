---
title: SF-M5 D01 — Production performance observations
status: Current
document-kind: contract
scope: Bounded production timing and executable measurement; platform qualification requires retained exact-source runs
canonical-for: []
last-reviewed: 2026-11-01
related-documents: [SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md, SF-M3-RAPIER-WORKSHOP.md, SF-M4-PROJECTS-EXHIBITIONS.md]
---

# SF-M5 D01 — Production performance observations

The [v1 performance policy](SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md#103-performance-policy)
requires measurements, fixed **1/60-second** solver steps and truthful slowdown
reporting. There is no unconditional 60 FPS or sixteen-body throughput promise.
This machinery observes the ordinary application and retained native/Rapier
owners. It does not run an alternate solver or select a lighter test scene.

## Measurement boundaries

`performance_sampler.gd` keeps a fixed vocabulary, exact cumulative counts,
sums and maxima, and at most **4096 samples per metric**. Quantiles use nearest
rank on that bounded recent window. Every distribution identifies its first and
last sequence, window count and sample timestamp. Once a window wraps, its
p50/p95 must be labelled recent-window statistics; the separate lifetime maximum
still retains earlier outliers. Sorting occurs on copied values at observation
time, at most once per second. Explicit evidence export can force a fresh copy.

| Observation | Measured boundary and limits |
|---|---|
| Native tick | Existing C++ steady-clock `simulation_time_ms` for completed native ticks; full Godot call duration is a separate metric |
| Coupled tick | Host request through native/Rapier advancement and work accounting, before constructing the returned observation |
| Rapier step / flush | Existing actual manual `space_step` and `space_flush_queries` timings; zero-body scenes contribute no samples |
| Collider build / sync | Existing collider-budget build duration when chunks were processed; complete sync includes snapshot extraction and queueing |
| Feedback / collision work | Actual applied/stale feedback, contact/displaced-cell, scanned-cell and scheduler-job counters |
| Render snapshot / upload | Copied native snapshot acquisition and complete successful canvas publication (including snapshot acquisition, validation, CPU image updates and texture submission); `render_upload_ms` is inclusive, not GPU duration; payload bytes and rectangle counts are cumulative |
| Physics callback | Commands, zero-to-four fixed-step requests and any canvas publication |
| Frame interval | Monotonic interval between ordinary Godot `_process` callbacks; this is not a GPU completion time |
| Pacing / backlog | Requested rate `60 × speed`, actual tick counters, scheduled callback credit, remaining credit, pending Step and collider counts |
| Memory | Godot static-allocator current/peak; browser/CDP memory values are separately labelled and do not claim process RSS or all WASM memory |

Each host configuration starts a new measurement epoch. A staged project
transfers its actual measurement owner along with its native/Rapier owners.
Application/frame and canvas counters have their own timestamps and remain
application-lifetime observations. Consumers must compare matching epochs and
must not subtract counters across project replacement.

`scheduled_tick_credits` counts running physics callbacks at the selected rate.
`completed_callback_ticks` also counts explicitly requested paused Steps. Their
unqualified lifetime difference is not a backlog measurement: menu/focus/reset
clearances and paused Steps retain their accepted semantics. Actual pending
credit, pending Steps and pending colliders are separately observable. The
browser throughput interval admits only continuous running at one rate in one
session, and reports requested versus achieved wall-clock rate even when the
Godot scheduler itself falls behind real time.

The first tick's start and last completed native tick's end are recorded.
Browser throughput is computed from differences in observed counters over a
measured wall interval. It must not be inferred from tick latency, requested
speed, build flags or `requestAnimationFrame` alone. Idle time and a paused
window are not counted as continuous-running throughput.

## Integrity gates

`test_sandfall_performance.gd` executes the production native/Rapier host on
Blank, Material Lab and the existing sixteen-body Gallery definition, and
checks counter agreement, zero-body ownership, fixed dt, new-session retirement,
copied observations and bounded quantile scope. A real Rapier-only partial
failure must retain one Rapier step and zero completed native ticks, with no
invented native latency sample. The sample-window test retains an early outlier
after wrap instead of silently erasing the lifetime maximum.

Run the focused test only with an explicitly identified native runtime:

```sh
godot --headless --path build/web-sandfall-project \
  --script res://tests/test_sandfall_performance.gd
```

The command is backend evidence, not browser qualification. Compatibility and
threaded browser workloads, host metadata, repeated measurements and independent
review belong to the final SF-M5 release ledger. No new performance threshold is
retroactively selected to make a slow sample pass. Acceptance requires complete,
finite, source-bound measurements, unchanged fixed-step/capacity behavior and
explicit disclosure of achieved rate, outliers, observation overhead and any
remaining platform or exhibition gate.

## Actual-browser measurement and repetition

Use an isolated Chromium process and a verified source-matched Web export for
each measurement. The same runner accepts either profile. It checks served
bytes and the runtime's native hash, retains genuine trusted DOM input and
waits for settled source-derived controls before each one-shot UI action. It
does not retry state-changing clicks or drive an application command setter.

```sh
node tools/sandfall/sf_m5_performance.mjs \
  --port 9231 --url 'http://127.0.0.1:8040/?test=1' \
  --verification sf-m5-evidence/artifact-verification.json \
  --profile compat --workload sixteen_body --duration-ms 30000 \
  --width 800 --height 450 --dpr 1 --repetition 1 \
  --output sf-m5-evidence/performance-compat-sixteen-1.json
```

Run `blank`, `material_lab` and `sixteen_body` from the existing production
definitions. The first two launch through Sandbox/template/Run controls; the
sixteen-body workload launches through the searchable Gallery. Thirty actual
native ticks precede the registered 30-second measurement interval. The final
Pause and current-distribution gate preserve a stable endpoint. Native latency
distributions cover the scene lifetime including warmup; the separately
reported throughput interval excludes warmup and the final Pause. A wrapped
latency window remains explicitly scoped.

Threaded runs use `--profile threaded`, their own artifact-verification receipt,
and an explicit matching `--workers 2 --url 'http://127.0.0.1:8040/?test=1&workers=2'`
(or a supported count). They require actual browser isolation/worker capability.
Material and sixteen-body multiworker runs require observed native worker
participation; an idle blank scene cannot establish parallel execution merely
by reporting a configured count. One-worker threaded controls remain valid and
must not be reported as multiworker execution.

Use at least three separately executed runs per comparison population, each in
a fresh isolated browser process. Keep requested duration, viewport/DPR, worker
count, browser, host and source constant within a population. No other workload
should run simultaneously on the measurement host unless contention is
explicitly the experiment. The established browser viewports are 800×450 DPR1
and 640×400 DPR2. Source/native/Rapier/toolchain/served-byte identities remain in
the input verifier and each browser receipt.

```sh
python3 tools/sandfall/sf_m5_performance_summary.py \
  sf-m5-evidence/performance-compat-sixteen-1.json \
  sf-m5-evidence/performance-compat-sixteen-2.json \
  sf-m5-evidence/performance-compat-sixteen-3.json \
  --output sf-m5-evidence/performance-summary.json
```

The reducer rejects duplicate receipt bytes, dirty harnesses, failed runs and
insufficient repetition. It keeps source/profile/workload/host/browser/viewport/
duration populations separate; reports throughput variation, per-run latency
quantiles, outliers and resource trends; and never calls a median of per-run
p95s a pooled p95. CDP main-thread task time and JS heap are partial process
observations, with their limits stated beside the values. Headless software
rendering is identified as such in the retained launch command/environment,
not extrapolated to the user's GPU or a human exhibition verdict.

`test_sf_m5_performance_assertions.mjs` uses explicitly synthetic negative
receipts to ensure stale distributions, missing timing, wrong worker profiles,
false zero-body Rapier counts, changing epochs and shortened measurement windows
cannot qualify. Passing those oracle tests does not count as a browser run.
