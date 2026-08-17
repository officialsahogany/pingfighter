extends RefCounted

const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const CharacterInfoOverlayTextureDrawer := preload("res://scripts/hud/character_info_overlay_texture_drawer.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PerkFusionByproductCatalog := preload("res://scripts/characters/perk_fusion_byproduct_catalog.gd")
const RuntimePerkOverflowDescriptions := preload("res://scripts/characters/runtime_perk_overflow_descriptions.gd")

const LEVEL_BADGE_FILL := Color(0.12, 0.075, 0.032, 0.94)
const LEVEL_BADGE_HORIZONTAL_PADDING := 7.0
const LEVEL_BADGE_VERTICAL_PADDING := 2.0
const LEVEL_BADGE_MIN_HEIGHT := 18.0
const LEVEL_BADGE_BOTTOM_OFFSET := 4.0

# Perk tooltip right-panel ("능력치") stat-line color and header. The 2-panel
# perk tooltip mirrors the passive-item dual tooltip: left = friendly `detail`,
# right = the per-level numeric breakdown (`descriptions[level]`) split into lines.
const PERK_STAT_ENTRY_COLOR := Color(0.72, 0.86, 1.0)
const PERK_STAT_HEADER := "능력치"


# Split a per-level stat string ("넉백 +20%, 스턴 +20%, ...") into right-panel
# entry dicts. Returns [] (→ single-panel fallback) when there is nothing
# distinct to show on the right: empty stats, or stats identical to the left-panel
# detail. The identical case is the non-Korean locale collapse — `localize_perk_data`
# rewrites both `detail` and every `descriptions[level]` to the same summary string,
# so a 2-panel split would just duplicate the text.
static func build_perk_stat_entries(stats_text: String, detail_text: String) -> Array:
	# 단일 진입점: 융합/주사위 태그 라인([[fusion:*]]/[[dice:*]] 프리픽스)은
	# 전용 색·취소선 분해기로, 일반 퍽 스탯은 개편 범용 콤마 분해(detail==
	# stats면 단일 패널 붕괴)로 라우팅한다 — 소실 개편 원본과 사후 융합
	# 재구축본의 병합 지점.
	var stats: String = stats_text.strip_edges()
	if stats == "":
		return []
	if _has_tagged_stat_prefix(stats):
		return _build_tagged_stat_entries(stats)
	var detail: String = detail_text.strip_edges()
	if stats == detail:
		return []
	var entries: Array = []
	for piece in stats.split(",", false):
		var text: String = str(piece).strip_edges()
		if text == "":
			continue
		entries.append({"text": text, "color": PERK_STAT_ENTRY_COLOR})
	return entries


static func _has_tagged_stat_prefix(stats: String) -> bool:
	var localization: Object = _fusion_localization()
	var dice_localization: Object = _mystic_dice_localization()
	var prefixes: Array = [
		localization.STAT_HEADER_PREFIX,
		localization.STAT_PENALTY_PREFIX,
		localization.STAT_DELETED_PREFIX,
		localization.STAT_BYPRODUCT_PREFIX,
		localization.STAT_NORMAL_PREFIX,
		dice_localization.STAT_BENEFIT_PREFIX,
		dice_localization.STAT_CURSE_PREFIX,
		dice_localization.STAT_NEUTRAL_PREFIX,
	]
	for raw_line: String in stats.split("
", false):
		for prefix_value: Variant in prefixes:
			if raw_line.begins_with(str(prefix_value)):
				return true
	return false


static func _apply_runtime_status_lines(data: Dictionary, skill_id: String, runtime_state: Object) -> void:
	if runtime_state == null or not runtime_state.has_method("get_runtime_status_lines"):
		return
	var lines_value: Variant = runtime_state.get_runtime_status_lines(skill_id)
	if not (lines_value is Array) or (lines_value as Array).is_empty():
		return
	var lines: Array[String] = []
	for line_value: Variant in lines_value:
		var line := str(line_value).strip_edges()
		if line != "":
			lines.append(line)
	if lines.is_empty():
		return
	data["description"] = "\n".join(lines)
	if str(data.get("detail", "")).strip_edges() == "":
		data["detail"] = lines[0]


static func build_equipped_skill_lookup(equipped_skills: Array) -> Dictionary:
	var result: Dictionary = {}
	for skill_id_value in equipped_skills:
		var skill_id: String = str(skill_id_value)
		if skill_id != "":
			result[skill_id] = true
	return result


static func _fusion_projection_cache_signature(runtime_snapshot_override: Variant) -> int:
	if not (runtime_snapshot_override is Dictionary):
		return 0
	var projection: Dictionary = (runtime_snapshot_override as Dictionary).get("perk_fusion_display_projection", {}) as Dictionary
	if projection.is_empty():
		return 0
	return hash([
		int(projection.get("fusion_revision", 0)),
		int(projection.get("cache_signature", 0)),
	])


static func acquired_perk_cache_hash(levels: Dictionary, catalog: Object, runtime_state: Object = null, runtime_snapshot_override: Variant = null, effective_levels: Dictionary = {}, equipped_skills_for_filter: Array = []) -> int:
	var catalog_id: int = catalog.get_instance_id() if catalog != null else 0
	var equipped_skills_hash: int = hash(equipped_skills_for_filter)
	var language := LanguageSettings.get_language()
	var angel_signature := 0
	if runtime_snapshot_override is Dictionary:
		angel_signature = _angel_blessing_cache_signature(runtime_snapshot_override as Dictionary)
	# 융합 projection 서명: 레벨이 동일해도 fusion revision이 바뀌면(커밋/
	# 복원) TAB 캐시가 반드시 무효화돼야 한다.
	var fusion_signature := _fusion_projection_cache_signature(runtime_snapshot_override)
	var has_snapshot_effective_levels := runtime_snapshot_override is Dictionary and (runtime_snapshot_override as Dictionary).has("effective_runtime_skill_levels")
	if runtime_state != null and not has_snapshot_effective_levels:
		return hash([acquired_perk_runtime_cache_hash(levels, catalog_id, runtime_state, effective_levels, equipped_skills_hash), angel_signature, fusion_signature, language])
	return hash([catalog_id, hash(levels), hash(effective_levels), equipped_skills_hash, angel_signature, fusion_signature, language])


static func _angel_blessing_cache_signature(runtime_snapshot: Dictionary) -> int:
	var roll_value: Variant = runtime_snapshot.get("angel_blessing", {})
	var acquisition_value: Variant = runtime_snapshot.get("angel_blessing_acquisition", {})
	var roll_snapshot: Dictionary = roll_value if roll_value is Dictionary else {}
	var acquisition_snapshot: Dictionary = acquisition_value if acquisition_value is Dictionary else {}
	return hash([
		int(roll_snapshot.get("revision", 0)),
		int(roll_snapshot.get("active_stage", 0)),
		hash(roll_snapshot.get("active_buff_ids", [])),
		hash(acquisition_snapshot.get("pending_rolls", [])),
	])


static func acquired_perk_runtime_cache_hash(levels: Dictionary, catalog_id: int, runtime_state: Object, effective_levels: Dictionary, equipped_skills_hash: int) -> int:
	var result: int = hash(catalog_id)
	result = hash([result, equipped_skills_hash])
	for skill_id_value in levels:
		var skill_id: String = str(skill_id_value)
		var base_level: int = int(levels.get(skill_id_value, 0))
		if base_level <= 0:
			continue
		var effective_level: int = effective_runtime_perk_level(runtime_state, skill_id, base_level, effective_levels)
		result = hash([result, skill_id, base_level, effective_level])
	return result


static func should_hide_equipped_unlock_perk(perk_data: Dictionary, equipped_skill_lookup: Dictionary) -> bool:
	if equipped_skill_lookup.is_empty():
		return false
	var unlocked_skill: String = str(perk_data.get("unlocks_skill", ""))
	return unlocked_skill != "" and bool(equipped_skill_lookup.get(unlocked_skill, false))


# 융합 재료 헤더 전용 색(스탯 패널에서 재료 섹션을 시각 구분).
const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")

const FUSION_STAT_HEADER_COLOR := Color(1.0, 0.84, 0.42, 1.0)
const FUSION_STAT_PENALTY_COLOR := Color(1.0, 0.55, 0.45, 1.0)
const FUSION_STAT_DELETED_COLOR := Color(0.62, 0.62, 0.66, 1.0)
const FUSION_STAT_BYPRODUCT_COLOR := Color(0.55, 0.85, 1.0, 1.0)
const FUSION_ENTRY_DRAW_COLOR := Color(0.72, 0.46, 0.98, 1.0)

# 팔자윷 스탯 행 색: 표시는 raw 부호가 아니라 "이득/손해"(benefit)
# 기준 — LIB(낮을수록 이득) 3종은 raw 부호가 반전돼 색이 뒤집힌다.
const MYSTIC_DICE_STAT_BENEFIT_COLOR := Color(0.14, 0.52, 0.82, 1.0)
const MYSTIC_DICE_STAT_CURSE_COLOR := Color(0.88, 0.20, 0.18, 1.0)
const MYSTIC_DICE_STAT_NEUTRAL_COLOR := Color(0.70, 0.65, 0.56, 1.0)
const MYSTIC_DICE_ENTRY_DRAW_COLOR := Color(0.78, 0.56, 0.24, 1.0)


static func _mystic_dice_localization() -> Object:
	return load("res://scripts/characters/mystic_dice_localization.gd")


static func _fusion_localization() -> Object:
	return load("res://scripts/characters/perk_fusion_localization.gd")


static func _fusion_icon_key() -> Object:
	return load("res://scripts/characters/perk_fusion_icon_key.gd")


# 융합 projection 엔트리 → TAB 표시 엔트리(접착). fusion 셀은 결과 로그
# (detail, ≤3줄)와 재료 스탯(description, 프리픽스 태그 포함 raw)을 분리
# 유지하고, 아이콘은 재료쌍 합성 키(_draw_id)로 라우팅한다. live_source_
# options가 있으면 스탯 패널의 before/after가 라이브 값(central getter
# 일치)으로 대체된다 — 커밋 record 자체는 불변.
static func build_acquired_perks_from_projection(
	projection_entries: Array,
	catalog: Object,
	effective_levels: Dictionary,
	accent_blue: Color,
	accent_gold: Color,
	runtime_state: Object = null,
	equipped_skill_lookup: Dictionary = {}
) -> Array:
	var result: Array = []
	var common_unlock_entries: Dictionary = {}
	for projection_value: Variant in projection_entries:
		if projection_value is Dictionary:
			var projection_id := str((projection_value as Dictionary).get("perk_id", (projection_value as Dictionary).get("id", "")))
			if CommonSkillCatalog.is_common_unlock(projection_id):
				common_unlock_entries[projection_id] = true
	for entry_value: Variant in projection_entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value as Dictionary
		if str(entry.get("type", "perk")) == "fusion":
			var fusion_data: Dictionary = _fusion_display_entry(entry, catalog, accent_gold, runtime_state)
			if not fusion_data.is_empty():
				result.append(fusion_data)
			continue
		if str(entry.get("type", "perk")) == "mystic_dice":
			var dice_data: Dictionary = _mystic_dice_display_entry(entry, accent_gold)
			if not dice_data.is_empty():
				result.append(dice_data)
			continue
		var perk_id := str(entry.get("perk_id", entry.get("id", "")))
		var base_level := int(entry.get("base_level", 0))
		if perk_id.is_empty() or base_level <= 0:
			continue
		var common_unlock_id := CommonSkillCatalog.get_unlock_id_for_skill(perk_id)
		if common_unlock_id != "" and bool(common_unlock_entries.get(common_unlock_id, false)):
			continue
		var level := int(entry.get("effective_level", int(effective_levels.get(perk_id, base_level))))
		# 장착 해금퍽 숨김은 acquired_perk_data의 lookup 인자를 그대로 관통
		# — 빈 {} 고정이면 projection 상시인 라이브에서 필터가 죽는다.
		var data: Dictionary = acquired_perk_data(perk_id, base_level, level, catalog, equipped_skill_lookup, accent_blue)
		if data.is_empty():
			continue
		_apply_polish_stats_text(data, perk_id, level, runtime_state)
		var draw_id := common_unlock_id if common_unlock_id != "" else perk_id
		_decorate_presented_perk(data, draw_id, accent_blue, accent_gold)
		# 런타임 상태 라인(천사의 주사위 등)은 일반 분기와 동일하게 여기서도
		# 적용한다 — projection 분기 추출 때 탈락해 씰(angel_blessing_status_
		# tooltip_smoke)이 조용히 RED로 남았던 자리(2026-07-21 복원).
		_apply_runtime_status_lines(data, perk_id, runtime_state)
		# 대쉬토큰류 slot_cost>1 퍽은 projection 경유에서도 슬롯 셀 N개로
		# 확장해야 한다 — 그리드 셀 수와 슬롯 카운터가 같은 수를 읽는 계약.
		append_presented_perk_with_slot_cells(result, data, slot_cost_for_level(catalog, data, base_level))
	return result


static func _decorate_presented_perk(data: Dictionary, draw_id: String, accent_blue: Color, accent_gold: Color) -> void:
	data["_draw_id"] = draw_id
	var draw_color: Color = CharacterInfoOverlayValueUtils.get_color(data.get("icon_color", accent_blue))
	data["_draw_color"] = draw_color
	data["_draw_border_color"] = Color(draw_color.r, draw_color.g, draw_color.b, 0.48)
	data["_draw_hover_border_color"] = Color(draw_color.r, draw_color.g, draw_color.b, 0.92)
	data["_level_text"] = CharacterInfoOverlayFormatter.perk_level_text(data)
	data["_level_color"] = CharacterInfoOverlayFormatter.perk_level_color(data, accent_gold)


static func _fusion_display_entry(
	entry: Dictionary,
	catalog: Object,
	accent_gold: Color,
	runtime_state: Object = null
) -> Dictionary:
	var localization: Object = _fusion_localization()
	var fusion_id := str(entry.get("fusion_id", entry.get("id", "")))
	if fusion_id.is_empty():
		return {}
	var sources: Array = entry.get("sources", []) as Array
	var source_names: Array = entry.get("source_names", []) as Array
	var source_labels: Dictionary = {}
	for source_index in range(sources.size()):
		var source_id := str(sources[source_index])
		source_labels[source_id] = str(source_names[source_index]) if source_index < source_names.size() else source_id
	var record: Dictionary = (entry.get("record_payload", {}) as Dictionary).duplicate(true)
	# 라이브 hover: 스탯 패널의 before/after는 성장한 유효레벨 기준 라이브
	# 값을 쓴다(record 원본은 불변 커밋 로그 — 사본에만 주입).
	var live_options: Dictionary = entry.get("live_source_options", {}) as Dictionary
	if not live_options.is_empty():
		var merged_options: Dictionary = (record.get("source_options", {}) as Dictionary).duplicate(true)
		for live_perk_value: Variant in live_options.keys():
			merged_options[str(live_perk_value)] = (live_options.get(live_perk_value, {}) as Dictionary).duplicate(true)
		record["source_options"] = merged_options
	var detail_lines: Array = localization.result_log_lines(record, source_labels)
	var stat_lines: Array = localization.tooltip_stat_lines(
		record,
		source_labels,
		entry.get("base_levels", {}) as Dictionary,
		entry.get("effective_levels", {}) as Dictionary
	)
	var fusion_draw_id: String = str(_fusion_icon_key().build(
		fusion_id,
		int(entry.get("fusion_revision", 0)),
		sources
	))
	var data: Dictionary = {
		"id": fusion_id,
		"name": str(entry.get("summary", fusion_id)),
		"tree": "fusion",
		"level": 1,
		"base_level": 1,
		"max_level": 1,
		"slot_cost": int(entry.get("slot_cost", 1)),
		"detail": "\n".join(detail_lines),
		"description": "\n".join(stat_lines),
		"icon_color": FUSION_ENTRY_DRAW_COLOR,
	}
	var fusion_sections: Array = _build_fusion_detail_sections(
		entry,
		record,
		source_labels,
		catalog,
		runtime_state,
		fusion_draw_id
	)
	if fusion_sections.size() == 3:
		data["fusion_sections"] = fusion_sections
	data["_draw_id"] = fusion_draw_id
	data["_draw_color"] = FUSION_ENTRY_DRAW_COLOR
	data["_draw_border_color"] = Color(FUSION_ENTRY_DRAW_COLOR.r, FUSION_ENTRY_DRAW_COLOR.g, FUSION_ENTRY_DRAW_COLOR.b, 0.48)
	data["_draw_hover_border_color"] = Color(FUSION_ENTRY_DRAW_COLOR.r, FUSION_ENTRY_DRAW_COLOR.g, FUSION_ENTRY_DRAW_COLOR.b, 0.92)
	data["_level_text"] = str(localization.text("level_fusion"))
	data["_level_color"] = accent_gold
	return data


# 합일 hover의 정본 3칸: 원본 무공 A, 원본 무공 B, 부작용/부산물 결과.
# 첫 두 칸은 일반 무공 tooltip과 같은 catalog/effective-level 해석기를
# 통과한다. 합일 전용 option key를 다시 설명문처럼 조립하지 않는다.
static func _build_fusion_detail_sections(
	entry: Dictionary,
	record: Dictionary,
	source_labels: Dictionary,
	catalog: Object,
	runtime_state: Object,
	fusion_draw_id: String
) -> Array:
	if catalog == null or not catalog.has_method("get_perk_data"):
		return []
	var sources: Array = entry.get("sources", []) as Array
	if sources.size() != 2:
		return []
	var localization: Object = _fusion_localization()
	var base_levels: Dictionary = entry.get("base_levels", {}) as Dictionary
	var effective_levels: Dictionary = entry.get("effective_levels", {}) as Dictionary
	var sections: Array = []
	for source_index in range(2):
		var source_id := str(sources[source_index])
		var catalog_data_value: Variant = catalog.get_perk_data(source_id)
		if not (catalog_data_value is Dictionary) or (catalog_data_value as Dictionary).is_empty():
			return []
		var base_level := int(base_levels.get(source_id, 0))
		var effective_level := int(effective_levels.get(source_id, base_level))
		var source_data := acquired_perk_data(
			source_id,
			base_level,
			effective_level,
			catalog,
			{},
			Color.WHITE
		)
		_apply_polish_stats_text(source_data, source_id, effective_level, runtime_state)
		_apply_runtime_status_lines(source_data, source_id, runtime_state)
		sections.append({
			"kind": "source",
			"source_id": source_id,
			"eyebrow": str(localization.text("material_a" if source_index == 0 else "material_b")),
			"icon_id": source_id,
			"title": str(source_data.get("name", source_labels.get(source_id, source_id))),
			"subtitle": CharacterInfoOverlayFormatter.perk_level_text(source_data),
			"body": str(source_data.get("detail", "")),
			"stats": str(source_data.get("description", "")),
			"rows": _build_source_fusion_change_rows(
				source_id,
				record,
				source_labels,
				base_level,
				effective_level
			),
		})
	sections.append(_build_fusion_outcome_section(record, source_labels, fusion_draw_id))
	return sections


static func _build_source_fusion_change_rows(
	source_id: String,
	record: Dictionary,
	source_labels: Dictionary,
	base_level: int,
	effective_level: int
) -> Array:
	var localization: Object = _fusion_localization()
	var source_record: Dictionary = record.duplicate(true)
	source_record["sources"] = [source_id]
	source_record["source_options"] = _dictionary_subset(record.get("source_options", {}), source_id)
	source_record["option_penalties"] = _dictionary_subset(record.get("option_penalties", {}), source_id)
	source_record["deleted_options"] = _dictionary_subset(record.get("deleted_options", {}), source_id)
	source_record["byproducts"] = []
	source_record["byproduct_payloads"] = {}
	var tagged_lines: Array = localization.tooltip_stat_lines(
		source_record,
		source_labels,
		{source_id: base_level},
		{source_id: effective_level}
	)
	var rows: Array = []
	for line_value: Variant in tagged_lines:
		var line := str(line_value)
		if line.begins_with(localization.STAT_PENALTY_PREFIX):
			rows.append({
				"text": line.trim_prefix(localization.STAT_PENALTY_PREFIX),
				"tone": "penalty",
			})
		elif line.begins_with(localization.STAT_DELETED_PREFIX):
			rows.append({
				"text": line.trim_prefix(localization.STAT_DELETED_PREFIX),
				"tone": "deleted",
				"strikethrough": true,
			})
	return rows


static func _dictionary_subset(value: Variant, key: String) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var dictionary: Dictionary = value as Dictionary
	if not dictionary.has(key):
		return {}
	var child: Variant = dictionary.get(key)
	return {key: child.duplicate(true) if child is Dictionary or child is Array else child}


static func _build_fusion_outcome_section(
	record: Dictionary,
	source_labels: Dictionary,
	fusion_draw_id: String
) -> Dictionary:
	var localization: Object = _fusion_localization()
	var outcome := str(record.get("outcome", "success"))
	var byproducts: Array = record.get("byproducts", []) as Array
	var payloads: Dictionary = record.get("byproduct_payloads", {}) as Dictionary
	var changed_count := _nested_fusion_record_count(record.get("option_penalties", {}))
	var deleted_count := _deleted_fusion_record_count(record.get("deleted_options", {}))
	var title_key := "outcome_complete"
	var body_key := "result_success"
	match outcome:
		"stable":
			title_key = "outcome_stable"
			body_key = "result_stable"
		"side_effect":
			title_key = "outcome_side"
			body_key = "result_side"
		"byproduct":
			title_key = "outcome_byproduct"
			body_key = "result_byproduct"
	var rows: Array = []
	if changed_count > 0 or deleted_count > 0:
		rows.append({
			"text": str(localization.format("result_change_summary", [changed_count, deleted_count])),
			"tone": "penalty",
		})
	for byproduct_value: Variant in byproducts:
		var byproduct_id := str(byproduct_value.get("id", "")) if byproduct_value is Dictionary else str(byproduct_value)
		if byproduct_id.is_empty():
			continue
		var detail := str(localization.byproduct_detail(
			byproduct_id,
			payloads.get(byproduct_id, {}) as Dictionary,
			source_labels
		))
		var row_text := str(localization.byproduct_name(byproduct_id))
		if not detail.is_empty():
			row_text += " — " + detail
		rows.append({
			"text": row_text,
			"tone": "byproduct",
			"icon_id": byproduct_id,
		})
	var eyebrow_key := "outcome_complete"
	if not byproducts.is_empty():
		eyebrow_key = "prob_byproduct"
	elif outcome == "side_effect" or changed_count > 0 or deleted_count > 0:
		eyebrow_key = "prob_side"
	var outcome_icon_id := fusion_draw_id
	if byproducts.size() == 1:
		var only_byproduct: Variant = byproducts[0]
		outcome_icon_id = str(only_byproduct.get("id", "")) if only_byproduct is Dictionary else str(only_byproduct)
	return {
		"kind": "outcome",
		"eyebrow": str(localization.text(eyebrow_key)),
		"icon_id": outcome_icon_id,
		"title": str(localization.text(title_key)),
		"subtitle": "",
		"body": str(localization.text(body_key)),
		"stats": "",
		"rows": rows,
	}


static func _nested_fusion_record_count(value: Variant) -> int:
	if not (value is Dictionary):
		return 0
	var count := 0
	for child_value: Variant in (value as Dictionary).values():
		if child_value is Dictionary:
			count += (child_value as Dictionary).size()
	return count


static func _deleted_fusion_record_count(value: Variant) -> int:
	if not (value is Dictionary):
		return 0
	var count := 0
	for child_value: Variant in (value as Dictionary).values():
		if child_value is Array:
			count += (child_value as Array).size()
	return count


# 팔자윷 호환 projection 엔트리 → TAB 표시 엔트리(접착). 슬롯 비소모
# 셀(_slot_free_cell) 하나로 접히고, detail=플레이버, description=7행
# 태그 스탯([[dice:*]] — benefit 부호 기준 색)으로 분리 유지한다.
static func _mystic_dice_display_entry(entry: Dictionary, accent_gold: Color) -> Dictionary:
	var localization: Object = _mystic_dice_localization()
	var roller: Object = load("res://scripts/characters/mystic_dice_roller.gd")
	var permanent_raw: Dictionary = entry.get("permanent_raw", {}) as Dictionary
	var stat_lines: Array[String] = []
	for stat_key: String in roller.STAT_KEYS:
		var raw_value: int = int(permanent_raw.get(stat_key, 0))
		var benefit: int = -raw_value if stat_key in roller.LOWER_IS_BETTER_STAT_KEYS else raw_value
		var prefix: String = localization.STAT_NEUTRAL_PREFIX
		if benefit > 0:
			prefix = localization.STAT_BENEFIT_PREFIX
		elif benefit < 0:
			prefix = localization.STAT_CURSE_PREFIX
		var value_text := "%+d%%" % raw_value if raw_value != 0 else "0%"
		stat_lines.append("%s%s %s" % [prefix, str(localization.text(stat_key)), value_text])
	var card: Dictionary = load("res://scripts/characters/mystic_dice_offer_planner.gd").build_card()
	var data: Dictionary = {
		"id": "mystic_dice",
		"name": str(card.get("name", "팔자윷")),
		"tree": "mystic_dice",
		"level": 1,
		"base_level": 1,
		"max_level": 1,
		"slot_cost": 0,
		"_slot_free_cell": true,
		"use_count": int(entry.get("use_count", 0)),
		"detail": str(card.get("detail", card.get("description", ""))),
		"description": "\n".join(stat_lines),
		"icon_color": MYSTIC_DICE_ENTRY_DRAW_COLOR,
	}
	data["_draw_id"] = "mystic_dice"
	data["_draw_color"] = MYSTIC_DICE_ENTRY_DRAW_COLOR
	data["_draw_border_color"] = Color(MYSTIC_DICE_ENTRY_DRAW_COLOR.r, MYSTIC_DICE_ENTRY_DRAW_COLOR.g, MYSTIC_DICE_ENTRY_DRAW_COLOR.b, 0.48)
	data["_draw_hover_border_color"] = Color(MYSTIC_DICE_ENTRY_DRAW_COLOR.r, MYSTIC_DICE_ENTRY_DRAW_COLOR.g, MYSTIC_DICE_ENTRY_DRAW_COLOR.b, 0.92)
	data["_level_text"] = str(localization.text("badge"))
	data["_level_color"] = accent_gold
	return data


# fusion 셀의 hover 본문 팩킹 구분자: hover_body_cache는 String 배열이라
# 구조를 실을 수 없다 — detail(결과 로그, 좌패널)과 description(태그 스탯,
# 우패널 분해용)을 제어문자 1개로 팩킹해 드로우 시점에 분해한다.
const FUSION_HOVER_SPLIT := ""
const FUSION_SECTION_SPLIT := ""


static func pack_fusion_hover_body(
	detail: String,
	tagged_stats: String,
	fusion_sections: Array = []
) -> String:
	var packed := detail + FUSION_HOVER_SPLIT + tagged_stats
	if not fusion_sections.is_empty():
		packed += FUSION_SECTION_SPLIT + JSON.stringify(fusion_sections)
	return packed


# fusion hover 실경로 payload: 팩킹된 hover 본문 → 좌패널 body(결과 로그)+
# 우패널 roll_options(색·취소선 메타 엔트리). 비-fusion 본문이면 {} —
# 호출부는 기존 단일 툴팁 경로를 유지한다. [[fusion:*]] 태그가 hover에
# 원문 노출되는 것을 막는 소유 분해 지점.
static func build_fusion_hover_payload(packed_body: String) -> Dictionary:
	var split_at: int = packed_body.find(FUSION_HOVER_SPLIT)
	if split_at < 0:
		return {}
	var detail_text := packed_body.substr(0, split_at)
	var tagged_stats := packed_body.substr(split_at + FUSION_HOVER_SPLIT.length())
	var fusion_sections: Array = []
	var section_split_at := tagged_stats.find(FUSION_SECTION_SPLIT)
	if section_split_at >= 0:
		var section_json := tagged_stats.substr(section_split_at + FUSION_SECTION_SPLIT.length())
		tagged_stats = tagged_stats.substr(0, section_split_at)
		var parsed_sections: Variant = JSON.parse_string(section_json)
		if parsed_sections is Array:
			fusion_sections = parsed_sections as Array
	var entries: Array = build_perk_stat_entries(tagged_stats, "")
	if entries.is_empty() and fusion_sections.is_empty():
		return {}
	if detail_text.strip_edges().is_empty():
		detail_text = str((entries[0] as Dictionary).get("text", " ")) if not entries.is_empty() else " "
	# 행 예산 프로파일은 태그 출처가 결정한다: [[dice:*]] 스탯이면 주사위
	# 전용(14행), 아니면 융합(24행).
	var tooltip_kind := "mystic_dice" if tagged_stats.contains("[[dice:") else "fusion"
	var payload := {
		"body": detail_text,
		"roll_options": entries,
		"tooltip_kind": tooltip_kind,
	}
	if fusion_sections.size() == 3:
		payload["fusion_sections"] = fusion_sections
	return payload


# 융합 스탯 문자열([[fusion:*]] 프리픽스 라인) → 렌더 엔트리 분해. 삭제
# 흉터는 U+0336 결합 글리프 대신 렌더러 소유 strikethrough 메타로 표기한다
# (한국어 폰트 스택에 결합 취소선 글리프가 없어 tofu가 된다).
static func _build_tagged_stat_entries(stats: String) -> Array:
	var localization: Object = _fusion_localization()
	var dice_localization: Object = _mystic_dice_localization()
	var entries: Array = []
	for raw_line: String in stats.split("\n", false):
		var line := raw_line
		var color: Color = Color.WHITE
		var strikethrough := false
		var icon_id := ""
		if line.begins_with(localization.STAT_HEADER_PREFIX):
			line = line.trim_prefix(localization.STAT_HEADER_PREFIX)
			color = FUSION_STAT_HEADER_COLOR
		elif line.begins_with(localization.STAT_PENALTY_PREFIX):
			line = line.trim_prefix(localization.STAT_PENALTY_PREFIX)
			color = FUSION_STAT_PENALTY_COLOR
		elif line.begins_with(localization.STAT_DELETED_PREFIX):
			line = line.trim_prefix(localization.STAT_DELETED_PREFIX)
			color = FUSION_STAT_DELETED_COLOR
			strikethrough = true
		elif line.begins_with(localization.STAT_BYPRODUCT_PREFIX):
			line = line.trim_prefix(localization.STAT_BYPRODUCT_PREFIX)
			color = FUSION_STAT_BYPRODUCT_COLOR
			icon_id = _byproduct_icon_id_for_line(line, localization)
		elif line.begins_with(dice_localization.STAT_BENEFIT_PREFIX):
			line = line.trim_prefix(dice_localization.STAT_BENEFIT_PREFIX)
			color = MYSTIC_DICE_STAT_BENEFIT_COLOR
		elif line.begins_with(dice_localization.STAT_CURSE_PREFIX):
			line = line.trim_prefix(dice_localization.STAT_CURSE_PREFIX)
			color = MYSTIC_DICE_STAT_CURSE_COLOR
		elif line.begins_with(dice_localization.STAT_NEUTRAL_PREFIX):
			line = line.trim_prefix(dice_localization.STAT_NEUTRAL_PREFIX)
			color = MYSTIC_DICE_STAT_NEUTRAL_COLOR
		elif line.begins_with(localization.STAT_NORMAL_PREFIX):
			line = line.trim_prefix(localization.STAT_NORMAL_PREFIX)
		if line.strip_edges().is_empty():
			continue
		var entry := {
			"text": line,
			"color": color,
			"strikethrough": strikethrough,
		}
		if not icon_id.is_empty():
			entry["icon_id"] = icon_id
		entries.append(entry)
	return entries


# 로컬라이즈된 부산물 행을 실제 카탈로그 id로 되돌린다. 표시 문자열에 별도
# 마커를 섞지 않아 툴팁 원문/번역 계약은 보존하면서 아이콘 메타만 붙인다.
static func _byproduct_icon_id_for_line(line: String, localization: Object) -> String:
	for byproduct_id_value: Variant in PerkFusionByproductCatalog.DATA.keys():
		var byproduct_id := str(byproduct_id_value)
		var localized_name := str(localization.byproduct_name(byproduct_id))
		if line == localized_name or line.begins_with(localized_name + " —"):
			return byproduct_id
	return ""


static func acquired_perk_data(
	skill_id: String,
	base_level: int,
	level: int,
	catalog: Object,
	equipped_skill_lookup: Dictionary,
	accent_blue: Color
) -> Dictionary:
	var data: Dictionary = {}
	if catalog != null and catalog.has_method("get_perk_data"):
		data = catalog.get_perk_data(skill_id)
	if data.is_empty() and CommonSkillCatalog.is_common_skill(skill_id):
		data = CommonSkillCatalog.get_unlock_perk_data(CommonSkillCatalog.get_unlock_id_for_skill(skill_id))
	if data.is_empty():
		data = {"name": skill_id, "icon_color": accent_blue, "tree": ""}
	elif should_hide_equipped_unlock_perk(data, equipped_skill_lookup):
		return {}
	data = data.duplicate(true)
	data["id"] = skill_id
	data["base_level"] = base_level
	data["level"] = level
	if not data.has("description"):
		var descriptions: Dictionary = CharacterInfoOverlayValueUtils.get_dict(data.get("descriptions", {}))
		# Effective level (transcendent_crown / sage_ring +N) can exceed the max
		# defined description level. resolve_stats_text generates the Lv.6+ stat
		# line from the runtime scaling patterns (Korean), and falls back to the
		# HIGHEST defined level's stats otherwise — never straight to the detail,
		# which collapsed the "능력치" panel (2026-07-09 bug). Showing the stale
		# Lv.5 text at Lv.7 was the follow-up bug (2026-07-10).
		var description: String = RuntimePerkOverflowDescriptions.resolve_stats_text(skill_id, descriptions, level)
		if description == "":
			description = str(data.get("detail", ""))
		data["description"] = description
	return data


static func _apply_polish_stats_text(data: Dictionary, skill_id: String, level: int, runtime_state: Object) -> void:
	var stats_text: String = RuntimePerkOverflowDescriptions.append_polish_delta(
		str(data.get("description", "")),
		skill_id,
		level,
		runtime_state
	)
	data["description"] = RuntimePerkOverflowDescriptions.append_polish_status(
		stats_text,
		skill_id,
		runtime_state
	)


static func build_acquired_perks(levels: Dictionary, catalog: Object, runtime_state: Object = null, runtime_snapshot_override: Variant = null, effective_levels_override: Dictionary = {}, equipped_skills_for_filter: Array = [], accent_blue: Color = Color.WHITE, accent_gold: Color = Color.WHITE) -> Array:
	var result: Array = []
	var effective_levels: Dictionary = effective_levels_override if not effective_levels_override.is_empty() else effective_runtime_perk_levels_from_snapshot(runtime_snapshot_override)
	# 장착 해금퍽 숨김 lookup은 projection 분기보다 먼저 만든다 — 라이브는
	# 항상 projection 분기라, 일반 분기에서만 만들면 장착된 액티브 스킬의
	# 해금퍽 카드가 실전 TAB에 다시 노출된다(2026-07-21 P2).
	var equipped_skill_lookup: Dictionary = build_equipped_skill_lookup(equipped_skills_for_filter)
	# 융합 projection이 스냅샷에 실려 오면 그 접힘(fold)이 정본이다 — 융합된
	# 소스 퍽은 개별 셀로 다시 그리지 않고 합성 fusion 셀 하나로 표시한다.
	if runtime_snapshot_override is Dictionary:
		var fusion_projection: Dictionary = (runtime_snapshot_override as Dictionary).get("perk_fusion_display_projection", {}) as Dictionary
		var projection_entries: Array = fusion_projection.get("entries", []) as Array
		if not projection_entries.is_empty():
			var projected: Array = build_acquired_perks_from_projection(
				projection_entries,
				catalog,
				effective_levels,
				accent_blue,
				accent_gold,
				runtime_state,
				equipped_skill_lookup
			)
			projected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return sort_perks(a, b)
			)
			return projected
	for skill_id_value in levels:
		var skill_id: String = str(skill_id_value)
		var base_level: int = int(levels.get(skill_id_value, 0))
		if base_level <= 0:
			continue
		var common_unlock_id := CommonSkillCatalog.get_unlock_id_for_skill(skill_id)
		if common_unlock_id != "" and int(levels.get(common_unlock_id, 0)) > 0:
			continue
		var level: int = effective_runtime_perk_level(runtime_state, skill_id, base_level, effective_levels)
		var data: Dictionary = acquired_perk_data(skill_id, base_level, level, catalog, equipped_skill_lookup, accent_blue)
		if data.is_empty():
			continue
		_apply_polish_stats_text(data, skill_id, level, runtime_state)
		data["_draw_id"] = skill_id
		if common_unlock_id != "":
			data["_draw_id"] = common_unlock_id
		var draw_color: Color = CharacterInfoOverlayValueUtils.get_color(data.get("icon_color", accent_blue))
		data["_draw_color"] = draw_color
		data["_draw_border_color"] = Color(draw_color.r, draw_color.g, draw_color.b, 0.48)
		data["_draw_hover_border_color"] = Color(draw_color.r, draw_color.g, draw_color.b, 0.92)
		data["_level_text"] = CharacterInfoOverlayFormatter.perk_level_text(data)
		data["_level_color"] = CharacterInfoOverlayFormatter.perk_level_color(data, accent_gold)
		_apply_runtime_status_lines(data, skill_id, runtime_state)
		append_presented_perk_with_slot_cells(result, data, slot_cost_for_level(catalog, data, base_level))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return sort_perks(a, b)
	)
	return result


