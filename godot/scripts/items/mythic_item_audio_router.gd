extends RefCounted


func apply_ragnarok_feedback(runtime: Object, deps: Dictionary, amount: float, intensity: float) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback == null:
		feedback = runtime._get_instance(deps.get("registry", null), "battle_feedback_state")
	if feedback == null:
		return
	if feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(amount, intensity)
	elif feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(amount, intensity)


func apply_poseidon_feedback(runtime: Object, deps: Dictionary, amount: float, intensity: float) -> void:
	apply_ragnarok_feedback(runtime, deps, amount, intensity)


func play_ragnarok_shot_audio(runtime: Object, registry: Object) -> void:
	var audio: Object = get_ragnarok_audio(runtime, registry)
	if audio == null:
		return
	if audio.has_method("play_ragnarok_shot"):
		audio.play_ragnarok_shot()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func play_ragnarok_boom_audio(runtime: Object, registry: Object) -> void:
	var audio: Object = get_ragnarok_audio(runtime, registry)
	if audio == null:
		return
	if audio.has_method("play_ragnarok_boom"):
		audio.play_ragnarok_boom()
	elif audio.has_method("play_grenade_explosion"):
		audio.play_grenade_explosion()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func play_ragnarok_shock_audio(runtime: Object, registry: Object) -> void:
	if runtime.ragnarok_shock_loop_active:
		return
	var audio: Object = get_ragnarok_audio(runtime, registry)
	if audio == null:
		return
	if audio.has_method("play_electric_shock_loop"):
		audio.play_electric_shock_loop()
		runtime.ragnarok_shock_loop_active = true
	elif audio.has_method("play_ragnarok_shock_loop"):
		audio.play_ragnarok_shock_loop()
		runtime.ragnarok_shock_loop_active = true


func stop_ragnarok_shock_audio(runtime: Object, registry: Object) -> void:
	var audio: Object = get_ragnarok_audio(runtime, registry)
	if audio != null:
		if audio.has_method("stop_electric_shock_loop"):
			audio.stop_electric_shock_loop()
		if audio.has_method("stop_ragnarok_shock_loop"):
			audio.stop_ragnarok_shock_loop()
	runtime.ragnarok_shock_loop_active = false


func get_ragnarok_audio(runtime: Object, registry: Object) -> Object:
	var audio: Object = runtime._get_instance(registry, "game_audio")
	if audio != null:
		runtime.ragnarok_audio = audio
		return audio
	if runtime.ragnarok_audio != null and is_instance_valid(runtime.ragnarok_audio):
		return runtime.ragnarok_audio
	return null


func play_poseidon_wave_audio(runtime: Object, registry: Object) -> void:
	var audio: Object = get_poseidon_audio(runtime, registry)
	if audio == null:
		return
	if audio.has_method("play_poseidon_wave"):
		audio.play_poseidon_wave()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func play_poseidon_charge_audio(runtime: Object, registry: Object) -> void:
	var audio: Object = get_poseidon_audio(runtime, registry)
	if audio == null:
		return
	if audio.has_method("play_poseidon_charge"):
		audio.play_poseidon_charge()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func play_knee_pads_audio(runtime: Object, registry: Object) -> void:
	var audio: Object = runtime._get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_active_item"):
		audio.play_active_item()
	elif audio.has_method("play_item_get"):
		audio.play_item_get()


func play_soul_burst_audio(runtime: Object, registry: Object) -> void:
	var audio: Object = runtime._get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_soul_burst_dash"):
		audio.play_soul_burst_dash()
	elif audio.has_method("play_dash_start"):
		audio.play_dash_start(false)
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func play_celestial_armor_audio(runtime: Object, registry: Object) -> void:
	var audio: Object = runtime._get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_shield_kiting_hit"):
		audio.play_shield_kiting_hit()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()
	elif audio.has_method("play_item_get"):
		audio.play_item_get()


