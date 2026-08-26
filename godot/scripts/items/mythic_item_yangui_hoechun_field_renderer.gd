extends RefCounted

const CORE_LENGTH_PX := 276.0
const CRESCENT_COUNT := 3
const CRESCENT_SEGMENTS := 10

const ROCK_SHADOW := Color("#5a4326")
const ROCK_DEEP := Color("#7b5a25")
const ROCK_GOLD := Color("#c9a227")
const ROCK_LIGHT := Color("#f2d98a")
const CRESCENT_CYAN := Color("#bfe9f0")
const CRESCENT_WHITE := Color("#ffffff")

var _rock_shadow_shape: PackedVector2Array = PackedVector2Array([
	Vector2(3.0, -1.0), Vector2(54.0, -15.0), Vector2(138.0, -42.0),
	Vector2(228.0, -61.0), Vector2(CORE_LENGTH_PX + 10.0, -47.0),
	Vector2(CORE_LENGTH_PX + 18.0, 8.0), Vector2(222.0, 25.0),
	Vector2(124.0, 27.0), Vector2(42.0, 14.0),
])
var _rock_body_shape: PackedVector2Array = PackedVector2Array([
	Vector2(0.0, -2.0), Vector2(62.0, -19.0), Vector2(144.0, -48.0),
	Vector2(222.0, -54.0), Vector2(CORE_LENGTH_PX, -35.0),
	Vector2(CORE_LENGTH_PX - 8.0, 2.0), Vector2(211.0, 17.0),
	Vector2(118.0, 20.0), Vector2(36.0, 10.0),
])
var _rock_stratum_a: PackedVector2Array = PackedVector2Array([
	Vector2(25.0, -4.0), Vector2(91.0, -23.0), Vector2(117.0, -16.0), Vector2(55.0, 1.0),
])
var _rock_stratum_b: PackedVector2Array = PackedVector2Array([
	Vector2(104.0, -29.0), Vector2(170.0, -48.0), Vector2(198.0, -40.0), Vector2(136.0, -19.0),
])
var _rock_stratum_c: PackedVector2Array = PackedVector2Array([
	Vector2(181.0, -48.0), Vector2(242.0, -48.0), Vector2(267.0, -31.0), Vector2(209.0, -25.0),
])


func draw_effect(canvas: CanvasItem, shake_offset: Vector2, context: Dictionary) -> void:
	if canvas == null or not bool(context.get("visible", false)):
		return
	var wave_contexts: Array = context.get("waves", [])
	if wave_contexts.is_empty() and bool(context.get("wave_active", false)):
		wave_contexts = [context]
	for wave_value in wave_contexts:
		if not (wave_value is Dictionary):
			continue
		var wave: Dictionary = wave_value
		_draw_wave(canvas, shake_offset, wave)


func _draw_wave(canvas: CanvasItem, shake_offset: Vector2, wave: Dictionary) -> void:
	var origin: Vector2 = _as_vector2(wave.get("origin", Vector2.ZERO)) + shake_offset
	var phase := float(wave.get("phase", 0.0))
	var half_height := maxf(1.0, float(wave.get("half_height", 92.0)))
	var left_alpha := clampf(float(wave.get("left_alpha", wave.get("alpha", 0.0))), 0.0, 1.0)
	var right_alpha := clampf(float(wave.get("right_alpha", wave.get("alpha", 0.0))), 0.0, 1.0)
	if left_alpha > 0.001:
		_draw_wedge(
			canvas,
			Vector2(float(wave.get("left_front_x", origin.x)) + shake_offset.x, origin.y),
			-1,
			half_height,
			phase,
			left_alpha
		)
	if right_alpha > 0.001:
		_draw_wedge(
			canvas,
			Vector2(float(wave.get("right_front_x", origin.x)) + shake_offset.x, origin.y),
			1,
			half_height,
			phase,
			right_alpha
		)
	_draw_activation_breath(canvas, origin, float(wave.get("age_sec", 1.0)), maxf(left_alpha, right_alpha), phase)
	var hit_ratio := clampf(float(wave.get("hit_flash_ratio", 0.0)), 0.0, 1.0)
	if hit_ratio > 0.001:
		_draw_hit_flash(
			canvas,
			_as_vector2(wave.get("hit_position", origin)) + shake_offset,
			hit_ratio,
			phase
		)


