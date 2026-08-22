extends RefCounted

const Stage4PonkIllusionState := preload("res://scripts/stages/stage4/stage4_ponk_illusion_state.gd")
const Stage4PonkMagneticFieldState := preload("res://scripts/stages/stage4/stage4_ponk_magnetic_field_state.gd")
const Stage4PonkMagneticProjectileState := preload("res://scripts/stages/stage4/stage4_ponk_magnetic_projectile_state.gd")
const Stage4PonkMeditationState := preload("res://scripts/stages/stage4/stage4_ponk_meditation_state.gd")
const Stage4PonkSkillCardStateBuilder := preload("res://scripts/stages/stage4/stage4_ponk_skill_card_state_builder.gd")
const Stage4PonkFxHostCoordinator := preload("res://scripts/stages/stage4/stage4_ponk_fx_host_coordinator.gd")
const Stage4PonkFxContextBuilder := preload("res://scripts/stages/stage4/stage4_ponk_fx_context_builder.gd")
const Stage4PonkFallbackFxRenderer := preload("res://scripts/stages/stage4/stage4_ponk_fallback_fx_renderer.gd")
const Stage4PonkBallInteractionCoordinator := preload("res://scripts/stages/stage4/stage4_ponk_ball_interaction_coordinator.gd")
const Stage4PonkRuntimeCoordinator := preload("res://scripts/stages/stage4/stage4_ponk_runtime_coordinator.gd")
const Stage4PonkPresentationCoordinator := preload("res://scripts/stages/stage4/stage4_ponk_presentation_coordinator.gd")

const STAGE_ID := 4
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const GAUGE_MAX := Stage4PonkRuntimeCoordinator.GAUGE_MAX
const MAGNETIC_COOLDOWN_SEC := Stage4PonkMagneticFieldState.COOLDOWN_SEC
const MEDITATION_COOLDOWN_SEC := Stage4PonkMeditationState.COOLDOWN_SEC
const MEDITATION_CHANCE := Stage4PonkRuntimeCoordinator.MEDITATION_CHANCE
const MAGNETIC_RADIUS := Stage4PonkMagneticFieldState.RADIUS
const MAGNETIC_ENRAGED_RADIUS := Stage4PonkMagneticFieldState.ENRAGED_RADIUS
const MAGNETIC_PROJECTILE_SPEED := Stage4PonkMagneticProjectileState.PROJECTILE_SPEED
const MAGNETIC_PROJECTILE_HOMING_X_SPEED := Stage4PonkMagneticProjectileState.PROJECTILE_HOMING_X_SPEED
const MAGNETIC_PROJECTILE_ENRAGED_HOMING_X_SPEED := Stage4PonkMagneticProjectileState.PROJECTILE_ENRAGED_HOMING_X_SPEED
const MAGNETIC_PROJECTILE_SLOW_FRAMES := Stage4PonkMagneticProjectileState.PROJECTILE_SLOW_FRAMES
const MAGNETIC_PROJECTILE_SLOW_MULTIPLIER := Stage4PonkMagneticProjectileState.PROJECTILE_SLOW_MULTIPLIER
const MAGNETIC_PROJECTILE_CONTACT_Y_SPEED_MULTIPLIER := Stage4PonkMagneticProjectileState.PROJECTILE_CONTACT_Y_SPEED_MULTIPLIER
const MEDITATION_TRAIL_MAX := Stage4PonkMeditationState.TRAIL_MAX
const MEDITATION_PARTICLE_MAX := Stage4PonkMeditationState.PARTICLE_MAX
const MEDITATION_RELEASE_MAX_BALL_SPEED := Stage4PonkMeditationState.RELEASE_MAX_BALL_SPEED
const MEDITATION_RELEASE_SPEED_BONUS_MIN := Stage4PonkMeditationState.RELEASE_SPEED_BONUS_MIN
const MEDITATION_RELEASE_SPEED_BONUS_MAX := Stage4PonkMeditationState.RELEASE_SPEED_BONUS_MAX
const BALL_BASE_SPEED_FALLBACK := Stage4PonkBallInteractionCoordinator.BALL_BASE_SPEED_FALLBACK
const ILLUSION_UNLOCK_PLAYER_SCORE := Stage4PonkIllusionState.ILLUSION_UNLOCK_PLAYER_SCORE
const ILLUSION_COOLDOWN_SEC := Stage4PonkIllusionState.ILLUSION_COOLDOWN_SEC
const ILLUSION_FIRST_CAST_DELAY_FRAMES := Stage4PonkIllusionState.ILLUSION_FIRST_CAST_DELAY_FRAMES
const ILLUSION_AWAKEN_BURST_FRAMES := Stage4PonkIllusionState.ILLUSION_AWAKEN_BURST_FRAMES
const ILLUSION_AWAKEN_STAGE_LOCKED := Stage4PonkIllusionState.ILLUSION_AWAKEN_STAGE_LOCKED
const ILLUSION_AWAKEN_STAGE_WAIT_SERVE := Stage4PonkIllusionState.ILLUSION_AWAKEN_STAGE_WAIT_SERVE
const ILLUSION_AWAKEN_STAGE_SERVE_WAIT := Stage4PonkIllusionState.ILLUSION_AWAKEN_STAGE_SERVE_WAIT
const ILLUSION_AWAKEN_STAGE_COUNTDOWN := Stage4PonkIllusionState.ILLUSION_AWAKEN_STAGE_COUNTDOWN
const ILLUSION_AWAKEN_STAGE_LOOP := Stage4PonkIllusionState.ILLUSION_AWAKEN_STAGE_LOOP

