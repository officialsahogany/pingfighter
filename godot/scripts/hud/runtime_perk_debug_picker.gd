extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const PANEL_MARGIN := 28.0
const PANEL_MAX_WIDTH := 1180.0
const HEADER_HEIGHT := 112.0
const CARD_HEIGHT := 54.0
const CARD_GAP := 8.0
const MIN_CARD_WIDTH := 208.0
const ICON_SIZE := 36.0
const MAX_VISIBLE_CARDS := 12
const TAB_TOP_OFFSET := 64.0
const TAB_HEIGHT := 32.0
const TAB_GAP := 6.0
const TAB_DEFINITIONS := [
	{"id": "smasher_chosik", "label": "한미량 초식", "kind": "chosik", "character_type": "smasher"},
	{"id": "soldier_chosik", "label": "호란 초식", "kind": "chosik", "character_type": "soldier"},
	{"id": "viper_chosik", "label": "세린 초식", "kind": "chosik", "character_type": "viper"},
	{"id": "vision_mugong", "label": "비전초식", "kind": "vision_mugong"},
	{"id": "mugong", "label": "무공", "kind": "mugong"},
	{"id": "peerless_mugong", "label": "절세무공", "kind": "peerless_mugong"},
]
const TOOLTIP_MAX_WIDTH := 380.0
const TOOLTIP_MIN_WIDTH := 280.0
const TOOLTIP_VIEW_MARGIN := 8.0
const TOOLTIP_CARD_GAP := 10.0
const TOOLTIP_PADDING := 14.0
const TOOLTIP_TITLE_LINE_HEIGHT := 21.0
const TOOLTIP_BODY_LINE_HEIGHT := 18.0

var open := false
var target_level := 1
var last_applied_id := ""
var last_applied_timer := 0.0
var page_index := 0
var selected_tab_index := 0
var _icon_prewarmed := false
var _text_prewarmed := false
var _text_prewarmed_char_type := ""
var _cached_entries: Array = []
var _cached_entries_char_type: String = ""
var _cached_panel_rect: Rect2 = Rect2()
var _cached_layout: Dictionary = {}
var _cached_layout_view_w: float = -1.0
var _cached_layout_view_h: float = -1.0
var _cached_layout_entry_count: int = -1
var _tooltip_layout_cache: Dictionary = {}


func prewarm_assets(catalog: Object = null, owner: Object = null, icon_renderer: Object = null) -> void:
	if not _icon_prewarmed and icon_renderer != null and icon_renderer.has_method("prewarm_assets"):
		icon_renderer.prewarm_assets()
		_icon_prewarmed = true
	var char_type: String = _get_character_type(owner)
	var entries: Array = _cached_entries
	if entries.is_empty() or _cached_entries_char_type != char_type:
		entries = _get_entries(catalog, owner)
	_cache_entries_for_owner(owner, entries)
	if _text_prewarmed and _text_prewarmed_char_type == char_type:
		return
	_text_prewarmed = true
	_text_prewarmed_char_type = char_type
	_prewarm_text_metrics(entries)


func toggle() -> void:
	open = not open
	if open:
		target_level = max(1, target_level)
		page_index = max(0, page_index)


func close() -> void:
	open = false


func is_open() -> bool:
	return open


func handle_input(event: InputEvent, owner: Object, registry: Object, view_size: Vector2) -> bool:
	if not open:
		return false
	var catalog: Object = _get_instance(registry, "runtime_perk_catalog")
	var all_entries: Array = _get_entries(catalog, owner)
	var entries: Array = _get_entries_for_tab(all_entries, selected_tab_index)

	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed or key_event.echo:
			return true
		if key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE:
			close()
			return true
		if _handle_tab_key(key_event):
			return true
		if _handle_page_key(key_event, entries.size()):
			return true
		return true

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP or mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mouse_event.pressed:
				_adjust_target_level(mouse_event, entries, view_size)
			return true
		if not mouse_event.pressed:
			return true
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			close()
			return true
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return true
		var panel_rect: Rect2 = _get_panel_rect(view_size, min(entries.size(), MAX_VISIBLE_CARDS))
		if not panel_rect.has_point(mouse_event.position):
			close()
			return true
		var clicked_tab_index: int = _get_tab_index_at(mouse_event.position, panel_rect)
		if clicked_tab_index >= 0:
			_select_tab(clicked_tab_index)
			return true
		var hit_index: int = _get_entry_index_at(mouse_event.position, view_size, entries)
		if hit_index >= 0:
			_apply_entry(entries[hit_index], owner, registry, catalog)
		return true

	if event is InputEventMouseMotion:
		return true

	return true


func update(delta: float) -> void:
	if last_applied_timer > 0.0:
		last_applied_timer = max(0.0, last_applied_timer - delta)


