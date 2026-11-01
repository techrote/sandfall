class_name SandfallArchiveCodec
extends RefCounted

# Portable authored initial state, never a live-world continuation. The codec
# builds copied candidates only. The session owns isolated native/Rapier
# readiness and the final replacement transaction.
const Registry = preload("res://scripts/sandfall/rapier_object_registry.gd")
const Presentation = preload("res://scripts/sandfall/presentation_model.gd")
const StrictJSON = preload("res://scripts/sandfall/archive_json.gd")
const Zip = preload("res://scripts/sandfall/archive_zip.gd")
const SCHEMA_VERSION: int = 1
const WORLD_BYTES: int = 1024 * 1024 * 5
const MANIFEST: String = "project/manifest.json"
const REQUIRED: Array[String] = ["scene/scene.json", "scene/objects.json", "world/cells.bin",
	"presentation/style.json", "presentation/annotations.json"]
const SOURCE_KEYS: Array[String] = ["source_commit", "source_tree", "native_source_commit",
	"native_runtime_sha256", "rapier_version", "rapier_runtime_sha256", "godot_version", "build_profile"]
const DEFINITION_KEYS: Array[String] = ["id", "title", "revision", "world_size", "initial_view",
	"rectangles", "bodies", "simulation_origin", "simulation_size", "simulation_margin", "cadence_lod",
	"initial_cells", "object_schema_version", "authored_revision", "authored_cells_sha256",
	"project", "presentation", "assets", "notes", "project_source"]


static func encode_definition(definition: Dictionary, source_identity: Dictionary = {}) -> Dictionary:
	var files: Dictionary = _logical_files(definition, source_identity)
	if not files.ok:
		return files
	var packed: Dictionary = Zip.pack(files.files)
	if not packed.ok:
		return _refuse(packed.error)
	return {"ok": true, "accepted": true, "error": "", "reason": "", "bytes": packed.bytes,
		"manifest": files.manifest.duplicate(true), "logical_sha256": files.logical_sha256,
		"logical_hash": files.logical_sha256, "physical_sha256": files.physical_sha256}


static func encode(definition: Dictionary, source_identity: Dictionary = {}) -> Dictionary:
	return encode_definition(definition, source_identity)


static func canonical_identity(definition: Dictionary, source_identity: Dictionary = {}) -> Dictionary:
	var files: Dictionary = _logical_files(definition, source_identity)
	if not files.ok:
		return files
	return {"ok": true, "error": "", "logical_sha256": files.logical_sha256,
		"physical_sha256": files.physical_sha256, "manifest": files.manifest.duplicate(true)}


static func inspect_zip(bytes: PackedByteArray) -> Dictionary:
	return Zip.inspect(bytes)


static func decode(bytes: PackedByteArray) -> Dictionary:
	return decode_bytes(bytes)


static func decode_bytes(bytes: PackedByteArray) -> Dictionary:
	var unpacked: Dictionary = Zip.unpack(bytes)
	if not unpacked.ok:
		return _refuse(unpacked.error)
	return decode_files(unpacked.files)


