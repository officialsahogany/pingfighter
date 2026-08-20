extends RefCounted

const BattleContextReader := preload("res://scripts/core/battle_context_reader.gd")
const VictoryHighlightPillarTrace := preload("res://scripts/core/victory_highlight_pillar_trace.gd")
const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const PlayerCharacterRuntime := preload(
	"res://scripts/characters/player_character_runtime.gd"
)
const TowerAscentScreenSpaceSurfacePolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_screen_space_surface_policy.gd"
)
const TowerAscentMapHintRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_map_hint_renderer.gd"
)

const BACKGROUND_COLOR := Color(0.02, 0.02, 0.05)

var _arity_cache: Dictionary = {}
# 좌측 레터박스 퍽 스트립 렌더러(드로어 소유 — 엔트리 캐시는 렌더러 내부
# 소유, 투영 cache_signature/리비전 키로 무효화).
var hud_strip_renderer: Object = preload("res://scripts/hud/runtime_perk_hud_strip_renderer.gd").new()
var _tower_ascent_map_hint_renderer: Object = TowerAscentMapHintRenderer.new()


func draw(canvas: CanvasItem, registry: Object, config: Dictionary = {}) -> void:
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var total_start: int = _perf_begin(perf_logger)
	var sample_start: int = _perf_begin(perf_logger)
	var surface: Dictionary = _build_draw_surface(canvas, registry, config)
	_perf_end(perf_logger, "draw.scene.surface", sample_start)
	if surface.is_empty():
		_perf_end(perf_logger, "draw.scene.total", total_start)
		return
	var view_size: Vector2 = _get_vector2(surface, "view_size", Vector2.ZERO)
	var layout: Dictionary = surface.get("layout", {})
	VictoryHighlightPillarTrace.trace_draw_pass("battle_scene", canvas, registry, view_size, layout)
	sample_start = _perf_begin(perf_logger)
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), BACKGROUND_COLOR)
	_perf_end(perf_logger, "draw.scene.background", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_pillar_scene(canvas, registry, view_size, layout)
	_perf_end(perf_logger, "draw.scene.pillar_scene", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_tower_noncombat_node_background(canvas, registry, view_size)
	_perf_end(perf_logger, "draw.scene.tower_noncombat_background", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_tower_ascent_map_hint(canvas, registry, view_size, layout)
	_perf_end(perf_logger, "draw.scene.tower_map_hint", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_transformed_playfield_scene(canvas, registry, surface)
	_perf_end(perf_logger, "draw.scene.playfield", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_post_playfield_pillar_hud(canvas, registry, view_size, layout)
	_perf_end(perf_logger, "draw.scene.post_pillar_hud", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_perk_hud_strip(canvas, registry, view_size, layout)
	_perf_end(perf_logger, "draw.scene.perk_hud_strip", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_hud_overlays(canvas, registry, view_size, layout)
	_perf_end(perf_logger, "draw.scene.hud_overlays", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_tower_reward_pick(canvas, registry, view_size)
	_perf_end(perf_logger, "draw.scene.tower_reward_pick", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_tower_ascent_fullscreen_map(canvas, registry, view_size)
	_perf_end(perf_logger, "draw.scene.tower_fullscreen_map", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_tower_ascent_fullscreen_fade(canvas, registry, view_size)
	_perf_end(perf_logger, "draw.scene.tower_fullscreen_fade", sample_start)
	_perf_end(perf_logger, "draw.scene.total", total_start)


# 좌측 레터박스 퍽 스트립: 게이트는 levels OR 표시 투영 엔트리 — 일반 퍽
# 레벨이 비어도 신비의 주사위 전용 투영이 스트립을 열 수 있어야 하므로
# 레벨-공백 조기 반환을 두지 않는다.
func _draw_perk_hud_strip(canvas: CanvasItem, registry: Object, view_size: Vector2, layout: Dictionary) -> void:
	if hud_strip_renderer == null or not hud_strip_renderer.has_method("draw"):
		return
	var perk_state: Object = _get_instance(registry, "runtime_perk_state")
	var levels: Dictionary = {}
	var display_projection: Dictionary = {}
	if perk_state != null:
		var levels_value: Variant = perk_state.get("runtime_skill_levels")
		if levels_value is Dictionary:
			levels = levels_value
		if perk_state.has_method("get_perk_fusion_display_projection"):
			display_projection = perk_state.get_perk_fusion_display_projection()
	if not bool(hud_strip_renderer.has_visible_entries(levels, display_projection)):
		return
	var perk_catalog: Object = _get_instance(registry, "runtime_perk_catalog")
	var perk_icon_renderer: Object = _get_instance(registry, "runtime_perk_icon_renderer")
	var game_offset: Vector2 = _get_vector2(layout, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(layout, "game_size", view_size)
	hud_strip_renderer.draw(canvas, levels, perk_catalog, perk_icon_renderer, game_offset, game_size, display_projection)


func draw_playfield_underlay(canvas: CanvasItem, registry: Object, config: Dictionary = {}) -> void:
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var total_start: int = _perf_begin(perf_logger)
	var sample_start: int = _perf_begin(perf_logger)
	var surface: Dictionary = _build_draw_surface(canvas, registry, config)
	_perf_end(perf_logger, "draw.scene_underlay.surface", sample_start)
	if surface.is_empty():
		_perf_end(perf_logger, "draw.scene_underlay.total", total_start)
		return
	var view_size: Vector2 = _get_vector2(surface, "view_size", Vector2.ZERO)
	sample_start = _perf_begin(perf_logger)
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), BACKGROUND_COLOR)
	_perf_end(perf_logger, "draw.scene_underlay.background", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_transformed_playfield_scene(canvas, registry, surface)
	_perf_end(perf_logger, "draw.scene_underlay.playfield", sample_start)
	_perf_end(perf_logger, "draw.scene_underlay.total", total_start)


func draw_pillar_overlay(canvas: CanvasItem, registry: Object, config: Dictionary = {}) -> void:
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var total_start: int = _perf_begin(perf_logger)
	var sample_start: int = _perf_begin(perf_logger)
	var surface: Dictionary = _build_draw_surface(canvas, registry, config)
	_perf_end(perf_logger, "draw.pillar_overlay.surface", sample_start)
	if surface.is_empty():
		_perf_end(perf_logger, "draw.pillar_overlay.total", total_start)
		return
	var view_size: Vector2 = _get_vector2(surface, "view_size", Vector2.ZERO)
	var layout: Dictionary = surface.get("layout", {})
	var context_owner: Object = _get_context_owner(canvas, surface)
	VictoryHighlightPillarTrace.trace_draw_pass("pillar_overlay", canvas, registry, view_size, layout)
	if not bool(config.get("skip_background", false)):
		sample_start = _perf_begin(perf_logger)
		_draw_pillar_background_overlay(canvas, registry, view_size, layout, context_owner)
		_perf_end(perf_logger, "draw.pillar_overlay.background", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_pillar_hud_scene(canvas, registry, view_size, layout, context_owner)
	_perf_end(perf_logger, "draw.pillar_overlay.hud", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_post_playfield_pillar_hud(canvas, registry, view_size, layout, context_owner)
	_perf_end(perf_logger, "draw.pillar_overlay.post_hud", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_hud_overlays(canvas, registry, view_size, layout)
	_perf_end(perf_logger, "draw.pillar_overlay.hud_overlays", sample_start)
	_perf_end(perf_logger, "draw.pillar_overlay.total", total_start)


func _draw_transformed_playfield_scene(canvas: CanvasItem, registry: Object, surface: Dictionary) -> void:
	var width: float = float(surface.get("width", 760.0))
	var height: float = float(surface.get("height", 750.0))
	var pillar_width: float = float(surface.get("pillar_width", 80.0))
	var transform_state: Dictionary = _resolve_playfield_transform(surface)
	canvas.draw_set_transform(
		_get_vector2(transform_state, "origin", Vector2.ZERO),
		0.0,
		_get_vector2(transform_state, "scale", Vector2.ONE)
	)
	_draw_playfield_scene(canvas, registry, Vector2.ZERO, width, height, pillar_width)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _resolve_playfield_transform(surface: Dictionary) -> Dictionary:
	var width: float = float(surface.get("width", 760.0))
	var render_scale: float = float(surface.get("render_scale", 1.0))
	var game_offset: Vector2 = _get_vector2(surface, "game_offset", Vector2.ZERO)
	var shake_offset: Vector2 = _get_vector2(surface, "shake_offset", Vector2.ZERO)
	var origin := game_offset + shake_offset * render_scale
	var scale_value := Vector2(render_scale, render_scale)
	var context_owner: Object = _get_context_owner(null, surface)
	var mirror_active := (
		int(BattleSceneOwnerReader.get_value(context_owner, "current_stage", 1)) == 3
		and str(BattleSceneOwnerReader.get_value(context_owner, "stage_boss_variant", "")) == "alice"
		and bool(BattleSceneOwnerReader.get_value(context_owner, "stage3_alice_mirror_active", false))
	)
	if mirror_active:
		origin.x += width * render_scale
		scale_value.x = -render_scale
	return {"origin": origin, "scale": scale_value, "mirrored": mirror_active}


func _build_draw_surface(canvas: CanvasItem, registry: Object, config: Dictionary = {}) -> Dictionary:
	if canvas == null or registry == null:
		return {}
	var scene_config: Dictionary = config
	if scene_config.is_empty():
		scene_config = _build_scene_config(registry)
	var width: float = float(scene_config.get("width", 760.0))
	var height: float = float(scene_config.get("height", 750.0))
	var pillar_width: float = float(scene_config.get("pillar_width", 80.0))
	var feedback: Object = _get_instance(registry, "battle_feedback_state")
	var view_size: Vector2 = _get_vector2(scene_config, "view_size", Vector2.ZERO)
	if view_size == Vector2.ZERO:
		view_size = canvas.get_viewport_rect().size
	var layout: Dictionary = _build_layout(registry, view_size, width, height)
	var render_scale: float = float(layout.get("render_scale", 1.0))
	var game_offset: Vector2 = _get_vector2(layout, "game_offset", Vector2.ZERO)
	return {
		"width": width,
		"height": height,
		"pillar_width": pillar_width,
		"view_size": view_size,
		"layout": layout,
		"render_scale": render_scale,
		"game_offset": game_offset,
		"shake_offset": _get_shake_offset(feedback),
		"context_owner": config.get("context_owner", canvas),
	}


func _draw_pillar_scene(canvas: CanvasItem, registry: Object, view_size: Vector2, layout: Dictionary) -> void:
	var pillar_draw_pass: Object = _get_instance(registry, "battle_scene_pillar_draw_pass")
	if pillar_draw_pass == null:
		return
	pillar_draw_pass.draw(canvas, registry, view_size, layout)


func _draw_tower_ascent_map_hint(
	canvas: CanvasItem,
	registry: Object,
	view_size: Vector2,
	layout: Dictionary
) -> void:
	# This pass intentionally stays in screen space. The full 760x750 game
	# canvas begins at game_offset; the hint may only occupy the left letterbox.
	var flow_owner: Object = _get_cached_instance(registry, "tower_ascent_flow_owner")
	var flow_active := (
		flow_owner != null
		and flow_owner.has_method("is_active")
		and bool(flow_owner.is_active())
	)
	_tower_ascent_map_hint_renderer.draw(
		canvas,
		view_size,
		_get_vector2(layout, "game_offset", Vector2.ZERO),
		_get_vector2(layout, "game_size", view_size),
		flow_active
	)


func _draw_tower_noncombat_node_background(
	canvas: CanvasItem,
	registry: Object,
	view_size: Vector2
) -> void:
	var flow_owner: Object = _get_cached_instance(registry, "tower_ascent_flow_owner")
	if (
		flow_owner == null
		or not flow_owner.has_method("draw_retained_noncombat_node_background")
	):
		return
	flow_owner.draw_retained_noncombat_node_background(
		canvas,
		Rect2(Vector2.ZERO, view_size)
	)


func _draw_pillar_hud_scene(canvas: CanvasItem, registry: Object, view_size: Vector2, layout: Dictionary, context_owner: Object = null) -> void:
	var pillar_draw_pass: Object = _get_instance(registry, "battle_scene_pillar_draw_pass")
	if pillar_draw_pass == null or not pillar_draw_pass.has_method("draw_hud_overlay"):
		return
	pillar_draw_pass.draw_hud_overlay(canvas, registry, view_size, layout, context_owner)


func _draw_pillar_background_overlay(canvas: CanvasItem, registry: Object, view_size: Vector2, layout: Dictionary, context_owner: Object = null) -> void:
	var pillar_draw_pass: Object = _get_instance(registry, "battle_scene_pillar_draw_pass")
	if pillar_draw_pass == null or not pillar_draw_pass.has_method("draw_background_overlay"):
		return
	pillar_draw_pass.draw_background_overlay(canvas, registry, view_size, layout, context_owner)


func _draw_playfield_scene(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	width: float,
	height: float,
	pillar_width: float
) -> void:
	var playfield_drawer: Object = _get_instance(registry, "battle_playfield_scene_drawer")
	if playfield_drawer == null:
		return
	playfield_drawer.draw(
		canvas,
		registry,
		shake_offset,
		width,
		height,
		pillar_width
	)


func _draw_hud_overlays(canvas: CanvasItem, registry: Object, _view_size: Vector2, _layout: Dictionary) -> void:
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var perk_renderer: Object = _get_instance(registry, "runtime_perk_overlay_renderer")
	if perk_renderer == null or not perk_renderer.has_method("draw"):
		return
	var perk_state: Object = _get_instance(registry, "runtime_perk_state")
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if (
		_method_accepts_argument_count(perk_renderer, "has_visible_effects", 2)
		and not bool(perk_renderer.has_visible_effects(perk_state, mythic_item_runtime))
	):
		return
	var perk_catalog: Object = _get_instance(registry, "runtime_perk_catalog")
	var perk_icon_renderer: Object = _get_instance(registry, "runtime_perk_icon_renderer")
	if _method_accepts_argument_count(perk_renderer, "draw", 7):
		perk_renderer.draw(canvas, perk_state, perk_catalog, _view_size, perk_icon_renderer, mythic_item_runtime, perf_logger)
	else:
		perk_renderer.draw(canvas, perk_state, perk_catalog, _view_size, perk_icon_renderer, mythic_item_runtime)


func _draw_tower_ascent_fullscreen_map(
	canvas: CanvasItem,
	registry: Object,
	view_size: Vector2
) -> void:
	var flow_owner: Object = _get_cached_instance(registry, "tower_ascent_flow_owner")
	var phase_name := (
		str(flow_owner.get_phase_name())
		if flow_owner != null and flow_owner.has_method("get_phase_name")
		else ""
	)
	var overlay_closing := (
		flow_owner != null
		and flow_owner.has_method("is_map_overlay_closing")
		and bool(flow_owner.is_map_overlay_closing())
	)
	var transition_visual_model: Dictionary = (
		flow_owner.get_map_transition_visual_model()
		if flow_owner != null and flow_owner.has_method("get_map_transition_visual_model")
		else {}
	)
	if (
		flow_owner == null
		or (
			not overlay_closing
			and not TowerAscentScreenSpaceSurfacePolicy.uses_screen_space_flow_phase(
				phase_name,
				transition_visual_model
			)
		)
		or not flow_owner.has_method("draw_fullscreen_surface")
	):
		return
	var walker_model := _build_tower_map_walker_model(canvas)
	if _method_accepts_argument_count(flow_owner, "draw_fullscreen_surface", 3):
		flow_owner.draw_fullscreen_surface(
			canvas,
			Rect2(Vector2.ZERO, view_size),
			walker_model
		)
	else:
		flow_owner.draw_fullscreen_surface(canvas, Rect2(Vector2.ZERO, view_size))


func _draw_tower_ascent_fullscreen_fade(
	canvas: CanvasItem,
	registry: Object,
	view_size: Vector2
) -> void:
	var flow_owner: Object = _get_cached_instance(registry, "tower_ascent_flow_owner")
	if (
		flow_owner == null
		or not flow_owner.has_method("draw_fullscreen_fade")
		or not flow_owner.has_method("is_active")
		or not bool(flow_owner.is_active())
	):
		return
	flow_owner.draw_fullscreen_fade(canvas, Rect2(Vector2.ZERO, view_size))


func _build_tower_map_walker_model(canvas: CanvasItem) -> Dictionary:
	var textures_value: Variant = BattleSceneOwnerReader.get_value(canvas, "battle_textures", {})
	if not (textures_value is Dictionary):
		return {}
	var textures := textures_value as Dictionary
	var character_runtime := PlayerCharacterRuntime.new()
	var character_type := character_runtime.normalize(
		BattleSceneOwnerReader.get_value(canvas, "selected_character_type", PlayerCharacterRuntime.SMASHER)
	)
	var left_key := "player_walk_left_texture"
	var right_key := "player_walk_right_texture"
	match character_type:
		PlayerCharacterRuntime.COMMANDO:
			left_key = "commando_player_walk_left_sheet"
			right_key = "commando_player_walk_right_sheet"
		PlayerCharacterRuntime.VIPER:
			left_key = "viper_player_walk_left_sheet"
			right_key = "viper_player_walk_right_sheet"
		PlayerCharacterRuntime.OPTIMUS:
			left_key = "optimus_player_walk_left_sheet"
			right_key = "optimus_player_walk_right_sheet"
		PlayerCharacterRuntime.BLACKSMITH:
			left_key = "blacksmith_player_walk_left_sheet"
			right_key = "blacksmith_player_walk_right_sheet"
	return {
		"left_texture": textures.get(left_key, null),
		"right_texture": textures.get(right_key, null),
		"grid_cols": 4,
		"grid_rows": 2,
		"frame_count": 8,
		"character_type": character_type,
	}


func _draw_tower_reward_pick(
	canvas: CanvasItem,
	registry: Object,
	view_size: Vector2
) -> void:
	var loot_state: Object = _get_instance(registry, "victory_loot_phase_state")
	if (
		loot_state == null
		or not loot_state.has_method("is_reward_pick_active")
		or not bool(loot_state.is_reward_pick_active())
		or not loot_state.has_method("draw_reward_pick")
	):
		return
	loot_state.draw_reward_pick(canvas, view_size)


func _draw_post_playfield_pillar_hud(canvas: CanvasItem, registry: Object, view_size: Vector2, layout: Dictionary, context_owner: Object = null) -> void:
	var draw_context_builder: Object = _get_instance(registry, "battle_draw_context")
	var context: Dictionary = {}
	var context_source: Object = context_owner if context_owner != null else canvas
	if draw_context_builder != null and draw_context_builder.has_method("build_pillar_scene_context"):
		context = draw_context_builder.build_pillar_scene_context(context_source, view_size, layout, 0.0)
	_append_viper_lod_context(context, registry)
	context["battle_perf_logger"] = _get_instance(registry, "battle_perf_logger")
	var current_stage: int = int(context.get("current_stage", 1))
	var pillar_scene_drawer: Object = _get_stage_instance(registry, current_stage, "pillar_scene_drawer", "stage1_pillar_scene_drawer")
	if (
		draw_context_builder == null
		or pillar_scene_drawer == null
		or not pillar_scene_drawer.has_method("draw_post_playfield_hud")
	):
		return
	pillar_scene_drawer.draw_post_playfield_hud(
		canvas,
		context,
		registry
	)


func _build_layout(registry: Object, view_size: Vector2, width: float, height: float) -> Dictionary:
	var layout_module: Object = _get_instance(registry, "battle_view_layout")
	if layout_module != null:
		return layout_module.build_game_layout(view_size, width, height)
	return {
		"game_size": Vector2(width, height),
		"game_offset": Vector2.ZERO,
		"render_scale": 1.0,
	}


func _get_context_owner(canvas: CanvasItem, surface: Dictionary) -> Object:
	var owner: Variant = surface.get("context_owner", canvas)
	if typeof(owner) == TYPE_OBJECT and owner != null and is_instance_valid(owner):
		return owner as Object
	return canvas


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_cached_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_cached_instance"):
		return null
	return registry.get_cached_instance(key)


func _append_viper_lod_context(context: Dictionary, registry: Object) -> void:
	var jetpack_state: Object = _get_instance(registry, "viper_jetpack_state")
	if jetpack_state == null:
		return
	if "active" in jetpack_state:
		context["viper_jetpack_active"] = bool(jetpack_state.active)
	if jetpack_state.has_method("is_airborne"):
		context["viper_jetpack_airborne"] = bool(jetpack_state.is_airborne(0.1))
	if "air_strike_flash_timer" in jetpack_state:
		context["viper_air_strike_flash_timer"] = float(jetpack_state.air_strike_flash_timer)


func _method_accepts_argument_count(target: Object, method_name: String, arg_count: int) -> bool:
	if target == null:
		return false
	var instance_id: int = target.get_instance_id()
	var by_instance: Variant = _arity_cache.get(instance_id)
	if by_instance is Dictionary:
		var by_method: Variant = (by_instance as Dictionary).get(method_name)
		if by_method is Dictionary:
			var cached: Variant = (by_method as Dictionary).get(arg_count)
			if cached != null:
				return bool(cached)
	var result: bool = false
	for method_info in target.get_method_list():
		if not (method_info is Dictionary):
			continue
		if str(method_info.get("name", "")) != method_name:
			continue
		var args_count: int = 0
		var args_value: Variant = method_info.get("args", [])
		if args_value is Array:
			args_count = args_value.size()
		var default_count: int = 0
		var default_value: Variant = method_info.get("default_args", [])
		if default_value is Array:
			default_count = default_value.size()
		var min_args_count: int = max(0, args_count - default_count)
		result = arg_count >= min_args_count and arg_count <= args_count
		break
	var instance_cache: Dictionary = _arity_cache.get(instance_id, {})
	var method_cache: Dictionary = instance_cache.get(method_name, {})
	method_cache[arg_count] = result
	instance_cache[method_name] = method_cache
	_arity_cache[instance_id] = instance_cache
	return result


func _get_stage_instance(registry: Object, current_stage: int, role: String, fallback_key: String) -> Object:
	var router: Object = _get_instance(registry, "stage_runtime_router")
	if router != null and router.has_method("get_instance"):
		var routed: Object = router.get_instance(registry, current_stage, role)
		if routed != null:
			return routed
	return _get_instance(registry, fallback_key)


func _build_scene_config(registry: Object) -> Dictionary:
	var config: Object = _get_instance(registry, "battle_scene_config")
	if config != null and config.has_method("build_draw_context"):
		return config.build_draw_context()
	return {
		"width": 760.0,
		"height": 750.0,
		"pillar_width": 80.0,
	}


func _get_shake_offset(feedback: Object) -> Vector2:
	if feedback != null and feedback.has_method("get_shake_offset"):
		var offset: Variant = feedback.get_shake_offset()
		if offset is Vector2:
			return offset
	return Vector2.ZERO


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BattleContextReader.get_vector2(source, key, fallback)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
