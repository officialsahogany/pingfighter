extends RefCounted

const DEFAULT_WIDTH := 760.0
const DEFAULT_HEIGHT := 750.0


static func build_crow(side_override: String, random: RandomNumberGenerator, width: float = DEFAULT_WIDTH) -> Dictionary:
	var start_side := side_override
	if start_side not in ["left", "right"]:
		start_side = "left" if random.randi_range(0, 1) == 0 else "right"

	var x := -50.0
	var vx := random.randf_range(1.5, 3.0)
	if start_side == "right":
		x = width + 50.0
		vx = random.randf_range(-3.0, -1.5)
	var spawn_y := float(random.randi_range(50, 200))
	return {
		"x": x,
		"y": spawn_y,
		"vx": vx,
		"vy": random.randf_range(-0.3, 0.3),
		"wing_phase": random.randf_range(0.0, TAU),
		"wing_speed": random.randf_range(0.15, 0.25),
		"size": random.randi_range(20, 30),
		"caught": false,
		"glow_timer": 0.0,
		"hitbox_radius": 25.0,
		"gold_dust": [],
		"dust_spawn_accum": random.randf(),
		"last_x": x,
		"last_y": spawn_y,
	}


static func build_gold_dust_particle(
	crow: Dictionary,
	prev_pos: Vector2,
	current_pos: Vector2,
	direction: float,
	size: float,
	random: RandomNumberGenerator
) -> Dictionary:
	var t: float = random.randf()
	var base_x: float = lerpf(prev_pos.x, current_pos.x, t)
	var base_y: float = lerpf(prev_pos.y, current_pos.y, t)
	var tail_offset: float = random.randf_range(size * 0.55, size * 1.35)
	var wing_offset: float = sin(float(crow.get("wing_phase", 0.0)) + t * TAU) * size * 0.16
	var life: float = float(random.randi_range(42, 78))
	return {
		"x": base_x - direction * tail_offset + random.randf_range(-5.0, 5.0),
		"y": base_y + wing_offset + random.randf_range(-size * 0.18, size * 0.24),
		"vx": float(crow.get("vx", 0.0)) * 0.06 - direction * random.randf_range(0.04, 0.34),
		"vy": random.randf_range(0.08, 0.42),
		"gravity": random.randf_range(0.006, 0.017),
		"life": life,
		"max_life": life,
		"size": random.randf_range(1.0, 2.8),
		"phase": random.randf_range(0.0, TAU),
		"phase_speed": random.randf_range(0.12, 0.28),
	}


static func build_crow_fragments(x: float, y: float, size: int, random: RandomNumberGenerator) -> Array:
	var fragments: Array = []
	var fragment_count: int = random.randi_range(6, 8)
	for idx in range(fragment_count):
		var angle: float = (float(idx) / float(fragment_count)) * TAU + random.randf_range(-0.3, 0.3)
		var speed: float = random.randf_range(2.0, 6.0)
		var frag_type := "feather" if random.randf() < 0.52 else "fragment"
		var point_count: int = 6 if frag_type == "feather" else random.randi_range(5, 7)
		var shape_offsets: Array = []
		for _point in range(point_count):
			shape_offsets.append(random.randf_range(0.6, 1.0))
		fragments.append({
			"x": x,
			"y": y,
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed - random.randf_range(1.0, 3.0),
			"size": random.randi_range(3, maxi(4, int(floor(float(size) * 0.5)))),
			"rotation": random.randf_range(0.0, 360.0),
			"rotation_speed": random.randf_range(-15.0, 15.0),
			"gravity": 0.15,
			"life": float(random.randi_range(60, 90)),
			"color": Color(0.08 + random.randf() * 0.05, 0.06 + random.randf() * 0.04, 0.10 + random.randf() * 0.06, 1.0),
			"type": frag_type,
			"opacity": 1.0,
			"num_points": point_count,
			"shape_offsets": shape_offsets,
		})
	return fragments


static func build_crow_debris_particles(x: float, y: float, count: int, random: RandomNumberGenerator) -> Array:
	var particles: Array = []
	for _idx in range(maxi(0, count)):
		var particle_angle: float = random.randf_range(0.0, TAU)
		var particle_speed: float = random.randf_range(1.0, 4.0)
		particles.append({
			"x": x,
			"y": y,
			"vx": cos(particle_angle) * particle_speed,
			"vy": sin(particle_angle) * particle_speed - 2.0,
			"size": random.randi_range(1, 3),
			"life": float(random.randi_range(20, 40)),
			"color": Color(0.16, 0.14, 0.18, 1.0),
			"opacity": 0.78,
			"rotation": random.randf_range(0.0, 360.0),
			"shape_offsets": [
				random.randf_range(0.7, 1.0),
				random.randf_range(0.7, 1.0),
				random.randf_range(0.7, 1.0),
				random.randf_range(0.7, 1.0),
			],
		})
	return particles
