extends RefCounted

const StageClearResultConfigSceneHandler := preload("res://scripts/ui/stage_clear_result_config_scene_handler.gd")


static func build_callbacks(
	next_stage: Callable,
	exit_to_menu: Callable,
	roll_box_reward: Callable,
	grant_immediate_box_reward: Callable,
	enter_plaza: Callable
) -> Dictionary:
	return {
		"next_stage": next_stage,
		"exit_to_menu": exit_to_menu,
		"roll_box_reward": roll_box_reward,
		"grant_immediate_box_reward": grant_immediate_box_reward,
		"enter_plaza": enter_plaza,
	}


static func spawn_scene(
	owner: Object,
	packed: PackedScene,
	scene_path: String,
	config: Dictionary,
	callbacks: Dictionary
) -> Control:
	if not (owner is Node):
		return null
	if packed == null:
		push_warning("Missing stage clear result scene at %s" % scene_path)
		return null

	var instance: Node = packed.instantiate()
	if not (instance is Control):
		if instance != null:
			instance.queue_free()
		push_warning("Stage clear result scene root must be Control: %s" % scene_path)
		return null

	var scene := instance as Control
	scene.name = "StageClearResultScene"
	scene.process_mode = Node.PROCESS_MODE_ALWAYS
	scene.z_index = 1200
	scene.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	StageClearResultConfigSceneHandler.configure(
		scene,
		config,
		_get_callback(callbacks, "next_stage"),
		_get_callback(callbacks, "exit_to_menu"),
		_get_callback(callbacks, "roll_box_reward"),
		_get_callback(callbacks, "grant_immediate_box_reward"),
		_get_callback(callbacks, "enter_plaza")
	)
	(owner as Node).add_child(scene)
	return scene


static func free_scene(scene: Control) -> void:
	if scene != null and is_instance_valid(scene):
		StageClearResultConfigSceneHandler.clear_runtime_references(scene)
		scene.queue_free()


static func free_screen_result_scene(screen: Object) -> void:
	if screen == null:
		return
	free_scene(_get_screen_control(screen, "_scene_node"))
	screen.set("_scene_node", null)


static func _get_callback(callbacks: Dictionary, key: String) -> Callable:
	var value: Variant = callbacks.get(key, Callable())
	return value if value is Callable else Callable()


static func _get_screen_control(screen: Object, property_name: String) -> Control:
	if screen == null:
		return null
	var value: Variant = screen.get(property_name)
	if value is Control and is_instance_valid(value):
		return value as Control
	return null
