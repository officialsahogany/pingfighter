extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const PlazaThemeCatalog := preload("res://scripts/plaza/plaza_theme_catalog.gd")

const FLOOR_BASE_01 := "res://assets/ui/plaza/plaza_stage1_floor_base_01_cyber_joseon_imagegen_v1.png"
const FLOOR_BASE_02 := "res://assets/ui/plaza/plaza_stage1_floor_base_02_cyber_joseon_imagegen_v1.png"
const FLOOR_ACCENT := "res://assets/ui/plaza/plaza_stage1_floor_accent_neon_cyber_joseon_imagegen_v1.png"
const FLOOR_ACCENT_EMISSIVE := "res://assets/ui/plaza/plaza_stage1_floor_accent_neon_emissive_v1.png"
const FLOOR_BORDER := "res://assets/ui/plaza/plaza_stage1_floor_border_dancheong_cyber_joseon_imagegen_v1.png"
const FLOOR_BORDER_EMISSIVE := "res://assets/ui/plaza/plaza_stage1_floor_border_dancheong_emissive_v1.png"
const FLOOR_MEDALLION := "res://assets/ui/plaza/plaza_stage1_floor_special_medallion_cyber_joseon_imagegen_v1.png"
const FLOOR_MEDALLION_EMISSIVE := "res://assets/ui/plaza/plaza_stage1_floor_special_medallion_emissive_v1.png"
const SIDESCROLL_GROUND_STRIP := "res://assets/ui/plaza/plaza_stage1_sidescroll_ground_strip_cyber_joseon_imagegen_v1.png"
const SIDESCROLL_GROUND_STRIP_EMISSIVE := "res://assets/ui/plaza/plaza_stage1_sidescroll_ground_strip_emissive_v1.png"
const SIDESCROLL_MIDGROUND_WALL := "res://assets/ui/plaza/plaza_stage1_sidescroll_midground_wall_cyber_joseon_imagegen_v1.png"
const SIDESCROLL_FAR_SKY := "res://assets/ui/plaza/plaza_stage1_sidescroll_far_sky_moon_cyber_joseon_imagegen_v1.png"
const SIDESCROLL_ACCENT_CUTOUT := "res://assets/ui/plaza/plaza_stage1_sidescroll_accent_neon_cutout_v1.png"
const SIDESCROLL_ACCENT_CUTOUT_EMISSIVE := "res://assets/ui/plaza/plaza_stage1_sidescroll_accent_neon_cutout_emissive_v1.png"
const SIDESCROLL_MEDALLION_CUTOUT := "res://assets/ui/plaza/plaza_stage1_sidescroll_medallion_cutout_v1.png"
const SIDESCROLL_MEDALLION_CUTOUT_EMISSIVE := "res://assets/ui/plaza/plaza_stage1_sidescroll_medallion_cutout_emissive_v1.png"

const BUILDING_MANIFEST_PATHS := [
	"res://assets/ui/plaza/buildings/plaza_stage1_cyber_joseon_shop_v2_manifest.json",
	"res://assets/ui/plaza/buildings/plaza_stage1_cyber_joseon_bank_v1_manifest.json",
	"res://assets/ui/plaza/buildings/plaza_stage1_cyber_joseon_gacha_v1_manifest.json",
	"res://assets/ui/plaza/buildings/plaza_stage1_cyber_joseon_lingpet_store_v1_manifest.json",
	"res://assets/ui/plaza/buildings/plaza_stage1_cyber_joseon_blacksmith_v1_manifest.json",
	"res://assets/ui/plaza/buildings/plaza_stage1_cyber_joseon_tavern_v1_manifest.json",
	"res://assets/ui/plaza/buildings/plaza_stage1_cyber_joseon_academy_v1_manifest.json",
]

const FLOOR_KEYS := {
	"base_01": FLOOR_BASE_01,
	"base_02": FLOOR_BASE_02,
	"accent": FLOOR_ACCENT,
	"accent_emissive": FLOOR_ACCENT_EMISSIVE,
	"border": FLOOR_BORDER,
	"border_emissive": FLOOR_BORDER_EMISSIVE,
	"medallion": FLOOR_MEDALLION,
	"medallion_emissive": FLOOR_MEDALLION_EMISSIVE,
	"ground_strip": SIDESCROLL_GROUND_STRIP,
	"ground_strip_emissive": SIDESCROLL_GROUND_STRIP_EMISSIVE,
	"midground_wall": SIDESCROLL_MIDGROUND_WALL,
	"far_sky": SIDESCROLL_FAR_SKY,
	"accent_cutout": SIDESCROLL_ACCENT_CUTOUT,
	"accent_cutout_emissive": SIDESCROLL_ACCENT_CUTOUT_EMISSIVE,
	"medallion_cutout": SIDESCROLL_MEDALLION_CUTOUT,
	"medallion_cutout_emissive": SIDESCROLL_MEDALLION_CUTOUT_EMISSIVE,
}

