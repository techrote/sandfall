extends SceneTree

# Real native/Rapier object lifecycle and capacity acceptance. Registry/schema
# negatives and injected stale-feedback tests are explicitly labelled; these
# do not replace the separate genuine-input compatibility browser workload.
const Host = preload("res://scripts/sandfall/simulation_host.gd")
const Registry = preload("res://scripts/sandfall/rapier_object_registry.gd")
const Definitions = preload("res://scripts/sandfall/scene_definitions.gd")
const MaterialTools = preload("res://scripts/sandfall/material_tools.gd")

class RefusingAllocationHost extends Host:
	var refuse_allocation: bool = false
	func _make_body(initial: Dictionary) -> RigidBody2D:
		return null if refuse_allocation else super._make_body(initial)

class RefusingTerrainHost extends Host:
	var refuse_terrain: bool = false
	func _sync_terrain() -> void:
		if refuse_terrain:
			_enter_fault("Injected collider readiness refusal after real object mutation")
		else:
			super._sync_terrain()

var _failures: Array[String] = []
var _checks: int = 0
var _receipts: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	_registry_negatives()
	if not CyberWebCapabilities.native_available() or not ClassDB.class_exists(&"SandfallEditBridge"):
		_check(false, "Fresh native extension unavailable; physics tests not executed")
		_finish()
		return
	for count: int in [0, 1, 3, 8, 16]:
		await _capacity_physics(count)
	await _live_graph_lifecycle()
	await _initial_properties_and_reconstruction()
	_legacy_native_restore_binding()
	await _metadata_feedback_boundary()
	await _restitution_rebound()
	await _graph_failure_boundaries()
	_finish()


func _registry_negatives() -> void:
	var row: Dictionary = Registry.make_box("model-box", 1, Vector2(100, 100))
	_check(Registry.validate_graph([row]).ok, "Canonical default box refused")
	_check(Registry.validate_graph([]).ok, "Zero object graph refused")
	var negatives: Array = [
		{"mass": 0.0}, {"mass": -1.0}, {"mass": 0.000001}, {"mass": 0.000999},
		{"mass": INF}, {"mass": NAN},
		{"size": Vector2.ZERO}, {"size": Vector2(-2, 10)}, {"size": Vector2(INF, 10)},
		{"size": Vector2(257, 10)}, {"position": Vector2(-1, 100)},
		{"position": Vector2(1024, 100)}, {"position": Vector2(NAN, 100)},
		{"rotation": INF}, {"rotation": TAU + 1.0}, {"shape": "circle"},
		{"friction": -0.1}, {"restitution": 1.1}, {"linear_damp": -1.0},
		{"angular_damp": INF}, {"linear_velocity": Vector2(4097, 0)},
		{"angular_velocity": 101.0}, {"gravity_scale": 5.0}, {"fixed": "true"},
		{"schema_version": 2}, {"id": ""}, {"id": "bad/id"},
		{"creation_order": 0}, {"unsupported_joint": true},
	]
	for change: Dictionary in negatives:
		var invalid: Dictionary = row.duplicate(true)
		invalid.merge(change, true)
		_check(not Registry.validate_graph([invalid]).ok, "Model negative admitted: " + str(change))
	var minimum_mass: Dictionary = row.duplicate(true)
	minimum_mass.mass = 0.001
	_check(Registry.validate_graph([minimum_mass]).ok, "Native-compatible minimum mass refused")
	_check(not Registry.validate_graph([row, row.duplicate(true)]).ok, "Duplicate ID admitted")
	var duplicate_order: Dictionary = row.duplicate(true)
	duplicate_order.id = "other-id"
	_check(not Registry.validate_graph([row, duplicate_order]).ok, "Duplicate creation order admitted")
	var earlier: Dictionary = Registry.make_box("earlier", 2, Vector2(200, 100))
	var later: Dictionary = Registry.make_box("later", 9, Vector2(300, 100))
	var ordered: Dictionary = Registry.validate_graph([later, earlier])
	_check(ordered.ok and ordered.definitions[0].id == "earlier" and ordered.definitions[1].id == "later",
		"Input array order replaced stable creation order")
	var registry: Variant = Registry.new()
	_check(registry.install([row]).ok, "Registry install failed")
	var copy: Array = registry.definitions()
	copy[0].mass = 99.0
	_check(registry.definition("model-box").mass == 1.0, "Registry leaked mutable definition ownership")
	var encoded: Dictionary = Registry.logical_representation(registry.definitions())
	var roundtrip: Dictionary = Registry.reconstruct_logical(JSON.parse_string(JSON.stringify(encoded)))
	_check(roundtrip.ok and roundtrip.definitions == registry.definitions(), "Versioned logical JSON-compatible reconstruction lost fields")
	_check(Registry.logical_payload_bytes(registry.definitions()) == JSON.stringify(encoded, "", true, true).to_utf8_buffer().size(), "Logical history payload accounting differs from exact encoding")
	_receipts["model_schema_negatives"] = {"cases": negatives.size() + 2, "logical_payload_bytes": Registry.logical_payload_bytes([row])}


