class_name SandfallPresentationOverlay
extends Control

# Pure copied-data projection. These annotations and passive-subject markers
# never enter material ownership, sampling, collision, or actor input.
var canvas: SandfallWorldCanvas
var session: SandfallSessionController
var preview_points: Array = []
var preview_color: Color = Color("8de4d7")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	use_parent_material = false
	clip_contents = true


func _process(_delta: float) -> void:
	if canvas != null:
		var content: Rect2 = canvas.content_rect()
		position = content.position
		size = content.size
	queue_redraw()


func _draw() -> void:
	if canvas == null or session == null:
		return
	var view: Dictionary = canvas.state()
	# Clip to the actual fitted world viewport, including after zoom/pan and
	# resize. Letterbox pixels and adjacent controls are not decoration space.
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var origin: Vector2 = Vector2(view.camera_origin[0], view.camera_origin[1])
	var scale: Vector2 = rect.size / Vector2(view.view_size[0], view.view_size[1])
	var presentation: Dictionary = session.presentation()
	if bool(presentation.get("style", {}).get("annotations_visible", true)):
		for annotation: Dictionary in presentation.get("annotations", []):
			_draw_annotation(annotation, rect, origin, scale)
	if preview_points.size() > 1:
		var points: PackedVector2Array = PackedVector2Array()
		for point: Array in preview_points:
			points.append(rect.position + (Vector2(point[0], point[1]) - origin) * scale)
		draw_polyline(points, preview_color, 2.0, true)
	var state: Dictionary = session.state()
	var ids: Array = state.get("body_ids", [])
	var poses: Array = state.get("body_poses", [])
	for object: Dictionary in state.get("object_definitions", []):
		if not bool(object.get("passive_subject", false)):
			continue
		var index: int = ids.find(object.id)
		if index < 0 or index >= poses.size():
			continue
		var point: Vector2 = rect.position + (Vector2(poses[index][0], poses[index][1]) - origin) * scale
		if rect.has_point(point):
			draw_arc(point, 10.0, 0.0, TAU, 24, Color("f4ce74"), 2.0, true)
			draw_string(ThemeDB.fallback_font, point + Vector2(13, -8), "Subject", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f4ce74"))


func _draw_annotation(annotation: Dictionary, rect: Rect2, origin: Vector2, scale: Vector2) -> void:
	var color: Color = Color(str(annotation.color))
	var points: PackedVector2Array = PackedVector2Array()
	for value: Array in annotation.points:
		points.append(rect.position + (Vector2(value[0], value[1]) - origin) * scale)
	if str(annotation.type) == "label":
		if not points.is_empty() and rect.has_point(points[0]):
			draw_string(ThemeDB.fallback_font, points[0], str(annotation.text), HORIZONTAL_ALIGNMENT_LEFT, maxf(0.0, rect.end.x - points[0].x), 16, color)
	elif points.size() > 1:
		draw_polyline(points, color, maxf(1.0, float(annotation.width) * scale.x), true)
