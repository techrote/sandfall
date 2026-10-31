extends SceneTree

const Host = preload("res://scripts/sandfall/simulation_host.gd")
const Session = preload("res://scripts/sandfall/session_controller.gd")
const Codec = preload("res://scripts/sandfall/archive_codec.gd")
const Registry = preload("res://scripts/sandfall/rapier_object_registry.gd")
const Definitions = preload("res://scripts/sandfall/scene_definitions.gd")

class FailedCandidate extends Host:
	func _sync_terrain() -> void:
		_enter_fault("labelled candidate-only collider readiness failure")

class FailedBodyCandidate extends Host:
	var allocation_log: Dictionary = {}
	func _make_body(initial: Dictionary) -> RigidBody2D:
		allocation_log.attempts += 1
		if allocation_log.attempts == 3:
			return null
		var body: RigidBody2D = super._make_body(initial)
		if body != null:
			var collider: CollisionShape2D = body.get_child(0)
			allocation_log.body_ids.append(body.get_instance_id())
			allocation_log.collider_ids.append(collider.get_instance_id())
			allocation_log.shape_refs.append(weakref(collider.shape))
			allocation_log.valid_rids = allocation_log.valid_rids and body.get_rid().is_valid() and collider.shape.get_rid().is_valid()
		return body

class ImportHost extends Host:
	var fail_candidate: bool = false
	var fail_body_candidate: bool = false
	var allocation_log: Dictionary = {}
	func _new_staging_host() -> SandfallSimulationHost:
		if fail_body_candidate:
			allocation_log = {"attempts": 0, "body_ids": [], "collider_ids": [], "shape_refs": [], "valid_rids": true}
			var candidate: FailedBodyCandidate = FailedBodyCandidate.new()
			candidate.allocation_log = allocation_log
			return candidate
		return FailedCandidate.new() if fail_candidate else Host.new()

var _checks: int = 0
var _failures: Array[String] = []
var _receipts: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	await _capacity_roundtrips()
	await _adoption_preserves_backend_state()
	await _atomic_candidate_failures()
	await _partial_body_candidate_failure()
	await _frozen_save_and_evidence()
	print("SANDFALL_PROJECTS_TEST ", JSON.stringify({"ok": _failures.is_empty(), "checks": _checks,
		"failures": _failures, "receipts": _receipts,
		"scope": "fresh-native isolated World/Rapier project installation, initial-state ZIP and bounded run evidence"}))
	quit(0 if _failures.is_empty() else 1)


