extends RefCounted

const StageActorDrawContextArrays := preload("res://scripts/stages/common/stage_actor_draw_context_arrays.gd")
const Stage3BossSkillPayloadFactory := preload("res://scripts/stages/stage3/stage3_boss_skill_payload_factory.gd")
const PlayerKnockbackImmunity := preload("res://scripts/stages/common/player_knockback_immunity.gd")

const WIDTH := 760.0
const COOLDOWN_SEC := 35.0
const WINDUP_SEC := 0.5
const THROW_ANIMATION_SEC := 0.6
const THROW_START_X_RATIO := 0.9
const THROW_SPEED := 0.04
const LIFETIME_SEC := 4.0
const SMOKE_SEC := 3.0
const SMOKE_FADE_SEC := 2.0
const SMOKE_RADIUS := 80.0
const REVERSE_SEC := 2.0
const EXPLODE_SEC := 0.5
const EXPLOSION_RADIUS := 120.0
const EXPLOSION_KNOCKBACK_SPEED := 8.0
const EXPLOSION_KNOCKBACK_FRAMES := 18.0
const EXPLOSION_KNOCKBACK_DECAY := 0.85
const EXPLOSION_KNOCKBACK_SOURCE := "stage3_curse_chest_explosion"
const MAX_SMOKE_PARTICLES := 240

var curse_phase := "idle"
var curse_cooldown := COOLDOWN_SEC
var curse_windup_timer := 0.0
var curse_throw_progress := 0.0
var curse_throw_start := Vector2.ZERO
var curse_throw_pos := Vector2.ZERO
var curse_target := Vector2.ZERO
var curse_pos := Vector2.ZERO
var curse_lifetime := 0.0
var curse_open_timer := 0.0
var curse_reverse_timer := 0.0
var curse_smoke: Array = []
var curse_explosion_timer := 0.0
var curse_explosion_particles: Array = []
var curse_nudge_vx := 0.0
var curse_wobble_angle := 0.0
var curse_wobble_vel := 0.0

var _rng: RandomNumberGenerator


func _init(shared_rng: RandomNumberGenerator) -> void:
	_rng = shared_rng


func reset() -> void:
	curse_cooldown = COOLDOWN_SEC
	reset_effects()


func reset_effects() -> void:
	curse_phase = "idle"
	curse_windup_timer = 0.0
	curse_throw_progress = 0.0
	curse_smoke.clear()
	curse_explosion_particles.clear()
	curse_reverse_timer = 0.0
	curse_nudge_vx = 0.0
	curse_wobble_angle = 0.0
	curse_wobble_vel = 0.0


func update_cooldown(delta: float) -> void:
	curse_cooldown = max(0.0, curse_cooldown - delta)


func is_ready() -> bool:
	return curse_cooldown <= 0.0 and curse_phase == "idle"


func is_reverse_active() -> bool:
	return curse_reverse_timer > 0.0


func activate(deps: Dictionary) -> void:
	curse_phase = "windup"
	curse_windup_timer = WINDUP_SEC
	curse_target = Vector2(_rng.randf_range(60.0, WIDTH - 60.0), _rng.randf_range(700.0, 730.0))
	curse_cooldown = COOLDOWN_SEC
	_play_audio(deps, "play_stage3_dollcurse")


func consume_parried() -> void:
	curse_cooldown = COOLDOWN_SEC
	reset_effects()


func update(delta: float, context: Dictionary, deps: Dictionary) -> void:
	if curse_reverse_timer > 0.0:
		curse_reverse_timer = max(0.0, curse_reverse_timer - delta)
	match curse_phase:
		"idle":
			return
		"windup":
			curse_windup_timer -= delta
			if curse_windup_timer <= 0.0:
				var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2(330.0, 25.0)), Vector2(330.0, 25.0))
				var boss_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)), Vector2(100.0, 40.0))
				# Match the authored right-paw release instead of snapping the
				# procedural projectile back to the boss center at the handoff.
				curse_throw_start = boss_pos + Vector2(boss_size.x * THROW_START_X_RATIO, boss_size.y + 10.0)
				curse_throw_pos = curse_throw_start
				curse_throw_progress = 0.0
				curse_phase = "throwing"
		"throwing":
			curse_throw_progress = min(1.0, curse_throw_progress + THROW_SPEED * delta * 60.0)
			var ratio: float = curse_throw_progress
			curse_throw_pos = curse_throw_start.lerp(curse_target, ratio)
			curse_throw_pos.y += -180.0 * (4.0 * ratio * (1.0 - ratio))
			if curse_throw_progress >= 1.0:
				curse_pos = curse_target
				curse_lifetime = 0.0
				curse_open_timer = 0.0
				curse_smoke.clear()
				curse_phase = "closed"
				_play_audio(deps, "play_stage3_chest_land")
		"closed":
			_update_closed(delta, context)
			if curse_lifetime >= LIFETIME_SEC:
				_trigger_explosion(context, deps)
		"open":
			_update_open(delta, context)
		"exploding":
			_update_explosion(delta)


