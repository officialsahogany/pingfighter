extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectFeedback := preload("res://scripts/items/active_item_effect_feedback.gd")
const ActiveItemEffectStateApplier := preload("res://scripts/items/active_item_effect_state_applier.gd")
const ActiveItemPaddleSync := preload("res://scripts/items/active_item_paddle_sync.gd")
const ActiveItemTimedPaddleActivation := preload("res://scripts/items/active_item_timed_paddle_activation.gd")

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

	func play_drink() -> void:
		calls.append("play_drink")

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


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(100.0, 680.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var runtime_paddle_scale := 1.0


func _init() -> void:
	_verify_direct_timed_paddle_activation()
	_verify_controller_delegates_activation()

	if _failures.is_empty():
		print("active_item_timed_paddle_activation_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_timed_paddle_activation() -> void:
	var activation: Object = ActiveItemTimedPaddleActivation.new()
	var state_applier: Object = ActiveItemEffectStateApplier.new()
	var paddle_sync: Object = ActiveItemPaddleSync.new()
	var feedback_helper: Object = ActiveItemEffectFeedback.new()
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()

	var vitamin_feedback := FakeFeedback.new()
	var vitamin_audio := FakeAudio.new()
	_expect(activation.activate_vitamin_pill(
		controller,
		FakeRegistry.new(vitamin_feedback, vitamin_audio),
		false,
		Vector2(160.0, 705.0),
		state_applier,
		feedback_helper
	), "vitamin activation helper should activate from inactive state")
	_expect(controller.vitamin_pill_active, "vitamin activation helper should apply active state")
	_expect(controller.vitamin_pill_player_center == Vector2(160.0, 705.0), "vitamin activation helper should preserve player center")
	_expect(vitamin_feedback.gauge_flashes == 1, "vitamin activation helper should trigger gauge flash")
	_expect(vitamin_feedback.shakes == [Vector2(0.025, 0.9)], "vitamin activation helper should trigger reference shake")
	_expect(vitamin_audio.calls == ["play_drink"], "vitamin activation helper should prefer drink audio")
	_expect(not activation.activate_vitamin_pill(controller, null, true, Vector2.ZERO, state_applier, feedback_helper), "vitamin activation helper should reject already-active state")

	var long_audio := FakeAudio.new()
	_expect(activation.activate_long_boost(
		controller,
		owner,
		FakeRegistry.new(null, long_audio),
		false,
		state_applier,
		paddle_sync,
		feedback_helper
	), "long boost activation helper should activate from inactive state")
	_expect(controller.long_boost_active, "long boost activation helper should apply active state")
	_expect(long_audio.calls == ["play_active_item"], "long boost activation helper should prefer active-item audio")

	var vial_feedback := FakeFeedback.new()
	var vial_audio := FakeAudio.new()
	_expect(activation.activate_strange_vial(
		controller,
		owner,
		FakeRegistry.new(vial_feedback, vial_audio),
		true,
		Vector2(180.0, 700.0),
		false,
		state_applier,
		paddle_sync,
		feedback_helper
	), "strange vial activation helper should restart even while active")
	_expect(controller.strange_vial_active, "strange vial activation helper should apply active state")
	_expect(str(controller.strange_vial_effect_type) == "shrink", "strange vial activation helper should preserve chosen effect")
	_expect(vial_feedback.gauge_flashes == 1, "strange vial activation helper should trigger gauge flash")
	_expect(vial_audio.calls == ["play_drink"], "strange vial activation helper should prefer drink audio")


func _verify_controller_delegates_activation() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()

	_expect(controller.activate_long_boost(owner, null), "controller should delegate long boost activation")
	_expect(not controller.activate_long_boost(owner, null), "controller should preserve long boost active gate")

	_expect(controller.activate_vitamin_pill(owner, null), "controller should delegate vitamin activation")
	_expect(not controller.activate_vitamin_pill(owner, null), "controller should preserve vitamin active gate")

	seed(5)
	_expect(controller.activate_strange_vial(owner, null), "controller should delegate strange vial activation")
	_expect(controller.strange_vial_effect_type in ["enlarge", "shrink"], "controller should preserve strange vial random effect choice")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