static func slot_cost_for_level(catalog: Object, perk_data: Dictionary, base_level: int) -> int:
	if catalog != null and catalog.has_method("get_slot_cost_for_level"):
		return max(0, int(catalog.get_slot_cost_for_level(perk_data, base_level)))
	return 1


# 슬롯 비용 표시 확장의 단일 소스 — 일반(레벨 dict) 분기와 융합 projection
# 분기가 반드시 같은 헬퍼를 지나야 한다. projection 분기가 자체 append를
# 유지하면 라이브(스냅샷은 항상 projection을 실음)에서만 대쉬토큰 Lv.N이
# 슬롯 셀 N개 대신 배지 셀 1개로 붕괴한다(2026-07-21 리포트).
static func append_presented_perk_with_slot_cells(result: Array, data: Dictionary, slot_cost: int) -> void:
	data["_slot_cost"] = slot_cost
	if slot_cost > 1:
		for cell_index in range(slot_cost):
			var cell_data: Dictionary = data.duplicate(true)
			cell_data["_is_slot_cell"] = true
			cell_data["_slot_cell_index"] = cell_index
			cell_data["_slot_cell_total"] = slot_cost
			# 일반 다중 점유 셀은 개수가 곧 수량이라 명패를 생략한다. 다만
			# 카운트형 고유 무공은 내부 level을 성급으로 오해하지 않도록 분류
			# 태그를 각 셀에 유지한다.
			if str(cell_data.get("rank_tag", "")).strip_edges() == "":
				cell_data["_level_text"] = ""
			result.append(cell_data)
		return
	if slot_cost <= 0:
		data["_slot_free_cell"] = true
	result.append(data)


