class_name SandfallArchiveJSON
extends RefCounted

# The general Godot JSON reader accepts duplicate members and some relaxed
# syntax. Portable project data needs one unambiguous, bounded JSON meaning.
# This parser never instantiates Variants, resources, scripts or engine objects.
const MAX_DEPTH: int = 32
const MAX_NODES: int = 65536
const MAX_BYTES: int = 1024 * 1024

var _text: String = ""
var _at: int = 0
var _nodes: int = 0
var _error: String = ""


static func parse_bytes(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() > MAX_BYTES or bytes.has(0):
		return {"ok": false, "error": "json_size_or_nul"}
	if not valid_utf8(bytes):
		return {"ok": false, "error": "json_invalid_utf8"}
	var parser: SandfallArchiveJSON = SandfallArchiveJSON.new()
	parser._text = bytes.get_string_from_utf8()
	if parser._text.to_utf8_buffer() != bytes:
		return {"ok": false, "error": "json_invalid_utf8"}
	var value: Variant = parser._value(0)
	parser._space()
	if parser._error.is_empty() and parser._at != parser._text.length():
		parser._error = "json_trailing_data"
	return {"ok": parser._error.is_empty(), "error": parser._error, "value": value}


func _value(depth: int) -> Variant:
	_nodes += 1
	if depth > MAX_DEPTH or _nodes > MAX_NODES:
		_error = "json_complexity_limit"
		return null
	_space()
	if _at >= _text.length():
		_error = "json_unexpected_end"
		return null
	var token: String = _text[_at]
	if token == "{":
		return _object(depth + 1)
	if token == "[":
		return _array(depth + 1)
	if token == "\"":
		return _string()
	for literal: String in ["true", "false", "null"]:
		if _text.substr(_at, literal.length()) == literal:
			_at += literal.length()
			if literal == "null":
				return null
			return literal == "true"
	if token == "-" or (token >= "0" and token <= "9"):
		return _number()
	_error = "json_invalid_token"
	return null


func _object(depth: int) -> Dictionary:
	_at += 1
	_space()
	var result: Dictionary = {}
	if _consume("}"):
		return result
	while _error.is_empty():
		if _at >= _text.length() or _text[_at] != "\"":
			_error = "json_object_key_required"
			break
		var key: String = _string()
		if not _error.is_empty():
			break
		if result.has(key):
			_error = "json_duplicate_key"
			break
		_space()
		if not _consume(":"):
			_error = "json_missing_colon"
			break
		result[key] = _value(depth)
		_space()
		if _consume("}"):
			return result
		if not _consume(","):
			_error = "json_missing_separator"
			break
		_space()
	return result


func _array(depth: int) -> Array:
	_at += 1
	_space()
	var result: Array = []
	if _consume("]"):
		return result
	while _error.is_empty():
		result.append(_value(depth))
		_space()
		if _consume("]"):
			return result
		if not _consume(","):
			_error = "json_missing_separator"
			break
		_space()
	return result


func _string() -> String:
	var start: int = _at
	_at += 1
	while _at < _text.length():
		var code: int = _text.unicode_at(_at)
		if code < 32:
			_error = "json_control_in_string"
			return ""
		if code == 34:
			_at += 1
			var parsed: Variant = JSON.parse_string(_text.substr(start, _at - start))
			if not parsed is String or parsed.to_utf8_buffer().has(0):
				_error = "json_invalid_string"
				return ""
			return parsed
		if code == 92:
			_at += 1
			if _at >= _text.length() or _text[_at] not in ["\"", "\\", "/", "b", "f", "n", "r", "t", "u"]:
				_error = "json_invalid_escape"
				return ""
			if _text[_at] == "u":
				var point: int = _hex4(_at + 1)
				if point < 0 or point == 0:
					_error = "json_invalid_unicode_escape"
					return ""
				_at += 4
				if point >= 0xd800 and point <= 0xdbff:
					if _text.substr(_at + 1, 2) != "\\u":
						_error = "json_unpaired_surrogate"
						return ""
					var low: int = _hex4(_at + 3)
					if low < 0xdc00 or low > 0xdfff:
						_error = "json_unpaired_surrogate"
						return ""
					_at += 6
				elif point >= 0xdc00 and point <= 0xdfff:
					_error = "json_unpaired_surrogate"
					return ""
		_at += 1
	_error = "json_unterminated_string"
	return ""


func _number() -> Variant:
	var start: int = _at
	_consume("-")
	if _consume("0"):
		if _digit():
			_error = "json_leading_zero"
			return null
	else:
		if not _digit():
			_error = "json_number_requires_digit"
			return null
		while _digit():
			_at += 1
	if _consume("."):
		if not _digit():
			_error = "json_fraction_requires_digit"
			return null
		while _digit():
			_at += 1
	if _consume("e") or _consume("E"):
		if not _consume("+"):
			_consume("-")
		if not _digit():
			_error = "json_exponent_requires_digit"
			return null
		while _digit():
			_at += 1
	var token: String = _text.substr(start, _at - start)
	var exponent_at: int = token.to_lower().find("e")
	if token.length() > 128:
		_error = "json_number_not_finite_or_exact"
		return null
	if exponent_at >= 0:
		# Never convert attacker-controlled exponent integers before bounding
		# their digits: INT64_MIN cannot be safely negated, and oversized
		# conversion both logs an engine error and can change numeric meaning.
		var exponent: String = token.substr(exponent_at + 1)
		if exponent.begins_with("+") or exponent.begins_with("-"):
			exponent = exponent.substr(1)
		exponent = exponent.lstrip("0")
		if exponent.length() > 3 or (not exponent.is_empty() and exponent.to_int() > 308):
			_error = "json_number_not_finite_or_exact"
			return null
	var number: float = token.to_float()
	if not is_finite(number) or absf(number) > 9007199254740991.0:
		_error = "json_number_not_finite_or_exact"
		return null
	return number


static func valid_utf8(bytes: PackedByteArray) -> bool:
	var index: int = 0
	while index < bytes.size():
		var first: int = bytes[index]
		if first < 0x80:
			index += 1
			continue
		var length: int = 2 if first >= 0xc2 and first <= 0xdf else (3 if first >= 0xe0 and first <= 0xef else (4 if first >= 0xf0 and first <= 0xf4 else 0))
		if length == 0 or index + length > bytes.size():
			return false
		for continuation: int in range(1, length):
			if bytes[index + continuation] < 0x80 or bytes[index + continuation] > 0xbf:
				return false
		var second: int = bytes[index + 1]
		if (first == 0xe0 and second < 0xa0) or (first == 0xed and second >= 0xa0) \
				or (first == 0xf0 and second < 0x90) or (first == 0xf4 and second >= 0x90):
			return false
		index += length
	return true


func _hex4(start: int) -> int:
	if start + 4 > _text.length():
		return -1
	var value: int = 0
	for index: int in range(start, start + 4):
		var digit: int = "0123456789abcdef".find(_text[index].to_lower())
		if digit < 0:
			return -1
		value = value * 16 + digit
	return value


func _digit() -> bool:
	return _at < _text.length() and _text[_at] >= "0" and _text[_at] <= "9"


func _space() -> void:
	while _at < _text.length() and _text[_at] in [" ", "\t", "\r", "\n"]:
		_at += 1


func _consume(token: String) -> bool:
	if _at < _text.length() and _text[_at] == token:
		_at += 1
		return true
	return false
