extends SceneTree

const StageClearResultActorPresenter := preload("res://scripts/ui/stage_clear_result_actor_presenter.gd")
const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")
const StageClearResultFieldApplySceneHandler := preload("res://scripts/ui/stage_clear_result_field_apply_scene_handler.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_presenter_contract()
	_verify_context_builder_contract()
	_verify_presenter_apply_contract()
	_verify_presenter_source()
	_verify_scene_delegates_actor_presenter()

	if _failures.is_empty():
		print("stage_clear_result_actor_presenter_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_context_builder_contract() -> void:
	var player_context: Dictionary = StageClearResultActorPresenter.get_player_victory_draw_context(
		2.5,
		0.4,
		7,
		null,
		null
	)
	_expect(float(player_context.get("timer", 0.0)) == 2.5, "player context should include scene timer")
	_expect(float(player_context.get("player_victory_click_reaction_timer", 0.0)) == 0.4, "player context should include reaction timer")
	_expect(int(player_context.get("player_victory_click_transition_base_frame", 0)) == 7, "player context should include transition base frame")
	_expect(player_context.has("player_victory_sheet"), "player context should include base sheet key")
	_expect(player_context.has("player_victory_click_reaction_sheet"), "player context should include reaction sheet key")

	var boss_context: Dictionary = StageClearResultActorPresenter.get_defeated_boss_draw_context(
		3,
		4.5,
		1.5,
		0.2,
		5,
		null,
		null,
		null,
		null,
		0.3,
		8,
		null,
		null,
		0.6,
		11,
		null,
		null,
		0.22,
		5,
		null,
		0.12,
		4,
		null,
		0.32,
		6
	)
	_expect(int(boss_context.get("current_stage", 0)) == 3, "boss context should include current stage")
	_expect(float(boss_context.get("timer", 0.0)) == 4.5, "boss context should include scene timer")
	_expect(float(boss_context.get("dalji_base_timer", 0.0)) == 1.5, "boss context should include Dalji base timer")
	_expect(int(boss_context.get("dalji_click_transition_base_frame", 0)) == 5, "boss context should include Dalji transition frame")
	_expect(float(boss_context.get("stage2_boss_defeat_click_reaction_timer", 0.0)) == 0.3, "boss context should include Stage 2 timer")
	_expect(int(boss_context.get("stage2_boss_defeat_click_transition_base_frame", 0)) == 8, "boss context should include Stage 2 base frame")
	_expect(float(boss_context.get("stage3_boss_defeat_click_reaction_timer", 0.0)) == 0.6, "boss context should include Stage 3 timer")
	_expect(int(boss_context.get("stage3_boss_defeat_click_transition_base_frame", 0)) == 11, "boss context should include Stage 3 base frame")
	_expect(boss_context.has("stage6_boss_defeat_sheet"), "boss context should include Stage 6 Tetriser defeat sheet key")
	_expect(float(boss_context.get("stage6_boss_defeat_click_reaction_timer", 0.0)) == 0.12, "boss context should include Stage 6 timer")
	_expect(int(boss_context.get("stage6_boss_defeat_click_transition_base_frame", 0)) == 4, "boss context should include Stage 6 base frame")
	_expect(boss_context.has("stage4_ponk_boss_defeat_live2d_sheet"), "boss context should include Stage 4 Ponk Live2D result sheet key")
	_expect(boss_context.has("stage4_ponk_boss_defeat_click_reaction_sheet"), "boss context should include Stage 4 Ponk click sheet key")
	_expect(float(boss_context.get("stage4_ponk_boss_defeat_click_reaction_timer", 0.0)) == 0.22, "boss context should include Stage 4 Ponk timer")
	_expect(int(boss_context.get("stage4_ponk_boss_defeat_click_transition_base_frame", 0)) == 5, "boss context should include Stage 4 Ponk base frame")
	_expect(boss_context.has("stage5_hongryun_result_sheet"), "boss context should include Stage 5 Hongryun fallback result sheet key")
	_expect(float(boss_context.get("stage5_hongryun_result_click_reaction_timer", 0.0)) == 0.32, "boss context should include Stage 5 Hongryun timer")
	_expect(int(boss_context.get("stage5_hongryun_result_click_transition_base_frame", 0)) == 6, "boss context should include Stage 5 Hongryun base frame")


func _verify_presenter_contract() -> void:
	_expect(StageClearResultActorPresenter != null, "actor presenter preload should resolve")
	var missing_player: Dictionary = StageClearResultActorPresenter.draw_player_victory_live2d(
		null,
		Vector2(1280.0, 720.0),
		1.0,
		{}
	)
	_expect(bool(missing_player.get("drawn", false)), "actor presenter should preserve null-sheet player drawn state")
	_expect(missing_player.get("click_rect", null) is Rect2, "actor presenter should return player click rect state")
	var missing_dalji: Dictionary = StageClearResultActorPresenter.draw_defeated_boss(
		null,
		Vector2(1280.0, 720.0),
		1.0,
		{"current_stage": 1}
	)
	_expect(missing_dalji.is_empty(), "actor presenter should no-op when Dalji sheet is missing")
	var missing_stage2: Dictionary = StageClearResultActorPresenter.draw_defeated_boss(
		null,
		Vector2(1280.0, 720.0),
		1.0,
		{"current_stage": 2}
	)
	_expect(missing_stage2.is_empty(), "actor presenter should no-op when Stage 2 sheet is missing")
	var missing_stage4: Dictionary = StageClearResultActorPresenter.draw_defeated_boss(
		null,
		Vector2(1280.0, 720.0),
		1.0,
		{"current_stage": 4}
	)
	_expect(missing_stage4.is_empty(), "actor presenter should no-op when Stage 4 Ponk Live2D sheet is missing")
	var missing_stage5: Dictionary = StageClearResultActorPresenter.draw_defeated_boss(
		null,
		Vector2(1280.0, 720.0),
		1.0,
		{"current_stage": 5}
	)
	_expect(missing_stage5.is_empty(), "actor presenter should no-op when Stage 5 Hongryun fallback sheet is missing")
	var stage5_sheet := load(StageClearResultAssetLoader.STAGE5_HONGRYUN_RESULT_SHEET_PATH) as Texture2D
	var stage5_result: Dictionary = StageClearResultActorPresenter.draw_defeated_boss(
		null,
		Vector2(1280.0, 720.0),
		1.0,
		{
			"current_stage": 5,
			"stage5_hongryun_result_sheet": stage5_sheet,
			"timer": 0.50,
		}
	)
	_expect(stage5_result.get("stage5_hongryun_result_rect", null) is Rect2, "actor presenter should expose Stage 5 Hongryun fallback draw rect state")
	_expect(stage5_result.get("stage5_hongryun_result_click_rect", null) is Rect2, "actor presenter should expose Stage 5 Hongryun fallback click rect state")
	var stage6_sheet := load(StageClearResultAssetLoader.STAGE6_BOSS_DEFEAT_SHEET_PATH) as Texture2D
	var stage6_result: Dictionary = StageClearResultActorPresenter.draw_defeated_boss(
		null,
		Vector2(1280.0, 720.0),
		1.0,
		{
			"current_stage": 6,
			"stage6_boss_defeat_sheet": stage6_sheet,
			"timer": 0.25,
		}
	)
	_expect(stage6_result.get("stage6_boss_defeat_rect", null) is Rect2, "actor presenter should expose Stage 6 Tetriser defeated draw rect state")
	_expect(stage6_result.get("stage6_boss_defeat_click_rect", null) is Rect2, "actor presenter should expose Stage 6 Tetriser click rect state")


func _verify_presenter_apply_contract() -> void:
	var dalji_rect := Rect2(Vector2(10.0, 20.0), Vector2(120.0, 140.0))
	var current_dalji_rect := Rect2(Vector2(1.0, 2.0), Vector2(30.0, 40.0))
	var defeated_apply: Dictionary = StageClearResultActorPresenter.get_defeated_boss_draw_apply_result(
		{
			"dalji_click_rect": dalji_rect,
			"stage6_boss_defeat_click_rect": Rect2(Vector2(20.0, 30.0), Vector2(90.0, 100.0)),
			"stage4_ponk_boss_defeat_click_rect": Rect2(Vector2(40.0, 50.0), Vector2(70.0, 80.0)),
			"stage5_hongryun_result_click_rect": Rect2(Vector2(60.0, 70.0), Vector2(80.0, 90.0)),
		},
		current_dalji_rect,
		Rect2(Vector2(3.0, 4.0), Vector2(50.0, 60.0)),
		Rect2(Vector2(7.0, 8.0), Vector2(30.0, 40.0)),
		Rect2(Vector2(9.0, 10.0), Vector2(20.0, 30.0))
	)
	_expect(defeated_apply.get("dalji_click_rect", Rect2()) == dalji_rect, "defeated-boss apply helper should apply Dalji click rects")
	_expect(defeated_apply.get("stage6_boss_defeat_click_rect", Rect2()) == Rect2(Vector2(20.0, 30.0), Vector2(90.0, 100.0)), "defeated-boss apply helper should apply Stage 6 click rects")
	_expect(defeated_apply.get("stage4_ponk_boss_defeat_click_rect", Rect2()) == Rect2(Vector2(40.0, 50.0), Vector2(70.0, 80.0)), "defeated-boss apply helper should apply Stage 4 Ponk click rects")
	_expect(defeated_apply.get("stage5_hongryun_result_click_rect", Rect2()) == Rect2(Vector2(60.0, 70.0), Vector2(80.0, 90.0)), "defeated-boss apply helper should apply Stage 5 Hongryun click rects")

	var missing_defeated_apply: Dictionary = StageClearResultActorPresenter.get_defeated_boss_draw_apply_result(
		{},
		current_dalji_rect,
		Rect2(Vector2(3.0, 4.0), Vector2(50.0, 60.0)),
		Rect2(Vector2(7.0, 8.0), Vector2(30.0, 40.0)),
		Rect2(Vector2(9.0, 10.0), Vector2(20.0, 30.0))
	)
	_expect(missing_defeated_apply.get("dalji_click_rect", Rect2()) == current_dalji_rect, "defeated-boss apply helper should keep current Dalji rect on no-op draws")
	_expect(missing_defeated_apply.get("stage6_boss_defeat_click_rect", Rect2()) == Rect2(Vector2(3.0, 4.0), Vector2(50.0, 60.0)), "defeated-boss apply helper should keep current Stage 6 rect on no-op draws")
	_expect(missing_defeated_apply.get("stage4_ponk_boss_defeat_click_rect", Rect2()) == Rect2(Vector2(7.0, 8.0), Vector2(30.0, 40.0)), "defeated-boss apply helper should keep current Stage 4 Ponk rect on no-op draws")
	_expect(missing_defeated_apply.get("stage5_hongryun_result_click_rect", Rect2()) == Rect2(Vector2(9.0, 10.0), Vector2(20.0, 30.0)), "defeated-boss apply helper should keep current Stage 5 Hongryun rect on no-op draws")

	var player_rect := Rect2(Vector2(30.0, 40.0), Vector2(150.0, 160.0))
	var player_apply: Dictionary = StageClearResultActorPresenter.get_player_victory_draw_apply_result({
		"click_rect": player_rect,
		"drawn": false,
	})
	_expect(player_apply.get("player_victory_click_rect", Rect2()) == player_rect, "player apply helper should apply victory click rects")
	_expect(not bool(player_apply.get("drawn", true)), "player apply helper should preserve false drawn state")

	var missing_player_apply: Dictionary = StageClearResultActorPresenter.get_player_victory_draw_apply_result({})
	_expect(missing_player_apply.get("player_victory_click_rect", Rect2()) == Rect2(), "player apply helper should clear missing click rects")
	_expect(bool(missing_player_apply.get("drawn", false)), "player apply helper should default missing drawn state to true")

	var player_scene_apply: Dictionary = StageClearResultActorPresenter.get_player_victory_draw_scene_apply_result({
		"click_rect": player_rect,
		"drawn": false,
	})
	var player_field_payload: Dictionary = player_scene_apply.get("field_payload", {}) as Dictionary
	_expect(player_field_payload.get("_player_victory_click_rect", Rect2()) == player_rect, "player scene apply helper should map click rects to scene fields")
	_expect(not bool(player_scene_apply.get("drawn", true)), "player scene apply helper should preserve drawn state")

	var defeated_scene_apply: Dictionary = StageClearResultActorPresenter.get_defeated_boss_draw_scene_apply_result(
		{
			"dalji_click_rect": dalji_rect,
			"stage6_boss_defeat_click_rect": Rect2(Vector2(20.0, 30.0), Vector2(90.0, 100.0)),
			"stage4_ponk_boss_defeat_click_rect": Rect2(Vector2(40.0, 50.0), Vector2(70.0, 80.0)),
			"stage5_hongryun_result_click_rect": Rect2(Vector2(60.0, 70.0), Vector2(80.0, 90.0)),
		},
		current_dalji_rect,
		Rect2(Vector2(3.0, 4.0), Vector2(50.0, 60.0)),
		Rect2(Vector2(7.0, 8.0), Vector2(30.0, 40.0)),
		Rect2(Vector2(9.0, 10.0), Vector2(20.0, 30.0))
	)
	var defeated_field_payload: Dictionary = defeated_scene_apply.get("field_payload", {}) as Dictionary
	_expect(defeated_field_payload.get("_dalji_click_rect", Rect2()) == dalji_rect, "defeated scene apply helper should map Dalji click rects to scene fields")
	_expect(defeated_field_payload.get("_stage6_boss_defeat_click_rect", Rect2()) == Rect2(Vector2(20.0, 30.0), Vector2(90.0, 100.0)), "defeated scene apply helper should map Stage 6 click rects to scene fields")
	_expect(defeated_field_payload.get("_stage4_ponk_boss_defeat_click_rect", Rect2()) == Rect2(Vector2(40.0, 50.0), Vector2(70.0, 80.0)), "defeated scene apply helper should map Stage 4 Ponk click rects to scene fields")
	_expect(defeated_field_payload.get("_stage5_hongryun_result_click_rect", Rect2()) == Rect2(Vector2(60.0, 70.0), Vector2(80.0, 90.0)), "defeated scene apply helper should map Stage 5 Hongryun click rects to scene fields")

	var scene := StageClearResultScene.new()
	StageClearResultFieldApplySceneHandler.apply_scene_apply_result(scene, player_scene_apply)
	StageClearResultFieldApplySceneHandler.apply_scene_apply_result(scene, defeated_scene_apply)
	_expect(scene.get("_player_victory_click_rect") == player_rect, "scene field payload helper should apply player click rects")
	_expect(scene.get("_dalji_click_rect") == dalji_rect, "scene field payload helper should apply Dalji click rects")
	_expect(scene.get("_stage6_boss_defeat_click_rect") == Rect2(Vector2(20.0, 30.0), Vector2(90.0, 100.0)), "scene field payload helper should apply Stage 6 click rects")
	_expect(scene.get("_stage4_ponk_boss_defeat_click_rect") == Rect2(Vector2(40.0, 50.0), Vector2(70.0, 80.0)), "scene field payload helper should apply Stage 4 Ponk click rects")
	_expect(scene.get("_stage5_hongryun_result_click_rect") == Rect2(Vector2(60.0, 70.0), Vector2(80.0, 90.0)), "scene field payload helper should apply Stage 5 Hongryun click rects")
	scene.free()


func _verify_presenter_source() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_actor_presenter.gd")
	_expect(source.find("static func get_player_victory_draw_context") >= 0, "actor presenter should expose player draw context assembly")
	_expect(source.find("static func get_defeated_boss_draw_context") >= 0, "actor presenter should expose defeated-boss draw context assembly")
	_expect(source.find("static func draw_player_victory_live2d") >= 0, "actor presenter should expose player Live2D draw orchestration")
	_expect(source.find("static func draw_defeated_boss") >= 0, "actor presenter should expose defeated-boss draw orchestration")
	_expect(source.find("static func _get_stage_result_fallback_config") >= 0, "actor presenter should centralize remaining Stage 5/6 fallback routing config")
	_expect(source.find("static func _draw_stage_result_fallback_actor") >= 0, "actor presenter should route remaining Stage 5/6 fallback drawing through one helper")
	_expect(source.find("static func get_player_victory_draw_apply_result") >= 0, "actor presenter should expose player draw apply payloads")
	_expect(source.find("static func get_defeated_boss_draw_apply_result") >= 0, "actor presenter should expose defeated-boss draw apply payloads")
	_expect(source.find("static func _get_defeated_boss_click_rect_payload_configs") >= 0, "actor presenter should centralize defeated-boss click rect payload config")
	_expect(source.find("static func _get_click_rect_apply_result") >= 0, "actor presenter should build defeated-boss click rect apply payloads through one helper")
	_expect(source.find("static func _get_click_rect_field_payload") >= 0, "actor presenter should build defeated-boss scene field payloads through one helper")
	_expect(source.find("static func get_player_victory_draw_scene_apply_result") >= 0, "actor presenter should expose player scene field apply payloads")
	_expect(source.find("static func get_defeated_boss_draw_scene_apply_result") >= 0, "actor presenter should expose defeated-boss scene field apply payloads")
	_expect(source.find("StageClearResultActorDrawHelper.draw_player_victory_live2d") >= 0, "actor presenter should delegate player sheet drawing")
	_expect(source.find("StageClearResultActorDrawHelper.draw_dalji_defeated") >= 0, "actor presenter should delegate Dalji sheet drawing")
	_expect(source.find("StageClearResultActorDrawHelper.draw_stage2_defeated") >= 0, "actor presenter should delegate Stage 2 sheet drawing")
	_expect(source.find("StageClearResultActorDrawHelper.draw_stage3_defeated") >= 0, "actor presenter should delegate Stage 3 sheet drawing")
	_expect(source.find("StageClearResultActorDrawHelper.draw_stage4_ponk_defeated") >= 0, "actor presenter should delegate Stage 4 Ponk Live2D drawing")
	_expect(source.find("StageClearResultActorDrawHelper.draw_stage5_hongryun_result_fallback") >= 0, "actor presenter should delegate Stage 5 Hongryun fallback sheet drawing")
	_expect(source.find("StageClearResultActorDrawHelper.draw_stage6_tetriser_defeated") >= 0, "actor presenter should delegate Stage 6 Tetriser defeat sheet drawing")
	_expect(source.find("get_boss_defeat_reaction_state") >= 0, "actor presenter should assemble boss reaction state")
	_expect(source.find("get_dalji_reaction_state") >= 0, "actor presenter should assemble Dalji reaction state")
	_expect(source.find("get_player_victory_reaction_state") >= 0, "actor presenter should assemble player reaction state")
	_expect(source.find("\"dalji_click_rect\"") >= 0, "actor presenter should return Dalji click rect state")


func _verify_scene_delegates_actor_presenter() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var draw_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_draw_scene_handler.gd")
	var scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_actor_draw_scene_handler.gd")
	_expect(source.find("StageClearResultDrawSceneHandler.draw_result_scene") >= 0, "result scene should delegate top-level drawing to the draw scene handler")
	_expect(draw_scene_handler_source.find("StageClearResultActorDrawSceneHandler.draw_player_victory") >= 0, "draw scene handler should delegate player victory drawing to the actor draw scene handler")
	_expect(draw_scene_handler_source.find("StageClearResultActorDrawSceneHandler.draw_defeated_boss") >= 0, "draw scene handler should delegate defeated-boss drawing to the actor draw scene handler")
	_expect(source.find("StageClearResultActorPresenter.") < 0, "result scene should not call the actor presenter directly")
	_expect(scene_handler_source.find("StageClearResultActorPresenter.draw_player_victory_live2d") >= 0, "actor draw scene handler should delegate player Live2D drawing to the presenter")
	_expect(scene_handler_source.find("StageClearResultActorPresenter.draw_defeated_boss") >= 0, "actor draw scene handler should delegate defeated-boss drawing to the presenter")
	_expect(scene_handler_source.find("StageClearResultActorPresenter.get_player_victory_draw_context") >= 0, "actor draw scene handler should delegate player draw context assembly to the presenter")
	_expect(scene_handler_source.find("StageClearResultActorPresenter.get_defeated_boss_draw_context") >= 0, "actor draw scene handler should delegate defeated-boss draw context assembly to the presenter")
	_expect(scene_handler_source.find("StageClearResultActorPresenter.get_player_victory_draw_scene_apply_result") >= 0, "actor draw scene handler should delegate player scene field apply payloads to the presenter")
	_expect(scene_handler_source.find("StageClearResultActorPresenter.get_defeated_boss_draw_scene_apply_result") >= 0, "actor draw scene handler should delegate defeated-boss scene field apply payloads to the presenter")
	_expect(source.find("func _apply_scene_apply_result") < 0, "result scene should not keep scene apply-result pass-through wrappers")
	_expect(source.find("func _apply_scene_field_payload") < 0, "result scene should not keep the retired direct field-payload wrapper")
	_expect(source.find("func _get_field_payload_from_apply_result") < 0, "result scene should not keep the retired payload-unwrapping wrapper")
	_expect(source.find("StageClearResultActorDrawHelper.draw_player_victory_live2d") < 0, "result scene should not draw player Live2D directly")
	_expect(source.find("StageClearResultActorDrawHelper.draw_stage2_defeated") < 0, "result scene should not draw Stage 2 defeated actors directly")
	_expect(source.find("StageClearResultActorDrawHelper.draw_stage3_defeated") < 0, "result scene should not draw Stage 3 defeated actors directly")
	_expect(source.find("_dalji_click_rect = StageClearResultActorDrawHelper.draw_dalji_defeated") < 0, "result scene should not draw Dalji defeated actors directly")
	_expect(source.find("_get_actor_player_victory_draw_context") < 0, "result scene should not keep player draw context wrappers")
	_expect(source.find("_get_actor_defeated_draw_context") < 0, "result scene should not keep defeated-boss draw context wrappers")
	_expect(source.find("func _draw_defeated_boss") < 0, "result scene should not keep defeated-boss draw fanout wrappers")
	_expect(source.find("func _draw_player_victory") < 0, "result scene should not keep player-victory draw fanout wrappers")
	_expect(scene_handler_source.find("static func get_player_victory_draw_context") >= 0, "actor draw scene handler should own player scene-context glue")
	_expect(scene_handler_source.find("static func get_defeated_boss_draw_context") >= 0, "actor draw scene handler should own defeated-boss scene-context glue")
	_expect(source.find("_dalji_click_rect = result.get(\"dalji_click_rect\"") < 0, "result scene should not inspect defeated-boss click rect results directly")
	_expect(source.find("_dalji_click_rect = apply_result.get(\"dalji_click_rect\"") < 0, "result scene should not write Dalji click rects from presenter apply payloads directly")
	_expect(source.find("_player_victory_click_rect = apply_result.get(\"player_victory_click_rect\"") < 0, "result scene should not write player click rects from presenter apply payloads directly")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
