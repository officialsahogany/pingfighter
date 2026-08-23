extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const Stage3BossSkillHudAssets := preload("res://scripts/stages/stage3/stage3_boss_skill_hud_assets.gd")

const SKILLCARD_ATLAS_PATH := Stage3BossSkillHudAssets.SKILLCARD_ATLAS_PATH
const SKILLCARD_ID_TO_INDEX := Stage3BossSkillHudAssets.SKILLCARD_ID_TO_INDEX
const SKILLCARD_ATLAS_COLS := Stage3BossSkillHudAssets.SKILLCARD_ATLAS_COLS
const SKILLCARD_ATLAS_ROWS := Stage3BossSkillHudAssets.SKILLCARD_ATLAS_ROWS
const SKILLCARD_ATLAS_FRAMES := Stage3BossSkillHudAssets.SKILLCARD_ATLAS_FRAMES
const SKILLCARD_FRAME_SIZE := Stage3BossSkillHudAssets.SKILLCARD_FRAME_SIZE
const SKILLCARD_ATLAS_SIZE := Stage3BossSkillHudAssets.SKILLCARD_ATLAS_SIZE

var _skillcard_atlas: Texture2D = null
var _metrics_cache_pillar_width := -1.0
var _metrics_cache: Dictionary = {}


func prewarm_assets() -> void:
	_get_skillcard_atlas()


func get_debug_card_metrics(pillar_width: float) -> Dictionary:
	return BossSkillCardHudSpec.get_card_metrics(pillar_width)


func get_debug_skillcard_source_rect(texture_size: Vector2, skill_id: String) -> Rect2:
	if not SKILLCARD_ID_TO_INDEX.has(skill_id):
		return Rect2()
	if not texture_size.is_equal_approx(Vector2(SKILLCARD_ATLAS_SIZE)):
		return Rect2()
	var frame_index: int = int(SKILLCARD_ID_TO_INDEX[skill_id])
	if frame_index < 0 or frame_index >= SKILLCARD_ATLAS_FRAMES:
		return Rect2()
	var frame_col: int = frame_index % SKILLCARD_ATLAS_COLS
	var frame_row: int = floori(float(frame_index) / float(SKILLCARD_ATLAS_COLS))
	if frame_row < 0 or frame_row >= SKILLCARD_ATLAS_ROWS:
		return Rect2()
	return Rect2(
		Vector2(frame_col * SKILLCARD_FRAME_SIZE.x, frame_row * SKILLCARD_FRAME_SIZE.y),
		Vector2(SKILLCARD_FRAME_SIZE)
	)


func draw(canvas: CanvasItem, context: Dictionary) -> void:
	if canvas == null or int(context.get("current_stage", 1)) != 3:
		return
	if not bool(context.get("stage3_boss_skill_hud_active", false)):
		return
	var skills: Array = _get_array(context.get("stage3_boss_skill_hud_skills", []))
	if skills.is_empty():
		return
	var view_size: Vector2 = _as_vector2(context.get("view_size", Vector2.ZERO), Vector2.ZERO)
	var game_offset: Vector2 = _as_vector2(context.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var game_size: Vector2 = _as_vector2(context.get("game_size", Vector2.ZERO), Vector2.ZERO)
	if game_offset.x <= 0.0 or game_size.y <= 0.0:
		return
	var perf_logger: Object = context.get("battle_perf_logger", null)
	var entries := skills
	if entries.is_empty():
		return
	entries.sort_custom(Callable(self, "_sort_entries"))
	var pillar_w: float = max(0.0, game_offset.x)
	var metrics: Dictionary = _get_card_metrics(pillar_w)
	var scale_factor: float = float(metrics.get("scale_factor", 1.0))
	var card_size: Vector2 = _as_vector2(metrics.get("card_size", Vector2(34.0, 10.0)), Vector2(34.0, 10.0))
	var card_w: float = card_size.x
	var card_h: float = card_size.y
	var card_gap: float = float(metrics.get("card_gap", 2.0))
	var margin_x: float = float(metrics.get("margin_x", 3.0))
	var margin_y: float = float(metrics.get("margin_y", 5.0))
	var total_h: float = float(entries.size()) * (card_h + card_gap) - card_gap
	var card_x: float = max(1.0, pillar_w - card_w - margin_x)
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
	var card_rects: Array = []
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	for i in range(entries.size()):
		var skill: Dictionary = entries[i]
		var rect := Rect2(Vector2(card_x, start_y + float(i) * (card_h + card_gap)), Vector2(card_w, card_h))
		card_rects.append(rect)
		var card_sample_start: int = _perf_begin(perf_logger)
		if LingpetRailCard.is_lingpet_skill(skill):
			LingpetRailCard.draw_card(canvas, rect, skill, scale_factor, time_seconds)
			_perf_end(perf_logger, "stage3.rail.lingpet_card", card_sample_start)
		else:
			_draw_card(canvas, rect, skill, scale_factor)
			_perf_end(perf_logger, "stage3.rail.cards_draw", card_sample_start)

	var gauge_sample_start: int = _perf_begin(perf_logger)
	if bool(context.get("stage3_boss_skill_hud_show_boss_gauge", true)):
		_draw_wand_gauge(canvas, context, game_offset, scale_factor)
	_perf_end(perf_logger, "stage3.rail.gauge_speech", gauge_sample_start)

	var tooltip_sample_start: int = _perf_begin(perf_logger)
	var mouse_pos: Vector2 = BossSkillCardHudSpec.get_mouse_position(canvas)
	var hovered_skill: Dictionary = {}
	var hovered_rect := Rect2()
	for i in range(entries.size()):
		var tooltip_skill: Dictionary = entries[i]
		var rect: Rect2 = _as_rect2(card_rects[i], Rect2())
		if rect.has_point(mouse_pos):
			hovered_skill = tooltip_skill
			hovered_rect = rect
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
				"background_color": Color(0.055, 0.035, 0.060, 0.94),
				"inner_color": Color(0.13, 0.08, 0.13, 0.54),
			}
		)
	_perf_end(perf_logger, "stage3.rail.tooltip", tooltip_sample_start)


