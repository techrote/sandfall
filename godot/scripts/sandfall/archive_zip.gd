class_name SandfallArchiveZIP
extends RefCounted

# A bounded classic ZIP container, interoperable with ordinary ZIP tools.
# Entry metadata is preflighted in full before any decompression. Nothing is
# extracted to disk and no ResourceLoader/Variant deserialization is involved.
# ZIP64, encrypted/multipart containers, links, alternate filename extras and
# methods other than STORE/DEFLATE are deliberately unsupported in schema v1.
const MAX_ENTRIES: int = 256
const MAX_EXPANDED_BYTES: int = 128 * 1024 * 1024
const MAX_ARCHIVE_BYTES: int = MAX_EXPANDED_BYTES + 1024 * 1024
const MAX_ASSET_BYTES: int = 16 * 1024 * 1024
const MAX_JSON_BYTES: int = 1024 * 1024
const CELL_BYTES: int = 1024 * 1024 * 5
const WORLD_RATIO_LIMIT: int = 1100 # A valid, mostly Empty world approaches 1032:1.
const OTHER_RATIO_LIMIT: int = 200
const FIXED_FILES: Array[String] = ["project/manifest.json", "project/scene/scene.json",
	"project/scene/objects.json", "project/world/cells.bin", "project/presentation/style.json",
	"project/presentation/annotations.json", "project/README.md"]


