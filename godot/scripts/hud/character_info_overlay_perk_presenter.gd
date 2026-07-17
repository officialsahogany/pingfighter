extends RefCounted

const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const CharacterInfoOverlayTextureDrawer := preload("res://scripts/hud/character_info_overlay_texture_drawer.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const LEVEL_BADGE_FILL := Color(0.05, 0.09, 0.15, 0.92)


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
const FUSION_STAT_HEADER_COLOR := Color(1.0, 0.84, 0.42, 1.0)
const FUSION_STAT_PENALTY_COLOR := Color(1.0, 0.55, 0.45, 1.0)
const FUSION_STAT_DELETED_COLOR := Color(0.62, 0.62, 0.66, 1.0)
const FUSION_STAT_BYPRODUCT_COLOR := Color(0.55, 0.85, 1.0, 1.0)
const FUSION_ENTRY_DRAW_COLOR := Color(0.72, 0.46, 0.98, 1.0)


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
	accent_gold: Color
) -> Array:
	var result: Array = []
	for entry_value: Variant in projection_entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value as Dictionary
		if str(entry.get("type", "perk")) == "fusion":
			var fusion_data: Dictionary = _fusion_display_entry(entry, accent_gold)
			if not fusion_data.is_empty():
				result.append(fusion_data)
			continue
		var perk_id := str(entry.get("perk_id", entry.get("id", "")))
		var base_level := int(entry.get("base_level", 0))
		if perk_id.is_empty() or base_level <= 0:
			continue
		var level := int(entry.get("effective_level", int(effective_levels.get(perk_id, base_level))))
		var data: Dictionary = acquired_perk_data(perk_id, base_level, level, catalog, {}, accent_blue)
		if data.is_empty():
			continue
		_decorate_presented_perk(data, perk_id, accent_blue, accent_gold)
		result.append(data)
	return result


static func _decorate_presented_perk(data: Dictionary, draw_id: String, accent_blue: Color, accent_gold: Color) -> void:
	data["_draw_id"] = draw_id
	var draw_color: Color = CharacterInfoOverlayValueUtils.get_color(data.get("icon_color", accent_blue))
	data["_draw_color"] = draw_color
	data["_draw_border_color"] = Color(draw_color.r, draw_color.g, draw_color.b, 0.48)
	data["_draw_hover_border_color"] = Color(draw_color.r, draw_color.g, draw_color.b, 0.92)
	data["_level_text"] = CharacterInfoOverlayFormatter.perk_level_text(data)
	data["_level_color"] = CharacterInfoOverlayFormatter.perk_level_color(data, accent_gold)


static func _fusion_display_entry(entry: Dictionary, accent_gold: Color) -> Dictionary:
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
	data["_draw_id"] = _fusion_icon_key().build(
		fusion_id,
		int(entry.get("fusion_revision", 0)),
		sources
	)
	data["_draw_color"] = FUSION_ENTRY_DRAW_COLOR
	data["_draw_border_color"] = Color(FUSION_ENTRY_DRAW_COLOR.r, FUSION_ENTRY_DRAW_COLOR.g, FUSION_ENTRY_DRAW_COLOR.b, 0.48)
	data["_draw_hover_border_color"] = Color(FUSION_ENTRY_DRAW_COLOR.r, FUSION_ENTRY_DRAW_COLOR.g, FUSION_ENTRY_DRAW_COLOR.b, 0.92)
	data["_level_text"] = str(localization.text("level_fusion"))
	data["_level_color"] = accent_gold
	return data


# fusion 셀의 hover 본문 팩킹 구분자: hover_body_cache는 String 배열이라
# 구조를 실을 수 없다 — detail(결과 로그, 좌패널)과 description(태그 스탯,
# 우패널 분해용)을 제어문자 1개로 팩킹해 드로우 시점에 분해한다.
const FUSION_HOVER_SPLIT := ""


static func pack_fusion_hover_body(detail: String, tagged_stats: String) -> String:
	return detail + FUSION_HOVER_SPLIT + tagged_stats


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
	var entries: Array = build_perk_stat_entries(tagged_stats, "")
	if entries.is_empty():
		return {}
	if detail_text.strip_edges().is_empty():
		detail_text = str((entries[0] as Dictionary).get("text", " "))
	return {
		"body": detail_text,
		"roll_options": entries,
	}


# 융합 스탯 문자열([[fusion:*]] 프리픽스 라인) → 렌더 엔트리 분해. 삭제
# 흉터는 U+0336 결합 글리프 대신 렌더러 소유 strikethrough 메타로 표기한다
# (한국어 폰트 스택에 결합 취소선 글리프가 없어 tofu가 된다).
static func build_perk_stat_entries(stats: String, _detail: String) -> Array:
	var localization: Object = _fusion_localization()
	var entries: Array = []
	for raw_line: String in stats.split("\n", false):
		var line := raw_line
		var color: Color = Color.WHITE
		var strikethrough := false
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
		elif line.begins_with(localization.STAT_NORMAL_PREFIX):
			line = line.trim_prefix(localization.STAT_NORMAL_PREFIX)
		if line.strip_edges().is_empty():
			continue
		entries.append({
			"text": line,
			"color": color,
			"strikethrough": strikethrough,
		})
	return entries


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
		var description_value: Variant = descriptions.get(level, null)
		if description_value == null:
			description_value = data.get("detail", "")
		data["description"] = str(description_value)
	return data


