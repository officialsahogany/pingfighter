extends RefCounted

const ProjectResourceLoader = preload("res://scripts/resources/project_resource_loader.gd")

const ASSET_BACKGROUND := "background"
const ASSET_STATUE := "statue"
const ASSET_GLOW := "glow"
const ASSET_CAPSULE := "capsule"
const ASSET_RITUAL_RING := "ritual_ring"
const ASSET_RITUAL_BACKPLATE := "ritual_backplate"
const ASSET_SOUL_SEAL_SHARD := "soul_seal_shard"

const ASSET_SPECS := {
	ASSET_BACKGROUND: {
		"path": "res://assets/sprites/tower/noncombat/guardian_spring_presentation/guardian_spring_scene_background_imagegen_v1.png",
		"expected_size": Vector2i(760, 750),
	},
	ASSET_STATUE: {
		"path": "res://assets/sprites/tower/noncombat/guardian_spring_presentation/guardian_spring_statue_palm_stele_imagegen_v1.png",
		"expected_size": Vector2i(1024, 1536),
	},
	ASSET_GLOW: {
		"path": "res://assets/sprites/tower/noncombat/guardian_spring_presentation/guardian_spring_statue_glow_overlay_imagegen_v1.png",
		"expected_size": Vector2i(1024, 1536),
	},
	ASSET_CAPSULE: {
		"path": "res://assets/sprites/tower/noncombat/guardian_spring_presentation/guardian_spring_capsule_frame_jade_seed_imagegen_v1.png",
		"expected_size": Vector2i(1086, 1448),
	},
	ASSET_RITUAL_RING: {
		"path": "res://assets/sprites/tower/noncombat/guardian_spring_presentation/guardian_spring_ritual_jade_ring_imagegen_v1.png",
		"expected_size": Vector2i(1024, 1024),
		"source_png": true,
	},
	ASSET_RITUAL_BACKPLATE: {
		"path": "res://assets/sprites/tower/noncombat/guardian_spring_presentation/guardian_spring_ritual_jade_backplate_imagegen_v1.png",
		"expected_size": Vector2i(1024, 1024),
		"source_png": true,
	},
	ASSET_SOUL_SEAL_SHARD: {
		"path": "res://assets/sprites/tower/noncombat/guardian_spring_presentation/guardian_spring_soul_seal_shard_imagegen_v1.png",
		"expected_size": Vector2i(512, 512),
		"source_png": true,
	},
}

var _resolution_by_key: Dictionary = {}
var _resource_exists_override: Callable
var _resource_load_override: Callable
var _cache_hit_count := 0
var _filesystem_probe_count := 0
var _resource_load_count := 0
var _cold_prewarm_usec := 0


func _init(
	resource_exists_override: Callable = Callable(),
	resource_load_override: Callable = Callable()
) -> void:
	_resource_exists_override = resource_exists_override
	_resource_load_override = resource_load_override


func get_asset_keys() -> PackedStringArray:
	return PackedStringArray(ASSET_SPECS.keys())


func resolve_declared_path(asset_key: String) -> String:
	var spec: Dictionary = ASSET_SPECS.get(asset_key, {})
	return str(spec.get("path", ""))


func get_expected_size(asset_key: String) -> Vector2i:
	var spec: Dictionary = ASSET_SPECS.get(asset_key, {})
	return spec.get("expected_size", Vector2i.ZERO)


func prewarm_all() -> Dictionary:
	if _resolution_by_key.size() == ASSET_SPECS.size():
		_cache_hit_count += 1
		var cached := get_cached_bundle()
		cached["cache_hit"] = true
		cached["cold_prewarm_usec"] = 0
		return cached
	var started_usec := Time.get_ticks_usec()
	for asset_key_value in ASSET_SPECS.keys():
		prewarm_asset(str(asset_key_value))
	_cold_prewarm_usec = maxi(0, Time.get_ticks_usec() - started_usec)
	var result := get_cached_bundle()
	result["cache_hit"] = false
	result["cold_prewarm_usec"] = _cold_prewarm_usec
	return result


