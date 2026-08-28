extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _resource_cache: Dictionary = {}


func get_resource_cache() -> Dictionary:
	return _resource_cache


func load_texture_resource(path: String) -> Texture2D:
	return ProjectResourceLoader.load_texture(
		path,
		"Missing sprite at %s",
		"Failed to load texture at %s"
	)


func load_optional_texture_resource(path: String) -> Texture2D:
	return ProjectResourceLoader.load_texture(path, "", "")


func load_imported_texture_resource(path: String, optional: bool = false) -> Texture2D:
	return ProjectResourceLoader.load_imported_texture(
		path,
		"" if optional else "Missing sprite at %s",
		"" if optional else "Failed to load texture at %s"
	)


func texture_spec(keys: Array, path: String, optional: bool = false) -> Dictionary:
	return {
		"keys": keys,
		"path": path,
		"optional": optional,
	}


func imported_texture_spec(keys: Array, path: String, optional: bool = false) -> Dictionary:
	var spec := texture_spec(keys, path, optional)
	spec["prefer_imported"] = true
	return spec


func is_texture_spec_loaded(spec: Dictionary) -> bool:
	var keys_value: Variant = spec.get("keys", [])
	if not (keys_value is Array):
		return true
	var expected_path := str(spec.get("path", ""))
	for key_value in keys_value:
		var texture: Variant = _resource_cache.get(str(key_value), null)
		if not (texture is Texture2D):
			return false
		if expected_path != "" and str((texture as Texture2D).resource_path) != expected_path:
			return false
	return true


func try_store_cached_texture_spec(spec: Dictionary) -> bool:
	var path := str(spec.get("path", ""))
	if path == "":
		return false
	var texture: Texture2D = ProjectResourceLoader.get_cached_texture(path)
	if texture == null:
		return false
	store_texture_spec(spec, texture)
	return true


func load_texture_spec(spec: Dictionary) -> void:
	var path := str(spec.get("path", ""))
	if path == "":
		return
	var texture: Texture2D = null
	if bool(spec.get("prefer_imported", false)):
		texture = load_imported_texture_resource(path, bool(spec.get("optional", false)))
	elif bool(spec.get("optional", false)):
		texture = load_optional_texture_resource(path)
	else:
		texture = load_texture_resource(path)
	store_texture_spec(spec, texture)


func store_texture_spec(spec: Dictionary, texture: Texture2D) -> void:
	var keys_value: Variant = spec.get("keys", [])
	if not (keys_value is Array):
		return
	for key_value in keys_value:
		_resource_cache[str(key_value)] = texture
