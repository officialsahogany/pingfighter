extends RefCounted

const StageActorDrawContextArrays := preload("res://scripts/stages/common/stage_actor_draw_context_arrays.gd")
const Stage4PonkSkillPayloadFactory := preload("res://scripts/stages/stage4/stage4_ponk_skill_payload_factory.gd")

const COOLDOWN_SEC := 18.0
const DURATION_FRAMES := 108.0
const ORBIT_RADIUS := 80.0
const TRAIL_MAX := 28
const PARTICLE_MAX := 48
const RELEASE_FX_FRAMES := 26.0
const RELEASE_MAX_BALL_SPEED := 35.0
const RELEASE_SPEED_BONUS_MIN := 1.10
const RELEASE_SPEED_BONUS_MAX := 1.30
const DEFAULT_BALL_POS := Vector2(380.0, 150.0)

# Mutable owner for Ponk meditation orbit, transient payloads, release roll,
# ball handoff, and release-FX state. The borrowed Stage 4 RNG is never consumed
# during construction. Audio and reset-time FX orchestration remain in the
# runtime coordinator; node-backed hosts stay externally owned.

var meditation_active := false
var meditation_timer_frames := 0.0
var meditation_angle_degrees := 0.0
var meditation_ball_pos := DEFAULT_BALL_POS
var meditation_trails: Array = []
var meditation_particles: Array = []
var meditation_circles: Array = []
var meditation_release_pending := false
var meditation_release_velocity := Vector2.ZERO
var meditation_cooldown_seconds := COOLDOWN_SEC
var meditation_release_fx_timer_frames := 0.0
var meditation_release_fx_origin := Vector2.ZERO
var meditation_release_fx_pos := Vector2.ZERO
var meditation_release_fx_velocity := Vector2.ZERO
var meditation_release_fx_trails: Array = []
var meditation_release_fx_id := 0

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


func reset() -> void:
	meditation_active = false
	meditation_timer_frames = 0.0
	meditation_angle_degrees = 0.0
	meditation_ball_pos = DEFAULT_BALL_POS
	meditation_trails.clear()
	meditation_particles.clear()
	meditation_circles.clear()
	meditation_release_pending = false
	meditation_release_velocity = Vector2.ZERO
	meditation_cooldown_seconds = COOLDOWN_SEC
	reset_release_fx(true)


func reset_round() -> void:
	meditation_active = false
	meditation_timer_frames = 0.0
	meditation_trails.clear()
	meditation_particles.clear()
	meditation_circles.clear()
	meditation_release_pending = false
	meditation_release_velocity = Vector2.ZERO
	reset_release_fx(true)


func clear_stage_transients() -> void:
	meditation_active = false
	meditation_trails.clear()
	meditation_particles.clear()
	meditation_circles.clear()
	reset_release_fx()


func update_cooldown(delta: float) -> void:
	meditation_cooldown_seconds = maxf(
		0.0,
		meditation_cooldown_seconds - maxf(0.0, delta)
	)


func activate(boss_center: Vector2, circle_center: Vector2) -> bool:
	meditation_active = true
	meditation_timer_frames = DURATION_FRAMES
	meditation_angle_degrees = 0.0
	meditation_ball_pos = _get_orbit_ball_pos(boss_center)
	meditation_trails.clear()
	meditation_particles.clear()
	meditation_circles.clear()
	meditation_release_pending = false
	meditation_release_velocity = Vector2.ZERO
	meditation_cooldown_seconds = COOLDOWN_SEC
	reset_release_fx()
	_spawn_circles(circle_center)
	return true


func get_controlled_ball_pos(boss_center: Vector2) -> Vector2:
	meditation_ball_pos = _get_orbit_ball_pos(boss_center)
	return meditation_ball_pos


