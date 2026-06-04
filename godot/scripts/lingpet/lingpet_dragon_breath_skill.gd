extends RefCounted

# 3-piece modular VFX (texture pieces + WritheEmber shader + textured particles +
# elapsed-driven tween envelopes). The simulation/gameplay below is unchanged;
# only the draw path composites the layered fire look.
const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const DragonBreathTextureCache := preload("res://scripts/lingpet/lingpet_dragon_breath_texture_cache.gd")
const JET_MATERIAL_PRESET := "red_dragon_breath_jet"
const ZONE_MATERIAL_PRESET := "red_dragon_breath_zone"

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const BREATH_DURATION_SECONDS := 3.5
const BREATH_SPAWN_SECONDS := 1.2
const INITIAL_PARTICLES := 40
const CONTINUOUS_PARTICLES := 4
const PARTICLE_MAX := 132
const SPAWN_INTERVAL_SECONDS := 0.02
const HIT_COOLDOWN_SECONDS := 0.30
const BALL_HIT_PADDING := 5.0
const BALL_MIN_SPEED := 10.0
const BALL_SPEED_MULT_MIN := 1.30
const BALL_SPEED_MULT_MAX := 1.50
const BALL_SIDE_KNOCK_MIN := 3.0
const BALL_SIDE_KNOCK_MAX := 6.0
const ANGLE_OFFSET_MAX := 0.30
const FIRE_ZONE_WIDTH := 100.0
const FIRE_ZONE_HEIGHT := 50.0
const FIRE_ZONE_DURATION_SECONDS := 2.0
const FIRE_ZONE_DUPLICATE_X := 60.0
const FIRE_ZONE_DUPLICATE_Y := 40.0
const FIRE_ZONE_SPAWN_INTERVAL_SECONDS := 0.30
const FIRE_ZONE_SPREAD_INTERVAL_SECONDS := 5.0 / 60.0
const FIRE_ZONE_PUSH_INTERVAL_SECONDS := 0.50
const FIRE_ZONE_PUSH_FORCE := 60.0
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
var _zone_material: ShaderMaterial = null
var _additive_material: CanvasItemMaterial = null


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


func prewarm() -> void:
	# Resource prewarm only: the WritheEmber shader PSO is already warmed at boot
	# by the shared inferno / electrocution hosts (same static shader instance),
	# so building the materials + procedural textures here is enough to keep the
	# first breath frame off the hot-path lazy-init trap.
	WritheEmberMaterial.prewarm()
	DragonBreathTextureCache.prewarm()
	ImpactFlareTextureCache.prewarm()
	_ensure_materials()


