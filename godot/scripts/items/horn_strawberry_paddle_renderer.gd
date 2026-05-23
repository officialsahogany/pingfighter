extends RefCounted

const STRAWBERRY_RED := Color(0.88, 0.08, 0.13)
const STRAWBERRY_LIGHT := Color(0.98, 0.32, 0.36)
const STRAWBERRY_HIGHLIGHT := Color(1.0, 0.78, 0.82)
const STRAWBERRY_DARK := Color(0.48, 0.02, 0.06)
const FOOT_RED := Color(0.82, 0.18, 0.22)
const FOOT_LIGHT := Color(1.0, 0.46, 0.50)
const SEED_DARK := Color(0.56, 0.04, 0.06)
const SEED_GOLD := Color(0.94, 0.80, 0.24)
const LEAF_DARK := Color(0.12, 0.38, 0.08)
const LEAF_MID := Color(0.20, 0.64, 0.16)
const LEAF_BRIGHT := Color(0.42, 0.86, 0.28)

var _prev_center_x := 0.0
var _has_prev_center := false
var _walk_timer := 0.0


func draw(
	canvas: CanvasItem,
	context: Dictionary,
	player_pos: Vector2,
	paddle_size: Vector2,
	shake_offset: Vector2 = Vector2.ZERO,
	alpha: float = 1.0,
	extra_offset: Vector2 = Vector2.ZERO,
	axis_scale_x: float = 1.0
) -> Rect2:
	if canvas == null:
		return Rect2()
	var safe_size := Vector2(max(1.0, paddle_size.x), max(1.0, paddle_size.y))
	var clamped_alpha: float = clamp(alpha, 0.0, 1.0)
	if clamped_alpha <= 0.001:
		return Rect2(player_pos + shake_offset + extra_offset, safe_size)
	var center_x: float = player_pos.x + safe_size.x * 0.5
	var move_delta: float = 0.0 if not _has_prev_center else center_x - _prev_center_x
	_prev_center_x = center_x
	_has_prev_center = true
	var is_moving: bool = abs(move_delta) > 0.45 or abs(float(context.get("player_speed", 0.0))) > 0.2
	if is_moving:
		_walk_timer += 0.15

	var horn_context: Dictionary = _as_dictionary(context.get("horn_strawberry_context", {}))
	var eat_context: Dictionary = _as_dictionary(horn_context.get("eat", {}))
	var field_context: Dictionary = _as_dictionary(horn_context.get("field", {}))
	var bomb_context: Dictionary = _as_dictionary(horn_context.get("bomb", {}))
	var is_eating: bool = bool(eat_context.get("eating", false))
	var is_field_holding: bool = bool(field_context.get("holding", false))
	var is_bomb_holding: bool = bool(bomb_context.get("holding", false)) and not bool(bomb_context.get("throwing", false))
	var is_bomb_throwing: bool = bool(bomb_context.get("throwing", false))
	var current_msec: float = float(context.get("current_msec", Time.get_ticks_msec()))

	var motion: Dictionary = _build_motion(
		current_msec,
		move_delta,
		is_moving,
		is_eating,
		is_field_holding or is_bomb_holding,
		float(field_context.get("hold_timer_sec", bomb_context.get("hold_timer_sec", 0.0))),
		float(eat_context.get("head_bob_timer_sec", 0.0))
	)
	var radius: float = max(20.0, safe_size.x * 0.28)
	var body_height: float = radius * 2.2 * float(motion.get("squash", 1.0))
	var body_center := Vector2(
		center_x,
		player_pos.y + safe_size.y - body_height * 0.5 - 8.0 - float(motion.get("bounce_y", 0.0))
	) + shake_offset + extra_offset
	body_center.y += float(motion.get("head_bob", 0.0))
	var spin_scale: float = axis_scale_x
	if is_bomb_throwing:
		spin_scale *= cos(current_msec * 0.001 * 12.0 * TAU)
	var signed_axis_scale: float = clamp(spin_scale, -1.0, 1.0)
	var abs_axis_scale: float = max(0.12, abs(signed_axis_scale))
	var lean: float = clamp(float(motion.get("lean", 0.0)), -8.0, 8.0)
	var sway: float = sin(current_msec * 0.004) * 2.5

	_draw_shadow(canvas, body_center + Vector2(0.0, radius + 6.0), radius, abs_axis_scale, clamped_alpha)
	_draw_feet(canvas, body_center, radius, _walk_timer, move_delta, is_moving, is_eating, current_msec, abs_axis_scale, clamped_alpha)
	_draw_body(canvas, body_center, radius, float(motion.get("squash", 1.0)), lean, abs_axis_scale, clamped_alpha)
	_draw_seeds(canvas, body_center, radius, float(motion.get("squash", 1.0)), lean, abs_axis_scale, clamped_alpha)
	_draw_leaves(canvas, body_center, radius, body_height, sway, float(motion.get("leaf_drop", 0.0)), lean, abs_axis_scale, clamped_alpha)
	_draw_horns(canvas, body_center, radius, body_height, current_msec, lean, abs_axis_scale, signed_axis_scale < 0.0, clamped_alpha)
	return Rect2(body_center - Vector2(radius * 1.25, radius * 1.65), Vector2(radius * 2.5, radius * 3.0))


