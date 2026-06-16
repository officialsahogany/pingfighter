extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const Stage1DaljiBossSkillHudUtils := preload("res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_utils.gd")
const Stage1DaljiBossSkillHudAssets := preload("res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_assets.gd")

const WHIP_SKILLCARD_TEXTURE_PATH := Stage1DaljiBossSkillHudAssets.WHIP_SKILLCARD_TEXTURE_PATH
const SPINNING_TOP_SKILLCARD_TEXTURE_PATH := Stage1DaljiBossSkillHudAssets.SPINNING_TOP_SKILLCARD_TEXTURE_PATH
const QUEUE_LERP_SPEED := 8.0
const SIDE_STRIP_BASE := 2.0
const TOOLTIP_WIDTH_BASE := 168.0
const TOOLTIP_PADDING_BASE := 10.0
const TOOLTIP_GAP_BASE := 8.0
const TOOLTIP_LINE_SPACING_BASE := 4.0
const TOOLTIP_MAX_DESC_LINES := 2
const TOOLTIP_SCALE_MIN := 0.85
const TOOLTIP_SCALE_MAX := 1.15
const TOOLTIP_MIN_LEFT_WIDTH := 120.0

var _skillcard_textures := {}
var _queue_positions := {}
var _prewarm_skillcard_step_index := 0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _prewarm_skillcard_step_index >= 2:
		return true
	match _prewarm_skillcard_step_index:
		0:
			_get_skillcard_texture("whip")
		1:
			_get_skillcard_texture("spinning_top")
	_prewarm_skillcard_step_index += 1
	return _prewarm_skillcard_step_index >= 2


func get_debug_card_metrics(pillar_width: float) -> Dictionary:
	return BossSkillCardHudSpec.get_card_metrics(pillar_width)


