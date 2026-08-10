extends RefCounted

const PlazaInteriorDrawPrimitives := preload("res://scripts/plaza/plaza_interior_draw_primitives.gd")
const PlazaInteriorLayout := preload("res://scripts/plaza/plaza_interior_layout.gd")

# The procedural fallback room is shared by every non-shop interior. The shop
# has a top-view backdrop and therefore never uses this label table.
const PROCEDURAL_ROOM_NEON_SIGNS := {
	"bank": "BANK",
	"gacha": "GACHA",
	"lingpet_store": "SPIRIT",
	"blacksmith": "FORGE",
	"tavern": "PUB",
	"academy": "SKILL",
}


static func draw_room(
	canvas: CanvasItem,
	font: Font,
	view_size: Vector2,
	scale: float,
	time: float,
	building_type: String,
	accent: Color,
	backdrop_texture: Texture2D
) -> bool:
	if canvas == null or scale <= 0.0:
		return false
	if _draw_backdrop_texture(canvas, view_size, backdrop_texture):
		return true
	_draw_procedural_background(canvas, font, view_size, scale, time, building_type, accent)
	if backdrop_texture == null:
		_draw_shop_table(canvas, scale)
	return false


static func get_cover_source_rect(texture_size: Vector2, target_size: Vector2) -> Rect2:
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or target_size.x <= 0.0 or target_size.y <= 0.0:
		return Rect2()
	var target_ratio := target_size.x / target_size.y
	var source_ratio := texture_size.x / texture_size.y
	var source_rect := Rect2(Vector2.ZERO, texture_size)
	if source_ratio > target_ratio:
		var crop_width := texture_size.y * target_ratio
		source_rect.position.x = (texture_size.x - crop_width) * 0.5
		source_rect.size.x = crop_width
	elif source_ratio < target_ratio:
		var crop_height := texture_size.x / target_ratio
		source_rect.position.y = (texture_size.y - crop_height) * 0.5
		source_rect.size.y = crop_height
	return source_rect


static func get_neon_label(building_type: String) -> String:
	return str(PROCEDURAL_ROOM_NEON_SIGNS.get(building_type, ""))


static func _draw_backdrop_texture(canvas: CanvasItem, view_size: Vector2, backdrop_texture: Texture2D) -> bool:
	if backdrop_texture == null:
		return false
	var source_rect := get_cover_source_rect(backdrop_texture.get_size(), view_size)
	if not source_rect.has_area():
		return false
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 1.0), true)
	canvas.draw_texture_rect_region(backdrop_texture, Rect2(Vector2.ZERO, view_size), source_rect)
	return true


static func _draw_procedural_background(
	canvas: CanvasItem,
	font: Font,
	view_size: Vector2,
	scale: float,
	time: float,
	building_type: String,
	accent: Color
) -> void:
	var game_size := PlazaInteriorLayout.GAME_SIZE
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.006, 0.008, 0.014, 1.0), true)
	for index in range(16):
		var blend := float(index) / 15.0
		var band := Rect2(
			Vector2(0.0, blend * game_size.y) * scale,
			Vector2(game_size.x, game_size.y / 15.0 + 2.0) * scale
		)
		canvas.draw_rect(band, Color(0.012 + blend * 0.018, 0.010 + blend * 0.010, 0.025 + blend * 0.026, 1.0), true)
	var pulse := 0.5 + 0.5 * sin(time * 3.7)
	for index in range(10):
		var x := 296.0 + float(index) * 46.0
		var y := 96.0 + float(index % 3) * 42.0
		canvas.draw_line(Vector2(x, y) * scale, Vector2(x + 72.0, y + 122.0) * scale, Color(accent.r, accent.g, accent.b, 0.07 + pulse * 0.03), maxf(1.0, 1.4 * scale))
	for index in range(7):
		var panel := Rect2(Vector2(305.0 + float(index) * 58.0, 70.0 + float(index % 2) * 28.0) * scale, Vector2(42.0, 82.0) * scale)
		canvas.draw_rect(panel, Color(0.015, 0.020, 0.034, 0.84), true)
		canvas.draw_rect(panel, Color(0.75, 0.12, 0.95, 0.18), false, maxf(1.0, 1.0 * scale))
	var floor_rect := Rect2(Vector2(258.0, 464.0) * scale, Vector2(486.0, 226.0) * scale)
	canvas.draw_rect(floor_rect, Color(0.028, 0.026, 0.038, 0.98), true)
	for index in range(9):
		var y := 484.0 + float(index) * 22.0
		canvas.draw_line(Vector2(270.0, y) * scale, Vector2(724.0, y - 18.0) * scale, Color(0.0, 0.80, 0.94, 0.050), maxf(1.0, 1.0 * scale))
	for index in range(8):
		var x := 292.0 + float(index) * 54.0
		canvas.draw_line(Vector2(x, 666.0) * scale, Vector2(x + 88.0, 476.0) * scale, Color(1.0, 0.22, 0.92, 0.042), maxf(1.0, 1.0 * scale))
	_draw_room_neon_sign(canvas, font, scale, building_type)
	_draw_wall_neon_props(canvas, scale)
	_draw_room_clutter(canvas, scale)


