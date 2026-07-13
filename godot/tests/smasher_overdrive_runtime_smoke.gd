extends SceneTree

const BallFrameMotionController := preload("res://scripts/ball/ball_frame_motion_controller.gd")
const BallMotionEventProcessor := preload("res://scripts/ball/ball_motion_event_processor.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const SmasherOverdriveState := preload("res://scripts/characters/smasher_overdrive_state.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const SmasherSkillState := preload("res://scripts/characters/smasher_skill_state.gd")

var _failed := false


class FakeSkillState:
	var triggered_skill := ""
	var triggered_cooldown := 0.0

	func get_configured_cooldown_remaining(_skill_name: String, _current_msec: int, _skill_config: Object) -> float:
		return 0.0

	func trigger_configured_cooldown(skill_name: String, _current_msec: int, skill_config: Object) -> void:
		triggered_skill = skill_name
		triggered_cooldown = float(skill_config.get_cooldown_seconds(skill_name))


class FakeBallPhysics:
	pass


class FakeActiveState:
	var active := true

	func is_active() -> bool:
		return active


class FakeHolyBarrierMotionStepper:
	func step(ball_pos: Vector2, _effective_motion: Vector2, _ball_vel: Vector2, _context: Dictionary) -> Dictionary:
		return {
			"event": "holy_barrier",
			"ball_pos": ball_pos,
			"impact_pos": ball_pos,
		}


func _init() -> void:
	var config := SmasherSkillConfig.new()
	_expect(is_equal_approx(config.get_skill_cost("smasher_overdrive"), 280.0), "overdrive cost should be 280")
	_expect(is_equal_approx(config.get_cooldown_seconds("smasher_overdrive"), 28.0), "overdrive cooldown should be 28 seconds")
	_expect(config.unlock_and_equip_skill("smasher_overdrive"), "overdrive should use the normal active-skill equip path")
	var perk: Dictionary = RuntimePerkCatalog.new().get_perk_data("unlock_smasher_overdrive")
	_expect(str(perk.get("unlocks_skill", "")) == "smasher_overdrive", "unlock id should map to the collision-safe runtime id")

	var state := SmasherOverdriveState.new()
	var cooldown := FakeSkillState.new()
	var deps := {"skill_config": config, "skill_state": cooldown}
	var player_config := {
		"ball_active": true,
		"ball_vel": Vector2(8.0, -6.0),
		"player_skill_input_locked": false,
	}
	var activation: Dictionary = state.update_input(
		{"down_pressed": true, "secondary_action_just_pressed": true},
		1000,
		300.0,
		Vector2.ZERO,
		player_config,
		deps
	)
	_expect(bool(activation.get("activated", false)), "down + right-click edge should activate overdrive")
	_expect(is_equal_approx(float(activation.get("special_gauge", 0.0)), 20.0), "activation should spend exactly 280 gauge")
	_expect(cooldown.triggered_skill == "smasher_overdrive" and is_equal_approx(cooldown.triggered_cooldown, 28.0), "shared cooldown should receive the final configured cooldown")

	var first_motion: Dictionary = state.apply_ball_motion(Vector2(100.0, 200.0), Vector2(8.0, -6.0))
	_expect(not first_motion.has("skip_ball_motion_step"), "overdrive must not take ownership of the normal ball motion step")
	var boosted_vel: Vector2 = first_motion.get("ball_vel", Vector2.ZERO)
	_expect(is_equal_approx(boosted_vel.length(), 13.0), "speed boost should apply once at +30 percent")
	var second_motion: Dictionary = state.apply_ball_motion(Vector2(101.0, 199.0), boosted_vel)
	_expect(is_equal_approx(_vec(second_motion, "ball_vel").length(), 13.0), "speed boost must not compound every frame")
	var decayed_motion: Dictionary = state.apply_ball_motion(Vector2(102.0, 198.0), Vector2(7.2, -5.4))
	_expect(is_equal_approx(_vec(decayed_motion, "ball_vel").length(), 13.0), "the flat speed bonus should remain in force for the active window")

	for frame in 12:
		state.update_input({}, 1001 + frame, 20.0, Vector2.ZERO, player_config, deps)
	var kink_motion: Dictionary = state.apply_ball_motion(Vector2(120.0, 180.0), boosted_vel)
	var kink_vel := _vec(kink_motion, "ball_vel")
	_expect(int(state.get_snapshot().get("kink_serial", 0)) == 1, "12 gameplay frames should schedule exactly one kink")
	_expect(absf(kink_vel.normalized().y) >= sin(deg_to_rad(25.0)) - 0.001, "kink should preserve the shared minimum vertical angle")

	state.notify_ball_reflected(Vector2(-5.0, 9.0), Vector2(0.0, 300.0))
	_expect(_vec(state.get_snapshot(), "base_heading").dot(Vector2(-5.0, 9.0).normalized()) > 0.999, "ordinary bounce should refresh the base heading")
	for event_name in [
		"wall", "sand_terrain", "brick_wall", "trampoline", "horn_strawberry_field",
		"lingpet_bone_barrier", "holy_barrier", "adversity_armor", "player_paddle", "boss_paddle",
	]:
		_expect(BallMotionEventProcessor.OVERDRIVE_REFLECTION_EVENTS.has(event_name), "%s should be sealed as an overdrive reflection event" % event_name)

	var holy_state := SmasherOverdriveState.new()
	var holy_config: Dictionary = player_config.duplicate(true)
	holy_config["ball_vel"] = Vector2(4.0, 8.0)
	holy_state.update_input(
		{"down_pressed": true, "secondary_action_just_pressed": true}, 1500, 300.0, Vector2.ZERO, holy_config, deps
	)
	holy_state.apply_ball_motion(Vector2(300.0, 680.0), Vector2(4.0, 8.0))
	var holy_scene := {
		"ball_pos": Vector2(300.0, 680.0),
		"ball_vel": Vector2(4.0, 8.0),
		"ball_impact_boost": 1.0,
	}
	BallMotionEventProcessor.new().step_motion(
		holy_scene,
		1.0,
		{"ball_size": 28.6, "selected_character_type": "smasher"},
		{"motion_stepper": FakeHolyBarrierMotionStepper.new(), "smasher_overdrive_state": holy_state},
		{}
	)
	_expect(_vec(holy_state.get_snapshot(), "base_heading").y < 0.0, "holy barrier should refresh base heading to the reflected upward direction")
	for frame in 12:
		holy_state.update_input({}, 1501 + frame, 20.0, Vector2.ZERO, holy_config, deps)
	var post_holy_kink: Vector2 = _vec(
		holy_state.apply_ball_motion(_vec(holy_scene, "ball_pos"), _vec(holy_scene, "ball_vel")),
		"ball_vel"
	)
	_expect(post_holy_kink.y < 0.0, "the first kink after a holy-barrier save must preserve upward travel")

	var motion_controller := BallFrameMotionController.new()
	var scene := {"ball_vel": Vector2(40.0, 0.0), "max_ball_speed": 26.0, "ball_impact_boost": 1.0}
	motion_controller.apply_ball_speed_limits(scene, {"ball_physics": FakeBallPhysics.new(), "smasher_overdrive_state": state})
	_expect(is_equal_approx(_vec(scene, "ball_vel").length(), 30.0), "active overdrive should open only the capped speed-30 window")
	scene["ball_vel"] = Vector2(40.0, 0.0)
	scene["ball_impact_boost"] = 2.0
	motion_controller.apply_ball_speed_limits(scene, {"ball_physics": FakeBallPhysics.new(), "smasher_overdrive_state": state})
	_expect(is_equal_approx(_vec(scene, "ball_vel").length(), 15.0), "speed 30 cap should apply to effective speed when impact boost is active")
	state.reset_round()
	scene["ball_vel"] = Vector2(40.0, 0.0)
	scene["ball_impact_boost"] = 1.0
	motion_controller.apply_ball_speed_limits(scene, {"ball_physics": FakeBallPhysics.new(), "smasher_overdrive_state": state})
	_expect(is_equal_approx(_vec(scene, "ball_vel").length(), 26.0), "teardown should self-heal to the normal cap")
	_expect(not state.is_active() and int(state.get_snapshot().get("smasher_overdrive_remaining_frames", -1)) == 0, "round reset should clear all active duration state")

	var duration_state := SmasherOverdriveState.new()
	duration_state.update_input(
		{"down_pressed": true, "secondary_action_just_pressed": true}, 2000, 300.0, Vector2.ZERO, player_config, deps
	)
	var locked_config: Dictionary = player_config.duplicate(true)
	locked_config["player_skill_input_locked"] = true
	duration_state.update_input({}, 2001, 20.0, Vector2.ZERO, locked_config, deps)
	_expect(int(duration_state.get_snapshot().get("smasher_overdrive_remaining_frames", 0)) == 360, "temporary skill locks should pause instead of canceling or consuming overdrive")
	for frame in 359:
		duration_state.update_input({}, 2001 + frame, 20.0, Vector2.ZERO, player_config, deps)
	_expect(duration_state.is_active() and int(duration_state.get_snapshot().get("smasher_overdrive_remaining_frames", 0)) == 1, "duration should remain active for exactly 359 gameplay ticks at 72 Hz")
	var paused_remaining := int(duration_state.get_snapshot().get("smasher_overdrive_remaining_frames", 0))
	# Modal/tooltip frames do not call the player controller, so no wall-clock
	# method exists here that can consume the remaining gameplay frame.
	_expect(int(duration_state.get_snapshot().get("smasher_overdrive_remaining_frames", 0)) == paused_remaining, "a modal pause should not consume frame-based duration")
	duration_state.update_input({}, 999999, 20.0, Vector2.ZERO, player_config, deps)
	_expect(not duration_state.is_active(), "the 360th gameplay tick should expire the five-second window")

	var conflict_state := SmasherOverdriveState.new()
	var conflict_deps: Dictionary = deps.duplicate()
	conflict_deps["smasher_magnum_grip_state"] = FakeActiveState.new()
	var conflict_result: Dictionary = conflict_state.update_input(
		{"down_pressed": true, "secondary_action_just_pressed": true}, 3000, 300.0, Vector2.ZERO, player_config, conflict_deps
	)
	_expect(not bool(conflict_result.get("activated", false)), "overdrive should not activate while Magnum Grip owns continuous ball steering")

	var reduced_config := SmasherSkillConfig.new()
	reduced_config.set_runtime_cooldown_multiplier(0.5)
	_expect(reduced_config.unlock_and_equip_skill("smasher_overdrive"), "reduced-cooldown fixture should equip overdrive")
	var reduced_skill_state := SmasherSkillState.new()
	var reduced_state := SmasherOverdriveState.new()
	reduced_state.update_input(
		{"down_pressed": true, "secondary_action_just_pressed": true},
		4000,
		300.0,
		Vector2.ZERO,
		player_config,
		{"skill_config": reduced_config, "skill_state": reduced_skill_state}
	)
	_expect(is_equal_approx(reduced_skill_state.get_cooldown_total_seconds("smasher_overdrive"), 14.0), "activation should store the final reduced cooldown used by HUD ratios")
	_expect(is_equal_approx(float(reduced_config.get_snapshot().get("cooldown_seconds", {}).get("smasher_overdrive", 0.0)), 14.0), "orb wedge config should expose the same final cooldown")
	_expect(is_equal_approx(float(reduced_config.get_skill_data("smasher_overdrive").get("cooldown", 0.0)), 14.0), "tooltip data should expose the same final cooldown")
	_expect(is_equal_approx(reduced_skill_state.get_configured_cooldown_remaining("smasher_overdrive", 11000, reduced_config), 0.5), "HUD remaining ratio should be half after seven of fourteen seconds")

	if _failed:
		quit(1)
		return
	print("smasher_overdrive_runtime_smoke: ok")
	quit(0)


func _vec(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	return value if value is Vector2 else Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
