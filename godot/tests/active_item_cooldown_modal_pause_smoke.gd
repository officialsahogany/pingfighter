extends SceneTree

const BattleSceneFrameController := preload("res://scripts/core/battle_scene_frame_controller.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = [
		{"name": "long_boost", "cooldown_msec": 10000, "last_use_msec": 1000},
	]

	func queue_redraw() -> void:
		pass

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))


class FakeActiveItemRuntime:
	extends RefCounted

	var pause_calls := 0
	var resume_calls := 0
	var paused_owner: Object = null
	var resumed_owner: Object = null

	func pause_cooldowns(owner: Object = null, _registry: Object = null) -> void:
		pause_calls += 1
		paused_owner = owner

	func resume_cooldowns(owner: Object = null, _registry: Object = null) -> void:
		resume_calls += 1
		resumed_owner = owner


class FakeMythicRuntime:
	extends RefCounted

	var acquisition_active := false

	func is_acquisition_cinematic_active() -> bool:
		return acquisition_active


class FakeGameAudio:
	extends RefCounted

	var stop_calls := 0

	func stop_dash_delay() -> void:
		stop_calls += 1


class FakeUpdateDriver:
	extends RefCounted

	var update_calls := 0

	func update(_owner: Object, _registry: Object, _delta: float) -> void:
		update_calls += 1


class FakeRegistry:
	extends RefCounted

	var active_item_runtime := FakeActiveItemRuntime.new()
	var modal_gate := BattleSceneModalGateController.new()
	var mythic_runtime := FakeMythicRuntime.new()
	var game_audio := FakeGameAudio.new()
	var update_driver := FakeUpdateDriver.new()

	func get_instance(key: String) -> Object:
		match key:
			"active_item_runtime":
				return active_item_runtime
			"battle_scene_modal_gate_controller":
				return modal_gate
			"mythic_item_runtime":
				return mythic_runtime
			"game_audio":
				return game_audio
			"battle_scene_update_driver":
				return update_driver
		return null


func _init() -> void:
	_verify_modal_gate_pauses_active_item_cooldowns()

	if _failures.is_empty():
		print("active_item_cooldown_modal_pause_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_modal_gate_pauses_active_item_cooldowns() -> void:
	var controller: Object = BattleSceneFrameController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var callbacks := {
		"is_battle_initialized": Callable(self, "_return_true"),
		"is_stage_landing_intro_started": Callable(self, "_return_true"),
	}

	registry.mythic_runtime.acquisition_active = true
	controller.process_physics(1.0 / 60.0, owner, registry, Callable(registry, "get_instance"), callbacks)
	_expect(registry.active_item_runtime.pause_calls == 1, "mythic acquisition should pause active item cooldowns")
	_expect(registry.active_item_runtime.paused_owner == owner, "modal cooldown pause should receive the battle owner")
	_expect(registry.game_audio.stop_calls == 1, "mythic acquisition entry should stop gameplay loop audio exactly once")
	_expect(registry.update_driver.update_calls == 0, "mythic acquisition should skip the normal update driver")

	controller.process_physics(1.0 / 60.0, owner, registry, Callable(registry, "get_instance"), callbacks)
	_expect(registry.active_item_runtime.pause_calls == 1, "continued mythic acquisition should not stack active item cooldown pauses")
	_expect(registry.game_audio.stop_calls == 1, "continued mythic acquisition should not restop gameplay loop audio")

	registry.mythic_runtime.acquisition_active = false
	controller.process_physics(1.0 / 60.0, owner, registry, Callable(registry, "get_instance"), callbacks)
	_expect(registry.active_item_runtime.resume_calls == 1, "closing mythic acquisition should resume active item cooldowns once")
	_expect(registry.active_item_runtime.resumed_owner == owner, "modal cooldown resume should receive the battle owner")
	_expect(registry.update_driver.update_calls == 1, "normal update should resume after the modal closes")


func _return_true() -> bool:
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
