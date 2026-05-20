extends RefCounted

const CORE_TEXTURE_SIZE := 96
const HIGHLIGHT_TEXTURE_SIZE := 64
const SATURN_RING_TEXTURE_WIDTH := 256
const SATURN_RING_TEXTURE_HEIGHT := 112

static var _core_texture: ImageTexture = null
static var _highlight_texture: ImageTexture = null
static var _saturn_ring_back_texture: ImageTexture = null
static var _saturn_ring_front_texture: ImageTexture = null


static func prewarm() -> void:
	get_core_texture()
	get_highlight_texture()
	get_saturn_ring_texture(false)
	get_saturn_ring_texture(true)


static func get_core_texture() -> ImageTexture:
	if _core_texture != null:
		return _core_texture
	_core_texture = _build_core_texture()
	return _core_texture


static func get_highlight_texture() -> ImageTexture:
	if _highlight_texture != null:
		return _highlight_texture
	_highlight_texture = _build_highlight_texture()
	return _highlight_texture


static func get_saturn_ring_texture(front_half: bool) -> ImageTexture:
	if front_half:
		if _saturn_ring_front_texture == null:
			_saturn_ring_front_texture = _build_saturn_ring_texture(true)
		return _saturn_ring_front_texture
	if _saturn_ring_back_texture == null:
		_saturn_ring_back_texture = _build_saturn_ring_texture(false)
	return _saturn_ring_back_texture


static func draw_core(canvas: CanvasItem, center: Vector2, radius: float, color: Color, alpha: float) -> void:
	_draw_centered_texture(canvas, get_core_texture(), center, radius * 2.0, color, alpha)


static func draw_highlight(canvas: CanvasItem, center: Vector2, radius: float, color: Color, alpha: float) -> void:
	_draw_centered_texture(canvas, get_highlight_texture(), center, radius * 2.0, color, alpha)


static func draw_saturn_ring(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	rotation: float,
	tilt_scale: float,
	color: Color,
	alpha: float,
	front_half: bool
) -> void:
	if canvas == null or radius <= 0.0 or alpha <= 0.0:
		return
	var texture: Texture2D = get_saturn_ring_texture(front_half)
	if texture == null:
		return
	var draw_width: float = radius * 3.46
	var draw_height: float = radius * clamp(tilt_scale, 0.72, 1.18)
	var half_size := Vector2(draw_width * 0.5, draw_height * 0.5)
	var c: float = cos(rotation)
	var s: float = sin(rotation)
	var points := PackedVector2Array([
		center + _rotate_offset(Vector2(-half_size.x, -half_size.y), c, s),
		center + _rotate_offset(Vector2(half_size.x, -half_size.y), c, s),
		center + _rotate_offset(Vector2(half_size.x, half_size.y), c, s),
		center + _rotate_offset(Vector2(-half_size.x, half_size.y), c, s),
	])
	var colors := PackedColorArray([
		Color(color.r, color.g, color.b, alpha),
		Color(color.r, color.g, color.b, alpha),
		Color(color.r, color.g, color.b, alpha),
		Color(color.r, color.g, color.b, alpha),
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(float(SATURN_RING_TEXTURE_WIDTH), 0.0),
		Vector2(float(SATURN_RING_TEXTURE_WIDTH), float(SATURN_RING_TEXTURE_HEIGHT)),
		Vector2(0.0, float(SATURN_RING_TEXTURE_HEIGHT)),
	])
	canvas.draw_polygon(
		points,
		colors,
		uvs,
		texture
	)


static func _rotate_offset(offset: Vector2, c: float, s: float) -> Vector2:
	return Vector2(offset.x * c - offset.y * s, offset.x * s + offset.y * c)


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


