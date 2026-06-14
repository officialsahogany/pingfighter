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


static func get_crisis_reservation(
	context: Dictionary,
	crisis_triggered: bool,
	boss_rage_pending: bool,
	boss_rage_active: bool,
	crisis_player_score: int
) -> Dictionary:
	if not should_trigger_crisis(
		context,
		crisis_triggered,
		boss_rage_pending,
		boss_rage_active,
		crisis_player_score
	):
		return {"triggered": false, "ai_mode": ""}
	return {
		"triggered": true,
		"ai_mode": get_crisis_ai_mode(context),
	}


static func get_crisis_ai_mode(context: Dictionary) -> String:
	var ai_mode: String = str(context.get("ai_mode", context.get("league_mode", "champion")))
	return "mythic" if ai_mode == "mythic" else "champion"


static func get_crisis_rock_count(ai_mode: String, champion_count: int, mythic_count: int) -> int:
	return mythic_count if ai_mode == "mythic" else champion_count


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


static func get_stomp_steps(
	previous_timer: float,
	current_timer: float,
	interval_sec: float,
	buildup_sec: float,
	max_step_count: int
) -> Array[int]:
	var steps: Array[int] = []
	var previous_step: int = int(floor(previous_timer / interval_sec))
	var current_step: int = int(floor(current_timer / interval_sec))
	if previous_timer >= buildup_sec or current_step <= previous_step:
		return steps
	var max_step: int = min(int(floor(buildup_sec / interval_sec)), max_step_count)
	for step in range(previous_step + 1, min(current_step, max_step) + 1):
		if step > 0:
			steps.append(step)
	return steps


static func get_stomp_offset_y(step: int) -> float:
	return -18.0 if step % 2 == 1 else 12.0


static func is_finished(timer: float, total_sec: float) -> bool:
	return timer > total_sec
