class_name SandfallSessionController
extends RefCounted

# Application lifecycle authority. Initial values and the live solver are
# separate owners. Edit history belongs to the logical document, never physics.
signal document_changed
signal reconstructed
signal input_retired(reason: String)

const MAX_COMMANDS: int = 32
const MAX_JOURNAL: int = 64
const MAX_INTERVENTIONS: int = 256
const MAX_INTERVENTION_BYTES: int = 32 * 1024 * 1024

var _document: SandfallAuthoringDocument
var _pristine: bool = true
var _tool_hold: bool = false
var _speed: float = 1.0
var _tick_credit: float = 0.0
var _interventions: Array[Dictionary] = []
var _intervention_bytes: int = 0
var _sequence: int = 0
var _mutation_count: int = 0
var _last_edit: Dictionary = {}
var _source_identity: Dictionary = {}
var _host: Node
var _entry: String = "home"
var _mode: String = "edit"
var _paused: bool = true
var _menu: bool = false
var _generation: int = 0
var _input_epoch: int = 0
var _initial: Dictionary = {}
var _frozen: Dictionary = {}
var _commands: Array[Dictionary] = []
var _pending_steps: int = 0
var _history_retired: bool = false
var _edit_epoch: int = 0
var _current_hash: String = ""
var _hash_tick: int = 0
var _definition_hash: String = ""
var _last_refusal: String = ""
var _journal: Array[Dictionary] = []


func _init(host: Node) -> void:
	_host = host


func enqueue(action: String, value: Variant = "", expected_generation: int = -1) -> bool:
	if action not in ["gallery", "sandbox", "template", "run", "toggle_pause", "step", "reset", "reset_edit", "menu", "continue", "speed", "undo", "redo"] or not value is String or str(value).length() > 128:
		return _refuse("malformed_or_untyped_command")
	var generation: int = _generation if expected_generation < 0 else expected_generation
	if generation != _generation:
		return _refuse("stale_generation")
	if _commands.size() >= MAX_COMMANDS:
		return _refuse("command_capacity")
	if action == "step":
		if _mode != "run" or not _paused or _menu or not bool(_host.state().ready):
			return _refuse("step_requires_ready_paused_run")
		if _pending_steps > 0:
			return _refuse("step_already_pending")
		for command: Dictionary in _commands:
			if command.action == "step":
				return _refuse("step_already_queued")
	_commands.append({"action": action, "value": value, "generation": generation, "input_epoch": _input_epoch})
	return true


func process_commands() -> void:
	var batch: Array[Dictionary] = _commands.duplicate(true)
	_commands.clear()
	for command: Dictionary in batch:
		if int(command.generation) != _generation or int(command.input_epoch) != _input_epoch:
			_refuse("retired_command_epoch")
			continue
		_apply(str(command.action), command.value)


func advance() -> bool:
	if _mode != "run" or _menu or _tool_hold or not bool(_host.state().ready):
		return false
	if _paused and _pending_steps == 0:
		return false
	var receipt: Dictionary = _host.tick_once()
	if bool(receipt.get("advanced", false)) or int(receipt.get("native_delta", 0)) > 0 or int(receipt.get("rapier_delta", 0)) > 0:
		_retire_history()
	if bool(receipt.get("fault", false)):
		# One solver may already have advanced. Preserve those actual counters,
		# retire the old editing/input epoch, and never claim rollback.
		_mode = "fault"
		_paused = true
		_retire_history()
		clear_pending_input("fault")
		_record("fault", str(receipt.get("error", "solver failure")))
		return false
	if not bool(receipt.get("advanced", false)):
		return false # Terrain readiness retains the single pending Step.
	_history_retired = true
	if _pending_steps > 0:
		_pending_steps = 0
		_refresh_hash()
	return true


func advance_frame() -> int:
	if _mode != "run" or _menu or _tool_hold or not bool(_host.state().ready):
		_tick_credit = 0.0
		return 0
	if _paused:
		_tick_credit = 0.0
		return 1 if advance() else 0
	_tick_credit += _speed
	var completed: int = 0
	for _request: int in range(mini(4, int(_tick_credit))):
		if not advance():
			_tick_credit = 0.0
			break
		completed += 1
		_tick_credit -= 1.0
	return completed


