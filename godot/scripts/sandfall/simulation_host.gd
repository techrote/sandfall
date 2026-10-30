class_name SandfallSimulationHost
extends Node2D

# Main-thread solver owner. This service never schedules itself, polls input,
# owns Edit/Run UI state, or creates an actor. Each accepted tick is requested
# explicitly by the application and reports the actual two solver counters.
const FIXED_DELTA: float = 1.0 / 60.0
const TERRAIN_CHUNKS_PER_PASS: int = 32
const TERRAIN_BUDGET_USEC: int = 750
const MAX_INITIAL_TERRAIN_PASSES: int = 256
const MAX_INITIAL_BODIES: int = 3

var _native_world: Variant
var _demo_bridge: Variant
var _rapier_bridge: CyberRapierPhysicsBridge
var _bodies: Array[RigidBody2D] = []
var _body_sizes: PackedVector2Array = PackedVector2Array()
var _definition: Dictionary = {}
var _ready: bool = false
var _fault: bool = false
var _error: String = ""
var _hard_surface_revision: int = -1
var _contacts_total: int = 0
var _displaced_total: int = 0
var _moves_total: int = 0
var _initial_material_sha256: String = ""
var _initial_body_states: Array = []
var _rapier_probe: Dictionary = {}
var _cpp_exception_probe: bool = false


func configure(definition: Dictionary) -> Dictionary:
	var validation: String = _validate_definition(definition)
	if not validation.is_empty():
		_enter_fault(validation)
		return state()
	shutdown()
	_definition = definition.duplicate(true)
	_fault = false
	_error = ""
	_contacts_total = 0
	_displaced_total = 0
	_moves_total = 0
	_cpp_exception_probe = false
	if not is_inside_tree():
		_enter_fault("Simulation host must be inside the scene tree")
		return state()
	if not CyberWebCapabilities.native_available():
		_enter_fault("Native Sandfall simulation extension unavailable")
		return state()
	if int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60)) != 60:
		_enter_fault("Sandfall requires a fixed physics tick rate of 60 Hz")
		return state()
	_native_world = ClassDB.instantiate(&"CyberNativeCellWorld")
	_demo_bridge = ClassDB.instantiate(&"CyberDemoBridge")
	if _native_world == null or _demo_bridge == null or _native_world.has_failed():
		_enter_fault("Native Sandfall world construction failed")
		return state()
	if not _demo_bridge.build_world(_native_world, _definition.rectangles):
		_enter_fault("Initial material construction refused: " + str(_demo_bridge.get_last_error()))
		return state()
	# Apply to the installed world, never to a camera-derived region. The
	# retained adapter also preserves interest across transactional install.
	var margin: Vector2i = _definition.simulation_margin
	_native_world.set_simulation_window(
		_definition.simulation_origin, _definition.simulation_size, margin.x, margin.y
	)
	_native_world.set_simulation_window_enabled(true)
	_native_world.set_interest_center(
		Vector2i(_definition.simulation_origin) + Vector2i(_definition.simulation_size) / 2
	)
	_native_world.set_cadence_lod_enabled(bool(_definition.cadence_lod))
	var revision_before: int = int(_native_world.get_revision())
	var malformed_refused: bool = not _demo_bridge.import_level(_native_world, PackedByteArray([0]))
	_cpp_exception_probe = malformed_refused \
		and str(_demo_bridge.get_last_error()) == "Wrong world payload length" \
		and int(_native_world.get_revision()) == revision_before
	print("SANDFALL_CPP_EXCEPTION_PROBE ", _cpp_exception_probe)
	if not _cpp_exception_probe:
		_enter_fault("Native malformed-import exception preflight failed")
		return state()
	if _rapier_probe.is_empty():
		_rapier_probe = CyberWebCapabilities.rapier_probe()
		print("SANDFALL_RAPIER_PROBE ", JSON.stringify(_rapier_probe))
	_initial_material_sha256 = material_identity()
	if _initial_material_sha256.is_empty():
		_enter_fault("Initial material identity could not be captured")
		return state()
	if not _definition.bodies.is_empty():
		if not bool(_rapier_probe.get("ok", false)):
			_enter_fault(str(_rapier_probe.get("reason", "Rapier unavailable")))
			return state()
		_create_bodies()
		_rapier_bridge = CyberRapierPhysicsBridge.new()
		var bridge_error: Error = _rapier_bridge.initialize(get_world_2d().space, _bodies, _body_sizes)
		if bridge_error != OK:
			_enter_fault("Manual Rapier bridge initialization failed: " + error_string(bridge_error))
			return state()
		for index: int in range(_bodies.size()):
			_bodies[index].freeze = false
			var initial: Dictionary = _definition.bodies[index]
			_rapier_bridge.reset_body(index, initial.position, float(initial.rotation))
		_rapier_bridge.refresh_all_states()
		_rapier_bridge.reset_result_tracking()
		for _pass: int in range(MAX_INITIAL_TERRAIN_PASSES):
			_sync_terrain()
			if _fault:
				return state()
			if _rapier_bridge.pending_hard_surface_chunks() == 0:
				break
		if _rapier_bridge.pending_hard_surface_chunks() != 0:
			_enter_fault("Initial terrain collider readiness did not complete")
			return state()
	_initial_body_states = _read_body_states()
	_ready = true
	return state()


