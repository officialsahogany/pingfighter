extends RefCounted


static func grant_immediate_box_reward(
	reward: Dictionary,
	box_index: int,
	owner: Object,
	registry: Object,
	scene: Control,
	reward_grant_handler: Object,
	starpoint_choice_handler: Object,
	mythic_acquisition_handler: Object,
	starpoint_choice_reward_delay: float
) -> bool:
	if reward_grant_handler == null or not reward_grant_handler.has_method("grant_immediate_box_reward"):
		return false
	var result: Dictionary = reward_grant_handler.grant_immediate_box_reward(
		reward,
		owner,
		registry,
		can_defer_starpoint_choice(starpoint_choice_handler, registry)
	)
	if not bool(result.get("granted", false)):
		return false
	if bool(result.get("defer_starpoint_choice", false)):
		schedule_deferred_starpoint_choice(starpoint_choice_handler, scene, box_index, starpoint_choice_reward_delay)
	if bool(result.get("mythic_perk_choice_opened", false)):
		record_active_mythic_perk_choice(starpoint_choice_handler, scene, box_index, registry)
	if bool(result.get("raise_mythic_acquisition_cinematic", false)):
		raise_mythic_acquisition_cinematic(mythic_acquisition_handler, registry)
	sync_scene_visibility(scene)
	return true


static func grant_immediate_box_reward_from_screen(
	reward: Dictionary,
	box_index: int,
	screen: Object,
	owner: Object,
	registry: Object,
	reward_grant_handler: Object,
	starpoint_choice_handler: Object,
	mythic_acquisition_handler: Object,
	starpoint_choice_reward_delay: float
) -> bool:
	if screen == null or not bool(screen.get("active")):
		return false
	return grant_immediate_box_reward(
		reward,
		box_index,
		owner,
		registry,
		get_screen_scene(screen),
		reward_grant_handler,
		starpoint_choice_handler,
		mythic_acquisition_handler,
		starpoint_choice_reward_delay
	)


static func can_defer_starpoint_choice(starpoint_choice_handler: Object, registry: Object) -> bool:
	if starpoint_choice_handler == null or not starpoint_choice_handler.has_method("can_defer_choice"):
		return false
	return bool(starpoint_choice_handler.can_defer_choice(
		get_instance(registry, "runtime_perk_state"),
		get_instance(registry, "runtime_perk_catalog")
	))


static func schedule_deferred_starpoint_choice(
	starpoint_choice_handler: Object,
	scene: Control,
	box_index: int,
	delay: float
) -> void:
	if starpoint_choice_handler != null and starpoint_choice_handler.has_method("schedule_deferred_choice"):
		starpoint_choice_handler.schedule_deferred_choice(scene, box_index, delay)


static func record_active_mythic_perk_choice(
	starpoint_choice_handler: Object,
	scene: Control,
	box_index: int,
	registry: Object
) -> void:
	if starpoint_choice_handler != null and starpoint_choice_handler.has_method("record_active_choice"):
		starpoint_choice_handler.record_active_choice(scene, box_index, get_instance(registry, "runtime_perk_state"))


static func raise_mythic_acquisition_cinematic(mythic_acquisition_handler: Object, registry: Object) -> void:
	if mythic_acquisition_handler != null and mythic_acquisition_handler.has_method("raise_cinematic"):
		mythic_acquisition_handler.raise_cinematic(get_instance(registry, "mythic_item_runtime"))


static func sync_scene_visibility(scene: Control) -> void:
	if scene != null and is_instance_valid(scene):
		scene.visible = true


static func get_screen_scene(screen: Object) -> Control:
	if screen == null:
		return null
	var scene_value: Variant = screen.get("_scene_node")
	if scene_value is Control:
		var scene := scene_value as Control
		if is_instance_valid(scene):
			return scene
	return null


static func get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var instance: Variant = registry.get_instance(key)
	return instance if instance is Object else null
