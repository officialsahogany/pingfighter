extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const EGG_RADIUS := 28.0
const EGG_TEXTURE_DRAW_SIZE := Vector2(88.0, 88.0)
const EGG_SEMI_MAJOR := 34.0
const EGG_SEMI_MINOR := 27.0
const HATCH_FLASH_SECONDS := 0.50
const EGG_CRACK_LIGHT_MAIN_WIDTH := 2.1
const EGG_CRACK_LIGHT_GLOW_WIDTH := 6.0
const HATCH_BREAK_SHARD_COUNT := 9
const HATCH_BREAK_SHARD_DISTANCE := 44.0
const HATCH_BREAK_SHARD_GRAVITY := 20.0
const EGG_BARE_VARIANT_PATHS := [
	"res://assets/sprites/lingpet/resonance_egg_bare_variant_0.png",
	"res://assets/sprites/lingpet/resonance_egg_bare_variant_1.png",
	"res://assets/sprites/lingpet/resonance_egg_bare_variant_2.png",
	"res://assets/sprites/lingpet/resonance_egg_bare_variant_3.png",
	"res://assets/sprites/lingpet/resonance_egg_bare_variant_4.png",
]
const EGG_VARIANT_GLOW := [
	Color(0.36, 0.82, 1.0),
	Color(1.0, 0.74, 0.32),
	Color(0.66, 0.50, 1.0),
	Color(1.0, 0.46, 0.64),
	Color(0.42, 0.92, 0.64),
]

var _variant_textures: Array = []


func prewarm() -> void:
	_variant_textures.clear()
	for path: String in EGG_BARE_VARIANT_PATHS:
		_variant_textures.append(_load_egg_texture(path))


func get_variant_count() -> int:
	return EGG_BARE_VARIANT_PATHS.size()


func draw_egg(
	canvas: CanvasItem,
	center: Vector2,
	hatch_hits: int,
	required_hits: int,
	wobble_angle: float,
	variant_index: int,
	roll_angle: float = 0.0
) -> void:
	if canvas == null:
		return
	var hit_ratio: float = clampf(float(hatch_hits) / float(maxi(1, required_hits)), 0.0, 1.0)
	var pulse: float = 0.5 + sin(float(Time.get_ticks_msec()) * 0.006) * 0.5
	var glow_alpha: float = 0.16 + 0.10 * pulse + 0.12 * hit_ratio
	var glow_color: Color = _get_glow_for_index(variant_index)
	canvas.draw_circle(center + Vector2(0.0, 3.0), EGG_RADIUS + 16.0, Color(glow_color.r, glow_color.g, glow_color.b, glow_alpha))
	var final_rotation: float = roll_angle + deg_to_rad(wobble_angle)
	var visual_center: Vector2 = center + Vector2(0.0, _get_roll_bob_offset(roll_angle))
	var texture_rect := Rect2(
		visual_center - EGG_TEXTURE_DRAW_SIZE * 0.5,
		EGG_TEXTURE_DRAW_SIZE
	)
	var egg_texture: Texture2D = _get_cached_variant_texture(variant_index)
	if egg_texture != null:
		_draw_rotated_texture(canvas, egg_texture, texture_rect, final_rotation)
	_draw_egg_crack_light(canvas, texture_rect, hatch_hits, pulse, final_rotation)


func draw_profile_egg(
	canvas: CanvasItem,
	center: Vector2,
	hatch_hits: int,
	required_hits: int,
	wobble_angle: float,
	variant_index: int,
	roll_angle: float = 0.0
) -> void:
	if canvas == null:
		return
	draw_egg(canvas, center, hatch_hits, required_hits, wobble_angle, variant_index, roll_angle)


func draw_hatch_flash(canvas: CanvasItem, center: Vector2, hatch_flash_timer: float, variant_index: int = -1) -> void:
	if canvas == null:
		return
	var glow: Color = _get_glow_for_index(variant_index)
	var t: float = clampf(hatch_flash_timer / HATCH_FLASH_SECONDS, 0.0, 1.0)
	_draw_hatch_shell_burst(canvas, center, t, variant_index)
	var radius: float = lerpf(18.0, 74.0, 1.0 - t)
	canvas.draw_circle(center, radius, Color(glow.r, glow.g, glow.b, 0.24 * t))
	canvas.draw_arc(center, radius * 0.72, 0.0, TAU, 48, Color(0.44, 1.0, 1.0, 0.58 * t), 3.0, true)


func _load_egg_texture(path: String) -> Texture2D:
	return ProjectResourceLoader.load_imported_texture(
		path,
		"[LingpetEggFieldRenderer] missing resonance egg texture: %s",
		"[LingpetEggFieldRenderer] failed to load resonance egg texture: %s"
	)


