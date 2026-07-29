extends RefCounted

const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const CharacterInfoOverlayStatsPresenter := preload("res://scripts/hud/character_info_overlay_stats_presenter.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")


static func build_stats(
	snapshot: Dictionary,
	accent_gold: Color,
	text_soft: Color,
	empty_text_color: Color,
	stat_buff_color: Color,
	speed_display_px_per_point: float,
	hatch_required_hits: int,
	defense_rate_tooltip: String,
	row_budget_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(560.0, 360.0))
) -> Array:
	var state := str(snapshot.get("state", "none"))
	if state == "egg":
		var hits := int(snapshot.get("hatch_hits", 0))
		var required_hits := maxi(1, int(snapshot.get("required_hits", hatch_required_hits)))
		return [
			make_display_stat_row("상태", "알", accent_gold),
			make_display_stat_row("부화 진행", CharacterInfoOverlayFormatter.format_int_pair(hits, required_hits), text_soft),
		]
	if state != "companion":
		return [make_display_stat_row("상태", "미획득", empty_text_color)]
	var speed_default := float(snapshot.get("companion_patrol_speed_default", 120.0))
	var speed_min := float(snapshot.get("companion_patrol_speed_min", 70.0))
	var speed_max := float(snapshot.get("companion_patrol_speed_max", 135.0))
	var catch_width := float(snapshot.get("companion_catch_width", 100.0))
	var catch_height := float(snapshot.get("companion_catch_height", 44.0))
	var hit_gain := float(snapshot.get("companion_hit_gauge_gain", 40.0))
	var skill_id := str(snapshot.get("companion_skill_id", "")).strip_edges()
	var skill_name := str(snapshot.get("companion_skill_name", "")).strip_edges()
	if skill_name.is_empty():
		skill_name = "액티브 스킬"
	var active_cooldown := float(snapshot.get("companion_skill_cooldown_duration", 40.0))
	var second_skill_id := str(snapshot.get("companion_skill_id_1", "")).strip_edges()
	var second_skill_name := str(snapshot.get("companion_skill_name_1", "")).strip_edges()
	if second_skill_name.is_empty():
		second_skill_name = "2nd active"
	var second_active_cooldown := float(snapshot.get("companion_skill_cooldown_duration_1", 0.0))
	var defense_rate := float(snapshot.get("companion_defense_rate", 0.0))
	var appearance_rate := float(snapshot.get("companion_appearance_rate", 0.0))
	var speed_display := speed_default / speed_display_px_per_point
	var pet_name := str(snapshot.get("title", "")).strip_edges()
	if pet_name.is_empty():
		pet_name = "수호령"
	var rows := [
		make_display_stat_row("이동 속도", "%.2f" % speed_display, Color.WHITE, LanguageSettings.translate_text("%s이(가) 플레이어 진영에서 독자적으로 순찰할 때 쓰는 기본 이동 속도입니다. 실제 순찰은 %s~%spx/s 사이에서 자연스럽게 변동됩니다.") % [pet_name, CharacterInfoOverlayFormatter.format_plain_number(speed_min), CharacterInfoOverlayFormatter.format_plain_number(speed_max)]),
		make_display_stat_row("몸집크기", "%sx%spx" % [CharacterInfoOverlayFormatter.format_plain_number(catch_width), CharacterInfoOverlayFormatter.format_plain_number(catch_height)], Color.WHITE, LanguageSettings.translate_text("%s이(가) 공을 튕겨낼 때 쓰는 실제 판정 범위입니다.") % pet_name),
		make_display_stat_row("기력 획득량", "%spt" % CharacterInfoOverlayFormatter.format_plain_number(hit_gain), stat_buff_color, "수호령이 공을 직접 튕겼을 때 얻는 공통 기본 기력 획득량입니다."),
	]
	if defense_rate > 0.0:
		rows.append(make_display_stat_row("방어율", CharacterInfoOverlayFormatter.format_percent_text(defense_rate * 100.0), stat_buff_color, defense_rate_tooltip))
	if appearance_rate > 0.0:
		rows.append(make_display_stat_row("출현율", CharacterInfoOverlayFormatter.format_percent_text(appearance_rate * 100.0), stat_buff_color, "사라졌다 다시 나타나기까지의 대기가 짧아지는 정도입니다. 높을수록 더 자주 등장합니다."))
	if not skill_id.is_empty():
		rows.insert(3, make_display_stat_row("액티브 쿨타임", CharacterInfoOverlayFormatter.format_seconds_text(active_cooldown), Color.WHITE, LanguageSettings.translate_text("%s을(를) 다시 사용할 수 있게 되는 시간입니다.") % skill_name))
	if not second_skill_id.is_empty():
		var projected_count := rows.size() + 1
		if row_budget_can_fit(row_budget_rect, projected_count):
			rows.insert(mini(4, rows.size()), make_display_stat_row("2nd 액티브 쿨타임", CharacterInfoOverlayFormatter.format_seconds_text(second_active_cooldown), Color.WHITE, "%s을(를) 다시 사용할 수 있게 되는 시간입니다." % second_skill_name))
	return rows


