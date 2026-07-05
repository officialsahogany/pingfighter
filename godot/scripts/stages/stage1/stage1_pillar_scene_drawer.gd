extends RefCounted

const Stage1PillarHudSceneDrawer := preload("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")

# Stage 1 uses the shared pillar HUD directly. Match later-stage behavior by
# trimming ornamental orb layers during capped-frame and high-refresh LOD windows.
const STAGE1_STATIC_HUD_LOD_SCALE := BattleRenderQuality.FPS_CAP_EFFECT_SCALE

var hud_scene_drawer: Object = Stage1PillarHudSceneDrawer.new()
var _prewarm_step_index := 0
var _prewarm_finished_for := ""


func prewarm_assets(
	module_getter: Callable,
	selected_character_type: String = "smasher",
	stage1_boss_variant: String = "dalji"
) -> void:
	while not prewarm_assets_step(module_getter, selected_character_type, stage1_boss_variant):
		pass


func prewarm_assets_step(
	module_getter: Callable,
	selected_character_type: String = "smasher",
	stage1_boss_variant: String = "dalji"
) -> bool:
	var normalized_stage1_boss_variant: String = _normalize_stage1_boss_variant(stage1_boss_variant)
	var prewarm_key := "%s:%s" % [selected_character_type, normalized_stage1_boss_variant]
	if _prewarm_finished_for == prewarm_key:
		return true
	if _prewarm_step_index == 0:
		if hud_scene_drawer != null and hud_scene_drawer.has_method("prewarm_assets_step"):
			if not bool(hud_scene_drawer.prewarm_assets_step(module_getter, selected_character_type, normalized_stage1_boss_variant)):
				return false
		elif hud_scene_drawer != null and hud_scene_drawer.has_method("prewarm_assets"):
			hud_scene_drawer.prewarm_assets(module_getter, selected_character_type, normalized_stage1_boss_variant)
		_prewarm_step_index = 1
		return false
	if _prewarm_step_index == 1:
		_get_module(module_getter, "stage1_fallback_pillar_renderer")
	_prewarm_finished_for = prewarm_key
	_prewarm_step_index = 0
	return true


func reset_prewarm_cache() -> void:
	_prewarm_step_index = 0
	_prewarm_finished_for = ""
	if hud_scene_drawer != null and hud_scene_drawer.has_method("reset_prewarm_cache"):
		hud_scene_drawer.reset_prewarm_cache()


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
	var director_snapshot: Dictionary = _build_stage1_crescendo_snapshot(registry)
	var sample_start: int = _perf_begin(perf_logger)
	if stage_background != null:
		drew_layered_background = stage_background.draw(canvas, view_size, game_offset, game_size, width, perf_logger, quality_scale, director_snapshot)
	if not drew_layered_background:
		var fallback_renderer = registry.get_instance("stage1_fallback_pillar_renderer")
		if fallback_renderer != null:
			fallback_renderer.draw(canvas, view_size, game_offset, game_size, height, time_seconds)
	_perf_end(perf_logger, "stage1.pillar.background", sample_start)

	sample_start = _perf_begin(perf_logger)
	hud_scene_drawer.draw(
		canvas,
		_with_stage1_hud_lod_context(context, quality_scale),
		registry,
		states,
		view_size,
		game_offset,
		game_size,
		time_seconds
	)
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
	hud_scene_drawer.draw(
		canvas,
		_with_stage1_hud_lod_context(context, _get_pillar_quality_scale(context)),
		registry,
		states,
		view_size,
		game_offset,
		game_size,
		time_seconds
	)
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
	var director_snapshot: Dictionary = _build_stage1_crescendo_snapshot(registry)
	var stage_background = states.get("stage_background", null)
	if stage_background != null and stage_background.has_method("draw_pillar_background_overlay"):
		stage_background.draw_pillar_background_overlay(canvas, view_size, game_offset, game_size, width, perf_logger, quality_scale, director_snapshot)
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


func _with_stage1_hud_lod_context(context: Dictionary, quality_scale: float) -> Dictionary:
	var high_refresh_lod_active := BattleRenderQuality.is_high_refresh_lod_active()
	if quality_scale > STAGE1_STATIC_HUD_LOD_SCALE and not high_refresh_lod_active:
		return context
	var hud_context: Dictionary = context.duplicate()
	hud_context["stage1_pillar_hud_static_lod"] = true
	hud_context["pillar_hud_static_lod"] = true
	return hud_context


func _normalize_stage1_boss_variant(value: Variant) -> String:
	var variant: String = str(value).strip_edges().to_lower()
	if variant in ["gaksi", "gaksital", "talkwangdae", "talchum"]:
		return "gaksi"
	if variant in ["podo", "pododaejang", "podo_daejang"]:
		return "podo"
	return "dalji"


func _build_stage1_crescendo_snapshot(registry: Object) -> Dictionary:
	var ball_intensity: Object = _get_registry_instance(registry, "ball_intensity")
	if ball_intensity == null:
		return {}
	return {
		"display_intensity": _get_display_intensity(ball_intensity),
		"rally_tier": _get_rally_tier(ball_intensity),
	}


func _get_display_intensity(ball_intensity: Object) -> float:
	if ball_intensity != null and ball_intensity.has_method("get_display_intensity"):
		return clampf(float(ball_intensity.get_display_intensity()), 0.0, 1.0)
	return 0.0


func _get_rally_tier(ball_intensity: Object) -> int:
	if ball_intensity != null and ball_intensity.has_method("get_rally_tier"):
		return clampi(int(ball_intensity.get_rally_tier()), 0, 5)
	return 0


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


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
