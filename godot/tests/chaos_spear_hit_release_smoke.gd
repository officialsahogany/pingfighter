extends SceneTree

const BallRoundState := preload("res://scripts/ball/ball_round_state.gd")
const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const PaddleBounceController := preload("res://scripts/ball/paddle_bounce_controller.gd")
const PaddleBounceState := preload("res://scripts/ball/paddle_bounce_state.gd")
const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")


class FakeMotionStepper:
	func step(ball_pos: Vector2, motion_delta: Vector2, _ball_vel: Vector2, _context: Dictionary) -> Dictionary:
		return {
			"ball_pos": ball_pos + motion_delta,
			"event": "none",
		}


class FakeAudio:
	var stopped := 0

	func play_paddle_hit() -> void:
		pass

	func stop_chaos_spear_windup() -> void:
		stopped += 1

	func stop_chaos_spear_flying() -> void:
		stopped += 1

	func stop_chaos_spear_impact() -> void:
		stopped += 1


class FakeFeedback:
	func trigger_gauge_flash() -> void:
		pass

	func set_screen_shake(_duration: float, _amount: float) -> void:
		pass

	func max_screen_shake(_duration: float, _amount: float) -> void:
		pass


class FakePerkState:
	var gold := 0
	var levels := {
		"blade_amp": 0,
		"kick_enhance": 0,
	}

	func get_runtime_skill_level(skill_id: String) -> int:
		return int(levels.get(skill_id, 0))

	func award_gold(amount: int) -> int:
		gold += max(0, amount)
		return gold


func _init() -> void:
	_test_player_paddle_hit_releases_chaos()
	_test_natural_expiry_release_clears_motion_skip()
	_test_air_and_dark_blade_hits_release_chaos()
	_test_phantom_kick_hit_releases_chaos()
	_test_mythic_pause_expiry_self_heals_motion_skip()
	_test_self_heal_noop_when_flag_already_released()
	_test_round_reset_scopes_ownership_and_normalizes_skip()
	print("chaos_spear_hit_release_smoke: ok")
	quit(0)


func _test_player_paddle_hit_releases_chaos() -> void:
	var runtime: Object = _blackhole_runtime()
	var context := _base_context()
	context["ball_pos"] = Vector2(380.0, 675.0)
	context["ball_vel"] = Vector2(0.0, 8.0)
	context["player_pos"] = Vector2(302.5, 650.0)
	var deps := _deps(runtime)

	var result: Dictionary = BallUpdateController.new().update(1.0 / 60.0, context, deps)
	var snapshot: Dictionary = result.get("snapshot", {})
	_expect(str(runtime.get_snapshot().get("chaos_state", "")) == "fade", "player paddle contact should end Chaos Spear blackhole immediately")
	_expect(not bool(snapshot.get("skip_ball_motion_step", false)), "player paddle contact should resume the normal ball motion step")
	_expect(not bool(runtime.chaos_ball_motion_owned), "early-hit release must drop motion-skip ownership on the same frame")
	_expect(_get_vector2(snapshot, "ball_vel", Vector2.ZERO).y < 0.0, "player paddle contact should launch the held ball upward")
	_expect(_get_vector2(snapshot, "ball_vel", Vector2.ZERO).length() >= 3.0, "player paddle release should keep a real bounce speed")


func _test_natural_expiry_release_clears_motion_skip() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var release_velocity := Vector2(12.0, -9.0)
	runtime.chaos_state = "fade"
	runtime.chaos_release_pending = true
	runtime.chaos_release_velocity = release_velocity
	var start_pos := Vector2(380.0, 420.0)
	var context := _base_context()
	context["ball_pos"] = start_pos
	context["ball_vel"] = Vector2.ZERO
	context["skip_ball_motion_step"] = true
	var deps := _deps(runtime)

	var result: Dictionary = BallUpdateController.new().update(1.0 / 60.0, context, deps)
	var snapshot: Dictionary = result.get("snapshot", {})
	_expect(not bool(snapshot.get("skip_ball_motion_step", true)), "natural Chaos Spear expiry should clear the held-ball motion skip")
	_expect(_get_vector2(snapshot, "ball_vel", Vector2.ZERO).distance_to(release_velocity) <= 0.001, "natural Chaos Spear expiry should apply the queued release velocity")
	_expect(_get_vector2(snapshot, "ball_pos", start_pos).distance_to(start_pos) > 0.1, "natural Chaos Spear expiry should let the ball move immediately")
	_expect(not bool(runtime.get_snapshot().get("chaos_release_pending", true)), "natural Chaos Spear release velocity should be consumed once")


