class_name SandfallEditorController
extends RefCounted

signal settings_changed

const Tools = preload("res://scripts/sandfall/material_tools.gd")
const OBJECT_TOOL_IDS: Array[String] = ["box", "select", "move", "rotate", "resize"]
const TOOL_IDS: Array[String] = ["pencil", "erase", "picker", "line", "rectangle", "fill", "select", "move", "paste"]

var tool: String = "picker"
var tool_group: String = "materials"
var object_tool: String = "select"
var selected_object_id: String = ""
var selection_serial: int = 0
var _object_gesture: Dictionary = {}
var _pending_object: Dictionary = {}
var footprint: String = "circle"
var brush_size: Vector2i = Vector2i(5, 5)
var filled: bool = true
var grid: bool = false
var primary: PackedByteArray = PackedByteArray([2, 0, 0, 200, 0])
var secondary: PackedByteArray = PackedByteArray([3, 255, 0, 200, 0])
var selection_rect: Rect2i = Rect2i()
var notice: String = "Choose a tool. Edits do not advance physics."
var inspected: Dictionary = {}
var hover: Vector2i = Vector2i(-1, -1)

var _session: SandfallSessionController
var _canvas: SandfallWorldCanvas
var _bridge: Variant
var _catalogue: Array = []
var _gesture: Dictionary = {}
var _stroke_cells: Dictionary = {}
var _clipboard: PackedByteArray = PackedByteArray()
var _clipboard_size: Vector2i = Vector2i.ZERO
var _filler: SandfallMaterialTools = SandfallMaterialTools.new()
var _fill_context: Dictionary = {}
var _fill_processed: int = 0
var _pending_selection: Dictionary = {}


func _init(session: SandfallSessionController, canvas: SandfallWorldCanvas) -> void:
	_session = session
	_canvas = canvas
	_session.document_changed.connect(_selection_committed)
	_bridge = ClassDB.instantiate(&"SandfallEditBridge")
	if _bridge != null:
		_catalogue = _bridge.catalogue()


func catalogue() -> Array:
	return _catalogue.duplicate(true)


func select_material(id: int, alternate: bool = false) -> void:
	for row: Dictionary in _catalogue:
		if int(row.id) == id:
			var value: PackedByteArray = Tools.cell_tuple(id, int(row.state_a), int(row.state_b), int(row.temperature))
			if alternate:
				secondary = value
			else:
				primary = value
			settings_changed.emit()
			return
	notice = "Invalid material ID refused."


func set_temperature(value: int) -> void:
	var decoded: Dictionary = Tools.tuple_values(primary)
	var candidate: PackedByteArray = Tools.cell_tuple(int(decoded.id), int(decoded.state_a), int(decoded.state_b), value)
	if candidate.size() == 5:
		primary = candidate
		settings_changed.emit()


func set_tool(value: String) -> void:
	cancel("tool_changed")
	if value in TOOL_IDS:
		tool = value
		if tool == "picker":
			selection_rect = Rect2i()
		notice = "Tool: " + tool.capitalize()
		settings_changed.emit()


