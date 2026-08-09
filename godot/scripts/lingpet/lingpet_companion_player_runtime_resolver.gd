extends RefCounted

const SMASHER_OVERDRIVE_KEY := "smasher_overdrive_state"
const SMASHER_DASH_KEY := "smasher_dash_state"
const VIPER_RUNTIME_KEY := "viper_skill_runtime"


func is_right_click_claimed_by_player_skill(
	owner: Object,
	registry: Object
) -> bool:
	var overdrive_state := _get_cached_instance(registry, SMASHER_OVERDRIVE_KEY)
	if overdrive_state != null:
		if overdrive_state.has_method("is_active") and bool(overdrive_state.is_active()):
			return true
		if overdrive_state.has_method("is_armed") and bool(overdrive_state.is_armed()):
			return true
	var viper_runtime := _get_cached_instance(registry, VIPER_RUNTIME_KEY)
	return (
		viper_runtime != null
		and viper_runtime.has_method("is_command_armable")
		and bool(viper_runtime.is_command_armable(owner, registry))
	)


func resolve_player_dash_state(registry: Object) -> Dictionary:
	var dash_state := _get_cached_instance(registry, SMASHER_DASH_KEY)
	if dash_state == null:
		return {}
	if not dash_state.has_method("is_active") or not bool(dash_state.is_active()):
		return {}
	if not dash_state.has_method("get_snapshot"):
		return {}
	var snapshot: Variant = dash_state.get_snapshot()
	return snapshot if snapshot is Dictionary else {}


func is_player_guard_available(registry: Object) -> bool:
	var viper_runtime := _get_cached_instance(registry, VIPER_RUNTIME_KEY)
	return (
		viper_runtime == null
		or not viper_runtime.has_method("is_player_guard_available")
		or bool(viper_runtime.is_player_guard_available())
	)


func _get_cached_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_cached_instance"):
		return null
	var cached: Variant = registry.get_cached_instance(key)
	if typeof(cached) == TYPE_OBJECT and cached != null and is_instance_valid(cached):
		return cached as Object
	return null
