extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")

const FIREBALL_SKILLCARD_TEXTURE_PATH := "res://assets/sprites/hud/stage5_hongryun_fireball_skillcard_imagegen_v1.png"
const INFERNO_SKILLCARD_TEXTURE_PATH := "res://assets/sprites/hud/stage5_hongryun_inferno_skillcard_imagegen_v1.png"
const ORB_FILL_SHEET_PATH := "res://assets/sprites/hud/stage5_hongryun_orb_fill_sheet_autosprite_v1.png"
const FIREBALL_FALLBACK_SHEET_PATH := "res://assets/sprites/hud/stage5_hongryun_motion_sprites_imagegen_v2.png"
const INFERNO_FALLBACK_SHEET_PATH := "res://assets/sprites/hud/stage5_hongryun_dragon_head_sheet_imagegen_v3_16f.png"
const CARD_TEXTURE_COLS := 4
const CARD_TEXTURE_ROWS := 4
const ORB_FILL_SHEET_COLS := 4
const ORB_FILL_SHEET_ROWS := 4
const ORB_FILL_FRAME_COUNT := 16
const ORB_FILL_ANIM_SEC := 0.55
const WIDE_SKILLCARD_ASPECT_MIN := 2.5
const SIDE_STRIP_BASE := 2.0
const TOOLTIP_WIDTH_BASE := 168.0
const TOOLTIP_PADDING_BASE := 10.0
const TOOLTIP_GAP_BASE := 8.0
const TOOLTIP_LINE_SPACING_BASE := 4.0
const TOOLTIP_MAX_DESC_LINES := BossSkillCardHudSpec.TOOLTIP_MAX_DESC_LINES
const TOOLTIP_SCALE_MIN := 0.85
const TOOLTIP_SCALE_MAX := 1.15
const TOOLTIP_MIN_LEFT_WIDTH := 120.0
const LOD_ACTIVE_THRESHOLD := 0.7
const SEVERE_LOD_ACTIVE_THRESHOLD := 0.6
const EMPTY_ORB_ARC_SEGMENTS := 28
const EMPTY_ORB_ARC_SEGMENTS_LOD := 20
const EMPTY_ORB_ARC_SEGMENTS_SEVERE_LOD := 14
const INFERNO_WEDGE_SEGMENTS_BASE := 18.0
const INFERNO_WEDGE_SEGMENTS_BASE_LOD := 12.0
const INFERNO_WEDGE_SEGMENTS_BASE_SEVERE_LOD := 8.0

const FIREBALL_CARD_COLOR := Color(0.95, 0.42, 0.30, 1.0)
const FIREBALL_SIDE_STRIP := Color(0.86, 0.20, 0.18, 0.72)
const INFERNO_CARD_COLOR := Color(1.0, 0.20, 0.20, 1.0)
const INFERNO_SIDE_STRIP := Color(1.0, 0.32, 0.18, 0.86)
const DRAGON_ORB_FILL := Color(1.0, 0.32, 0.20, 1.0)
const DRAGON_ORB_EMPTY := Color(0.45, 0.15, 0.12, 0.45)
const DRAGON_ORB_READY_PULSE_FREQ := 4.5
const INFERNO_CHARGE_WEDGE := Color(1.0, 0.92, 0.40, 0.90)
const INFERNO_CHARGE_PULSE_FREQ := 8.0
const STATUS_READY_BORDER := Color(0.48, 1.0, 0.64, 0.70)
const STATUS_CASTING_BORDER := Color(1.0, 0.84, 0.26, 0.88)
const STATUS_INFERNO_CHARGE_BORDER := Color(1.0, 0.30, 0.20, 0.95)
const STATUS_CHARGING_BORDER := Color(0.28, 0.23, 0.17, 0.70)
const STATUS_PAUSED_BORDER := Color(0.24, 0.22, 0.20, 0.62)
const STATUS_LOCKED_BORDER := Color(0.36, 0.34, 0.32, 0.62)

var _textures := {}
var _queue_positions := {}
var _last_dragon_orb_gauge := -1.0
var _orb_fill_anim_slot := -1
var _orb_fill_anim_started_at := -999.0
var _prewarm_step_index := 0
var _prewarmed := false


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _prewarmed:
		return true
	match _prewarm_step_index:
		0:
			_get_skill_texture("hongryun_fireball")
		1:
			_get_skill_texture("hongryun_inferno")
		2:
			_get_orb_fill_texture()
		_:
			_prewarmed = true
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	return false


