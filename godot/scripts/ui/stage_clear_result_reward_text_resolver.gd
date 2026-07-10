extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const REWARD_DETAIL_FALLBACK_TEXT := "획득한 퍽 효과를 적용합니다."
const REWARD_STARPOINT_TITLE_PREFIX := "퍽 선택권"


static func get_reward_detail_text(reward: Dictionary, perk_data: Dictionary, fallback_detail: String) -> String:
	for key in ["description", "detail", "effect_text"]:
		var direct: String = str(reward.get(key, ""))
		if direct != "":
			return LanguageSettings.translate_text(direct)

	var description: String = str(perk_data.get("description", ""))
	if description != "":
		return LanguageSettings.translate_text(description)
	var descriptions_value: Variant = perk_data.get("descriptions", {})
	if descriptions_value is Dictionary:
		var descriptions: Dictionary = descriptions_value
		var next_level: int = max(1, int(reward.get("next_level", 1)))
		if descriptions.has(next_level):
			return LanguageSettings.translate_text(str(descriptions[next_level]))
		if descriptions.has(1):
			return LanguageSettings.translate_text(str(descriptions[1]))
	var detail: String = str(perk_data.get("detail", ""))
	if detail != "":
		return LanguageSettings.translate_text(detail)

	return LanguageSettings.translate_text(fallback_detail)


static func get_reward_perk_data(reward: Dictionary, perk_catalog: Object, perk_id: String) -> Dictionary:
	var perk_data_value: Variant = reward.get("perk_data", {})
	if perk_data_value is Dictionary:
		var perk_data: Dictionary = perk_data_value
		if not perk_data.is_empty():
			return perk_data.duplicate(true)
	if perk_id == "" or perk_catalog == null or not perk_catalog.has_method("get_perk_data"):
		return {}
	var catalog_value: Variant = perk_catalog.call("get_perk_data", perk_id)
	if catalog_value is Dictionary:
		var catalog_data: Dictionary = catalog_value
		return catalog_data.duplicate(true)
	return {}


static func get_reward_title(
	reward: Dictionary,
	perk_data: Dictionary,
	is_perk_reward: bool,
	fallback_label: String,
	starpoint_title_prefix: String = ""
) -> String:
	if str(reward.get("type", "")) == "starpoint" and starpoint_title_prefix != "":
		return "%s +%d" % [starpoint_title_prefix, int(reward.get("amount", 0))]
	var label: String = str(reward.get("label", ""))
	if label != "":
		return LanguageSettings.translate_text(label)
	if is_perk_reward:
		var perk_name: String = str(perk_data.get("name", ""))
		if perk_name != "":
			return LanguageSettings.translate_text(perk_name)
	return LanguageSettings.translate_text(fallback_label)


static func get_reward_text_state(
	reward: Dictionary,
	perk_catalog: Object,
	perk_id: String,
	is_perk_reward: bool,
	fallback_label: String,
	fallback_detail: String,
	starpoint_title_prefix: String = ""
) -> Dictionary:
	var perk_data: Dictionary = get_reward_perk_data(reward, perk_catalog, perk_id)
	return {
		"perk_data": perk_data,
		"title": get_reward_title(reward, perk_data, is_perk_reward, fallback_label, starpoint_title_prefix),
		"detail": get_reward_detail_text(reward, perk_data, fallback_detail),
	}


static func get_reward_type_fallback_label(reward_type: String) -> String:
	match reward_type:
		"active":
			return LanguageSettings.translate_text("액티브")
		"passive":
			return LanguageSettings.translate_text("패시브")
		"mythic":
			return LanguageSettings.translate_text("신화")
		"mythic_perk":
			return LanguageSettings.translate_text("신화 퍽")
		"mythic_perk_choice":
			return LanguageSettings.translate_text("신화 퍽 선택")
		"starpoint":
			return LanguageSettings.translate_text("스타포인트")
		"perk", "skill":
			return LanguageSettings.translate_text("퍽")
	return LanguageSettings.translate_text("보상")
