extends SceneTree

const PlazaScenePacked := preload("res://scenes/plaza.tscn")
const PlazaScene := preload("res://scripts/plaza/plaza_scene.gd")
const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaPlayerController := preload("res://scripts/plaza/plaza_player_controller.gd")
const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")
const PlazaLingpetStoreTransactions := preload("res://scripts/plaza/plaza_lingpet_store_transactions.gd")
const PlazaTavernTransactions := preload("res://scripts/plaza/plaza_tavern_transactions.gd")
const PlazaThemeCatalog := preload("res://scripts/plaza/plaza_theme_catalog.gd")

const PIXEL_SAMPLE_PATHS := [
	"res://assets/ui/plaza/plaza_stage1_floor_base_01_cyber_joseon_imagegen_v1.png",
	"res://assets/ui/plaza/plaza_stage1_sidescroll_ground_strip_cyber_joseon_imagegen_v1.png",
	"res://assets/ui/plaza/plaza_stage1_sidescroll_ground_strip_emissive_v1.png",
	"res://assets/ui/plaza/plaza_stage1_sidescroll_midground_wall_cyber_joseon_imagegen_v1.png",
	"res://assets/ui/plaza/plaza_stage1_sidescroll_far_sky_moon_cyber_joseon_imagegen_v1.png",
	"res://assets/ui/plaza/plaza_stage1_sidescroll_accent_neon_cutout_v1.png",
	"res://assets/ui/plaza/plaza_stage1_sidescroll_medallion_cutout_v1.png",
	"res://assets/ui/plaza/buildings/plaza_lingpia_shop_v1_building_base.png",
	"res://assets/ui/plaza/interior/plaza_shop_strewn_coin_pile_autosprite_static_v1.png",
	"res://assets/ui/plaza/interior/plaza_shop_strewn_coin_pile_autosprite_anim_sheet_v1.png",
]

var _failures: Array[String] = []


class CallbackSink:
	extends RefCounted

	var exit_calls := 0

	func exit_plaza() -> void:
		exit_calls += 1


