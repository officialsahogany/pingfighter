extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")


static func format_facility(facility: String, summary: Dictionary) -> String:
	match facility:
		"bank":
			return format_bank(summary)
		"shop":
			return format_shop(summary)
		"gacha":
			return format_gacha(summary)
		"lingpet_store":
			return format_lingpet_store(summary)
		"blacksmith":
			return format_blacksmith(summary)
		"academy":
			return format_academy(summary)
		"tavern":
			return format_tavern(summary)
	return ""


static func format_bank(summary: Dictionary) -> String:
	var reason := str(summary.get("reason", ""))
	if not bool(summary.get("changed", false)):
		match reason:
			"no_ap":
				return "열쇠가 부족합니다."
			"no_plaza_gold":
				return "맡길 골드가 없습니다."
			"no_bank_deposit":
				return "찾거나 정산할 예금이 없습니다."
			"interest_already_claimed":
				return "이번 스테이지 이자는 이미 정산했습니다."
			_:
				return "지금은 처리할 수 없습니다."
	match str(summary.get("action", "")):
		"deposit":
			return "%dG를 예금했습니다." % int(summary.get("delta_deposit", 0))
		"withdraw":
			return "%dG를 출금했습니다." % int(summary.get("delta_gold", 0))
		"interest":
			return "이자 %dG를 받았습니다." % int(summary.get("interest_gold", 0))
	return "처리했습니다."


static func format_shop(summary: Dictionary) -> String:
	# Stable-key templates keep raw Korean item names out of non-Korean locales.
	var reason := str(summary.get("reason", ""))
	if not bool(summary.get("changed", false)):
		match reason:
			"no_ap":
				return LanguageSettings.translate("plaza.msg.shop.no_ap")
			"not_enough_gold":
				return LanguageSettings.translate("plaza.msg.shop.not_enough_gold")
			"active_slots_full":
				return LanguageSettings.translate("plaza.msg.shop.active_slots_full")
			"no_active_item":
				return LanguageSettings.translate("plaza.msg.shop.no_active_item")
			"no_passive_item":
				return LanguageSettings.translate("plaza.msg.shop.no_passive_item")
			"inventory_full":
				return LanguageSettings.translate("plaza.msg.shop.inventory_full")
			"missing_item_runtime", "missing_owner":
				return LanguageSettings.translate("plaza.msg.shop.missing_item_bag")
			_:
				return LanguageSettings.translate("plaza.msg.shop.default_blocked")
	var localized_name := localize_shop_item_name(summary)
	match str(summary.get("action", "")):
		"purchase":
			return LanguageSettings.translate("plaza.msg.shop.purchase") % [localized_name, int(summary.get("delta_gold", 0))]
		"sale":
			return LanguageSettings.translate("plaza.msg.shop.sale") % [localized_name, int(summary.get("sell_price", 0))]
	return LanguageSettings.translate("plaza.msg.shop.traded")


static func localize_shop_item_name(summary: Dictionary) -> String:
	var korean_display := str(summary.get("display_name", "")).strip_edges()
	var item_id := str(summary.get("item_name", "")).strip_edges()
	if korean_display == "" and item_id == "":
		return LanguageSettings.translate("plaza.msg.shop.fallback_item")
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_KOREAN:
		return korean_display if korean_display != "" else LanguageSettings.translate("plaza.msg.shop.fallback_item")
	var item_data := {"name": item_id}
	if korean_display != "":
		item_data["display_name"] = korean_display
	var localized: Dictionary = LanguageSettings.localize_item_data(item_data)
	var localized_name := str(localized.get("display_name", "")).strip_edges()
	if localized_name == "":
		localized_name = LanguageSettings.translate("plaza.msg.shop.fallback_item")
	return localized_name


static func format_gacha(summary: Dictionary) -> String:
	var reason := str(summary.get("reason", ""))
	var display_name := str(summary.get("display_name", summary.get("item_name", "")))
	if display_name == "":
		display_name = "아이템"
	if not bool(summary.get("changed", false)):
		match reason:
			"no_ap":
				return "열쇠가 부족합니다."
			"not_enough_gold":
				return "뽑기 비용이 부족합니다."
			"active_slots_full":
				return "액티브 슬롯이 가득 찼습니다."
			"missing_item_runtime", "missing_owner":
				return "아이템 가방을 찾을 수 없습니다."
			"empty_gacha_pool":
				return "뽑기 캡슐이 비어 있습니다."
			_:
				return "지금은 뽑을 수 없습니다."
	return "%s을(를) 뽑았습니다. %dG" % [display_name, int(summary.get("delta_gold", 0))]


