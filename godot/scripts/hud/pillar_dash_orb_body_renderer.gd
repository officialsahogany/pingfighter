extends RefCounted


func draw(
	canvas: CanvasItem,
	pillar_drawer: Object,
	center: Vector2,
	radius: float,
	frame_width: float,
	t: float,
	available_tokens: int,
	max_tokens: int,
	flash_timer: float,
	flash_duration: float,
	frame_texture
) -> void:
	if canvas == null or pillar_drawer == null:
		return

	var pulse: float = 0.5 + 0.5 * sin(t * 4.0)
	var outer_glow: float = 0.08 + 0.06 * pulse
	if available_tokens > 0:
		outer_glow += 0.08 + 0.06 * pulse
	if flash_timer > 0.0:
		outer_glow += 0.28 * (flash_timer / flash_duration)

	_draw_outer_glow(canvas, center, radius, frame_width, outer_glow)
	if not (frame_texture is Texture2D):
		_draw_fallback_frame(canvas, pillar_drawer, center, radius, frame_width)
	_draw_background(canvas, center, radius)
	_draw_ambient_particles(canvas, center, radius, t)
	_draw_core(canvas, center, radius, t, available_tokens, max_tokens)


func _draw_outer_glow(canvas: CanvasItem, center: Vector2, radius: float, frame_width: float, outer_glow: float) -> void:
	for layer in range(4):
		var glow_radius: float = radius + frame_width + 14.0 - float(layer) * 3.0
		var alpha: float = outer_glow * (1.0 - float(layer) * 0.18)
		canvas.draw_circle(center, glow_radius, Color(0.92, 0.28, 0.28, alpha))


func _draw_fallback_frame(
	canvas: CanvasItem,
	pillar_drawer: Object,
	center: Vector2,
	radius: float,
	frame_width: float
) -> void:
	pillar_drawer.draw_pillar_orb_frame(
		canvas,
		center,
		radius,
		frame_width,
		Color(0.16, 0.10, 0.09, 1.0),
		Color(0.46, 0.34, 0.32, 1.0),
		Color(0.70, 0.54, 0.50, 1.0),
		Color(0.84, 0.20, 0.20, 1.0),
		Color(1.0, 0.72, 0.72, 1.0)
	)


func _draw_background(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	for r in range(int(radius), 0, -4):
		var ratio: float = float(r) / radius
		var bg_color: Color = Color(
			0.06 + 0.12 * (1.0 - ratio),
			0.02 + 0.04 * (1.0 - ratio),
			0.03 + 0.06 * (1.0 - ratio),
			1.0
		)
		canvas.draw_circle(center, float(r), bg_color)


func _draw_ambient_particles(canvas: CanvasItem, center: Vector2, radius: float, t: float) -> void:
	for i in range(5):
		var pa: float = t * 0.9 + float(i) * 1.26
		var orbit_r: float = (radius - 10.0) * (0.25 + 0.45 * abs(sin(pa * 0.5 + float(i) * 0.8)))
		var orbit_angle: float = pa * (0.7 + float(i % 3) * 0.12)
		var particle_pos: Vector2 = center + Vector2(cos(orbit_angle), sin(orbit_angle * 0.8 + float(i))) * orbit_r
		if particle_pos.distance_to(center) < radius - 5.0:
			var pa_alpha: float = 0.28 + 0.18 * abs(sin(pa * 1.2))
			var pa_size: float = 1.6 + float(i % 3) * 0.5
			canvas.draw_circle(particle_pos, pa_size, Color(1.0, 0.55, 0.42, pa_alpha))
			canvas.draw_circle(particle_pos, pa_size * 0.4, Color(1.0, 1.0, 0.9, pa_alpha * 0.5))


func _draw_core(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	t: float,
	available_tokens: int,
	max_tokens: int
) -> void:
	var core_pulse: float = 0.5 + 0.5 * sin(t * 3.2)
	var core_a: float = 0.06 + 0.05 * core_pulse + float(available_tokens) / float(max_tokens) * 0.08
	canvas.draw_circle(center, radius * 0.50, Color(0.80, 0.20, 0.18, core_a))
	canvas.draw_circle(center, radius * 0.28, Color(1.0, 0.45, 0.35, core_a * 0.7))