func prewarm_asset(asset_key: String) -> Dictionary:
	if _resolution_by_key.has(asset_key):
		_cache_hit_count += 1
		var cached: Dictionary = (_resolution_by_key[asset_key] as Dictionary).duplicate(false)
		cached["cache_hit"] = true
		return cached
	var spec: Dictionary = ASSET_SPECS.get(asset_key, {})
	var path := str(spec.get("path", ""))
	var expected_size: Vector2i = spec.get("expected_size", Vector2i.ZERO)
	var resolution := {
		"asset_key": asset_key,
		"path": path,
		"expected_size": expected_size,
		"actual_size": Vector2i.ZERO,
		"texture": null,
		"cached": true,
		"cache_hit": false,
		"ready": false,
		"reason": "unknown_asset_key" if spec.is_empty() else "missing_asset",
	}
	if not spec.is_empty():
		var texture := _load_bitmap_once(path, bool(spec.get("source_png", false)))
		resolution["texture"] = texture
		if texture != null:
			var actual_size := Vector2i(texture.get_size())
			resolution["actual_size"] = actual_size
			resolution["ready"] = actual_size == expected_size
			resolution["reason"] = (
				"texture_ready" if actual_size == expected_size else "size_mismatch"
			)
	_resolution_by_key[asset_key] = resolution
	return resolution.duplicate(false)


func get_cached_bundle() -> Dictionary:
	var textures := {}
	var resolutions := {}
	var ready := _resolution_by_key.size() == ASSET_SPECS.size()
	for asset_key_value in ASSET_SPECS.keys():
		var asset_key := str(asset_key_value)
		var resolution: Dictionary = _resolution_by_key.get(asset_key, {})
		resolutions[asset_key] = resolution.duplicate(false)
		var texture: Texture2D = resolution.get("texture", null) as Texture2D
		textures[asset_key] = texture
		ready = ready and bool(resolution.get("ready", false)) and texture != null
	return {
		"ready": ready,
		"textures": textures,
		"resolutions": resolutions,
		"entry_count": _resolution_by_key.size(),
		"expected_count": ASSET_SPECS.size(),
		"cold_prewarm_usec": _cold_prewarm_usec,
		"cache_hit": false,
		"fallback_to_v1": not ready,
	}


func get_debug_state() -> Dictionary:
	var bundle := get_cached_bundle()
	return {
		"ready": bool(bundle.get("ready", false)),
		"entry_count": int(bundle.get("entry_count", 0)),
		"expected_count": int(bundle.get("expected_count", 0)),
		"cache_hit_count": _cache_hit_count,
		"filesystem_probe_count": _filesystem_probe_count,
		"resource_load_count": _resource_load_count,
		"cold_prewarm_usec": _cold_prewarm_usec,
		"fallback_to_v1": bool(bundle.get("fallback_to_v1", true)),
	}


func clear_cache() -> void:
	_resolution_by_key.clear()
	_cache_hit_count = 0
	_filesystem_probe_count = 0
	_resource_load_count = 0
	_cold_prewarm_usec = 0


func _load_bitmap_once(path: String, source_png: bool = false) -> Texture2D:
	if path.is_empty():
		return null
	_filesystem_probe_count += 1
	var resource_exists := (
		bool(_resource_exists_override.call(path))
		if _resource_exists_override.is_valid()
		else FileAccess.file_exists(path)
	)
	if not resource_exists:
		return null
	_resource_load_count += 1
	var loaded_resource: Variant = null
	if _resource_load_override.is_valid():
		loaded_resource = _resource_load_override.call(path)
	elif source_png:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			loaded_resource = ImageTexture.create_from_image(image)
	else:
		loaded_resource = ProjectResourceLoader.load_texture(path)
	return loaded_resource as Texture2D if loaded_resource is Texture2D else null
