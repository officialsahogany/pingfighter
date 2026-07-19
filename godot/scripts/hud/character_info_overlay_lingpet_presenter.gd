extends RefCounted

const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const CharacterInfoOverlayLingpetSnapshotBuilder := preload("res://scripts/hud/character_info_overlay_lingpet_snapshot_builder.gd")
const CharacterInfoOverlayLingpetVitalityProjection := preload("res://scripts/hud/character_info_overlay_lingpet_vitality_projection.gd")
const CharacterInfoOverlayLingpetTextureLoader := preload("res://scripts/hud/character_info_overlay_lingpet_texture_loader.gd")
const CharacterInfoOverlayStatsPresenter := preload("res://scripts/hud/character_info_overlay_stats_presenter.gd")
const CharacterInfoOverlayTextLineCache := preload("res://scripts/hud/character_info_overlay_text_line_cache.gd")
const CharacterInfoOverlayTextureDrawer := preload("res://scripts/hud/character_info_overlay_texture_drawer.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetRingCoreRules := preload("res://scripts/lingpet/lingpet_ring_core_rules.gd")

const PANEL_LIVE2D_COLS_BY_PET_ID := {
	"lunabi": 14,
	"nekuring": 14,
	"monkeyring": 14,
	"onimaru": 14,
	"orosha": 14,
	"rahoset": 14,
}
const PANEL_LIVE2D_ROWS_BY_PET_ID := {
	"lunabi": 7,
	"nekuring": 7,
	"monkeyring": 7,
	"onimaru": 7,
	"orosha": 7,
	"rahoset": 7,
}
const PANEL_LIVE2D_FRAME_COUNT_BY_PET_ID := {
	"lunabi": 98,
	"nekuring": 98,
	"monkeyring": 98,
	"onimaru": 98,
	"orosha": 98,
	"rahoset": 98,
}
const PANEL_LIVE2D_FRAME_INTERVAL_BY_PET_ID := {
	"lunabi": 1.0 / 16.0,
	"nekuring": 1.0 / 16.0,
	"monkeyring": 1.0 / 16.0,
	"onimaru": 1.0 / 16.0,
	"orosha": 1.0 / 16.0,
	"rahoset": 1.0 / 16.0,
}
const AFFINITY_BAND_HEIGHT := 50.0
const AFFINITY_METER_HEIGHT := 8.0
# Vertical split of the affinity band into the two hover zones: the top slice
# (label + affinity meter + "다음:" row) belongs to the 교감 tooltip, everything
# below to the 포만도 strip tooltip. The satiety strip starts at +30 (see
# _get_satiety_strip_layout), so 28 keeps the two hover rects from overlapping.
const AFFINITY_HOVER_BAND_HEIGHT := 28.0
const SATIETY_METER_HEIGHT := 8.0
const SATIETY_METER_GAP := 4.0
const SATIETY_WARNING_THRESHOLD := 50
const SATIETY_CRITICAL_THRESHOLD := 20
const RING_CORE_ROW_HEIGHT := 64.0
const UNLOCK_CHOICE_BAND_MIN_HEIGHT := 54.0
const UNLOCK_CHOICE_BAND_MAX_HEIGHT := 76.0

static func draw_panel(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	snapshot: Dictionary,
	mouse_pos: Vector2,
	hover_data: Dictionary,
	skill_icon_rects: Array,
	unlock_options: Array,
	unlock_card_rects: Array,
	ring_core_rects: Array,
	slot_tab_rects: Array,
	art_texture_cache: Dictionary,
	skill_icon_texture_cache: Dictionary,
	empty_ring_texture: Texture2D,
	section_color: Color,
	section_border: Color,
	grid_fill: Color,
	stat_buff_color: Color,
	empty_text_color: Color,
	accent_blue: Color,
	accent_gold: Color,
	text_soft: Color,
	slot_fill: Color,
	ring_segments: int,
	ui_text_scale: float,
	wrap_text_callable: Callable,
	hatch_required_hits: int,
	panel_animation_time: float = 0.0
) -> Dictionary:
	skill_icon_rects.clear()
	unlock_card_rects.clear()
	ring_core_rects.clear()
	slot_tab_rects.clear()
	CharacterInfoOverlayTextureDrawer.draw_section_chrome(canvas, rect, section_color, section_border, accent_blue)
	_draw_paw_icon(canvas, Vector2(rect.position.x + 24.0, rect.position.y + 18.0), 13.0, Color(0.92, 0.96, 1.0, 0.95))
	_draw_text_xy(canvas, font, "링펫", rect.position.x + 36.0, rect.position.y + 24.0, 13, text_soft, ui_text_scale)
	_draw_lingpet_slot_tabs(canvas, font, rect, snapshot, slot_tab_rects, accent_blue, slot_fill, empty_text_color, text_soft, ui_text_scale)
	var content_rect := Rect2(rect.position.x + 12.0, rect.position.y + 36.0, rect.size.x - 24.0, rect.size.y - 48.0)
	canvas.draw_rect(content_rect, grid_fill)
	var state: String = str(snapshot.get("state", "none"))
	if state == "companion":
		return draw_companion_panel(canvas, font, content_rect, snapshot, mouse_pos, hover_data, skill_icon_rects, unlock_options, unlock_card_rects, ring_core_rects, art_texture_cache, skill_icon_texture_cache, stat_buff_color, empty_text_color, accent_blue, slot_fill, ring_segments, ui_text_scale, panel_animation_time)
	draw_non_companion_panel(canvas, font, content_rect, snapshot, hatch_required_hits, stat_buff_color, empty_text_color, accent_gold, text_soft, ring_segments, ui_text_scale, wrap_text_callable, empty_ring_texture)
	return hover_data


static func draw_egg_icon(canvas: CanvasItem, rect: Rect2, state: String, progress: float, stat_buff_color: Color, empty_text_color: Color, ring_segments: int, ui_text_scale: float) -> void:
	var center := rect.get_center()
	var rx: float = rect.size.x * 0.34
	var ry: float = rect.size.y * 0.43
	var egg_color := Color(1.0, 170.0 / 255.0, 218.0 / 255.0, 0.28)
	var ring_color := Color(85.0 / 255.0, 218.0 / 255.0, 1.0, 0.82)
	if state == "companion":
		egg_color = Color(105.0 / 255.0, 245.0 / 255.0, 170.0 / 255.0, 0.24)
		ring_color = stat_buff_color
	for i in range(5, 0, -1):
		canvas.draw_circle(center, max(rx, ry) + float(i) * 3.0, Color(ring_color.r, ring_color.g, ring_color.b, 0.018 * float(i)))
	var egg_points := PackedVector2Array()
	for point_index in range(18):
		var angle: float = TAU * float(point_index) / 18.0
		egg_points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	canvas.draw_colored_polygon(egg_points, egg_color)
	canvas.draw_arc(center, max(rx, ry) * 0.84, 0.0, TAU, ring_segments, ring_color, 2.0)
	canvas.draw_circle(center + Vector2(-rx * 0.24, -ry * 0.22), max(2.0, rx * 0.09), Color(1.0, 1.0, 1.0, 0.58))
	if state == "egg" and progress > 0.0:
		var crack_color := Color(1.0, 245.0 / 255.0, 170.0 / 255.0, 0.88)
		var crack_bottom: float = center.y - ry * 0.2 + ry * 0.95 * progress
		canvas.draw_polyline(PackedVector2Array([
			center + Vector2(-rx * 0.08, -ry * 0.62),
			center + Vector2(rx * 0.10, -ry * 0.30),
			center + Vector2(-rx * 0.02, -ry * 0.06),
			Vector2(center.x + rx * 0.18, crack_bottom),
		]), crack_color, 1.8)
	elif state == "none":
		var none_rect := rect.grow(-8.0)
		var none_line_color := Color(empty_text_color.r, empty_text_color.g, empty_text_color.b, 0.32)
		canvas.draw_line(none_rect.position + Vector2(9.0, 9.0), none_rect.end - Vector2(9.0, 9.0), none_line_color, 1.4)
		canvas.draw_line(Vector2(none_rect.end.x - 9.0, none_rect.position.y + 9.0), Vector2(none_rect.position.x + 9.0, none_rect.end.y - 9.0), none_line_color, 1.4)
	else:
		_draw_centered_fallback_text(canvas, "M", center.x, center.y + 4.0, int(rect.size.x * 0.30), Color.WHITE, ui_text_scale)


static func _draw_paw_icon(canvas: CanvasItem, center: Vector2, size: float, color: Color) -> void:
	canvas.draw_circle(center + Vector2(0.0, size * 0.16), size * 0.36, color)
	canvas.draw_circle(center + Vector2(-size * 0.36, -size * 0.14), size * 0.16, color)
	canvas.draw_circle(center + Vector2(-size * 0.13, -size * 0.34), size * 0.17, color)
	canvas.draw_circle(center + Vector2(size * 0.13, -size * 0.34), size * 0.17, color)
	canvas.draw_circle(center + Vector2(size * 0.36, -size * 0.14), size * 0.16, color)


static func draw_non_companion_panel(
	canvas: CanvasItem,
	font: Font,
	content_rect: Rect2,
	snapshot: Dictionary,
	hatch_required_hits: int,
	stat_buff_color: Color,
	empty_text_color: Color,
	accent_gold: Color,
	text_soft: Color,
	ring_segments: int,
	ui_text_scale: float,
	wrap_text_callable: Callable,
	empty_ring_texture: Texture2D = null
) -> void:
	var state: String = str(snapshot.get("state", "none"))
	var hits: int = int(snapshot.get("hatch_hits", 0))
	var required_hits: int = max(1, int(snapshot.get("required_hits", hatch_required_hits)))
	var progress: float = clamp(float(hits) / float(required_hits), 0.0, 1.0)
	var compact: bool = content_rect.size.x < 260.0 or content_rect.size.y < 145.0
	if state == "none" and empty_ring_texture != null and not compact:
		# No-egg hero layout (mockup): centered text block on top, the large
		# unhatched crystal egg filling the space below.
		var none_center_x: float = content_rect.get_center().x
		var none_title: String = str(snapshot.get("title", "링펫 없음"))
		var none_subtitle: String = str(snapshot.get("subtitle", "미해금"))
		var none_body: String = str(snapshot.get("body", ""))
		_draw_centered_text(canvas, font, none_title, none_center_x, content_rect.position.y + 30.0, 16, Color.WHITE, ui_text_scale)
		_draw_centered_text(canvas, font, none_subtitle, none_center_x, content_rect.position.y + 52.0, 12, text_soft, ui_text_scale)
		var none_body_lines_value: Variant = wrap_text_callable.call(font, LanguageSettings.translate_text(none_body), 11, content_rect.size.x - 40.0, 3)
		var none_body_lines: Array = none_body_lines_value if none_body_lines_value is Array else []
		for i in range(none_body_lines.size()):
			_draw_centered_text(canvas, font, str(none_body_lines[i]), none_center_x, content_rect.position.y + 78.0 + float(i) * 18.0, 11, empty_text_color, ui_text_scale)
		var none_art_top: float = content_rect.position.y + 86.0 + float(none_body_lines.size()) * 18.0
		var none_art_rect := Rect2(content_rect.position.x + 20.0, none_art_top, content_rect.size.x - 40.0, maxf(60.0, content_rect.end.y - none_art_top - 10.0))
		CharacterInfoOverlayTextureDrawer.draw_contained(canvas, empty_ring_texture, none_art_rect, Color(1.0, 1.0, 1.0, 0.95))
		return
	var icon_size: float = clamp(min(content_rect.size.x * (0.36 if not compact else 0.28), content_rect.size.y * 0.54), 38.0, 82.0)
	var icon_rect: Rect2
	var text_x: float
	var text_y: float
	var text_w: float
	if compact:
		icon_rect = Rect2(content_rect.position.x + 10.0, content_rect.position.y + 10.0, icon_size, icon_size)
		text_x = icon_rect.end.x + 10.0
		text_y = content_rect.position.y + 23.0
		text_w = max(96.0, content_rect.end.x - text_x - 10.0)
	else:
		icon_rect = Rect2(content_rect.position.x + 16.0, content_rect.position.y + content_rect.size.y * 0.5 - icon_size * 0.5, icon_size, icon_size)
		text_x = icon_rect.end.x + 18.0
		text_y = content_rect.position.y + 36.0
		text_w = max(120.0, content_rect.end.x - text_x - 12.0)
	if state == "none" and empty_ring_texture != null:
		var hero_rect: Rect2 = icon_rect.grow(icon_size * 0.44)
		CharacterInfoOverlayTextureDrawer.draw_contained(canvas, empty_ring_texture, hero_rect, Color(1.0, 1.0, 1.0, 0.92))
	else:
		draw_egg_icon(canvas, icon_rect, state, progress, stat_buff_color, empty_text_color, ring_segments, ui_text_scale)

	var title: String = str(snapshot.get("title", "링펫 없음"))
	var subtitle: String = str(snapshot.get("subtitle", "미해금"))
	var body: String = str(snapshot.get("body", ""))
	_draw_text_xy(canvas, font, title, text_x, text_y, 15, Color.WHITE, ui_text_scale)
	_draw_text_xy(canvas, font, subtitle, text_x, text_y + 24.0, 12, accent_gold if state == "egg" else text_soft, ui_text_scale)
	var body_lines_value: Variant = wrap_text_callable.call(font, LanguageSettings.translate_text(body), 11, text_w, 4)
	var body_lines: Array = body_lines_value if body_lines_value is Array else []
	for i in range(body_lines.size()):
		_draw_text_xy(canvas, font, str(body_lines[i]), text_x, text_y + 48.0 + float(i) * 18.0, 11, empty_text_color, ui_text_scale)
	if state == "egg":
		var meter_rect := Rect2(text_x, min(content_rect.end.y - 24.0, text_y + 94.0), text_w, 8.0)
		canvas.draw_rect(meter_rect, Color(8.0 / 255.0, 12.0 / 255.0, 20.0 / 255.0, 0.96))
		canvas.draw_rect(Rect2(meter_rect.position, Vector2(meter_rect.size.x * clamp(progress, 0.0, 1.0), meter_rect.size.y)), Color(85.0 / 255.0, 218.0 / 255.0, 1.0, 0.82))
		canvas.draw_rect(meter_rect, Color(85.0 / 255.0, 218.0 / 255.0, 1.0, 0.85), false, 1.0)


static func draw_companion_panel(
	canvas: CanvasItem,
	font: Font,
	content_rect: Rect2,
	snapshot: Dictionary,
	mouse_pos: Vector2,
	hover_data: Dictionary,
	skill_icon_rects: Array,
	unlock_options: Array,
	unlock_card_rects: Array,
	ring_core_rects: Array,
	art_texture_cache: Dictionary,
	skill_icon_texture_cache: Dictionary,
	stat_buff_color: Color,
	empty_text_color: Color,
	accent_blue: Color,
	slot_fill: Color,
	ring_segments: int,
	ui_text_scale: float,
	panel_animation_time: float = 0.0
) -> Dictionary:
	var title: String = str(snapshot.get("title", "링펫"))
	var subtitle: String = str(snapshot.get("subtitle", "동행 중"))
	var pet_id := str(snapshot.get("pet_id", "")).strip_edges().to_lower()
	var skill_specs: Array = get_skill_specs(snapshot, stat_buff_color)
	var skill_row_h: float = clamp(content_rect.size.y * 0.22, 58.0, 78.0)
	var affinity_band_h: float = AFFINITY_BAND_HEIGHT
	var ring_core_row_h: float = RING_CORE_ROW_HEIGHT
	var open_unlock_option := _first_open_unlock_option(unlock_options)
	var open_unlock_count := _count_open_unlock_options(unlock_options)
	var unlock_band_h: float = 0.0
	if not open_unlock_option.is_empty():
		unlock_band_h = clamp(content_rect.size.y * 0.18, UNLOCK_CHOICE_BAND_MIN_HEIGHT, UNLOCK_CHOICE_BAND_MAX_HEIGHT)
	var title_y: float = content_rect.position.y + 26.0
	_draw_centered_text(canvas, font, title, content_rect.get_center().x, title_y, 18, Color.WHITE, ui_text_scale)
	_draw_centered_text(canvas, font, subtitle, content_rect.get_center().x, title_y + 23.0, 12, stat_buff_color, ui_text_scale)

	var art_rect: Rect2 = companion_art_rect(content_rect, skill_row_h + unlock_band_h + ring_core_row_h, affinity_band_h)
	canvas.draw_rect(art_rect, Color(7.0 / 255.0, 15.0 / 255.0, 25.0 / 255.0, 0.34))
	var aurora_texture: Texture2D = CharacterInfoOverlayLingpetTextureLoader.get_cached_panel_aurora_texture(art_texture_cache)
	if aurora_texture != null:
		_draw_aurora_backdrop(canvas, art_rect, aurora_texture, panel_animation_time)
	var art_texture: Texture2D = CharacterInfoOverlayLingpetTextureLoader.get_cached_art_texture(str(snapshot.get("pet_id", "")), art_texture_cache)
	if art_texture != null:
		if CharacterInfoOverlayLingpetTextureLoader.uses_panel_live2d_art(pet_id):
			draw_panel_live2d_art(canvas, art_texture, art_rect.grow(-4.0), pet_id, panel_animation_time)
		else:
			CharacterInfoOverlayTextureDrawer.draw_contained(canvas, art_texture, art_rect.grow(-4.0), Color(1.0, 1.0, 1.0, 0.96))
	else:
		var static_art_texture: Texture2D = CharacterInfoOverlayLingpetTextureLoader.get_cached_static_art_texture(str(snapshot.get("pet_id", "")), art_texture_cache)
		if static_art_texture != null:
			CharacterInfoOverlayTextureDrawer.draw_contained(canvas, static_art_texture, art_rect.grow(-4.0), Color(1.0, 1.0, 1.0, 0.96))
		else:
			draw_egg_icon(canvas, Rect2(art_rect.get_center() - Vector2(44.0, 44.0), Vector2(88.0, 88.0)), "companion", 1.0, stat_buff_color, empty_text_color, ring_segments, ui_text_scale)

	var affinity_rect := Rect2(art_rect.position.x, art_rect.end.y + 4.0, art_rect.size.x, max(24.0, affinity_band_h - 10.0))
	hover_data = draw_affinity_status(canvas, font, affinity_rect, snapshot, stat_buff_color, empty_text_color, accent_blue, ui_text_scale, mouse_pos, hover_data)
	var ring_core_row_rect := Rect2(affinity_rect.position.x, affinity_rect.end.y + 4.0, affinity_rect.size.x, ring_core_row_h)
	hover_data = _draw_lingpet_ring_core_row(canvas, font, ring_core_row_rect, snapshot, mouse_pos, hover_data, ring_core_rects, skill_icon_texture_cache, stat_buff_color, empty_text_color, accent_blue, slot_fill, ring_segments, ui_text_scale)

	var icon_count: int = max(1, skill_specs.size())
	var icon_gap: float = 9.0
	var icon_size: float = clamp((content_rect.size.x - 24.0 - icon_gap * float(icon_count - 1)) / float(icon_count), 38.0, 58.0)
	var icon_total_w: float = icon_size * float(icon_count) + icon_gap * float(icon_count - 1)
	var icon_x: float = content_rect.get_center().x - icon_total_w * 0.5
	var icon_y: float = content_rect.end.y - skill_row_h + (skill_row_h - icon_size) * 0.48
	if not open_unlock_option.is_empty():
		var unlock_rect := Rect2(art_rect.position.x, ring_core_row_rect.end.y + 4.0, art_rect.size.x, max(0.0, icon_y - ring_core_row_rect.end.y - 8.0))
		if unlock_rect.size.y >= 42.0:
			hover_data = draw_unlock_choice_band(canvas, font, unlock_rect, pet_id, open_unlock_option, maxi(0, open_unlock_count - 1), mouse_pos, hover_data, skill_icon_rects, unlock_card_rects, skill_icon_texture_cache, stat_buff_color, accent_blue, slot_fill, ring_segments, ui_text_scale)
	for i in range(skill_specs.size()):
		var icon_rect := Rect2(icon_x + float(i) * (icon_size + icon_gap), icon_y, icon_size, icon_size)
		skill_icon_rects.append(icon_rect)
		var spec: Dictionary = skill_specs[i]
		hover_data = draw_skill_icon(canvas, font, icon_rect, spec, mouse_pos, hover_data, skill_icon_texture_cache, accent_blue, slot_fill, ring_segments, ui_text_scale)
	return hover_data


static func draw_unlock_choice_band(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	pet_id: String,
	option: Dictionary,
	waiting_count: int,
	mouse_pos: Vector2,
	hover_data: Dictionary,
	skill_icon_rects: Array,
	unlock_card_rects: Array,
	skill_icon_texture_cache: Dictionary,
	stat_buff_color: Color,
	accent_blue: Color,
	slot_fill: Color,
	ring_segments: int,
	ui_text_scale: float
) -> Dictionary:
	var choice_key := str(option.get("choice_key", "")).strip_edges().to_lower()
	var candidates: Array = option.get("candidates", []) as Array
	if choice_key == "" or candidates.size() < 2:
		return hover_data
	var title := LanguageSettings.translate_text(_unlock_choice_title(choice_key))
	if waiting_count > 0:
		title = "%s · %s" % [title, LanguageSettings.translate_text("+%d 대기") % waiting_count]
	_draw_text_xy(canvas, font, title, rect.position.x + 2.0, rect.position.y + 13.0, 9, Color(1.0, 1.0, 1.0, 0.78), ui_text_scale)
	var visible_candidates: int = mini(2, candidates.size())
	var gap := 8.0
	var card_y := rect.position.y + 18.0
	var card_h: float = max(24.0, rect.end.y - card_y)
	var card_w: float = max(54.0, (rect.size.x - gap * float(visible_candidates - 1)) / float(visible_candidates))
	for i in range(visible_candidates):
		var candidate_id := str(candidates[i]).strip_edges().to_lower()
		var card_rect := Rect2(rect.position.x + float(i) * (card_w + gap), card_y, card_w, card_h)
		unlock_card_rects.append({
			"rect": card_rect,
			"pet_id": pet_id,
			"choice_key": choice_key,
			"candidate_id": candidate_id,
		})
		skill_icon_rects.append(card_rect)
		hover_data = draw_unlock_candidate_card(canvas, font, card_rect, pet_id, choice_key, candidate_id, mouse_pos, hover_data, skill_icon_texture_cache, stat_buff_color, accent_blue, slot_fill, ring_segments, ui_text_scale)
	return hover_data


static func draw_unlock_candidate_card(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	pet_id: String,
	choice_key: String,
	candidate_id: String,
	mouse_pos: Vector2,
	hover_data: Dictionary,
	skill_icon_texture_cache: Dictionary,
	stat_buff_color: Color,
	accent_blue: Color,
	slot_fill: Color,
	ring_segments: int,
	ui_text_scale: float
) -> Dictionary:
	var spec: Dictionary = _unlock_candidate_spec(pet_id, choice_key, candidate_id, stat_buff_color, accent_blue)
	var color: Color = _get_color(spec.get("color", accent_blue), accent_blue)
	var hovered: bool = rect.has_point(mouse_pos)
	canvas.draw_rect(rect, slot_fill)
	canvas.draw_rect(rect, Color(color.r, color.g, color.b, 0.95 if hovered else 0.58), false, 2.0 if hovered else 1.0)
	var icon_size: float = min(rect.size.y - 8.0, 36.0)
	var icon_rect := Rect2(rect.position.x + 5.0, rect.position.y + (rect.size.y - icon_size) * 0.5, icon_size, icon_size)
	var texture_path := str(spec.get("card_texture_path" if bool(spec.get("use_card", false)) else "icon_texture_id", "")).strip_edges()
	var texture: Texture2D = CharacterInfoOverlayLingpetTextureLoader.get_skill_icon_texture(texture_path, skill_icon_texture_cache)
	if texture != null and bool(spec.get("use_card", false)):
		CharacterInfoOverlayTextureDrawer.draw_cover(canvas, texture, icon_rect, Color(1.0, 1.0, 1.0, 0.94))
	elif texture != null:
		CharacterInfoOverlayTextureDrawer.draw_contained(canvas, texture, icon_rect, Color(1.0, 1.0, 1.0, 0.96))
	else:
		_draw_skill_symbol(canvas, font, icon_rect, candidate_id, color, ring_segments, ui_text_scale)
	var text_x := icon_rect.end.x + 6.0
	var text_w: float = max(20.0, rect.end.x - text_x - 5.0)
	_draw_text_xy(canvas, font, _fit_text_to_width(font, str(spec.get("title", candidate_id)), 9, text_w, ui_text_scale), text_x, rect.position.y + 16.0, 9, Color.WHITE, ui_text_scale)
	_draw_text_xy(canvas, font, _fit_text_to_width(font, str(spec.get("subtitle", "")), 8, text_w, ui_text_scale), text_x, rect.position.y + 31.0, 8, Color(color.r, color.g, color.b, 0.90), ui_text_scale)
	if hovered:
		_fill_hover_data(hover_data, str(spec.get("title", "")), str(spec.get("subtitle", "")), str(spec.get("body", "")), color, rect)
	return hover_data


static func companion_art_rect(content_rect: Rect2, skill_row_h: float, affinity_band_h: float = 0.0) -> Rect2:
	return Rect2(content_rect.position.x + 10.0, content_rect.position.y + 44.0, content_rect.size.x - 20.0, max(82.0, content_rect.size.y - skill_row_h - 54.0 - maxf(0.0, affinity_band_h)))


static func merge_runtime_satiety_snapshot(panel_snapshot: Dictionary, runtime_snapshot: Dictionary) -> Dictionary:
	# 사후 리팩토링 정합: 포만도 병합은 프로젝션 모듈이 단일 소유(씰 계약).
	return CharacterInfoOverlayLingpetVitalityProjection.merge_runtime_snapshot(panel_snapshot, runtime_snapshot)


static func get_satiety_strip_state(snapshot: Dictionary) -> Dictionary:
	# 사후 리팩토링 정합: 스트립 상태 판정은 프로젝션 모듈이 단일 소유(씰 계약).
	return CharacterInfoOverlayLingpetVitalityProjection.get_strip_state(snapshot)


static func get_satiety_strip_layout_for_tests(font: Font, rect: Rect2, snapshot: Dictionary, ui_text_scale: float) -> Dictionary:
	return _get_satiety_strip_layout(font, rect, get_satiety_strip_state(snapshot), ui_text_scale)


static func lingpet_progress_meter_width(rect: Rect2) -> float:
	# Single source of truth for the 교감 and 포만 meter length. Both bars use
	# this so they share an identical left edge + width and read as one tidy
	# stack; their right-side annotations ("다음: …" / "포만도 …") then line up in
	# the same column too. Changing the affinity meter span here keeps satiety
	# in lockstep automatically.
	return clampf(rect.size.x * 0.50, 78.0, maxf(78.0, rect.size.x - 118.0))


static func _get_satiety_strip_layout(font: Font, rect: Rect2, satiety_state: Dictionary, ui_text_scale: float) -> Dictionary:
	if not bool(satiety_state.get("visible", false)):
		return {}
	var label_text := str(satiety_state.get("label", ""))
	var strip_y: float = rect.position.y + 18.0 + AFFINITY_METER_HEIGHT + SATIETY_METER_GAP
	var baseline_y: float = strip_y + 8.0
	# Align the 포만 meter to the exact span of the 교감 meter above it, then place
	# the "포만도" label + value in the same right-hand annotation column the 교감
	# "다음:" text uses, so the two bars stack cleanly instead of staggering.
	var meter_w: float = lingpet_progress_meter_width(rect)
	var meter_rect := Rect2(rect.position.x, strip_y, meter_w, SATIETY_METER_HEIGHT)
	var annot_x: float = meter_rect.end.x + 8.0
	var label_w: float = _text_size(font, label_text, 9, ui_text_scale).x
	var label_rect := Rect2(annot_x, strip_y - 1.0, label_w, SATIETY_METER_HEIGHT + 3.0)
	var value_x: float = label_rect.end.x + 5.0 * ui_text_scale
	var value_w: float = maxf(10.0, rect.end.x - value_x)
	var value_rect := Rect2(value_x, strip_y - 1.0, value_w, SATIETY_METER_HEIGHT + 3.0)
	return {
		"label_rect": label_rect,
		"meter_rect": meter_rect,
		"value_rect": value_rect,
		"baseline_y": baseline_y,
	}


static func _satiety_strip_color(satiety_state: Dictionary, stat_buff_color: Color) -> Color:
	match str(satiety_state.get("color_key", "normal")):
		"critical":
			return Color(1.0, 64.0 / 255.0, 82.0 / 255.0, 0.94)
		"warning":
			return Color(1.0, 206.0 / 255.0, 80.0 / 255.0, 0.92)
	return Color(stat_buff_color.r, stat_buff_color.g, stat_buff_color.b, 0.88)


# Single source for the two bar hover zones inside the affinity band, so the
# draw path and the regression smoke agree. The 교감 zone is the top slice; the
# 포만도 zone is everything below it. They abut at AFFINITY_HOVER_BAND_HEIGHT and
# never overlap (has_point is half-open, so the seam belongs to 포만도).
static func affinity_bar_hover_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position.x, rect.position.y, rect.size.x, AFFINITY_HOVER_BAND_HEIGHT)


