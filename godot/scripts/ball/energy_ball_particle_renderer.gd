extends RefCounted

const BALL_RENDER_RADIUS := 13.0
const ENERGY_BALL_MAX_PARTICLES := 20
const ENERGY_BALL_PARTICLE_COLORS: Array[Color] = [
	Color(200.0 / 255.0, 230.0 / 255.0, 1.0),
	Color(150.0 / 255.0, 200.0 / 255.0, 1.0),
	Color(100.0 / 255.0, 180.0 / 255.0, 1.0),
	Color(1.0, 1.0, 1.0),
]

var particles: Array[Dictionary] = []


func clear() -> void:
	particles.clear()


func draw(canvas: CanvasItem, pos: Vector2) -> void:
	_spawn_particles()
	_draw_particles(canvas, pos)


func _spawn_particles() -> void:
	if randf() >= 0.4:
		return
	var spawn_angle: float = randf_range(0.0, TAU)
	var spawn_dist: float = BALL_RENDER_RADIUS * randf_range(0.867, 1.445)
	particles.append({
		"x": cos(spawn_angle) * spawn_dist,
		"y": sin(spawn_angle) * spawn_dist,
		"vx": randf_range(-0.5, 0.5),
		"vy": randf_range(-1.5, -0.5),
		"life": float(randi_range(20, 40)),
		"max_life": 40.0,
		"size": randf_range(0.42, 1.02),
		"color": ENERGY_BALL_PARTICLE_COLORS[randi_range(0, ENERGY_BALL_PARTICLE_COLORS.size() - 1)]
	})

	while particles.size() > ENERGY_BALL_MAX_PARTICLES:
		particles.pop_front()


func _draw_particles(canvas: CanvasItem, pos: Vector2) -> void:
	var new_particles: Array[Dictionary] = []
	for particle in particles:
		var p: Dictionary = particle
		var px: float = float(p["x"]) + float(p["vx"])
		var py: float = float(p["y"]) + float(p["vy"])
		var life: float = float(p["life"]) - 1.0
		var max_life: float = float(p["max_life"])
		var base_size: float = float(p["size"])
		var color: Color = p["color"]

		p["x"] = px
		p["y"] = py
		p["life"] = life

		if life > 0.0:
			var alpha: float = (200.0 * (life / max_life)) / 255.0
			var size: float = max(1.0, floor(base_size * (life / max_life)))
			var particle_pos: Vector2 = pos + Vector2(px, py)
			canvas.draw_circle(particle_pos, size + 2.0, Color(color.r, color.g, color.b, alpha * 0.33))
			canvas.draw_circle(particle_pos, size, Color(color.r, color.g, color.b, alpha))
			new_particles.append(p)

	particles = new_particles