func build_card_layout(context: Dictionary) -> Dictionary:
	if not bool(context.get("stage1_dalji_boss_skill_hud_active", false)):
		return {}
	var skills: Array = Stage1DaljiBossSkillHudUtils.get_array(context.get("stage1_dalji_boss_skill_hud_skills", []))
	if skills.is_empty():
		return {}

	var view_size: Vector2 = Stage1DaljiBossSkillHudUtils.as_vector2(context.get("view_size", Vector2.ZERO), Vector2.ZERO)
	var game_offset: Vector2 = Stage1DaljiBossSkillHudUtils.as_vector2(context.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var game_size: Vector2 = Stage1DaljiBossSkillHudUtils.as_vector2(context.get("game_size", Vector2.ZERO), Vector2.ZERO)
	if view_size.x <= 0.0 or view_size.y <= 0.0 or game_size.y <= 0.0:
		return {}

	var entries := _skill_entries(skills)
	if entries.is_empty():
		return {}
	entries.sort_custom(Callable(self, "_sort_entries"))

	var pillar_w: float = max(0.0, game_offset.x)
	var pillar_h: float = max(0.0, game_size.y)
	if pillar_w < BossSkillCardHudSpec.CARD_MIN_SIZE.x + 4.0 or pillar_h < BossSkillCardHudSpec.CARD_MIN_SIZE.y:
		return {}

	var metrics: Dictionary = BossSkillCardHudSpec.get_card_metrics(pillar_w)
	var scale_factor: float = float(metrics.get("scale_factor", 1.0))
	var card_size: Vector2 = Stage1DaljiBossSkillHudUtils.as_vector2(metrics.get("card_size", Vector2(34.0, 10.0)), Vector2(34.0, 10.0))
	var card_w: float = card_size.x
	var card_h: float = card_size.y
	var card_gap: float = float(metrics.get("card_gap", 2.0))
	var margin_x: float = float(metrics.get("margin_x", 3.0))
	var margin_y: float = float(metrics.get("margin_y", 5.0))
	var total_h: float = float(entries.size()) * (card_h + card_gap) - card_gap
	var card_x: float = max(1.0, pillar_w - card_w - margin_x)
	var avoid_rect: Rect2 = Stage1DaljiBossSkillHudUtils.as_rect2(context.get("commando_firearm_panel_rect", Rect2()), Rect2())
	var start_y: float = BossSkillCardHudSpec.resolve_stack_start_y(
		game_offset,
		pillar_h,
		total_h,
		margin_y,
		card_x,
		card_w,
		scale_factor,
		avoid_rect
	)
	var rects := []
	for i in range(entries.size()):
		rects.append(Rect2(
			Vector2(card_x, start_y + float(i) * (card_h + card_gap)),
			Vector2(card_w, card_h)
		))
	return {
		"entries": entries,
		"rects": rects,
		"stack_rect": Stage1DaljiBossSkillHudUtils.union_rects(rects),
		"scale_factor": scale_factor,
	}


func draw(canvas: CanvasItem, context: Dictionary) -> void:
	if canvas == null or int(context.get("current_stage", 1)) != 1:
		return
	var layout: Dictionary = build_card_layout(context)
	if layout.is_empty():
		return
	var entries: Array = Stage1DaljiBossSkillHudUtils.get_array(layout.get("entries", []))
	var rects: Array = Stage1DaljiBossSkillHudUtils.get_array(layout.get("rects", []))
	if entries.is_empty() or rects.size() < entries.size():
		return
	var scale_factor: float = float(layout.get("scale_factor", 1.0))
	var view_size: Vector2 = Stage1DaljiBossSkillHudUtils.as_vector2(context.get("view_size", Vector2.ZERO), Vector2.ZERO)
	var game_offset: Vector2 = Stage1DaljiBossSkillHudUtils.as_vector2(context.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var pillar_w: float = max(0.0, game_offset.x)
	var time_seconds: float = float(context.get("time_seconds", Time.get_ticks_msec() / 1000.0))
	var mouse_pos: Vector2 = _get_mouse_position(canvas)
	var hovered_skill: Dictionary = {}
	var hovered_rect := Rect2()

	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var target_rect: Rect2 = Stage1DaljiBossSkillHudUtils.as_rect2(rects[i], Rect2())
		var target_y: float = target_rect.position.y
		var key: String = str(entry.get("id", "skill_%d" % i))
		var current_y: float = float(_queue_positions.get(key, target_y))
		current_y = lerp(current_y, target_y, min(1.0, QUEUE_LERP_SPEED / 60.0))
		_queue_positions[key] = current_y
		var card_rect := Rect2(Vector2(target_rect.position.x, round(current_y)), target_rect.size)
		_draw_card(
			canvas,
			card_rect,
			entry,
			scale_factor,
			time_seconds
		)
		if card_rect.has_point(mouse_pos):
			hovered_skill = entry
			hovered_rect = card_rect
	_prune_queue_positions(entries)
	if not hovered_skill.is_empty():
		_draw_skill_tooltip(canvas, hovered_skill, hovered_rect, view_size, pillar_w, _get_tooltip_scale(scale_factor))


func _draw_card(canvas: CanvasItem, rect: Rect2, skill: Dictionary, scale_factor: float, time_seconds: float) -> void:
	if LingpetRailCard.is_lingpet_skill(skill):
		LingpetRailCard.draw_card(canvas, rect, skill, scale_factor, time_seconds)
		return
	var status: String = str(skill.get("status", "charging"))
	var ready: bool = bool(skill.get("ready", false)) or status == "ready"
	var active: bool = status == "casting"
	var used: bool = status == "used" or bool(skill.get("used", false))
	var progress: float = clamp(float(skill.get("progress", 0.0)), 0.0, 1.0)
	var flash: float = clamp(float(skill.get("flash", 0.0)), 0.0, 1.0)
	var skill_color: Color = Stage1DaljiBossSkillHudUtils.as_color(
		skill.get("color", Color(1.0, 0.74, 0.22, 1.0)),
		Color(1.0, 0.74, 0.22, 1.0)
	)

	var skillcard := _get_skillcard_texture(str(skill.get("id", "")))
	var fill_ratio: float = 1.0 if active or ready else progress
	if used:
		fill_ratio = 0.0
	_draw_skillcard_gauge(canvas, rect, skillcard, fill_ratio, skill_color)

	if active:
		var active_pulse: float = 0.5 + 0.5 * sin(time_seconds * 6.7)
		canvas.draw_rect(rect, Color(1.0, 0.78, 0.22, 0.18 + 0.12 * active_pulse))
	elif used:
		canvas.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.58))
	elif not ready and fill_ratio > 0.0 and fill_ratio < 1.0:
		var edge_x: float = rect.position.x + rect.size.x * fill_ratio
		canvas.draw_line(
			Vector2(edge_x, rect.position.y + 1.0),
			Vector2(edge_x, rect.end.y - 1.0),
			Color(1.0, 0.86, 0.34, 0.48),
			max(1.0, round(1.0 * scale_factor))
		)

	if flash > 0.0:
		canvas.draw_rect(
			rect.grow(2.0 * scale_factor),
			Color(skill_color.r, skill_color.g, skill_color.b, 0.20 * flash),
			false,
			max(1.0, round(2.0 * scale_factor))
		)

	var border_color := Color(0.24, 0.24, 0.32, 0.56)
	var border_width: float = max(1.0, round(1.0 * scale_factor))
	if active:
		var cast_pulse: float = 0.7 + 0.3 * sin(time_seconds * 5.0)
		border_color = Color(1.0, 0.84, 0.26, 0.88 * cast_pulse)
		border_width = max(1.0, round(2.0 * scale_factor))
	elif ready:
		var ready_pulse: float = 0.6 + 0.4 * sin(time_seconds * 2.9)
		border_color = Color(0.40, 0.86, 0.58, 0.70 * ready_pulse)
	elif used:
		border_color = Color(0.28, 0.25, 0.25, 0.54)
	canvas.draw_rect(rect, border_color, false, border_width)

	var side_w: float = max(1.0, round(SIDE_STRIP_BASE * scale_factor))
	canvas.draw_rect(
		Rect2(rect.position + Vector2(0.0, border_width), Vector2(side_w, max(1.0, rect.size.y - border_width * 2.0))),
		Color(0.86, 0.20, 0.18, 0.72)
	)


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

	var gap: float = max(4.0, round(TOOLTIP_GAP_BASE * tooltip_scale))
	var left_available: float = max(0.0, card_rect.position.x - gap - 6.0)
	var width: float = TOOLTIP_WIDTH_BASE * tooltip_scale
	if left_available >= TOOLTIP_MIN_LEFT_WIDTH:
		width = min(width, left_available)
	var padding: float = TOOLTIP_PADDING_BASE * tooltip_scale
	var line_gap: float = TOOLTIP_LINE_SPACING_BASE * tooltip_scale
	var title_size: int = max(13, int(round(15.0 * tooltip_scale)))
	var normal_size: int = max(10, int(round(11.0 * tooltip_scale)))
	var small_size: int = max(9, int(round(9.0 * tooltip_scale)))
	var max_text_width: float = width - padding * 2.0
	var desc_lines: Array[String] = _wrap_text(LanguageSettings.translate_text(str(info.get("description", ""))), font, normal_size, max_text_width, TOOLTIP_MAX_DESC_LINES)
	var status_text: String = _get_tooltip_status_text(skill)
	var cooldown_seconds := float(info.get("cooldown_seconds", 0.0))
	var cooldown_language := LanguageSettings.get_language()
	var cooldown_text: String = "Cooldown %.0fs" % cooldown_seconds
	if cooldown_language == LanguageSettings.LANGUAGE_SPANISH:
		cooldown_text = "Recarga %.0fs" % cooldown_seconds
	elif cooldown_language == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		cooldown_text = "Recarga %.0fs" % cooldown_seconds
	elif cooldown_language == LanguageSettings.LANGUAGE_RUSSIAN:
		cooldown_text = "Перезарядка %.0fс" % cooldown_seconds
	elif cooldown_language == LanguageSettings.LANGUAGE_CHINESE:
		cooldown_text = "冷却%.0f秒" % cooldown_seconds
	elif cooldown_language == LanguageSettings.LANGUAGE_JAPANESE:
		cooldown_text = "クールタイム%.0f秒" % cooldown_seconds
	elif cooldown_language != LanguageSettings.LANGUAGE_ENGLISH:
		cooldown_text = "쿨타임 %.0f초" % cooldown_seconds
	var trigger_text: String = LanguageSettings.translate_text(str(info.get("trigger", "")))
	var title_h: float = 20.0 * tooltip_scale
	var meta_h: float = 17.0 * tooltip_scale
	var line_h: float = 14.0 * tooltip_scale
	var height: float = padding * 2.0 + title_h + meta_h + float(desc_lines.size()) * (line_h + line_gap)
	height = max(58.0 * tooltip_scale, height)

	var pos := Vector2(card_rect.position.x - width - gap, card_rect.position.y + card_rect.size.y * 0.5 - height * 0.5)
	if pos.x < 6.0:
		pos.x = min(card_rect.end.x + gap, view_size.x - width - 6.0)
	if pos.x < pillar_width and pos.x + width > pillar_width and card_rect.position.x - width - gap >= 6.0:
		pos.x = card_rect.position.x - width - gap
	pos.y = clamp(pos.y, 6.0, max(6.0, view_size.y - height - 6.0))
	var rect := Rect2(pos, Vector2(width, height))

	var skill_color: Color = Stage1DaljiBossSkillHudUtils.as_color(skill.get("color", Color(1.0, 0.76, 0.18, 1.0)), Color(1.0, 0.76, 0.18, 1.0))
	canvas.draw_rect(rect, Color(0.055, 0.045, 0.065, 0.94))
	canvas.draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), rect.size - Vector2(4.0, 4.0)), Color(0.14, 0.10, 0.12, 0.54), false, max(1.0, round(1.0 * tooltip_scale)))
	canvas.draw_rect(rect, Color(skill_color.r, skill_color.g, skill_color.b, 0.78), false, max(1.0, round(1.5 * tooltip_scale)))

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
	_draw_text(canvas, font, Vector2(pos.x + padding, cursor_y), "%s · %s" % [trigger_text, cooldown_text], small_size, Color(0.86, 0.76, 0.60, 1.0))
	cursor_y += meta_h
	for line in desc_lines:
		_draw_text(canvas, font, Vector2(pos.x + padding, cursor_y), line, normal_size, Color(0.88, 0.86, 0.80, 1.0))
		cursor_y += line_h + line_gap


