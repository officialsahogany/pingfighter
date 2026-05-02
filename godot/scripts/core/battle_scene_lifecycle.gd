extends RefCounted


func initialize(owner: CanvasItem, registry: Object, context: Dictionary = {}) -> void:
	if owner == null or registry == null:
		return
	randomize()
	owner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	owner.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	var startup_context: Dictionary = context
	if startup_context.is_empty():
		startup_context = _build_startup_context(owner, registry)

	var view_layout: Object = _get_instance(registry, "battle_view_layout")
	if view_layout != null:
		view_layout.configure_window(owner.get_window())

	var bootstrap: Object = _get_instance(registry, "battle_scene_bootstrap")
	if bootstrap != null:
		_apply_owner_snapshot(owner, bootstrap.initialize(owner, startup_context, registry))

	var update_driver: Object = _get_instance(registry, "battle_scene_update_driver")
	if update_driver != null:
		update_driver.reset_ball(owner, registry)


func _apply_owner_snapshot(owner: Object, snapshot: Dictionary) -> void:
	if owner == null:
		return
	for key in snapshot.keys():
		owner.set(str(key), snapshot[key])


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _build_startup_context(owner: Object, registry: Object) -> Dictionary:
	var config: Object = _get_instance(registry, "battle_scene_config")
	if config != null and config.has_method("build_startup_context"):
		return config.build_startup_context(owner)
	return {
		"width": 760.0,
		"height": 750.0,
		"pillar_width": 80.0,
		"player_y": 700.0,
		"boss_y": 25.0,
		"player_paddle_width": 155.0,
		"boss_paddle_width": 100.0,
		"current_stage": int(owner.get("current_stage")),
		"ai_mode": str(owner.get("ai_mode")),
		"arena_mode_enabled": bool(owner.get("arena_mode_enabled")),
		"weather_type": str(owner.get("weather_type")),
	}
