extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const WIDTH := 760.0
const HEIGHT := 750.0
const PLAY_LEFT := 0.0
const PLAY_RIGHT := WIDTH
const BALL_SIZE := 28.6
const BALL_RENDER_RADIUS := 16.9
const DRIVE_TEXT_DURATION_FRAMES := 30.0
const POWER_SMASH_TEXT_DURATION_FRAMES := 48.0
const PADDLE_WIDTH := 155.0
const PADDLE_HEIGHT := 50.0
const PLAYER_Y := 700.0
const BOSS_Y := 25.0
const BOSS_PADDLE_WIDTH := 100.0
const BOSS_PADDLE_HEIGHT := 40.0
const BOSS_HITBOX_HEIGHT := BOSS_PADDLE_HEIGHT


func build(owner: Object, shake_offset: Vector2, registry) -> Dictionary:
	return {
		"shake_offset": shake_offset,
		"width": WIDTH,
		"height": HEIGHT,
		"current_stage": int(_get_owner_value(owner, "current_stage", 1)),
		"play_left": PLAY_LEFT,
		"play_right": PLAY_RIGHT,
		"dash_snapshot": _get_dash_snapshot(registry),
		"textures": _get_owner_dict(owner, "battle_textures"),
		"player_pos": _get_owner_vector2(owner, "player_pos", Vector2.ZERO),
		"player_speed": float(_get_owner_value(owner, "player_speed", 0.0)),
		"player_paddle_size": Vector2(PADDLE_WIDTH, PADDLE_HEIGHT),
		"boss_pos": _get_owner_vector2(owner, "boss_pos", Vector2.ZERO),
		"boss_paddle_size": Vector2(BOSS_PADDLE_WIDTH, BOSS_PADDLE_HEIGHT),
		"boss_hitbox_height": BOSS_HITBOX_HEIGHT,
		"ball_active": bool(_get_owner_value(owner, "ball_active", false)),
		"ball_pos": _get_owner_vector2(owner, "ball_pos", Vector2.ZERO),
		"ball_vel": _get_owner_vector2(owner, "ball_vel", Vector2.ZERO),
		"ball_size": BALL_SIZE,
		"ball_visual_type": str(_get_owner_value(owner, "ball_visual_type", "energy")),
		"bomb_ball_loaded": bool(_get_owner_value(owner, "bomb_ball_loaded", false)),
		"poisoned_ball_overlay_active": bool(_get_owner_value(owner, "poisoned_ball_overlay_active", false)),
		"viper_knockback_overlay_active": bool(_get_owner_value(owner, "viper_knockback_overlay_active", false)),
		"boost_charging_active": bool(_get_owner_value(owner, "boost_charging_active", false)),
		"drive_ball_active": bool(_get_owner_value(owner, "drive_ball_active", false)),
		"player_y": PLAYER_Y,
		"boss_y": BOSS_Y,
		"player_paddle_width": PADDLE_WIDTH,
		"boss_paddle_width": BOSS_PADDLE_WIDTH,
		"ball_render_radius": BALL_RENDER_RADIUS,
		"special_gauge": float(_get_owner_value(owner, "special_gauge", 0.0)),
		"drive_text_timer_frames": float(_get_owner_value(owner, "drive_text_timer_frames", 0.0)),
		"drive_text_duration_frames": DRIVE_TEXT_DURATION_FRAMES,
		"power_smash_text_duration_frames": POWER_SMASH_TEXT_DURATION_FRAMES,
	}


func _get_dash_snapshot(registry) -> Dictionary:
	var dash_state: Object = registry.get_instance("smasher_dash_state")
	if dash_state != null:
		return dash_state.get_snapshot()
	return {
		"tokens": 0,
		"max_tokens": 1,
		"active": false,
		"direction": 0.0,
		"is_half": false,
		"available_timer": 0.0,
		"charge_timer": 0.0,
		"recharge_frames": 90.0,
	}


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	return BattleSceneOwnerReader.get_vector2(owner, key, fallback)


func _get_owner_dict(owner: Object, key: String) -> Dictionary:
	return BattleSceneOwnerReader.get_dictionary(owner, key)