func reset() -> void:
	_queue_positions.clear()
	_last_dragon_orb_gauge = -1.0
	_orb_fill_anim_slot = -1
	_orb_fill_anim_started_at = -999.0


func get_debug_card_metrics(pillar_width: float) -> Dictionary:
	return BossSkillCardHudSpec.get_card_metrics(pillar_width)


func build_card_layout(context: Dictionary) -> Dictionary:
	if not bool(context.get("stage5_boss_skill_hud_active", false)):
		return {}
	var skills: Array = _get_array(context.get("stage5_boss_skill_hud_skills", []))
	if skills.is_empty():
		return {}

	var view_size: Vector2 = _as_vector2(context.get("view_size", Vector2.ZERO), Vector2.ZERO)
	var game_offset: Vector2 = _as_vector2(context.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var game_size: Vector2 = _as_vector2(context.get("game_size", Vector2.ZERO), Vector2.ZERO)
	if view_size.x <= 0.0 or game_offset.x <= 0.0 or game_size.y <= 0.0:
		return {}

	var entries := _skill_entries(skills)
	if entries.is_empty():
		return {}
	entries.sort_custom(Callable(self, "_sort_entries"))

	var pillar_w: float = maxf(0.0, game_offset.x)
	var metrics: Dictionary = BossSkillCardHudSpec.get_card_metrics(pillar_w)
	var scale_factor: float = float(metrics.get("scale_factor", 1.0))
	var card_size: Vector2 = _as_vector2(metrics.get("card_size", Vector2(34.0, 10.0)), Vector2(34.0, 10.0))
	var card_w: float = card_size.x
	var card_h: float = card_size.y
	var card_gap: float = float(metrics.get("card_gap", 2.0))
	var margin_x: float = float(metrics.get("margin_x", 3.0))
	var margin_y: float = float(metrics.get("margin_y", 5.0))
	var total_h: float = float(entries.size()) * (card_h + card_gap) - card_gap
	var card_x: float = maxf(1.0, pillar_w - card_w - margin_x)
	var avoid_rect: Rect2 = _as_rect2(context.get("commando_firearm_panel_rect", Rect2()), Rect2())
	var start_y: float = BossSkillCardHudSpec.resolve_stack_start_y(
		game_offset,
		game_size.y,
		total_h,
		margin_y,
		card_x,
		card_w,
		scale_factor,
		avoid_rect
	)
	var rects := []
	for idx in range(entries.size()):
		rects.append(Rect2(
			Vector2(card_x, start_y + float(idx) * (card_h + card_gap)),
			Vector2(card_w, card_h)
		))
	return {
		"entries": entries,
		"rects": rects,
		"scale_factor": scale_factor,
	}


func draw(canvas: CanvasItem, context: Dictionary) -> void:
	if canvas == null or int(context.get("current_stage", 1)) != 5:
		return
	var layout: Dictionary = build_card_layout(context)
	if layout.is_empty():
		return
	var entries: Array = _get_array(layout.get("entries", []))
	var rects: Array = _get_array(layout.get("rects", []))
	if entries.is_empty() or rects.size() < entries.size():
		return

	var scale_factor: float = float(layout.get("scale_factor", 1.0))
	var view_size: Vector2 = _as_vector2(context.get("view_size", Vector2.ZERO), Vector2.ZERO)
	var game_offset: Vector2 = _as_vector2(context.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var pillar_w: float = maxf(0.0, game_offset.x)
	var time_seconds: float = float(context.get("time_seconds", Time.get_ticks_msec() / 1000.0))
	var quality_scale: float = float(context.get("stage5_hud_quality_scale", 1.0))
	var mouse_pos: Vector2 = _get_mouse_position(canvas)
	var hovered_skill: Dictionary = {}
	var hovered_rect := Rect2()

	for idx in range(entries.size()):
		var entry: Dictionary = entries[idx]
		var target_rect: Rect2 = _as_rect2(rects[idx], Rect2())
		var target_y: float = target_rect.position.y
		var key: String = str(entry.get("id", "stage5_skill_%d" % idx))
		var motion: Dictionary = BossSkillCardHudSpec.advance_card_shuffle(
			_queue_positions, key, target_rect.position.x, target_y, scale_factor, time_seconds
		)
		var rect := Rect2(Vector2(float(motion.get("x", target_rect.position.x)), round(float(motion.get("y", target_y)))), target_rect.size)
		_draw_card(canvas, rect, entry, scale_factor, time_seconds, quality_scale)
		if rect.has_point(mouse_pos):
			hovered_skill = entry
			hovered_rect = rect
	_prune_queue_positions(entries)
	if not hovered_skill.is_empty():
		_draw_skill_tooltip(canvas, hovered_skill, hovered_rect, view_size, pillar_w, _get_tooltip_scale(scale_factor))


func get_asset_status() -> Dictionary:
	return {
		"fireball_card_texture": _get_skill_texture("hongryun_fireball") != null,
		"inferno_card_texture": _get_skill_texture("hongryun_inferno") != null,
		"orb_fill_sheet_texture": _get_orb_fill_texture() != null,
	}


func _draw_card(canvas: CanvasItem, rect: Rect2, skill: Dictionary, scale_factor: float, time_seconds: float, quality_scale: float) -> void:
	if LingpetRailCard.is_lingpet_skill(skill):
		LingpetRailCard.draw_card(canvas, rect, skill, scale_factor, time_seconds)
		return
	var status: String = str(skill.get("status", "charging"))
	var ready: bool = bool(skill.get("ready", false)) or status == "ready"
	var active: bool = bool(skill.get("active", false)) or status == "casting" or status == "inferno_charge"
	var locked: bool = status == "locked"
	var progress: float = clampf(float(skill.get("progress", 0.0)), 0.0, 1.0)
	var skill_color: Color = _as_color(skill.get("color", _default_skill_color(str(skill.get("id", "")))), _default_skill_color(str(skill.get("id", ""))))
	var fill_ratio: float = 1.0 if active or ready else progress
	if locked:
		fill_ratio = 0.0
	_draw_skillcard_gauge(canvas, rect, str(skill.get("id", "")), fill_ratio, skill_color)

	if status == "inferno_charge":
		var charge_pulse: float = 0.55 + 0.45 * sin(time_seconds * INFERNO_CHARGE_PULSE_FREQ)
		canvas.draw_rect(rect, Color(1.0, 0.22, 0.12, 0.18 + charge_pulse * 0.16))
		_draw_inferno_charge_wedge(canvas, rect, float(skill.get("inferno_charge_progress", 0.0)), scale_factor, quality_scale)
	elif active:
		var active_pulse: float = 0.55 + 0.45 * sin(time_seconds * 7.0)
		canvas.draw_rect(rect, Color(1.0, 0.38, 0.12, 0.14 + active_pulse * 0.12))
	elif ready:
		var ready_pulse: float = 0.5 + 0.5 * sin(time_seconds * 3.1)
		canvas.draw_rect(rect.grow(1.0 * scale_factor), Color(skill_color.r, skill_color.g, skill_color.b, 0.10 + ready_pulse * 0.10), false, maxf(1.0, round(1.4 * scale_factor)))
	elif fill_ratio > 0.0 and fill_ratio < 1.0:
		var edge_x: float = rect.position.x + rect.size.x * fill_ratio
		canvas.draw_line(Vector2(edge_x, rect.position.y + 1.0), Vector2(edge_x, rect.end.y - 1.0), Color(1.0, 0.88, 0.44, 0.50), 1.0, true)

	if str(skill.get("render_kind", "")) == "dragon_orb_gauge":
		_draw_dragon_orb_overlay(
			canvas,
			rect,
			float(skill.get("gauge", 0.0)),
			max(1, int(skill.get("gauge_max", 5))),
			ready,
			status == "inferno_charge",
			time_seconds,
			scale_factor,
			quality_scale
		)

	var border := _get_border_color(status, ready, active, locked, time_seconds)
	var border_width: float = maxf(1.0, round(scale_factor))
	if active or ready:
		border_width = maxf(1.0, round(1.5 * scale_factor))
	canvas.draw_rect(rect, border, false, border_width)

	var side_w: float = maxf(1.0, round(SIDE_STRIP_BASE * scale_factor))
	canvas.draw_rect(
		Rect2(rect.position + Vector2(0.0, border_width), Vector2(side_w, maxf(1.0, rect.size.y - border_width * 2.0))),
		_get_side_strip_color(str(skill.get("id", "")))
	)
	BossSkillCardHudSpec.draw_trigger_marker(canvas, skill, rect, scale_factor)


func _draw_skillcard_gauge(canvas: CanvasItem, rect: Rect2, skill_id: String, fill_ratio: float, fallback_color: Color) -> void:
	var clamped_fill: float = clampf(fill_ratio, 0.0, 1.0)
	canvas.draw_rect(rect, Color(0.050, 0.030, 0.025, 0.96))
	var texture: Texture2D = _get_skill_texture(skill_id)
	var source_rect: Rect2 = _get_skill_source_rect(skill_id, texture)
	if texture == null or source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		if clamped_fill > 0.0:
			canvas.draw_rect(
				Rect2(rect.position, Vector2(rect.size.x * clamped_fill, rect.size.y)),
				Color(fallback_color.r * 0.58, fallback_color.g * 0.50, fallback_color.b * 0.44, 0.82)
			)
		return
	# 종횡비 보존(cover) 게이지 draw는 공용 스펙으로 단일화(찌그러짐 방지).
	BossSkillCardHudSpec.draw_skillcard_gauge_fill(
		canvas,
		rect,
		texture,
		source_rect,
		clamped_fill,
		Color(0.22, 0.17, 0.15, 1.0),
		Color(1.0, 0.96, 0.90, 1.0)
	)


func _draw_dragon_orb_overlay(
	canvas: CanvasItem,
	rect: Rect2,
	gauge: float,
	gauge_max: int,
	ready: bool,
	inferno_charge: bool,
	time_seconds: float,
	scale_factor: float,
	quality_scale: float
) -> void:
	var max_count: int = max(1, gauge_max)
	var clamped_gauge: float = clampf(gauge, 0.0, float(max_count))
	_update_orb_fill_animation_state(clamped_gauge, time_seconds)
	var side_w: float = maxf(1.0, round(SIDE_STRIP_BASE * scale_factor))
	var gap: float = maxf(1.0, round(1.0 * scale_factor))
	var margin_x: float = maxf(2.0, 2.0 * scale_factor)
	var available_w: float = maxf(1.0, rect.size.x - side_w - margin_x * 2.0)
	var max_slot_w: float = maxf(2.0 * scale_factor, (available_w - float(max_count - 1) * gap) / float(max_count))
	var slot_h: float = minf(rect.size.y * 0.62, max_slot_w)
	slot_h = maxf(3.0 * scale_factor, slot_h)
	var slot_w: float = slot_h
	var total_w: float = float(max_count) * slot_w + float(max_count - 1) * gap
	var x: float = rect.end.x - total_w - margin_x
	x = maxf(rect.position.x + side_w + 1.0 * scale_factor, x)
	var y: float = rect.end.y - slot_h - maxf(1.0, rect.size.y * 0.08)
	var full_count: int = int(floor(clamped_gauge))
	var frac: float = clamped_gauge - float(full_count)
	var severe_lod := _is_severe_lod(quality_scale)
	var pulse: float = 1.0
	if ready:
		pulse = 0.7 + 0.3 * sin(time_seconds * DRAGON_ORB_READY_PULSE_FREQ)
	for idx in range(max_count):
		var slot_rect := Rect2(Vector2(x + float(idx) * (slot_w + gap), y), Vector2(slot_w, slot_h))
		var fill: float = 0.0
		if idx < full_count:
			fill = 1.0
		elif idx == full_count and frac > 0.0:
			fill = frac
		var alpha_scale: float = pulse
		if inferno_charge:
			alpha_scale *= 0.55 + 0.25 * sin(time_seconds * INFERNO_CHARGE_PULSE_FREQ + float(idx))
		_draw_empty_orb_slot(canvas, slot_rect, scale_factor, quality_scale)
		if fill > 0.0:
			var frame_index: int = _resolve_orb_fill_frame(idx, fill, time_seconds)
			if not _draw_orb_fill_frame(canvas, slot_rect, frame_index, alpha_scale):
				_draw_procedural_orb_fill(canvas, slot_rect, fill, alpha_scale)
		if ready and not severe_lod:
			canvas.draw_rect(slot_rect.grow(0.75 * scale_factor), Color(DRAGON_ORB_FILL.r, DRAGON_ORB_FILL.g, DRAGON_ORB_FILL.b, 0.22 * pulse), false, maxf(1.0, round(scale_factor)))


func _update_orb_fill_animation_state(gauge: float, time_seconds: float) -> void:
	if _last_dragon_orb_gauge < 0.0:
		_last_dragon_orb_gauge = gauge
		return
	if gauge > _last_dragon_orb_gauge + 0.01:
		_orb_fill_anim_slot = clampi(int(ceil(gauge)) - 1, 0, 4)
		_orb_fill_anim_started_at = time_seconds
	elif gauge < _last_dragon_orb_gauge - 0.01:
		_orb_fill_anim_slot = -1
	_last_dragon_orb_gauge = gauge


func _resolve_orb_fill_frame(slot_index: int, fill: float, time_seconds: float) -> int:
	if slot_index == _orb_fill_anim_slot:
		var elapsed: float = time_seconds - _orb_fill_anim_started_at
		if elapsed >= 0.0 and elapsed < ORB_FILL_ANIM_SEC:
			return clampi(int(floor((elapsed / ORB_FILL_ANIM_SEC) * float(ORB_FILL_FRAME_COUNT))), 0, ORB_FILL_FRAME_COUNT - 1)
	return clampi(int(round(clampf(fill, 0.0, 1.0) * float(ORB_FILL_FRAME_COUNT - 1))), 0, ORB_FILL_FRAME_COUNT - 1)


func _draw_empty_orb_slot(canvas: CanvasItem, slot_rect: Rect2, scale_factor: float, quality_scale: float) -> void:
	var center: Vector2 = slot_rect.get_center()
	var radius: float = minf(slot_rect.size.x, slot_rect.size.y) * 0.48
	var segments: int = _get_lod_count(EMPTY_ORB_ARC_SEGMENTS, EMPTY_ORB_ARC_SEGMENTS_LOD, EMPTY_ORB_ARC_SEGMENTS_SEVERE_LOD, quality_scale)
	canvas.draw_circle(center, radius, Color(DRAGON_ORB_EMPTY.r, DRAGON_ORB_EMPTY.g, DRAGON_ORB_EMPTY.b, 0.34))
	canvas.draw_arc(center, radius, 0.0, TAU, segments, Color(1.0, 0.34, 0.20, 0.54), maxf(1.0, round(0.9 * scale_factor)), true)
	if not _is_severe_lod(quality_scale):
		canvas.draw_arc(center, radius * 0.70, 0.0, TAU, segments, Color(0.92, 0.12, 0.08, 0.32), maxf(1.0, round(0.65 * scale_factor)), true)


func _draw_orb_fill_frame(canvas: CanvasItem, slot_rect: Rect2, frame_index: int, alpha_scale: float) -> bool:
	var texture: Texture2D = _get_orb_fill_texture()
	if texture == null:
		return false
	var source_rect: Rect2 = _get_orb_fill_source_rect(frame_index, texture)
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return false
	var draw_rect: Rect2 = slot_rect.grow(slot_rect.size.x * 0.24)
	canvas.draw_texture_rect_region(
		texture,
		draw_rect,
		source_rect,
		Color(1.0, 0.96, 0.88, clampf(alpha_scale, 0.0, 1.0)),
		false,
		true
	)
	return true


func _draw_procedural_orb_fill(canvas: CanvasItem, slot_rect: Rect2, fill: float, alpha_scale: float) -> void:
	var center: Vector2 = slot_rect.get_center()
	var radius: float = minf(slot_rect.size.x, slot_rect.size.y) * (0.20 + 0.28 * clampf(fill, 0.0, 1.0))
	canvas.draw_circle(center, radius, Color(DRAGON_ORB_FILL.r, DRAGON_ORB_FILL.g, DRAGON_ORB_FILL.b, minf(1.0, DRAGON_ORB_FILL.a * alpha_scale)))


func _draw_inferno_charge_wedge(canvas: CanvasItem, rect: Rect2, progress: float, scale_factor: float, quality_scale: float) -> void:
	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	if clamped_progress <= 0.0:
		return
	var radius: float = maxf(4.0 * scale_factor, rect.size.y * 0.45)
	var center := Vector2(rect.end.x - radius * 0.35, rect.position.y + radius * 0.30)
	var points := PackedVector2Array()
	points.append(center)
	var segment_base: float = INFERNO_WEDGE_SEGMENTS_BASE
	if quality_scale <= SEVERE_LOD_ACTIVE_THRESHOLD:
		segment_base = INFERNO_WEDGE_SEGMENTS_BASE_SEVERE_LOD
	elif quality_scale <= LOD_ACTIVE_THRESHOLD:
		segment_base = INFERNO_WEDGE_SEGMENTS_BASE_LOD
	var steps: int = max(5, int(ceil(segment_base * clamped_progress)))
	var start_angle: float = -PI * 0.5
	var sweep: float = -TAU * clamped_progress
	for step in range(steps + 1):
		var ratio: float = float(step) / float(steps)
		var angle: float = start_angle + sweep * ratio
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	canvas.draw_colored_polygon(points, INFERNO_CHARGE_WEDGE)
	canvas.draw_arc(center, radius, start_angle + sweep, start_angle, steps, Color(1.0, 0.66, 0.24, 0.88), maxf(1.0, round(scale_factor)), true)


func _draw_skill_tooltip(
	canvas: CanvasItem,
	skill: Dictionary,
	card_rect: Rect2,
	view_size: Vector2,
	pillar_width: float,
	tooltip_scale: float
) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var info: Dictionary = _get_tooltip_info(skill)
	if info.is_empty():
		return

	var gap: float = maxf(4.0, round(TOOLTIP_GAP_BASE * tooltip_scale))
	var left_available: float = maxf(0.0, card_rect.position.x - gap - 6.0)
	var width: float = TOOLTIP_WIDTH_BASE * tooltip_scale
	if left_available >= TOOLTIP_MIN_LEFT_WIDTH:
		width = minf(width, left_available)
	var padding: float = TOOLTIP_PADDING_BASE * tooltip_scale
	var line_gap: float = TOOLTIP_LINE_SPACING_BASE * tooltip_scale
	var title_size: int = max(13, int(round(15.0 * tooltip_scale)))
	var normal_size: int = max(10, int(round(11.0 * tooltip_scale)))
	var small_size: int = max(9, int(round(9.0 * tooltip_scale)))
	var max_text_width: float = width - padding * 2.0
	var desc_lines: Array[String] = _wrap_text(str(info.get("description", "")), font, normal_size, max_text_width, TOOLTIP_MAX_DESC_LINES)
	var status_text: String = _get_tooltip_status_text(skill)
	var trigger_text: String = str(info.get("trigger", ""))
	var cooldown_text: String = str(info.get("cooldown", ""))
	var title_h: float = 20.0 * tooltip_scale
	var meta_h: float = 17.0 * tooltip_scale
	var line_h: float = 14.0 * tooltip_scale
	var height: float = padding * 2.0 + title_h + meta_h + float(desc_lines.size()) * (line_h + line_gap)
	height = maxf(58.0 * tooltip_scale, height)

	var pos := Vector2(card_rect.position.x - width - gap, card_rect.position.y + card_rect.size.y * 0.5 - height * 0.5)
	if pos.x < 6.0:
		pos.x = minf(card_rect.end.x + gap, view_size.x - width - 6.0)
	if pos.x < pillar_width and pos.x + width > pillar_width and card_rect.position.x - width - gap >= 6.0:
		pos.x = card_rect.position.x - width - gap
	pos.y = clampf(pos.y, 6.0, maxf(6.0, view_size.y - height - 6.0))
	var rect := Rect2(pos, Vector2(width, height))

	var skill_color: Color = _as_color(skill.get("color", FIREBALL_CARD_COLOR), FIREBALL_CARD_COLOR)
	canvas.draw_rect(rect, Color(0.055, 0.035, 0.030, 0.94))
	canvas.draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), rect.size - Vector2(4.0, 4.0)), Color(0.18, 0.08, 0.06, 0.54), false, maxf(1.0, round(1.0 * tooltip_scale)))
	canvas.draw_rect(rect, Color(skill_color.r, skill_color.g, skill_color.b, 0.78), false, maxf(1.0, round(1.5 * tooltip_scale)))

	var cursor_y: float = pos.y + padding
	_draw_text(canvas, font, Vector2(pos.x + padding, cursor_y), str(info.get("name", "")), title_size, Color(1.0, 0.92, 0.74, 1.0))
	var status_size: Vector2 = font.get_string_size(status_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, small_size)
	_draw_text(
		canvas,
		font,
		Vector2(pos.x + width - padding - status_size.x, cursor_y + 2.0 * tooltip_scale),
		status_text,
		small_size,
		_get_status_color(skill)
	)
	cursor_y += title_h
	# 쿨다운이 없는 카드(상호작용 권한형 링펫 카드)는 " / " 꼬리표가 남지 않게
	# 공용 메타라인 규칙을 통과시킨다.
	_draw_text(canvas, font, Vector2(pos.x + padding, cursor_y), BossSkillCardHudSpec.build_meta_line(trigger_text, cooldown_text, " / "), small_size, Color(0.90, 0.76, 0.58, 1.0))
	cursor_y += meta_h
	for line in desc_lines:
		_draw_text(canvas, font, Vector2(pos.x + padding, cursor_y), line, normal_size, Color(0.90, 0.86, 0.78, 1.0))
		cursor_y += line_h + line_gap


