extends SceneTree

const EffectsCharacterDepsBuilder := preload("res://scripts/core/battle_update_effects_character_deps_builder.gd")
const EffectsDepsBuilder := preload("res://scripts/core/battle_update_effects_deps_builder.gd")
const BattleUpdateEffectsContext := preload("res://scripts/core/battle_update_effects_context.gd")

var _failures: Array[String] = []


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var requested_keys: Array[String] = []

	func _init() -> void:
		for key in [
			"smasher_power_smash_state",
			"smasher_plasma_state",
			"smasher_recovery_state",
			"smasher_cleanse_state",
			"smasher_warp_gate_state",
			"smasher_wheel_state",
			"smasher_magnum_grip_state",
			"smasher_dash_spirit_state",
			"smasher_shield_kiting_state",
			"viper_skill_runtime",
			"viper_jetpack_state",
			"viper_skill_config",
			"viper_skill_state",
			"commando_firearm_runtime",
			"runtime_perk_state",
			"monkey_blessing_delivery_state",
			"commando_reload_delivery_state",
			"smasher_combo_state",
		]:
			instances[key] = RefCounted.new()

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		return instances.get(key, null)


func _init() -> void:
	var registry := FakeRegistry.new()
	var builder: Object = EffectsCharacterDepsBuilder.new()

	_verify_character_deps(builder.build_deps(registry), registry, "direct builder")
	_verify_character_deps(EffectsDepsBuilder.new().build_deps(registry, 1), registry, "effects deps builder")
	_verify_character_deps(BattleUpdateEffectsContext.new().build_deps(registry, 1), registry, "effects context facade")
	_verify_scoped_character_deps()

	var null_deps: Dictionary = builder.build_deps(null)
	for key in [
		"power_state",
		"smasher_plasma_state",
		"smasher_recovery_state",
		"smasher_cleanse_state",
		"smasher_warp_gate_state",
		"smasher_wheel_state",
		"smasher_magnum_grip_state",
		"smasher_dash_spirit_state",
		"smasher_shield_kiting_state",
		"viper_skill_runtime",
		"viper_jetpack_state",
		"viper_skill_config",
		"viper_skill_state",
		"commando_firearm_runtime",
		"runtime_perk_state",
		"monkey_blessing_delivery_state",
		"commando_reload_delivery_state",
		"combo_state",
	]:
		_expect(null_deps.get(key, RefCounted.new()) == null, "null registry should produce null %s" % key)

	if _failures.is_empty():
		print("effects_character_deps_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_character_deps(deps: Dictionary, registry: FakeRegistry, source: String) -> void:
	var dep_to_registry_key := {
		"power_state": "smasher_power_smash_state",
		"smasher_plasma_state": "smasher_plasma_state",
		"smasher_recovery_state": "smasher_recovery_state",
		"smasher_cleanse_state": "smasher_cleanse_state",
		"smasher_warp_gate_state": "smasher_warp_gate_state",
		"smasher_wheel_state": "smasher_wheel_state",
		"smasher_magnum_grip_state": "smasher_magnum_grip_state",
		"smasher_dash_spirit_state": "smasher_dash_spirit_state",
		"smasher_shield_kiting_state": "smasher_shield_kiting_state",
		"viper_skill_runtime": "viper_skill_runtime",
		"viper_jetpack_state": "viper_jetpack_state",
		"viper_skill_config": "viper_skill_config",
		"viper_skill_state": "viper_skill_state",
		"commando_firearm_runtime": "commando_firearm_runtime",
		"runtime_perk_state": "runtime_perk_state",
		"monkey_blessing_delivery_state": "monkey_blessing_delivery_state",
		"commando_reload_delivery_state": "commando_reload_delivery_state",
		"combo_state": "smasher_combo_state",
	}
	for dep_key in dep_to_registry_key.keys():
		var registry_key: String = str(dep_to_registry_key[dep_key])
		_expect(
			deps.get(dep_key, null) == registry.instances[registry_key],
			"%s should include %s from %s" % [source, dep_key, registry_key]
		)


func _verify_scoped_character_deps() -> void:
	var builder: Object = EffectsCharacterDepsBuilder.new()

	var smasher_registry := FakeRegistry.new()
	var smasher_deps: Dictionary = builder.build_deps(smasher_registry, "smasher")
	_expect(smasher_deps.get("power_state", null) == smasher_registry.instances["smasher_power_smash_state"], "scoped Smasher deps should include Smasher power state")
	_expect(smasher_deps.get("combo_state", null) == smasher_registry.instances["smasher_combo_state"], "scoped Smasher deps should include combo state")
	_expect(smasher_deps.get("monkey_blessing_delivery_state", null) == smasher_registry.instances["monkey_blessing_delivery_state"], "shared Monkey Blessing effect state should stay available")
	_expect(smasher_deps.get("commando_reload_delivery_state", null) == smasher_registry.instances["commando_reload_delivery_state"], "shared Commando reload delivery effect state should stay available")
	_expect(not smasher_registry.requested_keys.has("viper_skill_runtime"), "scoped Smasher deps should not request Viper runtime")
	_expect(not smasher_registry.requested_keys.has("commando_firearm_runtime"), "scoped Smasher deps should not request Commando runtime")

	var viper_registry := FakeRegistry.new()
	var viper_deps: Dictionary = builder.build_deps(viper_registry, "viper")
	_expect(viper_deps.get("viper_skill_runtime", null) == viper_registry.instances["viper_skill_runtime"], "scoped Viper deps should include Viper runtime")
	_expect(viper_deps.get("viper_skill_config", null) == viper_registry.instances["viper_skill_config"], "scoped Viper deps should include Viper skill config")
	_expect(viper_deps.get("runtime_perk_state", null) == viper_registry.instances["runtime_perk_state"], "shared runtime perk state should stay available")
	_expect(viper_deps.get("commando_reload_delivery_state", null) == viper_registry.instances["commando_reload_delivery_state"], "shared Commando reload delivery effect state should stay available for Viper cleanup")
	_expect(not viper_deps.has("power_state"), "scoped Viper deps should not expose Smasher power state")
	_expect(not viper_registry.requested_keys.has("smasher_wheel_state"), "scoped Viper deps should not request Smasher wheel state")
	_expect(not viper_registry.requested_keys.has("commando_firearm_runtime"), "scoped Viper deps should not request Commando runtime")

	var commando_registry := FakeRegistry.new()
	var commando_deps: Dictionary = builder.build_deps(commando_registry, "commando")
	_expect(commando_deps.get("commando_firearm_runtime", null) == commando_registry.instances["commando_firearm_runtime"], "scoped Commando deps should include firearm runtime")
	_expect(commando_deps.get("commando_reload_delivery_state", null) == commando_registry.instances["commando_reload_delivery_state"], "scoped Commando deps should include reload delivery state")
	_expect(not commando_deps.has("viper_skill_runtime"), "scoped Commando deps should not expose Viper runtime")
	_expect(not commando_registry.requested_keys.has("smasher_wheel_state"), "scoped Commando deps should not request Smasher wheel state")
	_expect(not commando_registry.requested_keys.has("viper_skill_runtime"), "scoped Commando deps should not request Viper runtime")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
