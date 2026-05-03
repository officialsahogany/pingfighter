extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

const WIDTH: float = 760.0
const PLAY_LEFT: float = 0.0
const PLAY_RIGHT: float = WIDTH
const PADDLE_WIDTH: float = 155.0
const BOSS_PADDLE_WIDTH: float = 100.0
const BALL_SIZE: float = 28.6
const BOSS_Y: float = 25.0
const BOSS_HITBOX_HEIGHT: float = 40.0
const HITBOX_PADDING: float = 5.0

var character_runtime: Object = PlayerCharacterRuntime.new()


func build_player_control_config(character_type: String = "smasher") -> Dictionary:
	var config := {
		"play_left": PLAY_LEFT,
		"play_right": PLAY_RIGHT,
		"paddle_width": PADDLE_WIDTH,
	}
	config.merge(character_runtime.get_base_movement_config(character_type), true)
	return config


func build_player_control_deps(registry: Object, character_type: String = "smasher") -> Dictionary:
	var combo_key: String = character_runtime.get_combo_state_key(character_type)
	return {
		"input_reader": registry.get_instance(character_runtime.get_input_reader_key(character_type)),
		"dash_state": registry.get_instance(character_runtime.get_dash_state_key(character_type)),
		"drive_input_state": registry.get_instance("smasher_drive_input_state") if not character_runtime.is_viper(character_type) else null,
		"skill_state": registry.get_instance(character_runtime.get_skill_state_key(character_type)),
		"skill_config": registry.get_instance(character_runtime.get_skill_config_key(character_type)),
		"power_state": registry.get_instance("smasher_power_smash_state") if not character_runtime.is_viper(character_type) else null,
		"movement_state": registry.get_instance("player_movement_state"),
		"combo_state": registry.get_instance(combo_key) if combo_key != "" else null,
		"orb_hud_state": registry.get_instance("orb_hud_state"),
		"active_item_runtime": registry.get_instance("active_item_runtime"),
		"audio": registry.get_instance("game_audio"),
		"feedback": registry.get_instance("battle_feedback_state"),
	}


func build_boss_ai_context(owner: Object, registry: Object) -> Dictionary:
	var round_state: Object = registry.get_instance("round_flow_state")
	var power_state: Object = registry.get_instance("smasher_power_smash_state")
	var context := {
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
	var whip_state: Object = registry.get_instance("stage1_dalji_whip_skill_state")
	if whip_state != null and whip_state.has_method("get_ai_context"):
		context.merge(whip_state.get_ai_context(), true)
	var active_item_runtime: Object = registry.get_instance("active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("get_boss_ai_context"):
		context.merge(active_item_runtime.get_boss_ai_context(), true)
	return context


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	return BattleSceneOwnerReader.get_vector2(owner, key, fallback)
