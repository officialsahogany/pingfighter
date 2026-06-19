extends SceneTree

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BattleDrawBallContext := preload("res://scripts/core/battle_draw_ball_context.gd")
const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const Stage1CommandoFirearmRenderer := preload("res://scripts/stages/stage1/stage1_commando_firearm_renderer.gd")
const Stage3ActorRenderer := preload("res://scripts/stages/stage3/stage3_actor_renderer.gd")
const Stage3BossSkillHudRenderer := preload("res://scripts/stages/stage3/stage3_boss_skill_hud_renderer.gd")
const Stage3BossSkillState := preload("res://scripts/stages/stage3/stage3_boss_skill_state.gd")
const Stage3MenheraBossActorRenderer := preload("res://scripts/stages/stage3/stage3_menhera_boss_actor_renderer.gd")
const Stage3PlayfieldRenderer := preload("res://scripts/stages/stage3/stage3_playfield_renderer.gd")
const Stage3PillarBackground := preload("res://scripts/stages/stage3/stage3_pillar_background.gd")
const Stage3PillarSceneDrawer := preload("res://scripts/stages/stage3/stage3_pillar_scene_drawer.gd")
const StageRuntimeRouter := preload("res://scripts/stages/stage_runtime_router.gd")
const StatusEffectState := preload("res://scripts/status/status_effect_state.gd")
const ViperAirborneLod := preload("res://scripts/core/viper_airborne_lod.gd")

const BASE_TEXTURE_PATH := "res://assets/sprites/hud/stage3_layered_cyber_menhera_base_imagegen_v4.png"
const AMBIENT_TEXTURE_PATH := "res://assets/sprites/hud/stage3_menhera_ambient_sprites_imagegen_v3.png"
const CENTER_FRAME_TEXTURE_PATH := "res://assets/sprites/hud/stage3_center_frame_imagegen_v2.png"
const LANDING_TEXTURE_PATH := "res://assets/sprites/hud/stage3_landing_zoom_background_imagegen_v1.png"
const MENHERA_SKILLCARD_ATLAS_PATH := "res://assets/sprites/stage3/menhera_boss_skill_cards_imagegen_v1.png"
const MENHERA_SKILLCARD_SOURCE_PATH := "res://assets/sprites/stage3/menhera_boss_skill_cards_imagegen_v1_source.png"
const MENHERA_BOSS_SHEET_PATHS := [
	"res://assets/sprites/stage3/menhera_boss_sheet.png",
	"res://assets/sprites/stage3/menhera_boss_attack.png",
	"res://assets/sprites/stage3/menhera_boss_dash.png",
	"res://assets/sprites/stage3/menhera_boss_turn.png",
	"res://assets/sprites/stage3/menhera_boss_victory.png",
	"res://assets/sprites/stage3/menhera_boss_defeat.png",
]
const STAGE3_AUDIO_PATHS := [
	"res://assets/bgm/stage3bgm.ogg",
	"res://assets/sounds/stage3tail.wav",
	"res://assets/sounds/psychoball.wav",
	"res://assets/sounds/dollcurse.wav",
	"res://assets/sounds/tears.wav",
	"res://assets/sounds/bonemake.wav",
	"res://assets/sounds/weakexplosion.wav",
	"res://assets/sounds/kuromiawake.wav",
	"res://assets/sounds/kuromitongue.wav",
	"res://assets/sounds/kuromiswallow.wav",
]


class FakeStage3Audio:
	var starpoint_collect_count := 0

	func play_starpoint_collect() -> void:
		starpoint_collect_count += 1


class FakeRuntimePerkState:
	var collected_star_points := 0

	func collect_star_points(amount: int, _character_type: String, _catalog: Object = null, _owner: Object = null, _registry: Object = null) -> bool:
		collected_star_points += max(0, amount)
		return true


class FakeOwner:
	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1


class FakeChaosRuntime:
	var release_count := 0
	var last_release_context := {}

	func release_chaos_blackhole_from_hit(_deps: Dictionary = {}, context: Dictionary = {}) -> bool:
		release_count += 1
		last_release_context = context.duplicate(true)
		return true