func _fixture(count: int) -> Dictionary:
	var definition: Dictionary = Definitions.get_definition("blank")
	definition.id = "sf-m3-%d-objects" % count
	definition.rectangles = PackedInt32Array([
		0, 0, 1024, 1024, 0,
		10, 220, 460, 4, 1,
		10, 160, 4, 60, 1,
		466, 160, 4, 60, 1,
		14, 170, 452, 50, 3,
		30, 20, 12, 12, 2,
	])
	definition.bodies = []
	for index: int in range(count):
		definition.bodies.append(Registry.make_box("capacity-%02d" % (index + 1), index + 1,
			Vector2(70 + (index % 4) * 100, 50 + (index / 4) * 35), Vector2(12, 12)))
	return definition


func _capacity_physics(count: int) -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var definition: Dictionary = _fixture(count)
	var configured: Dictionary = host.configure(definition)
	_check(configured.ready, "Capacity %d failed configuration: %s" % [count, configured.error])
	if not configured.ready:
		host.free()
		return
	_check(configured.body_states.size() == count and configured.body_ids.size() == count, "Capacity graph count mismatch")
	_check(configured.native_tick == 0 and configured.rapier_steps == 0, "Construction advanced a solver")
	_check(configured.bridge_active == (count > 0), "Wrong zero-body activation state")
	for index: int in range(count):
		_check(host.object_occupancy_at(Vector2i(definition.bodies[index].position)) == definition.bodies[index].id,
			"Initial native occupancy did not map the stable object")
	var initial: Array = configured.body_states.duplicate(true)
	var desired_ticks: int = 400 if count == 16 else (240 if count > 0 else 30)
	var completed: int = 0
	var attempts: int = 0
	while completed < desired_ticks and attempts < desired_ticks * 20:
		attempts += 1
		var tick: Dictionary = host.tick_once()
		if tick.fault:
			_check(false, "Capacity run faulted: " + str(tick.error))
			break
		if tick.advanced:
			completed += 1
			_check(tick.native_delta == 1 and tick.rapier_delta == (1 if count > 0 else 0), "Wrong coupled step delta")
		if attempts % 20 == 0:
			await process_frame
	var final: Dictionary = host.state(true)
	_check(completed == desired_ticks, "Capacity workload did not finish requested actual ticks")
	_check(final.body_states.size() == count, "Body count changed during physics")
	if count == 0:
		_check(host._rapier_probe.is_empty() and not final.rapier_available,
			"Empty scene performed the hidden physical Rapier capability probe")
		var excessive: Array = _fixture(16).bodies
		excessive.append(Registry.make_box("empty-overflow", 17, Vector2(450, 70)))
		var refused: Dictionary = host.apply_object_graph(excessive, final.object_revision, final.native_tick)
		_check(not refused.ok and refused.error == "object_capacity_16" \
			and host._rapier_probe.is_empty() and host.state().rapier_steps == 0,
			"Refused nonempty graph physically probed Rapier from a zero-body scene")
		_check(final.rapier_steps == 0 and not final.bridge_active, "Empty graph stepped Rapier or retained phantom body")
		_check(final.moves_total > 0, "Native falling Sand did not evolve in zero-body scene")
	else:
		_check(final.contacts_total > 0 and final.displaced_total > 0, "No actual native-to-Rapier coupling at capacity")
		var applied: int = 0
		for index: int in range(count):
			var id: String = final.body_ids[index]
			_check(float(final.body_states[index][1]) > float(initial[index][1]) + 1.0, "Object did not fall under actual Rapier gravity")
			_check(float(final.body_states[index][1]) < 216.0, "Object fell through the hard native floor")
			var feedback: Dictionary = final.object_feedback.get(id, {})
			_check(int(feedback.get("samples", 0)) == completed, "Object missing from a native coupling sample: " + id)
			_check(int(feedback.get("contacts", 0)) > 0, "Object had no real native material contacts: " + id)
			applied += int(feedback.get("applications", 0))
		_check(applied > 0, "No real native impulse was accepted by Rapier")
		if count >= 8:
			_check(not final.body_body_pairs.is_empty(), "Multiple-body workload had no real body/body contact")
	if count == 16:
		var old_definitions: Array = host.get_object_definitions()
		var candidate: Array = old_definitions.duplicate(true)
		candidate.append(Registry.make_box("overflow", 17, Vector2(450, 70)))
		var before: Dictionary = host.capture_physical_state()
		var rids: Array = []
		for body: RigidBody2D in host._bodies:
			rids.append(body.get_rid())
		var refusal: Dictionary = host.apply_object_graph(candidate, final.object_revision, final.native_tick)
		var after: Dictionary = host.capture_physical_state()
		_check(not refusal.ok and not refusal.partial and refusal.error == "object_capacity_16", "Object 17 did not refuse atomically")
		_check(before.native_payload == after.native_payload and before.bodies == after.bodies \
			and old_definitions == host.get_object_definitions(), "Body17 refusal mutated native/body/logical state")
		for index: int in range(16):
			_check(host._bodies[index].get_rid() == rids[index], "Body17 refusal replaced a RID")
		_receipts["body17_refusal"] = refusal
	for repeat: int in range(3):
		var reset: Dictionary = host.configure(definition)
		_check(reset.ready and reset.native_tick == 0 and reset.rapier_steps == 0, "Reconstruction did not return to tick zero")
		_check(reset.body_states == initial and host.get_object_definitions() == definition.bodies, "Repeated reconstruction changed initial poses/properties/IDs")
	_receipts["capacity_%d" % count] = {"actual_ticks": completed, "final": final}
	print("SANDFALL_OBJECT_PROGRESS ", JSON.stringify({"bodies": count, "ticks": completed, "failures": _failures.size()}))
	host.free()
	await process_frame


