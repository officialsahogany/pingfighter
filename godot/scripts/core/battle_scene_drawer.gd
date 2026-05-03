extends RefCounted

const BattleContextReader := preload("res://scripts/core/battle_context_reader.gd")

const BACKGROUND_COLOR := Color(0.02, 0.02, 0.05)


func draw(canvas: CanvasItem, registry: Object, config: Dictionary = {}) -> void:
	if canvas == null or registry == null:
		return
	var scene_config: Dictionary = config
	if scene_config.is_empty():
		scene_config = _build_scene_config(registry)
	var width: float = float(scene_config.get("width", 760.0))
	var height: float = float(scene_config.get("height", 750.0))
	var pillar_width: float = float(scene_config.get("pillar_width", 80.0))

	var feedback: Object = _get_instance(registry, "battle_feedback_state")
	var shake_offset: Vector2 = _get_shake_offset(feedback)
	var view_size: Vector2 = canvas.get_viewport_rect().size
	var layout: Dictionary = _build_layout(registry, view_size, width, height)
	var render_scale: float = float(layout.get("render_scale", 1.0))
	var game_offset: Vector2 = _get_vector2(layout, "game_offset", Vector2.ZERO)

	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), BACKGROUND_COLOR)
	_draw_pillar_scene(canvas, registry, view_size, layout)

	canvas.draw_set_transform(game_offset, 0.0, Vector2(render_scale, render_scale))
	_draw_playfield_scene(canvas, registry, shake_offset, width, height, pillar_width)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_hud_overlays(canvas, registry, view_size, layout)


func _draw_pillar_scene(canvas: CanvasItem, registry: Object, view_size: Vector2, layout: Dictionary) -> void:
	var pillar_draw_pass: Object = _get_instance(registry, "battle_scene_pillar_draw_pass")
	if pillar_draw_pass == null:
		return
	pillar_draw_pass.draw(canvas, registry, view_size, layout)


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


func _draw_hud_overlays(canvas: CanvasItem, registry: Object, view_size: Vector2, layout: Dictionary) -> void:
	var tooltip_renderer: Object = _get_instance(registry, "smasher_skill_orb_tooltip_renderer")
	var draw_context_builder: Object = _get_instance(registry, "battle_draw_context")
	if (
		tooltip_renderer != null
		and draw_context_builder != null
		and tooltip_renderer.has_method("draw")
		and draw_context_builder.has_method("build_pillar_scene_context")
	):
		tooltip_renderer.draw(
			canvas,
			registry,
			view_size,
			layout,
			draw_context_builder.build_pillar_scene_context(canvas, view_size, layout, 0.0)
		)
	var perk_renderer: Object = _get_instance(registry, "runtime_perk_overlay_renderer")
	var perk_state: Object = _get_instance(registry, "runtime_perk_state")
	var perk_catalog: Object = _get_instance(registry, "runtime_perk_catalog")
	if perk_renderer != null and perk_renderer.has_method("draw"):
		perk_renderer.draw(canvas, perk_state, perk_catalog, view_size, null)


func _build_layout(registry: Object, view_size: Vector2, width: float, height: float) -> Dictionary:
	var layout_module: Object = _get_instance(registry, "battle_view_layout")
	if layout_module != null:
		return layout_module.build_game_layout(view_size, width, height)
	return {
		"game_size": Vector2(width, height),
		"game_offset": Vector2.ZERO,
		"render_scale": 1.0,
	}


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


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
