class_name SandfallSimulationHost
extends Node2D

# Main-thread solver owner. This service never schedules itself, polls input,
# owns Edit/Run UI state, or creates an actor. Each accepted tick is requested
# explicitly by the application and reports the actual two solver counters.
const FIXED_DELTA: float = 1.0 / 60.0
const TERRAIN_CHUNKS_PER_PASS: int = 32
const TERRAIN_BUDGET_USEC: int = 750
const MAX_INITIAL_TERRAIN_PASSES: int = 256
const Registry = preload("res://scripts/sandfall/rapier_object_registry.gd")
const MAX_INITIAL_BODIES: int = Registry.MAX_OBJECTS

var _native_world: Variant
var _edit_bridge: Variant
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
var _object_registry: Variant = Registry.new()
var _object_revision: int = 0
var _object_feedback: Dictionary = {}
var _body_body_pairs: Dictionary = {}
var _object_mutating: bool = false
var _physics_viewport: SubViewport
var _body_root: Node2D


func configure(definition: Dictionary) -> Dictionary:
	var validation: String = _validate_definition(definition)
	if not validation.is_empty():
		if _ready and not _fault:
			var refused: Dictionary = state()
			refused["ready"] = false
			refused["error"] = validation
			refused["refused"] = true
			refused["partial"] = false
			return refused
		_enter_fault(validation)
		return state()
	shutdown()
	_definition = definition.duplicate(true)
	_object_registry = Registry.new()
	_object_registry.install(definition.bodies)
	_definition.bodies = _object_registry.definitions()
	_object_revision = 0
	_object_feedback.clear()
	_body_body_pairs.clear()
	_definition.rectangles = PackedInt32Array(definition.rectangles).duplicate()
	if definition.has("initial_cells"):
		_definition.initial_cells = PackedByteArray(definition.initial_cells).duplicate()
	_fault = false
	_error = ""
	_contacts_total = 0
	_displaced_total = 0
	_moves_total = 0
	_cpp_exception_probe = false
	if not is_inside_tree():
		_enter_fault("Simulation host must be inside the scene tree")
		return state()
	# Each logical scene owns an isolated physics space. An archive candidate
	# can therefore construct bodies/colliders while the current scene remains
	# intact, with neither graph ever appearing in the other's coupling space.
	_physics_viewport = SubViewport.new()
	_physics_viewport.name = "SandfallOwnedPhysics"
	_physics_viewport.world_2d = World2D.new()
	_physics_viewport.size = Vector2i(1, 1)
	_physics_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_physics_viewport)
	_body_root = Node2D.new()
	_physics_viewport.add_child(_body_root)
	# Empty scenes are native-only too: do not leave an automatically stepped
	# Rapier space merely because there is no bridge to deactivate it yet.
	PhysicsServer2D.space_set_active(_body_root.get_world_2d().space, false)
	if not CyberWebCapabilities.native_available():
		_enter_fault("Native Sandfall simulation extension unavailable")
		return state()
	if int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60)) != 60:
		_enter_fault("Sandfall requires a fixed physics tick rate of 60 Hz")
		return state()
	_native_world = ClassDB.instantiate(&"CyberNativeCellWorld")
	_demo_bridge = ClassDB.instantiate(&"CyberDemoBridge")
	_edit_bridge = ClassDB.instantiate(&"SandfallEditBridge")
	if _native_world == null or _demo_bridge == null or _native_world.has_failed():
		_enter_fault("Native Sandfall world construction failed")
		return state()
	var built: bool = bool(_demo_bridge.import_level(_native_world, _definition.initial_cells)) if _definition.has("initial_cells") else bool(_demo_bridge.build_world(_native_world, _definition.rectangles))
	if not built:
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
	_initial_material_sha256 = material_identity()
	if _initial_material_sha256.is_empty():
		_enter_fault("Initial material identity could not be captured")
		return state()
	if not _definition.bodies.is_empty():
		_probe_rapier_if_needed()
		if not bool(_rapier_probe.get("ok", false)):
			_enter_fault(str(_rapier_probe.get("reason", "Rapier unavailable")))
			return state()
		if not _create_bodies():
			_enter_fault("Project body construction failed")
			return state()
		_rapier_bridge = CyberRapierPhysicsBridge.new()
		var bridge_error: Error = _rapier_bridge.initialize(_body_root.get_world_2d().space, _bodies, _body_sizes, _object_registry.ids())
		if bridge_error != OK:
			_enter_fault("Manual Rapier bridge initialization failed: " + error_string(bridge_error))
			return state()
		for index: int in range(_bodies.size()):
			var initial: Dictionary = _definition.bodies[index]
			_install_body_state(_bodies[index], initial, [])
		_rapier_bridge.refresh_all_states()
		_rapier_bridge.reset_result_tracking()
		_rapier_bridge.enable_diagnostics()
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
	if _bridge_active():
		# Establish actual body occupancy at setup without advancing either solver.
		# Later edit snapshots never clear or rebuild these live masks/feedback.
		_native_world.prepare_rigid_body_coupling(_rapier_bridge.pack_body_states(), false)
	_ready = true
	return state()