func _live_graph_lifecycle() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var configured: Dictionary = host.configure(_fixture(0))
	_check(configured.ready, "Live graph setup failed")
	if not configured.ready:
		host.free()
		return
	var a: Dictionary = Registry.make_box("live-a", 1, Vector2(100, 100))
	var b: Dictionary = Registry.make_box("live-b", 2, Vector2(200, 100))
	b.linear_velocity = Vector2(20, 10)
	_check(host.apply_object_graph([a, b], 0, 0).ok, "Live spawn failed")
	_check(host.tick_once().advanced, "Live spawned graph would not step")
	var old: Dictionary = host.state()
	var invalid: Array = []
	for invalid_mass: float in [NAN, 0.000001, 0.000999]:
		invalid = host.get_object_definitions()
		invalid[1].mass = invalid_mass
		var before_invalid: Dictionary = host.capture_physical_state()
		var invalid_result: Dictionary = host.apply_object_graph(invalid, old.object_revision, old.native_tick)
		var after_invalid: Dictionary = host.capture_physical_state()
		_check(not invalid_result.ok and not invalid_result.partial and before_invalid.native_payload == after_invalid.native_payload \
			and before_invalid.bodies == after_invalid.bodies and before_invalid.definition == after_invalid.definition,
			"Malformed/tiny later mass partly mutated the live graph: " + str(invalid_mass))
	invalid = host.get_object_definitions()
	invalid[1].creation_order = 3
	_check(not host.apply_object_graph(invalid, old.object_revision, old.native_tick).ok,
		"Existing stable creation order was changed")
	var kept_rid: RID = host._bodies[1].get_rid()
	var retired_body: RigidBody2D = host._bodies[0]
	var old_results: PackedFloat32Array = host._native_world.rigid_body_results().duplicate()
	# Clearly labelled injection: an old copied native sample must not redirect
	# a synthetic impulse into live-b after it takes live-a's previous slot.
	if old_results.size() >= CyberRigidBodyCoupling.RESULT_STRIDE:
		old_results[CyberRigidBodyCoupling.RESULT_IMPULSE_X] = 5.0
	var deletion: Dictionary = host.apply_object_graph([b], old.object_revision, old.native_tick)
	_check(deletion.ok and not is_instance_valid(retired_body), "Deleted body node/RID owner was not retired")
	var after: Dictionary = host.state()
	_check(after.body_ids == PackedStringArray(["live-b"]) and host._bodies[0].get_rid() == kept_rid, "Stable identity or unaffected RID lost across slot change")
	_check(after.body_states[0] == old.body_states[1], "Deleting a neighbor reset evolved body state")
	_check(host.object_occupancy_at(Vector2i(100, 100)).is_empty(), "Deleted body left native ghost occupancy")
	var velocity: Vector2 = host._rapier_bridge.body_linear_velocity(0)
	var injected_applied: int = host._rapier_bridge.apply_cellular_results(123456, old_results)
	_check(injected_applied == 0 and host._rapier_bridge.body_linear_velocity(0) == velocity, "Retired sample applied an impulse to a new slot occupant")
	var resized: Dictionary = b.duplicate(true)
	resized.size = Vector2(32, 20)
	resized.mass = 2.5
	_check(host.apply_object_graph([resized], after.object_revision, after.native_tick).ok, "Live resize/mass change failed")
	var resized_state: Dictionary = host.state()
	_check(resized_state.body_states[0] == after.body_states[0], "Property/size edit reset an evolved pose or velocity")
	_check(host._bodies[0].get_rid() != kept_rid, "Resize did not replace the old collider owner")
	_check(host.object_occupancy_at(Vector2i(211, 100)) == "live-b", "Resized body did not refresh native occupancy")
	var reset_pose: Dictionary = host.apply_object_graph([resized], resized_state.object_revision,
		resized_state.native_tick, {"live-b": ["position", "linear_velocity"]})
	_check(reset_pose.ok and reset_pose.changed, "Explicit return to initial pose was incorrectly treated as a logical no-op")
	_check(host.state().body_states[0][0] == 200.0 and host.state().body_states[0][1] == 100.0, "Explicit live transform did not apply")
	var before_empty: Dictionary = host.state()
	_check(host.apply_object_graph([], before_empty.object_revision, before_empty.native_tick).ok, "Delete-last-body failed")
	var empty: Dictionary = host.state()
	_check(empty.rapier_steps == before_empty.rapier_steps and not empty.bridge_active and empty.body_states.is_empty(), "Deactivation lost cumulative Rapier counter or retained a body")
	var step: Dictionary = host.tick_once()
	_check(step.advanced and step.native_delta == 1 and step.rapier_delta == 0, "Empty-after-deletion scene stepped Rapier")
	for repeat: int in range(20):
		var row: Dictionary = Registry.make_box("cycle-%d" % repeat, repeat + 10, Vector2(300, 100))
		_check(host.apply_object_graph([row], host.state().object_revision, host.state().native_tick).ok, "Repeated spawn failed")
		_check(host.object_occupancy_at(Vector2i(300, 100)) == row.id, "Repeated spawn misrouted occupancy identity")
		var cycled_step: Dictionary = host.tick_once()
		_check(cycled_step.advanced and cycled_step.rapier_delta == 1, "Repeated reactivation failed actual Rapier stepping")
		_check(host.apply_object_graph([], host.state().object_revision, host.state().native_tick).ok, "Repeated deletion failed")
		_check(host.object_occupancy_at(Vector2i(300, 100)).is_empty(), "Repeated deletion retained a ghost")
		var inactive_step: Dictionary = host.tick_once()
		_check(inactive_step.advanced and inactive_step.rapier_delta == 0, "Repeated zero-body deactivation stepped a phantom")
	var reactivated: Dictionary = Registry.make_box("reactivated-in-water", 100, Vector2(300, 190))
	_check(host.apply_object_graph([reactivated], host.state().object_revision, host.state().native_tick).ok,
		"Reactivation into the native Water fixture failed")
	_check(host._rapier_bridge.diagnostic_applications.size() == 6,
		"Zero-body rebind erased the diagnostics-enabled state")
	for _tick: int in range(20):
		_check(host.tick_once().advanced, "Reactivated real feedback workload did not advance")
	var reactivated_feedback: Dictionary = host.state().object_feedback.get("reactivated-in-water", {})
	_check(int(reactivated_feedback.get("contacts", 0)) > 0 and int(reactivated_feedback.get("applications", 0)) > 0,
		"Real native feedback after zero-body reactivation was not observed/applied")
	_receipts["live_graph_lifecycle"] = {"slot_after_delete": after.slot_mapping, "old_sample_injection_applied": injected_applied,
		"empty_native_step": step, "repeated_create_delete": 20, "reactivated_feedback": reactivated_feedback}
	host.free()
	await process_frame


