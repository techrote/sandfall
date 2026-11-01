extends SceneTree

# M5-B01 extends the retained M2/M3/M4 physical tests. Chemistry/history,
# partial-Rapier failure, Gallery feedback controls and project ZIP round trips
# stay in their original suites. This suite closes pacing and repeated-owner
# stress gaps using the production Session and actual native/Rapier owners.
const Host = preload("res://scripts/sandfall/simulation_host.gd")
const Session = preload("res://scripts/sandfall/session_controller.gd")
const Registry = preload("res://scripts/sandfall/rapier_object_registry.gd")
const MaterialTools = preload("res://scripts/sandfall/material_tools.gd")
const Codec = preload("res://scripts/sandfall/archive_codec.gd")
const SPEEDS: Array[String] = ["0.25", "0.5", "1", "2", "4"]
const PACED_TICKS: int = 60
# Float32 translation accumulation over 61 steps, measured in native cells.
# These limits are declared before measurement, not derived from passing runs.
const POSITION_TOLERANCE: float = 0.002
const ROTATION_TOLERANCE: float = 0.0001
const STRESS_TICKS: int = 120
const STRESS_COUNTS: Array[int] = [16, 0, 1, 3, 8, 16]

var _checks: int = 0
var _failures: Array[String] = []
var _receipts: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	if not CyberWebCapabilities.native_available() or not ClassDB.class_exists(&"SandfallEditBridge"):
		_check(false, "Required real native/Edit extension is unavailable")
		_finish()
		return
	await _all_five_fixed_step_presets()
	await _repeated_capacity_replacement()
	_finish()