func stage_project(definition: Dictionary) -> Dictionary:
	# No live owner is retired until every native/Rapier readiness check passes.
	var error: String = _validate_definition(definition)
	if not error.is_empty():
		return {"ok": false, "error": error, "partial": false}
	var candidate: SandfallSimulationHost = _new_staging_host()
	add_child(candidate)
	candidate._rapier_probe = _rapier_probe.duplicate(true)
	var result: Dictionary = candidate.configure(definition)
	if not bool(result.ready):
		var reason: String = str(result.error)
		candidate.free()
		return {"ok": false, "error": "candidate_readiness: " + reason, "partial": false}
	return {"ok": true, "candidate": candidate, "state": result}


func _new_staging_host() -> SandfallSimulationHost:
	return SandfallSimulationHost.new()


func commit_staged_project(candidate: SandfallSimulationHost) -> Dictionary:
	if candidate == null or candidate == self or candidate.get_parent() != self \
			or not candidate._ready or candidate._fault or candidate._native_tick() != 0 \
			or candidate._rapier_steps() != 0 or not is_instance_valid(candidate._physics_viewport):
		return {"ok": false, "error": "invalid_staged_owner", "partial": false}
	# The candidate already owns its World2D, body RIDs, terrain and native
	# state. Moving the containing viewport does not rebuild or rebind a body.
	# No allocation/fallible solver operation follows retirement of the old graph.
	shutdown()
	candidate._physics_viewport.reparent(self, false)
	_native_world = candidate._native_world
	_edit_bridge = candidate._edit_bridge
	_demo_bridge = candidate._demo_bridge
	_rapier_bridge = candidate._rapier_bridge
	_bodies = candidate._bodies
	_body_sizes = candidate._body_sizes
	_definition = candidate._definition
	_ready = candidate._ready
	_fault = candidate._fault
	_error = candidate._error
	_hard_surface_revision = candidate._hard_surface_revision
	_contacts_total = candidate._contacts_total
	_displaced_total = candidate._displaced_total
	_moves_total = candidate._moves_total
	_initial_material_sha256 = candidate._initial_material_sha256
	_initial_body_states = candidate._initial_body_states
	_rapier_probe = candidate._rapier_probe
	_cpp_exception_probe = candidate._cpp_exception_probe
	_object_registry = candidate._object_registry
	_object_revision = candidate._object_revision
	_object_feedback = candidate._object_feedback
	_body_body_pairs = candidate._body_body_pairs
	_physics_viewport = candidate._physics_viewport
	_body_root = candidate._body_root
	candidate._bodies = []
	candidate._initial_body_states = []
	candidate._rapier_bridge = null
	candidate._physics_viewport = null
	candidate._body_root = null
	candidate._native_world = null
	candidate._edit_bridge = null
	candidate._demo_bridge = null
	candidate.free()
	return {"ok": true, "state": state()}