func pointer(event: InputEvent) -> void:
	if tool_group == "objects":
		_object_pointer(event)
		return
	if not _fill_context.is_empty():
		return
	var state: Dictionary = _session.state()
	if not state.ready or state.menu or state.mode not in ["edit", "run"]:
		return
	if event is InputEventMouseMotion:
		var point: Vector2i = _cell_at(event.global_position)
		hover = point
		if not _gesture.is_empty():
			if not Tools.in_bounds(point):
				cancel("outside_world")
				return
			if tool in ["pencil", "erase"]:
				for cell: Vector2i in Tools.line(_gesture.last, point):
					Tools.stamp(_stroke_cells, cell, brush_size, footprint)
			_gesture.last = point
		return
	if not event is InputEventMouseButton or event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	var point: Vector2i = _cell_at(event.global_position)
	hover = point
	if not Tools.in_bounds(point):
		cancel("outside_world")
		return
	if event.pressed:
		cancel("new_gesture")
		var revision: int = int(state.document.get("revision", -1))
		_gesture = {"first": point, "last": point, "button": event.button_index,
			"generation": int(state.generation), "epoch": int(state.input_epoch), "revision": revision,
			"value": (secondary if event.button_index == MOUSE_BUTTON_RIGHT else primary).duplicate()}
		if tool in ["pencil", "erase"]:
			Tools.stamp(_stroke_cells, point, brush_size, footprint)
		return
	if _gesture.is_empty() or int(_gesture.button) != event.button_index:
		return # A release never creates an operation without a fresh admitted press.
	if tool in ["pencil", "erase"]:
		for cell: Vector2i in Tools.line(_gesture.last, point):
			Tools.stamp(_stroke_cells, cell, brush_size, footprint)
	var context: Dictionary = _gesture.duplicate(true)
	context.last = point
	var indices: PackedInt32Array = Tools.sorted_indices(_stroke_cells)
	_gesture.clear()
	_stroke_cells.clear()
	if int(context.generation) != int(state.generation) or int(context.epoch) != int(state.input_epoch):
		notice = "Retired gesture refused."
		return
	match tool:
		"picker":
			_pick(point, event.button_index == MOUSE_BUTTON_RIGHT)
		"select":
			selection_rect = Tools.selection(context.first, point)
			notice = "Selection %d × %d" % [selection_rect.size.x, selection_rect.size.y]
		"fill":
			_begin_fill(point, context)
		"paste":
			_paste(point, false, context)
		"move":
			if selection_rect.has_area() and selection_rect.has_point(context.first):
				_paste(selection_rect.position + point - Vector2i(context.first), true, context)
			else:
				notice = "Start Move inside a rectangular selection."
		"line":
			_send(Tools.stroke(Tools.line(context.first, point), brush_size, footprint), context.value, "line", context)
		"rectangle":
			_send(Tools.rectangle(context.first, point, filled), context.value, "rectangle", context)
		"pencil", "erase":
			var value: PackedByteArray = PackedByteArray([0, 0, 0, 200, 0]) if tool == "erase" else context.value
			_send(indices, value, tool + "_stroke", context)


func pump() -> void:
	if _fill_context.is_empty():
		return
	var state: Dictionary = _session.state()
	if int(state.generation) != int(_fill_context.generation) or int(state.input_epoch) != int(_fill_context.epoch) or state.menu:
		cancel("retired_fill")
		return
	var progress: Dictionary = _filler.pump_fill()
	_fill_processed = int(progress.processed)
	notice = "Fill preview: %d cells · Cancel to discard" % _fill_processed
	if bool(progress.done):
		var context: Dictionary = _fill_context.duplicate(true)
		_fill_context.clear()
		_send(progress.indices, context.value, "flood_fill", context)
		_session.end_tool_hold()


func cancel(reason: String = "cancelled") -> void:
	var was_active: bool = not _gesture.is_empty() or not _fill_context.is_empty() or not _object_gesture.is_empty()
	_gesture.clear()
	_object_gesture.clear()
	_stroke_cells.clear()
	_pending_selection.clear()
	_fill_context.clear()
	_filler.cancel_fill()
	_session.end_tool_hold()
	hover = Vector2i(-1, -1)
	if reason in ["session_replaced", "fault", "partial_edit_fault"]:
		selection_rect = Rect2i()
		inspected = {}
		selected_object_id = ""
		_pending_object.clear()
		selection_serial += 1
	if was_active:
		notice = "Uncommitted operation discarded: " + reason


