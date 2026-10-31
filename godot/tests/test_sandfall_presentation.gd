extends SceneTree

const Model = preload("res://scripts/sandfall/presentation_model.gd")
var _checks: int = 0
var _failures: Array[String] = []


func _init() -> void:
	var initial: Dictionary = Model.defaults()
	_check(Model.validate(initial).ok, "Default presentation refused")
	var label: Dictionary = {"id": "label-1", "type": "label", "points": [[12.5, 20.0]], "color": "#8de4d7ff", "width": 1.0, "text": "Water is a material"}
	initial.annotations.append(label)
	var checked: Dictionary = Model.validate(initial)
	_check(checked.ok, "Valid annotation refused")
	initial.annotations[0].text = "Mutated caller"
	_check(checked.presentation.annotations[0].text == "Water is a material", "Presentation validator retained caller ownership")
	for change: Dictionary in [{"type": "script"}, {"text": ""}, {"id": "../bad"}, {"points": [[NAN, 5]]}, {"points": [[1025, 5]]}, {"color": "red"}, {"width": 0}, {"width": INF}, {"script": "res://bad.gd"}]:
		var candidate: Dictionary = checked.presentation.duplicate(true)
		candidate.annotations[0].merge(change, true)
		_check(not Model.validate(candidate).ok, "Malformed annotation admitted: " + str(change))
	var duplicate: Dictionary = checked.presentation.duplicate(true)
	duplicate.annotations.append(duplicate.annotations[0].duplicate(true))
	_check(not Model.validate(duplicate).ok, "Duplicate annotation ID admitted")
	var bad_theme: Dictionary = Model.defaults()
	bad_theme.style.theme = "remote-url"
	_check(not Model.validate(bad_theme).ok, "Unknown presentation theme admitted")
	var stroke: Dictionary = Model.defaults()
	stroke.annotations.append({"id": "stroke-1", "type": "stroke", "points": [[0, 0], [1024, 1024]], "color": "#ffffffff", "width": 2.0, "text": ""})
	_check(Model.validate(stroke).ok, "Bounded expressive stroke refused")
	_check(Model.payload_bytes(stroke) == JSON.stringify(stroke, "", true, true).to_utf8_buffer().size(), "Presentation logical history payload is incorrectly accounted")
	var capacity: Dictionary = Model.defaults()
	for index: int in 129:
		var value: Dictionary = label.duplicate(true)
		value.id = "capacity-%d" % index
		capacity.annotations.append(value)
	_check(not Model.validate(capacity).ok, "Annotation129 admitted")
	var point_capacity: Dictionary = Model.defaults()
	for index: int in 17:
		var points: Array = []
		for point: int in 256: points.append([point, index])
		point_capacity.annotations.append({"id": "points-%d" % index, "type": "stroke", "points": points, "color": "#ffffffff", "width": 1.0, "text": ""})
	_check(not Model.validate(point_capacity).ok, "4096-point aggregate capacity not enforced")
	print("SANDFALL_PRESENTATION_RESULT ", JSON.stringify({"ok": _failures.is_empty(), "checks": _checks, "failures": _failures}))
	quit(0 if _failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(message)
		print("SF_M4_PRESENTATION_FAILURE ", message)
