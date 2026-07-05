extends RefCounted

const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")


static func build_input_context_from_screen(screen: Object) -> Dictionary:
	if screen == null:
		return {}
	return {
		"spawn_pending": _get_screen_bool(screen, "_spawn_pending", false),
		"scene": _get_screen_control(screen, "_scene_node"),
		"owner": _get_screen_object(screen, "_pending_owner"),
		"registry": _get_screen_object(screen, "_pending_registry"),
		"plaza_scene_handler": _get_screen_object(screen, "_plaza_scene_handler"),
		"mythic_acquisition_handler": _get_screen_object(screen, "_mythic_acquisition_handler"),
		"starpoint_choice_handler": _get_screen_object(screen, "_starpoint_choice_handler"),
		"dalji_click_dialogue_duration": StageClearResultScene.DALJI_CLICK_DIALOGUE_DURATION,
		"is_active": Callable(screen, "is_active"),
		"has_result_scene": Callable(screen, "_has_result_scene"),
	}


static func _get_screen_object(screen: Object, property_name: String) -> Object:
	if screen == null:
		return null
	var value: Variant = screen.get(property_name)
	return value if value is Object else null


static func _get_screen_control(screen: Object, property_name: String) -> Control:
	var value: Object = _get_screen_object(screen, property_name)
	if value is Control and is_instance_valid(value):
		return value as Control
	return null


static func _get_screen_bool(screen: Object, property_name: String, default_value: bool) -> bool:
	if screen == null:
		return default_value
	var value: Variant = screen.get(property_name)
	if value == null:
		return default_value
	return bool(value)
