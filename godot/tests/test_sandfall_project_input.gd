extends SceneTree

# Ordinary Godot Control input, authoring history, Gallery navigation and
# presentation fences. Browser file chooser/download/pixels are separate tests.
var _app: Variant
var _checks: int = 0
var _failures: Array[String] = []
var _receipts: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 800)
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	_app = load("res://sandfall_main.tscn").instantiate()
	root.add_child(_app)
	await _frames(3)
	await _click("sandbox")
	var baseline: Dictionary = _app.observation()
	_check(baseline.mode == "edit" and baseline.tick == 0, "Sandbox is not a zero-time editor")
	for id: String in ["file_open", "file_save", "file_evidence", "file_promote", "gallery_browse", "mode_presentation"]:
		_check(baseline.buttons.has(id), "Essential project control missing: " + id)
	await _click("mode_presentation")
	await _field("annotation_text", "Physical water below")
	await _click("presentation_label")
	await _drag(Vector2(80, 60), Vector2(80, 60))
	var labelled: Dictionary = _app.observation()
	_check(labelled.presentation.annotations.size() == 1 and labelled.presentation.annotations[0].text == "Physical water below", "Label was not authored through canvas input")
	_check(labelled.document.undo_depth == 1 and labelled.tick == 0 and labelled.rapier_steps == 0, "Label did not enter one zero-time shared transaction")
	_check(labelled.current_hash == baseline.current_hash and labelled.object_definitions == baseline.object_definitions, "Label changed semantic materials or physics")
	await _click("presentation_stroke")
	await _drag(Vector2(90, 80), Vector2(150, 80))
	_check(_app.observation().presentation.annotations.size() == 2 and _app.observation().document.undo_depth == 2, "Completed decorative drag was not one transaction")
	await _click("undo")
	_check(_app.observation().presentation.annotations.size() == 1, "Shared undo did not restore previous annotations")
	await _click("redo")
	_check(_app.observation().presentation.annotations.size() == 2, "Shared redo did not restore exact stroke")
	await _click("presentation_visible")
	_check(not _app.observation().presentation.style.annotations_visible and _app.observation().document.undo_depth == 3, "Presentation visibility was not authored with history")
	await _click("undo")
	_check(_app.observation().presentation.style.annotations_visible, "Undo failed to restore annotation visibility")
	await _click("mode_materials")
	await _click("material_wall")
	await _click("tool_rectangle")
	await _drag(Vector2(250, 180), Vector2(280, 185))
	var painted: Dictionary = _app.observation()
	_check(painted.current_hash != baseline.current_hash and painted.document.undo_depth == 3, "Semantic/presentation history did not share chronological ordering")
	await _click("undo")
	_check(_app.observation().current_hash == baseline.current_hash and _app.observation().presentation.annotations.size() == 2, "Mixed undo corrupted semantic/decoration ownership")
	await _click("run")
	await _frames(3)
	await _click("pause")
	var run: Dictionary = _app.observation()
	_check(run.tick > 0 and run.history_retired and run.document.undo_depth == 0, "First Run tick did not retire presentation history")
	await _click("mode_presentation")
	await _click("presentation_label")
	await _drag(Vector2(180, 80), Vector2(180, 80))
	_check(_app.observation().pristine and _app.observation().intervention_count == 0 and _app.observation().tick == run.tick, "Cosmetic Run annotation changed physical identity or advanced physics")
	await _click("mode_objects")
	await _click("object_box")
	await _drag(Vector2(300, 80), Vector2(320, 100))
	var intervened: Dictionary = _app.observation()
	_check(not intervened.pristine and intervened.intervention_count == 1, "Object intervention did not make a promotable Modified Run")
	await _click("file_promote")
	var preview: Dictionary = _app.observation()
	_check(preview.project_modal == "promotion" and preview.promotion.accepted and preview.promotion.eligible == 1, "Promotion did not present eligible reconstruction before confirmation")
	_check(preview.generation == intervened.generation and preview.mode == "run", "Opening preview changed the current Run before confirmation")
	await _click("promotion_cancel")
	_check(_app.observation().mode == "run" and _app.observation().generation == intervened.generation, "Cancelling promotion replaced the Run")
	await _click("file_promote")
	await _click("promotion_confirm")
	var promoted: Dictionary = _app.observation()
	_check(promoted.mode == "edit" and promoted.tick == 0 and promoted.rapier_steps == 0 and promoted.document.undo_depth == 0, "Confirmed promotion did not create a fresh paused Edit baseline")
	_check(promoted.body_ids == intervened.body_ids and promoted.presentation.annotations.size() == 2, "Promotion lost explicit object identity or copied evolved Run decoration")
	# This native Control test supplies a file-picker result directly; only the
	# separate actual-browser lane claims trusted chooser input and downloads.
	var encoded: Dictionary = SandfallArchiveCodec.encode_definition(_app._session.authored_project(), _app._session.source_identity())
	_check(encoded.ok, "Authored project could not be encoded for staged UI import")
	await _click("file_open")
	_app._desktop_dialog.hide()
	_app._on_project_selected(PackedByteArray([0]), "invalid.sandfall", int(_app._file_lease.serial))
	await _frames(2)
	var refused: Dictionary = _app.observation()
	_check(refused.project_file.status == "refused" and refused.generation == promoted.generation and refused.body_ids == promoted.body_ids and refused.current_hash == promoted.current_hash, "Malformed archive replaced current physical/document state")
	await _click("project_cancel")
	await _click("file_open")
	_app._desktop_dialog.hide()
	_app._on_project_selected(encoded.bytes, "roundtrip.sandfall", int(_app._file_lease.serial))
	await _frames(2)
	_check(_app.observation().project_file.staged and _app.observation().generation == promoted.generation, "Valid archive was not held for explicit replacement confirmation")
	# Inject an independent session transition while a staged preview exists.
	# The UI must reject the stale generation even with a fresh button click.
	_app._session.enqueue("sandbox")
	await _frames(3)
	var other_generation: Dictionary = _app.observation()
	await _click("project_confirm")
	_check(_app.observation().project_file.error == "stale_project_generation" and _app.observation().generation == other_generation.generation and _app.observation().body_ids.is_empty(), "Staged archive crossed its original session generation")
	await _click("project_cancel")
	await _click("file_open")
	_app._desktop_dialog.hide()
	_app._on_project_selected(encoded.bytes, "roundtrip.sandfall", int(_app._file_lease.serial))
	await _frames(2)
	# Focus retires the old input epoch; a newly pressed explicit confirmation
	# remains valid in the same generation after returning from a file chooser.
	var before_focus_epoch: int = int(_app.observation().input_epoch)
	_app._session.focus_lost()
	await _frames(2)
	_check(int(_app.observation().input_epoch) > before_focus_epoch and _app.observation().project_file.staged, "Focus retirement discarded staged bytes or retained an old epoch")
	await _click("project_confirm")
	var imported: Dictionary = _app.observation()
	_check(imported.project_file.import_count == 1 and imported.mode == "edit" and imported.tick == 0 and imported.rapier_steps == 0 and imported.document.undo_depth == 0, "Open confirmation did not install a fresh zero-time project")
	_check(imported.body_ids == promoted.body_ids and imported.presentation == promoted.presentation and imported.current_hash == promoted.current_hash, "Project UI roundtrip lost exact authored state")
	var save_path: String = ProjectSettings.globalize_path("user://sf-m4-ui-stage-save.bin")
	_check(_app._write_export_file(save_path, PackedByteArray([1, 2, 3])).ok and FileAccess.get_file_as_bytes(save_path) == PackedByteArray([1, 2, 3]), "Staged desktop write did not publish complete bytes")
	_check(_app._write_export_file(save_path, PackedByteArray([4, 5, 6, 7])).ok and FileAccess.get_file_as_bytes(save_path) == PackedByteArray([4, 5, 6, 7]), "Staged desktop replacement did not replace complete bytes")
	DirAccess.remove_absolute(save_path)
	await _click("gallery_browse")
	var held: int = int(_app.observation().tick)
	await _frames(3)
	_check(_app.observation().menu and _app.observation().tick == held, "Gallery chooser did not hold simulation")
	await _field("gallery_search", "rotation")
	_check(_app.observation().gallery.visible_ids == ["endless_kinetic_loop"], "Gallery text input search did not filter by mechanism")
	await _click("gallery_launch_endless_kinetic_loop")
	_check(_app.observation().entry == "gallery" and _app.observation().scene_id == "endless_kinetic_loop" and _app.observation().mode == "run", "Gallery did not launch selected complete scene")
	await _frames(5)
	_check(_app.observation().tick > 0 and _app.observation().body_ids.size() == 3, "Gallery did not autoplay after readiness")
	await _click("gallery_browse")
	_key(KEY_ESCAPE)
	await _frames(2)
	_check(_app.observation().project_modal == "" and not _app.observation().menu, "Escape did not close project modal safely")
	_receipts.append(_app.observation())
	print("SANDFALL_PROJECT_INPUT_RESULT ", JSON.stringify({"ok": _failures.is_empty(), "checks": _checks, "failures": _failures, "receipts": _receipts}))
	_app.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)


