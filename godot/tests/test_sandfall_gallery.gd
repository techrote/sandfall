extends SceneTree

# Real native/Rapier runs, including a no-water control for the fluid subject.
# Receipts are outcome measurements; they do not claim bitwise replay or human
# exhibition acceptance. Browser input/rendering is qualified independently.
const Host = preload("res://scripts/sandfall/simulation_host.gd")
const Scenes = preload("res://scripts/sandfall/scene_definitions.gd")
const Gallery = preload("res://scripts/sandfall/gallery.gd")
const Presentation = preload("res://scripts/sandfall/presentation_model.gd")

var _checks: int = 0
var _failures: Array[String] = []
var _receipts: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	_check(Gallery.entries().size() == 7 and Gallery.entries("subject water").size() == 2, "Gallery search does not match title/mechanism/material metadata")
	var copy: Array = Gallery.entries()
	copy[0].title = "changed"
	_check(Gallery.entries()[0].title == "Gravity Cascade", "Gallery leaked mutable catalogue ownership")
	for id: String in Gallery.ids():
		var definition: Dictionary = Scenes.get_definition(id)
		_check(not definition.is_empty() and definition.project.startup == "run_autoplay", "Gallery has no complete initial definition: " + id)
		_check(Presentation.validate(definition.presentation).ok, "Gallery decoration is malformed: " + id)
		for repetition: int in [1, 2]:
			await _measure(definition, 600, repetition)
	var control: Dictionary = Scenes.get_definition("fluid_messenger")
	control.id = "fluid-messenger-no-water-control"
	control.rectangles = PackedInt32Array([0, 0, 1024, 1024, 0, 10, 220, 460, 4, 1, 10, 40, 4, 180, 1, 466, 40, 4, 180, 1])
	await _measure(control, 600, 1)
	print("SANDFALL_GALLERY_RESULT ", JSON.stringify({"ok": _failures.is_empty(), "checks": _checks, "failures": _failures, "runs": _receipts}))
	quit(0 if _failures.is_empty() else 1)


func _measure(definition: Dictionary, target: int, repetition: int) -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var first: Dictionary = host.configure(definition)
	_check(first.ready and first.native_tick == 0 and first.rapier_steps == 0, "Gallery failed zero-tick readiness: " + str(definition.id))
	if not first.ready:
		host.free()
		return
	var initial: Array = first.body_states.duplicate(true)
	var times: Array[int] = []
	var completed: int = 0
	for attempt: int in range(target + 100):
		if completed >= target: break
		var started: int = Time.get_ticks_usec()
		var receipt: Dictionary = host.tick_once()
		if bool(receipt.advanced):
			completed += 1
			times.append(Time.get_ticks_usec() - started)
		if bool(receipt.fault):
			_check(false, "Gallery entered Fault: " + str(receipt.error))
			break
		if attempt % 30 == 0: await process_frame
	var final: Dictionary = host.state(true)
	_check(completed == target and final.native_tick == target and final.rapier_steps == target, "Gallery did not complete fixed coupled workload: " + str(definition.id))
	_check(final.body_ids.size() == definition.bodies.size(), "Gallery changed bounded body count")
	for pose: Array in final.body_states:
		_check(is_finite(float(pose[0])) and is_finite(float(pose[1])) and float(pose[0]) >= 0 and float(pose[0]) <= 1024 and float(pose[1]) >= 0 and float(pose[1]) <= 1024, "Gallery body escaped physical bounds")
	if definition.id == "endless_kinetic_loop":
		for index: int in initial.size():
			_check(Vector2(final.body_states[index][0], final.body_states[index][1]).distance_to(Vector2(initial[index][0], initial[index][1])) < 0.1, "Idealized inertial loop drifted outside its bounded centres")
			_check(absf(float(final.body_states[index][5])) > 0.9 and absf(float(final.body_states[index][2]) - float(initial[index][2])) > 0.1, "Inertial loop lost real angular motion")
	else:
		if str(definition.id).contains("no-water-control"):
			_check(Vector2(final.body_states[0][0], final.body_states[0][1]).distance_to(Vector2(initial[0][0], initial[0][1])) < 0.001, "No-water control moved without force")
			_check(final.contacts_total == 0 and int(final.object_feedback[final.body_ids[0]].applications) == 0, "No-water control reports synthetic fluid feedback")
		else:
			_check(final.moves_total > 0, "Gallery native cells never moved")
			_check(final.contacts_total > 0, "Gallery has no body/material contact")
			if definition.id in ["fluid_messenger", "passive_subject_ride"]:
				var subject: String = str(definition.project.passive_subject_id)
				var feedback: Dictionary = final.object_feedback[subject]
				_check(int(feedback.applications) > 0 and Vector2(float(feedback.accepted_impulse_x), float(feedback.accepted_impulse_y)).length() > 0.0, "Passive subject has no actual native-to-Rapier impulse")
				_check(Vector2(final.body_states[0][0], final.body_states[0][1]).distance_to(Vector2(initial[0][0], initial[0][1])) > 0.1, "Native fluid feedback did not move the real subject")
			if definition.id == "sixteen_body":
				_check(final.body_ids.size() == 16 and not final.body_body_pairs.is_empty(), "Sixteen-body exhibition lacks independent contacts")
	var restored: Dictionary = host.configure(definition)
	_check(restored.ready and restored.body_states == initial and restored.native_tick == 0 and restored.rapier_steps == 0, "Gallery Reset did not reconstruct authored initial poses")
	times.sort()
	_receipts.append({"scene": definition.id, "repetition": repetition, "ticks": completed, "initial_body_poses": initial,
		"final": final, "reset_body_poses": restored.body_states, "coupled_tick_usec": {
			"p50": times[times.size() / 2] if not times.is_empty() else 0,
			"p95": times[int(times.size() * 0.95)] if not times.is_empty() else 0,
			"max": times.back() if not times.is_empty() else 0}})
	host.free()
	await process_frame


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(message)
		print("SF_M4_GALLERY_FAILURE ", message)
