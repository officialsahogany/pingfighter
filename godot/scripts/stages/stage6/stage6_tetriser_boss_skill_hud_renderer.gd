extends RefCounted

# Stage 6 테트리서 boss skill HUD renderer (달지식 보스 스킬 카드 HUD).
#
# 기획: docs/stage6_tetriser_port_plan.md §3,§7
# 원본의 오른쪽 세로 게이지바 대신, 공유 BossSkillCardHudSpec 레이아웃으로
# 게이지 + 4스킬(낙하 테트로 / 가드 블록 / 테트로 벽 / 초인테트리서)을 카드 스택으로
# 표현한다. 테트리서 전용 스킬카드 텍스처는 아직 없어 카드는 절차적으로 그린다.
# 카드 데이터는 stage6_tetriser_state.get_hud_context()의
# `stage6_boss_skill_hud_skills`.

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const Stage6TetriserBossSkillHudAssets := preload("res://scripts/stages/stage6/stage6_tetriser_boss_skill_hud_assets.gd")

const SIDE_STRIP_BASE := 2.0
const READY_BORDER := Color(0.48, 1.0, 0.64, 0.70)
const ACTIVE_BORDER := Color(1.0, 0.55, 0.22, 0.95)
const CHARGING_BORDER := Color(0.30, 0.36, 0.46, 0.66)
const PAUSED_BORDER := Color(0.26, 0.28, 0.32, 0.60)
const CARD_BG := Color(0.06, 0.08, 0.13, 0.95)
const PREWARM_SKILL_IDS := ["stage6_tetro_drop", "stage6_guard", "stage6_wall", "stage6_super"]

const TOOLTIP_INFO := {
	"stage6_tetro_drop": {
		"name": "낙하 테트로", "trigger": "자동(5~10초)", "cooldown": "게이지 30",
		"description": "테트로미노 블록이 조립되어 낙하·정착합니다. 공/활주/연막으로 파괴.",
	},
	"stage6_guard": {
		"name": "가드 블록", "trigger": "자동(7~15초)", "cooldown": "게이지 50/100",
		"description": "보스 좌우에 4셀 가로 바를 전개해 상단을 방어합니다(최대 4개).",
	},
	"stage6_wall": {
		"name": "테트로 벽", "trigger": "자동(30초)", "cooldown": "게이지 50",
		"description": "좌우 가장자리에 테트로 벽을 쌓아 압박합니다(셀 단위 파괴).",
	},
	"stage6_super": {
		"name": "초인테트리서", "trigger": "게이지 500", "cooldown": "발동 중 드레인",
		"description": "초인 변신: 본체가 커지고 테트로가 거대·공 면역이 되며 큐브로 광선을 쏩니다.",
	},
}

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
	if not bool(context.get("stage6_boss_skill_hud_active", false)):
		return {}
	var skills: Array = _get_array(context.get("stage6_boss_skill_hud_skills", []))
	var entries: Array = []
	for value in skills:
		if value is Dictionary:
			entries.append(value)
	if entries.is_empty():
		return {}

	var view_size: Vector2 = _as_vector2(context.get("view_size", Vector2.ZERO))
	var game_offset: Vector2 = _as_vector2(context.get("game_offset", Vector2.ZERO))
	var game_size: Vector2 = _as_vector2(context.get("game_size", Vector2.ZERO))
	if view_size.x <= 0.0 or game_offset.x <= 0.0 or game_size.y <= 0.0:
		return {}

	entries.sort_custom(Callable(self, "_sort_entries"))

	var pillar_w: float = maxf(0.0, game_offset.x)
	var metrics: Dictionary = BossSkillCardHudSpec.get_card_metrics(pillar_w)
	var scale_factor: float = float(metrics.get("scale_factor", 1.0))
	var card_size: Vector2 = _as_vector2(metrics.get("card_size", Vector2(34.0, 10.0)))
	var card_gap: float = float(metrics.get("card_gap", 2.0))
	var margin_x: float = float(metrics.get("margin_x", 3.0))
	var margin_y: float = float(metrics.get("margin_y", 5.0))
	var total_h: float = float(entries.size()) * (card_size.y + card_gap) - card_gap
	var card_x: float = maxf(1.0, pillar_w - card_size.x - margin_x)
	# Stage 6 carries the most cards (4 boss skills + hatched lingpet = 5), so the
	# centered stack overlapped the Commando firearm HUD. Shift the stack above the
	# firearm panel exactly like Stages 1-5 (this renderer was the only stage rail
	# that never read the panel rect / passed avoid_rect to the shared layout).
	var avoid_rect: Rect2 = _as_rect2(context.get("commando_firearm_panel_rect", Rect2()))
	var start_y: float = BossSkillCardHudSpec.resolve_stack_start_y(
		game_offset, game_size.y, total_h, margin_y, card_x, card_size.x, scale_factor, avoid_rect
	)
	var rects: Array = []
	for idx in range(entries.size()):
		rects.append(Rect2(Vector2(card_x, start_y + float(idx) * (card_size.y + card_gap)), card_size))
	return {"entries": entries, "rects": rects, "scale_factor": scale_factor}