func draw_mini(
	canvas: CanvasItem,
	center: Vector2,
	paddle_width: float,
	alpha: float = 1.0,
	axis_scale_x: float = 1.0
) -> Rect2:
	var size := Vector2(max(40.0, paddle_width), max(18.0, paddle_width * 0.32))
	var pos := center - Vector2(size.x * 0.5, size.y * 0.65)
	return draw(canvas, {}, pos, size, Vector2.ZERO, alpha, Vector2.ZERO, axis_scale_x)


func _build_motion(
	current_msec: float,
	move_delta: float,
	is_moving: bool,
	is_eating: bool,
	is_holding: bool,
	hold_timer_sec: float,
	head_bob_timer_sec: float
) -> Dictionary:
	var bounce_y := 0.0
	var squash := 1.0
	var lean := 0.0
	var leaf_drop := 0.0
	if is_eating:
		var chew_timer: float = current_msec * 0.028
		var chew_bob: float = abs(sin(chew_timer))
		bounce_y = 2.0 + chew_bob * 5.0
		squash = 0.92 + chew_bob * 0.14
		lean = sin(chew_timer * 0.55) * 2.4
		leaf_drop = 2.0 + chew_bob * 3.0
	elif is_holding:
		var shake_t: float = current_msec * 0.04
		var intensity: float = clamp(hold_timer_sec / 0.5, 0.0, 1.0)
		bounce_y = 1.0 + abs(sin(shake_t * 3.0)) * 2.0 * intensity
		squash = 1.0 + sin(shake_t * 5.7) * 0.05 * intensity
		lean = sin(shake_t * 4.3) * 3.0 * intensity
	elif is_moving:
		bounce_y = abs(sin(_walk_timer * 3.5)) * 5.0
		squash = 1.0 + sin(_walk_timer * 7.0) * 0.06
		lean = clamp(move_delta * 1.2, -6.0, 6.0)
	else:
		bounce_y = sin(current_msec * 0.003) * 1.5
		squash = 1.0 + sin(current_msec * 0.004) * 0.02
	var head_bob := 0.0
	if head_bob_timer_sec > 0.0:
		var progress: float = 1.0 - clamp(head_bob_timer_sec / 0.4, 0.0, 1.0)
		head_bob = sin(progress * PI) * 14.0
		squash *= 1.0 + sin(progress * PI) * 0.08
	return {
		"bounce_y": bounce_y,
		"squash": squash,
		"lean": lean,
		"leaf_drop": leaf_drop,
		"head_bob": head_bob,
	}


