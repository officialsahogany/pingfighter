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

const INTERIOR_NPC_TEXTURE_PATHS := {
	"shop": "res://assets/ui/plaza/interior/plaza_lingpia_interior_npc_shop_mora_imagegen_v1.png",
	"bank": "res://assets/ui/plaza/interior/plaza_lingpia_interior_npc_bank_doyun_imagegen_v1.png",
	"gacha": "res://assets/ui/plaza/interior/plaza_lingpia_interior_npc_gacha_lumi_imagegen_v1.png",
	"lingpet_store": "res://assets/ui/plaza/interior/plaza_lingpia_interior_npc_lingpet_store_lingling_imagegen_v1.png",
	"blacksmith": "res://assets/ui/plaza/interior/plaza_lingpia_interior_npc_blacksmith_gangcheol_imagegen_v1.png",
	"tavern": "res://assets/ui/plaza/interior/plaza_lingpia_interior_npc_tavern_harang_imagegen_v1.png",
	"academy": "res://assets/ui/plaza/interior/plaza_lingpia_interior_npc_academy_seoyul_imagegen_v1.png",
}

const INTERIOR_ROOM_TEXTURE_PATHS := {
	"shop": "res://assets/ui/plaza/interior/plaza_stage1_interior_shop_room_topview_imagegen_v2.png",
}

const INTERIOR_OBJECT_TEXTURE_PATHS := {
	"crystal": "res://assets/ui/plaza/interior/plaza_stage1_interior_shop_object_crystal_imagegen_v1.png",
	"capsule": "res://assets/ui/plaza/interior/plaza_stage1_interior_shop_object_capsule_imagegen_v1.png",
	"sell": "res://assets/ui/plaza/interior/plaza_stage1_interior_shop_object_sell_device_imagegen_v1.png",
	"money_bundle": "res://assets/ui/plaza/interior/plaza_shop_strewn_money_bundle_autosprite_static_v1.png",
	"coin_pile": "res://assets/ui/plaza/interior/plaza_shop_strewn_coin_pile_autosprite_static_v1.png",
	"gear": "res://assets/ui/plaza/interior/plaza_shop_strewn_gear_autosprite_static_v1.png",
	"wrench_tool": "res://assets/ui/plaza/interior/plaza_shop_strewn_wrench_tool_autosprite_static_v1.png",
	"data_cube": "res://assets/ui/plaza/interior/plaza_shop_strewn_data_cube_autosprite_static_v1.png",
	"circuit_gadget": "res://assets/ui/plaza/interior/plaza_shop_strewn_circuit_gadget_autosprite_static_v1.png",
	"money_bundle_anim": "res://assets/ui/plaza/interior/plaza_shop_strewn_money_bundle_autosprite_anim_sheet_v1.png",
	"coin_pile_anim": "res://assets/ui/plaza/interior/plaza_shop_strewn_coin_pile_autosprite_anim_sheet_v1.png",
	"gear_anim": "res://assets/ui/plaza/interior/plaza_shop_strewn_gear_autosprite_anim_sheet_v1.png",
	"wrench_tool_anim": "res://assets/ui/plaza/interior/plaza_shop_strewn_wrench_tool_autosprite_anim_sheet_v1.png",
	"data_cube_anim": "res://assets/ui/plaza/interior/plaza_shop_strewn_data_cube_autosprite_anim_sheet_v1.png",
	"circuit_gadget_anim": "res://assets/ui/plaza/interior/plaza_shop_strewn_circuit_gadget_autosprite_anim_sheet_v1.png",
}

const PLAZA_PLAYER_GRID_COLS := 4
const PLAZA_PLAYER_GRID_ROWS := 2
const PLAZA_PLAYER_FRAME_COUNT := 8
const PLAZA_PLAYER_SPRITE_PATHS := {
	"smasher": {
		"idle": "res://assets/sprites/characters/smasher/smasher_subculture_idle_sheet.png",
		"walk_left": "res://assets/sprites/characters/smasher/smasher_subculture_left_walk_sheet.png",
		"walk_right": "res://assets/sprites/characters/smasher/smasher_subculture_right_walk_sheet.png",
	},
	"viper": {
		"idle": "res://assets/sprites/characters/viper/viper_subculture_idle_sheet.png",
		"walk_left": "res://assets/sprites/characters/viper/viper_subculture_left_walk_sheet.png",
		"walk_right": "res://assets/sprites/characters/viper/viper_subculture_right_walk_sheet.png",
	},
	"soldier": {
		"idle": "res://assets/sprites/characters/commando/commando_subculture_idle_sheet.png",
		"walk_left": "res://assets/sprites/characters/commando/commando_subculture_left_walk_sheet.png",
		"walk_right": "res://assets/sprites/characters/commando/commando_subculture_right_walk_sheet.png",
	},
}

