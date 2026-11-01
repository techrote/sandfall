class_name SandfallSceneDefinitions
extends RefCounted

# Initial values only. No node, RID, live solver, or input owner is retained here.
# The retained three-body fixture now uses the same stable logical identities
# and versioned defaults as objects authored through the SF-M3 workshop.
const Registry = preload("res://scripts/sandfall/rapier_object_registry.gd")
const WORLD_SIZE: Vector2i = Vector2i(1024, 1024)
const INITIAL_VIEW: Vector2i = Vector2i(480, 270)
const IDS: Array[String] = ["blank", "material_lab", "physics_pit"]


static func ids() -> Array[String]:
	return IDS.duplicate()


static func get_definition(id: String) -> Dictionary:
	if id not in IDS:
		return {}
	# The retained constructor requires at least one rectangle. An explicit
	# Empty carve describes a genuinely blank world without a synthetic tick.
	var rectangles: PackedInt32Array = PackedInt32Array([0, 0, 1024, 1024, 0])
	var bodies: Array[Dictionary] = []
	var title: String = "Blank Sandbox"
	if id != "blank":
		rectangles = CyberDemoWorlds.rectangles(id).duplicate()
		title = "Material Lab" if id == "material_lab" else "Physics Pit"
	if id == "physics_pit":
		for x: int in [124, 244, 384]:
			var order: int = bodies.size() + 1
			bodies.append(Registry.make_box("physics-pit-%d" % order, order, Vector2(x, 90), Vector2(8, 14)))
	return {
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