static func satiety_bar_hover_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position.x, rect.position.y + AFFINITY_HOVER_BAND_HEIGHT, rect.size.x, maxf(12.0, rect.size.y - AFFINITY_HOVER_BAND_HEIGHT))


static func draw_affinity_status(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	snapshot: Dictionary,
	stat_buff_color: Color,
	empty_text_color: Color,
	accent_blue: Color,
	ui_text_scale: float,
	mouse_pos: Vector2 = Vector2.INF,
	hover_data: Dictionary = {}
) -> Dictionary:
	var level := int(snapshot.get("affinity_level", 0))
	var points := maxf(0.0, float(snapshot.get("affinity_points", 0.0)))
	var requirement := maxf(0.0, float(snapshot.get("affinity_next_requirement", 0.0)))
	var next_label := str(snapshot.get("affinity_next_label", "")).strip_edges()
	var maxed := requirement <= 0.0 and level > 0
	var progress: float = 1.0 if maxed else clampf(points / maxf(1.0, requirement), 0.0, 1.0)
	# Composed/measured strings are translated here (not only inside
	# _draw_text_xy) so exact-map lookups still match and the right-aligned
	# width is measured on the same text that gets drawn.
	var level_text := LanguageSettings.translate_text("교감 Lv.%d") % level
	var value_text := LanguageSettings.translate_text(next_label) if maxed and next_label != "" else "%d / %d" % [int(round(points)), int(round(requirement))]
	var value_w := _text_size(font, value_text, 11, ui_text_scale).x
	_draw_text_xy(canvas, font, level_text, rect.position.x, rect.position.y + 11.0, 11, Color.WHITE, ui_text_scale)
	_draw_text_xy(canvas, font, value_text, rect.end.x - value_w, rect.position.y + 11.0, 11, stat_buff_color if maxed else empty_text_color, ui_text_scale)

	var meter_w: float = lingpet_progress_meter_width(rect)
	var meter_rect := Rect2(rect.position.x, rect.position.y + 18.0, meter_w, AFFINITY_METER_HEIGHT)
	canvas.draw_rect(meter_rect, Color(8.0 / 255.0, 12.0 / 255.0, 20.0 / 255.0, 0.96))
	canvas.draw_rect(Rect2(meter_rect.position, Vector2(meter_rect.size.x * progress, meter_rect.size.y)), Color(1.0, 112.0 / 255.0, 188.0 / 255.0, 0.82))
	canvas.draw_rect(meter_rect, Color(1.0, 112.0 / 255.0, 188.0 / 255.0, 0.86), false, 1.0)
	var next_text := LanguageSettings.translate_text(next_label) if maxed else LanguageSettings.translate_text("다음: %s") % LanguageSettings.translate_text(next_label)
	if next_label == "":
		next_text = LanguageSettings.translate_text("다음 보상 준비 중")
	var next_x := meter_rect.end.x + 8.0
	var next_w := maxf(10.0, rect.end.x - next_x)
	_draw_text_xy(canvas, font, _fit_text_to_width(font, next_text, 10, next_w, ui_text_scale), next_x, rect.position.y + 26.0, 10, accent_blue if maxed else empty_text_color, ui_text_scale)

	var satiety_state := get_satiety_strip_state(snapshot)
	var satiety_layout := _get_satiety_strip_layout(font, rect, satiety_state, ui_text_scale)
	if not satiety_layout.is_empty():
		var satiety_color := _satiety_strip_color(satiety_state, stat_buff_color)
		var satiety_meter_rect: Rect2 = satiety_layout.get("meter_rect", Rect2())
		var satiety_progress := clampf(float(satiety_state.get("pct", 0)) / 100.0, 0.0, 1.0)
		var exhaustion_ratio := clampf(float(satiety_state.get("ratio", 0.0)), 0.0, 1.0)
		canvas.draw_rect(satiety_meter_rect, Color(8.0 / 255.0, 12.0 / 255.0, 20.0 / 255.0, 0.96))
		canvas.draw_rect(Rect2(satiety_meter_rect.position, Vector2(satiety_meter_rect.size.x * satiety_progress, satiety_meter_rect.size.y)), satiety_color)
		if exhaustion_ratio > 0.0:
			canvas.draw_rect(satiety_meter_rect.grow(1.0), Color(1.0, 64.0 / 255.0, 82.0 / 255.0, 0.18 + 0.20 * exhaustion_ratio), false, 1.0)
		canvas.draw_rect(satiety_meter_rect, satiety_color, false, 1.0)
		var label_rect: Rect2 = satiety_layout.get("label_rect", Rect2())
		var value_rect: Rect2 = satiety_layout.get("value_rect", Rect2())
		var baseline_y: float = float(satiety_layout.get("baseline_y", satiety_meter_rect.end.y))
		if label_rect.size.x > 1.0:
			_draw_text_xy(canvas, font, _fit_text_to_width(font, str(satiety_state.get("label", "")), 9, label_rect.size.x, ui_text_scale), label_rect.position.x, baseline_y, 9, empty_text_color, ui_text_scale)
		_draw_text_xy(canvas, font, _fit_text_to_width(font, str(satiety_state.get("value", "")), 9, value_rect.size.x, ui_text_scale), value_rect.position.x, baseline_y, 9, satiety_color, ui_text_scale)

	# Hover tooltips for the two bars, mirroring the stat-row / ring-core hover
	# contract (_fill_hover_data clears + sets, so the last matching rect wins).
	# The 교감 band is the top slice (label + meter + "다음:" row); the 포만도 band
	# is the strip below it. The two rects never overlap, so at most one fills.
	var affinity_hover_rect := affinity_bar_hover_rect(rect)
	if affinity_hover_rect.has_point(mouse_pos):
		_fill_hover_data(
			hover_data,
			level_text,
			value_text,
			LanguageSettings.translate_text("이번 판 동안 링펫과 쌓은 교감 수치입니다. 요구치를 채우면 교감 레벨이 오르고 다음 보상이 해금됩니다.")
				+ " " + LanguageSettings.translate_text("링펫을 클릭하거나 E 키(패드 RT)로 교감할 수 있습니다."),
			Color(1.0, 112.0 / 255.0, 188.0 / 255.0, 1.0),
			affinity_hover_rect
		)
	if not satiety_layout.is_empty():
		var satiety_hover_rect := satiety_bar_hover_rect(rect)
		if satiety_hover_rect.has_point(mouse_pos):
			_fill_hover_data(
				hover_data,
				LanguageSettings.translate_text("포만도"),
				str(satiety_state.get("value", "")),
				LanguageSettings.translate_text("링펫의 포만도입니다. 시간이 지나면 서서히 줄고, 낮아지면 순찰이 느려지며 0이 되면 탈진합니다. 먹이를 주면 회복됩니다."),
				_satiety_strip_color(satiety_state, stat_buff_color),
				satiety_hover_rect
			)
	return hover_data


