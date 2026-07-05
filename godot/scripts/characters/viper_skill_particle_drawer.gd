extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const LOD_PARTICLE_STRIDE_THRESHOLD := 0.66
const SEVERE_LOD_SCALE_THRESHOLD := 0.50
const IGNITION_SEVERE_LOD_SCALE_THRESHOLD := 0.60
const SEVERE_LOD_DIVE_PARTICLE_DRAW_LIMIT := 42
const SEVERE_LOD_HIT_PARTICLE_DRAW_LIMIT := 40
const SEVERE_LOD_IGNITION_PARTICLE_DRAW_LIMIT := 48
const SEVERE_LOD_PHANTOM_HIT_PARTICLE_DRAW_LIMIT := 52


func update_particle_list(particles: Array, fps_scale: float, drag: float, gravity: float) -> void:
	if particles.is_empty():
		return
	var alive: Array = []
	var drag_factor: float = pow(drag, fps_scale)
	for particle_value in particles:
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		particle["pos"] = _get_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + _get_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO) * fps_scale
		particle["vel"] = _get_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO) * drag_factor + Vector2(0.0, gravity * fps_scale)
		particle["life"] = float(particle.get("life", 0.0)) - fps_scale
		if float(particle.get("life", 0.0)) > 0.0:
			alive.append(particle)
	particles.clear()
	particles.append_array(alive)


func update_ignition_particle_array(particles: Array, fps_scale: float) -> void:
	if particles.is_empty():
		return
	var write_index := 0
	for read_index in range(particles.size()):
		var particle_value: Variant = particles[read_index]
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var kind: String = str(particle.get("kind", ""))
		var pos: Vector2 = _get_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO)
		var vel: Vector2 = _get_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO)
		var size: float = max(0.1, float(particle.get("size", 2.0)))
		pos += vel * fps_scale
		match kind:
			"smoke":
				vel *= pow(0.965, fps_scale)
				vel.y -= 0.02 * fps_scale
				size += 0.16 * fps_scale
			"burst":
				vel *= pow(0.94, fps_scale)
				vel.y += 0.02 * fps_scale
				size = max(0.6, size - 0.10 * fps_scale)
			"ember":
				vel.y -= 0.012 * fps_scale
				vel.x += sin((pos.y + float(read_index)) * 0.05) * 0.02 * fps_scale
				size = max(0.4, size - 0.045 * fps_scale)
			"charge":
				vel.y -= 0.02 * fps_scale
				size = max(0.4, size - 0.08 * fps_scale)
			_:
				size = max(0.3, size - 0.12 * fps_scale)
		var life: float = float(particle.get("life", 0.0)) - fps_scale
		if life <= 0.0:
			continue
		particle["pos"] = pos
		particle["vel"] = vel
		particle["life"] = life
		particle["size"] = size
		particles[write_index] = particle
		write_index += 1
	if write_index < particles.size():
		particles.resize(write_index)


func update_dive_particle_array(particles: Array, fps_scale: float) -> void:
	if particles.is_empty():
		return
	var write_index := 0
	for read_index in range(particles.size()):
		var particle_value: Variant = particles[read_index]
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var kind: String = str(particle.get("kind", ""))
		var pos: Vector2 = _get_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO)
		var vel: Vector2 = _get_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO)
		var size: float = max(0.1, float(particle.get("size", 2.0)))
		pos += vel * fps_scale
		match kind:
			"dust_cloud":
				vel *= pow(0.96, fps_scale)
				vel.y -= 0.03 * fps_scale
				size += 0.2 * fps_scale
			"dust_pillar":
				vel.y *= pow(0.94, fps_scale)
				size += 0.15 * fps_scale
			"debris":
				vel.y += 0.2 * fps_scale
				size = max(0.3, size - 0.12 * fps_scale)
			"charge":
				vel.y += 0.045 * fps_scale
				size = max(0.4, size - 0.08 * fps_scale)
			_:
				size = max(0.3, size - 0.18 * fps_scale)
		var life: float = float(particle.get("life", 0.0)) - fps_scale
		if life <= 0.0:
			continue
		particle["pos"] = pos
		particle["vel"] = vel
		particle["life"] = life
		particle["size"] = size
		particles[write_index] = particle
		write_index += 1
	if write_index < particles.size():
		particles.resize(write_index)


func spawn_dive_landing_particles(
	particles: Array,
	center: Vector2,
	particle_limit: int,
	jetpack_max_height: float
) -> void:
	for _dive_landing_dust_index in range(50):
		var dive_landing_side: float = -1.0 if randf() < 0.5 else 1.0
		particles.append({
			"pos": center + Vector2(randf_range(-40.0, 40.0), randf_range(-8.0, 4.0)),
			"vel": Vector2(dive_landing_side * randf_range(4.0, 14.0), randf_range(-3.0, -0.3)),
			"life": randf_range(35.0, 60.0),
			"max_life": 60.0,
			"size": randf_range(10.0, 22.0),
			"color": Color(0.58, 0.58, 0.54, 0.82),
			"kind": "dust_cloud",
		})
	for _dive_landing_pillar_index in range(25):
		particles.append({
			"pos": center + Vector2(randf_range(-jetpack_max_height * 1.8, jetpack_max_height * 1.8), randf_range(-3.0, 3.0)),
			"vel": Vector2(randf_range(-1.2, 1.2), randf_range(-5.0, -1.5)),
			"life": randf_range(20.0, 40.0),
			"max_life": 40.0,
			"size": randf_range(5.0, 14.0),
			"color": Color(0.66, 0.66, 0.61, 0.78),
			"kind": "dust_pillar",
		})
	for _dive_landing_debris_index in range(30):
		var dive_landing_debris_angle: float = randf_range(-PI, 0.0)
		var dive_landing_debris_speed: float = randf_range(5.0, 16.0)
		particles.append({
			"pos": center + Vector2(randf_range(-60.0, 60.0), 0.0),
			"vel": Vector2(cos(dive_landing_debris_angle) * dive_landing_debris_speed, sin(dive_landing_debris_angle) * dive_landing_debris_speed * 0.5),
			"life": randf_range(12.0, 30.0),
			"max_life": 30.0,
			"size": randf_range(1.5, 5.0),
			"color": Color(0.82, 0.76, 0.64, 0.92),
			"kind": "debris",
		})
	while particles.size() > particle_limit:
		particles.pop_front()


