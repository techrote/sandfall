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
const MAX_DIAGNOSTIC_PARAMETER_BYTES: int = 16 * 1024
const Archive = preload("res://scripts/sandfall/archive_codec.gd")
const Presentation = preload("res://scripts/sandfall/presentation_model.gd")
const Promotion = preload("res://scripts/sandfall/intervention_promotion.gd")

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
# Monotone for this application owner, including after undo/deletion/reset.
# Reconstruction may restore a previous ID; allocation never reissues one.
var _next_object_serial: int = 1
var _editable_initial_body_poses: Array = []
var _run_presentation: Dictionary = Presentation.defaults()
var _promotion: Dictionary = {}
var _promotion_serial: int = 0
var _event_sequence: int = 0
var _journal_dropped: int = 0
var _project_identity_cache: Dictionary = {}
var _project_identity_revision: int = -1
var _command_context: Dictionary = {}


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
		_command_context = _command_summary(command)
		if int(command.generation) != _generation or int(command.input_epoch) != _input_epoch:
			_refuse("retired_command_epoch")
			continue
		_apply(str(command.action), command.value)
	_command_context = {}


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
	_promotion.clear()
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
		"project": _document.project_metadata() if _document != null else {},
		"presentation": presentation(),
		"promotion_pending": not _promotion.is_empty(),
		"definition_hash": _definition_hash,
		"initial_hash": str(native.initial_material_sha256),
		"current_hash": _current_hash, "material_hash_tick": _hash_tick,
		"tick": int(native.native_tick), "rapier_steps": int(native.rapier_steps),
		"rapier_active": bool(native.bridge_active),
		"rapier_available": bool(native.rapier_available), "workers": int(native.workers),
		"body_poses": native.body_states, "initial_body_poses": _editable_initial_body_poses.duplicate(true) if _mode == "edit" else native.initial_body_states,
		"body_ids": native.get("body_ids", []),
		"object_definitions": SandfallRapierObjectRegistry.logical_graph(object_definitions()),
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
		"object_edit":
			_apply_object_edit(value)
		"presentation":
			_apply_presentation(value)
		"undo", "redo":
			_apply_history(action)
		"gallery", "sandbox":
			_entry = action
			var selected: String = (str(value) if not str(value).is_empty() else "physics_pit") if action == "gallery" else "blank"
			if selected not in SandfallSceneDefinitions.ids():
				_refuse("unknown_gallery_scene")
				return
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
	_project_identity_cache.clear()
	_project_identity_revision = -1
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
		# An accepted zero-tick preview is the projection of the authored graph.
		# Preserve it independently so later accidental drift remains observable.
		_editable_initial_body_poses = installed.body_states.duplicate(true) if mode == "edit" else []
		for object_definition: Dictionary in _host.get_object_definitions():
			_next_object_serial = maxi(_next_object_serial, int(object_definition.creation_order) + 1)
			# Logical reconstruction permits IDs independent of creation order.
			# Reserve any canonical allocator ID already observed, even if that
			# object is deleted before our monotonically increasing counter reaches it.
			var id: String = str(object_definition.id)
			var suffix: String = id.trim_prefix("sf-box-")
			if id.begins_with("sf-box-") and suffix.length() <= 10 and suffix.is_valid_int():
				var observed_serial: int = suffix.to_int()
				if observed_serial >= 1 and observed_serial <= SandfallRapierObjectRegistry.MAX_CREATION_ORDER \
						and str(observed_serial) == suffix:
					_next_object_serial = maxi(_next_object_serial, observed_serial + 1)
		if not retain_document:
			var captured: Dictionary = _host.capture_cells()
			_document = SandfallAuthoringDocument.new(accepted, captured.get("cells", PackedByteArray()))
		if mode == "run" and _document != null:
			_document.lock_for_run()
	if _document != null and _document.valid():
		_initial = _document.snapshot()
		_frozen = _copy_definition(_initial) if mode == "run" else {}
		_run_presentation = _document.presentation_copy()
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


