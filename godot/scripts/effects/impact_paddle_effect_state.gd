extends RefCounted

const PADDLE_HIT_PLAYER_COLOR_LIGHT := Color(0.40, 0.60, 1.0)
const PADDLE_HIT_BOSS_COLOR_LIGHT := Color(1.0, 0.45, 0.35)
const HIGH_INTENSITY_COLOR := Color(1.0, 0.38, 0.80)
const CORE_FLASH_COLOR := Color(0.93, 0.97, 1.0)
const HIT_PARTICLE_COUNT := 2
const HIT_PARTICLE_FORCE_BONUS := 1.35
const HIT_PARTICLE_SPAWN_MAX := 3
const HIT_STREAK_BASE_COUNT := 1
const HIT_STREAK_FORCE_BONUS := 0.90
const HIT_STREAK_SPAWN_MAX := 2
const HIT_PARTICLE_MAX_COUNT := 18
const HIT_RING_MAX_COUNT := 6
const HIT_STREAK_MAX_COUNT := 10
const HIT_FLASH_MAX_COUNT := 5
const SPARK_LIFE_MIN := 0.12
const SPARK_LIFE_MAX := 0.24
const RING_LIFE := 0.20
const STREAK_LIFE := 0.12
const FLASH_LIFE := 0.12

var hit_particles: Array[Dictionary] = []
var hit_rings: Array[Dictionary] = []
var hit_streaks: Array[Dictionary] = []
var hit_flashes: Array[Dictionary] = []


func clear() -> void:
	hit_particles.clear()
	hit_rings.clear()
	hit_streaks.clear()
	hit_flashes.clear()


func spawn_hit_particles(
	pos: Vector2,
	color: Color,
	direction: Vector2 = Vector2.ZERO,
	intensity: float = 0.0,
	impact_speed: float = 0.0
) -> void:
	var burst_direction: Vector2 = _resolve_direction(direction)
	var force: float = _resolve_force(intensity, impact_speed)
	_spawn_flash(pos, color, force)
	_spawn_rings(pos, color, burst_direction, force)
	_spawn_streaks(pos, color, burst_direction, force)
	_spawn_sparks(pos, color, burst_direction, force)
	_trim_effects()


func spawn_paddle_hit_particles(
	pos: Vector2,
	is_player: bool,
	ball_vel: Vector2 = Vector2.ZERO,
	intensity: float = 0.0
) -> void:
	var base_color: Color = PADDLE_HIT_PLAYER_COLOR_LIGHT if is_player else PADDLE_HIT_BOSS_COLOR_LIGHT
	var hit_color: Color = base_color.lerp(HIGH_INTENSITY_COLOR, clamp(intensity * 0.55, 0.0, 0.55))
	var fallback_direction := Vector2(0.0, -1.0 if is_player else 1.0)
	var direction: Vector2 = ball_vel if ball_vel.length_squared() > 0.001 else fallback_direction
	spawn_hit_particles(pos, hit_color, direction, intensity, ball_vel.length())


func update(delta: float) -> void:
	var fps_scale: float = delta * 60.0
	_update_particles(delta, fps_scale)
	_update_timed_effects(hit_rings, delta)
	_update_timed_effects(hit_streaks, delta, fps_scale)
	_update_timed_effects(hit_flashes, delta)


func get_hit_particles() -> Array[Dictionary]:
	return hit_particles


func get_hit_rings() -> Array[Dictionary]:
	return hit_rings


func get_hit_streaks() -> Array[Dictionary]:
	return hit_streaks


func get_hit_flashes() -> Array[Dictionary]:
	return hit_flashes


func has_hit_particles() -> bool:
	return has_hit_effects()


func has_hit_effects() -> bool:
	return (
		not hit_particles.is_empty()
		or not hit_rings.is_empty()
		or not hit_streaks.is_empty()
		or not hit_flashes.is_empty()
	)


func _spawn_sparks(pos: Vector2, color: Color, direction: Vector2, force: float) -> void:
	var tangent := Vector2(-direction.y, direction.x)
	var count: int = min(HIT_PARTICLE_SPAWN_MAX, HIT_PARTICLE_COUNT + int(round(force * HIT_PARTICLE_FORCE_BONUS)))
	for _i in range(count):
		var spread: float = randf_range(-1.0, 1.0)
		var push: Vector2 = (direction * randf_range(3.0, 6.4 + force * 3.0)) + (tangent * spread * randf_range(1.2, 4.6))
		push += Vector2(randf_range(-0.55, 0.55), randf_range(-0.55, 0.55))
		var max_life: float = randf_range(SPARK_LIFE_MIN, SPARK_LIFE_MAX + force * 0.025)
		hit_particles.append({
			"pos": pos + tangent * randf_range(-4.0, 4.0),
			"vel": push,
			"life": max_life,
			"max_life": max_life,
			"size": randf_range(1.8, 4.2 + force * 0.9),
			"color": color,
			"trail": randf_range(7.0, 16.0 + force * 8.0),
		})