func draw(canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2) -> void:
	if canvas == null or not open:
		return
	var catalog: Object = _get_instance(registry, "runtime_perk_catalog")
	var runtime_state: Object = _get_instance(registry, "runtime_perk_state")
	var icon_renderer: Object = _get_instance(registry, "runtime_perk_icon_renderer")
	var all_entries: Array = _get_cached_entries(catalog, owner)
	var entries: Array = _get_entries_for_tab(all_entries, selected_tab_index)
	_clamp_page_index(entries.size())
	var visible_entries: Array = _get_visible_entries(entries)
	var panel_layout: Dictionary = _get_cached_panel_layout(view_size, visible_entries.size())
	var panel_rect: Rect2 = panel_layout.get("panel_rect", Rect2())
	var layout: Dictionary = panel_layout.get("layout", {})
	var mouse_pos: Vector2 = _get_mouse_position(canvas)

	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.40))
	canvas.draw_rect(panel_rect, Color(0.035, 0.045, 0.070, 0.96))
	canvas.draw_rect(panel_rect, Color(0.30, 0.78, 1.0, 0.90), false, 2.0)

	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var title_pos: Vector2 = panel_rect.position + Vector2(18.0, 30.0)
	canvas.draw_string(font, title_pos, "F4 초식 · 무공 디버그", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.84, 0.96, 1.0))
	canvas.draw_string(font, panel_rect.position + Vector2(18.0, 52.0), "탭 선택 · 호버 상세 · 좌클릭 적용 · 휠 단계 · 우클릭/Esc 닫기", HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 150.0, 12, Color(0.70, 0.77, 0.84))
	var level_text := "목표 단계 %d" % target_level
	var level_size: Vector2 = font.get_string_size(level_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18)
	canvas.draw_string(font, panel_rect.position + Vector2(panel_rect.size.x - level_size.x - 18.0, 32.0), level_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(1.0, 0.84, 0.28))
	var page_text := "Page %d/%d" % [page_index + 1, _get_page_count(entries.size())]
	canvas.draw_string(font, panel_rect.position + Vector2(panel_rect.size.x - 112.0, 54.0), page_text, HORIZONTAL_ALIGNMENT_LEFT, 96.0, 12, Color(0.70, 0.84, 0.94))
	_draw_tabs(canvas, font, panel_rect, all_entries, mouse_pos)

	var levels: Dictionary = _get_runtime_levels(runtime_state, owner)
	var hovered_entry: Dictionary = {}
	var hovered_card_rect := Rect2()
	for index in range(visible_entries.size()):
		var entry: Dictionary = visible_entries[index]
		var card_rect: Rect2 = _get_card_rect(index, panel_rect, layout)
		var hovered: bool = card_rect.has_point(mouse_pos)
		_draw_card(canvas, font, card_rect, entry, hovered, levels, icon_renderer)
		if hovered:
			hovered_entry = entry
			hovered_card_rect = card_rect
	if not hovered_entry.is_empty():
		var hovered_perk_id: String = str(hovered_entry.get("id", ""))
		_draw_hover_tooltip(
			canvas,
			font,
			hovered_entry,
			int(levels.get(hovered_perk_id, 0)),
			hovered_card_rect,
			view_size
		)


func _draw_tabs(canvas: CanvasItem, font: Font, panel_rect: Rect2, all_entries: Array, mouse_pos: Vector2) -> void:
	for tab_index in range(TAB_DEFINITIONS.size()):
		var tab_rect: Rect2 = _get_tab_rect(tab_index, panel_rect)
		var selected: bool = tab_index == selected_tab_index
		var hovered: bool = tab_rect.has_point(mouse_pos)
		var fill := Color(0.070, 0.085, 0.120, 0.96)
		var border := Color(0.25, 0.34, 0.46, 0.78)
		var text_color := Color(0.70, 0.78, 0.86)
		if hovered:
			fill = Color(0.105, 0.145, 0.200, 0.98)
			border = Color(0.38, 0.67, 0.88, 0.88)
			text_color = Color(0.88, 0.95, 1.0)
		if selected:
			fill = Color(0.12, 0.24, 0.34, 0.99)
			border = Color(0.35, 0.82, 1.0, 0.96)
			text_color = Color(0.96, 0.99, 1.0)
		canvas.draw_rect(tab_rect, fill)
		canvas.draw_rect(tab_rect, border, false, 1.5 if selected else 1.0)
		if selected:
			canvas.draw_rect(Rect2(tab_rect.position + Vector2(1.0, tab_rect.size.y - 3.0), Vector2(tab_rect.size.x - 2.0, 2.0)), Color(0.34, 0.86, 1.0, 0.95))
		var definition: Dictionary = TAB_DEFINITIONS[tab_index]
		var entry_count: int = _get_entries_for_tab(all_entries, tab_index).size()
		var label := "%s %d" % [str(definition.get("label", "")), entry_count]
		canvas.draw_string(font, tab_rect.position + Vector2(5.0, 21.0), label, HORIZONTAL_ALIGNMENT_CENTER, tab_rect.size.x - 10.0, 12, text_color)


func _get_tab_rect(tab_index: int, panel_rect: Rect2) -> Rect2:
	var tab_count: int = max(1, TAB_DEFINITIONS.size())
	var inner_width: float = panel_rect.size.x - 24.0
	var tab_width: float = (inner_width - TAB_GAP * float(tab_count - 1)) / float(tab_count)
	var x: float = panel_rect.position.x + 12.0 + float(tab_index) * (tab_width + TAB_GAP)
	return Rect2(Vector2(x, panel_rect.position.y + TAB_TOP_OFFSET), Vector2(tab_width, TAB_HEIGHT))