const BUILDING_BASELINE_Y := 640.0
const BUILDING_INTERACTION_TOP := 570.0
const BUILDING_INTERACTION_HEIGHT := 118.0

const BUILDING_LAYOUT := {
	"shop": {
		"pivot": Vector2(360.0, BUILDING_BASELINE_Y),
		"display_height": 360.0,
		"interaction_width": 180.0,
	},
	"bank": {
		"pivot": Vector2(740.0, BUILDING_BASELINE_Y),
		"display_height": 390.0,
		"interaction_width": 190.0,
	},
	"gacha": {
		"pivot": Vector2(1120.0, BUILDING_BASELINE_Y),
		"display_height": 360.0,
		"interaction_width": 190.0,
	},
	"lingpet_store": {
		"pivot": Vector2(1510.0, BUILDING_BASELINE_Y),
		"display_height": 370.0,
		"interaction_width": 210.0,
	},
	"blacksmith": {
		"pivot": Vector2(1900.0, BUILDING_BASELINE_Y),
		"display_height": 400.0,
		"interaction_width": 200.0,
	},
	"tavern": {
		"pivot": Vector2(2290.0, BUILDING_BASELINE_Y),
		"display_height": 350.0,
		"interaction_width": 190.0,
	},
	"academy": {
		"pivot": Vector2(2680.0, BUILDING_BASELINE_Y),
		"display_height": 420.0,
		"interaction_width": 220.0,
	},
}

static var _prewarm_index := 0
static var _prewarm_stage_id := -1
static var _prewarm_status: Dictionary = {}
static var _manifest_cache: Dictionary = {}
static var _building_specs_cache: Dictionary = {}


static func reset_for_test() -> void:
	_prewarm_index = 0
	_prewarm_stage_id = -1
	_prewarm_status.clear()
	_manifest_cache.clear()
	_building_specs_cache.clear()


static func get_prewarm_status() -> Dictionary:
	return _prewarm_status.duplicate(true)


static func prewarm_assets_step(stage_id: int = 1, use_threaded_texture_loads: bool = true) -> bool:
	var normalized_stage := PlazaThemeCatalog.normalize_stage_id(stage_id)
	if _prewarm_stage_id != normalized_stage:
		_prewarm_stage_id = normalized_stage
		_prewarm_index = 0
		_prewarm_status.clear()

	var paths: Array[String] = get_prewarm_texture_paths(normalized_stage)
	if _prewarm_index >= paths.size():
		_prewarm_status["stage_id"] = normalized_stage
		_prewarm_status["complete"] = true
		_prewarm_index = 0
		return true

	var path := paths[_prewarm_index]
	var result: Dictionary
	if use_threaded_texture_loads:
		result = ProjectResourceLoader.prewarm_texture_threaded_step(
			path,
			"Missing plaza texture",
			"Failed to load plaza texture",
			ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_MSEC,
			ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_POLLS,
			false,
			true
		)
	else:
		result = {"done": true, "texture": ProjectResourceLoader.load_imported_texture(path)}
	if not bool(result.get("done", false)):
		return false
	_prewarm_status[path] = result.get("texture", null) is Texture2D
	_prewarm_index += 1
	if _prewarm_index >= paths.size():
		_building_specs_cache[normalized_stage] = build_building_specs(normalized_stage)
		_prewarm_status["stage_id"] = normalized_stage
		_prewarm_status["complete"] = true
		_prewarm_index = 0
		return true
	return false


static func get_prewarm_texture_paths(stage_id: int = 1) -> Array[String]:
	var _theme: Dictionary = PlazaThemeCatalog.get_theme(stage_id)
	var paths: Array[String] = []
	for key in FLOOR_KEYS.keys():
		paths.append(str(FLOOR_KEYS[key]))
	for manifest_path in BUILDING_MANIFEST_PATHS:
		var manifest := load_manifest(str(manifest_path))
		var layers: Dictionary = _get_dictionary(manifest.get("layers", {}))
		for layer_key in ["base", "sign_emissive", "window_glow_mask"]:
			var layer: Dictionary = _get_dictionary(layers.get(layer_key, {}))
			var path := str(layer.get("res_path", ""))
			if path != "":
				paths.append(path)
	return paths