func _draw_card(canvas: CanvasItem, rect: Rect2, skill: Dictionary, scale_factor: float) -> void:
	if LingpetRailCard.is_lingpet_skill(skill):
		LingpetRailCard.draw_card(canvas, rect, skill, scale_factor, Time.get_ticks_msec() / 1000.0)
		return
	var status: String = str(skill.get("status", "charging"))
	var ready: bool = bool(skill.get("ready", false)) or status == "ready"
	var active: bool = status == "casting"
	var locked: bool = status == "locked"
	var progress: float = clamp(float(skill.get("progress", 0.0)), 0.0, 1.0)
	var skill_color: Color = _as_color(skill.get("color", Color(1.0, 0.38, 0.68, 1.0)), Color(1.0, 0.38, 0.68, 1.0))
	var fill_ratio: float = 1.0 if active or ready else progress
	if locked:
		fill_ratio = 0.0
	_draw_skillcard_gauge(canvas, rect, str(skill.get("id", "")), fill_ratio, skill_color)
	var shine_x: float = rect.position.x + rect.size.x * fill_ratio
	if fill_ratio > 0.0 and fill_ratio < 1.0:
		canvas.draw_line(Vector2(shine_x, rect.position.y + 1.0), Vector2(shine_x, rect.end.y - 1.0), Color(1.0, 0.82, 0.94, 0.58), 1.0)
	var border := Color(0.30, 0.20, 0.28, 0.72)
	if active:
		border = Color(1.0, 0.72, 0.92, 0.95)
	elif ready:
		border = Color(0.64, 1.0, 0.72, 0.84)
	elif locked:
		border = Color(0.36, 0.34, 0.38, 0.60)
	canvas.draw_rect(rect, border, false, max(1.0, round(scale_factor)))
	canvas.draw_rect(Rect2(rect.position + Vector2(0.0, 1.0), Vector2(max(1.0, 2.0 * scale_factor), rect.size.y - 2.0)), Color(1.0, 0.28, 0.58, 0.70))
	BossSkillCardHudSpec.draw_trigger_marker(canvas, skill, rect, scale_factor)


func _draw_skillcard_gauge(canvas: CanvasItem, rect: Rect2, skill_id: String, fill_ratio: float, fallback_color: Color) -> void:
	var clamped_fill: float = clamp(fill_ratio, 0.0, 1.0)
	var atlas: Texture2D = _get_skillcard_atlas()
	canvas.draw_rect(rect, Color(0.055, 0.035, 0.060, 0.94))
	var source_rect := Rect2()
	if atlas != null:
		source_rect = get_debug_skillcard_source_rect(atlas.get_size(), skill_id)
	if atlas == null or not source_rect.has_area():
		if clamped_fill > 0.0:
			canvas.draw_rect(
				Rect2(rect.position, Vector2(rect.size.x * clamped_fill, rect.size.y)),
				Color(fallback_color.r * 0.62, fallback_color.g * 0.55, fallback_color.b * 0.62, 0.78)
			)
		return
	# 종횡비 보존(cover) 게이지 draw는 공용 스펙으로 단일화(찌그러짐 방지).
	BossSkillCardHudSpec.draw_skillcard_gauge_fill(
		canvas,
		rect,
		atlas,
		source_rect,
		clamped_fill,
		Color(0.22, 0.20, 0.22, 1.0),
		Color(1.0, 0.96, 1.0, 1.0)
	)