func _get_tab_index_at(position: Vector2, panel_rect: Rect2) -> int:
	for tab_index in range(TAB_DEFINITIONS.size()):
		if _get_tab_rect(tab_index, panel_rect).has_point(position):
			return tab_index
	return -1


func _select_tab(tab_index: int) -> bool:
	var clamped_index: int = clampi(tab_index, 0, TAB_DEFINITIONS.size() - 1)
	if clamped_index == selected_tab_index:
		return false
	selected_tab_index = clamped_index
	page_index = 0
	return true


func _handle_tab_key(key_event: InputEventKey) -> bool:
	match key_event.keycode:
		KEY_1, KEY_KP_1:
			_select_tab(0)
		KEY_2, KEY_KP_2:
			_select_tab(1)
		KEY_3, KEY_KP_3:
			_select_tab(2)
		KEY_4, KEY_KP_4:
			_select_tab(3)
		KEY_5, KEY_KP_5:
			_select_tab(4)
		KEY_6, KEY_KP_6:
			_select_tab(5)
		KEY_TAB:
			var direction := -1 if key_event.shift_pressed else 1
			_select_tab(posmod(selected_tab_index + direction, TAB_DEFINITIONS.size()))
		_:
			return false
	return true


func _get_entries_for_tab(all_entries: Array, tab_index: int) -> Array:
	var result: Array = []
	if TAB_DEFINITIONS.is_empty():
		return result
	var definition: Dictionary = TAB_DEFINITIONS[clampi(tab_index, 0, TAB_DEFINITIONS.size() - 1)]
	for entry_value in all_entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if _entry_matches_tab(entry, definition):
			result.append(entry)
	return result


func _entry_matches_tab(entry: Dictionary, definition: Dictionary) -> bool:
	var kind: String = str(definition.get("kind", ""))
	var is_peerless: bool = _is_peerless_mugong_entry(entry)
	var is_chosik: bool = _is_chosik_entry(entry)
	var is_vision_mugong: bool = _is_vision_mugong_entry(entry)
	match kind:
		"chosik":
			if not is_chosik or is_peerless or is_vision_mugong:
				return false
			var restriction: String = str(entry.get("character_restriction", "")).strip_edges().to_lower()
			if restriction.is_empty():
				return true
			return restriction == str(definition.get("character_type", ""))
		"vision_mugong":
			return is_vision_mugong
		"peerless_mugong":
			return is_peerless
		"mugong":
			return not is_chosik and not is_peerless
	return false


func _is_chosik_entry(entry: Dictionary) -> bool:
	return (
		str(entry.get("unlocks_skill", "")).strip_edges() != ""
		or bool(entry.get("is_skill_manual", false))
	)


func _is_vision_mugong_entry(entry: Dictionary) -> bool:
	return (
		bool(entry.get("vision_chosik", false))
		or str(entry.get("debug_group", "")).strip_edges().to_lower() == "vision"
	)


func _is_peerless_mugong_entry(entry: Dictionary) -> bool:
	var rarity: String = str(entry.get("rarity", "")).strip_edges().to_lower()
	var debug_group: String = str(entry.get("debug_group", "")).strip_edges().to_lower()
	var tree: String = str(entry.get("tree", "")).strip_edges().to_lower()
	return rarity == "mythic" or debug_group == "converted_mythic" or tree == "mythic"


func _draw_card(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	entry: Dictionary,
	hovered: bool,
	levels: Dictionary,
	icon_renderer: Object
) -> void:
	var perk_id: String = str(entry.get("id", ""))
	var owned_level: int = int(levels.get(perk_id, 0))
	var apply_level: int = _get_apply_level_for_entry(entry)
	var is_last: bool = perk_id == last_applied_id and last_applied_timer > 0.0
	var base := Color(0.105, 0.125, 0.165, 0.96)
	if hovered:
		base = Color(0.14, 0.20, 0.27, 0.98)
	if is_last:
		base = base.lerp(Color(0.24, 0.34, 0.20, 1.0), 0.55)
	canvas.draw_rect(rect, base)
	canvas.draw_rect(rect, Color(0.25, 0.39, 0.52, 0.72), false, 1.0)

	var icon_rect := Rect2(rect.position + Vector2(9.0, (rect.size.y - ICON_SIZE) * 0.5), Vector2(ICON_SIZE, ICON_SIZE))
	var drew_icon := false
	if icon_renderer != null and icon_renderer.has_method("draw_icon"):
		drew_icon = bool(icon_renderer.draw_icon(canvas, perk_id, icon_rect, 1.0, true))
	if not drew_icon:
		var color: Color = _get_color(entry.get("icon_color", Color(0.5, 0.8, 1.0)), Color(0.5, 0.8, 1.0))
		canvas.draw_circle(icon_rect.get_center(), ICON_SIZE * 0.40, color)
		canvas.draw_circle(icon_rect.get_center() + Vector2(-5.0, -6.0), 3.0, Color(1.0, 1.0, 1.0, 0.28))

	var text_x: float = rect.position.x + 53.0
	var title: String = str(entry.get("name", perk_id)).strip_edges()
	if title.is_empty():
		title = perk_id
	canvas.draw_string(font, Vector2(text_x, rect.position.y + 20.0), title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 106.0, 13, Color(0.94, 0.98, 1.0))
	var status: String = _get_status_text(entry, owned_level, apply_level)
	canvas.draw_string(font, Vector2(text_x, rect.position.y + 39.0), status, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 106.0, 11, Color(0.68, 0.75, 0.83))

	var level_badge: String = _get_level_badge(entry, apply_level)
	var badge_size: Vector2 = font.get_string_size(level_badge, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12)
	var badge_rect := Rect2(rect.position + Vector2(rect.size.x - badge_size.x - 18.0, rect.size.y * 0.5 - 12.0), Vector2(badge_size.x + 10.0, 22.0))
	canvas.draw_rect(badge_rect, Color(0.05, 0.09, 0.13, 0.92))
	canvas.draw_rect(badge_rect, Color(1.0, 0.84, 0.30, 0.82), false, 1.0)
	canvas.draw_string(font, badge_rect.position + Vector2(5.0, 15.0), level_badge, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(1.0, 0.86, 0.36))


