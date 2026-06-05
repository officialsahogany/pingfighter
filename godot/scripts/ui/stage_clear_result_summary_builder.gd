extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const StageClearResultRewardTextResolver := preload("res://scripts/ui/stage_clear_result_reward_text_resolver.gd")

const RESULT_REWARD_SOURCE_STAGE := "stage"
const RESULT_REWARD_SOURCE_BOX := "box"
const RESULT_REWARD_SOURCE_LABELS := {
	"stage": "인게임",
	"box": "상자 보상",
}


static func calculate_starpoint_total(boxes: Array) -> int:
	var total: int = 0
	for box_value in boxes:
		if not (box_value is Dictionary):
			continue
		var box: Dictionary = box_value
		var reward: Variant = box.get("reward", {})
		if not (reward is Dictionary):
			continue
		var reward_dict: Dictionary = reward
		if str(reward_dict.get("type", "")) == "starpoint":
			total += max(0, int(reward_dict.get("amount", 0)) - get_resolved_perk_rewards(reward_dict).size())
	return total


static func resolve_display_gold(runtime_perk_state: Object, fallback_gold: int) -> int:
	if runtime_perk_state != null:
		var gold_value: Variant = runtime_perk_state.get("gold_from_perks")
		if gold_value != null:
			return int(gold_value)
	return fallback_gold


static func calculate_score_rating(player_score: int, boss_score: int) -> int:
	var margin: int = player_score - boss_score
	if margin >= 4:
		return 3
	if margin >= 2:
		return 2
	return 1


static func build_item_summary(
	stage_reward_snapshot: Dictionary,
	boxes: Array,
	stage_source: String = RESULT_REWARD_SOURCE_STAGE,
	box_source: String = RESULT_REWARD_SOURCE_BOX,
	source_labels: Dictionary = RESULT_REWARD_SOURCE_LABELS
) -> Array:
	var items: Array = []
	for reward in get_stage_summary_array(stage_reward_snapshot, "passive_items"):
		if reward is Dictionary:
			items.append(with_result_reward_source(reward as Dictionary, stage_source, source_labels))
	for reward in get_stage_summary_array(stage_reward_snapshot, "active_items"):
		if reward is Dictionary:
			items.append(with_result_reward_source(reward as Dictionary, stage_source, source_labels))
	for box_value in boxes:
		if not (box_value is Dictionary):
			continue
		var box: Dictionary = box_value
		var reward: Variant = box.get("reward", {})
		if not (reward is Dictionary):
			continue
		var reward_dict: Dictionary = reward
		var reward_type: String = str(reward_dict.get("type", ""))
		if reward_type == "active" or reward_type == "passive" or reward_type == "mythic":
			items.append(with_result_reward_source(reward_dict, box_source, source_labels))
	return items


static func split_item_rewards_by_type(item_rewards: Array) -> Dictionary:
	var active_items: Array = []
	var passive_items: Array = []
	var mythic_items: Array = []
	for item_value in item_rewards:
		if not (item_value is Dictionary):
			continue
		var item_dict: Dictionary = item_value
		match str(item_dict.get("type", "")):
			"active":
				active_items.append(item_dict)
			"mythic":
				mythic_items.append(item_dict)
			_:
				passive_items.append(item_dict)
	return {
		"active_items": active_items,
		"passive_items": passive_items,
		"mythic_items": mythic_items,
	}


static func build_perk_summary(
	stage_reward_snapshot: Dictionary,
	boxes: Array,
	stage_source: String = RESULT_REWARD_SOURCE_STAGE,
	box_source: String = RESULT_REWARD_SOURCE_BOX,
	source_labels: Dictionary = RESULT_REWARD_SOURCE_LABELS
) -> Array:
	var perks: Array = []
	for reward in get_stage_summary_array(stage_reward_snapshot, "perks"):
		if reward is Dictionary:
			perks.append(with_result_reward_source(reward as Dictionary, stage_source, source_labels))
	for box_value in boxes:
		if not (box_value is Dictionary):
			continue
		var box: Dictionary = box_value
		var reward: Variant = box.get("reward", {})
		if not (reward is Dictionary):
			continue
		var reward_dict: Dictionary = reward
		for resolved_perk in get_resolved_perk_rewards(reward_dict):
			if resolved_perk is Dictionary:
				perks.append(with_result_reward_source(resolved_perk as Dictionary, box_source, source_labels))
		if is_perk_reward(reward_dict):
			perks.append(with_result_reward_source(reward_dict, box_source, source_labels))
	return perks


