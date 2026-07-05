extends SceneTree

const BallRoundState := preload("res://scripts/ball/ball_round_state.gd")
const Stage1GaksitalBossSkillCooldownState := preload("res://scripts/stages/stage1/stage1_gaksital_boss_skill_cooldown_state.gd")
const Stage1GaksitalFanWindSkillState := preload("res://scripts/stages/stage1/stage1_gaksital_fan_wind_skill_state.gd")
const ViperSkillChaosSpearBallMotionRuntime := preload("res://scripts/characters/viper_skill_chaos_spear_ball_motion_runtime.gd")

var _failures: Array[String] = []


class FakeAudio:
	extends RefCounted

	var fan_volumes: Array[float] = []

	func play_gaksital_fan(volume: float = 0.35) -> void:
		fan_volumes.append(volume)


func _init() -> void:
	_verify_on_hit_consumes_ready_cooldown_and_charges()
	_verify_charge_becomes_active_after_sixty_frames()
	_verify_capture_owns_and_moves_ball()
	_verify_capture_release_restores_normal_motion()
	_verify_expiry_release_restores_normal_motion()
	_verify_existing_ball_owner_blocks_capture()
	_verify_round_reset_and_common_snapshot_clear_skip()
	_verify_chaos_absorb_protocol_outcomes()
	_verify_chaos_absorb_collector_reaches_fan_wind()
	_verify_fan_wind_draw_not_gated_by_fan_list()
	_verify_runtime_wiring_contracts()

	if _failures.is_empty():
		print("stage1_gaksital_fan_wind_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_on_hit_consumes_ready_cooldown_and_charges() -> void:
	var cooldown: Object = Stage1GaksitalBossSkillCooldownState.new()
	var state: Object = Stage1GaksitalFanWindSkillState.new()
	var context: Dictionary = _base_context()
	context["ball_active"] = true
	cooldown.update(1200.0, context, {
		"stage1_gaksital_fan_wind_skill_state": state,
	})
	_expect(bool(cooldown.is_ready("fan_wind")), "fan wind cooldown should become ready after 1200f")
	var audio := FakeAudio.new()
	var consumed: bool = bool(state.try_consume_boss_hit(context, {
		"stage1_gaksital_boss_skill_cooldown_state": cooldown,
		"audio": audio,
	}))
	_expect(consumed, "ready fan wind should consume on boss hit")
	_expect(not bool(cooldown.is_ready("fan_wind")), "fan wind cooldown should reset after on-hit consumption")
	var draw_context: Dictionary = state.get_draw_context()
	_expect(bool(draw_context.get("stage1_fan_wind_charging", false)), "fan wind should enter charging after the boss-hit trigger")
	_expect(audio.fan_volumes.size() == 1, "fan wind charge should play the shared Gaksital fan cue once")


func _verify_charge_becomes_active_after_sixty_frames() -> void:
	var state: Object = Stage1GaksitalFanWindSkillState.new()
	_force_charge(state)
	state.update_and_collide(59.0, {}, _base_context(), {})
	_expect(bool(state.get_draw_context().get("stage1_fan_wind_charging", false)), "fan wind should still charge before 60f")
	state.update_and_collide(1.0, {}, _base_context(), {})
	var draw_context: Dictionary = state.get_draw_context()
	_expect(not bool(draw_context.get("stage1_fan_wind_charging", true)), "fan wind charge should finish at 60f")
	_expect(bool(draw_context.get("stage1_fan_wind_active", false)), "fan wind should become active after charging")
	_expect(is_equal_approx(float(draw_context.get("stage1_fan_wind_growth_scale", 0.0)), 1.0), "fan wind growth should reach full scale after charging")


func _verify_capture_owns_and_moves_ball() -> void:
	var state: Object = Stage1GaksitalFanWindSkillState.new()
	_force_active(state, Vector2(320.0, 140.0))
	var scene := {
		"ball_pos": Vector2(330.0, 140.6),
		"ball_vel": Vector2(7.0, 3.0),
		"skip_ball_motion_step": false,
	}
	var result: Dictionary = state.update_and_collide(1.0, scene, _base_context(), {})
	_expect(bool(result.get("skip_ball_motion_step", false)), "fan wind capture should own the shared ball motion step")
	_expect(bool(result.get("stage1_gaksital_fan_wind_captured", false)), "fan wind capture should report captured")
	_expect(_get_vector2(result, "ball_vel", Vector2.ONE) == Vector2.ZERO, "captured fan wind ball should hold zero velocity")
	var first_pos: Vector2 = _get_vector2(result, "ball_pos", Vector2.ZERO)
	scene.merge(result, true)
	var followup: Dictionary = state.update_and_collide(1.0, scene, _base_context(), {})
	var second_pos: Vector2 = _get_vector2(followup, "ball_pos", first_pos)
	_expect(first_pos.distance_to(second_pos) > 0.01, "captured fan wind ball should visibly orbit between frames")


func _verify_capture_release_restores_normal_motion() -> void:
	var state: Object = Stage1GaksitalFanWindSkillState.new()
	_force_captured(state, Vector2(300.0, 160.0))
	state.capture_timer = 1.0
	state.rng.seed = 7
	var result: Dictionary = state.update_and_collide(1.0, {
		"ball_pos": Vector2(308.0, 160.0),
		"skip_ball_motion_step": true,
	}, _base_context(), {})
	var velocity: Vector2 = _get_vector2(result, "ball_vel", Vector2.ZERO)
	_expect(bool(result.get("stage1_gaksital_fan_wind_released", false)), "fan wind should report normal capture release")
	_expect(not bool(result.get("skip_ball_motion_step", true)), "normal fan wind release must clear motion skip")
	_expect(velocity.length() >= 12.0 and velocity.length() <= 17.0, "normal fan wind release speed should stay in the Python band")
	_expect(velocity.y > 0.0, "normal fan wind release should force the ball downward")
	_expect(not bool(state.is_active()), "fan wind state should clear after normal release")


func _verify_expiry_release_restores_normal_motion() -> void:
	var state: Object = Stage1GaksitalFanWindSkillState.new()
	_force_captured(state, Vector2(300.0, 160.0))
	state.timer_frames = 1.0
	state.rng.seed = 11
	var result: Dictionary = state.update_and_collide(1.0, {
		"ball_pos": Vector2(306.0, 160.0),
		"skip_ball_motion_step": true,
	}, _base_context(), {})
	var velocity: Vector2 = _get_vector2(result, "ball_vel", Vector2.ZERO)
	_expect(bool(result.get("stage1_gaksital_fan_wind_expired_release", false)), "fan wind expiry should report expiry release")
	_expect(not bool(result.get("skip_ball_motion_step", true)), "expiry fan wind release must clear motion skip")
	_expect(is_equal_approx(velocity.length(), 13.0), "expiry fan wind release speed should match the Python 13px/f contract")
	_expect(velocity.y > 0.0, "expiry fan wind release should force the ball downward")


func _verify_existing_ball_owner_blocks_capture() -> void:
	var state: Object = Stage1GaksitalFanWindSkillState.new()
	_force_active(state, Vector2(320.0, 140.0))
	var result: Dictionary = state.update_and_collide(1.0, {
		"ball_pos": Vector2(322.0, 140.6),
		"ball_vel": Vector2(5.0, 2.0),
		"skip_ball_motion_step": true,
	}, _base_context(), {})
	_expect(result.is_empty(), "fan wind should not return a capture result while another owner has skip_ball_motion_step")
	_expect(not bool(state.is_ball_captured()), "fan wind should not steal a ball from an existing owner")


func _verify_round_reset_and_common_snapshot_clear_skip() -> void:
	var state: Object = Stage1GaksitalFanWindSkillState.new()
	_force_captured(state, Vector2(300.0, 160.0))
	state.reset_round()
	_expect(not bool(state.is_active()), "fan wind reset_round should clear active/captured state")
	var snapshot: Dictionary = BallRoundState.new().build_common_snapshot()
	_expect(not bool(snapshot.get("skip_ball_motion_step", true)), "round common snapshot should normalize fan wind motion skip")


func _verify_chaos_absorb_protocol_outcomes() -> void:
	var state: Object = Stage1GaksitalFanWindSkillState.new()
	_force_active(state, Vector2(320.0, 140.0))
	var absorbed: Array = state.absorb_chaos_spear_objects(Vector2(330.0, 150.0), 175.0)
	_expect(absorbed.size() == 1, "chaos absorb should eat an active vortex within pull radius")
	_expect(not bool(state.is_active()), "chaos absorb should clear the absorbed vortex state")

	var far_state: Object = Stage1GaksitalFanWindSkillState.new()
	_force_active(far_state, Vector2(320.0, 140.0))
	var far_absorbed: Array = far_state.absorb_chaos_spear_objects(Vector2(700.0, 700.0), 175.0)
	_expect(far_absorbed.is_empty(), "chaos absorb should skip a vortex outside pull radius")
	_expect(bool(far_state.is_active()), "out-of-radius vortex must stay alive")

	var captured_state: Object = Stage1GaksitalFanWindSkillState.new()
	_force_captured(captured_state, Vector2(320.0, 140.0))
	var captured_absorbed: Array = captured_state.absorb_chaos_spear_objects(Vector2(320.0, 140.0), 175.0)
	_expect(captured_absorbed.is_empty(), "chaos absorb must skip a ball-owning (captured) vortex this poll")
	_expect(bool(captured_state.is_ball_captured()), "captured vortex must keep ball ownership through the skipped poll")


func _verify_chaos_absorb_collector_reaches_fan_wind() -> void:
	var state: Object = Stage1GaksitalFanWindSkillState.new()
	_force_active(state, Vector2(320.0, 140.0))
	var absorbed: Array = ViperSkillChaosSpearBallMotionRuntime._collect_absorbed_objects(
		Vector2(330.0, 150.0),
		{"stage1_gaksital_fan_wind_skill_state": state},
		175.0
	)
	_expect(absorbed.size() == 1, "chaos spear absorb collector should poll the gaksital fan wind vortex")
	_expect(not bool(state.is_active()), "collector absorb should clear the fan wind state through the real path")


func _verify_fan_wind_draw_not_gated_by_fan_list() -> void:
	var renderer_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_gaksital_fan_throw_renderer.gd")
	_expect(renderer_source.find("\n\t_draw_fan_wind(") >= 0, "renderer draw() must call _draw_fan_wind at top level (not inside the fan loop)")
	_expect(renderer_source.find("\n\t\t_draw_fan_wind(") < 0, "renderer _draw_fan_wind call must not be nested inside a loop/branch")
	_expect(renderer_source.find("\n\t_draw_hit_effect(") >= 0, "renderer draw() must call _draw_hit_effect at top level (not inside the fan loop)")
	_expect(renderer_source.find("\n\t\t_draw_hit_effect(") < 0, "renderer _draw_hit_effect call must not be nested inside a loop/branch")


func _verify_runtime_wiring_contracts() -> void:
	var controller_source := FileAccess.get_file_as_string("res://scripts/ball/ball_update_controller.gd")
	var fan_wind_call := controller_source.find("apply_stage1_gaksital_fan_wind")
	var first_skip_gate := controller_source.find("if bool(scene.get(\"skip_ball_motion_step\", false)):")
	_expect(fan_wind_call >= 0, "ball update controller should tick Gaksital fan wind")
	_expect(first_skip_gate >= 0 and fan_wind_call < first_skip_gate, "fan wind must tick before the first shared skip gate")
	var post_hit_source := FileAccess.get_file_as_string("res://scripts/ball/paddle_bounce_boss_post_hit_handler.gd")
	_expect(post_hit_source.find("try_consume_boss_hit") >= 0, "boss post-hit handler should trigger fan wind through the on-hit contract")
	var frame_source := FileAccess.get_file_as_string("res://scripts/ball/ball_frame_motion_controller.gd")
	_expect(frame_source.find("stage1_gaksital_fan_wind_released") >= 0, "frame motion controller should merge fan wind release results")


func _force_charge(state: Object) -> void:
	var cooldown: Object = Stage1GaksitalBossSkillCooldownState.new()
	var context: Dictionary = _base_context()
	context["ball_active"] = true
	cooldown.update(1200.0, context, {})
	state.try_consume_boss_hit(context, {"stage1_gaksital_boss_skill_cooldown_state": cooldown})


func _force_active(state: Object, pos: Vector2) -> void:
	state.active = true
	state.charging = false
	state.captured = false
	state.timer_frames = Stage1GaksitalFanWindSkillState.DURATION_FRAMES
	state.vortex_pos = pos
	state.drift_vx = 0.0
	state.drift_reroll_timer = 999.0
	state.growth_scale = 1.0


func _force_captured(state: Object, pos: Vector2) -> void:
	_force_active(state, pos)
	state.captured = true
	state.capture_timer = Stage1GaksitalFanWindSkillState.CAPTURE_DURATION_FRAMES
	state.capture_radius = 8.0
	state.capture_angle = 0.0


func _base_context() -> Dictionary:
	return {
		"current_stage": 1,
		"stage1_boss_variant": "gaksi",
		"boss_pos": Vector2(330.0, 70.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_hitbox_height": 40.0,
		"ball_active": true,
		"ball_pos": Vector2(380.0, 140.0),
	}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
