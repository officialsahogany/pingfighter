extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetRingCoreRules := preload("res://scripts/lingpet/lingpet_ring_core_rules.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")

const PANEL_LIVE2D_VISUAL_KEYS_BY_PET_ID := {
	"lunabi": "click_reaction_anim",
	"nekuring": "click_reaction_anim",
	"monkeyring": "click_reaction_anim",
	"onimaru": "click_reaction_anim",
	"orosha": "click_reaction_anim",
	"rahoset": "click_reaction_anim",
}
const PREWARM_ALL_PETS := "__all_lingpets__"
# Slowly rotating galaxy swirl drawn behind the companion art (reuses the
# ball-spawn vortex asset — teal/magenta aurora, no bespoke art needed).
const PANEL_AURORA_TEXTURE_PATH := "res://assets/sprites/core/ball_spawn/stage_ball_spawn_vortex_imagegen_v1.png"

static var _art_prewarm_paths: Array[String] = []
static var _art_prewarm_index := 0
static var _art_prewarm_key := ""
static var _skill_icon_prewarm_paths: Array[String] = []
static var _skill_icon_prewarm_index := 0
static var _skill_icon_prewarm_key := ""


static func get_panel_aurora_texture(cache: Dictionary) -> Texture2D:
	if cache.has(PANEL_AURORA_TEXTURE_PATH):
		var cached_texture: Variant = cache[PANEL_AURORA_TEXTURE_PATH]
		if cached_texture is Texture2D:
			return cached_texture as Texture2D
		cache.erase(PANEL_AURORA_TEXTURE_PATH)
	var texture := ProjectResourceLoader.load_imported_texture(
		PANEL_AURORA_TEXTURE_PATH,
		"Missing lingpet aurora texture at %s",
		"Failed to load lingpet aurora texture at %s"
	)
	if texture != null:
		cache[PANEL_AURORA_TEXTURE_PATH] = texture
	return texture


static func get_cached_panel_aurora_texture(cache: Dictionary) -> Texture2D:
	return _get_cached_texture_path(PANEL_AURORA_TEXTURE_PATH, cache)


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


static func get_cached_art_texture(pet_id: String, cache: Dictionary) -> Texture2D:
	return _get_cached_texture_path(get_panel_art_path(pet_id), cache)


static func get_cached_static_art_texture(pet_id: String, cache: Dictionary) -> Texture2D:
	return _get_cached_texture_path(get_static_art_path(pet_id), cache)


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


static func get_static_art_path(pet_id: String) -> String:
	var normalized_pet_id := pet_id.strip_edges().to_lower()
	var path := ""
	if LingpetCatalog.has_pet(normalized_pet_id):
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


static func get_ring_core_icon_texture(tier: int, cache: Dictionary) -> Texture2D:
	var clamped_tier := clampi(tier, 0, LingpetRingCoreRules.MAX_RING_CORE_TIER)
	if clamped_tier <= 0:
		return null
	var icon_id := "lingpet_ring_core_upgrade_tier_%d" % clamped_tier
	var path := str(RuntimePerkIconRenderer.PERK_ICON_PATHS.get(icon_id, ""))
	if path == "":
		return null
	return get_skill_icon_texture(path, cache)


static func prewarm_art_assets(cache: Dictionary, pet_ids: Variant = null) -> void:
	var resolved_pet_ids := _resolve_prewarm_pet_ids(pet_ids)
	if resolved_pet_ids.is_empty():
		return
	_touch_texture(get_panel_aurora_texture(cache))
	for pet_id in resolved_pet_ids:
		_touch_texture(get_art_texture(pet_id, cache))


static func prewarm_cached_art_assets(cache: Dictionary, pet_ids: Variant = null) -> void:
	var resolved_pet_ids := _resolve_prewarm_pet_ids(pet_ids)
	if resolved_pet_ids.is_empty():
		return
	_touch_texture(get_cached_panel_aurora_texture(cache))
	for pet_id in resolved_pet_ids:
		var panel_texture := get_cached_art_texture(pet_id, cache)
		if panel_texture != null:
			_touch_texture(panel_texture)
			continue
		_touch_texture(get_cached_static_art_texture(pet_id, cache))


static func prewarm_art_assets_step(cache: Dictionary, pet_ids: Variant = null) -> bool:
	var prewarm_key := _build_prewarm_key(pet_ids)
	if _art_prewarm_paths.is_empty() or _art_prewarm_key != prewarm_key:
		_art_prewarm_paths = _build_panel_art_prewarm_paths(pet_ids)
		_art_prewarm_index = 0
		_art_prewarm_key = prewarm_key
	if _art_prewarm_paths.is_empty() or _art_prewarm_index >= _art_prewarm_paths.size():
		_finish_art_prewarm()
		return true
	var path: String = _art_prewarm_paths[_art_prewarm_index]
	if path != "":
		if not _prewarm_texture_path_threaded_step(
			path,
			cache,
			"Missing lingpet art texture at %s",
			"Failed to load lingpet art texture at %s",
			true
		):
			return false
	_art_prewarm_index += 1
	return false


static func prewarm_skill_icon_assets(cache: Dictionary, pet_ids: Variant = null) -> void:
	for pet_id in _resolve_prewarm_pet_ids(pet_ids):
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
	for tier in range(1, LingpetRingCoreRules.MAX_RING_CORE_TIER + 1):
		_touch_texture(get_ring_core_icon_texture(tier, cache))


