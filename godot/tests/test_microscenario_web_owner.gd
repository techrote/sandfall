extends SceneTree

# Required shared-Web owner contracts extracted from historical desktop Tower case.
# Full regression profile retains original cross-owner parity comparisons.
const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
var failures: int = 0
var assertions: int = 0

class WebSpy:
	extends "res://scripts/web_demo_controller.gd"
	var captured: Dictionary = {}
	func _write_microscenario_capture(report: Dictionary) -> void:
		captured = report.duplicate(true)

func _init() -> void:
	call_deferred("_run")

func expect(value: bool, message: String) -> void:
	assertions += 1
	if value: return
	failures += 1
	push_error(message)

func key(code: Key, pressed: bool, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return event

func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	root.size = Vector2i(1600, 1200)
	var definition: Dictionary = Catalogue.unequal_head(2)
	var wanted: String = Contract.validate(definition).hash
	var invalid: Dictionary = definition.duplicate(true)
	invalid.seed = -1

	var web: Control = load("res://web_main.tscn").instantiate()
	web.set_script(WebSpy)
	root.add_child(web)
	await process_frame
	web.set_physics_process(false) # Explicit test stepping; presentation still consumes state.
	web.focused = true
	web.ui.close_menu()
	expect(web.ready_to_play, "synchronous controller did not initialize")
	var desktop_only_player_fixture: Dictionary = Catalogue.definition(
		"rem003/player-granular-review/sampled-baseline",
		0
	)
	expect(
		not web.microscenario_apply_definition(
			desktop_only_player_fixture,
			"Play"
		),
		"Web silently accepted a desktop-only PLAY-VAL player fixture"
	)
	expect(
		"desktop asynchronous owner" in web.microscenario_error,
		"Web player-fixture refusal did not explain its platform scope"
	)
	expect(web.microscenario_apply_definition(definition, "Benchmark"), "Web-owner generic definition refused")
	expect(web.micro_host.summary().definition_hash == wanted, "owners disagree on definition identity")
	web.microscenario_capture()
	expect(web.captured.completed_tick == 0 and not web.captured.replay_complete, "Web initial capture is not truthful")
	expect(not web._encode_current().ok, "generic level export falsely represents scenario continuation")
	expect(not web.set_quality(2) and not web.set_liquid_surface_adhesion(false), "fixed synchronous fixture accepted a live semantic override")
	expect(not web.queue_explosion_mutation(80,180,4), "unregistered generic explosion accepted")
	expect(not web.queue_brush_mutation(80,180,0,2), "undeclared Web generic brush accepted")
	expect(web.tower_command({"step":true}), "Web single step refused")
	web._physics_process(1.0/60.0)
	web._physics_process(1.0/60.0)
	expect(web.native_world.get_tick_index() == 1, "Web single step was not exactly one tick")
	web.microscenario_capture()
	# Cross-owner parity remains in the full historical desktop diagnostic.
	expect(web.captured.completed_tick == 1
		and web.captured.native.has("content_hash")
		and web.captured.native.has("water_integer"),
		"Web completed-tick capture lost content/quantity")
	web.microscenario_panel._open_definition()
	web.microscenario_panel.definition_text.text = "{invalid"
	web.microscenario_panel._apply_definition()
	expect(web.native_world.get_tick_index() == 1, "invalid pasted JSON changed the World")
	web.microscenario_panel.definition_dialog.hide()
	var before: Dictionary = web.captured.native.duplicate(true)
	expect(not web.microscenario_apply_definition(invalid), "invalid Web definition accepted")
	web.microscenario_capture()
	expect(web.captured.native == before, "rejected Web reset mutated state")
	web._unhandled_key_input(key(KEY_R,true))
	expect(web.native_world.get_tick_index() == 0 and web.micro_host.summary().definition_hash == wanted, "Web R did not retain the selected fixture")
	web.tower_reset()
	expect(not web.tower_context.get("micro_active",false), "Web generic -> Tower reset failed")
	web.rapier_bridge.shutdown()
	web.queue_free()
	await process_frame
	print("MICROSCENARIO_WEB_OWNER: %d assertions; %d failures" % [assertions, failures])
	quit(1 if failures else 0)