static func inspect(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 22 or bytes.size() > MAX_ARCHIVE_BYTES:
		return _refuse("zip_archive_size")
	var eocd: int = -1
	for offset: int in range(bytes.size() - 22, maxi(-1, bytes.size() - 65558), -1):
		if _u32(bytes, offset) == 0x06054b50 and offset + 22 + _u16(bytes, offset + 20) == bytes.size():
			eocd = offset
			break
	if eocd < 0:
		return _refuse("zip_end_record_missing")
	var count: int = _u16(bytes, eocd + 10)
	var central_size: int = _u32(bytes, eocd + 12)
	var central: int = _u32(bytes, eocd + 16)
	if _u16(bytes, eocd + 4) != 0 or _u16(bytes, eocd + 6) != 0 \
			or _u16(bytes, eocd + 8) != count:
		return _refuse("zip_multipart_unsupported")
	if count < 1 or count > MAX_ENTRIES:
		return _refuse("zip_entry_capacity")
	if central_size == 0xffffffff or central == 0xffffffff \
			or central + central_size != eocd:
		return _refuse("zip_central_bounds_or_zip64")
	var cursor: int = central
	var expanded: int = 0
	var names: Dictionary = {}
	var entries: Array[Dictionary] = []
	var ranges: Array[Dictionary] = []
	for unused: int in range(count):
		if cursor + 46 > eocd or _u32(bytes, cursor) != 0x02014b50:
			return _refuse("zip_central_entry_malformed")
		var flags: int = _u16(bytes, cursor + 8)
		var method: int = _u16(bytes, cursor + 10)
		var crc: int = _u32(bytes, cursor + 16)
		var compressed: int = _u32(bytes, cursor + 20)
		var size: int = _u32(bytes, cursor + 24)
		var name_size: int = _u16(bytes, cursor + 28)
		var extra_size: int = _u16(bytes, cursor + 30)
		var comment_size: int = _u16(bytes, cursor + 32)
		var attributes: int = _u32(bytes, cursor + 38)
		var local: int = _u32(bytes, cursor + 42)
		var next: int = cursor + 46 + name_size + extra_size + comment_size
		if next > eocd or name_size < 1 or name_size > 160:
			return _refuse("zip_entry_name_or_bounds")
		var name_bytes: PackedByteArray = bytes.slice(cursor + 46, cursor + 46 + name_size)
		for character: int in name_bytes:
			if character < 32 or character > 126:
				return _refuse("zip_path_not_canonical")
		var name: String = name_bytes.get_string_from_utf8()
		if name.to_utf8_buffer() != name_bytes or not valid_path(name):
			return _refuse("zip_path_not_canonical")
		if names.has(name.to_lower()):
			return _refuse("zip_duplicate_casefolded_path")
		names[name.to_lower()] = true
		var directory: bool = name.ends_with("/")
		var unix_type: int = (attributes >> 16) & 0xf000
		if unix_type not in [0, 0x4000, 0x8000] \
				or (unix_type == 0x4000 and not directory) \
				or (unix_type == 0x8000 and directory) \
				or ((attributes & 0x10) != 0 and not directory):
			return _refuse("zip_link_or_special_entry")
		if method not in [0, 8] or (flags & ~0x080e) != 0 \
				or (method == 0 and (flags & 6) != 0) \
				or _u16(bytes, cursor + 6) > 20 or _u16(bytes, cursor + 34) != 0:
			return _refuse("zip_unsupported_method_flags_or_version")
		if not _valid_extra(bytes, cursor + 46 + name_size, extra_size):
			return _refuse("zip_unsupported_extra")
		if compressed == 0xffffffff or size == 0xffffffff or local == 0xffffffff:
			return _refuse("zip64_unsupported")
		var limit: int = entry_limit(name)
		if limit < 0 or size > limit or (directory and (size != 0 or compressed != 0 or method != 0 or crc != 0)):
			return _refuse("zip_entry_type_or_size")
		if name == "project/world/cells.bin" and size != CELL_BYTES:
			return _refuse("wrong_cell_payload_length")
		expanded += size
		if expanded > MAX_EXPANDED_BYTES:
			return _refuse("zip_expanded_capacity")
		var ratio_limit: int = WORLD_RATIO_LIMIT if name == "project/world/cells.bin" else OTHER_RATIO_LIMIT
		if (size > 0 and compressed == 0) or size > maxi(1, compressed) * ratio_limit:
			return _refuse("zip_compression_ratio")
		if method == 0 and size != compressed:
			return _refuse("zip_stored_size_mismatch")
		if local + 30 > central or _u32(bytes, local) != 0x04034b50:
			return _refuse("zip_local_header_missing")
		var local_name_size: int = _u16(bytes, local + 26)
		var local_extra_size: int = _u16(bytes, local + 28)
		var data_start: int = local + 30 + local_name_size + local_extra_size
		var data_end: int = data_start + compressed
		if data_end > central or local_name_size != name_size \
				or bytes.slice(local + 30, local + 30 + local_name_size) != name_bytes \
				or _u16(bytes, local + 4) > 20 or _u16(bytes, local + 6) != flags \
				or _u16(bytes, local + 8) != method:
			return _refuse("zip_local_central_mismatch")
		if size == 0 and method == 8:
			# The engine returns an empty array both for an empty stream and
			# for decompression failure. Admit the standard exact empty fixed
			# or stored block encodings before decoding; do not mistake failure
			# for successful zero-byte output with CRC zero.
			if crc != 0 or compressed not in [2, 5]:
				return _refuse("zip_empty_deflate_encoding_unsupported")
			var empty_data: PackedByteArray = bytes.slice(data_start, data_end)
			if empty_data not in [PackedByteArray([3, 0]), PackedByteArray([1, 0, 0, 255, 255])]:
				return _refuse("zip_empty_deflate_encoding_unsupported")
		if not _valid_extra(bytes, local + 30 + local_name_size, local_extra_size):
			return _refuse("zip_unsupported_local_extra")
		if (flags & 8) == 0:
			if _u32(bytes, local + 14) != crc or _u32(bytes, local + 18) != compressed \
					or _u32(bytes, local + 22) != size:
				return _refuse("zip_local_sizes_or_crc_mismatch")
		else:
			if _u32(bytes, local + 14) not in [0, crc] \
					or _u32(bytes, local + 18) not in [0, compressed] \
					or _u32(bytes, local + 22) not in [0, size]:
				return _refuse("zip_descriptor_local_mismatch")
			var descriptor: int = data_end
			if descriptor + 4 <= central and _u32(bytes, descriptor) == 0x08074b50:
				descriptor += 4
			if descriptor + 12 > central or _u32(bytes, descriptor) != crc \
					or _u32(bytes, descriptor + 4) != compressed or _u32(bytes, descriptor + 8) != size:
				return _refuse("zip_descriptor_mismatch")
			data_end = descriptor + 12
		entries.append({"name": name, "directory": directory, "method": method,
			"crc": crc, "size": size, "compressed_size": compressed, "data_start": data_start})
		ranges.append({"start": local, "end": data_end})
		cursor = next
	if cursor != eocd:
		return _refuse("zip_unlisted_central_bytes")
	for entry: Dictionary in entries:
		if entry.directory:
			continue
		for other: Dictionary in entries:
			if str(other.name).to_lower().begins_with(str(entry.name).to_lower() + "/"):
				return _refuse("zip_file_directory_path_conflict")
	ranges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.start < b.start)
	var end: int = 0
	for span: Dictionary in ranges:
		if span.start != end:
			return _refuse("zip_overlapping_or_unlisted_local_bytes")
		end = span.end
	if end != central:
		return _refuse("zip_unlisted_local_tail")
	return {"ok": true, "error": "", "entries": entries, "expanded_bytes": expanded}