func clipboard_action(action: String) -> void:
	cancel("clipboard_command")
	var state: Dictionary = _session.state()
	if not state.ready or state.menu or state.mode not in ["edit", "run"] or not selection_rect.has_area():
		notice = "Select a rectangle first."
		return
	var capture: Dictionary = _session.editing_snapshot()
	if not bool(capture.ok):
		notice = str(capture.error)
		return
	if action in ["copy", "cut"]:
		_clipboard = _bridge.extract_rectangle(capture.cells, selection_rect)
		_clipboard_size = selection_rect.size
		notice = "Copied %d × %d exact material/state/temperature tuples" % [_clipboard_size.x, _clipboard_size.y]
	if action in ["cut", "delete"]:
		_send(Tools.rectangle(selection_rect.position, selection_rect.end - Vector2i.ONE, true),
			PackedByteArray([0, 0, 0, 200, 0]), action, _context())


func state() -> Dictionary:
	return {"tool": tool, "footprint": footprint, "brush_size": [brush_size.x, brush_size.y],
		"filled": filled, "grid": grid, "primary": Tools.tuple_values(primary), "secondary": Tools.tuple_values(secondary),
		"selection": [selection_rect.position.x, selection_rect.position.y, selection_rect.size.x, selection_rect.size.y],
		"clipboard_size": [_clipboard_size.x, _clipboard_size.y], "gesture_active": not _gesture.is_empty() or not _object_gesture.is_empty(),
		"tool_group": tool_group, "object_tool": object_tool, "selected_object_id": selected_object_id,
		"selection_serial": selection_serial, "object_gesture_active": not _object_gesture.is_empty(),
		"selected_object": _json_object(selected_object()), "object_preview": _json_object(object_preview()),
		"fill_active": not _fill_context.is_empty(), "fill_processed": _fill_processed,
		"hover": [hover.x, hover.y], "inspected": inspected.duplicate(true), "notice": notice,
		"preview_first": _point_values(_gesture.get("first", Vector2i(-1, -1))),
		"preview_last": _point_values(_gesture.get("last", Vector2i(-1, -1)))}


func _begin_fill(point: Vector2i, context: Dictionary) -> void:
	if not _session.begin_tool_hold(int(context.generation), int(context.epoch)):
		return
	var capture: Dictionary = _session.editing_snapshot()
	if not bool(capture.ok) or not _filler.start_fill(capture.get("cells", PackedByteArray()), point):
		_session.end_tool_hold()
		notice = "Fill snapshot refused."
		return
	_fill_context = context
	_fill_processed = 0


func _pick(point: Vector2i, alternate: bool) -> void:
	var capture: Dictionary = _session.editing_snapshot()
	if not bool(capture.ok):
		return
	var index: int = (point.y * 1024 + point.x) * 5
	var value: PackedByteArray = PackedByteArray(capture.cells).slice(index, index + 5)
	inspected = Tools.tuple_values(value)
	inspected["x"] = point.x
	inspected["y"] = point.y
	if alternate:
		secondary = value.duplicate()
	else:
		primary = value.duplicate()
	notice = "Cell %d,%d · ID %d · a=%d b=%d T=%d" % [point.x, point.y, inspected.id, inspected.state_a, inspected.state_b, inspected.temperature]
	settings_changed.emit()


func _paste(destination: Vector2i, move: bool, context: Dictionary) -> void:
	var capture: Dictionary = _session.editing_snapshot()
	if not bool(capture.ok):
		return
	var payload: PackedByteArray = _bridge.extract_rectangle(capture.cells, selection_rect) if move else _clipboard.duplicate()
	var dimensions: Vector2i = selection_rect.size if move else _clipboard_size
	if payload.is_empty():
		notice = "Clipboard is empty."
		return
	var target: Rect2i = Rect2i(destination, dimensions)
	var patch: Dictionary = _bridge.selection_patch(capture.cells, selection_rect, target, payload, move)
	if not bool(patch.ok):
		notice = str(patch.error)
		return
	if _session.enqueue_mutation(patch.indices, patch.after, "selection_move" if move else "selection_paste",
		int(context.revision), int(context.generation), int(context.epoch)):
		_pending_selection = {"target": target, "generation": int(context.generation), "mutation_count": int(_session.state().mutation_count) + 1, "kind": "selection_move" if move else "selection_paste"}
		notice = "Selection operation queued."


