extends SceneTree

# Native tuple admission + ordinary ZIP reconstruction. Malicious fixtures are
# generated locally and never mutate a host; staged host atomicity is tested by
# the separate project-session suite. Python ZIP interoperability is a distinct
# CI pass over the emitted files, not inferred from codec self-roundtrips.
const Codec = preload("res://scripts/sandfall/archive_codec.gd")
const Zip = preload("res://scripts/sandfall/archive_zip.gd")
const StrictJSON = preload("res://scripts/sandfall/archive_json.gd")
const Registry = preload("res://scripts/sandfall/rapier_object_registry.gd")
const Definitions = preload("res://scripts/sandfall/scene_definitions.gd")
const Presentation = preload("res://scripts/sandfall/presentation_model.gd")

var _checks: int = 0
var _failures: Array[String] = []
var _negatives: Array[Dictionary] = []
var _roundtrips: Array[Dictionary] = []
var _output: String = ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_output = OS.get_environment("SF_M4_TEST_OUTPUT")
	if _output.is_empty():
		_output = ProjectSettings.globalize_path("user://sf-m4-archive-test")
	DirAccess.make_dir_recursive_absolute(_output)
	_json_negatives()
	_zip_structural_negatives()
	if not ClassDB.class_exists(&"SandfallEditBridge"):
		_check(false, "Fresh Sandfall native tuple validator is unavailable")
		_finish()
		return
	_corrupt_deflate_negatives()
	for count: int in [0, 1, 3, 8, 16]:
		_roundtrip(count)
	_logical_negatives()
	_ownership_and_identity()
	_finish()


func _definition(count: int = 3) -> Dictionary:
	var definition: Dictionary = Definitions.get_definition("blank")
	definition.id = "archive-fixture-%d" % count
	definition.title = "Portable %d-body fixture" % count
	var cells: PackedByteArray = PackedByteArray()
	cells.resize(Codec.WORLD_BYTES)
	cells.fill(0)
	# Exact signed thermal extrema and material-owned state; no eight-byte ABI.
	var bridge: Variant = ClassDB.instantiate(&"SandfallEditBridge")
	var catalogue: Array = bridge.catalogue()
	var index: int = 1100
	for row: Dictionary in catalogue:
		for repeat: int in range(3):
			var at: int = index * 5
			cells[at] = int(row.id)
			cells[at + 1] = int(row.state_a)
			cells[at + 2] = int(row.state_b)
			var temperature: int = [-32768, 200, 32767][repeat]
			cells[at + 3] = temperature & 255
			cells[at + 4] = (temperature >> 8) & 255
			index += 1
	definition.initial_cells = cells
	definition.bodies = []
	for body_index: int in range(count):
		var row: Dictionary = Registry.make_box("portable-%02d" % body_index,
			body_index * 3 + 2, Vector2(100 + (body_index % 8) * 50, 100 + (body_index / 8) * 90), Vector2(12, 18))
		row.name = "Initial box %d" % body_index
		row.rotation = 0.17
		row.mass = 2.0 + body_index
		row.linear_velocity = Vector2(body_index * 0.5, -2.25)
		row.angular_velocity = 0.125
		row.friction = 0.33
		row.restitution = 0.42
		row.linear_damp = 0.2
		row.angular_damp = 0.6
		row.passive_subject = body_index == 0
		row.fixed = body_index == 14
		row.frozen = body_index == 15
		definition.bodies.append(row)
	definition.project = Codec.project_defaults(definition.bodies)
	definition.project.expectations = ["Declared outcome only; no deterministic replay claim"]
	definition.presentation = Presentation.defaults()
	definition.presentation.style.theme = "muted"
	definition.presentation.annotations = [
		{"id": "caption", "type": "label", "points": [[40.5, 52.25]], "color": "#88ccffff", "width": 2.0, "text": "Initial state — editable JSON"},
		{"id": "mark", "type": "stroke", "points": [[40.0, 80.0], [100.0, 82.0]], "color": "#ffc044ff", "width": 3.0, "text": ""}]
	definition.notes = "# Portable fixture\n\nThis ordinary folder contains initial material tuples and independent boxes.\n"
	var image: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.25, 0.5, 0.75, 1.0))
	definition.assets = {"assets/swatch.png": image.save_png_to_buffer()}
	return definition