static func build_visible_reward_summary(
	stage_reward_snapshot: Dictionary,
	boxes: Array,
	stage_source: String = RESULT_REWARD_SOURCE_STAGE,
	box_source: String = RESULT_REWARD_SOURCE_BOX,
	source_labels: Dictionary = RESULT_REWARD_SOURCE_LABELS
) -> Array:
	var rewards: Array = []
	for reward in get_stage_summary_array(stage_reward_snapshot, "passive_items"):
		if reward is Dictionary:
			rewards.append(with_result_reward_source(reward as Dictionary, stage_source, source_labels))
	for reward in get_stage_summary_array(stage_reward_snapshot, "active_items"):
		if reward is Dictionary:
			rewards.append(with_result_reward_source(reward as Dictionary, stage_source, source_labels))
	for box_value in boxes:
		if not (box_value is Dictionary):
			continue
		var box: Dictionary = box_value
		var reward: Variant = box.get("reward", {})
		if not (reward is Dictionary):
			continue
		var reward_dict: Dictionary = reward
		var resolved_perks: Array = get_resolved_perk_rewards(reward_dict)
		if not resolved_perks.is_empty():
			for resolved_perk in resolved_perks:
				if resolved_perk is Dictionary:
					rewards.append(with_result_reward_source(resolved_perk as Dictionary, box_source, source_labels))
			continue
		var reward_type: String = str(reward_dict.get("type", ""))
		if reward_type == "active" or reward_type == "passive" or reward_type == "mythic" or reward_type == "starpoint":
			rewards.append(with_result_reward_source(reward_dict, box_source, source_labels))
	return rewards


static func build_result_summary_state(
	stage_reward_snapshot: Dictionary,
	boxes: Array,
	stage_source: String = RESULT_REWARD_SOURCE_STAGE,
	box_source: String = RESULT_REWARD_SOURCE_BOX,
	source_labels: Dictionary = RESULT_REWARD_SOURCE_LABELS
) -> Dictionary:
	var item_rewards: Array = build_item_summary(stage_reward_snapshot, boxes, stage_source, box_source, source_labels)
	var perk_rewards: Array = build_perk_summary(stage_reward_snapshot, boxes, stage_source, box_source, source_labels)
	var visible_rewards: Array = build_visible_reward_summary(stage_reward_snapshot, boxes, stage_source, box_source, source_labels)
	var known_sources := [stage_source, box_source]
	return {
		"item_rewards": item_rewards,
		"perk_rewards": perk_rewards,
		"visible_rewards": visible_rewards,
		"item_reward_count": item_rewards.size(),
		"perk_reward_count": perk_rewards.size(),
		"stage_active_item_count": get_stage_summary_array(stage_reward_snapshot, "active_items").size(),
		"stage_passive_item_count": get_stage_summary_array(stage_reward_snapshot, "passive_items").size(),
		"stage_perk_count": get_stage_summary_array(stage_reward_snapshot, "perks").size(),
		"item_reward_source_counts": count_result_reward_sources(item_rewards, known_sources),
		"perk_reward_source_counts": count_result_reward_sources(perk_rewards, known_sources),
		"visible_reward_source_counts": count_result_reward_sources(visible_rewards, known_sources),
		"starpoint_total": calculate_starpoint_total(boxes),
	}


