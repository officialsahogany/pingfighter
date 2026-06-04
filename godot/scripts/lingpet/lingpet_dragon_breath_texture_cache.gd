extends RefCounted

# Procedural texture pieces for the Red Dragon "Dragon Breath" modular VFX.
#
# Piece ②/③ of the 3-piece modular VFX layering (static texture + runtime
# shader / tween motion). Only the directional flame-tongue is bespoke here; the
# soft radial glow and the starburst hit-flash reuse the shared
# `ImpactFlareTextureCache` so we do not duplicate those families.
#
# All RGB is left white so the draw call can tint the piece to any heat color
# with an additive modulate; the alpha channel carries the flame silhouette.

const FLAME_TONGUE_SIZE := 64
const EMBER_SIZE := 48

static var _flame_tongue_texture: ImageTexture = null
static var _ember_texture: ImageTexture = null


static func prewarm() -> void:
	while not prewarm_step():
		pass


# One texture per call so the boot prewarm can spread the builds across frames.
static func prewarm_step() -> bool:
	if _flame_tongue_texture == null:
		get_flame_tongue_texture()
		return false
	if _ember_texture == null:
		get_ember_texture()
		return false
	return true


static func get_flame_tongue_texture() -> ImageTexture:
	if _flame_tongue_texture != null:
		return _flame_tongue_texture
	_flame_tongue_texture = _build_flame_tongue_texture()
	return _flame_tongue_texture


static func get_ember_texture() -> ImageTexture:
	if _ember_texture != null:
		return _ember_texture
	_ember_texture = _build_ember_texture()
	return _ember_texture


# Directional flame lick: pointed soft tip at the top (v=0), fat rounded belly
# around 65% down, tapering back to a soft base. Drawn rotated so the tip leads
# the travel direction.
static func _build_flame_tongue_texture() -> ImageTexture:
	var data := PackedByteArray()
	data.resize(FLAME_TONGUE_SIZE * FLAME_TONGUE_SIZE * 4)
	var center_x: float = (float(FLAME_TONGUE_SIZE) - 1.0) * 0.5
	var offset := 0
	for y in range(FLAME_TONGUE_SIZE):
		var ny: float = float(y) / float(FLAME_TONGUE_SIZE - 1)  # 0 top (tip) .. 1 base
		# Half-width envelope: ~0 at the tip, swelling to a belly skewed toward
		# the base, then tapering so the base reads rounded rather than chopped.
		var half_w: float = pow(clamp(ny + 0.02, 0.0, 1.0), 0.55) * pow(clamp(1.05 - ny * 0.65, 0.0, 1.0), 1.25)
		half_w = max(0.015, half_w)
		# Soft vertical fade so the tip and the very base both feather out.
		var vert: float = pow(clamp(ny + 0.06, 0.0, 1.0), 0.42) * pow(clamp(1.08 - ny, 0.0, 1.0), 0.7)
		for x in range(FLAME_TONGUE_SIZE):
			var nx: float = (float(x) - center_x) / center_x  # -1 .. 1
			var edge: float = clamp(1.0 - abs(nx) / half_w, 0.0, 1.0)
			var cross: float = pow(edge, 1.7)
			var core: float = pow(edge, 4.5) * clamp(ny * 1.3, 0.0, 1.0)
			var alpha: float = clamp(cross * vert * 0.85 + core * 0.45, 0.0, 1.0)
			_write_pixel(data, offset, 255, 255, 255, _alpha_to_byte(alpha))
			offset += 4
	return _create_texture(FLAME_TONGUE_SIZE, FLAME_TONGUE_SIZE, data)


# Soft round ember/glow blob with a bright tight core, used for spark motes and
# under-glows. Reuses the same falloff family as the shared impact glow but at a
# tighter core so additive stacking does not wash out.
static func _build_ember_texture() -> ImageTexture:
	var data := PackedByteArray()
	data.resize(EMBER_SIZE * EMBER_SIZE * 4)
	var center_coord: float = (float(EMBER_SIZE) - 1.0) * 0.5
	var max_dist: float = max(1.0, center_coord)
	var offset := 0
	for y in range(EMBER_SIZE):
		var dy: float = float(y) - center_coord
		for x in range(EMBER_SIZE):
			var dx: float = float(x) - center_coord
			var t: float = clamp(sqrt(dx * dx + dy * dy) / max_dist, 0.0, 1.0)
			var core: float = pow(max(0.0, 1.0 - t * 1.7), 3.0) * 0.95
			var halo: float = pow(max(0.0, 1.0 - t), 1.6) * 0.22
			_write_pixel(data, offset, 255, 255, 255, _alpha_to_byte(clamp(core + halo, 0.0, 1.0)))
			offset += 4
	return _create_texture(EMBER_SIZE, EMBER_SIZE, data)


static func _create_texture(width: int, height: int, data: PackedByteArray) -> ImageTexture:
	var image: Image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)
	return ImageTexture.create_from_image(image)


static func _write_pixel(data: PackedByteArray, offset: int, r: int, g: int, b: int, a: int) -> void:
	data[offset] = r
	data[offset + 1] = g
	data[offset + 2] = b
	data[offset + 3] = a


static func _alpha_to_byte(alpha: float) -> int:
	return int(clamp(round(alpha * 255.0), 0.0, 255.0))
