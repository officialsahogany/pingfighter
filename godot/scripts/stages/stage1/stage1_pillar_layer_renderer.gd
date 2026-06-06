extends RefCounted

const Stage1PillarLayerGeometry := preload("res://scripts/stages/stage1/stage1_pillar_layer_geometry.gd")
const Stage1PillarChromeRenderer := preload("res://scripts/stages/stage1/stage1_pillar_chrome_renderer.gd")
const Stage1PillarCloudRenderer := preload("res://scripts/stages/stage1/stage1_pillar_cloud_renderer.gd")
const Stage1PillarTreeRenderer := preload("res://scripts/stages/stage1/stage1_pillar_tree_renderer.gd")
const Stage1PillarPetalRenderer := preload("res://scripts/stages/stage1/stage1_pillar_petal_renderer.gd")
const Stage1PillarButterflyRenderer := preload("res://scripts/stages/stage1/stage1_pillar_butterfly_renderer.gd")

var geometry: Object = Stage1PillarLayerGeometry.new()
var chrome_renderer: Object = Stage1PillarChromeRenderer.new()
var cloud_renderer: Object = Stage1PillarCloudRenderer.new()
var tree_renderer: Object = Stage1PillarTreeRenderer.new()
var petal_renderer: Object = Stage1PillarPetalRenderer.new()
var butterfly_renderer: Object = Stage1PillarButterflyRenderer.new()


func get_tree_rect(side: String, view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> Rect2:
	return geometry.get_tree_rect(side, view_size, game_offset, game_size)


func get_side_rect(side: String, view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> Rect2:
	return geometry.get_side_rect(side, view_size, game_offset, game_size)


func draw_hanji_subtle_borders(canvas: CanvasItem, view_size: Vector2, game_rect: Rect2, scale_factor: float) -> void:
	chrome_renderer.draw_hanji_subtle_borders(canvas, view_size, game_rect, scale_factor)


func draw_cloud_motion_layers(
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
	cloud_renderer.draw(canvas, cloud_sprite_texture, view_size, game_offset, game_size, scale_factor, time, quality_scale, motion_multiplier)


func draw_tree_motion_layers(
	canvas: CanvasItem,
	tree_sprite_texture: Texture2D,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	scale_factor: float,
	tree_shakes: Dictionary,
	crescendo_offset: Vector2 = Vector2.ZERO
) -> void:
	tree_renderer.draw(canvas, tree_sprite_texture, view_size, game_offset, game_size, scale_factor, tree_shakes, crescendo_offset)


func draw_tree_drop_petals(canvas: CanvasItem, tree_drop_petals: Array[Dictionary], quality_scale: float = 1.0) -> void:
	petal_renderer.draw_tree_drop_petals(canvas, tree_drop_petals, quality_scale)


func draw_floating_petals(canvas: CanvasItem, floating_petals: Array[Dictionary], quality_scale: float = 1.0) -> void:
	petal_renderer.draw_floating_petals(canvas, floating_petals, quality_scale)


func draw_butterflies(
	canvas: CanvasItem,
	butterfly_sheet_texture: Texture2D,
	butterflies: Array[Dictionary],
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	scale_factor: float,
	time: float,
	quality_scale: float = 1.0
) -> void:
	butterfly_renderer.draw(canvas, butterfly_sheet_texture, butterflies, view_size, game_offset, game_size, scale_factor, time, quality_scale)


func draw_game_border_shine(canvas: CanvasItem, game_rect: Rect2, scale_factor: float, time: float, quality_scale: float = 1.0, alpha_multiplier: float = 1.0) -> void:
	chrome_renderer.draw_game_border_shine(canvas, game_rect, scale_factor, time, quality_scale, alpha_multiplier)


func get_tree_shake_offset(side: String, scale_factor: float, tree_shakes: Dictionary) -> Vector2:
	return tree_renderer.get_tree_shake_offset(side, scale_factor, tree_shakes)


func clip_rect(rect: Rect2, view_size: Vector2) -> Rect2:
	return geometry.clip_rect(rect, view_size)


func get_sheet_region(texture: Texture2D, cols: int, rows: int, index: int) -> Rect2:
	return geometry.get_sheet_region(texture, cols, rows, index)


func fit_region_rect(source_region: Rect2, bounds: Rect2, center_ratio: Vector2) -> Rect2:
	return geometry.fit_region_rect(source_region, bounds, center_ratio)


func draw_texture_region(canvas: CanvasItem, texture: Texture2D, dest: Rect2, source_region: Rect2, alpha: float = 1.0, flip_h: bool = false) -> void:
	geometry.draw_texture_region(canvas, texture, dest, source_region, alpha, flip_h)


func build_ellipse_points(rect: Rect2, segments: int = 24) -> PackedVector2Array:
	return geometry.build_ellipse_points(rect, segments)