func update(fps_scale: float, boss_center: Vector2) -> bool:
	if not meditation_active:
		_update_transients(fps_scale)
		_update_release_fx(fps_scale)
		return false
	var step: float = maxf(0.0, fps_scale)
	meditation_timer_frames = maxf(0.0, meditation_timer_frames - step)
	meditation_angle_degrees += (720.0 / DURATION_FRAMES) * step
	meditation_ball_pos = _get_orbit_ball_pos(boss_center)
	_append_trail(meditation_ball_pos)
	_update_transients(step)
	_spawn_particle(meditation_ball_pos)
	return meditation_timer_frames <= 0.0


func consume_release() -> Dictionary:
	if not meditation_release_pending:
		return {}
	meditation_release_pending = false
	return {"velocity": meditation_release_velocity}


func finish(base_ball_speed: float) -> void:
	var release_velocity: Vector2 = _build_release_velocity(base_ball_speed)
	meditation_release_fx_timer_frames = RELEASE_FX_FRAMES
	meditation_release_fx_origin = meditation_ball_pos
	meditation_release_fx_pos = meditation_ball_pos
	meditation_release_fx_velocity = release_velocity
	meditation_release_fx_trails = meditation_trails.duplicate(true)
	meditation_release_fx_id += 1
	meditation_active = false
	meditation_timer_frames = 0.0
	meditation_trails.clear()
	meditation_particles.clear()
	meditation_circles.clear()
	meditation_release_pending = true
	meditation_release_velocity = release_velocity


func reset_release_fx(reset_id: bool = false) -> void:
	meditation_release_fx_timer_frames = 0.0
	meditation_release_fx_origin = Vector2.ZERO
	meditation_release_fx_pos = Vector2.ZERO
	meditation_release_fx_velocity = Vector2.ZERO
	meditation_release_fx_trails.clear()
	if reset_id:
		meditation_release_fx_id = 0


func get_actor_draw_context(copy_arrays: bool = false) -> Dictionary:
	return {
		"stage4_meditation_active": meditation_active,
		"stage4_meditation_timer": meditation_timer_frames,
		"stage4_meditation_cooldown_remaining": meditation_cooldown_seconds,
		"stage4_meditation_cooldown_total": COOLDOWN_SEC,
		"stage4_meditation_angle": meditation_angle_degrees,
		"stage4_meditation_ball_pos": meditation_ball_pos,
		"stage4_meditation_trails": StageActorDrawContextArrays.snapshot(meditation_trails, copy_arrays),
		"stage4_meditation_particles": StageActorDrawContextArrays.snapshot(meditation_particles, copy_arrays),
		"stage4_meditation_circles": StageActorDrawContextArrays.snapshot(meditation_circles, copy_arrays),
		"stage4_meditation_release_fx_active": meditation_release_fx_timer_frames > 0.0,
		"stage4_meditation_release_fx_timer": meditation_release_fx_timer_frames,
		"stage4_meditation_release_fx_total": RELEASE_FX_FRAMES,
		"stage4_meditation_release_fx_origin": meditation_release_fx_origin,
		"stage4_meditation_release_fx_pos": meditation_release_fx_pos,
		"stage4_meditation_release_fx_velocity": meditation_release_fx_velocity,
		"stage4_meditation_release_fx_id": meditation_release_fx_id,
		"stage4_meditation_release_fx_trails": StageActorDrawContextArrays.snapshot(meditation_release_fx_trails, copy_arrays),
	}


func get_snapshot() -> Dictionary:
	return {
		"meditation_active": meditation_active,
		"meditation_timer_frames": meditation_timer_frames,
		"meditation_angle_degrees": meditation_angle_degrees,
		"meditation_ball_pos": meditation_ball_pos,
		"meditation_trails": meditation_trails.duplicate(true),
		"meditation_particles": meditation_particles.duplicate(true),
		"meditation_circles": meditation_circles.duplicate(true),
		"meditation_release_pending": meditation_release_pending,
		"meditation_release_velocity": meditation_release_velocity,
		"meditation_cooldown_seconds": meditation_cooldown_seconds,
		"meditation_release_fx_timer_frames": meditation_release_fx_timer_frames,
		"meditation_release_fx_origin": meditation_release_fx_origin,
		"meditation_release_fx_pos": meditation_release_fx_pos,
		"meditation_release_fx_velocity": meditation_release_fx_velocity,
		"meditation_release_fx_trails": meditation_release_fx_trails.duplicate(true),
		"meditation_release_fx_id": meditation_release_fx_id,
	}


