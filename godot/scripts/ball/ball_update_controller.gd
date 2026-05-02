extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")
const BallFrameMotionController := preload("res://scripts/ball/ball_frame_motion_controller.gd")
const BallMotionEventProcessor := preload("res://scripts/ball/ball_motion_event_processor.gd")

var frame_motion_controller: Object = BallFrameMotionController.new()
var motion_event_processor: Object = BallMotionEventProcessor.new()


func update(delta: float, context: Dictionary, deps: Dictionary, callbacks: Dictionary = {}) -> Dictionary:
	var scene: Dictionary = _build_scene_snapshot(context)
	var fps_scale: float = delta * 60.0
	var power_state: Object = deps.get("power_state", null)

	if power_state != null and power_state.is_freeze_active():
		frame_motion_controller.update_power_freeze(delta, scene, context, deps)
		return {"snapshot": scene}

	if not bool(context.get("ball_active", false)):
		return {}

	var power_smashing_parabola_active: bool = power_state != null and power_state.is_parabola_active()
	frame_motion_controller.update_serve_collision_cooldowns(scene, fps_scale)
	if not power_smashing_parabola_active:
		frame_motion_controller.cap_ball_speed(scene, deps)

	frame_motion_controller.apply_impact_decay(scene, fps_scale, deps)
	frame_motion_controller.apply_ball_spin(scene, fps_scale, deps)
	frame_motion_controller.apply_power_motion(scene, fps_scale, context, deps)
	frame_motion_controller.apply_stage1_dalji_whip(scene, fps_scale, context, deps)

	if not power_smashing_parabola_active:
		frame_motion_controller.cap_ball_speed(scene, deps)

	var score_event: String = motion_event_processor.step_motion(scene, fps_scale, context, deps, callbacks)
	if score_event != "":
		return {
			"snapshot": scene,
			"score_event": score_event,
		}

	_update_ball_effects(scene, fps_scale, context, deps)
	return {"snapshot": scene}


func _build_scene_snapshot(context: Dictionary) -> Dictionary:
	return {
		"ball_pos": _get_vector2(context, "ball_pos", Vector2.ZERO),
		"ball_vel": _get_vector2(context, "ball_vel", Vector2.ZERO),
		"ball_impact_boost": float(context.get("ball_impact_boost", 1.0)),
		"ball_boost_decay_rate": float(context.get("ball_boost_decay_rate", 0.975)),
		"ball_min_boost": float(context.get("ball_min_boost", 0.70)),
		"player_collision_cooldown": float(context.get("player_collision_cooldown", 0.0)),
		"boss_collision_cooldown": float(context.get("boss_collision_cooldown", 0.0)),
		"vertical_bounce_count": int(context.get("vertical_bounce_count", 0)),
		"ball_spin_strength": float(context.get("ball_spin_strength", 0.0)),
		"ball_spin_direction": int(context.get("ball_spin_direction", 0)),
		"drive_ball_active": bool(context.get("drive_ball_active", false)),
		"drive_hit_boss": bool(context.get("drive_hit_boss", false)),
		"drive_speed_increase": float(context.get("drive_speed_increase", 0.0)),
		"drive_text_timer_frames": float(context.get("drive_text_timer_frames", 0.0)),
		"special_gauge": float(context.get("special_gauge", 0.0)),
		"player_speed": float(context.get("player_speed", 0.0)),
		"boss_vel": float(context.get("boss_vel", 0.0)),
	}


func _update_ball_effects(scene: Dictionary, fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	var ball_effects: Object = deps.get("ball_effects", null)
	var ball_intensity: Object = deps.get("ball_intensity", null)
	if ball_effects == null or ball_intensity == null:
		return
	var ball_pos: Vector2 = _get_vector2(scene, "ball_pos", Vector2.ZERO)
	var ball_vel: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
	ball_effects.update_ghost_trail(ball_pos, float(context.get("ball_size", 28.6)) * 0.5, fps_scale)
	ball_intensity.update_transition(ball_vel, fps_scale)
	ball_effects.update_intensity_particles(
		ball_pos,
		ball_vel,
		fps_scale,
		ball_intensity.calculate(ball_vel),
		ball_intensity.get_current_colors()
	)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)
