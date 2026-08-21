extends RefCounted

const Stage1PillarHudSceneDrawer := preload("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")

var hud_scene_drawer: Object = Stage1PillarHudSceneDrawer.new()


func draw(canvas: CanvasItem, context: Dictionary, registry: Object, states: Dictionary) -> void:
	if canvas == null or registry == null:
		return
	var view_size: Vector2 = _get_vector2(context, "view_size", Vector2.ZERO)
	var game_offset: Vector2 = _get_vector2(context, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(context, "game_size", Vector2.ZERO)
	var width: float = float(context.get("width", 760.0))
	var height: float = float(context.get("height", 750.0))
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0

	var stage_background: Object = states.get("stage_background", null)
	if stage_background == null:
		stage_background = registry.get_instance("stage4_pillar_background")
	var drew_background := false
	if stage_background != null and stage_background.has_method("draw"):
		drew_background = bool(stage_background.draw(canvas, view_size, game_offset, game_size, width))
	if not drew_background:
		var fallback_renderer: Object = registry.get_instance("stage1_fallback_pillar_renderer")
		if fallback_renderer != null and fallback_renderer.has_method("draw"):
			fallback_renderer.draw(canvas, view_size, game_offset, game_size, height, time_seconds)

	hud_scene_drawer.draw(canvas, context, registry, states, view_size, game_offset, game_size, time_seconds)


func draw_pillar_hud_overlay(canvas: CanvasItem, context: Dictionary, registry: Object, states: Dictionary) -> void:
	if canvas == null or registry == null:
		return
	var view_size: Vector2 = _get_vector2(context, "view_size", Vector2.ZERO)
	var game_offset: Vector2 = _get_vector2(context, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(context, "game_size", Vector2.ZERO)
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	hud_scene_drawer.draw(canvas, context, registry, states, view_size, game_offset, game_size, time_seconds)


func draw_post_playfield_hud(canvas: CanvasItem, context: Dictionary, registry: Object) -> void:
	if canvas == null or registry == null:
		return
	var perf_logger: Object = context.get("battle_perf_logger", null)
	var view_size: Vector2 = _get_vector2(context, "view_size", Vector2.ZERO)
	var game_offset: Vector2 = _get_vector2(context, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(context, "game_size", Vector2.ZERO)
	var sample_start: int = _perf_begin(perf_logger)
	hud_scene_drawer.draw_active_item_hud(canvas, context, registry, view_size, game_offset, game_size)
	_perf_end(perf_logger, "stage4.pillar.post_active_hud", sample_start)
	if bool(context.get("suppress_boss_skill_hud", false)):
		return
	sample_start = _perf_begin(perf_logger)
	var drew_ponk_boss_hud := _draw_stage4_ponk_boss_skill_hud(canvas, context, registry, view_size, game_offset, game_size)
	_perf_end(perf_logger, "stage4.pillar.ponk_boss_hud", sample_start)
	if not drew_ponk_boss_hud:
		sample_start = _perf_begin(perf_logger)
		_draw_stage4_ponk_gauge(canvas, context, registry, view_size, game_offset, game_size)
		_perf_end(perf_logger, "stage4.pillar.ponk_gauge_hud", sample_start)


func _draw_stage4_ponk_boss_skill_hud(
	canvas: CanvasItem,
	context: Dictionary,
	registry: Object,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2
) -> bool:
	var renderer: Object = registry.get_instance("stage4_ponk_boss_skill_hud_renderer")
	if renderer == null or not renderer.has_method("draw"):
		return false
	var ponk_skill_state: Object = registry.get_instance("stage4_ponk_skill_state")
	if ponk_skill_state == null or not ponk_skill_state.has_method("get_skill_card_hud_context"):
		return false
	var hud_context: Dictionary = context.duplicate(true)
	hud_context.merge(ponk_skill_state.get_skill_card_hud_context(null, context), true)
	hud_context["view_size"] = view_size
	hud_context["game_offset"] = game_offset
	hud_context["game_size"] = game_size
	# Hatched lingpet rides this stage's boss skill rail too (companion persists across stages).
	LingpetRailCard.append_entry(hud_context, registry, "stage4_ponk_boss_skill_hud_skills", "stage4_ponk_boss_skill_hud_active")
	renderer.draw(canvas, hud_context)
	return true


func _draw_stage4_ponk_gauge(
	canvas: CanvasItem,
	context: Dictionary,
	registry: Object,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2
) -> void:
	var renderer: Object = registry.get_instance("stage4_ponk_gauge_hud_renderer")
	if renderer == null or not renderer.has_method("draw"):
		return
	var hud_context: Dictionary = context.duplicate(true)
	var map_state: Object = registry.get_instance("stage4_map_state")
	if map_state != null and map_state.has_method("get_hud_context"):
		hud_context.merge(map_state.get_hud_context({
			"stage4_temple_destruction_event": registry.get_instance("stage4_temple_destruction_event"),
			"stage4_ponk_skill_state": registry.get_instance("stage4_ponk_skill_state"),
		}), true)
	hud_context["view_size"] = view_size
	hud_context["game_offset"] = game_offset
	hud_context["game_size"] = game_size
	renderer.draw(canvas, hud_context)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
