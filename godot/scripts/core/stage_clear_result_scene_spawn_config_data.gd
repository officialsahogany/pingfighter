extends RefCounted


static func build_result_scene_config(
	scene_config_builder: Object,
	player_score: int,
	boss_score: int,
	current_stage: int,
	selected_character_type: String,
	reward_plan: Dictionary,
	stage_reward_snapshot: Dictionary,
	runtime_owner: Object,
	runtime_registry: Object
) -> Dictionary:
	if scene_config_builder == null or not scene_config_builder.has_method("build_config"):
		return {}
	var config_value: Variant = scene_config_builder.build_config(
		player_score,
		boss_score,
		current_stage,
		selected_character_type,
		reward_plan,
		stage_reward_snapshot,
		runtime_owner,
		runtime_registry
	)
	return config_value.duplicate(true) if config_value is Dictionary else {}


static func get_result_victory_character_type(runtime_context_handler: Object, owner: Object) -> String:
	if runtime_context_handler != null and runtime_context_handler.has_method("get_result_victory_character_type"):
		return str(runtime_context_handler.get_result_victory_character_type(owner))
	return ""


static func get_screen_reward_plan(screen: Object) -> Dictionary:
	if screen != null and screen.has_method("get_reward_plan"):
		var reward_plan_value: Variant = screen.get_reward_plan()
		return reward_plan_value.duplicate(true) if reward_plan_value is Dictionary else {}
	return {}


static func get_screen_dictionary(screen: Object, property_name: String) -> Dictionary:
	if screen == null:
		return {}
	var value: Variant = screen.get(property_name)
	return value.duplicate(true) if value is Dictionary else {}


static func get_screen_int(screen: Object, property_name: String, fallback: int) -> int:
	if screen == null:
		return fallback
	var value: Variant = screen.get(property_name)
	if value == null:
		return fallback
	return int(value)


static func get_screen_control(screen: Object, property_name: String) -> Control:
	var value: Object = get_screen_object(screen, property_name)
	if value is Control and is_instance_valid(value):
		return value as Control
	return null


static func get_screen_object(screen: Object, property_name: String) -> Object:
	if screen == null:
		return null
	var value: Variant = screen.get(property_name)
	return value if value is Object else null
