extends SceneTree

const BattleResources := preload("res://scripts/resources/battle_resources.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_stage1_smasher_transition_prewarm_is_fine_grained()
	await _verify_stage2_smasher_transition_prewarm_keeps_boss_aliases()

	if _failures.is_empty():
		print("battle_resources_transition_prewarm_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage1_smasher_transition_prewarm_is_fine_grained() -> void:
	var resources: Object = BattleResources.new()
	var done := false
	var step_count := 0
	for _idx in range(256):
		step_count += 1
		done = resources.prewarm_transition_textures_step({
			"selected_character_type": "smasher",
			"current_stage": 1,
			"include_result_sheets": false,
			"include_all_characters": false,
			"include_all_stages": false,
		})
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
	_expect(
		source.find("const PINGPONG_BALL_TEXTURE_PATH := \"res://assets/sprites/ball_runtime_128.png\"") >= 0,
		"battle transition prewarm should use the small runtime pingpong ball texture"
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


func _verify_stage2_smasher_transition_prewarm_keeps_boss_aliases() -> void:
	var resources: Object = BattleResources.new()
	var done := false
	var step_count := 0
	for _idx in range(256):
		step_count += 1
		done = resources.prewarm_transition_textures_step({
			"selected_character_type": "smasher",
			"current_stage": 2,
			"include_result_sheets": false,
			"include_all_characters": false,
			"include_all_stages": false,
		})
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