static func build_slot_grid_entries(acquired: Array, slot_count: int) -> Array:
	var result: Array = []
	var free_entries: Array = []
	for entry_value in acquired:
		var entry: Dictionary = entry_value if entry_value is Dictionary else {}
		if entry.is_empty():
			continue
		if bool(entry.get("_slot_free_cell", false)):
			free_entries.append(entry)
		else:
			result.append(entry)
	while result.size() < slot_count:
		result.append({
			"_empty_slot": true,
			"_draw_id": "",
			"_draw_color": Color(0.34, 0.42, 0.52, 0.46),
			"_draw_border_color": Color(0.34, 0.42, 0.52, 0.32),
			"_draw_hover_border_color": Color(0.34, 0.42, 0.52, 0.32),
			"_level_text": "",
			"_level_color": Color.TRANSPARENT,
			"name": "",
			"description": "",
		})
	result.append_array(free_entries)
	return result


static func build_overlay_acquired_perks_cached(
	target: Object,
	levels: Dictionary,
	catalog: Object,
	runtime_state: Object,
	runtime_snapshot_override: Variant,
	equipped_skills_for_filter: Array,
	current_cache_hash: int,
	cache_ready: bool,
	cached_perks: Array,
	draw_id_cache: Array[String],
	draw_color_cache: Array[Color],
	border_color_cache: Array[Color],
	hover_border_color_cache: Array[Color],
	level_text_cache: Array[String],
	level_color_cache: Array[Color],
	hover_title_cache: Array[String],
	hover_body_cache: Array[String],
	hover_detail_cache: Array[String],
	accent_blue: Color,
	accent_gold: Color
) -> Array:
	var effective_levels: Dictionary = effective_runtime_perk_levels_from_snapshot(runtime_snapshot_override)
	var cache_hash: int = acquired_perk_cache_hash(levels, catalog, runtime_state, runtime_snapshot_override, effective_levels, equipped_skills_for_filter)
	if cache_ready and cache_hash == current_cache_hash:
		return cached_perks
	var acquired: Array = build_acquired_perks(levels, catalog, runtime_state, runtime_snapshot_override, effective_levels, equipped_skills_for_filter, accent_blue, accent_gold)
	refresh_draw_arrays(acquired, draw_id_cache, draw_color_cache, border_color_cache, hover_border_color_cache, level_text_cache, level_color_cache, hover_title_cache, hover_body_cache, hover_detail_cache, accent_blue, Callable(CharacterInfoOverlayFormatter, "perk_level_text"), Callable(CharacterInfoOverlayFormatter, "perk_level_color").bind(accent_gold))
	target.set("_acquired_perk_cache_hash", cache_hash)
	target.set("_acquired_perk_cache_ready", true)
	target.set("_acquired_perk_cache", acquired)
	return acquired


