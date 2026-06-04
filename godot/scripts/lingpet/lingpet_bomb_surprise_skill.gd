extends RefCounted

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const BALL_RADIUS_FALLBACK := 14.3
const FUSE_MIN_SECONDS := 4.0
const FUSE_MAX_SECONDS := 8.0
const VY_GRACE_SECONDS := 0.15
const BOSS_STUN_SECONDS := 3.0
const PLAYER_STUN_SECONDS := 0.8
const BOSS_KNOCKBACK_VELOCITY := 52.0
const PLAYER_KNOCKBACK_SCALE := 0.30
const BOSS_KNOCKBACK_FRAMES := 18.0
const PLAYER_KNOCKBACK_FRAMES := 10.0
const KNOCKBACK_DECAY := 0.85
const EXPLOSION_SECONDS := 0.60
const SELF_EXPLOSION_SECONDS := 0.35
const BOMB_RADIUS := 9.0
const EXPLOSION_RADIUS := 350.0
const SELF_EXPLOSION_RADIUS := 180.0
const PARTICLE_MAX := 96
const TRAIL_MAX_POINTS := 12
const ATTACH_FLIGHT_SPEED := 980.0
const RETURN_FLIGHT_SPEED := 920.0
const ATTACH_ARRIVE_DISTANCE := 8.0
const RETURN_ARRIVE_DISTANCE := 6.0
const STATUS_SOURCE := "volty_bomb_surprise"

const PHASE_IDLE := "idle"
const PHASE_FLY_TO_BALL := "fly_to_ball"
const PHASE_ATTACHED := "attached"
const PHASE_RETURNING := "returning"

const LOCATION_BALL := "ball"
const LOCATION_TOP := "top"
const LOCATION_BOTTOM := "bottom"

var _active := false
var _phase := PHASE_IDLE
var _timer := 0.0
var _fuse_seconds := FUSE_MIN_SECONDS
var _location := LOCATION_BALL
var _last_ball_vy_sign := 0
var _vy_grace_timer := 0.0
var _tick_sound_cd := 0.0
var _tick_toggle := false
var _urgent_tick_playing := false
var _home_pos := Vector2.ZERO
var _body_pos := Vector2.ZERO
var _attached_pos := Vector2.ZERO
var _visual_seed := 0.0
var _explosion_pos := Vector2.ZERO
var _explosion_timer := 0.0
var _explosion_duration := EXPLOSION_SECONDS
var _explosion_radius := EXPLOSION_RADIUS
var _particles: Array = []
var _trail: Array[Vector2] = []
var _explosion_count := 0
var _last_explosion_target := ""
var _last_self_explosion := false
var _last_knockback_velocity := 0.0
var _last_stun_frames := 0.0


func reset() -> void:
	_active = false
	_phase = PHASE_IDLE
	_timer = 0.0
	_fuse_seconds = FUSE_MIN_SECONDS
	_location = LOCATION_BALL
	_last_ball_vy_sign = 0
	_vy_grace_timer = 0.0
	_tick_sound_cd = 0.0
	_tick_toggle = false
	_urgent_tick_playing = false
	_home_pos = Vector2.ZERO
	_body_pos = Vector2.ZERO
	_attached_pos = Vector2.ZERO
	_visual_seed = 0.0
	_explosion_pos = Vector2.ZERO
	_explosion_timer = 0.0
	_explosion_duration = EXPLOSION_SECONDS
	_explosion_radius = EXPLOSION_RADIUS
	_particles.clear()
	_trail.clear()
	_last_explosion_target = ""
	_last_self_explosion = false
	_last_knockback_velocity = 0.0
	_last_stun_frames = 0.0


func prewarm() -> void:
	pass


func launch(origin: Vector2, owner: Object = null, launch_context: Dictionary = {}) -> bool:
	reset()
	_active = true
	_phase = PHASE_FLY_TO_BALL
	_timer = 0.0
	_fuse_seconds = _pick_fuse_seconds(origin, launch_context)
	_location = LOCATION_BALL
	_last_ball_vy_sign = _get_ball_vy_sign(owner)
	_vy_grace_timer = VY_GRACE_SECONDS
	_home_pos = _get_launch_home_pos(origin, launch_context)
	_body_pos = origin
	_attached_pos = _get_owner_vector2(owner, "ball_pos", origin)
	_visual_seed = _seeded_unit(_attached_pos.x + _attached_pos.y, float(_explosion_count) + 17.0)
	return true


