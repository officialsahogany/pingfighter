extends SceneTree

const CharacterInfoOverlayLingpetTextureLoader := preload("res://scripts/hud/character_info_overlay_lingpet_texture_loader.gd")
const LingpetAcquireCutinOverlayHost := preload("res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_catalog_entry()
	_verify_visual_paths()
	_verify_runtime_sheet_sizes()
	_verify_manifests()
	_verify_character_info_panel_mapping()
	_verify_acquire_cutin_anim_sheet()
	_verify_acquire_dismiss_click_sheet()
	_verify_acquire_host_loads_visible_cutin_textures()
	_cleanup()
	if _failures.is_empty():
		print("lingpet_onimaru_debug_l2d_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_entry() -> void:
	_expect(LingpetCatalog.has_pet("onimaru"), "Onimaru should be runtime-activatable for F7 debug")
	_expect(LingpetCatalog.is_pet_debug_enabled("onimaru"), "Onimaru should be visible in the F7 debug picker")
	_expect(not LingpetCatalog.is_pet_enabled("onimaru"), "Onimaru should stay out of the normal hatch pool")
	_expect(not LingpetCatalog.get_pet_ids().has("onimaru"), "enabled pet ids should not include debug-only Onimaru")
	_expect(LingpetCatalog.get_debug_pet_ids().has("onimaru"), "debug pet ids should include Onimaru")
	_expect(LingpetCatalog.get_pet_ids(true).has("onimaru"), "all pet ids should include parked Onimaru metadata")
	_expect(LingpetCatalog.get_display_name("onimaru") == "오니마루", "Onimaru should expose the accepted Korean display name")
	var active_pool := LingpetCatalog.get_active_skill_pool("onimaru")
	_expect(active_pool.size() == 1, "Onimaru should expose exactly one accepted debug active skill")
	var active_skill: Dictionary = active_pool[0] if not active_pool.is_empty() else {}
	_expect(str(active_skill.get("id", "")) == "onimaru_headbutt", "Onimaru debug active skill should be onimaru_headbutt")
	_expect(str(active_skill.get("runtime_kind", "")) == "headbutt", "Onimaru debug active skill should route through the shared headbutt runtime")
	_expect(LingpetSkillDispatcher.is_headbutt("onimaru_headbutt"), "Onimaru Headbutt should resolve through the dispatcher")
	_expect(float(active_skill.get("disable_moving_miss", 0.0)) > 0.5, "Onimaru Headbutt should disable the random moving-target miss roll")
	var hatch_candidates := LingpetCatalog.get_hatch_candidates({
		"league_mode": "junior",
		"character_type": "smasher",
	}, [])
	_expect(not hatch_candidates.has("onimaru"), "Onimaru should not enter the random hatch pool while debug-only")


func _verify_visual_paths() -> void:
	var expected := {
		"cutin_art": "res://assets/sprites/lingpet/onimaru_lingpet_live2d_anchor_v2_amber.png",
		"cutin_anim": "res://assets/sprites/lingpet/onimaru_cutin_live2d_autosprite_32f_amber.png",
		"cutin_dismiss_anim": "res://assets/sprites/lingpet/onimaru_click_live2d_autosprite_98f_amber_gripfix.png",
		"click_reaction_anim": "res://assets/sprites/lingpet/onimaru_click_live2d_autosprite_98f_amber_gripfix.png",
		"companion_click_reaction_anim": "res://assets/sprites/lingpet/onimaru_companion_click_reaction_autosprite_98f_amber_gripfix.png",
		"companion_idle": "res://assets/sprites/lingpet/onimaru_companion_standing_idle_25f.png",
		"companion_move_left": "res://assets/sprites/lingpet/onimaru_companion_move_left_25f.png",
		"companion_move_right": "res://assets/sprites/lingpet/onimaru_companion_move_right_25f.png",
		"companion_walk": "res://assets/sprites/lingpet/onimaru_companion_move_right_25f.png",
		"companion_strike": "res://assets/sprites/lingpet/onimaru_companion_strike_25f.png",
		"companion_cast": "res://assets/sprites/lingpet/onimaru_companion_standing_idle_25f.png",
	}
	for key in expected.keys():
		var path := str(expected[key])
		_expect(LingpetCatalog.get_visual_path("onimaru", str(key)) == path, "Onimaru should route %s to the amber v2 debug asset" % str(key))
		_expect(FileAccess.file_exists(path), "%s should exist on disk" % path)
	var entry := LingpetCatalog.get_entry("onimaru")
	_expect(str(entry.get("concept_art_path", "")) == "res://assets/sprites/lingpet/onimaru_lingpet_live2d_anchor_v2_amber.png", "Onimaru concept art should point at the amber v2 transparent cutout")
	_expect(str(entry.get("concept_magenta_source_path", "")) == "res://assets/sprites/lingpet/onimaru_lingpet_live2d_anchor_v2_amber_magenta_source.png", "Onimaru amber magenta source should stay traceable")


func _verify_runtime_sheet_sizes() -> void:
	_expect_texture_size("res://assets/sprites/lingpet/onimaru_lingpet_live2d_anchor_v2_amber.png", 1254, 1254)
	_expect_texture_size("res://assets/sprites/lingpet/onimaru_companion_standing_idle_25f.png", 1280, 1280)
	_expect_texture_size("res://assets/sprites/lingpet/onimaru_companion_move_left_25f.png", 1280, 1280)
	_expect_texture_size("res://assets/sprites/lingpet/onimaru_companion_move_right_25f.png", 1280, 1280)
	_expect_texture_size("res://assets/sprites/lingpet/onimaru_companion_strike_25f.png", 1280, 1280)
	_expect_texture_size("res://assets/sprites/lingpet/onimaru_cutin_live2d_autosprite_32f_amber.png", 4096, 2048)
	_expect_texture_size("res://assets/sprites/lingpet/onimaru_click_live2d_autosprite_98f_amber_gripfix.png", 7168, 3584)
	_expect_texture_size("res://assets/sprites/lingpet/onimaru_companion_click_reaction_autosprite_98f_amber_gripfix.png", 1792, 896)


func _verify_manifests() -> void:
	_expect_manifest_grid("res://assets/sprites/lingpet/onimaru_companion_standing_idle_25f_manifest.json", 5, 5, 25, 256, false)
	_expect_manifest_grid("res://assets/sprites/lingpet/onimaru_companion_move_left_25f_manifest.json", 5, 5, 25, 256, false)
	_expect_manifest_grid("res://assets/sprites/lingpet/onimaru_companion_move_right_25f_manifest.json", 5, 5, 25, 256, false)
	_expect_manifest_grid("res://assets/sprites/lingpet/onimaru_companion_strike_25f_manifest.json", 5, 5, 25, 256, false)
	_expect_manifest_grid("res://assets/sprites/lingpet/onimaru_cutin_live2d_autosprite_32f_amber_manifest.json", 8, 4, 32, 512, false)
	_expect_manifest_grid("res://assets/sprites/lingpet/onimaru_click_live2d_autosprite_98f_amber_gripfix_manifest.json", 14, 7, 98, 512, false)
	_expect_manifest_grid("res://assets/sprites/lingpet/onimaru_companion_click_reaction_autosprite_98f_amber_gripfix_manifest.json", 14, 7, 98, 128, false)


func _verify_character_info_panel_mapping() -> void:
	_expect(
		CharacterInfoOverlayLingpetTextureLoader.get_panel_live2d_visual_key("onimaru") == "click_reaction_anim",
		"character info panel should use Onimaru's 14x7 click Live2D sheet"
	)
	_expect(
		CharacterInfoOverlayLingpetTextureLoader.get_panel_art_path("onimaru") == "res://assets/sprites/lingpet/onimaru_click_live2d_autosprite_98f_amber_gripfix.png",
		"character info panel should load Onimaru's click sheet through the catalog"
	)


func _verify_acquire_cutin_anim_sheet() -> void:
	var host := LingpetAcquireCutinOverlayHost.new()
	host._asset_pet_id = "onimaru"
	_expect(host._get_cutin_anim_cols() == 8, "Onimaru acquisition Live2D should use the default 8-column grid")
	_expect(host._get_cutin_anim_rows() == 4, "Onimaru acquisition Live2D should use the default 4-row grid")
	_expect(host._get_cutin_anim_frame_count() == 32, "Onimaru acquisition Live2D should play the default 32-frame sheet")
	_expect(is_equal_approx(host._get_cutin_anim_fps(), 32.0), "Onimaru acquisition Live2D should run the hold-expanded 32-frame sheet at 32fps")


func _verify_acquire_dismiss_click_sheet() -> void:
	var host := LingpetAcquireCutinOverlayHost.new()
	host._asset_pet_id = "onimaru"
	_expect(host._get_cutin_dismiss_cols() == 14, "Onimaru acquisition click dismiss should use the 14-column click Live2D grid")
	_expect(host._get_cutin_dismiss_rows() == 7, "Onimaru acquisition click dismiss should use the 7-row click Live2D grid")
	_expect(host._get_cutin_dismiss_frame_count() == 98, "Onimaru acquisition click dismiss should play the full 98-frame click Live2D sheet")


func _verify_acquire_host_loads_visible_cutin_textures() -> void:
	ProjectResourceLoader.clear_caches()
	var anim_path := LingpetCatalog.get_visual_path("onimaru", "cutin_anim")
	var host := LingpetAcquireCutinOverlayHost.new()
	_expect(ProjectResourceLoader.get_cached_texture(anim_path) == null, "Onimaru acquisition sheet should start cold for the visibility guard")
	_expect(host.is_pet_cutin_anim_ready("onimaru"), "Onimaru acquisition readiness should secure the animated cut-in sheet instead of waiting forever on an empty cache")
	_expect(ProjectResourceLoader.get_cached_texture(anim_path) != null, "Onimaru acquisition readiness should cache the cut-in Live2D sheet")
	host._sync_assets_for_pet("onimaru")
	_expect(host._cutin_anim_sheet != null, "Onimaru acquisition host should draw with the catalog cut-in sheet after sync")


func _expect_texture_size(path: String, width: int, height: int) -> void:
	var texture := ProjectResourceLoader.load_texture(path)
	_expect(texture != null, "%s should load as a Texture2D" % path)
	if texture == null:
		return
	_expect(texture.get_width() == width and texture.get_height() == height, "%s should be %dx%d" % [path, width, height])


func _expect_manifest_grid(path: String, cols: int, rows: int, frame_count: int, cell_size: int, expect_repeated_static: bool = true) -> void:
	_expect(FileAccess.file_exists(path), "%s should exist" % path)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_expect(data is Dictionary, "%s should parse as manifest JSON" % path)
	if not (data is Dictionary):
		return
	var grid: Dictionary = (data as Dictionary).get("grid", {})
	_expect(int(grid.get("cols", 0)) == cols, "%s cols should match runtime contract" % path)
	_expect(int(grid.get("rows", 0)) == rows, "%s rows should match runtime contract" % path)
	_expect(int(grid.get("frame_count", 0)) == frame_count, "%s frame count should match runtime contract" % path)
	var cell: Array = grid.get("cell_size", [])
	_expect(cell.size() == 2 and int(cell[0]) == cell_size and int(cell[1]) == cell_size, "%s cell size should match runtime contract" % path)
	_expect(bool(grid.get("repeated_static_frame", false)) == expect_repeated_static, "%s repeated-frame flag should match the runtime contract" % path)
	if not expect_repeated_static:
		return
	var recon: Dictionary = (data as Dictionary).get("reconstruction_frame0", {})
	var occupancy: Array = recon.get("occupancy", [])
	var alpha_bbox: Array = recon.get("alpha_bbox", [])
	_expect(int(recon.get("grid_cols", 0)) == 10 and int(recon.get("grid_rows", 0)) == 10, "%s reconstruction mask should use the cut-in host grid" % path)
	_expect(occupancy.size() == 100, "%s reconstruction occupancy should cover the full 10x10 grid" % path)
	_expect(alpha_bbox.size() == 4, "%s reconstruction alpha bbox should be normalized" % path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _cleanup() -> void:
	ProjectResourceLoader.clear_caches()
