extends SceneTree

const Cinematic := preload("res://scripts/items/mythic_item_acquisition_cinematic_v2.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const ASSET_SPECS := [
	{
		"path": "res://assets/sprites/effects/mythic_acquisition/mythic_icon_backdrop.png",
		"size": Vector2i(256, 256),
		"hash": "18B9B2E48C74A95593E9ACD845CDB73DBACC0BC401B2AEAFE8FFDF672BDC5B77",
	},
	{
		"path": "res://assets/sprites/effects/mythic_acquisition/mythic_soft_vignette.png",
		"size": Vector2i(760, 750),
		"hash": "8EA3CDABBC902B4A908211BD764E82CF5AE4C9F7EB8431215F2D921CC872E314",
	},
	{
		"path": "res://assets/sprites/effects/mythic_acquisition/mythic_soft_white_flash.png",
		"size": Vector2i(760, 750),
		"hash": "53794A124FB7D896706595372FACA98D66988659579CA37CEAF595DCF65F32DB",
	},
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_baked_assets()
	await _verify_staged_prewarm()
	_verify_runtime_has_no_rasterization()
	_clear_runtime_caches()
	if _failures.is_empty():
		print("mythic_item_acquisition_raster_assets_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_baked_assets() -> void:
	for spec: Dictionary in ASSET_SPECS:
		var path := str(spec.get("path", ""))
		_expect(FileAccess.file_exists(path), "baked cinematic PNG should ship: %s" % path)
		_expect(ResourceLoader.exists(path, "Texture2D"), "baked cinematic raster should load as Texture2D: %s" % path)
		var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
		_expect(texture != null, "baked cinematic raster should resolve: %s" % path)
		if texture == null:
			continue
		var image := texture.get_image()
		_expect(image != null and not image.is_empty(), "baked cinematic raster should contain image data: %s" % path)
		if image == null or image.is_empty():
			continue
		_expect(Vector2i(image.get_width(), image.get_height()) == spec.get("size", Vector2i.ZERO), "baked cinematic raster size should remain exact: %s" % path)
		_expect(_hash_image(image) == str(spec.get("hash", "")), "baked cinematic raster RGBA bytes should match the former runtime generator: %s" % path)


func _verify_staged_prewarm() -> void:
	_clear_runtime_caches()
	var completed := false
	for _step in range(180):
		if Cinematic.prewarm_assets_step():
			completed = true
			break
		await process_frame
	_expect(completed, "staged cinematic prewarm should finish with baked raster assets")
	for spec: Dictionary in ASSET_SPECS:
		var path := str(spec.get("path", ""))
		var cached_texture := ProjectResourceLoader.get_cached_texture(path)
		_expect(cached_texture != null, "staged prewarm should cache baked cinematic raster: %s" % path)
		if cached_texture != null:
			_expect(_hash_image(cached_texture.get_image()) == str(spec.get("hash", "")), "staged imported texture should preserve baked RGBA bytes: %s" % path)


func _verify_runtime_has_no_rasterization() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_acquisition_cinematic_v2.gd")
	var baker_source := FileAccess.get_file_as_string("res://tools/bake_mythic_acquisition_raster_textures.gd")
	_expect(runtime_source.find("Image.create_from_data") < 0, "runtime cinematic should not allocate raster images")
	_expect(runtime_source.find("ImageTexture.create_from_image") < 0, "runtime cinematic should not upload generated raster textures")
	_expect(runtime_source.find("PackedByteArray") < 0, "runtime cinematic should not allocate procedural raster buffers")
	_expect(runtime_source.find("_write_pixel") < 0, "runtime cinematic should not rasterize pixels")
	_expect(runtime_source.find("_load_baked_texture(ICON_BACKDROP_TEXTURE_PATH)") >= 0, "runtime icon backdrop facade should load the baked resource")
	_expect(runtime_source.find("_load_baked_texture(SOFT_VIGNETTE_TEXTURE_PATH)") >= 0, "runtime vignette facade should load the baked resource")
	_expect(runtime_source.find("_load_baked_texture(SOFT_WHITE_FLASH_TEXTURE_PATH)") >= 0, "runtime white-flash facade should load the baked resource")
	_expect(baker_source.find("Image.create_from_data") >= 0 and baker_source.find("save_png") >= 0, "offline baker should own rasterization and PNG saving")


func _clear_runtime_caches() -> void:
	Cinematic.reset_for_test()
	ProjectResourceLoader.clear_caches()


func _hash_image(image: Image) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(image.get_data())
	return hashing.finish().hex_encode().to_upper()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
