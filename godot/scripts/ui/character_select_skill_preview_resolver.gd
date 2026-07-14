extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")


static func get_preview_data(character: Dictionary, icon_index: int, config_cache: Dictionary) -> Dictionary:
	var skill_ids := get_character_skill_preview_ids(character)
	if icon_index < 0 or icon_index >= skill_ids.size():
		return {}
	var skill_id := str(skill_ids[icon_index]).strip_edges()
	if skill_id == "":
		return {}
	var skill_config := get_skill_config_for_character(character, config_cache)
	if skill_config == null or not skill_config.has_method("get_skill_data"):
		return {}
	var data_value: Variant = skill_config.get_skill_data(skill_id)
	if data_value is Dictionary:
		var skill_data: Dictionary = data_value
		if not skill_data.is_empty():
			return skill_data
	return {}


static func get_character_skill_preview_ids(character: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var configured_ids_value: Variant = character.get("skill_preview_ids", [])
	if configured_ids_value is Array:
		for id_value in configured_ids_value:
			result.append(str(id_value))
	if not result.is_empty():
		return result
	var icon_paths_value: Variant = character.get("skill_icon_paths", [])
	if icon_paths_value is Array:
		for path_value in icon_paths_value:
			result.append(infer_skill_id_from_icon_path(str(path_value), character))
	return result


static func infer_skill_id_from_icon_path(path: String, character: Dictionary) -> String:
	var file_name := path
	var slash_index: int = max(path.rfind("/"), path.rfind("\\"))
	if slash_index >= 0:
		file_name = path.substr(slash_index + 1)
	if file_name.ends_with(".png"):
		file_name = file_name.substr(0, file_name.length() - 4)
	if file_name.ends_with("_skill_orb"):
		file_name = file_name.substr(0, file_name.length() - "_skill_orb".length())
	var runtime_id := normalize_runtime_id(character)
	var prefix := "commando" if runtime_id == "commando" else runtime_id
	if prefix == "commando" and file_name == "commando_pistol":
		return "commando_pistol"
	if prefix != "" and file_name.begins_with("%s_" % prefix):
		return file_name.substr(prefix.length() + 1)
	return file_name


static func get_skill_config_for_character(character: Dictionary, config_cache: Dictionary) -> Object:
	var runtime_id := normalize_runtime_id(character)
	match runtime_id:
		"smasher":
			if not config_cache.has("smasher"):
				config_cache["smasher"] = SmasherSkillConfig.new()
			return config_cache["smasher"]
		"commando":
			if not config_cache.has("commando"):
				config_cache["commando"] = CommandoSkillConfig.new()
			return config_cache["commando"]
		"viper":
			if not config_cache.has("viper"):
				config_cache["viper"] = ViperSkillConfig.new()
			return config_cache["viper"]
	return null


static func normalize_runtime_id(character: Dictionary) -> String:
	var runtime_id := str(character.get("runtime_id", character.get("id", ""))).strip_edges().to_lower()
	return "commando" if runtime_id == "soldier" else runtime_id


static func skill_data_color(skill_data: Dictionary, fallback: Color) -> Color:
	var value: Variant = skill_data.get("color", fallback)
	return value if value is Color else fallback


static func format_skill_meta(skill_data: Dictionary) -> String:
	var cost: float = float(skill_data.get("cost", 0.0))
	var cooldown: float = float(skill_data.get("cooldown", 0.0))
	if cost > 0.0 and cooldown > 0.0:
		return LanguageSettings.translate_text("비용 %s  쿨타임 %s초" % [format_number(cost), format_number(cooldown)])
	if cooldown > 0.0:
		return LanguageSettings.translate_text("쿨타임 %s초" % format_number(cooldown))
	if cost > 0.0:
		return "비용 %s" % format_number(cost)
	return ""


static func format_number(value: float) -> String:
	var rounded: float = round(value)
	if is_equal_approx(value, rounded):
		return str(int(rounded))
	var text := "%.1f" % value
	if text.ends_with(".0"):
		text = text.substr(0, text.length() - 2)
	return text