class FakePlazaOwner:
	extends Node2D

	var selected_character_type := "smasher"
	var active_lingpet_id := ""
	var current_lingpet_id := ""
	var lingpet_id := ""
	var lingpet_state := "none"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_theme_fallback()
	_verify_stage_two_manifest_override_contract()
	_verify_player_sprite_loader_contract()
	_verify_interior_npc_texture_contract()
	_verify_interior_room_texture_contract()
	_verify_interior_object_texture_contract()
	_verify_plaza_warp_pso_prewarm_contract()
	_prewarm_stage_one()
	_prewarm_stage_two_with_manifest_override()
	await _verify_plaza_scene_runtime()
	await _verify_random_building_layout_runtime()
	await _verify_player_sprite_and_lingpet_runtime()

	if _failures.is_empty():
		print("plaza_scene_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_theme_fallback() -> void:
	_expect(PlazaThemeCatalog.normalize_stage_id(999) == PlazaThemeCatalog.DEFAULT_STAGE_ID, "unknown plaza stage should fall back to Stage 1")
	var theme: Dictionary = PlazaThemeCatalog.get_theme(999)
	_expect(str(theme.get("id", "")) == "stage1_cyber_joseon", "theme fallback should return the Stage 1 cyber-Joseon theme")


func _verify_stage_two_manifest_override_contract() -> void:
	var theme: Dictionary = PlazaThemeCatalog.get_theme(2)
	_expect(str(theme.get("id", "")) == "stage2_jungle_relic", "Stage 2 plaza theme should resolve to the jungle relic theme")
	_expect(str(theme.get("asset_slug", "")) == "jungle_relic", "Stage 2 plaza theme should expose the manifest asset slug")
	var paths := PlazaAssetLoader.get_floor_texture_paths_for_test(2)
	for key in ["base_01", "ground_strip", "ground_strip_emissive", "midground_wall", "far_sky"]:
		_expect(str(paths.get(key, "")) != "", "Stage 2 floor fallback should expose %s" % key)
	_expect(str(paths.get("ground_strip", "")).find("plaza_stage2_") >= 0, "Stage 2 should use its jungle relic ground manifest asset")
	_expect(str(paths.get("ground_strip_emissive", "")).find("plaza_stage2_") >= 0, "Stage 2 should use its jungle relic ground emissive manifest asset")
	_expect(str(paths.get("midground_wall", "")).find("plaza_stage2_") >= 0, "Stage 2 should use its jungle relic midground manifest asset")
	_expect(str(paths.get("far_sky", "")).find("plaza_stage2_") >= 0, "Stage 2 should use its jungle relic sky manifest asset")
	_expect(str(paths.get("base_01", "")).find("plaza_stage1_") >= 0, "Stage 2 top-down floor tiles should intentionally keep Stage 1 fallback in v1")


func _verify_player_sprite_loader_contract() -> void:
	for character_type in ["smasher", "viper", "soldier"]:
		var paths: Dictionary = PlazaAssetLoader.get_player_texture_paths_for_test(character_type)
		_expect(str(paths.get("character_type", "")) == character_type, "plaza player loader should normalize %s" % character_type)
		for key in ["idle", "walk_left", "walk_right"]:
			var path := str(paths.get(key, ""))
			_expect(path.find("_subculture_") >= 0 and path.ends_with(".png"), "%s should expose a %s subculture sheet" % [character_type, key])
	for fallback_character in ["optimus", "baltor", "blacksmith"]:
		var fallback_paths: Dictionary = PlazaAssetLoader.get_player_texture_paths_for_test(fallback_character)
		_expect(str(fallback_paths.get("idle", "")) == "", "%s should keep the neutral plaza fallback until a walk sheet exists" % fallback_character)


func _verify_interior_npc_texture_contract() -> void:
	var paths: Dictionary = PlazaAssetLoader.get_interior_npc_texture_paths_for_test()
	for building_type in ["shop", "bank", "gacha", "lingpet_store", "blacksmith", "tavern", "academy"]:
		var path := str(paths.get(building_type, ""))
		_expect(path.begins_with("res://assets/ui/plaza/interior/"), "%s should use a plaza interior NPC texture path" % building_type)
		_expect(path.ends_with("_imagegen_v1.png"), "%s should use the accepted imagegen v1 NPC PNG" % building_type)
		_expect(FileAccess.file_exists(path), "%s interior NPC PNG should exist" % building_type)
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		_expect(image != null and not image.is_empty(), "%s interior NPC PNG should load as an image" % building_type)
		if image != null and not image.is_empty():
			_expect(image.get_size() == Vector2i(512, 880), "%s interior NPC PNG should keep the 512x880 source-downsample size" % building_type)
			_expect(image.get_pixel(0, 0).a < 0.001, "%s interior NPC PNG should have transparent corners" % building_type)
			_expect(image.get_pixel(image.get_width() - 1, image.get_height() - 1).a < 0.001, "%s interior NPC PNG should have transparent corners" % building_type)
	_verify_interior_npc_qa_file()


func _verify_interior_room_texture_contract() -> void:
	var paths: Dictionary = PlazaAssetLoader.get_interior_room_texture_paths_for_test()
	var shop_path := str(paths.get("shop", ""))
	_expect(shop_path == "res://assets/ui/plaza/interior/plaza_stage1_interior_shop_room_topview_imagegen_v2.png", "shop interior should expose the accepted top-view room backdrop path")
	_expect(FileAccess.file_exists(shop_path), "shop interior room backdrop PNG should exist")
	var image := Image.load_from_file(ProjectSettings.globalize_path(shop_path))
	_expect(image != null and not image.is_empty(), "shop interior room backdrop PNG should load as an image")
	if image != null and not image.is_empty():
		_expect(image.get_width() >= 1000 and image.get_height() >= 1000, "shop interior room backdrop should keep the high-resolution imagegen source")
		var sample := image.get_pixel(image.get_width() / 2, image.get_height() / 2)
		_expect(sample.a > 0.99, "shop interior room backdrop should be an opaque background")


func _verify_interior_object_texture_contract() -> void:
	var paths: Dictionary = PlazaAssetLoader.get_interior_object_texture_paths_for_test()
	for object_kind in ["crystal", "capsule", "sell"]:
		var path := str(paths.get(object_kind, ""))
		_expect(path == "res://assets/ui/plaza/interior/plaza_stage1_interior_shop_object_%s_imagegen_v1.png" % ("sell_device" if object_kind == "sell" else object_kind), "%s shop object should expose the accepted imagegen v1 path" % object_kind)
		_expect(FileAccess.file_exists(path), "%s shop object PNG should exist" % object_kind)
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		_expect(image != null and not image.is_empty(), "%s shop object PNG should load as an image" % object_kind)
		if image != null and not image.is_empty():
			_expect(image.get_size() == Vector2i(512, 512), "%s shop object should keep the normalized 512px transparent cutout" % object_kind)
			_expect(image.get_pixel(0, 0).a < 0.001, "%s shop object should have transparent corners" % object_kind)
			var sample := image.get_pixel(image.get_width() / 2, image.get_height() / 2)
			_expect(sample.a > 0.05, "%s shop object should occupy the center of its normalized cutout" % object_kind)


func _verify_interior_npc_qa_file() -> void:
	var manifest_path := "res://assets/ui/plaza/interior/plaza_lingpia_interior_npc_imagegen_v1_manifest.json"
	_expect(FileAccess.file_exists(manifest_path), "interior NPC imagegen manifest should exist")
	var qa_path := "res://assets/ui/plaza/interior/plaza_lingpia_interior_npc_imagegen_v1_qa.json"
	_expect(FileAccess.file_exists(qa_path), "interior NPC QA manifest should exist")
	var file := FileAccess.open(qa_path, FileAccess.READ)
	_expect(file != null, "interior NPC QA manifest should open")
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_expect(parsed is Dictionary, "interior NPC QA manifest should parse as a dictionary")
	if not (parsed is Dictionary):
		return
	var assets: Array = (parsed as Dictionary).get("assets", [])
	_expect(assets.size() == 7, "interior NPC QA manifest should track all seven building NPCs")
	for asset in assets:
		if not (asset is Dictionary):
			_expect(false, "interior NPC QA entries should be dictionaries")
			continue
		var entry := asset as Dictionary
		_expect(int(entry.get("visible_magenta_pixels", -1)) == 0, "%s should have no visible magenta residue" % str(entry.get("file", "npc")))
		_expect(int(entry.get("corner_alpha_max", 255)) == 0, "%s should keep transparent corners" % str(entry.get("file", "npc")))


func _verify_plaza_warp_pso_prewarm_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/core/battle_pso_prewarmer.gd")
	_expect(source.find("PlazaWarpPillarFxHost") >= 0, "battle PSO prewarmer should own the plaza warp pillar host before plaza arrival")
	_expect(source.find("_prewarm_plaza_warp_pillar_shader_states") >= 0, "battle PSO prewarmer should expose a plaza warp pillar draw warmup step")
	var body := _function_body(source, "func _prewarm_plaza_warp_pillar_shader_states")
	_expect(body.find("sync_state") >= 0, "plaza warp pillar warmup should issue the real host sync_state path")
	_expect(body.find("\"phase\": \"arrive\"") >= 0, "plaza warp pillar warmup should cover the arrival phase")
	_expect(body.find("\"phase\": \"exit\"") >= 0, "plaza warp pillar warmup should cover the exit phase")


func _prewarm_stage_one() -> void:
	PlazaScene.reset_prewarm_assets_for_test()
	var guard := 0
	while not bool(PlazaScene.prewarm_assets_blocking_step(1)):
		guard += 1
		if guard > 96:
			_expect(false, "plaza asset prewarm should finish within the staged texture budget")
			return
	var status: Dictionary = PlazaScene.get_prewarm_asset_status()
	_expect(bool(status.get("complete", false)), "plaza prewarm should report completion")
	_expect(int(status.get("stage_id", 0)) == 1, "plaza prewarm should remember the normalized stage")


func _prewarm_stage_two_with_manifest_override() -> void:
	PlazaScene.reset_prewarm_assets_for_test()
	var guard := 0
	while not bool(PlazaScene.prewarm_assets_blocking_step(2)):
		guard += 1
		if guard > 96:
			_expect(false, "Stage 2 plaza manifest prewarm should finish within the staged texture budget")
			return
	var status: Dictionary = PlazaScene.get_prewarm_asset_status()
	_expect(bool(status.get("complete", false)), "Stage 2 plaza manifest prewarm should report completion")
	_expect(int(status.get("stage_id", 0)) == 2, "Stage 2 plaza manifest prewarm should remember the requested stage")
	_expect(_status_has_loaded_path(status, "plaza_stage2_sidescroll_ground_strip_jungle_relic"), "Stage 2 prewarm should load the jungle relic ground strip")
	_expect(_status_has_loaded_path(status, "plaza_stage2_sidescroll_midground_wall_jungle_relic"), "Stage 2 prewarm should load the jungle relic midground wall")
	_expect(_status_has_loaded_path(status, "plaza_stage2_sidescroll_far_sky_moon_jungle_relic"), "Stage 2 prewarm should load the jungle relic far sky")


func _verify_plaza_scene_runtime() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(760, 750)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var sink := CallbackSink.new()
	var scene := PlazaScenePacked.instantiate() as Control
	var save_path := _smoke_save_path("runtime")
	_cleanup_save(save_path)
	_expect(scene != null, "plaza scene should instantiate")
	if scene == null:
		viewport.queue_free()
		_cleanup_save(save_path)
		return
	viewport.add_child(scene)
	scene.configure({"current_stage": 999, "plaza_save_path": save_path, "full_layout_for_test": true}, Callable(sink, "exit_plaza"), true)
	scene.update_plaza(1.0 / 60.0)

	var status: Dictionary = scene.get_status()
	_expect(int(status.get("current_stage", 0)) == 1, "plaza scene should normalize unknown stages to Stage 1")
	_expect(bool(status.get("side_scroll", false)), "plaza scene should run in the side-scroll street layout")
	_expect(float((status.get("world_size", Vector2.ZERO) as Vector2).x) > 760.0, "side-scroll plaza should expose a wider world than the game canvas")
	_expect(int(status.get("building_count", 0)) == 7, "Stage 1 full-layout test mode should load the seven accepted building kits")
	_expect(int(status.get("collision_rect_count", -1)) == 0, "side-scroll plaza should keep buildings as background storefronts without blocking footprints")
	_verify_flicker_samples_are_instance_seeded(scene)
	_verify_character_info_tab_toggle(scene, "plaza street")
	_verify_building_menu_shells(scene)

	var bank: Dictionary = _find_building(scene.get_building_specs_for_test(), "bank")
	_expect(not bank.is_empty(), "plaza should include the bank building spec")
	if not bank.is_empty():
		var interaction_rect: Rect2 = bank.get("interaction_rect", Rect2())
		scene.set_player_pos_for_test(Vector2(interaction_rect.get_center().x, float(status.get("ground_y", 0.0))))
		_expect(scene.trigger_interaction_for_test(), "player in a building interaction zone should open the menu dialog placeholder")
		status = scene.get_status()
		_expect(bool(status.get("menu_open", false)), "building interaction should open the S5 menu shell")
		_expect(str(status.get("active_menu_type", "")) == "bank", "bank interaction should open the bank menu shell")

		scene.set_player_pos_for_test(Vector2(120.0, float(status.get("ground_y", 0.0)) - 80.0))
		var before_pos: Vector2 = scene.get_status().get("player_pos", Vector2.ZERO)
		var before_camera := float(scene.get_status().get("camera_x", 0.0))
		scene.move_player_for_test(Vector2.RIGHT, 1.0 / 60.0)
		var after_pos: Vector2 = scene.get_status().get("player_pos", Vector2.ZERO)
		_expect(after_pos.is_equal_approx(before_pos), "open building menu should block player walking")
		_expect(is_equal_approx(float(scene.get_status().get("camera_x", 0.0)), before_camera), "open building menu should block camera movement")
		var exit_zone_while_menu: Rect2 = scene.get_status().get("exit_zone", Rect2())
		scene.set_player_pos_for_test(Vector2(exit_zone_while_menu.get_center().x, float(status.get("ground_y", 0.0))))
		_expect(not scene.trigger_interaction_for_test(), "open building menu should block EXIT interaction")
		_expect(sink.exit_calls == 0, "blocked EXIT interaction should not invoke the delayed callback")
		_expect(not scene.trigger_menu_action_for_test(0), "empty bank action should not mutate the S6 bank ledger")
		_send_key(scene, KEY_ESCAPE)
		scene.advance_building_transition_for_test(1.0)
		status = scene.get_status()
		_expect(not bool(status.get("menu_open", true)), "ESC should close the building menu shell")

		scene.set_player_pos_for_test(Vector2(interaction_rect.get_center().x, float(status.get("ground_y", 0.0))))
		_expect(scene.trigger_interaction_for_test(false), "building interaction should start the entry transition")
		status = scene.get_status()
		_expect(bool(status.get("building_transition_active", false)), "building interaction should keep the menu closed during the entry transition")
		_expect(str(status.get("building_transition_phase", "")) == "enter", "building entry should start in enter phase")
		_expect(not bool(status.get("warp_pillar_fx_active", true)), "building entry should not activate the plaza light-pillar FX host")
		_expect(int(status.get("warp_pillar_fx_actor_count", -1)) == 0, "building entry should not send actor slots to the light-pillar FX host")
		_expect(not bool(status.get("menu_open", false)), "building menu should wait for the entry transition to finish")
		before_pos = scene.get_status().get("player_pos", Vector2.ZERO)
		scene.move_player_for_test(Vector2.RIGHT, 1.0 / 60.0)
		after_pos = scene.get_status().get("player_pos", Vector2.ZERO)
		_expect(after_pos.is_equal_approx(before_pos), "building entry should block player walking")
		scene.advance_building_transition_for_test(1.0)
		status = scene.get_status()
		_expect(not bool(status.get("building_transition_active", true)), "building entry should finish after its one-second budget")
		_expect(bool(status.get("menu_open", false)), "building menu should open after the entry transition")
		scene.close_menu_for_test(false)
		status = scene.get_status()
		_expect(bool(status.get("building_transition_active", false)), "closing the menu should start the return entry transition")
		_expect(str(status.get("building_transition_phase", "")) == "return", "building return should report return phase")
		_expect(not bool(status.get("warp_pillar_fx_active", true)), "building return should keep the plaza light-pillar FX host off")
		scene.advance_building_transition_for_test(1.0)
		status = scene.get_status()
		_expect(not bool(status.get("building_transition_active", true)), "building return should finish after its one-second budget")
		_expect(not bool(status.get("warp_pillar_fx_active", true)), "light-pillar FX host should stay hidden after building return")

		# Mouse click on the building BODY (visual_rect center, above the base
		# entrance strip) must open the menu -- not only the narrow interaction_rect.
		var bank_visual: Rect2 = bank.get("visual_rect", Rect2())
		var bank_interaction: Rect2 = bank.get("interaction_rect", Rect2())
		var body_point := bank_visual.get_center()
		_expect(bank_visual.size != Vector2.ZERO, "bank spec should expose a visual_rect for mouse picking")
		_expect(not bank_interaction.has_point(body_point), "building body center should sit above the base interaction strip (so this proves body-click, not base-strip)")
		_expect(not str(scene.get_building_at_world_pos_for_test(body_point).get("type", "")).is_empty(), "mouse pick at the building body should resolve a building")
		_expect(str(scene.get_building_at_world_pos_for_test(body_point).get("type", "")) == "bank", "mouse pick at the bank body should resolve the bank")
		_expect(scene.click_world_pos_for_test(body_point), "left-click on the bank body should open its menu")
		_expect(str(scene.get_status().get("active_menu_type", "")) == "bank", "body-click should open the bank menu shell")
		_expect(not scene.click_world_pos_for_test(body_point), "click while a menu is open should be a no-op")
		scene.close_menu_for_test()
		_expect(scene.get_building_at_world_pos_for_test(Vector2(5.0, 5.0)).is_empty(), "mouse pick at empty sky should resolve no building")

		scene.set_player_pos_for_test(Vector2(120.0, float(status.get("ground_y", 0.0)) - 80.0))
		before_pos = scene.get_status().get("player_pos", Vector2.ZERO)
		scene.move_player_for_test(Vector2.RIGHT, 1.0 / 60.0)
		after_pos = scene.get_status().get("player_pos", Vector2.ZERO)
		_expect(after_pos.x > before_pos.x, "side-scroll plaza should move the player on the X axis after the menu closes")
		_expect(absf(after_pos.y - float(status.get("ground_y", 0.0))) <= 0.01, "side-scroll plaza should clamp the player to the ground line")

	scene.set_player_pos_for_test(Vector2(1600.0, float(status.get("ground_y", 0.0))))
	status = scene.get_status()
	_expect(float(status.get("camera_x", 0.0)) > 0.0, "side-scroll plaza should advance the camera on the X axis")

	var exit_zone: Rect2 = scene.get_status().get("exit_zone", Rect2())
	scene.set_player_pos_for_test(Vector2(exit_zone.get_center().x, float(status.get("ground_y", 0.0))))
	_expect(scene.trigger_interaction_for_test(), "player in the plaza exit zone should trigger exit")
	status = scene.get_status()
	_expect(bool(status.get("plaza_warp_active", false)), "plaza exit should start the light-pillar exit phase")
	_expect(str(status.get("plaza_warp_phase", "")) == "exit", "plaza exit should report exit phase")
	_expect(bool(status.get("warp_pillar_fx_active", false)), "plaza exit should activate the light-pillar FX host")
	_expect(sink.exit_calls == 0, "plaza exit should delay the stage-transition callback until the light pillar finishes")
	scene.advance_plaza_warp_transition_for_test(1.0)
	status = scene.get_status()
	_expect(not bool(status.get("plaza_warp_active", true)), "plaza exit light pillar should finish after its one-second budget")
	_expect(sink.exit_calls == 1, "plaza exit should invoke the delayed stage-transition callback exactly once after the light pillar")

	for _idx in range(4):
		await process_frame
	_verify_nonblank_viewport(viewport)
	viewport.queue_free()
	_cleanup_save(save_path)


func _verify_random_building_layout_runtime() -> void:
	var save_path := _smoke_save_path("random_layout")
	_cleanup_save(save_path)
	var store := PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.set_stage_map_seed_for_test(1, 424242)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(760, 750)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := PlazaScenePacked.instantiate() as Control
	_expect(scene != null, "plaza random layout scene should instantiate")
	if scene == null:
		viewport.queue_free()
		_cleanup_save(save_path)
		return
	viewport.add_child(scene)
	scene.configure({"current_stage": 1, "plaza_save_path": save_path}, Callable(), true)
	scene.update_plaza(1.0 / 60.0)
	var status: Dictionary = scene.get_status()
	_expect(int(status.get("map_seed", 0)) == 424242, "random layout should use the persisted stage map seed")
	_expect(int(status.get("building_count", 0)) >= 2 and int(status.get("building_count", 0)) <= 5, "random layout should keep the building count in the 2..5 range")
	_expect(is_equal_approx(float((status.get("world_size", Vector2.ZERO) as Vector2).x), 1900.0), "random layout should use the compact Stage 1 plaza width")
	var specs: Array[Dictionary] = scene.get_building_specs_for_test()
	_expect(not _find_building(specs, "bank").is_empty(), "random layout should always include the bank")
	_verify_interaction_rects_do_not_overlap(specs)
	var exit_zone: Rect2 = status.get("exit_zone", Rect2())
	_expect(exit_zone.position.x > 1600.0 and exit_zone.end.x <= 1900.0, "compact plaza exit should stay near the right edge")
	_verify_minimap_state(scene, specs)
	viewport.queue_free()
	_cleanup_save(save_path)

	var due_path := _smoke_save_path("due_tavern")
	_cleanup_save(due_path)
	var due_store := PlazaSaveStore.new()
	due_store.set_save_path(due_path)
	due_store.set_stage_map_seed_for_test(2, 515151)
	due_store.perform_tavern_accept_quest(1, PlazaTavernTransactions.get_stage_offer(1), false)
	var due_viewport := SubViewport.new()
	due_viewport.size = Vector2i(760, 750)
	due_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(due_viewport)
	var due_scene := PlazaScenePacked.instantiate() as Control
	_expect(due_scene != null, "plaza due tavern scene should instantiate")
	if due_scene == null:
		due_viewport.queue_free()
		_cleanup_save(due_path)
		return
	due_viewport.add_child(due_scene)
	due_scene.configure({"current_stage": 2, "plaza_save_path": due_path}, Callable(), true)
	_expect(not _find_building(due_scene.get_building_specs_for_test(), "tavern").is_empty(), "random layout should force tavern when an accepted quest is due for report")
	due_viewport.queue_free()
	_cleanup_save(due_path)


func _verify_player_sprite_and_lingpet_runtime() -> void:
	var save_path := _smoke_save_path("player_sprite")
	_cleanup_save(save_path)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(760, 750)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	for character_type in ["smasher", "viper", "soldier"]:
		var scene := PlazaScenePacked.instantiate() as Control
		_expect(scene != null, "%s plaza scene should instantiate" % character_type)
		if scene == null:
			continue
		viewport.add_child(scene)
		scene.configure(
			{
				"current_stage": 1,
				"plaza_save_path": save_path,
				"selected_character_type": character_type,
				"full_layout_for_test": true,
			},
			Callable(),
			true
		)
		scene.update_plaza(1.0 / 60.0)
		var status: Dictionary = scene.get_status()
		_expect(str(status.get("selected_character_type", "")) == character_type, "%s should be the active plaza player character" % character_type)
		_expect(bool(status.get("player_sprite_loaded", false)), "%s plaza walk/idle sheet should load" % character_type)
		_expect(str(status.get("player_sprite_mode", "")) == "sheet", "%s should render from a player sheet" % character_type)
		scene.queue_free()

	for fallback_character in ["optimus", "baltor", "blacksmith"]:
		var fallback_scene := PlazaScenePacked.instantiate() as Control
		_expect(fallback_scene != null, "%s fallback plaza scene should instantiate" % fallback_character)
		if fallback_scene == null:
			continue
		viewport.add_child(fallback_scene)
		fallback_scene.configure(
			{
				"current_stage": 1,
				"plaza_save_path": save_path,
				"selected_character_type": fallback_character,
				"full_layout_for_test": true,
			},
			Callable(),
			true
		)
		var fallback_status: Dictionary = fallback_scene.get_status()
		_expect(not bool(fallback_status.get("player_sprite_loaded", true)), "%s should not claim a missing plaza walk sheet" % fallback_character)
		_expect(str(fallback_status.get("player_sprite_mode", "")) == "neutral_placeholder", "%s should use the neutral silhouette fallback" % fallback_character)
		fallback_scene.queue_free()

	var owner := FakePlazaOwner.new()
	owner.selected_character_type = "smasher"
	owner.active_lingpet_id = "maribo"
	owner.current_lingpet_id = "maribo"
	owner.lingpet_id = "maribo"
	owner.lingpet_state = "companion"
	viewport.add_child(owner)
	var lingpet_scene := PlazaScenePacked.instantiate() as Control
	_expect(lingpet_scene != null, "lingpet follower plaza scene should instantiate")
	if lingpet_scene != null:
		viewport.add_child(lingpet_scene)
		lingpet_scene.configure(
			{
				"current_stage": 1,
				"plaza_save_path": save_path,
				"runtime_owner": owner,
				"full_layout_for_test": true,
			},
			Callable(),
			true
		)
		var lingpet_status: Dictionary = lingpet_scene.get_status()
		_expect(bool(lingpet_status.get("lingpet_companion_visible", false)), "active lingpet companion should render in the plaza")
		_expect(str(lingpet_status.get("lingpet_companion_pet_id", "")) == "maribo", "plaza follower should use the active lingpet id")
		var player_pos: Vector2 = lingpet_status.get("player_pos", Vector2.ZERO)
		var follower_pos: Vector2 = lingpet_status.get("lingpet_follower_pos", Vector2.ZERO)
		_expect(follower_pos.x < player_pos.x, "lingpet follower should start behind the right-facing player")
		_expect(follower_pos.y < player_pos.y, "lingpet follower should keep a visible vertical offset above the ground line")
		lingpet_scene.move_player_for_test(Vector2.RIGHT, 1.0 / 60.0)
		var moved_status: Dictionary = lingpet_scene.get_status()
		var moved_follower_pos: Vector2 = moved_status.get("lingpet_follower_pos", Vector2.ZERO)
		_expect(moved_follower_pos.x > follower_pos.x, "lingpet follower should trail after player movement")
		lingpet_scene.queue_free()

	viewport.queue_free()
	_cleanup_save(save_path)


func _verify_flicker_samples_are_instance_seeded(scene: Control) -> void:
	var samples: Dictionary = scene.get_flicker_samples_for_test()
	var unique_values := {}
	for value in samples.values():
		unique_values[snappedf(float(value), 0.001)] = true
	_expect(unique_values.size() >= 3, "plaza flicker samples should vary by per-instance seed within the same tick")


func _verify_building_menu_shells(scene: Control) -> void:
	var expected_titles := {
		"shop": "상점",
		"bank": "은행",
		"gacha": "가챠샵",
		"lingpet_store": "링펫스토어",
		"blacksmith": "대장간",
		"tavern": "선술집",
		"academy": "아카데미",
	}
	var expected_actions := {
		"shop": [],
		"bank": ["예금 100G", "출금 100G", "이자 정산"],
		"gacha": ["액티브 캡슐 뽑기 150G"],
		"lingpet_store": ["공명 알 뽑기 250G", "링펫 관리"],
		"blacksmith": ["마지막 아이템 강화"],
		"tavern": ["퀘스트 받기"],
		"academy": ["스킬 획득", "스킬 교환"],
	}
	for building_type in expected_titles.keys():
		var spec := _find_building(scene.get_building_specs_for_test(), str(building_type))
		_expect(not spec.is_empty(), "plaza should include %s building spec" % building_type)
		if spec.is_empty():
			continue
		var interaction_rect: Rect2 = spec.get("interaction_rect", Rect2())
		var ground_y := float(scene.get_status().get("ground_y", 0.0))
		scene.set_player_pos_for_test(Vector2(interaction_rect.get_center().x, ground_y))
		_expect(scene.trigger_interaction_for_test(), "%s interaction should open a menu shell" % building_type)
		var status: Dictionary = scene.get_status()
		_expect(bool(status.get("menu_open", false)), "%s menu shell should report open" % building_type)
		_expect(bool(status.get("interior_view_active", false)), "%s menu shell should open the dedicated interior view" % building_type)
		_expect(bool(status.get("interior_room_replaces_plaza", false)), "%s interior view should replace the plaza street visually" % building_type)
		_expect(str(status.get("active_menu_type", "")) == str(building_type), "%s menu shell should report the active menu type" % building_type)
		_expect(str(status.get("active_menu_title", "")) == str(expected_titles[building_type]), "%s menu shell should use the expected title" % building_type)
		_verify_character_info_tab_toggle(scene, "%s interior" % str(building_type))
		var expected_action_labels: Array = expected_actions[building_type]
		if str(building_type) == "academy":
			expected_action_labels = ["스킬 수업 200G", "스킬 교환"]
		if str(building_type) == "lingpet_store":
			expected_action_labels = PlazaLingpetStoreTransactions.get_menu_action_labels(null)
		if str(building_type) == "tavern":
			expected_action_labels = ["의뢰 받기", "의뢰 보고"]
		_expect(_string_arrays_equal(status.get("active_menu_actions", []), expected_action_labels), "%s menu shell should expose the expected action stubs" % building_type)
		if str(building_type) == "shop":
			_expect(bool(status.get("interior_room_texture_loaded", false)), "shop interior should load the generated room backdrop texture")
			_expect(int(status.get("interior_object_texture_count", 0)) >= 15, "shop interior should load generated trade, strewn static, and AutoSprite animation textures")
			_expect(int(status.get("shop_inventory_count", 0)) >= 5, "shop menu should roll a passive/legendary stock inventory on open")
			_expect(int(status.get("interior_shop_inventory_count", 0)) >= 5, "shop interior should receive the rolled stock inventory")
			var interior_status: Dictionary = status.get("interior_view_status", {})
			_expect(int(interior_status.get("object_count", 0)) == 1, "shop interior should expose exactly one tabletop trade object")
			var removed_hover_status: Dictionary = scene.hover_interior_object_for_test("shop_strewn_money_bundle")
			_expect(str(removed_hover_status.get("interior_hovered_object_id", "")) == "", "shop interior should not expose extra tabletop props")
			var hover_status: Dictionary = scene.hover_interior_object_for_test("shop_strewn_coin_pile")
			_expect(str(hover_status.get("interior_hovered_object_id", "")) == "shop_strewn_coin_pile", "shop interior should hover the coin pile trade entry")
			var click_status: Dictionary = scene.click_interior_object_for_test("shop_strewn_coin_pile")
			_expect(bool(click_status.get("interior_shop_click_animation_active", false)), "shop strewn item click should start the tabletop click animation")
			_expect(str(click_status.get("interior_selected_object_id", "")) == "shop_strewn_coin_pile", "shop click animation should stay bound to the clicked coin pile")
			var trade_status: Dictionary = scene.advance_interior_view_for_test(0.75)
			_expect(bool(trade_status.get("trade_ui_open", false)), "shop strewn item animation should open the trade UI")
			status = scene.get_status()
			_expect(bool(status.get("interior_trade_ui_open", false)), "shop interior status should expose the open trade UI")
		scene.close_menu_for_test()


func _verify_nonblank_viewport(viewport: SubViewport) -> void:
	_expect(viewport != null and viewport.size == Vector2i(760, 750), "plaza viewport should keep the 760x750 game canvas contract")
	_verify_nonblank_asset_pixels()


func _verify_nonblank_asset_pixels() -> void:
	for path in PIXEL_SAMPLE_PATHS:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		_expect(image != null and image.get_width() > 0 and image.get_height() > 0, "plaza pixel fallback should load %s" % path)
		if image == null:
			continue
		var lit_samples := 0
		var step_y: int = max(1, int(image.get_height() / 16))
		var step_x: int = max(1, int(image.get_width() / 16))
		for y in range(0, image.get_height(), step_y):
			for x in range(0, image.get_width(), step_x):
				var color: Color = image.get_pixel(x, y)
				if color.a > 0.05 and color.r + color.g + color.b > 0.20:
					lit_samples += 1
		_expect(lit_samples >= 8, "plaza pixel fallback should find visible nonblank pixels in %s" % path)


func _find_building(specs: Array, building_type: String) -> Dictionary:
	for spec_value in specs:
		if spec_value is Dictionary and str((spec_value as Dictionary).get("type", "")) == building_type:
			return (spec_value as Dictionary)
	return {}


func _verify_interaction_rects_do_not_overlap(specs: Array) -> void:
	var rects: Array[Rect2] = []
	for spec in specs:
		if spec is Dictionary:
			rects.append((spec as Dictionary).get("interaction_rect", Rect2()))
	rects.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	for idx in range(1, rects.size()):
		_expect(rects[idx - 1].end.x + 20.0 <= rects[idx].position.x, "random building interaction zones should keep a playable gap")


func _verify_minimap_state(scene: Control, specs: Array[Dictionary]) -> void:
	var status: Dictionary = scene.get_status()
	var state_value: Variant = status.get("minimap_state", {})
	_expect(state_value is Dictionary, "plaza status should expose minimap state")
	if not (state_value is Dictionary):
		return
	var state := state_value as Dictionary
	var track_rect: Rect2 = state.get("track_rect", Rect2())
	_expect(track_rect.size.x >= 120.0 and track_rect.size.y > 0.0, "minimap should expose a horizontal track")
	var markers_value: Variant = state.get("building_markers", [])
	_expect(markers_value is Array, "minimap should expose building markers")
	if markers_value is Array:
		var markers := markers_value as Array
		_expect(markers.size() == specs.size(), "minimap should map every spawned building to a marker")
		for marker_value in markers:
			if not (marker_value is Dictionary):
				_expect(false, "minimap marker should be a dictionary")
				continue
			var marker := marker_value as Dictionary
			var marker_pos: Vector2 = marker.get("position", Vector2.ZERO)
			_expect(marker_pos.x >= track_rect.position.x and marker_pos.x <= track_rect.end.x, "minimap building marker should stay inside the track")
			_expect(str(marker.get("identity_emblem_id", "")) != "", "minimap building marker should expose the canonical emblem id")
			var icon_pos: Vector2 = marker.get("icon_position", Vector2.ZERO)
			_expect(icon_pos.x >= track_rect.position.x and icon_pos.x <= track_rect.end.x, "minimap emblem icon should stay horizontally inside the track")
			_expect(icon_pos.y < track_rect.position.y, "minimap emblem icon should sit above the location tick")
	var player_marker: Vector2 = state.get("player_marker", Vector2.ZERO)
	var exit_marker: Vector2 = state.get("exit_marker", Vector2.ZERO)
	_expect(player_marker.x >= track_rect.position.x and player_marker.x <= track_rect.end.x, "minimap player marker should stay inside the track")
	_expect(exit_marker.x > player_marker.x and exit_marker.x <= track_rect.end.x, "minimap exit marker should sit near the right end")
	var ground_y := float(status.get("ground_y", 0.0))
	var initial_player_x := player_marker.x
	scene.set_player_pos_for_test(Vector2(1850.0, ground_y))
	var right_state_value: Variant = scene.get_status().get("minimap_state", {})
	if right_state_value is Dictionary:
		var right_state := right_state_value as Dictionary
		var right_player_marker: Vector2 = right_state.get("player_marker", Vector2.ZERO)
		_expect(right_player_marker.x > initial_player_x + track_rect.size.x * 0.5, "minimap player marker should advance with world X")
		_expect(right_player_marker.x <= track_rect.end.x, "minimap player marker should clamp inside the track at the right edge")


func _status_has_loaded_path(status: Dictionary, path_fragment: String) -> bool:
	for key in status.keys():
		if str(key).find(path_fragment) >= 0 and bool(status.get(key, false)):
			return true
	return false


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)


func _send_key(scene: Control, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	scene.handle_plaza_input(event)


func _verify_character_info_tab_toggle(scene: Control, context: String) -> void:
	_send_key(scene, KEY_TAB)
	var status: Dictionary = scene.get_status()
	_expect(bool(status.get("character_info_overlay_active", false)), "%s Tab should open character info overlay" % context)
	_expect(bool(status.get("character_info_overlay_visible", false)), "%s character info overlay should be visible" % context)
	_send_key(scene, KEY_TAB)
	status = scene.get_status()
	_expect(not bool(status.get("character_info_overlay_active", true)), "%s second Tab should close character info overlay" % context)


func _cleanup_save(path: String) -> void:
	var backup_path := path.trim_suffix(".cfg") + ".last_good.cfg"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))


func _smoke_save_path(slug: String) -> String:
	return "res://.tmp/plaza_scene_smoke_%s_%d_%d.cfg" % [
		slug,
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]


func _string_arrays_equal(left_value: Variant, right_value: Variant) -> bool:
	if not (left_value is Array) or not (right_value is Array):
		return false
	var left := left_value as Array
	var right := right_value as Array
	if left.size() != right.size():
		return false
	for idx in range(left.size()):
		if str(left[idx]) != str(right[idx]):
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
