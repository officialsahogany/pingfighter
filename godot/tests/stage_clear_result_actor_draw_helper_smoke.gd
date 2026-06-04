extends SceneTree

const StageClearResultActorDrawHelper := preload("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")

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
	_expect(source.find("static func draw_dalji_defeated") >= 0, "actor draw helper should own Dalji defeated drawing")
	_expect(source.find("static func draw_stage2_defeated") >= 0, "actor draw helper should own Stage 2 defeated drawing")
	_expect(source.find("static func draw_stage3_defeated") >= 0, "actor draw helper should own Stage 3 defeated drawing")
	_expect(source.find("static func draw_player_victory_live2d") >= 0, "actor draw helper should own player victory Live2D drawing")
	_expect(source.find("StageClearResultLayoutHelper.get_dalji_draw_rect") >= 0, "actor draw helper should resolve Dalji draw rects")
	_expect(source.find("StageClearResultLayoutHelper.get_player_victory_click_rect") >= 0, "actor draw helper should return player click rects")
	_expect(source.find("StageClearResultSheetDrawHelper.draw_reaction_sheet") >= 0, "actor draw helper should delegate reaction sheet blending")
	_expect(StageClearResultActorDrawHelper != null, "actor draw helper preload should resolve")

	StageClearResultActorDrawHelper.draw_dalji_defeated(null, null, null, {}, Vector2(1280.0, 720.0), 1.0, 14, Vector2(896.0, 896.0), 0.98)
	StageClearResultActorDrawHelper.draw_stage2_defeated(null, null, null, {}, Vector2(1280.0, 720.0), 1.0, 14, Vector2(896.0, 896.0), 0.98)
	StageClearResultActorDrawHelper.draw_stage3_defeated(null, null, null, {}, Vector2(1280.0, 720.0), 1.0, 14, Vector2(896.0, 896.0), 0.98)
	var result: Dictionary = StageClearResultActorDrawHelper.draw_player_victory_live2d(null, null, null, {}, Vector2(1280.0, 720.0), 1.0, 11, Vector2(896.0, 896.0))
	_expect(bool(result.get("drawn", false)), "player victory helper should preserve null-sheet drawn=true behavior")
	_expect(result.get("click_rect", null) is Rect2, "player victory helper should return click rect state")


func _verify_scene_delegates_actor_draws() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(source.find("StageClearResultActorDrawHelper.draw_dalji_defeated") >= 0, "result scene should delegate Dalji defeated drawing")
	_expect(source.find("StageClearResultActorDrawHelper.draw_stage2_defeated") >= 0, "result scene should delegate Stage 2 defeated drawing")
	_expect(source.find("StageClearResultActorDrawHelper.draw_stage3_defeated") >= 0, "result scene should delegate Stage 3 defeated drawing")
	_expect(source.find("StageClearResultActorDrawHelper.draw_player_victory_live2d") >= 0, "result scene should delegate player victory Live2D drawing")
	_expect(source.find("_dalji_click_rect = StageClearResultActorDrawHelper.draw_dalji_defeated") >= 0, "result scene should still store Dalji click rect")
	_expect(source.find("_player_victory_click_rect = result.get") >= 0, "result scene should still store player victory click rect")
	_expect(source.find("func _draw_stage2_defeated_boss") < 0, "result scene should not keep Stage 2 defeated draw wrappers")
	_expect(source.find("func _draw_stage3_defeated_boss") < 0, "result scene should not keep Stage 3 defeated draw wrappers")
	_expect(source.find("func _is_stage2_result_boss") < 0, "result scene should not keep trivial Stage 2 predicate wrappers")
	_expect(source.find("func _is_stage3_result_boss") < 0, "result scene should not keep trivial Stage 3 predicate wrappers")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