func update(delta: float, owner: Object, registry: Object = null) -> void:
	var safe_delta: float = maxf(0.0, delta)
	match _phase:
		PHASE_FLY_TO_BALL:
			_step_flight_to_ball(safe_delta, owner)
		PHASE_ATTACHED:
			_update_attachment(safe_delta, owner, registry)
			_timer += safe_delta
			_update_fuse_audio(safe_delta, registry)
			if _timer >= _fuse_seconds:
				_explode(owner, registry)
		PHASE_RETURNING:
			_step_return(safe_delta)
		_:
			pass
	if _explosion_timer > 0.0:
		_explosion_timer = maxf(0.0, _explosion_timer - safe_delta)
	if not _particles.is_empty():
		_update_particles(safe_delta)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	if not _particles.is_empty():
		_draw_particles(canvas, shake_offset)
	if _explosion_timer > 0.0:
		_draw_explosion(canvas, _explosion_pos + shake_offset)
	if _phase == PHASE_FLY_TO_BALL or _phase == PHASE_RETURNING:
		_draw_travel_trail(canvas, shake_offset)
	if _phase == PHASE_ATTACHED:
		_draw_bomb(canvas, _body_pos + shake_offset)


func has_visible_effects() -> bool:
	return _phase != PHASE_IDLE or _explosion_timer > 0.0 or not _particles.is_empty()


func is_active() -> bool:
	return _phase != PHASE_IDLE


func has_companion_position_override() -> bool:
	return _phase != PHASE_IDLE


