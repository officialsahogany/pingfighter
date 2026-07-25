extends SceneTree

const OUTPUT_PATH := "res://assets/ui/main_menu/main_menu_ambient_vignette.res"
const TEXTURE_SIZE := 256
const FALLOFF_START := 0.45


func _init() -> void:
	var image := _build_vignette_image()
	var texture := ImageTexture.create_from_image(image)
	if texture == null:
		_fail("ImageTexture creation failed")
		return
	var result := ResourceSaver.save(texture, OUTPUT_PATH)
	if result != OK:
		_fail("ResourceSaver failed: %s" % result)
		return
	print("bake_main_menu_ambient_vignette: ok size=%dx%d output=%s" % [TEXTURE_SIZE, TEXTURE_SIZE, OUTPUT_PATH])
	quit(0)


func _build_vignette_image() -> Image:
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := float(TEXTURE_SIZE) * 0.5
	var max_dist := sqrt(center * center + center * center)
	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var dx := float(x) + 0.5 - center
			var dy := float(y) + 0.5 - center
			var distance := sqrt(dx * dx + dy * dy) / max_dist
			var amount := clampf((distance - FALLOFF_START) / (1.0 - FALLOFF_START), 0.0, 1.0)
			amount = amount * amount * (3.0 - 2.0 * amount)
			image.set_pixel(x, y, Color(0.0, 0.0, 0.0, amount))
	return image


func _fail(message: String) -> void:
	push_error("bake_main_menu_ambient_vignette: %s" % message)
	quit(1)