static func load_floor_textures(_stage_id: int = 1) -> Dictionary:
	var textures: Dictionary = {}
	for key in FLOOR_KEYS.keys():
		textures[key] = ProjectResourceLoader.load_imported_texture(str(FLOOR_KEYS[key]))
	return textures


static func build_building_specs(stage_id: int = 1) -> Array[Dictionary]:
	var normalized_stage := PlazaThemeCatalog.normalize_stage_id(stage_id)
	if _building_specs_cache.has(normalized_stage):
		return _duplicate_spec_array(_building_specs_cache[normalized_stage])

	var specs: Array[Dictionary] = []
	for manifest_path in BUILDING_MANIFEST_PATHS:
		var manifest := load_manifest(str(manifest_path))
		if manifest.is_empty():
			continue
		var building_type := str(manifest.get("building_type", ""))
		if not BUILDING_LAYOUT.has(building_type):
			continue
		var layout: Dictionary = _get_dictionary(BUILDING_LAYOUT[building_type])
		var pivot_pos := Vector2.ZERO
		var pivot_value: Variant = layout.get("pivot", Vector2.ZERO)
		if pivot_value is Vector2:
			pivot_pos = pivot_value as Vector2
		var source_size := _array_to_vector2(manifest.get("source_size", []), Vector2.ONE)
		var origin_pivot := _array_to_vector2(manifest.get("origin_pivot", []), source_size * 0.5)
		var fallback_display_height := float(manifest.get("display_height", round(source_size.y * float(manifest.get("display_scale", 1.0)))))
		var display_height: float = float(layout.get("display_height", fallback_display_height))
		var display_scale: float = display_height / max(1.0, source_size.y)
		var interaction_width := float(layout.get("interaction_width", max(140.0, source_size.x * display_scale * 0.38)))
		var interaction_rect := Rect2(
			Vector2(pivot_pos.x - interaction_width * 0.5, BUILDING_INTERACTION_TOP),
			Vector2(interaction_width, BUILDING_INTERACTION_HEIGHT)
		)
		var layers: Dictionary = _get_dictionary(manifest.get("layers", {}))
		specs.append({
			"type": building_type,
			"display_name": get_building_display_name(building_type),
			"pivot_pos": pivot_pos,
			"source_size": source_size,
			"origin_pivot": origin_pivot,
			"display_scale": display_scale,
			"display_height": int(round(display_height)),
			"collision_rect": Rect2(),
			"interaction_rect": interaction_rect,
			"visual_rect": Rect2(pivot_pos - origin_pivot * display_scale, source_size * display_scale),
			"y_sort_anchor": BUILDING_BASELINE_Y,
			"base_texture": _load_layer_texture(layers, "base"),
			"sign_texture": _load_layer_texture(layers, "sign_emissive"),
			"window_texture": _load_layer_texture(layers, "window_glow_mask"),
			"identity_emblem": _get_dictionary(manifest.get("identity_emblem", {})),
		})
	specs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("y_sort_anchor", 0.0)) < float(b.get("y_sort_anchor", 0.0)))
	_building_specs_cache[normalized_stage] = specs.duplicate(true)
	return specs


static func load_manifest(path: String) -> Dictionary:
	if _manifest_cache.has(path):
		return (_manifest_cache[path] as Dictionary).duplicate(true)
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_warning("Missing plaza building manifest: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("Invalid plaza building manifest JSON: %s" % path)
		return {}
	_manifest_cache[path] = (parsed as Dictionary).duplicate(true)
	return (parsed as Dictionary).duplicate(true)


static func get_building_display_name(building_type: String) -> String:
	match building_type:
		"shop":
			return "상점"
		"bank":
			return "은행"
		"gacha":
			return "가챠샵"
		"lingpet_store":
			return "링펫스토어"
		"blacksmith":
			return "대장간"
		"tavern":
			return "선술집"
		"academy":
			return "아카데미"
	return building_type


static func _load_layer_texture(layers: Dictionary, layer_key: String) -> Texture2D:
	var layer: Dictionary = _get_dictionary(layers.get(layer_key, {}))
	var path := str(layer.get("res_path", ""))
	if path == "":
		return null
	return ProjectResourceLoader.load_imported_texture(path)


static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary)
	return {}


static func _duplicate_spec_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for item in (value as Array):
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result


static func _array_to_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return fallback


static func _dictionary_to_rect(value: Variant) -> Rect2:
	if not (value is Dictionary):
		return Rect2()
	var dict := value as Dictionary
	return Rect2(
		Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0))),
		Vector2(float(dict.get("w", 0.0)), float(dict.get("h", 0.0)))
	)