func spawn_dive_charge_particles(
	particles: Array,
	player_pos: Vector2,
	paddle_size: Vector2,
	hold_ratio: float,
	particle_limit: int
) -> void:
	var center: Vector2 = player_pos + paddle_size * 0.5
	var foot_y: float = player_pos.y + paddle_size.y
	var count: int = int(1.0 + clamp(hold_ratio, 0.0, 1.0) * 5.0)
	for _i in range(count):
		var spread: float = 8.0 + hold_ratio * 14.0
		var color := Color(1.0, randf_range(0.48, 0.86), randf_range(0.12, 0.38), 1.0)
		particles.append({
			"pos": Vector2(center.x + randf_range(-spread, spread), foot_y + randf_range(-2.0, 4.0)),
			"vel": Vector2(randf_range(-0.8, 0.8), randf_range(-3.5, -1.0) * (0.6 + hold_ratio * 0.6)),
			"life": randf_range(12.0, 28.0),
			"max_life": 28.0,
			"size": randf_range(2.0, 4.5 + hold_ratio * 2.0),
			"color": color,
			"kind": "charge",
		})
	while particles.size() > particle_limit:
		particles.pop_front()


func spawn_dive_prep_particles(
	particles: Array,
	center: Vector2,
	prep_progress: float,
	fps_scale: float,
	particle_limit: int
) -> void:
	var count: int = max(1, int(round((2.0 + prep_progress * 4.0) * max(0.25, fps_scale))))
	for _i in range(count):
		var angle: float = randf_range(0.0, TAU)
		var dist: float = randf_range(30.0, 80.0) * (1.0 - prep_progress * 0.5)
		var outward := Vector2(cos(angle), sin(angle))
		particles.append({
			"pos": center + outward * dist,
			"vel": -outward * 2.0,
			"life": 12.0,
			"max_life": 12.0,
			"size": randf_range(2.0, 5.0),
			"color": Color(0.40, 0.95, 1.0, 1.0),
			"kind": "energy",
		})
	while particles.size() > particle_limit:
		particles.pop_front()


func spawn_dive_trail_particles(
	particles: Array,
	center_x: float,
	foot_y: float,
	fps_scale: float,
	particle_limit: int
) -> void:
	var count: int = max(1, int(round(2.0 * max(0.25, fps_scale))))
	for _i in range(count):
		particles.append({
			"pos": Vector2(center_x + randf_range(-8.0, 8.0), foot_y),
			"vel": Vector2(randf_range(-0.8, 0.8), randf_range(-2.0, 0.5)),
			"life": randf_range(6.0, 12.0),
			"max_life": 12.0,
			"size": randf_range(2.0, 5.0),
			"color": Color(1.0, 0.72, 0.24, 1.0),
			"kind": "trail",
		})
	while particles.size() > particle_limit:
		particles.pop_front()


func spawn_dual_glitch_clone_dive_particles(particles: Array, center: Vector2, particle_limit: int) -> void:
	for _i in range(12):
		particles.append({
			"pos": center + Vector2(randf_range(-44.0, 44.0), randf_range(-5.0, 4.0)),
			"vel": Vector2(randf_range(-9.0, 9.0), randf_range(-2.4, 0.2)),
			"life": randf_range(14.0, 28.0),
			"max_life": 28.0,
			"size": randf_range(3.0, 8.0),
			"color": Color(0.28, 0.95, 1.0, 0.80),
			"kind": "energy",
		})
	while particles.size() > particle_limit:
		particles.pop_front()


func spawn_ignition_aura_burst(particles: Array, center: Vector2, particle_limit: int) -> void:
	particles.clear()
	for _ignition_burst_index in range(46):
		var ignition_burst_angle: float = randf_range(0.0, TAU)
		var ignition_burst_speed: float = randf_range(3.5, 12.0)
		particles.append({
			"pos": center + Vector2(cos(ignition_burst_angle), sin(ignition_burst_angle)) * randf_range(4.0, 22.0),
			"vel": Vector2(cos(ignition_burst_angle), sin(ignition_burst_angle)) * ignition_burst_speed + Vector2(0.0, randf_range(-1.2, 0.8)),
			"life": randf_range(18.0, 44.0),
			"max_life": 44.0,
			"size": randf_range(3.0, 8.5),
			"color": Color(1.0, randf_range(0.42, 0.78), randf_range(0.06, 0.20), 0.88),
			"kind": "burst",
		})
	for _ignition_smoke_index in range(18):
		var ignition_smoke_side: float = -1.0 if randf() < 0.5 else 1.0
		particles.append({
			"pos": center + Vector2(randf_range(-54.0, 54.0), randf_range(-10.0, 18.0)),
			"vel": Vector2(ignition_smoke_side * randf_range(1.0, 5.0), randf_range(-4.8, -1.0)),
			"life": randf_range(36.0, 66.0),
			"max_life": 66.0,
			"size": randf_range(5.0, 13.0),
			"color": Color(1.0, 0.24, 0.08, 0.52),
			"kind": "smoke",
		})
	while particles.size() > particle_limit:
		particles.pop_front()


func spawn_ignition_live_embers(
	particles: Array,
	player_pos: Vector2,
	paddle_size: Vector2,
	particle_limit: int
) -> void:
	var center: Vector2 = player_pos + paddle_size * 0.5
	var foot_y: float = player_pos.y + paddle_size.y
	for _i in range(2):
		particles.append({
			"pos": Vector2(center.x + randf_range(-paddle_size.x * 0.58, paddle_size.x * 0.58), foot_y + randf_range(-4.0, 8.0)),
			"vel": Vector2(randf_range(-0.45, 0.45), randf_range(-2.8, -1.2)),
			"life": randf_range(34.0, 62.0),
			"max_life": 62.0,
			"size": randf_range(2.2, 5.8),
			"color": Color(1.0, randf_range(0.48, 0.88), randf_range(0.10, 0.28), 0.72),
			"kind": "ember",
		})
	while particles.size() > particle_limit:
		particles.pop_front()


