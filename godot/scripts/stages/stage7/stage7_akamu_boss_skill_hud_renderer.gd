extends RefCounted

# Stage 7 Akamu Rigo texture-backed boss skill-card HUD.
# Card state comes from stage7_akamu_state; this owner handles staged texture
# prewarm, cooldown wipes, status presentation, and the clone-count badge.

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const Stage7AkamuBossSkillHudAssets := preload("res://scripts/stages/stage7/stage7_akamu_boss_skill_hud_assets.gd")

const SIDE_STRIP_BASE := 2.0
const READY_BORDER := Color(0.48, 1.0, 0.64, 0.70)
const ACTIVE_BORDER := Color(1.0, 0.55, 0.22, 0.95)
const CHARGING_BORDER := Color(0.30, 0.36, 0.46, 0.66)
const PAUSED_BORDER := Color(0.26, 0.28, 0.32, 0.74)
const CARD_BG := Color(0.06, 0.08, 0.13, 0.95)
const PREWARM_SKILL_IDS := ["stage7_clone", "stage7_shuriken", "stage7_cloud", "stage7_superspeed"]
const TOOLTIP_STYLE := {
	"status_labels": {"active": "발동 중"},
	"status_colors": {"active": ACTIVE_BORDER},
}

const TOOLTIP_INFO := {
	"stage7_clone": {
		"name": "그림자분신",
		"trigger": "게이지 100 · 받아칠 때 25%",
		"cooldown": "8초",
		"description": "0.5초 시전 후 일반 상태에서는 2체, 초각성 상태에서는 4체의 분신을 전개합니다. 분신은 10초 동안 이동하며 공을 받으면 대신 반사하고 사라집니다.",
	},
	"stage7_shuriken": {
		"name": "표창",
		"trigger": "게이지 30",
		"cooldown": "8~25초",
		"description": "0.3초 시전 후 플레이어를 다시 조준해 표창을 던집니다. 적중하면 2초 동안 이동 속도를 80% 낮추고 기력을 최대 60 감소시킵니다.",
	},
	"stage7_cloud": {
		"name": "구름장막",
		"trigger": "게이지 120 · 받아칠 때 35%",
		"cooldown": "10~20초",
		"description": "0.4초 집중 후 중앙에서 하강해 넓은 구름을 펼치고 복귀합니다. 구름은 약 8.3초 동안 전장을 가리고, 돌진 중에는 공을 통과합니다.",
	},
	"stage7_superspeed": {
		"name": "극정호신",
		"trigger": "초각성 해금 · 게이지 250",
		"cooldown": "해금 및 종료 후 50초",
		"description": "초각성 완료 시 해금되어 첫 발동까지 50초를 기다립니다. 발동하면 0.35초 동안 전장을 멈춘 뒤 10초간 공의 예상 궤도로 연속 활주하며, 지속 중 받아칠 때의 기력 수급은 20으로 감소합니다.",
	},
}

const DISPLAY_NAMES := {
	"stage7_clone": "그림자분신",
	"stage7_shuriken": "표창",
	"stage7_cloud": "구름장막",
	"stage7_superspeed": "극정호신",
}

var _textures: Dictionary = {}
var _queue_positions: Dictionary = {}
var _prewarm_step_index := 0
var _prewarmed := false


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _prewarmed:
		return true
	if _prewarm_step_index >= PREWARM_SKILL_IDS.size():
		_prewarmed = true
		_prewarm_step_index = 0
		return true
	_get_skill_texture(str(PREWARM_SKILL_IDS[_prewarm_step_index]))
	_prewarm_step_index += 1
	if _prewarm_step_index >= PREWARM_SKILL_IDS.size():
		_prewarmed = true
		_prewarm_step_index = 0
		return true
	return false


func reset() -> void:
	_queue_positions.clear()


func get_debug_card_metrics(pillar_width: float) -> Dictionary:
	return BossSkillCardHudSpec.get_card_metrics(pillar_width)