func _draw_shadow(canvas: CanvasItem, center: Vector2, radius: float, axis_scale_x: float, alpha: float) -> void:
	_draw_ellipse(canvas, center, Vector2(radius * 0.72 * axis_scale_x, 4.0), Color(0.0, 0.0, 0.0, 0.16 * alpha), 24)


func _draw_feet(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	walk_timer: float,
	move_delta: float,
	is_moving: bool,
	is_eating: bool,
	current_msec: float,
	axis_scale_x: float,
	alpha: float
) -> void:
	var ground_y: float = center.y + radius + 2.0
	for side in [-1, 1]:
		var phase_offset: float = 0.0 if side == 1 else PI
		var step_phase: float = walk_timer * 3.5 + phase_offset
		var lift := 0.0
		var fwd := 0.0
		var spread := 0.0
		var land_squash := 0.0
		if is_moving:
			var cycle: float = sin(step_phase)
			lift = max(0.0, cycle) * 6.0
			fwd = sin(step_phase) * 3.0
			spread = move_delta * 0.3 * float(side)
			land_squash = max(0.0, -sin(step_phase + 0.3)) * 0.15
		elif is_eating:
			lift = abs(sin(current_msec * 0.014 + phase_offset)) * 2.0
		else:
			spread = sin(current_msec * 0.002 + phase_offset) * 0.3
		var foot_center := Vector2(
			center.x + (float(side) * radius * 0.40 + fwd + spread) * axis_scale_x,
			ground_y - lift
		)
		var foot_radius := Vector2((5.0 + land_squash * 3.0) * axis_scale_x, max(2.0, 3.5 - land_squash * 1.5))
		_draw_ellipse(canvas, Vector2(foot_center.x, ground_y + 1.0), Vector2(max(2.0, foot_radius.x * (1.0 - lift * 0.06)), 1.5), Color(0.0, 0.0, 0.0, max(0.04, 0.16 - lift * 0.018) * alpha), 16)
		_draw_ellipse(canvas, foot_center, foot_radius + Vector2(1.0, 0.8), _with_alpha(STRAWBERRY_DARK, 0.86 * alpha), 16)
		_draw_ellipse(canvas, foot_center, foot_radius, _with_alpha(FOOT_RED, 0.96 * alpha), 16)
		_draw_ellipse(canvas, foot_center + Vector2(-1.0 * float(side), -1.0), foot_radius * Vector2(0.58, 0.46), _with_alpha(FOOT_LIGHT, 0.72 * alpha), 14)


func _draw_body(canvas: CanvasItem, center: Vector2, radius: float, squash: float, lean: float, axis_scale_x: float, alpha: float) -> void:
	var body_width: float = radius * 2.0 * (2.0 - squash) * axis_scale_x
	var body_height: float = radius * 2.2 * squash
	var points := PackedVector2Array()
	for i in range(28):
		var angle: float = TAU * float(i) / 28.0 - PI * 0.5
		var norm_y: float = sin(angle)
		var width_scale: float = 1.0 + abs(norm_y) * 0.05 if norm_y < 0.0 else 1.0 - norm_y * 0.45
		var local_y: float = sin(angle) * body_height * 0.5
		var local_x: float = cos(angle) * body_width * 0.5 * width_scale
		points.append(_lean_point(center, local_x, local_y, body_height, lean))
	canvas.draw_polygon(points, PackedColorArray([_with_alpha(STRAWBERRY_RED, 0.98 * alpha)]))
	var lower_shadow := PackedVector2Array()
	for point in points:
		if point.y >= center.y:
			lower_shadow.append(point)
	if lower_shadow.size() >= 3:
		lower_shadow.append(center + Vector2(body_width * 0.34, body_height * 0.05))
		lower_shadow.append(center + Vector2(-body_width * 0.34, body_height * 0.05))
		canvas.draw_polygon(lower_shadow, PackedColorArray([Color(0.24, 0.0, 0.02, 0.17 * alpha)]))
	_draw_ellipse(canvas, center + Vector2(-body_width * 0.13, -body_height * 0.19), Vector2(radius * 0.34 * axis_scale_x, radius * 0.24), _with_alpha(STRAWBERRY_LIGHT, 0.34 * alpha), 20)
	_draw_ellipse(canvas, center + Vector2(-body_width * 0.15, -body_height * 0.22), Vector2(radius * 0.18 * axis_scale_x, radius * 0.12), _with_alpha(STRAWBERRY_HIGHLIGHT, 0.46 * alpha), 16)
	_draw_polyline_closed(canvas, points, _with_alpha(STRAWBERRY_DARK, 0.90 * alpha), 2.0)