func _draw_wedge(
	canvas: CanvasItem,
	front: Vector2,
	side: int,
	half_height: float,
	phase: float,
	alpha: float
) -> void:
	var baseline_y := front.y - half_height * 0.20
	_draw_dust_tail(canvas, front.x, baseline_y, side, half_height, phase, alpha)

	canvas.draw_colored_polygon(
		_transform_polygon(_rock_shadow_shape, front.x, baseline_y, side, half_height / 92.0),
		_alpha(ROCK_SHADOW, alpha * 0.72)
	)
	canvas.draw_colored_polygon(
		_transform_polygon(_rock_body_shape, front.x, baseline_y, side, half_height / 92.0),
		_alpha(ROCK_GOLD, alpha * 0.86)
	)

	_draw_rock_strata(canvas, front.x, baseline_y, side, half_height, phase, alpha)
	for crescent_index in range(CRESCENT_COUNT):
		_draw_crescent(canvas, front.x, baseline_y, side, half_height, phase, alpha, crescent_index)


func _draw_rock_strata(
	canvas: CanvasItem,
	front_x: float,
	baseline_y: float,
	side: int,
	half_height: float,
	phase: float,
	alpha: float
) -> void:
	var height_scale := half_height / 92.0
	var pulse := sin(phase * 0.55) * 2.0
	_draw_stratum(canvas, _rock_stratum_a, ROCK_LIGHT, 0.68, front_x, baseline_y, side, height_scale, pulse, alpha)
	_draw_stratum(canvas, _rock_stratum_b, ROCK_LIGHT, 0.56, front_x, baseline_y, side, height_scale, pulse, alpha)
	_draw_stratum(canvas, _rock_stratum_c, ROCK_DEEP, 0.52, front_x, baseline_y, side, height_scale, pulse, alpha)


func _draw_stratum(
	canvas: CanvasItem,
	points: PackedVector2Array,
	color: Color,
	color_alpha: float,
	front_x: float,
	baseline_y: float,
	side: int,
	height_scale: float,
	pulse: float,
	alpha: float
) -> void:
	var transformed := PackedVector2Array()
	transformed.resize(points.size())
	for point_index in range(points.size()):
		var point := points[point_index]
		transformed[point_index] = Vector2(
			front_x - float(side) * point.x,
			baseline_y + (point.y + pulse * float(point_index % 2)) * height_scale
		)
	canvas.draw_colored_polygon(transformed, _alpha(color, alpha * color_alpha))


func _draw_crescent(
	canvas: CanvasItem,
	front_x: float,
	baseline_y: float,
	side: int,
	half_height: float,
	phase: float,
	alpha: float,
	index: int
) -> void:
	var centers := [213.0, 132.0, 55.0]
	var heights := [55.0, 43.0, 30.0]
	var bulges := [34.0, 28.0, 22.0]
	var thicknesses := [13.0, 11.0, 9.0]
	var center_back := float(centers[index])
	var height := float(heights[index]) * half_height / 92.0
	var bulge := float(bulges[index])
	var thickness := float(thicknesses[index]) * half_height / 92.0
	var ripple := sin(phase + float(index) * 0.9) * 1.6
	var glow_points := _build_crescent_ribbon(
		front_x,
		baseline_y,
		side,
		center_back,
		height + 3.0,
		bulge + ripple + 4.0,
		thickness + 5.0
	)
	canvas.draw_colored_polygon(glow_points, _alpha(CRESCENT_CYAN, alpha * 0.28))
	var cyan_points := _build_crescent_ribbon(
		front_x,
		baseline_y,
		side,
		center_back,
		height,
		bulge + ripple,
		thickness
	)
	canvas.draw_colored_polygon(cyan_points, _alpha(CRESCENT_CYAN, alpha * 0.96))
	var core_points := _build_crescent_ribbon(
		front_x,
		baseline_y,
		side,
		center_back + 1.5,
		height * 0.88,
		bulge + ripple - 1.2,
		maxf(2.6, thickness * 0.34)
	)
	canvas.draw_colored_polygon(core_points, _alpha(CRESCENT_WHITE, alpha * 0.72))