func build_card_layout(context: Dictionary) -> Dictionary:
	if not bool(context.get("stage7_boss_skill_hud_active", false)):
		return {}
	var skills := _get_array(context.get("stage7_boss_skill_hud_skills", []))
	var entries: Array = []
	for value in skills:
		if value is Dictionary:
			entries.append(value)
	if entries.is_empty():
		return {}

	var view_size := _as_vector2(context.get("view_size", Vector2.ZERO))
	var game_offset := _as_vector2(context.get("game_offset", Vector2.ZERO))
	var game_size := _as_vector2(context.get("game_size", Vector2.ZERO))
	if view_size.x <= 0.0 or game_offset.x <= 0.0 or game_size.y <= 0.0:
		return {}
	entries.sort_custom(Callable(self, "_sort_entries"))

	var pillar_width := maxf(0.0, game_offset.x)
	var metrics := BossSkillCardHudSpec.get_card_metrics(pillar_width)
	var scale_factor := float(metrics.get("scale_factor", 1.0))
	var card_size := _as_vector2(metrics.get("card_size", Vector2(34.0, 10.0)))
	var card_gap := float(metrics.get("card_gap", 2.0))
	var margin_x := float(metrics.get("margin_x", 3.0))
	var margin_y := float(metrics.get("margin_y", 5.0))
	var total_height := float(entries.size()) * (card_size.y + card_gap) - card_gap
	var card_x := maxf(1.0, pillar_width - card_size.x - margin_x)
	var avoid_rect := _as_rect2(context.get("commando_firearm_panel_rect", Rect2()))
	var start_y := BossSkillCardHudSpec.resolve_stack_start_y(
		game_offset, game_size.y, total_height, margin_y,
		card_x, card_size.x, scale_factor, avoid_rect
	)
	var rects: Array = []
	for index in range(entries.size()):
		rects.append(Rect2(Vector2(card_x, start_y + float(index) * (card_size.y + card_gap)), card_size))
	return {"entries": entries, "rects": rects, "scale_factor": scale_factor}


func draw(canvas: CanvasItem, context: Dictionary) -> void:
	if canvas == null or int(context.get("current_stage", 1)) != 7:
		return
	var layout := build_card_layout(context)
	if layout.is_empty():
		return
	var entries := _get_array(layout.get("entries", []))
	var rects := _get_array(layout.get("rects", []))
	if entries.is_empty() or rects.size() < entries.size():
		return
	var scale_factor := float(layout.get("scale_factor", 1.0))
	var view_size := _as_vector2(context.get("view_size", Vector2.ZERO))
	var pillar_width := maxf(0.0, _as_vector2(context.get("game_offset", Vector2.ZERO)).x)
	var time_seconds := float(context.get("time_seconds", Time.get_ticks_msec() / 1000.0))
	var mouse_pos := BossSkillCardHudSpec.get_mouse_position(canvas)
	var hovered: Dictionary = {}
	var hovered_rect := Rect2()

	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var target_rect := _as_rect2(rects[index])
		var key := str(entry.get("id", "stage7_skill_%d" % index))
		var motion: Dictionary = BossSkillCardHudSpec.advance_card_shuffle(
			_queue_positions, key, target_rect.position.x, target_rect.position.y, scale_factor, time_seconds
		)
		var rect := Rect2(Vector2(float(motion.get("x", target_rect.position.x)), round(float(motion.get("y", target_rect.position.y)))), target_rect.size)
		_draw_card(canvas, rect, entry, scale_factor, time_seconds)
		if rect.has_point(mouse_pos):
			hovered = entry
			hovered_rect = rect
	_prune_queue_positions(entries)
	if not hovered.is_empty():
		var tooltip_info: Dictionary = (
			LingpetRailCard.tooltip_info(hovered) if LingpetRailCard.is_lingpet_skill(hovered)
			else _as_dictionary(TOOLTIP_INFO.get(str(hovered.get("id", "")), {}))
		)
		BossSkillCardHudSpec.draw_skill_tooltip(
			canvas, hovered, hovered_rect, view_size, pillar_width,
			tooltip_info, scale_factor, TOOLTIP_STYLE
		)


