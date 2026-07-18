extends RefCounted

const PerkFusionModalLayout := preload("res://scripts/characters/perk_fusion_modal_layout.gd")
const PerkFusionLocalization := preload("res://scripts/characters/perk_fusion_localization.gd")
const PerkFusionIconKey := preload("res://scripts/characters/perk_fusion_icon_key.gd")
const PerkFusionOutcomeRules := preload("res://scripts/characters/perk_fusion_outcome_rules.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const KOREAN_UI_FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")

const PHASE_MATERIALS := "materials"
const PHASE_CONFIRM := "confirm"
const PHASE_ANIMATION := "animation"
const PHASE_REVEAL := "reveal"
const PerkFusionColdBootTimelineState := preload("res://scripts/characters/perk_fusion_cold_boot_timeline_state.gd")
# 콜드부트 타임라인이 단일 권위 — modal flow의 같은 이름 상수와 동일 파생
# (이중 duration 상수 트랩 봉인).
const DEFAULT_ANIMATION_DURATION := PerkFusionColdBootTimelineState.TOTAL_ANIMATION_DURATION
const MAX_RESULT_LINES := 8
const MAX_LINE_CHARS := 48

const BACKDROP_COLOR := Color(0.01, 0.015, 0.035, 0.78)
const PANEL_COLOR := Color(0.055, 0.07, 0.12, 0.985)
const PANEL_BORDER_COLOR := Color(0.36, 0.73, 1.0, 0.88)
const ACCENT_COLOR := Color(0.32, 0.86, 1.0, 1.0)
const GOLD_COLOR := Color(1.0, 0.79, 0.27, 1.0)
const MUTED_COLOR := Color(0.68, 0.76, 0.88, 1.0)

var _layout_helper: Object = PerkFusionModalLayout.new()
var _fallback_font: Font = null


func prewarm_assets() -> void:
	# The Korean UI font is statically preloaded. Draw-time work stays resource-free.
	pass


func reset() -> void:
	pass


func draw(
	canvas: CanvasItem,
	fusion_snapshot: Dictionary,
	catalog: Object,
	view_size: Vector2,
	icon_renderer: Object = null
) -> void:
	if canvas == null or fusion_snapshot.is_empty() or view_size.x <= 1.0 or view_size.y <= 1.0:
		return
	var phase: String = str(fusion_snapshot.get("phase", ""))
	if phase not in [PHASE_MATERIALS, PHASE_CONFIRM, PHASE_ANIMATION, PHASE_REVEAL]:
		return
	var layout: Dictionary = _layout_helper.build_layout(fusion_snapshot, view_size)
	_draw_shell(canvas, layout, view_size)
	match phase:
		PHASE_MATERIALS:
			_draw_materials(canvas, fusion_snapshot, catalog, layout, icon_renderer)
		PHASE_CONFIRM:
			_draw_confirm(canvas, fusion_snapshot, catalog, layout, icon_renderer)
		PHASE_ANIMATION:
			_draw_animation(canvas, fusion_snapshot, catalog, layout)
		PHASE_REVEAL:
			_draw_reveal(canvas, fusion_snapshot, catalog, layout, icon_renderer)


func _draw_shell(canvas: CanvasItem, layout: Dictionary, view_size: Vector2) -> void:
	var panel_rect: Rect2 = _as_rect2(layout.get("panel_rect", Rect2()))
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), BACKDROP_COLOR, true)
	canvas.draw_rect(panel_rect, PANEL_COLOR, true)
	canvas.draw_rect(panel_rect.grow(4.0), Color(0.12, 0.34, 0.62, 0.22), false, 3.0)
	canvas.draw_rect(panel_rect, PANEL_BORDER_COLOR, false, 2.0)


