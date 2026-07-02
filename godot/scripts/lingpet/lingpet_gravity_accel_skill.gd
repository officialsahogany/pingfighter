extends RefCounted

# Serabi (세라비 / orbi) active skill 중력가속 / Gravity Accel.
# Ported from the original PingFighter chronos (키르케) GravityControl hero skill
# (downtown/hero_skills.py `GravityControl`). The original warps gravity on the
# ball for a fixed duration: each frame `ball.vy += force * dir`, applying 70%
# when the ball already travels WITH the gravity direction and 100% against it
# (so an opposing ball decelerates and reverses).
#
# As a player-side lingpet skill the warp pulls the ball UP toward the BOSS goal
# (dir = up): a rising return is accelerated toward the boss (less reaction time)
# and a descending ball is decelerated / dragged back up (easier for the player
# to return). Level scaling (per the design owner): higher level = stronger
# gravity AND longer duration. Strength / duration come from the launch context
# (catalog `gravity_strength_by_level` / `duration_seconds_by_level`), falling
# back to the internal per-level tables below.

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0

# Gravity direction: -1 = up (toward the boss goal). This is the player-side
# inversion of the original (which pulled the ball toward the caster's opponent).
const GRAVITY_DIR := -1.0
const WITH_GRAVITY_FACTOR := 0.7    # ball already heading toward the boss -> 70%
const AGAINST_GRAVITY_FACTOR := 1.0 # descending ball -> full pull (decelerate)

# Safety caps so the warp stays a strong-but-fair drag instead of gluing the
# ball to the boss wall. ball_vel is px/frame@60 (ball_update_controller uses
# fps_scale = delta * 60), so these are per-frame speeds.
# MAX_VERTICAL_SPEED is the PRIMARY felt-strength lever: the per-frame gravity
# saturates the ball to this cap within ~0.5-0.9s and it holds there for the rest
# of the field, so this cap -- not gravity_strength -- governs how hard the pull
# feels. ~7.65 is the base ball speed, so 10 ≈ 1.31x base (a gentle upward drag).
const MAX_VERTICAL_SPEED := 10.0
const MAX_TOTAL_SPEED_MULT := 1.7
const MIN_TOTAL_SPEED_CAP := 12.0

const DEFAULT_DURATION_BY_LEVEL: Array[float] = [2.0, 2.5, 3.0, 3.5, 4.0]
const DEFAULT_STRENGTH_BY_LEVEL: Array[float] = [28.8, 36.0, 43.2, 50.4, 57.6]

const PARTICLE_MAX := 48
const AMBIENT_INTERVAL := 0.05
const AMBIENT_BURST := 2
const DISTORTION_LINES := 6
const FIELD_COLOR := Color(0.30, 0.18, 0.52, 1.0)

var _active_seconds := 0.0
var _duration := 0.0
var _strength := 0.0
var _active_skill_level := 1
var _activation_speed := 0.0
var _elapsed := 0.0
var _ambient_timer := 0.0
var _seed := 0
var _particles: Array[Dictionary] = []
var _last_applied_upward := false


func reset() -> void:
	_active_seconds = 0.0
	_duration = 0.0
	_strength = 0.0
	_active_skill_level = 1
	_activation_speed = 0.0
	_elapsed = 0.0
	_ambient_timer = 0.0
	_seed = 0
	_particles.clear()
	_last_applied_upward = false


func prewarm() -> void:
	pass


func can_arm(params: Dictionary) -> bool:
	# Only worth casting while a live ball is in play; the warp does nothing on
	# an empty field and would waste the cooldown.
	if not bool(params.get("ball_active", false)):
		return false
	if not bool(params.get("companion_visible", false)):
		return false
	return true


