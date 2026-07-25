extends RefCounted

const ANIMATION_META := {
	"coin_pile": {
		"texture_key": "coin_pile_anim",
		"cols": 5,
		"rows": 5,
		"frames": 25,
		"duration": 0.72,
	},
}

const TEXTURE_DRAW_SIZES := {
	"money_bundle": Vector2(92.0, 72.0),
	"coin_pile": Vector2(108.0, 88.0),
	"gear": Vector2(64.0, 64.0),
	"wrench_tool": Vector2(100.0, 66.0),
	"data_cube": Vector2(78.0, 78.0),
	"circuit_gadget": Vector2(94.0, 68.0),
}


static func get_animation_meta(kind: String) -> Dictionary:
	var value: Variant = ANIMATION_META.get(kind, {})
	return value as Dictionary if value is Dictionary else {}


static func get_texture_draw_size(kind: String, fallback_size: Vector2) -> Vector2:
	var value: Variant = TEXTURE_DRAW_SIZES.get(kind, fallback_size)
	return value as Vector2 if value is Vector2 else fallback_size


static func get_color(kind: String, fallback: Color) -> Color:
	match kind:
		"money_bundle":
			return Color(0.42, 1.0, 0.62, 1.0)
		"coin_pile":
			return Color(1.0, 0.75, 0.24, 1.0)
		"gear", "wrench_tool":
			return Color(0.86, 0.76, 0.58, 1.0)
		"data_cube", "circuit_gadget":
			return Color(0.0, 0.90, 1.0, 1.0)
		_:
			return fallback


static func get_sheet_frame_rect(texture: Texture2D, cols: int, rows: int, frame_index: int) -> Rect2:
	if texture == null or cols <= 0 or rows <= 0:
		return Rect2()
	var texture_size := texture.get_size()
	var cell_size := Vector2(texture_size.x / float(cols), texture_size.y / float(rows))
	var safe_index := maxi(0, frame_index)
	var col := safe_index % cols
	var row := int(float(safe_index) / float(cols))
	row = mini(row, rows - 1)
	return Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size)
