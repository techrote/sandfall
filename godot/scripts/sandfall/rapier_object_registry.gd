class_name SandfallRapierObjectRegistry
extends RefCounted

# Copied logical definitions only. Stable IDs never enter the native float ABI:
# the host maps this creation-ordered list to transient bounded slots 1..N.
# Length = native cells (Godot pixels), time = seconds, angle = radians, mass =
# Godot/Rapier mass units. No unsupported SI conversion is implied.
const SCHEMA_VERSION: int = 1
const MAX_OBJECTS: int = 16
const MAX_CREATION_ORDER: int = 2147483647
const WORLD_SIZE: float = 1024.0
const MIN_SIZE: float = 1.0
const MAX_SIZE: float = 256.0
# The native coupling parser clamps below this floor. Refuse smaller authored
# masses so Rapier and native feedback always consume the same admitted mass.
const MIN_MASS: float = 0.001
const FIELDS: Array[String] = ["schema_version", "id", "creation_order", "shape", "name",
	"passive_subject", "position", "size", "rotation", "mass", "gravity_scale",
	"friction", "restitution", "linear_damp", "angular_damp", "linear_velocity",
	"angular_velocity", "fixed", "frozen"]
const OPTIONAL_FIELDS: Array[String] = ["name", "passive_subject", "fixed", "frozen"]

var _definitions: Array = []
var _slot_by_id: Dictionary = {}
var _revision: int = 0


static func make_box(id: String, creation_order: int, position: Vector2,
		size: Vector2 = Vector2(16.0, 16.0)) -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "id": id, "creation_order": creation_order,
		"shape": "box", "name": "", "passive_subject": false, "position": position,
		"size": size, "rotation": 0.0, "mass": 1.0, "gravity_scale": 0.094,
		"friction": 0.78, "restitution": 0.0, "linear_damp": 0.15,
		"angular_damp": 0.35, "linear_velocity": Vector2.ZERO,
		"angular_velocity": 0.0, "fixed": false, "frozen": false}


static func validate_graph(candidate: Array) -> Dictionary:
	if candidate.size() > MAX_OBJECTS:
		return _refusal("object_capacity_16")
	var definitions: Array = []
	var ids: Dictionary = {}
	var orders: Dictionary = {}
	for value: Variant in candidate:
		if not value is Dictionary:
			return _refusal("object_definition_not_dictionary")
		var row: Dictionary = value.duplicate(true)
		for key: Variant in row:
			if not key is String or key not in FIELDS:
				return _refusal("unsupported_object_setting")
		for field: String in FIELDS:
			if not row.has(field) and field not in OPTIONAL_FIELDS:
				return _refusal("missing_object_" + field)
		for field: String in OPTIONAL_FIELDS:
			if not row.has(field):
				row[field] = "" if field == "name" else false
		if not row.schema_version is int or row.schema_version != SCHEMA_VERSION:
			return _refusal("unsupported_object_schema")
		if not row.shape is String or row.shape != "box":
			return _refusal("unsupported_object_shape")
		if not row.id is String or not _valid_id(row.id):
			return _refusal("invalid_object_id")
		if ids.has(row.id):
			return _refusal("duplicate_object_id")
		if not row.creation_order is int or row.creation_order < 1 \
				or row.creation_order > MAX_CREATION_ORDER or orders.has(row.creation_order):
			return _refusal("invalid_or_duplicate_creation_order")
		if not row.name is String or row.name.length() > 128 \
				or row.name.to_utf8_buffer().has(0):
			return _refusal("invalid_object_name")
		for field: String in ["passive_subject", "fixed", "frozen"]:
			if not row[field] is bool:
				return _refusal("invalid_object_" + field)
		for field: String in ["position", "size", "linear_velocity"]:
			if not row[field] is Vector2 or not Vector2(row[field]).is_finite():
				return _refusal("invalid_object_" + field)
		var size: Vector2 = row.size
		if size.x < MIN_SIZE or size.y < MIN_SIZE or size.x > MAX_SIZE or size.y > MAX_SIZE:
			return _refusal("invalid_object_dimensions")
		var ranges: Dictionary = {"rotation": [-TAU, TAU], "mass": [MIN_MASS, 1000000.0],
			"gravity_scale": [0.0, 4.0], "friction": [0.0, 1.0], "restitution": [0.0, 1.0],
			"linear_damp": [0.0, 100.0], "angular_damp": [0.0, 100.0],
			"angular_velocity": [-100.0, 100.0]}
		for field: String in ranges:
			if not (row[field] is int or row[field] is float) or not is_finite(float(row[field])) \
					or float(row[field]) < float(ranges[field][0]) or float(row[field]) > float(ranges[field][1]):
				return _refusal("invalid_object_" + field)
			row[field] = float(row[field])
		var velocity: Vector2 = row.linear_velocity
		if absf(velocity.x) > 4096.0 or absf(velocity.y) > 4096.0:
			return _refusal("invalid_object_linear_velocity")
		var position: Vector2 = row.position
		var half: Vector2 = size * 0.5
		var extent: Vector2 = Vector2(absf(cos(row.rotation)) * half.x + absf(sin(row.rotation)) * half.y,
			absf(sin(row.rotation)) * half.x + absf(cos(row.rotation)) * half.y)
		if position.x - extent.x < 0.0 or position.y - extent.y < 0.0 \
				or position.x + extent.x > WORLD_SIZE or position.y + extent.y > WORLD_SIZE:
			return _refusal("object_transform_outside_world")
		ids[row.id] = true
		orders[row.creation_order] = true
		definitions.append(row)
	definitions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.creation_order < b.creation_order)
	return {"ok": true, "error": "", "definitions": definitions}


