extends RefCounted

# Procedural texture fragments for the Maribo Hydro Sphere water puddle VFX.
# Mirrors the impact_flare / impact_shockwave texture-cache pattern: static lazy
# cache + PackedByteArray pixel builders + ImageTexture. All textures are
# radially alpha-faded squares so blitting them stretched into the puddle's wide
# bounding box (rx*2 x ry*2) yields an ELLIPSE-shaped result automatically (a
# radial fade stretched to a w!=h rect reads as an ellipse) -- no per-primitive
# masking or draw_set_transform needed (immediate-mode friendly).
#
# The caustic texture is built to tile-scroll: blit it with draw_texture_rect_region
# at a time-animated source offset to fake flowing water caustics without a GPU
# shader. Layer two scrolls in opposite directions for shimmer.

const CAUSTIC_TEXTURE_SIZE := 192
const SURFACE_TEXTURE_SIZE := 128
const FOAM_RING_TEXTURE_SIZE := 160
const DROPLET_TEXTURE_SIZE := 48

static var _caustic_texture: ImageTexture = null
static var _surface_texture: ImageTexture = null
static var _foam_ring_texture: ImageTexture = null
static var _droplet_texture: ImageTexture = null


static func prewarm() -> void:
	get_caustic_texture()
	get_surface_texture()
	get_foam_ring_texture()
	get_droplet_texture()


static func get_caustic_texture() -> ImageTexture:
	if _caustic_texture == null:
		_caustic_texture = _build_caustic_texture()
	return _caustic_texture


static func get_surface_texture() -> ImageTexture:
	if _surface_texture == null:
		_surface_texture = _build_surface_texture()
	return _surface_texture


static func get_foam_ring_texture() -> ImageTexture:
	if _foam_ring_texture == null:
		_foam_ring_texture = _build_foam_ring_texture()
	return _foam_ring_texture


static func get_droplet_texture() -> ImageTexture:
	if _droplet_texture == null:
		_droplet_texture = _build_droplet_texture()
	return _droplet_texture


# Soft elliptical water body: bright-ish core, smooth fade to transparent edge.
static func _build_surface_texture() -> ImageTexture:
	var size := SURFACE_TEXTURE_SIZE
	var data := PackedByteArray()
	data.resize(size * size * 4)
	var center: float = (float(size) - 1.0) * 0.5
	var max_dist: float = maxf(1.0, center)
	var offset := 0
	for y in range(size):
		var dy: float = (float(y) - center) / max_dist
		for x in range(size):
			var dx: float = (float(x) - center) / max_dist
			var d: float = sqrt(dx * dx + dy * dy)
			if d >= 1.0:
				_write_pixel(data, offset, 255, 255, 255, 0)
				offset += 4
				continue
			# Smooth body fill + a slightly brighter centre sheen.
			var body: float = pow(1.0 - d, 1.55) * 0.72
			var sheen: float = pow(maxf(0.0, 1.0 - d * 1.7), 3.0) * 0.30
			_write_pixel(data, offset, 255, 255, 255, _alpha_to_byte(clampf(body + sheen, 0.0, 1.0)))
			offset += 4
	return _create_texture(size, size, data)


# Caustic veins: interference of a few directional waves -> bright thin ridges,
# radially faded so it stays inside the puddle when stretched to the bbox.
static func _build_caustic_texture() -> ImageTexture:
	var size := CAUSTIC_TEXTURE_SIZE
	var data := PackedByteArray()
	data.resize(size * size * 4)
	var center: float = (float(size) - 1.0) * 0.5
	var max_dist: float = maxf(1.0, center)
	var offset := 0
	for y in range(size):
		var ny: float = float(y) / float(size)
		var dyc: float = (float(y) - center) / max_dist
		for x in range(size):
			var nx: float = float(x) / float(size)
			var dxc: float = (float(x) - center) / max_dist
			var d: float = sqrt(dxc * dxc + dyc * dyc)
			if d >= 1.0:
				_write_pixel(data, offset, 255, 255, 255, 0)
				offset += 4
				continue
			# Three rotated sine fields; their intersections form a cellular net.
			var w1: float = sin((nx * 7.0 + ny * 3.0) * TAU)
			var w2: float = sin((nx * -4.0 + ny * 6.5) * TAU + 1.7)
			var w3: float = sin((nx * 5.5 - ny * 5.0) * TAU + 3.1)
			var net: float = absf(w1 + w2 + w3) / 3.0
			# Thin bright ridges where the field is near a crest.
			var ridge: float = pow(clampf(1.0 - net * 1.9, 0.0, 1.0), 3.0)
			var fade: float = pow(maxf(0.0, 1.0 - d), 1.3)
			_write_pixel(data, offset, 255, 255, 255, _alpha_to_byte(clampf(ridge * fade, 0.0, 1.0)))
			offset += 4
	return _create_texture(size, size, data)


# Soft ring near r~0.84 for the puddle rim foam (elliptical when stretched).
static func _build_foam_ring_texture() -> ImageTexture:
	var size := FOAM_RING_TEXTURE_SIZE
	var data := PackedByteArray()
	data.resize(size * size * 4)
	var center: float = (float(size) - 1.0) * 0.5
	var max_dist: float = maxf(1.0, center)
	var ring_r := 0.84
	var offset := 0
	for y in range(size):
		var dy: float = (float(y) - center) / max_dist
		for x in range(size):
			var dx: float = (float(x) - center) / max_dist
			var d: float = sqrt(dx * dx + dy * dy)
			var ring: float = pow(clampf(1.0 - absf(d - ring_r) / 0.16, 0.0, 1.0), 2.0)
			if d >= 1.0:
				ring = 0.0
			_write_pixel(data, offset, 255, 255, 255, _alpha_to_byte(clampf(ring, 0.0, 1.0)))
			offset += 4
	return _create_texture(size, size, data)


# Small soft droplet/bubble for splash + ambient particles.
static func _build_droplet_texture() -> ImageTexture:
	var size := DROPLET_TEXTURE_SIZE
	var data := PackedByteArray()
	data.resize(size * size * 4)
	var center: float = (float(size) - 1.0) * 0.5
	var max_dist: float = maxf(1.0, center)
	var offset := 0
	for y in range(size):
		var dy: float = (float(y) - center) / max_dist
		for x in range(size):
			var dx: float = (float(x) - center) / max_dist
			var d: float = sqrt(dx * dx + dy * dy)
			if d >= 1.0:
				_write_pixel(data, offset, 255, 255, 255, 0)
				offset += 4
				continue
			var core: float = pow(maxf(0.0, 1.0 - d), 2.4) * 0.95
			var rim: float = pow(clampf(1.0 - absf(d - 0.7) / 0.3, 0.0, 1.0), 2.0) * 0.30
			_write_pixel(data, offset, 255, 255, 255, _alpha_to_byte(clampf(core + rim, 0.0, 1.0)))
			offset += 4
	return _create_texture(size, size, data)


static func _create_texture(width: int, height: int, data: PackedByteArray) -> ImageTexture:
	var image: Image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)
	return ImageTexture.create_from_image(image)


static func _write_pixel(data: PackedByteArray, offset: int, r: int, g: int, b: int, a: int) -> void:
	data[offset] = r
	data[offset + 1] = g
	data[offset + 2] = b
	data[offset + 3] = a


static func _alpha_to_byte(alpha: float) -> int:
	return int(clampf(round(alpha * 255.0), 0.0, 255.0))