static func decode_files(files: Dictionary) -> Dictionary:
	# The exact same file-map validator handles ZIP contents and a developer's
	# extracted project folder; it never reads a caller-supplied filesystem path.
	if not files.has(MANIFEST) or files.size() > Zip.MAX_ENTRIES:
		return _refuse("manifest_missing_or_file_capacity")
	var total: int = 0
	var names: Dictionary = {}
	for key: Variant in files:
		if not key is String or not Zip.valid_path(key) or key.ends_with("/") \
				or Zip.entry_limit(key) < 0 or not files[key] is PackedByteArray \
				or files[key].size() > Zip.entry_limit(key) or names.has(key.to_lower()):
			return _refuse("project_file_type_path_or_capacity")
		names[key.to_lower()] = true
		total += files[key].size()
	if total > Zip.MAX_EXPANDED_BYTES:
		return _refuse("zip_expanded_capacity")
	var parsed_manifest: Dictionary = _parse_object(files[MANIFEST])
	if not parsed_manifest.ok:
		return parsed_manifest
	var manifest: Dictionary = parsed_manifest.value
	if not _keys(manifest, ["format", "schema_version", "project", "scene", "versions", "source", "files"]) \
			or manifest.format != "sandfall-project" or not _integer(manifest.schema_version, 1, 1) \
			or manifest.scene != "scene/scene.json":
		return _refuse("unsupported_project_manifest_schema")
	if not manifest.project is Dictionary or not _keys(manifest.project, ["id", "title"]) \
			or not _identifier(manifest.project.id) or not _text(manifest.project.title, 1, 128):
		return _refuse("invalid_project_identity")
	if not manifest.versions is Dictionary or not _keys(manifest.versions, ["cells", "objects", "presentation"]):
		return _refuse("unsupported_content_versions")
	for version: Variant in manifest.versions.values():
		if not _integer(version, 1, 1):
			return _refuse("unsupported_content_versions")
	var source: Dictionary = validate_source(manifest.source)
	if not source.ok:
		return source
	if not manifest.files is Dictionary or manifest.files.size() != files.size() - 1:
		return _refuse("manifest_inventory_mismatch")
	for required: String in REQUIRED:
		if not manifest.files.has(required):
			return _refuse("required_project_file_missing")
	for relative: Variant in manifest.files:
		if not relative is String or relative == "manifest.json" \
				or not files.has("project/" + relative):
			return _refuse("manifest_path_not_present")
		var record: Variant = manifest.files[relative]
		if not record is Dictionary or not _keys(record, ["sha256", "bytes"]) \
				or not _digest(record.sha256, 64) \
				or not _integer(record.bytes, 0, Zip.MAX_EXPANDED_BYTES):
			return _refuse("invalid_manifest_file_record")
		var content: PackedByteArray = files["project/" + relative]
		if content.size() != int(record.bytes) or sha256(content) != record.sha256:
			return _refuse("project_file_size_or_digest_mismatch")
	var parsed_scene: Dictionary = _parse_object(files["project/scene/scene.json"])
	if not parsed_scene.ok:
		return parsed_scene
	var scene: Dictionary = parsed_scene.value
	var scene_checked: Dictionary = _validate_scene(scene, source.source)
	if not scene_checked.ok:
		return scene_checked
	var parsed_objects: Dictionary = _parse_object(files["project/scene/objects.json"])
	if not parsed_objects.ok:
		return parsed_objects
	var object_graph: Dictionary = Registry.reconstruct_logical(parsed_objects.value)
	if not object_graph.ok:
		return _refuse(object_graph.error)
	var style: Dictionary = _parse_object(files["project/presentation/style.json"])
	var annotations: Dictionary = _parse_object(files["project/presentation/annotations.json"])
	if not style.ok or not annotations.ok:
		return _refuse("invalid_presentation_json")
	if not _keys(style.value, ["schema_version", "style"]) \
			or not _integer(style.value.schema_version, 1, 1) \
			or not _keys(annotations.value, ["schema_version", "annotations"]) \
			or not _integer(annotations.value.schema_version, 1, 1):
		return _refuse("unsupported_presentation_file_schema")
	var presentation: Dictionary = {"schema_version": 1, "style": style.value.style,
		"annotations": annotations.value.annotations}
	var assets: Dictionary = {}
	for path: String in files:
		if path.begins_with("project/assets/"):
			assets[path.trim_prefix("project/")] = PackedByteArray(files[path]).duplicate()
	var notes: String = ""
	if files.has("project/README.md"):
		if not StrictJSON.valid_utf8(files["project/README.md"]):
			return _refuse("notes_invalid_utf8")
		notes = PackedByteArray(files["project/README.md"]).get_string_from_utf8()
		if notes.to_utf8_buffer() != files["project/README.md"]:
			return _refuse("notes_invalid_utf8")
	var definition: Dictionary = {
		"id": manifest.project.id, "title": manifest.project.title, "revision": 1,
		"world_size": Vector2i(1024, 1024), "initial_view": Vector2i(480, 270),
		"rectangles": PackedInt32Array([0, 0, 1024, 1024, 0]),
		"bodies": object_graph.definitions, "initial_cells": PackedByteArray(files["project/world/cells.bin"]).duplicate(),
		"simulation_origin": _vector2i(scene.interest.origin),
		"simulation_size": _vector2i(scene.interest.size),
		"simulation_margin": _vector2i(scene.interest.margin), "cadence_lod": false,
		"project": scene_checked.project, "presentation": presentation, "assets": assets, "notes": notes,
		"project_source": scene.origin_source.duplicate(true),
	}
	var checked: Dictionary = validate_definition(definition, source.source)
	if not checked.ok:
		return checked
	var identity: Dictionary = canonical_identity(checked.definition, source.source)
	if not identity.ok:
		return identity
	return {"ok": true, "accepted": true, "error": "", "reason": "",
		"definition": checked.definition, "candidate": checked.definition.duplicate(true),
		"manifest": manifest.duplicate(true), "logical_sha256": identity.logical_sha256,
		"logical_hash": identity.logical_sha256, "physical_sha256": identity.physical_sha256}


