extends SceneTree

const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")

const BASE_BOSS_ACCEL := 0.798
const BASE_BOSS_MAX_SPEED := 6.3175
const CHAMPION_BOSS_SPEED_MULTIPLIER := 1.5
const BASE_BOSS_DASH_MAX_DISTANCE := 316.8
const BASE_BOSS_DASH_COOLDOWN_MIN_SECONDS := 40.0
const BASE_BOSS_DASH_COOLDOWN_MAX_SECONDS := 55.0
const BOSS_DASH_AVERAGE_SPEED := 30.0
const BOSS_DASH_SPEED := 40.0

var _failures: Array[String] = []


func _init() -> void:
	var context: Dictionary = _build_stage3_context()
	var state: Object = BossAiState.new()
	var boss_pos := Vector2(40.0, 25.0)

	var result: Dictionary = state.update(1.0 / 60.0, boss_pos, 0.0, context)
	var dash_draw: Dictionary = state.get_dash_draw_context()
	var dash_snapshot: Dictionary = state.get_dash_token_snapshot()

	var expected_dash_distance: float = BASE_BOSS_DASH_MAX_DISTANCE * 1.10
	var expected_duration: float = expected_dash_distance / BOSS_DASH_AVERAGE_SPEED
	var expected_first_frame_speed: float = BOSS_DASH_SPEED * ((expected_duration - 1.0) / expected_duration)
	var recharge_frames: float = float(dash_snapshot.get("recharge_frames", 0.0))
	var expected_min_recharge: float = BASE_BOSS_DASH_COOLDOWN_MIN_SECONDS * 0.90 * 60.0
	var expected_max_recharge: float = BASE_BOSS_DASH_COOLDOWN_MAX_SECONDS * 0.90 * 60.0

	_expect(bool(dash_draw.get("boss_dash_active", false)), "Stage 3 boss dash should be allowed by the shared dash gate")
	_expect(int(dash_draw.get("boss_dash_direction", 0)) == 1, "Stage 3 boss dash should move toward the predicted intercept")
	_expect(is_equal_approx(float(dash_snapshot.get("duration_frames", 0.0)), expected_duration), "Stage 3 boss dash duration should use +10% distance")
	_expect(abs(float(result.get("boss_vel", 0.0)) - expected_first_frame_speed) <= 0.001, "Stage 3 boss dash should use the shared dash speed curve")
	_expect(int(dash_snapshot.get("tokens", -1)) == 0, "Stage 3 boss dash should consume the boss dash token")
	_expect(recharge_frames >= expected_min_recharge and recharge_frames <= expected_max_recharge, "Stage 3 boss dash recharge should use -10% cooldown")
	_verify_two_dash_tokens_leave_one_after_dash()
	_verify_two_token_boss_recovers_without_explicit_chain_flag()
	_verify_two_token_boss_respects_zero_chain_chance()
	_verify_two_token_boss_chains_dash_when_ball_stays_far()
	_verify_two_token_boss_recovers_when_ball_is_close_after_dash()
	_verify_inactive_grenade_knockback_does_not_move_boss()

	if _failures.is_empty():
		print("boss_ai_stage_dash_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_inactive_grenade_knockback_does_not_move_boss() -> void:
	var context: Dictionary = _build_stage3_context()
	context["active_item_grenade_stun_active"] = true
	context["active_item_grenade_knockback_active"] = false
	context["active_item_grenade_knockback_vel"] = 40.0
	var state: Object = BossAiState.new()
	var boss_pos := Vector2(320.0, 25.0)
	var result: Dictionary = state.update(1.0 / 60.0, boss_pos, 5.0, context)
	var result_pos: Vector2 = result.get("boss_pos", Vector2.ZERO)
	_expect(is_equal_approx(result_pos.x, boss_pos.x), "inactive stun knockback should not move the boss")
	_expect(is_equal_approx(float(result.get("boss_vel", -1.0)), 0.0), "inactive stun knockback should report zero boss velocity")


func _verify_two_dash_tokens_leave_one_after_dash() -> void:
	var context: Dictionary = _build_stage3_context()
	context["ai_mode"] = "mythic"
	context["boss_dash_max_tokens"] = 2
	var state: Object = BossAiState.new()
	state.update(1.0 / 60.0, Vector2(40.0, 25.0), 0.0, context)
	var dash_snapshot: Dictionary = state.get_dash_token_snapshot()
	_expect(int(dash_snapshot.get("max_tokens", 0)) == 2, "two-token boss dash context should raise max tokens")
	_expect(int(dash_snapshot.get("tokens", -1)) == 1, "two-token boss dash should leave one token after the first dash")


func _verify_two_token_boss_chains_dash_when_ball_stays_far() -> void:
	var context: Dictionary = _build_stage3_context()
	context["ai_mode"] = "mythic"
	context["boss_dash_max_tokens"] = 2
	context["boss_dash_chain_enabled"] = true
	context["boss_dash_chain_trigger_chance"] = 1.0
	var state: Object = BossAiState.new()
	var result: Dictionary = state.update(1.0 / 60.0, Vector2(40.0, 25.0), 0.0, context)
	var chained := false
	for _frame in range(80):
		result = state.update(
			1.0 / 60.0,
			result.get("boss_pos", Vector2.ZERO),
			float(result.get("boss_vel", 0.0)),
			context
		)
		var dash_snapshot: Dictionary = state.get_dash_token_snapshot()
		if (
			bool(dash_snapshot.get("active", false))
			and not bool(dash_snapshot.get("recovering", false))
			and int(dash_snapshot.get("tokens", -1)) == 0
		):
			chained = true
			break
	_expect(chained, "two-token boss should chain into a second dash when the predicted ball target stays far")


func _verify_two_token_boss_recovers_without_explicit_chain_flag() -> void:
	var context: Dictionary = _build_stage3_context()
	context["ai_mode"] = "mythic"
	context["boss_dash_max_tokens"] = 2
	context.erase("boss_dash_chain_enabled")
	context.erase("boss_dash_chain_trigger_chance")
	_expect(_runs_to_dash_recovery(context), "two-token boss should recover when boss_dash_chain_enabled is not explicit")


func _verify_two_token_boss_respects_zero_chain_chance() -> void:
	var context: Dictionary = _build_stage3_context()
	context["ai_mode"] = "mythic"
	context["boss_dash_max_tokens"] = 2
	context["boss_dash_chain_enabled"] = true
	context["boss_dash_chain_trigger_chance"] = 0.0
	_expect(_runs_to_dash_recovery(context), "two-token boss should recover when boss_dash_chain_trigger_chance is zero")


func _verify_two_token_boss_recovers_when_ball_is_close_after_dash() -> void:
	var context: Dictionary = _build_stage3_context()
	context["ai_mode"] = "mythic"
	context["boss_dash_max_tokens"] = 2
	context["boss_dash_chain_enabled"] = true
	context["boss_dash_chain_trigger_chance"] = 1.0
	context["ball_pos"] = Vector2(330.0, 145.0)
	_expect(_runs_to_dash_recovery(context), "two-token boss should enter recovery instead of chaining when the predicted ball target is close")


func _runs_to_dash_recovery(context: Dictionary) -> bool:
	var state: Object = BossAiState.new()
	var result: Dictionary = state.update(1.0 / 60.0, Vector2(40.0, 25.0), 0.0, context)
	for _frame in range(80):
		result = state.update(
			1.0 / 60.0,
			result.get("boss_pos", Vector2.ZERO),
			float(result.get("boss_vel", 0.0)),
			context
		)
		var dash_snapshot: Dictionary = state.get_dash_token_snapshot()
		if bool(dash_snapshot.get("recovering", false)):
			return int(dash_snapshot.get("tokens", -1)) == 1
	return false


func _build_stage3_context() -> Dictionary:
	return {
		"current_stage": 3,
		"ai_mode": "junior",
		"width": 760.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"boss_y": 25.0,
		"hitbox_padding": 5.0,
		"ball_size": 28.6,
		"boss_max_speed": BASE_BOSS_MAX_SPEED * 1.06,
		"boss_movement_accel": BASE_BOSS_ACCEL * CHAMPION_BOSS_SPEED_MULTIPLIER * 1.06,
		"boss_movement_decel": BASE_BOSS_ACCEL * CHAMPION_BOSS_SPEED_MULTIPLIER * 1.06,
		"boss_movement_max_speed": BASE_BOSS_MAX_SPEED * CHAMPION_BOSS_SPEED_MULTIPLIER * 1.06,
		"boss_dash_enabled": true,
		"boss_dash_max_tokens": 1,
		"boss_dash_max_distance": BASE_BOSS_DASH_MAX_DISTANCE * 1.10,
		"boss_dash_trigger_chance": 1.0,
		"boss_dash_chain_enabled": false,
		"boss_dash_chain_trigger_chance": 1.0,
		"boss_dash_cooldown_min_seconds": BASE_BOSS_DASH_COOLDOWN_MIN_SECONDS * 0.90,
		"boss_dash_cooldown_max_seconds": BASE_BOSS_DASH_COOLDOWN_MAX_SECONDS * 0.90,
		"boss_dash_stun_seconds": 0.60,
		"boss_mistake_chance": 0.0,
		"ball_active": true,
		"waiting_for_serve": false,
		"player_serves": true,
		"ball_pos": Vector2(650.0, 145.0),
		"ball_vel": Vector2(0.0, -8.0),
		"ball_impact_boost": 1.0,
		"ball_boost_decay_rate": 0.975,
		"ball_min_boost": 0.70,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
