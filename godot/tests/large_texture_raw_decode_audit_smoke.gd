extends SceneTree

var _failed := false


func _init() -> void:
	var character_prewarm_source := FileAccess.get_file_as_string("res://scripts/ui/character_select_prewarm.gd")
	var character_preview_source := FileAccess.get_file_as_string("res://scripts/ui/character_live_preview.gd")
	var skill_cutin_source := FileAccess.get_file_as_string("res://scripts/hud/skill_cutin_overlay_host.gd")
	var lingpet_cutin_source := FileAccess.get_file_as_string("res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd")
	var battle_resources_source := FileAccess.get_file_as_string("res://scripts/resources/battle_resources.gd")
	var warmup_plan_source := FileAccess.get_file_as_string("res://scripts/core/battle_boot_warmup_plan.gd")
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
	var cutin_step_body := _function_body(skill_cutin_source, "func _prewarm_cutin_sheet_texture_threaded_step(")
	_expect(
		cutin_step_body.find("ProjectResourceLoader.prewarm_texture_threaded_step(") >= 0
			and cutin_step_body.find("true") >= 0,
		"skill cut-in staged prewarm should request imported threaded texture loading"
	)
	_verify_skill_cutin_transition_prewarm(battle_resources_source, warmup_plan_source)

	var lingpet_portal_body := _function_body(lingpet_cutin_source, "func _get_portal_texture(")
	_expect(
		lingpet_portal_body.find("ProjectResourceLoader.load_imported_texture(RESONANCE_PORTAL_PATH") >= 0,
		"lingpet acquire cut-in portal should use imported texture loading instead of raw source PNG decode"
	)
	_verify_lingpet_portal_has_no_raw_loads()

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


func _verify_skill_cutin_transition_prewarm(battle_resources_source: String, warmup_plan_source: String) -> void:
	var core_specs := _function_body(battle_resources_source, "func _get_core_texture_specs(")
	var smasher_specs := _function_body(battle_resources_source, "func _get_smasher_player_texture_specs(")
	var viper_specs := _function_body(battle_resources_source, "func _get_viper_player_texture_specs(")
	var imported_spec_body := _function_body(battle_resources_source, "func _imported_texture_spec(")
	var load_spec_body := _function_body(battle_resources_source, "func _load_texture_spec(")
	var load_core_body := _function_body(battle_resources_source, "func _load_core_textures(")
	_expect(
		core_specs.find("LINGPET_ACQUIRE_RESONANCE_PORTAL_PATH") >= 0
			and load_core_body.find("_load_imported_texture_resource(LINGPET_ACQUIRE_RESONANCE_PORTAL_PATH") >= 0,
		"lingpet acquire portal should be warmed through the character-common imported texture path"
	)
	_expect(
		smasher_specs.find("SMASHER_POWER_SMASHING_CUTIN_SHEET_PATH") >= 0
			and smasher_specs.find("SMASHER_GHOST_SMASHING_CUTIN_SHEET_PATH") >= 0
			and smasher_specs.find("SMASHER_DRIVE_CUTIN_BACKPLATE_PATH") >= 0
			and smasher_specs.find("SMASHER_DRIVE_CUTIN_PARTICLE_PATH") >= 0
			and smasher_specs.find("SMASHER_SHIELD_KITING_CUTIN_CHARACTER_PATH") >= 0,
		"selected Smasher transition texture prewarm should warm skill cut-in sheets/VFX before the cut-in host stage"
	)
	_expect(
		viper_specs.find("VIPER_PHANTOM_KICK_CUTIN_SHEET_PATH") >= 0,
		"selected Viper transition texture prewarm should warm the Phantom Kick cut-in sheet before the cut-in host stage"
	)
	_expect(
		imported_spec_body.find("\"prefer_imported\"") >= 0
			and load_spec_body.find("_load_imported_texture_resource(path") >= 0,
		"large cut-in transition specs should use imported fallback instead of raw source decode"
	)
	_expect(
		warmup_plan_source.find("\"skill_cutin_overlay_host\"") >= 0,
		"boot draw-runtime warmup should instantiate the skill cut-in host before selected-character asset prewarm"
	)
	_expect(
		warmup_plan_source.find("\"lingpet_acquire_cutin_overlay_host\"") >= 0,
		"boot draw-runtime warmup should instantiate the lingpet acquire cut-in host before selected-character asset prewarm"
	)


func _verify_lingpet_portal_has_no_raw_loads() -> void:
	const PORTAL_PATH := "res://assets/sprites/lingpet/effects/lingpet_acquire_resonance_backplate_imagegen_v1.png"
	var forbidden_patterns := [
		"load_texture(RESONANCE_PORTAL_PATH",
		"load_texture(\"%s" % PORTAL_PATH,
		"_load_texture_resource(LINGPET_ACQUIRE_RESONANCE_PORTAL_PATH",
	]
	for script_path in _collect_gd_files("res://scripts"):
		var source := FileAccess.get_file_as_string(script_path)
		for pattern in forbidden_patterns:
			_expect(
				source.find(pattern) < 0,
				"lingpet acquire portal should not use raw texture loading in %s" % script_path
			)


func _collect_gd_files(root_path: String) -> Array[String]:
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
			results.append_array(_collect_gd_files(path))
		elif entry.ends_with(".gd"):
			results.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	return results


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
