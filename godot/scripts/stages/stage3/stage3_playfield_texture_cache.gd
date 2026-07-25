extends RefCounted

const TILE_SIZE := 50
const BORDER_THICKNESS := 10.0
const MAX_CHECKER_TEXTURE_CACHE_ENTRIES := 9
const MAX_BORDER_TEXTURE_CACHE_ENTRIES := 9

const PASTEL_PINK := Color(1.0, 182.0 / 255.0, 193.0 / 255.0, 1.0)
const LAVENDER := Color(230.0 / 255.0, 190.0 / 255.0, 1.0, 1.0)
const BABY_BLUE := Color(137.0 / 255.0, 207.0 / 255.0, 240.0 / 255.0, 1.0)
const WHITE := Color.WHITE

var checker_texture_cache: Dictionary = {}
var border_texture_cache: Dictionary = {}


func get_checker_texture(width: int, height: int, phase: int) -> Texture2D:
	var safe_width := maxi(1, width)
	var safe_height := maxi(1, height)
	var safe_phase := wrapi(phase, 0, 3)
	var cache_key := "%d:%d:%d" % [safe_width, safe_height, safe_phase]
	var cached: Variant = checker_texture_cache.get(cache_key, null)
	if cached is Texture2D:
		return cached

	var base := get_checker_base_color_for_phase(safe_phase)
	var alternate := Color(
		minf(1.0, base.r + 10.0 / 255.0),
		minf(1.0, base.g + 8.0 / 255.0),
		minf(1.0, base.b + 10.0 / 255.0),
		1.0
	)
	var outline := Color(
		maxf(0.0, base.r - 5.0 / 255.0),
		maxf(0.0, base.g - 5.0 / 255.0),
		maxf(0.0, base.b - 5.0 / 255.0),
		1.0
	)
	var image := Image.create(safe_width, safe_height, false, Image.FORMAT_RGBA8)
	image.fill(base)
	for x in range(0, safe_width, TILE_SIZE):
		for y in range(0, safe_height, TILE_SIZE):
			var tile_width := mini(TILE_SIZE, safe_width - x)
			var tile_height := mini(TILE_SIZE, safe_height - y)
			if tile_width <= 0 or tile_height <= 0:
				continue
			var tile_rect := Rect2i(x, y, tile_width, tile_height)
			@warning_ignore("integer_division")
			if (int(x / TILE_SIZE) + int(y / TILE_SIZE)) % 2 != 0:
				image.fill_rect(tile_rect, alternate)
			image.fill_rect(Rect2i(x, y, tile_width, 1), outline)
			image.fill_rect(Rect2i(x, y + tile_height - 1, tile_width, 1), outline)
			image.fill_rect(Rect2i(x, y, 1, tile_height), outline)
			image.fill_rect(Rect2i(x + tile_width - 1, y, 1, tile_height), outline)
	var texture := ImageTexture.create_from_image(image)
	if checker_texture_cache.size() >= MAX_CHECKER_TEXTURE_CACHE_ENTRIES:
		checker_texture_cache.clear()
	checker_texture_cache[cache_key] = texture
	return texture


