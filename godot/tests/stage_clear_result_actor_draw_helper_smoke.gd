extends SceneTree

const StageClearResultActorDrawHelper := preload("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")
const StageClearResultActorPresenter := preload("res://scripts/ui/stage_clear_result_actor_presenter.gd")
const StageClearResultLive2DActorDrawHelper := preload("res://scripts/ui/stage_clear_result_live2d_actor_draw_helper.gd")
const StageClearResultPulseActorDrawHelper := preload("res://scripts/ui/stage_clear_result_pulse_actor_draw_helper.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_helper_contract()
	_verify_scene_delegates_actor_draws()

	if _failures.is_empty():
		print("stage_clear_result_actor_draw_helper_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_contract() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")
	var live2d_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_live2d_actor_draw_helper.gd")
	var pulse_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_pulse_actor_draw_helper.gd")
	_expect(source.find("static func draw_dalji_defeated") >= 0, "actor draw helper should expose Dalji defeated drawing")
	_expect(source.find("static func draw_stage2_defeated") >= 0, "actor draw helper should expose Stage 2 defeated drawing")
	_expect(source.find("static func draw_stage3_defeated") >= 0, "actor draw helper should expose Stage 3 defeated drawing")
	_expect(source.find("static func draw_stage4_ponk_defeated") >= 0, "actor draw helper should expose Stage 4 Ponk defeated drawing")
	_expect(source.find("static func draw_stage4_ponk_result_fallback") < 0, "actor draw helper should not expose Stage 4 Ponk fallback drawing")
	_expect(source.find("static func draw_stage5_hongryun_result_fallback") >= 0, "actor draw helper should expose Stage 5 Hongryun result fallback drawing")
	_expect(live2d_source.find("static func draw_dalji_defeated") >= 0, "Live2D actor draw helper should own Dalji defeated drawing")
	_expect(live2d_source.find("static func draw_stage2_defeated") >= 0, "Live2D actor draw helper should own Stage 2 defeated drawing")
	_expect(live2d_source.find("static func draw_stage3_defeated") >= 0, "Live2D actor draw helper should own Stage 3 defeated drawing")
	_expect(live2d_source.find("static func draw_stage4_ponk_defeated") >= 0, "Live2D actor draw helper should own Stage 4 Ponk defeated drawing")
	_expect(live2d_source.find("static func draw_player_victory_live2d") >= 0, "Live2D actor draw helper should own player victory Live2D drawing")
	_expect(source.find("StageClearResultLive2DActorDrawHelper.draw_dalji_defeated") >= 0, "actor draw helper should delegate Dalji drawing to the Live2D actor helper")
	_expect(source.find("StageClearResultLive2DActorDrawHelper.draw_stage2_defeated") >= 0, "actor draw helper should delegate Stage 2 drawing to the Live2D actor helper")
	_expect(source.find("StageClearResultLive2DActorDrawHelper.draw_stage3_defeated") >= 0, "actor draw helper should delegate Stage 3 drawing to the Live2D actor helper")
	_expect(source.find("StageClearResultLive2DActorDrawHelper.draw_stage4_ponk_defeated") >= 0, "actor draw helper should delegate Stage 4 Ponk drawing to the Live2D actor helper")
	_expect(source.find("StageClearResultLive2DActorDrawHelper.draw_player_victory_live2d") >= 0, "actor draw helper should delegate player victory drawing to the Live2D actor helper")
	_expect(pulse_source.find("static func draw_pulse_result_sheet") >= 0, "pulse actor draw helper should keep reused result fallback pulse drawing in one helper")
	_expect(pulse_source.find("static func get_pulse_result_reaction_state") >= 0, "pulse actor draw helper should keep reused result fallback reaction states in one helper")
	_expect(pulse_source.find("static func get_pulse_result_click_attempt") >= 0, "pulse actor draw helper should keep reused result fallback click attempts in one helper")
	_expect(source.find("StageClearResultPulseActorDrawHelper.draw_stage4_ponk_result_fallback") < 0, "actor draw helper should not delegate Stage 4 drawing to the pulse actor helper")
	_expect(source.find("StageClearResultPulseActorDrawHelper.draw_stage5_hongryun_result_fallback") >= 0, "actor draw helper should delegate Stage 5 fallback drawing to the pulse actor helper")
	_expect(source.find("StageClearResultPulseActorDrawHelper.draw_stage6_tetriser_defeated") >= 0, "actor draw helper should delegate Stage 6 fallback drawing to the pulse actor helper")
	_expect(pulse_source.find("StageClearResultSheetDrawHelper.draw_sheet_frame") >= 0, "pulse actor draw helper should own fallback sheet-frame drawing")
	_expect(source.find("static func draw_player_victory_live2d") >= 0, "actor draw helper should expose player victory Live2D drawing")
	_expect(source.find("static func get_dalji_reaction_state") >= 0, "actor draw helper should expose Dalji reaction state")
	_expect(source.find("static func get_player_victory_reaction_state") >= 0, "actor draw helper should expose player reaction state")
	_expect(source.find("static func get_boss_defeat_reaction_state") >= 0, "actor draw helper should expose boss reaction state")
	_expect(source.find("static func get_stage4_ponk_reaction_state") < 0, "actor draw helper should not expose Stage 4 Ponk fallback reaction state")
	_expect(source.find("static func get_stage5_hongryun_reaction_state") >= 0, "actor draw helper should expose Stage 5 Hongryun reaction state")
	_expect(source.find("static func get_stage6_tetriser_reaction_state") >= 0, "actor draw helper should expose Stage 6 Tetriser reaction state")
	_expect(source.find("static func get_player_victory_click_attempt") >= 0, "actor draw helper should expose player click attempts")
	_expect(source.find("static func get_dalji_click_attempt") >= 0, "actor draw helper should expose Dalji click attempts")
	_expect(source.find("static func get_boss_defeat_click_attempt") >= 0, "actor draw helper should expose boss click attempts")
	_expect(source.find("static func get_stage4_ponk_click_attempt") < 0, "actor draw helper should not expose Stage 4 Ponk fallback click attempts")
	_expect(source.find("static func get_stage5_hongryun_click_attempt") >= 0, "actor draw helper should expose Stage 5 Hongryun click attempts")
	_expect(source.find("static func get_stage6_tetriser_click_attempt") >= 0, "actor draw helper should expose Stage 6 Tetriser click attempts")
	_expect(live2d_source.find("StageClearResultLayoutHelper.get_dalji_draw_rect") >= 0, "Live2D actor draw helper should resolve Dalji draw rects")
	_expect(live2d_source.find("StageClearResultLayoutHelper.get_player_victory_click_rect") >= 0, "Live2D actor draw helper should return player click rects")
	_expect(live2d_source.find("StageClearResultSheetDrawHelper.draw_reaction_sheet") >= 0, "Live2D actor draw helper should delegate reaction sheet blending")
	_expect(StageClearResultActorDrawHelper != null, "actor draw helper preload should resolve")
	_expect(StageClearResultLive2DActorDrawHelper != null, "Live2D actor draw helper preload should resolve")
	_expect(StageClearResultPulseActorDrawHelper != null, "pulse actor draw helper preload should resolve")
	_expect(
		int(StageClearResultActorDrawHelper.get_player_victory_reaction_state(0.2, 0.1, 0).get("base_frame", -1)) == 3,
		"player reaction helper should calculate base frames"
	)
	var click_attempt: Dictionary = StageClearResultActorDrawHelper.get_dalji_click_attempt(
		Vector2(640.0, 360.0),
		Vector2(1280.0, 720.0),
		1.0,
		StageClearResultActorDrawHelper.DALJI_CLICK_TOTAL_DURATION,
		0.0
	)
	_expect(click_attempt.get("click_rect", null) is Rect2, "click attempt helper should return a click rect")
	_expect(click_attempt.get("attempt", null) is Dictionary, "click attempt helper should return attempt state")
	_expect(StageClearResultActorDrawHelper.STAGE5_HONGRYUN_RESULT_FRAME_COUNT == 8, "Stage 5 Hongryun fallback should expose the 8-frame victory sheet contract")
	_expect(StageClearResultActorDrawHelper.STAGE5_HONGRYUN_RESULT_GRID_COLS == 4, "Stage 5 Hongryun fallback should expose the 4-column victory sheet contract")
	_expect(StageClearResultActorDrawHelper.STAGE5_HONGRYUN_RESULT_CELL_SIZE == Vector2(384.0, 384.0), "Stage 5 Hongryun fallback should expose the victory sheet cell size")
	_expect(StageClearResultActorDrawHelper.STAGE6_TETRISER_DEFEAT_FRAME_COUNT == 8, "Stage 6 Tetriser fallback should expose the 8-frame defeat sheet contract")
	var stage4_click_attempt: Dictionary = StageClearResultActorDrawHelper.get_boss_defeat_click_attempt(
		4,
		Vector2(180.0, 520.0),
		Vector2(1920.0, 1080.0),
		1.0,
		StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		0.50
	)
	_expect(stage4_click_attempt.get("click_rect", null) is Rect2, "Stage 4 Ponk click attempt should return a click rect")
	_expect(bool((stage4_click_attempt.get("attempt", {}) as Dictionary).get("handled", false)), "Stage 4 Ponk click attempt should handle clicks inside the Live2D actor rect")
	var stage5_click_attempt: Dictionary = StageClearResultActorDrawHelper.get_stage5_hongryun_click_attempt(
		Vector2(200.0, 540.0),
		Vector2(1920.0, 1080.0),
		1.0,
		StageClearResultActorDrawHelper.STAGE5_HONGRYUN_CLICK_TOTAL_DURATION,
		0.50
	)
	_expect(stage5_click_attempt.get("click_rect", null) is Rect2, "Stage 5 Hongryun click attempt should return a click rect")
	_expect(bool((stage5_click_attempt.get("attempt", {}) as Dictionary).get("handled", false)), "Stage 5 Hongryun click attempt should handle clicks inside the fallback actor rect")
	var stage6_click_attempt: Dictionary = StageClearResultActorDrawHelper.get_stage6_tetriser_click_attempt(
		Vector2(200.0, 540.0),
		Vector2(1920.0, 1080.0),
		1.0,
		StageClearResultActorDrawHelper.STAGE6_TETRISER_CLICK_TOTAL_DURATION,
		0.50
	)
	_expect(stage6_click_attempt.get("click_rect", null) is Rect2, "Stage 6 Tetriser click attempt should return a click rect")
	_expect(bool((stage6_click_attempt.get("attempt", {}) as Dictionary).get("handled", false)), "Stage 6 Tetriser click attempt should handle clicks inside the fallback actor rect")

	StageClearResultActorDrawHelper.draw_dalji_defeated(null, null, null, {}, Vector2(1280.0, 720.0), 1.0, 14, Vector2(896.0, 896.0), 0.98)
	StageClearResultActorDrawHelper.draw_stage2_defeated(null, null, null, {}, Vector2(1280.0, 720.0), 1.0, 14, Vector2(896.0, 896.0), 0.98)
	StageClearResultActorDrawHelper.draw_stage3_defeated(null, null, null, {}, Vector2(1280.0, 720.0), 1.0, 14, Vector2(896.0, 896.0), 0.98)
	StageClearResultActorDrawHelper.draw_stage4_ponk_defeated(null, null, null, {}, Vector2(1280.0, 720.0), 1.0, 14, Vector2(896.0, 896.0), 0.98)
	StageClearResultActorDrawHelper.draw_stage5_hongryun_result_fallback(null, null, 0.0, Vector2(1280.0, 720.0), 1.0, 0.98)
	StageClearResultActorDrawHelper.draw_stage6_tetriser_defeated(null, null, 0.0, Vector2(1280.0, 720.0), 1.0, 0.98)
	var result: Dictionary = StageClearResultActorDrawHelper.draw_player_victory_live2d(null, null, null, {}, Vector2(1280.0, 720.0), 1.0, 11, Vector2(896.0, 896.0))
	_expect(bool(result.get("drawn", false)), "player victory helper should preserve null-sheet drawn=true behavior")
	_expect(result.get("click_rect", null) is Rect2, "player victory helper should return click rect state")


func _verify_scene_delegates_actor_draws() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var draw_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_draw_scene_handler.gd")
	var scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_actor_draw_scene_handler.gd")
	var presenter_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_actor_presenter.gd")
	_expect(StageClearResultActorPresenter != null, "actor presenter preload should resolve")
	_expect(source.find("StageClearResultDrawSceneHandler.draw_result_scene") >= 0, "result scene should delegate top-level drawing through the draw scene handler")
	_expect(draw_scene_handler_source.find("StageClearResultActorDrawSceneHandler.draw_defeated_boss") >= 0, "draw scene handler should delegate defeated-boss drawing through the actor draw scene handler")
	_expect(scene_handler_source.find("StageClearResultActorPresenter.draw_defeated_boss") >= 0, "actor draw scene handler should delegate defeated-boss drawing through the actor presenter")
	_expect(presenter_source.find("StageClearResultActorDrawHelper.draw_dalji_defeated") >= 0, "actor presenter should delegate Dalji defeated drawing")
	_expect(presenter_source.find("StageClearResultActorDrawHelper.draw_stage2_defeated") >= 0, "actor presenter should delegate Stage 2 defeated drawing")
	_expect(presenter_source.find("StageClearResultActorDrawHelper.draw_stage3_defeated") >= 0, "actor presenter should delegate Stage 3 defeated drawing")
	_expect(presenter_source.find("StageClearResultActorDrawHelper.draw_stage4_ponk_defeated") >= 0, "actor presenter should delegate Stage 4 Ponk defeated drawing")
	_expect(presenter_source.find("StageClearResultActorDrawHelper.draw_stage4_ponk_result_fallback") < 0, "actor presenter should not route Stage 4 Ponk through fallback drawing")
	_expect(presenter_source.find("StageClearResultActorDrawHelper.draw_stage5_hongryun_result_fallback") >= 0, "actor presenter should delegate Stage 5 Hongryun result fallback drawing")
	_expect(draw_scene_handler_source.find("StageClearResultActorDrawSceneHandler.draw_player_victory") >= 0, "draw scene handler should delegate player victory drawing through the actor draw scene handler")
	_expect(scene_handler_source.find("StageClearResultActorPresenter.draw_player_victory_live2d") >= 0, "actor draw scene handler should delegate player victory Live2D drawing through the actor presenter")
	_expect(presenter_source.find("StageClearResultActorDrawHelper.draw_player_victory_live2d") >= 0, "actor presenter should delegate player victory Live2D drawing")
	_expect(scene_handler_source.find("StageClearResultActorPresenter.get_defeated_boss_draw_scene_apply_result") >= 0, "actor draw scene handler should store Dalji click rect through actor presenter scene apply payloads")
	_expect(scene_handler_source.find("StageClearResultActorPresenter.get_player_victory_draw_scene_apply_result") >= 0, "actor draw scene handler should store player victory click rect through actor presenter scene apply payloads")
	_expect(source.find("func _draw_stage2_defeated_boss") < 0, "result scene should not keep Stage 2 defeated draw wrappers")
	_expect(source.find("func _draw_stage3_defeated_boss") < 0, "result scene should not keep Stage 3 defeated draw wrappers")
	_expect(source.find("func _draw_defeated_boss") < 0, "result scene should not keep defeated-boss draw fanout wrappers")
	_expect(source.find("func _draw_player_victory") < 0, "result scene should not keep player-victory draw fanout wrappers")
	_expect(source.find("func _is_stage2_result_boss") < 0, "result scene should not keep trivial Stage 2 predicate wrappers")
	_expect(source.find("func _is_stage3_result_boss") < 0, "result scene should not keep trivial Stage 3 predicate wrappers")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
