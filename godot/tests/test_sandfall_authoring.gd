extends SceneTree

# Real native/Godot/Rapier integration. Model-only geometry/history-capacity
# checks are explicitly identified; physical refusal injections are labelled.
const Host = preload("res://scripts/sandfall/simulation_host.gd")
const Session = preload("res://scripts/sandfall/session_controller.gd")
const Document = preload("res://scripts/sandfall/authoring_document.gd")
const Tools = preload("res://scripts/sandfall/material_tools.gd")

class RefusingNativeHost extends Host:
	func _advance_native_tick() -> bool:
		return false

var _failures: Array[String] = []
var _checks: int = 0
var _receipts: Dictionary = {}
var _bridge: Variant


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	_bridge = ClassDB.instantiate(&"SandfallEditBridge")
	if _bridge == null:
		_check(false, "Fresh Sandfall edit adapter unavailable")
		_finish()
		return
	await _exact_edit_and_refusals()
	await _run_and_first_tick_fence()
	await _partial_coupled_failure()
	await _chemistry_and_thermal()
	await _selection_fill_geometry()
	await _history_capacity()
	await _full_world_and_offscreen()
	await _read_only_coupling_snapshot()
	_finish()


func _exact_edit_and_refusals() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "sandbox")
	var initial: Dictionary = session.state()
	_check(initial.ready and initial.document.valid, "Authored document was not constructed")
	if not initial.ready:
		host.free()
		return
	var catalogue: Array = host.material_catalogue()
	_check(catalogue.size() == 131, "Runtime catalogue lost IDs or admitted reserved slot")
	for row: Dictionary in catalogue:
		_check(int(row.id) != 10 and not str(row.name).is_empty(), "Invalid catalogue entry")
	var index: int = 50 * 1024 + 50
	var exact: PackedByteArray = Tools.cell_tuple(6, 17, 23, -125)
	_mutate(session, PackedInt32Array([index]), exact, "thermal_fire_authoring")
	var changed: Dictionary = session.state()
	_check(changed.document.undo_depth == 1 and changed.document.revision == 1, "One edit did not make one history transaction")
	_check(_at(host, index) == exact, "Native edit lost material/state/temperature tuple")
	_check(changed.document.cells_sha256 == changed.current_hash, "Document and real native preview disagree")
	for _frame: int in range(3):
		await physics_frame
		_check(not session.advance(), "Edit preview advanced a solver")
	_check(session.state().tick == 0 and session.state().rapier_steps == 0, "Edit did not remain at exact zero")
	_command(session, "undo")
	_check(session.state().current_hash == initial.initial_hash and session.state().document.redo_depth == 1, "Undo did not restore full authored initial payload")
	var empty: PackedByteArray = Tools.cell_tuple(0, 0, 0, 200)
	_mutate(session, PackedInt32Array([index]), empty, "no_effect")
	_check(session.state().document.redo_depth == 1 and session.state().document.undo_depth == 0, "No-op cleared redo or created history")
	_command(session, "redo")
	_check(_at(host, index) == exact and session.state().current_hash == changed.current_hash, "Redo was not byte-exact")
	var original: PackedByteArray = session.authoring_cells()
	original[index * 5] = 1
	var snapshot: Dictionary = session.initial_definition()
	snapshot.initial_cells[index * 5] = 1
	snapshot.rectangles[0] = 999
	_check(_at(host, index) == exact and session.authoring_cells()[index * 5] == 6, "External copy mutated authored/live state")
	var before_bad: Dictionary = session.state()
	var bad: PackedByteArray = Tools.cell_tuple(2, 0, 0, 200)
	bad.append_array(Tools.cell_tuple(10, 0, 0, 200))
	_mutate(session, PackedInt32Array([index + 1, index + 2]), bad, "invalid_late_tuple")
	_check(session.state().current_hash == before_bad.current_hash and session.state().native.native_revision == before_bad.native.native_revision, "Invalid final tuple partly applied a batch")
	_mutate(session, PackedInt32Array([index]), Tools.cell_tuple(3, 0, 0, 200), "zero_mass_water")
	_check(session.state().current_hash == before_bad.current_hash, "Zero-mass Water silently normalized")
	var state: Dictionary = session.state()
	_check(session.enqueue_mutation(PackedInt32Array([index]), empty, "stale_doc", 0, state.generation, state.input_epoch), "Stale revision test was not queued")
	session.process_commands()
	_check(session.state().last_refusal == "stale_document_revision" and session.state().current_hash == before_bad.current_hash, "Stale document revision was applied")
	_check(not session.enqueue_mutation(PackedInt32Array([index]), empty, "stale_generation", state.document.revision, state.generation - 1, state.input_epoch), "Old generation admitted a mutation")
	_check(not session.enqueue_mutation(PackedInt32Array([index]), empty, "stale_input", state.document.revision, state.generation, state.input_epoch - 1), "Old input epoch admitted a mutation")
	var captured: Dictionary = host.capture_cells()
	var conflict: Dictionary = {"indices": PackedInt32Array([index]), "before": empty, "after": empty}
	var refused: Dictionary = host.apply_editor_patch(conflict, captured.revision, captured.tick)
	_check(not refused.ok and refused.error == "before_tuple_conflict", "Native adapter ignored expected before tuple")
	refused = host.apply_editor_patch({"indices": PackedInt32Array([index]), "before": exact, "after": empty}, captured.revision - 1, captured.tick)
	_check(not refused.ok and refused.error == "stale_native_revision_or_tick", "Native adapter ignored revision lease")
	_command(session, "undo")
	_mutate(session, PackedInt32Array([index]), Tools.cell_tuple(12, 99, 7, -32768), "branching_acid_edit")
	_check(session.state().document.redo_depth == 0 and _at(host, index) == Tools.cell_tuple(12, 99, 7, -32768), "New edit failed to retire redo or preserve signed thermal state")
	_receipts.exact_edit = {"initial_hash": initial.initial_hash, "edited_hash": changed.current_hash,
		"checks": "full tuples; no-op redo; reserved material; Water normalization; source aliases; native/doc/generation/input leases",
		"final": session.state()}
	host.free()
	await process_frame


