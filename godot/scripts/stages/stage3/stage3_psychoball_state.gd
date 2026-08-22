extends RefCounted

const StageActorDrawContextArrays := preload("res://scripts/stages/common/stage_actor_draw_context_arrays.gd")
const Stage3BossSkillPayloadFactory := preload("res://scripts/stages/stage3/stage3_boss_skill_payload_factory.gd")

const STAGE_ID := 3
const WIDTH := 760.0
const HEIGHT := 750.0
const COOLDOWN_SEC := 70.0
const DURATION_SEC := 5.0
const ENRAGED_DURATION_SEC := 7.5
const SMOKE_OPACITY_THRESHOLD := 50.0 / 255.0
const SMOKE_NEUTRALIZE_SPEED := 10.0
const NEUTRALIZE_PARTICLE_COUNT := 20
const TRAIL_INITIAL_ALPHA := 200.0 / 255.0
const TRAIL_FADE_PER_FRAME := 10.0 / 255.0
const TRAIL_MIN_ALPHA := 10.0 / 255.0
const HITSTOP_SEC := 0.12
const MAX_OVERDRIVE_TRAILS := 15
const MAX_NEUTRALIZE_PARTICLES := 60

var psycho_cooldown := COOLDOWN_SEC
var overdrive_active := false
var overdrive_timer := 0.0
var overdrive_flash_timer := 0.0
var psycho_bg_timer := 0.0
var overdrive_trails: Array = []
var psycho_neutralize_particles: Array = []
var psychoball_hitstop_timer := 0.0

var _rng: RandomNumberGenerator


func _init(shared_rng: RandomNumberGenerator) -> void:
	_rng = shared_rng


func reset() -> void:
	psycho_cooldown = COOLDOWN_SEC
	reset_effects()


func reset_effects() -> void:
	overdrive_active = false
	overdrive_timer = 0.0
	overdrive_flash_timer = 0.0
	psycho_bg_timer = 0.0
	overdrive_trails.clear()
	psycho_neutralize_particles.clear()
	psychoball_hitstop_timer = 0.0


func update_cooldown(delta: float) -> void:
	psycho_cooldown = max(0.0, psycho_cooldown - delta)


func can_trigger(context: Dictionary, kuromi_awakening: bool) -> bool:
	return (
		psycho_cooldown <= 0.0
		and not overdrive_active
		and not kuromi_awakening
		and int(context.get("current_stage", STAGE_ID)) == STAGE_ID
		and bool(context.get("ball_active", true))
		and not bool(context.get("waiting_for_serve", false))
	)


func activate(context: Dictionary) -> void:
	overdrive_active = true
	psycho_cooldown = COOLDOWN_SEC
	overdrive_timer = ENRAGED_DURATION_SEC if bool(context.get("enraged_boss_active", false)) else DURATION_SEC
	overdrive_flash_timer = 0.5
	psycho_bg_timer = 0.0
	psychoball_hitstop_timer = HITSTOP_SEC
	overdrive_trails.clear()


func consume_parried() -> void:
	psycho_cooldown = COOLDOWN_SEC
	reset_effects()


func emit_activation_feedback(deps: Dictionary) -> void:
	_play_audio(deps, "play_stage3_psychoball_loop")
	_trigger_hitstop_feedback(deps)


func is_active() -> bool:
	return overdrive_active


func is_hitstop_active() -> bool:
	return psychoball_hitstop_timer > 0.0


func update_hitstop(delta: float) -> void:
	psychoball_hitstop_timer = max(0.0, psychoball_hitstop_timer - delta)


