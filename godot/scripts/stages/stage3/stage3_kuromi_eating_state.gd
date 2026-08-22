extends RefCounted

const StageActorDrawContextArrays := preload("res://scripts/stages/common/stage_actor_draw_context_arrays.gd")
const Stage3BossSkillPayloadFactory := preload("res://scripts/stages/stage3/stage3_boss_skill_payload_factory.gd")

const WIDTH := 760.0
const HEIGHT := 750.0
const EAT_COOLDOWN_SEC := 20.0
const EAT_CHANCE := 0.06
const TONGUE_EXTEND_FRAMES := 20.0
const TONGUE_WRAP_FRAMES := 40.0
const SWALLOW_FRAMES := 50.0
const CHEW_FRAMES := 120.0
const DIRECTION_FRAMES := 180.0
const RELEASE_FRAMES := 190.0
const SPIT_SOUND_LEAD_FRAMES := 18.0
const SPIT_SPEED_MIN := 8.0
const SPIT_SPEED_MAX := 12.0
const SPIT_SPEED_MULT := 3.0
const SPIT_HORIZONTAL_EXCLUSION := PI * 0.083
const SPIT_ANGLE_LIMIT := PI * 0.7
const MAX_EATING_PARTICLES := 80
const MAX_SPIT_TRAIL_POINTS := 30

# Focused owner for Kuromi's ball-eating sequence. It borrows the Stage 3 RNG
# so entry, particles, spit angle, and spit speed keep their established order.
# Cross-skill ordering and the resulting prism burst remain with the host.

var kuromi_eating_active := false
var kuromi_eating_timer := 0.0
var kuromi_eating_cooldown := 0.0
var kuromi_ball_entered := false
var kuromi_spit_angle := 0.0
var kuromi_has_spit_angle := false
var kuromi_mouth_direction := 0.0
var kuromi_mouth_open := 0.0
var kuromi_chewing_phase := 0.0
var kuromi_tongue_extended := 0.0
var kuromi_tongue_angle := 0.0
var kuromi_tongue_wrap_phase := 0.0
var kuromi_ball_tongue_pos := Vector2.ZERO
var kuromi_ball_on_tongue := false
var kuromi_eat_source_pos := Vector2.ZERO
var kuromi_swallow_sound_played := false
var kuromi_spit_sound_played := false
var kuromi_eating_particles: Array = []
var kuromi_spit_trail: Array = []
var kuromi_spit_trail_phase := 0.0
var kuromi_spit_trail_frame := 0.0

var _rng: RandomNumberGenerator
var _prism_burst_pending := false
var _prism_burst_pos := Vector2.ZERO


func _init(shared_rng: RandomNumberGenerator) -> void:
	_rng = shared_rng


func reset() -> void:
	kuromi_eating_active = false
	kuromi_eating_timer = 0.0
	kuromi_eating_cooldown = 0.0
	kuromi_ball_entered = false
	kuromi_has_spit_angle = false
	kuromi_mouth_direction = 0.0
	kuromi_mouth_open = 0.0
	kuromi_chewing_phase = 0.0
	kuromi_tongue_extended = 0.0
	kuromi_tongue_angle = 0.0
	kuromi_tongue_wrap_phase = 0.0
	kuromi_ball_tongue_pos = Vector2.ZERO
	kuromi_ball_on_tongue = false
	kuromi_eat_source_pos = Vector2.ZERO
	kuromi_swallow_sound_played = false
	kuromi_spit_sound_played = false
	kuromi_eating_particles.clear()
	kuromi_spit_trail.clear()
	kuromi_spit_trail_phase = 0.0
	kuromi_spit_trail_frame = 0.0
	_prism_burst_pending = false
	_prism_burst_pos = Vector2.ZERO


func update_cooldown(delta: float) -> void:
	if kuromi_eating_cooldown > 0.0:
		kuromi_eating_cooldown = maxf(0.0, kuromi_eating_cooldown - delta)


