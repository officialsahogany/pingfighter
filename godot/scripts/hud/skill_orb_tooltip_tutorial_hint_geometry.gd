extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")


static func get_highlight_rect(
	owner: Object,
	registry: Object,
	view_size: Vector2,
	target_skill: String,
	layout_helper: Object,
	fallback_orb_renderer: Object
) -> Rect2:
	if target_skill == "":
		return Rect2()
	var skill_config: Object = _get_instance(registry, "smasher_skill_config")
	if skill_config == null or not skill_config.has_method("get_snapshot"):
		return Rect2()
	var snapshot: Dictionary = _get_dict(skill_config.get_snapshot())
	var equipped_skills: Array = _get_array(snapshot.get("equipped_skills", []))
	var target_index := -1
	for i in range(equipped_skills.size()):
		if str(equipped_skills[i]) == target_skill:
			target_index = i
			break
	if target_index < 0:
		return Rect2()
	if layout_helper == null or not layout_helper.has_method("build_layout") or not layout_helper.has_method("build_skill_orb_context"):
		return Rect2()
	var scene_config: Dictionary = _build_scene_config(registry)
	var layout: Dictionary = _build_layout(
		registry,
		view_size,
		float(scene_config.get("width", 760.0)),
		float(scene_config.get("height", 750.0))
	)
	var game_offset: Vector2 = _get_vector2(layout, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(layout, "game_size", Vector2(760.0, 750.0))
	var ui_layout: Dictionary = layout_helper.build_layout(game_offset, game_size, {
		"height": float(scene_config.get("height", 750.0)),
	})
	var scale_factor: float = float(ui_layout.get("scale_factor", 1.0))
	var skill_context: Dictionary = layout_helper.build_skill_orb_context({
		"skill_state": _get_instance(registry, "smasher_skill_state"),
		"selected_character_type": "smasher",
		"skill_config_snapshot": snapshot,
		"special_gauge": BattleSceneOwnerReader.get_value(owner, "special_gauge", 0.0),
	}, _get_instance(registry, "pillar_orb_drawer"))
	var orb_renderer: Object = _get_instance(registry, "smasher_skill_orb_renderer")
	if orb_renderer == null or not orb_renderer.has_method("get_slot_positions"):
		orb_renderer = fallback_orb_renderer
	if orb_renderer == null or not orb_renderer.has_method("get_slot_positions"):
		return Rect2()
	var positions: Array = orb_renderer.get_slot_positions(
		_get_vector2(ui_layout, "left_center", Vector2.ZERO),
		float(ui_layout.get("orb_radius", 55.0)),
		scale_factor,
		skill_context
	)
	if target_index >= positions.size():
		return Rect2()
	var icon_radius: float = float(skill_context.get("skill_orb_radius", 24.0)) * scale_factor
	var center: Vector2 = _as_vector2(positions[target_index], Vector2.ZERO)
	return Rect2(center - Vector2(icon_radius, icon_radius), Vector2(icon_radius * 2.0, icon_radius * 2.0))


static func _build_layout(registry: Object, view_size: Vector2, width: float, height: float) -> Dictionary:
	var layout_module: Object = _get_instance(registry, "battle_view_layout")
	if layout_module != null and layout_module.has_method("build_game_layout"):
		return layout_module.build_game_layout(view_size, width, height)
	return {
		"game_size": Vector2(width, height),
		"game_offset": Vector2.ZERO,
		"render_scale": 1.0,
	}


static func _build_scene_config(registry: Object) -> Dictionary:
	var config: Object = _get_instance(registry, "battle_scene_config")
	if config != null and config.has_method("build_draw_context"):
		return config.build_draw_context()
	return {
		"width": 760.0,
		"height": 750.0,
		"pillar_width": 80.0,
	}


static func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "" or not registry.has_method("get_instance"):
		return null
	var value: Variant = registry.get_instance(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


static func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


static func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


static func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