func tick_once() -> Dictionary:
	var before_native: int = _native_tick()
	var before_rapier: int = _rapier_steps()
	if not _ready or _fault:
		return _tick_receipt(false, before_native, before_rapier, "not_ready")
	if bool(_native_world.has_failed()):
		_enter_fault("Native world failed before the next tick: " + str(_native_world.get_last_tick_error()))
		return _tick_receipt(false, before_native, before_rapier, "native_failed")
	if _bridge_active():
		_sync_terrain()
		if _fault:
			return _tick_receipt(false, before_native, before_rapier, "terrain_refused")
		if _rapier_bridge.pending_hard_surface_chunks() != 0:
			return _tick_receipt(false, before_native, before_rapier, "terrain_pending")
		_rapier_bridge.apply_cellular_results(before_native, _native_world.rigid_body_results())
		_rapier_bridge.step()
		_native_world.prepare_rigid_body_coupling(_rapier_bridge.pack_body_states(), true)
	else:
		_native_world.prepare_rigid_body_coupling(PackedFloat32Array(), false)
	if not _advance_native_tick():
		_enter_fault("Native tick refused after solver advancement: " + str(_native_world.get_last_tick_error()))
		return _tick_receipt(false, before_native, before_rapier, "native_tick_refused")
	_contacts_total += int(_native_world.get_rigid_body_contacts_last_tick())
	_displaced_total += int(_native_world.get_rigid_body_displaced_last_tick())
	_moves_total += int(_native_world.get_moves_last_tick())
	var native_delta: int = _native_tick() - before_native
	var rapier_delta: int = _rapier_steps() - before_rapier
	if native_delta != 1 or rapier_delta != (1 if _bridge_active() else 0):
		_enter_fault("Solver tick ownership invariant failed")
		return _tick_receipt(false, before_native, before_rapier, "counter_mismatch")
	return _tick_receipt(true, before_native, before_rapier, "advanced")


func _advance_native_tick() -> bool:
	# Single dispatch point also permits an explicitly labelled negative test
	# subclass to refuse the native phase after an actual Rapier step.
	return bool(_native_world.simulation_tick())


