extends RefCounted

const MAX_RENDERED_ADVERSITY_ARMOR_PARTICLES := 28


func draw_field_effects(
	runtime: Object,
	canvas: CanvasItem,
	shake_offset: Vector2,
	ragnarok_impact_effect_duration: float,
	ragnarok_electric_stun_intensity: float
) -> void:
	if canvas == null or runtime == null:
		return
	var impact_elapsed: float = runtime._ragnarok_impact_elapsed()
	var impact_active: bool = impact_elapsed < ragnarok_impact_effect_duration
	var stun_active: bool = runtime.ragnarok_boss_stun_timer_frames > 0.0
	var poseidon_visible: bool = runtime.poseidon_capture_active or runtime.poseidon_vortex_active or not runtime.poseidon_particles.is_empty() or not runtime.poseidon_water_trail.is_empty() or runtime.poseidon_explosion_active
	var knee_pads_visible: bool = runtime.knee_pads_flash_timer_frames > 0.0 or not runtime.knee_pads_particles.is_empty()
	var soul_burst_visible: bool = runtime.soul_burst_effect_timer_frames > 0.0 or not runtime.soul_burst_particles.is_empty() or not runtime.soul_burst_shockwaves.is_empty() or not runtime.soul_burst_wind_trails.is_empty()
	var foul_whistle_visible: bool = runtime.foul_whistle_state.animation_active
	var revival_visible: bool = runtime.revival_state.is_effect_active()
	var sensor_visible: bool = runtime.sensor_auto_dash_effect_timer_frames > 0.0
	var venom_mist_visible: bool = runtime.venom_mist_field_active or not runtime.venom_mist_particles.is_empty()
	var rainbow_glove_visible: bool = runtime.rainbow_fur_glove_aura_timer_frames > 0.0 or not runtime.rainbow_fur_glove_particles.is_empty()
	var adversity_armor_visible: bool = runtime._is_adversity_armor_effect_active()
	var shrapnel_armor_visible: bool = runtime._is_shrapnel_armor_effect_active()
	var celestial_armor_visible: bool = runtime.celestial_armor_state.is_wave_active()
	var hermes_visible: bool = runtime.hermes_shoes_state.is_visible(runtime.is_hermes_shoes_active())
	var baal_visible: bool = runtime.baal_boots_effect_state.is_visible(
		runtime.baal_boots_weather_state.cinematic_active,
		runtime.baal_boots_weather_state.round_effect_active
	)
	var acquisition_visible: bool = runtime.acquisition_cinematic != null and runtime.acquisition_cinematic.is_active()
	if not impact_active and not stun_active and runtime.ragnarok_sparks.is_empty() and not poseidon_visible and not knee_pads_visible and not soul_burst_visible and not foul_whistle_visible and not revival_visible and not sensor_visible and not venom_mist_visible and not rainbow_glove_visible and not adversity_armor_visible and not shrapnel_armor_visible and not celestial_armor_visible and not hermes_visible and not baal_visible and not acquisition_visible:
		return
	if baal_visible:
		runtime._draw_baal_boots_effects(canvas, shake_offset)
	if hermes_visible:
		runtime._draw_hermes_shoes_effect(canvas, shake_offset)
	if venom_mist_visible:
		runtime._draw_venom_mist_effect(canvas, shake_offset)
	if rainbow_glove_visible:
		runtime._draw_rainbow_fur_glove_effect(canvas, shake_offset)
	if adversity_armor_visible:
		runtime._draw_adversity_armor_effect(canvas, shake_offset)
	if shrapnel_armor_visible:
		runtime._draw_shrapnel_armor_effect(canvas, shake_offset)
	if celestial_armor_visible:
		runtime._draw_celestial_armor_effect(canvas, shake_offset)
	if poseidon_visible:
		runtime._draw_poseidon_effects(canvas, shake_offset)
	if knee_pads_visible:
		runtime._draw_knee_pads_effects(canvas, shake_offset)
	if soul_burst_visible:
		runtime._draw_soul_burst_effects(canvas, shake_offset)
	if foul_whistle_visible:
		runtime._draw_foul_whistle_effect(canvas, shake_offset)
	if revival_visible:
		runtime._draw_revival_effect(canvas, shake_offset)
	if sensor_visible:
		runtime._draw_sensor_auto_dash_effect(canvas, shake_offset)
	var center: Vector2 = runtime.ragnarok_impact_center + shake_offset
	if impact_active:
		runtime._draw_ragnarok_impact_rings(canvas, center, impact_elapsed)
	if stun_active:
		runtime._draw_ragnarok_electric_stun_overlay(canvas, center, runtime.ragnarok_stun_target_size, ragnarok_electric_stun_intensity)
	runtime._draw_ragnarok_sparks(canvas, center, shake_offset)
	if acquisition_visible:
		if runtime.acquisition_cinematic != null:
			runtime.acquisition_cinematic.draw(canvas, shake_offset)


