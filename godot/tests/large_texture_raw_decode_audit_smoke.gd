extends SceneTree

var _failed := false


func _init() -> void:
	var character_prewarm_source := FileAccess.get_file_as_string("res://scripts/ui/character_select_prewarm.gd")
	var character_preview_source := FileAccess.get_file_as_string("res://scripts/ui/character_live_preview.gd")
	var skill_cutin_source := FileAccess.get_file_as_string("res://scripts/hud/skill_cutin_overlay_host.gd")
	var lingpet_cache_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_visual_texture_cache.gd")
	var lingpet_panel_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_lingpet_texture_loader.gd")

	var character_sync_body := _function_body(character_prewarm_source, "func _load_job_synchronously(")
	_expect(
		character_sync_body.find("ProjectResourceLoader.load_imported_texture(path)") >= 0,
		"character-select sync fallback should not raw-decode large Live2D texture jobs"
	)

	var preview_threadable_body := _function_body(character_preview_source, "func _can_thread_load_texture(")
	_expect(
		preview_threadable_body.find("FileAccess.file_exists(path)") < 0,
		"character live preview should not reject threaded/imported loading just because the raw PNG exists"
	)
	_expect(
		preview_threadable_body.find("FileAccess.file_exists(\"%s.import\" % path)") >= 0
			and preview_threadable_body.find("ResourceLoader.exists(path, \"Texture2D\")") >= 0,
		"character live preview should allow imported or ResourceLoader-visible texture sheets to load off the main path"
	)

	var preview_request_body := _function_body(character_preview_source, "func _request_next_fullframe_sheet(")
	_expect(
		preview_request_body.find("ProjectResourceLoader.load_imported_texture(candidate_path)") >= 0,
		"character live preview fallback should prefer imported textures for large full-frame sheets"
	)

	var preview_one_shot_body := _function_body(character_preview_source, "func play_fullframe_one_shot(")
	_expect(
		preview_one_shot_body.find("ProjectResourceLoader.load_imported_texture(") >= 0,
		"character preview one-shot sheets should use imported textures instead of raw source PNG decode"
	)

	var preview_return_body := _function_body(character_preview_source, "func _start_configured_return_one_shot(")
	_expect(
		preview_return_body.find("ProjectResourceLoader.load_imported_texture(") >= 0,
		"character preview return sheets should use imported textures instead of raw source PNG decode"
	)

	var cutin_load_body := _function_body(skill_cutin_source, "func _load_cutin_sheet_texture(")
	_expect(
		cutin_load_body.find("ProjectResourceLoader.load_imported_texture(") >= 0,
		"skill cut-in sheets should use imported textures instead of raw source PNG decode"
	)

	var lingpet_get_body := _function_body(lingpet_cache_source, "func get_texture(")
	_expect(
		lingpet_get_body.find("ProjectResourceLoader.load_imported_texture(") >= 0,
		"lingpet visual cache fallback should prefer imported textures for large optional sheets"
	)

	var lingpet_panel_body := _function_body(lingpet_panel_source, "static func get_art_texture(")
	_expect(
		lingpet_panel_body.find("ProjectResourceLoader.load_imported_texture(") >= 0,
		"character-info lingpet panel art should prefer imported textures for Live2D panel sheets"
	)

	if _failed:
		quit(1)
		return
	print("large_texture_raw_decode_audit_smoke: ok")
	quit(0)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	var next_static_func := source.find("\nstatic func ", start + signature.length())
	if next_func < 0 or (next_static_func >= 0 and next_static_func < next_func):
		next_func = next_static_func
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
	quit(1)