func _all_five_fixed_step_presets() -> void:
	var matrix: Array = []
	var reference_cells: PackedByteArray = PackedByteArray()
	var reference_poses: Array = []
	for speed: String in SPEEDS:
		var host: Variant = Host.new()
		root.add_child(host)
		var session: Variant = Session.new(host)
		_command(session, "sandbox")
		var definition: Dictionary = session.authored_project()
		var body: Dictionary = Registry.make_box("fixed-dt-token", 1, Vector2(300, 100), Vector2(12, 14))
		body.gravity_scale = 0.0
		body.linear_damp = 0.0
		body.angular_damp = 0.0
		body.linear_velocity = Vector2(12, -6)
		body.angular_velocity = 0.5
		definition.bodies = [body]
		var installed: Dictionary = session.import_project(definition, session.state().generation, session.state().input_epoch)
		_check(installed.ok, "Fixed-dt fixture import failed")
		if not installed.ok:
			host.free()
			continue
		var chemical_index: int = 100 * 1024 + 100
		var thermal_index: int = 50 * 1024 + 150
		_mutate(session, chemical_index, MaterialTools.cell_tuple(22, 1, 0, 1500), "m5-steam-initial")
		_mutate(session, thermal_index, MaterialTools.cell_tuple(2, 0, 0, 777), "m5-hot-sand-initial")
		var initial_cells: PackedByteArray = host.capture_cells().cells.duplicate()
		var initial_poses: Array = host.state().body_states.duplicate(true)
		_check(session.state().document.undo_depth == 2 and session.state().tick == 0
			and session.state().rapier_steps == 0, "Chemical/thermal initial authoring did not remain tick zero")
		_command(session, "speed", speed)
		_command(session, "run")
		_command(session, "toggle_pause")
		for frame: int in 4:
			await process_frame
			_check(session.advance_frame() == 0, "Paused preset advanced a solver: " + speed)
		_check(host.capture_cells().cells == initial_cells and host.state().body_states == initial_poses,
			"Paused chemistry or actual body state changed")
		_command(session, "step")
		_check(session.advance_frame() == 1, "Preset Step did not advance exactly once: " + speed)
		_check(session.state().tick == 1 and session.state().rapier_steps == 1 and session.state().paused,
			"Preset Step counter/pause ownership is wrong")
		_check(session.state().document.undo_depth == 0 and session.state().document.redo_depth == 0
			and session.state().history_retired, "Preset first advancement retained thermochemical history")
		var chemical: Dictionary = MaterialTools.tuple_values(_at(host, chemical_index))
		var thermal: Dictionary = MaterialTools.tuple_values(_at(host, thermal_index + 1024))
		_check(chemical.id == 3 and thermal.id == 2 and thermal.temperature == 777,
			"Real phase transition/thermal transport did not occur on preset Step")
		_command(session, "toggle_pause")
		var frames: int = int(float(PACED_TICKS) / float(speed))
		var steps_by_frame: Array[int] = []
		var cumulative: int = 0
		for frame: int in frames:
			var before: Dictionary = host.state()
			var advanced: int = session.advance_frame()
			var after: Dictionary = host.state()
			cumulative += advanced
			steps_by_frame.append(advanced)
			_check(after.native_tick - before.native_tick == advanced and after.rapier_steps - before.rapier_steps == advanced,
				"Paced frame receipt differs from actual solver counters")
			_check(cumulative == int(float(frame + 1) * float(speed)), "Pacing credit changed the requested tick count")
			_check(after.fixed_delta == 1.0 / 60.0 and host._rapier_bridge.fixed_delta() == 1.0 / 60.0,
				"A speed preset changed the actual Rapier fixed step")
			if frame % 20 == 0: await process_frame
		_command(session, "toggle_pause")
		var final: Dictionary = host.state(true)
		var final_cells: PackedByteArray = host.capture_cells().cells
		_check(cumulative == PACED_TICKS and final.native_tick == PACED_TICKS + 1
			and final.rapier_steps == PACED_TICKS + 1, "Preset did not execute the registered actual workload")
		var seconds: float = float(PACED_TICKS + 1) / 60.0
		var pose: Array = final.body_states[0]
		var solver_iterations: int = int(ProjectSettings.get_setting("physics/rapier/solver/num_iterations", 0))
		_check(solver_iterations == 4, "Pinned Rapier solver-substep contract changed")
		# Rapier integrates float32 translations at every solver iteration.
		# Comparing 61 steps directly to an unrounded double-precision line
		# incorrectly flagged ordinary accumulated rounding (retained negative).
		# Model the pinned arithmetic; never widen the original tolerance.
		var expected_x: float = _float32_translation(300.0, 12.0, PACED_TICKS + 1, solver_iterations)
		var expected_y: float = _float32_translation(100.0, -6.0, PACED_TICKS + 1, solver_iterations)
		_check(absf(float(pose[0]) - expected_x) <= POSITION_TOLERANCE
			and absf(float(pose[1]) - expected_y) <= POSITION_TOLERANCE
			and absf(float(pose[2]) - 0.5 * seconds) <= ROTATION_TOLERANCE,
			"Actual undamped Rapier trajectory contradicts 1/60-second accounting")
		_check(final.contacts_total == 0 and final.body_body_pairs.is_empty(), "Fixed-dt control acquired unintended contacts")
		if reference_cells.is_empty():
			reference_cells = final_cells.duplicate()
			reference_poses = final.body_states.duplicate(true)
		else:
			_check(final_cells == reference_cells, "Same-source equal-tick chemical/thermal outcome depends on pacing")
			_compare_poses(reference_poses, final.body_states, "Equal-tick pacing")
		_command(session, "undo")
		_check(not session.state().document.can_undo and session.state().document.undo_depth == 0,
			"Pacing/Pause resurrected thermochemical history")
		_command(session, "reset_edit")
		_check(session.state().tick == 0 and session.state().rapier_steps == 0 and session.state().paused
			and session.state().mode == "edit" and session.state().document.undo_depth == 0,
			"Preset Reset & Edit did not start a fresh tick-zero history")
		_check(host.capture_cells().cells == initial_cells and host.state().body_states == initial_poses,
			"Reset reconstructed evolved cells/body velocities instead of authored initial state")
		matrix.append({"speed": float(speed), "frames": frames, "steps_by_frame": steps_by_frame,
			"paused_frames": 4, "single_step": 1, "paced_ticks": cumulative,
			"actual_native_ticks": final.native_tick, "actual_rapier_steps": final.rapier_steps,
			"fixed_delta": final.fixed_delta, "initial_poses": initial_poses, "final_poses": final.body_states,
			"solver_iterations": solver_iterations, "float32_expected_xy": [expected_x, expected_y],
			"ideal_real_xy": [300.0 + 12.0 * seconds, 100.0 - 6.0 * seconds],
			"post_step_chemical": chemical, "post_step_thermal": thermal,
			"initial_cells_sha256": Codec.sha256(initial_cells), "final_cells_sha256": Codec.sha256(final_cells),
			"reset_initial_cells_exact": host.capture_cells().cells == initial_cells,
			"reset_initial_poses_exact": host.state().body_states == initial_poses})
		host.free()
		await process_frame
	_receipts.fixed_step_presets = {"position_tolerance_cells": POSITION_TOLERANCE,
		"rotation_tolerance_radians": ROTATION_TOLERANCE, "cases": matrix,
		"scope": "same source, same worker count and platform; equal-tick local comparison, not cross-platform bitwise replay"}