static func should_redraw_panel_live2d(snapshot: Dictionary) -> bool:
	if str(snapshot.get("state", "")) != "companion":
		return false
	# Every companion panel now animates (rotating aurora backdrop), not only
	# live2d-sheet pets, so the continuous-redraw gate opens for any companion.
	return true


# Slowly rotating galaxy quad behind the companion. Vertices are recomputed from
# the angle each frame into shared scratch buffers (no transform-stack rotation =
# tumble-immune, no per-frame allocation). UVs stay normalized 0..1.
const AURORA_SPIN_SECONDS := 34.0
const AURORA_ALPHA := 0.72
const AURORA_STRETCH_MAX := 1.5
const AURORA_UV_INSET := 0.05
static var _aurora_points := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
static var _aurora_colors := PackedColorArray([
	Color(1.0, 1.0, 1.0, AURORA_ALPHA),
	Color(1.0, 1.0, 1.0, AURORA_ALPHA),
	Color(1.0, 1.0, 1.0, AURORA_ALPHA),
	Color(1.0, 1.0, 1.0, AURORA_ALPHA),
])
static var AURORA_UVS := PackedVector2Array([
	Vector2(AURORA_UV_INSET, AURORA_UV_INSET),
	Vector2(1.0 - AURORA_UV_INSET, AURORA_UV_INSET),
	Vector2(1.0 - AURORA_UV_INSET, 1.0 - AURORA_UV_INSET),
	Vector2(AURORA_UV_INSET, 1.0 - AURORA_UV_INSET),
])