static func _build_core_texture() -> ImageTexture:
	var image: Image = Image.create(CORE_TEXTURE_SIZE, CORE_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center_coord: float = (float(CORE_TEXTURE_SIZE) - 1.0) * 0.5
	var max_dist: float = max(1.0, center_coord)
	for y in range(CORE_TEXTURE_SIZE):
		var dy: float = float(y) - center_coord
		for x in range(CORE_TEXTURE_SIZE):
			var dx: float = float(x) - center_coord
			var t: float = clamp(sqrt(dx * dx + dy * dy) / max_dist, 0.0, 1.0)
			var solid: float = _smooth01(clamp((1.0 - t) / 0.20, 0.0, 1.0)) * 0.98
			var inner: float = pow(max(0.0, 1.0 - t * 0.86), 1.35) * 0.40
			var alpha: float = clamp(max(solid, inner), 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


static func _build_highlight_texture() -> ImageTexture:
	var image: Image = Image.create(HIGHLIGHT_TEXTURE_SIZE, HIGHLIGHT_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center_coord: float = (float(HIGHLIGHT_TEXTURE_SIZE) - 1.0) * 0.5
	var max_dist: float = max(1.0, center_coord)
	var shine_center := Vector2(-0.25, -0.30)
	for y in range(HIGHLIGHT_TEXTURE_SIZE):
		var ny: float = (float(y) - center_coord) / max_dist
		for x in range(HIGHLIGHT_TEXTURE_SIZE):
			var nx: float = (float(x) - center_coord) / max_dist
			var p := Vector2(nx, ny)
			var dist: float = (p - shine_center).length()
			var oval_x: float = (p.x - shine_center.x) / 0.52
			var oval_y: float = (p.y - shine_center.y) / 0.34
			var oval: float = sqrt(oval_x * oval_x + oval_y * oval_y)
			var spot: float = pow(clamp(1.0 - dist / 0.30, 0.0, 1.0), 2.0) * 0.82
			var crescent: float = pow(clamp(1.0 - oval, 0.0, 1.0), 1.7) * 0.44
			var alpha: float = clamp(max(spot, crescent), 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


static func _build_saturn_ring_texture(front_half: bool) -> ImageTexture:
	var image: Image = Image.create(SATURN_RING_TEXTURE_WIDTH, SATURN_RING_TEXTURE_HEIGHT, false, Image.FORMAT_RGBA8)
	var center_x: float = (float(SATURN_RING_TEXTURE_WIDTH) - 1.0) * 0.5
	var center_y: float = (float(SATURN_RING_TEXTURE_HEIGHT) - 1.0) * 0.5
	var radius_x: float = float(SATURN_RING_TEXTURE_WIDTH) * 0.43
	var radius_y: float = float(SATURN_RING_TEXTURE_HEIGHT) * 0.24
	for y in range(SATURN_RING_TEXTURE_HEIGHT):
		var ny: float = (float(y) - center_y) / radius_y
		for x in range(SATURN_RING_TEXTURE_WIDTH):
			var nx: float = (float(x) - center_x) / radius_x
			var ellipse: float = sqrt(nx * nx + ny * ny)
			if ellipse < 0.62 or ellipse > 1.08:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.0))
				continue
			var half_mask: float = _get_ring_half_mask(ny, front_half)
			if half_mask <= 0.001:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.0))
				continue
			var main_band: float = pow(clamp(1.0 - abs(ellipse - 0.88) / 0.16, 0.0, 1.0), 1.55)
			var inner_band: float = pow(clamp(1.0 - abs(ellipse - 0.73) / 0.045, 0.0, 1.0), 1.9) * 0.42
			var outer_haze: float = pow(clamp(1.0 - abs(ellipse - 1.00) / 0.16, 0.0, 1.0), 2.4) * 0.26
			var lane_mod: float = 0.82 + 0.10 * sin(ellipse * 84.0) + 0.08 * sin(nx * 28.0)
			var end_fade: float = pow(clamp(1.0 - abs(nx) / 1.10, 0.0, 1.0), 0.18)
			var alpha: float = clamp((main_band + inner_band + outer_haze) * lane_mod * half_mask * end_fade, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


static func _get_ring_half_mask(normalized_y: float, front_half: bool) -> float:
	var front_mask: float = _smooth01((normalized_y + 0.10) / 0.20)
	return front_mask if front_half else 1.0 - front_mask


static func _smooth01(value: float) -> float:
	var t: float = clamp(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