static func validate_definition(value: Dictionary, source_identity: Dictionary = {}) -> Dictionary:
	for key: Variant in value:
		# Godot's dictionary dot assignment may add a StringName key to an
		# otherwise String-keyed in-memory snapshot. Canonical JSON still emits
		# plain strings and decoded archives accept only JSON string members.
		if not (key is String or key is StringName) or str(key) not in DEFINITION_KEYS:
			return _refuse("unsupported_initial_definition_setting:" + str(key))
	if not _identifier(value.get("id")) or not _text(value.get("title"), 1, 128) \
			or value.get("world_size") != Vector2i(1024, 1024) \
			or value.get("initial_view") != Vector2i(480, 270) \
			or not value.get("initial_cells") is PackedByteArray \
			or value.initial_cells.size() != WORLD_BYTES or not value.get("bodies") is Array:
		return _refuse("invalid_initial_definition")
	if not ClassDB.class_exists(&"SandfallEditBridge"):
		return _refuse("native_material_validator_unavailable")
	var bridge: Variant = ClassDB.instantiate(&"SandfallEditBridge")
	var cells: Dictionary = bridge.validate_cells(value.initial_cells)
	if not bool(cells.get("ok", false)):
		return _refuse(str(cells.get("error", "invalid_cell_tuple")))
	var graph: Dictionary = Registry.validate_graph(value.bodies)
	if not graph.ok:
		return _refuse(graph.error)
	var source: Dictionary = validate_source(source_identity if not source_identity.is_empty() else local_source_identity())
	if not source.ok:
		return source
	for key: String in ["simulation_origin", "simulation_size", "simulation_margin"]:
		if not value.get(key) is Vector2i:
			return _refuse("invalid_authored_interest")
	var interest: Dictionary = {"policy": "authored-window-v1", "origin": _array2(value.simulation_origin),
		"size": _array2(value.simulation_size), "margin": _array2(value.simulation_margin)}
	if not _valid_interest(interest) or not value.get("cadence_lod") is bool or value.cadence_lod:
		return _refuse("unsupported_initial_solver_policy")
	var metadata: Variant = value.get("project", project_defaults(graph.definitions))
	if not metadata is Dictionary:
		return _refuse("invalid_project_metadata")
	var project: Dictionary = _validate_project(metadata)
	if not project.ok:
		return project
	var passive: Array[String] = []
	for row: Dictionary in graph.definitions:
		if row.passive_subject:
			passive.append(row.id)
	if passive.size() > 1 or (passive.size() == 1 and project.project.passive_subject_id != passive[0]) \
			or (passive.is_empty() and project.project.passive_subject_id != ""):
		return _refuse("passive_subject_identity_mismatch")
	var presentation: Dictionary = Presentation.validate(value.get("presentation", Presentation.defaults()))
	if not presentation.ok:
		return _refuse(str(presentation.get("error", presentation.get("reason", "invalid_presentation"))))
	var assets_value: Variant = value.get("assets", {})
	if not assets_value is Dictionary or assets_value.size() + REQUIRED.size() + 2 > Zip.MAX_ENTRIES:
		return _refuse("asset_count_or_type")
	var assets: Dictionary = {}
	var asset_names: Dictionary = {}
	var total_asset_bytes: int = 0
	for path: Variant in assets_value:
		if not path is String or not path.begins_with("assets/") or not path.ends_with(".png") \
				or not Zip.valid_path("project/" + path) or asset_names.has(path.to_lower()) \
				or not assets_value[path] is PackedByteArray:
			return _refuse("unsupported_asset_type_or_path")
		asset_names[path.to_lower()] = true
		var image: Dictionary = _validate_png(assets_value[path])
		if not image.ok:
			return image
		total_asset_bytes += assets_value[path].size()
		if total_asset_bytes > Zip.MAX_EXPANDED_BYTES - WORLD_BYTES - 6 * Zip.MAX_JSON_BYTES:
			return _refuse("asset_total_capacity")
		assets[path] = PackedByteArray(assets_value[path]).duplicate()
	var notes: Variant = value.get("notes", "")
	if not notes is String or notes.to_utf8_buffer().size() > Zip.MAX_JSON_BYTES or notes.to_utf8_buffer().has(0):
		return _refuse("invalid_project_notes")
	var origin_source: Dictionary = source.source
	if value.has("project_source"):
		var original: Dictionary = validate_source(value.project_source)
		if not original.ok:
			return original
		origin_source = original.source
	var normalized: Dictionary = {"id": value.id, "title": value.title, "revision": 1,
		"world_size": Vector2i(1024, 1024), "initial_view": Vector2i(480, 270),
		"rectangles": PackedInt32Array([0, 0, 1024, 1024, 0]),
		"bodies": graph.definitions.duplicate(true), "object_schema_version": 1,
		"initial_cells": PackedByteArray(value.initial_cells).duplicate(),
		"simulation_origin": value.simulation_origin, "simulation_size": value.simulation_size,
		"simulation_margin": value.simulation_margin, "cadence_lod": false,
		"project": project.project.duplicate(true), "presentation": presentation.presentation.duplicate(true),
		"assets": assets, "notes": notes, "project_source": origin_source.duplicate(true)}
	return {"ok": true, "error": "", "definition": normalized, "source": source.source.duplicate(true)}


