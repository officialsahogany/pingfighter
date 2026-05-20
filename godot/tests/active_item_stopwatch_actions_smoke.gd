extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectFeedback := preload("res://scripts/items/active_item_effect_feedback.gd")
const ActiveItemEffectStateApplier := preload("res://scripts/items/active_item_effect_state_applier.gd")
const ActiveItemPlayerCenterReader := preload("res://scripts/items/active_item_player_center_reader.gd")
const ActiveItemStopwatchActions := preload("res://scripts/items/active_item_stopwatch_actions.gd")
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
	_verify_direct_stopwatch_actions()
	_verify_direct_stopwatch_action_rejections()
	_verify_controller_delegates_stopwatch_actions()

	if _failures.is_empty():
		print("active_item_stopwatch_actions_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_stopwatch_actions() -> void:
	var actions: Object = ActiveItemStopwatchActions.new()
	var target: Object = ActiveItemEffectController.new()
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

	_expect(actions.activate(
		target,
		owner,
		registry,
		false,
		ActiveItemPlayerCenterReader.new(),
		ActiveItemStopwatchRuntime.new(),
		ActiveItemEffectStateApplier.new(),
		ActiveItemEffectFeedback.new()
	), "Stopwatch actions should activate")
	_expect(target.stopwatch_active, "Stopwatch actions should apply active state")
	_expect(is_equal_approx(target.stopwatch_timer_frames, 120.0), "Stopwatch actions should apply freeze timer")
	_expect(target.stopwatch_original_ball_vel == Vector2(3.0, -9.0), "Stopwatch actions should preserve perk resume velocity")
	_expect(owner.ball_vel == Vector2.ZERO, "Stopwatch actions should freeze ball")
	_expect(owner.player_collision_cooldown == 0.0 and owner.boss_collision_cooldown == 0.0, "Stopwatch actions should clear collision cooldowns")
	_expect(perk.consume_calls == 1, "Stopwatch actions should consume perk resume velocity once")
	_expect(audio.calls == ["play_timewatch", "play_active_item"], "Stopwatch actions should play both audio cues")
	_expect(feedback.shakes == [Vector2(0.04, 1.25)], "Stopwatch actions should dispatch reference shake")


func _verify_direct_stopwatch_action_rejections() -> void:
	var actions: Object = ActiveItemStopwatchActions.new()
	var active_target: Object = ActiveItemEffectController.new()
	var active_owner := FakeOwner.new()
	_expect(not actions.activate(
		active_target,
		active_owner,
		null,
		true,
		ActiveItemPlayerCenterReader.new(),
		ActiveItemStopwatchRuntime.new(),
		ActiveItemEffectStateApplier.new(),
		ActiveItemEffectFeedback.new()
	), "Stopwatch actions should reject while active")
	_expect(not active_target.stopwatch_active, "active rejection should not mutate target")
	_expect(active_owner.ball_vel == Vector2(8.0, -6.0), "active rejection should not freeze ball")

	var blocked_target: Object = ActiveItemEffectController.new()
	var blocked_owner := FakeOwner.new()
	blocked_owner.ball_pos = Vector2(160.0, 700.0)
	_expect(not actions.activate(
		blocked_target,
		blocked_owner,
		null,
		false,
		ActiveItemPlayerCenterReader.new(),
		ActiveItemStopwatchRuntime.new(),
		ActiveItemEffectStateApplier.new(),
		ActiveItemEffectFeedback.new()
	), "Stopwatch actions should reject unsafe activation")
	_expect(not blocked_target.stopwatch_active, "unsafe rejection should not mutate target")
	_expect(blocked_owner.ball_vel == Vector2(8.0, -6.0), "unsafe rejection should not freeze ball")


func _verify_controller_delegates_stopwatch_actions() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	var feedback := FakeFeedback.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"battle_feedback_state": feedback,
		"game_audio": audio,
	}

	_expect(controller.activate_stopwatch(owner, registry), "controller should delegate Stopwatch activation")
	_expect(controller.stopwatch_active, "controller delegated Stopwatch should activate")
	_expect(is_equal_approx(controller.stopwatch_timer_frames, 120.0), "controller delegated Stopwatch should set timer")
	_expect(owner.ball_vel == Vector2.ZERO, "controller delegated Stopwatch should freeze ball")
	_expect(audio.calls == ["play_timewatch", "play_active_item"], "controller delegated Stopwatch should preserve audio cues")
	_expect(feedback.shakes == [Vector2(0.04, 1.25)], "controller delegated Stopwatch should preserve feedback")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
