extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const HEUPINJIN_ICON_PATH := ActiveItemCatalog.MAGNET_FIELD_ICON_PATH
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const FORMATION_OFFSET := Vector2(0.0, -54.0)
const FORMATION_OUTER_RADIUS := Vector2(148.0, 72.0)
const FORMATION_MIDDLE_RADIUS := Vector2(112.0, 55.0)
const FORMATION_INNER_RADIUS := Vector2(72.0, 36.0)
const FORMATION_ICON_SIZE := 38.0
const FORMATION_SIDES := 8
const EDGE_MARGIN := 4.0
const PARTICLE_ALPHA_CUTOFF := 0.02
const BED_STEPS := 7
const CHANNEL_CURL := 0.85
const CHANNEL_TAIL_SEGMENTS := 3

const INK_COLOR := Color(26.0 / 255.0, 19.0 / 255.0, 14.0 / 255.0, 1.0)
const AGED_GOLD_DARK := Color(112.0 / 255.0, 72.0 / 255.0, 24.0 / 255.0, 1.0)
const AGED_GOLD := Color(214.0 / 255.0, 158.0 / 255.0, 53.0 / 255.0, 1.0)
const AGED_GOLD_LIGHT := Color(1.0, 218.0 / 255.0, 112.0 / 255.0, 1.0)
const JADE_COLOR := Color(55.0 / 255.0, 190.0 / 255.0, 143.0 / 255.0, 1.0)

var _icon_texture: Texture2D


func prewarm_assets() -> void:
	_touch_texture(get_icon_texture())


func draw(
	canvas: CanvasItem,
	magnet_context: Dictionary,
	particles: Array,
	shake_offset: Vector2
) -> void:
	if canvas == null or not bool(magnet_context.get("active", false)):
		return

	var player_center: Vector2 = _get_vector2(
		magnet_context,
		"player_center",
		Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - 25.0)
	) + shake_offset
	var formation_center: Vector2 = player_center + FORMATION_OFFSET
	var timer_frames: float = float(magnet_context.get("timer_frames", 0.0))
	var initial_timer_frames: float = max(1.0, float(magnet_context.get("initial_timer_frames", 480.0)))
	var remaining_ratio: float = clamp(timer_frames / initial_timer_frames, 0.0, 1.0)
	var phase: float = float(magnet_context.get("field_phase", 0.0))
	var fade_alpha: float = min(1.0, remaining_ratio * 2.4)
	var expiry_boost: float = 1.0
	if timer_frames < 60.0:
		expiry_boost = 1.0 + 0.55 * (0.5 + 0.5 * sin(phase * 3.4))

	_draw_formation_bed(canvas, formation_center, phase, fade_alpha, expiry_boost)
	_draw_inward_channels(canvas, formation_center, phase, fade_alpha)
	_draw_center_plaque(canvas, formation_center, phase, fade_alpha, expiry_boost)
	for particle_value in particles:
		if particle_value is Dictionary:
			draw_particle(canvas, particle_value, shake_offset)


func draw_particle(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2) -> void:
	var alpha: float = clamp(float(particle.get("alpha", 1.0)), 0.0, 1.0)
	if alpha <= PARTICLE_ALPHA_CUTOFF:
		return
	var color: Color = _get_color(particle.get("color", AGED_GOLD), AGED_GOLD)
	var center: Vector2 = _clamp_to_field(_get_vector2(particle, "position", Vector2.ZERO) + shake_offset)
	var velocity: Vector2 = _get_vector2(particle, "velocity", Vector2.UP)
	var direction: Vector2 = velocity.normalized() if velocity.length_squared() > 0.001 else Vector2.UP
	var radius: float = max(1.0, float(particle.get("radius", 2.0)))
	var stretch: float = clampf(velocity.length(), 1.2, 4.0)
	canvas.draw_circle(center, radius * 2.8, Color(color.r, color.g, color.b, 0.05 * alpha))
	canvas.draw_line(
		center - direction * radius * (1.2 + stretch),
		center + direction * radius * 0.8,
		Color(color.r, color.g, color.b, 0.4 * alpha),
		max(1.0, radius * 0.65)
	)
	canvas.draw_circle(
		center + direction * radius * 0.8,
		maxf(1.0, radius * 0.75),
		Color(AGED_GOLD_LIGHT.r, AGED_GOLD_LIGHT.g, AGED_GOLD_LIGHT.b, 0.5 * alpha)
	)


