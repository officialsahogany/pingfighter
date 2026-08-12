extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const DEFAULT_PREWARM_KEYS := [
	"companion_idle",
	"companion_move_left",
	"companion_move_right",
	"companion_walk",
	"companion_distance_roll_source",
	"companion_strike",
	"companion_cast",
	"companion_puppet_control",
	# S3-a 8-8: 탑승 시트 2키. companion_carry 는 기존 미등재 결함이었다 — 첫 탑승
	# 프레임에 1280² 시트가 draw 경로에서 동기 로드됐다. companion_mount_base 는
	# 탑다운 준비도 게이트가 cache-only 로 읽으므로(§A-4) 프리웜이 준비를 책임진다.
	# 미보유 펫은 get_visual_path 가 빈 문자열이라 프리웜이 자연 스킵된다.
	"companion_carry",
	"companion_mount_base",
]

var _textures: Dictionary = {}


func prewarm_pet(pet_id: String, keys: Array = DEFAULT_PREWARM_KEYS) -> void:
	for raw_key in keys:
		get_texture(pet_id, str(raw_key), null)


func prewarm_pet_key_threaded_step(
	pet_id: String,
	visual_key: String,
	max_msec: int,
	max_polls: int
) -> bool:
	var path: String = LingpetCatalog.get_visual_path(pet_id, visual_key)
	if path == "":
		return true
	if _textures.has(path):
		var cached: Variant = _textures[path]
		if cached is Texture2D:
			return true
		_textures.erase(path)
	var result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(
		path,
		"[LingpetVisualTextureCache] missing lingpet visual texture: %s",
		"[LingpetVisualTextureCache] failed to load lingpet visual texture: %s",
		max_msec,
		max_polls,
		false,
		true
	)
	var texture: Texture2D = result.get("texture", null) as Texture2D
	if texture != null:
		_textures[path] = texture
	return bool(result.get("done", true))


func get_texture(pet_id: String, visual_key: String, fallback: Texture2D = null) -> Texture2D:
	var path: String = LingpetCatalog.get_visual_path(pet_id, visual_key)
	if path == "":
		return fallback
	if _textures.has(path):
		var cached: Variant = _textures[path]
		if cached is Texture2D:
			return cached as Texture2D
		_textures.erase(path)
	var texture := ProjectResourceLoader.load_imported_texture(
		path,
		"[LingpetVisualTextureCache] missing lingpet visual texture: %s",
		"[LingpetVisualTextureCache] failed to load lingpet visual texture: %s"
	)
	if texture != null:
		_textures[path] = texture
		return texture
	return fallback


func get_cached_texture(pet_id: String, visual_key: String, fallback: Texture2D = null) -> Texture2D:
	var path: String = LingpetCatalog.get_visual_path(pet_id, visual_key)
	if path == "":
		return fallback
	if _textures.has(path):
		var cached: Variant = _textures[path]
		if cached is Texture2D:
			return cached as Texture2D
		_textures.erase(path)
	var shared_cached: Texture2D = ProjectResourceLoader.get_cached_texture(path)
	if shared_cached != null:
		_textures[path] = shared_cached
		return shared_cached
	return fallback


func clear() -> void:
	_textures.clear()