func _draw_materials(
	canvas: CanvasItem,
	snapshot: Dictionary,
	catalog: Object,
	layout: Dictionary,
	icon_renderer: Object
) -> void:
	var panel_rect: Rect2 = _as_rect2(layout.get("panel_rect", Rect2()))
	_draw_heading(canvas, panel_rect, PerkFusionLocalization.text("materials_title"), PerkFusionLocalization.text("materials_subtitle"))
	var candidate_ids: Array = _as_array(snapshot.get("candidate_ids", []))
	var selected_sources: Array = _selected_sources(snapshot)
	var highlighted_index: int = int(snapshot.get("highlight_index", 0))
	var candidate_rects: Array = _as_array(layout.get("candidate_rects", []))
	var visible_indices: Array = _as_array(layout.get("visible_candidate_indices", []))
	for index_value in visible_indices:
		var candidate_index: int = int(index_value)
		if candidate_index < 0 or candidate_index >= candidate_ids.size() or candidate_index >= candidate_rects.size():
			continue
		var perk_id: String = str(candidate_ids[candidate_index])
		var selected_order: int = selected_sources.find(perk_id)
		_draw_candidate_card(
			canvas,
			perk_id,
			_as_rect2(candidate_rects[candidate_index]),
			candidate_index == highlighted_index,
			selected_order,
			catalog,
			icon_renderer,
			{}
		)
	var page_count: int = int(layout.get("page_count", 1))
	if page_count > 1:
		var grid_rect: Rect2 = _as_rect2(layout.get("grid_rect", Rect2()))
		_draw_text_centered(
			canvas,
			PerkFusionLocalization.format("page", [int(layout.get("page_index", 0)) + 1, page_count]),
			Vector2(grid_rect.get_center().x, grid_rect.end.y - 6.0),
			12,
			MUTED_COLOR
		)
	_draw_button(canvas, _as_rect2(layout.get("back_rect", Rect2())), PerkFusionLocalization.text("cancel"), false, false)
	_draw_button(
		canvas,
		_as_rect2(layout.get("confirm_rect", Rect2())),
		PerkFusionLocalization.text("confirm") if selected_sources.size() == 2 else PerkFusionLocalization.format("selected", [selected_sources.size()]),
		selected_sources.size() == 2,
		true
	)


func _draw_confirm(
	canvas: CanvasItem,
	snapshot: Dictionary,
	catalog: Object,
	layout: Dictionary,
	icon_renderer: Object
) -> void:
	var panel_rect: Rect2 = _as_rect2(layout.get("panel_rect", Rect2()))
	_draw_heading(canvas, panel_rect, PerkFusionLocalization.text("confirm_title"), PerkFusionLocalization.text("confirm_subtitle"))
	var selected_sources: Array = _selected_sources(snapshot)
	var source_previews: Array = _as_array(snapshot.get("source_previews", []))
	var pair_rects: Array = _as_array(layout.get("pair_rects", []))
	for pair_index in range(mini(2, mini(selected_sources.size(), pair_rects.size()))):
		var source_id := str(selected_sources[pair_index])
		_draw_candidate_card(
			canvas,
			source_id,
			_as_rect2(pair_rects[pair_index]),
			true,
			pair_index,
			catalog,
			icon_renderer,
			_find_source_preview(source_previews, source_id)
		)
	var probability_rect: Rect2 = _as_rect2(layout.get("probability_rect", Rect2()))
	_draw_probabilities(canvas, probability_rect, snapshot)
	_draw_text_centered(
		canvas,
		PerkFusionLocalization.text("irreversible"),
		Vector2(probability_rect.get_center().x, probability_rect.end.y - 13.0),
		13,
		Color(1.0, 0.58, 0.55, 1.0)
	)
	_draw_button(canvas, _as_rect2(layout.get("back_rect", Rect2())), PerkFusionLocalization.text("reselect"), true, false)
	_draw_button(canvas, _as_rect2(layout.get("confirm_rect", Rect2())), PerkFusionLocalization.text("commit"), true, true)


