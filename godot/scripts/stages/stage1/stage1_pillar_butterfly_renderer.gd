extends RefCounted

const Stage1PillarLayerGeometry := preload("res://scripts/stages/stage1/stage1_pillar_layer_geometry.gd")

const BUTTERFLY_FRAME_COUNT := 4
const BUTTERFLY_COLOR_COUNT := 4

var geometry: Object = Stage1PillarLayerGeometry.new()


func draw(
	canvas: CanvasItem,
	butterfly_sheet_texture: Texture2D,
	butterflies: Array[Dictionary],
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	scale_factor: float,
	time: float
) -> void:
	if butterfly_sheet_texture == null:
		return
	for butterfly in butterflies:
		var side: String = str(butterfly.get("side", "left"))
		var side_rect: Rect2 = geometry.get_side_rect(side, view_size, game_offset, game_size)
		if side_rect.size.x <= 24.0:
			continue
		var phase: float = float(butterfly.get("phase", 0.0))
		var base_x: float = side_rect.position.x + side_rect.size.x * 0.5
		var base_y: float = view_size.y * float(butterfly.get("y_ratio", 0.5))
		var draw_pos := Vector2(
			base_x + sin(time * 0.5 + phase) * 15.0 * scale_factor,
			base_y + cos(time * 0.3 + phase) * 10.0 * scale_factor
		)
		var wing_speed: float = float(butterfly.get("wing_speed", 10.0))
		var anim_t: float = fmod(time * wing_speed + phase, TAU)
		var frame_index: int = int((anim_t / TAU) * float(BUTTERFLY_FRAME_COUNT)) % BUTTERFLY_FRAME_COUNT
		var color_index: int = int(butterfly.get("color_index", 0)) % BUTTERFLY_COLOR_COUNT
		var cell_w: float = float(butterfly_sheet_texture.get_width()) / float(BUTTERFLY_FRAME_COUNT)
		var cell_h: float = float(butterfly_sheet_texture.get_height()) / float(BUTTERFLY_COLOR_COUNT)
		var source_region := Rect2(cell_w * float(frame_index), cell_h * float(color_index), cell_w, cell_h)
		var target_size: float = max(18.0, 44.0 * max(0.4, float(butterfly.get("size", 1.0))) * scale_factor)
		geometry.draw_texture_region(
			canvas,
			butterfly_sheet_texture,
			Rect2(draw_pos - Vector2(target_size, target_size) * 0.5, Vector2(target_size, target_size)),
			source_region
		)
