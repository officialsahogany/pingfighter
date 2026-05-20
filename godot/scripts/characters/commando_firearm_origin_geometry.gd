extends RefCounted


static func get_player_muzzle_pos(config: Dictionary, field_size: Vector2) -> Vector2:
	var player_pos: Vector2 = get_player_pos_from_config(config, field_size)
	var paddle_width: float = get_player_paddle_width_from_config(config)
	var paddle_height: float = get_player_paddle_height_from_config(config)
	return Vector2(
		player_pos.x + paddle_width * 0.5,
		player_pos.y + min(paddle_height * 0.34, 18.0)
	)


static func get_commando_fire_sheet_world_pos(
	config: Dictionary,
	source_pos: Vector2,
	field_size: Vector2,
	source_cell_size: Vector2,
	player_foot_y_offset: float
) -> Vector2:
	var player_pos: Vector2 = get_player_pos_from_config(config, field_size)
	var paddle_width: float = get_player_paddle_width_from_config(config)
	var paddle_height: float = get_player_paddle_height_from_config(config)
	var paddle_scale: float = get_player_paddle_scale_from_config(config, paddle_width)
	var draw_size: Vector2 = source_cell_size * paddle_scale
	var visual_top_left := Vector2(
		player_pos.x + paddle_width * 0.5 - draw_size.x * 0.5,
		player_pos.y + paddle_height - draw_size.y + player_foot_y_offset
	)
	return visual_top_left + source_pos * paddle_scale


static func get_player_pos_from_config(config: Dictionary, field_size: Vector2) -> Vector2:
	var fallback := Vector2(field_size.x * 0.5, field_size.y - 70.0)
	return get_vector2(config.get("player_pos", fallback), fallback)


static func get_player_paddle_width_from_config(config: Dictionary) -> float:
	return max(1.0, float(config.get("paddle_width", config.get("player_paddle_width", 155.0))))


static func get_player_paddle_height_from_config(config: Dictionary) -> float:
	return max(1.0, float(config.get("paddle_height", config.get("player_paddle_height", 50.0))))


static func get_player_paddle_scale_from_config(config: Dictionary, paddle_width: float) -> float:
	return max(0.1, float(config.get("player_paddle_scale", max(1.0, paddle_width / 155.0))))


static func get_boss_target_pos(config: Dictionary, field_width: float) -> Vector2:
	var fallback := Vector2(field_width * 0.5 - 50.0, 60.0)
	var boss_pos: Vector2 = get_vector2(config.get("boss_pos", fallback), fallback)
	var boss_width: float = max(1.0, float(config.get("boss_paddle_width", 100.0)))
	var boss_height: float = max(1.0, float(config.get("boss_hitbox_height", 40.0)))
	return Vector2(
		boss_pos.x + boss_width * 0.5,
		boss_pos.y + boss_height * 0.5
	)


static func get_firearm_origin(
	weapon_id: String,
	config: Dictionary,
	profile: Dictionary,
	field_size: Vector2,
	source_cell_size: Vector2,
	player_foot_y_offset: float,
	pistol_muzzle_source: Vector2,
	bazooka_muzzle_source: Vector2,
	net_gun_muzzle_source: Vector2,
	base_weapon_id: String
) -> Vector2:
	if is_pistol_weapon(weapon_id, base_weapon_id) and not bool(profile.get("slingshot", false)):
		return get_commando_fire_sheet_world_pos(
			config,
			pistol_muzzle_source,
			field_size,
			source_cell_size,
			player_foot_y_offset
		)
	if bool(profile.get("vertical_launch", false)):
		return get_commando_fire_sheet_world_pos(
			config,
			bazooka_muzzle_source,
			field_size,
			source_cell_size,
			player_foot_y_offset
		)
	if weapon_id == "net_gun":
		return get_commando_fire_sheet_world_pos(
			config,
			net_gun_muzzle_source,
			field_size,
			source_cell_size,
			player_foot_y_offset
		)
	return get_player_muzzle_pos(config, field_size)


static func get_firearm_aim_origin(_weapon_id: String, origin: Vector2) -> Vector2:
	return origin


static func is_pistol_weapon(weapon_id: String, base_weapon_id: String) -> bool:
	return weapon_id == base_weapon_id or weapon_id == "commando_pistol"


static func get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
