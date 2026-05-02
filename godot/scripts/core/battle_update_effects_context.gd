extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const BALL_SIZE: float = 22.0


func build_context(owner: Object, registry: Object) -> Dictionary:
	var textures: Dictionary = _get_owner_dict(owner, "battle_textures")
	return {
		"current_msec": Time.get_ticks_msec(),
		"dash_snapshot": _get_dash_snapshot(registry),
		"drive_text_timer_frames": float(_get_owner_value(owner, "drive_text_timer_frames", 0.0)),
		"ball_pos": _get_owner_vector2(owner, "ball_pos", Vector2.ZERO),
		"ball_active": bool(_get_owner_value(owner, "ball_active", false)),
		"ball_size": BALL_SIZE,
		"special_gauge": float(_get_owner_value(owner, "special_gauge", 0.0)),
		"player_speed": float(_get_owner_value(owner, "player_speed", 0.0)),
		"player_has_sprite": _has_texture(textures, "player_sprite_texture"),
		"player_has_idle_sprite": _has_texture(textures, "player_idle_sprite_texture"),
		"boss_vel": float(_get_owner_value(owner, "boss_vel", 0.0)),
		"boss_has_sprite": _has_texture(textures, "boss_sprite_sheet"),
	}


func build_deps(registry: Object) -> Dictionary:
	return {
		"feedback": registry.get_instance("battle_feedback_state"),
		"audio": registry.get_instance("game_audio"),
		"scoreboard_state": registry.get_instance("scoreboard_state"),
		"power_state": registry.get_instance("smasher_power_smash_state"),
		"combo_state": registry.get_instance("smasher_combo_state"),
		"stage_background": registry.get_instance("stage1_pillar_background"),
		"orb_hud_state": registry.get_instance("orb_hud_state"),
		"animation_state": registry.get_instance("actor_animation_state"),
		"impact_effects": registry.get_instance("impact_effects"),
	}


func _get_dash_snapshot(registry: Object) -> Dictionary:
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


func _has_texture(textures: Dictionary, key: String) -> bool:
	return textures.get(key, null) is Texture2D


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	return BattleSceneOwnerReader.get_vector2(owner, key, fallback)


func _get_owner_dict(owner: Object, key: String) -> Dictionary:
	return BattleSceneOwnerReader.get_dictionary(owner, key)