static func unpack(bytes: PackedByteArray) -> Dictionary:
	var checked: Dictionary = inspect(bytes)
	if not checked.ok:
		return checked
	var files: Dictionary = {}
	for entry: Dictionary in checked.entries:
		if entry.directory:
			continue
		var data: PackedByteArray = bytes.slice(entry.data_start, entry.data_start + entry.compressed_size)
		var expanded: PackedByteArray
		if int(entry.size) == 0:
			expanded = PackedByteArray() # Empty method-8 streams were validated above.
		elif int(entry.method) == 8:
			# ZIP DEFLATE is raw RFC1951. A bounded RFC1952 wrapper lets the
			# engine's zlib implementation verify the ZIP CRC and exact size.
			# No archive bytes control the output allocation upper bound.
			var gzip: PackedByteArray = PackedByteArray([31, 139, 8, 0, 0, 0, 0, 0, 0, 255])
			gzip.append_array(data)
			_put32(gzip, entry.crc)
			_put32(gzip, entry.size)
			expanded = gzip.decompress_dynamic(int(entry.size) + 1, FileAccess.COMPRESSION_GZIP)
		else:
			expanded = data
		if expanded.size() != int(entry.size) or _crc32(expanded) != int(entry.crc):
			return _refuse("zip_decompression_size_or_crc")
		files[entry.name] = expanded
	return {"ok": true, "error": "", "files": files, "expanded_bytes": checked.expanded_bytes}


static func pack(files: Dictionary) -> Dictionary:
	if files.is_empty() or files.size() > MAX_ENTRIES:
		return _refuse("zip_entry_capacity")
	var local: PackedByteArray = PackedByteArray()
	var central: PackedByteArray = PackedByteArray()
	var paths: Array = files.keys()
	paths.sort()
	var expanded: int = 0
	for key: Variant in paths:
		if not key is String or not valid_path(key) or key.ends_with("/") \
				or not files[key] is PackedByteArray or entry_limit(key) < 0 \
				or files[key].size() > entry_limit(key):
			return _refuse("zip_export_entry_invalid")
		var data: PackedByteArray = files[key]
		expanded += data.size()
		if expanded > MAX_EXPANDED_BYTES:
			return _refuse("zip_expanded_capacity")
		var gzip: PackedByteArray = data.compress(FileAccess.COMPRESSION_GZIP) if not data.is_empty() else PackedByteArray()
		if not data.is_empty() and (gzip.size() < 18 or gzip.slice(0, 4) != PackedByteArray([31, 139, 8, 0])):
			return _refuse("zip_deflate_compression_failed")
		var payload: PackedByteArray = gzip.slice(10, gzip.size() - 8) if not data.is_empty() else PackedByteArray()
		var crc: int = _u32(gzip, gzip.size() - 8) if not data.is_empty() else 0
		var method: int = 8 if not data.is_empty() else 0
		var ratio_limit: int = WORLD_RATIO_LIMIT if key == "project/world/cells.bin" else OTHER_RATIO_LIMIT
		# Highly repetitive optional notes/annotations remain valid data. Store
		# those entries rather than exporting a file our own ratio gate refuses.
		if data.size() > maxi(1, payload.size()) * ratio_limit:
			payload = data
			method = 0
		var name_bytes: PackedByteArray = key.to_utf8_buffer()
		var start: int = local.size()
		_put32(local, 0x04034b50)
		_put16(local, 20)
		_put16(local, 0x0800)
		_put16(local, method)
		_put16(local, 0)
		_put16(local, 33) # Fixed 1980-01-01 timestamp; logical identity is separate.
		_put32(local, crc)
		_put32(local, payload.size())
		_put32(local, data.size())
		_put16(local, name_bytes.size())
		_put16(local, 0)
		local.append_array(name_bytes)
		local.append_array(payload)
		_put32(central, 0x02014b50)
		_put16(central, 0x0314)
		_put16(central, 20)
		_put16(central, 0x0800)
		_put16(central, method)
		_put16(central, 0)
		_put16(central, 33)
		_put32(central, crc)
		_put32(central, payload.size())
		_put32(central, data.size())
		_put16(central, name_bytes.size())
		_put16(central, 0)
		_put16(central, 0)
		_put16(central, 0)
		_put16(central, 0)
		_put32(central, 0x81a40000) # Unix regular file, 0644; never executable/link.
		_put32(central, start)
		central.append_array(name_bytes)
	var central_start: int = local.size()
	local.append_array(central)
	_put32(local, 0x06054b50)
	_put16(local, 0)
	_put16(local, 0)
	_put16(local, paths.size())
	_put16(local, paths.size())
	_put32(local, central.size())
	_put32(local, central_start)
	_put16(local, 0)
	var checked: Dictionary = inspect(local)
	if not checked.ok:
		return checked
	return {"ok": true, "error": "", "bytes": local}


