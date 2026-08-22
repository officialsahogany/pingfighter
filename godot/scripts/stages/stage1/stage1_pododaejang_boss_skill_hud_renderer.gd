extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const Stage1DaljiBossSkillHudUtils := preload("res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_utils.gd")
const Stage1PododaejangBossSkillHudAssets := preload("res://scripts/stages/stage1/stage1_pododaejang_boss_skill_hud_assets.gd")

const PATROL_GUARDS_SKILLCARD_TEXTURE_PATH := Stage1PododaejangBossSkillHudAssets.PATROL_GUARDS_SKILLCARD_TEXTURE_PATH
const ARREST_ROPE_SKILLCARD_TEXTURE_PATH := Stage1PododaejangBossSkillHudAssets.ARREST_ROPE_SKILLCARD_TEXTURE_PATH
const QUEUE_LERP_SPEED := 8.0
const SIDE_STRIP_BASE := 2.0

var _patrol_guards_skillcard_texture: Texture2D = null
var _arrest_rope_skillcard_texture: Texture2D = null
var _queue_positions := {}
var _prewarm_done := false


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _prewarm_done:
		return true
	_get_skillcard_texture("patrol_guards")
	_get_skillcard_texture("arrest_rope")
	_prewarm_done = true
	return true


func get_debug_card_metrics(pillar_width: float) -> Dictionary:
	return BossSkillCardHudSpec.get_card_metrics(pillar_width)