static func catalog_prewarm_entries(catalog: Object, character_type: String) -> Array:
	if catalog == null:
		return []
	if catalog.has_method("get_debug_perk_entries"):
		var debug_entries: Variant = catalog.get_debug_perk_entries(character_type)
		return debug_entries if debug_entries is Array else []
	if not catalog.has_method("get_all_perk_data"):
		return []
	var all_data_value: Variant = catalog.get_all_perk_data()
	if not (all_data_value is Dictionary):
		return []
	var all_data: Dictionary = all_data_value
	var entries: Array = []
	for skill_id_value in all_data.keys():
		var raw_entry: Variant = all_data[skill_id_value]
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry.duplicate(true)
		entry["id"] = str(skill_id_value)
		entries.append(entry)
	return entries


static func prewarm_runtime_perk_text(
	font: Font,
	catalog: Object,
	character_type: String,
	runtime_state: Object,
	text_size_callable: Callable,
	trim_label_callable: Callable,
	prewarm_text_block_callable: Callable
) -> bool:
	var entries: Array = build_runtime_perk_text_prewarm_entries(catalog, character_type, runtime_state)
	if catalog == null:
		return false
	prewarm_runtime_perk_text_entries_step(
		font,
		entries,
		0,
		entries.size(),
		text_size_callable,
		trim_label_callable,
		prewarm_text_block_callable
	)
	return true