func draw_hermes_shoes_effect(
	canvas: CanvasItem,
	shake_offset: Vector2,
	state: Object,
	active: bool,
	trail_life_frames: float,
	move_trail_threshold: float
) -> void:
	if canvas == null or state == null:
		return
	var trails: Array = _as_array(state.get("trails"))
	var player_size: Vector2 = _as_vector2(state.get("player_size"), Vector2.ZERO)
	for trail_value in trails:
		var trail: Dictionary = _as_dict(trail_value)
		var trail_center: Vector2 = _as_vector2(trail.get("center", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var trail_size: Vector2 = _as_vector2(trail.get("size", player_size), player_size)
		var life: float = float(trail.get("life", 0.0))
		var max_life: float = max(1.0, float(trail.get("max_life", trail_life_frames)))
		var fade: float = clamp(life / max_life, 0.0, 1.0)
		if fade <= 0.01:
			continue
		var rect := Rect2(trail_center - trail_size * 0.5, trail_size)
		canvas.draw_rect(rect, Color(150.0 / 255.0, 210.0 / 255.0, 1.0, 0.15 * fade), false, 2.0)
		var direction: float = sign(float(trail.get("direction", 0.0)))
		if abs(direction) <= 0.01:
			direction = 1.0
		for line_index in range(3):
			var y: float = rect.position.y + trail_size.y * (0.25 + float(line_index) * 0.25)
			var start := Vector2(rect.position.x + (trail_size.x if direction > 0.0 else 0.0), y)
			var end := start - Vector2(direction * (18.0 + float(line_index) * 3.0), 0.0)
			canvas.draw_line(start, end, Color(1.0, 245.0 / 255.0, 150.0 / 255.0, 0.34 * fade), 2.0)

	var player_center: Vector2 = _as_vector2(state.get("player_center"), Vector2.ZERO)
	if not active or player_center == Vector2.ZERO:
		return
	var center: Vector2 = player_center + shake_offset
	var half_width: float = max(18.0, player_size.x * 0.5)
	var half_height: float = max(12.0, player_size.y * 0.5)
	var flap: float = sin(float(state.get("phase"))) * 3.5
	var wing_color := Color(1.0, 1.0, 1.0, 0.50)
	var wing_glow := Color(160.0 / 255.0, 215.0 / 255.0, 1.0, 0.18)
	var wing_outline := Color(1.0, 220.0 / 255.0, 70.0 / 255.0, 0.78)
	var left_anchor := Vector2(center.x - half_width, center.y)
	var right_anchor := Vector2(center.x + half_width, center.y)
	var left_points := PackedVector2Array([
		left_anchor,
		left_anchor + Vector2(-16.0 + flap, -half_height * 0.42),
		left_anchor + Vector2(-30.0 + flap, 0.0),
		left_anchor + Vector2(-16.0 + flap, half_height * 0.42),
	])
	var right_points := PackedVector2Array([
		right_anchor,
		right_anchor + Vector2(16.0 - flap, -half_height * 0.42),
		right_anchor + Vector2(30.0 - flap, 0.0),
		right_anchor + Vector2(16.0 - flap, half_height * 0.42),
	])
	draw_hermes_wing_polygon(canvas, left_points, wing_glow, wing_outline, 4.0)
	draw_hermes_wing_polygon(canvas, right_points, wing_glow, wing_outline, 4.0)
	draw_hermes_wing_polygon(canvas, left_points, wing_color, wing_outline, 1.8)
	draw_hermes_wing_polygon(canvas, right_points, wing_color, wing_outline, 1.8)

	var last_move_delta_x: float = float(state.get("last_move_delta_x"))
	if abs(last_move_delta_x) >= move_trail_threshold:
		var direction: float = sign(last_move_delta_x)
		var line_side_x: float = center.x - half_width - 12.0 if direction > 0.0 else center.x + half_width + 12.0
		for line_index in range(3):
			var y: float = center.y - half_height * 0.45 + float(line_index) * half_height * 0.45
			var start := Vector2(line_side_x, y)
			var end := start - Vector2(direction * (24.0 + float(line_index) * 4.0), 0.0)
			canvas.draw_line(start, end, Color(1.0, 1.0, 150.0 / 255.0, 0.46), 2.0)


func draw_hermes_wing_polygon(
	canvas: CanvasItem,
	points: PackedVector2Array,
	fill_color: Color,
	outline_color: Color,
	outline_width: float
) -> void:
	if canvas == null or points.size() < 3:
		return
	canvas.draw_colored_polygon(points, fill_color)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	canvas.draw_polyline(outline, outline_color, outline_width, true)


func draw_celestial_armor_effect(
	canvas: CanvasItem,
	shake_offset: Vector2,
	state: Object,
	wave_radius_max: float,
	shard_count: int,
	arc_segments: int
) -> void:
	if canvas == null or state == null:
		return
	var wave_timer_frames: float = float(state.get("wave_timer_frames"))
	var wave_life_frames: float = float(state.get("wave_life_frames"))
	if wave_timer_frames <= 0.0 or wave_life_frames <= 0.0:
		return
	var elapsed: float = max(0.0, wave_life_frames - wave_timer_frames)
	var t: float = clamp(elapsed / max(1.0, wave_life_frames), 0.0, 1.0)
	var ease_out: float = 1.0 - pow(1.0 - t, 2.3)
	var radius: float = 18.0 + ease_out * wave_radius_max
	var fade: float = pow(1.0 - t, 1.1)
	if fade <= 0.02:
		return
	var center: Vector2 = _as_vector2(state.get("wave_center"), Vector2.ZERO) + shake_offset
	var thickness: float = max(1.0, 7.0 * (1.0 - pow(t, 0.9)))
	var rainbow_stops: Array[Color] = [
		Color(1.0, 70.0 / 255.0, 110.0 / 255.0),
		Color(1.0, 170.0 / 255.0, 70.0 / 255.0),
		Color(1.0, 240.0 / 255.0, 90.0 / 255.0),
		Color(120.0 / 255.0, 1.0, 140.0 / 255.0),
		Color(90.0 / 255.0, 200.0 / 255.0, 1.0),
		Color(140.0 / 255.0, 110.0 / 255.0, 1.0),
		Color(220.0 / 255.0, 120.0 / 255.0, 1.0),
	]
	var wave_seed: float = float(state.get("wave_seed"))
	var phase: float = float(state.get("phase"))
	var rotation: float = wave_seed + phase * 0.6
	for idx in range(rainbow_stops.size()):
		var base_color: Color = rainbow_stops[idx]
		var start_angle: float = (float(idx) / float(rainbow_stops.size())) * TAU + rotation
		var end_angle: float = (float(idx + 1) / float(rainbow_stops.size())) * TAU + rotation
		var glow_color := Color(base_color.r, base_color.g, base_color.b, 0.22 * fade)
		var core_color := Color(base_color.r, base_color.g, base_color.b, 0.82 * fade)
		canvas.draw_arc(center, radius + 1.0, start_angle, end_angle, arc_segments, glow_color, thickness + 6.0, true)
		canvas.draw_arc(center, radius, start_angle, end_angle, arc_segments, core_color, thickness, true)
	canvas.draw_arc(center, max(2.0, radius - 3.0), 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.46 * fade * (1.0 - t)), 1.0, true)

	for shard_idx in range(shard_count):
		var angle: float = (float(shard_idx) / float(shard_count)) * TAU + wave_seed * 1.7 - phase * 0.9
		var jitter: float = sin(phase * 4.2 + float(shard_idx) * 1.3) * 2.0
		var shard_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius + jitter)
		var shard_alpha: float = 0.86 * fade * (1.0 - t * 0.6)
		if shard_alpha <= 0.02:
			continue
		var shard_color: Color = rainbow_stops[shard_idx % rainbow_stops.size()]
		canvas.draw_circle(shard_pos, 2.1, Color(shard_color.r, shard_color.g, shard_color.b, shard_alpha))
		canvas.draw_circle(shard_pos, 0.9, Color(1.0, 1.0, 1.0, min(1.0, shard_alpha + 0.15)))

	if t < 0.35:
		var core_ratio: float = 1.0 - t / 0.35
		canvas.draw_circle(center, max(2.0, 12.0 * core_ratio), Color(1.0, 1.0, 1.0, 0.68 * core_ratio))


