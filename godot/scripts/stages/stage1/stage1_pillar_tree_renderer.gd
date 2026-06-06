extends RefCounted

const Stage1PillarLayerGeometry := preload("res://scripts/stages/stage1/stage1_pillar_layer_geometry.gd")

const TREE_SHAKE_DURATION := 0.28
const TREE_SHAKE_BASE_PIXELS := 3.0
const TREE_SHAKE_FREQUENCY := 34.0
const LEFT_TREE_REGION := Rect2(20.0, 25.0, 580.0, 925.0)
const RIGHT_TREE_REGION := Rect2(1048.0, 25.0, 576.0, 925.0)

var geometry: Object = Stage1PillarLayerGeometry.new()


func draw(
	canvas: CanvasItem,
	tree_sprite_texture: Texture2D,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	scale_factor: float,
	tree_shakes: Dictionary,
	crescendo_offset: Vector2 = Vector2.ZERO
) -> void:
	if tree_sprite_texture == null:
		return
	_draw_tree_side(canvas, tree_sprite_texture, view_size, game_offset, game_size, scale_factor, tree_shakes, "left", LEFT_TREE_REGION, crescendo_offset)
	_draw_tree_side(canvas, tree_sprite_texture, view_size, game_offset, game_size, scale_factor, tree_shakes, "right", RIGHT_TREE_REGION, crescendo_offset)


func _draw_tree_side(
	canvas: CanvasItem,
	tree_sprite_texture: Texture2D,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	scale_factor: float,
	tree_shakes: Dictionary,
	side: String,
	source_region: Rect2,
	crescendo_offset: Vector2 = Vector2.ZERO
) -> void:
	var bounds: Rect2 = geometry.clip_rect(geometry.get_tree_rect(side, view_size, game_offset, game_size), view_size)
	if bounds.size.x <= 2.0 or bounds.size.y <= 2.0:
		return
	var fit: Rect2 = geometry.fit_region_rect(source_region, bounds, Vector2(0.5, 0.5))
	if side == "left":
		fit.position.x = bounds.position.x
	else:
		fit.position.x = bounds.end.x - fit.size.x
	fit.position.y = bounds.end.y - fit.size.y
	fit.position += get_tree_shake_offset(side, scale_factor, tree_shakes)
	var side_dir: float = -1.0 if side == "left" else 1.0
	fit.position += Vector2(crescendo_offset.x * side_dir, crescendo_offset.y)
	geometry.draw_texture_region(canvas, tree_sprite_texture, fit, source_region, 248.0 / 255.0, false)


func get_tree_shake_offset(side: String, scale_factor: float, tree_shakes: Dictionary) -> Vector2:
	var shake: Dictionary = tree_shakes.get(side, {})
	var timer: float = float(shake.get("timer", 0.0))
	if timer <= 0.0:
		return Vector2.ZERO
	var age: float = TREE_SHAKE_DURATION - timer
	var envelope: float = pow(timer / max(0.001, TREE_SHAKE_DURATION), 1.65)
	var strength: float = max(0.0, float(shake.get("strength", 1.0)))
	var amplitude: float = TREE_SHAKE_BASE_PIXELS * max(1.0, scale_factor) * strength
	var side_dir: float = -1.0 if side == "left" else 1.0
	return Vector2(
		round(side_dir * amplitude * envelope * sin(age * TREE_SHAKE_FREQUENCY + PI * 0.5)),
		round(amplitude * 0.22 * envelope * sin(age * TREE_SHAKE_FREQUENCY * 0.57))
	)
