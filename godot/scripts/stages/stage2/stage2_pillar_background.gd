extends RefCounted

const Stage2PillarAssetState := preload("res://scripts/stages/stage2/stage2_pillar_asset_state.gd")
const Stage2RenderBudgetHelper := preload("res://scripts/stages/stage2/stage2_render_budget_helper.gd")
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
const Stage2StarpointRuntimeState := preload("res://scripts/stages/stage2/stage2_starpoint_runtime_state.gd")
const Stage2StarpointCoordinator := preload("res://scripts/stages/stage2/stage2_starpoint_coordinator.gd")
const Stage2RockInteractionCoordinator := preload("res://scripts/stages/stage2/stage2_rock_interaction_coordinator.gd")
const Stage2RockLifecycleCoordinator := preload("res://scripts/stages/stage2/stage2_rock_lifecycle_coordinator.gd")
const Stage2ChaosRockAbsorbState := preload("res://scripts/stages/stage2/stage2_chaos_rock_absorb_state.gd")
const Stage2ChaosRockAbsorbCoordinator := preload("res://scripts/stages/stage2/stage2_chaos_rock_absorb_coordinator.gd")
const Stage2WaterCannonRuntimeState := preload("res://scripts/stages/stage2/stage2_water_cannon_runtime_state.gd")
const Stage2WaterCannonCoordinator := preload("res://scripts/stages/stage2/stage2_water_cannon_coordinator.gd")
const Stage2WaterCannonVisualStateBuilder := preload("res://scripts/stages/stage2/stage2_water_cannon_visual_state_builder.gd")
const Stage2QuakeWaveVisualStateBuilder := preload("res://scripts/stages/stage2/stage2_quake_wave_visual_state_builder.gd")
const Stage2RockFragmentMotionState := preload("res://scripts/stages/stage2/stage2_rock_fragment_motion_state.gd")
const Stage2RockFrameCoordinator := preload("res://scripts/stages/stage2/stage2_rock_frame_coordinator.gd")
const Stage2AmbientPayloadFactory := preload("res://scripts/stages/stage2/stage2_ambient_payload_factory.gd")
const Stage2AmbientLayoutHelper := preload("res://scripts/stages/stage2/stage2_ambient_layout_helper.gd")
const Stage2RustlePayloadFactory := preload("res://scripts/stages/stage2/stage2_rustle_payload_factory.gd")
const Stage2RustleSnapshotBuilder := preload("res://scripts/stages/stage2/stage2_rustle_snapshot_builder.gd")
const Stage2RustleState := preload("res://scripts/stages/stage2/stage2_rustle_state.gd")
const Stage2RustleCoordinator := preload("res://scripts/stages/stage2/stage2_rustle_coordinator.gd")
const Stage2ActorDrawContextBuilder := preload("res://scripts/stages/stage2/stage2_actor_draw_context_builder.gd")
const Stage2ImagegenAssetStatusBuilder := preload("res://scripts/stages/stage2/stage2_imagegen_asset_status_builder.gd")
const Stage2AmbientVisualSnapshotBuilder := preload("res://scripts/stages/stage2/stage2_ambient_visual_snapshot_builder.gd")
const Stage2BossAiContextBuilder := preload("res://scripts/stages/stage2/stage2_boss_ai_context_builder.gd")
const Stage2BossRageSnapshotBuilder := preload("res://scripts/stages/stage2/stage2_boss_rage_snapshot_builder.gd")
const Stage2BossRageState := preload("res://scripts/stages/stage2/stage2_boss_rage_state.gd")
const Stage2BossRageCoordinator := preload("res://scripts/stages/stage2/stage2_boss_rage_coordinator.gd")
const Stage2PerfLogSnapshotBuilder := preload("res://scripts/stages/stage2/stage2_perf_log_snapshot_builder.gd")
const Stage2PerfLogger := preload("res://scripts/stages/stage2/stage2_perf_logger.gd")
const Stage2PerfCounterRecorder := preload("res://scripts/stages/stage2/stage2_perf_counter_recorder.gd")
const Stage2CollisionGeometry := preload("res://scripts/stages/stage2/stage2_collision_geometry.gd")
const Stage2PlayfieldBounds := preload("res://scripts/stages/stage2/stage2_playfield_bounds.gd")
const Stage2BossExpressionState := preload("res://scripts/stages/stage2/stage2_boss_expression_state.gd")
const Stage2SkillWarningState := preload("res://scripts/stages/stage2/stage2_skill_warning_state.gd")
const Stage2WallReactionCoordinator := preload("res://scripts/stages/stage2/stage2_wall_reaction_coordinator.gd")
const Stage2RockFeedbackCoordinator := preload("res://scripts/stages/stage2/stage2_rock_feedback_coordinator.gd")
const Stage2FragmentHitFlashState := preload("res://scripts/stages/stage2/stage2_fragment_hit_flash_state.gd")
const Stage2RockQuery := preload("res://scripts/stages/stage2/stage2_rock_query.gd")
const Stage2VisibilityState := preload("res://scripts/stages/stage2/stage2_visibility_state.gd")
const Stage2QuakeRuntimeState := preload("res://scripts/stages/stage2/stage2_quake_runtime_state.gd")
const Stage2QuakeCoordinator := preload("res://scripts/stages/stage2/stage2_quake_coordinator.gd")

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
const QUAKE_DURATION_SEC := Stage2QuakeCoordinator.DEFAULT_DURATION_SEC
const QUAKE_REPEAT_COOLDOWN_SEC := Stage2QuakeCoordinator.REPEAT_COOLDOWN_SEC
const ROCK_IMAGEGEN_MIN_LONG_SIDE := 14.0
const MAX_ROCKS := Stage2RockLifecycleCoordinator.MAX_ROCKS
const WATER_CANNON_CHARGE_SEC := Stage2WaterCannonCoordinator.CHARGE_SEC
const WATER_TRAIL_LIFE_SEC := Stage2WaterCannonCoordinator.TRAIL_LIFE_SEC
const WATER_TRAIL_MAX_COUNT := Stage2WaterCannonCoordinator.TRAIL_MAX_COUNT
const WATER_SPLASH_LIFE_SEC := 1.0
const SKILL_WARNING_DEFAULT_SEC := 1.15
const WATER_SPLASH_RENDER_LIMIT := 8
const WATER_SPLASH_RENDER_LIMIT_SEVERE_LOD := 6
const STARPOINT_PARTICLE_RENDER_LIMIT := 12
const STARPOINT_PARTICLE_RENDER_LIMIT_SEVERE_LOD := 6
const QUAKE_BOSS_LAUNCH_GUARD_SEC := Stage2QuakeCoordinator.BOSS_LAUNCH_GUARD_SEC
const QUAKE_WAVE_COUNT := Stage2QuakeCoordinator.WAVE_COUNT
const QUAKE_WAVE_SEGMENTS := Stage2QuakeCoordinator.WAVE_SEGMENTS
const VISUAL_ONLY_QUAKE_WAVE_COUNT := 2
const VISUAL_ONLY_QUAKE_WAVE_SEGMENTS := 5
const LOD_ACTIVE_THRESHOLD := 0.85
const SEVERE_LOD_ACTIVE_THRESHOLD := 0.66
const CRISIS_PLAYER_SCORE := Stage2BossRageCoordinator.CRISIS_PLAYER_SCORE
const BOSS_RAGE_STOMP_INTERVAL_SEC := Stage2BossRageCoordinator.STOMP_INTERVAL_SEC
const BOSS_RAGE_BUILDUP_SEC := Stage2BossRageCoordinator.BUILDUP_SEC
const BOSS_RAGE_FINAL_STOMP_SEC := Stage2BossRageCoordinator.FINAL_STOMP_SEC
const BOSS_RAGE_TOTAL_SEC := Stage2BossRageCoordinator.TOTAL_SEC
const BOSS_RAGE_CRISIS_ROCK_COUNT_CHAMPION := Stage2BossRageCoordinator.CRISIS_ROCK_COUNT_CHAMPION
const BOSS_RAGE_CRISIS_ROCK_COUNT_MYTHIC := Stage2BossRageCoordinator.CRISIS_ROCK_COUNT_MYTHIC
const BOSS_EXPRESSION_DURATION_SEC := 2.0
var asset_state: Object = Stage2PillarAssetState.new()
var base_texture: Texture2D:
	get:
		return asset_state.base_texture as Texture2D
	set(value):
		asset_state.base_texture = value