func draw_venom_mist_effect(
	canvas: CanvasItem,
	shake_offset: Vector2,
	mist_center: Vector2,
	duration_frames: float,
	timer_frames: float,
	particles: Array,
	boss_in_field: bool,
	radius: float,
	alpha: float
) -> void:
	if canvas == null or alpha <= 0.0:
		return
	# Low-cost procedural fog until a dedicated Godot particle/sheet remaster is authored.
	var center: Vector2 = mist_center + shake_offset
	var elapsed: float = max(0.0, duration_frames - timer_frames)
	for layer in range(5):
		var ratio: float = 1.0 - float(layer) / 5.0
		var breathe: float = 1.0 + 0.08 * sin(elapsed * 0.025 * 1.2 + float(layer) * 0.9)
		var layer_radius: float = radius * (0.30 + float(layer) * 0.16) * breathe
		var fill := Color(
			20.0 / 255.0,
			(130.0 + 50.0 * ratio) / 255.0,
			(60.0 + 40.0 * (1.0 - ratio)) / 255.0,
			0.18 * ratio * alpha
		)
		canvas.draw_circle(center, layer_radius, fill)
	for particle_value in particles:
		var particle: Dictionary = _as_dict(particle_value)
		var offset: Vector2 = _as_vector2(particle.get("offset", Vector2.ZERO), Vector2.ZERO)
		var life_ratio: float = clamp(float(particle.get("life", 0.0)) / max(1.0, float(particle.get("max_life", 1.0))), 0.0, 1.0)
		var particle_alpha: float = float(particle.get("alpha", 0.2)) * alpha * min(1.0, life_ratio * 1.35)
		if particle_alpha <= 0.01:
			continue
		var layer_id: int = int(particle.get("layer", 1))
		var color := Color(35.0 / 255.0, 160.0 / 255.0, 80.0 / 255.0, particle_alpha)
		if layer_id == 0:
			color = Color(25.0 / 255.0, 135.0 / 255.0, 70.0 / 255.0, particle_alpha * 0.75)
		elif layer_id == 2:
			color = Color(130.0 / 255.0, 235.0 / 255.0, 115.0 / 255.0, particle_alpha * 0.82)
		canvas.draw_circle(center + offset, float(particle.get("size", 12.0)), color)
	if boss_in_field:
		canvas.draw_arc(center, radius * 0.86, 0.0, TAU, 52, Color(0.55, 1.0, 0.35, 0.28 * alpha), 2.0)


func draw_rainbow_fur_glove_effect(
	canvas: CanvasItem,
	shake_offset: Vector2,
	aura_center: Vector2,
	aura_life_frames: float,
	aura_timer_frames: float,
	aura_phase: float,
	particles: Array,
	colors: Array
) -> void:
	if canvas == null:
		return
	var center: Vector2 = aura_center + shake_offset
	var life_frames: float = max(1.0, aura_life_frames)
	if aura_timer_frames > 0.0:
		var progress: float = 1.0 - clamp(aura_timer_frames / life_frames, 0.0, 1.0)
		var ease_out: float = 1.0 - pow(1.0 - progress, 2.0)
		var fade: float = clamp(aura_timer_frames / life_frames, 0.0, 1.0)
		var ring_base: float = 20.0 + 110.0 * ease_out
		var thickness: float = max(1.0, 6.0 * fade)
		var color_count: int = colors.size()
		for idx in range(color_count):
			var base_color: Color = _as_color(colors[idx], Color.WHITE)
			var wobble: float = sin(aura_phase + float(idx) * TAU / float(color_count)) * 6.0
			var radius: float = max(4.0, ring_base + (float(idx) - 2.0) * 4.0 + wobble)
			canvas.draw_arc(center, radius + 2.0, 0.0, TAU, 72, Color(base_color.r, base_color.g, base_color.b, 0.16 * fade), thickness + 6.0, true)
			canvas.draw_arc(center, radius, 0.0, TAU, 72, Color(base_color.r, base_color.g, base_color.b, 0.70 * fade), thickness, true)
		canvas.draw_circle(center, max(2.0, 18.0 * fade), Color(1.0, 1.0, 1.0, 0.62 * fade))
		for ray_idx in range(12):
			var angle: float = float(ray_idx) * TAU / 12.0 + aura_phase
			var color: Color = _as_color(colors[ray_idx % color_count], Color.WHITE)
			var start_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * max(2.0, ring_base - 12.0)
			var end_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * (ring_base + 30.0 * fade)
			canvas.draw_line(start_pos, end_pos, Color(color.r, color.g, color.b, 0.58 * fade), max(1.0, 3.0 * fade), true)

	for particle_value in particles:
		var particle: Dictionary = _as_dict(particle_value)
		var life: float = float(particle.get("life", 0.0))
		var max_life: float = max(1.0, float(particle.get("max_life", 1.0)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		if alpha <= 0.02:
			continue
		var pos: Vector2 = _as_vector2(particle.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(particle.get("size", 2.0)) * (0.8 + 0.25 * sin(float(particle.get("phase", 0.0)))))
		var color: Color = _as_color(particle.get("color", Color.WHITE), Color.WHITE)
		canvas.draw_circle(pos, size + 3.0, Color(color.r, color.g, color.b, 0.17 * alpha))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, 0.86 * alpha))
		canvas.draw_circle(pos, max(0.8, size * 0.38), Color(1.0, 1.0, 1.0, 0.68 * alpha))


