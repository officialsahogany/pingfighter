extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const CAMPFIRE_TEXTURE_PATH := "res://assets/sprites/items/campfire_deploy_imagegen_v1.png"
const CAMPFIRE_DRAW_SIZE := Vector2(64.0, 64.0)
# The prepared 128px texture has 8 transparent rows below its visible logs.
# Offset by the same normalized inset so the visible pixels, not the PNG box,
# end exactly on the collision/playfield floor.
const CAMPFIRE_TEXTURE_BOTTOM_INSET_RATIO := 8.0 / 128.0
const MAX_PARTICLE_DRAW_COUNT := 28

var campfire_texture: Texture2D


func prewarm_assets() -> void:
	_get_campfire_texture()


func get_campfire_texture() -> Texture2D:
	return _get_campfire_texture()


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null or context.is_empty():
		return
	var campfires: Array = context.get("campfires", [])
	for campfire_value in campfires:
		if not (campfire_value is Dictionary):
			continue
		_draw_campfire(canvas, campfire_value as Dictionary, shake_offset)
	_draw_particles(canvas, context.get("particles", []), shake_offset)


func _draw_campfire(
	canvas: CanvasItem,
	campfire: Dictionary,
	shake_offset: Vector2
) -> void:
	var rect: Rect2 = _get_rect2(campfire, "rect")
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var center: Vector2 = rect.get_center() + shake_offset
	var phase: float = float(campfire.get("phase", 0.0))
	# The 80px recovery radius is gameplay-only. Do not draw a circular fill,
	# outline, or ground halo around the campfire.

	var texture: Texture2D = _get_campfire_texture()
	if texture == null:
		_draw_fallback(canvas, center, phase)
		return
	var spawn_ratio: float = 1.0 - clampf(float(campfire.get("spawn_timer_frames", 0.0)) / 18.0, 0.0, 1.0)
	var eased_spawn: float = 1.0 - pow(1.0 - spawn_ratio, 3.0)
	var flicker_scale: float = 1.0 + sin(phase * 1.7) * 0.025
	var draw_size: Vector2 = CAMPFIRE_DRAW_SIZE * eased_spawn
	draw_size.x *= flicker_scale
	var draw_rect: Rect2 = compute_campfire_draw_rect(rect, draw_size, shake_offset)
	canvas.draw_texture_rect(texture, draw_rect, false, Color.WHITE)


static func compute_campfire_draw_rect(
	campfire_rect: Rect2,
	draw_size: Vector2 = CAMPFIRE_DRAW_SIZE,
	shake_offset: Vector2 = Vector2.ZERO
) -> Rect2:
	var center_x: float = campfire_rect.get_center().x + shake_offset.x
	var texture_bottom: float = (
		campfire_rect.end.y
		+ shake_offset.y
		+ draw_size.y * CAMPFIRE_TEXTURE_BOTTOM_INSET_RATIO
	)
	return Rect2(Vector2(center_x - draw_size.x * 0.5, texture_bottom - draw_size.y), draw_size)


func _draw_particles(canvas: CanvasItem, particles_value: Variant, shake_offset: Vector2) -> void:
	if not (particles_value is Array):
		return
	var particles: Array = particles_value
	var start_index: int = maxi(0, particles.size() - MAX_PARTICLE_DRAW_COUNT)
	for index in range(start_index, particles.size()):
		var particle_value: Variant = particles[index]
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var life: float = maxf(0.0, float(particle.get("life", 0.0)))
		var initial_life: float = maxf(0.001, float(particle.get("initial_life", life)))
		var alpha: float = clampf(life / initial_life, 0.0, 1.0)
		var color: Color = _get_color(particle, "color", Color(1.0, 0.5, 0.08, 1.0))
		color.a *= alpha
		canvas.draw_circle(
			_get_vector2(particle, "position") + shake_offset,
			maxf(0.8, float(particle.get("size", 1.5)) * (0.65 + alpha * 0.35)),
			color
		)


func _draw_fallback(canvas: CanvasItem, center: Vector2, phase: float) -> void:
	var flame_height: float = 19.0 + sin(phase * 1.8) * 2.0
	canvas.draw_polygon(
		PackedVector2Array([
			center + Vector2(-10.0, 15.0),
			center + Vector2(0.0, -flame_height),
			center + Vector2(10.0, 15.0),
		]),
		PackedColorArray([Color(1.0, 0.24, 0.03), Color(1.0, 0.72, 0.08), Color(1.0, 0.24, 0.03)])
	)
	canvas.draw_line(center + Vector2(-17.0, 19.0), center + Vector2(17.0, 27.0), Color(0.24, 0.10, 0.04), 7.0)
	canvas.draw_line(center + Vector2(17.0, 19.0), center + Vector2(-17.0, 27.0), Color(0.24, 0.10, 0.04), 7.0)


func _get_campfire_texture() -> Texture2D:
	if campfire_texture == null and ResourceLoader.exists(CAMPFIRE_TEXTURE_PATH):
		campfire_texture = ProjectResourceLoader.load_texture(CAMPFIRE_TEXTURE_PATH)
	return campfire_texture


func _get_rect2(source: Dictionary, key: String) -> Rect2:
	var value: Variant = source.get(key, Rect2())
	return value if value is Rect2 else Rect2()


func _get_vector2(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	return value if value is Vector2 else Vector2.ZERO


func _get_color(source: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = source.get(key, fallback)
	return value if value is Color else fallback
