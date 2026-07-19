extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")
const RuntimePerkOverflowDescriptions := preload("res://scripts/characters/runtime_perk_overflow_descriptions.gd")
const TutorialHintKeycapRenderer := preload("res://scripts/hud/tutorial_hint_keycap_renderer.gd")
const AngelBlessingRollOverlayHost := preload("res://scripts/hud/angel_blessing_roll_overlay_host.gd")
const MysticDiceOverlayRenderer := preload("res://scripts/hud/mystic_dice_overlay_renderer.gd")
const PerkFusionOverlayRenderer := preload("res://scripts/hud/perk_fusion_overlay_renderer.gd")
const PerkFusionColdBootCinematic := preload("res://scripts/hud/perk_fusion_cold_boot_cinematic.gd")

const CARD_RADIUS := 8.0
const PANEL_RADIUS := 8.0
const CHOICE_MODAL_PARTICLE_DRAW_LIMIT := 10
const CHOICE_MODAL_PARTICLE_COMPACT_LIFE_RATIO := 0.68
const CHOICE_FLIGHT_PARTICLE_DRAW_LIMIT := 6
const CHOICE_FLIGHT_SOURCE_RING_COUNT := 1
const CHOICE_FLIGHT_ARRIVAL_RING_COUNT := 1
# Starpoint absorption: small spiral-descent visual that plays after the perk
# modal fully closes. Mirrors the data layout written by
# runtime_perk_state.gd's `_start_starpoint_absorption_effect` /
# `_update_starpoint_absorption_effect`.
const STARPOINT_ABSORPTION_ARRIVAL_ARC_SEGMENTS := 24
const STARPOINT_ABSORPTION_STAR_TIP_COUNT := 5
const STARPOINT_ABSORPTION_GLOW_COLOR := Color(1.0, 0.65, 0.85, 1.0)
const STARPOINT_ABSORPTION_FILL_COLOR := Color(1.0, 0.85, 0.4, 1.0)
const STARPOINT_ABSORPTION_OUTLINE_COLOR := Color(1.0, 1.0, 0.55, 1.0)
const STARPOINT_ABSORPTION_BURST_COLOR := Color(1.0, 0.95, 0.55, 1.0)
const FLIGHT_SOURCE_ARC_SEGMENTS := 10
const FLIGHT_CORE_ARC_SEGMENTS := 8
const FLIGHT_ARRIVAL_ARC_SEGMENTS := 10
const PERK_UNLOCK_SYMBOL_ARC_SEGMENTS := 20
const PERK_FALLBACK_SYMBOL_ARC_SEGMENTS := 24
const TITLE_TEXT := "스킬 강화!"
const UNLOCK_SHOWCASE_TITLE_TEXT := "새 스킬 획득!"
const UNLOCK_SHOWCASE_PROMPT_TEXT := "아무 키나 눌러 계속"
const TITLE_FONT_SIZE := 34
const MYTHIC_GOLD_DEEP := Color(1.0, 178.0 / 255.0, 44.0 / 255.0)
const MYTHIC_GOLD_BRIGHT := Color(1.0, 224.0 / 255.0, 120.0 / 255.0)
const MYTHIC_GOLD_HIGHLIGHT := Color(1.0, 247.0 / 255.0, 214.0 / 255.0)
const MYTHIC_GOLD_AMBER := Color(1.0, 150.0 / 255.0, 30.0 / 255.0)
const MYTHIC_ORNAMENT_SPARKLE_COUNT := 7
const MYTHIC_ORNAMENT_COMPACT_SPARKLE_COUNT := 5
const MYTHIC_ORNAMENT_CROWN_MIN_REF := 70.0
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
var _back_glow_stylebox: StyleBoxFlat = null
# Per-card description wrap cache: rebuilt only when the choice set or card
# width changes (the modal redraws every frame for its animation).
var _card_desc_cache_signature := 0
var _card_desc_cache: Array = []


# 시스템 카드 모달 전용 렌더러(오버레이 소유 — draw 밖 prewarm_assets에서
# 함께 프리웜).
var _mystic_dice_overlay_renderer: Object = MysticDiceOverlayRenderer.new()
var _perk_fusion_overlay_renderer: Object = PerkFusionOverlayRenderer.new()