func _send(indices: PackedInt32Array, value: PackedByteArray, kind: String, context: Dictionary) -> void:
	var desired: PackedByteArray = _bridge.repeated_tuple(value, indices.size())
	var accepted: bool = _session.enqueue_mutation(indices, desired, kind,
		int(context.revision), int(context.generation), int(context.epoch))
	notice = ("Queued %s (%d cells)" % [kind, indices.size()]) if accepted else str(_session.state().last_refusal)


func _context() -> Dictionary:
	var state: Dictionary = _session.state()
	return {"generation": int(state.generation), "epoch": int(state.input_epoch), "revision": int(state.document.get("revision", -1))}


func _cell_at(global_position: Vector2) -> Vector2i:
	if not _canvas.global_content_rect().has_point(global_position):
		return Vector2i(-1, -1)
	var world: Vector2 = _canvas.global_to_world(global_position)
	return Vector2i(floori(world.x), floori(world.y))


static func _point_values(point: Vector2i) -> Array:
	return [point.x, point.y]


func _selection_committed() -> void:
	_object_committed()
	if _pending_selection.is_empty():
		return
	var observed: Dictionary = _session.state()
	if int(observed.generation) == int(_pending_selection.generation) and int(observed.mutation_count) == int(_pending_selection.mutation_count) and str(observed.last_edit.get("kind", "")) == str(_pending_selection.kind):
		selection_rect = _pending_selection.target
	_pending_selection.clear()


func set_tool_group(value: String) -> void:
	if value not in ["materials", "objects"]:
		return
	cancel("tool_group_changed")
	tool_group = value
	notice = "Material tools: exact cell authoring." if value == "materials" else "Object tools: independent Rapier boxes · maximum 16."
	settings_changed.emit()


func set_object_tool(value: String) -> void:
	if value not in OBJECT_TOOL_IDS:
		return
	cancel("object_tool_changed")
	tool_group = "objects"
	object_tool = value
	notice = {"box": "Drag a box, or click for a 24 × 24 box.", "select": "Click a box to inspect its stable ID.",
		"move": "Drag a box to move it. One release is one transaction.",
		"rotate": "Drag around a box centre to rotate it.", "resize": "Drag from a box corner to resize around its centre."}[value]
	settings_changed.emit()


func select_object(id: String) -> void:
	cancel("object_selection")
	selected_object_id = id if not _find_object(id).is_empty() else ""
	selection_serial += 1
	notice = "Selected " + selected_object_id if not selected_object_id.is_empty() else "Object selection cleared."
	settings_changed.emit()


func refresh_object_selection() -> void:
	cancel("inspector_refresh")
	selection_serial += 1
	settings_changed.emit()


func selected_object() -> Dictionary:
	return _find_object(selected_object_id)


func object_views() -> Array:
	# Logical definitions own properties and IDs. Only copied current poses are
	# used for hit-testing; a moving Run body is never selected at its old pose.
	var definitions: Array = _session.object_definitions()
	var native: Dictionary = _session.state().native
	var ids: Array = native.get("body_ids", [])
	var poses: Array = native.get("body_states", [])
	for definition: Dictionary in definitions:
		var slot: int = ids.find(str(definition.id))
		if slot >= 0 and slot < poses.size():
			definition.position = Vector2(float(poses[slot][0]), float(poses[slot][1]))
			definition.rotation = float(poses[slot][2])
			definition.linear_velocity = Vector2(float(poses[slot][3]), float(poses[slot][4]))
			definition.angular_velocity = float(poses[slot][5])
	return definitions


func selected_object_view() -> Dictionary:
	for definition: Dictionary in object_views():
		if str(definition.id) == selected_object_id:
			return definition
	return {}