func spawn_ignition_charge_particles(
	particles: Array,
	player_pos: Vector2,
	paddle_size: Vector2,
	hold_ratio: float,
	particle_limit: int
) -> void:
	var center_x: float = player_pos.x + paddle_size.x * 0.5
	var foot_y: float = player_pos.y + paddle_size.y
	var count: int = int(1.0 + clamp(hold_ratio, 0.0, 1.0) * 6.0)
	for _i in range(count):
		var spread: float = 12.0 + hold_ratio * 28.0
		particles.append({
			"pos": Vector2(center_x + randf_range(-spread, spread), foot_y + randf_range(-2.0, 8.0)),
			"vel": Vector2(randf_range(-0.7, 0.7), randf_range(-3.2, -0.8) * (0.6 + hold_ratio)),
			"life": randf_range(14.0, 30.0),
			"max_life": 30.0,
			"size": randf_range(2.0, 4.0 + hold_ratio * 3.0),
			"color": Color(1.0, randf_range(0.46, 0.82), randf_range(0.08, 0.22), 0.92),
			"kind": "charge",
		})
	while particles.size() > particle_limit:
		particles.pop_front()


func spawn_phantom_hit_particles(particles: Array, pos: Vector2, particle_count: int, particle_limit: int) -> void:
	var phantom_palette := [
		Color(0.31, 0.06, 0.47, 1.0),
		Color(0.43, 0.10, 0.63, 1.0),
		Color(0.24, 0.03, 0.37, 1.0),
		Color(0.51, 0.12, 0.70, 1.0),
		Color(0.16, 0.0, 0.25, 1.0),
		Color(0.37, 0.04, 0.55, 1.0),
		Color(0.47, 0.16, 0.61, 1.0),
		Color(0.27, 0.05, 0.43, 1.0),
	]
	for phantom_index in range(particle_count):
		var phantom_angle: float = randf_range(0.0, TAU)
		var phantom_speed: float = randf_range(3.5, 13.0)
		var phantom_life: float = randf_range(30.0, 65.0)
		particles.append({
			"pos": pos + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0)),
			"vel": Vector2(cos(phantom_angle), sin(phantom_angle)) * phantom_speed + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)),
			"life": phantom_life,
			"max_life": phantom_life,
			"size": randf_range(3.5, 8.0),
			"color": phantom_palette[phantom_index % phantom_palette.size()],
			"glow": randf() < 0.5,
		})
	while particles.size() > particle_limit:
		particles.pop_front()


func spawn_marshal_motion_particle(
	particles: Array,
	pos: Vector2,
	kind: String,
	chance: float,
	life_override: float,
	particle_limit: int
) -> void:
	if randf() > chance:
		return
	var life: float = life_override if life_override > 0.0 else randf_range(8.0, 16.0)
	var speed: float = randf_range(1.5, 5.0)
	if kind == "impact":
		speed = randf_range(3.5, 10.5)
	var angle: float = randf_range(0.0, TAU)
	var particle := {
		"pos": pos,
		"vel": Vector2(cos(angle), sin(angle)) * speed + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)),
		"life": life,
		"max_life": life,
		"size": randf_range(2.0, 5.0) if kind == "trail" else randf_range(4.0, 10.0),
		"kind": kind,
	}
	particles.append(particle)
	while particles.size() > particle_limit:
		particles.pop_front()


func spawn_fallback_hit_impact(
	ball_pos: Vector2,
	impact_velocity: Vector2,
	impact_effects: Object,
	hit_color: Color,
	particle_intensity: float,
	explosion_scale: float,
	explosion_intensity: float
) -> void:
	if impact_effects == null:
		return
	var direction: Vector2 = impact_velocity.normalized() if impact_velocity.length() > 0.0 else Vector2(0.0, -1.0)
	if impact_effects.has_method("spawn_hit_particles"):
		impact_effects.spawn_hit_particles(ball_pos, hit_color, direction, particle_intensity, impact_velocity.length())
	if impact_effects.has_method("create_energy_explosion"):
		impact_effects.create_energy_explosion(ball_pos, explosion_scale, explosion_intensity)


func register_ball_hit_pulse(ball_pos: Vector2, ball_vel: Vector2, ball_effects: Object, intensity: float, kind: String) -> bool:
	if ball_effects == null or not ball_effects.has_method("register_hit_pulse"):
		return false
	ball_effects.register_hit_pulse(ball_pos, ball_vel, intensity, kind)
	return true


func spawn_shadow_activation_feedback(pos: Vector2, impact_effects: Object, scale: float) -> void:
	if impact_effects != null and impact_effects.has_method("create_energy_explosion"):
		impact_effects.create_energy_explosion(pos, 0.52 * scale, 0.72 * scale)


func draw_ignition_particle_list(
	canvas: CanvasItem,
	particles: Array,
	shake_offset: Vector2,
	effect_lod_scale: float = 1.0
) -> void:
	var severe_lod: bool = _is_ignition_severe_lod(effect_lod_scale)
	var stride: int = _get_lod_particle_stride(effect_lod_scale)
	var draw_limit: int = _get_lod_particle_draw_limit(
		particles.size(),
		SEVERE_LOD_IGNITION_PARTICLE_DRAW_LIMIT,
		severe_lod
	)
	var particle_index := 0
	var drawn_count := 0
	for particle_value in particles:
		particle_index += 1
		if stride > 1 and particle_index % stride != 0:
			continue
		if drawn_count >= draw_limit:
			break
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var life: float = max(0.0, float(particle.get("life", 0.0)))
		var max_life: float = max(1.0, float(particle.get("max_life", 1.0)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		if alpha <= 0.01:
			continue
		var pos: Vector2 = _get_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(particle.get("size", 3.0)))
		var color_value: Variant = particle.get("color", Color(1.0, 0.50, 0.12, 1.0))
		var color: Color = color_value if color_value is Color else Color(1.0, 0.50, 0.12, 1.0)
		if not severe_lod and size > 4.0:
			canvas.draw_circle(pos, size + 3.0, Color(color.r, color.g, color.b, alpha * 0.14))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, alpha * color.a))
		drawn_count += 1


