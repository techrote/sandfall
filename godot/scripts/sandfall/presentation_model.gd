class_name SandfallPresentationModel
extends RefCounted

# Logical, non-physical decoration. The document owns this copied value; neither
# the validator nor the renderer can write material cells or Rapier state.
const MAX_ANNOTATIONS: int = 128
const MAX_POINTS: int = 4096
const MAX_STROKE_POINTS: int = 256
const THEMES: Array[String] = ["classic", "muted", "contrast"]


static func defaults() -> Dictionary:
	return {"schema_version": 1, "style": {"theme": "classic", "annotations_visible": true}, "annotations": []}


static func validate(value: Variant) -> Dictionary:
	if not value is Dictionary or not _keys(value, ["schema_version", "style", "annotations"]):
		return _refuse("presentation_structure")
	if not _integer(value.schema_version) or int(value.schema_version) != 1:
		return _refuse("presentation_schema_version")
	var style: Variant = value.style
	if not style is Dictionary or not _keys(style, ["theme", "annotations_visible"]) \
			or not style.theme is String or style.theme not in THEMES or not style.annotations_visible is bool:
		return _refuse("presentation_style")
	if not value.annotations is Array or value.annotations.size() > MAX_ANNOTATIONS:
		return _refuse("presentation_annotation_capacity")
	var ids: Dictionary = {}
	var count: int = 0
	var annotations: Array = []
	for item: Variant in value.annotations:
		if not item is Dictionary or not _keys(item, ["id", "type", "points", "color", "width", "text"]):
			return _refuse("presentation_annotation_structure")
		if not item.id is String or not _id(item.id) or ids.has(item.id):
			return _refuse("presentation_annotation_id")
		ids[item.id] = true
		if not item.type is String or item.type not in ["label", "stroke"] \
				or not item.color is String or not _color(item.color) \
				or not _number(item.width) or float(item.width) < 1.0 or float(item.width) > 32.0 \
				or not item.text is String or item.text.length() > 128 or item.text.to_utf8_buffer().has(0):
			return _refuse("presentation_annotation_parameters")
		if not item.points is Array or item.points.is_empty() or item.points.size() > MAX_STROKE_POINTS:
			return _refuse("presentation_points")
		if (item.type == "label" and (item.points.size() != 1 or item.text.strip_edges().is_empty())) \
				or (item.type == "stroke" and (item.points.size() < 2 or not item.text.is_empty())):
			return _refuse("presentation_annotation_type")
		var points: Array = []
		for point: Variant in item.points:
			if not point is Array or point.size() != 2 or not _number(point[0]) or not _number(point[1]) \
					or float(point[0]) < 0.0 or float(point[0]) > 1024.0 or float(point[1]) < 0.0 or float(point[1]) > 1024.0:
				return _refuse("presentation_point_bounds")
			points.append([float(point[0]), float(point[1])])
		count += points.size()
		if count > MAX_POINTS:
			return _refuse("presentation_point_capacity")
		annotations.append({"id": item.id, "type": item.type, "points": points,
			"color": str(item.color).to_lower(), "width": float(item.width), "text": item.text})
	var normalized: Dictionary = {"schema_version": 1, "style": style.duplicate(true), "annotations": annotations}
	return {"ok": true, "accepted": true, "presentation": normalized, "value": normalized.duplicate(true), "error": "", "reason": ""}


static func payload_bytes(value: Dictionary) -> int:
	return JSON.stringify(value, "", true, true).to_utf8_buffer().size()


static func _keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key: Variant in value:
		if not key is String or key not in expected:
			return false
	return true


static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _id(value: String) -> bool:
	if value.is_empty() or value.length() > 64:
		return false
	for index: int in value.length():
		var code: int = value.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code in [45, 95]):
			return false
	return true


static func _color(value: String) -> bool:
	if value.length() != 9 or not value.begins_with("#"):
		return false
	for character: String in value.substr(1).to_lower():
		if character not in "0123456789abcdef":
			return false
	return true


static func _refuse(reason: String) -> Dictionary:
	return {"ok": false, "accepted": false, "error": reason, "reason": reason}
