extends RefCounted

static var _texture_cache: Dictionary = {}
static var _audio_cache: Dictionary = {}
static var _font_cache: Dictionary = {}


static func load_texture(path: String, missing_warning: String = "", failed_warning: String = "") -> Texture2D:
	if _texture_cache.has(path):
		var cached_texture: Variant = _texture_cache[path]
		if cached_texture is Texture2D:
			return cached_texture
		_texture_cache.erase(path)

	var imported_exists: bool = _can_load_imported_resource(path)
	if imported_exists:
		var texture_resource: Resource = load(path)
		if texture_resource is Texture2D:
			_texture_cache[path] = texture_resource
			return texture_resource

	var raw_exists: bool = FileAccess.file_exists(path)
	if raw_exists:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			var raw_texture: Texture2D = ImageTexture.create_from_image(image)
			_texture_cache[path] = raw_texture
			return raw_texture

	if not raw_exists and not imported_exists:
		_push_path_warning(missing_warning, path)
	else:
		_push_path_warning(failed_warning, path)
	return null


static func get_cached_texture(path: String) -> Texture2D:
	if not _texture_cache.has(path):
		return null
	var cached_texture: Variant = _texture_cache[path]
	if cached_texture is Texture2D:
		return cached_texture
	_texture_cache.erase(path)
	return null


static func store_texture(path: String, texture: Texture2D) -> void:
	if path == "" or texture == null:
		return
	_texture_cache[path] = texture


static func load_audio_stream(path: String, missing_warning: String = "", failed_warning: String = "") -> AudioStream:
	if _audio_cache.has(path):
		var cached_stream: Variant = _audio_cache[path]
		if cached_stream is AudioStream:
			return cached_stream
		_audio_cache.erase(path)

	var raw_exists: bool = FileAccess.file_exists(path)
	if raw_exists:
		var raw_path: String = ProjectSettings.globalize_path(path)
		match path.get_extension().to_lower():
			"wav":
				var wav_stream := AudioStreamWAV.load_from_file(raw_path)
				if wav_stream != null:
					_audio_cache[path] = wav_stream
					return wav_stream
			"mp3":
				var mp3_stream := AudioStreamMP3.load_from_file(raw_path)
				if mp3_stream != null:
					_audio_cache[path] = mp3_stream
					return mp3_stream
			"ogg":
				var ogg_stream := AudioStreamOggVorbis.load_from_file(raw_path)
				if ogg_stream != null:
					_audio_cache[path] = ogg_stream
					return ogg_stream

	var imported_exists: bool = _can_load_imported_resource(path)
	if imported_exists:
		var stream_resource: Resource = load(path)
		if stream_resource is AudioStream:
			_audio_cache[path] = stream_resource
			return stream_resource

	if not raw_exists and not imported_exists:
		_push_path_warning(missing_warning, path)
	else:
		_push_path_warning(failed_warning, path)
	return null


static func get_cached_audio_stream(path: String) -> AudioStream:
	if not _audio_cache.has(path):
		return null
	var cached_stream: Variant = _audio_cache[path]
	if cached_stream is AudioStream:
		return cached_stream
	_audio_cache.erase(path)
	return null


static func store_audio_stream(path: String, stream: AudioStream) -> void:
	if path == "" or stream == null:
		return
	_audio_cache[path] = stream


static func load_font(path: String, missing_warning: String = "", failed_warning: String = "") -> Font:
	if _font_cache.has(path):
		var cached_font: Variant = _font_cache[path]
		if cached_font is Font:
			return cached_font
		_font_cache.erase(path)

	var raw_exists: bool = FileAccess.file_exists(path)
	if raw_exists:
		var font_file := FontFile.new()
		if font_file.load_dynamic_font(ProjectSettings.globalize_path(path)) == OK:
			_font_cache[path] = font_file
			return font_file

	var imported_exists: bool = _can_load_imported_resource(path)
	if imported_exists:
		var font_resource: Resource = load(path)
		if font_resource is Font:
			_font_cache[path] = font_resource
			return font_resource

	if not raw_exists and not imported_exists:
		_push_path_warning(missing_warning, path)
	else:
		_push_path_warning(failed_warning, path)
	return null


static func _push_path_warning(template: String, path: String) -> void:
	if template != "":
		push_warning(template % path)


static func _can_load_imported_resource(path: String) -> bool:
	var import_path := "%s.import" % path
	if not FileAccess.file_exists(import_path):
		return false

	var import_config := ConfigFile.new()
	if import_config.load(import_path) != OK:
		return false

	var remap_path: Variant = import_config.get_value("remap", "path", "")
	if remap_path is String and remap_path != "":
		return FileAccess.file_exists(remap_path)

	var dest_files: Variant = import_config.get_value("deps", "dest_files", [])
	if dest_files is Array:
		if dest_files.is_empty():
			return false
		for dest_file in dest_files:
			if not (dest_file is String) or not FileAccess.file_exists(dest_file):
				return false
		return true

	return true


static func clear_caches() -> void:
	_texture_cache.clear()
	_audio_cache.clear()
	_font_cache.clear()