static func _draw_shop_table(canvas: CanvasItem, scale: float) -> void:
	var table_rect := Rect2(Vector2(292.0, 438.0) * scale, Vector2(438.0, 154.0) * scale)
	canvas.draw_rect(table_rect, Color(0.030, 0.022, 0.034, 0.98), true)
	canvas.draw_rect(table_rect, Color(0.0, 0.88, 0.92, 0.20), false, maxf(1.0, 1.5 * scale))
	canvas.draw_line(Vector2(308.0, 458.0) * scale, Vector2(710.0, 430.0) * scale, Color(1.0, 0.18, 0.92, 0.28), maxf(1.0, 1.0 * scale))
	canvas.draw_line(Vector2(312.0, 594.0) * scale, Vector2(704.0, 566.0) * scale, Color(0.0, 0.90, 1.0, 0.20), maxf(1.0, 1.0 * scale))
	_draw_table_clutter(canvas, scale)


static func _draw_room_neon_sign(canvas: CanvasItem, font: Font, scale: float, building_type: String) -> void:
	var label := get_neon_label(building_type)
	if label == "":
		return
	var sign_rect := Rect2(Vector2(544.0, 108.0) * scale, Vector2(116.0, 54.0) * scale)
	canvas.draw_rect(sign_rect, Color(0.018, 0.024, 0.036, 0.92), true)
	canvas.draw_rect(sign_rect, Color(1.0, 0.08, 0.80, 0.46), false, maxf(1.0, 1.4 * scale))
	if font == null:
		return
	var font_size := int(23.0 * scale)
	if font_size <= 0:
		return
	var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var text_position := Vector2(sign_rect.get_center().x - text_width * 0.5, sign_rect.position.y + 38.0 * scale)
	PlazaInteriorDrawPrimitives.draw_text_shadow(canvas, font, text_position, label, font_size, Color(1.0, 0.40, 0.95, 0.94))


