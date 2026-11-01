extends SceneTree

# Real fresh-native/Rapier document/session integration. Explicit model-only
# budget injections below test preflight capacity without allocating 64 MiB.
const Host = preload("res://scripts/sandfall/simulation_host.gd")
const Session = preload("res://scripts/sandfall/session_controller.gd")
const Document = preload("res://scripts/sandfall/authoring_document.gd")
const Registry = preload("res://scripts/sandfall/rapier_object_registry.gd")
const MaterialTools = preload("res://scripts/sandfall/material_tools.gd")

class PartialHost extends Host:
	var fail_terrain: bool = false
	func _sync_terrain() -> void:
		if fail_terrain:
			_enter_fault("labelled object-history partial terrain failure")
		else:
			super._sync_terrain()

class NativeRefusalHost extends Host:
	func _advance_native_tick() -> bool:
		return false

var _checks: int = 0
var _failures: Array[String] = []
var _receipts: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	if not ClassDB.class_exists(&"SandfallEditBridge"):
		_check(false, "Fresh native SandfallEditBridge required")
		_finish()
		return
	await _mixed_history()
	await _reconstructed_identity_allocation()
	await _run_commands_and_capacity()
	await _partial_failures()
	await _model_history_limits()
	_finish()


func _mixed_history() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "sandbox")
	var states: Array = [_authored(session, host)]
	_material(session, 50 * 1024 + 50, MaterialTools.cell_tuple(1, 0, 0, -123))
	states.append(_authored(session, host))
	_object(session, {"operation": "spawn", "definition": {"position": Vector2(240, 90), "size": Vector2(19, 23),
		"linear_velocity": Vector2(5, -3), "angular_velocity": 0.2, "name": "Copper token", "passive_subject": true}})
	var id: String = session.state().last_edit.object_id
	states.append(_authored(session, host))
	_object(session, {"operation": "update", "id": id, "changes": {"position": Vector2(250, 110), "rotation": 0.3}})
	states.append(_authored(session, host))
	_object(session, {"operation": "update", "id": id, "changes": {"mass": 4.5, "friction": 0.23, "restitution": 0.4,
		"linear_damp": 0.61, "angular_damp": 0.72, "size": Vector2(21, 27)}})
	states.append(_authored(session, host))
	_material(session, 50 * 1024 + 50, MaterialTools.cell_tuple(0, 0, 0, 200))
	states.append(_authored(session, host))
	_object(session, {"operation": "duplicate", "id": id, "offset": Vector2(50, 0)})
	var duplicate_id: String = session.state().last_edit.object_id
	states.append(_authored(session, host))
	_object(session, {"operation": "delete", "id": id})
	states.append(_authored(session, host))
	_check(session.state().document.undo_depth == states.size() - 1, "Mixed operations do not share one chronological history")
	for index: int in range(states.size() - 2, -1, -1):
		_command(session, "undo")
		_assert_authored(session, host, states[index], "mixed undo %d" % index)
	for index: int in range(1, states.size()):
		_command(session, "redo")
		_assert_authored(session, host, states[index], "mixed redo %d" % index)
	var snapshot: Dictionary = session.initial_definition()
	snapshot.bodies[0].mass = 99.0
	var definitions: Array = session.object_definitions()
	definitions[0].name = "caller alias"
	_check(session.object_definitions()[0].mass == 4.5 and session.object_definitions()[0].name == "Copper token", "Public logical object copies alias their owner")
	_command(session, "undo")
	_object(session, {"operation": "delete", "id": duplicate_id})
	_object(session, {"operation": "spawn", "definition": {"position": Vector2(340, 80)}})
	var fresh_id: String = session.state().last_edit.object_id
	_check(fresh_id != id and fresh_id != duplicate_id and session.state().document.redo_depth == 0,
		"Allocation reused a retired ID or new edit retained redo")
	_check(session.state().body_poses == session.state().initial_body_poses, "Accepted Edit baseline does not describe its authored graph")
	_receipts.mixed_history = {"transactions": states.size() - 1, "original_id": id, "duplicate_id": duplicate_id,
		"new_id_after_delete_and_undo": fresh_id, "final": session.state()}
	host.free()
	await process_frame


