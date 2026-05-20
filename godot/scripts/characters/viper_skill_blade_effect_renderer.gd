extends RefCounted


func get_draw_constants(
	base_width: float,
	hitbox_height: float,
	dark_hitbox_height: float,
	fadeout_frames: float,
	rest_frames: float,
	dark_rest_frames: float
) -> Dictionary:
	return {
		"base_width": base_width,
		"hitbox_height": hitbox_height,
		"dark_hitbox_height": dark_hitbox_height,
		"fadeout_frames": fadeout_frames,
		"rest_frames": rest_frames,
		"dark_rest_frames": dark_rest_frames,
	}


func draw_blade_effects(canvas: CanvasItem, shake_offset: Vector2, runtime: Object, constants: Dictionary) -> void:
	if runtime.blade_projectile_active:
		draw_blade_projectile(
			canvas,
			runtime.blade_projectile_pos,
			runtime.blade_projectile_width,
			runtime.blade_dark_mode,
			runtime.blade_projectile_trail,
			get_main_blade_alive(runtime, float(constants.get("fadeout_frames", 30.0))),
			shake_offset,
			constants
		)
	for projectile_value in runtime.blade_followup_projectiles:
		if not (projectile_value is Dictionary):
			continue
		var projectile: Dictionary = projectile_value
		var alive: float = 1.0
		if bool(projectile.get("fadeout", false)):
			alive = clamp(float(projectile.get("fadeout_frames", 0.0)) / float(constants.get("fadeout_frames", 30.0)), 0.0, 1.0)
		draw_blade_projectile(
			canvas,
			_get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO),
			float(projectile.get("width", constants.get("base_width", 350.0))),
			bool(projectile.get("dark_mode", false)),
			projectile.get("trail", []),
			alive * 0.78,
			shake_offset,
			constants
		)
	if runtime.blade_motion_active:
		draw_blade_spin_afterimages(canvas, shake_offset, runtime, constants)


func get_main_blade_alive(runtime: Object, fadeout_frames: float) -> float:
	if not runtime.blade_projectile_active:
		return 0.0
	var travel: float = max(1.0, runtime.blade_projectile_start_y - runtime.blade_projectile_target_y)
	var progress: float = clamp(1.0 - ((runtime.blade_projectile_pos.y - runtime.blade_projectile_target_y) / travel), 0.0, 1.0)
	var fade_factor: float = 0.0
	if progress > 0.65:
		fade_factor = clamp((progress - 0.65) / 0.35, 0.0, 1.0)
	if runtime.blade_projectile_fadeout:
		var fadeout_factor: float = 1.0 - clamp(runtime.blade_projectile_fadeout_frames / fadeout_frames, 0.0, 1.0)
		fade_factor = max(fade_factor, fadeout_factor)
	return 1.0 - fade_factor


