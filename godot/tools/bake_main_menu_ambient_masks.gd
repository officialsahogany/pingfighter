extends SceneTree

const MainMenuAmbientMaskData := preload("res://scripts/ui/main_menu_ambient_mask_data.gd")
const MainMenuAmbientProjection := preload("res://scripts/ui/main_menu_ambient_projection.gd")

const LOGO_BACKGROUND_PATH := "res://assets/ui/main_menu/lingpia_main_menu_bg_logo.png"
const LOGO_NO_BACKGROUND_PATH := "res://assets/ui/main_menu/lingpia_main_menu_bg_no_logo.png"
const OUTPUT_PATH := "res://assets/ui/main_menu/main_menu_ambient_masks.res"


func _init() -> void:
	var logo_image := _load_source_image(LOGO_BACKGROUND_PATH)
	var base_image := _load_source_image(LOGO_NO_BACKGROUND_PATH)
	if logo_image == null or base_image == null or logo_image.is_empty() or base_image.is_empty():
		_fail("could not load source images")
		return
	if logo_image.get_size() != base_image.get_size():
		_fail("source image sizes differ")
		return
	var data := MainMenuAmbientMaskData.new()
	data.source_image_size = logo_image.get_size()
	data.letter_mask_rect = MainMenuAmbientProjection.LOGO_LETTER_MASK_RECT
	data.orb_mask_rect = MainMenuAmbientProjection.LOGO_ORB_MASK_RECT
	data.letter_mask = _build_letter_mask(logo_image, base_image, data.letter_mask_rect)
	data.orb_mask = _build_orb_mask(logo_image, base_image, data.orb_mask_rect)
	if not data.is_valid_for(data.letter_mask_rect, data.orb_mask_rect):
		_fail("generated mask resource failed validation")
		return
	var result := ResourceSaver.save(data, OUTPUT_PATH)
	if result != OK:
		_fail("ResourceSaver failed: %s" % result)
		return
	print("bake_main_menu_ambient_masks: ok letter=%d orb=%d output=%s" % [data.letter_mask.size(), data.orb_mask.size(), OUTPUT_PATH])
	quit(0)


func _load_source_image(path: String) -> Image:
	var texture := load(path) as Texture2D
	if texture == null:
		return null
	var image := texture.get_image()
	if image != null and image.is_compressed():
		image.decompress()
	return image


func _build_letter_mask(logo_image: Image, base_image: Image, rect: Rect2i) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(rect.size.x * rect.size.y)
	var write_index := 0
	for y in rect.size.y:
		var source_y := rect.position.y + y
		for x in rect.size.x:
			var source_x := rect.position.x + x
			var source_pos := Vector2(source_x, source_y)
			var is_letter := (
				MainMenuAmbientProjection.is_source_point_inside_logo_word(source_pos)
				and MainMenuAmbientProjection.is_logo_letter_color(
					logo_image.get_pixel(source_x, source_y),
					base_image.get_pixel(source_x, source_y)
				)
			)
			mask[write_index] = 1 if is_letter else 0
			write_index += 1
	return mask


func _build_orb_mask(logo_image: Image, base_image: Image, rect: Rect2i) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(rect.size.x * rect.size.y)
	var write_index := 0
	for y in rect.size.y:
		var source_y := rect.position.y + y
		for x in rect.size.x:
			var source_x := rect.position.x + x
			var source_pos := Vector2(source_x, source_y)
			mask[write_index] = 1 if MainMenuAmbientProjection.is_logo_orb_effect_color(
				logo_image.get_pixel(source_x, source_y),
				base_image.get_pixel(source_x, source_y),
				source_pos
			) else 0
			write_index += 1
	return mask


func _fail(message: String) -> void:
	push_error("bake_main_menu_ambient_masks: %s" % message)
	quit(1)
