extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const PlazaTradeItemPresentation := preload("res://scripts/plaza/plaza_trade_item_presentation.gd")

var textures_by_path: Dictionary = {}


func prewarm_inventories(player_inventory: Array, shop_inventory: Array) -> void:
	_prewarm_items(player_inventory)
	_prewarm_items(shop_inventory)


func get_texture(item_data: Dictionary) -> Texture2D:
	var path := PlazaTradeItemPresentation.get_icon_path(item_data)
	if path == "":
		return null
	var texture: Variant = textures_by_path.get(path, null)
	return texture if texture is Texture2D else null


func has_cached_path(path: String) -> bool:
	return textures_by_path.has(path)


func get_cached_count() -> int:
	return textures_by_path.size()


func reset() -> void:
	textures_by_path.clear()


func _prewarm_items(items: Array) -> void:
	for item_value in items:
		if not item_value is Dictionary:
			continue
		var item_data: Dictionary = item_value
		var path := PlazaTradeItemPresentation.get_icon_path(item_data)
		if path == "" or textures_by_path.has(path):
			continue
		if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
			textures_by_path[path] = null
			continue
		textures_by_path[path] = ProjectResourceLoader.load_imported_texture(path)