func _ensure_materials() -> void:
	if _jet_material == null:
		_jet_material = WritheEmberMaterial.build_material(JET_MATERIAL_PRESET)
	if _zone_material == null:
		_zone_material = WritheEmberMaterial.build_material(ZONE_MATERIAL_PRESET)
	if _additive_material == null:
		_additive_material = CanvasItemMaterial.new()
		_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


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
	if canvas == null or not has_visible_effects():
		return
	_ensure_materials()
	var time_sec := float(Time.get_ticks_msec()) / 1000.0
	# Layer 1 - shader backplate (depth/mood): lingering burning-floor patches.
	_draw_fire_zone_backplates(canvas, shake_offset, time_sec)
	# Layer 2 - shader backplate: the active breath jet pouring from the mouth.
	_draw_breath_jet(canvas, shake_offset, time_sec)
	# Layer 3 - additive textured detail (dynamic ②/③): zone flames, embers,
	# trails, sparks, hit flash. One additive context so the layer batches.
	var prev_material: Material = canvas.material
	canvas.material = _additive_material
	for zone in _fire_zones:
		_draw_zone_flames_textured(canvas, zone, shake_offset)
	_draw_breath_muzzle(canvas, shake_offset, time_sec)
	for particle in _particles:
		_draw_breath_particle(canvas, particle, shake_offset)
	if _hit_flash_timer > 0.0:
		_draw_hit_flash(canvas, _last_hit_pos + shake_offset, _hit_flash_timer / 0.24)
	canvas.material = prev_material


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
	var delay := index_ratio * 0.3 if initial else 0.0
	var life := randf_range(1.0, 1.8) if initial else randf_range(0.6, 1.2)
	var size := randf_range(10.0, 25.0) if initial else randf_range(8.0, 18.0)
	var start_y_offset := 20.0 if initial else 25.0
	var speed_min := 350.0 if initial else 400.0
	var speed_max := 600.0 if initial else 550.0
	var vx_range := 50.0 if initial else 40.0
	_particles.append({
		"pos": _origin + Vector2(randf_range(-25.0, 25.0), _direction * start_y_offset),
		"vel": Vector2(randf_range(-vx_range, vx_range), _direction * randf_range(speed_min, speed_max)),
		"life": life + delay,
		"max_life": maxf(0.01, life),
		"size": size,
		"max_size": size,
		"phase": randf(),
		"wob": randf(),
		"delay": delay,
		"zone_reported": false,
	})


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

	var ball_vel: Vector2 = _get_owner_vector2(owner, "ball_vel", Vector2.ZERO)
	var current_speed := ball_vel.length()
	if current_speed < 8.0:
		current_speed = BALL_MIN_SPEED
	var boosted_speed := current_speed * randf_range(BALL_SPEED_MULT_MIN, BALL_SPEED_MULT_MAX)
	var angle_offset := randf_range(-ANGLE_OFFSET_MAX, ANGLE_OFFSET_MAX)
	var next_vel := Vector2.ZERO
	next_vel.y = _direction * absf(boosted_speed * cos(angle_offset))
	var dx := ball_pos.x - pos.x
	var knockback_dir := 1.0 if dx >= 0.0 else -1.0
	if absf(dx) <= 1.0:
		knockback_dir = -1.0 if randf() < 0.5 else 1.0
	next_vel.x = knockback_dir * randf_range(BALL_SIDE_KNOCK_MIN, BALL_SIDE_KNOCK_MAX) + boosted_speed * sin(angle_offset)
	owner.set("ball_vel", next_vel)
	_hit_cooldown = HIT_COOLDOWN_SECONDS
	_hit_flash_timer = 0.24
	_last_hit_pos = ball_pos
	_ball_hit_count += 1


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
	var zone := {
		"position": center,
		"width": FIRE_ZONE_WIDTH,
		"height": FIRE_ZONE_HEIGHT,
		"timer": FIRE_ZONE_DURATION_SECONDS,
		"max_timer": FIRE_ZONE_DURATION_SECONDS,
		"spread_timer": 0.0,
		"push_timer": FIRE_ZONE_PUSH_INTERVAL_SECONDS,
		"flames": [],
		"boss_in_fire": false,
		"last_push_dir": 0.0,
	}
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
	var in_fire := _is_boss_touching_zone(owner, zone)
	zone["boss_in_fire"] = in_fire
	if not in_fire:
		return
	_apply_boss_slow(registry)
	var push_timer := float(zone.get("push_timer", 0.0)) + delta
	if push_timer >= FIRE_ZONE_PUSH_INTERVAL_SECONDS:
		push_timer = fmod(push_timer, FIRE_ZONE_PUSH_INTERVAL_SECONDS)
		_push_boss_from_fire(owner, registry, zone)
	zone["push_timer"] = push_timer


func _seed_zone_flames(zone: Dictionary, count: int, spread_x: float, spread_y: float) -> void:
	var flames: Array = zone.get("flames", [])
	var center: Vector2 = zone.get("position", Vector2.ZERO)
	for _i in range(count):
		flames.append({
			"pos": center + Vector2(randf_range(-spread_x, spread_x), randf_range(-spread_y, spread_y)),
			"size": randf_range(8.0, 20.0),
			"life": randf_range(0.33, 0.66),
			"max_life": 0.66,
			"phase": randf(),
		})
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
	var x_in_range := absf(boss_rect.get_center().x - center.x) < (width * 0.25 + boss_rect.size.x * 0.5)
	var y_in_range := absf(boss_rect.get_center().y - center.y) < 60.0
	return x_in_range and y_in_range