func draw_ignition_aura_sheet(
	canvas: CanvasItem,
	center: Vector2,
	tick_msec: float,
	texture: Texture2D,
	paddle_size: Vector2,
	columns: int,
	rows: int,
	frame_interval_msec: int
) -> void:
	if texture == null:
		return
	var sheet_w: float = float(texture.get_width())
	var sheet_h: float = float(texture.get_height())
	if sheet_w <= 0.0 or sheet_h <= 0.0:
		return
	var frame_w: float = sheet_w / float(columns)
	var frame_h: float = sheet_h / float(rows)
	if frame_w <= 0.0 or frame_h <= 0.0:
		return
	var frame_count: int = max(1, columns * rows)
	var frame_index: int = int(floor(tick_msec / float(frame_interval_msec))) % frame_count
	var frame_col: int = frame_index % columns
	@warning_ignore("integer_division")
	var frame_row: int = int(frame_index / columns)
	var breath: float = 0.92 + 0.08 * sin(tick_msec * 0.0028)
	var base_size: float = max(112.0, min(150.0, max(paddle_size.x * 2.45, paddle_size.y * 1.55)))
	var aura_size: float = base_size * breath * 1.2
	var aura_center := center + Vector2(0.0, -max(12.0, aura_size * 0.14))
	var dest_rect := Rect2(aura_center - Vector2(aura_size, aura_size) * 0.5, Vector2(aura_size, aura_size))
	var source_rect := Rect2(Vector2(float(frame_col) * frame_w, float(frame_row) * frame_h), Vector2(frame_w, frame_h))
	var alpha: float = 0.48 + 0.10 * (0.5 + 0.5 * sin(tick_msec * 0.0043))
	canvas.draw_texture_rect_region(texture, dest_rect, source_rect, Color(1.0, 1.0, 1.0, alpha), false, true)


func get_ignition_aura_effect_texture(runtime: Object, sheet_path: String) -> Texture2D:
	if runtime.ignition_aura_effect_load_attempted:
		return runtime.ignition_aura_effect_texture
	runtime.ignition_aura_effect_load_attempted = true
	runtime.ignition_aura_effect_texture = ProjectResourceLoader.load_texture(
		sheet_path,
		"Missing Viper Ignition Aura effect sheet at %s",
		"Failed to load Viper Ignition Aura effect sheet at %s"
	)
	return runtime.ignition_aura_effect_texture


func prewarm_ignition_aura_assets(runtime: Object, sheet_path: String) -> bool:
	ImpactFlareTextureCache.prewarm()
	ImpactShockwaveTextureCache.prewarm()
	get_ignition_aura_effect_texture(runtime, sheet_path)
	return true


func draw_ignition_aura_effects(
	canvas: CanvasItem,
	shake_offset: Vector2,
	runtime: Object,
	ratio: float,
	sheet_path: String,
	columns: int,
	rows: int,
	frame_interval_msec: int,
	effect_lod_scale: float = 1.0
) -> void:
	var tick: float = float(Time.get_ticks_msec())
	if runtime.ignition_hold_start_msec > 0:
		var hold_center: Vector2 = runtime.ignition_hold_player_pos + runtime.ignition_hold_paddle_size * 0.5 + shake_offset
		draw_ignition_hold_aura(canvas, hold_center, runtime.ignition_hold_ratio, tick, effect_lod_scale)

	if runtime.ignition_active:
		var center: Vector2 = runtime.ignition_player_pos + runtime.ignition_paddle_size * 0.5 + shake_offset
		draw_ignition_aura_sheet(
			canvas,
			center,
			tick,
			get_ignition_aura_effect_texture(runtime, sheet_path),
			runtime.ignition_paddle_size,
			columns,
			rows,
			frame_interval_msec
		)
		draw_ignition_active_aura(canvas, center, tick, ratio, runtime.ignition_remaining_frames, effect_lod_scale)

	draw_ignition_particle_list(canvas, runtime.ignition_burst_particles, shake_offset, effect_lod_scale)
	draw_ignition_particle_list(canvas, runtime.ignition_live_embers, shake_offset, effect_lod_scale)
	draw_ignition_particle_list(canvas, runtime.ignition_charge_particles, shake_offset, effect_lod_scale)


func draw_ignition_hold_aura(
	canvas: CanvasItem,
	center: Vector2,
	hold_ratio: float,
	tick_msec: float,
	effect_lod_scale: float = 1.0
) -> void:
	var hold_t: float = clamp(hold_ratio, 0.0, 1.0)
	var hold_pulse: float = 0.5 + 0.5 * sin(tick_msec * 0.026)
	ImpactFlareTextureCache.draw_glow(canvas, center, 36.0 + hold_t * 42.0 + hold_pulse * 8.0, Color(1.0, 0.48, 0.10), 0.14 + hold_t * 0.18)
	var severe_lod: bool = _is_ignition_severe_lod(effect_lod_scale)
	var ring_count: int = 2 if severe_lod else 3
	for ring_index in range(ring_count):
		var radius: float = 24.0 + hold_t * 58.0 + float(ring_index) * 13.0
		var alpha: float = (0.22 + hold_t * 0.16 - float(ring_index) * 0.04) * (0.55 + hold_pulse * 0.45)
		ImpactShockwaveTextureCache.draw_full_ring(canvas, center, radius, Color(1.0, 0.55, 0.12), alpha)
	var spoke_count: int = 3 if severe_lod else 6
	for i in range(spoke_count):
		var angle: float = TAU * float(i) / float(spoke_count) + tick_msec * 0.004
		var inner: Vector2 = center + Vector2(cos(angle), sin(angle)) * (14.0 + hold_t * 8.0)
		var outer: Vector2 = center + Vector2(cos(angle), sin(angle)) * (42.0 + hold_t * 36.0)
		canvas.draw_line(outer, inner, Color(1.0, 0.82, 0.30, 0.20 + hold_t * 0.34), 1.8, true)