var tree_texture: Texture2D:
	get:
		return asset_state.tree_texture as Texture2D
	set(value):
		asset_state.tree_texture = value
var game_frame_texture: Texture2D:
	get:
		return asset_state.game_frame_texture as Texture2D
	set(value):
		asset_state.game_frame_texture = value
var leaf_texture: Texture2D:
	get:
		return asset_state.leaf_texture as Texture2D
	set(value):
		asset_state.leaf_texture = value
var rock_texture: Texture2D:
	get:
		return asset_state.rock_texture as Texture2D
	set(value):
		asset_state.rock_texture = value
var rock_debris_texture: Texture2D:
	get:
		return asset_state.rock_debris_texture as Texture2D
	set(value):
		asset_state.rock_debris_texture = value
var texture_loaded: bool:
	get:
		return bool(asset_state.texture_loaded)
	set(value):
		asset_state.texture_loaded = value
var imagegen_renderer: Object = Stage2PillarImagegenRenderer.new()
var imagegen_assets_builder: Object = Stage2PillarImagegenAssetsBuilder.new()
var obstacle_visual_renderer: Object = Stage2PillarObstacleVisualRenderer.new()
var water_cannon_visual_renderer: Object = Stage2WaterCannonVisualRenderer.new()
var warning_visual_renderer: Object = Stage2WarningVisualRenderer.new()
var screen_overlay_visual_renderer: Object = Stage2ScreenOverlayVisualRenderer.new()
var ambient_visual_renderer: Object = Stage2AmbientVisualRenderer.new()
var ambient_state: Object = Stage2AmbientVisualState.new()
var rock_visual_factory: Object = Stage2RockVisualFactory.new()
var rock_visual_assets_builder: Object = Stage2RockVisualAssetsBuilder.new()
var rock_state: Object = Stage2RockRuntimeState.new()
var starpoint_state: Object = Stage2StarpointRuntimeState.new()
var starpoint_coordinator: Object = Stage2StarpointCoordinator.new()
var rock_fragment_state: Object = Stage2RockFragmentMotionState.new()
var chaos_rock_state: Object = Stage2ChaosRockAbsorbState.new()
var chaos_rock_coordinator: Object = Stage2ChaosRockAbsorbCoordinator.new()
var water_cannon_state: Object = Stage2WaterCannonRuntimeState.new()
var water_cannon_coordinator: Object = Stage2WaterCannonCoordinator.new()
var water_visual_state: Object = Stage2WaterVisualState.new()
var water_cannon_visual_state_builder: Object = Stage2WaterCannonVisualStateBuilder.new()
var quake_wave_visual_state_builder: Object = Stage2QuakeWaveVisualStateBuilder.new()
var ambient_payload_factory: Object = Stage2AmbientPayloadFactory.new()
var ambient_layout_helper: Object = Stage2AmbientLayoutHelper.new()
var rustle_payload_factory: Object = Stage2RustlePayloadFactory.new()
var rustle_state: Object = Stage2RustleState.new()
var rustle_coordinator: Object = Stage2RustleCoordinator.new()
var rustle_snapshot_builder: Object = Stage2RustleSnapshotBuilder.new()
var actor_draw_context_builder: Object = Stage2ActorDrawContextBuilder.new()
var imagegen_asset_status_builder: Object = Stage2ImagegenAssetStatusBuilder.new()
var ambient_visual_snapshot_builder: Object = Stage2AmbientVisualSnapshotBuilder.new()
var boss_ai_context_builder: Object = Stage2BossAiContextBuilder.new()
var boss_rage_snapshot_builder: Object = Stage2BossRageSnapshotBuilder.new()
var boss_rage_state: Object = Stage2BossRageState.new()
var boss_rage_coordinator: Object = Stage2BossRageCoordinator.new()
var perf_log_snapshot_builder: Object = Stage2PerfLogSnapshotBuilder.new()
var perf_logger: Object = Stage2PerfLogger.new()
var collision_geometry: Object = Stage2CollisionGeometry.new()
var playfield_bounds: Object = Stage2PlayfieldBounds.new()
var boss_expression_state: Object = Stage2BossExpressionState.new()
var skill_warning_state: Object = Stage2SkillWarningState.new()
var wall_reaction_coordinator: Object = Stage2WallReactionCoordinator.new()
var rock_feedback_coordinator: Object = Stage2RockFeedbackCoordinator.new()
var rock_interaction_coordinator: Object = Stage2RockInteractionCoordinator.new()
var rock_lifecycle_coordinator: Object = Stage2RockLifecycleCoordinator.new()
var rock_frame_coordinator: Object = Stage2RockFrameCoordinator.new()
var border_flash_state: Object:
	get:
		return wall_reaction_coordinator.border_flash_state as Object
	set(value):
		wall_reaction_coordinator.border_flash_state = value