func get_companion_position_override(fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if _phase != PHASE_IDLE:
		return _body_pos
	return fallback


func suppresses_companion_body_hit() -> bool:
	return _phase != PHASE_IDLE


func get_explosion_count_for_tests() -> int:
	return _explosion_count


func get_snapshot() -> Dictionary:
	return {
		"bomb_surprise_active": _active,
		"bomb_surprise_phase": _phase,
		"bomb_surprise_companion_override_active": has_companion_position_override(),
		"bomb_surprise_body_pos": _body_pos,
		"bomb_surprise_home_pos": _home_pos,
		"bomb_surprise_attached_active": _phase == PHASE_ATTACHED,
		"bomb_surprise_location": _location,
		"bomb_surprise_timer": _timer,
		"bomb_surprise_fuse_seconds": _fuse_seconds,
		"bomb_surprise_tick_sound_cd": _tick_sound_cd,
		"bomb_surprise_tick_toggle": _tick_toggle,
		"bomb_surprise_urgent_tick_playing": _urgent_tick_playing,
		"bomb_surprise_attached_pos": _attached_pos,
		"bomb_surprise_explosion_active": _explosion_timer > 0.0,
		"bomb_surprise_explosion_pos": _explosion_pos,
		"bomb_surprise_explosion_radius": _explosion_radius,
		"bomb_surprise_explosion_count": _explosion_count,
		"bomb_surprise_last_target": _last_explosion_target,
		"bomb_surprise_last_self_explosion": _last_self_explosion,
		"bomb_surprise_last_knockback_velocity": _last_knockback_velocity,
		"bomb_surprise_last_stun_frames": _last_stun_frames,
		"bomb_surprise_particle_count": _particles.size(),
	}


func _update_attachment(delta: float, owner: Object, registry: Object) -> void:
	var current_sign := _get_ball_vy_sign(owner)
	if _vy_grace_timer > 0.0:
		_vy_grace_timer = maxf(0.0, _vy_grace_timer - delta)
		_last_ball_vy_sign = current_sign
	else:
		if current_sign != 0 and _last_ball_vy_sign != 0 and current_sign != _last_ball_vy_sign:
			var hit_paddle := LOCATION_TOP if current_sign > 0 else LOCATION_BOTTOM
			if _location == LOCATION_BALL:
				_location = hit_paddle
				_play_transfer_feedback(registry)
			elif _location == hit_paddle:
				_location = LOCATION_BALL
				_play_transfer_feedback(registry)
		if current_sign != 0:
			_last_ball_vy_sign = current_sign
	_attached_pos = _get_attached_position(owner)
	_body_pos = _attached_pos
	_trail.clear()


func _step_flight_to_ball(delta: float, owner: Object) -> void:
	_attached_pos = _get_owner_vector2(owner, "ball_pos", _attached_pos)
	_append_trail_point(_body_pos)
	if _move_body_toward(_attached_pos, ATTACH_FLIGHT_SPEED, delta, ATTACH_ARRIVE_DISTANCE):
		_phase = PHASE_ATTACHED
		_active = true
		_timer = 0.0
		_location = LOCATION_BALL
		_body_pos = _attached_pos
		_last_ball_vy_sign = _get_ball_vy_sign(owner)
		_vy_grace_timer = VY_GRACE_SECONDS
		_trail.clear()


func _update_fuse_audio(delta: float, registry: Object) -> void:
	var audio := _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	_tick_sound_cd -= delta
	var fuse_ratio := clampf(_timer / maxf(0.001, _fuse_seconds), 0.0, 1.0)
	var tick_interval := maxf(0.12, 0.7 - fuse_ratio * 0.58)
	if _tick_sound_cd <= 0.0:
		_tick_sound_cd = tick_interval
		if audio.has_method("play_bomb_surprise_tick"):
			audio.play_bomb_surprise_tick(_tick_toggle, fuse_ratio)
		_tick_toggle = not _tick_toggle
	var remaining := _fuse_seconds - _timer
	if remaining <= 0.5 and not _urgent_tick_playing and audio.has_method("play_bomb_surprise_urgent_tick"):
		audio.play_bomb_surprise_urgent_tick()
		_urgent_tick_playing = true


func _step_return(delta: float) -> void:
	_append_trail_point(_body_pos)
	if _move_body_toward(_home_pos, RETURN_FLIGHT_SPEED, delta, RETURN_ARRIVE_DISTANCE):
		_phase = PHASE_IDLE
		_active = false
		_body_pos = _home_pos
		_trail.clear()


func _move_body_toward(target: Vector2, speed: float, delta: float, arrive_distance: float) -> bool:
	var offset := target - _body_pos
	var distance := offset.length()
	if distance <= maxf(0.1, arrive_distance):
		_body_pos = target
		return true
	var step := maxf(0.0, speed) * maxf(0.0, delta)
	if step >= distance:
		_body_pos = target
		return true
	if step > 0.0:
		_body_pos += offset / distance * step
	return false


func _append_trail_point(pos: Vector2) -> void:
	_trail.append(pos)
	while _trail.size() > TRAIL_MAX_POINTS:
		_trail.remove_at(0)


func _explode(owner: Object, registry: Object) -> void:
	_active = false
	_phase = PHASE_RETURNING
	_explosion_pos = _get_attached_position(owner)
	_body_pos = _explosion_pos
	_trail.clear()
	var target := _get_explosion_target(owner)
	var self_explosion := target == LOCATION_BOTTOM
	_last_explosion_target = target
	_last_self_explosion = self_explosion
	_explosion_duration = SELF_EXPLOSION_SECONDS if self_explosion else EXPLOSION_SECONDS
	_explosion_radius = SELF_EXPLOSION_RADIUS if self_explosion else EXPLOSION_RADIUS
	_explosion_timer = _explosion_duration
	_explosion_count += 1
	_apply_explosion_status(owner, registry, target, self_explosion)
	_spawn_explosion_particles(_explosion_pos, self_explosion)
	_play_explosion_feedback(registry, self_explosion)
	_apply_screen_shake(registry, self_explosion)


func _get_explosion_target(owner: Object) -> String:
	if _location == LOCATION_TOP or _location == LOCATION_BOTTOM:
		return _location
	var ball_pos: Vector2 = _get_owner_vector2(owner, "ball_pos", _attached_pos)
	return LOCATION_BOTTOM if ball_pos.y >= FIELD_HEIGHT * 0.5 else LOCATION_TOP


func _apply_explosion_status(owner: Object, registry: Object, target: String, self_explosion: bool) -> void:
	var direction := _get_knockback_direction(owner, target, _explosion_pos)
	var status_state := _get_registry_instance(registry, "status_effect_state")
	if target == LOCATION_TOP:
		var boss_velocity := direction * BOSS_KNOCKBACK_VELOCITY
		_last_knockback_velocity = boss_velocity
		_last_stun_frames = BOSS_STUN_SECONDS * 60.0
		if status_state != null and status_state.has_method("apply_status"):
			status_state.apply_status(
				"boss",
				"stun",
				_last_stun_frames,
				{
					"cleansable": true,
					"visual": STATUS_SOURCE,
					"knockback_vel": boss_velocity,
					"knockback_active": true,
					"knockback_frames": BOSS_KNOCKBACK_FRAMES,
					"knockback_decay_per_frame": KNOCKBACK_DECAY,
				},
				STATUS_SOURCE
			)
	else:
		var player_velocity := direction * BOSS_KNOCKBACK_VELOCITY * PLAYER_KNOCKBACK_SCALE
		_last_knockback_velocity = player_velocity
		_last_stun_frames = PLAYER_STUN_SECONDS * 60.0
		if status_state != null and status_state.has_method("apply_status"):
			status_state.apply_status(
				"player",
				"stun",
				_last_stun_frames,
				{
					"cleansable": true,
					"visual": STATUS_SOURCE,
					"weak_stun": self_explosion,
				},
				STATUS_SOURCE
			)
		var movement_state := _get_registry_instance(registry, "player_movement_state")
		if movement_state != null and movement_state.has_method("start_knockback"):
			movement_state.start_knockback(
				player_velocity,
				PLAYER_KNOCKBACK_FRAMES,
				KNOCKBACK_DECAY,
				true,
				true
			)


func _get_knockback_direction(owner: Object, target: String, origin: Vector2) -> float:
	var target_center_x := FIELD_WIDTH * 0.5
	if target == LOCATION_TOP:
		var boss_rect := _get_boss_rect(owner)
		target_center_x = boss_rect.position.x + boss_rect.size.x * 0.5
	else:
		var player_rect := _get_player_rect(owner)
		target_center_x = player_rect.position.x + player_rect.size.x * 0.5
	var dx := target_center_x - origin.x
	if absf(dx) < 5.0:
		return -1.0 if _seeded_unit(origin.x + origin.y, float(_explosion_count) + 31.0) < 0.5 else 1.0
	return 1.0 if dx > 0.0 else -1.0


func _spawn_explosion_particles(origin: Vector2, self_explosion: bool) -> void:
	var particle_count := 35 if self_explosion else 72
	var speed_min := 120.0 if self_explosion else 220.0
	var speed_max := 360.0 if self_explosion else 720.0
	var life_min := 0.16 if self_explosion else 0.24
	var life_max := 0.40 if self_explosion else 0.62
	for _i in range(particle_count):
		var angle := randf_range(0.0, TAU)
		var speed := randf_range(speed_min, speed_max)
		_add_particle(
			origin + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0)),
			Vector2(cos(angle), sin(angle)) * speed,
			randf_range(life_min, life_max),
			randf_range(2.0, 7.0) if self_explosion else randf_range(3.0, 11.0),
			0 if randf() < 0.72 else 1
		)