func _click(key: String) -> void:
	var state: Dictionary = _app.observation()
	if not state.buttons.has(key):
		_check(false, "Missing visible button: " + key)
		return
	var rect: Array = state.buttons[key]
	var point: Vector2 = Vector2(rect[0] + rect[2] * 0.5, rect[1] + rect[3] * 0.5)
	_motion(point)
	_mouse_button(point, true)
	await _frames(1)
	_mouse_button(point, false)
	await _frames(4)


func _field(key: String, value: String) -> void:
	var fields: Dictionary = _app.observation().project_controls
	if not fields.has(key):
		_check(false, "Missing project text field: " + key)
		return
	var rect: Array = fields[key]
	var point: Vector2 = Vector2(rect[0] + rect[2] * 0.5, rect[1] + rect[3] * 0.5)
	_motion(point)
	_mouse_button(point, true)
	_mouse_button(point, false)
	await _frames(1)
	_key(KEY_A, true)
	for character: String in value:
		for pressed: bool in [true, false]:
			var event: InputEventKey = InputEventKey.new()
			event.unicode = character.unicode_at(0)
			event.pressed = pressed
			Input.parse_input_event(event)
	_key(KEY_ENTER)
	await _frames(3)


func _world(point: Vector2) -> Vector2:
	var state: Dictionary = _app.observation()
	return Vector2(state.view[0] + (point.x - state.camera.camera_origin[0]) / state.camera.view_size[0] * state.view[2],
		state.view[1] + (point.y - state.camera.camera_origin[1]) / state.camera.view_size[1] * state.view[3])


func _drag(first: Vector2, last: Vector2) -> void:
	var from: Vector2 = _world(first)
	var to: Vector2 = _world(last)
	_motion(from)
	_mouse_button(from, true)
	await _frames(1)
	_motion(to, to - from)
	await _frames(1)
	_mouse_button(to, false)
	await _frames(4)


func _motion(point: Vector2, relative: Vector2 = Vector2.ZERO) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	Input.parse_input_event(event)


func _mouse_button(point: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)


func _key(code: Key, ctrl: bool = false) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.ctrl_pressed = ctrl
		if code == KEY_A: event.unicode = 97
		elif code == KEY_ENTER: event.unicode = 13
		event.pressed = pressed
		Input.parse_input_event(event)


func _frames(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(message)
		print("SF_M4_PROJECT_INPUT_FAILURE ", message)