func _roundtrip(count: int) -> void:
	var original: Dictionary = _definition(count)
	var source: Dictionary = Codec.local_source_identity()
	var encoded: Dictionary = Codec.encode_definition(original, source)
	_check(encoded.ok, "%d-body project export: %s" % [count, encoded.get("error", "")])
	if not encoded.ok:
		return
	_check(encoded.bytes.slice(0, 4) == PackedByteArray([80, 75, 3, 4]), "Ordinary PK ZIP signature")
	var inspected: Dictionary = Codec.inspect_zip(encoded.bytes)
	_check(inspected.ok, "Full ZIP preflight")
	var world_deflate: bool = false
	for entry: Dictionary in inspected.entries:
		if entry.name == "project/world/cells.bin":
			world_deflate = entry.method == 8 and entry.size == Codec.WORLD_BYTES
	_check(world_deflate, "Initial cells use ordinary entry DEFLATE")
	var imported: Dictionary = Codec.decode_bytes(encoded.bytes)
	_check(imported.ok, "%d-body project import: %s" % [count, imported.get("error", "")])
	if not imported.ok:
		return
	_check(imported.definition.initial_cells == original.initial_cells, "Every cell/state/thermal byte roundtrips")
	_check(imported.definition.bodies == original.bodies, "Stable IDs/order/geometry/physics/velocities roundtrip")
	_check(imported.definition.presentation == original.presentation, "Separate presentation roundtrips")
	_check(imported.definition.assets == original.assets, "Self-contained PNG bytes roundtrip")
	_check(imported.definition.notes == original.notes, "Human-authored notes roundtrip")
	_check(imported.logical_sha256 == encoded.logical_sha256, "Canonical logical project digest roundtrips")
	_check(imported.physical_sha256 == encoded.physical_sha256, "Canonical physical identity roundtrips")
	var encoded_again: Dictionary = Codec.encode_definition(imported.definition, source)
	_check(encoded_again.ok and encoded_again.logical_sha256 == encoded.logical_sha256,
		"Re-export keeps canonical logical identity")
	var file: FileAccess = FileAccess.open(_output.path_join("roundtrip-%d.sandfall" % count), FileAccess.WRITE)
	_check(file != null, "Write independent ZIP interoperability fixture")
	if file != null:
		file.store_buffer(encoded.bytes)
		file.close()
	_roundtrips.append({"bodies": count, "archive_bytes": encoded.bytes.size(),
		"archive_sha256": Codec.sha256(encoded.bytes), "logical_sha256": encoded.logical_sha256,
		"physical_sha256": encoded.physical_sha256, "cells_sha256": Codec.sha256(original.initial_cells)})


