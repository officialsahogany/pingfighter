extends RefCounted


static func collect_starpoint_reward(
	context: Dictionary,
	deps: Dictionary,
	use_deps_registry_fallback: bool = true
) -> bool:
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	if runtime_perk_state == null or not runtime_perk_state.has_method("collect_star_points"):
		return false
	var runtime_perk_catalog: Object = deps.get("runtime_perk_catalog", null)
	var owner: Object = context.get("owner", null)
	var registry: Object = context.get("registry", null)
	if registry == null and use_deps_registry_fallback:
		registry = deps.get("registry", null)
	var character_type: String = str(context.get("selected_character_type", "smasher"))
	return bool(runtime_perk_state.collect_star_points(1, character_type, runtime_perk_catalog, owner, registry))


static func request_owner_redraw(context: Dictionary) -> void:
	var owner: Object = context.get("owner", null)
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()