const BUILDING_MANIFEST_PATHS := [
	"res://assets/ui/plaza/buildings/plaza_lingpia_shop_v1_manifest.json",
	"res://assets/ui/plaza/buildings/plaza_lingpia_bank_v1_manifest.json",
	"res://assets/ui/plaza/buildings/plaza_lingpia_gacha_v1_manifest.json",
	"res://assets/ui/plaza/buildings/plaza_lingpia_lingpet_store_v1_manifest.json",
	"res://assets/ui/plaza/buildings/plaza_lingpia_blacksmith_v1_manifest.json",
	"res://assets/ui/plaza/buildings/plaza_lingpia_tavern_v1_manifest.json",
	"res://assets/ui/plaza/buildings/plaza_lingpia_academy_v1_manifest.json",
]

# R1 production set. BUILDING_MANIFEST_PATHS remains a compatibility/rollback
# catalog for older tests and consumers; the live plaza uses this retained set.
const HWANGYEOK_BUILDING_ASSET_SET_ID := "hwangyeok_2d_v1"
const HWANGYEOK_MAP_WORLD_SIZE := Vector2(2400.0, 1500.0)
const HWANGYEOK_BUILDING_MANIFEST_PATHS := [
	"res://assets/ui/plaza/buildings/hwangyeok/plaza_hwangyeok_shop_3q_v1_manifest.json",
	"res://assets/ui/plaza/buildings/hwangyeok/plaza_hwangyeok_bank_3q_v1_manifest.json",
	"res://assets/ui/plaza/buildings/hwangyeok/plaza_hwangyeok_gacha_3q_v1_manifest.json",
	"res://assets/ui/plaza/buildings/hwangyeok/plaza_hwangyeok_lingpet_store_3q_v1_manifest.json",
	"res://assets/ui/plaza/buildings/hwangyeok/plaza_hwangyeok_blacksmith_3q_v1_manifest.json",
	"res://assets/ui/plaza/buildings/hwangyeok/plaza_hwangyeok_tavern_3q_v1_manifest.json",
	"res://assets/ui/plaza/buildings/hwangyeok/plaza_hwangyeok_academy_3q_v1_manifest.json",
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

const FLOOR_TEXTURE_ORDER := [
	"base_01",
	"base_02",
	"accent",
	"accent_emissive",
	"border",
	"border_emissive",
	"medallion",
	"medallion_emissive",
	"ground_strip",
	"ground_strip_emissive",
	"midground_wall",
	"far_sky",
	"accent_cutout",
	"accent_cutout_emissive",
	"medallion_cutout",
	"medallion_cutout_emissive",
]

const FLOOR_MANIFEST_KEYS := {
	"base_01": "base_01",
	"base_02": "base_02",
	"accent_neon": "accent",
	"border_dancheong": "border",
	"special_medallion": "medallion",
}

const FLOOR_EMISSIVE_MANIFEST_KEYS := {
	"accent_neon_emissive": "accent_emissive",
	"border_dancheong_emissive": "border_emissive",
	"special_medallion_emissive": "medallion_emissive",
}

const PARALLAX_MANIFEST_KEYS := {
	"ground": "ground_strip",
	"ground_emissive": "ground_strip_emissive",
	"midground": "midground_wall",
	"sky": "far_sky",
	"accent_cutout": "accent_cutout",
	"accent_cutout_emissive": "accent_cutout_emissive",
	"medallion_cutout": "medallion_cutout",
	"medallion_cutout_emissive": "medallion_cutout_emissive",
}

const BUILDING_BASELINE_Y := 640.0
const BUILDING_INTERACTION_TOP := 570.0
const BUILDING_INTERACTION_HEIGHT := 118.0
const DEFAULT_WORLD_WIDTH := 1900.0
const BUILDING_LEFT_MARGIN := 300.0
const BUILDING_EXIT_BUFFER := 220.0
const BUILDING_MIN_GAP := 32.0
const BUILDING_MAX_GAP := 360.0
const RANDOM_BUILDING_MIN_COUNT := 2
const RANDOM_BUILDING_MAX_COUNT := 5
const REQUIRED_BUILDING_TYPES := ["bank"]
const CHANCE_BUILDING_TYPES := [
	{"type": "academy", "chance": 0.50},
	{"type": "shop", "chance": 0.40},
	{"type": "gacha", "chance": 0.40},
]
const FILLER_BUILDING_TYPES := ["blacksmith", "tavern", "lingpet_store"]
const FULL_LAYOUT_BUILDING_ORDER := ["shop", "bank", "gacha", "lingpet_store", "blacksmith", "tavern", "academy"]

const BUILDING_LAYOUT := {
	"shop": {
		"display_height": 220.0,
		"interaction_width": 150.0,
	},
	"bank": {
		"display_height": 280.0,
		"interaction_width": 170.0,
	},
	"gacha": {
		"display_height": 250.0,
		"interaction_width": 165.0,
	},
	"lingpet_store": {
		"display_height": 250.0,
		"interaction_width": 170.0,
	},
	"blacksmith": {
		"display_height": 300.0,
		"interaction_width": 180.0,
	},
	"tavern": {
		"display_height": 220.0,
		"interaction_width": 150.0,
	},
	"academy": {
		"display_height": 300.0,
		"interaction_width": 180.0,
	},
}

static var _prewarm_index := 0
static var _prewarm_stage_id := -1
static var _prewarm_status: Dictionary = {}
static var _building_prewarm_states: Dictionary = {}
static var _manifest_cache: Dictionary = {}
static var _building_specs_cache: Dictionary = {}
static var _hwangyeok_building_specs_cache: Dictionary = {}
static var _player_texture_cache: Dictionary = {}
static var _interior_npc_texture_cache: Dictionary = {}
static var _interior_room_texture_cache: Dictionary = {}
static var _interior_object_texture_cache: Dictionary = {}


static func reset_for_test() -> void:
	_prewarm_index = 0
	_prewarm_stage_id = -1
	_prewarm_status.clear()
	_building_prewarm_states.clear()
	_manifest_cache.clear()
	_building_specs_cache.clear()
	_hwangyeok_building_specs_cache.clear()
	_player_texture_cache.clear()
	_interior_npc_texture_cache.clear()
	_interior_room_texture_cache.clear()
	_interior_object_texture_cache.clear()


static func invalidate_hwangyeok_building_specs_cache() -> void:
	# The spec cache retains Texture2D objects. A project resource-cache reset can
	# replace their RIDs, so the GPU prewarmer must rebuild specs from the current
	# 21-path cache before sealing the replacement identities.
	_hwangyeok_building_specs_cache.clear()


static func get_prewarm_status() -> Dictionary:
	return _prewarm_status.duplicate(true)


static func get_building_prewarm_status(prewarm_key: String = HWANGYEOK_BUILDING_ASSET_SET_ID) -> Dictionary:
	var state_value: Variant = _building_prewarm_states.get(prewarm_key, {})
	if not (state_value is Dictionary):
		return {}
	var state := state_value as Dictionary
	var status_value: Variant = state.get("status", {})
	return (status_value as Dictionary).duplicate(true) if status_value is Dictionary else {}


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
		_prewarm_status["stage_id"] = normalized_stage
		_prewarm_status["complete"] = true
		_prewarm_index = 0
		return true
	return false


static func get_prewarm_texture_paths(stage_id: int = 1) -> Array[String]:
	var _theme: Dictionary = PlazaThemeCatalog.get_theme(stage_id)
	var paths: Array[String] = []
	var floor_paths := resolve_floor_texture_paths(stage_id)
	for key in FLOOR_TEXTURE_ORDER:
		var path := str(floor_paths.get(key, ""))
		if path != "":
			paths.append(path)
	for character_type in PLAZA_PLAYER_SPRITE_PATHS.keys():
		var player_paths: Dictionary = PLAZA_PLAYER_SPRITE_PATHS.get(character_type, {})
		for key in ["idle", "walk_left", "walk_right"]:
			var path := str(player_paths.get(key, ""))
			if path != "":
				paths.append(path)
	for path in INTERIOR_NPC_TEXTURE_PATHS.values():
		if str(path) != "":
			paths.append(str(path))
	for path in INTERIOR_ROOM_TEXTURE_PATHS.values():
		if str(path) != "":
			paths.append(str(path))
	for path in INTERIOR_OBJECT_TEXTURE_PATHS.values():
		if str(path) != "":
			paths.append(str(path))
	# Building layers are owned by PlazaMapWorldHost ->
	# PlazaBuildingRenderer and are prewarmed through that production chain.
	return paths


static func get_hwangyeok_building_manifest_paths() -> Array[String]:
	var paths: Array[String] = []
	for path_value in HWANGYEOK_BUILDING_MANIFEST_PATHS:
		paths.append(str(path_value))
	return paths


static func get_building_layer_texture_paths(manifest_paths: Array) -> Array[String]:
	var paths: Array[String] = []
	for manifest_path_value in manifest_paths:
		var manifest := load_manifest(str(manifest_path_value))
		var layers: Dictionary = _get_dictionary(manifest.get("layers", {}))
		for layer_key in ["base", "sign_emissive", "window_glow_mask"]:
			var layer: Dictionary = _get_dictionary(layers.get(layer_key, {}))
			var path := str(layer.get("res_path", ""))
			if path != "":
				paths.append(path)
	return paths


static func get_hwangyeok_building_prewarm_texture_paths() -> Array[String]:
	return get_building_layer_texture_paths(get_hwangyeok_building_manifest_paths())


static func prewarm_building_assets_step(
	manifest_paths: Array,
	use_threaded_texture_loads: bool = true,
	prewarm_key: String = HWANGYEOK_BUILDING_ASSET_SET_ID
) -> bool:
	var paths := get_building_layer_texture_paths(manifest_paths)
	var expected_path_count := manifest_paths.size() * 3
	var signature := "\n".join(PackedStringArray(paths))
	var state_value: Variant = _building_prewarm_states.get(prewarm_key, {})
	var state: Dictionary = state_value as Dictionary if state_value is Dictionary else {}
	if str(state.get("signature", "")) != signature:
		state = {
			"signature": signature,
			"index": 0,
			"status": {
				"asset_set_id": prewarm_key,
				"complete": false,
				"expected_path_count": expected_path_count,
				"path_count": paths.size(),
			},
		}
		_building_prewarm_states[prewarm_key] = state

	var status_value: Variant = state.get("status", {})
	var status: Dictionary = status_value as Dictionary if status_value is Dictionary else {}
	if expected_path_count <= 0 or paths.size() != expected_path_count:
		status["complete"] = false
		status["invalid_manifest_set"] = true
		state["status"] = status
		_building_prewarm_states[prewarm_key] = state
		return false
	status.erase("invalid_manifest_set")

	var index := int(state.get("index", 0))
	if index >= paths.size():
		status["complete"] = true
		state["status"] = status
		_building_prewarm_states[prewarm_key] = state
		return true

	var path := paths[index]
	var result: Dictionary
	if use_threaded_texture_loads:
		result = ProjectResourceLoader.prewarm_texture_threaded_step(
			path,
			"Missing plaza building texture",
			"Failed to load plaza building texture",
			ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_MSEC,
			ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_POLLS,
			false,
			true
		)
	else:
		result = {"done": true, "texture": ProjectResourceLoader.load_imported_texture(path)}
	if not bool(result.get("done", false)):
		return false
	var loaded := result.get("texture", null) is Texture2D
	status[path] = loaded
	if not loaded:
		status["complete"] = false
		status["failed_path"] = path
		state["status"] = status
		_building_prewarm_states[prewarm_key] = state
		return false
	status.erase("failed_path")
	index += 1
	state["index"] = index
	status["complete"] = index >= paths.size()
	state["status"] = status
	_building_prewarm_states[prewarm_key] = state
	return bool(status.get("complete", false))


static func load_floor_textures(stage_id: int = 1) -> Dictionary:
	var textures: Dictionary = {}
	var paths := resolve_floor_texture_paths(stage_id)
	for key in FLOOR_TEXTURE_ORDER:
		var path := str(paths.get(key, ""))
		textures[key] = ProjectResourceLoader.load_imported_texture(path) if path != "" else null
	return textures


static func normalize_player_character_type(character_type: Variant) -> String:
	var value := str(character_type).strip_edges().to_lower()
	match value:
		"", "mika", "미카", "smasher":
			return "smasher"
		"serin", "세린", "viper":
			return "viper"
		"rena", "레나", "commando", "soldier":
			return "soldier"
		"io", "이오", "optimus":
			return "optimus"
		"kohaku", "코하쿠", "baltor":
			return "baltor"
		_:
			return value


static func load_player_textures(character_type: Variant) -> Dictionary:
	var normalized := normalize_player_character_type(character_type)
	if _player_texture_cache.has(normalized):
		return (_player_texture_cache.get(normalized, {}) as Dictionary).duplicate(false)
	var paths: Dictionary = PLAZA_PLAYER_SPRITE_PATHS.get(normalized, {})
	var textures := {
		"character_type": normalized,
		"idle": null,
		"walk_left": null,
		"walk_right": null,
		"grid_cols": PLAZA_PLAYER_GRID_COLS,
		"grid_rows": PLAZA_PLAYER_GRID_ROWS,
		"frame_count": PLAZA_PLAYER_FRAME_COUNT,
	}
	for key in ["idle", "walk_left", "walk_right"]:
		var path := str(paths.get(key, ""))
		textures[key] = ProjectResourceLoader.load_texture(path) if path != "" else null
	textures["has_sprite"] = (
		textures.get("idle", null) is Texture2D
		or textures.get("walk_left", null) is Texture2D
		or textures.get("walk_right", null) is Texture2D
	)
	_player_texture_cache[normalized] = textures.duplicate(false)
	return textures.duplicate(false)


static func load_interior_npc_textures() -> Dictionary:
	if not _interior_npc_texture_cache.is_empty():
		return _interior_npc_texture_cache.duplicate(false)
	var textures := {}
	for building_type in INTERIOR_NPC_TEXTURE_PATHS.keys():
		var path := str(INTERIOR_NPC_TEXTURE_PATHS.get(building_type, ""))
		textures[building_type] = ProjectResourceLoader.load_imported_texture(path) if path != "" else null
	_interior_npc_texture_cache = textures.duplicate(false)
	return textures.duplicate(false)


static func load_interior_room_textures() -> Dictionary:
	if not _interior_room_texture_cache.is_empty():
		return _interior_room_texture_cache.duplicate(false)
	var textures := {}
	for building_type in INTERIOR_ROOM_TEXTURE_PATHS.keys():
		var path := str(INTERIOR_ROOM_TEXTURE_PATHS.get(building_type, ""))
		textures[building_type] = ProjectResourceLoader.load_imported_texture(path) if path != "" else null
	_interior_room_texture_cache = textures.duplicate(false)
	return textures.duplicate(false)


static func load_interior_object_textures() -> Dictionary:
	if not _interior_object_texture_cache.is_empty():
		return _interior_object_texture_cache.duplicate(false)
	var textures := {}
	for object_kind in INTERIOR_OBJECT_TEXTURE_PATHS.keys():
		var path := str(INTERIOR_OBJECT_TEXTURE_PATHS.get(object_kind, ""))
		textures[object_kind] = ProjectResourceLoader.load_imported_texture(path) if path != "" else null
	_interior_object_texture_cache = textures.duplicate(false)
	return textures.duplicate(false)


static func get_interior_npc_texture_paths_for_test() -> Dictionary:
	return INTERIOR_NPC_TEXTURE_PATHS.duplicate(true)


static func get_interior_room_texture_paths_for_test() -> Dictionary:
	return INTERIOR_ROOM_TEXTURE_PATHS.duplicate(true)


static func get_interior_object_texture_paths_for_test() -> Dictionary:
	return INTERIOR_OBJECT_TEXTURE_PATHS.duplicate(true)


static func get_player_texture_paths_for_test(character_type: Variant) -> Dictionary:
	var normalized := normalize_player_character_type(character_type)
	var paths: Dictionary = PLAZA_PLAYER_SPRITE_PATHS.get(normalized, {})
	var result := {"character_type": normalized}
	for key in ["idle", "walk_left", "walk_right"]:
		result[key] = str(paths.get(key, ""))
	return result


static func resolve_floor_texture_paths(stage_id: int = 1) -> Dictionary:
	var normalized_stage := PlazaThemeCatalog.normalize_stage_id(stage_id)
	var paths := FLOOR_KEYS.duplicate(true)
	_apply_manifest_assets_to_paths(
		paths,
		_get_stage_floor_manifest_path(normalized_stage),
		"assets",
		FLOOR_MANIFEST_KEYS
	)
	_apply_manifest_assets_to_paths(
		paths,
		_get_stage_floor_manifest_path(normalized_stage),
		"emissive_overlays",
		FLOOR_EMISSIVE_MANIFEST_KEYS
	)
	_apply_manifest_assets_to_paths(
		paths,
		_get_stage_parallax_manifest_path(normalized_stage),
		"assets",
		PARALLAX_MANIFEST_KEYS
	)
	return paths


static func get_floor_texture_paths_for_test(stage_id: int = 1) -> Dictionary:
	return resolve_floor_texture_paths(stage_id).duplicate(true)


static func build_building_specs(
	stage_id: int = 1,
	map_seed: int = 0,
	world_width: float = DEFAULT_WORLD_WIDTH,
	full_layout_for_test: bool = false,
	force_tavern: bool = false
) -> Array[Dictionary]:
	var normalized_stage := PlazaThemeCatalog.normalize_stage_id(stage_id)
	var cache_key := _building_specs_cache_key(normalized_stage, map_seed, world_width, full_layout_for_test, force_tavern)
	if _building_specs_cache.has(cache_key):
		return _duplicate_spec_array(_building_specs_cache[cache_key])

	var selected_types := _select_building_types(normalized_stage, map_seed, full_layout_for_test, force_tavern)
	var specs: Array[Dictionary] = []
	for manifest_path in BUILDING_MANIFEST_PATHS:
		var manifest := load_manifest(str(manifest_path))
		if manifest.is_empty():
			continue
		var building_type := str(manifest.get("building_type", ""))
		if not BUILDING_LAYOUT.has(building_type):
			continue
		if not selected_types.has(building_type):
			continue
		var layout: Dictionary = _get_dictionary(BUILDING_LAYOUT[building_type])
		var source_size := _array_to_vector2(manifest.get("source_size", []), Vector2.ONE)
		var origin_pivot := _array_to_vector2(manifest.get("origin_pivot", []), source_size * 0.5)
		var fallback_display_height := float(manifest.get("display_height", round(source_size.y * float(manifest.get("display_scale", 1.0)))))
		var display_height: float = float(layout.get("display_height", fallback_display_height))
		var display_scale: float = display_height / max(1.0, source_size.y)
		var interaction_width := float(layout.get("interaction_width", max(140.0, source_size.x * display_scale * 0.38)))
		var layers: Dictionary = _get_dictionary(manifest.get("layers", {}))
		specs.append({
			"type": building_type,
			"display_name": get_building_display_name(building_type),
			"pivot_pos": Vector2.ZERO,
			"source_size": source_size,
			"origin_pivot": origin_pivot,
			"display_scale": display_scale,
			"display_height": int(round(display_height)),
			"interaction_width": interaction_width,
			"collision_rect": Rect2(),
			"interaction_rect": Rect2(),
			"visual_rect": Rect2(),
			"y_sort_anchor": BUILDING_BASELINE_Y,
			"base_texture": _load_layer_texture(layers, "base"),
			"sign_texture": _load_layer_texture(layers, "sign_emissive"),
			"window_texture": _load_layer_texture(layers, "window_glow_mask"),
			"identity_emblem": _get_dictionary(manifest.get("identity_emblem", {})),
		})
	specs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return selected_types.find(str(a.get("type", ""))) < selected_types.find(str(b.get("type", ""))))
	_apply_building_positions(specs, normalized_stage, map_seed, max(world_width, 760.0), full_layout_for_test)
	_building_specs_cache[cache_key] = specs.duplicate(true)
	return specs


