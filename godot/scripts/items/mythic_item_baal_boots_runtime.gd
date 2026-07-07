extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ITEM_BAAL_BOOTS := "baal_boots"


func is_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_BAAL_BOOTS)


func is_active(runtime: Object) -> bool:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_level(runtime) > 0
	return is_equipped(runtime)


func get_gauge_recovery(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_mythic_value(runtime, "gauge_recovery")
	if not is_equipped(runtime):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_value(runtime, ITEM_BAAL_BOOTS, "gauge_recovery"), 0.0, 2000.0)


func apply_player_hit(
	runtime: Object,
	ball_pos: Vector2,
	ball_vel: Vector2,
	context: Dictionary,
	deps: Dictionary,
	constants: Dictionary
) -> Dictionary:
	var round_weather_type: String = runtime.baal_boots_weather_state.round_weather_type
	if not runtime.baal_boots_weather_state.round_effect_active or round_weather_type == "":
		return {}
	match round_weather_type:
		"fire", "ice":
			runtime.baal_boots_combat_state.mark_ball(
				round_weather_type,
				float(constants.get("ball_mark_frames", 240.0))
			)
			spawn_aura_particles(runtime, ball_pos, round_weather_type, 8, constants)
			runtime.audio_router.play_baal_boots_pulse_audio(runtime, runtime._get_dict(deps).get("registry", null))
			return {
				"activated": true,
				"ball_vel": ball_vel,
				"baal_boots_ball_mark_type": runtime.baal_boots_combat_state.ball_mark_type,
			}
		"rain", "hail":
			spawn_projectiles(runtime, ball_pos, round_weather_type, context, constants)
			runtime.audio_router.play_baal_boots_pulse_audio(runtime, runtime._get_dict(deps).get("registry", null))
			return {
				"activated": true,
				"ball_vel": ball_vel,
			}
	return {}


func apply_boss_hit(
	runtime: Object,
	ball_vel: Vector2,
	context: Dictionary,
	deps: Dictionary,
	constants: Dictionary
) -> Dictionary:
	if (
		runtime.baal_boots_combat_state.ball_mark_timer_frames <= 0.0
		or runtime.baal_boots_combat_state.ball_mark_type == ""
	):
		return {}
	var mark_type: String = runtime.baal_boots_combat_state.consume_ball_mark()
	var boss_center: Vector2 = resolve_boss_center_from_context(runtime, context)
	var result := {
		"applied": true,
		"ball_vel": ball_vel,
	}
	match mark_type:
		"fire":
			var direction: float = 1.0 if boss_center.x < float(constants.get("field_width", 760.0)) * 0.5 else -1.0
			result["boss_vel"] = runtime.baal_boots_combat_state.apply_knockback(
				direction,
				float(constants.get("knockback_power", 17.0)),
				float(constants.get("knockback_frames", 34.0))
			)
			result["ball_vel"] = ball_vel * 0.94
		"ice":
			runtime.baal_boots_combat_state.apply_slow(float(constants.get("rain_slow_frames", 180.0)))
			result["boss_slow"] = true
	spawn_aura_particles(runtime, boss_center, mark_type, 14, constants)
	runtime.audio_router.apply_ragnarok_feedback(runtime, deps, 0.09, 3.4)
	runtime.audio_router.play_baal_boots_pulse_audio(runtime, runtime._get_dict(deps).get("registry", null))
	return result


func clear_runtime(runtime: Object, registry: Object, constants: Dictionary) -> void:
	clear_round_state(runtime, registry, constants)


func clear_round_state(runtime: Object, registry: Object, _constants: Dictionary) -> void:
	var had_sand_round: bool = runtime.baal_boots_weather_state.clear_round_state()
	runtime.baal_boots_effect_state.clear()
	runtime.baal_boots_combat_state.clear()
	if had_sand_round:
		var weather: Object = runtime._get_instance(registry, "weather_event_state")
		if weather != null and weather.has_method("dissolve_sand_terrain"):
			weather.dissolve_sand_terrain()


