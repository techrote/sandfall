class_name SandfallAuthoringDocument
extends RefCounted

# Sole logical initial-state owner. History stores sparse exact tuples, never
# evolved solver snapshots. Candidates allocate before the host is mutated.
const CELL_BYTES: int = 5
const WORLD_CELLS: int = 1024 * 1024
const MAX_HISTORY_BYTES: int = 64 * 1024 * 1024
const MAX_HISTORY_ENTRIES: int = 512

var _bridge: Variant
var _definition: Dictionary = {}
var _cells: PackedByteArray = PackedByteArray()
var _revision: int = 0
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _history_bytes: int = 0
var _locked: bool = false
var _retired: bool = false
var _hash: String = ""
var _prepared: Dictionary = {}
var _prepared_serial: int = 0


func _init(definition: Dictionary, cells: PackedByteArray) -> void:
	_bridge = ClassDB.instantiate(&"SandfallEditBridge")
	if _bridge == null or not bool(_bridge.validate_cells(cells).ok):
		_locked = true
		_retired = true
		return
	_definition = definition.duplicate(true)
	_definition.erase("initial_cells")
	_definition.rectangles = PackedInt32Array(definition.rectangles).duplicate()
	_cells = cells.duplicate()
	_refresh_hash()


func valid() -> bool:
	return _cells.size() == WORLD_CELLS * CELL_BYTES


func state() -> Dictionary:
	return {"valid": valid(), "revision": _revision, "cells_sha256": _hash,
		"undo_depth": _undo.size(), "redo_depth": _redo.size(),
		"history_bytes": _history_bytes, "history_limit_bytes": MAX_HISTORY_BYTES,
		"can_undo": not _locked and not _undo.is_empty(),
		"can_redo": not _locked and not _redo.is_empty(),
		"locked": _locked, "retired": _retired}


func cells_copy() -> PackedByteArray:
	return _cells.duplicate()


func cell(index: int) -> PackedByteArray:
	if index < 0 or index >= WORLD_CELLS or not valid():
		return PackedByteArray()
	return _cells.slice(index * CELL_BYTES, (index + 1) * CELL_BYTES)


func snapshot() -> Dictionary:
	var out: Dictionary = _definition.duplicate(true)
	out["initial_cells"] = _cells.duplicate()
	out.rectangles = PackedInt32Array(_definition.rectangles).duplicate()
	out["authored_revision"] = _revision
	out["authored_cells_sha256"] = _hash
	return out


func prepare(indices: PackedInt32Array, desired: PackedByteArray, expected_revision: int,
		kind: String) -> Dictionary:
	_prepared.clear()
	if _locked or not valid():
		return _refusal("document_not_editable")
	if expected_revision != _revision:
		return _refusal("stale_document_revision")
	var patch: Dictionary = _bridge.plan_patch(_cells, indices, desired)
	if not bool(patch.ok):
		return patch
	var cost: int = patch.indices.size() * (4 + 2 * CELL_BYTES)
	var redo_bytes: int = 0
	for entry: Dictionary in _redo:
		redo_bytes += int(entry.cost)
	if _undo.size() >= MAX_HISTORY_ENTRIES or _history_bytes - redo_bytes + cost > MAX_HISTORY_BYTES:
		return _refusal("history_capacity_refused_before_mutation")
	patch["cost"] = cost
	patch["kind"] = kind
	patch["revision"] = _revision
	patch["history_action"] = "edit"
	return _hold_prepared(patch)


func prepare_history(direction: String) -> Dictionary:
	_prepared.clear()
	if _locked or direction not in ["undo", "redo"]:
		return _refusal("history_requires_edit_at_zero")
	var source: Array[Dictionary] = _undo if direction == "undo" else _redo
	if source.is_empty():
		return _refusal("history_empty")
	var entry: Dictionary = source.back()
	var target: PackedByteArray = entry.before if direction == "undo" else entry.after
	var patch: Dictionary = _bridge.plan_patch(_cells, entry.indices, target)
	if not bool(patch.ok):
		return patch
	# A history conflict is corruption, never an excuse for a partial inverse.
	var expected: PackedByteArray = entry.after if direction == "undo" else entry.before
	if patch.indices != entry.indices or patch.before != expected:
		return _refusal("history_tuple_conflict")
	patch["revision"] = _revision
	patch["history_action"] = direction
	patch["kind"] = entry.kind
	patch["cost"] = entry.cost
	return _hold_prepared(patch)


func commit(patch: Dictionary) -> bool:
	# Called only after the exclusive native host accepted this exact prepared
	# patch. No allocation-heavy candidate construction occurs at commit.
	if _locked or _prepared.is_empty() or int(patch.get("token", -1)) != _prepared_serial or int(patch.get("revision", -1)) != _revision or not bool(patch.get("ok", false)):
		return false
	if not patch.get("indices") is PackedInt32Array or not patch.get("before") is PackedByteArray or not patch.get("after") is PackedByteArray or not patch.has("history_action"):
		return false
	if patch.indices != _prepared.indices or patch.before != _prepared.before or patch.after != _prepared.after or patch.history_action != _prepared.history_action:
		return false
	match str(patch.history_action):
		"edit":
			for entry: Dictionary in _redo:
				_history_bytes -= int(entry.cost)
			_redo.clear()
			_undo.append({"indices": _prepared.indices, "before": _prepared.before, "after": _prepared.after,
				"kind": str(_prepared.kind), "cost": int(_prepared.cost)})
			_history_bytes += int(_prepared.cost)
		"undo":
			_redo.append(_undo.pop_back())
		"redo":
			_undo.append(_redo.pop_back())
		_:
			return false
	_cells = _prepared.candidate
	_prepared = {}
	_revision += 1
	_refresh_hash()
	return true


func lock_for_run() -> void:
	_prepared.clear()
	_locked = true # Run refuses history even while both solvers are still at zero.


func retire_history() -> void:
	_prepared.clear()
	_locked = true
	_retired = true
	_undo.clear()
	_redo.clear()
	_history_bytes = 0


func _refresh_hash() -> void:
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(_cells)
	_hash = hashing.finish().hex_encode()


static func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "error": reason, "partial": false}


func _hold_prepared(patch: Dictionary) -> Dictionary:
	_prepared_serial += 1
	_prepared = patch
	var public_patch: Dictionary = patch.duplicate(true)
	public_patch.erase("candidate")
	public_patch.indices = PackedInt32Array(patch.indices).duplicate()
	public_patch.before = PackedByteArray(patch.before).duplicate()
	public_patch.after = PackedByteArray(patch.after).duplicate()
	public_patch["token"] = _prepared_serial
	return public_patch