static func _draw_aurora_backdrop(canvas: CanvasItem, rect: Rect2, texture: Texture2D, panel_animation_time: float) -> void:
	var center := rect.get_center()
	# Corner radius = half the short side, so the rotated quad's bounding circle
	# stays inside the art rect on the short axis at every angle. The quad is
	# then stretched along the LONG axis (post-rotation, clamped to the rect) so
	# the galaxy fills the band as a tilted disc instead of hiding behind the
	# pet. The UV inset crops the texture's pure-black margin for extra reach.
	var corner_radius: float = minf(rect.size.x, rect.size.y) * 0.5 * 0.98
	var stretch: float = clampf(maxf(rect.size.x, rect.size.y) * 0.5 * 0.98 / maxf(corner_radius, 1.0), 1.0, AURORA_STRETCH_MAX)
	var stretch_horizontal: bool = rect.size.x >= rect.size.y
	var spin := fposmod(panel_animation_time, AURORA_SPIN_SECONDS) / AURORA_SPIN_SECONDS * TAU
	for i in range(4):
		var corner_angle := spin + PI * 0.25 + float(i) * PI * 0.5
		var offset := Vector2(cos(corner_angle), sin(corner_angle)) * corner_radius
		if stretch_horizontal:
			offset.x *= stretch
		else:
			offset.y *= stretch
		_aurora_points[i] = center + offset
	canvas.draw_polygon(_aurora_points, _aurora_colors, AURORA_UVS, texture)


