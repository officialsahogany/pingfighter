extends RefCounted

const CARD_RADIUS := 8.0
const PANEL_RADIUS := 8.0
const CHOICE_MODAL_PARTICLE_DRAW_LIMIT := 10
const CHOICE_MODAL_PARTICLE_COMPACT_LIFE_RATIO := 0.68
const CHOICE_FLIGHT_PARTICLE_DRAW_LIMIT := 6
const CHOICE_FLIGHT_SOURCE_RING_COUNT := 1
const CHOICE_FLIGHT_ARRIVAL_RING_COUNT := 1
const FLIGHT_SOURCE_ARC_SEGMENTS := 10
const FLIGHT_CORE_ARC_SEGMENTS := 8
const FLIGHT_ARRIVAL_ARC_SEGMENTS := 10
const PERK_UNLOCK_SYMBOL_ARC_SEGMENTS := 20
const PERK_FALLBACK_SYMBOL_ARC_SEGMENTS := 24
const TITLE_TEXT := "스킬 강화!"
const TITLE_FONT_SIZE := 34
const TITLE_SHADOW_DRAW_COUNT := 1
const TEXT_FIT_CACHE_LIMIT := 160
const TEXT_SIZE_CACHE_LIMIT := 160

var _fallback_font: Font = null
var _draw_now_msec := 0
var _title_text_size := Vector2.ZERO
var _title_text_line: TextLine = null
var _title_text_line_font_id := 0
var _text_fit_cache: Dictionary = {}
var _text_size_cache: Dictionary = {}
var _text_cache_font_id := 0


func prewarm_assets() -> void:
	var font: Font = _get_font()
	if font == null:
		return
	_prepare_text_caches()
	_get_title_text_line(font)
	_get_title_text_size(font)
	for sample in [
		{"text": TITLE_TEXT, "size": TITLE_FONT_SIZE},
		{"text": "Lv.1", "size": 18},
		{"text": "Lv.5", "size": 18},
		{"text": "+1", "size": 11},
		{"text": "A", "size": 12},
		{"text": "G", "size": 20},
		{"text": "...", "size": 12},
	]:
		_get_text_size(font, str(sample.get("text", "")), int(sample.get("size", 14)))
	_get_fitted_text(font, TITLE_TEXT, 18, 12, 180.0)


func has_visible_effects(
	runtime_state: Object,
	mythic_item_runtime: Object = null,
	treasure_hunt_runtime: Object = null
) -> bool:
	if _runtime_state_has_visible_effects(runtime_state):
		return true
	if mythic_item_runtime != null and mythic_item_runtime.has_method("is_activation_effect_active"):
		if bool(mythic_item_runtime.is_activation_effect_active()):
			return true
	if treasure_hunt_runtime != null and treasure_hunt_runtime.has_method("is_effect_active"):
		if bool(treasure_hunt_runtime.is_effect_active()):
			return true
	return false


