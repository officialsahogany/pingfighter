extends RefCounted

const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")


static func get_display_name(lingpet_id: String) -> String:
	if LingpetCatalog.has_pet(lingpet_id):
		return LingpetCatalog.get_display_name(lingpet_id)
	match lingpet_id:
		"maribo":
			return "마리보"
		"":
			return "링펫"
		_:
			return lingpet_id


static func get_skill_specs(snapshot: Dictionary, stat_buff_color: Color) -> Array:
	var specs: Array = []
	var skill_id := str(snapshot.get("companion_skill_id", "")).strip_edges()
	if not skill_id.is_empty():
		var skill_name := str(snapshot.get("companion_skill_name", "")).strip_edges()
		if skill_name.is_empty():
			skill_name = "액티브 스킬"
		var active_cooldown := float(snapshot.get("companion_skill_cooldown_duration", 0.0))
		var skill_description := str(snapshot.get("companion_skill_description", "")).strip_edges()
		if skill_description.is_empty():
			skill_description = "링펫이 전투 중 자동으로 사용하는 액티브 스킬입니다."
		var icon_texture_id := str(snapshot.get("companion_skill_icon_path", "")).strip_edges()
		var skill_level := int(snapshot.get("companion_skill_level", 0))
		var active_level_label := "Lv.%d · " % skill_level if skill_level > 0 else ""
		specs.append({
			"id": skill_id,
			"title": skill_name,
			"subtitle": LanguageSettings.translate_text("액티브 · %s쿨타임 %s") % [active_level_label, LanguageSettings.translate_text(CharacterInfoOverlayFormatter.format_seconds_text(active_cooldown))],
			"body": skill_description,
			"color": Color(80.0 / 255.0, 220.0 / 255.0, 1.0),
			"badge": "A",
			"use_card": icon_texture_id.is_empty(),
			"icon_texture_id": icon_texture_id,
			"card_texture_path": str(snapshot.get("companion_skill_card_path", "")),
		})
	var second_skill_id := str(snapshot.get("companion_skill_id_1", "")).strip_edges()
	if not second_skill_id.is_empty():
		var second_skill_name := str(snapshot.get("companion_skill_name_1", "")).strip_edges()
		if second_skill_name.is_empty():
			second_skill_name = "2nd active"
		var second_active_cooldown := float(snapshot.get("companion_skill_cooldown_duration_1", 0.0))
		var second_skill_description := str(snapshot.get("companion_skill_description_1", "")).strip_edges()
		if second_skill_description.is_empty():
			second_skill_description = "두 번째 액티브 슬롯에 장착된 링펫 스킬입니다."
		var second_icon_texture_id := str(snapshot.get("companion_skill_icon_path_1", "")).strip_edges()
		var second_skill_level := int(snapshot.get("companion_skill_level_1", 0))
		var second_active_level_label := "Lv.%d / " % second_skill_level if second_skill_level > 0 else ""
		specs.append({
			"id": second_skill_id,
			"title": second_skill_name,
			"subtitle": "2nd active / %s%s" % [second_active_level_label, CharacterInfoOverlayFormatter.format_seconds_text(second_active_cooldown)],
			"body": second_skill_description,
			"color": Color(80.0 / 255.0, 220.0 / 255.0, 1.0),
			"badge": "A",
			"use_card": second_icon_texture_id.is_empty(),
			"icon_texture_id": second_icon_texture_id,
			"card_texture_path": str(snapshot.get("companion_skill_card_path_1", "")),
		})
	var gauge_bonus_pct := float(snapshot.get("gauge_gain_bonus_pct", 0.0))
	var player_speed_bonus_pct := float(snapshot.get("companion_player_speed_bonus_pct", 0.0))
	var starpoint_tracking_chance_pct := float(snapshot.get("companion_starpoint_tracking_chance_pct", 0.0))
	var ring_dash_chance_pct := float(snapshot.get("companion_ring_dash_chance_pct", 0.0))
	var passive_id := str(snapshot.get("companion_passive_skill_id", "")).strip_edges()
	if not passive_id.is_empty():
		var passive_name := str(snapshot.get("companion_passive_skill_name", "")).strip_edges()
		if passive_name.is_empty():
			passive_name = "패시브 스킬"
		var passive_description := str(snapshot.get("companion_passive_skill_description", "")).strip_edges()
		if passive_description.is_empty():
			passive_description = "링펫에게 배정된 패시브 스킬입니다."
		var passive_subtitle := LanguageSettings.translate_text("패시브")
		var passive_level := int(snapshot.get("companion_passive_skill_level", 0))
		if passive_level > 0:
			passive_subtitle += " · Lv.%d" % passive_level
		if gauge_bonus_pct > 0.0:
			passive_subtitle += " · " + LanguageSettings.translate_text("받아치기") + " +" + CharacterInfoOverlayFormatter.format_percent_text(gauge_bonus_pct)
		if player_speed_bonus_pct > 0.0:
			passive_subtitle += " · " + LanguageSettings.translate_text("이동") + " +" + CharacterInfoOverlayFormatter.format_percent_text(player_speed_bonus_pct)
		if starpoint_tracking_chance_pct > 0.0:
			passive_subtitle += " · " + LanguageSettings.translate_text("추적") + " " + CharacterInfoOverlayFormatter.format_percent_text(starpoint_tracking_chance_pct)
		if ring_dash_chance_pct > 0.0:
			passive_subtitle += " · " + LanguageSettings.translate_text("전이") + " " + CharacterInfoOverlayFormatter.format_percent_text(ring_dash_chance_pct)
		specs.append({
			"id": passive_id,
			"title": passive_name,
			"subtitle": passive_subtitle,
			"body": passive_description,
			"color": stat_buff_color,
			"badge": "P",
			"icon_texture_id": str(snapshot.get("companion_passive_skill_icon_path", snapshot.get("gauge_gain_bonus_icon_path", ""))),
		})
	elif gauge_bonus_pct > 0.0:
		var fallback_passive := LingpetCatalog.get_passive_skill(str(snapshot.get("pet_id", "")))
		var fallback_passive_id := str(fallback_passive.get("id", "")).strip_edges()
		var fallback_passive_title := str(fallback_passive.get("name", "")).strip_edges()
		var fallback_passive_description := str(fallback_passive.get("description", "")).strip_edges()
		var fallback_icon_texture_id := str(snapshot.get("gauge_gain_bonus_icon_path", "")).strip_edges()
		if fallback_icon_texture_id.is_empty():
			fallback_icon_texture_id = str(fallback_passive.get("icon_texture_path", "")).strip_edges()
		if fallback_passive_id.is_empty():
			fallback_passive_id = "lingpet_resonance_boost"
		if fallback_passive_title.is_empty():
			fallback_passive_title = "공명 증폭"
		if fallback_passive_description.is_empty():
			fallback_passive_description = "플레이어가 공을 받아칠 때 게이지 획득량이 증가합니다."
		specs.append({
			"id": fallback_passive_id,
			"title": fallback_passive_title,
			"subtitle": "패시브 · 받아치기 +" + CharacterInfoOverlayFormatter.format_percent_text(gauge_bonus_pct),
			"body": fallback_passive_description,
			"color": stat_buff_color,
			"badge": "P",
			"icon_texture_id": fallback_icon_texture_id,
		})
	var second_passive_id := str(snapshot.get("companion_passive_skill_id_1", "")).strip_edges()
	if not second_passive_id.is_empty():
		var second_passive_name := str(snapshot.get("companion_passive_skill_name_1", "")).strip_edges()
		if second_passive_name.is_empty():
			second_passive_name = "2nd passive"
		var second_passive_description := str(snapshot.get("companion_passive_skill_description_1", "")).strip_edges()
		if second_passive_description.is_empty():
			second_passive_description = "두 번째 패시브 슬롯에 장착된 링펫 스킬입니다."
		var second_passive_subtitle := "2nd passive"
		var second_passive_level := int(snapshot.get("companion_passive_skill_level_1", 0))
		if second_passive_level > 0:
			second_passive_subtitle += " / Lv.%d" % second_passive_level
		specs.append({
			"id": second_passive_id,
			"title": second_passive_name,
			"subtitle": second_passive_subtitle,
			"body": second_passive_description,
			"color": stat_buff_color,
			"badge": "P",
			"icon_texture_id": str(snapshot.get("companion_passive_skill_icon_path_1", "")),
		})
	return specs