func _draw_hover_tooltip(
	canvas: CanvasItem,
	font: Font,
	entry: Dictionary,
	owned_level: int,
	card_rect: Rect2,
	view_size: Vector2
) -> void:
	var content: Dictionary = _build_hover_tooltip_content(entry, owned_level)
	var layout: Dictionary = _get_hover_tooltip_layout(font, content, view_size)
	var tooltip_size: Vector2 = layout.get("size", Vector2(TOOLTIP_MIN_WIDTH, 120.0))
	var tooltip_rect: Rect2 = _get_hover_tooltip_rect(card_rect, tooltip_size, view_size)
	var accent: Color = _get_color(entry.get("icon_color", Color(0.30, 0.78, 1.0)), Color(0.30, 0.78, 1.0))
	canvas.draw_rect(tooltip_rect, Color(0.018, 0.024, 0.038, 0.985))
	canvas.draw_rect(tooltip_rect, Color(accent.r, accent.g, accent.b, 0.92), false, 2.0)

	var text_x: float = tooltip_rect.position.x + TOOLTIP_PADDING
	var text_width: float = tooltip_rect.size.x - TOOLTIP_PADDING * 2.0
	var y: float = tooltip_rect.position.y + TOOLTIP_PADDING + 15.0
	for line_value in layout.get("title_lines", []):
		_draw_tooltip_text(canvas, font, str(line_value), Vector2(text_x, y), 16, Color(0.96, 0.99, 1.0))
		y += TOOLTIP_TITLE_LINE_HEIGHT

	_draw_tooltip_text(canvas, font, str(content.get("subtitle", "")), Vector2(text_x, y), 12, Color(accent.r, accent.g, accent.b, 0.96))
	y += TOOLTIP_BODY_LINE_HEIGHT + 7.0
	for line_value in layout.get("detail_lines", []):
		_draw_tooltip_text(canvas, font, str(line_value), Vector2(text_x, y), 13, Color(0.84, 0.89, 0.94))
		y += TOOLTIP_BODY_LINE_HEIGHT

	var stat_lines: Array = layout.get("stat_lines", [])
	if not stat_lines.is_empty():
		y += 5.0
		canvas.draw_line(Vector2(text_x, y), Vector2(text_x + text_width, y), Color(accent.r, accent.g, accent.b, 0.34), 1.0)
		y += 18.0
		_draw_tooltip_text(canvas, font, str(content.get("stats_heading", "효과")), Vector2(text_x, y), 12, Color(1.0, 0.84, 0.36))
		y += TOOLTIP_BODY_LINE_HEIGHT
		for line_value in stat_lines:
			_draw_tooltip_text(canvas, font, str(line_value), Vector2(text_x, y), 13, Color(0.74, 0.86, 0.97))
			y += TOOLTIP_BODY_LINE_HEIGHT


func _build_hover_tooltip_content(entry: Dictionary, owned_level: int) -> Dictionary:
	var perk_id: String = str(entry.get("id", ""))
	var title: String = str(entry.get("name", perk_id)).strip_edges()
	if title.is_empty():
		title = perk_id
	var apply_level: int = _get_apply_level_for_entry(entry)
	var kind: String = _get_hover_tooltip_kind(entry)
	var is_instant: bool = (
		apply_level <= 0 or bool(entry.get("is_instant", false))
	) and not bool(entry.get("is_physique_training", false))
	var subtitle: String = kind
	if bool(entry.get("is_physique_training", false)):
		subtitle += " · 1회 적용"
	elif is_instant:
		subtitle += " · 즉시 적용"
	else:
		subtitle += " · 적용 %s · 보유 %s" % [
			_debug_level_text(entry, apply_level),
			_debug_level_text(entry, max(0, owned_level)),
		]

	var detail: String = str(entry.get("detail", "")).strip_edges()
	var stats: String = _get_hover_tooltip_level_description(entry, apply_level)
	if detail.is_empty():
		detail = stats
		stats = ""
	elif stats == detail:
		stats = ""
	if detail.is_empty():
		detail = "상세 설명이 없습니다."

	var stats_heading := "효과"
	if apply_level > 0:
		stats_heading = "%s 효과" % _debug_level_text(entry, apply_level)
	if kind in ["초식", "비전초식"]:
		stats_heading = "습득 정보"

	return {
		"id": perk_id,
		"title": title,
		"subtitle": subtitle,
		"kind": kind,
		"detail": detail,
		"stats": stats,
		"stats_heading": stats_heading,
		"apply_level": apply_level,
		"owned_level": max(0, owned_level),
	}


