extends RefCounted


static func load_texture(path: String, missing_warning: String = "", failed_warning: String = "") -> Texture2D:
	var raw_exists: bool = FileAccess.file_exists(path)
	if raw_exists:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)

	var imported_exists: bool = ResourceLoader.exists(path)
	if imported_exists:
		var texture_resource: Resource = load(path)
		if texture_resource is Texture2D:
			return texture_resource

	if not raw_exists and not imported_exists:
		_push_path_warning(missing_warning, path)
	else:
		_push_path_warning(failed_warning, path)
	return null


static func load_audio_stream(path: String, missing_warning: String = "", failed_warning: String = "") -> AudioStream:
	var raw_exists: bool = FileAccess.file_exists(path)
	if raw_exists:
		var raw_path: String = ProjectSettings.globalize_path(path)
		match path.get_extension().to_lower():
			"wav":
				var wav_stream := AudioStreamWAV.load_from_file(raw_path)
				if wav_stream != null:
					return wav_stream
			"mp3":
				var mp3_stream := AudioStreamMP3.load_from_file(raw_path)
				if mp3_stream != null:
					return mp3_stream
			"ogg":
				var ogg_stream := AudioStreamOggVorbis.load_from_file(raw_path)
				if ogg_stream != null:
					return ogg_stream

	var imported_exists: bool = ResourceLoader.exists(path)
	if imported_exists:
		var stream_resource: Resource = load(path)
		if stream_resource is AudioStream:
			return stream_resource

	if not raw_exists and not imported_exists:
		_push_path_warning(missing_warning, path)
	else:
		_push_path_warning(failed_warning, path)
	return null


static func _push_path_warning(template: String, path: String) -> void:
	if template != "":
		push_warning(template % path)
