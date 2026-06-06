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
	render_limits: Dictionary,
	draw_context: Dictionary = {}
) -> void:
	_transform_renderer.draw(canvas, shake_offset, transform_context, draw_context)
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
	var build_progress: float = clamp(float(barrier.get("build_timer_sec", 0.0)) / 0.5, 0.0, 1.0)
	var death_ratio: float = clamp(float(barrier.get("death_timer_sec", 0.0)) / 0.6, 0.0, 1.0) if dying else 0.0
	var alpha: float = (0.35 + 0.55 * build_progress) if not built else 0.9
	alpha *= 1.0 - death_ratio
	if alpha <= 0.02:
		return
	if dying:
		_draw_barrier_fragments(canvas, rect, barrier, death_ratio, alpha)
		return

	var now: float = float(Time.get_ticks_msec()) / 180.0
	var center_y: float = rect.position.y + rect.size.y * 0.5
	var berry_row_y: float = center_y - 18.0
	var vine_y: float = berry_row_y - 12.0
	var vine_start := Vector2(rect.position.x - 8.0, vine_y)
	var vine_end := Vector2(rect.position.x + rect.size.x + 8.0, vine_y)
	canvas.draw_rect(rect.grow(3.0), Color(0.76, 0.02, 0.06, alpha * 0.12), true)
	canvas.draw_rect(rect, Color(0.98, 0.10, 0.16, alpha * 0.20), true)
	canvas.draw_line(vine_start + Vector2(0.0, 3.0), vine_end + Vector2(0.0, 3.0), Color(0.02, 0.18, 0.04, alpha * 0.45), 6.0)
	canvas.draw_line(vine_start + Vector2(0.0, 1.0), vine_end + Vector2(0.0, 1.0), Color(0.12, 0.52, 0.10, alpha * 0.88), 4.0)
	canvas.draw_line(vine_start, vine_end, Color(0.50, 0.94, 0.36, alpha * 0.42), 1.0)
	var berry_count: int = max(4, int(rect.size.x / 26.0))
	var span: float = max(1.0, rect.size.x - 20.0)
	if built:
		var built_stem_lines := PackedVector2Array()
		built_stem_lines.resize(berry_count * 2)
		for idx in range(berry_count):
			var cx: float = rect.position.x + 10.0 + span * float(idx) / max(1.0, float(berry_count - 1))
			var bob: float = sin(now + float(idx) * 0.9) * 1.4
			var cy: float = berry_row_y + bob
			var berry_size: float = max(8.0, 17.0 + float(idx % 2) * 2.0)
			built_stem_lines[idx * 2] = Vector2(cx, vine_y + 2.0)
			built_stem_lines[idx * 2 + 1] = Vector2(cx, cy - berry_size * 0.55)
		canvas.draw_multiline(built_stem_lines, Color(0.08, 0.40, 0.06, alpha), 2.0)
	for idx in range(berry_count):
		var local_progress: float = 1.0 if built else clamp(build_progress * float(berry_count) - float(idx) + 0.35, 0.0, 1.0)
		if local_progress <= 0.0:
			continue
		var cx: float = rect.position.x + 10.0 + span * float(idx) / max(1.0, float(berry_count - 1))
		var bob: float = sin(now + float(idx) * 0.9) * 1.4
		var cy: float = berry_row_y + bob
		var berry_size: float = max(8.0, (17.0 + float(idx % 2) * 2.0) * local_progress)
		if not built:
			canvas.draw_line(
				Vector2(cx, vine_y + 2.0),
				Vector2(cx, cy - berry_size * 0.55),
				Color(0.08, 0.40, 0.06, alpha * local_progress),
				2.0
			)
		_draw_tiny_strawberry(canvas, Vector2(cx, cy), berry_size, alpha * local_progress, (-10.0 if idx % 2 == 0 else 10.0) * local_progress)
	if built:
		for idx in range(max(0, berry_count - 1)):
			var bridge_x: float = rect.position.x + 10.0 + span * (float(idx) + 0.5) / max(1.0, float(berry_count - 1))
			var bridge_y: float = berry_row_y + sin(now + float(idx) * 0.9 + 0.45) * 1.2
			_draw_tiny_strawberry(
				canvas,
				Vector2(bridge_x, bridge_y + (5.0 if idx % 2 == 0 else -3.0)),
				11.0,
				alpha * 0.84,
				18.0 if idx % 2 == 0 else -18.0
			)


func _draw_barrier_fragments(canvas: CanvasItem, rect: Rect2, barrier: Dictionary, death_ratio: float, alpha: float) -> void:
	var seeds: Array = _as_array(barrier.get("seeds", []))
	var count: int = max(8, seeds.size())
	for idx in range(count):
		var seed_point: Vector2 = _as_vector2(seeds[idx], Vector2(rect.size.x * 0.5, rect.size.y * 0.5)) if idx < seeds.size() else Vector2(rect.size.x * (float(idx + 1) / float(count + 1)), rect.size.y * 0.5)
		var scatter := Vector2(
			sin(float(idx) * 1.91) * 30.0 * death_ratio,
			(20.0 + abs(cos(float(idx) * 1.37)) * 16.0) * death_ratio
		)
		var pos: Vector2 = rect.position + seed_point + scatter
		if idx % 3 == 0:
			_draw_tiny_strawberry(canvas, pos, max(5.0, 10.0 * (1.0 - death_ratio * 0.35)), alpha * 0.78, float(idx % 5) * 12.0)
		else:
			canvas.draw_circle(pos, 1.8, Color(0.98, 0.84, 0.30, alpha * 0.75))


