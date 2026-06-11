extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const BANANA_TEXTURE_PATH := "res://assets/sprites/items/banana.png"
const PHASE_IDLE := 0
const PHASE_PREPARE := 1

const PREPARE_SECONDS := 0.30
const BANANA_COUNT_BY_LEVEL := [1, 1, 2, 2, 2]
const SECOND_THROW_DELAY_SECONDS := 0.15
const LAND_Y := 45.0
const LAND_SECONDS := 3.0
const LAND_X_MIN := 30.0
const LAND_X_MAX := 730.0
const LAND_RANDOM_MIN := 40.0
const LAND_RANDOM_MAX := 720.0
const LAND_RANDOM_MIN_GAP := 120.0
const LAND_RANDOM_ATTEMPTS := 20
const FLYING_DRAW_SIZE := 64.0
const LANDED_DRAW_SIZE := 72.0
const COLLISION_SIZE := Vector2(80.0, 50.0)
const BOSS_PADDLE_WIDTH := 100.0
const BOSS_HITBOX_HEIGHT := 40.0
const THROW_SPEED_Y_PER_FRAME := -20.0
const THROW_AIM_X_DIVISOR := 30.0
const THROW_SPEED_X_MAX_PER_FRAME := 6.0
const WALL_LEFT := 10.0
const WALL_RIGHT := 750.0
const WALL_BOUNCE_SCALE := 0.70
const PROJECTILE_CULL_TOP := -50.0
const PROJECTILE_CULL_BOTTOM := 800.0
const SLIP_SECONDS := 0.80
const SLIP_SPEED_BY_LEVEL := [15.0, 16.25, 17.5, 18.75, 20.0]
const SLIP_CENTER_EPSILON := 10.0
const BURST_PARTICLE_COUNT := 12
const BURST_PARTICLE_MAX := 48
const BURST_GRAVITY := 1200.0
const COMPANION_CAST_PROGRESS_MAX := 0.92

var _phase := PHASE_IDLE
var _phase_timer := 0.0
var _origin := Vector2.ZERO
var _projectiles: Array[Dictionary] = []
var _landed_bananas: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _slip_timer := 0.0
var _slip_direction := 0.0
var _active_skill_level := 1
var _banana_count := 1
var _slip_speed_per_frame := 15.0
var _banana_texture: Texture2D = null
var _ellipse_mesh: ArrayMesh = null
var _registry: Object = null
var _landing_xs_for_tests: Array[float] = []
var _slip_direction_rolls_for_tests: Array[float] = []
var _throw_sound_count := 0
var _slip_sound_count := 0


func reset() -> void:
	_phase = PHASE_IDLE
	_phase_timer = 0.0
	_origin = Vector2.ZERO
	_projectiles.clear()
	_landed_bananas.clear()
	_particles.clear()
	_slip_timer = 0.0
	_slip_direction = 0.0
	_active_skill_level = 1
	_banana_count = _get_banana_count_for_level(_active_skill_level)
	_slip_speed_per_frame = _get_slip_speed_for_level(_active_skill_level)
	_throw_sound_count = 0
	_slip_sound_count = 0


func cancel(_owner: Object = null, registry: Object = null) -> void:
	if registry != null:
		_registry = registry
	reset()


func prewarm() -> void:
	_ensure_banana_texture()


func launch(origin: Vector2, _owner: Object = null, launch_context: Dictionary = {}) -> bool:
	reset()
	_ensure_banana_texture()
	var ctx_registry: Variant = launch_context.get("registry", null)
	if typeof(ctx_registry) == TYPE_OBJECT and is_instance_valid(ctx_registry):
		_registry = ctx_registry as Object
	_active_skill_level = _get_active_skill_level(launch_context)
	_banana_count = _get_banana_count_for_context(launch_context, _active_skill_level)
	_slip_speed_per_frame = _get_slip_speed_for_context(launch_context, _active_skill_level)
	_origin = Vector2(clampf(origin.x, 32.0, FIELD_WIDTH - 32.0), clampf(origin.y, 80.0, FIELD_HEIGHT - 32.0))
	_phase = PHASE_PREPARE
	_phase_timer = 0.0
	return true


