extends SceneTree

const ActiveItemAipillActions := preload("res://scripts/items/active_item_aipill_actions.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectFeedback := preload("res://scripts/items/active_item_effect_feedback.gd")
const ActiveItemEffectStateApplier := preload("res://scripts/items/active_item_effect_state_applier.gd")

var _failures: Array[String] = []


class FakeFeedback:
	extends RefCounted

	var gauge_flashes := 0
	var shakes: Array[Vector2] = []

	func trigger_gauge_flash() -> void:
		gauge_flashes += 1

	func max_screen_shake(amount: float, duration: float) -> void:
		shakes.append(Vector2(amount, duration))


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_active_item() -> void:
		calls.append("play_active_item")


class FakeRegistry:
	extends RefCounted

	var feedback: Object = null
	var audio: Object = null

	func _init(feedback_state: Object = null, audio_state: Object = null) -> void:
		feedback = feedback_state
		audio = audio_state

	func get_instance(key: String) -> Object:
		if key == "battle_feedback_state":
			return feedback
		if key == "game_audio":
			return audio
		return null


func _init() -> void:
	_verify_direct_aipill_actions()
	_verify_controller_delegates_actions()

	if _failures.is_empty():
		print("active_item_aipill_actions_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_aipill_actions() -> void:
	var actions: Object = ActiveItemAipillActions.new()
	var controller: Object = ActiveItemEffectController.new()
	var applier: Object = ActiveItemEffectStateApplier.new()
	var feedback_helper: Object = ActiveItemEffectFeedback.new()
	var activation_feedback := FakeFeedback.new()
	var activation_audio := FakeAudio.new()

	_expect(actions.activate(
		controller,
		FakeRegistry.new(activation_feedback, activation_audio),
		applier,
		feedback_helper
	), "AI Pill action helper should activate")
	_expect(controller.aipill_active, "AI Pill action helper should apply active state")
	_expect(is_equal_approx(controller.aipill_flash_timer_frames, 12.0), "AI Pill action helper should apply activation flash")
	_expect(activation_feedback.gauge_flashes == 1, "AI Pill activation should trigger gauge flash")
	_expect(activation_feedback.shakes == [Vector2(0.035, 1.1)], "AI Pill activation should trigger reference shake")
	_expect(activation_audio.calls == ["play_active_item"], "AI Pill activation should play active-item audio")

	var control_config := {
		"paddle_width": 100.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"ball_pos": Vector2(300.0, 250.0),
		"paddle_speed": 6.0,
		"paddle_max_speed": 6.0,
	}
	var control_result: Dictionary = actions.apply_player_control(true, Vector2.ZERO, control_config, 1.0 / 60.0)
	_expect(control_result.get("player_pos", Vector2.ZERO) == Vector2(24.0, 0.0), "AI Pill action helper should delegate player control")

	controller.aipill_active = true
	controller.aipill_phase = 3.0
	var guard_feedback := FakeFeedback.new()
	var next_gauge: float = actions.apply_guard_drain(
		controller,
		100.0,
		{"selected_character_type": "smasher"},
		{"feedback": guard_feedback},
		controller.aipill_active,
		controller.aipill_phase,
		applier,
		feedback_helper
	)
	_expect(is_equal_approx(next_gauge, 10.0), "AI Pill action helper should apply guard gauge drain")
	_expect(is_equal_approx(controller.aipill_phase, 3.0), "AI Pill guard flash should preserve phase")
	_expect(is_equal_approx(controller.aipill_flash_timer_frames, 12.0), "AI Pill guard flash should reset flash timer")
	_expect(guard_feedback.gauge_flashes == 1, "AI Pill guard drain should trigger gauge flash")
	_expect(guard_feedback.shakes == [Vector2(0.025, 0.9)], "AI Pill guard drain should trigger reference shake")

	next_gauge = actions.apply_guard_drain(
		controller,
		10.0,
		{"selected_character_type": "smasher"},
		{},
		controller.aipill_active,
		controller.aipill_phase,
		applier,
		feedback_helper
	)
	_expect(is_equal_approx(next_gauge, 0.0), "AI Pill action helper should clamp depleted guard gauge")
	_expect(not controller.aipill_active, "AI Pill action helper should clear depleted AI Pill")


func _verify_controller_delegates_actions() -> void:
	var controller: Object = ActiveItemEffectController.new()

	_expect(controller.activate_aipill(null, null), "controller should delegate AI Pill activation")
	_expect(controller.aipill_active, "controller delegated AI Pill activation should set active")

	var gauge: float = controller.apply_aipill_guard_drain(100.0, {"selected_character_type": "smasher"}, {})
	_expect(is_equal_approx(gauge, 10.0), "controller should delegate AI Pill guard drain")
	_expect(is_equal_approx(controller.aipill_flash_timer_frames, 12.0), "controller should apply delegated guard flash")

	var control_config := {
		"paddle_width": 100.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"ball_pos": Vector2(300.0, 250.0),
		"paddle_speed": 6.0,
		"paddle_max_speed": 6.0,
	}
	var control_result: Dictionary = controller.apply_aipill_player_control(Vector2.ZERO, 0.0, control_config, 1.0 / 60.0)
	_expect(control_result.get("player_pos", Vector2.ZERO) == Vector2(24.0, 0.0), "controller should delegate AI Pill player control through actions")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
