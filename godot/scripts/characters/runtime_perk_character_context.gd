extends RefCounted

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")

var _battle_scene_config: Object = BattleSceneConfig.new()


func get_skill_config_key(character_type: String) -> String:
	match normalize_character_type(character_type):
		"viper":
			return "viper_skill_config"
		"soldier":
			return "commando_skill_config"
		"optimus":
			return "optimus_skill_config"
		"blacksmith":
			return "blacksmith_skill_config"
	return "smasher_skill_config"


func get_skill_state_key(character_type: String) -> String:
	match normalize_character_type(character_type):
		"viper":
			return "viper_skill_state"
		"soldier":
			return "commando_skill_state"
		"optimus":
			return ""
		"blacksmith":
			return "blacksmith_skill_state"
	return "smasher_skill_state"


func get_owner_skill_state_key(owner: Object) -> String:
	return get_skill_state_key(get_owner_character_type(owner))


func normalize_character_type(character_type: String) -> String:
	var normalized: String = str(character_type).strip_edges().to_lower()
	if normalized == "viper":
		return "viper"
	if normalized == "soldier" or normalized == "commando":
		return "soldier"
	if normalized == "optimus" or normalized == "io":
		return "optimus"
	if normalized == "blacksmith" or normalized == "baltor" or normalized == "kohaku":
		return "blacksmith"
	return "smasher"


func get_owner_character_type(owner: Object) -> String:
	if owner == null:
		return "smasher"
	var value: Variant = owner.get("selected_character_type")
	if value == null:
		return "smasher"
	var normalized: String = str(value).strip_edges().to_lower()
	if normalized == "viper":
		return "viper"
	if normalized == "soldier" or normalized == "commando":
		return "soldier"
	if normalized == "optimus" or normalized == "io":
		return "optimus"
	if normalized == "blacksmith" or normalized == "baltor" or normalized == "kohaku":
		return "blacksmith"
	return "smasher"


func get_normalized_owner_character_type(owner: Object) -> String:
	if owner == null:
		return "smasher"
	var value: Variant = owner.get("selected_character_type")
	if value == null:
		return "smasher"
	return normalize_character_type(str(value))


func get_current_stage(owner: Object) -> int:
	if owner == null:
		return 0
	var value: Variant = owner.get("current_stage")
	if value == null:
		return 0
	return max(0, int(value))


func get_starting_dash_tokens(owner: Object) -> int:
	if owner == null:
		return 1
	var owner_value: Variant = owner.get("starting_dash_tokens")
	if owner_value != null:
		return max(1, int(owner_value))
	if _battle_scene_config != null and _battle_scene_config.has_method("get_starting_dash_tokens"):
		return max(1, int(_battle_scene_config.get_starting_dash_tokens(owner)))
	return 1