func tick_once() -> Dictionary:
	var before_native: int = _native_tick()
	var before_rapier: int = _rapier_steps()
	if not _ready or _fault or _object_mutating:
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
		_record_applied_feedback()
		_rapier_bridge.step()
		_record_body_contacts()
		_native_world.prepare_rigid_body_coupling(_rapier_bridge.pack_body_states(), true)
	else:
		_native_world.prepare_rigid_body_coupling(PackedFloat32Array(), false)
	if not _advance_native_tick():
		_enter_fault("Native tick refused after solver advancement: " + str(_native_world.get_last_tick_error()))
		return _tick_receipt(false, before_native, before_rapier, "native_tick_refused")
	_contacts_total += int(_native_world.get_rigid_body_contacts_last_tick())
	_displaced_total += int(_native_world.get_rigid_body_displaced_last_tick())
	_moves_total += int(_native_world.get_moves_last_tick())
	_record_native_feedback()
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
		"rapier_probe_deferred": _rapier_probe.is_empty(),
		"rapier_reason": str(_rapier_probe.get("reason", "not probed")),
		"rapier_probe": _rapier_probe.duplicate(true),
		"cpp_exception_probe": _cpp_exception_probe,
		"native_tick": _native_tick(), "rapier_steps": _rapier_steps(),
		"native_attempted_tick": int(_native_world.get_attempted_tick_index()) if _native_world != null else 0,
		"native_revision": int(_native_world.get_revision()) if _native_world != null else 0,
		"bridge_active": _bridge_active(),
		"owned_physics_space_active": PhysicsServer2D.space_is_active(_body_root.get_world_2d().space) if is_instance_valid(_body_root) else false,
		"pending_colliders": _rapier_bridge.pending_hard_surface_chunks() if _bridge_active() else 0,
		"contacts_total": _contacts_total, "displaced_total": _displaced_total,
		"moves_total": _moves_total,
		"moves_last_tick": int(_native_world.get_moves_last_tick()) if _native_world != null else 0,
		"workers": int(_native_world.get_worker_threads()) if _native_world != null else 0,
		"initial_material_sha256": _initial_material_sha256,
		"initial_body_states": _initial_body_states.duplicate(true),
		"body_states": _read_body_states(), "body_sizes": _body_size_values(),
		"body_ids": _object_registry.ids(), "object_definitions": get_object_definitions(),
		"logical_objects": Registry.logical_graph(get_object_definitions()),
		"object_revision": _object_revision, "object_schema_version": Registry.SCHEMA_VERSION,
		"slot_mapping": _rapier_bridge.slot_mapping() if _rapier_bridge != null else {"epoch": 0, "project_ids": [], "slots": 0, "sample_serial": 0},
		"object_feedback": _object_feedback.duplicate(true), "body_body_pairs": _body_body_pairs.keys(),
		"initial_definition_id": str(_definition.get("id", "")),
		"initial_definition_revision": int(_definition.get("revision", 0)),
		"world_size": [1024, 1024], "initial_view": [480, 270],
		"simulation_interest": _interest_values(), "fixed_delta": FIXED_DELTA,
	}
	if include_material_identity:
		result["current_material_sha256"] = material_identity()
	return result


func get_object_definitions() -> Array:
	return _object_registry.definitions()