func _draw_probabilities(canvas: CanvasItem, rect: Rect2, snapshot: Dictionary) -> void:
	var probabilities: Dictionary = _get_probabilities(snapshot)
	var preview: Dictionary = _as_dict(snapshot.get("outcome_preview", {}))
	var core_stabilize_armed := bool(preview.get("core_stabilize_armed", false))
	var labels: Array[String] = [
		PerkFusionLocalization.text("prob_success"),
		PerkFusionLocalization.text("prob_core_stable" if core_stabilize_armed else "prob_side"),
		PerkFusionLocalization.text("prob_byproduct"),
	]
	var keys: Array[String] = ["success", "side_effect", "byproduct"]
	var side_color := Color(0.45, 0.90, 1.0) if core_stabilize_armed else Color(1.0, 0.48, 0.48)
	var colors: Array[Color] = [Color(0.39, 0.92, 0.73), side_color, GOLD_COLOR]
	var column_width: float = rect.size.x / 3.0
	for column in range(3):
		var percent: float = _as_percent(float(probabilities.get(keys[column], 0.0)))
		var center := Vector2(rect.position.x + column_width * (float(column) + 0.5), rect.position.y + 30.0)
		_draw_text_centered(canvas, labels[column], center, 14, colors[column])
		_draw_text_centered(canvas, "%d%%" % int(round(percent)), center + Vector2(0.0, 27.0), 22, Color.WHITE)


# CB3 degraded 폴백 계약: 콜드부트 호스트가 트리에서 부팅 중이면 비주얼은
# 호스트가 그리고(같은 프레임 이중 드로 방지), 여기 즉시모드는 호스트
# 부재/미프리웜에서만 그린다 — 무크래시 폴백.
func _draw_animation(
	canvas: CanvasItem,
	snapshot: Dictionary,
	catalog: Object,
	layout: Dictionary
) -> void:
	var panel_rect: Rect2 = _as_rect2(layout.get("panel_rect", Rect2()))
	_draw_heading(canvas, panel_rect, PerkFusionLocalization.text("animation_title"), PerkFusionLocalization.text("animation_subtitle"))
	if bool(snapshot.get("cold_boot_host_live", false)):
		return
	var result_rect: Rect2 = _as_rect2(layout.get("result_rect", Rect2()))
	var center: Vector2 = result_rect.get_center()
	var progress: float = _animation_progress(snapshot)
	var orbit_radius: float = minf(result_rect.size.x, result_rect.size.y) * 0.22 * (1.0 - progress)
	var selected_sources: Array = _selected_sources(snapshot)
	var left_name: String = _perk_name(catalog, str(selected_sources[0]) if selected_sources.size() > 0 else PerkFusionLocalization.text("material_a"))
	var right_name: String = _perk_name(catalog, str(selected_sources[1]) if selected_sources.size() > 1 else PerkFusionLocalization.text("material_b"))
	var left_center := center + Vector2(-orbit_radius, 0.0)
	var right_center := center + Vector2(orbit_radius, 0.0)
	var pulse: float = 0.5 + 0.5 * sin(progress * TAU * 4.0)
	canvas.draw_line(left_center, right_center, Color(0.32, 0.80, 1.0, 0.35 + 0.35 * progress), 3.0)
	canvas.draw_circle(left_center, 28.0 + 5.0 * pulse, Color(0.25, 0.73, 1.0, 0.75))
	canvas.draw_circle(right_center, 28.0 + 5.0 * (1.0 - pulse), Color(1.0, 0.64, 0.30, 0.75))
	for ring_index in range(3):
		var ring_radius: float = 42.0 + float(ring_index) * 22.0 + progress * 24.0
		canvas.draw_arc(
			center,
			ring_radius,
			-progress * TAU * (1.0 + float(ring_index) * 0.25),
			-progress * TAU * (1.0 + float(ring_index) * 0.25) + PI * 1.35,
			28,
			Color(0.34 + 0.16 * float(ring_index), 0.78, 1.0, 0.68 - float(ring_index) * 0.12),
			2.0
		)
	for spark_index in range(8):
		var angle: float = TAU * float(spark_index) / 8.0 + progress * TAU * 1.7
		var spark_pos: Vector2 = center + Vector2.from_angle(angle) * (62.0 + 26.0 * pulse)
		canvas.draw_circle(spark_pos, 2.0 + float(spark_index % 3), Color(0.76, 0.94, 1.0, 0.86))
	_draw_text_centered(canvas, left_name, center + Vector2(-145.0, 118.0), 14, MUTED_COLOR)
	_draw_text_centered(canvas, right_name, center + Vector2(145.0, 118.0), 14, MUTED_COLOR)
	_draw_text_centered(canvas, "%d%%" % int(round(progress * 100.0)), center + Vector2(0.0, 154.0), 18, Color.WHITE)
	_draw_text_centered(
		canvas,
		PerkFusionLocalization.text("skip"),
		_as_rect2(layout.get("confirm_rect", Rect2())).get_center(),
		13,
		MUTED_COLOR
	)


