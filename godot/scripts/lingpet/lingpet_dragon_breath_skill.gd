extends RefCounted

# 3-piece modular VFX (texture pieces + WritheEmber shader + textured particles +
# elapsed-driven tween envelopes). The simulation/gameplay below is unchanged;
# only the draw path composites the layered fire look.
const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const WritheEmberMaterial := preload("res://scripts/effects/writhe_ember_material.gd")
const DragonBreathTextureCache := preload("res://scripts/lingpet/lingpet_dragon_breath_texture_cache.gd")
const LingpetDragonBreathPayloadFactory := preload("res://scripts/lingpet/lingpet_dragon_breath_payload_factory.gd")
const LingpetDragonBreathRenderer := preload("res://scripts/lingpet/lingpet_dragon_breath_renderer.gd")
# Lingering ground fire reuses the molotov fire-zone effect (5-layer WritheEmber
# host + GPU embers). We drive a SEPARATE host pool via a dedicated name prefix
# so the lingpet breath never fights the molotov active item over hosts.
const MolotovZoneRenderer := preload("res://scripts/items/active_item_throw_molotov_renderer.gd")
const JET_MATERIAL_PRESET := "red_dragon_breath_jet"
const ZONE_FX_HOST_PREFIX := "LingpetDragonBreathFireFxHost"

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const BREATH_DURATION_SECONDS := 4.55
const BREATH_SPAWN_SECONDS := 1.56
const INITIAL_PARTICLES := 40
const CONTINUOUS_PARTICLES := 4
const PARTICLE_MAX := 132
const SPAWN_INTERVAL_SECONDS := 0.02
const HIT_COOLDOWN_SECONDS := 0.30
const HIT_FLASH_SECONDS := 0.32
const BALL_HIT_PADDING := 5.0
const BALL_MIN_SPEED := 10.0
const BALL_SPEED_MULT_MIN := 1.30
const BALL_SPEED_MULT_MAX := 1.50
const BALL_SIDE_KNOCK_MIN := 3.0
const BALL_SIDE_KNOCK_MAX := 6.0
const ANGLE_OFFSET_MAX := 0.30
# Breath "heat field": a forgiving upward cone from the mouth. Any ball inside it
# is reflected while the breath is live, independent of whether a tiny ember
# sprite happens to overlap it. The AI companion can't be aimed by the player and
# its stream is narrow, so per-ember hit-testing almost never caught the ball
# (~0.2 hits per breath in sim); this cone makes the reflection actually land.
const BREATH_FIELD_REACH := 380.0
const BREATH_FIELD_BASE_HALF_W := 46.0
const BREATH_FIELD_TIP_HALF_W := 150.0
const FIRE_ZONE_WIDTH := 100.0
const FIRE_ZONE_HEIGHT := 50.0
const FIRE_ZONE_DURATION_SECONDS := 2.0
const FIRE_ZONE_DUPLICATE_X := 60.0
const FIRE_ZONE_DUPLICATE_Y := 40.0
const FIRE_ZONE_SPAWN_INTERVAL_SECONDS := 0.30
const FIRE_ZONE_SPREAD_INTERVAL_SECONDS := 5.0 / 60.0
# Smooth decaying-velocity bounce (parity with the molotov fire zone): a contact
# arms an outward velocity that decays each frame so the boss eases out and is
# pulled back by its own (slowed) AI, instead of being hard-snapped to a wall.
const FIRE_ZONE_KNOCKBACK_SPEED := 17.0  # initial outward px/frame on contact
const FIRE_ZONE_KNOCKBACK_DECAY_PER_FRAME := 0.88
const FIRE_ZONE_KNOCKBACK_REARM_SPEED := 3.5  # re-bounce once residual vel drops below this
const FIRE_ZONE_KNOCKBACK_COOLDOWN_FRAMES := 8.0  # short: re-bounce on each fresh contact (anti-cross)
# Post-AI crossing barrier (dragon breath updates AFTER update_boss_ai): the boss
# may not end a frame on the far side of a zone midline relative to the side it
# entered the frame on. Mirrors the boss_ai_state molotov barrier; the y-band
# matches _is_boss_touching_zone so a patch only blocks while sharing the boss y.
const FIRE_ZONE_BARRIER_Y_BAND := 74.0
const FIRE_ZONE_BARRIER_SIDE_EPSILON := 0.5
const FIRE_ZONE_INITIAL_FLAMES := 10
const FIRE_ZONE_MAX_FLAMES := 30
const FIRE_ZONE_SPAWN_FLAMES := 2
const SLOW_MULTIPLIER := 0.50
const SLOW_REFRESH_FRAMES := 4.0
const STATUS_SOURCE := "red_dragon_dragon_breath_fire"

