extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectFeedback := preload("res://scripts/items/active_item_effect_feedback.gd")

var _failures: Array[String] = []


class FakeFeedback:
	extends RefCounted

	var gauge_flashes := 0
	var dash_flashes := 0
	var shakes: Array[Vector2] = []

	func trigger_gauge_flash() -> void:
		gauge_flashes += 1

	func trigger_dash_flash() -> void:
		dash_flashes += 1

	func max_screen_shake(amount: float, duration: float) -> void:
		shakes.append(Vector2(amount, duration))


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_drink() -> void:
		calls.append("play_drink")

	func play_active_item() -> void:
		calls.append("play_active_item")

	func play_timewatch() -> void:
		calls.append("play_timewatch")

	func play_item_get() -> void:
		calls.append("play_item_get")


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

	var special_gauge := 100.0
	var special_gauge_max := 500.0
	var player_pos := Vector2(100.0, 680.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var ball_pos := Vector2(20.0, 40.0)
	var ball_vel := Vector2(4.0, -6.0)
	var player_collision_cooldown := 99.0
	var boss_collision_cooldown := 99.0


func _init() -> void:
	_verify_direct_feedback_helper()
	_verify_controller_delegates_feedback()

	if _failures.is_empty():
		print("active_item_effect_feedback_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_feedback_helper() -> void:
	var helper: Object = ActiveItemEffectFeedback.new()
	var feedback := FakeFeedback.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(feedback, audio)

	helper.trigger_registry_feedback(registry, true, true, 0.2, 0.7)
	_expect(feedback.gauge_flashes == 1, "feedback helper should trigger gauge flash")
	_expect(feedback.dash_flashes == 1, "feedback helper should trigger dash flash")
	_expect(feedback.shakes == [Vector2(0.2, 0.7)], "feedback helper should preserve shake arguments")

	helper.play_first_audio(registry, ["missing_method", "play_drink", "play_active_item"])
	_expect(audio.calls == ["play_drink"], "first-audio helper should use the first available method")

	helper.play_all_audio(registry, ["play_timewatch", "play_active_item"])
	_expect(audio.calls == ["play_drink", "play_timewatch", "play_active_item"], "all-audio helper should call every available method")

	helper.play_first_audio(null, ["play_item_get"])
	helper.trigger_registry_feedback(null, true, true, 1.0, 1.0)


func _verify_controller_delegates_feedback() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()

	var gauge_feedback := FakeFeedback.new()
	var gauge_audio := FakeAudio.new()
	var gauge_registry := FakeRegistry.new(gauge_feedback, gauge_audio)
	_expect(controller.apply_gauge_charge({"gauge_gain": 10.0}, owner, gauge_registry), "gauge charge should still apply")
	_expect(is_equal_approx(owner.special_gauge, 110.0), "gauge charge should preserve owner gauge mutation")
	_expect(gauge_feedback.gauge_flashes == 1, "gauge charge should delegate gauge flash")
	_expect(gauge_feedback.shakes == [Vector2(0.06, 1.6)], "gauge charge should delegate reference shake")
	_expect(gauge_audio.calls == ["play_drink"], "gauge charge should delegate drink audio")

	var boost_audio := FakeAudio.new()
	_expect(controller.activate_long_boost(owner, FakeRegistry.new(null, boost_audio)), "long boost should still activate")
	_expect(boost_audio.calls == ["play_active_item"], "long boost should prefer active-item audio over drink")

	var stopwatch_feedback := FakeFeedback.new()
	var stopwatch_audio := FakeAudio.new()
	var stopwatch_owner := FakeOwner.new()
	_expect(controller.activate_stopwatch(stopwatch_owner, FakeRegistry.new(stopwatch_feedback, stopwatch_audio)), "stopwatch should still activate")
	_expect(stopwatch_audio.calls == ["play_timewatch", "play_active_item"], "stopwatch should preserve both audio cues")
	_expect(stopwatch_feedback.shakes == [Vector2(0.04, 1.25)], "stopwatch should delegate shake")

	var guard_feedback := FakeFeedback.new()
	controller.aipill_active = true
	var next_gauge: float = controller.apply_aipill_guard_drain(
		100.0,
		{"selected_character_type": "smasher"},
		{"feedback": guard_feedback}
	)
	_expect(is_equal_approx(next_gauge, 10.0), "AI Pill guard drain should preserve gauge drain")
	_expect(guard_feedback.gauge_flashes == 1, "AI Pill guard drain should delegate gauge flash")
	_expect(guard_feedback.shakes == [Vector2(0.025, 0.9)], "AI Pill guard drain should delegate guard shake")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