func _capacity_roundtrips() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "sandbox")
	var base: Dictionary = session.authored_project()
	var matrix: Array = []
	for count: int in [0, 1, 3, 8, 16]:
		var definition: Dictionary = base.duplicate(true)
		definition.bodies = []
		for index: int in count:
			var body: Dictionary = Registry.make_box("archive-%02d" % index, index + 1,
				Vector2(100 + (index % 4) * 70, 40 + (index / 4) * 35), Vector2(19, 17))
			body.mass = 0.4 + float(index) / 10.0
			body.friction = 0.31
			body.restitution = 0.22
			body.linear_velocity = Vector2(2.5, -1.25)
			body.angular_velocity = 0.2
			body.name = "Archive body %d" % index
			definition.bodies.append(body)
		var encoded: Dictionary = Codec.encode_definition(definition)
		_check(encoded.ok, "Encode %d bodies: %s" % [count, encoded.get("error", "")])
		if not encoded.ok: continue
		var decoded: Dictionary = Codec.decode_bytes(encoded.bytes)
		_check(decoded.ok, "Decode %d bodies" % count)
		if not decoded.ok: continue
		var previous_generation: int = session.state().generation
		var installed: Dictionary = session.import_project(decoded.definition, previous_generation, session.state().input_epoch)
		_check(installed.ok, "Install %d bodies: %s" % [count, installed.get("error", "")])
		var state: Dictionary = session.state()
		_check(state.mode == "edit" and state.paused and state.tick == 0 and state.rapier_steps == 0
			and state.generation == previous_generation + 1, "Import startup policy or generation incorrect")
		_check(session.authored_project().initial_cells == definition.initial_cells
			and session.object_definitions() == definition.bodies, "Initial cells or object parameters changed in ZIP reconstruction")
		_check(state.document.undo_depth == 0 and state.document.redo_depth == 0, "Import restored transient Edit history")
		_check(host._bodies.size() == count and host._body_root.get_world_2d().space != root.world_2d.space,
			"Project bodies do not own an isolated physics space")
		_check(not host.state().owned_physics_space_active, "Project physics space is automatically active, including empty scene")
		var container_id: int = host._adopted_container.get_instance_id()
		_check(host.get_child_count() == 1 and host._adopted_container.get_parent() == host
			and host._physics_viewport.get_parent() == host._adopted_container
			and host._adopted_container.get_child_count() == 1,
			"Imported graph does not have exactly one bounded inert ownership container")
		_check(host.state().body_states == host.state().initial_body_states,
			"Imported actual backend initial velocities/poses differ from the staged initial graph")
		for index: int in count:
			var pose: Array = host.state().body_states[index]
			_check(Vector2(pose[3], pose[4]) == definition.bodies[index].linear_velocity
				and is_equal_approx(float(pose[5]), float(definition.bodies[index].angular_velocity)),
				"Portable initial velocity was only preserved in logical metadata")
		var ids: Dictionary = {}
		for body: RigidBody2D in host._bodies:
			_check(not ids.has(body.get_rid()), "Repeated RID in imported graph")
			ids[body.get_rid()] = true
		var imported_identity: Dictionary = session.project_identity()
		_check(imported_identity.ok and imported_identity.logical_sha256 == encoded.logical_sha256,
			"Portable logical identity changed after installation")
		_command(session, "run")
		for _tick: int in 30:
			_check(session.advance(), "Imported Run failed a native tick")
		_check(session.state().tick == 30 and session.state().rapier_steps == (30 if count > 0 else 0),
			"Imported solver step counts incorrect")
		_command(session, "reset_edit")
		_check(session.state().tick == 0 and session.state().rapier_steps == 0
			and session.object_definitions() == definition.bodies and session.authored_project().initial_cells == definition.initial_cells,
			"Imported project reset does not reconstruct exact authored values")
		_check(not is_instance_id_valid(container_id) and host.get_child_count() == 1,
			"Reset leaked an adopted container or nested a new physical graph")
		matrix.append({"bodies": count, "logical_sha256": encoded.logical_sha256, "bytes": encoded.bytes.size(),
			"native_ticks": 30, "rapier_steps": 30 if count > 0 else 0, "reset_exact": true})
	_receipts.matrix = matrix
	host.free()
	await process_frame


