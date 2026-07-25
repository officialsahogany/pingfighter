extends SceneTree

# expect-zero-object-leaks

const CharacterSelectPrewarm := preload("res://scripts/ui/character_select_prewarm.gd")
const LARGE_TEXTURE_PIXEL_AREA := 4096 * 4096

var _failures: Array[String] = []


func _init() -> void:
	var prewarm := CharacterSelectPrewarm.new()
	var retained_paths := prewarm.collect_retained_cache_paths()
	var checked_paths: Dictionary = {}
	var large_sheet_count := 0
	for path_value in retained_paths.get("textures", []):
		var path := str(path_value)
		if checked_paths.has(path) or not path.to_lower().ends_with(".png"):
			continue
		checked_paths[path] = true
		var dimensions := _read_png_dimensions(path)
		if dimensions == Vector2i.ZERO:
			_expect(false, "character-select prewarm PNG should expose a valid IHDR: %s" % path)
			continue
		if dimensions.x * dimensions.y < LARGE_TEXTURE_PIXEL_AREA:
			continue
		large_sheet_count += 1
		_verify_vram_import(path, dimensions)

	_expect(large_sheet_count > 0, "character-select prewarm should include at least one large-sheet contract target")
	if _failures.is_empty():
		print("character_select_large_sheet_import_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _read_png_dimensions(path: String) -> Vector2i:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return Vector2i.ZERO
	var header := file.get_buffer(24)
	file.close()
	if header.size() < 24:
		return Vector2i.ZERO
	var png_signature := PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
	for index in range(png_signature.size()):
		if header[index] != png_signature[index]:
			return Vector2i.ZERO
	if header[12] != 73 or header[13] != 72 or header[14] != 68 or header[15] != 82:
		return Vector2i.ZERO
	return Vector2i(_read_u32_be(header, 16), _read_u32_be(header, 20))


func _read_u32_be(bytes: PackedByteArray, offset: int) -> int:
	return (
		(int(bytes[offset]) << 24)
		| (int(bytes[offset + 1]) << 16)
		| (int(bytes[offset + 2]) << 8)
		| int(bytes[offset + 3])
	)


func _verify_vram_import(path: String, dimensions: Vector2i) -> void:
	var import_path := "%s.import" % path
	var import_text := FileAccess.get_file_as_string(import_path)
	var label := "%s (%dx%d)" % [path, dimensions.x, dimensions.y]
	_expect(not import_text.is_empty(), "large prewarm sheet import settings should exist: %s" % label)
	_expect(import_text.contains("compress/mode=2"), "large prewarm sheet should use VRAM compression: %s" % label)
	_expect(import_text.contains("compress/high_quality=true"), "large prewarm sheet should use high-quality compression: %s" % label)
	_expect(import_text.contains("\"vram_texture\": true"), "large prewarm sheet should be marked as a VRAM texture: %s" % label)
	_expect(import_text.contains("path.bptc="), "large prewarm sheet should provide a desktop BPTC import: %s" % label)
	_expect(import_text.contains("path.astc="), "large prewarm sheet should provide a mobile ASTC import: %s" % label)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