func state(include_material_identity: bool = false) -> Dictionary:
	var result: Dictionary = {
		"ready": _ready and not _fault, "fault": _fault, "error": _error,
		"native_available": CyberWebCapabilities.native_available(),
		"rapier_available": bool(_rapier_probe.get("ok", false)),
		"rapier_reason": str(_rapier_probe.get("reason", "not probed")),
		"rapier_probe": _rapier_probe.duplicate(true),
		"cpp_exception_probe": _cpp_exception_probe,
		"native_tick": _native_tick(), "rapier_steps": _rapier_steps(),
		"native_attempted_tick": int(_native_world.get_attempted_tick_index()) if _native_world != null else 0,
		"native_revision": int(_native_world.get_revision()) if _native_world != null else 0,
		"bridge_active": _bridge_active(),
		"pending_colliders": _rapier_bridge.pending_hard_surface_chunks() if _bridge_active() else 0,
		"contacts_total": _contacts_total, "displaced_total": _displaced_total,
		"moves_total": _moves_total,
		"moves_last_tick": int(_native_world.get_moves_last_tick()) if _native_world != null else 0,
		"workers": int(_native_world.get_worker_threads()) if _native_world != null else 0,
		"initial_material_sha256": _initial_material_sha256,
		"initial_body_states": _initial_body_states.duplicate(true),
		"body_states": _read_body_states(), "body_sizes": _body_size_values(),
		"initial_definition_id": str(_definition.get("id", "")),
		"initial_definition_revision": int(_definition.get("revision", 0)),
		"world_size": [1024, 1024], "initial_view": [480, 270],
		"simulation_interest": _interest_values(), "fixed_delta": FIXED_DELTA,
	}
	if include_material_identity:
		result["current_material_sha256"] = material_identity()
	return result


func material_identity() -> String:
	if _native_world == null or _demo_bridge == null or _native_world.has_failed():
		return ""
	var payload: PackedByteArray = _demo_bridge.export_level(_native_world)
	if payload.is_empty():
		return ""
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(payload)
	return hashing.finish().hex_encode()


func take_render_snapshot(force_full: bool = false) -> Dictionary:
	if not _ready or _fault or _native_world == null:
		return {"failed": true, "error": _error if _fault else "World is not ready"}
	var packet: Dictionary = _native_world.take_render_snapshot(force_full)
	var copied: Dictionary = packet.duplicate(true)
	copied["rectangles"] = PackedInt32Array(packet.get("rectangles", PackedInt32Array())).duplicate()
	copied["cells"] = PackedByteArray(packet.get("cells", PackedByteArray())).duplicate()
	return copied


func capture_physical_state() -> Dictionary:
	if not _ready or _fault:
		return {"ok": false, "error": "Cannot capture an unready or failed session"}
	var payload: PackedByteArray = _demo_bridge.export_physical_state(_native_world)
	return {
		"ok": not payload.is_empty(), "native_payload": payload.duplicate(),
		"definition": _definition.duplicate(true), "bodies": _read_body_states(),
		"native_tick": _native_tick(), "rapier_steps": _rapier_steps(),
	}


func restore_physical_state(snapshot: Dictionary) -> Dictionary:
	# Internal continuation fixture, not a portable project/archive API. Validate
	# all body values before construction so malformed input never partly restores.
	var restored_definition: Dictionary = snapshot.get("definition", {})
	var body_values: Array = snapshot.get("bodies", [])
	var validation: String = _validate_definition(restored_definition)
	if not validation.is_empty() or not snapshot.get("native_payload") is PackedByteArray \
			or body_values.size() != restored_definition.get("bodies", []).size():
		return {"ok": false, "error": "Malformed internal physical snapshot"}
	for row: Variant in body_values:
		if not row is Array or row.size() != 7:
			return {"ok": false, "error": "Malformed internal body snapshot"}
		for component: int in range(6):
			if not (row[component] is int or row[component] is float) or not is_finite(float(row[component])):
				return {"ok": false, "error": "Nonfinite internal body snapshot"}
	var installed: Dictionary = configure(restored_definition)
	if not bool(installed.ready):
		return {"ok": false, "error": str(installed.error)}
	if not _demo_bridge.import_physical_state(_native_world, snapshot.native_payload):
		_enter_fault("Physical state restore refused: " + str(_demo_bridge.get_last_error()))
		return {"ok": false, "error": _error}
	for index: int in range(_bodies.size()):
		var row: Array = body_values[index]
		var rid: RID = _bodies[index].get_rid()
		_rapier_bridge.reset_body(index, Vector2(float(row[0]), float(row[1])), float(row[2]))
		PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2(float(row[3]), float(row[4])))
		PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, float(row[5]))
		PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING, bool(row[6]))
	if _bridge_active():
		_rapier_bridge.refresh_all_states()
		_rapier_bridge.reset_result_tracking()
		_hard_surface_revision = -1
		for _pass: int in range(MAX_INITIAL_TERRAIN_PASSES):
			_sync_terrain()
			if _fault:
				return {"ok": false, "error": _error}
			if _rapier_bridge.pending_hard_surface_chunks() == 0:
				break
		if _rapier_bridge.pending_hard_surface_chunks() != 0:
			_enter_fault("Restored terrain collider readiness did not complete")
			return {"ok": false, "error": _error}
	return {"ok": true, "state": state()}


