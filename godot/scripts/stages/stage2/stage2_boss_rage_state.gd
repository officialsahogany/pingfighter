extends RefCounted


static func should_trigger_crisis(
	context: Dictionary,
	crisis_triggered: bool,
	boss_rage_pending: bool,
	boss_rage_active: bool,
	crisis_player_score: int
) -> bool:
	if int(context.get("current_stage", 1)) != 2:
		return false
	if crisis_triggered or boss_rage_pending or boss_rage_active:
		return false
	var player_score: int = int(context.get("player_score", 0))
	var boss_score: int = int(context.get("boss_score", 0))
	return player_score == crisis_player_score and boss_score <= crisis_player_score


static func get_inactive_visuals(offset_y: float, tint: float, delta: float) -> Dictionary:
	return {
		"offset_y": move_toward(offset_y, 0.0, delta * 120.0),
		"tint": move_toward(tint, 0.0, delta * 2.4),
	}


static func get_visuals(
	timer: float,
	offset_y: float,
	buildup_sec: float,
	final_stomp_sec: float,
	total_sec: float
) -> Dictionary:
	var tint := 0.0
	if timer <= buildup_sec:
		tint = clamp(timer / max(0.001, buildup_sec), 0.0, 1.0)
	elif timer <= final_stomp_sec:
		tint = 1.0
	else:
		var fade: float = 1.0 - (timer - final_stomp_sec) / max(0.001, total_sec - final_stomp_sec)
		tint = clamp(fade, 0.0, 1.0)
	return {
		"tint": tint,
		"offset_y": move_toward(offset_y, 0.0, 4.0),
	}


static func should_emit_final_stomp(previous_timer: float, current_timer: float, final_stomp_sec: float) -> bool:
	return previous_timer < final_stomp_sec and current_timer >= final_stomp_sec


static func is_finished(timer: float, total_sec: float) -> bool:
	return timer > total_sec