func _test_air_and_dark_blade_hits_release_chaos() -> void:
	var deps := _deps(null)
	var scene := {
		"ball_pos": Vector2(380.0, 420.0),
		"ball_vel": Vector2(0.0, -30.0),
		"ball_impact_boost": 1.0,
		"player_collision_cooldown": 0.0,
	}
	var context: Dictionary = _base_context()
	context.merge(scene, true)

	var air_runtime: Object = _blackhole_runtime()
	deps["viper_skill_runtime"] = air_runtime
	var air_result: Dictionary = air_runtime.call("_apply_blade_hit", scene, context, deps, false, true, false, false, 1.0)
	_expect(str(air_runtime.get_snapshot().get("chaos_state", "")) == "fade", "Air Blade hit should end Chaos Spear blackhole immediately")
	_expect(not bool(air_result.get("skip_ball_motion_step", true)), "Air Blade release should clear Chaos Spear's motion skip")
	_expect(_get_vector2(air_result, "ball_vel", Vector2.ZERO).y < 0.0, "Air Blade should launch the held ball with its hit velocity")

	var dark_runtime: Object = _blackhole_runtime()
	deps["viper_skill_runtime"] = dark_runtime
	var dark_result: Dictionary = dark_runtime.call("_apply_blade_hit", scene, context, deps, true, true, false, false, 1.0)
	_expect(str(dark_runtime.get_snapshot().get("chaos_state", "")) == "fade", "Dark Blade hit should end Chaos Spear blackhole immediately")
	_expect(not bool(dark_result.get("skip_ball_motion_step", true)), "Dark Blade release should clear Chaos Spear's motion skip")
	_expect(_get_vector2(dark_result, "ball_vel", Vector2.ZERO).y < 0.0, "Dark Blade should launch the held ball with its hit velocity")


func _test_phantom_kick_hit_releases_chaos() -> void:
	var runtime: Object = _blackhole_runtime()
	runtime.marshal_is_double = true
	runtime.marshal_phase = 2
	runtime.marshal_phase_frames = 999.0
	runtime.marshal_wall_pos = Vector2(40.0, 350.0)
	var deps := _deps(runtime)
	var config: Dictionary = _base_context()
	config["ball_pos"] = Vector2(620.0, 350.0)
	config["ball_vel"] = Vector2(0.0, -8.0)
	config["boss_pos"] = Vector2(330.0, 25.0)
	config["boss_paddle_width"] = 100.0
	config["ball_impact_boost"] = 1.0

	runtime.marshal_charge_start_pos = (
		_get_vector2(config, "ball_pos", Vector2.ZERO)
		- _get_vector2(config, "player_paddle_size", Vector2(155.0, 50.0)) * 0.5
	)
	var result: Dictionary = {}
	runtime.call("_update_marshal_charge_phase", config, deps, result)
	_expect(str(runtime.get_snapshot().get("chaos_state", "")) == "fade", "Phantom Kick hit should end Chaos Spear blackhole immediately")
	_expect(not bool(result.get("skip_ball_motion_step", true)), "Phantom Kick release should clear Chaos Spear's motion skip")
	_expect(_get_vector2(result, "ball_vel", Vector2.ZERO).length() >= 22.0, "Phantom Kick should launch the held ball with the kick speed")