func _draw_tiny_strawberry(canvas: CanvasItem, center: Vector2, size: float, alpha: float, tilt_degrees: float = 0.0) -> void:
	var clamped_alpha: float = clamp(alpha, 0.0, 1.0)
	if clamped_alpha <= 0.01:
		return
	var radius_x: float = max(3.0, size * 0.44)
	var radius_y: float = max(4.0, size * 0.56)
	var tilt: float = deg_to_rad(tilt_degrees)
	var tilt_cos: float = cos(tilt)
	var tilt_sin: float = sin(tilt)
	var body := PackedVector2Array()
	for i in range(18):
		var angle: float = TAU * float(i) / 18.0 - PI * 0.5
		var local := Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
		if local.y > 0.0:
			local.x *= 1.0 - local.y / max(1.0, radius_y) * 0.22
		var rotated := Vector2(
			local.x * tilt_cos - local.y * tilt_sin,
			local.x * tilt_sin + local.y * tilt_cos
		)
		body.append(center + rotated)
	canvas.draw_colored_polygon(body, Color(0.92, 0.07, 0.12, 0.95 * clamped_alpha))
	canvas.draw_polyline(body, Color(0.42, 0.01, 0.04, 0.75 * clamped_alpha), 1.0, true)
	canvas.draw_circle(center + Vector2(-radius_x * 0.24, -radius_y * 0.22), size * 0.12, Color(1.0, 0.58, 0.60, 0.45 * clamped_alpha))
	var leaf_lines := PackedVector2Array()
	leaf_lines.resize(6)
	var base: Vector2 = center + Vector2(0.0, -radius_y * 0.75)
	for leaf_idx in range(3):
		var leaf_angle: float = -PI * 0.55 + float(leaf_idx) * PI * 0.18 + tilt
		var tip: Vector2 = base + Vector2(cos(leaf_angle), sin(leaf_angle)) * size * 0.35
		leaf_lines[leaf_idx * 2] = base
		leaf_lines[leaf_idx * 2 + 1] = tip
	canvas.draw_multiline(leaf_lines, Color(0.16, 0.66, 0.12, 0.88 * clamped_alpha), 2.0)
	for seed_idx in range(3):
		var seed_pos := center + Vector2(
			(-0.24 + float(seed_idx) * 0.24) * radius_x,
			(-0.04 + float(seed_idx % 2) * 0.26) * radius_y
		)
		canvas.draw_circle(seed_pos, max(0.8, size * 0.045), Color(0.98, 0.84, 0.30, 0.80 * clamped_alpha))


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
		var scatter: float = 7.0 + float(rendered_trails % 4) * 1.5
		_draw_tiny_strawberry(canvas, center + Vector2(-scatter, sin(float(rendered_trails) * 0.7) * 2.0), 15.0 * alpha, 0.72 * alpha, -20.0)
		_draw_tiny_strawberry(canvas, center + Vector2(scatter * 0.8, -sin(float(rendered_trails) * 0.7) * 1.4), 12.0 * alpha, 0.58 * alpha, 16.0)
		canvas.draw_circle(center, 18.0 * alpha, Color(1.0, 0.22, 0.28, 0.10 * alpha))
		rendered_trails += 1
	if bool(context.get("active", false)):
		var player_center: Vector2 = _as_vector2(context.get("player_center", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var target_center: Vector2 = _as_vector2(context.get("target_center", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var current_offset: Vector2 = _as_vector2(context.get("current_offset", Vector2.ZERO), Vector2.ZERO)
		var origin_center: Vector2 = player_center - current_offset
		var phase_name: String = str(context.get("phase", ""))
		var charge_color := Color(1.0, 0.12, 0.20, 0.72)
		if phase_name == "impact":
			charge_color = Color(1.0, 0.86, 0.30, 0.9)
		var dash_dir: Vector2 = (target_center - origin_center).normalized()
		var side := Vector2(-dash_dir.y, dash_dir.x)
		for lane in [-1, 0, 1]:
			var lane_offset: Vector2 = side * float(lane) * 9.0
			canvas.draw_line(origin_center + lane_offset, player_center + lane_offset, Color(0.98, 0.20, 0.26, 0.13 + 0.06 * float(1 - abs(lane))), 5.0 - float(abs(lane)))
		canvas.draw_circle(player_center, 18.0, charge_color)
		canvas.draw_circle(player_center + Vector2(0.0, -13.0), 6.0, Color(0.28, 0.95, 0.22, 0.9))
		_draw_tiny_strawberry(canvas, player_center + side * 18.0, 14.0, 0.62, 22.0)
		_draw_tiny_strawberry(canvas, player_center - side * 15.0, 11.0, 0.48, -18.0)
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
