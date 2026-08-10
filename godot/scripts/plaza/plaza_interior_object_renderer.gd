extends RefCounted

const PlazaCoinTradeAuraRenderer := preload("res://scripts/plaza/plaza_coin_trade_aura_renderer.gd")
const PlazaInteriorDrawPrimitives := preload("res://scripts/plaza/plaza_interior_draw_primitives.gd")
const PlazaShopStrewnVisualSpec := preload("res://scripts/plaza/plaza_shop_strewn_visual_spec.gd")

const EMPTY_AURA_SNAPSHOT := {}


static func draw_standard_object(
	canvas: CanvasItem,
	font: Font,
	spec: Dictionary,
	hover: float,
	flare: float,
	selected: bool,
	time: float,
	accent: Color,
	scale: float,
	texture: Texture2D
) -> void:
	if canvas == null or spec.is_empty():
		return
	var rect: Rect2 = spec.get("rect", Rect2())
	var lift := hover * 12.0 + flare * 10.0
	var center := Rect2(rect.position + Vector2(0.0, -lift), rect.size).get_center()
	canvas.draw_circle(center * scale, (54.0 + hover * 10.0 + flare * 28.0) * scale, Color(accent.r, accent.g, accent.b, 0.16 + hover * 0.20 + flare * 0.32))
	canvas.draw_circle(center * scale, (34.0 + hover * 4.0) * scale, Color(0.0, 0.95, 1.0, 0.15 + hover * 0.12))
	var pedestal := Rect2(Vector2(rect.position.x + 10.0, rect.end.y - 22.0) * scale, Vector2(rect.size.x - 20.0, 26.0) * scale)
	canvas.draw_rect(pedestal, Color(0.014, 0.022, 0.030, 0.94), true)
	canvas.draw_rect(pedestal, Color(0.0, 0.88, 1.0, 0.28), false, maxf(1.0, 1.0 * scale))
	_draw_object_icon(canvas, str(spec.get("kind", "crystal")), center, hover, flare, scale, texture)
	var ring_color := Color(1.0, 0.36, 0.94, 0.68) if selected else Color(0.0, 0.86, 1.0, 0.34 + hover * 0.34)
	canvas.draw_arc(center * scale, (43.0 + hover * 5.0) * scale, -PI * 0.12 + time, TAU * 0.82 + time, 42, ring_color, maxf(1.0, 1.8 * scale), true)
	if font == null:
		return
	var label_rect := Rect2(Vector2(rect.position.x - 8.0, rect.end.y + 10.0) * scale, Vector2(rect.size.x + 16.0, 38.0) * scale)
	canvas.draw_rect(label_rect, Color(0.012, 0.014, 0.022, 0.78), true)
	canvas.draw_rect(label_rect, Color(accent.r, accent.g, accent.b, 0.30), false, maxf(1.0, 1.0 * scale))
	PlazaInteriorDrawPrimitives.draw_text_shadow(canvas, font, label_rect.position + Vector2(10.0, 24.0) * scale, str(spec.get("label", "")), int(13.0 * scale), Color(0.94, 0.98, 1.0, 0.96))


