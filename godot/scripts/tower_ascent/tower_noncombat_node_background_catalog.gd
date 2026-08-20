extends RefCounted

const SOURCE_BITMAP := "bitmap"
const SOURCE_PROCEDURAL := "procedural"
const FALLBACK_STAGE_BACKGROUND := "stage_background"
const REST_CAMP_PROCEDURAL_PATH := "procedural://tower/noncombat/rest_camp"
const NODE_BACKGROUND_SPECS := {
	"shop": {
		"source": SOURCE_BITMAP,
		"path": "res://assets/sprites/tower/noncombat/shop_arena_background_imagegen_v1.png",
	},
	"training": {
		"source": SOURCE_BITMAP,
		"path": "res://assets/sprites/tower/noncombat/training_arena_background_imagegen_v1.png",
	},
	"fallen_monk": {
		"source": SOURCE_BITMAP,
		"path": "res://assets/sprites/tower/noncombat/fallen_monk_arena_background_imagegen_v1.png",
	},
	"guardian_spring": {
		"source": SOURCE_BITMAP,
		"path": "res://assets/sprites/tower/noncombat/guardian_spring_arena_background_imagegen_v1.png",
	},
	# The approved S3 budget is exactly four bitmaps. Rest keeps R4's existing
	# campfire procedure instead of inventing a fifth candidate asset.
	"rest": {
		"source": SOURCE_PROCEDURAL,
		"path": REST_CAMP_PROCEDURAL_PATH,
	},
}

var _resolution_by_kind: Dictionary = {}
var _load_attempt_by_path: Dictionary = {}
var _cold_prewarm_usec_by_kind: Dictionary = {}
var _resource_exists_override: Callable
var _resource_load_override: Callable
var _cache_hit_count := 0
var _filesystem_probe_count := 0
var _resource_load_count := 0


func _init(
	resource_exists_override: Callable = Callable(),
	resource_load_override: Callable = Callable()
) -> void:
	_resource_exists_override = resource_exists_override
	_resource_load_override = resource_load_override


func get_supported_node_kinds() -> PackedStringArray:
	return PackedStringArray(NODE_BACKGROUND_SPECS.keys())


func resolve_declared_path(node_kind: String) -> String:
	var spec: Dictionary = NODE_BACKGROUND_SPECS.get(_normalize_kind(node_kind), {})
	return str(spec.get("path", ""))


func prewarm_node_kind(node_kind: String) -> Dictionary:
	var kind := _normalize_kind(node_kind)
	if _resolution_by_kind.has(kind):
		_cache_hit_count += 1
		var cached: Dictionary = (_resolution_by_kind[kind] as Dictionary).duplicate(false)
		cached["cache_hit"] = true
		cached["cold_prewarm_usec"] = 0
		return cached

	var started_usec := Time.get_ticks_usec()
	var spec: Dictionary = NODE_BACKGROUND_SPECS.get(kind, {})
	var source := str(spec.get("source", ""))
	var path := str(spec.get("path", ""))
	var resolution := {
		"kind": kind,
		"source": source,
		"background_path": path,
		"texture": null,
		"cached": true,
		"cache_hit": false,
		"ready": false,
		"fallback_to_stage_background": false,
		"fallback_kind": "",
		"reason": "",
	}
	if spec.is_empty():
		resolution["fallback_to_stage_background"] = true
		resolution["fallback_kind"] = FALLBACK_STAGE_BACKGROUND
		resolution["reason"] = "unknown_kind"
	elif source == SOURCE_PROCEDURAL:
		resolution["ready"] = true
		resolution["reason"] = "procedural_ready"
	else:
		var texture := _load_bitmap_once(path)
		resolution["texture"] = texture
		resolution["ready"] = texture != null
		resolution["fallback_to_stage_background"] = texture == null
		resolution["fallback_kind"] = FALLBACK_STAGE_BACKGROUND if texture == null else ""
		resolution["reason"] = "missing_asset" if texture == null else "texture_ready"

	var elapsed_usec := maxi(0, Time.get_ticks_usec() - started_usec)
	resolution["cold_prewarm_usec"] = elapsed_usec
	_resolution_by_kind[kind] = resolution
	_cold_prewarm_usec_by_kind[kind] = elapsed_usec
	return resolution.duplicate(false)


func get_cached_resolution(node_kind: String) -> Dictionary:
	var kind := _normalize_kind(node_kind)
	if _resolution_by_kind.has(kind):
		return (_resolution_by_kind[kind] as Dictionary).duplicate(false)
	return {
		"kind": kind,
		"source": str((NODE_BACKGROUND_SPECS.get(kind, {}) as Dictionary).get("source", "")),
		"background_path": resolve_declared_path(kind),
		"texture": null,
		"cached": false,
		"cache_hit": false,
		"ready": false,
		"fallback_to_stage_background": true,
		"fallback_kind": FALLBACK_STAGE_BACKGROUND,
		"reason": "not_prewarmed",
		"cold_prewarm_usec": 0,
	}


func get_debug_state() -> Dictionary:
	var hit_count := 0
	var miss_count := 0
	for resolution_value in _resolution_by_kind.values():
		if not (resolution_value is Dictionary):
			continue
		var resolution := resolution_value as Dictionary
		if bool(resolution.get("fallback_to_stage_background", false)):
			miss_count += 1
		else:
			hit_count += 1
	return {
		"entry_count": _resolution_by_kind.size(),
		"hit_count": hit_count,
		"miss_count": miss_count,
		"cache_hit_count": _cache_hit_count,
		"filesystem_probe_count": _filesystem_probe_count,
		"resource_load_count": _resource_load_count,
		"load_attempt_by_path": _load_attempt_by_path.duplicate(true),
		"cold_prewarm_usec_by_kind": _cold_prewarm_usec_by_kind.duplicate(true),
	}


func clear_cache() -> void:
	_resolution_by_kind.clear()
	_load_attempt_by_path.clear()
	_cold_prewarm_usec_by_kind.clear()
	_cache_hit_count = 0
	_filesystem_probe_count = 0
	_resource_load_count = 0


func _load_bitmap_once(path: String) -> Texture2D:
	if path.is_empty():
		return null
	_load_attempt_by_path[path] = int(_load_attempt_by_path.get(path, 0)) + 1
	_filesystem_probe_count += 1
	var resource_exists := (
		bool(_resource_exists_override.call(path))
		if _resource_exists_override.is_valid()
		else ResourceLoader.exists(path, "Texture2D")
	)
	if not resource_exists:
		return null
	_resource_load_count += 1
	var loaded_resource: Resource = (
		_resource_load_override.call(path)
		if _resource_load_override.is_valid()
		else ResourceLoader.load(path, "Texture2D")
	)
	return loaded_resource as Texture2D if loaded_resource is Texture2D else null


func _normalize_kind(node_kind: String) -> String:
	var kind := node_kind.strip_edges().to_lower()
	return kind if NODE_BACKGROUND_SPECS.has(kind) else "unknown"