func _get_hover_tooltip_kind(entry: Dictionary) -> String:
	if _is_vision_mugong_entry(entry):
		return "비전초식"
	if str(entry.get("unlocks_skill", "")).strip_edges() != "" or str(entry.get("id", "")).begins_with("unlock_"):
		return "초식"
	var debug_group: String = str(entry.get("debug_group", entry.get("tree", ""))).to_lower()
	if bool(entry.get("is_physique_training", false)) or debug_group == "training":
		return "수련"
	if debug_group == "lingpet":
		return "수호령 강화"
	var rarity: String = str(entry.get("rarity", "")).to_lower()
	if rarity == "mythic" or debug_group == "converted_mythic":
		return "절세무공"
	if bool(entry.get("is_instant", false)) or debug_group == "instant":
		return "즉시 효과"
	return "무공"


func _get_hover_tooltip_level_description(entry: Dictionary, apply_level: int) -> String:
	var descriptions_value: Variant = entry.get("descriptions", {})
	if descriptions_value is Dictionary:
		var descriptions: Dictionary = descriptions_value
		var lookup_level: int = max(1, apply_level)
		if descriptions.has(lookup_level):
			return str(descriptions.get(lookup_level, "")).strip_edges()
		var string_key := str(lookup_level)
		if descriptions.has(string_key):
			return str(descriptions.get(string_key, "")).strip_edges()
		var best_level := -1
		var best_text := ""
		for level_key_value in descriptions.keys():
			var level_key_text := str(level_key_value)
			if not level_key_text.is_valid_int():
				continue
			var level_key := int(level_key_text)
			if level_key <= lookup_level and level_key > best_level:
				best_level = level_key
				best_text = str(descriptions.get(level_key_value, "")).strip_edges()
		if not best_text.is_empty():
			return best_text
	return str(entry.get("description", "")).strip_edges()


func _get_hover_tooltip_layout(font: Font, content: Dictionary, view_size: Vector2) -> Dictionary:
	var width: float = min(TOOLTIP_MAX_WIDTH, max(TOOLTIP_MIN_WIDTH, view_size.x - TOOLTIP_VIEW_MARGIN * 2.0))
	var text_width: float = width - TOOLTIP_PADDING * 2.0
	var cache_key: int = hash([
		str(content.get("id", "")),
		str(content.get("title", "")),
		str(content.get("subtitle", "")),
		str(content.get("detail", "")),
		str(content.get("stats", "")),
		int(round(width)),
		int(round(view_size.y)),
	])
	var cached_value: Variant = _tooltip_layout_cache.get(cache_key, null)
	if cached_value is Dictionary:
		return cached_value

	var title_lines: Array[String] = _wrap_tooltip_text(font, str(content.get("title", "")), 16, text_width, 2)
	var detail_lines: Array[String] = _wrap_tooltip_text(font, str(content.get("detail", "")), 13, text_width, 64)
	var stat_lines: Array[String] = _wrap_tooltip_text(font, str(content.get("stats", "")), 13, text_width, 64)
	var fixed_height: float = TOOLTIP_PADDING * 2.0 + float(title_lines.size()) * TOOLTIP_TITLE_LINE_HEIGHT + TOOLTIP_BODY_LINE_HEIGHT + 7.0
	if not stat_lines.is_empty():
		fixed_height += 23.0 + TOOLTIP_BODY_LINE_HEIGHT
	var max_content_lines: int = max(2, int(floor((view_size.y - TOOLTIP_VIEW_MARGIN * 2.0 - fixed_height) / TOOLTIP_BODY_LINE_HEIGHT)))
	_fit_tooltip_line_budget(font, detail_lines, stat_lines, max_content_lines, text_width)
	var height: float = fixed_height + float(detail_lines.size() + stat_lines.size()) * TOOLTIP_BODY_LINE_HEIGHT
	var result := {
		"size": Vector2(width, min(height, view_size.y - TOOLTIP_VIEW_MARGIN * 2.0)),
		"title_lines": title_lines,
		"detail_lines": detail_lines,
		"stat_lines": stat_lines,
	}
	_tooltip_layout_cache[cache_key] = result
	return result


func _fit_tooltip_line_budget(font: Font, detail_lines: Array[String], stat_lines: Array[String], max_lines: int, max_width: float) -> void:
	var original_detail_count: int = detail_lines.size()
	var original_stat_count: int = stat_lines.size()
	while detail_lines.size() + stat_lines.size() > max_lines:
		if detail_lines.size() > max(1, stat_lines.size()):
			detail_lines.pop_back()
		elif stat_lines.size() > 1:
			stat_lines.pop_back()
		elif detail_lines.size() > 1:
			detail_lines.pop_back()
		else:
			break
	if detail_lines.size() < original_detail_count and not detail_lines.is_empty():
		detail_lines[detail_lines.size() - 1] = _ellipsize_tooltip_line(font, detail_lines[-1], 13, max_width)
	if stat_lines.size() < original_stat_count and not stat_lines.is_empty():
		stat_lines[stat_lines.size() - 1] = _ellipsize_tooltip_line(font, stat_lines[-1], 13, max_width)


