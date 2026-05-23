extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const BRICK_WALL_VARIANT_SHEET_PATH := "res://assets/sprites/effects/brick_wall_installed_variants_imagegen_v1.png"
const BRICK_WALL_VARIANT_GRID_COLS := 4
const BRICK_WALL_VARIANT_GRID_ROWS := 2
const BRICK_WALL_VARIANT_COUNT := BRICK_WALL_VARIANT_GRID_COLS * BRICK_WALL_VARIANT_GRID_ROWS
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const EFFECT_PARTICLE_ALPHA_CUTOFF := 0.02

var brick_wall_variant_sheet_texture: Texture2D


func prewarm_assets() -> void:
	_touch_texture(get_brick_wall_variant_sheet_texture())


func draw_brick_wall_effect(canvas: CanvasItem, brick_wall_context: Dictionary, shake_offset: Vector2) -> void:
	var walls: Array = brick_wall_context.get("walls", [])
	for wall_value in walls:
		if not (wall_value is Dictionary):
			continue
		var wall: Dictionary = wall_value
		_draw_brick_wall(
			canvas,
			_get_rect2(wall, "rect", Rect2()),
			int(wall.get("crack_level", 0)),
			1.0,
			shake_offset,
			int(wall.get("visual_variant", -1)),
			int(wall.get("crack_seed", 0)),
			_get_vector2(wall, "crack_origin_ratio", Vector2(-1.0, -1.0))
		)

	if bool(brick_wall_context.get("installing", false)):
		var pending_wall: Dictionary = _get_dictionary(brick_wall_context, "pending_wall")
		var wall_rect: Rect2 = _get_rect2(pending_wall, "rect", Rect2())
		if wall_rect.size.x > 0.0 and wall_rect.size.y > 0.0:
			var timer_frames: float = float(brick_wall_context.get("install_timer_frames", 0.0))
			var initial_frames: float = max(1.0, float(brick_wall_context.get("install_initial_frames", 30.0)))
			var progress: float = clamp(1.0 - timer_frames / initial_frames, 0.0, 1.0)
			_draw_brick_wall(
				canvas,
				wall_rect,
				0,
				0.42 + progress * 0.30,
				shake_offset,
				int(pending_wall.get("visual_variant", -1))
			)
			_draw_brick_install_gauge(canvas, pending_wall, progress, shake_offset)

	var particles: Array = brick_wall_context.get("particles", [])
	for particle_value in particles:
		if particle_value is Dictionary:
			_draw_brick_particle(canvas, particle_value, shake_offset)


func get_brick_wall_variant_sheet_texture() -> Texture2D:
	if brick_wall_variant_sheet_texture == null:
		brick_wall_variant_sheet_texture = ProjectResourceLoader.load_texture(
			BRICK_WALL_VARIANT_SHEET_PATH,
			"Missing brick wall variant sheet at %s",
			"Failed to load brick wall variant sheet at %s"
		)
	return brick_wall_variant_sheet_texture


func get_brick_wall_variant_index(wall_rect: Rect2, visual_variant: int) -> int:
	if visual_variant >= 0:
		return visual_variant % BRICK_WALL_VARIANT_COUNT
	var fallback_seed: int = int(round(wall_rect.position.x * 7.0 + wall_rect.position.y * 3.0 + wall_rect.size.x * 5.0))
	return int(abs(fallback_seed)) % BRICK_WALL_VARIANT_COUNT


func get_brick_wall_variant_source_rect(sheet: Texture2D, variant_index: int) -> Rect2:
	var texture_size: Vector2 = sheet.get_size()
	var cell_size := Vector2(
		texture_size.x / float(BRICK_WALL_VARIANT_GRID_COLS),
		texture_size.y / float(BRICK_WALL_VARIANT_GRID_ROWS)
	)
	var clamped_index: int = clampi(variant_index, 0, BRICK_WALL_VARIANT_COUNT - 1)
	var source_col: int = clamped_index % BRICK_WALL_VARIANT_GRID_COLS
	var source_row: int = int(floor(float(clamped_index) / float(BRICK_WALL_VARIANT_GRID_COLS)))
	return Rect2(
		Vector2(float(source_col) * cell_size.x, float(source_row) * cell_size.y),
		cell_size
	)


