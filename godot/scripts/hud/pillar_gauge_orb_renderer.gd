extends RefCounted

const PillarGaugeOrbFillRenderer := preload("res://scripts/hud/pillar_gauge_orb_fill_renderer.gd")

var fill_renderer: Object = PillarGaugeOrbFillRenderer.new()


func draw(canvas: CanvasItem, center: Vector2, orb_radius: float, t: float, scale_factor: float, context: Dictionary) -> void:
	if canvas == null:
		return

	var pillar_drawer = context.get("pillar_drawer", null)
	if pillar_drawer == null:
		return

	var radius: float = max(16.0, orb_radius)
	var frame_width_base: float = float(context.get("frame_width_base", 7.0))
	var frame_width: float = max(4.0, frame_width_base * scale_factor)
	var gauge_value: float = float(context.get("gauge_value", 0.0))
	var gauge_max: float = max(1.0, float(context.get("gauge_max", 500.0)))
	var full_ratio: float = clamp(gauge_value / gauge_max, 0.0, 1.0)
	var flash_duration: float = max(0.001, float(context.get("flash_duration", 1.0)))
	var flash_timer: float = max(0.0, float(context.get("flash_timer", 0.0)))
	var pulse: float = 0.5 + 0.5 * sin(t * 4.0)
	var glow_strength: float = 0.08 + 0.06 * pulse
	if full_ratio >= 0.999:
		glow_strength += 0.14 + 0.10 * pulse
	if flash_timer > 0.0:
		glow_strength += 0.28 * (flash_timer / flash_duration)

	for layer in range(4):
		var glow_radius: float = radius + frame_width + 14.0 - float(layer) * 3.0
		var alpha: float = glow_strength * (1.0 - float(layer) * 0.18)
		canvas.draw_circle(center, glow_radius, Color(0.36, 0.58, 1.0, alpha))

	var frame_texture = context.get("frame_texture", null)
	if not (frame_texture is Texture2D):
		pillar_drawer.draw_pillar_orb_frame(
			canvas,
			center,
			radius,
			frame_width,
			Color(0.18, 0.14, 0.08, 1.0),
			Color(0.58, 0.48, 0.24, 1.0),
			Color(0.85, 0.73, 0.42, 1.0),
			Color(0.18, 0.46, 0.88, 1.0),
			Color(0.72, 0.88, 1.0, 1.0)
		)

	for r in range(int(radius), 0, -4):
		var ratio: float = float(r) / radius
		var bg_color := Color(
			0.02 + 0.06 * (1.0 - ratio),
			0.05 + 0.08 * (1.0 - ratio),
			0.12 + 0.14 * (1.0 - ratio),
			1.0
		)
		canvas.draw_circle(center, float(r), bg_color)

	for i in range(6):
		var pa: float = t * 0.8 + float(i) * 1.05
		var orbit_r: float = (radius - 10.0) * (0.25 + 0.45 * abs(sin(pa * 0.5 + float(i) * 0.7)))
		var orbit_angle: float = pa * (0.6 + float(i % 3) * 0.15)
		var particle_pos := center + Vector2(cos(orbit_angle), sin(orbit_angle * 0.8 + float(i))) * orbit_r
		if particle_pos.distance_to(center) < radius - 5.0:
			var pa_alpha: float = 0.30 + 0.20 * abs(sin(pa * 1.3))
			var pa_size: float = 1.8 + float(i % 3) * 0.6
			canvas.draw_circle(particle_pos, pa_size, Color(0.55, 0.78, 1.0, pa_alpha))
			canvas.draw_circle(particle_pos, pa_size * 0.4, Color(1.0, 1.0, 1.0, pa_alpha * 0.5))

	var core_pulse: float = 0.5 + 0.5 * sin(t * 3.0)
	var core_alpha: float = 0.06 + 0.05 * core_pulse + full_ratio * 0.08
	canvas.draw_circle(center, radius * 0.55, Color(0.30, 0.55, 1.0, core_alpha))
	canvas.draw_circle(center, radius * 0.30, Color(0.50, 0.75, 1.0, core_alpha * 0.7))

	fill_renderer.draw(canvas, pillar_drawer, center, radius, t, scale_factor, full_ratio)
	pillar_drawer.draw_pillar_orb_glass(canvas, center, radius, Color(0.50, 0.74, 1.0, 1.0))
	if frame_texture is Texture2D:
		var texture: Texture2D = frame_texture
		pillar_drawer.draw_rotating_orb_frame_texture(canvas, texture, center, radius, float(context.get("frame_spin_angle", 0.0)))

	if flash_timer > 0.0:
		var flash_progress: float = flash_timer / flash_duration
		for layer in range(3):
			var flash_radius: float = radius + 10.0 * scale_factor + float(layer) * 12.0 * scale_factor
			var flash_alpha: float = (0.38 - float(layer) * 0.10) * flash_progress
			canvas.draw_circle(center, flash_radius, Color(1.0, 0.82, 0.46, flash_alpha))
		canvas.draw_arc(center, radius + 26.0 * scale_factor * (1.0 - flash_progress), 0.0, TAU, 32, Color(1.0, 0.86, 0.50, 0.50 * flash_progress), 3.0)

	var ring_phase: float = fmod(t * 0.8, 1.0)
	var ring_r: float = radius * (0.5 + ring_phase * 0.5)
	var ring_alpha: float = 0.12 * (1.0 - ring_phase)
	if ring_alpha > 0.01:
		canvas.draw_arc(center, ring_r, 0.0, TAU, 32, Color(0.50, 0.74, 1.0, ring_alpha), 1.5)

	canvas.draw_circle(center, radius * 0.40, Color(0.78, 0.90, 1.0, 0.12 + full_ratio * 0.18))
	pillar_drawer.draw_pillar_text_centered(
		canvas,
		center,
		"%d/%d" % [int(round(gauge_value)), int(round(gauge_max))],
		int(round(16.0 * scale_factor)),
		Color.WHITE
	)