func _repeated_capacity_replacement() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "gallery", "sixteen_body")
	_command(session, "reset_edit")
	var base: Dictionary = session.authored_project()
	base.project.startup = "edit_paused"
	var cases: Array = []
	var retired_instance_ids: Array[int] = []
	var previous_container: int = 0
	for repetition: int in [1, 2]:
		for count: int in STRESS_COUNTS:
			var definition: Dictionary = base.duplicate(true)
			definition.bodies = base.bodies.slice(0, count).duplicate(true)
			for index: int in count:
				definition.bodies[index].linear_velocity = Vector2(2.5, -1.25)
				definition.bodies[index].angular_velocity = 0.2
			var old_generation: int = session.state().generation
			for body: RigidBody2D in host._bodies:
				retired_instance_ids.append(body.get_instance_id())
			var installed: Dictionary = session.import_project(definition, old_generation, session.state().input_epoch)
			_check(installed.ok, "Repeated capacity import failed: %d/%d" % [repetition, count])
			if not installed.ok: continue
			await process_frame
			for instance_id: int in retired_instance_ids:
				_check(not is_instance_id_valid(instance_id), "Replacement retained an old body instance")
			retired_instance_ids.clear()
			if previous_container != 0:
				_check(not is_instance_id_valid(previous_container), "Repeated import retained the old physical container")
			previous_container = host._adopted_container.get_instance_id()
			var initial: Dictionary = host.state(true)
			_check(initial.native_tick == 0 and initial.rapier_steps == 0 and initial.body_ids.size() == count
				and not initial.owned_physics_space_active, "Repeated import secretly stepped or changed body capacity")
			_check(host.get_child_count() == 1 and host._adopted_container.get_child_count() == 1,
				"Repeated replacement grew the ownership-container depth")
			_check(initial.body_states == initial.initial_body_states
				and host.capture_cells().cells == definition.initial_cells, "Repeated import lost authored initial data")
			for index: int in count:
				_check(Vector2(initial.body_states[index][3], initial.body_states[index][4]) == Vector2(2.5, -1.25)
					and absf(float(initial.body_states[index][5]) - 0.2) < 0.000001,
					"Repeated import lost actual initial velocity through scene-tree frames")
			if count > 0:
				# Force a real shape/RID rebuild, then exact Edit undo, before the run.
				var retired: int = host._bodies[0].get_instance_id()
				_object_edit(session, {"operation": "update", "id": definition.bodies[0].id,
					"changes": {"size": definition.bodies[0].size + Vector2(2, 2)}})
				_check(not is_instance_id_valid(retired), "Resize did not retire its replaced body owner")
				_command(session, "undo")
				_check(host.get_object_definitions() == definition.bodies and host.state().body_states == initial.body_states,
					"Rebuild/Undo failed to restore exact initial graph and actual velocities")
			if count == 16:
				var before: Dictionary = host.capture_physical_state()
				_object_edit(session, {"operation": "spawn", "definition": {"position": Vector2(440, 50)}})
				var after: Dictionary = host.capture_physical_state()
				_check(session.state().last_refusal == "object_capacity_16" and before.native_payload == after.native_payload
					and before.bodies == after.bodies and host.get_object_definitions() == definition.bodies,
					"Repeated-capacity body17 refusal changed the live project")
			_command(session, "run")
			for tick: int in STRESS_TICKS:
				_check(session.advance(), "Repeated capacity owner failed a requested tick")
				if tick % 30 == 0: await process_frame
			var final: Dictionary = host.state(true)
			_check(final.native_tick == STRESS_TICKS and final.rapier_steps == (STRESS_TICKS if count > 0 else 0),
				"Repeated capacity solver counters are wrong")
			_check(Array(final.body_ids) == Array(initial.body_ids)
				and Array(final.slot_mapping.project_ids) == Array(initial.body_ids),
				"Stable IDs/dense slot mapping changed under stress")
			if count == 0:
				_check(not final.bridge_active and final.object_feedback.is_empty(), "Zero-body replacement retained feedback authority")
			else:
				for id: String in final.body_ids:
					_check(int(final.object_feedback[id].samples) == STRESS_TICKS, "Repeated owner missed a native body sample")
				_check(final.contacts_total > 0, "Repeated actual scene had no native-material contact")
				if count == 16:
					_check(not final.body_body_pairs.is_empty(), "Repeated sixteen-body scene had no real body/body contact")
			cases.append({"repetition": repetition, "body_count": count, "generation": session.state().generation,
				"replaced_generation": old_generation, "ticks": final.native_tick, "rapier_steps": final.rapier_steps,
				"initial_cells_sha256": initial.current_material_sha256, "initial_body_poses": initial.body_states,
				"final_body_poses": final.body_states, "body_body_pairs": final.body_body_pairs,
				"contacts": final.contacts_total, "displaced": final.displaced_total,
				"feedback": final.object_feedback, "bounded_container_count": host.get_child_count()})
			print("SF_M5_SCIENCE_PROGRESS ", JSON.stringify({"repetition": repetition, "bodies": count,
				"ticks": final.native_tick, "failures": _failures.size()}))
			# Freeze a real evolved owner so the next import must retire it.
			_command(session, "toggle_pause")
	_receipts.capacity_replacement = {"repetitions": 2, "sequence": STRESS_COUNTS,
		"ticks_per_owner": STRESS_TICKS, "cases": cases}
	host.free()
	await process_frame
	_check(not is_instance_id_valid(previous_container), "Final shutdown leaked an adopted owner")


