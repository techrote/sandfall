class_name SandfallApplication
extends Control

# Dedicated zero-player entry. Only this application admits UI/time/camera
# intent; the composed host has no keyboard, actor or launcher authority.
var _host: SandfallSimulationHost
var _session: SandfallSessionController
var _editor: SandfallEditorController
var _overlay: SandfallEditorOverlay
var _sidebar: ScrollContainer
var _material_panel: VBoxContainer
var _object_panel: VBoxContainer
var _object_list: ItemList
var _object_count: Label
var _inspector: PanelContainer
var _inspector_title: Label
var _inspector_mode: Label
var _inspector_tabs: Dictionary = {}
var _inspector_fields: Dictionary = {}
var _inspector_baseline: Dictionary = {}
var _inspector_loaded_serial: int = -1
var _inspector_object_id: String = ""
var _inspector_tab: String = "shape"
var _object_list_ids: Array = []
var _primary_palette: OptionButton
var _secondary_palette: OptionButton
var _temperature: SpinBox
var _brush_width: SpinBox
var _brush_height: SpinBox
var _editor_info: Label
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
	_session.document_changed.connect(func() -> void: _canvas.publish())
	_load_provenance()
	_session.set_source_identity(_provenance)
	_connect_browser_focus()
	_update_ui()
	_publish_observation(true)


func _physics_process(_delta: float) -> void:
	if _session == null:
		return
	_session.process_commands()
	# Pacing selects zero to four unchanged 1/60 solver requests per callback.
	# A paused Step remains exactly one; counters always report actual work.
	if _session.advance_frame() > 0:
		_canvas.publish()


func _process(_delta: float) -> void:
	_frame += 1
	if _session == null:
		return
	_editor.pump()
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
		if not event.pressed and _editor != null and not _canvas.global_content_rect().has_point(event.global_position):
			_editor.cancel("release_outside_canvas")
		if event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
			_pan_active = false


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or _session == null:
		return
	var state: Dictionary = _session.state()
	if event.ctrl_pressed and event.keycode in [KEY_Z, KEY_Y]:
		_request("redo" if event.keycode == KEY_Y or event.shift_pressed else "undo")
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and (_editor.state().gesture_active or _editor.state().fill_active):
		_session.clear_pending_input("explicit_cancel")
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
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
			_editor.cancel("camera_pan")
			_pan_active = event.pressed
			_canvas.accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_editor.cancel("camera_zoom")
			_canvas.zoom_at(1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2, event.global_position)
			_canvas.accept_event()
	elif event is InputEventMouseMotion and _pan_active:
		if not _canvas.global_content_rect().has_point(event.global_position):
			_session.clear_pending_input("world_view_exit")
			return
		_canvas.pan(event.relative)
		_canvas.accept_event()

	if not _pan_active and (event is InputEventMouseMotion or (event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT])):
		_editor.pointer(event)
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
	if _editor != null:
		_editor.cancel(_reason)
	_held_keys.clear()
	_pointer_buttons.clear()
	_button_gestures.clear()
	_pan_active = false
	_clear_serial += 1


