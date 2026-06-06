extends RefCounted

const StageClearResultActorDrawHelper := preload("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")


static func get_config_reset_state() -> Dictionary:
	return {
		"lid_open_counter": 0,
		"starpoint_choice_gate_active": false,
		"starpoint_choice_gate_box_index": -1,
		"hovered_box_index": -1,
		"hovered_button": "none",
		"next_stage_button_rect": Rect2(),
		"exit_button_rect": Rect2(),
		"scroll_phase": "hidden",
		"scroll_timer": 0.0,
		"scroll_position_offset": Vector2.ZERO,
		"scroll_dragging": false,
		"scroll_drag_grab_offset": Vector2.ZERO,
		"timer": 0.0,
		"dalji_base_timer": 0.0,
		"dalji_click_reaction_timer": StageClearResultActorDrawHelper.DALJI_CLICK_TOTAL_DURATION,
		"player_victory_click_reaction_timer": StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_TOTAL_DURATION,
		"stage2_boss_defeat_click_reaction_timer": StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		"stage3_boss_defeat_click_reaction_timer": StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		"dalji_dialogue_timer": 0.0,
	}


# Single source of truth: coerce each reset/current field and emit it under the
# scene's real member name. Folding the prior two-tier apply_result/scene_apply
# pair into one map keeps the type coercion + field-naming from drifting apart.
static func get_config_reset_scene_apply_result(reset_state: Dictionary, current_state: Dictionary) -> Dictionary:
	return {
		"field_payload": {
			"_lid_open_counter": int(reset_state.get("lid_open_counter", current_state.get("lid_open_counter", 0))),
			"_starpoint_choice_gate_active": bool(reset_state.get("starpoint_choice_gate_active", current_state.get("starpoint_choice_gate_active", false))),
			"_starpoint_choice_gate_box_index": int(reset_state.get("starpoint_choice_gate_box_index", current_state.get("starpoint_choice_gate_box_index", -1))),
			"_hovered_box_index": int(reset_state.get("hovered_box_index", current_state.get("hovered_box_index", -1))),
			"_hovered_button": str(reset_state.get("hovered_button", current_state.get("hovered_button", "none"))),
			"_next_stage_button_rect": _rect_value(reset_state, current_state, "next_stage_button_rect"),
			"_exit_button_rect": _rect_value(reset_state, current_state, "exit_button_rect"),
			"_scroll_phase": str(reset_state.get("scroll_phase", current_state.get("scroll_phase", "hidden"))),
			"_scroll_timer": float(reset_state.get("scroll_timer", current_state.get("scroll_timer", 0.0))),
			"_scroll_position_offset": _vector2_value(reset_state, current_state, "scroll_position_offset"),
			"_scroll_dragging": bool(reset_state.get("scroll_dragging", current_state.get("scroll_dragging", false))),
			"_scroll_drag_grab_offset": _vector2_value(reset_state, current_state, "scroll_drag_grab_offset"),
			"timer": float(reset_state.get("timer", current_state.get("timer", 0.0))),
			"_dalji_base_timer": float(reset_state.get("dalji_base_timer", current_state.get("dalji_base_timer", 0.0))),
			"_dalji_click_reaction_timer": float(reset_state.get("dalji_click_reaction_timer", current_state.get("dalji_click_reaction_timer", StageClearResultActorDrawHelper.DALJI_CLICK_TOTAL_DURATION))),
			"_player_victory_click_reaction_timer": float(reset_state.get("player_victory_click_reaction_timer", current_state.get("player_victory_click_reaction_timer", StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_TOTAL_DURATION))),
			"_stage2_boss_defeat_click_reaction_timer": float(reset_state.get("stage2_boss_defeat_click_reaction_timer", current_state.get("stage2_boss_defeat_click_reaction_timer", StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION))),
			"_stage3_boss_defeat_click_reaction_timer": float(reset_state.get("stage3_boss_defeat_click_reaction_timer", current_state.get("stage3_boss_defeat_click_reaction_timer", StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION))),
			"_dalji_dialogue_timer": float(reset_state.get("dalji_dialogue_timer", current_state.get("dalji_dialogue_timer", 0.0))),
		},
	}


static func _rect_value(reset_state: Dictionary, current_state: Dictionary, key: String) -> Rect2:
	var current_value: Variant = current_state.get(key, Rect2())
	if not current_value is Rect2:
		current_value = Rect2()
	var value: Variant = reset_state.get(key, current_value)
	if value is Rect2:
		return value
	return current_value


static func _vector2_value(reset_state: Dictionary, current_state: Dictionary, key: String) -> Vector2:
	var current_value: Variant = current_state.get(key, Vector2.ZERO)
	if not current_value is Vector2:
		current_value = Vector2.ZERO
	var value: Variant = reset_state.get(key, current_value)
	if value is Vector2:
		return value
	return current_value
