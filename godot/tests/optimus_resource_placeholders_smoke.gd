extends SceneTree

const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const OPTIMUS_RESOURCE_KEYS := [
	"optimus_player_idle_sheet",
	"optimus_player_walk_left_sheet",
	"optimus_player_walk_right_sheet",
	"optimus_player_attack_left_sheet",
	"optimus_player_attack_right_sheet",
	"optimus_overlay_paddle",
	"optimus_overlay_core_glow",
	"optimus_overlay_back",
	"optimus_overlay_accessory",
	"optimus_overlay_outfit_accent",
]

var _failures: Array[String] = []


func _init() -> void:
	_verify_optimus_selected_loads_optional_keys()
	_verify_io_alias_uses_optimus_keys()
	_verify_optimus_reload_clears_stale_smasher_fallbacks()
	_verify_include_all_keeps_smasher_defaults()

	if _failures.is_empty():
		print("optimus_resource_placeholders_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_optimus_selected_loads_optional_keys() -> void:
	ProjectResourceLoader.clear_caches()
	var textures: Dictionary = BattleResources.new().load_all(_optimus_config("optimus"))
	for key in OPTIMUS_RESOURCE_KEYS:
		_expect(textures.has(key), "Optimus-only resource load should expose optional key %s" % key)
	_expect(
		not (textures.get("player_sprite_texture", null) is Texture2D),
		"Optimus-only resource load should not fall back to the legacy Smasher walk strip"
	)


func _verify_io_alias_uses_optimus_keys() -> void:
	ProjectResourceLoader.clear_caches()
	var textures: Dictionary = BattleResources.new().load_all(_optimus_config("io"))
	for key in OPTIMUS_RESOURCE_KEYS:
		_expect(textures.has(key), "io alias should normalize to Optimus and expose optional key %s" % key)


func _verify_optimus_reload_clears_stale_smasher_fallbacks() -> void:
	ProjectResourceLoader.clear_caches()
	var resources := BattleResources.new()
	var smasher_textures: Dictionary = resources.load_all({
		"selected_character_type": "smasher",
		"current_stage": 1,
		"include_all_characters": false,
		"include_all_stages": false,
		"include_result_sheets": false,
	})
	var smasher_sprite: Variant = smasher_textures.get("player_sprite_texture", null)
	_expect(smasher_sprite is Texture2D, "Smasher resource load should still provide its legacy walk strip")

	var optimus_textures: Dictionary = resources.load_all(_optimus_config("optimus"))
	_expect(
		optimus_textures.get("player_sprite_texture", null) != smasher_sprite,
		"reusing BattleResources for Optimus should clear stale Smasher generic sprite keys"
	)
	for key in OPTIMUS_RESOURCE_KEYS:
		_expect(optimus_textures.has(key), "Optimus reload should retain optional key %s" % key)


func _verify_include_all_keeps_smasher_defaults() -> void:
	ProjectResourceLoader.clear_caches()
	var textures: Dictionary = BattleResources.new().load_all({})
	_expect(
		textures.get("player_sprite_texture", null) is Texture2D,
		"include-all resource load should keep the Smasher generic walk strip for legacy callers"
	)
	for key in OPTIMUS_RESOURCE_KEYS:
		_expect(textures.has(key), "include-all resource load should also expose Optimus optional key %s" % key)


func _optimus_config(character_type: String) -> Dictionary:
	return {
		"selected_character_type": character_type,
		"current_stage": 1,
		"include_all_characters": false,
		"include_all_stages": false,
		"include_result_sheets": false,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