class Stage3DrawProbe:
	extends Node2D

	var background: Object = null
	var actor_renderer: Object = null
	var skill_state: Object = null
	var skill_hud_renderer: Object = null
	var background_draw_count: int = 0
	var actor_draw_count: int = 0
	var skill_hud_draw_count: int = 0
	var background_draw_result: bool = false

	func _draw() -> void:
		if background != null:
			background.update(1.0 / 60.0, {}, {})
			background_draw_count += 1
			background_draw_result = background.draw(
				self,
				Vector2(1280.0, 800.0),
				Vector2(260.0, 25.0),
				Vector2(760.0, 750.0),
				760.0
			)
		if actor_renderer != null:
			actor_draw_count += 1
			var actor_context := {
				"current_stage": 3,
				"width": 760.0,
				"height": 750.0,
				"ball_pos": Vector2(380.0, 375.0),
				"player_pos": Vector2(300.0, 700.0),
				"player_paddle_size": Vector2(155.0, 50.0),
				"boss_pos": Vector2(320.0, 25.0),
				"boss_paddle_size": Vector2(110.0, 18.0),
				"boss_hitbox_height": 40.0,
				"stage3_emotional_phase": 1,
				"stage3_kuromi_awakened": false,
			}
			if skill_state != null and skill_state.has_method("get_actor_draw_context"):
				actor_context.merge(skill_state.get_actor_draw_context(), true)
			actor_context["stage3_curse_reverse_active"] = true
			actor_context["stage3_curse_reverse_ratio"] = 0.65
			actor_renderer.draw(self, actor_context)
			var awake_context: Dictionary = actor_context.duplicate(true)
			awake_context["stage3_kuromi_petrified"] = false
			awake_context["stage3_kuromi_awakened"] = true
			awake_context["stage3_kuromi_awakening"] = false
			awake_context["stage3_tail_whip_active"] = true
			awake_context["stage3_tail_whip_progress"] = 0.5
			awake_context["stage3_tail_hit_bursts"] = [{
				"x": 390.0,
				"y": 375.0,
				"life": 0.32,
				"max_life": 0.55,
				"angle": 0.35,
				"seed": 3303,
			}]
			awake_context["stage3_starpoint_drops"] = [{
				"pos": Vector2(405.0, 390.0),
				"vel": Vector2(1.4, -2.0),
				"size": 12.0,
				"rotation": 0.35,
				"glow_intensity": 1.0,
				"life": 560.0,
				"source_type": "menhera_tail",
			}]
			awake_context["stage3_starpoint_particles"] = [{
				"pos": Vector2(405.0, 390.0),
				"size": 2.4,
				"alpha": 0.8,
				"color_shift": 0.55,
			}]
			actor_renderer.draw(self, awake_context)
			var eating_context: Dictionary = actor_context.duplicate(true)
			eating_context["stage3_kuromi_petrified"] = false
			eating_context["stage3_kuromi_awakened"] = true
			eating_context["stage3_kuromi_eating_active"] = true
			eating_context["stage3_kuromi_eating_timer"] = 28.0
			eating_context["stage3_kuromi_mouth_open"] = 0.86
			eating_context["stage3_kuromi_tongue_extended"] = 0.92
			eating_context["stage3_kuromi_tongue_wrap_phase"] = 0.42
			eating_context["stage3_kuromi_ball_on_tongue"] = true
			eating_context["stage3_kuromi_ball_tongue_pos"] = Vector2(420.0, 410.0)
			eating_context["stage3_kuromi_tongue_angle"] = 0.35
			actor_renderer.draw(self, eating_context)
		if skill_hud_renderer != null and skill_state != null:
			skill_hud_draw_count += 1
			var hud_context := {
				"current_stage": 3,
				"view_size": Vector2(1280.0, 800.0),
				"game_offset": Vector2(260.0, 25.0),
				"game_size": Vector2(760.0, 750.0),
			}
			hud_context.merge(skill_state.get_hud_context(null, hud_context), true)
			skill_hud_renderer.draw(self, hud_context)


var probe: Stage3DrawProbe = null
var frame_count: int = 0


