extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Stage2PillarAssets := preload("res://scripts/stages/stage2/stage2_pillar_assets.gd")
const Stage2RenderBudgetHelper := preload("res://scripts/stages/stage2/stage2_render_budget_helper.gd")
const Stage2AudioRouter := preload("res://scripts/stages/stage2/stage2_audio_router.gd")
const Stage2PillarImagegenRenderer := preload("res://scripts/stages/stage2/stage2_pillar_imagegen_renderer.gd")
const Stage2PillarImagegenAssetsBuilder := preload("res://scripts/stages/stage2/stage2_pillar_imagegen_assets_builder.gd")
const Stage2PillarObstacleVisualRenderer := preload("res://scripts/stages/stage2/stage2_pillar_obstacle_visual_renderer.gd")
const Stage2WaterCannonVisualRenderer := preload("res://scripts/stages/stage2/stage2_water_cannon_visual_renderer.gd")
const Stage2WaterVisualState := preload("res://scripts/stages/stage2/stage2_water_visual_state.gd")
const Stage2WarningVisualRenderer := preload("res://scripts/stages/stage2/stage2_warning_visual_renderer.gd")
const Stage2ScreenOverlayVisualRenderer := preload("res://scripts/stages/stage2/stage2_screen_overlay_visual_renderer.gd")
const Stage2AmbientVisualRenderer := preload("res://scripts/stages/stage2/stage2_ambient_visual_renderer.gd")
const Stage2AmbientVisualState := preload("res://scripts/stages/stage2/stage2_ambient_visual_state.gd")
const Stage2RockVisualFactory := preload("res://scripts/stages/stage2/stage2_rock_visual_factory.gd")
const Stage2RockVisualAssetsBuilder := preload("res://scripts/stages/stage2/stage2_rock_visual_assets_builder.gd")
const Stage2RockRuntimeState := preload("res://scripts/stages/stage2/stage2_rock_runtime_state.gd")
const Stage2StarpointVisualFactory := preload("res://scripts/stages/stage2/stage2_starpoint_visual_factory.gd")
const Stage2StarpointDropMotionState := preload("res://scripts/stages/stage2/stage2_starpoint_drop_motion_state.gd")
const Stage2StarpointDropQuery := preload("res://scripts/stages/stage2/stage2_starpoint_drop_query.gd")
const LingpetStarlightTrackingBridge := preload("res://scripts/stages/common/lingpet_starlight_tracking_bridge.gd")
const Stage2ChaosRockAbsorbState := preload("res://scripts/stages/stage2/stage2_chaos_rock_absorb_state.gd")
const Stage2WaterCannonGeometry := preload("res://scripts/stages/stage2/stage2_water_cannon_geometry.gd")
const Stage2WaterCannonVisualStateBuilder := preload("res://scripts/stages/stage2/stage2_water_cannon_visual_state_builder.gd")
const Stage2QuakeWaveVisualStateBuilder := preload("res://scripts/stages/stage2/stage2_quake_wave_visual_state_builder.gd")
const Stage2WaterCannonPayloadFactory := preload("res://scripts/stages/stage2/stage2_water_cannon_payload_factory.gd")
const Stage2WaterCannonPayloadConfigBuilder := preload("res://scripts/stages/stage2/stage2_water_cannon_payload_config_builder.gd")
const Stage2WaterTrailPayloadFactory := preload("res://scripts/stages/stage2/stage2_water_trail_payload_factory.gd")
const Stage2RockFragmentPayloadFactory := preload("res://scripts/stages/stage2/stage2_rock_fragment_payload_factory.gd")
const Stage2RockFragmentPayloadConfigBuilder := preload("res://scripts/stages/stage2/stage2_rock_fragment_payload_config_builder.gd")
const Stage2RockFragmentMotionState := preload("res://scripts/stages/stage2/stage2_rock_fragment_motion_state.gd")
const Stage2QuakeRockPayloadFactory := preload("res://scripts/stages/stage2/stage2_quake_rock_payload_factory.gd")
const Stage2QuakeRockSpawnFactory := preload("res://scripts/stages/stage2/stage2_quake_rock_spawn_factory.gd")
const Stage2CrisisRockWallPayloadFactory := preload("res://scripts/stages/stage2/stage2_crisis_rock_wall_payload_factory.gd")
const Stage2QuakeRockDropState := preload("res://scripts/stages/stage2/stage2_quake_rock_drop_state.gd")
const Stage2QuakeRockOffsetState := preload("res://scripts/stages/stage2/stage2_quake_rock_offset_state.gd")
const Stage2WaterFragmentHitResolver := preload("res://scripts/stages/stage2/stage2_water_fragment_hit_resolver.gd")
const Stage2StarpointParticleState := preload("res://scripts/stages/stage2/stage2_starpoint_particle_state.gd")
const Stage2AmbientPayloadFactory := preload("res://scripts/stages/stage2/stage2_ambient_payload_factory.gd")
const Stage2AmbientLayoutHelper := preload("res://scripts/stages/stage2/stage2_ambient_layout_helper.gd")
const Stage2RustlePayloadFactory := preload("res://scripts/stages/stage2/stage2_rustle_payload_factory.gd")
const Stage2RustleSnapshotBuilder := preload("res://scripts/stages/stage2/stage2_rustle_snapshot_builder.gd")
const Stage2RustleState := preload("res://scripts/stages/stage2/stage2_rustle_state.gd")
const Stage2ActorDrawContextBuilder := preload("res://scripts/stages/stage2/stage2_actor_draw_context_builder.gd")
const Stage2ImagegenAssetStatusBuilder := preload("res://scripts/stages/stage2/stage2_imagegen_asset_status_builder.gd")
const Stage2AmbientVisualSnapshotBuilder := preload("res://scripts/stages/stage2/stage2_ambient_visual_snapshot_builder.gd")
const Stage2BossAiContextBuilder := preload("res://scripts/stages/stage2/stage2_boss_ai_context_builder.gd")
const Stage2BossRageSnapshotBuilder := preload("res://scripts/stages/stage2/stage2_boss_rage_snapshot_builder.gd")
const Stage2BossRageState := preload("res://scripts/stages/stage2/stage2_boss_rage_state.gd")
const Stage2PerfLogSnapshotBuilder := preload("res://scripts/stages/stage2/stage2_perf_log_snapshot_builder.gd")
const Stage2PerfLogger := preload("res://scripts/stages/stage2/stage2_perf_logger.gd")
const Stage2PerfCounterRecorder := preload("res://scripts/stages/stage2/stage2_perf_counter_recorder.gd")
const Stage2CollisionGeometry := preload("res://scripts/stages/stage2/stage2_collision_geometry.gd")
const Stage2PlayfieldBounds := preload("res://scripts/stages/stage2/stage2_playfield_bounds.gd")
const Stage2BossExpressionState := preload("res://scripts/stages/stage2/stage2_boss_expression_state.gd")
const Stage2SkillWarningState := preload("res://scripts/stages/stage2/stage2_skill_warning_state.gd")
const Stage2BorderFlashState := preload("res://scripts/stages/stage2/stage2_border_flash_state.gd")
const Stage2FragmentHitFlashState := preload("res://scripts/stages/stage2/stage2_fragment_hit_flash_state.gd")
const Stage2RockQuery := preload("res://scripts/stages/stage2/stage2_rock_query.gd")
const Stage2VisibilityState := preload("res://scripts/stages/stage2/stage2_visibility_state.gd")
const Stage2QuakeScreenShakeState := preload("res://scripts/stages/stage2/stage2_quake_screen_shake_state.gd")
const Stage2QuakeBallMotionState := preload("res://scripts/stages/stage2/stage2_quake_ball_motion_state.gd")