func prewarm_assets() -> void:
	AngelBlessingRollOverlayHost.prewarm_assets()
	_mystic_dice_overlay_renderer.prewarm_assets()
	_perk_fusion_overlay_renderer.prewarm_assets()
	PerkFusionColdBootCinematic.prewarm_assets()
	var font: Font = _get_font()
	if font == null:
		return
	_prepare_text_caches()
	_get_title_text_line(font)
	_get_title_text_size(font)
	for sample in [
		{"text": TITLE_TEXT, "size": TITLE_FONT_SIZE},
		{"text": UNLOCK_SHOWCASE_TITLE_TEXT, "size": 24},
		{"text": UNLOCK_SHOWCASE_PROMPT_TEXT, "size": 14},
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
		# Starpoint absorption fires AFTER the modal closes, so the renderer must
		# read its state from the inactive branch as well. Snapshot is cheap when
		# the effect dict is empty (just one Dictionary.get + early return).
		inactive_start = _perf_begin(perf_logger)
		_draw_starpoint_absorption_effect(canvas, runtime_state)
		_perf_end(perf_logger, "hud.perk_overlay.starpoint_absorption", inactive_start)
		return

	var sample_start: int = _perf_begin(perf_logger)
	var snapshot: Dictionary = runtime_state.get_snapshot()
	_perf_end(perf_logger, "hud.perk_overlay.snapshot", sample_start)
	# 퍽 융합 모달(S1~S4): 표준 선택 카드 대신 전용 렌더러가 그린다 —
	# raw choice_active는 유지되므로 이 라우팅이 카드 드로우보다 먼저 오고,
	# 융합 모달 활성 중 일반 카드는 그리지 않는다.
	if runtime_state.has_method("is_perk_fusion_modal_active") and bool(runtime_state.is_perk_fusion_modal_active()):
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 20.0 / 255.0, 0.68))
		sample_start = _perf_begin(perf_logger)
		_perk_fusion_overlay_renderer.draw(
			canvas,
			runtime_state.get_perk_fusion_modal_snapshot(),
			catalog,
			view_size,
			icon_renderer
		)
		_perf_end(perf_logger, "hud.perk_overlay.perk_fusion_modal", sample_start)
		return
	# 신비의 주사위 모달(D1~D3): 표준 선택 카드 대신 전용 렌더러가 그린다 —
	# raw choice_active는 유지되므로 이 라우팅이 카드 드로우보다 먼저 온다.
	if runtime_state.has_method("is_mystic_dice_modal_active") and bool(runtime_state.is_mystic_dice_modal_active()):
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 20.0 / 255.0, 0.68))
		sample_start = _perf_begin(perf_logger)
		_mystic_dice_overlay_renderer.draw(
			canvas,
			runtime_state.get_mystic_dice_modal_snapshot(),
			runtime_state.get_mystic_dice_snapshot(),
			view_size
		)
		_perf_end(perf_logger, "hud.perk_overlay.mystic_dice_modal", sample_start)
		return
	if runtime_state.has_method("is_unlock_showcase_active") and bool(runtime_state.is_unlock_showcase_active()):
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 20.0 / 255.0, 0.68))
		sample_start = _perf_begin(perf_logger)
		_draw_particles(canvas, snapshot)
		_perf_end(perf_logger, "hud.perk_overlay.unlock_showcase_particles", sample_start)
		sample_start = _perf_begin(perf_logger)
		_draw_unlock_showcase(canvas, snapshot, view_size, icon_renderer)
		_perf_end(perf_logger, "hud.perk_overlay.unlock_showcase", sample_start)
		return
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
	_draw_per_card_descriptions(canvas, choices, selected_index, layout, float(snapshot.get("animation_time", 0.0)))
	_perf_end(perf_logger, "hud.perk_overlay.description", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_status_panel(canvas, runtime_state, snapshot, catalog, _get_rect2(layout.get("panel_rect", Rect2())), icon_renderer, view_size)
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
	sample_start = _perf_begin(perf_logger)
	_draw_starpoint_absorption_effect(canvas, runtime_state)
	_perf_end(perf_logger, "hud.perk_overlay.starpoint_absorption", sample_start)


func _runtime_state_has_visible_effects(runtime_state: Object) -> bool:
	if runtime_state == null:
		return false
	if runtime_state.has_method("is_choice_active") and bool(runtime_state.is_choice_active()):
		return true
	if runtime_state.has_method("is_choice_flight_active") and bool(runtime_state.is_choice_flight_active()):
		return true
	if runtime_state.has_method("is_starpoint_absorption_active") and bool(runtime_state.is_starpoint_absorption_active()):
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
		var absorption_effect: Dictionary = _get_dict(snapshot.get("starpoint_absorption_effect", {}))
		if bool(absorption_effect.get("active", false)):
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


func _draw_unlock_showcase(canvas: CanvasItem, snapshot: Dictionary, view_size: Vector2, icon_renderer: Object) -> void:
	var showcase: Dictionary = _get_dict(snapshot.get("unlock_showcase", {}))
	if not bool(showcase.get("active", false)):
		return
	var font: Font = _get_font()
	if font == null:
		return
	var age: float = float(showcase.get("age", 0.0))
	var alpha: float = clamp(age / 0.18, 0.0, 1.0)
	if alpha <= 0.001:
		return
	var skill_id: String = str(showcase.get("skill_id", ""))
	var skill_data: Dictionary = _get_dict(showcase.get("skill_data", {}))
	var choice: Dictionary = _get_dict(showcase.get("choice", {}))
	var color: Color = _get_color(skill_data.get("color", choice.get("icon_color", Color(90.0 / 255.0, 190.0 / 255.0, 1.0))))
	var skill_name: String = str(skill_data.get("korean", skill_data.get("name", choice.get("name", skill_id))))
	var how_to_use: String = _normalize_keycap_message(str(skill_data.get("how_to_use", "")))
	var motion_hint: String = str(skill_data.get("motion_hint", ""))
	var panel_width: float = min(max(460.0, view_size.x - 96.0), 640.0)
	var panel_height: float = 268.0
	if how_to_use == "":
		panel_height -= 34.0
	if motion_hint == "":
		panel_height -= 24.0
	var panel_rect := Rect2(
		Vector2(floor((view_size.x - panel_width) * 0.5), floor((view_size.y - panel_height) * 0.5)),
		Vector2(panel_width, panel_height)
	)
	var pulse: float = 0.5 + 0.5 * sin(float(_get_draw_msec()) * 0.006)
	for grow in [16.0, 9.0, 4.0]:
		canvas.draw_rect(panel_rect.grow(grow), Color(color.r, color.g, color.b, (0.06 + 0.06 * pulse) * alpha), false, max(1.0, 5.0 - grow * 0.18))
	canvas.draw_rect(panel_rect, Color(12.0 / 255.0, 18.0 / 255.0, 32.0 / 255.0, 0.95 * alpha))
	canvas.draw_rect(panel_rect, Color(color.r, color.g, color.b, 0.76 * alpha), false, 2.4)
	canvas.draw_line(panel_rect.position + Vector2(24.0, 82.0), Vector2(panel_rect.end.x - 24.0, panel_rect.position.y + 82.0), Color(color.r, color.g, color.b, 0.34 * alpha), 1.0)

	_draw_text_centered(canvas, UNLOCK_SHOWCASE_TITLE_TEXT, panel_rect.position + Vector2(panel_rect.size.x * 0.5, 36.0), 24, Color(1.0, 225.0 / 255.0, 125.0 / 255.0, alpha))

	var icon_rect := Rect2(panel_rect.position + Vector2(34.0, 101.0), Vector2(72.0, 72.0))
	canvas.draw_rect(icon_rect, Color(7.0 / 255.0, 12.0 / 255.0, 22.0 / 255.0, 0.90 * alpha))
	canvas.draw_rect(icon_rect, Color(color.r, color.g, color.b, 0.58 * alpha), false, 1.6)
	var icon_choice := choice.duplicate(true)
	icon_choice["id"] = skill_id
	icon_choice["icon_id"] = skill_id
	icon_choice["icon_color"] = color
	_draw_icon(canvas, icon_renderer, icon_choice, icon_rect.grow(-7.0), alpha)

	var text_left: float = icon_rect.end.x + 22.0
	var text_width: float = max(80.0, panel_rect.end.x - text_left - 34.0)
	_draw_text_fitted(canvas, skill_name, Vector2(text_left, panel_rect.position.y + 132.0), 28, Color(0.96, 0.99, 1.0, alpha), text_width, 17)
	if motion_hint != "":
		_draw_text_fitted(canvas, motion_hint, Vector2(text_left, panel_rect.position.y + 164.0), 15, Color(170.0 / 255.0, 190.0 / 255.0, 215.0 / 255.0, 0.92 * alpha), text_width, 11)

	if how_to_use != "":
		var keycap_y: float = panel_rect.position.y + 210.0
		var available_width: float = max(120.0, panel_rect.size.x - 56.0)
		var keycap_font_size: int = TutorialHintKeycapRenderer.fit_font_size(font, how_to_use, available_width, 23, 13)
		TutorialHintKeycapRenderer.draw_centered_line(canvas, font, how_to_use, Vector2(panel_rect.get_center().x, keycap_y), keycap_font_size, alpha)

	var blink: float = 0.55 + 0.45 * sin(float(_get_draw_msec()) * 0.005)
	_draw_text_centered(
		canvas,
		UNLOCK_SHOWCASE_PROMPT_TEXT,
		Vector2(panel_rect.get_center().x, panel_rect.end.y - 27.0),
		14,
		Color(185.0 / 255.0, 200.0 / 255.0, 225.0 / 255.0, (0.58 + 0.34 * blink) * alpha)
	)


func _normalize_keycap_message(text: String) -> String:
	var words: Array = []
	for raw_word in text.split(" ", false):
		words.append(_normalize_joined_keycap_token(str(raw_word)))
	return " ".join(words)


func _normalize_joined_keycap_token(token: String) -> String:
	for separator in ["/", "-", "+"]:
		if token.find(separator) < 0:
			continue
		var pieces: PackedStringArray = token.split(separator, false)
		if pieces.size() < 2:
			continue
		var normalized: Array = []
		var all_key_tokens := true
		for piece in pieces:
			var clean_piece: String = str(piece).strip_edges()
			if clean_piece == "" or not TutorialHintKeycapRenderer.KEYCAP_TOKENS.has(clean_piece):
				all_key_tokens = false
				break
			normalized.append(clean_piece)
		if all_key_tokens:
			return (" %s " % separator).join(normalized)
	return token


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
	var fast_pulse: float = 0.5 + 0.5 * sin(float(_get_draw_msec()) * 0.0108)
	var marker: String = str(theme.get("marker", "energy"))

	# Inner glow band (Python parity: 7-layer inset, brightest near edge fading inward).
	for inset in range(1, 8):
		var band_alpha: float = clamp((0.42 + 0.22 * pulse) - float(inset) * 0.048, 0.0, 1.0) * alpha
		if band_alpha <= 0.003:
			continue
		canvas.draw_rect(rect.grow(-float(inset)), Color(main.r, main.g, main.b, band_alpha), false, 1.0)

	# Pulsing main accent border (stronger than the card's static border).
	var main_alpha: float = (0.65 + 0.25 * pulse) * alpha
	canvas.draw_rect(rect.grow(1.0), Color(accent.r, accent.g, accent.b, main_alpha), false, 2.0)

	# Inner highlight line (close to white at peak pulse).
	var hl_alpha: float = (0.34 + 0.26 * pulse) * alpha
	canvas.draw_rect(rect.grow(-3.0), Color(highlight.r, highlight.g, highlight.b, hl_alpha), false, 1.0)

	var corner_len: float = min(18.0, rect.size.x * 0.16)
	var corner_accent := Color(accent.r, accent.g, accent.b, (0.62 + 0.22 * pulse) * alpha)
	var corner_highlight := Color(highlight.r, highlight.g, highlight.b, (0.48 + 0.24 * pulse) * alpha)
	_draw_character_edge_corners(canvas, rect, corner_accent, corner_highlight, corner_len)

	if marker == "poison":
		_draw_viper_edge_marks(canvas, rect, main, accent, highlight, alpha, pulse, fast_pulse)
	elif marker == "mecha":
		_draw_optimus_edge_marks(canvas, rect, main, accent, highlight, alpha, pulse, fast_pulse)
	elif marker == "tactical":
		_draw_soldier_edge_marks(canvas, rect, main, accent, highlight, alpha, pulse, fast_pulse)
	else:
		_draw_smasher_edge_marks(canvas, rect, main, accent, highlight, alpha, pulse, fast_pulse)


func _draw_character_outer_glow(canvas: CanvasItem, rect: Rect2, restriction: String, alpha: float, pulse: float) -> void:
	if restriction == "":
		return
	var theme: Dictionary = _character_edge_theme(restriction, alpha, pulse)
	if theme.is_empty():
		return
	var main: Color = theme.get("main", Color(0.0, 0.0, 0.0, 0.0))
	var sb: StyleBoxFlat = _get_back_glow_stylebox()
	var corner_radius: int = int(clamp(round(rect.size.y * 0.18), 8.0, 16.0))
	sb.corner_radius_top_left = corner_radius
	sb.corner_radius_top_right = corner_radius
	sb.corner_radius_bottom_left = corner_radius
	sb.corner_radius_bottom_right = corner_radius
	for grow in [8.0, 6.0, 4.0, 2.0]:
		var alpha_byte: float = (50.0 - grow * 5.0) + pulse * 25.0
		var glow_alpha: float = clamp(alpha_byte / 255.0, 0.0, 1.0) * alpha
		if glow_alpha <= 0.003:
			continue
		sb.bg_color = Color(main.r, main.g, main.b, glow_alpha)
		canvas.draw_style_box(sb, rect.grow(grow))


func _get_back_glow_stylebox() -> StyleBoxFlat:
	if _back_glow_stylebox == null:
		_back_glow_stylebox = StyleBoxFlat.new()
		_back_glow_stylebox.anti_aliasing = true
		_back_glow_stylebox.anti_aliasing_size = 1.0
	return _back_glow_stylebox


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


func _draw_smasher_edge_marks(
	canvas: CanvasItem,
	rect: Rect2,
	main: Color,
	accent: Color,
	highlight: Color,
	alpha: float,
	_pulse: float,
	fast_pulse: float
) -> void:
	# 4-corner lightning sparks (Python: 15-frame cycle, phases 0..9 render with
	# size 4 → 3 → 2 px depending on phase, brightest at phase 0).
	var phase_base: int = int(float(_get_draw_msec()) * 0.06)
	var corners: Array[Vector2] = [
		rect.position + Vector2(6.0, 6.0),
		Vector2(rect.end.x - 7.0, rect.position.y + 6.0),
		Vector2(rect.position.x + 6.0, rect.end.y - 7.0),
		rect.end - Vector2(7.0, 7.0),
	]
	for ci in range(corners.size()):
		var spark_phase: int = (phase_base + ci * 5) % 15
		if spark_phase >= 10:
			continue
		var spark_alpha: float = clamp((220.0 - float(spark_phase) * 18.0) / 255.0, 0.0, 1.0) * alpha
		if spark_alpha <= 0.005:
			continue
		var spark_r: float = 4.0 if spark_phase < 3 else (3.0 if spark_phase < 6 else 2.0)
		if spark_phase < 3:
			canvas.draw_circle(corners[ci], spark_r + 1.0, Color(main.r, main.g, main.b, spark_alpha * 0.5))
		canvas.draw_circle(corners[ci], spark_r, Color(highlight.r, highlight.g, highlight.b, spark_alpha))

	# Top/bottom zig-zag energy lines (Python: 8 segments, jitter 3px).
	var top_y: float = rect.position.y + 2.0
	var bottom_y: float = rect.end.y - 3.0
	var inner_left: float = rect.position.x + 10.0
	var inner_w: float = rect.size.x - 20.0
	var line_alpha: float = clamp((90.0 + 50.0 * fast_pulse) / 255.0, 0.0, 1.0) * alpha
	var energy_color := Color(accent.r, accent.g, accent.b, line_alpha)
	var time_ms: float = float(_get_draw_msec())
	for si in range(8):
		var sx1: float = inner_left + inner_w * float(si) / 8.0
		var sx2: float = inner_left + inner_w * float(si + 1) / 8.0
		var jitter: float = sin(time_ms * 0.024 + float(si) * 1.2) * 3.0
		canvas.draw_line(Vector2(sx1, top_y + jitter), Vector2(sx2, top_y - jitter), energy_color, 1.0)
		canvas.draw_line(Vector2(sx1, bottom_y - jitter), Vector2(sx2, bottom_y + jitter), energy_color, 1.0)

	# Left/right vertical electric lines (Python: 5 segments, jitter 2px, dimmer).
	var inner_top: float = rect.position.y + 10.0
	var inner_h: float = rect.size.y - 20.0
	var side_alpha: float = clamp((70.0 + 40.0 * fast_pulse) / 255.0, 0.0, 1.0) * alpha
	var side_color := Color(main.r, main.g, main.b, side_alpha)
	for si in range(5):
		var sy1: float = inner_top + inner_h * float(si) / 5.0
		var sy2: float = inner_top + inner_h * float(si + 1) / 5.0
		var jitter: float = sin(time_ms * 0.021 + float(si) * 1.8) * 2.0
		canvas.draw_line(Vector2(rect.position.x + 2.0 + jitter, sy1), Vector2(rect.position.x + 2.0 - jitter, sy2), side_color, 1.0)
		canvas.draw_line(Vector2(rect.end.x - 3.0 - jitter, sy1), Vector2(rect.end.x - 3.0 + jitter, sy2), side_color, 1.0)


func _draw_viper_edge_marks(
	canvas: CanvasItem,
	rect: Rect2,
	main: Color,
	accent: Color,
	highlight: Color,
	alpha: float,
	_pulse: float,
	_fast_pulse: float
) -> void:
	# 12 poison smoke particles travelling along the perimeter (Python parity).
	var poison_count := 12
	var time_ms: float = float(_get_draw_msec())
	var inset := 4.0
	var inner_w: float = max(1.0, rect.size.x - inset * 2.0)
	var inner_h: float = max(1.0, rect.size.y - inset * 2.0)
	var perim: float = 2.0 * (inner_w + inner_h)
	for pi in range(poison_count):
		var vt: float = fmod(time_ms * 0.0015 + float(pi) * (TAU / float(poison_count)), TAU)
		if vt < 0.0:
			vt += TAU
		var pos_on_perim: float = (vt / TAU) * perim
		var px: float = 0.0
		var py: float = 0.0
		if pos_on_perim < inner_w:
			px = rect.position.x + inset + pos_on_perim
			py = rect.position.y + 3.0
		elif pos_on_perim < inner_w + inner_h:
			px = rect.end.x - inset
			py = rect.position.y + inset + (pos_on_perim - inner_w)
		elif pos_on_perim < 2.0 * inner_w + inner_h:
			px = rect.end.x - inset - (pos_on_perim - inner_w - inner_h)
			py = rect.end.y - inset
		else:
			px = rect.position.x + 3.0
			py = rect.end.y - inset - (pos_on_perim - 2.0 * inner_w - inner_h)
		var p_alpha: float = clamp((160.0 + 70.0 * sin(time_ms * 0.009 + float(pi))) / 255.0, 0.0, 1.0) * alpha
		if p_alpha <= 0.005:
			continue
		var pr: float = 3.0 if pi % 4 == 0 else 2.0
		var pc: Color = highlight if pi % 3 == 0 else accent
		# Soft halo around bigger particles.
		if pr >= 3.0:
			canvas.draw_circle(Vector2(px, py), pr + 2.0, Color(main.r, main.g, main.b, p_alpha * 0.33))
		canvas.draw_circle(Vector2(px, py), pr, Color(pc.r, pc.g, pc.b, p_alpha))

	# 4 corner poison puddles (Python: dim outer pool + bright inner core).
	var v_corners: Array[Vector2] = [
		rect.position + Vector2(6.0, 6.0),
		Vector2(rect.end.x - 7.0, rect.position.y + 6.0),
		Vector2(rect.position.x + 6.0, rect.end.y - 7.0),
		rect.end - Vector2(7.0, 7.0),
	]
	for vi in range(v_corners.size()):
		var va: float = clamp((100.0 + 60.0 * sin(time_ms * 0.0048 + float(vi) * 1.5)) / 255.0, 0.0, 1.0) * alpha
		if va <= 0.005:
			continue
		canvas.draw_circle(v_corners[vi], 4.0, Color(main.r, main.g, main.b, va * 0.5))
		canvas.draw_circle(v_corners[vi], 2.0, Color(accent.r, accent.g, accent.b, va))


func _draw_optimus_edge_marks(
	canvas: CanvasItem,
	rect: Rect2,
	main: Color,
	accent: Color,
	highlight: Color,
	alpha: float,
	pulse: float,
	_fast_pulse: float
) -> void:
	# L-shape gear/circuit corner decorations (Python: 4 corners, 2 thick + 2 thin lines each).
	var corner_len: float = 14.0
	var ca: float = clamp((180.0 + 60.0 * pulse) / 255.0, 0.0, 1.0) * alpha
	if ca > 0.005:
		var ax := Color(accent.r, accent.g, accent.b, ca)
		var hx := Color(highlight.r, highlight.g, highlight.b, ca * 0.5)
		var lx: float = rect.position.x
		var rx: float = rect.end.x
		var ty: float = rect.position.y
		var by: float = rect.end.y
		# top-left
		canvas.draw_line(Vector2(lx + 3.0, ty + 6.0), Vector2(lx + 3.0, ty + 6.0 + corner_len), ax, 2.0)
		canvas.draw_line(Vector2(lx + 3.0, ty + 6.0), Vector2(lx + 3.0 + corner_len, ty + 6.0), ax, 2.0)
		canvas.draw_line(Vector2(lx + 5.0, ty + 8.0), Vector2(lx + 5.0, ty + 8.0 + corner_len - 4.0), hx, 1.0)
		canvas.draw_line(Vector2(lx + 5.0, ty + 8.0), Vector2(lx + 5.0 + corner_len - 4.0, ty + 8.0), hx, 1.0)
		# top-right
		canvas.draw_line(Vector2(rx - 4.0, ty + 6.0), Vector2(rx - 4.0, ty + 6.0 + corner_len), ax, 2.0)
		canvas.draw_line(Vector2(rx - 4.0, ty + 6.0), Vector2(rx - 4.0 - corner_len, ty + 6.0), ax, 2.0)
		canvas.draw_line(Vector2(rx - 6.0, ty + 8.0), Vector2(rx - 6.0, ty + 8.0 + corner_len - 4.0), hx, 1.0)
		canvas.draw_line(Vector2(rx - 6.0, ty + 8.0), Vector2(rx - 6.0 - corner_len + 4.0, ty + 8.0), hx, 1.0)
		# bottom-left
		canvas.draw_line(Vector2(lx + 3.0, by - 7.0), Vector2(lx + 3.0, by - 7.0 - corner_len), ax, 2.0)
		canvas.draw_line(Vector2(lx + 3.0, by - 7.0), Vector2(lx + 3.0 + corner_len, by - 7.0), ax, 2.0)
		canvas.draw_line(Vector2(lx + 5.0, by - 9.0), Vector2(lx + 5.0, by - 9.0 - corner_len + 4.0), hx, 1.0)
		canvas.draw_line(Vector2(lx + 5.0, by - 9.0), Vector2(lx + 5.0 + corner_len - 4.0, by - 9.0), hx, 1.0)
		# bottom-right
		canvas.draw_line(Vector2(rx - 4.0, by - 7.0), Vector2(rx - 4.0, by - 7.0 - corner_len), ax, 2.0)
		canvas.draw_line(Vector2(rx - 4.0, by - 7.0), Vector2(rx - 4.0 - corner_len, by - 7.0), ax, 2.0)
		canvas.draw_line(Vector2(rx - 6.0, by - 9.0), Vector2(rx - 6.0, by - 9.0 - corner_len + 4.0), hx, 1.0)
		canvas.draw_line(Vector2(rx - 6.0, by - 9.0), Vector2(rx - 6.0 - corner_len + 4.0, by - 9.0), hx, 1.0)

	# 6 top/bottom circuit dots (Python: pulsing per-dot phase).
	var time_ms: float = float(_get_draw_msec())
	for di in range(6):
		var dx: float = rect.position.x + rect.size.x * float(di + 1) / 7.0
		var dp: float = sin(time_ms * 0.009 + float(di) * 0.9)
		var da: float = clamp((130.0 + 70.0 * dp) / 255.0, 0.0, 1.0) * alpha
		if da <= 0.005:
			continue
		var dr: float = 2.0 if dp > 0.5 else 1.0
		canvas.draw_circle(Vector2(dx, rect.position.y + 4.0), dr, Color(accent.r, accent.g, accent.b, da))
		canvas.draw_circle(Vector2(dx, rect.end.y - 5.0), dr, Color(accent.r, accent.g, accent.b, da))

	# Vertical-sweeping scanline.
	var scan_pulse: float = 0.5 + 0.5 * sin(time_ms * 0.0036)
	var scan_y: float = rect.position.y + 6.0 + (rect.size.y - 12.0) * scan_pulse
	var scan_alpha: float = clamp((40.0 + 25.0 * pulse) / 255.0, 0.0, 1.0) * alpha
	if scan_alpha > 0.004:
		canvas.draw_line(
			Vector2(rect.position.x + 4.0, scan_y),
			Vector2(rect.end.x - 5.0, scan_y),
			Color(main.r, main.g, main.b, scan_alpha),
			1.0
		)


func _draw_soldier_edge_marks(
	canvas: CanvasItem,
	rect: Rect2,
	main: Color,
	accent: Color,
	highlight: Color,
	alpha: float,
	pulse: float,
	fast_pulse: float
) -> void:
	# 4 corner tactical crosses with bright center dot.
	var marker_corners: Array[Vector2] = [
		rect.position + Vector2(9.0, 9.0),
		Vector2(rect.end.x - 10.0, rect.position.y + 9.0),
		Vector2(rect.position.x + 9.0, rect.end.y - 10.0),
		rect.end - Vector2(10.0, 10.0),
	]
	var ma: float = clamp((180.0 + 60.0 * fast_pulse) / 255.0, 0.0, 1.0) * alpha
	if ma > 0.005:
		var marker_color := Color(accent.r, accent.g, accent.b, ma)
		var center_color := Color(highlight.r, highlight.g, highlight.b, ma)
		for mc in marker_corners:
			canvas.draw_line(mc + Vector2(-4.0, 0.0), mc + Vector2(4.0, 0.0), marker_color, 2.0)
			canvas.draw_line(mc + Vector2(0.0, -4.0), mc + Vector2(0.0, 4.0), marker_color, 2.0)
			canvas.draw_circle(mc, 1.4, center_color)

	# Vertical dashed side lines.
	var dash_len: float = 5.0
	var gap: float = 5.0
	var dl_a: float = clamp((100.0 + 50.0 * pulse) / 255.0, 0.0, 1.0) * alpha
	if dl_a <= 0.005:
		return
	var dash_color := Color(main.r, main.g, main.b, dl_a)

	var dy: float = rect.position.y + 16.0
	var dy_end: float = rect.end.y - 16.0
	while dy < dy_end:
		var dy_stop: float = min(dy + dash_len, dy_end)
		canvas.draw_line(Vector2(rect.position.x + 2.0, dy), Vector2(rect.position.x + 2.0, dy_stop), dash_color, 2.0)
		canvas.draw_line(Vector2(rect.end.x - 3.0, dy), Vector2(rect.end.x - 3.0, dy_stop), dash_color, 2.0)
		dy += dash_len + gap

	# Horizontal dashed top/bottom lines (Python parity addition).
	var dx: float = rect.position.x + 16.0
	var dx_end: float = rect.end.x - 16.0
	while dx < dx_end:
		var dx_stop: float = min(dx + dash_len, dx_end)
		canvas.draw_line(Vector2(dx, rect.position.y + 2.0), Vector2(dx_stop, rect.position.y + 2.0), dash_color, 1.0)
		canvas.draw_line(Vector2(dx, rect.end.y - 3.0), Vector2(dx_stop, rect.end.y - 3.0), dash_color, 1.0)
		dx += dash_len + gap


# Soft golden surround halo for mythic perks. MUST be drawn BEHIND the card/cell
# (before its opaque bg) -- drawn on top it would veil the whole interior in an amber
# haze. Fills rounded styleboxes larger than `rect`; the bg then masks the inner portion
# so only the outer bloom ring shows and the interior stays clean.
func _draw_mythic_ornament_glow(canvas: CanvasItem, rect: Rect2, alpha: float, intensity: float = 0.6) -> void:
	if alpha <= 0.003:
		return
	intensity = clampf(intensity, 0.0, 1.0)
	var time_ms: float = float(_get_draw_msec())
	var pulse: float = 0.5 + 0.5 * sin(time_ms * 0.0042)
	var ref: float = min(rect.size.x, rect.size.y)
	var scale_ref: float = clampf(ref / 120.0, 0.42, 1.0)
	var sb: StyleBoxFlat = _get_back_glow_stylebox()
	var corner_radius: int = int(clamp(round(ref * 0.16), 6.0, 18.0))
	sb.corner_radius_top_left = corner_radius
	sb.corner_radius_top_right = corner_radius
	sb.corner_radius_bottom_left = corner_radius
	sb.corner_radius_bottom_right = corner_radius
	var bloom_base: float = (0.11 + 0.13 * pulse) * (0.58 + 0.42 * intensity)
	for grow in [16.0, 11.0, 7.0, 3.0]:
		var g: float = grow * scale_ref
		var bloom_alpha: float = clampf(bloom_base - g * 0.0048, 0.0, 1.0) * alpha
		if bloom_alpha <= 0.003:
			continue
		sb.bg_color = Color(MYTHIC_GOLD_AMBER.r, MYTHIC_GOLD_AMBER.g, MYTHIC_GOLD_AMBER.b, bloom_alpha)
		canvas.draw_style_box(sb, rect.grow(g))


# Golden FRAME ornament for mythic perks: ornate double frame, corner filigree with gem
# studs, orbiting sparkles, and a crown gem (large surfaces only). Every draw sits ON the
# rect edge or OUTSIDE it, so the card/cell interior is never tinted. Draw this AFTER the
# card bg/icon/text; pair it with _draw_mythic_ornament_glow behind.
func _draw_mythic_ornament_frame(canvas: CanvasItem, rect: Rect2, alpha: float, intensity: float = 0.6) -> void:
	if alpha <= 0.003:
		return
	intensity = clampf(intensity, 0.0, 1.0)
	var time_ms: float = float(_get_draw_msec())
	var pulse: float = 0.5 + 0.5 * sin(time_ms * 0.0042)
	var fast_pulse: float = 0.5 + 0.5 * sin(time_ms * 0.0091)
	var ref: float = min(rect.size.x, rect.size.y)
	var scale_ref: float = clampf(ref / 120.0, 0.42, 1.0)

	# Ornate double frame.
	var outer := rect.grow(2.0 * scale_ref)
	canvas.draw_rect(outer, Color(MYTHIC_GOLD_DEEP.r, MYTHIC_GOLD_DEEP.g, MYTHIC_GOLD_DEEP.b, (0.72 + 0.20 * pulse) * alpha), false, max(1.6, 2.6 * scale_ref))
	canvas.draw_rect(rect.grow(-1.5 * scale_ref), Color(MYTHIC_GOLD_BRIGHT.r, MYTHIC_GOLD_BRIGHT.g, MYTHIC_GOLD_BRIGHT.b, (0.50 + 0.28 * pulse) * alpha), false, max(1.0, 1.4 * scale_ref))

	# Corner filigree brackets + gem studs.
	var corner_len: float = clampf(ref * 0.22, 9.0, 30.0)
	var inset: float = 3.0 * scale_ref
	var lx: float = rect.position.x + inset
	var rx: float = rect.end.x - inset
	var ty: float = rect.position.y + inset
	var by: float = rect.end.y - inset
	var bracket := Color(MYTHIC_GOLD_BRIGHT.r, MYTHIC_GOLD_BRIGHT.g, MYTHIC_GOLD_BRIGHT.b, (0.80 + 0.18 * pulse) * alpha)
	var shine := Color(MYTHIC_GOLD_HIGHLIGHT.r, MYTHIC_GOLD_HIGHLIGHT.g, MYTHIC_GOLD_HIGHLIGHT.b, (0.58 + 0.32 * fast_pulse) * alpha)
	var bracket_w: float = max(1.6, 2.4 * scale_ref)
	var corners: Array = [
		[Vector2(lx, ty), Vector2(1.0, 1.0)],
		[Vector2(rx, ty), Vector2(-1.0, 1.0)],
		[Vector2(lx, by), Vector2(1.0, -1.0)],
		[Vector2(rx, by), Vector2(-1.0, -1.0)],
	]
	var gem_r: float = max(1.8, 2.8 * scale_ref)
	for corner in corners:
		var p: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		canvas.draw_line(p, p + Vector2(corner_len * d.x, 0.0), bracket, bracket_w)
		canvas.draw_line(p, p + Vector2(0.0, corner_len * d.y), bracket, bracket_w)
		canvas.draw_line(p + Vector2(2.0 * d.x, 2.0 * d.y), p + Vector2(corner_len * 0.58 * d.x, 2.0 * d.y), shine, max(1.0, bracket_w * 0.5))
		canvas.draw_circle(p, gem_r, Color(MYTHIC_GOLD_DEEP.r, MYTHIC_GOLD_DEEP.g, MYTHIC_GOLD_DEEP.b, alpha))
		canvas.draw_circle(p, gem_r * 0.5, shine)

	# Orbiting golden sparkles on a path just outside the frame.
	var sparkle_path := rect.grow(3.5 * scale_ref)
	var count: int = MYTHIC_ORNAMENT_SPARKLE_COUNT if ref >= MYTHIC_ORNAMENT_CROWN_MIN_REF else MYTHIC_ORNAMENT_COMPACT_SPARKLE_COUNT
	var perim: float = 2.0 * (sparkle_path.size.x + sparkle_path.size.y)
	for si in range(count):
		var travel: float = fmod(time_ms * 0.00017 + float(si) / float(count), 1.0) * perim
		var sp: Vector2 = _perimeter_point(sparkle_path, travel)
		var twinkle: float = 0.5 + 0.5 * sin(time_ms * 0.006 + float(si) * 1.7)
		var s_alpha: float = clampf((0.34 + 0.66 * twinkle) * (0.68 + 0.32 * intensity), 0.0, 1.0) * alpha
		if s_alpha <= 0.02:
			continue
		_draw_gold_sparkle(canvas, sp, (2.4 + 1.7 * twinkle) * scale_ref, s_alpha)

	# Crown gem accent (large surfaces only -- skipped on the compact tray cell).
	if ref >= MYTHIC_ORNAMENT_CROWN_MIN_REF:
		var crown_center := Vector2(rect.get_center().x, rect.position.y - 7.0 * scale_ref)
		var gs: float = (5.0 + 0.8 * pulse) * scale_ref
		var gem := PackedVector2Array([
			crown_center + Vector2(0.0, -gs * 1.35),
			crown_center + Vector2(gs, 0.0),
			crown_center + Vector2(0.0, gs * 1.35),
			crown_center + Vector2(-gs, 0.0),
		])
		canvas.draw_circle(crown_center, gs * 2.0, Color(MYTHIC_GOLD_AMBER.r, MYTHIC_GOLD_AMBER.g, MYTHIC_GOLD_AMBER.b, 0.42 * alpha))
		canvas.draw_colored_polygon(gem, Color(MYTHIC_GOLD_BRIGHT.r, MYTHIC_GOLD_BRIGHT.g, MYTHIC_GOLD_BRIGHT.b, alpha))
		canvas.draw_circle(crown_center, gs * 0.42, Color(MYTHIC_GOLD_HIGHLIGHT.r, MYTHIC_GOLD_HIGHLIGHT.g, MYTHIC_GOLD_HIGHLIGHT.b, alpha))


# Classic 8-point gold twinkle: soft halo, crossed rays, bright core. Convex-only
# draws (circles + lines) so there is no concave-polygon triangulation risk.
func _draw_gold_sparkle(canvas: CanvasItem, center: Vector2, size: float, alpha: float) -> void:
	canvas.draw_circle(center, size * 1.7, Color(MYTHIC_GOLD_AMBER.r, MYTHIC_GOLD_AMBER.g, MYTHIC_GOLD_AMBER.b, alpha * 0.32))
	var ray := Color(MYTHIC_GOLD_HIGHLIGHT.r, MYTHIC_GOLD_HIGHLIGHT.g, MYTHIC_GOLD_HIGHLIGHT.b, alpha)
	var diag_ray := Color(MYTHIC_GOLD_BRIGHT.r, MYTHIC_GOLD_BRIGHT.g, MYTHIC_GOLD_BRIGHT.b, alpha * 0.72)
	canvas.draw_line(center - Vector2(size, 0.0), center + Vector2(size, 0.0), ray, 1.3)
	canvas.draw_line(center - Vector2(0.0, size), center + Vector2(0.0, size), ray, 1.3)
	var diag: float = size * 0.52
	canvas.draw_line(center - Vector2(diag, diag), center + Vector2(diag, diag), diag_ray, 0.9)
	canvas.draw_line(center - Vector2(diag, -diag), center + Vector2(diag, -diag), diag_ray, 0.9)
	canvas.draw_circle(center, max(1.0, size * 0.34), ray)


# Walk the perimeter of `r` by `dist` pixels (clockwise from the top-left corner).
func _perimeter_point(r: Rect2, dist: float) -> Vector2:
	var w: float = max(1.0, r.size.x)
	var h: float = max(1.0, r.size.y)
	var d: float = fposmod(dist, 2.0 * (w + h))
	if d < w:
		return Vector2(r.position.x + d, r.position.y)
	d -= w
	if d < h:
		return Vector2(r.end.x, r.position.y + d)
	d -= h
	if d < w:
		return Vector2(r.end.x - d, r.end.y)
	d -= w
	return Vector2(r.position.x, r.end.y - d)


# Per-card description columns (2026-07-09 request): instead of one shared panel
# that only shows the selected/hovered perk, every perk's description is laid out
# at once in a column directly under its own card. The selected card's column is
# brighter. Wrapped lines are cached and only recomputed when the choice set or
# card width changes (the modal redraws every frame for its animation).
func _draw_per_card_descriptions(canvas: CanvasItem, choices: Array, selected_index: int, layout: Dictionary, animation_time: float) -> void:
	if choices.is_empty():
		return
	var alpha: float = clamp(animation_time / 0.3, 0.0, 1.0)
	if alpha <= 0.001:
		return
	var card_size: Vector2 = _get_vector2(layout.get("card_size", Vector2(250.0, 126.0)))
	var cards_start: Vector2 = _get_vector2(layout.get("cards_start", Vector2.ZERO))
	var card_gap: float = float(layout.get("card_gap", 16.0))
	var desc_rect: Rect2 = _get_rect2(layout.get("desc_rect", Rect2()))
	if card_size.x <= 0.0 or desc_rect.size.y <= 0.0:
		return
	_ensure_card_desc_cache(choices, card_size.x)
	for i in range(min(choices.size(), _card_desc_cache.size())):
		var choice: Dictionary = _get_dict(choices[i])
		var col_x: float = cards_start.x + float(i) * (card_size.x + card_gap)
		var block := Rect2(Vector2(col_x, desc_rect.position.y), Vector2(card_size.x, desc_rect.size.y))
		_draw_card_description_block(canvas, choice, _get_dict(_card_desc_cache[i]), block, i == selected_index, alpha)


func _draw_card_description_block(canvas: CanvasItem, choice: Dictionary, cached: Dictionary, rect: Rect2, selected: bool, alpha: float) -> void:
	var icon_color: Color = _get_color(choice.get("icon_color", Color.WHITE))
	var accent_lines: Array = _get_array(cached.get("accent_lines", []))
	var body_lines: Array = _get_array(cached.get("body_lines", []))

	# Fit the panel to its content so short perks do not leave a tall empty box; cap
	# at the reserved band height so a long body never overlaps the status panel below.
	var accent_line_h := 22.0
	var body_line_h := 21.0
	var top_offset := 24.0
	var content_h: float = top_offset + float(accent_lines.size()) * accent_line_h + float(body_lines.size()) * body_line_h + 6.0
	if not accent_lines.is_empty() and not body_lines.is_empty():
		content_h += 3.0
	var box_h: float = clamp(content_h, 46.0, rect.size.y)
	var box := Rect2(rect.position, Vector2(rect.size.x, box_h))

	var bg := Color(30.0 / 255.0, 35.0 / 255.0, 55.0 / 255.0, 0.90 * alpha)
	if selected:
		bg = Color(40.0 / 255.0, 50.0 / 255.0, 84.0 / 255.0, 0.94 * alpha)
	canvas.draw_rect(box, bg)
	var border_alpha: float = (0.85 if selected else 0.42) * alpha
	canvas.draw_rect(box, Color(icon_color.r, icon_color.g, icon_color.b, border_alpha), false, 2.0 if selected else 1.2)

	var pad := 12.0
	var text_x: float = box.position.x + pad
	var y: float = box.position.y + top_offset

	for line in accent_lines:
		_draw_text(canvas, str(line), Vector2(text_x, y), 16, Color(1.0, 0.86, 0.56, alpha))
		y += accent_line_h

	if not body_lines.is_empty():
		if not accent_lines.is_empty():
			y += 3.0
		for line in body_lines:
			_draw_text(canvas, str(line), Vector2(text_x, y), 16, Color(0.86, 0.91, 0.98, alpha))
			y += body_line_h


# Rebuilds the wrapped description lines only when the choice set or card width
# changes; the per-frame draw path then just blits the cached lines.
#
# Layout intent (2026-07-09 readability pass): the card already shows the name and
# the Lv./해금/즉시/골드 tag, so the description column does NOT repeat them. It shows
# at most two tiers:
#  - accent = the numeric effect (`description`), highlighted, ONLY for scaling perks
#    where the number is the point (Lv.-tagged). Unlock/instant/gold perks skip it
#    because their `description` just restates the card name ("고스트스매싱 스킬 해금").
#  - body = the friendly `detail` sentence. Falls back to `description` when `detail`
#    is absent or collapses to the same text (the non-Korean locale summary case).
func _ensure_card_desc_cache(choices: Array, card_width: float) -> void:
	var signature: int = hash([hash(choices), int(round(card_width))])
	if signature == _card_desc_cache_signature and not _card_desc_cache.is_empty():
		return
	_card_desc_cache_signature = signature
	_card_desc_cache = []
	var inner_width: float = max(20.0, card_width - 20.0)
	for choice_value in choices:
		var choice: Dictionary = _get_dict(choice_value)
		var description := str(choice.get("description", ""))
		var detail := str(choice.get("detail", ""))
		var has_distinct_detail: bool = detail != "" and detail.strip_edges() != description.strip_edges()
		var is_scaling: bool = _level_text(choice).begins_with("Lv.")
		var accent_text := ""
		var body_text := ""
		if is_scaling and has_distinct_detail:
			accent_text = description
			body_text = detail
		elif has_distinct_detail:
			body_text = detail
		else:
			body_text = description
		_card_desc_cache.append({
			"accent_lines": _wrap_text_px(accent_text, 16, inner_width, 3) if accent_text != "" else [],
			"body_lines": _wrap_text_px(body_text, 16, inner_width, 4),
		})


# Width-aware word wrap (the plain _wrap_text is char-count based and would overflow
# the narrow per-card columns). Measures with the cached font metrics.
func _wrap_text_px(text: String, font_size: int, max_px: float, max_lines: int) -> Array:
	var font: Font = _get_font()
	if font == null or text == "" or max_lines <= 0 or max_px <= 4.0:
		return []
	var lines: Array = []
	var current := ""
	for word in text.split(" ", false):
		# A single token wider than the column -- a long word, or a space-less CJK run
		# (Korean/Japanese/Chinese text often has no break spaces at all) -- must be split
		# at the character level, or it overflows the card. Flush the pending line first.
		if _get_text_size(font, word, font_size).x > max_px:
			if current != "":
				lines.append(current)
				current = ""
				if lines.size() >= max_lines:
					return lines
			for ch in word:
				if current != "" and _get_text_size(font, current + ch, font_size).x > max_px:
					lines.append(current)
					if lines.size() >= max_lines:
						return lines
					current = ch
				else:
					current += ch
			continue
		var trial: String = word if current == "" else current + " " + word
		if current != "" and _get_text_size(font, trial, font_size).x > max_px:
			lines.append(current)
			if lines.size() >= max_lines:
				return lines
			current = word
		else:
			current = trial
	if current != "" and lines.size() < max_lines:
		lines.append(current)
	return lines


func _draw_status_panel(canvas: CanvasItem, runtime_state: Object, snapshot: Dictionary, catalog: Object, rect: Rect2, icon_renderer: Object, view_size: Vector2 = Vector2.ZERO) -> void:
	canvas.draw_rect(rect, Color(12.0 / 255.0, 18.0 / 255.0, 32.0 / 255.0, 0.82))
	canvas.draw_rect(rect, Color(110.0 / 255.0, 96.0 / 255.0, 58.0 / 255.0, 0.72), false, 2.0)
	canvas.draw_line(rect.position + Vector2(12.0, 3.0), Vector2(rect.end.x - 12.0, rect.position.y + 3.0), Color(190.0 / 255.0, 160.0 / 255.0, 82.0 / 255.0, 0.65), 1.0)

	var levels: Dictionary = _get_dict(snapshot.get("runtime_skill_levels", {}))
	var pending: int = int(snapshot.get("pending_skill_choices", 0))
	var gold: int = int(snapshot.get("gold_from_perks", 0))

	_draw_text(canvas, "◆ 현재 퍽", rect.position + Vector2(16.0, 26.0), 15, Color(1.0, 215.0 / 255.0, 100.0 / 255.0))
	_draw_text(canvas, "선택 대기: %d" % pending, rect.position + Vector2(rect.size.x - 118.0, 23.0), 13, Color(170.0 / 255.0, 180.0 / 255.0, 210.0 / 255.0))
	_draw_text(canvas, "퍽 골드: %d" % gold, rect.position + Vector2(rect.size.x - 118.0, 45.0), 13, Color(1.0, 215.0 / 255.0, 100.0 / 255.0))

	var slot_status: Dictionary = _get_dict(snapshot.get("perk_slot_status", {}))
	if slot_status.is_empty() and catalog != null and catalog.has_method("get_perk_slot_status"):
		# 융합 슬롯 환급 반영: runtime_state 자체를 slot context로 관통.
		slot_status = _get_dict(catalog.get_perk_slot_status(levels, runtime_state))
	if not slot_status.is_empty():
		var slot_count: int = int(slot_status.get("count", 0))
		var slot_limit: int = int(slot_status.get("limit", 0))
		if slot_limit > 0:
			var slot_color := Color(170.0 / 255.0, 225.0 / 255.0, 1.0, 0.95)
			if slot_count >= slot_limit:
				slot_color = Color(1.0, 190.0 / 255.0, 90.0 / 255.0, 0.98)
			_draw_text(canvas, "슬롯 %d/%d" % [slot_count, slot_limit], rect.position + Vector2(rect.size.x - 118.0, 67.0), 13, slot_color)
			if slot_count >= slot_limit:
				_draw_text(canvas, get_full_slot_hint(), rect.position + Vector2(rect.size.x - 118.0, 89.0), 12, Color(1.0, 210.0 / 255.0, 130.0 / 255.0, 0.90))

	# Owned perks EXCLUDE active-skill unlocks (fold 후처리에서 제외); they
	# live in the 5-orb skill HUD and do not consume a perk slot. 실경로 fold:
	# 스냅샷의 융합 projection을 소비하는 4인자 빌더가 정본 — 융합 소스 퍽은
	# 개별 아이콘으로 재등장하지 않고 재료쌍 합성 셀 하나로 접힌다.
	var acquired: Array = _build_acquired_perks_for_snapshot(levels, catalog, runtime_state, snapshot)
	# Full perk-slot grid like the character-info panel (2026-07-09 request): one cell per
	# perk-slot-limit, owned perks filled, the rest drawn as empty slots. 빈칸 산정은
	# acquired.size()가 아니라 프레젠터 공용 조립기를 관통한다 — 슬롯 비소모
	# 퍽(_slot_free_cell)이 빈칸을 잠식하면 카운터(5/7)와 그리드 빈칸 수가
	# 어긋난다(코덱스 v1 P1).
	var slot_limit_for_grid: int = max(1, int(slot_status.get("limit", 6)))
	var grid_entries: Array = _build_status_slot_grid(acquired, slot_limit_for_grid)
	var display_slots: int = max(1, grid_entries.size())

	var icons_left: float = rect.position.x + 18.0
	var counter_col_left: float = rect.end.x - 130.0
	var gap := 10.0
	var avail_w: float = max(60.0, counter_col_left - icons_left - 6.0)
	var fit_size: float = (avail_w - gap * float(max(0, display_slots - 1))) / float(display_slots)
	var icon_size: float = clamp(fit_size, 28.0, 54.0)
	var row_y: float = rect.position.y + 52.0

	var mouse_pos: Vector2 = Vector2(-1.0, -1.0)
	if runtime_state != null and runtime_state.has_method("get_status_hover_mouse_pos"):
		mouse_pos = runtime_state.get_status_hover_mouse_pos()
	var hovered_skill: Dictionary = {}
	var hovered_icon_rect := Rect2()

	var inset: float = icon_size * 0.11
	var badge_offset: float = icon_size * 0.17
	var badge_radius: float = icon_size * 0.185
	var badge_font: int = max(9, int(round(icon_size * 0.22)))
	var plus_half: float = icon_size * 0.14
	for idx in range(display_slots):
		var icon_rect := Rect2(Vector2(icons_left + float(idx) * (icon_size + gap), row_y), Vector2(icon_size, icon_size))
		var skill: Dictionary = _get_dict(grid_entries[idx])
		if bool(skill.get("_empty_slot", false)):
			# Empty slot(조립기가 소모 셀 뒤·비소모 셀 앞에 채움).
			canvas.draw_rect(icon_rect, Color(18.0 / 255.0, 23.0 / 255.0, 36.0 / 255.0, 0.62))
			canvas.draw_rect(icon_rect, Color(80.0 / 255.0, 92.0 / 255.0, 120.0 / 255.0, 0.40), false, 1.2)
			var plus_center: Vector2 = icon_rect.get_center()
			var plus_color := Color(120.0 / 255.0, 135.0 / 255.0, 165.0 / 255.0, 0.55)
			canvas.draw_line(plus_center - Vector2(plus_half, 0.0), plus_center + Vector2(plus_half, 0.0), plus_color, 1.6)
			canvas.draw_line(plus_center - Vector2(0.0, plus_half), plus_center + Vector2(0.0, plus_half), plus_color, 1.6)
			continue
		var is_mythic: bool = str(skill.get("rarity", "")).to_lower() == "mythic"
		if icon_rect.has_point(mouse_pos):
			hovered_skill = skill
			hovered_icon_rect = icon_rect
		var color: Color = _get_color(skill.get("icon_color", Color(100.0 / 255.0, 150.0 / 255.0, 1.0)))
		# Mythic: soft gold halo BEHIND the cell only; the interior keeps the normal dark
		# cell so the gold reads as a surround, not a hazy tint (2026-07-09 feedback).
		if is_mythic:
			_draw_mythic_ornament_glow(canvas, icon_rect, 1.0, 0.72)
		canvas.draw_rect(icon_rect, Color(max(0.0, color.r - 0.28), max(0.0, color.g - 0.28), max(0.0, color.b - 0.28), 0.92))
		canvas.draw_rect(icon_rect, Color(color.r, color.g, color.b, 0.72), false, 1.4)
		_draw_icon(canvas, icon_renderer, skill, icon_rect.grow(-inset), 1.0)
		# Slot cells (dash-token per-slot occupancy) already read as one filled slot each,
		# so skip the level badge -- the count of cells IS the level/token count. Single-level
		# perks (max_level == 1) also skip it: they never level, and "고유"/"신화" would not
		# fit the tiny numeric circle (2026-07-09 wording decision).
		if not bool(skill.get("is_slot_cell", false)) and int(skill.get("max_level", 1)) > 1:
			var badge_center: Vector2 = icon_rect.end - Vector2(badge_offset, badge_offset)
			canvas.draw_circle(badge_center, badge_radius + 1.0, Color(8.0 / 255.0, 12.0 / 255.0, 20.0 / 255.0, 0.92))
			canvas.draw_circle(badge_center, badge_radius, Color(1.0, 215.0 / 255.0, 70.0 / 255.0))
			_draw_text_centered(canvas, str(skill.get("level", 1)), badge_center + Vector2(0.0, 1.0), badge_font, Color(42.0 / 255.0, 30.0 / 255.0, 0.0))
		if is_mythic:
			_draw_mythic_ornament_frame(canvas, icon_rect, 1.0, 0.72)

	# Owned-perk hover tooltip (2026-07-09 request): mirrors the character-info perk
	# tooltip -- left = friendly detail, right = "능력치" numeric breakdown. Drawn last
	# so it sits on top of the status row.
	if not hovered_skill.is_empty() and view_size.x > 0.0:
		_draw_perk_status_tooltip(canvas, hovered_skill, hovered_icon_rect, view_size)


func _perk_stats_for_level(skill: Dictionary) -> String:
	var descriptions: Dictionary = _get_dict(skill.get("descriptions", {}))
	if descriptions.is_empty():
		return ""
	var level: int = int(skill.get("level", 1))
	# Effective level may exceed the base cap (transcendent_crown / sage_ring):
	# resolve_stats_text generates the Lv.6+ stat line from the runtime scaling
	# patterns (Korean), falling back to the highest defined level description
	# for unregistered perks and non-Korean locales.
	var stats: String = RuntimePerkOverflowDescriptions.resolve_stats_text(str(skill.get("id", "")), descriptions, level)
	if stats != "":
		return stats
	var max_level: int = int(skill.get("max_level", 1))
	return str(descriptions.get(max_level, ""))


# Comma-split the numeric stat string into right-panel lines. Returns [] (single
# panel) when the stats are empty or identical to the friendly detail -- the
# non-Korean locale collapse where localize_perk_data rewrites both to one summary.
func _perk_stat_lines(stats: String, detail: String) -> Array:
	var trimmed_stats := stats.strip_edges()
	if trimmed_stats == "" or trimmed_stats == detail.strip_edges():
		return []
	var out: Array = []
	for piece in trimmed_stats.split(",", false):
		var text: String = str(piece).strip_edges()
		if text != "":
			out.append(text)
	return out


# 슬롯 그리드 조립(코덱스 v1 P1): 슬롯 비소모 퍽(_slot_free_cell)은 빈칸
# 산정에서 제외하고 그리드 뒤에 별도 표시한다 — 프레젠터 공용 조립기 재사용
# (acquired.size() 기준 빈칸 계산은 5/7+비소모 1에서 빈칸 1로 어긋난다).
func _build_status_slot_grid(acquired: Array, slot_limit: int) -> Array:
	return CharacterInfoOverlayPerkPresenter.build_slot_grid_entries(acquired, max(1, slot_limit))


# 우측 능력치 패널 엔트리(코덱스 v1 P2): 일반 퍽은 descriptions[level]
# (overflow 연동) 콤마 분해, 융합/주사위 projection 엔트리는 descriptions
# 사전 없이 단수 description(태그 스탯 라인)으로 오므로 공용 파서
# build_perk_stat_entries로 라우팅해 색·취소선 메타데이터를 보존한다.
func _perk_status_tooltip_stat_entries(skill: Dictionary) -> Array:
	var stats := _perk_stats_for_level(skill)
	if stats == "":
		stats = str(skill.get("description", ""))
	return CharacterInfoOverlayPerkPresenter.build_perk_stat_entries(stats, str(skill.get("detail", "")))


func _draw_perk_status_tooltip(canvas: CanvasItem, skill: Dictionary, anchor_rect: Rect2, view_size: Vector2) -> void:
	var name := str(skill.get("name", ""))
	var detail := str(skill.get("detail", ""))
	var stats := _perk_stats_for_level(skill)
	var stat_entries: Array = _perk_status_tooltip_stat_entries(skill)
	var left_body: String = detail if detail != "" else stats
	var accent: Color = _get_color(skill.get("icon_color", Color(0.55, 0.72, 1.0)))
	var max_level: int = int(skill.get("max_level", 1))
	# Single-level perks show "신화"/"고유" instead of "Lv.1" (2026-07-09 wording
	# decision). 융합/주사위 projection 엔트리는 자기 라벨(_level_text: "융합" 등)을
	# 이미 실어 오므로 그것을 우선한다.
	var level_text := str(skill.get("_level_text", ""))
	if level_text == "":
		if max_level > 1:
			level_text = "Lv.%d" % int(skill.get("level", 1))
		elif str(skill.get("rarity", "")) == "mythic":
			level_text = "신화"
		else:
			level_text = "고유"

	var pad := 12.0
	var gap := 10.0
	var line_h := 20.0
	var left_w := 300.0
	var body_lines: Array = _wrap_text_px(left_body, 15, left_w - pad * 2.0, 6)
	var left_h: float = 20.0 + 22.0 + (19.0 if level_text != "" else 2.0) + float(body_lines.size()) * line_h + 8.0

	var has_right: bool = not stat_entries.is_empty()
	var right_w := 214.0
	var right_rows: Array = []
	if has_right:
		for entry_value in stat_entries:
			var entry: Dictionary = _get_dict(entry_value)
			var entry_color: Color = _get_color(entry.get("color", Color(0.72, 0.86, 1.0)))
			var entry_strike: bool = bool(entry.get("strikethrough", false))
			for wrapped in _wrap_text_px(str(entry.get("text", "")), 14, right_w - pad * 2.0, 2):
				right_rows.append({
					"text": str(wrapped),
					"color": entry_color,
					"strikethrough": entry_strike,
				})
	var right_h: float = 20.0 + 24.0 + float(right_rows.size()) * line_h + 8.0

	var total_w: float = left_w + (gap + right_w if has_right else 0.0)
	var total_h: float = max(left_h, right_h if has_right else 0.0)

	# Prefer above the icon (the status row sits at the screen bottom); fall below only
	# if there is no room, then clamp inside the view.
	var px: float = anchor_rect.position.x - 6.0
	var py: float = anchor_rect.position.y - total_h - 12.0
	if py < 8.0:
		py = anchor_rect.end.y + 12.0
	px = clamp(px, 8.0, max(8.0, view_size.x - total_w - 8.0))
	py = clamp(py, 8.0, max(8.0, view_size.y - total_h - 8.0))

	# Left panel: name, level, friendly detail.
	var left_rect := Rect2(Vector2(px, py), Vector2(left_w, left_h))
	canvas.draw_rect(left_rect, Color(12.0 / 255.0, 16.0 / 255.0, 28.0 / 255.0, 0.97))
	canvas.draw_rect(left_rect, Color(accent.r, accent.g, accent.b, 0.85), false, 2.0)
	var tx: float = px + pad
	var ty: float = py + 24.0
	_draw_text(canvas, name, Vector2(tx, ty), 16, Color(1.0, 1.0, 1.0))
	ty += 22.0
	if level_text != "":
		_draw_text(canvas, level_text, Vector2(tx, ty), 13, Color(1.0, 0.84, 0.5))
		ty += 19.0
	else:
		ty += 2.0
	for line in body_lines:
		_draw_text(canvas, str(line), Vector2(tx, ty), 15, Color(0.86, 0.91, 0.98))
		ty += line_h

	if not has_right:
		return

	# Right panel: "능력치" numeric breakdown.
	var rx: float = px + left_w + gap
	var right_rect := Rect2(Vector2(rx, py), Vector2(right_w, right_h))
	canvas.draw_rect(right_rect, Color(18.0 / 255.0, 22.0 / 255.0, 40.0 / 255.0, 0.97))
	canvas.draw_rect(right_rect, Color(1.0, 140.0 / 255.0, 70.0 / 255.0, 0.85), false, 2.0)
	_draw_text(canvas, "능력치", Vector2(rx + pad, py + 24.0), 14, Color(1.0, 215.0 / 255.0, 85.0 / 255.0))
	var ry: float = py + 24.0 + 22.0
	for row_value in right_rows:
		var row: Dictionary = _get_dict(row_value)
		var row_color: Color = _get_color(row.get("color", Color(0.72, 0.86, 1.0)))
		var row_text := str(row.get("text", ""))
		_draw_text(canvas, row_text, Vector2(rx + pad, ry), 14, row_color)
		if bool(row.get("strikethrough", false)):
			# 융합 삭제 옵션 취소선(TAB 툴팁과 동일 메타 보존).
			var strike_w: float = _get_text_size(_get_font(), row_text, 14).x
			canvas.draw_line(Vector2(rx + pad, ry - 4.0), Vector2(rx + pad + strike_w, ry - 4.0), Color(row_color.r, row_color.g, row_color.b, 0.85), 1.2)
		ry += line_h


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


# Starpoint absorption visual. Reads `starpoint_absorption_effect` straight off
# the runtime state's snapshot (rather than recomputing here) because the state
# is responsible for translating playfield -> screen each frame so the target
# tracks the moving paddle. Effect phases:
#   [0.00, 0.85]  star spirals from above-the-head source down into the player
#                 body with a sparkle trail and ease-in acceleration
#   [0.85, 1.00]  arrival burst ring + central flash, alpha fading out
func _draw_starpoint_absorption_effect(canvas: CanvasItem, runtime_state: Object) -> void:
	if canvas == null or runtime_state == null:
		return
	if not runtime_state.has_method("get_snapshot"):
		return
	var snapshot: Dictionary = _get_dict(runtime_state.get_snapshot())
	var effect: Dictionary = _get_dict(snapshot.get("starpoint_absorption_effect", {}))
	if not bool(effect.get("active", false)):
		return
	var age: float = float(effect.get("age", 0.0))
	var duration: float = max(0.001, float(effect.get("duration", 0.7)))
	var progress: float = clamp(age / duration, 0.0, 1.0)
	var source: Vector2 = _get_vector2(effect.get("source_pos", Vector2.ZERO))
	var target: Vector2 = _get_vector2(effect.get("target_pos", Vector2.ZERO))
	if source == Vector2.ZERO or target == Vector2.ZERO:
		# Update hasn't translated the playfield position yet (first frame after
		# trigger before update tick fires, or owner / view_size missing). Skip
		# rendering until coords resolve so we don't draw a star at (0,0).
		return
	var screen_scale: float = max(0.1, float(effect.get("screen_scale", 1.0)))
	var flight_progress: float = clamp(progress / 0.85, 0.0, 1.0)
	# Ease-in acceleration so the star "drops" into the body rather than
	# coasting at constant velocity. Pow(2.0) gives a clean parabolic feel.
	var eased: float = pow(flight_progress, 2.0)
	var center: Vector2 = source.lerp(target, eased)
	# Spiral offset shrinks to zero on arrival. Negative orbit dir for visual
	# rotation feel; radius scales with screen scale so a zoomed-out viewport
	# doesn't drown the spiral.
	var spiral_angle: float = age * 7.0
	var spiral_radius: float = 22.0 * screen_scale * (1.0 - flight_progress)
	var head_pos: Vector2 = center + Vector2(cos(spiral_angle), sin(spiral_angle)) * spiral_radius
	# --- Sparkle trail (deterministic from particles list) ---
	var particles: Array = _get_array(effect.get("particles", []))
	_draw_starpoint_absorption_trail(canvas, source, target, particles, age, flight_progress, screen_scale)
	# --- Main star + outer glow (during flight phase) ---
	if flight_progress < 1.0:
		var star_size: float = (15.0 - flight_progress * 5.0) * screen_scale
		var head_alpha: float = clampf(1.0 - flight_progress * 0.35, 0.0, 1.0)
		# Outer halo glow rings.
		canvas.draw_circle(head_pos, star_size * 2.6, Color(STARPOINT_ABSORPTION_GLOW_COLOR.r, STARPOINT_ABSORPTION_GLOW_COLOR.g, STARPOINT_ABSORPTION_GLOW_COLOR.b, 0.18 * head_alpha))
		canvas.draw_circle(head_pos, star_size * 1.6, Color(STARPOINT_ABSORPTION_GLOW_COLOR.r, STARPOINT_ABSORPTION_GLOW_COLOR.g, STARPOINT_ABSORPTION_GLOW_COLOR.b, 0.32 * head_alpha))
		# 5-tip star polygon (matches the starpoint drop's visual identity so
		# the absorbed thing reads as "the starpoint you just picked up").
		var star_points: PackedVector2Array = _build_starpoint_absorption_star(head_pos, star_size, age * 6.0)
		if star_points.size() >= 3:
			canvas.draw_colored_polygon(star_points, Color(STARPOINT_ABSORPTION_FILL_COLOR.r, STARPOINT_ABSORPTION_FILL_COLOR.g, STARPOINT_ABSORPTION_FILL_COLOR.b, head_alpha))
			for idx in range(star_points.size()):
				canvas.draw_line(star_points[idx], star_points[(idx + 1) % star_points.size()], Color(STARPOINT_ABSORPTION_OUTLINE_COLOR.r, STARPOINT_ABSORPTION_OUTLINE_COLOR.g, STARPOINT_ABSORPTION_OUTLINE_COLOR.b, head_alpha), max(1.4, 2.2 * screen_scale))
		# Central white-hot dot.
		canvas.draw_circle(head_pos, max(1.4, star_size * 0.28), Color(1.0, 1.0, 1.0, head_alpha))
	# --- Arrival burst (last 15% of effect) ---
	if progress > 0.85:
		var burst_t: float = clamp((progress - 0.85) / 0.15, 0.0, 1.0)
		var burst_radius: float = lerpf(8.0 * screen_scale, 46.0 * screen_scale, _ease_out_cubic(burst_t))
		var burst_alpha: float = (1.0 - burst_t) * 0.85
		canvas.draw_arc(
			target,
			burst_radius,
			0.0,
			TAU,
			STARPOINT_ABSORPTION_ARRIVAL_ARC_SEGMENTS,
			Color(STARPOINT_ABSORPTION_BURST_COLOR.r, STARPOINT_ABSORPTION_BURST_COLOR.g, STARPOINT_ABSORPTION_BURST_COLOR.b, burst_alpha),
			max(1.6, 3.4 * screen_scale * (1.0 - burst_t))
		)
		# Soft inner flash that collapses inward as the burst expands.
		var flash_alpha: float = (1.0 - burst_t) * 0.55
		canvas.draw_circle(target, 18.0 * screen_scale * (1.0 - burst_t * 0.4), Color(1.0, 0.95, 0.65, flash_alpha))


func _draw_starpoint_absorption_trail(
	canvas: CanvasItem,
	source: Vector2,
	target: Vector2,
	particles: Array,
	age: float,
	flight_progress: float,
	screen_scale: float
) -> void:
	if particles.is_empty():
		return
	# Each particle lags behind the main star by a fixed phase offset so the
	# overall trail looks like a comet tail. Particles ALSO orbit the descending
	# centerline so the trail has a swirling, magical feel rather than a flat
	# line.
	for particle_value in particles:
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var phase: float = float(particle.get("phase", 0.0))
		var radius_seed: float = float(particle.get("radius_seed", 0.5))
		var twinkle_seed: float = float(particle.get("twinkle_seed", 0.5))
		var orbit_dir: float = float(particle.get("orbit_dir", 1.0))
		var lag: float = (radius_seed + 0.15) * 0.18  # 0.027..0.207
		var local_progress: float = clamp(flight_progress - lag, 0.0, 1.0)
		if local_progress <= 0.0:
			continue
		var local_eased: float = pow(local_progress, 2.0)
		var spine: Vector2 = source.lerp(target, local_eased)
		var orbit_angle: float = phase + age * 5.5 * orbit_dir
		var orbit_radius: float = (8.0 + radius_seed * 12.0) * screen_scale * (1.0 - local_progress * 0.7)
		var pos: Vector2 = spine + Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
		var twinkle: float = 0.55 + 0.45 * sin(age * 6.0 + twinkle_seed * TAU)
		var size: float = max(1.2, (2.6 - local_progress * 1.2) * screen_scale)
		var alpha: float = clampf((1.0 - local_progress) * 0.85 * twinkle, 0.0, 1.0)
		canvas.draw_circle(pos, size * 2.4, Color(STARPOINT_ABSORPTION_GLOW_COLOR.r, STARPOINT_ABSORPTION_GLOW_COLOR.g, STARPOINT_ABSORPTION_GLOW_COLOR.b, alpha * 0.35))
		canvas.draw_circle(pos, size, Color(1.0, 0.95, 0.55, alpha))


func _build_starpoint_absorption_star(center: Vector2, size: float, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var vertices: int = STARPOINT_ABSORPTION_STAR_TIP_COUNT * 2
	for idx in range(vertices):
		var r: float = size if idx % 2 == 0 else size * 0.5
		var a: float = rotation + float(idx) * PI / float(STARPOINT_ABSORPTION_STAR_TIP_COUNT)
		points.append(center + Vector2(cos(a), sin(a)) * r)
	return points


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
	var skill_id: String = str(skill.get("icon_id", skill.get("id", "")))
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
	elif skill_id == "mystic_dice":
		# 절차 five-pip 폴백: PNG 로드가 실패해도 주사위 카드가 주사위로
		# 읽히게 한다(둥근 몸체+5핍).
		canvas.draw_rect(Rect2(center - Vector2(radius * 0.82, radius * 0.82), Vector2(radius * 1.64, radius * 1.64)), Color(c.r, c.g, c.b, 0.85 * alpha))
		canvas.draw_rect(Rect2(center - Vector2(radius * 0.82, radius * 0.82), Vector2(radius * 1.64, radius * 1.64)), hi, false, 1.4)
		var pip_radius: float = radius * 0.16
		for pip_offset: Vector2 in [Vector2(-0.45, -0.45), Vector2(0.45, -0.45), Vector2(0.0, 0.0), Vector2(-0.45, 0.45), Vector2(0.45, 0.45)]:
			canvas.draw_circle(center + pip_offset * radius, pip_radius, hi)
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


# 런타임 선택 상태 패널이 스냅샷의 접힌 융합 projection을 그대로 소비한다
# (TAB presenter와 같은 fold — 융합 소스 퍽을 개별 셀로 재드로우하지 않고
# 재료쌍 합성 아이콘 키 하나로 라우팅).
func _build_acquired_perks_for_snapshot(levels: Dictionary, catalog: Object, runtime_state: Object, snapshot: Dictionary) -> Array:
	var entries: Array = CharacterInfoOverlayPerkPresenter.build_acquired_perks(
		levels,
		catalog,
		runtime_state,
		snapshot
	)
	# 상태 패널의 아이콘 라우팅은 엔트리 id를 그대로 아이콘 키로 쓴다 —
	# 융합 셀은 재료쌍 합성 키(리비전 포함)로 승격한다(TAB은 id=fusion_id와
	# _draw_id를 분리 유지하는 것과 대비되는 소비자별 계약).
	var filtered: Array = []
	for entry_value: Variant in entries:
		if not (entry_value is Dictionary):
			filtered.append(entry_value)
			continue
		var entry: Dictionary = entry_value as Dictionary
		# 오버레이 "현재 퍽" 계약: 액티브 스킬 해금 퍽(unlocks_skill)은 5-orb
		# 스킬 HUD 소유라 무조건 제외한다 — TAB 프레젠터의 "장착된 해금만
		# 숨김"(equipped lookup) 계약과 다른 소비자별 규칙.
		if str(entry.get("unlocks_skill", "")).strip_edges() != "":
			continue
		var draw_id := str(entry.get("_draw_id", ""))
		if draw_id.begins_with("perk_fusion_pair:"):
			entry["id"] = draw_id
		# 오버레이 상태 패널 계약(dash-token 슬롯 셀 스모크): 셀 플래그를
		# 평면 키(is_slot_cell)로 미러한다 — TAB 프레젠터는 _프리픽스 내부
		# 키(_is_slot_cell)를 쓰는 소비자별 계약.
		if bool(entry.get("_is_slot_cell", false)):
			entry["is_slot_cell"] = true
			entry["slot_cell_index"] = int(entry.get("_slot_cell_index", 0))
			entry["slot_cell_total"] = int(entry.get("_slot_cell_total", 1))
		filtered.append(entry)
	return filtered


# 레거시 3인자 진입점: snapshot 없는 호출을 정본 4인자 fold로 위임한다
# (별도 자체 빌더를 유지하면 projection 미인지 dead 경로가 재발한다).
func _build_acquired_perks(levels: Dictionary, catalog: Object, runtime_state: Object = null) -> Array:
	return _build_acquired_perks_for_snapshot(levels, catalog, runtime_state, {})


func _level_text(choice: Dictionary) -> String:
	var override := str(choice.get("level_text", ""))
	if override != "":
		return override
	if bool(choice.get("is_gold_conversion", false)):
		return LanguageSettings.translate_text("골드")
	if bool(choice.get("is_instant", false)):
		return LanguageSettings.translate_text("즉시")
	if _shows_character_unlock_badge(choice):
		return LanguageSettings.translate_text("해금")
	# 1회성(최대 Lv.1) 퍽은 레벨 대신 태그 — 신화 레어리티는 "신화", 그 외
	# "고유"(2026-07-09 문구 확정). 선택 카드와 획득 패널이 같은
	# 라우팅(LanguageSettings)을 쓴다.
	if int(choice.get("max_level", 99)) == 1 and str(choice.get("character_restriction", "")) == "":
		if str(choice.get("rarity", "")) == "mythic":
			return LanguageSettings.translate_text("신화")
		return LanguageSettings.translate_text("고유")
	return "Lv.%d" % int(choice.get("next_level", 1))


func _long_level_text(choice: Dictionary) -> String:
	var override := str(choice.get("long_level_text", ""))
	if override != "":
		return override
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


static func get_full_slot_hint() -> String:
	# 가득 시 실제 규칙은 '새 슬롯-소모 퍽만 제외'다: flag ON에서는 보유
	# 강화에 더해 비소모 후보(슬롯 확장·해금·즉시·골드·링펫)가 전부 계속
	# 나온다 — 특정 부류만 콕 집는 문구는 실제 후보와 다시 어긋난다.
	if PerkConversionFlags.is_enabled():
		return LanguageSettings.translate_text("강화·비소모 퍽만")
	return LanguageSettings.translate_text("보유 퍽 강화만")


func _draw_text(canvas: CanvasItem, text: String, baseline: Vector2, font_size: int, color: Color) -> void:
	text = LanguageSettings.translate_text(text)
	var font: Font = _get_font()
	if font == null or text == "":
		return
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_text_fitted(canvas: CanvasItem, text: String, baseline: Vector2, font_size: int, color: Color, max_width: float, min_font_size: int = 10) -> void:
	text = LanguageSettings.translate_text(text)
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
	text = LanguageSettings.translate_text(text)
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
