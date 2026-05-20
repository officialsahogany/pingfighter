extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectStateApplier := preload("res://scripts/items/active_item_effect_state_applier.gd")
const ActiveItemStopwatchOwnerEffects := preload("res://scripts/items/active_item_stopwatch_owner_effects.gd")
const ActiveItemStopwatchRuntime := preload("res://scripts/items/active_item_stopwatch_runtime.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ball_pos := Vector2(200.0, 300.0)
	var ball_vel := Vector2(8.0, -6.0)
	var player_pos := Vector2(100.0, 680.0)
	var player_paddle_width := 120.0
	var player_paddle_height := 40.0
	var player_collision_cooldown := 99.0
	var boss_collision_cooldown := 99.0


class FakePerkState:
	extends RefCounted

	var consume_calls := 0
	var resume_velocity := Vector2.ZERO

	func consume_resume_velocity_for_stopwatch() -> Dictionary:
		consume_calls += 1
		return {"ball_vel": resume_velocity}


class FakeTarget:
	extends RefCounted

	var stopwatch_active := false
	var stopwatch_timer_frames := 0.0
	var stopwatch_initial_timer_frames := 0.0
	var stopwatch_recovery_timer_frames := 0.0
	var stopwatch_post_recovery_grace_frames := 0.0
	var stopwatch_original_ball_vel := Vector2.ZERO
	var stopwatch_flash_timer_frames := 0.0
	var stopwatch_clock_angle := 0.0


class FakeFeedback:
	extends RefCounted

	var shakes: Array[Vector2] = []

	func max_screen_shake(amount: float, duration: float) -> void:
		shakes.append(Vector2(amount, duration))


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_timewatch() -> void:
		calls.append("play_timewatch")

	func play_active_item() -> void:
		calls.append("play_active_item")


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_direct_stopwatch_activation_runtime()
	_verify_direct_stopwatch_update_runtime()
	_verify_direct_stopwatch_update_application()
	_verify_controller_delegates_stopwatch_activation()
	_verify_controller_delegates_stopwatch_update()

	if _failures.is_empty():
		print("active_item_stopwatch_runtime_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_stopwatch_activation_runtime() -> void:
	var runtime: Object = ActiveItemStopwatchRuntime.new()
	var owner := FakeOwner.new()
	var perk := FakePerkState.new()
	perk.resume_velocity = Vector2(0.0, -20.0)
	var registry := FakeRegistry.new()
	registry.instances = {"runtime_perk_state": perk}

	var state: Dictionary = runtime.build_activation_state(owner, registry, Vector2(160.0, 700.0))
	_expect(bool(state.get("activated", false)), "stopwatch runtime should activate when ball is safe")
	_expect(is_equal_approx(float(state.get("timer_frames", 0.0)), 120.0), "stopwatch runtime should use reference freeze duration")
	_expect(_get_vector2(state, "original_ball_vel", Vector2.ZERO) == Vector2(0.0, -20.0), "stopwatch runtime should prefer perk resume velocity")
	_expect(owner.ball_vel == Vector2.ZERO, "stopwatch runtime should freeze the ball on activation")
	_expect(is_equal_approx(owner.player_collision_cooldown, 0.0), "stopwatch runtime should clear player collision cooldown")
	_expect(is_equal_approx(owner.boss_collision_cooldown, 0.0), "stopwatch runtime should clear boss collision cooldown")
	_expect(perk.consume_calls == 1, "stopwatch runtime should consume perk resume velocity once")

	var fallback_owner := FakeOwner.new()
	var fallback_state: Dictionary = runtime.build_activation_state(fallback_owner, null, Vector2(160.0, 700.0))
	_expect(_get_vector2(fallback_state, "original_ball_vel", Vector2.ZERO) == Vector2(8.0, -6.0), "stopwatch runtime should fall back to current ball velocity")

	var blocked_owner := FakeOwner.new()
	blocked_owner.ball_pos = Vector2(160.0, 700.0)
	var blocked_state: Dictionary = runtime.build_activation_state(blocked_owner, null, Vector2(160.0, 700.0))
	_expect(not bool(blocked_state.get("activated", true)), "stopwatch runtime should block near-player activation")
	_expect(bool(blocked_state.get("blocked_by_safe_distance", false)), "stopwatch runtime should report safe-distance block")
	_expect(blocked_owner.ball_vel == Vector2(8.0, -6.0), "blocked stopwatch activation should not freeze the ball")


func _verify_direct_stopwatch_update_runtime() -> void:
	var runtime: Object = ActiveItemStopwatchRuntime.new()
	var original_velocity := Vector2(8.0, -6.0)

	var freeze_tick: Dictionary = runtime.update_state(true, 120.0, 120.0, 0.0, 0.0, original_velocity, 10.0, 1.0, true, 1.0 / 60.0)
	_expect(bool(freeze_tick.get("active", false)), "stopwatch update should stay active during freeze")
	_expect(is_equal_approx(float(freeze_tick.get("timer_frames", 0.0)), 119.0), "stopwatch update should tick freeze timer")
	_expect(is_equal_approx(float(freeze_tick.get("flash_timer_frames", 0.0)), 9.0), "stopwatch update should tick flash timer")
	_expect(is_equal_approx(float(freeze_tick.get("clock_angle", 0.0)), 1.1), "stopwatch update should advance clock angle")
	_expect(bool(freeze_tick.get("freeze_ball", false)), "stopwatch update should request ball freeze during freeze timer")

	var freeze_expiry: Dictionary = runtime.update_state(true, 1.0, 120.0, 0.0, 0.0, original_velocity, 0.0, 2.0, true, 1.0 / 60.0)
	_expect(bool(freeze_expiry.get("active", false)), "stopwatch update should remain active at recovery handoff")
	_expect(is_equal_approx(float(freeze_expiry.get("timer_frames", -1.0)), 0.0), "stopwatch update should clear freeze timer at handoff")
	_expect(is_equal_approx(float(freeze_expiry.get("recovery_timer_frames", 0.0)), 60.0), "stopwatch update should start reference recovery window")
	_expect(bool(freeze_expiry.get("freeze_ball", false)), "stopwatch handoff tick should still request ball freeze")

	var owner_missing: Dictionary = runtime.update_state(true, 120.0, 120.0, 0.0, 0.0, original_velocity, 10.0, 3.0, false, 1.0 / 60.0)
	_expect(not bool(owner_missing.get("active", true)), "stopwatch update should clear when owner is missing")
	_expect(_get_vector2(owner_missing, "original_ball_vel", original_velocity) == Vector2.ZERO, "owner-missing stopwatch update should clear stored velocity")
	_expect(is_equal_approx(float(owner_missing.get("clock_angle", 0.0)), 3.1), "owner-missing stopwatch update should preserve advanced clock angle")

	var recovery_tick: Dictionary = runtime.update_state(true, 0.0, 120.0, 30.0, 0.0, original_velocity, 0.0, 4.0, true, 1.0 / 60.0)
	_expect(bool(recovery_tick.get("active", false)), "stopwatch recovery update should stay active before recovery ends")
	_expect(is_equal_approx(float(recovery_tick.get("recovery_timer_frames", 0.0)), 29.0), "stopwatch recovery update should tick recovery timer")
	_expect(bool(recovery_tick.get("apply_recovery_velocity", false)), "stopwatch recovery update should request velocity ramp")
	_expect(not bool(recovery_tick.get("apply_final_recovery_velocity", false)), "mid-recovery update should not request final velocity")
	_expect(_get_vector2(recovery_tick, "recovery_original_ball_vel", Vector2.ZERO) == original_velocity, "recovery update should expose original velocity for side effects")

	var cooldown_tick: Dictionary = runtime.update_state(true, 0.0, 120.0, 11.0, 0.0, original_velocity, 0.0, 5.0, true, 1.0 / 60.0)
	_expect(bool(cooldown_tick.get("reset_collision_cooldowns", false)), "stopwatch recovery update should request periodic collision-cooldown reset")

	var recovery_finish: Dictionary = runtime.update_state(true, 0.0, 120.0, 1.0, 0.0, original_velocity, 0.0, 6.0, true, 1.0 / 60.0)
	_expect(not bool(recovery_finish.get("active", true)), "stopwatch recovery update should clear after recovery ends")
	_expect(bool(recovery_finish.get("apply_recovery_velocity", false)), "final recovery update should still request velocity ramp")
	_expect(bool(recovery_finish.get("apply_final_recovery_velocity", false)), "final recovery update should request full-speed restore")
	_expect(is_equal_approx(float(recovery_finish.get("recovery_timer_for_velocity", -1.0)), 0.0), "final recovery update should expose zero recovery timer")
	_expect(_get_vector2(recovery_finish, "recovery_original_ball_vel", Vector2.ZERO) == original_velocity, "final recovery update should preserve original velocity for side effects")


func _verify_direct_stopwatch_update_application() -> void:
	var runtime: Object = ActiveItemStopwatchRuntime.new()
	var state_applier: Object = ActiveItemEffectStateApplier.new()
	var owner_effects: Object = ActiveItemStopwatchOwnerEffects.new()
	var target := FakeTarget.new()
	var owner := FakeOwner.new()

	target.stopwatch_active = true
	target.stopwatch_timer_frames = 2.0
	target.stopwatch_initial_timer_frames = 120.0
	target.stopwatch_recovery_timer_frames = 0.0
	target.stopwatch_original_ball_vel = Vector2(10.0, 0.0)
	target.stopwatch_flash_timer_frames = 3.0
	target.stopwatch_clock_angle = 5.0
	owner.ball_vel = Vector2(3.0, -4.0)
	runtime.apply_update(
		target,
		owner,
		target.stopwatch_active,
		target.stopwatch_timer_frames,
		target.stopwatch_initial_timer_frames,
		target.stopwatch_recovery_timer_frames,
		target.stopwatch_post_recovery_grace_frames,
		target.stopwatch_original_ball_vel,
		target.stopwatch_flash_timer_frames,
		target.stopwatch_clock_angle,
		1.0 / 60.0,
		state_applier,
		owner_effects
	)
	_expect(target.stopwatch_active, "stopwatch runtime should apply active freeze state")
	_expect(is_equal_approx(target.stopwatch_timer_frames, 1.0), "stopwatch runtime should apply freeze timer tick")
	_expect(is_equal_approx(target.stopwatch_flash_timer_frames, 2.0), "stopwatch runtime should apply flash tick")
	_expect(is_equal_approx(target.stopwatch_clock_angle, 5.1), "stopwatch runtime should apply clock tick")
	_expect(owner.ball_vel == Vector2.ZERO, "stopwatch runtime should apply owner freeze side effect")

	target.stopwatch_active = true
	target.stopwatch_timer_frames = 0.0
	target.stopwatch_initial_timer_frames = 120.0
	target.stopwatch_recovery_timer_frames = 1.0
	target.stopwatch_original_ball_vel = Vector2(0.0, -20.0)
	owner.ball_vel = Vector2.ZERO
	owner.player_collision_cooldown = 99.0
	owner.boss_collision_cooldown = 99.0
	runtime.apply_update(
		target,
		owner,
		target.stopwatch_active,
		target.stopwatch_timer_frames,
		target.stopwatch_initial_timer_frames,
		target.stopwatch_recovery_timer_frames,
		target.stopwatch_post_recovery_grace_frames,
		target.stopwatch_original_ball_vel,
		target.stopwatch_flash_timer_frames,
		target.stopwatch_clock_angle,
		1.0 / 60.0,
		state_applier,
		owner_effects
	)
	_expect(not target.stopwatch_active, "stopwatch runtime should apply final recovery clear state")
	_expect(is_equal_approx(target.stopwatch_recovery_timer_frames, 0.0), "stopwatch runtime should clear recovery timer")
	_expect(target.stopwatch_original_ball_vel == Vector2.ZERO, "stopwatch runtime should clear stored velocity after final recovery")
	_expect(owner.ball_vel == Vector2(0.0, -20.0), "stopwatch runtime should apply final owner recovery velocity")
	_expect(owner.player_collision_cooldown == 0.0 and owner.boss_collision_cooldown == 0.0, "stopwatch runtime should apply owner cooldown reset")


func _verify_controller_delegates_stopwatch_activation() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	var perk := FakePerkState.new()
	perk.resume_velocity = Vector2(3.0, -9.0)
	var feedback := FakeFeedback.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"runtime_perk_state": perk,
		"battle_feedback_state": feedback,
		"game_audio": audio,
	}

	_expect(controller.activate_stopwatch(owner, registry), "controller should activate stopwatch through runtime helper")
	_expect(controller.stopwatch_active, "controller should apply delegated stopwatch active state")
	_expect(is_equal_approx(controller.stopwatch_timer_frames, 120.0), "controller should apply delegated stopwatch timer")
	_expect(controller.stopwatch_original_ball_vel == Vector2(3.0, -9.0), "controller should apply delegated original velocity")
	_expect(owner.ball_vel == Vector2.ZERO, "controller delegated stopwatch should freeze ball")
	_expect(owner.player_collision_cooldown == 0.0 and owner.boss_collision_cooldown == 0.0, "controller delegated stopwatch should clear collision cooldowns")
	_expect(audio.calls == ["play_timewatch", "play_active_item"], "controller should preserve stopwatch audio cues")
	_expect(feedback.shakes == [Vector2(0.04, 1.25)], "controller should preserve stopwatch feedback shake")

	var blocked_controller: Object = ActiveItemEffectController.new()
	var blocked_owner := FakeOwner.new()
	blocked_owner.ball_pos = Vector2(160.0, 700.0)
	_expect(not blocked_controller.activate_stopwatch(blocked_owner, null), "controller should reject unsafe stopwatch activation")
	_expect(not blocked_controller.stopwatch_active, "blocked controller stopwatch should stay inactive")
	_expect(blocked_owner.ball_vel == Vector2(8.0, -6.0), "blocked controller stopwatch should not mutate ball velocity")


func _verify_controller_delegates_stopwatch_update() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	controller.stopwatch_active = true
	controller.stopwatch_timer_frames = 2.0
	controller.stopwatch_initial_timer_frames = 120.0
	controller.stopwatch_recovery_timer_frames = 0.0
	controller.stopwatch_original_ball_vel = Vector2(10.0, 0.0)
	controller.stopwatch_flash_timer_frames = 3.0
	controller.stopwatch_clock_angle = 5.0
	owner.ball_vel = Vector2(3.0, -4.0)

	controller.update(owner, 1.0 / 60.0)
	_expect(controller.stopwatch_active, "controller stopwatch update should stay active during freeze")
	_expect(is_equal_approx(controller.stopwatch_timer_frames, 1.0), "controller stopwatch update should apply freeze timer tick")
	_expect(is_equal_approx(controller.stopwatch_flash_timer_frames, 2.0), "controller stopwatch update should apply flash tick")
	_expect(is_equal_approx(controller.stopwatch_clock_angle, 5.1), "controller stopwatch update should apply clock tick")
	_expect(owner.ball_vel == Vector2.ZERO, "controller stopwatch update should apply delegated ball-freeze request")

	controller.update(owner, 1.0 / 60.0)
	_expect(controller.stopwatch_active, "controller stopwatch update should remain active at recovery handoff")
	_expect(is_equal_approx(controller.stopwatch_timer_frames, 0.0), "controller stopwatch update should clear freeze timer at handoff")
	_expect(is_equal_approx(controller.stopwatch_recovery_timer_frames, 60.0), "controller stopwatch update should apply recovery handoff")

	controller.stopwatch_active = true
	controller.stopwatch_timer_frames = 0.0
	controller.stopwatch_initial_timer_frames = 120.0
	controller.stopwatch_recovery_timer_frames = 30.0
	controller.stopwatch_original_ball_vel = Vector2(10.0, 0.0)
	owner.ball_vel = Vector2.ZERO
	controller.update(owner, 1.0 / 60.0)
	_expect(is_equal_approx(controller.stopwatch_recovery_timer_frames, 29.0), "controller stopwatch update should apply recovery tick")
	_expect(owner.ball_vel.is_equal_approx(Vector2(10.0 * (31.0 / 60.0), 0.0)), "controller stopwatch update should apply delegated recovery velocity")

	controller.stopwatch_active = true
	controller.stopwatch_timer_frames = 0.0
	controller.stopwatch_initial_timer_frames = 120.0
	controller.stopwatch_recovery_timer_frames = 1.0
	controller.stopwatch_original_ball_vel = Vector2(0.0, -20.0)
	owner.ball_vel = Vector2.ZERO
	owner.player_collision_cooldown = 99.0
	owner.boss_collision_cooldown = 99.0
	controller.update(owner, 1.0 / 60.0)
	_expect(not controller.stopwatch_active, "controller stopwatch update should clear after final recovery tick")
	_expect(is_equal_approx(controller.stopwatch_recovery_timer_frames, 0.0), "controller stopwatch update should clear recovery timer after final tick")
	_expect(controller.stopwatch_original_ball_vel == Vector2.ZERO, "controller stopwatch update should clear stored velocity after final tick")
	_expect(owner.ball_vel == Vector2(0.0, -20.0), "controller stopwatch update should restore final full-speed velocity")
	_expect(owner.player_collision_cooldown == 0.0 and owner.boss_collision_cooldown == 0.0, "controller stopwatch update should apply delegated cooldown reset")


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