func _initial_properties_and_reconstruction() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var definition: Dictionary = Definitions.get_definition("blank")
	var body: Dictionary = Registry.make_box("passive-token", 7, Vector2(150, 150), Vector2(20, 30))
	body.name = "Passive subject"
	body.passive_subject = true
	body.rotation = 0.4
	body.mass = 2.75
	body.friction = 0.43
	body.restitution = 0.25
	body.linear_damp = 0.8
	body.angular_damp = 0.9
	body.linear_velocity = Vector2(3.0, -2.0)
	body.angular_velocity = 0.7
	var fixed: Dictionary = Registry.make_box("fixed-platform", 8, Vector2(300, 150), Vector2(50, 10))
	fixed.fixed = true
	var frozen: Dictionary = Registry.make_box("frozen-token", 9, Vector2(400, 150))
	frozen.frozen = true
	definition.bodies = [body, fixed, frozen]
	var configured: Dictionary = host.configure(definition)
	_check(configured.ready, "Nondefault properties configuration failed")
	if configured.ready:
		_check(configured.body_states[0][3] == 3.0 and configured.body_states[0][4] == -2.0 \
			and is_equal_approx(configured.body_states[0][5], 0.7), "Initial velocity was lost")
		_check(is_equal_approx(host._bodies[0].mass, 2.75) and is_equal_approx(host._bodies[0].physics_material_override.friction, 0.43) \
			and is_equal_approx(host._bodies[0].physics_material_override.bounce, 0.25), "Physical inspector properties were not installed")
		for tick: int in range(20):
			_check(host.tick_once().advanced, "Property fixture did not advance")
		var advanced: Dictionary = host.state()
		_check(advanced.body_states[1].slice(0, 3) == configured.body_states[1].slice(0, 3), "Fixed object moved")
		_check(advanced.body_states[2].slice(0, 3) == configured.body_states[2].slice(0, 3), "Frozen object moved")
		var snapshot: Dictionary = host.capture_physical_state()
		var restored: Dictionary = host.restore_physical_state(snapshot)
		_check(restored.ok, "Generalized internal physical snapshot did not restore")
		_check(host.get_object_definitions() == definition.bodies, "Internal restore lost logical metadata/properties")
		var restored_state: Dictionary = host.state()
		_check(restored_state.native_tick == snapshot.native_tick and restored_state.rapier_steps == 0,
			"Restore occupancy publication advanced a solver or changed the saved native tick")
		var occupied: Vector2i = Vector2i(Vector2(snapshot.bodies[0][0], snapshot.bodies[0][1]))
		_check(host.object_occupancy_at(occupied) == body.id,
			"Restored ready graph lost the actual native body occupancy mask")
		var captured: Dictionary = host.capture_cells()
		var before_refusal: Dictionary = host.capture_physical_state()
		var old_feedback: PackedFloat32Array = host._native_world.rigid_body_results().duplicate()
		var patch: Dictionary = host.plan_editor_patch(captured.cells,
			PackedInt32Array([occupied.y * 1024 + occupied.x]), MaterialTools.cell_tuple(2, 0, 0, 200))
		var refusal: Dictionary = host.apply_editor_patch(patch, captured.revision, captured.tick)
		_check(not refusal.ok and refusal.error == "body_occupancy_conflict",
			"Restored body mask did not protect against overlapping material authoring")
		var after_refusal: Dictionary = host.capture_physical_state()
		_check(after_refusal.native_payload == before_refusal.native_payload and after_refusal.bodies == before_refusal.bodies \
			and host._native_world.rigid_body_results() == old_feedback and host.state().native_tick == restored_state.native_tick \
			and host.state().rapier_steps == restored_state.rapier_steps,
			"Restored occupancy/edit refusal mutated physical state, feedback or solver counters")
		_receipts["restored_occupancy"] = {"cell": [occupied.x, occupied.y], "id": body.id,
			"native_tick": restored_state.native_tick, "rapier_steps": restored_state.rapier_steps,
			"occupied_edit_refusal": refusal.error}
		_check(before_refusal.native_payload == snapshot.native_payload,
			"Restore-only occupancy changed exact saved native physical bytes")
		var resumed: Dictionary = host.tick_once()
		_check(resumed.advanced and resumed.native_delta == 1 and resumed.rapier_delta == 1,
			"Actual normal coupled stepping did not resume after restored occupancy")
		var reset: Dictionary = host.configure(definition)
		_check(reset.body_states == configured.body_states, "Reset lost initial nonzero velocities or fixed/frozen states")
		_receipts["nondefault_initial_properties"] = {"initial": configured, "advanced": advanced}
	host.free()
	await process_frame


