extends SceneTree

# Actual native/Rapier backend acceptance for the new neutral host. The final
# partial-failure case is explicitly injected at the native dispatch boundary;
# its Rapier step is real, and it is never presented as a successful solver run.
const Host = preload("res://scripts/sandfall/simulation_host.gd")
const Definitions = preload("res://scripts/sandfall/scene_definitions.gd")
const Canvas = preload("res://scripts/sandfall/world_canvas.gd")

class RefusingNativeHost extends Host:
	func _advance_native_tick() -> bool:
		return false

var _failures: Array[String] = []
var _receipts: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	if not CyberWebCapabilities.native_available():
		_failures.append("Native extension unavailable; backend acceptance was not executed")
		_finish()
		return
	await _inactive_and_camera()
	await _coupled_600_and_restore()
	await _refusals_and_partial_failure()
	_render_payload_negatives()
	_finish()


func _inactive_and_camera() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var definition: Dictionary = Definitions.get_definition("material_lab")
	var configured: Dictionary = host.configure(definition)
	_expect(bool(configured.ready), "Native-only scene did not become ready: " + str(configured.error))
	if not configured.ready:
		host.free()
		return
	_expect(bool(configured.cpp_exception_probe), "Native C++ malformed-import exception preflight failed")
	_expect(bool(configured.rapier_available), "Actual Rapier startup probe failed even though this scene has no bodies")
	_expect(int(configured.native_tick) == 0 and int(configured.rapier_steps) == 0, "Construction advanced a solver")
	for _frame: int in range(4):
		await physics_frame
	var idle: Dictionary = host.state(true)
	_expect(idle.native_tick == 0 and idle.rapier_steps == 0, "Unscheduled Edit preview advanced during ordinary frames")
	_expect(not idle.bridge_active and idle.body_states.is_empty(), "Native-only scene retained a body bridge")
	var canvas: Variant = Canvas.new()
	canvas.position = Vector2(25, 40)
	canvas.size = Vector2(700, 350)
	root.add_child(canvas)
	canvas.bind_host(host)
	var before_camera: Dictionary = host.state(true)
	var physical_before_camera: Dictionary = host.capture_physical_state()
	var content: Rect2 = canvas.global_content_rect()
	canvas.zoom_at(1.5, content.get_center())
	canvas.pan(Vector2(-30, -20))
	var camera: Dictionary = canvas.state()
	var after_camera: Dictionary = host.state(true)
	var physical_after_camera: Dictionary = host.capture_physical_state()
	_expect(before_camera.current_material_sha256 == after_camera.current_material_sha256, "Camera changed native material state")
	_expect(physical_before_camera.native_payload == physical_after_camera.native_payload,
		"Camera changed the actual native physical state, including its simulation region/configuration")
	_expect(before_camera.native_tick == after_camera.native_tick and before_camera.rapier_steps == after_camera.rapier_steps, "Camera advanced a solver")
	_expect(before_camera.simulation_interest == after_camera.simulation_interest, "Camera changed authored simulation interest")
	_expect(float(camera.zoom) > 1.0 and camera.camera_origin != [0.0, 0.0], "Camera controls did not change presentation")
	var view: Vector2 = Vector2(camera.view_size[0], camera.view_size[1])
	var origin: Vector2 = Vector2(camera.camera_origin[0], camera.camera_origin[1])
	_expect(canvas.global_to_world(content.get_center()).distance_to(origin + view * 0.5) < 0.001, "Aspect-fit global coordinates do not map to the world center")
	var held_packet: Dictionary = host.take_render_snapshot(true)
	var held_cells: PackedByteArray = held_packet.cells
	var held_copy: PackedByteArray = held_cells.duplicate()
	var step: Dictionary = host.tick_once()
	_expect(bool(step.advanced) and step.native_delta == 1 and step.rapier_delta == 0, "Inactive-bridge Step was not exactly native+1 / Rapier+0")
	_expect(held_cells == held_copy, "Later solver work mutated a published snapshot")
	var after_step: Dictionary = host.state()
	for _frame: int in range(4):
		await physics_frame
	_expect(host.state().native_tick == after_step.native_tick, "Host autonomously advanced after one requested Step")
	var paused_after_step: Dictionary = host.state()
	# The caller's definition must not become the mutable owner of a live run.
	definition.rectangles = PackedInt32Array([0, 0, 1024, 1024, 1])
	var captured: Dictionary = host.capture_physical_state()
	_expect(captured.definition.rectangles != definition.rectangles, "Live session retained the caller's mutable initial definition")
	var blank: Dictionary = host.configure(Definitions.get_definition("blank"))
	_expect(blank.ready and blank.native_tick == 0 and blank.rapier_steps == 0, "Blank template did not construct at tick zero")
	_expect(blank.body_states.is_empty() and not blank.bridge_active, "Blank template retained coupled bodies")
	_receipts["inactive_and_camera"] = {"ready_at_zero": configured, "camera": camera,
		"exact_step": step, "paused_after_step": paused_after_step, "blank": blank}
	canvas.free()
	host.free()
	await process_frame