const MAX_LEAF_PARTICLES := 120
const LEAF_PARTICLE_RENDER_LIMIT := 16
const LEAF_PARTICLE_RENDER_LIMIT_SEVERE_LOD := 8
const AMBIENT_INITIAL_LEAF_COUNT := 3
const AMBIENT_FIREFLY_COUNT := 6
const AMBIENT_MAX_FALLING_LEAVES := 5
const AMBIENT_FALLING_LEAF_RENDER_LIMIT := 5
const AMBIENT_FALLING_LEAF_RENDER_LIMIT_SEVERE_LOD := 0
const AMBIENT_LEAF_SPAWN_RATE := 0.0015
const MAX_ROCK_FRAGMENTS := 180
const ROCK_FRAGMENT_RENDER_LIMIT := 16
const ROCK_FRAGMENT_RENDER_LIMIT_SEVERE_LOD := 12
const LEAF_PARTICLE_LIFE_SEC := 0.95
const ROCK_FRAGMENT_LIFE_SEC := 45.0 / 60.0
const BORDER_FLASH_DURATION_SEC := 0.22
const QUAKE_DURATION_SEC := 80.0 / 60.0
const QUAKE_INITIAL_COOLDOWN_SEC := 0.0
const PISTOL_ROCK_BOUNCE_MAX := 2
const PISTOL_ROCK_BOUNCE_DAMPING := 0.88
const PISTOL_ROCK_BOUNCE_MIN_SPEED := 6.0
const PISTOL_ROCK_BOUNCE_EPSILON := 0.1
const QUAKE_REPEAT_COOLDOWN_SEC := 4.0
const ROCK_LIFE_SEC := -1.0
const QUAKE_ROCK_DROP_HEIGHT := 185.0
const QUAKE_ROCK_DROP_TIME_SEC := 0.42
const QUAKE_ROCK_DROP_STAGGER_SEC := 0.07
const QUAKE_ROCK_LAND_FLASH_SEC := 0.34
const QUAKE_ROCK_SIZE_SCALE := 0.50
const ROCK_IMAGEGEN_MIN_LONG_SIDE := 14.0
const MAX_ROCKS := 8
const WATER_CANNON_AFTER_QUAKE_DELAY_SEC := 7.0
const WATER_CANNON_CHARGE_SEC := 0.80
const WATER_CANNON_FIRE_SEC := 0.50
const WATER_TRAIL_LIFE_SEC := 0.38
const WATER_TRAIL_MAX_COUNT := 32
const WATER_SPLASH_LIFE_SEC := 1.0
const WATER_FRAGMENT_HIT_FLASH_SEC := 0.24
const SKILL_WARNING_DEFAULT_SEC := 1.15
const SKILL_WARNING_FRAGMENT_SEC := 0.90
const WATER_CANNON_ROCK_FRAGMENT_MIN_COUNT := 20
const WATER_CANNON_ROCK_FRAGMENT_MAX_COUNT := 25
const WATER_CANNON_WATER_SPLASH_MIN_COUNT := 15
const WATER_CANNON_WATER_SPLASH_MAX_COUNT := 20
const WATER_CANNON_ROCK_FRAGMENT_LIFE_SEC := 100.0 / 60.0
const WATER_CANNON_WATER_SPLASH_LIFE_SEC := 60.0 / 60.0
const WATER_CANNON_ROCK_FRAGMENT_GRAVITY := 0.5 * 60.0 * 60.0
const WATER_CANNON_WATER_SPLASH_GRAVITY := 0.3 * 60.0 * 60.0
const WATER_CANNON_MAX_SPLASHES := 64
const WATER_SPLASH_RENDER_LIMIT := 8
const WATER_SPLASH_RENDER_LIMIT_SEVERE_LOD := 6
const WATER_FRAGMENT_PLAYER_KNOCKBACK_SPEED := 20.0
const WATER_FRAGMENT_PLAYER_KNOCKBACK_FRAMES := 40.0
const WATER_FRAGMENT_PLAYER_KNOCKBACK_DECAY := 0.85
const STARPOINT_DROP_SIZE := 12.0
const STARPOINT_DROP_LIFETIME := 600.0
const STARPOINT_DROP_ACCELERATION := 0.25
const STARPOINT_DROP_MAX_FALL_SPEED := 12.0
const STARPOINT_DROP_BOUNCE_DAMPING := 0.7
const STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES := [-36.0, -24.0, 24.0, 36.0]
const STARPOINT_PARTICLE_COUNT := 20
const STARPOINT_PARTICLE_LIFE := 60.0
const STARPOINT_PARTICLE_RENDER_LIMIT := 12
const STARPOINT_PARTICLE_RENDER_LIMIT_SEVERE_LOD := 6
const QUAKE_BOSS_LAUNCH_GUARD_SEC := 22.0 / 60.0
const QUAKE_BOSS_BACKSTOP_SEC := 6.0 / 60.0
const QUAKE_BALL_SHAKE_SCALE := 0.95
const QUAKE_BALL_MAX_SPEED := 12.5
const QUAKE_BALL_EFFECTIVE_SPEED_CAP := 5.0
const QUAKE_BALL_REFERENCE_BASE_SPEED := 9.0
const QUAKE_WAVE_COUNT := 4
const QUAKE_WAVE_SEGMENTS := 8
const VISUAL_ONLY_QUAKE_WAVE_COUNT := 2
const VISUAL_ONLY_QUAKE_WAVE_SEGMENTS := 5
const LOD_ACTIVE_THRESHOLD := 0.85
const SEVERE_LOD_ACTIVE_THRESHOLD := 0.66
const CHAOS_ROCK_PULL_REFRESH_SEC := 0.18
const CHAOS_ROCK_DESTROY_DISTANCE := 14.0
const CHAOS_ROCK_ANGULAR_SPEED_MAX := 0.22
const CHAOS_ROCK_ANGULAR_SPEED_NUMERATOR := 8.0
const CHAOS_ROCK_RADIAL_SPEED_MIN := 4.0
const CHAOS_ROCK_RADIAL_SPEED_MAX := 22.0
const CHAOS_ROCK_RADIAL_SPEED_NUMERATOR := 460.0
const CHAOS_ROCK_SPIN_MULTIPLIER := 1.8
const CRISIS_PLAYER_SCORE := 4
const BOSS_RAGE_STOMP_INTERVAL_SEC := 15.0 / 60.0
const BOSS_RAGE_BUILDUP_SEC := 60.0 / 60.0
const BOSS_RAGE_FINAL_STOMP_SEC := 80.0 / 60.0
const BOSS_RAGE_TOTAL_SEC := 100.0 / 60.0
const BOSS_RAGE_CRISIS_ROCK_COUNT_CHAMPION := 3
const BOSS_RAGE_CRISIS_ROCK_COUNT_MYTHIC := 5
const CRISIS_ROCK_WALL_Y_MIN := 12.0
const CRISIS_ROCK_WALL_Y_MID := 29.0
const CRISIS_ROCK_WALL_Y_MAX := 46.0
const BOSS_EXPRESSION_DURATION_SEC := 2.0
const BUSH_RUSTLE_RANGE := 150.0
const VINE_RUSTLE_RANGE := 120.0
const BUSH_RUSTLE_NORMAL := 8.0
const BUSH_RUSTLE_DASH := 15.0
const VINE_RUSTLE_NORMAL := 7.0
const VINE_RUSTLE_DASH := 12.0
const BUSH_SIDE_WALL_BAND_Y := 135.0
var base_texture: Texture2D = null
var tree_texture: Texture2D = null
var game_frame_texture: Texture2D = null
var leaf_texture: Texture2D = null
var rock_texture: Texture2D = null
var rock_debris_texture: Texture2D = null
var texture_loaded := false
var _prewarm_assets_done := false
var _prewarm_step_index := 0
var imagegen_renderer: Object = Stage2PillarImagegenRenderer.new()
var imagegen_assets_builder: Object = Stage2PillarImagegenAssetsBuilder.new()
var obstacle_visual_renderer: Object = Stage2PillarObstacleVisualRenderer.new()
var water_cannon_visual_renderer: Object = Stage2WaterCannonVisualRenderer.new()
var warning_visual_renderer: Object = Stage2WarningVisualRenderer.new()
var screen_overlay_visual_renderer: Object = Stage2ScreenOverlayVisualRenderer.new()
var ambient_visual_renderer: Object = Stage2AmbientVisualRenderer.new()
var rock_visual_factory: Object = Stage2RockVisualFactory.new()
var rock_visual_assets_builder: Object = Stage2RockVisualAssetsBuilder.new()
var starpoint_visual_factory: Object = Stage2StarpointVisualFactory.new()
var water_cannon_geometry: Object = Stage2WaterCannonGeometry.new()
var water_cannon_visual_state_builder: Object = Stage2WaterCannonVisualStateBuilder.new()
var quake_wave_visual_state_builder: Object = Stage2QuakeWaveVisualStateBuilder.new()
var water_cannon_payload_factory: Object = Stage2WaterCannonPayloadFactory.new()
var water_cannon_payload_config_builder: Object = Stage2WaterCannonPayloadConfigBuilder.new()
var water_trail_payload_factory: Object = Stage2WaterTrailPayloadFactory.new()
var rock_fragment_payload_factory: Object = Stage2RockFragmentPayloadFactory.new()
var rock_fragment_payload_config_builder: Object = Stage2RockFragmentPayloadConfigBuilder.new()
var quake_rock_payload_factory: Object = Stage2QuakeRockPayloadFactory.new()
var quake_rock_spawn_factory: Object = Stage2QuakeRockSpawnFactory.new()
var crisis_rock_wall_payload_factory: Object = Stage2CrisisRockWallPayloadFactory.new()
var ambient_payload_factory: Object = Stage2AmbientPayloadFactory.new()
var ambient_layout_helper: Object = Stage2AmbientLayoutHelper.new()
var rustle_payload_factory: Object = Stage2RustlePayloadFactory.new()
var rustle_snapshot_builder: Object = Stage2RustleSnapshotBuilder.new()
var actor_draw_context_builder: Object = Stage2ActorDrawContextBuilder.new()
var imagegen_asset_status_builder: Object = Stage2ImagegenAssetStatusBuilder.new()
var ambient_visual_snapshot_builder: Object = Stage2AmbientVisualSnapshotBuilder.new()
var boss_ai_context_builder: Object = Stage2BossAiContextBuilder.new()
var boss_rage_snapshot_builder: Object = Stage2BossRageSnapshotBuilder.new()
var perf_log_snapshot_builder: Object = Stage2PerfLogSnapshotBuilder.new()
var perf_logger: Object = Stage2PerfLogger.new()
var collision_geometry: Object = Stage2CollisionGeometry.new()
var playfield_bounds: Object = Stage2PlayfieldBounds.new()
var boss_expression_state: Object = Stage2BossExpressionState.new()
var skill_warning_state: Object = Stage2SkillWarningState.new()
var border_flash_state: Object = Stage2BorderFlashState.new()
var fragment_hit_flash_state: Object = Stage2FragmentHitFlashState.new()
var rock_query: Object = Stage2RockQuery.new()
var tree_source_regions: Dictionary = {}
var leaf_source_regions: Array = []
var rock_source_regions: Array = []
var rock_debris_source_regions: Array = []
var game_frame_hole := Rect2()
var game_frame_hole_checked := false
var ambient_rng := RandomNumberGenerator.new()
var ambient_time := 0.0
var excitement := 0.0
var ambient_layout_size := Vector2.ZERO
var ambient_game_offset := Vector2.ZERO
var ambient_game_size := Vector2.ZERO
var falling_leaves: Array = []
var fireflies: Array = []
var leaf_particles: Array = []
var rocks: Array = []
var rock_fragments: Array = []
var starpoint_drops: Array = []
var starpoint_particles: Array = []
var rustle_bushes: Array = []
var rustle_vines: Array = []
var rustle_layout_size := Vector2.ZERO
var prev_boss_paddle_center_x := 380.0
var prev_player_paddle_center_x := 380.0
var boss_paddle_center_valid := false
var player_paddle_center_valid := false
var water_trail: Array = []
var water_splashes: Array = []
var quake_timer := 0.0
var quake_duration := QUAKE_DURATION_SEC
var quake_cooldown := QUAKE_INITIAL_COOLDOWN_SEC
var quake_motion_rng := RandomNumberGenerator.new()
var quake_ball_rng := RandomNumberGenerator.new()
var quake_ball_velocity_backup := Vector2.ZERO
var quake_ball_velocity_backup_valid := false
var quake_boss_launch_guard_timer := 0.0
var quake_affects_ball := false
var quake_audio_active := false
var water_cannon_delay := -1.0
var water_cannon_phase := "idle"
var water_cannon_timer := 0.0
var water_cannon_target_id := -1
var water_cannon_start := Vector2.ZERO
var water_cannon_target := Vector2.ZERO
var water_cannon_current := Vector2.ZERO
var water_cannon_progress := 0.0
var chaos_rock_absorb_center := Vector2.ZERO
var chaos_rock_absorb_timer := 0.0
var chaos_absorbed_entries: Array = []
var rock_next_id := 1
var crisis_triggered := false
var boss_rage_pending := false
var boss_rage_active := false
var boss_rage_timer := 0.0
var boss_rage_stomp_count := 0
var boss_rage_final_stomp_done := false
var boss_rage_offset_y := 0.0
var boss_rage_tint := 0.0
var boss_rage_ai_mode := "champion"
# Cached audio handle: rage / quake start when ball is not yet active (waiting_for_serve),
# so battle_effects_update_controller passes an effect_deps with audio=null. We capture
# the live audio reference at activation time and use it as a fallback so the cry / quake
# SFX are not silently dropped during the pre-rally rage animation.
var rage_audio: Object = null
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 2202
	quake_motion_rng.seed = 2204
	quake_ball_rng.seed = 2205
	ambient_rng.seed = 2206


func reset() -> void:
	falling_leaves.clear()
	fireflies.clear()
	ambient_layout_size = Vector2.ZERO
	ambient_game_offset = Vector2.ZERO
	ambient_game_size = Vector2.ZERO
	ambient_time = 0.0
	excitement = 0.0
	leaf_particles.clear()
	rocks.clear()
	rock_fragments.clear()
	var had_starpoints := not starpoint_drops.is_empty() or not starpoint_particles.is_empty()
	starpoint_drops.clear()
	starpoint_particles.clear()
	if had_starpoints:
		obstacle_visual_renderer.hide_all_starpoint_drops()
	_reset_rustle_state()
	water_trail.clear()
	water_splashes.clear()
	border_flash_state.reset(BORDER_FLASH_DURATION_SEC)
	quake_timer = 0.0
	quake_duration = QUAKE_DURATION_SEC
	quake_cooldown = QUAKE_INITIAL_COOLDOWN_SEC
	quake_ball_velocity_backup = Vector2.ZERO
	quake_ball_velocity_backup_valid = false
	quake_boss_launch_guard_timer = 0.0
	quake_affects_ball = false
	water_cannon_delay = -1.0
	water_cannon_phase = "idle"
	water_cannon_timer = 0.0
	water_cannon_target_id = -1
	water_cannon_progress = 0.0
	chaos_rock_absorb_center = Vector2.ZERO
	chaos_rock_absorb_timer = 0.0
	chaos_absorbed_entries.clear()
	fragment_hit_flash_state.reset(WATER_FRAGMENT_HIT_FLASH_SEC)
	skill_warning_state.reset(SKILL_WARNING_DEFAULT_SEC)
	rock_next_id = 1
	crisis_triggered = false
	boss_rage_pending = false
	boss_rage_active = false
	boss_rage_timer = 0.0
	boss_rage_stomp_count = 0
	boss_rage_final_stomp_done = false
	boss_rage_offset_y = 0.0
	boss_rage_tint = 0.0
	boss_rage_ai_mode = "champion"
	rage_audio = null
	boss_expression_state.reset()


func reset_round(deps: Dictionary = {}) -> void:
	_clear_quake_round_state(deps)
	water_cannon_delay = -1.0
	_cancel_water_cannon()
	water_trail.clear()
	water_splashes.clear()
	fragment_hit_flash_state.reset(WATER_FRAGMENT_HIT_FLASH_SEC)


func update(delta: float, context: Dictionary = {}, deps: Dictionary = {}) -> void:
	var perf_start := _perf_begin()
	var clamped_delta: float = max(0.0, delta)
	_update_ambient_visuals(clamped_delta)
	_update_boss_expression(clamped_delta)
	_update_rustle_reactions(clamped_delta, context)
	_check_crisis_situation(context)
	_update_boss_rage(clamped_delta, deps)
	border_flash_state.update(clamped_delta)
	fragment_hit_flash_state.update(clamped_delta)
	skill_warning_state.update(clamped_delta)
	if quake_timer > 0.0:
		quake_timer = max(0.0, quake_timer - clamped_delta)
		var feedback: Object = deps.get("feedback", null)
		if feedback != null:
			if feedback.has_method("push_fixed_shake_offset"):
				feedback.push_fixed_shake_offset(Stage2QuakeScreenShakeState.get_offset(quake_timer, quake_duration, quake_motion_rng))
			elif feedback.has_method("max_screen_shake"):
				var ratio: float = quake_timer / max(0.001, quake_duration)
				feedback.max_screen_shake(0.040 + ratio * 0.025, 1.6 + ratio * 1.2)
	elif (
		deps.get("stage2_boss_skill_state", null) == null
		and int(context.get("current_stage", 1)) == 2
		and bool(context.get("ball_active", false))
	):
		quake_cooldown = max(0.0, quake_cooldown - clamped_delta)
	_sync_quake_audio(deps)
	chaos_rock_absorb_timer = max(0.0, chaos_rock_absorb_timer - clamped_delta)

	Stage2AmbientVisualState.update_leaf_particles(leaf_particles, clamped_delta)

	var fps_scale: float = clamped_delta * 60.0
	_update_starpoint_drops(fps_scale, context, deps)
	_update_starpoint_particles(fps_scale)

	for idx in range(rocks.size() - 1, -1, -1):
		var rock: Dictionary = rocks[idx]
		var life: float = float(rock.get("life", ROCK_LIFE_SEC))
		if life >= 0.0:
			life -= clamped_delta
			if life <= 0.0:
				_spawn_rock_leaves(rock_query.get_center(rock), 0.70)
				rocks.remove_at(idx)
				continue
			rock["life"] = life
		if bool(rock.get("chaos_absorbing", false)):
			if chaos_rock_absorb_timer <= 0.0:
				rock["chaos_absorbing"] = false
				rocks[idx] = rock
				continue
			if _update_chaos_absorbing_rock(rock, clamped_delta, deps, context):
				rocks.remove_at(idx)
				continue
			rocks[idx] = rock
			continue
		if not rock_query.needs_runtime_update(rock, quake_timer > 0.0):
			continue
		Stage2RockRuntimeState.update_visual_timers(rock, clamped_delta)
		_update_quake_rock_drop(rock, clamped_delta)
		Stage2QuakeRockOffsetState.update_offset(rock, clamped_delta, quake_timer, quake_duration)
		rocks[idx] = rock
	_update_rock_fragments(clamped_delta)
	_update_water_cannon(clamped_delta, context, deps)
	_update_water_visuals(clamped_delta)
	_resolve_water_fragment_player_hits(context, deps)
	_perf_end("stage2_update", perf_start)
	_perf_maybe_log(context)


