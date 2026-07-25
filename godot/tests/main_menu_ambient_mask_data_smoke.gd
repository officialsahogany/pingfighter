extends SceneTree

const MainMenuAmbientMaskData := preload("res://scripts/ui/main_menu_ambient_mask_data.gd")
const MainMenuAmbientProjection := preload("res://scripts/ui/main_menu_ambient_projection.gd")
const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")
const BakedMaskData: MainMenuAmbientMaskData = preload("res://assets/ui/main_menu/main_menu_ambient_masks.res")

var _failures: Array[String] = []


func _init() -> void:
	_verify_baked_resource()
	_verify_runtime_has_no_image_scan()
	if _failures.is_empty():
		print("main_menu_ambient_mask_data_smoke: ok letter_on=%d orb_on=%d" % [BakedMaskData.letter_mask.count(1), BakedMaskData.orb_mask.count(1)])
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_baked_resource() -> void:
	_expect(FileAccess.file_exists("res://assets/ui/main_menu/main_menu_ambient_masks.res"), "baked ambient mask resource should ship")
	_expect(BakedMaskData != null, "baked ambient mask resource should load")
	if BakedMaskData == null:
		return
	_expect(BakedMaskData.is_valid_for(MainMenuAmbientProjection.LOGO_LETTER_MASK_RECT, MainMenuAmbientProjection.LOGO_ORB_MASK_RECT), "baked ambient mask resource should match current schema and geometry")
	_expect(BakedMaskData.letter_mask.size() == 127890, "letter mask should retain 1015x126 pixels")
	_expect(BakedMaskData.orb_mask.size() == 88350, "orb mask should retain 285x310 pixels")
	_expect(BakedMaskData.letter_mask.count(1) == 29480, "letter mask should preserve the accepted classified-pixel set")
	_expect(BakedMaskData.orb_mask.count(1) == 15372, "orb mask should preserve the accepted classified-pixel set")


func _verify_runtime_has_no_image_scan() -> void:
	var ambient_source := FileAccess.get_file_as_string("res://scripts/ui/main_menu_ambient.gd")
	var baker_source := FileAccess.get_file_as_string("res://tools/bake_main_menu_ambient_masks.gd")
	var build_body := SourceContractFunctionBody.extract(ambient_source, "func _build_logo_letter_mask(")
	_expect(build_body.find("BAKED_MASK_DATA.is_valid_for") >= 0, "runtime mask setup should validate the baked resource")
	_expect(build_body.find("letter_mask.duplicate()") >= 0 and build_body.find("orb_mask.duplicate()") >= 0, "runtime mask setup should copy baked byte arrays")
	_expect(ambient_source.find("get_image()") < 0 and ambient_source.find("get_pixel(") < 0, "runtime ambient should not copy or scan source images")
	_expect(ambient_source.find("ProjectResourceLoader") < 0, "runtime ambient should not retain the old source-texture mask loader")
	_expect(baker_source.find("get_image()") >= 0 and baker_source.find("get_pixel(") >= 0, "offline baker should retain source-image classification")
	_expect(baker_source.find("ResourceSaver.save") >= 0, "offline baker should save the export-safe resource")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