static func draw_featured_object(
	canvas: CanvasItem,
	font: Font,
	spec: Dictionary,
	hover: float,
	flare: float,
	time: float,
	scale: float,
	texture: Texture2D
) -> void:
	if canvas == null or spec.is_empty():
		return
	var rect: Rect2 = spec.get("rect", Rect2())
	var center := rect.get_center() + Vector2(0.0, -hover * 8.0 - flare * 7.0)
	var pad_color: Color = spec.get("pad_color", Color(0.0, 0.86, 1.0, 1.0))
	canvas.draw_circle(center * scale, (48.0 + hover * 10.0 + flare * 16.0) * scale, Color(pad_color.r, pad_color.g, pad_color.b, 0.18 + hover * 0.18 + flare * 0.24))
	canvas.draw_arc(center * scale, (50.0 + hover * 5.0) * scale, time * 0.9, TAU + time * 0.9, 48, Color(pad_color.r, pad_color.g, pad_color.b, 0.54 + hover * 0.22), maxf(1.0, 1.8 * scale), true)
	_draw_object_icon(canvas, str(spec.get("kind", "crystal")), center, hover, flare, scale, texture)
	if font == null:
		return
	var label_rect := Rect2(Vector2(rect.position.x - 6.0, rect.end.y + 6.0) * scale, Vector2(rect.size.x + 12.0, 48.0) * scale)
	canvas.draw_rect(label_rect, Color(0.0, 0.0, 0.0, 0.72), true)
	canvas.draw_rect(label_rect, Color(pad_color.r, pad_color.g, pad_color.b, 0.50), false, maxf(1.0, 1.0 * scale))
	var label_lines := str(spec.get("label", "")).split("\n", false, 2)
	for line_index in range(mini(label_lines.size(), 2)):
		PlazaInteriorDrawPrimitives.draw_text_shadow(
			canvas,
			font,
			label_rect.position + Vector2(10.0, 18.0 + float(line_index) * 18.0) * scale,
			str(label_lines[line_index]),
			int(11.0 * scale),
			Color(0.94, 0.98, 1.0, 0.96)
		)


static func draw_strewn_object(
	canvas: CanvasItem,
	font: Font,
	spec: Dictionary,
	hover: float,
	flare: float,
	time: float,
	accent: Color,
	scale: float,
	texture: Texture2D,
	aura_snapshot: Dictionary,
	additive_material: Material,
	aura_material: ShaderMaterial,
	burst_material: ShaderMaterial
) -> void:
	if canvas == null or spec.is_empty():
		return
	var rect: Rect2 = spec.get("rect", Rect2())
	var center := rect.get_center()
	var kind := str(spec.get("kind", "coin_pile"))
	var base_color := PlazaShopStrewnVisualSpec.get_color(kind, accent)
	if kind == "coin_pile":
		PlazaCoinTradeAuraRenderer.draw(canvas, aura_snapshot, time, additive_material, aura_material, burst_material)
	else:
		canvas.draw_circle(center * scale, (maxf(rect.size.x, rect.size.y) * (0.50 + hover * 0.26) + flare * 22.0) * scale, Color(base_color.r, base_color.g, base_color.b, 0.10 + hover * 0.26 + flare * 0.22))
	if not _draw_strewn_texture(canvas, spec, hover, time, scale, texture):
		_draw_strewn_fallback(canvas, kind, rect, hover, time, scale, base_color)
	if kind != "coin_pile":
		var ring_radius := (maxf(rect.size.x, rect.size.y) * 0.62 + hover * 8.0 + flare * 10.0) * scale
		var ring_color := Color(1.0, 0.84, 0.34, 0.42 + hover * 0.42 + flare * 0.42)
		canvas.draw_arc(center * scale, ring_radius, -PI * 0.1 + time * 1.1, TAU * 0.84 + time * 1.1, 48, ring_color, maxf(1.0, (1.4 + hover * 1.4) * scale), true)
	_draw_strewn_trade_label(canvas, font, spec, rect, hover, scale)


static func get_object_texture_draw_size(kind: String) -> Vector2:
	match kind:
		"capsule":
			return Vector2(74.0, 96.0)
		"sell":
			return Vector2(92.0, 88.0)
		_:
			return Vector2(72.0, 98.0)


static func get_object_texture_center_offset(kind: String) -> Vector2:
	if kind == "sell":
		return Vector2(0.0, -2.0)
	return Vector2(0.0, -4.0)


