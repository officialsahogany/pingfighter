extends SceneTree

const StageClearResultActorPresenter := preload("res://scripts/ui/stage_clear_result_actor_presenter.gd")
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
		11
	)
	_expect(int(boss_context.get("current_stage", 0)) == 3, "boss context should include current stage")
	_expect(float(boss_context.get("timer", 0.0)) == 4.5, "boss context should include scene timer")
	_expect(float(boss_context.get("dalji_base_timer", 0.0)) == 1.5, "boss context should include Dalji base timer")
	_expect(int(boss_context.get("dalji_click_transition_base_frame", 0)) == 5, "boss context should include Dalji transition frame")
	_expect(float(boss_context.get("stage2_boss_defeat_click_reaction_timer", 0.0)) == 0.3, "boss context should include Stage 2 timer")
	_expect(int(boss_context.get("stage2_boss_defeat_click_transition_base_frame", 0)) == 8, "boss context should include Stage 2 base frame")
	_expect(float(boss_context.get("stage3_boss_defeat_click_reaction_timer", 0.0)) == 0.6, "boss context should include Stage 3 timer")
	_expect(int(boss_context.get("stage3_boss_defeat_click_transition_base_frame", 0)) == 11, "boss context should include Stage 3 base frame")


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


func _verify_presenter_apply_contract() -> void:
	var dalji_rect := Rect2(Vector2(10.0, 20.0), Vector2(120.0, 140.0))
	var current_dalji_rect := Rect2(Vector2(1.0, 2.0), Vector2(30.0, 40.0))
	var defeated_apply: Dictionary = StageClearResultActorPresenter.get_defeated_boss_draw_apply_result(
		{"dalji_click_rect": dalji_rect},
		current_dalji_rect
	)
	_expect(defeated_apply.get("dalji_click_rect", Rect2()) == dalji_rect, "defeated-boss apply helper should apply Dalji click rects")

	var missing_defeated_apply: Dictionary = StageClearResultActorPresenter.get_defeated_boss_draw_apply_result(
		{},
		current_dalji_rect
	)
	_expect(missing_defeated_apply.get("dalji_click_rect", Rect2()) == current_dalji_rect, "defeated-boss apply helper should keep current Dalji rect on no-op draws")

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
		{"dalji_click_rect": dalji_rect},
		current_dalji_rect
	)
	var defeated_field_payload: Dictionary = defeated_scene_apply.get("field_payload", {}) as Dictionary
	_expect(defeated_field_payload.get("_dalji_click_rect", Rect2()) == dalji_rect, "defeated scene apply helper should map Dalji click rects to scene fields")

	var scene := StageClearResultScene.new()
	scene._apply_scene_apply_result(player_scene_apply)
	scene._apply_scene_apply_result(defeated_scene_apply)
	_expect(scene.get("_player_victory_click_rect") == player_rect, "scene field payload helper should apply player click rects")
	_expect(scene.get("_dalji_click_rect") == dalji_rect, "scene field payload helper should apply Dalji click rects")
	scene.free()


