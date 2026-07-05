extends SceneTree

const StageClearResultSheetDrawHelper := preload("res://scripts/ui/stage_clear_result_sheet_draw_helper.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_null_guards()
	_verify_scene_delegates_sheet_draws()

	if _failures.is_empty():
		print("stage_clear_result_sheet_draw_helper_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_null_guards() -> void:
	StageClearResultSheetDrawHelper.draw_sheet_frame(null, null, 0, 1, Vector2.ONE, Rect2(), 1.0)
	StageClearResultSheetDrawHelper.draw_sheet_frame(null, GradientTexture1D.new(), 0, 1, Vector2.ONE, Rect2(), 0.0)
	StageClearResultSheetDrawHelper.draw_reaction_sheet(null, null, null, {}, 1, Vector2.ONE, Rect2(), 1.0)


func _verify_scene_delegates_sheet_draws() -> void:
	var helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_sheet_draw_helper.gd")
	var scene_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var live2d_actor_helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_live2d_actor_draw_helper.gd")
	_expect(
		helper_source.find("StageClearResultLayoutHelper.sheet_source_rect") >= 0
			and helper_source.find("draw_texture_rect_region") >= 0,
		"sheet draw helper should own source-rect calculation and texture-region drawing"
	)
	_expect(
		helper_source.find("static func draw_reaction_sheet") >= 0
			and helper_source.find("\"transition_base_frame\"") >= 0
			and helper_source.find("\"reaction_frame\"") >= 0,
		"sheet draw helper should own result actor reaction blend drawing"
	)
	_expect(
		live2d_actor_helper_source.find("StageClearResultSheetDrawHelper.draw_reaction_sheet") >= 0,
		"result Live2D actor draw helper should delegate actor reaction-blend drawing"
	)
	for removed_wrapper in [
		"func _draw_player_victory_sheet_frame",
		"func _draw_stage2_boss_result_sheet_frame",
		"func _draw_stage3_boss_result_sheet_frame",
		"func _draw_dalji_sheet_frame",
	]:
		_expect(scene_source.find(removed_wrapper) < 0, "result scene should not keep sheet draw wrapper %s" % removed_wrapper)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
