extends SceneTree

const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")
const Stage3PlayfieldTextureCache := preload("res://scripts/stages/stage3/stage3_playfield_texture_cache.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_checker_texture_and_capacity()
	_verify_border_texture()
	_verify_playfield_single_owner_contract()
	if _failures.is_empty():
		print("stage3_playfield_texture_cache_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_checker_texture_and_capacity() -> void:
	var cache := Stage3PlayfieldTextureCache.new()
	var texture := cache.get_checker_texture(103, 77, 0)
	_expect(texture != null, "checker cache should build a texture")
	_expect(texture == cache.get_checker_texture(103, 77, 3), "wrapped emotional phase should reuse the canonical checker texture")
	var image := texture.get_image()
	_expect(image.get_width() == 103 and image.get_height() == 77, "checker texture should preserve requested dimensions")
	_expect(image.get_pixel(10, 10).is_equal_approx(Stage3PlayfieldTextureCache.get_checker_base_color_for_phase(0)), "checker base tile should preserve its phase color")
	var alternate := Color8(65, 53, 75, 255)
	_expect(image.get_pixel(60, 10).is_equal_approx(alternate), "checker alternate tile should preserve its brightened phase color")
	for index in range(Stage3PlayfieldTextureCache.MAX_CHECKER_TEXTURE_CACHE_ENTRIES + 2):
		cache.get_checker_texture(20 + index, 20, index % 3)
	_expect(cache.checker_texture_cache.size() > 0 and cache.checker_texture_cache.size() <= Stage3PlayfieldTextureCache.MAX_CHECKER_TEXTURE_CACHE_ENTRIES, "checker texture cache should clear at its bounded capacity")


func _verify_border_texture() -> void:
	var cache := Stage3PlayfieldTextureCache.new()
	var texture := cache.get_border_texture(120, 90, 1)
	_expect(texture != null, "border cache should build a texture")
	_expect(texture == cache.get_border_texture(120, 90, 1), "border cache should reuse an identical phase texture")
	var image := texture.get_image()
	_expect(image.get_pixel(20, 1).is_equal_approx(Stage3PlayfieldTextureCache.PASTEL_PINK), "border edge should preserve its emotional phase color")
	_expect(is_zero_approx(image.get_pixel(20, 20).a), "border texture interior should remain transparent")
	cache.clear()
	var snapshot := cache.get_snapshot()
	_expect(int(snapshot.get("checker_texture_cache_count", -1)) == 0, "cache clear should remove checker textures")
	_expect(int(snapshot.get("border_texture_cache_count", -1)) == 0, "cache clear should remove border textures")


func _verify_playfield_single_owner_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_playfield_renderer.gd")
	_expect(source.find("var _playfield_texture_cache: Stage3PlayfieldTextureCache") >= 0, "Stage 3 playfield should keep one typed texture-cache owner")
	for mirror in ["checker_texture_cache", "border_texture_cache"]:
		_expect(source.find("var %s: Dictionary = {}" % mirror) == -1, "%s mirror should be removed" % mirror)
	_expect(_function_body(source, "func _get_checker_texture(").find("_playfield_texture_cache.get_checker_texture") >= 0, "checker texture facade should delegate to the cache owner")
	_expect(_function_body(source, "func _get_border_texture(").find("_playfield_texture_cache.get_border_texture") >= 0, "border texture facade should delegate to the cache owner")
	_expect(_function_body(source, "func _build_border_image(").find("_playfield_texture_cache.build_border_image") >= 0, "border image facade should delegate to the cache owner")


func _function_body(source: String, signature: String) -> String:
	return SourceContractFunctionBody.extract(source, signature)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