func draw_adversity_armor_effect(
	canvas: CanvasItem,
	shake_offset: Vector2,
	context: Dictionary,
	aura_particles: Array,
	barrier_particles: Array
) -> void:
	if canvas == null:
		return
	var active: bool = bool(context.get("invincible", false))
	var barrier_y: float = float(context.get("barrier_y", 732.0))
	var phase: float = float(context.get("phase", 0.0))
	var timer_ratio: float = clamp(float(context.get("timer_ratio", 0.0)), 0.0, 1.0)
	var flash_timer: float = float(context.get("flash_timer_frames", 0.0))
	var flash_frames: float = max(1.0, float(context.get("flash_frames", 30.0)))
	var flash: float = clamp(flash_timer / flash_frames, 0.0, 1.0)
	if active:
		var line_y: float = barrier_y + shake_offset.y
		var core_color := Color(1.0, 0.92, 0.45, 0.68 + 0.18 * sin(phase * 2.1))
		var glow_color := Color(1.0, 0.55, 0.14, 0.18 + 0.12 * timer_ratio)
		canvas.draw_line(Vector2(14.0 + shake_offset.x, line_y), Vector2(746.0 + shake_offset.x, line_y), glow_color, 12.0, true)
		canvas.draw_line(Vector2(24.0 + shake_offset.x, line_y), Vector2(736.0 + shake_offset.x, line_y), core_color, 4.2, true)
		for wave_index in range(3):
			var wave_offset: float = sin(phase + float(wave_index) * 1.7) * (3.0 + float(wave_index))
			var alpha: float = 0.34 - float(wave_index) * 0.07
			canvas.draw_line(
				Vector2(40.0 + shake_offset.x, line_y - 9.0 - float(wave_index) * 7.0 + wave_offset),
				Vector2(720.0 + shake_offset.x, line_y - 9.0 - float(wave_index) * 7.0 - wave_offset),
				Color(1.0, 0.78, 0.22, alpha * timer_ratio),
				max(1.0, 2.4 - float(wave_index) * 0.3),
				true
			)
		var fill_width: float = 190.0 * timer_ratio
		var gauge_origin := Vector2(285.0, barrier_y - 28.0) + shake_offset
		canvas.draw_rect(Rect2(gauge_origin, Vector2(190.0, 5.0)), Color(0.15, 0.09, 0.02, 0.34), true)
		canvas.draw_rect(Rect2(gauge_origin, Vector2(fill_width, 5.0)), Color(1.0, 0.74, 0.24, 0.72), true)
	if flash > 0.0:
		var center: Vector2 = _as_vector2(context.get("last_reflect_center", Vector2(380.0, barrier_y)), Vector2(380.0, barrier_y)) + shake_offset
		for ring_index in range(3):
			var radius: float = 26.0 + (1.0 - flash) * 86.0 + float(ring_index) * 18.0
			canvas.draw_arc(center, radius, PI, TAU, 56, Color(1.0, 0.78, 0.25, flash * (0.48 - float(ring_index) * 0.10)), 3.0, true)

	for particle_index in range(_recent_start(aura_particles, MAX_RENDERED_ADVERSITY_ARMOR_PARTICLES), aura_particles.size()):
		_draw_adversity_armor_particle(
			canvas,
			_as_dict(aura_particles[particle_index]),
			shake_offset,
			Color(1.0, 0.80, 0.28, 1.0),
			true
		)
	for particle_index in range(_recent_start(barrier_particles, MAX_RENDERED_ADVERSITY_ARMOR_PARTICLES), barrier_particles.size()):
		_draw_adversity_armor_particle(
			canvas,
			_as_dict(barrier_particles[particle_index]),
			shake_offset,
			Color(1.0, 0.68, 0.18, 1.0),
			false
		)


