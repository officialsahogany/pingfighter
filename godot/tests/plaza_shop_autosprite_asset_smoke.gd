extends SceneTree

const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")

const STREWN_KINDS := [
	"money_bundle",
	"coin_pile",
	"gear",
	"wrench_tool",
	"data_cube",
	"circuit_gadget",
]

var _failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	_verify_loader_paths()
	_verify_static_cutouts()
	_verify_animation_atlases()
	if _failures.is_empty():
		print("plaza_shop_autosprite_asset_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_loader_paths() -> void:
	var paths := PlazaAssetLoader.get_interior_object_texture_paths_for_test()
	for kind in STREWN_KINDS:
		_expect(paths.has(kind), "loader should expose static strewn path for %s" % kind)
		_expect(paths.has("%s_anim" % kind), "loader should expose AutoSprite sheet path for %s" % kind)
		_expect(ResourceLoader.exists(str(paths.get(kind, ""))), "static strewn texture should exist for %s" % kind)
		_expect(ResourceLoader.exists(str(paths.get("%s_anim" % kind, ""))), "AutoSprite sheet texture should exist for %s" % kind)


func _verify_static_cutouts() -> void:
	for kind in STREWN_KINDS:
		var image := _load_image("res://assets/ui/plaza/interior/plaza_shop_strewn_%s_autosprite_static_v1.png" % kind)
		_expect(image != null, "static cutout image should load for %s" % kind)
		if image == null:
			continue
		_expect(image.get_width() == 1024 and image.get_height() == 1024, "static cutout should keep 1024 source size for %s" % kind)
		_expect(image.get_pixel(0, 0).a < 0.05, "static cutout should have transparent border for %s" % kind)
		_expect(_count_visible_samples(image) >= 8, "static cutout should have visible nonblank samples for %s" % kind)


func _verify_animation_atlases() -> void:
	for kind in STREWN_KINDS:
		var atlas_path := "res://assets/ui/plaza/interior/plaza_shop_strewn_%s_autosprite_atlas_v1.json" % kind
		var manifest_path := "res://assets/ui/plaza/interior/plaza_shop_strewn_%s_autosprite_anim_manifest_v1.json" % kind
		var atlas := _load_json(atlas_path)
		var manifest := _load_json(manifest_path)
		_expect(not atlas.is_empty(), "AutoSprite atlas should parse for %s" % kind)
		_expect(not manifest.is_empty(), "AutoSprite runtime manifest should parse for %s" % kind)
		if atlas.is_empty() or manifest.is_empty():
			continue
		var frames: Variant = atlas.get("frames", {})
		_expect(frames is Dictionary and (frames as Dictionary).size() == 25, "AutoSprite atlas should contain 25 frames for %s" % kind)
		var meta: Variant = atlas.get("meta", {})
		var size: Variant = (meta as Dictionary).get("size", {}) if meta is Dictionary else {}
		var frame_size: Variant = (meta as Dictionary).get("frame_size", {}) if meta is Dictionary else {}
		_expect(size is Dictionary and int((size as Dictionary).get("w", 0)) == 2560 and int((size as Dictionary).get("h", 0)) == 2560, "AutoSprite sheet should be 5x5 512 cells for %s" % kind)
		_expect(frame_size is Dictionary and int((frame_size as Dictionary).get("w", 0)) == 512 and int((frame_size as Dictionary).get("h", 0)) == 512, "AutoSprite frame size should be 512 for %s" % kind)
		_expect(int(manifest.get("cols", 0)) == 5 and int(manifest.get("rows", 0)) == 5 and int(manifest.get("frame_count", 0)) == 25, "runtime manifest should match 5x5/25 for %s" % kind)


func _load_image(path: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _count_visible_samples(image: Image) -> int:
	var lit_samples := 0
	var step_y: int = max(1, int(image.get_height() / 16))
	var step_x: int = max(1, int(image.get_width() / 16))
	for y in range(0, image.get_height(), step_y):
		for x in range(0, image.get_width(), step_x):
			var color := image.get_pixel(x, y)
			if color.a > 0.05 and color.r + color.g + color.b > 0.20:
				lit_samples += 1
	return lit_samples


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
