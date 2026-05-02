extends RefCounted

const BossAiPredictionState := preload("res://scripts/ai/boss_ai_prediction_state.gd")
const BossAiTurnInertiaResolver := preload("res://scripts/ai/boss_ai_turn_inertia_resolver.gd")

var prediction_state: Object = BossAiPredictionState.new()
var turn_inertia_resolver: Object = BossAiTurnInertiaResolver.new()


func reset() -> void:
	prediction_state.reset()


func update(delta: float, boss_pos: Vector2, boss_vel: float, context: Dictionary) -> Dictionary:
	var fps_scale: float = delta * 60.0
	var width: float = float(context.get("width", 760.0))
	var play_left: float = float(context.get("play_left", 0.0))
	var play_right: float = float(context.get("play_right", width))
	var boss_paddle_width: float = float(context.get("boss_paddle_width", 100.0))
	var boss_center: float = boss_pos.x + boss_paddle_width * 0.5
	var future_x: float = width * 0.5
	var ball_approaching_boss: bool = false

	if bool(context.get("ball_active", false)) and not bool(context.get("waiting_for_serve", true)):
		var ball_pos: Vector2 = _as_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
		var ball_vel: Vector2 = _as_vector2(context.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
		ball_approaching_boss = ball_vel.y < 0.0
		future_x = prediction_state.predict_future_x(
			ball_pos,
			ball_vel,
			fps_scale,
			play_left,
			play_right,
			boss_paddle_width,
			context
		)
	else:
		prediction_state.reset()
		future_x = width * 0.5

	var reaction_multiplier: float = _get_power_smash_reaction_multiplier(context)
	boss_vel = turn_inertia_resolver.update_velocity(
		future_x,
		boss_center,
		boss_vel,
		fps_scale,
		ball_approaching_boss,
		reaction_multiplier
	)
	boss_pos.x += boss_vel * fps_scale
	boss_pos.x = clamp(boss_pos.x, play_left, play_right - boss_paddle_width)

	return {
		"boss_pos": boss_pos,
		"boss_vel": boss_vel,
	}

func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _get_power_smash_reaction_multiplier(context: Dictionary) -> float:
	if not bool(context.get("power_smashing_parabola_active", false)):
		return 1.0
	var combo_consumed: int = int(context.get("power_smashing_combo_consumed", 0))
	if combo_consumed < 2:
		return 1.0
	return 1.0 + min(float(combo_consumed) * 0.05, 0.30)