static func valid_path(path: String) -> bool:
	if not path.begins_with("project/") or path.length() > 160:
		return false
	for index: int in range(path.length()):
		var code: int = path.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) \
				or (code >= 97 and code <= 122) or code in [45, 46, 47, 95]):
			return false
	var components: PackedStringArray = path.split("/", true)
	if components.size() > 8:
		return false
	for index: int in range(components.size()):
		var part: String = components[index]
		if part.is_empty() and index == components.size() - 1:
			continue
		if part.is_empty() or part in [".", ".."] or part.ends_with("."):
			return false
		var stem: String = part.get_slice(".", 0).to_upper()
		if stem in ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"]:
			return false
	return true


static func entry_limit(path: String) -> int:
	if path.ends_with("/"):
		return 0 if path in ["project/", "project/scene/", "project/world/", "project/presentation/", "project/assets/"] \
			or path.begins_with("project/assets/") else -1
	if path == "project/world/cells.bin":
		return CELL_BYTES
	if path in FIXED_FILES:
		return MAX_JSON_BYTES
	if path.begins_with("project/assets/") and path.ends_with(".png"):
		return MAX_ASSET_BYTES
	return -1


static func _valid_extra(bytes: PackedByteArray, offset: int, size: int) -> bool:
	var end: int = offset + size
	if end > bytes.size():
		return false
	while offset < end:
		if offset + 4 > end:
			return false
		var tag: int = _u16(bytes, offset)
		var length: int = _u16(bytes, offset + 2)
		# Timestamps and owner IDs have no filename/execution semantics.
		if tag not in [0x5455, 0x7875, 0x000a] or offset + 4 + length > end:
			return false
		offset += 4 + length
	return offset == end


static func _crc32(bytes: PackedByteArray) -> int:
	if bytes.is_empty():
		return 0
	# Reuse native zlib's CRC rather than a multi-million-iteration script loop.
	var gzip: PackedByteArray = bytes.compress(FileAccess.COMPRESSION_GZIP)
	return _u32(gzip, gzip.size() - 8) if gzip.size() >= 18 else -1


static func _u16(bytes: PackedByteArray, offset: int) -> int:
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8)


static func _u32(bytes: PackedByteArray, offset: int) -> int:
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8) \
		| (int(bytes[offset + 2]) << 16) | (int(bytes[offset + 3]) << 24)


static func _put16(bytes: PackedByteArray, value: int) -> void:
	bytes.append(value & 255)
	bytes.append((value >> 8) & 255)


static func _put32(bytes: PackedByteArray, value: int) -> void:
	for shift: int in [0, 8, 16, 24]:
		bytes.append((value >> shift) & 255)


static func _refuse(error: String) -> Dictionary:
	return {"ok": false, "error": error, "partial": false}