func _draw_brick_wall(
	canvas: CanvasItem,
	wall_rect: Rect2,
	crack_level: int,
	alpha: float,
	shake_offset: Vector2,
	visual_variant: int = -1,
	crack_seed: int = 0,
	crack_origin_ratio: Vector2 = Vector2(-1.0, -1.0)
) -> void:
	if wall_rect.size.x <= 0.0 or wall_rect.size.y <= 0.0:
		return

	var draw_rect := Rect2(wall_rect.position + shake_offset, wall_rect.size)
	var variant_sheet: Texture2D = get_brick_wall_variant_sheet_texture()
	if variant_sheet != null:
		var variant_index: int = get_brick_wall_variant_index(wall_rect, visual_variant)
		canvas.draw_texture_rect_region(
			variant_sheet,
			draw_rect,
			get_brick_wall_variant_source_rect(variant_sheet, variant_index),
			Color(1.0, 1.0, 1.0, alpha)
		)
		_draw_brick_cracks(canvas, draw_rect, crack_level, alpha, crack_seed, crack_origin_ratio)
		return

	var base_color := Color(139.0 / 255.0, 69.0 / 255.0, 19.0 / 255.0, alpha)
	if crack_level == 1:
		base_color = Color(120.0 / 255.0, 60.0 / 255.0, 30.0 / 255.0, alpha)
	elif crack_level >= 2:
		base_color = Color(90.0 / 255.0, 45.0 / 255.0, 25.0 / 255.0, alpha)

	canvas.draw_rect(draw_rect, Color(0.0, 0.0, 0.0, 0.22 * alpha))
	canvas.draw_rect(draw_rect, base_color)
	canvas.draw_line(draw_rect.position, draw_rect.position + Vector2(draw_rect.size.x, 0.0), Color(205.0 / 255.0, 130.0 / 255.0, 75.0 / 255.0, 0.78 * alpha), 2.0)
	canvas.draw_line(draw_rect.position, draw_rect.position + Vector2(0.0, draw_rect.size.y), Color(205.0 / 255.0, 130.0 / 255.0, 75.0 / 255.0, 0.58 * alpha), 1.0)
	canvas.draw_line(draw_rect.position + Vector2(0.0, draw_rect.size.y), draw_rect.end, Color(55.0 / 255.0, 25.0 / 255.0, 15.0 / 255.0, 0.76 * alpha), 2.0)
	canvas.draw_line(draw_rect.position + Vector2(draw_rect.size.x, 0.0), draw_rect.end, Color(55.0 / 255.0, 25.0 / 255.0, 15.0 / 255.0, 0.62 * alpha), 1.0)

	var mortar_color := Color(70.0 / 255.0, 35.0 / 255.0, 20.0 / 255.0, 0.74 * alpha)
	for row in range(1, 3):
		var y: float = draw_rect.position.y + draw_rect.size.y * float(row) / 3.0
		canvas.draw_line(Vector2(draw_rect.position.x, y), Vector2(draw_rect.end.x, y), mortar_color, 1.0)
	for col in range(1, 4):
		var x: float = draw_rect.position.x + draw_rect.size.x * float(col) / 4.0
		var y_offset: float = draw_rect.size.y / 3.0 if col % 2 == 0 else 0.0
		canvas.draw_line(Vector2(x, draw_rect.position.y + y_offset), Vector2(x, draw_rect.end.y), mortar_color, 1.0)

	canvas.draw_rect(draw_rect, Color(35.0 / 255.0, 18.0 / 255.0, 12.0 / 255.0, 0.88 * alpha), false, 2.0)
	_draw_brick_cracks(canvas, draw_rect, crack_level, alpha, crack_seed, crack_origin_ratio)