# 신화 획득 시네마틱 등 modal pause는 update_effects만 돌리고 update_ball을 멈춘다.
# 그 창에서 블랙홀이 만료->fade->reset까지 끝나면 pending 해제가 와이프되는데,
# 다음 ball 패스의 소유권 자가 해제가 잔류한 skip_ball_motion_step을 풀어야 한다.
func _test_mythic_pause_expiry_self_heals_motion_skip() -> void:
	var runtime: Object = _blackhole_runtime()
	var mid_field := Vector2(380.0, 420.0)
	runtime.chaos_target = mid_field
	runtime.chaos_current = mid_field
	runtime.chaos_prev_ball_center = mid_field
	runtime.chaos_blackhole_ball_origin = mid_field
	var deps := _deps(runtime)
	var controller: Object = BallUpdateController.new()

	var owned_context := _base_context()
	owned_context["ball_pos"] = mid_field
	owned_context["ball_vel"] = Vector2(0.0, 8.0)
	var owned_result: Dictionary = controller.update(1.0 / 60.0, owned_context, deps)
	var owned_snapshot: Dictionary = owned_result.get("snapshot", {})
	_expect(bool(owned_snapshot.get("skip_ball_motion_step", false)), "blackhole ball pass should hold the shared motion skip")
	_expect(bool(runtime.chaos_ball_motion_owned), "blackhole ball pass should mark chaos as the motion-skip owner")

	var pause_context := _base_context()
	for _i in range(260):
		runtime.update_effects(1.0, 0, pause_context, deps)
	_expect(str(runtime.get_snapshot().get("chaos_state", "")) == "idle", "blackhole and fade should expire during the paused window")
	_expect(not bool(runtime.get_snapshot().get("chaos_release_pending", true)), "pause-window reset wipes the queued release (the trap precondition)")
	_expect(bool(runtime.chaos_ball_motion_owned), "ownership must survive the pause-window chaos reset")

	var resume_context := _base_context()
	resume_context["ball_pos"] = _get_vector2(owned_snapshot, "ball_pos", mid_field)
	resume_context["ball_vel"] = _get_vector2(owned_snapshot, "ball_vel", Vector2.ZERO)
	resume_context["skip_ball_motion_step"] = true
	var resume_result: Dictionary = controller.update(1.0 / 60.0, resume_context, deps)
	var snapshot: Dictionary = resume_result.get("snapshot", {})
	_expect(not bool(snapshot.get("skip_ball_motion_step", true)), "self-heal should clear the stuck motion skip after the pause window")
	_expect(_get_vector2(snapshot, "ball_vel", Vector2.ZERO).length() >= 16.0, "self-heal should restore a real timeout-class release speed")
	_expect(not bool(runtime.chaos_ball_motion_owned), "self-heal should consume the ownership flag")


func _test_self_heal_noop_when_flag_already_released() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	runtime.chaos_ball_motion_owned = true
	var deps := _deps(runtime)
	var serve_vel := Vector2(3.0, -7.0)
	var context := _base_context()
	context["ball_pos"] = Vector2(380.0, 420.0)
	context["ball_vel"] = serve_vel

	var result: Dictionary = BallUpdateController.new().update(1.0 / 60.0, context, deps)
	var snapshot: Dictionary = result.get("snapshot", {})
	_expect(_get_vector2(snapshot, "ball_vel", Vector2.ZERO).distance_to(serve_vel) <= 0.001, "self-heal must not inject a velocity when the skip flag was already released")
	_expect(not bool(runtime.chaos_ball_motion_owned), "stale ownership should still be consumed quietly")


