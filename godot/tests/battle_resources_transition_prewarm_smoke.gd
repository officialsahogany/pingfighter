extends SceneTree

const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_stage1_smasher_transition_prewarm_is_fine_grained()
	await _verify_stage1_gaksital_transition_prewarm_uses_variant_sheets()
	await _verify_stage1_pododaejang_transition_prewarm_uses_variant_sheets()
	await _verify_stage2_smasher_transition_prewarm_keeps_boss_aliases()
	await _cleanup_runtime_resources()

	if _failures.is_empty():
		print("battle_resources_transition_prewarm_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage1_smasher_transition_prewarm_is_fine_grained() -> void:
	var resources: Object = BattleResources.new()
	var context := {
		"selected_character_type": "smasher",
		"current_stage": 1,
		"include_result_sheets": false,
		"include_all_characters": false,
		"include_all_stages": false,
	}
	_prime_transition_job_placeholders(resources, context)
	var done := false
	var step_count := 0
	for _idx in range(256):
		step_count += 1
		done = resources.prewarm_transition_textures_step(context)
		if done:
			break
		await process_frame

	_expect(done, "Stage 1 Smasher transition prewarm should complete")
	_expect(step_count >= 30, "transition prewarm should be split into many small texture/icon steps")
	var source := FileAccess.get_file_as_string("res://scripts/resources/battle_resources.gd")
	_expect(source.find("func _prewarm_texture_spec_step") >= 0, "transition prewarm should use the threaded texture step helper")
	_expect(source.find("ResourceLoader.load_threaded_request(path, \"Texture2D\", true)") >= 0, "transition prewarm should request large textures off the process frame")
	_expect(
		source.find("step_done = _prewarm_selected_skill_icon_texture_step(") >= 0,
		"transition prewarm should stage selected skill icons instead of sync-loading them"
	)
	_expect(
		source.find("if not _prewarm_texture_spec_step(spec):") >= 0,
		"selected skill icon prewarm should reuse the threaded texture spec helper"
	)
	_expect(
		source.find("_clear_transition_skill_icon_temp_keys()") >= 0,
		"transition prewarm reset should discard temporary skill icon texture cache keys"
	)
	var core_paths_source := FileAccess.get_file_as_string("res://scripts/resources/battle_core_texture_paths.gd")
	_expect(
		source.find("PINGPONG_BALL_TEXTURE_PATH := BattleCoreTexturePaths.PINGPONG_BALL_TEXTURE_PATH") >= 0,
		"battle resources should expose the public pingpong ball path alias from the core manifest"
	)
	_expect(
		core_paths_source.find("const PINGPONG_BALL_TEXTURE_PATH := \"res://assets/sprites/ball_runtime_128.png\"") >= 0,
		"battle transition prewarm should use the small runtime pingpong ball texture from the core manifest"
	)
	var ball_texture := load("res://assets/sprites/ball_runtime_128.png") as Texture2D
	_expect(
		ball_texture != null and max(ball_texture.get_width(), ball_texture.get_height()) <= 160,
		"runtime pingpong ball texture should stay small enough to avoid first core texture prewarm spikes"
	)

	var cache: Dictionary = resources.get_resource_cache()
	_expect(_has_texture(cache, "pingpong_ball_texture"), "core ball texture should load through staged prewarm")
	_expect(_has_texture(cache, "stage1_center_background_texture"), "Stage 1 center background should load through staged core prewarm")
	_expect(_has_texture(cache, "player_walk_left_texture"), "Smasher left walk sheet should load through staged player prewarm")
	_expect(_has_texture(cache, "player_idle_back_sheet"), "Smasher idle sheet should load through staged player prewarm")
	_expect(
		cache.get("player_idle_back_sheet", null) == cache.get("player_idle_sprite_texture", null),
		"Smasher idle runtime and fallback keys should share the same loaded texture"
	)
	_expect(_has_texture(cache, "boss_paengi_top_whip_sheet"), "Dalji paengi top-whip sheet should load through staged boss prewarm")
	_expect(_has_texture(cache, "boss_sprite_sheet"), "Dalji legacy walk alias should be populated during staged boss prewarm")
	_expect(_has_texture(cache, "boss_hit_sprite_sheet"), "Dalji legacy hit alias should be populated during staged boss prewarm")
	_expect(not cache.has("player_defeat_sheet"), "transition prewarm should skip result player sheets when include_result_sheets is false")
	_expect(not cache.has("boss_defeat_sheet"), "transition prewarm should skip result boss sheets when include_result_sheets is false")

	var smasher_icons: Variant = cache.get("smasher_skill_icon_textures", {})
	_expect(smasher_icons is Dictionary, "Smasher skill icon cache should be a dictionary")
	if smasher_icons is Dictionary:
		_expect(_has_texture(smasher_icons, "smasher_wheel"), "Smasher wheel icon should load through staged icon prewarm")
	_expect(cache.get("viper_skill_icon_textures", null) is Dictionary, "inactive Viper icon cache should be initialized")
	_expect(cache.get("commando_skill_icon_textures", null) is Dictionary, "inactive Commando icon cache should be initialized")


func _verify_stage1_gaksital_transition_prewarm_uses_variant_sheets() -> void:
	var resources: Object = BattleResources.new()
	var context := {
		"selected_character_type": "smasher",
		"current_stage": 1,
		"stage1_boss_variant": "gaksi",
		"include_result_sheets": false,
		"include_all_characters": false,
		"include_all_stages": false,
	}
	_prime_transition_job_placeholders(resources, context)
	var done := false
	var step_count := 0
	for _idx in range(256):
		step_count += 1
		done = resources.prewarm_transition_textures_step(context)
		if done:
			break
		await process_frame

	_expect(done, "Stage 1 Gaksital transition prewarm should complete")
	_expect(step_count >= 30, "Gaksital transition prewarm should remain split across staged texture/icon work")
	var cache: Dictionary = resources.get_resource_cache()
	_expect(_has_texture(cache, "boss_walk_left_sheet"), "Gaksital left walk sheet should load through staged boss prewarm")
	_expect(_has_texture(cache, "boss_walk_right_sheet"), "Gaksital right walk sheet should load through staged boss prewarm")
	_expect(_has_texture(cache, "boss_sprite_sheet"), "Gaksital legacy walk alias should map to the right walk sheet")
	_expect(cache.get("boss_sprite_sheet", null) == cache.get("boss_walk_right_sheet", null), "Gaksital legacy walk alias should share the right walk texture")
	_expect(_has_texture(cache, "boss_hit_sprite_sheet"), "Gaksital hit alias should load through staged boss prewarm")
	_expect(_has_texture(cache, "boss_fan_throw_sheet"), "Gaksital fan-throw sheet should load through staged boss prewarm")
	_expect(_has_texture(cache, "boss_fan_projectile_texture"), "Gaksital fan projectile texture should load through staged boss prewarm")
	_expect(not cache.has("boss_whip_sheet"), "Gaksital prewarm should not load Dalji whip sheet")
	_expect(not cache.has("boss_paengi_top_whip_sheet"), "Gaksital prewarm should not load Dalji top-whip sheet")
	_expect(not cache.has("boss_defeat_sheet"), "Gaksital transition prewarm should skip result boss sheets when include_result_sheets is false")


func _verify_stage1_pododaejang_transition_prewarm_uses_variant_sheets() -> void:
	var resources: Object = BattleResources.new()
	var dalji_context := {
		"selected_character_type": "smasher",
		"current_stage": 1,
		"stage1_boss_variant": "dalji",
		"include_result_sheets": false,
		"include_all_characters": false,
		"include_all_stages": false,
	}
	_prime_transition_job_placeholders(resources, dalji_context)
	var done := false
	for _idx in range(256):
		done = resources.prewarm_transition_textures_step(dalji_context)
		if done:
			break
		await process_frame
	_expect(done, "Stage 1 Dalji setup prewarm should complete before Pododaejang clear test")
	var cache: Dictionary = resources.get_resource_cache()
	_expect(_has_texture(cache, "boss_sprite_sheet"), "Dalji setup should populate the legacy boss walk alias")
	_expect(_has_texture(cache, "boss_whip_sheet"), "Dalji setup should populate the whip sheet")

	done = false
	var pododaejang_context := {
		"selected_character_type": "smasher",
		"current_stage": 1,
		"stage1_boss_variant": "pododaejang",
		"include_result_sheets": false,
		"include_all_characters": false,
		"include_all_stages": false,
	}
	_prime_transition_job_placeholders(resources, pododaejang_context)
	var step_count := 0
	for _idx in range(256):
		step_count += 1
		done = resources.prewarm_transition_textures_step(pododaejang_context)
		if done:
			break
		await process_frame

	_expect(done, "Stage 1 Pododaejang transition prewarm should complete")
	_expect(step_count >= 28, "Pododaejang transition prewarm should remain split across staged texture/icon work")
	_expect(_has_texture(cache, "boss_walk_left_sheet"), "Pododaejang front walk should load into the left walk key")
	_expect(_has_texture(cache, "boss_walk_right_sheet"), "Pododaejang front walk should load into the right walk key")
	_expect(_has_texture(cache, "boss_sprite_sheet"), "Pododaejang legacy walk alias should load")
	_expect(cache.get("boss_walk_left_sheet", null) == cache.get("boss_walk_right_sheet", null), "Pododaejang left/right walk keys should share the single front-facing walk sheet")
	_expect(cache.get("boss_sprite_sheet", null) == cache.get("boss_walk_right_sheet", null), "Pododaejang legacy walk alias should share the front-facing walk sheet")
	_expect(_has_texture(cache, "boss_idle_sheet"), "Pododaejang idle sheet should load through staged boss prewarm")
	_expect(_has_texture(cache, "boss_attack_sheet"), "Pododaejang arrest-rope attack sheet should load through staged boss prewarm")
	_expect(_has_texture(cache, "boss_hit_sprite_sheet"), "Pododaejang legacy hit alias should map to attack, not stun")
	_expect(cache.get("boss_hit_sprite_sheet", null) == cache.get("boss_attack_sheet", null), "Pododaejang hit alias should share the attack texture")
	_expect(_has_texture(cache, "boss_dash_sheet"), "Pododaejang dash sheet should load through staged boss prewarm")
	_expect(_has_texture(cache, "boss_stun_sheet"), "Pododaejang stun sheet should load through staged boss prewarm")
	_expect(_has_texture(cache, "stage1_pojol_patrol_walk_sheet"), "Pododaejang pojol patrol walk should prewarm with the variant")
	_expect(not cache.has("boss_whip_sheet"), "Pododaejang prewarm should not keep stale Dalji whip sheet")
	_expect(not cache.has("boss_paengi_top_whip_sheet"), "Pododaejang prewarm should not keep stale Dalji top-whip sheet")
	_expect(not cache.has("boss_fan_throw_sheet"), "Pododaejang prewarm should not keep stale Gaksital fan-throw sheet")
	_expect(not cache.has("boss_fan_projectile_texture"), "Pododaejang prewarm should not keep stale Gaksital fan projectile texture")
	_expect(not cache.has("boss_defeat_sheet"), "Pododaejang transition prewarm should skip result boss sheets when include_result_sheets is false")


func _verify_stage2_smasher_transition_prewarm_keeps_boss_aliases() -> void:
	var resources: Object = BattleResources.new()
	var context := {
		"selected_character_type": "smasher",
		"current_stage": 2,
		"include_result_sheets": false,
		"include_all_characters": false,
		"include_all_stages": false,
	}
	_prime_transition_job_placeholders(resources, context)
	var done := false
	var step_count := 0
	for _idx in range(256):
		step_count += 1
		done = resources.prewarm_transition_textures_step(context)
		if done:
			break
		await process_frame

	_expect(done, "Stage 2 Smasher transition prewarm should complete")
	_expect(step_count >= 24, "Stage 2 transition prewarm should remain split across staged texture/icon work")
	var cache: Dictionary = resources.get_resource_cache()
	_expect(_has_texture(cache, "boss_walk_left_sheet"), "Stage 2 left walk sheet should load through staged boss prewarm")
	_expect(_has_texture(cache, "boss_idle_sheet"), "Stage 2 idle sheet should load through staged boss prewarm")
	_expect(_has_texture(cache, "boss_sprite_sheet"), "Stage 2 legacy walk alias should be populated during staged boss prewarm")
	_expect(_has_texture(cache, "boss_hit_sprite_sheet"), "Stage 2 legacy hit alias should be populated during staged boss prewarm")
	_expect(not cache.has("boss_defeat_sheet"), "Stage 2 transition prewarm should skip result boss sheets when include_result_sheets is false")


func _has_texture(cache: Dictionary, key: String) -> bool:
	return cache.get(key, null) is Texture2D


func _cleanup_runtime_resources() -> void:
	ProjectResourceLoader.clear_caches()
	for _i in range(12):
		await process_frame


func _prime_transition_job_placeholders(resources: Object, context: Dictionary) -> void:
	# This smoke verifies transition-prewarm sequencing and cache aliasing, not
	# Godot's threaded importer itself. Placeholder cache priming keeps the same
	# staged spec path while avoiding flaky headless ObjectDB leak warnings from
	# short-lived threaded texture workers at process exit.
	for job_value in resources.get_transition_texture_prewarm_jobs(context):
		if not (job_value is Dictionary):
			continue
		var path := str((job_value as Dictionary).get("path", ""))
		if path == "" or ProjectResourceLoader.get_cached_texture(path) != null:
			continue
		var texture := PlaceholderTexture2D.new()
		texture.size = Vector2(64.0, 64.0)
		ProjectResourceLoader.store_texture(path, texture)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