func _run_and_first_tick_fence() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "sandbox")
	var index: int = 40 * 1024 + 40
	_mutate(session, PackedInt32Array([index]), Tools.cell_tuple(2, 11, 9, 777), "initial_sand")
	var authored_hash: String = session.state().current_hash
	_command(session, "speed", "0.25")
	_command(session, "run")
	_check(session.state().tick == 0 and session.state().document.locked and session.state().document.undo_depth == 1, "Run did not freeze and immediately disable Edit history before first tick")
	_command(session, "undo")
	_check(session.state().last_refusal == "history_requires_edit_at_zero" and session.state().current_hash == authored_hash, "Run at zero admitted history")
	for _frame: int in range(3):
		_check(session.advance_frame() == 0, "Quarter-speed pacing advanced too early")
	_check(session.state().document.undo_depth == 1 and not session.state().history_retired, "History was retired before actual first advancement")
	_check(session.advance_frame() == 1, "Quarter-speed pacing failed first fixed tick")
	_check(session.state().document.undo_depth == 0 and session.state().document.redo_depth == 0 and session.state().history_retired, "First actual advancement retained old history")
	_command(session, "toggle_pause")
	_command(session, "speed", "4")
	_command(session, "step")
	_check(session.advance_frame() == 1 and session.state().tick == 2 and session.state().paused, "Speed changed exact Step semantics")
	_command(session, "undo")
	_check(session.state().document.undo_depth == 0 and not session.state().document.can_undo, "Pause/rate change resurrected history")
	var frozen: Dictionary = session.frozen_definition()
	frozen.initial_cells[index * 5] = 1
	_check(session.frozen_definition().initial_cells[index * 5] == 2, "Frozen revision aliased caller memory")
	var before_intervention: Dictionary = session.state()
	_mutate(session, PackedInt32Array([index + 10]), Tools.cell_tuple(12, 123, 0, 345), "run_acid_intervention")
	var modified: Dictionary = session.state()
	_check(not modified.pristine and modified.intervention_count == 1 and modified.tick == before_intervention.tick,
		"Accepted Run intervention did not mark Modified without advancing time")
	_check(modified.document.cells_sha256 == authored_hash and modified.initial_hash == authored_hash, "Run intervention mutated frozen authoring state")
	var journal: Array = session.intervention_journal()
	_check(journal.size() == 1 and journal[0].after == Tools.cell_tuple(12, 123, 0, 345) and journal[0].tick == 2,
		"Run journal lost exact values/tick")
	journal[0].after[0] = 1
	_check(session.intervention_journal()[0].after[0] == 12, "Journal alias permitted mutation")
	_command(session, "reset")
	_check(session.state().current_hash == authored_hash and session.state().pristine and session.state().tick == 0 and not session.state().document.can_undo,
		"Reset did not reconstruct frozen authored state without old history")
	_command(session, "reset_edit")
	_check(session.state().mode == "edit" and session.state().document.undo_depth == 0 and session.state().document.redo_depth == 0
		and session.state().current_hash == authored_hash, "Reset & Edit did not start an empty exact tick-zero history")
	_receipts.first_tick_and_interventions = {"authored_hash": authored_hash, "modified": modified, "reset_edit": session.state()}
	host.free()
	await process_frame