func _draw_reveal(
	canvas: CanvasItem,
	snapshot: Dictionary,
	catalog: Object,
	layout: Dictionary,
	icon_renderer: Object
) -> void:
	var record: Dictionary = _record(snapshot)
	var outcome: String = str(record.get("outcome", "success"))
	var panel_rect: Rect2 = _as_rect2(layout.get("panel_rect", Rect2()))
	var outcome_title: String = _outcome_title(outcome)
	var subtitle: String = PerkFusionLocalization.text("reveal_subtitle")
	if outcome == "stable":
		subtitle = PerkFusionLocalization.text("stable_subtitle")
	_draw_heading(canvas, panel_rect, outcome_title, subtitle)

	var result_rect: Rect2 = _as_rect2(layout.get("result_rect", Rect2()))
	var sources: Array = _as_array(record.get("sources", []))
	var source_names: Array[String] = []
	for source_value in sources.slice(0, mini(2, sources.size())):
		source_names.append(_perk_name(catalog, str(source_value)))
	var pair_text: String = " + ".join(source_names) if not source_names.is_empty() else PerkFusionLocalization.text("fusion_default")
	var icon_size := clampf(minf(result_rect.size.x, result_rect.size.y) * 0.16, 48.0, 76.0)
	var icon_rect := Rect2(
		Vector2(result_rect.get_center().x - icon_size * 0.5, result_rect.position.y + 10.0),
		Vector2(icon_size, icon_size)
	)
	canvas.draw_rect(icon_rect.grow(4.0), Color(0.025, 0.035, 0.07, 0.96), true)
	canvas.draw_rect(icon_rect.grow(4.0), GOLD_COLOR, false, 2.0)
	_draw_perk_icon(
		canvas,
		icon_renderer,
		PerkFusionIconKey.build(
			str(record.get("fusion_id", "")),
			int(record.get("created_revision", 0)),
			sources
		),
		icon_rect
	)
	_draw_text_centered(canvas, pair_text, Vector2(result_rect.get_center().x, icon_rect.end.y + 25.0), 21, Color.WHITE)

	var lines: Array[String] = _result_lines(record, outcome, catalog)
	var line_y: float = icon_rect.end.y + 55.0
	var max_visible_lines := mini(
		MAX_RESULT_LINES,
		maxi(1, int(floor((result_rect.end.y - line_y - 8.0) / 25.0)))
	)
	for line_index in range(mini(max_visible_lines, lines.size())):
		_draw_text_centered(
			canvas,
			_limit_line(lines[line_index], MAX_LINE_CHARS),
			Vector2(result_rect.get_center().x, line_y + float(line_index) * 25.0),
			15,
			GOLD_COLOR if lines[line_index].begins_with(PerkFusionLocalization.text("prob_byproduct")) else MUTED_COLOR
		)
	_draw_text_centered(
		canvas,
		PerkFusionLocalization.text("continue"),
		_as_rect2(layout.get("confirm_rect", Rect2())).get_center(),
		14,
		Color(0.86, 0.96, 1.0, 1.0)
	)