# 소유권 토큰은 자연 만료 와이프(pending 잔존 reset)에서만 살아남아야 한다.
# 라운드 경계 reset은 토큰을 끊고, 스냅샷 계층이 공유 skip 플래그를 정규화하므로
# 다음 라운드에서 자가 해제가 새 서브나 다른 시스템의 홀드를 건드릴 수 없다.
func _test_round_reset_scopes_ownership_and_normalizes_skip() -> void:
	var runtime: Object = _blackhole_runtime()
	runtime.chaos_ball_motion_owned = true
	runtime.reset_round({"audio": FakeAudio.new()})
	_expect(str(runtime.get_snapshot().get("chaos_state", "")) == "idle", "round reset should clear the blackhole state")
	_expect(not bool(runtime.chaos_ball_motion_owned), "round reset without a pending release must drop motion-skip ownership")

	# pending이 막 armed된 직후(공 패스 소비 전)의 명시적 라운드 reset도 토큰을 끊어야 한다.
	var pending_runtime: Object = _blackhole_runtime()
	pending_runtime.chaos_ball_motion_owned = true
	var pending_pause_context := _base_context()
	var pending_deps := _deps(pending_runtime)
	for _i in range(185):
		pending_runtime.update_effects(1.0, 0, pending_pause_context, pending_deps)
	_expect(bool(pending_runtime.get_snapshot().get("chaos_release_pending", false)), "blackhole timeout should arm the pending release before the round reset")
	pending_runtime.reset_round({"audio": FakeAudio.new()})
	_expect(not bool(pending_runtime.chaos_ball_motion_owned), "an explicit round reset must drop motion-skip ownership even with a pending release armed")
	_expect(not bool(pending_runtime.get_snapshot().get("chaos_release_pending", true)), "an explicit round reset should wipe the armed pending release")

	var round_state: Object = BallRoundState.new()
	var reset_snapshot: Dictionary = round_state.build_reset_snapshot(760.0, 750.0)
	_expect(reset_snapshot.has("skip_ball_motion_step") and not bool(reset_snapshot.get("skip_ball_motion_step", true)), "round reset snapshot must normalize the shared motion-skip flag")
	var serve_snapshot: Dictionary = round_state.build_serve_snapshot(true, Vector2(302.5, 650.0), Vector2(330.0, 25.0), 710.0, 25.0, 155.0, 100.0, 40.0, 28.6, 20.0, null)
	_expect(serve_snapshot.has("skip_ball_motion_step") and not bool(serve_snapshot.get("skip_ball_motion_step", true)), "serve snapshot must normalize the shared motion-skip flag")

	# 라운드 reset 후 다른 시스템이 잡은 skip=true 홀드를 chaos가 훔치지 않아야 한다.
	var foreign_context := _base_context()
	foreign_context["ball_pos"] = Vector2(380.0, 420.0)
	foreign_context["ball_vel"] = Vector2.ZERO
	foreign_context["skip_ball_motion_step"] = true
	var foreign_result: Dictionary = BallUpdateController.new().update(1.0 / 60.0, foreign_context, _deps(runtime))
	var foreign_snapshot: Dictionary = foreign_result.get("snapshot", {})
	_expect(bool(foreign_snapshot.get("skip_ball_motion_step", false)), "after a round reset chaos must leave a foreign motion-skip hold untouched")
	_expect(_get_vector2(foreign_snapshot, "ball_vel", Vector2.ONE).distance_to(Vector2.ZERO) <= 0.001, "after a round reset chaos must not inject a release velocity into a foreign hold")


func _blackhole_runtime() -> Object:
	var runtime: Object = ViperSkillRuntime.new()
	runtime.chaos_state = "blackhole"
	runtime.chaos_target = Vector2(380.0, 675.0)
	runtime.chaos_current = runtime.chaos_target
	runtime.chaos_phase_frames = 0.0
	runtime.chaos_base_radius = 52.0
	runtime.chaos_orbit_seed = 0.0
	runtime.chaos_prev_ball_center = runtime.chaos_target
	runtime.chaos_prev_ball_valid = true
	runtime.chaos_blackhole_ball_origin = runtime.chaos_target
	runtime.chaos_blackhole_origin_valid = true
	return runtime


func _deps(runtime: Object) -> Dictionary:
	var deps := {
		"audio": FakeAudio.new(),
		"feedback": FakeFeedback.new(),
		"runtime_perk_state": FakePerkState.new(),
		"motion_stepper": FakeMotionStepper.new(),
		"paddle_bounce_controller": PaddleBounceController.new(),
		"paddle_bounce_state": PaddleBounceState.new(),
	}
	if runtime != null:
		deps["viper_skill_runtime"] = runtime
	return deps


func _base_context() -> Dictionary:
	return {
		"selected_character_type": "viper",
		"ball_active": true,
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"ball_size": 28.6,
		"player_pos": Vector2(302.5, 650.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"ball_pos": Vector2(380.0, 675.0),
		"ball_vel": Vector2(0.0, 8.0),
		"ball_impact_boost": 1.0,
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
		"min_ball_speed": 3.0,
		"max_ball_speed": 30.0,
		"max_bounce_angle": 60.0,
		"special_gauge": 0.0,
	}


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
