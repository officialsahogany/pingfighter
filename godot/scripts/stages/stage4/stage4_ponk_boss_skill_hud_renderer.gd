extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const Stage4PonkBossSkillHudAssets := preload("res://scripts/stages/stage4/stage4_ponk_boss_skill_hud_assets.gd")

const MAGNETIC_FIELD_SKILLCARD_TEXTURE_PATH := Stage4PonkBossSkillHudAssets.MAGNETIC_FIELD_SKILLCARD_TEXTURE_PATH
const MEDITATION_SKILLCARD_TEXTURE_PATH := Stage4PonkBossSkillHudAssets.MEDITATION_SKILLCARD_TEXTURE_PATH
const ILLUSION_RIPPLE_SKILLCARD_TEXTURE_PATH := Stage4PonkBossSkillHudAssets.ILLUSION_RIPPLE_SKILLCARD_TEXTURE_PATH
const MAGNETIC_FIELD_FALLBACK_SHEET_PATH := Stage4PonkBossSkillHudAssets.MAGNETIC_FIELD_FALLBACK_SHEET_PATH
const MEDITATION_FALLBACK_SHEET_PATH := Stage4PonkBossSkillHudAssets.MEDITATION_FALLBACK_SHEET_PATH
const CARD_TEXTURE_COLS := Stage4PonkBossSkillHudAssets.CARD_TEXTURE_COLS
const CARD_TEXTURE_ROWS := Stage4PonkBossSkillHudAssets.CARD_TEXTURE_ROWS
const SIDE_STRIP_BASE := 2.0
const WIDE_SKILLCARD_ASPECT_MIN := 2.5

var _textures := {}
var _queue_positions := {}
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
			_get_skill_texture("magnetic_field")
		1:
			_get_skill_texture("meditation")
		2:
			_get_skill_texture("illusion_ripple")
		_:
			_prewarmed = true
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	if _prewarm_step_index > 2:
		_prewarmed = true
		_prewarm_step_index = 0
		return true
	return false


func reset() -> void:
	_queue_positions.clear()


func get_debug_card_metrics(pillar_width: float) -> Dictionary:
	return BossSkillCardHudSpec.get_card_metrics(pillar_width)


func draw(canvas: CanvasItem, context: Dictionary) -> void:
	if canvas == null or int(context.get("current_stage", 1)) != 4:
		return
	if not bool(context.get("stage4_ponk_boss_skill_hud_active", false)):
		return
	var skills: Array = _get_array(context.get("stage4_ponk_boss_skill_hud_skills", []))
	if skills.is_empty():
		return
	var view_size: Vector2 = _as_vector2(context.get("view_size", Vector2.ZERO), Vector2.ZERO)
	var game_offset: Vector2 = _as_vector2(context.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var game_size: Vector2 = _as_vector2(context.get("game_size", Vector2.ZERO), Vector2.ZERO)
	if view_size.x <= 0.0 or game_offset.x <= 0.0 or game_size.y <= 0.0:
		return

	var entries := _skill_entries(skills)
	if entries.is_empty():
		return
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
	var time_seconds: float = float(context.get("time_seconds", Time.get_ticks_msec() / 1000.0))
	var mouse_pos: Vector2 = BossSkillCardHudSpec.get_mouse_position(canvas)
	var hovered_skill: Dictionary = {}
	var hovered_rect := Rect2()

	for idx in range(entries.size()):
		var entry: Dictionary = entries[idx]
		var target_y: float = start_y + float(idx) * (card_h + card_gap)
		var key: String = str(entry.get("id", "stage4_skill_%d" % idx))
		var motion: Dictionary = BossSkillCardHudSpec.advance_card_shuffle(
			_queue_positions, key, card_x, target_y, scale_factor, time_seconds
		)
		var rect := Rect2(Vector2(float(motion.get("x", card_x)), round(float(motion.get("y", target_y)))), Vector2(card_w, card_h))
		_draw_card(canvas, rect, entry, scale_factor, time_seconds)
		if rect.has_point(mouse_pos):
			hovered_skill = entry
			hovered_rect = rect
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
			{
				"background_color": Color(0.055, 0.045, 0.035, 0.94),
				"inner_color": Color(0.15, 0.11, 0.07, 0.54),
			}
		)


func get_asset_status() -> Dictionary:
	return {
		"magnetic_card_texture": _get_skill_texture("magnetic_field") != null,
		"meditation_card_texture": _get_skill_texture("meditation") != null,
		"illusion_ripple_card_texture": _get_skill_texture("illusion_ripple") != null,
	}