func _partial_coupled_failure() -> void:
	var host: Variant = RefusingNativeHost.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "sandbox")
	_command(session, "template", "physics_pit")
	_mutate(session, PackedInt32Array([40 * 1024 + 40]), Tools.cell_tuple(6, 29, 3, 1900), "pre_run_fire")
	_check(session.state().document.undo_depth == 1, "Partial-fault setup lacked genuine Edit history")
	_command(session, "run")
	_check(not session.advance(), "Injected native refusal claimed complete coupled tick")
	var fault: Dictionary = session.state()
	_check(fault.mode == "fault" and fault.tick == 0 and fault.rapier_steps == 1 and fault.history_retired
		and fault.document.undo_depth == 0 and fault.document.redo_depth == 0,
		"Real Rapier-only advancement did not invalidate Edit history")
	_command(session, "undo")
	_check(session.state().mode == "fault" and session.state().rapier_steps == 1, "Fault admitted unsafe Undo")
	_command(session, "reset_edit")
	_check(session.state().tick == 0 and session.state().rapier_steps == 0 and session.state().document.undo_depth == 0,
		"Partial fault recovery resurrected old history")
	_receipts.labelled_native_refusal_after_real_rapier = fault
	host.free()
	await process_frame


func _chemistry_and_thermal() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "sandbox")
	# Steam lifetime 1 is an actual native chemical phase transition on the
	# next kernel update. Neighbouring heat remains authoritative signed data.
	var index: int = 100 * 1024 + 100
	var original: PackedByteArray = Tools.cell_tuple(22, 1, 0, 1500)
	_mutate(session, PackedInt32Array([index]), original, "steam_initial_condition")
	var thermal_index: int = 50 * 1024 + 150
	_mutate(session, PackedInt32Array([thermal_index]), Tools.cell_tuple(2, 0, 0, 777), "hot_sand_initial_condition")
	var authored_hash: String = session.state().current_hash
	_command(session, "undo")
	_check(_at(host, thermal_index) == Tools.cell_tuple(0, 0, 0, 200), "Thermal undo lost the original empty field")
	_command(session, "redo")
	_command(session, "undo")
	_command(session, "undo")
	_check(_at(host, index) == Tools.cell_tuple(0, 0, 0, 200), "Thermochemical Undo lost original temperature")
	_command(session, "redo")
	_check(_at(host, index) == original, "Thermochemical Redo lost lifetime/temperature")
	_command(session, "redo")
	_command(session, "run")
	_check(session.advance(), "Chemical test did not run a real native tick")
	_command(session, "toggle_pause")
	var evolved: PackedByteArray = _at(host, index)
	_check(evolved[0] == 3 and evolved != original, "Real Steam-to-Water phase transition was not observed")
	var thermal_from: Dictionary = Tools.tuple_values(_at(host, thermal_index))
	var thermal_to: Dictionary = Tools.tuple_values(_at(host, thermal_index + 1024))
	_check(thermal_from.temperature == 200 and thermal_to.id == 2 and thermal_to.temperature == 777, "Real native material transport did not move the authored thermal field")
	_check(session.state().document.cells_sha256 == authored_hash and session.state().document.undo_depth == 0,
		"Chemical evolution changed draft or left historical inverse edits available")
	_command(session, "reset_edit")
	_check(_at(host, index) == original and session.state().current_hash == authored_hash, "Reset & Edit tried to invert chemistry rather than reconstructing initial tuples")
	_receipts.actual_chemical_transition = {"initial": Tools.tuple_values(original), "evolved": Tools.tuple_values(evolved), "restored": Tools.tuple_values(_at(host, index)), "thermal_source_after_tick": thermal_from, "thermal_destination_after_tick": thermal_to}
	host.free()
	await process_frame


