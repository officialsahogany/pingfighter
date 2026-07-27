extends SceneTree

const BattleSceneInputController := preload("res://scripts/core/battle_scene_input_controller.gd")

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
	var companion_click_positions: Array[Vector2] = []
	var switch_result := true
	var cycle_result := true
	var companion_click_result := false

	func switch_lingpet_slot(slot_index: int, _owner: Object = null, _registry: Object = null) -> bool:
		switched_slots.append(slot_index)
		return switch_result

	func cycle_lingpet_slot(direction: int = 1, _owner: Object = null, _registry: Object = null) -> bool:
		cycled_directions.append(direction)
		return cycle_result

	func try_begin_companion_click_reaction(playfield_pos: Vector2, _registry: Object = null) -> bool:
		companion_click_positions.append(playfield_pos)
		return companion_click_result

	func get_snapshot() -> Dictionary:
		return {
			"battle_slot_pet_ids": ["maribo", "", ""],
			"active_slot_index": 0,
		}


class FakeReadiness:
	extends RefCounted

	func is_intro_or_warmup_blocking(_module_getter: Callable, _battle_initialized: bool, _stage_landing_intro_started: bool) -> bool:
		return false


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
	_verify_lingpet_slot_click_hud_is_removed()
	_verify_lingpet_companion_click_uses_playfield_coordinates()
	_verify_renderer_and_input_hide_battle_slot_hud()
	if _failures.is_empty():
		print("lingpet_battle_slot_hud_removed_smoke: ok")
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

	input.handle_unhandled_input(
		_key_event(KEY_L, true),
		owner,
		registry,
		Callable(registry, "get_instance"),
		{"battle_initialized": true, "stage_landing_intro_started": true}
	)
	_expect(runtime.cycled_directions == [1, -1], "Shift+L should cycle to the previous occupied lingpet battle slot")
	_expect(runtime.switched_slots.is_empty(), "Shift+L should also use cycle logic instead of direct numeric slot switching")
	_expect(owner.redraws == 2, "successful reverse lingpet cycle key should request redraw")


func _verify_lingpet_slot_click_hud_is_removed() -> void:
	var owner := FakeOwner.new()
	var runtime := FakeRuntime.new()
	var registry := _make_registry(runtime)
	var input := BattleSceneInputController.new()
	input.handle_unhandled_input(
		_mouse_click(Vector2(88.0, 518.0)),
		owner,
		registry,
		Callable(registry, "get_instance"),
		{"battle_initialized": true, "stage_landing_intro_started": true}
	)
	_expect(runtime.switched_slots.is_empty(), "battle-screen lingpet slot clicks should be removed with the visible slot HUD")
	_expect(runtime.companion_click_positions.is_empty(), "removed lingpet slot HUD click area should not trigger the companion click reaction")
	_expect(owner.redraws == 0, "removed lingpet slot HUD click area should not request redraw")


func _verify_lingpet_companion_click_uses_playfield_coordinates() -> void:
	var owner := FakeOwner.new()
	var runtime := FakeRuntime.new()
	runtime.companion_click_result = true
	var registry := _make_registry(runtime)
	var input := BattleSceneInputController.new()
	input.handle_unhandled_input(
		_mouse_click(Vector2(260.0 + 250.0, 75.0 + 245.0)),
		owner,
		registry,
		Callable(registry, "get_instance"),
		{"battle_initialized": true, "stage_landing_intro_started": true}
	)
	_expect(runtime.companion_click_positions.size() == 1, "clicking the in-playfield companion should ask the runtime to begin its reaction")
	if runtime.companion_click_positions.size() == 1:
		_expect(runtime.companion_click_positions[0] == Vector2(250.0, 245.0), "companion click should convert screen coords back into playfield coords")
	_expect(runtime.switched_slots.is_empty(), "companion click should not use the old slot-switch click path")
	_expect(owner.redraws == 1, "successful companion click reaction should request redraw")


func _verify_renderer_and_input_hide_battle_slot_hud() -> void:
	var hud_source := FileAccess.get_file_as_string("res://scripts/hud/stage1_pillar_ui_renderer.gd")
	var input_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_input_controller.gd")
	var lingpet_input_source := FileAccess.get_file_as_string("res://scripts/core/battle_lingpet_interaction_input_router.gd")
	_expect(hud_source.find("lingpet_battle_slot_hud.gd") < 0, "pillar HUD renderer should not preload the removed lingpet battle slot HUD helper")
	_expect(hud_source.find("LingpetBattleSlotHud.draw") < 0, "pillar HUD renderer should not draw the lingpet battle slot list")
	_expect(not FileAccess.file_exists("res://scripts/hud/lingpet_battle_slot_hud.gd"), "lingpet battle slot HUD helper should be removed from the battle UI")
	_expect(input_source.find("lingpet_battle_slot_hud.gd") < 0, "battle input should not depend on the removed lingpet battle slot HUD helper")
	_expect(input_source.find("BattleLingpetInteractionInputRouter") >= 0, "battle input should delegate lingpet interactions to the focused router")
	_expect(lingpet_input_source.find("_get_lingpet_cycle_direction") >= 0, "lingpet input router should keep the non-number-key lingpet cycle shortcut")
	_expect(lingpet_input_source.find("cycle_lingpet_slot") >= 0, "lingpet input router should cycle lingpets instead of consuming active-item number keys")
	_expect(input_source.find("get_slot_index_at_position") < 0, "battle input should not keep hidden mouse hit-areas for the removed slot HUD")


func _make_registry(runtime: Object) -> FakeRegistry:
	return FakeRegistry.new({
		"lingpet_egg_runtime": runtime,
		"battle_scene_readiness_controller": FakeReadiness.new(),
	})


func _key_event(keycode: Key, shift_pressed: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode as Key
	event.physical_keycode = keycode as Key
	event.shift_pressed = shift_pressed
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