func _adoption_preserves_backend_state() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "sandbox")
	var definition: Dictionary = session.authored_project()
	definition.bodies = []
	for index: int in 3:
		var body: Dictionary = Registry.make_box("adoption-%d" % index, index + 1,
			Vector2(120 + index * 130, 80), Vector2(18, 23))
		body.rotation = 0.35
		body.mass = 2.75
		body.friction = 0.47
		body.restitution = 0.62
		body.gravity_scale = 0.0
		body.linear_damp = 0.0
		body.angular_damp = 0.0
		body.linear_velocity = Vector2(12, -7) if index == 0 else Vector2.ZERO
		body.angular_velocity = 1.5 if index == 0 else 0.0
		body.fixed = index == 1
		body.frozen = index == 2
		definition.bodies.append(body)
	var staged: Dictionary = host.stage_project(definition)
	_check(staged.ok, "Nonzero-velocity candidate did not stage")
	if not staged.ok:
		host.free()
		return
	var before_states: Array = staged.candidate.state().body_states.duplicate(true)
	var before_properties: Array = _backend_properties(staged.candidate)
	var before_samples: Dictionary = _coupling_cache(staged.candidate)
	var adopted: Dictionary = host.commit_staged_project(staged.candidate)
	_check(adopted.ok and host.state().native_tick == 0 and host.state().rapier_steps == 0,
		"Adoption failed or secretly advanced physics")
	_check(host._adopted_container == staged.candidate and host._physics_viewport.get_parent() == staged.candidate,
		"Adoption reparented the live physical subtree")
	_check(host.state().body_states == before_states and host.state().initial_body_states == before_states,
		"Viewport tree re-entry overwrote actual initial velocities or transforms")
	var adoption_properties_unchanged: bool = _backend_properties(host) == before_properties
	_check(adoption_properties_unchanged,
		"Viewport adoption changed raw backend properties, shape/RID ownership or manual space")
	_check(_coupling_cache(host) == before_samples,
		"Adoption changed the initial bounded sampling state or slot mapping")
	await process_frame
	_check(host.state().body_states == before_states and not host.state().owned_physics_space_active,
		"Scene-tree frame or automatic space stepping changed the imported tick-zero graph")
	var tick: Dictionary = host.tick_once()
	var advanced: Array = host.state().body_states
	_check(tick.advanced and host.state().native_tick == 1 and host.state().rapier_steps == 1,
		"Imported velocity test did not perform exactly one coupled step")
	_check(absf(float(advanced[0][0]) - (float(before_states[0][0]) + 12.0 / 60.0)) < 0.002
		and absf(float(advanced[0][1]) - (float(before_states[0][1]) - 7.0 / 60.0)) < 0.002
		and absf(float(advanced[0][2]) - (float(before_states[0][2]) + 1.5 / 60.0)) < 0.0001,
		"Actual first-step translation/rotation did not use imported initial velocities")
	_check(Vector2(advanced[0][3], advanced[0][4]) == Vector2(12, -7)
		and is_equal_approx(float(advanced[0][5]), 1.5), "Undamped imported velocities were lost after the first step")
	_check(advanced[1] == before_states[1] and advanced[2] == before_states[2],
		"Fixed/frozen imported bodies moved on the first step")
	_receipts.adoption = {"before": before_states, "after_first_tick": advanced,
		"adoption_properties_unchanged": adoption_properties_unchanged,
		"first_step_backend_properties": _backend_properties(host),
		"initial_sampling_unchanged": true, "zero_tick_frame_unchanged": true,
		"raw_backend_properties": before_properties}
	for iteration: int in 3:
		var previous_container: int = host._adopted_container.get_instance_id()
		var replacement: Dictionary = host.stage_project(definition)
		_check(replacement.ok and host.commit_staged_project(replacement.candidate).ok,
			"Repeated nonzero-velocity adoption failed")
		_check(not is_instance_id_valid(previous_container) and host.get_child_count() == 1
			and host._adopted_container.get_parent() == host and host._adopted_container.get_child_count() == 1,
			"Repeated adoption retained an old container or grew its ownership depth")
		_check(host.state().body_states == before_states,
			"Repeated adoption changed actual authored initial velocities or transforms")
	definition["project"] = Codec.project_defaults(definition.bodies)
	definition.project.startup = "run_autoplay"
	var encoded: Dictionary = Codec.encode_definition(definition)
	var decoded: Dictionary = Codec.decode_bytes(encoded.bytes)
	_check(encoded.ok and decoded.ok, "Autoplay initial-velocity project failed ordinary ZIP roundtrip")
	var imported: Dictionary = session.import_project(decoded.definition, session.state().generation, session.state().input_epoch)
	_check(imported.ok and session.state().mode == "run" and not session.state().paused
		and session.state().tick == 0 and session.state().rapier_steps == 0
		and session.state().document.locked and host.state().body_states == before_states,
		"Autoplay archive did not install exact nonzero initial state with Run history locked at zero")
	_check(session.advance() and session.state().tick == 1 and session.state().rapier_steps == 1
		and session.state().history_retired and host.state().body_states == advanced,
		"Autoplay archive did not use the same initial velocities on its first coupled step")
	host.free()
	await process_frame