func draw_ignition_active_aura(
	canvas: CanvasItem,
	center: Vector2,
	tick_msec: float,
	ratio: float,
	remaining_frames: float,
	effect_lod_scale: float = 1.0
) -> void:
	var severe_lod: bool = _is_ignition_severe_lod(effect_lod_scale)
	var pulse: float = 0.5 + 0.5 * sin(tick_msec * 0.018)
	var low_time_boost: float = 0.0 if remaining_frames > 180.0 else 0.12 + pulse * 0.08
	ImpactFlareTextureCache.draw_glow(canvas, center, 72.0 + pulse * 18.0, Color(1.0, 0.36, 0.08), 0.20 + low_time_boost)
	if not severe_lod:
		ImpactFlareTextureCache.draw_glow(canvas, center + Vector2(0.0, 8.0), 38.0 + pulse * 8.0, Color(1.0, 0.86, 0.28), 0.18)
	var ring_count: int = 2 if severe_lod else 3
	for ring_index in range(ring_count):
		var ring_radius: float = 46.0 + float(ring_index) * 20.0 + pulse * 5.0
		var ring_alpha: float = (0.22 - float(ring_index) * 0.04) * (0.72 + pulse * 0.28)
		ImpactShockwaveTextureCache.draw_full_ring(canvas, center, ring_radius, Color(1.0, 0.46, 0.08), ring_alpha)
	var arc_radius: float = 54.0 + pulse * 7.0
	var arc_count: int = 2 if severe_lod else 4
	var arc_segments: int = 10 if severe_lod else 18
	for arc_index in range(arc_count):
		var start_angle: float = tick_msec * 0.0028 + float(arc_index) * PI * 0.5
		var end_angle: float = start_angle + PI * (0.30 + 0.10 * pulse)
		canvas.draw_arc(center, arc_radius + float(arc_index % 2) * 11.0, start_angle, end_angle, arc_segments, Color(1.0, 0.82, 0.30, 0.48), 2.2)
	if ratio < 0.18:
		var fade_flash: float = (0.18 - ratio) / 0.18
		var fade_segments: int = 24 if severe_lod else 42
		canvas.draw_arc(center, 82.0 + pulse * 8.0, 0.0, TAU, fade_segments, Color(1.0, 0.22, 0.08, 0.14 + fade_flash * 0.18), 3.0)


func draw_dive_particle_list(
	canvas: CanvasItem,
	particles: Array,
	shake_offset: Vector2,
	effect_lod_scale: float = 1.0
) -> void:
	var severe_lod: bool = effect_lod_scale <= SEVERE_LOD_SCALE_THRESHOLD
	var stride: int = _get_lod_particle_stride(effect_lod_scale)
	var draw_limit: int = _get_lod_particle_draw_limit(
		particles.size(),
		SEVERE_LOD_DIVE_PARTICLE_DRAW_LIMIT,
		severe_lod
	)
	var particle_index := 0
	var drawn_count := 0
	for particle_value in particles:
		particle_index += 1
		if stride > 1 and particle_index % stride != 0:
			continue
		if drawn_count >= draw_limit:
			break
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var life: float = max(0.0, float(particle.get("life", 0.0)))
		var max_life: float = max(1.0, float(particle.get("max_life", 1.0)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		if alpha <= 0.01:
			continue
		var pos: Vector2 = _get_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(particle.get("size", 3.0)))
		var color_value: Variant = particle.get("color", Color(0.60, 0.90, 1.0, 1.0))
		var color: Color = color_value if color_value is Color else Color(0.60, 0.90, 1.0, 1.0)
		if not severe_lod and size > 4.0:
			canvas.draw_circle(pos, size + 2.0, Color(color.r, color.g, color.b, alpha * 0.18))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, alpha * color.a))
		drawn_count += 1


func draw_dive_phase_effects(
	canvas: CanvasItem,
	shake_offset: Vector2,
	active: bool,
	phase: int,
	phase_frames: float,
	player_pos: Vector2,
	paddle_size: Vector2,
	prep_frames: float,
	effect_lod_scale: float = 1.0
) -> void:
	if not active:
		return
	var severe_lod: bool = effect_lod_scale <= SEVERE_LOD_SCALE_THRESHOLD
	var center: Vector2 = player_pos + paddle_size * 0.5 + shake_offset
	if phase == 0:
		var prep_t: float = clamp(phase_frames / max(1.0, prep_frames), 0.0, 1.0)
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.024)
		ImpactShockwaveTextureCache.draw_full_ring(canvas, center, 28.0 + prep_t * 54.0, Color(0.35, 0.95, 1.0), 0.32 + pulse * 0.16)
		ImpactFlareTextureCache.draw_glow(canvas, center, 42.0 + pulse * 10.0, Color(1.0, 0.58, 0.16), 0.22 + prep_t * 0.14)
		var spoke_count: int = 4 if severe_lod else 8
		for i in range(spoke_count):
			var angle: float = TAU * float(i) / float(spoke_count) + phase_frames * 0.11
			var inner: Vector2 = center + Vector2(cos(angle), sin(angle)) * (18.0 + prep_t * 10.0)
			var outer: Vector2 = center + Vector2(cos(angle), sin(angle)) * (54.0 - prep_t * 18.0)
			canvas.draw_line(outer, inner, Color(0.80, 0.96, 1.0, 0.20 + prep_t * 0.38), 1.6, true)
	elif phase == 1:
		var foot: Vector2 = Vector2(center.x, player_pos.y + paddle_size.y) + shake_offset
		canvas.draw_line(foot + Vector2(0.0, -80.0), foot + Vector2(0.0, 18.0), Color(1.0, 0.55, 0.10, 0.38), 18.0, true)
		canvas.draw_line(foot + Vector2(0.0, -60.0), foot + Vector2(0.0, 10.0), Color(0.70, 0.96, 1.0, 0.46), 5.0, true)


func draw_dive_effects(
	canvas: CanvasItem,
	shake_offset: Vector2,
	runtime: Object,
	floating_text_renderer: Object,
	shockwave_frames: float,
	clone_telegraph_frames: float,
	hit_text_frames: float,
	hit_text_float_y: float,
	effect_lod_scale: float = 1.0
) -> void:
	if runtime.dive_active:
		draw_dive_phase_effects(
			canvas,
			shake_offset,
			runtime.dive_active,
			runtime.dive_phase,
			runtime.dive_phase_frames,
			runtime.dive_player_pos,
			runtime.dive_paddle_size,
			runtime.dive_prep_frames_snapshot,
			effect_lod_scale
		)
		if runtime.dive_phase == 2 and runtime.dive_shockwave_timer > 0.0:
			draw_dive_shockwave(
				canvas,
				runtime.dive_shockwave_timer,
				runtime.dive_shockwave_pos,
				shake_offset,
				shockwave_frames,
				runtime.dive_shockwave_max_radius,
				effect_lod_scale
			)
	elif runtime.dive_shockwave_timer > 0.0:
		draw_dive_shockwave(
			canvas,
			runtime.dive_shockwave_timer,
			runtime.dive_shockwave_pos,
			shake_offset,
			shockwave_frames,
			runtime.dive_shockwave_max_radius,
			effect_lod_scale
		)
	draw_dual_glitch_clone_dive_effects(
		canvas,
		runtime.dual_glitch_clone_dive_entries,
		shake_offset,
		runtime.dive_shockwave_pos,
		clone_telegraph_frames,
		shockwave_frames,
		effect_lod_scale
	)
	draw_dive_particle_list(canvas, runtime.dive_particles, shake_offset, effect_lod_scale)
	draw_dive_particle_list(canvas, runtime.dive_charge_particles, shake_offset, effect_lod_scale)
	floating_text_renderer.draw_dive_hit_text(
		canvas,
		runtime.dive_hit_text_timer,
		runtime.dive_hit_text_pos,
		runtime.dive_hit_text_height_ratio,
		shake_offset,
		hit_text_frames,
		hit_text_float_y
	)


