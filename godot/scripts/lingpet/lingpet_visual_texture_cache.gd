extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const DEFAULT_PREWARM_KEYS := [
	"egg",
	"egg_crack_1",
	"egg_crack_2",
	"companion_walk",
	"companion_strike",
	"companion_cast",
]

var _textures: Dictionary = {}


func prewarm_pet(pet_id: String, keys: Array = DEFAULT_PREWARM_KEYS) -> void:
	for raw_key in keys:
		get_texture(pet_id, str(raw_key), null)


func get_texture(pet_id: String, visual_key: String, fallback: Texture2D = null) -> Texture2D:
	var path: String = LingpetCatalog.get_visual_path(pet_id, visual_key)
	if path == "":
		return fallback
	if _textures.has(path):
		var cached: Variant = _textures[path]
		if cached is Texture2D:
			return cached as Texture2D
		_textures.erase(path)
	var texture := ProjectResourceLoader.load_texture(
		path,
		"[LingpetVisualTextureCache] missing lingpet visual texture: %s",
		"[LingpetVisualTextureCache] failed to load lingpet visual texture: %s"
	)
	if texture != null:
		_textures[path] = texture
		return texture
	return fallback


func clear() -> void:
	_textures.clear()