# R1 production Hwangyeok building path. Its cache key uses only fixed
# map-world inputs; viewport, safe-rect, fit scale, and window size must never
# be added here.
static func build_hwangyeok_building_specs(
	stage_id: int = 1,
	map_seed: int = 0,
	full_layout_for_test: bool = false,
	force_tavern: bool = false
) -> Array[Dictionary]:
	var normalized_stage := PlazaThemeCatalog.normalize_stage_id(stage_id)
	var cache_key := "%s:%d:%d:%d:%d:%d" % [
		HWANGYEOK_BUILDING_ASSET_SET_ID,
		normalized_stage,
		map_seed,
		int(HWANGYEOK_MAP_WORLD_SIZE.x),
		1 if full_layout_for_test else 0,
		1 if force_tavern else 0,
	]
	if _hwangyeok_building_specs_cache.has(cache_key):
		return _duplicate_spec_array(_hwangyeok_building_specs_cache[cache_key])

	var selected_types := _select_building_types(normalized_stage, map_seed, full_layout_for_test, force_tavern)
	var specs: Array[Dictionary] = []
	for manifest_path_value in HWANGYEOK_BUILDING_MANIFEST_PATHS:
		var manifest_path := str(manifest_path_value)
		var manifest := load_manifest(manifest_path)
		if manifest.is_empty():
			continue
		var building_type := str(manifest.get("building_type", ""))
		if not BUILDING_LAYOUT.has(building_type) or not selected_types.has(building_type):
			continue
		var layout: Dictionary = _get_dictionary(BUILDING_LAYOUT[building_type])
		var source_size := _array_to_vector2(manifest.get("source_size", []), Vector2.ONE)
		var origin_pivot := _array_to_vector2(manifest.get("origin_pivot", []), source_size * 0.5)
		var display_height: float = float(manifest.get("display_height", source_size.y))
		var display_scale: float = display_height / max(1.0, source_size.y)
		var interaction_width: float = float(layout.get("interaction_width", max(140.0, source_size.x * display_scale * 0.38)))
		var layers: Dictionary = _get_dictionary(manifest.get("layers", {}))
		var sign_glow_color := _manifest_color(manifest, "sign_glow_color", Color.WHITE)
		var window_glow_color := _manifest_color(manifest, "window_glow_color", Color(1.0, 0.93, 0.78, 1.0))
		specs.append({
			"type": building_type,
			"display_name": get_building_display_name(building_type),
			"asset_set_id": HWANGYEOK_BUILDING_ASSET_SET_ID,
			"asset_id": str(manifest.get("asset_id", "")),
			"manifest_path": manifest_path,
			"pivot_pos": Vector2.ZERO,
			"source_size": source_size,
			"runtime_texture_size": _array_to_vector2(manifest.get("runtime_texture_size", []), Vector2(512.0, 512.0)),
			"origin_pivot": origin_pivot,
			"display_scale": display_scale,
			"display_height": int(round(display_height)),
			"interaction_width": interaction_width,
			"collision_rect": Rect2(),
			"interaction_rect": Rect2(),
			"visual_rect": Rect2(),
			"y_sort_anchor": BUILDING_BASELINE_Y,
			"base_texture": _load_layer_texture(layers, "base"),
			"sign_texture": _load_layer_texture(layers, "sign_emissive"),
			"window_texture": _load_layer_texture(layers, "window_glow_mask"),
			"sign_glow_color": sign_glow_color,
			"window_glow_color": window_glow_color,
			"sign_glow_strength": maxf(0.0, float(manifest.get("sign_glow_strength", 1.0))),
			"window_glow_strength": maxf(0.0, float(manifest.get("window_glow_strength", 1.0))),
			"marker_color": window_glow_color,
			"identity_emblem": _get_dictionary(manifest.get("identity_emblem", {})),
			"coordinate_contract": _get_dictionary(manifest.get("coordinate_contract", {})).duplicate(true),
			"ground_anchor_chord": _array_to_vector2_list(manifest.get("ground_anchor_chord", [])),
			"footprint_polygon": _array_to_vector2_list(manifest.get("footprint_polygon", [])),
			"footprint_polygon_order": str(manifest.get("footprint_polygon_order", "")),
			"footprint_art_reference": _get_dictionary(manifest.get("footprint_art_reference", {})).duplicate(true),
			"entrance_anchor": _array_to_vector2(manifest.get("entrance_anchor", []), origin_pivot),
			"entrance_anchor_offset": _array_to_vector2(manifest.get("entrance_anchor_offset", []), Vector2.ZERO),
			"entrance_normal": _array_to_vector2(manifest.get("entrance_normal", []), Vector2(-1.0, 0.5)),
			"sort_anchor": _array_to_vector2(manifest.get("sort_anchor", []), Vector2.ZERO),
			"label_anchor": _array_to_vector2(manifest.get("label_anchor", []), Vector2.ZERO),
			"label_anchor_source_pixels": _array_to_vector2(manifest.get("label_anchor_source_pixels", []), Vector2.ZERO),
			"label_rect_rule": str(manifest.get("label_rect_rule", "")),
			"plot_class": str(manifest.get("plot_class", "")),
			"hierarchy_rank": int(manifest.get("hierarchy_rank", 0)),
			"approach_side": str(manifest.get("approach_side", "")),
			"road_side_clearance": _get_dictionary(manifest.get("road_side_clearance", {})).duplicate(true),
			"occlusion_band": (manifest.get("occlusion_band", []) as Array).duplicate(true) if manifest.get("occlusion_band", []) is Array else [],
			"allow_rotation": bool(manifest.get("allow_rotation", false)),
			"allow_mirror": bool(manifest.get("allow_mirror", false)),
			"plot_tags": (manifest.get("plot_tags", []) as Array).duplicate(true) if manifest.get("plot_tags", []) is Array else [],
			"entrance_access_corridor": _get_dictionary(manifest.get("entrance_access_corridor", {})).duplicate(true),
		})
	specs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return selected_types.find(str(a.get("type", ""))) < selected_types.find(str(b.get("type", ""))))
	_apply_building_positions(specs, normalized_stage, map_seed, HWANGYEOK_MAP_WORLD_SIZE.x, full_layout_for_test)
	_hwangyeok_building_specs_cache[cache_key] = specs.duplicate(true)
	return specs


