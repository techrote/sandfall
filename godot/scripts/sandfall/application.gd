class_name SandfallApplication
extends Control

# Dedicated zero-player entry. Only this application admits UI/time/camera
# intent; the composed host has no keyboard, actor or launcher authority.
var _host: SandfallSimulationHost
var _session: SandfallSessionController
var _canvas: SandfallWorldCanvas
var _buttons: Dictionary = {}
var _status: Label
var _home: Label
var _modal: Control
var _held_keys: Dictionary = {}
var _pointer_buttons: Dictionary = {}
var _button_gestures: Dictionary = {}
var _pan_active: bool = false
var _clear_serial: int = 0
var _frame: int = 0
var _paint_commands: int = 0
var _observer_enabled: bool = false
var _last_observation_ms: int = -1000
var _provenance: Dictionary = {}
var _web_focus_callback: JavaScriptObject
var _web_window: JavaScriptObject
var _web_document: JavaScriptObject
var _web_canvas: JavaScriptObject


func _ready() -> void:
	_host = SandfallSimulationHost.new()
	_host.name = "SimulationHost"
	add_child(_host)
	_session = SandfallSessionController.new(_host)
	_session.input_retired.connect(_clear_input)
	_build_ui()
	_session.reconstructed.connect(_on_reconstructed)
	_load_provenance()
	_connect_browser_focus()
	_update_ui()
	_publish_observation(true)


func _physics_process(_delta: float) -> void:
	if _session == null:
		return
	_session.process_commands()
	# Exactly one fixed 1/60 native/Rapier request per physics callback. Godot's
	# bounded catch-up controls wall-clock pacing; counters always report work.
	if _session.advance():
		_canvas.publish()


func _process(_delta: float) -> void:
	_frame += 1
	if _session == null:
		return
	_update_ui()
	_publish_observation()


func _input(event: InputEvent) -> void:
	# Releases are observed even when a UI Control consumes the event later.
	if event is InputEventKey:
		var key: String = str(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
		if event.pressed:
			_held_keys[key] = true
		else:
			_held_keys.erase(key)
	elif event is InputEventMouseButton:
		var button: String = str(event.button_index)
		if event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
			_pointer_buttons[button] = true
		else:
			_pointer_buttons.erase(button)
		if event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
			_pan_active = false


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or _session == null:
		return
	var state: Dictionary = _session.state()
	if event.keycode == KEY_ESCAPE:
		_request("continue" if state.menu else "menu")
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_P and state.mode == "run" and not state.menu:
		_request("toggle_pause")
		get_viewport().set_input_as_handled()


func _canvas_input(event: InputEvent) -> void:
	var state: Dictionary = _session.state()
	if not state.ready or state.menu:
		return
	if event is InputEventMouseButton:
		if not _canvas.global_content_rect().has_point(event.global_position):
			return
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_pan_active = event.pressed
			_canvas.accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_canvas.zoom_at(1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2, event.global_position)
			_canvas.accept_event()
	elif event is InputEventMouseMotion and _pan_active:
		if not _canvas.global_content_rect().has_point(event.global_position):
			_session.clear_pending_input("world_view_exit")
			return
		_canvas.pan(event.relative)
		_canvas.accept_event()


func _notification(what: int) -> void:
	if _session == null:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_session.focus_lost()
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		_session.clear_pending_input("window_pointer_exit")


func _request(action: String, value: String = "") -> void:
	# UI entry changes and modal transitions retire any previous gesture before
	# admitting the new command. No browser test has a command setter.
	_clear_input("ui_command")
	_session.enqueue(action, value)


func _clear_input(_reason: String = "") -> void:
	_held_keys.clear()
	_pointer_buttons.clear()
	_button_gestures.clear()
	_pan_active = false
	_clear_serial += 1


func _on_reconstructed() -> void:
	_canvas.bind_host(_host)
	_update_ui()


func _camera_action(action: String) -> void:
	_clear_input("camera_control")
	if not _session.state().ready or _session.state().menu:
		return
	var content: Rect2 = _canvas.global_content_rect()
	match action:
		"pan_left": _canvas.pan(Vector2(content.size.x * 0.12, 0))
		"pan_right": _canvas.pan(Vector2(-content.size.x * 0.12, 0))
		"pan_up": _canvas.pan(Vector2(0, content.size.y * 0.12))
		"pan_down": _canvas.pan(Vector2(0, -content.size.y * 0.12))
		"zoom_in": _canvas.zoom_at(1.2, content.get_center())
		"zoom_out": _canvas.zoom_at(1.0 / 1.2, content.get_center())
		"fit": _canvas.fit()


func _build_ui() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color("111821")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	column.add_child(header)
	var title: Label = Label.new()
	title.text = "SANDFALL"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_add_button(header, "gallery", "Gallery", func() -> void: _request("gallery"))
	_add_button(header, "sandbox", "Sandbox", func() -> void: _request("sandbox"))
	_add_button(header, "menu", "Menu", func() -> void: _request("menu"))
	var templates: HBoxContainer = HBoxContainer.new()
	column.add_child(templates)
	var template_label: Label = Label.new()
	template_label.text = "Initial scene   "
	templates.add_child(template_label)
	_add_button(templates, "template_blank", "Blank", func() -> void: _request("template", "blank"))
	_add_button(templates, "template_native", "Material Lab", func() -> void: _request("template", "material_lab"))
	_add_button(templates, "template_coupled", "Physics Pit", func() -> void: _request("template", "physics_pit"))
	var frame: PanelContainer = PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color("080c12")
	frame.add_theme_stylebox_override("panel", panel)
	column.add_child(frame)
	_canvas = SandfallWorldCanvas.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(_canvas)
	_canvas.gui_input.connect(_canvas_input)
	_canvas.mouse_exited.connect(func() -> void: _session.clear_pending_input("canvas_exit"))
	_home = Label.new()
	_home.text = "A world in motion. No player required.\n\nOpen Gallery to watch the materials and bodies interact.\nOpen Sandbox to start paused, choose a template, then Run."
	_home.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_home.add_theme_font_size_override("font_size", 23)
	_home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_home)
	var camera: HBoxContainer = HBoxContainer.new()
	column.add_child(camera)
	var camera_label: Label = Label.new()
	camera_label.text = "Camera   "
	camera.add_child(camera_label)
	for pair: Array in [["pan_left", "Left"], ["pan_right", "Right"], ["pan_up", "Up"], ["pan_down", "Down"], ["zoom_in", "+"], ["zoom_out", "−"], ["fit", "Fit"]]:
		var camera_action: String = str(pair[0])
		_add_button(camera, camera_action, str(pair[1]), func() -> void: _camera_action(camera_action))
	var hint: Label = Label.new()
	hint.text = "   Middle drag · wheel zoom"
	camera.add_child(hint)
	var lifecycle: HBoxContainer = HBoxContainer.new()
	column.add_child(lifecycle)
	_add_button(lifecycle, "run", "Run", func() -> void: _request("run"))
	_add_button(lifecycle, "pause", "Pause", func() -> void: _request("toggle_pause"))
	_add_button(lifecycle, "step", "Step", func() -> void: _request("step"))
	_add_button(lifecycle, "reset", "Reset", func() -> void: _request("reset"))
	_add_button(lifecycle, "reset_edit", "Reset & Edit", func() -> void: _request("reset_edit"))
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lifecycle.add_child(_status)
	_build_menu()