static func prewarm_skill_icon_assets_step(cache: Dictionary, pet_ids: Variant = null) -> bool:
	var prewarm_key := _build_prewarm_key(pet_ids)
	if _skill_icon_prewarm_paths.is_empty() or _skill_icon_prewarm_key != prewarm_key:
		_skill_icon_prewarm_paths = _build_skill_icon_prewarm_paths(pet_ids)
		_skill_icon_prewarm_index = 0
		_skill_icon_prewarm_key = prewarm_key
	if _skill_icon_prewarm_paths.is_empty() or _skill_icon_prewarm_index >= _skill_icon_prewarm_paths.size():
		_finish_skill_icon_prewarm()
		return true
	var path: String = _skill_icon_prewarm_paths[_skill_icon_prewarm_index]
	if path != "":
		if not _prewarm_texture_path_threaded_step(
			path,
			cache,
			"Missing lingpet skill icon at %s",
			"Failed to load lingpet skill icon at %s",
			false
		):
			return false
	_skill_icon_prewarm_index += 1
	return false


static func _build_panel_art_prewarm_paths(pet_ids: Variant = null) -> Array[String]:
	var paths: Array[String] = []
	var resolved_pet_ids := _resolve_prewarm_pet_ids(pet_ids)
	if resolved_pet_ids.is_empty():
		return paths
	_append_unique_path(paths, PANEL_AURORA_TEXTURE_PATH)
	for pet_id in resolved_pet_ids:
		_append_unique_path(paths, get_panel_art_path(str(pet_id)))
	return paths


static func _build_skill_icon_prewarm_paths(pet_ids: Variant = null) -> Array[String]:
	var paths: Array[String] = []
	for pet_id in _resolve_prewarm_pet_ids(pet_ids):
		for skill in LingpetCatalog.get_active_skill_pool(pet_id):
			if not bool(skill.get("enabled", true)):
				continue
			_append_unique_path(paths, str(skill.get("icon_texture_path", "")))
			_append_unique_path(paths, str(skill.get("card_texture_path", "")))
		for passive in LingpetCatalog.get_passive_skill_pool(pet_id):
			if not bool(passive.get("enabled", true)):
				continue
			_append_unique_path(paths, str(passive.get("icon_texture_path", "")))
		_append_unique_path(paths, LingpetCatalog.get_passive_icon_path(str(pet_id), "gauge_gain_bonus"))
	for tier in range(1, LingpetRingCoreRules.MAX_RING_CORE_TIER + 1):
		var icon_id := "lingpet_ring_core_upgrade_tier_%d" % tier
		_append_unique_path(paths, str(RuntimePerkIconRenderer.PERK_ICON_PATHS.get(icon_id, "")))
	return paths


static func _resolve_prewarm_pet_ids(pet_ids: Variant = null) -> Array[String]:
	if pet_ids == null:
		return []
	if pet_ids is String and str(pet_ids) == PREWARM_ALL_PETS:
		return LingpetCatalog.get_pet_ids()
	var raw_ids: Array = []
	if pet_ids is Array:
		raw_ids = pet_ids
	else:
		raw_ids = [pet_ids]
	if raw_ids.has(PREWARM_ALL_PETS):
		return LingpetCatalog.get_pet_ids()
	var result: Array[String] = []
	for raw_id in raw_ids:
		var pet_id := str(raw_id).strip_edges().to_lower()
		if pet_id != "" and LingpetCatalog.has_pet(pet_id) and not result.has(pet_id):
			result.append(pet_id)
	return result


static func _build_prewarm_key(pet_ids: Variant = null) -> String:
	if pet_ids == null:
		return "none"
	if pet_ids is String and str(pet_ids) == PREWARM_ALL_PETS:
		return "all"
	if pet_ids is Array and (pet_ids as Array).has(PREWARM_ALL_PETS):
		return "all"
	return "ids:%s" % ",".join(_resolve_prewarm_pet_ids(pet_ids))


static func _append_unique_path(paths: Array[String], path: String) -> void:
	var normalized := path.strip_edges()
	if normalized == "" or paths.has(normalized):
		return
	paths.append(normalized)


static func _get_cached_texture_path(path: String, cache: Dictionary) -> Texture2D:
	if path == "":
		return null
	if cache.has(path):
		var cached_texture: Variant = cache[path]
		if cached_texture is Texture2D:
			return cached_texture as Texture2D
		cache.erase(path)
	var shared_cached: Texture2D = ProjectResourceLoader.get_cached_texture(path)
	if shared_cached != null:
		cache[path] = shared_cached
	return shared_cached


static func _prewarm_texture_path_threaded_step(
	path: String,
	cache: Dictionary,
	missing_warning: String,
	failed_warning: String,
	prefer_imported_fallback: bool
) -> bool:
	if path == "":
		return true
	if cache.has(path):
		var cached_texture: Variant = cache[path]
		if cached_texture is Texture2D:
			_touch_texture(cached_texture as Texture2D)
			return true
		cache.erase(path)
	var result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(
		path,
		missing_warning,
		failed_warning,
		ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_MSEC,
		ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_POLLS,
		false,
		prefer_imported_fallback
	)
	if not bool(result.get("done", true)):
		return false
	var texture: Texture2D = result.get("texture", null) as Texture2D
	if texture != null:
		cache[path] = texture
		_touch_texture(texture)
	return true


static func _finish_art_prewarm() -> void:
	_art_prewarm_paths.clear()
	_art_prewarm_index = 0
	_art_prewarm_key = ""


static func _finish_skill_icon_prewarm() -> void:
	_skill_icon_prewarm_paths.clear()
	_skill_icon_prewarm_index = 0
	_skill_icon_prewarm_key = ""


static func _touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_size()
