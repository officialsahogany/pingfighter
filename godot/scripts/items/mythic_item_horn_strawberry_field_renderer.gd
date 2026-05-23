extends RefCounted

const HornStrawberryTransformCinematicRenderer := preload("res://scripts/items/horn_strawberry_transform_cinematic_renderer.gd")

var _transform_renderer: Object = HornStrawberryTransformCinematicRenderer.new()


func is_transform_visible(transform_context: Dictionary) -> bool:
	return _transform_renderer.is_visible(transform_context)


func draw_horn_strawberry_effects(
	canvas: CanvasItem,
	shake_offset: Vector2,
	transform_context: Dictionary,
	eat_context: Dictionary,
	field_context: Dictionary,
	horn_charge_context: Dictionary,
	bomb_context: Dictionary,
	render_limits: Dictionary
) -> void:
	_transform_renderer.draw(canvas, shake_offset, transform_context)
	_draw_bomb_paint(canvas, shake_offset, bomb_context, int(render_limits.get("paint", 16)))

	var barriers: Array = _as_array(field_context.get("barriers", []))
	var rendered_barriers := 0
	for barrier_value in barriers:
		if rendered_barriers >= int(render_limits.get("barriers", 3)):
			break
		var barrier: Dictionary = _as_dict(barrier_value)
		if barrier.is_empty():
			continue
		_draw_barrier(canvas, shake_offset, barrier)
		rendered_barriers += 1

	var projectiles: Array = _as_array(eat_context.get("projectiles", []))
	var rendered_projectiles := 0
	for projectile_value in projectiles:
		if rendered_projectiles >= int(render_limits.get("projectiles", 6)):
			break
		var projectile: Dictionary = _as_dict(projectile_value)
		if projectile.is_empty():
			continue
		_draw_stem(canvas, shake_offset, projectile)
		rendered_projectiles += 1

	_draw_charge(canvas, shake_offset, horn_charge_context, int(render_limits.get("trails", 8)))
	_draw_bombs(
		canvas,
		shake_offset,
		bomb_context,
		int(render_limits.get("bombs", 18)),
		int(render_limits.get("explosions", 8))
	)


func _draw_barrier(canvas: CanvasItem, shake_offset: Vector2, barrier: Dictionary) -> void:
	var rect := Rect2(
		Vector2(float(barrier.get("rect_x", 0.0)), float(barrier.get("rect_y", 0.0))) + shake_offset,
		Vector2(max(1.0, float(barrier.get("width", 180.0))), max(1.0, float(barrier.get("height", 12.0))))
	)
	var built: bool = bool(barrier.get("built", false))
	var dying: bool = bool(barrier.get("dying", false))
	var death_ratio: float = clamp(float(barrier.get("death_timer_sec", 0.0)) / 0.6, 0.0, 1.0) if dying else 0.0
	var alpha: float = (0.35 + 0.55 * clamp(float(barrier.get("build_timer_sec", 0.0)) / 0.5, 0.0, 1.0)) if not built else 0.9
	alpha *= 1.0 - death_ratio
	if alpha <= 0.02:
		return
	var body_color := Color(0.95, 0.16, 0.24, alpha)
	var edge_color := Color(0.35, 0.88, 0.30, min(1.0, alpha + 0.1))
	var shine_color := Color(1.0, 0.74, 0.74, alpha * 0.55)
	canvas.draw_rect(rect.grow(2.0), Color(0.12, 0.45, 0.16, alpha * 0.28), false, 2.0)
	canvas.draw_rect(rect, body_color, true)
	canvas.draw_rect(rect, edge_color, false, 2.0)
	canvas.draw_line(rect.position + Vector2(6.0, 3.0), rect.position + Vector2(rect.size.x - 6.0, 3.0), shine_color, 2.0)
	var seed_count: int = clamp(int(rect.size.x / 18.0), 4, 10)
	for i in range(seed_count):
		var t: float = float(i + 1) / float(seed_count + 1)
		var seed_pos := rect.position + Vector2(rect.size.x * t, rect.size.y * (0.45 + 0.22 * sin(float(i) * 1.7)))
		canvas.draw_circle(seed_pos, 1.6, Color(1.0, 0.86, 0.38, alpha * 0.88))


