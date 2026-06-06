extends RefCounted

const Stage1PillarLayerGeometry := preload("res://scripts/stages/stage1/stage1_pillar_layer_geometry.gd")

const CLOUD_LOD_THRESHOLD := 0.85
const CLOUD_PRIMARY_LAYER_COUNT := 2
const CLOUD_TOTAL_LAYER_COUNT := 4

var geometry: Object = Stage1PillarLayerGeometry.new()


func draw(
	canvas: CanvasItem,
	cloud_sprite_texture: Texture2D,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	scale_factor: float,
	time: float,
	quality_scale: float = 1.0,
	motion_multiplier: float = 1.0
) -> void:
	if cloud_sprite_texture == null:
		return
	var h: float = view_size.y
	var left_w: float = max(0.0, game_offset.x)
	var right_x: float = game_offset.x + game_size.x
	var right_w: float = max(0.0, view_size.x - right_x)
	var lod_active: bool = quality_scale < CLOUD_LOD_THRESHOLD
	var motion_scale: float = max(0.0, motion_multiplier)
	_draw_cloud_spec(canvas, cloud_sprite_texture, view_size, scale_factor, time, Rect2(0.0, h * 0.08, max(1.0, left_w), h * 0.22), 0, 0.24, 32.0 * motion_scale, 6.0 * motion_scale, 0.0, false, Vector2(0.50, 0.46), 212.0 / 255.0)
	_draw_cloud_spec(canvas, cloud_sprite_texture, view_size, scale_factor, time, Rect2(right_x, h * 0.09, max(1.0, right_w), h * 0.22), 1, 0.22, -34.0 * motion_scale, 6.0 * motion_scale, 2.4, true, Vector2(0.50, 0.47), 212.0 / 255.0)
	if lod_active:
		return
	_draw_cloud_spec(canvas, cloud_sprite_texture, view_size, scale_factor, time, Rect2(0.0, h * 0.55, max(1.0, left_w), h * 0.25), 3, 0.19, 38.0 * motion_scale, 7.0 * motion_scale, 1.7, false, Vector2(0.47, 0.48), 196.0 / 255.0)
	_draw_cloud_spec(canvas, cloud_sprite_texture, view_size, scale_factor, time, Rect2(right_x, h * 0.57, max(1.0, right_w), h * 0.25), 4, 0.18, -40.0 * motion_scale, 7.0 * motion_scale, 3.6, true, Vector2(0.53, 0.49), 196.0 / 255.0)


func _draw_cloud_spec(
	canvas: CanvasItem,
	texture: Texture2D,
	view_size: Vector2,
	scale_factor: float,
	time: float,
	spec_rect: Rect2,
	sprite_index: int,
	speed: float,
	amp_x: float,
	amp_y: float,
	phase: float,
	flip_h: bool,
	spec_center: Vector2,
	alpha: float
) -> void:
	var bounds: Rect2 = geometry.clip_rect(spec_rect, view_size)
	if bounds.size.x <= 2.0 or bounds.size.y <= 2.0:
		return
	var source_region: Rect2 = geometry.get_sheet_region(texture, 3, 2, sprite_index)
	var layer_bounds := Rect2(bounds.position, bounds.size * Vector2(0.88, 0.86))
	layer_bounds.position += bounds.size * Vector2(0.06, 0.07)
	var dest: Rect2 = geometry.fit_region_rect(source_region, layer_bounds, spec_center)
	var phase_t: float = time * speed + phase
	var offset := Vector2(
		round(sin(phase_t) * amp_x * scale_factor),
		round(cos(phase_t * 0.73) * amp_y * scale_factor)
	)
	dest.position += offset
	geometry.draw_texture_region(canvas, texture, dest, source_region, alpha, flip_h)
