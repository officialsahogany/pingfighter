extends SceneTree

const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const BattleUpdateEffectsSpriteContextBuilder := preload("res://scripts/core/battle_update_effects_sprite_context_builder.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const COMMANDO_PLAYER_PATHS := [
	"res://assets/sprites/characters/commando/base_grip/commando_base_grip_idle_back_gemini_v1.png",
	"res://assets/sprites/characters/commando/base_grip/commando_base_grip_walk_left_gemini_v1.png",
	"res://assets/sprites/characters/commando/base_grip/commando_base_grip_walk_right_gemini_v1.png",
	"res://assets/sprites/characters/commando/commando_subculture_back_walk_sheet.png",
]

const COMMANDO_ICON_IDS := [
	"supply_drop",
	"commando_pistol",
	"net_gun",
	"fire_support",
	"bowling_trap",
	"suicide_drone",
	"ak47",
	"bazooka",
]

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_asset_loads()
	_verify_resource_contexts()

	if _failures.is_empty():
		print("commando_resource_sprite_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_asset_loads() -> void:
	for path in COMMANDO_PLAYER_PATHS:
		var texture: Texture2D = ProjectResourceLoader.load_texture(path)
		_expect(texture != null, "%s should load as a raw Godot texture" % path)
		if texture != null:
			_expect(texture.get_size().x > 0.0 and texture.get_size().y > 0.0, "%s should have visible dimensions" % path)
	for skill_id in COMMANDO_ICON_IDS:
		var path := "res://assets/sprites/skills/commando_%s_skill_orb.png" % skill_id
		if skill_id == "commando_pistol":
			path = "res://assets/sprites/skills/commando_pistol_skill_orb.png"
		var texture: Texture2D = ProjectResourceLoader.load_texture(path)
		_expect(texture != null, "%s should load as a Commando skill icon" % path)


func _verify_resource_contexts() -> void:
	var resources := BattleResources.new()
	var textures: Dictionary = resources.load_all({
		"selected_character_type": "soldier",
		"current_stage": 1,
		"include_all_characters": false,
		"include_all_stages": false,
		"include_result_sheets": false,
	})
	_expect(textures.get("commando_player_idle_sheet", null) is Texture2D, "Commando idle sheet should be loaded")
	_expect(textures.get("commando_player_walk_left_sheet", null) is Texture2D, "Commando left walk sheet should be loaded")
	_expect(textures.get("commando_player_walk_right_sheet", null) is Texture2D, "Commando right walk sheet should be loaded")
	_expect(textures.get("commando_player_walk_back_sheet", null) is Texture2D, "Commando back walk sheet should be loaded")
	_expect(textures.get("commando_player_legacy_idle_sheet", null) is Texture2D, "Commando legacy idle sheet should stay cached")
	_expect(not (textures.get("player_sprite_texture", null) is Texture2D), "Commando-only prewarm should not require Smasher player sprite")

	var icons: Dictionary = textures.get("commando_skill_icon_textures", {})
	for skill_id in COMMANDO_ICON_IDS:
		_expect(icons.get(skill_id, null) is Texture2D, "Commando icon map should include %s" % skill_id)

	var update_builder := BattleUpdateEffectsSpriteContextBuilder.new()
	var update_context: Dictionary = update_builder.build_context(textures, "soldier")
	_expect(str(update_context.get("selected_character_type", "")) == "soldier", "effects sprite context should keep soldier")
	_expect(bool(update_context.get("player_has_sprite", false)), "effects sprite context should see Commando player sprite")
	_expect(bool(update_context.get("player_has_idle_sprite", false)), "effects sprite context should see Commando idle sheet")
	_expect(bool(update_context.get("player_has_attack_sheet", false)), "Commando should expose its own attack sheet")
	_expect(int(update_context.get("player_idle_frame_count", 0)) == 8, "Commando B2 idle should use 8 frame sheet cadence")

	var draw_builder := BattleDrawActorContext.new()
	var actor_context: Dictionary = draw_builder.build({
		"selected_character_type": "soldier",
		"textures": textures,
	}, {})
	_expect(str(actor_context.get("selected_character_type", "")) == "soldier", "actor draw context should keep soldier")
	_expect(actor_context.get("player_sprite_texture", null) == textures.get("commando_player_walk_back_sheet", null), "actor draw context should use Commando back sheet as base")
	_expect(actor_context.get("player_walk_left_texture", null) == textures.get("commando_player_walk_left_sheet", null), "actor draw context should use Commando left sheet")
	_expect(actor_context.get("player_walk_right_texture", null) == textures.get("commando_player_walk_right_sheet", null), "actor draw context should use Commando right sheet")
	_expect(actor_context.get("player_idle_sprite_texture", null) == textures.get("commando_player_idle_sheet", null), "actor draw context should use Commando idle sheet")
	_expect(int(actor_context.get("player_idle_frame_count", 0)) == 8, "actor draw context should expose Commando B2 idle as 8 frames")
	_expect(int(actor_context.get("player_idle_grid_rows", 0)) == 2, "actor draw context should expose Commando B2 idle as 4x2 grid")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
