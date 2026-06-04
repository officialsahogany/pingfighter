extends RefCounted

# Stage 6 Tetriser pillar scene drawer.
#
# Owns the Stage 6 atmospheric background fanout and reuses the common Stage 1
# pillar HUD drawer for scoreboard/orb/active-item chrome. The gameplay cube is
# rendered by stage6_tetriser_playfield_renderer, not by this background pass.

const Stage1PillarHudSceneDrawer := preload("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const Stage6PillarTetris := preload("res://scripts/stages/stage6/stage6_tetriser_pillar_tetris.gd")

const STAGE6_STATIC_HUD_LOD_SCALE := BattleRenderQuality.FPS_CAP_EFFECT_SCALE

var hud_scene_drawer: Object = Stage1PillarHudSceneDrawer.new()
var pillar_tetris: Object = Stage6PillarTetris.new()
var _prewarm_step_index := 0
var _prewarm_character_type := ""
var _prewarm_finished_for := ""


func prewarm_assets(module_getter: Callable, selected_character_type: String = "smasher") -> void:
	while not prewarm_assets_step(module_getter, selected_character_type):
		pass


func prewarm_assets_step(module_getter: Callable, selected_character_type: String = "smasher") -> bool:
	var character_type := str(selected_character_type)
	if _prewarm_finished_for == character_type:
		return true
	if _prewarm_character_type != character_type:
		_prewarm_character_type = character_type
		_prewarm_step_index = 0

	match _prewarm_step_index:
		0:
			var stage_background: Object = _get_module(module_getter, "stage6_tetriser_pillar_background")
			if stage_background != null and stage_background.has_method("prewarm_assets_step"):
				if not bool(stage_background.prewarm_assets_step()):
					return false
			elif stage_background != null and stage_background.has_method("prewarm_assets"):
				stage_background.prewarm_assets()
		1:
			if hud_scene_drawer != null and hud_scene_drawer.has_method("prewarm_assets_step"):
				if not bool(hud_scene_drawer.prewarm_assets_step(module_getter, character_type)):
					return false
			elif hud_scene_drawer != null and hud_scene_drawer.has_method("prewarm_assets"):
				hud_scene_drawer.prewarm_assets(module_getter, character_type)
		2:
			var skill_hud: Object = _get_module(module_getter, "stage6_tetriser_boss_skill_hud_renderer")
			if skill_hud != null and skill_hud.has_method("prewarm_assets_step"):
				if not bool(skill_hud.prewarm_assets_step()):
					return false
			elif skill_hud != null and skill_hud.has_method("prewarm_assets"):
				skill_hud.prewarm_assets()
		3:
			_get_module(module_getter, "stage1_fallback_pillar_renderer")
		_:
			_prewarm_finished_for = character_type
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	return false


func draw(canvas: CanvasItem, context: Dictionary, registry: Object, states: Dictionary) -> void:
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

	var stage_background: Object = states.get("stage_background", null)
	var sample_start: int = _perf_begin(perf_logger)
	var drew_layered_background := false
	if stage_background != null:
		drew_layered_background = _draw_stage_background(canvas, stage_background, view_size, game_offset, game_size, width, perf_logger, quality_scale)
	if not drew_layered_background:
		var fallback_renderer: Object = registry.get_instance("stage1_fallback_pillar_renderer")
		if fallback_renderer != null and fallback_renderer.has_method("draw"):
			fallback_renderer.draw(canvas, view_size, game_offset, game_size, height, time_seconds)
	_perf_end(perf_logger, "stage6.pillar.background", sample_start)

	# Self-playing Tetris wells in the letterbox margins (backdrop behind the HUD).
	sample_start = _perf_begin(perf_logger)
	if pillar_tetris != null and pillar_tetris.has_method("draw"):
		pillar_tetris.draw(canvas, view_size, game_offset, game_size, quality_scale)
	_perf_end(perf_logger, "stage6.pillar.tetris", sample_start)

	sample_start = _perf_begin(perf_logger)
	hud_scene_drawer.draw(
		canvas,
		_with_stage6_hud_lod_context(context, quality_scale),
		registry,
		states,
		view_size,
		game_offset,
		game_size,
		time_seconds
	)
	_perf_end(perf_logger, "stage6.pillar.hud_scene", sample_start)
	_perf_end(perf_logger, "stage6.pillar.total", total_start)


func draw_pillar_hud_overlay(canvas: CanvasItem, context: Dictionary, registry: Object, states: Dictionary) -> void:
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
		_with_stage6_hud_lod_context(context, _get_pillar_quality_scale(context)),
		registry,
		states,
		view_size,
		game_offset,
		game_size,
		time_seconds
	)
	_perf_end(perf_logger, "stage6.pillar.hud_overlay_scene", sample_start)


