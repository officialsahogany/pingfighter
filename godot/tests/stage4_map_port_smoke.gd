extends SceneTree

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const BallDependencyContext := preload("res://scripts/ball/ball_dependency_context.gd")
const BallFrameMotionController := preload("res://scripts/ball/ball_frame_motion_controller.gd")
const BallMotionStepper := preload("res://scripts/ball/ball_motion_stepper.gd")
const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const WallBounceController := preload("res://scripts/ball/wall_bounce_controller.gd")
const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleDrawSceneContext := preload("res://scripts/core/battle_draw_scene_context.gd")
const ImpactEffects := preload("res://scripts/effects/impact_effects.gd")
const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const GameplayLoopAudioCleanup := preload("res://scripts/audio/gameplay_loop_audio_cleanup.gd")
const StageLandingIntro := preload("res://scripts/core/stage_landing_intro.gd")
const StageRuntimeRouter := preload("res://scripts/stages/stage_runtime_router.gd")
const Stage4ActorRenderer := preload("res://scripts/stages/stage4/stage4_actor_renderer.gd")
const Stage4BirdEvent := preload("res://scripts/stages/stage4/stage4_bird_event.gd")
const Stage4BrazierMonkEvent := preload("res://scripts/stages/stage4/stage4_brazier_monk_event.gd")
const Stage4MapState := preload("res://scripts/stages/stage4/stage4_map_state.gd")
const Stage4MoonEvent := preload("res://scripts/stages/stage4/stage4_moon_event.gd")
const Stage4PillarBackground := preload("res://scripts/stages/stage4/stage4_pillar_background.gd")
const Stage4PillarSceneDrawer := preload("res://scripts/stages/stage4/stage4_pillar_scene_drawer.gd")
const Stage4PlayfieldRenderer := preload("res://scripts/stages/stage4/stage4_playfield_renderer.gd")
const Stage4PonkBossActorRenderer := preload("res://scripts/stages/stage4/stage4_ponk_boss_actor_renderer.gd")
const Stage4PonkBossSkillHudRenderer := preload("res://scripts/stages/stage4/stage4_ponk_boss_skill_hud_renderer.gd")
const Stage4PonkGaugeHudRenderer := preload("res://scripts/stages/stage4/stage4_ponk_gauge_hud_renderer.gd")
const Stage4PonkMagneticFxHost := preload("res://scripts/stages/stage4/stage4_ponk_magnetic_fx_host.gd")
const Stage4PonkMeditationFxHost := preload("res://scripts/stages/stage4/stage4_ponk_meditation_fx_host.gd")
const Stage4PonkSkillState := preload("res://scripts/stages/stage4/stage4_ponk_skill_state.gd")
const Stage4TempleDestructionEvent := preload("res://scripts/stages/stage4/stage4_temple_destruction_event.gd")
const StatusEffectState := preload("res://scripts/status/status_effect_state.gd")

const STAGE4_IMAGE_ASSETS := [
	{"path": "res://assets/sprites/hud/stage4_center_background_base_imagegen_v2.png", "size": Vector2(760.0, 750.0)},
	{"path": "res://assets/sprites/hud/stage4_center_thin_border_imagegen_v1.png", "size": Vector2(760.0, 750.0)},
	{"path": "res://assets/sprites/hud/stage4_center_temple_building_imagegen_v4.png", "size": Vector2(1254.0, 1254.0)},
	{"path": "res://assets/sprites/hud/stage4_center_ambient_sprites_imagegen_v3.png", "size": Vector2(1772.0, 886.0)},
	{"path": "res://assets/sprites/hud/stage4_floating_temple_aura_sheet_imagegen_v1.png", "size": Vector2(256.0, 256.0)},
	{"path": "res://assets/sprites/hud/stage4_temple_explosion_sheet_imagegen_v2.png", "size": Vector2(2504.0, 2504.0)},
	{"path": "res://assets/sprites/hud/stage4_temple_explosion_sheet_imagegen_v2_native.png", "size": Vector2(1252.0, 1252.0)},
	{"path": "res://assets/sprites/hud/stage4_temple_debris_sprites_imagegen_v1.png", "size": Vector2(384.0, 384.0)},
	{"path": "res://assets/sprites/hud/stage4_star_bird_flight_sheet_imagegen_v1.png", "size": Vector2(512.0, 128.0)},
	{"path": "res://assets/sprites/hud/stage4_red_moon_fragment_atlas_imagegen_v1.png", "size": Vector2(1254.0, 1254.0)},
	{"path": "res://assets/sprites/hud/stage4_landing_zoom_background_imagegen_v1.png", "size": Vector2(1254.0, 1254.0)},
	{"path": "res://assets/sprites/hud/stage4_empty_temple_nightsky_base_imagegen_v3.png", "size": Vector2(1659.0, 948.0)},
	{"path": "res://assets/sprites/hud/stage4_empty_temple_nightsky_base_imagegen_v4_nomoon.png", "size": Vector2(1659.0, 948.0)},
	{"path": "res://assets/sprites/hud/stage4_moon_white_idle_sheet_imagegen_v1.png", "size": Vector2(1770.0, 295.0)},
	{"path": "res://assets/sprites/hud/stage4_moon_red_transform_sheet_imagegen_v2.png", "size": Vector2(1770.0, 295.0)},
	{"path": "res://assets/sprites/hud/stage4_moon_red_burst_sheet_imagegen_v1.png", "size": Vector2(1770.0, 295.0)},
	{"path": "res://assets/sprites/hud/stage4_shaolin_cyber_temple_base_imagegen_v1.png", "size": Vector2(1659.0, 948.0)},
	{"path": "res://assets/sprites/hud/stage4_shaolin_cyber_temple_motion_sprites_imagegen_v1.png", "size": Vector2(1659.0, 948.0)},
	{"path": "res://assets/sprites/hud/stage4_tibetan_cyber_temple_base_imagegen_v2.png", "size": Vector2(1653.0, 951.0)},
	{"path": "res://assets/sprites/hud/stage4_tibetan_cyber_temple_motion_sprites_imagegen_v2.png", "size": Vector2(1659.0, 948.0)},
	{"path": "res://assets/sprites/hud/stage4_ponk_refraction_magnetic_field_skillcard_imagegen_v1.png", "size": Vector2(2016.0, 540.0)},
	{"path": "res://assets/sprites/hud/stage4_ponk_vipassana_meditation_skillcard_imagegen_v1.png", "size": Vector2(2016.0, 540.0)},
	{"path": "res://assets/sprites/stage4/stage4_ponk_refraction_magnetic_field_sheet_imagegen_v3_soft.png", "size": Vector2(2048.0, 2048.0)},
	{"path": "res://assets/sprites/stage4/temple_ghost_walk_left.png", "size": Vector2(1376.0, 768.0)},
	{"path": "res://assets/sprites/stage4/temple_ghost_walk_right.png", "size": Vector2(1376.0, 768.0)},
	{"path": "res://assets/sprites/stage4/temple_ghost_attack.png", "size": Vector2(1376.0, 768.0)},
	{"path": "res://assets/sprites/stage4/effects/stage4_ponk_magnetic_lattice_imagegen_v1.png", "size": Vector2(1024.0, 1024.0)},
	{"path": "res://assets/sprites/stage4/effects/stage4_ponk_magnetic_prism_shard_imagegen_v1.png", "size": Vector2(1024.0, 1024.0)},
	{"path": "res://assets/sprites/stage4/effects/stage4_ponk_magnetic_arc_ribbon_imagegen_v1.png", "size": Vector2(1024.0, 1024.0)},
	{"path": "res://assets/sprites/stage4/effects/stage4_ponk_magnetic_collapse_burst_imagegen_v1.png", "size": Vector2(1024.0, 1024.0)},
	{"path": "res://assets/sprites/stage4/effects/stage4_ponk_magnetic_projectile_orb_imagegen_v1.png", "size": Vector2(1024.0, 1024.0)},
	{"path": "res://assets/sprites/stage4/effects/stage4_ponk_magnetic_projectile_trail_imagegen_v1.png", "size": Vector2(1024.0, 1024.0)},
	{"path": "res://assets/sprites/stage4/effects/stage4_ponk_meditation_mandala_imagegen_v1.png", "size": Vector2(1024.0, 1024.0)},
	{"path": "res://assets/sprites/stage4/effects/stage4_ponk_meditation_lotus_petal_imagegen_v1.png", "size": Vector2(1024.0, 1024.0)},
	{"path": "res://assets/sprites/stage4/effects/stage4_ponk_meditation_sutra_shard_imagegen_v1.png", "size": Vector2(1024.0, 1024.0)},
]

const STAGE4_AUDIO_PATHS := [
	"res://assets/bgm/stage4bgm.ogg",
	"res://assets/bgm/stage4bgm-phase2.mp3",
	"res://assets/sounds/stage4moonshoot.wav",
	"res://assets/sounds/stage4moonshoot2.wav",
	"res://assets/sounds/stage4hitting.wav",
	"res://assets/sounds/birdkill.wav",
	"res://assets/sounds/magnetic.wav",
	"res://assets/sounds/ponkmeditation.wav",
	"res://assets/sounds/meditationafter.wav",
]


class FakeStage4Audio:
	var phase2_bgm_count := 0
	var moon_shoot_count := 0
	var fragment_shoot_count := 0
	var temple_hit_count := 0
	var birdkill_count := 0
	var starpoint_collect_count := 0
	var magnetic_loop_count := 0
	var stop_magnetic_count := 0
	var sync_magnetic_active_count := 0
	var meditation_count := 0
	var meditation_after_count := 0
	var wall_hit_count := 0
	var dash_count := 0

	func play_bgm(name: String) -> bool:
		if name == "stage4_phase2":
			phase2_bgm_count += 1
		return true

	func play_stage4_phase2_bgm() -> bool:
		phase2_bgm_count += 1
		return true

	func play_stage4_moon_shoot() -> void:
		moon_shoot_count += 1

	func play_stage4_fragment_shoot() -> void:
		fragment_shoot_count += 1

	func play_stage4_temple_hit() -> void:
		temple_hit_count += 1

	func play_stage4_birdkill() -> void:
		birdkill_count += 1

	func play_starpoint_collect() -> void:
		starpoint_collect_count += 1

	func play_stage4_magnetic_loop() -> void:
		magnetic_loop_count += 1

	func sync_stage4_magnetic_loop(active: bool) -> void:
		if active:
			sync_magnetic_active_count += 1
		else:
			stop_stage4_magnetic_loop()

	func play_stage4_meditation() -> void:
		meditation_count += 1

	func play_stage4_meditation_after() -> void:
		meditation_after_count += 1

	func play_wall_hit(_impact_speed: float = 0.0, _source_x: float = 380.0) -> void:
		wall_hit_count += 1

	func play_dash() -> void:
		dash_count += 1

	func stop_stage4_magnetic_loop() -> void:
		stop_magnetic_count += 1


class FakeBallPhysics:
	func enforce_minimum_rally_speed(velocity: Vector2) -> Vector2:
		return velocity

	func get_minimum_effective_boost(_velocity: Vector2) -> float:
		return 1.0


class FakeRuntimePerkState:
	var collected_star_points := 0

	func collect_star_points(amount: int, _character_type: String, _catalog: Object = null, _owner: Object = null, _registry: Object = null) -> bool:
		collected_star_points += max(0, amount)
		return true


class FakeStage4MovementState:
	var knockback_count := 0
	var last_knockback_vel := 0.0

	func start_knockback(velocity: float, _frames: float = 0.0, _decay: float = 1.0, _force: bool = false, _stage_event: bool = false) -> bool:
		knockback_count += 1
		last_knockback_vel = velocity
		return true


class FakeStage4BossAiState:
	var knockback_count := 0
	var last_knockback_vel := 0.0

	func start_paddle_hit_knockback(velocity: float, _frames: float = 0.0, _decay: float = 1.0, _force: bool = false) -> bool:
		knockback_count += 1
		last_knockback_vel = velocity
		return true


class FakeStage4DashState:
	var active := false

	func is_active() -> bool:
		return active

	func get_snapshot() -> Dictionary:
		return {"active": active}


class FakeStage4BallEffects:
	var hit_pulse_count := 0

	func register_hit_pulse(_pos: Vector2, _vel: Vector2, _strength: float = 0.0, _kind: String = "") -> void:
		hit_pulse_count += 1


class FakeStage4Owner:
	extends RefCounted

	var current_stage := 4
	var player_pos := Vector2(320.0, 690.0)
	var boss_pos := Vector2(330.0, 55.0)
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var selected_character_type := "smasher"
	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1


