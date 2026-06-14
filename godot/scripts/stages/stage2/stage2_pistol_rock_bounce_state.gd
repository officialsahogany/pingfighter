extends RefCounted

const BOUNCE_MAX := 2
const BOUNCE_DAMPING := 0.88
const BOUNCE_MIN_SPEED := 6.0
const BOUNCE_EPSILON := 0.1


static func is_bounce_limit_reached(projectile: Dictionary) -> bool:
	return int(projectile.get("rock_bounces", 0)) >= BOUNCE_MAX


static func get_hit_side(
	projectile_rect: Rect2,
	rock_rect: Rect2,
	pos: Vector2,
	velocity: Vector2,
	rect_hit: bool
) -> String:
	if rect_hit:
		var overlap_left: float = projectile_rect.end.x - rock_rect.position.x
		var overlap_right: float = rock_rect.end.x - projectile_rect.position.x
		var overlap_top: float = projectile_rect.end.y - rock_rect.position.y
		var overlap_bottom: float = rock_rect.end.y - projectile_rect.position.y
		var hit_side := "left"
		var min_overlap := overlap_left
		if overlap_right < min_overlap:
			min_overlap = overlap_right
			hit_side = "right"
		if overlap_top < min_overlap:
			min_overlap = overlap_top
			hit_side = "top"
		if overlap_bottom < min_overlap:
			hit_side = "bottom"
		return hit_side
	var relative: Vector2 = pos - (rock_rect.position + rock_rect.size * 0.5)
	if relative.length_squared() <= 0.001:
		relative = -velocity
	if abs(relative.x) > abs(relative.y):
		return "left" if relative.x <= 0.0 else "right"
	return "top" if relative.y <= 0.0 else "bottom"


static func build_projectile(
	projectile: Dictionary,
	pos: Vector2,
	velocity: Vector2,
	projectile_radius: float,
	rock_rect: Rect2,
	hit_side: String
) -> Dictionary:
	var next_projectile: Dictionary = projectile.duplicate(true)
	match hit_side:
		"left":
			pos.x = rock_rect.position.x - projectile_radius - BOUNCE_EPSILON
			velocity.x = -max(abs(velocity.x) * BOUNCE_DAMPING, BOUNCE_MIN_SPEED)
		"right":
			pos.x = rock_rect.end.x + projectile_radius + BOUNCE_EPSILON
			velocity.x = max(abs(velocity.x) * BOUNCE_DAMPING, BOUNCE_MIN_SPEED)
		"top":
			pos.y = rock_rect.position.y - projectile_radius - BOUNCE_EPSILON
			velocity.y = -max(abs(velocity.y) * BOUNCE_DAMPING, BOUNCE_MIN_SPEED)
		_:
			pos.y = rock_rect.end.y + projectile_radius + BOUNCE_EPSILON
			velocity.y = max(abs(velocity.y) * BOUNCE_DAMPING, BOUNCE_MIN_SPEED)
	next_projectile["rock_bounces"] = int(next_projectile.get("rock_bounces", 0)) + 1
	next_projectile["pos"] = pos
	next_projectile["velocity"] = velocity
	next_projectile["speed"] = velocity.length()
	next_projectile["stage2_rock_bounce_side"] = hit_side
	return next_projectile
