extends RefCounted

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")


static func build_perk_rewards(
	current_levels: Dictionary,
	baseline_levels: Dictionary,
	perk_catalog: Object
) -> Array:
	var rewards: Array = []
	for perk_id_value in current_levels.keys():
		var perk_id: String = str(perk_id_value)
		var current_level: int = int(current_levels.get(perk_id_value, 0))
		var baseline_level: int = int(baseline_levels.get(perk_id, baseline_levels.get(perk_id_value, 0)))
		if current_level <= baseline_level:
			continue
		var perk_reward: Dictionary = build_perk_reward(
			perk_id,
			baseline_level,
			current_level,
			perk_catalog
		)
		if not perk_reward.is_empty():
			rewards.append(perk_reward)
	return rewards


static func build_perk_reward(
	perk_id: String,
	baseline_level: int,
	current_level: int,
	perk_catalog: Object
) -> Dictionary:
	if perk_id == "" or current_level <= baseline_level:
		return {}
	# Common active-orb skill levels are derived from their unlock-manual
	# perks. Listing both produces a valid localized manual card plus a second
	# internal-id row such as `soul_summon_art 고유` on the result scroll.
	if CommonSkillCatalog.is_common_skill(perk_id):
		return {}
	var perk_data: Dictionary = {}
	if perk_catalog != null and perk_catalog.has_method("get_perk_data"):
		var perk_value: Variant = perk_catalog.get_perk_data(perk_id)
		if perk_value is Dictionary:
			perk_data = (perk_value as Dictionary).duplicate(true)
	var perk_name: String = str(perk_data.get("name", perk_id))
	var label: String = "%s %s" % [
		perk_name,
		LanguageSettings.format_mugong_rank(perk_data, current_level),
	]
	if current_level - baseline_level > 1:
		label = "%s +%d" % [label, current_level - baseline_level]
	return {
		"type": "perk",
		"label": label,
		"perk_id": perk_id,
		"id": perk_id,
		"current_level": baseline_level,
		"next_level": current_level,
		"level_delta": current_level - baseline_level,
		"source": "stage_perk",
		"perk_data": perk_data,
	}
