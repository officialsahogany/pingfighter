extends RefCounted

const StageClearResultActorDrawHelper := preload("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")


static func get_reaction_timer_reset_value(apply_key: String) -> float:
	for config: Dictionary in _get_reaction_timer_reset_configs():
		if String(config.get("apply_key", "")) == apply_key:
			return float(config.get("reset_value", 0.0))
	return 0.0


static func get_config_reset_state() -> Dictionary:
	var reset_state: Dictionary = {
		"lid_open_counter": 0,
		"starpoint_choice_gate_active": false,
		"starpoint_choice_gate_box_index": -1,
		"hovered_box_index": -1,
		"hovered_button": "none",
		"next_stage_button_rect": Rect2(),
		"plaza_button_rect": Rect2(),
		"exit_button_rect": Rect2(),
		"scroll_phase": "hidden",
		"scroll_timer": 0.0,
		"scroll_position_offset": Vector2.ZERO,
		"scroll_dragging": false,
		"scroll_drag_grab_offset": Vector2.ZERO,
		"timer": 0.0,
		"dalji_base_timer": 0.0,
		"dalji_dialogue_timer": 0.0,
	}
	for config: Dictionary in _get_reaction_timer_reset_configs():
		reset_state[String(config.get("apply_key", ""))] = float(config.get("reset_value", 0.0))
	return reset_state


# Single source of truth: coerce each reset/current field and emit it under the
# scene's real member name. Folding the prior two-tier apply_result/scene_apply
# pair into one map keeps the type coercion + field-naming from drifting apart.
static func get_config_reset_scene_apply_result(reset_state: Dictionary, current_state: Dictionary) -> Dictionary:
	var field_payload: Dictionary = {
		"_lid_open_counter": int(reset_state.get("lid_open_counter", current_state.get("lid_open_counter", 0))),
		"_starpoint_choice_gate_active": bool(reset_state.get("starpoint_choice_gate_active", current_state.get("starpoint_choice_gate_active", false))),
		"_starpoint_choice_gate_box_index": int(reset_state.get("starpoint_choice_gate_box_index", current_state.get("starpoint_choice_gate_box_index", -1))),
		"_hovered_box_index": int(reset_state.get("hovered_box_index", current_state.get("hovered_box_index", -1))),
		"_hovered_button": str(reset_state.get("hovered_button", current_state.get("hovered_button", "none"))),
		"_next_stage_button_rect": _rect_value(reset_state, current_state, "next_stage_button_rect"),
		"_plaza_button_rect": _rect_value(reset_state, current_state, "plaza_button_rect"),
		"_exit_button_rect": _rect_value(reset_state, current_state, "exit_button_rect"),
		"_scroll_phase": str(reset_state.get("scroll_phase", current_state.get("scroll_phase", "hidden"))),
		"_scroll_timer": float(reset_state.get("scroll_timer", current_state.get("scroll_timer", 0.0))),
		"_scroll_position_offset": _vector2_value(reset_state, current_state, "scroll_position_offset"),
		"_scroll_dragging": bool(reset_state.get("scroll_dragging", current_state.get("scroll_dragging", false))),
		"_scroll_drag_grab_offset": _vector2_value(reset_state, current_state, "scroll_drag_grab_offset"),
		"timer": float(reset_state.get("timer", current_state.get("timer", 0.0))),
		"_dalji_base_timer": float(reset_state.get("dalji_base_timer", current_state.get("dalji_base_timer", 0.0))),
		"_dalji_dialogue_timer": float(reset_state.get("dalji_dialogue_timer", current_state.get("dalji_dialogue_timer", 0.0))),
	}
	for config: Dictionary in _get_reaction_timer_reset_configs():
		var apply_key: String = String(config.get("apply_key", ""))
		var field_key: String = String(config.get("field_key", ""))
		var reset_value: float = float(config.get("reset_value", 0.0))
		field_payload[field_key] = float(reset_state.get(apply_key, current_state.get(apply_key, reset_value)))
	return {
		"field_payload": field_payload,
	}


static func _get_reaction_timer_reset_configs() -> Array[Dictionary]:
	return [
		{
			"apply_key": "dalji_click_reaction_timer",
			"field_key": "_dalji_click_reaction_timer",
			"reset_value": StageClearResultActorDrawHelper.DALJI_CLICK_TOTAL_DURATION,
		},
		{
			"apply_key": "player_victory_click_reaction_timer",
			"field_key": "_player_victory_click_reaction_timer",
			"reset_value": StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_TOTAL_DURATION,
		},
		{
			"apply_key": "stage2_boss_defeat_click_reaction_timer",
			"field_key": "_stage2_boss_defeat_click_reaction_timer",
			"reset_value": StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		},
		{
			"apply_key": "stage3_boss_defeat_click_reaction_timer",
			"field_key": "_stage3_boss_defeat_click_reaction_timer",
			"reset_value": StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		},
		{
			"apply_key": "stage4_ponk_boss_defeat_click_reaction_timer",
			"field_key": "_stage4_ponk_boss_defeat_click_reaction_timer",
			"reset_value": StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		},
		{
			"apply_key": "stage5_hongryun_result_click_reaction_timer",
			"field_key": "_stage5_hongryun_result_click_reaction_timer",
			"reset_value": StageClearResultActorDrawHelper.STAGE5_HONGRYUN_CLICK_TOTAL_DURATION,
		},
		{
			"apply_key": "stage6_boss_defeat_click_reaction_timer",
			"field_key": "_stage6_boss_defeat_click_reaction_timer",
			"reset_value": StageClearResultActorDrawHelper.STAGE6_TETRISER_CLICK_TOTAL_DURATION,
		},
		{
			"apply_key": "stage7_boss_defeat_click_reaction_timer",
			"field_key": "_stage7_boss_defeat_click_reaction_timer",
			"reset_value": StageClearResultActorDrawHelper.STAGE7_AKAMU_CLICK_TOTAL_DURATION,
		},
	]


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
