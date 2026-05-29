extends SceneTree

const SkillOrbTooltipHoverState := preload("res://scripts/hud/skill_orb_tooltip_hover_state.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var current_stage := 1


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


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	var hover_state := SkillOrbTooltipHoverState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({
		"smasher_skill_config": FakeSkillConfig.new(),
	})

	var first: Dictionary = hover_state.cycle_gamepad_tooltip(owner, registry)
	_expect(bool(first.get("handled", false)), "first View/Back press should be handled")
	_expect(bool(first.get("active", false)), "first View/Back press should open a tooltip")
	_expect(str(first.get("skill_name", "")) == "drive", "first View/Back press should select the first equipped skill")
	_expect(str(hover_state.update_hover_state(owner, registry).get("skill_name", "")) == "drive", "manual tooltip state should feed frame-flow deps")

	var second: Dictionary = hover_state.cycle_gamepad_tooltip(owner, registry)
	_expect(bool(second.get("active", false)), "second View/Back press should keep tooltip active")
	_expect(str(second.get("skill_name", "")) == "power_smashing", "second View/Back press should select the next equipped skill")
	_expect(str(hover_state.update_hover_state(owner, registry).get("skill_name", "")) == "power_smashing", "frame-flow deps should follow the selected skill")

	var close_result: Dictionary = hover_state.cycle_gamepad_tooltip(owner, registry)
	_expect(bool(close_result.get("handled", false)), "press after last skill should still be handled")
	_expect(not bool(close_result.get("active", true)), "press after last skill should close the gamepad tooltip")
	_expect(hover_state.update_hover_state(owner, registry).is_empty(), "closed gamepad tooltip should clear frame-flow deps")

	owner.selected_character_type = "viper"
	var viper_result: Dictionary = hover_state.cycle_gamepad_tooltip(owner, registry)
	_expect(not bool(viper_result.get("handled", true)), "missing character skill config should not consume View/Back")

	if _failures.is_empty():
		print("skill_orb_gamepad_tooltip_cycle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
