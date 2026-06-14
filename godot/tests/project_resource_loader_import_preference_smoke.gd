extends SceneTree

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const IMPORTED_TEXTURE_PATH := "res://assets/sprites/hud/stage2_game_frame_rock_leaf_imagegen_v3.png"
const IMPORTED_AUDIO_PATH := "res://assets/bgm/stage2bgm.ogg"

var _failed := false


func _init() -> void:
	# This intentionally pins source-first loading; stale imported cache files
	# have broken regenerated assets before.
	ProjectResourceLoader.clear_caches()

	var texture: Texture2D = ProjectResourceLoader.load_texture(IMPORTED_TEXTURE_PATH)
	_expect(texture != null, "imported texture should load")
	_expect(texture is ImageTexture, "source texture should prefer raw ImageTexture decode before imported fallback")
	_expect(texture.resource_path == IMPORTED_TEXTURE_PATH, "imported texture should preserve the source resource path")
	_expect(ProjectResourceLoader.texture_resource_exists(IMPORTED_TEXTURE_PATH), "texture resource existence helper should accept import-visible PNG assets")
	_expect(ProjectResourceLoader.can_thread_load_texture(IMPORTED_TEXTURE_PATH), "threaded texture gate should accept import-visible PNG assets")

	var audio: AudioStream = ProjectResourceLoader.load_audio_stream(IMPORTED_AUDIO_PATH)
	_expect(audio != null, "imported audio should load")
	_expect(ProjectResourceLoader.audio_resource_exists(IMPORTED_AUDIO_PATH), "audio resource existence helper should accept import-visible audio assets")
	_verify_asset_png_import_sidecars()

	var source := FileAccess.get_file_as_string("res://scripts/resources/project_resource_loader.gd")
	var texture_body := _function_body(source, "static func load_texture(")
	var threaded_prewarm_body := _function_body(source, "static func prewarm_texture_threaded_step(")
	var audio_body := _function_body(source, "static func load_audio_stream(")
	var threaded_audio_prewarm_body := _function_body(source, "static func prewarm_audio_stream_threaded_step(")
	_expect(
		texture_body.find("Image.load_from_file") < texture_body.find("_can_load_imported_resource"),
		"texture loader should prefer raw PNG decoding before imported fallback"
	)
	_expect(
		texture_body.find("ResourceLoader.exists(path, \"Texture2D\")") > texture_body.find("_can_load_imported_resource"),
		"texture loader should accept ResourceLoader-visible textures in exported builds even when raw .import files are not visible"
	)
	_expect(
		source.find("THREADED_TEXTURE_PREWARM_MAX_MSEC") >= 0
			and source.find("THREADED_TEXTURE_PREWARM_MAX_POLLS") >= 0,
		"threaded texture prewarm should have a bounded fallback guard"
	)
	_expect(
		threaded_prewarm_body.find("_is_threaded_texture_prewarm_stale") >= 0
			and threaded_prewarm_body.find("_load_threaded_texture_fallback(path, missing_warning, failed_warning, prefer_imported_fallback)") >= 0,
		"threaded texture prewarm should fall back to source loading instead of stalling indefinitely"
	)
	_verify_threaded_prewarm_short_guard(threaded_prewarm_body)
	_expect(
		audio_body.find("load_from_file") < audio_body.find("_can_load_imported_resource"),
		"audio loader should prefer raw audio decoding before imported fallback"
	)
	_expect(
		audio_body.find("load_from_file") < audio_body.find("_get_resource_loader_audio_stream"),
		"audio loader should prefer raw audio decoding before cached ResourceLoader audio"
	)
	_expect(
		threaded_audio_prewarm_body.find("ResourceLoader.load_threaded_request(path, \"AudioStream\", true)") >= 0
			and threaded_audio_prewarm_body.find("store_audio_stream(path, stream)") >= 0,
		"threaded audio prewarm helper should load imported AudioStreams off the main thread and cache them for normal playback"
	)

	if _failed:
		# quit() is deferred, so a failing _expect() that only called quit(1) would be
		# overwritten by a later quit(0) and exit clean. Gate the success exit on the
		# failure flag so a real regression actually fails the run.
		quit(1)
		return
	print("project_resource_loader_import_preference_smoke: ok")
	quit(0)


func _verify_threaded_prewarm_short_guard(threaded_prewarm_body: String) -> void:
	_expect(
		threaded_prewarm_body.find("max_msec: int = THREADED_TEXTURE_PREWARM_MAX_MSEC") >= 0
			and threaded_prewarm_body.find("max_polls: int = THREADED_TEXTURE_PREWARM_MAX_POLLS") >= 0,
		"threaded texture prewarm should let callers set a shorter hard fallback guard"
	)
	_expect(
		threaded_prewarm_body.find("prefer_imported_fallback: bool = false") >= 0,
		"threaded texture prewarm should let result sheets opt into imported-texture fallback"
	)
	_expect(
		threaded_prewarm_body.find("emit_timeout_warning: bool = false") >= 0
			and threaded_prewarm_body.find("if emit_timeout_warning:") >= 0,
		"threaded texture prewarm should default loading-screen callers to a silent short fallback and gate the stuck-load warning behind the opt-in flag"
	)
	_expect(
		threaded_prewarm_body.find("_is_threaded_texture_prewarm_expired(max_msec, max_polls)") >= 0,
		"threaded texture prewarm should use the caller-provided hard fallback guard"
	)
	# Seal the regression: every shipped caller blocks a visible loading / transition
	# progress bar on done == true, so a long default hard bound re-freezes the bar
	# at the 81% / 86% / 92% plateaus (raising this to 30s is exactly the regression
	# that surfaced those). The long "keep slow-but-progressing loads threaded"
	# behavior must stay OPT-IN per caller, never the default.
	_expect(
		ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_MSEC <= 3000
			and ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_POLLS <= 600,
		"threaded prewarm default hard bound must stay short (<=3000ms / <=600 polls); long keep-threaded is opt-in per caller"
	)


func _verify_asset_png_import_sidecars() -> void:
	var missing_sidecars := _collect_pngs_missing_import("res://assets")
	for path in missing_sidecars:
		_expect(false, "PNG asset is missing its committed .import sidecar: %s" % path)


func _collect_pngs_missing_import(root_path: String) -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open(root_path)
	if dir == null:
		return results
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var path := "%s/%s" % [root_path, entry]
		if dir.current_is_dir():
			results.append_array(_collect_pngs_missing_import(path))
		elif entry.ends_with(".png") and not FileAccess.file_exists("%s.import" % path):
			results.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	return results


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nstatic func ", start + signature.length())
	if next_func < 0:
		next_func = source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
	quit(1)