func shutdown() -> void:
	_ready = false
	# Remove the old graph before shutdown reactivates the shared physics space.
	for body: RigidBody2D in _bodies:
		if is_instance_valid(body):
			body.freeze = true
			body.collision_layer = 0
			body.collision_mask = 0
			remove_child(body)
	if _rapier_bridge != null:
		_rapier_bridge.shutdown()
		_rapier_bridge = null
	for body: RigidBody2D in _bodies:
		if is_instance_valid(body):
			body.free()
	_bodies.clear()
	_body_sizes = PackedVector2Array()
	_native_world = null
	_demo_bridge = null
	_hard_surface_revision = -1
	_initial_material_sha256 = ""
	_initial_body_states.clear()


func _exit_tree() -> void:
	shutdown()


func _create_bodies() -> void:
	for initial: Dictionary in _definition.bodies:
		var body: RigidBody2D = RigidBody2D.new()
		body.name = "SandfallBody%d" % (_bodies.size() + 1)
		body.freeze = true
		body.position = initial.position
		body.rotation = float(initial.rotation)
		body.mass = float(initial.mass)
		body.gravity_scale = float(initial.gravity_scale)
		body.linear_damp = float(initial.linear_damp)
		body.angular_damp = float(initial.angular_damp)
		body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
		var material: PhysicsMaterial = PhysicsMaterial.new()
		material.friction = 0.78
		material.bounce = 0.0
		material.rough = true
		material.absorbent = true
		body.physics_material_override = material
		var collider: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = initial.size
		collider.shape = shape
		body.add_child(collider)
		add_child(body)
		_bodies.append(body)
		_body_sizes.append(initial.size)


func _sync_terrain() -> void:
	if not _bridge_active():
		return
	var revision: int = int(_native_world.get_hard_surface_revision())
	if revision != _hard_surface_revision:
		if _rapier_bridge.queue_hard_surface_chunk_snapshot(_native_world.get_hard_surface_chunk_rectangles()):
			_hard_surface_revision = revision
		else:
			_enter_fault("Native terrain collider snapshot was refused")
			return
	_rapier_bridge.process_hard_surface_collider_budget(TERRAIN_CHUNKS_PER_PASS, TERRAIN_BUDGET_USEC)


func _bridge_active() -> bool:
	return _rapier_bridge != null and _rapier_bridge.is_initialized()


func _native_tick() -> int:
	return int(_native_world.get_tick_index()) if _native_world != null else 0


func _rapier_steps() -> int:
	return _rapier_bridge.manual_step_count() if _bridge_active() else 0


func _read_body_states() -> Array:
	var result: Array = []
	if not _bridge_active():
		return result
	for index: int in range(_bodies.size()):
		var rid: RID = _bodies[index].get_rid()
		var pose: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
		var velocity: Vector2 = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		result.append([pose.origin.x, pose.origin.y, pose.get_rotation(), velocity.x, velocity.y,
			float(PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)),
			bool(PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING))])
	return result