func get_icon_texture() -> Texture2D:
	if _icon_texture == null:
		_icon_texture = ProjectResourceLoader.load_texture(
			HEUPINJIN_ICON_PATH,
			"Missing Heupinjin icon at %s",
			"Failed to load Heupinjin icon at %s"
		)
	return _icon_texture


func get_asset_status() -> Dictionary:
	return {
		"icon_path": HEUPINJIN_ICON_PATH,
		"icon_ready": get_icon_texture() != null,
	}


# The eight-sided formation is expressed as stacked translucent fills, never as a
# stroked perimeter: a drawn outline reads as a bright wall around the paddle and
# hides the ball travelling through it.
func _draw_formation_bed(
	canvas: CanvasItem,
	center: Vector2,
	phase: float,
	alpha: float,
	expiry_boost: float
) -> void:
	var breath: float = 1.0 + 0.02 * sin(phase * 0.8)
	var spin: float = phase * 0.05
	for index in range(BED_STEPS):
		var step: float = float(index) / float(BED_STEPS - 1)
		var radius: Vector2 = (FORMATION_OUTER_RADIUS * (1.06 * breath)).lerp(
			FORMATION_INNER_RADIUS * (0.34 * breath),
			step
		)
		var rotation: float = spin + (PI / 8.0 if index % 2 == 1 else 0.0)
		var tint: Color = AGED_GOLD_DARK.lerp(AGED_GOLD_LIGHT, step)
		var step_alpha: float = (0.015 + 0.019 * step) * alpha * expiry_boost
		_draw_elliptical_octagon_fill(canvas, center, radius, rotation, Color(tint.r, tint.g, tint.b, step_alpha))

	_draw_elliptical_octagon_fill(
		canvas,
		center,
		FORMATION_MIDDLE_RADIUS * (0.52 * breath),
		-spin,
		Color(JADE_COLOR.r, JADE_COLOR.g, JADE_COLOR.b, 0.028 * alpha)
	)


func _draw_inward_channels(canvas: CanvasItem, center: Vector2, phase: float, alpha: float) -> void:
	var travel: float = fposmod(phase * 0.26, 1.0)
	for index in range(FORMATION_SIDES):
		var base_angle: float = -PI * 0.5 + TAU * float(index) / float(FORMATION_SIDES) + phase * 0.06
		var staggered_travel: float = fposmod(travel + float(index) * 0.37, 1.0)
		var head: Vector2 = _channel_point(center, base_angle, staggered_travel)
		var previous: Vector2 = head
		for tail_index in range(1, CHANNEL_TAIL_SEGMENTS + 1):
			var tail_t: float = staggered_travel - 0.07 * float(tail_index)
			if tail_t <= 0.0:
				break
			var tail_point: Vector2 = _channel_point(center, base_angle, tail_t)
			canvas.draw_line(
				tail_point,
				previous,
				Color(AGED_GOLD.r, AGED_GOLD.g, AGED_GOLD.b, (0.3 - 0.08 * float(tail_index)) * alpha),
				2.4 - 0.6 * float(tail_index)
			)
			previous = tail_point

		canvas.draw_circle(head, 5.5, Color(AGED_GOLD_LIGHT.r, AGED_GOLD_LIGHT.g, AGED_GOLD_LIGHT.b, 0.05 * alpha))
		canvas.draw_circle(head, 1.7, Color(AGED_GOLD_LIGHT.r, AGED_GOLD_LIGHT.g, AGED_GOLD_LIGHT.b, 0.5 * alpha))