func _draw_candidate_card(
	canvas: CanvasItem,
	perk_id: String,
	rect: Rect2,
	highlighted: bool,
	selected_order: int,
	catalog: Object,
	icon_renderer: Object,
	preview: Dictionary = {}
) -> void:
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var selected: bool = selected_order >= 0
	var border_color: Color = GOLD_COLOR if selected else (ACCENT_COLOR if highlighted else Color(0.29, 0.38, 0.55, 0.9))
	var background_color := Color(0.11, 0.15, 0.24, 0.98) if highlighted else Color(0.075, 0.095, 0.16, 0.98)
	canvas.draw_rect(rect, background_color, true)
	if highlighted or selected:
		canvas.draw_rect(rect.grow(4.0), Color(border_color.r, border_color.g, border_color.b, 0.20), false, 3.0)
	canvas.draw_rect(rect, border_color, false, 2.5 if highlighted or selected else 1.4)
	if not preview.is_empty():
		_draw_candidate_preview(canvas, perk_id, rect, preview, catalog, icon_renderer)
		return
	var icon_size: float = clampf(minf(rect.size.y - 30.0, rect.size.x * 0.34), 24.0, 60.0)
	var icon_rect := Rect2(rect.position + Vector2(12.0, maxf(8.0, (rect.size.y - icon_size) * 0.5)), Vector2(icon_size, icon_size))
	canvas.draw_rect(icon_rect, Color(0.025, 0.035, 0.07, 0.96), true)
	canvas.draw_rect(icon_rect, Color(0.35, 0.72, 1.0, 0.65), false, 1.5)
	_draw_perk_icon(canvas, icon_renderer, perk_id, icon_rect.grow(-4.0))
	var name_x: float = icon_rect.end.x + 10.0
	var max_name_width: float = maxf(8.0, rect.end.x - name_x - 10.0)
	_draw_text_fitted(canvas, _perk_name(catalog, perk_id), Vector2(name_x, rect.position.y + rect.size.y * 0.49), 17, Color.WHITE, max_name_width)
	_draw_text_fitted(canvas, PerkFusionLocalization.text("max_level"), Vector2(name_x, rect.position.y + rect.size.y * 0.72), 12, MUTED_COLOR, max_name_width)
	if selected:
		var badge_center := rect.position + Vector2(rect.size.x - 17.0, 17.0)
		canvas.draw_circle(badge_center, 12.0, GOLD_COLOR)
		_draw_text_centered(canvas, str(selected_order + 1), badge_center + Vector2(0.0, -1.0), 13, Color(0.10, 0.08, 0.02, 1.0))


func _draw_candidate_preview(
	canvas: CanvasItem,
	perk_id: String,
	rect: Rect2,
	preview: Dictionary,
	catalog: Object,
	icon_renderer: Object
) -> void:
	var icon_size := clampf(rect.size.y * 0.27, 32.0, 46.0)
	var icon_rect := Rect2(rect.position + Vector2(12.0, 10.0), Vector2(icon_size, icon_size))
	canvas.draw_rect(icon_rect, Color(0.025, 0.035, 0.07, 0.96), true)
	_draw_perk_icon(canvas, icon_renderer, perk_id, icon_rect.grow(-3.0))
	var name_x := icon_rect.end.x + 8.0
	_draw_text_fitted(canvas, _perk_name(catalog, perk_id), Vector2(name_x, rect.position.y + 28.0), 15, Color.WHITE, rect.end.x - name_x - 10.0, 9)
	var base_level := int(preview.get("base_level", 0))
	var effective_level := int(preview.get("effective_level", base_level))
	var level_label := "Lv.%d" % base_level
	if effective_level != base_level:
		level_label += " → %d" % effective_level
	_draw_text_fitted(canvas, level_label, Vector2(name_x, rect.position.y + 48.0), 11, MUTED_COLOR, rect.end.x - name_x - 10.0, 8)

	var option_lines: Array[String] = []
	for option_value: Variant in _as_array(preview.get("options", [])):
		var option: Dictionary = _as_dict(option_value)
		option_lines.append(PerkFusionLocalization.option_preview(
			str(option.get("key", "option")),
			option.get("value", 0.0),
			str(option.get("polarity", "forward"))
		))
	if option_lines.is_empty():
		var description := str(preview.get("description", "")).strip_edges()
		if not description.is_empty():
			option_lines.append(description)
	var line_y := rect.position.y + 76.0
	var max_lines := maxi(1, int(floor((rect.end.y - line_y - 8.0) / 16.0)))
	for line_index in range(mini(max_lines, option_lines.size())):
		_draw_text_fitted(
			canvas,
			option_lines[line_index],
			Vector2(rect.position.x + 12.0, line_y + float(line_index) * 16.0),
			11,
			MUTED_COLOR,
			rect.size.x - 24.0,
			8
		)


