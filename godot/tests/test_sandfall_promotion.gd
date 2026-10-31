extends SceneTree

const Host = preload("res://scripts/sandfall/simulation_host.gd")
const Session = preload("res://scripts/sandfall/session_controller.gd")
const Promotion = preload("res://scripts/sandfall/intervention_promotion.gd")
const Presentation = preload("res://scripts/sandfall/presentation_model.gd")
const Tools = preload("res://scripts/sandfall/material_tools.gd")
const Codec = preload("res://scripts/sandfall/archive_codec.gd")

var _checks: int = 0
var _failures: Array[String] = []
var _receipts: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	await _presentation_history()
	await _new_draft_replay()
	await _passive_subject_promotion()
	await _partial_tick_and_capacity()
	print("SANDFALL_PROMOTION_TEST ", JSON.stringify({"ok": _failures.is_empty(), "checks": _checks,
		"failures": _failures, "receipts": _receipts,
		"scope": "exact mixed material/object/presentation history; frozen-initial declarative replay, preview leases and capacity"}))
	quit(0 if _failures.is_empty() else 1)


func _presentation_history() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "sandbox")
	var empty: Dictionary = session.authored_project()
	_material(session, PackedInt32Array([55 * 1024 + 55]), Tools.cell_tuple(12, 127, 0, 321), "pencil_stroke")
	var painted: Dictionary = session.authored_project()
	_object(session, {"operation": "spawn", "definition": {"position": Vector2(250, 60)}})
	var with_object: Dictionary = session.authored_project()
	var physical: Dictionary = host.capture_physical_state()
	var decoration: Dictionary = Presentation.defaults()
	decoration.annotations = [{"id": "note-1", "type": "label", "points": [[30.0, 40.0]],
		"color": "#ffffff80", "width": 2.0, "text": "Heat stays in cells"}]
	var state: Dictionary = session.state()
	_check(session.enqueue_presentation(decoration, state.document.revision, state.generation, state.input_epoch), "Presentation enqueue refused")
	session.process_commands()
	_check(session.state().document.undo_depth == 3 and host.capture_physical_state() == physical,
		"Presentation history changed physics or split chronology")
	var with_presentation: Dictionary = session.authored_project()
	_command(session, "undo")
	_same_authored(session.authored_project(), with_object, "presentation undo")
	_command(session, "undo")
	_same_authored(session.authored_project(), painted, "object undo")
	_command(session, "undo")
	_same_authored(session.authored_project(), empty, "material undo")
	for _index: int in 3: _command(session, "redo")
	_same_authored(session.authored_project(), with_presentation, "mixed redo")
	decoration.annotations[0].text = "Caller alias"
	_check(session.presentation().annotations[0].text == "Heat stays in cells", "Presentation payload aliases caller")
	var bytes: int = session.state().document.history_bytes
	session._document._history_bytes = session._document.MAX_HISTORY_BYTES
	state = session.state()
	_check(session.enqueue_presentation(decoration, state.document.revision, state.generation, state.input_epoch), "Capacity fixture failed enqueue")
	session.process_commands()
	_check(session.state().last_refusal == "history_capacity_refused_before_mutation"
		and session.presentation().annotations[0].text == "Heat stays in cells", "Presentation exceeded bounded history before refusal")
	session._document._history_bytes = bytes
	_command(session, "run")
	_command(session, "toggle_pause")
	_command(session, "undo")
	_check(session.state().last_refusal == "history_requires_edit_at_zero" and session.state().document.locked,
		"Paused zero-tick Run unlocked presentation history")
	_command(session, "step")
	_check(session.advance() and session.state().document.undo_depth == 0 and session.state().document.retired,
		"First physics tick did not retire presentation history")
	_command(session, "reset_edit")
	_check(session.presentation().annotations[0].text == "Heat stays in cells" and session.state().document.undo_depth == 0,
		"Reset & Edit lost authored presentation or resurrected history")
	_receipts.presentation_history = {"mixed_transactions": 3, "capacity_refused": true, "first_tick_retired": true}
	host.free()
	await process_frame


