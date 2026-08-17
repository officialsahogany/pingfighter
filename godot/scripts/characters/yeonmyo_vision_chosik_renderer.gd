extends RefCounted

const CHEST_SIZE := Vector2(46.0, 34.0)
const GAS_RADIUS := 80.0
const ELLIPSE_SEGMENTS := 24


func draw(canvas: CanvasItem, snapshot: Dictionary, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	var phase := str(snapshot.get("phase", "idle"))
	var chest_pos := _as_vector2(snapshot.get("chest_pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	if phase == "throw":
		var ground_pos := _as_vector2(snapshot.get("throw_ground_pos", chest_pos), chest_pos) + shake_offset
		var height := maxf(0.0, float(snapshot.get("throw_height", 0.0)))
		_draw_throw_shadow(canvas, ground_pos, height)
		_draw_chest(
			canvas,
			chest_pos,
			0.0,
			float(snapshot.get("throw_rotation", 0.0)),
			float(snapshot.get("throw_scale", 1.0))
		)
		return
	if phase == "open":
		_draw_gas(
			canvas,
			chest_pos,
			float(snapshot.get("smoke_elapsed", 0.0)),
			float(snapshot.get("smoke_emit_duration", 3.0)),
			float(snapshot.get("smoke_fade_duration", 2.0)),
			float(snapshot.get("visual_time", 0.0))
		)
	var landing_ratio := clampf(
		float(snapshot.get("landing_elapsed", 1.0))
		/ maxf(0.001, float(snapshot.get("landing_settle_duration", 0.34))),
		0.0,
		1.0
	)
	var settle_strength := 1.0 - landing_ratio
	var settle_rotation := sin(landing_ratio * PI * 4.0) * 0.16 * settle_strength
	var settle_scale := Vector2(
		1.0 + settle_strength * 0.12,
		1.0 - settle_strength * 0.10
	)
	_draw_ground_shadow(canvas, chest_pos, 1.0 - settle_strength * 0.18)
	_draw_chest(
		canvas,
		chest_pos + Vector2(0.0, sin(landing_ratio * PI) * -5.0 * settle_strength),
		clampf(float(snapshot.get("smoke_elapsed", 0.0)) / 0.18, 0.0, 1.0) if phase == "open" else 0.0,
		settle_rotation,
		settle_scale
	)


func _draw_throw_shadow(canvas: CanvasItem, ground_pos: Vector2, height: float) -> void:
	var height_ratio := clampf(height / 150.0, 0.0, 1.0)
	var shadow_scale := 1.0 - height_ratio * 0.42
	_draw_ellipse(
		canvas,
		ground_pos,
		Vector2(22.0 * shadow_scale, 22.0 * shadow_scale * 0.45),
		Color(0.03, 0.01, 0.05, 0.30 - height_ratio * 0.14)
	)


func _draw_ground_shadow(canvas: CanvasItem, pos: Vector2, scale: float) -> void:
	_draw_ellipse(
		canvas,
		pos + Vector2(0.0, 15.0),
		Vector2(24.0 * scale, 24.0 * scale * 0.42),
		Color(0.03, 0.01, 0.05, 0.26)
	)


func _draw_chest(
	canvas: CanvasItem,
	center: Vector2,
	open_ratio: float,
	rotation: float,
	scale_value: Variant
) -> void:
	var scale := Vector2.ONE
	if scale_value is Vector2:
		scale = scale_value
	else:
		scale *= float(scale_value)
	# This renderer runs inside BattleSceneDrawer's playfield transform. Never
	# replace that shared CanvasItem state: transform every local chest vertex
	# directly instead so following effects retain game_offset/render_scale.
	var direction := Vector2(cos(rotation), sin(rotation))
	var perpendicular := Vector2(-direction.y, direction.x)
	var body_rect := Rect2(-CHEST_SIZE * 0.5, CHEST_SIZE)
	_draw_transformed_rect(
		canvas,
		body_rect,
		center,
		direction,
		perpendicular,
		scale,
		Color(0.18, 0.07, 0.22, 0.98),
		Color(0.72, 0.43, 0.82, 0.94),
		3.0
	)
	var lid_y := lerpf(body_rect.position.y - 8.0, body_rect.position.y - 24.0, open_ratio)
	var lid_height := lerpf(14.0, 10.0, open_ratio)
	if open_ratio > 0.0:
		var mouth_rect := Rect2(
			Vector2(body_rect.position.x + 2.0, body_rect.position.y - 4.0),
			Vector2(body_rect.size.x - 4.0, 10.0)
		)
		_draw_transformed_rect(
			canvas,
			mouth_rect,
			center,
			direction,
			perpendicular,
			scale,
			Color(0.05, 0.01, 0.08, 1.0),
			Color(0.80, 0.38, 0.94, 0.70),
			2.0
		)
	var lid_rect := Rect2(
		Vector2(body_rect.position.x - 2.0, lid_y),
		Vector2(CHEST_SIZE.x + 4.0, lid_height)
	)
	_draw_transformed_rect(
		canvas,
		lid_rect,
		center,
		direction,
		perpendicular,
		scale,
		Color(0.29, 0.09, 0.36, 1.0),
		Color(0.87, 0.62, 0.91, 0.96),
		2.0
	)
	_draw_transformed_rect(
		canvas,
		Rect2(Vector2(-4.0, -2.0), Vector2(8.0, 12.0)),
		center,
		direction,
		perpendicular,
		scale,
		Color(0.92, 0.74, 0.28, 1.0)
	)
	canvas.draw_colored_polygon(
		_build_transformed_ellipse_points(
			Vector2(0.0, 2.0),
			Vector2(2.2, 2.2),
			center,
			direction,
			perpendicular,
			scale
		),
		Color(0.30, 0.12, 0.08, 1.0)
	)


func _draw_ellipse(canvas: CanvasItem, center: Vector2, radius: Vector2, color: Color) -> void:
	canvas.draw_colored_polygon(
		_build_transformed_ellipse_points(
			Vector2.ZERO,
			radius,
			center,
			Vector2.RIGHT,
			Vector2.DOWN,
			Vector2.ONE
		),
		color
	)


func _draw_transformed_rect(
	canvas: CanvasItem,
	rect: Rect2,
	center: Vector2,
	direction: Vector2,
	perpendicular: Vector2,
	scale: Vector2,
	fill_color: Color,
	outline_color: Color = Color.TRANSPARENT,
	outline_width: float = 0.0
) -> void:
	var points := PackedVector2Array([
		_transform_local_point(rect.position, center, direction, perpendicular, scale),
		_transform_local_point(Vector2(rect.end.x, rect.position.y), center, direction, perpendicular, scale),
		_transform_local_point(rect.end, center, direction, perpendicular, scale),
		_transform_local_point(Vector2(rect.position.x, rect.end.y), center, direction, perpendicular, scale),
	])
	canvas.draw_colored_polygon(points, fill_color)
	if outline_width <= 0.0 or outline_color.a <= 0.0:
		return
	var closed_points := PackedVector2Array(points)
	closed_points.append(points[0])
	canvas.draw_polyline(closed_points, outline_color, outline_width, true)


func _build_transformed_ellipse_points(
	local_center: Vector2,
	radius: Vector2,
	center: Vector2,
	direction: Vector2,
	perpendicular: Vector2,
	scale: Vector2
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(ELLIPSE_SEGMENTS):
		var angle := TAU * float(index) / float(ELLIPSE_SEGMENTS)
		var local_point := local_center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		points.append(_transform_local_point(local_point, center, direction, perpendicular, scale))
	return points


func _transform_local_point(
	local_point: Vector2,
	center: Vector2,
	direction: Vector2,
	perpendicular: Vector2,
	scale: Vector2
) -> Vector2:
	return (
		center
		+ direction * local_point.x * scale.x
		+ perpendicular * local_point.y * scale.y
	)


func _draw_gas(
	canvas: CanvasItem,
	pos: Vector2,
	smoke_elapsed: float,
	emit_duration: float,
	fade_duration: float,
	visual_time: float
) -> void:
	var fade := 1.0
	if smoke_elapsed > emit_duration:
		fade = clampf(1.0 - (smoke_elapsed - emit_duration) / maxf(0.001, fade_duration), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(visual_time * 3.8)
	canvas.draw_circle(pos, GAS_RADIUS, Color(0.30, 0.08, 0.42, (0.045 + pulse * 0.025) * fade))
	for index in range(14):
		var delay := float(index) * 0.16
		var age := smoke_elapsed - delay
		if age < 0.0:
			continue
		age = fmod(age, 2.25)
		var direction_angle := float(index) * 2.399 + sin(float(index) * 1.7) * 0.3
		var spread := minf(GAS_RADIUS - 8.0, age * (25.0 + float(index % 4) * 3.0))
		var rise := minf(30.0, age * 18.0)
		var puff_pos := pos + Vector2(cos(direction_angle) * spread, sin(direction_angle) * spread * 0.48 - 18.0 - rise)
		var puff_radius := 6.0 + age * 6.0 + float(index % 3)
		var life_alpha := clampf(1.0 - age / 2.25, 0.0, 1.0) * fade
		canvas.draw_circle(puff_pos, puff_radius, Color(0.55, 0.17, 0.70, 0.16 * life_alpha))
		canvas.draw_circle(puff_pos + Vector2(-puff_radius * 0.25, -puff_radius * 0.22), puff_radius * 0.58, Color(0.78, 0.39, 0.90, 0.10 * life_alpha))


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