func _find_source_preview(previews: Array, source_id: String) -> Dictionary:
	for preview_value: Variant in previews:
		var preview: Dictionary = _as_dict(preview_value)
		if str(preview.get("perk_id", "")) == source_id:
			return preview
	return {}


func _draw_button(canvas: CanvasItem, rect: Rect2, label: String, enabled: bool, primary: bool) -> void:
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var fill: Color = Color(0.10, 0.18, 0.30, 0.98)
	var border: Color = Color(0.42, 0.58, 0.76, 0.82)
	if primary:
		fill = Color(0.08, 0.31, 0.48, 0.98) if enabled else Color(0.09, 0.12, 0.18, 0.96)
		border = ACCENT_COLOR if enabled else Color(0.30, 0.36, 0.46, 0.7)
	canvas.draw_rect(rect, fill, true)
	canvas.draw_rect(rect, border, false, 2.0)
	_draw_text_centered(canvas, label, rect.get_center(), 14, Color.WHITE if enabled or not primary else MUTED_COLOR)


func _draw_heading(canvas: CanvasItem, panel_rect: Rect2, title: String, subtitle: String) -> void:
	_draw_text_centered(canvas, title, panel_rect.position + Vector2(panel_rect.size.x * 0.5, 30.0), 24, Color(0.88, 0.97, 1.0, 1.0))
	_draw_text_centered(canvas, subtitle, panel_rect.position + Vector2(panel_rect.size.x * 0.5, 58.0), 13, MUTED_COLOR)


func _get_probabilities(snapshot: Dictionary) -> Dictionary:
	var preview := _as_dict(snapshot.get("outcome_preview", {}))
	var weights := _as_dict(preview.get("weights", {}))
	if weights.is_empty():
		weights = PerkFusionOutcomeRules.build_final_outcome_weights(false)
	return {
		"success": weights.get(PerkFusionOutcomeRules.OUTCOME_SUCCESS, 0.0),
		"side_effect": weights.get(PerkFusionOutcomeRules.OUTCOME_SIDE_EFFECT, 0.0),
		"byproduct": weights.get(PerkFusionOutcomeRules.OUTCOME_BYPRODUCT, 0.0),
	}


func _animation_progress(snapshot: Dictionary) -> float:
	return clampf(
		1.0 - float(snapshot.get("animation_remaining", DEFAULT_ANIMATION_DURATION)) / DEFAULT_ANIMATION_DURATION,
		0.0,
		1.0
	)


func _selected_sources(snapshot: Dictionary) -> Array:
	var sources: Array = _as_array(snapshot.get("selected_source_ids", []))
	return sources.duplicate()


func _record(snapshot: Dictionary) -> Dictionary:
	return _as_dict(snapshot.get("committed_record", {}))