func _draw_wand_gauge(canvas: CanvasItem, context: Dictionary, game_offset: Vector2, scale_factor: float) -> void:
	var gauge: float = clamp(float(context.get("stage3_boss_skill_hud_boss_gauge", 0.0)), 0.0, float(context.get("stage3_boss_skill_hud_boss_gauge_max", 500.0)))
	var gauge_max: float = max(1.0, float(context.get("stage3_boss_skill_hud_boss_gauge_max", 500.0)))
	var fill_ratio: float = clamp(gauge / gauge_max, 0.0, 1.0)
	var wand_x: float = game_offset.x + 760.0 * scale_factor - 48.0 * scale_factor
	var wand_y: float = game_offset.y + 30.0 * scale_factor
	var moon_r: float = 12.0 * scale_factor
	canvas.draw_circle(Vector2(wand_x, wand_y), moon_r + 2.0 * scale_factor, Color(1.0, 0.82, 0.12, 0.90))
	canvas.draw_circle(Vector2(wand_x, wand_y), moon_r, Color(1.0, 1.0, 0.80, 0.92))
	canvas.draw_circle(Vector2(wand_x + 5.0 * scale_factor, wand_y), moon_r - 2.0 * scale_factor, Color(0.16, 0.16, 0.12, 0.95))
	var gem_h: float = 60.0 * scale_factor
	var gem_w: float = 24.0 * scale_factor
	var gem_y: float = wand_y + 25.0 * scale_factor
	var gem := PackedVector2Array([
		Vector2(wand_x, gem_y),
		Vector2(wand_x + gem_w * 0.5, gem_y + gem_h / 3.0),
		Vector2(wand_x + gem_w * 0.5, gem_y + gem_h * 2.0 / 3.0),
		Vector2(wand_x, gem_y + gem_h),
		Vector2(wand_x - gem_w * 0.5, gem_y + gem_h * 2.0 / 3.0),
		Vector2(wand_x - gem_w * 0.5, gem_y + gem_h / 3.0),
	])
	canvas.draw_colored_polygon(gem, Color(0.06, 0.03, 0.08, 0.86))
	canvas.draw_polyline(gem, Color(1.0, 0.82, 0.16, 0.88), 2.0 * scale_factor, true)
	var fill_h: float = (gem_h - 6.0 * scale_factor) * fill_ratio
	if fill_h > 1.0:
		canvas.draw_rect(
			Rect2(Vector2(wand_x - gem_w * 0.34, gem_y + gem_h - 3.0 * scale_factor - fill_h), Vector2(gem_w * 0.68, fill_h)),
			Color(1.0, 0.32 + 0.40 * fill_ratio, 1.0, 0.76)
		)
	var ribbon_y: float = gem_y + gem_h + 5.0 * scale_factor
	canvas.draw_circle(Vector2(wand_x, ribbon_y + 4.0 * scale_factor), 5.0 * scale_factor, Color(1.0, 0.42, 0.72, 0.90))
	canvas.draw_rect(Rect2(Vector2(wand_x - 15.0 * scale_factor, ribbon_y), Vector2(30.0 * scale_factor, 8.0 * scale_factor)), Color(1.0, 0.08, 0.58, 0.72))


func _get_skillcard_atlas() -> Texture2D:
	if _skillcard_atlas != null:
		return _skillcard_atlas
	_skillcard_atlas = ProjectResourceLoader.load_texture(
		SKILLCARD_ATLAS_PATH,
		"[Stage3HwangyeokjeonSkillHud] missing skillcard atlas: %s",
		"[Stage3HwangyeokjeonSkillHud] failed to load skillcard atlas: %s"
	)
	return _skillcard_atlas


func _get_tooltip_info(value: Variant) -> Dictionary:
	var skill: Dictionary = {}
	var skill_id := ""
	if value is Dictionary:
		skill = value as Dictionary
		skill_id = str(skill.get("id", ""))
	else:
		skill_id = str(value)
	if skill_id == "tear_shower":
		return {
			"name": "눈물샤워",
			"trigger": "자동",
			"cooldown": "쿨타임 25초",
			"description": "전장 위로 눈물을 떨어뜨려 공을 둔화시키고 보스 쪽 압박을 만듭니다.",
		}
	if skill_id == "curse_chest":
		return {
			"name": "저주상자",
			"trigger": "자동",
			"cooldown": "쿨타임 35초",
			"description": "저주 상자를 던져 폭발과 연기를 남기고 공의 흐름을 어지럽힙니다.",
		}
	if skill_id == "psycho_ball":
		return {
			"name": "사이코볼",
			"trigger": "보스 타격",
			"cooldown": "쿨타임 70초",
			"description": "사이코볼 상태로 전장을 흔들며 공 충돌에 강한 히트스톱을 겁니다.",
		}
	if LingpetRailCard.is_lingpet_skill(skill) or skill_id == LingpetRailCard.SKILL_ID:
		return LingpetRailCard.tooltip_info(skill)
	return {}


func _get_card_metrics(pillar_width: float) -> Dictionary:
	if is_equal_approx(_metrics_cache_pillar_width, pillar_width) and not _metrics_cache.is_empty():
		return _metrics_cache
	_metrics_cache_pillar_width = pillar_width
	_metrics_cache = BossSkillCardHudSpec.get_card_metrics(pillar_width)
	return _metrics_cache


func _sort_entries(a: Dictionary, b: Dictionary) -> bool:
	return BossSkillCardHudSpec.compare_skill_entries_by_next_activation(a, b)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


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
