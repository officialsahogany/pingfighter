extends RefCounted

const NORMALIZED_SIZE := 256
const DEFAULT_HUD_CROP_ZOOM := 1.22
const DEFAULT_HUD_INNER_FILL := 0.95
const NORMALIZE_CONFIGS := {
	"smasher_wheel": {
		"crop_zoom": DEFAULT_HUD_CROP_ZOOM,
		"inner_fill": DEFAULT_HUD_INNER_FILL,
	},
	"bazooka": {
		"crop_zoom": 1.08,
		"inner_fill": 0.98,
	},
}

static var _normalized_cache: Dictionary = {}


static func normalize(skill_id: String, texture: Texture2D) -> Texture2D:
	if texture == null or not NORMALIZE_CONFIGS.has(skill_id):
		return texture

	var config: Dictionary = NORMALIZE_CONFIGS.get(skill_id, {})
	var crop_zoom: float = max(1.0, float(config.get("crop_zoom", DEFAULT_HUD_CROP_ZOOM)))
	var inner_fill: float = clamp(float(config.get("inner_fill", DEFAULT_HUD_INNER_FILL)), 0.01, 1.0)
	var cache_key := "%s:%s:%s:%s:%s" % [
		skill_id,
		str(texture.get_rid().get_id()),
		str(NORMALIZED_SIZE),
		str(crop_zoom),
		str(inner_fill),
	]
	if _normalized_cache.has(cache_key):
		var cached: Variant = _normalized_cache[cache_key]
		if cached is Texture2D:
			return cached
		_normalized_cache.erase(cache_key)

	var normalized := _create_cropped_orb_texture(texture, crop_zoom, inner_fill)
	if normalized == null:
		return texture
	_normalized_cache[cache_key] = normalized
	return normalized


static func clear_cache() -> void:
	_normalized_cache.clear()


static func _create_cropped_orb_texture(texture: Texture2D, crop_zoom: float, inner_fill: float) -> Texture2D:
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return null

	image.convert(Image.FORMAT_RGBA8)
	var zoom_size: int = max(NORMALIZED_SIZE + 2, int(round(float(NORMALIZED_SIZE) * crop_zoom)))
	image.resize(zoom_size, zoom_size, Image.INTERPOLATE_LANCZOS)

	var crop_origin := Vector2i(
		max(0, int(floor(float(zoom_size - NORMALIZED_SIZE) * 0.5))),
		max(0, int(floor(float(zoom_size - NORMALIZED_SIZE) * 0.5)))
	)
	var cropped := Image.create_empty(NORMALIZED_SIZE, NORMALIZED_SIZE, false, Image.FORMAT_RGBA8)
	cropped.fill(Color(0.0, 0.0, 0.0, 0.0))
	cropped.blit_rect(
		image,
		Rect2i(crop_origin, Vector2i(NORMALIZED_SIZE, NORMALIZED_SIZE)),
		Vector2i.ZERO
	)

	var inner_size: int = clampi(int(round(float(NORMALIZED_SIZE) * inner_fill)), 1, NORMALIZED_SIZE)
	cropped.resize(inner_size, inner_size, Image.INTERPOLATE_LANCZOS)

	var normalized := Image.create_empty(NORMALIZED_SIZE, NORMALIZED_SIZE, false, Image.FORMAT_RGBA8)
	normalized.fill(Color(0.0, 0.0, 0.0, 0.0))
	normalized.blit_rect(
		cropped,
		Rect2i(Vector2i.ZERO, Vector2i(inner_size, inner_size)),
		Vector2i(
			int(floor(float(NORMALIZED_SIZE - inner_size) * 0.5)),
			int(floor(float(NORMALIZED_SIZE - inner_size) * 0.5))
		)
	)
	_apply_circular_alpha_mask(normalized)
	return ImageTexture.create_from_image(normalized)


static func _apply_circular_alpha_mask(image: Image) -> void:
	var center := Vector2(float(NORMALIZED_SIZE) * 0.5, float(NORMALIZED_SIZE) * 0.5)
	var radius: float = max(1.0, float(NORMALIZED_SIZE) * 0.5 - 1.0)
	var radius_sq: float = radius * radius
	for y in range(NORMALIZED_SIZE):
		for x in range(NORMALIZED_SIZE):
			var sample := Vector2(float(x), float(y))
			if sample.distance_squared_to(center) <= radius_sq:
				continue
			var color: Color = image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			color.a = 0.0
			image.set_pixel(x, y, color)