static func project_defaults(bodies: Array = []) -> Dictionary:
	var passive: String = ""
	for row: Dictionary in bodies:
		if bool(row.get("passive_subject", false)):
			passive = str(row.get("id", ""))
	return {"schema_version": 1, "kind": "kinetic_sandbox", "seed": 0,
		"startup": "edit_paused", "camera": {"origin": [0, 0], "size": [480, 270], "zoom": 1.0},
		"events": [], "expectations": [], "passive_subject_id": passive}


static func local_source_identity() -> Dictionary:
	return {"source_commit": "local-unpublished", "source_tree": "local-unpublished",
		"native_source_commit": "local-unpublished", "native_runtime_sha256": "unattested",
		"rapier_version": "0.35.2", "rapier_runtime_sha256": "unattested",
		"godot_version": "4.7.stable.official.5b4e0cb0f", "build_profile": "local"}


static func validate_source(value: Variant) -> Dictionary:
	if not value is Dictionary or not _keys(value, SOURCE_KEYS):
		return _refuse("invalid_source_identity_fields")
	if value.build_profile not in ["compat", "threaded", "local"] \
			or value.rapier_version != "0.35.2" or value.godot_version != "4.7.stable.official.5b4e0cb0f":
		return _refuse("unsupported_runtime_identity")
	for field: String in ["source_commit", "source_tree", "native_source_commit"]:
		if not _digest(value[field], 40) and not (value.build_profile == "local" and value[field] == "local-unpublished"):
			return _refuse("invalid_source_revision")
	for field: String in ["native_runtime_sha256", "rapier_runtime_sha256"]:
		if not _digest(value[field], 64) and not (value.build_profile == "local" and value[field] == "unattested"):
			return _refuse("invalid_runtime_digest")
	return {"ok": true, "error": "", "source": value.duplicate(true)}


static func sha256(bytes: PackedByteArray) -> String:
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


static func canonical_json(value: Variant) -> PackedByteArray:
	return (JSON.stringify(value, "\t", true, true) + "\n").to_utf8_buffer()


