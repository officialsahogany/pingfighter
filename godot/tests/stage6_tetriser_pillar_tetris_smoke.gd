extends SceneTree

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Stage6PillarBackground := preload("res://scripts/stages/stage6/stage6_tetriser_pillar_background.gd")

const STAGE6_PILLAR_DRAWER_PATH := "res://scripts/stages/stage6/stage6_tetriser_pillar_scene_drawer.gd"
const STAGE6_PILLAR_BACKGROUND_PATH := "res://scripts/stages/stage6/stage6_tetriser_pillar_background.gd"
const STAGE6_BG_PATH := "res://assets/sprites/hud/stage6_tetriser_pillar_bg_imagegen_v1.png"

class Stage6DrawProbe:
	extends Node2D

	var background: Object = null
	var view_size := Vector2(1280.0, 800.0)
	var game_offset := Vector2(260.0, 25.0)
	var game_size := Vector2(760.0, 750.0)
	var draw_count := 0
	var draw_result := false

	func _draw() -> void:
		draw_count += 1
		draw_result = bool(background.draw(
			self,
			view_size,
			game_offset,
			game_size,
			760.0,
			null,
			1.0
		))


var _failures: Array[String] = []
var _probe: Stage6DrawProbe = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectResourceLoader.clear_caches()
	_test_static_background_asset_contract()
	_test_stage6_drawer_drops_live_tetris_pass()
	_test_static_background_source_contract()
	_test_static_background_draws()
	await process_frame
	await process_frame
	_expect(_probe.draw_count > 0, "Stage 6 static pillar background draw probe should receive a draw callback")
	_expect(_probe.draw_result, "Stage 6 static pillar background draw should return true")
	ProjectResourceLoader.clear_caches()

	if _failures.is_empty():
		print("stage6_tetriser_pillar_tetris_smoke: ok")
		call_deferred("_quit_with_code", 0)
	else:
		for failure in _failures:
			push_error(failure)
		call_deferred("_quit_with_code", 1)


func _test_static_background_asset_contract() -> void:
	_expect(FileAccess.file_exists(STAGE6_BG_PATH), "Stage 6 static pillar background PNG should exist")
	_expect(FileAccess.file_exists("%s.import" % STAGE6_BG_PATH), "Stage 6 static pillar background PNG should have a Godot import sidecar")
	var background: Object = Stage6PillarBackground.new()
	_expect(bool(background.prewarm_assets_step()), "Stage 6 static pillar background should complete staged prewarm")
	var status: Dictionary = background.get_asset_status()
	_expect(str(status.get("theme", "")) == "static_tetriser_ringpia", "Stage 6 background should use the static Tetriser Ringpia theme")
	_expect(str(status.get("base_texture_path", "")) == STAGE6_BG_PATH, "Stage 6 background should expose the static PNG path")
	_expect(bool(status.get("base_texture", false)), "Stage 6 background should load the static PNG")
	_expect(bool(status.get("uses_static_texture", false)), "Stage 6 background should use a static texture")
	_expect(not bool(status.get("draws_old_tetris_columns", true)), "Stage 6 background should not draw old Tetris columns")
	_expect(not bool(status.get("draws_live_tetris_wells", true)), "Stage 6 background should not draw live Tetris wells")
	_expect(not bool(status.get("has_runtime_animation", true)), "Stage 6 background should not run background animation")


func _test_stage6_drawer_drops_live_tetris_pass() -> void:
	var source := FileAccess.get_file_as_string(STAGE6_PILLAR_DRAWER_PATH)
	_expect(source.find("Stage6PillarTetris") < 0, "Stage 6 pillar drawer should not preload the retired pillar Tetris deco")
	_expect(source.find("pillar_tetris") < 0, "Stage 6 pillar drawer should not keep the retired pillar Tetris instance")
	_expect(source.find("\"stage6.pillar.tetris\"") < 0, "Stage 6 pillar drawer should not emit a retired pillar Tetris perf sample")
	_expect(source.find("stage6.pillar.background") >= 0, "Stage 6 pillar drawer should keep the background perf sample")
	_expect(source.find("stage6.pillar.hud_scene") >= 0, "Stage 6 pillar drawer should keep the shared HUD pass")


func _test_static_background_source_contract() -> void:
	var source := FileAccess.get_file_as_string(STAGE6_PILLAR_BACKGROUND_PATH)
	_expect(source.find(STAGE6_BG_PATH) >= 0, "Stage 6 background source should reference the static PNG")
	_expect(source.find("ProjectResourceLoader.load_texture") >= 0, "Stage 6 background should load through ProjectResourceLoader")
	_expect(source.find("ImageTexture.create_from_image") < 0, "Stage 6 background should not build runtime image textures")
	_expect(source.find("Time.get_ticks_msec") < 0, "Stage 6 background should not advance draw-time animation")
	_expect(source.find("\"TETRISER\"") < 0, "Stage 6 static mood background should not add text over the playfield")
	_expect(source.find("_draw_central_marquee") < 0, "Stage 6 static mood background should not draw the old marquee")
	_expect(source.find("_draw_side_architecture") < 0, "Stage 6 static mood background should not draw old Tetris side architecture")
	_expect(source.find("_draw_scan_grid") < 0, "Stage 6 static mood background should not draw a game-like Tetris grid")


func _test_static_background_draws() -> void:
	var background: Object = Stage6PillarBackground.new()
	background.prewarm_assets()
	_probe = Stage6DrawProbe.new()
	_probe.background = background
	get_root().add_child(_probe)
	_probe.queue_redraw()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _quit_with_code(exit_code: int) -> void:
	if _probe != null and is_instance_valid(_probe):
		_probe.queue_free()
	for _i in range(2):
		await process_frame
	quit(exit_code)