func update_runtime(
	runtime: Object,
	owner: Object,
	registry: Object,
	fps_scale: float,
	constants: Dictionary
) -> void:
	if not is_active(runtime):
		if runtime.baal_boots_weather_state.has_round_activity():
			clear_round_state(runtime, registry, constants)
		return

	var step: float = max(0.0, fps_scale)
	if runtime.baal_boots_weather_state.has_round_activity():
		runtime.baal_boots_weather_state.set_absorb_center(runtime.owner_syncer.read_owner_player_center(runtime, owner))

	if runtime.baal_boots_weather_state.pending_weather_type != "":
		var pending_weather_type: String = runtime.baal_boots_weather_state.pending_weather_type
		spawn_aura_particles(runtime, runtime.baal_boots_weather_state.absorb_center, pending_weather_type, 1, constants)
		if runtime.baal_boots_weather_state.tick_trigger(step):
			begin_absorb(runtime, owner, registry, pending_weather_type, constants)

	if runtime.baal_boots_weather_state.tick_cinematic(step):
		finish_absorb(runtime, owner, registry, constants)

	update_absorb_particles(runtime, step)
	update_aura_particles(runtime, step)
	update_projectiles(runtime, owner, registry, step, constants)
	runtime.baal_boots_combat_state.update(step, float(constants.get("knockback_decay", 0.88)))


func try_arm_from_weather(
	runtime: Object,
	owner: Object,
	registry: Object,
	weather_type_override: String,
	constants: Dictionary
) -> void:
	if (
		not is_active(runtime)
		or runtime.baal_boots_weather_state.activated_this_round
		or runtime.baal_boots_weather_state.cinematic_active
	):
		return
	var weather: Object = runtime._get_instance(registry, "weather_event_state")
	if weather == null:
		return
	var weather_active := true
	if weather.has_method("is_weather_active"):
		weather_active = bool(weather.is_weather_active())
	var weather_type := weather_type_override.strip_edges()
	if weather_type == "" and weather.has_method("get_weather_type"):
		weather_type = str(weather.get_weather_type())
	if not weather_active or weather_type == "":
		return
	runtime.baal_boots_weather_state.arm(
		weather_type,
		runtime.owner_syncer.read_owner_player_center(runtime, owner),
		float(constants.get("trigger_delay_frames", 150.0))
	)
	spawn_aura_particles(runtime, runtime.baal_boots_weather_state.absorb_center, weather_type, 12, constants)


func begin_absorb(
	runtime: Object,
	owner: Object,
	registry: Object,
	weather_type: String,
	constants: Dictionary
) -> void:
	var weather: Object = runtime._get_instance(registry, "weather_event_state")
	if weather == null:
		runtime.baal_boots_weather_state.cancel_pending_activation()
		return
	var active_weather_type := weather_type
	if active_weather_type == "" and weather.has_method("get_weather_type"):
		active_weather_type = str(weather.get_weather_type())
	if active_weather_type == "" or (weather.has_method("is_weather_active") and not bool(weather.is_weather_active())):
		runtime.baal_boots_weather_state.cancel_pending_activation()
		return

	var absorb_center: Vector2 = runtime.owner_syncer.read_owner_player_center(runtime, owner)
	runtime.baal_boots_weather_state.set_absorb_center(absorb_center)
	var harvested: Array = []
	if weather.has_method("harvest_particles"):
		harvested = weather.harvest_particles(active_weather_type)
	var sand_absorbed_total := 0.0
	if active_weather_type == "sand" and weather.has_method("get_sand_total_depth"):
		sand_absorbed_total = float(weather.get_sand_total_depth())
	build_absorb_particles(runtime, harvested, active_weather_type, constants)
	runtime.baal_boots_weather_state.start_absorb_cinematic(
		active_weather_type,
		absorb_center,
		sand_absorbed_total,
		float(constants.get("telegraph_frames", 48.0)) + float(constants.get("absorb_frames", 150.0))
	)

	if weather.has_method("force_end_weather_event"):
		weather.force_end_weather_event(owner, registry)
	if weather.has_method("clear_visual_particles"):
		weather.clear_visual_particles()
	if active_weather_type == "sand" and weather.has_method("dissolve_sand_terrain"):
		weather.dissolve_sand_terrain()
	runtime.audio_router.apply_ragnarok_feedback(runtime, {"registry": registry}, 0.14, 5.0)
	runtime.audio_router.play_baal_boots_absorb_audio(runtime, registry)