func _new_draft_replay() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "sandbox")
	_material(session, PackedInt32Array([60 * 1024 + 70]), Tools.cell_tuple(2, 0, 0, 200), "pencil_stroke")
	_object(session, {"operation": "spawn", "definition": {"position": Vector2(300, 60), "linear_velocity": Vector2(5, 0)}})
	var id: String = session.state().last_edit.object_id
	var initial: Dictionary = session.authored_project()
	_command(session, "run")
	for _tick: int in 30: _check(session.advance(), "Promotion fixture did not evolve")
	_command(session, "toggle_pause")
	var native_before: PackedByteArray = session.editing_snapshot().cells
	_check(native_before != initial.initial_cells, "Promotion fixture did not evolve native cells")
	var paint_index: int = 25 * 1024 + 20
	_material(session, PackedInt32Array([paint_index]), Tools.cell_tuple(12, 113, 0, -456), "pencil_stroke")
	_object(session, {"operation": "update", "id": id, "changes": {"mass": 3.5, "position": Vector2(280, 70)}})
	_object(session, {"operation": "spawn", "definition": {"position": Vector2(380, 60), "size": Vector2(16, 21)}})
	var new_id: String = session.state().last_edit.object_id
	var excluded_index: int = 26 * 1024 + 20
	_material(session, PackedInt32Array([excluded_index]), Tools.cell_tuple(1, 0, 0, 200), "selection_move")
	_check(not session.state().pristine and session.state().intervention_count == 4, "Accepted interventions were not recorded")
	var before: Dictionary = host.capture_physical_state()
	session.set_modal_open(true)
	var preview: Dictionary = session.preview_promotion()
	_check(preview.ok and preview.eligible == 3 and preview.skipped == 1 and preview.conflicts.size() == 1,
		"Preview did not explicitly exclude runtime selection")
	_check(host.capture_physical_state() == before and session.state().mode == "run", "Preview mutated the live run")
	var cancelled_token: int = int(preview.get("token", -1))
	session.set_modal_open(false)
	_check(not session.confirm_promotion(cancelled_token).ok and host.capture_physical_state() == before,
		"Cancelled preview token replaced the scene")
	session.set_modal_open(true)
	preview = session.preview_promotion()
	var old_generation: int = session.state().generation
	var accepted: Dictionary = session.confirm_promotion(int(preview.get("token", -1)))
	_check(accepted.ok, "Confirmed new draft refused: " + str(accepted.get("error", "")))
	var state: Dictionary = session.state()
	_check(state.mode == "edit" and state.paused and state.tick == 0 and state.rapier_steps == 0
		and state.generation == old_generation + 1 and state.document.undo_depth == 0 and state.document.redo_depth == 0,
		"Promotion did not create a fresh paused tick-zero Edit session")
	var expected: PackedByteArray = initial.initial_cells.duplicate()
	var painted: PackedByteArray = Tools.cell_tuple(12, 113, 0, -456)
	for offset: int in 5: expected[paint_index * 5 + offset] = painted[offset]
	_check(session.authored_project().initial_cells == expected,
		"Promotion copied evolved chemistry/material movement or excluded selection payload")
	var objects: Array = session.object_definitions()
	_check(objects.size() == 2 and objects[0].id == id and objects[0].mass == 3.5
		and objects[0].position == Vector2(280, 70) and objects[0].linear_velocity == Vector2(5, 0)
		and objects[1].id == new_id, "Promotion lost stable IDs or copied evolved body velocity")
	_check(session.project_identity().logical_sha256 == preview.candidate_hash,
		"Confirmed draft differs from previewed canonical identity")
	_check(not session.confirm_promotion(int(preview.token)).ok, "Promotion token applied twice")
	_receipts.promotion = {"preview": preview, "new_generation": state.generation, "objects": state.object_definitions,
		"frozen_cells_replayed_exactly": true, "evolved_state_excluded": true}
	# Explicit original footprints retain unchanged live cells too. This is a
	# pure journal boundary test rather than a manufactured physics claim.
	var journal: Array = [{"kind": "pencil_stroke", "accepted": true, "sequence": 1,
		"command_indices": PackedInt32Array([paint_index, excluded_index]),
		"command_after": painted + painted, "indices": PackedInt32Array([paint_index]), "after": painted}]
	var replay: Dictionary = Promotion.build(initial, journal)
	_check(replay.ok and replay.definition.initial_cells.slice(excluded_index * 5, excluded_index * 5 + 5) == painted,
		"Promotion replayed only changed live cells, losing the complete declared footprint")
	var cancel_paint: Array = [{"kind": "pencil_stroke", "accepted": true, "sequence": 1,
		"command_indices": PackedInt32Array([paint_index]), "command_after": painted},
		{"kind": "erase_stroke", "accepted": true, "sequence": 2,
		"command_indices": PackedInt32Array([paint_index]),
		"command_after": initial.initial_cells.slice(paint_index * 5, paint_index * 5 + 5)}]
	var reverted: Dictionary = Promotion.build(initial, cancel_paint)
	_check(reverted.ok and reverted.preview.changed_cells == 0 and reverted.preview.changed_cell_bounds_inclusive.is_empty()
		and reverted.preview.material_changes.size() == 2 and reverted.definition.initial_cells == initial.initial_cells,
		"Promotion preview misreported cancelled intermediate paint as a final initial difference")
	host.free()
	await process_frame