static func draw_panel_live2d_art(canvas: CanvasItem, texture: Texture2D, rect: Rect2, pet_id: String, panel_animation_time: float) -> void:
	var source := panel_live2d_source_rect(pet_id, texture.get_size(), panel_animation_time)
	if source.size.x <= 0.0 or source.size.y <= 0.0:
		CharacterInfoOverlayTextureDrawer.draw_contained(canvas, texture, rect, Color(1.0, 1.0, 1.0, 0.96))
		return
	CharacterInfoOverlayTextureDrawer.draw_contained_region(canvas, texture, rect, source, Color(1.0, 1.0, 1.0, 0.96))


static func panel_live2d_source_rect(pet_id: String, texture_size: Vector2, panel_animation_time: float) -> Rect2:
	if texture_size.x <= 1.0 or texture_size.y <= 1.0:
		return Rect2()
	var normalized_pet_id := pet_id.strip_edges().to_lower()
	var cols: int = max(1, int(PANEL_LIVE2D_COLS_BY_PET_ID.get(normalized_pet_id, 1)))
	var rows: int = max(1, int(PANEL_LIVE2D_ROWS_BY_PET_ID.get(normalized_pet_id, 1)))
	var max_frames: int = cols * rows
	var frame_count: int = clampi(int(PANEL_LIVE2D_FRAME_COUNT_BY_PET_ID.get(normalized_pet_id, max_frames)), 1, max_frames)
	var frame_interval: float = maxf(0.016, float(PANEL_LIVE2D_FRAME_INTERVAL_BY_PET_ID.get(normalized_pet_id, 0.0625)))
	var frame_index: int = int(floor(maxf(0.0, panel_animation_time) / frame_interval)) % frame_count
	var col: int = frame_index % cols
	var row: int = int(floor(float(frame_index) / float(cols)))
	var cell_size := Vector2(texture_size.x / float(cols), texture_size.y / float(rows))
	return Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size)


static func draw_skill_icon(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	spec: Dictionary,
	mouse_pos: Vector2,
	hover_data: Dictionary,
	skill_icon_texture_cache: Dictionary,
	accent_blue: Color,
	slot_fill: Color,
	ring_segments: int,
	ui_text_scale: float
) -> Dictionary:
	var color: Color = _get_color(spec.get("color", accent_blue), accent_blue)
	var hovered: bool = rect.has_point(mouse_pos)
	var border_color: Color = Color(color.r, color.g, color.b, 1.0 if hovered else 0.72)
	canvas.draw_rect(rect, slot_fill)
	canvas.draw_rect(rect, border_color, false, 2.0 if hovered else 1.0)
	var inner := rect.grow(-4.0)
	var use_card: bool = bool(spec.get("use_card", false))
	var texture: Texture2D = CharacterInfoOverlayLingpetTextureLoader.get_skill_icon_texture(str(spec.get("card_texture_path" if use_card else "icon_texture_id", "")), skill_icon_texture_cache)
	if texture != null and use_card:
		CharacterInfoOverlayTextureDrawer.draw_cover(canvas, texture, inner, Color(1.0, 1.0, 1.0, 0.94))
	elif texture != null:
		CharacterInfoOverlayTextureDrawer.draw_contained(canvas, texture, inner, Color(1.0, 1.0, 1.0, 0.96))
	else:
		_draw_skill_symbol(canvas, font, inner, str(spec.get("id", "")), color, ring_segments, ui_text_scale)
	var badge: String = str(spec.get("badge", ""))
	if badge != "":
		var badge_rect := Rect2(rect.end.x - 22.0, rect.position.y + 3.0, 19.0, 14.0)
		canvas.draw_rect(badge_rect, Color(0.0, 0.0, 0.0, 0.58))
		canvas.draw_rect(badge_rect, Color(color.r, color.g, color.b, 0.88), false, 1.0)
		_draw_centered_text(canvas, font, badge, badge_rect.get_center().x, badge_rect.get_center().y, 8, Color.WHITE, ui_text_scale)
	if hovered:
		_fill_hover_data(hover_data, str(spec.get("title", "")), str(spec.get("subtitle", "")), str(spec.get("body", "")), color, rect)
	return hover_data


static func _draw_skill_symbol(canvas: CanvasItem, font: Font, rect: Rect2, id: String, color: Color, ring_segments: int, ui_text_scale: float) -> void:
	var center := rect.get_center()
	var radius: float = min(rect.size.x, rect.size.y) * 0.36
	canvas.draw_circle(center, radius + 7.0, Color(color.r, color.g, color.b, 0.12))
	canvas.draw_circle(center, radius, Color(color.r, color.g, color.b, 0.26))
	canvas.draw_arc(center, radius, 0.0, TAU, ring_segments, color, 2.0)
	match id:
		"lingpet_afterglow_leak":
			canvas.draw_circle(center + Vector2(-radius * 0.18, radius * 0.10), radius * 0.42, Color(0.40, 1.0, 0.82, 0.42))
			canvas.draw_circle(center + Vector2(radius * 0.18, -radius * 0.08), radius * 0.30, Color(0.86, 1.0, 0.64, 0.34))
			canvas.draw_arc(center, radius * 0.66, -0.15, PI * 1.2, ring_segments, Color(1.0, 1.0, 0.82, 0.52), 1.4, true)
			canvas.draw_circle(center, radius * 0.16, Color(1.0, 1.0, 0.86, 0.88))
		"lingpet_tailwind_steps":
			var trail_color := Color(0.60, 1.0, 0.88, 0.58)
			for i in range(3):
				var y_offset: float = (float(i) - 1.0) * radius * 0.22
				canvas.draw_arc(center + Vector2(-radius * 0.08, y_offset), radius * (0.34 + float(i) * 0.10), PI * 0.06, PI * 0.86, ring_segments, trail_color, 1.3)
			var arrow_start := center + Vector2(-radius * 0.46, radius * 0.18)
			var arrow_end := center + Vector2(radius * 0.44, -radius * 0.18)
			canvas.draw_line(arrow_start, arrow_end, Color.WHITE, 2.0)
			canvas.draw_line(arrow_end, arrow_end + Vector2(-radius * 0.20, -radius * 0.02), Color.WHITE, 2.0)
			canvas.draw_line(arrow_end, arrow_end + Vector2(-radius * 0.08, radius * 0.18), Color.WHITE, 2.0)
		"lingpet_starlight_tracking":
			var star_points := PackedVector2Array()
			for i in range(10):
				var angle: float = -PI * 0.5 + TAU * float(i) / 10.0
				var point_radius: float = radius * (0.54 if i % 2 == 0 else 0.23)
				star_points.append(center + Vector2(cos(angle), sin(angle)) * point_radius)
			canvas.draw_colored_polygon(star_points, Color(1.0, 0.92, 0.45, 0.82))
			canvas.draw_arc(center + Vector2(-radius * 0.10, radius * 0.08), radius * 0.78, PI * 0.18, PI * 1.30, ring_segments, Color(0.65, 1.0, 1.0, 0.54), 1.6)
			canvas.draw_circle(center + Vector2(radius * 0.46, -radius * 0.34), radius * 0.10, Color.WHITE)
		"lingpet_ring_dash":
			var dash_color := Color(0.50, 0.92, 1.0, 0.62)
			for i in range(3):
				var trail_offset := Vector2(-radius * (0.52 + float(i) * 0.16), radius * (0.20 - float(i) * 0.14))
				canvas.draw_line(center + trail_offset, center + trail_offset + Vector2(radius * 0.46, -radius * 0.18), dash_color, 1.4)
			var shield_rect := Rect2(center - Vector2(radius * 0.16, radius * 0.42), Vector2(radius * 0.46, radius * 0.84))
			canvas.draw_rect(shield_rect, Color(1.0, 1.0, 1.0, 0.78), false, 2.0)
			canvas.draw_line(center + Vector2(-radius * 0.46, radius * 0.28), center + Vector2(radius * 0.42, -radius * 0.28), Color.WHITE, 2.2)
		"resonance_boost", "maribo_resonance_boost", "lingpet_resonance_boost":
			for i in range(3):
				var arc_radius: float = radius * (0.55 + float(i) * 0.18)
				canvas.draw_arc(center, arc_radius, -0.2 + float(i) * 0.42, PI + float(i) * 0.34, ring_segments, Color(1.0, 1.0, 1.0, 0.36), 1.2)
			canvas.draw_circle(center, radius * 0.22, Color(1.0, 1.0, 1.0, 0.86))
			_draw_centered_text(canvas, font, "+", center.x, center.y + radius * 0.18, int(radius * 0.95), Color.WHITE, ui_text_scale)
		_:
			_draw_fallback_symbol(canvas, rect, color, id, ring_segments, ui_text_scale)


static func _draw_fallback_symbol(canvas: CanvasItem, rect: Rect2, color: Color, id_text: String, ring_segments: int, ui_text_scale: float) -> void:
	var center := rect.get_center()
	var radius: float = min(rect.size.x, rect.size.y) * 0.38
	canvas.draw_circle(center, radius, Color(color.r, color.g, color.b, 0.32))
	canvas.draw_arc(center, radius, 0.0, TAU, ring_segments, color, 2.0)
	_draw_centered_text(canvas, ThemeDB.fallback_font, _fallback_symbol_letter(id_text), center.x, center.y + 3.0, int(radius * 1.2), Color.WHITE, ui_text_scale)


static func _fill_hover_data(data: Dictionary, title: String, subtitle: String, body: String, color: Color, anchor_rect: Rect2) -> void:
	data.clear()
	data["title"] = title
	data["subtitle"] = subtitle
	data["body"] = body
	data["color"] = color
	data["anchor_rect"] = anchor_rect


static func _get_color(value: Variant, fallback: Color) -> Color:
	return value if value is Color else fallback


static func _fallback_symbol_letter(id_text: String) -> String:
	return "?" if id_text == "" else id_text.substr(0, 1).to_upper()


const SLOT_TAB_HEIGHT := 20.0
const SLOT_TAB_MAX_WIDTH := 80.0
const SLOT_TAB_GAP := 4.0
const SLOT_TAB_MAX_COUNT := 3