func launch(origin: Vector2, owner: Object = null, launch_context: Dictionary = {}) -> bool:
	reset()
	_active_skill_level = clampi(int(launch_context.get("active_skill_level", launch_context.get("skill_level", 1))), 1, 5)
	_duration = _resolve_level_float(launch_context, "duration_seconds", DEFAULT_DURATION_BY_LEVEL)
	_strength = _resolve_level_float(launch_context, "gravity_strength", DEFAULT_STRENGTH_BY_LEVEL)
	_active_seconds = _duration
	_elapsed = 0.0
	_ambient_timer = 0.0
	_seed = int(absf(round(origin.x * 13.0 + origin.y * 31.0 + float(_active_skill_level) * 7.0))) % 4096
	if owner != null:
		var ball_vel: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_vel", Vector2.ZERO)
		_activation_speed = ball_vel.length()
	return _active_seconds > 0.0


func update(delta: float, owner: Object, _registry: Object = null, _launch_context: Dictionary = {}) -> void:
	var safe_delta := maxf(0.0, delta)
	_update_particles(safe_delta)
	if _active_seconds <= 0.0:
		return
	_elapsed += safe_delta
	_active_seconds = maxf(0.0, _active_seconds - safe_delta)
	_apply_gravity_to_ball(owner, safe_delta)
	_spawn_ambient_particles(safe_delta)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	if _active_seconds > 0.0:
		_draw_field(canvas, shake_offset)
	if not _particles.is_empty():
		_draw_particles(canvas, shake_offset)


func has_visible_effects() -> bool:
	return _active_seconds > 0.0 or not _particles.is_empty()


func is_active() -> bool:
	return _active_seconds > 0.0 or has_visible_effects()


func is_projectile_active() -> bool:
	return is_active()


func is_field_active() -> bool:
	return _active_seconds > 0.0


func get_snapshot() -> Dictionary:
	return {
		"gravity_accel_active": is_active(),
		"gravity_accel_field_active": _active_seconds > 0.0,
		"gravity_accel_timer": _active_seconds,
		"gravity_accel_duration": _duration,
		"gravity_accel_strength": _strength,
		"gravity_accel_level": _active_skill_level,
		"gravity_accel_last_applied_upward": _last_applied_upward,
		"gravity_accel_particle_count": _particles.size(),
	}


func get_particle_count_for_tests() -> int:
	return _particles.size()


func _apply_gravity_to_ball(owner: Object, delta: float) -> void:
	_last_applied_upward = false
	if owner == null or delta <= 0.0:
		return
	if not bool(BattleSceneOwnerReader.get_value(owner, "ball_active", false)):
		return
	# Another owned-ball skill (ghost shot, chaos spear, inferno, ...) is driving
	# the ball directly this frame; do not fight its scripted motion.
	if bool(BattleSceneOwnerReader.get_value(owner, "skip_ball_motion_step", false)):
		return
	var ball_vel: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_vel", Vector2.ZERO)
	var force := _strength * delta
	if ball_vel.y < 0.0:
		ball_vel.y += GRAVITY_DIR * force * WITH_GRAVITY_FACTOR
	else:
		ball_vel.y += GRAVITY_DIR * force * AGAINST_GRAVITY_FACTOR
	if ball_vel.y < -MAX_VERTICAL_SPEED:
		ball_vel.y = -MAX_VERTICAL_SPEED
	var max_total := maxf(_activation_speed * MAX_TOTAL_SPEED_MULT, MIN_TOTAL_SPEED_CAP)
	var speed := ball_vel.length()
	if speed > max_total and speed > 0.001:
		ball_vel = ball_vel * (max_total / speed)
	owner.set("ball_vel", ball_vel)
	_last_applied_upward = ball_vel.y < 0.0


func _resolve_level_float(launch_context: Dictionary, key: String, fallback_by_level: Array[float]) -> float:
	var supplied := float(launch_context.get(key, -1.0))
	if supplied > 0.0:
		return supplied
	var index := clampi(_active_skill_level - 1, 0, fallback_by_level.size() - 1)
	return fallback_by_level[index]