func _spawn_rings(pos: Vector2, color: Color, direction: Vector2, force: float) -> void:
	hit_rings.append({
		"pos": pos,
		"life": RING_LIFE + force * 0.04,
		"max_life": RING_LIFE + force * 0.04,
		"start_radius": 8.0 + force * 3.0,
		"end_radius": 32.0 + force * 28.0,
		"color": color,
		"thickness": 2.4 + force * 1.6,
	})
	if force < 1.05:
		return
	hit_rings.append({
		"pos": pos - direction * (4.0 + force * 3.0),
		"life": RING_LIFE * 0.72,
		"max_life": RING_LIFE * 0.72,
		"start_radius": 4.0 + force * 2.0,
		"end_radius": 18.0 + force * 18.0,
		"color": CORE_FLASH_COLOR.lerp(color, 0.35),
		"thickness": 1.6 + force,
	})


func _spawn_streaks(pos: Vector2, color: Color, direction: Vector2, force: float) -> void:
	var tangent := Vector2(-direction.y, direction.x)
	var streak_count: int = min(HIT_STREAK_SPAWN_MAX, HIT_STREAK_BASE_COUNT + int(round(force * HIT_STREAK_FORCE_BONUS)))
	for _i in range(streak_count):
		var tangent_bias: float = randf_range(-1.0, 1.0)
		var streak_dir: Vector2 = (tangent * tangent_bias * randf_range(0.7, 1.45) + direction * randf_range(0.45, 1.0)).normalized()
		if streak_dir.length_squared() <= 0.001:
			streak_dir = direction
		hit_streaks.append({
			"pos": pos + tangent * randf_range(-12.0, 12.0) - direction * randf_range(0.0, 5.0),
			"vel": streak_dir * randf_range(2.4, 5.4 + force * 2.0),
			"dir": streak_dir,
			"life": STREAK_LIFE + randf_range(-0.025, 0.04),
			"max_life": STREAK_LIFE + 0.04,
			"length": randf_range(20.0, 36.0 + force * 30.0),
			"width": randf_range(1.5, 2.9 + force * 1.1),
			"color": color,
		})


func _spawn_flash(pos: Vector2, color: Color, force: float) -> void:
	hit_flashes.append({
		"pos": pos,
		"life": FLASH_LIFE,
		"max_life": FLASH_LIFE,
		"radius": 18.0 + force * 26.0,
		"color": CORE_FLASH_COLOR.lerp(color, 0.28),
	})


func _update_particles(delta: float, fps_scale: float) -> void:
	if hit_particles.is_empty():
		return
	var write_idx: int = 0
	for i in range(hit_particles.size()):
		var p: Dictionary = hit_particles[i]
		var particle_pos: Vector2 = p["pos"]
		var particle_vel: Vector2 = p["vel"]
		var particle_life: float = float(p["life"])
		particle_pos += particle_vel * fps_scale
		particle_vel *= pow(0.90, fps_scale)
		particle_life -= delta
		p["pos"] = particle_pos
		p["vel"] = particle_vel
		p["life"] = particle_life
		if particle_life > 0.0:
			hit_particles[write_idx] = p
			write_idx += 1
	hit_particles.resize(write_idx)


func _update_timed_effects(effects: Array[Dictionary], delta: float, fps_scale: float = 1.0) -> void:
	if effects.is_empty():
		return
	var write_idx: int = 0
	for i in range(effects.size()):
		var effect: Dictionary = effects[i]
		var life: float = float(effect.get("life", 0.0)) - delta
		effect["life"] = life
		if effect.has("vel"):
			var pos: Vector2 = effect.get("pos", Vector2.ZERO)
			var vel: Vector2 = effect.get("vel", Vector2.ZERO)
			effect["pos"] = pos + vel * fps_scale
			effect["vel"] = vel * pow(0.86, fps_scale)
		if life > 0.0:
			effects[write_idx] = effect
			write_idx += 1
	effects.resize(write_idx)


func _resolve_direction(direction: Vector2) -> Vector2:
	if direction.length_squared() <= 0.0001:
		var angle: float = randf_range(0.0, TAU)
		return Vector2(cos(angle), sin(angle))
	return direction.normalized()


func _resolve_force(intensity: float, impact_speed: float) -> float:
	return clamp(max(intensity, impact_speed / 34.0), 0.15, 1.65)


func _trim_effects() -> void:
	while hit_particles.size() > HIT_PARTICLE_MAX_COUNT:
		hit_particles.pop_front()
	while hit_rings.size() > HIT_RING_MAX_COUNT:
		hit_rings.pop_front()
	while hit_streaks.size() > HIT_STREAK_MAX_COUNT:
		hit_streaks.pop_front()
	while hit_flashes.size() > HIT_FLASH_MAX_COUNT:
		hit_flashes.pop_front()
