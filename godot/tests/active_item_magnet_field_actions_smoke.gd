extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectFeedback := preload("res://scripts/items/active_item_effect_feedback.gd")
const ActiveItemEffectStateApplier := preload("res://scripts/items/active_item_effect_state_applier.gd")
const ActiveItemMagnetFieldActions := preload("res://scripts/items/active_item_magnet_field_actions.gd")
const ActiveItemMagnetFieldRuntime := preload("res://scripts/items/active_item_magnet_field_runtime.gd")
const ActiveItemPlayerCenterReader := preload("res://scripts/items/active_item_player_center_reader.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(100.0, 600.0)
	var player_paddle_width := 120.0
	var player_paddle_height := 40.0


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
	_verify_direct_magnet_field_actions()
	_verify_direct_magnet_field_action_rejections()
	_verify_controller_delegates_magnet_field_actions()

	if _failures.is_empty():
		print("active_item_magnet_field_actions_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_magnet_field_actions() -> void:
	var target: Object = ActiveItemEffectController.new()
	target.magnet_field_particles.append({"alpha": 1.0})
	var feedback := FakeFeedback.new()
	var audio := FakeAudio.new()

	_expect(_activate(target, FakeOwner.new(), false, FakeRegistry.new(feedback, audio)), "Magnet Field actions should activate")
	_expect(target.magnet_field_active, "Magnet Field actions should apply active state")
	_expect(is_equal_approx(target.magnet_field_timer_frames, 480.0), "Magnet Field actions should apply reference duration")
	_expect(target.magnet_field_player_center == Vector2(160.0, 620.0), "Magnet Field actions should snapshot player center")
	_expect(target.magnet_field_particles.is_empty(), "Magnet Field actions should clear stale particles on activation")
	_expect(audio.calls == ["play_active_item"], "Magnet Field actions should play active-item audio")
	_expect(feedback.shakes == [Vector2(0.035, 1.1)], "Magnet Field actions should dispatch reference shake")


func _verify_direct_magnet_field_action_rejections() -> void:
	var active_target: Object = ActiveItemEffectController.new()
	var active_audio := FakeAudio.new()
	_expect(not _activate(active_target, FakeOwner.new(), true, FakeRegistry.new(null, active_audio)), "Magnet Field actions should reject while active")
	_expect(not active_target.magnet_field_active, "active rejection should not mutate target")
	_expect(active_audio.calls.is_empty(), "active rejection should not play audio")

	var null_owner_target: Object = ActiveItemEffectController.new()
	var null_owner_audio := FakeAudio.new()
	_expect(not _activate(null_owner_target, null, false, FakeRegistry.new(null, null_owner_audio)), "Magnet Field actions should reject missing owner")
	_expect(not null_owner_target.magnet_field_active, "missing-owner rejection should not mutate target")
	_expect(null_owner_audio.calls.is_empty(), "missing-owner rejection should not play audio")


func _verify_controller_delegates_magnet_field_actions() -> void:
	var controller: Object = ActiveItemEffectController.new()
	controller.magnet_field_particles.append({"alpha": 1.0})
	var feedback := FakeFeedback.new()
	var audio := FakeAudio.new()

	_expect(controller.activate_magnet_field(FakeOwner.new(), FakeRegistry.new(feedback, audio)), "controller should delegate Magnet Field activation")
	_expect(controller.magnet_field_active, "controller delegated Magnet Field should activate")
	_expect(is_equal_approx(controller.magnet_field_timer_frames, 480.0), "controller delegated Magnet Field should set duration")
	_expect(controller.magnet_field_player_center == Vector2(160.0, 620.0), "controller delegated Magnet Field should snapshot center")
	_expect(controller.magnet_field_particles.is_empty(), "controller delegated Magnet Field should clear stale particles")
	_expect(audio.calls == ["play_active_item"], "controller delegated Magnet Field should preserve audio cue")
	_expect(feedback.shakes == [Vector2(0.035, 1.1)], "controller delegated Magnet Field should preserve feedback")


func _activate(target: Object, owner: Object, active: bool, registry: Object) -> bool:
	return ActiveItemMagnetFieldActions.new().activate(
		target,
		owner,
		registry,
		active,
		ActiveItemPlayerCenterReader.new(),
		ActiveItemMagnetFieldRuntime.new(),
		ActiveItemEffectStateApplier.new(),
		ActiveItemEffectFeedback.new()
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