func update(delta: float, owner: Object = null, registry: Object = null, _launch_context: Dictionary = {}) -> void:
	if registry != null:
		_registry = registry
	var safe_delta := maxf(0.0, delta)
	_update_particles(safe_delta)
	_update_slip(safe_delta)
	if _phase == PHASE_PREPARE:
		_phase_timer += safe_delta
		if _phase_timer >= PREPARE_SECONDS:
			_execute_throw()
			_phase = PHASE_IDLE
			_phase_timer = 0.0
			return
	_update_projectiles(safe_delta)
	_update_landed(safe_delta, owner)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	_ensure_banana_texture()
	if _phase == PHASE_PREPARE:
		var progress := clampf(_phase_timer / PREPARE_SECONDS, 0.0, 1.0)
		var prepare_pos := _get_prepare_banana_pos(progress)
		_draw_banana(canvas, prepare_pos + shake_offset, FLYING_DRAW_SIZE, lerpf(-15.0, 15.0, progress))
	for projectile in _projectiles:
		if float(projectile.get("delay", 0.0)) > 0.0:
			continue
		_draw_projectile_trail(canvas, projectile.get("trail", []) as Array, shake_offset)
		_draw_banana(
			canvas,
			_get_vector2(projectile, "position", Vector2.ZERO) + shake_offset,
			FLYING_DRAW_SIZE,
			float(projectile.get("rotation_degrees", 0.0))
		)
	for landed in _landed_bananas:
		var timer := float(landed.get("timer", 0.0))
		if timer < 1.0 and int(timer * 12.0) % 2 == 0:
			continue
		var pos := _get_vector2(landed, "position", Vector2.ZERO) + shake_offset
		_draw_filled_ellipse(canvas, Rect2(pos - Vector2(30.0, 5.0), Vector2(60.0, 10.0)), Color(1.0, 0.86, 0.18, 0.31))
		_draw_banana(canvas, pos, LANDED_DRAW_SIZE, 15.0)
	_draw_particles(canvas, shake_offset)


func has_visible_effects() -> bool:
	return _phase != PHASE_IDLE or not _projectiles.is_empty() or not _landed_bananas.is_empty() or not _particles.is_empty()


func is_active() -> bool:
	return has_visible_effects() or _slip_timer > 0.0


func has_companion_position_override() -> bool:
	return _phase == PHASE_PREPARE


func get_companion_position_override(fallback: Vector2 = Vector2.ZERO) -> Vector2:
	return _origin if _phase == PHASE_PREPARE else fallback


func get_companion_cast_pose_progress() -> float:
	if _phase != PHASE_PREPARE:
		return -1.0
	return lerpf(0.0, COMPANION_CAST_PROGRESS_MAX, clampf(_phase_timer / PREPARE_SECONDS, 0.0, 1.0))


func get_boss_ai_context() -> Dictionary:
	if _slip_timer <= 0.0 or absf(_slip_direction) <= 0.001:
		return {}
	return {
		"lingpet_banana_slice_boss_slip_active": true,
		"lingpet_banana_slice_boss_slip_direction": _slip_direction,
		"lingpet_banana_slice_boss_slip_speed": _slip_speed_per_frame * clampf(_slip_timer / SLIP_SECONDS, 0.0, 1.0),
	}


func get_snapshot() -> Dictionary:
	return {
		"banana_slice_active": is_active(),
		"banana_slice_phase": _phase,
		"banana_slice_phase_prepare": PHASE_PREPARE,
		"banana_slice_prepare_seconds": PREPARE_SECONDS,
		"banana_slice_prepare_timer": _phase_timer,
		"banana_slice_active_skill_level": _active_skill_level,
		"banana_slice_banana_count": _banana_count,
		"banana_slice_banana_count_by_level": BANANA_COUNT_BY_LEVEL.duplicate(),
		"banana_slice_projectile_count": _projectiles.size(),
		"banana_slice_landed_count": _landed_bananas.size(),
		"banana_slice_particle_count": _particles.size(),
		"banana_slice_slip_active": _slip_timer > 0.0,
		"banana_slice_slip_timer": _slip_timer,
		"banana_slice_slip_direction": _slip_direction,
		"banana_slice_slip_initial_speed": _slip_speed_per_frame,
		"banana_slice_slip_speed_by_level": SLIP_SPEED_BY_LEVEL.duplicate(),
		"banana_slice_slip_speed": float(get_boss_ai_context().get("lingpet_banana_slice_boss_slip_speed", 0.0)),
		"banana_slice_throw_sound_count": _throw_sound_count,
		"banana_slice_slip_sound_count": _slip_sound_count,
		"banana_slice_banana_texture_loaded": _banana_texture != null,
		"banana_slice_companion_override_active": has_companion_position_override(),
		"banana_slice_companion_cast_pose_progress": get_companion_cast_pose_progress(),
		"banana_slice_projectiles": _projectiles.duplicate(true),
		"banana_slice_landed_bananas": _landed_bananas.duplicate(true),
	}


func set_landing_xs_for_tests(xs: Array) -> void:
	_landing_xs_for_tests.clear()
	for value in xs:
		if value is int or value is float:
			_landing_xs_for_tests.append(float(value))


func set_slip_direction_rolls_for_tests(rolls: Array) -> void:
	_slip_direction_rolls_for_tests.clear()
	for value in rolls:
		if value is int or value is float:
			_slip_direction_rolls_for_tests.append(float(value))


func get_projectile_count_for_tests() -> int:
	return _projectiles.size()


func get_landed_count_for_tests() -> int:
	return _landed_bananas.size()


func get_slip_state_for_tests() -> Dictionary:
	return {
		"active": _slip_timer > 0.0,
		"timer": _slip_timer,
		"direction": _slip_direction,
		"speed": float(get_boss_ai_context().get("lingpet_banana_slice_boss_slip_speed", 0.0)),
	}


func force_land_for_tests(pos: Vector2, timer: float = LAND_SECONDS) -> void:
	_landed_bananas.append({
		"position": Vector2(clampf(pos.x, LAND_X_MIN, LAND_X_MAX), LAND_Y),
		"timer": maxf(0.0, timer),
		"max_timer": LAND_SECONDS,
		"slip_triggered": false,
	})


func force_throw_for_tests() -> void:
	if _phase != PHASE_PREPARE:
		_phase = PHASE_PREPARE
		_phase_timer = PREPARE_SECONDS
	_execute_throw()
	_phase = PHASE_IDLE
	_phase_timer = 0.0


func _execute_throw() -> void:
	var targets := _pick_landing_xs(_banana_count)
	var start_pos := _get_prepare_banana_pos(1.0)
	for index in range(_banana_count):
		var target_x := float(targets[index])
		var dx := target_x - start_pos.x
		var x_speed := minf(absf(dx) / THROW_AIM_X_DIVISOR, THROW_SPEED_X_MAX_PER_FRAME)
		var x_dir := -1.0 if dx < 0.0 else 1.0
		if absf(dx) <= 0.001:
			x_dir = 0.0
		_projectiles.append({
			"position": start_pos,
			"velocity": Vector2(x_dir * x_speed, THROW_SPEED_Y_PER_FRAME),
			"target_position": Vector2(target_x, LAND_Y),
			"delay": SECOND_THROW_DELAY_SECONDS * float(index),
			"rotation_degrees": 0.0,
			"rotation_speed_degrees": randf_range(480.0, 900.0) * (-1.0 if randf() < 0.5 else 1.0),
			"trail": [start_pos],
		})
	_play_throw_feedback()


func _update_projectiles(delta: float) -> void:
	if _projectiles.is_empty():
		return
	var fps_scale := delta * 60.0
	var write_index := 0
	for read_index in range(_projectiles.size()):
		var projectile := _projectiles[read_index]
		var delay := maxf(0.0, float(projectile.get("delay", 0.0)) - delta)
		projectile["delay"] = delay
		if delay > 0.0:
			_projectiles[write_index] = projectile
			write_index += 1
			continue
		var pos := _get_vector2(projectile, "position", Vector2.ZERO)
		var vel := _get_vector2(projectile, "velocity", Vector2.ZERO)
		pos += vel * fps_scale
		projectile["rotation_degrees"] = fposmod(
			float(projectile.get("rotation_degrees", 0.0))
			+ float(projectile.get("rotation_speed_degrees", 0.0)) * delta,
			360.0
		)
		if pos.x <= WALL_LEFT:
			pos.x = WALL_LEFT
			vel.x = absf(vel.x) * WALL_BOUNCE_SCALE
		elif pos.x >= WALL_RIGHT:
			pos.x = WALL_RIGHT
			vel.x = -absf(vel.x) * WALL_BOUNCE_SCALE
		projectile["position"] = pos
		projectile["velocity"] = vel
		var trail: Array = projectile.get("trail", []) as Array
		trail.append(pos)
		while trail.size() > 6:
			trail.pop_front()
		projectile["trail"] = trail
		if pos.y <= LAND_Y and vel.y < 0.0:
			_land_banana(Vector2(pos.x, LAND_Y))
			continue
		if pos.y < PROJECTILE_CULL_TOP or pos.y > PROJECTILE_CULL_BOTTOM:
			continue
		_projectiles[write_index] = projectile
		write_index += 1
	if write_index < _projectiles.size():
		_projectiles.resize(write_index)


func _land_banana(pos: Vector2) -> void:
	_landed_bananas.append({
		"position": Vector2(clampf(pos.x, LAND_X_MIN, LAND_X_MAX), LAND_Y),
		"timer": LAND_SECONDS,
		"max_timer": LAND_SECONDS,
		"slip_triggered": false,
	})


func _update_landed(delta: float, owner: Object) -> void:
	if _landed_bananas.is_empty():
		return
	var boss_rect := _get_boss_rect(owner)
	var write_index := 0
	for read_index in range(_landed_bananas.size()):
		var landed := _landed_bananas[read_index]
		var timer := float(landed.get("timer", LAND_SECONDS)) - delta
		if timer <= 0.0:
			continue
		landed["timer"] = timer
		var pos := _get_vector2(landed, "position", Vector2(FIELD_WIDTH * 0.5, LAND_Y))
		var banana_rect := Rect2(pos - COLLISION_SIZE * 0.5, COLLISION_SIZE)
		if not bool(landed.get("slip_triggered", false)) and boss_rect.intersects(banana_rect):
			landed["slip_triggered"] = true
			_start_boss_slip(owner, pos)
			_spawn_burst_particles(pos)
			_play_slip_feedback()
			continue
		_landed_bananas[write_index] = landed
		write_index += 1
	if write_index < _landed_bananas.size():
		_landed_bananas.resize(write_index)


func _start_boss_slip(owner: Object, banana_pos: Vector2) -> void:
	_slip_timer = SLIP_SECONDS
	var boss_rect := _get_boss_rect(owner)
	var paddle_cx := boss_rect.position.x + boss_rect.size.x * 0.5
	var delta_x := paddle_cx - banana_pos.x
	if absf(delta_x) < SLIP_CENTER_EPSILON:
		_slip_direction = -1.0 if _consume_slip_direction_roll() < 0.5 else 1.0
	else:
		_slip_direction = -1.0 if delta_x > 0.0 else 1.0


func _update_slip(delta: float) -> void:
	if _slip_timer <= 0.0:
		_slip_timer = 0.0
		_slip_direction = 0.0
		return
	_slip_timer = maxf(0.0, _slip_timer - delta)
	if _slip_timer <= 0.0:
		_slip_direction = 0.0


func _spawn_burst_particles(pos: Vector2) -> void:
	var colors := [
		Color(1.0, 225.0 / 255.0, 50.0 / 255.0, 1.0),
		Color(227.0 / 255.0, 189.0 / 255.0, 52.0 / 255.0, 1.0),
		Color(198.0 / 255.0, 156.0 / 255.0, 41.0 / 255.0, 1.0),
		Color(1.0, 1.0, 200.0 / 255.0, 1.0),
		Color(139.0 / 255.0, 90.0 / 255.0, 43.0 / 255.0, 1.0),
	]
	for _i in range(BURST_PARTICLE_COUNT):
		if _particles.size() >= BURST_PARTICLE_MAX:
			_particles.pop_front()
		var angle := randf_range(0.0, TAU)
		var speed := randf_range(180.0, 480.0)
		_particles.append({
			"position": pos,
			"velocity": Vector2(cos(angle), sin(angle)) * speed + Vector2(0.0, -180.0),
			"life": randf_range(0.33, 0.67),
			"max_life": 0.67,
			"size": randf_range(3.0, 7.0),
			"color": colors[randi() % colors.size()],
		})


func _update_particles(delta: float) -> void:
	if _particles.is_empty():
		return
	var write_index := 0
	for read_index in range(_particles.size()):
		var particle := _particles[read_index]
		var life := float(particle.get("life", 0.0)) - delta
		if life <= 0.0:
			continue
		var pos := _get_vector2(particle, "position", Vector2.ZERO)
		var vel := _get_vector2(particle, "velocity", Vector2.ZERO)
		pos += vel * delta
		vel.y += BURST_GRAVITY * delta
		particle["life"] = life
		particle["position"] = pos
		particle["velocity"] = vel
		_particles[write_index] = particle
		write_index += 1
	if write_index < _particles.size():
		_particles.resize(write_index)


func _pick_landing_xs(count: int) -> Array[float]:
	var positions: Array[float] = []
	for index in range(count):
		if index < _landing_xs_for_tests.size():
			positions.append(clampf(_landing_xs_for_tests[index], LAND_RANDOM_MIN, LAND_RANDOM_MAX))
			continue
		var candidate := randf_range(LAND_RANDOM_MIN, LAND_RANDOM_MAX)
		for _attempt in range(LAND_RANDOM_ATTEMPTS):
			candidate = randf_range(LAND_RANDOM_MIN, LAND_RANDOM_MAX)
			var ok := true
			for existing in positions:
				if absf(candidate - float(existing)) < LAND_RANDOM_MIN_GAP:
					ok = false
					break
			if ok:
				break
		positions.append(candidate)
	return positions


func _get_active_skill_level(launch_context: Dictionary) -> int:
	return clampi(int(launch_context.get("active_skill_level", launch_context.get("skill_level", 1))), 1, 5)


func _get_banana_count_for_context(launch_context: Dictionary, active_skill_level: int) -> int:
	var fallback := _get_banana_count_for_level(active_skill_level)
	if launch_context.has("banana_count"):
		var context_count := float(launch_context.get("banana_count", -1.0))
		if context_count > 0.0:
			return clampi(int(round(context_count)), 1, 4)
	return fallback


func _get_slip_speed_for_context(launch_context: Dictionary, active_skill_level: int) -> float:
	var fallback := _get_slip_speed_for_level(active_skill_level)
	if launch_context.has("slip_speed"):
		var context_speed := float(launch_context.get("slip_speed", -1.0))
		if context_speed > 0.0:
			return context_speed
	return fallback


func _get_banana_count_for_level(active_skill_level: int) -> int:
	var index := clampi(active_skill_level, 1, BANANA_COUNT_BY_LEVEL.size()) - 1
	return clampi(int(BANANA_COUNT_BY_LEVEL[index]), 1, 4)


func _get_slip_speed_for_level(active_skill_level: int) -> float:
	var index := clampi(active_skill_level, 1, SLIP_SPEED_BY_LEVEL.size()) - 1
	return maxf(0.0, float(SLIP_SPEED_BY_LEVEL[index]))


func _get_prepare_banana_pos(progress: float) -> Vector2:
	return _origin + Vector2(0.0, lerpf(0.0, -20.0, clampf(progress, 0.0, 1.0)))


func _get_boss_rect(owner: Object) -> Rect2:
	var boss_pos := BattleSceneOwnerReader.get_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - BOSS_PADDLE_WIDTH * 0.5, 25.0))
	var boss_width := maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "boss_paddle_width", BOSS_PADDLE_WIDTH)))
	var boss_height := maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "boss_hitbox_height", BOSS_HITBOX_HEIGHT)))
	return Rect2(boss_pos, Vector2(boss_width, boss_height))