class FakeStage4Registry:
	var instances: Dictionary = {}
	var requested_keys: Array[String] = []

	func _init(initial_instances: Dictionary = {}) -> void:
		instances = initial_instances

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		var value: Variant = instances.get(key, null)
		if typeof(value) == TYPE_OBJECT:
			return value as Object
		return null


class Stage4DrawProbe:
	extends Node2D

	var background: Object = null
	var actor_renderer: Object = null
	var gauge_renderer: Object = null
	var skill_card_renderer: Object = null
	var map_state: Object = null
	var destruction: Object = null
	var bird_event: Object = null
	var monk_event: Object = null
	var moon_event: Object = null
	var ponk_skill_state: Object = null
	var background_draw_count := 0
	var actor_draw_count := 0
	var gauge_draw_count := 0
	var skill_card_draw_count := 0
	var background_draw_result := false

	func _draw() -> void:
		var deps := {
			"current_stage": 4,
			"stage4_map_state": map_state,
			"stage4_temple_destruction_event": destruction,
			"stage4_bird_event": bird_event,
			"stage4_brazier_monk_event": monk_event,
			"stage4_moon_event": moon_event,
			"stage4_ponk_skill_state": ponk_skill_state,
		}
		var base_context := {
			"current_stage": 4,
			"width": 760.0,
			"height": 750.0,
			"view_size": Vector2(1280.0, 800.0),
			"game_offset": Vector2(260.0, 25.0),
			"game_size": Vector2(760.0, 750.0),
			"ball_pos": Vector2(380.0, 375.0),
			"player_pos": Vector2(300.0, 700.0),
			"player_paddle_size": Vector2(155.0, 50.0),
			"boss_pos": Vector2(318.0, 42.0),
			"boss_paddle_size": Vector2(124.0, 26.0),
			"boss_hitbox_height": 46.0,
			"stage4_ponk_gauge_visible": true,
			"stage4_ponk_gauge_value": 180.0,
			"stage4_ponk_gauge_max": 500.0,
		}
		if map_state != null and map_state.has_method("get_draw_context"):
			base_context.merge(map_state.get_draw_context(deps), true)
		if background != null:
			background.update(1.0 / 60.0, base_context, deps)
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
			actor_renderer.draw(self, base_context)
		if gauge_renderer != null:
			gauge_draw_count += 1
			var hud_context: Dictionary = base_context.duplicate(true)
			hud_context["stage4_ponk_gauge_active"] = true
			gauge_renderer.draw(self, hud_context)
		if skill_card_renderer != null and ponk_skill_state != null:
			skill_card_draw_count += 1
			var skill_hud_context: Dictionary = base_context.duplicate(true)
			skill_hud_context.merge(ponk_skill_state.get_skill_card_hud_context(null, skill_hud_context), true)
			skill_card_renderer.draw(self, skill_hud_context)


var probe: Stage4DrawProbe = null
var frame_count := 0