func _draw_seeds(canvas: CanvasItem, center: Vector2, radius: float, squash: float, lean: float, axis_scale_x: float, alpha: float) -> void:
	var body_height: float = radius * 2.2 * squash
	var rows := [
		{"y": -0.25, "count": 5},
		{"y": 0.05, "count": 6},
		{"y": 0.35, "count": 4},
	]
	for row in rows:
		var row_y: float = float(row["y"])
		var count: int = int(row["count"])
		var width_scale: float = 1.0 + abs(row_y) * 0.05 if row_y < 0.0 else 1.0 - row_y * 0.45
		var row_width: float = radius * width_scale * 0.72 * axis_scale_x
		for idx in range(count):
			var frac: float = (float(idx) + 0.5) / float(count)
			var jitter_x: float = sin(float(idx) * 12.989 + row_y * 78.23) * 1.2
			var jitter_y: float = cos(float(idx) * 8.127 + row_y * 41.17) * 1.1
			var local_x: float = lerp(-row_width, row_width, frac) + jitter_x
			var local_y: float = row_y * body_height * 0.5 + jitter_y
			var seed_center: Vector2 = _lean_point(center, local_x, local_y, body_height, lean)
			_draw_ellipse(canvas, seed_center + Vector2(0.0, 0.8), Vector2(2.3 * axis_scale_x, 1.8), _with_alpha(SEED_DARK, 0.72 * alpha), 10)
			_draw_ellipse(canvas, seed_center, Vector2(1.8 * axis_scale_x, 1.35), _with_alpha(SEED_GOLD, 0.92 * alpha), 10)


func _draw_leaves(canvas: CanvasItem, center: Vector2, radius: float, body_height: float, sway: float, leaf_drop: float, lean: float, axis_scale_x: float, alpha: float) -> void:
	var leaf_y: float = -body_height * 0.5 + 2.0 + leaf_drop
	for side in [-1, 1]:
		var base := _lean_point(center, float(side) * radius * 0.25 * axis_scale_x, leaf_y + 5.0, body_height, lean)
		var tip := _lean_point(center, float(side) * radius * 0.48 * axis_scale_x + float(side) * 10.0 + sway * 0.4, leaf_y - 5.0, body_height, lean)
		var inner := _lean_point(center, float(side) * radius * 0.10 * axis_scale_x, leaf_y + 7.0, body_height, lean)
		canvas.draw_polygon(PackedVector2Array([base, tip, inner]), PackedColorArray([_with_alpha(LEAF_DARK, 0.90 * alpha), _with_alpha(LEAF_MID, 0.96 * alpha), _with_alpha(LEAF_BRIGHT, 0.86 * alpha)]))
	for side in [-1, 1]:
		var base_left := _lean_point(center, float(side) * radius * 0.28 * axis_scale_x, leaf_y + 6.0, body_height, lean)
		var base_right := _lean_point(center, float(side) * radius * 0.50 * axis_scale_x, leaf_y + 6.0, body_height, lean)
		var tip := _lean_point(center, float(side) * radius * 0.70 * axis_scale_x + float(side) * 8.0 + sway * 0.7, leaf_y - 10.0, body_height, lean)
		canvas.draw_polygon(PackedVector2Array([base_left, base_right, tip]), PackedColorArray([_with_alpha(LEAF_DARK, 0.88 * alpha), _with_alpha(LEAF_MID, 0.98 * alpha), _with_alpha(LEAF_BRIGHT, 0.92 * alpha)]))
		canvas.draw_line((base_left + base_right) * 0.5, tip, _with_alpha(LEAF_BRIGHT, 0.60 * alpha), 1.2)