func _draw_projectile_trail(canvas: CanvasItem, trail: Array, shake_offset: Vector2) -> void:
	if trail.is_empty():
		return
	for index in range(trail.size()):
		var value: Variant = trail[index]
		if not (value is Vector2):
			continue
		var alpha := float(index + 1) / float(trail.size()) * 0.20
		canvas.draw_circle((value as Vector2) + shake_offset, 7.0, Color(1.0, 0.90, 0.18, alpha))


func _draw_banana(canvas: CanvasItem, center: Vector2, draw_size: float, angle_degrees: float) -> void:
	if _banana_texture == null:
		canvas.draw_circle(center, draw_size * 0.34, Color(1.0, 0.84, 0.10, 0.92))
		canvas.draw_arc(center, draw_size * 0.36, -0.9, 0.9, 16, Color(0.55, 0.32, 0.05, 0.95), 3.0)
		return
	_draw_rotated_texture_region(
		canvas,
		_banana_texture,
		Rect2(Vector2.ZERO, _banana_texture.get_size()),
		center,
		Vector2(draw_size, draw_size),
		angle_degrees
	)


func _draw_rotated_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	center: Vector2,
	draw_size: Vector2,
	angle_degrees: float
) -> void:
	if texture == null or draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var angle := deg_to_rad(angle_degrees)
	var half_size := draw_size * 0.5
	var local_corners := [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	]
	var points := PackedVector2Array()
	for corner in local_corners:
		points.append(_rotated_local(center, corner, angle))
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_max.x, uv_max.y),
		Vector2(uv_min.x, uv_max.y),
	])
	canvas.draw_polygon(points, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]), uvs, texture)


func _draw_particles(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for particle in _particles:
		var max_life := maxf(0.001, float(particle.get("max_life", 0.67)))
		var alpha := clampf(float(particle.get("life", 0.0)) / max_life, 0.0, 1.0)
		var color: Color = particle.get("color", Color(1.0, 0.9, 0.2, 1.0))
		color.a *= alpha
		canvas.draw_circle(_get_vector2(particle, "position", Vector2.ZERO) + shake_offset, float(particle.get("size", 4.0)), color)


func _draw_filled_ellipse(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	if rect.size.x <= 1.0 or rect.size.y <= 1.0 or color.a <= 0.0:
		return
	var radius := rect.size * 0.5
	var center := rect.get_center()
	var transform := Transform2D(Vector2(radius.x, 0.0), Vector2(0.0, radius.y), center)
	canvas.draw_mesh(_get_filled_ellipse_mesh(), null, transform, color)


func _get_filled_ellipse_mesh() -> ArrayMesh:
	if _ellipse_mesh != null:
		return _ellipse_mesh
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	vertices.append(Vector3.ZERO)
	for step in range(24):
		var angle := TAU * float(step) / 24.0
		vertices.append(Vector3(cos(angle), sin(angle), 0.0))
	for step in range(24):
		indices.append(0)
		indices.append(step + 1)
		indices.append((step + 1) % 24 + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_ellipse_mesh = mesh
	return _ellipse_mesh


func _rotated_local(center: Vector2, local: Vector2, angle: float) -> Vector2:
	return center + Vector2(
		local.x * cos(angle) - local.y * sin(angle),
		local.x * sin(angle) + local.y * cos(angle)
	)


func _ensure_banana_texture() -> Texture2D:
	if _banana_texture == null:
		_banana_texture = ProjectResourceLoader.load_texture(
			BANANA_TEXTURE_PATH,
			"Missing Banana Slice texture at %s",
			"Failed to load Banana Slice texture at %s"
		)
	return _banana_texture


func _play_throw_feedback() -> void:
	_throw_sound_count += 1
	var audio := _get_registry_instance(_registry, "game_audio")
	if audio != null and audio.has_method("play_banana_throw"):
		audio.play_banana_throw()


func _play_slip_feedback() -> void:
	_slip_sound_count += 1
	var audio := _get_registry_instance(_registry, "game_audio")
	if audio != null and audio.has_method("play_banana_slip"):
		audio.play_banana_slip()


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _consume_slip_direction_roll() -> float:
	if not _slip_direction_rolls_for_tests.is_empty():
		return clampf(float(_slip_direction_rolls_for_tests.pop_front()), 0.0, 1.0)
	return randf()


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
