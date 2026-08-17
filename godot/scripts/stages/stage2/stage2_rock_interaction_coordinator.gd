extends RefCounted

const Stage2PistolRockBounceState := preload("res://scripts/stages/stage2/stage2_pistol_rock_bounce_state.gd")


func resolve_ball_collision(
	scene: Dictionary,
	context: Dictionary,
	rock_state: Object,
	rock_query: Object,
	collision_geometry: Object,
	hit_callback: Callable,
	deps: Dictionary
) -> bool:
	if not _can_interact(context, rock_state) or rock_query == null or collision_geometry == null:
		return false
	var rocks: Array = rock_state.rocks as Array
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var previous_ball_pos: Vector2 = _get_vector2(scene.get("previous_ball_pos", ball_pos), ball_pos)
	var ball_vel: Vector2 = _get_vector2(scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	var ball_radius: float = float(context.get("ball_size", 28.6)) * 0.5
	for index in range(rocks.size()):
		var rock: Dictionary = rocks[index]
		if not rock_query.is_landed(rock):
			continue
		var center: Vector2 = rock_query.get_center(rock)
		var radius: float = float(rock.get("radius", 28.0))
		if not collision_geometry.segment_hits_circle(previous_ball_pos, ball_pos, center, radius + ball_radius):
			continue
		var normal: Vector2 = ball_pos - center
		if normal.length_squared() <= 0.001:
			normal = -ball_vel.normalized() if ball_vel.length_squared() > 0.001 else Vector2.UP
		else:
			normal = normal.normalized()
		var speed: float = max(4.0, ball_vel.length())
		var reflected: Vector2 = ball_vel.bounce(normal)
		if reflected.length_squared() <= 0.001:
			reflected = normal * speed
		else:
			reflected = reflected.normalized() * speed
		scene["ball_vel"] = reflected
		scene["ball_pos"] = center + normal * (radius + ball_radius + 2.0)
		_call_hit_callback(hit_callback, index, deps, context)
		return true
	return false


func resolve_blade_projectile_collision(
	blade_rect: Rect2,
	context: Dictionary,
	rock_state: Object,
	rock_query: Object,
	collision_geometry: Object,
	hit_callback: Callable,
	deps: Dictionary
) -> int:
	if not _can_interact(context, rock_state) or rock_query == null or collision_geometry == null:
		return 0
	if blade_rect.size.x <= 0.0 or blade_rect.size.y <= 0.0:
		return 0
	var rocks: Array = rock_state.rocks as Array
	var hit_count := 0
	for index in range(rocks.size() - 1, -1, -1):
		var rock: Dictionary = rocks[index]
		if not rock_query.is_landed(rock):
			continue
		var center: Vector2 = rock_query.get_center(rock)
		var radius: float = float(rock.get("radius", 28.0))
		if not collision_geometry.circle_rect_overlap(center, radius, blade_rect):
			continue
		rock["hp"] = 1
		rock_state.replace_at(index, rock)
		_call_hit_callback(hit_callback, index, deps, context)
		hit_count += 1
	return hit_count


func resolve_explosion_rock_collision(
	center: Vector2,
	radius: float,
	context: Dictionary,
	rock_state: Object,
	rock_query: Object,
	hit_callback: Callable,
	deps: Dictionary
) -> int:
	if not _can_interact(context, rock_state) or rock_query == null or radius <= 0.0:
		return 0
	var rocks: Array = rock_state.rocks as Array
	var hit_count := 0
	for index in range(rocks.size() - 1, -1, -1):
		var rock: Dictionary = rocks[index]
		if not rock_query.is_landed(rock):
			continue
		var rock_center: Vector2 = rock_query.get_center(rock)
		var rock_radius: float = max(0.0, float(rock.get("radius", float(rock.get("visual_radius", 28.0)) * 0.5)))
		if rock_center.distance_to(center) > radius + rock_radius:
			continue
		rock["hp"] = 1
		rock_state.replace_at(index, rock)
		_call_hit_callback(hit_callback, index, deps, context)
		hit_count += 1
	return hit_count


func resolve_pistol_projectile_rock_bounce(
	projectile: Dictionary,
	context: Dictionary,
	rock_state: Object,
	rock_query: Object,
	collision_geometry: Object,
	ricochet_callback: Callable,
	deps: Dictionary
) -> Dictionary:
	if not _can_interact(context, rock_state) or rock_query == null or collision_geometry == null:
		return {"bounced": false}
	var rocks: Array = rock_state.rocks as Array
	var pos: Vector2 = _get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var previous_pos: Vector2 = _get_vector2(projectile.get("prev_pos", pos), pos)
	var velocity: Vector2 = _get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	var projectile_radius: float = max(1.0, float(projectile.get("radius", 5.0)))
	var projectile_rect := Rect2(
		pos - Vector2(projectile_radius, projectile_radius),
		Vector2(projectile_radius * 2.0, projectile_radius * 2.0)
	)
	for index in range(rocks.size()):
		var rock: Dictionary = rocks[index]
		if not rock_query.is_landed(rock):
			continue
		var rock_center: Vector2 = rock_query.get_center(rock)
		var rock_radius: float = max(0.0, float(rock.get("radius", float(rock.get("visual_radius", 28.0)) * 0.5)))
		var rock_rect := Rect2(
			rock_center - Vector2(rock_radius, rock_radius),
			Vector2(rock_radius * 2.0, rock_radius * 2.0)
		)
		var rect_hit: bool = projectile_rect.intersects(rock_rect)
		if not rect_hit and not collision_geometry.segment_hits_circle(previous_pos, pos, rock_center, rock_radius + projectile_radius):
			continue
		if Stage2PistolRockBounceState.is_bounce_limit_reached(projectile):
			return {"bounced": false, "consumed": true}
		var hit_side: String = Stage2PistolRockBounceState.get_hit_side(projectile_rect, rock_rect, pos, velocity, rect_hit)
		var bounced_projectile: Dictionary = Stage2PistolRockBounceState.build_projectile(
			projectile,
			pos,
			velocity,
			projectile_radius,
			rock_rect,
			hit_side
		)
		_call_ricochet_callback(ricochet_callback, index, deps)
		return {
			"bounced": true,
			"projectile": bounced_projectile,
			"rock_index": index,
			"rock_id": int(rock.get("id", index)),
			"side": hit_side,
		}
	return {"bounced": false}


func _can_interact(context: Dictionary, rock_state: Object) -> bool:
	return (
		int(context.get("current_stage", 1)) == 2
		and rock_state != null
		and not (rock_state.rocks as Array).is_empty()
	)


func _call_hit_callback(callback: Callable, index: int, deps: Dictionary, context: Dictionary) -> void:
	if callback.is_valid():
		callback.call(index, deps, context)


func _call_ricochet_callback(callback: Callable, index: int, deps: Dictionary) -> void:
	if callback.is_valid():
		callback.call(index, deps)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