func apply_object_graph(candidate: Array, expected_revision: int = -1,
		expected_tick: int = -1, explicit_fields: Dictionary = {}) -> Dictionary:
	# All validation and allocation precede world mutation. This is called only
	# at the session's serialized command boundary, never from a body callback.
	if not _ready or _fault or _object_mutating:
		return {"ok": false, "error": "host_not_editable", "partial": false}
	if (expected_revision >= 0 and expected_revision != _object_revision) \
			or (expected_tick >= 0 and expected_tick != _native_tick()):
		return {"ok": false, "error": "stale_object_revision_or_tick", "partial": false}
	var validation: Dictionary = Registry.validate_graph(candidate)
	if not validation.ok:
		return {"ok": false, "error": validation.error, "partial": false}
	var desired: Array = validation.definitions
	var before: Array = get_object_definitions()
	var desired_ids: Dictionary = {}
	for row: Dictionary in desired:
		desired_ids[row.id] = row
		var previous: Dictionary = _object_registry.definition(row.id)
		if not previous.is_empty() and previous.creation_order != row.creation_order:
			return {"ok": false, "error": "immutable_object_creation_order", "partial": false}
	for id: Variant in explicit_fields:
		if not id is String or not explicit_fields[id] is Array \
				or _object_registry.slot_for_id(id) == 0 or not desired_ids.has(id):
			return {"ok": false, "error": "invalid_explicit_object_fields", "partial": false}
		for field: Variant in explicit_fields[id]:
			if not field is String or field not in Registry.FIELDS \
					or field in ["id", "creation_order", "schema_version", "shape"]:
				return {"ok": false, "error": "invalid_explicit_object_fields", "partial": false}
	var old_states: Array = _read_body_states()
	var physical_change: bool = before.size() != desired.size()
	for index: int in range(before.size()):
		var id: String = before[index].id
		var requested: Array = explicit_fields.get(id, [])
		if not desired_ids.has(id):
			physical_change = true
			continue
		var row: Dictionary = desired_ids[id]
		physical_change = physical_change or not _same_physical_definition(before[index], row) \
			or _explicit_state_changed(row, old_states[index], requested)
	if desired == before and not physical_change:
		return {"ok": true, "error": "", "partial": false, "changed": false,
			"physical_changed": false, "revision": _object_revision}
	if not physical_change:
		# Names and passive-subject metadata belong to the logical document. They
		# must not retire pending physical feedback or change the sampling epoch.
		_object_registry.install(desired)
		_definition.bodies = get_object_definitions()
		_object_revision += 1
		return {"ok": true, "error": "", "partial": false, "changed": true,
			"physical_changed": false, "revision": _object_revision,
			"definitions": get_object_definitions()}
	if not desired.is_empty():
		_probe_rapier_if_needed()
		if not bool(_rapier_probe.get("ok", false)):
			return {"ok": false, "error": "rapier_unavailable", "partial": false}
	var old_by_id: Dictionary = {}
	for index: int in range(before.size()):
		old_by_id[before[index].id] = index
	var staged: Array[RigidBody2D] = []
	var next_bodies: Array[RigidBody2D] = []
	var next_sizes: PackedVector2Array = PackedVector2Array()
	var state_rows: Array = []
	for row: Dictionary in desired:
		var old_index: int = int(old_by_id.get(row.id, -1))
		var old: Dictionary = before[old_index] if old_index >= 0 else {}
		var prior_state: Array = old_states[old_index].duplicate() if old_index >= 0 else []
		var requested: Array = explicit_fields.get(row.id, [])
		var body: RigidBody2D
		if old_index >= 0 and _same_physical_definition(old, row) \
				and not _explicit_state_changed(row, prior_state, requested):
			body = _bodies[old_index]
		else:
			body = _make_body(row)
			if body == null:
				for allocated: RigidBody2D in staged:
					allocated.free()
				return {"ok": false, "error": "object_allocation_refused", "partial": false}
			staged.append(body)
			if old_index >= 0:
				if row.position != old.position or "position" in requested:
					prior_state[0] = row.position.x
					prior_state[1] = row.position.y
				if row.rotation != old.rotation or "rotation" in requested:
					prior_state[2] = row.rotation
				if row.linear_velocity != old.linear_velocity or "linear_velocity" in requested:
					prior_state[3] = row.linear_velocity.x
					prior_state[4] = row.linear_velocity.y
				if row.angular_velocity != old.angular_velocity or "angular_velocity" in requested:
					prior_state[5] = row.angular_velocity
				prior_state[6] = false
		next_bodies.append(body)
		next_sizes.append(row.size)
		state_rows.append(prior_state)
	_object_mutating = true
	# Two separate zero-step preparations retire both old observations and old
	# previous poses, so a reused slot cannot sweep from a deleted object's pose.
	_native_world.prepare_rigid_body_coupling(PackedFloat32Array(), false)
	for body: RigidBody2D in staged:
		_body_root.add_child(body)
	for index: int in range(next_bodies.size()):
		if next_bodies[index] in staged:
			_install_body_state(next_bodies[index], desired[index], state_rows[index])
	var retired: Array[RigidBody2D] = []
	for body: RigidBody2D in _bodies:
		if body not in next_bodies:
			body.freeze = true
			body.collision_layer = 0
			body.collision_mask = 0
			body.get_parent().remove_child(body)
			retired.append(body)
	_bodies = next_bodies
	_body_sizes = next_sizes
	_object_registry.install(desired)
	_definition.bodies = get_object_definitions()
	var bridge_error: Error = OK
	if _rapier_bridge == null and not _bodies.is_empty():
		_rapier_bridge = CyberRapierPhysicsBridge.new()
		bridge_error = _rapier_bridge.initialize(_body_root.get_world_2d().space, _bodies, _body_sizes, _object_registry.ids())
		_rapier_bridge.enable_diagnostics()
		_hard_surface_revision = -1
	elif _rapier_bridge != null:
		bridge_error = _rapier_bridge.rebind_bodies(_bodies, _body_sizes, _object_registry.ids())
	for body: RigidBody2D in retired:
		body.free()
	if bridge_error != OK or bool(_native_world.has_failed()):
		_object_mutating = false
		_enter_fault("Object graph partly installed: " + error_string(bridge_error))
		return {"ok": false, "error": _error, "partial": true}
	if _bridge_active():
		_rapier_bridge.refresh_all_states()
		for _pass: int in range(MAX_INITIAL_TERRAIN_PASSES):
			_sync_terrain()
			if _fault or _rapier_bridge.pending_hard_surface_chunks() == 0:
				break
		if _fault or _rapier_bridge.pending_hard_surface_chunks() != 0:
			_object_mutating = false
			_enter_fault("Object graph changed but terrain readiness failed")
			return {"ok": false, "error": _error, "partial": true}
		_native_world.prepare_rigid_body_coupling(_rapier_bridge.pack_body_states(), false)
	if bool(_native_world.has_failed()):
		_object_mutating = false
		_enter_fault("Object graph changed but native occupancy publication failed")
		return {"ok": false, "error": _error, "partial": true}
	# Remove retired identity diagnostics; surviving cumulative observations keep
	# their stable keys even when their transient sampling slots change.
	for id: String in _object_feedback.keys():
		if _object_registry.slot_for_id(id) == 0:
			_object_feedback.erase(id)
	for pair: String in _body_body_pairs.keys():
		var ids: PackedStringArray = pair.split(":")
		if _object_registry.slot_for_id(ids[0]) == 0 or _object_registry.slot_for_id(ids[1]) == 0:
			_body_body_pairs.erase(pair)
	_object_revision += 1
	_object_mutating = false
	return {"ok": true, "error": "", "partial": false, "changed": true,
		"physical_changed": true, "revision": _object_revision, "definitions": get_object_definitions()}


