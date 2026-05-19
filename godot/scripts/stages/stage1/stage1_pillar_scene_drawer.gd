extends RefCounted

const Stage1PillarHudSceneDrawer := preload("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")

var hud_scene_drawer: Object = Stage1PillarHudSceneDrawer.new()


func prewarm_assets(module_getter: Callable, selected_character_type: String = "smasher") -> void:
	if hud_scene_drawer != null and hud_scene_drawer.has_method("prewarm_assets"):
		hud_scene_drawer.prewarm_assets(module_getter, selected_character_type)
	_get_module(module_getter, "stage1_fallback_pillar_renderer")


func draw(canvas: CanvasItem, context: Dictionary, registry, states: Dictionary) -> void:
	if canvas == null or registry == null:
		return

	var perf_logger: Object = context.get("battle_perf_logger", null)
	var total_start: int = _perf_begin(perf_logger)
	var view_size: Vector2 = _get_vector2(context, "view_size", Vector2.ZERO)
	var game_offset: Vector2 = _get_vector2(context, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(context, "game_size", Vector2.ZERO)
	var width: float = float(context.get("width", 760.0))
	var height: float = float(context.get("height", 750.0))
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var quality_scale: float = _get_pillar_quality_scale(context)

	var stage_background = states.get("stage_background", null)
	var drew_layered_background := false
	var sample_start: int = _perf_begin(perf_logger)
	if stage_background != null:
		drew_layered_background = stage_background.draw(canvas, view_size, game_offset, game_size, width, perf_logger, quality_scale)
	if not drew_layered_background:
		var fallback_renderer = registry.get_instance("stage1_fallback_pillar_renderer")
		if fallback_renderer != null:
			fallback_renderer.draw(canvas, view_size, game_offset, game_size, height, time_seconds)
	_perf_end(perf_logger, "stage1.pillar.background", sample_start)

	sample_start = _perf_begin(perf_logger)
	hud_scene_drawer.draw(canvas, context, registry, states, view_size, game_offset, game_size, time_seconds)
	_perf_end(perf_logger, "stage1.pillar.hud_scene", sample_start)
	_perf_end(perf_logger, "stage1.pillar.total", total_start)


func draw_pillar_hud_overlay(canvas: CanvasItem, context: Dictionary, registry, states: Dictionary) -> void:
	if canvas == null or registry == null:
		return

	var perf_logger: Object = context.get("battle_perf_logger", null)
	var sample_start: int = _perf_begin(perf_logger)
	var view_size: Vector2 = _get_vector2(context, "view_size", Vector2.ZERO)
	var game_offset: Vector2 = _get_vector2(context, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(context, "game_size", Vector2.ZERO)
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	hud_scene_drawer.draw(canvas, context, registry, states, view_size, game_offset, game_size, time_seconds)
	_perf_end(perf_logger, "stage1.pillar.hud_overlay_scene", sample_start)


func draw_pillar_background_overlay(canvas: CanvasItem, context: Dictionary, registry, states: Dictionary) -> void:
	if canvas == null or registry == null:
		return
	var perf_logger: Object = context.get("battle_perf_logger", null)
	var sample_start: int = _perf_begin(perf_logger)
	var view_size: Vector2 = _get_vector2(context, "view_size", Vector2.ZERO)
	var game_offset: Vector2 = _get_vector2(context, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(context, "game_size", Vector2.ZERO)
	var width: float = float(context.get("width", 760.0))
	var quality_scale: float = _get_pillar_quality_scale(context)
	var stage_background = states.get("stage_background", null)
	if stage_background != null and stage_background.has_method("draw_pillar_background_overlay"):
		stage_background.draw_pillar_background_overlay(canvas, view_size, game_offset, game_size, width, perf_logger, quality_scale)
	_perf_end(perf_logger, "stage1.pillar.background_overlay", sample_start)


func draw_post_playfield_hud(canvas: CanvasItem, context: Dictionary, registry) -> void:
	if canvas == null or registry == null:
		return

	var perf_logger: Object = context.get("battle_perf_logger", null)
	var sample_start: int = _perf_begin(perf_logger)
	var view_size: Vector2 = _get_vector2(context, "view_size", Vector2.ZERO)
	var game_offset: Vector2 = _get_vector2(context, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(context, "game_size", Vector2.ZERO)
	hud_scene_drawer.draw_active_item_hud(canvas, context, registry, view_size, game_offset, game_size)
	_perf_end(perf_logger, "stage1.pillar.post_active_hud", sample_start)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_pillar_quality_scale(context: Dictionary) -> float:
	return BattleRenderQuality.effect_scale(context)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null
