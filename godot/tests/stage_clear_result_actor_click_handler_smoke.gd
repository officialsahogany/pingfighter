extends SceneTree

const StageClearResultActorClickHandler := preload("res://scripts/ui/stage_clear_result_actor_click_handler.gd")
const StageClearResultActorClickSceneApplyHandler := preload("res://scripts/ui/stage_clear_result_actor_click_scene_apply_handler.gd")
const StageClearResultActorClickSceneHandler := preload("res://scripts/ui/stage_clear_result_actor_click_scene_handler.gd")
const StageClearResultActorDrawHelper := preload("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")
const StageClearResultFieldApplySceneHandler := preload("res://scripts/ui/stage_clear_result_field_apply_scene_handler.gd")
const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_player_victory_click()
	_verify_dalji_click()
	_verify_player_victory_scene_apply_result()
	_verify_dalji_scene_apply_result()
	_verify_boss_defeat_click()
	_verify_boss_result_click_config()
	_verify_boss_result_scene_apply_result()
	_verify_click_reaction_apply_result()
	_verify_click_rect_apply_result()
	_verify_dalji_side_effect_apply_result()
	_verify_scene_field_apply_results()
	_verify_scene_delegates_actor_clicks()

	if _failures.is_empty():
		print("stage_clear_result_actor_click_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_player_victory_click() -> void:
	var view_size := Vector2(1920.0, 1080.0)
	var click_rect: Rect2 = StageClearResultLayoutHelper.get_player_victory_click_rect(
		view_size,
		1.0,
		StageClearResultActorDrawHelper.PLAYER_VICTORY_CELL_SIZE
	)
	var result: Dictionary = StageClearResultActorClickHandler.handle_player_victory_click(
		click_rect.get_center(),
		view_size,
		1.0,
		StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_TOTAL_DURATION,
		1.10
	)
	_expect(bool(result.get("handled", false)), "player victory click should be handled inside the actor rect")
	_expect(bool(result.get("started", false)), "player victory click should start when no reaction is active")
	_expect(int(result.get("transition_base_frame", 0)) > 0, "player victory click should preserve the current base frame")

	var active_result: Dictionary = StageClearResultActorClickHandler.handle_player_victory_click(
		click_rect.get_center(),
		view_size,
		1.0,
		0.10,
		1.10
	)
	_expect(bool(active_result.get("handled", false)), "active player victory reaction clicks should still be consumed")
	_expect(not bool(active_result.get("started", true)), "active player victory reaction clicks should not restart the reaction")


func _verify_dalji_click() -> void:
	var view_size := Vector2(1920.0, 1080.0)
	var click_rect: Rect2 = StageClearResultLayoutHelper.get_dalji_draw_rect(view_size, 1.0)
	var ignored: Dictionary = StageClearResultActorClickHandler.handle_dalji_click(
		2,
		click_rect.get_center(),
		view_size,
		1.0,
		StageClearResultActorDrawHelper.DALJI_CLICK_TOTAL_DURATION,
		0.40
	)
	_expect(not bool(ignored.get("handled", true)), "Dalji click handler should ignore non-Stage 1 results")

	var result: Dictionary = StageClearResultActorClickHandler.handle_dalji_click(
		1,
		click_rect.get_center(),
		view_size,
		1.0,
		StageClearResultActorDrawHelper.DALJI_CLICK_TOTAL_DURATION,
		0.40
	)
	_expect(bool(result.get("handled", false)), "Dalji click should be handled inside the actor rect")
	_expect(bool(result.get("started", false)), "Dalji click should start when no reaction is active")
	_expect(bool(result.get("show_dialogue", false)), "Dalji handled clicks should request dialogue")
	_expect(bool(result.get("play_voice", false)), "Dalji handled clicks should request voice playback")


func _verify_player_victory_scene_apply_result() -> void:
	var scene := StageClearResultScene.new()
	scene.set("_player_victory_click_reaction_timer", StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_TOTAL_DURATION)
	scene.set("_player_victory_click_transition_base_frame", 0)

	var view_size := Vector2(1920.0, 1080.0)
	var click_rect: Rect2 = StageClearResultLayoutHelper.get_player_victory_click_rect(
		view_size,
		1.0,
		StageClearResultActorDrawHelper.PLAYER_VICTORY_CELL_SIZE
	)
	var result: Dictionary = StageClearResultActorClickSceneApplyHandler.get_player_victory_click_scene_apply_result(
		scene,
		click_rect.get_center(),
		view_size,
		1.0,
		1.10
	)
	var field_payload: Dictionary = result.get("field_payload", {}) as Dictionary
	_expect(bool(result.get("handled", false)), "player victory scene apply helper should handle clicks inside the actor rect")
	_expect(bool(result.get("started", false)), "player victory scene apply helper should preserve started click state")
	_expect(field_payload.get("_player_victory_click_rect", Rect2()) == click_rect, "player victory scene apply helper should map click rect fields")
	_expect(field_payload.has("_player_victory_click_transition_base_frame"), "player victory scene apply helper should map transition frame payloads")
	_expect(float(field_payload.get("_player_victory_click_reaction_timer", -1.0)) == 0.0, "player victory scene apply helper should restart reaction timers")
	_expect(bool(result.get("redraw", false)), "player victory scene apply helper should request redraw for handled clicks")
	_expect(not bool(result.get("play_voice", true)), "player victory scene apply helper should not request Dalji voice playback")
	scene.free()


func _verify_dalji_scene_apply_result() -> void:
	var scene := StageClearResultScene.new()
	scene.set("_dalji_click_reaction_timer", StageClearResultActorDrawHelper.DALJI_CLICK_TOTAL_DURATION)
	scene.set("_dalji_click_transition_base_frame", 0)
	scene.set("_dalji_dialogue_timer", 0.4)

	var view_size := Vector2(1920.0, 1080.0)
	var click_rect: Rect2 = StageClearResultLayoutHelper.get_dalji_draw_rect(view_size, 1.0)
	var result: Dictionary = StageClearResultActorClickSceneApplyHandler.get_dalji_click_scene_apply_result(
		1,
		scene,
		click_rect.get_center(),
		view_size,
		1.0,
		0.40,
		1.55
	)
	var field_payload: Dictionary = result.get("field_payload", {}) as Dictionary
	_expect(bool(result.get("handled", false)), "Dalji scene apply helper should handle Stage 1 clicks inside the actor rect")
	_expect(bool(result.get("started", false)), "Dalji scene apply helper should preserve started click state")
	_expect(field_payload.get("_dalji_click_rect", Rect2()) == click_rect, "Dalji scene apply helper should map click rect fields")
	_expect(field_payload.has("_dalji_click_transition_base_frame"), "Dalji scene apply helper should map transition frame payloads")
	_expect(float(field_payload.get("_dalji_click_reaction_timer", -1.0)) == 0.0, "Dalji scene apply helper should restart reaction timers")
	_expect(float(field_payload.get("_dalji_dialogue_timer", 0.0)) == 1.55, "Dalji scene apply helper should map dialogue timer side effects")
	_expect(bool(result.get("play_voice", false)), "Dalji scene apply helper should preserve voice playback requests")

	var ignored: Dictionary = StageClearResultActorClickSceneApplyHandler.get_dalji_click_scene_apply_result(
		2,
		scene,
		click_rect.get_center(),
		view_size,
		1.0,
		0.40,
		1.55
	)
	var ignored_payload: Dictionary = ignored.get("field_payload", {}) as Dictionary
	_expect(not bool(ignored.get("handled", true)), "Dalji scene apply helper should ignore non-Stage 1 results")
	_expect(ignored_payload.get("_dalji_click_rect", Rect2(1.0, 1.0, 1.0, 1.0)) == Rect2(), "Dalji scene apply helper should clear click rects for ignored clicks")
	_expect(not ignored_payload.has("_dalji_dialogue_timer"), "Dalji scene apply helper should not show dialogue for ignored clicks")
	_expect(not bool(ignored.get("play_voice", true)), "Dalji scene apply helper should not request voice playback for ignored clicks")
	scene.free()


func _verify_boss_defeat_click() -> void:
	var view_size := Vector2(1920.0, 1080.0)
	var stage2_rect: Rect2 = StageClearResultLayoutHelper.get_stage2_boss_result_draw_rect(view_size, 1.0)
	var missing_sheet: Dictionary = StageClearResultActorClickHandler.handle_boss_defeat_click(
		2,
		false,
		stage2_rect.get_center(),
		view_size,
		1.0,
		StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		0.25
	)
	_expect(not bool(missing_sheet.get("handled", true)), "boss defeat clicks should ignore stages without a reaction sheet")

	var result: Dictionary = StageClearResultActorClickHandler.handle_boss_defeat_click(
		2,
		true,
		stage2_rect.get_center(),
		view_size,
		1.0,
		StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		0.25
	)
	_expect(bool(result.get("handled", false)), "Stage 2 boss defeat clicks should be handled inside the actor rect")
	_expect(bool(result.get("started", false)), "Stage 2 boss defeat clicks should start when no reaction is active")

	var stage4_rect: Rect2 = StageClearResultLayoutHelper.get_stage4_boss_result_draw_rect(view_size, 1.0)
	var stage4_missing_sheet: Dictionary = StageClearResultActorClickHandler.handle_boss_defeat_click(
		4,
		false,
		stage4_rect.get_center(),
		view_size,
		1.0,
		StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		0.50
	)
	_expect(not bool(stage4_missing_sheet.get("handled", true)), "Stage 4 Ponk result clicks should require the Live2D reaction sheet")

	var stage4_result: Dictionary = StageClearResultActorClickHandler.handle_boss_defeat_click(
		4,
		true,
		stage4_rect.get_center(),
		view_size,
		1.0,
		StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		0.50
	)
	_expect(bool(stage4_result.get("handled", false)), "Stage 4 Ponk result clicks should be handled inside the Live2D actor rect")
	_expect(bool(stage4_result.get("started", false)), "Stage 4 Ponk result clicks should start the Live2D click reaction")
	_expect(int(stage4_result.get("transition_base_frame", -1)) == 9, "Stage 4 Ponk click should preserve the current Live2D base frame")

	var stage5_rect: Rect2 = StageClearResultLayoutHelper.get_stage5_hongryun_result_draw_rect(view_size, 1.0)
	var stage5_missing_sheet: Dictionary = StageClearResultActorClickHandler.handle_boss_defeat_click(
		5,
		false,
		stage5_rect.get_center(),
		view_size,
		1.0,
		StageClearResultActorDrawHelper.STAGE5_HONGRYUN_CLICK_TOTAL_DURATION,
		0.50
	)
	_expect(not bool(stage5_missing_sheet.get("handled", true)), "Stage 5 Hongryun result clicks should require the fallback result sheet")

	var stage5_result: Dictionary = StageClearResultActorClickHandler.handle_boss_defeat_click(
		5,
		true,
		stage5_rect.get_center(),
		view_size,
		1.0,
		StageClearResultActorDrawHelper.STAGE5_HONGRYUN_CLICK_TOTAL_DURATION,
		0.50
	)
	_expect(bool(stage5_result.get("handled", false)), "Stage 5 Hongryun result clicks should be handled inside the fallback actor rect")
	_expect(bool(stage5_result.get("started", false)), "Stage 5 Hongryun result clicks should start the fallback pulse reaction")
	_expect(int(stage5_result.get("transition_base_frame", -1)) == 3, "Stage 5 Hongryun click should preserve the current fallback frame")

	var stage6_rect: Rect2 = StageClearResultLayoutHelper.get_stage6_tetriser_result_draw_rect(view_size, 1.0)
	var stage6_missing_sheet: Dictionary = StageClearResultActorClickHandler.handle_boss_defeat_click(
		6,
		false,
		stage6_rect.get_center(),
		view_size,
		1.0,
		StageClearResultActorDrawHelper.STAGE6_TETRISER_CLICK_TOTAL_DURATION,
		0.25
	)
	_expect(not bool(stage6_missing_sheet.get("handled", true)), "Stage 6 boss defeat clicks should require the Tetriser defeat sheet")

	var stage6_result: Dictionary = StageClearResultActorClickHandler.handle_boss_defeat_click(
		6,
		true,
		stage6_rect.get_center(),
		view_size,
		1.0,
		StageClearResultActorDrawHelper.STAGE6_TETRISER_CLICK_TOTAL_DURATION,
		0.25
	)
	_expect(bool(stage6_result.get("handled", false)), "Stage 6 boss defeat clicks should be handled inside the Tetriser result rect")
	_expect(bool(stage6_result.get("started", false)), "Stage 6 boss defeat clicks should start the Tetriser pulse reaction")
	_expect(int(stage6_result.get("transition_base_frame", -1)) == 2, "Stage 6 boss click should preserve the current Tetriser defeat frame")


func _verify_boss_result_click_config() -> void:
	var stage2_config: Dictionary = StageClearResultActorClickHandler.get_boss_result_click_config(2)
	_expect(stage2_config.get("sheet_property", &"") == &"_stage2_boss_defeat_click_reaction_sheet", "Stage 2 boss click config should expose the boss reaction sheet field")
	_expect(stage2_config.get("transition_base_frame_property", &"") == &"_stage2_boss_defeat_click_transition_base_frame", "Stage 2 boss click config should expose the boss transition field")
	_expect(stage2_config.get("reaction_timer_property", &"") == &"_stage2_boss_defeat_click_reaction_timer", "Stage 2 boss click config should expose the boss timer field")

	var stage3_config: Dictionary = StageClearResultActorClickHandler.get_boss_result_click_config(3)
	_expect(stage3_config.get("sheet_property", &"") == &"_stage3_boss_defeat_click_reaction_sheet", "Stage 3 boss click config should expose the boss reaction sheet field")
	_expect(stage3_config.get("transition_base_frame_property", &"") == &"_stage3_boss_defeat_click_transition_base_frame", "Stage 3 boss click config should expose the boss transition field")
	_expect(stage3_config.get("reaction_timer_property", &"") == &"_stage3_boss_defeat_click_reaction_timer", "Stage 3 boss click config should expose the boss timer field")

	var stage4_config: Dictionary = StageClearResultActorClickHandler.get_boss_result_click_config(4)
	_expect(stage4_config.get("sheet_property", &"") == &"_stage4_ponk_boss_defeat_click_reaction_sheet", "Stage 4 Live2D click config should expose the Ponk reaction sheet field")
	_expect(stage4_config.get("transition_base_frame_property", &"") == &"_stage4_ponk_boss_defeat_click_transition_base_frame", "Stage 4 Live2D click config should expose the Ponk transition field")
	_expect(stage4_config.get("reaction_timer_property", &"") == &"_stage4_ponk_boss_defeat_click_reaction_timer", "Stage 4 Live2D click config should expose the Ponk timer field")

	var stage5_config: Dictionary = StageClearResultActorClickHandler.get_boss_result_click_config(5)
	_expect(stage5_config.get("sheet_property", &"") == &"_stage5_hongryun_result_sheet", "Stage 5 fallback click config should expose the Hongryun sheet field")
	_expect(stage5_config.get("transition_base_frame_property", &"") == &"_stage5_hongryun_result_click_transition_base_frame", "Stage 5 fallback click config should expose the Hongryun transition field")
	_expect(stage5_config.get("reaction_timer_property", &"") == &"_stage5_hongryun_result_click_reaction_timer", "Stage 5 fallback click config should expose the Hongryun timer field")

	var stage6_config: Dictionary = StageClearResultActorClickHandler.get_boss_result_click_config(6)
	_expect(stage6_config.get("sheet_property", &"") == &"_stage6_boss_defeat_sheet", "Stage 6 fallback click config should expose the Tetriser sheet field")
	_expect(stage6_config.get("transition_base_frame_property", &"") == &"_stage6_boss_defeat_click_transition_base_frame", "Stage 6 fallback click config should expose the Tetriser transition field")
	_expect(stage6_config.get("reaction_timer_property", &"") == &"_stage6_boss_defeat_click_reaction_timer", "Stage 6 fallback click config should expose the Tetriser timer field")

	_expect(StageClearResultActorClickHandler.get_boss_result_click_config(1).is_empty(), "non-boss result stages should not expose boss click config")
	_expect(StageClearResultActorClickHandler.get_stage_result_fallback_click_config(4).is_empty(), "fallback config compatibility helper should not expose Stage 4 Live2D config")
	_expect(StageClearResultActorClickHandler.get_stage_result_fallback_click_config(2).is_empty(), "fallback config compatibility helper should not expose Stage 2 config")


func _verify_boss_result_scene_apply_result() -> void:
	var scene := StageClearResultScene.new()
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	var texture := ImageTexture.create_from_image(image)
	scene.set("_stage2_boss_defeat_click_reaction_sheet", texture)
	scene.set("_stage2_boss_defeat_click_reaction_timer", StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION)
	scene.set("_stage2_boss_defeat_click_transition_base_frame", 0)

	var view_size := Vector2(1920.0, 1080.0)
	var stage2_rect: Rect2 = StageClearResultLayoutHelper.get_stage2_boss_result_draw_rect(view_size, 1.0)
	var result: Dictionary = StageClearResultActorClickSceneApplyHandler.get_boss_result_click_scene_apply_result(
		2,
		2,
		scene,
		stage2_rect.get_center(),
		view_size,
		1.0,
		0.25
	)
	var field_payload: Dictionary = result.get("field_payload", {}) as Dictionary
	_expect(bool(result.get("handled", false)), "boss-result scene apply helper should handle the current stage with a loaded sheet")
	_expect(bool(result.get("started", false)), "boss-result scene apply helper should preserve started click state")
	_expect(field_payload.has("_stage2_boss_defeat_click_transition_base_frame"), "boss-result scene apply helper should map transition frame payloads")
	_expect(float(field_payload.get("_stage2_boss_defeat_click_reaction_timer", -1.0)) == 0.0, "boss-result scene apply helper should restart reaction timers")
	_expect(bool(result.get("redraw", false)), "boss-result scene apply helper should request redraw for handled clicks")

	var stage_mismatch: Dictionary = StageClearResultActorClickSceneApplyHandler.get_boss_result_click_scene_apply_result(
		3,
		2,
		scene,
		stage2_rect.get_center(),
		view_size,
		1.0,
		0.25
	)
	_expect(not bool(stage_mismatch.get("handled", true)), "boss-result scene apply helper should ignore non-current stages")
	_expect((stage_mismatch.get("field_payload", {}) as Dictionary).is_empty(), "boss-result scene apply helper should not write fields for non-current stages")

	var missing_sheet: Dictionary = StageClearResultActorClickSceneApplyHandler.get_boss_result_click_scene_apply_result(
		3,
		3,
		scene,
		stage2_rect.get_center(),
		view_size,
		1.0,
		0.25
	)
	_expect(not bool(missing_sheet.get("handled", true)), "boss-result scene apply helper should ignore missing reaction sheets")
	_expect((missing_sheet.get("field_payload", {}) as Dictionary).is_empty(), "boss-result scene apply helper should not write fields when the reaction sheet is missing")
	scene.free()


func _verify_click_reaction_apply_result() -> void:
	var missed: Dictionary = StageClearResultActorClickHandler.get_click_reaction_apply_result(
		{"handled": false, "started": false},
		9,
		0.7
	)
	_expect(not bool(missed.get("handled", true)), "apply helper should preserve unhandled clicks")
	_expect(int(missed.get("transition_base_frame", 0)) == 9, "apply helper should keep current transition frame for misses")
	_expect(float(missed.get("reaction_timer", 0.0)) == 0.7, "apply helper should keep current reaction timer for misses")
	_expect(not bool(missed.get("redraw", true)), "apply helper should not redraw for misses")

	var consumed: Dictionary = StageClearResultActorClickHandler.get_click_reaction_apply_result(
		{"handled": true, "started": false},
		11,
		0.3
	)
	_expect(bool(consumed.get("handled", false)), "apply helper should preserve consumed active-reaction clicks")
	_expect(not bool(consumed.get("started", true)), "apply helper should preserve non-restarting active clicks")
	_expect(int(consumed.get("transition_base_frame", 0)) == 11, "apply helper should keep transition frame for active clicks")
	_expect(float(consumed.get("reaction_timer", 0.0)) == 0.3, "apply helper should keep reaction timer for active clicks")
	_expect(bool(consumed.get("redraw", false)), "apply helper should request redraw for handled active clicks")

	var started: Dictionary = StageClearResultActorClickHandler.get_click_reaction_apply_result(
		{
			"handled": true,
			"started": true,
			"transition_base_frame": 15,
			"reaction_timer": 0.0,
		},
		2,
		1.0
	)
	_expect(bool(started.get("handled", false)), "apply helper should preserve handled started clicks")
	_expect(bool(started.get("started", false)), "apply helper should preserve started clicks")
	_expect(int(started.get("transition_base_frame", 0)) == 15, "apply helper should apply captured transition frame")
	_expect(float(started.get("reaction_timer", -1.0)) == 0.0, "apply helper should apply restart reaction timer")
	_expect(bool(started.get("redraw", false)), "apply helper should redraw for started clicks")

	var scene_started: Dictionary = StageClearResultActorClickHandler.get_click_reaction_scene_apply_result(
		{
			"handled": true,
			"started": true,
			"transition_base_frame": 21,
			"reaction_timer": 0.0,
		},
		&"_transition_field",
		2,
		&"_reaction_field",
		1.0
	)
	var scene_field_payload: Dictionary = scene_started.get("field_payload", {}) as Dictionary
	_expect(bool(scene_started.get("handled", false)), "scene apply helper should preserve handled clicks")
	_expect(int(scene_field_payload.get("_transition_field", 0)) == 21, "scene apply helper should map transition frame fields")
	_expect(float(scene_field_payload.get("_reaction_field", -1.0)) == 0.0, "scene apply helper should map reaction timer fields")
	_expect(bool(scene_started.get("redraw", false)), "scene apply helper should preserve redraw requests")

	var scene_missed: Dictionary = StageClearResultActorClickHandler.get_click_reaction_scene_apply_result(
		{"handled": false},
		&"_transition_field",
		2,
		&"_reaction_field",
		1.0
	)
	var missed_field_payload: Dictionary = scene_missed.get("field_payload", {}) as Dictionary
	_expect(missed_field_payload.is_empty(), "scene apply helper should not return field writes for missed clicks")


func _verify_click_rect_apply_result() -> void:
	var player_rect := Rect2(Vector2(10.0, 20.0), Vector2(120.0, 140.0))
	var player_apply: Dictionary = StageClearResultActorClickHandler.get_player_victory_click_rect_apply_result({
		"click_rect": player_rect,
	})
	_expect(player_apply.get("player_victory_click_rect", Rect2()) == player_rect, "player click-rect apply helper should preserve click rects")

	var missing_player_apply: Dictionary = StageClearResultActorClickHandler.get_player_victory_click_rect_apply_result({})
	_expect(missing_player_apply.get("player_victory_click_rect", Rect2()) == Rect2(), "player click-rect apply helper should clear missing click rects")

	var dalji_rect := Rect2(Vector2(30.0, 40.0), Vector2(150.0, 160.0))
	var dalji_apply: Dictionary = StageClearResultActorClickHandler.get_dalji_click_rect_apply_result({
		"click_rect": dalji_rect,
	})
	_expect(dalji_apply.get("dalji_click_rect", Rect2()) == dalji_rect, "Dalji click-rect apply helper should preserve click rects")

	var missing_dalji_apply: Dictionary = StageClearResultActorClickHandler.get_dalji_click_rect_apply_result({})
	_expect(missing_dalji_apply.get("dalji_click_rect", Rect2()) == Rect2(), "Dalji click-rect apply helper should clear missing click rects")

	var player_scene_apply: Dictionary = StageClearResultActorClickHandler.get_player_victory_click_rect_scene_apply_result({
		"click_rect": player_rect,
	})
	var player_field_payload: Dictionary = player_scene_apply.get("field_payload", {}) as Dictionary
	_expect(player_field_payload.get("_player_victory_click_rect", Rect2()) == player_rect, "player click-rect scene helper should map scene field names")

	var dalji_scene_apply: Dictionary = StageClearResultActorClickHandler.get_dalji_click_rect_scene_apply_result({
		"click_rect": dalji_rect,
	})
	var dalji_field_payload: Dictionary = dalji_scene_apply.get("field_payload", {}) as Dictionary
	_expect(dalji_field_payload.get("_dalji_click_rect", Rect2()) == dalji_rect, "Dalji click-rect scene helper should map scene field names")


func _verify_dalji_side_effect_apply_result() -> void:
	var shown: Dictionary = StageClearResultActorClickHandler.get_dalji_click_side_effect_apply_result(
		{
			"show_dialogue": true,
			"play_voice": true,
		},
		0.4,
		1.55
	)
	_expect(float(shown.get("dalji_dialogue_timer", 0.0)) == 1.55, "Dalji side-effect apply helper should set dialogue timer")
	_expect(bool(shown.get("play_voice", false)), "Dalji side-effect apply helper should request voice playback")

	var ignored: Dictionary = StageClearResultActorClickHandler.get_dalji_click_side_effect_apply_result(
		{
			"show_dialogue": false,
			"play_voice": false,
		},
		0.6,
		1.55
	)
	_expect(float(ignored.get("dalji_dialogue_timer", 0.0)) == 0.6, "Dalji side-effect apply helper should preserve timer when dialogue is not requested")
	_expect(not bool(ignored.get("play_voice", true)), "Dalji side-effect apply helper should not request voice playback for ignored clicks")

	var scene_shown: Dictionary = StageClearResultActorClickHandler.get_dalji_click_side_effect_scene_apply_result(
		{
			"show_dialogue": true,
			"play_voice": true,
		},
		0.4,
		1.55
	)
	var scene_field_payload: Dictionary = scene_shown.get("field_payload", {}) as Dictionary
	_expect(float(scene_field_payload.get("_dalji_dialogue_timer", 0.0)) == 1.55, "Dalji side-effect scene helper should map dialogue timer field")
	_expect(bool(scene_shown.get("play_voice", false)), "Dalji side-effect scene helper should preserve voice playback requests")


func _verify_scene_field_apply_results() -> void:
	var player_rect := Rect2(Vector2(10.0, 20.0), Vector2(120.0, 140.0))
	var dalji_rect := Rect2(Vector2(30.0, 40.0), Vector2(150.0, 160.0))
	var scene := StageClearResultScene.new()
	StageClearResultFieldApplySceneHandler.apply_scene_apply_result(scene, {
		"field_payload": {
			"_player_victory_click_rect": player_rect,
			"_dalji_click_rect": dalji_rect,
			"_dalji_dialogue_timer": 1.55,
			"_player_victory_click_transition_base_frame": 9,
			"_player_victory_click_reaction_timer": 0.0,
			"_stage6_boss_defeat_click_transition_base_frame": 3,
			"_stage6_boss_defeat_click_reaction_timer": 0.0,
			"_stage6_boss_defeat_click_rect": Rect2(Vector2(50.0, 60.0), Vector2(170.0, 180.0)),
			"_stage4_ponk_boss_defeat_click_transition_base_frame": 2,
			"_stage4_ponk_boss_defeat_click_reaction_timer": 0.0,
			"_stage4_ponk_boss_defeat_click_rect": Rect2(Vector2(70.0, 80.0), Vector2(190.0, 200.0)),
			"_stage5_hongryun_result_click_transition_base_frame": 4,
			"_stage5_hongryun_result_click_reaction_timer": 0.0,
			"_stage5_hongryun_result_click_rect": Rect2(Vector2(90.0, 100.0), Vector2(210.0, 220.0)),
		},
	})
	_expect(scene.get("_player_victory_click_rect") == player_rect, "scene field helper should apply player click rect fields")
	_expect(scene.get("_dalji_click_rect") == dalji_rect, "scene field helper should apply Dalji click rect fields")
	_expect(abs(float(scene.get("_dalji_dialogue_timer")) - 1.55) <= 0.001, "scene field helper should apply Dalji dialogue timers")
	_expect(int(scene.get("_player_victory_click_transition_base_frame")) == 9, "scene field helper should apply transition frame fields")
	_expect(abs(float(scene.get("_player_victory_click_reaction_timer")) - 0.0) <= 0.001, "scene field helper should apply reaction timer fields")
	_expect(int(scene.get("_stage6_boss_defeat_click_transition_base_frame")) == 3, "scene field helper should apply Stage 6 transition frame fields")
	_expect(abs(float(scene.get("_stage6_boss_defeat_click_reaction_timer")) - 0.0) <= 0.001, "scene field helper should apply Stage 6 reaction timer fields")
	_expect(scene.get("_stage6_boss_defeat_click_rect") == Rect2(Vector2(50.0, 60.0), Vector2(170.0, 180.0)), "scene field helper should apply Stage 6 click rect fields")
	_expect(int(scene.get("_stage4_ponk_boss_defeat_click_transition_base_frame")) == 2, "scene field helper should apply Stage 4 Ponk transition frame fields")
	_expect(abs(float(scene.get("_stage4_ponk_boss_defeat_click_reaction_timer")) - 0.0) <= 0.001, "scene field helper should apply Stage 4 Ponk reaction timer fields")
	_expect(scene.get("_stage4_ponk_boss_defeat_click_rect") == Rect2(Vector2(70.0, 80.0), Vector2(190.0, 200.0)), "scene field helper should apply Stage 4 Ponk click rect fields")
	_expect(int(scene.get("_stage5_hongryun_result_click_transition_base_frame")) == 4, "scene field helper should apply Stage 5 Hongryun transition frame fields")
	_expect(abs(float(scene.get("_stage5_hongryun_result_click_reaction_timer")) - 0.0) <= 0.001, "scene field helper should apply Stage 5 Hongryun reaction timer fields")
	_expect(scene.get("_stage5_hongryun_result_click_rect") == Rect2(Vector2(90.0, 100.0), Vector2(210.0, 220.0)), "scene field helper should apply Stage 5 Hongryun click rect fields")
	scene.free()


func _verify_scene_delegates_actor_clicks() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var input_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_input_scene_handler.gd")
	var helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_actor_click_handler.gd")
	var scene_apply_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_actor_click_scene_apply_handler.gd")
	var scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_actor_click_scene_handler.gd")
	var actor_click_source: String = _slice_function(input_scene_handler_source, "static func handle_mouse_left_press", "static func _get_scene_string")
	_expect(StageClearResultActorClickSceneHandler != null, "actor click scene handler preload should resolve")
	_expect(input_scene_handler_source.find("StageClearResultActorClickSceneHandler.handle_player_victory_click") >= 0, "input scene handler should delegate player victory click scene glue")
	_expect(input_scene_handler_source.find("StageClearResultActorClickSceneHandler.handle_dalji_click") >= 0, "input scene handler should delegate Dalji click scene glue")
	_expect(source.find("StageClearResultActorClickSceneHandler.handle_player_victory_click") < 0, "result scene should not keep player victory click scene glue")
	_expect(source.find("StageClearResultActorClickSceneHandler.handle_dalji_click") < 0, "result scene should not keep Dalji click scene glue")
	_expect(source.find("StageClearResultActorClickSceneApplyHandler.") < 0, "result scene should not call the actor click scene-apply helper directly")
	_expect(scene_handler_source.find("StageClearResultActorClickSceneApplyHandler.get_player_victory_click_scene_apply_result") >= 0, "actor click scene handler should delegate player victory click scene apply payloads")
	_expect(scene_handler_source.find("StageClearResultActorClickSceneApplyHandler.get_dalji_click_scene_apply_result") >= 0, "actor click scene handler should delegate Dalji click scene apply payloads")
	_expect(source.find("StageClearResultActorClickHandler.handle_player_victory_click") < 0, "result scene should not call the low-level player victory click attempt helper directly")
	_expect(source.find("StageClearResultActorClickHandler.handle_dalji_click") < 0, "result scene should not call the low-level Dalji click attempt helper directly")
	_expect(input_scene_handler_source.find("StageClearResultActorClickSceneHandler.handle_current_boss_result_click") >= 0, "input scene handler should delegate current boss result click scene glue")
	_expect(source.find("StageClearResultActorClickSceneHandler.handle_current_boss_result_click") < 0, "result scene should not keep current boss result click scene glue")
	_expect(scene_handler_source.find("StageClearResultActorClickSceneApplyHandler.get_boss_result_click_scene_apply_result") >= 0, "actor click scene handler should delegate boss result click scene apply payloads")
	_expect(source.find("StageClearResultActorClickHandler.get_click_reaction_scene_apply_result") < 0, "result scene should not assemble click reaction scene field payloads directly")
	_expect(source.find("StageClearResultActorClickHandler.get_player_victory_click_rect_scene_apply_result") < 0, "result scene should not assemble player click-rect scene field payloads directly")
	_expect(source.find("StageClearResultActorClickHandler.get_dalji_click_rect_scene_apply_result") < 0, "result scene should not assemble Dalji click-rect scene field payloads directly")
	_expect(source.find("StageClearResultActorClickHandler.get_dalji_click_side_effect_scene_apply_result") < 0, "result scene should not assemble Dalji click side-effect scene field payloads directly")
	_expect(source.find("func _handle_player_victory_click") < 0, "result scene should not keep player victory click scene glue")
	_expect(source.find("func _handle_dalji_click") < 0, "result scene should not keep Dalji click scene glue")
	_expect(source.find("func _handle_current_boss_result_click") < 0, "result scene should not keep current-stage boss result click scene glue")
	_expect(source.find("func _handle_boss_result_click") < 0, "result scene should not keep boss result click scene glue")
	_expect(scene_handler_source.find("static func handle_boss_result_click") >= 0, "actor click scene handler should route Stage 2-6 boss result clicks through one helper")
	_expect(source.find("StageClearResultActorClickHandler.get_boss_result_click_config") < 0, "result scene should not read Stage 2-6 boss result click property config directly")
	_expect(source.find("StageClearResultActorClickHandler.get_stage_result_fallback_click_config") < 0, "result scene should not use the compatibility-only fallback config helper")
	_expect(source.find("func _handle_stage2_boss_defeat_click") < 0, "result scene should not keep a Stage 2 boss click wrapper")
	_expect(source.find("func _handle_stage3_boss_defeat_click") < 0, "result scene should not keep a Stage 3 boss click wrapper")
	_expect(source.find("func _handle_stage4_ponk_result_click") < 0, "result scene should not keep a Stage 4 fallback click wrapper")
	_expect(source.find("func _handle_stage5_hongryun_result_click") < 0, "result scene should not keep a Stage 5 fallback click wrapper")
	_expect(source.find("func _handle_stage6_boss_defeat_click") < 0, "result scene should not keep a Stage 6 boss click wrapper")
	_expect(source.find("func _handle_stage_result_fallback_click") < 0, "result scene should not keep the fallback-only click wrapper")
	_expect(source.find("func _handle_boss_defeat_click") < 0, "result scene should not keep a direct boss-defeat click helper")
	_expect(source.find("func _apply_click_reaction_result") < 0, "result scene should not keep the retired direct click-reaction apply wrapper")
	_expect(source.find("func _get_stage_result_fallback_click_config") < 0, "result scene should not keep fallback click property config")
	_expect(source.find("func _apply_scene_apply_result") < 0, "result scene should not keep scene apply-result pass-through wrappers")
	_expect(source.find("func _apply_scene_field_payload") < 0, "result scene should not keep the retired direct field-payload wrapper")
	_expect(source.find("func _get_field_payload_from_apply_result") < 0, "result scene should not keep the retired payload-unwrapping wrapper")
	_expect(helper_source.find("static func get_click_reaction_scene_apply_result") >= 0, "actor click helper should expose click reaction scene field payloads")
	_expect(helper_source.find("static func get_player_victory_click_scene_apply_result") < 0, "actor click helper should not keep player victory scene-apply orchestration")
	_expect(helper_source.find("static func get_dalji_click_scene_apply_result") < 0, "actor click helper should not keep Dalji scene-apply orchestration")
	_expect(helper_source.find("static func get_player_victory_click_rect_scene_apply_result") >= 0, "actor click helper should expose player click-rect scene field payloads")
	_expect(helper_source.find("static func get_dalji_click_rect_scene_apply_result") >= 0, "actor click helper should expose Dalji click-rect scene field payloads")
	_expect(helper_source.find("static func get_dalji_click_side_effect_scene_apply_result") >= 0, "actor click helper should expose Dalji side-effect scene field payloads")
	_expect(helper_source.find("static func get_boss_result_click_config") >= 0, "actor click helper should centralize Stage 2-6 boss result click property config")
	_expect(helper_source.find("static func get_boss_result_click_scene_apply_result") < 0, "actor click helper should not keep boss result scene-apply orchestration")
	_expect(scene_apply_source.find("static func get_player_victory_click_scene_apply_result") >= 0, "actor click scene-apply helper should expose player victory scene field payloads")
	_expect(scene_apply_source.find("static func get_dalji_click_scene_apply_result") >= 0, "actor click scene-apply helper should expose Dalji scene field payloads")
	_expect(scene_apply_source.find("static func get_boss_result_click_scene_apply_result") >= 0, "actor click scene-apply helper should expose boss result scene field payloads")
	_expect(scene_handler_source.find("static func apply_actor_click_scene_apply_result") >= 0, "actor click scene handler should own scene apply / redraw / voice glue")
	_expect(scene_handler_source.find("StageClearResultAudioSceneHandler.play_dalji_click_voice") >= 0, "actor click scene handler should route Dalji click voice playback")
	_expect(scene_apply_source.find("StageClearResultActorClickHandler.handle_player_victory_click") >= 0, "actor click scene-apply helper should reuse player victory click attempts")
	_expect(scene_apply_source.find("StageClearResultActorClickHandler.get_click_reaction_scene_apply_result") >= 0, "actor click scene-apply helper should reuse click reaction payload helpers")
	_expect(helper_source.find("static func get_stage_result_fallback_click_config") >= 0, "actor click helper should keep the Stage 4/5/6 compatibility config facade")
	_expect(actor_click_source.find("result.get(\"started\"") < 0, "result scene should not inspect click reaction started state directly")
	_expect(actor_click_source.find("_player_victory_click_rect = result.get(\"click_rect\"") < 0, "result scene should not inspect player click rect results directly")
	_expect(actor_click_source.find("_dalji_click_rect = result.get(\"click_rect\"") < 0, "result scene should not inspect Dalji click rect results directly")
	_expect(actor_click_source.find("_player_victory_click_rect = click_rect_result.get") < 0, "result scene should not write player click rects directly")
	_expect(actor_click_source.find("_dalji_click_rect = click_rect_result.get") < 0, "result scene should not write Dalji click rects directly")
	_expect(actor_click_source.find("_dalji_dialogue_timer = float(side_effect_result.get") < 0, "result scene should not write Dalji dialogue timers directly")
	_expect(actor_click_source.find("set(transition_base_frame_property") < 0, "result scene should not write click transition fields directly")
	_expect(actor_click_source.find("set(reaction_timer_property") < 0, "result scene should not write click reaction timer fields directly")
	_expect(actor_click_source.find("if bool(result.get(\"show_dialogue\"") < 0, "result scene should not inspect Dalji dialogue requests directly")
	_expect(actor_click_source.find("if bool(result.get(\"play_voice\"") < 0, "result scene should not inspect Dalji voice requests directly")
	_expect(source.find("get_player_victory_click_attempt") < 0, "result scene should not build player victory click attempts directly")
	_expect(source.find("get_dalji_click_attempt") < 0, "result scene should not build Dalji click attempts directly")
	_expect(source.find("get_boss_defeat_click_attempt") < 0, "result scene should not build boss click attempts directly")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _slice_function(source: String, start_pattern: String, end_pattern: String) -> String:
	var start_index: int = source.find(start_pattern)
	if start_index < 0:
		return ""
	var end_index: int = source.find(end_pattern, start_index + start_pattern.length())
	return source.substr(start_index) if end_index < 0 else source.substr(start_index, end_index - start_index)