func _passive_subject_promotion() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "sandbox")
	_object(session, {"operation": "spawn", "definition": {"position": Vector2(120, 60), "passive_subject": true}})
	var original_id: String = session.state().last_edit.object_id
	var initial: Dictionary = session.authored_project()
	var initial_project: Dictionary = initial.get("project", Codec.project_defaults(initial.bodies))
	_check(initial_project.passive_subject_id == original_id and initial.bodies[0].passive_subject,
		"Initial passive subject was not frozen in the authored project")
	_command(session, "run")
	_command(session, "toggle_pause")
	_object(session, {"operation": "spawn", "definition": {"position": Vector2(220, 60), "passive_subject": true}})
	var new_id: String = session.state().last_edit.object_id
	var journal: Array = session.intervention_journal()
	_check(journal.size() == 1 and journal[0].source == session.source_identity()
		and Codec.validate_source(journal[0].source).ok,
		"Object intervention omitted the normalized local source identity")
	journal[0].source.source_commit = "caller-alias"
	_check(session.intervention_journal()[0].source == session.source_identity(),
		"Object journal source identity aliases caller-owned data")
	var objects: Array = session.object_definitions()
	_check(objects.size() == 2 and not objects[0].passive_subject and objects[1].passive_subject,
		"Accepted passive-subject spawn did not transfer the live designation")
	_check(session.authored_project().bodies == initial.bodies,
		"Live passive-subject spawn changed the frozen initial project")
	session.set_modal_open(true)
	var before: Dictionary = host.capture_physical_state()
	var preview: Dictionary = session.preview_promotion()
	_check(preview.ok and preview.eligible == 1 and preview.skipped == 0
		and host.capture_physical_state() == before,
		"Passive-subject spawn preview refused or mutated the live run")
	if preview.ok:
		var accepted: Dictionary = session.confirm_promotion(int(preview.token))
		var promoted: Dictionary = session.authored_project()
		_check(accepted.ok and promoted.bodies.size() == 2 and promoted.bodies[0].id == original_id
			and not promoted.bodies[0].passive_subject and promoted.bodies[1].id == new_id
			and promoted.bodies[1].passive_subject and promoted.project.passive_subject_id == new_id,
			"Confirmed promotion failed to preserve IDs and transfer the passive-subject role")
		_check(Codec.encode_definition(promoted).ok and session.state().mode == "edit"
			and session.state().tick == 0 and session.state().rapier_steps == 0,
			"Promoted passive-subject project is not an exportable fresh draft")
	_receipts.passive_subject_promotion = {"previous_id": original_id, "new_id": new_id,
		"single_role_preserved": preview.ok, "local_source_recorded": true, "frozen_original_preserved": true}
	host.free()
	await process_frame


func _partial_tick_and_capacity() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "sandbox")
	_command(session, "run")
	_command(session, "toggle_pause")
	var initial: Dictionary = session.authored_project()
	session._intervention_bytes = Session.MAX_INTERVENTION_BYTES - 17
	var before: Dictionary = host.capture_physical_state()
	_material(session, PackedInt32Array([10 * 1024 + 10]), Tools.cell_tuple(1, 0, 0, 200), "pencil_stroke")
	_check(session.state().last_refusal == "intervention_journal_capacity" and session.state().pristine
		and host.capture_physical_state() == before, "Promotion command payload bytes were omitted from pre-mutation capacity")
	session._intervention_bytes = 0
	session.set_modal_open(true)
	_check(not session.preview_promotion().ok, "Empty journal produced a promotable evolved snapshot")
	_check(session.authored_project().initial_cells == initial.initial_cells, "Failed promotion altered frozen initial cells")
	_receipts.capacity = {"logical_bytes_per_single_material_cell": 18, "refused_before_mutation": true}
	host.free()
	await process_frame


func _material(session: Variant, indices: PackedInt32Array, desired: PackedByteArray, kind: String) -> void:
	var state: Dictionary = session.state()
	_check(session.enqueue_mutation(indices, desired, kind, state.document.revision, state.generation, state.input_epoch), "Material enqueue refused")
	session.process_commands()


func _object(session: Variant, operation: Dictionary) -> void:
	var context: Dictionary = session.object_edit_snapshot()
	_check(session.enqueue_object_edit(operation, context.revision, context.generation, context.input_epoch), "Object enqueue refused")
	session.process_commands()


func _command(session: Variant, action: String, value: String = "") -> void:
	_check(session.enqueue(action, value), "Command refused: " + action)
	session.process_commands()


func _same_authored(a: Dictionary, b: Dictionary, label: String) -> void:
	_check(a.initial_cells == b.initial_cells and a.bodies == b.bodies and a.presentation == b.presentation,
		"Exact mixed history differs at " + label)


func _check(value: bool, message: String) -> void:
	_checks += 1
	if not value: _failures.append(message)