func _draw_skillcard_gauge(
	canvas: CanvasItem,
	rect: Rect2,
	skillcard: Texture2D,
	fill_ratio: float,
	fallback_color: Color
) -> void:
	var clamped_fill: float = clamp(fill_ratio, 0.0, 1.0)
	canvas.draw_rect(rect, Color(0.06, 0.045, 0.075, 1.0))
	if skillcard == null:
		canvas.draw_rect(rect, Color(fallback_color.r * 0.16, fallback_color.g * 0.13, fallback_color.b * 0.10, 1.0))
		if clamped_fill > 0.0:
			canvas.draw_rect(
				Rect2(rect.position, Vector2(rect.size.x * clamped_fill, rect.size.y)),
				Color(fallback_color.r * 0.55, fallback_color.g * 0.28, fallback_color.b * 0.18, 1.0)
			)
		return

	canvas.draw_texture_rect(skillcard, rect, false, Color(0.18, 0.16, 0.18, 1.0))
	if clamped_fill <= 0.0:
		return
	var texture_size: Vector2 = skillcard.get_size()
	var source_width: float = texture_size.x * clamped_fill
	canvas.draw_texture_rect_region(
		skillcard,
		Rect2(rect.position, Vector2(rect.size.x * clamped_fill, rect.size.y)),
		Rect2(Vector2.ZERO, Vector2(source_width, texture_size.y))
	)


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
			active_keys[str(entry.get("id", ""))] = true
	for key in _queue_positions.keys():
		if not active_keys.has(str(key)):
			_queue_positions.erase(key)