func _init() -> void:
	for asset in STAGE4_IMAGE_ASSETS:
		_expect_stage4_texture(str(asset["path"]), asset["size"])
	for path in STAGE4_AUDIO_PATHS:
		_expect(ProjectResourceLoader.load_audio_stream(str(path)) != null, "Stage 4 audio stream should load: %s" % str(path))
	var cleanup_audio := FakeStage4Audio.new()
	GameplayLoopAudioCleanup.stop_all(cleanup_audio)
	_expect(cleanup_audio.stop_magnetic_count == 1, "Stage 4 magnetic loop should be registered in shared gameplay loop cleanup")

	var router: Object = StageRuntimeRouter.new()
	_expect(str(router.get_module_key(4, "actor_renderer")) == "stage4_actor_renderer", "Stage 4 should route actor drawing to the Stage 4 actor renderer")
	_expect(str(router.get_module_key(4, "pillar_scene_drawer")) == "stage4_pillar_scene_drawer", "Stage 4 should route pillar drawing to the Stage 4 pillar scene drawer")
	_expect(str(router.get_module_key(4, "stage_background")) == "stage4_pillar_background", "Stage 4 should route stage background state to the Stage 4 pillar background")

	var registry: Object = GameplayModuleRegistry.new()
	var stage3_playfield_renderer: Object = registry.get_instance("stage3_playfield_renderer")
	_expect(stage3_playfield_renderer != null and stage3_playfield_renderer.has_method("prewarm_assets"), "Stage 3 playfield renderer should be registered for debug-picker reset compatibility")
	var actor_renderer: Object = registry.get_instance("stage4_actor_renderer")
	_expect(actor_renderer != null and actor_renderer.has_method("draw"), "Stage 4 actor renderer should be constructible from the module catalog")
	_expect(actor_renderer.has_method("prewarm_assets"), "Stage 4 actor renderer should expose prewarm_assets")
	actor_renderer.prewarm_assets()
	var actor_source := FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_actor_renderer.gd")
	_expect(
		actor_source.find("boss_renderer.draw") >= 0
		and actor_source.find("ponk_skill_renderer.draw") > actor_source.find("boss_renderer.draw"),
		"Stage 4 Ponk magnetic field should draw above the boss/player actor layer so it remains visible"
	)
	var actor_asset_status: Dictionary = actor_renderer.get_imagegen_asset_status()
	_expect(bool(actor_asset_status.get("center_background", false)), "Stage 4 center background should be available to the actor renderer")
	_expect(bool(actor_asset_status.get("temple_building", false)), "Stage 4 temple building should be available to the actor renderer")
	_expect(bool(actor_asset_status.get("ambient_atlas", false)), "Stage 4 ambient atlas should be available to the actor renderer")
	_expect(bool(actor_asset_status.get("aura_sheet", false)), "Stage 4 floating aura sheet should be available to the actor renderer")
	_expect(bool(actor_asset_status.get("explosion_sheet", false)), "Stage 4 temple explosion sheet should be available to the actor renderer")
	_expect(bool(actor_asset_status.get("debris_atlas", false)), "Stage 4 debris atlas should be available to the actor renderer")
	_expect(bool(actor_asset_status.get("red_moon_fragment_atlas", false)), "Stage 4 red moon fragment atlas should be available to the actor renderer")
	_expect(bool(actor_asset_status.get("magnetic_field_sheet", false)), "Stage 4 Ponk magnetic field sheet should be available to the actor renderer")
	_expect(bool(actor_asset_status.get("magnetic_fx_shader_host_pipeline", false)), "Stage 4 Ponk magnetic field should expose its shader-backed FX host pipeline")
	_expect(bool(actor_asset_status.get("magnetic_fx_texture_pieces_ready", false)), "Stage 4 Ponk magnetic field should prewarm Claude's texture-piece layers")
	_expect(bool(actor_asset_status.get("magnetic_fx_lattice_png_slot", false)), "Stage 4 Ponk magnetic field should load Claude's lattice PNG slot")
	_expect(bool(actor_asset_status.get("magnetic_fx_prism_shard_png_slot", false)), "Stage 4 Ponk magnetic field should load Claude's prism-shard PNG slot")
	_expect(bool(actor_asset_status.get("magnetic_fx_arc_ribbon_png_slot", false)), "Stage 4 Ponk magnetic field should load Claude's arc-ribbon PNG slot")
	_expect(bool(actor_asset_status.get("magnetic_phase2_fx_texture_pieces_ready", false)), "Stage 4 Ponk magnetic projectile should prewarm Claude's Phase 2 texture-piece layers")
	_expect(bool(actor_asset_status.get("magnetic_fx_collapse_burst_png_slot", false)), "Stage 4 Ponk magnetic projectile should load Claude's collapse-burst PNG slot")
	_expect(bool(actor_asset_status.get("magnetic_fx_projectile_orb_png_slot", false)), "Stage 4 Ponk magnetic projectile should load Claude's projectile-orb PNG slot")
	_expect(bool(actor_asset_status.get("magnetic_fx_projectile_trail_png_slot", false)), "Stage 4 Ponk magnetic projectile should load Claude's projectile-trail PNG slot")
	_expect(bool(actor_asset_status.get("meditation_fx_shader_host_pipeline", false)), "Stage 4 Ponk meditation should expose its shader-backed FX host pipeline")
	_expect(bool(actor_asset_status.get("meditation_fx_mandala_png_slot", false)), "Stage 4 Ponk meditation should load Claude's mandala PNG slot")
	_expect(bool(actor_asset_status.get("meditation_fx_lotus_petal_png_slot", false)), "Stage 4 Ponk meditation should load Claude's lotus-petal PNG slot")
	_expect(bool(actor_asset_status.get("meditation_fx_sutra_shard_png_slot", false)), "Stage 4 Ponk meditation should load Claude's sutra-shard PNG slot")
	_expect(bool(actor_asset_status.get("ponk_boss_sheet", false)), "Stage 4 Ponk boss sprite sheet should be available to the actor renderer")
	_expect(not bool(actor_asset_status.get("ponk_boss_draws_legacy_paddle_with_sheet", true)), "Stage 4 Ponk boss sprite sheet should suppress the legacy rectangular paddle draw")
	_expect(bool(actor_asset_status.get("temple_ghost_sprite_runtime", false)), "Stage 4 temple ghost monk sheets should be available to the actor renderer")
	_expect(int(actor_asset_status.get("ambient_sprite_count", 0)) == 8, "Stage 4 ambient atlas should slice into eight source sprites")
	_expect(int(actor_asset_status.get("aura_frame_count", 0)) == 16, "Stage 4 aura sheet should slice into sixteen frames")
	_expect(int(actor_asset_status.get("explosion_frame_count", 0)) == 16, "Stage 4 explosion sheet should slice into sixteen frames")
	_expect(int(actor_asset_status.get("red_moon_fragment_frame_count", 0)) == 16, "Stage 4 red moon fragment atlas should slice into sixteen frames")
	_expect(bool(actor_asset_status.get("center_border_texture", false)), "Stage 4 playfield should prewarm the imagegen thin center border")
	_expect(bool(actor_asset_status.get("center_border_draw_enabled", false)), "Stage 4 playfield should draw the center background border")
	_expect(float(actor_asset_status.get("center_border_thickness", 99.0)) <= 2.0, "Stage 4 center background border should stay thin like the Stage 1/2 treatment")
	_expect(bool(actor_asset_status.get("wall_contact_flash_enabled", false)), "Stage 4 playfield should enable wall-hit border flashes")
	_expect(float(actor_asset_status.get("wall_contact_flash_duration_sec", 0.0)) > 0.0, "Stage 4 wall-hit border flash should expose a visible timer")
	_expect(int(actor_asset_status.get("magnetic_field_frame_count", 0)) == 16, "Stage 4 Ponk magnetic field sheet should slice into sixteen frames")
	_expect(int(actor_asset_status.get("magnetic_fx_shader_layers", 0)) >= 5, "Stage 4 Ponk magnetic field should expose lattice, arc, collapse, orb, and trail shader layers")
	_expect(int(actor_asset_status.get("magnetic_fx_gpu_particle_layers", 0)) >= 1, "Stage 4 Ponk magnetic field should expose prism shard GPU particles")
	_expect(int(actor_asset_status.get("meditation_fx_gpu_particle_layers", 0)) >= 3, "Stage 4 Ponk meditation should expose mote, petal, and release GPU particle layers")
	_expect(bool(actor_asset_status.get("floating_motion_enabled", false)), "Stage 4 playfield props should keep the original floating motion layer enabled")
	_expect(int(actor_asset_status.get("floating_lantern_count", 0)) == 6, "Stage 4 playfield should carry the six original floating lantern anchors")
	_expect(int(actor_asset_status.get("floating_leaf_count", 0)) == 15, "Stage 4 playfield should carry the original floating leaf field")
	_expect(not bool(actor_asset_status.get("playfield_aura_sheet_draw_enabled", true)), "Stage 4 playfield should suppress the oversized purple aura-sheet strip")

	var playfield_renderer: Object = Stage4PlayfieldRenderer.new()
	playfield_renderer.prewarm_assets()
	_expect(bool(playfield_renderer.get_imagegen_asset_status().get("center_border_texture", false)), "Stage 4 direct playfield construction should load the imagegen thin border")
	_expect(bool(playfield_renderer.get_imagegen_asset_status().get("center_border_draw_enabled", false)), "Stage 4 direct playfield construction should keep the thin center border enabled")
	_expect(bool(playfield_renderer.get_imagegen_asset_status().get("wall_contact_flash_enabled", false)), "Stage 4 direct playfield construction should keep wall-hit border flashes enabled")
	_expect(int(playfield_renderer.get_imagegen_asset_status().get("explosion_frame_count", 0)) == 16, "Stage 4 direct playfield construction should keep the selected 4x4 explosion sheet")
	_expect(float(playfield_renderer.get_imagegen_asset_status().get("explosion_frame_interval_sec", 1.0)) <= 0.04, "Stage 4 temple explosion frames should advance at a snappy burst cadence")
	_expect(bool(playfield_renderer.get_imagegen_asset_status().get("debris_hint_removed", false)), "Stage 4 temple debris should use event-owned physics particles instead of the old boxed hint draw")
	_expect(not bool(playfield_renderer.get_imagegen_asset_status().get("destruction_dust_cloud_draw_enabled", true)), "Stage 4 temple collapse should not fill the screen with brown smoke clouds")
	_expect(not bool(playfield_renderer.get_imagegen_asset_status().get("procedural_ruins_draw_enabled", true)), "Stage 4 destroyed temple should leave clean sky instead of drawing procedural brown ruins")
	_expect(bool(playfield_renderer.get_imagegen_asset_status().get("destruction_wave_payload_draw_enabled", false)), "Stage 4 destruction beam should render from event-owned moving wave payload instead of scalar progress interpolation")
	_expect(bool(playfield_renderer.get_imagegen_asset_status().get("support_aura_removed_on_collapse", false)), "Stage 4 temple support glyphs should be tied to the live temple and removed during destruction")
	_expect(not bool(playfield_renderer.get_imagegen_asset_status().get("stadium_line_draw_enabled", true)), "Stage 4 playfield should not draw extra stadium-line overlays")
	var explosion_first_frame: int = int(playfield_renderer.get_debug_temple_explosion_frame_index({
		"stage4_collapse_progress": 0.09,
		"stage4_destruction_phase_timer": 0.43,
	}))
	var explosion_soon_frame: int = int(playfield_renderer.get_debug_temple_explosion_frame_index({
		"stage4_collapse_progress": 0.13,
		"stage4_destruction_phase_timer": 0.62,
	}))
	var explosion_late_frame: int = int(playfield_renderer.get_debug_temple_explosion_frame_index({
		"stage4_collapse_progress": 0.18,
		"stage4_destruction_phase_timer": 0.90,
	}))
	_expect(explosion_first_frame >= 0, "Stage 4 temple explosion should begin once collapse starts")
	_expect(explosion_soon_frame >= explosion_first_frame + 3, "Stage 4 temple explosion should not stretch one sprite frame over several collapse frames")
	_expect(explosion_late_frame == 15, "Stage 4 temple explosion should reach the final sprite frame during the early collapse beat")
	var intact_visibility: Dictionary = playfield_renderer.get_debug_static_decoration_visibility({
		"stage4_destruction_active": false,
		"stage4_temple_destroyed": false,
		"stage4_collapse_progress": 0.0,
	})
	_expect(bool(intact_visibility.get("lanterns", false)) and bool(intact_visibility.get("training_dummies", false)), "Stage 4 intact temple should draw the static lantern and dummy props")
	_expect(bool(intact_visibility.get("support_aura", false)), "Stage 4 intact floating temple may draw its support glyphs")
	_expect(not bool(intact_visibility.get("stadium_lines", true)), "Stage 4 intact playfield should still suppress stadium-line overlays")
	var collapsing_visibility: Dictionary = playfield_renderer.get_debug_static_decoration_visibility({
		"stage4_destruction_active": true,
		"stage4_destruction_phase": 4,
		"stage4_decorations_destroyed": true,
		"stage4_collapse_progress": 0.12,
	})
	_expect(not bool(collapsing_visibility.get("lanterns", true)), "Stage 4 collapse should stop drawing static lantern props")
	_expect(not bool(collapsing_visibility.get("training_dummies", true)), "Stage 4 collapse should stop drawing static dummy props")
	_expect(not bool(collapsing_visibility.get("support_aura", true)), "Stage 4 collapse should remove the floating temple support glyphs")
	_expect(not bool(collapsing_visibility.get("stadium_lines", true)), "Stage 4 collapse should not draw stadium-line overlays")
	var wave_probe: Object = Stage4TempleDestructionEvent.new()
	var wave_audio := FakeStage4Audio.new()
	wave_probe.start_destruction_animation("wave_parity")
	for _wave_phase_seek_idx in range(300):
		wave_probe.update(1.0 / 60.0, {"current_stage": 4}, {"audio": wave_audio})
		if int(wave_probe.get_snapshot().get("stage4_destruction_phase", 0)) == 3:
			break
	_expect(int(wave_probe.get_snapshot().get("stage4_destruction_phase", 0)) == 3, "Stage 4 red moon sequence should enter the destruction-wave phase after the original 4.5-second buildup")
	for _wave_charge_idx in range(60):
		wave_probe.update(1.0 / 60.0, {"current_stage": 4}, {"audio": wave_audio})
	_expect(not bool(wave_probe.get_snapshot().get("stage4_destruction_wave_active", true)), "Stage 4 destruction wave should stay hidden during the one-second moon charge")
	wave_probe.update(1.0 / 60.0, {"current_stage": 4}, {"audio": wave_audio})
	for _wave_travel_idx in range(15):
		wave_probe.update(1.0 / 60.0, {"current_stage": 4}, {"audio": wave_audio})
	var wave_snapshot: Dictionary = wave_probe.get_snapshot()
	var wave_payload: Dictionary = wave_snapshot.get("stage4_destruction_wave", {}) as Dictionary
	_expect(wave_audio.moon_shoot_count == 1, "Stage 4 destruction wave should play the moon-shoot cue exactly when the beam fires")
	_expect(bool(wave_snapshot.get("stage4_destruction_wave_active", false)) and not wave_payload.is_empty(), "Stage 4 destruction wave should export the real moving wave payload after fire")
	_expect(float(wave_payload.get("start_y", 999.0)) <= 12.0, "Stage 4 destruction wave should originate from the pillar moon source height, not the old low playfield line")
	_expect(float(wave_payload.get("current_x", 999.0)) < float(wave_payload.get("start_x", 0.0)) - 100.0, "Stage 4 destruction wave should travel at the original fast 12px-per-frame pace")
	_expect(float(wave_payload.get("radius", 0.0)) >= 25.0, "Stage 4 destruction wave should grow into the original thick energy core instead of a thin hint line")
	_expect(_as_array(wave_payload.get("trail", [])).size() > 0 and _as_array(wave_payload.get("beam_particles", [])).size() > 0, "Stage 4 destruction wave should carry dynamic trail and beam particle payloads")
	for _wave_hit_idx in range(55):
		wave_probe.update(1.0 / 60.0, {"current_stage": 4}, {"audio": wave_audio})
	_expect(wave_audio.temple_hit_count >= 1, "Stage 4 destruction wave should play the temple-hit cue when the fast beam reaches the temple")
	var destruction_probe: Object = Stage4TempleDestructionEvent.new()
	destruction_probe.start_destruction_animation("smoke")
	for _collapse_seek_idx in range(7 * 60):
		destruction_probe.update(1.0 / 60.0, {"current_stage": 4}, {"audio": FakeStage4Audio.new()})
	var collapse_snapshot: Dictionary = destruction_probe.get_snapshot()
	var collapse_debris_count: int = _as_array(collapse_snapshot.get("stage4_collapse_debris", [])).size()
	var roof_fragment_count: int = _as_array(collapse_snapshot.get("stage4_roof_fragments", [])).size()
	_expect(bool(collapse_snapshot.get("stage4_decorations_destroyed", false)), "Stage 4 collapse should mark ambient decorations as destroyed")
	_expect(collapse_debris_count + roof_fragment_count >= 120, "Stage 4 collapse should spawn the original-scale physical debris field")
	_expect(_as_array(collapse_snapshot.get("stage4_dust_clouds", [])).size() >= 15, "Stage 4 collapse should export dust clouds for the renderer")
	_expect(_as_array(collapse_snapshot.get("stage4_falling_lanterns", [])).size() == 6, "Stage 4 collapse should convert all six static lanterns into falling lantern state")
	var debris_min_x := 9999.0
	var debris_max_x := -9999.0
	var mapwide_burst_count := 0
	for debris_value in _as_array(collapse_snapshot.get("stage4_collapse_debris", [])):
		if debris_value is Dictionary:
			debris_min_x = minf(debris_min_x, float((debris_value as Dictionary).get("x", 0.0)))
			debris_max_x = maxf(debris_max_x, float((debris_value as Dictionary).get("x", 0.0)))
			if bool((debris_value as Dictionary).get("mapwide_burst", false)):
				mapwide_burst_count += 1
	_expect(mapwide_burst_count >= 48, "Stage 4 collapse should include a Kuromi-style mapwide burst debris layer")
	_expect(debris_min_x < -40.0 and debris_max_x > 800.0, "Stage 4 collapse debris should fly into the pillar background instead of staying inside the temple image box")
	var playfield_source := FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_playfield_renderer.gd")
	_expect(playfield_source.find("draw_set_transform") < 0, "Stage 4 playfield renderer must not reset the transformed playfield canvas")
	_expect(playfield_source.find("_draw_debris_hint") < 0, "Stage 4 playfield renderer should fully remove the boxed debris hint path")
	_expect(
		playfield_source.find("_draw_texture_region_rotated(canvas, red_moon_fragment_atlas") >= 0,
		"Stage 4 red moon fragment atlas draw should apply projectile self-rotation"
	)
	_expect(playfield_source.find("_draw_stage4_wall_contact_flash") >= 0, "Stage 4 playfield renderer should draw wall-hit border flashes from actor context")
	_expect(Stage4ActorRenderer.new().has_method("draw"), "Stage 4 actor renderer preload should parse")
	_expect(Stage4PonkBossActorRenderer.new().has_method("draw"), "Stage 4 Ponk boss placeholder renderer should parse")

	var pillar_scene_drawer: Object = registry.get_instance("stage4_pillar_scene_drawer")
	_expect(pillar_scene_drawer != null and pillar_scene_drawer.has_method("draw_post_playfield_hud"), "Stage 4 pillar scene drawer should expose the post-playfield HUD pass")
	_expect(Stage4PillarSceneDrawer.new().has_method("draw"), "Stage 4 pillar scene drawer direct preload should parse")
	var skill_card_renderer: Object = registry.get_instance("stage4_ponk_boss_skill_hud_renderer")
	_expect(skill_card_renderer != null and skill_card_renderer.has_method("draw"), "Stage 4 Ponk boss skill-card HUD renderer should be constructible")
	_expect(Stage4PonkBossSkillHudRenderer.new().has_method("draw"), "Stage 4 Ponk boss skill-card HUD renderer direct preload should parse")
	skill_card_renderer.prewarm_assets()
	var skill_card_status: Dictionary = skill_card_renderer.get_asset_status()
	_expect(bool(skill_card_status.get("magnetic_card_texture", false)), "Stage 4 Ponk magnetic skill card should load themed PNG art")
	_expect(bool(skill_card_status.get("meditation_card_texture", false)), "Stage 4 Ponk meditation skill card should load themed PNG art")

	var background: Object = registry.get_instance("stage4_pillar_background")
	_expect(background != null and background.has_method("draw"), "Stage 4 pillar background should be constructible from the module catalog")
	_expect(background.has_method("trigger_tree_shake"), "Stage 4 pillar background should expose the shared wall-hit shake API")
	background.trigger_tree_shake("left", 280.0, 620.0, 750.0)
	var wall_bounce := WallBounceController.new()
	var wall_response: Dictionary = wall_bounce.process(
		Vector2(-8.0, 1.5),
		1.0,
		"left",
		Vector2(0.0, 280.0),
		750.0,
		{
			"audio": FakeStage4Audio.new(),
			"stage_background": background,
		}
	)
	_expect(_as_vector2(wall_response.get("ball_vel", Vector2.ZERO), Vector2.ZERO).length() > 0.0, "Stage 4 wall bounce should call the shared shake API without freezing")
	var stage4_impact_effects := ImpactEffects.new()
	stage4_impact_effects.spawn_wall_impact(Vector2(4.0, 280.0), "left", 24.0)
	var wall_flash_context: Dictionary = BattleDrawActorContext.new().build(
		{"current_stage": 4, "width": 760.0, "height": 750.0},
		{"impact_effects": stage4_impact_effects}
	)
	_expect(float(wall_flash_context.get("stage4_wall_flash_timer", 0.0)) > 0.0, "Stage 4 actor context should export the wall-hit border flash timer")
	_expect(str(wall_flash_context.get("stage4_wall_flash_side", "")) == "left", "Stage 4 actor context should preserve the wall-hit side for border flashes")
	_expect(is_equal_approx(_as_vector2(wall_flash_context.get("stage4_wall_flash_position", Vector2.ZERO), Vector2.ZERO).y, 280.0), "Stage 4 actor context should preserve the wall-hit y position for border flashes")
	var guarded_wall_response: Dictionary = wall_bounce.process(
		Vector2(8.0, 0.0),
		1.0,
		"right",
		Vector2(760.0, 420.0),
		750.0,
		{
			"audio": FakeStage4Audio.new(),
			"stage_background": RefCounted.new(),
		}
	)
	_expect(_as_vector2(guarded_wall_response.get("ball_vel", Vector2.ZERO), Vector2.ZERO).length() > 0.0, "wall bounce should ignore stage backgrounds without the optional shake API")
	var ball_deps: Dictionary = BallDependencyContext.new().build_update_deps(registry)
	_expect(ball_deps.get("stage4_pillar_background", null) == background, "Stage 4 ball deps should include the routed pillar background target")
	_expect(ball_deps.get("stage4_ponk_skill_state", null) == registry.get_instance("stage4_ponk_skill_state"), "Stage 4 ball deps should include the Ponk skill state")
	background.prewarm_assets()
	var background_status: Dictionary = background.get_imagegen_asset_status()
	_expect(bool(background_status.get("nightsky_primary", false)), "Stage 4 primary nightsky pillar base should be available")
	_expect(bool(background_status.get("nightsky_fallback", false)), "Stage 4 fallback nightsky pillar base should be available")
	_expect(bool(background_status.get("original_temple_base", false)), "Stage 4 pillar should use the current original nightsky temple base")
	_expect(not bool(background_status.get("temple_motion_enabled", true)), "Stage 4 pillar motion overlays should match the current original disabled state")
	_expect(not bool(background_status.get("tibetan_motion", true)), "Stage 4 pillar should not draw legacy Tibetan motion overlays while the original keeps them disabled")
	_expect(bool(background_status.get("moon_white", false)), "Stage 4 white moon idle sheet should be available")
	_expect(bool(background_status.get("moon_red_transform", false)), "Stage 4 red moon transform sheet should be available")
	_expect(bool(background_status.get("moon_red_burst", false)), "Stage 4 red moon burst sheet should be available")
	_expect(int(background_status.get("moon_frame_count", 0)) == 6, "Stage 4 moon sheets should slice into six horizontal frames")
	_expect(bool(background_status.get("moon_fragment_atlas", false)), "Stage 4 red moon fragment atlas should be available to the pillar background")
	_expect(int(background_status.get("moon_fragment_frame_count", 0)) == 16, "Stage 4 red moon fragment atlas should slice into sixteen pillar/background frames")
	_expect(background.set_stage4_red_moon_state(1.0, 1.2, 18.0), "Stage 4 pillar background should expose red-moon state control")
	_expect(background.is_stage4_red_moon_active(), "Stage 4 pillar background should report an active red moon after state control")

	var direct_bird_event: Object = Stage4BirdEvent.new()
	direct_bird_event.prewarm_assets()
	var bird_status: Dictionary = direct_bird_event.get_asset_status()
	_expect(bool(bird_status.get("star_bird_sheet", false)), "Stage 4 star bird sheet should be available to the bird event")
	_expect(int(bird_status.get("star_bird_frame_count", 0)) == 4, "Stage 4 star bird sheet should expose four frames")
	_expect(int(bird_status.get("star_bird_gold_dust_max", 0)) == 84, "Stage 4 star bird gold dust cap should match the Python reference")
	_expect(direct_bird_event.has_method("resolve_ball_collision"), "Stage 4 bird event should own ball-hit starpoint collision")
	_expect(direct_bird_event.force_spawn_bird("left"), "Stage 4 bird event should force-spawn a star bird for smoke coverage")
	for _idx in range(10):
		direct_bird_event.update(1.0 / 60.0, {"current_stage": 4}, {})
	var bird_positions: Array = direct_bird_event.get_crow_positions()
	_expect(bird_positions.size() == 1, "Stage 4 star bird event should expose active bird collision positions")
	_expect(direct_bird_event.catch_crow(int((bird_positions[0] as Dictionary).get("index", -1))), "Stage 4 star bird event should allow catching by index")
	var bird_context: Dictionary = direct_bird_event.get_actor_draw_context(true)
	_expect(_as_array(bird_context.get("stage4_star_bird_fragments", [])).size() >= 6, "Stage 4 caught star bird should spawn explosion fragments")
	_expect(_as_array(bird_context.get("stage4_star_bird_particles", [])).size() >= 8, "Stage 4 caught star bird should spawn debris particles")
	_expect(_as_array(bird_context.get("stage4_starpoint_drops", [])).size() == 1, "Stage 4 caught star bird should spawn one crow starpoint drop")
	var crow_drop: Dictionary = _as_array(bird_context.get("stage4_starpoint_drops", []))[0] as Dictionary
	_expect(str(crow_drop.get("source_type", "")) == "crow", "Stage 4 crow starpoint should keep the crow source tag")
	_expect(direct_bird_event.force_spawn_bird("right"), "Stage 4 bird event should support a second forced spawn after catch")
	var direct_ball_bird: Dictionary = direct_bird_event.crows[0] as Dictionary
	direct_ball_bird["x"] = 260.0
	direct_ball_bird["y"] = 160.0
	direct_ball_bird["vx"] = 0.0
	direct_ball_bird["vy"] = 0.0
	direct_bird_event.crows[0] = direct_ball_bird
	var direct_bird_audio := FakeStage4Audio.new()
	var direct_bird_scene := {
		"ball_pos": Vector2(260.0, 160.0),
		"ball_vel": Vector2(4.0, -6.0),
	}
	_expect(direct_bird_event.resolve_ball_collision(direct_bird_scene, {"current_stage": 4, "ball_size": 28.6}, {"audio": direct_bird_audio}), "Stage 4 bird event should kill a bird on ball contact")
	_expect(bool(direct_bird_scene.get("stage4_star_bird_caught", false)), "Stage 4 bird event should annotate ball-contact bird kills")
	_expect(direct_bird_audio.birdkill_count == 1, "Stage 4 direct bird ball kill should play the birdkill cue")
	_expect(int(direct_bird_event.get_debug_snapshot().get("starpoint_drop_count", 0)) == 2, "Stage 4 direct bird ball kill should add a crow starpoint drop")

	var direct_monk_event: Object = Stage4BrazierMonkEvent.new()
	direct_monk_event.prewarm_assets()
	var monk_asset_status: Dictionary = direct_monk_event.get_asset_status()
	_expect(bool(monk_asset_status.get("temple_ghost_walk_left_sheet", false)), "Stage 4 temple ghost walk-left sheet should load")
	_expect(bool(monk_asset_status.get("temple_ghost_walk_right_sheet", false)), "Stage 4 temple ghost walk-right sheet should load")
	_expect(bool(monk_asset_status.get("temple_ghost_attack_sheet", false)), "Stage 4 temple ghost attack sheet should load")
	_expect(int(monk_asset_status.get("temple_ghost_frame_count", 0)) == 8, "Stage 4 temple ghost sheets should expose eight frames")
	_expect(float(monk_asset_status.get("temple_ghost_float_amplitude", 0.0)) >= 4.0, "Stage 4 temple ghost should expose a readable slow hover amplitude")
	_expect(direct_monk_event.force_spawn_monk(), "Stage 4 monk event should force-spawn a normal monk for smoke coverage")
	var monk_snapshot: Dictionary = direct_monk_event.get_debug_snapshot()
	_expect(int(monk_snapshot.get("monk_count", 0)) == 1, "Stage 4 forced normal monk should be tracked")
	direct_monk_event.reset()
	_expect(int(direct_monk_event.spawn_smoke_grenade_monks_from_brazier()) == 5, "Stage 4 lit brazier should spawn five smoke-grenade monks")
	_expect(direct_monk_event.has_smoke_grenade_monks(), "Stage 4 smoke-grenade monks should stay active after brazier spawn")
	_expect(int(direct_monk_event.trigger_smoke_grenade_monk_return()) == 5, "Stage 4 smoke-grenade monks should expose the return trigger")
	for _idx in range(8):
		direct_monk_event.update(1.0 / 60.0, {"current_stage": 4}, {})
	var monk_context: Dictionary = direct_monk_event.get_actor_draw_context(true)
	_expect(_as_array(monk_context.get("stage4_monks", [])).size() == 5, "Stage 4 smoke-grenade monks should export actor draw context")
	_expect(float(monk_context.get("stage4_monk_visual_time_sec", 0.0)) > 0.0, "Stage 4 monk draw context should carry live time for ghost hover animation")

	var map_state: Object = registry.get_instance("stage4_map_state")
	var destruction: Object = registry.get_instance("stage4_temple_destruction_event")
	var bird_event: Object = registry.get_instance("stage4_bird_event")
	var monk_event: Object = registry.get_instance("stage4_brazier_monk_event")
	var moon_event: Object = registry.get_instance("stage4_moon_event")
	var ponk_skill_state: Object = registry.get_instance("stage4_ponk_skill_state")
	_expect(map_state != null and map_state.has_method("check_smoke_touches_brazier"), "Stage 4 map state should expose smoke-brazier contact")
	_expect(destruction != null and destruction.has_method("start_destruction_animation"), "Stage 4 destruction event should expose start_destruction_animation")
	_expect(bird_event != null and bird_event.has_method("get_crow_positions"), "Stage 4 bird event should be constructible from the module catalog")
	_expect(monk_event != null and monk_event.has_method("spawn_smoke_grenade_monks_from_brazier"), "Stage 4 monk event should be constructible from the module catalog")
	_expect(moon_event != null and moon_event.has_method("resolve_fragment_collisions"), "Stage 4 moon event should be constructible from the module catalog")
	_expect(ponk_skill_state != null and ponk_skill_state.has_method("register_boss_hit"), "Stage 4 Ponk skill state should be constructible from the module catalog")
	moon_event.prewarm_assets()
	var moon_status: Dictionary = moon_event.get_asset_status()
	_expect(bool(moon_status.get("fragment_atlas", false)), "Stage 4 moon event should load the red moon fragment atlas")
	_expect(int(moon_status.get("fragment_frame_count", 0)) == 16, "Stage 4 moon event should expose sixteen red moon fragment frames")
	ponk_skill_state.prewarm_assets()
	var ponk_asset_status: Dictionary = ponk_skill_state.get_asset_status()
	_expect(bool(ponk_asset_status.get("magnetic_field_sheet", false)), "Stage 4 Ponk skill state should load the magnetic field sheet")
	_expect(int(ponk_asset_status.get("magnetic_field_frame_count", 0)) == 16, "Stage 4 Ponk skill state should expose sixteen magnetic frames")
	_expect(bool(ponk_asset_status.get("magnetic_fx_shader_host_pipeline", false)), "Stage 4 Ponk skill state should prewarm the magnetic shader host")
	_expect(int(ponk_asset_status.get("magnetic_fx_shader_layers", 0)) >= 5, "Stage 4 Ponk magnetic FX should provide lattice, arc, collapse, orb, and trail shader layers")
	_expect(int(ponk_asset_status.get("magnetic_fx_gpu_particle_layers", 0)) >= 1, "Stage 4 Ponk magnetic FX should provide prism shard GPU particles")
	_expect(bool(ponk_asset_status.get("magnetic_fx_texture_pieces_ready", false)), "Stage 4 Ponk magnetic FX should prewarm Claude's texture pieces")
	_expect(bool(ponk_asset_status.get("magnetic_upgrade_fx_texture_pieces_ready", false)), "Stage 4 Ponk magnetic FX should prewarm charge-glyph and impact-burst upgrade textures")
	_expect(bool(ponk_asset_status.get("magnetic_fx_charge_glyph_png_slot", false)), "Stage 4 Ponk skill state should prefer Claude's charge-glyph PNG")
	_expect(bool(ponk_asset_status.get("magnetic_fx_lattice_png_slot", false)), "Stage 4 Ponk skill state should prefer Claude's lattice PNG")
	_expect(bool(ponk_asset_status.get("magnetic_fx_prism_shard_png_slot", false)), "Stage 4 Ponk skill state should prefer Claude's prism-shard PNG")
	_expect(bool(ponk_asset_status.get("magnetic_fx_arc_ribbon_png_slot", false)), "Stage 4 Ponk skill state should prefer Claude's arc-ribbon PNG")
	_expect(bool(ponk_asset_status.get("magnetic_phase2_fx_texture_pieces_ready", false)), "Stage 4 Ponk magnetic Phase 2 FX should prewarm Claude's texture pieces")
	_expect(bool(ponk_asset_status.get("magnetic_fx_collapse_burst_png_slot", false)), "Stage 4 Ponk skill state should prefer Claude's collapse-burst PNG")
	_expect(bool(ponk_asset_status.get("magnetic_fx_projectile_orb_png_slot", false)), "Stage 4 Ponk skill state should prefer Claude's projectile-orb PNG")
	_expect(bool(ponk_asset_status.get("magnetic_fx_projectile_trail_png_slot", false)), "Stage 4 Ponk skill state should prefer Claude's projectile-trail PNG")
	_expect(bool(ponk_asset_status.get("magnetic_fx_impact_burst_png_slot", false)), "Stage 4 Ponk skill state should prefer Claude's impact-burst PNG")
	_expect(bool(ponk_asset_status.get("meditation_fx_shader_host_pipeline", false)), "Stage 4 Ponk skill state should prewarm the meditation shader host")
	_expect(int(ponk_asset_status.get("meditation_fx_shader_layers", 0)) >= 3, "Stage 4 Ponk meditation FX should provide mandala, trail, and release shader layers")
	_expect(int(ponk_asset_status.get("meditation_fx_gpu_particle_layers", 0)) >= 3, "Stage 4 Ponk meditation FX should provide three GPU particle layers")
	_expect(bool(ponk_asset_status.get("meditation_fx_texture_pieces_ready", false)), "Stage 4 Ponk meditation FX should prewarm procedural texture pieces")
	_expect(bool(ponk_asset_status.get("meditation_upgrade_fx_texture_pieces_ready", false)), "Stage 4 Ponk meditation FX should prewarm lock/release upgrade textures")
	_expect(bool(ponk_asset_status.get("meditation_fx_mandala_png_slot", false)), "Stage 4 Ponk skill state should prefer Claude's mandala PNG")
	_expect(bool(ponk_asset_status.get("meditation_fx_lotus_petal_png_slot", false)), "Stage 4 Ponk skill state should prefer Claude's lotus-petal PNG")
	_expect(bool(ponk_asset_status.get("meditation_fx_sutra_shard_png_slot", false)), "Stage 4 Ponk skill state should prefer Claude's sutra-shard PNG")
	_expect(bool(ponk_asset_status.get("meditation_fx_lock_burst_png_slot", false)), "Stage 4 Ponk skill state should prefer Claude's lock-burst PNG")
	_expect(bool(ponk_asset_status.get("meditation_fx_release_burst_png_slot", false)), "Stage 4 Ponk skill state should prefer Claude's release-burst PNG")
	_expect(bool(ponk_asset_status.get("meditation_fx_release_trail_png_slot", false)), "Stage 4 Ponk skill state should prefer Claude's release-trail PNG")
	var meditation_fx_status: Dictionary = Stage4PonkMeditationFxHost.build_pipeline_status()
	var magnetic_fx_status: Dictionary = Stage4PonkMagneticFxHost.build_pipeline_status()
	_expect(bool(magnetic_fx_status.get("magnetic_fx_texture_pieces_ready", false)), "Stage 4 magnetic FX host should be constructible with Claude's generated art assets")
	_expect(bool(magnetic_fx_status.get("magnetic_phase2_fx_texture_pieces_ready", false)), "Stage 4 magnetic Phase 2 FX host should be constructible with Claude's generated art assets")
	_expect(bool(meditation_fx_status.get("meditation_fx_texture_pieces_ready", false)), "Stage 4 meditation FX host should be constructible without generated art assets")
	var initial_skill_card_context: Dictionary = ponk_skill_state.get_skill_card_hud_context(null, {"current_stage": 4})
	var initial_skill_cards: Array = _as_array(initial_skill_card_context.get("stage4_ponk_boss_skill_hud_skills", []))
	_expect(bool(initial_skill_card_context.get("stage4_ponk_boss_skill_hud_active", false)), "Stage 4 Ponk skill card HUD context should be active")
	_expect(initial_skill_cards.size() == 2, "Stage 4 Ponk should expose two boss skill cards")
	_expect(_has_skill_card(initial_skill_cards, "magnetic_field"), "Stage 4 Ponk skill cards should include refraction magnetic field")
	_expect(_has_skill_card(initial_skill_cards, "meditation"), "Stage 4 Ponk skill cards should include meditation")
	_expect(str(_get_skill_card(initial_skill_cards, "magnetic_field").get("name", "")) == "굴절 자기장", "Stage 4 magnetic skill card should expose a Korean label")
	_expect(str(_get_skill_card(initial_skill_cards, "magnetic_field").get("trigger_type", "")) == "auto_cooldown", "Stage 4 magnetic skill card should expose automatic cooldown metadata")
	_expect(is_equal_approx(float(_get_skill_card(initial_skill_cards, "magnetic_field").get("cooldown_total", 0.0)), 25.0), "Stage 4 magnetic skill card should expose the 25-second cooldown")
	_expect(str(_get_skill_card(initial_skill_cards, "meditation").get("trigger_type", "")) == "hit_cooldown", "Stage 4 meditation skill card should expose hit-trigger cooldown metadata")
	_expect(is_equal_approx(float(_get_skill_card(initial_skill_cards, "meditation").get("cooldown_total", 0.0)), 18.0), "Stage 4 meditation skill card should expose the 18-second cooldown")
	map_state.reset()
	destruction.reset()
	bird_event.reset()
	monk_event.reset()
	moon_event.reset()
	ponk_skill_state.reset()
	var stage4_event_deps := {
		"current_stage": 4,
		"stage4_temple_destruction_event": destruction,
		"stage4_bird_event": bird_event,
		"stage4_brazier_monk_event": monk_event,
		"stage4_moon_event": moon_event,
		"stage4_ponk_skill_state": ponk_skill_state,
	}
	_expect(map_state.check_smoke_touches_brazier(380.0, 570.0, 50.0, stage4_event_deps), "Stage 4 smoke should light the brazier through the planned API")
	_expect(map_state.is_brazier_lit(), "Stage 4 brazier state should stay lit after smoke contact")
	_expect(int(monk_event.get_debug_snapshot().get("smoke_monk_count", 0)) == 5, "Stage 4 smoke-brazier contact should spawn five smoke monks through map state")
	_expect(map_state.trigger_smoke_grenade_monk_return(stage4_event_deps) == 5, "Stage 4 map state should forward smoke monk return trigger")
	_expect(bird_event.force_spawn_bird("left"), "Stage 4 registry bird event should spawn for draw-context coverage")
	map_state.update(1.0 / 60.0, {"current_stage": 4}, stage4_event_deps)
	var combined_context: Dictionary = map_state.get_actor_draw_context(stage4_event_deps)
	_expect(_as_array(combined_context.get("stage4_star_birds", [])).size() == 1, "Stage 4 map context should merge bird draw context")
	_expect(_as_array(combined_context.get("stage4_monks", [])).size() == 5, "Stage 4 map context should merge monk draw context")
	var draw_scene_context := BattleDrawSceneContext.new()
	var draw_registry := FakeStage4Registry.new({
		"stage4_map_state": map_state,
		"stage4_temple_destruction_event": destruction,
		"stage4_bird_event": bird_event,
		"stage4_brazier_monk_event": monk_event,
		"stage4_moon_event": moon_event,
		"stage4_ponk_skill_state": ponk_skill_state,
		"stage2_pillar_background": RefCounted.new(),
		"smasher_wheel_state": RefCounted.new(),
		"commando_firearm_runtime": RefCounted.new(),
		"viper_skill_runtime": RefCounted.new(),
	})
	var live_draw_deps: Dictionary = draw_scene_context.build_scene_deps(draw_registry, null, null)
	_expect(live_draw_deps.get("stage4_map_state", null) == map_state, "Stage 4 draw deps should include the live map state")
	_expect(live_draw_deps.get("stage4_bird_event", null) == bird_event, "Stage 4 draw deps should include the live star-bird event")
	_expect(live_draw_deps.get("stage4_brazier_monk_event", null) == monk_event, "Stage 4 draw deps should include the live monk event")
	draw_registry.requested_keys.clear()
	var optimized_draw_deps: Dictionary = draw_scene_context.build_scene_deps(
		draw_registry,
		null,
		null,
		{"current_stage": 4, "selected_character_type": "viper"}
	)
	_expect(optimized_draw_deps.get("stage4_map_state", null) == map_state, "Stage 4 optimized draw deps should include the live map state")
	_expect(optimized_draw_deps.get("viper_skill_runtime", null) == draw_registry.instances["viper_skill_runtime"], "Viper optimized draw deps should include the Viper runtime")
	_expect(not draw_registry.requested_keys.has("stage2_pillar_background"), "Stage 4 optimized draw deps should not request Stage 2 state")
	_expect(not draw_registry.requested_keys.has("smasher_wheel_state"), "Viper optimized draw deps should not request Smasher wheel state")
	_expect(not draw_registry.requested_keys.has("commando_firearm_runtime"), "Viper optimized draw deps should not request Commando firearm state")
	var live_actor_context: Dictionary = BattleDrawActorContext.new().build({
		"current_stage": 4,
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_pos": Vector2(318.0, 42.0),
		"boss_paddle_size": Vector2(124.0, 26.0),
	}, live_draw_deps)
	_expect(_as_array(live_actor_context.get("stage4_star_birds", [])).size() == 1, "Stage 4 draw actor context should carry live star birds")
	_expect(_as_array(live_actor_context.get("stage4_monks", [])).size() == 5, "Stage 4 draw actor context should carry live monks")

	var collision_audio := FakeStage4Audio.new()
	var fake_perk_state := FakeRuntimePerkState.new()
	var fake_owner := FakeStage4Owner.new()
	fake_owner.player_pos = Vector2(330.0, 210.0)
	var collection_registry := FakeStage4Registry.new({
		"runtime_perk_state": fake_perk_state,
		"runtime_perk_catalog": RefCounted.new(),
	})
	var collision_deps := {
		"current_stage": 4,
		"audio": collision_audio,
		"runtime_perk_state": fake_perk_state,
		"runtime_perk_catalog": collection_registry.get_instance("runtime_perk_catalog"),
		"stage4_map_state": map_state,
		"stage4_temple_destruction_event": destruction,
		"stage4_bird_event": bird_event,
		"stage4_brazier_monk_event": monk_event,
		"stage4_moon_event": moon_event,
		"stage4_ponk_skill_state": ponk_skill_state,
	}
	var live_crow: Dictionary = bird_event.crows[0] as Dictionary
	live_crow["x"] = 380.0
	live_crow["y"] = 260.0
	live_crow["vx"] = 0.0
	live_crow["vy"] = 0.0
	bird_event.crows[0] = live_crow
	var bird_collision_scene := {
		"ball_pos": Vector2(380.0, 260.0),
		"ball_vel": Vector2(0.0, -8.0),
	}
	var bird_collision_context := {
		"current_stage": 4,
		"ball_size": 28.6,
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"selected_character_type": "smasher",
	}
	_expect(background.resolve_ball_collision(bird_collision_scene, bird_collision_context, collision_deps), "Stage 4 background should catch a star bird through the ball collision hook")
	_expect(bool(bird_collision_scene.get("stage4_star_bird_caught", false)), "Stage 4 bird collision should annotate the ball scene")
	_expect(collision_audio.birdkill_count == 1, "Stage 4 bird collision should play the birdkill cue")
	_expect(bird_event.get_crow_positions().is_empty(), "Stage 4 caught bird should leave the active collision list")
	_expect(int(bird_event.get_debug_snapshot().get("starpoint_drop_count", 0)) == 1, "Stage 4 bird collision should leave a collectible starpoint drop")
	var collect_context: Dictionary = bird_collision_context.duplicate()
	collect_context["owner"] = fake_owner
	collect_context["registry"] = collection_registry
	collect_context["player_pos"] = fake_owner.player_pos
	collect_context["player_paddle_size"] = Vector2(120.0, 120.0)
	map_state.update(1.0 / 60.0, collect_context, collision_deps)
	_expect(fake_perk_state.collected_star_points == 1, "Stage 4 crow starpoint should grant one runtime star point on paddle contact")
	_expect(int(bird_event.get_debug_snapshot().get("starpoint_drop_count", 0)) == 0, "collected Stage 4 crow starpoint should be removed from the field")
	_expect(collision_audio.starpoint_collect_count == 1, "collecting a Stage 4 crow starpoint should play the shared collect audio")

	map_state.reset()
	bird_event.reset()
	monk_event.reset()
	var tear_audio := FakeStage4Audio.new()
	var tear_registry := FakeStage4Registry.new({
		"game_audio": tear_audio,
		"stage4_pillar_background": background,
		"stage4_map_state": map_state,
		"stage4_temple_destruction_event": destruction,
		"stage4_bird_event": bird_event,
		"stage4_brazier_monk_event": monk_event,
		"stage4_moon_event": moon_event,
		"stage4_ponk_skill_state": ponk_skill_state,
	})
	var tear_owner := FakeStage4Owner.new()
	var throw_controller: Object = ActiveItemThrowController.new()
	throw_controller._trigger_tear_gas_zone(tear_owner, tear_registry, Vector2(380.0, 570.0))
	for _idx in range(12):
		throw_controller._update_tear_gas_zones(tear_owner, tear_registry, 1.0 / 60.0)
	_expect(map_state.is_brazier_lit(), "Stage 4 tear-gas smoke should light the brazier through the active-item update path")
	_expect(int(monk_event.get_debug_snapshot().get("smoke_monk_count", 0)) == 5, "Stage 4 tear-gas brazier contact should spawn five smoke monks")
	var lit_zone: Dictionary = throw_controller.get_tear_gas_zones()[0] as Dictionary
	_expect(bool(lit_zone.get("stage4_brazier_smoke", false)), "Stage 4 tear-gas zone should remember that it lit the brazier")
	lit_zone["duration_frames"] = 1.0
	throw_controller.tear_gas_zones[0] = lit_zone
	throw_controller._update_tear_gas_zones(tear_owner, tear_registry, 1.0 / 60.0)
	_expect(throw_controller.get_tear_gas_zones().is_empty(), "expired Stage 4 tear-gas zone should be removed")
	_expect(int(monk_event.get_debug_snapshot().get("smoke_returning_count", 0)) == 5, "expired Stage 4 brazier smoke should trigger the smoke monks' return timer")
	monk_event.reset()
	bird_event.reset()
	moon_event.reset()

	_expect(monk_event.force_spawn_monk(), "Stage 4 monk event should force-spawn a monk for staff collision coverage")
	var staff_monk: Dictionary = monk_event.monks[0] as Dictionary
	staff_monk["x"] = 380.0
	staff_monk["y"] = 512.0
	staff_monk["state"] = "standing"
	staff_monk["opacity"] = 1.0
	staff_monk["fade_in"] = false
	staff_monk["swing_chance"] = 1.0
	staff_monk["swing_chance_used"] = false
	staff_monk["swing_cooldown"] = 0.0
	staff_monk["can_deflect"] = true
	monk_event.monks[0] = staff_monk
	var staff_audio := FakeStage4Audio.new()
	var staff_ball_effects := FakeStage4BallEffects.new()
	var staff_deps := {
		"current_stage": 4,
		"audio": staff_audio,
		"ball_effects": staff_ball_effects,
		"stage4_map_state": map_state,
		"stage4_temple_destruction_event": destruction,
		"stage4_bird_event": bird_event,
		"stage4_brazier_monk_event": monk_event,
		"stage4_moon_event": moon_event,
		"stage4_ponk_skill_state": ponk_skill_state,
	}
	var staff_scene := {
		"ball_pos": Vector2(380.0, 512.0),
		"ball_vel": Vector2(0.0, -8.0),
	}
	var staff_context := {
		"current_stage": 4,
		"ball_pos": Vector2(380.0, 512.0),
		"ball_vel": Vector2(0.0, -8.0),
		"last_hit_by": "player",
	}
	background.resolve_ball_collision(staff_scene, staff_context, staff_deps)
	for _idx in range(12):
		monk_event.update(1.0 / 60.0, {"current_stage": 4}, {})
	_expect(background.resolve_ball_collision(staff_scene, staff_context, staff_deps), "Stage 4 monk staff should deflect the ball during the staff hit window")
	_expect(bool(staff_scene.get("stage4_monk_staff_hit", false)), "Stage 4 monk staff collision should annotate the ball scene")
	_expect(_as_vector2(staff_scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO).length() > 8.0, "Stage 4 monk staff collision should accelerate the ball")
	_expect(staff_audio.wall_hit_count == 1, "Stage 4 monk staff collision should play the shared wall-hit cue")
	_expect(staff_ball_effects.hit_pulse_count == 1, "Stage 4 monk staff collision should register a ball hit pulse")

	monk_event.reset()
	moon_event.reset()
	var moon_audio := FakeStage4Audio.new()
	var moon_movement := FakeStage4MovementState.new()
	var moon_status_state := StatusEffectState.new()
	var moon_dash := FakeStage4DashState.new()
	var moon_ai := FakeStage4BossAiState.new()
	var moon_deps := {
		"current_stage": 4,
		"audio": moon_audio,
		"movement_state": moon_movement,
		"status_effect_state": moon_status_state,
		"dash_state": moon_dash,
		"ai_state": moon_ai,
		"stage4_map_state": map_state,
		"stage4_temple_destruction_event": destruction,
		"stage4_bird_event": bird_event,
		"stage4_brazier_monk_event": monk_event,
		"stage4_moon_event": moon_event,
		"stage4_ponk_skill_state": ponk_skill_state,
	}
	var moon_context := {
		"current_stage": 4,
		"player_pos": Vector2(320.0, 680.0),
		"player_paddle_size": Vector2(120.0, 50.0),
		"boss_pos": Vector2(320.0, 46.0),
		"boss_paddle_size": Vector2(124.0, 46.0),
		"special_gauge": 100.0,
	}
	_expect(moon_event.force_spawn_moon_fragments(1, Vector2(360.0, 705.0)) == 1, "Stage 4 moon event should force-spawn one red moon fragment")
	var player_fragment: Dictionary = moon_event.moon_fragments[0] as Dictionary
	var player_fragment_visual_scale: float = float(player_fragment.get("visual_scale", 0.0))
	_expect(
		player_fragment_visual_scale >= Stage4MoonEvent.FRAGMENT_IMAGE_SCALE_MIN
		and player_fragment_visual_scale <= Stage4MoonEvent.FRAGMENT_IMAGE_SCALE_MAX,
		"Stage 4 moon fragment should carry a randomized visual scale from original size to the tuned maximum"
	)
	var player_fragment_rotation_speed: float = absf(float(player_fragment.get("rotation_speed", 0.0)))
	_expect(
		player_fragment_rotation_speed >= Stage4MoonEvent.FRAGMENT_ROTATION_SPEED_MIN
		and player_fragment_rotation_speed <= Stage4MoonEvent.FRAGMENT_ROTATION_SPEED_MAX,
		"Stage 4 moon fragment should carry a randomized self-rotation speed"
	)
	player_fragment["x"] = 360.0
	player_fragment["y"] = 705.0
	player_fragment["vx"] = 0.0
	player_fragment["vy"] = 0.0
	player_fragment["size"] = 12.0
	player_fragment["entered_field"] = true
	player_fragment["fragment_id"] = 9001
	moon_event.moon_fragments[0] = player_fragment
	var moon_player_scene := {"special_gauge": 100.0}
	_expect(background.resolve_ball_collision(moon_player_scene, moon_context, moon_deps), "Stage 4 moon fragment should hit the player paddle through the shared collision hook")
	_expect(bool(moon_player_scene.get("stage4_player_burn_active", false)), "Stage 4 moon fragment should mark the player burn visual")
	_expect(moon_status_state.has_status("player", "burn"), "Stage 4 moon fragment should apply the shared player burn status")
	_expect(is_equal_approx(float(moon_player_scene.get("special_gauge", 0.0)), 98.0), "Stage 4 moon fragment should drain two special gauge points")
	_expect(moon_movement.knockback_count == 1, "Stage 4 moon fragment should knock the player paddle")
	_expect(moon_audio.birdkill_count == 1, "Stage 4 moon fragment player hit should play the Python reference birdkill cue")
	_expect(moon_audio.temple_hit_count == 0, "Stage 4 moon fragment actor hits should not play the temple-impact cue")
	var moon_draw_context: Dictionary = moon_event.get_actor_draw_context(true)
	_expect(_as_array(moon_draw_context.get("stage4_moon_fragments", [])).size() == 1, "Stage 4 moon event should export fragment draw context")
	_expect(bool(moon_draw_context.get("stage4_player_burn_active", false)), "Stage 4 moon event should export burn draw context")

	moon_event.reset()
	moon_dash.active = true
	_expect(moon_event.force_spawn_moon_fragments(1, Vector2(360.0, 705.0)) == 1, "Stage 4 moon event should force-spawn one dash-deflection fragment")
	var dash_fragment: Dictionary = moon_event.moon_fragments[0] as Dictionary
	dash_fragment["x"] = 360.0
	dash_fragment["y"] = 705.0
	dash_fragment["vx"] = 0.0
	dash_fragment["vy"] = 0.0
	dash_fragment["size"] = 12.0
	dash_fragment["entered_field"] = true
	dash_fragment["fragment_id"] = 9002
	moon_event.moon_fragments[0] = dash_fragment
	var moon_dash_scene := {}
	_expect(background.resolve_ball_collision(moon_dash_scene, moon_context, moon_deps), "Stage 4 dash should deflect a moon fragment through the shared collision hook")
	_expect(bool(moon_dash_scene.get("stage4_moon_fragment_deflected", false)), "Stage 4 dash deflection should annotate the scene")
	_expect(moon_audio.dash_count == 1, "Stage 4 dash deflection should play the dash cue")
	var deflected_fragment: Dictionary = moon_event.moon_fragments[0] as Dictionary
	_expect(bool(deflected_fragment.get("deflected", false)), "Stage 4 dash deflection should mark the fragment as boss-bound")
	deflected_fragment["x"] = 370.0
	deflected_fragment["y"] = 66.0
	moon_event.moon_fragments[0] = deflected_fragment
	moon_dash.active = false
	ponk_skill_state.reset()
	ponk_skill_state.apply_gauge_delta(220.0)
	var moon_boss_scene := {}
	_expect(background.resolve_ball_collision(moon_boss_scene, moon_context, moon_deps), "Stage 4 deflected moon fragment should hit the boss")
	_expect(bool(moon_boss_scene.get("stage4_moon_fragment_boss_hit", false)), "Stage 4 boss fragment hit should annotate the scene")
	_expect(is_equal_approx(float(moon_boss_scene.get("stage4_ponk_gauge_delta", 0.0)), -50.0), "Stage 4 boss fragment hit should drain fifty Ponk gauge points")
	_expect(is_equal_approx(float(ponk_skill_state.get_debug_snapshot().get("stage4_ponk_gauge_value", 0.0)), 170.0), "Stage 4 deflected moon fragment should drain the live Ponk gauge state")
	_expect(moon_status_state.has_status("boss", "stun"), "Stage 4 boss fragment hit should apply shared boss stun")
	_expect(moon_ai.knockback_count == 1, "Stage 4 boss fragment hit should push the boss paddle")
	_expect(moon_audio.birdkill_count == 2, "Stage 4 boss fragment hit should play the same Python reference birdkill cue")
	_expect(moon_audio.temple_hit_count == 0, "Stage 4 reflected actor hits should keep the temple-impact cue reserved for temple hits")
	moon_event.reset()

	ponk_skill_state.reset()
	var ponk_audio := FakeStage4Audio.new()
	var ponk_context := {
		"current_stage": 4,
		"ball_active": true,
		"ball_pos": Vector2(370.0, 82.0),
		"ball_vel": Vector2(0.0, 8.0),
		"boss_pos": Vector2(320.0, 46.0),
		"boss_paddle_size": Vector2(124.0, 46.0),
		"player_pos": Vector2(320.0, 680.0),
		"player_paddle_size": Vector2(120.0, 50.0),
		"ball_base_speed": 7.65,
	}
	var ponk_deps := {
		"current_stage": 4,
		"audio": ponk_audio,
		"status_effect_state": StatusEffectState.new(),
		"stage4_ponk_skill_state": ponk_skill_state,
	}
	var initial_ponk_snapshot: Dictionary = ponk_skill_state.get_debug_snapshot()
	_expect(is_equal_approx(float(initial_ponk_snapshot.get("magnetic_cooldown_seconds", 0.0)), 25.0), "Stage 4 magnetic cooldown should begin at twenty-five seconds")
	_expect(is_equal_approx(float(initial_ponk_snapshot.get("meditation_cooldown_seconds", 0.0)), 18.0), "Stage 4 meditation cooldown should begin at eighteen seconds")
	ponk_skill_state.register_boss_hit(Vector2(0.0, 9.0), ponk_context, ponk_deps)
	var blocked_meditation_snapshot: Dictionary = ponk_skill_state.get_debug_snapshot()
	_expect(not bool(blocked_meditation_snapshot.get("meditation_active", false)), "Stage 4 meditation should not trigger from a boss hit while its cooldown remains")
	_expect(is_equal_approx(float(blocked_meditation_snapshot.get("stage4_ponk_gauge_value", 0.0)), 0.0), "Stage 4 Ponk boss hits should no longer charge the old boss gauge skill card")
	ponk_skill_state.set("meditation_cooldown_seconds", 0.0)
	ponk_skill_state.register_boss_hit(Vector2(0.0, 9.0), ponk_context, ponk_deps)
	var meditation_hit_snapshot: Dictionary = ponk_skill_state.get_debug_snapshot()
	_expect(bool(meditation_hit_snapshot.get("meditation_active", false)), "Stage 4 meditation should trigger from the next boss hit after its cooldown")
	_expect(is_equal_approx(float(meditation_hit_snapshot.get("meditation_cooldown_seconds", 0.0)), 18.0), "Stage 4 meditation should restart its eighteen-second cooldown on hit trigger")
	_expect(ponk_audio.meditation_count == 1, "Stage 4 hit-triggered meditation should play the meditation cue")
	var meditation_hit_cards: Array = _as_array(ponk_skill_state.get_skill_card_hud_context(null, ponk_context).get("stage4_ponk_boss_skill_hud_skills", []))
	_expect(str(_get_skill_card(meditation_hit_cards, "meditation").get("status", "")) == "casting", "Stage 4 meditation skill card should show casting after hit trigger")
	ponk_skill_state.reset()
	ponk_skill_state.set("magnetic_cooldown_seconds", 0.0)
	ponk_skill_state.update(1.0 / 60.0, ponk_context, ponk_deps)
	var magnetic_snapshot: Dictionary = ponk_skill_state.get_debug_snapshot()
	_expect(bool(magnetic_snapshot.get("magnetic_active", false)), "Stage 4 Ponk zero magnetic cooldown should auto-activate refraction magnetic field")
	_expect(is_equal_approx(float(magnetic_snapshot.get("magnetic_cooldown_seconds", 0.0)), 25.0), "Stage 4 magnetic field should restart its twenty-five-second cooldown on auto activation")
	var magnetic_draw_context: Dictionary = ponk_skill_state.get_actor_draw_context(true)
	_expect(bool(magnetic_draw_context.get("stage4_magnetic_active", false)), "Stage 4 magnetic draw context should expose the active field")
	_expect(magnetic_draw_context.has("stage4_effect_clock"), "Stage 4 magnetic draw context should expose the runtime VFX clock")
	_expect(magnetic_draw_context.has("stage4_magnetic_enraged"), "Stage 4 magnetic draw context should expose the enraged FX state")
	var active_skill_cards: Array = _as_array(ponk_skill_state.get_skill_card_hud_context(null, ponk_context).get("stage4_ponk_boss_skill_hud_skills", []))
	_expect(str(_get_skill_card(active_skill_cards, "magnetic_field").get("status", "")) == "casting", "Stage 4 magnetic skill card should show casting while active")
	_expect(ponk_audio.magnetic_loop_count >= 1, "Stage 4 Ponk magnetic field should start its loop audio")
	var magnetic_scene := {
		"ball_pos": Vector2(370.0, 82.0),
		"ball_vel": Vector2(0.0, 8.0),
	}
	_expect(background.apply_ball_motion(magnetic_scene, ponk_context, {
		"current_stage": 4,
		"stage4_ponk_skill_state": ponk_skill_state,
	}, 1.0), "Stage 4 background should route magnetic field ball motion")
	_expect(bool(magnetic_scene.get("stage4_magnetic_ball_curved", false)), "Stage 4 magnetic field should annotate curved ball motion")
	_expect(_as_vector2(magnetic_scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO) != Vector2(0.0, 8.0), "Stage 4 magnetic field should bend the ball velocity")
	ponk_skill_state.set("magnetic_timer_frames", 1.0)
	var homing_ponk_context: Dictionary = ponk_context.duplicate(true)
	homing_ponk_context["player_pos"] = Vector2(120.0, 680.0)
	ponk_skill_state.update(1.0 / 60.0, homing_ponk_context, ponk_deps)
	var projectile_snapshot: Dictionary = ponk_skill_state.get_debug_snapshot()
	_expect(not bool(projectile_snapshot.get("magnetic_active", true)), "Stage 4 expired magnetic field should stop the active field")
	_expect(bool(projectile_snapshot.get("magnetic_projectile_active", false)), "Stage 4 expired magnetic field should launch a slow projectile")
	_expect(float(projectile_snapshot.get("magnetic_projectile_elapsed_seconds", 0.0)) > 0.0, "Stage 4 magnetic projectile should track Phase 2 elapsed time")
	var projectile_pos: Vector2 = _as_vector2(projectile_snapshot.get("magnetic_projectile_pos", Vector2.ZERO), Vector2.ZERO)
	_expect(projectile_pos.x < 382.0, "Stage 4 magnetic projectile should gently home toward the player on normal launch")
	_expect(ponk_audio.stop_magnetic_count >= 1, "Stage 4 expired magnetic field should stop its loop audio")
	var projectile_draw_context: Dictionary = ponk_skill_state.get_actor_draw_context(true)
	_expect(projectile_draw_context.has("stage4_magnetic_projectile_elapsed"), "Stage 4 magnetic projectile draw context should expose Phase 2 elapsed time")
	_expect(projectile_draw_context.has("stage4_magnetic_projectile_velocity"), "Stage 4 magnetic projectile draw context should expose trail orientation velocity")
	var homing_velocity: Vector2 = _as_vector2(projectile_draw_context.get("stage4_magnetic_projectile_velocity", Vector2.ZERO), Vector2.ZERO)
	_expect(homing_velocity.x < 0.0, "Stage 4 magnetic projectile velocity should point toward the player's X position")
	var magnetic_release_scene := {
		"ball_pos": Vector2(370.0, 82.0),
		"ball_vel": Vector2(0.0, 2.0),
	}
	ponk_skill_state.apply_ball_motion(magnetic_release_scene, ponk_context, ponk_deps, 1.0)
	_expect(bool(magnetic_release_scene.get("stage4_magnetic_released_ball", false)), "Stage 4 magnetic release should mark the restored ball")
	_expect(_as_vector2(magnetic_release_scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO).length() >= 7.65, "Stage 4 magnetic release should restore the ball speed floor")
	ponk_skill_state.force_spawn_magnetic_projectile(Vector2(380.0, 705.0), 80.0)
	var projectile_scene := {}
	var projectile_context: Dictionary = ponk_context.duplicate(true)
	projectile_context["player_pos"] = Vector2(320.0, 680.0)
	projectile_context["player_paddle_size"] = Vector2(120.0, 50.0)
	_expect(background.resolve_ball_collision(projectile_scene, projectile_context, ponk_deps), "Stage 4 magnetic projectile should hit the player through the shared background hook")
	_expect(bool(projectile_scene.get("stage4_magnetic_projectile_player_hit", false)), "Stage 4 magnetic projectile should annotate the player hit")
	_expect((ponk_deps["status_effect_state"] as Object).has_status("player", "slow"), "Stage 4 magnetic projectile should apply shared player slow status")
	var projectile_slow_status: Dictionary = (ponk_deps["status_effect_state"] as Object).get_status("player", "slow")
	_expect(is_equal_approx(float(projectile_slow_status.get("multiplier", 0.0)), 0.5), "Stage 4 magnetic projectile should slow the player by 50 percent on hit")
	_expect(is_equal_approx(float(projectile_scene.get("stage4_magnetic_projectile_y_speed_multiplier", 0.0)), 0.5), "Stage 4 magnetic projectile should halve its Y speed after touching the player")
	ponk_skill_state.update(1.0 / 60.0, projectile_context, ponk_deps)
	var slowed_projectile_velocity: Vector2 = _as_vector2(ponk_skill_state.get_actor_draw_context(true).get("stage4_magnetic_projectile_velocity", Vector2.ZERO), Vector2.ZERO)
	_expect(is_equal_approx(slowed_projectile_velocity.y, 6.0), "Stage 4 magnetic projectile should continue at 50 percent Y speed after contact")

	ponk_skill_state.reset()
	var meditation_audio := FakeStage4Audio.new()
	var meditation_deps := {
		"current_stage": 4,
		"audio": meditation_audio,
		"stage4_ponk_skill_state": ponk_skill_state,
	}
	_expect(ponk_skill_state.force_activate_meditation(ponk_context, meditation_deps), "Stage 4 Ponk meditation should force-activate for smoke coverage")
	_expect(meditation_audio.meditation_count == 1, "Stage 4 Ponk meditation should play the meditation cue")
	var meditation_scene := {
		"ball_pos": Vector2(370.0, 160.0),
		"ball_vel": Vector2(2.0, -3.0),
	}
	_expect(ponk_skill_state.apply_ball_motion(meditation_scene, ponk_context, meditation_deps, 1.0), "Stage 4 meditation should control the ball during the orbit")
	_expect(bool(meditation_scene.get("stage4_meditation_ball_control", false)), "Stage 4 meditation should annotate controlled ball motion")
	_expect(_as_vector2(meditation_scene.get("ball_vel", Vector2.ONE), Vector2.ONE) == Vector2.ZERO, "Stage 4 meditation should hold the ball still while orbiting")
	_expect(not bool(meditation_scene.get("skip_ball_motion_step", false)), "Stage 4 meditation should not persist the shared skip flag across ball frames")
	ponk_skill_state.set("meditation_timer_frames", 1.0)
	ponk_skill_state.update(1.0 / 60.0, ponk_context, meditation_deps)
	ponk_skill_state.apply_ball_motion(meditation_scene, ponk_context, meditation_deps, 1.0)
	_expect(bool(meditation_scene.get("stage4_meditation_released_ball", false)), "Stage 4 meditation should release the ball after its orbit")
	_expect(_as_vector2(meditation_scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO).y > 0.0, "Stage 4 meditation release should launch the ball downward")
	var meditation_release_speed_direct: float = _as_vector2(meditation_scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO).length()
	var meditation_base_speed: float = float(ponk_context.get("ball_base_speed", 7.65))
	_expect(meditation_release_speed_direct >= meditation_base_speed * 1.3 * 1.10 - 0.01, "Stage 4 meditation release should add at least 10 percent speed")
	_expect(meditation_release_speed_direct <= meditation_base_speed * 1.6 * 1.30 + 0.01, "Stage 4 meditation release should cap its extra speed at 30 percent")
	_expect(meditation_audio.meditation_after_count == 1, "Stage 4 Ponk meditation release should play the after cue")
	_expect(not bool(meditation_scene.get("skip_ball_motion_step", false)), "Stage 4 meditation release should clear any stale shared skip flag")
	ponk_skill_state.set("meditation_release_pending", true)
	ponk_skill_state.set("meditation_release_velocity", Vector2(0.0, 42.0))
	var release_cap_scene := {
		"ball_pos": Vector2(370.0, 160.0),
		"ball_vel": Vector2.ZERO,
		"ball_impact_boost": 1.0,
		"max_ball_speed": 26.0,
		"impact_boost_max_ball_speed": 26.0,
		"speed_limit_disabled": false,
	}
	ponk_skill_state.apply_ball_motion(release_cap_scene, ponk_context, meditation_deps, 1.0)
	_expect(is_equal_approx(float(release_cap_scene.get("stage4_meditation_release_speed_cap", 0.0)), 35.0), "Stage 4 meditation release should expose a one-frame 35 speed cap")
	BallFrameMotionController.new().apply_ball_speed_limits(release_cap_scene, {"ball_physics": FakeBallPhysics.new()})
	var meditation_release_speed: float = _as_vector2(release_cap_scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO).length()
	_expect(meditation_release_speed > 34.9 and meditation_release_speed <= 35.01, "Stage 4 meditation release should allow the launch speed up to 35")
	var normal_cap_scene := {
		"ball_vel": Vector2(0.0, 42.0),
		"ball_impact_boost": 1.0,
		"max_ball_speed": 26.0,
		"impact_boost_max_ball_speed": 26.0,
		"speed_limit_disabled": false,
	}
	BallFrameMotionController.new().apply_ball_speed_limits(normal_cap_scene, {"ball_physics": FakeBallPhysics.new()})
	_expect(_as_vector2(normal_cap_scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO).length() <= 26.01, "Stage 4 meditation speed cap should not persist after the release frame")

	ponk_skill_state.reset()
	var meditation_flow_audio := FakeStage4Audio.new()
	var meditation_flow_deps := {
		"current_stage": 4,
		"audio": meditation_flow_audio,
		"stage_background": background,
		"stage4_ponk_skill_state": ponk_skill_state,
		"motion_stepper": BallMotionStepper.new(),
	}
	var meditation_flow_context: Dictionary = ponk_context.duplicate(true)
	meditation_flow_context.merge({
		"ball_active": true,
		"ball_pos": Vector2(370.0, 160.0),
		"ball_vel": Vector2(2.0, -3.0),
		"skip_ball_motion_step": false,
		"ball_impact_boost": 1.0,
		"ball_boost_decay_rate": 0.975,
		"ball_min_boost": 0.70,
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
		"vertical_bounce_count": 0,
		"ball_spin_strength": 0.0,
		"ball_spin_direction": 0,
		"drive_ball_active": false,
		"drive_hit_boss": false,
		"drive_speed_increase": 0.0,
		"drive_text_timer_frames": 0.0,
		"special_gauge": 0.0,
		"player_speed": 0.0,
		"max_step_distance": 12.0,
		"ball_size": 28.6,
	}, true)
	_expect(ponk_skill_state.force_activate_meditation(meditation_flow_context, meditation_flow_deps), "Stage 4 Ponk meditation should activate for full ball-update flow coverage")
	var meditation_controller := BallUpdateController.new()
	var controller_released := false
	for _frame in range(140):
		ponk_skill_state.update(1.0 / 60.0, meditation_flow_context, meditation_flow_deps)
		var flow_result: Dictionary = meditation_controller.update(1.0 / 60.0, meditation_flow_context, meditation_flow_deps)
		var flow_snapshot: Variant = flow_result.get("snapshot", {})
		if flow_snapshot is Dictionary:
			meditation_flow_context.merge(flow_snapshot, true)
		if bool(meditation_flow_context.get("stage4_meditation_released_ball", false)):
			controller_released = true
			break
	_expect(controller_released, "Stage 4 meditation should release through the real ball-update controller instead of getting stuck behind skip_ball_motion_step")
	_expect(_as_vector2(meditation_flow_context.get("ball_vel", Vector2.ZERO), Vector2.ZERO).y > 0.0, "Stage 4 meditation ball-update flow should launch the released ball downward")
	_expect(not bool(meditation_flow_context.get("skip_ball_motion_step", false)), "Stage 4 meditation ball-update flow should leave the shared skip flag clear")
	_expect(meditation_flow_audio.meditation_after_count == 1, "Stage 4 meditation ball-update flow should play the after cue once")
	var ponk_draw_context: Dictionary = ponk_skill_state.get_actor_draw_context(true)
	_expect(ponk_draw_context.has("stage4_magnetic_active"), "Stage 4 Ponk skill state should export actor draw context")
	ponk_skill_state.reset()

	var score_audio := FakeStage4Audio.new()
	var score_deps := {
		"current_stage": 4,
		"audio": score_audio,
		"stage4_temple_destruction_event": destruction,
		"stage4_bird_event": bird_event,
		"stage4_brazier_monk_event": monk_event,
		"stage4_moon_event": moon_event,
		"stage4_ponk_skill_state": ponk_skill_state,
	}
	map_state.reset()
	destruction.reset()
	map_state.handle_score_event("player", {"player_score": 3, "boss_score": 0}, score_deps)
	_expect(not destruction.is_destruction_animation_active(), "Stage 4 player-score trigger should wait for the next serve prepare")
	_expect(map_state.handle_scoreboard_serve_prepare(score_deps), "Stage 4 player-score trigger should start destruction on the next round")
	_expect(destruction.is_destruction_animation_active(), "Stage 4 score-next-round destruction should activate the shared destruction state machine")
	_expect(str(destruction.get_snapshot().get("stage4_destruction_reason", "")) == "score_next_round", "Stage 4 score trigger should tag the destruction reason")
	_expect(score_audio.phase2_bgm_count == 1, "Stage 4 score trigger should start the phase-2 BGM once")
	for _idx in range(340):
		map_state.update(1.0 / 60.0, {"current_stage": 4}, score_deps)
	_expect(score_audio.moon_shoot_count >= 1, "Stage 4 destruction wave should reach the moon-shoot audio cue")

	var enrage_audio := FakeStage4Audio.new()
	var enrage_map_state := Stage4MapState.new()
	var enrage_destruction := Stage4TempleDestructionEvent.new()
	var enrage_deps := {
		"current_stage": 4,
		"audio": enrage_audio,
		"stage4_temple_destruction_event": enrage_destruction,
		"stage4_bird_event": Stage4BirdEvent.new(),
		"stage4_brazier_monk_event": Stage4BrazierMonkEvent.new(),
		"stage4_moon_event": Stage4MoonEvent.new(),
		"stage4_ponk_skill_state": Stage4PonkSkillState.new(),
	}
	enrage_map_state.update(1.0 / 60.0, {"current_stage": 4, "enraged_boss_active": true}, enrage_deps)
	_expect(enrage_destruction.is_destruction_animation_active(), "Stage 4 enrage trigger should start destruction immediately")
	_expect(str(enrage_destruction.get_snapshot().get("stage4_destruction_reason", "")) == "enraged", "Stage 4 enrage trigger should tag the destruction reason")
	_expect(enrage_audio.phase2_bgm_count == 1, "Stage 4 enrage trigger should start the phase-2 BGM once")

	var gauge_renderer: Object = registry.get_instance("stage4_ponk_gauge_hud_renderer")
	_expect(gauge_renderer != null and gauge_renderer.has_method("draw"), "Stage 4 Ponk gauge HUD renderer should be constructible")
	_expect(Stage4PonkGaugeHudRenderer.new().has_method("draw"), "Stage 4 Ponk gauge HUD renderer direct preload should parse")
	var hud_context: Dictionary = map_state.get_hud_context({
		"stage4_temple_destruction_event": destruction,
		"stage4_ponk_skill_state": ponk_skill_state,
	})
	_expect(bool(hud_context.get("stage4_ponk_gauge_visible", false)), "Stage 4 Ponk gauge HUD context should default visible")

	var landing_intro := StageLandingIntro.new()
	landing_intro.prewarm_assets(4)

	var visual_fx_audio := FakeStage4Audio.new()
	var visual_fx_context := {
		"current_stage": 4,
		"boss_pos": Vector2(318.0, 42.0),
		"boss_paddle_size": Vector2(124.0, 46.0),
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"ball_base_speed": 7.65,
	}
	ponk_skill_state.force_activate_magnetic(visual_fx_context, {"audio": visual_fx_audio})
	ponk_skill_state.set("magnetic_timer_frames", 1.0)
	ponk_skill_state.update(1.0 / 60.0, visual_fx_context, {"audio": visual_fx_audio})
	ponk_skill_state.force_activate_meditation(visual_fx_context, {"audio": visual_fx_audio})
	for _fx_frame in range(6):
		ponk_skill_state.update(1.0 / 60.0, visual_fx_context, {"audio": visual_fx_audio})

	probe = Stage4DrawProbe.new()
	probe.background = background
	probe.actor_renderer = actor_renderer
	probe.gauge_renderer = gauge_renderer
	probe.skill_card_renderer = skill_card_renderer
	probe.map_state = map_state
	probe.destruction = destruction
	probe.bird_event = bird_event
	probe.monk_event = monk_event
	probe.moon_event = moon_event
	probe.ponk_skill_state = ponk_skill_state
	get_root().add_child(probe)
	probe.queue_redraw()


