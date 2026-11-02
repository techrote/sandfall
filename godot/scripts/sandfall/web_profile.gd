class_name SandfallWebProfile
extends RefCounted

# Host setup only. Worker threads remain native-only; Rapier stays on Godot main.
# The browser bootstrap validates resources before executing Godot. A threaded
# binary or a configured pool is not proof that multiple workers executed tasks.
static func apply_policy() -> Dictionary:
	if not OS.has_feature("web"):
		return {"ok": true, "profile": "native", "requested_workers": int(ProjectSettings.get_setting("cybersand/native_worker_threads", 0))}
	var parsed: Variant = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(globalThis.sandfallWebStartup || null)", true)))
	if not parsed is Dictionary or parsed.get("status") != "assets-and-host-verified":
		return {"ok": false, "error": "Web runtime identity/hosting preflight is absent"}
	var profile: String = str(parsed.get("profile", ""))
	if (profile == "threaded") != OS.has_feature("threads"):
		return {"ok": false, "error": "Web export profile disagrees with the running Godot thread capability"}
	var workers: int = int(parsed.get("resolved_workers", 0))
	if workers not in [1, 2, 4, 6] or (profile == "compat" and workers != 1):
		return {"ok": false, "error": "Unsupported native worker policy"}
	ProjectSettings.set_setting("cybersand/native_worker_threads", workers)
	return {"ok": true, "profile": profile, "requested_workers": parsed.requested_workers,
		"resolved_workers": workers, "capabilities": parsed.capabilities.duplicate(true)}


static func observe(policy: Dictionary, world: Variant, observed_peak: int) -> Dictionary:
	var result: Dictionary = policy.duplicate(true)
	result["configured_workers"] = int(world.get_worker_threads()) if world != null else 0
	result["observed_workers_peak"] = observed_peak
	result["ownership"] = "synchronous-godot-main; native-only-worker-pool; main-thread-rapier"
	return result