var fragment_hit_flash_state: Object = Stage2FragmentHitFlashState.new()
var rock_query: Object = Stage2RockQuery.new()
var quake_state: Object = Stage2QuakeRuntimeState.new()
var quake_coordinator: Object = Stage2QuakeCoordinator.new()
var tree_source_regions: Dictionary:
	get:
		return asset_state.tree_source_regions as Dictionary
	set(value):
		asset_state.tree_source_regions = value
var leaf_source_regions: Array:
	get:
		return asset_state.leaf_source_regions as Array
	set(value):
		asset_state.leaf_source_regions = value
var rock_source_regions: Array:
	get:
		return asset_state.rock_source_regions as Array
	set(value):
		asset_state.rock_source_regions = value
var rock_debris_source_regions: Array:
	get:
		return asset_state.rock_debris_source_regions as Array
	set(value):
		asset_state.rock_debris_source_regions = value
var game_frame_hole: Rect2:
	get:
		return asset_state.game_frame_hole
	set(value):
		asset_state.game_frame_hole = value
var game_frame_hole_checked: bool:
	get:
		return bool(asset_state.game_frame_hole_checked)
	set(value):
		asset_state.game_frame_hole_checked = value
var ambient_rng: RandomNumberGenerator:
	get:
		return ambient_state.rng as RandomNumberGenerator
	set(value):
		ambient_state.rng = value