func draw_blade_projectile(
	canvas: CanvasItem,
	pos: Vector2,
	width: float,
	dark_mode: bool,
	trail_value: Variant,
	alive: float,
	shake_offset: Vector2,
	constants: Dictionary
) -> void:
	if alive <= 0.01:
		return
	var center: Vector2 = pos + shake_offset
	var half_w: float = max(24.0, width * 0.5)
	var height: float = float(constants.get("dark_hitbox_height", 83.0)) if dark_mode else float(constants.get("hitbox_height", 55.0))
	var trail: Array = trail_value if trail_value is Array else []
	var tail_shift: float = get_blade_tail_shift(pos, trail, height)
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * (0.012 if dark_mode else 0.018))
	for i in range(1, trail.size()):
		var prev: Vector2 = _get_vector2(trail[i - 1], pos) + shake_offset
		var curr: Vector2 = _get_vector2(trail[i], pos) + shake_offset
		var ratio: float = float(i) / max(1.0, float(trail.size() - 1))
		var trail_alpha: float = (0.12 + 0.30 * ratio) * alive
		var trail_color := Color(0.82, 0.05, 0.08, trail_alpha) if dark_mode else Color(0.54, 0.38, 0.88, trail_alpha)
		canvas.draw_line(prev, curr, trail_color, 2.0 + 4.0 * ratio, true)

	var layer_data: Array = [
		[1.00, Color(0.22, 0.10, 0.36, 0.18 * alive)],
		[0.82, Color(0.42, 0.24, 0.64, 0.30 * alive)],
		[0.62, Color(0.62, 0.40, 0.82, 0.43 * alive)],
		[0.36, Color(0.86, 0.72, 1.0, 0.58 * alive)],
	]
	if dark_mode:
		layer_data = [
			[1.08, Color(0.05, 0.0, 0.01, 0.26 * alive)],
			[0.92, Color(0.25, 0.02, 0.04, 0.42 * alive)],
			[0.70, Color(0.58, 0.04, 0.08, 0.55 * alive)],
			[0.48, Color(0.92, 0.20, 0.16, 0.62 * alive)],
			[0.22, Color(1.0, 0.66, 0.48, 0.70 * alive)],
		]
	for layer in layer_data:
		var scale: float = float(layer[0])
		var color: Color = layer[1]
		draw_blade_fan_polygon(canvas, center, half_w * scale, height * scale, tail_shift, color)

	var edge_color := Color(1.0, 0.34, 0.32, 0.88 * alive) if dark_mode else Color(0.86, 0.70, 1.0, 0.78 * alive)
	var edge_pts: PackedVector2Array = build_blade_arc_points(center, half_w * 1.15, height * 1.08, tail_shift, 18)
	for i in range(1, edge_pts.size()):
		canvas.draw_line(edge_pts[i - 1], edge_pts[i], edge_color, 3.2 if dark_mode else 2.2, true)
	var spine_top: Vector2 = center + Vector2(tail_shift, -height * 0.92)
	canvas.draw_line(center, spine_top, Color(1.0, 0.88, 0.72, 0.74 * alive) if dark_mode else Color(0.88, 0.82, 1.0, 0.70 * alive), 3.0, true)
	canvas.draw_circle(center, 10.0 + 5.0 * pulse, Color(1.0, 0.20, 0.16, 0.20 * alive) if dark_mode else Color(0.60, 0.32, 1.0, 0.18 * alive))
	for i in range(8 if not dark_mode else 14):
		var t: float = float(i) / max(1.0, float((8 if not dark_mode else 14) - 1))
		var angle: float = PI * 1.15 + t * PI * 0.70
		var spark: Vector2 = center + Vector2(cos(angle) * half_w * 1.05 + tail_shift * t, sin(angle) * height * 1.05)
		var shimmer: float = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.02 + float(i) * 1.7)
		canvas.draw_circle(spark, 1.5 + shimmer * 1.8, Color(1.0, 0.42, 0.32, 0.72 * alive * shimmer) if dark_mode else Color(0.90, 0.72, 1.0, 0.62 * alive * shimmer))


func draw_blade_fan_polygon(canvas: CanvasItem, center: Vector2, half_w: float, height: float, tail_shift: float, color: Color) -> void:
	var points := PackedVector2Array()
	points.append(center)
	var arc_points: PackedVector2Array = build_blade_arc_points(center, half_w * 1.12, height * 1.08, tail_shift, 15)
	for point in arc_points:
		points.append(point)
	if points.size() >= 3:
		var colors := PackedColorArray()
		for _i in range(points.size()):
			colors.append(color)
		canvas.draw_polygon(points, colors)


func build_blade_arc_points(center: Vector2, half_w: float, height: float, tail_shift: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(max(2, segments)):
		var t: float = float(i) / max(1.0, float(segments - 1))
		var angle: float = PI * 1.15 + t * PI * 0.70
		var curve_shift: float = tail_shift * t * t * (3.0 - 2.0 * t)
		points.append(center + Vector2(cos(angle) * half_w + curve_shift, sin(angle) * height))
	return points


func get_blade_tail_shift(pos: Vector2, trail: Array, height: float) -> float:
	if trail.size() < 2:
		return 0.0
	var oldest: Vector2 = _get_vector2(trail[0], pos)
	var shift: float = oldest.x - pos.x
	return clamp(shift, -height * 1.2, height * 1.2)


func draw_blade_spin_afterimages(canvas: CanvasItem, shake_offset: Vector2, runtime: Object, constants: Dictionary) -> void:
	var center: Vector2 = runtime.blade_motion_pos + runtime.blade_paddle_size * 0.5 + shake_offset
	var phase_alpha: float = 0.42 if runtime.blade_motion_phase < 2 else max(0.0, 1.0 - runtime.blade_motion_frames / max(1.0, float(constants.get("dark_rest_frames", 90.0)) if runtime.blade_dark_mode else float(constants.get("rest_frames", 66.0)))) * 0.32
	if phase_alpha <= 0.01:
		return
	var radius: float = 34.0 if not runtime.blade_dark_mode else 48.0
	var color := Color(0.92, 0.20, 0.18, phase_alpha) if runtime.blade_dark_mode else Color(0.70, 0.35, 1.0, phase_alpha)
	for i in range(3):
		var angle: float = runtime.blade_spin_angle + float(i) * TAU / 3.0
		var p0: Vector2 = center + Vector2(cos(angle), sin(angle) * 0.45) * radius
		var p1: Vector2 = center + Vector2(cos(angle + 0.9), sin(angle + 0.9) * 0.45) * radius
		canvas.draw_line(p0, p1, color, 5.0, true)
	canvas.draw_circle(center, radius * 0.45, Color(color.r, color.g, color.b, phase_alpha * 0.30))


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