func finish_absorb(runtime: Object, owner: Object, registry: Object, constants: Dictionary) -> void:
	if not runtime.baal_boots_weather_state.finish_absorb():
		return
	if not runtime.baal_boots_weather_state.gauge_given:
		give_gauge(runtime, owner, registry, constants)
	if runtime.baal_boots_weather_state.round_weather_type == "sand":
		var weather: Object = runtime._get_instance(registry, "weather_event_state")
		if weather != null and weather.has_method("rebuild_sand_behind_player"):
			weather.rebuild_sand_behind_player(runtime.owner_syncer.read_owner_player_center(runtime, owner))
	spawn_aura_particles(
		runtime,
		runtime.owner_syncer.read_owner_player_center(runtime, owner),
		runtime.baal_boots_weather_state.round_weather_type,
		20,
		constants
	)


func build_absorb_particles(runtime: Object, harvested: Array, weather_type: String, constants: Dictionary) -> void:
	runtime.baal_boots_effect_state.build_absorb_particles(
		harvested,
		weather_type,
		get_weather_color(weather_type),
		int(constants.get("absorb_particle_fallback_count", 42)),
		Vector2(float(constants.get("field_width", 760.0)), float(constants.get("field_height", 750.0))),
		float(constants.get("absorb_frames", 150.0))
	)


func update_absorb_particles(runtime: Object, fps_scale: float) -> void:
	runtime.baal_boots_effect_state.update_absorb_particles(
		fps_scale,
		runtime.baal_boots_weather_state.absorb_center,
		runtime.baal_boots_weather_state.cinematic_active
	)


func spawn_aura_particles(
	runtime: Object,
	center: Vector2,
	weather_type: String,
	count: int,
	constants: Dictionary
) -> void:
	runtime.baal_boots_effect_state.spawn_aura_particles(
		center,
		weather_type,
		count,
		get_weather_color(weather_type),
		int(constants.get("aura_particle_max", 42))
	)


func update_aura_particles(runtime: Object, fps_scale: float) -> void:
	runtime.baal_boots_effect_state.update_aura_particles(fps_scale)


func spawn_projectiles(
	runtime: Object,
	ball_pos: Vector2,
	weather_type: String,
	context: Dictionary,
	constants: Dictionary
) -> void:
	var boss_center: Vector2 = resolve_boss_center_from_context(runtime, context)
	runtime.baal_boots_effect_state.spawn_projectiles(
		ball_pos,
		boss_center,
		weather_type,
		get_weather_color(weather_type),
		float(constants.get("projectile_speed", 8.5)),
		float(constants.get("projectile_life_frames", 150.0))
	)


func update_projectiles(
	runtime: Object,
	owner: Object,
	registry: Object,
	fps_scale: float,
	constants: Dictionary
) -> void:
	var boss_rect: Rect2 = get_boss_rect(runtime, owner)
	var hit_events: Array = runtime.baal_boots_effect_state.update_projectiles(
		fps_scale,
		boss_rect,
		Vector2(float(constants.get("field_width", 760.0)), float(constants.get("field_height", 750.0)))
	)
	for hit_event_value in hit_events:
		var hit_event: Dictionary = runtime._get_dict(hit_event_value)
		apply_projectile_hit(
			runtime,
			runtime._get_vector2(hit_event.get("position", Vector2.ZERO)),
			str(hit_event.get("weather_type", "")),
			owner,
			registry,
			constants
		)


func apply_projectile_hit(
	runtime: Object,
	pos: Vector2,
	weather_type: String,
	owner: Object,
	registry: Object,
	constants: Dictionary
) -> void:
	match weather_type:
		"rain":
			runtime.baal_boots_combat_state.apply_slow(float(constants.get("rain_slow_frames", 180.0)))
		"hail":
			var boss_center: Vector2 = runtime.owner_syncer.read_owner_boss_center(runtime, owner)
			var direction: float = 1.0 if boss_center.x < float(constants.get("field_width", 760.0)) * 0.5 else -1.0
			runtime.baal_boots_combat_state.apply_knockback(
				direction,
				float(constants.get("knockback_power", 17.0)),
				float(constants.get("knockback_frames", 34.0))
			)
	spawn_aura_particles(runtime, pos, weather_type, 12, constants)
	runtime.audio_router.apply_ragnarok_feedback(runtime, {"registry": registry}, 0.06, 2.7)


