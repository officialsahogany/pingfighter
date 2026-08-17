extends RefCounted

const BattleContextReader := preload("res://scripts/core/battle_context_reader.gd")
const BallRenderInterpolation := preload("res://scripts/ball/ball_render_interpolation.gd")
const ViperAirborneLod := preload("res://scripts/core/viper_airborne_lod.gd")


func build_effects_context(context: Dictionary, deps: Dictionary) -> Dictionary:
	var ball_effects = deps.get("ball_effects", null)
	var ball_intensity = deps.get("ball_intensity", null)
	var impact_effects = deps.get("impact_effects", null)
	var ball_vel: Vector2 = _get_vector2(context, "ball_vel", Vector2.ZERO)
	if ball_effects == null or ball_intensity == null or impact_effects == null:
		return {}
	var power_state = deps.get("power_state", null)
	var lod_active: bool = ViperAirborneLod.is_any_lod_active(context)
	var lod_scale: float = ViperAirborneLod.effect_scale(context)
	return {
		"ball_ghost_trail": ball_effects.get_ghost_trail(),
		"ball_intensity_trail": ball_effects.get_intensity_trail(),
		"ball_intensity_particles": ball_effects.get_intensity_particles(),
		"energy_explosion_particles": impact_effects.get_energy_explosion_particles(),
		"intensity": ball_intensity.calculate(ball_vel),
		"ball_current_display_colors": ball_intensity.get_current_colors(),
		"ball_current_glow_color": ball_intensity.get_current_glow_color(),
		"ball_pos": _get_effective_ball_draw_pos(context),
		"ball_size": float(context.get("ball_size", 28.6)),
		"ball_render_radius": float(context.get("ball_render_radius", float(context.get("ball_size", 28.6)) * 0.5)),
		"viper_airborne_lod_active": lod_active,
		"effect_lod_scale": lod_scale,
		"ghost_shot_active": _call_bool(power_state, "is_ghost_shot_active"),
		"ghost_shot_motion_active": _call_bool(power_state, "is_ghost_shot_motion_active"),
	}


func build_draw(context: Dictionary, deps: Dictionary) -> Dictionary:
	var round_state = deps.get("round_state", null)
	var waiting_for_serve: bool = round_state == null or round_state.is_waiting_for_serve()
	var kuromi_ball_hidden: bool = bool(context.get("stage3_kuromi_ball_hidden", false))
	var should_draw: bool = (bool(context.get("ball_active", false)) or waiting_for_serve) and not kuromi_ball_hidden
	var draw_pos: Vector2 = _get_vector2(context, "ball_pos", Vector2.ZERO)
	if waiting_for_serve:
		draw_pos = _get_waiting_serve_ball_pos(context, round_state)
	elif bool(context.get("ball_render_interpolation_enabled", true)):
		draw_pos = BallRenderInterpolation.get_render_ball_pos(context, draw_pos)

	var power_state = deps.get("power_state", null)
	var textures: Dictionary = _get_dict(context.get("textures", {}))
	var fire_weather_ball_active: bool = _is_fire_weather_active(context, deps)
	var lod_active: bool = ViperAirborneLod.is_any_lod_active(context)
	var lod_scale: float = ViperAirborneLod.effect_scale(context)
	var ball_context := {
		"drive_ball_active": bool(context.get("drive_ball_active", false)),
		"perk_fusion_thunder_drive_active": float(context.get("perk_fusion_overload_speed_cap", 0.0)) > 0.0,
		"power_smashing_freeze_active": power_state != null and power_state.is_freeze_active(),
		"power_smashing_parabola_active": power_state != null and power_state.is_parabola_active(),
		"ghost_shot_active": _call_bool(power_state, "is_ghost_shot_active"),
		"ghost_shot_motion_active": _call_bool(power_state, "is_ghost_shot_motion_active"),
		"ghost_shot_pending_teleport": _call_bool(power_state, "has_ghost_shot_pending_teleport"),
		"ball_visual_type": str(context.get("ball_visual_type", "energy")),
		"bomb_ball_loaded": bool(context.get("bomb_ball_loaded", false)),
		"poisoned_ball_overlay_active": bool(context.get("poisoned_ball_overlay_active", false)),
		"viper_knockback_overlay_active": bool(context.get("viper_knockback_overlay_active", false)),
		"fire_weather_ball_active": fire_weather_ball_active,
		"pingpong_ball_texture": _get_value(textures, "pingpong_ball_texture"),
		"ball_vel": _get_vector2(context, "ball_vel", Vector2.ZERO),
		"boost_charging_active": bool(context.get("boost_charging_active", false)),
		"viper_airborne_lod_active": lod_active,
		"effect_lod_scale": lod_scale,
	}
	var mythic_item_runtime = deps.get("mythic_item_runtime", null)
	if (
		mythic_item_runtime != null
		and mythic_item_runtime.has_method("get_ball_draw_context")
		and _should_read_ball_draw_context(mythic_item_runtime)
	):
		ball_context.merge(mythic_item_runtime.get_ball_draw_context(), true)
	var ball_effects = deps.get("ball_effects", null)
	if ball_effects != null and ball_effects.has_method("get_hit_pulse_event"):
		ball_context["hit_pulse_event"] = ball_effects.get_hit_pulse_event()
	return {
		"should_draw": should_draw,
		"draw_pos": draw_pos + _get_vector2(context, "shake_offset", Vector2.ZERO),
		"context": ball_context,
	}


