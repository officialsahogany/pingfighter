extends SceneTree

const Stage6PillarTetris := preload("res://scripts/stages/stage6/stage6_tetriser_pillar_tetris.gd")
const Stage6PillarBackground := preload("res://scripts/stages/stage6/stage6_tetriser_pillar_background.gd")
const STAGE6_PILLAR_DRAWER_PATH := "res://scripts/stages/stage6/stage6_tetriser_pillar_scene_drawer.gd"
const STAGE6_PILLAR_TETRIS_PATH := "res://scripts/stages/stage6/stage6_tetriser_pillar_tetris.gd"
const STAGE6_PILLAR_BACKGROUND_PATH := "res://scripts/stages/stage6/stage6_tetriser_pillar_background.gd"

var _failures: Array[String] = []


func _init() -> void:
	_test_falling_piece_uses_smooth_visual_drop()
	_test_stage6_lod_keeps_pillar_tetris_visible()
	_test_stage6_drawer_routes_pillar_tetris()
	_test_retro_tetris_ringpia_background_contract()
	_test_arcade_well_contract()

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


func _test_retro_tetris_ringpia_background_contract() -> void:
	var background: Object = Stage6PillarBackground.new()
	var status: Dictionary = background.get_asset_status()
	_expect(str(status.get("theme", "")) == "retro_tetris_ringpia", "Stage 6 background should use the retro Tetris + Ringpia theme")
	_expect(bool(status.get("draws_old_tetris_columns", false)), "Stage 6 background should draw old-Tetris-style side columns")
	# Single focal panel: the live Tetris well owns the framed cabinet / NEXT / STATS /
	# score. The background must NOT stack a second decorative panel on top of it, or
	# the pillar reads as cluttered (competing frames, duplicate STATS, clashing blocks).
	_expect(not bool(status.get("dense_cabinet_fill", true)), "Stage 6 background must not stack a dense cabinet panel over the live Tetris well")
	var source := FileAccess.get_file_as_string(STAGE6_PILLAR_BACKGROUND_PATH)
	_expect(source.find("_draw_panel_backing") < 0, "Stage 6 background should not redraw a cabinet panel backing behind the Tetris well")
	_expect(source.find("_draw_cabinet_fill_blocks") < 0, "Stage 6 background should not draw cabinet fill blocks that clash with real tetrominoes")
	_expect(source.find("TORCH_POSITIONS") < 0, "retro Stage 6 background should remove the previous torch port")
	_expect(source.find("_draw_motes") < 0, "retro Stage 6 background should remove the previous mote port")
	_expect(source.find("ImageTexture.create_from_image") < 0, "retro Stage 6 background should not build runtime gradient textures")
	_expect(source.find("TETRISER") >= 0, "retro Stage 6 background should draw the Tetriser marquee")


func _test_arcade_well_contract() -> void:
	var source := FileAccess.get_file_as_string(STAGE6_PILLAR_TETRIS_PATH)
	_expect(source.find("TARGET_COLUMNS := 10") >= 0, "pillar Tetris should use a classic 10-column well")
	_expect(source.find("CLASSIC_COLORS") >= 0, "pillar Tetris should use classic tetromino colors")
	_expect(source.find("\"SCORE %d\"") >= 0, "pillar Tetris should draw a score plinth")
	_expect(source.find("\"LINES %d\"") >= 0, "pillar Tetris should draw line count text")
	_expect(source.find("\"RINGPIA 6\"") >= 0, "pillar Tetris should mix in Ringpia identity")
	_expect(source.find("WELL_BG") >= 0, "pillar Tetris should draw black arcade wells")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