func _draw_card(canvas: CanvasItem, rect: Rect2, skill: Dictionary, scale_factor: float, time_seconds: float) -> void:
	if LingpetRailCard.is_lingpet_skill(skill):
		LingpetRailCard.draw_card(canvas, rect, skill, scale_factor, time_seconds)
		return
	var status: String = str(skill.get("status", "charging"))
	var ready: bool = bool(skill.get("ready", false)) or status == "ready"
	var active: bool = bool(skill.get("active", false)) or status == "casting"
	var locked: bool = status == "locked"
	var progress: float = clampf(float(skill.get("progress", 0.0)), 0.0, 1.0)
	var skill_color: Color = _as_color(skill.get("color", Color(0.75, 0.86, 1.0, 1.0)), Color(0.75, 0.86, 1.0, 1.0))
	var fill_ratio: float = 1.0 if active or ready else progress
	if locked:
		fill_ratio = 0.0
	_draw_skillcard_gauge(canvas, rect, str(skill.get("id", "")), fill_ratio, skill_color)

	if active:
		var active_pulse: float = 0.55 + 0.45 * sin(time_seconds * 7.0)
		canvas.draw_rect(rect, Color(1.0, 0.28, 0.12, 0.16 + active_pulse * 0.12))
	elif ready:
		var ready_pulse: float = 0.5 + 0.5 * sin(time_seconds * 3.1)
		canvas.draw_rect(rect.grow(1.0 * scale_factor), Color(skill_color.r, skill_color.g, skill_color.b, 0.10 + ready_pulse * 0.10), false, maxf(1.0, round(1.4 * scale_factor)))
	elif fill_ratio > 0.0 and fill_ratio < 1.0:
		var edge_x: float = rect.position.x + rect.size.x * fill_ratio
		canvas.draw_line(Vector2(edge_x, rect.position.y + 1.0), Vector2(edge_x, rect.end.y - 1.0), Color(1.0, 0.88, 0.44, 0.50), 1.0, true)

	var border := Color(0.28, 0.23, 0.17, 0.70)
	if active:
		border = Color(1.0, 0.35, 0.18, 0.96)
	elif ready:
		border = Color(0.54, 1.0, 0.72, 0.90)
	elif locked:
		border = Color(0.36, 0.34, 0.32, 0.62)
	canvas.draw_rect(rect, border, false, maxf(1.0, round(scale_factor)))

	var side_w: float = maxf(1.0, round(SIDE_STRIP_BASE * scale_factor))
	canvas.draw_rect(Rect2(rect.position + Vector2(0.0, 1.0), Vector2(side_w, rect.size.y - 2.0)), Color(0.95, 0.28, 0.16, 0.74))
	BossSkillCardHudSpec.draw_trigger_marker(canvas, skill, rect, scale_factor)


func _draw_skillcard_gauge(canvas: CanvasItem, rect: Rect2, skill_id: String, fill_ratio: float, fallback_color: Color) -> void:
	var clamped_fill: float = clampf(fill_ratio, 0.0, 1.0)
	canvas.draw_rect(rect, Color(0.040, 0.030, 0.020, 0.96))
	var texture: Texture2D = _get_skill_texture(skill_id)
	var source_rect: Rect2 = _get_skill_source_rect(skill_id, texture)
	if texture == null or source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		if clamped_fill > 0.0:
			canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clamped_fill, rect.size.y)), Color(fallback_color.r * 0.58, fallback_color.g * 0.50, fallback_color.b * 0.44, 0.82))
		return
	# 종횡비 보존(cover) 게이지 draw는 공용 스펙으로 단일화(찌그러짐 방지).
	BossSkillCardHudSpec.draw_skillcard_gauge_fill(
		canvas,
		rect,
		texture,
		source_rect,
		clamped_fill,
		Color(0.20, 0.18, 0.16, 1.0),
		Color(1.0, 0.96, 0.90, 1.0)
	)


func _get_skill_texture(skill_id: String) -> Texture2D:
	for path in _get_skill_texture_paths(skill_id):
		if not _textures.has(path):
			_textures[path] = ProjectResourceLoader.load_texture(path)
		if _textures[path] is Texture2D:
			return _textures[path]
	return null


func _get_skill_texture_paths(skill_id: String) -> Array[String]:
	if skill_id == "magnetic_field":
		return [MAGNETIC_FIELD_SKILLCARD_TEXTURE_PATH, MAGNETIC_FIELD_FALLBACK_SHEET_PATH]
	if skill_id == "meditation":
		return [MEDITATION_SKILLCARD_TEXTURE_PATH, MEDITATION_FALLBACK_SHEET_PATH]
	if skill_id == "illusion_ripple":
		return [ILLUSION_RIPPLE_SKILLCARD_TEXTURE_PATH]
	return []


func _get_skill_source_rect(skill_id: String, texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()
	var size: Vector2 = texture.get_size()
	if size.x / maxf(1.0, size.y) >= WIDE_SKILLCARD_ASPECT_MIN:
		return Rect2(Vector2.ZERO, size)
	var cell := Vector2(size.x / float(CARD_TEXTURE_COLS), size.y / float(CARD_TEXTURE_ROWS))
	var index := 0
	if skill_id == "meditation":
		index = 5
	var col: int = index % CARD_TEXTURE_COLS
	var row: int = int(floor(float(index) / float(CARD_TEXTURE_COLS))) % CARD_TEXTURE_ROWS
	return Rect2(Vector2(float(col) * cell.x, float(row) * cell.y), cell)


func _get_tooltip_info(skill: Dictionary) -> Dictionary:
	if LingpetRailCard.is_lingpet_skill(skill):
		return LingpetRailCard.tooltip_info(skill)
	return {
		"name": str(skill.get("name", skill.get("label", skill.get("short_label", "")))),
		"trigger": str(skill.get("trigger", "")),
		"cooldown_seconds": float(skill.get("cooldown_seconds", skill.get("cooldown_total", 0.0))),
		"description": str(skill.get("description", "")),
	}


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


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _as_rect2(value: Variant, fallback: Rect2) -> Rect2:
	if value is Rect2:
		return value
	return fallback