static func build_runtime_perk_text_prewarm_entries(
	catalog: Object,
	character_type: String,
	runtime_state: Object
) -> Array:
	var entries: Array = []
	if catalog == null:
		return entries
	for entry_value in catalog_prewarm_entries(catalog, character_type):
		entries.append({
			"kind": "perk",
			"entry": CharacterInfoOverlayValueUtils.get_dict(entry_value),
		})
	if runtime_state == null or not runtime_state.has_method("get_snapshot"):
		return entries
	var snapshot: Dictionary = CharacterInfoOverlayValueUtils.get_dict(runtime_state.get_snapshot())
	var levels: Dictionary = CharacterInfoOverlayValueUtils.get_dict(snapshot.get("runtime_skill_levels", {}))
	for skill_id_value in levels.keys():
		var skill_id: String = str(skill_id_value)
		var level: int = int(levels.get(skill_id_value, 1))
		var data: Dictionary = {}
		if catalog.has_method("get_perk_data"):
			data = CharacterInfoOverlayValueUtils.get_dict(catalog.get_perk_data(skill_id))
		if not data.is_empty():
			data["id"] = skill_id
			data["level"] = level
		entries.append({
			"kind": "runtime_level",
			"level": level,
			"entry": data,
		})
	return entries


static func prewarm_runtime_perk_text_entries_step(
	font: Font,
	entries: Array,
	cursor: int,
	batch_size: int,
	text_size_callable: Callable,
	trim_label_callable: Callable,
	prewarm_text_block_callable: Callable
) -> int:
	if font == null or entries.is_empty():
		return entries.size()
	var end_index: int = min(entries.size(), max(cursor, 0) + max(batch_size, 1))
	for i in range(max(cursor, 0), end_index):
		var prewarm_entry: Dictionary = CharacterInfoOverlayValueUtils.get_dict(entries[i])
		var kind: String = str(prewarm_entry.get("kind", "perk"))
		var entry: Dictionary = CharacterInfoOverlayValueUtils.get_dict(prewarm_entry.get("entry", {}))
		if kind == "runtime_level":
			text_size_callable.call(
				font,
				LanguageSettings.format_mugong_level(
					int(prewarm_entry.get("level", 1)),
					int(entry.get("max_level", 1))
				),
				9
			)
		if entry.is_empty():
			continue
		CharacterInfoOverlayValueUtils.prewarm_perk_text_entry(
			font,
			entry,
			text_size_callable,
			trim_label_callable,
			prewarm_text_block_callable
		)
	return end_index


