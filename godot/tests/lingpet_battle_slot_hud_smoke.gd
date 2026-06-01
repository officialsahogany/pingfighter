extends SceneTree

const BattleSceneInputController := preload("res://scripts/core/battle_scene_input_controller.gd")
const LingpetBattleSlotHud := preload("res://scripts/hud/lingpet_battle_slot_hud.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraws := 0

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 900.0))

	func queue_redraw() -> void:
		redraws += 1


class FakeRuntime:
	extends RefCounted

	var switched_slots: Array[int] = []
	var cycled_directions: Array[int] = []
	var switch_result := true
	var cycle_result := true

	func switch_lingpet_slot(slot_index: int, _owner: Object = null) -> bool:
		switched_slots.append(slot_index)
		return switch_result

	func cycle_lingpet_slot(direction: int = 1, _owner: Object = null) -> bool:
		cycled_directions.append(direction)
		return cycle_result

	func get_snapshot() -> Dictionary:
		return {
			"battle_slot_pet_ids": ["maribo", "", ""],
			"active_slot_index": 0,
		}


class FakeReadiness:
	extends RefCounted

	func is_intro_or_warmup_blocking(_module_getter: Callable, _battle_initialized: bool, _stage_landing_intro_started: bool) -> bool:
		return false


class FakeViewLayout:
	extends RefCounted

	func build_game_layout(_view_size: Vector2, _width: float, _height: float) -> Dictionary:
		return {
			"game_offset": Vector2(140.0, 0.0),
			"game_size": Vector2(912.0, 900.0),
		}


class FakeRegistry:
	extends RefCounted

	var instances := {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		if value is Object:
			return value
		return null


func _init() -> void:
	_verify_lingpet_cycle_key_avoids_item_number_keys()
	_verify_click_switch_uses_shared_slot_rect()
	_verify_renderer_and_input_are_wired()
	if _failures.is_empty():
		print("lingpet_battle_slot_hud_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_lingpet_cycle_key_avoids_item_number_keys() -> void:
	var owner := FakeOwner.new()
	var runtime := FakeRuntime.new()
	var registry := _make_registry(runtime)
	var input := BattleSceneInputController.new()
	input.handle_unhandled_input(
		_key_event(KEY_8),
		owner,
		registry,
		Callable(registry, "get_instance"),
		{"battle_initialized": true, "stage_landing_intro_started": true}
	)
	_expect(runtime.switched_slots.is_empty(), "KEY_8 should stay reserved for future active-item slots")
	_expect(runtime.cycled_directions.is_empty(), "KEY_8 should not cycle lingpet slots")
	_expect(owner.redraws == 0, "ignored item number key should not request redraw")

	input.handle_unhandled_input(
		_key_event(KEY_L),
		owner,
		registry,
		Callable(registry, "get_instance"),
		{"battle_initialized": true, "stage_landing_intro_started": true}
	)
	_expect(runtime.cycled_directions == [1], "KEY_L should cycle to the next occupied lingpet battle slot")
	_expect(runtime.switched_slots.is_empty(), "KEY_L should use runtime cycle logic instead of direct numeric slot switching")
	_expect(owner.redraws == 1, "successful lingpet cycle key should request redraw")


func _verify_click_switch_uses_shared_slot_rect() -> void:
	var owner := FakeOwner.new()
	var runtime := FakeRuntime.new()
	var registry := _make_registry(runtime)
	var input := BattleSceneInputController.new()
	var rects := LingpetBattleSlotHud.build_slot_rects(
		Vector2(140.0, 0.0),
		Vector2(912.0, 900.0),
		{"height": 750.0}
	)
	input.handle_unhandled_input(
		_mouse_click(rects[2].get_center()),
		owner,
		registry,
		Callable(registry, "get_instance"),
		{"battle_initialized": true, "stage_landing_intro_started": true}
	)
	_expect(runtime.switched_slots == [2], "left-click inside the third drawn lingpet slot should switch slot 2")


func _verify_renderer_and_input_are_wired() -> void:
	var hud_source := FileAccess.get_file_as_string("res://scripts/hud/stage1_pillar_ui_renderer.gd")
	var input_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_input_controller.gd")
	_expect(hud_source.find("lingpet_battle_slot_hud.gd") >= 0, "pillar HUD renderer should preload the lingpet battle slot HUD helper")
	_expect(hud_source.find("LingpetBattleSlotHud.draw") >= 0, "pillar HUD renderer should draw the lingpet battle slots")
	_expect(input_source.find("LingpetBattleSlotHud.get_cycle_direction_for_key") >= 0, "battle input should route the lingpet cycle key through the shared slot helper")
	_expect(input_source.find("cycle_lingpet_slot") >= 0, "battle input should cycle lingpets instead of consuming active-item number keys")
	_expect(input_source.find("LingpetBattleSlotHud.get_slot_index_at_position") >= 0, "battle input should route mouse clicks through the shared lingpet slot helper")


func _make_registry(runtime: Object) -> FakeRegistry:
	return FakeRegistry.new({
		"lingpet_egg_runtime": runtime,
		"battle_scene_readiness_controller": FakeReadiness.new(),
		"battle_view_layout": FakeViewLayout.new(),
	})


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode as Key
	event.physical_keycode = keycode as Key
	return event


func _mouse_click(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