func clear_pending_input(reason: String) -> void:
	_tool_hold = false
	_tick_credit = 0.0
	_input_epoch += 1
	_pending_steps = 0
	_commands.clear()
	input_retired.emit(reason)


func focus_lost() -> void:
	if _mode == "run":
		_paused = true
		_refresh_hash()
	clear_pending_input("focus_lost")


func state() -> Dictionary:
	var native: Dictionary = _host.state()
	return {
		"entry": _entry, "mode": _mode, "paused": _paused, "menu": _menu,
		"ready": bool(native.ready), "generation": _generation, "input_epoch": _input_epoch,
		"scene_id": str(_initial.get("id", "")),
		"definition_hash": _definition_hash,
		"initial_hash": str(native.initial_material_sha256),
		"current_hash": _current_hash, "material_hash_tick": _hash_tick,
		"tick": int(native.native_tick), "rapier_steps": int(native.rapier_steps),
		"rapier_active": bool(native.bridge_active),
		"rapier_available": bool(native.rapier_available), "workers": int(native.workers),
		"body_poses": native.body_states, "initial_body_poses": native.initial_body_states,
		"moves": int(native.get("moves_total", 0)),
		"contacts_total": int(native.contacts_total), "displaced_total": int(native.displaced_total),
		"pending_steps": _pending_steps, "queued_commands": _commands.size(),
		"history_retired": _history_retired, "edit_epoch": _edit_epoch,
		"history_supported": true, "pristine": _pristine,
		"document": _document.state() if _document != null else {},
		"tool_busy": _tool_hold, "speed": _speed, "mutation_count": _mutation_count,
		"intervention_count": _interventions.size(), "intervention_bytes": _intervention_bytes,
		"last_edit": _last_edit.duplicate(true),
		"simulation_interest": native.simulation_interest,
		"error": str(native.error), "last_refusal": _last_refusal,
		"native": native, "journal": _journal.duplicate(true),
	}


func initial_definition() -> Dictionary:
	return _document.snapshot() if _mode == "edit" and _document != null else _copy_definition(_initial)


func frozen_definition() -> Dictionary:
	return _copy_definition(_frozen)


func _apply(action: String, value: Variant) -> void:
	match action:
		"speed":
			if str(value) not in ["0.25", "0.5", "1", "2", "4"]:
				_refuse("unsupported_speed")
				return
			_speed = float(value)
			_tick_credit = 0.0
			_record("speed", str(value))
		"mutation":
			_apply_mutation(value)
		"undo", "redo":
			_apply_history(action)
		"gallery", "sandbox":
			_entry = action
			var selected: String = "physics_pit" if action == "gallery" else "blank"
			_install(SandfallSceneDefinitions.get_definition(selected), "run" if action == "gallery" else "edit", action != "gallery")
		"template":
			if _entry == "home" or value not in SandfallSceneDefinitions.ids():
				_refuse("unknown_template_or_entry")
				return
			_install(SandfallSceneDefinitions.get_definition(value), "run" if _entry == "gallery" else "edit", _entry != "gallery")
		"run":
			if _mode != "edit" or not bool(_host.state().ready) or _menu:
				_refuse("run_requires_ready_edit")
				return
			_install(_document.snapshot(), "run", false, true)
		"toggle_pause":
			if _mode != "run" or not bool(_host.state().ready) or _menu:
				_refuse("pause_requires_ready_run")
				return
			_paused = not _paused
			_tick_credit = 0.0
			_pending_steps = 0
			if _paused:
				_refresh_hash()
			_record("pause" if _paused else "resume")
		"step":
			if _mode == "run" and _paused and not _menu and bool(_host.state().ready):
				_pending_steps = 1
				_record("step_requested")
			else:
				_refuse("step_requires_ready_paused_run")
		"reset", "reset_edit":
			if _initial.is_empty():
				_refuse("reset_requires_scene")
				return
			var recipe: Dictionary = _frozen if not _frozen.is_empty() else (_document.snapshot() if _document != null else _initial)
			var target_mode: String = "edit" if action == "reset_edit" or _mode == "edit" else "run"
			_install(recipe, target_mode, target_mode == "edit" or _entry != "gallery")
		"menu":
			_menu = true
			clear_pending_input("menu_open")
			_refresh_hash()
			_record("menu_open")
		"continue":
			_menu = false
			clear_pending_input("menu_closed")
			_record("menu_closed")
		_:
			_refuse("unknown_command")