# Red Dragon flies in with the sortie motion (off-screen -> ingress -> loiter in
# the center background). The breath may only arm once it has actually reached
# the center stage; otherwise it fires during ingress and pours from the screen
# edge before the dragon is on-stage. Band matches the sortie loiter region so
# the breath starts as the dragon enters the center and traces its loiter path.
const ARM_CENTER_MIN_X := 150.0
const ARM_CENTER_MAX_X := FIELD_WIDTH - 150.0
const ARM_CENTER_MIN_Y := 110.0
const ARM_CENTER_MAX_Y := FIELD_HEIGHT - 220.0

var _breath_active := false
var _spawn_phase_ended := false
var _elapsed := 0.0
var _spawn_timer := 0.0
var _hit_cooldown := 0.0
var _fire_zone_timer := 0.0
var _direction := -1.0
var _origin := Vector2.ZERO
var _particles: Array[Dictionary] = []
var _fire_zones: Array[Dictionary] = []
var _fire_zone_positions: Array[Vector2] = []
var _hit_flash_timer := 0.0
var _last_hit_pos := Vector2.ZERO
var _ball_hit_count := 0
var _fire_zone_spawn_count := 0
var _last_push_dir := 0.0
var _registry: Object = null
var _jet_material: ShaderMaterial = null
var _additive_material: CanvasItemMaterial = null
var _zone_fx_renderer: Object = null
var _renderer: Object = LingpetDragonBreathRenderer.new()
var _zone_fx_dirty := false
var _zone_id_counter := 0


func reset() -> void:
	if not _fire_zones.is_empty() or _breath_active:
		_clear_boss_slow(_registry)
	_breath_active = false
	_spawn_phase_ended = false
	_elapsed = 0.0
	_spawn_timer = 0.0
	_hit_cooldown = 0.0
	_fire_zone_timer = 0.0
	_direction = -1.0
	_origin = Vector2.ZERO
	_particles.clear()
	_fire_zones.clear()
	_fire_zone_positions.clear()
	_hit_flash_timer = 0.0
	_last_hit_pos = Vector2.ZERO
	_last_push_dir = 0.0
	if _zone_fx_renderer != null and _zone_fx_renderer.has_method("deactivate_all_hosts"):
		_zone_fx_renderer.deactivate_all_hosts()
	_zone_fx_dirty = false


func prewarm() -> void:
	# Resource prewarm only: the WritheEmber shader PSO is already warmed at boot
	# by the shared inferno / electrocution hosts (same static shader instance),
	# so building the materials + procedural textures here is enough to keep the
	# first breath frame off the hot-path lazy-init trap.
	WritheEmberMaterial.prewarm()
	DragonBreathTextureCache.prewarm()
	ImpactFlareTextureCache.prewarm()
	_ensure_materials()
	_ensure_zone_fx_renderer()
	if _zone_fx_renderer != null and _zone_fx_renderer.has_method("prewarm_assets"):
		_zone_fx_renderer.prewarm_assets()


func _ensure_materials() -> void:
	if _jet_material == null:
		_jet_material = WritheEmberMaterial.build_material(JET_MATERIAL_PRESET)
	if _additive_material == null:
		_additive_material = CanvasItemMaterial.new()
		_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func _ensure_zone_fx_renderer() -> void:
	if _zone_fx_renderer != null:
		return
	_zone_fx_renderer = MolotovZoneRenderer.new()
	if _zone_fx_renderer.has_method("set_fx_host_name_prefix"):
		_zone_fx_renderer.set_fx_host_name_prefix(ZONE_FX_HOST_PREFIX)


func launch(origin: Vector2, _owner: Object = null) -> void:
	reset()
	_breath_active = true
	_elapsed = 0.0
	_spawn_timer = 0.0
	_hit_cooldown = 0.0
	_fire_zone_timer = 0.0
	_origin = Vector2(clampf(origin.x, 24.0, FIELD_WIDTH - 24.0), clampf(origin.y, 0.0, FIELD_HEIGHT))
	# Red Dragon is a player-side companion and always breathes toward the boss
	# at the top of the field, so the stream always points up regardless of where
	# the (moving) companion currently sits. The old y-based sign flipped to a
	# downward spray whenever the companion patrolled into the upper half.
	_direction = -1.0
	_spawn_initial_particles()