func _selection_fill_geometry() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "sandbox")
	var rectangle: PackedInt32Array = Tools.rectangle(Vector2i(10, 10), Vector2i(19, 19), true)
	_mutate(session, rectangle, _bridge.repeated_tuple(Tools.cell_tuple(2, 44, 55, -1234), rectangle.size()), "selection_source")
	var capture: Dictionary = host.capture_cells()
	var clip: PackedByteArray = _bridge.extract_rectangle(capture.cells, Rect2i(10, 10, 10, 10))
	var move: Dictionary = _bridge.selection_patch(capture.cells, Rect2i(10, 10, 10, 10), Rect2i(15, 10, 10, 10), clip, true)
	_check(move.ok, "Overlapping selection move refused")
	_mutate(session, move.indices, move.after, "overlap_move")
	_check(_at(host, 10 * 1024 + 10) == Tools.cell_tuple(0, 0, 0, 200) and _at(host, 10 * 1024 + 24) == Tools.cell_tuple(2, 44, 55, -1234), "Overlapping move destroyed exact tuples")
	_command(session, "undo")
	_check(session.state().current_hash == _digest(capture.cells), "Move undo was not one exact transaction")
	var bad: Dictionary = _bridge.selection_patch(capture.cells, Rect2i(), Rect2i(1020, 1020, 10, 10), clip, false)
	_check(not bad.ok, "Out-of-bounds paste clipped or partly applied")
	var filler: Variant = Tools.new()
	_check(filler.start_fill(capture.cells, Vector2i(12, 12)), "Category fill did not start")
	var result: Dictionary = {"done": false}
	var pumps: int = 0
	while not result.done and pumps < 200:
		result = filler.pump_fill(16, 1000)
		pumps += 1
	_check(result.done and result.indices.size() == 100 and result.indices == rectangle, "Fill did not find exactly the connected material category")
	_check(session.state().current_hash == _digest(capture.cells), "Fill preview mutated the native world")
	_mutate(session, result.indices, _bridge.repeated_tuple(Tools.cell_tuple(3, 255, 0, 200), result.indices.size()), "completed_fill")
	_check(session.state().document.undo_depth == 2, "Fill did not create one transaction")
	_command(session, "undo")
	_check(session.state().current_hash == _digest(capture.cells), "Fill undo did not restore all cell state and temperature")
	filler.start_fill(capture.cells, Vector2i(0, 0))
	filler.pump_fill(16, 1000)
	filler.cancel_fill()
	_check(not filler.pump_fill().active and session.state().current_hash == _digest(capture.cells), "Cancelled large fill mutated state")
	var footprint: Dictionary = {}
	Tools.stamp(footprint, Vector2i(50, 50), Vector2i(9, 9), "circle")
	_check(footprint.size() == 49, "Odd circle lost inherited radius-four lattice")
	footprint.clear()
	Tools.stamp(footprint, Vector2i(50, 50), Vector2i(2, 2), "square")
	_check(footprint.size() == 4 and footprint.has(50 * 1024 + 50) and footprint.has(51 * 1024 + 51), "Even footprint lost inherited positive-side convention")
	var line: PackedInt32Array = Tools.stroke([Vector2i(10, 40), Vector2i(20, 40)], Vector2i.ONE, "square")
	_check(line.size() == 11, "Sparse pointer path was not interpolated")
	_check(Tools.rectangle(Vector2i(1, 1), Vector2i(3, 3), false).size() == 8, "Rectangle outline is not exact")
	_receipts.selection_fill = {"fill_cells": result.indices.size(), "fill_pumps": pumps, "source_hash": _digest(capture.cells), "overlapping_move_undone": true, "cancelled_fill_unchanged": true}
	host.free()
	await process_frame