func _logical_negatives() -> void:
	var original: Dictionary = _definition()
	var source: Dictionary = Codec.local_source_identity()
	for change: Dictionary in [
		{"mass": 0.0}, {"mass": -1.0}, {"mass": INF}, {"mass": NAN},
		{"shape": "circle"}, {"size": Vector2.ZERO}, {"size": Vector2(257, 12)},
		{"position": Vector2(-10, 12)}, {"linear_damp": -0.1}, {"fixed": "yes"}]:
		var bad: Dictionary = original.duplicate(true)
		bad.bodies[0].merge(change, true)
		_negative("definition_" + str(change), Codec.encode_definition(bad, source))
	var duplicate: Dictionary = original.duplicate(true)
	duplicate.bodies.append(duplicate.bodies[0].duplicate(true))
	_negative("duplicate_stable_id", Codec.encode_definition(duplicate, source))
	var overflow: Dictionary = _definition(16)
	overflow.bodies.append(Registry.make_box("seventeenth", 999, Vector2(600, 200)))
	_negative("body_17", Codec.encode_definition(overflow, source))
	var invalid_cells: Dictionary = original.duplicate(true)
	invalid_cells.initial_cells[0] = 10
	_negative("reserved_material_id_10", Codec.encode_definition(invalid_cells, source))
	invalid_cells = original.duplicate(true)
	invalid_cells.initial_cells[0] = 255
	_negative("unknown_material_id_255", Codec.encode_definition(invalid_cells, source))
	invalid_cells = original.duplicate(true)
	invalid_cells.initial_cells.resize(Codec.WORLD_BYTES - 1)
	_negative("truncated_initial_cells", Codec.encode_definition(invalid_cells, source))
	invalid_cells = original.duplicate(true)
	invalid_cells.initial_cells[0] = 3
	invalid_cells.initial_cells[1] = 0
	_negative("water_zero_mass_would_normalize", Codec.encode_definition(invalid_cells, source))
	invalid_cells.initial_cells[1] = 255
	invalid_cells.initial_cells[2] = 255
	_negative("water_invalid_coherence_would_normalize", Codec.encode_definition(invalid_cells, source))
	var bad_seed: Dictionary = original.duplicate(true)
	bad_seed.project.seed = 42
	_negative("unsupported_native_seed", Codec.encode_definition(bad_seed, source))
	var bad_solver: Dictionary = original.duplicate(true)
	bad_solver.cadence_lod = true
	_negative("unsupported_solver_cadence", Codec.encode_definition(bad_solver, source))
	var event: Dictionary = original.duplicate(true)
	event.project.events = [{"tick": 2, "script": "res://attack.gd"}]
	_negative("executable_event_policy", Codec.encode_definition(event, source))
	var remote: Dictionary = original.duplicate(true)
	remote.assets = {"https://example.invalid/picture.png": PackedByteArray([0])}
	_negative("external_asset_url", Codec.encode_definition(remote, source))
	var poisoned_png: Dictionary = original.duplicate(true)
	poisoned_png.assets["assets/swatch.png"] = "not a png".to_utf8_buffer()
	_negative("invalid_png", Codec.encode_definition(poisoned_png, source))
	var giant_png: Dictionary = original.duplicate(true)
	var png: PackedByteArray = giant_png.assets["assets/swatch.png"].duplicate()
	png[16] = 127
	giant_png.assets["assets/swatch.png"] = png
	_negative("oversize_png_before_decode", Codec.encode_definition(giant_png, source))
	var unsupported: Dictionary = original.duplicate(true)
	unsupported.hidden_solver_option = true
	_negative("unknown_definition_setting", Codec.encode_definition(unsupported, source))
	var bad_source: Dictionary = source.duplicate(true)
	bad_source.build_profile = "compat"
	_negative("unattested_source_cannot_claim_compat", Codec.encode_definition(original, bad_source))
	var unsafe_camera: Dictionary = original.duplicate(true)
	unsafe_camera.project.camera.origin = [1020, 1020]
	_negative("camera_would_clamp", Codec.encode_definition(unsafe_camera, source))
	var encoded: Dictionary = Codec.encode_definition(original, source)
	if not encoded.ok:
		_check(false, "Valid fixture before manifest attacks")
		return
	var files: Dictionary = Zip.unpack(encoded.bytes).files
	var wrong_hash: Dictionary = files.duplicate(true)
	wrong_hash["project/README.md"][0] = 65
	_negative("wrong_file_digest", Codec.decode_files(wrong_hash))
	var missing: Dictionary = files.duplicate(true)
	missing.erase("project/scene/objects.json")
	_negative("missing_required_file", Codec.decode_files(missing))
	var extra: Dictionary = files.duplicate(true)
	extra["project/assets/unlisted.png"] = original.assets["assets/swatch.png"]
	_negative("unlisted_asset_digest", Codec.decode_files(extra))
	var manifest: Dictionary = JSON.parse_string(files[Codec.MANIFEST].get_string_from_utf8())
	manifest.schema_version = 2
	var versioned: Dictionary = files.duplicate(true)
	versioned[Codec.MANIFEST] = Codec.canonical_json(manifest)
	_negative("future_manifest_version", Codec.decode_files(versioned))
	var changed: Dictionary = files.duplicate(true)
	var objects: Dictionary = JSON.parse_string(changed["project/scene/objects.json"].get_string_from_utf8())
	objects.objects[0].mass = 0
	_rewrite_json(changed, "scene/objects.json", objects)
	_negative("self_consistent_bad_mass_archive", Codec.decode_files(changed))
	changed = files.duplicate(true)
	var scene: Dictionary = JSON.parse_string(changed["project/scene/scene.json"].get_string_from_utf8())
	scene.solver.policy = "unqualified-water-policy"
	_rewrite_json(changed, "scene/scene.json", scene)
	_negative("self_consistent_unsupported_solver", Codec.decode_files(changed))
	changed = files.duplicate(true)
	changed["project/scene/objects.json"] = '{"schema_version":1,"schema_version":1,"objects":[]}'.to_utf8_buffer()
	_rehash(changed)
	_negative("duplicate_json_member_inside_valid_digest", Codec.decode_files(changed))


