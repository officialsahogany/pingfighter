extends SceneTree

const SheetGeometry := preload("res://scripts/ui/character_live_preview_sheet_geometry.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_rect_parsing_and_mapping()
	_verify_fit_and_scale_geometry()
	_verify_alpha_trim_sampling()
	_verify_live_preview_delegation()
	if _failures.is_empty():
		print("character_live_preview_sheet_geometry_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_rect_parsing_and_mapping() -> void:
	var expected := Rect2(4.0, 6.0, 20.0, 30.0)
	_expect(SheetGeometry.parse_rect(expected) == expected, "Rect2 trim metadata should pass through")
	_expect(SheetGeometry.parse_rect({"x": 4, "y": 6, "w": 20, "h": 30}) == expected, "dictionary trim metadata should normalize")
	_expect(SheetGeometry.parse_rect([4, 6, 20, 30]) == expected, "array trim metadata should normalize")
	var source := Rect2(100.0, 200.0, 400.0, 300.0)
	var normalized := Rect2(0.25, 0.20, 0.50, 0.40)
	var source_region := SheetGeometry.normalized_rect_to_source(source, normalized)
	_expect(source_region == Rect2(200.0, 260.0, 200.0, 120.0), "normalized source regions should preserve source offsets")
	var target_region := SheetGeometry.source_subrect_to_target(source, Rect2(10.0, 20.0, 800.0, 600.0), source_region)
	_expect(target_region == Rect2(210.0, 140.0, 400.0, 240.0), "source subrects should map proportionally into target space")
	_expect(SheetGeometry.apply_relative_trim(source, expected) == Rect2(104.0, 206.0, 20.0, 30.0), "relative trim should offset the active sheet cell")


func _verify_fit_and_scale_geometry() -> void:
	var target := Rect2(10.0, 20.0, 200.0, 200.0)
	var fit := SheetGeometry.fit_region_rect(Vector2(400.0, 200.0), target)
	_expect(fit == Rect2(10.0, 70.0, 200.0, 100.0), "fit geometry should letterbox while preserving aspect ratio")
	var stretched := SheetGeometry.live2d_stage_fit_rect(Vector2(400.0, 200.0), target, 1.5)
	_expect(stretched == Rect2(10.0, 20.0, 200.0, 150.0), "stage Y scaling should preserve the fitted bottom edge")
	_expect(SheetGeometry.scale_rect(Rect2(10.0, 20.0, 40.0, 60.0), 2.0) == Rect2(-10.0, -10.0, 80.0, 120.0), "center scaling should preserve the rectangle center")


func _verify_alpha_trim_sampling() -> void:
	var image := Image.create(80, 40, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	_fill_opaque_rect(image, Rect2i(10, 8, 4, 5))
	_fill_opaque_rect(image, Rect2i(60, 12, 3, 4))
	var trim := SheetGeometry.build_alpha_trim_rect(image, Vector2(80.0, 40.0), 2, 1, 2, 2, 0.0)
	_expect(trim == Rect2(4.0, 2.0, 25.0, 20.0), "alpha trim should union local bounds across sampled frames and apply minimum padding")
	var first_only := SheetGeometry.build_alpha_trim_rect(image, Vector2(80.0, 40.0), 2, 1, 2, 1, 0.0)
	_expect(first_only == Rect2(4.0, 2.0, 16.0, 17.0), "sample limit should deterministically select the first frame when limited to one")
	var empty_image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	empty_image.fill(Color.TRANSPARENT)
	_expect(SheetGeometry.build_alpha_trim_rect(empty_image, Vector2(16.0, 16.0), 1, 1, 1, 1, 0.0) == Rect2(), "fully transparent sheets should not publish a trim rect")


func _verify_live_preview_delegation() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/character_live_preview.gd")
	_expect(source.find("CharacterLivePreviewSheetGeometry.parse_rect") >= 0, "live preview should delegate explicit trim parsing")
	_expect(source.find("CharacterLivePreviewSheetGeometry.build_alpha_trim_rect") >= 0, "live preview should delegate alpha trim sampling")
	_expect(source.find("CharacterLivePreviewSheetGeometry.normalized_rect_to_source") >= 0, "live preview should delegate source projection")
	_expect(source.find("CharacterLivePreviewSheetGeometry.live2d_stage_fit_rect") >= 0, "live preview should delegate stage-fit geometry")


func _fill_opaque_rect(image: Image, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			image.set_pixel(x, y, Color.WHITE)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