func _push_boss_from_fire(owner: Object, registry: Object, zone: Dictionary) -> void:
	if owner == null:
		return
	var boss_rect := _get_boss_rect(owner)
	var boss_pos := boss_rect.position
	var center: Vector2 = zone.get("position", Vector2.ZERO)
	var push_dir := -1.0 if boss_rect.get_center().x < center.x else 1.0
	if absf(boss_rect.get_center().x - center.x) <= 0.001:
		push_dir = float(zone.get("last_push_dir", _last_push_dir))
		if absf(push_dir) <= 0.001:
			push_dir = 1.0
	zone["last_push_dir"] = push_dir
	_last_push_dir = push_dir
	boss_pos.x = clampf(boss_pos.x + push_dir * FIRE_ZONE_PUSH_FORCE, 0.0, maxf(0.0, FIELD_WIDTH - boss_rect.size.x))
	owner.set("boss_pos", boss_pos)
	owner.set("boss_vel", push_dir * FIRE_ZONE_PUSH_FORCE * 0.22)
	var feedback: Object = _get_registry_instance(registry, "battle_feedback_state")
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(0.035, 1.1)


func _apply_boss_slow(registry: Object) -> void:
	var status_state: Object = _get_registry_instance(registry, "status_effect_state")
	if status_state == null or not status_state.has_method("apply_status"):
		return
	status_state.apply_status(
		"boss",
		"slow",
		SLOW_REFRESH_FRAMES,
		{
			"multiplier": SLOW_MULTIPLIER,
			"cleansable": true,
			"visual": "red_dragon_dragon_breath",
			"suppress_legacy_boss_ai_slow": true,
		},
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


func _draw_fire_zone_backplates(canvas: CanvasItem, shake_offset: Vector2, time_sec: float) -> void:
	if _fire_zones.is_empty() or _zone_material == null:
		return
	var glow: Texture2D = ImpactFlareTextureCache.get_glow_texture()
	if glow == null:
		return
	# One WritheEmber context for every patch: per-zone life folds into the
	# modulate alpha so the whole burning-floor layer batches in a single bind.
	_zone_material.set_shader_parameter("elapsed", time_sec)
	_zone_material.set_shader_parameter("intensity", 1.0)
	var prev_material: Material = canvas.material
	canvas.material = _zone_material
	for zone in _fire_zones:
		var center: Vector2 = zone.get("position", Vector2.ZERO) + shake_offset
		var width := float(zone.get("width", FIRE_ZONE_WIDTH))
		var height := float(zone.get("height", FIRE_ZONE_HEIGHT))
		var env := _zone_envelope(zone)
		if env <= 0.01:
			continue
		var life_ratio := clampf(float(zone.get("timer", 0.0)) / maxf(0.01, float(zone.get("max_timer", FIRE_ZONE_DURATION_SECONDS))), 0.0, 1.0)
		var w := width * 1.4
		var h := height * 1.55
		var rect := Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h))
		# Warm modulate so the white glow piece colorizes to burning-floor fire
		# under the WritheEmber shader (the shader only tints ~50% on its own).
		var a := 0.7 * env * (0.65 + 0.35 * life_ratio)
		canvas.draw_texture_rect(glow, rect, false, Color(1.0, 0.46, 0.13, a))
	canvas.material = prev_material