func _ownership_and_identity() -> void:
	var original: Dictionary = _definition()
	var source: Dictionary = Codec.local_source_identity()
	var checked: Dictionary = Codec.validate_definition(original, source)
	_check(checked.ok, "Initial normalization")
	if not checked.ok:
		return
	original.initial_cells[0] = 3
	original.bodies[0].mass = 50.0
	original.presentation.annotations[0].text = "caller mutation"
	_check(checked.definition.initial_cells[0] == 0 and checked.definition.bodies[0].mass == 2.0 \
		and checked.definition.presentation.annotations[0].text != "caller mutation", "Candidate owns copied cells/objects/metadata")
	var clean: Dictionary = _definition()
	var before: Dictionary = Codec.canonical_identity(clean, source)
	clean.presentation.style.theme = "contrast"
	clean.project.camera.origin = [10.0, 20.0]
	clean.title = "Cosmetic rename"
	clean.bodies[0].name = "Visual caption"
	var after: Dictionary = Codec.canonical_identity(clean, source)
	_check(before.ok and after.ok and before.physical_sha256 == after.physical_sha256,
		"Cosmetics/camera/names preserve physical identity")
	_check(before.logical_sha256 != after.logical_sha256, "Portable identity includes authored presentation/camera/metadata")
	clean.bodies[0].mass += 1.0
	var physics: Dictionary = Codec.canonical_identity(clean, source)
	_check(physics.ok and physics.physical_sha256 != after.physical_sha256, "Physical parameter changes physical identity")
	var reordered: Dictionary = _definition()
	reordered.bodies.reverse()
	var reordered_id: Dictionary = Codec.canonical_identity(reordered, source)
	_check(reordered_id.ok and reordered_id.logical_sha256 == before.logical_sha256,
		"Registry creation order defines canonical object serialization")
	var next_source: Dictionary = source.duplicate(true)
	next_source.source_commit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	var normalized: Dictionary = checked.definition
	var exported: Dictionary = Codec.encode_definition(normalized, next_source)
	var imported: Dictionary = Codec.decode_bytes(exported.bytes) if exported.ok else exported
	_check(imported.ok and imported.manifest.source.source_commit == next_source.source_commit \
		and imported.definition.project_source.source_commit == "local-unpublished",
		"Writer source is current while original source is retained")


func _json_negatives() -> void:
	for text: String in ['{"x":1,"x":2}', '{"x":1,"\\u0078":2}', '{"x":NaN}', '{"x":1e999}',
		'{"x":1e999999999999999999999999999999}', '{"x":1e-9223372036854775808}', '{"x":1e-309}',
		'{"x":01}', '{"x":1.}', '{"x":+1}', '{"x":1,}', '[1,]', '{"x":"\\u0000"}',
		'{"x":"\\ud800"}', '{"x":"\\udc00"}', '{"x":"\\q"}', '{} trailing', '{/*comment*/}',
		'"raw\nnewline"', '{"x":9007199254740992}']:
		_negative("strict_json_" + text, StrictJSON.parse_bytes(text.to_utf8_buffer()))
	_negative("json_invalid_utf8", StrictJSON.parse_bytes(PackedByteArray([123, 34, 255, 34, 58, 48, 125])))
	_negative("json_depth_capacity", StrictJSON.parse_bytes(("[".repeat(40) + "0" + "]".repeat(40)).to_utf8_buffer()))
	var valid: Dictionary = StrictJSON.parse_bytes('{"unicode":"\\ud83d\\ude42","number":-1.25e2,"nil":null,"array":[true,false,0]}'.to_utf8_buffer())
	_check(valid.ok and valid.value.number == -125.0 and valid.value.unicode == "🙂", "Strict JSON admits standard Unicode/numbers/literals")
	var padded: Dictionary = StrictJSON.parse_bytes('1e-000000000000000000000002'.to_utf8_buffer())
	_check(padded.ok and padded.value == 0.01, "Bounded exponent admission preserves standard leading-zero exponent digits")