var ambient_time: float:
	get:
		return float(ambient_state.time)
	set(value):
		ambient_state.time = value
var excitement: float:
	get:
		return float(ambient_state.excitement)
	set(value):
		ambient_state.excitement = value
var ambient_layout_size: Vector2:
	get:
		return ambient_state.layout_size as Vector2
	set(value):
		ambient_state.layout_size = value
var ambient_game_offset: Vector2:
	get:
		return ambient_state.game_offset as Vector2
	set(value):
		ambient_state.game_offset = value
var ambient_game_size: Vector2:
	get:
		return ambient_state.game_size as Vector2
	set(value):
		ambient_state.game_size = value
var falling_leaves: Array:
	get:
		return ambient_state.falling_leaves as Array
	set(value):
		ambient_state.falling_leaves = value
var fireflies: Array:
	get:
		return ambient_state.fireflies as Array
	set(value):
		ambient_state.fireflies = value
var leaf_particles: Array:
	get:
		return ambient_state.leaf_particles as Array
	set(value):
		ambient_state.leaf_particles = value
var rocks: Array:
	get:
		return rock_state.rocks as Array
	set(value):
		rock_state.rocks = value
var rock_fragments: Array:
	get:
		return rock_fragment_state.fragments as Array
	set(value):
		rock_fragment_state.fragments = value
var starpoint_drops: Array:
	get:
		return starpoint_state.drops as Array
	set(value):
		starpoint_state.drops = value
var starpoint_particles: Array:
	get:
		return starpoint_state.particles as Array
	set(value):
		starpoint_state.particles = value
var rustle_bushes: Array:
	get:
		return rustle_state.bushes as Array
	set(value):
		rustle_state.bushes = value
var rustle_vines: Array:
	get:
		return rustle_state.vines as Array
	set(value):
		rustle_state.vines = value
var rustle_layout_size: Vector2:
	get:
		return rustle_state.layout_size as Vector2
	set(value):
		rustle_state.layout_size = value
var prev_boss_paddle_center_x: float:
	get:
		return float(rustle_state.prev_boss_center_x)
	set(value):
		rustle_state.prev_boss_center_x = value
var prev_player_paddle_center_x: float:
	get:
		return float(rustle_state.prev_player_center_x)
	set(value):
		rustle_state.prev_player_center_x = value
var boss_paddle_center_valid: bool:
	get:
		return bool(rustle_state.boss_center_valid)
	set(value):
		rustle_state.boss_center_valid = value
var player_paddle_center_valid: bool:
	get:
		return bool(rustle_state.player_center_valid)
	set(value):
		rustle_state.player_center_valid = value
var water_trail: Array:
	get:
		return water_visual_state.trail as Array
	set(value):
		water_visual_state.trail = value
var water_splashes: Array:
	get:
		return water_visual_state.splashes as Array
	set(value):
		water_visual_state.splashes = value
var quake_timer: float:
	get:
		return float(quake_state.timer)
	set(value):
		quake_state.timer = value
var quake_duration: float:
	get:
		return float(quake_state.duration)
	set(value):
		quake_state.duration = value
var quake_cooldown: float:
	get:
		return float(quake_state.cooldown)
	set(value):
		quake_state.cooldown = value
var quake_motion_rng: RandomNumberGenerator:
	get:
		return quake_state.motion_rng as RandomNumberGenerator
	set(value):
		quake_state.motion_rng = value
var quake_ball_rng: RandomNumberGenerator:
	get:
		return quake_state.ball_rng as RandomNumberGenerator
	set(value):
		quake_state.ball_rng = value
var quake_ball_velocity_backup: Vector2:
	get:
		return quake_state.ball_velocity_backup as Vector2
	set(value):
		quake_state.ball_velocity_backup = value
var quake_ball_velocity_backup_valid: bool:
	get:
		return bool(quake_state.ball_velocity_backup_valid)
	set(value):
		quake_state.ball_velocity_backup_valid = value
var quake_boss_launch_guard_timer: float:
	get:
		return float(quake_state.boss_launch_guard_timer)
	set(value):
		quake_state.boss_launch_guard_timer = value
var quake_affects_ball: bool:
	get:
		return bool(quake_state.affects_ball)
	set(value):
		quake_state.affects_ball = value
var quake_audio_active: bool:
	get:
		return bool(quake_state.audio_active)
	set(value):
		quake_state.audio_active = value
var water_cannon_delay: float:
	get:
		return float(water_cannon_state.delay)
	set(value):
		water_cannon_state.delay = value
var water_cannon_phase: String:
	get:
		return str(water_cannon_state.phase)
	set(value):
		water_cannon_state.phase = value
