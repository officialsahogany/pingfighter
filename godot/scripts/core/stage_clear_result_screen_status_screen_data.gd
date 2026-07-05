extends RefCounted


static func build_status_from_screen(status_handler: Object, screen: Object, scene_path: String) -> Dictionary:
	if screen == null:
		return {}
	if status_handler == null or not status_handler.has_method("build_status"):
		return {}
	var plaza_progress_handler: Object = _get_screen_object(screen, "_plaza_progress_handler")
	var status_value: Variant = status_handler.build_status(
		_call_screen_bool(screen, "is_active", _get_screen_bool(screen, "active", false)),
		_get_screen_int(screen, "player_score", 0),
		_get_screen_int(screen, "boss_score", 0),
		_get_screen_int(screen, "current_stage", 1),
		_get_screen_reward_plan(screen),
		scene_path,
		_get_screen_scene_ready(screen),
		_get_screen_bool(screen, "_spawn_pending", false),
		_get_cached_plaza_progress_summary(plaza_progress_handler),
		_get_screen_dictionary(screen, "_stage_start_snapshot"),
		_get_screen_dictionary(screen, "_last_stage_reward_snapshot"),
		_get_screen_object(screen, "_reward_grant_handler"),
		_get_screen_object(screen, "_starpoint_choice_handler"),
		_get_screen_object(screen, "_plaza_scene_handler")
	)
	return (status_value as Dictionary).duplicate(true) if status_value is Dictionary else {}


static func _get_screen_reward_plan(screen: Object) -> Dictionary:
	if screen == null or not screen.has_method("get_reward_plan"):
		return {}
	var reward_plan_value: Variant = screen.get_reward_plan()
	return reward_plan_value.duplicate(true) if reward_plan_value is Dictionary else {}


static func _get_screen_scene_ready(screen: Object) -> bool:
	if screen != null and screen.has_method("is_scene_ready"):
		return bool(screen.is_scene_ready())
	var scene: Object = _get_screen_object(screen, "_scene_node")
	return scene != null and is_instance_valid(scene)


static func _get_cached_plaza_progress_summary(plaza_progress_handler: Object) -> Dictionary:
	if plaza_progress_handler == null or not plaza_progress_handler.has_method("get_cached_summary"):
		return {}
	var summary_value: Variant = plaza_progress_handler.get_cached_summary()
	return summary_value.duplicate(true) if summary_value is Dictionary else {}


static func _call_screen_bool(screen: Object, method_name: String, fallback: bool) -> bool:
	if screen == null or not screen.has_method(method_name):
		return fallback
	return bool(screen.call(method_name))


static func _get_screen_object(screen: Object, property_name: String) -> Object:
	if screen == null:
		return null
	var value: Variant = screen.get(property_name)
	return value if value is Object else null


static func _get_screen_dictionary(screen: Object, property_name: String) -> Dictionary:
	if screen == null:
		return {}
	var value: Variant = screen.get(property_name)
	return value.duplicate(true) if value is Dictionary else {}


static func _get_screen_int(screen: Object, property_name: String, default_value: int) -> int:
	if screen == null:
		return default_value
	var value: Variant = screen.get(property_name)
	if value == null:
		return default_value
	return int(value)


static func _get_screen_bool(screen: Object, property_name: String, default_value: bool) -> bool:
	if screen == null:
		return default_value
	var value: Variant = screen.get(property_name)
	if value == null:
		return default_value
	return bool(value)
