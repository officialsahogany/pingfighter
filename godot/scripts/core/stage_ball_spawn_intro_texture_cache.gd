extends RefCounted

const GLOW_TEX_SIZE := 128
const BALL_BODY_TEX_SIZE := 128

static var _glow_tex: ImageTexture = null
static var _ball_tex: ImageTexture = null
static var _ball_body_tex: ImageTexture = null
static var _prewarm_step_index := 0


static func prewarm() -> void:
	while not prewarm_step():
		pass


static func prewarm_step() -> bool:
	match _prewarm_step_index:
		0:
			get_glow_texture()
		1:
			get_ball_texture()
		2:
			get_ball_body_texture()
		_:
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	return false


static func get_glow_texture() -> ImageTexture:
	if _glow_tex != null:
		return _glow_tex
	var size: int = GLOW_TEX_SIZE
	var data := PackedByteArray()
	data.resize(size * size * 4)
	var c: float = float(size) * 0.5
	var offset := 0
	for y in range(size):
		for x in range(size):
			var dx: float = float(x) - c + 0.5
			var dy: float = float(y) - c + 0.5
			var d: float = sqrt(dx * dx + dy * dy)
			var t: float = clamp(d / c, 0.0, 1.0)
			var bright_core: float = pow(max(0.0, 1.0 - t * 1.55), 4.0) * 0.92
			var mid: float = pow(max(0.0, 1.0 - t * 1.10), 2.4) * 0.42
			var halo: float = pow(1.0 - t, 1.7) * 0.22
			var alpha: float = clamp(bright_core + mid + halo, 0.0, 1.0)
			_write_pixel(data, offset, 255, 255, 255, _alpha_to_byte(alpha))
			offset += 4
	var img: Image = Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data)
	_glow_tex = ImageTexture.create_from_image(img)
	return _glow_tex


static func get_ball_texture() -> ImageTexture:
	if _ball_tex != null:
		return _ball_tex
	var size: int = 192
	var data := PackedByteArray()
	data.resize(size * size * 4)
	var c: float = float(size) * 0.5
	var offset := 0
	for y in range(size):
		for x in range(size):
			var dx: float = float(x) - c + 0.5
			var dy: float = float(y) - c + 0.5
			var d: float = sqrt(dx * dx + dy * dy)
			var t: float = clamp(d / c, 0.0, 1.0)
			var corona: float = pow(1.0 - t, 1.6) * 0.55
			var bloom: float = pow(max(0.0, 1.0 - t * 1.3), 2.6) * 0.45
			var alpha: float = clamp(corona + bloom, 0.0, 1.0)
			_write_pixel(data, offset, 255, 255, 255, _alpha_to_byte(alpha))
			offset += 4
	var img: Image = Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data)
	_ball_tex = ImageTexture.create_from_image(img)
	return _ball_tex


static func get_ball_body_texture() -> ImageTexture:
	if _ball_body_tex != null:
		return _ball_body_tex
	var size: int = BALL_BODY_TEX_SIZE
	var data := PackedByteArray()
	data.resize(size * size * 4)
	var c: float = float(size) * 0.5
	var radius: float = float(size) * 0.33
	var highlight_x: float = -radius * 0.32
	var highlight_y: float = -radius * 0.34
	var inner_highlight_x: float = highlight_x - radius * 0.07
	var inner_highlight_y: float = highlight_y - radius * 0.05
	var offset := 0
	for y in range(size):
		for x in range(size):
			var px: float = float(x) - c + 0.5
			var py: float = float(y) - c + 0.5
			var d: float = sqrt(px * px + py * py)
			var t: float = d / radius
			var col := Color(0.0, 0.0, 0.0, 0.0)
			if t <= 1.08:
				col = _blend_over(col, Color(0.10, 0.30, 0.78, 0.45 * smoothstep(1.08, 0.98, t)))
			if t <= 1.0:
				col = _blend_over(col, Color(0.20, 0.50, 0.95, smoothstep(1.0, 0.94, t)))
			if t <= 0.86:
				col = _blend_over(col, Color(0.32, 0.65, 1.0, 0.85 * smoothstep(0.86, 0.74, t)))
			if t <= 0.66:
				col = _blend_over(col, Color(0.50, 0.82, 1.0, 0.75 * smoothstep(0.66, 0.50, t)))
			if t <= 0.46:
				col = _blend_over(col, Color(0.70, 0.93, 1.0, 0.70 * smoothstep(0.46, 0.26, t)))

			var hl_dx: float = px - highlight_x
			var hl_dy: float = py - highlight_y
			var hl_dist: float = sqrt(hl_dx * hl_dx + hl_dy * hl_dy)
			if hl_dist <= radius * 0.34:
				var hl_alpha: float = 0.92 * smoothstep(radius * 0.34, radius * 0.17, hl_dist)
				col = _blend_over(col, Color(1.0, 1.0, 1.0, hl_alpha))
			var inner_hl_dx: float = px - inner_highlight_x
			var inner_hl_dy: float = py - inner_highlight_y
			var inner_hl_dist: float = sqrt(inner_hl_dx * inner_hl_dx + inner_hl_dy * inner_hl_dy)
			if inner_hl_dist <= radius * 0.16:
				col = _blend_over(col, Color(1.0, 1.0, 1.0, smoothstep(radius * 0.16, radius * 0.04, inner_hl_dist)))

			if t > 0.83 and t < 1.03:
				var ang: float = atan2(py, px)
				if ang > PI * 1.05 or ang < -PI * 0.15:
					var arc_alpha: float = 0.38 * (1.0 - abs(t - 0.93) / 0.10)
					col = _blend_over(col, Color(1.0, 1.0, 1.0, max(0.0, arc_alpha)))
			_write_color_pixel(data, offset, col)
			offset += 4
	var img: Image = Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data)
	_ball_body_tex = ImageTexture.create_from_image(img)
	return _ball_body_tex


static func _blend_over(dst: Color, src: Color) -> Color:
	var out_a: float = src.a + dst.a * (1.0 - src.a)
	if out_a <= 0.0001:
		return Color(0.0, 0.0, 0.0, 0.0)
	var out_r: float = (src.r * src.a + dst.r * dst.a * (1.0 - src.a)) / out_a
	var out_g: float = (src.g * src.a + dst.g * dst.a * (1.0 - src.a)) / out_a
	var out_b: float = (src.b * src.a + dst.b * dst.a * (1.0 - src.a)) / out_a
	return Color(out_r, out_g, out_b, out_a)


static func _write_pixel(data: PackedByteArray, offset: int, r: int, g: int, b: int, a: int) -> void:
	data[offset] = r
	data[offset + 1] = g
	data[offset + 2] = b
	data[offset + 3] = a


static func _write_color_pixel(data: PackedByteArray, offset: int, color: Color) -> void:
	data[offset] = _color_to_byte(color.r)
	data[offset + 1] = _color_to_byte(color.g)
	data[offset + 2] = _color_to_byte(color.b)
	data[offset + 3] = _alpha_to_byte(color.a)


static func _alpha_to_byte(alpha: float) -> int:
	return int(clamp(round(alpha * 255.0), 0.0, 255.0))


static func _color_to_byte(channel: float) -> int:
	return int(clamp(round(channel * 255.0), 0.0, 255.0))
