extends RefCounted

const StageClearResultBoxData := preload("res://scripts/ui/stage_clear_result_box_data.gd")
const StageClearResultScrollState := preload("res://scripts/ui/stage_clear_result_scroll_state.gd")


static func build_non_actor_status(context: Dictionary) -> Dictionary:
	var boxes: Array = _get_array(context, "boxes")
	var box_counts: Dictionary = _get_dictionary(context, "box_counts")
	var reward_summary_state: Dictionary = _get_dictionary(context, "reward_summary_state")
	var scroll_phase: String = str(context.get("scroll_phase", "hidden"))

	var status: Dictionary = {}
	status.merge(_get_reward_status(context, boxes, box_counts, reward_summary_state), true)
	status.merge(_get_scroll_status(context, scroll_phase), true)
	status.merge(_get_scene_control_status(context, scroll_phase), true)
	return status


static func _get_reward_status(
	context: Dictionary,
	boxes: Array,
	box_counts: Dictionary,
	reward_summary_state: Dictionary
) -> Dictionary:
	var opened_count: int = int(box_counts.get("opened_count", 0))
	var opening_count: int = int(box_counts.get("opening_count", 0))
	return {
		"box_count": boxes.size(),
		"opened_count": opened_count,
		"opening_count": opening_count,
		"item_reward_count": int(reward_summary_state.get("item_reward_count", 0)),
		"perk_reward_count": int(reward_summary_state.get("perk_reward_count", 0)),
		"stage_active_item_count": int(reward_summary_state.get("stage_active_item_count", 0)),
		"stage_passive_item_count": int(reward_summary_state.get("stage_passive_item_count", 0)),
		"stage_perk_count": int(reward_summary_state.get("stage_perk_count", 0)),
		"item_reward_source_counts": reward_summary_state.get("item_reward_source_counts", {}),
		"perk_reward_source_counts": reward_summary_state.get("perk_reward_source_counts", {}),
		"visible_reward_source_counts": reward_summary_state.get("visible_reward_source_counts", {}),
		"box_display_labels": StageClearResultBoxData.get_box_display_labels(boxes),
		"perk_info": context.get("perk_info", {}),
		"starpoint_total": int(reward_summary_state.get("starpoint_total", 0)),
		"hovered_box_index": int(context.get("hovered_box_index", -1)),
		"all_boxes_opened": boxes.size() > 0 and opened_count == boxes.size(),
	}


static func _get_scroll_status(context: Dictionary, scroll_phase: String) -> Dictionary:
	return {
		"scroll_phase": scroll_phase,
		"scroll_unfurl_progress": StageClearResultScrollState.get_unfurl_progress(
			scroll_phase,
			float(context.get("scroll_timer", 0.0)),
			float(context.get("scroll_unfurl_duration", 0.0))
		),
		"scroll_visible": scroll_phase == "unfurling" or scroll_phase == "visible",
		"scroll_texture_loaded": bool(context.get("scroll_texture_loaded", false)),
		"scroll_rect": context.get("scroll_rect", Rect2()),
		"scroll_position_offset": context.get("scroll_position_offset", Vector2.ZERO),
		"scroll_dragging": bool(context.get("scroll_dragging", false)),
	}


static func _get_scene_control_status(context: Dictionary, scroll_phase: String) -> Dictionary:
	return {
		"next_stage_button_rect": context.get("next_stage_button_rect", Rect2()),
		"plaza_button_rect": context.get("plaza_button_rect", Rect2()),
		"exit_button_rect": context.get("exit_button_rect", Rect2()),
		"buttons_clickable": scroll_phase == "visible",
		"hovered_button": str(context.get("hovered_button", "")),
		"scene_timer": float(context.get("scene_timer", 0.0)),
		"exit_callback_bound": bool(context.get("exit_callback_bound", false)),
		"starpoint_choice_gate_active": bool(context.get("starpoint_choice_gate_active", false)),
		"starpoint_choice_gate_box_index": int(context.get("starpoint_choice_gate_box_index", -1)),
		"runtime_perk_choice_active": bool(context.get("runtime_perk_choice_active", false)),
		"treasure_hunt_effect_active": bool(context.get("treasure_hunt_effect_active", false)),
		"box_open_audio_ready": bool(context.get("box_open_audio_ready", false)),
	}


static func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


static func _get_array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	if value is Array:
		return value
	return []
