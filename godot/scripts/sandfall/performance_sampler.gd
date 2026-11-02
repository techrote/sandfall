class_name SandfallPerformanceSampler
extends RefCounted

# Observations only. This owner cannot request ticks, mutate a World or advance
# Rapier. Each named metric has an exact lifetime count/sum/max and a bounded
# 4096-value recent window. Quantiles use nearest rank and explicitly identify
# their window; a wrapped window is never labelled a lifetime distribution.
const CAPACITY: int = 4096
const METRICS: Array[String] = [
	"native_tick_ms", "native_dispatch_ms", "coupled_tick_ms",
	"rapier_step_ms", "rapier_flush_ms", "collider_build_ms", "collider_sync_ms",
	"render_snapshot_ms", "render_upload_ms", "frame_interval_ms", "physics_callback_ms",
]
const COUNTERS: Array[String] = [
	"native_completed", "tick_attempts", "tick_refusals", "rapier_completed",
	"feedback_applied", "feedback_stale_rejected", "native_contacts", "native_displaced",
	"native_scanned_cells", "native_scheduler_jobs", "render_snapshot_calls",
	"render_snapshot_refusals", "render_payload_bytes", "render_patch_rectangles",
	"collider_sync_calls", "collider_chunks_processed", "uploads", "payload_bytes",
	"patch_rectangles", "physics_callbacks", "pending_step_callbacks",
]

var _metrics: Dictionary = {}
var _counters: Dictionary = {}
var _started_usec: int = Time.get_ticks_usec()
var _first_tick_usec: int = 0
var _last_tick_usec: int = 0
var _last_snapshot_usec: int = -1000000
var _distribution_cache: Dictionary = {}


func record(metric: String, value: float) -> void:
	if metric not in METRICS or not is_finite(value) or value < 0.0:
		return
	if not _metrics.has(metric):
		_metrics[metric] = {"count": 0, "total": 0.0, "max": 0.0, "last": 0.0,
			"values": PackedFloat64Array()}
	var row: Dictionary = _metrics[metric]
	var values: PackedFloat64Array = row["values"]
	var count: int = int(row["count"])
	if values.size() < CAPACITY:
		values.append(value)
	else:
		values[count % CAPACITY] = value
	row["values"] = values
	row["count"] = count + 1
	row["total"] = float(row["total"]) + value
	row["max"] = maxf(float(row["max"]), value)
	row["last"] = value


func count(name: String, amount: int = 1) -> void:
	if name not in COUNTERS or amount < 0:
		return
	_counters[name] = int(_counters.get(name, 0)) + amount


func tick_completed(started_usec: int) -> void:
	if _first_tick_usec == 0:
		_first_tick_usec = started_usec
	_last_tick_usec = Time.get_ticks_usec()
	count("native_completed")


func compact() -> Dictionary:
	return {"counters": _counters.duplicate(), "started_usec": _started_usec,
		"first_tick_usec": _first_tick_usec, "last_tick_usec": _last_tick_usec}


func snapshot(force: bool = false) -> Dictionary:
	var now: int = Time.get_ticks_usec()
	# State/observation can be read repeatedly between production callbacks.
	# Sort bounded copies at most once per second, never on the solver path.
	if force or now - _last_snapshot_usec >= 1000000:
		_distribution_cache.clear()
		for name: String in _metrics:
			var row: Dictionary = _metrics[name]
			var ordered: PackedFloat64Array = row["values"].duplicate()
			ordered.sort()
			var size: int = ordered.size()
			_distribution_cache[name] = {
				"count": int(row["count"]), "total": float(row["total"]),
				"max": float(row["max"]), "last": float(row["last"]),
				"window_count": size, "window_first_sequence": int(row["count"]) - size + 1,
				"window_last_sequence": int(row["count"]),
				"p50": ordered[maxi(0, ceili(size * 0.50) - 1)],
				"p95": ordered[maxi(0, ceili(size * 0.95) - 1)],
				"window_max": ordered[size - 1],
			}
		_last_snapshot_usec = now
	var result: Dictionary = compact()
	result.merge({"schema": "sandfall-performance-v1", "clock": "Godot monotonic microseconds",
		"window_capacity": CAPACITY, "quantile_method": "nearest-rank",
		"distribution_sampled_usec": _last_snapshot_usec, "observed_usec": now,
		"metrics": _distribution_cache.duplicate(true)})
	return result
