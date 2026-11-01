extends SceneTree

# Actual Godot Control hit-testing and Input dispatch. Browser input/pixels have
# their own independent compatibility-Web qualification lane.
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
	_check(_app.observation().mode == "edit" and _app.observation().tick == 0, "Sandbox did not enter static Edit")
	_check(_app.observation().editor.tools_visible and _app._buttons.tools.text == "Tools: shown", "Sandbox did not visibly expose its editing tools")
	await _click("material_wall")
	await _click("tool_rectangle")
	await _drag(Vector2(300, 180), Vector2(330, 200))
	var wall_hash: String = _app.observation().current_hash
	_check(_app.observation().document.undo_depth == 1, "Material baseline did not create first chronological transaction")
	await _click("mode_objects")
	await _click("object_box")
	await _drag(Vector2(60, 60), Vector2(80, 80))
	var created: Dictionary = _app.observation()
	_check(created.object_definitions.size() == 1 and created.document.undo_depth == 2 and created.tick == 0 and created.rapier_steps == 0, "Box canvas creation did not create one zero-time transaction")
	var id: String = str(created.object_definitions[0].id)
	_check(created.editor.selected_object_id == id and created.rendering.body_ids == [id], "Created box was not selected/render-bound by stable ID")
	_check(created.object_definitions[0].size == [20.0, 20.0], "Box preview geometry did not match physical geometry")
	await _click("object_select")
	await _drag(Vector2(70, 70), Vector2(70, 70))
	_check(_app.observation().editor.selected_object_id == id, "Canvas selection did not identify stable ID")
	await _click("object_move")
	await _drag(Vector2(70, 70), Vector2(100, 90))
	var moved: Dictionary = _app.observation()
	_check(moved.document.undo_depth == 3 and _definition(id).position.distance_to(Vector2(100, 90)) < 0.05, "Object drag did not commit one exact position transaction")
	await _click("object_tab_physics")
	await _field("mass", "3.5")
	await _field("friction", "0.35")
	await _field("restitution", "0.4")
	await _field("linear_damping", "0.2")
	await _field("angular_damping", "0.6")
	await _field("gravity_scale", "0.1")
	_check(_app.observation().document.undo_depth == 3 and is_equal_approx(float(_definition(id).mass), 1.0), "Typing inspector values mutated physics before Apply")
	await _click("object_apply")
	_check(is_equal_approx(float(_definition(id).mass), 3.5) and _app.observation().document.undo_depth == 4, "Inspector mass Apply did not commit one object transaction")
	_check(is_equal_approx(float(_definition(id).friction), 0.35) and is_equal_approx(float(_definition(id).restitution), 0.4)
		and is_equal_approx(float(_definition(id).linear_damp), 0.2) and is_equal_approx(float(_definition(id).angular_damp), 0.6)
		and is_equal_approx(float(_definition(id).gravity_scale), 0.1), "Inspector physics fields were lost or mapped incorrectly")
	_check(_app.observation().current_hash == wall_hash, "Inspector interaction painted through into material cells")
	await _click("object_tab_shape")
	await _field("width", "28")
	await _field("height", "12")
	await _field("rotation", "30")
	await _click("object_apply")
	_check(_definition(id).size == Vector2(28, 12) and is_equal_approx(float(_definition(id).rotation), deg_to_rad(30.0)), "Precise inspector resize/rotation was not applied")
	_check(_app.observation().document.undo_depth == 5, "Grouped inspector changes created multiple transactions")
	await _click("object_tab_motion")
	await _field("vx", "12")
	await _field("vy", "-3")
	await _field("angular_velocity", "45")
	await _click("object_apply")
	_check(_definition(id).linear_velocity == Vector2(12, -3) and is_equal_approx(float(_definition(id).angular_velocity), deg_to_rad(45.0)), "Initial velocity controls lost values or units")
	await _click("object_duplicate")
	var duplicated: Dictionary = _app.observation()
	_check(duplicated.object_definitions.size() == 2 and duplicated.editor.selected_object_id != id, "Duplicate failed to allocate/select a distinct stable identity")
	var duplicate_id: String = str(duplicated.editor.selected_object_id)
	_check(_definition(duplicate_id).size == _definition(id).size and _definition(duplicate_id).linear_velocity == _definition(id).linear_velocity, "Duplicate lost geometry or initial velocity")
	await _click("object_delete")
	_check(_app.observation().object_definitions.size() == 1 and _app.observation().editor.selected_object_id == "", "Delete did not retire selected object")
	await _click("undo")
	_check(_app.observation().object_definitions.size() == 2 and not _definition(duplicate_id).is_empty(), "Object undo did not restore the exact deleted ID")
	await _click("redo")
	_check(_app.observation().object_definitions.size() == 1 and _definition(duplicate_id).is_empty(), "Object redo did not remove the same stable ID")
	# A cancelled drag cannot be reactivated by its old release.
	await _click("object_move")
	var from: Vector2 = _world(Vector2(100, 90))
	var to: Vector2 = _world(Vector2(130, 90))
	_mouse_button(from, true)
	_motion(to, to - from)
	await _frames(1)
	_key(KEY_ESCAPE)
	_mouse_button(to, false)
	await _frames(3)
	_check(_definition(id).position.distance_to(Vector2(100, 90)) < 0.05 and not _app.observation().editor.object_gesture_active, "Cancelled object drag committed on stale release")
	await _click("tools")
	_check(not _app.observation().editor.tools_visible and _app._buttons.tools.text == "Tools: hidden", "Tools button did not report hidden state")
	await _click("tools")
	_check(_app.observation().editor.tools_visible, "Tools button did not restore editor visibility")
	# Reset & Edit starts a new empty history with all current authored objects.
	await _click("run")
	for _frame: int in range(20):
		await _frames(1)
		if _app.observation().tick >= 2:
			break
	await _click("pause")
	var paused: Dictionary = _app.observation()
	_check(paused.tick > 0 and paused.document.undo_depth == 0 and paused.history_retired, "Run failed to retire mixed material/object history")
	await _click("object_box")
	await _drag(Vector2(200, 60), Vector2(220, 80))
	_check(not _app.observation().pristine and _app.observation().intervention_count == 1 and _app.observation().tick == paused.tick, "Live Box creation did not enter the intervention journal")
	await _click("step")
	_check(_app.observation().tick == paused.tick + 1 and _app.observation().rapier_steps == paused.rapier_steps + 1, "Multi-object Step did not advance each solver exactly once")
	await _click("reset")
	_check(_app.observation().object_definitions.size() == 1 and _definition(id).size == Vector2(28, 12), "Reset did not reconstruct frozen authored bodies")
	await _click("reset_edit")
	_check(_app.observation().mode == "edit" and _app.observation().tick == 0 and _app.observation().document.undo_depth == 0, "Reset & Edit did not start a fresh history")
	await _click("object_select")
	await _drag(Vector2(100, 90), Vector2(100, 90))
	var corner_from: Vector2 = Vector2(100, 90) + Vector2(14, 6).rotated(deg_to_rad(30.0))
	var corner_to: Vector2 = Vector2(100, 90) + Vector2(18, 9).rotated(deg_to_rad(30.0))
	await _drag(corner_from, corner_to)
	_check(_definition(id).size.distance_to(Vector2(36, 18)) < 0.05 and _app.observation().document.undo_depth == 1,
		"Selection corner handle did not resize the physical box in one transaction")
	await _click("object_rotate")
	await _drag(Vector2(100, 90) + Vector2(18, 0).rotated(deg_to_rad(30.0)),
		Vector2(100, 90) + Vector2(18, 0).rotated(deg_to_rad(75.0)))
	_check(absf(float(_definition(id).rotation) - deg_to_rad(75.0)) < 0.01 and _app.observation().document.undo_depth == 2,
		"Canvas rotation did not commit its actual angle once")
	await _click("object_tab_shape")
	var untouched_height: float = float(_definition(id).size.y)
	await _field("width", "40.5")
	await _click("object_apply")
	_check(float(_definition(id).size.y) == untouched_height and is_equal_approx(float(_definition(id).size.x), 40.5),
		"Inspector changed an untouched vector component by display rounding")
	_receipts.append(_app.observation())
	# Capacity is exercised through the canvas itself, not a diagnostic setter.
	await _click("template_blank")
	await _click("mode_objects")
	await _click("object_box")
	for index: int in range(16):
		var centre: Vector2 = Vector2(40 + (index % 8) * 50, 60 + (index / 8) * 50)
		await _drag(centre - Vector2(8, 8), centre + Vector2(8, 8))
	var full: Dictionary = _app.observation()
	_check(full.object_definitions.size() == 16 and full.rendering.body_count == 16 and full.rendering.body_ids.size() == 16, "Sixteen canvas bodies did not reach rendering bindings")
	await _drag(Vector2(400, 150), Vector2(420, 170))
	var refused: Dictionary = _app.observation()
	_check(refused.object_definitions == full.object_definitions and refused.document.undo_depth == full.document.undo_depth and refused.last_refusal.contains("capacity"), "Seventeenth canvas body was not atomically refused")
	_check(refused.tick == 0 and refused.rapier_steps == 0, "Capacity authoring unexpectedly advanced physics")
	_receipts.append(refused)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--sandfall-ui-screenshot="):
			await process_frame
			await RenderingServer.frame_post_draw
			var captured: Image = root.get_texture().get_image()
			var path: String = argument.trim_prefix("--sandfall-ui-screenshot=")
			_check(not captured.is_empty() and captured.save_png(path) == OK, "Actual native UI screenshot failed")
	_app.free()
	await _frames(2)
	print("SANDFALL_OBJECT_INPUT_TEST ", JSON.stringify({"ok": _failures.is_empty(), "checks": _checks,
		"failures": _failures, "scope": "actual Godot Control input; browser and visual gates separate", "receipts": _receipts}))
	quit(0 if _failures.is_empty() else 1)