# R0 compatibility alias retained for focused candidate QA and older callers.
static func build_hwangyeok_building_specs_for_preview(
	stage_id: int = 1,
	map_seed: int = 0,
	full_layout_for_test: bool = false,
	force_tavern: bool = false
) -> Array[Dictionary]:
	return build_hwangyeok_building_specs(
		stage_id,
		map_seed,
		full_layout_for_test,
		force_tavern
	)


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


static func _building_specs_cache_key(
	stage_id: int,
	map_seed: int,
	world_width: float,
	full_layout_for_test: bool,
	force_tavern: bool
) -> String:
	return "%d:%d:%d:%d:%d" % [
		stage_id,
		map_seed,
		int(round(world_width)),
		1 if full_layout_for_test else 0,
		1 if force_tavern else 0,
	]


static func _select_building_types(
	stage_id: int,
	map_seed: int,
	full_layout_for_test: bool,
	force_tavern: bool
) -> Array:
	if full_layout_for_test:
		return FULL_LAYOUT_BUILDING_ORDER.duplicate()
	var rng := _build_layout_rng(stage_id, map_seed)
	var selected: Array = []
	for building_type in REQUIRED_BUILDING_TYPES:
		_append_unique(selected, str(building_type))
	if force_tavern:
		_append_unique(selected, "tavern")
	var target_count := rng.randi_range(RANDOM_BUILDING_MIN_COUNT, RANDOM_BUILDING_MAX_COUNT)
	target_count = clampi(maxi(target_count, selected.size()), RANDOM_BUILDING_MIN_COUNT, RANDOM_BUILDING_MAX_COUNT)
	for chance_value in CHANCE_BUILDING_TYPES:
		var chance: Dictionary = _get_dictionary(chance_value)
		var building_type := str(chance.get("type", ""))
		if building_type == "" or selected.has(building_type):
			continue
		if rng.randf() < float(chance.get("chance", 0.0)):
			_append_unique(selected, building_type)
	target_count = clampi(maxi(target_count, selected.size()), RANDOM_BUILDING_MIN_COUNT, RANDOM_BUILDING_MAX_COUNT)
	var fillers: Array = FILLER_BUILDING_TYPES.duplicate()
	_shuffle_array(fillers, rng)
	for filler_value in fillers:
		if selected.size() >= target_count:
			break
		_append_unique(selected, str(filler_value))
	var remaining_pool: Array = []
	for building_type in FULL_LAYOUT_BUILDING_ORDER:
		if not selected.has(str(building_type)):
			remaining_pool.append(str(building_type))
	_shuffle_array(remaining_pool, rng)
	for building_type in remaining_pool:
		if selected.size() >= RANDOM_BUILDING_MIN_COUNT:
			break
		_append_unique(selected, str(building_type))
	var bank_index := selected.find("bank")
	if bank_index > 0:
		selected.remove_at(bank_index)
		selected.insert(0, "bank")
	var rest := selected.slice(1)
	_shuffle_array(rest, rng)
	var ordered: Array = ["bank"]
	for value in rest:
		ordered.append(str(value))
	return ordered