# Draws up to 3 acquired-lingpet tabs to the right of the "링펫" header. Each
# occupied tab appends {rect, slot_index, pet_id} to slot_tab_rects, which the
# overlay click handler (_try_handle_lingpet_slot_tab_click) reads to switch the
# active companion (lingpet_egg_runtime.switch_lingpet_slot). Tabs sit in the
# header band (above content_rect) so the body never reflows.
static func _draw_lingpet_slot_tabs(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	snapshot: Dictionary,
	slot_tab_rects: Array,
	accent_blue: Color,
	slot_fill: Color,
	empty_text_color: Color,
	text_soft: Color,
	ui_text_scale: float
) -> void:
	var tabs_value: Variant = snapshot.get("slot_tabs", [])
	if not (tabs_value is Array):
		return
	var tabs: Array = tabs_value
	if tabs.is_empty():
		return
	var count: int = mini(tabs.size(), SLOT_TAB_MAX_COUNT)
	# Anchor after the paw icon + title (title draws at rect.x + 36 since the
	# section glyph pass) so the tabs never cover the section label.
	var header_x: float = rect.position.x + 36.0
	var header_w: float = _text_size(font, "링펫", 13, ui_text_scale).x
	var gap: float = SLOT_TAB_GAP * ui_text_scale
	var start_x: float = header_x + header_w + 12.0 * ui_text_scale
	var avail: float = rect.end.x - 8.0 - start_x
	if avail <= 24.0:
		return
	var tab_h: float = SLOT_TAB_HEIGHT * ui_text_scale
	var tab_w: float = minf(SLOT_TAB_MAX_WIDTH * ui_text_scale, (avail - float(count - 1) * gap) / float(count))
	if tab_w < 18.0:
		return
	var tab_y: float = maxf(rect.position.y + 2.0, rect.position.y + 24.0 - tab_h * 0.85)
	for i in range(count):
		var entry_value: Variant = tabs[i]
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var tab_rect := Rect2(start_x + float(i) * (tab_w + gap), tab_y, tab_w, tab_h)
		var is_active: bool = bool(entry.get("active", false))
		var bg: Color = Color(accent_blue.r, accent_blue.g, accent_blue.b, 0.85) if is_active else Color(slot_fill.r, slot_fill.g, slot_fill.b, 0.72)
		canvas.draw_rect(tab_rect, bg)
		var border: Color = Color(1.0, 1.0, 1.0, 0.85) if is_active else Color(empty_text_color.r, empty_text_color.g, empty_text_color.b, 0.5)
		canvas.draw_rect(tab_rect, border, false, 1.0)
		var label: String = _fit_text_to_width(font, str(entry.get("name", "")), 11, tab_w - 8.0 * ui_text_scale, ui_text_scale)
		var label_color: Color = Color.WHITE if is_active else text_soft
		_draw_centered_text(canvas, font, label, tab_rect.get_center().x, tab_rect.get_center().y, 11, label_color, ui_text_scale)
		slot_tab_rects.append({
			"rect": tab_rect,
			"slot_index": int(entry.get("slot_index", -1)),
			"pet_id": str(entry.get("pet_id", "")),
		})


static func _draw_centered_fallback_text(canvas: CanvasItem, text: String, center_x: float, center_y: float, size: int, color: Color, ui_text_scale: float) -> void:
	_draw_centered_text(canvas, ThemeDB.fallback_font, text, center_x, center_y, size, color, ui_text_scale)


static func _fit_text_to_width(font: Font, text: String, size: int, max_width: float, ui_text_scale: float) -> String:
	if text == "" or font == null or max_width <= 0.0:
		return ""
	if _text_size(font, text, size, ui_text_scale).x <= max_width:
		return text
	var ellipsis := "..."
	var ellipsis_w := _text_size(font, ellipsis, size, ui_text_scale).x
	var next_text := text
	while next_text.length() > 0:
		next_text = next_text.left(next_text.length() - 1)
		if _text_size(font, next_text, size, ui_text_scale).x + ellipsis_w <= max_width:
			return next_text + ellipsis
	return ellipsis if ellipsis_w <= max_width else ""


static func _text_size(font: Font, text: String, size: int, ui_text_scale: float) -> Vector2:
	if font == null or text == "":
		return Vector2.ZERO
	var visible_text := LanguageSettings.translate_text(text)
	var ui_size: int = max(1, int(round(float(size) * ui_text_scale)))
	return CharacterInfoOverlayTextLineCache.get_string_size_cached(font, visible_text, ui_size)


static func _draw_centered_text(canvas: CanvasItem, font: Font, text: String, center_x: float, center_y: float, size: int, color: Color, ui_text_scale: float) -> void:
	if text == "":
		return
	if font == null:
		return
	var visible_text := LanguageSettings.translate_text(text)
	var ui_size: int = max(1, int(round(float(size) * ui_text_scale)))
	# get_string_size + draw_string과 픽셀 동일한 셰이핑 캐시 경로
	# (Font 내부 64-LRU 순환 축출 회피, 측정/드로우가 같은 엔트리 공유).
	var text_size: Vector2 = CharacterInfoOverlayTextLineCache.get_string_size_cached(font, visible_text, ui_size)
	CharacterInfoOverlayTextLineCache.draw_string_cached(canvas, font, Vector2(center_x - text_size.x * 0.5, center_y + text_size.y * 0.34), visible_text, ui_size, color)


static func _draw_text_xy(canvas: CanvasItem, font: Font, text: String, baseline_x: float, baseline_y: float, size: int, color: Color, ui_text_scale: float) -> void:
	if text == "":
		return
	if font == null:
		return
	# draw_string과 픽셀 동일한 셰이핑 캐시 경로 (Font 내부 64-LRU 순환 축출 회피).
	CharacterInfoOverlayTextLineCache.draw_string_cached(canvas, font, Vector2(baseline_x, baseline_y), LanguageSettings.translate_text(text), max(1, int(round(float(size) * ui_text_scale))), color)


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
	var skill_id: String = str(snapshot.get("companion_skill_id", "")).strip_edges()
	if skill_id != "":
		var skill_name: String = str(snapshot.get("companion_skill_name", "")).strip_edges()
		if skill_name == "":
			skill_name = "액티브 스킬"
		var active_cooldown: float = float(snapshot.get("companion_skill_cooldown_duration", 0.0))
		var skill_description: String = str(snapshot.get("companion_skill_description", "")).strip_edges()
		if skill_description == "":
			skill_description = "링펫이 전투 중 자동으로 사용하는 액티브 스킬입니다."
		var icon_texture_id := str(snapshot.get("companion_skill_icon_path", "")).strip_edges()
		var skill_level: int = int(snapshot.get("companion_skill_level", 0))
		var active_level_label := "Lv.%d · " % skill_level if skill_level > 0 else ""
		specs.append({
			"id": skill_id,
			"title": skill_name,
			"subtitle": LanguageSettings.translate_text("액티브 · %s쿨타임 %s") % [active_level_label, LanguageSettings.translate_text(CharacterInfoOverlayFormatter.format_seconds_text(active_cooldown))],
			"body": skill_description,
			"color": Color(80.0 / 255.0, 220.0 / 255.0, 1.0),
			"badge": "A",
			"use_card": icon_texture_id == "",
			"icon_texture_id": icon_texture_id,
			"card_texture_path": str(snapshot.get("companion_skill_card_path", "")),
		})
	var second_skill_id: String = str(snapshot.get("companion_skill_id_1", "")).strip_edges()
	if second_skill_id != "":
		var second_skill_name: String = str(snapshot.get("companion_skill_name_1", "")).strip_edges()
		if second_skill_name == "":
			second_skill_name = "2nd active"
		var second_active_cooldown: float = float(snapshot.get("companion_skill_cooldown_duration_1", 0.0))
		var second_skill_description: String = str(snapshot.get("companion_skill_description_1", "")).strip_edges()
		if second_skill_description == "":
			second_skill_description = "두 번째 액티브 슬롯에 장착된 링펫 스킬입니다."
		var second_icon_texture_id := str(snapshot.get("companion_skill_icon_path_1", "")).strip_edges()
		var second_skill_level: int = int(snapshot.get("companion_skill_level_1", 0))
		var second_active_level_label := "Lv.%d / " % second_skill_level if second_skill_level > 0 else ""
		specs.append({
			"id": second_skill_id,
			"title": second_skill_name,
			"subtitle": "2nd active / %s%s" % [second_active_level_label, CharacterInfoOverlayFormatter.format_seconds_text(second_active_cooldown)],
			"body": second_skill_description,
			"color": Color(80.0 / 255.0, 220.0 / 255.0, 1.0),
			"badge": "A",
			"use_card": second_icon_texture_id == "",
			"icon_texture_id": second_icon_texture_id,
			"card_texture_path": str(snapshot.get("companion_skill_card_path_1", "")),
		})
	var gauge_bonus_pct: float = float(snapshot.get("gauge_gain_bonus_pct", 0.0))
	var player_speed_bonus_pct: float = float(snapshot.get("companion_player_speed_bonus_pct", 0.0))
	var starpoint_tracking_chance_pct: float = float(snapshot.get("companion_starpoint_tracking_chance_pct", 0.0))
	var ring_dash_chance_pct: float = float(snapshot.get("companion_ring_dash_chance_pct", 0.0))
	var passive_id: String = str(snapshot.get("companion_passive_skill_id", "")).strip_edges()
	if passive_id != "":
		var passive_name: String = str(snapshot.get("companion_passive_skill_name", "")).strip_edges()
		if passive_name == "":
			passive_name = "패시브 스킬"
		var passive_description: String = str(snapshot.get("companion_passive_skill_description", "")).strip_edges()
		if passive_description == "":
			passive_description = "링펫에게 배정된 패시브 스킬입니다."
		var passive_subtitle := LanguageSettings.translate_text("패시브")
		var passive_level: int = int(snapshot.get("companion_passive_skill_level", 0))
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
		var fallback_passive: Dictionary = LingpetCatalog.get_passive_skill(str(snapshot.get("pet_id", "")))
		var fallback_passive_id := str(fallback_passive.get("id", "")).strip_edges()
		var fallback_passive_title := str(fallback_passive.get("name", "")).strip_edges()
		var fallback_passive_description := str(fallback_passive.get("description", "")).strip_edges()
		var fallback_icon_texture_id := str(snapshot.get("gauge_gain_bonus_icon_path", "")).strip_edges()
		if fallback_icon_texture_id == "":
			fallback_icon_texture_id = str(fallback_passive.get("icon_texture_path", "")).strip_edges()
		if fallback_passive_id == "":
			fallback_passive_id = "lingpet_resonance_boost"
		if fallback_passive_title == "":
			fallback_passive_title = "공명 증폭"
		if fallback_passive_description == "":
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
	var second_passive_id: String = str(snapshot.get("companion_passive_skill_id_1", "")).strip_edges()
	if second_passive_id != "":
		var second_passive_name: String = str(snapshot.get("companion_passive_skill_name_1", "")).strip_edges()
		if second_passive_name == "":
			second_passive_name = "2nd passive"
		var second_passive_description: String = str(snapshot.get("companion_passive_skill_description_1", "")).strip_edges()
		if second_passive_description == "":
			second_passive_description = "두 번째 패시브 슬롯에 장착된 링펫 스킬입니다."
		var second_passive_subtitle := "2nd passive"
		var second_passive_level: int = int(snapshot.get("companion_passive_skill_level_1", 0))
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