func draw_dive_shockwave(
	canvas: CanvasItem,
	timer: float,
	pos: Vector2,
	shake_offset: Vector2,
	shockwave_frames: float,
	shockwave_max_radius: float,
	effect_lod_scale: float = 1.0
) -> void:
	var severe_lod: bool = effect_lod_scale <= SEVERE_LOD_SCALE_THRESHOLD
	var progress: float = 1.0 - clamp(timer / max(1.0, shockwave_frames), 0.0, 1.0)
	var center: Vector2 = pos + shake_offset
	var alpha: float = clamp(1.0 - progress * 0.78, 0.0, 1.0)
	var current_radius: float = lerp(34.0, max(300.0, shockwave_max_radius), progress)
	var half_width: float = 50.0 + current_radius * progress
	var y: float = center.y
	canvas.draw_line(Vector2(center.x - half_width, y), Vector2(center.x + half_width, y), Color(0.90, 0.96, 1.0, 0.34 * alpha), 15.0, true)
	canvas.draw_line(Vector2(center.x - half_width * 0.82, y - 10.0), Vector2(center.x + half_width * 0.82, y - 10.0), Color(0.35, 0.92, 1.0, 0.42 * alpha), 5.0, true)
	var ring_count: int = 1 if severe_lod else 3
	for i in range(ring_count):
		var radius: float = max(10.0, current_radius - float(i) * 28.0)
		ImpactShockwaveTextureCache.draw_full_ring(canvas, center + Vector2(0.0, -8.0), radius, Color(0.38, 0.95, 1.0), alpha * (0.30 - float(i) * 0.06))
	if not severe_lod:
		ImpactFlareTextureCache.draw_glow(canvas, center + Vector2(0.0, -8.0), 58.0 + progress * 40.0, Color(1.0, 0.70, 0.20), alpha * 0.20)


func draw_dual_glitch_clone_dive_effects(
	canvas: CanvasItem,
	entries: Array,
	shake_offset: Vector2,
	fallback_pos: Vector2,
	telegraph_frames: float,
	shockwave_frames: float,
	effect_lod_scale: float = 1.0
) -> void:
	var severe_lod: bool = effect_lod_scale <= SEVERE_LOD_SCALE_THRESHOLD
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var center := Vector2(float(entry.get("x", fallback_pos.x)), float(entry.get("y", fallback_pos.y))) + shake_offset
		var side: int = int(entry.get("side", 0))
		var tint := Color(0.74, 0.28, 1.0) if side < 0 else Color(0.20, 0.95, 1.0)
		if not bool(entry.get("activated", false)):
			var delay_frames: float = float(entry.get("delay_frames", 0.0))
			var telegraph_ratio: float = 1.0 - clamp(delay_frames / max(1.0, telegraph_frames), 0.0, 1.0)
			if telegraph_ratio <= 0.0:
				continue
			var radius: float = 28.0 + telegraph_ratio * 42.0
			ImpactShockwaveTextureCache.draw_full_ring(canvas, center + Vector2(0.0, -8.0), radius, tint, 0.12 + telegraph_ratio * 0.28)
			canvas.draw_line(center + Vector2(-42.0, -10.0), center + Vector2(42.0, -10.0), Color(tint.r, tint.g, tint.b, 0.16 + telegraph_ratio * 0.22), 4.0, true)
			continue
		var timer: float = float(entry.get("timer", 0.0))
		if timer <= 0.0:
			continue
		var progress: float = 1.0 - clamp(timer / max(1.0, shockwave_frames), 0.0, 1.0)
		var alpha: float = max(0.0, 1.0 - progress)
		var half_width: float = 42.0 + 330.0 * progress
		canvas.draw_line(Vector2(center.x - half_width, center.y), Vector2(center.x + half_width, center.y), Color(tint.r, tint.g, tint.b, 0.26 * alpha), 11.0, true)
		canvas.draw_line(Vector2(center.x - half_width * 0.78, center.y - 10.0), Vector2(center.x + half_width * 0.78, center.y - 10.0), Color(0.95, 1.0, 1.0, 0.30 * alpha), 4.0, true)
		var ring_count: int = 1 if severe_lod else 2
		for i in range(ring_count):
			ImpactShockwaveTextureCache.draw_full_ring(
				canvas,
				center + Vector2(0.0, -8.0),
				28.0 + progress * 180.0 + float(i) * 24.0,
				tint,
				alpha * (0.22 - float(i) * 0.05)
			)


func _get_lod_particle_stride(effect_lod_scale: float) -> int:
	return 2 if effect_lod_scale < LOD_PARTICLE_STRIDE_THRESHOLD else 1


func _get_lod_particle_draw_limit(source_count: int, severe_limit: int, severe_lod: bool) -> int:
	if not severe_lod:
		return source_count
	return min(source_count, severe_limit)


func _is_ignition_severe_lod(effect_lod_scale: float) -> bool:
	return effect_lod_scale <= IGNITION_SEVERE_LOD_SCALE_THRESHOLD