static func _draw_object_icon(
	canvas: CanvasItem,
	kind: String,
	center: Vector2,
	hover: float,
	flare: float,
	scale: float,
	texture: Texture2D
) -> void:
	if texture != null:
		var draw_size := get_object_texture_draw_size(kind) * (1.0 + hover * 0.07 + flare * 0.12)
		var center_offset := get_object_texture_center_offset(kind)
		var texture_rect := Rect2((center + center_offset - draw_size * 0.5) * scale, draw_size * scale)
		canvas.draw_texture_rect(texture, texture_rect, false, Color(1.0, 1.0, 1.0, 0.96 + hover * 0.04))
		return
	var alpha := 0.88 + hover * 0.10
	match kind:
		"capsule":
			var body := Rect2((center + Vector2(-18.0, -30.0 - flare * 5.0)) * scale, Vector2(36.0, 60.0) * scale)
			canvas.draw_rect(body, Color(0.06, 0.95, 1.0, 0.24 + hover * 0.16), true)
			canvas.draw_rect(body, Color(0.0, 0.96, 1.0, alpha), false, maxf(1.0, 2.0 * scale))
			canvas.draw_circle((center + Vector2(0.0, -20.0)) * scale, 18.0 * scale, Color(1.0, 0.30, 0.92, 0.50))
			canvas.draw_circle((center + Vector2(0.0, 20.0)) * scale, 18.0 * scale, Color(0.0, 0.88, 1.0, 0.46))
		"sell":
			var body := Rect2((center + Vector2(-30.0, -20.0)) * scale, Vector2(60.0, 40.0) * scale)
			canvas.draw_rect(body, Color(1.0, 0.72, 0.22, 0.24), true)
			canvas.draw_rect(body, Color(1.0, 0.82, 0.32, alpha), false, maxf(1.0, 2.0 * scale))
			canvas.draw_line((center + Vector2(-20.0, 0.0)) * scale, (center + Vector2(20.0, 0.0)) * scale, Color(1.0, 0.88, 0.42, 0.92), maxf(1.0, 3.0 * scale))
			canvas.draw_line((center + Vector2(9.0, -12.0)) * scale, (center + Vector2(22.0, 0.0)) * scale, Color(1.0, 0.88, 0.42, 0.92), maxf(1.0, 3.0 * scale))
			canvas.draw_line((center + Vector2(9.0, 12.0)) * scale, (center + Vector2(22.0, 0.0)) * scale, Color(1.0, 0.88, 0.42, 0.92), maxf(1.0, 3.0 * scale))
		_:
			canvas.draw_circle(center * scale, (25.0 + flare * 5.0) * scale, Color(0.80, 0.22, 1.0, 0.30 + hover * 0.16))
			canvas.draw_rect(Rect2((center + Vector2(-15.0, -25.0)) * scale, Vector2(30.0, 50.0) * scale), Color(0.76, 0.20, 1.0, 0.24), true)
			canvas.draw_line((center + Vector2(0.0, -30.0)) * scale, (center + Vector2(24.0, 2.0)) * scale, Color(0.92, 0.58, 1.0, alpha), maxf(1.0, 2.2 * scale))
			canvas.draw_line((center + Vector2(24.0, 2.0)) * scale, (center + Vector2(0.0, 32.0)) * scale, Color(0.55, 0.94, 1.0, alpha), maxf(1.0, 2.2 * scale))
			canvas.draw_line((center + Vector2(0.0, 32.0)) * scale, (center + Vector2(-24.0, 2.0)) * scale, Color(0.92, 0.58, 1.0, alpha), maxf(1.0, 2.2 * scale))
			canvas.draw_line((center + Vector2(-24.0, 2.0)) * scale, (center + Vector2(0.0, -30.0)) * scale, Color(0.55, 0.94, 1.0, alpha), maxf(1.0, 2.2 * scale))


static func _draw_strewn_texture(canvas: CanvasItem, spec: Dictionary, hover: float, time: float, scale: float, texture: Texture2D) -> bool:
	if texture == null:
		return false
	var kind := str(spec.get("kind", ""))
	var rect: Rect2 = spec.get("rect", Rect2())
	var center := rect.get_center()
	var draw_size := PlazaShopStrewnVisualSpec.get_texture_draw_size(kind, rect.size) * (1.0 + hover * 0.08)
	var rotation := float(spec.get("rotation", 0.0)) + hover * 0.035 * sin(time * 5.4)
	var alpha := 0.94 + hover * 0.06
	var local_rect := Rect2(-draw_size * 0.5 * scale, draw_size * scale)
	canvas.draw_set_transform(center * scale, rotation, Vector2.ONE)
	canvas.draw_texture_rect(texture, local_rect, false, Color(1.0, 1.0, 1.0, alpha))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