func _zip_structural_negatives() -> void:
	var simple: Dictionary = {"name": "project/README.md", "data": "Readable project note".to_utf8_buffer()}
	var valid: PackedByteArray = _raw_zip([simple])
	_check(Zip.inspect(valid).ok and Zip.unpack(valid).files["project/README.md"] == simple.data,
		"Independent STORE ZIP fixture accepted")
	for name: String in ["../README.md", "/project/README.md", "project/../README.md",
		"project/./README.md", "project//README.md", "project\\README.md", "project/C:/README.md",
		"other/README.md", "project/assets/NUL.png", "project/assets/attack.gd", "project/assets/image.svg",
		"project/assets/remote.url", "project/assets/trailing./image.png"]:
		_negative("zip_path_" + name, Zip.inspect(_raw_zip([{"name": name, "data": simple.data}])))
	_negative("zip_symlink", Zip.inspect(_raw_zip([{"name": "project/README.md", "data": simple.data, "attributes": 0xa1ff0000}])))
	_negative("zip_special_device", Zip.inspect(_raw_zip([{"name": "project/README.md", "data": simple.data, "attributes": 0x21ff0000}])))
	_negative("zip_casefold_collision", Zip.inspect(_raw_zip([simple, {"name": "project/readme.md", "data": simple.data}])))
	_negative("zip_exact_duplicate", Zip.inspect(_raw_zip([simple, simple])))
	_negative("zip_local_name_mismatch", Zip.inspect(_raw_zip([{"name": "project/README.md", "local_name": "project/ATTACK.md", "data": simple.data}])))
	_negative("zip_encryption", Zip.inspect(_raw_zip([{"name": "project/README.md", "data": simple.data, "flags": 1}])))
	_negative("zip_unknown_compression", Zip.inspect(_raw_zip([{"name": "project/README.md", "data": simple.data, "method": 12}])))
	_negative("zip_alternate_unicode_path", Zip.inspect(_raw_zip([{"name": "project/README.md", "data": simple.data, "extra": PackedByteArray([0x75, 0x70, 0, 0])}])))
	_negative("zip64_extra", Zip.inspect(_raw_zip([{"name": "project/README.md", "data": simple.data, "extra": PackedByteArray([1, 0, 0, 0])}])))
	_negative("zip_wrong_crc", Zip.unpack(_raw_zip([{"name": "project/README.md", "data": simple.data, "crc": 12345}])))
	_negative("zip_declared_bomb", Zip.inspect(_raw_zip([{"name": "project/assets/bomb.png", "data": PackedByteArray([3, 0]), "method": 8, "declared_size": 16000000}])))
	_negative("zip_zero_compressed_nonzero", Zip.inspect(_raw_zip([{"name": "project/README.md", "data": PackedByteArray(), "method": 8, "declared_size": 20}])))
	_negative("zip_truncated", Zip.inspect(valid.slice(0, valid.size() - 1)))
	var appended: PackedByteArray = valid.duplicate()
	appended.append(0)
	_negative("zip_trailing_unlisted_data", Zip.inspect(appended))
	var prepended: PackedByteArray = PackedByteArray([0])
	prepended.append_array(valid)
	_negative("zip_self_extracting_prefix", Zip.inspect(prepended))
	var multi: PackedByteArray = valid.duplicate()
	multi[multi.size() - 18] = 1
	_negative("zip_multipart", Zip.inspect(multi))
	var entries: Array = []
	for index: int in range(257):
		entries.append({"name": "project/assets/entry-%d.png" % index, "data": PackedByteArray()})
	_negative("zip_257_entries", Zip.inspect(_raw_zip(entries)))
	entries.clear()
	var compressed: PackedByteArray = PackedByteArray()
	compressed.resize(84000)
	compressed.fill(0)
	for index: int in range(9):
		entries.append({"name": "project/assets/expanded-%d.png" % index,
			"data": compressed, "method": 8, "declared_size": 16 * 1024 * 1024})
	_negative("zip_total_expansion_128mib", Zip.inspect(_raw_zip(entries)))
	var descriptor: PackedByteArray = _raw_zip([{"name": "project/README.md", "data": simple.data, "flags": 8}])
	_check(Zip.unpack(descriptor).ok, "Ordinary streaming data descriptor ZIP accepted")
	for empty_data: PackedByteArray in [PackedByteArray([3, 0]), PackedByteArray([1, 0, 0, 255, 255])]:
		var empty_zip: PackedByteArray = _raw_zip([{"name": "project/README.md", "data": empty_data,
			"method": 8, "declared_size": 0, "crc": 0}])
		var empty_result: Dictionary = Zip.unpack(empty_zip)
		_check(empty_result.ok and empty_result.files["project/README.md"].is_empty(),
			"Ordinary empty DEFLATE block accepted without ambiguous inflater return")
	for invalid_empty: Dictionary in [{"data": PackedByteArray([7, 0]), "crc": 0},
		{"data": PackedByteArray([3, 0, 0]), "crc": 0}, {"data": PackedByteArray([3, 0]), "crc": 1}]:
		_negative("zip_invalid_empty_deflate_" + str(invalid_empty), Zip.unpack(_raw_zip([
			{"name": "project/README.md", "data": invalid_empty.data, "method": 8, "declared_size": 0, "crc": invalid_empty.crc}])))


