extends SceneTree

const BattleSceneOverlayInputController := preload("res://scripts/core/battle_scene_overlay_input_controller.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const GameplayCoreModuleCatalog := preload("res://scripts/resources/gameplay_core_module_catalog.gd")
const LingpetDebugPicker := preload("res://scripts/core/lingpet_debug_picker.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraws := 0
	var ai_mode := "junior league"
	var selected_character_type := "smasher"
	var player_pos := Vector2(263.75, 675.0)
	var player_paddle_width := 232.5
	var player_paddle_height := 75.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var ball_active := false
	var ball_pos := Vector2.ZERO
	var ball_vel := Vector2.ZERO
	var ball_size := 28.6
	var special_gauge := 100.0
	var special_gauge_max := 500.0
	var lingpet_id := ""
	var active_lingpet_id := ""
	var current_lingpet_id := ""
	var lingpet_state := "none"
	var ringpet_state := "none"
	var lingpet_hatch_hits := 0
	var ringpet_hatch_hits := 0
	var lingpet_hatch_required_hits := 3
	var ringpet_hatch_required_hits := 3
	var lingpet_egg_pos := Vector2.ZERO
	var lingpet_companion_pos := Vector2.ZERO
	var ringpet_companion_pos := Vector2.ZERO
	var lingpet_companion_patrol_speed_default := 120.0
	var ringpet_companion_patrol_speed_default := 120.0
	var lingpet_companion_patrol_speed_min := 70.0
	var ringpet_companion_patrol_speed_min := 70.0
	var lingpet_companion_patrol_speed_max := 135.0
	var ringpet_companion_patrol_speed_max := 135.0
	var lingpet_companion_catch_width := 100.0
	var ringpet_companion_catch_width := 100.0
	var lingpet_companion_catch_height := 44.0
	var ringpet_companion_catch_height := 44.0
	var lingpet_companion_defense_rate := 0.0
	var ringpet_companion_defense_rate := 0.0
	var lingpet_companion_defense_intercept_active := false
	var ringpet_companion_defense_intercept_active := false
	var lingpet_companion_defense_intercept_target_x := 0.0
	var ringpet_companion_defense_intercept_target_x := 0.0
	var lingpet_companion_contact_count := 0
	var ringpet_companion_contact_count := 0
	var lingpet_companion_last_contact_pos := Vector2.ZERO
	var ringpet_companion_last_contact_pos := Vector2.ZERO
	var lingpet_companion_hit_cooldown := 0.0
	var ringpet_companion_hit_cooldown := 0.0
	var lingpet_companion_hit_gauge_gain := 0.0
	var ringpet_companion_hit_gauge_gain := 0.0
	var lingpet_companion_hit_gauge_last_gain := 0.0
	var ringpet_companion_hit_gauge_last_gain := 0.0
	var lingpet_companion_hit_gauge_trigger_count := 0
	var ringpet_companion_hit_gauge_trigger_count := 0
	var lingpet_skill_id := ""
	var ringpet_skill_id := ""
	var lingpet_active_skill_id := ""
	var ringpet_active_skill_id := ""
	var lingpet_skill_name := ""
	var ringpet_skill_name := ""
	var lingpet_skill_cooldown := 0.0
	var ringpet_skill_cooldown := 0.0
	var lingpet_skill_cooldown_duration := 40.0
	var ringpet_skill_cooldown_duration := 40.0
	var lingpet_skill_ready := false
	var ringpet_skill_ready := false
	var lingpet_skill_last_gain := 0.0
	var ringpet_skill_last_gain := 0.0
	var lingpet_skill_trigger_count := 0
	var ringpet_skill_trigger_count := 0
	var lingpet_gauge_gain_bonus_pct := 0.0
	var ringpet_gauge_gain_bonus_pct := 0.0
	var lingpet_passive_skill_id := ""
	var ringpet_passive_skill_id := ""
	var lingpet_passive_skill_name := ""
	var ringpet_passive_skill_name := ""
	var lingpet_passive_skill_description := ""
	var ringpet_passive_skill_description := ""
	var lingpet_passive_skill_icon_path := ""
	var ringpet_passive_skill_icon_path := ""
	var lingpet_effect_text := ""
	var lingpet_owned_pet_ids: Array = []
	var owned_lingpet_ids: Array = []
	var owned_ringpet_ids: Array = []
	var lingpet_collection: Dictionary = {}
	var ringpet_collection: Dictionary = {}
	var owned_lingpets: Dictionary = {}
	var owned_ringpets: Dictionary = {}
	var lingpet_loadouts: Dictionary = {}
	var ringpet_loadouts: Dictionary = {}
	var owned_lingpet_loadouts: Dictionary = {}
	var owned_ringpet_loadouts: Dictionary = {}
	var lingpet_slots: Array = ["", "", ""]
	var ringpet_slots: Array = ["", "", ""]
	var lingpet_slot_pet_ids: Array = ["", "", ""]
	var ringpet_slot_pet_ids: Array = ["", "", ""]
	var lingpet_active_slot_index := 0
	var ringpet_active_slot_index := 0

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))

	func queue_redraw() -> void:
		redraws += 1


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
		return null


