extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const Stage1DaljiBossSkillHudUtils := preload("res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_utils.gd")
const Stage1GaksitalBossSkillHudAssets := preload("res://scripts/stages/stage1/stage1_gaksital_boss_skill_hud_assets.gd")

const FAN_THROW_SKILLCARD_TEXTURE_PATH := Stage1GaksitalBossSkillHudAssets.FAN_THROW_SKILLCARD_TEXTURE_PATH
const FAN_WIND_SKILLCARD_TEXTURE_PATH := Stage1GaksitalBossSkillHudAssets.FAN_WIND_SKILLCARD_TEXTURE_PATH
const QUEUE_LERP_SPEED := 8.0
const SIDE_STRIP_BASE := 2.0

var _skillcard_texture: Texture2D = null
var _fan_wind_skillcard_texture: Texture2D = null
var _queue_positions := {}
var _prewarm_skillcard_done := false


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _prewarm_skillcard_done:
		return true
	_get_skillcard_texture("fan_throw")
	_get_skillcard_texture("fan_wind")
	_prewarm_skillcard_done = true
	return true


func get_debug_card_metrics(pillar_width: float) -> Dictionary:
	return BossSkillCardHudSpec.get_card_metrics(pillar_width)


func build_card_layout(context: Dictionary) -> Dictionary:
	if not bool(context.get("stage1_gaksital_boss_skill_hud_active", false)):
		return {}
	var skills: Array = Stage1DaljiBossSkillHudUtils.get_array(context.get("stage1_gaksital_boss_skill_hud_skills", []))
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
	var card_gap: float = float(metrics.get("card_gap", 2.0))
	var margin_x: float = float(metrics.get("margin_x", 3.0))
	var margin_y: float = float(metrics.get("margin_y", 5.0))
	var total_h: float = float(entries.size()) * (card_size.y + card_gap) - card_gap
	var card_x: float = max(1.0, pillar_w - card_size.x - margin_x)
	var avoid_rect: Rect2 = Stage1DaljiBossSkillHudUtils.as_rect2(context.get("commando_firearm_panel_rect", Rect2()), Rect2())
	var start_y: float = BossSkillCardHudSpec.resolve_stack_start_y(
		game_offset,
		pillar_h,
		total_h,
		margin_y,
		card_x,
		card_size.x,
		scale_factor,
		avoid_rect
	)
	var rects := []
	for i in range(entries.size()):
		rects.append(Rect2(
			Vector2(card_x, start_y + float(i) * (card_size.y + card_gap)),
			card_size
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
	var mouse_pos: Vector2 = BossSkillCardHudSpec.get_mouse_position(canvas)
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
		_draw_card(canvas, card_rect, entry, scale_factor, time_seconds)
		if card_rect.has_point(mouse_pos):
			hovered_skill = entry
			hovered_rect = card_rect
	_prune_queue_positions(entries)
	if not hovered_skill.is_empty():
		BossSkillCardHudSpec.draw_skill_tooltip(
			canvas,
			hovered_skill,
			hovered_rect,
			view_size,
			pillar_w,
			_get_tooltip_info(hovered_skill),
			scale_factor,
			{"meta_separator": " / "}
		)


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
		skill.get("color", Color(0.92, 0.24, 0.16, 1.0)),
		Color(0.92, 0.24, 0.16, 1.0)
	)
	var fill_ratio: float = 1.0 if active or ready else progress
	if used:
		fill_ratio = 0.0
	_draw_skillcard_gauge(canvas, rect, _get_skillcard_texture(str(skill.get("id", ""))), fill_ratio, skill_color)
	if active:
		var active_pulse: float = 0.5 + 0.5 * sin(time_seconds * 6.7)
		canvas.draw_rect(rect, Color(1.0, 0.78, 0.22, 0.16 + 0.12 * active_pulse))
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
	if skill_id == "fan_throw":
		if _skillcard_texture == null:
			_skillcard_texture = ProjectResourceLoader.load_texture(
				FAN_THROW_SKILLCARD_TEXTURE_PATH,
				"[Stage1GaksitalBossSkillHud] missing skillcard texture: %s",
				"[Stage1GaksitalBossSkillHud] failed to load skillcard texture: %s"
			)
		return _skillcard_texture
	if skill_id == "fan_wind" and FAN_WIND_SKILLCARD_TEXTURE_PATH != "":
		if _fan_wind_skillcard_texture == null:
			_fan_wind_skillcard_texture = ProjectResourceLoader.load_texture(
				FAN_WIND_SKILLCARD_TEXTURE_PATH,
				"[Stage1GaksitalBossSkillHud] missing fan wind skillcard texture: %s",
				"[Stage1GaksitalBossSkillHud] failed to load fan wind skillcard texture: %s"
			)
		return _fan_wind_skillcard_texture
	return null


func _get_tooltip_info(skill: Dictionary) -> Dictionary:
	var skill_id: String = str(skill.get("id", ""))
	if skill_id == "fan_throw":
		return {
			"name": "부채던지기",
			"trigger": "즉시 발동",
			"cooldown_seconds": 16.0,
			"description": "회전하는 부채를 던집니다. 맞으면 잠시 기절하고 밀려납니다.",
		}
	if skill_id == "fan_wind":
		return {
			"name": "부채바람",
			"trigger": "보스 타격 시 발동",
			"cooldown_seconds": 20.0,
			"description": "부채바람 소용돌이로 공을 붙잡았다가 아래로 방출합니다.",
		}
	if LingpetRailCard.is_lingpet_skill(skill) or skill_id == LingpetRailCard.SKILL_ID:
		return LingpetRailCard.tooltip_info(skill)
	return {}
