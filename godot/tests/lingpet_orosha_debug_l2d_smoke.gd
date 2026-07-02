extends SceneTree

const CharacterInfoOverlayLingpetPresenter := preload("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
const CharacterInfoOverlayLingpetTextureLoader := preload("res://scripts/hud/character_info_overlay_lingpet_texture_loader.gd")
const LingpetAcquireCutinOverlayHost := preload("res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetCompanionRenderer := preload("res://scripts/lingpet/lingpet_companion_renderer.gd")
const LingpetCompanionSpriteAnimator := preload("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_catalog_entry()
	_verify_visual_paths()
	_verify_runtime_sheet_sizes()
	_verify_companion_movement_48_frame_contracts()
	_verify_round_roll_source_manifest()
	_verify_manifests()
	_verify_character_info_click_live2d_mapping()
	_verify_acquire_live2d_sheet_contracts()
	_verify_acquire_host_loads_visible_cutin_textures()
	_cleanup()
	if _failures.is_empty():
		print("lingpet_orosha_debug_l2d_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_entry() -> void:
	_expect(LingpetCatalog.has_pet("orosha"), "Orosha should be runtime-activatable")
	_expect(LingpetCatalog.is_pet_enabled("orosha"), "Orosha should be enabled after Star Coil production promotion")
	_expect(LingpetCatalog.get_pet_ids().has("orosha"), "enabled pet ids should include live Orosha")
	_expect(LingpetCatalog.get_debug_pet_ids().has("orosha"), "debug pet ids should include live Orosha for F7 selection")
	_expect(LingpetCatalog.get_pet_ids(true).has("orosha"), "all pet ids should include Orosha metadata")
	_expect(LingpetCatalog.get_display_name("orosha") == "오로샤", "Orosha should expose the accepted Korean display name")
	_expect(LingpetCatalog.get_motion_style("orosha") == "patrol", "Orosha should use the grounded patrol movement style")
	_expect(_active_pool_has(LingpetCatalog.get_active_skill_pool("orosha"), "orosha_star_coil"), "Orosha should expose the shipped Star Coil active runtime")
	_expect(LingpetCatalog.get_active_skill_runtime_kind("orosha_star_coil") == "star_coil", "Orosha Star Coil should route through the star_coil runtime kind")
	var hatch_candidates := LingpetCatalog.get_hatch_candidates({
		"league_mode": "junior",
		"character_type": "smasher",
	}, [])
	_expect(hatch_candidates.has("orosha"), "Orosha should enter the random hatch pool after Star Coil production promotion")


func _verify_visual_paths() -> void:
	var expected := {
		"cutin_art": "res://assets/sprites/lingpet/orosha_lingpet_live2d_anchor_v1.png",
		"cutin_anim": "res://assets/sprites/lingpet/orosha_cutin_live2d_rigid_v2_autosprite_32f.png",
		"cutin_vfx_anim": "res://assets/sprites/lingpet/orosha_acquire_vfx_autosprite_16f.png",
		"cutin_dismiss_anim": "res://assets/sprites/lingpet/orosha_cutin_dismiss_anim.png",
		"click_reaction_anim": "res://assets/sprites/lingpet/orosha_click_rolling_autosprite_98f.png",
		"companion_click_reaction_anim": "res://assets/sprites/lingpet/orosha_companion_click_reaction_rolling_98f.png",
		"companion_idle": "res://assets/sprites/lingpet/orosha_companion_idle_ground_autosprite_25f.png",
		"companion_move_left": "res://assets/sprites/lingpet/orosha_companion_move_left_ground_roll_autosprite_48f.png",
		"companion_move_right": "res://assets/sprites/lingpet/orosha_companion_move_right_ground_roll_autosprite_48f.png",
		"companion_walk": "res://assets/sprites/lingpet/orosha_companion_move_right_ground_roll_autosprite_48f.png",
		"companion_distance_roll_source": "res://assets/sprites/lingpet/orosha_companion_round_roll_source_v1.png",
		"companion_strike": "res://assets/sprites/lingpet/orosha_companion_static_25f.png",
		"companion_cast": "res://assets/sprites/lingpet/orosha_companion_static_25f.png",
	}
	for key in expected.keys():
		var path := str(expected[key])
		_expect(LingpetCatalog.get_visual_path("orosha", str(key)) == path, "Orosha should route %s to the commissioned debug asset" % str(key))
		_expect(FileAccess.file_exists(path), "%s should exist on disk" % path)
	var entry := LingpetCatalog.get_entry("orosha")
	_expect(str(entry.get("concept_art_path", "")) == "res://assets/sprites/lingpet/orosha_lingpet_live2d_anchor_v1.png", "Orosha concept art should point at the commissioned transparent anchor")
	_expect(str(entry.get("concept_magenta_source_path", "")) == "res://assets/sprites/lingpet/orosha_lingpet_live2d_anchor_v1_magenta_source.png", "Orosha front magenta source should stay traceable")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/orosha_background_only_v1.png"), "Orosha source background plate should stay archived")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/orosha_vfx_transparent_v1.png"), "Orosha transparent VFX layer should stay archived")


func _verify_runtime_sheet_sizes() -> void:
	_expect_texture_size("res://assets/sprites/lingpet/orosha_lingpet_live2d_anchor_v1.png", 1254, 1254)
	_expect_texture_size("res://assets/sprites/lingpet/orosha_companion_back_clean_v1.png", 1254, 1254)
	_expect_texture_size("res://assets/sprites/lingpet/orosha_companion_back_clean_v2.png", 1254, 1254)
	_expect_texture_size("res://assets/sprites/lingpet/orosha_companion_round_roll_source_v1_autosprite_raw.png", 1024, 1024)
	_expect_texture_size("res://assets/sprites/lingpet/orosha_companion_round_roll_source_v1.png", 1024, 1024)
	_expect_texture_size("res://assets/sprites/lingpet/orosha_companion_static_25f.png", 1280, 1280)
	_expect_texture_size("res://assets/sprites/lingpet/orosha_companion_idle_ground_autosprite_25f.png", 1280, 1280)
	_expect_texture_size("res://assets/sprites/lingpet/orosha_companion_move_left_ground_roll_autosprite_48f.png", 2048, 1536)
	_expect_texture_size("res://assets/sprites/lingpet/orosha_companion_move_right_ground_roll_autosprite_48f.png", 2048, 1536)
	_expect_texture_size("res://assets/sprites/lingpet/orosha_cutin_live2d_rigid_v2_autosprite_32f.png", 4096, 2048)
	_expect_texture_size("res://assets/sprites/lingpet/orosha_acquire_vfx_autosprite_16f.png", 2048, 2048)
	_expect_texture_size("res://assets/sprites/lingpet/orosha_cutin_dismiss_anim.png", 7168, 3584)
	_expect_texture_size("res://assets/sprites/lingpet/orosha_click_rolling_autosprite_98f.png", 7168, 3584)
	_expect_texture_size("res://assets/sprites/lingpet/orosha_companion_click_reaction_rolling_98f.png", 1792, 896)


func _verify_companion_movement_48_frame_contracts() -> void:
	_expect(int(LingpetCatalog.get_visual_layout_value("orosha", "companion_move_left_cols")) == 8, "Orosha left movement should declare an 8-column sheet")
	_expect(int(LingpetCatalog.get_visual_layout_value("orosha", "companion_move_left_rows")) == 6, "Orosha left movement should declare a 6-row sheet")
	_expect(int(LingpetCatalog.get_visual_layout_value("orosha", "companion_move_left_frame_count")) == 48, "Orosha left movement should declare all 48 frames")
	_expect(int(LingpetCatalog.get_visual_layout_value("orosha", "companion_move_right_cols")) == 8, "Orosha right movement should declare an 8-column sheet")
	_expect(int(LingpetCatalog.get_visual_layout_value("orosha", "companion_move_right_rows")) == 6, "Orosha right movement should declare a 6-row sheet")
	_expect(int(LingpetCatalog.get_visual_layout_value("orosha", "companion_move_right_frame_count")) == 48, "Orosha right movement should declare all 48 frames")
	_expect(int(LingpetCatalog.get_visual_layout_value("orosha", "companion_stop_freeze_move_frame")) == 1, "Orosha should freeze the current rolling frame while stopped instead of snapping to idle")
	_expect(int(LingpetCatalog.get_visual_layout_value("orosha", "companion_distance_roll_enabled")) == 1, "Orosha should use distance-based rotation from the rear-view source")
	_expect(is_equal_approx(LingpetCatalog.get_visual_layout_value("orosha", "companion_distance_roll_radius"), 49.0), "Orosha distance-roll radius should match the 98px companion draw diameter")
	_expect(is_equal_approx(LingpetCatalog.get_visual_layout_value("orosha", "companion_distance_roll_stop_deceleration"), 16.0), "Orosha distance-roll should declare a smooth visual stop deceleration")
	_expect(is_equal_approx(LingpetCatalog.get_visual_layout_value("orosha", "companion_distance_roll_max_angular_velocity"), 6.0), "Orosha distance-roll should cap visual coast velocity")
	_expect(is_equal_approx(LingpetCatalog.get_visual_layout_value("orosha", "companion_distance_roll_visual_tilt_radians"), 0.0), "Orosha should full-rotate the complete circular source instead of using the rejected limited-tilt fallback")
	var animator := LingpetCompanionSpriteAnimator.new()
	var meta := {
		"cols": 8,
		"rows": 6,
		"frame_count": 48,
	}
	var moving_frame := int(animator.get_walk_frame(0.0, 2600, 1.0, meta))
	_expect(moving_frame == 35, "Orosha 48-frame walk metadata should let the animator advance beyond the old 25-frame cycle")
	var texture := ProjectResourceLoader.load_texture("res://assets/sprites/lingpet/orosha_companion_move_left_ground_roll_autosprite_48f.png")
	_expect(texture != null, "Orosha 48-frame left movement sheet should load for source-rect verification")
	if texture == null:
		return
	var source := animator.get_source_rect(texture, 47, meta)
	_expect(is_equal_approx(source.position.x, 1792.0) and is_equal_approx(source.position.y, 1280.0), "Orosha frame 47 should slice from the last occupied 8x6 cell")
	_expect(is_equal_approx(source.size.x, 256.0) and is_equal_approx(source.size.y, 256.0), "Orosha 48-frame movement source rect should keep 256px cells")
	for _i in range(20):
		animator.advance_walk_phase(0.05, 1.0)
	var phase_frame := int(animator.get_walk_frame(0.0, 1000, 1.0, meta))
	for _i in range(8):
		animator.advance_walk_phase(0.05, 0.0)
	var stopped_phase_frame := int(animator.get_walk_frame(0.0, 9000, LingpetCompanionSpriteAnimator.MOVING_RATIO_THRESHOLD + 0.001, meta))
	_expect(stopped_phase_frame == phase_frame, "Orosha stop-freeze draw ratio should reuse the current rolling phase instead of resetting the face position")
	var right_texture := ProjectResourceLoader.load_texture("res://assets/sprites/lingpet/orosha_companion_move_right_ground_roll_autosprite_48f.png")
	var idle_texture := ProjectResourceLoader.load_texture("res://assets/sprites/lingpet/orosha_companion_idle_ground_autosprite_25f.png")
	var roll_source_texture := ProjectResourceLoader.load_texture("res://assets/sprites/lingpet/orosha_companion_back_clean_v2.png")
	_expect(right_texture != null and idle_texture != null and roll_source_texture != null, "Orosha movement fixture should load right movement, idle, and distance-roll textures")
	if right_texture != null and idle_texture != null and roll_source_texture != null:
		var roll_state := LingpetCompanionRenderer.new().resolve_companion_sprite_state_for_tests({
			"face_left": false,
			"motion_speed_ratio": 0.0,
			"companion_distance_roll_enabled": 1.0,
			"companion_roll_angle": 0.75,
			"distance_roll_source_texture": roll_source_texture,
			"idle_texture": idle_texture,
			"move_left_texture": texture,
			"move_right_texture": right_texture,
			"walk_texture": right_texture,
		})
		_expect(str(roll_state.get("visual_key", "")) == "companion_distance_roll_source", "Orosha stopped draw should keep the rear-view distance-roll source instead of snapping to an idle/move frame")
		_expect(bool(roll_state.get("distance_roll", false)), "Orosha stopped draw should request rotated single-source rendering")
		_expect(is_equal_approx(float(roll_state.get("rotation", 0.0)), 0.75), "Orosha renderer should preserve the runtime movement-derived roll angle")
		var cast_state := LingpetCompanionRenderer.new().resolve_companion_sprite_state_for_tests({
			"casting_windup": true,
			"face_left": false,
			"motion_speed_ratio": 1.0,
			"companion_distance_roll_enabled": 1.0,
			"distance_roll_source_texture": roll_source_texture,
			"cast_texture": idle_texture,
		})
		_expect(str(cast_state.get("visual_key", "")) == "companion_cast", "Orosha distance-roll movement should not override explicit cast windup poses")
		var stopped_state := LingpetCompanionRenderer.new().resolve_companion_sprite_state_for_tests({
			"face_left": false,
			"motion_speed_ratio": 0.0,
			"companion_stop_freeze_move_frame": 1.0,
			"idle_texture": idle_texture,
			"move_left_texture": texture,
			"move_right_texture": right_texture,
			"walk_texture": right_texture,
		})
		_expect(str(stopped_state.get("visual_key", "")) == "companion_move_right", "Orosha stopped-right draw should hold the right rolling sheet, not snap to the idle sheet")
		_expect(float(stopped_state.get("speed_ratio", 0.0)) > LingpetCompanionSpriteAnimator.MOVING_RATIO_THRESHOLD, "Orosha stopped-right draw should request the phase frame while real motion stays idle")
		var normal_idle_state := LingpetCompanionRenderer.new().resolve_companion_sprite_state_for_tests({
			"face_left": false,
			"motion_speed_ratio": 0.0,
			"companion_stop_freeze_move_frame": 0.0,
			"idle_texture": idle_texture,
			"move_left_texture": texture,
			"move_right_texture": right_texture,
			"walk_texture": right_texture,
		})
		_expect(str(normal_idle_state.get("visual_key", "")) == "companion_idle", "Pets without stop-freeze should keep the existing idle-sheet behavior")


func _verify_round_roll_source_manifest() -> void:
	var path := "res://assets/sprites/lingpet/orosha_companion_round_roll_source_v1_manifest.json"
	_expect(FileAccess.file_exists(path), "%s should exist" % path)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_expect(data is Dictionary, "%s should parse as manifest JSON" % path)
	if not (data is Dictionary):
		return
	var output: Dictionary = (data as Dictionary).get("output", {})
	_expect(str(output.get("path", "")) == "res://assets/sprites/lingpet/orosha_companion_round_roll_source_v1.png", "Orosha round-roll manifest should point at the runtime source")
	var size: Array = output.get("size", [])
	_expect(size.size() == 2 and int(size[0]) == 1024 and int(size[1]) == 1024, "Orosha round-roll source should be the AutoSprite 1024px redraw")
	var autosprite: Dictionary = (data as Dictionary).get("autosprite", {})
	_expect(str(autosprite.get("character_id", "")) == "cmqk40id600igdr8dd7rj5xv7", "Orosha round-roll manifest should record the AutoSprite reference character")
	_expect(str(autosprite.get("pose_id", "")) == "cmqk41vqd00crzdcew6lbj2cd", "Orosha round-roll manifest should record the accepted Round Hoop pose")
	var postprocess: Dictionary = (data as Dictionary).get("postprocess", {})
	_expect(str(postprocess.get("method", "")).find("circular outer clip") >= 0, "Orosha round-roll source should document the exact circular outer clip")
	var qa: Dictionary = (data as Dictionary).get("qa", {})
	_expect(int(qa.get("edge_alpha_max", 255)) == 0, "Orosha round-roll source should keep the canvas edge transparent")
	_expect(int(qa.get("outer_radius_sample_count", 0)) == 360, "Orosha round-roll QA should sample the full circle")
	_expect(absf(float(qa.get("outer_radius_max", 999.0)) - float(qa.get("outer_radius_min", -999.0))) <= 1.5, "Orosha round-roll outer radius should stay effectively circular")


func _verify_manifests() -> void:
	_expect_manifest_grid("res://assets/sprites/lingpet/orosha_companion_static_25f_manifest.json", 5, 5, 25, 256, true, 1)
	_expect_manifest_grid("res://assets/sprites/lingpet/orosha_companion_idle_ground_autosprite_25f_manifest.json", 5, 5, 25, 256, false, 25)
	_expect_manifest_grid("res://assets/sprites/lingpet/orosha_companion_move_left_ground_roll_autosprite_48f_manifest.json", 8, 6, 48, 256, false, 48)
	_expect_manifest_grid("res://assets/sprites/lingpet/orosha_companion_move_right_ground_roll_autosprite_48f_manifest.json", 8, 6, 48, 256, false, 48)
	_expect_manifest_grid("res://assets/sprites/lingpet/orosha_cutin_live2d_rigid_v2_autosprite_32f_manifest.json", 8, 4, 32, 512, false, 32)
	_expect_manifest_grid("res://assets/sprites/lingpet/orosha_acquire_vfx_autosprite_16f_manifest.json", 4, 4, 16, 512, false, 16)
	_expect_manifest_grid("res://assets/sprites/lingpet/orosha_click_rolling_autosprite_98f_manifest.json", 14, 7, 98, 512, false, 64)
	_expect_manifest_grid("res://assets/sprites/lingpet/orosha_companion_click_reaction_rolling_98f_manifest.json", 14, 7, 98, 128, false, 64)


func _verify_character_info_click_live2d_mapping() -> void:
	_expect(
		CharacterInfoOverlayLingpetTextureLoader.get_panel_live2d_visual_key("orosha") == "click_reaction_anim",
		"character info panel should use Orosha's 14x7 click sheet"
	)
	_expect(
		CharacterInfoOverlayLingpetTextureLoader.get_panel_art_path("orosha") == "res://assets/sprites/lingpet/orosha_click_rolling_autosprite_98f.png",
		"character info panel should load Orosha's click sheet through the catalog"
	)
	_expect(CharacterInfoOverlayLingpetTextureLoader.uses_panel_live2d_art("orosha"), "Orosha character-info art should opt into panel Live2D playback")
	var source := CharacterInfoOverlayLingpetPresenter.panel_live2d_source_rect("orosha", Vector2(7168.0, 3584.0), 0.0)
	_expect(is_equal_approx(source.size.x, 512.0) and is_equal_approx(source.size.y, 512.0), "Orosha panel Live2D should split the click sheet into 14x7 / 512px cells")
	var next_source := CharacterInfoOverlayLingpetPresenter.panel_live2d_source_rect("orosha", Vector2(7168.0, 3584.0), 1.0 / 16.0)
	_expect(is_equal_approx(next_source.position.x, 512.0) and is_equal_approx(next_source.position.y, 0.0), "Orosha panel Live2D should advance through the 98-frame click sheet")


func _verify_acquire_live2d_sheet_contracts() -> void:
	var host := LingpetAcquireCutinOverlayHost.new()
	host._asset_pet_id = "orosha"
	_expect(host._get_cutin_anim_cols() == 8, "Orosha acquisition Live2D should use the 8-column sheet")
	_expect(host._get_cutin_anim_rows() == 4, "Orosha acquisition Live2D should use the 4-row sheet")
	_expect(host._get_cutin_anim_frame_count() == 32, "Orosha acquisition Live2D should play all 32 frames")
	_expect(host._get_cutin_dismiss_cols() == 14, "Orosha acquisition click dismiss should use the current 14-column dismiss grid")
	_expect(host._get_cutin_dismiss_rows() == 7, "Orosha acquisition click dismiss should use the current 7-row dismiss grid")
	_expect(host._get_cutin_dismiss_frame_count() == 98, "Orosha acquisition click dismiss should play the current 98-frame dismiss sheet")


func _verify_acquire_host_loads_visible_cutin_textures() -> void:
	ProjectResourceLoader.clear_caches()
	var anim_path := LingpetCatalog.get_visual_path("orosha", "cutin_anim")
	var host := LingpetAcquireCutinOverlayHost.new()
	_expect(ProjectResourceLoader.get_cached_texture(anim_path) == null, "Orosha acquisition sheet should start cold for the visibility guard")
	_expect(host.is_pet_cutin_anim_ready("orosha"), "Orosha acquisition readiness should secure the animated cut-in sheet instead of waiting forever on an empty cache")
	_expect(ProjectResourceLoader.get_cached_texture(anim_path) != null, "Orosha acquisition readiness should cache the cut-in sheet")
	for _i in 8:
		if host.prewarm_pet_assets_step("orosha"):
			break
	host._sync_assets_for_pet("orosha")
	_expect(host._cutin_anim_sheet != null, "Orosha acquisition host should draw with the catalog cut-in sheet after sync")
	_expect(host._cutin_vfx_sheet != null, "Orosha acquisition host should layer the pet-specific animated VFX sheet")


func _expect_texture_size(path: String, width: int, height: int) -> void:
	var texture := ProjectResourceLoader.load_texture(path)
	_expect(texture != null, "%s should load as a Texture2D" % path)
	if texture == null:
		return
	_expect(texture.get_width() == width and texture.get_height() == height, "%s should be %dx%d" % [path, width, height])


func _expect_manifest_grid(path: String, cols: int, rows: int, frame_count: int, cell_size: int, repeated_static_frame: bool, min_unique_frame_hashes: int) -> void:
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
	_expect(bool(grid.get("repeated_static_frame", false)) == repeated_static_frame, "%s repeated-static flag should match the accepted asset state" % path)
	var source_anchor: Dictionary = (data as Dictionary).get("source_anchor", {})
	_expect(str(source_anchor.get("path", "")).begins_with("res://assets/sprites/lingpet/orosha_"), "%s should record an Orosha source anchor" % path)
	var recon: Dictionary = (data as Dictionary).get("reconstruction_frame0", {})
	var occupancy: Array = recon.get("occupancy", [])
	var alpha_bbox: Array = recon.get("alpha_bbox", [])
	_expect(int(recon.get("grid_cols", 0)) == 10 and int(recon.get("grid_rows", 0)) == 10, "%s reconstruction mask should use the cut-in host grid" % path)
	_expect(occupancy.size() == 100, "%s reconstruction occupancy should cover the full 10x10 grid" % path)
	_expect(alpha_bbox.size() == 4, "%s reconstruction alpha bbox should be normalized" % path)
	var qa: Dictionary = (data as Dictionary).get("qa", {})
	_expect(int(qa.get("edge_alpha_max", 255)) == 0, "%s should leave every cell edge transparent" % path)
	_expect(int(qa.get("unique_frame_hashes", 0)) >= min_unique_frame_hashes, "%s should preserve the expected animated frame variety" % path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _active_pool_has(pool: Array, skill_id: String) -> bool:
	for entry_value in pool:
		if entry_value is Dictionary and str((entry_value as Dictionary).get("id", "")) == skill_id:
			return true
	return false


func _cleanup() -> void:
	ProjectResourceLoader.clear_caches()