func _definition(id: String) -> Dictionary:
	for definition: Dictionary in _app._session.object_definitions():
		if str(definition.id) == id:
			return definition
	return {}


func _click(key: String) -> void:
	var buttons: Dictionary = _app.observation().buttons
	if not buttons.has(key):
		_check(false, "Missing clickable control: " + key)
		return
	var rect: Array = buttons[key]
	var point: Vector2 = Vector2(rect[0] + rect[2] * 0.5, rect[1] + rect[3] * 0.5)
	_motion(point)
	_mouse_button(point, true)
	await _frames(1)
	_mouse_button(point, false)
	await _frames(3)


func _field(key: String, value: String) -> void:
	var fields: Dictionary = _app.observation().editor_controls
	if not fields.has("object_" + key):
		_check(false, "Missing inspector field: " + key)
		return
	var rect: Array = fields["object_" + key]
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
	await _frames(2)


func _world(point: Vector2) -> Vector2:
	var observed: Dictionary = _app.observation()
	var view: Array = observed.view
	var origin: Array = observed.camera.camera_origin
	var dimensions: Array = observed.camera.view_size
	return Vector2(view[0] + (point.x - origin[0]) / dimensions[0] * view[2],
		view[1] + (point.y - origin[1]) / dimensions[1] * view[3])


func _drag(first: Vector2, last: Vector2) -> void:
	var from: Vector2 = _world(first)
	var to: Vector2 = _world(last)
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
	for _index: int in range(count):
		await physics_frame
		await process_frame


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(message)
		print("SF_M3_INPUT_FAILURE ", message)
