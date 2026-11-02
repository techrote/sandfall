extends SceneTree

const Sampler = preload("res://scripts/sandfall/performance_sampler.gd")
const Host = preload("res://scripts/sandfall/simulation_host.gd")
const Definitions = preload("res://scripts/sandfall/scene_definitions.gd")

class RefusingNativeHost extends Host:
	func _advance_native_tick() -> bool:
		return false

var failures: Array[String] = []
var receipts: Dictionary = {}


func _init() -> void:
	call_deferred("run")


func run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	bounded_window()
	if not CyberWebCapabilities.native_available():
		failures.append("Native runtime unavailable; production measurements were not executed")
	else:
		await actual_owners()
	print("SANDFALL_PERFORMANCE_RESULT ", JSON.stringify({"ok": failures.is_empty(),
		"failures": failures, "receipts": receipts}, "", true, true))
	quit(0 if failures.is_empty() else 1)


func expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func bounded_window() -> void:
	var sampler: Variant = Sampler.new()
	# Force wrap with an early outlier: a tail percentile must not be presented
	# as a whole-run maximum or lose the exact lifetime observation count.
	sampler.record("native_tick_ms", 1000000.0)
	for index: int in Sampler.CAPACITY:
		sampler.record("native_tick_ms", float(index + 1))
	sampler.record("invented_metric", 1.0)
	sampler.record("native_tick_ms", -1.0)
	sampler.record("native_tick_ms", NAN)
	sampler.count("invented_counter")
	var sample: Dictionary = sampler.snapshot(true)
	var metric: Dictionary = sample.metrics.native_tick_ms
	expect(metric.count == 4097 and metric.window_count == 4096,
		"Bounded ring lost count or exceeded its capacity")
	expect(metric.p50 == 2048.0 and metric.p95 == 3892.0 and metric.window_max == 4096.0,
		"Nearest-rank tail quantiles do not describe the recorded values")
	expect(metric.max == 1000000.0 and metric.window_first_sequence == 2 and metric.window_last_sequence == 4097,
		"Lifetime maximum and wrapped tail scope were conflated")
	expect(sample.metrics.size() == 1 and sample.counters.is_empty(),
		"Unknown/nonfinite observations can grow or contaminate telemetry")
	sample.metrics.native_tick_ms.count = 0
	expect(sampler.snapshot(true).metrics.native_tick_ms.count == 4097,
		"A consumer mutated authoritative performance counters")
	receipts["bounded_window"] = sampler.snapshot(true)


func actual_owners() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	for scene_id: String in ["blank", "material_lab", "sixteen_body"]:
		var configured: Dictionary = host.configure(Definitions.get_definition(scene_id))
		expect(configured.ready, "Production scene did not become ready: " + scene_id)
		if not configured.ready:
			continue
		var before: Dictionary = host.performance_snapshot(true)
		expect(before.native_tick == 0 and before.counters.get("native_completed", 0) == 0,
			"Reconstruction retained a previous scene's measured ticks")
		var attempts: int = 0
		while host.state().native_tick < 48 and attempts < 1000:
			attempts += 1
			var result: Dictionary = host.tick_once()
			if result.fault:
				failures.append("Performance fixture faulted: " + str(result.error))
				break
			if result.advanced:
				host.take_render_snapshot()
			if attempts % 12 == 0:
				await process_frame
		var measured: Dictionary = host.performance_snapshot(true)
		var expected_rapier: int = 48 if scene_id == "sixteen_body" else 0
		expect(measured.native_tick == 48 and measured.counters.get("native_completed", 0) == 48,
			"Measured completion did not match actual native ticks: " + scene_id)
		expect(measured.rapier_steps == expected_rapier and measured.counters.get("rapier_completed", 0) == expected_rapier,
			"Measured Rapier count did not match actual owner steps: " + scene_id)
		expect(measured.metrics.native_tick_ms.count == 48 and measured.metrics.native_tick_ms.max > 0.0,
			"Native timing did not sample actual completed native calls")
		expect(measured.counters.get("render_snapshot_calls", 0) == 48,
			"Render sampling did not account for every consumed publication")
		expect(measured.fixed_delta == 1.0 / 60.0,
			"Timing instrumentation changed the fixed solver step")
		var tick: int = int(measured.native_tick)
		for _frame: int in 3:
			await process_frame
		expect(host.performance_snapshot(true).native_tick == tick,
			"Reading performance observations advanced simulation")
		receipts[scene_id] = measured
	host.free()
	var refusing: Variant = RefusingNativeHost.new()
	root.add_child(refusing)
	var setup: Dictionary = refusing.configure(Definitions.get_definition("sixteen_body"))
	expect(setup.ready, "Partial-failure performance control did not become ready")
	if setup.ready:
		var result: Dictionary = refusing.tick_once()
		var measured: Dictionary = refusing.performance_snapshot(true)
		expect(result.fault and result.native_delta == 0 and result.rapier_delta == 1,
			"Negative control did not execute a real Rapier-only partial step")
		expect(measured.counters.get("native_completed", 0) == 0 and measured.counters.get("rapier_completed", 0) == 1,
			"Partial failure was misreported as a successful native completion")
		expect(not measured.metrics.has("native_tick_ms") and measured.metrics.rapier_step_ms.count == 1,
			"A nonexistent native step polluted the latency distribution")
		receipts["partial_failure"] = measured
	refusing.free()
	await process_frame