func _draw_breath_jet(canvas: CanvasItem, shake_offset: Vector2, time_sec: float) -> void:
	if _jet_material == null:
		return
	var env := _jet_envelope()
	if env <= 0.01:
		return
	var tex: Texture2D = DragonBreathTextureCache.get_flame_tongue_texture()
	if tex == null:
		return
	var pulse := 0.86 + 0.14 * sin(time_sec * 11.0)
	var up := Vector2(0.0, _direction)
	var origin := _origin + shake_offset
	var jet_len := lerpf(90.0, 230.0, env) * pulse
	var outer_w := lerpf(46.0, 86.0, env)
	_jet_material.set_shader_parameter("elapsed", time_sec)
	_jet_material.set_shader_parameter("intensity", 1.0 + 0.6 * env)
	var prev_material: Material = canvas.material
	canvas.material = _jet_material
	# Warm modulate is required: the WritheEmber shader only tints ~50% toward
	# the preset, so a plain-white piece reads washed-out. The deep-orange outer
	# pour + a hotter, narrower inner core give the fiery breath body.
	_draw_flame_tongue(canvas, tex, origin + up * (jet_len * 0.5), up, outer_w, jet_len * 0.5, Color(1.0, 0.50, 0.15, 0.62 * env))
	var inner_len := jet_len * 0.7
	_draw_flame_tongue(canvas, tex, origin + up * (inner_len * 0.5), up, outer_w * 0.55, inner_len * 0.5, Color(1.0, 0.82, 0.46, 0.7 * env))
	canvas.material = prev_material


func _jet_envelope() -> float:
	# Tween envelope: ease the pour in over 0.18s, hold, ease out as the spawn
	# (mouth pour) phase closes -- the flying embers carry the look afterward.
	if not _breath_active or _elapsed >= BREATH_SPAWN_SECONDS + 0.25:
		return 0.0
	var jet_in := _ease_out(clampf(_elapsed / 0.18, 0.0, 1.0))
	var jet_out := 1.0 - _ease_out(clampf((_elapsed - (BREATH_SPAWN_SECONDS - 0.30)) / 0.55, 0.0, 1.0))
	return jet_in * clampf(jet_out, 0.0, 1.0)


# Bright warm glow anchored at the dragon's mouth while the breath pours. Drawn
# in the additive layer (not the shader pass) so it stacks as light.
func _draw_breath_muzzle(canvas: CanvasItem, shake_offset: Vector2, time_sec: float) -> void:
	var env := _jet_envelope()
	if env <= 0.01:
		return
	var ember: Texture2D = DragonBreathTextureCache.get_ember_texture()
	if ember == null:
		return
	var origin := _origin + shake_offset
	var up := Vector2(0.0, _direction)
	var pulse := 0.85 + 0.15 * sin(time_sec * 17.0)
	# Stretched vertical root glow so the base reads as a thick fire column
	# feeding the cloud, not a thin stalk.
	var root_len := 150.0 * env * pulse
	_draw_flame_tongue(canvas, DragonBreathTextureCache.get_flame_tongue_texture(), origin + up * (root_len * 0.5), up, 46.0 * env, root_len * 0.5, Color(1.0, 0.52, 0.18, 0.4 * env))
	_draw_centered_tex(canvas, ember, origin, 124.0 * env * pulse, Color(1.0, 0.46, 0.14, 0.4 * env))
	_draw_centered_tex(canvas, ember, origin, 72.0 * env * pulse, Color(1.0, 0.72, 0.32, 0.5 * env))
	_draw_centered_tex(canvas, ember, origin, 34.0 * env * pulse, Color(1.0, 0.96, 0.82, 0.62 * env))


