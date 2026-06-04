extends RefCounted

const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const Stage1PillarHudSceneDrawer := preload("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const BLOCKING_OVERLAY_LOD_METHODS := [
	"is_runtime_perk_choice_active",
	"is_runtime_perk_feedback_active",
	"is_character_debug_picker_open",
	"is_perk_debug_picker_open",
	"is_stage_debug_picker_open",
	"is_weather_debug_picker_open",
	"is_mythic_management_menu_open",
	"is_pandora_legacy_selection_active",
	"is_character_info_active",
	"is_pause_menu_active",
	"is_active_item_debug_spawn_menu_open",
]
# Stage 2 reuses the Stage 1 pillar HUD. Trim ornamental orb layers during
# the same 72 FPS-cap / Viper glide windows that trigger global render LOD.
const STAGE2_STATIC_HUD_LOD_SCALE := BattleRenderQuality.FPS_CAP_EFFECT_SCALE

var hud_scene_drawer: Object = Stage1PillarHudSceneDrawer.new()
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
			if hud_scene_drawer != null and hud_scene_drawer.has_method("prewarm_assets_step"):
				if not bool(hud_scene_drawer.prewarm_assets_step(module_getter, character_type)):
					return false
			elif hud_scene_drawer != null and hud_scene_drawer.has_method("prewarm_assets"):
				hud_scene_drawer.prewarm_assets(module_getter, character_type)
		_:
			_prewarm_finished_for = character_type
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	return false