func get_boss_rect(runtime: Object, owner: Object) -> Rect2:
	var pos: Vector2 = runtime._get_vector2(runtime._safe_owner_get(owner, "boss_pos", Vector2(330.0, 25.0)))
	var size: Vector2 = runtime._get_vector2(runtime._safe_owner_get(owner, "boss_paddle_size", Vector2.ZERO))
	if size == Vector2.ZERO:
		size = Vector2(
			float(runtime._safe_owner_get(owner, "boss_paddle_width", 100.0)),
			float(runtime._safe_owner_get(owner, "boss_hitbox_height", 40.0))
		)
	return Rect2(pos, size)


func give_gauge(runtime: Object, owner: Object, registry: Object, constants: Dictionary) -> void:
	runtime.baal_boots_weather_state.gauge_given = true
	if owner == null:
		return
	var gain: float = get_gauge_recovery(runtime)
	if gain <= 0.0:
		return
	var gauge_max: float = max(1.0, float(runtime._safe_owner_get(
		owner,
		"special_gauge_max",
		float(constants.get("base_special_gauge_max", 500.0))
	)))
	var current_gauge: float = clamp(float(runtime._safe_owner_get(owner, "special_gauge", 0.0)), 0.0, gauge_max)
	var next_gauge: float = clamp(current_gauge + gain, 0.0, gauge_max)
	if next_gauge <= current_gauge:
		return
	owner.set("special_gauge", next_gauge)
	runtime.gauge_feedback.trigger_gauge_flash(runtime, {"registry": registry})
	runtime.gauge_feedback.trigger_orb_gauge_spin(runtime, {
		"orb_hud_state": runtime._get_instance(registry, "orb_hud_state"),
	})


func get_player_speed_multiplier(runtime: Object, constants: Dictionary) -> float:
	if not runtime.baal_boots_weather_state.round_effect_active:
		return 1.0
	var round_weather_type: String = runtime.baal_boots_weather_state.round_weather_type
	return (
		float(constants.get("wind_speed_multiplier", 1.5))
		if round_weather_type == "breeze" or round_weather_type == "gust"
		else 1.0
	)


func resolve_boss_center_from_context(runtime: Object, context: Dictionary) -> Vector2:
	var boss_pos: Vector2 = runtime._get_vector2(context.get("boss_pos", Vector2(330.0, 25.0)))
	var boss_size: Vector2 = runtime._get_vector2(context.get("boss_paddle_size", Vector2.ZERO))
	if boss_size == Vector2.ZERO:
		boss_size = Vector2(
			float(context.get("boss_paddle_width", 100.0)),
			float(context.get("boss_hitbox_height", 40.0))
		)
	return boss_pos + boss_size * 0.5


func get_weather_color(weather_type: String) -> Color:
	match weather_type:
		"breeze":
			return Color(0.66, 0.90, 1.0, 1.0)
		"gust":
			return Color(1.0, 0.78, 0.36, 1.0)
		"fire":
			return Color(1.0, 0.26, 0.10, 1.0)
		"ice":
			return Color(0.62, 0.92, 1.0, 1.0)
		"rain":
			return Color(0.32, 0.66, 1.0, 1.0)
		"hail":
			return Color(0.82, 0.94, 1.0, 1.0)
		"sand":
			return Color(0.90, 0.68, 0.32, 1.0)
	return Color(1.0, 0.40, 0.22, 1.0)


func _get_converted_mythic_value(runtime: Object, key: String) -> float:
	if _get_converted_perk_level(runtime) <= 0:
		return 0.0
	return PerkConversionValues.get_mythic_value(ITEM_BAAL_BOOTS, key)


func _get_converted_perk_level(runtime: Object) -> int:
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		return max(0, int(runtime.get_converted_perk_effect_level(ITEM_BAAL_BOOTS)))
	return 0
