extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const GEUMGANG_BARRIER_SEAL_PATH := "res://assets/sprites/effects/geumgang_barrier_seal_imagegen_v1.png"
const SEAL_SPACING := 150.0
const SEAL_BASE_SIZE := 34.0
const KNOT_SPACING := 48.0
const PARTICLE_ALPHA_CUTOFF := 0.02

const BAND_SHADOW := Color(0.12, 0.035, 0.018, 0.78)
const BAND_OXBLOOD := Color(0.46, 0.055, 0.025, 0.92)
const BAND_GOLD := Color(0.96, 0.58, 0.08, 0.96)
const BAND_CORE := Color(1.0, 0.91, 0.52, 0.98)

var seal_texture: Texture2D


func prewarm_assets() -> void:
	_touch_texture(get_seal_texture())


func get_seal_texture() -> Texture2D:
	if seal_texture == null:
		seal_texture = ProjectResourceLoader.load_texture(
			GEUMGANG_BARRIER_SEAL_PATH,
			"Geumgang Barrier seal texture missing: %s",
			"Geumgang Barrier seal texture failed to load: %s"
		)
	return seal_texture


func draw(
	canvas: CanvasItem,
	barrier_context: Dictionary,
	particles: Array,
	shake_offset: Vector2
) -> void:
	if canvas == null or not bool(barrier_context.get("active", false)):
		return

	var width: float = max(0.0, float(barrier_context.get("width", 760.0)))
	var barrier_y: float = float(barrier_context.get("barrier_y", 725.0))
	var barrier_height: float = max(1.0, float(barrier_context.get("barrier_height", 20.0)))
	var center_y: float = barrier_y + barrier_height * 0.5
	var glow_phase: float = float(barrier_context.get("glow_phase", 0.0))
	var pulse: float = 0.82 + 0.18 * sin(glow_phase)

	# Deliberate direct-draw host: this is a flat 20 px collision band whose
	# generated seal texture supplies identity. Keeping the band on the owning
	# field renderer avoids a detached-host cleanup surface at round boundaries.
	_draw_layered_band(canvas, width, center_y, pulse, shake_offset)
	_draw_braided_knots(canvas, width, center_y, pulse, shake_offset)
	_draw_repeating_seals(canvas, width, center_y, glow_phase, shake_offset)

	for particle_value in particles:
		if particle_value is Dictionary:
			_draw_particle(canvas, particle_value, shake_offset)

	var timer_frames: float = float(barrier_context.get("timer_frames", 0.0))
	if timer_frames < 60.0 and int(timer_frames) % 10 < 5:
		canvas.draw_rect(
			Rect2(Vector2(0.0, barrier_y - 4.0) + shake_offset, Vector2(width, barrier_height + 8.0)),
			Color(1.0, 0.72, 0.18, 0.16)
		)


func _draw_layered_band(
	canvas: CanvasItem,
	width: float,
	center_y: float,
	pulse: float,
	shake_offset: Vector2
) -> void:
	var start := Vector2(0.0, center_y) + shake_offset
	var end := Vector2(width, center_y) + shake_offset
	canvas.draw_line(start + Vector2(0.0, 3.0), end + Vector2(0.0, 3.0), BAND_SHADOW, 13.0)
	canvas.draw_line(start + Vector2(0.0, 1.0), end + Vector2(0.0, 1.0), BAND_OXBLOOD, 9.0)
	canvas.draw_line(start, end, Color(BAND_GOLD.r, BAND_GOLD.g, BAND_GOLD.b, BAND_GOLD.a * pulse), 5.0)
	canvas.draw_line(start + Vector2(0.0, -1.5), end + Vector2(0.0, -1.5), Color(BAND_CORE.r, BAND_CORE.g, BAND_CORE.b, BAND_CORE.a * pulse), 1.5)


func _draw_braided_knots(
	canvas: CanvasItem,
	width: float,
	center_y: float,
	pulse: float,
	shake_offset: Vector2
) -> void:
	for x_value in range(0, int(width) + int(KNOT_SPACING), int(KNOT_SPACING)):
		var x: float = min(width, float(x_value))
		var center := Vector2(x, center_y) + shake_offset
		var half_width := 6.0
		var half_height := 4.0
		var knot_color := Color(1.0, 0.74, 0.18, 0.52 * pulse)
		canvas.draw_line(center + Vector2(-half_width, 0.0), center + Vector2(0.0, -half_height), knot_color, 1.5)
		canvas.draw_line(center + Vector2(0.0, -half_height), center + Vector2(half_width, 0.0), knot_color, 1.5)
		canvas.draw_line(center + Vector2(half_width, 0.0), center + Vector2(0.0, half_height), knot_color, 1.5)
		canvas.draw_line(center + Vector2(0.0, half_height), center + Vector2(-half_width, 0.0), knot_color, 1.5)


