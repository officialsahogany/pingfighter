extends RefCounted

const StageClearResultActorReactionUpdateHandler := preload("res://scripts/ui/stage_clear_result_actor_reaction_update_handler.gd")
const StageClearResultBoxSceneHandler := preload("res://scripts/ui/stage_clear_result_box_scene_handler.gd")
const StageClearResultFieldApplySceneHandler := preload("res://scripts/ui/stage_clear_result_field_apply_scene_handler.gd")
const StageClearResultFxHostUpdateHandler := preload("res://scripts/ui/stage_clear_result_fx_host_update_handler.gd")
const StageClearResultScrollSceneHandler := preload("res://scripts/ui/stage_clear_result_scroll_scene_handler.gd")
const StageClearResultViewportSceneHandler := preload("res://scripts/ui/stage_clear_result_viewport_scene_handler.gd")


static func update_result_scene(scene: Control, delta: float) -> void:
	if scene == null:
		return
	var safe_delta: float = max(0.0, delta)
	scene.set("timer", _get_scene_float(scene, &"timer") + safe_delta)
	apply_actor_reaction_timer_update(
		scene,
		StageClearResultActorReactionUpdateHandler.update_actor_reaction_timers(
			get_actor_reaction_timer_context(scene),
			safe_delta
		)
	)
	StageClearResultBoxSceneHandler.update_boxes(scene, safe_delta)
	StageClearResultScrollSceneHandler.update_scroll(scene, safe_delta)
	StageClearResultViewportSceneHandler.sync_control_to_viewport(scene)
	StageClearResultFxHostUpdateHandler.update_fx_hosts(
		_get_scene_object(scene, &"_fx_host_pool"),
		scene,
		_get_scene_array(scene, &"_boxes"),
		StageClearResultViewportSceneHandler.get_layout_scale(scene.size),
		_get_scene_float(scene, &"timer"),
		_get_scene_string(scene, &"_scroll_phase", "hidden"),
		_get_scene_float(scene, &"_scroll_timer")
	)
	scene.queue_redraw()


static func get_actor_reaction_timer_context(scene: Object) -> Dictionary:
	return StageClearResultActorReactionUpdateHandler.get_actor_reaction_timer_context(
		_get_scene_float(scene, &"_dalji_base_timer"),
		_get_scene_float(scene, &"_dalji_click_reaction_timer"),
		_get_scene_float(scene, &"_player_victory_click_reaction_timer"),
		_get_scene_float(scene, &"_stage2_boss_defeat_click_reaction_timer"),
		_get_scene_float(scene, &"_stage3_boss_defeat_click_reaction_timer"),
		_get_scene_float(scene, &"_dalji_dialogue_timer"),
		_get_scene_float(scene, &"_stage6_boss_defeat_click_reaction_timer"),
		_get_scene_float(scene, &"_stage4_ponk_boss_defeat_click_reaction_timer"),
		_get_scene_float(scene, &"_stage5_hongryun_result_click_reaction_timer")
	)


static func apply_actor_reaction_timer_update(scene: Object, result: Dictionary) -> void:
	_apply_scene_apply_result(scene, StageClearResultActorReactionUpdateHandler.get_actor_reaction_timer_scene_apply_result(
		result,
		get_actor_reaction_timer_context(scene)
	))


static func _apply_scene_apply_result(scene: Object, apply_result: Dictionary) -> void:
	StageClearResultFieldApplySceneHandler.apply_scene_apply_result(scene, apply_result)


static func _get_scene_array(scene: Object, field_name: StringName) -> Array:
	if scene == null:
		return []
	var value: Variant = scene.get(field_name)
	return value if value is Array else []


static func _get_scene_float(scene: Object, field_name: StringName, fallback: float = 0.0) -> float:
	if scene == null:
		return fallback
	var value: Variant = scene.get(field_name)
	return fallback if value == null else float(value)


static func _get_scene_object(scene: Object, field_name: StringName) -> Object:
	if scene == null:
		return null
	var value: Variant = scene.get(field_name)
	return value if value is Object else null


static func _get_scene_string(scene: Object, field_name: StringName, fallback: String) -> String:
	if scene == null:
		return fallback
	var value: Variant = scene.get(field_name)
	return fallback if value == null else str(value)