func _add_particle(pos: Vector2, vel: Vector2, life: float, size: float, kind: int) -> void:
	if _particles.size() >= PARTICLE_MAX:
		return
	_particles.append({
		"pos": pos,
		"vel": vel,
		"life": maxf(0.01, life),
		"max_life": maxf(0.01, life),
		"size": maxf(0.5, size),
		"kind": kind,
	})


func _update_particles(delta: float) -> void:
	var kept: Array = []
	for particle in _particles:
		var life: float = float(particle["life"]) - delta
		if life <= 0.0:
			continue
		var vel: Vector2 = particle["vel"]
		vel *= 0.84 if int(particle["kind"]) == 0 else 0.78
		vel.y += 95.0 * delta
		particle["vel"] = vel
		particle["pos"] = (particle["pos"] as Vector2) + vel * delta
		particle["life"] = life
		kept.append(particle)
	_particles = kept


func _draw_bomb(canvas: CanvasItem, center: Vector2) -> void:
	var time_seconds := float(Time.get_ticks_msec()) / 1000.0
	var fuse_ratio := clampf(_timer / maxf(0.001, _fuse_seconds), 0.0, 1.0)
	var pulse := 0.90 + 0.10 * sin(time_seconds * lerpf(8.0, 22.0, fuse_ratio) + _visual_seed * TAU)
	var latch_radius := (BOMB_RADIUS + 25.0 + 8.0 * fuse_ratio) * pulse
	canvas.draw_circle(center, latch_radius + 10.0, Color(1.0, 0.18, 0.06, 0.08 + 0.16 * fuse_ratio))
	canvas.draw_arc(center, latch_radius, -0.30 * TAU, 0.34 * TAU, 28, Color(0.98, 0.88, 0.42, 0.74), 2.2, true)
	canvas.draw_arc(center, latch_radius * 0.78, 0.18 * TAU, 0.82 * TAU, 26, Color(0.20, 0.90, 1.0, 0.58 + 0.24 * fuse_ratio), 2.0, true)
	for idx in range(4):
		var angle := TAU * float(idx) / 4.0 + time_seconds * 2.8
		var spark_pos := center + Vector2(cos(angle), sin(angle)) * latch_radius
		canvas.draw_circle(spark_pos, 2.2 + fuse_ratio * 2.8, Color(1.0, 0.30, 0.08, 0.62 + 0.24 * fuse_ratio))
	var fuse_tip := center + Vector2(latch_radius * 0.66, -latch_radius * 0.62)
	canvas.draw_line(center + Vector2(latch_radius * 0.22, -latch_radius * 0.38), fuse_tip, Color(0.95, 0.76, 0.30, 0.78), 2.0, true)
	canvas.draw_circle(fuse_tip, 3.0 + fuse_ratio * 3.4, Color(1.0, 0.30, 0.08, 0.88))