static func _apply_building_positions(
	specs: Array[Dictionary],
	stage_id: int,
	map_seed: int,
	world_width: float,
	full_layout_for_test: bool
) -> void:
	if specs.is_empty():
		return
	var rng: RandomNumberGenerator = _build_layout_rng(stage_id + 17, map_seed + (1 if full_layout_for_test else 0))
	var left_margin: float = min(BUILDING_LEFT_MARGIN, max(180.0, world_width * 0.18))
	var exit_buffer: float = min(BUILDING_EXIT_BUFFER, max(160.0, world_width * 0.12))
	var usable_width: float = max(360.0, world_width - left_margin - exit_buffer)
	var total_interaction_width := 0.0
	for spec in specs:
		total_interaction_width += float(spec.get("interaction_width", 160.0))
	var gap_count := maxi(0, specs.size() - 1)
	var gaps: Array[float] = []
	if gap_count > 0:
		var min_gap_total: float = BUILDING_MIN_GAP * float(gap_count)
		var extra_gap: float = max(0.0, usable_width - total_interaction_width - min_gap_total)
		var weights: Array[float] = []
		var weight_total := 0.0
		for _idx in range(gap_count):
			var weight := rng.randf_range(0.35, 1.85)
			weights.append(weight)
			weight_total += weight
		for idx in range(gap_count):
			var organic_extra: float = extra_gap * float(weights[idx]) / max(0.001, weight_total)
			gaps.append(clampf(BUILDING_MIN_GAP + organic_extra, BUILDING_MIN_GAP, BUILDING_MAX_GAP))
	var total_gap := 0.0
	for gap in gaps:
		total_gap += float(gap)
	var layout_width: float = total_interaction_width + total_gap
	var start_x: float = left_margin
	if layout_width < usable_width:
		start_x += rng.randf_range(0.0, max(0.0, usable_width - layout_width) * 0.35)
	var cursor_left: float = start_x
	for idx in range(specs.size()):
		var spec: Dictionary = specs[idx]
		var interaction_width: float = float(spec.get("interaction_width", 160.0))
		var pivot_pos := Vector2(cursor_left + interaction_width * 0.5, BUILDING_BASELINE_Y)
		var source_size: Vector2 = spec.get("source_size", Vector2.ONE)
		var origin_pivot: Vector2 = spec.get("origin_pivot", source_size * 0.5)
		var display_scale: float = float(spec.get("display_scale", 1.0))
		spec["pivot_pos"] = pivot_pos
		spec["interaction_rect"] = Rect2(
			Vector2(pivot_pos.x - interaction_width * 0.5, BUILDING_INTERACTION_TOP),
			Vector2(interaction_width, BUILDING_INTERACTION_HEIGHT)
		)
		spec["visual_rect"] = Rect2(pivot_pos - origin_pivot * display_scale, source_size * display_scale)
		spec["y_sort_anchor"] = BUILDING_BASELINE_Y
		cursor_left += interaction_width
		if idx < gaps.size():
			cursor_left += float(gaps[idx])