func _spawn_ambient_particles(delta: float) -> void:
	if delta <= 0.0:
		return
	_ambient_timer -= delta
	if _ambient_timer > 0.0:
		return
	_ambient_timer = AMBIENT_INTERVAL
	for _i in range(AMBIENT_BURST):
		if _particles.size() >= PARTICLE_MAX:
			return
		var x := randf_range(20.0, FIELD_WIDTH - 20.0)
		var y := randf_range(FIELD_HEIGHT * 0.35, FIELD_HEIGHT - 20.0)
		# Particles stream UP toward the boss, visualizing the gravity direction.
		_particles.append({
			"pos": Vector2(x, y),
			"vel": Vector2(randf_range(-12.0, 12.0), -randf_range(180.0, 360.0)),
			"life": randf_range(0.4, 0.85),
			"max_life": 0.85,
			"size": randf_range(2.0, 5.0),
		})


func _update_particles(delta: float) -> void:
	if _particles.is_empty() or delta <= 0.0:
		return
	var write_index := 0
	for particle in _particles:
		var life := float(particle.get("life", 0.0)) - delta
		if life <= 0.0:
			continue
		var pos: Vector2 = particle.get("pos", Vector2.ZERO)
		var vel: Vector2 = particle.get("vel", Vector2.ZERO)
		pos += vel * delta
		vel.y -= 36.0 * delta  # accelerate upward (the warp pulls them to the boss)
		particle["life"] = life
		particle["pos"] = pos
		particle["vel"] = vel
		_particles[write_index] = particle
		write_index += 1
	if write_index < _particles.size():
		_particles.resize(write_index)


func _draw_field(canvas: CanvasItem, shake_offset: Vector2) -> void:
	var life_ratio := clampf(_active_seconds / maxf(0.01, _duration), 0.0, 1.0)
	var appear := clampf((_duration - _active_seconds) / 0.25, 0.0, 1.0)
	var fade := clampf(life_ratio / 0.25, 0.0, 1.0)
	var alpha := clampf(appear * fade, 0.0, 1.0)
	if alpha <= 0.01:
		return
	var time_seconds := float(Time.get_ticks_msec()) / 1000.0
	# Soft full-field purple overlay (gravity-warp mood).
	canvas.draw_rect(
		Rect2(shake_offset, Vector2(FIELD_WIDTH, FIELD_HEIGHT)),
		Color(FIELD_COLOR.r, FIELD_COLOR.g, FIELD_COLOR.b, 0.12 * alpha),
		true
	)
	# Horizontal distortion lines drifting UP, warping with a travelling sine.
	for i in range(DISTORTION_LINES):
		var phase := fmod(time_seconds * 0.45 + float(i) * 0.37 + float(_seed) * 0.013, 1.0)
		var base_y := FIELD_HEIGHT * (1.0 - phase)
		var amp := 6.0 + 8.0 * float((i + _seed) % 3)
		var freq := 0.018 + 0.006 * float(i % 3)
		var line_phase := time_seconds * 2.2 + float(i)
		var points := PackedVector2Array()
		var x := 20.0
		while x <= FIELD_WIDTH - 20.0:
			var wy := base_y + sin(x * freq + line_phase) * amp
			points.append(Vector2(x, wy) + shake_offset)
			x += 24.0
		if points.size() >= 2:
			canvas.draw_polyline(points, Color(0.72, 0.56, 1.0, 0.22 * alpha), 2.0, true)


func _draw_particles(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for particle in _particles:
		var max_life := maxf(0.01, float(particle.get("max_life", 0.85)))
		var life_t := clampf(float(particle.get("life", 0.0)) / max_life, 0.0, 1.0)
		var alpha := clampf(life_t * 1.3, 0.0, 1.0)
		if alpha <= 0.02:
			continue
		var pos: Vector2 = (particle.get("pos", Vector2.ZERO) as Vector2) + shake_offset
		var size := maxf(1.0, float(particle.get("size", 2.0)) * (0.7 + 0.3 * life_t))
		var vel: Vector2 = particle.get("vel", Vector2.ZERO)
		var tail := pos - vel * (1.5 / 60.0)
		canvas.draw_line(tail, pos, Color(0.78, 0.62, 1.0, 0.45 * alpha), maxf(1.0, size * 0.5), true)
		canvas.draw_circle(pos, size, Color(0.90, 0.80, 1.0, 0.65 * alpha))
