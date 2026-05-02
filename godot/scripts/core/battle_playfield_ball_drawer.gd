extends RefCounted

const BattleContextReader := preload("res://scripts/core/battle_context_reader.gd")


func draw_ball_effects(
	canvas: CanvasItem,
	registry: Object,
	draw_context_builder: Object,
	draw_context: Dictionary,
	draw_deps: Dictionary,
	shake_offset: Vector2
) -> void:
	if not bool(canvas.get("ball_active")) or str(canvas.get("ball_visual_type")) == "pingpong":
		return
	var ball_effects_renderer: Object = _get_instance(registry, "ball_effects_renderer")
	if ball_effects_renderer != null and draw_context_builder != null:
		ball_effects_renderer.draw_active_effects(
			canvas,
			shake_offset,
			draw_context_builder.build_ball_effects_context(draw_context, draw_deps)
		)


func draw_ball(
	canvas: CanvasItem,
	registry: Object,
	draw_context_builder: Object,
	draw_context: Dictionary,
	draw_deps: Dictionary,
	shake_offset: Vector2
) -> void:
	if draw_context_builder == null:
		return
	var ball_draw: Dictionary = draw_context_builder.build_ball_draw(draw_context, draw_deps)
	if not bool(ball_draw.get("should_draw", false)):
		return
	var ball_renderer: Object = _get_instance(registry, "ball_renderer")
	if ball_renderer == null:
		return
	var ball_renderer_context: Dictionary = _get_dict(ball_draw.get("context", {}))
	ball_renderer.draw_current(
		canvas,
		_get_vector2(ball_draw, "draw_pos", _get_canvas_vector2(canvas, "ball_pos", Vector2.ZERO) + shake_offset),
		ball_renderer_context
	)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_canvas_vector2(canvas: CanvasItem, key: String, fallback: Vector2) -> Vector2:
	if canvas == null:
		return fallback
	var value: Variant = canvas.get(key)
	if value is Vector2:
		return value
	return fallback


func _get_dict(value: Variant) -> Dictionary:
	return BattleContextReader.get_dictionary(value)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BattleContextReader.get_vector2(source, key, fallback)