static func build_perk_info_summary(
	perks: Array,
	starpoint_total: int,
	first_perk_title: String,
	first_perk_detail: String
) -> Dictionary:
	if not perks.is_empty():
		var title: String = first_perk_title
		if title == "":
			title = LanguageSettings.translate_text("획득 퍽")
		if perks.size() > 1:
			var extra_count: int = perks.size() - 1
			if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
				title = "%s +%d" % [title, extra_count]
			elif LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
				title = "%s +%d" % [title, extra_count]
			elif LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
				title = "%s +%d" % [title, extra_count]
			elif LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
				title = "%s +%d" % [title, extra_count]
			elif LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
				title = "%s 另%d个" % [title, extra_count]
			elif LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
				title = "%s 他%d個" % [title, extra_count]
			else:
				title = "%s 외 %d개" % [title, extra_count]
		return {
			"kind": "perk",
			"eyebrow": LanguageSettings.translate_text("획득 퍽"),
			"title": title,
			"detail": LanguageSettings.translate_text(first_perk_detail),
		}

	if starpoint_total > 0:
		var detail := "다음 진행 시 획득한 수만큼 퍽 선택창이 열립니다."
		if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
			detail = "The next run will open perk choices for the amount acquired."
		elif LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
			detail = "La siguiente partida abrirá elecciones de perks por la cantidad obtenida."
		elif LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
			detail = "A próxima partida abrirá escolhas de perks pela quantidade obtida."
		elif LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
			detail = "В следующем забеге откроются выборы перков по полученному количеству."
		elif LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
			detail = "下次进行时会按获得数量打开升级选择窗口。"
		elif LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
			detail = "次回進行時、獲得数ぶんパーク選択画面が開きます。"
		return {
			"kind": "starpoint",
			"eyebrow": LanguageSettings.translate_text("퍽 선택"),
			"title": "%s +%d" % [LanguageSettings.translate_text("퍽 선택권"), starpoint_total],
			"detail": detail,
		}

	return {
		"kind": "empty",
		"eyebrow": LanguageSettings.translate_text("퍽 정보"),
		"title": LanguageSettings.translate_text("획득 퍽 없음"),
		"detail": LanguageSettings.translate_text("이번 결과는 아이템 보상만 획득했습니다."),
	}


static func build_perk_info_summary_from_reward_state(
	reward_summary_state: Dictionary,
	perk_catalog: Object,
	detail_fallback_text: String = StageClearResultRewardTextResolver.REWARD_DETAIL_FALLBACK_TEXT,
	starpoint_title_prefix: String = StageClearResultRewardTextResolver.REWARD_STARPOINT_TITLE_PREFIX
) -> Dictionary:
	var perks_value: Variant = reward_summary_state.get("perk_rewards", [])
	var perks: Array = perks_value if perks_value is Array else []
	var first_perk_title: String = ""
	var first_perk_detail: String = ""
	if not perks.is_empty():
		var first_perk: Dictionary = perks[0] if perks[0] is Dictionary else {}
		var first_perk_text_state: Dictionary = StageClearResultRewardTextResolver.get_reward_text_state(
			first_perk,
			perk_catalog,
			get_reward_perk_id(first_perk),
			is_perk_reward(first_perk),
			StageClearResultRewardTextResolver.get_reward_type_fallback_label(str(first_perk.get("type", ""))),
			detail_fallback_text,
			starpoint_title_prefix
		)
		first_perk_title = str(first_perk_text_state.get("title", ""))
		first_perk_detail = str(first_perk_text_state.get("detail", ""))
	return build_perk_info_summary(
		perks,
		int(reward_summary_state.get("starpoint_total", 0)),
		first_perk_title,
		first_perk_detail
	)


static func with_result_reward_source(reward: Dictionary, result_source: String, source_labels: Dictionary) -> Dictionary:
	var copy: Dictionary = reward.duplicate(true)
	copy["_result_reward_source"] = result_source
	copy["_result_reward_source_label"] = LanguageSettings.translate_text(str(source_labels.get(result_source, "")))
	return copy


static func count_result_reward_sources(rewards: Array, known_sources: Array) -> Dictionary:
	var counts: Dictionary = {}
	for source_value in known_sources:
		counts[str(source_value)] = 0
	for reward_value in rewards:
		if not (reward_value is Dictionary):
			continue
		var reward: Dictionary = reward_value
		var source_key: String = str(reward.get("_result_reward_source", ""))
		if source_key == "":
			continue
		counts[source_key] = int(counts.get(source_key, 0)) + 1
	return counts


static func get_stage_summary_array(stage_reward_snapshot: Dictionary, key: String) -> Array:
	var value: Variant = stage_reward_snapshot.get(key, [])
	if value is Array:
		return (value as Array).duplicate(true)
	return []


static func get_resolved_perk_rewards(reward: Dictionary) -> Array:
	var value: Variant = reward.get("resolved_perk_rewards", [])
	if value is Array:
		return (value as Array).duplicate(true)
	return []


static func is_perk_reward(reward: Dictionary) -> bool:
	var reward_type: String = str(reward.get("type", ""))
	return reward_type == "perk" or reward_type == "skill" or get_reward_perk_id(reward) != ""


static func get_reward_perk_id(reward: Dictionary) -> String:
	for key in ["perk_id", "skill_id", "id"]:
		var value: String = str(reward.get(key, ""))
		if value != "":
			return value
	var perk_data: Variant = reward.get("perk_data", {})
	if perk_data is Dictionary:
		return str((perk_data as Dictionary).get("id", ""))
	return ""