func _draw_repeating_seals(
	canvas: CanvasItem,
	width: float,
	center_y: float,
	glow_phase: float,
	shake_offset: Vector2
) -> void:
	var texture := get_seal_texture()
	var first_x: float = SEAL_SPACING * 0.5
	var seal_index := 0
	var x := first_x
	while x < width:
		var local_pulse: float = 0.88 + 0.12 * sin(glow_phase + float(seal_index) * 0.9)
		var size_value: float = SEAL_BASE_SIZE * local_pulse
		var center := Vector2(x, center_y - 1.0) + shake_offset
		if texture != null:
			canvas.draw_texture_rect(
				texture,
				Rect2(center - Vector2.ONE * size_value * 0.5, Vector2.ONE * size_value),
				false,
				Color(1.0, 0.96, 0.74, 0.88 + 0.12 * local_pulse)
			)
		else:
			_draw_fallback_seal(canvas, center, size_value * 0.34, local_pulse)
		seal_index += 1
		x += SEAL_SPACING


func _draw_fallback_seal(canvas: CanvasItem, center: Vector2, radius: float, pulse: float) -> void:
	var color := Color(1.0, 0.86, 0.36, 0.88 * pulse)
	for index in range(4):
		var angle: float = PI * 0.25 + float(index) * PI * 0.5
		var direction := Vector2(cos(angle), sin(angle))
		var tangent := Vector2(-direction.y, direction.x)
		var tip: Vector2 = center + direction * radius
		canvas.draw_line(center, tip, color, 2.0)
		canvas.draw_line(tip, tip - direction * radius * 0.35 + tangent * radius * 0.24, color, 1.5)
		canvas.draw_line(tip, tip - direction * radius * 0.35 - tangent * radius * 0.24, color, 1.5)


func _draw_particle(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2) -> void:
	var alpha: float = clamp(float(particle.get("alpha", 1.0)), 0.0, 1.0)
	if alpha <= PARTICLE_ALPHA_CUTOFF:
		return
	var center: Vector2 = _get_vector2(particle, "position", Vector2.ZERO) + shake_offset
	var color: Color = _get_color(particle.get("color", BAND_CORE), BAND_CORE)
	var radius: float = max(1.0, float(particle.get("radius", 3.0)))
	var rotation: float = float(particle.get("rotation", 0.0))
	if str(particle.get("kind", "idle")) == "hit":
		_draw_hit_particle(canvas, center, color, radius, alpha, rotation)
	else:
		_draw_idle_particle(canvas, center, color, radius, alpha, rotation)


func _draw_hit_particle(
	canvas: CanvasItem,
	center: Vector2,
	color: Color,
	radius: float,
	alpha: float,
	rotation: float
) -> void:
	var expansion: float = 1.0 + (1.0 - alpha) * 2.6
	for index in range(8):
		var angle: float = rotation + TAU * float(index) / 8.0
		var direction := Vector2(cos(angle), sin(angle))
		var inner: Vector2 = center + direction * radius * 0.45 * expansion
		var outer: Vector2 = center + direction * radius * (1.2 if index % 2 == 0 else 0.85) * expansion
		canvas.draw_line(inner, outer, Color(color.r, color.g, color.b, alpha * 0.88), 1.6)
	canvas.draw_circle(center, max(1.0, radius * 0.42), Color(1.0, 0.93, 0.58, alpha))


func _draw_idle_particle(
	canvas: CanvasItem,
	center: Vector2,
	color: Color,
	radius: float,
	alpha: float,
	rotation: float
) -> void:
	var direction := Vector2(cos(rotation), sin(rotation))
	var tangent := Vector2(-direction.y, direction.x)
	var tip: Vector2 = center + direction * radius * 1.8
	var left: Vector2 = center - direction * radius * 0.8 + tangent * radius * 0.7
	var right: Vector2 = center - direction * radius * 0.8 - tangent * radius * 0.7
	var petal_color := Color(color.r, color.g, color.b, alpha * 0.82)
	canvas.draw_line(left, tip, petal_color, 1.4)
	canvas.draw_line(right, tip, petal_color, 1.4)
	canvas.draw_line(left, right, Color(1.0, 0.56, 0.12, alpha * 0.55), 1.0)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback


func _touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_size()
