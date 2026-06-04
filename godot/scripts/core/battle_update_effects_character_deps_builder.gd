extends RefCounted

const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

var character_runtime: Object = PlayerCharacterRuntime.new()


func build_deps(registry: Object, character_type: String = "") -> Dictionary:
	if character_type.strip_edges() == "":
		return _build_legacy_deps(registry)
	var normalized_character: String = character_runtime.normalize(character_type)
	var deps: Dictionary = _build_common_deps(registry)
	if character_runtime.is_viper(normalized_character):
		_append_viper_deps(deps, registry)
	elif character_runtime.is_commando(normalized_character):
		_append_commando_deps(deps, registry)
	elif character_runtime.is_blacksmith(normalized_character):
		_append_blacksmith_deps(deps, registry)
	else:
		_append_smasher_deps(deps, registry)
	return deps


func _build_legacy_deps(registry: Object) -> Dictionary:
	var deps: Dictionary = _build_common_deps(registry)
	_append_smasher_deps(deps, registry)
	_append_viper_deps(deps, registry)
	_append_commando_deps(deps, registry)
	return deps


func _build_common_deps(registry: Object) -> Dictionary:
	return {
		"registry": registry,
		"runtime_perk_state": _get_instance(registry, "runtime_perk_state"),
		"monkey_blessing_delivery_state": _get_instance(registry, "monkey_blessing_delivery_state"),
		"commando_reload_delivery_state": _get_instance(registry, "commando_reload_delivery_state"),
	}


func _append_smasher_deps(deps: Dictionary, registry: Object) -> void:
	deps["power_state"] = _get_instance(registry, "smasher_power_smash_state")
	deps["smasher_plasma_state"] = _get_instance(registry, "smasher_plasma_state")
	deps["smasher_recovery_state"] = _get_instance(registry, "smasher_recovery_state")
	deps["smasher_cleanse_state"] = _get_instance(registry, "smasher_cleanse_state")
	deps["smasher_warp_gate_state"] = _get_instance(registry, "smasher_warp_gate_state")
	deps["smasher_wheel_state"] = _get_instance(registry, "smasher_wheel_state")
	deps["smasher_magnum_grip_state"] = _get_instance(registry, "smasher_magnum_grip_state")
	deps["smasher_dash_spirit_state"] = _get_instance(registry, "smasher_dash_spirit_state")
	deps["smasher_shield_kiting_state"] = _get_instance(registry, "smasher_shield_kiting_state")
	deps["combo_state"] = _get_instance(registry, "smasher_combo_state")


func _append_viper_deps(deps: Dictionary, registry: Object) -> void:
	deps["viper_skill_runtime"] = _get_instance(registry, "viper_skill_runtime")
	deps["viper_jetpack_state"] = _get_instance(registry, "viper_jetpack_state")
	deps["viper_skill_config"] = _get_instance(registry, "viper_skill_config")
	deps["viper_skill_state"] = _get_instance(registry, "viper_skill_state")


func _append_commando_deps(deps: Dictionary, registry: Object) -> void:
	deps["commando_firearm_runtime"] = _get_instance(registry, "commando_firearm_runtime")


func _append_blacksmith_deps(deps: Dictionary, registry: Object) -> void:
	deps["blacksmith_thor_shield_state"] = _get_instance(registry, "blacksmith_thor_shield_state")
	deps["blacksmith_skill_state"] = _get_instance(registry, "blacksmith_skill_state")


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
