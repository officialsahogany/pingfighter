extends SceneTree

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Stage1PillarBackground := preload("res://scripts/stages/stage1/stage1_pillar_background.gd")

const VIEW_SIZE := Vector2(1280.0, 800.0)
const GAME_OFFSET := Vector2(260.0, 0.0)
const GAME_SIZE := Vector2(760.0, 750.0)
const MAX_PREWARM_CALLS := 1024
const STAGE1_BACKGROUND_SOURCE_PATH := "res://scripts/stages/stage1/stage1_pillar_background.gd"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectResourceLoader.clear_caches()
	await _verify_stage1_background_prewarm_completes()
	_verify_stage1_background_uses_short_threaded_guard()
	ProjectResourceLoader.clear_caches()
	await process_frame

	if _failures.is_empty():
		print("stage1_pillar_background_prewarm_smoke: ok")
		call_deferred("_quit_with_code", 0)
	else:
		for failure in _failures:
			push_error(failure)
		call_deferred("_quit_with_code", 1)


func _verify_stage1_background_prewarm_completes() -> void:
	var background := Stage1PillarBackground.new()
	var calls := 0
	var completed := false
	while calls < MAX_PREWARM_CALLS:
		if bool(background.prewarm_assets_step(VIEW_SIZE, GAME_OFFSET, GAME_SIZE)):
			completed = true
			break
		calls += 1
		await process_frame

	_expect(completed, "Stage 1 background prewarm should leave the 48% finish-resources step")
	_expect(background.hanji_texture != null, "Stage 1 background should prewarm the hanji texture")
	_expect(background.tree_sprite_texture != null, "Stage 1 background should prewarm the side tree texture")
	_expect(background.cloud_sprite_texture != null, "Stage 1 background should prewarm the cloud texture")
	_expect(background.butterfly_sheet_texture != null, "Stage 1 background should prewarm the butterfly sheet")
	_expect(int(background.get("_prewarm_assets_step_index")) == 0, "completed Stage 1 background prewarm should reset its step index")
	background.hanji_texture = null
	background.tree_sprite_texture = null
	background.cloud_sprite_texture = null
	background.butterfly_sheet_texture = null
	background.set("ambient_state", null)
	background.set("layer_renderer", null)
	background = null


func _verify_stage1_background_uses_short_threaded_guard() -> void:
	_expect(
		int(Stage1PillarBackground.PREWARM_TEXTURE_FALLBACK_MSEC) == 1800,
		"Stage 1 background should keep a short threaded texture fallback"
	)
	_expect(
		int(Stage1PillarBackground.PREWARM_TEXTURE_FALLBACK_POLLS) == 240,
		"Stage 1 background should keep a bounded threaded texture poll fallback"
	)
	var source := _read_text_file(STAGE1_BACKGROUND_SOURCE_PATH)
	var prewarm_call_index := source.find("ProjectResourceLoader.prewarm_texture_threaded_step(")
	_expect(
		prewarm_call_index >= 0,
		"Stage 1 background should call the shared threaded texture prewarm helper"
	)
	var prewarm_callsite := ""
	if prewarm_call_index >= 0:
		prewarm_callsite = source.substr(prewarm_call_index, 420)
	_expect(
		prewarm_callsite.find("PREWARM_TEXTURE_FALLBACK_MSEC") >= 0
		and prewarm_callsite.find("PREWARM_TEXTURE_FALLBACK_POLLS") >= 0,
		"Stage 1 background prewarm should pass its bounded fallback constants to the threaded helper"
	)
	_expect(
		prewarm_callsite.find("false") >= 0,
		"Stage 1 expected fallback should not emit timeout warnings during loading"
	)


func _read_text_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _quit_with_code(exit_code: int) -> void:
	for _i in range(3):
		await process_frame
	quit(exit_code)
