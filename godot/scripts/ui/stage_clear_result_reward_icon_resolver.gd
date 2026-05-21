extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


static func get_reward_icon_texture(reward: Dictionary, texture_cache: Dictionary) -> Texture2D:
	var preloaded_texture: Texture2D = get_preloaded_reward_icon_texture(reward)
	if preloaded_texture != null:
		return preloaded_texture

	var icon_path: String = get_reward_icon_path(reward)
	if icon_path == "":
		return null
	if texture_cache.has(icon_path):
		var cached: Variant = texture_cache[icon_path]
		return cached if cached is Texture2D else null

	var loaded: Texture2D = ProjectResourceLoader.load_texture(icon_path, "", "")
	texture_cache[icon_path] = loaded
	return loaded


static func get_preloaded_reward_icon_texture(reward: Dictionary) -> Texture2D:
	var item_data: Dictionary = get_reward_item_data(reward)
	var pre_texture: Variant = item_data.get("icon_texture", null)
	return pre_texture if pre_texture is Texture2D else null


static func get_reward_icon_path(reward: Dictionary) -> String:
	var item_data: Dictionary = get_reward_item_data(reward)

	var icon_path: String = str(reward.get("icon_path", ""))
	if icon_path != "":
		return icon_path

	icon_path = str(item_data.get("icon_path", ""))
	if icon_path != "":
		return icon_path

	var item_name: String = str(reward.get("item_name", ""))
	if item_name == "":
		item_name = str(item_data.get("name", ""))
	if item_name != "":
		return "res://assets/sprites/items/%s.png" % item_name

	return ""


static func get_reward_item_data(reward: Dictionary) -> Dictionary:
	var item_data_value: Variant = reward.get("item_data", {})
	if item_data_value is Dictionary:
		return item_data_value
	return {}