func update(delta: float, owner: Object, registry: Object = null, launch_context: Dictionary = {}) -> void:
	_registry = registry
	var safe_delta := maxf(0.0, delta)
	if safe_delta <= 0.0:
		if not _fire_zones.is_empty():
			_apply_fire_zones(owner, registry, 0.0)
		return
	_hit_flash_timer = maxf(0.0, _hit_flash_timer - safe_delta)
	_hit_cooldown = maxf(0.0, _hit_cooldown - safe_delta)
	if _breath_active:
		_elapsed += safe_delta
		# Keep the mouth anchored to the live (moving) companion while it pours,
		# so the breath reads as a steady stream sweeping with the dragon instead
		# of a one-shot fountain stuck at the launch point.
		_follow_companion_origin(launch_context)
		_update_breath_spawn(safe_delta)
		# Reliable ball reflection: catch any ball inside the breath's heat cone.
		_try_reflect_ball_in_breath_field(owner)
		if _elapsed >= BREATH_DURATION_SECONDS:
			_breath_active = false
			_spawn_phase_ended = true
	_update_particles(safe_delta, owner)
	_update_fire_zones(safe_delta, owner, registry)


func _follow_companion_origin(launch_context: Dictionary) -> void:
	# Only steer the emitter while the mouth pour / jet is still live; afterward
	# the airborne embers carry themselves and the origin no longer matters.
	if _elapsed >= BREATH_SPAWN_SECONDS + 0.3:
		return
	var companion_pos: Variant = launch_context.get("companion_pos", null)
	if not (companion_pos is Vector2) or (companion_pos as Vector2) == Vector2.ZERO:
		return
	var radius := maxf(0.0, float(launch_context.get("companion_radius", 0.0)))
	var mouth: Vector2 = (companion_pos as Vector2) + Vector2(0.0, _direction * (radius + 10.0))
	_origin = Vector2(clampf(mouth.x, 24.0, FIELD_WIDTH - 24.0), clampf(mouth.y, 0.0, FIELD_HEIGHT))


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	# Lingering ground fire reuses the molotov fire-zone effect via a dedicated
	# host pool. Run it every frame (even with no zones) so the hosts deactivate
	# cleanly when the last patch expires -- draw() is called every companion
	# frame, so this is the natural place to drive host lifecycle.
	_draw_fire_zones_molotov(canvas, shake_offset)
	if not has_visible_effects():
		return
	_ensure_materials()
	_renderer.draw_breath(
		canvas,
		shake_offset,
		_breath_active,
		_elapsed,
		_origin,
		_direction,
		_particles,
		_hit_flash_timer,
		_last_hit_pos,
		HIT_FLASH_SECONDS,
		BREATH_SPAWN_SECONDS,
		_jet_material,
		_additive_material
	)


func has_visible_effects() -> bool:
	return _breath_active or not _particles.is_empty() or not _fire_zones.is_empty() or _hit_flash_timer > 0.0


func is_active() -> bool:
	return _breath_active or not _particles.is_empty() or not _fire_zones.is_empty()


# Arming gate: only let the breath start once the dragon is visible AND has flown
# into the center background. Prevents the sortie-ingress "fires from the screen
# edge" bug. The launch happens ~1s later (windup), but the dragon arms the first
# frame it enters the center, so the launch still lands on-stage.
func can_arm(params: Dictionary) -> bool:
	if not bool(params.get("companion_visible", false)):
		return false
	var companion_pos: Variant = params.get("companion_pos", Vector2.ZERO)
	if not (companion_pos is Vector2):
		return false
	var pos: Vector2 = companion_pos as Vector2
	if pos == Vector2.ZERO:
		return false
	if pos.x < ARM_CENTER_MIN_X or pos.x > ARM_CENTER_MAX_X:
		return false
	if pos.y < ARM_CENTER_MIN_Y or pos.y > ARM_CENTER_MAX_Y:
		return false
	return true


func get_ball_hit_count_for_tests() -> int:
	return _ball_hit_count


func get_fire_zone_spawn_count_for_tests() -> int:
	return _fire_zone_spawn_count


func get_snapshot() -> Dictionary:
	var primary_zone_pos := Vector2.ZERO
	var primary_zone_timer := 0.0
	var boss_in_fire := false
	if not _fire_zones.is_empty():
		var zone: Dictionary = _fire_zones[0]
		primary_zone_pos = zone.get("position", Vector2.ZERO)
		primary_zone_timer = float(zone.get("timer", 0.0))
	for zone in _fire_zones:
		if bool(zone.get("boss_in_fire", false)):
			boss_in_fire = true
			break
	return {
		"dragon_breath_active": _breath_active,
		"dragon_breath_particle_count": _particles.size(),
		"dragon_breath_fire_zone_count": _fire_zones.size(),
		"dragon_breath_fire_zone_pos": primary_zone_pos,
		"dragon_breath_fire_zone_timer": primary_zone_timer,
		"dragon_breath_ball_hit_count": _ball_hit_count,
		"dragon_breath_fire_zone_spawn_count": _fire_zone_spawn_count,
		"dragon_breath_ball_on_fire": _breath_active and _hit_cooldown > 0.0,
		"dragon_breath_boss_in_fire": boss_in_fire,
		"dragon_breath_slow_multiplier": SLOW_MULTIPLIER,
		"dragon_breath_duration": BREATH_DURATION_SECONDS,
		"dragon_breath_spawn_seconds": BREATH_SPAWN_SECONDS,
	}