func _ellipsize_tooltip_line(font: Font, text: String, font_size: int, max_width: float) -> String:
	var result: String = text.rstrip("…")
	while not result.is_empty() and font.get_string_size(result + "…", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > max_width:
		result = result.left(result.length() - 1)
	return result + "…"


func _wrap_tooltip_text(font: Font, text: String, font_size: int, max_width: float, max_lines: int) -> Array[String]:
	var lines: Array[String] = []
	if font == null or text.is_empty() or max_lines <= 0:
		return lines
	for paragraph_value in text.split("\n", true):
		var paragraph: String = str(paragraph_value).strip_edges()
		if paragraph.is_empty():
			continue
		var current := ""
		for word_value in paragraph.split(" ", false):
			var word: String = str(word_value)
			var candidate: String = word if current.is_empty() else "%s %s" % [current, word]
			if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width:
				current = candidate
				continue
			if not current.is_empty():
				lines.append(current)
				if lines.size() >= max_lines:
					return lines
				current = ""
			if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width:
				current = word
				continue
			for character_index in range(word.length()):
				var glyph: String = word.substr(character_index, 1)
				var glyph_candidate: String = current + glyph
				if current.is_empty() or font.get_string_size(glyph_candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width:
					current = glyph_candidate
					continue
				lines.append(current)
				if lines.size() >= max_lines:
					return lines
				current = glyph
		if not current.is_empty():
			lines.append(current)
			if lines.size() >= max_lines:
				return lines
	return lines


func _get_hover_tooltip_rect(card_rect: Rect2, tooltip_size: Vector2, view_size: Vector2) -> Rect2:
	var tooltip_pos := Vector2(card_rect.end.x + TOOLTIP_CARD_GAP, card_rect.position.y)
	if tooltip_pos.x + tooltip_size.x > view_size.x - TOOLTIP_VIEW_MARGIN:
		tooltip_pos.x = card_rect.position.x - tooltip_size.x - TOOLTIP_CARD_GAP
	if tooltip_pos.y + tooltip_size.y > view_size.y - TOOLTIP_VIEW_MARGIN:
		tooltip_pos.y = card_rect.end.y - tooltip_size.y
	tooltip_pos.x = clamp(tooltip_pos.x, TOOLTIP_VIEW_MARGIN, max(TOOLTIP_VIEW_MARGIN, view_size.x - tooltip_size.x - TOOLTIP_VIEW_MARGIN))
	tooltip_pos.y = clamp(tooltip_pos.y, TOOLTIP_VIEW_MARGIN, max(TOOLTIP_VIEW_MARGIN, view_size.y - tooltip_size.y - TOOLTIP_VIEW_MARGIN))
	return Rect2(tooltip_pos, tooltip_size)


func _draw_tooltip_text(canvas: CanvasItem, font: Font, text: String, baseline: Vector2, font_size: int, color: Color) -> void:
	canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 2, Color(0.0, 0.0, 0.0, 0.88))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _apply_entry(entry: Dictionary, owner: Object, registry: Object, catalog: Object) -> void:
	var runtime_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_state == null or not runtime_state.has_method("debug_set_perk_level"):
		return
	var perk_id: String = str(entry.get("id", ""))
	var applied: bool = bool(runtime_state.debug_set_perk_level(perk_id, _get_apply_level_for_entry(entry), owner, registry, catalog))
	if applied:
		last_applied_id = perk_id
		last_applied_timer = 0.65
		if _is_mythic_acquisition_cinematic_active(registry) or _is_guardian_enhance_cutin_active(registry):
			close()


func _adjust_target_level(mouse_event: InputEventMouseButton, entries: Array, view_size: Vector2) -> void:
	var index: int = _get_entry_index_at(mouse_event.position, view_size, entries)
	if index < 0:
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			page_index = max(0, page_index - 1)
		else:
			page_index = min(_get_page_count(entries.size()) - 1, page_index + 1)
		return
	var max_level: int = 5
	max_level = max(1, int(entries[index].get("max_level", 1)))
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		target_level = min(max_level, target_level + 1)
	else:
		target_level = max(1, target_level - 1)


func _get_apply_level_for_entry(entry: Dictionary) -> int:
	var max_level: int = max(0, int(entry.get("max_level", 1)))
	if max_level <= 0 or bool(entry.get("is_instant", false)):
		return 0
	return clampi(target_level, 1, max_level)


func _get_status_text(entry: Dictionary, owned_level: int, apply_level: int) -> String:
	var max_level: int = int(entry.get("max_level", 1))
	var group: String = str(entry.get("debug_group", entry.get("tree", "")))
	if bool(entry.get("is_physique_training", false)):
		# 상한은 카탈로그가 카드에 실어 보낸 값만 읽는다 — 리터럴 복사본을 두면
		# 수납술 상한(1회 → 3회)을 바꿀 때 배지만 옛 값으로 남는다.
		var training_max_count: int = int(entry.get("training_max_count", -1))
		if training_max_count > 0:
			return "수련 / %d회 한정" % training_max_count
		return "수련 / 반복 습득"
	if max_level <= 0 or bool(entry.get("is_instant", false)):
		return "%s / instant" % group
	return "%s / own %s -> %s" % [
		group,
		_debug_level_text(entry, owned_level),
		_debug_level_text(entry, apply_level),
	]


func _get_level_badge(entry: Dictionary, apply_level: int) -> String:
	var max_level: int = int(entry.get("max_level", 1))
	if bool(entry.get("is_physique_training", false)):
		return "수련"
	if max_level <= 0 or bool(entry.get("is_instant", false)):
		return "GO"
	return _debug_level_text(entry, apply_level)


func _debug_level_text(entry: Dictionary, level: int) -> String:
	var kind := _get_hover_tooltip_kind(entry)
	if kind == "수련":
		return "수련"
	if kind in ["초식", "비전초식", "무공", "절세무공"]:
		if level <= 0:
			return LanguageSettings.format_mugong_level(0, maxi(1, int(entry.get("max_level", 1))))
		return LanguageSettings.format_mugong_rank(entry, level)
	return "Lv.%d" % maxi(0, level)


func _get_entry_index_at(position: Vector2, view_size: Vector2, entries: Array) -> int:
	_clamp_page_index(entries.size())
	var visible_entries: Array = _get_visible_entries(entries)
	var panel_rect: Rect2 = _get_panel_rect(view_size, visible_entries.size())
	var layout: Dictionary = _build_grid_layout(panel_rect, visible_entries.size())
	var page_start: int = _get_page_start(entries.size())
	for index in range(visible_entries.size()):
		if _get_card_rect(index, panel_rect, layout).has_point(position):
			return page_start + index
	return -1


func _get_entries(catalog: Object, owner: Object) -> Array:
	if catalog != null and catalog.has_method("get_debug_perk_entries"):
		return catalog.get_debug_perk_entries(_get_character_type(owner))
	return []


func _get_cached_entries(catalog: Object, owner: Object) -> Array:
	var char_type: String = _get_character_type(owner)
	if not _cached_entries.is_empty() and char_type == _cached_entries_char_type:
		return _cached_entries
	_cache_entries_for_owner(owner, _get_entries(catalog, owner))
	_clamp_page_index(_cached_entries.size())
	return _cached_entries


func _cache_entries_for_owner(owner: Object, entries: Array) -> void:
	_cached_entries = entries
	_cached_entries_char_type = _get_character_type(owner)
	_tooltip_layout_cache.clear()


func _get_visible_entries(entries: Array) -> Array:
	var result: Array = []
	var page_start: int = _get_page_start(entries.size())
	var page_end: int = min(entries.size(), page_start + MAX_VISIBLE_CARDS)
	for index in range(page_start, page_end):
		result.append(entries[index])
	return result


func _get_page_start(entry_count: int) -> int:
	_clamp_page_index(entry_count)
	return page_index * MAX_VISIBLE_CARDS


func _get_page_count(entry_count: int) -> int:
	return max(1, int(ceil(float(max(0, entry_count)) / float(MAX_VISIBLE_CARDS))))


func _clamp_page_index(entry_count: int) -> void:
	page_index = clampi(page_index, 0, _get_page_count(entry_count) - 1)


func _handle_page_key(key_event: InputEventKey, entry_count: int) -> bool:
	var old_page := page_index
	match key_event.keycode:
		KEY_PAGEUP, KEY_LEFT:
			page_index = max(0, page_index - 1)
		KEY_PAGEDOWN, KEY_RIGHT:
			page_index = min(_get_page_count(entry_count) - 1, page_index + 1)
		KEY_HOME:
			page_index = 0
		KEY_END:
			page_index = _get_page_count(entry_count) - 1
		_:
			return false
	return page_index != old_page


func _get_cached_panel_layout(view_size: Vector2, entry_count: int) -> Dictionary:
	if (
		entry_count == _cached_layout_entry_count
		and is_equal_approx(view_size.x, _cached_layout_view_w)
		and is_equal_approx(view_size.y, _cached_layout_view_h)
		and _cached_panel_rect.size != Vector2.ZERO
	):
		return {"panel_rect": _cached_panel_rect, "layout": _cached_layout}
	_cached_panel_rect = _get_panel_rect(view_size, entry_count)
	_cached_layout = _build_grid_layout(_cached_panel_rect, entry_count)
	_cached_layout_view_w = view_size.x
	_cached_layout_view_h = view_size.y
	_cached_layout_entry_count = entry_count
	return {"panel_rect": _cached_panel_rect, "layout": _cached_layout}


func _prewarm_text_metrics(entries: Array) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	_touch_font_text(font, "F4 초식 · 무공 디버그", 18)
	_touch_font_text(font, "탭 선택 · 호버 상세 · 좌클릭 적용 · 휠 단계 · 우클릭/Esc 닫기", 12)
	for definition_value in TAB_DEFINITIONS:
		if definition_value is Dictionary:
			_touch_font_text(font, "%s 99" % str((definition_value as Dictionary).get("label", "")), 12)
	for label in ["초식", "비전초식", "무공", "절세무공", "즉시 효과", "수호령 강화", "즉시 적용", "습득 정보", "효과", "상세 설명이 없습니다."]:
		_touch_font_text(font, str(label), 13)
	for level in range(1, 6):
		_touch_font_text(font, "목표 단계 %d" % level, 18)
		_touch_font_text(font, LanguageSettings.format_mugong_level(level, 5), 12)
		_touch_font_text(font, "Lv.%d" % level, 12)
	_touch_font_text(font, "GO", 12)
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var entry_data: Dictionary = entry
		var perk_id: String = str(entry_data.get("id", ""))
		var title: String = str(entry_data.get("name", perk_id)).strip_edges()
		if title.is_empty():
			title = perk_id
		_touch_font_text(font, title, 13)
		var max_level: int = max(0, int(entry_data.get("max_level", 1)))
		var sample_level: int = 0 if max_level <= 0 or bool(entry_data.get("is_instant", false)) else clampi(target_level, 1, max_level)
		_touch_font_text(font, _get_status_text(entry_data, 0, sample_level), 11)
		_touch_font_text(font, _get_level_badge(entry_data, sample_level), 12)
		_touch_font_text(font, str(entry_data.get("detail", "")), 13)
		_touch_font_text(font, str(entry_data.get("description", "")), 13)
		var descriptions_value: Variant = entry_data.get("descriptions", {})
		if descriptions_value is Dictionary:
			for description_value in (descriptions_value as Dictionary).values():
				_touch_font_text(font, str(description_value), 13)


func _touch_font_text(font: Font, text: String, font_size: int) -> void:
	if text.is_empty():
		return
	for line_value in text.split("\n", true):
		var line: String = str(line_value)
		if not line.is_empty():
			font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)


