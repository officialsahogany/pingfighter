extends SceneTree

const GameplayStageModuleCatalog := preload("res://scripts/resources/gameplay_stage_module_catalog.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const StageRuntimeRouter := preload("res://scripts/stages/stage_runtime_router.gd")
const Stage5HongryunState := preload("res://scripts/stages/stage5/stage5_hongryun_state.gd")
const Stage5HongryunPillarBackground := preload("res://scripts/stages/stage5/stage5_hongryun_pillar_background.gd")
const Stage5HongryunPillarBackgroundPayloadFactory := preload("res://scripts/stages/stage5/stage5_hongryun_pillar_background_payload_factory.gd")
const Stage5HongryunPillarSceneDrawer := preload("res://scripts/stages/stage5/stage5_hongryun_pillar_scene_drawer.gd")
const Stage5HongryunPlayfieldRenderer := preload("res://scripts/stages/stage5/stage5_hongryun_playfield_renderer.gd")
const Stage5HongryunBossActorRenderer := preload("res://scripts/stages/stage5/stage5_hongryun_boss_actor_renderer.gd")
const Stage5HongryunActorRenderer := preload("res://scripts/stages/stage5/stage5_hongryun_actor_renderer.gd")
const Stage5HongryunBossSkillHudRenderer := preload("res://scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd")

var _failures: Array[String] = []


class FakeSkillHud:
	var prewarm_count := 0

	func prewarm_assets() -> void:
		prewarm_count += 1


class FakeRegistry:
	var skill_hud := FakeSkillHud.new()
	var fallback := RefCounted.new()

	func get_instance(key: String) -> Object:
		match key:
			"stage5_hongryun_boss_skill_hud_renderer":
				return skill_hud
			"stage1_fallback_pillar_renderer":
				return fallback
		return null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_router_and_catalog()
	_verify_background_contract()
	_verify_renderer_asset_status()
	_verify_stage5_high_refresh_lod_contract()
	_verify_state_actor_draw_contract()
	await _verify_stage5_boss_texture_prewarm()
	await _cleanup_after_checks()

	if _failures.is_empty():
		print("stage5_hongryun_visual_shell_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_router_and_catalog() -> void:
	var router := StageRuntimeRouter.new()
	_expect(str(router.get_module_key(5, "actor_renderer")) == "stage5_hongryun_actor_renderer", "Stage 5 should route to Hongryun actor renderer")
	_expect(str(router.get_module_key(5, "boss_actor_renderer")) == "stage5_hongryun_boss_actor_renderer", "Stage 5 should expose Hongryun boss actor role")
	_expect(str(router.get_module_key(5, "pillar_scene_drawer")) == "stage5_hongryun_pillar_scene_drawer", "Stage 5 should route to Hongryun pillar scene drawer")
	_expect(str(router.get_module_key(5, "stage_background")) == "stage5_hongryun_pillar_background", "Stage 5 should route to Hongryun background")
	_expect(str(router.get_module_key(5, "playfield_renderer")) == "stage5_hongryun_playfield_renderer", "Stage 5 should expose Hongryun playfield role")
	_expect(str(router.get_module_key(5, "boss_skill_hud_renderer")) == "stage5_hongryun_boss_skill_hud_renderer", "Stage 5 should keep Hongryun skill HUD route")

	var catalog := GameplayStageModuleCatalog.new()
	for key in [
		"stage5_hongryun_actor_renderer",
		"stage5_hongryun_playfield_renderer",
		"stage5_hongryun_boss_actor_renderer",
		"stage5_hongryun_pillar_background",
		"stage5_hongryun_pillar_background_payload_factory",
		"stage5_hongryun_pillar_scene_drawer",
		"stage5_hongryun_boss_skill_hud_renderer",
	]:
		var spec: Dictionary = catalog.get_spec(str(key))
		_expect(str(spec.get("path", "")) != "", "Stage 5 visual shell catalog should register %s" % str(key))


func _verify_background_contract() -> void:
	var background := Stage5HongryunPillarBackground.new()
	background.prewarm_assets()
	var initial_status: Dictionary = background.get_debug_snapshot()
	_expect(bool(initial_status.get("base_texture_loaded", false)), "Hongryun background base texture should load")
	_expect(bool(initial_status.get("inferno_texture_loaded", false)), "Hongryun inferno background texture should load")
	_expect(background.has_method("trigger_spiral_burst"), "Hongryun background should expose spiral burst hook")
	_expect(background.has_method("set_inferno_mode"), "Hongryun background should expose inferno mode hook")
	_expect(background.has_method("add_fire_impact"), "Hongryun background should expose fire impact hook")
	_expect(Stage5HongryunPillarBackground.SPIRAL_BURST_ARM_COUNT_SEVERE_LOD <= 2, "Hongryun background severe LOD should reduce spiral burst arms")
	_expect(Stage5HongryunPillarBackground.SPIRAL_BURST_PRIMARY_SEGMENTS_SEVERE_LOD <= 14, "Hongryun background severe LOD should reduce spiral arc segments")
	_expect(Stage5HongryunPillarBackground.FIRE_IMPACT_OUTER_SEGMENTS_SEVERE_LOD <= 20, "Hongryun background severe LOD should reduce fire impact arc segments")
	_expect(Stage5HongryunPillarBackground.VIGNETTE_STEPS_SEVERE_LOD <= 3, "Hongryun background severe LOD should reduce vignette passes")
	var payload_burst: Dictionary = Stage5HongryunPillarBackgroundPayloadFactory.build_spiral_burst(2, 1.5, Stage5HongryunPillarBackground.SPIRAL_BURST_LIFETIME_SEC, true)
	_expect(float(payload_burst.get("age", -1.0)) == 0.0, "spiral burst payload should start at zero age")
	_expect(float(payload_burst.get("life", 0.0)) == Stage5HongryunPillarBackground.SPIRAL_BURST_LIFETIME_SEC, "spiral burst payload should preserve configured lifetime")
	_expect(float(payload_burst.get("intensity", 0.0)) == 1.6, "inferno spiral burst payload should keep boosted intensity")
	_expect(is_equal_approx(float(payload_burst.get("phase", 0.0)), 2.0 * 0.73 + 1.5), "spiral burst payload should derive phase from queue position and time")
	var payload_impact: Dictionary = Stage5HongryunPillarBackgroundPayloadFactory.build_fire_impact(Vector2(300.0, 420.0), Stage5HongryunPillarBackground.FIRE_IMPACT_LIFETIME_SEC)
	_expect(payload_impact.get("pos", null) == Vector2(300.0, 420.0), "fire impact payload should preserve position")
	_expect(float(payload_impact.get("age", -1.0)) == 0.0, "fire impact payload should start at zero age")
	_expect(float(payload_impact.get("life", 0.0)) == Stage5HongryunPillarBackground.FIRE_IMPACT_LIFETIME_SEC, "fire impact payload should preserve configured lifetime")
	_expect(float(payload_impact.get("scale", 0.0)) == 1.0, "fire impact payload should default to scale one")

	background.trigger_spiral_burst(true)
	background.add_fire_impact(300.0, 420.0)
	background.set_inferno_mode(true)
	background.update(0.2)
	var active_status: Dictionary = background.get_debug_snapshot()
	_expect(bool(active_status.get("inferno_mode_active", false)), "inferno mode should persist until explicitly disabled")
	_expect(float(active_status.get("inferno_blend", 0.0)) > 0.0, "inferno blend should advance while active")
	_expect(int(active_status.get("spiral_burst_count", 0)) == 1, "spiral burst should be queued")
	_expect(int(active_status.get("fire_impact_count", 0)) == 1, "fire impact should be queued")
	background.reset()
	var reset_status: Dictionary = background.get_debug_snapshot()
	_expect(not bool(reset_status.get("inferno_mode_active", true)), "background reset should clear inferno mode")
	_expect(int(reset_status.get("spiral_burst_count", -1)) == 0, "background reset should clear bursts")
	_expect(int(reset_status.get("fire_impact_count", -1)) == 0, "background reset should clear impacts")
	var background_source := FileAccess.get_file_as_string("res://scripts/stages/stage5/stage5_hongryun_pillar_background.gd")
	_expect(background_source.find("Stage5HongryunPillarBackgroundPayloadFactory.build_spiral_burst") >= 0, "Hongryun background should delegate spiral burst payloads")
	_expect(background_source.find("Stage5HongryunPillarBackgroundPayloadFactory.build_fire_impact") >= 0, "Hongryun background should delegate fire impact payloads")


func _verify_renderer_asset_status() -> void:
	var registry := FakeRegistry.new()
	var pillar := Stage5HongryunPillarSceneDrawer.new()
	pillar.prewarm_assets(Callable(registry, "get_instance"), "smasher")
	var pillar_status: Dictionary = pillar.get_asset_status()
	_expect(bool(pillar_status.get("vase_lantern", false)), "pillar scene should load vase/lantern art")
	_expect(bool(pillar_status.get("snake_pot", false)), "pillar scene should load snake pot art")
	_expect(bool(pillar_status.get("cyber_snake", false)), "pillar scene should load cyber snake sheet")
	_expect(registry.skill_hud.prewarm_count == 1, "pillar scene prewarm should warm Hongryun skill HUD")

	var playfield := Stage5HongryunPlayfieldRenderer.new()
	playfield.prewarm_assets()
	var playfield_status: Dictionary = playfield.get_imagegen_asset_status()
	_expect(bool(playfield_status.get("stage5_fireball_atlas", false)), "playfield should load fireball atlas")
	_expect(str(playfield_status.get("stage5_fireball_atlas_path", "")).ends_with("stage5_hongryun_fireball_sheet_autosprite_v1.png"), "playfield should prefer AutoSprite fireball sheet")
	_expect(bool(playfield_status.get("stage5_center_border_texture", false)), "playfield should load the imagegen Hongryun center border")
	_expect(bool(playfield_status.get("stage5_center_border_draw_enabled", false)), "playfield should draw the imagegen Hongryun center border")
	_expect(str(playfield_status.get("stage5_center_border_path", "")).ends_with("stage5_hongryun_center_border_imagegen_v1.png"), "playfield should use the accepted Hongryun center border PNG")
	_expect(float(playfield_status.get("stage5_center_border_fallback_stroke", 99.0)) <= 2.0, "playfield fallback border should stay thin if the PNG is missing")
	_expect(float(playfield_status.get("stage5_center_border_collision_edge_band_px", 99.0)) <= 13.0, "playfield border should stay in the ball collision edge band")
	_expect(bool(playfield_status.get("stage5_center_border_inner_guides_removed", false)), "playfield border should not draw misleading inner guide lines")
	_verify_stage5_center_border_collision_edge_asset()
	_expect(int(playfield_status.get("trail_render_limit", 0)) <= 30, "playfield trail renderer should cap rendered trail nodes")

	var boss := Stage5HongryunBossActorRenderer.new()
	boss.prewarm_assets()
	var boss_status: Dictionary = boss.get_asset_status()
	_expect(bool(boss_status.get("stage5_hongryun_walk", false)), "boss actor should load walk sheet")
	_expect(bool(boss_status.get("stage5_hongryun_attack", false)), "boss actor should load attack sheet")
	_expect(bool(boss_status.get("stage5_hongryun_dash", false)), "boss actor should load dash sheet")
	_expect(bool(boss_status.get("stage5_hongryun_turn", false)), "boss actor should load turn sheet")
	_expect(bool(boss_status.get("stage5_hongryun_dragon_head", false)), "boss actor should load dragon head sheet")
	_expect(int(boss_status.get("turn_frame_count", 0)) == 16, "boss actor should keep 8x2 turn sheet metadata for future reactivation")
	_expect(not bool(boss_status.get("turn_pose_visible", true)), "boss actor should keep visible turn pose disabled until turn sheet is regenerated (shipped sheet packs 7 chars per row, not 8)")
	var boss_geometry: Dictionary = boss.get_debug_frame_geometry()
	var walk_source_rect: Rect2 = boss_geometry.get("walk_source_rect", Rect2())
	var walk_draw_size: Vector2 = boss_geometry.get("walk_draw_size", Vector2.ZERO)
	_expect(walk_source_rect.size.x < 620.0, "boss actor should trim walk source rect so neighboring sheet frames cannot show")
	_expect(walk_draw_size.y <= 140.0, "boss actor should keep Hongryun walk draw size below oversized preview height")

	var actor := Stage5HongryunActorRenderer.new()
	actor.prewarm_assets()
	var actor_status: Dictionary = actor.get_imagegen_asset_status()
	_expect(bool(actor_status.get("stage5_fireball_atlas", false)), "actor wrapper should report playfield assets")
	_expect(bool(actor_status.get("stage5_center_border_texture", false)), "actor wrapper should report the Hongryun center border asset")
	_expect(bool(actor_status.get("stage5_hongryun_walk", false)), "actor wrapper should report boss assets")


func _verify_stage5_center_border_collision_edge_asset() -> void:
	var path := "res://assets/sprites/hud/stage5_hongryun_center_border_imagegen_v1.png"
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	_expect(image != null, "Stage 5 center border PNG should load for collision-edge alpha audit")
	if image == null:
		return
	_expect(image.get_size() == Vector2i(760, 750), "Stage 5 center border PNG should match the 760x750 playfield")
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var inner_clear_margin_px := 28
	var inner_alpha_pixels := 0
	for y in range(inner_clear_margin_px, image.get_height() - inner_clear_margin_px):
		for x in range(inner_clear_margin_px, image.get_width() - inner_clear_margin_px):
			if image.get_pixel(x, y).a > 0.01:
				inner_alpha_pixels += 1
	_expect(inner_alpha_pixels == 0, "Stage 5 center border PNG should leave the inner playfield clear of false wall lines")


func _verify_stage5_high_refresh_lod_contract() -> void:
	var previous_max_fps: int = int(Engine.get("max_fps"))
	Engine.set("max_fps", 144)
	BattleRenderQuality.reset_cache_for_test()
	var context := {"current_stage": 5, "selected_character_type": "smasher"}
	var playfield := Stage5HongryunPlayfieldRenderer.new()
	var pillar := Stage5HongryunPillarSceneDrawer.new()
	var playfield_quality_scale: float = playfield._get_playfield_quality_scale(context)
	var pillar_quality_scale: float = pillar._get_pillar_quality_scale(context)
	var pillar_hud_context: Dictionary = pillar._with_stage5_hud_lod_context(context, pillar_quality_scale)
	var boss_source := FileAccess.get_file_as_string("res://scripts/stages/stage5/stage5_hongryun_boss_actor_renderer.gd")
	var pillar_source := FileAccess.get_file_as_string("res://scripts/stages/stage5/stage5_hongryun_pillar_scene_drawer.gd")
	var boss_hud_source := FileAccess.get_file_as_string("res://scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd")
	BattleRenderQuality.reset_cache_for_test()
	Engine.set("max_fps", previous_max_fps)

	_expect(playfield_quality_scale < 0.85, "Stage 5 playfield should honor high-refresh render LOD for smasher")
	_expect(pillar_quality_scale < 0.85, "Stage 5 pillar chrome should honor high-refresh render LOD for smasher")
	_expect(
		bool(pillar_hud_context.get("pillar_hud_static_lod", false)),
		"Stage 5 pillar HUD should trim ornamental shared HUD layers during high-refresh render LOD"
	)
	_expect(Stage5HongryunPillarSceneDrawer.INFERNO_PILLAR_TRAIL_RENDER_LIMIT_SEVERE_LOD <= 6, "Stage 5 pillar flourish should cap inferno letterbox wisps under severe LOD")
	_expect(Stage5HongryunBossSkillHudRenderer.EMPTY_ORB_ARC_SEGMENTS_SEVERE_LOD <= 14, "Stage 5 boss skill HUD should reduce dragon orb arc segments under severe LOD")
	_expect(boss_source.find("BattleRenderQuality.effect_scale(context)") >= 0, "Stage 5 boss actor should honor shared render quality LOD")
	_expect(boss_source.find("ViperAirborneLod.effect_scale(context)") < 0, "Stage 5 boss actor should not bypass shared high-refresh LOD")
	_expect(pillar_source.find("_with_stage5_hud_lod_context(context, quality_scale)") >= 0, "Stage 5 pillar draw should route shared HUD through the LOD helper")
	_expect(pillar_source.find("stage5_pillar_hud_static_lod") >= 0, "Stage 5 pillar HUD should expose its static LOD marker")
	_expect(boss_hud_source.find("stage5_hud_quality_scale") >= 0, "Stage 5 boss skill HUD should receive the pillar quality scale")


func _verify_state_actor_draw_contract() -> void:
	var state := Stage5HongryunState.new()
	state.fireball_projectiles = [{
		"pos": Vector2(300.0, 120.0),
		"vel": Vector2(0.0, 15.0),
		"radius": 8.0,
		"age": 3.0,
	}]
	state.fireball_impact_events = [{
		"pos": Vector2(320.0, 420.0),
		"reason": "player",
		"scale": 1.0,
	}]
	state.inferno_active = true
	state.inferno_phase = 2
	state.inferno_trail_elapsed_sec = 1.25
	state.inferno_trail_positions = [Vector2(300.0, 300.0), Vector2(320.0, 340.0)]
	state.boss_throwing_windup_active = true
	state.boss_throwing_windup_timer = 12.0
	var context: Dictionary = state.get_actor_draw_context()
	_expect(context.has("stage5_hongryun_fireballs"), "state actor context should include fireballs")
	_expect(context.has("stage5_hongryun_fireball_impacts"), "state actor context should include impact hints")
	_expect(context.has("stage5_hongryun_inferno_trail"), "state actor context should include inferno trail")
	_expect(context.has("stage5_hongryun_inferno_trail_elapsed_sec"), "state actor context should include inferno trail elapsed time")
	_expect(bool(context.get("stage5_hongryun_boss_throwing", false)), "state actor context should expose boss throwing windup")
	_expect(float(context.get("stage5_hongryun_boss_throw_progress", 0.0)) > 0.0, "state actor context should expose boss throwing progress")


func _verify_stage5_boss_texture_prewarm() -> void:
	var resources := BattleResources.new()
	resources.prewarm_boss_textures({"current_stage": 1})
	var stale_cache: Dictionary = resources.get_resource_cache()
	var stale_walk: Variant = stale_cache.get("boss_sprite_sheet", null)
	var stale_attack: Variant = stale_cache.get("boss_attack_sheet", null)
	var stale_dash: Variant = stale_cache.get("boss_dash_sheet", null)

	var boss := Stage5HongryunBossActorRenderer.new()
	boss.prewarm_assets()
	var selected_paths: Dictionary = boss.get_debug_selected_texture_paths({
		"boss_sprite_sheet": stale_walk,
		"boss_attack_sheet": stale_attack,
		"boss_dash_sheet": stale_dash,
	})
	_expect(str(selected_paths.get("walk", "")) == "res://assets/sprites/stage5/stage5_hongryun_boss_sheet.png", "boss actor should ignore stale shared walk texture context")
	_expect(str(selected_paths.get("attack", "")) == "res://assets/sprites/stage5/stage5_hongryun_boss_attack.png", "boss actor should ignore stale shared attack texture context")
	_expect(str(selected_paths.get("dash", "")) == "res://assets/sprites/stage5/stage5_hongryun_boss_dash.png", "boss actor should ignore stale shared dash texture context")

	var transition_resources := BattleResources.new()
	transition_resources.prewarm_boss_textures({"current_stage": 1})
	var done := false
	for _idx in range(240):
		done = transition_resources.prewarm_transition_textures_step({
			"current_stage": 5,
			"selected_character_type": "smasher",
		})
		if done:
			break
		await process_frame
	_expect(done, "Stage 5 transition prewarm should complete")
	var stage5_cache: Dictionary = transition_resources.get_resource_cache()
	_expect(_texture_path(stage5_cache.get("boss_sprite_sheet", null)) == "res://assets/sprites/stage5/stage5_hongryun_boss_sheet.png", "Stage 5 transition prewarm should replace stale walk sheet")
	_expect(_texture_path(stage5_cache.get("boss_attack_sheet", null)) == "res://assets/sprites/stage5/stage5_hongryun_boss_attack.png", "Stage 5 transition prewarm should replace stale attack sheet")
	_expect(_texture_path(stage5_cache.get("boss_dash_sheet", null)) == "res://assets/sprites/stage5/stage5_hongryun_boss_dash.png", "Stage 5 transition prewarm should replace stale dash sheet")
	_expect(_texture_path(stage5_cache.get("boss_turn_sheet", null)) == "res://assets/sprites/stage5/stage5_hongryun_boss_turn.png", "Stage 5 transition prewarm should load turn sheet")
	transition_resources.reset_transition_texture_prewarm()


func _cleanup_after_checks() -> void:
	BattleRenderQuality.reset_cache_for_test()
	ProjectResourceLoader.clear_caches()
	for _idx in range(4):
		await process_frame


func _texture_path(value: Variant) -> String:
	if value is Texture2D:
		return str((value as Texture2D).resource_path)
	return ""


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