func _at(host: Variant, index: int) -> PackedByteArray:
	return PackedByteArray(host.capture_cells().cells).slice(index * 5, index * 5 + 5)


func _float32_translation(initial: float, velocity: float, ticks: int, iterations: int) -> float:
	if iterations <= 0: return NAN
	var sub_dt: float = PackedFloat32Array([PackedFloat32Array([1.0 / 60.0])[0] / iterations])[0]
	var increment: float = PackedFloat32Array([velocity * sub_dt])[0]
	var position: float = initial
	for substep: int in ticks * iterations:
		position = PackedFloat32Array([position + increment])[0]
	return position


func _mutate(session: Variant, index: int, tuple: PackedByteArray, kind: String) -> void:
	var state: Dictionary = session.state()
	_check(session.enqueue_mutation(PackedInt32Array([index]), tuple, kind,
		state.document.revision, state.generation, state.input_epoch), "Scientific initial mutation was refused at admission")
	session.process_commands()
	_check(bool(session.state().last_edit.get("accepted", false)), "Scientific initial mutation was not accepted")


func _object_edit(session: Variant, operation: Dictionary) -> void:
	var state: Dictionary = session.state()
	_check(session.enqueue_object_edit(operation, state.document.revision, state.generation, state.input_epoch),
		"Scientific object command was refused at queue admission")
	session.process_commands()


func _command(session: Variant, action: String, value: String = "") -> void:
	_check(session.enqueue(action, value), "Scientific command was refused at admission: " + action)
	session.process_commands()


func _compare_poses(expected: Array, actual: Array, label: String) -> void:
	_check(expected.size() == actual.size(), label + " changed body count")
	for index: int in mini(expected.size(), actual.size()):
		for component: int in 6:
			var tolerance: float = ROTATION_TOLERANCE if component in [2, 5] else POSITION_TOLERANCE
			_check(absf(float(expected[index][component]) - float(actual[index][component])) <= tolerance,
				label + " exceeded declared local numerical tolerance")


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(message)
		print("SF_M5_SCIENCE_FAILURE ", message)


func _finish() -> void:
	print("SANDFALL_SCIENTIFIC_TEST ", JSON.stringify({"schema_version": 1, "ok": _failures.is_empty(),
		"checks": _checks, "failures": _failures, "receipts": _receipts,
		"scope": "actual source-matched native/Rapier local scientific test; browser and human acceptance remain separate"}))
	quit(0 if _failures.is_empty() else 1)
