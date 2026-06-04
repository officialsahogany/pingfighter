extends RefCounted

# Procedural luminance texture fragments for the "잔광 유출 / Afterglow Leak"
# resonance-fluid VFX. Same architecture as HydroPuddleTextureCache: static lazy
# ImageTexture cache + PackedByteArray pixel builders. Every texture is baked
# WHITE (RGB 255) with luminance encoded in alpha, so the consumer tints to the
# green-gold "공명 유체" palette at draw time via the draw_texture_rect modulate.
#
# Radial pieces (glow / body / caustic / rim / droplet) are radially alpha-faded
# squares: blitting them stretched into a wide bounding box yields an ELLIPSE for
# free (a radial fade stretched to a w!=h rect reads as an ellipse) -- no per
# primitive masking or draw_set_transform needed (immediate-mode friendly, see
# the draw_set_transform trap rule).
#
# The caustic texture is built to tile-scroll: blit it at a time-animated source
# offset (draw_texture_rect_region) to fake flowing light-veins without a GPU
# shader. Layer two scrolls in opposite directions for a "living light" shimmer.
#
# The streak texture is ANISOTROPIC (a vertical rivulet): a soft bright vertical
# band that tapers toward the bottom tip, used for the liquid "흘러내림" running
# down from the burst point to the floor pool.

const GLOW_TEXTURE_SIZE := 128
const BODY_TEXTURE_SIZE := 128
const CAUSTIC_TEXTURE_SIZE := 192
const RIM_TEXTURE_SIZE := 160
const DROPLET_TEXTURE_SIZE := 48
const STREAK_TEXTURE_SIZE := 64

static var _glow_texture: ImageTexture = null
static var _body_texture: ImageTexture = null
static var _caustic_texture: ImageTexture = null
static var _rim_texture: ImageTexture = null
static var _droplet_texture: ImageTexture = null
static var _streak_texture: ImageTexture = null


static func prewarm() -> void:
	get_glow_texture()
	get_body_texture()
	get_caustic_texture()
	get_rim_texture()
	get_droplet_texture()
	get_streak_texture()


static func get_glow_texture() -> ImageTexture:
	if _glow_texture == null:
		_glow_texture = _build_glow_texture()
	return _glow_texture


static func get_body_texture() -> ImageTexture:
	if _body_texture == null:
		_body_texture = _build_body_texture()
	return _body_texture


static func get_caustic_texture() -> ImageTexture:
	if _caustic_texture == null:
		_caustic_texture = _build_caustic_texture()
	return _caustic_texture


static func get_rim_texture() -> ImageTexture:
	if _rim_texture == null:
		_rim_texture = _build_rim_texture()
	return _rim_texture


static func get_droplet_texture() -> ImageTexture:
	if _droplet_texture == null:
		_droplet_texture = _build_droplet_texture()
	return _droplet_texture


static func get_streak_texture() -> ImageTexture:
	if _streak_texture == null:
		_streak_texture = _build_streak_texture()
	return _streak_texture


# Wide, very soft bloom halo for the ambient luminance around the fluid.
static func _build_glow_texture() -> ImageTexture:
	var size := GLOW_TEXTURE_SIZE
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
			var halo: float = pow(1.0 - d, 2.2) * 0.85
			_write_pixel(data, offset, 255, 255, 255, _alpha_to_byte(clampf(halo, 0.0, 1.0)))
			offset += 4
	return _create_texture(size, size, data)


# Luminous fluid body: smooth gel fill plus a hot, tight central sheen so the
# pool reads as "light itself" rather than a flat translucent disc.
static func _build_body_texture() -> ImageTexture:
	var size := BODY_TEXTURE_SIZE
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
			var body: float = pow(1.0 - d, 1.45) * 0.74
			var sheen: float = pow(maxf(0.0, 1.0 - d * 1.85), 3.2) * 0.48
			_write_pixel(data, offset, 255, 255, 255, _alpha_to_byte(clampf(body + sheen, 0.0, 1.0)))
			offset += 4
	return _create_texture(size, size, data)