static func logical_representation(definitions: Array) -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "objects": logical_graph(definitions)}


static func logical_graph(definitions: Array) -> Array:
	var objects: Array = definitions.duplicate(true)
	for row: Dictionary in objects:
		for field: String in ["position", "size", "linear_velocity"]:
			var value: Vector2 = row[field]
			row[field] = [value.x, value.y]
	return objects


static func reconstruct_logical(value: Dictionary) -> Dictionary:
	# Internal versioned logical data for SF-M4; this is not a file/ZIP codec.
	if value.size() != 2 or not (value.get("schema_version") is int or value.get("schema_version") is float) \
			or value.get("schema_version") != SCHEMA_VERSION \
			or not value.get("objects") is Array:
		return _refusal("invalid_logical_object_graph")
	var objects: Array = value.objects.duplicate(true)
	if objects.size() > MAX_OBJECTS:
		return _refusal("object_capacity_16")
	for row: Variant in objects:
		if not row is Dictionary:
			return _refusal("object_definition_not_dictionary")
		for field: String in ["schema_version", "creation_order"]:
			var number: Variant = row.get(field)
			if not (number is int or number is float) or not is_finite(float(number)) \
					or float(number) != floorf(float(number)) or absf(float(number)) > MAX_CREATION_ORDER:
				return _refusal("invalid_logical_" + field)
			row[field] = int(number)
		for field: String in ["position", "size", "linear_velocity"]:
			var vector: Variant = row.get(field)
			if not vector is Array or vector.size() != 2:
				return _refusal("invalid_logical_" + field)
			for component: Variant in vector:
				if not (component is float or component is int) or not is_finite(float(component)):
					return _refusal("invalid_logical_" + field)
			row[field] = Vector2(float(vector[0]), float(vector[1]))
	return validate_graph(objects)


static func logical_payload_bytes(definitions: Array) -> int:
	# Exactly the canonical UTF-8 logical JSON payload, excluding engine allocator
	# overhead. Both before and after graphs are charged by the document/journal.
	return JSON.stringify(logical_representation(definitions), "", true, true).to_utf8_buffer().size()


func install(candidate: Array) -> Dictionary:
	var validation: Dictionary = validate_graph(candidate)
	if not validation.ok:
		return validation
	_definitions = validation.definitions.duplicate(true)
	_slot_by_id.clear()
	for index: int in range(_definitions.size()):
		_slot_by_id[_definitions[index].id] = index + 1
	_revision += 1
	return {"ok": true, "revision": _revision}


func definitions() -> Array:
	return _definitions.duplicate(true)


func definition(id: String) -> Dictionary:
	var slot: int = slot_for_id(id)
	return _definitions[slot - 1].duplicate(true) if slot > 0 else {}


func slot_for_id(id: String) -> int:
	return int(_slot_by_id.get(id, 0))


func id_for_slot(slot: int) -> String:
	return str(_definitions[slot - 1].id) if slot >= 1 and slot <= _definitions.size() else ""


func ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for row: Dictionary in _definitions:
		result.append(row.id)
	return result


static func _valid_id(id: String) -> bool:
	if id.is_empty() or id.length() > 64:
		return false
	for index: int in range(id.length()):
		var code: int = id.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) \
				or (code >= 97 and code <= 122) or code == 45 or code == 95):
			return false
	return true


static func _refusal(error: String) -> Dictionary:
	return {"ok": false, "error": error, "definitions": []}
