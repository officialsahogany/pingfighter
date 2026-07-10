extends RefCounted

const RuntimePerkCharacterContext := preload("res://scripts/characters/runtime_perk_character_context.gd")
const RuntimePerkRegistryLookup := preload("res://scripts/characters/runtime_perk_registry_lookup.gd")

var _character_context: Object = RuntimePerkCharacterContext.new()
var _registry_lookup: Object = RuntimePerkRegistryLookup.new()


func get_eligible_buff_ids(
	angel_state: Object,
	character_type: String,
	registry: Object
) -> Array[String]:
	if angel_state == null or not angel_state.has_method("get_eligible_buff_ids"):
		return []
	var values: Array = angel_state.get_eligible_buff_ids(
		has_live_player_skill_cooldown(character_type, registry)
	)
	var result: Array[String] = []
	for value: Variant in values:
		result.append(str(value))
	return result


func has_live_player_skill_cooldown(character_type: String, registry: Object) -> bool:
	return bool(get_capability(character_type, registry).get("eligible", false))


func get_capability(character_type: String, registry: Object) -> Dictionary:
	var normalized_character: String = _character_context.normalize_character_type(character_type)
	var config_key: String = _character_context.get_skill_config_key(normalized_character)
	var state_key: String = _character_context.get_skill_state_key(normalized_character)
	var result := {
		"character_type": normalized_character,
		"skill_config_key": config_key,
		"skill_state_key": state_key,
		"configured_skill_ids": [],
		"eligible": false,
		"reason": "",
	}
	if config_key.is_empty():
		result["reason"] = "no_skill_config"
		return result
	if state_key.is_empty():
		result["reason"] = "no_skill_state"
		return result

	var skill_config: Object = _registry_lookup.get_instance(registry, config_key)
	if skill_config == null or not skill_config.has_method("get_snapshot"):
		result["reason"] = "missing_skill_config"
		return result
	if not _is_live_cooldown_config(skill_config):
		result["reason"] = "missing_live_config_contract"
		return result
	var snapshot_value: Variant = skill_config.get_snapshot()
	if not (snapshot_value is Dictionary):
		result["reason"] = "invalid_skill_config_snapshot"
		return result
	var snapshot: Dictionary = snapshot_value
	if not bool(snapshot.get("cooldown_reduction_eligible", false)):
		result["reason"] = "cooldown_contract_not_live"
		return result
	var configured_skill_ids: Array[String] = _get_declared_cooldown_skill_ids(snapshot)
	result["configured_skill_ids"] = configured_skill_ids
	if configured_skill_ids.is_empty():
		result["reason"] = "no_declared_cooldown_skills"
		return result

	var skill_state: Object = _registry_lookup.get_instance(registry, state_key)
	if not _is_live_cooldown_state(skill_state):
		result["reason"] = "missing_live_timer_owner"
		return result

	result["eligible"] = true
	result["reason"] = "live_configured_cooldown"
	return result


func _get_declared_cooldown_skill_ids(snapshot: Dictionary) -> Array[String]:
	var declared_value: Variant = snapshot.get("cooldown_reduction_skill_ids", [])
	if not (declared_value is Array):
		return []
	var cooldowns_value: Variant = snapshot.get("cooldown_seconds", {})
	if not (cooldowns_value is Dictionary):
		return []
	var cooldowns: Dictionary = cooldowns_value
	var result: Array[String] = []
	for skill_id_value: Variant in declared_value:
		var skill_id := str(skill_id_value).strip_edges()
		if not skill_id.is_empty() and cooldowns.has(skill_id) and skill_id not in result:
			result.append(skill_id)
	result.sort()
	return result


func _is_live_cooldown_state(skill_state: Object) -> bool:
	if skill_state == null:
		return false
	return (
		skill_state.has_method("trigger_configured_cooldown")
		and skill_state.has_method("get_configured_cooldown_remaining")
		and skill_state.has_method("get_cooldown_remaining")
		and skill_state.has_method("get_cooldown_total_seconds")
	)


func _is_live_cooldown_config(skill_config: Object) -> bool:
	return (
		skill_config.has_method("get_cooldown_seconds")
		and skill_config.has_method("set_runtime_cooldown_multiplier")
		and skill_config.has_method("set_item_cooldown_multiplier")
	)
