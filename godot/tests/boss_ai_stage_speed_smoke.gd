extends SceneTree

const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")

const BASE_BOSS_ACCEL := 0.798
const BASE_BOSS_MAX_SPEED := 6.3175
const CHAMPION_BOSS_SPEED_MULTIPLIER := 1.5

var _failures: Array[String] = []


func _init() -> void:
	var stage1_context: Dictionary = _build_context(1, 1.0)
	var stage3_context: Dictionary = _build_context(3, 1.06)
	var boss_pos := Vector2(200.0, 25.0)

	var stage1_result: Dictionary = BossAiState.new().update(1.0 / 60.0, boss_pos, 0.0, stage1_context)
	var stage3_result: Dictionary = BossAiState.new().update(1.0 / 60.0, boss_pos, 0.0, stage3_context)

	var stage1_vel: float = float(stage1_result.get("boss_vel", 0.0))
	var stage3_vel: float = float(stage3_result.get("boss_vel", 0.0))
	_expect(is_equal_approx(stage1_vel, BASE_BOSS_ACCEL * CHAMPION_BOSS_SPEED_MULTIPLIER), "Stage 1 boss velocity should keep the current champion baseline")
	_expect(is_equal_approx(stage3_vel, BASE_BOSS_ACCEL * CHAMPION_BOSS_SPEED_MULTIPLIER * 1.06), "Stage 3 boss velocity should be 6% faster than Stage 1")
	_expect(stage3_vel > stage1_vel, "Later-stage boss movement should be faster than Stage 1")

	if _failures.is_empty():
		print("boss_ai_stage_speed_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _build_context(stage: int, stage_speed_multiplier: float) -> Dictionary:
	return {
		"current_stage": stage,
		"width": 760.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"boss_paddle_width": 100.0,
		"boss_max_speed": BASE_BOSS_MAX_SPEED * stage_speed_multiplier,
		"boss_movement_accel": BASE_BOSS_ACCEL * CHAMPION_BOSS_SPEED_MULTIPLIER * stage_speed_multiplier,
		"boss_movement_decel": BASE_BOSS_ACCEL * CHAMPION_BOSS_SPEED_MULTIPLIER * stage_speed_multiplier,
		"boss_movement_max_speed": BASE_BOSS_MAX_SPEED * CHAMPION_BOSS_SPEED_MULTIPLIER * stage_speed_multiplier,
		"boss_dash_enabled": false,
		"boss_mistake_chance": 0.0,
		"ball_active": false,
		"waiting_for_serve": false,
		"player_serves": true,
		"ball_pos": Vector2.ZERO,
		"ball_vel": Vector2.ZERO,
		"ball_impact_boost": 1.0,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