func _corrupt_deflate_negatives() -> void:
	# The pinned engine reports malformed DEFLATE/CRC as an engine diagnostic
	# as well as an empty result. Preserve that diagnostic within an explicit
	# negative fixture boundary; it is never permission to ignore other errors.
	var original: PackedByteArray = "Bounded raw DEFLATE test".repeat(100).to_utf8_buffer()
	var gzip: PackedByteArray = original.compress(FileAccess.COMPRESSION_GZIP)
	var raw: PackedByteArray = gzip.slice(10, gzip.size() - 8)
	var retained: Dictionary = Codec.validate_definition(_definition(3), Codec.local_source_identity()).definition
	var retained_hash: String = Codec.canonical_identity(retained, Codec.local_source_identity()).logical_sha256
	var fixtures: Array = [
		{"name": "reserved_deflate_block", "data": PackedByteArray([7, 0, 0, 0]), "size": 20, "crc": 0},
		{"name": "truncated_deflate", "data": raw.slice(0, raw.size() - 2), "size": original.size(), "crc": Zip._crc32(original)},
		{"name": "deflate_output_exceeds_declared_bound", "data": raw, "size": 1, "crc": Zip._crc32(original)},
		{"name": "deflate_crc_mismatch", "data": raw, "size": original.size(), "crc": 12345},
	]
	for fixture: Dictionary in fixtures:
		var archive: PackedByteArray = _raw_zip([{"name": "project/README.md", "data": fixture.data,
			"method": 8, "declared_size": fixture.size, "crc": fixture.crc}])
		_check(Zip.inspect(archive).ok, "Malformed DEFLATE fixture passes structural preflight")
		var fixture_hash: String = Codec.sha256(archive)
		print("SF_M4_EXPECTED_DECOMPRESSION_REFUSAL_BEGIN ", JSON.stringify({"case": fixture.name, "fixture_sha256": fixture_hash}))
		var refused: Dictionary = Zip.unpack(archive)
		_negative(fixture.name, refused)
		var input_unchanged: bool = Codec.sha256(archive) == fixture_hash
		var retained_unchanged: bool = Codec.canonical_identity(retained, Codec.local_source_identity()).logical_sha256 == retained_hash
		_check(input_unchanged and retained_unchanged, "Malformed container preserves input and retained logical candidate")
		print("SF_M4_EXPECTED_DECOMPRESSION_REFUSAL_END ", JSON.stringify({"case": fixture.name,
			"fixture_sha256": fixture_hash, "refused": not bool(refused.ok), "error": refused.error,
			"input_unchanged": input_unchanged, "retained_candidate_unchanged": retained_unchanged}))