static func _build_layout_rng(stage_id: int, map_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var safe_seed := map_seed if map_seed > 0 else int(abs(hash("plaza:%d" % stage_id)))
	rng.seed = int(abs(hash("%d:%d" % [stage_id, safe_seed])))
	return rng


static func _append_unique(target: Array, value: String) -> void:
	if value == "" or target.has(value):
		return
	target.append(value)


static func _shuffle_array(values: Array, rng: RandomNumberGenerator) -> void:
	for idx in range(values.size() - 1, 0, -1):
		var swap_idx := rng.randi_range(0, idx)
		var temp: Variant = values[idx]
		values[idx] = values[swap_idx]
		values[swap_idx] = temp


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


static func _get_stage_floor_manifest_path(stage_id: int) -> String:
	var normalized_stage := PlazaThemeCatalog.normalize_stage_id(stage_id)
	var slug := PlazaThemeCatalog.get_asset_slug(normalized_stage)
	return "res://assets/ui/plaza/plaza_stage%d_floor_tiles_%s_v1_manifest.json" % [normalized_stage, slug]


static func _get_stage_parallax_manifest_path(stage_id: int) -> String:
	var normalized_stage := PlazaThemeCatalog.normalize_stage_id(stage_id)
	var slug := PlazaThemeCatalog.get_asset_slug(normalized_stage)
	return "res://assets/ui/plaza/plaza_stage%d_sidescroll_parallax_layers_%s_v1_manifest.json" % [normalized_stage, slug]


static func _apply_manifest_assets_to_paths(
	paths: Dictionary,
	manifest_path: String,
	collection_key: String,
	id_to_path_key: Dictionary
) -> void:
	var manifest := _load_optional_manifest(manifest_path)
	if manifest.is_empty():
		return
	var entries: Variant = manifest.get(collection_key, [])
	if not (entries is Array):
		return
	for entry_value in (entries as Array):
		if not (entry_value is Dictionary):
			continue
		var entry := entry_value as Dictionary
		var manifest_id := str(entry.get("id", ""))
		if not id_to_path_key.has(manifest_id):
			continue
		var path_key := str(id_to_path_key[manifest_id])
		var texture_path := str(entry.get("res_path", ""))
		if texture_path == "":
			continue
		if not ProjectResourceLoader.texture_resource_exists(texture_path):
			continue
		paths[path_key] = texture_path


static func _load_optional_manifest(path: String) -> Dictionary:
	if _manifest_cache.has(path):
		return (_manifest_cache[path] as Dictionary).duplicate(true)
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_warning("Empty plaza manifest: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("Invalid plaza manifest JSON: %s" % path)
		return {}
	_manifest_cache[path] = (parsed as Dictionary).duplicate(true)
	return (parsed as Dictionary).duplicate(true)


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


static func _array_to_vector2_list(value: Variant) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not (value is Array):
		return result
	for point_value in value as Array:
		if point_value is Array and (point_value as Array).size() >= 2:
			result.append(Vector2(float((point_value as Array)[0]), float((point_value as Array)[1])))
	return result


static func _manifest_color(manifest: Dictionary, key: String, fallback: Color) -> Color:
	var value := str(manifest.get(key, "")).strip_edges()
	if value == "":
		return fallback
	return Color.from_string(value, fallback)


static func _dictionary_to_rect(value: Variant) -> Rect2:
	if not (value is Dictionary):
		return Rect2()
	var dict := value as Dictionary
	return Rect2(
		Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0))),
		Vector2(float(dict.get("w", 0.0)), float(dict.get("h", 0.0)))
	)