func _draw_center_plaque(
	canvas: CanvasItem,
	center: Vector2,
	phase: float,
	alpha: float,
	expiry_boost: float
) -> void:
	var pulse: float = 0.92 + 0.08 * sin(phase * 1.2)
	canvas.draw_circle(center, 46.0 * pulse, Color(AGED_GOLD_LIGHT.r, AGED_GOLD_LIGHT.g, AGED_GOLD_LIGHT.b, 0.022 * alpha * expiry_boost))
	canvas.draw_circle(center, 34.0 * pulse, Color(AGED_GOLD_LIGHT.r, AGED_GOLD_LIGHT.g, AGED_GOLD_LIGHT.b, 0.032 * alpha * expiry_boost))
	canvas.draw_circle(center, 25.0 * pulse, Color(AGED_GOLD_LIGHT.r, AGED_GOLD_LIGHT.g, AGED_GOLD_LIGHT.b, 0.05 * alpha * expiry_boost))
	canvas.draw_circle(center, 26.0 * pulse, Color(INK_COLOR.r, INK_COLOR.g, INK_COLOR.b, 0.1 * alpha))
	canvas.draw_circle(center, 22.0 * pulse, Color(INK_COLOR.r, INK_COLOR.g, INK_COLOR.b, 0.12 * alpha))
	canvas.draw_circle(center, 18.0 * pulse, Color(INK_COLOR.r, INK_COLOR.g, INK_COLOR.b, 0.14 * alpha))

	var texture: Texture2D = get_icon_texture()
	if texture != null:
		var icon_scale: float = 0.97 + 0.05 * sin(phase * 1.2)
		var draw_size := Vector2(FORMATION_ICON_SIZE, FORMATION_ICON_SIZE) * icon_scale
		canvas.draw_texture_rect(texture, Rect2(center - draw_size * 0.5, draw_size), false, Color(1.0, 1.0, 1.0, 0.85 * alpha))
	else:
		_draw_plaque_fallback(canvas, center, FORMATION_ICON_SIZE, alpha)


func _draw_plaque_fallback(canvas: CanvasItem, center: Vector2, size: float, alpha: float) -> void:
	_draw_elliptical_octagon_fill(
		canvas,
		center,
		Vector2.ONE * size * 0.42,
		PI / 8.0,
		Color(AGED_GOLD.r, AGED_GOLD.g, AGED_GOLD.b, 0.55 * alpha)
	)
	canvas.draw_circle(center, size * 0.13, Color(INK_COLOR.r, INK_COLOR.g, INK_COLOR.b, alpha))


func _channel_point(center: Vector2, base_angle: float, t: float) -> Vector2:
	var eased: float = t * t
	var radius: Vector2 = (FORMATION_OUTER_RADIUS * 0.94).lerp(FORMATION_INNER_RADIUS * 0.5, eased)
	var angle: float = base_angle + CHANNEL_CURL * (1.0 - t)
	return _clamp_to_field(_ellipse_point(center, radius, angle))


func _draw_elliptical_octagon_fill(
	canvas: CanvasItem,
	center: Vector2,
	radius: Vector2,
	rotation: float,
	color: Color
) -> void:
	if radius.x <= 0.0 or radius.y <= 0.0 or color.a <= 0.0:
		return
	var points := PackedVector2Array()
	for index in range(FORMATION_SIDES):
		var angle: float = rotation + TAU * float(index) / float(FORMATION_SIDES)
		points.append(_clamp_to_field(_ellipse_point(center, radius, angle)))
	if Geometry2D.triangulate_polygon(points).is_empty():
		return
	canvas.draw_colored_polygon(points, color)


func _ellipse_point(center: Vector2, radius: Vector2, angle: float) -> Vector2:
	return center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)


func _clamp_to_field(point: Vector2) -> Vector2:
	return Vector2(
		clamp(point.x, EDGE_MARGIN, FIELD_WIDTH - EDGE_MARGIN),
		clamp(point.y, EDGE_MARGIN, FIELD_HEIGHT - EDGE_MARGIN)
	)


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
