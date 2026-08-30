extends SceneTree

const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
const Stage1DaljiBossSkillHudRenderer := preload("res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd")
const Stage1PillarHudSceneDrawer := preload("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")
const Stage1PillarSceneDrawer := preload("res://scripts/stages/stage1/stage1_pillar_scene_drawer.gd")
const Stage1PillarUiRenderer := preload("res://scripts/hud/stage1_pillar_ui_renderer.gd")
const Stage1PillarStatusOrbContextBuilder := preload("res://scripts/hud/stage1_pillar_status_orb_context_builder.gd")
const PillarDashOrbBodyRenderer := preload("res://scripts/hud/pillar_dash_orb_body_renderer.gd")
const PillarDashOrbRenderer := preload("res://scripts/hud/pillar_dash_orb_renderer.gd")
const PillarDashTokenFillRenderer := preload("res://scripts/hud/pillar_dash_token_fill_renderer.gd")
const PillarDashTokenFlashRenderer := preload("res://scripts/hud/pillar_dash_token_flash_renderer.gd")
const PillarGaugeOrbRenderer := preload("res://scripts/hud/pillar_gauge_orb_renderer.gd")
const PillarOrbBackgroundCache := preload("res://scripts/hud/pillar_orb_background_cache.gd")
const PillarStatusOrbRenderer := preload("res://scripts/hud/pillar_status_orb_renderer.gd")
const PillarLiquidDrawer := preload("res://scripts/hud/pillar_liquid_drawer.gd")
const PillarOrbChromeDrawer := preload("res://scripts/hud/pillar_orb_chrome_drawer.gd")
const ScoreboardTopMiniDeuceEmberRenderer := preload("res://scripts/hud/scoreboard_top_mini_deuce_ember_renderer.gd")
const ScoreboardTopMiniDeuceEffectRenderer := preload("res://scripts/hud/scoreboard_top_mini_deuce_effect_renderer.gd")
const ScoreboardTopMiniNormalChromeRenderer := preload("res://scripts/hud/scoreboard_top_mini_normal_chrome_renderer.gd")
const ScoreboardTopMiniNormalDecorationRenderer := preload("res://scripts/hud/scoreboard_top_mini_normal_decoration_renderer.gd")
const SmasherSkillOrbCooldownRenderer := preload("res://scripts/hud/smasher_skill_orb_cooldown_renderer.gd")
const SmasherSkillOrbSocketRenderer := preload("res://scripts/hud/smasher_skill_orb_socket_renderer.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const ViperAirborneLod := preload("res://scripts/core/viper_airborne_lod.gd")

var _failures: Array[String] = []


class FakeBossSkillRenderer:
	extends RefCounted

	var draw_calls := 0
	var last_context: Dictionary = {}

	func draw(_canvas: CanvasItem, context: Dictionary) -> void:
		draw_calls += 1
		last_context = context.duplicate(true)


class FakeCooldownState:
	extends RefCounted

	func get_hud_context() -> Dictionary:
		return {
			"stage1_dalji_boss_skill_hud_active": true,
			"stage1_dalji_boss_skill_hud_skills": [
				{"id": "whip", "progress": 0.25},
				{"id": "spinning_top", "progress": 0.50},
				{"id": "quake_test", "progress": 0.75},
			],
		}


class FakeLingpetRuntime:
	extends RefCounted

	var snapshot_calls := 0

	func is_companion_active(_pet_id: String = "") -> bool:
		return true

	func get_snapshot() -> Dictionary:
		snapshot_calls += 1
		return {
			"companion_skill_id": "maribo_hydro_sphere",
			"companion_skill_name": "Hydro Sphere",
			"companion_skill_description": "Test companion skill",
			"companion_skill_card_path": "res://assets/sprites/lingpet/maribo_hydro_sphere_skillcard_imagegen_v2.png",
			"companion_skill_cooldown": 0.0,
			"companion_skill_cooldown_duration": 40.0,
			"companion_skill_ready": true,
			"companion_skill_flash_ratio": 0.0,
			"companion_skill_winding_up": false,
			"hydro_sphere_projectile_active": false,
			"hydro_sphere_puddle_active": false,
		}


class FakePillarUiRenderer:
	extends RefCounted

	var panel_rect := Rect2(Vector2(356.0, 654.0), Vector2(92.0, 152.0))

	func build_commando_firearm_panel_state(_game_offset: Vector2, _game_size: Vector2, _context: Dictionary) -> Dictionary:
		return {"rect": panel_rect}


class FakeSelectorRenderer:
	extends RefCounted

	var last_center := Vector2.ZERO
	var last_scale := 0.0

	func build_panel_state(center: Vector2, scale_factor: float, _context: Dictionary) -> Dictionary:
		last_center = center
		last_scale = scale_factor
		return {"rect": Rect2(center - Vector2(10.0, 20.0), Vector2(20.0, 40.0))}


class FakeRegistry:
	extends RefCounted

	var entries: Dictionary = {}

	func _init(initial_entries: Dictionary = {}) -> void:
		entries = initial_entries

	func get_cached_instance(key: String) -> Object:
		return entries.get(key, null)

	func get_instance(key: String) -> Object:
		return entries.get(key, null)


func _init() -> void:
	_verify_pillar_renderer_exposes_commando_panel_state()
	_verify_cards_avoid_commando_firearm_panel()
	_verify_post_active_hud_pass_seeds_commando_panel_rect()
	_verify_scene_drawer_passes_commando_panel_rect()
	_verify_stage1_shared_boss_hud_skips_lingpet_snapshot_off_stage()
	_verify_boss_dash_uses_compact_fallback_frame()
	_verify_stage1_pillar_scene_static_hud_lod()
	_verify_viper_hud_lod_context()
	_verify_viper_hud_lod_draw_budgets()
	_verify_gauge_liquid_display_ratio_smoothing()
	_verify_status_orb_cache_prewarm()
	_verify_stage1_status_orb_base_render_budgets()

	if _failures.is_empty():
		print("stage1_dalji_commando_hud_layout_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_pillar_renderer_exposes_commando_panel_state() -> void:
	var renderer := Stage1PillarUiRenderer.new()
	var selector := FakeSelectorRenderer.new()
	var panel_state: Dictionary = renderer.build_commando_firearm_panel_state(
		Vector2(512.0, 64.0),
		Vector2(1024.0, 1024.0),
		{
			"height": 750.0,
			"selected_character_type": "soldier",
			"commando_firearm_selector_renderer": selector,
		}
	)
	var panel_rect: Rect2 = _get_rect(panel_state.get("rect", Rect2()))
	_expect(panel_rect.size.x > 0.0 and panel_rect.size.y > 0.0, "pillar renderer should expose a computed Commando firearm panel rect")
	_expect(is_equal_approx(selector.last_scale, 1024.0 / 750.0), "pillar renderer should reuse the live pillar UI scale for the Commando firearm panel")


func _verify_cards_avoid_commando_firearm_panel() -> void:
	var renderer := Stage1DaljiBossSkillHudRenderer.new()
	var panel_rect := Rect2(Vector2(356.0, 654.0), Vector2(92.0, 152.0))
	var context := {
		"current_stage": 1,
		"stage1_dalji_boss_skill_hud_active": true,
		"view_size": Vector2(2048.0, 1152.0),
		"game_offset": Vector2(512.0, 64.0),
		"game_size": Vector2(1024.0, 1024.0),
		"stage1_dalji_boss_skill_hud_skills": [
			{"id": "whip", "progress": 0.10},
			{"id": "spinning_top", "progress": 0.35},
			{"id": "quake_test", "progress": 0.55},
			{"id": "rush_test", "progress": 0.80},
		],
	}
	var default_layout: Dictionary = renderer.build_card_layout(context)
	var default_stack: Rect2 = _get_rect(default_layout.get("stack_rect", Rect2()))
	_expect(default_stack.end.y > panel_rect.position.y, "default centered Dalji cards should reproduce the Commando overlap risk")

	context["commando_firearm_panel_rect"] = panel_rect
	var shifted_layout: Dictionary = renderer.build_card_layout(context)
	var shifted_stack: Rect2 = _get_rect(shifted_layout.get("stack_rect", Rect2()))
	var scale_factor: float = float(shifted_layout.get("scale_factor", 1.0))
	var required_gap: float = BossSkillCardHudSpec.get_commando_firearm_panel_gap(scale_factor)
	_expect(shifted_stack.end.y <= panel_rect.position.y - required_gap + 0.01, "Commando-safe Dalji cards should sit above the firearm panel")
	_expect(shifted_stack.position.y < default_stack.position.y, "Commando-safe Dalji card stack should move upward instead of shrinking or staying centered")

	context["commando_firearm_panel_rect"] = Rect2(Vector2(12.0, panel_rect.position.y), panel_rect.size)
	var far_layout: Dictionary = renderer.build_card_layout(context)
	var far_stack: Rect2 = _get_rect(far_layout.get("stack_rect", Rect2()))
	_expect(is_equal_approx(far_stack.position.y, default_stack.position.y), "unrelated left-edge panels should not move the Dalji card stack")


func _verify_post_active_hud_pass_seeds_commando_panel_rect() -> void:
	var boss_renderer := FakeBossSkillRenderer.new()
	var pillar_renderer := FakePillarUiRenderer.new()
	var registry := FakeRegistry.new({
		"stage1_dalji_boss_skill_hud_renderer": boss_renderer,
		"stage1_dalji_boss_skill_cooldown_state": FakeCooldownState.new(),
		"stage1_pillar_ui_renderer": pillar_renderer,
		"commando_firearm_selector_renderer": RefCounted.new(),
		"commando_weapon_controller": RefCounted.new(),
	})
	var drawer := Stage1PillarHudSceneDrawer.new()
	var context := {
		"height": 750.0,
		"selected_character_type": "soldier",
	}
	drawer.draw_active_item_hud(
		null,
		context,
		registry,
		Vector2(2048.0, 1152.0),
		Vector2(512.0, 64.0),
		Vector2(1024.0, 1024.0)
	)
	var seeded_rect: Rect2 = _get_rect(context.get("commando_firearm_panel_rect", Rect2()))
	_expect(seeded_rect == pillar_renderer.panel_rect, "post-active HUD pass should seed the Commando firearm panel rect for later boss skill HUD draws")


func _verify_scene_drawer_passes_commando_panel_rect() -> void:
	var boss_renderer := FakeBossSkillRenderer.new()
	var pillar_renderer := FakePillarUiRenderer.new()
	var registry := FakeRegistry.new({
		"stage1_dalji_boss_skill_hud_renderer": boss_renderer,
		"stage1_dalji_boss_skill_cooldown_state": FakeCooldownState.new(),
		"stage1_pillar_ui_renderer": pillar_renderer,
		"commando_firearm_selector_renderer": RefCounted.new(),
		"commando_weapon_controller": RefCounted.new(),
	})
	var drawer := Stage1PillarHudSceneDrawer.new()
	drawer._draw_stage1_dalji_boss_skill_hud(
		null,
		{
			"height": 750.0,
			"selected_character_type": "soldier",
		},
		registry,
		Vector2(2048.0, 1152.0),
		Vector2(512.0, 64.0),
		Vector2(1024.0, 1024.0),
		0.0
	)
	_expect(boss_renderer.draw_calls == 1, "Stage 1 boss skill HUD should still draw through the scene drawer")
	var passed_rect: Rect2 = _get_rect(boss_renderer.last_context.get("commando_firearm_panel_rect", Rect2()))
	_expect(passed_rect == pillar_renderer.panel_rect, "scene drawer should pass the live Commando firearm panel rect into the boss skill HUD")


func _verify_stage1_shared_boss_hud_skips_lingpet_snapshot_off_stage() -> void:
	var boss_renderer := FakeBossSkillRenderer.new()
	var lingpet_runtime := FakeLingpetRuntime.new()
	var registry := FakeRegistry.new({
		"stage1_dalji_boss_skill_hud_renderer": boss_renderer,
		"stage1_dalji_boss_skill_cooldown_state": FakeCooldownState.new(),
		"stage1_pillar_ui_renderer": FakePillarUiRenderer.new(),
		"commando_firearm_selector_renderer": RefCounted.new(),
		"commando_weapon_controller": RefCounted.new(),
		"lingpet_egg_runtime": lingpet_runtime,
	})
	var drawer := Stage1PillarHudSceneDrawer.new()
	var base_context := {
		"height": 750.0,
		"selected_character_type": "soldier",
		"stage1_boss_variant": "dalji",
	}
	var off_stage_context := base_context.duplicate()
	off_stage_context["current_stage"] = 2
	drawer._draw_stage1_boss_skill_hud(
		null,
		off_stage_context,
		registry,
		Vector2(2048.0, 1152.0),
		Vector2(512.0, 64.0),
		Vector2(1024.0, 1024.0),
		0.0
	)
	_expect(lingpet_runtime.snapshot_calls == 0, "Stage 1 shared boss HUD should not build lingpet snapshots off Stage 1")
	_expect(boss_renderer.draw_calls == 0, "Stage 1 shared boss HUD should not draw off Stage 1")

	var stage1_context := base_context.duplicate()
	stage1_context["current_stage"] = 1
	drawer._draw_stage1_boss_skill_hud(
		null,
		stage1_context,
		registry,
		Vector2(2048.0, 1152.0),
		Vector2(512.0, 64.0),
		Vector2(1024.0, 1024.0),
		0.0
	)
	_expect(lingpet_runtime.snapshot_calls == 1, "Stage 1 shared boss HUD should still build one lingpet snapshot on Stage 1")
	_expect(boss_renderer.draw_calls == 1, "Stage 1 shared boss HUD should still draw on Stage 1")


func _verify_boss_dash_uses_compact_fallback_frame() -> void:
	var builder := Stage1PillarStatusOrbContextBuilder.new()
	var boss_context: Dictionary = builder.build_boss_dash_orb_context({}, null)
	_expect(bool(boss_context.get("compact_fallback_frame", false)), "Stage 1 boss dash HUD should use the compact procedural fallback frame")


func _verify_stage1_pillar_scene_static_hud_lod() -> void:
	var original_max_fps: int = int(Engine.get("max_fps"))
	var drawer := Stage1PillarSceneDrawer.new()
	Engine.set("max_fps", 72)
	BattleRenderQuality.reset_cache_for_test()
	ViperAirborneLod.reset_cache_for_test()
	var capped_context: Dictionary = drawer._with_stage1_hud_lod_context(
		{"selected_character_type": "soldier"},
		BattleRenderQuality.effect_scale({"selected_character_type": "soldier"})
	)
	_expect(bool(capped_context.get("stage1_pillar_hud_static_lod", false)), "Stage 1 capped-frame HUD should trim ornamental pillar orb layers")
	_expect(bool(capped_context.get("pillar_hud_static_lod", false)), "Stage 1 capped-frame HUD should use the shared static HUD LOD flag")

	Engine.set("max_fps", 144)
	BattleRenderQuality.reset_cache_for_test()
	ViperAirborneLod.reset_cache_for_test()
	var high_refresh_context: Dictionary = drawer._with_stage1_hud_lod_context(
		{"selected_character_type": "soldier"},
		BattleRenderQuality.effect_scale({"selected_character_type": "soldier"})
	)
	_expect(bool(high_refresh_context.get("pillar_hud_static_lod", false)), "Stage 1 high-refresh HUD should trim ornamental pillar orb layers")

	Engine.set("max_fps", 0)
	BattleRenderQuality.reset_cache_for_test()
	ViperAirborneLod.reset_cache_for_test()
	var uncapped_source := {"selected_character_type": "soldier"}
	var uncapped_context: Dictionary = drawer._with_stage1_hud_lod_context(
		uncapped_source,
		BattleRenderQuality.effect_scale(uncapped_source)
	)
	_expect(uncapped_context == uncapped_source, "Stage 1 normal-quality HUD should keep the original context")
	Engine.set("max_fps", original_max_fps)
	BattleRenderQuality.reset_cache_for_test()
	ViperAirborneLod.reset_cache_for_test()


func _verify_viper_hud_lod_context() -> void:
	var original_max_fps: int = int(Engine.get("max_fps"))
	Engine.set("max_fps", 72)
	BattleRenderQuality.reset_cache_for_test()
	ViperAirborneLod.reset_cache_for_test()
	var renderer := Stage1PillarUiRenderer.new()
	var builder := Stage1PillarStatusOrbContextBuilder.new()
	var viper_context := {
		"selected_character_type": "viper",
		"dash_snapshot": {"tokens": 1, "max_tokens": 2},
	}
	var expected_lod_scale := BattleRenderQuality.FPS_CAP_EFFECT_SCALE
	var status_context: Dictionary = renderer._build_status_context(viper_context)
	var dash_context: Dictionary = builder.build_dash_orb_context(status_context, null)
	var gauge_context: Dictionary = builder.build_gauge_orb_context(status_context, null)
	var boss_context: Dictionary = builder.build_boss_dash_orb_context(status_context, null)
	_expect(
		abs(float(dash_context.get("hud_lod_scale", 1.0)) - expected_lod_scale) < 0.001,
		"Viper pillar dash HUD should carry the capped-frame LOD scale when max_fps is capped"
	)
	_expect(
		abs(float(gauge_context.get("hud_lod_scale", 1.0)) - expected_lod_scale) < 0.001,
		"Viper gauge HUD should carry the capped-frame LOD scale when max_fps is capped"
	)
	_expect(
		abs(float(boss_context.get("hud_lod_scale", 1.0)) - expected_lod_scale) < 0.001,
		"Viper boss dash HUD should carry the capped-frame LOD scale when max_fps is capped"
	)
	_expect(
		is_equal_approx(renderer._get_hud_lod_scale({"selected_character_type": "soldier"}), expected_lod_scale),
		"non-Viper pillar HUD should use the shared capped-frame render quality"
	)
	Engine.set("max_fps", 144)
	BattleRenderQuality.reset_cache_for_test()
	ViperAirborneLod.reset_cache_for_test()
	_expect(
		is_equal_approx(renderer._get_hud_lod_scale({"selected_character_type": "soldier"}), BattleRenderQuality.HIGH_REFRESH_EFFECT_SCALE),
		"non-Viper pillar HUD should keep high-refresh render quality when runtime max_fps targets 144"
	)
	Engine.set("max_fps", original_max_fps)
	BattleRenderQuality.reset_cache_for_test()
	ViperAirborneLod.reset_cache_for_test()


func _verify_viper_hud_lod_draw_budgets() -> void:
	_expect(PillarDashTokenFlashRenderer.FLASH_LAYER_COUNT <= 2, "dash flash should keep a tight layer count")
	_expect(PillarDashTokenFlashRenderer.FLASH_LAYER_COUNT_LOD <= 1, "dash flash should use one layer under HUD LOD")
	_expect(PillarDashTokenFlashRenderer.FLASH_ARC_POINTS <= 24, "dash flash should keep a bounded arc budget")
	_expect(PillarDashTokenFlashRenderer.FLASH_ARC_POINTS_LOD <= 12, "dash flash should keep a tight LOD arc budget")
	_expect(PillarDashTokenFlashRenderer.FLASH_BURST_COUNT <= 6, "dash flash should keep a bounded burst budget")
	_expect(PillarDashTokenFlashRenderer.FLASH_BURST_COUNT_LOD <= 2, "dash flash should keep a tight LOD burst budget")
	_expect(PillarDashTokenFlashRenderer.FLASH_BURST_COUNT_LOD < PillarDashTokenFlashRenderer.FLASH_BURST_COUNT, "dash flash should reduce burst count under HUD LOD")
	_expect(PillarDashOrbRenderer.RECOVERY_CHAIN_ARC_POINTS_LOD < PillarDashOrbRenderer.RECOVERY_CHAIN_ARC_POINTS, "dash recovery chains should reduce arc points under HUD LOD")
	_expect(PillarDashOrbRenderer.RECOVERY_PULL_RING_POINTS_LOD <= 14, "dash recovery pull ring should keep a tight LOD arc budget")
	_expect(PillarDashOrbRenderer.RECOVERY_CHAIN_ARC_COUNT_LOD <= 1, "dash recovery chains should keep a tight LOD chain count")
	_expect(ScoreboardTopMiniNormalChromeRenderer.GLOW_LAYER_COUNT <= 2, "top mini normal scoreboard should keep a bounded glow-layer budget")
	_expect(ScoreboardTopMiniNormalChromeRenderer.BAND_COUNT <= 3, "top mini normal scoreboard should keep a bounded band budget")
	_expect(ScoreboardTopMiniNormalChromeRenderer.BAND_COUNT_LOD <= 1, "top mini normal scoreboard should keep a tight LOD band budget")
	_expect(ScoreboardTopMiniNormalChromeRenderer.BAND_COUNT_LOD < ScoreboardTopMiniNormalChromeRenderer.BAND_COUNT, "top mini normal scoreboard should reduce band count under HUD LOD")
	_expect(ScoreboardTopMiniNormalDecorationRenderer.SCORE_PIP_COUNT <= 3, "top mini normal scoreboard pips should keep a bounded draw budget")
	_expect(ScoreboardTopMiniNormalDecorationRenderer.SCORE_PIP_COUNT_LOD <= 2, "top mini normal scoreboard LOD pips should stay tighter")
	_expect(ScoreboardTopMiniNormalDecorationRenderer.SPARKLE_SWEEP_WIDTH_SCALE <= 12.0, "top mini normal scoreboard sparkle sweep should keep a bounded draw width")
	_expect(ScoreboardTopMiniNormalDecorationRenderer.SPARKLE_SWEEP_WIDTH_SCALE_LOD <= 6.0, "top mini normal scoreboard LOD sparkle sweep should keep a tight draw width")
	_expect(ScoreboardTopMiniDeuceEffectRenderer.GLOW_LAYER_COUNT <= 2, "top mini deuce scoreboard should keep a bounded glow-layer budget")
	_expect(ScoreboardTopMiniDeuceEffectRenderer.GLOW_LAYER_COUNT_LOD <= 1, "top mini deuce scoreboard should keep a tight LOD glow-layer budget")
	_expect(ScoreboardTopMiniDeuceEffectRenderer.FIRE_GRADIENT_BANDS <= 4, "top mini deuce scoreboard should keep a bounded fire-gradient budget")
	_expect(ScoreboardTopMiniDeuceEffectRenderer.FIRE_GRADIENT_BANDS_LOD <= 2, "top mini deuce scoreboard should keep a tight LOD fire-gradient budget")
	_expect(ScoreboardTopMiniDeuceEffectRenderer.FLAME_LAYER_COUNT <= 2, "top mini deuce scoreboard should keep a bounded flame-layer budget")
	_expect(ScoreboardTopMiniDeuceEffectRenderer.FLAME_LAYER_COUNT_LOD <= 1, "top mini deuce scoreboard should keep a tight LOD flame-layer budget")
	_expect(ScoreboardTopMiniDeuceEffectRenderer.FLAME_STEP >= 6, "top mini deuce flames should keep a coarse default step")
	_expect(ScoreboardTopMiniDeuceEffectRenderer.FLAME_STEP_LOD >= 10, "top mini deuce flames should keep a coarse LOD step")
	_expect(ScoreboardTopMiniDeuceEffectRenderer.FLAME_STEP_LOD > ScoreboardTopMiniDeuceEffectRenderer.FLAME_STEP, "top mini deuce flames should use a coarser step under HUD LOD")
	_expect(ScoreboardTopMiniDeuceEmberRenderer.EMBER_COUNT <= 4, "top mini deuce ember particles should keep a bounded draw budget")

	var dash_source := FileAccess.get_file_as_string("res://scripts/hud/pillar_dash_orb_renderer.gd")
	var gauge_source := FileAccess.get_file_as_string("res://scripts/hud/pillar_gauge_orb_renderer.gd")
	var gauge_fill_source := FileAccess.get_file_as_string("res://scripts/hud/pillar_gauge_orb_fill_renderer.gd")
	var dash_body_source := FileAccess.get_file_as_string("res://scripts/hud/pillar_dash_orb_body_renderer.gd")
	var dash_fill_source := FileAccess.get_file_as_string("res://scripts/hud/pillar_dash_token_fill_renderer.gd")
	var skill_slot_source := FileAccess.get_file_as_string("res://scripts/hud/smasher_skill_orb_slot_renderer.gd")
	var flash_source := FileAccess.get_file_as_string("res://scripts/hud/pillar_dash_token_flash_renderer.gd")
	var pillar_ui_source := FileAccess.get_file_as_string("res://scripts/hud/stage1_pillar_ui_renderer.gd")
	var status_context_source := FileAccess.get_file_as_string("res://scripts/hud/stage1_pillar_status_orb_context_builder.gd")
	var top_mini_drawer_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_top_mini_scoreboard_scene_drawer.gd")
	var top_mini_renderer_source := FileAccess.get_file_as_string("res://scripts/hud/scoreboard_top_mini_renderer.gd")
	_expect(dash_source.find("token_renderer.draw_flash(canvas, center, radius, flash_timer / flash_duration, scale_factor, context)") >= 0, "dash flash draw should receive the HUD LOD context")
	_expect(flash_source.find("quality_scale < 0.85") >= 0, "dash flash renderer should branch on HUD LOD quality")
	_expect(pillar_ui_source.find("SENSOR_FRAME_ARC_SEGMENTS_LOD if lod_active else SENSOR_FRAME_ARC_SEGMENTS") >= 0, "sensor cooldown HUD should branch on HUD LOD quality")
	_expect(
		status_context_source.find("pillar_hud_static_lod") >= 0
			and gauge_source.find("static_hud_lod") >= 0
			and gauge_fill_source.find("draw_pillar_liquid_fill") >= 0
			and gauge_fill_source.find("_draw_static_fill") < 0
			and dash_source.find("static_hud_lod") >= 0
			and dash_body_source.find("static_hud_lod") >= 0
			and dash_body_source.find("_draw_static_compact_fallback_frame") >= 0
			and dash_fill_source.find("pillar_hud_static_lod") >= 0
			and skill_slot_source.find("static_hud_lod") >= 0,
		"pillar HUD static LOD should keep gauge liquid animated while removing expensive ornamental layers"
	)
	_expect(top_mini_drawer_source.find("BattleRenderQuality.effect_scale(context)") >= 0, "top mini scoreboard should reuse the shared render-quality helper")
	_expect(top_mini_renderer_source.find("quality_scale") >= 0, "top mini scoreboard renderer should forward quality scale to variants")


func _verify_gauge_liquid_display_ratio_smoothing() -> void:
	var renderer := PillarGaugeOrbRenderer.new()
	var initial_ratio: float = renderer._update_display_ratio(0.20, 0.0)
	var rising_ratio: float = renderer._update_display_ratio(0.80, 1.0 / 72.0)
	var later_rising_ratio: float = renderer._update_display_ratio(0.80, 7.0 / 72.0)
	var falling_ratio: float = renderer._update_display_ratio(0.10, 8.0 / 72.0)
	_expect(is_equal_approx(initial_ratio, 0.20), "gauge liquid display ratio should snap to the first live value")
	_expect(rising_ratio > initial_ratio and rising_ratio < 0.80, "gauge liquid display ratio should rise smoothly instead of jumping")
	_expect(later_rising_ratio > rising_ratio and later_rising_ratio < 0.80, "gauge liquid display ratio should continue following the target")
	_expect(falling_ratio < later_rising_ratio and falling_ratio > 0.10, "gauge liquid display ratio should fall quickly but smoothly")


func _verify_status_orb_cache_prewarm() -> void:
	var renderer := PillarStatusOrbRenderer.new()
	_expect(renderer.has_method("prewarm_caches"), "pillar status orb renderer should expose live-cache prewarm for HUD stage warmup")
	renderer.prewarm_caches([55.0])
	_expect(PillarStatusOrbRenderer.DEFAULT_PREWARM_RADII.has(80.0), "status-orb prewarm should include 1080p scaled dash radius")
	_expect(PillarStatusOrbRenderer.DEFAULT_PREWARM_RADII.size() >= 6, "status-orb prewarm should cover common scaled pillar radii")
	var background_cache := PillarOrbBackgroundCache.new()
	_expect(
		background_cache._texture_size_for_radius(79.2) == background_cache._texture_size_for_radius(80.0),
		"radial background cache should bucket near-equal scaled radii"
	)
	var scene_drawer_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")
	_expect(scene_drawer_source.find("status_orb_renderer.prewarm_caches()") >= 0, "Stage 1 pillar HUD prewarm should warm live status-orb caches")


func _verify_stage1_status_orb_base_render_budgets() -> void:
	_expect(PillarLiquidDrawer.LIQUID_SURFACE_STEP <= 1.5, "Stage 1 status-orb liquid fill should keep high-quality surface sampling")
	_expect(PillarLiquidDrawer.LIQUID_SURFACE_STEP_LOD >= 4.0, "Stage 1 status-orb liquid fill should still widen surface sampling under HUD LOD")
	_expect(PillarLiquidDrawer.LIQUID_POLYGON_MAX_POINTS <= 260, "Stage 1 status-orb liquid fill should keep a bounded polygon vertex budget")
	# Cadence is a wall-clock rate, not a vertex budget: it adds no samples or
	# draw calls. Bounded here only so the surface cannot become a strobe; the
	# value tracks the PingFighter reference ripple this orb was ported from.
	_expect(PillarLiquidDrawer.LIQUID_ANIMATION_SPEED <= 1.1, "Stage 1 status-orb liquid fill should keep a readable, non-strobing surface cadence")
	_expect(PillarLiquidDrawer.LIQUID_EDGE_SEARCH_STEPS <= 8, "Stage 1 status-orb liquid fill should keep bounded circular-edge search work")
	_expect(PillarLiquidDrawer.LIQUID_SURFACE_GLOW_MIN_HEIGHT >= 2.0, "Stage 1 status-orb liquid surface glow should avoid drawing edge-closing seams")
	_expect(PillarLiquidDrawer.LIQUID_BAND_STEP_LOD >= 12.0, "Stage 1 status-orb liquid fill bands should keep a coarse LOD step")
	_expect(PillarLiquidDrawer.LIQUID_MAX_BUBBLES <= 2, "Stage 1 status-orb liquid fill should cap decorative bubbles")
	_expect(PillarLiquidDrawer.DASH_SECTOR_SEGMENTS <= 14, "Stage 1 dash sector liquid should keep a bounded polygon budget")
	_expect(PillarLiquidDrawer.DASH_INNER_SECTOR_SEGMENTS <= 9, "Stage 1 dash sector liquid should keep a bounded inner polygon budget")
	_expect(PillarLiquidDrawer.DASH_PULSE_ARC_POINTS <= 9, "Stage 1 dash sector liquid pulse should keep a bounded arc budget")
	_expect(PillarGaugeOrbRenderer.OUTER_GLOW_LAYERS <= 1, "Stage 1 gauge orb should keep a tight glow-layer budget")
	_expect(PillarGaugeOrbRenderer.AMBIENT_PARTICLE_COUNT <= 1, "Stage 1 gauge orb should cap ambient particles tightly")
	_expect(PillarGaugeOrbRenderer.FLASH_LAYER_COUNT <= 2, "Stage 1 gauge orb flash should keep a tight layer budget")
	_expect(PillarGaugeOrbRenderer.FLASH_LAYER_COUNT_LOD <= 1, "Stage 1 gauge orb flash should keep one LOD layer")
	_expect(PillarGaugeOrbRenderer.FLASH_RING_SEGMENTS <= 10, "Stage 1 gauge orb flash ring should keep a tight segment budget")
	_expect(PillarGaugeOrbRenderer.FLASH_RING_SEGMENTS_LOD <= 8, "Stage 1 gauge orb flash ring should keep a tight LOD segment budget")
	_expect(PillarGaugeOrbRenderer.IDLE_RING_SEGMENTS <= 10, "Stage 1 gauge orb idle ring should keep a tight segment budget")
	_expect(PillarGaugeOrbRenderer.IDLE_RING_SEGMENTS_LOD <= 8, "Stage 1 gauge orb idle ring should keep a tight LOD segment budget")
	_expect(PillarOrbChromeDrawer.GLASS_HIGHLIGHT_SEGMENTS <= 12, "Stage 1 orb glass highlight should keep a bounded polygon budget")
	_expect(PillarOrbChromeDrawer.GLASS_SMALL_HIGHLIGHT_SEGMENTS <= 10, "Stage 1 orb small glass highlight should keep a bounded polygon budget")
	_expect(PillarOrbChromeDrawer.GLASS_RIM_SEGMENTS <= 10, "Stage 1 orb glass rim should keep a bounded arc budget")
	_expect(PillarOrbChromeDrawer.FRAME_OUTER_RING_SEGMENTS <= 32, "Stage 1 orb chrome outer ring should keep a bounded arc budget")
	_expect(PillarOrbChromeDrawer.FRAME_MID_RING_SEGMENTS <= 32, "Stage 1 orb chrome mid ring should keep a bounded arc budget")
	_expect(PillarOrbChromeDrawer.FRAME_HIGHLIGHT_ARC_SEGMENTS <= 14, "Stage 1 orb chrome highlight arcs should keep a bounded arc budget")
	_expect(PillarOrbChromeDrawer.FRAME_INNER_RING_SEGMENTS <= 28, "Stage 1 orb chrome inner ring should keep a bounded arc budget")
	_expect(PillarDashOrbBodyRenderer.OUTER_GLOW_LAYERS <= 2, "Stage 1 dash orb should keep a bounded glow-layer budget")
	_expect(PillarDashOrbBodyRenderer.OUTER_GLOW_LAYERS_LOD <= 1, "Stage 1 dash orb should keep a tight LOD glow-layer budget")
	_expect(PillarDashOrbBodyRenderer.AMBIENT_PARTICLE_COUNT <= 2, "Stage 1 dash orb should cap ambient particles")
	_expect(PillarDashOrbBodyRenderer.AMBIENT_PARTICLE_COUNT_LOD <= 1, "Stage 1 dash orb should keep a tight LOD ambient particle budget")
	_expect(PillarDashOrbBodyRenderer.COMPACT_FRAME_OUTER_SEGMENTS <= 24, "Stage 1 compact dash orb frame should keep a bounded outer arc budget")
	_expect(PillarDashOrbBodyRenderer.COMPACT_FRAME_INNER_SEGMENTS <= 20, "Stage 1 compact dash orb frame should keep a bounded inner arc budget")
	_expect(PillarDashOrbBodyRenderer.COMPACT_FRAME_OUTER_SEGMENTS_STATIC_LOD <= 10, "Stage 1 static compact dash orb frame should keep a tight outer arc budget")
	_expect(PillarDashOrbBodyRenderer.COMPACT_FRAME_HIGHLIGHT_SEGMENTS_STATIC_LOD <= 5, "Stage 1 static compact dash orb frame should keep a tight highlight arc budget")
	_expect(PillarDashOrbBodyRenderer.COMPACT_FRAME_INNER_SEGMENTS_STATIC_LOD <= 8, "Stage 1 static compact dash orb frame should keep a tight inner arc budget")
	_expect(PillarDashOrbRenderer.IDLE_RING_SEGMENTS <= 14, "Stage 1 dash orb idle ring should keep a tight segment budget")
	_expect(PillarDashOrbRenderer.BOOST_RING_ARC_COUNT <= 3, "Stage 1 dash boost ring should keep a bounded arc count")
	_expect(PillarDashOrbRenderer.BOOST_RING_ARC_COUNT_LOD <= 2, "Stage 1 dash boost ring should keep a tight LOD arc count")
	_expect(PillarDashOrbRenderer.BOOST_RING_ARC_POINTS <= 6, "Stage 1 dash boost ring should keep a bounded arc point budget")
	_expect(PillarDashOrbRenderer.BOOST_RING_ARC_POINTS_LOD <= 4, "Stage 1 dash boost ring should keep a tight LOD arc point budget")
	_expect(PillarDashOrbRenderer.RECOVERY_SPARK_COUNT <= 4, "Stage 1 dash recovery should keep a bounded spark count")
	_expect(PillarDashOrbRenderer.RECOVERY_INNER_LAYER_COUNT <= 3, "Stage 1 dash recovery should keep a bounded inner layer budget")
	_expect(PillarDashOrbRenderer.RECOVERY_INNER_LAYER_COUNT_LOD <= 1, "Stage 1 dash recovery should keep a tight LOD inner layer budget")
	_expect(PillarDashOrbRenderer.RECOVERY_PULL_RING_POINTS <= 24, "Stage 1 dash recovery pull ring should keep a bounded arc budget")
	_expect(PillarDashOrbRenderer.RECOVERY_CHAIN_ARC_POINTS <= 9, "Stage 1 dash recovery chains should keep a bounded arc budget")
	_expect(PillarDashOrbRenderer.RECOVERY_SEAL_OUTER_POINTS <= 20, "Stage 1 dash recovery seal should keep a bounded outer arc budget")
	_expect(PillarDashOrbRenderer.RECOVERY_SEAL_OUTER_POINTS_LOD <= 12, "Stage 1 dash recovery seal should keep a tight LOD outer arc budget")
	_expect(PillarDashOrbRenderer.RECOVERY_SEAL_INNER_POINTS <= 14, "Stage 1 dash recovery seal should keep a bounded inner arc budget")
	_expect(PillarDashOrbRenderer.RECOVERY_SEAL_INNER_POINTS_LOD <= 10, "Stage 1 dash recovery seal should keep a tight LOD inner arc budget")
	_expect(SmasherSkillOrbSocketRenderer.READY_GLOW_FILL_LAYER_COUNT <= 3, "skill-orb ready glow should keep a bounded fill-layer budget")
	_expect(SmasherSkillOrbSocketRenderer.READY_GLOW_LIGHT_POINT_COUNT <= 3, "skill-orb ready glow should keep a bounded light-point budget")
	_expect(SmasherSkillOrbSocketRenderer.ACTIVATION_FLASH_LAYER_COUNT <= 1, "skill-orb activation flash should keep a bounded layer budget")
	_expect(SmasherSkillOrbCooldownRenderer.COOLDOWN_SECTOR_SEGMENTS <= 14, "skill-orb cooldown sectors should keep a bounded polygon budget")
	_expect(SmasherSkillOrbCooldownRenderer.COOLDOWN_RING_SEGMENTS <= 14, "skill-orb cooldown rings should keep a bounded arc budget")
	_expect(SmasherSkillOrbCooldownRenderer.COOLDOWN_RING_SEGMENTS_STATIC_LOD >= 14, "skill-orb static cooldown rings should not collapse into octagonal silhouettes")
	_expect(Stage1PillarUiRenderer.SENSOR_FRAME_ARC_SEGMENTS <= 16, "Stage 1 sensor cooldown HUD should keep a bounded frame arc budget")
	_expect(Stage1PillarUiRenderer.SENSOR_FRAME_ARC_SEGMENTS_LOD <= 12, "Stage 1 sensor cooldown HUD should keep a tight LOD frame arc budget")
	_expect(Stage1PillarUiRenderer.SENSOR_PROGRESS_ARC_SEGMENTS <= 16, "Stage 1 sensor cooldown HUD should keep a bounded progress arc budget")
	_expect(Stage1PillarUiRenderer.SENSOR_PROGRESS_ARC_SEGMENTS_LOD <= 12, "Stage 1 sensor cooldown HUD should keep a tight LOD progress arc budget")
	_expect(Stage1PillarUiRenderer.SENSOR_READY_WAVE_COUNT <= 1, "Stage 1 sensor cooldown HUD should keep a tight ready-wave count")
	_expect(Stage1PillarUiRenderer.SENSOR_READY_WAVE_SEGMENTS <= 12, "Stage 1 sensor cooldown HUD should keep a bounded ready-wave arc budget")
	_expect(Stage1PillarUiRenderer.SENSOR_READY_WAVE_SEGMENTS_LOD <= 8, "Stage 1 sensor cooldown HUD should keep a tight LOD ready-wave arc budget")
	_expect(PillarDashTokenFillRenderer.BOOST_SINGLE_RING_LAYERS <= 1, "Stage 1 boost-charging dash token should keep a bounded ring layer budget")
	_expect(PillarDashTokenFillRenderer.BOOST_SINGLE_RING_SEGMENTS <= 24, "Stage 1 boost-charging dash token should keep a bounded ring segment budget")
	_expect(PillarDashTokenFillRenderer.BOOST_SINGLE_RING_SEGMENTS_LOD <= 16, "Stage 1 boost-charging dash token should keep a tight LOD ring segment budget")
	_expect(PillarDashTokenFillRenderer.BOOST_SECTOR_BACKGROUND_SEGMENTS <= 14, "Stage 1 boost-charging dash sector should keep a bounded background polygon budget")
	_expect(PillarDashTokenFillRenderer.BOOST_SECTOR_CHARGE_LAYERS <= 2, "Stage 1 boost-charging dash sector should keep a bounded fill-layer budget")
	_expect(PillarDashTokenFillRenderer.BOOST_SECTOR_CHARGE_SEGMENTS <= 10, "Stage 1 boost-charging dash sector should keep a bounded polygon budget")
	_expect(PillarDashTokenFillRenderer.BOOST_SECTOR_CORE_SEGMENTS <= 8, "Stage 1 boost-charging dash sector should keep a bounded core polygon budget")
	_expect(PillarDashTokenFillRenderer.BOOST_SECTOR_PULSE_SEGMENTS <= 9, "Stage 1 boost-charging dash sector should keep a bounded pulse arc budget")
	_expect(PillarDashTokenFillRenderer.BOOST_SECTOR_RAINBOW_SEGMENTS <= 9, "Stage 1 boost-charging dash sector should keep a bounded rainbow arc budget")
	var fill_renderer := PillarDashTokenFillRenderer.new()
	_expect(
		fill_renderer._should_draw_compact_full_single_token({"tokens": 1, "max_tokens": 1}, 1.0, false),
		"stable full single-token dash HUD should use the compact draw path"
	)
	_expect(
		not fill_renderer._should_draw_compact_full_single_token({"dash_active": true}, 1.0, false),
		"active dash HUD should keep the expressive full-token draw path"
	)


func _get_rect(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