var rng := RandomNumberGenerator.new()
var _illusion_state := Stage4PonkIllusionState.new()
var _magnetic_field_state := Stage4PonkMagneticFieldState.new()
var _magnetic_projectile_state := Stage4PonkMagneticProjectileState.new()
var _meditation_state := Stage4PonkMeditationState.new(rng)
var _skill_card_state_builder := Stage4PonkSkillCardStateBuilder.new()
var _fx_host_coordinator := Stage4PonkFxHostCoordinator.new()
var _fx_context_builder := Stage4PonkFxContextBuilder.new()
var _ball_interaction_coordinator := Stage4PonkBallInteractionCoordinator.new()
var _runtime_coordinator := Stage4PonkRuntimeCoordinator.new(
	_magnetic_field_state,
	_magnetic_projectile_state,
	_meditation_state,
	_illusion_state,
	_fx_host_coordinator,
	_ball_interaction_coordinator
)
var _presentation_coordinator := Stage4PonkPresentationCoordinator.new(
	_fx_host_coordinator,
	_fx_context_builder,
	Stage4PonkFallbackFxRenderer.new(),
	_runtime_coordinator,
	_magnetic_field_state,
	_magnetic_projectile_state,
	_meditation_state,
	_illusion_state
)

var _fallback_fx_renderer: Object:
	get:
		return _presentation_coordinator.fallback_fx_renderer
	set(value):
		_presentation_coordinator.fallback_fx_renderer = value

var magnetic_sheet: Texture2D:
	get:
		return _fallback_fx_renderer.get("magnetic_sheet") as Texture2D
	set(value):
		_fallback_fx_renderer.set("magnetic_sheet", value)

var textures_loaded: bool:
	get:
		return bool(_fallback_fx_renderer.get("textures_loaded"))
	set(value):
		_fallback_fx_renderer.set("textures_loaded", value)

var frame_clock: float:
	get:
		return _runtime_coordinator.frame_clock
	set(value):
		_runtime_coordinator.frame_clock = value

var boss_special_gauge: float:
	get:
		return _runtime_coordinator.boss_special_gauge
	set(value):
		_runtime_coordinator.boss_special_gauge = value

var boss_special_ready: bool:
	get:
		return _runtime_coordinator.boss_special_ready
	set(value):
		_runtime_coordinator.boss_special_ready = value

# Compatibility properties preserve existing diagnostics and focused fixtures;
# mutable field/curvature state lives only in Stage4PonkMagneticFieldState.
var magnetic_cooldown_seconds: float:
	get:
		return _magnetic_field_state.magnetic_cooldown_seconds
	set(value):
		_magnetic_field_state.magnetic_cooldown_seconds = value

var magnetic_active: bool:
	get:
		return _magnetic_field_state.magnetic_active
	set(value):
		_magnetic_field_state.magnetic_active = value