# Caustic light-veins: interference of a few directional waves -> bright thin
# ridges, radially faded so they stay inside the fluid when stretched.
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
			var w1: float = sin((nx * 6.5 + ny * 3.4) * TAU)
			var w2: float = sin((nx * -4.2 + ny * 6.8) * TAU + 1.7)
			var w3: float = sin((nx * 5.7 - ny * 4.6) * TAU + 3.1)
			var net: float = absf(w1 + w2 + w3) / 3.0
			var ridge: float = pow(clampf(1.0 - net * 1.85, 0.0, 1.0), 3.0)
			var fade: float = pow(maxf(0.0, 1.0 - d), 1.25)
			_write_pixel(data, offset, 255, 255, 255, _alpha_to_byte(clampf(ridge * fade, 0.0, 1.0)))
			offset += 4
	return _create_texture(size, size, data)


# Surface-tension meniscus ring near r~0.86 (elliptical when stretched).
static func _build_rim_texture() -> ImageTexture:
	var size := RIM_TEXTURE_SIZE
	var data := PackedByteArray()
	data.resize(size * size * 4)
	var center: float = (float(size) - 1.0) * 0.5
	var max_dist: float = maxf(1.0, center)
	var ring_r := 0.86
	var offset := 0
	for y in range(size):
		var dy: float = (float(y) - center) / max_dist
		for x in range(size):
			var dx: float = (float(x) - center) / max_dist
			var d: float = sqrt(dx * dx + dy * dy)
			var ring: float = pow(clampf(1.0 - absf(d - ring_r) / 0.13, 0.0, 1.0), 2.0)
			if d >= 1.0:
				ring = 0.0
			_write_pixel(data, offset, 255, 255, 255, _alpha_to_byte(clampf(ring, 0.0, 1.0)))
			offset += 4
	return _create_texture(size, size, data)


# Small luminous droplet/bead for the burst spray + ambient surface motes.
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
			var core: float = pow(maxf(0.0, 1.0 - d), 2.2) * 0.98
			var rim: float = pow(clampf(1.0 - absf(d - 0.68) / 0.3, 0.0, 1.0), 2.0) * 0.28
			_write_pixel(data, offset, 255, 255, 255, _alpha_to_byte(clampf(core + rim, 0.0, 1.0)))
			offset += 4
	return _create_texture(size, size, data)


# Vertical rivulet: a soft bright band down the centre that tapers to a rounded
# tip at the bottom and fades in at the top. Used for the running-down "흘러내림"
# columns connecting the burst point to the floor pool.
static func _build_streak_texture() -> ImageTexture:
	var size := STREAK_TEXTURE_SIZE
	var data := PackedByteArray()
	data.resize(size * size * 4)
	var offset := 0
	for y in range(size):
		var ny: float = float(y) / float(size - 1)
		# Fade in at the very top, full body through the middle, round the bottom
		# tip off so the leading head reads as a falling bead of liquid.
		var top_in: float = clampf(ny / 0.16, 0.0, 1.0)
		var tip: float = 1.0 - clampf((ny - 0.82) / 0.18, 0.0, 1.0) * 0.55
		var v_env: float = top_in * tip
		# Narrow the band toward the tip so the rivulet looks like it is running.
		var half_w: float = 0.5 * (1.0 - 0.34 * ny)
		for x in range(size):
			var nx: float = float(x) / float(size - 1)
			var dxn: float = absf(nx - 0.5) / maxf(0.01, half_w)
			if dxn >= 1.0:
				_write_pixel(data, offset, 255, 255, 255, 0)
				offset += 4
				continue
			var h_band: float = pow(1.0 - dxn, 1.7)
			var core: float = pow(maxf(0.0, 1.0 - dxn * 2.4), 2.0) * 0.4
			_write_pixel(data, offset, 255, 255, 255, _alpha_to_byte(clampf((h_band + core) * v_env, 0.0, 1.0)))
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