static func build_acquired_perks(levels: Dictionary, catalog: Object, runtime_state: Object = null, runtime_snapshot_override: Variant = null, effective_levels_override: Dictionary = {}, equipped_skills_for_filter: Array = [], accent_blue: Color = Color.WHITE, accent_gold: Color = Color.WHITE) -> Array:
	var result: Array = []
	var effective_levels: Dictionary = effective_levels_override if not effective_levels_override.is_empty() else effective_runtime_perk_levels_from_snapshot(runtime_snapshot_override)
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
				accent_gold
			)
			projected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return sort_perks(a, b)
			)
			return projected
	var equipped_skill_lookup: Dictionary = build_equipped_skill_lookup(equipped_skills_for_filter)
	for skill_id_value in levels:
		var skill_id: String = str(skill_id_value)
		var base_level: int = int(levels.get(skill_id_value, 0))
		if base_level <= 0:
			continue
		var level: int = effective_runtime_perk_level(runtime_state, skill_id, base_level, effective_levels)
		var data: Dictionary = acquired_perk_data(skill_id, base_level, level, catalog, equipped_skill_lookup, accent_blue)
		if data.is_empty():
			continue
		data["_draw_id"] = skill_id
		var draw_color: Color = CharacterInfoOverlayValueUtils.get_color(data.get("icon_color", accent_blue))
		data["_draw_color"] = draw_color
		data["_draw_border_color"] = Color(draw_color.r, draw_color.g, draw_color.b, 0.48)
		data["_draw_hover_border_color"] = Color(draw_color.r, draw_color.g, draw_color.b, 0.92)
		data["_level_text"] = CharacterInfoOverlayFormatter.perk_level_text(data)
		data["_level_color"] = CharacterInfoOverlayFormatter.perk_level_color(data, accent_gold)
		_apply_runtime_status_lines(data, skill_id, runtime_state)
		result.append(data)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return sort_perks(a, b)
	)
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
	accent_blue: Color,
	accent_gold: Color
) -> Array:
	var effective_levels: Dictionary = effective_runtime_perk_levels_from_snapshot(runtime_snapshot_override)
	var cache_hash: int = acquired_perk_cache_hash(levels, catalog, runtime_state, runtime_snapshot_override, effective_levels, equipped_skills_for_filter)
	if cache_ready and cache_hash == current_cache_hash:
		return cached_perks
	var acquired: Array = build_acquired_perks(levels, catalog, runtime_state, runtime_snapshot_override, effective_levels, equipped_skills_for_filter, accent_blue, accent_gold)
	refresh_draw_arrays(acquired, draw_id_cache, draw_color_cache, border_color_cache, hover_border_color_cache, level_text_cache, level_color_cache, hover_title_cache, hover_body_cache, accent_blue, Callable(CharacterInfoOverlayFormatter, "perk_level_text"), Callable(CharacterInfoOverlayFormatter, "perk_level_color").bind(accent_gold))
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
		if kind == "runtime_level":
			text_size_callable.call(font, "Lv.%d" % int(prewarm_entry.get("level", 1)), 9)
		var entry: Dictionary = CharacterInfoOverlayValueUtils.get_dict(prewarm_entry.get("entry", {}))
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
		if str(perk.get("tree", "")) == "fusion":
			# fusion 셀: detail(결과 로그)+태그 스탯을 팩킹 — 실 hover가
			# build_fusion_hover_payload로 분해해 dual 툴팁(13행·색·취소선)을
			# 탄다. [[fusion:*]] 태그 원문을 일반 본문으로 노출하지 않는다.
			hover_body_cache[i] = pack_fusion_hover_body(str(perk.get("detail", "")), str(perk.get("description", "")))
		else:
			hover_body_cache[i] = CharacterInfoOverlayValueUtils.get_string_fallback(perk, "description", "detail")


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
		CharacterInfoOverlayTextureDrawer.draw_hex_cell(canvas, cell_rect, grid_cell_fill, border_color, 2.0 if hovered else 1.2)
		var perk_id: String = draw_id_cache[i]
		if not can_draw_perk_icon or not bool(icon_renderer.draw_icon(canvas, perk_id, icon_rect_cache[i], 1.0, true)):
			CharacterInfoOverlayTextureDrawer.draw_fallback_symbol(canvas, icon_rect_cache[i], color, perk_id, letter_cache, letter_cache_limit, ring_segments, draw_text_centered_xy_callable)
		var level_text: String = level_text_cache[i]
		var level_color: Color = level_color_cache[i]
		var level_text_size: Vector2 = get_level_text_size_callable.call(font, level_text, 9)
		var badge_rect := Rect2(center_x_cache[i] - level_text_size.x * 0.5 - 6.0, level_y_cache[i] - 10.0, level_text_size.x + 12.0, 13.0)
		canvas.draw_rect(badge_rect, LEVEL_BADGE_FILL)
		canvas.draw_rect(badge_rect, Color(level_color.r, level_color.g, level_color.b, 0.55), false, 1.0)
		draw_text_centered_with_size_xy_callable.call(canvas, font, level_text, center_x_cache[i], level_y_cache[i], 9, level_color, level_text_size)
		if hovered:
			# fusion 셀 hover 실경로: 팩킹 본문을 분해해 roll_options(스탯
			# 엔트리)+tooltip_kind="fusion"을 실으면 draw_tooltip이 dual
			# 툴팁(동적 행 예산+색·취소선)으로 분기한다. 비-fusion은 기존
			# 단일 툴팁 경로 그대로.
			var fusion_payload: Dictionary = build_fusion_hover_payload(hover_body_cache[i])
			if fusion_payload.is_empty():
				hover_data = set_hover_data_callable.call(hover_data, hover_title_cache[i], level_text, hover_body_cache[i], color)
			else:
				hover_data = set_hover_data_callable.call(hover_data, hover_title_cache[i], level_text, str(fusion_payload.get("body", "")), color, null, null, fusion_payload.get("roll_options", []))
				hover_data["tooltip_kind"] = "fusion"
	return hover_data


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
		return str(a.get("id", "")) < str(b.get("id", ""))
	return a_level > b_level
