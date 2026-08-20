extends RefCounted

const MAP_SCROLL_ROOT := "res://assets/sprites/tower/map_scroll"
const SOURCE_BITMAP := "bitmap"
const REALM_HUMAN := "human_realm"
const REALM_IMMORTAL := "immortal_realm"

const COMMON_HANJI_PAPER := "common_hanji_paper"
const FLOOR_GATE_PLAQUE := "floor_gate_plaque"
const ROUTE_BRUSH_UNSELECTED := "route_brush_unselected"
const ROUTE_BRUSH_AVAILABLE := "route_brush_available"
const ROUTE_BRUSH_COMPLETED_GOLD := "route_brush_completed_gold"

const HUMAN_BAND_ASSET_KEYS: Array[String] = [
	"human_realm_01_mountain_rev2",
	"human_realm_02_village_rev2",
	"human_realm_03_river_rev2",
]
const IMMORTAL_BAND_ASSET_KEYS: Array[String] = [
	"immortal_realm_01_islands_rev2",
	"immortal_realm_02_cloud_cranes_rev2",
	"immortal_realm_03_pavilions_rev2",
]

const ASSET_SPECS := {
	COMMON_HANJI_PAPER: {
		"path": MAP_SCROLL_ROOT + "/common_hanji_paper.png",
		"size": Vector2i(692, 320),
	},
	FLOOR_GATE_PLAQUE: {
		"path": MAP_SCROLL_ROOT + "/floor_gate_plaque.png",
		"size": Vector2i(620, 48),
	},
	ROUTE_BRUSH_UNSELECTED: {
		"path": MAP_SCROLL_ROOT + "/route_brush_unselected.png",
		"size": Vector2i(72, 320),
	},
	ROUTE_BRUSH_AVAILABLE: {
		"path": MAP_SCROLL_ROOT + "/route_brush_available.png",
		"size": Vector2i(72, 320),
	},
	ROUTE_BRUSH_COMPLETED_GOLD: {
		"path": MAP_SCROLL_ROOT + "/route_brush_completed_gold.png",
		"size": Vector2i(72, 320),
	},
	"human_realm_01_mountain_rev2": {
		"path": MAP_SCROLL_ROOT + "/human_realm_01_mountain_rev2.png",
		"size": Vector2i(692, 320),
	},
	"human_realm_02_village_rev2": {
		"path": MAP_SCROLL_ROOT + "/human_realm_02_village_rev2.png",
		"size": Vector2i(692, 320),
	},
	"human_realm_03_river_rev2": {
		"path": MAP_SCROLL_ROOT + "/human_realm_03_river_rev2.png",
		"size": Vector2i(692, 320),
	},
	"immortal_realm_01_islands_rev2": {
		"path": MAP_SCROLL_ROOT + "/immortal_realm_01_islands_rev2.png",
		"size": Vector2i(692, 320),
	},
	"immortal_realm_02_cloud_cranes_rev2": {
		"path": MAP_SCROLL_ROOT + "/immortal_realm_02_cloud_cranes_rev2.png",
		"size": Vector2i(692, 320),
	},
	"immortal_realm_03_pavilions_rev2": {
		"path": MAP_SCROLL_ROOT + "/immortal_realm_03_pavilions_rev2.png",
		"size": Vector2i(692, 320),
	},
}

var _resolution_by_key: Dictionary = {}
var _load_attempt_by_path: Dictionary = {}
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


func get_asset_keys() -> PackedStringArray:
	return PackedStringArray(ASSET_SPECS.keys())


func resolve_declared_path(asset_key: String) -> String:
	var spec: Dictionary = ASSET_SPECS.get(asset_key, {})
	return str(spec.get("path", ""))


func get_expected_size(asset_key: String) -> Vector2i:
	var spec: Dictionary = ASSET_SPECS.get(asset_key, {})
	return spec.get("size", Vector2i.ZERO)


static func resolve_band_asset_key(
	realm_kind: String,
	floor_number: int,
	previous_asset_key: String = ""
) -> String:
	var family := (
		IMMORTAL_BAND_ASSET_KEYS
		if realm_kind == REALM_IMMORTAL
		else HUMAN_BAND_ASSET_KEYS
	)
	var realm_bias := 1 if realm_kind == REALM_IMMORTAL else 0
	var variant_index := posmod(floor_number * 2 + realm_bias, family.size())
	var asset_key := family[variant_index]
	if asset_key == previous_asset_key:
		asset_key = family[(variant_index + 1) % family.size()]
	return asset_key


func prewarm_all() -> Dictionary:
	var all_ready := true
	for asset_key in ASSET_SPECS.keys():
		var resolution := prewarm_asset(str(asset_key))
		all_ready = all_ready and bool(resolution.get("ready", false))
	return {
		"ready": all_ready,
		"entry_count": _resolution_by_key.size(),
		"expected_count": ASSET_SPECS.size(),
	}


func prewarm_asset(asset_key: String) -> Dictionary:
	if _resolution_by_key.has(asset_key):
		_cache_hit_count += 1
		var cached: Dictionary = (_resolution_by_key[asset_key] as Dictionary).duplicate(false)
		cached["cache_hit"] = true
		return cached

	var spec: Dictionary = ASSET_SPECS.get(asset_key, {})
	var path := str(spec.get("path", ""))
	var expected_size: Vector2i = spec.get("size", Vector2i.ZERO)
	var resolution := {
		"asset_key": asset_key,
		"source": SOURCE_BITMAP,
		"path": path,
		"expected_size": expected_size,
		"texture": null,
		"cached": true,
		"cache_hit": false,
		"ready": false,
		"reason": "unknown_asset_key" if spec.is_empty() else "missing_asset",
	}
	if not spec.is_empty():
		var texture := _load_bitmap_once(path)
		resolution["texture"] = texture
		if texture != null:
			var actual_size := Vector2i(texture.get_size())
			resolution["actual_size"] = actual_size
			resolution["ready"] = actual_size == expected_size
			resolution["reason"] = "texture_ready" if actual_size == expected_size else "size_mismatch"
	_resolution_by_key[asset_key] = resolution
	return resolution.duplicate(false)


func get_cached_resolution(asset_key: String) -> Dictionary:
	if _resolution_by_key.has(asset_key):
		return (_resolution_by_key[asset_key] as Dictionary).duplicate(false)
	return {
		"asset_key": asset_key,
		"source": SOURCE_BITMAP,
		"path": resolve_declared_path(asset_key),
		"expected_size": get_expected_size(asset_key),
		"texture": null,
		"cached": false,
		"cache_hit": false,
		"ready": false,
		"reason": "not_prewarmed",
	}


func get_debug_state() -> Dictionary:
	var ready_count := 0
	var missing_count := 0
	for resolution_value in _resolution_by_key.values():
		if not (resolution_value is Dictionary):
			continue
		if bool((resolution_value as Dictionary).get("ready", false)):
			ready_count += 1
		else:
			missing_count += 1
	return {
		"entry_count": _resolution_by_key.size(),
		"expected_count": ASSET_SPECS.size(),
		"ready_count": ready_count,
		"missing_count": missing_count,
		"cache_hit_count": _cache_hit_count,
		"filesystem_probe_count": _filesystem_probe_count,
		"resource_load_count": _resource_load_count,
		"load_attempt_by_path": _load_attempt_by_path.duplicate(true),
	}


func clear_cache() -> void:
	_resolution_by_key.clear()
	_load_attempt_by_path.clear()
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