static func update_overlay_grid_layout(target: Object, grid_rect: Rect2, cell_size: float, stride: float, columns: int, item_count: int, scroll: float, current_layout_rect: Rect2, current_scroll: float, current_columns: int, current_cell_size: float, current_stride: float, current_item_count: int, cell_rect_cache: Array[Rect2], icon_rect_cache: Array[Rect2], center_x_cache: Array[float], level_y_cache: Array[float], visible_index_cache: Array[int]) -> void:
	if grid_rect == current_layout_rect and item_count == current_item_count and columns == current_columns and is_equal_approx(cell_size, current_cell_size) and is_equal_approx(stride, current_stride) and is_equal_approx(scroll, current_scroll):
		return
	target.set("_perk_grid_layout_rect", grid_rect)
	target.set("_perk_grid_layout_item_count", item_count)
	target.set("_perk_grid_layout_columns", columns)
	target.set("_perk_grid_layout_cell_size", cell_size)
	target.set("_perk_grid_layout_stride", stride)
	target.set("_perk_grid_layout_scroll", scroll)
	var layout_state: Dictionary = CharacterInfoOverlayValueUtils.refresh_perk_grid_layout_arrays(
		grid_rect,
		cell_size,
		stride,
		columns,
		item_count,
		scroll,
		cell_rect_cache,
		icon_rect_cache,
		center_x_cache,
		level_y_cache,
		visible_index_cache
	)
	target.set("_last_perk_grid_start", layout_state.get("start", Vector2.ZERO))
	target.set("_last_perk_grid_cell_size", cell_size)
	target.set("_last_perk_grid_stride", stride)
	target.set("_last_perk_grid_columns", columns)
	target.set("_last_perk_grid_item_count", item_count)


