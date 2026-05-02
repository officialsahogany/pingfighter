extends RefCounted

const Stage1PillarHudSceneDrawer := preload("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")

var hud_scene_drawer: Object = Stage1PillarHudSceneDrawer.new()


func draw(canvas: CanvasItem, context: Dictionary, registry, states: Dictionary) -> void:
	if canvas == null or registry == null:
		return

	var view_size: Vector2 = _get_vector2(context, "view_size", Vector2.ZERO)
	var game_offset: Vector2 = _get_vector2(context, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(context, "game_size", Vector2.ZERO)
	var width: float = float(context.get("width", 760.0))
	var height: float = float(context.get("height", 750.0))
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0

	var stage_background = states.get("stage_background", null)
	var drew_layered_background := false
	if stage_background != null:
		drew_layered_background = stage_background.draw(canvas, view_size, game_offset, game_size, width)
	if not drew_layered_background:
		var fallback_renderer = registry.get_instance("stage1_fallback_pillar_renderer")
		if fallback_renderer != null:
			fallback_renderer.draw(canvas, view_size, game_offset, game_size, height, time_seconds)

	hud_scene_drawer.draw(canvas, context, registry, states, view_size, game_offset, game_size, time_seconds)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
