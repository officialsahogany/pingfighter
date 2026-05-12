extends Node2D

var owner_node: Object = null
var registry: Object = null


func configure(next_owner: Object, next_registry: Object) -> void:
	owner_node = next_owner
	registry = next_registry


func _draw() -> void:
	if owner_node == null or registry == null:
		return
	var tooltip_renderer: Object = _get_instance("smasher_skill_orb_tooltip_renderer")
	var draw_context_builder: Object = _get_instance("battle_draw_context")
	if (
		tooltip_renderer == null
		or draw_context_builder == null
		or not tooltip_renderer.has_method("draw")
		or not draw_context_builder.has_method("build_pillar_scene_context")
	):
		return

	var view_size: Vector2 = get_viewport_rect().size
	if view_size == Vector2.ZERO:
		return
	var scene_config: Dictionary = _build_scene_config()
	var layout: Dictionary = _build_layout(
		view_size,
		float(scene_config.get("width", 760.0)),
		float(scene_config.get("height", 750.0))
	)
	var scene_context: Dictionary = draw_context_builder.build_pillar_scene_context(owner_node, view_size, layout, 0.0)
	tooltip_renderer.draw(self, registry, view_size, layout, scene_context)


func _build_layout(view_size: Vector2, width: float, height: float) -> Dictionary:
	var layout_module: Object = _get_instance("battle_view_layout")
	if layout_module != null and layout_module.has_method("build_game_layout"):
		return layout_module.build_game_layout(view_size, width, height)
	return {
		"game_size": Vector2(width, height),
		"game_offset": Vector2.ZERO,
		"render_scale": 1.0,
	}


func _build_scene_config() -> Dictionary:
	var config: Object = _get_instance("battle_scene_config")
	if config != null and config.has_method("build_draw_context"):
		return config.build_draw_context()
	return {
		"width": 760.0,
		"height": 750.0,
		"pillar_width": 80.0,
	}


func _get_instance(key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