func _build_crescent_ribbon(
	front_x: float,
	baseline_y: float,
	side: int,
	center_back: float,
	height: float,
	bulge: float,
	thickness: float
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for segment in range(CRESCENT_SEGMENTS + 1):
		var ratio := float(segment) / float(CRESCENT_SEGMENTS)
		var arc_ratio := sin(ratio * PI)
		var back := center_back - bulge * arc_ratio
		var vertical := lerpf(-height, height, ratio) - 6.0
		points.append(Vector2(front_x - float(side) * back, baseline_y + vertical))
	for segment in range(CRESCENT_SEGMENTS, -1, -1):
		var ratio := float(segment) / float(CRESCENT_SEGMENTS)
		var arc_ratio := sin(ratio * PI)
		var back := center_back - maxf(0.0, bulge - thickness) * arc_ratio
		var vertical := lerpf(-height, height, ratio) - 6.0
		points.append(Vector2(front_x - float(side) * back, baseline_y + vertical))
	return points


func _draw_dust_tail(
	canvas: CanvasItem,
	front_x: float,
	baseline_y: float,
	side: int,
	half_height: float,
	phase: float,
	alpha: float
) -> void:
	var height_scale := half_height / 92.0
	for dust_index in range(4):
		var back := CORE_LENGTH_PX + 12.0 + float(dust_index) * 17.0
		var y := baseline_y - 2.0 - float(dust_index % 3) * 8.0 * height_scale + sin(phase + float(dust_index)) * 2.0
		var position := Vector2(front_x - float(side) * back, y)
		var radius := (10.0 - float(dust_index) * 1.25) * height_scale
		canvas.draw_circle(position, radius, _alpha(ROCK_GOLD, alpha * (0.15 - float(dust_index) * 0.022)))
	for shard_index in range(2):
		var back := CORE_LENGTH_PX + 22.0 + float(shard_index) * 31.0
		var center := Vector2(
			front_x - float(side) * back,
			baseline_y - 24.0 - float(shard_index % 2) * 13.0 + sin(phase * 0.7 + float(shard_index)) * 3.0
		)
		var shard := PackedVector2Array([
			center + Vector2(float(side) * 8.0, -3.0),
			center + Vector2(-float(side) * 5.0, -6.0),
			center + Vector2(-float(side) * 9.0, 5.0),
		])
		canvas.draw_colored_polygon(shard, _alpha(ROCK_LIGHT, alpha * 0.26))


func _draw_activation_breath(
	canvas: CanvasItem,
	origin: Vector2,
	age_sec: float,
	alpha: float,
	phase: float
) -> void:
	var ratio := clampf(1.0 - age_sec / 0.24, 0.0, 1.0)
	if ratio <= 0.001 or alpha <= 0.001:
		return
	for shard_index in range(6):
		var angle := phase * 0.18 + TAU * float(shard_index) / 6.0
		var direction := Vector2.from_angle(angle)
		var tangent := direction.orthogonal()
		var inner := origin + direction * 16.0
		var outer := origin + direction * lerpf(38.0, 82.0, 1.0 - ratio)
		canvas.draw_colored_polygon(PackedVector2Array([
			inner - tangent * 5.0,
			outer,
			inner + tangent * 5.0,
		]), _alpha(ROCK_LIGHT, alpha * ratio * 0.34))
	canvas.draw_circle(origin, 16.0 + (1.0 - ratio) * 17.0, _alpha(CRESCENT_WHITE, alpha * ratio * 0.20))


func _draw_hit_flash(canvas: CanvasItem, position: Vector2, ratio: float, phase: float) -> void:
	var expand := 1.0 - ratio
	canvas.draw_circle(position, 13.0 + expand * 24.0, _alpha(ROCK_GOLD, ratio * 0.22))
	canvas.draw_circle(position, 7.0 + expand * 10.0, _alpha(CRESCENT_WHITE, ratio * 0.78))
	for ray_index in range(8):
		var angle := phase + TAU * float(ray_index) / 8.0
		var direction := Vector2.from_angle(angle)
		var tangent := direction.orthogonal()
		var inner := position + direction * (10.0 + expand * 5.0)
		var outer := position + direction * (24.0 + expand * 25.0)
		canvas.draw_colored_polygon(PackedVector2Array([
			inner - tangent * 2.2,
			outer,
			inner + tangent * 2.2,
		]), _alpha(CRESCENT_WHITE, ratio * 0.74))


func _transform_polygon(
	points: PackedVector2Array,
	front_x: float,
	baseline_y: float,
	side: int,
	height_scale: float
) -> PackedVector2Array:
	var transformed := PackedVector2Array()
	transformed.resize(points.size())
	for point_index in range(points.size()):
		var point := points[point_index]
		transformed[point_index] = Vector2(
			front_x - float(side) * point.x,
			baseline_y + point.y * height_scale
		)
	return transformed


func _alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO
