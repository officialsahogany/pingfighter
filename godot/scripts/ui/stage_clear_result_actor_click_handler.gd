extends RefCounted

const StageClearResultActorDrawHelper := preload("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")


static func handle_player_victory_click(
	mouse_position: Vector2,
	view_size: Vector2,
	draw_scale: float,
	reaction_timer: float,
	base_timer: float
) -> Dictionary:
	return _build_attempt_result(StageClearResultActorDrawHelper.get_player_victory_click_attempt(
		mouse_position,
		view_size,
		draw_scale,
		reaction_timer,
		base_timer
	))


static func handle_dalji_click(
	current_stage: int,
	mouse_position: Vector2,
	view_size: Vector2,
	draw_scale: float,
	reaction_timer: float,
	base_timer: float
) -> Dictionary:
	if current_stage != 1:
		return _empty_result()
	var result: Dictionary = _build_attempt_result(StageClearResultActorDrawHelper.get_dalji_click_attempt(
		mouse_position,
		view_size,
		draw_scale,
		reaction_timer,
		base_timer
	))
	result["show_dialogue"] = bool(result.get("handled", false))
	result["play_voice"] = bool(result.get("handled", false))
	return result


static func handle_boss_defeat_click(
	stage_id: int,
	has_reaction_sheet: bool,
	mouse_position: Vector2,
	view_size: Vector2,
	draw_scale: float,
	reaction_timer: float,
	base_timer: float
) -> Dictionary:
	if not has_reaction_sheet or (stage_id != 2 and stage_id != 3 and stage_id != 4 and stage_id != 5 and stage_id != 6):
		return _empty_result()
	if stage_id == 5:
		return _build_attempt_result(StageClearResultActorDrawHelper.get_stage5_hongryun_click_attempt(
			mouse_position,
			view_size,
			draw_scale,
			reaction_timer,
			base_timer
		))
	if stage_id == 6:
		return _build_attempt_result(StageClearResultActorDrawHelper.get_stage6_tetriser_click_attempt(
			mouse_position,
			view_size,
			draw_scale,
			reaction_timer,
			base_timer
		))
	return _build_attempt_result(StageClearResultActorDrawHelper.get_boss_defeat_click_attempt(
		stage_id,
		mouse_position,
		view_size,
		draw_scale,
		reaction_timer,
		base_timer
	))


static func get_boss_result_click_config(stage_id: int) -> Dictionary:
	match stage_id:
		2:
			return {
				"sheet_property": &"_stage2_boss_defeat_click_reaction_sheet",
				"transition_base_frame_property": &"_stage2_boss_defeat_click_transition_base_frame",
				"reaction_timer_property": &"_stage2_boss_defeat_click_reaction_timer",
			}
		3:
			return {
				"sheet_property": &"_stage3_boss_defeat_click_reaction_sheet",
				"transition_base_frame_property": &"_stage3_boss_defeat_click_transition_base_frame",
				"reaction_timer_property": &"_stage3_boss_defeat_click_reaction_timer",
			}
		4:
			return {
				"sheet_property": &"_stage4_ponk_boss_defeat_click_reaction_sheet",
				"transition_base_frame_property": &"_stage4_ponk_boss_defeat_click_transition_base_frame",
				"reaction_timer_property": &"_stage4_ponk_boss_defeat_click_reaction_timer",
			}
		5:
			return {
				"sheet_property": &"_stage5_hongryun_result_sheet",
				"transition_base_frame_property": &"_stage5_hongryun_result_click_transition_base_frame",
				"reaction_timer_property": &"_stage5_hongryun_result_click_reaction_timer",
			}
		6:
			return {
				"sheet_property": &"_stage6_boss_defeat_sheet",
				"transition_base_frame_property": &"_stage6_boss_defeat_click_transition_base_frame",
				"reaction_timer_property": &"_stage6_boss_defeat_click_reaction_timer",
			}
	return {}


static func get_stage_result_fallback_click_config(stage_id: int) -> Dictionary:
	if stage_id != 5 and stage_id != 6:
		return {}
	return get_boss_result_click_config(stage_id)


