extends SceneTree

# Actual native/Rapier lifecycle tests. Commands here exercise the application
# owner directly; genuine pointer/key acceptance belongs to the browser suite.
const Host = preload("res://scripts/sandfall/simulation_host.gd")
const Session = preload("res://scripts/sandfall/session_controller.gd")

class RefusingNativeHost extends Host:
	func _advance_native_tick() -> bool:
		return false

var _failures: Array[String] = []
var _receipts: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	await _native_lifecycle()
	await _coupled_lifecycle()
	await _partial_fault()
	await _dedicated_entry()
	print("SANDFALL_SESSION_TEST ", JSON.stringify({"ok": _failures.is_empty(),
		"failures": _failures, "receipts": _receipts,
		"scope": "actual native/Rapier lifecycle and entry instantiation; fault refusal explicitly injected; browser input qualified separately"}))
	quit(0 if _failures.is_empty() else 1)


func _native_lifecycle() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "sandbox")
	var blank: Dictionary = session.state()
	_expect(blank.ready and blank.entry == "sandbox" and blank.mode == "edit" and blank.paused,
		"Sandbox did not enter ready paused Edit")
	_expect(blank.tick == 0 and blank.rapier_steps == 0, "Sandbox construction advanced physics")
	_expect(not session.enqueue("step"), "Edit accepted a Step request")
	for _frame: int in range(4):
		await physics_frame
		_expect(not session.advance(), "Edit advanced during ordinary frames")
	_command(session, "template", "material_lab")
	var initial: Dictionary = session.state()
	_expect(initial.tick == 0 and initial.current_hash == initial.initial_hash, "Native template changed during Edit setup")
	var editable_copy: Dictionary = session.initial_definition()
	_command(session, "run")
	var frozen_hash: String = session.state().definition_hash
	editable_copy.rectangles = PackedInt32Array([0, 0, 1024, 1024, 1])
	var frozen_copy: Dictionary = session.frozen_definition()
	frozen_copy.rectangles = PackedInt32Array([0, 0, 1024, 1024, 2])
	_expect(session.state().definition_hash == frozen_hash and session.frozen_definition().rectangles != frozen_copy.rectangles,
		"Run did not retain an independent immutable initial recipe")
	for _tick: int in range(3):
		_expect(session.advance(), "Native-only Run refused a tick")
	_command(session, "toggle_pause")
	var paused: Dictionary = session.state()
	_expect(paused.paused and paused.tick == 3 and paused.rapier_steps == 0 and paused.history_retired,
		"Native Run/Pause ownership was incorrect")
	_expect(session.enqueue("step"), "Paused Run refused Step")
	_expect(not session.enqueue("step"), "Duplicate queued Step was accepted")
	session.process_commands()
	_expect(session.advance(), "Accepted native Step did not advance")
	var stepped: Dictionary = session.state()
	_expect(stepped.tick == 4 and stepped.rapier_steps == 0 and stepped.paused and stepped.pending_steps == 0,
		"Native Step was not exactly +1/+0 and paused")
	for _frame: int in range(4):
		await physics_frame
		_expect(not session.advance(), "Pause autonomously advanced")
	_expect(session.state().current_hash == stepped.current_hash, "Paused material identity changed")
	# A queued Step is retired by a later reset in the same main-thread batch.
	var retired_generation: int = stepped.generation
	_expect(session.enqueue("step"), "Reset negative setup could not queue Step")
	_expect(session.enqueue("reset"), "Reset negative setup could not queue Reset")
	session.process_commands()
	var reset: Dictionary = session.state()
	_expect(reset.mode == "run" and reset.paused and reset.tick == 0 and reset.rapier_steps == 0
		and reset.current_hash == initial.initial_hash and reset.pending_steps == 0,
		"Sandbox reset did not reconstruct the frozen tick-zero recipe and retire Step")
	_expect(not session.enqueue("step", "", retired_generation), "Delayed old-session command was accepted")
	_expect(not session.advance(), "Reset leaked a queued Step")
	# Menu blocks a pending request and retains prior pause state on Continue.
	_expect(session.enqueue("step"), "Menu negative setup could not queue Step")
	_expect(session.enqueue("menu"), "Menu negative setup could not queue menu")
	session.process_commands()
	_expect(session.state().menu and session.state().pending_steps == 0 and not session.advance(),
		"Menu retained pending simulation input")
	_command(session, "continue")
	_expect(not session.state().menu and session.state().paused and not session.advance(), "Continue changed prior Pause ownership")
	# Already-drained commands carry an input epoch too: opening a modal must
	# retire the rest of that batch, not only the now-empty member queue.
	var generation_before_menu: int = session.state().generation
	session.enqueue("menu")
	session.enqueue("gallery")
	session.process_commands()
	_expect(session.state().menu and session.state().entry == "sandbox"
		and session.state().generation == generation_before_menu and not session.advance(),
		"Modal entry allowed a retired command from the drained batch")
	_command(session, "continue")
	_command(session, "toggle_pause")
	session.focus_lost()
	_expect(session.state().paused and session.state().pending_steps == 0 and not session.advance(), "Blur did not stop and clear input")
	_command(session, "reset_edit")
	var edited: Dictionary = session.state()
	_expect(edited.mode == "edit" and edited.paused and edited.tick == 0 and edited.rapier_steps == 0,
		"Reset & Edit did not create a clean editable baseline")
	_expect(edited.edit_epoch > initial.edit_epoch and edited.history_supported and edited.document.undo_depth == 0 and edited.document.redo_depth == 0,
		"Reset & Edit reused the old epoch or retained old history")
	_receipts.native = {"blank": blank, "initial": initial, "paused": paused,
		"step": stepped, "reset": reset, "reset_edit": edited,
		"stale_generation_refused": true, "duplicate_step_refused": true}
	host.free()
	await process_frame


