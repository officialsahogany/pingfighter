extends SceneTree

const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const Stage2RenderBudgetHelper := preload("res://scripts/stages/stage2/stage2_render_budget_helper.gd")
const Stage2VisibilityState := preload("res://scripts/stages/stage2/stage2_visibility_state.gd")
const Stage2AmbientVisualRenderer := preload("res://scripts/stages/stage2/stage2_ambient_visual_renderer.gd")
const Stage2PillarObstacleVisualRenderer := preload("res://scripts/stages/stage2/stage2_pillar_obstacle_visual_renderer.gd")
const BattlePlayfieldSceneDrawer := preload("res://scripts/core/battle_playfield_scene_drawer.gd")
const Stage2PillarSceneDrawer := preload("res://scripts/stages/stage2/stage2_pillar_scene_drawer.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const ViperAirborneLod := preload("res://scripts/core/viper_airborne_lod.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_render_budgets()
	_verify_recent_start_helpers()
	_verify_modal_overlay_lod_helpers()
	_verify_playfield_visibility_helpers()
	_verify_draw_paths_use_render_caps()

	if _failures.is_empty():
		print("stage2_pillar_render_budget_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_render_budgets() -> void:
	_expect(Stage2PillarBackground.AMBIENT_FALLING_LEAF_RENDER_LIMIT <= Stage2PillarBackground.AMBIENT_MAX_FALLING_LEAVES, "Stage 2 pillar falling leaves should keep a bounded ambient render budget")
	_expect(Stage2PillarBackground.AMBIENT_FALLING_LEAF_RENDER_LIMIT_SEVERE_LOD <= 0, "Stage 2 severe LOD should disable pillar falling leaves")
	_expect(Stage2PillarBackground.LEAF_PARTICLE_RENDER_LIMIT <= 16, "Stage 2 leaf particles should cap decorative rendering")
	_expect(Stage2PillarBackground.LEAF_PARTICLE_RENDER_LIMIT_SEVERE_LOD <= 8, "Stage 2 leaf particles should tighten under severe LOD")
	_expect(Stage2PillarBackground.ROCK_FRAGMENT_RENDER_LIMIT <= 16, "Stage 2 rock fragments should keep a tighter texture-heavy render cap")
	_expect(Stage2PillarBackground.ROCK_FRAGMENT_RENDER_LIMIT_SEVERE_LOD <= 12, "Stage 2 rock fragments should tighten under severe LOD")
	_expect(Stage2PillarBackground.WATER_SPLASH_RENDER_LIMIT <= 8, "Stage 2 water splashes should keep a tighter decorative render cap")
	_expect(Stage2PillarBackground.WATER_SPLASH_RENDER_LIMIT_SEVERE_LOD <= 6, "Stage 2 water splashes should tighten under severe LOD")
	_expect(Stage2PillarBackground.STARPOINT_PARTICLE_RENDER_LIMIT <= 12, "Stage 2 starpoint particles should cap decorative rendering")
	_expect(Stage2PillarBackground.STARPOINT_PARTICLE_RENDER_LIMIT_SEVERE_LOD <= 6, "Stage 2 starpoint particles should tighten under severe LOD")
	_expect(Stage2PillarBackground.WATER_TRAIL_MAX_COUNT <= 32, "Stage 2 water cannon trails should keep a capped history")
	_expect(Stage2PillarBackground.WATER_CANNON_MAX_SPLASHES <= 64, "Stage 2 water cannon splashes should keep a capped history")
	_expect(Stage2PillarBackground.QUAKE_WAVE_SEGMENTS <= 8, "Stage 2 quake waves should keep segment count capped")
	_expect(Stage2PillarBackground.VISUAL_ONLY_QUAKE_WAVE_SEGMENTS <= 5, "Stage 2 visual quake waves should keep segment count capped")
	_expect(
		float(Stage2PillarSceneDrawer.STAGE2_STATIC_HUD_LOD_SCALE) >= ViperAirborneLod.GLIDE_EFFECT_SCALE,
		"Stage 2 pillar HUD static LOD should cover Viper glide / 72 FPS-cap render windows"
	)

	var background := Stage2PillarBackground.new()
	var status: Dictionary = background.get_render_budget_status()
	_expect(int(status.get("ambient_falling_leaf_render_limit", 0)) == Stage2PillarBackground.AMBIENT_FALLING_LEAF_RENDER_LIMIT, "render budget status should expose the ambient leaf cap")
	_expect(int(status.get("ambient_falling_leaf_render_limit_severe_lod", 0)) == Stage2PillarBackground.AMBIENT_FALLING_LEAF_RENDER_LIMIT_SEVERE_LOD, "render budget status should expose the severe ambient leaf cap")
	_expect(int(status.get("leaf_particle_render_limit", 0)) == Stage2PillarBackground.LEAF_PARTICLE_RENDER_LIMIT, "render budget status should expose the leaf cap")
	_expect(int(status.get("leaf_particle_render_limit_severe_lod", 0)) == Stage2PillarBackground.LEAF_PARTICLE_RENDER_LIMIT_SEVERE_LOD, "render budget status should expose the severe leaf cap")
	_expect(int(status.get("rock_fragment_render_limit", 0)) == Stage2PillarBackground.ROCK_FRAGMENT_RENDER_LIMIT, "render budget status should expose the rock-fragment cap")
	_expect(int(status.get("rock_fragment_render_limit_severe_lod", 0)) == Stage2PillarBackground.ROCK_FRAGMENT_RENDER_LIMIT_SEVERE_LOD, "render budget status should expose the severe rock-fragment cap")
	_expect(int(status.get("water_splash_render_limit", 0)) == Stage2PillarBackground.WATER_SPLASH_RENDER_LIMIT, "render budget status should expose the water-splash cap")
	_expect(int(status.get("water_splash_render_limit_severe_lod", 0)) == Stage2PillarBackground.WATER_SPLASH_RENDER_LIMIT_SEVERE_LOD, "render budget status should expose the severe water-splash cap")
	_expect(int(status.get("starpoint_particle_render_limit", 0)) == Stage2PillarBackground.STARPOINT_PARTICLE_RENDER_LIMIT, "render budget status should expose the starpoint cap")
	_expect(int(status.get("starpoint_particle_render_limit_severe_lod", 0)) == Stage2PillarBackground.STARPOINT_PARTICLE_RENDER_LIMIT_SEVERE_LOD, "render budget status should expose the severe starpoint cap")

	var pillar_drawer := Stage2PillarSceneDrawer.new()
	var previous_max_fps: int = int(Engine.get("max_fps"))
	Engine.set("max_fps", 60)
	var capped_quality_scale := BattleRenderQuality.effect_scale({"selected_character_type": "smasher"})
	_expect(
		is_equal_approx(capped_quality_scale, BattleRenderQuality.FPS_CAP_EFFECT_SCALE),
		"Stage 2 pillar quality should follow the global 72 FPS-cap render LOD"
	)
	var capped_hud_context: Dictionary = pillar_drawer._with_stage2_hud_lod_context({"selected_character_type": "smasher"}, capped_quality_scale)
	_expect(
		bool(capped_hud_context.get("pillar_hud_static_lod", false)),
		"Stage 2 FPS-cap HUD should trim ornamental pillar orb layers even without Viper airborne flags"
	)
	var air_strike_hud_context: Dictionary = pillar_drawer._with_stage2_hud_lod_context(
		{
			"selected_character_type": "viper",
			"viper_jetpack_airborne": true,
			"viper_jetpack_active": true,
			"viper_air_strike_flash_timer": 3.0,
		},
		ViperAirborneLod.LOD_EFFECT_SCALE
	)
	_expect(
		bool(air_strike_hud_context.get("pillar_hud_static_lod", false)),
		"Stage 2 Viper Air Strike should trim ornamental pillar HUD layers while keeping readable HUD content"
	)
	Engine.set("max_fps", 144)
	var high_refresh_hud_context: Dictionary = pillar_drawer._with_stage2_hud_lod_context(
		{
			"selected_character_type": "viper",
		},
		BattleRenderQuality.HIGH_REFRESH_EFFECT_SCALE
	)
	_expect(
		bool(high_refresh_hud_context.get("pillar_hud_static_lod", false)),
		"144 Hz Stage 2 should trim ornamental pillar HUD layers without hiding readable HUD content"
	)
	Engine.set("max_fps", previous_max_fps)


func _verify_recent_start_helpers() -> void:
	var values: Array = []
	for index in range(120):
		values.append(index)
	_expect(Stage2RenderBudgetHelper.recent_start(values, 72) == 48, "Stage 2 render-budget helper should draw only the newest capped entries")
	_expect(Stage2RenderBudgetHelper.get_lod_count(10, 7, 3, 0.58, Stage2PillarBackground.LOD_ACTIVE_THRESHOLD, Stage2PillarBackground.SEVERE_LOD_ACTIVE_THRESHOLD) == 3, "Stage 2 render-budget helper should use severe LOD counts")
	var trimmed: Array = values.duplicate()
	Stage2RenderBudgetHelper.trim_array_from_front(trimmed, 4)
	_expect(trimmed == [116, 117, 118, 119], "Stage 2 render-budget helper should trim arrays from the front")
	var helper_status: Dictionary = Stage2RenderBudgetHelper.build_status(5, 0, 16, 8, 16, 12, 8, 6, 12, 6)
	_expect(int(helper_status.get("water_splash_render_limit_severe_lod", 0)) == 6, "Stage 2 render-budget helper should build status payloads")

	var ambient_renderer := Stage2AmbientVisualRenderer.new()
	_expect(ambient_renderer._recent_start(values, -1) == 0, "ambient renderer default render budget should draw all entries")
	_expect(ambient_renderer._recent_start(values, 72) == 48, "ambient renderer should cap leaf particles")
	_expect(ambient_renderer._recent_start(values, 0) == values.size(), "ambient renderer zero render budget should draw nothing")

	var obstacle_renderer := Stage2PillarObstacleVisualRenderer.new()
	_expect(obstacle_renderer._recent_start(values, -1) == 0, "obstacle renderer default render budget should draw all entries")
	_expect(obstacle_renderer._recent_start(values, 48) == 72, "obstacle renderer should cap starpoint particles")
	_expect(obstacle_renderer._recent_start(values, 0) == values.size(), "obstacle renderer zero render budget should draw nothing")


func _verify_modal_overlay_lod_helpers() -> void:
	var registry := FakeRegistry.new()
	registry.cached["battle_scene_modal_gate_controller"] = FakeModalGate.new()
	registry.cached["pause_menu_overlay"] = FakePauseMenuOverlay.new()
	var playfield_drawer := BattlePlayfieldSceneDrawer.new()
	var pillar_drawer := Stage2PillarSceneDrawer.new()
	_expect(
		playfield_drawer._uses_blocking_overlay_lod(registry, {"current_stage": 2}),
		"Stage 2 playfield drawer should enter modal-overlay LOD while pause/menu overlays are active"
	)
	_expect(
		not playfield_drawer._uses_blocking_overlay_lod(registry, {"current_stage": 1}),
		"Stage 2 playfield drawer modal-overlay LOD should stay Stage 2 scoped"
	)
	_expect(
		pillar_drawer._is_blocking_overlay_lod_active(registry),
		"Stage 2 pillar drawer should share the modal-overlay LOD gate"
	)
	_expect(
		not registry.lazy_keys.has("pause_menu_overlay"),
		"modal-overlay LOD should read overlay state from cached modules instead of lazy-creating overlays"
	)


func _verify_playfield_visibility_helpers() -> void:
	_expect(
		Stage2VisibilityState.has_visible_playfield_overlay(false, false, 0.0, false, 0.0, 1, 0, 0),
		"Stage 2 visibility helper should detect overlay leaf particles"
	)
	_expect(
		Stage2VisibilityState.has_visible_playfield_obstacles(0.0, "idle", 1, 0, 0, 0),
		"Stage 2 visibility helper should detect rock obstacles"
	)
	_expect(
		Stage2VisibilityState.is_boss_movement_locked(false, "charging"),
		"Stage 2 visibility helper should lock boss movement during cannon charge"
	)
	var background := Stage2PillarBackground.new()
	_expect(not background.has_visible_playfield_overlay(), "fresh Stage 2 background should not draw empty overlay decoration")
	_expect(not background.has_visible_playfield_obstacles(), "fresh Stage 2 background should not draw empty obstacle decoration")
	background.rocks.append({"pos": Vector2(120.0, 120.0)})
	_expect(background.has_visible_playfield_obstacles(), "Stage 2 rocks should keep the obstacle draw pass visible")
	_expect(not background.has_visible_playfield_overlay(), "Stage 2 rocks alone should not keep the overlay draw pass visible")
	background.trigger_tree_shake("left", 24.0, 620.0, 750.0)
	_expect(background.has_visible_playfield_overlay(), "Stage 2 border flash / leaf hits should keep the overlay draw pass visible")


func _verify_draw_paths_use_render_caps() -> void:
	var background_source := FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	var ambient_source := FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_ambient_visual_renderer.gd")
	var obstacle_source := FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_obstacle_visual_renderer.gd")
	var water_renderer_source := FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_water_cannon_visual_renderer.gd")
	var warning_source := FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_warning_visual_renderer.gd")
	var counter_source := FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_perf_counter_recorder.gd")
	var pillar_scene_source := FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_scene_drawer.gd")
	var scene_drawer_source := FileAccess.get_file_as_string("res://scripts/core/battle_playfield_scene_drawer.gd")
	var warmup_plan_source := FileAccess.get_file_as_string("res://scripts/core/battle_boot_warmup_plan.gd")
	var pillar_ui_source := FileAccess.get_file_as_string("res://scripts/hud/stage1_pillar_ui_renderer.gd")
	var status_context_source := FileAccess.get_file_as_string("res://scripts/hud/stage1_pillar_status_orb_context_builder.gd")
	var skill_slot_source := FileAccess.get_file_as_string("res://scripts/hud/smasher_skill_orb_slot_renderer.gd")
	var skill_cooldown_source := FileAccess.get_file_as_string("res://scripts/hud/smasher_skill_orb_cooldown_renderer.gd")
	_expect(background_source != "", "Stage 2 pillar background source should be readable")
	_expect(
		background_source.find("func _ensure_texture(") < 0,
		"Stage 2 pillar background should not keep an unused texture-ensure alias"
	)
	_expect(ambient_source != "", "Stage 2 ambient renderer source should be readable")
	_expect(obstacle_source != "", "Stage 2 obstacle renderer source should be readable")
	_expect(water_renderer_source != "", "Stage 2 water cannon renderer source should be readable")
	_expect(warning_source != "", "Stage 2 warning renderer source should be readable")
	_expect(counter_source != "", "Stage 2 perf counter recorder source should be readable")
	_expect(pillar_scene_source != "", "Stage 2 pillar scene drawer source should be readable")
	_expect(scene_drawer_source != "", "Battle playfield scene drawer source should be readable")
	_expect(warmup_plan_source != "", "Battle boot warmup plan source should be readable")
	_expect(pillar_ui_source != "", "shared pillar UI renderer source should be readable")
	_expect(status_context_source != "", "shared pillar status context source should be readable")
	_expect(skill_slot_source != "", "skill orb slot renderer source should be readable")
	_expect(skill_cooldown_source != "", "skill orb cooldown renderer source should be readable")
	_expect(
		_function_body(background_source, "func draw_playfield_overlay").find("LEAF_PARTICLE_RENDER_LIMIT_SEVERE_LOD") >= 0,
		"Stage 2 overlay draw should pass the leaf severe render cap"
	)
	_expect(
		background_source.find("skill_warning_state.trigger") >= 0
			and background_source.find("func _trigger_skill_warning") < 0,
		"Stage 2 background should trigger delegated skill-warning state directly"
	)
	_expect(
		background_source.find("Stage2RenderBudgetHelper.get_playfield_quality_scale") >= 0
			and background_source.find("Stage2RenderBudgetHelper.get_lod_count") >= 0,
		"Stage 2 draw paths should call render-budget helpers directly"
	)
	_expect(
		background_source.find("func _get_playfield_quality_scale") < 0
			and background_source.find("func _get_lod_count") < 0,
		"Stage 2 background should not keep render-budget pass-through wrappers"
	)
	_expect(
		_function_body(background_source, "func draw(").find("_draw_ambient_layers(canvas, quality_scale)") >= 0
			and _function_body(background_source, "func _draw_ambient_layers").find("AMBIENT_FALLING_LEAF_RENDER_LIMIT_SEVERE_LOD") >= 0,
		"Stage 2 pillar background draw should disable ambient falling leaves under severe LOD"
	)
	_expect(
		pillar_scene_source.find("BattleRenderQuality.effect_scale(context)") >= 0
			and pillar_scene_source.find("stage_background.draw(canvas, view_size, game_offset, game_size, width, quality_scale)") >= 0,
		"Stage 2 pillar scene should forward render quality to the pillar background"
	)
	_expect(
		pillar_scene_source.find("_with_stage2_hud_lod_context") >= 0
			and pillar_scene_source.find("stage2_pillar_hud_static_lod") >= 0,
		"Stage 2 pillar scene should still support static HUD rendering for severe render quality"
	)
	_expect(
		pillar_ui_source.find("if skill_orb_renderer != null and not static_hud_lod:") < 0
			and pillar_ui_source.find("if active_skill_orb_renderer != null:") >= 0,
		"Stage 2 pillar HUD restore should keep the skill orb underlay visible"
	)
	_expect(
		status_context_source.find("\"show_count_text\": not static_hud_lod") < 0,
		"Stage 2 pillar HUD restore should keep dash count text on its normal renderer path"
	)
	_expect(
		skill_slot_source.find("static_hud_lod") >= 0
			and skill_slot_source.find("cooldown_renderer.draw(") >= 0,
		"skill orb slots should forward static HUD LOD to cooldown rendering"
	)
	_expect(
		skill_cooldown_source.find("COOLDOWN_RING_SEGMENTS_STATIC_LOD") >= 0
			and _function_body(skill_cooldown_source, "func draw(").find("and not static_hud_lod") >= 0,
		"skill orb cooldown draw should use a cheaper static HUD LOD path"
	)
	_expect(
		_function_body(background_source, "func draw_playfield_overlay").find("STARPOINT_PARTICLE_RENDER_LIMIT_SEVERE_LOD") >= 0,
		"Stage 2 overlay draw should pass the starpoint severe render cap"
	)
	for label in [
		"stage2.overlay.border_flash",
		"stage2.overlay.rage_tint",
		"stage2.overlay.leaf_particles",
		"stage2.overlay.starpoint_particles",
		"stage2.overlay.starpoint_drops",
		"stage2.overlay.fragment_flash",
		"stage2.overlay.skill_warning",
	]:
		_expect(background_source.find(label) >= 0, "Stage 2 overlay draw should expose BattlePerf label %s" % label)
	_expect(
		_function_body(background_source, "func draw_playfield_overlay").find("battle_perf_logger: Object = null") >= 0,
		"Stage 2 overlay draw should accept the shared BattlePerf logger"
	)
	_expect(
		_function_body(background_source, "func draw_playfield_overlay").find("has_visible_playfield_overlay") >= 0,
		"Stage 2 overlay draw should skip when only obstacle visuals are active"
	)
	_expect(
		_function_body(background_source, "func draw_playfield_overlay").find("_record_playfield_overlay_counters") >= 0,
		"Stage 2 overlay draw should report lightweight visual counters"
	)
	_expect(
		_function_body(background_source, "func _record_playfield_overlay_counters").find("Stage2PerfCounterRecorder.record_playfield_overlay_counters") >= 0,
		"Stage 2 overlay counter wrapper should delegate label writes to the counter recorder"
	)
	for overlay_counter in [
		"stage2.overlay.border_flash_active",
		"stage2.overlay.rage_tint_active",
		"stage2.overlay.fragment_flash_active",
		"stage2.overlay.skill_warning_active",
	]:
		_expect(
			counter_source.find(overlay_counter) >= 0,
			"Stage 2 overlay counters should expose non-particle visible lane %s" % overlay_counter
		)
	_expect(
		warning_source.find("_text_layout_cache") >= 0
			and warning_source.find("func _get_fitted_text_layout") >= 0
			and warning_source.find("font.get_string_size") >= 0,
		"Stage 2 skill warning banner should cache fitted text measurement instead of recomputing every draw"
	)
	_expect(
		_function_body(background_source, "func draw_playfield_overlay").find("if not has_visible_playfield_overlay():")
			< _function_body(background_source, "func draw_playfield_overlay").find("_record_playfield_overlay_counters"),
		"Stage 2 overlay counters should stay behind the empty-pass visibility gate"
	)
	for overlay_gate in [
		"if border_flash_state.is_active():",
		"if boss_rage_active or boss_rage_tint > 0.001:",
		"if not leaf_particles.is_empty():",
		"if not starpoint_particles.is_empty():",
		"if not starpoint_drops.is_empty():",
		"if fragment_hit_flash_state.get_timer() > 0.0:",
		"if skill_warning_state.is_active():",
	]:
		_expect(
			_function_body(background_source, "func draw_playfield_overlay").find(overlay_gate) >= 0,
			"Stage 2 overlay draw should guard inactive subpass %s" % overlay_gate
		)
	_expect(
		_function_body(background_source, "func draw_playfield_overlay").find("border_flash_state.get_snapshot()") >= 0
			and background_source.find("func _get_border_flash_visual_state") < 0,
		"Stage 2 border-flash draw should use delegated state directly without a pass-through wrapper"
	)
	_expect(
		_function_body(scene_drawer_source, "func _draw_stage_playfield_overlay").find("draw_playfield_overlay(canvas, draw_context, shake_offset, perf_logger)") >= 0,
		"playfield scene drawer should forward BattlePerf logger to overlay owners that accept it"
	)
	# The earlier optimization wired both `stage2_score_overlay_lod` and
	# `overlay_lod` into a `decorative_lod` gate that hid the entire Stage 2 pillar
	# HUD (and field decorations) while the scoreboard was active. Because
	# `scoreboard_state.is_active()` flips on at the moment of scoring -- before its
	# darkening alpha has faded in -- the HUD orbs and field elements disappeared
	# for a couple of frames during shield kiting and Viper-airborne kill blows.
	# Stage 1 never gated decoration on the scoreboard and reads fine, so the rule
	# here is now "draw decoration unconditionally; rely on the score overlay's
	# own opaque fill once it lands."
	_expect(
		scene_drawer_source.find("var decorative_lod := false") >= 0,
		"Stage 2 playfield drawer should keep decoration always-on (no scoreboard / modal-driven hide of HUD pillar)"
	)
	_expect(
		_function_body(scene_drawer_source, "func _has_visible_stage_playfield_overlay").find("has_visible_playfield_overlay") >= 0
			and _function_body(scene_drawer_source, "func _has_visible_stage_playfield_overlay").find("return true") >= 0,
		"playfield scene drawer should use Stage 2 overlay visibility when available while preserving legacy draw owners"
	)
	_expect(
		_function_body(scene_drawer_source, "func _has_visible_stage_playfield_obstacles").find("has_visible_playfield_obstacles") >= 0
			and _function_body(scene_drawer_source, "func _has_visible_stage_playfield_obstacles").find("return true") >= 0,
		"playfield scene drawer should use Stage 2 obstacle visibility when available while preserving legacy draw owners"
	)
	_expect(
		pillar_scene_source.find("if overlay_lod:\n\t\treturn") < 0,
		"Stage 2 pillar scene must NOT early-return on overlay_lod (caused HUD orbs to vanish during score / modal frames)"
	)
	_expect(
		_function_body(pillar_scene_source, "func draw_pillar_hud_overlay").find("if _is_scoreboard_overlay_active") < 0
			and _function_body(pillar_scene_source, "func draw_post_playfield_hud").find("if _is_scoreboard_overlay_active") < 0,
		"Stage 2 pillar overlay paths must NOT gate the HUD on scoreboard / blocking-overlay state"
	)
	for label in [
		"stage2.pillar.background",
		"stage2.pillar.monkey",
		"stage2.pillar.hud",
		"stage2.pillar.active_item_hud",
		"stage2.pillar.boss_skill_hud",
	]:
		_expect(pillar_scene_source.find(label) >= 0, "Stage 2 pillar draw should expose BattlePerf label %s" % label)
	_expect(
		_function_body(pillar_scene_source, "func _draw_stage2_boss_skill_hud").find("context.duplicate()") < 0,
		"Stage 2 boss skill HUD should build a compact draw context instead of copying the full battle context"
	)
	_expect(
		_function_body(background_source, "func draw_playfield_obstacles").find("ROCK_FRAGMENT_RENDER_LIMIT_SEVERE_LOD") >= 0,
		"Stage 2 obstacle draw should cap rock-fragment rendering with severe LOD"
	)
	_expect(
		_function_body(background_source, "func draw_playfield_obstacles").find("WATER_SPLASH_RENDER_LIMIT_SEVERE_LOD") >= 0,
		"Stage 2 obstacle draw should cap water-splash rendering with severe LOD"
	)
	_expect(
		_function_body(background_source, "func _prewarm_texture_step").find("ProjectResourceLoader.prewarm_texture_threaded_step") >= 0
			and _function_body(background_source, "func _load_texture_step").find("ProjectResourceLoader.load_texture") >= 0
			and background_source.find("func _load_base_texture") < 0
			and background_source.find("func _load_tree_texture") < 0
			and background_source.find("func _load_game_frame_texture") < 0
			and background_source.find("func _load_leaf_texture") < 0
			and background_source.find("func _load_rock_texture") < 0
			and background_source.find("func _load_rock_debris_texture") < 0,
		"Stage 2 texture prewarm should load staged texture chunks directly without one-line pass-through wrappers"
	)
	_expect(
		_function_body(background_source, "func draw_playfield_obstacles").find("quake_wave_visual_state_builder.build_state") >= 0
			and background_source.find("func _get_quake_wave_visual_state") < 0,
		"Stage 2 quake-wave draw should build delegated visual state directly without a pass-through wrapper"
	)
	_expect(
		_function_body(background_source, "func draw_playfield_obstacles").find("rock_visual_assets_builder.build_assets") >= 0
			and background_source.find("func _get_rock_visual_assets") < 0,
		"Stage 2 obstacle assets should build delegated visual assets directly without a pass-through wrapper"
	)
	_expect(
		_function_body(background_source, "func _draw_water_cannon(").find("water_cannon_visual_state_builder.build_state") >= 0
			and background_source.find("func _get_water_cannon_visual_state") < 0,
		"Stage 2 water-cannon draw should build delegated visual state directly without a pass-through wrapper"
	)
	for label in [
		"stage2.obstacles.quake_waves",
		"stage2.obstacles.target_highlight",
		"stage2.obstacles.assets",
		"stage2.obstacles.rocks",
		"stage2.obstacles.rock_fragments",
		"stage2.obstacles.water_cannon",
		"stage2.obstacles.water_splashes",
	]:
		_expect(background_source.find(label) >= 0, "Stage 2 obstacle draw should expose BattlePerf label %s" % label)
	_expect(
		_function_body(background_source, "func draw_playfield_obstacles").find("battle_perf_logger: Object = null") >= 0,
		"Stage 2 obstacle draw should accept the shared BattlePerf logger"
	)
	_expect(
		_function_body(background_source, "func draw_playfield_obstacles").find("has_visible_playfield_obstacles") >= 0,
		"Stage 2 obstacle draw should skip when no obstacle visuals are active"
	)
	_expect(
		_function_body(background_source, "func draw_playfield_obstacles").find("_record_playfield_obstacle_counters") >= 0,
		"Stage 2 obstacle draw should report lightweight visual counters"
	)
	_expect(
		_function_body(background_source, "func _record_playfield_obstacle_counters").find("Stage2PerfCounterRecorder.record_playfield_obstacle_counters") >= 0,
		"Stage 2 obstacle counter wrapper should delegate label writes to the counter recorder"
	)
	for obstacle_counter in [
		"stage2.obstacles.quake_active",
		"stage2.obstacles.water_cannon_active",
		"stage2.obstacles.water_trail",
	]:
		_expect(
			counter_source.find(obstacle_counter) >= 0,
			"Stage 2 obstacle counters should expose non-array visible lane %s" % obstacle_counter
		)
	_expect(
		_function_body(water_renderer_source, "func draw_target_highlight").find("draw_arc") < 0
			and _function_body(water_renderer_source, "func _draw_corner_brackets").find("draw_line") >= 0,
		"Stage 2 water cannon target highlight should avoid high-segment draw_arc calls before firing"
	)
	_expect(
		_function_body(background_source, "func draw_playfield_obstacles").find("if not has_visible_playfield_obstacles():")
			< _function_body(background_source, "func draw_playfield_obstacles").find("_record_playfield_obstacle_counters"),
		"Stage 2 obstacle counters should stay behind the empty-pass visibility gate"
	)
	for obstacle_gate in [
		"if quake_timer > 0.0:",
		"if water_cannon_target_id >= 0:",
		"if not rocks.is_empty() or not rock_fragments.is_empty() or not water_splashes.is_empty():",
		"if not rocks.is_empty():",
		"if not rock_fragments.is_empty():",
		"if water_cannon_phase != \"idle\" or not water_trail.is_empty():",
		"if not water_splashes.is_empty():",
	]:
		_expect(
			_function_body(background_source, "func draw_playfield_obstacles").find(obstacle_gate) >= 0,
			"Stage 2 obstacle draw should guard inactive subpass %s" % obstacle_gate
		)
	_expect(
		_function_body(scene_drawer_source, "func _draw_stage_playfield_obstacles").find("draw_playfield_obstacles(canvas, draw_context, shake_offset, perf_logger)") >= 0,
		"playfield scene drawer should forward BattlePerf logger to obstacle owners that accept it"
	)
	for label in [
		"context.scene",
		"context.deps",
		"context.actor",
	]:
		_expect(scene_drawer_source.find(label) >= 0, "playfield scene drawer should expose BattlePerf label %s" % label)
	_expect(
		_array_body(warmup_plan_source, '"draw_runtime"').find('"stage2_pillar_background"') >= 0,
		"boot warmup draw_runtime group should instantiate Stage 2 pillar background before live draw"
	)
	_expect(
		_function_body(ambient_source, "func draw_leaf_particles").find("_recent_start(leaf_particles, render_limit)") >= 0,
		"Stage 2 ambient renderer should cap leaf rendering"
	)
	_expect(
		_function_body(ambient_source, "func _draw_falling_leaves").find("_recent_start(falling_leaves, render_limit)") >= 0,
		"Stage 2 ambient renderer should cap pillar falling-leaf rendering"
	)
	_expect(
		_function_body(obstacle_source, "func draw_starpoint_particles").find("_recent_start(starpoint_particles, render_limit)") >= 0,
		"Stage 2 obstacle renderer should cap starpoint rendering"
	)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)


func _array_body(source: String, key: String) -> String:
	var start := source.find(key)
	if start < 0:
		return ""
	var close_index := source.find("]", start)
	if close_index < 0:
		return source.substr(start)
	return source.substr(start, close_index - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakePauseMenuOverlay:
	extends RefCounted

	var active := true

	func is_active() -> bool:
		return active


class FakeModalGate:
	extends RefCounted

	func is_pause_menu_active(module_getter: Callable) -> bool:
		var pause_menu: Object = module_getter.call("pause_menu_overlay")
		return pause_menu != null and pause_menu.has_method("is_active") and bool(pause_menu.is_active())


class FakeRegistry:
	extends RefCounted

	var cached := {}
	var lazy_keys: Array[String] = []

	func get_cached_instance(key: String) -> Object:
		var value: Variant = cached.get(key, null)
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
		return null

	func get_instance(key: String) -> Object:
		lazy_keys.append(key)
		return get_cached_instance(key)
