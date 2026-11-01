class_name SandfallGallery
extends RefCounted

# Curated initial scenes and declared observation criteria. These descriptions
# are not qualification receipts: runtime evidence reports what actually ran.
const ENTRIES: Array[Dictionary] = [
	{"id": "gravity_cascade", "title": "Gravity Cascade", "reference": "ZP-P01", "kind": "kinetic_sandbox", "tags": ["gravity", "sand", "water", "boxes", "simple"], "description": "Sand falls through ledges while three independent boxes drop into a water basin.", "expectations": ["Native material moves without actor input", "Three bodies fall through solver integration", "Hard terrain contains the basin"]},
	{"id": "fluid_messenger", "title": "Fluid Messenger", "reference": "ZP-P06", "kind": "zero_input", "tags": ["water", "feedback", "subject", "simple"], "description": "An uncontrolled messenger starts in water. Observe native fluid feedback moving its Rapier body.", "expectations": ["Messenger receives nonzero native feedback impulses", "Messenger position changes through physical integration", "No scripted transform changes or actor input"]},
	{"id": "passive_subject_ride", "title": "Passive Subject Ride", "reference": "SF-SUBJECT", "kind": "zero_input", "tags": ["subject", "water", "boxes", "medium"], "description": "Follow the gold-ringed subject as falling bodies enter a water-filled channel. It has no motor.", "expectations": ["Subject is one of three bounded physical bodies", "Native material feedback reaches the passive subject", "Reset restores the subject's initial definition"]},
	{"id": "endless_kinetic_loop", "title": "Endless Kinetic Loop", "reference": "ZP-P10", "kind": "kinetic_sandbox", "tags": ["rotation", "loop", "idealized", "simple"], "description": "Three separated boxes retain initial angular motion with zero gravity and damping. An idealized inertial loop, with no motor or pose animation.", "expectations": ["Angular motion continues from initial velocity", "Body count and positions remain bounded", "No new resources or environmental commands are created"]},
	{"id": "intervention", "title": "Intervention Workshop", "reference": "ZP-FX-06", "kind": "kinetic_sandbox", "tags": ["editing", "modified", "reset", "medium"], "description": "Paint a wall or add a body during the run. Modified is sticky; Reset reconstructs the authored initial scene.", "expectations": ["Accepted physical intervention marks Modified", "Rejected changes preserve the current graph", "Reset restores the frozen initial scene"]},
	{"id": "time_controls", "title": "Time Controls", "reference": "ZP-FX-07", "kind": "kinetic_sandbox", "tags": ["pause", "step", "speed", "simple"], "description": "Pause, advance one fixed tick, or select a pacing preset while the same physical scene evolves.", "expectations": ["Pause performs zero solver steps", "Step advances exactly one fixed coupled tick", "Pacing presets retain 1/60-second physics"]},
	{"id": "sixteen_body", "title": "Sandfall 16-Body", "reference": "SF-16", "kind": "kinetic_sandbox", "tags": ["water", "capacity", "contacts", "complex"], "description": "Sixteen independent boxes fall into a bounded water basin, exchanging body and material contacts.", "expectations": ["All sixteen stable IDs sample and render", "Bodies contact each other and native materials", "A seventeenth body refuses without changing the graph"]},
]


static func entries(query: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var terms: PackedStringArray = query.strip_edges().to_lower().split(" ", false)
	for entry: Dictionary in ENTRIES:
		var haystack: String = (str(entry.title) + " " + str(entry.reference) + " " + str(entry.kind) + " " + " ".join(entry.tags) + " " + str(entry.description)).to_lower()
		var matches: bool = true
		for term: String in terms:
			if not haystack.contains(term):
				matches = false
				break
		if matches:
			result.append(entry.duplicate(true))
	return result


static func entry(id: String) -> Dictionary:
	for value: Dictionary in ENTRIES:
		if value.id == id:
			return value.duplicate(true)
	return {}


static func ids() -> Array[String]:
	var result: Array[String] = []
	for value: Dictionary in ENTRIES:
		result.append(str(value.id))
	return result
