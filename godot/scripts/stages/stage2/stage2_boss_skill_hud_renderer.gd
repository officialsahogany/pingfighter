extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const Stage2BossSkillHudAssets := preload("res://scripts/stages/stage2/stage2_boss_skill_hud_assets.gd")

const JUNGLE_QUAKE_SKILLCARD_TEXTURE_PATH := Stage2BossSkillHudAssets.JUNGLE_QUAKE_SKILLCARD_TEXTURE_PATH
const SPEED_DEFENSE_SKILLCARD_TEXTURE_PATH := Stage2BossSkillHudAssets.SPEED_DEFENSE_SKILLCARD_TEXTURE_PATH
const WATER_CANNON_SKILLCARD_TEXTURE_PATH := Stage2BossSkillHudAssets.WATER_CANNON_SKILLCARD_TEXTURE_PATH
const SKILLCARD_PREWARM_IDS := Stage2BossSkillHudAssets.SKILLCARD_PREWARM_IDS

var _skillcard_textures := {}
var _prewarm_done := false
var _prewarm_step_index := 0
var _metrics_cache_pillar_width := -1.0
var _metrics_cache: Dictionary = {}


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _prewarm_done:
		return true
	if _prewarm_step_index >= SKILLCARD_PREWARM_IDS.size():
		_prewarm_done = true
		_prewarm_step_index = 0
		return true
	_get_skillcard_texture(str(SKILLCARD_PREWARM_IDS[_prewarm_step_index]))
	_prewarm_step_index += 1
	if _prewarm_step_index >= SKILLCARD_PREWARM_IDS.size():
		_prewarm_done = true
		_prewarm_step_index = 0
		return true
	return false


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
	var font: Font = ThemeDB.fallback_font
	var card_rects: Array = []
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0

	for i in range(entries.size()):
		var skill: Dictionary = entries[i]
		var rect := Rect2(Vector2(card_x, start_y + float(i) * (card_h + card_gap)), Vector2(card_w, card_h))
		card_rects.append(rect)
		var card_sample_start: int = _perf_begin(perf_logger)
		if LingpetRailCard.is_lingpet_skill(skill):
			LingpetRailCard.draw_card(canvas, rect, skill, scale_factor, time_seconds)
			_perf_end(perf_logger, "stage2.rail.lingpet_card", card_sample_start)
		else:
			_draw_card(canvas, rect, skill, scale_factor, font)
			_perf_end(perf_logger, "stage2.rail.cards_draw", card_sample_start)

	var gauge_sample_start: int = _perf_begin(perf_logger)
	# Stage 2 still publishes gauge/speech context, but this compact rail does not draw it.
	_perf_end(perf_logger, "stage2.rail.gauge_speech", gauge_sample_start)

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
				"background_color": Color(0.035, 0.050, 0.060, 0.94),
				"inner_color": Color(0.07, 0.11, 0.13, 0.54),
			}
		)
	_perf_end(perf_logger, "stage2.rail.tooltip", tooltip_sample_start)


func _draw_card(canvas: CanvasItem, rect: Rect2, skill: Dictionary, scale_factor: float, font: Font) -> void:
	if LingpetRailCard.is_lingpet_skill(skill):
		LingpetRailCard.draw_card(canvas, rect, skill, scale_factor, Time.get_ticks_msec() / 1000.0)
		return
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
	var label: String = LanguageSettings.translate_text(str(skill.get("label", "")))
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
	# 종횡비 보존(cover) 게이지 draw는 공용 스펙으로 단일화(찌그러짐 방지).
	BossSkillCardHudSpec.draw_skillcard_gauge_fill(
		canvas,
		rect,
		skillcard,
		Rect2(Vector2.ZERO, skillcard.get_size()),
		clamped_fill,
		dim,
		Color(1.0, 1.0, 1.0, 1.0)
	)


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


func _get_tooltip_info(value: Variant) -> Dictionary:
	var skill: Dictionary = {}
	var skill_id := ""
	if value is Dictionary:
		skill = value as Dictionary
		skill_id = str(skill.get("id", ""))
	else:
		skill_id = str(value)
	if skill_id == "jungle_quake":
		return {
			"name": "정글지진",
			"trigger": "자동",
			"cooldown": "쿨타임 40초",
			"description": "바닥을 흔들어 바위와 충격을 일으킵니다. 압박 단계가 높을수록 낙석이 늘어납니다.",
		}
	if skill_id == "water_cannon":
		return {
			"name": "물대포",
			"trigger": "자동 / 바위 등장 후",
			"cooldown": "쿨타임 30초",
			"description": "물대포를 충전해 전장을 가로지르는 물줄기를 발사합니다.",
		}
	if skill_id == "speed_defense":
		return {
			"name": "스피드디펜스",
			"trigger": "자동",
			"cooldown": "쿨타임 25초",
			"description": "짧은 시간 동안 보스 이동과 반응이 빨라지고 상태 이상을 막습니다.",
		}
	if LingpetRailCard.is_lingpet_skill(skill) or skill_id == LingpetRailCard.SKILL_ID:
		return LingpetRailCard.tooltip_info(skill)
	return {}


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
