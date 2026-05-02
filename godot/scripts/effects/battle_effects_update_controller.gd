extends RefCounted


func update(delta: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	var fps_scale: float = delta * 60.0
	var now_msec: int = int(context.get("current_msec", Time.get_ticks_msec()))
	var dash_snapshot: Dictionary = _get_dictionary(context, "dash_snapshot")
	var dash_token_max: int = int(dash_snapshot.get("max_tokens", 1))

	var feedback = deps.get("feedback", null)
	if feedback != null:
		feedback.update(delta, dash_token_max)

	var audio = deps.get("audio", null)
	if audio != null:
		audio.update(delta)

	var scoreboard_state = deps.get("scoreboard_state", null)
	if scoreboard_state != null:
		scoreboard_state.update_top_mini_sparkle(delta)

	var drive_text_timer_frames: float = max(
		0.0,
		float(context.get("drive_text_timer_frames", 0.0)) - fps_scale
	)

	var ball_pos: Vector2 = _get_vector2(context, "ball_pos", Vector2.ZERO)
	var power_state = deps.get("power_state", null)
	if power_state != null:
		power_state.update_text_timer(fps_scale)
		power_state.update_effects(
			fps_scale,
			ball_pos,
			bool(context.get("ball_active", false)),
			float(context.get("ball_size", 0.0))
		)

	var combo_state = deps.get("combo_state", null)
	if combo_state != null:
		combo_state.update_timers(fps_scale)

	var stage_background = deps.get("stage_background", null)
	if stage_background != null:
		stage_background.update(delta)

	var orb_hud_state = deps.get("orb_hud_state", null)
	if orb_hud_state != null:
		orb_hud_state.sync_gauge_spin(
			max(0, int(round(float(context.get("special_gauge", 0.0))))),
			now_msec
		)
		orb_hud_state.sync_dash_token_spin(
			max(0, int(dash_snapshot.get("tokens", 0))),
			now_msec
		)

	_update_actor_animation(delta, context, deps, dash_snapshot)

	var impact_effects = deps.get("impact_effects", null)
	if impact_effects != null:
		impact_effects.update(delta)

	return {
		"drive_text_timer_frames": drive_text_timer_frames,
	}


func _update_actor_animation(
	delta: float,
	context: Dictionary,
	deps: Dictionary,
	dash_snapshot: Dictionary
) -> void:
	var animation_state = deps.get("animation_state", null)
	if animation_state == null:
		return
	animation_state.update(delta, {
		"player_speed": float(context.get("player_speed", 0.0)),
		"dash_active": dash_snapshot.get("active", false),
		"player_has_sprite": bool(context.get("player_has_sprite", false)),
		"player_has_idle_sprite": bool(context.get("player_has_idle_sprite", false)),
		"ball_pos": _get_vector2(context, "ball_pos", Vector2.ZERO),
		"ball_vel": _get_vector2(context, "ball_vel", Vector2.ZERO),
		"ball_active": bool(context.get("ball_active", false)),
		"ball_impact_boost": float(context.get("ball_impact_boost", 1.0)),
		"ball_size": float(context.get("ball_size", 0.0)),
		"boss_pos": _get_vector2(context, "boss_pos", Vector2.ZERO),
		"boss_vel": float(context.get("boss_vel", 0.0)),
		"boss_has_sprite": bool(context.get("boss_has_sprite", false)),
		"boss_has_hit_sprite": bool(context.get("boss_has_hit_sprite", false)),
		"boss_collision_cooldown": float(context.get("boss_collision_cooldown", 0.0)),
		"boss_paddle_width": float(context.get("boss_paddle_width", 100.0)),
		"boss_hitbox_height": float(context.get("boss_hitbox_height", 40.0)),
	})


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