func update(
	delta: float,
	context: Dictionary,
	deps: Dictionary,
	result: Dictionary,
	can_start: bool
) -> void:
	var ball_pos: Vector2 = _as_vector2(
		result.get("ball_pos", context.get("ball_pos", Vector2.ZERO)),
		Vector2.ZERO
	)
	_update_spit_trail(delta, ball_pos)
	_update_eating_particles(delta)
	if kuromi_eating_active:
		_update_eating(delta, deps, result)
		return
	result["stage3_kuromi_ball_hidden"] = false
	if not can_start or kuromi_eating_cooldown > 0.0:
		return
	var kuromi_rect := Rect2(
		Vector2(WIDTH * 0.5 - 60.0, HEIGHT * 0.5 - 60.0),
		Vector2(120.0, 120.0)
	)
	var ball_size: float = maxf(1.0, float(context.get("ball_size", 28.6)))
	var ball_rect := Rect2(
		ball_pos - Vector2(ball_size * 0.5, ball_size * 0.5),
		Vector2(ball_size, ball_size)
	)
	var ball_in_area: bool = kuromi_rect.intersects(ball_rect)
	if ball_in_area and not kuromi_ball_entered and _rng.randf() < EAT_CHANCE:
		if _should_defer_for_ball_owner(context, result, deps):
			kuromi_ball_entered = ball_in_area
			return
		_start_eating(ball_pos, deps)
		result["stage3_kuromi_ball_hidden"] = true
	kuromi_ball_entered = ball_in_area


func is_ball_hidden() -> bool:
	return kuromi_eating_active


func get_actor_draw_context(copy_arrays: bool = false) -> Dictionary:
	return {
		"stage3_kuromi_eating_active": kuromi_eating_active,
		"stage3_kuromi_ball_hidden": is_ball_hidden(),
		"stage3_kuromi_eating_timer": kuromi_eating_timer,
		"stage3_kuromi_eating_progress": clampf(kuromi_eating_timer / RELEASE_FRAMES, 0.0, 1.0),
		"stage3_kuromi_mouth_open": kuromi_mouth_open,
		"stage3_kuromi_mouth_direction": kuromi_mouth_direction,
		"stage3_kuromi_chewing_phase": kuromi_chewing_phase,
		"stage3_kuromi_tongue_extended": kuromi_tongue_extended,
		"stage3_kuromi_tongue_angle": kuromi_tongue_angle,
		"stage3_kuromi_tongue_wrap_phase": kuromi_tongue_wrap_phase,
		"stage3_kuromi_ball_tongue_pos": kuromi_ball_tongue_pos,
		"stage3_kuromi_ball_on_tongue": kuromi_ball_on_tongue,
		"stage3_kuromi_eating_particles": StageActorDrawContextArrays.snapshot(
			kuromi_eating_particles,
			copy_arrays,
			true
		),
		"stage3_kuromi_spit_trail": StageActorDrawContextArrays.snapshot(
			kuromi_spit_trail,
			copy_arrays,
			true
		),
		"stage3_kuromi_spit_trail_phase": kuromi_spit_trail_phase,
	}


func consume_prism_burst_request() -> Variant:
	if not _prism_burst_pending:
		return null
	_prism_burst_pending = false
	return _prism_burst_pos


func _should_defer_for_ball_owner(
	context: Dictionary,
	result: Dictionary,
	deps: Dictionary
) -> bool:
	if bool(result.get("skip_ball_motion_step", context.get("skip_ball_motion_step", false))):
		return true
	var viper_skill_runtime: Object = deps.get("viper_skill_runtime", null)
	if viper_skill_runtime == null or not viper_skill_runtime.has_method("get_snapshot"):
		return false
	var viper_snapshot: Dictionary = viper_skill_runtime.get_snapshot()
	var chaos_state: String = str(viper_snapshot.get("chaos_state", "idle"))
	return chaos_state != "" and chaos_state != "idle"


