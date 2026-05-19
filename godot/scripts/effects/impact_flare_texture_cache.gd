extends RefCounted

const GLOW_TEXTURE_SIZE := 128
const BURST_TEXTURE_SIZE := 192
const SPARKLE_TEXTURE_SIZE := 128
const BURST_RAY_COUNT := 18

static var _glow_texture: ImageTexture = null
static var _burst_texture: ImageTexture = null
static var _sparkle_texture: ImageTexture = null


static func prewarm() -> void:
	get_glow_texture()
	get_burst_texture()
	get_sparkle_texture()


static func get_glow_texture() -> ImageTexture:
	if _glow_texture != null:
		return _glow_texture
	_glow_texture = _build_glow_texture()
	return _glow_texture


static func get_burst_texture() -> ImageTexture:
	if _burst_texture != null:
		return _burst_texture
	_burst_texture = _build_burst_texture()
	return _burst_texture


static func get_sparkle_texture() -> ImageTexture:
	if _sparkle_texture != null:
		return _sparkle_texture
	_sparkle_texture = _build_sparkle_texture()
	return _sparkle_texture


static func draw_glow(canvas: CanvasItem, center: Vector2, radius: float, color: Color, alpha: float) -> void:
	_draw_centered_texture(canvas, get_glow_texture(), center, radius * 2.0, color, alpha)


static func draw_burst(canvas: CanvasItem, center: Vector2, radius: float, color: Color, alpha: float) -> void:
	_draw_centered_texture(canvas, get_burst_texture(), center, radius * 2.0, color, alpha)


static func draw_sparkle(canvas: CanvasItem, center: Vector2, radius: float, color: Color, alpha: float) -> void:
	_draw_centered_texture(canvas, get_sparkle_texture(), center, radius * 2.0, color, alpha)


static func _draw_centered_texture(
	canvas: CanvasItem,
	texture: Texture2D,
	center: Vector2,
	size_px: float,
	color: Color,
	alpha: float
) -> void:
	if canvas == null or texture == null or size_px <= 0.0 or alpha <= 0.0:
		return
	var size := Vector2(size_px, size_px)
	canvas.draw_texture_rect(
		texture,
		Rect2(center - size * 0.5, size),
		false,
		Color(color.r, color.g, color.b, alpha)
	)


static func _build_glow_texture() -> ImageTexture:
	var image: Image = Image.create(GLOW_TEXTURE_SIZE, GLOW_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center_coord: float = (float(GLOW_TEXTURE_SIZE) - 1.0) * 0.5
	var max_dist: float = max(1.0, center_coord)
	for y in range(GLOW_TEXTURE_SIZE):
		var dy: float = float(y) - center_coord
		for x in range(GLOW_TEXTURE_SIZE):
			var dx: float = float(x) - center_coord
			var t: float = clamp(sqrt(dx * dx + dy * dy) / max_dist, 0.0, 1.0)
			var core: float = pow(max(0.0, 1.0 - t * 1.80), 3.2) * 0.92
			var bloom: float = pow(max(0.0, 1.0 - t), 2.0) * 0.34
			var halo: float = pow(max(0.0, 1.0 - t), 0.95) * 0.14
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clamp(core + bloom + halo, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


static func _build_burst_texture() -> ImageTexture:
	var image: Image = Image.create(BURST_TEXTURE_SIZE, BURST_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center_coord: float = (float(BURST_TEXTURE_SIZE) - 1.0) * 0.5
	var max_dist: float = max(1.0, center_coord)
	for y in range(BURST_TEXTURE_SIZE):
		var dy: float = float(y) - center_coord
		for x in range(BURST_TEXTURE_SIZE):
			var dx: float = float(x) - center_coord
			var dist_ratio: float = sqrt(dx * dx + dy * dy) / max_dist
			if dist_ratio > 1.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.0))
				continue
			var angle: float = atan2(dy, dx)
			var ray_alpha: float = 0.0
			for ray_idx in range(BURST_RAY_COUNT):
				var ray_angle: float = TAU * float(ray_idx) / float(BURST_RAY_COUNT)
				var angle_delta: float = abs(wrapf(angle - ray_angle, -PI, PI))
				var ray_width: float = 0.055 + 0.020 * float(ray_idx % 3)
				var ray_shape: float = pow(clamp(1.0 - angle_delta / ray_width, 0.0, 1.0), 3.4)
				ray_shape *= pow(max(0.0, 1.0 - dist_ratio), 1.25)
				ray_shape *= 0.70 + 0.30 * sin(float(ray_idx) * 1.73)
				ray_alpha = max(ray_alpha, ray_shape)
			var core: float = pow(max(0.0, 1.0 - dist_ratio * 2.35), 2.3) * 0.72
			var haze: float = pow(max(0.0, 1.0 - dist_ratio), 2.8) * 0.20
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clamp(ray_alpha + core + haze, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


static func _build_sparkle_texture() -> ImageTexture:
	var image: Image = Image.create(SPARKLE_TEXTURE_SIZE, SPARKLE_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center_coord: float = (float(SPARKLE_TEXTURE_SIZE) - 1.0) * 0.5
	var max_dist: float = max(1.0, center_coord)
	for y in range(SPARKLE_TEXTURE_SIZE):
		var dy: float = (float(y) - center_coord) / max_dist
		for x in range(SPARKLE_TEXTURE_SIZE):
			var dx: float = (float(x) - center_coord) / max_dist
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist > 1.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.0))
				continue
			var horizontal: float = _line_alpha(abs(dy), abs(dx), 0.055, 0.95)
			var vertical: float = _line_alpha(abs(dx), abs(dy), 0.055, 0.95)
			var diag_a: float = _line_alpha(abs(dx - dy) * 0.7071, abs(dx + dy) * 0.7071, 0.045, 0.66) * 0.56
			var diag_b: float = _line_alpha(abs(dx + dy) * 0.7071, abs(dx - dy) * 0.7071, 0.045, 0.66) * 0.56
			var center: float = pow(max(0.0, 1.0 - dist * 5.0), 2.0) * 0.85
			var alpha: float = clamp(max(max(horizontal, vertical), max(diag_a, diag_b)) + center, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


static func _line_alpha(distance_to_line: float, distance_along_line: float, width: float, length: float) -> float:
	var line_width: float = pow(clamp(1.0 - distance_to_line / width, 0.0, 1.0), 2.2)
	var line_length: float = pow(clamp(1.0 - distance_along_line / length, 0.0, 1.0), 1.6)
	return line_width * line_length
