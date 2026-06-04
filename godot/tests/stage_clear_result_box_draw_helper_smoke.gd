extends SceneTree

const StageClearResultBoxDrawHelper := preload("res://scripts/ui/stage_clear_result_box_draw_helper.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_helper_source()
	_verify_scene_delegates_box_draw()

	if _failures.is_empty():
		print("stage_clear_result_box_draw_helper_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_source() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_draw_helper.gd")
	_expect(source.find("static func draw_floating_result_box") >= 0, "box draw helper should own complete floating result-box drawing")
	_expect(source.find("StageClearResultRewardFloatDrawHelper.draw_reward_label") >= 0, "box draw helper should own opened reward label sequencing")
	_expect(source.find("StageClearResultShapeHelper.draw_box_hover_glow") >= 0, "box draw helper should own floating box hover glow drawing")
	_expect(source.find("static func draw_result_box_sheet_frame") >= 0, "box draw helper should own result-box sheet frame drawing")
	_expect(source.find("canvas.draw_texture_rect_region") >= 0, "box draw helper should render result-box sheets through texture regions")
	_expect(source.find("return true") >= 0, "box draw helper should report successful sheet frame drawing")
	_expect(source.find("static func draw_result_box_fallback") >= 0, "box draw helper should own result-box fallback drawing")
	_expect(source.find("StageClearResultClickReactionState.smooth01") >= 0, "fallback box lid should use the shared easing helper")
	_expect(source.find("canvas.draw_set_transform") >= 0, "fallback box drawing should use the provided canvas transform")
	_expect(source.find("canvas.draw_rect") >= 0, "fallback box drawing should draw body and lid rects")
	_expect(StageClearResultBoxDrawHelper != null, "box draw helper preload should resolve")

	_expect(
		not StageClearResultBoxDrawHelper.draw_result_box_sheet_frame(
			null,
			null,
			Vector2.ZERO,
			0,
			1,
			Vector2.ONE,
			1.0,
			0.0,
			1.0
		),
		"box draw helper should reject null canvas / texture sheet draw requests"
	)
	StageClearResultBoxDrawHelper.draw_floating_result_box(null, {}, {})

	StageClearResultBoxDrawHelper.draw_result_box_fallback(
		null,
		Vector2.ZERO,
		30.0,
		20.0,
		0.0,
		1.0,
		false,
		1.0,
		"idle",
		0.0
	)


func _verify_scene_delegates_box_draw() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(source.find("StageClearResultBoxDrawHelper.draw_floating_result_box") >= 0, "result scene should delegate floating result-box drawing")
	_expect(source.find("StageClearResultBoxDrawHelper.draw_result_box_sheet_frame") < 0, "result scene should not directly own result-box sheet frame drawing")
	_expect(source.find("StageClearResultRewardFloatDrawHelper") < 0, "result scene should not directly own floating reward-label draw sequencing")
	_expect(source.find("StageClearResultShapeHelper.draw_box_hover_glow") < 0, "result scene should not directly draw floating box hover glow")
	_expect(source.find("var col: int = frame_index % RESULT_BOX_SHEET_GRID_COLS") < 0, "result scene should not keep result-box sheet column math")
	_expect(source.find("func _draw_result_box_fallback") < 0, "result scene should not keep result-box fallback drawing wrappers")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