func _get_skill_texture(skill_id: String) -> Texture2D:
	for path in _get_skill_texture_paths(skill_id):
		if not _textures.has(path):
			_textures[path] = ProjectResourceLoader.load_texture(path)
		if _textures[path] is Texture2D:
			return _textures[path]
	return null


func _get_skill_texture_paths(skill_id: String) -> Array[String]:
	if skill_id == "hongryun_fireball":
		return [FIREBALL_SKILLCARD_TEXTURE_PATH, FIREBALL_FALLBACK_SHEET_PATH]
	if skill_id == "hongryun_inferno":
		return [INFERNO_SKILLCARD_TEXTURE_PATH, INFERNO_FALLBACK_SHEET_PATH]
	return []


func _get_orb_fill_texture() -> Texture2D:
	if not _textures.has(ORB_FILL_SHEET_PATH):
		_textures[ORB_FILL_SHEET_PATH] = ProjectResourceLoader.load_texture(ORB_FILL_SHEET_PATH)
	if _textures[ORB_FILL_SHEET_PATH] is Texture2D:
		return _textures[ORB_FILL_SHEET_PATH]
	return null


func _get_skill_source_rect(skill_id: String, texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()
	var size: Vector2 = texture.get_size()
	if size.x / maxf(1.0, size.y) >= WIDE_SKILLCARD_ASPECT_MIN:
		return Rect2(Vector2.ZERO, size)
	var cell := Vector2(size.x / float(CARD_TEXTURE_COLS), size.y / float(CARD_TEXTURE_ROWS))
	var index := 0
	if skill_id == "hongryun_inferno":
		index = 0
	var col: int = index % CARD_TEXTURE_COLS
	var row: int = int(floor(float(index) / float(CARD_TEXTURE_COLS))) % CARD_TEXTURE_ROWS
	return Rect2(Vector2(float(col) * cell.x, float(row) * cell.y), cell)


func _get_orb_fill_source_rect(frame_index: int, texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()
	var size: Vector2 = texture.get_size()
	var cell := Vector2(size.x / float(ORB_FILL_SHEET_COLS), size.y / float(ORB_FILL_SHEET_ROWS))
	var index: int = clampi(frame_index, 0, ORB_FILL_FRAME_COUNT - 1)
	var col: int = index % ORB_FILL_SHEET_COLS
	var row: int = int(floor(float(index) / float(ORB_FILL_SHEET_COLS))) % ORB_FILL_SHEET_ROWS
	return Rect2(Vector2(float(col) * cell.x, float(row) * cell.y), cell)


func _get_tooltip_info(value: Variant) -> Dictionary:
	var skill: Dictionary = {}
	var skill_id := ""
	if value is Dictionary:
		skill = value as Dictionary
		skill_id = str(skill.get("id", ""))
	else:
		skill_id = str(value)
	if skill_id == "hongryun_fireball":
		return {
			"name": "홍련 화염구",
			"trigger": "자동",
			"cooldown": "쿨타임 3.5~5.0초",
			"description": "홍련이 화염구를 발사합니다. 맞으면 용 구슬 게이지가 1칸 충전됩니다.",
		}
	if skill_id == "hongryun_inferno":
		return {
			"name": "홍련 인페르노",
			"trigger": "구슬 5칸 / 보스 적중",
			"cooldown": "용 구슬 5칸",
			"description": "5번 맞으면 홍련이 공을 화염 용처럼 돌진시킵니다. 가드와 진입 각도를 흔듭니다.",
		}
	if LingpetRailCard.is_lingpet_skill(skill) or skill_id == LingpetRailCard.SKILL_ID:
		return LingpetRailCard.tooltip_info(skill)
	return {}


func _get_tooltip_status_text(skill: Dictionary) -> String:
	var status: String = str(skill.get("status", "charging"))
	if status == "inferno_charge":
		return LanguageSettings.translate_text("인페르노 예열")
	if status == "casting":
		return LanguageSettings.translate_text("발동 중")
	if status == "paused":
		return LanguageSettings.translate_text("대기")
	if status == "locked":
		return LanguageSettings.translate_text("잠김")
	if bool(skill.get("ready", false)) or status == "ready":
		return LanguageSettings.translate_text("준비 완료")
	var progress_percent := int(round(clampf(float(skill.get("progress", 0.0)), 0.0, 1.0) * 100.0))
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
		return "Charge %d%%" % progress_percent
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
		return "Carga %d%%" % progress_percent
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return "Carga %d%%" % progress_percent
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
		return "Заряд %d%%" % progress_percent
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
		return "充能 %d%%" % progress_percent
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
		return "チャージ %d%%" % progress_percent
	return "충전 %d%%" % progress_percent


func _get_status_color(skill: Dictionary) -> Color:
	var status: String = str(skill.get("status", "charging"))
	if status == "inferno_charge":
		return Color(1.0, 0.44, 0.28, 1.0)
	if status == "casting":
		return Color(1.0, 0.84, 0.26, 1.0)
	if status == "paused":
		return Color(0.72, 0.68, 0.62, 1.0)
	if status == "locked":
		return Color(0.58, 0.55, 0.52, 1.0)
	if bool(skill.get("ready", false)) or status == "ready":
		return Color(0.48, 1.0, 0.64, 1.0)
	return Color(0.78, 0.72, 0.64, 1.0)


func _get_border_color(status: String, ready: bool, active: bool, locked: bool, time_seconds: float) -> Color:
	if status == "inferno_charge":
		var charge_pulse: float = 0.65 + 0.35 * sin(time_seconds * INFERNO_CHARGE_PULSE_FREQ)
		return Color(STATUS_INFERNO_CHARGE_BORDER.r, STATUS_INFERNO_CHARGE_BORDER.g, STATUS_INFERNO_CHARGE_BORDER.b, STATUS_INFERNO_CHARGE_BORDER.a * charge_pulse)
	if active:
		var cast_pulse: float = 0.70 + 0.30 * sin(time_seconds * 5.0)
		return Color(STATUS_CASTING_BORDER.r, STATUS_CASTING_BORDER.g, STATUS_CASTING_BORDER.b, STATUS_CASTING_BORDER.a * cast_pulse)
	if ready:
		var ready_pulse: float = 0.60 + 0.40 * sin(time_seconds * 2.9)
		return Color(STATUS_READY_BORDER.r, STATUS_READY_BORDER.g, STATUS_READY_BORDER.b, STATUS_READY_BORDER.a * ready_pulse)
	if locked:
		return STATUS_LOCKED_BORDER
	if status == "paused":
		return STATUS_PAUSED_BORDER
	return STATUS_CHARGING_BORDER


func _get_side_strip_color(skill_id: String) -> Color:
	if skill_id == "hongryun_inferno":
		return INFERNO_SIDE_STRIP
	return FIREBALL_SIDE_STRIP


func _default_skill_color(skill_id: String) -> Color:
	if skill_id == "hongryun_inferno":
		return INFERNO_CARD_COLOR
	return FIREBALL_CARD_COLOR


func _skill_entries(skills: Array) -> Array:
	var entries := []
	for value in skills:
		if value is Dictionary:
			entries.append(value)
	return entries


func _sort_entries(a: Dictionary, b: Dictionary) -> bool:
	return BossSkillCardHudSpec.compare_skill_entries_by_next_activation(a, b)


func _prune_queue_positions(entries: Array) -> void:
	var active_keys := {}
	for entry in entries:
		if entry is Dictionary:
			active_keys[str((entry as Dictionary).get("id", ""))] = true
	for key in _queue_positions.keys():
		if not active_keys.has(str(key)):
			_queue_positions.erase(key)


func _wrap_text(text: String, font: Font, font_size: int, max_width: float, max_lines: int) -> Array[String]:
	var lines: Array[String] = []
	var current := ""
	for word in LanguageSettings.translate_text(text).split(" ", false):
		var candidate: String = word if current == "" else "%s %s" % [current, word]
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width:
			current = candidate
			continue
		if current != "":
			lines.append(current)
			if lines.size() >= max_lines:
				return lines
		current = word
	if current != "" and lines.size() < max_lines:
		lines.append(current)
	return lines


func _draw_text(canvas: CanvasItem, font: Font, pos: Vector2, text: String, font_size: int, color: Color) -> void:
	text = LanguageSettings.translate_text(text)
	canvas.draw_string(font, pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, minf(0.72, color.a)))
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _get_tooltip_scale(scale_factor: float) -> float:
	return clampf(scale_factor, TOOLTIP_SCALE_MIN, TOOLTIP_SCALE_MAX)


func _get_lod_count(normal_count: int, lod_count: int, severe_count: int, quality_scale: float) -> int:
	if quality_scale <= SEVERE_LOD_ACTIVE_THRESHOLD:
		return severe_count
	if quality_scale <= LOD_ACTIVE_THRESHOLD:
		return lod_count
	return normal_count


func _is_severe_lod(quality_scale: float) -> bool:
	return quality_scale <= SEVERE_LOD_ACTIVE_THRESHOLD


func _get_mouse_position(canvas: CanvasItem) -> Vector2:
	var viewport: Viewport = canvas.get_viewport()
	if viewport == null:
		return Vector2(-100000.0, -100000.0)
	return viewport.get_mouse_position()


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback


func _as_rect2(value: Variant, fallback: Rect2) -> Rect2:
	if value is Rect2:
		return value
	return fallback


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