func _backend_properties(host: Variant) -> Array:
	var rows: Array = []
	for body: RigidBody2D in host._bodies:
		var rid: RID = body.get_rid()
		var parameters: Array = []
		for parameter: int in range(PhysicsServer2D.BODY_PARAM_MAX):
			var value: Variant = PhysicsServer2D.body_get_param(rid, parameter)
			parameters.append([value.x, value.y] if value is Vector2 else value)
		rows.append({"rid": str(rid.get_id()), "shape": str(PhysicsServer2D.body_get_shape(rid, 0).get_id()),
			"space": str(PhysicsServer2D.body_get_space(rid).get_id()),
			"mode": PhysicsServer2D.body_get_mode(rid), "parameters": parameters,
			"ccd": PhysicsServer2D.body_get_continuous_collision_detection_mode(rid),
			"layers": body.collision_layer, "mask": body.collision_mask, "freeze": body.freeze})
	return rows


func _coupling_cache(host: Variant) -> Dictionary:
	var bridge: Variant = host._rapier_bridge
	# Observe without consuming a new sample serial; pack_body_states advances
	# that bounded serial by design and is not a read-only diagnostic API.
	return {"transforms": bridge._transforms.duplicate(),
		"linear_velocities": bridge._linear_velocities.duplicate(),
		"angular_velocities": bridge._angular_velocities.duplicate(),
		"sleeping": bridge._sleeping.duplicate(), "slots": bridge.slot_mapping()}


func _atomic_candidate_failures() -> void:
	var host: Variant = ImportHost.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "gallery")
	for _tick: int in 7: _check(session.advance(), "Old active scene failed advance")
	_command(session, "toggle_pause")
	var initial: Dictionary = session.authored_project()
	initial["project"] = Codec.project_defaults(initial.bodies)
	var before: Dictionary = _snapshot(session, host)
	var stale: Dictionary = session.import_project(initial, session.state().generation - 1, session.state().input_epoch)
	_check(not stale.ok and _snapshot(session, host) == before, "Stale import replaced current session")
	var invalid: Dictionary = initial.duplicate(true)
	invalid.bodies[0].mass = NAN
	_check(not session.import_project(invalid, session.state().generation, session.state().input_epoch).ok
		and _snapshot(session, host) == before, "Nonfinite import replaced current session")
	invalid = initial.duplicate(true)
	invalid.bodies = []
	for index: int in 17:
		invalid.bodies.append(Registry.make_box("overflow-%d" % index, index + 1, Vector2(20 + index * 25, 40)))
	_check(not session.import_project(invalid, session.state().generation, session.state().input_epoch).ok
		and _snapshot(session, host) == before, "Body17 import replaced current session")
	host.fail_candidate = true
	for _attempt: int in 3:
		var refused: Dictionary = session.import_project(initial, session.state().generation, session.state().input_epoch)
		_check(not refused.ok and not refused.partial and str(refused.error).contains("candidate_readiness"),
			"Candidate readiness failure did not refuse before commit")
		_check(_snapshot(session, host) == before and host.get_child_count() == 1,
			"Failed candidate changed active physical state or leaked a viewport")
	host.fail_candidate = false
	var staged: Dictionary = host.stage_project(initial)
	_check(staged.ok and _snapshot(session, host) == before, "Staging disturbed the previous World")
	if staged.ok:
		_check(staged.candidate._body_root.get_world_2d().space != host._body_root.get_world_2d().space,
			"Staged candidate shares active physics space")
		staged.candidate.free()
	_check(_snapshot(session, host) == before, "Discarding preview disturbed active physics")
	_command(session, "step")
	_check(session.advance() and session.state().tick == 8 and session.state().rapier_steps == 8,
		"Old coupled scene stopped functioning after rejected imports")
	_receipts.atomic_refusals = {"stale_generation": true, "nonfinite_mass": true, "body17": true,
		"readiness_failures": 3, "discarded_isolated_candidate": true, "old_scene_continues": true}
	host.free()
	await process_frame


