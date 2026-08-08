extends RefCounted

const HOST_KEY := "lingpet_guardian_enhance_cutin_overlay_host"


func resolve(registry: Object) -> Object:
	if registry == null:
		return null
	var host: Variant = null
	if registry.has_method("get_cached_instance"):
		host = registry.get_cached_instance(HOST_KEY)
	if (typeof(host) != TYPE_OBJECT or host == null) and registry.has_method("get_instance"):
		host = registry.get_instance(HOST_KEY)
	if typeof(host) == TYPE_OBJECT and host != null and is_instance_valid(host):
		return host as Object
	return null


func is_anim_ready(registry: Object, pet_id: String) -> bool:
	var host := resolve(registry)
	if host == null:
		return true
	if host.has_method("is_pet_panel_anim_ready"):
		return bool(host.is_pet_panel_anim_ready(pet_id))
	if not host.has_method("is_pet_cutin_anim_ready"):
		return true
	return bool(host.is_pet_cutin_anim_ready(pet_id))


func get_animation_contract(registry: Object, pet_id: String) -> Dictionary:
	var host := resolve(registry)
	if host == null or not host.has_method("get_animation_contract"):
		return {}
	var value: Variant = host.get_animation_contract(pet_id)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func prewarm_result_icon(registry: Object, result: Dictionary) -> bool:
	var host := resolve(registry)
	if host == null:
		return true
	var detail: Dictionary = result.get("result_detail", {}) as Dictionary
	var icon_path := str(detail.get("icon_texture_path", "")).strip_edges()
	if icon_path == "":
		return true
	if not host.has_method("prewarm_result_icon_path"):
		return false
	return bool(host.prewarm_result_icon_path(icon_path))


func has_cached_result_icon(registry: Object, icon_path: String) -> bool:
	var normalized := icon_path.strip_edges()
	if normalized == "":
		return false
	var host := resolve(registry)
	return (
		host != null
		and host.has_method("has_cached_result_icon")
		and bool(host.has_cached_result_icon(normalized))
	)
