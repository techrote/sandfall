class_name SandfallSessionController
extends RefCounted

# Application lifecycle authority. Initial values and the live solver are
# separate owners. No history, actor input, archive or editor tool is implied.
signal reconstructed
signal input_retired(reason: String)

const MAX_COMMANDS: int = 32
const MAX_JOURNAL: int = 64

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


func enqueue(action: String, value: String = "", expected_generation: int = -1) -> bool:
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
		_apply(str(command.action), str(command.value))


func advance() -> bool:
	if _mode != "run" or _menu or not bool(_host.state().ready):
		return false
	if _paused and _pending_steps == 0:
		return false
	var receipt: Dictionary = _host.tick_once()
	if bool(receipt.get("fault", false)):
		# One solver may already have advanced. Preserve those actual counters,
		# retire the old editing/input epoch, and never claim rollback.
		_mode = "fault"
		_paused = true
		_history_retired = true
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


func clear_pending_input(reason: String) -> void:
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
		"history_supported": false, "pristine": true,
		"simulation_interest": native.simulation_interest,
		"error": str(native.error), "last_refusal": _last_refusal,
		"native": native, "journal": _journal.duplicate(true),
	}


func initial_definition() -> Dictionary:
	return _initial.duplicate(true)


func frozen_definition() -> Dictionary:
	return _frozen.duplicate(true)


func _apply(action: String, value: String) -> void:
	match action:
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
			_install(_initial, "run", false)
		"toggle_pause":
			if _mode != "run" or not bool(_host.state().ready) or _menu:
				_refuse("pause_requires_ready_run")
				return
			_paused = not _paused
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
			var recipe: Dictionary = _frozen if not _frozen.is_empty() else _initial
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


func _install(definition: Dictionary, mode: String, paused: bool) -> void:
	# Copy before retiring either previous owner: callers can pass our frozen
	# recipe, but no live session keeps a reference to the editable dictionary.
	var accepted: Dictionary = definition.duplicate(true)
	_generation += 1
	clear_pending_input("session_replaced")
	_menu = false
	_paused = true
	_initial = accepted.duplicate(true)
	_frozen = accepted.duplicate(true) if mode == "run" else {}
	_definition_hash = _hash_definition(accepted)
	_history_retired = mode == "run"
	if mode == "edit":
		_edit_epoch += 1
	var installed: Dictionary = _host.configure(accepted)
	_mode = mode if bool(installed.ready) else "fault"
	_paused = paused if bool(installed.ready) else true
	if _mode == "fault":
		_history_retired = true
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
	hashing.update(var_to_bytes(definition))
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