func _reconstructed_identity_allocation() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "sandbox")
	var definition: Dictionary = session.initial_definition()
	# Internal logical IDs and creation order are deliberately independent.
	definition.bodies = [Registry.make_box("sf-box-100", 1, Vector2(210, 90))]
	session._install(definition, "edit", true)
	_check(session.state().mode == "edit" and session.object_definitions()[0].id == "sf-box-100",
		"Reconstructed ID/order mismatch fixture did not install")
	_object(session, {"operation": "delete", "id": "sf-box-100"})
	_object(session, {"operation": "spawn"})
	_check(session.state().last_edit.object_id == "sf-box-101" and session.object_definitions()[0].creation_order == 101,
		"Allocator failed to reserve a reconstructed stable ID independently of creation order")
	_command(session, "reset_edit")
	_object(session, {"operation": "spawn", "definition": {"position": Vector2(310, 90)}})
	_check(session.state().last_edit.object_id == "sf-box-102", "Reconstruction/reset reused an observed allocator ID")
	_receipts.reconstructed_identity = {"reconstructed_id": "sf-box-100", "reconstructed_order": 1,
		"next_id_after_delete_and_reset": session.state().last_edit.object_id}
	definition.bodies = [Registry.make_box("sf-box-2147483647", 1, Vector2(210, 90))]
	session._install(definition, "edit", true)
	var before: Dictionary = _authored(session, host)
	_object(session, {"operation": "spawn"})
	_check(session.state().last_refusal == "invalid_or_duplicate_creation_order" and _authored(session, host) == before
		and session.state().document.undo_depth == 0, "Exhausted allocator mutated the graph or history")
	host.free()
	await process_frame


func _run_commands_and_capacity() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "sandbox")
	_object(session, {"operation": "spawn", "definition": {"position": Vector2(200, 60), "linear_velocity": Vector2(12, 0)}})
	var id: String = session.state().last_edit.object_id
	var frozen: Array = session.object_definitions()
	_command(session, "run")
	_command(session, "toggle_pause")
	_check(session.state().document.locked and session.state().document.undo_depth == 1, "Paused Run zero must lock but not yet retire Edit history")
	var before: Dictionary = session.state()
	_object(session, {"operation": "update", "id": id, "changes": {"mass": frozen[0].mass}})
	_check(session.state().last_refusal == "no_effect" and session.state().pristine and session.state().intervention_count == 0
		and session.state().mutation_count == before.mutation_count, "Run no-op incorrectly marks Modified or journals")
	var old: Dictionary = session.object_edit_snapshot()
	for malformed: Dictionary in [{"operation": "delete", "id": id, "changes": {"mass": NAN}},
			{"operation": "spawn", "definition": {}, "changes": {"unknown": true}},
			{"operation": "update", "id": id, "offset": Vector2.ZERO},
			{"operation": "duplicate", "id": id, "definition": {}}]:
		_check(not session.enqueue_object_edit(malformed, old.revision, old.generation, old.input_epoch), "Operation-inapplicable payload was admitted")
	_check(session.object_definitions() == frozen and session.state().pristine, "Malformed outer operation mutated live graph")
	_check(not session.enqueue_object_edit({"operation": "delete", "id": id}, old.revision, old.generation - 1, old.input_epoch), "Stale generation object accepted")
	_check(not session.enqueue_object_edit({"operation": "delete", "id": id}, old.revision, old.generation, old.input_epoch - 1), "Stale input object accepted")
	_check(session.enqueue_object_edit({"operation": "delete", "id": id}, old.revision - 1, old.generation, old.input_epoch), "Revision refusal did not reach exclusive owner")
	session.process_commands()
	_check(session.object_definitions().size() == 1 and session.state().last_refusal == "stale_object_revision", "Stale object revision deleted body")
	var mapping: Dictionary = host.state().slot_mapping
	var pose_before_metadata: Array = host.state().body_states
	_object(session, {"operation": "update", "id": id, "changes": {"name": "A temporary label", "passive_subject": true}})
	_check(session.state().pristine and session.state().intervention_count == 0 and not session.state().last_edit.physical
		and host.state().slot_mapping == mapping and host.state().body_states == pose_before_metadata,
		"Cosmetic object metadata changed physical identity, journal or Pristine")
	for _tick: int in range(20):
		_command(session, "step")
		_check(session.advance(), "Run object-history fixture did not step")
	_check(session.state().history_retired and session.state().document.undo_depth == 0, "First actual coupled tick did not retire object history")
	var evolved: Array = session.state().body_poses[0].duplicate()
	_check(Vector2(evolved[0], evolved[1]).distance_to(frozen[0].position) > 1.0, "Explicit pose reset fixture did not evolve")
	_object(session, {"operation": "update", "id": id, "changes": {"position": frozen[0].position}})
	var reset_pose: Array = session.state().body_poses[0]
	_check(Vector2(reset_pose[0], reset_pose[1]).is_equal_approx(frozen[0].position) and not session.state().pristine
		and session.state().intervention_count == 1, "Explicit same-logical initial transform failed to intervene on evolved pose")
	_check(is_equal_approx(reset_pose[3], evolved[3]) and is_equal_approx(reset_pose[4], evolved[4]), "Transform-only intervention reset unrequested velocity")
	var journal: Array = session.intervention_journal()
	var cost: int = Registry.logical_payload_bytes(journal[0].before_objects) + Registry.logical_payload_bytes(journal[0].after_objects) \
		+ JSON.stringify(journal[0].explicit_fields, "", true, true).to_utf8_buffer().size()
	_check(session.state().intervention_bytes == cost, "Object intervention logical payload accounting is incomplete")
	journal[0].after_objects[0].mass = 123.0
	_check(session.intervention_journal()[0].after_objects[0].mass == frozen[0].mass, "Intervention object payload aliases owner")
	var receipt_before: Dictionary = session.state()
	# Explicit labelled model-only journal-budget injection around a real host.
	session._intervention_bytes = Session.MAX_INTERVENTION_BYTES
	_object(session, {"operation": "delete", "id": id})
	_check(session.object_definitions().size() == 1 and session.state().last_refusal == "intervention_journal_capacity"
		and session.state().intervention_count == 1, "Journal byte refusal happened after physical mutation")
	session._intervention_bytes = int(receipt_before.intervention_bytes)
	var saved_journal: Array = session._interventions.duplicate(true)
	session._interventions.resize(Session.MAX_INTERVENTIONS)
	_object(session, {"operation": "delete", "id": id})
	_check(session.object_definitions().size() == 1 and session.state().last_refusal == "intervention_journal_capacity", "Journal entry refusal happened after physical mutation")
	session._interventions.assign(saved_journal)
	_command(session, "reset")
	_check(session.object_definitions() == frozen and session.state().tick == 0 and session.state().rapier_steps == 0
		and session.state().pristine and not session.state().document.can_undo, "Reset did not restore exact frozen objects")
	_command(session, "reset_edit")
	_check(session.state().document.undo_depth == 0 and session.state().document.redo_depth == 0 and session.object_definitions() == frozen,
		"Reset & Edit resurrected object history or changed baseline")
	var lease: Dictionary = session.object_edit_snapshot()
	_check(session.enqueue_object_edit({"operation": "delete", "id": id}, lease.revision, lease.generation, lease.input_epoch), "Input retirement setup refused")
	session.focus_lost()
	session.process_commands()
	_check(session.object_definitions() == frozen, "Blur applied retired queued object command")
	_receipts.run = {"frozen": Registry.logical_graph(frozen), "evolved": evolved, "reset_pose": reset_pose,
		"journal_payload_bytes": cost, "final": session.state()}
	host.free()
	await process_frame


