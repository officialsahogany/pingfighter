extends RefCounted

var boss_slow_timer_frames := 0.0
var boss_knockback_timer_frames := 0.0
var boss_knockback_vel := 0.0
var ball_mark_type := ""
var ball_mark_timer_frames := 0.0


func clear() -> void:
	boss_slow_timer_frames = 0.0
	boss_knockback_timer_frames = 0.0
	boss_knockback_vel = 0.0
	ball_mark_type = ""
	ball_mark_timer_frames = 0.0


func update(fps_scale: float, knockback_decay: float) -> void:
	var step: float = max(0.0, fps_scale)
	if boss_slow_timer_frames > 0.0:
		boss_slow_timer_frames = max(0.0, boss_slow_timer_frames - step)
	if boss_knockback_timer_frames > 0.0:
		boss_knockback_timer_frames = max(0.0, boss_knockback_timer_frames - step)
		boss_knockback_vel *= pow(knockback_decay, step)
		if boss_knockback_timer_frames <= 0.0 or abs(boss_knockback_vel) <= 0.25:
			boss_knockback_timer_frames = 0.0
			boss_knockback_vel = 0.0
	if ball_mark_timer_frames > 0.0:
		ball_mark_timer_frames = max(0.0, ball_mark_timer_frames - step)
		if ball_mark_timer_frames <= 0.0:
			ball_mark_type = ""


func mark_ball(weather_type: String, duration_frames: float) -> void:
	ball_mark_type = weather_type
	ball_mark_timer_frames = duration_frames


func consume_ball_mark() -> String:
	if ball_mark_timer_frames <= 0.0 or ball_mark_type == "":
		return ""
	var mark_type := ball_mark_type
	ball_mark_timer_frames = 0.0
	ball_mark_type = ""
	return mark_type


func apply_knockback(direction: float, power: float, duration_frames: float) -> float:
	boss_knockback_vel = direction * power
	boss_knockback_timer_frames = duration_frames
	return boss_knockback_vel


func apply_slow(duration_frames: float) -> void:
	boss_slow_timer_frames = max(boss_slow_timer_frames, duration_frames)


func merge_boss_ai_context(context: Dictionary, slow_multiplier: float) -> void:
	context["baal_boots_boss_slow_active"] = boss_slow_timer_frames > 0.0
	context["baal_boots_boss_slow_multiplier"] = slow_multiplier
	context["baal_boots_boss_knockback_active"] = boss_knockback_timer_frames > 0.0 and abs(boss_knockback_vel) > 0.0
	context["baal_boots_boss_knockback_vel"] = boss_knockback_vel


func merge_ball_draw_context(context: Dictionary) -> void:
	if ball_mark_timer_frames > 0.0 and ball_mark_type != "":
		context["baal_boots_ball_mark_active"] = true
		context["baal_boots_ball_mark_type"] = ball_mark_type


func get_context() -> Dictionary:
	return {
		"boss_slow_timer_frames": boss_slow_timer_frames,
		"boss_knockback_timer_frames": boss_knockback_timer_frames,
		"ball_mark_type": ball_mark_type,
		"ball_mark_timer_frames": ball_mark_timer_frames,
	}
