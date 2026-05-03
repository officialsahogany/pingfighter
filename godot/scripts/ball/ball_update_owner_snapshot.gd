extends RefCounted


func build(owner: Object) -> Dictionary:
	var textures: Dictionary = _get_owner_dict(owner, "battle_textures")
	return {
		"ball_pos": _get_owner_vector2(owner, "ball_pos", Vector2.ZERO),
		"ball_vel": _get_owner_vector2(owner, "ball_vel", Vector2.ZERO),
		"ball_active": bool(_get_owner_value(owner, "ball_active", false)),
		"ball_impact_boost": float(_get_owner_value(owner, "ball_impact_boost", 1.0)),
		"ball_boost_decay_rate": float(_get_owner_value(owner, "ball_boost_decay_rate", 0.975)),
		"ball_min_boost": float(_get_owner_value(owner, "ball_min_boost", 0.70)),
		"player_collision_cooldown": float(_get_owner_value(owner, "player_collision_cooldown", 0.0)),
		"boss_collision_cooldown": float(_get_owner_value(owner, "boss_collision_cooldown", 0.0)),
		"vertical_bounce_count": int(_get_owner_value(owner, "vertical_bounce_count", 0)),
		"ball_spin_strength": float(_get_owner_value(owner, "ball_spin_strength", 0.0)),
		"ball_spin_direction": int(_get_owner_value(owner, "ball_spin_direction", 0)),
		"drive_speed_increase": float(_get_owner_value(owner, "drive_speed_increase", 0.0)),
		"drive_ball_active": bool(_get_owner_value(owner, "drive_ball_active", false)),
		"drive_hit_boss": bool(_get_owner_value(owner, "drive_hit_boss", false)),
		"special_gauge": float(_get_owner_value(owner, "special_gauge", 0.0)),
		"player_speed": float(_get_owner_value(owner, "player_speed", 0.0)),
		"boss_vel": float(_get_owner_value(owner, "boss_vel", 0.0)),
		"player_pos": _get_owner_vector2(owner, "player_pos", Vector2.ZERO),
		"boss_pos": _get_owner_vector2(owner, "boss_pos", Vector2.ZERO),
		"drive_text_timer_frames": float(_get_owner_value(owner, "drive_text_timer_frames", 0.0)),
		"gameplay_frame_counter": int(_get_owner_value(owner, "gameplay_frame_counter", 0)),
		"current_stage": int(_get_owner_value(owner, "current_stage", 1)),
		"selected_character_type": str(_get_owner_value(owner, "selected_character_type", "smasher")),
		"player_has_hit_sprite": _has_texture(textures, "player_attack_sheet")
			or _has_texture(textures, "player_hit_sprite_texture")
			or _has_texture(textures, "player_hit_left_strip_texture")
			or _has_texture(textures, "player_hit_right_strip_texture"),
		"boss_has_hit_sprite": _has_texture(textures, "boss_attack_sheet")
			or _has_texture(textures, "boss_hit_sprite_sheet"),
	}


func get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	return _get_owner_vector2(owner, key, fallback)


func get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return _get_owner_value(owner, key, fallback)


func _has_texture(textures: Dictionary, key: String) -> bool:
	return textures.get(key, null) is Texture2D


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


func _get_owner_dict(owner: Object, key: String) -> Dictionary:
	var value: Variant = _get_owner_value(owner, key, {})
	if value is Dictionary:
		return value
	return {}
