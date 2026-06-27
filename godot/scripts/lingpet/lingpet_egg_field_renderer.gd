extends RefCounted

const EGG_RADIUS := 28.0
const EGG_TEXTURE_DRAW_SIZE := Vector2(88.0, 88.0)
const EGG_TEXTURE_TOP_OFFSET_RATIO := 0.48
const EGG_PLAYER_WOBBLE_VISUAL_PIXELS := 1.6
const HATCH_FLASH_SECONDS := 0.50
const EGG_CRACK_LIGHT_MAIN_WIDTH := 2.1
const EGG_CRACK_LIGHT_GLOW_WIDTH := 6.0
const HATCH_BREAK_SHARD_COUNT := 9
const HATCH_BREAK_SHARD_DISTANCE := 44.0
const HATCH_BREAK_SHARD_GRAVITY := 20.0
const EGG_TINTS := [
	Color(0.36, 0.82, 1.0),
	Color(1.0, 0.46, 0.64),
	Color(1.0, 0.74, 0.32),
	Color(0.66, 0.50, 1.0),
	Color(0.42, 0.92, 0.64),
]


func get_tint_count() -> int:
	return EGG_TINTS.size()


func get_tint_for_index(index: int) -> Color:
	if index < 0 or index >= EGG_TINTS.size():
		return Color.WHITE
	return EGG_TINTS[index]


func get_visual_key_for_hits(hatch_hits: int, required_hits: int) -> String:
	var safe_required_hits: int = maxi(1, required_hits)
	if hatch_hits <= 0:
		return "egg"
	if hatch_hits >= safe_required_hits - 1:
		return "egg_crack_2"
	return "egg_crack_1"


func draw_egg(
	canvas: CanvasItem,
	center: Vector2,
	hatch_hits: int,
	required_hits: int,
	wobble_angle: float,
	egg_texture: Texture2D,
	tint: Color = Color.WHITE
) -> void:
	if canvas == null:
		return
	var hit_ratio: float = clampf(float(hatch_hits) / float(maxi(1, required_hits)), 0.0, 1.0)
	var pulse: float = 0.5 + sin(float(Time.get_ticks_msec()) * 0.006) * 0.5
	var glow_alpha: float = 0.16 + 0.10 * pulse + 0.12 * hit_ratio
	var wobble_radians: float = deg_to_rad(wobble_angle)
	var visual_center: Vector2 = center + Vector2(sin(wobble_radians) * EGG_PLAYER_WOBBLE_VISUAL_PIXELS, absf(sin(wobble_radians)) * 1.2)
	canvas.draw_circle(visual_center + Vector2(0.0, 3.0), EGG_RADIUS + 16.0, Color(tint.r, tint.g, tint.b, glow_alpha))
	var texture_rect := Rect2(
		visual_center - Vector2(EGG_TEXTURE_DRAW_SIZE.x * 0.5, EGG_TEXTURE_DRAW_SIZE.y * EGG_TEXTURE_TOP_OFFSET_RATIO),
		EGG_TEXTURE_DRAW_SIZE
	)
	if egg_texture != null:
		canvas.draw_texture_rect(egg_texture, texture_rect, false, Color(tint.r, tint.g, tint.b, tint.a))
	_draw_egg_crack_light(canvas, texture_rect, hatch_hits, pulse)


func draw_hatch_flash(canvas: CanvasItem, center: Vector2, hatch_flash_timer: float) -> void:
	if canvas == null:
		return
	var t: float = clampf(hatch_flash_timer / HATCH_FLASH_SECONDS, 0.0, 1.0)
	_draw_hatch_shell_burst(canvas, center, t)
	var radius: float = lerpf(18.0, 74.0, 1.0 - t)
	canvas.draw_circle(center, radius, Color(1.0, 0.76, 0.94, 0.24 * t))
	canvas.draw_arc(center, radius * 0.72, 0.0, TAU, 48, Color(0.44, 1.0, 1.0, 0.58 * t), 3.0, true)


func _draw_egg_crack_light(canvas: CanvasItem, texture_rect: Rect2, hatch_hits: int, pulse: float) -> void:
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
	_draw_egg_crack_light_path(canvas, texture_rect, main_crack, leak_alpha, 1.0)
	var side_crack: Array[Vector2] = [
		Vector2(0.69, 0.24),
		Vector2(0.66, 0.35),
		Vector2(0.70, 0.48),
	]
	_draw_egg_crack_light_path(canvas, texture_rect, side_crack, leak_alpha * 0.72, 0.74)
	if hatch_hits >= 2:
		var lower_crack: Array[Vector2] = [
			Vector2(0.50, 0.56),
			Vector2(0.47, 0.68),
			Vector2(0.52, 0.80),
		]
		_draw_egg_crack_light_path(canvas, texture_rect, lower_crack, leak_alpha * 0.82, 0.86)


func _draw_egg_crack_light_path(
	canvas: CanvasItem,
	texture_rect: Rect2,
	path_ratios: Array[Vector2],
	alpha: float,
	width_scale: float
) -> void:
	if path_ratios.size() < 2:
		return
	var points := PackedVector2Array()
	for ratio: Vector2 in path_ratios:
		points.append(texture_rect.position + Vector2(texture_rect.size.x * ratio.x, texture_rect.size.y * ratio.y))
	var glow_width: float = EGG_CRACK_LIGHT_GLOW_WIDTH * width_scale
	var core_width: float = EGG_CRACK_LIGHT_MAIN_WIDTH * width_scale
	canvas.draw_polyline(points, Color(0.20, 1.0, 1.0, 0.20 * alpha), glow_width, true)
	canvas.draw_polyline(points, Color(1.0, 0.92, 0.36, 0.50 * alpha), core_width, true)
	canvas.draw_polyline(points, Color(1.0, 1.0, 0.86, 0.82 * alpha), maxf(0.75, core_width * 0.38), true)
	for i in range(points.size()):
		if i % 2 == 0:
			canvas.draw_circle(points[i], maxf(1.0, core_width * 0.44), Color(0.78, 1.0, 1.0, 0.34 * alpha))


func _draw_hatch_shell_burst(canvas: CanvasItem, center: Vector2, timer_ratio: float) -> void:
	var burst_progress: float = clampf(1.0 - timer_ratio, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - burst_progress, 2.0)
	var fade: float = clampf(timer_ratio * 1.18, 0.0, 1.0)
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
		var shell_color: Color = Color(1.0, 0.74, 0.93, 0.82 * fade)
		if i % 3 == 1:
			shell_color = Color(0.62, 0.95, 1.0, 0.74 * fade)
		elif i % 3 == 2:
			shell_color = Color(1.0, 0.91, 0.98, 0.78 * fade)
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
