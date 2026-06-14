extends SceneTree

const Stage2BossRageState := preload("res://scripts/stages/stage2/stage2_boss_rage_state.gd")
const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_crisis_gate()
	_verify_visual_timing()
	_verify_stomp_step_window()
	_verify_runtime_delegate()

	if _failures.is_empty():
		print("stage2_boss_rage_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_crisis_gate() -> void:
	_expect(not Stage2BossRageState.should_trigger_crisis({
		"current_stage": 1,
		"player_score": 4,
		"boss_score": 2,
	}, false, false, false, 4), "crisis gate should ignore non-Stage 2 contexts")
	_expect(not Stage2BossRageState.should_trigger_crisis({
		"current_stage": 2,
		"player_score": 4,
		"boss_score": 2,
	}, true, false, false, 4), "crisis gate should ignore already-triggered states")
	_expect(Stage2BossRageState.should_trigger_crisis({
		"current_stage": 2,
		"player_score": 4,
		"boss_score": 2,
	}, false, false, false, 4), "crisis gate should arm when the player reaches the crisis score")
	_expect(not Stage2BossRageState.should_trigger_crisis({
		"current_stage": 2,
		"player_score": 4,
		"boss_score": 5,
	}, false, false, false, 4), "crisis gate should ignore boss scores above the crisis score")
	var mythic_reservation: Dictionary = Stage2BossRageState.get_crisis_reservation({
		"current_stage": 2,
		"player_score": 4,
		"boss_score": 2,
		"ai_mode": "mythic",
	}, false, false, false, 4)
	_expect(bool(mythic_reservation.get("triggered", false)), "crisis reservation should report triggered gates")
	_expect(str(mythic_reservation.get("ai_mode", "")) == "mythic", "crisis reservation should preserve mythic AI mode")
	var fallback_reservation: Dictionary = Stage2BossRageState.get_crisis_reservation({
		"current_stage": 2,
		"player_score": 4,
		"boss_score": 2,
		"league_mode": "diamond",
	}, false, false, false, 4)
	_expect(str(fallback_reservation.get("ai_mode", "")) == "champion", "crisis reservation should normalize non-mythic modes")
	_expect(Stage2BossRageState.get_crisis_ai_mode({"league_mode": "mythic"}) == "mythic", "crisis AI mode should fall back to league mode")
	_expect(Stage2BossRageState.get_crisis_rock_count("mythic", 3, 5) == 5, "mythic crisis should use the mythic rock count")
	_expect(Stage2BossRageState.get_crisis_rock_count("champion", 3, 5) == 3, "non-mythic crisis should use the champion rock count")


func _verify_visual_timing() -> void:
	var inactive_visuals: Dictionary = Stage2BossRageState.get_inactive_visuals(12.0, 0.5, 0.1)
	_expect(float(inactive_visuals.get("offset_y", 12.0)) == 0.0, "inactive visuals should decay offset toward zero")
	_expect(_is_close(float(inactive_visuals.get("tint", 0.0)), 0.26), "inactive visuals should decay tint toward zero")

	var buildup_visuals: Dictionary = Stage2BossRageState.get_visuals(0.5, 12.0, 1.0, 1.333, 1.666)
	_expect(_is_close(float(buildup_visuals.get("tint", 0.0)), 0.5), "rage buildup should scale tint by timer")
	_expect(float(buildup_visuals.get("offset_y", 12.0)) == 8.0, "rage visuals should settle offset by fixed frame step")
	var final_visuals: Dictionary = Stage2BossRageState.get_visuals(1.2, 0.0, 1.0, 1.333, 1.666)
	_expect(float(final_visuals.get("tint", 0.0)) == 1.0, "rage pre-final phase should hold full tint")
	var fade_visuals: Dictionary = Stage2BossRageState.get_visuals(1.5, 0.0, 1.0, 1.333, 1.666)
	_expect(float(fade_visuals.get("tint", 1.0)) < 1.0, "rage post-final phase should fade tint")
	_expect(Stage2BossRageState.should_emit_final_stomp(1.2, 1.4, 1.333), "final stomp should fire on threshold crossing")
	_expect(not Stage2BossRageState.should_emit_final_stomp(1.4, 1.5, 1.333), "final stomp should not refire after crossing")
	_expect(Stage2BossRageState.is_finished(1.7, 1.666), "rage should finish after total duration")
	_expect(not Stage2BossRageState.is_finished(1.6, 1.666), "rage should stay active before total duration")


func _verify_stomp_step_window() -> void:
	var steps: Array[int] = Stage2BossRageState.get_stomp_steps(0.0, 0.8, 0.25, 1.0, 4)
	_expect(steps == [1, 2, 3], "rage stomp state should report crossed buildup steps")
	var capped_steps: Array[int] = Stage2BossRageState.get_stomp_steps(0.9, 1.5, 0.25, 1.0, 4)
	_expect(capped_steps == [4], "rage stomp state should cap buildup stomp steps")
	var expired_steps: Array[int] = Stage2BossRageState.get_stomp_steps(1.0, 1.5, 0.25, 1.0, 4)
	_expect(expired_steps.is_empty(), "rage stomp state should stop after buildup")
	_expect(Stage2BossRageState.get_stomp_offset_y(1) == -18.0, "odd stomp steps should lift the boss")
	_expect(Stage2BossRageState.get_stomp_offset_y(2) == 12.0, "even stomp steps should settle the boss")


func _verify_runtime_delegate() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(source.find("Stage2BossRageState.get_crisis_reservation") >= 0, "background should reserve crisis through the rage state helper")
	_expect(source.find("Stage2BossRageState.get_crisis_rock_count") >= 0, "background should resolve crisis rock count through the rage state helper")
	_expect(source.find("func _get_crisis_ai_mode") < 0, "background should not keep crisis AI mode policy")

	var background := Stage2PillarBackground.new()
	background.update(0.0, {
		"current_stage": 2,
		"player_score": 4,
		"boss_score": 2,
	}, {})
	_expect(background.is_boss_rage_pending(), "background should delegate crisis gating and reserve rage")
	_expect(background.start_boss_rage_animation({}), "background should start pending boss rage")
	background.update(0.25, {
		"current_stage": 2,
		"player_score": 4,
		"boss_score": 2,
	}, {})
	var snapshot: Dictionary = background.get_boss_rage_snapshot()
	_expect(bool(snapshot.get("active", false)), "background rage should remain active during buildup")
	_expect(float(snapshot.get("timer", 0.0)) > 0.0, "background rage should advance timer")
	_expect(float(snapshot.get("tint", 0.0)) > 0.0, "background rage should expose computed tint")


func _is_close(actual: float, expected: float, tolerance: float = 0.001) -> bool:
	return abs(actual - expected) <= tolerance


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