func _record(action: String, detail: String = "", parameters: Dictionary = {}) -> void:
	_event_sequence += 1
	var context: Dictionary = _command_context.duplicate(true)
	if not parameters.is_empty():
		context.merge(parameters, true)
	_journal.append({"sequence": _event_sequence, "action": action, "detail": detail, "generation": _generation,
		"input_epoch": _input_epoch, "accepted": action not in ["refused", "partial_mutation", "fault"],
		"source": source_identity(), "command": context,
		"native_tick": int(_host.state().native_tick), "rapier_steps": int(_host.state().rapier_steps)})
	if _journal.size() > MAX_JOURNAL:
		_journal.pop_front()
		_journal_dropped += 1


func _command_summary(command: Dictionary) -> Dictionary:
	var action: String = str(command.action)
	var result: Dictionary = {"command_class": action, "requested_generation": command.generation,
		"requested_input_epoch": command.input_epoch}
	var value: Variant = command.value
	if action == "mutation":
		result["kind"] = value.kind
		result["requested_cells"] = value.indices.size()
		result["indices_sha256"] = Archive.sha256(value.indices.to_byte_array())
		result["tuples_sha256"] = Archive.sha256(value.desired)
		result["parameter_encoding"] = "sha256 of little-endian i32 indices and five-byte tuples; accepted values in interventions"
	else:
		var logical: Variant = _evidence_value(value)
		var bytes: PackedByteArray = JSON.stringify(logical, "", true, true).to_utf8_buffer()
		result["parameters_sha256"] = Archive.sha256(bytes)
		result["parameters_bytes"] = bytes.size()
		result["parameters_truncated"] = bytes.size() > MAX_DIAGNOSTIC_PARAMETER_BYTES
		if bytes.size() <= MAX_DIAGNOSTIC_PARAMETER_BYTES:
			result["parameters"] = logical
	return result


