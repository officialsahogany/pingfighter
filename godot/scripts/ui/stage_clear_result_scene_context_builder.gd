extends RefCounted

const StageClearResultActorSceneContextBuilder := preload("res://scripts/ui/stage_clear_result_actor_scene_context_builder.gd")
const StageClearResultInteractionState := preload("res://scripts/ui/stage_clear_result_interaction_state.gd")
const StageClearResultRuntimeOverlaySceneHandler := preload("res://scripts/ui/stage_clear_result_runtime_overlay_scene_handler.gd")
const StageClearResultScrollState := preload("res://scripts/ui/stage_clear_result_scroll_state.gd")
const StageClearResultSummaryBuilder := preload("res://scripts/ui/stage_clear_result_summary_builder.gd")
const StageClearResultViewportSceneHandler := preload("res://scripts/ui/stage_clear_result_viewport_scene_handler.gd")


static func build_scene_context(scene: Object, dalji_dialogue: String) -> Dictionary:
	var control: Control = scene as Control
	var view_size: Vector2 = StageClearResultViewportSceneHandler.get_current_view_size(control)
	var layout_scale: float = StageClearResultViewportSceneHandler.get_layout_scale(view_size)
	var boxes: Array = _get_object_array(scene, "_boxes")

	var context: Dictionary = {
		"view_size": view_size,
		"layout_scale": layout_scale,
		"boxes": boxes,
		"current_stage": scene.get("current_stage"),
	}
	context.merge(_get_reward_scene_context(scene, boxes), true)
	context.merge(_get_scroll_scene_context(scene, layout_scale), true)
	context.merge(_get_scene_control_scene_context(scene), true)
	context.merge(StageClearResultActorSceneContextBuilder.build_actor_scene_context(scene, dalji_dialogue), true)
	return context


static func _get_reward_scene_context(scene: Object, boxes: Array) -> Dictionary:
	var reward_summary_state: Dictionary = StageClearResultSummaryBuilder.build_result_summary_state(
		_get_object_dictionary(scene, "stage_reward_snapshot"),
		boxes
	)
	return {
		"box_counts": StageClearResultInteractionState.get_box_state_counts(boxes),
		"reward_summary_state": reward_summary_state,
		"perk_info": StageClearResultSummaryBuilder.build_perk_info_summary_from_reward_state(
			reward_summary_state,
			scene.get("_perk_catalog")
		),
		"hovered_box_index": scene.get("_hovered_box_index"),
	}


static func _get_scroll_scene_context(scene: Object, layout_scale: float) -> Dictionary:
	var scroll_position_offset: Vector2 = _get_object_vector2(scene, "_scroll_position_offset")
	return {
		"scroll_phase": scene.get("_scroll_phase"),
		"scroll_timer": scene.get("_scroll_timer"),
		"scroll_unfurl_duration": StageClearResultScrollState.SCROLL_UNFURL_DURATION,
		"scroll_texture_loaded": scene.get("_scroll_texture") != null,
		"scroll_rect": StageClearResultScrollState.get_region_full_rect(layout_scale, scroll_position_offset),
		"scroll_position_offset": scroll_position_offset,
		"scroll_dragging": scene.get("_scroll_dragging"),
	}


static func _get_scene_control_scene_context(scene: Object) -> Dictionary:
	var exit_callback: Callable = scene.get("exit_to_menu_callback")
	var game_audio: Object = scene.get("_game_audio")
	return {
		"next_stage_button_rect": _get_object_rect2(scene, "_next_stage_button_rect"),
		"plaza_button_rect": _get_object_rect2(scene, "_plaza_button_rect"),
		"exit_button_rect": _get_object_rect2(scene, "_exit_button_rect"),
		"hovered_button": scene.get("_hovered_button"),
		"scene_timer": scene.get("timer"),
		"exit_callback_bound": exit_callback.is_valid(),
		"starpoint_choice_gate_active": scene.get("_starpoint_choice_gate_active"),
		"starpoint_choice_gate_box_index": scene.get("_starpoint_choice_gate_box_index"),
		"runtime_perk_choice_active": StageClearResultRuntimeOverlaySceneHandler.is_runtime_perk_choice_active(scene),
		"treasure_hunt_effect_active": StageClearResultRuntimeOverlaySceneHandler.is_treasure_hunt_effect_active(scene),
		"box_open_audio_ready": game_audio != null and game_audio.has_method("play_result_box_open"),
	}


static func _get_object_array(source: Object, key: String) -> Array:
	var value: Variant = source.get(key)
	if value is Array:
		return value
	return []


static func _get_object_dictionary(source: Object, key: String) -> Dictionary:
	var value: Variant = source.get(key)
	if value is Dictionary:
		return value
	return {}


static func _get_object_rect2(source: Object, key: String) -> Rect2:
	var value: Variant = source.get(key)
	if value is Rect2:
		return value
	return Rect2()


static func _get_object_vector2(source: Object, key: String) -> Vector2:
	return _get_vector2(source.get(key))


static func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO
