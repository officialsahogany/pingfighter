extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const CommandoFirearmHitGeometry := preload("res://scripts/characters/commando_firearm_hit_geometry.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const LingpetGatlingBurstPayloadFactory := preload("res://scripts/lingpet/lingpet_gatling_burst_payload_factory.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const MOUNT_DURATION_SECONDS := 1.0
const FIRE_DURATION_SECONDS := 3.0
const DISMOUNT_DURATION_SECONDS := 1.0
const BULLET_SPEED := 620.0
const FIRE_RATE_SECONDS := 0.067
const BULLET_LENGTH := 8.0
const BULLET_WIDTH := 3.0
const AK47_STUN_FRAMES := 12.0
const AK47_KNOCKBACK_POWER := CommandoFirearmRuntime.AK47_BOSS_KNOCKBACK_POWER
const AK47_KNOCKBACK_VELOCITY_SCALE := CommandoFirearmRuntime.AK47_BOSS_KNOCKBACK_VELOCITY_SCALE
const AK47_KNOCKBACK_FRAMES := CommandoFirearmRuntime.AK47_BOSS_KNOCKBACK_FRAMES
const AK47_KNOCKBACK_DECAY := CommandoFirearmRuntime.AK47_BOSS_KNOCKBACK_DECAY_PER_FRAME
const AK47_FRAME_VELOCITY_SCALE := 1.0 / 60.0
const SPREAD_ANGLE_DEGREES := 10.0
const MUZZLE_FLASH_SECONDS := 0.08
const TRAIL_STEPS := 5
const TRAIL_STEP_SECONDS := 0.012
const BULLET_MAX_AGE_SECONDS := 2.0
const PARTICLE_MAX := 96
const TRANSFORM_SHEET_PATH := "res://assets/sprites/lingpet/volty_gatling_tank_transform.png"
const TRANSFORM_FRAME_COUNT := 25
const TRANSFORM_COLUMNS := 5
const TRANSFORM_CHASSIS_FRAME_INDEX := 11
const TANK_SOURCE_DRAW_SIZE := 118.0
const TANK_DRAW_SIZE := 96.0
const TANK_VISUAL_SCALE := TANK_DRAW_SIZE / TANK_SOURCE_DRAW_SIZE
const CANNON_LENGTH := 42.0 * TANK_VISUAL_SCALE
const CANNON_MOUNT_PROGRESS_START := 0.45
const STATUS_SOURCE := "volty_gatling_burst"
const AK47_HIT_PROFILE := {
	"knockback_power": AK47_KNOCKBACK_POWER,
	"knockback_velocity_scale": AK47_KNOCKBACK_VELOCITY_SCALE,
}

const PHASE_IDLE := "idle"
const PHASE_MOUNTING := "mounting"
const PHASE_FIRING := "firing"
const PHASE_DISMOUNTING := "dismounting"

var _phase := PHASE_IDLE
var _phase_timer := 0.0
var _body_pos := Vector2.ZERO
var _home_pos := Vector2.ZERO
var _aim_angle := -PI * 0.5
var _fire_timer := 0.0
var _recoil_offset := 0.0
var _muzzle_flash_timer := 0.0
var _visual_seed := 0.0
var _bullets: Array[Dictionary] = []
var _hit_particles: Array[Dictionary] = []
var _shell_casings: Array[Dictionary] = []
var _smoke_puffs: Array[Dictionary] = []
var _shot_count := 0
var _hit_count := 0
var _last_knockback_velocity := 0.0
var _last_stun_frames := 0.0
var _loop_playing := false
var _textures_prewarmed := false
var _transform_texture: Texture2D = null
var _registry: Object = null


func reset() -> void:
	if _loop_playing:
		_sync_gatling_loop(_registry, false)
	_phase = PHASE_IDLE
	_phase_timer = 0.0
	_body_pos = Vector2.ZERO
	_home_pos = Vector2.ZERO
	_aim_angle = -PI * 0.5
	_fire_timer = 0.0
	_recoil_offset = 0.0
	_muzzle_flash_timer = 0.0
	_visual_seed = 0.0
	_bullets.clear()
	_hit_particles.clear()
	_shell_casings.clear()
	_smoke_puffs.clear()
	_last_knockback_velocity = 0.0
	_last_stun_frames = 0.0
	_loop_playing = false
	_registry = null


func prewarm() -> void:
	if _textures_prewarmed:
		return
	_transform_texture = ProjectResourceLoader.load_texture(TRANSFORM_SHEET_PATH)
	if _transform_texture != null:
		_transform_texture.get_size()
	_textures_prewarmed = true


func launch(origin: Vector2, owner: Object = null, launch_context: Dictionary = {}) -> bool:
	var launch_registry: Object = launch_context.get("registry", null) as Object
	reset()
	prewarm()
	_registry = launch_registry
	_phase = PHASE_MOUNTING
	_phase_timer = 0.0
	_fire_timer = 0.0
	_body_pos = _get_launch_home_pos(origin, launch_context)
	_home_pos = _body_pos
	_aim_angle = _get_aim_angle(owner, _body_pos)
	_visual_seed = _seeded_unit(_body_pos.x + _body_pos.y, float(_shot_count + _hit_count) + 19.0)
	_play_transform_feedback(_registry)
	_trigger_feedback_shake(_registry, 2.0, 0.08)
	return true


func update(delta: float, owner: Object, registry: Object = null) -> void:
	if registry != null:
		_registry = registry
	var safe_delta := maxf(0.0, delta)
	if _phase != PHASE_IDLE:
		_aim_angle = _get_aim_angle(owner, _body_pos)
		_phase_timer += safe_delta
		match _phase:
			PHASE_MOUNTING:
				_update_mounting(owner, registry)
			PHASE_FIRING:
				_update_firing(safe_delta, owner, registry)
			PHASE_DISMOUNTING:
				_update_dismounting(registry)
			_:
				pass
	_update_bullets(safe_delta, owner, registry)
	_update_particles(safe_delta)
	_muzzle_flash_timer = maxf(0.0, _muzzle_flash_timer - safe_delta)
	_recoil_offset = maxf(0.0, _recoil_offset - safe_delta * 35.0)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	_draw_smoke(canvas, shake_offset)
	_draw_bullets(canvas, shake_offset)
	_draw_hit_particles(canvas, shake_offset)
	_draw_shell_casings(canvas, shake_offset)
	if _phase != PHASE_IDLE:
		_draw_tank_body(canvas, shake_offset)


func has_visible_effects() -> bool:
	return (
		_phase != PHASE_IDLE
		or not _bullets.is_empty()
		or not _hit_particles.is_empty()
		or not _shell_casings.is_empty()
		or not _smoke_puffs.is_empty()
		or _muzzle_flash_timer > 0.0
	)


func is_active() -> bool:
	return _phase != PHASE_IDLE


func has_companion_position_override() -> bool:
	return _phase != PHASE_IDLE


func get_companion_position_override(fallback: Vector2 = Vector2.ZERO) -> Vector2:
	return _body_pos if _phase != PHASE_IDLE else fallback


func suppresses_companion_body_hit() -> bool:
	return _phase != PHASE_IDLE


func suppresses_companion_body_draw() -> bool:
	return _phase != PHASE_IDLE


func get_shot_count_for_tests() -> int:
	return _shot_count


func get_hit_count_for_tests() -> int:
	return _hit_count


func get_bullet_count_for_tests() -> int:
	return _bullets.size()


func get_snapshot() -> Dictionary:
	return {
		"gatling_burst_active": _phase != PHASE_IDLE,
		"gatling_burst_phase": _phase,
		"gatling_burst_mount_progress": _get_mount_progress(),
		"gatling_burst_dismount_progress": _get_dismount_progress(),
		"gatling_burst_firing": _phase == PHASE_FIRING,
		"gatling_burst_body_pos": _body_pos,
		"gatling_burst_home_pos": _home_pos,
		"gatling_burst_aim_angle": _aim_angle,
		"gatling_burst_transform_frame_index": _get_transform_frame_index(),
		"gatling_burst_transform_chassis_frame_index": TRANSFORM_CHASSIS_FRAME_INDEX,
		"gatling_burst_tank_draw_size": TANK_DRAW_SIZE,
		"gatling_burst_tank_visual_scale": TANK_VISUAL_SCALE,
		"gatling_burst_recoil": _recoil_offset,
		"gatling_burst_bullet_count": _bullets.size(),
		"gatling_burst_particle_count": _hit_particles.size() + _smoke_puffs.size() + _shell_casings.size(),
		"gatling_burst_shot_count": _shot_count,
		"gatling_burst_hit_count": _hit_count,
		"gatling_burst_last_knockback_velocity": _last_knockback_velocity,
		"gatling_burst_last_stun_frames": _last_stun_frames,
		"gatling_burst_loop_playing": _loop_playing,
	}


func _update_mounting(_owner: Object, registry: Object) -> void:
	if _phase_timer < MOUNT_DURATION_SECONDS:
		return
	_phase = PHASE_FIRING
	_phase_timer = 0.0
	_fire_timer = 0.0
	_sync_gatling_loop(registry, true)
	_trigger_feedback_shake(registry, 3.0, 0.15)


func _update_firing(delta: float, owner: Object, registry: Object) -> void:
	_fire_timer += delta
	while _fire_timer >= FIRE_RATE_SECONDS:
		_fire_timer -= FIRE_RATE_SECONDS
		_fire_bullet(owner, registry)
	if _phase_timer < FIRE_DURATION_SECONDS:
		return
	_phase = PHASE_DISMOUNTING
	_phase_timer = 0.0
	_recoil_offset = 0.0
	_sync_gatling_loop(registry, false)
	_play_transform_feedback(registry)


func _update_dismounting(_unused_registry: Object) -> void:
	if _phase_timer >= DISMOUNT_DURATION_SECONDS:
		_phase = PHASE_IDLE
		_phase_timer = 0.0


func _fire_bullet(owner: Object, registry: Object) -> void:
	var muzzle_pos := _get_muzzle_pos()
	var target := _get_boss_center(owner)
	var base_angle := atan2(target.y - muzzle_pos.y, target.x - muzzle_pos.x)
	var burst_spread := minf(SPREAD_ANGLE_DEGREES * 1.5, SPREAD_ANGLE_DEGREES * (1.0 + float(_shot_count) * 0.02))
	var spread := deg_to_rad(randf_range(-burst_spread, burst_spread))
	var final_angle := base_angle + spread
	var direction := Vector2(cos(final_angle), sin(final_angle))
	_bullets.append(LingpetGatlingBurstPayloadFactory.build_bullet(muzzle_pos, direction, BULLET_SPEED, final_angle, _shot_count))
	while _bullets.size() > 72:
		_bullets.remove_at(0)
	_shot_count += 1
	_recoil_offset = 3.5
	_muzzle_flash_timer = MUZZLE_FLASH_SECONDS
	_spawn_shell_casing(muzzle_pos, direction)
	_spawn_muzzle_smoke(muzzle_pos, direction)
	if (_shot_count % 3) == 1:
		_play_fire_feedback(registry)


func _update_bullets(delta: float, owner: Object, registry: Object) -> void:
	if _bullets.is_empty():
		return
	var boss_rect := _get_boss_rect(owner)
	var next_bullets: Array[Dictionary] = []
	for bullet in _bullets:
		var pos: Vector2 = _as_vector2(bullet.get("pos", Vector2.ZERO), Vector2.ZERO)
		var vel: Vector2 = _as_vector2(bullet.get("vel", Vector2.ZERO), Vector2.ZERO)
		var age := float(bullet.get("age", 0.0)) + delta
		pos += vel * delta
		if age > BULLET_MAX_AGE_SECONDS:
			continue
		if pos.x < -20.0 or pos.x > FIELD_WIDTH + 20.0 or pos.y < -20.0 or pos.y > FIELD_HEIGHT + 20.0:
			continue
		if _bullet_hits_boss(pos, boss_rect):
			_apply_boss_ak47_hit_status(owner, registry, pos, vel, boss_rect)
			_spawn_hit_particles(pos, float(bullet.get("angle", 0.0)))
			_play_hit_feedback(registry)
			_hit_count += 1
			continue
		bullet["pos"] = pos
		bullet["age"] = age
		next_bullets.append(bullet)
	_bullets = next_bullets


func _update_particles(delta: float) -> void:
	if not _hit_particles.is_empty():
		var next_hit: Array[Dictionary] = []
		for particle in _hit_particles:
			var age := float(particle.get("age", 0.0)) + delta
			var life := float(particle.get("life", 0.2))
			if age >= life:
				continue
			var pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO)
			var vel: Vector2 = _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO)
			pos += vel * delta
			vel.y += 200.0 * delta
			particle["age"] = age
			particle["pos"] = pos
			particle["vel"] = vel
			next_hit.append(particle)
		_hit_particles = next_hit
	if not _shell_casings.is_empty():
		var next_casings: Array[Dictionary] = []
		for casing in _shell_casings:
			var age := float(casing.get("age", 0.0)) + delta
			var life := float(casing.get("life", 0.5))
			if age >= life:
				continue
			var pos: Vector2 = _as_vector2(casing.get("pos", Vector2.ZERO), Vector2.ZERO)
			var vel: Vector2 = _as_vector2(casing.get("vel", Vector2.ZERO), Vector2.ZERO)
			pos += vel * delta
			vel.y += float(casing.get("gravity", 500.0)) * delta
			vel.x *= 0.97
			casing["age"] = age
			casing["pos"] = pos
			casing["vel"] = vel
			casing["rotation"] = float(casing.get("rotation", 0.0)) + float(casing.get("rot_speed", 0.0)) * delta
			next_casings.append(casing)
		_shell_casings = next_casings
	if not _smoke_puffs.is_empty():
		var next_smoke: Array[Dictionary] = []
		for smoke in _smoke_puffs:
			var age := float(smoke.get("age", 0.0)) + delta
			var life := float(smoke.get("life", 0.25))
			if age >= life:
				continue
			var pos: Vector2 = _as_vector2(smoke.get("pos", Vector2.ZERO), Vector2.ZERO)
			var vel: Vector2 = _as_vector2(smoke.get("vel", Vector2.ZERO), Vector2.ZERO)
			pos += vel * delta
			vel *= 0.92
			smoke["age"] = age
			smoke["pos"] = pos
			smoke["vel"] = vel
			smoke["size"] = float(smoke.get("size", 4.0)) + delta * 12.0
			next_smoke.append(smoke)
		_smoke_puffs = next_smoke


func _bullet_hits_boss(pos: Vector2, boss_rect: Rect2) -> bool:
	if boss_rect.size.x <= 0.0 or boss_rect.size.y <= 0.0:
		return false
	var boss_center := boss_rect.get_center()
	var hit_radius := boss_rect.size.x * 0.5 + 10.0
	return pos.distance_squared_to(boss_center) <= hit_radius * hit_radius


func _apply_boss_ak47_hit_status(owner: Object, registry: Object, hit_pos: Vector2, velocity: Vector2, boss_rect: Rect2) -> void:
	var frame_velocity := velocity * AK47_FRAME_VELOCITY_SCALE
	var knockback_velocity := CommandoFirearmHitGeometry.get_hit_knockback_velocity(
		AK47_HIT_PROFILE,
		hit_pos,
		frame_velocity,
		boss_rect.get_center()
	)
	_last_knockback_velocity = knockback_velocity
	_last_stun_frames = AK47_STUN_FRAMES
	var status_state := _get_registry_instance(registry, "status_effect_state")
	if status_state != null and status_state.has_method("apply_status"):
		status_state.apply_status(
			"boss",
			"stun",
			AK47_STUN_FRAMES,
			LingpetGatlingBurstPayloadFactory.build_ak47_stun_status_data(
				knockback_velocity,
				AK47_KNOCKBACK_FRAMES,
				AK47_KNOCKBACK_DECAY,
				STATUS_SOURCE
			),
			STATUS_SOURCE
		)
		return
	var ai_state := _get_registry_instance(registry, "boss_ai_state")
	if ai_state != null and ai_state.has_method("start_paddle_hit_knockback"):
		ai_state.start_paddle_hit_knockback(knockback_velocity, AK47_KNOCKBACK_FRAMES, AK47_KNOCKBACK_DECAY, true)
	elif owner != null:
		owner.set("boss_vel", knockback_velocity)


func _spawn_hit_particles(pos: Vector2, hit_angle: float) -> void:
	for i in range(8):
		_hit_particles.append(LingpetGatlingBurstPayloadFactory.build_hit_particle(pos, hit_angle, i))
	while _hit_particles.size() > PARTICLE_MAX:
		_hit_particles.remove_at(0)


func _spawn_shell_casing(pos: Vector2, direction: Vector2) -> void:
	_shell_casings.append(LingpetGatlingBurstPayloadFactory.build_shell_casing(pos, direction))
	while _shell_casings.size() > 36:
		_shell_casings.remove_at(0)


func _spawn_muzzle_smoke(pos: Vector2, direction: Vector2) -> void:
	_smoke_puffs.append(LingpetGatlingBurstPayloadFactory.build_muzzle_smoke(pos, direction))
	while _smoke_puffs.size() > 28:
		_smoke_puffs.remove_at(0)


func _draw_tank_body(canvas: CanvasItem, shake_offset: Vector2) -> void:
	var frame_index := _get_transform_frame_index()
	var tank_center := _get_tank_center() + shake_offset
	var alpha := 1.0
	if _phase == PHASE_MOUNTING:
		alpha = lerpf(0.82, 1.0, _get_mount_progress())
	elif _phase == PHASE_DISMOUNTING:
		alpha = lerpf(1.0, 0.78, _get_dismount_progress())
	var texture := _get_transform_texture()
	if texture != null:
		_draw_transform_frame(canvas, texture, frame_index, tank_center, alpha)
	else:
		_draw_fallback_tank(canvas, tank_center, alpha)
	_draw_cannon_overlay(canvas, tank_center, alpha * _get_cannon_alpha())
	if _phase == PHASE_MOUNTING:
		_draw_mount_bar(canvas, tank_center + Vector2(0.0, -58.0 * TANK_VISUAL_SCALE), _get_mount_progress(), TANK_VISUAL_SCALE)


func _draw_transform_frame(canvas: CanvasItem, texture: Texture2D, frame_index: int, center: Vector2, alpha: float) -> void:
	var rows := maxi(1, ceili(float(TRANSFORM_FRAME_COUNT) / float(TRANSFORM_COLUMNS)))
	var frame_w := float(texture.get_width()) / float(TRANSFORM_COLUMNS)
	var frame_h := float(texture.get_height()) / float(rows)
	if frame_w <= 0.0 or frame_h <= 0.0:
		return
	var col := frame_index % TRANSFORM_COLUMNS
	var row := int(floor(float(frame_index) / float(TRANSFORM_COLUMNS)))
	var src := Rect2(Vector2(float(col) * frame_w, float(row) * frame_h), Vector2(frame_w, frame_h))
	var dest := Rect2(center - Vector2(TANK_DRAW_SIZE, TANK_DRAW_SIZE) * 0.5, Vector2(TANK_DRAW_SIZE, TANK_DRAW_SIZE))
	canvas.draw_texture_rect_region(texture, dest, src, Color(1.0, 1.0, 1.0, alpha), false, true)


func _draw_cannon_overlay(canvas: CanvasItem, tank_center: Vector2, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var direction := Vector2(cos(_aim_angle), sin(_aim_angle))
	var scale := TANK_VISUAL_SCALE
	var mount := tank_center + Vector2(0.0, -10.0 * scale) - direction * _recoil_offset * scale
	var tip := mount + direction * CANNON_LENGTH
	canvas.draw_line(mount + Vector2(1.5, 2.0) * scale, tip + Vector2(1.5, 2.0) * scale, Color(0.02, 0.03, 0.04, 0.58 * alpha), maxf(1.0, 8.0 * scale), true)
	canvas.draw_line(mount, tip, Color(0.15, 0.17, 0.20, 0.92 * alpha), maxf(1.0, 6.0 * scale), true)
	canvas.draw_line(mount, tip, Color(0.62, 0.74, 0.82, 0.72 * alpha), maxf(1.0, 2.0 * scale), true)
	canvas.draw_circle(mount, 7.0 * scale, Color(0.10, 0.14, 0.18, 0.88 * alpha))
	canvas.draw_circle(mount, 3.2 * scale, Color(0.44, 0.96, 1.0, 0.70 * alpha))
	if _muzzle_flash_timer > 0.0:
		var ratio := clampf(_muzzle_flash_timer / MUZZLE_FLASH_SECONDS, 0.0, 1.0)
		canvas.draw_circle(tip, 12.0 * scale * ratio, Color(1.0, 0.84, 0.28, 0.58 * ratio))
		canvas.draw_line(tip - direction * 3.0 * scale, tip + direction * 18.0 * scale * ratio, Color(1.0, 0.95, 0.68, 0.82 * ratio), maxf(1.0, 4.0 * scale), true)


func _draw_fallback_tank(canvas: CanvasItem, center: Vector2, alpha: float) -> void:
	var scale := TANK_VISUAL_SCALE
	var body := Rect2(center + Vector2(-34.0, -12.0) * scale, Vector2(68.0, 36.0) * scale)
	var turret := Rect2(center + Vector2(-20.0, -30.0) * scale, Vector2(40.0, 28.0) * scale)
	canvas.draw_rect(body.grow(3.0 * scale), Color(0.02, 0.03, 0.04, 0.46 * alpha), true)
	canvas.draw_rect(body, Color(0.16, 0.20, 0.24, 0.94 * alpha), true)
	canvas.draw_rect(body.grow(-4.0 * scale), Color(0.31, 0.40, 0.47, 0.80 * alpha), false, maxf(1.0, 2.0 * scale))
	canvas.draw_rect(turret, Color(0.12, 0.17, 0.22, 0.96 * alpha), true)
	canvas.draw_rect(turret.grow(-4.0 * scale), Color(0.42, 0.92, 1.0, 0.34 * alpha), false, maxf(1.0, 1.8 * scale))
	for side in [-1, 1]:
		var tread_center := center + Vector2(float(side) * 26.0, 20.0) * scale
		canvas.draw_rect(Rect2(tread_center + Vector2(-15.0, -7.0) * scale, Vector2(30.0, 14.0) * scale), Color(0.04, 0.05, 0.06, 0.96 * alpha), true)
		for i in range(3):
			canvas.draw_circle(tread_center + Vector2(float(i - 1) * 8.0, 0.0) * scale, 3.0 * scale, Color(0.48, 0.55, 0.60, 0.72 * alpha))


func _draw_mount_bar(canvas: CanvasItem, center: Vector2, progress: float, scale: float) -> void:
	var bg := Rect2(center + Vector2(-36.0, -4.0) * scale, Vector2(72.0, 8.0) * scale)
	var fill := Rect2(bg.position + Vector2(1.5, 1.5) * scale, Vector2((bg.size.x - 3.0 * scale) * clampf(progress, 0.0, 1.0), bg.size.y - 3.0 * scale))
	canvas.draw_rect(bg.grow(2.0 * scale), Color(0.02, 0.04, 0.06, 0.70), true)
	canvas.draw_rect(bg, Color(0.60, 0.92, 1.0, 0.82), false, maxf(1.0, 1.4 * scale))
	canvas.draw_rect(fill, Color(0.44, 0.98, 1.0, 0.88), true)


func _draw_bullets(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for bullet in _bullets:
		var pos: Vector2 = _as_vector2(bullet.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var vel: Vector2 = _as_vector2(bullet.get("vel", Vector2.ZERO), Vector2.ZERO)
		var direction := vel.normalized() if vel.length_squared() > 0.001 else Vector2(cos(float(bullet.get("angle", 0.0))), sin(float(bullet.get("angle", 0.0))))
		var tracer := bool(bullet.get("tracer", false))
		for i in range(TRAIL_STEPS):
			var trail_ratio := 1.0 - float(i) / float(TRAIL_STEPS)
			var trail_pos := pos - direction * BULLET_SPEED * TRAIL_STEP_SECONDS * float(i + 1)
			var width := BULLET_WIDTH * (0.45 + trail_ratio * 0.55)
			var color := Color(1.0, 0.85, 0.28, 0.18 * trail_ratio)
			if tracer:
				color = Color(0.64, 0.96, 1.0, 0.28 * trail_ratio)
			canvas.draw_line(trail_pos, pos, color, width, true)
		var tip := pos + direction * BULLET_LENGTH
		var core_color := Color(1.0, 0.93, 0.52, 0.96)
		if tracer:
			core_color = Color(0.80, 1.0, 1.0, 1.0)
		canvas.draw_line(pos - direction * BULLET_LENGTH, tip, core_color, BULLET_WIDTH, true)


func _draw_hit_particles(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for particle in _hit_particles:
		var age := float(particle.get("age", 0.0))
		var life := maxf(0.001, float(particle.get("life", 0.2)))
		var ratio := clampf(1.0 - age / life, 0.0, 1.0)
		var pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size := float(particle.get("size", 2.0)) * (0.45 + ratio * 0.55)
		var color := Color(1.0, 0.74, 0.24, 0.82 * ratio) if bool(particle.get("ember", false)) else Color(0.82, 0.96, 1.0, 0.78 * ratio)
		canvas.draw_circle(pos, size, color)


func _draw_shell_casings(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for casing in _shell_casings:
		var age := float(casing.get("age", 0.0))
		var life := maxf(0.001, float(casing.get("life", 0.5)))
		var ratio := clampf(1.0 - age / life, 0.0, 1.0)
		var pos: Vector2 = _as_vector2(casing.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var rotation := float(casing.get("rotation", 0.0))
		var dir := Vector2(cos(rotation), sin(rotation))
		canvas.draw_line(pos - dir * 2.2, pos + dir * 2.2, Color(0.96, 0.72, 0.30, 0.70 * ratio), 2.0, true)


func _draw_smoke(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for smoke in _smoke_puffs:
		var age := float(smoke.get("age", 0.0))
		var life := maxf(0.001, float(smoke.get("life", 0.25)))
		var ratio := clampf(1.0 - age / life, 0.0, 1.0)
		var pos: Vector2 = _as_vector2(smoke.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		canvas.draw_circle(pos, float(smoke.get("size", 5.0)), Color(0.55, 0.64, 0.70, 0.16 * ratio))


func _get_transform_texture() -> Texture2D:
	if _transform_texture == null:
		prewarm()
	return _transform_texture


func _get_transform_frame_index() -> int:
	var progress := 0.0
	match _phase:
		PHASE_MOUNTING:
			progress = _get_mount_progress()
		PHASE_FIRING:
			progress = 1.0
		PHASE_DISMOUNTING:
			progress = 1.0 - _get_dismount_progress()
		_:
			progress = 0.0
	return clampi(roundi(progress * float(TRANSFORM_CHASSIS_FRAME_INDEX)), 0, TRANSFORM_CHASSIS_FRAME_INDEX)


func _get_cannon_alpha() -> float:
	if _phase == PHASE_MOUNTING:
		return clampf((_get_mount_progress() - CANNON_MOUNT_PROGRESS_START) / maxf(0.001, 1.0 - CANNON_MOUNT_PROGRESS_START), 0.0, 1.0)
	if _phase == PHASE_DISMOUNTING:
		return clampf(1.0 - _get_dismount_progress(), 0.0, 1.0)
	return 1.0 if _phase == PHASE_FIRING else 0.0


func _get_mount_progress() -> float:
	if _phase == PHASE_MOUNTING:
		return clampf(_phase_timer / MOUNT_DURATION_SECONDS, 0.0, 1.0)
	if _phase == PHASE_FIRING or _phase == PHASE_DISMOUNTING:
		return 1.0
	return 0.0


func _get_dismount_progress() -> float:
	return clampf(_phase_timer / DISMOUNT_DURATION_SECONDS, 0.0, 1.0) if _phase == PHASE_DISMOUNTING else 0.0


func _get_tank_center() -> Vector2:
	var direction := Vector2(cos(_aim_angle), sin(_aim_angle))
	return _body_pos + Vector2(0.0, -12.0 * TANK_VISUAL_SCALE) - direction * _recoil_offset * 0.45 * TANK_VISUAL_SCALE


func _get_muzzle_pos() -> Vector2:
	var direction := Vector2(cos(_aim_angle), sin(_aim_angle))
	return _get_tank_center() + Vector2(0.0, -10.0 * TANK_VISUAL_SCALE) + direction * CANNON_LENGTH


func _get_launch_home_pos(origin: Vector2, launch_context: Dictionary) -> Vector2:
	var companion_pos := _get_vector2(launch_context, "companion_pos", origin)
	return Vector2(clampf(companion_pos.x, 28.0, FIELD_WIDTH - 28.0), clampf(companion_pos.y, 32.0, FIELD_HEIGHT - 32.0))


func _get_boss_rect(owner: Object) -> Rect2:
	var boss_pos := _get_owner_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 25.0))
	var boss_w := maxf(1.0, float(_get_owner_value(owner, "boss_paddle_width", 100.0)))
	var boss_h := maxf(1.0, float(_get_owner_value(owner, "boss_hitbox_height", 40.0)))
	return Rect2(boss_pos, Vector2(boss_w, boss_h))


func _get_boss_center(owner: Object) -> Vector2:
	return _get_boss_rect(owner).get_center()


func _get_aim_angle(owner: Object, origin: Vector2) -> float:
	var target := _get_boss_center(owner)
	return atan2(target.y - origin.y, target.x - origin.x)


func _play_transform_feedback(registry: Object) -> void:
	var audio := _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_lingpet_gatling_transform"):
		audio.play_lingpet_gatling_transform()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func _play_fire_feedback(registry: Object) -> void:
	var audio := _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_lingpet_gatling_fire"):
		audio.play_lingpet_gatling_fire()
	elif audio.has_method("play_shrapnel_armor_fire"):
		audio.play_shrapnel_armor_fire()


func _play_hit_feedback(registry: Object) -> void:
	var audio := _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_commando_bullet_impact"):
		audio.play_commando_bullet_impact()
	elif audio.has_method("play_commando_firearm_impact"):
		audio.play_commando_firearm_impact("ak47")
	elif audio.has_method("play_lingpet_gatling_hit"):
		audio.play_lingpet_gatling_hit()
	elif audio.has_method("play_shrapnel_armor_hit"):
		audio.play_shrapnel_armor_hit()
	elif audio.has_method("play_paddle_hit"):
		audio.play_paddle_hit()


func _sync_gatling_loop(registry: Object, active: bool) -> void:
	var audio := _get_registry_instance(registry, "game_audio")
	if audio == null:
		_loop_playing = active
		return
	if audio.has_method("sync_lingpet_gatling_loop"):
		audio.sync_lingpet_gatling_loop(active)
	elif active and audio.has_method("play_lingpet_gatling_loop"):
		audio.play_lingpet_gatling_loop()
	elif not active and audio.has_method("stop_lingpet_gatling_loop"):
		audio.stop_lingpet_gatling_loop()
	_loop_playing = active


func _trigger_feedback_shake(registry: Object, amount: float, intensity: float) -> void:
	var feedback := _get_registry_instance(registry, "battle_feedback_state")
	if feedback == null:
		return
	if feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(amount, intensity)
	elif feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(amount, intensity)


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	return fallback if value == null else value


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_owner_value(owner, key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


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


func _seeded_unit(a: float, b: float) -> float:
	var value := sin(a * 12.9898 + b * 78.233 + _visual_seed * 4.1414) * 43758.5453
	return value - floor(value)