func _update_breath_spawn(delta: float) -> void:
	if _spawn_phase_ended:
		return
	if _elapsed >= BREATH_SPAWN_SECONDS:
		_spawn_phase_ended = true
		return
	_spawn_timer += delta
	while _spawn_timer >= SPAWN_INTERVAL_SECONDS:
		_spawn_timer -= SPAWN_INTERVAL_SECONDS
		for _i in range(CONTINUOUS_PARTICLES):
			_add_breath_particle(false)


func _spawn_initial_particles() -> void:
	for i in range(INITIAL_PARTICLES):
		_add_breath_particle(true, float(i) / float(maxi(1, INITIAL_PARTICLES)))


func _add_breath_particle(initial: bool, index_ratio: float = 0.0) -> void:
	if _particles.size() >= PARTICLE_MAX:
		return
	_particles.append(LingpetDragonBreathPayloadFactory.build_breath_particle(_origin, _direction, initial, index_ratio))


func _update_particles(delta: float, owner: Object) -> void:
	if _particles.is_empty():
		return
	var dying_positions: Array[Vector2] = []
	var write_index := 0
	for read_index in range(_particles.size()):
		var particle: Dictionary = _particles[read_index]
		var delay: float = float(particle.get("delay", 0.0))
		if delay > 0.0:
			delay = maxf(0.0, delay - delta)
			particle["delay"] = delay
			_particles[write_index] = particle
			write_index += 1
			continue

		var pos: Vector2 = particle.get("pos", Vector2.ZERO)
		var vel: Vector2 = particle.get("vel", Vector2.ZERO)
		pos += vel * delta
		var life: float = float(particle.get("life", 0.0)) - delta
		var size: float = float(particle.get("size", 1.0)) * pow(0.985, delta * 60.0)
		particle["pos"] = pos
		particle["life"] = life
		particle["size"] = size
		particle["phase"] = float(particle.get("phase", 0.0)) + delta

		_try_hit_ball_with_particle(particle, owner)

		if life <= 0.0 and not bool(particle.get("zone_reported", false)):
			dying_positions.append(pos)
			particle["zone_reported"] = true
		if life > -0.5 and size > 1.5:
			_particles[write_index] = particle
			write_index += 1
	if write_index < _particles.size():
		_particles.resize(write_index)
	_maybe_spawn_fire_zone_from_dying(delta, dying_positions)


func _try_hit_ball_with_particle(particle: Dictionary, owner: Object) -> void:
	if _hit_cooldown > 0.0 or owner == null:
		return
	if not bool(_get_owner_value(owner, "ball_active", false)):
		return
	var size := maxf(float(particle.get("size", 0.0)), 5.0)
	if size <= 3.0:
		return
	var ball_pos: Vector2 = _get_owner_vector2(owner, "ball_pos", Vector2.ZERO)
	var ball_radius := _get_ball_radius(owner) + BALL_HIT_PADDING
	var pos: Vector2 = particle.get("pos", Vector2.ZERO)
	if pos.distance_to(ball_pos) > size + ball_radius:
		return
	_reflect_ball(owner, pos.x)


# Reflect any ball inside the breath's upward heat cone (independent of the tiny
# ember sprites). This is the reliable path that makes the dragon breath actually
# bounce the ball during normal AI-companion play.
func _try_reflect_ball_in_breath_field(owner: Object) -> void:
	if _hit_cooldown > 0.0 or owner == null:
		return
	if not bool(_get_owner_value(owner, "ball_active", false)):
		return
	var ball_pos: Vector2 = _get_owner_vector2(owner, "ball_pos", Vector2.ZERO)
	# along = how far the ball sits in the breath's travel direction from the mouth.
	var along := (ball_pos.y - _origin.y) * _direction
	if along < -12.0 or along > BREATH_FIELD_REACH:
		return
	var spread_t := clampf(along / BREATH_FIELD_REACH, 0.0, 1.0)
	var half_w := lerpf(BREATH_FIELD_BASE_HALF_W, BREATH_FIELD_TIP_HALF_W, spread_t)
	if absf(ball_pos.x - _origin.x) > half_w + _get_ball_radius(owner):
		return
	_reflect_ball(owner, _origin.x)


