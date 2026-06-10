extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const PANEL_LIVE2D_VISUAL_KEYS_BY_PET_ID := {
	"lunabi": "click_reaction_anim",
	"nekuring": "click_reaction_anim",
	"monkeyring": "click_reaction_anim",
}


static func get_art_texture(pet_id: String, cache: Dictionary) -> Texture2D:
	var path := get_panel_art_path(pet_id)
	if path == "":
		return null
	if cache.has(path):
		var cached_texture: Variant = cache[path]
		if cached_texture is Texture2D:
			return cached_texture as Texture2D
		cache.erase(path)
	var texture := ProjectResourceLoader.load_imported_texture(
		path,
		"Missing lingpet art texture at %s",
		"Failed to load lingpet art texture at %s"
	)
	if texture != null:
		cache[path] = texture
		return texture
	return null


static func get_panel_art_path(pet_id: String) -> String:
	var normalized_pet_id := pet_id.strip_edges().to_lower()
	var path := ""
	if LingpetCatalog.has_pet(normalized_pet_id):
		var panel_live2d_key := get_panel_live2d_visual_key(normalized_pet_id)
		if panel_live2d_key != "":
			path = LingpetCatalog.get_visual_path(normalized_pet_id, panel_live2d_key)
		if path == "":
			path = LingpetCatalog.get_visual_path(normalized_pet_id, "cutin_art")
	if path == "":
		path = LingpetCatalog.get_visual_path(LingpetCatalog.get_default_pet_id(), "cutin_art")
	return path


static func get_panel_live2d_visual_key(pet_id: String) -> String:
	var normalized_pet_id := pet_id.strip_edges().to_lower()
	return str(PANEL_LIVE2D_VISUAL_KEYS_BY_PET_ID.get(normalized_pet_id, ""))


static func uses_panel_live2d_art(pet_id: String) -> bool:
	var normalized_pet_id := pet_id.strip_edges().to_lower()
	if normalized_pet_id == "":
		return false
	var visual_key := get_panel_live2d_visual_key(normalized_pet_id)
	return visual_key != "" and LingpetCatalog.get_visual_path(normalized_pet_id, visual_key) != ""


static func get_skill_icon_texture(texture_id: String, cache: Dictionary) -> Texture2D:
	var path: String = texture_id if texture_id.begins_with("res://") else ""
	if path == "":
		return null
	if cache.has(path):
		var cached_texture: Variant = cache[path]
		if cached_texture is Texture2D:
			return cached_texture as Texture2D
		cache.erase(path)
	var texture := ProjectResourceLoader.load_texture(
		path,
		"Missing lingpet skill icon at %s",
		"Failed to load lingpet skill icon at %s"
	)
	if texture != null:
		cache[path] = texture
	return texture


static func prewarm_art_assets(cache: Dictionary) -> void:
	for pet_id in LingpetCatalog.get_pet_ids():
		_touch_texture(get_art_texture(pet_id, cache))


static func prewarm_skill_icon_assets(cache: Dictionary) -> void:
	for pet_id in LingpetCatalog.get_pet_ids():
		for skill in LingpetCatalog.get_active_skill_pool(pet_id):
			if not bool(skill.get("enabled", true)):
				continue
			_touch_texture(get_skill_icon_texture(str(skill.get("icon_texture_path", "")), cache))
			_touch_texture(get_skill_icon_texture(str(skill.get("card_texture_path", "")), cache))
		for passive in LingpetCatalog.get_passive_skill_pool(pet_id):
			if not bool(passive.get("enabled", true)):
				continue
			_touch_texture(get_skill_icon_texture(str(passive.get("icon_texture_path", "")), cache))
		_touch_texture(get_skill_icon_texture(LingpetCatalog.get_passive_icon_path(pet_id, "gauge_gain_bonus"), cache))


static func _touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_size()