func _start_eating(ball_pos: Vector2, deps: Dictionary) -> void:
	var center := Vector2(WIDTH * 0.5, HEIGHT * 0.5)
	kuromi_eating_active = true
	kuromi_eating_timer = 0.0
	kuromi_eating_cooldown = EAT_COOLDOWN_SEC
	kuromi_has_spit_angle = false
	kuromi_spit_angle = 0.0
	kuromi_mouth_direction = 0.0
	kuromi_mouth_open = 0.0
	kuromi_chewing_phase = 0.0
	kuromi_tongue_extended = 0.0
	kuromi_tongue_wrap_phase = 0.0
	kuromi_ball_on_tongue = true
	kuromi_eat_source_pos = ball_pos
	kuromi_ball_tongue_pos = ball_pos
	kuromi_tongue_angle = atan2(ball_pos.y - center.y, ball_pos.x - center.x)
	kuromi_swallow_sound_played = false
	kuromi_spit_sound_played = false
	kuromi_eating_particles.clear()
	_play_audio(deps, "play_stage3_kuromi_tongue")


func _update_eating(delta: float, deps: Dictionary, result: Dictionary) -> void:
	var fps_scale: float = delta * 60.0
	kuromi_eating_timer += fps_scale
	result["stage3_kuromi_ball_hidden"] = true
	if not kuromi_spit_sound_played and kuromi_eating_timer >= RELEASE_FRAMES - SPIT_SOUND_LEAD_FRAMES:
		kuromi_spit_sound_played = true
		_play_audio(deps, "play_stage3_kuromi_spit")
	if kuromi_eating_timer < TONGUE_EXTEND_FRAMES:
		kuromi_tongue_extended = _ease_out_elastic(kuromi_eating_timer / TONGUE_EXTEND_FRAMES)
		kuromi_tongue_wrap_phase = 0.0
		kuromi_mouth_open = (kuromi_eating_timer / TONGUE_EXTEND_FRAMES) * 0.6
		kuromi_ball_on_tongue = true
		kuromi_ball_tongue_pos = kuromi_eat_source_pos
	elif kuromi_eating_timer < TONGUE_WRAP_FRAMES:
		var grab_progress: float = (
			(kuromi_eating_timer - TONGUE_EXTEND_FRAMES)
			/ (TONGUE_WRAP_FRAMES - TONGUE_EXTEND_FRAMES)
		)
		kuromi_tongue_extended = 1.0 - grab_progress * 0.9
		kuromi_tongue_wrap_phase = grab_progress
		kuromi_mouth_open = 0.6 + grab_progress * 0.4
		kuromi_ball_on_tongue = true
		kuromi_ball_tongue_pos = kuromi_eat_source_pos.lerp(
			Vector2(WIDTH * 0.5, HEIGHT * 0.5 + 20.0),
			grab_progress
		)
	elif kuromi_eating_timer < SWALLOW_FRAMES:
		var swallow_progress: float = (
			(kuromi_eating_timer - TONGUE_WRAP_FRAMES)
			/ (SWALLOW_FRAMES - TONGUE_WRAP_FRAMES)
		)
		if not kuromi_swallow_sound_played:
			kuromi_swallow_sound_played = true
			_play_audio(deps, "play_stage3_kuromi_swallow")
		kuromi_tongue_extended = maxf(0.0, 0.1 - swallow_progress * 0.1)
		kuromi_tongue_wrap_phase = 1.0
		if swallow_progress < 0.5:
			kuromi_mouth_open = 1.0
		else:
			kuromi_mouth_open = 1.0 - (swallow_progress - 0.5) * 1.6
		kuromi_ball_on_tongue = false
		if _rng.randf() < minf(1.0, 0.6 * fps_scale):
			for _idx in range(3):
				_spawn_mouth_particle(Vector2(WIDTH * 0.5, HEIGHT * 0.5 + 25.0), false)
	elif kuromi_eating_timer < CHEW_FRAMES:
		var chew_progress: float = (
			(kuromi_eating_timer - SWALLOW_FRAMES)
			/ (CHEW_FRAMES - SWALLOW_FRAMES)
		)
		kuromi_tongue_extended = 0.0
		kuromi_ball_on_tongue = false
		kuromi_chewing_phase = chew_progress
		var chew_cycle: float = sin(chew_progress * PI * 8.0)
		kuromi_mouth_open = 0.15 + absf(chew_cycle) * 0.35
		if _rng.randf() < minf(1.0, 0.3 * fps_scale):
			_spawn_mouth_particle(Vector2(WIDTH * 0.5, HEIGHT * 0.5 + 20.0), false)
	elif kuromi_eating_timer < DIRECTION_FRAMES:
		if not kuromi_has_spit_angle:
			kuromi_spit_angle = _roll_spit_angle()
			kuromi_has_spit_angle = true
		kuromi_mouth_direction = kuromi_spit_angle
		var buildup: float = (
			(kuromi_eating_timer - CHEW_FRAMES)
			/ (DIRECTION_FRAMES - CHEW_FRAMES)
		)
		kuromi_mouth_open = 0.2 + buildup * 0.4
		kuromi_chewing_phase = 0.0
		if _rng.randf() < minf(1.0, 0.8 * fps_scale):
			_spawn_mouth_particle(Vector2(WIDTH * 0.5, HEIGHT * 0.5), true)
	elif kuromi_eating_timer < RELEASE_FRAMES:
		if not kuromi_has_spit_angle:
			kuromi_spit_angle = _roll_spit_angle()
			kuromi_has_spit_angle = true
		kuromi_mouth_direction = kuromi_spit_angle
		var pressure_progress: float = (
			(kuromi_eating_timer - DIRECTION_FRAMES)
			/ (RELEASE_FRAMES - DIRECTION_FRAMES)
		)
		kuromi_mouth_open = 0.6 + 0.4 * pressure_progress
		kuromi_chewing_phase = 0.0
		if _rng.randf() < minf(1.0, 0.9 * fps_scale):
			_spawn_mouth_particle(Vector2(WIDTH * 0.5, HEIGHT * 0.5), true)
	else:
		_finish_eating(result, deps)