func _draw_zone_flames_textured(canvas: CanvasItem, zone: Dictionary, shake_offset: Vector2) -> void:
	var flames: Array = zone.get("flames", [])
	if flames.is_empty():
		return
	var env := _zone_envelope(zone)
	if env <= 0.01:
		return
	var tongue: Texture2D = DragonBreathTextureCache.get_flame_tongue_texture()
	var ember: Texture2D = DragonBreathTextureCache.get_ember_texture()
	var up := Vector2(0.0, -1.0)  # ground flames always lick upward
	for flame_value in flames:
		if not (flame_value is Dictionary):
			continue
		var flame: Dictionary = flame_value as Dictionary
		var pos: Vector2 = flame.get("pos", Vector2.ZERO) + shake_offset
		var size := float(flame.get("size", 0.0))
		if size <= 2.0:
			continue
		var max_life := maxf(0.01, float(flame.get("max_life", 0.66)))
		var life_ratio := clampf(float(flame.get("life", 0.0)) / max_life, 0.0, 1.0)
		var phase := float(flame.get("phase", 0.0))
		var heat := clampf(0.30 + 0.70 * life_ratio, 0.0, 1.0)
		var a := env * (0.35 + 0.55 * life_ratio)
		_draw_centered_tex(canvas, ember, pos, size * 2.2, _tint(heat * 0.75, a * 0.5))
		# Rounder, softer ground flame (lower aspect + per-flame tilt) so the
		# patch reads as a soft burning floor, not standing spikes.
		var sway: float = sin(phase * 3.7) * 0.35 + sin(phase * 9.0) * 0.12
		var lick: Vector2 = up.rotated(sway)
		_draw_flame_tongue(canvas, tongue, pos - up * size * 0.3, lick, size * 0.85, size * 1.25, _tint(heat, a * 0.9))
		_draw_centered_tex(canvas, ember, pos, size * 0.85, Color(1.0, 0.9, 0.66, a * 0.45))


func _draw_breath_particle(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2) -> void:
	if float(particle.get("delay", 0.0)) > 0.0:
		return
	var pos: Vector2 = particle.get("pos", Vector2.ZERO) + shake_offset
	var size := float(particle.get("size", 0.0))
	if size <= 2.0:
		return
	var max_life := maxf(0.01, float(particle.get("max_life", 1.0)))
	var life := float(particle.get("life", 0.0))
	var life_ratio := _particle_life_ratio(life, max_life)
	if life_ratio <= 0.02:
		return
	var phase := float(particle.get("phase", 0.0))
	# Birth-pop tween: quick scale-up over the first 14% of the particle's life.
	var age := 1.0 - clampf(life / max_life, 0.0, 1.0)
	var pop := _ease_out(clampf(age / 0.14, 0.0, 1.0))
	var draw_size := size * lerpf(0.5, 1.0, pop)
	var heat := clampf(0.30 + 0.70 * life_ratio, 0.0, 1.0)
	var ember: Texture2D = DragonBreathTextureCache.get_ember_texture()
	# Soft round billowing glow dominates the read so the mass looks like fire,
	# not a field of parallel spikes. Two stacked auras (wide soft + tighter mid)
	# fill the gaps between fast particles into a continuous burning cloud.
	_draw_centered_tex(canvas, ember, pos, draw_size * 4.6, _tint(heat * 0.60, 0.20 * life_ratio))
	_draw_centered_tex(canvas, ember, pos, draw_size * 2.7, _tint(heat * 0.85, 0.40 * life_ratio))
	# Soft flame tongue as a HIGHLIGHT on the glow (rounder ~1.25:1 aspect, lower
	# alpha). Each flame licks upward with a persistent per-particle tilt + slow
	# sway so they fan out turbulently instead of aligning into parallel thorns.
	var wob: float = float(particle.get("wob", 0.5))
	var lick_angle: float = (wob - 0.5) * 0.95 + sin(phase * 2.3 + wob * TAU) * 0.22
	var lick: Vector2 = Vector2(0.0, _direction).rotated(lick_angle)
	var tongue: Texture2D = DragonBreathTextureCache.get_flame_tongue_texture()
	_draw_flame_tongue(canvas, tongue, pos, lick, draw_size * 1.2, draw_size * 1.5, _tint(minf(heat, 0.80), 0.46 * life_ratio))
	# Warm round core (not a sharp white spark).
	_draw_centered_tex(canvas, ember, pos, draw_size * 1.05, Color(1.0, 0.82, 0.50, 0.42 * life_ratio))
	# Rare soft warm mote (no harsh white -- avoids the sparkler read).
	if randf() < 0.05 * life_ratio:
		_draw_centered_tex(canvas, ember, pos + Vector2(randf_range(-size, size), randf_range(-size, size)), randf_range(2.5, 4.0), Color(1.0, 0.86, 0.56, 0.6))