func object_occupancy_at(cell: Vector2i) -> String:
	if _native_world == null or cell.x < 0 or cell.y < 0 or cell.x >= 1024 or cell.y >= 1024:
		return ""
	return _object_registry.id_for_slot(int(_native_world.rigid_body_id_at(cell.x, cell.y)))


func material_identity() -> String:
	if _native_world == null or _demo_bridge == null or _native_world.has_failed():
		return ""
	var capture: Dictionary = capture_cells()
	var payload: PackedByteArray = capture.get("cells", PackedByteArray())
	if payload.is_empty():
		return ""
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(payload)
	return hashing.finish().hex_encode()


func capture_cells() -> Dictionary:
	if _edit_bridge == null or _native_world == null:
		return {"ok": false, "error": "native_editor_unavailable"}
	return _edit_bridge.capture_cells(_native_world)


func material_catalogue() -> Array:
	var bridge: Variant = ClassDB.instantiate(&"SandfallEditBridge")
	return bridge.catalogue() if bridge != null else []


func plan_editor_patch(cells: PackedByteArray, indices: PackedInt32Array, desired: PackedByteArray) -> Dictionary:
	return _edit_bridge.plan_patch(cells, indices, desired)


func apply_editor_patch(patch: Dictionary, expected_revision: int, expected_tick: int) -> Dictionary:
	if not _ready or _fault:
		return {"ok": false, "error": "host_not_editable", "partial": false}
	var receipt: Dictionary = _edit_bridge.apply_patch(_native_world, patch.indices, patch.before,
		patch.after, expected_revision, expected_tick)
	if bool(receipt.get("partial", false)):
		_enter_fault("Partial edit failure: " + str(receipt.error))
	elif bool(receipt.ok) and _bridge_active():
		# No body may step against known-stale edited terrain. A failed collider
		# publication is a Fault, not a claimed atomic cross-backend rollback.
		for _pass: int in range(MAX_INITIAL_TERRAIN_PASSES):
			_sync_terrain()
			if _fault or _rapier_bridge.pending_hard_surface_chunks() == 0:
				break
		if _fault or _rapier_bridge.pending_hard_surface_chunks() != 0:
			_enter_fault("Edited terrain readiness refused")
			return {"ok": false, "error": _error, "partial": true}
	return receipt


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
		if not row is Array or row.size() != 7 or not row[6] is bool:
			return {"ok": false, "error": "Malformed internal body snapshot"}
		for component: int in range(6):
			if not (row[component] is int or row[component] is float) or not is_finite(float(row[component])):
				return {"ok": false, "error": "Nonfinite internal body snapshot"}
	var installed: Dictionary = configure(restored_definition)
	if not bool(installed.ready):
		return {"ok": false, "error": str(installed.error)}
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
	# The native candidate installs these restored masks without waking saved
	# activity/deadline state. Ordinary live mask publication keeps its wakes.
	var restored_bodies: PackedFloat32Array = _rapier_bridge.pack_body_states() if _bridge_active() else PackedFloat32Array()
	if not _demo_bridge.import_physical_state(_native_world, snapshot.native_payload, restored_bodies):
		_enter_fault("Physical state restore refused after body reconstruction: " + str(_demo_bridge.get_last_error()))
		return {"ok": false, "error": _error, "partial": true}
	if _bridge_active():
		_hard_surface_revision = -1
		for _pass: int in range(MAX_INITIAL_TERRAIN_PASSES):
			_sync_terrain()
			if _fault:
				return {"ok": false, "error": _error, "partial": true}
			if _rapier_bridge.pending_hard_surface_chunks() == 0:
				break
		if _rapier_bridge.pending_hard_surface_chunks() != 0:
			_enter_fault("Restored terrain collider readiness did not complete")
			return {"ok": false, "error": _error, "partial": true}
	return {"ok": true, "state": state()}