func _coupled_600_and_restore() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var definition: Dictionary = Definitions.get_definition("physics_pit")
	var configured: Dictionary = host.configure(definition)
	_expect(bool(configured.ready), "Three-body scene did not become ready: " + str(configured.error))
	if not configured.ready:
		host.free()
		return
	_expect(configured.native_tick == 0 and configured.rapier_steps == 0 and configured.pending_colliders == 0, "Coupled construction did not finish at zero with ready terrain")
	var initial_hash: String = str(configured.initial_material_sha256)
	var initial_bodies: Array = configured.body_states.duplicate(true)
	var maximum_floor_y: float = 0.0
	var completed: int = 0
	var attempts: int = 0
	while completed < 600 and attempts < 12000:
		attempts += 1
		var tick: Dictionary = host.tick_once()
		if tick.fault:
			_failures.append("Actual coupled run faulted: " + str(tick.error))
			break
		if not tick.advanced:
			_expect(tick.reason == "terrain_pending" and tick.native_delta == 0 and tick.rapier_delta == 0, "Readiness fence advanced or misreported a solver")
			continue
		completed += 1
		_expect(tick.native_delta == 1 and tick.rapier_delta == 1, "Coupled tick was not exactly native+1 / Rapier+1")
		maximum_floor_y = maxf(maximum_floor_y, float(tick.body_states[0][1]))
		if completed % 20 == 0:
			print("SANDFALL_BACKEND_PROGRESS ", JSON.stringify({"native_tick": tick.native_tick,
				"rapier_steps": tick.rapier_steps, "contacts": tick.contacts_total, "displaced": tick.displaced_total}))
			await process_frame
	var coupled: Dictionary = host.state(true)
	_expect(completed == 600 and coupled.native_tick == 600 and coupled.rapier_steps == 600, "Actual 600 native / 600 Rapier contract failed")
	_expect(coupled.contacts_total > 0 and coupled.displaced_total > 0, "Actual coupled run had no positive contact/displacement")
	if coupled.body_states.size() == 3:
		_expect(absf(float(coupled.body_states[0][1]) - 159.0) <= 0.1 and maximum_floor_y <= 161.0, "One-pixel floor did not hold the first body")
		_expect(float(coupled.body_states[1][1]) > 100.0 and float(coupled.body_states[2][1]) > 100.0, "Water/sand bodies did not fall")
	for _frame: int in range(4):
		await physics_frame
	var paused: Dictionary = host.state()
	_expect(paused.native_tick == 600 and paused.rapier_steps == 600, "Ordinary paused frames advanced either solver")
	_expect(paused.body_states == coupled.body_states, "Paused frames changed the body graph")
	var saved: Dictionary = host.capture_physical_state()
	var save_restore_ok: bool = false
	_expect(bool(saved.get("ok", false)), "Native physical snapshot capture failed")
	if bool(saved.get("ok", false)):
		host.configure(Definitions.get_definition("blank"))
		_expect(not host.state().bridge_active, "Switch to blank retained the manual body bridge")
		var restored: Dictionary = host.restore_physical_state(saved)
		_expect(bool(restored.get("ok", false)), "Physical save/restore failed: " + str(restored.get("error", "")))
		if bool(restored.get("ok", false)):
			var roundtrip: Dictionary = host.capture_physical_state()
			_expect(roundtrip.native_payload == saved.native_payload, "Native physical payload did not round-trip byte-for-byte")
			var failures_before_body_compare: int = _failures.size()
			_compare_bodies(saved.bodies, roundtrip.bodies, "Restored")
			save_restore_ok = roundtrip.native_payload == saved.native_payload and _failures.size() == failures_before_body_compare
	var reset: Dictionary = host.configure(definition)
	_expect(reset.ready and reset.native_tick == 0 and reset.rapier_steps == 0, "Reset did not reconstruct both solver owners at zero")
	_expect(reset.initial_material_sha256 == initial_hash and host.material_identity() == initial_hash, "Reset did not reconstruct the source material identity")
	_compare_bodies(initial_bodies, reset.body_states, "Reset")
	_expect(reset.contacts_total == 0 and reset.displaced_total == 0 and reset.pending_colliders == 0, "Reset retained feedback or incomplete terrain")
	_receipts["coupled_600"] = {"result": coupled, "completed": completed,
		"maximum_floor_y": maximum_floor_y, "attempts": attempts,
		"paused": paused, "save_restore_ok": save_restore_ok, "reset": reset}
	host.free()
	await process_frame