func build_card_layout(context: Dictionary) -> Dictionary:
	if not bool(context.get("stage1_pododaejang_boss_skill_hud_active", false)):
		return {}
	var skills: Array = Stage1DaljiBossSkillHudUtils.get_array(
		context.get("stage1_pododaejang_boss_skill_hud_skills", [])
	)
	if skills.is_empty():
		return {}
	var view_size: Vector2 = Stage1DaljiBossSkillHudUtils.as_vector2(context.get("view_size", Vector2.ZERO), Vector2.ZERO)
	var game_offset: Vector2 = Stage1DaljiBossSkillHudUtils.as_vector2(context.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var game_size: Vector2 = Stage1DaljiBossSkillHudUtils.as_vector2(context.get("game_size", Vector2.ZERO), Vector2.ZERO)
	if view_size.x <= 0.0 or view_size.y <= 0.0 or game_size.y <= 0.0:
		return {}
	var entries: Array = _skill_entries(skills)
	if entries.is_empty():
		return {}
	entries.sort_custom(Callable(self, "_sort_entries"))
	var pillar_width: float = maxf(0.0, game_offset.x)
	var pillar_height: float = maxf(0.0, game_size.y)
	if pillar_width < BossSkillCardHudSpec.CARD_MIN_SIZE.x + 4.0 or pillar_height < BossSkillCardHudSpec.CARD_MIN_SIZE.y:
		return {}
	var metrics: Dictionary = BossSkillCardHudSpec.get_card_metrics(pillar_width)
	var scale_factor: float = float(metrics.get("scale_factor", 1.0))
	var card_size: Vector2 = Stage1DaljiBossSkillHudUtils.as_vector2(
		metrics.get("card_size", Vector2(34.0, 10.0)),
		Vector2(34.0, 10.0)
	)
	var card_gap: float = float(metrics.get("card_gap", 2.0))
	var margin_x: float = float(metrics.get("margin_x", 3.0))
	var margin_y: float = float(metrics.get("margin_y", 5.0))
	var total_height: float = float(entries.size()) * (card_size.y + card_gap) - card_gap
	var card_x: float = maxf(1.0, pillar_width - card_size.x - margin_x)
	var avoid_rect: Rect2 = Stage1DaljiBossSkillHudUtils.as_rect2(
		context.get("commando_firearm_panel_rect", Rect2()),
		Rect2()
	)
	var start_y: float = BossSkillCardHudSpec.resolve_stack_start_y(
		game_offset,
		pillar_height,
		total_height,
		margin_y,
		card_x,
		card_size.x,
		scale_factor,
		avoid_rect
	)
	var rects: Array = []
	for index in range(entries.size()):
		rects.append(Rect2(
			Vector2(card_x, start_y + float(index) * (card_size.y + card_gap)),
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
	var time_seconds: float = float(context.get("time_seconds", Time.get_ticks_msec() / 1000.0))
	var mouse_pos: Vector2 = BossSkillCardHudSpec.get_mouse_position(canvas)
	var hovered_skill: Dictionary = {}
	var hovered_rect := Rect2()
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var target_rect: Rect2 = Stage1DaljiBossSkillHudUtils.as_rect2(rects[index], Rect2())
		var key: String = str(entry.get("id", "skill_%d" % index))
		var current_y: float = float(_queue_positions.get(key, target_rect.position.y))
		current_y = lerpf(current_y, target_rect.position.y, minf(1.0, QUEUE_LERP_SPEED / 60.0))
		_queue_positions[key] = current_y
		var card_rect := Rect2(Vector2(target_rect.position.x, roundf(current_y)), target_rect.size)
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
			maxf(0.0, game_offset.x),
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
	var progress: float = clampf(float(skill.get("progress", 0.0)), 0.0, 1.0)
	var flash: float = clampf(float(skill.get("flash", 0.0)), 0.0, 1.0)
	var skill_color: Color = Stage1DaljiBossSkillHudUtils.as_color(
		skill.get("color", Color(0.55, 0.36, 0.18, 1.0)),
		Color(0.55, 0.36, 0.18, 1.0)
	)
	var fill_ratio: float = 1.0 if active or ready else progress
	if used:
		fill_ratio = 0.0
	_draw_skillcard_gauge(canvas, rect, _get_skillcard_texture(str(skill.get("id", ""))), fill_ratio, skill_color)
	if active:
		var pulse: float = 0.5 + 0.5 * sin(time_seconds * 6.7)
		canvas.draw_rect(rect, Color(1.0, 0.76, 0.24, 0.15 + 0.12 * pulse))
	elif used:
		canvas.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.60))
	if flash > 0.0:
		canvas.draw_rect(rect.grow(2.0 * scale_factor), Color(skill_color.r, skill_color.g, skill_color.b, 0.22 * flash), false, maxf(1.0, roundf(2.0 * scale_factor)))
	var border_color := Color(0.30, 0.24, 0.18, 0.70)
	var border_width: float = maxf(1.0, roundf(scale_factor))
	if active:
		border_color = Color(1.0, 0.80, 0.30, 0.92)
		border_width = maxf(1.0, roundf(2.0 * scale_factor))
	elif ready:
		border_color = Color(0.54, 0.88, 0.58, 0.78)
	canvas.draw_rect(rect, border_color, false, border_width)
	var side_width: float = maxf(1.0, roundf(SIDE_STRIP_BASE * scale_factor))
	canvas.draw_rect(
		Rect2(rect.position + Vector2(0.0, border_width), Vector2(side_width, maxf(1.0, rect.size.y - border_width * 2.0))),
		Color(0.67, 0.44, 0.20, 0.86)
	)


func _draw_skillcard_gauge(
	canvas: CanvasItem,
	rect: Rect2,
	skillcard: Texture2D,
	fill_ratio: float,
	fallback_color: Color
) -> void:
	var clamped_fill: float = clampf(fill_ratio, 0.0, 1.0)
	canvas.draw_rect(rect, Color(0.05, 0.04, 0.035, 1.0))
	if skillcard == null:
		canvas.draw_rect(rect, Color(fallback_color.r * 0.16, fallback_color.g * 0.13, fallback_color.b * 0.10, 1.0))
		if clamped_fill > 0.0:
			canvas.draw_rect(
				Rect2(rect.position, Vector2(rect.size.x * clamped_fill, rect.size.y)),
				Color(fallback_color.r * 0.58, fallback_color.g * 0.38, fallback_color.b * 0.22, 1.0)
			)
		return
	BossSkillCardHudSpec.draw_skillcard_gauge_fill(
		canvas,
		rect,
		skillcard,
		Rect2(Vector2.ZERO, skillcard.get_size()),
		clamped_fill,
		Color(0.14, 0.12, 0.10, 1.0),
		Color.WHITE
	)


func _skill_entries(skills: Array) -> Array:
	var entries: Array = []
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
	if skill_id == "patrol_guards":
		if _patrol_guards_skillcard_texture == null:
			_patrol_guards_skillcard_texture = ProjectResourceLoader.load_texture(
				PATROL_GUARDS_SKILLCARD_TEXTURE_PATH,
				"[Stage1PododaejangBossSkillHud] missing patrol guards skillcard texture: %s",
				"[Stage1PododaejangBossSkillHud] failed to load patrol guards skillcard texture: %s"
			)
		return _patrol_guards_skillcard_texture
	if skill_id == "arrest_rope":
		if _arrest_rope_skillcard_texture == null:
			_arrest_rope_skillcard_texture = ProjectResourceLoader.load_texture(
				ARREST_ROPE_SKILLCARD_TEXTURE_PATH,
				"[Stage1PododaejangBossSkillHud] missing arrest rope skillcard texture: %s",
				"[Stage1PododaejangBossSkillHud] failed to load arrest rope skillcard texture: %s"
			)
		return _arrest_rope_skillcard_texture
	return null


func _get_tooltip_info(skill: Dictionary) -> Dictionary:
	var skill_id: String = str(skill.get("id", ""))
	if skill_id == "patrol_guards":
		return {
			"name": "포졸소환",
			"trigger": "즉시 발동",
			"cooldown_seconds": 16.0,
			"description": "포졸 두 명이 순찰합니다. 포졸에 닿은 공은 속도를 유지한 채 무작위 방향으로 튕깁니다.",
		}
	if skill_id == "arrest_rope":
		return {
			"name": "포승줄",
			"trigger": "보스 타격 시 발동",
			"cooldown_seconds": 20.0,
			"description": "발사 지점을 피하지 못하면 포박되어 3초 동안 이동 속도가 절반이 됩니다. 대시로 끊을 수 있습니다.",
		}
	if LingpetRailCard.is_lingpet_skill(skill) or skill_id == LingpetRailCard.SKILL_ID:
		return LingpetRailCard.tooltip_info(skill)
	return {}