static func _evidence_value(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i:
		return [value.x, value.y]
	if value is float and not is_finite(value):
		return {"invalid_number": "nonfinite"}
	if value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in value:
			out[str(key)] = _evidence_value(value[key])
		return out
	if value is Array:
		var out: Array = []
		for item: Variant in value:
			out.append(_evidence_value(item))
		return out
	return value


func set_source_identity(identity: Dictionary) -> void:
	_source_identity = Archive.local_source_identity()
	for key: String in _source_identity:
		if identity.has(key):
			_source_identity[key] = identity[key]
	if not identity.has("native_runtime_sha256") and identity.has("sha256"):
		_source_identity.native_runtime_sha256 = str(identity.sha256)
	_project_identity_cache.clear()


func source_identity() -> Dictionary:
	return Archive.local_source_identity() if _source_identity.is_empty() else _source_identity.duplicate(true)


func authored_project() -> Dictionary:
	# Even a Gallery recipe is captured as exact initial tuples at setup. The
	# locked document continues to own those values throughout an evolved Run.
	return _document.snapshot() if _document != null and _document.valid() else {}


func project_identity() -> Dictionary:
	if _document == null or not _document.valid():
		return {"ok": false, "error": "no_authored_project"}
	var revision: int = int(_document.state().revision)
	if _project_identity_cache.is_empty() or _project_identity_revision != revision:
		_project_identity_cache = Archive.canonical_identity(authored_project(), source_identity())
		_project_identity_revision = revision
	return _project_identity_cache.duplicate(true)


func set_modal_open(open: bool) -> void:
	_menu = open
	clear_pending_input("project_modal_open" if open else "project_modal_closed")
	_record("project_modal_open" if open else "project_modal_closed")


func import_project(candidate: Dictionary, expected_generation: int, expected_epoch: int) -> Dictionary:
	if expected_generation != _generation or expected_epoch != _input_epoch:
		return _project_refusal("retired_project_import")
	var checked: Dictionary = Archive.validate_definition(candidate, source_identity())
	if not bool(checked.ok):
		return _project_refusal(str(checked.error))
	# Validation, native construction, Rapier construction, collider readiness
	# and copied document allocation all precede retirement of the active owner.
	var definition: Dictionary = checked.definition
	var document: SandfallAuthoringDocument = SandfallAuthoringDocument.new(definition, definition.initial_cells)
	if not document.valid():
		return _project_refusal("candidate_document_invalid")
	var staged: Dictionary = _host.stage_project(definition)
	if not bool(staged.ok):
		return _project_refusal(str(staged.error))
	var projection: Dictionary = staged.candidate.capture_cells()
	if not bool(projection.ok) or projection.cells != definition.initial_cells:
		staged.candidate.free()
		return _project_refusal("candidate_initial_projection_mismatch")
	var installed: Dictionary = _host.commit_staged_project(staged.candidate)
	if not bool(installed.ok):
		if is_instance_valid(staged.candidate):
			staged.candidate.free()
		if bool(installed.get("partial", false)):
			_handle_edit_refusal(installed)
		return _project_refusal(str(installed.error), bool(installed.get("partial", false)))
	_document = document
	_generation += 1
	clear_pending_input("project_installed")
	_menu = false
	_mode = "run" if str(definition.project.startup) == "run_autoplay" else "edit"
	_entry = "gallery" if _mode == "run" else "sandbox"
	_paused = _mode == "edit"
	_pristine = true
	_history_retired = false
	_interventions.clear()
	_intervention_bytes = 0
	_last_edit = {}
	_last_refusal = ""
	_initial = _document.snapshot()
	_frozen = _copy_definition(_initial) if _mode == "run" else {}
	_run_presentation = _document.presentation_copy()
	if _mode == "run":
		_document.lock_for_run()
	else:
		_edit_epoch += 1
	_editable_initial_body_poses = installed.state.body_states.duplicate(true) if _mode == "edit" else []
	_reserve_object_ids()
	_definition_hash = _hash_definition(_initial)
	_project_identity_cache.clear()
	_project_identity_revision = -1
	_refresh_hash()
	_record("project_import", str(definition.id))
	reconstructed.emit()
	document_changed.emit()
	return {"ok": true, "accepted": true, "error": "", "generation": _generation,
		"mode": _mode, "tick": 0, "partial": false}


func _reserve_object_ids() -> void:
	for definition: Dictionary in _host.get_object_definitions():
		_next_object_serial = maxi(_next_object_serial, int(definition.creation_order) + 1)
		var id: String = str(definition.id)
		var suffix: String = id.trim_prefix("sf-box-")
		if id.begins_with("sf-box-") and suffix.length() <= 10 and suffix.is_valid_int():
			var serial: int = suffix.to_int()
			if serial >= 1 and serial <= SandfallRapierObjectRegistry.MAX_CREATION_ORDER and str(serial) == suffix:
				_next_object_serial = maxi(_next_object_serial, serial + 1)


func presentation() -> Dictionary:
	if _mode == "edit" and _document != null:
		return _document.presentation_copy()
	return _run_presentation.duplicate(true)


func enqueue_presentation(value: Dictionary, expected_revision: int, generation: int, epoch: int) -> bool:
	if generation != _generation or epoch != _input_epoch or _menu or _mode not in ["edit", "run"]:
		return _refuse("retired_or_wrong_mode_presentation")
	var checked: Dictionary = Presentation.validate(value)
	if not bool(checked.ok):
		return _refuse(str(checked.error))
	for command: Dictionary in _commands:
		if command.action in ["mutation", "object_edit", "presentation"]:
			return _refuse("mutation_already_queued")
	if _commands.size() >= MAX_COMMANDS:
		return _refuse("command_capacity")
	_commands.append({"action": "presentation", "value": {"value": checked.presentation,
		"revision": expected_revision}, "generation": generation, "input_epoch": epoch})
	return true


func _apply_presentation(intent: Dictionary) -> void:
	if _menu or _mode not in ["edit", "run"] or not bool(_host.state().ready):
		_refuse("presentation_requires_ready_owner")
		return
	if _mode == "edit":
		if int(_host.state().native_tick) != 0 or int(_host.state().rapier_steps) != 0:
			_refuse("edit_requires_both_solvers_at_zero")
			return
		var patch: Dictionary = _document.prepare_presentation(intent.value, int(intent.revision))
		if not bool(patch.ok):
			_refuse(str(patch.error))
			return
		if not _document.commit(patch):
			_refuse("presentation_document_commit_conflict")
			return
		_definition_hash = _hash_definition(_document.snapshot())
	else:
		# Run decoration is only an observation setting. Save still packages the
		# frozen document; it never silently promotes a viewing change.
		_run_presentation = intent.value.duplicate(true)
	_last_refusal = ""
	_last_edit = {"kind": "presentation", "accepted": true, "physical": false, "mode": _mode}
	_record("presentation")
	document_changed.emit()


func preview_promotion() -> Dictionary:
	_promotion.clear()
	if _mode != "run" or _frozen.is_empty() or not bool(_host.state().ready):
		return _project_refusal("promotion_requires_ready_run")
	var built: Dictionary = Promotion.build(_frozen, intervention_journal())
	if not bool(built.ok):
		var refusal: Dictionary = _project_refusal(str(built.error))
		refusal["conflicts"] = built.get("conflicts", []).duplicate(true)
		return refusal
	var checked: Dictionary = Archive.validate_definition(built.definition, source_identity())
	if not bool(checked.ok):
		return _project_refusal("promotion_candidate: " + str(checked.error))
	var identity: Dictionary = Archive.canonical_identity(checked.definition, source_identity())
	if not bool(identity.ok):
		return _project_refusal(str(identity.error))
	_promotion_serial += 1
	_promotion = {"token": _promotion_serial, "generation": _generation, "epoch": _input_epoch,
		"sequence": _sequence, "tick": int(_host.state().native_tick), "definition": checked.definition,
		"candidate_hash": identity.logical_sha256, "summary": built.summary}
	return {"ok": true, "accepted": true, "token": _promotion_serial, "candidate_hash": identity.logical_sha256,
		"summary": built.summary, "conflicts": built.conflicts.duplicate(true),
		"eligible": built.eligible, "skipped": built.skipped, "preview": built.preview.duplicate(true)}


func confirm_promotion(token: int) -> Dictionary:
	if _promotion.is_empty() or token != int(_promotion.token) or _mode != "run" \
			or _generation != int(_promotion.generation) or _input_epoch != int(_promotion.epoch) \
			or _sequence != int(_promotion.sequence) or int(_host.state().native_tick) != int(_promotion.tick):
		return _project_refusal("retired_promotion_preview")
	var candidate: Dictionary = _copy_definition(_promotion.definition)
	var previous_generation: int = _generation
	var receipt: Dictionary = import_project(candidate, _generation, _input_epoch)
	if bool(receipt.ok):
		_record("interventions_promoted_to_new_draft", "from generation %d" % previous_generation)
	return receipt


func _project_refusal(reason: String, partial: bool = false) -> Dictionary:
	_refuse(reason)
	return {"ok": false, "accepted": false, "error": reason, "reason": reason, "partial": partial}


func run_evidence() -> Dictionary:
	var live: Dictionary = _host.state()
	var identity: Dictionary = project_identity()
	var initial: Dictionary = authored_project()
	var interventions: Array = []
	for entry: Dictionary in intervention_journal():
		var row: Dictionary = entry.duplicate(true)
		if row.has("after_objects"):
			row.before_objects = SandfallRapierObjectRegistry.logical_graph(row.before_objects)
			row.after_objects = SandfallRapierObjectRegistry.logical_graph(row.after_objects)
		if row.has("indices"):
			row.indices = Array(row.indices)
			row["after_base64"] = Marshalls.raw_to_base64(row.after)
			row.erase("after")
			row.command_indices = Array(row.command_indices)
			row["command_after_base64"] = Marshalls.raw_to_base64(row.command_after)
			row.erase("command_after")
		interventions.append(row)
	return {"type": "sandfall-run-evidence", "schema_version": 1, "source": source_identity(),
		"scope": "recorded local outcome; no full-stack bitwise replay or continuation guarantee",
		"project": {"id": initial.get("id", ""), "title": initial.get("title", ""),
			"logical_sha256": identity.get("logical_sha256", ""), "physical_sha256": identity.get("physical_sha256", ""),
			"identity_valid": bool(identity.get("ok", false)), "identity_error": identity.get("error", ""),
			"initial_cells_sha256": _document.state().cells_sha256 if _document != null else "",
			"initial_objects": SandfallRapierObjectRegistry.logical_graph(initial.get("bodies", [])),
			"settings": initial.get("project", Archive.project_defaults(initial.get("bodies", []))).duplicate(true), "interest": live.simulation_interest},
		"session": {"mode": _mode, "pristine": _pristine, "generation": _generation,
			"edit_epoch": _edit_epoch, "tick": int(live.native_tick), "rapier_steps": int(live.rapier_steps),
			"paused": _paused, "speed": _speed, "fixed_delta": 1.0 / 60.0,
			"history_retired": _history_retired, "error": str(live.error)},
		"actor_control_trace": {"mode": "absent", "locomotion_commands": 0, "action_commands": 0},
		"physical": {"body_ids": Array(live.body_ids), "body_poses": live.body_states,
			"cells_sha256": _host.material_identity(),
			"current_objects": SandfallRapierObjectRegistry.logical_graph(_host.get_object_definitions()),
			"initial_body_poses": live.initial_body_states, "moves": live.moves_total,
			"contacts": live.contacts_total, "displacements": live.displaced_total,
			"per_object_feedback": live.object_feedback, "body_body_pairs": live.body_body_pairs,
			"workers": live.workers, "pending_colliders": live.pending_colliders},
		"interventions": interventions, "intervention_bytes": _intervention_bytes,
		"observation": {"presentation": presentation()},
		"events": _journal.duplicate(true), "events_dropped": _journal_dropped,
		"trace_limits": {"diagnostic_parameter_bytes_per_event": MAX_DIAGNOSTIC_PARAMETER_BYTES,
			"unadmitted_malformed_parameters": "omitted; refusal reason retained", "full_replay_trace": false},
		"limits": {"interventions": MAX_INTERVENTIONS, "intervention_payload_bytes": MAX_INTERVENTION_BYTES,
			"diagnostic_events": MAX_JOURNAL},
		"qualification": {"human_exhibition_accepted": false, "threaded_web_qualified": false,
			"cross_platform_bitwise_replay": false}}


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
		if command.action in ["mutation", "object_edit", "presentation"]:
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
		if entry.has("indices"):
			copy.indices = PackedInt32Array(entry.indices).duplicate()
			copy.after = PackedByteArray(entry.after).duplicate()
		out.append(copy)
	return out


func object_definitions() -> Array:
	return _host.get_object_definitions()


func object_edit_snapshot() -> Dictionary:
	var live: Dictionary = _host.state()
	return {"ok": _mode in ["edit", "run"] and bool(live.ready) and not _menu,
		"definitions": object_definitions(), "generation": _generation, "input_epoch": _input_epoch,
		"revision": int(_document.state().revision) if _mode == "edit" and _document != null else int(live.get("object_revision", 0))}


func enqueue_object_edit(operation: Dictionary, expected_revision: int, generation: int, epoch: int) -> bool:
	if generation != _generation or epoch != _input_epoch or _menu or _mode not in ["edit", "run"]:
		return _refuse("retired_or_wrong_mode_object_edit")
	var error: String = _validate_object_operation(operation)
	if not error.is_empty():
		return _refuse(error)
	for command: Dictionary in _commands:
		if command.action in ["mutation", "object_edit", "presentation"]:
			return _refuse("mutation_already_queued")
	if _commands.size() >= MAX_COMMANDS:
		return _refuse("mutation_command_capacity_or_kind")
	_commands.append({"action": "object_edit", "value": {"operation": operation.duplicate(true),
		"revision": expected_revision, "mode": _mode}, "generation": generation, "input_epoch": epoch})
	return true


func _validate_object_operation(operation: Dictionary) -> String:
	if not operation.get("operation") is String or operation.operation not in ["spawn", "update", "delete", "duplicate"]:
		return "unsupported_object_operation"
	var allowed: Dictionary = {"spawn": ["operation", "definition"], "update": ["operation", "id", "changes"],
		"delete": ["operation", "id"], "duplicate": ["operation", "id", "offset"]}
	for key: Variant in operation:
		if key not in allowed[operation.operation]:
			return "unsupported_object_operation_field"
	if operation.operation != "spawn" and (not operation.get("id") is String or str(operation.id).is_empty() or str(operation.id).length() > 64):
		return "invalid_object_identity"
	var property_key: String = "definition" if operation.operation == "spawn" else "changes"
	if operation.has(property_key):
		if not operation[property_key] is Dictionary:
			return "malformed_object_properties"
		for key: Variant in operation[property_key]:
			if key not in ["name", "passive_subject", "shape", "position", "size", "rotation", "linear_velocity", "angular_velocity", "mass", "gravity_scale", "friction", "restitution", "linear_damp", "angular_damp", "fixed", "frozen"]:
				return "unsupported_or_immutable_object_property"
	if operation.has("offset") and (not operation.offset is Vector2 or not operation.offset.is_finite()):
		return "invalid_duplicate_offset"
	return ""


func _apply_object_edit(intent: Dictionary) -> void:
	var live: Dictionary = _host.state()
	if _menu or _mode not in ["edit", "run"] or _mode != str(intent.mode) or not bool(live.ready):
		_refuse("object_edit_requires_ready_owner")
		return
	var expected_revision: int = int(_document.state().revision) if _mode == "edit" else int(live.object_revision)
	if int(intent.revision) != expected_revision:
		_refuse("stale_document_revision" if _mode == "edit" else "stale_object_revision")
		return
	if _mode == "edit" and (int(live.native_tick) != 0 or int(live.rapier_steps) != 0):
		_refuse("edit_requires_both_solvers_at_zero")
		return
	var operation: Dictionary = intent.operation
	var before: Array = object_definitions()
	var candidate: Array = before.duplicate(true)
	var target: int = -1
	var object_id: String = str(operation.get("id", ""))
	for index: int in range(candidate.size()):
		if str(candidate[index].id) == object_id:
			target = index
	if operation.operation != "spawn" and target < 0:
		_refuse("object_not_found")
		return
	var allocated: bool = operation.operation in ["spawn", "duplicate"]
	var serial: int = _next_object_serial
	if allocated:
		object_id = "sf-box-%d" % serial
		var occupied: Dictionary = {}
		for definition: Dictionary in candidate:
			occupied[str(definition.id)] = true
		while occupied.has(object_id):
			serial += 1
			object_id = "sf-box-%d" % serial
	match str(operation.operation):
		"spawn":
			var definition: Dictionary = SandfallRapierObjectRegistry.make_box(object_id, serial, Vector2(240, 80), Vector2(24, 24))
			definition.merge(operation.get("definition", {}), true)
			candidate.append(definition)
		"duplicate":
			var duplicate: Dictionary = candidate[target].duplicate(true)
			duplicate.id = object_id
			duplicate.creation_order = serial
			# The project has one optional distinguished passive subject. Copying
			# its physical box does not silently create a second designation.
			duplicate.passive_subject = false
			duplicate.position += operation.get("offset", Vector2(24, 0))
			candidate.append(duplicate)
		"update":
			candidate[target].merge(operation.get("changes", {}), true)
		"delete":
			candidate.remove_at(target)
	var properties: Dictionary = operation.get("definition", {}) if operation.operation == "spawn" else operation.get("changes", {})
	if bool(properties.get("passive_subject", false)):
		for row: Dictionary in candidate:
			if str(row.id) != object_id:
				row.passive_subject = false
	var checked: Dictionary = SandfallRapierObjectRegistry.validate_graph(candidate)
	if not bool(checked.ok):
		_refuse(str(checked.error))
		return
	candidate = checked.definitions
	var patch: Dictionary = {}
	var kind: String = "object_" + str(operation.operation)
	if _mode == "edit":
		patch = _document.prepare_objects(candidate, expected_revision, kind)
		if not bool(patch.ok):
			_refuse(str(patch.error))
			return
	var explicit_fields: Dictionary = {}
	if _mode == "run" and operation.operation == "update":
		explicit_fields[object_id] = operation.get("changes", {}).keys()
	var cost: int = SandfallRapierObjectRegistry.logical_payload_bytes(before) + SandfallRapierObjectRegistry.logical_payload_bytes(candidate) \
		+ JSON.stringify(explicit_fields, "", true, true).to_utf8_buffer().size()
	var metadata_only: bool = operation.operation == "update"
	for field: Variant in operation.get("changes", {}):
		metadata_only = metadata_only and field in ["name", "passive_subject"]
	if _mode == "run" and not metadata_only and (_interventions.size() >= MAX_INTERVENTIONS or _intervention_bytes + cost > MAX_INTERVENTION_BYTES):
		_refuse("intervention_journal_capacity")
		return
	var receipt: Dictionary = _host.apply_object_graph(candidate, int(live.object_revision), int(live.native_tick), explicit_fields)
	if not bool(receipt.ok):
		if allocated and bool(receipt.get("partial", false)):
			_next_object_serial = serial + 1
		receipt["kind"] = kind
		receipt["object_id"] = object_id
		_handle_edit_refusal(receipt)
		return
	if not bool(receipt.get("changed", false)):
		_refuse("no_effect")
		return
	if allocated:
		_next_object_serial = serial + 1
	if _mode == "edit":
		if not _document.commit(patch):
			_handle_edit_refusal({"ok": false, "partial": true, "error": "document_commit_conflict"})
			return
		_definition_hash = _hash_definition(_document.snapshot())
		_editable_initial_body_poses = _host.state().body_states.duplicate(true)
	elif bool(receipt.get("physical_changed", true)):
		_pristine = false
		_sequence += 1
		_interventions.append({"sequence": _sequence, "tick": int(live.native_tick),
			"generation": _generation, "input_epoch": _input_epoch, "kind": kind, "accepted": true,
			"source": source_identity(), "object_id": object_id,
			"before_objects": before.duplicate(true), "after_objects": candidate.duplicate(true),
			"explicit_fields": explicit_fields.duplicate(true), "object_schema_version": 1})
		_intervention_bytes += cost
	else:
		_record("object_metadata", object_id)
	_mutation_count += 1
	_last_refusal = ""
	_last_edit = {"kind": kind, "object_id": object_id, "objects": candidate.size(), "mode": _mode,
		"tick": int(live.native_tick), "object_revision": int(receipt.get("revision", live.object_revision)),
		"physical": bool(receipt.get("physical_changed", true)), "accepted": true}
	document_changed.emit()


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
	# Both the actual physical delta and the complete explicit command are
	# retained. The latter is necessary for faithful initial-state promotion.
	var cost: int = patch.indices.size() * 9 + intent.indices.size() * 9
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
			"input_epoch": _input_epoch, "source": source_identity(), "indices": PackedInt32Array(patch.indices).duplicate(),
			"after": PackedByteArray(patch.after).duplicate(), "command_indices": PackedInt32Array(intent.indices).duplicate(),
			"command_after": PackedByteArray(intent.desired).duplicate()})
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
	var receipt: Dictionary
	if str(patch.get("domain", "cells")) == "presentation":
		receipt = {"ok": true}
	elif str(patch.get("domain", "cells")) == "objects":
		var live: Dictionary = _host.state()
		receipt = _host.apply_object_graph(patch.after_objects, int(live.object_revision), int(live.native_tick))
	else:
		var capture: Dictionary = _host.capture_cells()
		if not bool(capture.ok):
			_refuse(str(capture.error))
			return
		receipt = _host.apply_editor_patch(patch, int(capture.revision), int(capture.tick))
	if not bool(receipt.ok):
		_handle_edit_refusal(receipt)
		return
	if not _document.commit(patch):
		_handle_edit_refusal({"ok": false, "partial": true, "error": "document_commit_conflict"})
		return
	_last_refusal = ""
	_definition_hash = _hash_definition(_document.snapshot())
	if str(patch.get("domain", "cells")) == "objects":
		_editable_initial_body_poses = _host.state().body_states.duplicate(true)
	_last_edit = {"kind": direction, "domain": str(patch.get("domain", "cells")),
		"cells": patch.get("indices", PackedInt32Array()).size(), "mode": "edit", "tick": 0, "accepted": true}
	_refresh_hash()
	document_changed.emit()


func _handle_edit_refusal(receipt: Dictionary) -> void:
	if bool(receipt.get("partial", false)):
		var previous_mode: String = _mode
		var actual: Dictionary = _host.state()
		if previous_mode == "run":
			_pristine = false
		_last_edit = {"kind": str(receipt.get("kind", "mutation")), "accepted": false,
			"partial": true, "mode": previous_mode, "error": str(receipt.error),
			"object_id": str(receipt.get("object_id", "")), "tick": int(actual.native_tick),
			"rapier_steps": int(actual.rapier_steps), "object_revision": int(actual.get("object_revision", 0))}
		_mode = "fault"
		_paused = true
		_retire_history()
		clear_pending_input("partial_edit_fault")
		_record("partial_mutation", str(receipt.error))
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
