extends RefCounted

const PARTICLE_COUNT := 32
const RNG_SEED := 0x10617
const SKY_BAND_RATIO := 0.33
const SKY_LIGHT_COUNT := 24
const SKY_LIGHT_BLINK_PERIOD_MIN := 1.4
const SKY_LIGHT_BLINK_PERIOD_MAX := 5.0
const SILHOUETTE_SPAWN_MIN_SEC := 14.0
const SILHOUETTE_SPAWN_MAX_SEC := 28.0
const SILHOUETTE_MAX_ACTIVE := 2

var particles: Array[Dictionary] = []
var sky_lights: Array[Dictionary] = []
var silhouettes: Array[Dictionary] = []
var next_silhouette_spawn_time := 0.0
var elapsed_time := 0.0
var rng := RandomNumberGenerator.new()


func seed_rng() -> void:
	rng.seed = RNG_SEED


func seed_particles(view_size: Vector2, scatter_initial: bool) -> void:
	particles.clear()
	for _index in PARTICLE_COUNT:
		particles.append(make_particle(view_size, scatter_initial))


func make_particle(view_size: Vector2, scatter_initial: bool) -> Dictionary:
	var lifetime := rng.randf_range(9.0, 15.0)
	var initial_y: float
	var initial_age: float
	if scatter_initial:
		initial_y = rng.randf_range(0.0, view_size.y)
		initial_age = rng.randf_range(0.0, lifetime * 0.85)
	else:
		initial_y = view_size.y + rng.randf_range(20.0, 80.0)
		initial_age = 0.0
	var kind := "white" if rng.randf() < 0.82 else "violet"
	return {
		"x": rng.randf_range(0.0, view_size.x),
		"y": initial_y,
		"vx": rng.randf_range(-5.0, 5.0),
		"vy": rng.randf_range(-24.0, -11.0),
		"age": initial_age,
		"lifetime": lifetime,
		"size": rng.randf_range(1.3, 2.7),
		"kind": kind,
	}


func update_particles(delta: float, view_size: Vector2) -> void:
	for particle in particles:
		particle["x"] = float(particle["x"]) + float(particle["vx"]) * delta
		particle["y"] = float(particle["y"]) + float(particle["vy"]) * delta
		particle["age"] = float(particle["age"]) + delta
		if float(particle["age"]) >= float(particle["lifetime"]) or float(particle["y"]) < -30.0:
			var fresh := make_particle(view_size, false)
			for key in fresh:
				particle[key] = fresh[key]


func seed_sky_lights() -> void:
	sky_lights.clear()
	for _index in SKY_LIGHT_COUNT:
		sky_lights.append({
			"x_rel": rng.randf(),
			"y_rel": rng.randf_range(0.05, 0.92),
			"blink_period": rng.randf_range(SKY_LIGHT_BLINK_PERIOD_MIN, SKY_LIGHT_BLINK_PERIOD_MAX),
			"phase": rng.randf_range(0.0, TAU),
			"size": rng.randf_range(0.7, 1.9),
			"color_kind": rng.randi() % 3,
		})


func schedule_next_silhouette() -> void:
	next_silhouette_spawn_time = elapsed_time + rng.randf_range(SILHOUETTE_SPAWN_MIN_SEC, SILHOUETTE_SPAWN_MAX_SEC)


func make_silhouette(view_size: Vector2) -> Dictionary:
	var is_drone := rng.randf() < 0.45
	var go_right := rng.randf() < 0.5
	var sky_h := view_size.y * SKY_BAND_RATIO
	var y := rng.randf_range(sky_h * 0.18, sky_h * 0.82)
	var speed: float
	if is_drone:
		speed = rng.randf_range(40.0, 75.0)
	else:
		speed = rng.randf_range(90.0, 150.0)
	var start_x := -60.0 if go_right else view_size.x + 60.0
	return {
		"kind": "drone" if is_drone else "bird",
		"x": start_x,
		"y": y,
		"vx": speed if go_right else -speed,
		"vy": rng.randf_range(-3.5, 3.5),
		"age": 0.0,
		"phase": rng.randf_range(0.0, TAU),
		"scale": rng.randf_range(0.85, 1.4),
	}


func update_silhouettes(delta: float, view_size: Vector2) -> void:
	if elapsed_time >= next_silhouette_spawn_time and silhouettes.size() < SILHOUETTE_MAX_ACTIVE:
		silhouettes.append(make_silhouette(view_size))
		schedule_next_silhouette()
	var index := silhouettes.size() - 1
	while index >= 0:
		var silhouette: Dictionary = silhouettes[index]
		silhouette["x"] = float(silhouette["x"]) + float(silhouette["vx"]) * delta
		silhouette["y"] = float(silhouette["y"]) + float(silhouette["vy"]) * delta
		silhouette["age"] = float(silhouette["age"]) + delta
		var x_pos := float(silhouette["x"])
		var direction := 1.0 if float(silhouette["vx"]) > 0.0 else -1.0
		if (direction > 0.0 and x_pos > view_size.x + 80.0) or (direction < 0.0 and x_pos < -80.0):
			silhouettes.remove_at(index)
		index -= 1
