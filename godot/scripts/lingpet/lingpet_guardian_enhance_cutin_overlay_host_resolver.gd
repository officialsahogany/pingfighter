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
	if host == null or not host.has_method("is_pet_cutin_anim_ready"):
		return true
	return bool(host.is_pet_cutin_anim_ready(pet_id))