func shutdown() -> void:
	_ready = false
	# Remove the old graph before shutdown reactivates the shared physics space.
	for body: RigidBody2D in _bodies:
		if is_instance_valid(body):
			body.freeze = true
			body.collision_layer = 0
			body.collision_mask = 0
			body.get_parent().remove_child(body)
	if _rapier_bridge != null:
		_rapier_bridge.shutdown()
		_rapier_bridge = null
	for body: RigidBody2D in _bodies:
		if is_instance_valid(body):
			body.free()
	_bodies.clear()
	_body_sizes = PackedVector2Array()
	_native_world = null
	_edit_bridge = null
	_demo_bridge = null
	_hard_surface_revision = -1
	_initial_material_sha256 = ""
	_initial_body_states.clear()
	if is_instance_valid(_physics_viewport):
		_physics_viewport.free()
	_physics_viewport = null
	_body_root = null


func _exit_tree() -> void:
	shutdown()


func _create_bodies() -> bool:
	for initial: Dictionary in _definition.bodies:
		var body: RigidBody2D = _make_body(initial)
		if body == null:
			return false
		_body_root.add_child(body)
		_bodies.append(body)
		_body_sizes.append(initial.size)
	return true


func _make_body(initial: Dictionary) -> RigidBody2D:
	var body: RigidBody2D = RigidBody2D.new()
	body.name = "SandfallBody_" + str(initial.id)
	body.set_meta("sandfall_object_id", str(initial.id))
	body.freeze = true
	body.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	body.position = initial.position
	body.rotation = float(initial.rotation)
	body.mass = float(initial.mass)
	body.gravity_scale = float(initial.gravity_scale)
	# Authored damping is the total coefficient, not an addition to hidden
	# project defaults. Zero must mean no damping for a free inertial subject.
	body.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	body.linear_damp = float(initial.linear_damp)
	body.angular_damp = float(initial.angular_damp)
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	body.contact_monitor = true
	body.max_contacts_reported = Registry.MAX_OBJECTS * 4
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = float(initial.friction)
	material.bounce = float(initial.restitution)
	material.rough = true
	material.absorbent = true
	body.physics_material_override = material
	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = initial.size
	collider.shape = shape
	body.add_child(collider)
	if not body.get_rid().is_valid() or not shape.get_rid().is_valid():
		body.free()
		return null
	return body


func _install_body_state(body: RigidBody2D, initial: Dictionary, retained: Array) -> void:
	body.freeze = bool(initial.fixed) or bool(initial.frozen)
	var position: Vector2 = initial.position if retained.is_empty() else Vector2(retained[0], retained[1])
	var rotation: float = float(initial.rotation) if retained.is_empty() else float(retained[2])
	var velocity: Vector2 = initial.linear_velocity if retained.is_empty() else Vector2(retained[3], retained[4])
	var angular_velocity: float = float(initial.angular_velocity) if retained.is_empty() else float(retained[5])
	var sleeping: bool = false if retained.is_empty() else bool(retained[6])
	var rid: RID = body.get_rid()
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(rotation, position))
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, velocity)
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, angular_velocity)
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING, sleeping)


