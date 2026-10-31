class_name SandfallEditorController
extends RefCounted

signal settings_changed

const Tools = preload("res://scripts/sandfall/material_tools.gd")
const TOOL_IDS: Array[String] = ["pencil", "erase", "picker", "line", "rectangle", "fill", "select", "move", "paste"]

var tool: String = "picker"
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
	var was_active: bool = not _gesture.is_empty() or not _fill_context.is_empty()
	_gesture.clear()
	_stroke_cells.clear()
	_pending_selection.clear()
	_fill_context.clear()
	_filler.cancel_fill()
	_session.end_tool_hold()
	hover = Vector2i(-1, -1)
	if reason in ["session_replaced", "fault", "partial_edit_fault"]:
		selection_rect = Rect2i()
		inspected = {}
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
		"clipboard_size": [_clipboard_size.x, _clipboard_size.y], "gesture_active": not _gesture.is_empty(),
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
	if _pending_selection.is_empty():
		return
	var observed: Dictionary = _session.state()
	if int(observed.generation) == int(_pending_selection.generation) and int(observed.mutation_count) == int(_pending_selection.mutation_count) and str(observed.last_edit.get("kind", "")) == str(_pending_selection.kind):
		selection_rect = _pending_selection.target
	_pending_selection.clear()
