extends SceneTree

const CharacterInfoOverlayLingpetPresenter := preload("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
const CharacterInfoOverlayLingpetTextureLoader := preload("res://scripts/hud/character_info_overlay_lingpet_texture_loader.gd")
const LingpetAcquireCutinOverlayHost := preload("res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetCompanionSpriteAnimator := preload("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_catalog_entry()
	_verify_visual_paths()
	_verify_runtime_sheet_sizes()
	_verify_manifests()
	_verify_character_info_click_live2d_mapping()
	_verify_acquire_live2d_sheet_contracts()
	_verify_acquire_host_loads_visible_cutin_textures()
	_cleanup()
	if _failures.is_empty():
		print("lingpet_rahoset_debug_l2d_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_entry() -> void:
	_expect(LingpetCatalog.has_pet("rahoset"), "Rahoset should be runtime-activatable for F7 debug")
	_expect(LingpetCatalog.is_pet_debug_enabled("rahoset"), "Rahoset should be visible in the F7 debug picker")
	_expect(LingpetCatalog.is_pet_enabled("rahoset"), "Rahoset should be enabled after Sand Prison production promotion")
	_expect(LingpetCatalog.get_pet_ids().has("rahoset"), "enabled pet ids should include live Rahoset")
	_expect(LingpetCatalog.get_debug_pet_ids().has("rahoset"), "debug pet ids should still include Rahoset for F7 quick-select")
	var rahoset_hatch := LingpetCatalog.get_hatch_candidates({
		"league_mode": "junior",
		"character_type": "smasher",
	}, [])
	_expect(rahoset_hatch.has("rahoset"), "Rahoset should enter the random hatch pool after production promotion")
	_expect(LingpetCatalog.get_display_name("rahoset") == "라호세트", "Rahoset should expose the accepted Korean display name")
	_expect(LingpetCatalog.get_motion_style("rahoset") == "sortie_flight", "Rahoset should keep its airborne movement style")
	var active_pool := LingpetCatalog.get_active_skill_pool("rahoset")
	_expect(active_pool.size() == 1, "Rahoset should expose exactly one active skill now that the Sand Prison runtime shipped")
	_expect(not active_pool.is_empty() and str(active_pool[0].get("id", "")) == "rahoset_sand_prison", "Rahoset primary active skill should be Sand Prison")
	_expect(LingpetCatalog.get_active_skill_runtime_kind("rahoset_sand_prison") == "sand_prison", "Rahoset Sand Prison should route to the sand_prison runtime kind")
	var effect_text := LingpetCatalog.get_effect_text("rahoset")
	_expect(effect_text.find("모래감옥") >= 0, "Rahoset effect text should describe the shipped Sand Prison active skill")
	_expect(effect_text.find("제작 전 단계") < 0 and effect_text.find("정적 임시") < 0 and effect_text.find("디버그") < 0, "Rahoset production effect text should not keep placeholder or debug wording")


func _verify_visual_paths() -> void:
	var expected := {
		"cutin_art": "res://assets/sprites/lingpet/rahoset_lingpet_live2d_anchor_v1.png",
		"cutin_anim": "res://assets/sprites/lingpet/rahoset_cutin_acquire_ready_v2_autosprite_32f.png",
		"cutin_dismiss_anim": "res://assets/sprites/lingpet/rahoset_click_ritual_linked_v2_autosprite_98f.png",
		"click_reaction_anim": "res://assets/sprites/lingpet/rahoset_click_ritual_linked_v2_autosprite_98f.png",
		"companion_click_reaction_anim": "res://assets/sprites/lingpet/rahoset_companion_click_ritual_linked_v2_autosprite_98f.png",
		"companion_idle": "res://assets/sprites/lingpet/rahoset_companion_rear_hover_25f.png",
		"companion_move_left": "res://assets/sprites/lingpet/rahoset_companion_rear_hover_25f.png",
		"companion_move_right": "res://assets/sprites/lingpet/rahoset_companion_rear_hover_25f.png",
		"companion_walk": "res://assets/sprites/lingpet/rahoset_companion_rear_hover_25f.png",
		"companion_strike": "res://assets/sprites/lingpet/rahoset_companion_rear_strike_25f.png",
		"companion_cast": "res://assets/sprites/lingpet/rahoset_companion_rear_hover_25f.png",
	}
	for key in expected.keys():
		var path := str(expected[key])
		_expect(LingpetCatalog.get_visual_path("rahoset", str(key)) == path, "Rahoset should route %s to the debug Live2D asset" % str(key))
		_expect(FileAccess.file_exists(path), "%s should exist on disk" % path)
	var entry := LingpetCatalog.get_entry("rahoset")
	_expect(str(entry.get("concept_art_path", "")) == "res://assets/sprites/lingpet/rahoset_lingpet_live2d_anchor_v1.png", "Rahoset concept art should point at the accepted transparent anchor")
	_expect(str(entry.get("concept_magenta_source_path", "")) == "res://assets/sprites/lingpet/rahoset_lingpet_live2d_anchor_v1_magenta_source.png", "Rahoset exact-magenta source should stay traceable")


func _verify_runtime_sheet_sizes() -> void:
	_expect_texture_size("res://assets/sprites/lingpet/rahoset_lingpet_live2d_anchor_v1.png", 1212, 1297)
	_expect_texture_size("res://assets/sprites/lingpet/rahoset_companion_rear_hover_25f.png", 1280, 1280)
	_expect_texture_size("res://assets/sprites/lingpet/rahoset_companion_rear_strike_25f.png", 1280, 1280)
	_expect_texture_size("res://assets/sprites/lingpet/rahoset_cutin_acquire_ready_v2_autosprite_32f.png", 4096, 2048)
	_expect_texture_size("res://assets/sprites/lingpet/rahoset_click_ritual_linked_v2_autosprite_98f.png", 7168, 3584)
	_expect_texture_size("res://assets/sprites/lingpet/rahoset_companion_click_ritual_linked_v2_autosprite_98f.png", 1792, 896)


func _verify_manifests() -> void:
	_expect_manifest_grid("res://assets/sprites/lingpet/rahoset_companion_rear_hover_25f_manifest.json", 5, 5, 25, 256)
	_expect_manifest_grid("res://assets/sprites/lingpet/rahoset_companion_rear_strike_25f_manifest.json", 5, 5, 25, 256)
	_expect_manifest_grid("res://assets/sprites/lingpet/rahoset_cutin_acquire_ready_v2_autosprite_32f_manifest.json", 8, 4, 32, 512)
	_expect_manifest_grid("res://assets/sprites/lingpet/rahoset_click_ritual_linked_v2_autosprite_98f_manifest.json", 14, 7, 98, 512)
	_expect_manifest_grid("res://assets/sprites/lingpet/rahoset_companion_click_ritual_linked_v2_autosprite_98f_manifest.json", 14, 7, 98, 128)


func _verify_character_info_click_live2d_mapping() -> void:
	_expect(
		CharacterInfoOverlayLingpetTextureLoader.get_panel_live2d_visual_key("rahoset") == "click_reaction_anim",
		"character info panel should use Rahoset's 14x7 click Live2D sheet"
	)
	_expect(
		CharacterInfoOverlayLingpetTextureLoader.get_panel_art_path("rahoset") == "res://assets/sprites/lingpet/rahoset_click_ritual_linked_v2_autosprite_98f.png",
		"character info panel should load Rahoset's click sheet through the catalog"
	)
	_expect(CharacterInfoOverlayLingpetTextureLoader.uses_panel_live2d_art("rahoset"), "Rahoset character-info art should opt into panel Live2D playback")
	var source := CharacterInfoOverlayLingpetPresenter.panel_live2d_source_rect("rahoset", Vector2(7168.0, 3584.0), 0.0)
	_expect(is_equal_approx(source.size.x, 512.0) and is_equal_approx(source.size.y, 512.0), "Rahoset panel Live2D should split the click sheet into 14x7 / 512px cells")
	var next_source := CharacterInfoOverlayLingpetPresenter.panel_live2d_source_rect("rahoset", Vector2(7168.0, 3584.0), 1.0 / 16.0)
	_expect(is_equal_approx(next_source.position.x, 512.0) and is_equal_approx(next_source.position.y, 0.0), "Rahoset panel Live2D should advance through the 98-frame click sheet")


func _verify_acquire_live2d_sheet_contracts() -> void:
	var host := LingpetAcquireCutinOverlayHost.new()
	host._asset_pet_id = "rahoset"
	_expect(host._get_cutin_anim_cols() == 8, "Rahoset acquisition Live2D should use the 8-column sheet")
	_expect(host._get_cutin_anim_rows() == 4, "Rahoset acquisition Live2D should use the 4-row sheet")
	_expect(host._get_cutin_anim_frame_count() == 32, "Rahoset acquisition Live2D should play all 32 frames")
	_expect(host._get_cutin_dismiss_cols() == 14, "Rahoset acquisition click dismiss should use the 14-column click Live2D grid")
	_expect(host._get_cutin_dismiss_rows() == 7, "Rahoset acquisition click dismiss should use the 7-row click Live2D grid")
	_expect(host._get_cutin_dismiss_frame_count() == 98, "Rahoset acquisition click dismiss should play the full 98-frame click Live2D sheet")
	_clear_host_textures(host)


func _verify_acquire_host_loads_visible_cutin_textures() -> void:
	ProjectResourceLoader.clear_caches()
	var anim_path := LingpetCatalog.get_visual_path("rahoset", "cutin_anim")
	var host := LingpetAcquireCutinOverlayHost.new()
	_expect(ProjectResourceLoader.get_cached_texture(anim_path) == null, "Rahoset acquisition sheet should start cold for the visibility guard")
	for _i in range(320):
		if host.prewarm_pet_assets_step("rahoset", true):
			break
	_expect(host.is_pet_cutin_anim_ready("rahoset"), "Rahoset acquisition readiness should observe the prepared animated cut-in sheet")
	_expect(ProjectResourceLoader.get_cached_texture(anim_path) != null, "Rahoset acquisition readiness should cache the cut-in Live2D sheet")
	host._sync_assets_for_pet("rahoset")
	_expect(host._cutin_anim_sheet != null, "Rahoset acquisition host should draw with the catalog cut-in sheet after sync")
	_clear_host_textures(host)
	ProjectResourceLoader.clear_caches()


func _expect_texture_size(path: String, width: int, height: int) -> void:
	var texture := ProjectResourceLoader.load_texture(path)
	_expect(texture != null, "%s should load as a Texture2D" % path)
	if texture == null:
		return
	_expect(texture.get_width() == width and texture.get_height() == height, "%s should be %dx%d" % [path, width, height])
	texture = null


func _clear_host_textures(host: Object) -> void:
	if host == null:
		return
	host._cutin_art = null
	host._cutin_anim_sheet = null
	host._cutin_dismiss_sheet = null
	host._cutin_vfx_sheet = null
	host._portal_texture = null


func _expect_manifest_grid(path: String, cols: int, rows: int, frame_count: int, cell_size: int) -> void:
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
	_expect(not bool(grid.get("repeated_static_frame", true)), "%s should not be marked as a repeated static placeholder" % path)
	var source_anchor: Dictionary = (data as Dictionary).get("source_anchor", {})
	_expect(str(source_anchor.get("path", "")) == "res://assets/sprites/lingpet/rahoset_lingpet_live2d_anchor_v1.png", "%s should record the accepted source-front anchor" % path)
	var source_autosprite: Dictionary = (data as Dictionary).get("source_autosprite", {})
	if path.find("click_ritual_linked_v2") >= 0:
		_expect(str(source_autosprite.get("spritesheet_id", "")) == "cmqjak5v9001lxjwofvdt1xj3", "%s should record the accepted v2 click AutoSprite branch" % path)
		_expect(str(source_autosprite.get("pose_id_shared_ritual_ready", "")) == "cmqjagc45002113ggi1ny82xi", "%s should record the shared Ritual Ready pose" % path)
	elif path.find("cutin_acquire_ready_v2") >= 0:
		_expect(str(source_autosprite.get("spritesheet_id", "")) == "cmqjajxk40012xjwou1f5ikb3", "%s should record the accepted v2 acquisition AutoSprite branch" % path)
		_expect(str(source_autosprite.get("pose_id_shared_ritual_ready", "")) == "cmqjagc45002113ggi1ny82xi", "%s should record the shared Ritual Ready pose" % path)
	elif path.find("companion_rear_hover") >= 0:
		_expect(str(source_autosprite.get("spritesheet_id", "")) == "cmr1yrtnj001usu712sc2kss8", "%s should record the accepted rear-hover AutoSprite branch" % path)
	elif path.find("companion_rear_strike") >= 0:
		_expect(str(source_autosprite.get("spritesheet_id", "")) == "cmr1yrw22001ysu71mx6rmnwd", "%s should record the accepted rear-strike AutoSprite branch" % path)
	else:
		_expect(false, "%s has no pinned AutoSprite provenance branch in this smoke" % path)
	var qa: Dictionary = (data as Dictionary).get("qa", {})
	if path.find("click_ritual_linked_v2") >= 0:
		_expect(bool(qa.get("starts_from_shared_ritual_ready_pose", false)), "%s should document that frame 0 uses the shared Ritual Ready pose" % path)
		_expect(bool(qa.get("returns_to_shared_ritual_ready_pose", false)), "%s should document that the click sheet returns to the shared Ritual Ready pose" % path)
		_expect(bool(qa.get("distinct_from_acquisition_hover", false)), "%s should document that click Live2D is distinct from acquisition Live2D" % path)
		_expect(bool(qa.get("action_pose_change", false)), "%s should document a real click action pose change" % path)
		_expect(float(qa.get("acquisition_last_to_click_first_downsampled_diff", 999.0)) <= 10.0, "%s should start close to the acquisition final pose" % path)
		_expect(float(qa.get("first_to_last_downsampled_diff", 999.0)) <= 5.0, "%s should return close to the click first pose for panel-loop continuity" % path)
	elif path.find("cutin_acquire_ready_v2") >= 0:
		_expect(bool(qa.get("ends_on_shared_ritual_ready_pose", false)), "%s should document that acquisition ends on the shared Ritual Ready pose" % path)
		_expect(float(qa.get("acquisition_last_to_click_first_downsampled_diff", 999.0)) <= 10.0, "%s should hand off smoothly to the click first frame" % path)
	else:
		_expect(str(qa.get("rear_view", "")).find("back view") >= 0, "%s should document the accepted rear-view (back view) AutoSprite read" % path)
		_expect(str((data as Dictionary).get("generation_mode", "")) == "autosprite_rear_view_custom_v1", "%s should record the rear-view custom generation mode" % path)
	if path.find("companion_rear_strike") >= 0:
		var postprocess: Dictionary = (data as Dictionary).get("postprocess", {})
		_expect(
			int(postprocess.get("impact_cell", -1)) == LingpetCompanionSpriteAnimator.STRIKE_IMPACT_FRAME,
			"%s impact cell should match the animator STRIKE_IMPACT_FRAME contract" % path
		)
		var active_frames: Array = postprocess.get("runtime_active_frames", [])
		_expect(
			not active_frames.is_empty() and int(active_frames[0]) == LingpetCompanionSpriteAnimator.STRIKE_START_FRAME,
			"%s runtime active frames should start at the animator STRIKE_START_FRAME contract" % path
		)
	if path.find("_v2_") >= 0 or path.find("linked_v2") >= 0:
		_expect(int(qa.get("edge_alpha_max", 255)) == 0, "%s should leave every cell edge transparent" % path)
	var is_rear_companion_sheet := path.find("companion_rear_") >= 0
	if not is_rear_companion_sheet:
		_expect(bool(qa.get("right_facing_drift_rejected", false)), "%s should document the right-facing drift rejection" % path)
		_expect(int(qa.get("unique_frame_hashes", 0)) > 1, "%s should contain animated frames, not a repeated still" % path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _cleanup() -> void:
	ProjectResourceLoader.clear_caches()