func _coupled_lifecycle() -> void:
	var host: Variant = Host.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "sandbox")
	_command(session, "template", "physics_pit")
	var initial: Dictionary = session.state()
	_expect(initial.ready and initial.tick == 0 and initial.rapier_steps == 0 and initial.rapier_active
		and initial.native.pending_colliders == 0, "Coupled Edit was not fully ready at zero")
	_command(session, "run")
	_expect(session.advance(), "Coupled Run refused first tick")
	_command(session, "toggle_pause")
	var before: Dictionary = session.state()
	_command(session, "step")
	_expect(session.advance(), "Coupled Step did not advance")
	var after: Dictionary = session.state()
	_expect(after.tick == before.tick + 1 and after.rapier_steps == before.rapier_steps + 1 and after.paused,
		"Coupled Step did not advance exactly +1/+1")
	_command(session, "reset")
	var reset: Dictionary = session.state()
	_expect(reset.tick == 0 and reset.rapier_steps == 0 and reset.current_hash == initial.initial_hash
		and reset.body_poses == initial.body_poses and reset.paused and reset.mode == "run",
		"Coupled reset did not restore materials/body poses and paused Run")
	_command(session, "gallery")
	var gallery_ready: Dictionary = session.state()
	_expect(gallery_ready.ready and not gallery_ready.paused and gallery_ready.mode == "run"
		and gallery_ready.tick == 0 and gallery_ready.rapier_steps == 0 and gallery_ready.native.pending_colliders == 0,
		"Gallery autoplay was enabled before complete zero-tick readiness")
	for _tick: int in range(5):
		_expect(session.advance(), "Gallery did not autoplay after readiness")
	var gallery_run: Dictionary = session.state()
	_expect(gallery_run.tick == 5 and gallery_run.rapier_steps == 5, "Gallery did not execute actual paired ticks")
	_command(session, "reset")
	_expect(session.state().tick == 0 and not session.state().paused and session.state().ready,
		"Gallery reset did not follow readiness/autoplay policy")
	_receipts.coupled = {"initial": initial, "before_step": before, "after_step": after,
		"reset": reset, "gallery_ready_at_zero": gallery_ready, "gallery_run": gallery_run}
	host.free()
	await process_frame


func _partial_fault() -> void:
	var host: Variant = RefusingNativeHost.new()
	root.add_child(host)
	var session: Variant = Session.new(host)
	_command(session, "gallery")
	_expect(not session.advance(), "Injected partial failure reported successful advancement")
	var fault: Dictionary = session.state()
	_expect(fault.mode == "fault" and fault.paused and fault.tick == 0 and fault.rapier_steps == 1
		and fault.history_retired and fault.pending_steps == 0, "Partial Fault lost actual solver counts or history/input retirement")
	_expect(not session.enqueue("step"), "Fault accepted Step")
	_command(session, "toggle_pause")
	_command(session, "run")
	for _frame: int in range(3):
		await physics_frame
		_expect(not session.advance(), "Partial Fault resumed physics")
	_expect(session.state().rapier_steps == 1 and session.state().tick == 0, "Partial Fault counters changed after refusal")
	_command(session, "reset_edit")
	var reset: Dictionary = session.state()
	_expect(reset.mode == "edit" and reset.tick == 0 and reset.rapier_steps == 0 and reset.paused,
		"Explicit Fault reset did not establish a new tick-zero Edit baseline")
	_receipts.negative_injected_partial_failure = {"fault": fault, "explicit_reset": reset}
	host.free()
	await process_frame


func _dedicated_entry() -> void:
	_expect(str(ProjectSettings.get_setting("application/run/main_scene")) == "res://sandfall_main.tscn",
		"Project still starts an inherited host")
	_expect(int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 1280
		and int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 800
		and int(ProjectSettings.get_setting("display/window/size/window_width_override")) == 1280
		and int(ProjectSettings.get_setting("display/window/size/window_height_override")) == 800
		and str(ProjectSettings.get_setting("display/window/stretch/mode")) == "canvas_items",
		"Dedicated Sandfall layout does not use the source-bound 1280x800 canvas_items contract")
	_expect(not ProjectSettings.has_setting("autoload/FeatureNavigation"), "Inherited launcher autoload retains authority")
	var scene: PackedScene = load("res://sandfall_main.tscn")
	var app: Control = scene.instantiate()
	root.add_child(app)
	await process_frame
	var state: Dictionary = app.observation()
	_expect(state.app_ready and state.entry == "home" and state.tick == 0 and state.rapier_steps == 0,
		"Dedicated entry did not reach an idle home")
	_expect(state.actor_count == 0 and state.paint_commands == 0, "Dedicated entry installed inherited actor/action authority")
	_expect(state.buttons.has("gallery") and state.buttons.has("sandbox"), "Dedicated entry lacks both actual controls")
	_receipts.entry = state
	app.free()
	await process_frame


func _command(session: Variant, action: String, value: String = "") -> void:
	_expect(session.enqueue(action, value), "Could not enqueue " + action)
	session.process_commands()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