func _history_capacity() -> void:
	# Pure document-value capacity and alias refusal, backed by the same native
	# tuple planner. These checks do not claim physical simulation execution.
	var host: Variant = Host.new()
	root.add_child(host)
	var definition: Dictionary = SandfallSceneDefinitions.get_definition("blank")
	host.configure(definition)
	var document: Variant = Document.new(definition, host.capture_cells().cells)
	var all: PackedInt32Array = PackedInt32Array(range(1024 * 1024))
	var accepted: int = 0
	for material: int in [1, 2, 1, 2, 1]:
		var prepared: Dictionary = document.prepare(all, _bridge.repeated_tuple(Tools.cell_tuple(material, 0, 0, 200), all.size()), document.state().revision, "capacity_fixture")
		if prepared.ok:
			_check(document.commit(prepared), "Prepared model transaction failed to commit")
			accepted += 1
		else:
			_check(prepared.error == "history_capacity_refused_before_mutation", "Capacity test failed for an unrelated reason")
	_check(accepted == 4 and document.state().undo_depth == 4 and document.state().revision == 4, "History capacity was not enforced before mutation")
	var history: Dictionary = document.prepare_history("undo")
	history.after[0] = 10
	_check(not document.commit(history) and document.state().revision == 4, "Tampered prepared history was committed")
	var fresh: Variant = Document.new(definition, host.capture_cells().cells)
	var forged_cost: Dictionary = fresh.prepare(PackedInt32Array([0]), Tools.cell_tuple(2, 0, 0, 200), 0, "cost_tamper")
	forged_cost.cost = -999999
	_check(fresh.commit(forged_cost) and fresh.state().history_bytes == 14, "Public patch metadata corrupted private history accounting")
	_receipts.model_capacity = {"accepted_full_world_transactions": accepted, "history_bytes": document.state().history_bytes, "limit": Document.MAX_HISTORY_BYTES}
	host.free()
	await process_frame