var magnetic_timer_frames: float:
	get:
		return _magnetic_field_state.magnetic_timer_frames
	set(value):
		_magnetic_field_state.magnetic_timer_frames = value

var magnetic_radius: float:
	get:
		return _magnetic_field_state.magnetic_radius
	set(value):
		_magnetic_field_state.magnetic_radius = value

var magnetic_enraged: bool:
	get:
		return _magnetic_field_state.magnetic_enraged
	set(value):
		_magnetic_field_state.magnetic_enraged = value

var magnetic_center: Vector2:
	get:
		return _magnetic_field_state.magnetic_center
	set(value):
		_magnetic_field_state.magnetic_center = value

var magnet_curve_angle_degrees: float:
	get:
		return _magnetic_field_state.magnet_curve_angle_degrees
	set(value):
		_magnetic_field_state.magnet_curve_angle_degrees = value

var magnetic_release_pending: bool:
	get:
		return _magnetic_field_state.magnetic_release_pending
	set(value):
		_magnetic_field_state.magnetic_release_pending = value

var magnetic_release_min_speed: float:
	get:
		return _magnetic_field_state.magnetic_release_min_speed
	set(value):
		_magnetic_field_state.magnetic_release_min_speed = value

# Compatibility properties preserve existing diagnostics and focused fixtures;
# mutable projectile state lives only in Stage4PonkMagneticProjectileState.
var magnetic_projectile_active: bool:
	get:
		return _magnetic_projectile_state.active
	set(value):
		_magnetic_projectile_state.active = value

var magnetic_projectile_pos: Vector2:
	get:
		return _magnetic_projectile_state.pos
	set(value):
		_magnetic_projectile_state.pos = value

var magnetic_projectile_radius: float:
	get:
		return _magnetic_projectile_state.radius
	set(value):
		_magnetic_projectile_state.radius = value

var magnetic_projectile_elapsed_seconds: float:
	get:
		return _magnetic_projectile_state.elapsed_seconds
	set(value):
		_magnetic_projectile_state.elapsed_seconds = value

var magnetic_projectile_velocity: Vector2:
	get:
		return _magnetic_projectile_state.velocity
	set(value):
		_magnetic_projectile_state.velocity = value

var magnetic_projectile_y_speed_multiplier: float:
	get:
		return _magnetic_projectile_state.y_speed_multiplier
	set(value):
		_magnetic_projectile_state.y_speed_multiplier = value

var magnetic_projectile_fade_timer_seconds: float:
	get:
		return _magnetic_projectile_state.fade_timer_seconds
	set(value):
		_magnetic_projectile_state.fade_timer_seconds = value

var magnetic_projectile_fade_pos: Vector2:
	get:
		return _magnetic_projectile_state.fade_pos
	set(value):
		_magnetic_projectile_state.fade_pos = value

var magnetic_projectile_fade_radius: float:
	get:
		return _magnetic_projectile_state.fade_radius
	set(value):
		_magnetic_projectile_state.fade_radius = value

var magnetic_projectile_fade_velocity: Vector2:
	get:
		return _magnetic_projectile_state.fade_velocity
	set(value):
		_magnetic_projectile_state.fade_velocity = value
var magnetic_fx_host: Node:
	get:
		return _fx_host_coordinator.magnetic_fx_host
	set(value):
		_fx_host_coordinator.magnetic_fx_host = value

# Compatibility properties preserve existing diagnostics and fixtures;
# mutable meditation state lives only in Stage4PonkMeditationState.
var meditation_active: bool:
	get:
		return _meditation_state.meditation_active
	set(value):
		_meditation_state.meditation_active = value

var meditation_timer_frames: float:
	get:
		return _meditation_state.meditation_timer_frames
	set(value):
		_meditation_state.meditation_timer_frames = value

var meditation_angle_degrees: float:
	get:
		return _meditation_state.meditation_angle_degrees
	set(value):
		_meditation_state.meditation_angle_degrees = value

var meditation_ball_pos: Vector2:
	get:
		return _meditation_state.meditation_ball_pos
	set(value):
		_meditation_state.meditation_ball_pos = value

