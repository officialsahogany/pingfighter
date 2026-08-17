extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")


func play_active_unlock_flight_from_runtime_state(runtime_state: Object, registry: Object) -> bool:
	return play_active_unlock_flight(registry, RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_get_instance"))


func play_active_unlock_flight(registry: Object, get_instance: Callable) -> bool:
	var game_audio: Object = _get_game_audio(registry, get_instance)
	if game_audio == null:
		return false
	if game_audio.has_method("play_item_get"):
		game_audio.play_item_get()
		return true
	if game_audio.has_method("play_runtime_perk_choice_open"):
		game_audio.play_runtime_perk_choice_open()
		return true
	return false


func play_perk_select_from_runtime_state(runtime_state: Object, registry: Object) -> bool:
	return play_perk_select(registry, RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_get_instance"))


func play_perk_select(registry: Object, get_instance: Callable) -> bool:
	var game_audio: Object = _get_game_audio(registry, get_instance)
	if game_audio == null or not game_audio.has_method("play_runtime_perk_select"):
		return false
	game_audio.play_runtime_perk_select()
	return true


func _get_game_audio(registry: Object, get_instance: Callable) -> Object:
	if get_instance.is_valid():
		var value: Variant = get_instance.call(registry, "game_audio")
		if value is Object:
			return value
	if registry != null and registry.has_method("get_instance"):
		var registry_value: Variant = registry.get_instance("game_audio")
		if registry_value is Object:
			return registry_value
	return null


func _missing_instance(_registry: Object, _key: String) -> Object:
	return null