func _init() -> void:
	_verify_catalog_and_source_wiring()
	_verify_f10_opens_lingpet_debug_picker()
	_verify_click_grants_and_activates_lingpet()
	_verify_full_slots_replace_active_slot_for_debug_grant()
	if _failures.is_empty():
		print("lingpet_debug_picker_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_and_source_wiring() -> void:
	var spec: Dictionary = GameplayCoreModuleCatalog.new().get_spec("lingpet_debug_picker")
	_expect(str(spec.get("path", "")) == "res://scripts/core/lingpet_debug_picker.gd", "lingpet debug picker should be registered in the core module catalog")
	var input_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_overlay_input_controller.gd")
	var frame_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_overlay_frame_controller.gd")
	var gate_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_modal_gate_controller.gd")
	_expect(input_source.find("KEY_F10") >= 0 and input_source.find("DEBUG_MENU_LINGPET_PICKER") >= 0, "overlay input should wire F10 to the lingpet debug menu")
	_expect(frame_source.find("draw.overlay.lingpet_debug") >= 0, "overlay frame controller should draw the lingpet debug menu")
	_expect(gate_source.find("is_lingpet_debug_picker_open") >= 0 and gate_source.find("physics.modal_gate.lingpet_debug") >= 0, "modal gate should expose lingpet debug as a blocking modal")


func _verify_f10_opens_lingpet_debug_picker() -> void:
	var picker := LingpetDebugPicker.new()
	var runtime := LingpetEggRuntime.new()
	var modal_gate := BattleSceneModalGateController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({
		"battle_scene_modal_gate_controller": modal_gate,
		"lingpet_debug_picker": picker,
		"lingpet_egg_runtime": runtime,
	})
	var input := BattleSceneOverlayInputController.new()
	var handled := bool(input.handle_input(_key_event(KEY_F10), owner, registry, Callable(registry, "get_instance"), {}))
	_expect(handled, "F10 should be handled by overlay input")
	_expect(picker.is_open(), "F10 should open the lingpet debug picker")
	_expect(modal_gate.is_lingpet_debug_picker_open(Callable(registry, "get_instance")), "modal gate should see the open lingpet picker")
	_expect(modal_gate.should_block_battle_physics(Callable(registry, "get_instance")), "open lingpet picker should block battle physics")
	_expect(owner.redraws == 1, "opening lingpet debug should request one redraw")


func _verify_click_grants_and_activates_lingpet() -> void:
	var picker := LingpetDebugPicker.new()
	var runtime := LingpetEggRuntime.new()
	var modal_gate := BattleSceneModalGateController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({
		"battle_scene_modal_gate_controller": modal_gate,
		"lingpet_debug_picker": picker,
		"lingpet_egg_runtime": runtime,
	})
	picker.toggle(owner)
	var target_index := _find_pet_index(picker, "lunabi")
	if target_index < 0:
		target_index = 0
	var target_pet_id := picker.get_pet_id_for_tests(target_index)
	var card_rect := picker.get_card_rect_for_tests(target_index, owner.get_viewport_rect().size)
	var handled := bool(picker.handle_input(_mouse_click(card_rect.position + card_rect.size * 0.5), owner, registry, owner.get_viewport_rect().size))
	_expect(handled, "clicking a lingpet card should be handled")
	_expect(not picker.is_open(), "clicking a lingpet card should close the picker")
	_expect(target_pet_id != "", "target pet id should be available")
	_expect(owner.active_lingpet_id == target_pet_id, "clicked lingpet should become the active battle companion")
	_expect(owner.lingpet_state == "companion", "clicked lingpet should immediately enter companion state")
	_expect(owner.lingpet_owned_pet_ids.has(target_pet_id), "clicked lingpet should be added to owned pet ids")
	_expect(owner.lingpet_slots.has(target_pet_id), "clicked lingpet should be assigned to a battle slot")
	_expect(runtime.is_companion_active(target_pet_id), "runtime should report the clicked lingpet as active")
	_expect(runtime.is_acquire_cutin_active(), "F10 card selection should show the lingpet Live2D acquisition cut-in first")
	_expect(is_equal_approx(float(runtime.get_acquire_cutin_progress()), 0.0), "F10-triggered acquisition cut-in should start from the first reveal frame")
	_expect(modal_gate.is_lingpet_acquire_cutin_active(Callable(registry, "get_instance")), "modal gate should expose the F10-triggered acquisition cut-in")
	_expect(modal_gate.should_block_battle_physics(Callable(registry, "get_instance")), "F10-triggered acquisition cut-in should pause battle physics")
	_expect(owner.redraws == 1, "card click should request one redraw")


func _verify_full_slots_replace_active_slot_for_debug_grant() -> void:
	var runtime := LingpetEggRuntime.new()
	var owner := FakeOwner.new()
	owner.lingpet_slots = ["maribo", "maribo", "maribo"]
	owner.ringpet_slots = owner.lingpet_slots.duplicate()
	owner.lingpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.ringpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.lingpet_active_slot_index = 1
	owner.ringpet_active_slot_index = 1
	_expect(runtime.debug_grant_and_activate_pet("lunabi", owner), "debug grant should accept an implemented lingpet id")
	_expect(owner.active_lingpet_id == "lunabi", "debug grant should activate the selected lingpet even when slots were full")
	_expect(owner.lingpet_slots[owner.lingpet_active_slot_index] == "lunabi", "debug grant should replace the active full slot with the selected lingpet")
	_expect(not runtime.is_acquire_cutin_active(), "direct debug grant should keep cut-in optional unless F10 requests it")


func _find_pet_index(picker: Object, pet_id: String) -> int:
	for index in range(9):
		var current := str(picker.get_pet_id_for_tests(index))
		if current == pet_id:
			return index
		if current == "":
			return -1
	return -1


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
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