func update(delta: float, context: Dictionary, deps: Dictionary, result: Dictionary) -> void:
	if not overdrive_active:
		return
	var ball_pos: Vector2 = _as_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	if _is_ball_in_dense_smoke(ball_pos, context, deps):
		_neutralize_with_smoke(ball_pos, context, deps, result)
		return
	overdrive_timer -= delta
	if overdrive_timer <= 0.0:
		overdrive_active = false
		overdrive_trails.clear()
		psycho_bg_timer = 0.0
		_play_audio(deps, "stop_stage3_psychoball_loop")
		return
	psycho_bg_timer += delta * 60.0
	var ball_vel: Vector2 = _as_vector2(context.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	var curve: float = sin(float(Time.get_ticks_msec()) / 80.0) * 3.0
	ball_vel.x += curve * _rng.randf_range(0.5, 1.2) * delta * 60.0
	if _rng.randf() < 0.01 * delta * 60.0:
		ball_pos = Vector2(_rng.randf_range(50.0, WIDTH - 50.0), _rng.randf_range(150.0, HEIGHT - 150.0))
	result["ball_vel"] = ball_vel
	result["ball_pos"] = ball_pos
	var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2(330.0, 25.0)), Vector2(330.0, 25.0))
	var boss_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)), Vector2(100.0, 40.0))
	overdrive_trails.push_front({
		"center": boss_pos + Vector2(boss_size.x * 0.5, boss_size.y * 0.5 + 31.0),
		"alpha": TRAIL_INITIAL_ALPHA,
	})
	var trail_fade := TRAIL_FADE_PER_FRAME * delta * 60.0
	for idx in range(overdrive_trails.size() - 1, -1, -1):
		var trail: Dictionary = overdrive_trails[idx]
		trail["alpha"] = float(trail.get("alpha", 0.0)) - trail_fade
		if float(trail["alpha"]) < TRAIL_MIN_ALPHA:
			overdrive_trails.remove_at(idx)
		else:
			overdrive_trails[idx] = trail
	if overdrive_trails.size() > MAX_OVERDRIVE_TRAILS:
		overdrive_trails.resize(MAX_OVERDRIVE_TRAILS)


func update_neutralize_particles(delta: float) -> void:
	if psycho_neutralize_particles.is_empty():
		return
	var fps_scale := delta * 60.0
	var damping := pow(0.95, fps_scale)
	var write_idx: int = 0
	for idx in range(psycho_neutralize_particles.size()):
		var particle: Dictionary = psycho_neutralize_particles[idx]
		particle["x"] = float(particle.get("x", 0.0)) + float(particle.get("vx", 0.0)) * fps_scale
		particle["y"] = float(particle.get("y", 0.0)) + float(particle.get("vy", 0.0)) * fps_scale
		particle["vx"] = float(particle.get("vx", 0.0)) * damping
		particle["vy"] = float(particle.get("vy", 0.0)) * damping
		particle["life_frames"] = float(particle.get("life_frames", 0.0)) - fps_scale
		if float(particle.get("life_frames", 0.0)) <= 0.0:
			continue
		psycho_neutralize_particles[write_idx] = particle
		write_idx += 1
	if write_idx < psycho_neutralize_particles.size():
		psycho_neutralize_particles.resize(write_idx)


func get_actor_draw_context(copy_arrays: bool = false) -> Dictionary:
	return {
		"stage3_emotional_overdrive_active": overdrive_active,
		"stage3_emotional_overdrive_ratio": overdrive_timer / max(0.001, ENRAGED_DURATION_SEC),
		"stage3_psycho_bg_timer": psycho_bg_timer,
		"stage3_psychoball_hitstop_active": is_hitstop_active(),
		"stage3_psychoball_hitstop_ratio": psychoball_hitstop_timer / max(0.001, HITSTOP_SEC),
		"stage3_overdrive_trails": StageActorDrawContextArrays.snapshot(overdrive_trails, copy_arrays, true),
		"stage3_psychoball_neutralize_particles": StageActorDrawContextArrays.snapshot(psycho_neutralize_particles, copy_arrays, true),
	}


func sync_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("sync_stage3_psychoball_loop"):
		audio.sync_stage3_psychoball_loop(overdrive_active)


