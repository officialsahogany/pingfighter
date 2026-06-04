extends SceneTree

const Stage6PillarTetris := preload("res://scripts/stages/stage6/stage6_tetriser_pillar_tetris.gd")
const STAGE6_PILLAR_DRAWER_PATH := "res://scripts/stages/stage6/stage6_tetriser_pillar_scene_drawer.gd"

var _failures: Array[String] = []


func _init() -> void:
	_test_falling_piece_uses_smooth_visual_drop()
	_test_stage6_lod_keeps_pillar_tetris_visible()
	_test_stage6_drawer_routes_pillar_tetris()

	if _failures.is_empty():
		print("stage6_tetriser_pillar_tetris_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_falling_piece_uses_smooth_visual_drop() -> void:
	var game: Object = Stage6PillarTetris.PillarTetrisGame.new()
	game.setup(6, 14, 20.0, 123)
	var start_y: int = int(game.current.get("y", 0))
	var half_step: float = float(Stage6PillarTetris.PillarTetrisGame.FALL_SPEED) * 0.5
	game.update(half_step)
	var half_offset: float = float(game.get_visual_drop_offset())
	_expect(int(game.current.get("y", 0)) == start_y, "half gravity step should keep logical row unchanged")
	_expect(half_offset > 0.0, "half gravity step should expose a positive visual drop offset")
	_expect(half_offset < float(game.block_size), "visual drop offset should stay within one cell")

	game.update(float(Stage6PillarTetris.PillarTetrisGame.FALL_SPEED) * 0.55)
	_expect(int(game.current.get("y", 0)) >= start_y + 1, "full gravity step should advance the logical row")
	_expect(float(game.get_visual_drop_offset()) < float(game.block_size) * 0.2, "visual drop should reset after a logical row advance")


func _test_stage6_lod_keeps_pillar_tetris_visible() -> void:
	_expect(float(Stage6PillarTetris.LOD_THRESHOLD) < 0.58, "pillar Tetris should remain visible at observed Stage 6 lod=0.58")


func _test_stage6_drawer_routes_pillar_tetris() -> void:
	var source := FileAccess.get_file_as_string(STAGE6_PILLAR_DRAWER_PATH)
	_expect(source.find("Stage6PillarTetris") >= 0, "Stage 6 pillar drawer should preload the pillar Tetris deco")
	_expect(source.find("stage6.pillar.tetris") >= 0, "Stage 6 pillar drawer should emit a pillar Tetris perf sample")
	_expect(source.find("pillar_tetris.draw(") >= 0, "Stage 6 pillar drawer should draw pillar Tetris between background and HUD")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
