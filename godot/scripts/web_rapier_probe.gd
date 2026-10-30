class_name CyberWebRapierProbe
extends RefCounted

# Opt-in acceptance fixture, shared by native headless and actual Web runtime.
# Owns the demo only while testing; never enabled on a normal play URL.

# SF-M0: read-only progress for the opt-in actual-browser diagnostic. All
# measurements are observations; this does not modify solver state, timing or
# the 600-tick acceptance requirements. The terminal result remains authoritative.
static func _sf_m0_progress(host: Node, phase: String, index: int = -1) -> void:
	var entry: Dictionary = {"phase": phase, "index": index,
		"elapsed_ms": Time.get_ticks_msec(),
		"tick": int(host.native_world.get_tick_index()),
		"rapier_steps": int(host.rapier_bridge.manual_step_count()),
		"pending_colliders": int(host.rapier_bridge.pending_hard_surface_chunks()),
		"rapier_initialized": bool(host.rapier_bridge.is_initialized()),
		"menu_open": bool(host.ui.open), "paused": bool(host.paused)}
	var value: String = JSON.stringify(entry)
	print("SF_M0_RAPIER_PHASE ", value)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.sandfallM0ProbeProgress = " + value + ";", true)
static func run(host: Node) -> Dictionary:
	var failures: Array[String] = []
	if not host.rapier_available:
		return {"ok": false, "failures": [host.rapier_reason]}
	_sf_m0_progress(host, "probe-enter")
	host.set_physics_process(false)
	host.set_process(false)
	_sf_m0_progress(host, "select-physics-pit-before")
	host.select_demo("physics_pit")
	_sf_m0_progress(host, "select-physics-pit-after")
	host.focused = true
	host.input_armed = false
	# Complete the bounded collider queue before advancing either solver.
	_sf_m0_progress(host, "collider-drain-start")
	for i: int in range(256):
		if i < 2 or (i % 32) == 0:
			_sf_m0_progress(host, "collider-drain", i)
		host._sync_web_colliders()
		if host.rapier_bridge.pending_hard_surface_chunks() == 0:
			break
	_sf_m0_progress(host, "collider-drain-finished")
	if host.rapier_bridge.pending_hard_surface_chunks() != 0:
		failures.append("Collider queue did not drain")
	var contacts: int = 0
	var displaced: int = 0
	var maximum_floor_y: float = 0.0
	_sf_m0_progress(host, "tick-loop-start")
	for tick: int in range(600):
		if tick == 0 or tick == 1 or (tick % 20) == 0:
			_sf_m0_progress(host, "tick-before", tick)
		host._physics_process(1.0 / 60.0)
		if tick == 0 or tick == 1 or (tick % 20) == 0:
			_sf_m0_progress(host, "tick-after", tick)
		maximum_floor_y = maxf(maximum_floor_y, host.rapier_bridge.body_transform(0).origin.y)
		contacts += int(host.native_world.get_rigid_body_contacts_last_tick())
		displaced += int(host.native_world.get_rigid_body_displaced_last_tick())
		if tick % 20 == 0:
			await host.get_tree().process_frame
	_sf_m0_progress(host, "tick-loop-finished")
	var bodies: Array = host._metadata().bodies
	if int(host.native_world.get_tick_index()) != 600 or host.rapier_bridge.manual_step_count() != 600:
		failures.append("Cellular/Rapier step ownership mismatch")
	# Centre rests at 159; permit up to 2px transient solver penetration,
	# but never passage through the floor at y=166.
	if absf(bodies[0][1] - 159.0) > 0.1 or maximum_floor_y > 161.0:
		failures.append("One-pixel floor did not hold body")
	if bodies[1][1] <= 100.0 or bodies[2][1] <= 100.0:
		failures.append("Water/Sand bodies did not fall")
	if contacts <= 0 or displaced <= 0:
		failures.append("No two-way cellular contact/displacement")
	host.paused = true
	var before: Dictionary = host._metadata()
	host._physics_process(1.0 / 60.0)
	if host._metadata() != before or int(host.native_world.get_tick_index()) != 600:
		failures.append("Pause advanced simulation")
	host.paused = false
	host.ui.show_page("home")
	host._physics_process(1.0 / 60.0)
	if host._metadata() != before or host.rapier_bridge.manual_step_count() != 600:
		failures.append("Menu advanced Rapier")
	_sf_m0_progress(host, "roundtrip-start")
	var encoded: Dictionary = host._encode_current()
	if not encoded.ok:
		failures.append("Physics save encode failed")
	else:
		host.select_demo("neon_works", false)
		if host.rapier_bridge.is_initialized() or not host.rigid_bodies.is_empty():
			failures.append("Demo switch retained physics")
		host.import_save(encoded.text)
		var restored: Dictionary = host._encode_current()
		if not restored.ok:
			failures.append("Restored physics level cannot be encoded")
		else:
			var original_save: Dictionary = CyberDemoSaveCodec.decode_text(encoded.text)
			var restored_save: Dictionary = CyberDemoSaveCodec.decode_text(restored.text)
			if original_save.world != restored_save.world:
				failures.append("Cellular payload did not round-trip exactly")
			# Rapier reconstructs a rotation matrix from the saved angle;
			# float32 atan2/sin/cos round-off is not an exact replay state.
			for i: int in range(3):
				for component: int in range(6):
					if absf(original_save.metadata.bodies[i][component] - restored_save.metadata.bodies[i][component]) > 0.00001:
						failures.append("Body state restore exceeded float32 tolerance")
				if original_save.metadata.bodies[i][6] != restored_save.metadata.bodies[i][6]:
					failures.append("Body sleep state changed on restore")
	_sf_m0_progress(host, "roundtrip-finished")
	host.select_demo("physics_pit", false)
	for i: int in range(3):
		if host.rapier_bridge.body_transform(i).origin != Vector2([124, 244, 384][i], 90):
			failures.append("Reset did not restore spawn")
	if int(host.native_world.get_tick_index()) != 0:
		failures.append("Reset did not reset cellular tick")
	var result: Dictionary = {"ok": failures.is_empty(), "failures": failures, "ticks": 600,
		"workers": int(host.native_world.get_worker_threads()), "bodies": bodies,
		"maximum_floor_y": maximum_floor_y, "contacts": contacts, "displaced": displaced}
	host.select_demo("neon_works", false)
	host.ui.show_page("home")
	host.set_process(true)
	host.set_physics_process(true)
	_sf_m0_progress(host, "complete")
	return result