# Shared boost + side-knockback (Ignis "the fire shoves the ball toward the boss"
# behavior). `source_x` is the x the ball is pushed away from.
func _reflect_ball(owner: Object, source_x: float) -> void:
	var ball_pos: Vector2 = _get_owner_vector2(owner, "ball_pos", Vector2.ZERO)
	var ball_vel: Vector2 = _get_owner_vector2(owner, "ball_vel", Vector2.ZERO)
	var current_speed := ball_vel.length()
	if current_speed < 8.0:
		current_speed = BALL_MIN_SPEED
	var boosted_speed := current_speed * randf_range(BALL_SPEED_MULT_MIN, BALL_SPEED_MULT_MAX)
	var angle_offset := randf_range(-ANGLE_OFFSET_MAX, ANGLE_OFFSET_MAX)
	var next_vel := Vector2.ZERO
	next_vel.y = _direction * absf(boosted_speed * cos(angle_offset))
	var dx := ball_pos.x - source_x
	var knockback_dir := 1.0 if dx >= 0.0 else -1.0
	if absf(dx) <= 1.0:
		knockback_dir = -1.0 if randf() < 0.5 else 1.0
	next_vel.x = knockback_dir * randf_range(BALL_SIDE_KNOCK_MIN, BALL_SIDE_KNOCK_MAX) + boosted_speed * sin(angle_offset)
	owner.set("ball_vel", next_vel)
	_hit_cooldown = HIT_COOLDOWN_SECONDS
	_hit_flash_timer = HIT_FLASH_SECONDS
	_last_hit_pos = ball_pos
	_ball_hit_count += 1
	_play_ball_hit_feedback()