func get_asset_status() -> Dictionary:
	var clone_loaded := _get_skill_texture("stage7_clone") != null
	var shuriken_loaded := _get_skill_texture("stage7_shuriken") != null
	var cloud_loaded := _get_skill_texture("stage7_cloud") != null
	var superspeed_loaded := _get_skill_texture("stage7_superspeed") != null
	return {
		"clone_card_texture": clone_loaded,
		"shuriken_card_texture": shuriken_loaded,
		"cloud_card_texture": cloud_loaded,
		"superspeed_card_texture": superspeed_loaded,
		"uses_code_native_placeholder": not (
			clone_loaded and shuriken_loaded and cloud_loaded and superspeed_loaded
		),
	}


func _draw_card(canvas: CanvasItem, rect: Rect2, skill: Dictionary, scale_factor: float, time_seconds: float) -> void:
	if LingpetRailCard.is_lingpet_skill(skill):
		LingpetRailCard.draw_card(canvas, rect, skill, scale_factor, time_seconds)
		return
	var status := str(skill.get("status", "paused"))
	var paused := status == "paused" or status == "locked"
	var ready := not paused and (bool(skill.get("ready", false)) or status == "ready")
	var active := not paused and (bool(skill.get("active", false)) or status == "casting" or status == "active")
	var color := _as_color(skill.get("color", Color(0.6, 0.7, 1.0)))
	var fill_ratio := _resolve_fill_ratio(skill)
	var skill_id := str(skill.get("id", ""))
	var skill_texture := _get_skill_texture(skill_id)
	var has_texture := skill_texture != null

	_draw_skillcard_gauge(canvas, rect, skill_texture, fill_ratio, color)
	if active:
		var active_pulse := 0.55 + 0.45 * sin(time_seconds * 7.0)
		canvas.draw_rect(rect, Color(1.0, 0.42, 0.14, 0.14 + active_pulse * 0.14))
	elif ready:
		var ready_pulse := 0.5 + 0.5 * sin(time_seconds * 3.1)
		canvas.draw_rect(rect.grow(1.0 * scale_factor), Color(color.r, color.g, color.b, 0.08 + ready_pulse * 0.10), false, maxf(1.0, round(1.3 * scale_factor)))
	elif fill_ratio > 0.0 and fill_ratio < 1.0:
		var edge_x := rect.position.x + rect.size.x * fill_ratio
		canvas.draw_line(
			Vector2(edge_x, rect.position.y + 1.0),
			Vector2(edge_x, rect.end.y - 1.0),
			Color(1.0, 0.9, 0.5, 0.5),
			1.0,
			true
		)

	var border := PAUSED_BORDER if paused else CHARGING_BORDER
	if active:
		border = ACTIVE_BORDER
	elif ready:
		border = READY_BORDER
	canvas.draw_rect(rect, border, false, maxf(1.0, round((1.5 if active or ready else 1.0) * scale_factor)))

	var side_width := maxf(1.0, round(SIDE_STRIP_BASE * scale_factor))
	# 2분법: 보스 스킬 = 붉은 띠(적). 수호령 카드는 위 is_lingpet 분기에서 청록 띠로 그림.
	canvas.draw_rect(Rect2(rect.position, Vector2(side_width, rect.size.y)), BossSkillCardHudSpec.BOSS_SKILL_STRIP_COLOR)
	BossSkillCardHudSpec.draw_trigger_marker(canvas, skill, rect, scale_factor)
	var font := ThemeDB.fallback_font
	var active_count: int = int(skill.get("active_count", 0))
	if font != null and not has_texture:
		var label := str(DISPLAY_NAMES.get(skill_id, skill.get("name", "")))
		if active_count > 0:
			label += " ×%d" % active_count
		var font_size: int = maxi(8, int(round(8.0 * scale_factor)))
		var text_pos := Vector2(rect.position.x + side_width + 3.0, rect.get_center().y + float(font_size) * 0.35)
		canvas.draw_string(font, text_pos + Vector2.ONE, label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - side_width - 6.0, font_size, Color(0.0, 0.0, 0.0, 0.7))
		canvas.draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - side_width - 6.0, font_size, Color(0.96, 0.97, 1.0, 1.0))
	elif font != null and active_count > 0:
		_draw_clone_count_badge(canvas, rect, font, active_count, scale_factor)