func _process(_delta: float) -> bool:
	frame_count += 1
	if frame_count < 2:
		return false
	_expect(probe.background_draw_count > 0, "Stage 4 pillar background should draw through CanvasItem")
	_expect(probe.background_draw_result, "Stage 4 pillar background draw should return true")
	var drawn_moon_center: Vector2 = probe.background.get_stage4_moon_center()
	_expect(drawn_moon_center.x > 1160.0 and drawn_moon_center.y >= 50.0 and drawn_moon_center.y <= 82.0, "Stage 4 pillar moon should use the current original source-anchor position")
	_expect(probe.actor_draw_count > 0, "Stage 4 actor renderer should draw through CanvasItem")
	var magnetic_host: Node = probe.get_node_or_null("PonkMagneticFxHost")
	_expect(magnetic_host != null, "Stage 4 actor renderer should attach the Ponk magnetic FX host while magnetic field or projectile FX is active")
	if magnetic_host != null:
		var magnetic_host_status: Dictionary = magnetic_host.get_debug_status()
		_expect(bool(magnetic_host_status.get("active", false)), "Stage 4 magnetic FX host should stay active after deferred attachment")
		_expect(not bool(magnetic_host_status.get("process_active", true)), "Stage 4 magnetic FX host should update from draw sync instead of an outside-shell _process callback")
		_expect(int(magnetic_host_status.get("shader_layers", 0)) >= 5, "Stage 4 magnetic FX host should keep shader-driven lattice, arc, collapse, orb, and trail layers")
		_expect(int(magnetic_host_status.get("gpu_particle_layers", 0)) >= 1, "Stage 4 magnetic FX host should keep prism shard GPU particles live")
		_expect(bool(magnetic_host_status.get("texture_pieces_ready", false)), "Stage 4 magnetic FX host should keep Claude texture pieces ready")
		_expect(bool(magnetic_host_status.get("phase2_texture_pieces_ready", false)), "Stage 4 magnetic FX host should keep Claude Phase 2 texture pieces ready")
		_expect(bool(magnetic_host_status.get("charge_glyph_png_slot", false)), "Stage 4 magnetic FX host should keep Claude charge-glyph texture ready")
		_expect(bool(magnetic_host_status.get("impact_burst_png_slot", false)), "Stage 4 magnetic FX host should keep Claude impact-burst texture ready")
		_expect(bool(magnetic_host_status.get("lattice_writhe_shader", false)), "Stage 4 magnetic lattice should use the shared writhe ember shader")
		_expect(bool(magnetic_host_status.get("phase2_active", false)), "Stage 4 magnetic FX host should keep the collapse/projectile Phase 2 state active")
		_expect(bool(magnetic_host_status.get("collapse_burst_visible", false)) or bool(magnetic_host_status.get("projectile_orb_visible", false)) or bool(magnetic_host_status.get("impact_burst_visible", false)), "Stage 4 magnetic FX host should render collapse, projectile, or impact texture layers during Phase 2")
		_expect(bool(magnetic_host_status.get("uses_viewport_layout", false)), "Stage 4 magnetic FX host should consume viewport layout scale")
	var meditation_host: Node = probe.get_node_or_null("PonkMeditationFxHost")
	_expect(meditation_host != null, "Stage 4 actor renderer should attach the Ponk meditation FX host while meditation is active")
	if meditation_host != null:
		var meditation_host_status: Dictionary = meditation_host.get_debug_status()
		_expect(bool(meditation_host_status.get("active", false)), "Stage 4 meditation FX host should stay active after deferred attachment")
		_expect(not bool(meditation_host_status.get("process_active", true)), "Stage 4 meditation FX host should update from draw sync instead of an outside-shell _process callback")
		_expect(int(meditation_host_status.get("shader_layers", 0)) >= 3, "Stage 4 meditation FX host should keep shader-driven mandala, trail, and release layers")
		_expect(int(meditation_host_status.get("gpu_particle_layers", 0)) >= 3, "Stage 4 meditation FX host should keep three GPU particle layers live")
	_expect(probe.gauge_draw_count > 0, "Stage 4 Ponk gauge HUD should draw through CanvasItem")
	_expect(probe.skill_card_draw_count > 0, "Stage 4 Ponk boss skill-card HUD should draw through CanvasItem")
	print("stage4_map_port_smoke: ok")
	quit(0)
	return true


func _expect_stage4_texture(path: String, expected_size: Vector2) -> void:
	var texture: Texture2D = ProjectResourceLoader.load_texture(path)
	_expect(texture != null, "Stage 4 texture should load: %s" % path)
	_expect(texture.get_size() == expected_size, "Stage 4 texture should keep source dimensions: %s" % path)


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


func _has_skill_card(cards: Array, skill_id: String) -> bool:
	return not _get_skill_card(cards, skill_id).is_empty()


func _get_skill_card(cards: Array, skill_id: String) -> Dictionary:
	for value in cards:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == skill_id:
			return value as Dictionary
	return {}