func _draw_adversity_armor_particle(
	canvas: CanvasItem,
	particle: Dictionary,
	shake_offset: Vector2,
	base_color: Color,
	aura: bool
) -> void:
	var life: float = float(particle.get("life", 0.0))
	var max_life: float = max(1.0, float(particle.get("max_life", 1.0)))
	var alpha: float = clamp(life / max_life, 0.0, 1.0)
	if alpha <= 0.02:
		return
	var pos: Vector2 = _as_vector2(particle.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var size: float = max(0.8, float(particle.get("size", 2.0)))
	var glow_alpha: float = 0.16 if aura else 0.22
	canvas.draw_circle(pos, size + 3.0, Color(base_color.r, base_color.g, base_color.b, glow_alpha * alpha))
	canvas.draw_circle(pos, size, Color(base_color.r, base_color.g, base_color.b, 0.72 * alpha))
	canvas.draw_circle(pos, max(0.6, size * 0.35), Color(1.0, 0.96, 0.72, 0.72 * alpha))

func draw_shrapnel_armor_effect(
	canvas: CanvasItem,
	shake_offset: Vector2,
	flash_timer_frames: float,
	flash_center: Vector2,
	shards: Array,
	dust_particles: Array,
	boss_impact_timer_frames: float,
	boss_impact_center: Vector2,
	flash_frames: float,
	shard_life_frames: float,
	boss_impact_frames: float
) -> void:
	if canvas == null:
		return
	if flash_timer_frames > 0.0:
		var fade: float = clamp(flash_timer_frames / flash_frames, 0.0, 1.0)
		var center: Vector2 = flash_center + shake_offset
		canvas.draw_arc(center, 22.0 + 14.0 * (1.0 - fade), PI, TAU * 2.0, 32, Color(1.0, 0.66, 0.22, 0.58 * fade), 3.0, true)
		canvas.draw_circle(center, 13.0 + 8.0 * (1.0 - fade), Color(1.0, 0.48, 0.12, 0.18 * fade))

	for shard_value in shards:
		var shard: Dictionary = _as_dict(shard_value)
		var life: float = float(shard.get("life", 0.0))
		var max_life: float = max(1.0, float(shard.get("max_life", shard_life_frames)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		var size: float = max(1.0, float(shard.get("size", 4.0)))
		var color_shift: float = float(shard.get("color_shift", 0.0)) / 255.0
		var shard_color := Color(1.0, clamp(0.48 + color_shift, 0.25, 0.75), 0.10, 0.92 * alpha)
		var trail: Array = _as_array(shard.get("trail", []))
		for trail_index in range(trail.size()):
			var trail_pos: Vector2 = _as_vector2(trail[trail_index], Vector2.ZERO) + shake_offset
			var trail_alpha: float = 0.08 + 0.20 * float(trail_index + 1) / max(1.0, float(trail.size()))
			canvas.draw_circle(trail_pos, max(1.0, size * 0.48), Color(1.0, 0.52, 0.12, trail_alpha * alpha))
		var position: Vector2 = _as_vector2(shard.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var rotation: float = float(shard.get("rotation", 0.0))
		var long_axis := Vector2(cos(rotation), sin(rotation)) * size * 1.75
		var short_axis := Vector2(-sin(rotation), cos(rotation)) * size * 0.92
		var points := PackedVector2Array([
			position + long_axis,
			position + short_axis,
			position - long_axis,
			position - short_axis,
		])
		canvas.draw_circle(position, size + 4.0, Color(1.0, 0.42, 0.08, 0.18 * alpha))
		canvas.draw_colored_polygon(points, shard_color)
		for point_index in range(points.size()):
			canvas.draw_line(points[point_index], points[(point_index + 1) % points.size()], Color(1.0, 0.92, 0.54, 0.62 * alpha), 1.0, true)
		canvas.draw_circle(position, max(0.8, size * 0.35), Color(1.0, 0.95, 0.72, 0.76 * alpha))

	for particle_value in dust_particles:
		var particle: Dictionary = _as_dict(particle_value)
		var life: float = float(particle.get("life", 0.0))
		var max_life: float = max(1.0, float(particle.get("max_life", 1.0)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		var color: Color = _as_color(particle.get("color", Color(1.0, 0.55, 0.18)), Color(1.0, 0.55, 0.18))
		var pos: Vector2 = _as_vector2(particle.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size: float = max(0.6, float(particle.get("size", 1.5)))
		canvas.draw_circle(pos, size + 1.5, Color(color.r, color.g, color.b, 0.14 * alpha))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, 0.62 * alpha))

	if boss_impact_timer_frames > 0.0:
		var impact_fade: float = clamp(boss_impact_timer_frames / boss_impact_frames, 0.0, 1.0)
		var impact_center: Vector2 = boss_impact_center + shake_offset
		for ring_index in range(2):
			var radius: float = 28.0 + (1.0 - impact_fade) * 42.0 + float(ring_index) * 13.0
			canvas.draw_arc(impact_center, radius, 0.0, TAU, 44, Color(1.0, 0.54, 0.12, 0.54 * impact_fade), max(1.0, 3.0 - float(ring_index)), true)


func draw_knee_pads_effects(
	canvas: CanvasItem,
	shake_offset: Vector2,
	flash_center: Vector2,
	flash_timer_frames: float,
	particles: Array,
	flash_duration_frames: float
) -> void:
	if canvas == null:
		return
	var center: Vector2 = flash_center + shake_offset
	if flash_timer_frames > 0.0:
		var progress: float = 1.0 - clamp(flash_timer_frames / flash_duration_frames, 0.0, 1.0)
		var alpha: float = clamp(flash_timer_frames / flash_duration_frames, 0.0, 1.0)
		for ring_index in range(3):
			var radius: float = 16.0 + progress * 74.0 + float(ring_index) * 13.0
			var ring_alpha: float = max(0.0, alpha * (0.62 - float(ring_index) * 0.13))
			canvas.draw_arc(center, radius, 0.0, TAU, 72, Color(1.0, 0.86, 0.12, ring_alpha), 3.0, true)
		for ray_index in range(8):
			var angle: float = float(ray_index) / 8.0 * TAU + progress * 1.7
			var ray_len: float = 24.0 + progress * 48.0
			var start_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * 10.0
			var end_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * ray_len
			canvas.draw_line(start_pos, end_pos, Color(1.0, 0.93, 0.28, alpha * 0.55), 4.0, true)
			canvas.draw_line(start_pos, end_pos, Color(1.0, 1.0, 1.0, alpha * 0.35), 1.3, true)
		canvas.draw_circle(center, 30.0 * alpha + 6.0, Color(1.0, 0.86, 0.0, alpha * 0.24))
		canvas.draw_circle(center, 7.0 + 6.0 * (1.0 - progress), Color.WHITE, alpha * 0.88)

	for particle_value in particles:
		var particle: Dictionary = _as_dict(particle_value)
		var life: float = max(0.0, float(particle.get("life", 0.0)))
		var max_life: float = max(0.1, float(particle.get("max_life", 30.0)))
		var particle_alpha: float = clamp(life / max_life, 0.0, 1.0)
		var pos: Vector2 = _as_vector2(particle.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(particle.get("size", 2.0)))
		var color: Color = _as_color(particle.get("color", Color(1.0, 0.78, 0.0)), Color(1.0, 0.78, 0.0))
		color.a = particle_alpha
		canvas.draw_circle(pos, size * 2.1, Color(color.r, color.g, color.b, particle_alpha * 0.18))
		canvas.draw_circle(pos, size, color)


func draw_soul_burst_effects(
	canvas: CanvasItem,
	shake_offset: Vector2,
	center_base: Vector2,
	dash_direction: float,
	wind_trails: Array,
	shockwaves: Array,
	particles: Array,
	alpha_cutoff: float
) -> void:
	if canvas == null:
		return
	# Short dash accent: keep this in the shared procedural mythic-effect lane
	# instead of allocating a dedicated particle scene for a sub-second burst.
	var center: Vector2 = center_base + shake_offset
	var direction: float = dash_direction
	if abs(direction) <= 0.01:
		direction = 1.0

	for trail_value in wind_trails:
		var trail: Dictionary = _as_dict(trail_value)
		var life: float = float(trail.get("life", 0.0))
		var max_life: float = max(0.1, float(trail.get("max_life", 1.0)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		if alpha <= alpha_cutoff:
			continue
		var offset: Vector2 = _as_vector2(trail.get("offset", Vector2.ZERO), Vector2.ZERO)
		var length: float = float(trail.get("length", 60.0))
		var base: Vector2 = center + offset
		var start_pos: Vector2 = base - Vector2(direction * length, 0.0)
		var end_pos: Vector2 = base + Vector2(direction * length * 0.26, 0.0)
		var width: float = float(trail.get("width", 2.0))
		canvas.draw_line(start_pos, end_pos, Color(42.0 / 255.0, 0.0, 72.0 / 255.0, 0.22 * alpha), width + 5.0, true)
		canvas.draw_line(start_pos, end_pos, Color(180.0 / 255.0, 86.0 / 255.0, 1.0, 0.58 * alpha), width + 1.2, true)
		canvas.draw_line(start_pos.lerp(end_pos, 0.38), end_pos, Color(245.0 / 255.0, 220.0 / 255.0, 1.0, 0.42 * alpha), max(1.0, width * 0.45), true)

	for wave_value in shockwaves:
		var wave: Dictionary = _as_dict(wave_value)
		var life: float = float(wave.get("life", 0.0))
		var max_life: float = max(0.1, float(wave.get("max_life", 1.0)))
		var progress: float = 1.0 - clamp(life / max_life, 0.0, 1.0)
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		if alpha <= alpha_cutoff:
			continue
		var radius: float = lerp(float(wave.get("start_radius", 20.0)), float(wave.get("max_radius", 92.0)), progress)
		var squeeze: float = float(wave.get("squeeze", 0.72))
		var ring_color := Color(165.0 / 255.0, 72.0 / 255.0, 1.0, 0.62 * alpha)
		canvas.draw_arc(center, radius, 0.0, TAU, 76, Color(45.0 / 255.0, 0.0, 80.0 / 255.0, 0.18 * alpha), 7.0, true)
		draw_soul_burst_ellipse_arc(canvas, center, radius, radius * squeeze, ring_color, 3.0)
		draw_soul_burst_ellipse_arc(canvas, center, radius * 0.74, radius * squeeze * 0.74, Color(1.0, 230.0 / 255.0, 1.0, 0.35 * alpha), 1.2)

	for particle_value in particles:
		var particle: Dictionary = _as_dict(particle_value)
		var life: float = float(particle.get("life", 0.0))
		var max_life: float = max(0.1, float(particle.get("max_life", 1.0)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		if alpha <= alpha_cutoff:
			continue
		var pos: Vector2 = _as_vector2(particle.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(particle.get("size", 2.0)))
		var color: Color = _as_color(particle.get("color", Color(0.72, 0.32, 1.0, 1.0)), Color(0.72, 0.32, 1.0, 1.0))
		canvas.draw_circle(pos, size * 2.2, Color(color.r, color.g, color.b, 0.18 * alpha))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, color.a * alpha))
		canvas.draw_circle(pos, max(1.0, size * 0.38), Color(1.0, 0.88, 1.0, 0.68 * alpha))


func draw_soul_burst_ellipse_arc(
	canvas: CanvasItem,
	center: Vector2,
	radius_x: float,
	radius_y: float,
	color: Color,
	width: float
) -> void:
	if canvas == null:
		return
	var points := PackedVector2Array()
	for idx in range(73):
		var angle: float = TAU * float(idx) / 72.0
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	canvas.draw_polyline(points, color, width, true)


func draw_poseidon_effects(
	canvas: CanvasItem,
	shake_offset: Vector2,
	water_trail: Array,
	particles: Array,
	explosion_active: bool,
	player_center: Vector2,
	explosion_timer: float,
	explosion_particles: Array,
	explosion_flash_duration: float
) -> void:
	# Preserve the Python draw order: trail under vortex particles, charge flash on top.
	draw_poseidon_water_trail(canvas, shake_offset, water_trail)
	draw_poseidon_particles(canvas, shake_offset, particles)
	draw_poseidon_water_explosion(
		canvas,
		shake_offset,
		explosion_active,
		player_center,
		explosion_timer,
		explosion_particles,
		explosion_flash_duration
	)


func draw_poseidon_water_trail(canvas: CanvasItem, shake_offset: Vector2, water_trail: Array) -> void:
	if canvas == null or water_trail.is_empty():
		return
	for droplet_value in water_trail:
		var droplet: Dictionary = _as_dict(droplet_value)
		var life: float = float(droplet.get("life", 0.0))
		var alpha: float = clamp(life * 8.5 / 255.0, 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var size: float = max(0.5, float(droplet.get("size", 4.0)))
		var pos: Vector2 = Vector2(float(droplet.get("x", 0.0)), float(droplet.get("y", 0.0))) + shake_offset
		canvas.draw_circle(pos, size, Color(80.0 / 255.0, 160.0 / 255.0, 1.0, alpha))
		if size > 2.0:
			var highlight_offset: float = size / 3.0
			var highlight_alpha: float = min(1.0, alpha + 50.0 / 255.0) * 0.5
			canvas.draw_circle(
				pos - Vector2(highlight_offset, highlight_offset),
				size / 2.5,
				Color(220.0 / 255.0, 240.0 / 255.0, 1.0, highlight_alpha)
			)
		if size > 3.0:
			canvas.draw_arc(
				pos,
				size,
				0.0,
				TAU,
				24,
				Color(50.0 / 255.0, 120.0 / 255.0, 200.0 / 255.0, alpha / 3.0),
				1.0
			)


func draw_poseidon_particles(canvas: CanvasItem, shake_offset: Vector2, particles: Array) -> void:
	if canvas == null:
		return
	for particle_value in particles:
		var particle: Dictionary = _as_dict(particle_value)
		var size: float = max(0.5, float(particle.get("size", 4.0)))
		var life: float = float(particle.get("life", 0.0))
		var alpha: float = clamp(life * 5.0 / 255.0, 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var pos: Vector2 = Vector2(float(particle.get("x", 0.0)), float(particle.get("y", 0.0))) + shake_offset
		var color: Color = _as_color(particle.get("color", Color(50.0 / 255.0, 200.0 / 255.0, 1.0)), Color(50.0 / 255.0, 200.0 / 255.0, 1.0))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, alpha))
		var highlight_size: float = size / 3.0
		if highlight_size >= 0.5:
			canvas.draw_circle(
				pos - Vector2(highlight_size, highlight_size),
				highlight_size,
				Color(200.0 / 255.0, 230.0 / 255.0, 1.0, alpha * 0.5)
			)


func draw_poseidon_water_explosion(
	canvas: CanvasItem,
	shake_offset: Vector2,
	explosion_active: bool,
	player_center: Vector2,
	explosion_timer: float,
	explosion_particles: Array,
	explosion_flash_duration: float
) -> void:
	if canvas == null or not explosion_active:
		return
	var center: Vector2 = player_center + shake_offset
	if explosion_timer < explosion_flash_duration:
		var flash_progress: float = explosion_timer / explosion_flash_duration
		var flash_alpha: float = (180.0 / 255.0) * (1.0 - flash_progress)
		var flash_size: float = 30.0 + flash_progress * 90.0
		canvas.draw_circle(center, flash_size, Color(120.0 / 255.0, 200.0 / 255.0, 1.0, flash_alpha * 0.5))
		canvas.draw_circle(center, flash_size * 0.5, Color(180.0 / 255.0, 230.0 / 255.0, 1.0, flash_alpha))
	for p_value in explosion_particles:
		var p: Dictionary = _as_dict(p_value)
		var life: float = float(p.get("life", 0.0))
		var max_life: float = max(0.01, float(p.get("max_life", 1.0)))
		var ratio: float = clamp(life / max_life, 0.0, 1.0)
		var size: float = max(2.0, float(p.get("size", 8.0)) * ratio)
		var pos: Vector2 = center + Vector2(float(p.get("offset_x", 0.0)), float(p.get("offset_y", 0.0)))
		var alpha: float = (220.0 / 255.0) * ratio
		var color: Color = _as_color(p.get("color", Color(120.0 / 255.0, 220.0 / 255.0, 1.0)), Color(120.0 / 255.0, 220.0 / 255.0, 1.0))
		canvas.draw_circle(pos, size + 4.0, Color(100.0 / 255.0, 200.0 / 255.0, 1.0, alpha / 3.0))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, alpha))


func draw_ragnarok_impact_rings(
	canvas: CanvasItem,
	center: Vector2,
	elapsed: float,
	impact_effect_duration: float,
	impact_ring_segments: int
) -> void:
	if canvas == null:
		return
	var t: float = clamp(elapsed / impact_effect_duration, 0.0, 1.0)
	var alpha: float = 1.0 - t
	for i in range(3):
		var local_t: float = clamp(t - float(i) * 0.12, 0.0, 1.0)
		var radius: float = 34.0 + 112.0 * local_t + float(i) * 16.0
		var color := Color(120.0 / 255.0, 210.0 / 255.0, 1.0, alpha * (0.58 - float(i) * 0.12))
		canvas.draw_arc(center, radius, 0.0, TAU, impact_ring_segments, color, max(1.0, 5.0 * (1.0 - local_t)))
	var flash_alpha: float = 0.34 * alpha
	canvas.draw_circle(center, 62.0 + 18.0 * t, Color(150.0 / 255.0, 220.0 / 255.0, 1.0, flash_alpha))


func draw_ragnarok_stun_aura(
	canvas: CanvasItem,
	center: Vector2,
	aura_segments: int,
	aura_outer_segments: int
) -> void:
	if canvas == null:
		return
	var now: float = float(Time.get_ticks_msec())
	var pulse: float = 0.5 + 0.5 * sin(now * 0.012)
	canvas.draw_arc(center, 48.0 + pulse * 6.0, 0.0, TAU, aura_segments, Color(110.0 / 255.0, 210.0 / 255.0, 1.0, 0.46), 2.0)
	canvas.draw_arc(center, 72.0 + pulse * 8.0, 0.0, TAU, aura_outer_segments, Color(1.0, 235.0 / 255.0, 150.0 / 255.0, 0.30), 1.5)
	for i in range(5):
		var angle: float = now * 0.006 + float(i) * TAU / 5.0
		var start: Vector2 = center + Vector2(cos(angle), sin(angle)) * (34.0 + pulse * 5.0)
		var end: Vector2 = center + Vector2(cos(angle + 0.42), sin(angle + 0.42)) * (70.0 + pulse * 8.0)
		canvas.draw_line(start, end, Color(215.0 / 255.0, 245.0 / 255.0, 1.0, 0.62), 1.6)


func draw_ragnarok_electric_stun_overlay(
	canvas: CanvasItem,
	center: Vector2,
	target_size: Vector2,
	intensity: float,
	ellipse_segments: int,
	outer_colors: Array,
	core_colors: Array,
	branch_colors: Array,
	spark_colors: Array
) -> void:
	if canvas == null:
		return
	var safe_intensity: float = max(0.25, intensity)
	var electric_center: Vector2 = center + Vector2(0.0, 20.0 * safe_intensity)
	var half_width: float = max(10.0, (target_size.x * 0.5 + 5.0) * safe_intensity)
	var half_height: float = max(18.0, 28.0 * safe_intensity)

	var glow_w: float = half_width * 2.0 + 28.0
	var glow_h: float = half_height * 2.0 + 24.0
	for ring in range(3, 0, -1):
		var ring_alpha: float = (24.0 + float(ring) * 10.0) * safe_intensity / 255.0
		var rx: float = (glow_w - float(ring) * 6.0) * 0.5
		var ry: float = (glow_h - float(ring) * 4.0) * 0.5
		if rx <= 0.0 or ry <= 0.0:
			continue
		var glow_points: PackedVector2Array = make_ragnarok_ellipse_points(electric_center, rx, ry, ellipse_segments)
		canvas.draw_polyline(glow_points, Color(160.0 / 255.0, 210.0 / 255.0, 1.0, ring_alpha), max(1.0, 2.0 * safe_intensity), true)

	var main_arc_count: int = max(1, int(round(1.0 * safe_intensity)))
	for _arc_idx in range(main_arc_count):
		var sx: float = electric_center.x + float(randi_range(int(-half_width / 3.0), int(half_width / 3.0)))
		var sy: float = electric_center.y + float(randi_range(int(-half_height / 2.0), int(half_height / 2.0)))
		var arc_len: float = float(randi_range(int(12.0 * safe_intensity), int(24.0 * safe_intensity)))
		var arc_angle: float = randf_range(0.0, TAU)
		var ex: float = sx + cos(arc_angle) * arc_len
		var ey: float = sy + sin(arc_angle) * arc_len

		var segs: int = randi_range(3, 4)
		var pts := PackedVector2Array()
		pts.append(Vector2(sx, sy))
		for j in range(1, segs):
			var frac: float = float(j) / float(segs)
			var mx: float = sx + (ex - sx) * frac + randf_range(-2.5, 2.5) * safe_intensity
			var my: float = sy + (ey - sy) * frac + randf_range(-2.0, 2.0) * safe_intensity
			pts.append(Vector2(mx, my))
		pts.append(Vector2(ex, ey))

		canvas.draw_polyline(pts, _array_color(outer_colors, Color(100.0 / 255.0, 200.0 / 255.0, 1.0)), max(1.0, 2.0 * safe_intensity), true)
		canvas.draw_polyline(pts, _array_color(core_colors, Color(225.0 / 255.0, 245.0 / 255.0, 1.0)), 1.0, true)

	var branch_count: int = max(4, int(round(float(randi_range(4, 7)) * safe_intensity)))
	for _branch_idx in range(branch_count):
		var bx: float = electric_center.x + float(randi_range(int(-half_width), int(half_width)))
		var by: float = electric_center.y + float(randi_range(int(-half_height), int(half_height)))
		var b_angle: float = randf_range(0.0, TAU)
		var b_len: float = randf_range(8.0, 18.0) * safe_intensity
		var branch_pts := PackedVector2Array()
		branch_pts.append(Vector2(bx, by))
		var b_segs: int = randi_range(2, 4)
		for j in range(1, b_segs + 1):
			var frac_b: float = float(j) / float(b_segs)
			var nx: float = bx + cos(b_angle) * b_len * frac_b + randf_range(-4.0, 4.0) * safe_intensity
			var ny: float = by + sin(b_angle) * b_len * frac_b + randf_range(-4.0, 4.0) * safe_intensity
			branch_pts.append(Vector2(nx, ny))
		canvas.draw_polyline(branch_pts, _array_color(branch_colors, Color(120.0 / 255.0, 220.0 / 255.0, 1.0)), 1.0, true)

	var spark_count: int = max(2, int(round(float(randi_range(2, 4)) * safe_intensity)))
	for _spark_idx in range(spark_count):
		var sp_x: float = electric_center.x + float(randi_range(int(-half_width), int(half_width)))
		var sp_y: float = electric_center.y + float(randi_range(int(-half_height), int(half_height)))
		var sp_size: float = float(randi_range(1, max(2, int(2.0 * safe_intensity))))
		canvas.draw_circle(Vector2(sp_x, sp_y), sp_size, _array_color(spark_colors, Color(1.0, 245.0 / 255.0, 190.0 / 255.0)))


func make_ragnarok_ellipse_points(center: Vector2, radius_x: float, radius_y: float, segments: int) -> PackedVector2Array:
	var count: int = max(12, segments)
	var points := PackedVector2Array()
	for idx in range(count + 1):
		var angle: float = TAU * float(idx) / float(count)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


func draw_ragnarok_sparks(
	canvas: CanvasItem,
	center: Vector2,
	sparks: Array,
	alpha_cutoff: float
) -> void:
	if canvas == null:
		return
	for spark_value in sparks:
		var spark: Dictionary = _as_dict(spark_value)
		var life: float = float(spark.get("life", 0.0))
		var max_life: float = max(0.01, float(spark.get("max_life", 1.0)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		if alpha <= alpha_cutoff:
			continue
		var angle: float = float(spark.get("angle", 0.0))
		var radius: float = float(spark.get("radius", 0.0))
		var direction := Vector2(cos(angle), sin(angle))
		var pos: Vector2 = center + direction * radius
		var tail: Vector2 = center + direction * max(8.0, radius - 18.0)
		var width: float = float(spark.get("width", 1.0))
		canvas.draw_line(tail, pos, Color(70.0 / 255.0, 165.0 / 255.0, 1.0, 0.28 * alpha), width + 3.0)
		canvas.draw_line(tail, pos, Color(225.0 / 255.0, 245.0 / 255.0, 1.0, 0.84 * alpha), width)
		canvas.draw_circle(pos, width + 1.2, Color(1.0, 245.0 / 255.0, 190.0 / 255.0, 0.72 * alpha))


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback


func _recent_start(source: Array, render_limit: int) -> int:
	if render_limit < 0:
		return 0
	return max(0, source.size() - max(0, render_limit))


func _array_color(values: Array, fallback: Color) -> Color:
	if values.is_empty():
		return fallback
	return _as_color(values[randi() % values.size()], fallback)
