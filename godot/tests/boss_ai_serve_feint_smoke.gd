extends SceneTree

const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")

const BASE_BOSS_ACCEL := 0.798
const BASE_BOSS_MAX_SPEED := 6.3175
const CHAMPION_BOSS_SPEED_MULTIPLIER := 1.5

var _failures: Array[String] = []


func _init() -> void:
	seed(2489)
	_verify_every_named_profile_builds_a_plan()
	_verify_hold_snap_waits_then_moves()
	_verify_bait_reverse_changes_sides_before_release()
	_verify_serve_feint_resets_after_wait()

	if _failures.is_empty():
		print("boss_ai_serve_feint_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_every_named_profile_builds_a_plan() -> void:
	for profile in [
		"hold_snap",
		"side_step",
		"bait_reverse",
		"double_bluff",
		"stare_down",
		"shuffle",
	]:
		var state: Object = BossAiState.new()
		state.update(
			1.0 / 60.0,
			Vector2(300.0, 25.0),
			0.0,
			_build_context(profile, 1.0, 0.12)
		)
		var snapshot: Dictionary = state.get_serve_feint_snapshot()
		_expect(bool(snapshot.get("active", false)), "%s should activate a serve feint plan" % profile)
		_expect(str(snapshot.get("profile", "")) == profile, "%s should honor the forced profile" % profile)
		_expect(float(snapshot.get("release_x", -1.0)) >= 50.0, "%s should choose a legal release target" % profile)


func _verify_hold_snap_waits_then_moves() -> void:
	var state: Object = BossAiState.new()
	var early_result: Dictionary = state.update(
		1.0 / 60.0,
		Vector2(300.0, 25.0),
		0.0,
		_build_context("hold_snap", 1.0, 0.08)
	)
	_expect(is_equal_approx(float(early_result.get("boss_vel", -99.0)), 0.0), "hold-snap should stay still early in the serve wait")

	var late_result: Dictionary = state.update(
		1.0 / 60.0,
		Vector2(300.0, 25.0),
		0.0,
		_build_context("hold_snap", 1.0, 0.84)
	)
	_expect(float(late_result.get("boss_vel", 0.0)) > 0.0, "hold-snap should sidestep toward its release target late")


func _verify_bait_reverse_changes_sides_before_release() -> void:
	var state: Object = BossAiState.new()
	state.update(
		1.0 / 60.0,
		Vector2(300.0, 25.0),
		0.0,
		_build_context("bait_reverse", 1.0, 0.16)
	)
	var snapshot: Dictionary = state.get_serve_feint_snapshot()
	var anchor_x: float = float(snapshot.get("anchor_x", 0.0))
	var decoy_x: float = float(snapshot.get("decoy_x", 0.0))
	var release_x: float = float(snapshot.get("release_x", 0.0))
	_expect(decoy_x > anchor_x, "bait-reverse should first show the right-side decoy when forced right")
	_expect(release_x < anchor_x, "bait-reverse should release from the opposite side")

	var release_result: Dictionary = state.update(
		1.0 / 60.0,
		Vector2(decoy_x - 50.0, 25.0),
		0.0,
		_build_context("bait_reverse", 1.0, 0.96)
	)
	_expect(float(release_result.get("boss_vel", 0.0)) < 0.0, "bait-reverse should cut back toward the release side")


func _verify_serve_feint_resets_after_wait() -> void:
	var state: Object = BossAiState.new()
	state.update(
		1.0 / 60.0,
		Vector2(300.0, 25.0),
		0.0,
		_build_context("side_step", 1.0, 0.20)
	)
	var reset_context: Dictionary = _build_context("side_step", 1.0, 0.20)
	reset_context["waiting_for_serve"] = false
	reset_context["ball_active"] = true
	state.update(1.0 / 60.0, Vector2(300.0, 25.0), 0.0, reset_context)
	_expect(not bool(state.get_serve_feint_snapshot().get("active", true)), "serve feint should reset once play begins")


func _build_context(profile: String, serve_delay: float, progress: float) -> Dictionary:
	return {
		"current_stage": 1,
		"ai_mode": "champion",
		"width": 760.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"boss_paddle_width": 100.0,
		"boss_max_speed": BASE_BOSS_MAX_SPEED,
		"boss_movement_accel": BASE_BOSS_ACCEL * CHAMPION_BOSS_SPEED_MULTIPLIER,
		"boss_movement_decel": BASE_BOSS_ACCEL * CHAMPION_BOSS_SPEED_MULTIPLIER,
		"boss_movement_max_speed": BASE_BOSS_MAX_SPEED * CHAMPION_BOSS_SPEED_MULTIPLIER,
		"boss_dash_enabled": false,
		"boss_mistake_chance": 0.0,
		"ball_active": false,
		"waiting_for_serve": true,
		"player_serves": false,
		"boss_serve_timer": serve_delay * progress,
		"boss_serve_target_delay": serve_delay,
		"boss_serve_feint_profile_override": profile,
		"boss_serve_feint_side_override": 1.0,
		"player_pos": Vector2(520.0, 690.0),
		"player_paddle_width": 155.0,
		"ball_pos": Vector2.ZERO,
		"ball_vel": Vector2.ZERO,
		"ball_impact_boost": 1.0,
		"ball_boost_decay_rate": 0.975,
		"ball_min_boost": 0.70,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