func _get_effective_ball_draw_pos(context: Dictionary) -> Vector2:
	var ball_pos: Vector2 = _get_vector2(context, "ball_pos", Vector2.ZERO)
	if not bool(context.get("ball_active", false)):
		return ball_pos
	if not bool(context.get("ball_render_interpolation_enabled", true)):
		return ball_pos
	return BallRenderInterpolation.get_render_ball_pos(context, ball_pos)


func _get_waiting_serve_ball_pos(context: Dictionary, round_state) -> Vector2:
	var player_pos: Vector2 = _get_vector2(context, "player_pos", Vector2.ZERO)
	var boss_pos: Vector2 = _get_vector2(context, "boss_pos", Vector2.ZERO)
	var player_serves: bool = round_state == null or round_state.does_player_serve()
	if player_serves:
		return Vector2(
			player_pos.x + float(context.get("player_paddle_width", 0.0)) * 0.5,
			float(context.get("player_y", 0.0)) - float(context.get("ball_render_radius", 0.0))
		)
	return Vector2(
		boss_pos.x + float(context.get("boss_paddle_width", 0.0)) * 0.5,
		float(context.get("boss_y", 0.0))
			+ float(context.get("boss_hitbox_height", 0.0))
			+ float(context.get("ball_render_radius", 0.0))
	)


func _get_value(source: Dictionary, key: String) -> Variant:
	return source.get(key, null)


func _get_dict(value: Variant) -> Dictionary:
	return BattleContextReader.get_dictionary(value)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BattleContextReader.get_vector2(source, key, fallback)


func _call_bool(owner: Variant, method_name: String) -> bool:
	if owner == null or not (owner is Object) or not owner.has_method(method_name):
		return false
	return bool(owner.call(method_name))


func _should_read_ball_draw_context(source: Object) -> bool:
	if source.has_method("has_ball_draw_context"):
		return bool(source.has_ball_draw_context())
	return true


func _is_fire_weather_active(context: Dictionary, deps: Dictionary) -> bool:
	var weather = deps.get("weather_event_state", null)
	if weather != null and weather.has_method("is_fire_active") and bool(weather.is_fire_active()):
		return true
	return (
		(bool(context.get("weather_active", false)) or bool(context.get("weather_event_active", false)))
		and str(context.get("weather_type", "")) == "fire"
	)
