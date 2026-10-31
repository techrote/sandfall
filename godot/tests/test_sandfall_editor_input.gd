extends SceneTree

# Real Godot Input dispatch and Control hit-testing. These are native-host input
# integration tests, not a substitute for genuine browser/CDP acceptance.
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
	_check(_app.observation().mode == "edit" and _app.observation().tick == 0, "Sandbox UI did not enter Edit")
	var original: String = _app.observation().current_hash
	await _click("tool_pencil")
	await _drag(Vector2i(30, 30), Vector2i(50, 30))
	var stroke: Dictionary = _app.observation()
	_check(stroke.document.undo_depth == 1 and stroke.current_hash != original and stroke.tick == 0, "Genuine Godot stroke did not create exactly one zero-tick transaction")
	await _click("undo")
	_check(_app.observation().current_hash == original and _app.observation().document.redo_depth == 1, "Undo button did not restore initial state")
	await _click("redo")
	_check(_app.observation().current_hash == stroke.current_hash, "Redo button did not restore the exact stroke")
	await _click("tool_picker")
	await _drag(Vector2i(40, 30), Vector2i(40, 30))
	_check(_app.observation().editor.inspected.get("id", -1) == 2, "Picker did not read actual authored material")
	await _click("material_wall")
	await _click("tool_rectangle")
	await _drag(Vector2i(100, 40), Vector2i(120, 60))
	_check(_app.observation().document.undo_depth == 2 and _app.observation().last_edit.cells == 441, "Rectangle tool did not commit exact inclusive footprint")
	await _click("material_water")
	await _click("tool_fill")
	await _drag(Vector2i(110, 50), Vector2i(110, 50))
	for _frame: int in range(300):
		await _frames(1)
		if not _app.observation().editor.fill_active and _app.observation().queued_commands == 0:
			break
	_check(_app.observation().document.undo_depth == 3 and _app.observation().last_edit.kind == "flood_fill" and _app.observation().last_edit.cells == 441,
		"Bounded fill did not commit one category transaction through input")
	await _click("tool_select")
	await _drag(Vector2i(100, 40), Vector2i(120, 60))
	await _click("copy")
	_check(_app.observation().editor.clipboard_size == [21, 21], "Copy button lost selection dimensions")
	await _click("tool_paste")
	await _drag(Vector2i(150, 40), Vector2i(150, 40))
	_check(_app.observation().document.undo_depth == 4 and _app.observation().last_edit.cells == 441, "Paste did not make one exact transaction")
	await _click("tool_move")
	await _drag(Vector2i(155, 45), Vector2i(160, 45))
	_check(_app.observation().document.undo_depth == 5 and _app.observation().last_edit.kind == "selection_move", "Overlapping Move did not commit as a single operation")
	await _click("cut")
	_check(_app.observation().document.undo_depth == 6 and _app.observation().last_edit.kind == "cut", "Cut did not clear selection as one transaction")
	await _click("undo")
	var before_cancel: Dictionary = _app.observation()
	await _click("tool_pencil")
	var from: Vector2 = _world(Vector2i(240, 50))
	var to: Vector2 = _world(Vector2i(260, 50))
	_mouse_button(from, true)
	_motion(to, to - from)
	await _frames(1)
	_key(KEY_ESCAPE)
	_mouse_button(to, false)
	await _frames(3)
	_check(_app.observation().current_hash == before_cancel.current_hash and not _app.observation().editor.gesture_active, "Cancelled held stroke was committed by its old release")
	await _click("tool_fill")
	await _drag(Vector2i(400, 200), Vector2i(400, 200))
	_check(_app.observation().editor.fill_active, "Large fill was not incremental/cancellable")
	await _click("cancel_tool")
	_check(not _app.observation().editor.fill_active and _app.observation().current_hash == before_cancel.current_hash, "Cancelled fill mutated the authored world")
	await _click("tool_picker")
	await _click("run")
	for _frame: int in range(10):
		await _frames(1)
		if _app.observation().tick >= 2:
			break
	await _click("pause")
	var paused: Dictionary = _app.observation()
	_check(paused.mode == "run" and paused.paused and paused.tick > 0 and paused.document.undo_depth == 0, "Real Run/Pause input did not retire history on first tick")
	await _click("material_sand")
	await _click("tool_pencil")
	await _drag(Vector2i(250, 50), Vector2i(260, 50))
	_check(not _app.observation().pristine and _app.observation().intervention_count == 1 and _app.observation().tick == paused.tick, "Paused Run paint did not become a zero-time journalled intervention")
	await _click("reset_edit")
	_check(_app.observation().tick == 0 and _app.observation().mode == "edit" and _app.observation().document.undo_depth == 0,
		"Reset & Edit UI retained prior physical history")
	_receipts.append(_app.observation())
	_app.free()
	await _frames(2)
	print("SANDFALL_EDITOR_INPUT_TEST ", JSON.stringify({"ok": _failures.is_empty(), "checks": _checks, "failures": _failures,
		"scope": "actual Godot native input dispatch; browser input qualified separately", "receipts": _receipts}))
	quit(0 if _failures.is_empty() else 1)


func _click(key: String) -> void:
	var buttons: Dictionary = _app.observation().buttons
	if not buttons.has(key):
		_check(false, "Missing clickable control: " + key)
		return
	var r: Array = buttons[key]
	var point: Vector2 = Vector2(r[0] + r[2] * 0.5, r[1] + r[3] * 0.5)
	_motion(point)
	_mouse_button(point, true)
	await _frames(1)
	_mouse_button(point, false)
	await _frames(3)


func _world(cell: Vector2i) -> Vector2:
	var obs: Dictionary = _app.observation()
	var view: Array = obs.view
	var origin: Array = obs.camera.camera_origin
	var dimensions: Array = obs.camera.view_size
	return Vector2(view[0] + (cell.x + 0.5 - origin[0]) / dimensions[0] * view[2],
		view[1] + (cell.y + 0.5 - origin[1]) / dimensions[1] * view[3])


func _drag(a: Vector2i, b: Vector2i) -> void:
	var from: Vector2 = _world(a)
	var to: Vector2 = _world(b)
	_motion(from)
	_mouse_button(from, true)
	await _frames(1)
	_motion(to, to - from)
	await _frames(1)
	_mouse_button(to, false)
	await _frames(3)


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


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)


func _frames(count: int) -> void:
	for _index: int in range(count):
		await physics_frame
		await process_frame


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(message)
		print("SF_M2_INPUT_FAILURE ", message)
