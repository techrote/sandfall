class_name SandfallSceneDefinitions
extends RefCounted

# Initial values only. No node, RID, live solver, or input owner is retained here.
# The retained three-body fixture now uses the same stable logical identities
# and versioned defaults as objects authored through the SF-M3 workshop.
const Registry = preload("res://scripts/sandfall/rapier_object_registry.gd")
const Gallery = preload("res://scripts/sandfall/gallery.gd")
const Presentation = preload("res://scripts/sandfall/presentation_model.gd")
const WORLD_SIZE: Vector2i = Vector2i(1024, 1024)
const INITIAL_VIEW: Vector2i = Vector2i(480, 270)
const IDS: Array[String] = ["blank", "material_lab", "physics_pit"]


static func ids() -> Array[String]:
	var result: Array[String] = IDS.duplicate()
	result.append_array(Gallery.ids())
	return result


static func get_definition(id: String) -> Dictionary:
	if id not in ids():
		return {}
	# The retained constructor requires at least one rectangle. An explicit
	# Empty carve describes a genuinely blank world without a synthetic tick.
	var rectangles: PackedInt32Array = PackedInt32Array([0, 0, 1024, 1024, 0])
	var bodies: Array[Dictionary] = []
	var title: String = "Blank Sandbox"
	if id in ["material_lab", "physics_pit"]:
		rectangles = CyberDemoWorlds.rectangles(id).duplicate()
		title = "Material Lab" if id == "material_lab" else "Physics Pit"
	if id == "physics_pit":
		for x: int in [124, 244, 384]:
			var order: int = bodies.size() + 1
			var body: Dictionary = Registry.make_box("physics-pit-%d" % order, order, Vector2(x, 90), Vector2(8, 14))
			# Preserve this inherited fixture's effective damping now that authored
			# coefficients replace world defaults: .15 + .1 and .35 + 1.0.
			body.linear_damp = 0.25
			body.angular_damp = 1.35
			bodies.append(body)
	var definition: Dictionary = {
		"id": id, "title": title, "revision": 1,
		"world_size": WORLD_SIZE, "initial_view": INITIAL_VIEW,
		"rectangles": rectangles, "bodies": bodies,
		# This authored window is independent of every camera operation. It
		# matches the fixed initial 480x270 curated installation and margins.
		"simulation_origin": Vector2i.ZERO,
		"simulation_size": WORLD_SIZE,
		"simulation_margin": Vector2i(32, 36),
		"cadence_lod": false,
	}
	if id in Gallery.ids():
		_curate(definition, Gallery.entry(id))
	return definition


static func _curate(definition: Dictionary, entry: Dictionary) -> void:
	definition.title = str(entry.title)
	definition.rectangles = PackedInt32Array([
		0, 0, 1024, 1024, 0,
		10, 220, 460, 4, 1,
		10, 40, 4, 180, 1,
		466, 40, 4, 180, 1,
		14, 170, 452, 50, 3,
	])
	definition.bodies = []
	var count: int = 3
	if entry.id == "sixteen_body": count = 16
	if entry.id == "fluid_messenger": count = 1
	for index: int in count:
		var position: Vector2 = Vector2(100 + index * 140, 70)
		if count == 16:
			position = Vector2(70 + (index % 4) * 100, 50 + (index / 4) * 35)
		var body: Dictionary = Registry.make_box(str(entry.id) + "-%02d" % (index + 1), index + 1, position, Vector2(14, 14))
		if entry.id in ["fluid_messenger", "passive_subject_ride"] and index == 0:
			body.name = "Messenger" if entry.id == "fluid_messenger" else "Passive Subject"
			body.passive_subject = true
			body.position = Vector2(240, 185)
			body.mass = 0.1
			body.gravity_scale = 0.0
		definition.bodies.append(body)
	if entry.id == "gravity_cascade":
		definition.rectangles.append_array(PackedInt32Array([
			40, 28, 64, 20, 2, 170, 34, 60, 20, 2, 330, 28, 60, 20, 2,
			30, 105, 50, 3, 1, 160, 120, 50, 3, 1, 320, 105, 50, 3, 1,
		]))
	if entry.id == "endless_kinetic_loop":
		definition.rectangles = PackedInt32Array([0, 0, 1024, 1024, 0,
			10, 220, 460, 4, 1, 10, 40, 4, 180, 1, 466, 40, 4, 180, 1])
		for index: int in definition.bodies.size():
			definition.bodies[index].position = Vector2(110 + index * 130, 135)
			definition.bodies[index].size = Vector2(70, 12)
			definition.bodies[index].gravity_scale = 0.0
			definition.bodies[index].linear_damp = 0.0
			definition.bodies[index].angular_damp = 0.0
			definition.bodies[index].angular_velocity = 1.0 if index % 2 == 0 else -1.0
	var subject: String = ""
	for body: Dictionary in definition.bodies:
		if bool(body.passive_subject): subject = str(body.id)
	definition["project"] = {"schema_version": 1, "kind": str(entry.kind), "seed": 0,
		"startup": "run_autoplay", "camera": {"origin": [0.0, 0.0], "size": [480.0, 270.0], "zoom": 1.0},
		"events": [], "expectations": entry.expectations.duplicate(), "passive_subject_id": subject}
	definition["presentation"] = Presentation.defaults()
	definition.presentation.annotations.append({"id": "gallery-title", "type": "label", "points": [[24.0, 24.0]],
		"color": "#b4d2e6ff", "width": 1.0, "text": str(entry.title)})
	definition["notes"] = str(entry.description) + "\n\nDeclared observation criteria; consult run evidence for actual measured results.\n"
