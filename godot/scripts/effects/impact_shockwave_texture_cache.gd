extends RefCounted

const TEXTURE_SIZE := 128
const RING_RADIUS_RATIO := 0.72
const CORE_THICKNESS_RATIO := 0.030
const HALO_THICKNESS_RATIO := 0.115

static var _full_ring_texture: ImageTexture = null
static var _left_wall_ring_texture: ImageTexture = null
static var _right_wall_ring_texture: ImageTexture = null


static func prewarm() -> void:
	get_full_ring_texture()
	get_wall_ring_texture("left")
	get_wall_ring_texture("right")


static func get_full_ring_texture() -> ImageTexture:
	if _full_ring_texture != null:
		return _full_ring_texture
	_full_ring_texture = _build_ring_texture("")
	return _full_ring_texture


static func get_wall_ring_texture(side: String) -> ImageTexture:
	if side == "right":
		if _right_wall_ring_texture == null:
			_right_wall_ring_texture = _build_ring_texture("right")
		return _right_wall_ring_texture
	if _left_wall_ring_texture == null:
		_left_wall_ring_texture = _build_ring_texture("left")
	return _left_wall_ring_texture


static func draw_full_ring(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	color: Color,
	alpha: float
) -> void:
	_draw_ring_texture(canvas, get_full_ring_texture(), center, radius, color, alpha)


static func draw_wall_ring(
	canvas: CanvasItem,
	side: String,
	center: Vector2,
	radius: float,
	color: Color,
	alpha: float
) -> void:
	_draw_ring_texture(canvas, get_wall_ring_texture(side), center, radius, color, alpha)


static func _draw_ring_texture(
	canvas: CanvasItem,
	texture: Texture2D,
	center: Vector2,
	radius: float,
	color: Color,
	alpha: float
) -> void:
	if canvas == null or texture == null or radius <= 0.0 or alpha <= 0.0:
		return
	var draw_radius: float = max(1.0, radius / RING_RADIUS_RATIO)
	var size := Vector2(draw_radius * 2.0, draw_radius * 2.0)
	var rect := Rect2(center - size * 0.5, size)
	canvas.draw_texture_rect(texture, rect, false, Color(color.r, color.g, color.b, alpha))


static func _build_ring_texture(side: String) -> ImageTexture:
	var image: Image = Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center_coord: float = (float(TEXTURE_SIZE) - 1.0) * 0.5
	var max_dist: float = max(1.0, center_coord)

	for y in range(TEXTURE_SIZE):
		var dy: float = float(y) - center_coord
		for x in range(TEXTURE_SIZE):
			var dx: float = float(x) - center_coord
			if side == "left" and dx < 0.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.0))
				continue
			if side == "right" and dx > 0.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.0))
				continue

			var distance_ratio: float = sqrt(dx * dx + dy * dy) / max_dist
			if distance_ratio > 1.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.0))
				continue

			var ring_delta: float = abs(distance_ratio - RING_RADIUS_RATIO)
			var core: float = pow(clamp(1.0 - ring_delta / CORE_THICKNESS_RATIO, 0.0, 1.0), 1.7)
			var halo: float = pow(clamp(1.0 - ring_delta / HALO_THICKNESS_RATIO, 0.0, 1.0), 2.4)
			var alpha: float = clamp(core * 0.90 + halo * 0.42, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return ImageTexture.create_from_image(image)