func draw_pillar_background_overlay(canvas: CanvasItem, context: Dictionary, _registry: Object, states: Dictionary) -> void:
	if canvas == null:
		return
	var perf_logger: Object = context.get("battle_perf_logger", null)
	var sample_start: int = _perf_begin(perf_logger)
	var view_size: Vector2 = _get_vector2(context, "view_size", Vector2.ZERO)
	var game_offset: Vector2 = _get_vector2(context, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(context, "game_size", Vector2.ZERO)
	var width: float = float(context.get("width", 760.0))
	var quality_scale: float = _get_pillar_quality_scale(context)
	var stage_background: Object = states.get("stage_background", null)
	if stage_background != null and stage_background.has_method("draw_pillar_background_overlay"):
		stage_background.draw_pillar_background_overlay(canvas, view_size, game_offset, game_size, width, perf_logger, quality_scale)
	_perf_end(perf_logger, "stage6.pillar.background_overlay", sample_start)


func draw_post_playfield_hud(canvas: CanvasItem, context: Dictionary, registry: Object) -> void:
	if canvas == null or registry == null:
		return

	var perf_logger: Object = context.get("battle_perf_logger", null)
	var sample_start: int = _perf_begin(perf_logger)
	var view_size: Vector2 = _get_vector2(context, "view_size", Vector2.ZERO)
	var game_offset: Vector2 = _get_vector2(context, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(context, "game_size", Vector2.ZERO)
	hud_scene_drawer.draw_active_item_hud(canvas, context, registry, view_size, game_offset, game_size)
	_perf_end(perf_logger, "stage6.pillar.post_active_hud", sample_start)

	sample_start = _perf_begin(perf_logger)
	_draw_stage6_tetriser_boss_skill_hud(canvas, context, registry, view_size, game_offset, game_size)
	_perf_end(perf_logger, "stage6.pillar.tetriser_boss_hud", sample_start)


func get_asset_status() -> Dictionary:
	return {
		"uses_stage_background": true,
		"uses_common_pillar_hud": hud_scene_drawer != null,
	}


func _draw_stage6_tetriser_boss_skill_hud(
	canvas: CanvasItem,
	context: Dictionary,
	registry: Object,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2
) -> void:
	var renderer: Object = _get_stage6_boss_skill_renderer(registry)
	if renderer == null or not renderer.has_method("draw"):
		return
	var state: Object = registry.get_instance("stage6_tetriser_state")
	if state == null or not state.has_method("get_hud_context"):
		return
	var hud_context: Dictionary = context.duplicate(true)
	hud_context.merge(state.get_hud_context(null, context), true)
	hud_context["current_stage"] = 6
	hud_context["view_size"] = view_size
	hud_context["game_offset"] = game_offset
	hud_context["game_size"] = game_size
	hud_context["time_seconds"] = float(Time.get_ticks_msec()) / 1000.0
	renderer.draw(canvas, hud_context)


func _get_stage6_boss_skill_renderer(registry: Object) -> Object:
	var renderer_key := "stage6_tetriser_boss_skill_hud_renderer"
	var router: Object = registry.get_instance("stage_runtime_router")
	if router != null and router.has_method("get_module_key"):
		var routed_key: String = str(router.get_module_key(6, "boss_skill_hud_renderer"))
		if routed_key != "":
			renderer_key = routed_key
	return registry.get_instance(renderer_key)


func _draw_stage_background(
	canvas: CanvasItem,
	stage_background: Object,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	width: float,
	perf_logger: Object,
	quality_scale: float
) -> bool:
	if not stage_background.has_method("draw"):
		return false
	var arg_count: int = _get_method_argument_count(stage_background, "draw")
	if arg_count >= 7:
		return bool(stage_background.draw(canvas, view_size, game_offset, game_size, width, perf_logger, quality_scale))
	if arg_count >= 6:
		return bool(stage_background.draw(canvas, view_size, game_offset, game_size, width, perf_logger))
	return bool(stage_background.draw(canvas, view_size, game_offset, game_size, width))


func _get_method_argument_count(target: Object, method_name: String) -> int:
	if target == null:
		return 0
	for method_info in target.get_method_list():
		if str(method_info.get("name", "")) == method_name:
			var args: Variant = method_info.get("args", [])
			return args.size() if args is Array else 0
	return 0


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_pillar_quality_scale(context: Dictionary) -> float:
	return BattleRenderQuality.effect_scale(context)


func _with_stage6_hud_lod_context(context: Dictionary, quality_scale: float) -> Dictionary:
	if quality_scale > STAGE6_STATIC_HUD_LOD_SCALE and not BattleRenderQuality.is_high_refresh_lod_active():
		return context
	var hud_context: Dictionary = context.duplicate()
	hud_context["pillar_hud_static_lod"] = true
	hud_context["stage6_pillar_hud_static_lod"] = true
	return hud_context


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
