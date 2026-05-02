extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const DEFAULT_ITEM_COLOR := Color(200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0)

var texture_cache: Dictionary = {}


func clear_cache() -> void:
	texture_cache.clear()


func get_icon_texture(item_data: Dictionary) -> Texture2D:
	var direct_texture = item_data.get("icon_texture", null)
	if direct_texture is Texture2D:
		return direct_texture as Texture2D

	var path: String = str(item_data.get("icon_path", ""))
	if path == "":
		return null
	if not texture_cache.has(path):
		texture_cache[path] = _load_texture_resource(path)
	var cached_texture = texture_cache[path]
	if cached_texture is Texture2D:
		return cached_texture as Texture2D
	return null


func get_item_color(item_data: Dictionary) -> Color:
	var raw_color = item_data.get("color", DEFAULT_ITEM_COLOR)
	if raw_color is Color:
		return raw_color as Color
	if raw_color is Array and raw_color.size() >= 3:
		return Color(
			float(raw_color[0]) / 255.0,
			float(raw_color[1]) / 255.0,
			float(raw_color[2]) / 255.0,
			1.0
		)
	return DEFAULT_ITEM_COLOR


func _load_texture_resource(path: String) -> Texture2D:
	return ProjectResourceLoader.load_texture(
		path,
		"Missing active item icon at %s",
		"Failed to load active item icon at %s"
	)
