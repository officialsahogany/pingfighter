extends RefCounted

const ScoreboardState := preload("res://scripts/hud/scoreboard_state.gd")


func draw(canvas: CanvasItem, registry: Object, view_size: Vector2, layout: Dictionary) -> void:
	var draw_context_builder: Object = _get_instance(registry, "battle_draw_context")
	var pillar_scene_drawer: Object = _get_instance(registry, "stage1_pillar_scene_drawer")
	if pillar_scene_drawer == null or draw_context_builder == null:
		return
	pillar_scene_drawer.draw(
		canvas,
		draw_context_builder.build_pillar_scene_context(
			canvas,
			view_size,
			layout,
			ScoreboardState.TOP_MINI_SCORE_SPARKLE_DURATION
		),
		registry,
		draw_context_builder.build_pillar_scene_states(registry)
	)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