static func build_stats_cached(
	snapshot: Dictionary,
	cache: Dictionary,
	accent_gold: Color,
	text_soft: Color,
	empty_text_color: Color,
	stat_buff_color: Color,
	speed_display_px_per_point: float,
	hatch_required_hits: int,
	defense_rate_tooltip: String,
	row_budget_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(560.0, 360.0))
) -> Dictionary:
	var cache_hash := hash([
		get_stats_cache_hash(snapshot, hatch_required_hits),
		int(round(row_budget_rect.size.x)),
		int(round(row_budget_rect.size.y)),
	])
	if bool(cache.get("ready", false)) and int(cache.get("hash", 0)) == cache_hash:
		return cache
	return {
		"ready": true,
		"hash": cache_hash,
		"rows": build_stats(snapshot, accent_gold, text_soft, empty_text_color, stat_buff_color, speed_display_px_per_point, hatch_required_hits, defense_rate_tooltip, row_budget_rect).duplicate(true),
	}


static func get_stats_cache_hash(snapshot: Dictionary, hatch_required_hits: int) -> int:
	var state := str(snapshot.get("state", "none"))
	if state == "egg":
		return hash([LanguageSettings.get_language(), state, int(snapshot.get("hatch_hits", 0)), int(snapshot.get("required_hits", hatch_required_hits))])
	if state != "companion":
		return hash([LanguageSettings.get_language(), state])
	return hash([
		LanguageSettings.get_language(),
		state,
		float(snapshot.get("companion_patrol_speed_default", 120.0)),
		float(snapshot.get("companion_patrol_speed_min", 70.0)),
		float(snapshot.get("companion_patrol_speed_max", 135.0)),
		float(snapshot.get("companion_catch_width", 100.0)),
		float(snapshot.get("companion_catch_height", 44.0)),
		float(snapshot.get("companion_hit_gauge_gain", 40.0)),
		str(snapshot.get("companion_skill_id", "")).strip_edges(),
		str(snapshot.get("companion_skill_name", "")).strip_edges(),
		float(snapshot.get("companion_skill_cooldown_duration", 40.0)),
		str(snapshot.get("companion_skill_id_1", "")).strip_edges(),
		str(snapshot.get("companion_skill_name_1", "")).strip_edges(),
		float(snapshot.get("companion_skill_cooldown_duration_1", 0.0)),
		str(snapshot.get("companion_passive_skill_id_1", "")).strip_edges(),
		str(snapshot.get("companion_passive_skill_name_1", "")).strip_edges(),
		float(snapshot.get("companion_defense_rate", 0.0)),
		float(snapshot.get("companion_appearance_rate", 0.0)),
	])


static func row_budget_can_fit(budget_rect: Rect2, projected_row_count: int) -> bool:
	if projected_row_count <= 0 or budget_rect.size.x <= 0.0 or budget_rect.size.y <= 0.0:
		return true
	var lingpet_rect := CharacterInfoOverlayStatsPresenter.lingpet_stat_rect_for_sections(budget_rect)
	return CharacterInfoOverlayStatsPresenter.lingpet_stat_rows_visible_capacity(lingpet_rect, projected_row_count) >= projected_row_count


static func make_display_stat_row(label: String, value_text: String, color: Color, tooltip_body: String = "") -> Dictionary:
	var row := {
		"label": LanguageSettings.translate_text(label),
		"value": LanguageSettings.translate_text(value_text),
		"color": color,
	}
	if not tooltip_body.is_empty():
		row["tooltip_title"] = LanguageSettings.translate_text(label)
		row["tooltip_subtitle"] = LanguageSettings.translate_text(value_text)
		row["tooltip_body"] = LanguageSettings.translate_text(tooltip_body)
	return row