func activate_quake(
	duration_sec: float = QUAKE_DURATION_SEC,
	rock_count: int = MAX_ROCKS,
	schedule_water_cannon: bool = true,
	start_boss_launch_guard: bool = false,
	deps: Dictionary = {}
) -> bool:
	quake_duration = max(0.2, duration_sec)
	quake_timer = quake_duration
	quake_cooldown = QUAKE_REPEAT_COOLDOWN_SEC
	quake_ball_velocity_backup = Vector2.ZERO
	quake_ball_velocity_backup_valid = false
	quake_boss_launch_guard_timer = QUAKE_BOSS_LAUNCH_GUARD_SEC if start_boss_launch_guard else 0.0
	quake_affects_ball = true
	quake_ball_rng.randomize()
	var activation_audio: Object = deps.get("audio", null)
	if activation_audio != null:
		rage_audio = activation_audio
	var available_rock_slots: int = max(0, MAX_ROCKS - rocks.size())
	var spawn_count: int = min(clampi(rock_count, 0, MAX_ROCKS), available_rock_slots)
	if spawn_count > 0:
		_spawn_quake_rocks(spawn_count, deps)
	water_cannon_delay = WATER_CANNON_AFTER_QUAKE_DELAY_SEC if schedule_water_cannon and not rocks.is_empty() else -1.0
	skill_warning_state.trigger("quake", "정글지진!", 1.35)
	_play_quake_audio(deps)
	return true