var meditation_trails: Array:
	get:
		return _meditation_state.meditation_trails
	set(value):
		_meditation_state.meditation_trails = value

var meditation_particles: Array:
	get:
		return _meditation_state.meditation_particles
	set(value):
		_meditation_state.meditation_particles = value

var meditation_circles: Array:
	get:
		return _meditation_state.meditation_circles
	set(value):
		_meditation_state.meditation_circles = value

var meditation_release_pending: bool:
	get:
		return _meditation_state.meditation_release_pending
	set(value):
		_meditation_state.meditation_release_pending = value

var meditation_release_velocity: Vector2:
	get:
		return _meditation_state.meditation_release_velocity
	set(value):
		_meditation_state.meditation_release_velocity = value

var meditation_cooldown_seconds: float:
	get:
		return _meditation_state.meditation_cooldown_seconds
	set(value):
		_meditation_state.meditation_cooldown_seconds = value

var meditation_release_fx_timer_frames: float:
	get:
		return _meditation_state.meditation_release_fx_timer_frames
	set(value):
		_meditation_state.meditation_release_fx_timer_frames = value

var meditation_release_fx_origin: Vector2:
	get:
		return _meditation_state.meditation_release_fx_origin
	set(value):
		_meditation_state.meditation_release_fx_origin = value

var meditation_release_fx_pos: Vector2:
	get:
		return _meditation_state.meditation_release_fx_pos
	set(value):
		_meditation_state.meditation_release_fx_pos = value

var meditation_release_fx_velocity: Vector2:
	get:
		return _meditation_state.meditation_release_fx_velocity
	set(value):
		_meditation_state.meditation_release_fx_velocity = value

var meditation_release_fx_trails: Array:
	get:
		return _meditation_state.meditation_release_fx_trails
	set(value):
		_meditation_state.meditation_release_fx_trails = value

var meditation_release_fx_id: int:
	get:
		return _meditation_state.meditation_release_fx_id
	set(value):
		_meditation_state.meditation_release_fx_id = value
var meditation_fx_host: Node:
	get:
		return _fx_host_coordinator.meditation_fx_host
	set(value):
		_fx_host_coordinator.meditation_fx_host = value
# Compatibility properties preserve the established diagnostic/test surface;
# mutable illusion state lives only in Stage4PonkIllusionState.
var illusion_unlocked: bool:
	get:
		return _illusion_state.illusion_unlocked
	set(value):
		_illusion_state.illusion_unlocked = value

var illusion_awaken_stage: int:
	get:
		return _illusion_state.illusion_awaken_stage
	set(value):
		_illusion_state.illusion_awaken_stage = value

var illusion_first_cast_delay_frames: float:
	get:
		return _illusion_state.illusion_first_cast_delay_frames
	set(value):
		_illusion_state.illusion_first_cast_delay_frames = value

var illusion_awaken_burst_frames: float:
	get:
		return _illusion_state.illusion_awaken_burst_frames
	set(value):
		_illusion_state.illusion_awaken_burst_frames = value

var illusion_awaken_burst_played: bool:
	get:
		return _illusion_state.illusion_awaken_burst_played
	set(value):
		_illusion_state.illusion_awaken_burst_played = value

var illusion_active: bool:
	get:
		return _illusion_state.illusion_active
	set(value):
		_illusion_state.illusion_active = value

var illusion_timer_frames: float:
	get:
		return _illusion_state.illusion_timer_frames
	set(value):
		_illusion_state.illusion_timer_frames = value

var illusion_cooldown_seconds: float:
	get:
		return _illusion_state.illusion_cooldown_seconds
	set(value):
		_illusion_state.illusion_cooldown_seconds = value

var illusion_aura_enraged: bool:
	get:
		return _illusion_state.illusion_aura_enraged
	set(value):
		_illusion_state.illusion_aura_enraged = value

var illusion_fx_host: Node:
	get:
		return _fx_host_coordinator.illusion_fx_host
	set(value):
		_fx_host_coordinator.illusion_fx_host = value

var awaken_aura_fx_host: Node:
	get:
		return _fx_host_coordinator.awaken_aura_fx_host
	set(value):
		_fx_host_coordinator.awaken_aura_fx_host = value

