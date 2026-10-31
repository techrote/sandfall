class_name SandfallEditorOverlay
extends Control

# Only gizmos/rulers. This Control does not inherit the material shader and
# has no native or session mutation API. Terminal visual tests clear gizmos.
var canvas: SandfallWorldCanvas
var editor: SandfallEditorController


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	use_parent_material = false
	clip_contents = true


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if canvas == null or editor == null:
		return
	var view: Dictionary = canvas.state()
	var rect: Rect2 = canvas.content_rect()
	var origin: Vector2 = Vector2(view.camera_origin[0], view.camera_origin[1])
	var world_size: Vector2 = Vector2(view.view_size[0], view.view_size[1])
	var scale: Vector2 = rect.size / world_size
	if editor.grid:
		var stride: int = 1 if scale.x >= 8.0 else 32
		var font: Font = ThemeDB.fallback_font
		for x: int in range(ceili(origin.x / stride) * stride, mini(1024, ceili(origin.x + world_size.x)), stride):
			var px: float = rect.position.x + (x - origin.x) * scale.x
			draw_line(Vector2(px, rect.position.y), Vector2(px, rect.end.y), Color(1, 1, 1, 0.12))
			if x % 64 == 0: draw_string(font, Vector2(px + 2, rect.position.y + 14), str(x), HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		for y: int in range(ceili(origin.y / stride) * stride, mini(1024, ceili(origin.y + world_size.y)), stride):
			var py: float = rect.position.y + (y - origin.y) * scale.y
			draw_line(Vector2(rect.position.x, py), Vector2(rect.end.x, py), Color(1, 1, 1, 0.12))
			if y % 64 == 0: draw_string(font, Vector2(rect.position.x + 2, py + 14), str(y), HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	if editor.selection_rect.has_area():
		_outline(editor.selection_rect, rect, origin, scale, Color("87d8ff"))
	var state: Dictionary = editor.state()
	if bool(state.gesture_active):
		var first: Vector2i = Vector2i(state.preview_first[0], state.preview_first[1])
		var last: Vector2i = Vector2i(state.preview_last[0], state.preview_last[1])
		if editor.tool in ["rectangle", "select"]:
			_outline(SandfallMaterialTools.selection(first, last), rect, origin, scale, Color("f4ce74"))
		elif editor.tool == "line":
			draw_line(rect.position + (Vector2(first) + Vector2(0.5, 0.5) - origin) * scale,
				rect.position + (Vector2(last) + Vector2(0.5, 0.5) - origin) * scale, Color("f4ce74"), 1.5)
	if SandfallMaterialTools.in_bounds(editor.hover) and editor.tool in ["pencil", "erase"]:
		var footprint: Vector2i = editor.brush_size
		if editor.footprint != "rectangle": footprint.y = footprint.x
		var top_left: Vector2i = editor.hover - (footprint - Vector2i.ONE) / 2
		_outline(Rect2i(top_left, footprint), rect, origin, scale, Color("ffffff"))


func _outline(world_rect: Rect2i, content: Rect2, origin: Vector2, scale: Vector2, colour: Color) -> void:
	var screen: Rect2 = Rect2(content.position + (Vector2(world_rect.position) - origin) * scale, Vector2(world_rect.size) * scale)
	screen = screen.intersection(content)
	if screen.has_area():
		draw_rect(screen, colour, false, 1.5)
