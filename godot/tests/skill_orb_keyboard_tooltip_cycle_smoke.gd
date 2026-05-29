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
	_verify_shift_cycles_tooltips_for_arrow_space_grip()
	_verify_shift_is_ignored_for_other_grips()

	if _failures.is_empty():
		print("skill_orb_keyboard_tooltip_cycle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_shift_cycles_tooltips_for_arrow_space_grip() -> void:
	var input := BattleSceneInputController.new()
	var owner := FakeOwner.new()
	owner.set_meta("tutorial_grip_style", "space_arrows")
	var hover_state := SkillOrbTooltipHoverState.new()
	var registry := _build_registry(hover_state)
	_active_modules = {
		"battle_scene_readiness_controller": FakeReadinessController.new(),
		"battle_scene_skill_tooltip_driver": BattleSceneSkillTooltipDriver.new(),
	}

	input.handle_unhandled_input(_shift_key_event(), owner, registry, Callable(self, "_get_module"), {})
	_expect(str(hover_state.get_gamepad_selected_skill_name()) == "drive", "Shift should open the first skill tooltip for arrow-space grip")
	_expect(owner.redraw_count == 1, "Shift tooltip open should request a redraw")

	input.handle_unhandled_input(_shift_key_event(), owner, registry, Callable(self, "_get_module"), {})
	_expect(str(hover_state.get_gamepad_selected_skill_name()) == "power_smashing", "Second Shift press should cycle to the next skill tooltip")

	input.handle_unhandled_input(_shift_key_event(), owner, registry, Callable(self, "_get_module"), {})
	_expect(str(hover_state.get_gamepad_selected_skill_name()) == "", "Shift after the last skill should close the manual tooltip")
	_active_modules.clear()


func _verify_shift_is_ignored_for_other_grips() -> void:
	for grip_style in ["", "wasd_mouse", "gamepad"]:
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

		input.handle_unhandled_input(_shift_key_event(), owner, registry, Callable(self, "_get_module"), {})
		_expect(str(hover_state.get_gamepad_selected_skill_name()) == "", "Shift should not open skill tooltips for grip '%s'" % grip_style)
		_expect(owner.redraw_count == 0, "Ignored Shift should not request redraw for grip '%s'" % grip_style)
	_active_modules.clear()


func _build_registry(hover_state: Object) -> Object:
	return FakeRegistry.new({
		"skill_orb_tooltip_hover_state": hover_state,
		"smasher_skill_config": FakeSkillConfig.new(),
	})


func _get_module(key: String) -> Object:
	return _active_modules.get(key, null)


func _shift_key_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_SHIFT
	event.physical_keycode = KEY_SHIFT
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
