extends RefCounted


static func get_boss_rect(context: Dictionary, field_width: float) -> Rect2:
	var fallback_pos := Vector2(field_width * 0.5 - 50.0, 60.0)
	var boss_pos: Vector2 = get_vector2(context.get("boss_pos", fallback_pos), fallback_pos)
	var boss_width: float = max(1.0, float(context.get("boss_paddle_width", 100.0)))
	var boss_height: float = max(1.0, float(context.get("boss_hitbox_height", 40.0)))
	return Rect2(boss_pos, Vector2(boss_width, boss_height))


static func get_projectile_hitbox_rect(projectile: Dictionary, profile: Dictionary) -> Rect2:
	var pos: Vector2 = get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var radius: float = max(1.0, float(projectile.get("radius", profile.get("radius", 5.0))))
	var fallback_size := Vector2(radius * 2.0, radius * 2.0)
	var size: Vector2 = get_vector2(profile.get("hitbox_size", fallback_size), fallback_size)
	var offset: Vector2 = get_vector2(profile.get("hitbox_offset", Vector2.ZERO), Vector2.ZERO)
	return Rect2(pos - size * 0.5 + offset, size)


static func get_explosion_radius(projectile: Dictionary, profile: Dictionary) -> float:
	return max(1.0, float(projectile.get(
		"explosion_radius",
		profile.get("explosion_radius", projectile.get("impact_radius", profile.get("impact_radius", 24.0)))
	)))


static func expand_rect(rect: Rect2, amount: Vector2) -> Rect2:
	return Rect2(rect.position - amount, rect.size + amount * 2.0)


static func circle_intersects_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(
		clamp(center.x, rect.position.x, rect.end.x),
		clamp(center.y, rect.position.y, rect.end.y)
	)
	return center.distance_squared_to(closest) <= radius * radius


static func circle_contains_rect_center(center: Vector2, radius: float, rect: Rect2) -> bool:
	var rect_center: Vector2 = rect.position + rect.size * 0.5
	return center.distance_squared_to(rect_center) < radius * radius


static func segment_intersects_rect(from_pos: Vector2, to_pos: Vector2, rect: Rect2) -> bool:
	if rect.has_point(from_pos) or rect.has_point(to_pos):
		return true
	var top_left := rect.position
	var top_right := Vector2(rect.end.x, rect.position.y)
	var bottom_right := rect.end
	var bottom_left := Vector2(rect.position.x, rect.end.y)
	var edges := [
		[top_left, top_right],
		[top_right, bottom_right],
		[bottom_right, bottom_left],
		[bottom_left, top_left],
	]
	for edge in edges:
		var intersection: Variant = Geometry2D.segment_intersects_segment(from_pos, to_pos, edge[0], edge[1])
		if intersection != null:
			return true
	return false


static func net_projectile_hits_boss(projectile: Dictionary, profile: Dictionary, boss_rect: Rect2) -> bool:
	var inflate: Vector2 = get_vector2(profile.get("boss_inflate", Vector2(60.0, 40.0)), Vector2(60.0, 40.0))
	var expanded_boss: Rect2 = expand_rect(boss_rect, inflate)
	if get_projectile_hitbox_rect(projectile, profile).intersects(expanded_boss):
		return true
	var pos: Vector2 = get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var prev_pos: Vector2 = get_vector2(projectile.get("prev_pos", pos - get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)), pos)
	var segment_radius: float = max(0.0, float(profile.get("segment_radius", 0.0)))
	if segment_radius > 0.0:
		expanded_boss = expand_rect(expanded_boss, Vector2(segment_radius, segment_radius))
	return segment_intersects_rect(prev_pos, pos, expanded_boss)


static func net_projectile_passed_target(projectile: Dictionary, target: Vector2) -> bool:
	var pos: Vector2 = get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var prev_pos: Vector2 = get_vector2(projectile.get("prev_pos", pos), pos)
	var before: float = prev_pos.distance_to(target)
	var after: float = pos.distance_to(target)
	return after > before and before < 40.0


static func projectile_hitbox_hits_boss(projectile: Dictionary, profile: Dictionary, boss_rect: Rect2) -> bool:
	var weapon_id: String = str(projectile.get("weapon_id", "pistol"))
	if weapon_id == "net_gun":
		return net_projectile_hits_boss(projectile, profile, boss_rect)
	var projectile_rect: Rect2 = get_projectile_hitbox_rect(projectile, profile)
	return projectile_rect.intersects(boss_rect)


