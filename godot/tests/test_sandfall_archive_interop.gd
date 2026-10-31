extends SceneTree

# Files are independently extracted, edited, hashed and DEFLATE-repacked by
# Python's standard ZIP library. This tests actual codec interoperability and
# refuses externally produced hostile files, not codec-generated stand-ins.
const Codec = preload("res://scripts/sandfall/archive_codec.gd")
var _checks: int = 0
var _failures: Array[String] = []
var _receipts: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var root: String = OS.get_environment("SF_M4_INTEROP_DIR")
	if root.is_empty() or not FileAccess.file_exists(root.path_join("interop.json")):
		_check(false, "Independent external ZIP fixtures were not provisioned")
		_finish()
		return
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("interop.json")))
	if not manifest is Dictionary or not manifest.get("fixtures", null) is Array:
		_check(false, "Independent fixture manifest is malformed")
		_finish()
		return
	var retained: Dictionary = {}
	for fixture: Dictionary in manifest.fixtures:
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(str(fixture.path))
		_check(not bytes.is_empty(), "Independent ZIP fixture bytes are unavailable: " + str(fixture.path))
		if bytes.is_empty():
			continue
		var context: HashingContext = HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(bytes)
		var fixture_hash: String = context.finish().hex_encode()
		_check(fixture_hash == str(fixture.sha256), "External fixture identity changed: " + str(fixture.operation))
		var expected_crc_diagnostic: bool = str(fixture.operation) == "crc"
		var retained_hash: String = ""
		if expected_crc_diagnostic:
			retained_hash = str(Codec.canonical_identity(retained, Codec.local_source_identity()).get("logical_sha256", ""))
			_check(not retained_hash.is_empty(), "CRC negative has no retained valid logical candidate")
			print("SF_M4_EXPECTED_DECOMPRESSION_REFUSAL_BEGIN ", JSON.stringify({"case": "external_crc", "fixture_sha256": fixture_hash}))
		var result: Dictionary = Codec.decode_bytes(bytes)
		if expected_crc_diagnostic:
			var input_unchanged: bool = Codec.sha256(bytes) == fixture_hash
			var retained_unchanged: bool = Codec.canonical_identity(retained, Codec.local_source_identity()).get("logical_sha256", "") == retained_hash
			_check(input_unchanged and retained_unchanged, "External malformed CRC changed input or retained candidate")
			print("SF_M4_EXPECTED_DECOMPRESSION_REFUSAL_END ", JSON.stringify({"case": "external_crc", "fixture_sha256": fixture_hash,
				"refused": not bool(result.get("ok", false)), "error": str(result.get("error", "")),
				"input_unchanged": input_unchanged, "retained_candidate_unchanged": retained_unchanged}))
		var accepted: bool = bool(result.get("ok", false))
		var expected: bool = str(fixture.expected) == "accepted"
		_check(accepted == expected, "External ZIP disposition differs: " + str(fixture.operation) + " / " + str(result.get("error", "")))
		if accepted and expected:
			var definition: Dictionary = result.definition
			retained = definition.duplicate(true)
			_check(str(definition.title) == str(fixture.expected_title), "Human-readable external project title was not loaded")
			_check(Codec.sha256(definition.initial_cells) == str(fixture.world_sha256), "External ZIP changed exact authored material/thermal tuples")
			_check(definition.bodies.size() == int(fixture.body_count), "External ZIP changed body capacity")
			var ids: Array = []
			for body: Dictionary in definition.bodies:
				ids.append(str(body.id))
			_check(ids == fixture.object_ids, "External ZIP lost stable IDs/order")
			if not definition.bodies.is_empty():
				_check(float(definition.bodies[0].mass) == float(fixture.expected_first_mass), "Ordinary JSON physics edit was not loaded")
		_receipts.append({"operation": fixture.operation, "fixture_sha256": fixture.sha256,
			"accepted": accepted, "error": str(result.get("error", ""))})
	_finish()


func _check(condition: bool, reason: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(reason)


func _finish() -> void:
	var result: Dictionary = {"status": "passed" if _failures.is_empty() else "failed", "checks": _checks,
		"failures": _failures, "fixtures": _receipts, "scope": "Actual Godot codec / independent Python ZIP interchange"}
	print("SF_M4_INTEROP_RESULT ", JSON.stringify(result))
	var root: String = OS.get_environment("SF_M4_INTEROP_DIR")
	if not root.is_empty():
		var output: FileAccess = FileAccess.open(root.path_join("godot-interop-receipt.json"), FileAccess.WRITE)
		if output != null:
			output.store_string(JSON.stringify(result, "  ") + "\n")
	quit(0 if _failures.is_empty() else 1)
