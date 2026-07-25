extends RefCounted

const PlazaBackgroundProjection := preload("res://scripts/plaza/plaza_background_projection.gd")
const PlazaWorldGeometry := preload("res://scripts/plaza/plaza_world_geometry.gd")

const CULL_MARGIN := 80.0
const SHADOW_HEIGHT := 18.0


static func draw(
	canvas: CanvasItem,
	spec: Dictionary,
	camera_x: float,
	viewport_width: float,
	building_baseline_y: float,
	scale: float,
	ticks_msec: int
) -> void:
	if canvas == null:
		return
	var base_texture: Texture2D = spec.get("base_texture", null)
	if base_texture == null:
		return
	var world_rect := resolve_world_rect(spec)
	var local_rect := PlazaWorldGeometry.world_rect_to_local(world_rect, camera_x, scale)
	if local_rect.position.x > viewport_width + CULL_MARGIN or local_rect.end.x < -CULL_MARGIN:
		return
	var shadow_rect := Rect2(
		Vector2(local_rect.position.x + local_rect.size.x * 0.12, building_baseline_y * scale),
		Vector2(local_rect.size.x * 0.76, SHADOW_HEIGHT * scale)
	)
	canvas.draw_rect(shadow_rect, Color(0.0, 0.0, 0.0, 0.22), true)
	canvas.draw_texture_rect(base_texture, local_rect, false)
	var pulse := PlazaBackgroundProjection.discrete_flicker(get_flicker_seed(spec), ticks_msec)
	var sign_texture: Texture2D = spec.get("sign_texture", null)
	if sign_texture != null:
		canvas.draw_texture_rect(sign_texture, local_rect, false, Color(1.0, 1.0, 1.0, 0.72 + pulse * 0.22))
	var window_texture: Texture2D = spec.get("window_texture", null)
	if window_texture != null:
		canvas.draw_texture_rect(window_texture, local_rect, false, Color(1.0, 0.93, 0.78, 0.56 + pulse * 0.12))


static func resolve_world_rect(spec: Dictionary) -> Rect2:
	var world_rect: Rect2 = spec.get("visual_rect", Rect2())
	if world_rect.size != Vector2.ZERO:
		return world_rect
	var source_size: Vector2 = spec.get("source_size", Vector2.ONE)
	var origin_pivot: Vector2 = spec.get("origin_pivot", source_size * 0.5)
	var display_scale := float(spec.get("display_scale", 1.0))
	var pivot_pos: Vector2 = spec.get("pivot_pos", Vector2.ZERO)
	return Rect2(pivot_pos - origin_pivot * display_scale, source_size * display_scale)


static func get_flicker_seed(spec: Dictionary) -> String:
	var pivot_pos: Vector2 = spec.get("pivot_pos", Vector2.ZERO)
	return "%s:%d" % [str(spec.get("type", "")), int(round(pivot_pos.x))]
