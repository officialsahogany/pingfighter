extends RefCounted

const BLACK := Color(25.0 / 255.0, 25.0 / 255.0, 30.0 / 255.0)
const DARK := Color(35.0 / 255.0, 35.0 / 255.0, 40.0 / 255.0)
const DARKER := Color(18.0 / 255.0, 18.0 / 255.0, 22.0 / 255.0)
const BELT := Color(120.0 / 255.0, 90.0 / 255.0, 20.0 / 255.0)
const SHOE := Color(40.0 / 255.0, 40.0 / 255.0, 45.0 / 255.0)
const FLAME_YELLOW := Color(1.0, 220.0 / 255.0, 80.0 / 255.0)
const FLAME_ORANGE := Color(1.0, 140.0 / 255.0, 0.0)

var _previous_center_x := 0.0
var _walk_timer := 0.0
var _move_dir := 0


func draw(
	canvas: CanvasItem,
	player_pos: Vector2,
	paddle_size: Vector2,
	shake_offset: Vector2 = Vector2.ZERO,
	alpha: float = 1.0,
	context: Dictionary = {}
) -> Rect2:
	if canvas == null:
		return Rect2(player_pos, paddle_size)
	var rect := Rect2(player_pos + shake_offset, paddle_size)
	var cx: float = rect.position.x + rect.size.x * 0.5
	var foot_y: float = rect.position.y + rect.size.y
	_update_walk(cx)
	var bob: float = abs(sin(_walk_timer * 0.18)) * 2.0 if _move_dir != 0 else 0.0
	var body_scale: float = clampf(rect.size.x / 155.0, 0.72, 1.32)
	_draw_shadow(canvas, Vector2(cx, foot_y), body_scale, alpha)
	_draw_legs(canvas, Vector2(cx, foot_y - 18.0 + bob), body_scale, alpha)
	_draw_body(canvas, Vector2(cx, foot_y - 42.0 + bob), body_scale, alpha)
	_draw_arms(canvas, Vector2(cx, foot_y - 42.0 + bob), body_scale, alpha)
	_draw_head(canvas, Vector2(cx, foot_y - 58.0 + bob), body_scale, alpha, bool(context.get("helmet_removed", false)))
	return Rect2(Vector2(cx - 38.0 * body_scale, foot_y - 76.0 * body_scale), Vector2(76.0, 78.0) * body_scale)


func _update_walk(cx: float) -> void:
	var dx: float = cx - _previous_center_x
	_previous_center_x = cx
	if dx < -0.8:
		_move_dir = -1
		_walk_timer += 1.0
	elif dx > 0.8:
		_move_dir = 1
		_walk_timer += 1.0
	else:
		_move_dir = 0
		_walk_timer = max(0.0, _walk_timer - 1.0)


func _draw_shadow(canvas: CanvasItem, foot: Vector2, scale: float, alpha: float) -> void:
	_draw_ellipse(canvas, foot, Vector2(20.0, 4.0) * scale, _with_alpha(DARKER, 0.50 * alpha), 24)


func _draw_legs(canvas: CanvasItem, hip: Vector2, scale: float, alpha: float) -> void:
	var swing: float = sin(_walk_timer * 0.18)
	for side in [-1, 1]:
		var offset: float = swing * 6.0 * float(side) * -1.0 if _move_dir != 0 else 0.0
		var top: Vector2 = hip + Vector2(float(side) * 7.0, 0.0) * scale
		var bottom: Vector2 = top + Vector2(offset, 14.0) * scale
		canvas.draw_line(top, bottom, _with_alpha(BLACK, alpha), 5.0 * scale)
		_draw_ellipse(canvas, bottom + Vector2(0.0, 1.5) * scale, Vector2(5.0, 2.5) * scale, _with_alpha(SHOE, alpha), 16)


