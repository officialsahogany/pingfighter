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
		"stage4_ponk_reaction_state": {
			"reaction_active": true,
			"return_blend_active": false,
			"base_frame": 2,
			"reaction_alpha": 0.5,
		},
		"stage5_hongryun_reaction_state": {
			"reaction_active": true,
			"return_blend_active": false,
			"base_frame": 4,
			"reaction_alpha": 0.7,
		},
		"stage6_boss_reaction_state": {
			"reaction_active": true,
			"return_blend_active": false,
			"base_frame": 3,
			"reaction_alpha": 0.6,
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
		"stage4_ponk_boss_reaction_state": {
			"reaction_active": true,
			"return_blend_active": false,
			"base_frame": 2,
			"reaction_alpha": 0.5,
		},
		"stage4_ponk_boss_defeat_live2d_cell_size": Vector2(896.0, 896.0),
		"stage4_ponk_boss_defeat_live2d_frame_count": 98,
		"stage4_ponk_boss_defeat_live2d_grid_cols": 14,
		"stage4_ponk_boss_defeat_live2d_sheet_loaded": true,
		"stage4_ponk_boss_defeat_click_reaction_sheet_loaded": true,
		"stage4_ponk_boss_defeat_click_reaction_timer": 0.12,
		"stage4_ponk_boss_defeat_click_reaction_duration": 3.528,
		"stage4_ponk_boss_defeat_click_total_duration": 3.758,
		"stage4_ponk_boss_defeat_click_transition_base_frame": 2,
		"stage5_hongryun_result_cell_size": Vector2(384.0, 384.0),
		"stage5_hongryun_result_frame_count": 8,
		"stage5_hongryun_result_grid_cols": 4,
		"stage5_hongryun_result_sheet_loaded": true,
		"stage5_hongryun_result_click_reaction_timer": 0.14,
		"stage5_hongryun_result_click_reaction_duration": 0.36,
		"stage5_hongryun_result_click_total_duration": 0.56,
		"stage5_hongryun_result_click_transition_base_frame": 4,
		"stage6_boss_defeat_cell_size": Vector2(256.0, 256.0),
		"stage6_boss_defeat_frame_count": 8,
		"stage6_boss_defeat_grid_cols": 3,
		"stage6_boss_defeat_sheet_loaded": true,
		"stage6_boss_defeat_click_reaction_timer": 0.12,
		"stage6_boss_defeat_click_reaction_duration": 0.36,
		"stage6_boss_defeat_click_total_duration": 0.56,
		"stage6_boss_defeat_click_transition_base_frame": 3,
		"scroll_phase": "visible",
		"scroll_timer": 1.0,
		"scroll_unfurl_duration": 1.0,
		"scroll_texture_loaded": true,
		"scroll_rect": Rect2(Vector2(10.0, 20.0), Vector2(300.0, 400.0)),
		"scroll_position_offset": Vector2(3.0, 4.0),
		"scroll_dragging": true,
		"next_stage_button_rect": Rect2(Vector2(12.0, 22.0), Vector2(40.0, 20.0)),
		"plaza_button_rect": Rect2(Vector2(112.0, 22.0), Vector2(40.0, 20.0)),
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
	_expect(not bool(status.get("stage4_ponk_boss_defeat_live2d_active", true)), "Stage 2 status should keep Stage 4 Ponk actor inactive")
	_expect(int(status.get("stage4_ponk_boss_defeat_live2d_base_frame", 0)) == 2, "Stage 4 Ponk base frame should come from reaction state")
	_expect(bool(status.get("stage4_ponk_boss_defeat_click_reaction_active", false)), "Stage 4 Ponk click reaction state should be copied")
	_expect(status.get("stage4_ponk_boss_defeat_click_rect", Rect2()) is Rect2, "Stage 4 Ponk click rect should be exposed")
	_expect(not bool(status.get("stage5_hongryun_result_active", true)), "Stage 2 status should keep Stage 5 Hongryun actor inactive")
	_expect(int(status.get("stage5_hongryun_result_base_frame", 0)) == 4, "Stage 5 Hongryun base frame should come from reaction state")
	_expect(bool(status.get("stage5_hongryun_result_click_reaction_active", false)), "Stage 5 Hongryun click reaction state should be copied")
	_expect(status.get("stage5_hongryun_result_click_rect", Rect2()) is Rect2, "Stage 5 Hongryun click rect should be exposed")
	_expect(not bool(status.get("stage6_boss_defeat_active", true)), "Stage 2 status should keep Stage 6 actor inactive")
	_expect(int(status.get("stage6_boss_defeat_base_frame", 0)) == 3, "Stage 6 base frame should come from reaction state")
	_expect(bool(status.get("stage6_boss_defeat_click_reaction_active", false)), "Stage 6 click reaction state should be copied")
	_expect(status.get("stage6_boss_defeat_click_rect", Rect2()) is Rect2, "Stage 6 click rect should be exposed")
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
	_expect(status.get("plaza_button_rect", Rect2()) is Rect2, "status should expose plaza button rect")
	_expect(bool(status.get("exit_callback_bound", false)), "status should expose callback binding state")
	_expect(bool(status.get("starpoint_choice_gate_active", false)), "status should expose starpoint gate state")
	_expect(bool(status.get("runtime_perk_choice_active", false)), "status should expose runtime perk gate state")
	_expect(bool(status.get("box_open_audio_ready", false)), "status should expose result box audio dependency")


func _verify_scene_delegates_status_builder() -> void:
	var scene_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var status_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_status_scene_handler.gd")
	var helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_status_builder.gd")
	var scene_context_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene_context_builder.gd")
	var actor_scene_context_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_actor_scene_context_builder.gd")
	var live2d_boss_scene_context_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_live2d_boss_scene_context_builder.gd")
	var fallback_actor_scene_context_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_fallback_actor_scene_context_builder.gd")
	var actor_status_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_actor_status_builder.gd")
	var live2d_boss_status_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_live2d_boss_status_builder.gd")
	var fallback_actor_status_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_fallback_actor_status_builder.gd")
	var non_actor_status_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_non_actor_status_builder.gd")
	_expect(
		scene_source.find("func get_interaction_status") < 0
			and status_scene_handler_source.find("StageClearResultStatusBuilder.build_scene_interaction_status") >= 0,
		"stage-clear result scene should not keep an interaction-status facade; the status scene handler should own live status assembly"
	)
	_expect(
		scene_source.find("StageClearResultStatusBuilder.build_scene_interaction_status") < 0,
		"stage-clear result scene should not call the status builder directly"
	)
	_expect(
		helper_source.find("StageClearResultNonActorStatusBuilder.build_non_actor_status") >= 0
			and non_actor_status_source.find("\"box_open_audio_ready\"") >= 0
			and helper_source.find("StageClearResultActorStatusBuilder.build_actor_status") >= 0
			and actor_status_source.find("StageClearResultLive2DBossStatusBuilder.build_live2d_boss_defeat_status") >= 0
			and actor_status_source.find("StageClearResultFallbackActorStatusBuilder.build_stage_result_fallback_status") >= 0
			and live2d_boss_status_source.find("\"stage2_boss_defeat\"") >= 0
			and live2d_boss_status_source.find("\"stage4_ponk_boss_defeat\"") >= 0
			and live2d_boss_status_source.find("\"%s_live2d_active\"") >= 0
			and fallback_actor_status_source.find("\"stage4_ponk_result\"") < 0
			and fallback_actor_status_source.find("\"stage5_hongryun_result\"") >= 0
			and fallback_actor_status_source.find("\"stage6_boss_defeat\"") >= 0
			and fallback_actor_status_source.find("\"%s_click_reaction_active\"") >= 0
			and non_actor_status_source.find("StageClearResultScrollState.get_unfurl_progress") >= 0,
		"status builder should own the public interaction status fields"
	)
	_expect(
		helper_source.find("static func build_scene_interaction_status") >= 0
			and helper_source.find("StageClearResultSceneContextBuilder.build_scene_context") >= 0
			and scene_context_source.find("static func build_scene_context") >= 0
			and scene_context_source.find("StageClearResultActorSceneContextBuilder.build_actor_scene_context") >= 0
			and actor_scene_context_source.find("StageClearResultActorDrawHelper.get_player_victory_reaction_state") >= 0,
		"status builder should delegate scene status context assembly through scene and actor context builders"
	)
	_expect(scene_context_source.find("static func _get_reward_scene_context") >= 0, "scene context builder should centralize reward scene context assembly")
	_expect(scene_context_source.find("static func _get_scroll_scene_context") >= 0, "scene context builder should centralize scroll scene context assembly")
	_expect(scene_context_source.find("static func _get_scene_control_scene_context") >= 0, "scene context builder should centralize scene control context assembly")
	_expect(scene_context_source.find("StageClearResultViewportSceneHandler.get_current_view_size") >= 0, "scene context builder should route view-size lookup through the viewport scene handler")
	_expect(scene_context_source.find("StageClearResultViewportSceneHandler.get_layout_scale") >= 0, "scene context builder should route layout-scale lookup through the viewport scene handler")
	_expect(scene_context_source.find("StageClearResultRuntimeOverlaySceneHandler.is_runtime_perk_choice_active") >= 0, "scene context builder should route runtime perk state through the runtime overlay scene handler")
	_expect(scene_context_source.find("StageClearResultRuntimeOverlaySceneHandler.is_treasure_hunt_effect_active") >= 0, "scene context builder should route treasure-hunt state through the runtime overlay scene handler")
	_expect(scene_context_source.find("scene.call(\"_get_current_view_size\"") < 0, "scene context builder should not bounce view-size lookup through the result scene wrapper")
	_expect(scene_context_source.find("scene.call(\"_get_layout_scale\"") < 0, "scene context builder should not bounce layout-scale lookup through the result scene wrapper")
	_expect(scene_context_source.find("scene.call(\"_is_runtime_perk_choice_active\"") < 0, "scene context builder should not bounce runtime perk state through the result scene wrapper")
	_expect(scene_context_source.find("scene.call(\"_is_treasure_hunt_effect_active\"") < 0, "scene context builder should not bounce treasure-hunt state through the result scene wrapper")
	_expect(actor_scene_context_source.find("static func _get_dalji_scene_context") >= 0, "actor scene context builder should centralize Dalji scene context assembly")
	_expect(actor_status_source.find("static func _get_dalji_status") >= 0, "actor status builder should centralize Dalji public status assembly")
	_expect(non_actor_status_source.find("static func _get_reward_status") >= 0, "non-actor status builder should centralize reward public status assembly")
	_expect(non_actor_status_source.find("static func _get_scroll_status") >= 0, "non-actor status builder should centralize scroll public status assembly")
	_expect(non_actor_status_source.find("static func _get_scene_control_status") >= 0, "non-actor status builder should centralize scene control public status assembly")
	_expect(actor_scene_context_source.find("static func _get_player_victory_scene_context") >= 0, "actor scene context builder should centralize player victory scene context assembly")
	_expect(actor_status_source.find("static func _get_player_victory_status") >= 0, "actor status builder should centralize player victory public status assembly")
	_expect(actor_scene_context_source.find("StageClearResultLive2DBossSceneContextBuilder.build_live2d_boss_defeat_scene_context") >= 0, "actor scene context builder should delegate Stage 2/3 boss defeat scene context assembly")
	_expect(live2d_boss_scene_context_source.find("static func build_live2d_boss_defeat_scene_context") >= 0, "Live2D boss scene context builder should centralize Stage 2/3 boss defeat scene context assembly")
	_expect(live2d_boss_scene_context_source.find("static func _get_live2d_boss_defeat_scene_context_configs") >= 0, "Live2D boss scene context builder should centralize Stage 2/3 boss defeat scene context config")
	_expect(live2d_boss_scene_context_source.find("static func _get_single_live2d_boss_defeat_scene_context") >= 0, "Live2D boss scene context builder should map one Stage 2/3 boss defeat scene context from config")
	_expect(actor_status_source.find("StageClearResultLive2DBossStatusBuilder.build_live2d_boss_defeat_status") >= 0, "actor status builder should delegate Stage 2/3 boss defeat public status assembly")
	_expect(live2d_boss_status_source.find("static func build_live2d_boss_defeat_status") >= 0, "Live2D boss status builder should centralize Stage 2/3 boss defeat public status assembly")
	_expect(live2d_boss_status_source.find("static func _get_live2d_boss_defeat_status_configs") >= 0, "Live2D boss status builder should centralize Stage 2/3 boss defeat status config")
	_expect(live2d_boss_status_source.find("static func _get_single_live2d_boss_defeat_status") >= 0, "Live2D boss status builder should map one Stage 2/3 boss defeat public status from config")
	_expect(actor_status_source.find("StageClearResultFallbackActorStatusBuilder.build_stage_result_fallback_status") >= 0, "actor status builder should delegate Stage 4/5/6 fallback public status assembly")
	_expect(fallback_actor_status_source.find("static func build_stage_result_fallback_status") >= 0, "fallback actor status builder should centralize Stage 4/5/6 fallback public status assembly")
	_expect(fallback_actor_status_source.find("static func _get_stage_result_fallback_status_configs") >= 0, "fallback actor status builder should centralize Stage 4/5/6 fallback status config")
	_expect(fallback_actor_status_source.find("static func _get_single_stage_result_fallback_status") >= 0, "fallback actor status builder should map one Stage 4/5/6 fallback public status from config")
	_expect(actor_scene_context_source.find("StageClearResultFallbackActorSceneContextBuilder.build_stage_result_fallback_scene_context") >= 0, "actor scene context builder should delegate Stage 4/5/6 fallback scene context assembly")
	_expect(fallback_actor_scene_context_source.find("static func build_stage_result_fallback_scene_context") >= 0, "fallback actor scene context builder should centralize Stage 4/5/6 fallback scene context assembly")
	_expect(fallback_actor_scene_context_source.find("static func _get_stage_result_fallback_scene_context_configs") >= 0, "fallback actor scene context builder should centralize Stage 4/5/6 fallback scene context config")
	_expect(fallback_actor_scene_context_source.find("static func _get_single_stage_result_fallback_scene_context") >= 0, "fallback actor scene context builder should map one Stage 4/5/6 fallback scene context from config")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
