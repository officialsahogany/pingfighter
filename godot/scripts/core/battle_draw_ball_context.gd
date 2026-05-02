extends RefCounted

const BattleContextReader := preload("res://scripts/core/battle_context_reader.gd")


func build_effects_context(context: Dictionary, deps: Dictionary) -> Dictionary:
	var ball_effects = deps.get("ball_effects", null)
	var ball_intensity = deps.get("ball_intensity", null)
	var impact_effects = deps.get("impact_effects", null)
	var ball_vel: Vector2 = _get_vector2(context, "ball_vel", Vector2.ZERO)
	if ball_effects == null or ball_intensity == null or impact_effects == null:
		return {}
	return {
		"ball_ghost_trail": ball_effects.get_ghost_trail(),
		"ball_intensity_trail": ball_effects.get_intensity_trail(),
		"ball_intensity_particles": ball_effects.get_intensity_particles(),
		"energy_explosion_particles": impact_effects.get_energy_explosion_particles(),
		"intensity": ball_intensity.calculate(ball_vel),
		"ball_current_display_colors": ball_intensity.get_current_colors(),
		"ball_current_glow_color": ball_intensity.get_current_glow_color(),
		"ball_pos": _get_vector2(context, "ball_pos", Vector2.ZERO),
		"ball_size": float(context.get("ball_size", 22.0)),
	}


func build_draw(context: Dictionary, deps: Dictionary) -> Dictionary:
	var round_state = deps.get("round_state", null)
	var waiting_for_serve: bool = round_state == null or round_state.is_waiting_for_serve()
	var should_draw: bool = bool(context.get("ball_active", false)) or waiting_for_serve
	var draw_pos: Vector2 = _get_vector2(context, "ball_pos", Vector2.ZERO)
	if waiting_for_serve:
		draw_pos = _get_waiting_serve_ball_pos(context, round_state)

	var power_state = deps.get("power_state", null)
	var textures: Dictionary = _get_dict(context.get("textures", {}))
	return {
		"should_draw": should_draw,
		"draw_pos": draw_pos + _get_vector2(context, "shake_offset", Vector2.ZERO),
		"context": {
			"drive_ball_active": bool(context.get("drive_ball_active", false)),
			"power_smashing_freeze_active": power_state != null and power_state.is_freeze_active(),
			"power_smashing_parabola_active": power_state != null and power_state.is_parabola_active(),
			"ball_visual_type": str(context.get("ball_visual_type", "energy")),
			"bomb_ball_loaded": bool(context.get("bomb_ball_loaded", false)),
			"poisoned_ball_overlay_active": bool(context.get("poisoned_ball_overlay_active", false)),
			"viper_knockback_overlay_active": bool(context.get("viper_knockback_overlay_active", false)),
			"pingpong_ball_texture": _get_value(textures, "pingpong_ball_texture"),
			"ball_vel": _get_vector2(context, "ball_vel", Vector2.ZERO),
			"boost_charging_active": bool(context.get("boost_charging_active", false)),
		},
	}


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
