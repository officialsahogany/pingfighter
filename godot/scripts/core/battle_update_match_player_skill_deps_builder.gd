extends RefCounted

const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

const CHARACTER_KEY_SMASHER := PlayerCharacterRuntime.SMASHER
const CHARACTER_KEY_VIPER := PlayerCharacterRuntime.VIPER
const CHARACTER_KEY_COMMANDO := "commando"
const CHARACTER_KEY_OPTIMUS := PlayerCharacterRuntime.OPTIMUS
const CHARACTER_KEY_BLACKSMITH := PlayerCharacterRuntime.BLACKSMITH

const CHARACTER_SKILL_ORDER := [
	CHARACTER_KEY_SMASHER,
	CHARACTER_KEY_VIPER,
	CHARACTER_KEY_COMMANDO,
	CHARACTER_KEY_OPTIMUS,
	CHARACTER_KEY_BLACKSMITH,
]
const CHARACTER_SKILL_KEYS := {
	CHARACTER_KEY_SMASHER: {
		"state": "smasher_skill_state",
		"config": "smasher_skill_config",
		"runtimes": [],
	},
	CHARACTER_KEY_VIPER: {
		"state": "viper_skill_state",
		"config": "viper_skill_config",
		"runtimes": ["viper_skill_runtime"],
	},
	CHARACTER_KEY_COMMANDO: {
		"state": "commando_skill_state",
		"config": "commando_skill_config",
		"runtimes": [
			"commando_emergency_supply_state",
			"commando_firearm_runtime",
			"commando_supply_drop_state",
		],
	},
	CHARACTER_KEY_OPTIMUS: {
		"state": "optimus_energy_state",
		"config": "",
		"runtimes": [],
	},
	CHARACTER_KEY_BLACKSMITH: {
		"state": "blacksmith_skill_state",
		"config": "blacksmith_skill_config",
		"runtimes": [],
	},
}

var character_runtime: Object = PlayerCharacterRuntime.new()


func build_deps(registry: Object, character_type: String = "") -> Dictionary:
	var raw_character := character_type.strip_edges().to_lower()
	var scoped := not raw_character.is_empty()
	var normalized_character: String = character_runtime.normalize(raw_character) if scoped else ""
	var character_key := _get_character_skill_key(normalized_character) if scoped else ""
	var include_smasher := _should_include_character(scoped, character_key, CHARACTER_KEY_SMASHER)
	var include_optimus := _should_include_character(scoped, character_key, CHARACTER_KEY_OPTIMUS)
	var include_blacksmith := _should_include_character(scoped, character_key, CHARACTER_KEY_BLACKSMITH)
	var skill_states: Array = _build_skill_states(registry, scoped, character_key)
	var skill_configs: Array = _build_skill_configs(registry, scoped, character_key)
	return {
		"skill_state": _build_primary_skill_state(registry, scoped, character_key),
		"skill_states": skill_states,
		"drive_input_state": _get_instance(registry, "smasher_drive_input_state") if include_smasher else null,
		"smasher_plasma_state": _get_instance(registry, "smasher_plasma_state") if include_smasher else null,
		"smasher_recovery_state": _get_instance(registry, "smasher_recovery_state") if include_smasher else null,
		"smasher_cleanse_state": _get_instance(registry, "smasher_cleanse_state") if include_smasher else null,
		"status_effect_state": _get_instance(registry, "status_effect_state"),
		"smasher_warp_gate_state": _get_instance(registry, "smasher_warp_gate_state") if include_smasher else null,
		"smasher_wheel_state": _get_instance(registry, "smasher_wheel_state") if include_smasher else null,
		"smasher_overdrive_state": _get_instance(registry, "smasher_overdrive_state") if include_smasher else null,
		"smasher_magnum_grip_state": _get_instance(registry, "smasher_magnum_grip_state") if include_smasher else null,
		"smasher_dash_spirit_state": _get_instance(registry, "smasher_dash_spirit_state") if include_smasher else null,
		"smasher_shield_kiting_state": _get_instance(registry, "smasher_shield_kiting_state") if include_smasher else null,
		"blacksmith_thor_shield_state": _get_instance(registry, "blacksmith_thor_shield_state") if include_blacksmith else null,
		"laurel_leaf_shield_state": _get_instance(registry, "laurel_leaf_shield_state"),
		"monkey_blessing_delivery_state": _get_instance(registry, "monkey_blessing_delivery_state"),
		"commando_reload_delivery_state": _get_instance(registry, "commando_reload_delivery_state"),
		"runtime_perk_state": _get_instance(registry, "runtime_perk_state"),
		"optimus_energy_state": _get_instance(registry, "optimus_energy_state") if include_optimus else null,
		"skill_configs": skill_configs,
		"skill_runtimes": _build_skill_runtimes(registry, scoped, character_key),
		"dash_state": _get_instance(registry, "smasher_dash_state"),
	}


func _get_character_skill_key(normalized_character: String) -> String:
	if character_runtime.is_viper(normalized_character):
		return CHARACTER_KEY_VIPER
	if character_runtime.is_commando(normalized_character):
		return CHARACTER_KEY_COMMANDO
	if character_runtime.is_optimus(normalized_character):
		return CHARACTER_KEY_OPTIMUS
	if character_runtime.is_blacksmith(normalized_character):
		return CHARACTER_KEY_BLACKSMITH
	return CHARACTER_KEY_SMASHER


func _should_include_character(scoped: bool, selected_character_key: String, character_key: String) -> bool:
	return not scoped or selected_character_key == character_key


func _get_character_skill_entry(character_key: String) -> Dictionary:
	return CHARACTER_SKILL_KEYS.get(character_key, {})


func _get_character_registry_key(character_key: String, field: String) -> String:
	return str(_get_character_skill_entry(character_key).get(field, ""))


func _build_primary_skill_state(registry: Object, scoped: bool, selected_character_key: String) -> Object:
	var character_key := selected_character_key if scoped else CHARACTER_KEY_SMASHER
	var state_key := _get_character_registry_key(character_key, "state")
	return _get_instance(registry, state_key) if state_key != "" else null


func _build_skill_states(registry: Object, scoped: bool, selected_character_key: String) -> Array:
	var result: Array = []
	for character_key in CHARACTER_SKILL_ORDER:
		var state_key := _get_character_registry_key(character_key, "state")
		var value := _get_instance(registry, state_key) if _should_include_character(scoped, selected_character_key, character_key) else null
		result.append(value)
	return result


func _build_skill_configs(registry: Object, scoped: bool, selected_character_key: String) -> Array:
	var result: Array = []
	for character_key in CHARACTER_SKILL_ORDER:
		var config_key := _get_character_registry_key(character_key, "config")
		if config_key == "":
			continue
		var value := _get_instance(registry, config_key) if _should_include_character(scoped, selected_character_key, character_key) else null
		result.append(value)
	return result


func _build_skill_runtimes(registry: Object, scoped: bool, selected_character_key: String) -> Array:
	var result: Array = []
	for character_key in CHARACTER_SKILL_ORDER:
		if not _should_include_character(scoped, selected_character_key, character_key):
			continue
		var runtimes_value: Variant = _get_character_skill_entry(character_key).get("runtimes", [])
		if not (runtimes_value is Array):
			continue
		for runtime_key_value in runtimes_value:
			var runtime_key := str(runtime_key_value)
			if runtime_key != "":
				result.append(_get_instance(registry, runtime_key))
	return result


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