static func _first_open_unlock_option(unlock_options: Array) -> Dictionary:
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


static func _count_open_unlock_options(unlock_options: Array) -> int:
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


static func _unlock_candidate_spec(pet_id: String, choice_key: String, candidate_id: String, stat_buff_color: Color, accent_blue: Color) -> Dictionary:
	var active_choice := choice_key == "active" or choice_key == "second_active"
	var entry: Dictionary = LingpetCatalog.get_active_skill_entry(candidate_id) if active_choice else LingpetCatalog.get_passive_skill_entry(candidate_id)
	var title := str(entry.get("name", "")).strip_edges()
	if title == "":
		title = candidate_id
	var body := str(entry.get("description", "")).strip_edges()
	if body == "":
		body = "선택하면 이 스킬이 링펫 슬롯에 고정됩니다."
	var icon_path := str(entry.get("icon_texture_path", "")).strip_edges()
	if not active_choice and icon_path == "":
		icon_path = LingpetCatalog.get_passive_icon_path(pet_id, candidate_id)
	return {
		"id": candidate_id,
		"title": title,
		"subtitle": _unlock_choice_subtitle(choice_key),
		"body": body,
		"color": accent_blue if active_choice else stat_buff_color,
		"badge": "A" if active_choice else "P",
		"use_card": active_choice and str(entry.get("card_texture_path", "")).strip_edges() != "",
		"icon_texture_id": icon_path,
		"card_texture_path": str(entry.get("card_texture_path", "")).strip_edges(),
	}


static func _unlock_choice_title(choice_key: String) -> String:
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


static func _unlock_choice_subtitle(choice_key: String) -> String:
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


static func build_panel_snapshot(owner: Object, safe_owner_get: Callable, hatch_required_hits: int) -> Dictionary:
	return CharacterInfoOverlayLingpetSnapshotBuilder.build_panel_snapshot(owner, safe_owner_get, hatch_required_hits)

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
	var state: String = str(snapshot.get("state", "none"))
	if state == "egg":
		var hits: int = int(snapshot.get("hatch_hits", 0))
		var required_hits: int = max(1, int(snapshot.get("required_hits", hatch_required_hits)))
		return [
			make_display_stat_row("상태", "알", accent_gold),
			make_display_stat_row("부화 진행", CharacterInfoOverlayFormatter.format_int_pair(hits, required_hits), text_soft),
		]
	if state != "companion":
		return [
			make_display_stat_row("상태", "미획득", empty_text_color),
		]
	var speed_default: float = float(snapshot.get("companion_patrol_speed_default", 120.0))
	var speed_min: float = float(snapshot.get("companion_patrol_speed_min", 70.0))
	var speed_max: float = float(snapshot.get("companion_patrol_speed_max", 135.0))
	var catch_width: float = float(snapshot.get("companion_catch_width", 100.0))
	var catch_height: float = float(snapshot.get("companion_catch_height", 44.0))
	var hit_gain: float = float(snapshot.get("companion_hit_gauge_gain", 40.0))
	var skill_id: String = str(snapshot.get("companion_skill_id", "")).strip_edges()
	var skill_name: String = str(snapshot.get("companion_skill_name", "")).strip_edges()
	if skill_name == "":
		skill_name = "액티브 스킬"
	var active_cooldown: float = float(snapshot.get("companion_skill_cooldown_duration", 40.0))
	var second_skill_id: String = str(snapshot.get("companion_skill_id_1", "")).strip_edges()
	var second_skill_name: String = str(snapshot.get("companion_skill_name_1", "")).strip_edges()
	if second_skill_name == "":
		second_skill_name = "2nd active"
	var second_active_cooldown: float = float(snapshot.get("companion_skill_cooldown_duration_1", 0.0))
	var defense_rate: float = float(snapshot.get("companion_defense_rate", 0.0))
	var appearance_rate: float = float(snapshot.get("companion_appearance_rate", 0.0))
	var speed_display: float = speed_default / speed_display_px_per_point
	# Tooltips describe the ACTUAL equipped lingpet, not a hardcoded "마리보".
	var pet_name: String = str(snapshot.get("title", "")).strip_edges()
	if pet_name == "":
		pet_name = "링펫"
	var rows := [
		make_display_stat_row("이동 속도", "%.2f" % speed_display, Color.WHITE, LanguageSettings.translate_text("%s이(가) 플레이어 진영에서 독자적으로 순찰할 때 쓰는 기본 이동 속도입니다. 실제 순찰은 %s~%spx/s 사이에서 자연스럽게 변동됩니다.") % [pet_name, CharacterInfoOverlayFormatter.format_plain_number(speed_min), CharacterInfoOverlayFormatter.format_plain_number(speed_max)]),
		make_display_stat_row("몸집크기", "%sx%spx" % [CharacterInfoOverlayFormatter.format_plain_number(catch_width), CharacterInfoOverlayFormatter.format_plain_number(catch_height)], Color.WHITE, LanguageSettings.translate_text("%s이(가) 공을 튕겨낼 때 쓰는 실제 판정 범위입니다.") % pet_name),
		make_display_stat_row("게이지 획득량", "%spt" % CharacterInfoOverlayFormatter.format_plain_number(hit_gain), stat_buff_color, "링펫이 공을 직접 튕겼을 때 얻는 공통 기본 게이지 획득량입니다."),
	]
	# Defense is a PATROL-only local guard, so flight-style lingpets report a 0 rate
	# (see lingpet_egg_runtime._get_current_defense_rate). Hide the row entirely for
	# them rather than showing a misleading "방어율 0%" they can never act on.
	if defense_rate > 0.0:
		rows.append(make_display_stat_row("방어율", CharacterInfoOverlayFormatter.format_percent_text(defense_rate * 100.0), stat_buff_color, defense_rate_tooltip))
	# Flight-style lingpets show 출현율 (appearance rate) instead of 방어율 — the two are
	# mutually exclusive (patrol = defense, flight = appearance), so only one row shows.
	if appearance_rate > 0.0:
		rows.append(make_display_stat_row("출현율", CharacterInfoOverlayFormatter.format_percent_text(appearance_rate * 100.0), stat_buff_color, "사라졌다 다시 나타나기까지의 대기가 짧아지는 정도입니다. 높을수록 더 자주 등장합니다."))
	if skill_id != "":
		rows.insert(3, make_display_stat_row("액티브 쿨타임", CharacterInfoOverlayFormatter.format_seconds_text(active_cooldown), Color.WHITE, LanguageSettings.translate_text("%s을(를) 다시 사용할 수 있게 되는 시간입니다.") % skill_name))
	if second_skill_id != "":
		var projected_count_with_affinity := rows.size() + 2
		if _lingpet_row_budget_can_fit(row_budget_rect, projected_count_with_affinity):
			rows.insert(mini(4, rows.size()), make_display_stat_row("2nd 액티브 쿨타임", CharacterInfoOverlayFormatter.format_seconds_text(second_active_cooldown), Color.WHITE, "%s을(를) 다시 사용할 수 있게 되는 시간입니다." % second_skill_name))
	rows.append(make_display_stat_row("교감", "Lv.%d" % int(snapshot.get("affinity_level", 0)), stat_buff_color))
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
	var cache_hash: int = hash([
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
	var state: String = str(snapshot.get("state", "none"))
	if state == "egg":
		return hash([
			LanguageSettings.get_language(),
			state,
			int(snapshot.get("hatch_hits", 0)),
			int(snapshot.get("required_hits", hatch_required_hits)),
		])
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
		int(snapshot.get("affinity_level", 0)),
		float(snapshot.get("affinity_points", 0.0)),
		float(snapshot.get("affinity_next_requirement", 0.0)),
		str(snapshot.get("affinity_next_label", "")).strip_edges(),
		int(snapshot.get("ring_core_tier", 0)),
		int(snapshot.get("affinity_chip_count", 0)),
	])


static func _lingpet_row_budget_can_fit(budget_rect: Rect2, projected_row_count: int) -> bool:
	if projected_row_count <= 0:
		return true
	if budget_rect.size.x <= 0.0 or budget_rect.size.y <= 0.0:
		return true
	var lingpet_rect := CharacterInfoOverlayStatsPresenter.lingpet_stat_rect_for_sections(budget_rect)
	return CharacterInfoOverlayStatsPresenter.lingpet_stat_rows_visible_capacity(lingpet_rect, projected_row_count) >= projected_row_count