func _finish_eating(result: Dictionary, deps: Dictionary) -> void:
	var center := Vector2(WIDTH * 0.5, HEIGHT * 0.5)
	kuromi_eating_active = false
	kuromi_eating_timer = 0.0
	kuromi_mouth_open = 0.0
	kuromi_chewing_phase = 0.0
	kuromi_tongue_extended = 0.0
	kuromi_tongue_wrap_phase = 0.0
	kuromi_ball_on_tongue = false
	result["stage3_kuromi_ball_hidden"] = false
	result["ball_pos"] = center
	result["ball_vel"] = _get_spit_velocity()
	result["skip_ball_motion_step"] = false
	result["ball_impact_boost"] = 1.0
	_release_external_ball_owner(result, deps)
	kuromi_spit_trail.clear()
	kuromi_spit_trail_phase = 0.0
	kuromi_spit_trail_frame = 0.0
	kuromi_spit_trail.append(
		Stage3BossSkillPayloadFactory.build_kuromi_spit_trail_point(center, 18.0)
	)
	for _idx in range(25):
		_spawn_mouth_particle(center, true)
	_prism_burst_pending = true
	_prism_burst_pos = center


func _release_external_ball_owner(result: Dictionary, deps: Dictionary) -> void:
	var viper_skill_runtime: Object = deps.get("viper_skill_runtime", null)
	if viper_skill_runtime == null or not viper_skill_runtime.has_method("release_chaos_blackhole_from_hit"):
		return
	var release_context := {
		"ball_pos": _as_vector2(
			result.get("ball_pos", Vector2(WIDTH * 0.5, HEIGHT * 0.5)),
			Vector2(WIDTH * 0.5, HEIGHT * 0.5)
		),
		"ball_vel": _as_vector2(result.get("ball_vel", Vector2.ZERO), Vector2.ZERO),
	}
	if bool(viper_skill_runtime.release_chaos_blackhole_from_hit(deps, release_context)):
		result["skip_ball_motion_step"] = false


