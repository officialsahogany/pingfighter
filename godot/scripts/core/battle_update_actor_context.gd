extends RefCounted

const WIDTH: float = 760.0
const PLAY_LEFT: float = 0.0
const PLAY_RIGHT: float = WIDTH
const PADDLE_WIDTH: float = 155.0
const BOSS_PADDLE_WIDTH: float = 100.0
const BALL_SIZE: float = 22.0
const BOSS_Y: float = 25.0
const BOSS_HITBOX_HEIGHT: float = 40.0
const HITBOX_PADDING: float = 5.0


func build_player_control_config() -> Dictionary:
	return {
		"play_left": PLAY_LEFT,
		"play_right": PLAY_RIGHT,
		"paddle_width": PADDLE_WIDTH,
	}


func build_player_control_deps(registry: Object) -> Dictionary:
	return {
		"input_reader": registry.get_instance("smasher_input_reader"),
		"dash_state": registry.get_instance("smasher_dash_state"),
		"drive_input_state": registry.get_instance("smasher_drive_input_state"),
		"movement_state": registry.get_instance("player_movement_state"),
		"combo_state": registry.get_instance("smasher_combo_state"),
		"orb_hud_state": registry.get_instance("orb_hud_state"),
		"audio": registry.get_instance("game_audio"),
		"feedback": registry.get_instance("battle_feedback_state"),
	}


func build_boss_ai_context(owner: Object, registry: Object) -> Dictionary:
	var round_state: Object = registry.get_instance("round_flow_state")
	var power_state: Object = registry.get_instance("smasher_power_smash_state")
	return {
		"width": WIDTH,
		"play_left": PLAY_LEFT,
		"play_right": PLAY_RIGHT,
		"boss_paddle_width": BOSS_PADDLE_WIDTH,
		"ball_active": bool(_get_owner_value(owner, "ball_active", false)),
		"waiting_for_serve": round_state == null or round_state.is_waiting_for_serve(),
		"ball_pos": _get_owner_vector2(owner, "ball_pos", Vector2.ZERO),
		"ball_vel": _get_owner_vector2(owner, "ball_vel", Vector2.ZERO),
		"ball_impact_boost": float(_get_owner_value(owner, "ball_impact_boost", 1.0)),
		"ball_boost_decay_rate": float(_get_owner_value(owner, "ball_boost_decay_rate", 0.975)),
		"ball_min_boost": float(_get_owner_value(owner, "ball_min_boost", 0.70)),
		"ball_size": BALL_SIZE,
		"boss_y": BOSS_Y,
		"boss_hitbox_height": BOSS_HITBOX_HEIGHT,
		"hitbox_padding": HITBOX_PADDING,
		"power_smashing_parabola_active": power_state != null and power_state.is_parabola_active(),
		"power_smashing_combo_consumed": int(power_state.get_combo_consumed()) if power_state != null else 0,
	}


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value == null:
		return fallback
	return value


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_owner_value(owner, key, fallback)
	if value is Vector2:
		return value
	return fallback