func get_actor_draw_context(copy_arrays: bool = false) -> Dictionary:
	return {
		"stage3_curse_chest_phase": curse_phase,
		"stage3_curse_chest_windup_progress": 1.0 - curse_windup_timer / max(0.001, WINDUP_SEC),
		"stage3_curse_chest_throw_anim_active": is_throw_animation_active(),
		"stage3_curse_chest_throw_anim_progress": get_throw_animation_progress(),
		"stage3_curse_chest_throw_progress": curse_throw_progress,
		"stage3_curse_chest_throw_pos": curse_throw_pos,
		"stage3_curse_chest_throw_start": curse_throw_start,
		"stage3_curse_chest_target": curse_target,
		"stage3_curse_chest_pos": curse_pos,
		"stage3_curse_chest_wobble": curse_wobble_angle,
		"stage3_curse_chest_lifetime_ratio": curse_lifetime / max(0.001, LIFETIME_SEC),
		"stage3_curse_chest_smoke": StageActorDrawContextArrays.snapshot(curse_smoke, copy_arrays, false),
		"stage3_curse_reverse_active": is_reverse_active(),
		"stage3_curse_reverse_ratio": curse_reverse_timer / max(0.001, REVERSE_SEC),
		"stage3_curse_chest_explosion_particles": StageActorDrawContextArrays.snapshot(curse_explosion_particles, copy_arrays, true),
	}


func is_throw_animation_active() -> bool:
	return curse_phase in ["windup", "throwing"] and _get_throw_animation_elapsed_sec() < THROW_ANIMATION_SEC


func get_throw_animation_progress() -> float:
	if not is_throw_animation_active():
		return 0.0
	return clamp(_get_throw_animation_elapsed_sec() / THROW_ANIMATION_SEC, 0.0, 1.0)


func _get_throw_animation_elapsed_sec() -> float:
	if curse_phase == "windup":
		return max(0.0, WINDUP_SEC - curse_windup_timer)
	if curse_phase == "throwing":
		return WINDUP_SEC + curse_throw_progress / max(0.001, THROW_SPEED * 60.0)
	return THROW_ANIMATION_SEC


func _update_closed(delta: float, context: Dictionary) -> void:
	curse_lifetime += delta
	var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size: Vector2 = _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	var player_center := player_pos + player_size * 0.5
	var proximity: Vector2 = player_center - curse_pos
	var distance: float = proximity.length()
	if distance < 55.0 and distance > 1.0:
		var push_strength: float = (1.0 - distance / 55.0) * 1.8
		curse_nudge_vx += (-proximity.x / distance) * push_strength
		curse_wobble_vel += (-proximity.x / distance) * push_strength * 3.0
	if abs(curse_nudge_vx) > 0.05:
		curse_pos.x = clamp(curse_pos.x + curse_nudge_vx, 20.0, WIDTH - 20.0)
		curse_nudge_vx *= 0.85
	else:
		curse_nudge_vx = 0.0
	curse_wobble_vel += -curse_wobble_angle * 0.25
	curse_wobble_vel *= 0.88
	curse_wobble_angle = clamp(curse_wobble_angle + curse_wobble_vel, -18.0, 18.0)
	var dash_snapshot: Dictionary = _as_dict(context.get("dash_snapshot", {}))
	if bool(dash_snapshot.get("active", false)) and distance < 56.0:
		curse_phase = "open"
		curse_open_timer = 0.0


