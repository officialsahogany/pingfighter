extends SceneTree

const CharacterInfoOverlayLingpetPresenter := preload("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
const CharacterInfoOverlayLingpetTextureLoader := preload("res://scripts/hud/character_info_overlay_lingpet_texture_loader.gd")
const LingpetAcquireCutinOverlayHost := preload("res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
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
	_expect(not LingpetCatalog.is_pet_enabled("rahoset"), "Rahoset should stay out of the normal hatch pool")
	_expect(LingpetCatalog.get_display_name("rahoset") == "라호세트", "Rahoset should expose the accepted Korean display name")
	_expect(LingpetCatalog.get_motion_style("rahoset") == "sortie_flight", "Rahoset should keep its airborne movement style")
	_expect(LingpetCatalog.get_active_skill_pool("rahoset").is_empty(), "Rahoset should not expose a fake active skill before the sand/desert runtime ships")


func _verify_visual_paths() -> void:
	var expected := {
		"cutin_art": "res://assets/sprites/lingpet/rahoset_lingpet_live2d_anchor_v1.png",
		"cutin_anim": "res://assets/sprites/lingpet/rahoset_cutin_acquire_ready_v2_autosprite_32f.png",
		"cutin_dismiss_anim": "res://assets/sprites/lingpet/rahoset_click_ritual_linked_v2_autosprite_98f.png",
		"click_reaction_anim": "res://assets/sprites/lingpet/rahoset_click_ritual_linked_v2_autosprite_98f.png",
		"companion_click_reaction_anim": "res://assets/sprites/lingpet/rahoset_companion_click_ritual_linked_v2_autosprite_98f.png",
		"companion_idle": "res://assets/sprites/lingpet/rahoset_companion_front_hover_autosprite_25f.png",
		"companion_move_left": "res://assets/sprites/lingpet/rahoset_companion_front_hover_autosprite_25f.png",
		"companion_move_right": "res://assets/sprites/lingpet/rahoset_companion_front_hover_autosprite_25f.png",
		"companion_walk": "res://assets/sprites/lingpet/rahoset_companion_front_hover_autosprite_25f.png",
		"companion_strike": "res://assets/sprites/lingpet/rahoset_companion_front_hover_autosprite_25f.png",
		"companion_cast": "res://assets/sprites/lingpet/rahoset_companion_front_hover_autosprite_25f.png",
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
	_expect_texture_size("res://assets/sprites/lingpet/rahoset_companion_front_hover_autosprite_25f.png", 1280, 1280)
	_expect_texture_size("res://assets/sprites/lingpet/rahoset_cutin_acquire_ready_v2_autosprite_32f.png", 4096, 2048)
	_expect_texture_size("res://assets/sprites/lingpet/rahoset_click_ritual_linked_v2_autosprite_98f.png", 7168, 3584)
	_expect_texture_size("res://assets/sprites/lingpet/rahoset_companion_click_ritual_linked_v2_autosprite_98f.png", 1792, 896)


func _verify_manifests() -> void:
	_expect_manifest_grid("res://assets/sprites/lingpet/rahoset_companion_front_hover_autosprite_25f_manifest.json", 5, 5, 25, 256)
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


func _verify_acquire_host_loads_visible_cutin_textures() -> void:
	ProjectResourceLoader.clear_caches()
	var anim_path := LingpetCatalog.get_visual_path("rahoset", "cutin_anim")
	var host := LingpetAcquireCutinOverlayHost.new()
	_expect(ProjectResourceLoader.get_cached_texture(anim_path) == null, "Rahoset acquisition sheet should start cold for the visibility guard")
	_expect(host.is_pet_cutin_anim_ready("rahoset"), "Rahoset acquisition readiness should secure the animated cut-in sheet instead of waiting forever on an empty cache")
	_expect(ProjectResourceLoader.get_cached_texture(anim_path) != null, "Rahoset acquisition readiness should cache the cut-in Live2D sheet")
	host._sync_assets_for_pet("rahoset")
	_expect(host._cutin_anim_sheet != null, "Rahoset acquisition host should draw with the catalog cut-in sheet after sync")


func _expect_texture_size(path: String, width: int, height: int) -> void:
	var texture := ProjectResourceLoader.load_texture(path)
	_expect(texture != null, "%s should load as a Texture2D" % path)
	if texture == null:
		return
	_expect(texture.get_width() == width and texture.get_height() == height, "%s should be %dx%d" % [path, width, height])


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
	else:
		_expect(str(source_autosprite.get("spritesheet_id", "")) == "cmqfvnogp0002wp5i4g8b6l4r", "%s should record the accepted front-hover AutoSprite branch" % path)
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
		_expect(str(qa.get("perceptual_frontal_neutrality", "")).find("accepted") >= 0, "%s should document the accepted front-facing AutoSprite read" % path)
	if path.find("_v2_") >= 0 or path.find("linked_v2") >= 0:
		_expect(int(qa.get("edge_alpha_max", 255)) == 0, "%s should leave every cell edge transparent" % path)
	_expect(bool(qa.get("right_facing_drift_rejected", false)), "%s should document the right-facing drift rejection" % path)
	_expect(int(qa.get("unique_frame_hashes", 0)) > 1, "%s should contain animated frames, not a repeated still" % path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _cleanup() -> void:
	ProjectResourceLoader.clear_caches()