func _legacy_native_restore_binding() -> void:
	var native: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var demo: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var saved: PackedByteArray = demo.export_physical_state(native)
	_check(demo.import_physical_state(native, saved), "Legacy two-argument native physical import binding failed")
	_check(demo.export_physical_state(native) == saved and native.rigid_body_id_at(150, 150) == 0,
		"Legacy two-argument import changed physical bytes or created phantom occupancy")
	var bodies: PackedFloat32Array = PackedFloat32Array()
	for id: int in [1, 2]:
		CyberRigidBodyCoupling.append_input(bodies, id, Vector2(150, 150), 0.3,
			Vector2(20, 30), Vector2.ZERO, 0.0, 1.0, 7)
	_check(demo.import_physical_state(native, saved, bodies), "Restored-body native import binding failed")
	_check(native.rigid_body_id_at(150, 150) == 1 and demo.export_physical_state(native) == saved,
		"Restore mask lost lowest-slot overlap ownership or changed physical bytes")
	for malformed: PackedFloat32Array in [PackedFloat32Array([0.0]), bodies + bodies]:
		_check(not demo.import_physical_state(native, saved, malformed), "Malformed restore packed-body input was admitted")
		_check(native.rigid_body_id_at(150, 150) == 1 and demo.export_physical_state(native) == saved,
			"Malformed restore changed the retained live native graph or physical payload")
	_receipts["native_restore_bindings"] = {"legacy_two_argument": true,
		"optional_packed_bodies": true, "overlap_owner": 1, "malformed_atomic_refusals": 2}