func build_emp_strike_fx_state(
	runtime: Object,
	shake_offset: Vector2,
	node_fx_layout: Dictionary,
	shockwave_frames: float,
	jetpack_max_height: float,
	hit_text_frames: float
) -> Dictionary:
	var render_scale: float = max(0.01, float(node_fx_layout.get("render_scale", 1.0)))
	var game_offset: Vector2 = _get_vector2(node_fx_layout.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var hold_active: bool = runtime.dive_hold_start_msec > 0
	var base_pos: Vector2 = runtime.dive_player_pos
	var base_size: Vector2 = runtime.dive_paddle_size
	if hold_active and not runtime.dive_active:
		base_pos = runtime.dive_hold_player_pos
		base_size = runtime.dive_hold_paddle_size
	var player_center: Vector2 = base_pos + base_size * 0.5
	var foot: Vector2 = Vector2(player_center.x, base_pos.y + base_size.y)
	var hit_text_pos: Vector2 = runtime.dive_hit_text_pos
	if runtime.dive_hit_text_timer > 0.0:
		hit_text_pos.x = clamp(hit_text_pos.x, 96.0, 664.0)
		hit_text_pos.y = clamp(hit_text_pos.y, 84.0, 704.0)
	var shock_progress: float = 1.0 - clamp(runtime.dive_shockwave_timer / max(1.0, shockwave_frames), 0.0, 1.0)
	var shock_alpha: float = 0.0
	if runtime.dive_shockwave_timer > 0.0:
		shock_alpha = clamp(1.0 - shock_progress * 0.78, 0.0, 1.0)
	return {
		"render_scale": render_scale,
		"phase": runtime.dive_phase if runtime.dive_active else -1,
		"hold_active": hold_active,
		"hold_ratio": runtime.dive_hold_ratio,
		"prep_progress": clamp(runtime.dive_phase_frames / max(1.0, runtime.dive_prep_frames_snapshot), 0.0, 1.0) if runtime.dive_active and runtime.dive_phase == 0 else 0.0,
		"shockwave_progress": shock_progress,
		"shockwave_alpha": shock_alpha,
		"shockwave_radius": runtime.get_emp_shockwave_radius(),
		"height_ratio": clamp(runtime.dive_height_snapshot / jetpack_max_height, 0.0, 1.0),
		"hit_text_timer": runtime.dive_hit_text_timer,
		"hit_text_frames": hit_text_frames,
		"start_msec": runtime.dive_effect_start_msec,
		"shockwave_spawn_msec": runtime.dive_shockwave_spawn_msec,
		"hit_spawn_msec": runtime.dive_hit_feedback_msec,
		"screen_player_center": game_offset + (player_center + shake_offset) * render_scale,
		"screen_foot": game_offset + (foot + shake_offset) * render_scale,
		"screen_shockwave_center": game_offset + (runtime.dive_shockwave_pos + shake_offset) * render_scale,
		"screen_hit_pos": game_offset + (runtime.dive_hit_text_pos + shake_offset) * render_scale,
		"screen_hit_text_pos": game_offset + (hit_text_pos + shake_offset) * render_scale,
	}


func draw_hit_particle_list(
	canvas: CanvasItem,
	particles: Array,
	shake_offset: Vector2,
	phantom: bool,
	glow_size_threshold: float,
	effect_lod_scale: float = 1.0
) -> void:
	var severe_lod: bool = effect_lod_scale <= SEVERE_LOD_SCALE_THRESHOLD
	var stride: int = _get_lod_particle_stride(effect_lod_scale)
	var draw_limit: int = _get_lod_particle_draw_limit(
		particles.size(),
		SEVERE_LOD_PHANTOM_HIT_PARTICLE_DRAW_LIMIT if phantom else SEVERE_LOD_HIT_PARTICLE_DRAW_LIMIT,
		severe_lod
	)
	var particle_index := 0
	var drawn_count := 0
	for particle_value in particles:
		particle_index += 1
		if stride > 1 and particle_index % stride != 0:
			continue
		if drawn_count >= draw_limit:
			break
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var life: float = max(0.0, float(particle.get("life", 0.0)))
		var max_life: float = max(1.0, float(particle.get("max_life", 1.0)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		if alpha <= 0.01:
			continue
		var pos: Vector2 = _get_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(particle.get("size", 3.0)) * (0.45 + alpha * 0.55))
		var color := Color(0.55, 0.12, 0.82, 1.0)
		if phantom:
			var color_value: Variant = particle.get("color", Color(0.50, 0.12, 0.78, 1.0))
			color = color_value if color_value is Color else Color(0.50, 0.12, 0.78, 1.0)
		if size > glow_size_threshold:
			canvas.draw_circle(pos, size + (3.0 if phantom else 1.5), Color(color.r, color.g, color.b, alpha * (0.28 if phantom else 0.18)))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, alpha * 0.86))
		if phantom and bool(particle.get("glow", false)) and size > glow_size_threshold:
			canvas.draw_circle(pos, max(1.0, size * 0.45), Color(0.92, 0.56, 1.0, alpha * 0.62))
		drawn_count += 1


func get_nerve_strike_draw_constants(
	dash_frames: float,
	return_hit_frames: float,
	return_miss_frames: float,
	slash_vfx_frames: float,
	clone_stagger_frames: float,
	clone_slash_frames: float
) -> Dictionary:
	return {
		"dash_frames": dash_frames,
		"return_hit_frames": return_hit_frames,
		"return_miss_frames": return_miss_frames,
		"slash_vfx_frames": slash_vfx_frames,
		"clone_stagger_frames": clone_stagger_frames,
		"clone_slash_frames": clone_slash_frames,
	}


func draw_nerve_strike_runtime_effects(
	canvas: CanvasItem,
	shake_offset: Vector2,
	runtime: Object,
	dash_frames: float,
	return_hit_frames: float,
	return_miss_frames: float,
	slash_vfx_frames: float,
	clone_stagger_frames: float,
	clone_slash_frames: float
) -> void:
	draw_nerve_strike_effects(
		canvas,
		shake_offset,
		runtime,
		get_nerve_strike_draw_constants(
			dash_frames,
			return_hit_frames,
			return_miss_frames,
			slash_vfx_frames,
			clone_stagger_frames,
			clone_slash_frames
		)
	)


