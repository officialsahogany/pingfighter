extends RefCounted

const DEFAULT_ROBE_COLOR := Color(0.24, 0.20, 0.16, 1.0)
const DEFAULT_WEAPON_COLOR := Color(0.31, 0.24, 0.16, 1.0)


static func build_monk(entrance_pos: Vector2, overrides: Dictionary = {}) -> Dictionary:
	var monk := {
		"x": entrance_pos.x,
		"y": entrance_pos.y,
		"target_x": 200.0,
		"target_y": 510.0,
		"speed": 0.3,
		"direction": 1,
		"walking_phase": 0.0,
		"robe_sway": 0.0,
		"meditation_timer": 0.0,
		"state": "walking",
		"state_timer": 3.0,
		"staff_angle": 0.0,
		"opacity": 0.0,
		"fade_in": true,
		"swing_count": 0,
		"swing_animation": 0.0,
		"swing_cooldown": 0.0,
		"can_deflect": true,
		"returning_to_temple": false,
		"has_hit_ball": false,
		"swing_chance_used": false,
		"is_smoke_grenade_monk": false,
		"smoke_return_timer": 0.0,
		"monk_type": "normal",
		"robe_color": DEFAULT_ROBE_COLOR,
		"hat_type": "",
		"weapon_type": "basic_staff",
		"weapon_color": DEFAULT_WEAPON_COLOR,
		"swing_chance": 0.2,
		"speed_boost": 1.0,
	}
	monk.merge(overrides, true)
	return monk


static func build_hit_effects(monk: Dictionary, hit_tip_offset: Vector2, random: RandomNumberGenerator) -> Array:
	var effects: Array = []
	var direction := 1.0 if int(monk.get("direction", 1)) >= 0 else -1.0
	var staff_tip := Vector2(float(monk.get("x", 0.0)), float(monk.get("y", 0.0))) + Vector2(hit_tip_offset.x * direction, hit_tip_offset.y)
	effects.append({
		"type": "shockwave",
		"x": staff_tip.x,
		"y": staff_tip.y,
		"radius": 8.0,
		"alpha": 255.0,
		"life": 1.0,
	})
	for idx in range(8):
		var spark_angle: float = float(idx) * TAU / 8.0 + random.randf_range(-0.18, 0.18)
		var speed: float = random.randf_range(1.2, 3.8)
		effects.append({
			"type": "spark",
			"x": staff_tip.x,
			"y": staff_tip.y,
			"vx": cos(spark_angle) * speed,
			"vy": sin(spark_angle) * speed,
			"alpha": 255.0,
			"life": random.randf_range(12.0, 20.0),
		})
	return effects


static func build_explosion_particles(
	pos: Vector2,
	robe_color: Color,
	hero: bool,
	random: RandomNumberGenerator
) -> Array:
	var particles: Array = []
	var body_types := ["head", "torso", "arm", "arm", "leg", "leg"]
	for idx in range(body_types.size()):
		var angle: float = (float(idx) / float(body_types.size())) * TAU + random.randf_range(-0.28, 0.28)
		var speed: float = random.randf_range(2.0, 5.2) * (1.35 if hero else 1.0)
		particles.append({
			"type": body_types[idx],
			"x": pos.x,
			"y": pos.y,
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed - random.randf_range(1.0, 3.2),
			"size": random.randf_range(6.0, 12.0) * (1.22 if hero else 1.0),
			"rotation": random.randf_range(0.0, 360.0),
			"rotation_speed": random.randf_range(-12.0, 12.0),
			"gravity": 0.14,
			"life": random.randf_range(60.0, 92.0),
			"opacity": 1.0,
			"color": robe_color.lightened(0.18) if hero else robe_color,
		})
	for _idx in range(12 if hero else 8):
		var angle: float = random.randf_range(0.0, TAU)
		var speed: float = random.randf_range(1.0, 4.0) * (1.35 if hero else 1.0)
		particles.append({
			"type": "spark",
			"x": pos.x,
			"y": pos.y,
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed - 1.5,
			"size": random.randf_range(2.0, 4.0),
			"rotation": 0.0,
			"rotation_speed": 0.0,
			"gravity": 0.08,
			"life": random.randf_range(24.0, 44.0),
			"opacity": 1.0,
			"color": Color(1.0, 0.86, 0.30, 1.0) if hero else Color(0.42, 0.34, 0.24, 1.0),
		})
	return particles