func _draw_horns(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	body_height: float,
	current_msec: float,
	lean: float,
	axis_scale_x: float,
	flipped: bool,
	alpha: float
) -> void:
	var horn_base_y: float = -body_height * 0.5 + 4.0
	for raw_side in [-1, 1]:
		var side: int = -raw_side if flipped else raw_side
		var hbx: float = float(raw_side) * radius * 0.45 * axis_scale_x
		var hby: float = horn_base_y + 2.0
		var sway: float = sin(current_msec * 0.005 + float(side) * 0.8) * 2.5
		var tip_x: float = hbx + float(raw_side) * (12.0 * axis_scale_x) + sway * float(raw_side)
		var tip_y: float = hby - 26.0
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for i in range(11):
			var t: float = float(i) / 10.0
			var p: Vector2 = _quadratic(Vector2(hbx, hby), Vector2(hbx + float(raw_side) * 3.0 * axis_scale_x, hby - 14.0), Vector2(tip_x, tip_y), t)
			var p_next: Vector2 = _quadratic(Vector2(hbx, hby), Vector2(hbx + float(raw_side) * 3.0 * axis_scale_x, hby - 14.0), Vector2(tip_x, tip_y), min(1.0, t + 0.1))
			var direction: Vector2 = (p_next - p).normalized()
			var normal := Vector2(-direction.y, direction.x)
			var thickness: float = 5.5 * (1.0 - t * 0.82)
			left.append(_lean_point(center, p.x + normal.x * thickness, p.y + normal.y * thickness, body_height, lean))
			right.append(_lean_point(center, p.x - normal.x * thickness, p.y - normal.y * thickness, body_height, lean))
		var horn_points := PackedVector2Array()
		for p in left:
			horn_points.append(p)
		for i in range(right.size() - 1, -1, -1):
			horn_points.append(right[i])
		var shadow_points := PackedVector2Array()
		for p in horn_points:
			shadow_points.append(p + Vector2(1.0, 1.0))
		canvas.draw_polygon(shadow_points, PackedColorArray([Color(0.03, 0.14, 0.02, 0.52 * alpha)]))
		canvas.draw_polygon(horn_points, PackedColorArray([_with_alpha(LEAF_MID, 0.98 * alpha)]))
		_draw_polyline_closed(canvas, horn_points, _with_alpha(LEAF_DARK, 0.88 * alpha), 1.8)
		var tip := _lean_point(center, tip_x, tip_y, body_height, lean)
		canvas.draw_circle(tip, 4.0, _with_alpha(LEAF_BRIGHT, 0.96 * alpha))
		canvas.draw_circle(tip + Vector2(-1.0, -1.0), 1.7, Color(0.78, 1.0, 0.64, 0.90 * alpha))


func _lean_point(center: Vector2, local_x: float, local_y: float, body_height: float, lean: float) -> Vector2:
	var lean_x: float = (local_y / max(1.0, body_height)) * lean
	return center + Vector2(local_x + lean_x, local_y)


func _quadratic(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var inv := 1.0 - t
	return a * inv * inv + b * 2.0 * inv * t + c * t * t


func _draw_ellipse(canvas: CanvasItem, center: Vector2, radius: Vector2, color: Color, segments: int) -> void:
	if radius.x <= 0.0 or radius.y <= 0.0 or color.a <= 0.001:
		return
	var points := PackedVector2Array()
	for i in range(max(8, segments)):
		var angle: float = TAU * float(i) / float(max(8, segments))
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	canvas.draw_polygon(points, PackedColorArray([color]))


func _draw_polyline_closed(canvas: CanvasItem, points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() < 2 or color.a <= 0.001:
		return
	for i in range(points.size()):
		canvas.draw_line(points[i], points[(i + 1) % points.size()], color, width)


func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clamp(alpha, 0.0, 1.0))