var water_cannon_timer: float:
	get:
		return float(water_cannon_state.timer)
	set(value):
		water_cannon_state.timer = value
var water_cannon_target_id: int:
	get:
		return int(water_cannon_state.target_id)
	set(value):
		water_cannon_state.target_id = value
var water_cannon_start: Vector2:
	get:
		return water_cannon_state.start as Vector2
	set(value):
		water_cannon_state.start = value
var water_cannon_target: Vector2:
	get:
		return water_cannon_state.target as Vector2
	set(value):
		water_cannon_state.target = value
var water_cannon_current: Vector2:
	get:
		return water_cannon_state.current as Vector2
	set(value):
		water_cannon_state.current = value
var water_cannon_progress: float:
	get:
		return float(water_cannon_state.progress)
	set(value):
		water_cannon_state.progress = value
var chaos_rock_absorb_center: Vector2:
	get:
		return chaos_rock_state.center as Vector2
	set(value):
		chaos_rock_state.center = value
var chaos_rock_absorb_timer: float:
	get:
		return float(chaos_rock_state.timer)
	set(value):
		chaos_rock_state.timer = value
var chaos_absorbed_entries: Array:
	get:
		return chaos_rock_state.pending_entries as Array
	set(value):
		chaos_rock_state.pending_entries = value
var rock_next_id: int:
	get:
		return int(rock_state.next_id)
	set(value):
		rock_state.next_id = value
var crisis_triggered: bool:
	get:
		return bool(boss_rage_state.crisis_triggered)
	set(value):
		boss_rage_state.crisis_triggered = value
var boss_rage_pending: bool:
	get:
		return bool(boss_rage_state.pending)
	set(value):
		boss_rage_state.pending = value
var boss_rage_active: bool:
	get:
		return bool(boss_rage_state.active)
	set(value):
		boss_rage_state.active = value
var boss_rage_timer: float:
	get:
		return float(boss_rage_state.timer)
	set(value):
		boss_rage_state.timer = value
var boss_rage_stomp_count: int:
	get:
		return int(boss_rage_state.stomp_count)
	set(value):
		boss_rage_state.stomp_count = value
var boss_rage_final_stomp_done: bool:
	get:
		return bool(boss_rage_state.final_stomp_done)
	set(value):
		boss_rage_state.final_stomp_done = value
var boss_rage_offset_y: float:
	get:
		return float(boss_rage_state.offset_y)
	set(value):
		boss_rage_state.offset_y = value
var boss_rage_tint: float:
	get:
		return float(boss_rage_state.tint)
	set(value):
		boss_rage_state.tint = value
var boss_rage_ai_mode: String:
	get:
		return str(boss_rage_state.ai_mode)
	set(value):
		boss_rage_state.ai_mode = value
var rage_audio: Object:
	get:
		return boss_rage_coordinator.cached_audio as Object
	set(value):
		boss_rage_coordinator.cached_audio = value
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rustle_coordinator.configure(rustle_state, rustle_payload_factory)
	rock_lifecycle_coordinator.configure(
		rock_state,
		rock_query,
		ambient_state,
		water_visual_state,
		water_cannon_state,
		rng,
		rock_visual_factory,
		rock_feedback_coordinator
	)
	chaos_rock_coordinator.configure(
		rock_state,
		rock_query,
		water_visual_state,
		chaos_rock_state
	)
	starpoint_coordinator.configure(
		starpoint_state,
		rng,
		collision_geometry,
		playfield_bounds,
		obstacle_visual_renderer
	)
	rock_frame_coordinator.configure(
		rock_state,
		rock_query,
		rock_lifecycle_coordinator,
		chaos_rock_coordinator,
		chaos_rock_state,
		rock_feedback_coordinator,
		ambient_state,
		rock_fragment_state,
		rng,
		starpoint_coordinator
	)
	water_cannon_coordinator.configure(
		rock_state,
		rock_query,
		water_cannon_state,
		water_visual_state,
		rng,
		skill_warning_state,
		collision_geometry,
		fragment_hit_flash_state,
		rock_feedback_coordinator,
		ambient_state,
		rock_fragment_state
	)
	boss_rage_coordinator.configure(
		boss_rage_state,
		quake_state,
		rock_lifecycle_coordinator,
		skill_warning_state,
		QUAKE_DURATION_SEC,
		QUAKE_REPEAT_COOLDOWN_SEC,
		QUAKE_BOSS_LAUNCH_GUARD_SEC
	)
	quake_coordinator.configure(
		quake_state,
		rock_state,
		water_cannon_state,
		rock_lifecycle_coordinator,
		skill_warning_state,
		boss_rage_coordinator
	)
	quake_coordinator.reset()
	ambient_state.reset(2206)
	rng.seed = 2202
	quake_state.seed_random_sources(2204, 2205)


func reset() -> void:
	ambient_state.reset()
	rock_state.reset()
	rock_fragment_state.reset()
	var had_starpoints: bool = starpoint_state.clear()
	if had_starpoints:
		obstacle_visual_renderer.hide_all_starpoint_drops()
	_reset_rustle_state()
	water_visual_state.reset()
	wall_reaction_coordinator.reset()
	quake_coordinator.reset()
	water_cannon_state.reset()
	chaos_rock_state.reset()
	fragment_hit_flash_state.reset(Stage2WaterCannonCoordinator.FRAGMENT_HIT_FLASH_SEC)
	skill_warning_state.reset(SKILL_WARNING_DEFAULT_SEC)
	boss_rage_coordinator.reset()
	boss_expression_state.reset()


func reset_round(deps: Dictionary = {}) -> void:
	_clear_quake_round_state(deps)
	water_cannon_delay = -1.0
	_cancel_water_cannon()
	water_visual_state.reset()
	fragment_hit_flash_state.reset(Stage2WaterCannonCoordinator.FRAGMENT_HIT_FLASH_SEC)


func update(delta: float, context: Dictionary = {}, deps: Dictionary = {}) -> void:
	var perf_start := _perf_begin()
	var clamped_delta: float = max(0.0, delta)
	_update_ambient_visuals(clamped_delta)
	_update_boss_expression(clamped_delta)
	_update_rustle_reactions(clamped_delta, context)
	_check_crisis_situation(context)
	_update_boss_rage(clamped_delta, deps)
	wall_reaction_coordinator.advance(clamped_delta)
	fragment_hit_flash_state.update(clamped_delta)
	skill_warning_state.update(clamped_delta)
	quake_coordinator.update(clamped_delta, context, deps)
	chaos_rock_coordinator.advance_session(clamped_delta)

	ambient_state.advance_leaf_particles(clamped_delta)

	var fps_scale: float = clamped_delta * 60.0
	_update_starpoint_drops(fps_scale, context, deps)
	_update_starpoint_particles(fps_scale)

	rock_frame_coordinator.advance(
		clamped_delta,
		quake_timer,
		quake_duration,
		deps,
		context,
		rock_debris_source_regions.size()
	)
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
	return quake_coordinator.activate(
		duration_sec,
		rock_count,
		schedule_water_cannon,
		start_boss_launch_guard,
		deps
	)


func apply_quake_ball_motion(scene: Dictionary, context: Dictionary, _deps: Dictionary = {}, fps_scale: float = 1.0) -> bool:
	return quake_coordinator.apply_ball_motion(scene, context, fps_scale)


func force_end_quake_on_player_hit(deps: Dictionary = {}) -> void:
	_clear_quake_round_state(deps)


func _clear_quake_round_state(deps: Dictionary = {}) -> void:
	quake_coordinator.clear_round_state(deps)


func start_boss_rage_animation(deps: Dictionary = {}) -> bool:
	return boss_rage_coordinator.start(deps)


func set_expression(expression: String, duration_sec: float = BOSS_EXPRESSION_DURATION_SEC) -> void:
	boss_expression_state.set_expression(expression, duration_sec)


func resolve_quake_boss_backstop(scene: Dictionary, context: Dictionary, deps: Dictionary = {}) -> bool:
	return quake_coordinator.resolve_boss_backstop(scene, context, deps)


func activate_water_cannon(context: Dictionary = {}, _deps: Dictionary = {}) -> bool:
	return water_cannon_coordinator.activate(context)


func trigger_tree_shake(side: String, impact_y: float, impact_speed: float, field_height: float) -> void:
	wall_reaction_coordinator.trigger(
		side,
		impact_y,
		impact_speed,
		field_height,
		ambient_state,
		ambient_layout_helper,
		ambient_payload_factory,
		rng,
		AMBIENT_MAX_FALLING_LEAVES,
		MAX_LEAF_PARTICLES,
		LEAF_PARTICLE_LIFE_SEC
	)


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
	return rock_interaction_coordinator.resolve_ball_collision(
		scene,
		context,
		rock_state,
		rock_query,
		collision_geometry,
		Callable(self, "_hit_rock"),
		deps
	)


func resolve_blade_projectile_collision(blade_rect: Rect2, deps: Dictionary = {}, context: Dictionary = {}) -> int:
	return rock_interaction_coordinator.resolve_blade_projectile_collision(
		blade_rect,
		context,
		rock_state,
		rock_query,
		collision_geometry,
		Callable(self, "_hit_rock"),
		deps
	)


func resolve_explosion_rock_collision(center: Vector2, radius: float, deps: Dictionary = {}, context: Dictionary = {}) -> int:
	return rock_interaction_coordinator.resolve_explosion_rock_collision(
		center,
		radius,
		context,
		rock_state,
		rock_query,
		Callable(self, "_hit_rock"),
		deps
	)