func _draw_brick_cracks(
	canvas: CanvasItem,
	draw_rect: Rect2,
	crack_level: int,
	alpha: float,
	crack_seed: int = 0,
	crack_origin_ratio: Vector2 = Vector2(-1.0, -1.0)
) -> void:
	if crack_level <= 0:
		return
	var seed_value: int = _get_brick_crack_seed(draw_rect, crack_level, crack_seed)
	var origin_ratio: Vector2 = _get_brick_crack_origin_ratio(seed_value, crack_origin_ratio)
	var origin := Vector2(
		draw_rect.position.x + draw_rect.size.x * origin_ratio.x,
		draw_rect.position.y + draw_rect.size.y * origin_ratio.y
	)
	var primary_sign := -1.0 if _brick_crack_random(seed_value, 1) < 0.5 else 1.0
	var primary_angle: float = (0.0 if primary_sign > 0.0 else PI) + lerpf(-0.34, 0.34, _brick_crack_random(seed_value, 2))
	var primary_length: float = draw_rect.size.x * lerpf(0.26, 0.42, _brick_crack_random(seed_value, 3))
	var primary_points: PackedVector2Array = _build_brick_crack_path(draw_rect, origin, primary_angle, primary_length, 5, seed_value, 10)
	_draw_brick_crack_polyline(canvas, primary_points, alpha, 1.45)

	var counter_angle: float = primary_angle + PI + lerpf(-0.26, 0.26, _brick_crack_random(seed_value, 4))
	var counter_length: float = draw_rect.size.x * lerpf(0.14, 0.25, _brick_crack_random(seed_value, 5))
	_draw_brick_crack_polyline(
		canvas,
		_build_brick_crack_path(draw_rect, origin, counter_angle, counter_length, 3, seed_value, 30),
		alpha,
		1.25
	)

	var branch_count: int = 4 + min(crack_level, 2) * 2
	for branch_index in range(branch_count):
		var branch_anchor: Vector2 = _pick_crack_branch_anchor(primary_points, branch_index, seed_value)
		var branch_side := -1.0 if branch_index % 2 == 0 else 1.0
		var branch_angle: float = primary_angle + branch_side * lerpf(0.7, 1.45, _brick_crack_random(seed_value, 50 + branch_index))
		if _brick_crack_random(seed_value, 70 + branch_index) < 0.32:
			branch_angle += PI
		var branch_length: float = draw_rect.size.x * lerpf(0.08, 0.18, _brick_crack_random(seed_value, 90 + branch_index))
		_draw_brick_crack_polyline(
			canvas,
			_build_brick_crack_path(draw_rect, branch_anchor, branch_angle, branch_length, 2 + branch_index % 2, seed_value, 110 + branch_index * 7),
			alpha,
			1.05
		)

	_draw_brick_crack_chips(canvas, draw_rect, origin, seed_value, crack_level, alpha)