func apply_quake_ball_motion(scene: Dictionary, context: Dictionary, _deps: Dictionary = {}, fps_scale: float = 1.0) -> bool:
	if int(context.get("current_stage", 1)) != 2:
		return false
	if not quake_affects_ball:
		return false
	if quake_timer <= 0.0:
		return _restore_quake_ball_velocity(scene, context)

	var ball_vel: Vector2 = _get_vector2(scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	_capture_quake_ball_velocity_backup(ball_vel, context)

	var effective_timer: float = max(0.0, quake_timer - max(1.0, fps_scale) / 60.0)
	var quake_progress: float = 1.0 - (effective_timer / max(0.001, quake_duration))
	var impulse_scale: float = Stage2QuakeBallMotionState.get_impulse_scale(quake_progress)
	var elapsed_frames: float = max(0.0, quake_duration - effective_timer) * 60.0
	var shake_x: float = quake_ball_rng.randf_range(-7.6, 7.6) * QUAKE_BALL_SHAKE_SCALE * impulse_scale
	var shake_y: float = quake_ball_rng.randf_range(-5.2, 5.2) * QUAKE_BALL_SHAKE_SCALE * impulse_scale
	ball_vel.x += shake_x + sin(elapsed_frames * 0.95) * 0.95 * impulse_scale
	ball_vel.y += shake_y + cos(elapsed_frames * 1.2) * 0.72 * impulse_scale
	ball_vel = Stage2QuakeBallMotionState.apply_player_pull(ball_vel, ball_pos, context)
	ball_vel.x = clamp(ball_vel.x, -QUAKE_BALL_MAX_SPEED, QUAKE_BALL_MAX_SPEED)
	ball_vel.y = clamp(ball_vel.y, -QUAKE_BALL_MAX_SPEED, QUAKE_BALL_MAX_SPEED)
	ball_vel = _apply_quake_boss_launch_guard(scene, context, ball_vel, fps_scale)
	ball_vel = Stage2QuakeBallMotionState.apply_original_speed_cap(scene, ball_vel, QUAKE_BALL_EFFECTIVE_SPEED_CAP)
	scene["ball_vel"] = ball_vel
	return true


func force_end_quake_on_player_hit(deps: Dictionary = {}) -> void:
	_clear_quake_round_state(deps)


func _clear_quake_round_state(deps: Dictionary = {}) -> void:
	quake_timer = 0.0
	quake_ball_velocity_backup = Vector2.ZERO
	quake_ball_velocity_backup_valid = false
	quake_boss_launch_guard_timer = 0.0
	quake_affects_ball = false
	_stop_quake_audio(deps)


func start_boss_rage_animation(deps: Dictionary = {}) -> bool:
	if not boss_rage_pending or boss_rage_active:
		return false
	boss_rage_pending = false
	boss_rage_active = true
	boss_rage_timer = 0.0
	boss_rage_stomp_count = 0
	boss_rage_final_stomp_done = false
	boss_rage_offset_y = 0.0
	boss_rage_tint = 0.0
	rage_audio = deps.get("audio", null)
	skill_warning_state.trigger("rage", "악어장군 분노!", 1.25)
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(0.055, 2.2)
	return true


func set_expression(expression: String, duration_sec: float = BOSS_EXPRESSION_DURATION_SEC) -> void:
	boss_expression_state.set_expression(expression, duration_sec)


func resolve_quake_boss_backstop(scene: Dictionary, context: Dictionary, deps: Dictionary = {}) -> bool:
	if int(context.get("current_stage", 1)) != 2 or quake_timer <= 0.0 or not quake_affects_ball or not _was_last_hit_by_boss(deps):
		return false
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var ball_radius: float = float(context.get("ball_size", 28.6)) * 0.5
	if ball_pos.y - ball_radius > 0.0:
		return false

	quake_boss_launch_guard_timer = max(quake_boss_launch_guard_timer, QUAKE_BOSS_BACKSTOP_SEC)
	var ball_vel: Vector2 = _get_vector2(scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	ball_vel = _apply_quake_boss_launch_guard(scene, context, ball_vel, 1.0)
	ball_vel = Stage2QuakeBallMotionState.apply_original_speed_cap(scene, ball_vel, QUAKE_BALL_EFFECTIVE_SPEED_CAP)
	ball_pos = _get_vector2(scene.get("ball_pos", ball_pos), ball_pos)
	if ball_pos.y - ball_radius <= 0.0:
		var boss_pos: Vector2 = _get_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
		var boss_bottom: float = boss_pos.y + float(context.get("boss_hitbox_height", 40.0))
		ball_pos.y = boss_bottom + max(6.0, ball_radius + 2.0) + ball_radius
		scene["ball_pos"] = ball_pos
	var base_speed: float = QUAKE_BALL_REFERENCE_BASE_SPEED
	ball_vel.y = max(abs(ball_vel.y), base_speed * 0.65)
	ball_vel = Stage2QuakeBallMotionState.apply_original_speed_cap(scene, ball_vel, QUAKE_BALL_EFFECTIVE_SPEED_CAP)
	scene["ball_vel"] = ball_vel
	return true


func activate_water_cannon(context: Dictionary = {}, _deps: Dictionary = {}) -> bool:
	if water_cannon_phase != "idle" or rocks.is_empty():
		return false
	water_cannon_target_id = rock_query.select_random_id(rocks, rng)
	if water_cannon_target_id < 0:
		return false
	var target_rock: Dictionary = rock_query.get_by_id(rocks, water_cannon_target_id)
	if target_rock.is_empty():
		return false
	water_cannon_start = water_cannon_geometry.get_boss_cannon_start_from_context(context)
	water_cannon_target = rock_query.get_center(target_rock)
	water_cannon_current = water_cannon_start
	water_cannon_progress = 0.0
	water_cannon_phase = "charging"
	water_cannon_timer = WATER_CANNON_CHARGE_SEC
	water_cannon_delay = -1.0
	Stage2RockRuntimeState.mark_water_target(rocks, water_cannon_target_id)
	skill_warning_state.trigger("water_charge", "물대포 조준!", WATER_CANNON_CHARGE_SEC + 0.22)
	return true


func trigger_tree_shake(side: String, impact_y: float, impact_speed: float, field_height: float) -> void:
	var resolved_side: String = side
	if resolved_side == "":
		resolved_side = "left"
	var height: float = max(1.0, field_height)
	var y: float = clamp(impact_y, 20.0, height - 20.0)
	var x: float = 18.0 if resolved_side == "left" else 742.0
	if resolved_side not in ["left", "right"]:
		return

	border_flash_state.trigger(resolved_side, y, BORDER_FLASH_DURATION_SEC)

	if not Stage2RustleState.is_bush_side_wall_hit(y, height, BUSH_SIDE_WALL_BAND_Y):
		return
	var speed_scale: float = clamp(abs(impact_speed) / 520.0, 0.55, 1.65)
	excitement = min(2.0, max(excitement, 1.0 + speed_scale * 0.35))
	for _ambient_idx in range(2):
		_spawn_ambient_leaf()
	var count: int = clampi(int(round(10.0 + speed_scale * 9.0)), 10, 26)
	for _i in range(count):
		_spawn_leaf_particle(Vector2(x, y), resolved_side, speed_scale)
	Stage2RenderBudgetHelper.trim_array_from_front(leaf_particles, MAX_LEAF_PARTICLES)


func draw_playfield_overlay(
	canvas: CanvasItem,
	context: Dictionary,
	shake_offset: Vector2 = Vector2.ZERO,
	battle_perf_logger: Object = null
) -> void:
	var perf_start := _perf_begin()
	if canvas == null:
		_perf_end("stage2_overlay_draw", perf_start)
		return
	if not has_visible_playfield_overlay():
		obstacle_visual_renderer.hide_starpoint_drops(canvas)
		_perf_end("stage2_overlay_draw", perf_start)
		return
	_record_playfield_overlay_counters(battle_perf_logger)
	var width: float = float(context.get("width", 760.0))
	var height: float = float(context.get("height", 750.0))
	var quality_scale: float = Stage2RenderBudgetHelper.get_playfield_quality_scale(context)
	var battle_sample_start: int
	if border_flash_state.is_active():
		battle_sample_start = _battle_perf_begin(battle_perf_logger)
		screen_overlay_visual_renderer.draw_border_flash(canvas, width, height, shake_offset, border_flash_state.get_snapshot())
		_battle_perf_end(battle_perf_logger, "stage2.overlay.border_flash", battle_sample_start)
	if boss_rage_active or boss_rage_tint > 0.001:
		battle_sample_start = _battle_perf_begin(battle_perf_logger)
		screen_overlay_visual_renderer.draw_boss_rage_screen_tint(canvas, width, height, shake_offset, boss_rage_tint)
		_battle_perf_end(battle_perf_logger, "stage2.overlay.rage_tint", battle_sample_start)
	if not leaf_particles.is_empty():
		battle_sample_start = _battle_perf_begin(battle_perf_logger)
		ambient_visual_renderer.draw_leaf_particles(canvas, leaf_particles, shake_offset, LEAF_PARTICLE_LIFE_SEC, Stage2RenderBudgetHelper.get_lod_count(
			LEAF_PARTICLE_RENDER_LIMIT,
			LEAF_PARTICLE_RENDER_LIMIT,
			LEAF_PARTICLE_RENDER_LIMIT_SEVERE_LOD,
			quality_scale,
			LOD_ACTIVE_THRESHOLD,
			SEVERE_LOD_ACTIVE_THRESHOLD
		))
		_battle_perf_end(battle_perf_logger, "stage2.overlay.leaf_particles", battle_sample_start)
	if not starpoint_particles.is_empty():
		battle_sample_start = _battle_perf_begin(battle_perf_logger)
		obstacle_visual_renderer.draw_starpoint_particles(canvas, starpoint_particles, shake_offset, Stage2RenderBudgetHelper.get_lod_count(
			STARPOINT_PARTICLE_RENDER_LIMIT,
			STARPOINT_PARTICLE_RENDER_LIMIT,
			STARPOINT_PARTICLE_RENDER_LIMIT_SEVERE_LOD,
			quality_scale,
			LOD_ACTIVE_THRESHOLD,
			SEVERE_LOD_ACTIVE_THRESHOLD
		))
		_battle_perf_end(battle_perf_logger, "stage2.overlay.starpoint_particles", battle_sample_start)
	if not starpoint_drops.is_empty():
		battle_sample_start = _battle_perf_begin(battle_perf_logger)
		var starpoint_game_offset_value: Variant = context.get("game_offset", Vector2.ZERO)
		var starpoint_game_offset: Vector2 = starpoint_game_offset_value if starpoint_game_offset_value is Vector2 else Vector2.ZERO
		var starpoint_render_scale: float = maxf(0.001, float(context.get("render_scale", 1.0)))
		obstacle_visual_renderer.draw_starpoint_drops(
			canvas,
			starpoint_drops,
			shake_offset,
			starpoint_game_offset,
			starpoint_render_scale
		)
		_battle_perf_end(battle_perf_logger, "stage2.overlay.starpoint_drops", battle_sample_start)
	else:
		obstacle_visual_renderer.hide_starpoint_drops(canvas)
	if fragment_hit_flash_state.get_timer() > 0.0:
		battle_sample_start = _battle_perf_begin(battle_perf_logger)
		water_cannon_visual_renderer.draw_fragment_hit_flash(
			canvas,
			width,
			height,
			shake_offset,
			fragment_hit_flash_state.get_timer(),
			fragment_hit_flash_state.get_duration()
		)
		_battle_perf_end(battle_perf_logger, "stage2.overlay.fragment_flash", battle_sample_start)
	if skill_warning_state.is_active():
		battle_sample_start = _battle_perf_begin(battle_perf_logger)
		warning_visual_renderer.draw_skill_warning_banner(canvas, width, height, shake_offset, get_skill_warning_snapshot())
		_battle_perf_end(battle_perf_logger, "stage2.overlay.skill_warning", battle_sample_start)
	_perf_end("stage2_overlay_draw", perf_start)


func draw_playfield_obstacles(
	canvas: CanvasItem,
	context: Dictionary,
	shake_offset: Vector2 = Vector2.ZERO,
	battle_perf_logger: Object = null
) -> void:
	var perf_start := _perf_begin()
	if canvas == null:
		_perf_end("stage2_obstacle_draw", perf_start)
		return
	if not has_visible_playfield_obstacles():
		_perf_end("stage2_obstacle_draw", perf_start)
		return
	_record_playfield_obstacle_counters(battle_perf_logger)
	var width: float = float(context.get("width", 760.0))
	var quality_scale: float = Stage2RenderBudgetHelper.get_playfield_quality_scale(context)
	var battle_sample_start: int
	if quake_timer > 0.0:
		battle_sample_start = _battle_perf_begin(battle_perf_logger)
		var quake_wave_visual_state: Dictionary = quake_wave_visual_state_builder.build_state(
			quake_timer,
			quake_duration,
			quake_affects_ball,
			QUAKE_WAVE_COUNT,
			QUAKE_WAVE_SEGMENTS,
			VISUAL_ONLY_QUAKE_WAVE_COUNT,
			VISUAL_ONLY_QUAKE_WAVE_SEGMENTS
		)
		warning_visual_renderer.draw_quake_waves(canvas, width, shake_offset, quake_wave_visual_state)
		_battle_perf_end(battle_perf_logger, "stage2.obstacles.quake_waves", battle_sample_start)
	if water_cannon_target_id >= 0:
		battle_sample_start = _battle_perf_begin(battle_perf_logger)
		_draw_water_cannon_target_highlight(canvas, shake_offset)
		_battle_perf_end(battle_perf_logger, "stage2.obstacles.target_highlight", battle_sample_start)

	var rock_visual_assets := {}
	if not rocks.is_empty() or not rock_fragments.is_empty() or not water_splashes.is_empty():
		battle_sample_start = _battle_perf_begin(battle_perf_logger)
		rock_visual_assets = rock_visual_assets_builder.build_assets(
			rock_texture,
			rock_source_regions,
			rock_debris_texture,
			rock_debris_source_regions,
			ROCK_FRAGMENT_LIFE_SEC
		)
		_battle_perf_end(battle_perf_logger, "stage2.obstacles.assets", battle_sample_start)
	if not rocks.is_empty():
		battle_sample_start = _battle_perf_begin(battle_perf_logger)
		for rock in rocks:
			obstacle_visual_renderer.draw_rock(canvas, rock, shake_offset, rock_visual_assets)
		_battle_perf_end(battle_perf_logger, "stage2.obstacles.rocks", battle_sample_start)
	if not rock_fragments.is_empty():
		battle_sample_start = _battle_perf_begin(battle_perf_logger)
		var rock_fragment_render_limit := Stage2RenderBudgetHelper.get_lod_count(
			ROCK_FRAGMENT_RENDER_LIMIT,
			ROCK_FRAGMENT_RENDER_LIMIT,
			ROCK_FRAGMENT_RENDER_LIMIT_SEVERE_LOD,
			quality_scale,
			LOD_ACTIVE_THRESHOLD,
			SEVERE_LOD_ACTIVE_THRESHOLD
		)
		for fragment_index in range(Stage2RenderBudgetHelper.recent_start(rock_fragments, rock_fragment_render_limit), rock_fragments.size()):
			var fragment_value: Variant = rock_fragments[fragment_index]
			if not (fragment_value is Dictionary):
				continue
			var fragment: Dictionary = fragment_value
			obstacle_visual_renderer.draw_rock_fragment(canvas, fragment, shake_offset, rock_visual_assets)
		_battle_perf_end(battle_perf_logger, "stage2.obstacles.rock_fragments", battle_sample_start)
	if water_cannon_phase != "idle" or not water_trail.is_empty():
		battle_sample_start = _battle_perf_begin(battle_perf_logger)
		_draw_water_cannon(canvas, shake_offset)
		_battle_perf_end(battle_perf_logger, "stage2.obstacles.water_cannon", battle_sample_start)
	if not water_splashes.is_empty():
		battle_sample_start = _battle_perf_begin(battle_perf_logger)
		var water_splash_render_limit := Stage2RenderBudgetHelper.get_lod_count(
			WATER_SPLASH_RENDER_LIMIT,
			WATER_SPLASH_RENDER_LIMIT,
			WATER_SPLASH_RENDER_LIMIT_SEVERE_LOD,
			quality_scale,
			LOD_ACTIVE_THRESHOLD,
			SEVERE_LOD_ACTIVE_THRESHOLD
		)
		for splash_index in range(Stage2RenderBudgetHelper.recent_start(water_splashes, water_splash_render_limit), water_splashes.size()):
			var splash_value: Variant = water_splashes[splash_index]
			if not (splash_value is Dictionary):
				continue
			var splash: Dictionary = splash_value
			water_cannon_visual_renderer.draw_splash(
				canvas,
				splash,
				shake_offset,
				obstacle_visual_renderer,
				rock_visual_assets,
				WATER_SPLASH_LIFE_SEC
			)
		_battle_perf_end(battle_perf_logger, "stage2.obstacles.water_splashes", battle_sample_start)
	_perf_end("stage2_obstacle_draw", perf_start)


func resolve_ball_collision(scene: Dictionary, context: Dictionary, deps: Dictionary = {}) -> bool:
	if int(context.get("current_stage", 1)) != 2 or rocks.is_empty():
		return false
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var previous_ball_pos: Vector2 = _get_vector2(scene.get("previous_ball_pos", ball_pos), ball_pos)
	var ball_vel: Vector2 = _get_vector2(scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	var ball_radius: float = float(context.get("ball_size", 28.6)) * 0.5
	for idx in range(rocks.size()):
		var rock: Dictionary = rocks[idx]
		if not rock_query.is_landed(rock):
			continue
		var center: Vector2 = rock_query.get_center(rock)
		var radius: float = float(rock.get("radius", 28.0))
		if not collision_geometry.segment_hits_circle(previous_ball_pos, ball_pos, center, radius + ball_radius):
			continue
		var normal: Vector2 = (ball_pos - center)
		if normal.length_squared() <= 0.001:
			normal = -ball_vel.normalized() if ball_vel.length_squared() > 0.001 else Vector2.UP
		else:
			normal = normal.normalized()
		var speed: float = max(4.0, ball_vel.length())
		var reflected: Vector2 = ball_vel.bounce(normal)
		if reflected.length_squared() <= 0.001:
			reflected = normal * speed
		else:
			reflected = reflected.normalized() * speed
		scene["ball_vel"] = reflected
		scene["ball_pos"] = center + normal * (radius + ball_radius + 2.0)
		_hit_rock(idx, deps, context)
		return true
	return false


func resolve_blade_projectile_collision(blade_rect: Rect2, deps: Dictionary = {}, context: Dictionary = {}) -> int:
	if int(context.get("current_stage", 1)) != 2 or rocks.is_empty():
		return 0
	if blade_rect.size.x <= 0.0 or blade_rect.size.y <= 0.0:
		return 0
	var hit_count := 0
	for idx in range(rocks.size() - 1, -1, -1):
		var rock: Dictionary = rocks[idx]
		if not rock_query.is_landed(rock):
			continue
		var center: Vector2 = rock_query.get_center(rock)
		var radius: float = float(rock.get("radius", 28.0))
		if not collision_geometry.circle_rect_overlap(center, radius, blade_rect):
			continue
		# Blade projectiles slice Stage 2 rocks outright, even if future rocks gain extra HP.
		rock["hp"] = 1
		rocks[idx] = rock
		_hit_rock(idx, deps, context)
		hit_count += 1
	return hit_count


func resolve_explosion_rock_collision(center: Vector2, radius: float, deps: Dictionary = {}, context: Dictionary = {}) -> int:
	if int(context.get("current_stage", 1)) != 2 or rocks.is_empty():
		return 0
	if radius <= 0.0:
		return 0
	var hit_count := 0
	for idx in range(rocks.size() - 1, -1, -1):
		var rock: Dictionary = rocks[idx]
		if not rock_query.is_landed(rock):
			continue
		var rock_center: Vector2 = rock_query.get_center(rock)
		var rock_radius: float = max(0.0, float(rock.get("radius", float(rock.get("visual_radius", 28.0)) * 0.5)))
		if rock_center.distance_to(center) > radius + rock_radius:
			continue
		# Explosions break touched Stage 2 rocks outright, then reuse the normal reward/audio path.
		rock["hp"] = 1
		rocks[idx] = rock
		_hit_rock(idx, deps, context)
		hit_count += 1
	return hit_count


func resolve_pistol_projectile_rock_bounce(projectile: Dictionary, deps: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", 1)) != 2 or rocks.is_empty():
		return {"bounced": false}
	var pos: Vector2 = _get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var prev_pos: Vector2 = _get_vector2(projectile.get("prev_pos", pos), pos)
	var velocity: Vector2 = _get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	var projectile_radius: float = max(1.0, float(projectile.get("radius", 5.0)))
	var projectile_rect := Rect2(
		pos - Vector2(projectile_radius, projectile_radius),
		Vector2(projectile_radius * 2.0, projectile_radius * 2.0)
	)
	for idx in range(rocks.size()):
		var rock: Dictionary = rocks[idx]
		if not rock_query.is_landed(rock):
			continue
		var rock_center: Vector2 = rock_query.get_center(rock)
		var rock_radius: float = max(0.0, float(rock.get("radius", float(rock.get("visual_radius", 28.0)) * 0.5)))
		var rock_rect := Rect2(
			rock_center - Vector2(rock_radius, rock_radius),
			Vector2(rock_radius * 2.0, rock_radius * 2.0)
		)
		var rect_hit := projectile_rect.intersects(rock_rect)
		if not rect_hit and not collision_geometry.segment_hits_circle(prev_pos, pos, rock_center, rock_radius + projectile_radius):
			continue
		if int(projectile.get("rock_bounces", 0)) >= PISTOL_ROCK_BOUNCE_MAX:
			return {"bounced": false, "consumed": true}
		var hit_side: String = _get_pistol_rock_hit_side(projectile_rect, rock_rect, pos, velocity, rect_hit)
		var bounced_projectile: Dictionary = _build_pistol_rock_bounce_projectile(
			projectile,
			pos,
			velocity,
			projectile_radius,
			rock_rect,
			hit_side
		)
		_mark_rock_ricochet(idx, deps)
		return {
			"bounced": true,
			"projectile": bounced_projectile,
			"rock_index": idx,
			"rock_id": int(rock.get("id", idx)),
			"side": hit_side,
		}
	return {"bounced": false}


func absorb_chaos_spear_objects(center: Vector2, radius: float, _deps: Dictionary = {}) -> Array:
	var absorbed: Array = chaos_absorbed_entries.duplicate(true)
	chaos_absorbed_entries.clear()
	chaos_rock_absorb_center = center
	chaos_rock_absorb_timer = CHAOS_ROCK_PULL_REFRESH_SEC
	for idx in range(rocks.size()):
		var rock: Dictionary = rocks[idx]
		if not rock_query.is_landed(rock):
			continue
		var rock_center: Vector2 = rock_query.get_center(rock)
		if not bool(rock.get("chaos_absorbing", false)):
			rock_query.set_center(rock, rock_center)
			rock["chaos_spin_dir"] = 1.0 if (int(rock.get("id", idx)) & 1) == 1 else -1.0
		rock["chaos_absorbing"] = true
		rock["chaos_absorb_center"] = center
		rock["flash"] = max(float(rock.get("flash", 0.0)), 0.12)
		Stage2RockRuntimeState.clear_water_target_flash(rock)
		rocks[idx] = rock
	var splash_write_index := 0
	var splash_count := water_splashes.size()
	for idx in range(splash_count):
		var splash: Dictionary = water_splashes[idx]
		var splash_pos: Vector2 = _get_vector2(splash.get("pos", Vector2.ZERO), Vector2.ZERO)
		var splash_radius: float = float(splash.get("radius", 10.0))
		if splash_pos.distance_to(center) <= radius + splash_radius:
			absorbed.append({
				"position": splash_pos,
				"strength": 0.75,
				"color": Color(0.42, 0.88, 1.0, 1.0),
			})
			continue
		water_splashes[splash_write_index] = splash
		splash_write_index += 1
	if splash_write_index < splash_count:
		water_splashes.resize(splash_write_index)
	return absorbed


func has_visible_effects() -> bool:
	return Stage2VisibilityState.has_visible_effects(
		has_visible_playfield_overlay(),
		has_visible_playfield_obstacles(),
		Stage2RustleState.has_active(rustle_bushes, rustle_vines)
	)


func has_visible_playfield_overlay() -> bool:
	return Stage2VisibilityState.has_visible_playfield_overlay(
		border_flash_state.is_active(),
		boss_rage_active,
		boss_rage_tint,
		skill_warning_state.is_active(),
		fragment_hit_flash_state.get_timer(),
		leaf_particles.size(),
		starpoint_drops.size(),
		starpoint_particles.size()
	)


func has_visible_playfield_obstacles() -> bool:
	return Stage2VisibilityState.has_visible_playfield_obstacles(
		quake_timer,
		water_cannon_phase,
		rocks.size(),
		rock_fragments.size(),
		water_trail.size(),
		water_splashes.size()
	)


func get_leaf_particle_count() -> int:
	return leaf_particles.size()


func get_rock_count() -> int:
	return rocks.size()


func get_rock_fragment_count() -> int:
	return rock_fragments.size()


func get_rocks_snapshot() -> Array:
	return rocks.duplicate(true)


func get_starpoint_drop_count() -> int:
	return starpoint_drops.size()


func get_starpoint_drops_snapshot() -> Array:
	return starpoint_drops.duplicate(true)


func get_water_cannon_phase() -> String:
	return water_cannon_phase


func interrupt_water_cannon_charge_on_boss_hit() -> bool:
	if water_cannon_phase != "charging":
		return false
	_cancel_water_cannon()
	skill_warning_state.trigger("water_cancel", "물대포 중단!", 0.62)
	return true


func get_water_splash_count() -> int:
	return water_splashes.size()


func get_water_splashes_snapshot() -> Array:
	return water_splashes.duplicate(true)


func get_render_budget_status() -> Dictionary:
	return Stage2RenderBudgetHelper.build_status(
		AMBIENT_FALLING_LEAF_RENDER_LIMIT,
		AMBIENT_FALLING_LEAF_RENDER_LIMIT_SEVERE_LOD,
		LEAF_PARTICLE_RENDER_LIMIT,
		LEAF_PARTICLE_RENDER_LIMIT_SEVERE_LOD,
		ROCK_FRAGMENT_RENDER_LIMIT,
		ROCK_FRAGMENT_RENDER_LIMIT_SEVERE_LOD,
		WATER_SPLASH_RENDER_LIMIT,
		WATER_SPLASH_RENDER_LIMIT_SEVERE_LOD,
		STARPOINT_PARTICLE_RENDER_LIMIT,
		STARPOINT_PARTICLE_RENDER_LIMIT_SEVERE_LOD
	)


func get_fragment_hit_flash_timer() -> float:
	return fragment_hit_flash_state.get_timer()


func get_skill_warning_snapshot() -> Dictionary:
	return skill_warning_state.get_snapshot()


func is_quake_active() -> bool:
	return quake_timer > 0.0


func is_boss_movement_locked() -> bool:
	return Stage2VisibilityState.is_boss_movement_locked(boss_rage_active, water_cannon_phase)


func get_boss_ai_context() -> Dictionary:
	return boss_ai_context_builder.build_context(is_boss_movement_locked(), water_cannon_phase)


func is_boss_rage_pending() -> bool:
	return boss_rage_pending


func is_boss_rage_active() -> bool:
	return boss_rage_active


func get_boss_rage_snapshot() -> Dictionary:
	return boss_rage_snapshot_builder.build_snapshot(
		boss_rage_pending,
		boss_rage_active,
		boss_rage_timer,
		boss_rage_stomp_count,
		boss_rage_final_stomp_done,
		boss_rage_offset_y,
		boss_rage_tint
	)


func get_expression_snapshot() -> Dictionary:
	return boss_expression_state.get_snapshot()


func get_rustle_snapshot() -> Dictionary:
	return rustle_snapshot_builder.build_snapshot(rustle_bushes, rustle_vines)


func get_actor_draw_context() -> Dictionary:
	return actor_draw_context_builder.build_context(
		get_boss_rage_snapshot(),
		boss_expression_state.get_snapshot()
	)


func get_imagegen_asset_status() -> Dictionary:
	_ensure_textures()
	return imagegen_asset_status_builder.build_status(
		base_texture,
		tree_texture,
		tree_source_regions,
		game_frame_texture,
		leaf_texture,
		leaf_source_regions,
		rock_texture,
		rock_source_regions,
		rock_debris_texture,
		rock_debris_source_regions
	)


func prewarm_assets(
	view_size: Vector2 = Vector2(1280.0, 800.0),
	game_offset: Vector2 = Vector2(260.0, 0.0),
	game_size: Vector2 = Vector2(760.0, 750.0)
) -> void:
	while not prewarm_assets_step(view_size, game_offset, game_size):
		pass


func prewarm_assets_step(
	view_size: Vector2 = Vector2(1280.0, 800.0),
	game_offset: Vector2 = Vector2(260.0, 0.0),
	game_size: Vector2 = Vector2(760.0, 750.0)
) -> bool:
	if _prewarm_assets_done:
		return true
	match _prewarm_step_index:
		0, 1, 2, 3, 4, 5:
			if not _prewarm_texture_step(_prewarm_step_index):
				return false
		6:
			_ensure_ambient_layout(view_size, game_offset, game_size)
		7:
			_get_game_frame_source_hole()
		_:
			_prewarm_assets_done = true
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	if _prewarm_step_index > 7:
		_prewarm_assets_done = true
		_prewarm_step_index = 0
		return true
	return false


func get_ambient_visual_snapshot(
	view_size: Vector2 = Vector2(1280.0, 800.0),
	game_offset: Vector2 = Vector2(260.0, 0.0),
	game_size: Vector2 = Vector2(760.0, 750.0)
) -> Dictionary:
	_ensure_textures()
	_ensure_ambient_layout(view_size, game_offset, game_size)
	return ambient_visual_snapshot_builder.build_snapshot(
		falling_leaves,
		fireflies,
		leaf_source_regions
	)


func draw(canvas: CanvasItem, view_size: Vector2, game_offset: Vector2, game_size: Vector2, _width: float, quality_scale: float = 1.0) -> bool:
	var perf_start := _perf_begin()
	if canvas == null or view_size.x <= 0.0 or view_size.y <= 0.0:
		_perf_end("stage2_pillar_draw", perf_start)
		return false
	var prepare_start := _perf_begin()
	_ensure_textures()
	_ensure_ambient_layout(view_size, game_offset, game_size)
	_perf_end("stage2_pillar_prepare", prepare_start)
	if base_texture != null:
		_draw_imagegen_pillars(canvas, view_size, game_offset, game_size)
	else:
		_draw_procedural_pillars(canvas, view_size, game_offset, game_size)
	_draw_ambient_layers(canvas, quality_scale)
	_perf_end("stage2_pillar_draw", perf_start)
	return true


func draw_pillar_background_overlay(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	_width: float,
	_perf_logger: Object = null,
	quality_scale: float = 1.0
) -> bool:
	var perf_start := _perf_begin()
	if canvas == null or view_size.x <= 0.0 or view_size.y <= 0.0:
		_perf_end("stage2_pillar_background_overlay", perf_start)
		return false
	var prepare_start := _perf_begin()
	_ensure_textures()
	_ensure_ambient_layout(view_size, game_offset, game_size)
	_perf_end("stage2_pillar_overlay_prepare", prepare_start)
	if base_texture != null:
		_draw_imagegen_pillar_background_overlay(canvas, view_size, game_offset, game_size)
	else:
		_draw_procedural_pillars(canvas, view_size, game_offset, game_size)
	_draw_ambient_layers(canvas, quality_scale)
	_perf_end("stage2_pillar_background_overlay", perf_start)
	return true


func _draw_ambient_layers(canvas: CanvasItem, quality_scale: float) -> void:
	ambient_visual_renderer.draw_ambient_layers(
		canvas,
		falling_leaves,
		fireflies,
		leaf_texture,
		leaf_source_regions,
		ambient_game_offset,
		ambient_game_size,
		ambient_time,
		Stage2RenderBudgetHelper.get_lod_count(
			AMBIENT_MAX_FALLING_LEAVES,
			AMBIENT_FALLING_LEAF_RENDER_LIMIT,
			AMBIENT_FALLING_LEAF_RENDER_LIMIT_SEVERE_LOD,
			quality_scale,
			LOD_ACTIVE_THRESHOLD,
			SEVERE_LOD_ACTIVE_THRESHOLD
		)
	)


func _ensure_textures() -> void:
	if texture_loaded:
		return
	for step_index in range(6):
		_load_texture_step(step_index)
	texture_loaded = true


func _prewarm_texture_step(step_index: int) -> bool:
	match step_index:
		0:
			if base_texture != null:
				return true
			var result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(Stage2PillarAssets.BASE_TEXTURE_PATH)
			if not bool(result.get("done", true)):
				return false
			base_texture = result.get("texture", null) as Texture2D
		1:
			if tree_texture != null:
				if tree_source_regions.is_empty():
					tree_source_regions = Stage2PillarAssets.TREE_SOURCE_REGION_DATA.duplicate()
				return true
			var result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(Stage2PillarAssets.TREE_TEXTURE_PATH)
			if not bool(result.get("done", true)):
				return false
			tree_texture = result.get("texture", null) as Texture2D
			if tree_texture != null and tree_source_regions.is_empty():
				tree_source_regions = Stage2PillarAssets.TREE_SOURCE_REGION_DATA.duplicate()
		2:
			if game_frame_texture != null:
				return true
			var result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(Stage2PillarAssets.GAME_FRAME_TEXTURE_PATH)
			if not bool(result.get("done", true)):
				return false
			game_frame_texture = result.get("texture", null) as Texture2D
		3:
			if leaf_texture != null:
				if leaf_source_regions.is_empty():
					leaf_source_regions = Stage2PillarAssets.LEAF_SOURCE_REGION_DATA.duplicate()
				return true
			var result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(Stage2PillarAssets.LEAF_TEXTURE_PATH)
			if not bool(result.get("done", true)):
				return false
			leaf_texture = result.get("texture", null) as Texture2D
			if leaf_texture != null and leaf_source_regions.is_empty():
				leaf_source_regions = Stage2PillarAssets.LEAF_SOURCE_REGION_DATA.duplicate()
		4:
			if rock_texture != null:
				if rock_source_regions.is_empty():
					rock_source_regions = Stage2PillarAssets.ROCK_SOURCE_REGION_DATA.duplicate()
				return true
			var result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(Stage2PillarAssets.ROCK_TEXTURE_PATH)
			if not bool(result.get("done", true)):
				return false
			rock_texture = result.get("texture", null) as Texture2D
			if rock_texture != null and rock_source_regions.is_empty():
				rock_source_regions = Stage2PillarAssets.ROCK_SOURCE_REGION_DATA.duplicate()
		5:
			if rock_debris_texture != null:
				if rock_debris_source_regions.is_empty():
					rock_debris_source_regions = Stage2PillarAssets.ROCK_DEBRIS_SOURCE_REGION_DATA.duplicate()
				return true
			var result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(Stage2PillarAssets.ROCK_DEBRIS_TEXTURE_PATH)
			if not bool(result.get("done", true)):
				return false
			rock_debris_texture = result.get("texture", null) as Texture2D
			if rock_debris_texture != null and rock_debris_source_regions.is_empty():
				rock_debris_source_regions = Stage2PillarAssets.ROCK_DEBRIS_SOURCE_REGION_DATA.duplicate()
	if step_index >= 5:
		texture_loaded = true
	return true


func _load_texture_step(step_index: int) -> void:
	match step_index:
		0:
			if base_texture == null:
				base_texture = ProjectResourceLoader.load_texture(Stage2PillarAssets.BASE_TEXTURE_PATH)
		1:
			if tree_texture == null:
				tree_texture = ProjectResourceLoader.load_texture(Stage2PillarAssets.TREE_TEXTURE_PATH)
			if tree_texture != null and tree_source_regions.is_empty():
				tree_source_regions = Stage2PillarAssets.TREE_SOURCE_REGION_DATA.duplicate()
		2:
			if game_frame_texture == null:
				game_frame_texture = ProjectResourceLoader.load_texture(Stage2PillarAssets.GAME_FRAME_TEXTURE_PATH)
		3:
			if leaf_texture == null:
				leaf_texture = ProjectResourceLoader.load_texture(Stage2PillarAssets.LEAF_TEXTURE_PATH)
			if leaf_texture != null and leaf_source_regions.is_empty():
				leaf_source_regions = Stage2PillarAssets.LEAF_SOURCE_REGION_DATA.duplicate()
		4:
			if rock_texture == null:
				rock_texture = ProjectResourceLoader.load_texture(Stage2PillarAssets.ROCK_TEXTURE_PATH)
			if rock_texture != null and rock_source_regions.is_empty():
				rock_source_regions = Stage2PillarAssets.ROCK_SOURCE_REGION_DATA.duplicate()
		5:
			if rock_debris_texture == null:
				rock_debris_texture = ProjectResourceLoader.load_texture(Stage2PillarAssets.ROCK_DEBRIS_TEXTURE_PATH)
			if rock_debris_texture != null and rock_debris_source_regions.is_empty():
				rock_debris_source_regions = Stage2PillarAssets.ROCK_DEBRIS_SOURCE_REGION_DATA.duplicate()
	if step_index >= 5:
		texture_loaded = true


func _draw_imagegen_pillars(canvas: CanvasItem, view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> void:
	var imagegen_assets: Dictionary = imagegen_assets_builder.build_assets(
		base_texture,
		tree_texture,
		tree_source_regions,
		game_frame_texture,
		_get_game_frame_source_hole()
	)
	imagegen_renderer.draw(canvas, view_size, game_offset, game_size, imagegen_assets)


func _draw_imagegen_pillar_background_overlay(canvas: CanvasItem, view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> void:
	var imagegen_assets: Dictionary = imagegen_assets_builder.build_assets(
		base_texture,
		tree_texture,
		tree_source_regions,
		game_frame_texture,
		_get_game_frame_source_hole()
	)
	imagegen_renderer.draw_background_overlay(canvas, view_size, game_offset, game_size, imagegen_assets)


func _get_game_frame_source_hole() -> Rect2:
	if game_frame_hole_checked:
		return game_frame_hole
	game_frame_hole_checked = true
	if game_frame_texture == null:
		return Rect2()
	game_frame_hole = Stage2PillarAssets.GAME_FRAME_SOURCE_HOLE
	return game_frame_hole


func _draw_procedural_pillars(canvas: CanvasItem, view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> void:
	var game_rect := Rect2(game_offset, game_size)
	var left_rect := Rect2(0.0, 0.0, max(0.0, game_rect.position.x), view_size.y)
	var right_rect := Rect2(game_rect.end.x, 0.0, max(0.0, view_size.x - game_rect.end.x), view_size.y)
	var top_rect := Rect2(game_rect.position.x, 0.0, game_rect.size.x, max(0.0, game_rect.position.y))
	var bottom_rect := Rect2(game_rect.position.x, game_rect.end.y, game_rect.size.x, max(0.0, view_size.y - game_rect.end.y))
	for rect in [left_rect, right_rect, top_rect, bottom_rect]:
		_draw_panel(canvas, rect)


func _draw_panel(canvas: CanvasItem, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	canvas.draw_rect(rect, Color(0.015, 0.055, 0.045, 1.0))
	for idx in range(12):
		var t: float = float(idx) / 11.0
		var alpha: float = 0.11 + 0.09 * sin(float(idx) * 1.8)
		var x: float = rect.position.x + rect.size.x * t
		canvas.draw_line(
			Vector2(x, rect.position.y),
			Vector2(x + sin(float(idx)) * 26.0, rect.end.y),
			Color(0.06, 0.34, 0.18, alpha),
			2.0
		)
	for idx in range(10):
		var y: float = rect.position.y + fposmod(float(idx) * 47.0, max(1.0, rect.size.y))
		canvas.draw_line(
			Vector2(rect.position.x, y),
			Vector2(rect.end.x, y + sin(float(idx) * 1.1) * 16.0),
			Color(0.0, 0.70, 0.62, 0.08),
			1.0
		)
	canvas.draw_rect(rect.grow(-3.0), Color(0.08, 0.44, 0.28, 0.24), false, 2.0)


func _ensure_ambient_layout(view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> void:
	if ambient_layout_helper.is_current_layout(
		view_size,
		game_offset,
		game_size,
		ambient_layout_size,
		ambient_game_offset,
		ambient_game_size,
		fireflies
	):
		return
	ambient_layout_size = view_size
	ambient_game_offset = game_offset
	ambient_game_size = game_size
	ambient_layout_helper.populate_initial_layout(
		falling_leaves,
		fireflies,
		view_size,
		game_offset,
		game_size,
		ambient_payload_factory,
		ambient_rng,
		AMBIENT_INITIAL_LEAF_COUNT,
		AMBIENT_FIREFLY_COUNT
	)


func _update_ambient_visuals(delta: float) -> void:
	if delta <= 0.0:
		return
	ambient_time += delta
	if excitement > 0.0:
		excitement = max(0.0, excitement - delta * 0.5)
	Stage2AmbientVisualState.update_falling_leaves(falling_leaves, delta, ambient_layout_size)
	Stage2AmbientVisualState.update_fireflies(fireflies, delta, ambient_layout_size)
	if ambient_layout_helper.should_spawn_ambient_leaf(
		ambient_layout_size,
		ambient_rng,
		delta,
		excitement,
		AMBIENT_LEAF_SPAWN_RATE
	):
		_spawn_ambient_leaf()


func _spawn_ambient_leaf() -> void:
	ambient_layout_helper.append_ambient_leaf(
		falling_leaves,
		ambient_layout_size,
		ambient_game_offset,
		ambient_game_size,
		ambient_payload_factory,
		ambient_rng,
		AMBIENT_MAX_FALLING_LEAVES
	)


func _spawn_leaf_particle(origin: Vector2, side: String, speed_scale: float) -> void:
	leaf_particles.append(ambient_payload_factory.build_leaf_particle(
		origin,
		side,
		speed_scale,
		rng,
		LEAF_PARTICLE_LIFE_SEC
	))


func _reset_rustle_state() -> void:
	rustle_bushes.clear()
	rustle_vines.clear()
	rustle_layout_size = Vector2.ZERO
	boss_paddle_center_valid = false
	player_paddle_center_valid = false
	prev_boss_paddle_center_x = 380.0
	prev_player_paddle_center_x = 380.0


func _ensure_rustle_layout(width: float, height: float) -> void:
	var size := Vector2(width, height)
	if rustle_layout_size == size and not rustle_bushes.is_empty() and not rustle_vines.is_empty():
		return
	rustle_layout_size = size
	rustle_bushes = rustle_payload_factory.build_bushes(height)
	rustle_vines = rustle_payload_factory.build_vines()


func _update_rustle_reactions(delta: float, context: Dictionary) -> void:
	if int(context.get("current_stage", 1)) != 2:
		return
	var width: float = float(context.get("width", 760.0))
	var height: float = float(context.get("height", 750.0))
	_ensure_rustle_layout(width, height)

	var boss_pos: Vector2 = _get_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	var boss_center_x: float = boss_pos.x + float(context.get("boss_paddle_width", 100.0)) * 0.5
	if boss_paddle_center_valid:
		var boss_delta_x: float = boss_center_x - prev_boss_paddle_center_x
		if abs(boss_delta_x) > 2.0:
			var boss_dash_like: bool = abs(boss_delta_x) > 15.0 or abs(float(context.get("boss_vel", 0.0))) > 10.0
			_trigger_bush_rustle("boss", boss_center_x, boss_delta_x, boss_dash_like)
			_trigger_vine_rustle(boss_center_x, boss_delta_x, boss_dash_like)
	prev_boss_paddle_center_x = boss_center_x
	boss_paddle_center_valid = true

	var player_pos: Vector2 = _get_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	var player_center_x: float = player_pos.x + player_size.x * 0.5
	if player_paddle_center_valid:
		var player_delta_x: float = player_center_x - prev_player_paddle_center_x
		if abs(player_delta_x) > 2.0:
			var dash_snapshot: Dictionary = context.get("dash_snapshot", {}) if context.get("dash_snapshot", {}) is Dictionary else {}
			var player_dash_like: bool = abs(player_delta_x) > 15.0 or bool(dash_snapshot.get("active", false))
			_trigger_bush_rustle("player", player_center_x, player_delta_x, player_dash_like)
	prev_player_paddle_center_x = player_center_x
	player_paddle_center_valid = true

	Stage2RustleState.decay(rustle_bushes, rustle_vines, delta)


func _trigger_bush_rustle(area: String, paddle_center_x: float, delta_x: float, dash_like: bool) -> void:
	Stage2RustleState.trigger_bush_rustle(
		rustle_bushes,
		area,
		paddle_center_x,
		delta_x,
		dash_like,
		BUSH_RUSTLE_RANGE,
		BUSH_RUSTLE_NORMAL,
		BUSH_RUSTLE_DASH
	)


func _trigger_vine_rustle(paddle_center_x: float, delta_x: float, dash_like: bool) -> void:
	Stage2RustleState.trigger_vine_rustle(
		rustle_vines,
		paddle_center_x,
		delta_x,
		dash_like,
		VINE_RUSTLE_RANGE,
		VINE_RUSTLE_NORMAL,
		VINE_RUSTLE_DASH
	)


func _update_chaos_absorbing_rock(rock: Dictionary, delta: float, deps: Dictionary, context: Dictionary = {}) -> bool:
	var frame_step_total: float = max(0.0, delta) * 60.0
	if frame_step_total <= 0.0:
		return false
	var center: Vector2 = _get_vector2(rock.get("chaos_absorb_center", chaos_rock_absorb_center), chaos_rock_absorb_center)
	var whole_steps: int = int(min(floor(frame_step_total), 240.0))
	var remainder: float = frame_step_total - float(whole_steps)
	for _step in range(whole_steps):
		if _step_chaos_absorbing_rock(rock, center, 1.0, deps, context):
			return true
	if remainder > 0.001:
		return _step_chaos_absorbing_rock(rock, center, remainder, deps, context)
	return false


func _step_chaos_absorbing_rock(rock: Dictionary, center: Vector2, frame_step: float, deps: Dictionary, context: Dictionary = {}) -> bool:
	var rock_center: Vector2 = rock_query.get_center(rock)
	var result: Dictionary = Stage2ChaosRockAbsorbState.step_absorbing_rock(
		rock,
		rock_center,
		center,
		frame_step,
		CHAOS_ROCK_DESTROY_DISTANCE,
		CHAOS_ROCK_ANGULAR_SPEED_MAX,
		CHAOS_ROCK_ANGULAR_SPEED_NUMERATOR,
		CHAOS_ROCK_RADIAL_SPEED_MIN,
		CHAOS_ROCK_RADIAL_SPEED_MAX,
		CHAOS_ROCK_RADIAL_SPEED_NUMERATOR,
		CHAOS_ROCK_SPIN_MULTIPLIER
	)
	var result_center: Vector2 = _get_vector2(result.get("center", rock_center), rock_center)
	if bool(result.get("moved", false)):
		rock_query.set_center(rock, result_center)
	if bool(result.get("destroyed", false)):
		_destroy_chaos_absorbed_rock(rock, result_center, deps, context)
		return true
	return false


func _destroy_chaos_absorbed_rock(rock: Dictionary, center: Vector2, deps: Dictionary, context: Dictionary = {}) -> void:
	_spawn_rock_fragments(rock, center)
	_spawn_rock_leaves(center, 1.15)
	_spawn_golden_rock_starpoint_drop(rock, center, deps, context)
	Stage2AudioRouter.play_rock_break(rock, deps)
	var rock_radius: float = float(rock.get("radius", 28.0))
	chaos_absorbed_entries.append({
		"position": center,
		"strength": clamp(rock_radius / 28.0, 0.85, 1.65),
		"color": Color(0.48, 0.92, 0.78, 1.0),
	})


func _spawn_quake_rocks(count: int, deps: Dictionary = {}) -> void:
	var batch: Dictionary = quake_rock_spawn_factory.build_spawn_batch(
		rocks,
		count,
		MAX_ROCKS,
		rock_next_id,
		rng,
		rock_visual_factory,
		quake_rock_payload_factory,
		QUAKE_ROCK_SIZE_SCALE,
		ROCK_LIFE_SEC
	)
	var spawned_rocks: Array = batch.get("rocks", [])
	var targets: Array = batch.get("targets", [])
	for idx in range(spawned_rocks.size()):
		var rock: Dictionary = spawned_rocks[idx]
		rocks.append(rock)
		var target: Vector2 = _get_vector2(targets[idx] if idx < targets.size() else rock.get("target_pos", Vector2.ZERO), Vector2.ZERO)
		_spawn_rock_leaves(target, 0.28)
	rock_next_id = int(batch.get("next_id", rock_next_id + spawned_rocks.size()))
	Stage2AudioRouter.play_rock_spawn(deps)


func _spawn_crisis_rock_wall(deps: Dictionary = {}) -> void:
	water_trail.clear()
	water_splashes.clear()
	water_cannon_delay = -1.0
	water_cannon_phase = "idle"
	water_cannon_target_id = -1
	var crisis_rock_count: int = _get_boss_rage_crisis_rock_count()
	for idx in range(crisis_rock_count):
		var rock: Dictionary = crisis_rock_wall_payload_factory.build_crisis_rock(
			rock_next_id,
			idx,
			crisis_rock_count,
			rng,
			rock_visual_factory,
			CRISIS_ROCK_WALL_Y_MIN,
			CRISIS_ROCK_WALL_Y_MID,
			CRISIS_ROCK_WALL_Y_MAX,
			QUAKE_ROCK_DROP_HEIGHT,
			QUAKE_ROCK_SIZE_SCALE,
			QUAKE_ROCK_DROP_STAGGER_SEC,
			QUAKE_ROCK_DROP_TIME_SEC,
			ROCK_LIFE_SEC,
			rocks
		)
		rocks.append(rock)
		rock_next_id += 1
	_spawn_rock_leaves(Vector2(380.0, (CRISIS_ROCK_WALL_Y_MIN + CRISIS_ROCK_WALL_Y_MAX) * 0.5), 0.90)
	var skill_state: Object = deps.get("stage2_boss_skill_state", null)
	if skill_state != null and skill_state.has_method("defer_water_cannon_after_rock_spawn"):
		skill_state.defer_water_cannon_after_rock_spawn()
	Stage2AudioRouter.play_rock_spawn(deps)


func _hit_rock(index: int, deps: Dictionary, context: Dictionary = {}) -> void:
	if index < 0 or index >= rocks.size():
		return
	var rock: Dictionary = rocks[index]
	var center: Vector2 = rock_query.get_center(rock)
	rock["hp"] = int(rock.get("hp", 1)) - 1
	rock["flash"] = 0.24
	_spawn_rock_leaves(center, 1.0)
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(0.045, 2.2)
	if int(rock.get("hp", 0)) <= 0:
		_spawn_rock_fragments(rock, center)
		_spawn_golden_rock_starpoint_drop(rock, center, deps, context)
		Stage2AudioRouter.play_rock_break(rock, deps)
		rocks.remove_at(index)
	else:
		Stage2AudioRouter.play_rock_hit(deps)
		rocks[index] = rock


func _mark_rock_ricochet(index: int, deps: Dictionary) -> void:
	if index < 0 or index >= rocks.size():
		return
	var rock: Dictionary = rocks[index]
	rock["flash"] = max(float(rock.get("flash", 0.0)), 0.16)
	rocks[index] = rock
	Stage2AudioRouter.play_rock_hit(deps)


func _get_pistol_rock_hit_side(
	projectile_rect: Rect2,
	rock_rect: Rect2,
	pos: Vector2,
	velocity: Vector2,
	rect_hit: bool
) -> String:
	if rect_hit:
		var overlap_left: float = projectile_rect.end.x - rock_rect.position.x
		var overlap_right: float = rock_rect.end.x - projectile_rect.position.x
		var overlap_top: float = projectile_rect.end.y - rock_rect.position.y
		var overlap_bottom: float = rock_rect.end.y - projectile_rect.position.y
		var hit_side := "left"
		var min_overlap := overlap_left
		if overlap_right < min_overlap:
			min_overlap = overlap_right
			hit_side = "right"
		if overlap_top < min_overlap:
			min_overlap = overlap_top
			hit_side = "top"
		if overlap_bottom < min_overlap:
			hit_side = "bottom"
		return hit_side
	var relative: Vector2 = pos - (rock_rect.position + rock_rect.size * 0.5)
	if relative.length_squared() <= 0.001:
		relative = -velocity
	if abs(relative.x) > abs(relative.y):
		return "left" if relative.x <= 0.0 else "right"
	return "top" if relative.y <= 0.0 else "bottom"


func _build_pistol_rock_bounce_projectile(
	projectile: Dictionary,
	pos: Vector2,
	velocity: Vector2,
	projectile_radius: float,
	rock_rect: Rect2,
	hit_side: String
) -> Dictionary:
	var next_projectile: Dictionary = projectile.duplicate(true)
	match hit_side:
		"left":
			pos.x = rock_rect.position.x - projectile_radius - PISTOL_ROCK_BOUNCE_EPSILON
			velocity.x = -max(abs(velocity.x) * PISTOL_ROCK_BOUNCE_DAMPING, PISTOL_ROCK_BOUNCE_MIN_SPEED)
		"right":
			pos.x = rock_rect.end.x + projectile_radius + PISTOL_ROCK_BOUNCE_EPSILON
			velocity.x = max(abs(velocity.x) * PISTOL_ROCK_BOUNCE_DAMPING, PISTOL_ROCK_BOUNCE_MIN_SPEED)
		"top":
			pos.y = rock_rect.position.y - projectile_radius - PISTOL_ROCK_BOUNCE_EPSILON
			velocity.y = -max(abs(velocity.y) * PISTOL_ROCK_BOUNCE_DAMPING, PISTOL_ROCK_BOUNCE_MIN_SPEED)
		_:
			pos.y = rock_rect.end.y + projectile_radius + PISTOL_ROCK_BOUNCE_EPSILON
			velocity.y = max(abs(velocity.y) * PISTOL_ROCK_BOUNCE_DAMPING, PISTOL_ROCK_BOUNCE_MIN_SPEED)
	next_projectile["rock_bounces"] = int(next_projectile.get("rock_bounces", 0)) + 1
	next_projectile["pos"] = pos
	next_projectile["velocity"] = velocity
	next_projectile["speed"] = velocity.length()
	next_projectile["stage2_rock_bounce_side"] = hit_side
	return next_projectile


func _spawn_rock_fragments(rock: Dictionary, center: Vector2) -> void:
	var colors: Array = rock.get("style_colors", rock_visual_factory.get_style_colors(str(rock.get("style_type", "gray_stone"))))
	var payload_config: Dictionary = rock_fragment_payload_config_builder.build_config(ROCK_FRAGMENT_LIFE_SEC)
	rock_fragments.append_array(rock_fragment_payload_factory.build_fragments(
		rock,
		center,
		rock_debris_source_regions.size(),
		colors,
		rng,
		payload_config
	))
	Stage2RenderBudgetHelper.trim_array_from_front(rock_fragments, MAX_ROCK_FRAGMENTS)


func _update_rock_fragments(delta: float) -> void:
	Stage2RockFragmentMotionState.update_fragments(rock_fragments, delta)


func _spawn_rock_leaves(center: Vector2, strength: float) -> void:
	var count: int = clampi(int(round(8.0 + strength * 10.0)), 8, 20)
	for _i in range(count):
		var side := "left" if rng.randf() < 0.5 else "right"
		_spawn_leaf_particle(center, side, strength)
	Stage2RenderBudgetHelper.trim_array_from_front(leaf_particles, MAX_LEAF_PARTICLES)


func spawn_starpoint_drop(pos: Vector2, _source_type: String = "", deps: Dictionary = {}, context: Dictionary = {}) -> void:
	_spawn_starpoint_drop_at(pos, deps, context)


func _spawn_golden_rock_starpoint_drop(rock: Dictionary, center: Vector2, deps: Dictionary, context: Dictionary = {}) -> void:
	if not bool(rock.get("is_golden", false)):
		return
	_spawn_starpoint_drop_at(center, deps, context)


func _spawn_starpoint_drop_at(
	pos: Vector2,
	deps: Dictionary = {},
	context: Dictionary = {},
	allow_star_detector_bonus: bool = true,
	star_detector_bonus: bool = false
) -> void:
	starpoint_drops.append(starpoint_visual_factory.build_drop(
		pos,
		rng,
		star_detector_bonus,
		STARPOINT_DROP_SIZE,
		STARPOINT_DROP_LIFETIME
	))
	_spawn_starpoint_particles(pos, STARPOINT_PARTICLE_COUNT + (6 if star_detector_bonus else 0), 1.2 if star_detector_bonus else 1.0)
	if allow_star_detector_bonus:
		_spawn_star_detector_bonus_drops(pos, deps, context)


func _spawn_star_detector_bonus_drops(pos: Vector2, deps: Dictionary, context: Dictionary) -> void:
	var bonus_count: int = _roll_star_detector_bonus_drop_count(deps, context)
	for _i in range(bonus_count):
		var bonus_pos := Vector2(
			clamp(
				pos.x + float(STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES[rng.randi() % STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES.size()]),
				playfield_bounds.get_left(context) + STARPOINT_DROP_SIZE,
				playfield_bounds.get_right(context) - STARPOINT_DROP_SIZE
			),
			clamp(
				pos.y + float(STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES[rng.randi() % STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES.size()]),
				STARPOINT_DROP_SIZE,
				playfield_bounds.get_height(context) - STARPOINT_DROP_SIZE
			)
		)
		_spawn_starpoint_drop_at(bonus_pos, deps, context, false, true)


func _roll_star_detector_bonus_drop_count(deps: Dictionary, context: Dictionary) -> int:
	var mythic_item_runtime: Object = _get_mythic_item_runtime(deps, context)
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("roll_star_detector_bonus_drop_count"):
		return 0
	return max(0, int(mythic_item_runtime.roll_star_detector_bonus_drop_count()))


func _update_starpoint_drops(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	if int(context.get("current_stage", 1)) != 2:
		# Drop mid-flight starpoints when the player leaves Stage 2 so they
		# don't reappear frozen at their last position when the player returns.
		var had_starpoints := not starpoint_drops.is_empty() or not starpoint_particles.is_empty()
		if not starpoint_drops.is_empty():
			starpoint_drops.clear()
		if not starpoint_particles.is_empty():
			starpoint_particles.clear()
		if had_starpoints:
			obstacle_visual_renderer.hide_all_starpoint_drops()
		return
	if starpoint_drops.is_empty():
		return
	var player_rects: Array[Rect2] = collision_geometry.get_player_interaction_rects_from_context(
		context,
		deps,
		Vector2(155.0, 50.0)
	)
	var play_left: float = playfield_bounds.get_left(context)
	var play_right: float = playfield_bounds.get_right(context)
	var play_height: float = playfield_bounds.get_height(context)
	var write_index := 0
	var drop_count := starpoint_drops.size()
	for index in range(drop_count):
		var d: Dictionary = starpoint_drops[index]
		if not Stage2StarpointDropMotionState.update_drop(
			d,
			fps_scale,
			play_left,
			play_right,
			play_height,
			STARPOINT_DROP_SIZE,
			STARPOINT_DROP_MAX_FALL_SPEED,
			STARPOINT_DROP_ACCELERATION,
			STARPOINT_DROP_BOUNCE_DAMPING
		):
			continue

		var starlight_tracking_result := LingpetStarlightTrackingBridge.update_drop(d, fps_scale, context, deps)
		if bool(starlight_tracking_result.get("delivered", false)):
			if _collect_starpoint_drop(d, context, deps):
				_finish_starpoint_modal_collection(index, write_index, drop_count)
				return
			if starpoint_drops.size() < drop_count:
				return
			continue
		if bool(starlight_tracking_result.get("claimed", false)):
			starpoint_drops[write_index] = d
			write_index += 1
			continue

		if Stage2StarpointDropQuery.overlaps_any_player(d, player_rects, collision_geometry, STARPOINT_DROP_SIZE):
			if _collect_starpoint_drop(d, context, deps):
				_finish_starpoint_modal_collection(index, write_index, drop_count)
				return
			if starpoint_drops.size() < drop_count:
				return
			continue
		starpoint_drops[write_index] = d
		write_index += 1
	if write_index < drop_count:
		starpoint_drops.resize(write_index)


func _finish_starpoint_modal_collection(collected_index: int, write_index: int, drop_count: int) -> void:
	if starpoint_drops.size() < drop_count:
		return
	var tail_write := write_index
	for tail_read in range(collected_index + 1, drop_count):
		starpoint_drops[tail_write] = starpoint_drops[tail_read]
		tail_write += 1
	starpoint_drops.resize(tail_write)


func _collect_starpoint_drop(drop: Dictionary, context: Dictionary, deps: Dictionary) -> bool:
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	var runtime_perk_catalog: Object = deps.get("runtime_perk_catalog", null)
	var owner: Object = context.get("owner", null)
	var registry: Object = context.get("registry", deps.get("registry", null))
	var character_type: String = str(context.get("selected_character_type", "smasher"))
	var opened_choice: bool = false
	if runtime_perk_state != null and runtime_perk_state.has_method("collect_star_points"):
		opened_choice = bool(runtime_perk_state.collect_star_points(1, character_type, runtime_perk_catalog, owner, registry))
	var pos: Vector2 = _get_vector2(drop.get("pos", Vector2.ZERO), Vector2.ZERO)
	_spawn_starpoint_particles(pos, STARPOINT_PARTICLE_COUNT + 10, 1.4)
	Stage2AudioRouter.play_starpoint_collect(deps)
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()
	return opened_choice


func _spawn_starpoint_particles(pos: Vector2, count: int, intensity: float) -> void:
	starpoint_particles.append_array(starpoint_visual_factory.build_particles(
		pos,
		count,
		intensity,
		rng,
		STARPOINT_PARTICLE_LIFE
	))


func _update_starpoint_particles(fps_scale: float) -> void:
	Stage2StarpointParticleState.update_particles(starpoint_particles, fps_scale)


func _get_mythic_item_runtime(deps: Dictionary, context: Dictionary = {}) -> Object:
	var runtime: Object = deps.get("mythic_item_runtime", null)
	if runtime != null:
		return runtime
	var registry: Object = context.get("registry", deps.get("registry", null))
	if registry != null and registry.has_method("get_instance"):
		return registry.get_instance("mythic_item_runtime")
	return null


func _check_crisis_situation(context: Dictionary) -> bool:
	if not Stage2BossRageState.should_trigger_crisis(
		context,
		crisis_triggered,
		boss_rage_pending,
		boss_rage_active,
		CRISIS_PLAYER_SCORE
	):
		return false
	crisis_triggered = true
	boss_rage_pending = true
	boss_rage_ai_mode = _get_crisis_ai_mode(context)
	return true


func _get_boss_rage_crisis_rock_count() -> int:
	if boss_rage_ai_mode == "mythic":
		return BOSS_RAGE_CRISIS_ROCK_COUNT_MYTHIC
	return BOSS_RAGE_CRISIS_ROCK_COUNT_CHAMPION


func _get_crisis_ai_mode(context: Dictionary) -> String:
	var ai_mode: String = str(context.get("ai_mode", context.get("league_mode", "champion")))
	return "mythic" if ai_mode == "mythic" else "champion"


func _update_boss_expression(delta: float) -> void:
	boss_expression_state.update(delta)


func _update_boss_rage(delta: float, deps: Dictionary) -> void:
	if not boss_rage_active:
		var inactive_visuals: Dictionary = Stage2BossRageState.get_inactive_visuals(
			boss_rage_offset_y,
			boss_rage_tint,
			delta
		)
		boss_rage_offset_y = float(inactive_visuals.get("offset_y", boss_rage_offset_y))
		boss_rage_tint = float(inactive_visuals.get("tint", boss_rage_tint))
		return
	var previous_timer := boss_rage_timer
	boss_rage_timer += delta
	_update_boss_rage_visuals()
	_emit_boss_rage_stomps(previous_timer, boss_rage_timer, deps)
	if Stage2BossRageState.should_emit_final_stomp(previous_timer, boss_rage_timer, BOSS_RAGE_FINAL_STOMP_SEC):
		_emit_boss_rage_final_stomp(deps)
	if Stage2BossRageState.is_finished(boss_rage_timer, BOSS_RAGE_TOTAL_SEC):
		boss_rage_active = false
		boss_rage_timer = 0.0
		boss_rage_offset_y = 0.0
		boss_rage_tint = 0.0


func _update_boss_rage_visuals() -> void:
	var visuals: Dictionary = Stage2BossRageState.get_visuals(
		boss_rage_timer,
		boss_rage_offset_y,
		BOSS_RAGE_BUILDUP_SEC,
		BOSS_RAGE_FINAL_STOMP_SEC,
		BOSS_RAGE_TOTAL_SEC
	)
	boss_rage_tint = float(visuals.get("tint", boss_rage_tint))
	boss_rage_offset_y = float(visuals.get("offset_y", boss_rage_offset_y))


func _emit_boss_rage_stomps(previous_timer: float, current_timer: float, deps: Dictionary) -> void:
	var stomp_steps: Array[int] = Stage2BossRageState.get_stomp_steps(
		previous_timer,
		current_timer,
		BOSS_RAGE_STOMP_INTERVAL_SEC,
		BOSS_RAGE_BUILDUP_SEC,
		4
	)
	for step in stomp_steps:
		boss_rage_stomp_count += 1
		boss_rage_offset_y = Stage2BossRageState.get_stomp_offset_y(step)
		Stage2AudioRouter.play_boss_cry(deps, rage_audio)
		var feedback: Object = deps.get("feedback", null)
		if feedback != null and feedback.has_method("max_screen_shake"):
			feedback.max_screen_shake(0.060, 2.5 + float(step) * 0.18)


func _emit_boss_rage_final_stomp(deps: Dictionary) -> void:
	if boss_rage_final_stomp_done:
		return
	boss_rage_final_stomp_done = true
	boss_rage_offset_y = 26.0
	quake_duration = QUAKE_DURATION_SEC
	quake_timer = quake_duration
	quake_cooldown = QUAKE_REPEAT_COOLDOWN_SEC
	quake_ball_velocity_backup = Vector2.ZERO
	quake_ball_velocity_backup_valid = false
	quake_boss_launch_guard_timer = QUAKE_BOSS_LAUNCH_GUARD_SEC
	quake_affects_ball = false
	_spawn_crisis_rock_wall(deps)
	skill_warning_state.trigger("rage_wall", "방어벽 낙하!", 1.25)
	_play_quake_audio(deps)
	Stage2AudioRouter.play_boss_cry(deps, rage_audio)
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(0.082, 4.0)


func _update_quake_rock_drop(rock: Dictionary, delta: float) -> void:
	var target_pos: Vector2 = rock_query.get_target_pos(rock)
	var result: Dictionary = Stage2QuakeRockDropState.update_drop(
		rock,
		delta,
		target_pos,
		QUAKE_ROCK_LAND_FLASH_SEC,
		QUAKE_ROCK_DROP_TIME_SEC
	)
	if bool(result.get("landed", false)):
		var land_position: Vector2 = _get_vector2(result.get("land_position", target_pos), target_pos)
		_spawn_rock_leaves(land_position, 0.72)


func _update_water_cannon(delta: float, context: Dictionary, deps: Dictionary) -> void:
	if water_cannon_phase == "idle":
		if deps.get("stage2_boss_skill_state", null) != null:
			return
		if water_cannon_delay <= 0.0:
			return
		if int(context.get("current_stage", 1)) != 2 or not bool(context.get("ball_active", false)) or rocks.is_empty():
			return
		water_cannon_delay = max(0.0, water_cannon_delay - delta)
		if water_cannon_delay <= 0.0:
			activate_water_cannon(context, deps)
		return

	var target_index: int = rock_query.get_index_by_id(rocks, water_cannon_target_id)
	if target_index < 0:
		_cancel_water_cannon()
		return

	var target_rock: Dictionary = rocks[target_index]
	water_cannon_start = water_cannon_geometry.get_boss_cannon_start_from_context(context)
	water_cannon_target = rock_query.get_center(target_rock)
	if water_cannon_phase == "charging":
		water_cannon_current = water_cannon_start
		water_cannon_timer = max(0.0, water_cannon_timer - delta)
		Stage2RockRuntimeState.mark_water_target(rocks, water_cannon_target_id)
		if water_cannon_timer <= 0.0:
			water_cannon_phase = "firing"
			water_cannon_timer = WATER_CANNON_FIRE_SEC
			water_cannon_progress = 0.0
			skill_warning_state.trigger("water_fire", "물대포 발사!", 0.78)
			Stage2AudioRouter.play_hydro(deps)
		return

	if water_cannon_phase == "firing":
		water_cannon_timer = max(0.0, water_cannon_timer - delta)
		water_cannon_progress = clamp(1.0 - water_cannon_timer / max(0.001, WATER_CANNON_FIRE_SEC), 0.0, 1.0)
		water_cannon_current = water_cannon_start.lerp(water_cannon_target, water_cannon_progress)
		_add_water_trail(water_cannon_current, water_cannon_progress)
		Stage2RockRuntimeState.mark_water_target(rocks, water_cannon_target_id)
		if water_cannon_timer <= 0.0:
			_finish_water_cannon(context, deps)


func _update_water_visuals(delta: float) -> void:
	Stage2WaterVisualState.update_trail(water_trail, delta)
	Stage2WaterVisualState.update_splashes(water_splashes, delta)


func _resolve_water_fragment_player_hits(context: Dictionary, deps: Dictionary) -> void:
	if int(context.get("current_stage", 1)) != 2 or water_splashes.is_empty():
		return
	var player_rects: Array[Rect2] = collision_geometry.get_player_interaction_rects_from_context(
		context,
		deps,
		Vector2(155.0, 50.0)
	)
	if player_rects.is_empty():
		return
	var hits: Array = Stage2WaterFragmentHitResolver.resolve_hits(water_splashes, player_rects, collision_geometry)
	for hit_value in hits:
		var hit: Dictionary = hit_value
		_handle_water_fragment_player_hit(
			int(hit.get("index", -1)),
			hit.get("splash", {}),
			_get_vector2(hit.get("pos", Vector2.ZERO), Vector2.ZERO),
			hit.get("hit_rect", Rect2()),
			deps,
			context
		)


func _handle_water_fragment_player_hit(
	index: int,
	splash: Dictionary,
	pos: Vector2,
	player_rect: Rect2,
	deps: Dictionary,
	context: Dictionary = {}
) -> void:
	splash["can_hit_player"] = false
	splash["hit_cooldown"] = 30.0
	water_splashes[index] = splash
	if _is_player_status_immune(deps, context):
		return
	fragment_hit_flash_state.trigger(WATER_FRAGMENT_HIT_FLASH_SEC)
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(0.048, 2.5)
	var vel: Vector2 = _get_vector2(splash.get("vel", Vector2.ZERO), Vector2.ZERO)
	var impact_effects: Object = deps.get("impact_effects", null)
	if impact_effects != null and impact_effects.has_method("spawn_hit_particles"):
		impact_effects.spawn_hit_particles(pos, Color(0.62, 0.90, 1.0, 1.0), vel, 0.8, vel.length())
	Stage2AudioRouter.play_rock_hit(deps)
	var movement_state: Object = deps.get("movement_state", null)
	if movement_state == null or not movement_state.has_method("start_knockback"):
		return
	var direction: float = 1.0 if vel.x >= 0.0 else -1.0
	if abs(vel.x) <= 0.01:
		var player_center_x: float = player_rect.position.x + player_rect.size.x * 0.5
		direction = 1.0 if pos.x >= player_center_x else -1.0
	movement_state.start_knockback(
		direction * WATER_FRAGMENT_PLAYER_KNOCKBACK_SPEED,
		WATER_FRAGMENT_PLAYER_KNOCKBACK_FRAMES,
		WATER_FRAGMENT_PLAYER_KNOCKBACK_DECAY,
		true
	)


func _finish_water_cannon(context: Dictionary, deps: Dictionary) -> void:
	var target_index: int = rock_query.get_index_by_id(rocks, water_cannon_target_id)
	if target_index < 0:
		_cancel_water_cannon()
		return
	var target_rock: Dictionary = rocks[target_index]
	var center: Vector2 = rock_query.get_center(target_rock)
	rocks.remove_at(target_index)
	_spawn_water_cannon_fragments(target_rock, center)
	_spawn_rock_fragments(target_rock, center)
	_spawn_rock_leaves(center, 1.20)
	_spawn_golden_rock_starpoint_drop(target_rock, center, deps, context)
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(0.060, 3.0)
	Stage2AudioRouter.play_rock_break(target_rock, deps)
	skill_warning_state.trigger("fragment", "파편 주의!", SKILL_WARNING_FRAGMENT_SEC)
	_cancel_water_cannon()


func _cancel_water_cannon() -> void:
	_clear_water_cannon_target_flash()
	water_cannon_phase = "idle"
	water_cannon_timer = 0.0
	water_cannon_target_id = -1
	water_cannon_progress = 0.0
	water_cannon_current = water_cannon_start


func _clear_water_cannon_target_flash() -> void:
	if water_cannon_target_id < 0:
		return
	var target_index: int = rock_query.get_index_by_id(rocks, water_cannon_target_id)
	if target_index < 0:
		return
	var target_rock: Dictionary = rocks[target_index]
	Stage2RockRuntimeState.clear_water_target_flash(target_rock)
	rocks[target_index] = target_rock


func _add_water_trail(pos: Vector2, progress: float) -> void:
	water_trail.append(water_trail_payload_factory.build_trail(pos, progress, rng, WATER_TRAIL_LIFE_SEC))
	Stage2RenderBudgetHelper.trim_array_from_front(water_trail, WATER_TRAIL_MAX_COUNT)


func _spawn_water_cannon_fragments(rock: Dictionary, center: Vector2) -> void:
	var payload_config: Dictionary = water_cannon_payload_config_builder.build_config(
		WATER_CANNON_ROCK_FRAGMENT_MIN_COUNT,
		WATER_CANNON_ROCK_FRAGMENT_MAX_COUNT,
		WATER_CANNON_WATER_SPLASH_MIN_COUNT,
		WATER_CANNON_WATER_SPLASH_MAX_COUNT,
		WATER_CANNON_ROCK_FRAGMENT_LIFE_SEC,
		WATER_CANNON_WATER_SPLASH_LIFE_SEC,
		WATER_CANNON_ROCK_FRAGMENT_GRAVITY,
		WATER_CANNON_WATER_SPLASH_GRAVITY
	)
	water_splashes.append_array(water_cannon_payload_factory.build_payloads(
		rock,
		center,
		rock_debris_source_regions.size(),
		rng,
		payload_config
	))
	Stage2RenderBudgetHelper.trim_array_from_front(water_splashes, WATER_CANNON_MAX_SPLASHES)


func _draw_water_cannon_target_highlight(canvas: CanvasItem, shake_offset: Vector2) -> void:
	if water_cannon_target_id < 0:
		return
	var target_rock: Dictionary = rock_query.get_by_id(rocks, water_cannon_target_id)
	water_cannon_visual_renderer.draw_target_highlight(canvas, target_rock, water_cannon_phase, shake_offset)


func _draw_water_cannon(canvas: CanvasItem, shake_offset: Vector2) -> void:
	var visual_state: Dictionary = water_cannon_visual_state_builder.build_state(
		water_cannon_phase,
		water_cannon_start,
		water_cannon_target,
		water_cannon_current,
		water_cannon_progress,
		water_cannon_timer,
		WATER_CANNON_CHARGE_SEC,
		WATER_TRAIL_LIFE_SEC
	)
	water_cannon_visual_renderer.draw_cannon(canvas, visual_state, water_trail, shake_offset)


func _is_player_status_immune(deps: Dictionary, context: Dictionary = {}) -> bool:
	var cleanse_state: Object = deps.get("smasher_cleanse_state", null)
	if cleanse_state != null and cleanse_state.has_method("is_immune"):
		if bool(cleanse_state.is_immune()):
			return true
	var mythic_item_runtime: Object = _get_mythic_item_runtime(deps, context)
	if mythic_item_runtime != null and mythic_item_runtime.has_method("try_consume_celestial_armor_immunity"):
		var status_deps: Dictionary = deps.duplicate()
		status_deps["context"] = context
		if context.get("owner", null) is Object:
			status_deps["owner"] = context.get("owner", null)
		if bool(mythic_item_runtime.try_consume_celestial_armor_immunity("stage2_water_fragment", "knockback", status_deps)):
			return true
	return false


func _sync_quake_audio(deps: Dictionary) -> void:
	quake_audio_active = Stage2AudioRouter.sync_quake_loop(
		quake_timer,
		quake_audio_active,
		deps,
		rage_audio
	)


func _play_quake_audio(deps: Dictionary) -> void:
	quake_audio_active = Stage2AudioRouter.play_quake_loop(deps, rage_audio, quake_audio_active)


func _stop_quake_audio(deps: Dictionary) -> void:
	quake_audio_active = Stage2AudioRouter.stop_quake_loop(deps, rage_audio)


func _capture_quake_ball_velocity_backup(ball_vel: Vector2, _context: Dictionary) -> void:
	if quake_ball_velocity_backup_valid:
		return
	var base_speed: float = QUAKE_BALL_REFERENCE_BASE_SPEED
	var current_speed: float = ball_vel.length()
	if current_speed > base_speed * 2.0 and current_speed > 0.001:
		quake_ball_velocity_backup = ball_vel.normalized() * base_speed * 1.6
	else:
		quake_ball_velocity_backup = ball_vel
	quake_ball_velocity_backup_valid = true


func _restore_quake_ball_velocity(scene: Dictionary, _context: Dictionary) -> bool:
	if not quake_ball_velocity_backup_valid:
		quake_affects_ball = false
		return false
	var restored: Vector2 = quake_ball_velocity_backup
	var base_speed: float = QUAKE_BALL_REFERENCE_BASE_SPEED
	if restored.length() < base_speed * 0.85:
		var direction: Vector2 = restored.normalized() if restored.length_squared() > 0.001 else Vector2.DOWN
		restored = direction * base_speed
	scene["ball_vel"] = restored
	quake_ball_velocity_backup = Vector2.ZERO
	quake_ball_velocity_backup_valid = false
	quake_boss_launch_guard_timer = 0.0
	quake_affects_ball = false
	return true


func _apply_quake_boss_launch_guard(
	scene: Dictionary,
	context: Dictionary,
	ball_vel: Vector2,
	fps_scale: float
) -> Vector2:
	var result: Dictionary = Stage2QuakeBallMotionState.apply_boss_launch_guard(
		scene,
		context,
		ball_vel,
		fps_scale,
		quake_boss_launch_guard_timer,
		quake_ball_velocity_backup.y,
		quake_ball_velocity_backup_valid,
		QUAKE_BALL_REFERENCE_BASE_SPEED
	)
	quake_boss_launch_guard_timer = float(result.get("guard_timer", quake_boss_launch_guard_timer))
	return _get_vector2(result.get("ball_vel", ball_vel), ball_vel)


func _was_last_hit_by_boss(deps: Dictionary) -> bool:
	var ball_intensity: Object = deps.get("ball_intensity", null)
	if ball_intensity != null and ball_intensity.has_method("get_last_hit_by"):
		return str(ball_intensity.get_last_hit_by()) == "boss"
	return false


func _perf_begin() -> int:
	return perf_logger.begin_sample()


func _perf_end(label: String, start_usec: int) -> void:
	perf_logger.finish_sample(label, start_usec)


func _battle_perf_begin(battle_perf_logger: Object) -> int:
	if battle_perf_logger != null and battle_perf_logger.has_method("begin_sample"):
		return int(battle_perf_logger.begin_sample())
	return 0


func _battle_perf_end(battle_perf_logger: Object, label: String, start_usec: int) -> void:
	if battle_perf_logger != null and battle_perf_logger.has_method("finish_sample"):
		battle_perf_logger.finish_sample(label, start_usec)


func _record_playfield_overlay_counters(battle_perf_logger: Object) -> void:
	Stage2PerfCounterRecorder.record_playfield_overlay_counters(
		battle_perf_logger,
		leaf_particles.size(),
		starpoint_particles.size(),
		starpoint_drops.size(),
		border_flash_state.is_active(),
		boss_rage_active or boss_rage_tint > 0.001,
		fragment_hit_flash_state.get_timer() > 0.0,
		skill_warning_state.is_active()
	)


func _record_playfield_obstacle_counters(battle_perf_logger: Object) -> void:
	Stage2PerfCounterRecorder.record_playfield_obstacle_counters(
		battle_perf_logger,
		rocks.size(),
		rock_fragments.size(),
		water_splashes.size(),
		quake_timer > 0.0,
		water_cannon_phase != "idle",
		water_trail.size()
	)


func _perf_maybe_log(context: Dictionary) -> void:
	perf_logger.maybe_log(perf_log_snapshot_builder.build_snapshot(
		int(context.get("current_stage", 1)),
		rocks.size(),
		rock_fragments.size(),
		water_splashes.size(),
		water_trail.size(),
		quake_timer,
		boss_rage_active,
		water_cannon_phase,
		skill_warning_state.get_kind()
	))


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