func _raw_zip(entries: Array) -> PackedByteArray:
	var output: PackedByteArray = PackedByteArray()
	var directory: PackedByteArray = PackedByteArray()
	for entry: Dictionary in entries:
		var data: PackedByteArray = entry.data
		var name: PackedByteArray = str(entry.name).to_utf8_buffer()
		var local_name: PackedByteArray = str(entry.get("local_name", entry.name)).to_utf8_buffer()
		var extra: PackedByteArray = entry.get("extra", PackedByteArray())
		var crc: int = int(entry.get("crc", Zip._crc32(data)))
		var flags: int = int(entry.get("flags", 0))
		var method: int = int(entry.get("method", 0))
		var size: int = int(entry.get("declared_size", data.size()))
		var offset: int = output.size()
		_w32(output, 0x04034b50)
		for n: int in [20, flags, method, 0, 33]:
			_w16(output, n)
		for n: int in [0 if flags & 8 else crc, 0 if flags & 8 else data.size(), 0 if flags & 8 else size]:
			_w32(output, n)
		_w16(output, local_name.size())
		_w16(output, extra.size())
		output.append_array(local_name)
		output.append_array(extra)
		output.append_array(data)
		if flags & 8:
			for n: int in [0x08074b50, crc, data.size(), size]:
				_w32(output, n)
		_w32(directory, 0x02014b50)
		for n: int in [0x0314, 20, flags, method, 0, 33]:
			_w16(directory, n)
		for n: int in [crc, data.size(), size]:
			_w32(directory, n)
		for n: int in [name.size(), extra.size(), 0, 0, 0]:
			_w16(directory, n)
		_w32(directory, int(entry.get("attributes", 0x81a40000)))
		_w32(directory, offset)
		directory.append_array(name)
		directory.append_array(extra)
	var directory_at: int = output.size()
	output.append_array(directory)
	_w32(output, 0x06054b50)
	for n: int in [0, 0, entries.size(), entries.size()]:
		_w16(output, n)
	_w32(output, directory.size())
	_w32(output, directory_at)
	_w16(output, 0)
	return output


func _rewrite_json(files: Dictionary, path: String, value: Dictionary) -> void:
	files["project/" + path] = Codec.canonical_json(value)
	_rehash(files)


func _rehash(files: Dictionary) -> void:
	var manifest: Dictionary = JSON.parse_string(files[Codec.MANIFEST].get_string_from_utf8())
	for path: String in files:
		if path == Codec.MANIFEST:
			continue
		manifest.files[path.trim_prefix("project/")] = {"sha256": Codec.sha256(files[path]), "bytes": files[path].size()}
	files[Codec.MANIFEST] = Codec.canonical_json(manifest)


func _w16(bytes: PackedByteArray, value: int) -> void:
	bytes.append(value & 255)
	bytes.append((value >> 8) & 255)


func _w32(bytes: PackedByteArray, value: int) -> void:
	for shift: int in [0, 8, 16, 24]:
		bytes.append((value >> shift) & 255)


func _negative(name: String, result: Dictionary) -> void:
	_check(not bool(result.get("ok", false)), "Refuse " + name)
	_negatives.append({"fixture": name, "refused": not bool(result.get("ok", false)), "error": str(result.get("error", ""))})


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	var receipt: Dictionary = {"schema_version": 1, "suite": "SF-M4 authored project archive",
		"ok": _failures.is_empty(), "checks": _checks, "failures": _failures, "roundtrips": _roundtrips, "negatives": _negatives,
		"godot": Engine.get_version_info(), "native_tuple_validator": ClassDB.class_exists(&"SandfallEditBridge"),
		"evidence_scope": "native/Godot logical/ZIP admission; no browser or human exhibition claim"}
	var file: FileAccess = FileAccess.open(_output.path_join("archive-receipt.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(receipt, "\t", true, true) + "\n")
		file.close()
	print("SANDFALL_ARCHIVE_TEST ", JSON.stringify({"ok": _failures.is_empty(), "checks": _checks, "failures": _failures,
		"roundtrips": _roundtrips, "negative_count": _negatives.size()}))
	quit(0 if _failures.is_empty() else 1)