func draw(canvas: CanvasItem, context: Dictionary) -> void:
	if canvas == null or int(context.get("current_stage", 1)) != 6:
		return
	var layout: Dictionary = build_card_layout(context)
	if layout.is_empty():
		return
	var entries: Array = _get_array(layout.get("entries", []))
	var rects: Array = _get_array(layout.get("rects", []))
	if entries.is_empty() or rects.size() < entries.size():
		return
	var scale_factor: float = float(layout.get("scale_factor", 1.0))
	var view_size: Vector2 = _as_vector2(context.get("view_size", Vector2.ZERO))
	var pillar_w: float = maxf(0.0, _as_vector2(context.get("game_offset", Vector2.ZERO)).x)
	var time_seconds: float = float(context.get("time_seconds", Time.get_ticks_msec() / 1000.0))
	var mouse_pos: Vector2 = BossSkillCardHudSpec.get_mouse_position(canvas)
	var hovered: Dictionary = {}
	var hovered_rect := Rect2()

	for idx in range(entries.size()):
		var entry: Dictionary = entries[idx]
		var target_rect: Rect2 = _as_rect2(rects[idx])
		var key: String = str(entry.get("id", "stage6_skill_%d" % idx))
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
			else _get_array_safe_dict(TOOLTIP_INFO.get(str(hovered.get("id", "")), {}))
		)
		BossSkillCardHudSpec.draw_skill_tooltip(
			canvas, hovered, hovered_rect, view_size, pillar_w,
			tooltip_info, scale_factor
		)


func get_asset_status() -> Dictionary:
	return {
		"tetro_drop_card_texture": _get_skill_texture("stage6_tetro_drop") != null,
		"guard_block_card_texture": _get_skill_texture("stage6_guard") != null,
		"tetro_wall_card_texture": _get_skill_texture("stage6_wall") != null,
		"super_tetriser_card_texture": _get_skill_texture("stage6_super") != null,
	}


