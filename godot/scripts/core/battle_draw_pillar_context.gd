extends RefCounted

const BattleContextReader := preload("res://scripts/core/battle_context_reader.gd")
const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

const WIDTH := 760.0
const HEIGHT := 750.0
const GAUGE_MAX := 500.0

var character_runtime: Object = PlayerCharacterRuntime.new()


func build_scene_context(
	owner: Object,
	view_size: Vector2,
	layout: Dictionary,
	top_mini_score_sparkle_duration: float
) -> Dictionary:
	var character_type: String = character_runtime.normalize(_get_owner_value(owner, "selected_character_type", "smasher"))
	return {
		"view_size": view_size,
		"game_offset": _get_vector2(layout, "game_offset", Vector2.ZERO),
		"game_size": _get_vector2(layout, "game_size", Vector2(WIDTH, HEIGHT)),
		"width": WIDTH,
		"height": HEIGHT,
		"selected_character_type": character_type,
		"active_item_slots": _get_owner_array(owner, "active_item_slots"),
		"special_gauge": float(_get_owner_value(owner, "special_gauge", 0.0)),
		"gauge_max": GAUGE_MAX,
		"textures": _get_owner_dict(owner, "battle_textures"),
		"skill_icons": _get_owner_dict(owner, character_runtime.get_skill_icon_texture_key(character_type)),
		"top_mini_score_sparkle_duration": top_mini_score_sparkle_duration,
	}


func build_scene_states(registry) -> Dictionary:
	return {
		"stage_background": registry.get_instance("stage1_pillar_background"),
		"scoreboard_state": registry.get_instance("scoreboard_state"),
		"orb_hud_state": registry.get_instance("orb_hud_state"),
	}


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _get_owner_dict(owner: Object, key: String) -> Dictionary:
	return BattleSceneOwnerReader.get_dictionary(owner, key)


func _get_owner_array(owner: Object, key: String) -> Array:
	return BattleSceneOwnerReader.get_array(owner, key)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BattleContextReader.get_vector2(source, key, fallback)
