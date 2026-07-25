extends SceneTree

const BakedVignette: ImageTexture = preload("res://assets/ui/main_menu/main_menu_ambient_vignette.res")
const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_baked_texture()
	_verify_runtime_has_no_vignette_rasterization()
	if _failures.is_empty():
		print("main_menu_ambient_vignette_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_baked_texture() -> void:
	_expect(FileAccess.file_exists("res://assets/ui/main_menu/main_menu_ambient_vignette.res"), "baked ambient vignette should ship")
	_expect(BakedVignette != null, "baked ambient vignette should load")
	if BakedVignette == null:
		return
	_expect(BakedVignette.get_size() == Vector2(256.0, 256.0), "baked ambient vignette should remain 256x256")
	var image := BakedVignette.get_image()
	_expect(image != null and not image.is_empty(), "baked ambient vignette should contain image data")
	if image == null or image.is_empty():
		return
	var center_alpha := image.get_pixel(128, 128).a
	var corner_alpha := image.get_pixel(0, 0).a
	_expect(center_alpha <= 1.0 / 255.0, "vignette center should remain transparent")
	_expect(corner_alpha >= 0.98, "vignette corners should remain opaque before draw modulation")
	_expect(is_equal_approx(image.get_pixel(0, 0).a, image.get_pixel(255, 255).a), "vignette should remain diagonally symmetric")
	_expect(is_equal_approx(image.get_pixel(32, 128).a, image.get_pixel(223, 128).a), "vignette should remain horizontally symmetric")


func _verify_runtime_has_no_vignette_rasterization() -> void:
	var ambient_source := FileAccess.get_file_as_string("res://scripts/ui/main_menu_ambient.gd")
	var baker_source := FileAccess.get_file_as_string("res://tools/bake_main_menu_ambient_vignette.gd")
	var build_body := SourceContractFunctionBody.extract(ambient_source, "func _build_vignette_texture(")
	_expect(build_body.find("return BAKED_VIGNETTE_TEXTURE") >= 0, "runtime vignette facade should return the baked texture")
	_expect(ambient_source.find("Image.create(") < 0, "runtime ambient should not allocate a vignette Image")
	_expect(ambient_source.find("ImageTexture.create_from_image") < 0, "runtime ambient should not upload a generated vignette texture")
	_expect(ambient_source.find("set_pixel(") < 0, "runtime ambient should not rasterize vignette pixels")
	_expect(baker_source.find("Image.create(") >= 0 and baker_source.find("set_pixel(") >= 0, "offline baker should own vignette rasterization")
	_expect(baker_source.find("ResourceSaver.save") >= 0, "offline baker should save the export-safe vignette resource")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