func _partial_body_candidate_failure() -> void:
	var host: Variant = ImportHost.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "gallery")
	for _tick: int in 7: _check(session.advance(), "Allocation-failure fixture did not evolve")
	_command(session, "toggle_pause")
	var definition: Dictionary = session.authored_project()
	var before: Dictionary = _snapshot(session, host)
	host.fail_body_candidate = true
	for _attempt: int in 3:
		var refused: Dictionary = session.import_project(definition, session.state().generation, session.state().input_epoch)
		var log: Dictionary = host.allocation_log
		_check(log.attempts == 3 and log.body_ids.size() == 2 and log.valid_rids,
			"Labelled candidate failure did not follow two real body/RID allocations")
		_check(not refused.ok and not refused.partial and str(refused.error).contains("candidate_readiness"),
			"Partial candidate construction was not refused before active-owner commit")
		_check(_snapshot(session, host) == before and host.get_child_count() == 1,
			"Failed partial candidate changed active RIDs, native state, document, generation or epoch")
		for id: int in log.body_ids + log.collider_ids:
			_check(not is_instance_id_valid(id), "Failed candidate retained a body or collider node")
		for shape: WeakRef in log.shape_refs:
			_check(shape.get_ref() == null, "Failed candidate retained an allocated collider shape")
	host.fail_body_candidate = false
	_command(session, "step")
	_check(session.advance() and session.state().tick == 8 and session.state().rapier_steps == 8,
		"Old native/Rapier scene failed after rejected partial body construction")
	_receipts.partial_body_allocation = {"attempts": 3, "allocated_per_candidate": 2,
		"active_rids_and_native_unchanged": true, "candidate_nodes_and_shapes_retired": true,
		"old_scene_continues": true}
	host.free()
	await process_frame


func _frozen_save_and_evidence() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "gallery", "fluid_messenger")
	var initial: Dictionary = session.authored_project()
	var frozen: Dictionary = Codec.encode_definition(initial)
	_check(frozen.ok, "Gallery authored initial scene cannot be exported")
	for _tick: int in 150: _check(session.advance(), "Golden candidate failed native/Rapier tick")
	var evidence: Dictionary = session.run_evidence()
	_check(evidence.project.identity_valid and evidence.project.initial_cells_sha256 == Codec.sha256(initial.initial_cells),
		"Evidence initial identity is not frozen material data")
	_check(evidence.session.pristine and evidence.session.tick == 150 and evidence.session.rapier_steps == 150
		and evidence.actor_control_trace.locomotion_commands == 0 and evidence.actor_control_trace.action_commands == 0,
		"Pristine run evidence or absent actor trace is incorrect")
	_check(evidence.physical.contacts > 0, "Fluid Messenger did not record actual native/Rapier contact")
	var saved: Dictionary = Codec.encode_definition(session.authored_project())
	_check(saved.ok and saved.logical_sha256 == frozen.logical_sha256,
		"Save during evolved Run captured live state rather than frozen authored values")
	var parsed: Variant = JSON.parse_string(JSON.stringify(evidence))
	_check(parsed is Dictionary and parsed.type == "sandfall-run-evidence" and not parsed.qualification.cross_platform_bitwise_replay,
		"Run evidence is not a distinct JSON artifact or overclaims replay")
	var presentation: Dictionary = session.presentation()
	presentation.style.theme = "contrast"
	_check(session.enqueue_presentation(presentation, session.state().document.revision,
		session.state().generation, session.state().input_epoch), "Run view-only presentation was refused")
	session.process_commands()
	_check(session.state().pristine and Codec.encode_definition(session.authored_project()).logical_sha256 == frozen.logical_sha256,
		"Cosmetic Run presentation changed authored archive or marked Modified")
	_receipts.frozen_evidence = evidence
	host.free()
	await process_frame


func _snapshot(session: Variant, host: Variant) -> Dictionary:
	var physical: Dictionary = host.capture_physical_state()
	var rids: Array = []
	for body: RigidBody2D in host._bodies: rids.append(body.get_rid().get_id())
	return {"physical": physical, "rids": rids, "authored": session.authored_project(),
		"generation": session.state().generation, "epoch": session.state().input_epoch,
		"pristine": session.state().pristine, "mode": session.state().mode,
		"tick": session.state().tick, "rapier_steps": session.state().rapier_steps}


func _command(session: Variant, action: String, value: String = "") -> void:
	_check(session.enqueue(action, value), "Command refused: " + action)
	session.process_commands()


func _check(value: bool, message: String) -> void:
	_checks += 1
	if not value: _failures.append(message)
