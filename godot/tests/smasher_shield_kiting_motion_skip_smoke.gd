extends SceneTree

const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const SmasherShieldKitingState := preload("res://scripts/characters/smasher_shield_kiting_state.gd")

var _failures: Array[String] = []


class FakeStage5SkipState:
	var skipping := true

	func should_skip_ball_motion_step() -> bool:
		return skipping


class FakeSkillConfig:
	func is_skill_equipped(skill_name: String) -> bool:
		return skill_name == "shield_kiting"

	func get_skill_cost(_skill_name: String) -> float:
		return 130.0

	func get_cooldown_seconds(_skill_name: String) -> float:
		return 12.0


class FakeSkillState:
	var triggered_skill := ""

	func trigger_configured_cooldown(skill_name: String, _time_now: int, _skill_config: Object) -> void:
		triggered_skill = skill_name

	func get_configured_cooldown_remaining(_skill_name: String, _time_now: int, _skill_config: Object) -> float:
		return 0.0


func _init() -> void:
	_verify_shield_kiting_ticks_while_stage5_hijacks_ball_motion()

	if _failures.is_empty():
		print("smasher_shield_kiting_motion_skip_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_shield_kiting_ticks_while_stage5_hijacks_ball_motion() -> void:
	var shield_state := SmasherShieldKitingState.new()
	var skill_state := FakeSkillState.new()
	var context: Dictionary = _base_context()
	var now_msec := Time.get_ticks_msec()
	shield_state.last_action_edge_msec = now_msec - 120
	var activation: Dictionary = shield_state.update_input(
		{"action_pressed": true},
		now_msec,
		500.0,
		_get_vector2(context, "player_pos", Vector2.ZERO),
		context,
		{
			"skill_config": FakeSkillConfig.new(),
			"skill_state": skill_state,
		}
	)
	_expect(bool(activation.get("activated", false)), "Shield Kiting should activate from the double-tap edge")
	_expect(skill_state.triggered_skill == "shield_kiting", "Shield Kiting activation should trigger its cooldown")
	_expect(shield_state.is_movement_locked(), "Shield Kiting wind-up should initially lock Smasher movement")

	var windup_start_msec: int = Time.get_ticks_msec() - SmasherShieldKitingState.WIND_UP_MSEC - 80
	shield_state.projectile["started_msec"] = windup_start_msec
	shield_state.projectile["last_update_msec"] = windup_start_msec
	context["special_gauge"] = float(activation.get("special_gauge", 370.0))

	var controller := BallUpdateController.new()
	var result: Dictionary = controller.update(
		1.0 / 60.0,
		context,
		{
			"stage5_hongryun_state": FakeStage5SkipState.new(),
			"smasher_shield_kiting_state": shield_state,
		}
	)
	var snapshot_value: Variant = result.get("snapshot", {})
	var snapshot: Dictionary = {}
	if snapshot_value is Dictionary:
		snapshot = snapshot_value
	_expect(bool(snapshot.get("skip_ball_motion_step", false)), "Stage 5 Hongryun should still own the shared ball motion skip")
	_expect(not shield_state.is_movement_locked(), "Shield Kiting wind-up should tick and release movement during Hongryun ball hijack")
	_expect(str(shield_state.projectile.get("state", "")) != SmasherShieldKitingState.STATE_WIND_UP, "Shield Kiting should not wait for Hongryun inferno to end before launching")


func _base_context() -> Dictionary:
	return {
		"current_stage": 5,
		"selected_character_type": "smasher",
		"ball_active": true,
		"waiting_for_serve": false,
		"ball_pos": Vector2(120.0, 220.0),
		"ball_vel": Vector2(0.0, 8.0),
		"ball_size": 28.6,
		"skip_ball_motion_step": true,
		"ball_impact_boost": 1.0,
		"ball_boost_decay_rate": 0.975,
		"ball_min_boost": 0.70,
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
		"vertical_bounce_count": 0,
		"ball_spin_strength": 0.0,
		"ball_spin_direction": 0,
		"drive_ball_active": false,
		"drive_hit_boss": false,
		"drive_speed_increase": 0.0,
		"drive_text_timer_frames": 0.0,
		"special_gauge": 500.0,
		"player_speed": 0.0,
		"player_pos": Vector2(302.5, 690.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"paddle_width": 155.0,
		"paddle_height": 50.0,
	}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