func _draw_card(canvas: CanvasItem, rect: Rect2, skill: Dictionary, scale_factor: float, time_seconds: float) -> void:
	# The hatched lingpet rides this rail too. Delegate its card to the shared
	# helper so it shows its own skill-card art, status, and left-to-right cooldown
	# wipe exactly like Stages 1-5 (Stage 6's id->texture map only knows boss skills).
	if LingpetRailCard.is_lingpet_skill(skill):
		LingpetRailCard.draw_card(canvas, rect, skill, scale_factor, time_seconds)
		return
	var status: String = str(skill.get("status", "charging"))
	var ready: bool = bool(skill.get("ready", false)) or status == "ready"
	var active: bool = bool(skill.get("active", false)) or status == "casting"
	var progress: float = clampf(float(skill.get("progress", 0.0)), 0.0, 1.0)
	var color: Color = _as_color(skill.get("color", Color(0.6, 0.7, 1.0)))
	var fill_ratio: float = 1.0 if active or ready else progress
	var skill_id: String = str(skill.get("id", ""))
	var skill_texture: Texture2D = _get_skill_texture(skill_id)
	var has_texture: bool = skill_texture != null

	_draw_skillcard_gauge(canvas, rect, skill_texture, fill_ratio, color)
	if active:
		var active_pulse: float = 0.55 + 0.45 * sin(time_seconds * 7.0)
		canvas.draw_rect(rect, Color(1.0, 0.42, 0.14, 0.14 + active_pulse * 0.14))
	elif ready:
		var ready_pulse: float = 0.5 + 0.5 * sin(time_seconds * 3.1)
		canvas.draw_rect(rect.grow(1.0 * scale_factor), Color(color.r, color.g, color.b, 0.08 + ready_pulse * 0.10), false, maxf(1.0, round(1.3 * scale_factor)))
	elif fill_ratio > 0.0 and fill_ratio < 1.0:
		var edge_x: float = rect.position.x + rect.size.x * fill_ratio
		canvas.draw_line(Vector2(edge_x, rect.position.y + 1.0), Vector2(edge_x, rect.end.y - 1.0), Color(1.0, 0.9, 0.5, 0.5), 1.0, true)

	var border: Color = CHARGING_BORDER
	if active:
		border = ACTIVE_BORDER
	elif ready:
		border = READY_BORDER
	elif status == "paused":
		border = PAUSED_BORDER
	canvas.draw_rect(rect, border, false, maxf(1.0, round((1.5 if (active or ready) else 1.0) * scale_factor)))

	var side_w: float = maxf(1.0, round(SIDE_STRIP_BASE * scale_factor))
	canvas.draw_rect(Rect2(rect.position, Vector2(side_w, rect.size.y)), Color(color.r, color.g, color.b, 0.85))
	BossSkillCardHudSpec.draw_trigger_marker(canvas, skill, rect, scale_factor)

	var font: Font = ThemeDB.fallback_font
	if font != null and not has_texture:
		var label: String = str(skill.get("name", ""))
		var font_size: int = max(8, int(round(8.0 * scale_factor)))
		var text_pos := Vector2(rect.position.x + side_w + 3.0, rect.get_center().y + float(font_size) * 0.35)
		canvas.draw_string(font, text_pos + Vector2(1.0, 1.0), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - side_w - 6.0, font_size, Color(0.0, 0.0, 0.0, 0.7))
		canvas.draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - side_w - 6.0, font_size, Color(0.96, 0.97, 1.0, 1.0))


func _draw_skillcard_gauge(canvas: CanvasItem, rect: Rect2, texture: Texture2D, fill_ratio: float, fallback_color: Color) -> void:
	var clamped_fill: float = clampf(fill_ratio, 0.0, 1.0)
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


func _get_skill_texture(skill_id: String) -> Texture2D:
	var path: String = _get_skill_texture_path(skill_id)
	if path == "":
		return null
	if not _textures.has(path):
		_textures[path] = ProjectResourceLoader.load_texture(path)
	if _textures[path] is Texture2D:
		return _textures[path]
	return null


func _get_skill_texture_path(skill_id: String) -> String:
	if skill_id == "stage6_tetro_drop":
		return Stage6TetriserBossSkillHudAssets.TETRO_DROP_SKILLCARD_TEXTURE_PATH
	if skill_id == "stage6_guard":
		return Stage6TetriserBossSkillHudAssets.GUARD_BLOCK_SKILLCARD_TEXTURE_PATH
	if skill_id == "stage6_wall":
		return Stage6TetriserBossSkillHudAssets.TETRO_WALL_SKILLCARD_TEXTURE_PATH
	if skill_id == "stage6_super":
		return Stage6TetriserBossSkillHudAssets.SUPER_TETRISER_SKILLCARD_TEXTURE_PATH
	return ""


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


func _get_array_safe_dict(value: Variant) -> Dictionary:
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