func _on_reconstructed() -> void:
	_canvas.bind_host(_host)
	_sidebar.visible = _session.state().entry == "sandbox"
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
	_add_button(header, "tools", "Tools: shown", func() -> void: _toggle_tools())
	_add_button(header, "menu", "Menu", func() -> void: _request("menu"))
	var templates: HBoxContainer = HBoxContainer.new()
	column.add_child(templates)
	var template_label: Label = Label.new()
	template_label.text = "Initial scene   "
	templates.add_child(template_label)
	_add_button(templates, "template_blank", "Blank", func() -> void: _request("template", "blank"))
	_add_button(templates, "template_native", "Material Lab", func() -> void: _request("template", "material_lab"))
	_add_button(templates, "template_coupled", "Physics Pit", func() -> void: _request("template", "physics_pit"))
	var workspace: HBoxContainer = HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 10)
	column.add_child(workspace)
	_sidebar = ScrollContainer.new()
	_sidebar.custom_minimum_size = Vector2(250, 0)
	_sidebar.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_child(_sidebar)
	var frame: PanelContainer = PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color("080c12")
	frame.add_theme_stylebox_override("panel", panel)
	workspace.add_child(frame)
	_canvas = SandfallWorldCanvas.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(_canvas)
	_canvas.gui_input.connect(_canvas_input)
	_canvas.mouse_exited.connect(func() -> void: _session.clear_pending_input("canvas_exit"))
	_editor = SandfallEditorController.new(_session, _canvas)
	_overlay = SandfallEditorOverlay.new()
	_overlay.canvas = _canvas
	_overlay.editor = _editor
	_canvas.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_editor(templates)
	_build_object_inspector(workspace)
	_home = Label.new()
	_home.text = "A world in motion. No player required.\n\nOpen Gallery to watch the materials and bodies interact.\nOpen Sandbox to author an initial scene, then Run."
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
	hint.text = "  Speed "
	camera.add_child(hint)
	for rate: String in ["0.25", "0.5", "1", "2", "4"]:
		var pacing: String = rate
		var rate_button: Button = _add_button(camera, "speed_" + rate, rate + "×", func() -> void: _request("speed", pacing))
		rate_button.custom_minimum_size.x = 48
		rate_button.add_theme_font_size_override("font_size", 16)
	var lifecycle: HBoxContainer = HBoxContainer.new()
	column.add_child(lifecycle)
	_add_button(lifecycle, "run", "Run", func() -> void: _request("run"))
	_add_button(lifecycle, "pause", "Pause", func() -> void: _request("toggle_pause"))
	_add_button(lifecycle, "step", "Step", func() -> void: _request("step"))
	_add_button(lifecycle, "reset", "Reset", func() -> void: _request("reset"))
	_add_button(lifecycle, "reset_edit", "Reset & Edit", func() -> void: _request("reset_edit"))
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.clip_text = true
	_status.add_theme_font_size_override("font_size", 16)
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
	if state.entry == "home":
		_sidebar.hide()
	for key: String in _buttons:
		var button: Button = _buttons[key]
		button.disabled = bool(state.menu) and key != "continue"
		if key.begins_with("tool_") or key.begins_with("material_") or key.begins_with("object_") or key.begins_with("mode_") or key in ["copy", "cut", "delete", "grid", "cancel_tool", "filled"]:
			button.disabled = button.disabled or not state.ready or state.mode == "fault"
		if key.begins_with("template_") or key in ["pan_left", "pan_right", "pan_up", "pan_down", "zoom_in", "zoom_out", "fit", "reset", "reset_edit"]:
			button.disabled = button.disabled or state.entry == "home"
	_buttons.tools.text = "Tools: shown" if _sidebar.visible else "Tools: hidden"
	_material_panel.visible = _editor.tool_group == "materials"
	_object_panel.visible = _editor.tool_group == "objects"
	_inspector.visible = state.entry != "home" and _sidebar.visible and _editor.tool_group == "objects"
	_buttons.mode_materials.set_pressed_no_signal(_editor.tool_group == "materials")
	_buttons.mode_objects.set_pressed_no_signal(_editor.tool_group == "objects")
	_update_object_ui(state)
	_buttons.run.visible = state.mode == "edit" and state.entry != "home"
	_buttons.pause.visible = state.mode == "run"
	_buttons.pause.text = "Resume" if state.paused else "Pause"
	_buttons.step.disabled = state.menu or state.mode != "run" or not state.paused or not state.ready
	_buttons.run.disabled = state.menu or not state.ready
	var mode_label: String = "Choose Gallery or Sandbox" if state.entry == "home" else "%s · %s · tick %d" % [str(state.mode).capitalize(), "Paused" if state.paused else "Running", int(state.tick)]
	_status.text = mode_label + ((" · Pristine" if state.pristine else " · Modified") if state.mode == "run" else "")
	if state.tool_busy:
		_status.text += " · Tool held"
	_buttons.undo.disabled = state.menu or state.mode != "edit" or not bool(state.document.get("can_undo", false))
	_buttons.redo.disabled = state.menu or state.mode != "edit" or not bool(state.document.get("can_redo", false))
	_editor_info.text = _editor.notice
	if not str(state.last_refusal).is_empty():
		_editor_info.text = _refusal_label(str(state.last_refusal))
	if SandfallMaterialTools.in_bounds(_editor.hover):
		_editor_info.text += "\nCell %d,%d · zoom %.2f×" % [_editor.hover.x, _editor.hover.y, float(_canvas.state().zoom)]
	for tool_id: String in SandfallEditorController.TOOL_IDS:
		_buttons["tool_" + tool_id].set_pressed_no_signal(_editor.tool == tool_id)
	if not str(state.error).is_empty():
		_status.text = "Stopped: " + str(state.error)
		_status.add_theme_color_override("font_color", Color("ff9c81"))
	else:
		_status.remove_theme_color_override("font_color")