func _get_orbit_ball_pos(boss_center: Vector2) -> Vector2:
	var angle: float = deg_to_rad(meditation_angle_degrees)
	var scale := ORBIT_RADIUS * 1.5
	var denominator: float = 1.0 + pow(sin(angle), 2.0)
	return boss_center + Vector2(
		scale * cos(angle) / denominator,
		scale * sin(angle) * cos(angle) / denominator
	)


func _build_release_velocity(base_ball_speed: float) -> Vector2:
	var release_bonus: float = _rng.randf_range(RELEASE_SPEED_BONUS_MIN, RELEASE_SPEED_BONUS_MAX)
	var speed: float = base_ball_speed * _rng.randf_range(1.3, 1.6) * release_bonus
	var angle: float = deg_to_rad(_rng.randf_range(-45.0, 45.0))
	return Vector2(sin(angle), 1.0).normalized() * speed


func _append_trail(position: Vector2) -> void:
	meditation_trails.append(Stage4PonkSkillPayloadFactory.build_meditation_trail(position))
	while meditation_trails.size() > TRAIL_MAX:
		meditation_trails.pop_front()


func _update_transients(fps_scale: float) -> void:
	var next_trails: Array = []
	for trail_value in meditation_trails:
		if not (trail_value is Dictionary):
			continue
		var trail: Dictionary = trail_value
		trail["life"] = float(trail.get("life", 0.0)) - fps_scale
		if float(trail.get("life", 0.0)) > 0.0:
			next_trails.append(trail)
	meditation_trails = next_trails

	var next_particles: Array = []
	for particle_value in meditation_particles:
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		particle["life"] = float(particle.get("life", 0.0)) - fps_scale
		particle["pos"] = _as_vector2(particle.get("pos", Vector2.ZERO)) + _as_vector2(particle.get("vel", Vector2.ZERO)) * fps_scale
		if float(particle.get("life", 0.0)) > 0.0:
			next_particles.append(particle)
	meditation_particles = next_particles

	var next_circles: Array = []
	for circle_value in meditation_circles:
		if not (circle_value is Dictionary):
			continue
		var circle: Dictionary = circle_value
		circle["life"] = float(circle.get("life", 0.0)) - fps_scale
		circle["radius"] = float(circle.get("radius", 0.0)) + float(circle.get("grow", 1.2)) * fps_scale
		if float(circle.get("life", 0.0)) > 0.0:
			next_circles.append(circle)
		meditation_circles = next_circles


func _update_release_fx(fps_scale: float) -> void:
	if meditation_release_fx_timer_frames <= 0.0:
		return
	var step: float = maxf(0.0, fps_scale)
	meditation_release_fx_timer_frames = maxf(0.0, meditation_release_fx_timer_frames - step)
	meditation_release_fx_pos += meditation_release_fx_velocity * step
	var next_trails: Array = []
	for trail_value in meditation_release_fx_trails:
		if not (trail_value is Dictionary):
			continue
		var trail: Dictionary = trail_value
		trail["life"] = float(trail.get("life", 0.0)) - step
		if float(trail.get("life", 0.0)) > 0.0:
			next_trails.append(trail)
	meditation_release_fx_trails = next_trails
	if meditation_release_fx_timer_frames <= 0.0:
		meditation_release_fx_trails.clear()
		meditation_release_fx_velocity = Vector2.ZERO


func _spawn_particle(position: Vector2) -> void:
	if meditation_particles.size() >= PARTICLE_MAX or _rng.randf() > 0.42:
		return
	meditation_particles.append(Stage4PonkSkillPayloadFactory.build_meditation_particle(position, _rng))


func _spawn_circles(center: Vector2) -> void:
	for index in range(3):
		meditation_circles.append(Stage4PonkSkillPayloadFactory.build_meditation_circle(center, index))


func _as_vector2(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2.ZERO