func draw(canvas: CanvasItem, context: Dictionary, registry, states: Dictionary) -> void:
	if canvas == null or registry == null:
		return
	var perf_logger: Object = context.get("battle_perf_logger", null)
	var view_size: Vector2 = _get_vector2(context, "view_size", Vector2.ZERO)
	var game_offset: Vector2 = _get_vector2(context, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(context, "game_size", Vector2.ZERO)
	var width: float = float(context.get("width", 760.0))
	var _height: float = float(context.get("height", 750.0))
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var quality_scale: float = BattleRenderQuality.effect_scale(context)

	var stage_background = states.get("stage_background", null)
	if stage_background == null:
		stage_background = registry.get_instance("stage2_pillar_background")
	var sample_start: int = _perf_begin(perf_logger)
	if stage_background != null and stage_background.has_method("draw"):
		stage_background.draw(canvas, view_size, game_offset, game_size, width, quality_scale)
	_perf_end(perf_logger, "stage2.pillar.background", sample_start)
	var monkey_event: Object = registry.get_instance("stage2_monkey_banana_event")
	sample_start = _perf_begin(perf_logger)
	if monkey_event != null and monkey_event.has_method("draw_pillar"):
		monkey_event.draw_pillar(canvas, context)
	_perf_end(perf_logger, "stage2.pillar.monkey", sample_start)

	sample_start = _perf_begin(perf_logger)
	_draw_stage2_shared_pillar_hud(
		canvas,
		context,
		registry,
		states,
		view_size,
		game_offset,
		game_size,
		time_seconds,
		quality_scale
	)
	_perf_end(perf_logger, "stage2.pillar.hud", sample_start)


func draw_pillar_hud_overlay(canvas: CanvasItem, context: Dictionary, registry, states: Dictionary) -> void:
	if canvas == null or registry == null:
		return
	var view_size: Vector2 = _get_vector2(context, "view_size", Vector2.ZERO)
	var game_offset: Vector2 = _get_vector2(context, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(context, "game_size", Vector2.ZERO)
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	_draw_stage2_shared_pillar_hud(
		canvas,
		context,
		registry,
		states,
		view_size,
		game_offset,
		game_size,
		time_seconds,
		BattleRenderQuality.effect_scale(context)
	)


func draw_pillar_background_overlay(canvas: CanvasItem, context: Dictionary, registry, states: Dictionary) -> void:
	if canvas == null or registry == null:
		return
	var perf_logger: Object = context.get("battle_perf_logger", null)
	var sample_start: int = _perf_begin(perf_logger)
	var view_size: Vector2 = _get_vector2(context, "view_size", Vector2.ZERO)
	var game_offset: Vector2 = _get_vector2(context, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(context, "game_size", Vector2.ZERO)
	var width: float = float(context.get("width", 760.0))
	var quality_scale: float = BattleRenderQuality.effect_scale(context)
	var stage_background = states.get("stage_background", null)
	if stage_background == null:
		stage_background = registry.get_instance("stage2_pillar_background")
	if stage_background != null and stage_background.has_method("draw_pillar_background_overlay"):
		stage_background.draw_pillar_background_overlay(canvas, view_size, game_offset, game_size, width, perf_logger, quality_scale)
	_perf_end(perf_logger, "stage2.pillar.background_overlay", sample_start)


func draw_post_playfield_hud(canvas: CanvasItem, context: Dictionary, registry) -> void:
	if canvas == null or registry == null:
		return
	var perf_logger: Object = context.get("battle_perf_logger", null)
	var view_size: Vector2 = _get_vector2(context, "view_size", Vector2.ZERO)
	var game_offset: Vector2 = _get_vector2(context, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(context, "game_size", Vector2.ZERO)
	var sample_start: int = _perf_begin(perf_logger)
	hud_scene_drawer.draw_active_item_hud(canvas, context, registry, view_size, game_offset, game_size)
	_perf_end(perf_logger, "stage2.pillar.active_item_hud", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_stage2_boss_skill_hud(canvas, context, registry, view_size, game_offset, game_size)
	_perf_end(perf_logger, "stage2.pillar.boss_skill_hud", sample_start)


func _draw_stage2_boss_skill_hud(
	canvas: CanvasItem,
	context: Dictionary,
	registry: Object,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2
) -> void:
	var renderer: Object = registry.get_instance("stage2_boss_skill_hud_renderer")
	if renderer == null or not renderer.has_method("draw"):
		return
	var skill_state: Object = registry.get_instance("stage2_boss_skill_state")
	if skill_state == null or not skill_state.has_method("get_hud_context"):
		return
	var stage_background: Object = registry.get_instance("stage2_pillar_background")
	var hud_context: Dictionary = _get_dictionary(skill_state.get_hud_context(stage_background, context))
	hud_context["current_stage"] = int(context.get("current_stage", 2))
	hud_context["view_size"] = view_size
	hud_context["game_offset"] = game_offset
	hud_context["game_size"] = game_size
	var avoid_rect_value: Variant = context.get("commando_firearm_panel_rect", Rect2())
	if avoid_rect_value is Rect2:
		hud_context["commando_firearm_panel_rect"] = avoid_rect_value
	# Hatched lingpet rides this stage's boss skill rail too (companion persists across stages).
	LingpetRailCard.append_entry(hud_context, registry, "stage2_boss_skill_hud_skills", "stage2_boss_skill_hud_active")
	renderer.draw(canvas, hud_context)


func _draw_stage2_shared_pillar_hud(
	canvas: CanvasItem,
	context: Dictionary,
	registry: Object,
	states: Dictionary,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	time_seconds: float,
	quality_scale: float
) -> void:
	var use_static_lod := _should_stage2_hud_static_lod(quality_scale)
	var had_stage2_lod := false
	var had_shared_lod := false
	var previous_stage2_lod: Variant = null
	var previous_shared_lod: Variant = null
	if use_static_lod:
		had_stage2_lod = context.has("stage2_pillar_hud_static_lod")
		had_shared_lod = context.has("pillar_hud_static_lod")
		previous_stage2_lod = context.get("stage2_pillar_hud_static_lod", null)
		previous_shared_lod = context.get("pillar_hud_static_lod", null)
		context["stage2_pillar_hud_static_lod"] = true
		context["pillar_hud_static_lod"] = true
	hud_scene_drawer.draw(
		canvas,
		context,
		registry,
		states,
		view_size,
		game_offset,
		game_size,
		time_seconds
	)
	if use_static_lod:
		if had_stage2_lod:
			context["stage2_pillar_hud_static_lod"] = previous_stage2_lod
		else:
			context.erase("stage2_pillar_hud_static_lod")
		if had_shared_lod:
			context["pillar_hud_static_lod"] = previous_shared_lod
		else:
			context.erase("pillar_hud_static_lod")


func _should_stage2_hud_static_lod(quality_scale: float) -> bool:
	return quality_scale <= STAGE2_STATIC_HUD_LOD_SCALE or BattleRenderQuality.is_high_refresh_lod_active()


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _is_scoreboard_overlay_active(states: Dictionary, registry: Object) -> bool:
	var result_screen: Object = _get_instance(registry, "stage_clear_result_screen")
	if result_screen != null and result_screen.has_method("is_active") and bool(result_screen.is_active()):
		return false
	var scoreboard_state: Object = states.get("scoreboard_state", null)
	if scoreboard_state == null and registry != null and registry.has_method("get_instance"):
		scoreboard_state = registry.get_instance("scoreboard_state")
	return scoreboard_state != null and scoreboard_state.has_method("is_active") and bool(scoreboard_state.is_active())


func _is_blocking_overlay_lod_active(registry: Object) -> bool:
	var modal_gate: Object = _get_instance(registry, "battle_scene_modal_gate_controller")
	if modal_gate == null:
		return false
	var module_getter := Callable(self, "_get_registry_module").bind(registry)
	for method_name in BLOCKING_OVERLAY_LOD_METHODS:
		if modal_gate.has_method(method_name) and bool(modal_gate.call(method_name, module_getter)):
			return true
	return false


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return _as_object(registry.get_instance(key))


func _get_cached_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_cached_instance"):
		return null
	return _as_object(registry.get_cached_instance(key))


func _get_registry_module(key: String, registry: Object) -> Object:
	var cached: Object = _get_cached_instance(registry, key)
	if cached != null:
		return cached
	if registry != null and not registry.has_method("get_cached_instance") and registry.has_method("get_instance"):
		return _as_object(registry.get_instance(key))
	return null


func _as_object(value: Variant) -> Object:
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
