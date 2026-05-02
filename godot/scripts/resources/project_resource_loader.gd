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
	if raw_exists and path.get_extension().to_lower() == "wav":
		var wav_stream := AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(path))
		if wav_stream != null:
			return wav_stream

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
