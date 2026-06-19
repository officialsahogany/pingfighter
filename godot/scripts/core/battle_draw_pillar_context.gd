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
		"current_msec": Time.get_ticks_msec(),
		"view_size": view_size,
		"game_offset": _get_vector2(layout, "game_offset", Vector2.ZERO),
		"game_size": _get_vector2(layout, "game_size", Vector2(WIDTH, HEIGHT)),
		"width": WIDTH,
		"height": HEIGHT,
		"current_stage": int(_get_owner_value(owner, "current_stage", 1)),
		"selected_character_type": character_type,
		"active_item_slots": _get_owner_array(owner, "active_item_slots"),
		"runtime_perk_gold": int(_get_owner_value(owner, "runtime_perk_gold", 0)),
		"special_gauge": float(_get_owner_value(owner, "special_gauge", 0.0)),
		"gauge_max": max(1.0, float(_get_owner_value(owner, "special_gauge_max", GAUGE_MAX))),
		"textures": _get_owner_dict(owner, "battle_textures"),
		"skill_icons": _get_owner_dict(owner, character_runtime.get_skill_icon_texture_key(character_type)),
		"top_mini_score_sparkle_duration": top_mini_score_sparkle_duration,
	}


func build_scene_states(registry, current_stage: int = 1) -> Dictionary:
	return {
		"stage_background": _get_stage_instance(registry, current_stage, "stage_background", "stage1_pillar_background"),
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


func _get_stage_instance(registry: Object, current_stage: int, role: String, fallback_key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var router: Object = registry.get_instance("stage_runtime_router")
	if router != null and router.has_method("get_instance"):
		var routed: Object = router.get_instance(registry, current_stage, role)
		if routed != null:
			return routed
	return registry.get_instance(fallback_key)
