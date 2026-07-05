extends SceneTree

const StageClearResultClickReactionState := preload("res://scripts/ui/stage_clear_result_click_reaction_state.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")
const StageClearResultActorDrawHelper := preload("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")
const StageClearResultActorReactionUpdateHandler := preload("res://scripts/ui/stage_clear_result_actor_reaction_update_handler.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_frames()
	_verify_direct_alpha()
	_verify_click_attempt_state()
	_verify_reaction_state_snapshot()
	_verify_scene_constant_wiring()

	if _failures.is_empty():
		print("stage_clear_result_click_reaction_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_frames() -> void:
	_expect(StageClearResultClickReactionState.get_base_frame(0.11, 0.055, 98) == 2, "base frame should advance from timer and interval")
	_expect(StageClearResultClickReactionState.get_base_frame(99.0, 0.055, 1) == 0, "base frame should clamp frame count safely")
	_expect(StageClearResultClickReactionState.get_reaction_frame(0.072, 3.5, 0.036, 98) == 2, "reaction frame should advance from click interval")
	_expect(StageClearResultClickReactionState.get_reaction_frame(4.0, 3.5, 0.036, 98) == 97, "reaction frame should hold the last frame after reaction duration")
	_expect(StageClearResultClickReactionState.get_transition_base_frame(0.05, 0.16, 7, 12) == 7, "transition base should use captured base frame during transition")
	_expect(StageClearResultClickReactionState.get_transition_base_frame(0.20, 0.16, 7, 12) == 12, "transition base should return to current base frame after transition")


func _verify_direct_alpha() -> void:
	_expect(
		_is_close(StageClearResultClickReactionState.get_reaction_alpha(0.08, 3.5, 0.16, 0.18, 0.05, 3.73), 0.5),
		"reaction alpha should smooth in during the transition"
	)
	_expect(StageClearResultClickReactionState.get_reaction_alpha(1.0, 3.5, 0.16, 0.18, 0.05, 3.73) == 1.0, "reaction alpha should hold during the main reaction")
	_expect(StageClearResultClickReactionState.get_reaction_alpha(3.60, 3.5, 0.16, 0.18, 0.05, 3.73) == 1.0, "reaction alpha should hold during return hold")
	_expect(
		StageClearResultClickReactionState.get_reaction_alpha(3.71, 3.5, 0.16, 0.18, 0.05, 3.73) < 1.0,
		"reaction alpha should fade during return fade"
	)
	_expect(StageClearResultClickReactionState.get_reaction_alpha(3.73, 3.5, 0.16, 0.18, 0.05, 3.73) == 0.0, "reaction alpha should be zero once inactive")
	_expect(StageClearResultClickReactionState.is_reaction_active(3.72, 3.73), "reaction should stay active before total duration")
	_expect(not StageClearResultClickReactionState.is_reaction_active(3.73, 3.73), "reaction should stop at total duration")
	_expect(
		is_equal_approx(StageClearResultClickReactionState.advance_reaction_timer(3.70, 3.73, 0.10), 3.73),
		"reaction timer advance should clamp to the total duration"
	)
	_expect(
		is_equal_approx(StageClearResultClickReactionState.advance_reaction_timer(3.73, 3.73, 0.10), 3.73),
		"reaction timer advance should keep inactive timers unchanged"
	)
	_expect(StageClearResultClickReactionState.is_return_blend_active(3.5, 3.5, 3.73), "return blend should start at reaction duration")


func _verify_click_attempt_state() -> void:
	var click_rect := Rect2(Vector2(10.0, 20.0), Vector2(100.0, 120.0))
	var miss: Dictionary = StageClearResultClickReactionState.get_click_reaction_attempt(
		Vector2(0.0, 0.0),
		click_rect,
		4.0,
		3.73,
		0.11,
		0.055,
		98
	)
	_expect(not bool(miss.get("handled", true)), "click attempt should ignore misses")
	_expect(not bool(miss.get("started", true)), "click attempt miss should not start reactions")

	var already_active: Dictionary = StageClearResultClickReactionState.get_click_reaction_attempt(
		click_rect.get_center(),
		click_rect,
		0.25,
		3.73,
		0.11,
		0.055,
		98
	)
	_expect(bool(already_active.get("handled", false)), "click attempt should consume hits during active reactions")
	_expect(not bool(already_active.get("started", true)), "click attempt should not restart active reactions")

	var start: Dictionary = StageClearResultClickReactionState.get_click_reaction_attempt(
		click_rect.get_center(),
		click_rect,
		3.73,
		3.73,
		0.11,
		0.055,
		98
	)
	_expect(bool(start.get("handled", false)), "click attempt should consume valid hits")
	_expect(bool(start.get("started", false)), "click attempt should start inactive reactions")
	_expect(int(start.get("transition_base_frame", -1)) == 2, "click attempt should capture the current base frame")
	_expect(_is_close(float(start.get("reaction_timer", -1.0)), 0.0), "click attempt should reset the reaction timer")


func _verify_reaction_state_snapshot() -> void:
	var state: Dictionary = StageClearResultClickReactionState.get_reaction_state(
		0.11,
		0.055,
		98,
		0.08,
		3.5,
		0.036,
		0.16,
		9,
		0.18,
		0.05,
		3.73
	)
	_expect(int(state.get("base_frame", -1)) == 2, "reaction state should expose the current base frame")
	_expect(int(state.get("transition_base_frame", -1)) == 9, "reaction state should preserve captured transition frame during blend-in")
	_expect(int(state.get("reaction_frame", -1)) == 2, "reaction state should expose the click-reaction frame")
	_expect(_is_close(float(state.get("reaction_alpha", 0.0)), 0.5), "reaction state should expose the smoothed alpha")
	_expect(bool(state.get("reaction_active", false)), "reaction state should expose active state")
	_expect(not bool(state.get("return_blend_active", true)), "reaction state should expose return-blend state")


func _verify_scene_constant_wiring() -> void:
	var scene := StageClearResultScene.new()
	scene.timer = 0.11
	_expect(
		StageClearResultClickReactionState.get_base_frame(
			scene.timer,
			StageClearResultActorDrawHelper.PLAYER_VICTORY_FRAME_INTERVAL,
			StageClearResultActorDrawHelper.PLAYER_VICTORY_FRAME_COUNT
		) == 2,
		"scene player base-frame constants should stay wired to click reaction state"
	)
	scene._player_victory_click_transition_base_frame = 9
	scene._player_victory_click_reaction_timer = 0.08
	_expect(
		StageClearResultClickReactionState.get_transition_base_frame(
			scene._player_victory_click_reaction_timer,
			StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_TRANSITION_DURATION,
			scene._player_victory_click_transition_base_frame,
			2
		) == 9,
		"scene player transition constants should stay wired to click reaction state"
	)
	_expect(
		_is_close(StageClearResultClickReactionState.get_reaction_alpha(
			scene._player_victory_click_reaction_timer,
			StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_REACTION_DURATION,
			StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_TRANSITION_DURATION,
			StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_RETURN_HOLD_DURATION,
			StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_RETURN_FADE_DURATION,
			StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_TOTAL_DURATION
		), 0.5),
		"scene player alpha constants should stay wired to click reaction state"
	)
	scene._dalji_base_timer = 0.11
	_expect(
		StageClearResultClickReactionState.get_base_frame(
			scene._dalji_base_timer,
			StageClearResultActorDrawHelper.DALJI_FRAME_INTERVAL,
			StageClearResultActorDrawHelper.DALJI_FRAME_COUNT
		) == 2,
		"scene Dalji base-frame constants should stay wired to click reaction state"
	)
	scene._dalji_click_transition_base_frame = 6
	scene._dalji_click_reaction_timer = 0.08
	_expect(
		StageClearResultClickReactionState.get_transition_base_frame(
			scene._dalji_click_reaction_timer,
			StageClearResultActorDrawHelper.DALJI_CLICK_TRANSITION_DURATION,
			scene._dalji_click_transition_base_frame,
			2
		) == 6,
		"scene Dalji transition constants should stay wired to click reaction state"
	)
	_expect(
		_is_close(StageClearResultClickReactionState.get_reaction_alpha(
			scene._dalji_click_reaction_timer,
			StageClearResultActorDrawHelper.DALJI_CLICK_REACTION_DURATION,
			StageClearResultActorDrawHelper.DALJI_CLICK_TRANSITION_DURATION,
			StageClearResultActorDrawHelper.DALJI_CLICK_RETURN_HOLD_DURATION,
			StageClearResultActorDrawHelper.DALJI_CLICK_RETURN_FADE_DURATION,
			StageClearResultActorDrawHelper.DALJI_CLICK_TOTAL_DURATION
		), 0.5),
		"scene Dalji alpha constants should stay wired to click reaction state"
	)
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var live2d_actor_helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_live2d_actor_draw_helper.gd")
	var pulse_actor_helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_pulse_actor_draw_helper.gd")
	var update_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_update_scene_handler.gd")
	var update_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_actor_reaction_update_handler.gd")
	_expect(
		live2d_actor_helper_source.find("StageClearResultClickReactionState.get_reaction_state") >= 0
		and live2d_actor_helper_source.find("StageClearResultClickReactionState.get_click_reaction_attempt") >= 0
		and pulse_actor_helper_source.find("StageClearResultClickReactionState.get_reaction_state") >= 0
		and pulse_actor_helper_source.find("StageClearResultClickReactionState.get_click_reaction_attempt") >= 0,
		"actor draw implementation helpers should call click reaction state helpers directly"
	)
	_expect(
		source.find("StageClearResultUpdateSceneHandler.update_result_scene") >= 0
		and update_scene_handler_source.find("StageClearResultActorReactionUpdateHandler.update_actor_reaction_timers") >= 0
		and update_handler_source.find("StageClearResultClickReactionState.advance_reaction_timer") >= 0
		and StageClearResultActorReactionUpdateHandler != null,
		"scene should delegate click reaction timer advancement through the update scene handler and actor update handler"
	)
	_expect(source.find("StageClearResultClickReactionState.advance_reaction_timer") < 0, "scene should not advance click reaction timers directly")
	_expect(
		source.find("func _get_player_victory_base_frame") < 0
		and source.find("func _get_player_victory_reaction_frame") < 0
		and source.find("func _get_player_victory_transition_base_frame") < 0
		and source.find("func _get_player_victory_reaction_alpha") < 0
		and source.find("func _is_player_victory_click_reaction_active") < 0
		and source.find("func _is_player_victory_click_return_blend_active") < 0
		and source.find("func _get_dalji_base_frame") < 0
		and source.find("func _get_dalji_reaction_frame") < 0
		and source.find("func _get_dalji_transition_base_frame") < 0
		and source.find("func _get_dalji_reaction_alpha") < 0
		and source.find("func _is_dalji_click_reaction_active") < 0
		and source.find("func _is_dalji_click_return_blend_active") < 0
		and source.find("func _smooth01") < 0
		and source.find("func _get_stage3_boss_defeat_base_frame") < 0,
		"scene should not keep click reaction pass-through wrappers"
	)
	scene.free()


func _is_close(actual: float, expected: float, tolerance: float = 0.001) -> bool:
	return abs(actual - expected) <= tolerance


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