func _body_size_values() -> Array:
	var result: Array = []
	for dimensions: Vector2 in _body_sizes:
		result.append([dimensions.x, dimensions.y])
	return result


func _interest_values() -> Dictionary:
	if _definition.is_empty():
		return {}
	var origin: Vector2i = _definition.simulation_origin
	var dimensions: Vector2i = _definition.simulation_size
	var margin: Vector2i = _definition.simulation_margin
	return {"origin": [origin.x, origin.y], "size": [dimensions.x, dimensions.y],
		"margin": [margin.x, margin.y],
		"native_window_enabled": bool(_native_world.get_simulation_window_enabled()) if _native_world != null else false,
		"cadence_lod": bool(_native_world.get_cadence_lod_enabled()) if _native_world != null else false,
		"coordinate_source": "authored definition; native adapter has no region-coordinate getter",
		"camera_independent": true}


func _tick_receipt(advanced: bool, native_before: int, rapier_before: int, reason: String) -> Dictionary:
	var result: Dictionary = state()
	result["advanced"] = advanced
	result["reason"] = reason
	result["native_delta"] = _native_tick() - native_before
	result["rapier_delta"] = _rapier_steps() - rapier_before
	result["partial_advancement"] = _fault and (result.native_delta != 0 or result.rapier_delta != 0)
	return result


func _enter_fault(reason: String) -> void:
	_fault = true
	_ready = false
	_error = reason
	# Keep actual solver counters and the failed session for inspection. No
	# rollback is claimed, and no later tick is accepted until reconstruction.
	for body: RigidBody2D in _bodies:
		if is_instance_valid(body):
			body.freeze = true


func _validate_definition(definition: Dictionary) -> String:
	if definition.is_empty() or not definition.get("rectangles") is PackedInt32Array \
			or not definition.get("bodies") is Array:
		return "Initial scene definition is malformed"
	if definition.get("world_size") != Vector2i(1024, 1024) \
			or definition.get("initial_view") != Vector2i(480, 270):
		return "SF-M1 requires the fixed 1024 world and 480x270 initial view"
	for field: String in ["simulation_origin", "simulation_size", "simulation_margin"]:
		if not definition.get(field) is Vector2i:
			return "Initial simulation interest is malformed"
	var origin: Vector2i = definition.simulation_origin
	var dimensions: Vector2i = definition.simulation_size
	var margin: Vector2i = definition.simulation_margin
	if origin.x < 0 or origin.y < 0 or dimensions.x < 1 or dimensions.y < 1 \
			or origin.x + dimensions.x > 1024 or origin.y + dimensions.y > 1024 \
			or margin.x < 0 or margin.y < 0 or not definition.get("cadence_lod") is bool:
		return "Initial simulation interest is outside supported bounds"
	if definition.bodies.size() != 0 and definition.bodies.size() != MAX_INITIAL_BODIES:
		return "SF-M1 supports the empty or established three-body graph only"
	for initial: Variant in definition.bodies:
		if not initial is Dictionary or not initial.get("position") is Vector2 \
				or not initial.get("size") is Vector2:
			return "Initial body definition is malformed"
		var position_value: Vector2 = initial.position
		var dimensions_value: Vector2 = initial.size
		if not position_value.is_finite() or not dimensions_value.is_finite() \
				or dimensions_value.x <= 0.0 or dimensions_value.y <= 0.0 \
				or position_value.x < 0.0 or position_value.y < 0.0 \
				or position_value.x >= 1024.0 or position_value.y >= 1024.0:
			return "Initial body bounds are invalid"
		for field: String in ["rotation", "mass", "gravity_scale", "linear_damp", "angular_damp"]:
			if not (initial.get(field) is float or initial.get(field) is int) \
					or not is_finite(float(initial[field])):
				return "Initial body numeric values are invalid"
		if float(initial.mass) <= 0.0 or float(initial.linear_damp) < 0.0 or float(initial.angular_damp) < 0.0:
			return "Initial body mass/damping is invalid"
	return ""
