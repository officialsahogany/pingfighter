extends SceneTree

const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")
const CharacterInfoOverlayTextUtils := preload("res://scripts/hud/character_info_overlay_text_utils.gd")
const CharacterInfoOverlayTooltipPresenter := preload("res://scripts/hud/character_info_overlay_tooltip_presenter.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")
const PerkFusionLocalization := preload("res://scripts/characters/perk_fusion_localization.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []

# 실 draw 관통 레그용 프로브 상태(드로우 시그널 핸들러와 공유).
var _probe_draw_ran := false
var _probe_hover_data: Dictionary = {}
var _probe_draw_id_cache: Array[String] = []
var _probe_draw_color_cache: Array[Color] = []
var _probe_border_color_cache: Array[Color] = []
var _probe_hover_border_color_cache: Array[Color] = []
var _probe_level_text_cache: Array[String] = []
var _probe_level_color_cache: Array[Color] = []
var _probe_hover_title_cache: Array[String] = []
var _probe_hover_body_cache: Array[String] = []
var _probe_hover_detail_cache: Array[String] = []
var _dual_dispatch_capture: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var left_id := "reinforced_boomerang_gauntlet"
	var right_id := "master"
	var left_name := "초장거리 강화 부메랑 장인의 건틀릿"
	var right_name := "견고한 초대형 벽돌 장인의 설계도"
	var live_options := {
		left_id: {
			"boomerang_knockback_pct": {"value": 50.0, "adjusted_value": 40.0},
			"boomerang_stun_pct": {"value": 80.0, "adjusted_value": 80.0},
			"boomerang_launch_speed_pct": {"value": 50.0, "adjusted_value": 50.0},
			"boomerang_homing_pct": {"value": 50.0, "adjusted_value": 50.0},
			"boomerang_spawn_bonus_pct": {"value": 200.0, "adjusted_value": 200.0},
		},
		right_id: {
			"wall_length_pct": {"value": 45.0, "adjusted_value": 45.0},
			"item_cooldown_pct": {"value": 12.0, "adjusted_value": 0.0, "deleted": true},
			"wall_spawn_bonus_pct": {"value": 330.0, "adjusted_value": 330.0},
		},
	}
	var record := {
		"fusion_id": "fusion_worst",
		"created_revision": 7,
		"sources": [left_id, right_id],
		"outcome": "side_effect",
		"option_penalties": {
			left_id: {
				"boomerang_knockback_pct": {
					"original_value": 50.0,
					"adjusted_value": 40.0,
					"nominal_pct": 20.0,
				},
			},
		},
		"deleted_options": {right_id: ["item_cooldown_pct"]},
		"byproducts": ["reverb", "golden_trajectory", "limit_break"],
		"byproduct_payloads": {"limit_break": {"eligible_sources": [left_id]}},
	}
	var projection_entry := {
		"type": "fusion",
		"id": "fusion_worst",
		"fusion_id": "fusion_worst",
		"fusion_revision": 7,
		"sources": [left_id, right_id],
		"source_names": [left_name, right_name],
		"base_levels": {left_id: 5, right_id: 5},
		"effective_levels": {left_id: 7, right_id: 6},
		"live_source_options": live_options,
		"record_payload": record,
		"summary": "%s × %s · 부산물 3" % [left_name, right_name],
	}
	var acquired := CharacterInfoOverlayPerkPresenter.build_acquired_perks_from_projection(
		[projection_entry],
		null,
		{},
		Color.CORNFLOWER_BLUE,
		Color.GOLD
	)
	var fusion: Dictionary = acquired[0] if not acquired.is_empty() else {}
	var detail := str(fusion.get("detail", ""))
	var stats := str(fusion.get("description", ""))
	var detail_lines := detail.split("\n", false)
	_expect(detail_lines.size() <= 3, "fusion result log must stay within the left-panel three-line contract")
	_expect(detail != stats, "fusion result log and material stats must not collapse into one panel")
	_expect(stats.count(PerkFusionLocalization.STAT_HEADER_PREFIX + left_name) == 1 and stats.count(PerkFusionLocalization.STAT_HEADER_PREFIX + right_name) == 1, "each long material name should appear once as a section header")
	for raw_key in ["boomerang_knockback_pct", "item_cooldown_pct", "wall_spawn_bonus_pct"]:
		_expect(not stats.contains(raw_key), "tooltip must not leak internal option key %s" % raw_key)
	var entries := CharacterInfoOverlayPerkPresenter.build_perk_stat_entries(stats, detail)
	_expect(entries.size() == 13, "worst fixture should retain 2 headers + 8 option lanes + 3 byproduct lanes without silent drop")
	var joined_entry_text := ""
	var colors: Array[Color] = []
	var deleted_entry: Dictionary = {}
	for entry_value: Variant in entries:
		var entry: Dictionary = entry_value as Dictionary
		joined_entry_text += str(entry.get("text", "")) + "\n"
		colors.append(entry.get("color", Color.WHITE) as Color)
		if bool(entry.get("strikethrough", false)):
			deleted_entry = entry
	_expect(joined_entry_text.contains("50% → 40%") and joined_entry_text.contains("20%"), "penalty lane should show live original-to-current values")
	_expect(joined_entry_text.contains("삭제"), "deleted scar should keep its explicit deletion badge")
	_expect(not joined_entry_text.contains("\u0336"), "deleted scar must not inject unsupported U+0336 combining glyphs")
	_expect(not deleted_entry.is_empty(), "deleted scar should expose renderer-owned strikethrough metadata")
	var fallback_font: Font = ThemeDB.fallback_font
	_expect(fallback_font != null and not fallback_font.has_char(0x0336), "fixture should seal the unsupported combining-strikethrough font condition")
	var rendered_lines: Array = []
	var line_dict_cache: Array = []
	var text_cache: Array[String] = []
	var color_cache: Array[Color] = []
	var line_state := CharacterInfoOverlayTextUtils.refresh_tooltip_entry_lines(
		fallback_font,
		[deleted_entry],
		12,
		170.0,
		4,
		0,
		0,
		0,
		0,
		rendered_lines,
		line_dict_cache,
		text_cache,
		color_cache,
		func(_font: Font, text: String, _size: int, _width: float, _max_lines: int) -> Array:
			return [text],
		Color.GOLD
	)
	var wrapped_entries: Array = line_state.get("lines", []) as Array
	_expect(wrapped_entries.size() == 1 and bool((wrapped_entries[0] as Dictionary).get("strikethrough", false)), "wrapped render entry should preserve strikethrough metadata")
	var strike_segment := CharacterInfoOverlayTooltipPresenter.build_strikethrough_segment(
		fallback_font,
		str(deleted_entry.get("text", "")),
		Vector2(12.0, 40.0),
		12,
		170.0
	)
	_expect(strike_segment.size() == 2 and strike_segment[1].x > strike_segment[0].x and strike_segment[1].x <= 182.0, "deleted render entry should produce one bounded explicit strike segment")
	_expect(joined_entry_text.contains("잔향") and joined_entry_text.contains("황금 궤적") and joined_entry_text.contains("한계 돌파"), "all three byproduct lanes should remain visible")
	_expect(joined_entry_text.contains(left_name), "limit-break payload should name its eligible material")
	_expect(colors.has(CharacterInfoOverlayPerkPresenter.FUSION_STAT_HEADER_COLOR), "material headers should keep their dedicated color")
	_expect(colors.has(CharacterInfoOverlayPerkPresenter.FUSION_STAT_PENALTY_COLOR), "penalty lane should keep its red correction color")
	_expect(colors.has(CharacterInfoOverlayPerkPresenter.FUSION_STAT_DELETED_COLOR), "deleted scar should keep its deletion color")
	_expect(colors.has(CharacterInfoOverlayPerkPresenter.FUSION_STAT_BYPRODUCT_COLOR), "byproduct lanes should keep their gold color")
	var tooltip_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_tooltip_presenter.gd")
	var localization_source := FileAccess.get_file_as_string("res://scripts/characters/perk_fusion_localization.gd")
	_expect(tooltip_source.contains("tooltip_kind") and tooltip_source.contains("entry_line_limit"), "fusion tooltip renderer should use the expanded dynamic row budget")
	_expect(tooltip_source.contains("mini(24"), "fusion row budget should exceed the legacy eight-line cap")
	_expect(tooltip_source.contains("canvas.draw_line") and tooltip_source.contains("build_strikethrough_segment"), "deleted entries should draw an explicit renderer-owned strike line")
	_expect(not localization_source.contains("\\u0336") and not localization_source.contains("func _strikethrough"), "fusion localization must not encode strikethrough as combining glyphs")

	# 실 hover 관통(v1 반려 P1-2): TAB 그리드의 실 hover 캐시 배관 →
	# 팩킹 본문 → payload 분해 → set_hover_data(roll_options)+tooltip_kind
	# → draw_tooltip dual 분기 조건까지, 캔버스 밖에서 검증 가능한 전 구간을
	# 실 함수로 관통한다.
	var draw_id_cache: Array[String] = []
	var draw_color_cache: Array[Color] = []
	var border_color_cache: Array[Color] = []
	var hover_border_color_cache: Array[Color] = []
	var level_text_cache: Array[String] = []
	var level_color_cache: Array[Color] = []
	var hover_title_cache: Array[String] = []
	var hover_body_cache: Array[String] = []
	# 씰 갱신(2026-07-20): hover_detail_cache 도입 후 시그니처(파스-RED
	# 소실분 — 낡은 인자 목록은 자리밀림 파스 에러).
	var hover_detail_cache: Array[String] = []
	CharacterInfoOverlayPerkPresenter.refresh_draw_arrays(
		acquired,
		draw_id_cache,
		draw_color_cache,
		border_color_cache,
		hover_border_color_cache,
		level_text_cache,
		level_color_cache,
		hover_title_cache,
		hover_body_cache,
		hover_detail_cache,
		Color.CORNFLOWER_BLUE,
		func(_perk: Dictionary) -> String: return "",
		func(_perk: Dictionary) -> Color: return Color.WHITE
	)
	_expect(hover_body_cache.size() == 1 and hover_body_cache[0].contains(CharacterInfoOverlayPerkPresenter.FUSION_HOVER_SPLIT), "real hover cache should carry the packed fusion body (detail + tagged stats)")
	var hover_payload: Dictionary = CharacterInfoOverlayPerkPresenter.build_fusion_hover_payload(hover_body_cache[0])
	_expect(not hover_payload.is_empty(), "packed fusion hover body should decode into a dual-tooltip payload")
	var hover_body := str(hover_payload.get("body", ""))
	_expect(hover_body == detail and hover_body != "", "hover left panel body should be the fusion result log")
	_expect(not hover_body.contains("[[fusion:"), "hover body must not leak raw fusion stat tags")
	var hover_roll_options: Array = hover_payload.get("roll_options", []) as Array
	_expect(hover_roll_options.size() == 13, "hover roll options should retain the full 13-entry worst case")
	var hover_has_strike := false
	for hover_entry_value: Variant in hover_roll_options:
		var hover_entry: Dictionary = hover_entry_value as Dictionary
		_expect(not str(hover_entry.get("text", "")).contains("[[fusion:"), "hover roll entry text must not leak raw fusion stat tags")
		if bool(hover_entry.get("strikethrough", false)):
			hover_has_strike = true
	_expect(hover_has_strike, "hover roll entries should preserve the deletion strikethrough metadata")
	var non_fusion_payload: Dictionary = CharacterInfoOverlayPerkPresenter.build_fusion_hover_payload("일반 퍽 설명문")
	_expect(non_fusion_payload.is_empty(), "plain perk hover bodies must keep the legacy single-tooltip path")
	var hover_data: Dictionary = {}
	hover_data = CharacterInfoOverlayValueUtils.set_hover_data(
		hover_data,
		str(fusion.get("name", "")),
		"융합",
		hover_body,
		Color.CORNFLOWER_BLUE,
		null,
		null,
		hover_roll_options
	)
	hover_data["tooltip_kind"] = "fusion"
	var dispatch_roll_entries: Array = hover_data.get("roll_options", []) as Array
	_expect(not dispatch_roll_entries.is_empty() and str(hover_data.get("body", "")) != "", "assembled hover data should satisfy draw_tooltip's dual-panel dispatch condition")
	_expect(str(hover_data.get("tooltip_kind", "")) == "fusion", "assembled hover data should request the fusion dynamic row budget")
	var grid_cells_body := _extract_static_function_body(
		FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_perk_presenter.gd"),
		"static func draw_grid_cells("
	)
	_expect(grid_cells_body.contains("build_fusion_hover_payload"), "real grid hover branch must decode the packed fusion body")
	_expect(grid_cells_body.contains("hover_data[\"tooltip_kind\"] = str(fusion_payload.get(\"tooltip_kind\", \"fusion\"))"), "real grid hover branch must inject the payload-owned tooltip kind (fusion default)")
	_expect(grid_cells_body.contains("fusion_payload.get(\"roll_options\", [])"), "real grid hover branch must forward decoded stat entries as roll options")

	# v3(재리뷰 P2·게이트): 실 draw 관통 행동 레그 — 실제 CanvasItem draw
	# 시그널 안에서 프로덕션 draw_grid_cells가 hovered 셀의 hover 데이터를
	# 조립하고, 그 데이터가 실제 draw_tooltip의 dual 분기 디스패치에
	# 도달하는지 행동으로 봉인한다(소스씰만으로는 hover 인덱스·분기 도달·
	# Callable 인자 회귀가 GREEN일 수 있다).
	_probe_draw_id_cache = draw_id_cache
	_probe_draw_color_cache = draw_color_cache
	_probe_border_color_cache = border_color_cache
	_probe_hover_border_color_cache = hover_border_color_cache
	_probe_level_text_cache = level_text_cache
	_probe_level_color_cache = level_color_cache
	_probe_hover_title_cache = hover_title_cache
	_probe_hover_body_cache = hover_body_cache
	_probe_hover_detail_cache = hover_detail_cache
	var probe := Control.new()
	root.add_child(probe)
	probe.draw.connect(_on_probe_draw.bind(probe))
	for _redraw_attempt in range(4):
		if _probe_draw_ran:
			break
		probe.queue_redraw()
		await process_frame
	probe.queue_free()
	_expect(_probe_draw_ran, "the live TAB grid draw pass should have executed")
	_expect(str(_probe_hover_data.get("tooltip_kind", "")) == "fusion", "real draw_grid_cells hover output should request the fusion tooltip kind")
	_expect(str(_probe_hover_data.get("body", "")) == detail, "real draw_grid_cells hover output should carry the fusion result log as the left-panel body")
	var live_roll_options: Array = _probe_hover_data.get("roll_options", []) as Array
	_expect(live_roll_options.size() == 13, "real draw_grid_cells hover output should carry the full 13-entry stat payload")
	CharacterInfoOverlayTooltipPresenter.draw_tooltip(
		null,
		_probe_hover_data,
		Vector2(200.0, 200.0),
		Vector2(760.0, 750.0),
		fallback_font,
		[],
		Color.CORNFLOWER_BLUE,
		Color.WHITE,
		Color(0.0, 0.0, 0.0, 0.9),
		Callable(),
		Callable(),
		Callable(),
		Callable(self, "_capture_dual_dispatch"),
		Callable()
	)
	_expect(not _dual_dispatch_capture.is_empty(), "hover data assembled by the real grid draw must dispatch into the dual-tooltip branch of the real draw_tooltip")
	_expect((_dual_dispatch_capture.get("roll_entries", []) as Array).size() == 13, "the dual dispatch should receive all 13 stat entries")
	_expect(str((_dual_dispatch_capture.get("data", {}) as Dictionary).get("tooltip_kind", "")) == "fusion", "the dual dispatch should receive the fusion dynamic row budget request")
	_expect(str(_dual_dispatch_capture.get("body", "")) == detail, "the dual dispatch left panel should be the fusion result log")

	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("perk_fusion_tooltip_worst_case_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


# 실 draw 시그널 핸들러: 프로덕션 draw_grid_cells를 hovered 인덱스로 직접
# 호출한다(실 콜러블 배선 — set_hover_data는 프로덕션 static 그대로).
func _on_probe_draw(probe: CanvasItem) -> void:
	_probe_draw_ran = true
	var probe_font: Font = ThemeDB.fallback_font
	var hover_data: Dictionary = {}
	var visible_indexes: Array[int] = [0]
	var cell_rects: Array[Rect2] = [Rect2(10.0, 10.0, 52.0, 52.0)]
	var icon_rects: Array[Rect2] = [Rect2(14.0, 14.0, 44.0, 44.0)]
	var center_xs: Array[float] = [36.0]
	var level_ys: Array[float] = [58.0]
	_probe_hover_data = CharacterInfoOverlayPerkPresenter.draw_grid_cells(
		probe,
		probe_font,
		hover_data,
		visible_indexes,
		0,
		null,
		false,
		cell_rects,
		icon_rects,
		center_xs,
		level_ys,
		_probe_draw_id_cache,
		_probe_draw_color_cache,
		_probe_border_color_cache,
		_probe_hover_border_color_cache,
		_probe_level_text_cache,
		_probe_level_color_cache,
		_probe_hover_title_cache,
		_probe_hover_body_cache,
		_probe_hover_detail_cache,
		{},
		24,
		24,
		Color(0.1, 0.1, 0.2, 0.6),
		Callable(self, "_probe_level_text_size"),
		Callable(self, "_probe_draw_text_centered_with_size"),
		Callable(self, "_probe_draw_text_centered"),
		Callable(CharacterInfoOverlayValueUtils, "set_hover_data")
	)


func _probe_level_text_size(font: Font, text: String, size: int) -> Vector2:
	if font == null:
		return Vector2(10.0, 10.0)
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)


func _probe_draw_text_centered_with_size(canvas: CanvasItem, font: Font, text: String, center_x: float, y: float, size: int, color: Color, text_size: Vector2) -> void:
	if canvas != null and font != null:
		canvas.draw_string(font, Vector2(center_x - text_size.x * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _probe_draw_text_centered(canvas: CanvasItem, font: Font, text: String, center_x: float, y: float, size: int, color: Color) -> void:
	if canvas != null and font != null:
		canvas.draw_string(font, Vector2(center_x, y), text, HORIZONTAL_ALIGNMENT_CENTER, -1, size, color)


# 실 draw_tooltip의 dual 분기 디스패치 캡처(프로덕션 시그니처 미러).
func _capture_dual_dispatch(_canvas: Variant, data: Dictionary, _mouse_pos: Vector2, _view_size: Vector2, _font: Font, _color: Color, _title: String, _subtitle: String, body: String, roll_entries: Array) -> void:
	_dual_dispatch_capture = {
		"data": data,
		"body": body,
		"roll_entries": roll_entries,
	}


# 소스씰용 static 함수 본문 추출(다음 최상위 선언 전까지).
func _extract_static_function_body(source: String, function_signature_prefix: String) -> String:
	var start: int = source.find(function_signature_prefix)
	if start < 0:
		_failures.append("source seal could not find %s" % function_signature_prefix)
		return ""
	var end: int = source.find("\nstatic func ", start + function_signature_prefix.length())
	if end < 0:
		end = source.length()
	return source.substr(start, end - start)