static func _draw_strewn_fallback(canvas: CanvasItem, kind: String, rect: Rect2, hover: float, time: float, scale: float, base_color: Color) -> void:
	match kind:
		"money_bundle":
			_draw_money_bundle(canvas, rect, hover, scale)
		"coin_pile":
			_draw_coin_pile(canvas, rect, hover, scale)
		"gear":
			_draw_gear_prop(canvas, rect, hover, time, scale)
		"wrench_tool":
			_draw_wrench_prop(canvas, rect, hover, scale)
		"data_cube":
			_draw_data_cube_prop(canvas, rect, hover, scale)
		"circuit_gadget":
			_draw_circuit_prop(canvas, rect, hover, scale)
		_:
			canvas.draw_rect(Rect2(rect.position * scale, rect.size * scale), Color(base_color.r, base_color.g, base_color.b, 0.45 + hover * 0.18), true)


static func _draw_strewn_trade_label(canvas: CanvasItem, font: Font, spec: Dictionary, rect: Rect2, hover: float, scale: float) -> void:
	if font == null:
		return
	var label := str(spec.get("label", "")).strip_edges()
	var text := "%s  ·  거래" % label if label != "" else "거래"
	var font_size := int(13.0 * scale)
	if font_size <= 0:
		return
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var padding := 12.0 * scale
	var pill_size := Vector2(text_width + padding * 2.0, 26.0 * scale)
	var pill_position := Vector2(rect.get_center().x * scale - pill_size.x * 0.5, (rect.end.y + 14.0) * scale)
	var pill := Rect2(pill_position, pill_size)
	canvas.draw_rect(pill, Color(0.018, 0.014, 0.030, 0.86), true)
	canvas.draw_rect(pill, Color(1.0, 0.82, 0.30, 0.46 + hover * 0.42), false, maxf(1.0, 1.2 * scale))
	PlazaInteriorDrawPrimitives.draw_text_shadow(canvas, font, pill_position + Vector2(padding, 18.0 * scale), text, font_size, Color(1.0, 0.92, 0.60, 0.96))


static func _draw_money_bundle(canvas: CanvasItem, rect: Rect2, hover: float, scale: float) -> void:
	for index in range(3):
		var offset := Vector2(float(index) * 10.0, -float(index % 2) * 3.0)
		var bill := Rect2((rect.position + offset) * scale, Vector2(38.0, 22.0) * scale)
		canvas.draw_rect(bill, Color(0.08, 0.34, 0.22, 0.92), true)
		canvas.draw_rect(bill, Color(0.30, 1.0, 0.62, 0.40 + hover * 0.22), false, maxf(1.0, 1.0 * scale))
		canvas.draw_line(bill.position + Vector2(10.0, bill.size.y * 0.5), bill.position + Vector2(bill.size.x - 10.0, bill.size.y * 0.5), Color(0.80, 1.0, 0.70, 0.44), maxf(1.0, 1.0 * scale))


static func _draw_coin_pile(canvas: CanvasItem, rect: Rect2, hover: float, scale: float) -> void:
	for index in range(10):
		var x := rect.position.x + fposmod(float(index) * 17.0, rect.size.x - 8.0)
		var y := rect.position.y + fposmod(float(index) * 11.0, rect.size.y - 8.0)
		var radius := (4.0 + float(index % 3)) * scale
		canvas.draw_circle(Vector2(x, y) * scale, radius, Color(1.0, 0.70, 0.22, 0.78 + hover * 0.18))
		canvas.draw_circle(Vector2(x - 1.0, y - 1.0) * scale, radius * 0.42, Color(1.0, 0.95, 0.50, 0.42))