static func _logical_files(value: Dictionary, source_identity: Dictionary) -> Dictionary:
	var checked: Dictionary = validate_definition(value, source_identity)
	if not checked.ok:
		return checked
	var definition: Dictionary = checked.definition
	var source: Dictionary = checked.source
	var scene: Dictionary = {"schema_version": 1, "kind": definition.project.kind,
		"world_size": [1024, 1024], "fixed_hz": 60, "seed": definition.project.seed,
		"solver": {"policy": "cybersand-default-v1", "cadence_lod": false},
		"interest": {"policy": "authored-window-v1", "origin": _array2(definition.simulation_origin),
			"size": _array2(definition.simulation_size), "margin": _array2(definition.simulation_margin)},
		"camera": definition.project.camera.duplicate(true), "startup": definition.project.startup,
		"events": definition.project.events.duplicate(true), "passive_subject_id": definition.project.passive_subject_id,
		"expectations": definition.project.expectations.duplicate(true), "source": source.duplicate(true),
		"origin_source": definition.project_source.duplicate(true)}
	var files: Dictionary = {"project/scene/scene.json": canonical_json(scene),
		"project/scene/objects.json": canonical_json(Registry.logical_representation(definition.bodies)),
		"project/world/cells.bin": definition.initial_cells.duplicate(),
		"project/presentation/style.json": canonical_json({"schema_version": 1, "style": definition.presentation.style}),
		"project/presentation/annotations.json": canonical_json({"schema_version": 1, "annotations": definition.presentation.annotations})}
	if not definition.notes.is_empty():
		files["project/README.md"] = definition.notes.to_utf8_buffer()
	for asset: String in definition.assets:
		files["project/" + asset] = definition.assets[asset].duplicate()
	var inventory: Dictionary = {}
	for path: String in files:
		inventory[path.trim_prefix("project/")] = {"sha256": sha256(files[path]), "bytes": files[path].size()}
	var manifest: Dictionary = {"format": "sandfall-project", "schema_version": 1,
		"project": {"id": definition.id, "title": definition.title}, "scene": "scene/scene.json",
		"versions": {"cells": 1, "objects": 1, "presentation": 1}, "source": source.duplicate(true), "files": inventory}
	files[MANIFEST] = canonical_json(manifest)
	var physical_objects: Dictionary = Registry.logical_representation(definition.bodies)
	for body: Dictionary in physical_objects.objects:
		body.erase("name")
		body.erase("passive_subject")
	var physical: Dictionary = {"cells_sha256": inventory["world/cells.bin"].sha256,
		"objects": physical_objects, "world_size": [1024, 1024], "fixed_hz": 60,
		"seed": scene.seed, "solver": scene.solver, "interest": scene.interest, "events": scene.events}
	return {"ok": true, "error": "", "files": files, "manifest": manifest,
		"logical_sha256": sha256(files[MANIFEST]), "physical_sha256": sha256(canonical_json(physical))}


static func _validate_project(value: Dictionary) -> Dictionary:
	if not _keys(value, ["schema_version", "kind", "seed", "startup", "camera", "events", "expectations", "passive_subject_id"]) \
			or not _integer(value.schema_version, 1, 1) or value.kind not in ["zero_input", "kinetic_sandbox", "triggered_automatic"] \
			or not _integer(value.seed, 0, 0) or value.startup not in ["edit_paused", "run_autoplay"]:
		return _refuse("unsupported_project_metadata_or_seed")
	if not value.events is Array or not value.events.is_empty():
		return _refuse("unsupported_environmental_event_policy")
	# No trigger executor is accepted by this revision; a mislabeled trigger
	# scene would falsely claim automatic initiation and therefore refuses.
	if value.kind == "triggered_automatic":
		return _refuse("triggered_automatic_requires_supported_event_policy")
	if not value.camera is Dictionary or not _keys(value.camera, ["origin", "size", "zoom"]) \
			or not _vector_array(value.camera.origin, 0.0, 1024.0) \
			or not _vector_array(value.camera.size, 1.0, 1024.0) \
			or not _fixed_pair(value.camera.size, 480, 270) or not _number(value.camera.zoom, 0.5, 4.0):
		return _refuse("unsupported_initial_camera")
	if float(value.camera.origin[0]) + 480.0 / float(value.camera.zoom) > 1024.0 \
			or float(value.camera.origin[1]) + 270.0 / float(value.camera.zoom) > 1024.0:
		return _refuse("initial_camera_outside_world")
	if not value.passive_subject_id is String \
			or (value.passive_subject_id != "" and not _identifier(value.passive_subject_id)):
		return _refuse("invalid_passive_subject_id")
	if not value.expectations is Array or value.expectations.size() > 16:
		return _refuse("invalid_declared_expectations")
	for expectation: Variant in value.expectations:
		if not _text(expectation, 1, 256):
			return _refuse("invalid_declared_expectation")
	var project: Dictionary = value.duplicate(true)
	project.schema_version = 1
	project.seed = 0
	project.camera = {"origin": [float(value.camera.origin[0]), float(value.camera.origin[1])],
		"size": [480, 270], "zoom": float(value.camera.zoom)}
	return {"ok": true, "error": "", "project": project}