func _install(definition: Dictionary, mode: String, paused: bool, retain_document: bool = false) -> void:
	# Copy before retiring either previous owner: callers can pass our frozen
	# recipe, but no live session keeps a reference to the editable dictionary.
	var accepted: Dictionary = _copy_definition(definition)
	_generation += 1
	clear_pending_input("session_replaced")
	_menu = false
	_paused = true
	_initial = _copy_definition(accepted)
	_frozen = _copy_definition(accepted) if mode == "run" else {}
	_pristine = true
	_interventions.clear()
	_intervention_bytes = 0
	_last_edit = {}
	_definition_hash = _hash_definition(accepted)
	_history_retired = false
	if mode == "edit":
		_edit_epoch += 1
	var installed: Dictionary = _host.configure(accepted)
	if bool(installed.ready):
		if not retain_document:
			var captured: Dictionary = _host.capture_cells()
			_document = SandfallAuthoringDocument.new(accepted, captured.get("cells", PackedByteArray()))
		if mode == "run" and _document != null:
			_document.lock_for_run()
	if _document != null and _document.valid():
		_definition_hash = _hash_definition(_document.snapshot())
	_mode = mode if bool(installed.ready) and _document != null and _document.valid() else "fault"
	_paused = paused if bool(installed.ready) else true
	if _mode == "fault":
		_retire_history()
	_refresh_hash()
	_record("install", str(accepted.get("id", "")))
	reconstructed.emit()


func _refresh_hash() -> void:
	_current_hash = _host.material_identity()
	_hash_tick = int(_host.state().native_tick)


func _hash_definition(definition: Dictionary) -> String:
	# A process/toolchain-local initial-value identity, not a portable archive
	# codec or a promise of complete deterministic replay.
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	var logical: Dictionary = _copy_definition(definition)
	logical.erase("authored_revision")
	logical.erase("authored_cells_sha256")
	hashing.update(var_to_bytes(logical))
	return hashing.finish().hex_encode()


func _refuse(reason: String) -> bool:
	_last_refusal = reason
	_record("refused", reason)
	return false


func _record(action: String, detail: String = "") -> void:
	_journal.append({"action": action, "detail": detail, "generation": _generation,
		"native_tick": int(_host.state().native_tick), "rapier_steps": int(_host.state().rapier_steps)})
	if _journal.size() > MAX_JOURNAL:
		_journal.pop_front()


func set_source_identity(identity: Dictionary) -> void:
	_source_identity = {"source_commit": str(identity.get("source_commit", "local-unpublished")),
		"native_sha256": str(identity.get("sha256", "unattested"))}


func authoring_cells() -> PackedByteArray:
	return _document.cells_copy() if _document != null else PackedByteArray()


func editing_snapshot() -> Dictionary:
	if _mode == "edit" and _document != null:
		return {"ok": true, "cells": _document.cells_copy(), "revision": _document.state().revision}
	if _mode == "run" and bool(_host.state().ready):
		return _host.capture_cells()
	return {"ok": false, "error": "scene_not_editable"}


func begin_tool_hold(generation: int, epoch: int) -> bool:
	if generation != _generation or epoch != _input_epoch or _menu or _mode == "fault" or not bool(_host.state().ready):
		return _refuse("stale_or_unavailable_tool_session")
	_tool_hold = true
	return true


func end_tool_hold() -> void:
	_tool_hold = false


func enqueue_mutation(indices: PackedInt32Array, desired: PackedByteArray, kind: String,
		expected_revision: int, generation: int, epoch: int) -> bool:
	if generation != _generation or epoch != _input_epoch or _menu or _mode not in ["edit", "run"]:
		return _refuse("retired_or_wrong_mode_mutation")
	if indices.is_empty() or indices.size() > 1024 * 1024 or desired.size() != indices.size() * 5:
		return _refuse("invalid_mutation_size")
	for command: Dictionary in _commands:
		if command.action == "mutation":
			return _refuse("mutation_already_queued")
	if _commands.size() >= MAX_COMMANDS or kind.is_empty() or kind.length() > 64:
		return _refuse("mutation_command_capacity_or_kind")
	_commands.append({"action": "mutation", "value": {"indices": indices.duplicate(), "desired": desired.duplicate(),
		"kind": kind, "revision": expected_revision}, "generation": generation, "input_epoch": epoch})
	return true


