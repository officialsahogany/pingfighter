extends SceneTree

const Stage1BossActorRenderer := preload("res://scripts/stages/stage1/stage1_boss_actor_renderer.gd")
const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
const Stage1PlayerSpriteRenderer := preload("res://scripts/stages/stage1/stage1_player_sprite_renderer.gd")
const Stage1PlayfieldRenderer := preload("res://scripts/stages/stage1/stage1_playfield_renderer.gd")
const Stage1PillarChromeRenderer := preload("res://scripts/stages/stage1/stage1_pillar_chrome_renderer.gd")
const Stage1PillarBackground := preload("res://scripts/stages/stage1/stage1_pillar_background.gd")
const Stage1PillarCloudRenderer := preload("res://scripts/stages/stage1/stage1_pillar_cloud_renderer.gd")
const Stage1PillarPetalRenderer := preload("res://scripts/stages/stage1/stage1_pillar_petal_renderer.gd")
const Stage1PillarPetalState := preload("res://scripts/stages/stage1/stage1_pillar_petal_state.gd")
const Stage1PillarTreeDropPetalState := preload("res://scripts/stages/stage1/stage1_pillar_tree_drop_petal_state.gd")
const BattleDrawPlayfieldSceneContext := preload("res://scripts/core/battle_draw_playfield_scene_context.gd")

var _failures: Array[String] = []


class FakeOwner:
	var selected_character_type := "smasher"
	var current_stage := 1
	var battle_textures: Dictionary = {}

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 750.0))


class FakeBattleViewLayout:
	func build_game_layout(_view_size: Vector2, width: float, height: float) -> Dictionary:
		return {
			"game_offset": Vector2(10.0, 20.0),
			"game_size": Vector2(width, height),
			"render_scale": 1.0,
		}


class FakeDashState:
	func get_snapshot() -> Dictionary:
		return {
			"tokens": 1,
			"max_tokens": 1,
			"active": false,
			"direction": 0.0,
		}


class FakeViperSkillRuntime:
	func is_kick_skill_knockback_ball_active() -> bool:
		return true


class FakeViperJetpackState:
	var active := true
	var air_strike_flash_timer := 18.0

	func is_airborne(_threshold: float) -> bool:
		return true


class FakeRegistry:
	var requested_keys: Array[String] = []
	var view_layout := FakeBattleViewLayout.new()
	var dash_state := FakeDashState.new()
	var viper_runtime := FakeViperSkillRuntime.new()
	var viper_jetpack := FakeViperJetpackState.new()

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		match key:
			"battle_view_layout":
				return view_layout
			"smasher_dash_state":
				return dash_state
			"viper_skill_runtime":
				return viper_runtime
			"viper_jetpack_state":
				return viper_jetpack
		return null