func _partial_failures() -> void:
	var host: Variant = PartialHost.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "sandbox")
	_object(session, {"operation": "spawn"})
	var id: String = session.state().last_edit.object_id
	_command(session, "run")
	_command(session, "toggle_pause")
	var epoch: int = session.state().input_epoch
	host.fail_terrain = true
	_object(session, {"operation": "update", "id": id, "changes": {"size": Vector2(29, 31)}})
	var fault: Dictionary = session.state()
	_check(fault.mode == "fault" and not fault.pristine and fault.input_epoch > epoch and fault.history_retired, "Partial Run graph effect lacked truthful Modified/Fault/input retirement")
	_check(fault.last_edit.partial and not fault.last_edit.accepted and fault.intervention_count == 0
		and fault.tick == 0 and fault.rapier_steps == 0, "Partial object failure invented success, solver advancement or journal rollback")
	_check(host.get_object_definitions()[0].size == Vector2(29, 31), "Partial fixture did not actually mutate geometry")
	_check(not session.advance(), "Partial object Fault advanced")
	_receipts.partial_object_fault = fault
	host.free()
	await process_frame
	host = PartialHost.new()
	root.add_child(host)
	session = Session.new(host)
	_command(session, "sandbox")
	_command(session, "run")
	_command(session, "toggle_pause")
	host.fail_terrain = true
	_object(session, {"operation": "spawn"})
	var partial_id: String = session.state().last_edit.object_id
	_check(session.state().mode == "fault" and host.get_object_definitions().size() == 1, "Partial spawn did not install the labelled physical candidate")
	host.fail_terrain = false
	_command(session, "reset_edit")
	_object(session, {"operation": "spawn"})
	_check(session.state().last_edit.object_id != partial_id, "An ID exposed by partial mutation was reallocated after recovery")
	host.free()
	await process_frame
	host = NativeRefusalHost.new()
	root.add_child(host)
	session = Session.new(host)
	_command(session, "sandbox")
	_object(session, {"operation": "spawn"})
	_command(session, "run")
	_check(not session.advance(), "Injected native failure claimed successful coupled advancement")
	fault = session.state()
	_check(fault.mode == "fault" and fault.tick == 0 and fault.rapier_steps == 1 and fault.document.undo_depth == 0
		and fault.document.redo_depth == 0 and fault.history_retired, "Rapier-only advancement retained object history")
	_receipts.partial_coupled_fault = fault
	host.free()
	await process_frame