func _ease_out_elastic(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0
	var period := 0.3
	var shift := period / 4.0
	return pow(2.0, -10.0 * t) * sin((t - shift) * TAU / period) + 1.0


func _roll_spit_angle() -> float:
	if _rng.randf() < 0.5:
		return _rng.randf_range(-SPIT_ANGLE_LIMIT, -SPIT_HORIZONTAL_EXCLUSION)
	return _rng.randf_range(SPIT_HORIZONTAL_EXCLUSION, SPIT_ANGLE_LIMIT)


func _get_spit_velocity() -> Vector2:
	if not kuromi_has_spit_angle:
		kuromi_spit_angle = _roll_spit_angle()
		kuromi_has_spit_angle = true
	var speed: float = _rng.randf_range(SPIT_SPEED_MIN, SPIT_SPEED_MAX) * SPIT_SPEED_MULT
	return Vector2(cos(kuromi_spit_angle), sin(kuromi_spit_angle)) * speed


func _update_spit_trail(delta: float, ball_pos: Vector2) -> void:
	if kuromi_spit_trail.is_empty():
		return
	var fps_scale: float = delta * 60.0
	kuromi_spit_trail_frame += fps_scale
	kuromi_spit_trail_phase = fposmod(kuromi_spit_trail_phase + 0.1 * fps_scale, 1.0)
	if int(floor(kuromi_spit_trail_frame)) % 3 == 0:
		kuromi_spit_trail.append(
			Stage3BossSkillPayloadFactory.build_kuromi_spit_trail_point(ball_pos, 15.0)
		)
	var write_idx := 0
	for idx in range(kuromi_spit_trail.size()):
		var particle: Dictionary = kuromi_spit_trail[idx]
		particle["life"] = float(particle["life"]) - 0.02 * fps_scale
		particle["size"] = float(particle["size"]) * pow(0.98, fps_scale)
		if float(particle["life"]) <= 0.0:
			continue
		kuromi_spit_trail[write_idx] = particle
		write_idx += 1
	if write_idx < kuromi_spit_trail.size():
		kuromi_spit_trail.resize(write_idx)
	if kuromi_spit_trail.size() > MAX_SPIT_TRAIL_POINTS:
		_trim_array_from_front(kuromi_spit_trail, MAX_SPIT_TRAIL_POINTS)


func _spawn_mouth_particle(center: Vector2, directional: bool) -> void:
	kuromi_eating_particles.append(Stage3BossSkillPayloadFactory.build_kuromi_mouth_particle(
		center,
		kuromi_mouth_direction,
		directional,
		_rng
	))
	if kuromi_eating_particles.size() > MAX_EATING_PARTICLES:
		_trim_array_from_front(kuromi_eating_particles, MAX_EATING_PARTICLES)


func _update_eating_particles(delta: float) -> void:
	var write_idx := 0
	for idx in range(kuromi_eating_particles.size()):
		var particle: Dictionary = kuromi_eating_particles[idx]
		particle["x"] = float(particle.get("x", 0.0)) + float(particle.get("vx", 0.0)) * delta * 60.0
		particle["y"] = float(particle.get("y", 0.0)) + float(particle.get("vy", 0.0)) * delta * 60.0
		particle["vy"] = float(particle.get("vy", 0.0)) + 0.03 * delta * 60.0
		particle["life"] = float(particle.get("life", 0.0)) - delta
		if float(particle.get("life", 0.0)) <= 0.0:
			continue
		kuromi_eating_particles[write_idx] = particle
		write_idx += 1
	if write_idx < kuromi_eating_particles.size():
		kuromi_eating_particles.resize(write_idx)


func _trim_array_from_front(source: Array, max_size: int) -> void:
	var overflow: int = source.size() - max_size
	if overflow <= 0:
		return
	var write_idx := 0
	for read_idx in range(overflow, source.size()):
		source[write_idx] = source[read_idx]
		write_idx += 1
	source.resize(write_idx)


func _play_audio(deps: Dictionary, method: String) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method(method):
		audio.call(method)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	return fallback
