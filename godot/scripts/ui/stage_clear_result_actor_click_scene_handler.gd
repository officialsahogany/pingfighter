extends RefCounted

const StageClearResultActorClickSceneApplyHandler := preload("res://scripts/ui/stage_clear_result_actor_click_scene_apply_handler.gd")
const StageClearResultAudioSceneHandler := preload("res://scripts/ui/stage_clear_result_audio_scene_handler.gd")
const StageClearResultFieldApplySceneHandler := preload("res://scripts/ui/stage_clear_result_field_apply_scene_handler.gd")
const StageClearResultViewportSceneHandler := preload("res://scripts/ui/stage_clear_result_viewport_scene_handler.gd")


static func handle_player_victory_click(scene: Control, mouse_position: Vector2) -> bool:
	if scene == null:
		return false
	var view_size: Vector2 = StageClearResultViewportSceneHandler.get_current_view_size(scene)
	var draw_scale: float = StageClearResultViewportSceneHandler.get_layout_scale(view_size)
	return apply_actor_click_scene_apply_result(
		scene,
		StageClearResultActorClickSceneApplyHandler.get_player_victory_click_scene_apply_result(
			scene,
			mouse_position,
			view_size,
			draw_scale,
			_get_scene_float(scene, &"timer")
		)
	)


static func handle_dalji_click(scene: Control, mouse_position: Vector2, dialogue_duration: float) -> bool:
	if scene == null:
		return false
	var view_size: Vector2 = StageClearResultViewportSceneHandler.get_current_view_size(scene)
	var draw_scale: float = StageClearResultViewportSceneHandler.get_layout_scale(view_size)
	return apply_actor_click_scene_apply_result(
		scene,
		StageClearResultActorClickSceneApplyHandler.get_dalji_click_scene_apply_result(
			_get_scene_int(scene, &"current_stage", 1),
			scene,
			mouse_position,
			view_size,
			draw_scale,
			_get_scene_float(scene, &"_dalji_base_timer"),
			dialogue_duration
		)
	)


static func handle_current_boss_result_click(scene: Control, mouse_position: Vector2) -> bool:
	if scene == null:
		return false
	return handle_boss_result_click(scene, _get_scene_int(scene, &"current_stage", 1), mouse_position)


static func handle_boss_result_click(scene: Control, stage_id: int, mouse_position: Vector2) -> bool:
	if scene == null:
		return false
	var view_size: Vector2 = StageClearResultViewportSceneHandler.get_current_view_size(scene)
	var draw_scale: float = StageClearResultViewportSceneHandler.get_layout_scale(view_size)
	return apply_actor_click_scene_apply_result(
		scene,
		StageClearResultActorClickSceneApplyHandler.get_boss_result_click_scene_apply_result(
			_get_scene_int(scene, &"current_stage", 1),
			stage_id,
			scene,
			mouse_position,
			view_size,
			draw_scale,
			_get_scene_float(scene, &"timer")
		)
	)


static func apply_actor_click_scene_apply_result(scene: Control, apply_result: Dictionary) -> bool:
	if scene == null:
		return false
	StageClearResultFieldApplySceneHandler.apply_scene_apply_result(scene, apply_result)
	if bool(apply_result.get("play_voice", false)):
		StageClearResultAudioSceneHandler.play_dalji_click_voice(scene)
	if not bool(apply_result.get("handled", false)):
		return false
	if bool(apply_result.get("redraw", false)):
		scene.queue_redraw()
	return true


static func _get_scene_float(scene: Object, field_name: StringName, fallback: float = 0.0) -> float:
	if scene == null:
		return fallback
	var value: Variant = scene.get(field_name)
	return fallback if value == null else float(value)


static func _get_scene_int(scene: Object, field_name: StringName, fallback: int = 0) -> int:
	if scene == null:
		return fallback
	var value: Variant = scene.get(field_name)
	return fallback if value == null else int(value)
