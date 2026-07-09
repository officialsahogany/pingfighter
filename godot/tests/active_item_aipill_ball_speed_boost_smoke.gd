extends SceneTree

# AI 알약(aipill) 접촉 공속 부스트 씰:
# 1) 발동 중 플레이어 패들 접촉마다 공속 +25% (behavior/controller 위임)
# 2) 부스트 자체에 내부 상한 없음
# 3) 게이지 소진으로 알약이 꺼지는 "그 히트"도 접촉 시점 캡처로 부스트됨
#    (post_hit_handler 사전 캡처 순서 씰 — 드레인이 부스트보다 먼저 돈다)
# 4) 발동 중 공속 상한 해제 채널: 충돌 컨텍스트 키 방출 + 프레임 클램프 스킵 +
#    바운스 시점 max_ball_speed=INF

const ActiveItemAipillBehavior := preload("res://scripts/items/active_item_aipill_behavior.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemRuntimeContextFacade := preload("res://scripts/items/active_item_runtime_context_facade.gd")
const BallFrameMotionController := preload("res://scripts/ball/ball_frame_motion_controller.gd")
const PaddleBounceVelocityStep := preload("res://scripts/ball/paddle_bounce_velocity_step.gd")
const PaddleBouncePostHitHandler := preload("res://scripts/ball/paddle_bounce_post_hit_handler.gd")

var _failures: Array[String] = []


class RuntimeShell:
	extends RefCounted

	var effect_controller: Object = null


class FakeBallPhysics:
	extends RefCounted

	func enforce_minimum_rally_speed(velocity: Vector2) -> Vector2:
		return velocity

	func get_minimum_effective_boost(_velocity: Vector2) -> float:
		return 1.0


class CapturingPaddleBounceState:
	extends RefCounted

	var captured_max_ball_speed: float = -1.0

	func get_initial_speed(ball_velocity: Vector2) -> float:
		return ball_velocity.length()

	@warning_ignore("unused_parameter")
	func resolve_velocity(
		ball_velocity: Vector2,
		hit_pos: float,
		is_player: bool,
		incoming_dx: float,
		outgoing_direction: float,
		speed: float,
		angle_rad: float,
		drive_activated: bool,
		accel_scale: float,
		vertical_bounce_count: int,
		ball_physics: Object,
		drive_bounce_state: Object,
		current_drive_speed_increase: float,
		current_spin_strength: float,
		min_ball_speed: float,
		max_ball_speed: float
	) -> Dictionary:
		captured_max_ball_speed = max_ball_speed
		return {"ball_vel": ball_velocity}


class FakeAipillRuntime:
	extends RefCounted

	var behavior: Object = ActiveItemAipillBehavior.new()
	var active := true
	var guard_drain_calls := 0
	var boost_calls := 0
	var boost_called_after_drain := false

	func is_aipill_active() -> bool:
		return active

	func apply_aipill_guard_drain(_special_gauge: float, _context: Dictionary, _deps: Dictionary) -> float:
		guard_drain_calls += 1
		# 게이지 소진 → 이번 히트에서 알약이 꺼지는 시나리오를 재현
		active = false
		return 0.0

	func apply_aipill_ball_hit_speed_boost(ball_vel: Vector2, was_active_on_contact: bool = false) -> Dictionary:
		boost_calls += 1
		boost_called_after_drain = guard_drain_calls > 0
		return behavior.build_ball_hit_speed_boost_result(was_active_on_contact or active, ball_vel)


func _init() -> void:
	_verify_behavior_boost()
	_verify_controller_delegation()
	_verify_collision_context_carries_cap_disable_flag()
	_verify_frame_speed_limit_skips_cap_while_flag_active()
	_verify_bounce_velocity_step_uncaps_max_speed()
	_verify_post_hit_player_branch_boosts_even_on_exhausting_hit()
	_verify_post_hit_player_branch_skips_boost_when_inactive()

	if _failures.is_empty():
		print("active_item_aipill_ball_speed_boost_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_behavior_boost() -> void:
	var behavior: Object = ActiveItemAipillBehavior.new()

	var inactive: Dictionary = behavior.build_ball_hit_speed_boost_result(false, Vector2(4.0, -8.0))
	_expect(not bool(inactive.get("boosted", true)), "inactive aipill must not boost the ball")
	_expect(inactive.get("ball_vel", Vector2.ZERO) == Vector2(4.0, -8.0), "inactive aipill must keep the velocity untouched")

	var active: Dictionary = behavior.build_ball_hit_speed_boost_result(true, Vector2(4.0, -8.0))
	_expect(bool(active.get("boosted", false)), "active aipill must boost the ball")
	_expect((active.get("ball_vel", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(5.0, -10.0)), "boost must be exactly +25%")

	# 상한 없음: 이미 리그 상한(26)을 넘는 속도도 그대로 25% 증가해야 한다.
	var over_cap: Dictionary = behavior.build_ball_hit_speed_boost_result(true, Vector2(0.0, -40.0))
	_expect((over_cap.get("ball_vel", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(0.0, -50.0)), "boost must have no internal speed cap")

	var zero: Dictionary = behavior.build_ball_hit_speed_boost_result(true, Vector2.ZERO)
	_expect(not bool(zero.get("boosted", true)), "zero velocity must not report boosted")


func _verify_controller_delegation() -> void:
	var controller: Object = ActiveItemEffectController.new()

	var idle: Dictionary = controller.apply_aipill_ball_hit_speed_boost(Vector2(2.0, -2.0))
	_expect(not bool(idle.get("boosted", true)), "inactive controller must not boost")

	var precaptured: Dictionary = controller.apply_aipill_ball_hit_speed_boost(Vector2(2.0, -2.0), true)
	_expect(bool(precaptured.get("boosted", false)), "pre-captured contact-active flag must boost even when state already cleared")

	controller.aipill_active = true
	var live: Dictionary = controller.apply_aipill_ball_hit_speed_boost(Vector2(2.0, -2.0))
	_expect(bool(live.get("boosted", false)), "active controller must boost")
	_expect((live.get("ball_vel", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(2.5, -2.5)), "controller must delegate the +25% math")


func _verify_collision_context_carries_cap_disable_flag() -> void:
	var facade: Object = ActiveItemRuntimeContextFacade.new()
	var shell := RuntimeShell.new()
	shell.effect_controller = ActiveItemEffectController.new()

	var inactive_context: Dictionary = facade.get_ball_collision_context(shell)
	_expect(
		not inactive_context.has("active_item_aipill_ball_boost_active"),
		"inactive aipill must not emit the cap-disable key (merge-clobber safety)"
	)

	shell.effect_controller.aipill_active = true
	var active_context: Dictionary = facade.get_ball_collision_context(shell)
	_expect(
		bool(active_context.get("active_item_aipill_ball_boost_active", false)),
		"active aipill must emit the cap-disable key into the ball collision context"
	)


func _verify_frame_speed_limit_skips_cap_while_flag_active() -> void:
	var controller: Object = BallFrameMotionController.new()
	var deps := {"ball_physics": FakeBallPhysics.new()}
	var scene := {
		"ball_vel": Vector2(0.0, 40.0),
		"ball_impact_boost": 1.0,
		"max_ball_speed": 26.0,
		"impact_boost_max_ball_speed": 26.0,
		"active_item_aipill_ball_boost_active": true,
	}
	controller.apply_ball_speed_limits(scene, deps)
	var uncapped_vel: Vector2 = scene.get("ball_vel", Vector2.ZERO)
	_expect(uncapped_vel.is_equal_approx(Vector2(0.0, 40.0)), "per-frame cap must be disabled while the aipill boost flag is on")

	scene["active_item_aipill_ball_boost_active"] = false
	controller.apply_ball_speed_limits(scene, deps)
	var capped_vel: Vector2 = scene.get("ball_vel", Vector2.ZERO)
	_expect(capped_vel.length() <= 26.0 + 0.001, "per-frame cap must re-engage once the aipill flag drops")


func _verify_bounce_velocity_step_uncaps_max_speed() -> void:
	var step: Object = PaddleBounceVelocityStep.new()
	var frame := {
		"accel_scale": 1.0,
		"vertical_bounce_count": 0,
		"drive_speed_increase": 0.0,
		"ball_spin_strength": 0.0,
	}

	var boosted_state := CapturingPaddleBounceState.new()
	step.apply(
		boosted_state, null, Vector2(0.0, 10.0), 0.0, true, 0.0, -1.0, 10.0, 0.0, false,
		frame, null, {}, {"active_item_aipill_ball_boost_active": true}
	)
	_expect(boosted_state.captured_max_ball_speed == INF, "bounce-time max speed must be INF while the aipill flag is on")

	var capped_state := CapturingPaddleBounceState.new()
	step.apply(
		capped_state, null, Vector2(0.0, 10.0), 0.0, true, 0.0, -1.0, 10.0, 0.0, false,
		frame, null, {}, {}
	)
	_expect(
		is_equal_approx(capped_state.captured_max_ball_speed, 20.0),
		"bounce-time max speed must stay at the default cap without the flag"
	)


func _verify_post_hit_player_branch_boosts_even_on_exhausting_hit() -> void:
	var handler: Object = PaddleBouncePostHitHandler.new()
	var runtime := FakeAipillRuntime.new()
	var ball_vel := Vector2(3.0, -12.0)
	var result: Dictionary = _apply_player_post_hit(handler, runtime, ball_vel)

	_expect(runtime.guard_drain_calls == 1, "player hit during aipill must route the guard drain")
	_expect(runtime.boost_calls == 1, "player hit during aipill must call the ball-hit speed boost")
	_expect(
		runtime.boost_called_after_drain,
		"boost must run after the guard drain (pre-capture ordering is what this smoke seals)"
	)
	var out_vel: Vector2 = result.get("ball_vel", Vector2.ZERO)
	_expect(
		out_vel.is_equal_approx(ball_vel * 1.25),
		"the gauge-exhausting hit must still boost +25% via the pre-captured contact-active state"
	)


func _verify_post_hit_player_branch_skips_boost_when_inactive() -> void:
	var handler: Object = PaddleBouncePostHitHandler.new()
	var runtime := FakeAipillRuntime.new()
	runtime.active = false
	var ball_vel := Vector2(3.0, -12.0)
	var result: Dictionary = _apply_player_post_hit(handler, runtime, ball_vel)

	_expect(runtime.boost_calls == 0, "player hit without aipill must not call the speed boost")
	var out_vel: Vector2 = result.get("ball_vel", Vector2.ZERO)
	_expect(out_vel.is_equal_approx(ball_vel), "player hit without aipill must keep the resolved velocity")


func _apply_player_post_hit(handler: Object, runtime: Object, ball_vel: Vector2) -> Dictionary:
	var context := {
		"selected_character_type": "smasher",
		"player_y": 710.0,
		"ball_size": 28.6,
		"player_speed": 0.0,
		"boss_vel": 0.0,
		"gauge_charge_per_hit": 25.0,
		"gauge_max": 500.0,
	}
	return handler.apply(
		true,
		Vector2(380.0, 700.0),
		ball_vel,
		0.0,
		155.0,
		false,
		false,
		false,
		0.0,
		0.0,
		false,
		false,
		90.0,
		context,
		{"active_item_runtime": runtime}
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