func _same_physical_definition(a: Dictionary, b: Dictionary) -> bool:
	for field: String in Registry.FIELDS:
		if field not in ["id", "creation_order", "schema_version", "name", "passive_subject"] and a[field] != b[field]:
			return false
	return true


func _explicit_state_changed(row: Dictionary, current: Array, requested: Array) -> bool:
	return ("position" in requested and Vector2(current[0], current[1]) != row.position) \
		or ("rotation" in requested and not is_equal_approx(float(current[2]), float(row.rotation))) \
		or ("linear_velocity" in requested and Vector2(current[3], current[4]) != row.linear_velocity) \
		or ("angular_velocity" in requested and not is_equal_approx(float(current[5]), float(row.angular_velocity)))


func _feedback_row(id: String) -> Dictionary:
	if not _object_feedback.has(id):
		_object_feedback[id] = {"samples": 0, "contacts": 0, "displaced": 0, "applications": 0,
			"accepted_impulse_x": 0.0, "accepted_impulse_y": 0.0}
	return _object_feedback[id]


func _record_native_feedback() -> void:
	if not _bridge_active():
		return
	var results: PackedFloat32Array = _native_world.rigid_body_results()
	for index: int in range(CyberRigidBodyCoupling.result_body_count(results)):
		var offset: int = index * CyberRigidBodyCoupling.RESULT_STRIDE
		var id: String = _object_registry.id_for_slot(roundi(results[offset + CyberRigidBodyCoupling.RESULT_BODY_ID]))
		if id.is_empty():
			continue
		var row: Dictionary = _feedback_row(id)
		row.samples += 1
		row.contacts += roundi(results[offset + CyberRigidBodyCoupling.RESULT_CONTACT_COUNT])
		row.displaced += roundi(results[offset + CyberRigidBodyCoupling.RESULT_DISPLACED_COUNT])


func _record_applied_feedback() -> void:
	var applications: PackedFloat64Array = _rapier_bridge.diagnostic_applications
	for index: int in range(_bodies.size()):
		if applications.size() < (index + 1) * 6:
			break
		var x: float = applications[index * 6 + 1]
		var y: float = applications[index * 6 + 2]
		var row: Dictionary = _feedback_row(_object_registry.id_for_slot(index + 1))
		row.accepted_impulse_x += x
		row.accepted_impulse_y += y
		if x != 0.0 or y != 0.0:
			row.applications += 1


func _record_body_contacts() -> void:
	for body: RigidBody2D in _bodies:
		for other: Node in body.get_colliding_bodies():
			if not is_instance_valid(other) or not other.has_meta("sandfall_object_id"):
				continue
			var a: String = str(body.get_meta("sandfall_object_id"))
			var b: String = str(other.get_meta("sandfall_object_id"))
			var pair: String = a + ":" + b if a < b else b + ":" + a
			_body_body_pairs[pair] = true


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
	return _rapier_bridge != null and _rapier_bridge.is_initialized() and not _bodies.is_empty()


func _probe_rapier_if_needed() -> void:
	# The capability probe performs a real isolated Rapier step. A zero-body
	# project must never invoke it merely to construct or tick native material.
	if _rapier_probe.is_empty():
		_rapier_probe = CyberWebCapabilities.rapier_probe()
		print("SANDFALL_RAPIER_PROBE ", JSON.stringify(_rapier_probe))


func _native_tick() -> int:
	return int(_native_world.get_tick_index()) if _native_world != null else 0


func _rapier_steps() -> int:
	return _rapier_bridge.manual_step_count() if _rapier_bridge != null and _rapier_bridge.is_initialized() else 0


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
	if definition.has("initial_cells"):
		if not definition.initial_cells is PackedByteArray:
			return "Initial authored cells are malformed"
		var editor: Variant = ClassDB.instantiate(&"SandfallEditBridge")
		if editor == null or not bool(editor.validate_cells(definition.initial_cells).ok):
			return "Initial authored cell tuples are invalid"
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
	var objects: Dictionary = Registry.validate_graph(definition.bodies)
	if not objects.ok:
		return str(objects.error)
	return ""
