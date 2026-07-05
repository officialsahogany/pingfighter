extends SceneTree

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const CommandoFirearmBowlingTrapGeometry := preload("res://scripts/characters/commando_firearm_bowling_trap_geometry.gd")
const CommandoFirearmBowlingTrapGuardState := preload("res://scripts/characters/commando_firearm_bowling_trap_guard_state.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const StatusEffectState := preload("res://scripts/status/status_effect_state.gd")
const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")

var _failures: Array[String] = []


class FakeStage2SkillState:
	extends RefCounted

	var immune := false

	func is_boss_status_immune() -> bool:
		return immune


class FakeRegistry:
	extends RefCounted

	var stage2_boss_skill_state: Object = null

	func get_instance(key: String) -> Object:
		if key == "stage2_boss_skill_state":
			return stage2_boss_skill_state
		return null


class FakeShotCounter:
	extends RefCounted

	var shot_serial := 0


class FakeRuntimeOwner:
	extends RefCounted

	var bowling_trap_guard_armed := false
	var bowling_trap_guard_original_speed := 0.0
	var bowling_trap_guard_restore_speed := 0.0
	var bowling_trap_guard_source := ""
	var lingering_calls: Array = []

	func _spawn_lingering_effect(weapon_id: String, projectile: Dictionary, context: Dictionary) -> Dictionary:
		lingering_calls.append({
			"weapon_id": weapon_id,
			"projectile": projectile,
			"context": context,
		})
		return {"source": "fake_lingering"}


class FakeFeedback:
	extends RefCounted

	var calls: Array = []

	func max_screen_shake(amount: float, intensity: float) -> void:
		calls.append({"amount": amount, "intensity": intensity})


class FakeBallEffects:
	extends RefCounted

	var pulses: Array = []

	func register_hit_pulse(pos: Vector2, velocity: Vector2, intensity: float, kind: String) -> void:
		pulses.append({
			"pos": pos,
			"velocity": velocity,
			"intensity": intensity,
			"kind": kind,
		})


class FakeAudio:
	extends RefCounted

	var snap_calls := 0

	func play_commando_bowling_trap_snap() -> void:
		snap_calls += 1


func _init() -> void:
	_verify_direct_bowling_trap_geometry()
	_verify_direct_bowling_trap_guard_state()
	_verify_runtime_delegates_bowling_trap_geometry()
	_verify_removed_runtime_bowling_trap_geometry_bridges()
	_verify_bowling_trap_guard_knockback_stays_bounded()

	if _failures.is_empty():
		print("commando_firearm_bowling_trap_geometry_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_bowling_trap_geometry() -> void:
	var guard_knockback_power: float = CommandoFirearmRuntime.BOWLING_TRAP_GUARD_KNOCKBACK_POWER
	var guard_stun_frames: float = CommandoFirearmRuntime.BOWLING_TRAP_GUARD_STUN_FRAMES
	_expect(
		CommandoFirearmBowlingTrapGeometry.get_install_pos({}, 760.0, 750.0, 60.0, 20.0, 0.6) == Vector2(457.5, 735.0),
		"bowling-trap default install position should preserve legacy fallback geometry"
	)
	_expect(
		CommandoFirearmBowlingTrapGeometry.get_install_pos(
			{"player_pos": Vector2(10.0, 100.0), "paddle_width": 10.0, "paddle_height": 10.0},
			760.0,
			750.0,
			60.0,
			20.0,
			0.6
		) == Vector2(30.0, 450.0),
		"bowling-trap install position should clamp to field and minimum install row"
	)
	_expect(
		CommandoFirearmBowlingTrapGeometry.is_install_in_player_field(
			{"player_pos": Vector2(380.0, 690.0), "paddle_height": 50.0},
			760.0,
			750.0,
			0.6
		),
		"bowling-trap install field helper should accept lower-field installs"
	)
	_expect(
		not CommandoFirearmBowlingTrapGeometry.is_install_in_player_field(
			{"player_pos": Vector2(380.0, 100.0), "paddle_height": 50.0},
			760.0,
			750.0,
			0.6
		),
		"bowling-trap install field helper should reject upper-field installs"
	)

	_expect(
		CommandoFirearmBowlingTrapGeometry.soften_guard_ball(Vector2.ZERO, 8.0) == Vector2(0.0, 8.0),
		"zero guard velocity should restore downward speed"
	)
	_expect(
		CommandoFirearmBowlingTrapGeometry.soften_guard_ball(Vector2(3.0, 4.0), 10.0) == Vector2(6.0, 8.0),
		"nonzero guard velocity should preserve direction and restore target speed"
	)

	_expect(
		is_equal_approx(
			CommandoFirearmBowlingTrapGeometry.get_guard_knockback_velocity(Vector2(200.0, 0.0), {}, 760.0, guard_knockback_power),
			guard_knockback_power
		),
		"left-side boss guard hit should knock right"
	)
	_expect(
		is_equal_approx(
			CommandoFirearmBowlingTrapGeometry.get_guard_knockback_velocity(Vector2(500.0, 0.0), {}, 760.0, guard_knockback_power),
			-guard_knockback_power
		),
		"right-side boss guard hit should knock left"
	)
	_expect(
		is_equal_approx(
			CommandoFirearmBowlingTrapGeometry.get_guard_knockback_velocity(Vector2(380.0, 0.0), {"boss_vel": -3.0}, 760.0, guard_knockback_power),
			-guard_knockback_power
		),
		"center boss guard hit should follow current boss velocity when available"
	)
	# Launch fan: a continuous random +/-40 deg spread around vertical (toward the boss).
	var fan_half_angle: float = CommandoFirearmRuntime.BOWLING_TRAP_LAUNCH_FAN_HALF_ANGLE
	_expect(is_equal_approx(fan_half_angle, deg_to_rad(40.0)), "launch fan half-angle should be 40 degrees")
	for _sample in range(64):
		var dir_roll: float = CommandoFirearmBowlingTrapGeometry.roll_launch_direction()
		_expect(dir_roll >= -1.0 and dir_roll <= 1.0, "roll_launch_direction must stay within [-1, 1] (got %f)" % dir_roll)
	for dir_value in [-1.0, 0.0, 1.0]:
		var fan_motion: Dictionary = CommandoFirearmBowlingTrapGeometry.build_release_motion(
			{"pos": Vector2(100.0, 640.0), "captured_original_speed": 6.0, "launch_direction": dir_value},
			Vector2(0.0, -15.0),
			4.0,
			fan_half_angle
		)
		_expect((fan_motion["launch_vel"] as Vector2).y < 0.0, "bowling-trap launch should always travel upward toward the boss (dir=%f)" % dir_value)
		var deflection: float = absf(float(fan_motion["launch_angle"]) - (-PI * 0.5))
		_expect(deflection <= fan_half_angle + 0.0001, "launch deflection must stay within the +/-40 deg fan (dir=%f got %.1f deg)" % [dir_value, rad_to_deg(deflection)])
	_expect(
		is_equal_approx(absf(float(CommandoFirearmBowlingTrapGeometry.build_release_motion(
			{"pos": Vector2.ZERO, "captured_original_speed": 6.0, "launch_direction": 0.0},
			Vector2(0.0, -15.0), 4.0, fan_half_angle
		)["launch_angle"]) - (-PI * 0.5)), 0.0),
		"zero launch direction should fire straight up toward the boss"
	)

	var install_trap: Dictionary = CommandoFirearmBowlingTrapGeometry.build_install_trap(
		Vector2(120.0, 640.0),
		{"color": Color.RED, "secondary": Color.BLUE},
		"bowling_trap",
		9,
		60.0,
		20.0,
		48.0,
		Vector2(0.0, -15.0)
	)
	_expect(install_trap["state"] == "installing", "install trap payload should start in installing state")
	_expect(install_trap["captured_ball_pos"] == Vector2(120.0, 625.0), "install trap payload should preseed captured ball anchor")
	var appended_traps: Array = []
	var appended_flashes: Array = []
	var appended_trap: Dictionary = CommandoFirearmBowlingTrapGeometry.append_install_effects(
		appended_traps,
		appended_flashes,
		{"player_pos": Vector2(100.0, 640.0), "paddle_width": 80.0, "paddle_height": 45.0},
		{"color": Color.RED, "secondary": Color.BLUE},
		"bowling_trap",
		17,
		760.0,
		750.0,
		60.0,
		20.0,
		0.6,
		48.0,
		Vector2(0.0, -15.0),
		4,
		3
	)
	_expect(appended_traps.size() == 1, "install append helper should append one trap body")
	_expect(appended_flashes.size() == 1, "install append helper should append one marker flash")
	_expect(int(appended_trap.get("id", 0)) == 17, "install append helper should preserve runtime trap id")
	var runtime_traps: Array = []
	var runtime_flashes: Array = []
	var counter := FakeShotCounter.new()
	counter.shot_serial = 20
	var runtime_trap: Dictionary = CommandoFirearmBowlingTrapGeometry.append_runtime_install_effects(
		runtime_traps,
		runtime_flashes,
		counter,
		{"player_pos": Vector2(100.0, 640.0), "paddle_width": 80.0, "paddle_height": 45.0},
		{"color": Color.RED, "secondary": Color.BLUE},
		"bowling_trap",
		760.0,
		750.0,
		60.0,
		20.0,
		0.6,
		48.0,
		Vector2(0.0, -15.0),
		4,
		3
	)
	_expect(counter.shot_serial == 21, "runtime install append helper should claim the next shot id")
	_expect(int(runtime_trap.get("id", 0)) == 21, "runtime install append helper should use the claimed trap id")
	_expect(runtime_traps.size() == 1 and runtime_flashes.size() == 1, "runtime install append helper should append trap and marker payloads")
	_expect(
		CommandoFirearmBowlingTrapGeometry.update_install_state(install_trap, 48.0, 48.0)["state"] == "waiting",
		"install state update should enter waiting state when timer expires"
	)
	var carryover: Array = CommandoFirearmBowlingTrapGeometry.build_round_carryover([
		{"id": 1, "state": "installing", "pos": Vector2(100.0, 200.0)},
		{"id": 2, "state": "capturing", "pos": Vector2(200.0, 300.0), "captured_original_speed": 9.0},
		{"id": 3, "state": "launching", "pos": Vector2(300.0, 400.0)},
	], Vector2(0.0, -15.0))
	_expect(carryover.size() == 2, "round carryover should skip launching / inactive trap bodies")
	_expect(str((carryover[0] as Dictionary).get("state", "")) == "waiting", "round carryover should normalize traps to waiting")
	_expect((carryover[0] as Dictionary).get("captured_ball_pos", Vector2.ZERO) == Vector2(100.0, 185.0), "round carryover should rebuild captured-ball anchor")
	_expect(CommandoFirearmBowlingTrapGeometry.has_installing_trap([install_trap]), "installing trap helper should detect installing states")
	_expect(is_equal_approx(CommandoFirearmBowlingTrapGeometry.get_install_progress([{"state": "installing", "install_progress": 0.4}]), 0.4), "install progress helper should read installing progress")

	var capture_trap: Dictionary = CommandoFirearmBowlingTrapGeometry.build_capture_state(
		install_trap,
		{"ball_vel": Vector2(0.0, 6.0)},
		90.0,
		Vector2(0.0, -15.0)
	)
	_expect(capture_trap["state"] == "capturing", "capture state payload should enter capturing state")
	_expect(is_equal_approx(float(capture_trap["captured_original_speed"]), 6.0), "capture state payload should preserve original speed")
	var updated_capture: Dictionary = CommandoFirearmBowlingTrapGeometry.update_capture_state(capture_trap, 45.0, 90.0)
	_expect(is_equal_approx(float(updated_capture["capture_progress"]), 0.5), "capture state update should expose capture progress")
	_expect(not CommandoFirearmBowlingTrapGeometry.is_capture_complete(updated_capture), "halfway capture should not be complete")
	_expect(CommandoFirearmBowlingTrapGeometry.build_capture_result(updated_capture)["skip_ball_motion_step"], "capture result should pause normal ball motion")
	var release_motion: Dictionary = CommandoFirearmBowlingTrapGeometry.build_release_motion(
		capture_trap,
		Vector2(0.0, -15.0),
		4.0,
		CommandoFirearmRuntime.BOWLING_TRAP_LAUNCH_FAN_HALF_ANGLE
	)
	_expect(is_equal_approx(float(release_motion["launch_speed"]), 24.0), "release motion should multiply original ball speed")
	_expect(is_equal_approx((release_motion["launch_vel"] as Vector2).length(), 24.0), "release motion velocity should match launch speed")
	_expect(
		is_equal_approx(float(CommandoFirearmBowlingTrapGeometry.build_release_result(release_motion, "guard", guard_knockback_power, guard_stun_frames, 0.7)["commando_bowling_trap_guard_restore_speed"]), 4.2),
		"release result should expose reduced guard restore speed"
	)
	var release_payload: Dictionary = CommandoFirearmBowlingTrapGeometry.build_release_payload(
		capture_trap,
		{"impact_radius": 30.0},
		Vector2(0.0, -15.0),
		4.0,
		CommandoFirearmRuntime.BOWLING_TRAP_LAUNCH_FAN_HALF_ANGLE,
		0.7,
		guard_knockback_power,
		guard_stun_frames
	)
	_expect(str(_get_dict(release_payload.get("release_result", {})).get("commando_bowling_trap_guard_source", "")) == "commando_bowling_trap_guard_9", "release payload should build the guard source")
	_expect(str(_get_dict(release_payload.get("pseudo_projectile", {})).get("weapon_id", "")) == "bowling_trap", "release payload should build the pseudo projectile")
	var dispatch_owner := FakeRuntimeOwner.new()
	var dispatch_feedback := FakeFeedback.new()
	var dispatch_ball_effects := FakeBallEffects.new()
	var dispatch_audio := FakeAudio.new()
	var dispatch_flashes: Array = []
	CommandoFirearmBowlingTrapGeometry.dispatch_runtime_update_events(
		[
			{
				"type": "capture",
				"captured_pos": Vector2(120.0, 220.0),
				"ball_vel": Vector2(0.0, 6.0),
			},
			{
				"type": "release",
				"release_payload": release_payload,
			},
		],
		dispatch_flashes,
		dispatch_owner,
		{"ball_pos": Vector2(120.0, 220.0)},
		{
			"feedback": dispatch_feedback,
			"ball_effects": dispatch_ball_effects,
			"audio": dispatch_audio,
		},
		CommandoFirearmRuntime.WEAPON_PROFILES,
		CommandoFirearmRuntime.WEAPON_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.WEAPON_HIT_FEEDBACK,
		CommandoFirearmRuntime.HIT_FEEDBACK_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.BASE_WEAPON_ID,
		24.0,
		8
	)
	_expect(dispatch_feedback.calls.size() == 2, "runtime event dispatcher should trigger capture and release feedback")
	_expect(dispatch_ball_effects.pulses.size() == 2, "runtime event dispatcher should register capture and release ball pulses")
	_expect(dispatch_audio.snap_calls == 1, "runtime event dispatcher should play the capture snap cue once")
	_expect(dispatch_flashes.size() == 1, "runtime event dispatcher should append one release impact flash")
	_expect(dispatch_owner.lingering_calls.size() == 1, "runtime event dispatcher should spawn release lingering effect")
	_expect(dispatch_owner.bowling_trap_guard_armed, "runtime event dispatcher should apply release guard state")
	var runtime_capture_traps: Array = [{
		"id": 12,
		"state": "waiting",
		"pos": Vector2(100.0, 100.0),
		"width": 60.0,
	}]
	var runtime_capture_update: Dictionary = CommandoFirearmBowlingTrapGeometry.advance_runtime_traps(
		runtime_capture_traps,
		{"ball_pos": Vector2(100.0, 110.0), "ball_vel": Vector2(0.0, 5.0), "ball_size": 20.0},
		1.0,
		{"impact_radius": 30.0},
		48.0,
		90.0,
		Vector2(0.0, -15.0),
		20.0,
		40.0,
		60.0,
		4.0,
		PI / 8.0,
		0.7,
		guard_knockback_power,
		guard_stun_frames
	)
	_expect(str(_get_dict(runtime_capture_traps[0]).get("state", "")) == "capturing", "runtime trap owner should enter capture state")
	_expect(bool(_get_dict(runtime_capture_update.get("result", {})).get("commando_bowling_trap_captured", false)), "runtime trap owner should emit capture result")
	_expect(str(_get_dict(_get_array(runtime_capture_update.get("events", []))[0]).get("type", "")) == "capture", "runtime trap owner should emit capture event")
	var runtime_release_traps: Array = [capture_trap.merged({"timer_frames": 1.0}, true)]
	var runtime_release_update: Dictionary = CommandoFirearmBowlingTrapGeometry.advance_runtime_traps(
		runtime_release_traps,
		{},
		2.0,
		{"impact_radius": 30.0},
		48.0,
		90.0,
		Vector2(0.0, -15.0),
		20.0,
		40.0,
		60.0,
		4.0,
		PI / 8.0,
		0.7,
		guard_knockback_power,
		guard_stun_frames
	)
	_expect(runtime_release_traps.is_empty(), "runtime trap owner should remove completed capture traps")
	_expect(bool(_get_dict(runtime_release_update.get("result", {})).get("commando_bowling_trap_released", false)), "runtime trap owner should emit release result")
	_expect(str(_get_dict(_get_array(runtime_release_update.get("events", []))[0]).get("type", "")) == "release", "runtime trap owner should emit release event")
	var guard_state: Dictionary = CommandoFirearmBowlingTrapGeometry.build_guard_state({"id": 9}, 6.0, 0.7)
	_expect(bool(guard_state.get("armed", false)), "guard state helper should arm the guard")
	_expect(str(guard_state.get("source", "")) == "commando_bowling_trap_guard_9", "guard state helper should build stable guard sources")
	_expect(is_equal_approx(float(guard_state.get("restore_speed", 0.0)), 4.2), "guard state helper should apply speed reduction")
	_expect(not bool(CommandoFirearmBowlingTrapGeometry.build_cleared_guard_state().get("armed", true)), "cleared guard helper should disarm the guard")
	var status_data: Dictionary = CommandoFirearmBowlingTrapGeometry.build_guard_status_data(22.0, 6.0, 0.8, "guard")
	_expect(bool(status_data.get("knockback_active", false)), "guard status data should mark active knockback")
	_expect(str(status_data.get("source", "")) == "guard", "guard status data should preserve source")
	_expect(
		not CommandoFirearmBowlingTrapGeometry.is_stage2_boss_status_immune({}, {}),
		"stage2 boss immunity helper should default false"
	)
	_expect(
		CommandoFirearmBowlingTrapGeometry.is_stage2_boss_status_immune(
			{"current_stage": 2, "stage2_speed_defense_active": true},
			{}
		),
		"stage2 boss immunity helper should read active speed defense context"
	)
	var skill_state := FakeStage2SkillState.new()
	skill_state.immune = true
	_expect(
		CommandoFirearmBowlingTrapGeometry.is_stage2_boss_status_immune({}, {"stage2_boss_skill_state": skill_state}),
		"stage2 boss immunity helper should read injected skill state"
	)
	var registry := FakeRegistry.new()
	registry.stage2_boss_skill_state = skill_state
	_expect(
		CommandoFirearmBowlingTrapGeometry.is_stage2_boss_status_immune({}, {"registry": registry}),
		"stage2 boss immunity helper should read registry skill state"
	)
	var immune_result: Dictionary = CommandoFirearmBowlingTrapGeometry.build_guard_immune_result(Vector2(0.0, 4.0))
	_expect(bool(immune_result.get("boss_status_immune", false)), "guard immune result should expose boss immunity")
	_expect(not bool(immune_result.get("commando_bowling_trap_guard_hit", true)), "guard immune result should not mark a guard hit")
	var hit_result: Dictionary = CommandoFirearmBowlingTrapGeometry.build_guard_hit_result(Vector2(0.0, 4.0), guard_knockback_power, "guard", guard_stun_frames, 4.2)
	_expect(bool(hit_result.get("commando_bowling_trap_guard_hit", false)), "guard hit result should mark a guard hit")
	_expect(is_equal_approx(float(hit_result.get("commando_bowling_trap_guard_consumed_restore_speed", 0.0)), 4.2), "guard hit result should preserve restore speed")

	var trap := {"pos": Vector2(100.0, 100.0), "width": 60.0}
	var hit_context := {"ball_pos": Vector2(100.0, 110.0), "ball_vel": Vector2(0.0, 5.0), "ball_size": 20.0}
	_expect(CommandoFirearmBowlingTrapGeometry.hits_ball(trap, hit_context, 20.0, 40.0, 60.0), "downward ball should hit overlapping bowling trap")
	_expect(
		not CommandoFirearmBowlingTrapGeometry.hits_ball(trap, {"ball_pos": Vector2(100.0, 110.0), "ball_vel": Vector2(0.0, -5.0), "ball_size": 20.0}, 20.0, 40.0, 60.0),
		"upward ball should not trigger bowling trap"
	)
	_expect(
		not CommandoFirearmBowlingTrapGeometry.hits_ball(trap, {"ball_pos": Vector2(240.0, 110.0), "ball_vel": Vector2(0.0, 5.0), "ball_size": 20.0}, 20.0, 40.0, 60.0),
		"non-overlapping downward ball should not hit bowling trap"
	)


func _verify_direct_bowling_trap_guard_state() -> void:
	var runtime := CommandoFirearmRuntime.new()
	_expect(
		CommandoFirearmBowlingTrapGuardState.consume_runtime_boss_guard(
			runtime,
			Vector2.ZERO,
			{},
			{},
			CommandoFirearmRuntime.FIELD_WIDTH,
			CommandoFirearmRuntime.BASE_WEAPON_ID,
			CommandoFirearmRuntime.WEAPON_PROFILES,
			CommandoFirearmRuntime.WEAPON_PROFILE_OVERRIDES,
			CommandoFirearmRuntime.WEAPON_HIT_FEEDBACK,
			CommandoFirearmRuntime.HIT_FEEDBACK_PROFILE_OVERRIDES,
			CommandoFirearmRuntime.BOWLING_TRAP_GUARD_KNOCKBACK_POWER,
			CommandoFirearmRuntime.BOWLING_TRAP_GUARD_STUN_FRAMES,
			CommandoFirearmRuntime.BOWLING_TRAP_GUARD_KNOCKBACK_FRAMES,
			CommandoFirearmRuntime.BOWLING_TRAP_GUARD_KNOCKBACK_DECAY
		).is_empty(),
		"guard state owner should ignore unarmed runtime guard state"
	)
	CommandoFirearmBowlingTrapGeometry.apply_guard_state(
		runtime,
		{"armed": true, "restore_speed": 7.0, "source": ""}
	)
	var immune_result: Dictionary = CommandoFirearmBowlingTrapGuardState.consume_runtime_boss_guard(
		runtime,
		Vector2.ZERO,
		{"current_stage": 2, "stage2_speed_defense_active": true},
		{},
		CommandoFirearmRuntime.FIELD_WIDTH,
		CommandoFirearmRuntime.BASE_WEAPON_ID,
		CommandoFirearmRuntime.WEAPON_PROFILES,
		CommandoFirearmRuntime.WEAPON_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.WEAPON_HIT_FEEDBACK,
		CommandoFirearmRuntime.HIT_FEEDBACK_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.BOWLING_TRAP_GUARD_KNOCKBACK_POWER,
		CommandoFirearmRuntime.BOWLING_TRAP_GUARD_STUN_FRAMES,
		CommandoFirearmRuntime.BOWLING_TRAP_GUARD_KNOCKBACK_FRAMES,
		CommandoFirearmRuntime.BOWLING_TRAP_GUARD_KNOCKBACK_DECAY
	)
	_expect(bool(immune_result.get("boss_status_immune", false)), "guard state owner should preserve Stage 2 immunity handling")
	_expect(not runtime.is_bowling_trap_guard_armed(), "guard state owner should clear consumed runtime guard state")
	_expect(
		_get_vector2(immune_result.get("ball_vel", Vector2.ZERO), Vector2.ZERO) == Vector2(0.0, 7.0),
		"guard state owner should soften the ball before immunity exits"
	)


func _verify_runtime_delegates_bowling_trap_geometry() -> void:
	var runtime := CommandoFirearmRuntime.new()
	_expect(
		CommandoFirearmBowlingTrapGeometry.get_install_pos({}, 760.0, 750.0, 60.0, 20.0, 0.6) == Vector2(457.5, 735.0),
		"install-position owner should preserve runtime defaults"
	)
	runtime.bowling_traps = [{"id": 1, "state": "installing", "pos": Vector2(100.0, 200.0), "install_progress": 0.4}]
	var bowling_state_value: Variant = runtime.get_actor_draw_context().get("commando_firearm_bowling_trap_state", {})
	var bowling_state: Dictionary = {}
	if bowling_state_value is Dictionary:
		bowling_state = bowling_state_value
	_expect(is_equal_approx(float(bowling_state.get("install_progress", 0.0)), 0.4), "runtime draw context should use delegated install progress")
	runtime.bowling_traps = [{
		"id": 9,
		"state": "capturing",
		"pos": Vector2(100.0, 100.0),
		"captured_ball_pos": Vector2(100.0, 85.0),
		"captured_original_speed": 6.0,
		"timer_frames": 1.0,
		"launch_direction": 0.0,
	}]
	var release_result: Dictionary = CommandoFirearmBowlingTrapGeometry.advance_runtime_bowling_traps(
		runtime.bowling_traps,
		runtime.impact_flashes,
		runtime,
		{},
		{},
		2.0,
		CommandoFirearmRuntime.WEAPON_PROFILES,
		CommandoFirearmRuntime.WEAPON_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.WEAPON_HIT_FEEDBACK,
		CommandoFirearmRuntime.HIT_FEEDBACK_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.BASE_WEAPON_ID,
		float(ActiveItemThrowController.GRENADE_EXPLOSION_DURATION_FRAMES),
		CommandoFirearmRuntime.FLASH_LIMIT,
		CommandoFirearmRuntime.BOWLING_TRAP_INSTALL_FRAMES,
		CommandoFirearmRuntime.BOWLING_TRAP_CAPTURE_FRAMES,
		CommandoFirearmRuntime.BOWLING_TRAP_CAPTURE_BALL_OFFSET,
		CommandoFirearmRuntime.BOWLING_TRAP_HEIGHT,
		CommandoFirearmRuntime.BOWLING_TRAP_CAPTURE_HEIGHT,
		CommandoFirearmRuntime.BOWLING_TRAP_WIDTH,
		CommandoFirearmRuntime.BOWLING_TRAP_LAUNCH_SPEED_MULTIPLIER,
		CommandoFirearmRuntime.BOWLING_TRAP_LAUNCH_FAN_HALF_ANGLE,
		CommandoFirearmRuntime.BOWLING_TRAP_GUARD_SPEED_REDUCTION,
		CommandoFirearmRuntime.BOWLING_TRAP_GUARD_KNOCKBACK_POWER,
		CommandoFirearmRuntime.BOWLING_TRAP_GUARD_STUN_FRAMES
	)
	_expect(str(release_result.get("commando_bowling_trap_guard_source", "")) == "commando_bowling_trap_guard_9", "runtime release path should expose delegated guard source")
	_expect(runtime.is_bowling_trap_guard_armed(), "runtime release path should apply armed guard state")
	_expect(runtime.bowling_traps.is_empty(), "runtime release path should remove completed capture traps")
	CommandoFirearmBowlingTrapGeometry.apply_guard_state(
		runtime,
		CommandoFirearmBowlingTrapGeometry.build_cleared_guard_state()
	)
	_expect(not runtime.is_bowling_trap_guard_armed(), "runtime guard state owner should apply cleared state")
	var spawn_runtime := CommandoFirearmRuntime.new()
	spawn_runtime._spawn_firearm_effect(
		"bowling_trap",
		{"player_pos": Vector2(100.0, 640.0), "paddle_width": 80.0, "paddle_height": 45.0},
		{},
		{"kind": "trap", "color": Color.RED, "secondary": Color.BLUE}
	)
	_expect(spawn_runtime.bowling_traps.size() == 1, "runtime trap fire path should append one delegated trap")
	_expect(spawn_runtime.impact_flashes.size() == 1, "runtime trap fire path should append one delegated marker flash")
	_expect(int((spawn_runtime.bowling_traps[0] as Dictionary).get("id", 0)) == 1, "runtime trap fire path should preserve delegated shot id")


func _verify_removed_runtime_bowling_trap_geometry_bridges() -> void:
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	var effect_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_effect_update_state.gd")
	var fire_spawn_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_fire_spawn_state.gd")
	_expect(
		runtime_source.find("CommandoFirearmBowlingTrapGuardState.consume_runtime_boss_guard") >= 0,
		"runtime should delegate bowling-trap boss-guard consumption to the guard-state owner"
	)
	_expect(
		runtime_source.find("CommandoFirearmEffectUpdateState.advance_runtime_effects") >= 0,
		"runtime should delegate effect update orchestration"
	)
	_expect(
		effect_source.find("CommandoFirearmBowlingTrapGeometry.advance_runtime_bowling_traps") >= 0,
		"effect update owner should delegate bowling-trap lifecycle advancement to the geometry owner"
	)
	_expect(
		runtime_source.find("CommandoFirearmBowlingTrapGeometry.advance_runtime_traps") < 0,
		"runtime should not call the lower-level bowling-trap advance helper directly"
	)
	_expect(
		runtime_source.find("CommandoFirearmBowlingTrapGeometry.dispatch_runtime_update_events") < 0,
		"runtime should not call the lower-level bowling-trap event dispatch helper directly"
	)
	_expect(
		runtime_source.find("CommandoFirearmFireSpawnState.spawn_runtime_firearm_effect") >= 0,
		"runtime should delegate fire-spawn orchestration to the fire-spawn state"
	)
	_expect(
		fire_spawn_source.find("CommandoFirearmBowlingTrapGeometry.append_runtime_install_effects") >= 0,
		"fire-spawn state should delegate bowling-trap runtime install append to the geometry owner"
	)
	_expect(
		fire_spawn_source.find("CommandoFirearmBowlingTrapGeometry.append_install_effects") < 0,
		"fire-spawn state should not call the lower-level bowling-trap install helper directly"
	)
	for bridge_name in [
		"_is_bowling_trap_install_in_player_field",
		"_get_bowling_trap_install_pos",
		"_build_bowling_trap_install_payload",
		"_build_bowling_trap_install_marker_flash",
		"_has_installing_bowling_trap",
		"_build_bowling_trap_round_carryover",
		"_build_bowling_trap_capture_result",
		"_soften_bowling_trap_guard_ball",
		"_get_bowling_trap_guard_knockback_velocity",
		"_is_stage2_speed_defense_boss_immune",
		"_is_stage2_speed_defense_registry_immune",
		"_get_bowling_trap_launch_direction",
		"_bowling_trap_hits_ball",
		"_arm_bowling_trap_guard",
		"_apply_bowling_trap_guard_state",
		"_start_bowling_trap_install",
		"_update_bowling_trap_install",
		"_clear_bowling_trap_guard",
		"_update_bowling_trap_capture",
		"_capture_bowling_trap_ball",
		"_release_bowling_trap_ball",
		"_update_bowling_traps",
	]:
		_expect(runtime_source.find("func %s(" % bridge_name) == -1, "runtime should not keep bowling-trap geometry bridge %s" % bridge_name)
	_expect(
		runtime_source.find("bowling_trap_launch") == -1,
		"runtime should not keep bowling-trap launch event pulse dispatch inline"
	)


# OUTCOME seal: the bowling-trap guard hit must NUDGE the boss, not launch it across the
# field. Drives the real runtime path (status stun + knockback decay -> boss-AI grenade-style
# motion) and asserts total boss travel stays well under the field width. Reverse-verified:
# restoring the dynamite power (104.0) drives the boss ~610px into the wall and FAILS the
# upper bound. Target: intentional +30% buff over Python parity (22.0 -> 28.6 power), so the
# boss now travels ~190px (was ~146px at the Python source value) — still well inside the bound.
func _verify_bowling_trap_guard_knockback_stays_bounded() -> void:
	var travel: float = _simulate_bowling_trap_guard_boss_travel(
		CommandoFirearmRuntime.BOWLING_TRAP_GUARD_KNOCKBACK_POWER
	)
	_expect(
		travel > 60.0,
		"bowling-trap guard should still knock the boss back a meaningful distance (got %.1fpx)" % travel
	)
	_expect(
		travel < 300.0,
		"bowling-trap guard knockback must stay bounded (~190px after the +30%% buff), not slam the boss across the field (got %.1fpx)" % travel
	)
	# Reverse-verify the seal: the retired dynamite power must trip the upper bound.
	var dynamite_travel: float = _simulate_bowling_trap_guard_boss_travel(
		ActiveItemThrowController.DYNAMITE_BOSS_KNOCKBACK_POWER
	)
	_expect(
		dynamite_travel >= 300.0,
		"regression guard sanity: dynamite-power knockback (104) should overshoot the bound (got %.1fpx)" % dynamite_travel
	)


func _simulate_bowling_trap_guard_boss_travel(knockback_power: float) -> float:
	var status := StatusEffectState.new()
	var ai := BossAiState.new()
	# Boss parked near the left wall so a rightward knockback has the full field to travel.
	var boss_pos := Vector2(50.0, 25.0)
	var start_x: float = boss_pos.x
	status.apply_status(
		"boss",
		"stun",
		CommandoFirearmRuntime.BOWLING_TRAP_GUARD_STUN_FRAMES,
		{
			"knockback_vel": knockback_power,
			"knockback_active": true,
			"knockback_frames": CommandoFirearmRuntime.BOWLING_TRAP_GUARD_KNOCKBACK_FRAMES,
			"knockback_decay_per_frame": CommandoFirearmRuntime.BOWLING_TRAP_GUARD_KNOCKBACK_DECAY,
			"knockback_stop_threshold": 0.3,
		},
		"commando_bowling_trap_guard"
	)
	for _frame in range(40):
		status.update(1.0, {}, {})
		var ctx: Dictionary = status.get_boss_ai_context()
		ctx["width"] = 760.0
		ctx["play_left"] = 0.0
		ctx["play_right"] = 760.0
		ctx["boss_paddle_width"] = 100.0
		var ai_result: Dictionary = ai.update(1.0 / 60.0, boss_pos, 0.0, ctx)
		boss_pos = _get_vector2(ai_result.get("boss_pos", boss_pos), boss_pos)
	return absf(boss_pos.x - start_x)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
