extends SceneTree

# Regression seal (2026-07-05): when Viper has BOTH Dark Blade and Venom Edge
# equipped, the Air Blade phase-2 follow-up window is normally owned by Dark
# Blade (Air Blade -> Dark Blade -> Venom Edge). If Dark Blade is on cooldown,
# the follow-up must NOT silently drop -- Venom Edge fires directly from Air
# Blade instead (Air Blade -> Venom Edge). See
# ViperSkillBladeMotionRuntime.try_phase2_followup_activation.

const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")


class FakeInput:
	var snapshot := {
		"left_pressed": false,
		"right_pressed": false,
		"up_pressed": false,
		"down_pressed": false,
		"direction": 0.0,
	}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeJetpackState:
	var airborne := true

	func is_airborne(_threshold: float = 0.0) -> bool:
		return airborne


class FakeSkillConfig:
	# Full chain equipped: Air Blade + Dark Blade + Venom Edge (nerve_strike).
	func is_skill_equipped(skill_name: String) -> bool:
		return skill_name in ["shadow_step", "marshal_kick", "blade_rush", "dark_blade", "nerve_strike"]

	func get_skill_cost(skill_name: String) -> float:
		match skill_name:
			"blade_rush":
				return 200.0
			"dark_blade":
				return 150.0
			"nerve_strike":
				return 90.0
			"shadow_step":
				return 100.0
			"marshal_kick":
				return 80.0
		return 0.0


class FakeSkillState:
	# Per-skill remaining cooldown in seconds; 0.0 == ready.
	var cooldowns := {}

	func trigger_configured_cooldown(_skill_name: String, _now_msec: int, _skill_config: Object) -> void:
		pass

	func get_configured_cooldown_remaining(skill_name: String, _now_msec: int, _skill_config: Object) -> float:
		return float(cooldowns.get(skill_name, 0.0))


class FakeAudio:
	func play_viper_blade_spin() -> void:
		pass

	func play_nerve_strike_moving_sound() -> void:
		pass


class FakeFeedback:
	func max_screen_shake(_duration: float, _amount: float) -> void:
		pass


class FakeOrbHud:
	func trigger_gauge_spin(_now_msec: int) -> void:
		pass


class FakePerkState:
	func get_runtime_skill_level(_skill_id: String) -> int:
		return 0

	func award_gold(amount: int) -> int:
		return max(0, amount)


func _init() -> void:
	_test_dark_blade_on_cooldown_falls_back_to_venom_edge()
	_test_dark_blade_ready_still_chains_dark_blade()
	_test_both_follow_ups_on_cooldown_fire_nothing()
	print("viper_air_blade_venom_edge_fallback_smoke: ok")
	quit(0)


# Dark Blade on cooldown, Venom Edge ready -> Air Blade should chain into Venom Edge.
func _test_dark_blade_on_cooldown_falls_back_to_venom_edge() -> void:
	var setup: Dictionary = _make_air_blade_phase2_case({"dark_blade": 300.0})
	var result: Dictionary = _press_up_followup(setup)
	_expect(bool(result.get("activated", false)), "Air Blade follow-up should activate Venom Edge when Dark Blade is on cooldown")
	_expect(str(result.get("skill_name", "")) == "nerve_strike", "cooldown fallback should fire nerve_strike (Venom Edge), got '%s'" % str(result.get("skill_name", "")))
	var runtime: Object = setup.get("runtime", null)
	_expect(bool(runtime.nerve_strike_active), "Venom Edge fallback should enter the nerve strike runtime")
	_expect(not bool(runtime.blade_dark_mode), "Venom Edge fallback must NOT enter Dark Blade motion")


# Dark Blade ready -> existing behavior preserved: Air Blade chains into Dark Blade.
func _test_dark_blade_ready_still_chains_dark_blade() -> void:
	var setup: Dictionary = _make_air_blade_phase2_case({})
	var result: Dictionary = _press_up_followup(setup)
	_expect(bool(result.get("activated", false)), "Air Blade follow-up should activate Dark Blade when it is ready")
	_expect(str(result.get("skill_name", "")) == "dark_blade", "ready path should fire dark_blade, got '%s'" % str(result.get("skill_name", "")))
	var runtime: Object = setup.get("runtime", null)
	_expect(bool(runtime.blade_dark_mode), "Dark Blade chain should enter dark blade motion")
	_expect(not bool(runtime.nerve_strike_active), "Dark Blade chain must not start Venom Edge directly")