func object_preview() -> Dictionary:
	if _object_gesture.is_empty():
		return {}
	return _object_gesture.get("preview", {}).duplicate(true)


func apply_object_changes(changes: Dictionary) -> bool:
	cancel("inspector_apply")
	if selected_object_id.is_empty():
		notice = "Select an object first."
		return false
	return _send_object({"operation": "update", "id": selected_object_id, "changes": changes.duplicate(true)}, _object_context())


func object_action(action: String) -> void:
	cancel("object_command")
	if selected_object_id.is_empty():
		notice = "Select an object first."
		return
	if action in ["duplicate", "delete"]:
		_send_object({"operation": action, "id": selected_object_id}, _object_context())


func _find_object(id: String) -> Dictionary:
	if id.is_empty():
		return {}
	for definition: Dictionary in _session.object_definitions():
		if str(definition.id) == id:
			return definition.duplicate(true)
	return {}


func _object_at(point: Vector2) -> Dictionary:
	var definitions: Array = object_views()
	for index: int in range(definitions.size() - 1, -1, -1):
		var definition: Dictionary = definitions[index]
		var local: Vector2 = (point - Vector2(definition.position)).rotated(-float(definition.rotation))
		var half: Vector2 = Vector2(definition.size) * 0.5
		if absf(local.x) <= half.x and absf(local.y) <= half.y:
			return definition
	return {}


func _object_pointer(event: InputEvent) -> void:
	var observed: Dictionary = _session.state()
	if not observed.ready or observed.menu or observed.mode not in ["edit", "run"]:
		return
	if not event is InputEventMouseMotion and not event is InputEventMouseButton:
		return
	var global_point: Vector2 = event.global_position
	if not _canvas.global_content_rect().has_point(global_point):
		cancel("outside_world")
		return
	var point: Vector2 = _canvas.global_to_world(global_point)
	hover = Vector2i(floori(point.x), floori(point.y))
	if event is InputEventMouseMotion:
		if not _object_gesture.is_empty():
			_object_gesture.last = point
			_update_object_preview(point)
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		cancel("new_object_gesture")
		var action: String = object_tool
		var picked: Dictionary = _object_at(point)
		if object_tool == "select":
			var handle: Dictionary = _object_handle_at(point)
			if not handle.is_empty():
				action = str(handle.action)
				picked = handle.definition
		if action != "box":
			if picked.is_empty() and object_tool in ["rotate", "resize"]:
				picked = selected_object_view()
			if picked.is_empty():
				select_object("")
				return
			selected_object_id = str(picked.id)
			selection_serial += 1
			settings_changed.emit()
			if action == "select":
				notice = "Selected " + selected_object_id
				return
		if not _session.begin_tool_hold(int(observed.generation), int(observed.input_epoch)):
			return
		_object_gesture = _object_context()
		_object_gesture.merge({"first": point, "last": point, "tool": action, "original": picked.duplicate(true), "preview": {}})
		_update_object_preview(point)
		return
	if _object_gesture.is_empty():
		return
	_update_object_preview(point)
	var context: Dictionary = _object_gesture.duplicate(true)
	_object_gesture.clear()
	if int(context.generation) != int(observed.generation) or int(context.epoch) != int(observed.input_epoch):
		_session.end_tool_hold()
		notice = "Retired object gesture refused."
		return
	var preview: Dictionary = context.preview
	if str(context.tool) == "box":
		_send_object({"operation": "spawn", "definition": preview}, context)
	else:
		var changes: Dictionary = {}
		var field: String = {"move": "position", "rotate": "rotation", "resize": "size"}[str(context.tool)]
		changes[field] = preview[field]
		_send_object({"operation": "update", "id": str(context.original.id), "changes": changes}, context)
	_session.end_tool_hold()


