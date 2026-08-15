extends RefCounted

const StageClearResultUpdateSceneHandler := preload("res://scripts/ui/stage_clear_result_update_scene_handler.gd")
const StageClearResultUpdateScreenContextData := preload("res://scripts/core/stage_clear_result_update_screen_context_data.gd")


func update_screen_flow_from_screen(
	screen: Object,
	delta: float,
	starpoint_choice_reward_delay: float
) -> void:
	if screen == null or not StageClearResultUpdateScreenContextData.is_screen_active(screen):
		return
	var plaza_scene_handler: Object = StageClearResultUpdateScreenContextData.get_plaza_scene_handler(screen)
	if plaza_scene_handler != null and plaza_scene_handler.has_method("update"):
		plaza_scene_handler.update(delta)
	if StageClearResultUpdateScreenContextData.has_plaza_scene(plaza_scene_handler):
		return
	if plaza_scene_handler != null and plaza_scene_handler.has_method("is_entry_transition_active") and bool(plaza_scene_handler.is_entry_transition_active()):
		return
	if StageClearResultUpdateScreenContextData.is_spawn_pending(screen):
		var spawn_pending: bool = StageClearResultUpdateScreenContextData.update_pending_scene_spawn_from_screen(
			screen,
			starpoint_choice_reward_delay
		)
		screen.set("_spawn_pending", spawn_pending)
		if spawn_pending or not StageClearResultUpdateScreenContextData.screen_has_result_scene(screen):
			return
	if not StageClearResultUpdateScreenContextData.screen_has_result_scene(screen):
		return
	update_result_flow_from_screen(screen, delta)


func update_result_flow(
	delta: float,
	scene: Control,
	current_stage: int,
	owner: Object,
	registry: Object,
	selected_character_type: String,
	plaza_scene_handler: Object,
	mythic_acquisition_handler: Object,
	starpoint_choice_handler: Object
) -> void:
	if scene == null or not is_instance_valid(scene):
		return
	scene.visible = true
	StageClearResultUpdateSceneHandler.update_result_scene(scene, delta)
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_acquisition_handler != null and mythic_acquisition_handler.has_method("update_cinematic"):
		mythic_acquisition_handler.update_cinematic(delta, mythic_item_runtime, owner, registry)
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if starpoint_choice_handler == null:
		return
	if starpoint_choice_handler.has_method("update_runtime_choice"):
		starpoint_choice_handler.update_runtime_choice(
			delta,
			scene,
			runtime_perk_state,
			owner,
			registry
		)
	if starpoint_choice_handler.has_method("update_pending_choice"):
		starpoint_choice_handler.update_pending_choice(
			delta,
			scene,
			runtime_perk_state,
			_get_instance(registry, "runtime_perk_catalog"),
			selected_character_type,
			owner,
			registry,
			_get_instance(registry, "game_audio")
		)


func update_result_flow_from_screen(screen: Object, delta: float) -> void:
	var context: Dictionary = StageClearResultUpdateScreenContextData.build_result_flow_context(screen)
	if context.is_empty():
		return
	update_result_flow(
		delta,
		context.get("scene", null) as Control,
		int(context.get("current_stage", 1)),
		context.get("owner", null) as Object,
		context.get("registry", null) as Object,
		str(context.get("selected_character_type", "smasher")),
		context.get("plaza_scene_handler", null) as Object,
		context.get("mythic_acquisition_handler", null) as Object,
		context.get("starpoint_choice_handler", null) as Object
	)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var instance: Variant = registry.get_instance(key)
	return instance if instance is Object else null
