extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const BALL_SIZE: float = 28.6
const WIDTH: float = 760.0
const HEIGHT: float = 750.0
const PLAY_LEFT: float = 0.0
const PLAY_RIGHT: float = WIDTH
const BOSS_PADDLE_WIDTH: float = 100.0
const BOSS_HITBOX_HEIGHT: float = 40.0
const GAUGE_MAX: float = 500.0


func build_context(owner: Object, registry: Object, character_type: String, dash_snapshot: Dictionary) -> Dictionary:
	var round_state: Object = _get_instance(registry, "round_flow_state")
	return {
		"owner": owner,
		"registry": registry,
		"current_msec": Time.get_ticks_msec(),
		"current_stage": int(_get_owner_value(owner, "current_stage", 1)),
		"ai_mode": str(_get_owner_value(owner, "ai_mode", "champion")),
		"enraged_boss_active": bool(_get_owner_value(owner, "enraged_boss_active", false)),
		"selected_character_type": character_type,
		"width": WIDTH,
		"height": HEIGHT,
		"play_left": PLAY_LEFT,
		"play_right": PLAY_RIGHT,
		"dash_snapshot": dash_snapshot,
		"drive_text_timer_frames": float(_get_owner_value(owner, "drive_text_timer_frames", 0.0)),
		"ball_pos": _get_owner_vector2(owner, "ball_pos", Vector2.ZERO),
		"ball_vel": _get_owner_vector2(owner, "ball_vel", Vector2.ZERO),
		"ball_active": bool(_get_owner_value(owner, "ball_active", false)),
		"stage3_kuromi_ball_hidden": bool(_get_owner_value(owner, "stage3_kuromi_ball_hidden", false)),
		"waiting_for_serve": _is_waiting_for_serve(round_state),
		"ball_impact_boost": float(_get_owner_value(owner, "ball_impact_boost", 1.0)),
		"ball_size": BALL_SIZE,
		"special_gauge": float(_get_owner_value(owner, "special_gauge", 0.0)),
		"gauge_max": max(1.0, float(_get_owner_value(owner, "special_gauge_max", GAUGE_MAX))),
		"player_speed": float(_get_owner_value(owner, "player_speed", 0.0)),
		"player_collision_cooldown": float(_get_owner_value(owner, "player_collision_cooldown", 0.0)),
		"player_pos": _get_owner_vector2(owner, "player_pos", Vector2.ZERO),
		"player_paddle_size": Vector2(
			max(1.0, float(_get_owner_value(owner, "player_paddle_width", 155.0))),
			max(1.0, float(_get_owner_value(owner, "player_paddle_height", 50.0)))
		),
		"boss_pos": _get_owner_vector2(owner, "boss_pos", Vector2.ZERO),
		"boss_vel": float(_get_owner_value(owner, "boss_vel", 0.0)),
		"boss_collision_cooldown": float(_get_owner_value(owner, "boss_collision_cooldown", 0.0)),
		"boss_paddle_width": max(1.0, float(_get_owner_value(owner, "boss_paddle_width", BOSS_PADDLE_WIDTH))),
		"boss_hitbox_height": max(1.0, float(_get_owner_value(owner, "boss_hitbox_height", BOSS_HITBOX_HEIGHT))),
		"commando_suicide_drone_ball_boost_active": bool(_get_owner_value(owner, "commando_suicide_drone_ball_boost_active", false)),
		"commando_suicide_drone_ball_restore_speed": float(_get_owner_value(owner, "commando_suicide_drone_ball_restore_speed", 0.0)),
		"commando_suicide_drone_ball_boosted_speed": float(_get_owner_value(owner, "commando_suicide_drone_ball_boosted_speed", 0.0)),
		"blacksmith_umbrella_open": bool(_get_owner_value(owner, "blacksmith_umbrella_open", false)),
		"blacksmith_umbrella_anim_timer": float(_get_owner_value(owner, "blacksmith_umbrella_anim_timer", 0.0)),
		"blacksmith_umbrella_retracting": bool(_get_owner_value(owner, "blacksmith_umbrella_retracting", false)),
		"blacksmith_umbrella_anim_direction": int(_get_owner_value(owner, "blacksmith_umbrella_anim_direction", 1)),
		"blacksmith_umbrella_open_ratio": clamp(float(_get_owner_value(owner, "blacksmith_umbrella_open_ratio", 0.0)), 0.0, 1.0),
		"blacksmith_thor_shield_open_ratio": clamp(float(_get_owner_value(owner, "blacksmith_thor_shield_open_ratio", 0.0)), 0.0, 1.0),
		"blacksmith_umbrella_raise_amount": clamp(float(_get_owner_value(owner, "blacksmith_umbrella_raise_amount", 0.0)), 0.0, 1.0),
		"blacksmith_umbrella_shield_open_amount": clamp(float(_get_owner_value(owner, "blacksmith_umbrella_shield_open_amount", 0.0)), 0.0, 1.0),
		"blacksmith_umbrella_visual_state": str(_get_owner_value(owner, "blacksmith_umbrella_visual_state", "closed")),
		"blacksmith_umbrella_folded": bool(_get_owner_value(owner, "blacksmith_umbrella_folded", true)),
		"blacksmith_umbrella_deployed": bool(_get_owner_value(owner, "blacksmith_umbrella_deployed", false)),
		"blacksmith_umbrella_swing_active": bool(_get_owner_value(owner, "blacksmith_umbrella_swing_active", false)),
		"blacksmith_umbrella_gauge": int(_get_owner_value(owner, "blacksmith_umbrella_gauge", 5)),
		"blacksmith_umbrella_gauge_max": int(_get_owner_value(owner, "blacksmith_umbrella_gauge_max", 5)),
		"blacksmith_umbrella_gauge_gain": float(_get_owner_value(owner, "blacksmith_umbrella_gauge_gain", 60.0)),
	}


func _is_waiting_for_serve(round_state: Object) -> bool:
	if round_state == null or not round_state.has_method("is_waiting_for_serve"):
		return true
	return bool(round_state.is_waiting_for_serve())


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	return BattleSceneOwnerReader.get_vector2(owner, key, fallback)
