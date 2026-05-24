extends RefCounted

const CommandoFirearmAudioResolver := preload("res://scripts/characters/commando_firearm_audio_resolver.gd")


static func play_fire_audio(weapon_id: String, deps: Dictionary) -> void:
	if weapon_id == "fire_support":
		return
	play_weapon_audio_method(
		deps,
		CommandoFirearmAudioResolver.get_fire_audio_methods(weapon_id),
		"play_commando_firearm_fire",
		weapon_id
	)


static func play_impact_audio(weapon_id: String, deps: Dictionary) -> void:
	play_weapon_audio_method(
		deps,
		CommandoFirearmAudioResolver.get_impact_audio_methods(weapon_id),
		"play_commando_firearm_impact",
		weapon_id
	)


static func play_weapon_audio_method(
	deps: Dictionary,
	method_names: Array[String],
	fallback_method: String,
	weapon_id: String
) -> void:
	var audio: Object = get_audio(deps)
	if audio == null:
		return
	for method_name in method_names:
		if audio.has_method(method_name):
			audio.call(method_name)
			return
	if audio.has_method(fallback_method):
		audio.call(fallback_method, weapon_id)


static func play_first_audio_method(deps: Dictionary, method_names: Array[String]) -> void:
	var audio: Object = get_audio(deps)
	if audio == null:
		return
	for method_name in method_names:
		if audio.has_method(method_name):
			audio.call(method_name)
			return


static func play_reload_progress_audio(timer_result: Dictionary, deps: Dictionary) -> void:
	var base_result: Dictionary = _get_dict(timer_result.get("base_pistol", {}))
	var pistol_result: Dictionary = _get_dict(timer_result.get("commando_pistol", {}))
	var rounds_added: int = int(base_result.get("reload_rounds_added", 0)) + int(pistol_result.get("reload_rounds_added", 0))
	for _i in range(max(0, rounds_added)):
		play_first_audio_method(deps, ["play_commando_pistol_reload_round", "play_commando_pistol_reload_start"])


static func stop_suicide_drone_audio(deps: Dictionary) -> void:
	play_first_audio_method(deps, ["stop_commando_suicide_drone_loop"])


@warning_ignore("shadowed_variable_base_class")
static func start_support_aircraft_audio(call: Dictionary, deps: Dictionary) -> void:
	if bool(call.get("aircraft_audio_active", false)):
		return
	call["aircraft_audio_active"] = true
	play_first_audio_method(deps, ["play_commando_fire_support_aircraft_loop", "play_commando_supply_aircraft_loop"])


@warning_ignore("shadowed_variable_base_class")
static func stop_support_aircraft_audio(call: Dictionary, deps: Dictionary) -> void:
	if not bool(call.get("aircraft_audio_active", false)):
		return
	call["aircraft_audio_active"] = false
	play_first_audio_method(deps, ["stop_commando_fire_support_aircraft_loop", "stop_commando_supply_aircraft_loop"])


static func stop_all_support_aircraft_audio(support_calls: Array, deps: Dictionary) -> void:
	for index in range(support_calls.size()):
		@warning_ignore("shadowed_variable_base_class")
		var call: Dictionary = _get_dict(support_calls[index])
		stop_support_aircraft_audio(call, deps)
		support_calls[index] = call


static func get_audio(deps: Dictionary) -> Object:
	var value: Variant = deps.get("audio", deps.get("game_audio", null))
	return value if value is Object else null


static func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