func _play_ball_hit_feedback() -> void:
	var audio: Object = _get_registry_instance(_registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_dragon_breath_ball_hit"):
		audio.play_dragon_breath_ball_hit()
	elif audio.has_method("play_dragon_breath_fire"):
		audio.play_dragon_breath_fire(true)


func _maybe_spawn_fire_zone_from_dying(delta: float, dying_positions: Array[Vector2]) -> void:
	_fire_zone_timer += delta
	if _fire_zone_timer < FIRE_ZONE_SPAWN_INTERVAL_SECONDS or dying_positions.is_empty():
		return
	_fire_zone_timer = 0.0
	var avg := Vector2.ZERO
	for pos in dying_positions:
		avg += pos
	avg /= float(dying_positions.size())
	avg.x = clampf(avg.x, FIRE_ZONE_WIDTH * 0.5, FIELD_WIDTH - FIRE_ZONE_WIDTH * 0.5)
	avg.y = clampf(avg.y, FIRE_ZONE_HEIGHT * 0.5, FIELD_HEIGHT - FIRE_ZONE_HEIGHT * 0.5)
	for existing in _fire_zone_positions:
		if absf(existing.x - avg.x) < FIRE_ZONE_DUPLICATE_X and absf(existing.y - avg.y) < FIRE_ZONE_DUPLICATE_Y:
			return
	_spawn_fire_zone(avg)


func _spawn_fire_zone(center: Vector2) -> void:
	_zone_id_counter += 1
	var zone := LingpetDragonBreathPayloadFactory.build_fire_zone(
		center,
		FIRE_ZONE_WIDTH,
		FIRE_ZONE_HEIGHT,
		FIRE_ZONE_DURATION_SECONDS,
		_zone_id_counter
	)
	_seed_zone_flames(zone, FIRE_ZONE_INITIAL_FLAMES, 30.0, 12.0)
	_fire_zones.append(zone)
	_fire_zone_positions.append(center)
	_fire_zone_spawn_count += 1
	_play_fire_zone_feedback(_registry, true)


func _update_fire_zones(delta: float, owner: Object, registry: Object) -> void:
	if _fire_zones.is_empty():
		return
	var write_index := 0
	for read_index in range(_fire_zones.size()):
		var zone: Dictionary = _fire_zones[read_index]
		var timer := float(zone.get("timer", 0.0)) - delta
		if timer <= 0.0:
			continue
		zone["timer"] = timer
		_update_zone_flames(zone, delta)
		_apply_single_fire_zone(zone, owner, registry, delta)
		_fire_zones[write_index] = zone
		write_index += 1
	if write_index < _fire_zones.size():
		_fire_zones.resize(write_index)
	if _fire_zones.is_empty():
		_clear_boss_slow(registry)


func _apply_fire_zones(owner: Object, registry: Object, delta: float) -> void:
	for index in range(_fire_zones.size()):
		var zone: Dictionary = _fire_zones[index]
		_apply_single_fire_zone(zone, owner, registry, delta)
		_fire_zones[index] = zone


func _apply_single_fire_zone(zone: Dictionary, owner: Object, registry: Object, delta: float) -> void:
	# Parity with the molotov fire zone: a smooth decaying-velocity bounce (not a
	# hard wall snap), paced so it never machine-gun jitters, plus the 화염 감속,
	# plus a hard post-AI crossing barrier that even a 40px/frame dash can't beat.
	# Dragon breath runs in update_lingpet AFTER update_boss_ai, so everything here
	# is the frame's last word on boss_pos.
	var in_fire := _is_boss_touching_zone(owner, zone)
	zone["boss_in_fire"] = in_fire
	var fps_scale := delta * 60.0
	var knockback_vel := float(zone.get("knockback_vel", 0.0))
	var knockback_cooldown := maxf(0.0, float(zone.get("knockback_cooldown", 0.0)) - fps_scale)

	if not in_fire:
		zone["engage_dir"] = 0.0
	else:
		_apply_boss_slow(registry)

	# Re-arm the outward bounce on a fresh/decayed contact. The short cooldown +
	# velocity gate pace it (anti-jitter) while still re-bouncing on EVERY fresh
	# contact so the boss can't drift through between bounces. engage_dir locks the
	# direction for the whole engagement so a boss nudged past center isn't flipped.
	if in_fire and knockback_cooldown <= 0.0 and absf(knockback_vel) <= FIRE_ZONE_KNOCKBACK_REARM_SPEED:
		var locked := float(zone.get("engage_dir", 0.0))
		var push_dir := signf(locked) if absf(locked) > 0.001 else _resolve_fire_push_dir(owner, zone)
		zone["engage_dir"] = push_dir
		zone["last_push_dir"] = push_dir
		_last_push_dir = push_dir
		knockback_vel = push_dir * FIRE_ZONE_KNOCKBACK_SPEED
		knockback_cooldown = FIRE_ZONE_KNOCKBACK_COOLDOWN_FRAMES
		var feedback: Object = _get_registry_instance(registry, "battle_feedback_state")
		if feedback != null and feedback.has_method("max_screen_shake"):
			feedback.max_screen_shake(0.05, 1.5)

	# Integrate + decay the outward bounce (also while the boss is leaving, so the
	# residual push gives a sluggish exit instead of a hard stop).
	if absf(knockback_vel) > 0.001:
		_apply_fire_knockback_step(owner, knockback_vel * fps_scale)
		knockback_vel *= pow(FIRE_ZONE_KNOCKBACK_DECAY_PER_FRAME, fps_scale)
		if absf(knockback_vel) < 0.3:
			knockback_vel = 0.0

	# Hard no-cross guarantee for fast moves (notably the boss dash, which the
	# bounce alone cannot undo in a single frame).
	_apply_fire_crossing_barrier(owner, registry, zone)

	zone["knockback_vel"] = knockback_vel
	zone["knockback_cooldown"] = knockback_cooldown


func _seed_zone_flames(zone: Dictionary, count: int, spread_x: float, spread_y: float) -> void:
	var flames: Array = zone.get("flames", [])
	var center: Vector2 = zone.get("position", Vector2.ZERO)
	for _i in range(count):
		flames.append(LingpetDragonBreathPayloadFactory.build_zone_flame(center, spread_x, spread_y))
	zone["flames"] = flames


func _update_zone_flames(zone: Dictionary, delta: float) -> void:
	var spread_timer := float(zone.get("spread_timer", 0.0)) + delta
	if spread_timer >= FIRE_ZONE_SPREAD_INTERVAL_SECONDS:
		spread_timer = fmod(spread_timer, FIRE_ZONE_SPREAD_INTERVAL_SECONDS)
		var active_flames: Array = zone.get("flames", [])
		if active_flames.size() < FIRE_ZONE_MAX_FLAMES:
			_seed_zone_flames(
				zone,
				FIRE_ZONE_SPAWN_FLAMES,
				float(zone.get("width", FIRE_ZONE_WIDTH)) * 0.5,
				float(zone.get("height", FIRE_ZONE_HEIGHT)) * 0.5
			)
	zone["spread_timer"] = spread_timer
	var flames: Array = zone.get("flames", [])
	var write_index := 0
	for read_index in range(flames.size()):
		var flame: Dictionary = flames[read_index]
		var life := float(flame.get("life", 0.0)) - delta
		var size := float(flame.get("size", 1.0)) * pow(0.97, delta * 60.0)
		if life <= 0.0 or size < 2.0:
			continue
		var pos: Vector2 = flame.get("pos", Vector2.ZERO)
		var phase := float(flame.get("phase", 0.0)) + delta * 3.2
		pos.y -= (0.18 + 0.16 * (0.5 + 0.5 * sin(phase))) * delta * 60.0
		pos.x += sin(phase * 1.7) * 0.32 * delta * 60.0
		flame["pos"] = pos
		flame["life"] = life
		flame["size"] = size
		flame["phase"] = phase
		flames[write_index] = flame
		write_index += 1
	if write_index < flames.size():
		flames.resize(write_index)
	zone["flames"] = flames


func _is_boss_touching_zone(owner: Object, zone: Dictionary) -> bool:
	if owner == null:
		return false
	var boss_rect := _get_boss_rect(owner)
	var center: Vector2 = zone.get("position", Vector2.ZERO)
	var width := float(zone.get("width", FIRE_ZONE_WIDTH))
	# Forgiving overlap so the moving boss actually catches the patch as it
	# crosses the top, instead of slipping past a narrow trigger band.
	var x_in_range := absf(boss_rect.get_center().x - center.x) < (width * 0.5 + boss_rect.size.x * 0.5)
	var y_in_range := absf(boss_rect.get_center().y - center.y) < 74.0
	return x_in_range and y_in_range


func _resolve_fire_push_dir(owner: Object, zone: Dictionary) -> float:
	# Use the PRE-AI side (boss_pos_prev, set before update_boss_ai) — the same
	# source the crossing barrier uses — so the bounce and the barrier always agree
	# on which way is "out". Reading the live post-AI position would arm the wrong
	# direction on a dash-cross frame (boss already on the far side), making the
	# bounce fight the barrier.
	var boss_rect := _get_boss_rect(owner)
	var prev_pos := _get_owner_vector2(owner, "boss_pos_prev", boss_rect.position)
	var center: Vector2 = zone.get("position", Vector2.ZERO)
	var delta_x := (prev_pos.x + boss_rect.size.x * 0.5) - center.x
	if absf(delta_x) > 0.001:
		return -1.0 if delta_x < 0.0 else 1.0
	var prev := float(zone.get("last_push_dir", _last_push_dir))
	if absf(prev) > 0.001:
		return signf(prev)
	var boss_vel := float(_get_owner_value(owner, "boss_vel", 0.0))
	if absf(boss_vel) > 0.2:
		return -signf(boss_vel)
	return 1.0


# One frame of the decaying bounce: nudge boss_pos.x by the (already decayed)
# delta, clamped to the field. Does not touch boss_vel — the boss AI keeps its
# own velocity; the patch just displaces the boss outward over several frames.
func _apply_fire_knockback_step(owner: Object, delta_x: float) -> void:
	if owner == null:
		return
	var boss_rect := _get_boss_rect(owner)
	var boss_pos := boss_rect.position
	var boss_w := boss_rect.size.x
	boss_pos.x = clampf(boss_pos.x + delta_x, 0.0, maxf(0.0, FIELD_WIDTH - boss_w))
	owner.set("boss_pos", boss_pos)


# Post-AI one-sided crossing barrier (mirrors boss_ai_state's molotov barrier):
# the boss may not end the frame on the far side of the zone midline relative to
# the side it entered the frame on (read from boss_pos_prev, set before the boss
# AI moved this frame). Only blocks while the boss shares the zone's y-band, and
# clamps a hair past the midline so the blocked side persists frame to frame.
func _apply_fire_crossing_barrier(owner: Object, registry: Object, zone: Dictionary) -> void:
	if owner == null:
		return
	var center: Vector2 = zone.get("position", Vector2.ZERO)
	var boss_rect := _get_boss_rect(owner)
	var boss_w := boss_rect.size.x
	var half := boss_w * 0.5
	var boss_center_x := boss_rect.get_center().x
	var boss_center_y := boss_rect.get_center().y
	if absf(boss_center_y - center.y) >= FIRE_ZONE_BARRIER_Y_BAND:
		return
	var prev_pos := _get_owner_vector2(owner, "boss_pos_prev", boss_rect.position)
	var prev_center_x := prev_pos.x + half
	var clamped_center := boss_center_x
	if prev_center_x <= center.x:
		clamped_center = minf(boss_center_x, center.x - FIRE_ZONE_BARRIER_SIDE_EPSILON)
	else:
		clamped_center = maxf(boss_center_x, center.x + FIRE_ZONE_BARRIER_SIDE_EPSILON)
	if is_equal_approx(clamped_center, boss_center_x):
		return
	var boss_pos := boss_rect.position
	boss_pos.x = clampf(clamped_center - half, 0.0, maxf(0.0, FIELD_WIDTH - boss_w))
	owner.set("boss_pos", boss_pos)
	owner.set("boss_vel", 0.0)
	# A dash that rammed the patch must actually stop, or it re-rams every frame.
	var ai_state: Object = _get_registry_instance(registry, "boss_ai_state")
	if ai_state != null and ai_state.has_method("cancel_dash_for_fire_block"):
		ai_state.cancel_dash_for_fire_block()


func _apply_boss_slow(registry: Object) -> void:
	var status_state: Object = _get_registry_instance(registry, "status_effect_state")
	if status_state == null or not status_state.has_method("apply_status"):
		return
	status_state.apply_status(
		"boss",
		"slow",
		SLOW_REFRESH_FRAMES,
		LingpetDragonBreathPayloadFactory.build_boss_slow_status_data(SLOW_MULTIPLIER),
		STATUS_SOURCE
	)


func _clear_boss_slow(registry: Object) -> void:
	var status_state: Object = _get_registry_instance(registry, "status_effect_state")
	if status_state != null and status_state.has_method("clear_status"):
		status_state.clear_status("boss", "slow", STATUS_SOURCE)


func _play_fire_zone_feedback(registry: Object, low_volume: bool = false) -> void:
	var audio: Object = _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_dragon_breath_fire"):
		audio.play_dragon_breath_fire(low_volume)
	elif audio.has_method("play_molotov_explosion"):
		audio.play_molotov_explosion()


func _draw_fire_zones_molotov(canvas: CanvasItem, shake_offset: Vector2) -> void:
	if not _fire_zones.is_empty():
		_ensure_zone_fx_renderer()
		_zone_fx_renderer.draw_molotov_fire_zones(canvas, _build_molotov_zone_payload(), shake_offset, _elapsed)
		_zone_fx_dirty = true
	elif _zone_fx_dirty:
		# Final empty sync so the molotov hosts hide after the last patch ends.
		if _zone_fx_renderer != null:
			_zone_fx_renderer.draw_molotov_fire_zones(canvas, [], shake_offset, _elapsed)
		_zone_fx_dirty = false


# Convert the breath's fire zones into the molotov renderer's zone schema. The
# renderer adds shake_offset itself and only uses life_ratio (= remaining/max),
# so passing seconds-as-"frames" is fine. age_frames stays < 4 on the first
# frame (timer == max_timer) so the host fires its one-shot explosion burst.
func _build_molotov_zone_payload() -> Array:
	var payload: Array = []
	for zone in _fire_zones:
		payload.append(LingpetDragonBreathPayloadFactory.build_molotov_zone_payload(
			zone,
			FIRE_ZONE_WIDTH,
			FIRE_ZONE_HEIGHT,
			FIRE_ZONE_DURATION_SECONDS,
			_convert_zone_flames(zone.get("flames", []))
		))
	return payload


# Convert the breath's per-zone flame sim into the molotov renderer's flame
# schema so the lingpet fire patches get the same busy multi-layer flickering
# flames as the molotov item (not just the shader host).
func _convert_zone_flames(flames: Array) -> Array:
	var out: Array = []
	for flame_value in flames:
		if not (flame_value is Dictionary):
			continue
		var flame: Dictionary = flame_value as Dictionary
		out.append(LingpetDragonBreathPayloadFactory.build_molotov_flame_payload(flame, 8.0, 0.66))
	return out


func _get_boss_rect(owner: Object) -> Rect2:
	var boss_pos: Vector2 = _get_owner_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 25.0))
	var boss_w: float = maxf(1.0, float(_get_owner_value(owner, "boss_paddle_width", 100.0)))
	var boss_h: float = maxf(1.0, float(_get_owner_value(owner, "boss_hitbox_height", 40.0)))
	return Rect2(boss_pos, Vector2(boss_w, boss_h))


func _get_ball_radius(owner: Object) -> float:
	var ball_radius: float = float(_get_owner_value(owner, "ball_radius", 0.0))
	if ball_radius > 0.0:
		return ball_radius
	return maxf(6.0, float(_get_owner_value(owner, "ball_size", 20.0)) * 0.5)


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	return fallback if value == null else value


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_owner_value(owner, key, fallback)
	return value if value is Vector2 else fallback


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance(key)
		if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
			return cached as Object
	if registry.has_method("get_instance"):
		var value: Variant = registry.get_instance(key)
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
	return null