var fx_hosts_prewarmed: bool:
	get:
		return _fx_host_coordinator.fx_hosts_prewarmed
	set(value):
		_fx_host_coordinator.fx_hosts_prewarmed = value

func _init() -> void:
	rng.randomize()


func prewarm_assets() -> void:
	_presentation_coordinator.prewarm_assets()


func prewarm_assets_step() -> bool:
	return _presentation_coordinator.prewarm_assets_step()


func prewarm_runtime_hosts(canvas: CanvasItem) -> void:
	_presentation_coordinator.prewarm_runtime_hosts(canvas)


func prewarm_runtime_hosts_step(canvas: CanvasItem) -> bool:
	return _presentation_coordinator.prewarm_runtime_hosts_step(canvas)


func reset() -> void:
	_runtime_coordinator.reset()


func reset_round(deps: Dictionary = {}) -> void:
	_runtime_coordinator.reset_round(deps)


func reset_for_result() -> void:
	reset()


func update(delta: float, context: Dictionary = {}, deps: Dictionary = {}) -> Dictionary:
	_runtime_coordinator.update(delta, context, deps)
	return get_debug_snapshot()


func handle_score_event(scoring_side: String, score_result: Dictionary, _deps: Dictionary = {}) -> void:
	_runtime_coordinator.handle_score_event(scoring_side, score_result)


func register_boss_hit(_ball_vel: Vector2, context: Dictionary = {}, deps: Dictionary = {}) -> Dictionary:
	_runtime_coordinator.register_boss_hit(context, deps)
	return get_debug_snapshot()


func apply_gauge_delta(delta: float) -> Dictionary:
	_runtime_coordinator.apply_gauge_delta(delta)
	return get_debug_snapshot()


func apply_ball_motion(scene: Dictionary, context: Dictionary = {}, deps: Dictionary = {}, fps_scale: float = 1.0) -> bool:
	return _ball_interaction_coordinator.apply_ball_motion(
		scene,
		context,
		deps,
		fps_scale,
		_meditation_state,
		_magnetic_field_state
	)


func resolve_ball_collision(scene: Dictionary, context: Dictionary = {}, deps: Dictionary = {}) -> bool:
	return _ball_interaction_coordinator.resolve_ball_collision(
		scene,
		context,
		deps,
		_magnetic_projectile_state
	)


func force_activate_magnetic(context: Dictionary = {}, deps: Dictionary = {}) -> bool:
	return _runtime_coordinator.force_activate_magnetic(context, deps)


func force_activate_meditation(context: Dictionary = {}, deps: Dictionary = {}) -> bool:
	return _runtime_coordinator.force_activate_meditation(context, deps)


func force_activate_illusion() -> bool:
	return _illusion_state.force_activate()


func force_spawn_magnetic_projectile(pos: Vector2, radius: float = MAGNETIC_RADIUS) -> bool:
	return _magnetic_projectile_state.spawn(pos, radius)


func set_meditation_chance_for_tests(value: float) -> void:
	_runtime_coordinator.set_meditation_chance_for_tests(value)


func get_hud_context() -> Dictionary:
	var result := {
		"stage4_ponk_gauge_visible": true,
		"stage4_ponk_gauge_value": boss_special_gauge,
		"stage4_ponk_gauge_max": GAUGE_MAX,
		"stage4_ponk_gauge_ready": boss_special_ready,
		"stage4_ponk_gauge_active": magnetic_active or meditation_active or illusion_active,
	}
	result.merge(get_skill_card_hud_context(), true)
	return result


func get_skill_card_hud_context(_owner: Object = null, _context: Dictionary = {}) -> Dictionary:
	return _skill_card_state_builder.build_context(
		_magnetic_field_state,
		_meditation_state,
		_illusion_state,
		_get_meditation_chance()
	)


