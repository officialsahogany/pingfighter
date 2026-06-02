extends SceneTree

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Stage1PillarBackground := preload("res://scripts/stages/stage1/stage1_pillar_background.gd")

const VIEW_SIZE := Vector2(1280.0, 800.0)
const GAME_OFFSET := Vector2(260.0, 0.0)
const GAME_SIZE := Vector2(760.0, 750.0)
const MAX_PREWARM_CALLS := 1024

var _failures: Array[String] = []


func _init() -> void:
	ProjectResourceLoader.clear_caches()
	_verify_stage1_background_prewarm_completes()
	_verify_stage1_background_uses_short_threaded_guard()

	if _failures.is_empty():
		print("stage1_pillar_background_prewarm_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage1_background_prewarm_completes() -> void:
	var background := Stage1PillarBackground.new()
	var calls := 0
	var completed := false
	while calls < MAX_PREWARM_CALLS:
		if bool(background.prewarm_assets_step(VIEW_SIZE, GAME_OFFSET, GAME_SIZE)):
			completed = true
			break
		calls += 1

	_expect(completed, "Stage 1 background prewarm should leave the 48% finish-resources step")
	_expect(background.hanji_texture != null, "Stage 1 background should prewarm the hanji texture")
	_expect(background.tree_sprite_texture != null, "Stage 1 background should prewarm the side tree texture")
	_expect(background.cloud_sprite_texture != null, "Stage 1 background should prewarm the cloud texture")
	_expect(background.butterfly_sheet_texture != null, "Stage 1 background should prewarm the butterfly sheet")
	_expect(int(background.get("_prewarm_assets_step_index")) == 0, "completed Stage 1 background prewarm should reset its step index")


func _verify_stage1_background_uses_short_threaded_guard() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_pillar_background.gd")
	_expect(source.find("PREWARM_TEXTURE_FALLBACK_MSEC") >= 0, "Stage 1 background should define a short threaded texture fallback")
	_expect(source.find("PREWARM_TEXTURE_FALLBACK_POLLS") >= 0, "Stage 1 background should define a poll fallback")
	_expect(
		source.find("ProjectResourceLoader.prewarm_texture_threaded_step(\n\t\tpath,\n\t\t\"\",\n\t\t\"\",\n\t\tPREWARM_TEXTURE_FALLBACK_MSEC,\n\t\tPREWARM_TEXTURE_FALLBACK_POLLS") >= 0,
		"Stage 1 background should pass the short guard to threaded texture prewarm"
	)
	_expect(source.find("PREWARM_TEXTURE_FALLBACK_POLLS,\n\t\tfalse") >= 0, "Stage 1 expected fallback should not emit timeout warnings during loading")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