static func _validate_scene(value: Dictionary, source: Dictionary) -> Dictionary:
	if not _keys(value, ["schema_version", "kind", "world_size", "fixed_hz", "seed", "solver", "interest",
			"camera", "startup", "events", "passive_subject_id", "expectations", "source", "origin_source"]) \
			or not _integer(value.schema_version, 1, 1) or not _fixed_pair(value.world_size, 1024, 1024) \
			or not _integer(value.fixed_hz, 60, 60) or value.source != source:
		return _refuse("unsupported_scene_schema_or_source")
	var origin: Dictionary = validate_source(value.origin_source)
	if not origin.ok:
		return origin
	if not value.solver is Dictionary or not _keys(value.solver, ["policy", "cadence_lod"]) \
			or value.solver.policy != "cybersand-default-v1" \
			or not value.solver.cadence_lod is bool or value.solver.cadence_lod \
			or not _valid_interest(value.interest):
		return _refuse("unsupported_scene_solver_or_interest")
	return _validate_project({"schema_version": 1, "kind": value.kind, "seed": value.seed,
		"startup": value.startup, "camera": value.camera, "events": value.events,
		"passive_subject_id": value.passive_subject_id, "expectations": value.expectations})


static func _valid_interest(value: Variant) -> bool:
	if not value is Dictionary or not _keys(value, ["policy", "origin", "size", "margin"]) \
			or value.policy != "authored-window-v1":
		return false
	for field: String in ["origin", "size", "margin"]:
		if not value[field] is Array or value[field].size() != 2:
			return false
		for component: Variant in value[field]:
			if not _integer(component, 0, 1024):
				return false
	return value.size[0] >= 1 and value.size[1] >= 1 \
		and value.origin[0] + value.size[0] <= 1024 and value.origin[1] + value.size[1] <= 1024


static func _validate_png(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 33 or bytes.size() > Zip.MAX_ASSET_BYTES \
			or bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]) \
			or bytes.slice(12, 16).get_string_from_ascii() != "IHDR" \
			or _be32(bytes, 8) != 13:
		return _refuse("invalid_png_asset_header")
	var width: int = _be32(bytes, 16)
	var height: int = _be32(bytes, 20)
	if width < 1 or height < 1 or width > 4096 or height > 4096:
		return _refuse("png_asset_dimensions_capacity")
	var image: Image = Image.new()
	if image.load_png_from_buffer(bytes) != OK or image.get_width() != width or image.get_height() != height:
		return _refuse("png_asset_decode_failed")
	return {"ok": true, "error": ""}


static func _parse_object(bytes: PackedByteArray) -> Dictionary:
	var parsed: Dictionary = StrictJSON.parse_bytes(bytes)
	if not parsed.ok:
		return _refuse(parsed.error)
	if not parsed.value is Dictionary:
		return _refuse("json_object_required")
	return parsed


static func _keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key: Variant in value:
		if not key is String or key not in expected:
			return false
	return true


static func _digest(value: Variant, length: int) -> bool:
	if not value is String or value.length() != length:
		return false
	for index: int in range(value.length()):
		if "0123456789abcdef".find(value[index]) < 0:
			return false
	return true


static func _identifier(value: Variant) -> bool:
	if not value is String or value.length() < 1 or value.length() > 64:
		return false
	for index: int in range(value.length()):
		var code: int = value.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) \
				or (code >= 97 and code <= 122) or code in [45, 95]):
			return false
	return true


static func _text(value: Variant, minimum: int, maximum: int) -> bool:
	return value is String and value.length() >= minimum and value.length() <= maximum \
		and not value.to_utf8_buffer().has(0)


static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) >= minimum and float(value) <= maximum


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, minimum, maximum) and float(value) == floorf(float(value))


static func _vector_array(value: Variant, minimum: float, maximum: float) -> bool:
	return value is Array and value.size() == 2 \
		and _number(value[0], minimum, maximum) and _number(value[1], minimum, maximum)


static func _fixed_pair(value: Variant, x: int, y: int) -> bool:
	return value is Array and value.size() == 2 and _integer(value[0], x, x) and _integer(value[1], y, y)


static func _vector2i(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))


static func _array2(value: Vector2i) -> Array:
	return [value.x, value.y]


static func _be32(bytes: PackedByteArray, offset: int) -> int:
	return (int(bytes[offset]) << 24) | (int(bytes[offset + 1]) << 16) \
		| (int(bytes[offset + 2]) << 8) | int(bytes[offset + 3])


static func _refuse(reason: String) -> Dictionary:
	return {"ok": false, "accepted": false, "error": reason, "reason": reason, "partial": false}
