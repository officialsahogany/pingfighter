extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectFeedback := preload("res://scripts/items/active_item_effect_feedback.gd")
const ActiveItemEffectStateApplier := preload("res://scripts/items/active_item_effect_state_applier.gd")
const ActiveItemHolyBarrierActions := preload("res://scripts/items/active_item_holy_barrier_actions.gd")
const ActiveItemHolyBarrierRuntime := preload("res://scripts/items/active_item_holy_barrier_runtime.gd")

var _failures: Array[String] = []


class FakeFeedback:
	extends RefCounted

	var shakes: Array[Vector2] = []

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
	_verify_direct_holy_barrier_actions()
	_verify_controller_delegates_holy_barrier_actions()

	if _failures.is_empty():
		print("active_item_holy_barrier_actions_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_holy_barrier_actions() -> void:
	var target: Object = ActiveItemEffectController.new()
	target.holy_barrier_active = true
	target.holy_barrier_timer_frames = 12.0
	target.holy_barrier_glow_phase = 3.5
	target.holy_barrier_particles.append({"alpha": 1.0})
	var feedback := FakeFeedback.new()
	var audio := FakeAudio.new()

	_expect(_activate(target, FakeRegistry.new(feedback, audio)), "Holy Barrier actions should activate")
	_expect(target.holy_barrier_active, "Holy Barrier actions should apply active state")
	_expect(is_equal_approx(target.holy_barrier_timer_frames, 360.0), "Holy Barrier actions should apply reference duration")
	_expect(is_equal_approx(target.holy_barrier_initial_timer_frames, 360.0), "Holy Barrier actions should set initial duration")
	_expect(is_equal_approx(target.holy_barrier_glow_phase, 0.0), "Holy Barrier actions should reset glow phase")
	_expect(is_equal_approx(target.holy_barrier_particle_accumulator_frames, 0.0), "Holy Barrier actions should reset particle accumulator")
	_expect(target.holy_barrier_particles.is_empty(), "Holy Barrier actions should clear stale particles")
	_expect(feedback.shakes == [Vector2(0.035, 1.05)], "Holy Barrier actions should dispatch reference shake")
	_expect(audio.calls == ["play_active_item"], "Holy Barrier actions should play active-item audio")


func _verify_controller_delegates_holy_barrier_actions() -> void:
	var controller: Object = ActiveItemEffectController.new()
	controller.holy_barrier_particles.append({"alpha": 1.0})
	var feedback := FakeFeedback.new()
	var audio := FakeAudio.new()

	_expect(controller.activate_holy_barrier(null, FakeRegistry.new(feedback, audio)), "controller should delegate Holy Barrier activation")
	_expect(controller.holy_barrier_active, "controller delegated Holy Barrier should activate")
	_expect(is_equal_approx(controller.holy_barrier_timer_frames, 360.0), "controller delegated Holy Barrier should set duration")
	_expect(is_equal_approx(controller.holy_barrier_glow_phase, 0.0), "controller delegated Holy Barrier should reset glow")
	_expect(controller.holy_barrier_particles.is_empty(), "controller delegated Holy Barrier should clear stale particles")
	_expect(feedback.shakes == [Vector2(0.035, 1.05)], "controller delegated Holy Barrier should preserve feedback")
	_expect(audio.calls == ["play_active_item"], "controller delegated Holy Barrier should preserve audio cue")


func _activate(target: Object, registry: Object) -> bool:
	return ActiveItemHolyBarrierActions.new().activate(
		target,
		registry,
		ActiveItemHolyBarrierRuntime.new(),
		ActiveItemEffectStateApplier.new(),
		ActiveItemEffectFeedback.new()
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