func _draw_travel_trail(canvas: CanvasItem, shake_offset: Vector2) -> void:
	if _trail.is_empty():
		return
	for i in range(_trail.size()):
		var ratio := float(i + 1) / float(maxi(1, _trail.size()))
		var trail_pos := _trail[i] + shake_offset
		var alpha := 0.06 + 0.24 * ratio
		var radius := lerpf(3.0, 13.0, ratio)
		canvas.draw_circle(trail_pos, radius, Color(0.30, 0.92, 1.0, alpha))
		if i > 0:
			var prev_pos := _trail[i - 1] + shake_offset
			canvas.draw_line(prev_pos, trail_pos, Color(1.0, 0.32, 0.92, 0.22 * ratio), maxf(1.0, 4.0 * ratio), true)


func _draw_explosion(canvas: CanvasItem, center: Vector2) -> void:
	var ratio := clampf(_explosion_timer / maxf(0.001, _explosion_duration), 0.0, 1.0)
	var expansion := 1.0 - ratio
	var radius := lerpf(28.0, _explosion_radius, expansion)
	canvas.draw_circle(center, radius * 0.38, Color(1.0, 0.95, 0.72, 0.42 * ratio))
	canvas.draw_circle(center, radius * 0.72, Color(1.0, 0.30, 0.06, 0.18 * ratio))
	canvas.draw_arc(center, radius, 0.0, TAU, 64, Color(1.0, 0.80, 0.22, 0.80 * ratio), 3.0, true)
	canvas.draw_arc(center, radius * 0.62, 0.0, TAU, 48, Color(1.0, 0.98, 0.82, 0.66 * ratio), 2.0, true)
	for idx in range(14):
		var angle := TAU * float(idx) / 14.0 + expansion * 0.36
		var start := center + Vector2(cos(angle), sin(angle)) * radius * 0.22
		var end := center + Vector2(cos(angle), sin(angle)) * radius * lerpf(0.52, 0.94, _seeded_unit(_visual_seed, float(idx) + 71.0))
		canvas.draw_line(start, end, Color(1.0, 0.94, 0.62, 0.45 * ratio), 2.0, true)