func draw(
	canvas: CanvasItem,
	runtime_state: Object,
	catalog: Object,
	view_size: Vector2,
	icon_renderer: Object = null,
	mythic_item_runtime: Object = null,
	treasure_hunt_runtime: Object = null,
	perf_logger: Object = null
) -> void:
	if canvas == null or runtime_state == null or not runtime_state.has_method("is_choice_active"):
		return
	_draw_now_msec = Time.get_ticks_msec()
	_prepare_text_caches()
	if not bool(runtime_state.is_choice_active()):
		var inactive_start: int = _perf_begin(perf_logger)
		_draw_feedback(canvas, runtime_state, view_size)
		_perf_end(perf_logger, "hud.perk_overlay.feedback", inactive_start)
		inactive_start = _perf_begin(perf_logger)
		_draw_mythic_item_effect(canvas, mythic_item_runtime, view_size)
		_perf_end(perf_logger, "hud.perk_overlay.mythic_effect", inactive_start)
		inactive_start = _perf_begin(perf_logger)
		_draw_treasure_hunt_effect(canvas, treasure_hunt_runtime, view_size)
		_perf_end(perf_logger, "hud.perk_overlay.treasure_effect", inactive_start)
		return

	var sample_start: int = _perf_begin(perf_logger)
	var snapshot: Dictionary = runtime_state.get_snapshot()
	_perf_end(perf_logger, "hud.perk_overlay.snapshot", sample_start)
	if runtime_state.has_method("has_pending_unlock_swap") and bool(runtime_state.has_pending_unlock_swap()):
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 20.0 / 255.0, 0.68))
		sample_start = _perf_begin(perf_logger)
		_draw_particles(canvas, snapshot)
		_perf_end(perf_logger, "hud.perk_overlay.swap_particles", sample_start)
		sample_start = _perf_begin(perf_logger)
		_draw_unlock_swap_dialog(canvas, runtime_state, snapshot, view_size, icon_renderer)
		_perf_end(perf_logger, "hud.perk_overlay.swap_dialog", sample_start)
		sample_start = _perf_begin(perf_logger)
		_draw_feedback(canvas, runtime_state, view_size)
		_perf_end(perf_logger, "hud.perk_overlay.feedback", sample_start)
		return
	var choices: Array = _get_array(snapshot.get("current_choices", []))
	if choices.is_empty():
		return

	var selected_index: int = int(snapshot.get("selected_index", 0))
	sample_start = _perf_begin(perf_logger)
	var layout: Dictionary = runtime_state.build_layout(view_size)
	_perf_end(perf_logger, "hud.perk_overlay.layout", sample_start)

	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 20.0 / 255.0, 0.62))
	sample_start = _perf_begin(perf_logger)
	_draw_particles(canvas, snapshot)
	_perf_end(perf_logger, "hud.perk_overlay.particles", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_title(canvas, _get_vector2(layout.get("title_pos", Vector2.ZERO)), float(snapshot.get("animation_time", 0.0)))
	_perf_end(perf_logger, "hud.perk_overlay.title", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_cards(canvas, runtime_state, choices, selected_index, view_size, float(snapshot.get("animation_time", 0.0)), icon_renderer)
	_perf_end(perf_logger, "hud.perk_overlay.cards", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_description(canvas, choices, selected_index, _get_rect2(layout.get("desc_rect", Rect2())))
	_perf_end(perf_logger, "hud.perk_overlay.description", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_status_panel(canvas, runtime_state, snapshot, catalog, _get_rect2(layout.get("panel_rect", Rect2())), icon_renderer)
	_perf_end(perf_logger, "hud.perk_overlay.status_panel", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_pending_hint(canvas, snapshot, _get_vector2(layout.get("hint_pos", Vector2.ZERO)), runtime_state)
	_perf_end(perf_logger, "hud.perk_overlay.pending_hint", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_feedback(canvas, runtime_state, view_size)
	_perf_end(perf_logger, "hud.perk_overlay.feedback", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_mythic_item_effect(canvas, mythic_item_runtime, view_size)
	_perf_end(perf_logger, "hud.perk_overlay.mythic_effect", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_treasure_hunt_effect(canvas, treasure_hunt_runtime, view_size)
	_perf_end(perf_logger, "hud.perk_overlay.treasure_effect", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_choice_flight_effect(canvas, _get_dict(snapshot.get("choice_flight_effect", {})), icon_renderer)
	_perf_end(perf_logger, "hud.perk_overlay.choice_flight", sample_start)


func _runtime_state_has_visible_effects(runtime_state: Object) -> bool:
	if runtime_state == null:
		return false
	if runtime_state.has_method("is_choice_active") and bool(runtime_state.is_choice_active()):
		return true
	if runtime_state.has_method("is_choice_flight_active") and bool(runtime_state.is_choice_flight_active()):
		return true
	if runtime_state.has_method("has_feedback") and bool(runtime_state.has_feedback()):
		return true
	if runtime_state.has_method("get_snapshot"):
		var snapshot: Dictionary = _get_dict(runtime_state.get_snapshot())
		if float(snapshot.get("feedback_timer", 0.0)) > 0.0 and str(snapshot.get("feedback_text", "")) != "":
			return true
		var flight_effect: Dictionary = _get_dict(snapshot.get("choice_flight_effect", {}))
		if bool(flight_effect.get("active", false)):
			return true
	return false


func _draw_title(canvas: CanvasItem, center: Vector2, animation_time: float) -> void:
	var font: Font = _get_font()
	if font == null:
		return
	var alpha: float = clamp(animation_time / 0.22, 0.0, 1.0)
	if alpha <= 0.001:
		return
	var title_line: TextLine = _get_title_text_line(font)
	if title_line == null:
		return
	var text_size: Vector2 = _get_title_text_size(font)
	var pos := center - Vector2(text_size.x * 0.5, text_size.y * 0.28)
	var canvas_rid: RID = canvas.get_canvas_item()
	for glow in range(TITLE_SHADOW_DRAW_COUNT, 0, -1):
		title_line.draw(
			canvas_rid,
			pos + Vector2(float(glow), float(glow)) * 0.75,
			Color(1.0, 190.0 / 255.0, 70.0 / 255.0, alpha * 0.24 * float(glow))
		)
	title_line.draw(canvas_rid, pos, Color(1.0, 220.0 / 255.0, 100.0 / 255.0, alpha))


func _get_title_text_size(font: Font) -> Vector2:
	if _title_text_size == Vector2.ZERO:
		var title_line: TextLine = _get_title_text_line(font)
		if title_line != null:
			_title_text_size = title_line.get_size()
		else:
			_title_text_size = font.get_string_size(TITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TITLE_FONT_SIZE)
	return _title_text_size


func _get_title_text_line(font: Font) -> TextLine:
	if font == null:
		return null
	var font_id: int = font.get_instance_id()
	if _title_text_line != null and _title_text_line_font_id == font_id:
		return _title_text_line
	var title_line := TextLine.new()
	if not title_line.add_string(TITLE_TEXT, font, TITLE_FONT_SIZE):
		return null
	_title_text_line = title_line
	_title_text_line_font_id = font_id
	_title_text_size = title_line.get_size()
	return _title_text_line


func _draw_cards(canvas: CanvasItem, runtime_state: Object, choices: Array, selected_index: int, view_size: Vector2, animation_time: float, icon_renderer: Object) -> void:
	var rects: Array = runtime_state.get_card_rects(view_size)
	for index in range(min(choices.size(), rects.size())):
		var choice: Dictionary = _get_dict(choices[index])
		var rect: Rect2 = rects[index]
		var selected: bool = index == selected_index
		_draw_card(canvas, choice, rect, selected, animation_time, icon_renderer)


func _draw_card(canvas: CanvasItem, choice: Dictionary, rect: Rect2, selected: bool, animation_time: float, icon_renderer: Object) -> void:
	var icon_color: Color = _get_color(choice.get("icon_color", Color(100.0 / 255.0, 150.0 / 255.0, 1.0)))
	var rarity: String = str(choice.get("rarity", "common"))
	var is_unique: bool = bool(choice.get("is_unique", false)) or rarity == "legendary"
	var is_dowsing_bonus: bool = bool(choice.get("is_dowsing_goggles_bonus", false))
	var pulse: float = 0.5 + 0.5 * sin(float(_get_draw_msec()) * 0.006)
	var alpha: float = clamp(animation_time / 0.24, 0.0, 1.0)

	if is_dowsing_bonus:
		var bonus_color := Color(60.0 / 255.0, 220.0 / 255.0, 200.0 / 255.0, (0.18 + 0.18 * pulse) * alpha)
		for grow in [12.0, 8.0, 4.0]:
			canvas.draw_rect(rect.grow(grow), bonus_color, false, max(1.2, 4.0 - grow * 0.18))
	if selected:
		var glow_color: Color = Color(icon_color.r, icon_color.g, icon_color.b, 0.20 + 0.18 * pulse)
		for grow in [10.0, 6.0, 3.0]:
			canvas.draw_rect(rect.grow(grow), glow_color, false, max(1.0, 6.0 - grow * 0.35))
	elif is_unique:
		canvas.draw_rect(rect.grow(5.0), Color(1.0, 210.0 / 255.0, 40.0 / 255.0, 0.18 + 0.12 * pulse), false, 2.0)
	_draw_character_outer_glow(canvas, rect, str(choice.get("character_restriction", "")), alpha, pulse)

	var bg: Color = Color(25.0 / 255.0, 30.0 / 255.0, 50.0 / 255.0, 0.86 * alpha)
	if selected:
		bg = Color(40.0 / 255.0, 50.0 / 255.0, 90.0 / 255.0, 0.94 * alpha)
	elif is_unique:
		bg = Color(45.0 / 255.0, 38.0 / 255.0, 20.0 / 255.0, 0.90 * alpha)
	canvas.draw_rect(rect, bg)

	var border_color: Color = icon_color if selected else Color(60.0 / 255.0, 70.0 / 255.0, 90.0 / 255.0, alpha)
	if is_unique:
		border_color = Color(1.0, 215.0 / 255.0, 0.0, alpha)
	elif is_dowsing_bonus:
		border_color = Color(60.0 / 255.0, 220.0 / 255.0, 200.0 / 255.0, alpha)
	canvas.draw_rect(rect, border_color, false, 3.0 if selected else 2.0)
	_draw_character_edge(canvas, rect, str(choice.get("character_restriction", "")), alpha, pulse)

	var icon_margin: float = max(10.0, rect.size.y * 0.13)
	var icon_size: float = rect.size.y - icon_margin * 2.0
	var icon_rect := Rect2(rect.position + Vector2(12.0, icon_margin), Vector2(icon_size, icon_size))
	canvas.draw_rect(icon_rect, Color(15.0 / 255.0, 19.0 / 255.0, 31.0 / 255.0, 0.92 * alpha))
	canvas.draw_rect(icon_rect, Color(icon_color.r, icon_color.g, icon_color.b, 0.70 * alpha), false, 2.0)
	_draw_icon(canvas, icon_renderer, choice, icon_rect, alpha)

	var text_x: float = icon_rect.end.x + 10.0
	var name := str(choice.get("name", "알 수 없음"))
	var name_color: Color = Color(1.0, 215.0 / 255.0, 0.0, alpha) if is_unique else Color(1.0, 1.0, 1.0, alpha)
	var text_max_width: float = max(32.0, rect.end.x - text_x - 14.0)
	_draw_text_fitted(canvas, name, Vector2(text_x, rect.position.y + rect.size.y * 0.38), 18, name_color, text_max_width, 12)
	_draw_text_fitted(canvas, _level_text(choice), Vector2(text_x, rect.position.y + rect.size.y * 0.67), 14, _level_color(choice, is_unique, alpha), text_max_width, 10)

	if is_dowsing_bonus:
		var bonus_badge := Rect2(rect.end - Vector2(39.0, rect.size.y - 8.0), Vector2(30.0, 18.0))
		canvas.draw_rect(bonus_badge, Color(10.0 / 255.0, 46.0 / 255.0, 46.0 / 255.0, 0.92 * alpha))
		canvas.draw_rect(bonus_badge, Color(90.0 / 255.0, 1.0, 220.0 / 255.0, 0.84 * alpha), false, 1.0)
		_draw_text_centered(canvas, "+1", bonus_badge.get_center() + Vector2(0.0, 1.0), 11, Color(220.0 / 255.0, 1.0, 245.0 / 255.0, alpha))

	if _shows_character_unlock_badge(choice):
		var badge_rect := Rect2(rect.end - Vector2(33.0, 27.0), Vector2(24.0, 18.0))
		canvas.draw_rect(badge_rect, Color(18.0 / 255.0, 32.0 / 255.0, 42.0 / 255.0, 0.92 * alpha))
		canvas.draw_rect(badge_rect, Color(icon_color.r, icon_color.g, icon_color.b, 0.82 * alpha), false, 1.0)
		_draw_text_centered(canvas, "A", badge_rect.get_center() + Vector2(0.0, 1.0), 12, Color(1.0, 1.0, 1.0, alpha))


func _draw_unlock_swap_dialog(canvas: CanvasItem, runtime_state: Object, snapshot: Dictionary, view_size: Vector2, icon_renderer: Object) -> void:
	var swap: Dictionary = _get_dict(snapshot.get("pending_unlock_swap", {}))
	var candidates: Array = _get_array(swap.get("candidates", []))
	if candidates.is_empty():
		return
	var selected_index: int = clampi(int(snapshot.get("unlock_swap_selected_index", 0)), 0, candidates.size() - 1)
	var layout: Dictionary = runtime_state.build_unlock_swap_layout(view_size) if runtime_state.has_method("build_unlock_swap_layout") else {}
	var panel_rect: Rect2 = _get_rect2(layout.get("panel_rect", Rect2(Vector2(view_size.x * 0.5 - 240.0, view_size.y * 0.5 - 140.0), Vector2(480.0, 280.0))))
	canvas.draw_rect(panel_rect, Color(12.0 / 255.0, 18.0 / 255.0, 32.0 / 255.0, 0.95))
	canvas.draw_rect(panel_rect, Color(1.0, 190.0 / 255.0, 80.0 / 255.0, 0.86), false, 2.5)
	canvas.draw_line(panel_rect.position + Vector2(18.0, 88.0), Vector2(panel_rect.end.x - 18.0, panel_rect.position.y + 88.0), Color(1.0, 190.0 / 255.0, 80.0 / 255.0, 0.45), 1.0)

	_draw_text_centered(canvas, "화기 슬롯 교체", _get_vector2(layout.get("title_pos", panel_rect.position + Vector2(panel_rect.size.x * 0.5, 38.0))), 24, Color(1.0, 225.0 / 255.0, 125.0 / 255.0))
	_draw_text_centered(canvas, "새 화기: %s" % str(swap.get("new_name", swap.get("unlocks_skill", ""))), _get_vector2(layout.get("new_skill_pos", panel_rect.position + Vector2(panel_rect.size.x * 0.5, 70.0))), 15, Color(210.0 / 255.0, 225.0 / 255.0, 240.0 / 255.0))

	var rects: Array = runtime_state.get_unlock_swap_option_rects(view_size) if runtime_state.has_method("get_unlock_swap_option_rects") else []
	for index in range(min(candidates.size(), rects.size())):
		var candidate: Dictionary = _get_dict(candidates[index])
		var rect: Rect2 = rects[index]
		var selected: bool = index == selected_index
		var skill_id: String = str(candidate.get("skill_id", ""))
		var pulse: float = 0.5 + 0.5 * sin(float(_get_draw_msec()) * 0.006)
		if selected:
			for grow in [8.0, 4.0]:
				canvas.draw_rect(rect.grow(grow), Color(1.0, 190.0 / 255.0, 80.0 / 255.0, (0.16 + 0.12 * pulse)), false, max(1.0, 4.0 - grow * 0.25))
		canvas.draw_rect(rect, Color(24.0 / 255.0, 31.0 / 255.0, 46.0 / 255.0, 0.94))
		canvas.draw_rect(rect, Color(1.0, 205.0 / 255.0, 90.0 / 255.0, 0.90 if selected else 0.42), false, 2.0 if selected else 1.2)
		var icon_rect := Rect2(rect.position + Vector2(rect.size.x * 0.5 - 24.0, 16.0), Vector2(48.0, 48.0))
		canvas.draw_rect(icon_rect, Color(10.0 / 255.0, 14.0 / 255.0, 24.0 / 255.0, 0.88))
		if icon_renderer == null or not icon_renderer.has_method("draw_icon") or not bool(icon_renderer.draw_icon(canvas, skill_id, icon_rect.grow(-4.0), 1.0, true)):
			canvas.draw_circle(icon_rect.get_center(), 18.0, Color(0.52, 0.62, 0.50, 0.92))
		_draw_text_fitted(canvas, str(candidate.get("name", skill_id)), rect.position + Vector2(12.0, rect.size.y - 28.0), 14, Color(0.94, 0.97, 1.0), rect.size.x - 24.0, 10)

	_draw_text_centered(canvas, "Enter 선택 / Esc 취소", _get_vector2(layout.get("hint_pos", panel_rect.end - Vector2(panel_rect.size.x * 0.5, 34.0))), 13, Color(170.0 / 255.0, 180.0 / 255.0, 210.0 / 255.0, 0.94))


func _draw_character_edge(canvas: CanvasItem, rect: Rect2, restriction: String, alpha: float, pulse: float) -> void:
	if restriction == "":
		return
	var theme: Dictionary = _character_edge_theme(restriction, alpha, pulse)
	if theme.is_empty():
		return
	var main: Color = theme.get("main", Color(0.0, 0.0, 0.0, 0.0))
	var accent: Color = theme.get("accent", main)
	var highlight: Color = theme.get("highlight", accent)
	var edge_alpha: float = (0.36 + 0.18 * pulse) * alpha
	var accent_alpha: float = (0.42 + 0.20 * pulse) * alpha
	var highlight_alpha: float = (0.22 + 0.16 * pulse) * alpha
	var main_color := Color(main.r, main.g, main.b, edge_alpha)
	var accent_color := Color(accent.r, accent.g, accent.b, accent_alpha)
	var highlight_color := Color(highlight.r, highlight.g, highlight.b, highlight_alpha)
	var marker: String = str(theme.get("marker", "energy"))

	canvas.draw_rect(rect.grow(3.0), main_color, false, 1.6)
	canvas.draw_rect(rect.grow(-2.0), highlight_color, false, 1.0)

	var corner_len: float = min(18.0, rect.size.x * 0.16)
	_draw_character_edge_corners(canvas, rect, accent_color, highlight_color, corner_len)

	if marker == "poison":
		_draw_viper_edge_marks(canvas, rect, accent_color, highlight_color, pulse)
	elif marker == "mecha":
		_draw_optimus_edge_marks(canvas, rect, accent_color, highlight_color, pulse)
	elif marker == "tactical":
		_draw_soldier_edge_marks(canvas, rect, accent_color, highlight_color, pulse)
	else:
		_draw_smasher_edge_marks(canvas, rect, accent_color, highlight_color, pulse)


func _draw_character_outer_glow(canvas: CanvasItem, rect: Rect2, restriction: String, alpha: float, pulse: float) -> void:
	if restriction == "":
		return
	var theme: Dictionary = _character_edge_theme(restriction, alpha, pulse)
	if theme.is_empty():
		return
	var main: Color = theme.get("main", Color(0.0, 0.0, 0.0, 0.0))
	for grow in [8.0, 4.0]:
		var glow_alpha: float = (0.07 + 0.06 * pulse) * alpha * (1.0 - grow / 12.0)
		if glow_alpha > 0.001:
			canvas.draw_rect(rect.grow(grow), Color(main.r, main.g, main.b, glow_alpha), false, max(1.0, 3.2 - grow * 0.18))


func _character_edge_theme(restriction: String, alpha: float = 1.0, pulse: float = 0.5) -> Dictionary:
	match restriction:
		"smasher":
			return {
				"main": Color(0.0, 200.0 / 255.0, 1.0, alpha),
				"accent": Color(120.0 / 255.0, 240.0 / 255.0, 1.0, alpha),
				"highlight": Color(210.0 / 255.0, 1.0, 1.0, alpha),
				"marker": "energy",
				"pulse": pulse,
			}
		"viper":
			return {
				"main": Color(160.0 / 255.0, 0.0, 220.0 / 255.0, alpha),
				"accent": Color(200.0 / 255.0, 80.0 / 255.0, 1.0, alpha),
				"highlight": Color(240.0 / 255.0, 160.0 / 255.0, 1.0, alpha),
				"marker": "poison",
				"pulse": pulse,
			}
		"optimus":
			return {
				"main": Color(1.0, 140.0 / 255.0, 0.0, alpha),
				"accent": Color(1.0, 200.0 / 255.0, 80.0 / 255.0, alpha),
				"highlight": Color(1.0, 230.0 / 255.0, 150.0 / 255.0, alpha),
				"marker": "mecha",
				"pulse": pulse,
			}
		"soldier", "commando":
			return {
				"main": Color(80.0 / 255.0, 200.0 / 255.0, 60.0 / 255.0, alpha),
				"accent": Color(150.0 / 255.0, 240.0 / 255.0, 110.0 / 255.0, alpha),
				"highlight": Color(210.0 / 255.0, 1.0, 190.0 / 255.0, alpha),
				"marker": "tactical",
				"pulse": pulse,
			}
		_:
			return {}


func _draw_character_edge_corners(canvas: CanvasItem, rect: Rect2, accent: Color, highlight: Color, corner_len: float) -> void:
	var left: float = rect.position.x + 5.0
	var right: float = rect.end.x - 5.0
	var top: float = rect.position.y + 5.0
	var bottom: float = rect.end.y - 5.0
	var corners: Array[Dictionary] = [
		{"point": Vector2(left, top), "dir": Vector2(1.0, 1.0)},
		{"point": Vector2(right, top), "dir": Vector2(-1.0, 1.0)},
		{"point": Vector2(left, bottom), "dir": Vector2(1.0, -1.0)},
		{"point": Vector2(right, bottom), "dir": Vector2(-1.0, -1.0)},
	]
	for corner in corners:
		var point: Vector2 = corner.get("point", Vector2.ZERO)
		var dir: Vector2 = corner.get("dir", Vector2.ONE)
		canvas.draw_line(point, point + Vector2(corner_len * dir.x, 0.0), accent, 2.0)
		canvas.draw_line(point, point + Vector2(0.0, corner_len * dir.y), accent, 2.0)
		canvas.draw_line(point, point + Vector2(corner_len * 0.56 * dir.x, 0.0), highlight, 1.0)


func _draw_smasher_edge_marks(canvas: CanvasItem, rect: Rect2, accent: Color, highlight: Color, pulse: float) -> void:
	var segment_count := 4
	var top_y: float = rect.position.y + 2.0
	var bottom_y: float = rect.end.y - 2.0
	var usable_w: float = rect.size.x - 34.0
	for index in range(segment_count):
		var x0: float = rect.position.x + 17.0 + usable_w * float(index) / float(segment_count)
		var x1: float = rect.position.x + 17.0 + usable_w * float(index + 1) / float(segment_count) - 6.0
		var jitter: float = sin(float(_get_draw_msec()) * 0.012 + float(index) * 1.7) * (1.0 + pulse)
		canvas.draw_line(Vector2(x0, top_y + jitter), Vector2(x1, top_y - jitter), accent, 1.0)
		canvas.draw_line(Vector2(x0, bottom_y - jitter), Vector2(x1, bottom_y + jitter), highlight, 1.0)


func _draw_viper_edge_marks(canvas: CanvasItem, rect: Rect2, accent: Color, highlight: Color, pulse: float) -> void:
	var positions: Array[Vector2] = [
		rect.position + Vector2(rect.size.x * 0.50, 4.0),
		rect.position + Vector2(rect.size.x - 5.0, rect.size.y * 0.45),
		rect.position + Vector2(rect.size.x * 0.48, rect.size.y - 5.0),
		rect.position + Vector2(4.0, rect.size.y * 0.56),
	]
	for index in range(positions.size()):
		var radius: float = 1.8 + 1.2 * ((pulse + float(index) * 0.31) - floor(pulse + float(index) * 0.31))
		var color: Color = highlight if index % 2 == 0 else accent
		canvas.draw_circle(positions[index], radius, color)


func _draw_optimus_edge_marks(canvas: CanvasItem, rect: Rect2, accent: Color, highlight: Color, pulse: float) -> void:
	var dot_y_top: float = rect.position.y + 4.0
	var dot_y_bottom: float = rect.end.y - 4.0
	for ratio in [0.36, 0.50, 0.64]:
		var x: float = rect.position.x + rect.size.x * float(ratio)
		var dot_radius: float = 1.4 + pulse * 0.9
		canvas.draw_circle(Vector2(x, dot_y_top), dot_radius, accent)
		canvas.draw_circle(Vector2(x, dot_y_bottom), dot_radius, highlight)
	var scan_y: float = rect.position.y + 11.0 + (rect.size.y - 22.0) * pulse
	canvas.draw_line(rect.position + Vector2(7.0, scan_y), Vector2(rect.end.x - 7.0, scan_y), Color(accent.r, accent.g, accent.b, accent.a * 0.32), 1.0)


func _draw_soldier_edge_marks(canvas: CanvasItem, rect: Rect2, accent: Color, highlight: Color, _pulse: float) -> void:
	var centers: Array[Vector2] = [
		rect.position + Vector2(11.0, 11.0),
		rect.position + Vector2(rect.size.x - 11.0, 11.0),
		rect.position + Vector2(11.0, rect.size.y - 11.0),
		rect.position + Vector2(rect.size.x - 11.0, rect.size.y - 11.0),
	]
	for center in centers:
		canvas.draw_line(center + Vector2(-3.5, 0.0), center + Vector2(3.5, 0.0), accent, 1.6)
		canvas.draw_line(center + Vector2(0.0, -3.5), center + Vector2(0.0, 3.5), highlight, 1.2)
	var dash_len := 6.0
	var gap := 8.0
	var y: float = rect.position.y + 22.0
	while y < rect.end.y - 22.0:
		canvas.draw_line(Vector2(rect.position.x + 2.0, y), Vector2(rect.position.x + 2.0, min(y + dash_len, rect.end.y - 22.0)), accent, 1.4)
		canvas.draw_line(Vector2(rect.end.x - 2.0, y), Vector2(rect.end.x - 2.0, min(y + dash_len, rect.end.y - 22.0)), accent, 1.4)
		y += dash_len + gap


func _draw_description(canvas: CanvasItem, choices: Array, selected_index: int, rect: Rect2) -> void:
	if selected_index < 0 or selected_index >= choices.size():
		return
	var choice: Dictionary = _get_dict(choices[selected_index])
	var icon_color: Color = _get_color(choice.get("icon_color", Color.WHITE))
	canvas.draw_rect(rect, Color(30.0 / 255.0, 35.0 / 255.0, 55.0 / 255.0, 0.90))
	canvas.draw_rect(rect, Color(icon_color.r, icon_color.g, icon_color.b, 0.82), false, 2.0)

	var title := str(choice.get("name", "알 수 없음"))
	var level_info := _long_level_text(choice)
	var title_max_width: float = min(rect.size.x * 0.48, rect.size.x - 170.0)
	_draw_text_fitted(canvas, title, rect.position + Vector2(14.0, 22.0), 16, Color.WHITE, title_max_width, 11)
	_draw_text_fitted(canvas, level_info, rect.position + Vector2(14.0 + title_max_width + 10.0, 23.0), 13, Color(1.0, 205.0 / 255.0, 120.0 / 255.0), rect.size.x - title_max_width - 38.0, 10)

	var desc_lines: Array = _wrap_text(str(choice.get("description", "")), 48, 2)
	for i in range(desc_lines.size()):
		_draw_text(canvas, str(desc_lines[i]), rect.position + Vector2(14.0, 47.0 + float(i) * 18.0), 13, Color(210.0 / 255.0, 220.0 / 255.0, 235.0 / 255.0))


func _draw_status_panel(canvas: CanvasItem, runtime_state: Object, snapshot: Dictionary, catalog: Object, rect: Rect2, icon_renderer: Object) -> void:
	canvas.draw_rect(rect, Color(12.0 / 255.0, 18.0 / 255.0, 32.0 / 255.0, 0.82))
	canvas.draw_rect(rect, Color(110.0 / 255.0, 96.0 / 255.0, 58.0 / 255.0, 0.72), false, 2.0)
	canvas.draw_line(rect.position + Vector2(12.0, 3.0), Vector2(rect.end.x - 12.0, rect.position.y + 3.0), Color(190.0 / 255.0, 160.0 / 255.0, 82.0 / 255.0, 0.65), 1.0)

	var levels: Dictionary = _get_dict(snapshot.get("runtime_skill_levels", {}))
	var pending: int = int(snapshot.get("pending_skill_choices", 0))
	var gold: int = int(snapshot.get("gold_from_perks", 0))

	_draw_text(canvas, "◆ 현재 퍽", rect.position + Vector2(14.0, 23.0), 14, Color(1.0, 215.0 / 255.0, 100.0 / 255.0))
	_draw_text(canvas, "선택 대기: %d" % pending, rect.position + Vector2(rect.size.x - 118.0, 23.0), 13, Color(170.0 / 255.0, 180.0 / 255.0, 210.0 / 255.0))
	_draw_text(canvas, "퍽 골드: %d" % gold, rect.position + Vector2(rect.size.x - 118.0, 45.0), 13, Color(1.0, 215.0 / 255.0, 100.0 / 255.0))

	var acquired: Array = _build_acquired_perks(levels, catalog, runtime_state)
	if acquired.is_empty():
		_draw_text(canvas, "획득한 퍽 없음", rect.position + Vector2(108.0, 27.0), 13, Color(115.0 / 255.0, 120.0 / 255.0, 140.0 / 255.0))
		return

	var icon_size := 27.0
	var gap := 6.0
	var start := rect.position + Vector2(108.0, 18.0)
	var max_count: int = max(1, int((rect.size.x - 122.0) / (icon_size + gap)))
	for idx in range(min(max_count, acquired.size())):
		var skill: Dictionary = acquired[idx]
		var icon_rect := Rect2(start + Vector2(float(idx) * (icon_size + gap), 0.0), Vector2(icon_size, icon_size))
		var color: Color = _get_color(skill.get("icon_color", Color(100.0 / 255.0, 150.0 / 255.0, 1.0)))
		canvas.draw_rect(icon_rect, Color(max(0.0, color.r - 0.28), max(0.0, color.g - 0.28), max(0.0, color.b - 0.28), 0.92))
		canvas.draw_rect(icon_rect, Color(color.r, color.g, color.b, 0.72), false, 1.0)
		_draw_icon(canvas, icon_renderer, skill, icon_rect.grow(-4.0), 1.0)
		var badge := Rect2(icon_rect.end - Vector2(12.0, 12.0), Vector2(12.0, 12.0))
		canvas.draw_circle(badge.get_center(), 6.0, Color(1.0, 215.0 / 255.0, 70.0 / 255.0))
		_draw_text_centered(canvas, str(skill.get("level", 1)), badge.get_center() + Vector2(0.0, 1.0), 9, Color(42.0 / 255.0, 30.0 / 255.0, 0.0))
	if acquired.size() > max_count:
		_draw_text(canvas, "+%d" % (acquired.size() - max_count), start + Vector2(float(max_count) * (icon_size + gap), 20.0), 13, Color(160.0 / 255.0, 160.0 / 255.0, 175.0 / 255.0))


func _draw_pending_hint(canvas: CanvasItem, snapshot: Dictionary, pos: Vector2, runtime_state: Object) -> void:
	var selectable: bool = runtime_state.has_method("is_selectable") and bool(runtime_state.is_selectable())
	var text := "마우스 클릭 또는 ← → / Enter 로 선택"
	if not selectable:
		text = "선택지를 불러오는 중"
	_draw_text_centered(canvas, text, pos, 13, Color(170.0 / 255.0, 180.0 / 255.0, 210.0 / 255.0, 0.92))
	var pending: int = int(snapshot.get("pending_skill_choices", 0))
	if pending > 1:
		_draw_text_centered(canvas, "추가 %d개" % (pending - 1), pos + Vector2(0.0, -22.0), 12, Color(1.0, 220.0 / 255.0, 100.0 / 255.0, 0.95))


func _draw_feedback(canvas: CanvasItem, runtime_state: Object, view_size: Vector2) -> void:
	if runtime_state == null or not runtime_state.has_method("get_snapshot"):
		return
	var snapshot: Dictionary = runtime_state.get_snapshot()
	var timer: float = float(snapshot.get("feedback_timer", 0.0))
	var text: String = str(snapshot.get("feedback_text", ""))
	if timer <= 0.0 or text == "":
		return
	var alpha: float = clamp(timer, 0.0, 1.0)
	var center := Vector2(view_size.x * 0.5, view_size.y * 0.20 - (1.0 - alpha) * 16.0)
	var font: Font = _get_font()
	if font == null:
		return
	var size := 18
	var text_size: Vector2 = _get_text_size(font, text, size)
	var bg := Rect2(center - Vector2(text_size.x * 0.5 + 16.0, 22.0), Vector2(text_size.x + 32.0, 34.0))
	canvas.draw_rect(bg, Color(12.0 / 255.0, 18.0 / 255.0, 32.0 / 255.0, 0.72 * alpha))
	canvas.draw_rect(bg, Color(1.0, 215.0 / 255.0, 90.0 / 255.0, 0.58 * alpha), false, 1.0)
	canvas.draw_string(font, center - Vector2(text_size.x * 0.5, -5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, Color(1.0, 230.0 / 255.0, 130.0 / 255.0, alpha))


func _draw_mythic_item_effect(canvas: CanvasItem, mythic_item_runtime: Object, view_size: Vector2) -> void:
	if mythic_item_runtime != null and mythic_item_runtime.has_method("draw_activation_effect"):
		mythic_item_runtime.draw_activation_effect(canvas, view_size)


func _draw_treasure_hunt_effect(canvas: CanvasItem, treasure_hunt_runtime: Object, view_size: Vector2) -> void:
	if treasure_hunt_runtime != null and treasure_hunt_runtime.has_method("draw_effect"):
		treasure_hunt_runtime.draw_effect(canvas, view_size)


func _draw_particles(canvas: CanvasItem, snapshot: Dictionary) -> void:
	var particles: Array = _get_array(snapshot.get("particles", []))
	var particle_start: int = _recent_start(particles, CHOICE_MODAL_PARTICLE_DRAW_LIMIT)
	for particle_index in range(particle_start, particles.size()):
		var particle_value: Variant = particles[particle_index]
		var particle: Dictionary = _get_dict(particle_value)
		var pos: Vector2 = _get_vector2(particle.get("position", Vector2.ZERO))
		if pos == Vector2.ZERO:
			continue
		var age: float = float(particle.get("age", 0.0))
		var life_ratio: float = clamp(1.0 - age / 1.45, 0.0, 1.0)
		if life_ratio <= 0.0:
			continue
		var color: Color = _get_color(particle.get("color", Color.WHITE))
		var size: float = float(particle.get("size", 3.0))
		if life_ratio >= CHOICE_MODAL_PARTICLE_COMPACT_LIFE_RATIO:
			canvas.draw_circle(pos, size * (1.0 + 0.4 * life_ratio), Color(color.r, color.g, color.b, 0.18 * life_ratio))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, 0.76 * life_ratio))


func _draw_choice_flight_effect(canvas: CanvasItem, effect: Dictionary, icon_renderer: Object) -> void:
	if not bool(effect.get("active", false)):
		return
	var age: float = max(0.0, float(effect.get("age", 0.0)))
	var duration: float = max(0.001, float(effect.get("duration", 1.86)))
	var progress: float = clamp(age / duration, 0.0, 1.0)
	var source: Vector2 = _get_vector2(effect.get("source_pos", Vector2.ZERO))
	var target: Vector2 = _get_vector2(effect.get("target_pos", Vector2.ZERO))
	if source == Vector2.ZERO or target == Vector2.ZERO:
		return
	var color: Color = _get_color(effect.get("icon_color", Color(0.45, 0.75, 1.0)))
	var pulse: float = 0.5 + 0.5 * sin(float(_get_draw_msec()) * 0.018)
	_draw_choice_flight_source_card_fade(canvas, _get_rect2(effect.get("source_rect", Rect2())), color, progress)
	_draw_choice_flight_source_burst(canvas, source, color, progress, pulse)
	_draw_choice_flight_particles(canvas, source, target, effect, color, age)
	_draw_choice_flight_core(canvas, source, target, effect, icon_renderer, color, age, duration, pulse)
	_draw_choice_flight_arrival(canvas, target, color, progress, pulse)


func _draw_choice_flight_source_card_fade(canvas: CanvasItem, source_rect: Rect2, color: Color, progress: float) -> void:
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return
	var alpha: float = clamp(progress * 3.0, 0.0, 1.0)
	canvas.draw_rect(source_rect.grow(3.0), Color(color.r, color.g, color.b, 0.22 * alpha), false, 2.0)
	canvas.draw_rect(source_rect, Color(4.0 / 255.0, 8.0 / 255.0, 18.0 / 255.0, 0.46 * alpha))


func _draw_choice_flight_source_burst(canvas: CanvasItem, source: Vector2, color: Color, progress: float, pulse: float) -> void:
	var alpha: float = clamp(1.0 - progress * 3.2, 0.0, 1.0)
	if alpha <= 0.0:
		return
	for ring in range(CHOICE_FLIGHT_SOURCE_RING_COUNT):
		var ring_t: float = clamp(progress * 3.0 - float(ring) * 0.18, 0.0, 1.0)
		if ring_t <= 0.0:
			continue
		var radius: float = lerpf(14.0 + float(ring) * 8.0, 74.0 + float(ring) * 12.0, _ease_out_cubic(ring_t))
		canvas.draw_arc(source, radius, 0.0, TAU, FLIGHT_SOURCE_ARC_SEGMENTS, Color(color.r, color.g, color.b, alpha * (0.32 - float(ring) * 0.07)), 2.2)
	canvas.draw_circle(source, 24.0 + pulse * 8.0, Color(color.r, color.g, color.b, alpha * 0.18))


func _draw_choice_flight_particles(canvas: CanvasItem, source: Vector2, target: Vector2, effect: Dictionary, base_color: Color, age: float) -> void:
	var particles: Array = _get_array(effect.get("particles", []))
	var particle_start: int = _recent_start(particles, CHOICE_FLIGHT_PARTICLE_DRAW_LIMIT)
	for particle_index in range(particle_start, particles.size()):
		var value: Variant = particles[particle_index]
		var particle: Dictionary = _get_dict(value)
		var delay: float = float(particle.get("delay", 0.0))
		var duration: float = max(0.001, float(particle.get("duration", 0.75)))
		var t: float = clamp((age - delay) / duration, 0.0, 1.0)
		if t <= 0.0 or t >= 1.0:
			continue
		var eased: float = _ease_in_out_cubic(t)
		var arc: float = float(particle.get("arc", 64.0))
		var side_offset: float = float(particle.get("side_offset", 0.0)) * float(particle.get("side", 1.0))
		var pos: Vector2 = _choice_flight_bezier(source, target, eased, arc, side_offset)
		var prev_pos: Vector2 = _choice_flight_bezier(source, target, clamp(eased - 0.035, 0.0, 1.0), arc, side_offset)
		var fade: float = sin(t * PI)
		var color: Color = _get_color(particle.get("color", base_color))
		var size: float = float(particle.get("size", 3.0)) * (0.75 + 0.45 * fade)
		canvas.draw_line(prev_pos, pos, Color(color.r, color.g, color.b, 0.32 * fade), max(1.0, size * 0.65))
		canvas.draw_circle(pos, size * 2.3, Color(color.r, color.g, color.b, 0.11 * fade))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, 0.78 * fade))


func _draw_choice_flight_core(
	canvas: CanvasItem,
	source: Vector2,
	target: Vector2,
	effect: Dictionary,
	icon_renderer: Object,
	color: Color,
	age: float,
	duration: float,
	pulse: float
) -> void:
	var core_t: float = clamp((age - 0.10) / max(0.001, duration * 0.76), 0.0, 1.0)
	var eased: float = _ease_out_cubic(core_t)
	var pos: Vector2 = _choice_flight_bezier(source, target, eased, 104.0, 0.0)
	var alpha: float = clamp(sin(clamp(core_t, 0.0, 1.0) * PI) * 1.25, 0.0, 1.0)
	if core_t >= 0.96:
		alpha *= clamp(1.0 - (core_t - 0.96) / 0.04, 0.0, 1.0)
	if alpha <= 0.0:
		return
	var size: float = lerpf(62.0, 34.0, eased) * (1.0 + 0.05 * pulse)
	var rect := Rect2(pos - Vector2(size, size) * 0.5, Vector2(size, size))
	canvas.draw_circle(pos, size * 0.72, Color(color.r, color.g, color.b, 0.24 * alpha))
	canvas.draw_arc(pos, size * 0.58, -PI * 0.35 + age * 5.0, PI * 1.55 + age * 5.0, FLIGHT_CORE_ARC_SEGMENTS, Color(1.0, 1.0, 1.0, 0.55 * alpha), 2.2)
	var icon_choice: Dictionary = _get_dict(effect.get("choice", {})).duplicate(true)
	var skill_id: String = str(effect.get("skill_id", ""))
	if skill_id != "":
		icon_choice["id"] = skill_id
	_draw_icon(canvas, icon_renderer, icon_choice, rect.grow(-6.0), alpha)


func _draw_choice_flight_arrival(canvas: CanvasItem, target: Vector2, color: Color, progress: float, pulse: float) -> void:
	var arrival: float = clamp((progress - 0.56) / 0.44, 0.0, 1.0)
	if arrival <= 0.0:
		return
	var settle: float = _ease_out_cubic(arrival)
	for ring in range(CHOICE_FLIGHT_ARRIVAL_RING_COUNT):
		var local_t: float = clamp(arrival - float(ring) * 0.12, 0.0, 1.0)
		if local_t <= 0.0:
			continue
		var radius: float = lerpf(88.0 + float(ring) * 12.0, 22.0 + float(ring) * 5.0, _ease_out_cubic(local_t))
		var alpha: float = (1.0 - local_t) * 0.34 + 0.12
		canvas.draw_arc(target, radius, 0.0, TAU, FLIGHT_ARRIVAL_ARC_SEGMENTS, Color(color.r, color.g, color.b, alpha * (1.0 - float(ring) * 0.18)), 2.4)
	var core_radius: float = lerpf(4.0, 19.0 + pulse * 2.0, settle)
	canvas.draw_circle(target, core_radius * 1.85, Color(color.r, color.g, color.b, 0.16 * settle))
	canvas.draw_circle(target, core_radius, Color(color.r, color.g, color.b, 0.58 * settle))
	canvas.draw_circle(target, max(2.0, core_radius * 0.38), Color(1.0, 1.0, 1.0, 0.78 * settle))


func _choice_flight_bezier(source: Vector2, target: Vector2, t: float, arc: float, side_offset: float) -> Vector2:
	var direction: Vector2 = target - source
	var normal := Vector2.ZERO
	if direction.length() > 0.001:
		normal = Vector2(-direction.y, direction.x).normalized()
	var control: Vector2 = (source + target) * 0.5 + Vector2(0.0, -arc) + normal * side_offset
	var inv: float = 1.0 - t
	return source * inv * inv + control * 2.0 * inv * t + target * t * t


func _recent_start(values: Array, render_limit: int) -> int:
	if render_limit <= 0:
		return values.size()
	return max(0, values.size() - render_limit)


func _ease_out_cubic(t: float) -> float:
	var inv: float = 1.0 - clamp(t, 0.0, 1.0)
	return 1.0 - inv * inv * inv


func _ease_in_out_cubic(t: float) -> float:
	var clamped: float = clamp(t, 0.0, 1.0)
	if clamped < 0.5:
		return 4.0 * clamped * clamped * clamped
	var f: float = -2.0 * clamped + 2.0
	return 1.0 - f * f * f * 0.5


func _draw_icon(canvas: CanvasItem, icon_renderer: Object, skill: Dictionary, rect: Rect2, alpha: float) -> void:
	var skill_id: String = str(skill.get("id", ""))
	if icon_renderer != null and icon_renderer.has_method("draw_icon"):
		if bool(icon_renderer.draw_icon(canvas, skill_id, rect, alpha, true)):
			return
	_draw_perk_symbol(canvas, rect, _get_color(skill.get("icon_color", Color.WHITE)), str(skill.get("tree", "")), skill_id, alpha)


func _draw_perk_symbol(canvas: CanvasItem, rect: Rect2, color: Color, tree: String, skill_id: String, alpha: float) -> void:
	var center: Vector2 = rect.get_center()
	var radius: float = min(rect.size.x, rect.size.y) * 0.36
	var c := Color(color.r, color.g, color.b, alpha)
	var hi := Color(1.0, 1.0, 1.0, 0.82 * alpha)
	if skill_id == "convert_to_gold":
		canvas.draw_circle(center, radius, Color(1.0, 200.0 / 255.0, 40.0 / 255.0, 0.95 * alpha))
		_draw_text_centered(canvas, "G", center + Vector2(0.0, 2.0), int(radius * 1.35), Color(70.0 / 255.0, 42.0 / 255.0, 0.0, alpha))
	elif tree.find("unlock") >= 0:
		canvas.draw_circle(center, radius, Color(c.r, c.g, c.b, 0.36 * alpha))
		canvas.draw_arc(center, radius, -PI * 0.75, PI * 0.75, PERK_UNLOCK_SYMBOL_ARC_SEGMENTS, c, 3.0)
		canvas.draw_line(center + Vector2(-radius * 0.45, 0.0), center + Vector2(radius * 0.45, 0.0), hi, 2.0)
		canvas.draw_line(center + Vector2(0.0, -radius * 0.45), center + Vector2(0.0, radius * 0.45), hi, 2.0)
	elif tree == "dash":
		var points: PackedVector2Array = [
			center + Vector2(-radius * 0.8, radius * 0.5),
			center + Vector2(-radius * 0.1, -radius * 0.8),
			center + Vector2(radius * 0.05, -radius * 0.15),
			center + Vector2(radius * 0.8, -radius * 0.35),
			center + Vector2(radius * 0.05, radius * 0.8),
			center + Vector2(-radius * 0.08, radius * 0.15),
		]
		canvas.draw_colored_polygon(points, c)
		canvas.draw_polyline(points, hi, 1.2, true)
	elif tree == "item":
		canvas.draw_rect(Rect2(center - Vector2(radius * 0.75, radius * 0.52), Vector2(radius * 1.5, radius * 1.05)), Color(c.r, c.g, c.b, 0.72 * alpha))
		canvas.draw_line(center + Vector2(-radius * 0.55, -radius * 0.62), center + Vector2(radius * 0.55, -radius * 0.62), hi, 2.0)
		canvas.draw_line(center + Vector2(0.0, -radius * 0.75), center + Vector2(0.0, radius * 0.55), hi, 1.4)
	else:
		canvas.draw_circle(center, radius, Color(c.r, c.g, c.b, 0.36 * alpha))
		canvas.draw_arc(center, radius, 0.0, TAU, PERK_FALLBACK_SYMBOL_ARC_SEGMENTS, c, 2.4)
		canvas.draw_circle(center, radius * 0.36, hi)


func _build_acquired_perks(levels: Dictionary, catalog: Object, runtime_state: Object = null) -> Array:
	var result: Array = []
	for skill_id in levels.keys():
		var base_level: int = int(levels[skill_id])
		if base_level <= 0:
			continue
		var skill_id_text: String = str(skill_id)
		var level: int = _get_effective_runtime_perk_level(runtime_state, skill_id_text, base_level)
		var data: Dictionary = {}
		if catalog != null and catalog.has_method("get_perk_data"):
			data = catalog.get_perk_data(skill_id_text)
		if data.is_empty():
			data = {"name": skill_id_text, "icon_color": Color(100.0 / 255.0, 150.0 / 255.0, 1.0), "tree": ""}
		data = data.duplicate(true)
		data["id"] = skill_id_text
		data["base_level"] = base_level
		data["level"] = level
		result.append(data)
	result.sort_custom(Callable(self, "_sort_perks_by_level"))
	return result


func _get_effective_runtime_perk_level(runtime_state: Object, skill_id: String, base_level: int) -> int:
	if base_level <= 0:
		return base_level
	if runtime_state != null and runtime_state.has_method("get_runtime_skill_level"):
		return max(0, int(runtime_state.get_runtime_skill_level(skill_id)))
	return base_level


func _sort_perks_by_level(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("level", 0)) > int(b.get("level", 0))


func _level_text(choice: Dictionary) -> String:
	if bool(choice.get("is_gold_conversion", false)):
		return "골드"
	if bool(choice.get("is_instant", false)):
		return "즉시"
	if _shows_character_unlock_badge(choice):
		return "해금"
	return "Lv.%d" % int(choice.get("next_level", 1))


func _long_level_text(choice: Dictionary) -> String:
	if bool(choice.get("is_gold_conversion", false)):
		return "  (500골드)"
	if bool(choice.get("is_instant", false)):
		return "  (즉시 효과)"
	if _shows_character_unlock_badge(choice):
		return "  (액티브 해금)"
	return "  (Lv.%d → Lv.%d)" % [int(choice.get("current_level", 0)), int(choice.get("next_level", 1))]


func _shows_character_unlock_badge(choice: Dictionary) -> bool:
	return int(choice.get("max_level", 1)) <= 1 and str(choice.get("character_restriction", "")) != ""


func _level_color(choice: Dictionary, unique: bool, alpha: float) -> Color:
	if unique:
		return Color(1.0, 205.0 / 255.0, 50.0 / 255.0, alpha)
	if bool(choice.get("is_instant", false)):
		return Color(100.0 / 255.0, 1.0, 200.0 / 255.0, alpha)
	return Color(1.0, 200.0 / 255.0, 100.0 / 255.0, alpha)


func _wrap_text(text: String, max_chars: int, max_lines: int) -> Array:
	var lines: Array = []
	var remaining := text.strip_edges()
	while remaining.length() > max_chars and lines.size() < max_lines:
		lines.append(remaining.substr(0, max_chars))
		remaining = remaining.substr(max_chars).strip_edges()
	if remaining != "" and lines.size() < max_lines:
		lines.append(remaining)
	return lines


func _draw_text(canvas: CanvasItem, text: String, baseline: Vector2, font_size: int, color: Color) -> void:
	var font: Font = _get_font()
	if font == null or text == "":
		return
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_text_fitted(canvas: CanvasItem, text: String, baseline: Vector2, font_size: int, color: Color, max_width: float, min_font_size: int = 10) -> void:
	var font: Font = _get_font()
	if font == null or text == "" or max_width <= 0.0:
		return
	var fit: Dictionary = _get_fitted_text(font, text, font_size, min_font_size, max_width)
	var fitted_text: String = str(fit.get("text", ""))
	var fitted_size: int = int(fit.get("font_size", font_size))
	if fitted_text == "":
		return
	canvas.draw_string(font, baseline, fitted_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted_size, color)


func _get_fitted_text(font: Font, text: String, font_size: int, min_font_size: int, max_width: float) -> Dictionary:
	var cache_key: String = "%d|%d|%d|%d|%s" % [
		font.get_instance_id(),
		font_size,
		min_font_size,
		int(ceil(max_width)),
		text,
	]
	if _text_fit_cache.has(cache_key):
		var cached_fit: Variant = _text_fit_cache[cache_key]
		if cached_fit is Dictionary:
			return cached_fit
	var fitted_size: int = font_size
	while fitted_size > min_font_size and _get_text_size(font, text, fitted_size).x > max_width:
		fitted_size -= 1
	var fitted_text: String = text
	if _get_text_size(font, fitted_text, fitted_size).x > max_width:
		fitted_text = _ellipsize_to_width(font, text, max_width, fitted_size)
	var fit := {
		"text": fitted_text,
		"font_size": fitted_size,
	}
	_store_limited_cache(_text_fit_cache, cache_key, fit, TEXT_FIT_CACHE_LIMIT)
	return fit


func _ellipsize_to_width(font: Font, text: String, max_width: float, font_size: int) -> String:
	var suffix := "..."
	if _get_text_size(font, suffix, font_size).x > max_width:
		return ""
	var output := text
	while output.length() > 0:
		var candidate := output + suffix
		if _get_text_size(font, candidate, font_size).x <= max_width:
			return candidate
		output = output.substr(0, output.length() - 1)
	return suffix


func _draw_text_centered(canvas: CanvasItem, text: String, center: Vector2, font_size: int, color: Color) -> void:
	var font: Font = _get_font()
	if font == null or text == "":
		return
	var size: Vector2 = _get_text_size(font, text, font_size)
	canvas.draw_string(font, center - Vector2(size.x * 0.5, -size.y * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _prepare_text_caches() -> void:
	var font: Font = _get_font()
	var font_id := 0
	if font != null:
		font_id = font.get_instance_id()
	if _text_cache_font_id == font_id:
		return
	_text_cache_font_id = font_id
	_text_fit_cache.clear()
	_text_size_cache.clear()


func _get_text_size(font: Font, text: String, font_size: int) -> Vector2:
	var cache_key: String = "%d|%d|%s" % [font.get_instance_id(), font_size, text]
	if _text_size_cache.has(cache_key):
		var cached_size: Variant = _text_size_cache[cache_key]
		if cached_size is Vector2:
			return cached_size
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	_store_limited_cache(_text_size_cache, cache_key, size, TEXT_SIZE_CACHE_LIMIT)
	return size


func _store_limited_cache(cache: Dictionary, key: String, value: Variant, limit: int) -> void:
	if limit <= 0:
		return
	if not cache.has(key) and cache.size() >= limit:
		var keys: Array = cache.keys()
		if not keys.is_empty():
			cache.erase(keys[0])
	cache[key] = value


func _get_font() -> Font:
	if _fallback_font == null:
		_fallback_font = ThemeDB.fallback_font
	return _fallback_font


func _get_draw_msec() -> int:
	if _draw_now_msec <= 0:
		return Time.get_ticks_msec()
	return _draw_now_msec


func _get_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color.WHITE


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _get_rect2(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2()


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