func _update_open(delta: float, context: Dictionary) -> void:
	curse_open_timer += delta
	if curse_open_timer <= SMOKE_SEC:
		for _index in range(3):
			curse_smoke.append(Stage3BossSkillPayloadFactory.build_curse_smoke_particle(curse_pos, _rng))
		if curse_smoke.size() > MAX_SMOKE_PARTICLES:
			_trim_array_from_front(curse_smoke, MAX_SMOKE_PARTICLES)
	var write_idx: int = 0
	for idx in range(curse_smoke.size()):
		var particle: Dictionary = curse_smoke[idx]
		particle["x"] = float(particle["x"]) + float(particle["vx"]) * delta * 60.0
		particle["y"] = float(particle["y"]) + float(particle["vy"]) * delta * 60.0
		particle["vy"] = float(particle["vy"]) - 0.01 * delta * 60.0
		particle["vx"] = float(particle["vx"]) * pow(0.98, delta * 60.0)
		particle["life"] = float(particle["life"]) - delta
		particle["size"] = float(particle["size"]) + 0.05 * delta * 60.0
		if curse_open_timer > SMOKE_SEC:
			var fade_progress: float = (curse_open_timer - SMOKE_SEC) / SMOKE_FADE_SEC
			particle["alpha"] = max(0.0, 1.0 - fade_progress)
		if float(particle["life"]) <= 0.0 or float(particle["alpha"]) <= 0.02:
			continue
		curse_smoke[write_idx] = particle
		write_idx += 1
	if write_idx < curse_smoke.size():
		curse_smoke.resize(write_idx)
	if curse_open_timer <= SMOKE_SEC and curse_reverse_timer <= 0.0:
		var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
		var player_size: Vector2 = _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
		if (player_pos + player_size * 0.5).distance_to(curse_pos) < SMOKE_RADIUS:
			curse_reverse_timer = REVERSE_SEC
	if curse_open_timer >= SMOKE_SEC + SMOKE_FADE_SEC and curse_smoke.is_empty():
		curse_phase = "idle"


func _trigger_explosion(context: Dictionary, deps: Dictionary) -> void:
	curse_phase = "exploding"
	curse_explosion_timer = EXPLODE_SEC
	curse_explosion_particles.clear()
	curse_explosion_particles.append_array(Stage3BossSkillPayloadFactory.build_curse_explosion_particles(curse_pos, 15, _rng))
	_apply_explosion_knockback(context, deps)
	_play_audio(deps, "play_stage3_curse_explode")


func _apply_explosion_knockback(context: Dictionary, deps: Dictionary) -> bool:
	var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size: Vector2 = _as_vector2(
		context.get("player_paddle_size", Vector2(155.0, 50.0)),
		Vector2(155.0, 50.0)
	)
	var player_center: Vector2 = Rect2(player_pos, player_size).get_center()
	var offset: Vector2 = player_center - curse_pos
	var distance: float = offset.length()
	if distance >= EXPLOSION_RADIUS:
		return false
	if (
		PlayerKnockbackImmunity.is_cleanse_immune(deps, context)
		or PlayerKnockbackImmunity.try_block_player_knockback(
			deps,
			context,
			EXPLOSION_KNOCKBACK_SOURCE
		)
	):
		return false
	var direction := 1.0 if offset.x >= 0.0 else -1.0
	var strength: float = EXPLOSION_KNOCKBACK_SPEED * (1.0 - distance / EXPLOSION_RADIUS)
	var movement_state: Object = deps.get("movement_state", null)
	if movement_state == null or not movement_state.has_method("start_knockback"):
		return false
	return bool(movement_state.start_knockback(
		direction * strength,
		EXPLOSION_KNOCKBACK_FRAMES,
		EXPLOSION_KNOCKBACK_DECAY,
		true,
		true
	))


func _update_explosion(delta: float) -> void:
	curse_explosion_timer = max(0.0, curse_explosion_timer - delta)
	for idx in range(curse_explosion_particles.size() - 1, -1, -1):
		var particle: Dictionary = curse_explosion_particles[idx]
		particle["x"] = float(particle["x"]) + float(particle["vx"]) * delta * 60.0
		particle["y"] = float(particle["y"]) + float(particle["vy"]) * delta * 60.0
		particle["vy"] = float(particle["vy"]) + 0.1 * delta * 60.0
		particle["life"] = float(particle["life"]) - delta
		particle["life_ratio"] = clamp(float(particle["life"]) / max(0.001, float(particle.get("max_life", 0.67))), 0.0, 1.0)
		if float(particle["life"]) <= 0.0:
			curse_explosion_particles.remove_at(idx)
		else:
			curse_explosion_particles[idx] = particle
	if curse_explosion_timer <= 0.0 and curse_explosion_particles.is_empty():
		curse_phase = "idle"


func _trim_array_from_front(source: Array, max_size: int) -> void:
	var overflow: int = source.size() - max_size
	if overflow <= 0:
		return
	var write_idx: int = 0
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
	return fallback


func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
