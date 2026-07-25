extends SceneTree

const ICON_BACKDROP_PATH := "res://assets/sprites/effects/mythic_acquisition/mythic_icon_backdrop.png"
const SOFT_VIGNETTE_PATH := "res://assets/sprites/effects/mythic_acquisition/mythic_soft_vignette.png"
const SOFT_WHITE_FLASH_PATH := "res://assets/sprites/effects/mythic_acquisition/mythic_soft_white_flash.png"
const FIELD_WIDTH := 760
const FIELD_HEIGHT := 750


func _init() -> void:
	var outputs := {
		ICON_BACKDROP_PATH: _build_icon_backdrop_image(),
		SOFT_VIGNETTE_PATH: _build_field_image(false),
		SOFT_WHITE_FLASH_PATH: _build_field_image(true),
	}
	for path: String in outputs:
		var image: Image = outputs[path]
		var result: int = image.save_png(path)
		if result != OK:
			_fail("PNG save failed for %s: %s" % [path, result])
			return
		print("baked %dx%d %s %s" % [image.get_width(), image.get_height(), _hash_image(image), path])
	print("bake_mythic_acquisition_raster_textures: ok")
	quit(0)


func _build_icon_backdrop_image() -> Image:
	var size := 256
	var data := PackedByteArray()
	data.resize(size * size * 4)
	var center_x := float(size) * 0.5
	var center_y := float(size) * 0.5
	var radius := float(size) * 0.5
	var red := _color_to_byte(0.012)
	var green := _color_to_byte(0.010)
	var blue := _color_to_byte(0.024)
	var offset := 0
	for y in range(size):
		for x in range(size):
			var dx := float(x) - center_x
			var dy := float(y) - center_y
			var distance := sqrt(dx * dx + dy * dy) / radius
			var alpha := clampf(1.0 - smoothstep(0.34, 1.0, distance), 0.0, 1.0)
			alpha = pow(alpha, 1.25) * 0.74
			_write_pixel(data, offset, red, green, blue, _alpha_to_byte(alpha))
			offset += 4
	return Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data)


func _build_field_image(is_white_flash: bool) -> Image:
	var data := PackedByteArray()
	data.resize(FIELD_WIDTH * FIELD_HEIGHT * 4)
	var center_x := float(FIELD_WIDTH) * 0.5
	var center_y := float(FIELD_HEIGHT) * 0.5
	var half_width := maxf(1.0, float(FIELD_WIDTH) * 0.5)
	var half_height := maxf(1.0, float(FIELD_HEIGHT) * 0.5)
	var offset := 0
	for y in range(FIELD_HEIGHT):
		var normalized_y := (float(y) - center_y) / half_height
		for x in range(FIELD_WIDTH):
			var normalized_x := (float(x) - center_x) / half_width
			var distance := sqrt(normalized_x * normalized_x + normalized_y * normalized_y)
			var alpha: float
			if is_white_flash:
				alpha = 1.0 - smoothstep(0.54, 1.0, distance)
				alpha = pow(clampf(alpha, 0.0, 1.0), 0.58)
				_write_pixel(data, offset, 255, 255, 255, _alpha_to_byte(alpha))
			else:
				alpha = 1.0 - smoothstep(0.62, 1.0, distance)
				alpha = pow(clampf(alpha, 0.0, 1.0), 0.92) * 0.78
				_write_pixel(data, offset, 0, 0, 0, _alpha_to_byte(alpha))
			offset += 4
	return Image.create_from_data(FIELD_WIDTH, FIELD_HEIGHT, false, Image.FORMAT_RGBA8, data)


func _write_pixel(data: PackedByteArray, offset: int, red: int, green: int, blue: int, alpha: int) -> void:
	data[offset] = red
	data[offset + 1] = green
	data[offset + 2] = blue
	data[offset + 3] = alpha


func _alpha_to_byte(alpha: float) -> int:
	return int(clampf(roundf(alpha * 255.0), 0.0, 255.0))


func _color_to_byte(channel: float) -> int:
	return int(clampf(roundf(channel * 255.0), 0.0, 255.0))


func _hash_image(image: Image) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(image.get_data())
	return hashing.finish().hex_encode().to_upper()


func _fail(message: String) -> void:
	push_error("bake_mythic_acquisition_raster_textures: %s" % message)
	quit(1)