func _metadata_feedback_boundary() -> void:
	var definition: Dictionary = _fixture(1)
	definition.bodies[0].position = Vector2(300, 190)
	var next_states: Array = []
	var receipts: Array = []
	for change_metadata: bool in [false, true]:
		var host: Variant = Host.new()
		root.add_child(host)
		_check(host.configure(definition).ready, "Metadata feedback fixture failed setup")
		var pending: PackedFloat32Array = PackedFloat32Array()
		var real_pending_impulse: bool = false
		for _tick: int in range(20):
			_check(host.tick_once().advanced, "Metadata feedback fixture did not advance")
			pending = host._native_world.rigid_body_results().duplicate()
			if pending.size() >= CyberRigidBodyCoupling.RESULT_STRIDE \
					and (pending[CyberRigidBodyCoupling.RESULT_IMPULSE_X] != 0.0 \
					or pending[CyberRigidBodyCoupling.RESULT_IMPULSE_Y] != 0.0):
				real_pending_impulse = true
				break
		_check(real_pending_impulse, "Metadata boundary fixture did not produce actual pending native impulse")
		var before: Dictionary = host.state()
		var before_physical: Dictionary = host.capture_physical_state()
		var rid: RID = host._bodies[0].get_rid()
		var occupied: Vector2i = Vector2i(Vector2(before.body_states[0][0], before.body_states[0][1]))
		if change_metadata:
			var candidate: Array = host.get_object_definitions()
			candidate[0].name = "Metadata-only renamed subject"
			candidate[0].passive_subject = true
			var changed: Dictionary = host.apply_object_graph(candidate, before.object_revision, before.native_tick,
				{candidate[0].id: ["name", "passive_subject"]})
			_check(changed.ok and changed.changed and not changed.physical_changed \
				and changed.revision == before.object_revision + 1, "Metadata-only edit was treated as a physical intervention")
			var after: Dictionary = host.state()
			var after_physical: Dictionary = host.capture_physical_state()
			_check(after_physical.native_payload == before_physical.native_payload \
				and after_physical.bodies == before_physical.bodies and host._bodies[0].get_rid() == rid,
				"Metadata-only change replaced or moved a physical owner")
			_check(after.slot_mapping == before.slot_mapping and host._native_world.rigid_body_results() == pending \
				and after.object_feedback == before.object_feedback and host.object_occupancy_at(occupied) == candidate[0].id,
				"Metadata-only change retired native masks, pending impulse, stable mapping or diagnostics")
			_check(after.native_tick == before.native_tick and after.rapier_steps == before.rapier_steps,
				"Metadata-only change advanced a solver")
			candidate[0].mass = 99.0
			_check(host.get_object_definitions()[0].mass == 1.0, "Metadata install leaked mutable candidate ownership")
		_check(host.tick_once().advanced, "Next coupled step after metadata boundary failed")
		var next: Dictionary = host.state()
		_check(int(next.object_feedback[definition.bodies[0].id].applications) \
			> int(before.object_feedback[definition.bodies[0].id].applications),
			"Actual pending native impulse was lost at metadata boundary")
		next_states.append({"native_payload": host.capture_physical_state().native_payload,
			"bodies": next.body_states, "feedback": host._native_world.rigid_body_results().duplicate(),
			"slot_mapping": next.slot_mapping, "object_feedback": next.object_feedback})
		receipts.append({"metadata_changed": change_metadata, "tick": next.native_tick,
			"rapier_steps": next.rapier_steps, "feedback": next.object_feedback,
			"slot_mapping": next.slot_mapping})
		host.free()
		await process_frame
	_check(next_states[0] == next_states[1], "Metadata-only boundary changed the next real coupled step versus its identical no-edit control")
	_receipts["metadata_feedback_boundary"] = receipts