static func _draw_wall_neon_props(canvas: CanvasItem, scale: float) -> void:
	var cat_rect := Rect2(Vector2(650.0, 196.0) * scale, Vector2(68.0, 62.0) * scale)
	canvas.draw_rect(cat_rect, Color(0.018, 0.018, 0.032, 0.78), true)
	canvas.draw_rect(cat_rect, Color(1.0, 0.16, 0.82, 0.34), false, maxf(1.0, 1.0 * scale))
	var cat_center := Vector2(684.0, 226.0)
	canvas.draw_circle(cat_center * scale, 16.0 * scale, Color(1.0, 0.18, 0.86, 0.08))
	canvas.draw_arc(cat_center * scale, 16.0 * scale, 0.0, TAU, 32, Color(1.0, 0.28, 0.90, 0.72), maxf(1.0, 1.3 * scale), true)
	canvas.draw_line((cat_center + Vector2(-10.0, -12.0)) * scale, (cat_center + Vector2(-18.0, -24.0)) * scale, Color(1.0, 0.28, 0.90, 0.72), maxf(1.0, 1.3 * scale))
	canvas.draw_line((cat_center + Vector2(10.0, -12.0)) * scale, (cat_center + Vector2(18.0, -24.0)) * scale, Color(1.0, 0.28, 0.90, 0.72), maxf(1.0, 1.3 * scale))
	canvas.draw_circle((cat_center + Vector2(-6.0, -2.0)) * scale, 2.0 * scale, Color(0.0, 0.92, 1.0, 0.90))
	canvas.draw_circle((cat_center + Vector2(7.0, -2.0)) * scale, 2.0 * scale, Color(0.0, 0.92, 1.0, 0.90))
	var board_rect := Rect2(Vector2(596.0, 282.0) * scale, Vector2(122.0, 72.0) * scale)
	canvas.draw_rect(board_rect, Color(0.016, 0.026, 0.030, 0.70), true)
	canvas.draw_rect(board_rect, Color(0.0, 0.88, 1.0, 0.24), false, maxf(1.0, 1.0 * scale))
	for index in range(5):
		var y := 296.0 + float(index) * 10.0
		canvas.draw_line(Vector2(610.0, y) * scale, Vector2(700.0 - float(index % 2) * 18.0, y + 4.0) * scale, Color(0.0, 0.92, 1.0, 0.13), maxf(1.0, 0.8 * scale))


static func _draw_room_clutter(canvas: CanvasItem, scale: float) -> void:
	for index in range(22):
		var x := 288.0 + fposmod(float(index) * 71.0, 438.0)
		var y := 604.0 + fposmod(float(index) * 37.0, 78.0)
		var color := Color(1.0, 0.72, 0.24, 0.20) if index % 3 == 0 else Color(0.0, 0.86, 1.0, 0.13)
		if index % 4 == 0:
			canvas.draw_circle(Vector2(x, y) * scale, (3.5 + float(index % 5)) * scale, color)
			canvas.draw_circle(Vector2(x, y) * scale, (2.0 + float(index % 3)) * scale, Color(0.0, 0.0, 0.0, 0.28))
		else:
			var chip := Rect2(Vector2(x, y) * scale, Vector2(18.0 + float(index % 5) * 3.0, 8.0 + float(index % 3) * 3.0) * scale)
			canvas.draw_rect(chip, Color(0.018, 0.024, 0.030, 0.72), true)
			canvas.draw_rect(chip, color, false, maxf(1.0, 0.8 * scale))
	for index in range(7):
		var start := Vector2(312.0 + float(index) * 58.0, 686.0)
		var end := start + Vector2(44.0 + float(index % 2) * 30.0, -34.0 - float(index % 3) * 14.0)
		canvas.draw_line(start * scale, end * scale, Color(0.68, 0.16, 0.92, 0.13), maxf(1.0, 1.2 * scale))


static func _draw_table_clutter(canvas: CanvasItem, scale: float) -> void:
	for index in range(18):
		var x := 316.0 + fposmod(float(index) * 49.0, 386.0)
		var y := 470.0 + fposmod(float(index) * 29.0, 96.0)
		if index % 5 == 0:
			canvas.draw_circle(Vector2(x, y) * scale, 6.0 * scale, Color(1.0, 0.76, 0.22, 0.46))
			canvas.draw_circle(Vector2(x, y) * scale, 3.0 * scale, Color(0.25, 0.15, 0.04, 0.46))
		elif index % 3 == 0:
			var vial := Rect2(Vector2(x, y) * scale, Vector2(8.0, 24.0) * scale)
			canvas.draw_rect(vial, Color(0.0, 0.94, 1.0, 0.18), true)
			canvas.draw_rect(vial, Color(0.0, 0.94, 1.0, 0.42), false, maxf(1.0, 0.8 * scale))
		else:
			var card := Rect2(Vector2(x, y) * scale, Vector2(24.0, 16.0) * scale)
			canvas.draw_rect(card, Color(0.024, 0.028, 0.040, 0.82), true)
			canvas.draw_rect(card, Color(1.0, 0.24, 0.88, 0.22), false, maxf(1.0, 0.8 * scale))