func _get_panel_rect(view_size: Vector2, entry_count: int) -> Rect2:
	var width: float = min(PANEL_MAX_WIDTH, max(520.0, view_size.x - PANEL_MARGIN * 2.0))
	var columns: int = _get_column_count(width)
	var rows: int = int(ceil(float(max(1, entry_count)) / float(max(1, columns))))
	var content_height: float = HEADER_HEIGHT + float(rows) * CARD_HEIGHT + float(max(0, rows - 1)) * CARD_GAP + 24.0
	var height: float = min(max(360.0, content_height), max(360.0, view_size.y - PANEL_MARGIN * 2.0))
	var x: float = floor((view_size.x - width) * 0.5)
	var y: float = floor((view_size.y - height) * 0.5)
	return Rect2(Vector2(x, y), Vector2(width, height))


func _build_grid_layout(panel_rect: Rect2, entry_count: int) -> Dictionary:
	var columns: int = _get_column_count(panel_rect.size.x)
	var inner_width: float = panel_rect.size.x - 24.0
	var card_width: float = floor((inner_width - float(columns - 1) * CARD_GAP) / float(columns))
	var rows: int = int(ceil(float(max(1, entry_count)) / float(columns)))
	var available_height: float = max(160.0, panel_rect.size.y - HEADER_HEIGHT - 22.0)
	var row_height: float = min(CARD_HEIGHT, floor((available_height - float(max(0, rows - 1)) * CARD_GAP) / float(max(1, rows))))
	row_height = max(42.0, row_height)
	return {
		"columns": columns,
		"card_width": card_width,
		"row_height": row_height,
	}