func _draw_body(canvas: CanvasItem, center: Vector2, scale: float, alpha: float) -> void:
	var rect := Rect2(center + Vector2(-11.0, -2.0) * scale, Vector2(22.0, 18.0) * scale)
	canvas.draw_rect(rect, _with_alpha(BLACK, alpha))
	canvas.draw_line(
		Vector2(center.x, rect.position.y + 3.0 * scale),
		Vector2(center.x, rect.position.y + 14.0 * scale),
		_with_alpha(DARKER, alpha),
		2.0 * scale
	)
	canvas.draw_line(
		Vector2(rect.position.x + 3.0 * scale, rect.position.y + 13.0 * scale),
		Vector2(rect.position.x + rect.size.x - 3.0 * scale, rect.position.y + 13.0 * scale),
		_with_alpha(BELT, alpha),
		2.0 * scale
	)


func _draw_arms(canvas: CanvasItem, center: Vector2, scale: float, alpha: float) -> void:
	var swing: float = sin(_walk_timer * 0.18)
	for side in [-1, 1]:
		var shoulder: Vector2 = center + Vector2(float(side) * 12.0, 4.0) * scale
		var hand: Vector2 = shoulder + Vector2(float(side) * 12.0 + swing * float(side) * 4.0, 12.0) * scale
		canvas.draw_line(shoulder, hand, _with_alpha(BLACK, alpha), 5.0 * scale)
		canvas.draw_circle(hand, 3.0 * scale, _with_alpha(DARK, alpha))


func _draw_head(canvas: CanvasItem, center: Vector2, scale: float, alpha: float, helmet_is_removed: bool = false) -> void:
	var radius: float = 14.0 * scale
	if helmet_is_removed:
		var exposed_radius: float = 10.0 * scale
		canvas.draw_circle(center + Vector2(0.0, 2.0) * scale, exposed_radius, _with_alpha(Color(70.0 / 255.0, 58.0 / 255.0, 50.0 / 255.0), alpha))
		canvas.draw_circle(center + Vector2(-3.0, -1.0) * scale, 1.2 * scale, _with_alpha(Color.BLACK, alpha))
		canvas.draw_circle(center + Vector2(3.0, -1.0) * scale, 1.2 * scale, _with_alpha(Color.BLACK, alpha))
		canvas.draw_line(center + Vector2(-3.0, 4.0) * scale, center + Vector2(3.0, 4.0) * scale, _with_alpha(DARKER, 0.82 * alpha), max(1.0, scale))
		return
	canvas.draw_circle(center, radius, _with_alpha(BLACK, alpha))
	canvas.draw_circle(center + Vector2(-2.5, -3.0) * scale, radius * 0.68, _with_alpha(DARK, 0.78 * alpha))
	canvas.draw_circle(center, radius, _with_alpha(DARKER, alpha), false, max(1.0, scale))
	var fuse_base: Vector2 = center + Vector2(0.0, -radius + 2.0 * scale)
	var fuse_tip: Vector2 = center + Vector2(3.0, -radius - 10.0 + sin(_walk_timer * 0.2) * 2.0) * scale
	canvas.draw_line(fuse_base, fuse_tip, _with_alpha(Color(90.0 / 255.0, 80.0 / 255.0, 70.0 / 255.0), alpha), 2.0 * scale)
	canvas.draw_circle(fuse_tip + Vector2(0.0, -2.0) * scale, 4.0 * scale, _with_alpha(FLAME_YELLOW, alpha))
	canvas.draw_circle(fuse_tip + Vector2(0.0, -3.0) * scale, 2.3 * scale, _with_alpha(FLAME_ORANGE, alpha))


func _draw_ellipse(canvas: CanvasItem, center: Vector2, radius: Vector2, color: Color, segments: int = 20) -> void:
	if radius.x <= 0.0 or radius.y <= 0.0 or color.a <= 0.001:
		return
	var points := PackedVector2Array()
	var count: int = max(8, segments)
	for i in range(count):
		var angle: float = TAU * float(i) / float(count)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	canvas.draw_polygon(points, PackedColorArray([color]))


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))