static func refresh_draw_arrays(
	acquired: Array,
	draw_id_cache: Array[String],
	draw_color_cache: Array[Color],
	border_color_cache: Array[Color],
	hover_border_color_cache: Array[Color],
	level_text_cache: Array[String],
	level_color_cache: Array[Color],
	hover_title_cache: Array[String],
	hover_body_cache: Array[String],
	hover_detail_cache: Array[String],
	accent_blue: Color,
	perk_level_text_callable: Callable,
	perk_level_color_callable: Callable
) -> void:
	var acquired_count: int = acquired.size()
	draw_id_cache.resize(acquired_count)
	draw_color_cache.resize(acquired_count)
	border_color_cache.resize(acquired_count)
	hover_border_color_cache.resize(acquired_count)
	level_text_cache.resize(acquired_count)
	level_color_cache.resize(acquired_count)
	hover_title_cache.resize(acquired_count)
	hover_body_cache.resize(acquired_count)
	hover_detail_cache.resize(acquired_count)
	for i in range(acquired_count):
		var perk: Dictionary = CharacterInfoOverlayValueUtils.get_dict(acquired[i])
		draw_id_cache[i] = str(perk.get("_draw_id", perk.get("id", "")))
		draw_color_cache[i] = CharacterInfoOverlayValueUtils.get_color(perk.get("_draw_color", perk.get("icon_color", accent_blue)))
		var draw_color: Color = draw_color_cache[i]
		border_color_cache[i] = CharacterInfoOverlayValueUtils.get_color(perk.get("_draw_border_color", Color(draw_color.r, draw_color.g, draw_color.b, 0.48)))
		hover_border_color_cache[i] = CharacterInfoOverlayValueUtils.get_color(perk.get("_draw_hover_border_color", Color(draw_color.r, draw_color.g, draw_color.b, 0.92)))
		level_text_cache[i] = str(perk.get("_level_text", perk_level_text_callable.call(perk)))
		level_color_cache[i] = CharacterInfoOverlayValueUtils.get_color(perk.get("_level_color", perk_level_color_callable.call(perk)))
		hover_title_cache[i] = CharacterInfoOverlayValueUtils.get_string_fallback(perk, "name", "id")
		# body = per-level numeric stats (right panel source); detail = friendly
		# description (left panel). fusion/주사위 셀은 팩킹 본문(결과 로그·태그
		# 스탯)을 쓰고 detail 캐시는 비운다 — hover 실경로가 전용 dual 툴팁으로
		# 분기한다(태그 원문을 일반 본문으로 노출하지 않는다).
		if str(perk.get("tree", "")) in ["fusion", "mystic_dice"]:
			hover_body_cache[i] = pack_fusion_hover_body(
				str(perk.get("detail", "")),
				str(perk.get("description", "")),
				perk.get("fusion_sections", []) as Array
			)
			hover_detail_cache[i] = ""
		else:
			hover_body_cache[i] = CharacterInfoOverlayValueUtils.get_string_fallback(perk, "description", "detail")
			hover_detail_cache[i] = CharacterInfoOverlayValueUtils.get_string_fallback(perk, "detail", "description")


