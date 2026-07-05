extends RefCounted


static func prewarm_scene_shell(scene_shell_handler: Object) -> Dictionary:
	var ready := false
	if scene_shell_handler != null and scene_shell_handler.has_method("prewarm_scene_shell"):
		ready = bool(scene_shell_handler.prewarm_scene_shell())
	return {
		"ready": ready,
		"status": get_prewarm_status(scene_shell_handler),
	}


static func prewarm_assets_step(
	scene_shell_handler: Object,
	selected_character_type: String,
	stage_id: int,
	use_threaded_texture_loads: bool
) -> Dictionary:
	var done := false
	if scene_shell_handler != null and scene_shell_handler.has_method("prewarm_assets_step"):
		done = bool(scene_shell_handler.prewarm_assets_step(
			selected_character_type,
			stage_id,
			use_threaded_texture_loads
		))
	return {
		"done": done,
		"status": get_prewarm_status(scene_shell_handler),
	}


static func are_assets_ready_for_spawn(
	scene_shell_handler: Object,
	selected_character_type: String,
	stage_id: int
) -> bool:
	if scene_shell_handler == null or not scene_shell_handler.has_method("are_assets_ready_for_spawn"):
		return false
	return bool(scene_shell_handler.are_assets_ready_for_spawn(selected_character_type, stage_id))


static func get_required_scene_asset_keys(scene_shell_handler: Object, stage_id: int) -> Array[String]:
	if scene_shell_handler == null or not scene_shell_handler.has_method("get_required_scene_asset_keys"):
		return []
	var keys: Variant = scene_shell_handler.get_required_scene_asset_keys(stage_id)
	if not (keys is Array):
		return []
	var typed_keys: Array[String] = []
	for key in keys:
		typed_keys.append(str(key))
	return typed_keys


static func get_prewarm_status(scene_shell_handler: Object) -> Dictionary:
	if scene_shell_handler == null or not scene_shell_handler.has_method("get_prewarm_status"):
		return {}
	var status_value: Variant = scene_shell_handler.get_prewarm_status()
	return status_value.duplicate(true) if status_value is Dictionary else {}
