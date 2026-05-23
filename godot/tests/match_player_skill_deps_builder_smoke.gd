extends SceneTree

const MatchPlayerSkillDepsBuilder := preload("res://scripts/core/battle_update_match_player_skill_deps_builder.gd")
const BattleUpdateMatchFlowContext := preload("res://scripts/core/battle_update_match_flow_context.gd")
const BattleUpdateMatchFlowDepsGroups := preload("res://scripts/core/battle_update_match_flow_deps_groups.gd")

var _failures: Array[String] = []


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init() -> void:
		for key in [
			"smasher_skill_state",
			"viper_skill_state",
			"smasher_drive_input_state",
			"smasher_plasma_state",
			"smasher_recovery_state",
			"smasher_cleanse_state",
			"smasher_warp_gate_state",
			"smasher_wheel_state",
			"smasher_magnum_grip_state",
			"smasher_dash_spirit_state",
			"smasher_shield_kiting_state",
			"laurel_leaf_shield_state",
			"monkey_blessing_delivery_state",
			"commando_reload_delivery_state",
			"runtime_perk_state",
			"smasher_skill_config",
			"viper_skill_config",
			"viper_skill_runtime",
			"commando_skill_state",
			"commando_skill_config",
			"commando_emergency_supply_state",
			"commando_firearm_runtime",
			"commando_supply_drop_state",
			"optimus_energy_state",
			"smasher_dash_state",
		]:
			instances[key] = RefCounted.new()

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	var registry := FakeRegistry.new()
	var builder: Object = MatchPlayerSkillDepsBuilder.new()

	_verify_skill_deps(builder.build_deps(registry), registry, "direct builder")
	_verify_skill_deps(BattleUpdateMatchFlowDepsGroups.new().build_player_skill_runtime_deps(registry), registry, "deps groups facade")

	var match_flow_deps: Dictionary = BattleUpdateMatchFlowContext.new().build_deps(registry)
	_verify_skill_deps(match_flow_deps, registry, "match flow context facade")

	var null_deps: Dictionary = builder.build_deps(null)
	_expect(null_deps.get("skill_state", RefCounted.new()) == null, "null registry should produce null legacy skill state")
	_expect(null_deps.get("skill_states", []).size() == 4, "null registry should keep skill state array shape")
	_expect((null_deps.get("skill_states", []) as Array)[0] == null, "null registry should keep null Smasher skill state")
	_expect((null_deps.get("skill_states", []) as Array)[1] == null, "null registry should keep null Viper skill state")
	_expect((null_deps.get("skill_states", []) as Array)[2] == null, "null registry should keep null Commando skill state")
	_expect((null_deps.get("skill_states", []) as Array)[3] == null, "null registry should keep null Optimus energy state")
	_expect(null_deps.get("skill_configs", []).size() == 3, "null registry should keep skill config array shape")
	_expect(null_deps.get("skill_runtimes", []).size() == 4, "null registry should keep skill runtime array shape")
	_expect(null_deps.get("commando_reload_delivery_state", RefCounted.new()) == null, "null registry should produce null Commando reload delivery state")
	_expect(null_deps.get("dash_state", RefCounted.new()) == null, "null registry should produce null dash state")

	if _failures.is_empty():
		print("match_player_skill_deps_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_skill_deps(deps: Dictionary, registry: FakeRegistry, source: String) -> void:
	_expect(deps.get("skill_state", null) == registry.instances["smasher_skill_state"], "%s should keep legacy Smasher skill_state" % source)

	var skill_states: Array = deps.get("skill_states", [])
	_expect(skill_states.size() == 4, "%s should include four skill states" % source)
	_expect(skill_states[0] == registry.instances["smasher_skill_state"], "%s should include Smasher skill state first" % source)
	_expect(skill_states[1] == registry.instances["viper_skill_state"], "%s should include Viper skill state second" % source)
	_expect(skill_states[2] == registry.instances["commando_skill_state"], "%s should include Commando skill state third" % source)
	_expect(skill_states[3] == registry.instances["optimus_energy_state"], "%s should include Optimus energy state fourth" % source)

	for key in [
		"drive_input_state",
		"smasher_plasma_state",
		"smasher_recovery_state",
		"smasher_cleanse_state",
		"smasher_warp_gate_state",
		"smasher_wheel_state",
		"smasher_magnum_grip_state",
		"smasher_dash_spirit_state",
		"smasher_shield_kiting_state",
		"laurel_leaf_shield_state",
		"monkey_blessing_delivery_state",
		"commando_reload_delivery_state",
		"runtime_perk_state",
		"optimus_energy_state",
		"dash_state",
	]:
		var registry_key: String = _registry_key_for_dep(key)
		_expect(deps.get(key, null) == registry.instances[registry_key], "%s should include %s from %s" % [source, key, registry_key])

	var skill_configs: Array = deps.get("skill_configs", [])
	_expect(skill_configs.size() == 3, "%s should include three skill configs" % source)
	_expect(skill_configs[0] == registry.instances["smasher_skill_config"], "%s should include Smasher skill config first" % source)
	_expect(skill_configs[1] == registry.instances["viper_skill_config"], "%s should include Viper skill config second" % source)
	_expect(skill_configs[2] == registry.instances["commando_skill_config"], "%s should include Commando skill config third" % source)

	var skill_runtimes: Array = deps.get("skill_runtimes", [])
	_expect(skill_runtimes.size() == 4, "%s should include four skill runtimes" % source)
	_expect(skill_runtimes[0] == registry.instances["viper_skill_runtime"], "%s should include Viper skill runtime" % source)
	_expect(skill_runtimes[1] == registry.instances["commando_emergency_supply_state"], "%s should include Commando emergency supply runtime" % source)
	_expect(skill_runtimes[2] == registry.instances["commando_firearm_runtime"], "%s should include Commando firearm runtime" % source)
	_expect(skill_runtimes[3] == registry.instances["commando_supply_drop_state"], "%s should include Commando supply drop runtime" % source)


func _registry_key_for_dep(dep_key: String) -> String:
	if dep_key == "drive_input_state":
		return "smasher_drive_input_state"
	if dep_key == "dash_state":
		return "smasher_dash_state"
	return dep_key


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
