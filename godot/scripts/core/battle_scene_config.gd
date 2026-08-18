extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const WIDTH := 760.0
const HEIGHT := 750.0
# Legacy Python-era in-game HUD band width. This is not a playfield wall inset:
# Godot playfield background and wall collisions span x=0..WIDTH, while outer
# pillar chrome is drawn from viewport layout in the pillar scene pass.
const PILLAR_WIDTH := 80.0
const PADDLE_WIDTH := 155.0
const PADDLE_HEIGHT := 50.0
const PLAYER_Y := 700.0
const BOSS_Y := 25.0
const BOSS_PADDLE_WIDTH := 100.0
const BOSS_HITBOX_HEIGHT := 40.0
const JUNIOR_PLAYER_PADDLE_SCALE := 1.5
const LIMIT_BOSS_PADDLE_SCALE := 1.07
const MYTHIC_BOSS_PADDLE_SCALE := 1.15
const DEFAULT_STARTING_DASH_TOKENS := 2
const JUNIOR_STARTING_DASH_TOKENS := 2


func build_startup_context(owner: Object) -> Dictionary:
	var ai_mode := normalize_league_mode(str(_get_owner_value(owner, "ai_mode", "champion")))
	var league_boss_paddle_scale: float = get_league_boss_paddle_scale_for_mode(ai_mode)
	return {
		"width": WIDTH,
		"height": HEIGHT,
		"pillar_width": PILLAR_WIDTH,
		"player_y": PLAYER_Y,
		"boss_y": BOSS_Y,
		"player_paddle_width": PADDLE_WIDTH,
		"player_paddle_height": PADDLE_HEIGHT,
		"league_player_paddle_scale": get_league_player_paddle_scale_for_mode(ai_mode),
		"league_boss_paddle_scale": league_boss_paddle_scale,
		"starting_dash_tokens": get_starting_dash_tokens_for_mode(ai_mode),
		"boss_paddle_width": BOSS_PADDLE_WIDTH * league_boss_paddle_scale,
		"boss_hitbox_height": BOSS_HITBOX_HEIGHT,
		"selected_character_type": str(_get_owner_value(owner, "selected_character_type", "smasher")),
		"current_stage": int(_get_owner_value(owner, "current_stage", 1)),
		"stage1_boss_variant": str(_get_owner_value(owner, "stage1_boss_variant", "dalji")),
		"ai_mode": ai_mode,
		"arena_mode_enabled": bool(_get_owner_value(owner, "arena_mode_enabled", false)),
		"weather_type": str(_get_owner_value(owner, "weather_type", "")),
	}


func build_draw_context() -> Dictionary:
	return {
		"width": WIDTH,
		"height": HEIGHT,
		"pillar_width": PILLAR_WIDTH,
	}


func get_starting_dash_tokens(owner: Object) -> int:
	var ai_mode := normalize_league_mode(str(_get_owner_value(owner, "ai_mode", "champion")))
	return get_starting_dash_tokens_for_mode(ai_mode)


func get_starting_dash_tokens_for_mode(mode: String) -> int:
	var ai_mode := normalize_league_mode(mode)
	if ai_mode == "junior":
		return JUNIOR_STARTING_DASH_TOKENS
	return DEFAULT_STARTING_DASH_TOKENS


func get_league_player_paddle_scale(owner: Object) -> float:
	var ai_mode := normalize_league_mode(str(_get_owner_value(owner, "ai_mode", "champion")))
	return get_league_player_paddle_scale_for_mode(ai_mode)


func get_league_player_paddle_scale_for_mode(mode: String) -> float:
	var ai_mode := normalize_league_mode(mode)
	return JUNIOR_PLAYER_PADDLE_SCALE if ai_mode == "junior" else 1.0


func get_league_boss_paddle_scale(owner: Object) -> float:
	var ai_mode := normalize_league_mode(str(_get_owner_value(owner, "ai_mode", "champion")))
	return get_league_boss_paddle_scale_for_mode(ai_mode)


func get_league_boss_paddle_scale_for_mode(mode: String) -> float:
	var ai_mode := normalize_league_mode(mode)
	if ai_mode == "mythic":
		return MYTHIC_BOSS_PADDLE_SCALE
	if ai_mode == "limit":
		return LIMIT_BOSS_PADDLE_SCALE
	return 1.0


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


static func normalize_league_mode(mode: String) -> String:
	var normalized: String = mode.strip_edges().to_lower().replace(" ", "").replace("_", "").replace("-", "")
	if normalized == "junior" or normalized == "juniorleague":
		return "junior"
	if normalized == "mythic" or normalized == "mythicleague":
		return "mythic"
	if normalized == "limit" or normalized == "limitleague":
		return "limit"
	return "champion"