func play_yangui_hoechun_cast_audio(runtime: Object, registry: Object) -> void:
	_play_first_available(
		runtime._get_instance(registry, "game_audio"),
		["play_solar_bolt_strike", "play_megingjord", "play_active_item"]
	)


func play_yangui_hoechun_reflect_audio(
	runtime: Object,
	registry: Object,
	impact_speed: float
) -> void:
	var audio: Object = runtime._get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_stage7_akamu_wind_aura_block"):
		audio.play_stage7_akamu_wind_aura_block()
	elif audio.has_method("play_wall_hit"):
		audio.play_wall_hit(impact_speed)
	elif audio.has_method("play_shield_kiting_hit"):
		audio.play_shield_kiting_hit()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func play_baal_boots_absorb_audio(runtime: Object, registry: Object) -> void:
	var audio: Object = runtime._get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_weather_absorb"):
		audio.play_weather_absorb()
	elif audio.has_method("play_soul_burst_dash"):
		audio.play_soul_burst_dash()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()
	elif audio.has_method("play_item_get"):
		audio.play_item_get()


func play_baal_boots_pulse_audio(runtime: Object, registry: Object) -> void:
	var audio: Object = runtime._get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_shield_kiting_hit"):
		audio.play_shield_kiting_hit()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func play_foul_whistle_audio(runtime: Object, source: Variant) -> void:
	var audio: Object = null
	if source is Dictionary:
		audio = source.get("audio", source.get("game_audio", null))
	elif source != null and source is Object:
		var source_object: Object = source
		if source_object.has_method("play_foul_whistle") or source_object.has_method("play_active_item"):
			audio = source_object
		else:
			audio = runtime._get_instance(source_object, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_foul_whistle"):
		audio.play_foul_whistle()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func get_poseidon_audio(runtime: Object, registry: Object) -> Object:
	var audio: Object = runtime._get_instance(registry, "game_audio")
	if audio != null:
		runtime.poseidon_audio = audio
		return audio
	if runtime.poseidon_audio != null and is_instance_valid(runtime.poseidon_audio):
		return runtime.poseidon_audio
	return null


func play_pickup_audio(runtime: Object, registry: Object) -> void:
	var audio: Object = runtime._get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_item_get"):
		audio.play_item_get()


func play_equipment_audio(runtime: Object, registry: Object) -> void:
	var audio: Object = runtime._get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_item_get"):
		audio.play_item_get()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func play_activation_audio(runtime: Object, registry: Object) -> void:
	var audio: Object = runtime._get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_megingjord"):
		audio.play_megingjord()
	elif audio.has_method("play_pandora"):
		audio.play_pandora()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func play_venom_mist_poison_audio(runtime: Object, registry: Object) -> void:
	var audio: Object = runtime._get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_active_item"):
		audio.play_active_item()


func play_venom_mist_spawn_audio(runtime: Object, registry: Object) -> void:
	var audio: Object = runtime._get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_active_item"):
		audio.play_active_item()


func play_rainbow_fur_glove_audio(runtime: Object, registry: Object) -> void:
	var audio: Object = runtime._get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_rainbow_fur_glove"):
		audio.play_rainbow_fur_glove()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func play_adversity_armor_activate_audio(runtime: Object, registry: Object) -> void:
	var audio: Object = runtime._get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_shield_kiting_hit"):
		audio.play_shield_kiting_hit()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()
	elif audio.has_method("play_item_get"):
		audio.play_item_get()


func play_adversity_armor_reflect_audio(runtime: Object, registry: Object, impact_speed: float) -> void:
	var audio: Object = runtime._get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_wall_hit"):
		audio.play_wall_hit(impact_speed)
	elif audio.has_method("play_shield_kiting_hit"):
		audio.play_shield_kiting_hit()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func play_shrapnel_armor_fire_audio(runtime: Object, registry: Object) -> void:
	var audio: Object = runtime._get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_shrapnel_armor_fire"):
		audio.play_shrapnel_armor_fire()
	elif audio.has_method("play_throw"):
		audio.play_throw()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func play_shrapnel_armor_hit_audio(runtime: Object, registry: Object) -> void:
	var audio: Object = runtime._get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_shrapnel_armor_hit"):
		audio.play_shrapnel_armor_hit()
	elif audio.has_method("play_boomerang_hit"):
		audio.play_boomerang_hit()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func play_horn_strawberry_change_audio(runtime: Object, registry: Object) -> void:
	_play_first_available(
		runtime._get_instance(registry, "game_audio"),
		["play_horn_strawberry_change", "play_megingjord", "play_active_item"]
	)


func play_horn_strawberry_eat_audio(runtime: Object, registry: Object) -> void:
	_play_first_available(
		runtime._get_instance(registry, "game_audio"),
		["play_horn_strawberry_eat", "play_drink", "play_active_item"]
	)


func stop_horn_strawberry_eat_audio(runtime: Object, registry: Object) -> void:
	var audio: Object = runtime._get_instance(registry, "game_audio")
	if audio != null and audio.has_method("stop_horn_strawberry_eat"):
		audio.stop_horn_strawberry_eat()


func play_horn_strawberry_stem_fire_audio(runtime: Object, registry: Object) -> void:
	_play_first_available(
		runtime._get_instance(registry, "game_audio"),
		["play_horn_strawberry_stem_fire", "play_shrapnel_armor_fire", "play_throw", "play_active_item"]
	)


func play_horn_strawberry_stem_hit_audio(runtime: Object, registry: Object) -> void:
	_play_first_available(
		runtime._get_instance(registry, "game_audio"),
		["play_horn_strawberry_stem_hit", "play_shrapnel_armor_hit", "play_boomerang_hit", "play_active_item"]
	)


func play_horn_strawberry_field_audio(runtime: Object, registry: Object) -> void:
	_play_first_available(
		runtime._get_instance(registry, "game_audio"),
		["play_horn_strawberry_field", "play_active_item"]
	)


func play_horn_strawberry_field_break_audio(runtime: Object, registry: Object) -> void:
	_play_first_available(
		runtime._get_instance(registry, "game_audio"),
		["play_horn_strawberry_field_break", "play_active_item"]
	)


func play_horn_strawberry_field_build_break_audio(runtime: Object, registry: Object) -> void:
	_play_first_available(
		runtime._get_instance(registry, "game_audio"),
		["play_horn_strawberry_field_build_break", "play_active_item"]
	)


func play_horn_strawberry_horn_charge_audio(runtime: Object, registry: Object) -> void:
	_play_first_available(
		runtime._get_instance(registry, "game_audio"),
		["play_horn_strawberry_horn_charge", "play_active_item"]
	)


func play_horn_strawberry_horn_impact_audio(runtime: Object, registry: Object) -> void:
	_play_first_available(
		runtime._get_instance(registry, "game_audio"),
		["play_horn_strawberry_horn_impact"]
	)


func play_horn_strawberry_bomb_throw_audio(runtime: Object, registry: Object) -> void:
	_play_first_available(
		runtime._get_instance(registry, "game_audio"),
		["play_horn_strawberry_bomb_throw", "play_horn_strawberry_stem_hit", "play_shrapnel_armor_hit", "play_active_item"]
	)


func play_horn_strawberry_bomb_explosion_audio(runtime: Object, registry: Object) -> void:
	_play_first_available(
		runtime._get_instance(registry, "game_audio"),
		["play_horn_strawberry_bomb_explosion"]
	)


func play_named(runtime: Object, registry: Object, method_name: String) -> bool:
	var audio_method := method_name
	if audio_method.begins_with("_"):
		audio_method = audio_method.substr(1)
	if not has_method(audio_method):
		return false
	call(audio_method, runtime, registry)
	return true


func _play_first_available(audio: Object, method_names: Array) -> bool:
	if audio == null:
		return false
	for method_name_value in method_names:
		var method_name := str(method_name_value)
		if audio.has_method(method_name):
			audio.call(method_name)
			return true
	return false