func _get_skillcard_texture(skill_id: String) -> Texture2D:
	var path: String = _get_skillcard_texture_path(skill_id)
	if path == "":
		return null
	if not _skillcard_textures.has(path):
		_skillcard_textures[path] = ProjectResourceLoader.load_texture(
			path,
			"[Stage1DaljiBossSkillHud] missing skillcard texture: %s",
			"[Stage1DaljiBossSkillHud] failed to load skillcard texture: %s"
		)
	return _skillcard_textures[path]


func _get_skillcard_texture_path(skill_id: String) -> String:
	if skill_id == "whip":
		return WHIP_SKILLCARD_TEXTURE_PATH
	if skill_id == "spinning_top":
		return SPINNING_TOP_SKILLCARD_TEXTURE_PATH
	return ""


func _get_tooltip_info(value: Variant) -> Dictionary:
	var skill: Dictionary = {}
	var skill_id := ""
	if value is Dictionary:
		skill = value as Dictionary
		skill_id = str(skill.get("id", ""))
	else:
		skill_id = str(value)
	if skill_id == "whip":
		return {
			"name": "상모돌리기",
			"trigger": "타격발동",
			"cooldown_seconds": 22.0,
			"description": "공을 휘감아 아래로 몰아붙입니다. 플레이어가 가드하면 즉시 멈춥니다.",
		}
	if skill_id == "spinning_top":
		return {
			"name": "팽이치기",
			"trigger": "즉시발동",
			"cooldown_seconds": 16.0,
			"description": "달지가 팽이를 소환합니다. 팽이에 닿은 공은 무작위 방향으로 튕깁니다.",
		}
	if LingpetRailCard.is_lingpet_skill(skill) or skill_id == LingpetRailCard.SKILL_ID:
		return LingpetRailCard.tooltip_info(skill)
	return {}


