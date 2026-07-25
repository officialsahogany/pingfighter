extends RefCounted

const HEART_PARTICLE_LIMIT := 34
const HEART_SPAWN_CHANCE_PER_60FPS := 0.010
const STADIUM_SPARK_MIN_INTERVAL_SEC := 12.0
const STADIUM_SPARK_MAX_INTERVAL_SEC := 25.0
const STADIUM_SPARK_BURST_SEC := 0.85

var rng := RandomNumberGenerator.new()
var last_update_msec := 0
var time_sec := 0.0
var emotional_phase := 0
var heart_particles: Array = []
var stadium_spark_next_time := STADIUM_SPARK_MIN_INTERVAL_SEC
var stadium_spark_active_start := -1.0
var stadium_spark_cycle_index := 0
var stadium_spark_direction := 1.0


func _init() -> void:
	rng.seed = 3303


func reset(width: float = 760.0, height: float = 750.0) -> void:
	last_update_msec = 0
	time_sec = 0.0
	emotional_phase = 0
	heart_particles.clear()
	stadium_spark_next_time = rng.randf_range(STADIUM_SPARK_MIN_INTERVAL_SEC, STADIUM_SPARK_MAX_INTERVAL_SEC)
	stadium_spark_active_start = -1.0
	stadium_spark_cycle_index = 0
	stadium_spark_direction = 1.0
	for _index in range(4):
		heart_particles.append(make_heart_particle(width, height, true))


func tick_delta(now_msec: int = -1) -> float:
	var now := Time.get_ticks_msec() if now_msec < 0 else now_msec
	if last_update_msec <= 0:
		last_update_msec = now
		return 1.0 / 60.0
	var delta := clampf(float(now - last_update_msec) / 1000.0, 0.0, 0.05)
	last_update_msec = now
	if delta <= 0.0:
		delta = 1.0 / 60.0
	time_sec += delta
	return delta


func sync_phase(context: Dictionary) -> void:
	var phase_value: Variant = context.get("stage3_emotional_phase", null)
	if phase_value != null:
		emotional_phase = wrapi(int(phase_value), 0, 3)


func advance_stadium_spark() -> bool:
	if stadium_spark_active_start < 0.0:
		if time_sec < stadium_spark_next_time:
			return false
		stadium_spark_active_start = time_sec
		stadium_spark_cycle_index += 1
		stadium_spark_direction = -1.0 if stadium_spark_cycle_index % 2 == 1 else 1.0
	if get_stadium_spark_burst_time() >= STADIUM_SPARK_BURST_SEC:
		stadium_spark_active_start = -1.0
		stadium_spark_next_time = time_sec + rng.randf_range(STADIUM_SPARK_MIN_INTERVAL_SEC, STADIUM_SPARK_MAX_INTERVAL_SEC)
		return false
	return true


func get_stadium_spark_burst_time() -> float:
	return time_sec - stadium_spark_active_start


func update_particles(delta: float, width: float, height: float) -> void:
	var fps_scale := delta * 60.0
	if rng.randf() < HEART_SPAWN_CHANCE_PER_60FPS * fps_scale and heart_particles.size() < HEART_PARTICLE_LIMIT:
		heart_particles.append(make_heart_particle(width, height, false))
	var write_index := 0
	for index in range(heart_particles.size()):
		var particle: Dictionary = heart_particles[index]
		particle["x"] = float(particle.get("x", 0.0)) + float(particle.get("vx", 0.0)) * fps_scale
		particle["y"] = float(particle.get("y", 0.0)) + float(particle.get("vy", 0.0)) * fps_scale
		particle["life"] = float(particle.get("life", 0.0)) - fps_scale
		particle["twinkle"] = float(particle.get("twinkle", 0.0)) + 0.12 * fps_scale
		if float(particle.get("life", 0.0)) <= 0.0:
			continue
		heart_particles[write_index] = particle
		write_index += 1
	heart_particles.resize(write_index)


func make_heart_particle(width: float, height: float, initial: bool) -> Dictionary:
	return {
		"x": rng.randf_range(70.0, maxf(71.0, width - 70.0)),
		"y": rng.randf_range(90.0, maxf(91.0, height - 90.0)) if initial else height + 22.0,
		"vx": rng.randf_range(-0.30, 0.30),
		"vy": rng.randf_range(-1.50, -0.70),
		"size": rng.randi_range(8, 17),
		"broken": emotional_phase == 2 or rng.randf() < 0.30,
		"color_index": rng.randi_range(0, 2),
		"life": rng.randf_range(210.0, 420.0) if initial else rng.randf_range(260.0, 560.0),
		"twinkle": rng.randf_range(0.0, TAU),
	}
