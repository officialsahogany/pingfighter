extends SceneTree

const StageClearResultStatusBuilder := preload("res://scripts/ui/stage_clear_result_status_builder.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_status_builder_fields()
	_verify_scene_delegates_status_builder()

	if _failures.is_empty():
		print("stage_clear_result_status_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_status_builder_fields() -> void:
	var boxes := [
		{"state": "opened", "display_label": "A"},
		{"state": "opening", "display_label": "B"},
	]
	var status: Dictionary = StageClearResultStatusBuilder.build_interaction_status({
		"view_size": Vector2(1600.0, 900.0),
		"layout_scale": 1.0,
		"boxes": boxes,
		"box_counts": {"opened_count": 1, "opening_count": 1},
		"reward_summary_state": {
			"item_reward_count": 2,
			"perk_reward_count": 1,
			"stage_active_item_count": 1,
			"stage_passive_item_count": 1,
			"stage_perk_count": 1,
			"item_reward_source_counts": {"stage": 1, "box": 1},
			"perk_reward_source_counts": {"stage": 1},
			"visible_reward_source_counts": {"box": 2},
			"starpoint_total": 3,
		},
		"perk_info": {"kind": "perk"},
		"dalji_reaction_state": {
			"reaction_active": true,
			"return_blend_active": false,
			"base_frame": 7,
			"reaction_alpha": 0.4,
		},
		"player_victory_reaction_state": {
			"reaction_active": true,
			"return_blend_active": true,
			"base_frame": 11,
			"reaction_alpha": 0.8,
		},
		"stage2_boss_reaction_state": {
			"reaction_active": true,
			"return_blend_active": true,
			"base_frame": 13,
			"reaction_alpha": 0.9,
		},
		"stage3_boss_reaction_state": {
			"reaction_active": false,
			"return_blend_active": false,
			"base_frame": 17,
			"reaction_alpha": 0.1,
		},
		"current_stage": 2,
		"selected_character_type": "soldier",
		"player_victory_cell_size": Vector2(896.0, 896.0),
		"player_victory_frame_count": 98,
		"player_victory_grid_cols": 11,
		"stage2_boss_defeat_live2d_cell_size": Vector2(896.0, 896.0),
		"stage2_boss_defeat_live2d_frame_count": 98,
		"stage2_boss_defeat_live2d_grid_cols": 14,
		"stage2_boss_defeat_live2d_sheet_loaded": true,
		"stage2_boss_defeat_click_reaction_sheet_loaded": true,
		"stage3_boss_defeat_live2d_cell_size": Vector2(896.0, 896.0),
		"stage3_boss_defeat_live2d_frame_count": 98,
		"stage3_boss_defeat_live2d_grid_cols": 14,
		"scroll_phase": "visible",
		"scroll_timer": 1.0,
		"scroll_unfurl_duration": 1.0,
		"scroll_texture_loaded": true,
		"scroll_rect": Rect2(Vector2(10.0, 20.0), Vector2(300.0, 400.0)),
		"scroll_position_offset": Vector2(3.0, 4.0),
		"scroll_dragging": true,
		"next_stage_button_rect": Rect2(Vector2(12.0, 22.0), Vector2(40.0, 20.0)),
		"exit_button_rect": Rect2(Vector2(62.0, 22.0), Vector2(40.0, 20.0)),
		"hovered_button": "next_stage",
		"scene_timer": 12.5,
		"exit_callback_bound": true,
		"starpoint_choice_gate_active": true,
		"starpoint_choice_gate_box_index": 4,
		"runtime_perk_choice_active": true,
		"treasure_hunt_effect_active": false,
		"box_open_audio_ready": true,
	})

	_expect(bool(status.get("dalji_click_reaction_active", false)), "Dalji reaction state should be copied")
	_expect(int(status.get("dalji_base_frame", 0)) == 7, "Dalji base frame should come from reaction state")
	_expect(bool(status.get("stage2_boss_defeat_live2d_active", false)), "Stage 2 status should mark Stage 2 actor active")
	_expect(not bool(status.get("stage3_boss_defeat_live2d_active", true)), "Stage 2 status should keep Stage 3 actor inactive")
	_expect(int(status.get("stage2_boss_defeat_live2d_base_frame", 0)) == 13, "Stage 2 base frame should come from reaction state")
	_expect(int(status.get("player_victory_base_frame", 0)) == 11, "player victory base frame should come from reaction state")
	_expect(int(status.get("box_count", 0)) == 2, "status should expose box count")
	_expect(int(status.get("opened_count", 0)) == 1, "status should expose opened count")
	_expect(int(status.get("opening_count", 0)) == 1, "status should expose opening count")
	_expect(int(status.get("item_reward_count", 0)) == 2, "status should expose item reward count")
	_expect(int(status.get("starpoint_total", 0)) == 3, "status should expose starpoint total")
	_expect(not bool(status.get("all_boxes_opened", true)), "one opened box out of two should not be all-opened")
	_expect(bool(status.get("scroll_visible", false)), "visible scroll phase should be exposed as visible")
	_expect(bool(status.get("buttons_clickable", false)), "visible scroll phase should make buttons clickable")
	_expect(bool(status.get("scroll_texture_loaded", false)), "status should expose scroll texture load state")
	_expect(bool(status.get("scroll_dragging", false)), "status should expose drag state")
	_expect(bool(status.get("exit_callback_bound", false)), "status should expose callback binding state")
	_expect(bool(status.get("starpoint_choice_gate_active", false)), "status should expose starpoint gate state")
	_expect(bool(status.get("runtime_perk_choice_active", false)), "status should expose runtime perk gate state")
	_expect(bool(status.get("box_open_audio_ready", false)), "status should expose result box audio dependency")


func _verify_scene_delegates_status_builder() -> void:
	var scene_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_status_builder.gd")
	_expect(
		scene_source.find("StageClearResultStatusBuilder.build_interaction_status") >= 0,
		"stage-clear result scene should delegate interaction status assembly"
	)
	_expect(
		helper_source.find("\"box_open_audio_ready\"") >= 0
			and helper_source.find("\"stage2_boss_defeat_live2d_active\"") >= 0
			and helper_source.find("StageClearResultScrollState.get_unfurl_progress") >= 0,
		"status builder should own the public interaction status fields"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