func _add_button(parent: Node, key: String, label: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(64, 40)
	button.add_theme_font_size_override("font_size", 19)
	# Space is not a hidden action on the last clicked control. All required
	# controls remain pointer-accessible; P and Escape are explicit shortcuts.
	button.focus_mode = Control.FOCUS_NONE
	button.button_down.connect(func() -> void:
		_button_gestures[key] = {"clear_serial": _clear_serial, "generation": _session.state().generation}
	)
	button.mouse_exited.connect(func() -> void: _button_gestures.erase(key))
	button.pressed.connect(func() -> void:
		# BaseButton may still see a release after blur/modal/reset. A command
		# requires a fresh press admitted in this input and session epoch.
		var gesture: Dictionary = _button_gestures.get(key, {})
		_button_gestures.erase(key)
		if not gesture.is_empty() and int(gesture.clear_serial) == _clear_serial \
				and int(gesture.generation) == int(_session.state().generation):
			callback.call()
	)
	parent.add_child(button)
	_buttons[key] = button
	return button


func _build_menu() -> void:
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 210)
	center.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	var label: Label = Label.new()
	label.text = "Sandfall\nSimulation held while the menu is open.\nP: pause / resume · Escape: menu"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	_add_button(column, "continue", "Continue", func() -> void: _request("continue"))
	_modal.hide()