static func target_reached_hitbox_hits_boss(projectile: Dictionary, profile: Dictionary, boss_rect: Rect2) -> bool:
	var weapon_id: String = str(projectile.get("weapon_id", "pistol"))
	match weapon_id:
		"bazooka":
			var bazooka_center: Vector2 = get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
			return circle_contains_rect_center(bazooka_center, get_explosion_radius(projectile, profile), boss_rect)
		"fire_support", "suicide_drone":
			var explosion_center: Vector2 = get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
			return circle_contains_rect_center(explosion_center, get_explosion_radius(projectile, profile), boss_rect)
		"net_gun":
			return net_projectile_hits_boss(projectile, profile, boss_rect)
	return false


static func support_bomb_reached_target_y(projectile: Dictionary, profile: Dictionary, boss_rect: Rect2) -> bool:
	var pos: Vector2 = get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var target_y: float = float(projectile.get("target_y", get_vector2(projectile.get("target", pos), pos).y))
	if pos.y < target_y:
		return false
	pos.y = target_y
	projectile["pos"] = pos
	projectile["support_target_y_reached"] = 1.0
	return circle_contains_rect_center(pos, get_explosion_radius(projectile, profile), boss_rect)


static func projectile_reached_target(projectile: Dictionary, target: Vector2) -> bool:
	var pos: Vector2 = get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var velocity: Vector2 = get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	var radius: float = max(2.0, float(projectile.get("radius", 5.0)))
	var step: float = max(radius + 4.0, velocity.length() + radius)
	return pos.distance_to(target) <= step


static func projectile_out_of_bounds(projectile: Dictionary, field_size: Vector2, margin: float = 80.0) -> bool:
	var pos: Vector2 = get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	return (
		pos.x < -margin
		or pos.x > field_size.x + margin
		or pos.y < -margin
		or pos.y > field_size.y + margin
	)


static func is_explosive_wall_impact(projectile: Dictionary, profile: Dictionary, field_width: float) -> bool:
	if str(profile.get("kind", "")) != "rocket":
		return false
	var pos: Vector2 = get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	return pos.y <= 20.0 or pos.x <= 10.0 or pos.x >= field_width - 10.0


static func clamp_explosive_wall_impact(projectile: Dictionary, profile: Dictionary, field_width: float) -> void:
	if not is_explosive_wall_impact(projectile, profile, field_width):
		return
	var pos: Vector2 = get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	pos.x = clamp(pos.x, 10.0, field_width - 10.0)
	if pos.y <= 20.0:
		pos.y = 20.0
	projectile["pos"] = pos


static func explosive_wall_impact_hits_boss(projectile: Dictionary, profile: Dictionary, boss_rect: Rect2, field_width: float) -> bool:
	if not is_explosive_wall_impact(projectile, profile, field_width):
		return false
	var pos: Vector2 = get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	if str(projectile.get("weapon_id", "")) == "bazooka":
		return circle_contains_rect_center(pos, get_explosion_radius(projectile, profile), boss_rect)
	if str(projectile.get("weapon_id", "")) in ["fire_support", "suicide_drone"]:
		return circle_contains_rect_center(pos, get_explosion_radius(projectile, profile), boss_rect)
	return circle_intersects_rect(pos, get_explosion_radius(projectile, profile), boss_rect)


static func get_projectile_impact_reason(
	projectile: Dictionary,
	target: Vector2,
	weapon_id: String,
	profile: Dictionary,
	boss_rect: Rect2,
	field_size: Vector2,
	field_width: float
) -> String:
	var direct_hit_reason: String = get_direct_hit_impact_reason(projectile, profile, boss_rect)
	if direct_hit_reason != "":
		return direct_hit_reason
	var fire_support_target_y_reason: String = get_fire_support_target_y_impact_reason(
		weapon_id,
		projectile,
		profile,
		boss_rect
	)
	if fire_support_target_y_reason != "":
		return fire_support_target_y_reason
	var wall_impact_reason: String = get_explosive_wall_impact_reason(
		projectile,
		profile,
		boss_rect,
		field_width
	)
	if wall_impact_reason != "":
		return wall_impact_reason
	var target_reached_reason: String = get_target_reached_impact_reason(
		weapon_id,
		projectile,
		profile,
		boss_rect,
		target
	)
	if target_reached_reason != "":
		return target_reached_reason
	var net_passed_target_reason: String = get_net_passed_target_impact_reason(weapon_id, projectile, target)
	if net_passed_target_reason != "":
		return net_passed_target_reason
	return get_projectile_terminal_impact_reason(projectile, field_size)