static func make_display_stat_row(label: String, value_text: String, color: Color, tooltip_body: String = "") -> Dictionary:
	var row := {
		"label": LanguageSettings.translate_text(label),
		"value": LanguageSettings.translate_text(value_text),
		"color": color,
	}
	if tooltip_body != "":
		row["tooltip_title"] = LanguageSettings.translate_text(label)
		row["tooltip_subtitle"] = LanguageSettings.translate_text(value_text)
		row["tooltip_body"] = LanguageSettings.translate_text(tooltip_body)
	return row


static func _draw_lingpet_ring_core_row(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	snapshot: Dictionary,
	mouse_pos: Vector2,
	hover_data: Dictionary,
	ring_core_rects: Array,
	skill_icon_texture_cache: Dictionary,
	stat_buff_color: Color,
	empty_text_color: Color,
	accent_blue: Color,
	slot_fill: Color,
	ring_segments: int,
	ui_text_scale: float
) -> Dictionary:
	var tier := clampi(int(snapshot.get("ring_core_tier", 0)), 0, LingpetRingCoreRules.MAX_RING_CORE_TIER)
	var chip_count := clampi(int(snapshot.get("affinity_chip_count", 0)), 0, LingpetAffinityState.MAX_ENHANCEMENT_CHIPS)
	var slot_size: float = clampf(rect.size.y - 6.0, 42.0, 58.0)
	var ring_core_rect := Rect2(rect.position + Vector2(0.0, (rect.size.y - slot_size) * 0.5), Vector2(slot_size, slot_size))
	if tier > 0:
		ring_core_rects.append(ring_core_rect)
	var chip_pips_x := ring_core_rect.end.x + 7.0
	var chip_pips_hover_rect := Rect2(chip_pips_x - 3.0, rect.position.y, _affinity_chip_pips_width() + 6.0, rect.size.y)
	# Whole-row hover: the narrow chip-pips column shows the chip income tooltip; everything
	# else on the row (icon, labels, gaps) shows the ring-core cap tooltip. The icon-only and
	# pips-only hit rects were tiny (~50px / ~15px on a ~200px row), so hovering the large
	# label text showed nothing. The entire row is now a hover target.
	var hover_target := _ring_core_row_hover_target(rect, chip_pips_hover_rect, mouse_pos)
	_draw_lingpet_ring_core_slot(canvas, font, ring_core_rect, snapshot, hover_target == &"ring_core", skill_icon_texture_cache, accent_blue, slot_fill, ring_segments, ui_text_scale)
	_draw_vertical_affinity_chip_pips(canvas, Rect2(chip_pips_x, rect.position.y, _affinity_chip_pips_width(), rect.size.y), chip_count, stat_buff_color, empty_text_color)
	var text_x := chip_pips_x + _affinity_chip_pips_width() + 11.0
	var text_w: float = maxf(32.0, rect.end.x - text_x)
	var title_text := LanguageSettings.translate_text("링코어")
	var tier_text := "T%d" % tier if tier > 0 else LanguageSettings.translate_text("미장착")
	var chip_text := LanguageSettings.translate_text("강화칩 %d / %d") % [chip_count, LingpetAffinityState.MAX_ENHANCEMENT_CHIPS]
	_draw_text_xy(canvas, font, _fit_text_to_width(font, title_text, 11, text_w, ui_text_scale), text_x, rect.position.y + 18.0, 11, Color.WHITE, ui_text_scale)
	_draw_text_xy(canvas, font, _fit_text_to_width(font, tier_text, 10, text_w, ui_text_scale), text_x, rect.position.y + 36.0, 10, stat_buff_color if tier > 0 else empty_text_color, ui_text_scale)
	_draw_text_xy(canvas, font, _fit_text_to_width(font, chip_text, 9, text_w, ui_text_scale), text_x, rect.position.y + 52.0, 9, empty_text_color, ui_text_scale)
	if hover_target == &"chip":
		var chip_body := LanguageSettings.translate_text("친밀도 획득량 +%d%%") % (chip_count * 20)
		_fill_hover_data(hover_data, LanguageSettings.translate_text("강화칩 %d / %d") % [chip_count, LingpetAffinityState.MAX_ENHANCEMENT_CHIPS], "", chip_body, stat_buff_color, chip_pips_hover_rect)
	elif hover_target == &"ring_core":
		var rc_subtitle := ("T%d" % tier) if tier > 0 else LanguageSettings.translate_text("미장착")
		var rc_cap := LingpetRingCoreRules.get_ring_core_cap_for_tier(tier)
		var rc_body := LanguageSettings.translate_text("친밀도 상한 Lv.%d") % rc_cap
		_fill_hover_data(hover_data, LanguageSettings.translate_text("링코어"), rc_subtitle, rc_body, accent_blue, rect)
	return hover_data


# Returns which ring-core-row sub-region the mouse is over: the narrow chip-pips column
# (&"chip"), the rest of the row (&"ring_core"), or nothing (&""). Pips win where they
# overlap so the chip-income tooltip stays reachable. Pure + side-effect-free so the hover
# decision can be sealed by a smoke without a live draw context.
static func _ring_core_row_hover_target(row_rect: Rect2, pips_rect: Rect2, mouse_pos: Vector2) -> StringName:
	if pips_rect.has_point(mouse_pos):
		return &"chip"
	if row_rect.has_point(mouse_pos):
		return &"ring_core"
	return &""


# The ring-core slot cell is square and draw_contained centers the icon on the rect, so
# the inset MUST be symmetric — an asymmetric inset both shifts the icon sideways and
# shrinks it. A uniform 4px inset keeps the icon concentric with the cell and fills it
# generously (icon size = cell - 8, vs the old cell - 17 width that read small + left-shifted).
static func _ring_core_icon_rect(slot_rect: Rect2) -> Rect2:
	return slot_rect.grow(-4.0)


static func _draw_lingpet_ring_core_slot(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	snapshot: Dictionary,
	hovered: bool,
	skill_icon_texture_cache: Dictionary,
	accent_blue: Color,
	slot_fill: Color,
	ring_segments: int,
	ui_text_scale: float
) -> void:
	var tier := clampi(int(snapshot.get("ring_core_tier", 0)), 0, LingpetRingCoreRules.MAX_RING_CORE_TIER)
	canvas.draw_rect(rect, slot_fill)
	var border_color := Color(accent_blue.r, accent_blue.g, accent_blue.b, 0.96 if tier > 0 else 0.42)
	canvas.draw_rect(rect, border_color, false, 2.0 if hovered else 1.0)
	var icon_rect := _ring_core_icon_rect(rect)
	var texture: Texture2D = CharacterInfoOverlayLingpetTextureLoader.get_ring_core_icon_texture(tier, skill_icon_texture_cache)
	if texture != null:
		CharacterInfoOverlayTextureDrawer.draw_contained(canvas, texture, icon_rect, Color(1.0, 1.0, 1.0, 0.96))
	else:
		_draw_empty_lingpet_ring_core_slot(canvas, icon_rect, accent_blue, ring_segments)
	if tier > 0:
		var badge_rect := Rect2(rect.position + Vector2(3.0, rect.size.y - 16.0), Vector2(22.0, 12.0))
		canvas.draw_rect(badge_rect, Color(0.0, 0.0, 0.0, 0.58))
		canvas.draw_rect(badge_rect, Color(accent_blue.r, accent_blue.g, accent_blue.b, 0.72), false, 1.0)
		_draw_centered_text(canvas, font, "T%d" % tier, badge_rect.get_center().x, badge_rect.get_center().y, 7, Color.WHITE, ui_text_scale)


static func _draw_empty_lingpet_ring_core_slot(canvas: CanvasItem, rect: Rect2, accent_blue: Color, ring_segments: int) -> void:
	var center := rect.get_center()
	var radius: float = min(rect.size.x, rect.size.y) * 0.34
	canvas.draw_circle(center, radius, Color(accent_blue.r, accent_blue.g, accent_blue.b, 0.08))
	canvas.draw_arc(center, radius, 0.0, TAU, ring_segments, Color(accent_blue.r, accent_blue.g, accent_blue.b, 0.34), 1.4)
	canvas.draw_line(center + Vector2(-radius * 0.58, radius * 0.58), center + Vector2(radius * 0.58, -radius * 0.58), Color(0.70, 0.76, 0.82, 0.48), 1.6)


static func _affinity_chip_pips_width() -> float:
	var max_chips := LingpetAffinityState.MAX_ENHANCEMENT_CHIPS
	if max_chips <= 0:
		return 0.0
	return 8.0


static func _draw_vertical_affinity_chip_pips(canvas: CanvasItem, rect: Rect2, chip_count: int, stat_buff_color: Color, empty_text_color: Color) -> void:
	var max_chips := LingpetAffinityState.MAX_ENHANCEMENT_CHIPS
	if max_chips <= 0:
		return
	var pip_w := 8.0
	var pip_h := 7.0
	var pip_gap := 2.0
	var total_h := float(max_chips) * pip_h + float(maxi(0, max_chips - 1)) * pip_gap
	var pip_x := rect.position.x + (rect.size.x - pip_w) * 0.5
	var pip_y := rect.position.y + (rect.size.y - total_h) * 0.5
	for i in range(max_chips):
		var filled := i < chip_count
		var pip_rect := Rect2(pip_x, pip_y + float(i) * (pip_h + pip_gap), pip_w, pip_h)
		var fill := Color(stat_buff_color.r, stat_buff_color.g, stat_buff_color.b, 0.88) if filled else Color(empty_text_color.r, empty_text_color.g, empty_text_color.b, 0.18)
		var border := Color(stat_buff_color.r, stat_buff_color.g, stat_buff_color.b, 0.68) if filled else Color(empty_text_color.r, empty_text_color.g, empty_text_color.b, 0.42)
		canvas.draw_rect(pip_rect, fill)
		canvas.draw_rect(pip_rect, border, false, 1.0)
