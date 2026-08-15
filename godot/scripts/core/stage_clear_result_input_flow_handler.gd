extends RefCounted

const StageClearResultInputScreenData := preload("res://scripts/core/stage_clear_result_input_screen_data.gd")
const StageClearResultInputSceneHandler := preload("res://scripts/ui/stage_clear_result_input_scene_handler.gd")


func handle_input(
	event: InputEvent,
	spawn_pending: bool,
	scene: Control,
	owner: Object,
	registry: Object,
	plaza_scene_handler: Object,
	mythic_acquisition_handler: Object,
	starpoint_choice_handler: Object,
	dalji_click_dialogue_duration: float,
	is_active: Callable,
	has_result_scene: Callable
) -> bool:
	if not _call_bool(is_active, false):
		return false
	if plaza_scene_handler != null and plaza_scene_handler.has_method("is_entry_transition_active") and bool(plaza_scene_handler.is_entry_transition_active()):
		# The opaque loading/error surface owns input until the atomic reveal or
		# explicit teardown. No result-screen click can double-submit the entry.
		return true
	if _has_plaza_scene(plaza_scene_handler):
		if plaza_scene_handler.has_method("handle_input"):
			plaza_scene_handler.handle_input(event)
		return true
	if spawn_pending or not _call_bool(has_result_scene, _is_valid_scene(scene)):
		return true
	if _handle_mythic_input(event, scene, owner, registry, mythic_acquisition_handler):
		return true
	StageClearResultInputSceneHandler.handle_result_input(
		scene,
		event,
		dalji_click_dialogue_duration
	)
	if _call_bool(is_active, false) and _call_bool(has_result_scene, _is_valid_scene(scene)):
		_sync_starpoint_choice_rewards(scene, registry, starpoint_choice_handler)
	return true


func handle_input_from_screen(screen: Object, event: InputEvent) -> bool:
	if screen == null:
		return false
	var context: Dictionary = StageClearResultInputScreenData.build_input_context_from_screen(screen)
	if context.is_empty():
		return false
	return handle_input(
		event,
		bool(context.get("spawn_pending", false)),
		context.get("scene", null) as Control,
		context.get("owner", null) as Object,
		context.get("registry", null) as Object,
		context.get("plaza_scene_handler", null) as Object,
		context.get("mythic_acquisition_handler", null) as Object,
		context.get("starpoint_choice_handler", null) as Object,
		float(context.get("dalji_click_dialogue_duration", 0.0)),
		context.get("is_active", Callable()) as Callable,
		context.get("has_result_scene", Callable()) as Callable
	)


func _handle_mythic_input(
	event: InputEvent,
	scene: Control,
	owner: Object,
	registry: Object,
	mythic_acquisition_handler: Object
) -> bool:
	if mythic_acquisition_handler == null or not mythic_acquisition_handler.has_method("handle_input"):
		return false
	return bool(mythic_acquisition_handler.handle_input(
		event,
		_get_instance(registry, "mythic_item_runtime"),
		owner,
		registry,
		scene
	))


func _sync_starpoint_choice_rewards(
	scene: Control,
	registry: Object,
	starpoint_choice_handler: Object
) -> void:
	if starpoint_choice_handler == null or not starpoint_choice_handler.has_method("sync_box_perk_choice_rewards"):
		return
	starpoint_choice_handler.sync_box_perk_choice_rewards(
		scene,
		_get_instance(registry, "runtime_perk_state")
	)


func _has_plaza_scene(plaza_scene_handler: Object) -> bool:
	return (
		plaza_scene_handler != null
		and plaza_scene_handler.has_method("has_scene")
		and bool(plaza_scene_handler.has_scene())
	)


func _call_bool(callback: Callable, fallback: bool) -> bool:
	if not callback.is_valid():
		return fallback
	return bool(callback.call())


func _is_valid_scene(scene: Object) -> bool:
	return scene != null and is_instance_valid(scene)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var instance: Variant = registry.get_instance(key)
	return instance if instance is Object else null
