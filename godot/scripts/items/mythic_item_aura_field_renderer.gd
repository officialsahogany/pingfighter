extends RefCounted


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
	alpha: float,
	particle_render_limit: int
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
	for particle_index in range(_recent_start(particles, particle_render_limit), particles.size()):
		var particle: Dictionary = _as_dict(particles[particle_index])
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
	colors: Array,
	particle_render_limit: int,
	ring_segments: int
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
		var draw_colors: Array = colors
		if draw_colors.is_empty():
			draw_colors = [Color.WHITE]
		var color_count: int = draw_colors.size()
		for idx in range(color_count):
			var base_color: Color = _as_color(draw_colors[idx], Color.WHITE)
			var wobble: float = sin(aura_phase + float(idx) * TAU / float(color_count)) * 6.0
			var radius: float = max(4.0, ring_base + (float(idx) - 2.0) * 4.0 + wobble)
			canvas.draw_arc(center, radius + 2.0, 0.0, TAU, ring_segments, Color(base_color.r, base_color.g, base_color.b, 0.16 * fade), thickness + 6.0, true)
			canvas.draw_arc(center, radius, 0.0, TAU, ring_segments, Color(base_color.r, base_color.g, base_color.b, 0.70 * fade), thickness, true)
		canvas.draw_circle(center, max(2.0, 18.0 * fade), Color(1.0, 1.0, 1.0, 0.62 * fade))
		for ray_idx in range(12):
			var angle: float = float(ray_idx) * TAU / 12.0 + aura_phase
			var color: Color = _as_color(draw_colors[ray_idx % color_count], Color.WHITE)
			var start_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * max(2.0, ring_base - 12.0)
			var end_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * (ring_base + 30.0 * fade)
			canvas.draw_line(start_pos, end_pos, Color(color.r, color.g, color.b, 0.58 * fade), max(1.0, 3.0 * fade), true)

	for particle_index in range(_recent_start(particles, particle_render_limit), particles.size()):
		var particle: Dictionary = _as_dict(particles[particle_index])
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