static func get_click_reaction_apply_result(
	click_result: Dictionary,
	current_transition_base_frame: int,
	current_reaction_timer: float
) -> Dictionary:
	if not bool(click_result.get("handled", false)):
		return {
			"handled": false,
			"started": false,
			"transition_base_frame": current_transition_base_frame,
			"reaction_timer": current_reaction_timer,
			"redraw": false,
		}
	if not bool(click_result.get("started", false)):
		return {
			"handled": true,
			"started": false,
			"transition_base_frame": current_transition_base_frame,
			"reaction_timer": current_reaction_timer,
			"redraw": true,
		}
	return {
		"handled": true,
		"started": true,
		"transition_base_frame": int(click_result.get("transition_base_frame", current_transition_base_frame)),
		"reaction_timer": float(click_result.get("reaction_timer", current_reaction_timer)),
		"redraw": true,
	}


static func get_click_reaction_scene_apply_result(
	click_result: Dictionary,
	transition_base_frame_property: StringName,
	current_transition_base_frame: int,
	reaction_timer_property: StringName,
	current_reaction_timer: float
) -> Dictionary:
	var apply_result: Dictionary = get_click_reaction_apply_result(
		click_result,
		current_transition_base_frame,
		current_reaction_timer
	)
	var field_payload: Dictionary = {}
	if bool(apply_result.get("handled", false)):
		field_payload[str(transition_base_frame_property)] = int(apply_result.get("transition_base_frame", current_transition_base_frame))
		field_payload[str(reaction_timer_property)] = float(apply_result.get("reaction_timer", current_reaction_timer))
	return {
		"handled": bool(apply_result.get("handled", false)),
		"started": bool(apply_result.get("started", false)),
		"field_payload": field_payload,
		"redraw": bool(apply_result.get("redraw", false)),
	}


static func get_player_victory_click_rect_apply_result(click_result: Dictionary) -> Dictionary:
	return {
		"player_victory_click_rect": click_result.get("click_rect", Rect2()),
	}


static func get_player_victory_click_rect_scene_apply_result(click_result: Dictionary) -> Dictionary:
	var apply_result: Dictionary = get_player_victory_click_rect_apply_result(click_result)
	return {
		"field_payload": {
			"_player_victory_click_rect": apply_result.get("player_victory_click_rect", Rect2()),
		},
	}


static func get_dalji_click_rect_apply_result(click_result: Dictionary) -> Dictionary:
	return {
		"dalji_click_rect": click_result.get("click_rect", Rect2()),
	}


static func get_dalji_click_rect_scene_apply_result(click_result: Dictionary) -> Dictionary:
	var apply_result: Dictionary = get_dalji_click_rect_apply_result(click_result)
	return {
		"field_payload": {
			"_dalji_click_rect": apply_result.get("dalji_click_rect", Rect2()),
		},
	}


static func get_dalji_click_side_effect_apply_result(
	click_result: Dictionary,
	current_dialogue_timer: float,
	dialogue_duration: float
) -> Dictionary:
	var show_dialogue: bool = bool(click_result.get("show_dialogue", false))
	return {
		"dalji_dialogue_timer": dialogue_duration if show_dialogue else current_dialogue_timer,
		"play_voice": bool(click_result.get("play_voice", false)),
	}


static func get_dalji_click_side_effect_scene_apply_result(
	click_result: Dictionary,
	current_dialogue_timer: float,
	dialogue_duration: float
) -> Dictionary:
	var apply_result: Dictionary = get_dalji_click_side_effect_apply_result(
		click_result,
		current_dialogue_timer,
		dialogue_duration
	)
	return {
		"field_payload": {
			"_dalji_dialogue_timer": float(apply_result.get("dalji_dialogue_timer", current_dialogue_timer)),
		},
		"play_voice": bool(apply_result.get("play_voice", false)),
	}


static func _build_attempt_result(click_data: Dictionary) -> Dictionary:
	var attempt_value: Variant = click_data.get("attempt", {})
	var attempt: Dictionary = attempt_value if attempt_value is Dictionary else {}
	return {
		"handled": bool(attempt.get("handled", false)),
		"started": bool(attempt.get("started", false)),
		"click_rect": click_data.get("click_rect", Rect2()),
		"transition_base_frame": int(attempt.get("transition_base_frame", 0)),
		"reaction_timer": float(attempt.get("reaction_timer", 0.0)),
	}


static func _empty_result() -> Dictionary:
	return {
		"handled": false,
		"started": false,
		"click_rect": Rect2(),
		"transition_base_frame": 0,
		"reaction_timer": 0.0,
	}