func _get_card_rect(index: int, panel_rect: Rect2, layout: Dictionary) -> Rect2:
	var columns: int = max(1, int(layout.get("columns", 3)))
	var column: int = index % columns
	@warning_ignore("integer_division")
	var row: int = int(index / columns)
	var card_width: float = float(layout.get("card_width", MIN_CARD_WIDTH))
	var row_height: float = float(layout.get("row_height", CARD_HEIGHT))
	var x: float = panel_rect.position.x + 12.0 + float(column) * (card_width + CARD_GAP)
	var y: float = panel_rect.position.y + HEADER_HEIGHT + float(row) * (row_height + CARD_GAP)
	return Rect2(Vector2(x, y), Vector2(card_width, row_height))


func _get_column_count(width: float) -> int:
	return clampi(int(floor((width - 24.0 + CARD_GAP) / (MIN_CARD_WIDTH + CARD_GAP))), 3, 5)


func _get_runtime_levels(runtime_state: Object, owner: Object) -> Dictionary:
	if runtime_state != null and runtime_state.has_method("get_snapshot"):
		var snapshot: Variant = runtime_state.get_snapshot()
		if snapshot is Dictionary:
			var levels: Variant = snapshot.get("runtime_skill_levels", {})
			if levels is Dictionary:
				return levels
	if owner != null:
		var owner_levels: Variant = owner.get("runtime_perk_levels")
		if owner_levels is Dictionary:
			return owner_levels
	return {}


func _get_character_type(owner: Object) -> String:
	if owner == null:
		return "smasher"
	var value: Variant = owner.get("selected_character_type")
	if value == null:
		return "smasher"
	return str(value)


func _get_mouse_position(canvas: CanvasItem) -> Vector2:
	var viewport: Viewport = canvas.get_viewport()
	if viewport == null:
		return Vector2(-9999.0, -9999.0)
	return viewport.get_mouse_position()


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _is_mythic_acquisition_cinematic_active(registry: Object) -> bool:
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("is_acquisition_cinematic_active"):
		return false
	return bool(mythic_item_runtime.is_acquisition_cinematic_active())


func _is_guardian_enhance_cutin_active(registry: Object) -> bool:
	var lingpet_runtime: Object = _get_instance(registry, "lingpet_egg_runtime")
	if lingpet_runtime == null or not lingpet_runtime.has_method("is_guardian_enhance_cutin_active"):
		return false
	return bool(lingpet_runtime.is_guardian_enhance_cutin_active())


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback
