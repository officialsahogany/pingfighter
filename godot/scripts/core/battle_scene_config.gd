extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const WIDTH := 760.0
const HEIGHT := 750.0
# Legacy Python-era in-game HUD band width. This is not a playfield wall inset:
# Godot playfield background and wall collisions span x=0..WIDTH, while outer
# pillar chrome is drawn from viewport layout in the pillar scene pass.
const PILLAR_WIDTH := 80.0
const PADDLE_WIDTH := 155.0
const PLAYER_Y := 700.0
const BOSS_Y := 25.0
const BOSS_PADDLE_WIDTH := 100.0


func build_startup_context(owner: Object) -> Dictionary:
	return {
		"width": WIDTH,
		"height": HEIGHT,
		"pillar_width": PILLAR_WIDTH,
		"player_y": PLAYER_Y,
		"boss_y": BOSS_Y,
		"player_paddle_width": PADDLE_WIDTH,
		"boss_paddle_width": BOSS_PADDLE_WIDTH,
		"selected_character_type": str(_get_owner_value(owner, "selected_character_type", "smasher")),
		"current_stage": int(_get_owner_value(owner, "current_stage", 1)),
		"ai_mode": str(_get_owner_value(owner, "ai_mode", "champion")),
		"arena_mode_enabled": bool(_get_owner_value(owner, "arena_mode_enabled", false)),
		"weather_type": str(_get_owner_value(owner, "weather_type", "")),
	}


func build_draw_context() -> Dictionary:
	return {
		"width": WIDTH,
		"height": HEIGHT,
		"pillar_width": PILLAR_WIDTH,
	}


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)
