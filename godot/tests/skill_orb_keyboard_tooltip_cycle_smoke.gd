extends SceneTree

const BattleSceneInputController := preload("res://scripts/core/battle_scene_input_controller.gd")
const BattleSceneSkillTooltipDriver := preload("res://scripts/core/battle_scene_skill_tooltip_driver.gd")
const SkillOrbTooltipHoverState := preload("res://scripts/hud/skill_orb_tooltip_hover_state.gd")

var _failures: Array[String] = []
var _active_modules: Dictionary = {}


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var current_stage := 1
	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))


class FakeSkillConfig:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {
			"equipped_skills": ["drive", "power_smashing"],
			"skill_data": {
				"drive": {"name": "drive"},
				"power_smashing": {"name": "power_smashing"},
			},
		}


class FakeReadinessController:
	extends RefCounted

	func is_intro_or_warmup_blocking(
		_module_getter: Callable,
		_battle_initialized: bool,
		_stage_landing_intro_started: bool
	) -> bool:
		return false


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_t_cycles_tooltips_for_all_keyboard_grips()
	_verify_f_is_no_longer_a_tooltip_cycle_key()
	_verify_shift_is_reserved_for_vision_modifier()

	if _failures.is_empty():
		print("skill_orb_keyboard_tooltip_cycle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_t_cycles_tooltips_for_all_keyboard_grips() -> void:
	for grip_style in ["", "wasd_mouse", "space_arrows"]:
		var input := BattleSceneInputController.new()
		var owner := FakeOwner.new()
		if grip_style != "":
			owner.set_meta("tutorial_grip_style", grip_style)
		var hover_state := SkillOrbTooltipHoverState.new()
		var registry := _build_registry(hover_state)
		_active_modules = {
			"battle_scene_readiness_controller": FakeReadinessController.new(),
			"battle_scene_skill_tooltip_driver": BattleSceneSkillTooltipDriver.new(),
		}

		input.handle_unhandled_input(_key_event(KEY_T), owner, registry, Callable(self, "_get_module"), {})
		_expect(str(hover_state.get_gamepad_selected_skill_name()) == "drive", "T should open the first skill tooltip for grip '%s'" % grip_style)
		_expect(owner.redraw_count == 1, "T tooltip open should request a redraw for grip '%s'" % grip_style)

		input.handle_unhandled_input(_key_event(KEY_T), owner, registry, Callable(self, "_get_module"), {})
		_expect(str(hover_state.get_gamepad_selected_skill_name()) == "power_smashing", "Second T press should cycle to the next skill tooltip for grip '%s'" % grip_style)

		input.handle_unhandled_input(_key_event(KEY_T), owner, registry, Callable(self, "_get_module"), {})
		_expect(str(hover_state.get_gamepad_selected_skill_name()) == "", "T after the last skill should close the manual tooltip for grip '%s'" % grip_style)
	_active_modules.clear()


func _verify_f_is_no_longer_a_tooltip_cycle_key() -> void:
	var input := BattleSceneInputController.new()
	var owner := FakeOwner.new()
	var hover_state := SkillOrbTooltipHoverState.new()
	var registry := _build_registry(hover_state)
	_active_modules = {
		"battle_scene_readiness_controller": FakeReadinessController.new(),
		"battle_scene_skill_tooltip_driver": BattleSceneSkillTooltipDriver.new(),
	}

	input.handle_unhandled_input(_key_event(KEY_F), owner, registry, Callable(self, "_get_module"), {})
	_expect(str(hover_state.get_gamepad_selected_skill_name()) == "", "F should no longer open skill tooltips")
	_expect(owner.redraw_count == 0, "retired F tooltip input should not request a redraw")
	_active_modules.clear()


func _verify_shift_is_reserved_for_vision_modifier() -> void:
	var input := BattleSceneInputController.new()
	var owner := FakeOwner.new()
	owner.set_meta("tutorial_grip_style", "space_arrows")
	var hover_state := SkillOrbTooltipHoverState.new()
	var registry := _build_registry(hover_state)
	_active_modules = {
		"battle_scene_readiness_controller": FakeReadinessController.new(),
		"battle_scene_skill_tooltip_driver": BattleSceneSkillTooltipDriver.new(),
	}

	input.handle_unhandled_input(_key_event(KEY_SHIFT), owner, registry, Callable(self, "_get_module"), {})
	_expect(str(hover_state.get_gamepad_selected_skill_name()) == "", "Shift should stay reserved for the vision modifier")
	_expect(owner.redraw_count == 0, "reserved Shift should not redraw the skill tooltip")
	_active_modules.clear()


func _build_registry(hover_state: Object) -> Object:
	return FakeRegistry.new({
		"skill_orb_tooltip_hover_state": hover_state,
		"smasher_skill_config": FakeSkillConfig.new(),
	})


func _get_module(key: String) -> Object:
	return _active_modules.get(key, null)


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