func _init() -> void:
	_verify_actor_perf_forwarding()
	_verify_playfield_context_scopes_viper_modules()
	_verify_render_budget_constants()

	if _failures.is_empty():
		print("stage1_actor_render_budget_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_actor_perf_forwarding() -> void:
	var actor_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_actor_renderer.gd")
	var player_actor_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
	var player_sprite_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_player_sprite_renderer.gd")
	var commando_renderer_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_commando_firearm_renderer.gd")
	var effects_drawer_source := FileAccess.get_file_as_string("res://scripts/core/battle_playfield_effects_drawer.gd")
	_expect(
		actor_source.find("func draw(canvas: CanvasItem, context: Dictionary, perf_logger: Object = null)") >= 0,
		"Stage 1 actor draw should accept the shared perf logger"
	)
	for label in [
		"actors.stage1.playfield",
		"actors.stage1.dash_trail",
		"actors.stage1.player",
		"actors.stage1.boss",
		"actors.stage1.commando_firearm",
	]:
		_expect(actor_source.find(label) >= 0, "Stage 1 actor draw should report " + label)
	_expect(
		effects_drawer_source.find("actor_renderer.draw(canvas, actor_context, perf_logger)") >= 0,
		"battle playfield effects drawer should forward BattlePerf logger to Stage 1 actor draw"
	)
	_expect(
		effects_drawer_source.find("_method_accepts_argument_count(actor_renderer, \"draw\", 3)") >= 0,
		"battle playfield effects drawer should account for default perf-logger arguments"
	)
	_expect(
		effects_drawer_source.find("default_args") >= 0,
		"battle playfield effects drawer should inspect default arguments when forwarding perf logger"
	)
	_expect(
		actor_source.find("player_renderer.prewarm_runtime_assets()") >= 0
			and actor_source.find("commando_firearm_renderer.prewarm_runtime_assets()") >= 0,
		"Stage 1 actor prewarm should delegate through runtime renderer instances"
	)
	_expect(
		actor_source.find("playfield_renderer.prewarm_runtime_assets()") >= 0
			and actor_source.find("player_renderer.prewarm_runtime_assets()") >= 0
			and actor_source.find("commando_firearm_renderer.prewarm_runtime_assets()") >= 0,
		"Stage 1 actor prewarm should delegate through playfield and runtime renderer instances"
	)
	_expect(
		actor_source.find("playfield_renderer.prewarm_runtime_assets_step()") >= 0
			and actor_source.find("player_renderer.prewarm_runtime_assets_step()") >= 0,
		"Stage 1 actor prewarm should stage playfield/player cache construction"
	)
	_expect(
		player_actor_source.find("func prewarm_runtime_assets() -> void:") >= 0
			and player_sprite_source.find("func prewarm_runtime_assets() -> void:") >= 0
			and commando_renderer_source.find("func prewarm_runtime_assets() -> void:") >= 0,
		"Stage 1 runtime renderers should expose instance prewarm hooks"
	)


func _verify_playfield_context_scopes_viper_modules() -> void:
	var builder := BattleDrawPlayfieldSceneContext.new()
	var smasher_owner := FakeOwner.new()
	var smasher_registry := FakeRegistry.new()
	var smasher_context: Dictionary = builder.build(smasher_owner, Vector2.ZERO, smasher_registry)
	_expect(not smasher_registry.requested_keys.has("viper_skill_runtime"), "Smasher playfield context should not wake Viper skill runtime")
	_expect(not smasher_registry.requested_keys.has("viper_jetpack_state"), "Smasher playfield context should not wake Viper jetpack state")
	_expect(smasher_registry.requested_keys.has("smasher_dash_state"), "playfield context should keep the shared dash snapshot path")
	_expect(str(smasher_context.get("selected_character_type", "")) == "smasher", "playfield context should expose normalized Smasher id")

	var viper_owner := FakeOwner.new()
	viper_owner.selected_character_type = "viper"
	var viper_registry := FakeRegistry.new()
	var viper_context: Dictionary = builder.build(viper_owner, Vector2.ZERO, viper_registry)
	_expect(viper_registry.requested_keys.has("viper_skill_runtime"), "Viper playfield context should still read Viper skill runtime")
	_expect(viper_registry.requested_keys.has("viper_jetpack_state"), "Viper playfield context should still read Viper jetpack state")
	_expect(bool(viper_context.get("viper_knockback_overlay_active", false)), "Viper context should preserve kick knockback overlay state")
	_expect(bool(viper_context.get("viper_jetpack_active", false)), "Viper context should preserve jetpack active state")
	_expect(bool(viper_context.get("viper_jetpack_airborne", false)), "Viper context should preserve airborne state")
	_expect(is_equal_approx(float(viper_context.get("viper_air_strike_flash_timer", 0.0)), 18.0), "Viper context should preserve air-strike flash timer")


func _verify_render_budget_constants() -> void:
	var player_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
	var player_sprite_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_player_sprite_renderer.gd")
	var playfield_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_playfield_renderer.gd")
	var pillar_background_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_pillar_background.gd")
	_expect(player_source.find("const _HOVER_EMBER_SLOT_COUNT := 8") >= 0, "Viper hover ember draw slots should stay capped")
	_expect(Stage1PlayfieldRenderer.DASH_AFTERIMAGE_MAX_COUNT <= 3, "Stage 1 dash afterimages should stay capped")
	_expect(Stage1PlayfieldRenderer.DASH_AFTERIMAGE_LOD_MAX_COUNT <= 1, "Stage 1 Viper LOD dash afterimages should stay tighter")
	_expect(Stage1PlayfieldRenderer.GRID_PARTICLE_COUNT <= 6, "Stage 1 grid particles should stay capped")
	_expect(Stage1PlayfieldRenderer.GRID_PARTICLE_COUNT_LOD <= 3, "Stage 1 Viper LOD grid particles should stay capped")
	_expect(Stage1PlayfieldRenderer.GRID_PARTICLE_COUNT_SEVERE_LOD <= 1, "Stage 1 severe Viper LOD grid particles should stay tighter")
	_expect(Stage1PlayfieldRenderer.FLOOR_SPECK_COUNT <= 160, "Stage 1 fallback floor specks should stay capped")
	_expect(Stage1PlayfieldRenderer.FLOOR_SPECK_COUNT_LOD <= 48, "Stage 1 Viper LOD fallback floor specks should stay capped")
	_expect(Stage1PlayfieldRenderer.FLOOR_SPECK_COUNT_SEVERE_LOD <= 20, "Stage 1 severe Viper LOD fallback floor specks should stay tighter")
	_expect(Stage1PlayfieldRenderer.FLOOR_MOSS_COUNT <= 36, "Stage 1 fallback floor moss should stay capped")
	_expect(Stage1PlayfieldRenderer.FLOOR_MOSS_COUNT_LOD <= 12, "Stage 1 Viper LOD fallback floor moss should stay capped")
	_expect(Stage1PlayfieldRenderer.FLOOR_MOSS_COUNT_SEVERE_LOD <= 6, "Stage 1 severe Viper LOD fallback floor moss should stay tighter")
	_expect(Stage1PlayfieldRenderer.FLOOR_TILE_DRAW_STRIDE_LOD >= 3, "Stage 1 Viper LOD fallback floor tiles should be sampled")
	_expect(Stage1PlayfieldRenderer.STAGE1_WALL_FLASH_GRADIENT_STEPS <= 4, "Stage 1 wall flash gradient should stay light")
	_expect(Stage1PlayfieldRenderer.STAGE1_WALL_FLASH_GRADIENT_STEPS_LOD <= 2, "Stage 1 Viper LOD wall flash gradient should stay tighter")
	_expect(Stage1PlayfieldRenderer.STAGE1_WALL_FLASH_SIDE_STRIP_STEPS <= 4, "Stage 1 wall flash side strips should stay light")
	_expect(Stage1PlayfieldRenderer.STAGE1_WALL_FLASH_SIDE_STRIP_STEPS_LOD <= 2, "Stage 1 Viper LOD wall flash side strips should stay tighter")
	_expect(Stage1PlayfieldRenderer.STAGE1_WALL_FLASH_SATELLITE_COUNT <= 2, "Stage 1 wall flash satellites should stay capped")
	_expect(Stage1PlayfieldRenderer.STAGE1_WALL_FLASH_SATELLITE_COUNT_LOD <= 1, "Stage 1 Viper LOD wall flash satellites should stay tighter")
	_expect(Stage1PlayfieldRenderer.STAGE1_BORDER_MARK_SPACING >= 18, "Stage 1 default border marks should stay sparse")
	_expect(Stage1PlayfieldRenderer.STAGE1_BORDER_MARK_SPACING_LOD >= 40, "Stage 1 Viper LOD border marks should stay sparse")
	_expect(Stage1PlayfieldRenderer.STAGE1_BORDER_MARK_SPACING_SEVERE_LOD >= 60, "Stage 1 severe Viper LOD border marks should stay sparser")
	_expect(Stage1PlayfieldRenderer.STAGE1_BORDER_CORNER_ARC_SEGMENTS <= 16, "Stage 1 border corner arcs should stay coarse")
	_expect(Stage1PlayfieldRenderer.STAGE1_BORDER_CORNER_ARC_SEGMENTS_LOD <= 10, "Stage 1 Viper LOD border corner arcs should stay coarse")
	_expect(Stage1PlayfieldRenderer.STADIUM_GUIDE_ARC_SEGMENTS <= 28, "Stage 1 stadium guide arcs should stay coarse")
	_expect(Stage1PlayfieldRenderer.STADIUM_GUIDE_ARC_SEGMENTS_LOD <= 12, "Stage 1 Viper LOD stadium guide arcs should stay coarse")
	_expect(Stage1PlayfieldRenderer.STADIUM_GUIDE_ARC_SEGMENTS_SEVERE_LOD <= 8, "Stage 1 severe Viper LOD stadium guide arcs should stay very coarse")
	_expect(Stage1PlayfieldRenderer.STAGE1_FLOOR_EDGE_VIGNETTE_STEPS <= 8, "Stage 1 floor edge vignette should stay compact")
	_expect(Stage1PlayfieldRenderer.STAGE1_FLOOR_EDGE_VIGNETTE_STEPS_LOD <= 4, "Stage 1 Viper LOD floor edge vignette should stay compact")
	_expect(Stage1PlayfieldRenderer.STAGE1_FLOOR_EDGE_VIGNETTE_STEPS_SEVERE_LOD <= 3, "Stage 1 severe Viper LOD floor edge vignette should stay compact")
	_expect(Stage1PlayfieldRenderer.STADIUM_SPARK_POINT_STEP >= 16.0, "Stage 1 stadium spark should keep a coarse point step")
	_expect(Stage1PlayfieldRenderer.STADIUM_SPARK_POINT_STEP_LOD >= 26.0, "Stage 1 Viper LOD stadium spark should use a coarser point step")
	_expect(Stage1PlayfieldRenderer.STADIUM_SPARK_POINT_STEP_SEVERE_LOD >= 36.0, "Stage 1 severe Viper LOD stadium spark should use the coarsest point step")
	_expect(Stage1PlayfieldRenderer.STADIUM_SPARK_BRANCH_COUNT <= 3, "Stage 1 stadium spark branches should stay capped")
	_expect(Stage1PlayfieldRenderer.STADIUM_SPARK_BRANCH_COUNT_LOD <= 1, "Stage 1 Viper LOD stadium spark branches should stay tighter")
	_expect(Stage1PlayfieldRenderer.STADIUM_SPARK_TRAIL_SPARK_COUNT <= 2, "Stage 1 stadium trail sparks should stay capped")
	_expect(Stage1PlayfieldRenderer.STADIUM_SPARK_TRAIL_SPARK_COUNT_LOD <= 1, "Stage 1 Viper LOD stadium trail sparks should stay tighter")
	_expect(Stage1PlayfieldRenderer.STAGE1_CYBER_SCANLINE_COUNT <= 5, "Stage 1 cyber scanlines should stay capped")
	_expect(Stage1PlayfieldRenderer.STAGE1_CYBER_SCANLINE_COUNT_LOD <= 1, "Stage 1 Viper LOD cyber scanlines should stay capped")
	_expect(Stage1PlayfieldRenderer.STAGE1_CYBER_GLITCH_BAND_COUNT_LOD <= 1, "Stage 1 Viper LOD cyber glitch bands should stay capped")
	_expect(Stage1PlayfieldRenderer.STAGE1_CYBER_GLITCH_BAND_COUNT <= 3, "Stage 1 cyber glitch bands should stay capped")
	_expect(Stage1PlayfieldRenderer.STAGE1_CYBER_CIRCUIT_TICK_COUNT <= 4, "Stage 1 cyber ticks should stay capped")
	_expect(Stage1PlayfieldRenderer.STAGE1_CYBER_CIRCUIT_TICK_COUNT_LOD <= 1, "Stage 1 Viper LOD cyber ticks should stay capped")
	_expect(Stage1PlayfieldRenderer.STAGE1_MOOD_EDGE_STEPS <= 6, "Stage 1 playfield mood edge steps should stay compact")
	_expect(Stage1PlayfieldRenderer.STAGE1_MOOD_EDGE_STEPS_LOD <= 3, "Stage 1 Viper LOD playfield mood edge steps should stay compact")
	_expect(Stage1PlayfieldRenderer.STAGE1_MOOD_EDGE_STEPS_SEVERE_LOD <= 2, "Stage 1 severe Viper LOD playfield mood edge steps should stay compact")
	_expect(Stage1PlayfieldRenderer.STAGE1_OMINOUS_SHADOW_STEPS <= 7, "Stage 1 playfield ominous shadow steps should stay compact")
	_expect(Stage1PlayfieldRenderer.STAGE1_OMINOUS_SHADOW_STEPS_LOD <= 3, "Stage 1 Viper LOD shadow steps should stay capped")
	_expect(Stage1PlayfieldRenderer.STAGE1_OMINOUS_SHADOW_STEPS_SEVERE_LOD <= 2, "Stage 1 severe Viper LOD shadow steps should stay capped")
	_expect(Stage1PlayfieldRenderer.STAGE1_DEPTH_BAND_STEPS <= 5, "Stage 1 playfield depth layers should stay compact")
	_expect(Stage1PlayfieldRenderer.STAGE1_DEPTH_BAND_STEPS_LOD <= 3, "Stage 1 Viper LOD depth layers should stay compact")
	_expect(Stage1PlayfieldRenderer.STAGE1_DEPTH_BAND_STEPS_SEVERE_LOD <= 2, "Stage 1 severe Viper LOD depth layers should stay compact")
	_expect(
		playfield_source.find("context.get(\"stage1_depth_layers_enabled\", false)") >= 0,
		"Stage 1 solid depth bands should default off after the color-strip review"
	)
	_expect(Stage1PlayfieldRenderer.STAGE1_FLOOR_VIGNETTE_STEPS <= 8, "Stage 1 floor vignette should stay compact")
	_expect(Stage1PlayfieldRenderer.STAGE1_FLOOR_VIGNETTE_STEPS_LOD <= 5, "Stage 1 Viper LOD floor vignette should stay compact")
	_expect(Stage1PlayfieldRenderer.STAGE1_FLOOR_VIGNETTE_STEPS_SEVERE_LOD <= 3, "Stage 1 severe Viper LOD floor vignette should stay compact")
	_expect(Stage1PlayfieldRenderer.STAGE1_FLOOR_VIGNETTE_OUTER_ALPHA <= 56.0 / 255.0, "Stage 1 floor vignette edge alpha should stay bounded")
	_expect(
		playfield_source.find("_draw_stage1_floor_vignette(canvas, context, width, height, quality_scale)") >= 0,
		"Stage 1 playfield draw should include the soft floor vignette"
	)
	_expect(Stage1PlayerActorRenderer.PLAYER_GROUND_SHADOW_BASE_WIDTH >= 220.0, "Stage 1 player ground shadow should read wider")
	_expect(Stage1PlayerActorRenderer.PLAYER_GROUND_SHADOW_BASE_WIDTH <= 240.0, "Stage 1 player ground shadow width should stay bounded")
	_expect(Stage1PlayerActorRenderer.PLAYER_GROUND_SHADOW_BASE_HEIGHT >= 20.0, "Stage 1 player ground shadow should read thicker")
	_expect(Stage1PlayerActorRenderer.PLAYER_GROUND_SHADOW_BASE_HEIGHT <= 24.0, "Stage 1 player ground shadow height should stay bounded")
	_expect(Stage1PlayerActorRenderer.PLAYER_GROUND_SHADOW_ALPHA >= 0.24, "Stage 1 player ground shadow should stay visible")
	_expect(Stage1PlayerActorRenderer.PLAYER_GROUND_SHADOW_ALPHA <= 0.28, "Stage 1 player ground shadow alpha should stay bounded")
	_expect(
		player_source.find("_draw_player_topdown_rimlight") < 0 and player_source.find("PLAYER_TOPDOWN_RIMLIGHT") < 0,
		"Stage 1 player draw should not include the rejected fixed-ellipse topdown rimlight"
	)
	_expect(player_source.find("sprite_renderer.clear_transient_canvas_items()") >= 0, "Stage 1 player actor should clear transient sprite canvas items before hidden returns")
	_expect(Stage1PlayerSpriteRenderer.DEFAULT_PLAYER_SILHOUETTE_RIM_INTENSITY >= 0.60, "Stage 1 player silhouette rim should default visible")
	_expect(Stage1PlayerSpriteRenderer.DEFAULT_PLAYER_SILHOUETTE_RIM_INTENSITY <= 0.70, "Stage 1 player silhouette rim should stay bounded")
	_expect(Stage1PlayerSpriteRenderer.PLAYER_SILHOUETTE_RIM_OFFSET_PX <= 2.0, "Stage 1 player silhouette rim should stay 1-2px")
	_expect(player_sprite_source.find("CharacterTopdownRimShader") >= 0, "Stage 1 player sprite renderer should load the topdown rim shader")
	_expect(player_sprite_source.find("stage1_player_silhouette_rim_enabled") >= 0, "Stage 1 player silhouette rim should have a runtime toggle")
	_expect(player_sprite_source.find("func clear_transient_canvas_items() -> void:") >= 0, "Stage 1 player sprite renderer should expose transient canvas cleanup")
	_expect(
		player_sprite_source.find("canvas.material = material") >= 0
		and player_sprite_source.find("canvas.material = prev_material") >= 0,
		"Stage 1 player silhouette rim should restore the canvas material after drawing"
	)
	_expect(
		player_sprite_source.find("RenderingServer.canvas_item_create") < 0
		and player_sprite_source.find("_silhouette_rim_item") < 0,
		"Stage 1 player silhouette rim must not create a separate canvas_item RID (draw_set_transform trap failure mode 4)"
	)
	_expect(Stage1BossActorRenderer.GROUND_SHADOW_ALPHAS.size() <= 2, "Stage 1 boss shadow should use at most two polygon layers")
	_expect(Stage1BossActorRenderer.GROUND_SHADOW_SEGMENTS <= 12, "Stage 1 boss shadow should use a bounded ellipse segment count")
	_expect(Stage1PillarChromeRenderer.GAME_BORDER_SHINE_LAYERS <= 2, "Stage 1 border shine should use at most two rect layers")
	_expect(Stage1PillarChromeRenderer.GAME_BORDER_SHINE_LAYERS_LOD <= 1, "Stage 1 Viper LOD border shine should use one rect layer")
	_expect(Stage1PillarChromeRenderer.GAME_BORDER_SHINE_LOD_THRESHOLD >= 0.85, "Stage 1 border shine LOD should trigger for Viper quality scale")
	_expect(Stage1PillarBackground.MOOD_EDGE_STEPS <= 6, "Stage 1 pillar mood edge steps should stay compact")
	_expect(Stage1PillarBackground.OMINOUS_CORNER_STEPS <= 7, "Stage 1 pillar ominous corner bands should stay compact")
	_expect(Stage1PillarBackground.CYBER_SIGN_SLIT_COUNT <= 4, "Stage 1 pillar cyber slits should stay compact")
	_expect(pillar_background_source.find("quality_scale < 0.66:\n\t\treturn 1") >= 0, "Stage 1 pillar severe LOD mood work should stay tight")
	_expect(pillar_background_source.find("quality_scale < 0.85:\n\t\treturn 3") >= 0, "Stage 1 pillar Viper LOD mood edge work should stay tight")
	_expect(pillar_background_source.find("quality_scale < 0.85:\n\t\treturn 4") >= 0, "Stage 1 pillar Viper LOD ominous corner work should stay tight")
	_expect(Stage1PillarCloudRenderer.CLOUD_LOD_THRESHOLD >= 0.85, "Stage 1 cloud LOD should trigger for Viper quality scale")
	_expect(Stage1PillarCloudRenderer.CLOUD_PRIMARY_LAYER_COUNT <= 2, "Stage 1 cloud LOD should keep two primary cloud layers")
	_expect(Stage1PillarCloudRenderer.CLOUD_TOTAL_LAYER_COUNT <= 4, "Stage 1 cloud default should keep a bounded cloud layer count")
	_expect(Stage1PillarPetalState.FLOATING_PETAL_MAX <= 8, "Stage 1 floating petals should stay tightly capped")
	_expect(Stage1PillarPetalState.FLOATING_PETAL_SPAWN_RATE <= 0.72, "Stage 1 floating petal spawn rate should stay bounded")
	_expect(Stage1PillarTreeDropPetalState.TREE_DROP_PETAL_MAX <= 18, "Stage 1 tree-drop petals should stay tightly capped")
	_expect(Stage1PillarTreeDropPetalState.TREE_DROP_PETAL_SPAWN_MAX <= 2, "Stage 1 tree-drop petal burst should stay bounded")
	_expect(Stage1PillarPetalRenderer.TREE_DROP_PETAL_SEGMENTS <= 6, "Stage 1 tree-drop petal polygons should stay light")
	_expect(Stage1PillarPetalRenderer.TREE_DROP_PETAL_ARC_SEGMENTS <= 6, "Stage 1 tree-drop petal arcs should stay light")
	_expect(Stage1PillarPetalRenderer.FLOATING_PETAL_SEGMENTS <= 6, "Stage 1 floating petal polygons should stay light")
	_expect(Stage1PillarPetalRenderer.LOD_PETAL_SEGMENTS <= 4, "Stage 1 Viper LOD petal polygons should stay coarse")
	for label in [
		"stage1.pillar.bg_clouds",
		"stage1.pillar.bg_trees",
		"stage1.pillar.bg_petals",
		"stage1.pillar.bg_butterflies",
		"stage1.pillar.overlay_clouds",
	]:
		_expect(pillar_background_source.find(label) >= 0, "Stage 1 pillar background should report " + label)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
