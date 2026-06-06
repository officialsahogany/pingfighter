extends SceneTree

const StageClearResultActorClickHandler := preload("res://scripts/ui/stage_clear_result_actor_click_handler.gd")
const StageClearResultActorDrawHelper := preload("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")
const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_player_victory_click()
	_verify_dalji_click()
	_verify_boss_defeat_click()
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
	scene._apply_scene_field_payload({
		"_player_victory_click_rect": player_rect,
		"_dalji_click_rect": dalji_rect,
		"_dalji_dialogue_timer": 1.55,
		"_player_victory_click_transition_base_frame": 9,
		"_player_victory_click_reaction_timer": 0.0,
	})
	_expect(scene.get("_player_victory_click_rect") == player_rect, "scene field helper should apply player click rect fields")
	_expect(scene.get("_dalji_click_rect") == dalji_rect, "scene field helper should apply Dalji click rect fields")
	_expect(abs(float(scene.get("_dalji_dialogue_timer")) - 1.55) <= 0.001, "scene field helper should apply Dalji dialogue timers")
	_expect(int(scene.get("_player_victory_click_transition_base_frame")) == 9, "scene field helper should apply transition frame fields")
	_expect(abs(float(scene.get("_player_victory_click_reaction_timer")) - 0.0) <= 0.001, "scene field helper should apply reaction timer fields")
	scene.free()


func _verify_scene_delegates_actor_clicks() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_actor_click_handler.gd")
	var actor_click_source: String = _slice_function(source, "func _handle_player_victory_click", "func _play_dalji_click_voice")
	_expect(source.find("StageClearResultActorClickHandler.handle_player_victory_click") >= 0, "result scene should delegate player victory clicks")
	_expect(source.find("StageClearResultActorClickHandler.handle_dalji_click") >= 0, "result scene should delegate Dalji clicks")
	_expect(source.find("StageClearResultActorClickHandler.handle_boss_defeat_click") >= 0, "result scene should delegate boss defeat clicks")
	_expect(source.find("StageClearResultActorClickHandler.get_click_reaction_scene_apply_result") >= 0, "result scene should delegate click reaction scene field apply payloads")
	_expect(source.find("StageClearResultActorClickHandler.get_player_victory_click_rect_scene_apply_result") >= 0, "result scene should delegate player click-rect scene field apply payloads")
	_expect(source.find("StageClearResultActorClickHandler.get_dalji_click_rect_scene_apply_result") >= 0, "result scene should delegate Dalji click-rect scene field apply payloads")
	_expect(source.find("StageClearResultActorClickHandler.get_dalji_click_side_effect_scene_apply_result") >= 0, "result scene should delegate Dalji click side-effect scene field apply payloads")
	_expect(source.find("func _apply_scene_field_payload") >= 0, "result scene should centralize scene field payload application")
	_expect(source.find("func _get_field_payload_from_apply_result") >= 0, "result scene should unwrap nested scene field payloads in one helper")
	_expect(helper_source.find("static func get_click_reaction_scene_apply_result") >= 0, "actor click helper should expose click reaction scene field payloads")
	_expect(helper_source.find("static func get_player_victory_click_rect_scene_apply_result") >= 0, "actor click helper should expose player click-rect scene field payloads")
	_expect(helper_source.find("static func get_dalji_click_rect_scene_apply_result") >= 0, "actor click helper should expose Dalji click-rect scene field payloads")
	_expect(helper_source.find("static func get_dalji_click_side_effect_scene_apply_result") >= 0, "actor click helper should expose Dalji side-effect scene field payloads")
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