func _resolve_fill_ratio(skill: Dictionary) -> float:
	var status := str(skill.get("status", "charging"))
	if status == "locked":
		return 0.0
	if (
		bool(skill.get("active", false))
		or status == "active"
		or status == "casting"
		or bool(skill.get("ready", false))
		or status == "ready"
	):
		return 1.0
	return clampf(float(skill.get("progress", 0.0)), 0.0, 1.0)


func _draw_skillcard_gauge(
	canvas: CanvasItem,
	rect: Rect2,
	texture: Texture2D,
	fill_ratio: float,
	fallback_color: Color
) -> void:
	var clamped_fill := clampf(fill_ratio, 0.0, 1.0)
	canvas.draw_rect(rect, CARD_BG)
	if texture == null:
		if clamped_fill > 0.0:
			canvas.draw_rect(
				Rect2(rect.position, Vector2(rect.size.x * clamped_fill, rect.size.y)),
				Color(fallback_color.r * 0.6, fallback_color.g * 0.55, fallback_color.b * 0.5, 0.82)
			)
		return

	# 종횡비 보존(cover) 게이지 draw는 공용 스펙으로 단일화(찌그러짐 방지).
	BossSkillCardHudSpec.draw_skillcard_gauge_fill(
		canvas,
		rect,
		texture,
		Rect2(Vector2.ZERO, texture.get_size()),
		clamped_fill,
		Color(0.18, 0.18, 0.22, 1.0),
		Color(1.0, 0.96, 0.90, 1.0)
	)


func _draw_clone_count_badge(
	canvas: CanvasItem,
	rect: Rect2,
	font: Font,
	active_count: int,
	scale_factor: float
) -> void:
	var label := "×%d" % active_count
	var font_size: int = maxi(8, int(round(6.5 * scale_factor)))
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var padding := maxf(1.5, round(1.25 * scale_factor))
	var badge_size := Vector2(
		minf(rect.size.x - 2.0, text_size.x + padding * 2.0),
		minf(rect.size.y - 2.0, maxf(8.0, text_size.y + padding))
	)
	var badge_rect := Rect2(
		Vector2(
			rect.end.x - badge_size.x - padding,
			rect.get_center().y - badge_size.y * 0.5
		),
		badge_size
	)
	canvas.draw_rect(badge_rect, Color(0.025, 0.018, 0.05, 0.88))
	canvas.draw_rect(badge_rect, Color(0.86, 0.68, 1.0, 0.90), false, maxf(1.0, round(0.65 * scale_factor)))
	var text_pos := Vector2(badge_rect.position.x, badge_rect.get_center().y + float(font_size) * 0.35)
	canvas.draw_string(
		font,
		text_pos,
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		badge_rect.size.x,
		font_size,
		Color(1.0, 0.94, 1.0, 1.0)
	)


func _get_skill_texture(skill_id: String) -> Texture2D:
	var path := _get_skill_texture_path(skill_id)
	if path.is_empty():
		return null
	if not _textures.has(path):
		_textures[path] = ProjectResourceLoader.load_texture(path)
	if _textures[path] is Texture2D:
		return _textures[path]
	return null


func _get_skill_texture_path(skill_id: String) -> String:
	if skill_id == "stage7_clone":
		return Stage7AkamuBossSkillHudAssets.SHADOW_CLONE_SKILLCARD_TEXTURE_PATH
	if skill_id == "stage7_shuriken":
		return Stage7AkamuBossSkillHudAssets.SHURIKEN_SKILLCARD_TEXTURE_PATH
	if skill_id == "stage7_cloud":
		return Stage7AkamuBossSkillHudAssets.CLOUD_SCREEN_SKILLCARD_TEXTURE_PATH
	if skill_id == "stage7_superspeed":
		return Stage7AkamuBossSkillHudAssets.SUPERSPEED_SKILLCARD_TEXTURE_PATH
	return ""


func _sort_entries(a: Dictionary, b: Dictionary) -> bool:
	return BossSkillCardHudSpec.compare_skill_entries_by_next_activation(a, b)


func _prune_queue_positions(entries: Array) -> void:
	var active_keys: Dictionary = {}
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


func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _as_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color(0.6, 0.7, 1.0)


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _as_rect2(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2()