func _neutralize_with_smoke(ball_pos: Vector2, context: Dictionary, deps: Dictionary, result: Dictionary) -> void:
	overdrive_active = false
	overdrive_timer = 0.0
	overdrive_trails.clear()
	psycho_bg_timer = 0.0
	psychoball_hitstop_timer = 0.0
	_play_audio(deps, "stop_stage3_psychoball_loop")
	_play_neutralize_audio(deps)

	var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2(WIDTH * 0.5 - 50.0, 25.0)), Vector2(WIDTH * 0.5 - 50.0, 25.0))
	var boss_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)), Vector2(100.0, 40.0))
	var boss_height: float = max(1.0, float(context.get("boss_hitbox_height", boss_size.y)))
	var boss_center := boss_pos + Vector2(boss_size.x * 0.5, boss_height * 0.5)
	var direction := boss_center - ball_pos
	var ball_vel := Vector2(0.0, -SMOKE_NEUTRALIZE_SPEED)
	if direction.length() > 0.001:
		ball_vel = direction.normalized() * SMOKE_NEUTRALIZE_SPEED
	result["ball_vel"] = ball_vel
	result["ball_pos"] = ball_pos
	result["stage3_psychoball_smoke_neutralized"] = true
	_spawn_neutralize_particles(ball_pos)


func _is_ball_in_dense_smoke(ball_pos: Vector2, context: Dictionary, deps: Dictionary) -> bool:
	for value in _get_smoke_zones(context, deps):
		var zone: Dictionary = _as_dict(value)
		if zone.is_empty():
			continue
		var opacity: float = float(zone.get("opacity", 0.0))
		var threshold := 50.0 if opacity > 1.0 else SMOKE_OPACITY_THRESHOLD
		if opacity <= threshold:
			continue
		var center: Vector2 = _get_smoke_zone_center(zone)
		var radius_y: float = float(zone.get("radius", 0.0))
		var radius_x: float = float(zone.get("radius_x", radius_y))
		if radius_x <= 0.0 or radius_y <= 0.0:
			continue
		var dx: float = (ball_pos.x - center.x) / radius_x
		var dy: float = (ball_pos.y - center.y) / radius_y
		if dx * dx + dy * dy <= 1.0:
			return true
	return false


func _get_smoke_zones(context: Dictionary, deps: Dictionary) -> Array:
	for key in ["stage3_smoke_zones", "smoke_zones", "active_item_tear_gas_zones", "tear_gas_zones"]:
		var context_zones := _as_array(context.get(key, []))
		if not context_zones.is_empty():
			return context_zones
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null:
		if active_item_runtime.has_method("get_tear_gas_zones"):
			var runtime_zones := _as_array(active_item_runtime.get_tear_gas_zones())
			if not runtime_zones.is_empty():
				return runtime_zones
		var throw_controller: Object = active_item_runtime.get("throw_controller")
		if throw_controller != null and throw_controller.has_method("get_tear_gas_zones"):
			var controller_zones := _as_array(throw_controller.get_tear_gas_zones())
			if not controller_zones.is_empty():
				return controller_zones
	return []


func _get_smoke_zone_center(zone: Dictionary) -> Vector2:
	if zone.get("position", null) is Vector2:
		return zone.get("position")
	return Vector2(float(zone.get("x", 0.0)), float(zone.get("y", 0.0)))


func _spawn_neutralize_particles(center: Vector2) -> void:
	psycho_neutralize_particles.append_array(Stage3BossSkillPayloadFactory.build_psychoball_neutralize_particles(
		center,
		NEUTRALIZE_PARTICLE_COUNT,
		_rng
	))
	if psycho_neutralize_particles.size() > MAX_NEUTRALIZE_PARTICLES:
		_trim_array_from_front(psycho_neutralize_particles, MAX_NEUTRALIZE_PARTICLES)


func _trim_array_from_front(source: Array, max_size: int) -> void:
	var overflow: int = source.size() - max_size
	if overflow <= 0:
		return
	var write_idx: int = 0
	for read_idx in range(overflow, source.size()):
		source[write_idx] = source[read_idx]
		write_idx += 1
	source.resize(write_idx)


func _play_neutralize_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		return
	if audio.has_method("play_stage3_smoke_neutralize"):
		audio.play_stage3_smoke_neutralize()
	elif audio.has_method("play_paddle_hit"):
		audio.play_paddle_hit()


func _trigger_hitstop_feedback(deps: Dictionary) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback != null:
		if feedback.has_method("max_screen_shake"):
			feedback.max_screen_shake(0.12, 7.0)
		elif feedback.has_method("set_screen_shake"):
			feedback.set_screen_shake(0.12, 7.0)


func _play_audio(deps: Dictionary, method: String) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method(method):
		audio.call(method)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