func _draw_particles(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for particle in _particles:
		var max_life: float = maxf(0.01, float(particle["max_life"]))
		var life_t := clampf(float(particle["life"]) / max_life, 0.0, 1.0)
		var pos: Vector2 = (particle["pos"] as Vector2) + shake_offset
		var size: float = float(particle["size"]) * (0.6 + life_t * 0.55)
		var color := Color(1.0, 0.48, 0.08, 0.76 * life_t) if int(particle["kind"]) == 0 else Color(0.26, 0.22, 0.24, 0.44 * life_t)
		canvas.draw_circle(pos, size, color)


func _play_explosion_feedback(registry: Object, self_explosion: bool) -> void:
	var audio := _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_bomb_surprise_explosion"):
		audio.play_bomb_surprise_explosion(self_explosion)
	elif audio.has_method("stop_bomb_surprise_urgent_tick"):
		audio.stop_bomb_surprise_urgent_tick()
	if self_explosion and audio.has_method("play_stage3_curse_explode") and not audio.has_method("play_bomb_surprise_explosion"):
		audio.play_stage3_curse_explode()
	elif audio.has_method("play_grenade_explosion") and not audio.has_method("play_bomb_surprise_explosion"):
		audio.play_grenade_explosion()
	elif audio.has_method("play_active_item") and not audio.has_method("play_bomb_surprise_explosion"):
		audio.play_active_item()
	_urgent_tick_playing = false


func _play_transfer_feedback(registry: Object) -> void:
	var audio := _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_bomb_surprise_transfer"):
		audio.play_bomb_surprise_transfer()
	elif audio.has_method("play_spider_mine_setup"):
		audio.play_spider_mine_setup()


func _apply_screen_shake(registry: Object, self_explosion: bool) -> void:
	var feedback := _get_registry_instance(registry, "battle_feedback_state")
	if feedback == null or not feedback.has_method("max_screen_shake"):
		return
	if self_explosion:
		feedback.max_screen_shake(0.035, 0.80)
	else:
		feedback.max_screen_shake(0.080, 1.40)


func _pick_fuse_seconds(origin: Vector2, launch_context: Dictionary) -> float:
	if launch_context.has("fuse_seconds"):
		return clampf(float(launch_context.get("fuse_seconds", FUSE_MIN_SECONDS)), 0.10, FUSE_MAX_SECONDS)
	var roll := _seeded_unit(origin.x + origin.y, float(Time.get_ticks_msec() % 100000) + 11.0)
	return lerpf(FUSE_MIN_SECONDS, FUSE_MAX_SECONDS, roll)


func _get_launch_home_pos(origin: Vector2, launch_context: Dictionary) -> Vector2:
	var companion_pos := _as_vector2(launch_context.get("companion_pos", origin), origin)
	return origin if companion_pos == Vector2.ZERO else companion_pos


func _get_attached_position(owner: Object) -> Vector2:
	match _location:
		LOCATION_TOP:
			return _get_boss_rect(owner).get_center()
		LOCATION_BOTTOM:
			return _get_player_rect(owner).get_center()
		_:
			return _get_owner_vector2(owner, "ball_pos", _attached_pos)


func _get_ball_vy_sign(owner: Object) -> int:
	var ball_vel := _get_owner_vector2(owner, "ball_vel", Vector2.ZERO)
	if ball_vel.y > 0.0:
		return 1
	if ball_vel.y < 0.0:
		return -1
	return 0


func _get_boss_rect(owner: Object) -> Rect2:
	var boss_pos: Vector2 = _get_owner_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 25.0))
	var boss_w: float = maxf(1.0, float(_get_owner_value(owner, "boss_paddle_width", 100.0)))
	var boss_h: float = maxf(1.0, float(_get_owner_value(owner, "boss_hitbox_height", 40.0)))
	return Rect2(boss_pos, Vector2(boss_w, boss_h))


func _get_player_rect(owner: Object) -> Rect2:
	var player_w: float = maxf(1.0, float(_get_owner_value(owner, "player_paddle_width", 155.0)))
	var player_h: float = maxf(1.0, float(_get_owner_value(owner, "player_paddle_height", 50.0)))
	var player_pos: Vector2 = _get_owner_vector2(owner, "player_pos", Vector2(FIELD_WIDTH * 0.5 - player_w * 0.5, FIELD_HEIGHT - player_h))
	return Rect2(player_pos, Vector2(player_w, player_h))


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner != null and owner.get(key) != null:
		return owner.get(key)
	return fallback


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_owner_value(owner, key, fallback)
	return value if value is Vector2 else fallback


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
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


func _seeded_unit(seed_value: float, salt: float) -> float:
	var hashed := sin(seed_value * 9283.33 + salt * 47.77) * 43758.5453
	return hashed - floor(hashed)