static func first_open_unlock_option(unlock_options: Array) -> Dictionary:
	for option in unlock_options:
		if not (option is Dictionary):
			continue
		var choice: Dictionary = option
		if bool(choice.get("locked", false)):
			continue
		var candidates: Array = choice.get("candidates", []) as Array
		if candidates.size() >= 2:
			return choice
	return {}


static func count_open_unlock_options(unlock_options: Array) -> int:
	var count := 0
	for option in unlock_options:
		if not (option is Dictionary):
			continue
		var choice: Dictionary = option
		if bool(choice.get("locked", false)):
			continue
		var candidates: Array = choice.get("candidates", []) as Array
		if candidates.size() >= 2:
			count += 1
	return count


static func unlock_candidate_spec(pet_id: String, choice_key: String, candidate_id: String, stat_buff_color: Color, accent_blue: Color) -> Dictionary:
	var active_choice := choice_key == "active" or choice_key == "second_active"
	var entry := LingpetCatalog.get_active_skill_entry(candidate_id) if active_choice else LingpetCatalog.get_passive_skill_entry(candidate_id)
	var title := str(entry.get("name", "")).strip_edges()
	if title.is_empty():
		title = candidate_id
	var body := str(entry.get("description", "")).strip_edges()
	if body.is_empty():
		body = "선택하면 이 스킬이 링펫 슬롯에 고정됩니다."
	var icon_path := str(entry.get("icon_texture_path", "")).strip_edges()
	if not active_choice and icon_path.is_empty():
		icon_path = LingpetCatalog.get_passive_icon_path(pet_id, candidate_id)
	return {
		"id": candidate_id,
		"title": title,
		"subtitle": unlock_choice_subtitle(choice_key),
		"body": body,
		"color": accent_blue if active_choice else stat_buff_color,
		"badge": "A" if active_choice else "P",
		"use_card": active_choice and not str(entry.get("card_texture_path", "")).strip_edges().is_empty(),
		"icon_texture_id": icon_path,
		"card_texture_path": str(entry.get("card_texture_path", "")).strip_edges(),
	}


static func unlock_choice_title(choice_key: String) -> String:
	match choice_key:
		"active":
			return "액티브 선택"
		"passive":
			return "패시브 선택"
		"second_active":
			return "2nd 액티브 선택"
		"second_passive":
			return "2nd 패시브 선택"
	return "스킬 선택"


static func unlock_choice_subtitle(choice_key: String) -> String:
	match choice_key:
		"active":
			return "액티브 후보"
		"passive":
			return "패시브 후보"
		"second_active":
			return "2nd 액티브 후보"
		"second_passive":
			return "2nd 패시브 후보"
	return "후보"