func _draw_stem(canvas: CanvasItem, shake_offset: Vector2, projectile: Dictionary) -> void:
	var center: Vector2 = _as_vector2(projectile.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var size: float = max(8.0, float(projectile.get("size", 20.0)))
	var rotation: float = float(projectile.get("rotation", 0.0))
	var dir := Vector2(sin(rotation), -cos(rotation))
	var side := Vector2(-dir.y, dir.x)
	var tip := center + dir * size * 0.48
	var tail := center - dir * size * 0.42
	var leaf_left := tail + side * size * 0.28
	var leaf_right := tail - side * size * 0.28
	canvas.draw_circle(center, size * 0.38, Color(0.14, 0.62, 0.22, 0.28))
	canvas.draw_polygon(
		PackedVector2Array([tip, leaf_left, center + side * size * 0.12, leaf_right]),
		PackedColorArray([
			Color(0.35, 0.92, 0.30, 0.95),
			Color(0.06, 0.42, 0.13, 0.9),
			Color(0.16, 0.72, 0.20, 0.95),
			Color(0.08, 0.46, 0.14, 0.9),
		])
	)
	canvas.draw_line(tail, tip, Color(0.88, 1.0, 0.62, 0.82), 2.0)


func _draw_charge(canvas: CanvasItem, shake_offset: Vector2, context: Dictionary, trail_render_limit: int) -> void:
	var trails: Array = _as_array(context.get("trails", []))
	var rendered_trails := 0
	for trail_value in trails:
		if rendered_trails >= trail_render_limit:
			break
		var trail: Dictionary = _as_dict(trail_value)
		var center: Vector2 = _as_vector2(trail.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var life_sec: float = max(0.001, float(trail.get("life_sec", 0.28)))
		var alpha: float = clamp(float(trail.get("timer_sec", 0.0)) / life_sec, 0.0, 1.0)
		canvas.draw_circle(center, 22.0 * alpha, Color(1.0, 0.22, 0.28, 0.20 * alpha))
		canvas.draw_circle(center + Vector2(0.0, -8.0), 9.0 * alpha, Color(0.32, 1.0, 0.26, 0.30 * alpha))
		rendered_trails += 1
	if bool(context.get("active", false)):
		var player_center: Vector2 = _as_vector2(context.get("player_center", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var target_center: Vector2 = _as_vector2(context.get("target_center", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var phase_name: String = str(context.get("phase", ""))
		var charge_color := Color(1.0, 0.12, 0.20, 0.72)
		if phase_name == "impact":
			charge_color = Color(1.0, 0.86, 0.30, 0.9)
		canvas.draw_line(player_center, target_center, Color(0.98, 0.25, 0.28, 0.24), 6.0)
		canvas.draw_circle(player_center, 16.0, charge_color)
		canvas.draw_circle(player_center + Vector2(0.0, -13.0), 6.0, Color(0.28, 0.95, 0.22, 0.9))
	var flash_timer: float = float(context.get("impact_flash_timer_sec", 0.0))
	if flash_timer > 0.0:
		var target_center: Vector2 = _as_vector2(context.get("target_center", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var ratio: float = clamp(flash_timer / 0.20, 0.0, 1.0)
		canvas.draw_circle(target_center, 46.0 * (1.0 - ratio * 0.35), Color(1.0, 0.25, 0.18, 0.26 * ratio))
		canvas.draw_arc(target_center, 58.0 * (1.0 - ratio * 0.20), 0.0, TAU, 36, Color(1.0, 0.92, 0.36, 0.75 * ratio), 3.0)


func _draw_bomb_paint(canvas: CanvasItem, shake_offset: Vector2, context: Dictionary, paint_render_limit: int) -> void:
	var splatters: Array = _as_array(context.get("paint_splatters", []))
	var rendered := 0
	for splatter_value in splatters:
		if rendered >= paint_render_limit:
			break
		var splatter: Dictionary = _as_dict(splatter_value)
		var center: Vector2 = _as_vector2(splatter.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var radius: float = max(2.0, float(splatter.get("radius", 28.0)))
		var duration: float = max(0.001, float(splatter.get("duration_sec", 5.0)))
		var alpha: float = clamp(float(splatter.get("timer_sec", 0.0)) / duration, 0.0, 1.0)
		canvas.draw_circle(center, radius, Color(0.95, 0.08, 0.16, 0.23 * alpha))
		canvas.draw_arc(center, radius * 0.78, 0.0, TAU, 18, Color(0.25, 0.95, 0.18, 0.24 * alpha), 2.0)
		var blob_count: int = clamp(int(splatter.get("blob_count", 5)), 3, 8)
		for i in range(blob_count):
			var angle: float = float(i) / float(blob_count) * TAU + float(i % 3) * 0.21
			var blob_center: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * (0.32 + 0.08 * float(i % 2))
			canvas.draw_circle(blob_center, radius * 0.16, Color(1.0, 0.18, 0.22, 0.26 * alpha))
		rendered += 1


func _draw_bombs(
	canvas: CanvasItem,
	shake_offset: Vector2,
	context: Dictionary,
	bomb_render_limit: int,
	explosion_render_limit: int
) -> void:
	var bombs: Array = _as_array(context.get("bombs", []))
	var rendered_bombs := 0
	for bomb_value in bombs:
		if rendered_bombs >= bomb_render_limit:
			break
		var bomb: Dictionary = _as_dict(bomb_value)
		var center: Vector2 = _as_vector2(bomb.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size: float = max(4.0, float(bomb.get("size", 12.0)))
		canvas.draw_circle(center, size * 0.72, Color(0.94, 0.10, 0.16, 0.96))
		canvas.draw_circle(center + Vector2(-size * 0.16, -size * 0.18), size * 0.22, Color(1.0, 0.72, 0.72, 0.68))
		canvas.draw_circle(center + Vector2(size * 0.18, -size * 0.50), size * 0.24, Color(0.18, 0.72, 0.18, 0.92))
		rendered_bombs += 1
	var explosions: Array = _as_array(context.get("explosions", []))
	var rendered_explosions := 0
	for explosion_value in explosions:
		if rendered_explosions >= explosion_render_limit:
			break
		var explosion: Dictionary = _as_dict(explosion_value)
		var center: Vector2 = _as_vector2(explosion.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var duration: float = max(0.001, float(explosion.get("duration_sec", 0.5)))
		var ratio: float = clamp(float(explosion.get("timer_sec", 0.0)) / duration, 0.0, 1.0)
		var radius: float = 12.0 + (1.0 - ratio) * 34.0
		canvas.draw_circle(center, radius, Color(1.0, 0.16, 0.20, 0.26 * ratio))
		canvas.draw_arc(center, radius * 1.15, 0.0, TAU, 28, Color(1.0, 0.86, 0.36, 0.76 * ratio), 3.0)
		rendered_explosions += 1


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