func intervention_journal() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in _interventions:
		var copy: Dictionary = entry.duplicate(true)
		copy.indices = PackedInt32Array(entry.indices).duplicate()
		copy.after = PackedByteArray(entry.after).duplicate()
		out.append(copy)
	return out


func _apply_mutation(intent: Dictionary) -> void:
	if _menu or _mode not in ["edit", "run"] or not bool(_host.state().ready):
		_refuse("mutation_requires_ready_owner")
		return
	var capture: Dictionary = _host.capture_cells()
	if not bool(capture.ok):
		_refuse(str(capture.error))
		return
	var patch: Dictionary
	if _mode == "edit":
		if int(capture.tick) != 0 or int(_host.state().rapier_steps) != 0:
			_refuse("edit_requires_both_solvers_at_zero")
			return
		patch = _document.prepare(intent.indices, intent.desired, int(intent.revision), str(intent.kind))
	else:
		patch = _host.plan_editor_patch(capture.cells, intent.indices, intent.desired)
	if not bool(patch.ok):
		_refuse(str(patch.error))
		return
	var cost: int = patch.indices.size() * 9
	if _mode == "run" and (_interventions.size() >= MAX_INTERVENTIONS or _intervention_bytes + cost > MAX_INTERVENTION_BYTES):
		_refuse("intervention_journal_capacity")
		return
	var receipt: Dictionary = _host.apply_editor_patch(patch, int(capture.revision), int(capture.tick))
	if not bool(receipt.ok):
		_handle_edit_refusal(receipt)
		return
	if _mode == "edit":
		if not _document.commit(patch):
			_handle_edit_refusal({"ok": false, "partial": true, "error": "document_commit_conflict"})
			return
		_definition_hash = _hash_definition(_document.snapshot())
	else:
		_pristine = false
		_sequence += 1
		_interventions.append({"sequence": _sequence, "tick": int(capture.tick),
			"generation": _generation, "kind": str(intent.kind), "accepted": true,
			"source": _source_identity.duplicate(true), "indices": PackedInt32Array(patch.indices).duplicate(),
			"after": PackedByteArray(patch.after).duplicate()})
		_intervention_bytes += cost
	_mutation_count += 1
	_last_refusal = ""
	_last_edit = {"kind": str(intent.kind), "cells": patch.indices.size(), "mode": _mode,
		"tick": int(capture.tick), "native_revision": int(receipt.revision), "accepted": true}
	_refresh_hash()
	document_changed.emit()


func _apply_history(direction: String) -> void:
	if _mode != "edit" or _menu or _document == null or int(_host.state().native_tick) != 0 or int(_host.state().rapier_steps) != 0:
		_refuse("history_requires_edit_at_zero")
		return
	var patch: Dictionary = _document.prepare_history(direction)
	if not bool(patch.ok):
		_refuse(str(patch.error))
		return
	var capture: Dictionary = _host.capture_cells()
	if not bool(capture.ok):
		_refuse(str(capture.error))
		return
	var receipt: Dictionary = _host.apply_editor_patch(patch, int(capture.revision), int(capture.tick))
	if not bool(receipt.ok):
		_handle_edit_refusal(receipt)
		return
	if not _document.commit(patch):
		_handle_edit_refusal({"ok": false, "partial": true, "error": "document_commit_conflict"})
		return
	_last_refusal = ""
	_definition_hash = _hash_definition(_document.snapshot())
	_last_edit = {"kind": direction, "cells": patch.indices.size(), "mode": "edit", "tick": 0, "accepted": true}
	_refresh_hash()
	document_changed.emit()


func _handle_edit_refusal(receipt: Dictionary) -> void:
	if bool(receipt.get("partial", false)):
		_mode = "fault"
		_paused = true
		_retire_history()
		clear_pending_input("partial_edit_fault")
	_refuse(str(receipt.error))


func _retire_history() -> void:
	_history_retired = true
	if _document != null:
		_document.retire_history()


static func _copy_definition(value: Dictionary) -> Dictionary:
	var copy: Dictionary = value.duplicate(true)
	if copy.has("rectangles"):
		copy.rectangles = PackedInt32Array(value.rectangles).duplicate()
	if copy.has("initial_cells"):
		copy.initial_cells = PackedByteArray(value.initial_cells).duplicate()
	return copy