static func _draw_gear_prop(canvas: CanvasItem, rect: Rect2, hover: float, time: float, scale: float) -> void:
	var center := rect.get_center() * scale
	for index in range(8):
		var angle := time * (0.7 + hover * 0.8) + float(index) * TAU / 8.0
		var outer := center + Vector2(cos(angle), sin(angle)) * 24.0 * scale
		var inner := center + Vector2(cos(angle), sin(angle)) * 15.0 * scale
		canvas.draw_line(inner, outer, Color(0.78, 0.66, 0.42, 0.82), maxf(1.0, 3.0 * scale))
	canvas.draw_arc(center, 22.0 * scale, 0.0, TAU, 32, Color(0.92, 0.78, 0.44, 0.76 + hover * 0.20), maxf(1.0, 3.0 * scale), true)
	canvas.draw_arc(center, 8.0 * scale, 0.0, TAU, 20, Color(0.0, 0.0, 0.0, 0.62), maxf(1.0, 3.0 * scale), true)


static func _draw_wrench_prop(canvas: CanvasItem, rect: Rect2, hover: float, scale: float) -> void:
	var start := (rect.position + Vector2(8.0, rect.size.y - 8.0)) * scale
	var end := (rect.end - Vector2(8.0, rect.size.y - 12.0)) * scale
	canvas.draw_line(start, end, Color(0.58, 0.72, 0.76, 0.88), maxf(1.0, 6.0 * scale))
	canvas.draw_arc(end, 10.0 * scale, -PI * 0.25, PI * 1.25, 24, Color(0.78, 0.96, 1.0, 0.82 + hover * 0.14), maxf(1.0, 3.0 * scale), true)
	canvas.draw_circle(start, 7.0 * scale, Color(0.38, 0.46, 0.50, 0.86))


static func _draw_data_cube_prop(canvas: CanvasItem, rect: Rect2, hover: float, scale: float) -> void:
	var center := rect.get_center()
	var size := rect.size * 0.58
	var diamond := PackedVector2Array([
		(center + Vector2(0.0, -size.y * 0.55)) * scale,
		(center + Vector2(size.x * 0.55, 0.0)) * scale,
		(center + Vector2(0.0, size.y * 0.55)) * scale,
		(center + Vector2(-size.x * 0.55, 0.0)) * scale,
	])
	canvas.draw_colored_polygon(diamond, Color(0.16, 0.78, 1.0, 0.26 + hover * 0.14))
	for index in range(4):
		canvas.draw_line(diamond[index], diamond[(index + 1) % 4], Color(0.42, 1.0, 1.0, 0.84), maxf(1.0, 1.6 * scale))
	canvas.draw_line((center + Vector2(-size.x * 0.35, 0.0)) * scale, (center + Vector2(size.x * 0.35, 0.0)) * scale, Color(1.0, 0.24, 0.92, 0.52), maxf(1.0, 1.0 * scale))


static func _draw_circuit_prop(canvas: CanvasItem, rect: Rect2, hover: float, scale: float) -> void:
	var board := Rect2(rect.position * scale, rect.size * scale)
	canvas.draw_rect(board, Color(0.02, 0.11, 0.12, 0.88), true)
	canvas.draw_rect(board, Color(0.0, 0.92, 1.0, 0.34 + hover * 0.24), false, maxf(1.0, 1.0 * scale))
	for index in range(4):
		var y := board.position.y + (10.0 + float(index) * 8.0) * scale
		canvas.draw_line(Vector2(board.position.x + 8.0 * scale, y), Vector2(board.end.x - 8.0 * scale, y + float(index % 2) * 5.0 * scale), Color(0.0, 0.94, 0.86, 0.44 + hover * 0.18), maxf(1.0, 1.0 * scale))
	canvas.draw_circle(board.get_center(), 5.0 * scale, Color(1.0, 0.25, 0.88, 0.72))