func _model_history_limits() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "sandbox")
	var definition: Dictionary = session.initial_definition()
	var document: Variant = Document.new(definition, session.authoring_cells())
	var graph: Array = [Registry.make_box("model-capacity", 1, Vector2(200, 80))]
	var patch: Dictionary = document.prepare_objects(graph, 0, "object_spawn")
	var safe_patch: Dictionary = patch.duplicate(true)
	patch.after_objects[0].mass = 50.0
	_check(not document.commit(patch) and document.objects_copy().is_empty(), "Changed public candidate bypassed private copied ownership")
	_check(document.commit(safe_patch), "Exact original private candidate failed")
	var expected_cost: int = Registry.logical_payload_bytes([]) + Registry.logical_payload_bytes(graph)
	_check(document.state().history_bytes == expected_cost, "Object history cost is not exact before/after logical payload")
	for index: int in range(1, Document.MAX_HISTORY_ENTRIES):
		graph[0].mass = 1.0 + float(index)
		patch = document.prepare_objects(graph, document.state().revision, "object_update")
		_check(patch.ok and document.commit(patch), "Bounded model history entry %d failed" % index)
	var before: Dictionary = document.state()
	graph[0].mass = 999.0
	patch = document.prepare_objects(graph, before.revision, "object_overflow")
	_check(not patch.ok and patch.error == "history_capacity_refused_before_mutation" and document.state() == before,
		"History entry513 did not refuse without mutation")
	patch = document.prepare_history("undo")
	_check(patch.ok and document.commit(patch), "Full history could not undo")
	patch = document.prepare_objects(graph, document.state().revision, "branch_after_undo")
	_check(patch.ok and document.commit(patch) and document.state().redo_depth == 0, "Branch history capacity did not release redo correctly")
	# Artificial near-limit byte counter is labelled; the actual refusal still
	# traverses session/document/host admission, proving the live graph is intact.
	session._document._history_bytes = Document.MAX_HISTORY_BYTES
	var physical: Dictionary = host.state()
	_object(session, {"operation": "spawn"})
	_check(session.object_definitions().is_empty() and session.state().last_refusal == "history_capacity_refused_before_mutation"
		and host.state().object_revision == physical.object_revision, "History byte overflow changed the physical graph")
	_receipts.model_capacity = {"entries": Document.MAX_HISTORY_ENTRIES, "bytes_at_entry_limit": before.history_bytes,
		"byte_limit_injection": true, "private_candidate_copy": true}
	host.free()
	await process_frame


func _authored(session: Variant, host: Variant) -> Dictionary:
	return {"cells": session.authoring_cells(), "objects": session.initial_definition().bodies,
		"body_states": host.state().body_states, "body_sizes": host.state().body_sizes}


func _assert_authored(session: Variant, host: Variant, expected: Dictionary, label: String) -> void:
	_check(session.authoring_cells() == expected.cells and host.capture_cells().cells == expected.cells, label + " lost exact material/thermal tuples")
	_check(session.initial_definition().bodies == expected.objects and session.object_definitions() == expected.objects, label + " lost exact object metadata/properties/IDs")
	_check(host.state().body_sizes == expected.body_sizes, label + " lost exact geometry")
	var actual: Array = host.state().body_states
	_check(actual.size() == expected.body_states.size(), label + " changed body count")
	for index: int in range(mini(actual.size(), expected.body_states.size())):
		for component: int in range(6):
			_check(is_equal_approx(float(actual[index][component]), float(expected.body_states[index][component])), label + " changed pose/velocity")
	_check(session.state().tick == 0 and session.state().rapier_steps == 0, label + " stepped physics")


func _command(session: Variant, command: String) -> void:
	_check(session.enqueue(command), "Command enqueue refused: " + command)
	session.process_commands()


func _object(session: Variant, operation: Dictionary) -> void:
	var snapshot: Dictionary = session.object_edit_snapshot()
	_check(session.enqueue_object_edit(operation, snapshot.revision, snapshot.generation, snapshot.input_epoch), "Object operation could not queue")
	session.process_commands()


func _material(session: Variant, index: int, tuple: PackedByteArray) -> void:
	var snapshot: Dictionary = session.editing_snapshot()
	var state: Dictionary = session.state()
	_check(session.enqueue_mutation(PackedInt32Array([index]), tuple, "mixed_material", snapshot.revision, state.generation, state.input_epoch), "Mixed material operation could not queue")
	session.process_commands()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	var result: Dictionary = {"ok": _failures.is_empty(), "assertions": _checks, "failures": _failures, "receipts": _receipts}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--sandfall-result="):
			var file: FileAccess = FileAccess.open(argument.trim_prefix("--sandfall-result="), FileAccess.WRITE)
			file.store_string(JSON.stringify(result, "\t") + "\n")
	print("SANDFALL_OBJECT_HISTORY_TEST ", JSON.stringify(result))
	quit(0 if _failures.is_empty() else 1)