func _build_brick_crack_path(
	draw_rect: Rect2,
	origin: Vector2,
	angle: float,
	length: float,
	segments: int,
	seed_value: int,
	salt: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(origin)
	var current: Vector2 = origin
	var segment_count: int = max(1, segments)
	for segment_index in range(segment_count):
		var jitter: float = lerpf(-0.42, 0.42, _brick_crack_random(seed_value, salt + segment_index * 3))
		var step_length: float = length / float(segment_count) * lerpf(0.72, 1.22, _brick_crack_random(seed_value, salt + segment_index * 3 + 1))
		current += Vector2(cos(angle + jitter), sin(angle + jitter)) * step_length
		current.x = clamp(current.x, draw_rect.position.x + 2.0, draw_rect.end.x - 2.0)
		current.y = clamp(current.y, draw_rect.position.y + 2.0, draw_rect.end.y - 2.0)
		points.append(current)
	return points


func _draw_brick_crack_polyline(canvas: CanvasItem, points: PackedVector2Array, alpha: float, width: float) -> void:
	if points.size() < 2:
		return
	var shadow_color := Color(9.0 / 255.0, 5.0 / 255.0, 3.0 / 255.0, 0.86 * alpha)
	var inner_color := Color(28.0 / 255.0, 14.0 / 255.0, 8.0 / 255.0, 0.94 * alpha)
	var highlight_color := Color(214.0 / 255.0, 124.0 / 255.0, 64.0 / 255.0, 0.22 * alpha)
	for point_index in range(points.size() - 1):
		canvas.draw_line(points[point_index], points[point_index + 1], shadow_color, width + 0.8)
	for point_index in range(points.size() - 1):
		canvas.draw_line(points[point_index], points[point_index + 1], inner_color, width)
	for point_index in range(points.size() - 1):
		canvas.draw_line(points[point_index] + Vector2(-0.45, -0.45), points[point_index + 1] + Vector2(-0.45, -0.45), highlight_color, max(0.55, width * 0.42))


func _draw_brick_crack_chips(
	canvas: CanvasItem,
	draw_rect: Rect2,
	origin: Vector2,
	seed_value: int,
	crack_level: int,
	alpha: float
) -> void:
	var chip_count: int = 3 + min(crack_level, 2) * 2
	for chip_index in range(chip_count):
		var chip_pos := origin + Vector2(
			lerpf(-draw_rect.size.x * 0.16, draw_rect.size.x * 0.16, _brick_crack_random(seed_value, 160 + chip_index * 2)),
			lerpf(-draw_rect.size.y * 0.34, draw_rect.size.y * 0.34, _brick_crack_random(seed_value, 161 + chip_index * 2))
		)
		chip_pos.x = clamp(chip_pos.x, draw_rect.position.x + 3.0, draw_rect.end.x - 3.0)
		chip_pos.y = clamp(chip_pos.y, draw_rect.position.y + 3.0, draw_rect.end.y - 3.0)
		var radius: float = lerpf(0.75, 1.75, _brick_crack_random(seed_value, 190 + chip_index))
		canvas.draw_circle(chip_pos, radius + 0.5, Color(12.0 / 255.0, 7.0 / 255.0, 4.0 / 255.0, 0.42 * alpha))
		canvas.draw_circle(chip_pos + Vector2(-0.25, -0.25), radius * 0.42, Color(210.0 / 255.0, 112.0 / 255.0, 52.0 / 255.0, 0.22 * alpha))


func _pick_crack_branch_anchor(points: PackedVector2Array, branch_index: int, seed_value: int) -> Vector2:
	if points.size() <= 1:
		return Vector2.ZERO
	var min_index: int = 1
	var max_index: int = maxi(1, points.size() - 2)
	var anchor_index: int = clampi(min_index + int(floor(_brick_crack_random(seed_value, 130 + branch_index) * float(max_index))), min_index, max_index)
	return points[anchor_index]


func _get_brick_crack_seed(draw_rect: Rect2, crack_level: int, crack_seed: int) -> int:
	if crack_seed > 0:
		return crack_seed
	return int(abs(round(draw_rect.position.x * 17.0 + draw_rect.position.y * 31.0 + draw_rect.size.x * 13.0 + float(crack_level) * 97.0))) + 1


func _get_brick_crack_origin_ratio(seed_value: int, crack_origin_ratio: Vector2) -> Vector2:
	if crack_origin_ratio.x >= 0.0 and crack_origin_ratio.y >= 0.0:
		return Vector2(
			clamp(crack_origin_ratio.x, 0.12, 0.88),
			clamp(crack_origin_ratio.y, 0.18, 0.82)
		)
	return Vector2(
		lerpf(0.26, 0.74, _brick_crack_random(seed_value, 210)),
		lerpf(0.26, 0.74, _brick_crack_random(seed_value, 211))
	)


func _brick_crack_random(seed_value: int, salt: int) -> float:
	var raw: float = sin(float(seed_value) * 12.9898 + float(salt) * 78.233) * 43758.5453
	return fposmod(raw, 1.0)


func _draw_brick_install_gauge(
	canvas: CanvasItem,
	pending_wall: Dictionary,
	progress: float,
	shake_offset: Vector2
) -> void:
	var gauge_center: Vector2 = _get_vector2(pending_wall, "gauge_center", Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - 80.0)) + shake_offset
	var gauge_size := Vector2(80.0, 8.0)
	var gauge_rect := Rect2(gauge_center - gauge_size * 0.5, gauge_size)
	canvas.draw_rect(gauge_rect, Color(80.0 / 255.0, 80.0 / 255.0, 80.0 / 255.0, 0.92))
	canvas.draw_rect(gauge_rect, Color(139.0 / 255.0, 69.0 / 255.0, 19.0 / 255.0, 1.0), false, 2.0)
	var fill_color := Color(139.0 / 255.0, 69.0 / 255.0, 19.0 / 255.0, 1.0)
	if progress >= 0.8:
		fill_color = Color(1.0, 220.0 / 255.0, 70.0 / 255.0, 1.0)
	elif progress >= 0.5:
		fill_color = Color(160.0 / 255.0, 82.0 / 255.0, 45.0 / 255.0, 1.0)
	var fill_width: float = max(0.0, (gauge_size.x - 4.0) * progress)
	if fill_width > 0.5:
		canvas.draw_rect(Rect2(gauge_rect.position + Vector2(2.0, 2.0), Vector2(fill_width, gauge_size.y - 4.0)), fill_color)
	_draw_brick_hammer_icon(canvas, gauge_center + Vector2(55.0, 0.0), progress)


