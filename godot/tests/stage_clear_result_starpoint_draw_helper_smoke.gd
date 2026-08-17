extends SceneTree

const StageClearResultStarpointDrawHelper := preload("res://scripts/ui/stage_clear_result_starpoint_draw_helper.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_helper_source()
	_verify_scene_no_longer_owns_starpoint_primitives()

	if _failures.is_empty():
		print("stage_clear_result_starpoint_draw_helper_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_source() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_starpoint_draw_helper.gd")
	_expect(source.find("static func draw_ingame_starpoint_visual") >= 0, "starpoint compatibility helper should own in-game muhon primitive drawing")
	_expect(source.find("static func draw_muhon_wisps") >= 0, "starpoint compatibility helper should own muhon wisps")
	_expect(source.find("StageClearResultShapeHelper.draw_soul_flame") >= 0, "muhon primitive drawing should delegate soul-flame geometry")
	_expect(source.find("StageClearResultShapeHelper.draw_star_polygon") < 0, "muhon primitive drawing should not retain star polygons")
	_expect(source.find("StageClearResultTextLayoutHelper.draw_centered_text") >= 0, "starpoint primitive drawing should delegate amount text")
	_expect(source.find("canvas.draw_polyline") >= 0, "muhon wisps should draw through the provided canvas")
	_expect(StageClearResultStarpointDrawHelper != null, "starpoint draw helper preload should resolve")

	StageClearResultStarpointDrawHelper.draw_ingame_starpoint_visual(null, {}, true)
	StageClearResultStarpointDrawHelper.draw_muhon_wisps(null, Vector2.ZERO, 12.0, {})


func _verify_scene_no_longer_owns_starpoint_primitives() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(source.find("func _draw_ingame_starpoint_visual") < 0, "result scene should not keep starpoint primitive drawing wrappers")
	_expect(source.find("func _draw_muhon_wisps") < 0, "result scene should not keep muhon wisp drawing wrappers")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