static func get_direct_hit_impact_reason(projectile: Dictionary, profile: Dictionary, boss_rect: Rect2) -> String:
	if projectile_hitbox_hits_boss(projectile, profile, boss_rect):
		return "target"
	return ""


static func get_fire_support_target_y_impact_reason(
	weapon_id: String,
	projectile: Dictionary,
	profile: Dictionary,
	boss_rect: Rect2
) -> String:
	if not is_fire_support_weapon(weapon_id):
		return ""
	if support_bomb_reached_target_y(projectile, profile, boss_rect):
		return "target"
	if support_bomb_target_y_already_reached(projectile):
		return "expired"
	return ""


static func get_net_passed_target_impact_reason(weapon_id: String, projectile: Dictionary, target: Vector2) -> String:
	if not is_net_gun_weapon(weapon_id):
		return ""
	if net_projectile_passed_target(projectile, target):
		return "expired"
	return ""


static func get_explosive_wall_impact_reason(
	projectile: Dictionary,
	profile: Dictionary,
	boss_rect: Rect2,
	field_width: float
) -> String:
	if not is_explosive_wall_impact(projectile, profile, field_width):
		return ""
	clamp_explosive_wall_impact(projectile, profile, field_width)
	if explosive_wall_impact_hits_boss(projectile, profile, boss_rect, field_width):
		return "target"
	return "wall"


static func get_target_reached_impact_reason(
	weapon_id: String,
	projectile: Dictionary,
	profile: Dictionary,
	boss_rect: Rect2,
	target: Vector2
) -> String:
	if not projectile_reached_target(projectile, target):
		return ""
	if target_reached_hitbox_hits_boss(projectile, profile, boss_rect):
		return "target"
	return get_target_reached_expire_reason(weapon_id, profile)


static func get_projectile_terminal_impact_reason(projectile: Dictionary, field_size: Vector2) -> String:
	if projectile_life_expired(projectile):
		return "expired"
	if projectile_out_of_bounds(projectile, field_size):
		return "out_of_bounds"
	return ""


static func get_target_reached_expire_reason(weapon_id: String, profile: Dictionary) -> String:
	if weapon_id == "bazooka":
		return ""
	if str(profile.get("kind", "")) in ["rocket", "support", "drone"]:
		return "expired"
	return ""


static func is_fire_support_weapon(weapon_id: String) -> bool:
	return weapon_id == "fire_support"


static func is_net_gun_weapon(weapon_id: String) -> bool:
	return weapon_id == "net_gun"


static func support_bomb_target_y_already_reached(projectile: Dictionary) -> bool:
	return float(projectile.get("support_target_y_reached", 0.0)) > 0.0


static func projectile_life_expired(projectile: Dictionary) -> bool:
	return float(projectile.get("life_frames", 0.0)) <= 0.0


static func get_hit_knockback_velocity(
	profile: Dictionary,
	pos: Vector2,
	velocity: Vector2,
	boss_center: Vector2
) -> float:
	var base_power: float = float(profile.get("knockback_power", 0.0))
	var velocity_scale: float = float(profile.get("knockback_velocity_scale", 0.0))
	var power: float = base_power + abs(velocity.x) * max(0.0, velocity_scale)
	if power <= 0.001:
		return 0.0
	return float(get_hit_knockback_direction(pos, velocity, boss_center)) * power


static func get_result_hit_profile(profile: Dictionary, result: Dictionary) -> Dictionary:
	if not result.has("knockback_power") and not result.has("knockback_velocity_scale"):
		return profile
	var merged: Dictionary = profile.duplicate(true)
	if result.has("knockback_power"):
		merged["knockback_power"] = float(result.get("knockback_power", merged.get("knockback_power", 0.0)))
	if result.has("knockback_velocity_scale"):
		merged["knockback_velocity_scale"] = float(result.get("knockback_velocity_scale", merged.get("knockback_velocity_scale", 0.0)))
	return merged


static func get_hit_knockback_direction(pos: Vector2, velocity: Vector2, boss_center: Vector2) -> int:
	if abs(pos.x - boss_center.x) > 0.001:
		return 1 if pos.x <= boss_center.x else -1
	if abs(velocity.x) > 0.001:
		return 1 if velocity.x >= 0.0 else -1
	return 1


static func get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