func _draw_brick_hammer_icon(canvas: CanvasItem, center: Vector2, progress: float) -> void:
	canvas.draw_circle(center, 12.0, Color(50.0 / 255.0, 50.0 / 255.0, 50.0 / 255.0, 0.94))
	canvas.draw_circle(center, 12.0, Color(100.0 / 255.0, 100.0 / 255.0, 100.0 / 255.0, 0.88), false, 2.0)
	var hammer_frame: int = int(progress * 30.0) % 20
	var angle_degrees: float = 0.0
	if hammer_frame < 5:
		angle_degrees = -45.0
	elif hammer_frame < 8:
		angle_degrees = 35.0
	elif hammer_frame >= 10 and hammer_frame < 15:
		angle_degrees = -35.0
	elif hammer_frame >= 15 and hammer_frame < 18:
		angle_degrees = 30.0
	var angle: float = deg_to_rad(angle_degrees - 90.0)
	var handle_end: Vector2 = center + Vector2(cos(angle), sin(angle)) * 8.0
	canvas.draw_line(center, handle_end, Color(101.0 / 255.0, 67.0 / 255.0, 33.0 / 255.0, 1.0), 2.0)
	var head_a: Vector2 = handle_end + Vector2(cos(angle + PI * 0.5), sin(angle + PI * 0.5)) * 4.0
	var head_b: Vector2 = handle_end + Vector2(cos(angle - PI * 0.5), sin(angle - PI * 0.5)) * 4.0
	canvas.draw_line(head_a, head_b, Color(165.0 / 255.0, 165.0 / 255.0, 165.0 / 255.0, 1.0), 5.0)
	canvas.draw_line(head_a, head_b, Color(90.0 / 255.0, 90.0 / 255.0, 90.0 / 255.0, 1.0), 1.0)
	if hammer_frame == 7 or hammer_frame == 17:
		canvas.draw_circle(center + Vector2(0.0, 6.0), 2.2, Color(1.0, 220.0 / 255.0, 100.0 / 255.0, 1.0))
	canvas.draw_line(center + Vector2(-2.0, 7.0), center + Vector2(2.0, 7.0), Color(80.0 / 255.0, 80.0 / 255.0, 80.0 / 255.0, 1.0), 2.0)


func _draw_brick_particle(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2) -> void:
	var life: float = max(0.0, float(particle.get("life", 0.0)))
	var initial_life: float = max(1.0, float(particle.get("initial_life", life)))
	var life_ratio: float = clamp(life / initial_life, 0.0, 1.0)
	if life_ratio <= EFFECT_PARTICLE_ALPHA_CUTOFF:
		return
	var center: Vector2 = _get_vector2(particle, "position", Vector2.ZERO) + shake_offset
	var color: Color = _get_color(particle.get("color", Color(139.0 / 255.0, 69.0 / 255.0, 19.0 / 255.0, 1.0)), Color(139.0 / 255.0, 69.0 / 255.0, 19.0 / 255.0, 1.0))
	if str(particle.get("kind", "dust")) == "brick":
		_draw_brick_fragment_particle(canvas, center, particle, color, life_ratio)
		return
	var radius: float = max(1.0, float(particle.get("radius", 3.0))) * (0.65 + life_ratio * 0.35)
	canvas.draw_circle(center, radius * 1.8, Color(color.r, color.g, color.b, 0.10 * life_ratio))
	canvas.draw_circle(center, radius, Color(color.r, color.g, color.b, 0.62 * life_ratio))


func _draw_brick_fragment_particle(
	canvas: CanvasItem,
	center: Vector2,
	particle: Dictionary,
	color: Color,
	life_ratio: float
) -> void:
	var size: Vector2 = _get_vector2(particle, "size", Vector2(6.0, 4.0))
	var rotation: float = float(particle.get("rotation", 0.0))
	var draw_color := Color(color.r, color.g, color.b, 0.92 * life_ratio)
	var outline_color := Color(45.0 / 255.0, 22.0 / 255.0, 12.0 / 255.0, 0.55 * life_ratio)
	var half_size: Vector2 = size * 0.5
	var local_corners := [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	]
	var points := PackedVector2Array()
	for corner in local_corners:
		points.append(_rotated_local(center, corner, rotation))
	canvas.draw_colored_polygon(points, draw_color)
	for i in range(points.size()):
		canvas.draw_line(points[i], points[(i + 1) % points.size()], outline_color, 1.0)


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		return Color(float(value[0]) / 255.0, float(value[1]) / 255.0, float(value[2]) / 255.0, 1.0)
	return fallback


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _rotated_local(center: Vector2, local: Vector2, angle: float) -> Vector2:
	return center + Vector2(
		local.x * cos(angle) - local.y * sin(angle),
		local.x * sin(angle) + local.y * cos(angle)
	)


func _get_rect2(source: Dictionary, key: String, fallback: Rect2) -> Rect2:
	var value: Variant = source.get(key, fallback)
	if value is Rect2:
		return value
	return fallback


func _touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_size()
