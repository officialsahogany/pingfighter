extends SceneTree

const StageClearResultStaticDrawHelper := preload("res://scripts/ui/stage_clear_result_static_draw_helper.gd")
const StageClearResultDrawSceneHandler := preload("res://scripts/ui/stage_clear_result_draw_scene_handler.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_helper_contract()
	_verify_scene_delegates_static_draw()

	if _failures.is_empty():
		print("stage_clear_result_static_draw_helper_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_contract() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_static_draw_helper.gd")
	_expect(source.find("static func draw_background") >= 0, "static draw helper should own result background drawing")
	_expect(source.find("static func draw_dalji_click_dialogue") >= 0, "static draw helper should own Dalji click dialogue drawing")
	_expect(source.find("static func draw_player_victory_fallback") >= 0, "static draw helper should own player-victory fallback drawing")
	_expect(source.find("static func draw_footer") >= 0, "static draw helper should own result footer drawing")
	_expect(source.find("StageClearResultLayoutHelper.cover_source_rect") >= 0, "background drawing should use cover source rect math")
	_expect(source.find("StageClearResultShapeHelper.draw_panel") >= 0, "static helper should delegate panel drawing")
	_expect(source.find("StageClearResultSheetDrawHelper.draw_sheet_frame") >= 0, "player fallback should delegate sheet-frame drawing")
	_expect(source.find("StageClearResultTextLayoutHelper.draw_text") >= 0, "static helper should delegate text drawing")
	_expect(StageClearResultStaticDrawHelper != null, "static draw helper preload should resolve")

	StageClearResultStaticDrawHelper.draw_background(null, null, Vector2.ZERO)
	StageClearResultStaticDrawHelper.draw_dalji_click_dialogue(null, null, Vector2.ZERO, 1.0, 0.0, 0.2, "")
	StageClearResultStaticDrawHelper.draw_player_victory_fallback(
		null,
		null,
		Vector2.ZERO,
		1.0,
		0.0,
		null,
		0.055,
		98,
		11,
		Vector2(896.0, 896.0),
		"",
		"",
		""
	)
	StageClearResultStaticDrawHelper.draw_footer(null, null, Vector2.ZERO, 1.0, 1)


func _verify_scene_delegates_static_draw() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var draw_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_draw_scene_handler.gd")
	var actor_draw_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_actor_draw_scene_handler.gd")
	_expect(source.find("StageClearResultDrawSceneHandler.draw_result_scene") >= 0, "result scene should delegate top-level drawing through the draw scene handler")
	_expect(draw_scene_handler_source.find("StageClearResultStaticDrawHelper.draw_background") >= 0, "draw scene handler should delegate background drawing")
	_expect(draw_scene_handler_source.find("StageClearResultStaticDrawHelper.draw_dalji_click_dialogue") >= 0, "draw scene handler should delegate Dalji dialogue drawing")
	_expect(draw_scene_handler_source.find("StageClearResultStaticDrawHelper.draw_footer") >= 0, "draw scene handler should delegate footer drawing")
	_expect(source.find("StageClearResultStaticDrawHelper.draw_background") < 0, "result scene should not call static background drawing directly")
	_expect(source.find("StageClearResultStaticDrawHelper.draw_dalji_click_dialogue") < 0, "result scene should not call static dialogue drawing directly")
	_expect(source.find("StageClearResultStaticDrawHelper.draw_footer") < 0, "result scene should not call static footer drawing directly")
	_expect(draw_scene_handler_source.find("StageClearResultActorDrawSceneHandler.draw_player_victory") >= 0, "draw scene handler should delegate player-victory drawing through the actor draw scene handler")
	_expect(actor_draw_scene_handler_source.find("StageClearResultStaticDrawHelper.draw_player_victory_fallback") >= 0, "actor draw scene handler should delegate player-victory fallback drawing")
	_expect(StageClearResultDrawSceneHandler != null, "draw scene handler preload should resolve")
	_expect(source.find("func _draw_background") < 0, "result scene should not keep background drawing wrappers")
	_expect(source.find("func _draw_dalji_click_dialogue") < 0, "result scene should not keep Dalji dialogue drawing wrappers")
	_expect(source.find("func _draw_footer") < 0, "result scene should not keep footer drawing wrappers")
	_expect(source.find("func _draw_player_victory") < 0, "result scene should not keep player-victory draw fanout wrappers")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