func _init() -> void:
	_expect_stage3_asset(BASE_TEXTURE_PATH, Vector2(1254.0, 1254.0), "Stage 3 original pillar base image should load")
	_expect_stage3_asset(AMBIENT_TEXTURE_PATH, Vector2(1774.0, 887.0), "Stage 3 original ambient sprite sheet should load")
	_expect_stage3_asset(CENTER_FRAME_TEXTURE_PATH, Vector2(1277.0, 1158.0), "Stage 3 original center frame image should load")
	_expect_stage3_asset(LANDING_TEXTURE_PATH, Vector2(1254.0, 1254.0), "Stage 3 landing zoom background should load")
	_expect_stage3_asset(MENHERA_SKILLCARD_ATLAS_PATH, Vector2(1024.0, 96.0), "Stage 3 Menhera boss skillcard atlas should load")
	_expect_stage3_asset(MENHERA_SKILLCARD_SOURCE_PATH, Vector2(2048.0, 768.0), "Stage 3 Menhera boss skillcard source should be preserved")
	for path in MENHERA_BOSS_SHEET_PATHS:
		_expect_stage3_asset(str(path), Vector2(2752.0, 1536.0), "Stage 3 Menhera boss sheet should load")
	for path in STAGE3_AUDIO_PATHS:
		_expect(ProjectResourceLoader.load_audio_stream(str(path)) != null, "Stage 3 Menhera audio stream should load: %s" % str(path))

	var router: Object = StageRuntimeRouter.new()
	_expect(str(router.get_module_key(3, "actor_renderer")) == "stage3_actor_renderer", "Stage 3 should route actor drawing to the Stage 3 actor renderer")
	_expect(str(router.get_module_key(3, "pillar_scene_drawer")) == "stage3_pillar_scene_drawer", "Stage 3 should route pillar drawing to the Stage 3 pillar scene drawer")
	_expect(str(router.get_module_key(3, "stage_background")) == "stage3_pillar_background", "Stage 3 should route stage background state to the Stage 3 pillar background")

	var registry: Object = GameplayModuleRegistry.new()
	var actor_renderer: Object = registry.get_instance("stage3_actor_renderer")
	_expect(actor_renderer != null and actor_renderer.has_method("draw"), "Stage 3 actor renderer should be constructible from the module catalog")
	_expect(actor_renderer.has_method("prewarm_assets"), "Stage 3 actor renderer should expose prewarm_assets")
	_expect(actor_renderer.has_method("reset"), "Stage 3 actor renderer should expose reset")
	actor_renderer.prewarm_assets()
	_expect(Stage1CommandoFirearmRenderer.slingshot_stone_texture is Texture2D, "Stage 3 actor prewarm should warm Commando firearm projectile sheets")
	_expect(Stage1CommandoFirearmRenderer.bowling_trap_installed_texture is Texture2D, "Stage 3 actor prewarm should warm Commando firearm trap textures")
	actor_renderer.reset()

	var pillar_scene_drawer: Object = registry.get_instance("stage3_pillar_scene_drawer")
	_expect(
		pillar_scene_drawer != null and pillar_scene_drawer.has_method("draw_post_playfield_hud"),
		"Stage 3 pillar scene drawer should expose the post-playfield HUD pass"
	)

	var background: Object = registry.get_instance("stage3_pillar_background")
	_expect(background != null and background.has_method("draw"), "Stage 3 pillar background should be constructible from the module catalog")
	_expect(background.has_method("prewarm_assets_step"), "Stage 3 pillar background should expose staged prewarm chunks")
	background.prewarm_assets()
	var asset_status: Dictionary = background.get_imagegen_asset_status()
	_expect(bool(asset_status.get("base", false)), "Stage 3 pillar base image should be available to the runtime renderer")
	_expect(bool(asset_status.get("ambient", false)), "Stage 3 ambient sprite sheet should be available to the runtime renderer")
	_expect(bool(asset_status.get("center_frame", false)), "Stage 3 center frame image should be available to the runtime renderer")
	_expect(int(asset_status.get("ambient_sprite_count", 0)) == 8, "Stage 3 ambient sprite sheet should slice into eight source sprites")

	var direct_background: Object = Stage3PillarBackground.new()
	var staged_background_steps := 0
	while staged_background_steps < 8:
		staged_background_steps += 1
		if bool(direct_background.prewarm_assets_step()):
			break
	_expect(staged_background_steps == Stage3PillarBackground.PREWARM_STEP_COUNT, "Stage 3 pillar background should stage texture/window prewarm")
	direct_background.prewarm_assets()
	_expect(bool(direct_background.get_imagegen_asset_status().get("center_frame", false)), "Stage 3 direct pillar background construction should load the center frame")
	var background_perf: Dictionary = direct_background.get_performance_snapshot()
	_expect(int(background_perf.get("floating_heart_target_total", 999)) <= 16, "Stage 3 pillar floating hearts should stay within the draw budget")
	_expect(int(background_perf.get("floating_heart_pop_particle_count", 999)) <= 4, "Stage 3 pillar pop particles should stay within the draw budget")
	_expect(int(background_perf.get("floating_heart_draw_limit_lod", 999)) <= 10, "Stage 3 pillar should tighten floating-heart drawing during airborne LOD")
	_expect(int(background_perf.get("floating_heart_draw_limit_severe_lod", 999)) <= 6, "Stage 3 pillar should use a severe Viper floating-heart cap")
	_expect(int(background_perf.get("edge_accent_count", 999)) <= 2, "Stage 3 pillar edge accents should stay within the draw budget")
	_expect(int(background_perf.get("edge_accent_count_lod", 999)) <= 1, "Stage 3 pillar edge accents should tighten during airborne LOD")
	var stage3_bg_source := FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_pillar_background.gd")
	_expect(stage3_bg_source.find("Image.load_from_file") < 0, "Stage 3 pillar background should use baked regions instead of runtime image alpha scans")
	var direct_playfield: Object = Stage3PlayfieldRenderer.new()
	direct_playfield.prewarm_assets()
	var playfield_perf: Dictionary = direct_playfield.get_performance_snapshot()
	_expect(int(playfield_perf.get("checker_texture_cache_count", 0)) >= 3, "Stage 3 playfield prewarm should cache checker textures for all emotional phases")
	_expect(int(playfield_perf.get("border_texture_cache_count", 0)) >= 3, "Stage 3 playfield prewarm should cache border textures for all emotional phases")
	_expect(int(playfield_perf.get("ellipse_points_cache_count", 0)) > 0, "Stage 3 playfield prewarm should cache stadium emblem ellipse geometry")
	_expect(int(playfield_perf.get("heart_particle_limit", 99)) <= 8, "Stage 3 playfield heart particles should stay within the draw budget")
	_expect(int(playfield_perf.get("stadium_circle_segments", 99)) <= 16, "Stage 3 stadium rings should stay within the draw budget")
	_expect(int(playfield_perf.get("stadium_circle_segments", 0)) >= 16, "Stage 3 stadium rings should preserve a round silhouette")
	_expect(int(playfield_perf.get("stadium_inner_segments", 99)) <= 10, "Stage 3 stadium inner arcs should stay within the draw budget")
	_expect(int(playfield_perf.get("stadium_flow_arc_segments", 99)) <= 3, "Stage 3 stadium flow arcs should stay within the draw budget")
	_expect(int(playfield_perf.get("kuromi_shadow_layers", 99)) <= 2, "Stage 3 Kuromi shadow layers should stay within the draw budget")
	_expect(int(playfield_perf.get("kuromi_face_layer_count", 99)) <= 2, "Stage 3 Kuromi face layers should stay within the draw budget")
	_expect(int(playfield_perf.get("kuromi_ear_layer_count", 99)) <= 2, "Stage 3 Kuromi ear layers should stay within the draw budget")
	_expect(int(playfield_perf.get("kuromi_tongue_point_max", 99)) <= 20, "Stage 3 Kuromi tongue draw points should stay within the draw budget")
	_expect(int(playfield_perf.get("kuromi_idle_tail_point_count", 99)) <= 8, "Stage 3 Kuromi idle tail draw points should stay within the draw budget")
	_expect(int(playfield_perf.get("kuromi_petrified_tail_point_count", 99)) <= 4, "Stage 3 Kuromi petrified tail draw points should stay within the draw budget")
	_expect(int(playfield_perf.get("kuromi_awakening_ring_segments", 99)) <= 18, "Stage 3 Kuromi awakening ring should stay within the draw budget")
	_expect(int(playfield_perf.get("kuromi_awakening_crack_line_count", 99)) <= 3, "Stage 3 Kuromi awakening cracks should stay within the draw budget")
	_expect(int(playfield_perf.get("kuromi_spit_warning_mark_count", 99)) <= 4, "Stage 3 Kuromi spit warning marks should stay within the draw budget")
	_expect(float(playfield_perf.get("kuromi_spit_warning_line_length", 0.0)) >= 160.0, "Stage 3 Kuromi spit direction warning should project far enough to read")
	_expect(float(playfield_perf.get("kuromi_spit_warning_core_width", 0.0)) >= 3.0, "Stage 3 Kuromi spit direction warning should keep a clear bright core")
	_expect(bool(playfield_perf.get("kuromi_spit_warning_contrast_stroke", false)), "Stage 3 Kuromi spit direction warning should use a contrast stroke")
	_expect(int(playfield_perf.get("kuromi_crack_particle_draw_limit", 999)) <= 36, "Stage 3 Kuromi crack particles should cap per-frame drawing")
	_expect(int(playfield_perf.get("kuromi_crack_particle_detailed_draw_limit", 999)) <= 10, "Stage 3 Kuromi crack particles should cap detailed polygon drawing")
	_expect(bool(playfield_perf.get("kuromi_crack_particle_polygon_guard", false)), "Stage 3 Kuromi crack fragments should guard against degenerate polygon fills")
	_verify_kuromi_fragment_polygon_stability(direct_playfield)
	_expect(bool(playfield_perf.get("viper_airborne_lod_supported", false)), "Stage 3 playfield should expose shared Viper airborne LOD support")
	_expect(bool(playfield_perf.get("shared_render_quality_lod_supported", false)), "Stage 3 playfield should expose shared render-quality LOD support")
	_expect(int(playfield_perf.get("stadium_circle_segments_severe_lod", 0)) >= 16, "Stage 3 stadium rings should preserve a round silhouette in severe Viper LOD")
	_expect(int(playfield_perf.get("stadium_dash_length_severe_lod", 0)) >= 48, "Stage 3 stadium should stretch severe Viper LOD dash spans")
	_expect(int(playfield_perf.get("stadium_gap_length_severe_lod", 0)) >= 54, "Stage 3 stadium should stretch severe Viper LOD dash gaps")
	_expect(bool(playfield_perf.get("stadium_severe_lod_skips_inner_arc", false)), "Stage 3 stadium should skip decorative inner arcs in severe Viper LOD")
	_expect(bool(playfield_perf.get("stadium_severe_lod_skips_flow", false)), "Stage 3 stadium should skip decorative electric flow in severe Viper LOD")
	_expect(int(playfield_perf.get("kuromi_tongue_point_max_severe_lod", 999)) <= 10, "Stage 3 Kuromi tongue should use a severe Viper LOD point cap")
	_expect(int(playfield_perf.get("kuromi_crack_particle_draw_limit_lod", 999)) <= 22, "Stage 3 Kuromi crack particles should tighten during airborne LOD")
	_expect(int(playfield_perf.get("kuromi_crack_particle_draw_limit_severe_lod", 999)) <= 10, "Stage 3 Kuromi crack particles should use a severe Viper cap")
	_expect(int(playfield_perf.get("kuromi_crack_particle_detailed_draw_limit_severe_lod", 999)) <= 2, "Stage 3 Kuromi crack particles should use a severe Viper detailed-polygon cap")
	var glide_context := {
		"selected_character_type": "viper",
		"viper_jetpack_airborne": true,
		"viper_jetpack_active": false,
		"current_msec": 5000,
	}
	ViperAirborneLod.reset_cache_for_test()
	ViperAirborneLod.effect_scale(glide_context)
	glide_context["current_msec"] = 5000 + ViperAirborneLod.GLIDE_SEVERE_ENTER_MSEC
	var glide_quality: float = direct_playfield._get_playfield_quality_scale(glide_context)
	_expect(is_equal_approx(glide_quality, ViperAirborneLod.GLIDE_EFFECT_SCALE), "Stage 3 playfield should use shared Viper glide hysteresis")
	_expect(
		direct_playfield._get_lod_count(
			Stage3PlayfieldRenderer.KUROMI_CRACK_PARTICLE_DRAW_LIMIT,
			Stage3PlayfieldRenderer.KUROMI_CRACK_PARTICLE_DRAW_LIMIT_LOD,
			Stage3PlayfieldRenderer.KUROMI_CRACK_PARTICLE_DRAW_LIMIT_SEVERE_LOD,
			glide_quality
		) == Stage3PlayfieldRenderer.KUROMI_CRACK_PARTICLE_DRAW_LIMIT_SEVERE_LOD,
		"Stage 3 playfield should use severe crack-particle caps after glide hysteresis enters"
	)
	ViperAirborneLod.reset_cache_for_test()
	var old_max_fps: int = int(Engine.get("max_fps"))
	Engine.set("max_fps", BattleRenderQuality.FPS_CAP_LOD_MAX_FPS)
	BattleRenderQuality.reset_cache_for_test()
	var capped_quality: float = direct_playfield._get_playfield_quality_scale({"selected_character_type": "soldier"})
	_expect(
		is_equal_approx(capped_quality, BattleRenderQuality.FPS_CAP_EFFECT_SCALE),
		"Stage 3 Soldier playfield should honor shared 72 FPS-cap render LOD"
	)
	_expect(
		direct_playfield._get_lod_count(
			Stage3PlayfieldRenderer.KUROMI_CRACK_PARTICLE_DRAW_LIMIT,
			Stage3PlayfieldRenderer.KUROMI_CRACK_PARTICLE_DRAW_LIMIT_LOD,
			Stage3PlayfieldRenderer.KUROMI_CRACK_PARTICLE_DRAW_LIMIT_SEVERE_LOD,
			capped_quality
		) == Stage3PlayfieldRenderer.KUROMI_CRACK_PARTICLE_DRAW_LIMIT_SEVERE_LOD,
		"Stage 3 shared FPS-cap quality should reduce crack-particle drawing for Soldier too"
	)
	Engine.set("max_fps", old_max_fps)
	BattleRenderQuality.reset_cache_for_test()
	_expect(Stage3ActorRenderer.new().has_method("draw"), "Stage 3 actor renderer preload should parse")
	var stage3_actor_source := FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_actor_renderer.gd")
	_expect(stage3_actor_source.find("_prewarm_renderer_step(skill_effect_renderer)") >= 0, "Stage 3 actor prewarm should stage skill-effect assets")
	_expect(stage3_actor_source.find("_prewarm_renderer_step(commando_firearm_renderer)") >= 0, "Stage 3 actor prewarm should stage Commando firearm assets")
	_expect(stage3_actor_source.find("commando_firearm_renderer.prewarm_assets()") < 0, "Stage 3 actor prewarm should not monolithically warm Commando firearm assets")
	var stage3_playfield_source := FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_playfield_renderer.gd")
	_expect(stage3_playfield_source.find("BattleRenderQuality.effect_scale(context)") >= 0, "Stage 3 playfield should route LOD through shared render quality")
	var stage3_pillar_bg_source := FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_pillar_background.gd")
	_expect(stage3_pillar_bg_source.find("BattleRenderQuality.effect_scale(context)") >= 0, "Stage 3 pillar background should route LOD through shared render quality")
	var staged_boss_renderer: Object = Stage3MenheraBossActorRenderer.new()
	_expect(staged_boss_renderer.has_method("prewarm_assets_step"), "Stage 3 Menhera boss renderer should expose staged prewarm")
	var boss_prewarm_steps := 0
	while boss_prewarm_steps < 16:
		boss_prewarm_steps += 1
		if bool(staged_boss_renderer.prewarm_assets_step()):
			break
	_expect(boss_prewarm_steps == MENHERA_BOSS_SHEET_PATHS.size(), "Stage 3 Menhera boss prewarm should advance one sheet per staged step")
	var direct_boss_renderer: Object = Stage3MenheraBossActorRenderer.new()
	direct_boss_renderer.prewarm_assets()
	var boss_asset_status: Dictionary = direct_boss_renderer.get_asset_status()
	_expect(bool(boss_asset_status.get("walk", false)), "Stage 3 Menhera walk sheet should be available to the boss renderer")
	_expect(bool(boss_asset_status.get("attack", false)), "Stage 3 Menhera attack sheet should be available to the boss renderer")
	_expect(bool(boss_asset_status.get("dash", false)), "Stage 3 Menhera dash sheet should be available to the boss renderer")
	_expect(bool(boss_asset_status.get("turn", false)), "Stage 3 Menhera turn sheet should be available to the boss renderer")
	_expect(bool(boss_asset_status.get("victory", false)), "Stage 3 Menhera victory sheet should be available to the boss renderer")
	_expect(bool(boss_asset_status.get("defeat", false)), "Stage 3 Menhera defeat sheet should be available to the boss renderer")
	_expect(int(boss_asset_status.get("walk_frame_count", 0)) == 8, "Stage 3 Menhera walk sheet should slice into eight frames")
	_expect(bool(boss_asset_status.get("shared_render_quality_lod_supported", false)), "Stage 3 Menhera boss renderer should expose shared render-quality LOD support")
	var boss_source := FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_menhera_boss_actor_renderer.gd")
	_expect(boss_source.find("BattleRenderQuality.effect_scale(context)") >= 0, "Stage 3 Menhera boss renderer should honor shared render-quality LOD")
	var direct_skill_state: Object = Stage3BossSkillState.new()
	var skill_context := _stage3_runtime_context()
	skill_context["player_score"] = 0
	var initial_skill_snapshot: Dictionary = direct_skill_state.get_snapshot()
	_expect(abs(float(initial_skill_snapshot.get("psycho_cooldown", 0.0)) - 70.0) <= 0.001, "Stage 3 psycho ball should start on a 70-second hit-trigger cooldown")
	_expect(abs(float(initial_skill_snapshot.get("tears_cooldown", 0.0)) - 25.0) <= 0.001, "Stage 3 tear shower should start on a 25-second auto cooldown")
	_expect(abs(float(initial_skill_snapshot.get("curse_cooldown", 0.0)) - 35.0) <= 0.001, "Stage 3 curse chest should start on a 35-second auto cooldown")
	var initial_hud_context: Dictionary = direct_skill_state.get_hud_context(null, skill_context)
	_expect(not bool(initial_hud_context.get("stage3_boss_skill_hud_show_boss_gauge", true)), "Stage 3 cooldown skill HUD should suppress the old boss-gauge wand")
	var cooldown_total_by_id := {}
	var trigger_type_by_id := {}
	var menhera_skill_card_count := 0
	for skill in _as_array(initial_hud_context.get("stage3_boss_skill_hud_skills", [])):
		if not (skill is Dictionary):
			continue
		menhera_skill_card_count += 1
		_expect(str(skill.get("id", "")) != "kuromi_tail_whip", "Stage 3 Menhera skill HUD should not expose Kuromi as a skill card")
		cooldown_total_by_id[str(skill.get("id", ""))] = float(skill.get("cooldown_total", 0.0))
		trigger_type_by_id[str(skill.get("id", ""))] = str(skill.get("trigger_type", ""))
	_expect(menhera_skill_card_count == 3, "Stage 3 Menhera skill HUD should expose only the three Menhera Girl skill cards")
	_expect(str(trigger_type_by_id.get("psycho_ball", "")) == "hit", "Stage 3 psycho ball HUD card should advertise hit-trigger timing")
	_expect(str(trigger_type_by_id.get("tear_shower", "")) == "auto", "Stage 3 tear shower HUD card should advertise automatic trigger timing")
	_expect(str(trigger_type_by_id.get("curse_chest", "")) == "auto", "Stage 3 curse chest HUD card should advertise automatic trigger timing")
	_expect(abs(float(cooldown_total_by_id.get("psycho_ball", 0.0)) - 70.0) <= 0.001, "Stage 3 psycho ball HUD card should expose a 70-second cooldown")
	_expect(abs(float(cooldown_total_by_id.get("tear_shower", 0.0)) - 25.0) <= 0.001, "Stage 3 tear shower HUD card should expose a 25-second cooldown")
	_expect(abs(float(cooldown_total_by_id.get("curse_chest", 0.0)) - 35.0) <= 0.001, "Stage 3 curse chest HUD card should expose a 35-second cooldown")
	for _idx in range(10):
		var hit_result: Dictionary = direct_skill_state.register_boss_hit(Vector2(0.0, -8.0), skill_context)
		_expect(abs(float(hit_result.get("stage3_boss_gauge_gain", 0.0))) <= 0.001, "Stage 3 cooldown skills should ignore boss paddle-hit gauge gain")
	direct_skill_state.update(1.0 / 60.0, skill_context, {})
	_expect(abs(float(direct_skill_state.get_snapshot().get("boss_special_gauge", 0.0))) <= 0.001, "Stage 3 cooldown skills should keep the old hit gauge disabled")
	direct_skill_state.set("psycho_cooldown", 0.0)
	direct_skill_state.update(1.0 / 60.0, skill_context, {})
	_expect(not bool(direct_skill_state.get_snapshot().get("stage3_emotional_overdrive_active", false)), "Stage 3 psycho ball should wait for a boss hit after its cooldown fills")
	var psycho_hit_result: Dictionary = direct_skill_state.register_boss_hit(Vector2(0.0, -8.0), skill_context)
	_expect(bool(psycho_hit_result.get("stage3_psychoball_hit_triggered", false)), "Stage 3 psycho ball should trigger on the next boss hit once ready")
	_expect(bool(direct_skill_state.get_snapshot().get("stage3_psychoball_hitstop_active", false)), "Stage 3 psycho ball should expose hitstop during hit-trigger activation")
	_expect(abs(float(direct_skill_state.get_snapshot().get("psycho_cooldown", 0.0)) - 70.0) <= 0.001, "Stage 3 psycho ball cooldown should reset to 70 seconds after casting")
	direct_skill_state.set("psychoball_hitstop_timer", 0.0)
	var skill_result: Dictionary = direct_skill_state.update(1.0 / 60.0, skill_context, {})
	_expect(skill_result.has("ball_vel"), "Stage 3 psycho ball should hand modified ball velocity back to the runtime")
	var tears_state: Object = Stage3BossSkillState.new()
	tears_state.set("psycho_cooldown", 10.0)
	tears_state.set("tears_cooldown", 0.0)
	tears_state.set("curse_cooldown", 10.0)
	tears_state.update(1.0 / 60.0, skill_context, {})
	var tears_snapshot: Dictionary = tears_state.get_snapshot()
	_expect(bool(tears_snapshot.get("stage3_tears_active", false)), "Stage 3 tear shower should auto-trigger from its cooldown")
	_expect(abs(float(tears_snapshot.get("tears_cooldown", 0.0)) - 25.0) <= 0.001, "Stage 3 tear shower cooldown should reset to 25 seconds")
	var curse_state: Object = Stage3BossSkillState.new()
	curse_state.set("psycho_cooldown", 10.0)
	curse_state.set("tears_cooldown", 10.0)
	curse_state.set("curse_cooldown", 0.0)
	curse_state.update(1.0 / 60.0, skill_context, {})
	var curse_snapshot: Dictionary = curse_state.get_snapshot()
	_expect(str(curse_snapshot.get("stage3_curse_chest_phase", "")) == "windup", "Stage 3 curse chest should auto-trigger from its cooldown")
	_expect(abs(float(curse_snapshot.get("curse_cooldown", 0.0)) - 35.0) <= 0.001, "Stage 3 curse chest cooldown should reset to 35 seconds")
	var awakening_state: Object = Stage3BossSkillState.new()
	awakening_state.handle_score_event("player", {"player_score": 2, "boss_score": 0}, {})
	var awakening_snapshot: Dictionary = awakening_state.get_snapshot()
	_expect(bool(awakening_snapshot.get("stage3_kuromi_awakening", false)), "Stage 3 Kuromi should start awakening when the player reaches two points")
	_expect(bool(awakening_snapshot.get("stage3_kuromi_petrified", false)), "Stage 3 Kuromi should stay petrified during the awakening windup")
	_expect(not bool(awakening_snapshot.get("stage3_kuromi_awakened", false)), "Stage 3 Kuromi should not be marked awake until the awakening animation ends")
	var awakening_context := _stage3_runtime_context()
	for _idx in range(181):
		awakening_state.update(1.0 / 60.0, awakening_context, {})
	awakening_snapshot = awakening_state.get_snapshot()
	_expect(not bool(awakening_snapshot.get("stage3_kuromi_awakening", false)), "Stage 3 Kuromi awakening should finish after the three second event")
	_expect(not bool(awakening_snapshot.get("stage3_kuromi_petrified", true)), "Stage 3 Kuromi should leave the petrified state after the event")
	_expect(bool(awakening_snapshot.get("stage3_kuromi_awakened", false)), "Stage 3 Kuromi should be awake after the event")
	_expect(_as_array(awakening_snapshot.get("stage3_kuromi_crack_particles", [])).size() > 0, "Stage 3 Kuromi awakening should spawn stone fragments")
	var awakening_budget_state: Object = Stage3BossSkillState.new()
	awakening_budget_state.handle_score_event("player", {"player_score": 2, "boss_score": 0}, {})
	awakening_budget_state.set("kuromi_awakening_timer", 1.0 / 60.0)
	awakening_budget_state.update(1.0 / 60.0, awakening_context, {})
	var first_fragment_batch: Array = _as_array(awakening_budget_state.get_snapshot().get("stage3_kuromi_crack_particles", []))
	_expect(first_fragment_batch.size() > 0 and first_fragment_batch.size() <= 16, "Stage 3 Kuromi awakening fragments should be spawned in a frame-budgeted first batch")
	var eating_state: Object = Stage3BossSkillState.new()
	eating_state.force_kuromi_awake()
	eating_state.set("kuromi_eating_active", true)
	eating_state.set("kuromi_eating_timer", 0.0)
	eating_state.set("kuromi_eat_source_pos", Vector2(350.0, 360.0))
	eating_state.set("kuromi_ball_tongue_pos", Vector2(350.0, 360.0))
	eating_state.set("kuromi_ball_on_tongue", true)
	var eating_result: Dictionary = eating_state.update(1.0 / 60.0, skill_context, {})
	var eating_snapshot: Dictionary = eating_state.get_snapshot()
	_expect(bool(eating_result.get("stage3_kuromi_ball_hidden", false)), "Stage 3 Kuromi eating should hide the live ball while the original eat animation is active")
	_expect(bool(eating_snapshot.get("stage3_kuromi_eating_active", false)), "Stage 3 Kuromi eating state should stay active during tongue and chewing phases")
	_expect(float(eating_snapshot.get("stage3_kuromi_mouth_open", 0.0)) > 0.0, "Stage 3 Kuromi eating should expose original mouth-open animation data")
	_expect(float(eating_snapshot.get("stage3_kuromi_tongue_extended", 0.0)) > 0.0, "Stage 3 Kuromi eating should expose original tongue-extension animation data")
	eating_state.set("kuromi_eating_timer", 189.0)
	eating_state.set("kuromi_has_spit_angle", true)
	eating_state.set("kuromi_spit_angle", -PI / 4.0)
	var chaos_runtime := FakeChaosRuntime.new()
	var eating_release_context: Dictionary = skill_context.duplicate(true)
	eating_release_context["skip_ball_motion_step"] = true
	eating_result = eating_state.update(1.0 / 60.0, eating_release_context, {"viper_skill_runtime": chaos_runtime})
	_expect(not bool(eating_result.get("stage3_kuromi_ball_hidden", true)), "Stage 3 Kuromi should reveal the ball after the 190-frame eat sequence")
	_expect(_as_vector2(eating_result.get("ball_pos", Vector2.ZERO), Vector2.ZERO).distance_to(Vector2(380.0, 375.0)) <= 0.001, "Stage 3 Kuromi should spit the ball from the original center point")
	var spit_velocity: Vector2 = _as_vector2(eating_result.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	_expect(spit_velocity.length() >= 24.0 and spit_velocity.length() <= 36.0, "Stage 3 Kuromi spit velocity should use the original 8-12 speed tripled range")
	_expect(absf(spit_velocity.angle()) >= PI * 0.083, "Stage 3 Kuromi spit angle should keep the original horizontal exclusion")
	_expect(not bool(eating_result.get("skip_ball_motion_step", true)), "Stage 3 Kuromi spit should clear stale held-ball motion skip")
	_expect(chaos_runtime.release_count == 1, "Stage 3 Kuromi spit should release overlapping Chaos Spear ball ownership")
	_expect(_as_vector2(chaos_runtime.last_release_context.get("ball_vel", Vector2.ZERO), Vector2.ZERO).length() > 0.0, "Stage 3 Kuromi should pass the spit velocity to the Chaos Spear release hook")
	_expect(float(eating_result.get("ball_impact_boost", 0.0)) == 1.0, "Stage 3 Kuromi spit should reset impact boost like the original ball release")
	var hidden_ball_draw: Dictionary = BattleDrawBallContext.new().build_draw({
		"ball_active": true,
		"stage3_kuromi_ball_hidden": true,
		"ball_pos": Vector2(380.0, 375.0),
		"shake_offset": Vector2.ZERO,
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_width": 155.0,
		"player_y": 700.0,
		"ball_render_radius": 26.0,
	}, {})
	_expect(not bool(hidden_ball_draw.get("should_draw", true)), "Stage 3 Kuromi eating should suppress the normal ball renderer")
	var tail_state: Object = Stage3BossSkillState.new()
	tail_state.force_kuromi_awake()
	tail_state.set("kuromi_eating_cooldown", 10.0)
	tail_state.set("tail_whip_active", true)
	tail_state.set("tail_whip_timer", 0.5)
	tail_state.set("tail_whip_target", Vector2(390.0, 375.0))
	tail_state.set("tail_has_target", true)
	var tail_context := _stage3_runtime_context()
	tail_context["ball_pos"] = Vector2(390.0, 375.0)
	tail_context["ball_vel"] = Vector2(10.0, 0.0)
	var tail_result: Dictionary = tail_state.update(1.0 / 60.0, tail_context, {})
	var tail_snapshot: Dictionary = tail_state.get_snapshot()
	_expect(_as_array(tail_snapshot.get("stage3_tail_points", [])).size() == Stage3BossSkillState.TAIL_POINT_COUNT, "Stage 3 Kuromi tail should export the runtime whip curve budget")
	_expect(bool(tail_snapshot.get("stage3_tail_curve_active", false)), "Stage 3 Kuromi tail collision should arm the original curve-after-hit state")
	_expect(tail_result.has("ball_vel"), "Stage 3 Kuromi tail collision should hand back a redirected ball velocity")
	_expect(float(tail_result.get("ball_impact_boost", 0.0)) == 1.0, "Stage 3 Kuromi tail collision should reset impact boost like the Python reference")
	_expect(_as_array(tail_snapshot.get("stage3_tail_hit_bursts", [])).size() > 0, "Stage 3 Kuromi tail collision should export a Godot-native hit burst")
	_expect(_as_array(tail_snapshot.get("stage3_prism_particles", [])).size() >= Stage3BossSkillState.TAIL_HIT_PRISM_MIN_COUNT, "Stage 3 Kuromi tail hit should spawn the budgeted rainbow prism particle burst")
	var tail_starpoints: Array = _as_array(tail_snapshot.get("stage3_starpoint_drops", []))
	_expect(tail_starpoints.size() == 1, "Stage 3 Kuromi tail hit should drop one Menhera-tail starpoint like the Python reference")
	var tail_drop: Dictionary = tail_starpoints[0] if tail_starpoints[0] is Dictionary else {}
	_expect(str(tail_drop.get("source_type", "")) == "menhera_tail", "Stage 3 Kuromi tail starpoint should keep the original menhera_tail source tag")
	var tail_drop_pos: Vector2 = _as_vector2(tail_drop.get("pos", Vector2.ZERO), Vector2.ZERO)
	var fake_perk_state := FakeRuntimePerkState.new()
	var fake_audio := FakeStage3Audio.new()
	var fake_owner := FakeOwner.new()
	tail_context["owner"] = fake_owner
	tail_context["selected_character_type"] = "smasher"
	tail_context["player_pos"] = tail_drop_pos - Vector2(90.0, 90.0)
	tail_context["player_paddle_size"] = Vector2(180.0, 180.0)
	tail_state.update(0.0, tail_context, {
		"runtime_perk_state": fake_perk_state,
		"audio": fake_audio,
	})
	_expect(fake_perk_state.collected_star_points == 1, "Stage 3 Kuromi tail starpoint should grant one runtime star point on paddle contact")
	_expect(_as_array(tail_state.get_snapshot().get("stage3_starpoint_drops", [])).is_empty(), "collected Stage 3 Kuromi tail starpoint should be removed from the field")
	_expect(fake_audio.starpoint_collect_count == 1, "collecting a Stage 3 Kuromi tail starpoint should play the shared collect audio")
	_expect(fake_owner.redraw_count >= 1, "collecting a Stage 3 Kuromi tail starpoint should request redraw")
	var smoke_state: Object = Stage3BossSkillState.new()
	smoke_state.set("curse_phase", "open")
	smoke_state.set("curse_pos", Vector2(380.0, 710.0))
	var smoke_context := _stage3_runtime_context()
	smoke_context["player_score"] = 0
	for _idx in range(181):
		smoke_state.update(1.0 / 60.0, smoke_context, {})
	var smoke_particles: Array = _as_array(smoke_state.get_snapshot().get("stage3_curse_chest_smoke", []))
	_expect(smoke_particles.size() > 0, "Stage 3 curse chest should spawn pink smoke after dash-open")
	_expect(smoke_particles.size() <= 240, "Stage 3 curse chest smoke should stay under the draw-time particle cap")
	var reverse_state: Object = Stage3BossSkillState.new()
	reverse_state.set("curse_reverse_timer", 1.0)
	var reverse_snapshot: Dictionary = reverse_state.get_actor_draw_context()
	_expect(bool(reverse_snapshot.get("stage3_curse_reverse_active", false)), "Stage 3 curse reverse should expose active state for the player renderer")
	_expect(float(reverse_snapshot.get("stage3_curse_reverse_ratio", 0.0)) > 0.0, "Stage 3 curse reverse should expose remaining ratio for tint and head effect")
	var direct_skill_hud: Object = Stage3BossSkillHudRenderer.new()
	_expect(direct_skill_hud.has_method("draw"), "Stage 3 Menhera boss skill HUD renderer preload should parse")
	_expect(Stage3PillarSceneDrawer.new().has_method("draw"), "Stage 3 pillar scene drawer preload should parse")
	var tear_status_state: Object = StatusEffectState.new()
	var tear_skill_state: Object = Stage3BossSkillState.new()
	tear_skill_state.set("tears_active", true)
	tear_skill_state.set("tears_timer", 1.0)
	tear_skill_state.set("falling_tears", [{
		"x": 330.0,
		"y": 710.0,
		"prev_y": 710.0,
		"speed": 0.0,
	}])
	var tear_context := _stage3_runtime_context()
	tear_context["player_score"] = 0
	tear_skill_state.update(1.0 / 60.0, tear_context, {"status_effect_state": tear_status_state})
	var player_slow: Dictionary = tear_status_state.get_status("player", "slow")
	_expect(not player_slow.is_empty(), "Stage 3 tear shower hit should apply shared player slow")
	_expect(is_equal_approx(float(player_slow.get("remaining_frames", 0.0)), 130.0), "Stage 3 tear shower slow should last 130 frames")
	_expect(is_equal_approx(float(player_slow.get("multiplier", 0.0)), 0.80), "Stage 3 tear shower first hit should slow player by 20%")

	probe = Stage3DrawProbe.new()
	probe.background = background
	probe.actor_renderer = actor_renderer
	probe.skill_state = direct_skill_state
	probe.skill_hud_renderer = direct_skill_hud
	get_root().add_child(probe)
	probe.queue_redraw()


func _process(_delta: float) -> bool:
	frame_count += 1
	if frame_count < 2:
		return false
	_expect(probe.background_draw_count > 0, "Stage 3 pillar background should draw through CanvasItem")
	_expect(probe.background_draw_result, "Stage 3 original pillar background draw should return true")
	_expect(probe.actor_draw_count > 0, "Stage 3 playfield/actor renderer should draw through CanvasItem")
	_expect(probe.skill_hud_draw_count > 0, "Stage 3 Menhera boss skill HUD should draw through CanvasItem")
	print("stage3_map_port_smoke: ok")
	quit(0)
	return true


func _expect_stage3_asset(path: String, expected_size: Vector2, message: String) -> void:
	var texture: Texture2D = ProjectResourceLoader.load_texture(path)
	_expect(texture != null, message)
	_expect(texture.get_size() == expected_size, "%s with original source dimensions" % message)


func _verify_kuromi_fragment_polygon_stability(renderer: Object) -> void:
	var center := Vector2(380.0, 360.0)
	for seed in range(1, 161):
		for point_count in [5, 6, 7]:
			for size in [8.0, 12.0, 24.0]:
				var rotation: float = deg_to_rad(float((seed * 17) % 360))
				var points: PackedVector2Array = renderer._build_kuromi_stone_fragment_points(
					center,
					float(size),
					int(seed),
					rotation,
					int(point_count)
				)
				_expect(
					not Geometry2D.triangulate_polygon(points).is_empty(),
					"Stage 3 Kuromi fragment polygon should stay triangulable"
				)
				var highlight_count: int = max(3, floori(float(points.size()) / 3.0))
				var highlight_points := PackedVector2Array()
				for idx in range(highlight_count):
					highlight_points.append(points[idx])
				_expect(
					not Geometry2D.triangulate_polygon(highlight_points).is_empty(),
					"Stage 3 Kuromi fragment highlight polygon should stay triangulable"
				)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _stage3_runtime_context() -> Dictionary:
	return {
		"current_stage": 3,
		"ball_active": true,
		"waiting_for_serve": false,
		"ball_pos": Vector2(380.0, 360.0),
		"ball_vel": Vector2(2.0, -8.0),
		"boss_pos": Vector2(320.0, 25.0),
		"boss_paddle_size": Vector2(110.0, 18.0),
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"player_score": 2,
	}
