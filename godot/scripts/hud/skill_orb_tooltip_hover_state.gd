extends RefCounted


func update_hover_state(owner: Object, registry: Object) -> Dictionary:
	var tooltip_renderer: Object = _get_instance(registry, "smasher_skill_orb_tooltip_renderer")
	var draw_context_builder: Object = _get_instance(registry, "battle_draw_context")
	if (
		owner == null
		or tooltip_renderer == null
		or draw_context_builder == null
		or not tooltip_renderer.has_method("update_hover_state")
		or not draw_context_builder.has_method("build_pillar_scene_context")
	):
		return {}

	var view_size: Vector2 = _get_owner_view_size(owner)
	if view_size == Vector2.ZERO:
		return {}
	var scene_config: Dictionary = _build_scene_config(registry)
	var layout: Dictionary = _build_layout(
		registry,
		view_size,
		float(scene_config.get("width", 760.0)),
		float(scene_config.get("height", 750.0))
	)
	var scene_context: Dictionary = draw_context_builder.build_pillar_scene_context(owner, view_size, layout, 0.0)
	var hover_state: Dictionary = tooltip_renderer.update_hover_state(owner, registry, view_size, layout, scene_context)
	if hover_state.is_empty():
		return {}
	if str(hover_state.get("hover_type", "skill_orb")) == "commando_firearm":
		var tooltip_state: Dictionary = _get_dict(hover_state.get("tooltip_state", {}))
		return {
			"skill_name": str(tooltip_state.get("tooltip_key", "commando_firearm")),
		}
	var skill_data: Dictionary = {}
	var skill_value: Variant = hover_state.get("skill_data", {})
	if skill_value is Dictionary:
		skill_data = skill_value
	return {
		"skill_name": str(skill_data.get("name", "")),
	}


func _build_layout(registry: Object, view_size: Vector2, width: float, height: float) -> Dictionary:
	var layout_module: Object = _get_instance(registry, "battle_view_layout")
	if layout_module != null and layout_module.has_method("build_game_layout"):
		return layout_module.build_game_layout(view_size, width, height)
	return {
		"game_size": Vector2(width, height),
		"game_offset": Vector2.ZERO,
		"render_scale": 1.0,
	}


func _build_scene_config(registry: Object) -> Dictionary:
	var config: Object = _get_instance(registry, "battle_scene_config")
	if config != null and config.has_method("build_draw_context"):
		return config.build_draw_context()
	return {
		"width": 760.0,
		"height": 750.0,
		"pillar_width": 80.0,
	}


func _get_owner_view_size(owner: Object) -> Vector2:
	if owner != null and owner.has_method("get_viewport_rect"):
		return owner.get_viewport_rect().size
	return Vector2.ZERO


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