func _refusals_and_partial_failure() -> void:
	var invalid: Dictionary = Definitions.get_definition("physics_pit")
	invalid.bodies.append(invalid.bodies[0].duplicate(true))
	var host: Variant = Host.new()
	root.add_child(host)
	var refused: Dictionary = host.configure(invalid)
	_expect(refused.fault and not refused.ready and refused.native_tick == 0 and refused.rapier_steps == 0, "Unsupported body graph was not refused before advancement")
	var retry: Dictionary = host.tick_once()
	_expect(not retry.advanced and retry.native_delta == 0 and retry.rapier_delta == 0, "Unready graph accepted a tick")
	host.free()
	var failing: Variant = RefusingNativeHost.new()
	root.add_child(failing)
	var configured: Dictionary = failing.configure(Definitions.get_definition("physics_pit"))
	_expect(configured.ready, "Partial-failure test could not construct real native/Rapier owners")
	if configured.ready:
		var partial: Dictionary = failing.tick_once()
		_expect(partial.fault and not partial.advanced and partial.partial_advancement, "Injected native refusal did not enter partial Fault")
		_expect(partial.native_tick == 0 and partial.rapier_steps == 1 \
			and partial.native_delta == 0 and partial.rapier_delta == 1,
			"Partial failure did not preserve the actual native0 / Rapier1 counters")
		for _attempt: int in range(3):
			var stopped: Dictionary = failing.tick_once()
			_expect(not stopped.advanced and stopped.native_tick == 0 and stopped.rapier_steps == 1, "Fault permitted later solver advancement")
		_receipts["negative_injected_native_refusal_after_real_rapier_step"] = partial
	failing.free()
	_receipts["negative_unsupported_body_graph"] = refused
	await process_frame


func _render_payload_negatives() -> void:
	var rectangle: PackedInt32Array = PackedInt32Array([0, 0, 85, 128, 0, 170])
	_expect(not Canvas.validate_packet(rectangle, PackedByteArray(), 2).is_empty(), "Renderer accepted empty RG8 data")
	var truncated: PackedByteArray = PackedByteArray()
	truncated.resize(21759)
	_expect(not Canvas.validate_packet(rectangle, truncated, 2).is_empty(), "Renderer accepted a one-byte-short RG8 payload")
	_expect(Canvas.validate_packet(PackedInt32Array([0, 0, 2, 1, 0, 4]), PackedByteArray([1, 2, 3, 4]), 2).is_empty(), "Renderer refused a valid compact RG8 packet")
	_expect(not Canvas.validate_packet(PackedInt32Array([1023, 0, 2, 1, 0, 4]), PackedByteArray([1, 2, 3, 4]), 2).is_empty(), "Renderer accepted an out-of-world patch")


func _compare_bodies(expected: Array, actual: Array, label: String) -> void:
	_expect(expected.size() == actual.size(), label + " body count changed")
	for index: int in range(mini(expected.size(), actual.size())):
		for component: int in range(6):
			_expect(absf(float(expected[index][component]) - float(actual[index][component])) <= 0.00001,
				label + " body value exceeded float32 restore tolerance")
		_expect(expected[index][6] == actual[index][6], label + " body sleep state changed")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("SANDFALL_BACKEND_TEST ", JSON.stringify({"ok": _failures.is_empty(),
		"failures": _failures, "receipts": _receipts,
		"scope": "actual native/Rapier backend; native refusal case explicitly injected; no browser/human acceptance claim"}))
	quit(0 if _failures.is_empty() else 1)