# Dark Blade AND Venom Edge both on cooldown -> nothing new fires (no false Venom Edge).
func _test_both_follow_ups_on_cooldown_fire_nothing() -> void:
	var setup: Dictionary = _make_air_blade_phase2_case({"dark_blade": 300.0, "nerve_strike": 300.0})
	var result: Dictionary = _press_up_followup(setup)
	_expect(not bool(result.get("activated", false)), "no follow-up should activate when both Dark Blade and Venom Edge are on cooldown")
	var runtime: Object = setup.get("runtime", null)
	_expect(not bool(runtime.nerve_strike_active), "Venom Edge must not fire while it is on cooldown")
	_expect(not bool(runtime.blade_dark_mode), "Dark Blade must not fire while it is on cooldown")


# Starts Air Blade airborne and advances the motion into the phase-2 follow-up
# window (total frames in [66, 102)), with up released so no edge is consumed.
func _make_air_blade_phase2_case(cooldowns: Dictionary) -> Dictionary:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var jetpack := FakeJetpackState.new()
	var skill_state := FakeSkillState.new()
	skill_state.cooldowns = cooldowns.duplicate()
	var deps := {
		"input_reader": input,
		"skill_config": FakeSkillConfig.new(),
		"skill_state": skill_state,
		"audio": FakeAudio.new(),
		"feedback": FakeFeedback.new(),
		"orb_hud_state": FakeOrbHud.new(),
		"runtime_perk_state": FakePerkState.new(),
		"viper_jetpack_state": jetpack,
	}
	var config := {
		"selected_character_type": "viper",
		"ball_active": true,
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"player_floor_y": 680.0,
		"ball_size": 28.6,
		"boss_pos": Vector2(380.0, 45.0),
		"boss_paddle_width": 100.0,
		"ball_pos": Vector2(640.0, 350.0),
		"ball_vel": Vector2(0.0, -8.0),
		"ball_impact_boost": 1.0,
	}
	var player_pos := Vector2(302.5, 560.0)
	var gauge := 500.0

	# Frame 0: fresh up edge starts Air Blade (blade_rush, non-dark).
	input.snapshot["up_pressed"] = true
	var start_result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
	_expect(bool(start_result.get("activated", false)), "setup should activate Air Blade from the airborne up press")
	_expect(str(start_result.get("skill_name", "")) == "blade_rush", "setup should start blade_rush (Air Blade), got '%s'" % str(start_result.get("skill_name", "")))
	_expect(not bool(runtime.blade_dark_mode), "Air Blade setup must start in non-dark mode")
	player_pos = _get_vector2(start_result, "player_pos", player_pos)
	gauge = float(start_result.get("special_gauge", gauge))

	# Release up and advance the blade motion into the phase-2 window.
	input.snapshot["up_pressed"] = false
	for _i in range(70):
		var tick_result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
		player_pos = _get_vector2(tick_result, "player_pos", player_pos)
		gauge = float(tick_result.get("special_gauge", gauge))
	_expect(int(runtime.blade_motion_phase) == 2, "Air Blade should reach phase 2 before the follow-up window, phase=%d" % int(runtime.blade_motion_phase))
	_expect(runtime.blade_motion_total_frames >= 66.0 and runtime.blade_motion_total_frames < 102.0, "Air Blade should sit inside the [66,102) follow-up window, total=%f" % runtime.blade_motion_total_frames)
	_expect(bool(runtime.blade_motion_active), "Air Blade motion should still be active in the follow-up window")

	return {
		"runtime": runtime,
		"input": input,
		"deps": deps,
		"config": config,
		"player_pos": player_pos,
		"gauge": gauge,
	}


func _press_up_followup(setup: Dictionary) -> Dictionary:
	var runtime: Object = setup.get("runtime", null)
	var input: Object = setup.get("input", null)
	var deps: Dictionary = setup.get("deps", {})
	var config: Dictionary = setup.get("config", {})
	var player_pos: Vector2 = _get_vector2(setup, "player_pos", Vector2.ZERO)
	var gauge: float = float(setup.get("gauge", 0.0))
	input.snapshot["up_pressed"] = true
	return runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