func resolve_pistol_projectile_rock_bounce(projectile: Dictionary, deps: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	return rock_interaction_coordinator.resolve_pistol_projectile_rock_bounce(
		projectile,
		context,
		rock_state,
		rock_query,
		collision_geometry,
		Callable(self, "_mark_rock_ricochet"),
		deps
	)


func absorb_chaos_spear_objects(center: Vector2, radius: float, _deps: Dictionary = {}) -> Array:
	return chaos_rock_coordinator.refresh_absorption(center, radius)


func has_visible_effects() -> bool:
	return Stage2VisibilityState.has_visible_effects(
		has_visible_playfield_overlay(),
		has_visible_playfield_obstacles(),
		rustle_state.has_active_effects()
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
	return rock_state.get_snapshot()


func get_starpoint_drop_count() -> int:
	return starpoint_state.get_drop_count()


func get_starpoint_drops_snapshot() -> Array:
	return starpoint_state.get_drop_snapshot()


func get_water_cannon_phase() -> String:
	return water_cannon_phase


func interrupt_water_cannon_charge_on_boss_hit() -> bool:
	return water_cannon_coordinator.interrupt_charge_on_boss_hit()


func get_water_splash_count() -> int:
	return water_splashes.size()


func get_water_splashes_snapshot() -> Array:
	return water_visual_state.get_splashes_snapshot()


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
	return quake_coordinator.is_active()


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
		boss_expression_state.get_snapshot(),
		{
			"active": quake_timer > 0.0,
			"timer": quake_timer,
			"duration": quake_duration,
		}
	)


func get_imagegen_asset_status() -> Dictionary:
	asset_state.ensure_textures()
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
	if not asset_state.prewarm_assets_step():
		return false
	_ensure_ambient_layout(view_size, game_offset, game_size)
	return true


func get_ambient_visual_snapshot(
	view_size: Vector2 = Vector2(1280.0, 800.0),
	game_offset: Vector2 = Vector2(260.0, 0.0),
	game_size: Vector2 = Vector2(760.0, 750.0)
) -> Dictionary:
	asset_state.ensure_textures()
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
	asset_state.ensure_textures()
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
	asset_state.ensure_textures()
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


func _draw_imagegen_pillars(canvas: CanvasItem, view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> void:
	var imagegen_assets: Dictionary = imagegen_assets_builder.build_assets(
		base_texture,
		tree_texture,
		tree_source_regions,
		game_frame_texture,
		asset_state.get_game_frame_source_hole()
	)
	imagegen_renderer.draw(canvas, view_size, game_offset, game_size, imagegen_assets)


func _draw_imagegen_pillar_background_overlay(canvas: CanvasItem, view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> void:
	var imagegen_assets: Dictionary = imagegen_assets_builder.build_assets(
		base_texture,
		tree_texture,
		tree_source_regions,
		game_frame_texture,
		asset_state.get_game_frame_source_hole()
	)
	imagegen_renderer.draw_background_overlay(canvas, view_size, game_offset, game_size, imagegen_assets)


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
	ambient_state.ensure_layout(
		view_size,
		game_offset,
		game_size,
		ambient_layout_helper,
		ambient_payload_factory,
		AMBIENT_INITIAL_LEAF_COUNT,
		AMBIENT_FIREFLY_COUNT
	)


func _update_ambient_visuals(delta: float) -> void:
	ambient_state.advance_ambient(
		delta,
		ambient_layout_helper,
		ambient_payload_factory,
		AMBIENT_LEAF_SPAWN_RATE,
		AMBIENT_MAX_FALLING_LEAVES
	)


func _reset_rustle_state() -> void:
	rustle_coordinator.reset()


func _ensure_rustle_layout(width: float, height: float) -> void:
	rustle_coordinator.ensure_layout(width, height)


func _update_rustle_reactions(delta: float, context: Dictionary) -> void:
	rustle_coordinator.update(delta, context)


func _trigger_bush_rustle(area: String, paddle_center_x: float, delta_x: float, dash_like: bool) -> void:
	rustle_coordinator.trigger_bush(area, paddle_center_x, delta_x, dash_like)


func _trigger_vine_rustle(paddle_center_x: float, delta_x: float, dash_like: bool) -> void:
	rustle_coordinator.trigger_vine(paddle_center_x, delta_x, dash_like)


func _update_chaos_absorbing_rock(rock: Dictionary, delta: float, deps: Dictionary, context: Dictionary = {}) -> bool:
	return rock_frame_coordinator.update_chaos_absorbing_rock(
		rock,
		delta,
		deps,
		context,
		rock_debris_source_regions.size()
	)


func _step_chaos_absorbing_rock(rock: Dictionary, center: Vector2, frame_step: float, deps: Dictionary, context: Dictionary = {}) -> bool:
	return rock_frame_coordinator.step_chaos_absorbing_rock(
		rock,
		center,
		frame_step,
		deps,
		context,
		rock_debris_source_regions.size()
	)


func _destroy_chaos_absorbed_rock(rock: Dictionary, center: Vector2, deps: Dictionary, context: Dictionary = {}) -> void:
	rock_frame_coordinator.destroy_chaos_absorbed_rock(
		rock,
		center,
		deps,
		context,
		rock_debris_source_regions.size()
	)


func _spawn_quake_rocks(count: int, deps: Dictionary = {}) -> void:
	rock_lifecycle_coordinator.spawn_quake_rocks(count, deps)


func _spawn_crisis_rock_wall(deps: Dictionary = {}) -> void:
	boss_rage_coordinator.spawn_crisis_rock_wall(deps)


func _hit_rock(index: int, deps: Dictionary, context: Dictionary = {}) -> void:
	rock_feedback_coordinator.apply_hit(
		index,
		rock_state,
		rock_query,
		ambient_state,
		rock_fragment_state,
		rng,
		deps,
		Callable(self, "_spawn_starpoint_drop_at").bind(deps, context),
		rock_debris_source_regions.size()
	)


func _mark_rock_ricochet(index: int, deps: Dictionary) -> void:
	rock_feedback_coordinator.mark_ricochet(index, rock_state, deps)


func _spawn_rock_fragments(rock: Dictionary, center: Vector2) -> void:
	rock_feedback_coordinator.emit_fragment_burst(
		rock,
		center,
		rock_fragment_state,
		rng,
		rock_debris_source_regions.size(),
		MAX_ROCK_FRAGMENTS,
		ROCK_FRAGMENT_LIFE_SEC
	)


func _update_rock_fragments(delta: float) -> void:
	rock_frame_coordinator.advance_fragments(delta)


func _spawn_rock_leaves(center: Vector2, strength: float) -> void:
	rock_feedback_coordinator.emit_leaf_burst(
		center,
		strength,
		ambient_state,
		rng,
		MAX_LEAF_PARTICLES,
		LEAF_PARTICLE_LIFE_SEC
	)


func spawn_starpoint_drop(pos: Vector2, _source_type: String = "", deps: Dictionary = {}, context: Dictionary = {}) -> void:
	_spawn_starpoint_drop_at(pos, deps, context)


func _spawn_starpoint_drop_at(
	pos: Vector2,
	deps: Dictionary = {},
	context: Dictionary = {},
	allow_star_detector_bonus: bool = true,
	star_detector_bonus: bool = false
) -> void:
	starpoint_coordinator.spawn_drop_at(pos, deps, context, allow_star_detector_bonus, star_detector_bonus)


func _spawn_star_detector_bonus_drops(pos: Vector2, deps: Dictionary, context: Dictionary) -> void:
	starpoint_coordinator.spawn_star_detector_bonus_drops(pos, deps, context)


func _update_starpoint_drops(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	starpoint_coordinator.update_drops(fps_scale, context, deps)


func _collect_starpoint_drop(drop: Dictionary, context: Dictionary, deps: Dictionary) -> bool:
	return starpoint_coordinator.collect_drop(drop, context, deps)


func _spawn_starpoint_particles(pos: Vector2, count: int, intensity: float) -> void:
	starpoint_coordinator.spawn_particles(pos, count, intensity)


func _update_starpoint_particles(fps_scale: float) -> void:
	starpoint_coordinator.update_particles(fps_scale)


func _check_crisis_situation(context: Dictionary) -> bool:
	return boss_rage_coordinator.reserve_crisis(context)


func _get_boss_rage_crisis_rock_count() -> int:
	return boss_rage_coordinator.get_crisis_rock_count()


func _update_boss_expression(delta: float) -> void:
	boss_expression_state.update(delta)


func _update_boss_rage(delta: float, deps: Dictionary) -> void:
	boss_rage_coordinator.update(delta, deps)


func _update_quake_rock_drop(rock: Dictionary, delta: float) -> void:
	rock_frame_coordinator.update_quake_rock_drop(rock, delta)


func _update_water_cannon(delta: float, context: Dictionary, deps: Dictionary) -> void:
	var cannon_events: Dictionary = water_cannon_coordinator.update(delta, context, deps)
	if bool(cannon_events.get("finished", false)):
		_finish_water_cannon(context, deps)


func _update_water_visuals(delta: float) -> void:
	water_cannon_coordinator.advance_visuals(delta)


func _resolve_water_fragment_player_hits(context: Dictionary, deps: Dictionary) -> void:
	water_cannon_coordinator.resolve_fragment_player_hits(context, deps)


func _finish_water_cannon(context: Dictionary, deps: Dictionary) -> void:
	water_cannon_coordinator.finish_impact(
		deps,
		Callable(self, "_spawn_starpoint_drop_at").bind(deps, context),
		rock_debris_source_regions.size()
	)


func _cancel_water_cannon() -> void:
	water_cannon_coordinator.cancel()


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