func _update_object_preview(point: Vector2) -> void:
	var original: Dictionary = _object_gesture.original
	var action: String = str(_object_gesture.tool)
	var preview: Dictionary = original.duplicate(true)
	var first: Vector2 = _object_gesture.first
	if action == "box":
		var dimensions: Vector2 = (point - first).abs()
		if dimensions.length() < 2.0:
			preview = {"position": first, "size": Vector2(24, 24), "rotation": 0.0}
		else:
			preview = {"position": (first + point) * 0.5, "size": Vector2(maxf(2.0, dimensions.x), maxf(2.0, dimensions.y)), "rotation": 0.0}
	elif action == "move":
		preview.position = Vector2(original.position) + point - first
	elif action == "rotate":
		var initial_vector: Vector2 = first - Vector2(original.position)
		var current_vector: Vector2 = point - Vector2(original.position)
		if initial_vector.length_squared() > 0.01 and current_vector.length_squared() > 0.01:
			preview.rotation = wrapf(float(original.rotation) + current_vector.angle() - initial_vector.angle(), -PI, PI)
	elif action == "resize":
		var local: Vector2 = (point - Vector2(original.position)).rotated(-float(original.rotation))
		preview.size = Vector2(maxf(1.0, absf(local.x) * 2.0), maxf(1.0, absf(local.y) * 2.0))
	_object_gesture.preview = preview


func _send_object(operation: Dictionary, context: Dictionary) -> bool:
	var before_ids: Array[String] = []
	for definition: Dictionary in _session.object_definitions():
		before_ids.append(str(definition.id))
	var accepted: bool = _session.enqueue_object_edit(operation,
		int(context.revision), int(context.generation), int(context.epoch))
	if accepted:
		_pending_object = {"generation": int(context.generation), "before_ids": before_ids,
			"operation": str(operation.operation), "id": str(operation.get("id", ""))}
		notice = "Queued object " + str(operation.operation)
	else:
		notice = "Refused: " + str(_session.state().last_refusal)
	return accepted


func _object_committed() -> void:
	if not _pending_object.is_empty() and int(_pending_object.generation) == int(_session.state().generation):
		if str(_pending_object.operation) in ["spawn", "duplicate"]:
			for definition: Dictionary in _session.object_definitions():
				if str(definition.id) not in _pending_object.before_ids:
					selected_object_id = str(definition.id)
		_pending_object.clear()
	if not selected_object_id.is_empty() and _find_object(selected_object_id).is_empty():
		selected_object_id = ""
	selection_serial += 1
	settings_changed.emit()


static func _json_object(definition: Dictionary) -> Dictionary:
	var result: Dictionary = definition.duplicate(true)
	for field: String in ["position", "size", "linear_velocity"]:
		if result.get(field) is Vector2:
			result[field] = [result[field].x, result[field].y]
	return result


func _object_context() -> Dictionary:
	var observed: Dictionary = _session.state()
	return {"generation": int(observed.generation), "epoch": int(observed.input_epoch),
		"revision": int(observed.document.get("revision", -1)) if observed.mode == "edit" else int(observed.native.get("object_revision", -1))}


func _object_handle_at(point: Vector2) -> Dictionary:
	var definition: Dictionary = selected_object_view()
	if definition.is_empty():
		return {}
	var view: Dictionary = _canvas.state()
	var content: Rect2 = _canvas.content_rect()
	if content.size.x <= 0.0 or content.size.y <= 0.0:
		return {}
	var per_pixel: Vector2 = Vector2(view.view_size[0], view.view_size[1]) / content.size
	var tolerance: float = 6.0 * maxf(per_pixel.x, per_pixel.y)
	var local: Vector2 = (point - Vector2(definition.position)).rotated(-float(definition.rotation))
	var half: Vector2 = Vector2(definition.size) * 0.5
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		if local.distance_to(corner * half) <= tolerance:
			return {"action": "resize", "definition": definition}
	var knob: Vector2 = Vector2(0, -half.y - 12.0 * per_pixel.y)
	if local.distance_to(knob) <= tolerance:
		return {"action": "rotate", "definition": definition}
	return {}