func _verify_presenter_source() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_actor_presenter.gd")
	_expect(source.find("static func get_player_victory_draw_context") >= 0, "actor presenter should expose player draw context assembly")
	_expect(source.find("static func get_defeated_boss_draw_context") >= 0, "actor presenter should expose defeated-boss draw context assembly")
	_expect(source.find("static func draw_player_victory_live2d") >= 0, "actor presenter should expose player Live2D draw orchestration")
	_expect(source.find("static func draw_defeated_boss") >= 0, "actor presenter should expose defeated-boss draw orchestration")
	_expect(source.find("static func get_player_victory_draw_apply_result") >= 0, "actor presenter should expose player draw apply payloads")
	_expect(source.find("static func get_defeated_boss_draw_apply_result") >= 0, "actor presenter should expose defeated-boss draw apply payloads")
	_expect(source.find("static func get_player_victory_draw_scene_apply_result") >= 0, "actor presenter should expose player scene field apply payloads")
	_expect(source.find("static func get_defeated_boss_draw_scene_apply_result") >= 0, "actor presenter should expose defeated-boss scene field apply payloads")
	_expect(source.find("StageClearResultActorDrawHelper.draw_player_victory_live2d") >= 0, "actor presenter should delegate player sheet drawing")
	_expect(source.find("StageClearResultActorDrawHelper.draw_dalji_defeated") >= 0, "actor presenter should delegate Dalji sheet drawing")
	_expect(source.find("StageClearResultActorDrawHelper.draw_stage2_defeated") >= 0, "actor presenter should delegate Stage 2 sheet drawing")
	_expect(source.find("StageClearResultActorDrawHelper.draw_stage3_defeated") >= 0, "actor presenter should delegate Stage 3 sheet drawing")
	_expect(source.find("get_boss_defeat_reaction_state") >= 0, "actor presenter should assemble boss reaction state")
	_expect(source.find("get_dalji_reaction_state") >= 0, "actor presenter should assemble Dalji reaction state")
	_expect(source.find("get_player_victory_reaction_state") >= 0, "actor presenter should assemble player reaction state")
	_expect(source.find("\"dalji_click_rect\"") >= 0, "actor presenter should return Dalji click rect state")


func _verify_scene_delegates_actor_presenter() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(source.find("StageClearResultActorPresenter.draw_player_victory_live2d") >= 0, "result scene should delegate player Live2D drawing to the presenter")
	_expect(source.find("StageClearResultActorPresenter.draw_defeated_boss") >= 0, "result scene should delegate defeated-boss drawing to the presenter")
	_expect(source.find("StageClearResultActorPresenter.get_player_victory_draw_context") >= 0, "result scene should delegate player draw context assembly to the presenter")
	_expect(source.find("StageClearResultActorPresenter.get_defeated_boss_draw_context") >= 0, "result scene should delegate defeated-boss draw context assembly to the presenter")
	_expect(source.find("StageClearResultActorPresenter.get_player_victory_draw_scene_apply_result") >= 0, "result scene should delegate player scene field apply payloads to the presenter")
	_expect(source.find("StageClearResultActorPresenter.get_defeated_boss_draw_scene_apply_result") >= 0, "result scene should delegate defeated-boss scene field apply payloads to the presenter")
	_expect(source.find("func _apply_scene_apply_result") >= 0, "result scene should centralize scene apply-result application")
	_expect(source.find("func _apply_scene_field_payload") < 0, "result scene should not keep the retired direct field-payload wrapper")
	_expect(source.find("func _get_field_payload_from_apply_result") < 0, "result scene should not keep the retired payload-unwrapping wrapper")
	_expect(source.find("StageClearResultActorDrawHelper.draw_player_victory_live2d") < 0, "result scene should not draw player Live2D directly")
	_expect(source.find("StageClearResultActorDrawHelper.draw_stage2_defeated") < 0, "result scene should not draw Stage 2 defeated actors directly")
	_expect(source.find("StageClearResultActorDrawHelper.draw_stage3_defeated") < 0, "result scene should not draw Stage 3 defeated actors directly")
	_expect(source.find("_dalji_click_rect = StageClearResultActorDrawHelper.draw_dalji_defeated") < 0, "result scene should not draw Dalji defeated actors directly")
	_expect(source.find("_get_actor_player_victory_draw_context") >= 0, "result scene should keep a thin player draw context wrapper")
	_expect(source.find("_get_actor_defeated_draw_context") >= 0, "result scene should keep a thin defeated-boss draw context wrapper")
	_expect(source.find("_dalji_click_rect = result.get(\"dalji_click_rect\"") < 0, "result scene should not inspect defeated-boss click rect results directly")
	_expect(source.find("_dalji_click_rect = apply_result.get(\"dalji_click_rect\"") < 0, "result scene should not write Dalji click rects from presenter apply payloads directly")
	_expect(source.find("_player_victory_click_rect = apply_result.get(\"player_victory_click_rect\"") < 0, "result scene should not write player click rects from presenter apply payloads directly")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