func _update_ui() -> void:
	var state: Dictionary = _session.state()
	_home.visible = state.entry == "home"
	_canvas.visible = state.entry != "home"
	_modal.visible = state.menu
	for key: String in _buttons:
		var button: Button = _buttons[key]
		button.disabled = bool(state.menu) and key != "continue"
		if key.begins_with("template_") or key in ["pan_left", "pan_right", "pan_up", "pan_down", "zoom_in", "zoom_out", "fit", "reset", "reset_edit"]:
			button.disabled = button.disabled or state.entry == "home"
	_buttons.run.visible = state.mode == "edit" and state.entry != "home"
	_buttons.pause.visible = state.mode == "run"
	_buttons.pause.text = "Resume" if state.paused else "Pause"
	_buttons.step.disabled = state.menu or state.mode != "run" or not state.paused or not state.ready
	_buttons.run.disabled = state.menu or not state.ready
	var mode_label: String = "Choose Gallery or Sandbox" if state.entry == "home" else "%s · %s · tick %d" % [str(state.mode).capitalize(), "Paused" if state.paused else "Running", int(state.tick)]
	_status.text = mode_label + (" · Pristine" if state.entry != "home" else "")
	if not str(state.error).is_empty():
		_status.text = "Stopped: " + str(state.error)
		_status.add_theme_color_override("font_color", Color("ff9c81"))
	else:
		_status.remove_theme_color_override("font_color")


func observation() -> Dictionary:
	var result: Dictionary = _session.state()
	var rendering: Dictionary = _canvas.state()
	var buttons: Dictionary = {}
	for key: String in _buttons:
		var button: Button = _buttons[key]
		if button.is_visible_in_tree():
			var rect: Rect2 = button.get_global_rect()
			buttons[key] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	result.merge({"schema": "sandfall-host-v1", "app_ready": true, "frame": _frame,
		"input": {"held_keys": _held_keys.keys(), "pointer_buttons": _pointer_buttons.size(),
			"gesture_active": _pan_active, "pending_ui_gestures": _button_gestures.size(), "clear_serial": _clear_serial},
		"actor_count": _count_actor_nodes(get_tree().root), "paint_commands": _paint_commands,
		"camera": {"camera_origin": rendering.camera_origin, "view_size": rendering.view_size, "zoom": rendering.zoom},
		"rendering": rendering, "view": rendering.content_rect,
		"pending_colliders": result.native.pending_colliders,
		"render_rejections": int(rendering.render_rejections), "buttons": buttons,
		"viewport": [get_viewport_rect().size.x, get_viewport_rect().size.y],
		"source_commit": str(_provenance.get("source_commit", "")),
		"native_sha256": str(_provenance.get("sha256", "")),
		"provenance": _provenance.duplicate(true),
	}, true)
	return result


func _count_actor_nodes(node: Node) -> int:
	var count: int = 1 if node is CharacterBody2D else 0
	for child: Node in node.get_children():
		count += _count_actor_nodes(child)
	return count


func _load_provenance() -> void:
	var path: String = "res://addons/cybersand_native/runtime-provenance.web.json"
	if not OS.has_feature("web"):
		path = "res://addons/cybersand_native/runtime-provenance.sandfall-native.json"
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			_provenance = parsed


func _connect_browser_focus() -> void:
	if not OS.has_feature("web"):
		return
	_observer_enabled = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('test') === '1'", true))
	_web_window = JavaScriptBridge.get_interface("window")
	_web_document = JavaScriptBridge.get_interface("document")
	_web_canvas = _web_document.getElementById("canvas")
	_web_focus_callback = JavaScriptBridge.create_callback(_on_browser_focus_event)
	_web_window.addEventListener("blur", _web_focus_callback)
	_web_document.addEventListener("visibilitychange", _web_focus_callback)
	if _web_canvas != null:
		_web_canvas.addEventListener("mouseleave", _web_focus_callback)


func _on_browser_focus_event(arguments: Array) -> void:
	if _session == null or arguments.is_empty():
		return
	var event: JavaScriptObject = arguments[0]
	if str(event.type) == "mouseleave":
		_session.clear_pending_input("browser_pointer_exit")
	elif str(event.type) == "blur" or bool(_web_document.hidden):
		_session.focus_lost()
	_publish_observation(true)


func _publish_observation(force: bool = false) -> void:
	if not _observer_enabled:
		return
	var now: int = Time.get_ticks_msec()
	if not force and now - _last_observation_ms < 100:
		return
	_last_observation_ms = now
	# Read-only values in the ordinary application. No acceptance URL selects
	# a different scene or allows JavaScript to mutate the host or its counters.
	var encoded: String = JSON.stringify(JSON.stringify(observation()))
	JavaScriptBridge.eval("(() => { let e = document.getElementById('sandfall-test-state'); if (!e) { e = document.createElement('pre'); e.id = 'sandfall-test-state'; e.hidden = true; document.body.appendChild(e); } e.textContent = " + encoded + "; })()", true)


func _exit_tree() -> void:
	if _web_focus_callback != null:
		_web_window.removeEventListener("blur", _web_focus_callback)
		_web_document.removeEventListener("visibilitychange", _web_focus_callback)
		if _web_canvas != null:
			_web_canvas.removeEventListener("mouseleave", _web_focus_callback)
	if is_instance_valid(_host):
		_host.shutdown()