func observation() -> Dictionary:
	var result: Dictionary = _session.state()
	var rendering: Dictionary = _canvas.state()
	result.native["object_definitions"] = SandfallRapierObjectRegistry.logical_graph(result.native.get("object_definitions", []))
	var buttons: Dictionary = {}
	for key: String in _buttons:
		var button: Button = _buttons[key]
		if button.is_visible_in_tree():
			var rect: Rect2 = button.get_global_rect()
			buttons[key] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	var editor_state: Dictionary = _editor.state()
	editor_state["object_inspector"] = _object_inspector_observation()
	editor_state["tools_visible"] = _sidebar.visible
	result.merge({"schema": "sandfall-host-v1", "app_ready": true, "frame": _frame,
		"input": {"held_keys": _held_keys.keys(), "pointer_buttons": _pointer_buttons.size(),
			"gesture_active": _pan_active or _editor.state().gesture_active, "pending_ui_gestures": _button_gestures.size(), "clear_serial": _clear_serial},
		"actor_count": _count_actor_nodes(get_tree().root), "paint_commands": result.mutation_count,
		"editor": editor_state, "editor_controls": _editor_control_rects(),
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


func _toggle_tools() -> void:
	_clear_input("tools_panel")
	if _session.state().entry != "home":
		_sidebar.visible = not _sidebar.visible


func _editor_button(parent: Node, key: String, label: String, callback: Callable) -> Button:
	var button: Button = _add_button(parent, key, label, callback)
	button.custom_minimum_size = Vector2(72, 30)
	button.add_theme_font_size_override("font_size", 15)
	return button


func _build_editor(mode_parent: Node) -> void:
	var shared: VBoxContainer = VBoxContainer.new()
	shared.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shared.add_theme_constant_override("separation", 4)
	_sidebar.add_child(shared)
	var modes: HBoxContainer = HBoxContainer.new()
	mode_parent.add_child(modes)
	for group: String in ["materials", "objects"]:
		var choice: String = group
		var button: Button = _editor_button(modes, "mode_" + group, group.capitalize(), func() -> void:
			_clear_input("tool_group")
			_editor.set_tool_group(choice)
		)
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_material_panel = VBoxContainer.new()
	_material_panel.add_theme_constant_override("separation", 4)
	shared.add_child(_material_panel)
	var panel: VBoxContainer = _material_panel
	var search: LineEdit = LineEdit.new()
	search.name = "MaterialSearch"
	search.placeholder_text = "Search material / family / ID"
	search.add_theme_font_size_override("font_size", 15)
	panel.add_child(search)
	_primary_palette = OptionButton.new()
	_secondary_palette = OptionButton.new()
	for palette: OptionButton in [_primary_palette, _secondary_palette]:
		palette.fit_to_longest_item = false
		palette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		palette.custom_minimum_size = Vector2(230, 28)
		palette.add_theme_font_size_override("font_size", 15)
		panel.add_child(palette)
	_primary_palette.item_selected.connect(func(index: int) -> void:
		_clear_input("palette_change")
		_editor.select_material(_primary_palette.get_item_id(index))
	)
	_secondary_palette.item_selected.connect(func(index: int) -> void:
		_clear_input("palette_change")
		_editor.select_material(_secondary_palette.get_item_id(index), true)
	)
	search.text_changed.connect(func(value: String) -> void: _populate_palettes(value))
	var quick: HBoxContainer = HBoxContainer.new()
	panel.add_child(quick)
	for pair: Array in [[2, "sand", "Sand"], [3, "water", "Water"], [1, "wall", "Wall"]]:
		var id: int = int(pair[0])
		_editor_button(quick, "material_" + str(pair[1]), str(pair[2]), func() -> void:
			_clear_input("palette_change")
			_editor.select_material(id)
		)
	var tool_grid: GridContainer = GridContainer.new()
	tool_grid.columns = 3
	panel.add_child(tool_grid)
	for tool_id: String in SandfallEditorController.TOOL_IDS:
		var choice: String = tool_id
		var label: String = "Rect" if choice == "rectangle" else choice.capitalize()
		var button: Button = _editor_button(tool_grid, "tool_" + choice, label, func() -> void:
			_clear_input("tool_change")
			_editor.set_tool(choice)
		)
		button.toggle_mode = true
	var brush_row: HBoxContainer = HBoxContainer.new()
	panel.add_child(brush_row)
	var shape: OptionButton = OptionButton.new()
	shape.add_item("Circle")
	shape.add_item("Square")
	shape.add_item("Ratio rect")
	shape.add_theme_font_size_override("font_size", 14)
	brush_row.add_child(shape)
	_brush_width = SpinBox.new()
	_brush_height = SpinBox.new()
	for dimension: SpinBox in [_brush_width, _brush_height]:
		dimension.min_value = 1
		dimension.max_value = 32
		dimension.value = 5
		dimension.custom_minimum_size.x = 65
		dimension.add_theme_font_size_override("font_size", 14)
		brush_row.add_child(dimension)
	_brush_height.editable = false
	shape.item_selected.connect(func(index: int) -> void:
		_clear_input("footprint_change")
		_editor.footprint = ["circle", "square", "rectangle"][index]
		_brush_height.editable = index == 2
		if index != 2: _brush_height.value = _brush_width.value
	)
	_brush_width.value_changed.connect(func(value: float) -> void:
		_clear_input("brush_size")
		_editor.brush_size.x = int(value)
		if _editor.footprint != "rectangle": _brush_height.value = value
	)
	_brush_height.value_changed.connect(func(value: float) -> void:
		_clear_input("brush_size")
		_editor.brush_size.y = int(value)
	)
	var temperature_row: HBoxContainer = HBoxContainer.new()
	panel.add_child(temperature_row)
	var temperature_label: Label = Label.new()
	temperature_label.text = "T (native units)"
	temperature_label.add_theme_font_size_override("font_size", 14)
	temperature_row.add_child(temperature_label)
	_temperature = SpinBox.new()
	_temperature.min_value = -32768
	_temperature.max_value = 32767
	_temperature.value = 200
	_temperature.custom_minimum_size.x = 105
	_temperature.add_theme_font_size_override("font_size", 14)
	temperature_row.add_child(_temperature)
	_temperature.value_changed.connect(func(value: float) -> void:
		_clear_input("temperature")
		_editor.set_temperature(int(value))
	)
	var options: HBoxContainer = HBoxContainer.new()
	panel.add_child(options)
	var fill_button: Button = _editor_button(options, "filled", "Filled", func() -> void:
		_clear_input("shape_style")
		_editor.filled = not _editor.filled
		_buttons.filled.text = "Filled" if _editor.filled else "Outline"
	)
	fill_button.tooltip_text = "Rectangle: filled area or exact outline"
	_editor_button(options, "grid", "Grid/rulers", func() -> void:
		_clear_input("grid")
		_editor.grid = not _editor.grid
	)
	var clipboard_row: HBoxContainer = HBoxContainer.new()
	panel.add_child(clipboard_row)
	for action: String in ["copy", "cut", "delete"]:
		var command: String = action
		_editor_button(clipboard_row, action, action.capitalize(), func() -> void:
			_clear_input("clipboard")
			_editor.clipboard_action(command)
		)
	_build_object_tools(shared)
	var history_row: HBoxContainer = HBoxContainer.new()
	shared.add_child(history_row)
	_editor_button(history_row, "undo", "Undo", func() -> void: _request("undo"))
	_editor_button(history_row, "redo", "Redo", func() -> void: _request("redo"))
	_editor_button(history_row, "cancel_tool", "Cancel", func() -> void: _session.clear_pending_input("explicit_cancel"))
	_editor_info = Label.new()
	_editor_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_editor_info.custom_minimum_size.x = 230
	_editor_info.add_theme_font_size_override("font_size", 14)
	shared.add_child(_editor_info)
	_populate_palettes("")
	_editor.settings_changed.connect(_sync_editor_settings)


func _populate_palettes(filter_text: String) -> void:
	_primary_palette.clear()
	_secondary_palette.clear()
	for row: Dictionary in _editor.catalogue():
		var searchable: String = "%d %s %s" % [int(row.id), str(row.name), str(row.family)]
		if not filter_text.is_empty() and not filter_text.to_lower() in searchable.to_lower():
			continue
		var swatch: Image = Image.create(14, 14, false, Image.FORMAT_RGBA8)
		swatch.fill(row.rgba)
		var icon: ImageTexture = ImageTexture.create_from_image(swatch)
		_primary_palette.add_icon_item(icon, "L: " + searchable, int(row.id))
		_secondary_palette.add_icon_item(icon, "R: " + searchable, int(row.id))
		for palette: OptionButton in [_primary_palette, _secondary_palette]:
			palette.set_item_tooltip(palette.item_count - 1, searchable + (" · native rule available" if row.rule_available else " · native rule not implemented"))
	_sync_editor_settings()


func _sync_editor_settings() -> void:
	var primary_id: int = int(_editor.primary[0])
	var secondary_id: int = int(_editor.secondary[0])
	# A filtered list must never display a different material as the active slot.
	for pair: Array in [[_primary_palette, primary_id], [_secondary_palette, secondary_id]]:
		var palette: OptionButton = pair[0]
		var id: int = pair[1]
		var selected: int = -1
		for index: int in range(palette.item_count):
			if palette.get_item_id(index) == id: selected = index
		if selected < 0:
			for row: Dictionary in _editor.catalogue():
				if int(row.id) == id:
					palette.add_item("Current: %d %s" % [id, row.name], id)
					selected = palette.item_count - 1
					break
		palette.select(selected)
	if _temperature != null:
		_temperature.set_value_no_signal(float(SandfallMaterialTools.tuple_values(_editor.primary).temperature))


func _editor_control_rects() -> Dictionary:
	var out: Dictionary = {}
	for pair: Array in [["temperature", _temperature.get_line_edit()], ["brush_width", _brush_width.get_line_edit()], ["brush_height", _brush_height.get_line_edit()]]:
		var control: Control = pair[1]
		if control.is_visible_in_tree():
			var rect: Rect2 = control.get_global_rect()
			out[str(pair[0])] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	for field: String in _inspector_fields:
		var control: Control = _inspector_fields[field]
		if control is SpinBox:
			control = control.get_line_edit()
		if control.is_visible_in_tree():
			var rect: Rect2 = control.get_global_rect()
			out["object_" + field] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	return out


func _build_object_tools(parent: Node) -> void:
	_object_panel = VBoxContainer.new()
	_object_panel.add_theme_constant_override("separation", 5)
	parent.add_child(_object_panel)
	var explanation: Label = Label.new()
	explanation.text = "Physical objects · Rapier boxes\nDrag to create or manipulate."
	explanation.add_theme_font_size_override("font_size", 15)
	_object_panel.add_child(explanation)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	_object_panel.add_child(grid)
	for tool_id: String in SandfallEditorController.OBJECT_TOOL_IDS:
		var choice: String = tool_id
		var button: Button = _editor_button(grid, "object_" + tool_id, tool_id.capitalize(), func() -> void:
			_clear_input("object_tool")
			_editor.set_object_tool(choice)
		)
		button.toggle_mode = true
	_editor_button(grid, "object_clear", "Clear", func() -> void:
		_clear_input("object_deselect")
		_editor.select_object("")
	)
	_object_count = Label.new()
	_object_count.add_theme_font_size_override("font_size", 15)
	_object_panel.add_child(_object_count)
	_object_list = ItemList.new()
	_object_list.custom_minimum_size = Vector2(230, 150)
	_object_list.add_theme_font_size_override("font_size", 13)
	_object_list.item_selected.connect(func(index: int) -> void:
		_clear_input("object_list")
		_editor.select_object(str(_object_list.get_item_metadata(index)))
	)
	_object_panel.add_child(_object_list)
	var help: Label = Label.new()
	help.text = "Boxes stay separate from materials.\nRight inspector: exact values, then Apply.\nEdit history includes object changes."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 230
	help.add_theme_font_size_override("font_size", 14)
	_object_panel.add_child(help)


func _build_object_inspector(parent: Node) -> void:
	_inspector = PanelContainer.new()
	_inspector.custom_minimum_size = Vector2(264, 0)
	_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inspector.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(_inspector)
	var margin: MarginContainer = MarginContainer.new()
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 8)
	_inspector.add_child(margin)
	var panel: VBoxContainer = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 5)
	margin.add_child(panel)
	_inspector_title = Label.new()
	_inspector_title.text = "Object inspector"
	_inspector_title.add_theme_font_size_override("font_size", 16)
	_inspector_title.clip_text = true
	panel.add_child(_inspector_title)
	_inspector_mode = Label.new()
	_inspector_mode.add_theme_font_size_override("font_size", 13)
	_inspector_mode.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector_mode.custom_minimum_size.x = 240
	panel.add_child(_inspector_mode)
	var actions: HBoxContainer = HBoxContainer.new()
	panel.add_child(actions)
	_editor_button(actions, "object_apply", "Apply", _apply_object_inspector)
	_editor_button(actions, "object_duplicate", "Duplicate", func() -> void:
		_clear_input("object_duplicate")
		_editor.object_action("duplicate")
	)
	_editor_button(actions, "object_delete", "Delete", func() -> void:
		_clear_input("object_delete")
		_editor.object_action("delete")
	)
	var tabs: HBoxContainer = HBoxContainer.new()
	panel.add_child(tabs)
	for tab: String in ["shape", "physics", "motion"]:
		var choice: String = tab
		var button: Button = _editor_button(tabs, "object_tab_" + tab, tab.capitalize(), func() -> void:
			_clear_input("inspector_tab")
			_inspector_tab = choice
		)
		button.toggle_mode = true
		var page: VBoxContainer = VBoxContainer.new()
		page.add_theme_constant_override("separation", 3)
		_inspector_tabs[tab] = page
		panel.add_child(page)
	var shape: VBoxContainer = _inspector_tabs.shape
	var name_row: HBoxContainer = _inspector_row(shape, "Name")
	var object_name: LineEdit = LineEdit.new()
	object_name.max_length = 128
	object_name.custom_minimum_size.x = 135
	object_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	object_name.add_theme_font_size_override("font_size", 14)
	object_name.placeholder_text = "Optional name"
	name_row.add_child(object_name)
	_inspector_fields["name"] = object_name
	object_name.focus_entered.connect(func() -> void: _clear_input("inspector_focus"))
	_inspector_spin(shape, "x", "X (cells)", 0, 1024, 0.01)
	_inspector_spin(shape, "y", "Y (cells)", 0, 1024, 0.01)
	_inspector_spin(shape, "width", "Width (cells)", 1, 256, 0.01)
	_inspector_spin(shape, "height", "Height (cells)", 1, 256, 0.01)
	_inspector_spin(shape, "rotation", "Angle (degrees)", -360, 360, 0.01)
	_inspector_check(shape, "fixed", "Fixed (static collision)")
	_inspector_check(shape, "frozen", "Frozen (static until released)")
	var physics: VBoxContainer = _inspector_tabs.physics
	_inspector_spin(physics, "mass", "Mass (units)", 0.001, 1000000, 0.001)
	_inspector_spin(physics, "friction", "Friction", 0, 1, 0.01)
	_inspector_spin(physics, "restitution", "Restitution", 0, 1, 0.01)
	_inspector_spin(physics, "linear_damping", "Linear damp (s⁻¹)", 0, 100, 0.01)
	_inspector_spin(physics, "angular_damping", "Angular damp (s⁻¹)", 0, 100, 0.01)
	_inspector_spin(physics, "gravity_scale", "Gravity scale", 0, 4, 0.001)
	var motion: VBoxContainer = _inspector_tabs.motion
	_inspector_spin(motion, "vx", "Velocity X (cells/s)", -4096, 4096, 0.01)
	_inspector_spin(motion, "vy", "Velocity Y (cells/s)", -4096, 4096, 0.01)
	_inspector_spin(motion, "angular_velocity", "Spin (degrees/s)", -5729, 5729, 0.01)
	_inspector_check(motion, "passive_subject", "Passive subject (no controls)")
	var note: Label = Label.new()
	note.text = "Edit: initial velocities.\nRun: explicit live intervention.\nNo actor motor or physical rewind."
	note.add_theme_font_size_override("font_size", 13)
	motion.add_child(note)
	_editor_button(panel, "object_refresh", "Refresh observed pose", func() -> void:
		_clear_input("inspector_refresh")
		_editor.refresh_object_selection()
	)
	_inspector.hide()