func draw_nerve_strike_effects(canvas: CanvasItem, shake_offset: Vector2, runtime: Object, constants: Dictionary) -> void:
	var tick: float = float(Time.get_ticks_msec())
	if runtime.nerve_strike_active:
		var center: Vector2 = runtime.nerve_strike_pos + runtime.nerve_strike_paddle_size * 0.5 + shake_offset
		var dash_center: Vector2 = runtime.nerve_strike_dash_target_pos + runtime.nerve_strike_paddle_size * 0.5 + shake_offset
		if runtime.nerve_strike_phase == 0:
			var progress: float = clamp(runtime.nerve_strike_phase_frames / max(1.0, float(constants.get("dash_frames", 30.0))), 0.0, 1.0)
			var start_center: Vector2 = runtime.nerve_strike_start_pos + runtime.nerve_strike_paddle_size * 0.5 + shake_offset
			for i in range(4):
				var trail_t: float = clamp(progress - float(i) * 0.10, 0.0, 1.0)
				if trail_t <= 0.0:
					continue
				var trail_pos: Vector2 = start_center.lerp(dash_center, 0.5 - 0.5 * cos(trail_t * PI))
				var alpha: float = max(0.0, 0.30 - float(i) * 0.055)
				ImpactFlareTextureCache.draw_glow(canvas, trail_pos, 38.0 - float(i) * 4.0, Color(0.55, 0.08, 0.95), alpha)
				canvas.draw_line(trail_pos + Vector2(-42.0, 10.0), trail_pos + Vector2(42.0, -12.0), Color(0.58, 0.10, 0.92, alpha), 3.0, true)
			ImpactFlareTextureCache.draw_glow(canvas, center, 54.0, Color(0.18, 0.95, 0.56), 0.22)
		elif runtime.nerve_strike_phase == 1 and runtime.nerve_strike_hit_confirmed:
			canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(760.0, 750.0)), Color(0.06, 0.0, 0.10, 0.22))
			var pulse: float = 0.5 + 0.5 * sin(tick * 0.024)
			ImpactShockwaveTextureCache.draw_full_ring(canvas, center, 44.0 + pulse * 18.0, Color(0.58, 0.10, 0.92), 0.28)
			ImpactFlareTextureCache.draw_glow(canvas, center, 78.0 + pulse * 12.0, Color(0.18, 1.0, 0.58), 0.24)
			var font: Font = ThemeDB.fallback_font
			if font != null:
				var text := LanguageSettings.translate_text("베놈 엣지!")
				canvas.draw_string(font, center + Vector2(-74.0, -82.0), text, HORIZONTAL_ALIGNMENT_CENTER, 148.0, 24, Color(0.02, 0.0, 0.04, 0.86))
				canvas.draw_string(font, center + Vector2(-76.0, -84.0), text, HORIZONTAL_ALIGNMENT_CENTER, 148.0, 24, Color(0.88, 0.60, 1.0, 0.94))
		elif runtime.nerve_strike_phase == 2:
			var return_frames: float = float(constants.get("return_hit_frames", 138.0)) if runtime.nerve_strike_hit_confirmed else float(constants.get("return_miss_frames", 18.0))
			var progress2: float = clamp(runtime.nerve_strike_phase_frames / max(1.0, return_frames), 0.0, 1.0)
			ImpactFlareTextureCache.draw_glow(canvas, center, 42.0 * (1.0 - progress2), Color(0.20, 0.95, 0.58), 0.20 * (1.0 - progress2))

	if runtime.nerve_strike_slash_vfx_frames > 0.0:
		var vfx_ratio: float = 1.0 - clamp(runtime.nerve_strike_slash_vfx_frames / max(1.0, float(constants.get("slash_vfx_frames", 30.0))), 0.0, 1.0)
		draw_nerve_strike_slash_arcs(canvas, runtime.nerve_strike_slash_center + shake_offset, vfx_ratio, 1.0)

	draw_nerve_strike_clone_slashes(
		canvas,
		runtime.nerve_strike_clone_slashes,
		shake_offset,
		float(constants.get("clone_stagger_frames", 12.0)),
		float(constants.get("clone_slash_frames", 12.0))
	)


func draw_nerve_strike_clone_slashes(
	canvas: CanvasItem,
	clone_slashes: Array,
	shake_offset: Vector2,
	stagger_frames: float,
	slash_frames: float
) -> void:
	for entry_value in clone_slashes:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var state: String = str(entry.get("state", "pending"))
		var side: int = int(entry.get("side", 0))
		var tint := Color(0.74, 0.24, 1.0) if side < 0 else Color(0.14, 0.95, 0.76)
		if state == "pending":
			var delay_ratio: float = 1.0 - clamp(float(entry.get("delay_frames", 0.0)) / max(1.0, stagger_frames * (1.0 if side < 0 else 2.0)), 0.0, 1.0)
			var origin: Vector2 = _get_vector2(entry.get("origin", Vector2.ZERO), Vector2.ZERO) + shake_offset
			ImpactShockwaveTextureCache.draw_full_ring(canvas, origin, 22.0 + delay_ratio * 24.0, tint, 0.12 + delay_ratio * 0.20)
		elif state == "travel":
			var pos: Vector2 = _get_vector2(entry.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
			var target: Vector2 = _get_vector2(entry.get("target", Vector2.ZERO), Vector2.ZERO) + shake_offset
			canvas.draw_line(pos, target, Color(tint.r, tint.g, tint.b, 0.34), 3.0, true)
			ImpactFlareTextureCache.draw_glow(canvas, pos, 28.0, tint, 0.20)
		elif state == "slash":
			var slash_ratio: float = 1.0 - clamp(float(entry.get("timer", 0.0)) / max(1.0, slash_frames), 0.0, 1.0)
			draw_nerve_strike_slash_arcs(canvas, _get_vector2(entry.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset, slash_ratio, 0.72)


func draw_nerve_strike_slash_arcs(canvas: CanvasItem, center: Vector2, progress: float, alpha_scale: float) -> void:
	var alpha: float = max(0.0, 1.0 - progress) * alpha_scale
	if alpha <= 0.01:
		return
	ImpactFlareTextureCache.draw_glow(canvas, center, 86.0 + progress * 26.0, Color(0.54, 0.08, 0.92), 0.22 * alpha)
	for i in range(3):
		var radius: float = 48.0 + float(i) * 18.0 + progress * 54.0
		var start_angle: float = -PI * 0.80 + float(i) * 0.42 + progress * 0.34
		canvas.draw_arc(center, radius, start_angle, start_angle + PI * 1.30, 28, Color(0.82, 0.25, 1.0, 0.56 * alpha), 4.0 - float(i) * 0.65)
		canvas.draw_arc(center + Vector2(0.0, 6.0), radius * 0.82, start_angle + PI, start_angle + PI * 2.10, 24, Color(0.20, 1.0, 0.60, 0.38 * alpha), 2.4)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