func get_border_texture(width: int, height: int, phase: int) -> Texture2D:
	var safe_width := maxi(1, width)
	var safe_height := maxi(1, height)
	var safe_phase := wrapi(phase, 0, 3)
	var cache_key := "%d:%d:%d" % [safe_width, safe_height, safe_phase]
	var cached: Variant = border_texture_cache.get(cache_key, null)
	if cached is Texture2D:
		return cached

	var image := Image.create(safe_width, safe_height, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	build_border_image(image, safe_width, safe_height, safe_phase)
	var texture := ImageTexture.create_from_image(image)
	if border_texture_cache.size() >= MAX_BORDER_TEXTURE_CACHE_ENTRIES:
		border_texture_cache.clear()
	border_texture_cache[cache_key] = texture
	return texture


func build_border_image(image: Image, width: int, height: int, phase: int) -> void:
	var base_color := get_emotional_color_for_phase(phase)
	var border_pixels := maxi(1, int(round(BORDER_THICKNESS)))
	image.fill_rect(Rect2i(0, 0, width, mini(border_pixels, height)), base_color)
	image.fill_rect(Rect2i(0, maxi(0, height - border_pixels), width, mini(border_pixels, height)), base_color)
	image.fill_rect(Rect2i(0, 0, mini(border_pixels, width), height), base_color)
	image.fill_rect(Rect2i(maxi(0, width - border_pixels), 0, mini(border_pixels, width), height), base_color)

	var inner_pixels := 2
	var inner_offset := maxi(0, border_pixels - inner_pixels)
	var inner_width := maxi(0, width - 2 * inner_offset)
	var inner_height := maxi(0, height - 2 * inner_offset)
	if inner_width > 0 and inner_height > 0:
		image.fill_rect(Rect2i(inner_offset, inner_offset, inner_width, inner_pixels), WHITE)
		image.fill_rect(Rect2i(inner_offset, maxi(0, height - border_pixels), inner_width, inner_pixels), WHITE)
		image.fill_rect(Rect2i(inner_offset, inner_offset, inner_pixels, inner_height), WHITE)
		image.fill_rect(Rect2i(maxi(0, width - border_pixels), inner_offset, inner_pixels, inner_height), WHITE)

	var pattern_size := 15
	for index in range(0, width, pattern_size * 2):
		var top := Vector2(float(index) + float(pattern_size) * 0.5, BORDER_THICKNESS * 0.5)
		var bottom := Vector2(top.x, float(height) - BORDER_THICKNESS * 0.5)
		if index % (pattern_size * 4) == 0:
			draw_image_heart(image, top, 4.0, WHITE)
			draw_image_heart(image, bottom, 4.0, WHITE)
		else:
			draw_image_star(image, top, 3.0, WHITE)
			draw_image_star(image, bottom, 3.0, WHITE)
	for index in range(0, height, pattern_size * 2):
		var left := Vector2(BORDER_THICKNESS * 0.5, float(index) + float(pattern_size) * 0.5)
		var right := Vector2(float(width) - BORDER_THICKNESS * 0.5, left.y)
		if index % (pattern_size * 4) == 0:
			draw_image_heart(image, left, 4.0, WHITE)
			draw_image_heart(image, right, 4.0, WHITE)
		else:
			draw_image_star(image, left, 3.0, WHITE)
			draw_image_star(image, right, 3.0, WHITE)
	for corner in [
		Vector2(BORDER_THICKNESS * 0.5, BORDER_THICKNESS * 0.5),
		Vector2(float(width) - BORDER_THICKNESS * 0.5, BORDER_THICKNESS * 0.5),
		Vector2(BORDER_THICKNESS * 0.5, float(height) - BORDER_THICKNESS * 0.5),
		Vector2(float(width) - BORDER_THICKNESS * 0.5, float(height) - BORDER_THICKNESS * 0.5),
	]:
		draw_image_bandage_ribbon(image, corner, 8.0)


func draw_image_heart(image: Image, center: Vector2, size: float, color: Color) -> void:
	draw_image_circle(image, center + Vector2(-size * 0.45, -size * 0.34), size * 0.50, color)
	draw_image_circle(image, center + Vector2(size * 0.45, -size * 0.34), size * 0.50, color)
	draw_image_polygon(image, PackedVector2Array([
		center + Vector2(-size, -size * 0.10),
		center + Vector2(0.0, size),
		center + Vector2(size, -size * 0.10),
	]), color)


func draw_image_star(image: Image, center: Vector2, size: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(10):
		var radius := size if index % 2 == 0 else size * 0.5
		var angle := PI * float(index) / 5.0 - PI * 0.5
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_image_polygon(image, points, color)


func draw_image_bandage_ribbon(image: Image, center: Vector2, size: float) -> void:
	draw_image_line(image, center + Vector2(-size, -size), center + Vector2(size, size), PASTEL_PINK, 2.0)
	draw_image_line(image, center + Vector2(-size, size), center + Vector2(size, -size), PASTEL_PINK, 2.0)
	draw_image_circle(image, center, size * 0.45, WHITE)


func draw_image_line(image: Image, start: Vector2, finish: Vector2, color: Color, width: float) -> void:
	var delta := finish - start
	var steps := maxi(1, int(ceil(maxf(absf(delta.x), absf(delta.y)) * 2.0)))
	var radius := maxf(0.5, width * 0.5)
	for step in range(steps + 1):
		var weight := float(step) / float(steps)
		draw_image_circle(image, start.lerp(finish, weight), radius, color)


func draw_image_circle(image: Image, center: Vector2, radius: float, color: Color) -> void:
	if radius <= 0.0:
		return
	var min_x := maxi(0, int(floor(center.x - radius)))
	var max_x := mini(image.get_width() - 1, int(ceil(center.x + radius)))
	var min_y := maxi(0, int(floor(center.y - radius)))
	var max_y := mini(image.get_height() - 1, int(ceil(center.y + radius)))
	var radius_squared := radius * radius
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var delta_x := float(x) + 0.5 - center.x
			var delta_y := float(y) + 0.5 - center.y
			if delta_x * delta_x + delta_y * delta_y <= radius_squared:
				image.set_pixel(x, y, color)


func draw_image_polygon(image: Image, points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	var min_x := image.get_width() - 1
	var min_y := image.get_height() - 1
	var max_x := 0
	var max_y := 0
	for point in points:
		min_x = mini(min_x, int(floor(point.x)))
		min_y = mini(min_y, int(floor(point.y)))
		max_x = maxi(max_x, int(ceil(point.x)))
		max_y = maxi(max_y, int(ceil(point.y)))
	min_x = clampi(min_x, 0, image.get_width() - 1)
	min_y = clampi(min_y, 0, image.get_height() - 1)
	max_x = clampi(max_x, 0, image.get_width() - 1)
	max_y = clampi(max_y, 0, image.get_height() - 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if point_in_polygon(Vector2(float(x) + 0.5, float(y) + 0.5), points):
				image.set_pixel(x, y, color)


func point_in_polygon(point: Vector2, points: PackedVector2Array) -> bool:
	var inside := false
	var previous_index := points.size() - 1
	for index in range(points.size()):
		var current := points[index]
		var previous := points[previous_index]
		if (current.y > point.y) != (previous.y > point.y):
			var denominator := previous.y - current.y
			if absf(denominator) < 0.0001:
				denominator = 0.0001
			var crossing_x := (
				(previous.x - current.x)
				* (point.y - current.y)
				/ denominator
				+ current.x
			)
			if point.x < crossing_x:
				inside = not inside
		previous_index = index
	return inside


func clear() -> void:
	checker_texture_cache.clear()
	border_texture_cache.clear()


func get_snapshot() -> Dictionary:
	return {
		"checker_texture_cache_count": checker_texture_cache.size(),
		"border_texture_cache_count": border_texture_cache.size(),
	}


static func get_checker_base_color_for_phase(phase: int) -> Color:
	match wrapi(phase, 0, 3):
		1:
			return rgb255(65.0, 40.0, 55.0)
		2:
			return rgb255(40.0, 50.0, 70.0)
		_:
			return rgb255(55.0, 45.0, 65.0)


static func get_emotional_color_for_phase(phase: int) -> Color:
	match wrapi(phase, 0, 3):
		1:
			return PASTEL_PINK
		2:
			return BABY_BLUE
		_:
			return LAVENDER


static func rgb255(red: float, green: float, blue: float) -> Color:
	return Color(red / 255.0, green / 255.0, blue / 255.0, 1.0)
