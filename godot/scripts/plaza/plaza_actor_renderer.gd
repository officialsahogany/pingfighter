extends RefCounted

const PlazaActorVisualProjection := preload("res://scripts/plaza/plaza_actor_visual_projection.gd")
const PlazaWorldGeometry := preload("res://scripts/plaza/plaza_world_geometry.gd")


static func draw_player(
	canvas: CanvasItem,
	textures: Dictionary,
	world_position: Vector2,
	camera_x: float,
	scale: float,
	alpha: float,
	moving: bool,
	direction: int,
	frame: int
) -> void:
	if canvas == null:
		return
	if _draw_player_sheet(canvas, textures, world_position, camera_x, scale, alpha, moving, direction, frame):
		return
	_draw_player_placeholder(canvas, world_position, camera_x, scale, alpha)


static func draw_lingpet(
	canvas: CanvasItem,
	texture: Texture2D,
	draw_size: float,
	world_position: Vector2,
	camera_x: float,
	scale: float,
	alpha: float,
	ticks_msec: int
) -> void:
	if canvas == null or texture == null:
		return
	var safe_alpha := clampf(alpha, 0.0, 1.0)
	if safe_alpha <= 0.01:
		return
	var local := PlazaWorldGeometry.world_to_local(world_position, camera_x, scale)
	var draw_rect := PlazaActorVisualProjection.get_lingpet_draw_rect(local, draw_size, scale)
	_draw_ground_shadow(
		canvas,
		local + Vector2(0.0, 6.0) * scale,
		max(14.0, draw_size * 0.26) * scale,
		max(5.0, draw_size * 0.095) * scale,
		safe_alpha * 0.9
	)
	var frame := PlazaActorVisualProjection.get_lingpet_sprite_frame(ticks_msec)
	var src_rect := PlazaActorVisualProjection.get_sheet_frame_rect(
		texture.get_size(),
		frame,
		PlazaActorVisualProjection.LINGPET_COMPANION_GRID_COLS,
		PlazaActorVisualProjection.LINGPET_COMPANION_GRID_ROWS
	)
	canvas.draw_texture_rect_region(texture, draw_rect, src_rect, Color(1.0, 1.0, 1.0, safe_alpha))


static func get_player_texture_key(textures: Dictionary, moving: bool, direction: int) -> String:
	if moving:
		var walk_key := "walk_left" if direction < 0 else "walk_right"
		if textures.get(walk_key, null) != null:
			return walk_key
	if textures.get("idle", null) != null:
		return "idle"
	var fallback_key := "walk_left" if direction < 0 else "walk_right"
	return fallback_key if textures.get(fallback_key, null) != null else ""


static func _draw_player_sheet(
	canvas: CanvasItem,
	textures: Dictionary,
	world_position: Vector2,
	camera_x: float,
	scale: float,
	alpha: float,
	moving: bool,
	direction: int,
	frame: int
) -> bool:
	if not bool(textures.get("has_sprite", false)):
		return false
	var safe_alpha := clampf(alpha, 0.0, 1.0)
	if safe_alpha <= 0.01:
		return true
	var texture_key := get_player_texture_key(textures, moving, direction)
	var texture: Texture2D = textures.get(texture_key, null) if texture_key != "" else null
	if texture == null:
		return false
	var src_rect := PlazaActorVisualProjection.get_sheet_frame_rect(
		texture.get_size(),
		frame,
		int(textures.get("grid_cols", 4)),
		int(textures.get("grid_rows", 2))
	)
	var local := PlazaWorldGeometry.world_to_local(world_position, camera_x, scale)
	var draw_rect := PlazaActorVisualProjection.get_player_draw_rect(local, scale)
	_draw_ground_shadow(canvas, local + Vector2(0.0, 6.0) * scale, 24.0 * scale, 8.5 * scale, safe_alpha)
	canvas.draw_texture_rect_region(texture, draw_rect, src_rect, Color(1.0, 1.0, 1.0, safe_alpha))
	return true


static func _draw_player_placeholder(canvas: CanvasItem, world_position: Vector2, camera_x: float, scale: float, alpha: float) -> void:
	var safe_alpha := clampf(alpha, 0.0, 1.0)
	if safe_alpha <= 0.01:
		return
	var local := PlazaWorldGeometry.world_to_local(world_position, camera_x, scale)
	_draw_ground_shadow(canvas, local + Vector2(0.0, 6.0) * scale, 23.0 * scale, 8.0 * scale, safe_alpha)
	canvas.draw_rect(Rect2(local + Vector2(-15.0, -56.0) * scale, Vector2(30.0, 52.0) * scale), Color(0.30, 0.34, 0.38, 0.96 * safe_alpha), true)
	canvas.draw_rect(Rect2(local + Vector2(-17.0, -58.0) * scale, Vector2(34.0, 56.0) * scale), Color(0.74, 0.82, 0.88, 0.55 * safe_alpha), false, max(1.0, 2.0 * scale))
	canvas.draw_circle(local + Vector2(0.0, -74.0) * scale, 15.0 * scale, Color(0.68, 0.70, 0.72, safe_alpha))
	canvas.draw_line(local + Vector2(-9.0, -6.0) * scale, local + Vector2(-16.0, 12.0) * scale, Color(0.66, 0.74, 0.78, 0.9 * safe_alpha), max(1.0, 3.0 * scale))
	canvas.draw_line(local + Vector2(9.0, -6.0) * scale, local + Vector2(16.0, 12.0) * scale, Color(0.66, 0.74, 0.78, 0.9 * safe_alpha), max(1.0, 3.0 * scale))


# Soft flattened ground contact shadow drawn as concentric ellipses. This
# avoids draw_set_transform and keeps actor/companion shadows alpha-locked to
# their transition fade.
static func _draw_ground_shadow(canvas: CanvasItem, center: Vector2, radius_x: float, radius_y: float, intensity: float) -> void:
	if intensity <= 0.01 or radius_x <= 0.5 or radius_y <= 0.5:
		return
	for layer in [[1.0, 0.06], [0.66, 0.08], [0.36, 0.10]]:
		var layer_scale := float(layer[0])
		var layer_alpha := float(layer[1]) * intensity
		if layer_alpha <= 0.003:
			continue
		var points := PackedVector2Array()
		for index in range(24):
			var angle := TAU * float(index) / 24.0
			points.append(center + Vector2(cos(angle) * radius_x * layer_scale, sin(angle) * radius_y * layer_scale))
		canvas.draw_colored_polygon(points, Color(0.0, 0.0, 0.0, layer_alpha))
