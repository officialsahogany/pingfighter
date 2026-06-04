extends RefCounted


func build_deps(registry: Object) -> Dictionary:
	return {
		"skill_state": _get_instance(registry, "smasher_skill_state"),
		"skill_states": [
			_get_instance(registry, "smasher_skill_state"),
			_get_instance(registry, "viper_skill_state"),
			_get_instance(registry, "commando_skill_state"),
			_get_instance(registry, "optimus_energy_state"),
			_get_instance(registry, "blacksmith_skill_state"),
		],
		"drive_input_state": _get_instance(registry, "smasher_drive_input_state"),
		"smasher_plasma_state": _get_instance(registry, "smasher_plasma_state"),
		"smasher_recovery_state": _get_instance(registry, "smasher_recovery_state"),
		"smasher_cleanse_state": _get_instance(registry, "smasher_cleanse_state"),
		"status_effect_state": _get_instance(registry, "status_effect_state"),
		"smasher_warp_gate_state": _get_instance(registry, "smasher_warp_gate_state"),
		"smasher_wheel_state": _get_instance(registry, "smasher_wheel_state"),
		"smasher_magnum_grip_state": _get_instance(registry, "smasher_magnum_grip_state"),
		"smasher_dash_spirit_state": _get_instance(registry, "smasher_dash_spirit_state"),
		"smasher_shield_kiting_state": _get_instance(registry, "smasher_shield_kiting_state"),
		"blacksmith_thor_shield_state": _get_instance(registry, "blacksmith_thor_shield_state"),
		"laurel_leaf_shield_state": _get_instance(registry, "laurel_leaf_shield_state"),
		"monkey_blessing_delivery_state": _get_instance(registry, "monkey_blessing_delivery_state"),
		"commando_reload_delivery_state": _get_instance(registry, "commando_reload_delivery_state"),
		"runtime_perk_state": _get_instance(registry, "runtime_perk_state"),
		"optimus_energy_state": _get_instance(registry, "optimus_energy_state"),
		"skill_configs": [
			_get_instance(registry, "smasher_skill_config"),
			_get_instance(registry, "viper_skill_config"),
			_get_instance(registry, "commando_skill_config"),
			_get_instance(registry, "blacksmith_skill_config"),
		],
		"skill_runtimes": [
			_get_instance(registry, "viper_skill_runtime"),
			_get_instance(registry, "commando_emergency_supply_state"),
			_get_instance(registry, "commando_firearm_runtime"),
			_get_instance(registry, "commando_supply_drop_state"),
		],
		"dash_state": _get_instance(registry, "smasher_dash_state"),
	}


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