func _draw_hit_flash(canvas: CanvasItem, center: Vector2, ratio: float) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	if clamped <= 0.01:
		return
	var burst: Texture2D = ImpactFlareTextureCache.get_burst_texture()
	var ember: Texture2D = DragonBreathTextureCache.get_ember_texture()
	# Expanding burst as it fades (matches the original ring's growth feel).
	var radius := lerpf(54.0, 16.0, clamped)
	_draw_centered_tex(canvas, ember, center, radius * 1.2, Color(1.0, 0.55, 0.16, 0.34 * clamped))
	_draw_centered_tex(canvas, burst, center, radius * 2.2, Color(1.0, 0.82, 0.40, 0.5 * clamped))
	_draw_centered_tex(canvas, ember, center, radius * 0.7, Color(1.0, 0.96, 0.82, 0.6 * clamped))


func _draw_flame_tongue(canvas: CanvasItem, tex: Texture2D, center: Vector2, up: Vector2, half_w: float, half_h: float, color: Color) -> void:
	if tex == null or half_w <= 0.0 or half_h <= 0.0:
		return
	var right := Vector2(-up.y, up.x)
	var tip := up * half_h
	var base := -up * half_h
	var rw := right * half_w
	var pts := PackedVector2Array([
		center + tip - rw,
		center + tip + rw,
		center + base + rw,
		center + base - rw,
	])
	var uvs := PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])
	canvas.draw_colored_polygon(pts, color, uvs, tex)


func _draw_centered_tex(canvas: CanvasItem, tex: Texture2D, center: Vector2, size_px: float, color: Color) -> void:
	if tex == null or size_px <= 0.0 or color.a <= 0.0:
		return
	var s := Vector2(size_px, size_px)
	canvas.draw_texture_rect(tex, Rect2(center - s * 0.5, s), false, color)


func _zone_envelope(zone: Dictionary) -> float:
	var timer := float(zone.get("timer", 0.0))
	var max_timer := maxf(0.01, float(zone.get("max_timer", FIRE_ZONE_DURATION_SECONDS)))
	var appear := clampf((max_timer - timer) / 0.18, 0.0, 1.0)
	var fade := clampf(timer / 0.4, 0.0, 1.0)
	return appear * fade


func _particle_life_ratio(life: float, max_life: float) -> float:
	var fade_start := max_life * 0.4
	if life > fade_start:
		return 1.0
	if life > 0.0:
		var t := life / fade_start
		var smooth_t := t * t * (3.0 - 2.0 * t)
		return 0.3 + 0.7 * smooth_t
	var tail := clampf((life + 0.5) / 0.5, 0.0, 1.0)
	return 0.3 * tail * tail


func _tint(heat: float, alpha: float) -> Color:
	var c := _heat_color(heat)
	c.a = clampf(alpha, 0.0, 1.0)
	return c


func _heat_color(heat: float) -> Color:
	# Stays in the orange/red fire family; the top end lands at warm gold rather
	# than pure white so additive stacking glows hot without going sparkler-white.
	var h := clampf(heat, 0.0, 1.0)
	if h < 0.5:
		var t := h / 0.5
		return Color(1.0, lerpf(0.18, 0.48, t), lerpf(0.03, 0.11, t))
	var t2 := (h - 0.5) / 0.5
	return Color(1.0, lerpf(0.48, 0.84, t2), lerpf(0.11, 0.46, t2))


func _ease_out(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - c, 3.0)


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
