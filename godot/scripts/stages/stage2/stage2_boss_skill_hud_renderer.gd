extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")

const JUNGLE_QUAKE_SKILLCARD_TEXTURE_PATH := "res://assets/sprites/hud/stage2_jungle_quake_skillcard_imagegen_v1.png"
const SPEED_DEFENSE_SKILLCARD_TEXTURE_PATH := "res://assets/sprites/hud/stage2_speed_defense_skillcard_imagegen_v3.png"
const WATER_CANNON_SKILLCARD_TEXTURE_PATH := "res://assets/sprites/hud/stage2_water_cannon_skillcard_imagegen_v1.png"

var _skillcard_textures := {}


func prewarm_assets() -> void:
	_get_skillcard_texture("jungle_quake")
	_get_skillcard_texture("speed_defense")
	_get_skillcard_texture("water_cannon")


func get_debug_card_metrics(pillar_width: float) -> Dictionary:
	return BossSkillCardHudSpec.get_card_metrics(pillar_width)


func draw(canvas: CanvasItem, context: Dictionary) -> void:
	if canvas == null or int(context.get("current_stage", 1)) != 2:
		return
	if not bool(context.get("stage2_boss_skill_hud_active", false)):
		return
	var skills: Array = _get_array(context.get("stage2_boss_skill_hud_skills", []))
	if skills.is_empty():
		return

	var game_offset: Vector2 = _as_vector2(context.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var game_size: Vector2 = _as_vector2(context.get("game_size", Vector2.ZERO), Vector2.ZERO)
	if game_offset.x <= 0.0 or game_size.y <= 0.0:
		return

	var entries := _skill_entries(skills)
	if entries.is_empty():
		return

	var pillar_w: float = max(0.0, game_offset.x)
	var metrics: Dictionary = BossSkillCardHudSpec.get_card_metrics(pillar_w)
	var scale_factor: float = float(metrics.get("scale_factor", 1.0))
	var card_size: Vector2 = _as_vector2(metrics.get("card_size", Vector2(34.0, 10.0)), Vector2(34.0, 10.0))
	var card_w: float = card_size.x
	var card_h: float = card_size.y
	var card_gap: float = float(metrics.get("card_gap", 2.0))
	var margin_x: float = float(metrics.get("margin_x", 3.0))
	var margin_y: float = float(metrics.get("margin_y", 5.0))
	var total_h: float = float(entries.size()) * (card_h + card_gap) - card_gap
	var start_y: float = game_offset.y + max(margin_y, floor((game_size.y - total_h) * 0.5))
	var card_x: float = max(1.0, pillar_w - card_w - margin_x)
	var font: Font = ThemeDB.fallback_font

	for i in range(entries.size()):
		var skill: Dictionary = entries[i]
		var rect := Rect2(Vector2(card_x, start_y + float(i) * (card_h + card_gap)), Vector2(card_w, card_h))
		_draw_card(canvas, rect, skill, scale_factor, font)


func _draw_card(canvas: CanvasItem, rect: Rect2, skill: Dictionary, scale_factor: float, font: Font) -> void:
	var status: String = str(skill.get("status", "charging"))
	var ready: bool = bool(skill.get("ready", false)) or status == "ready"
	var active: bool = status == "casting"
	var locked: bool = status == "locked"
	var progress: float = clamp(float(skill.get("progress", 0.0)), 0.0, 1.0)
	var skill_color: Color = _as_color(skill.get("color", Color(0.35, 0.78, 1.0, 1.0)), Color(0.35, 0.78, 1.0, 1.0))
	var fill_ratio: float = 1.0 if active or ready else progress
	if locked:
		fill_ratio = 0.0

	var skillcard := _get_skillcard_texture(str(skill.get("id", "")))
	_draw_skillcard_gauge(canvas, rect, skillcard, fill_ratio, skill_color, locked)

	var border_color := Color(0.22, 0.25, 0.30, 0.70)
	if active:
		border_color = Color(0.80, 0.94, 1.0, 0.96)
	elif ready:
		border_color = Color(0.45, 1.0, 0.62, 0.84)
	elif locked:
		border_color = Color(0.36, 0.38, 0.40, 0.64)
	canvas.draw_rect(rect, border_color, false, max(1.0, round(1.0 * scale_factor)))

	if skillcard != null or font == null or rect.size.x < 31.0:
		return
	var label: String = str(skill.get("label", ""))
	var font_size: int = max(8, int(round(9.0 * scale_factor)))
	var text_width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	if text_width > rect.size.x - 4.0:
		label = label.substr(0, 1)
	var text_pos := Vector2(rect.position.x + 3.0, rect.position.y + rect.size.y - 3.0)
	canvas.draw_string(font, text_pos + Vector2(1.0, 1.0), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 6.0, font_size, Color(0.0, 0.0, 0.0, 0.72))
	canvas.draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 6.0, font_size, Color(0.93, 0.96, 0.98, 0.95))


func _draw_skillcard_gauge(
	canvas: CanvasItem,
	rect: Rect2,
	skillcard: Texture2D,
	fill_ratio: float,
	fallback_color: Color,
	locked: bool
) -> void:
	var clamped_fill: float = clamp(fill_ratio, 0.0, 1.0)
	canvas.draw_rect(rect, Color(0.04, 0.05, 0.07, 0.92))
	if skillcard == null:
		if clamped_fill > 0.0:
			canvas.draw_rect(
				Rect2(rect.position, Vector2(rect.size.x * clamped_fill, rect.size.y)),
				Color(fallback_color.r * 0.55, fallback_color.g * 0.48, fallback_color.b * 0.48, 0.72)
			)
		return

	var dim := Color(0.15, 0.16, 0.16, 1.0) if locked else Color(0.20, 0.19, 0.18, 1.0)
	canvas.draw_texture_rect(skillcard, rect, false, dim)
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


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_skillcard_texture(skill_id: String) -> Texture2D:
	var path: String = _get_skillcard_texture_path(skill_id)
	if path == "":
		return null
	if not _skillcard_textures.has(path):
		_skillcard_textures[path] = ProjectResourceLoader.load_texture(
			path,
			"[Stage2BossSkillHud] missing skillcard texture: %s",
			"[Stage2BossSkillHud] failed to load skillcard texture: %s"
		)
	return _skillcard_textures[path]


func _get_skillcard_texture_path(skill_id: String) -> String:
	if skill_id == "jungle_quake":
		return JUNGLE_QUAKE_SKILLCARD_TEXTURE_PATH
	if skill_id == "speed_defense":
		return SPEED_DEFENSE_SKILLCARD_TEXTURE_PATH
	if skill_id == "water_cannon":
		return WATER_CANNON_SKILLCARD_TEXTURE_PATH
	return ""


func _as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
