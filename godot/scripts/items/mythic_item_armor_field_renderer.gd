extends RefCounted


func draw_adversity_armor_effect(
	canvas: CanvasItem,
	shake_offset: Vector2,
	context: Dictionary,
	aura_particles: Array,
	barrier_particles: Array,
	timer_stack: Object,
	particle_render_limit: int,
	timer_bar_size: Vector2,
	timer_bar_margin: Vector2,
	timer_stack_spacing: float,
	timer_stack_key: String
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
		_draw_adversity_armor_timer_gauge(
			canvas,
			timer_ratio,
			timer_stack,
			timer_bar_size,
			timer_bar_margin,
			timer_stack_spacing,
			timer_stack_key
		)
	if flash > 0.0:
		var center: Vector2 = _as_vector2(context.get("last_reflect_center", Vector2(380.0, barrier_y)), Vector2(380.0, barrier_y)) + shake_offset
		for ring_index in range(3):
			var radius: float = 26.0 + (1.0 - flash) * 86.0 + float(ring_index) * 18.0
			canvas.draw_arc(center, radius, PI, TAU, 56, Color(1.0, 0.78, 0.25, flash * (0.48 - float(ring_index) * 0.10)), 3.0, true)

	for particle_index in range(_recent_start(aura_particles, particle_render_limit), aura_particles.size()):
		_draw_adversity_armor_particle(
			canvas,
			_as_dict(aura_particles[particle_index]),
			shake_offset,
			Color(1.0, 0.80, 0.28, 1.0),
			true
		)
	for particle_index in range(_recent_start(barrier_particles, particle_render_limit), barrier_particles.size()):
		_draw_adversity_armor_particle(
			canvas,
			_as_dict(barrier_particles[particle_index]),
			shake_offset,
			Color(1.0, 0.68, 0.18, 1.0),
			false
		)


func _draw_adversity_armor_timer_gauge(
	canvas: CanvasItem,
	timer_ratio: float,
	timer_stack: Object,
	timer_bar_size: Vector2,
	timer_bar_margin: Vector2,
	timer_stack_spacing: float,
	timer_stack_key: String
) -> void:
	var stack_index: int = 0
	if timer_stack != null and timer_stack.has_method("claim"):
		stack_index = int(timer_stack.claim(timer_stack_key, true))
	var frame_rect := Rect2(_get_adversity_armor_timer_bar_position(stack_index, timer_bar_size, timer_bar_margin, timer_stack_spacing), timer_bar_size)
	var outer_rect := frame_rect.grow(5.0)
	var mid_rect := frame_rect.grow(3.0)
	var border_rect := frame_rect.grow(2.0)
	canvas.draw_rect(outer_rect, Color(0.0, 0.0, 0.0, 0.28))
	canvas.draw_rect(outer_rect, Color(0.20, 0.12, 0.03, 0.94))
	canvas.draw_rect(mid_rect, Color(0.82, 0.48, 0.12, 0.96))
	canvas.draw_rect(mid_rect, Color(1.0, 0.74, 0.24, 0.90), false, 2.0)
	canvas.draw_rect(border_rect, Color(0.18, 0.10, 0.02, 0.96))
	canvas.draw_rect(frame_rect, Color(0.10, 0.06, 0.02, 0.94))

	var fill_width: float = max(1.0, (frame_rect.size.x - 4.0) * clamp(timer_ratio, 0.0, 1.0))
	var fill_rect := Rect2(frame_rect.position + Vector2(2.0, 2.0), Vector2(fill_width, frame_rect.size.y - 4.0))
	canvas.draw_rect(fill_rect, Color(1.0, 0.68, 0.18, 0.98))
	canvas.draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, max(2.0, fill_rect.size.y * 0.34))), Color(1.0, 0.92, 0.45, 0.92))
	for tick_index in range(1, 10):
		var tick_x: float = frame_rect.position.x + 2.0 + (frame_rect.size.x - 4.0) * (float(tick_index) / 10.0)
		canvas.draw_line(
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 4.0),
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			Color(1.0, 0.80, 0.32, 0.76),
			1.0
		)

	if fill_width > 2.0 and fill_width < frame_rect.size.x - 4.0:
		var glint_x: float = frame_rect.position.x + 2.0 + fill_width
		canvas.draw_line(
			Vector2(glint_x, frame_rect.position.y + 2.0),
			Vector2(glint_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			Color(1.0, 1.0, 1.0, 0.46),
			2.0
		)


func _get_adversity_armor_timer_bar_position(
	stack_index: int,
	timer_bar_size: Vector2,
	timer_bar_margin: Vector2,
	timer_stack_spacing: float
) -> Vector2:
	return Vector2(
		760.0 - timer_bar_size.x - timer_bar_margin.x,
		750.0 - timer_bar_margin.y - float(max(0, stack_index)) * timer_stack_spacing
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
	boss_impact_frames: float,
	shard_render_limit: int,
	trail_render_limit: int,
	dust_particle_render_limit: int,
	flash_arc_segments: int,
	boss_impact_arc_segments: int
) -> void:
	if canvas == null:
		return
	if flash_timer_frames > 0.0:
		var fade: float = clamp(flash_timer_frames / flash_frames, 0.0, 1.0)
		var center: Vector2 = flash_center + shake_offset
		canvas.draw_arc(center, 22.0 + 14.0 * (1.0 - fade), PI, TAU * 2.0, flash_arc_segments, Color(1.0, 0.66, 0.22, 0.58 * fade), 3.0, true)
		canvas.draw_circle(center, 13.0 + 8.0 * (1.0 - fade), Color(1.0, 0.48, 0.12, 0.18 * fade))

	for shard_index in range(_recent_start(shards, shard_render_limit), shards.size()):
		var shard: Dictionary = _as_dict(shards[shard_index])
		var life: float = float(shard.get("life", 0.0))
		var max_life: float = max(1.0, float(shard.get("max_life", shard_life_frames)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		var size: float = max(1.0, float(shard.get("size", 4.0)))
		var color_shift: float = float(shard.get("color_shift", 0.0)) / 255.0
		var shard_color := Color(1.0, clamp(0.48 + color_shift, 0.25, 0.75), 0.10, 0.92 * alpha)
		var trail: Array = _as_array(shard.get("trail", []))
		var trail_start: int = _recent_start(trail, trail_render_limit)
		var rendered_trail_count: int = max(1, trail.size() - trail_start)
		for trail_index in range(trail_start, trail.size()):
			var trail_pos: Vector2 = _as_vector2(trail[trail_index], Vector2.ZERO) + shake_offset
			var trail_alpha: float = 0.08 + 0.20 * float(trail_index - trail_start + 1) / float(rendered_trail_count)
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
		var outline := PackedVector2Array([points[0], points[1], points[2], points[3], points[0]])
		canvas.draw_polyline(outline, Color(1.0, 0.92, 0.54, 0.62 * alpha), 1.0, true)
		canvas.draw_circle(position, max(0.8, size * 0.35), Color(1.0, 0.95, 0.72, 0.76 * alpha))

	for particle_index in range(_recent_start(dust_particles, dust_particle_render_limit), dust_particles.size()):
		var particle_value = dust_particles[particle_index]
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
			canvas.draw_arc(impact_center, radius, 0.0, TAU, boss_impact_arc_segments, Color(1.0, 0.54, 0.12, 0.54 * impact_fade), max(1.0, 3.0 - float(ring_index)), true)


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