static func format_lingpet_store(summary: Dictionary) -> String:
	var reason := str(summary.get("reason", ""))
	if str(summary.get("action", "")) == "ring_core":
		if not bool(summary.get("changed", false)):
			match reason:
				"no_ap":
					return "행동력이 부족합니다."
				"not_enough_gold":
					return "링코어 강화 비용이 부족합니다."
				"missing_lingpet_runtime":
					return "링코어 상태를 찾을 수 없습니다."
				"max_ring_core_tier":
					return "링코어가 이미 최대 단계입니다."
				"missing_ring_core_price":
					return "링코어 가격표가 비어 있습니다."
				"perk_slots_full":
					return "퍽 슬롯이 가득 차 링코어를 강화할 수 없습니다."
				"ring_core_upgrade_failed":
					return "링코어 강화에 실패했습니다."
				_:
					return "지금은 링코어를 강화할 수 없습니다."
		return "%s 링코어가 친밀도 Lv.%d까지 열렸습니다. -%dG" % [
			str(summary.get("ring_core_name", "링코어")),
			int(summary.get("new_cap", 0)),
			abs(int(summary.get("delta_gold", 0))),
		]
	if not bool(summary.get("changed", false)):
		match reason:
			"no_ap":
				return "열쇠가 부족합니다."
			"not_enough_gold":
				return "알 뽑기 비용이 부족합니다."
			"egg_already_active":
				return "이미 깨어날 알이 기다리고 있습니다."
			"no_hatch_candidates":
				return "지금 뽑을 수 있는 새 링펫 알이 없습니다."
			"missing_lingpet_runtime", "missing_owner":
				return "링펫 장치를 찾을 수 없습니다."
			"manage_stub":
				return "링펫 관리는 다음 단계에서 열립니다."
			_:
				return "지금은 알을 뽑을 수 없습니다."
	return "공명 알이 전투에 나타났습니다. -%dG" % abs(int(summary.get("delta_gold", 0)))


static func format_blacksmith(summary: Dictionary) -> String:
	var reason := str(summary.get("reason", ""))
	var display_name := str(summary.get("display_name", summary.get("item_name", "")))
	if display_name == "":
		display_name = "아이템"
	if not bool(summary.get("changed", false)):
		match reason:
			"no_ap":
				return "열쇠가 부족합니다."
			"not_enough_gold":
				return "강화 비용이 부족합니다."
			"no_active_item":
				return "강화할 액티브 아이템이 없습니다."
			"max_level":
				return "%s은(는) 이미 최대 강화입니다." % display_name
			"missing_owner":
				return "아이템 가방을 찾을 수 없습니다."
			_:
				return "지금은 강화할 수 없습니다."
	match str(summary.get("result", "")):
		"success":
			return "%s +%d 강화 성공! -%dG" % [display_name, int(summary.get("new_level", 0)), abs(int(summary.get("delta_gold", 0)))]
		"maintain":
			return "%s 강화 유지. -%dG" % [display_name, abs(int(summary.get("delta_gold", 0)))]
		"fail":
			return "%s 강화 실패. 아이템은 유지됩니다. -%dG" % [display_name, abs(int(summary.get("delta_gold", 0)))]
	return "강화를 시도했습니다."


static func format_academy(summary: Dictionary) -> String:
	var reason := str(summary.get("reason", ""))
	if not bool(summary.get("changed", false)):
		match reason:
			"no_ap":
				return "행동력이 부족합니다."
			"not_enough_gold":
				return "수업료가 부족합니다."
			"missing_owner":
				return "현재 캐릭터를 찾을 수 없습니다."
			"missing_runtime_perk_state", "missing_runtime_perk_catalog":
				return "스킬 수업 장치를 찾을 수 없습니다."
			"choice_already_active":
				return "이미 진행 중인 스킬 선택이 있습니다."
			"no_academy_choices":
				return "지금 배울 수 있는 스킬이 없습니다."
			"exchange_stub":
				return "스킬 교환은 다음 단계에서 열립니다."
			_:
				return "지금은 수업을 진행할 수 없습니다."
	if bool(summary.get("choice_opened", false)):
		return "스킬 수업을 시작합니다. -%dG" % abs(int(summary.get("delta_gold", 0)))
	return "수업료를 냈지만 선택지를 열지 못했습니다."


static func format_tavern(summary: Dictionary) -> String:
	var reason := str(summary.get("reason", ""))
	var quest_name := str(summary.get("quest_name", "의뢰"))
	if quest_name == "":
		quest_name = "의뢰"
	if not bool(summary.get("changed", false)):
		match reason:
			"no_ap":
				return "행동력이 부족합니다."
			"quest_already_active":
				return "이미 진행 중인 의뢰가 있습니다."
			"stage_already_accepted":
				return "이번 스테이지의 의뢰는 이미 받았습니다."
			"invalid_quest":
				return "의뢰서가 손상되었습니다."
			"no_active_quest":
				return "보고할 의뢰가 없습니다."
			"quest_in_progress":
				return "다음 전투를 마친 뒤 보고할 수 있습니다."
			"missing_plaza_save_store":
				return "의뢰 장부를 찾을 수 없습니다."
			_:
				return "지금은 의뢰를 처리할 수 없습니다."
	match str(summary.get("action", "")):
		"accept":
			return "%s 의뢰를 받았습니다." % quest_name
		"complete":
			return "%s 보고 완료. +%dG" % [quest_name, int(summary.get("delta_gold", 0))]
	return "의뢰를 처리했습니다."