func _full_world_and_offscreen() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "sandbox")
	var index: int = 900 * 1024 + 900
	_mutate(session, PackedInt32Array([index]), Tools.cell_tuple(2, 0, 0, 999), "outside_initial_camera")
	var authored_hash: String = session.state().current_hash
	_command(session, "run")
	_check(session.advance(), "Full authored world refused actual native tick")
	var moved: Dictionary = Tools.tuple_values(_at(host, index + 1024))
	_check(moved.id == 2 and moved.temperature == 999, "Authoring outside the initial camera did not participate in native simulation")
	_command(session, "reset_edit")
	_check(session.state().current_hash == authored_hash, "Offscreen thermal authoring was not reset exactly")
	_command(session, "template", "blank")
	var initial: String = session.state().current_hash
	var snapshot: Dictionary = host.capture_cells()
	var filler: Variant = Tools.new()
	filler.start_fill(snapshot.cells, Vector2i(0, 0))
	var result: Dictionary = {"done": false}
	var pumps: int = 0
	while not result.done and pumps < 20000:
		result = filler.pump_fill()
		pumps += 1
	_check(result.done and result.indices.size() == 1024 * 1024, "Full-world bounded fill did not terminate with all cells exactly once")
	if result.done:
		_mutate(session, result.indices, _bridge.repeated_tuple(Tools.cell_tuple(1, 7, 8, 321), result.indices.size()), "full_world_fill")
		_check(session.state().document.undo_depth == 1 and session.state().last_edit.cells == 1024 * 1024 and session.state().tick == 0,
			"Actual native full-world batch failed single-transaction/zero-tick contract")
		_check(_at(host, 0) == Tools.cell_tuple(1, 7, 8, 321) and _at(host, 1024 * 1024 - 1) == Tools.cell_tuple(1, 7, 8, 321), "Full-world batch lost boundary tuples")
		_command(session, "undo")
		_check(session.state().current_hash == initial, "Full-world undo lost initial native state")
	_receipts.full_world = {"fill_pumps": pumps, "fill_cells": result.get("indices", []).size(), "offscreen_moved_tuple": moved, "reset_hash": session.state().current_hash}
	host.free()
	await process_frame


func _read_only_coupling_snapshot() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "sandbox")
	_command(session, "template", "physics_pit")
	var native: Variant = host._native_world # Internal native integration observation, never browser acceptance.
	var before_revision: int = native.get_revision()
	var before_feedback: PackedFloat32Array = native.rigid_body_results().duplicate()
	var before_material: int = native.material_at(124, 90)
	var capture: Dictionary = host.capture_cells()
	var candidate: Dictionary = _bridge.plan_patch(capture.cells, PackedInt32Array([90 * 1024 + 124]), Tools.cell_tuple(2, 0, 0, 200))
	var refused: Dictionary = host.apply_editor_patch(candidate, capture.revision, capture.tick)
	_check(not refused.ok and refused.error == "body_occupancy_conflict", "Pure snapshot lost the actual initial Rapier occupancy mask")
	_check(native.get_revision() == before_revision and native.material_at(124, 90) == before_material and native.rigid_body_results() == before_feedback,
		"Snapshot or occupied-cell refusal changed native revision, occupancy view or feedback")
	_check(session.state().tick == 0 and session.state().rapier_steps == 0, "Initial occupancy/snapshot validation stepped physics")
	_receipts.read_only_snapshot = {"revision_before": before_revision, "revision_after": native.get_revision(), "occupied_cell_refusal": refused.error, "feedback_unchanged": native.rigid_body_results() == before_feedback}
	host.free()
	await process_frame


func _mutate(session: Variant, indices: PackedInt32Array, desired: PackedByteArray, kind: String) -> void:
	var state: Dictionary = session.state()
	_check(session.enqueue_mutation(indices, desired, kind, int(state.document.revision), int(state.generation), int(state.input_epoch)), "Mutation could not be queued: " + kind)
	session.process_commands()


func _at(host: Variant, index: int) -> PackedByteArray:
	return PackedByteArray(host.capture_cells().cells).slice(index * 5, index * 5 + 5)


func _command(session: Variant, action: String, value: String = "") -> void:
	session.enqueue(action, value)
	session.process_commands()


func _digest(bytes: PackedByteArray) -> String:
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(message)
		print("SF_M2_FAILURE ", message)


func _finish() -> void:
	print("SANDFALL_AUTHORING_TEST ", JSON.stringify({"ok": _failures.is_empty(), "checks": _checks, "failures": _failures, "receipts": _receipts}))
	quit(0 if _failures.is_empty() else 1)