func _get_tooltip_status_text(skill: Dictionary) -> String:
	var status: String = str(skill.get("status", "charging"))
	if status == "casting":
		return LanguageSettings.translate_text("발동 중")
	if status == "used":
		return LanguageSettings.translate_text("사용됨")
	if bool(skill.get("ready", false)) or status == "ready":
		return LanguageSettings.translate_text("준비 완료")
	var progress_percent := int(round(clamp(float(skill.get("progress", 0.0)), 0.0, 1.0) * 100.0))
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


func _get_tooltip_scale(scale_factor: float) -> float:
	return clamp(scale_factor, TOOLTIP_SCALE_MIN, TOOLTIP_SCALE_MAX)


func _get_status_color(skill: Dictionary) -> Color:
	var status: String = str(skill.get("status", "charging"))
	if status == "casting":
		return Color(1.0, 0.84, 0.26, 1.0)
	if status == "used":
		return Color(0.58, 0.55, 0.52, 1.0)
	if bool(skill.get("ready", false)) or status == "ready":
		return Color(0.48, 1.0, 0.64, 1.0)
	return Color(0.78, 0.72, 0.64, 1.0)


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
	canvas.draw_string(font, pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, min(0.72, color.a)))
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _get_mouse_position(canvas: CanvasItem) -> Vector2:
	var viewport: Viewport = canvas.get_viewport()
	if viewport == null:
		return Vector2(-100000.0, -100000.0)
	return viewport.get_mouse_position()