func _restitution_rebound() -> void:
	var results: Array = []
	for restitution: float in [0.0, 0.8]:
		var host: Variant = Host.new()
		root.add_child(host)
		var definition: Dictionary = Definitions.get_definition("blank")
		definition.rectangles = PackedInt32Array([0, 0, 1024, 1024, 0, 10, 220, 460, 4, 1])
		var row: Dictionary = Registry.make_box("rebound-body", 1, Vector2(100, 180), Vector2(20, 20))
		row.restitution = restitution
		row.linear_velocity = Vector2(0, 120)
		row.gravity_scale = 0.0
		row.linear_damp = 0.0
		row.angular_damp = 0.0
		definition.bodies = [row]
		_check(host.configure(definition).ready, "Restitution fixture failed setup")
		var actual_bounce: float = float(PhysicsServer2D.body_get_param(host._bodies[0].get_rid(), PhysicsServer2D.BODY_PARAM_BOUNCE))
		_check(is_equal_approx(actual_bounce, restitution), "Restitution failed to reach the actual Rapier server")
		var min_velocity_y: float = INF
		var max_y: float = 0.0
		for _tick: int in range(60):
			_check(host.tick_once().advanced, "Restitution workload failed a real coupled tick")
			var observed: Dictionary = host.state()
			min_velocity_y = minf(min_velocity_y, float(observed.body_states[0][4]))
			max_y = maxf(max_y, float(observed.body_states[0][1]))
		_check(max_y > 208.0 and max_y < 212.0, "Restitution fixture did not strike and remain above the hard native floor")
		results.append({"restitution": restitution, "actual_rapier_bounce": actual_bounce,
			"minimum_velocity_y": min_velocity_y, "maximum_y": max_y, "final": host.state().body_states[0]})
		host.free()
		await process_frame
	_check(float(results[0].minimum_velocity_y) > -1.0 and absf(float(results[0].final[4])) < 1.0,
		"Zero restitution control unexpectedly rebounded or failed to settle")
	_check(float(results[1].minimum_velocity_y) < -50.0 and float(results[1].final[1]) < 190.0,
		"Authored nonzero restitution produced no actual rebound")
	_receipts["actual_restitution_rebound"] = results


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _graph_failure_boundaries() -> void:
	var allocation: Variant = RefusingAllocationHost.new()
	root.add_child(allocation)
	var configured: Dictionary = allocation.configure(_fixture(1))
	_check(configured.ready, "Allocation refusal fixture failed setup")
	if configured.ready:
		var before: Dictionary = allocation.capture_physical_state()
		var candidate: Array = allocation.get_object_definitions()
		candidate.append(Registry.make_box("allocation-refusal", 2, Vector2(250, 50)))
		allocation.refuse_allocation = true
		var refused: Dictionary = allocation.apply_object_graph(candidate, 0, 0)
		_check(not refused.ok and not refused.partial and not allocation.state().fault,
			"Pre-mutation allocation refusal entered a partial Fault")
		var after: Dictionary = allocation.capture_physical_state()
		_check(before.native_payload == after.native_payload and before.bodies == after.bodies \
			and before.definition == after.definition, "Pre-mutation allocation refusal changed the live graph")
	allocation.free()
	await process_frame
	var partial: Variant = RefusingTerrainHost.new()
	root.add_child(partial)
	configured = partial.configure(_fixture(1))
	_check(configured.ready, "Partial object mutation fixture failed setup")
	if configured.ready:
		_check(partial.tick_once().advanced, "Partial object fixture could not establish actual solver counters")
		var before: Dictionary = partial.state()
		var candidate: Array = partial.get_object_definitions()
		candidate[0].size = Vector2(24, 24)
		partial.refuse_terrain = true
		var failed: Dictionary = partial.apply_object_graph(candidate, before.object_revision, before.native_tick)
		var after: Dictionary = partial.state()
		_check(not failed.ok and failed.partial and after.fault and not after.ready,
			"Mutation followed by collider failure claimed atomic rollback")
		_check(after.body_sizes == [[24.0, 24.0]] and after.native_tick == before.native_tick \
			and after.rapier_steps == before.rapier_steps, "Partial failure did not retain actual graph/counters")
		_check(not partial.tick_once().advanced, "Fault accepted another tick after partial object mutation")
		_receipts["injected_partial_object_failure"] = {"result": failed, "actual_after": after}
	partial.free()
	await process_frame


func _finish() -> void:
	print("SANDFALL_OBJECT_TEST ", JSON.stringify({"ok": _failures.is_empty(), "checks": _checks,
		"failures": _failures, "receipts": _receipts,
		"scope": "actual native/Godot/Rapier; schema negatives and stale sample injection labelled; browser separate"}))
	quit(0 if _failures.is_empty() else 1)