static func draw_grid_cells(
	canvas: CanvasItem,
	font: Font,
	hover_data: Dictionary,
	visible_index_cache: Array[int],
	hovered_perk_index: int,
	icon_renderer: Object,
	can_draw_perk_icon: bool,
	cell_rect_cache: Array[Rect2],
	icon_rect_cache: Array[Rect2],
	center_x_cache: Array[float],
	level_y_cache: Array[float],
	draw_id_cache: Array[String],
	draw_color_cache: Array[Color],
	border_color_cache: Array[Color],
	hover_border_color_cache: Array[Color],
	level_text_cache: Array[String],
	level_color_cache: Array[Color],
	hover_title_cache: Array[String],
	hover_body_cache: Array[String],
	hover_detail_cache: Array[String],
	letter_cache: Dictionary,
	letter_cache_limit: int,
	ring_segments: int,
	grid_cell_fill: Color,
	get_level_text_size_callable: Callable,
	draw_text_centered_with_size_xy_callable: Callable,
	draw_text_centered_xy_callable: Callable,
	set_hover_data_callable: Callable
) -> Dictionary:
	for i in visible_index_cache:
		var cell_rect: Rect2 = cell_rect_cache[i]
		var color: Color = draw_color_cache[i]
		var hovered: bool = i == hovered_perk_index
		var border_color: Color = border_color_cache[i]
		if hovered:
			border_color = hover_border_color_cache[i]
		CharacterInfoOverlayTextureDrawer.draw_mugong_seal_cell(canvas, cell_rect, grid_cell_fill, border_color, 2.0 if hovered else 1.2)
		var perk_id: String = draw_id_cache[i]
		if perk_id == "":
			# Empty seal: a small engraved brush cross, not a modern add button.
			var plus_center: Vector2 = cell_rect.get_center()
			var plus_half: float = cell_rect.size.x * 0.10
			var plus_color := Color(0.55, 0.41, 0.23, 0.72)
			CharacterInfoOverlayTextureDrawer.draw_traditional_plus(canvas, plus_center, plus_half, plus_color, 1.5)
			continue
		if not can_draw_perk_icon or not bool(icon_renderer.draw_icon(canvas, perk_id, icon_rect_cache[i], 1.0, true)):
			CharacterInfoOverlayTextureDrawer.draw_fallback_symbol(canvas, icon_rect_cache[i], color, perk_id, letter_cache, letter_cache_limit, ring_segments, draw_text_centered_xy_callable)
		# The art now fills the same square as the round socket. Restore the rim
		# above it so padded and energetic PNG families share one final diameter.
		CharacterInfoOverlayTextureDrawer.draw_mugong_seal_rim(canvas, cell_rect, border_color, 2.0 if hovered else 1.2)
		var level_text: String = level_text_cache[i]
		var level_color: Color = level_color_cache[i]
		if level_text != "":
			var level_text_size: Vector2 = get_level_text_size_callable.call(font, level_text, 10)
			var badge_rect := get_level_badge_rect(center_x_cache[i], level_y_cache[i], level_text_size)
			CharacterInfoOverlayTextureDrawer.draw_ink_nameplate(canvas, badge_rect, Color(level_color.r, level_color.g, level_color.b, 0.70))
			draw_text_centered_with_size_xy_callable.call(canvas, font, level_text, center_x_cache[i], badge_rect.get_center().y, 10, level_color, level_text_size)
		if hovered:
			# fusion/주사위 셀은 팩킹 본문을 분해한 전용 dual 툴팁(동적 행
			# 예산+색·취소선), 그 외는 개편 범용 2단(좌=detail 설명/우=레벨별
			# 스탯 엔트리)으로 분기한다.
			var fusion_payload: Dictionary = build_fusion_hover_payload(hover_body_cache[i])
			if not fusion_payload.is_empty():
				hover_data = set_hover_data_callable.call(hover_data, hover_title_cache[i], level_text, str(fusion_payload.get("body", "")), color, null, null, fusion_payload.get("roll_options", []))
				hover_data["tooltip_kind"] = str(fusion_payload.get("tooltip_kind", "fusion"))
				var fusion_sections: Array = fusion_payload.get("fusion_sections", []) as Array
				if fusion_sections.size() == 3:
					hover_data["fusion_sections"] = fusion_sections
			else:
				var detail_body: String = hover_detail_cache[i] if i < hover_detail_cache.size() else ""
				var stat_entries: Array = build_perk_stat_entries(hover_body_cache[i], detail_body)
				var left_body: String = detail_body if detail_body != "" else hover_body_cache[i]
				var right_header: String = PERK_STAT_HEADER if not stat_entries.is_empty() else ""
				hover_data = set_hover_data_callable.call(hover_data, hover_title_cache[i], level_text, left_body, color, null, null, stat_entries, right_header)
	return hover_data


# `level_y` is the established lower-edge anchor used by the cached grid layout.
# Keep the plaque bottom fixed, but derive its height from the scaled font metrics
# and center the text inside that rect. The former 16px literal left 10px Korean
# glyph descenders below the dark plaque after UI_TEXT_SCALE raised them to 11px.
static func get_level_badge_rect(center_x: float, level_y: float, text_size: Vector2) -> Rect2:
	var badge_height: float = maxf(
		LEVEL_BADGE_MIN_HEIGHT,
		ceilf(text_size.y + LEVEL_BADGE_VERTICAL_PADDING * 2.0)
	)
	var badge_bottom: float = level_y + LEVEL_BADGE_BOTTOM_OFFSET
	return Rect2(
		center_x - text_size.x * 0.5 - LEVEL_BADGE_HORIZONTAL_PADDING,
		badge_bottom - badge_height,
		text_size.x + LEVEL_BADGE_HORIZONTAL_PADDING * 2.0,
		badge_height
	)


static func draw_overlay_grid_cells(
	canvas: CanvasItem,
	font: Font,
	hover_data: Dictionary,
	target: Object,
	hovered_perk_index: int,
	icon_renderer: Object,
	can_draw_perk_icon: bool,
	letter_cache: Dictionary,
	letter_cache_limit: int,
	ring_segments: int,
	grid_cell_fill: Color,
	get_level_text_size_callable: Callable,
	draw_text_centered_with_size_xy_callable: Callable,
	draw_text_centered_xy_callable: Callable,
	set_hover_data_callable: Callable
) -> Dictionary:
	return draw_grid_cells(
		canvas,
		font,
		hover_data,
		target.get("_perk_grid_visible_index_cache"),
		hovered_perk_index,
		icon_renderer,
		can_draw_perk_icon,
		target.get("_perk_grid_cell_rect_cache"),
		target.get("_perk_grid_icon_rect_cache"),
		target.get("_perk_grid_center_x_cache"),
		target.get("_perk_grid_level_y_cache"),
		target.get("_acquired_perk_draw_id_cache"),
		target.get("_acquired_perk_draw_color_cache"),
		target.get("_acquired_perk_border_color_cache"),
		target.get("_acquired_perk_hover_border_color_cache"),
		target.get("_acquired_perk_level_text_cache"),
		target.get("_acquired_perk_level_color_cache"),
		target.get("_acquired_perk_hover_title_cache"),
		target.get("_acquired_perk_hover_body_cache"),
		target.get("_acquired_perk_hover_detail_cache"),
		letter_cache,
		letter_cache_limit,
		ring_segments,
		grid_cell_fill,
		get_level_text_size_callable,
		draw_text_centered_with_size_xy_callable,
		draw_text_centered_xy_callable,
		set_hover_data_callable
	)


static func effective_runtime_perk_levels_from_snapshot(runtime_snapshot_override: Variant) -> Dictionary:
	if runtime_snapshot_override is Dictionary:
		return CharacterInfoOverlayValueUtils.get_dict((runtime_snapshot_override as Dictionary).get("effective_runtime_skill_levels", {}))
	return {}


static func effective_runtime_perk_level(runtime_state: Object, skill_id: String, base_level: int, effective_levels: Dictionary = {}) -> int:
	if base_level <= 0:
		return base_level
	if effective_levels.has(skill_id):
		return max(0, int(effective_levels.get(skill_id, base_level)))
	if runtime_state != null and runtime_state.has_method("get_runtime_skill_level"):
		return max(0, int(runtime_state.get_runtime_skill_level(skill_id)))
	return base_level


static func sort_perks(a: Dictionary, b: Dictionary) -> bool:
	var a_level: int = int(a.get("level", 0))
	var b_level: int = int(b.get("level", 0))
	if a_level == b_level:
		var a_id := str(a.get("id", ""))
		var b_id := str(b.get("id", ""))
		if a_id != b_id:
			return a_id < b_id
		return int(a.get("_slot_cell_index", 0)) < int(b.get("_slot_cell_index", 0))
	return a_level > b_level
