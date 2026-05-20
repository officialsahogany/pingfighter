extends RefCounted

const Stage1PillarHudSceneDrawer := preload("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")
const ViperAirborneLod := preload("res://scripts/core/viper_airborne_lod.gd")

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
	var perf_logger: Object = context.get("battle_perf_logger", null)
	var quality_scale: float = _get_pillar_quality_scale(context)

	var stage_background: Object = states.get("stage_background", null)
	if stage_background == null:
		stage_background = registry.get_instance("stage3_pillar_background")
	var drew_background: bool = false
	if stage_background != null and stage_background.has_method("draw"):
		var background_sample_start: int = _perf_begin(perf_logger)
		drew_background = bool(stage_background.draw(canvas, view_size, game_offset, game_size, width, context, quality_scale))
		_perf_end(perf_logger, "stage3.pillar.background", background_sample_start)
	if not drew_background:
		var fallback_renderer: Object = registry.get_instance("stage1_fallback_pillar_renderer")
		if fallback_renderer != null and fallback_renderer.has_method("draw"):
			var fallback_sample_start: int = _perf_begin(perf_logger)
			fallback_renderer.draw(canvas, view_size, game_offset, game_size, height, time_seconds)
			_perf_end(perf_logger, "stage3.pillar.fallback", fallback_sample_start)

	var hud_sample_start: int = _perf_begin(perf_logger)
	hud_scene_drawer.draw(canvas, context, registry, states, view_size, game_offset, game_size, time_seconds)
	_perf_end(perf_logger, "stage3.pillar.hud_scene", hud_sample_start)


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
	var view_size: Vector2 = _get_vector2(context, "view_size", Vector2.ZERO)
	var game_offset: Vector2 = _get_vector2(context, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(context, "game_size", Vector2.ZERO)
	hud_scene_drawer.draw_active_item_hud(canvas, context, registry, view_size, game_offset, game_size)
	_draw_stage3_boss_skill_hud(canvas, context, registry, view_size, game_offset, game_size)


func _draw_stage3_boss_skill_hud(
	canvas: CanvasItem,
	context: Dictionary,
	registry: Object,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2
) -> void:
	var renderer: Object = registry.get_instance("stage3_boss_skill_hud_renderer")
	if renderer == null or not renderer.has_method("draw"):
		return
	var skill_state: Object = registry.get_instance("stage3_boss_skill_state")
	if skill_state == null or not skill_state.has_method("get_hud_context"):
		return
	var hud_context: Dictionary = context.duplicate()
	hud_context.merge(skill_state.get_hud_context(null, context), true)
	hud_context["view_size"] = view_size
	hud_context["game_offset"] = game_offset
	hud_context["game_size"] = game_size
	renderer.draw(canvas, hud_context)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_pillar_quality_scale(context: Dictionary) -> float:
	return ViperAirborneLod.effect_scale(context)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