func _get_cached_variant_texture(index: int) -> Texture2D:
	if EGG_BARE_VARIANT_PATHS.is_empty():
		return null
	var normalized_index: int = _normalize_variant_index(index)
	if normalized_index < _variant_textures.size():
		var cached_value: Variant = _variant_textures[normalized_index]
		if cached_value is Texture2D:
			return cached_value as Texture2D
	var shared_cached: Texture2D = ProjectResourceLoader.get_cached_texture(EGG_BARE_VARIANT_PATHS[normalized_index])
	if shared_cached != null:
		while _variant_textures.size() < get_variant_count():
			_variant_textures.append(null)
		_variant_textures[normalized_index] = shared_cached
	return shared_cached


func _get_glow_for_index(index: int) -> Color:
	if EGG_VARIANT_GLOW.is_empty():
		return Color.WHITE
	var normalized_index: int = _normalize_variant_index(index)
	if normalized_index >= EGG_VARIANT_GLOW.size():
		return EGG_VARIANT_GLOW[0]
	return EGG_VARIANT_GLOW[normalized_index]


func _normalize_variant_index(index: int) -> int:
	var variant_count: int = get_variant_count()
	if index >= 0 and index < variant_count:
		return index
	return 0


func _get_roll_bob_offset(roll_angle: float) -> float:
	var contact_height: float = sqrt(
		pow(EGG_SEMI_MAJOR * cos(roll_angle), 2.0)
		+ pow(EGG_SEMI_MINOR * sin(roll_angle), 2.0)
	)
	return EGG_SEMI_MAJOR - contact_height


func _draw_rotated_texture(canvas: CanvasItem, texture: Texture2D, texture_rect: Rect2, rotation: float) -> void:
	var points: PackedVector2Array = _build_rotated_rect_points(texture_rect, rotation)
	var colors := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0),
	])
	canvas.draw_polygon(points, colors, uvs, texture)


func _build_rotated_rect_points(texture_rect: Rect2, rotation: float) -> PackedVector2Array:
	var center: Vector2 = texture_rect.get_center()
	var corners: Array[Vector2] = [
		texture_rect.position,
		texture_rect.position + Vector2(texture_rect.size.x, 0.0),
		texture_rect.position + texture_rect.size,
		texture_rect.position + Vector2(0.0, texture_rect.size.y),
	]
	var points := PackedVector2Array()
	for corner: Vector2 in corners:
		points.append(center + (corner - center).rotated(rotation))
	return points


func build_crack_light_points_for_tests(texture_rect: Rect2, path_ratios: Array[Vector2], rotation: float = 0.0) -> PackedVector2Array:
	return _build_egg_crack_light_points(texture_rect, path_ratios, rotation)


func _build_egg_crack_light_points(texture_rect: Rect2, path_ratios: Array[Vector2], rotation: float) -> PackedVector2Array:
	var center: Vector2 = texture_rect.get_center()
	var points := PackedVector2Array()
	for ratio: Vector2 in path_ratios:
		var point: Vector2 = texture_rect.position + Vector2(texture_rect.size.x * ratio.x, texture_rect.size.y * ratio.y)
		points.append(center + (point - center).rotated(rotation))
	return points


func _draw_egg_crack_light(canvas: CanvasItem, texture_rect: Rect2, hatch_hits: int, pulse: float, rotation: float) -> void:
	if hatch_hits <= 0:
		return
	var stage_boost: float = clampf(float(hatch_hits - 1) * 0.22, 0.0, 0.34)
	var leak_alpha: float = clampf(0.46 + 0.24 * pulse + stage_boost, 0.0, 0.92)
	var main_crack: Array[Vector2] = [
		Vector2(0.50, 0.15),
		Vector2(0.46, 0.26),
		Vector2(0.51, 0.36),
		Vector2(0.45, 0.49),
		Vector2(0.49, 0.63),
	]
	_draw_egg_crack_light_path(canvas, texture_rect, main_crack, leak_alpha, 1.0, rotation)
	var side_crack: Array[Vector2] = [
		Vector2(0.69, 0.24),
		Vector2(0.66, 0.35),
		Vector2(0.70, 0.48),
	]
	_draw_egg_crack_light_path(canvas, texture_rect, side_crack, leak_alpha * 0.72, 0.74, rotation)
	if hatch_hits >= 2:
		var lower_crack: Array[Vector2] = [
			Vector2(0.50, 0.56),
			Vector2(0.47, 0.68),
			Vector2(0.52, 0.80),
		]
		_draw_egg_crack_light_path(canvas, texture_rect, lower_crack, leak_alpha * 0.82, 0.86, rotation)


func _draw_egg_crack_light_path(
	canvas: CanvasItem,
	texture_rect: Rect2,
	path_ratios: Array[Vector2],
	alpha: float,
	width_scale: float,
	rotation: float
) -> void:
	if path_ratios.size() < 2:
		return
	var points: PackedVector2Array = _build_egg_crack_light_points(texture_rect, path_ratios, rotation)
	var glow_width: float = EGG_CRACK_LIGHT_GLOW_WIDTH * width_scale
	var core_width: float = EGG_CRACK_LIGHT_MAIN_WIDTH * width_scale
	canvas.draw_polyline(points, Color(0.20, 1.0, 1.0, 0.20 * alpha), glow_width, true)
	canvas.draw_polyline(points, Color(1.0, 0.92, 0.36, 0.50 * alpha), core_width, true)
	canvas.draw_polyline(points, Color(1.0, 1.0, 0.86, 0.82 * alpha), maxf(0.75, core_width * 0.38), true)
	for i in range(points.size()):
		if i % 2 == 0:
			canvas.draw_circle(points[i], maxf(1.0, core_width * 0.44), Color(0.78, 1.0, 1.0, 0.34 * alpha))


func _draw_hatch_shell_burst(canvas: CanvasItem, center: Vector2, timer_ratio: float, variant_index: int = -1) -> void:
	var burst_progress: float = clampf(1.0 - timer_ratio, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - burst_progress, 2.0)
	var fade: float = clampf(timer_ratio * 1.18, 0.0, 1.0)
	var glow: Color = _get_glow_for_index(variant_index)
	var egg_center: Vector2 = center + Vector2(0.0, -EGG_TEXTURE_DRAW_SIZE.y * 0.06)
	for i in range(HATCH_BREAK_SHARD_COUNT):
		var unit: float = float(i) / float(HATCH_BREAK_SHARD_COUNT)
		var angle: float = -PI * 0.92 + unit * PI * 1.84
		var drift: float = sin(float(i) * 2.17) * 0.18
		var dir := Vector2(cos(angle + drift), sin(angle + drift))
		var travel: float = HATCH_BREAK_SHARD_DISTANCE * (0.45 + 0.55 * _hatch_shard_unit(i + 2)) * eased
		var gravity := Vector2(0.0, HATCH_BREAK_SHARD_GRAVITY * burst_progress * burst_progress)
		var shard_center: Vector2 = egg_center + dir * travel + gravity
		var size: float = lerpf(8.5, 4.0, burst_progress) * (0.78 + 0.34 * _hatch_shard_unit(i + 11))
		var rotation: float = angle + burst_progress * lerpf(-1.7, 1.7, _hatch_shard_unit(i + 19))
		# Shards are the breaking shell, so they carry the egg's own variant tone
		# (lerped toward white for shell brightness) instead of a fixed pink palette.
		var shell_color: Color = glow.lerp(Color.WHITE, 0.25)
		shell_color.a = 0.82 * fade
		if i % 3 == 1:
			shell_color = glow.lerp(Color.WHITE, 0.55)
			shell_color.a = 0.74 * fade
		elif i % 3 == 2:
			shell_color = glow.lerp(Color.WHITE, 0.82)
			shell_color.a = 0.78 * fade
		_draw_hatch_shell_shard(canvas, shard_center, size, rotation, shell_color, fade)
		if i % 2 == 0:
			var sparkle_pos: Vector2 = egg_center + dir * (travel + 8.0)
			canvas.draw_circle(sparkle_pos, maxf(1.0, size * 0.22), Color(0.92, 1.0, 1.0, 0.58 * fade))


func _draw_hatch_shell_shard(canvas: CanvasItem, center: Vector2, size: float, rotation: float, fill_color: Color, fade: float) -> void:
	var points := PackedVector2Array()
	var local_points := [
		Vector2(-0.68, 0.46),
		Vector2(-0.18, -0.72),
		Vector2(0.70, -0.22),
		Vector2(0.32, 0.64),
	]
	for local: Vector2 in local_points:
		points.append(center + local.rotated(rotation) * size)
	canvas.draw_colored_polygon(points, fill_color)
	var outline := PackedVector2Array()
	for point: Vector2 in points:
		outline.append(point)
	outline.append(points[0])
	canvas.draw_polyline(outline, Color(0.18, 0.11, 0.24, 0.36 * fade), 1.0, true)


func _hatch_shard_unit(index: int) -> float:
	var shard_seed: int = int((index * 1103515245 + 12345) % 10000)
	return float(shard_seed) / 10000.0