func _result_lines(record: Dictionary, outcome: String, catalog: Object = null) -> Array[String]:
	var lines: Array[String] = []
	match outcome:
		"stable":
			lines.append(PerkFusionLocalization.text("result_stable"))
		"success":
			lines.append(PerkFusionLocalization.text("result_success"))
		"side_effect":
			lines.append(PerkFusionLocalization.text("result_side"))
		"byproduct":
			lines.append(PerkFusionLocalization.text("result_byproduct"))
	var source_labels: Dictionary = {}
	for source_value: Variant in _as_array(record.get("sources", [])):
		var source_id := str(source_value)
		source_labels[source_id] = _perk_name(catalog, source_id)
	lines.append_array(PerkFusionLocalization.record_detail_lines(record, source_labels))
	if lines.is_empty():
		lines.append(PerkFusionLocalization.text("result_fallback"))
	return lines


func _outcome_title(outcome: String) -> String:
	match outcome:
		"stable":
			return PerkFusionLocalization.text("outcome_stable")
		"success":
			return PerkFusionLocalization.text("outcome_success")
		"side_effect":
			return PerkFusionLocalization.text("outcome_side")
		"byproduct":
			return PerkFusionLocalization.text("outcome_byproduct")
	return PerkFusionLocalization.text("outcome_complete")


func _perk_name(catalog: Object, perk_id: String) -> String:
	if catalog != null and catalog.has_method("get_perk_data"):
		var value: Variant = catalog.get_perk_data(perk_id)
		if value is Dictionary:
			var data: Dictionary = value
			var display_name: String = str(data.get("name", data.get("korean", ""))).strip_edges()
			if not display_name.is_empty():
				return display_name
	return perk_id if not perk_id.is_empty() else PerkFusionLocalization.text("unknown_perk")


func _draw_perk_icon(canvas: CanvasItem, icon_renderer: Object, perk_id: String, rect: Rect2) -> void:
	var drew_icon := false
	if icon_renderer != null and icon_renderer.has_method("draw_icon"):
		drew_icon = bool(icon_renderer.draw_icon(canvas, perk_id, rect, 1.0, true))
	if not drew_icon:
		canvas.draw_circle(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.32, Color(0.32, 0.78, 1.0, 0.86))
		canvas.draw_circle(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.15, Color(0.82, 0.96, 1.0, 0.96))


func _draw_text_fitted(
	canvas: CanvasItem,
	text: String,
	baseline: Vector2,
	font_size: int,
	color: Color,
	max_width: float,
	min_font_size: int = 10
) -> void:
	if text.is_empty() or max_width <= 1.0:
		return
	var fitted_text: String = text
	var fitted_size: int = font_size
	var font := _get_font()
	while fitted_size > min_font_size and font.get_string_size(fitted_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted_size).x > max_width:
		fitted_size -= 1
	if font.get_string_size(fitted_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted_size).x > max_width:
		fitted_text = _ellipsize(fitted_text, fitted_size, max_width)
	canvas.draw_string(font, baseline, fitted_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted_size, color)


func _draw_text_centered(canvas: CanvasItem, text: String, center: Vector2, font_size: int, color: Color) -> void:
	if text.is_empty():
		return
	var font := _get_font()
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	canvas.draw_string(font, center - Vector2(size.x * 0.5, -size.y * 0.34), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _ellipsize(text: String, font_size: int, max_width: float) -> String:
	var suffix := "..."
	var output: String = text
	var font := _get_font()
	while not output.is_empty():
		if font.get_string_size(output + suffix, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width:
			return output + suffix
		output = output.left(output.length() - 1)
	return suffix


func _get_font() -> Font:
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_KOREAN:
		return KOREAN_UI_FONT
	if _fallback_font == null:
		_fallback_font = ThemeDB.fallback_font
	return _fallback_font if _fallback_font != null else KOREAN_UI_FONT


func _limit_line(text: String, max_chars: int) -> String:
	if text.length() <= max_chars:
		return text
	return text.left(maxi(1, max_chars - 3)) + "..."


func _as_percent(value: float) -> float:
	return value * 100.0 if value >= 0.0 and value <= 1.0 else value


func _as_array(value: Variant) -> Array:
	return value if value is Array else []


func _as_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _as_rect2(value: Variant) -> Rect2:
	return value if value is Rect2 else Rect2()
