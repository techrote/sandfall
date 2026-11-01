class_name SandfallInterventionPromotion
extends RefCounted

# Replays only declarative command values into a copied frozen initial scene.
# Runtime cell/body snapshots, contact caches and chemistry are never inputs.
const Registry = preload("res://scripts/sandfall/rapier_object_registry.gd")
const MATERIAL_KINDS: Array[String] = ["pencil_stroke", "erase_stroke", "line", "rectangle", "selection_erase"]


static func build(frozen: Dictionary, journal: Array) -> Dictionary:
	if not frozen.get("initial_cells") is PackedByteArray or journal.size() > 256:
		return _refuse("promotion_requires_frozen_initial_and_bounded_journal")
	var candidate: Dictionary = frozen.duplicate(true)
	var cells: PackedByteArray = PackedByteArray(frozen.initial_cells).duplicate()
	var objects: Array = frozen.get("bodies", []).duplicate(true)
	var bridge: Variant = ClassDB.instantiate(&"SandfallEditBridge")
	if bridge == null:
		return _refuse("native_promotion_validator_unavailable")
	var skipped: Array = []
	var eligible: int = 0
	var changed_cells: Dictionary = {}
	var object_changes: Array = []
	var material_changes: Array = []
	var changed_min: Vector2i = Vector2i(1024, 1024)
	var changed_max: Vector2i = Vector2i(-1, -1)
	for entry: Dictionary in journal:
		var kind: String = str(entry.get("kind", ""))
		if not bool(entry.get("accepted", false)):
			return _refuse("promotion_journal_not_accepted")
		if kind in MATERIAL_KINDS:
			# Preserve the complete admitted footprint, including cells that were
			# already equal in the evolved world when the command was accepted.
			if not entry.get("command_indices") is PackedInt32Array or not entry.get("command_after") is PackedByteArray:
				skipped.append({"sequence": entry.get("sequence", 0), "kind": kind, "reason": "complete_declarative_footprint_unavailable"})
				continue
			var patch: Dictionary = bridge.plan_patch(cells, entry.command_indices, entry.command_after)
			if not bool(patch.ok):
				if str(patch.error) != "no_effect":
					return _refuse("promotion_material_conflict: " + str(patch.error))
			else:
				cells = patch.candidate
				for index: int in patch.indices:
					changed_cells[index] = true
					var point: Vector2i = Vector2i(index % 1024, index / 1024)
					changed_min = changed_min.min(point)
					changed_max = changed_max.max(point)
			eligible += 1
			material_changes.append({"sequence": entry.sequence, "kind": kind,
				"declared_cells": entry.command_indices.size(),
				"first_index": entry.command_indices[0], "last_index": entry.command_indices[-1],
				"tuple_example_material_a_b_temperature_bytes": Array(entry.command_after.slice(0, 5))})
		elif kind in ["object_spawn", "object_duplicate", "object_delete", "object_update"]:
			var id: String = str(entry.get("object_id", ""))
			var target: int = _find(objects, id)
			var after: Array = entry.get("after_objects", [])
			var after_index: int = _find(after, id)
			if kind in ["object_spawn", "object_duplicate"]:
				if target >= 0 or after_index < 0:
					return _refuse("promotion_object_identity_conflict: " + id)
				objects.append(after[after_index].duplicate(true))
				# A newly designated subject transfers the single project role,
				# just as the accepted live spawn did. The frozen original still
				# contains the previous designation until this command is replayed.
				if bool(after[after_index].passive_subject):
					for object: Dictionary in objects:
						if str(object.id) != id:
							object.passive_subject = false
			elif kind == "object_delete":
				if target < 0:
					return _refuse("promotion_deleted_object_missing: " + id)
				objects.remove_at(target)
			else:
				if target < 0 or after_index < 0:
					return _refuse("promotion_updated_object_missing: " + id)
				var fields: Array = entry.get("explicit_fields", {}).get(id, [])
				if fields.is_empty():
					return _refuse("promotion_explicit_properties_missing: " + id)
				for field: String in fields:
					if field not in Registry.FIELDS or field in ["id", "creation_order", "schema_version"]:
						return _refuse("promotion_unsupported_object_property")
					objects[target][field] = after[after_index][field]
				if "passive_subject" in fields and bool(objects[target].passive_subject):
					for object: Dictionary in objects:
						if str(object.id) != id:
							object.passive_subject = false
			var checked: Dictionary = Registry.validate_graph(objects)
			if not bool(checked.ok):
				return _refuse("promotion_object_conflict: " + str(checked.error))
			objects = checked.definitions
			eligible += 1
			# Preview the applied frozen-scene result. The live journal snapshot
			# can contain view-only metadata outside this command's explicit fields.
			var replayed_index: int = _find(objects, id)
			object_changes.append({"sequence": entry.sequence, "kind": kind, "id": id,
				"initial_properties": Registry.logical_graph([objects[replayed_index]])[0] if replayed_index >= 0 else {},
				"applied_fields": entry.get("explicit_fields", {}).get(id, [])})
		else:
			skipped.append({"sequence": entry.get("sequence", 0), "kind": kind,
				"reason": "runtime_selection_or_unsupported_command_not_promoted"})
	if eligible == 0:
		return {"ok": false, "error": "no_eligible_declarative_interventions", "conflicts": skipped}
	# Preview describes the final initial-state difference, not the union of
	# intermediate commands. Paint followed by its original tuple can cancel.
	var final_changed_cells: int = 0
	changed_min = Vector2i(1024, 1024)
	changed_max = Vector2i(-1, -1)
	for index: int in changed_cells:
		var different: bool = false
		for component: int in 5:
			if cells[index * 5 + component] != frozen.initial_cells[index * 5 + component]:
				different = true
				break
		if different:
			final_changed_cells += 1
			var point: Vector2i = Vector2i(index % 1024, index / 1024)
			changed_min = changed_min.min(point)
			changed_max = changed_max.max(point)
	candidate.initial_cells = cells
	candidate.bodies = objects
	candidate.erase("authored_revision")
	candidate.erase("authored_cells_sha256")
	if candidate.has("project"):
		candidate.project.startup = "edit_paused"
		candidate.project.passive_subject_id = ""
		for object: Dictionary in objects:
			if bool(object.passive_subject):
				candidate.project.passive_subject_id = str(object.id)
	return {"ok": true, "definition": candidate, "eligible": eligible, "skipped": skipped.size(),
		"conflicts": skipped, "preview": {"changed_cells": final_changed_cells,
			"changed_cell_bounds_inclusive": [changed_min.x, changed_min.y, changed_max.x, changed_max.y] if final_changed_cells > 0 else [],
			"material_changes": material_changes, "object_count": objects.size(), "object_changes": object_changes},
		"summary": "%d declarative interventions; %d initial cells changed; %d objects; %d runtime-dependent commands excluded. Creates a new paused tick-zero draft; evolved physics and chemistry are discarded." % [eligible, final_changed_cells, objects.size(), skipped.size()]}


static func _find(objects: Array, id: String) -> int:
	for index: int in objects.size():
		if str(objects[index].get("id", "")) == id:
			return index
	return -1


static func _refuse(reason: String) -> Dictionary:
	return {"ok": false, "error": reason, "conflicts": [{"reason": reason}]}