func _inspector_row(parent: Node, label: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	parent.add_child(row)
	var title: Label = Label.new()
	title.text = label
	title.custom_minimum_size.x = 109
	title.add_theme_font_size_override("font_size", 13)
	row.add_child(title)
	return row


func _inspector_spin(parent: Node, key: String, label: String, minimum: float, maximum: float, increment: float) -> void:
	var row: HBoxContainer = _inspector_row(parent, label)
	var field: SpinBox = SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = increment
	field.custom_minimum_size.x = 126
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_font_size_override("font_size", 14)
	row.add_child(field)
	_inspector_fields[key] = field
	field.get_line_edit().focus_entered.connect(func() -> void: _clear_input("inspector_focus"))


func _inspector_check(parent: Node, key: String, label: String) -> void:
	var field: CheckBox = CheckBox.new()
	field.text = label
	field.add_theme_font_size_override("font_size", 13)
	field.focus_mode = Control.FOCUS_NONE
	parent.add_child(field)
	_inspector_fields[key] = field
	field.toggled.connect(func(_value: bool) -> void: _clear_input("inspector_flag"))


func _update_object_ui(state: Dictionary) -> void:
	var definitions: Array = _session.object_definitions()
	var identities: Array = []
	for definition: Dictionary in definitions:
		identities.append([str(definition.id), str(definition.get("name", ""))])
	if identities != _object_list_ids:
		_object_list_ids = identities.duplicate(true)
		_object_list.clear()
		for row: Array in identities:
			_object_list.add_item(str(row[0]) + (" · " + str(row[1]) if not str(row[1]).is_empty() else ""))
			_object_list.set_item_metadata(_object_list.item_count - 1, str(row[0]))
	_object_count.text = "%d / 16 bodies · stable identities" % definitions.size()
	for index: int in range(_object_list.item_count):
		if str(_object_list.get_item_metadata(index)) == _editor.selected_object_id:
			_object_list.select(index)
		else:
			_object_list.deselect(index)
	for tool_id: String in SandfallEditorController.OBJECT_TOOL_IDS:
		_buttons["object_" + tool_id].set_pressed_no_signal(_editor.object_tool == tool_id)
	var selected: Dictionary = _editor.selected_object()
	var has_selection: bool = not selected.is_empty()
	_inspector_title.text = str(selected.id) if has_selection else "Select a physical box"
	_inspector_mode.text = "Edit · exact initial definition" if state.mode == "edit" else "Run · staged live intervention"
	if has_selection:
		_inspector_mode.text += "\nApply commits one transaction."
	for key: String in ["object_apply", "object_duplicate", "object_delete", "object_refresh"]:
		_buttons[key].disabled = _buttons[key].disabled or not has_selection
	for key: String in _inspector_fields:
		var field: Control = _inspector_fields[key]
		if field is SpinBox or field is LineEdit:
			field.editable = has_selection and state.ready and not state.menu
		elif field is CheckBox:
			field.disabled = not has_selection or not state.ready or state.menu
	for tab: String in _inspector_tabs:
		_inspector_tabs[tab].visible = tab == _inspector_tab
		_buttons["object_tab_" + tab].set_pressed_no_signal(tab == _inspector_tab)
	if _inspector_loaded_serial != _editor.selection_serial:
		_inspector_loaded_serial = _editor.selection_serial
		_load_object_inspector(selected, state.mode == "run")


func _load_object_inspector(definition: Dictionary, use_live_pose: bool) -> void:
	_inspector_object_id = str(definition.get("id", ""))
	_inspector_baseline.clear()
	if definition.is_empty():
		return
	var logical: Dictionary = definition.duplicate(true)
	if use_live_pose:
		var observed: Dictionary = _editor.selected_object_view()
		if not observed.is_empty():
			logical.position = observed.position
			logical.rotation = observed.rotation
			logical.linear_velocity = observed.linear_velocity
			logical.angular_velocity = observed.angular_velocity
	var values: Dictionary = {"name": str(logical.name), "x": logical.position.x, "y": logical.position.y,
		"width": logical.size.x, "height": logical.size.y, "rotation": rad_to_deg(float(logical.rotation)),
		"mass": logical.mass, "friction": logical.friction, "restitution": logical.restitution,
		"linear_damping": logical.linear_damp, "angular_damping": logical.angular_damp,
		"gravity_scale": logical.gravity_scale, "vx": logical.linear_velocity.x, "vy": logical.linear_velocity.y,
		"angular_velocity": rad_to_deg(float(logical.angular_velocity)), "fixed": logical.fixed,
		"frozen": logical.frozen, "passive_subject": logical.passive_subject}
	for key: String in values:
		var field: Control = _inspector_fields[key]
		if field is SpinBox:
			field.set_value_no_signal(float(values[key]))
		elif field is LineEdit:
			field.text = str(values[key])
		else:
			field.set_pressed_no_signal(bool(values[key]))
	# The displayed rounded values are the baseline, so touching mass alone
	# never rounds or resets another physical property or the current pose.
	_inspector_baseline = _inspector_values()


func _inspector_values() -> Dictionary:
	var values: Dictionary = {}
	for key: String in _inspector_fields:
		var field: Control = _inspector_fields[key]
		if field is SpinBox:
			values[key] = field.value
		elif field is LineEdit:
			values[key] = field.text
		else:
			values[key] = field.button_pressed
	return values


func _apply_object_inspector() -> void:
	_clear_input("inspector_apply")
	if _inspector_object_id.is_empty() or _inspector_object_id != _editor.selected_object_id:
		return
	var current: Dictionary = _inspector_values()
	var exact: Dictionary = _editor.selected_object_view() if _session.state().mode == "run" else _editor.selected_object()
	if exact.is_empty():
		return
	var desired_position: Vector2 = exact.position
	var desired_size: Vector2 = exact.size
	var desired_velocity: Vector2 = exact.linear_velocity
	# Preserve unedited vector components at full native precision. During Run
	# the untouched pose/velocity component comes from the current live sample.
	if current.x != _inspector_baseline.x: desired_position.x = float(current.x)
	if current.y != _inspector_baseline.y: desired_position.y = float(current.y)
	if current.width != _inspector_baseline.width: desired_size.x = float(current.width)
	if current.height != _inspector_baseline.height: desired_size.y = float(current.height)
	if current.vx != _inspector_baseline.vx: desired_velocity.x = float(current.vx)
	if current.vy != _inspector_baseline.vy: desired_velocity.y = float(current.vy)
	var changes: Dictionary = {}
	for key: String in current:
		if current[key] == _inspector_baseline.get(key):
			continue
		match key:
			"x", "y": changes["position"] = desired_position
			"width", "height": changes["size"] = desired_size
			"rotation": changes["rotation"] = deg_to_rad(float(current.rotation))
			"vx", "vy": changes["linear_velocity"] = desired_velocity
			"angular_velocity": changes["angular_velocity"] = deg_to_rad(float(current.angular_velocity))
			"linear_damping": changes["linear_damp"] = current[key]
			"angular_damping": changes["angular_damp"] = current[key]
			_: changes[key] = current[key]
	if changes.is_empty():
		_editor.notice = "No changed object values to apply."
		return
	_editor.apply_object_changes(changes)


func _object_inspector_observation() -> Dictionary:
	return {"selected_id": _inspector_object_id, "tab": _inspector_tab,
		"values": _inspector_values(), "baseline": _inspector_baseline.duplicate(true),
		"visible": _inspector.visible, "units": "cells; Godot/Rapier mass units; seconds; UI degrees converted to radians"}


func _refusal_label(reason: String) -> String:
	match reason:
		"object_capacity_16": return "Maximum 16 bodies. Delete a box before adding another."
		"object_transform_outside_world": return "The complete rotated box must fit inside the world."
		"invalid_object_dimensions": return "Box dimensions must be between 1 and 256 cells."
		"history_capacity": return "Edit history is full. This change was not applied."
		"intervention_journal_capacity": return "This Run's intervention journal is full. Reset to begin a new Run."
		_: return "Refused: " + reason.replace("_", " ")
