extends SceneTree

const MatchPlayerSkillDepsBuilder := preload("res://scripts/core/battle_update_match_player_skill_deps_builder.gd")
const BattleUpdateMatchFlowContext := preload("res://scripts/core/battle_update_match_flow_context.gd")
const BattleUpdateMatchFlowDepsGroups := preload("res://scripts/core/battle_update_match_flow_deps_groups.gd")

var _failures: Array[String] = []


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var requested_keys: Array[String] = []

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
			"blacksmith_skill_state",
			"blacksmith_skill_config",
			"blacksmith_thor_shield_state",
			"status_effect_state",
			"smasher_dash_state",
		]:
			instances[key] = RefCounted.new()

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		return instances.get(key, null)


func _init() -> void:
	var registry := FakeRegistry.new()
	var builder: Object = MatchPlayerSkillDepsBuilder.new()

	_verify_skill_deps(builder.build_deps(registry), registry, "direct builder")
	_verify_skill_deps(BattleUpdateMatchFlowDepsGroups.new().build_player_skill_runtime_deps(registry), registry, "deps groups facade")

	var match_flow_deps: Dictionary = BattleUpdateMatchFlowContext.new().build_deps(registry)
	_verify_skill_deps(match_flow_deps, registry, "match flow context facade")
	_verify_scoped_smasher_deps(builder, registry)
	_verify_scoped_viper_deps(builder, registry)
	_verify_scoped_commando_deps(builder, registry)
	_verify_scoped_optimus_deps(builder, registry)
	_verify_scoped_blacksmith_deps(builder, registry)
	_verify_scoped_stage_deps(registry)

	var null_deps: Dictionary = builder.build_deps(null)
	_expect(null_deps.get("skill_state", RefCounted.new()) == null, "null registry should produce null legacy skill state")
	_expect(null_deps.get("skill_states", []).size() == 5, "null registry should keep skill state array shape")
	_expect((null_deps.get("skill_states", []) as Array)[0] == null, "null registry should keep null Smasher skill state")
	_expect((null_deps.get("skill_states", []) as Array)[1] == null, "null registry should keep null Viper skill state")
	_expect((null_deps.get("skill_states", []) as Array)[2] == null, "null registry should keep null Commando skill state")
	_expect((null_deps.get("skill_states", []) as Array)[3] == null, "null registry should keep null Optimus energy state")
	_expect((null_deps.get("skill_states", []) as Array)[4] == null, "null registry should keep null Blacksmith skill state")
	_expect(null_deps.get("skill_configs", []).size() == 4, "null registry should keep skill config array shape")
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
	_expect(skill_states.size() == 5, "%s should include five skill states" % source)
	_expect(skill_states[0] == registry.instances["smasher_skill_state"], "%s should include Smasher skill state first" % source)
	_expect(skill_states[1] == registry.instances["viper_skill_state"], "%s should include Viper skill state second" % source)
	_expect(skill_states[2] == registry.instances["commando_skill_state"], "%s should include Commando skill state third" % source)
	_expect(skill_states[3] == registry.instances["optimus_energy_state"], "%s should include Optimus energy state fourth" % source)
	_expect(skill_states[4] == registry.instances["blacksmith_skill_state"], "%s should include Blacksmith skill state fifth" % source)

	for key in [
		"drive_input_state",
		"smasher_plasma_state",
		"smasher_recovery_state",
		"smasher_cleanse_state",
		"status_effect_state",
		"smasher_warp_gate_state",
		"smasher_wheel_state",
		"smasher_magnum_grip_state",
		"smasher_dash_spirit_state",
		"smasher_shield_kiting_state",
		"blacksmith_thor_shield_state",
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
	_expect(skill_configs.size() == 4, "%s should include four skill configs" % source)
	_expect(skill_configs[0] == registry.instances["smasher_skill_config"], "%s should include Smasher skill config first" % source)
	_expect(skill_configs[1] == registry.instances["viper_skill_config"], "%s should include Viper skill config second" % source)
	_expect(skill_configs[2] == registry.instances["commando_skill_config"], "%s should include Commando skill config third" % source)
	_expect(skill_configs[3] == registry.instances["blacksmith_skill_config"], "%s should include Blacksmith skill config fourth" % source)

	var skill_runtimes: Array = deps.get("skill_runtimes", [])
	_expect(skill_runtimes.size() == 4, "%s should include four skill runtimes" % source)
	_expect(skill_runtimes[0] == registry.instances["viper_skill_runtime"], "%s should include Viper skill runtime" % source)
	_expect(skill_runtimes[1] == registry.instances["commando_emergency_supply_state"], "%s should include Commando emergency supply runtime" % source)
	_expect(skill_runtimes[2] == registry.instances["commando_firearm_runtime"], "%s should include Commando firearm runtime" % source)
	_expect(skill_runtimes[3] == registry.instances["commando_supply_drop_state"], "%s should include Commando supply drop runtime" % source)


func _verify_scoped_smasher_deps(builder: Object, registry: FakeRegistry) -> void:
	registry.requested_keys.clear()
	var deps: Dictionary = builder.build_deps(registry, "smasher")
	var skill_states: Array = deps.get("skill_states", [])
	var skill_configs: Array = deps.get("skill_configs", [])
	_expect(deps.get("skill_state", null) == registry.instances["smasher_skill_state"], "scoped Smasher deps should keep Smasher primary skill state")
	_expect(skill_states.size() == 5, "scoped Smasher deps should preserve skill state array shape")
	_expect(skill_states[0] == registry.instances["smasher_skill_state"], "scoped Smasher deps should include Smasher skill state")
	_expect(skill_states[1] == null, "scoped Smasher deps should not include Viper skill state")
	_expect(skill_states[2] == null, "scoped Smasher deps should not include Commando skill state")
	_expect(skill_states[3] == null, "scoped Smasher deps should not include Optimus energy state")
	_expect(skill_states[4] == null, "scoped Smasher deps should not include Blacksmith skill state")
	_expect(skill_configs.size() == 4, "scoped Smasher deps should preserve skill config array shape")
	_expect(skill_configs[0] == registry.instances["smasher_skill_config"], "scoped Smasher deps should include Smasher skill config")
	_expect(skill_configs[1] == null, "scoped Smasher deps should not include Viper skill config")
	_expect(skill_configs[2] == null, "scoped Smasher deps should not include Commando skill config")
	_expect(skill_configs[3] == null, "scoped Smasher deps should not include Blacksmith skill config")
	_expect(deps.get("blacksmith_thor_shield_state", RefCounted.new()) == null, "scoped Smasher deps should not include Blacksmith shield")
	_expect(deps.get("optimus_energy_state", RefCounted.new()) == null, "scoped Smasher deps should not include Optimus energy")
	_expect(deps.get("skill_runtimes", []).is_empty(), "scoped Smasher deps should not include cross-character skill runtimes")
	_expect(not registry.requested_keys.has("viper_skill_state"), "scoped Smasher deps should not wake Viper skill state")
	_expect(not registry.requested_keys.has("commando_skill_state"), "scoped Smasher deps should not wake Commando skill state")
	_expect(not registry.requested_keys.has("optimus_energy_state"), "scoped Smasher deps should not wake Optimus energy state")
	_expect(not registry.requested_keys.has("blacksmith_skill_state"), "scoped Smasher deps should not wake Blacksmith skill state")
	_expect(not registry.requested_keys.has("viper_skill_config"), "scoped Smasher deps should not wake Viper skill config")
	_expect(not registry.requested_keys.has("commando_skill_config"), "scoped Smasher deps should not wake Commando skill config")
	_expect(not registry.requested_keys.has("blacksmith_skill_config"), "scoped Smasher deps should not wake Blacksmith skill config")
	_expect(not registry.requested_keys.has("viper_skill_runtime"), "scoped Smasher deps should not wake Viper runtime")
	_expect(not registry.requested_keys.has("commando_firearm_runtime"), "scoped Smasher deps should not wake Commando firearm runtime")
	_expect(not registry.requested_keys.has("commando_supply_drop_state"), "scoped Smasher deps should not wake Commando supply runtime")


func _verify_scoped_viper_deps(builder: Object, registry: FakeRegistry) -> void:
	registry.requested_keys.clear()
	var deps: Dictionary = builder.build_deps(registry, "viper")
	var skill_states: Array = deps.get("skill_states", [])
	var skill_configs: Array = deps.get("skill_configs", [])
	_expect(deps.get("skill_state", null) == registry.instances["viper_skill_state"], "scoped Viper deps should expose Viper primary skill state")
	_expect(skill_states.size() == 5, "scoped Viper deps should preserve skill state array shape")
	_expect(skill_states[0] == null, "scoped Viper deps should not include Smasher skill state")
	_expect(skill_states[1] == registry.instances["viper_skill_state"], "scoped Viper deps should include Viper skill state")
	_expect(skill_states[2] == null, "scoped Viper deps should not include Commando skill state")
	_expect(skill_states[3] == null, "scoped Viper deps should not include Optimus energy state")
	_expect(skill_states[4] == null, "scoped Viper deps should not include Blacksmith skill state")
	_expect(skill_configs.size() == 4, "scoped Viper deps should preserve skill config array shape")
	_expect(skill_configs[0] == null, "scoped Viper deps should not include Smasher skill config")
	_expect(skill_configs[1] == registry.instances["viper_skill_config"], "scoped Viper deps should include Viper skill config")
	_expect(skill_configs[2] == null, "scoped Viper deps should not include Commando skill config")
	_expect(skill_configs[3] == null, "scoped Viper deps should not include Blacksmith skill config")
	var skill_runtimes: Array = deps.get("skill_runtimes", [])
	_expect(skill_runtimes.size() == 1, "scoped Viper deps should include one skill runtime")
	_expect(skill_runtimes[0] == registry.instances["viper_skill_runtime"], "scoped Viper deps should include Viper runtime")
	_expect(registry.requested_keys.has("viper_skill_runtime"), "scoped Viper deps should wake Viper runtime")
	_expect(not registry.requested_keys.has("smasher_skill_config"), "scoped Viper deps should not wake Smasher skill config")
	_expect(not registry.requested_keys.has("commando_firearm_runtime"), "scoped Viper deps should not wake Commando firearm runtime")
	_expect(not registry.requested_keys.has("commando_supply_drop_state"), "scoped Viper deps should not wake Commando supply runtime")


func _verify_scoped_commando_deps(builder: Object, registry: FakeRegistry) -> void:
	registry.requested_keys.clear()
	var deps: Dictionary = builder.build_deps(registry, "commando")
	var skill_states: Array = deps.get("skill_states", [])
	var skill_configs: Array = deps.get("skill_configs", [])
	_expect(deps.get("skill_state", null) == registry.instances["commando_skill_state"], "scoped Commando deps should expose Commando primary skill state")
	_expect(skill_states.size() == 5, "scoped Commando deps should preserve skill state array shape")
	_expect(skill_states[0] == null, "scoped Commando deps should not include Smasher skill state")
	_expect(skill_states[1] == null, "scoped Commando deps should not include Viper skill state")
	_expect(skill_states[2] == registry.instances["commando_skill_state"], "scoped Commando deps should include Commando skill state")
	_expect(skill_states[3] == null, "scoped Commando deps should not include Optimus energy state")
	_expect(skill_states[4] == null, "scoped Commando deps should not include Blacksmith skill state")
	_expect(skill_configs.size() == 4, "scoped Commando deps should preserve skill config array shape")
	_expect(skill_configs[0] == null, "scoped Commando deps should not include Smasher skill config")
	_expect(skill_configs[1] == null, "scoped Commando deps should not include Viper skill config")
	_expect(skill_configs[2] == registry.instances["commando_skill_config"], "scoped Commando deps should include Commando skill config")
	_expect(skill_configs[3] == null, "scoped Commando deps should not include Blacksmith skill config")
	var skill_runtimes: Array = deps.get("skill_runtimes", [])
	_expect(skill_runtimes.size() == 3, "scoped Commando deps should include three skill runtimes")
	_expect(skill_runtimes[0] == registry.instances["commando_emergency_supply_state"], "scoped Commando deps should include emergency supply runtime")
	_expect(skill_runtimes[1] == registry.instances["commando_firearm_runtime"], "scoped Commando deps should include firearm runtime")
	_expect(skill_runtimes[2] == registry.instances["commando_supply_drop_state"], "scoped Commando deps should include supply drop runtime")
	_expect(deps.get("blacksmith_thor_shield_state", RefCounted.new()) == null, "scoped Commando deps should not include Blacksmith shield")
	_expect(deps.get("optimus_energy_state", RefCounted.new()) == null, "scoped Commando deps should not include top-level Optimus energy")
	_expect(registry.requested_keys.has("commando_emergency_supply_state"), "scoped Commando deps should wake emergency supply runtime")
	_expect(registry.requested_keys.has("commando_firearm_runtime"), "scoped Commando deps should wake firearm runtime")
	_expect(registry.requested_keys.has("commando_supply_drop_state"), "scoped Commando deps should wake supply runtime")
	_expect(not registry.requested_keys.has("viper_skill_runtime"), "scoped Commando deps should not wake Viper runtime")
	_expect(not registry.requested_keys.has("blacksmith_skill_config"), "scoped Commando deps should not wake Blacksmith skill config")


func _verify_scoped_optimus_deps(builder: Object, registry: FakeRegistry) -> void:
	registry.requested_keys.clear()
	var deps: Dictionary = builder.build_deps(registry, "optimus")
	var skill_states: Array = deps.get("skill_states", [])
	var skill_configs: Array = deps.get("skill_configs", [])
	_expect(deps.get("skill_state", null) == registry.instances["optimus_energy_state"], "scoped Optimus deps should expose Optimus energy as primary skill state")
	_expect(deps.get("optimus_energy_state", null) == registry.instances["optimus_energy_state"], "scoped Optimus deps should include top-level Optimus energy")
	_expect(skill_states.size() == 5, "scoped Optimus deps should preserve skill state array shape")
	_expect(skill_states[0] == null, "scoped Optimus deps should not include Smasher skill state")
	_expect(skill_states[1] == null, "scoped Optimus deps should not include Viper skill state")
	_expect(skill_states[2] == null, "scoped Optimus deps should not include Commando skill state")
	_expect(skill_states[3] == registry.instances["optimus_energy_state"], "scoped Optimus deps should include Optimus energy state")
	_expect(skill_states[4] == null, "scoped Optimus deps should not include Blacksmith skill state")
	_expect(skill_configs.size() == 4, "scoped Optimus deps should preserve skill config array shape without adding an Optimus slot")
	_expect(skill_configs[0] == null, "scoped Optimus deps should not include Smasher skill config")
	_expect(skill_configs[1] == null, "scoped Optimus deps should not include Viper skill config")
	_expect(skill_configs[2] == null, "scoped Optimus deps should not include Commando skill config")
	_expect(skill_configs[3] == null, "scoped Optimus deps should not include Blacksmith skill config")
	_expect(deps.get("skill_runtimes", []).is_empty(), "scoped Optimus deps should not include cross-character skill runtimes")
	_expect(deps.get("blacksmith_thor_shield_state", RefCounted.new()) == null, "scoped Optimus deps should not include Blacksmith shield")
	_expect(registry.requested_keys.has("optimus_energy_state"), "scoped Optimus deps should wake Optimus energy")
	_expect(not registry.requested_keys.has("smasher_skill_config"), "scoped Optimus deps should not wake Smasher skill config")
	_expect(not registry.requested_keys.has("viper_skill_config"), "scoped Optimus deps should not wake Viper skill config")
	_expect(not registry.requested_keys.has("commando_skill_config"), "scoped Optimus deps should not wake Commando skill config")
	_expect(not registry.requested_keys.has("blacksmith_skill_config"), "scoped Optimus deps should not wake Blacksmith skill config")
	_expect(not registry.requested_keys.has("viper_skill_runtime"), "scoped Optimus deps should not wake Viper runtime")
	_expect(not registry.requested_keys.has("commando_firearm_runtime"), "scoped Optimus deps should not wake Commando firearm runtime")
	_expect(not registry.requested_keys.has("commando_supply_drop_state"), "scoped Optimus deps should not wake Commando supply runtime")


func _verify_scoped_blacksmith_deps(builder: Object, registry: FakeRegistry) -> void:
	registry.requested_keys.clear()
	var deps: Dictionary = builder.build_deps(registry, "blacksmith")
	var skill_states: Array = deps.get("skill_states", [])
	var skill_configs: Array = deps.get("skill_configs", [])
	_expect(deps.get("skill_state", null) == registry.instances["blacksmith_skill_state"], "scoped Blacksmith deps should expose Blacksmith primary skill state")
	_expect(deps.get("blacksmith_thor_shield_state", null) == registry.instances["blacksmith_thor_shield_state"], "scoped Blacksmith deps should include top-level Thor shield state")
	_expect(skill_states.size() == 5, "scoped Blacksmith deps should preserve skill state array shape")
	_expect(skill_states[0] == null, "scoped Blacksmith deps should not include Smasher skill state")
	_expect(skill_states[1] == null, "scoped Blacksmith deps should not include Viper skill state")
	_expect(skill_states[2] == null, "scoped Blacksmith deps should not include Commando skill state")
	_expect(skill_states[3] == null, "scoped Blacksmith deps should not include Optimus energy state")
	_expect(skill_states[4] == registry.instances["blacksmith_skill_state"], "scoped Blacksmith deps should include Blacksmith skill state")
	_expect(skill_configs.size() == 4, "scoped Blacksmith deps should preserve skill config array shape")
	_expect(skill_configs[0] == null, "scoped Blacksmith deps should not include Smasher skill config")
	_expect(skill_configs[1] == null, "scoped Blacksmith deps should not include Viper skill config")
	_expect(skill_configs[2] == null, "scoped Blacksmith deps should not include Commando skill config")
	_expect(skill_configs[3] == registry.instances["blacksmith_skill_config"], "scoped Blacksmith deps should include Blacksmith skill config")
	_expect(deps.get("skill_runtimes", []).is_empty(), "scoped Blacksmith deps should not duplicate Thor shield through skill_runtimes")
	_expect(registry.requested_keys.count("blacksmith_thor_shield_state") == 1, "scoped Blacksmith deps should request Thor shield only once")


func _verify_scoped_stage_deps(registry: FakeRegistry) -> void:
	registry.requested_keys.clear()
	BattleUpdateMatchFlowContext.new().build_deps(registry, 1, null, "", false, "smasher")
	_expect(not registry.requested_keys.has("stage5_hongryun_actor_renderer"), "Stage 1 scoped match deps should not wake Stage 5 actor renderer")


func _registry_key_for_dep(dep_key: String) -> String:
	if dep_key == "drive_input_state":
		return "smasher_drive_input_state"
	if dep_key == "dash_state":
		return "smasher_dash_state"
	return dep_key


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
