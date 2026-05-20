extends RefCounted

const MAX_CACHE_ENTRIES := 24
const TEXTURE_SIZE_BUCKET := 16

var _texture_cache: Dictionary = {}


func prewarm_radial_background(radius: float, outer_color: Color, inner_color: Color) -> void:
	_get_radial_texture(max(1.0, radius), outer_color, inner_color)


func draw_radial_background(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	outer_color: Color,
	inner_color: Color
) -> void:
	if canvas == null:
		return
	var safe_radius: float = max(1.0, radius)
	var texture: Texture2D = _get_radial_texture(safe_radius, outer_color, inner_color)
	if texture == null:
		return
	var draw_size: float = safe_radius * 2.0
	canvas.draw_texture_rect(texture, Rect2(center - Vector2(draw_size, draw_size) * 0.5, Vector2(draw_size, draw_size)), false)


func _get_radial_texture(radius: float, outer_color: Color, inner_color: Color) -> Texture2D:
	var size: int = _texture_size_for_radius(radius)
	var cache_key: String = "%d|%s|%s" % [
		size,
		_color_key(outer_color),
		_color_key(inner_color),
	]
	var cached: Variant = _texture_cache.get(cache_key, null)
	if cached is Texture2D:
		return cached

	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center_coord: float = (float(size) - 1.0) * 0.5
	var max_dist: float = max(1.0, center_coord)
	for y in range(size):
		var dy: float = float(y) - center_coord
		for x in range(size):
			var dx: float = float(x) - center_coord
			var dist_ratio: float = sqrt(dx * dx + dy * dy) / max_dist
			if dist_ratio > 1.0:
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			image.set_pixel(x, y, outer_color.lerp(inner_color, 1.0 - dist_ratio))
	var texture: Texture2D = ImageTexture.create_from_image(image)
	if _texture_cache.size() >= MAX_CACHE_ENTRIES:
		_texture_cache.clear()
	_texture_cache[cache_key] = texture
	return texture


func _texture_size_for_radius(radius: float) -> int:
	var diameter: float = max(1.0, radius) * 2.0
	return max(TEXTURE_SIZE_BUCKET, int(ceil(diameter / float(TEXTURE_SIZE_BUCKET))) * TEXTURE_SIZE_BUCKET)


func _color_key(color: Color) -> String:
	return "%03d%03d%03d%03d" % [
		int(round(clamp(color.r, 0.0, 1.0) * 255.0)),
		int(round(clamp(color.g, 0.0, 1.0) * 255.0)),
		int(round(clamp(color.b, 0.0, 1.0) * 255.0)),
		int(round(clamp(color.a, 0.0, 1.0) * 255.0)),
	]
