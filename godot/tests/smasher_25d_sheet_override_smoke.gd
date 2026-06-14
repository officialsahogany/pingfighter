extends SceneTree

const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Smasher25DSheetOverride := preload("res://scripts/core/smasher_25d_sheet_override.gd")

const PARTIAL_TEST_SHEET_PATHS := {
	"idle": "res://tests/__smasher_25d_partial_idle_4x2_160.png",
	"walk_left": "res://tests/__smasher_25d_partial_walk_left_4x2_160.png",
	"walk_right": "res://tests/__smasher_25d_partial_walk_right_4x2_160.png",
	"attack_left": "res://tests/__smasher_25d_partial_attack_left_4x4_160.png",
}
const RUNTIME_4X2_SHEET_SIZE := Vector2(640.0, 320.0)
const RUNTIME_4X4_SHEET_SIZE := Vector2(640.0, 640.0)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_default_off_when_no_flag_file()
	_verify_partial_25d_assets_keep_default_sheets()
	await _verify_25d_assets_override_sync_and_prewarm_lanes()

	OS.set_environment(Smasher25DSheetOverride.ENV_KEY, "")
	Smasher25DSheetOverride.clear_required_sheet_paths_for_test()
	Smasher25DSheetOverride.reset_cache_for_test()
	ProjectResourceLoader.clear_caches()

	if _failures.is_empty():
		print("smasher_25d_sheet_override_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_default_off_when_no_flag_file() -> void:
	OS.set_environment(Smasher25DSheetOverride.ENV_KEY, "")
	Smasher25DSheetOverride.clear_required_sheet_paths_for_test()
	Smasher25DSheetOverride.reset_cache_for_test()
	ProjectResourceLoader.clear_caches()
	if FileAccess.file_exists(Smasher25DSheetOverride.FLAG_PATH):
		return
	_expect(not Smasher25DSheetOverride.is_toggle_requested(), "Smasher 2.5D override should be off by default")
	_expect(Smasher25DSheetOverride.get_active_sheet_paths().is_empty(), "Smasher 2.5D paths should stay inactive without env or flag")


func _verify_partial_25d_assets_keep_default_sheets() -> void:
	OS.set_environment(Smasher25DSheetOverride.ENV_KEY, "1")
	Smasher25DSheetOverride.set_required_sheet_paths_for_test(PARTIAL_TEST_SHEET_PATHS)
	ProjectResourceLoader.clear_caches()
	_store_partial_25d_placeholders()
	Smasher25DSheetOverride.reset_cache_for_test()

	_expect(Smasher25DSheetOverride.is_toggle_requested(), "Smasher 2.5D env var should request the override")
	_expect(Smasher25DSheetOverride.get_active_sheet_paths().is_empty(), "A partial 3/4 Smasher 2.5D sheet set should keep the override inactive")
	_expect(
		Smasher25DSheetOverride.get_missing_required_sheet_paths().has(str(PARTIAL_TEST_SHEET_PATHS["attack_left"])),
		"Partial Smasher 2.5D test set should report the missing attack-left path"
	)
	var resources := BattleResources.new()
	var textures: Dictionary = resources.load_all(_smasher_context())
	_expect(_texture_path(textures, "player_idle_back_sheet") == BattleResources.SMASHER_IDLE_SHEET_PATH, "Partial 2.5D set should fall back to the shipped Smasher idle sheet")
	_expect(_texture_path(textures, "player_walk_left_texture") == BattleResources.PLAYER_WALK_LEFT_SPRITE_PATH, "Partial 2.5D set should fall back to the shipped Smasher walk-left sheet")
	_expect(_texture_path(textures, "player_walk_right_texture") == BattleResources.PLAYER_WALK_RIGHT_SPRITE_PATH, "Partial 2.5D set should fall back to the shipped Smasher walk-right sheet")
	_expect(_texture_path(textures, "player_attack_left_sheet") == BattleResources.SMASHER_ATTACK_LEFT_SHEET_PATH, "Partial 2.5D set should fall back to the shipped Smasher attack-left sheet")
	_expect(
		textures.get("player_idle_back_sheet", null) == textures.get("player_idle_sprite_texture", null),
		"Smasher idle alias keys should stay bound to the same texture when override is inactive"
	)
	Smasher25DSheetOverride.clear_required_sheet_paths_for_test()


func _verify_25d_assets_override_sync_and_prewarm_lanes() -> void:
	OS.set_environment(Smasher25DSheetOverride.ENV_KEY, "1")
	Smasher25DSheetOverride.clear_required_sheet_paths_for_test()
	Smasher25DSheetOverride.reset_cache_for_test()
	ProjectResourceLoader.clear_caches()

	var override_paths: Dictionary = Smasher25DSheetOverride.get_active_sheet_paths()
	_expect(not override_paths.is_empty(), "Repo Smasher 2.5D sheet set should activate the override")
	_expect(Smasher25DSheetOverride.get_missing_required_sheet_paths().is_empty(), "Repo Smasher 2.5D sheet set should have no missing required paths")

	var resources := BattleResources.new()
	var textures: Dictionary = resources.load_all(_smasher_context())
	_expect(_texture_path(textures, "player_idle_back_sheet") == Smasher25DSheetOverride.IDLE_SHEET_PATH, "Synchronous load should use 2.5D idle")
	_expect(_texture_path(textures, "player_idle_sprite_texture") == Smasher25DSheetOverride.IDLE_SHEET_PATH, "Synchronous load should bind both idle aliases to the 2.5D idle")
	_expect(_texture_path(textures, "player_walk_left_texture") == Smasher25DSheetOverride.WALK_LEFT_SHEET_PATH, "Synchronous load should use 2.5D walk-left")
	_expect(_texture_path(textures, "player_walk_right_texture") == Smasher25DSheetOverride.WALK_RIGHT_SHEET_PATH, "Synchronous load should use 2.5D walk-right")
	_expect(_texture_path(textures, "player_attack_left_sheet") == Smasher25DSheetOverride.ATTACK_LEFT_SHEET_PATH, "Synchronous load should use 2.5D attack-left")
	_expect(_texture_path(textures, "player_attack_right_sheet") == BattleResources.SMASHER_ATTACK_RIGHT_SHEET_PATH, "Attack-right should stay on the shipped 2D sheet during the one-attack pilot")
	_expect(_texture_size(textures, "player_idle_back_sheet") == RUNTIME_4X2_SHEET_SIZE, "2.5D idle sheet should keep 4x2 160px runtime cells")
	_expect(_texture_size(textures, "player_walk_left_texture") == RUNTIME_4X2_SHEET_SIZE, "2.5D walk-left sheet should keep 4x2 160px runtime cells")
	_expect(_texture_size(textures, "player_walk_right_texture") == RUNTIME_4X2_SHEET_SIZE, "2.5D walk-right sheet should keep 4x2 160px runtime cells")
	_expect(_texture_size(textures, "player_attack_left_sheet") == RUNTIME_4X4_SHEET_SIZE, "2.5D attack-left sheet should keep 4x4 160px runtime cells")

	var actor_context: Dictionary = BattleDrawActorContext.new().build({
		"selected_character_type": "smasher",
		"textures": textures,
		"player_paddle_size": Vector2(155.0, 50.0),
	}, {})
	_expect(actor_context.get("player_idle_sprite_texture", null) == textures.get("player_idle_back_sheet", null), "Draw context should use the 2.5D idle alias")
	_expect(actor_context.get("player_walk_left_texture", null) == textures.get("player_walk_left_texture", null), "Draw context should expose the 2.5D walk-left texture")
	_expect(actor_context.get("player_walk_right_texture", null) == textures.get("player_walk_right_texture", null), "Draw context should expose the 2.5D walk-right texture")
	_expect(actor_context.get("player_attack_left_sheet", null) == textures.get("player_attack_left_sheet", null), "Draw context should expose the 2.5D attack-left texture")

	Smasher25DSheetOverride.reset_cache_for_test()
	var prewarm_resources := BattleResources.new()
	var done := false
	for _idx in range(256):
		done = prewarm_resources.prewarm_transition_textures_step(_smasher_context())
		if done:
			break
		await process_frame

	_expect(done, "Transition prewarm should complete with the repo 2.5D sheet set")
	var prewarm_cache: Dictionary = prewarm_resources.get_resource_cache()
	_expect(_texture_path(prewarm_cache, "player_idle_back_sheet") == Smasher25DSheetOverride.IDLE_SHEET_PATH, "Prewarm specs should use 2.5D idle")
	_expect(_texture_path(prewarm_cache, "player_walk_left_texture") == Smasher25DSheetOverride.WALK_LEFT_SHEET_PATH, "Prewarm specs should use 2.5D walk-left")
	_expect(_texture_path(prewarm_cache, "player_walk_right_texture") == Smasher25DSheetOverride.WALK_RIGHT_SHEET_PATH, "Prewarm specs should use 2.5D walk-right")
	_expect(_texture_path(prewarm_cache, "player_attack_left_sheet") == Smasher25DSheetOverride.ATTACK_LEFT_SHEET_PATH, "Prewarm specs should use 2.5D attack-left")
	_expect(
		prewarm_cache.get("player_idle_back_sheet", null) == prewarm_cache.get("player_idle_sprite_texture", null),
		"Prewarm specs should bind both idle aliases to the same 2.5D texture"
	)


func _smasher_context() -> Dictionary:
	return {
		"selected_character_type": "smasher",
		"current_stage": 1,
		"include_all_characters": false,
		"include_all_stages": false,
		"include_result_sheets": false,
	}


func _store_partial_25d_placeholders() -> void:
	_store_placeholder(str(PARTIAL_TEST_SHEET_PATHS["idle"]), Vector2(640.0, 320.0))
	_store_placeholder(str(PARTIAL_TEST_SHEET_PATHS["walk_left"]), Vector2(640.0, 320.0))
	_store_placeholder(str(PARTIAL_TEST_SHEET_PATHS["walk_right"]), Vector2(640.0, 320.0))


func _store_placeholder(path: String, size: Vector2) -> void:
	var texture := PlaceholderTexture2D.new()
	texture.size = size
	ProjectResourceLoader.store_texture(path, texture)


func _texture_path(textures: Dictionary, key: String) -> String:
	var texture: Variant = textures.get(key, null)
	if texture is Texture2D:
		return (texture as Texture2D).resource_path
	return ""


func _texture_size(textures: Dictionary, key: String) -> Vector2:
	var texture: Variant = textures.get(key, null)
	if texture is Texture2D:
		return (texture as Texture2D).get_size()
	return Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