func get_actor_draw_context(copy_arrays: bool = false) -> Dictionary:
	var result := {
		"stage4_ponk_gauge_value": boss_special_gauge,
		"stage4_ponk_gauge_max": GAUGE_MAX,
		"stage4_ponk_gauge_ready": boss_special_ready,
		"stage4_ponk_gauge_active": magnetic_active or meditation_active or illusion_active,
		"stage4_magnetic_frame": _get_current_frame_index(),
		"stage4_effect_clock": frame_clock,
	}
	result.merge(_magnetic_field_state.get_actor_draw_context(), true)
	result.merge(_meditation_state.get_actor_draw_context(copy_arrays), true)
	result.merge(_magnetic_projectile_state.get_actor_draw_context(), true)
	result.merge(_illusion_state.get_actor_draw_context(_presentation_coordinator.has_loaded_awaken_aura_pipeline()), true)
	return result


func get_debug_snapshot() -> Dictionary:
	var snapshot := get_hud_context()
	snapshot.merge({
		"awaken_aura_fx_host_attached": _is_valid_awaken_aura_fx_host(),
	}, true)
	snapshot.merge(_magnetic_field_state.get_snapshot(), true)
	snapshot.merge(_meditation_state.get_snapshot(), true)
	snapshot.merge(_magnetic_projectile_state.get_snapshot(), true)
	snapshot.merge(_illusion_state.get_snapshot(), true)
	return snapshot


func get_asset_status() -> Dictionary:
	return _presentation_coordinator.get_asset_status()


func draw(canvas: CanvasItem, context: Dictionary = {}, shake_offset: Vector2 = Vector2.ZERO) -> void:
	_presentation_coordinator.draw(canvas, context, shake_offset)


func _ensure_textures() -> void:
	_presentation_coordinator.ensure_textures()


func _sync_draw_clock(context: Dictionary) -> void:
	_presentation_coordinator.sync_draw_clock(context)


func _get_illusion_awaken_aura_intensity(context: Dictionary) -> float:
	return _presentation_coordinator.get_illusion_awaken_aura_intensity(context)


func _draw_magnetic_field(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	_presentation_coordinator.draw_magnetic_field(canvas, context, shake_offset)


func _draw_magnetic_projectile(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	_presentation_coordinator.draw_magnetic_projectile(canvas, context, shake_offset)


func _sync_magnetic_fx_host(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, active: bool) -> bool:
	return _presentation_coordinator.sync_magnetic_fx_host(canvas, context, shake_offset, active)


func _build_magnetic_fx_context(context: Dictionary, shake_offset: Vector2) -> Dictionary:
	return _presentation_coordinator.build_magnetic_fx_context(context, shake_offset)


func _is_valid_magnetic_fx_host() -> bool:
	return _presentation_coordinator.is_valid_magnetic_fx_host()


func _sync_meditation_fx_host(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, active: bool) -> bool:
	return _presentation_coordinator.sync_meditation_fx_host(canvas, context, shake_offset, active)


func _build_meditation_fx_context(context: Dictionary, shake_offset: Vector2) -> Dictionary:
	return _presentation_coordinator.build_meditation_fx_context(context, shake_offset)


func _is_valid_meditation_fx_host() -> bool:
	return _presentation_coordinator.is_valid_meditation_fx_host()


func _sync_illusion_fx_host(canvas: CanvasItem, context: Dictionary, active: bool) -> bool:
	return _presentation_coordinator.sync_illusion_fx_host(canvas, context, active)


func _build_illusion_fx_context(context: Dictionary, canvas: CanvasItem = null) -> Dictionary:
	return _presentation_coordinator.build_illusion_fx_context(context, canvas)


func _is_valid_illusion_fx_host() -> bool:
	return _presentation_coordinator.is_valid_illusion_fx_host()


func _sync_awaken_aura_fx_host(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, active: bool) -> bool:
	return _presentation_coordinator.sync_awaken_aura_fx_host(canvas, context, shake_offset, active)


func _build_awaken_aura_fx_context(context: Dictionary, shake_offset: Vector2) -> Dictionary:
	return _presentation_coordinator.build_awaken_aura_fx_context(context, shake_offset)


func _is_valid_awaken_aura_fx_host() -> bool:
	return _presentation_coordinator.is_valid_awaken_aura_fx_host()


func _draw_meditation(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	_presentation_coordinator.draw_meditation(canvas, context, shake_offset)


func _get_current_frame_index() -> int:
	return _presentation_coordinator.get_current_frame_index()


func _get_meditation_chance() -> float:
	return _runtime_coordinator.get_meditation_chance()
