extends SceneTree

const BattleSceneInputController := preload("res://scripts/core/battle_scene_input_controller.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const BattleSceneOverlayInputController := preload("res://scripts/core/battle_scene_overlay_input_controller.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraws := 0

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))

	func queue_redraw() -> void:
		redraws += 1


class FakeReadiness:
	extends RefCounted

	func is_intro_or_warmup_blocking(_module_getter: Callable, _battle_initialized: bool, _stage_landing_intro_started: bool) -> bool:
		return false


class FakeRuntimePerkState:
	extends RefCounted

	var active := false
	var input_count := 0

	func is_choice_active() -> bool:
		return active

	func handle_input(_event: InputEvent, _owner: Object, _registry: Object, _view_size: Vector2) -> bool:
		input_count += 1
		return true


class FakeMythicItemRuntime:
	extends RefCounted

	var active := false
	var input_count := 0

	func is_acquisition_cinematic_active() -> bool:
		return active

	func handle_acquisition_cinematic_input(_event: InputEvent, _registry: Object = null) -> bool:
		input_count += 1
		return true


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return _as_object(instances.get(key, null))

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)

	func _as_object(value: Variant) -> Object:
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
		return null


func _init() -> void:
	_verify_runtime_perk_choice_beats_mythic_acquisition_input()
	_verify_mythic_acquisition_still_receives_input_when_perk_closed()

	if _failures.is_empty():
		print("battle_scene_modal_overlap_input_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_runtime_perk_choice_beats_mythic_acquisition_input() -> void:
	var owner := FakeOwner.new()
	var perk_state := FakeRuntimePerkState.new()
	perk_state.active = true
	var mythic_runtime := FakeMythicItemRuntime.new()
	mythic_runtime.active = true
	var registry := _build_registry(perk_state, mythic_runtime)

	BattleSceneInputController.new().handle_unhandled_input(
		_mouse_click(Vector2(300.0, 300.0)),
		owner,
		registry,
		Callable(registry, "get_instance"),
		_context()
	)

	_expect(perk_state.input_count == 1, "runtime perk choice should receive click input while mythic acquisition is also active")
	_expect(mythic_runtime.input_count == 0, "mythic acquisition cinematic should not starve an active runtime perk choice")
	_expect(owner.redraws >= 1, "overlap input should request a redraw after routing to the perk modal")


func _verify_mythic_acquisition_still_receives_input_when_perk_closed() -> void:
	var owner := FakeOwner.new()
	var perk_state := FakeRuntimePerkState.new()
	perk_state.active = false
	var mythic_runtime := FakeMythicItemRuntime.new()
	mythic_runtime.active = true
	var registry := _build_registry(perk_state, mythic_runtime)

	BattleSceneInputController.new().handle_unhandled_input(
		_mouse_click(Vector2(300.0, 300.0)),
		owner,
		registry,
		Callable(registry, "get_instance"),
		_context()
	)

	_expect(perk_state.input_count == 0, "closed runtime perk choice should not consume mythic acquisition clicks")
	_expect(mythic_runtime.input_count == 1, "standalone mythic acquisition cinematic should keep its click input path")
	_expect(owner.redraws >= 1, "standalone mythic input should still request redraw")


func _build_registry(perk_state: Object, mythic_runtime: Object) -> FakeRegistry:
	return FakeRegistry.new({
		"battle_scene_modal_gate_controller": BattleSceneModalGateController.new(),
		"battle_scene_overlay_input_controller": BattleSceneOverlayInputController.new(),
		"battle_scene_readiness_controller": FakeReadiness.new(),
		"runtime_perk_state": perk_state,
		"mythic_item_runtime": mythic_runtime,
	})


func _context() -> Dictionary:
	return {
		"battle_initialized": true,
		"stage_landing_intro_started": true,
		"mobile_touch_scene_ready": true,
	}


func _mouse_click(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
