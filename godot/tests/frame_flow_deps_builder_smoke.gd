extends SceneTree

const FrameFlowDepsBuilder := preload("res://scripts/core/battle_frame_flow_deps_builder.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var current_stage := 4


class FakeHoverState:
	extends RefCounted

	var hover_result: Dictionary = {"skill_name": "power_smashing"}
	var call_count := 0

	func update_hover_state(_owner: Object, _registry: Object) -> Dictionary:
		call_count += 1
		return hover_result


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary
	var requested_keys: Array[String] = []

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		return instances.get(key, null)


func _init() -> void:
	var builder: Object = FrameFlowDepsBuilder.new()
	var owner := FakeOwner.new()
	var scoreboard := RefCounted.new()
	var power_state := RefCounted.new()
	var round_state := RefCounted.new()
	var serve_flow := RefCounted.new()
	var hover_state := FakeHoverState.new()
	var registry := FakeRegistry.new({
		"scoreboard_state": scoreboard,
		"smasher_power_smash_state": power_state,
		"round_flow_state": round_state,
		"serve_flow_controller": serve_flow,
		"skill_orb_tooltip_hover_state": hover_state,
	})

	var deps: Dictionary = builder.build_deps(owner, registry)
	_expect(deps.get("scoreboard_state") == scoreboard, "deps should include scoreboard state")
	_expect(deps.get("power_state") == power_state, "smasher deps should include power smash state")
	_expect(deps.get("round_state") == round_state, "deps should include round flow state")
	_expect(deps.get("serve_flow_controller") == serve_flow, "deps should include serve flow controller")
	_expect(int(deps.get("serve_context", {}).get("current_stage", 0)) == 4, "serve context should include current stage")
	_expect(bool(deps.get("skill_orb_tooltip_active", false)), "tooltip hover should mark tooltip active")
	_expect(str(deps.get("skill_orb_tooltip_key", "")) == "power_smashing", "tooltip key should come from hover state")
	_expect(hover_state.call_count == 1, "hover state should update once")

	owner.selected_character_type = "viper"
	hover_state.hover_result = {}
	deps = builder.build_deps(owner, registry)
	_expect(deps.get("power_state") == null, "non-smasher deps should not include power smash state")
	_expect(not bool(deps.get("skill_orb_tooltip_active", true)), "empty hover state should mark tooltip inactive")
	_expect(str(deps.get("skill_orb_tooltip_key", "x")) == "", "empty hover state should clear tooltip key")

	if _failures.is_empty():
		print("frame_flow_deps_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
