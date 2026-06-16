extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Stage4PonkMagneticAssets := preload("res://scripts/stages/stage4/stage4_ponk_magnetic_assets.gd")
const Stage4PonkMagneticFxHost := preload("res://scripts/stages/stage4/stage4_ponk_magnetic_fx_host.gd")
const Stage4PonkMeditationFxHost := preload("res://scripts/stages/stage4/stage4_ponk_meditation_fx_host.gd")
const Stage4PonkSkillPayloadFactory := preload("res://scripts/stages/stage4/stage4_ponk_skill_payload_factory.gd")

const MAGNETIC_FIELD_SHEET_PATH := Stage4PonkMagneticAssets.MAGNETIC_FIELD_SHEET_PATH
const MAGNETIC_FIELD_COLS := Stage4PonkMagneticAssets.MAGNETIC_FIELD_COLS
const MAGNETIC_FIELD_ROWS := Stage4PonkMagneticAssets.MAGNETIC_FIELD_ROWS
const MAGNETIC_FIELD_FRAME_COUNT := Stage4PonkMagneticAssets.MAGNETIC_FIELD_FRAME_COUNT
const MAGNETIC_FIELD_FRAME_INTERVAL := Stage4PonkMagneticAssets.MAGNETIC_FIELD_FRAME_INTERVAL

const STAGE_ID := 4
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const GAUGE_MAX := 500.0
const MAGNETIC_COOLDOWN_SEC := 25.0
const MEDITATION_COOLDOWN_SEC := 18.0
const MEDITATION_CHANCE := 1.0
const MAGNETIC_DURATION_FRAMES := 200.0
const MAGNETIC_ENRAGED_DURATION_FRAMES := 300.0
const MAGNETIC_RADIUS := 160.0
const MAGNETIC_ENRAGED_RADIUS := 200.0
const MAGNETIC_PROJECTILE_SPEED := 12.0
const MAGNETIC_PROJECTILE_HOMING_X_SPEED := 3.2
const MAGNETIC_PROJECTILE_ENRAGED_HOMING_X_SPEED := 6.0
const MAGNETIC_PROJECTILE_SLOW_FRAMES := 10.0
const MAGNETIC_PROJECTILE_SLOW_MULTIPLIER := 0.5
const MAGNETIC_PROJECTILE_CONTACT_Y_SPEED_MULTIPLIER := 0.5
const MAGNETIC_PROJECTILE_FADE_SECONDS := 0.15
const MEDITATION_DURATION_FRAMES := 108.0
const MEDITATION_ORBIT_RADIUS := 80.0
const MEDITATION_TRAIL_MAX := 28
const MEDITATION_PARTICLE_MAX := 48
const MEDITATION_RELEASE_FX_FRAMES := 26.0
const MEDITATION_RELEASE_MAX_BALL_SPEED := 35.0
const MEDITATION_RELEASE_SPEED_BONUS_MIN := 1.10
const MEDITATION_RELEASE_SPEED_BONUS_MAX := 1.30
const BALL_BASE_SPEED_FALLBACK := 7.65
const MAGNETIC_SKILL_ID := "magnetic_field"
const MEDITATION_SKILL_ID := "meditation"

var rng := RandomNumberGenerator.new()
var magnetic_sheet: Texture2D = null
var textures_loaded := false
var frame_clock := 0.0

var boss_special_gauge := 0.0
var boss_special_ready := false
var magnetic_cooldown_seconds := MAGNETIC_COOLDOWN_SEC
var magnetic_active := false
var magnetic_timer_frames := 0.0
var magnetic_radius := MAGNETIC_RADIUS
var magnetic_enraged := false
var magnetic_center := Vector2(380.0, 78.0)
var magnet_curve_angle_degrees := 0.0
var magnetic_release_pending := false
var magnetic_release_min_speed := BALL_BASE_SPEED_FALLBACK

var magnetic_projectile_active := false
var magnetic_projectile_pos := Vector2.ZERO
var magnetic_projectile_radius := MAGNETIC_RADIUS
var magnetic_projectile_elapsed_seconds := 0.0
var magnetic_projectile_velocity := Vector2(0.0, MAGNETIC_PROJECTILE_SPEED)
var magnetic_projectile_y_speed_multiplier := 1.0
var magnetic_projectile_fade_timer_seconds := 0.0
var magnetic_projectile_fade_pos := Vector2.ZERO
var magnetic_projectile_fade_radius := MAGNETIC_RADIUS
var magnetic_projectile_fade_velocity := Vector2(0.0, MAGNETIC_PROJECTILE_SPEED)
var magnetic_fx_host: Node = null
var magnetic_fx_host_add_pending := false
var magnetic_fx_host_runtime_prewarmed := false

var meditation_active := false
var meditation_timer_frames := 0.0
var meditation_angle_degrees := 0.0
var meditation_ball_pos := Vector2(380.0, 150.0)
var meditation_trails: Array = []
var meditation_particles: Array = []
var meditation_circles: Array = []
var meditation_release_pending := false
var meditation_release_velocity := Vector2.ZERO
var meditation_cooldown_seconds := MEDITATION_COOLDOWN_SEC
var meditation_release_fx_timer_frames := 0.0
var meditation_release_fx_origin := Vector2.ZERO
var meditation_release_fx_pos := Vector2.ZERO
var meditation_release_fx_velocity := Vector2.ZERO
var meditation_release_fx_trails: Array = []
var meditation_release_fx_id := 0
var meditation_fx_host: Node = null
var meditation_fx_host_add_pending := false
var meditation_fx_host_runtime_prewarmed := false
var fx_hosts_prewarmed := false

var _test_meditation_chance := -1.0
var _prewarm_assets_done := false
var _prewarm_step_index := 0
var _prewarm_runtime_host_step_index := 0


func _init() -> void:
	rng.randomize()


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _prewarm_assets_done:
		return true
	match _prewarm_step_index:
		0:
			_ensure_textures()
		1:
			if not Stage4PonkMagneticFxHost.prewarm_assets_step():
				return false
		2:
			if not Stage4PonkMeditationFxHost.prewarm_assets_step():
				return false
		_:
			_prewarm_assets_done = true
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	if _prewarm_step_index > 2:
		_prewarm_assets_done = true
		_prewarm_step_index = 0
		return true
	return false


func prewarm_runtime_hosts(canvas: CanvasItem) -> void:
	while not prewarm_runtime_hosts_step(canvas):
		pass


func prewarm_runtime_hosts_step(canvas: CanvasItem) -> bool:
	if fx_hosts_prewarmed:
		return true
	if not (canvas is Node):
		fx_hosts_prewarmed = true
		_prewarm_runtime_host_step_index = 0
		return true
	match _prewarm_runtime_host_step_index:
		0:
			_get_or_create_magnetic_fx_host(canvas)
		1:
			_get_or_create_meditation_fx_host(canvas)
		_:
			fx_hosts_prewarmed = true
			_prewarm_runtime_host_step_index = 0
			return true
	_prewarm_runtime_host_step_index += 1
	if _prewarm_runtime_host_step_index > 1:
		fx_hosts_prewarmed = true
		_prewarm_runtime_host_step_index = 0
		return true
	return false


func reset() -> void:
	boss_special_gauge = 0.0
	boss_special_ready = false
	magnetic_cooldown_seconds = MAGNETIC_COOLDOWN_SEC
	magnetic_active = false
	magnetic_timer_frames = 0.0
	magnetic_radius = MAGNETIC_RADIUS
	magnetic_enraged = false
	magnetic_center = Vector2(380.0, 78.0)
	magnet_curve_angle_degrees = 0.0
	magnetic_release_pending = false
	magnetic_release_min_speed = BALL_BASE_SPEED_FALLBACK
	magnetic_projectile_active = false
	magnetic_projectile_pos = Vector2.ZERO
	magnetic_projectile_radius = MAGNETIC_RADIUS
	magnetic_projectile_elapsed_seconds = 0.0
	magnetic_projectile_velocity = Vector2(0.0, MAGNETIC_PROJECTILE_SPEED)
	magnetic_projectile_y_speed_multiplier = 1.0
	magnetic_projectile_fade_timer_seconds = 0.0
	magnetic_projectile_fade_pos = Vector2.ZERO
	magnetic_projectile_fade_radius = MAGNETIC_RADIUS
	magnetic_projectile_fade_velocity = Vector2(0.0, MAGNETIC_PROJECTILE_SPEED)
	_stop_magnetic_fx_host()
	meditation_active = false
	meditation_timer_frames = 0.0
	meditation_angle_degrees = 0.0
	meditation_ball_pos = Vector2(380.0, 150.0)
	meditation_trails.clear()
	meditation_particles.clear()
	meditation_circles.clear()
	meditation_release_pending = false
	meditation_release_velocity = Vector2.ZERO
	meditation_cooldown_seconds = MEDITATION_COOLDOWN_SEC
	_reset_meditation_release_fx(true)
	_stop_meditation_fx_host()
	frame_clock = 0.0


func reset_round(deps: Dictionary = {}) -> void:
	if magnetic_active or magnetic_projectile_active or magnetic_projectile_fade_timer_seconds > 0.0:
		_stop_magnetic_audio(deps)
	magnetic_cooldown_seconds = MAGNETIC_COOLDOWN_SEC
	magnetic_active = false
	magnetic_timer_frames = 0.0
	magnet_curve_angle_degrees = 0.0
	magnetic_release_pending = false
	magnetic_projectile_active = false
	magnetic_projectile_elapsed_seconds = 0.0
	magnetic_projectile_velocity = Vector2(0.0, MAGNETIC_PROJECTILE_SPEED)
	magnetic_projectile_y_speed_multiplier = 1.0
	magnetic_projectile_fade_timer_seconds = 0.0
	_stop_magnetic_fx_host()
	meditation_active = false
	meditation_timer_frames = 0.0
	meditation_trails.clear()
	meditation_particles.clear()
	meditation_circles.clear()
	meditation_release_pending = false
	meditation_release_velocity = Vector2.ZERO
	meditation_cooldown_seconds = MEDITATION_COOLDOWN_SEC
	_reset_meditation_release_fx(true)
	_stop_meditation_fx_host()


func update(delta: float, context: Dictionary = {}, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID or _is_inwang_context(context):
		if magnetic_active:
			_stop_magnetic_audio(deps)
		magnetic_active = false
		magnetic_projectile_active = false
		magnetic_projectile_y_speed_multiplier = 1.0
		magnetic_projectile_fade_timer_seconds = 0.0
		_stop_magnetic_fx_host()
		meditation_active = false
		meditation_trails.clear()
		meditation_particles.clear()
		meditation_circles.clear()
		_reset_meditation_release_fx()
		return get_debug_snapshot()

	var clamped_delta: float = clampf(delta, 0.0, 0.1)
	var fps_scale: float = clamped_delta * 60.0
	frame_clock += clamped_delta
	magnetic_center = _get_boss_center(context)

	if not _is_timing_frozen(context):
		if not _is_boss_skill_cooldown_paused(context):
			_update_skill_cooldowns(clamped_delta)
			if _can_auto_activate_magnetic(context):
				_activate_magnetic(context, deps)
		_update_magnetic(fps_scale, context, deps)
		_update_magnetic_projectile(fps_scale, context)
		_update_meditation(fps_scale, context, deps)

	_sync_magnetic_audio(deps)
	return get_debug_snapshot()


func register_boss_hit(_ball_vel: Vector2, context: Dictionary = {}, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID or _is_inwang_context(context):
		return get_debug_snapshot()
	if magnetic_active or meditation_active:
		return get_debug_snapshot()

	if meditation_cooldown_seconds <= 0.0:
		_activate_meditation(context, deps)
		return get_debug_snapshot()
	return get_debug_snapshot()


func apply_gauge_delta(delta: float) -> Dictionary:
	boss_special_gauge = clampf(boss_special_gauge + delta, 0.0, GAUGE_MAX)
	boss_special_ready = false
	return get_debug_snapshot()


func apply_ball_motion(scene: Dictionary, context: Dictionary = {}, deps: Dictionary = {}, fps_scale: float = 1.0) -> bool:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		return false
	if meditation_active:
		var controlled_pos: Vector2 = _get_meditation_ball_pos(context)
		meditation_ball_pos = controlled_pos
		scene["ball_pos"] = controlled_pos
		scene["ball_vel"] = Vector2.ZERO
		scene["skip_ball_motion_step"] = false
		scene["stage4_meditation_ball_control"] = true
		return true

	var handled := false
	if meditation_release_pending:
		scene["ball_vel"] = meditation_release_velocity
		scene["stage4_meditation_release_speed_cap"] = MEDITATION_RELEASE_MAX_BALL_SPEED
		scene["ball_spin_strength"] = 0.30
		scene["ball_spin_direction"] = 1 if meditation_release_velocity.x >= 0.0 else -1
		scene["skip_ball_motion_step"] = false
		scene["stage4_meditation_ball_control"] = false
		scene["stage4_meditation_released_ball"] = true
		meditation_release_pending = false
		handled = true

	if magnetic_release_pending:
		var release_vel: Vector2 = _get_vector2(scene, "ball_vel", _get_vector2(context, "ball_vel", Vector2.ZERO))
		if release_vel.length() > 0.001:
			var min_speed: float = maxf(magnetic_release_min_speed, _get_base_ball_speed(context, deps))
			if release_vel.length() < min_speed:
				release_vel = release_vel.normalized() * min_speed
				scene["ball_vel"] = release_vel
		scene["stage4_magnetic_released_ball"] = true
		magnetic_release_pending = false
		handled = true

	if not magnetic_active or _is_timing_frozen(context):
		return handled

	var ball_pos: Vector2 = _get_vector2(scene, "ball_pos", _get_vector2(context, "ball_pos", Vector2.ZERO))
	var ball_vel: Vector2 = _get_vector2(scene, "ball_vel", _get_vector2(context, "ball_vel", Vector2.ZERO))
	var boss_center: Vector2 = _get_boss_center(context)
	magnetic_center = boss_center
	if ball_pos.distance_to(boss_center) > magnetic_radius:
		return handled

	var player_center: Vector2 = _get_player_center(context)
	var to_player: Vector2 = player_center - ball_pos
	if to_player.length() <= 0.001:
		to_player = Vector2(0.0, 1.0)
	var step: float = maxf(0.0, fps_scale)
	magnet_curve_angle_degrees += 4.1 * step
	var curve_vector: Vector2 = to_player.normalized().rotated(deg_to_rad(magnet_curve_angle_degrees)) * (1.8 * step)
	var next_vel: Vector2 = (ball_vel + curve_vector) * pow(1.04, step)
	var speed_cap: float = _get_base_ball_speed(context, deps) * 2.2
	if next_vel.length() > speed_cap:
		next_vel = next_vel.normalized() * speed_cap
	scene["ball_vel"] = next_vel
	scene["stage4_magnetic_ball_curved"] = true
	scene["stage4_magnetic_curve_angle"] = magnet_curve_angle_degrees
	return true


func resolve_ball_collision(scene: Dictionary, context: Dictionary = {}, deps: Dictionary = {}) -> bool:
	if not magnetic_projectile_active or int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		return false
	var player_rect: Rect2 = _get_player_rect(context)
	if player_rect.size.x <= 0.0 or player_rect.size.y <= 0.0:
		return false
	if not _circle_rect_overlap(magnetic_projectile_pos, magnetic_projectile_radius * 0.68, player_rect):
		return false

	if _is_player_status_immune(deps):
		scene["stage4_magnetic_projectile_blocked"] = true
		_finish_magnetic_projectile_visual()
		_stop_magnetic_audio(deps)
		return true

	var status_state: Object = deps.get("status_effect_state", null)
	if status_state != null and status_state.has_method("apply_status"):
		status_state.apply_status(
			"player",
			"slow",
			MAGNETIC_PROJECTILE_SLOW_FRAMES,
			{
				"multiplier": MAGNETIC_PROJECTILE_SLOW_MULTIPLIER,
				"cleansable": true,
				"visual": "stage4_magnetic_projectile",
			},
			"stage4_magnetic_projectile"
		)
	magnetic_projectile_y_speed_multiplier = minf(
		magnetic_projectile_y_speed_multiplier,
		MAGNETIC_PROJECTILE_CONTACT_Y_SPEED_MULTIPLIER
	)
	scene["stage4_magnetic_projectile_player_hit"] = true
	scene["stage4_magnetic_projectile_slow_multiplier"] = MAGNETIC_PROJECTILE_SLOW_MULTIPLIER
	scene["stage4_magnetic_projectile_y_speed_multiplier"] = magnetic_projectile_y_speed_multiplier
	scene["stage4_magnetic_projectile_hit_count"] = int(scene.get("stage4_magnetic_projectile_hit_count", 0)) + 1
	return true


func force_activate_magnetic(context: Dictionary = {}, deps: Dictionary = {}) -> bool:
	boss_special_ready = false
	boss_special_gauge = 0.0
	_activate_magnetic(context, deps)
	return magnetic_active


func force_activate_meditation(context: Dictionary = {}, deps: Dictionary = {}) -> bool:
	_activate_meditation(context, deps)
	return meditation_active


func force_spawn_magnetic_projectile(pos: Vector2, radius: float = MAGNETIC_RADIUS) -> bool:
	magnetic_projectile_active = true
	magnetic_projectile_pos = pos
	magnetic_projectile_radius = maxf(12.0, radius)
	magnetic_projectile_elapsed_seconds = 0.0
	magnetic_projectile_velocity = Vector2(0.0, MAGNETIC_PROJECTILE_SPEED)
	magnetic_projectile_y_speed_multiplier = 1.0
	magnetic_projectile_fade_timer_seconds = 0.0
	return true


func set_meditation_chance_for_tests(value: float) -> void:
	_test_meditation_chance = value


func get_hud_context() -> Dictionary:
	var result := {
		"stage4_ponk_gauge_visible": true,
		"stage4_ponk_gauge_value": boss_special_gauge,
		"stage4_ponk_gauge_max": GAUGE_MAX,
		"stage4_ponk_gauge_ready": boss_special_ready,
		"stage4_ponk_gauge_active": magnetic_active or meditation_active,
	}
	result.merge(get_skill_card_hud_context(), true)
	return result


func get_skill_card_hud_context(_owner: Object = null, _context: Dictionary = {}) -> Dictionary:
	return {
		"stage4_ponk_boss_skill_hud_active": true,
		"stage4_ponk_boss_skill_hud_skills": [
			_build_magnetic_skill_card(),
			_build_meditation_skill_card(),
		],
	}


func get_actor_draw_context(copy_arrays: bool = false) -> Dictionary:
	return {
		"stage4_ponk_gauge_value": boss_special_gauge,
		"stage4_ponk_gauge_max": GAUGE_MAX,
		"stage4_ponk_gauge_ready": boss_special_ready,
		"stage4_ponk_gauge_active": magnetic_active or meditation_active,
		"stage4_magnetic_active": magnetic_active,
		"stage4_magnetic_timer": magnetic_timer_frames,
		"stage4_magnetic_radius": magnetic_radius,
		"stage4_magnetic_center": magnetic_center,
		"stage4_magnetic_enraged": magnetic_enraged,
		"stage4_magnetic_frame": _get_current_frame_index(),
		"stage4_effect_clock": frame_clock,
		"stage4_magnetic_curve_angle": magnet_curve_angle_degrees,
		"stage4_magnetic_cooldown_remaining": magnetic_cooldown_seconds,
		"stage4_magnetic_cooldown_total": MAGNETIC_COOLDOWN_SEC,
		"stage4_magnetic_projectile_active": magnetic_projectile_active,
		"stage4_magnetic_projectile_pos": magnetic_projectile_pos,
		"stage4_magnetic_projectile_radius": magnetic_projectile_radius,
		"stage4_magnetic_projectile_elapsed": magnetic_projectile_elapsed_seconds,
		"stage4_magnetic_projectile_velocity": magnetic_projectile_velocity,
		"stage4_magnetic_projectile_y_speed_multiplier": magnetic_projectile_y_speed_multiplier,
		"stage4_magnetic_projectile_fade_active": magnetic_projectile_fade_timer_seconds > 0.0,
		"stage4_magnetic_projectile_fade_timer": magnetic_projectile_fade_timer_seconds,
		"stage4_magnetic_projectile_fade_total": MAGNETIC_PROJECTILE_FADE_SECONDS,
		"stage4_magnetic_projectile_fade_pos": magnetic_projectile_fade_pos,
		"stage4_magnetic_projectile_fade_radius": magnetic_projectile_fade_radius,
		"stage4_magnetic_projectile_fade_velocity": magnetic_projectile_fade_velocity,
		"stage4_meditation_active": meditation_active,
		"stage4_meditation_timer": meditation_timer_frames,
		"stage4_meditation_cooldown_remaining": meditation_cooldown_seconds,
		"stage4_meditation_cooldown_total": MEDITATION_COOLDOWN_SEC,
		"stage4_meditation_angle": meditation_angle_degrees,
		"stage4_meditation_ball_pos": meditation_ball_pos,
		"stage4_meditation_trails": meditation_trails.duplicate(true) if copy_arrays else meditation_trails,
		"stage4_meditation_particles": meditation_particles.duplicate(true) if copy_arrays else meditation_particles,
		"stage4_meditation_circles": meditation_circles.duplicate(true) if copy_arrays else meditation_circles,
		"stage4_meditation_release_fx_active": meditation_release_fx_timer_frames > 0.0,
		"stage4_meditation_release_fx_timer": meditation_release_fx_timer_frames,
		"stage4_meditation_release_fx_total": MEDITATION_RELEASE_FX_FRAMES,
		"stage4_meditation_release_fx_origin": meditation_release_fx_origin,
		"stage4_meditation_release_fx_pos": meditation_release_fx_pos,
		"stage4_meditation_release_fx_velocity": meditation_release_fx_velocity,
		"stage4_meditation_release_fx_id": meditation_release_fx_id,
		"stage4_meditation_release_fx_trails": meditation_release_fx_trails.duplicate(true) if copy_arrays else meditation_release_fx_trails,
	}


func get_debug_snapshot() -> Dictionary:
	var snapshot := get_hud_context()
	snapshot.merge({
		"magnetic_active": magnetic_active,
		"magnetic_timer_frames": magnetic_timer_frames,
		"magnetic_radius": magnetic_radius,
		"magnetic_enraged": magnetic_enraged,
		"magnetic_cooldown_seconds": magnetic_cooldown_seconds,
		"magnetic_projectile_active": magnetic_projectile_active,
		"magnetic_projectile_pos": magnetic_projectile_pos,
		"magnetic_projectile_elapsed_seconds": magnetic_projectile_elapsed_seconds,
		"magnetic_projectile_y_speed_multiplier": magnetic_projectile_y_speed_multiplier,
		"magnetic_projectile_fade_timer_seconds": magnetic_projectile_fade_timer_seconds,
		"meditation_active": meditation_active,
		"meditation_timer_frames": meditation_timer_frames,
		"meditation_cooldown_seconds": meditation_cooldown_seconds,
		"meditation_release_pending": meditation_release_pending,
		"meditation_release_fx_timer_frames": meditation_release_fx_timer_frames,
	}, true)
	return snapshot


func get_asset_status() -> Dictionary:
	_ensure_textures()
	var status := {
		"magnetic_field_sheet": magnetic_sheet != null,
		"magnetic_field_frame_count": MAGNETIC_FIELD_FRAME_COUNT if magnetic_sheet != null else 0,
	}
	status.merge(Stage4PonkMagneticFxHost.build_pipeline_status(), true)
	status.merge(Stage4PonkMeditationFxHost.build_pipeline_status(), true)
	status["magnetic_fx_host_attached"] = _is_valid_magnetic_fx_host()
	status["meditation_fx_host_attached"] = _is_valid_meditation_fx_host()
	return status


func _build_magnetic_skill_card() -> Dictionary:
	var cooldown_ready: bool = magnetic_cooldown_seconds <= 0.0
	var ready: bool = cooldown_ready and not magnetic_active and not meditation_active
	var status := "casting" if magnetic_active else ("ready" if ready else "charging")
	var progress: float = 1.0 if magnetic_active or cooldown_ready else _cooldown_progress(magnetic_cooldown_seconds, MAGNETIC_COOLDOWN_SEC)
	return {
		"id": MAGNETIC_SKILL_ID,
		"name": "굴절 자기장",
		"short_label": "자기장",
		"trigger": "25초마다 자동 발동",
		"trigger_type": "auto_cooldown",
		"status": status,
		"ready": ready,
		"active": magnetic_active,
		"progress": progress,
		"remaining": maxf(0.0, magnetic_cooldown_seconds),
		"total": MAGNETIC_COOLDOWN_SEC,
		"cooldown_remaining": maxf(0.0, magnetic_cooldown_seconds),
		"cooldown_total": MAGNETIC_COOLDOWN_SEC,
		"cooldown_seconds": MAGNETIC_COOLDOWN_SEC,
		"duration_remaining": magnetic_timer_frames,
		"duration_total": MAGNETIC_ENRAGED_DURATION_FRAMES if magnetic_enraged else MAGNETIC_DURATION_FRAMES,
		"color": Color(0.50, 0.95, 1.0, 1.0),
		"description": "공을 보스 주변에서 굴절시키고 종료 시 감속 구체를 발사합니다.",
	}


func _build_meditation_skill_card() -> Dictionary:
	var cooldown_ready: bool = meditation_cooldown_seconds <= 0.0
	var ready: bool = cooldown_ready and not magnetic_active and not meditation_active
	var status := "casting" if meditation_active else ("ready" if ready else "charging")
	var progress: float = 1.0 if meditation_active or cooldown_ready else _cooldown_progress(meditation_cooldown_seconds, MEDITATION_COOLDOWN_SEC)
	return {
		"id": MEDITATION_SKILL_ID,
		"name": "위빠사나 명상",
		"short_label": "명상",
		"trigger": "18초 쿨타임 후 보스 타격",
		"trigger_type": "hit_cooldown",
		"trigger_chance": _get_meditation_chance(),
		"status": status,
		"ready": ready,
		"active": meditation_active,
		"progress": progress,
		"remaining": maxf(0.0, meditation_cooldown_seconds),
		"total": MEDITATION_COOLDOWN_SEC,
		"cooldown_remaining": maxf(0.0, meditation_cooldown_seconds),
		"cooldown_total": MEDITATION_COOLDOWN_SEC,
		"cooldown_seconds": MEDITATION_COOLDOWN_SEC,
		"duration_remaining": meditation_timer_frames,
		"duration_total": MEDITATION_DURATION_FRAMES,
		"color": Color(1.0, 0.76, 0.26, 1.0),
		"description": "공을 숫자 8 궤도로 붙잡고 명상 종료 후 추가 가속으로 플레이어 쪽으로 쏩니다.",
	}


func draw(canvas: CanvasItem, context: Dictionary = {}, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	_sync_draw_clock(context)
	_ensure_textures()
	var magnetic_field_fx_active: bool = bool(context.get("stage4_magnetic_active", magnetic_active))
	var magnetic_projectile_fx_active: bool = (
		bool(context.get("stage4_magnetic_projectile_active", magnetic_projectile_active))
		or bool(context.get("stage4_magnetic_projectile_fade_active", magnetic_projectile_fade_timer_seconds > 0.0))
	)
	var magnetic_fx_active: bool = magnetic_field_fx_active or magnetic_projectile_fx_active
	var magnetic_fx_handled: bool = _sync_magnetic_fx_host(canvas, context, shake_offset, magnetic_fx_active)
	if magnetic_field_fx_active and not magnetic_fx_handled:
		_draw_magnetic_field(canvas, context, shake_offset)
	if magnetic_projectile_fx_active and not magnetic_fx_handled:
		_draw_magnetic_projectile(canvas, context, shake_offset)
	var meditation_fx_active: bool = (
		bool(context.get("stage4_meditation_active", meditation_active))
		or bool(context.get("stage4_meditation_release_fx_active", meditation_release_fx_timer_frames > 0.0))
	)
	var fx_host_handled: bool = _sync_meditation_fx_host(canvas, context, shake_offset, meditation_fx_active)
	if meditation_fx_active and not fx_host_handled:
		_draw_meditation(canvas, context, shake_offset)


func _update_skill_cooldowns(delta: float) -> void:
	var step: float = maxf(0.0, delta)
	magnetic_cooldown_seconds = maxf(0.0, magnetic_cooldown_seconds - step)
	meditation_cooldown_seconds = maxf(0.0, meditation_cooldown_seconds - step)


func _can_auto_activate_magnetic(context: Dictionary) -> bool:
	return (
		magnetic_cooldown_seconds <= 0.0
		and not magnetic_active
		and not meditation_active
		and not _is_serve_waiting(context)
	)


func _cooldown_progress(remaining: float, total: float) -> float:
	return clampf(1.0 - maxf(0.0, remaining) / maxf(0.001, total), 0.0, 1.0)


func _activate_magnetic(context: Dictionary, deps: Dictionary) -> void:
	magnetic_enraged = _is_enraged(context)
	magnetic_radius = MAGNETIC_ENRAGED_RADIUS if magnetic_enraged else MAGNETIC_RADIUS
	magnetic_timer_frames = MAGNETIC_ENRAGED_DURATION_FRAMES if magnetic_enraged else MAGNETIC_DURATION_FRAMES
	magnetic_center = _get_boss_center(context)
	magnet_curve_angle_degrees = 0.0
	magnetic_active = true
	magnetic_release_pending = false
	magnetic_release_min_speed = maxf(_get_base_ball_speed(context, deps), float(context.get("player_last_shot_speed", 0.0)))
	boss_special_ready = false
	boss_special_gauge = 0.0
	magnetic_cooldown_seconds = MAGNETIC_COOLDOWN_SEC
	_play_magnetic_audio(deps)


func _update_magnetic(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	if not magnetic_active:
		return
	magnetic_timer_frames = maxf(0.0, magnetic_timer_frames - maxf(0.0, fps_scale))
	if magnetic_timer_frames > 0.0:
		return
	magnetic_active = false
	magnetic_release_pending = true
	magnetic_projectile_active = true
	magnetic_projectile_pos = _get_boss_center(context)
	magnetic_projectile_radius = magnetic_radius
	magnetic_projectile_elapsed_seconds = 0.0
	magnetic_projectile_velocity = Vector2(0.0, MAGNETIC_PROJECTILE_SPEED)
	magnetic_projectile_y_speed_multiplier = 1.0
	magnetic_projectile_fade_timer_seconds = 0.0
	magnet_curve_angle_degrees = 0.0
	_stop_magnetic_audio(deps)


func _update_magnetic_projectile(fps_scale: float, context: Dictionary) -> void:
	if not magnetic_projectile_active:
		if magnetic_projectile_fade_timer_seconds > 0.0:
			magnetic_projectile_fade_timer_seconds = maxf(0.0, magnetic_projectile_fade_timer_seconds - maxf(0.0, fps_scale) / 60.0)
		return
	var step: float = maxf(0.0, fps_scale)
	magnetic_projectile_elapsed_seconds += step / 60.0
	var previous_pos: Vector2 = magnetic_projectile_pos
	var homing_speed: float = MAGNETIC_PROJECTILE_ENRAGED_HOMING_X_SPEED if magnetic_enraged else MAGNETIC_PROJECTILE_HOMING_X_SPEED
	if homing_speed > 0.0:
		var player_center: Vector2 = _get_player_center(context)
		var dx: float = player_center.x - magnetic_projectile_pos.x
		magnetic_projectile_pos.x += clampf(dx, -homing_speed * step, homing_speed * step)
	var y_speed: float = MAGNETIC_PROJECTILE_SPEED * maxf(0.0, magnetic_projectile_y_speed_multiplier)
	magnetic_projectile_pos.y += y_speed * step
	var next_velocity: Vector2 = magnetic_projectile_pos - previous_pos
	if next_velocity.length_squared() > 0.001:
		magnetic_projectile_velocity = next_velocity
	var height: float = maxf(FIELD_HEIGHT, float(context.get("height", FIELD_HEIGHT)))
	if magnetic_projectile_pos.y > height + magnetic_projectile_radius:
		_finish_magnetic_projectile_visual()


func _finish_magnetic_projectile_visual() -> void:
	magnetic_projectile_fade_pos = magnetic_projectile_pos
	magnetic_projectile_fade_radius = magnetic_projectile_radius
	magnetic_projectile_fade_velocity = magnetic_projectile_velocity
	magnetic_projectile_fade_timer_seconds = MAGNETIC_PROJECTILE_FADE_SECONDS
	magnetic_projectile_active = false


func _activate_meditation(context: Dictionary, deps: Dictionary) -> void:
	meditation_active = true
	meditation_timer_frames = MEDITATION_DURATION_FRAMES
	meditation_angle_degrees = 0.0
	meditation_ball_pos = _get_meditation_ball_pos(context)
	meditation_trails.clear()
	meditation_particles.clear()
	meditation_circles.clear()
	meditation_release_pending = false
	meditation_release_velocity = Vector2.ZERO
	meditation_cooldown_seconds = MEDITATION_COOLDOWN_SEC
	_reset_meditation_release_fx()
	_spawn_meditation_circles()
	_play_meditation_audio(deps)


func _update_meditation(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	if not meditation_active:
		_update_meditation_particles(fps_scale)
		_update_meditation_release_fx(fps_scale)
		return
	var step: float = maxf(0.0, fps_scale)
	meditation_timer_frames = maxf(0.0, meditation_timer_frames - step)
	meditation_angle_degrees += (720.0 / MEDITATION_DURATION_FRAMES) * step
	meditation_ball_pos = _get_meditation_ball_pos(context)
	_append_meditation_trail(meditation_ball_pos)
	_update_meditation_particles(step)
	_spawn_meditation_particle(meditation_ball_pos)
	if meditation_timer_frames <= 0.0:
		_finish_meditation(context, deps)


func _finish_meditation(context: Dictionary, deps: Dictionary) -> void:
	var release_velocity: Vector2 = _build_meditation_release_velocity(context, deps)
	meditation_release_fx_timer_frames = MEDITATION_RELEASE_FX_FRAMES
	meditation_release_fx_origin = meditation_ball_pos
	meditation_release_fx_pos = meditation_ball_pos
	meditation_release_fx_velocity = release_velocity
	meditation_release_fx_trails = meditation_trails.duplicate(true)
	meditation_release_fx_id += 1
	meditation_active = false
	meditation_timer_frames = 0.0
	meditation_trails.clear()
	meditation_particles.clear()
	meditation_circles.clear()
	meditation_release_pending = true
	meditation_release_velocity = release_velocity
	_play_meditation_after_audio(deps)


func _get_meditation_ball_pos(context: Dictionary) -> Vector2:
	var center: Vector2 = _get_boss_center(context)
	var angle: float = deg_to_rad(meditation_angle_degrees)
	var scale := MEDITATION_ORBIT_RADIUS * 1.5
	var denom: float = 1.0 + pow(sin(angle), 2.0)
	return center + Vector2(
		scale * cos(angle) / denom,
		scale * sin(angle) * cos(angle) / denom
	)


func _build_meditation_release_velocity(context: Dictionary, deps: Dictionary) -> Vector2:
	var release_bonus: float = rng.randf_range(MEDITATION_RELEASE_SPEED_BONUS_MIN, MEDITATION_RELEASE_SPEED_BONUS_MAX)
	var speed: float = _get_base_ball_speed(context, deps) * rng.randf_range(1.3, 1.6) * release_bonus
	var angle: float = deg_to_rad(rng.randf_range(-45.0, 45.0))
	return Vector2(sin(angle), 1.0).normalized() * speed


func _append_meditation_trail(pos: Vector2) -> void:
	meditation_trails.append(Stage4PonkSkillPayloadFactory.build_meditation_trail(pos))
	while meditation_trails.size() > MEDITATION_TRAIL_MAX:
		meditation_trails.pop_front()


func _update_meditation_particles(fps_scale: float) -> void:
	var next_trails: Array = []
	for trail_value in meditation_trails:
		if not (trail_value is Dictionary):
			continue
		var trail: Dictionary = trail_value
		trail["life"] = float(trail.get("life", 0.0)) - fps_scale
		if float(trail.get("life", 0.0)) > 0.0:
			next_trails.append(trail)
	meditation_trails = next_trails

	var next_particles: Array = []
	for particle_value in meditation_particles:
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		particle["life"] = float(particle.get("life", 0.0)) - fps_scale
		particle["pos"] = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO) * fps_scale
		if float(particle.get("life", 0.0)) > 0.0:
			next_particles.append(particle)
	meditation_particles = next_particles

	var next_circles: Array = []
	for circle_value in meditation_circles:
		if not (circle_value is Dictionary):
			continue
		var circle: Dictionary = circle_value
		circle["life"] = float(circle.get("life", 0.0)) - fps_scale
		circle["radius"] = float(circle.get("radius", 0.0)) + float(circle.get("grow", 1.2)) * fps_scale
		if float(circle.get("life", 0.0)) > 0.0:
			next_circles.append(circle)
		meditation_circles = next_circles


func _update_meditation_release_fx(fps_scale: float) -> void:
	if meditation_release_fx_timer_frames <= 0.0:
		return
	var step: float = maxf(0.0, fps_scale)
	meditation_release_fx_timer_frames = maxf(0.0, meditation_release_fx_timer_frames - step)
	meditation_release_fx_pos += meditation_release_fx_velocity * step
	var next_trails: Array = []
	for trail_value in meditation_release_fx_trails:
		if not (trail_value is Dictionary):
			continue
		var trail: Dictionary = trail_value
		trail["life"] = float(trail.get("life", 0.0)) - step
		if float(trail.get("life", 0.0)) > 0.0:
			next_trails.append(trail)
	meditation_release_fx_trails = next_trails
	if meditation_release_fx_timer_frames <= 0.0:
		meditation_release_fx_trails.clear()
		meditation_release_fx_velocity = Vector2.ZERO


func _spawn_meditation_particle(pos: Vector2) -> void:
	if meditation_particles.size() >= MEDITATION_PARTICLE_MAX or rng.randf() > 0.42:
		return
	meditation_particles.append(Stage4PonkSkillPayloadFactory.build_meditation_particle(pos, rng))


func _spawn_meditation_circles() -> void:
	var center := magnetic_center
	for idx in range(3):
		meditation_circles.append(Stage4PonkSkillPayloadFactory.build_meditation_circle(center, idx))


func _ensure_textures() -> void:
	if textures_loaded:
		return
	textures_loaded = true
	magnetic_sheet = ProjectResourceLoader.load_texture(MAGNETIC_FIELD_SHEET_PATH)


func _sync_draw_clock(context: Dictionary) -> void:
	if context.has("stage4_effect_clock"):
		frame_clock = maxf(0.0, float(context.get("stage4_effect_clock", frame_clock)))
		return
	if (
		bool(context.get("stage4_magnetic_active", magnetic_active))
		or bool(context.get("stage4_magnetic_projectile_active", magnetic_projectile_active))
		or bool(context.get("stage4_magnetic_projectile_fade_active", magnetic_projectile_fade_timer_seconds > 0.0))
		or bool(context.get("stage4_meditation_active", meditation_active))
		or bool(context.get("stage4_meditation_release_fx_active", meditation_release_fx_timer_frames > 0.0))
	):
		frame_clock = float(Time.get_ticks_msec()) * 0.001


func _draw_magnetic_field(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var center: Vector2 = _as_vector2(context.get("stage4_magnetic_center", magnetic_center), magnetic_center) + shake_offset
	var radius: float = maxf(16.0, float(context.get("stage4_magnetic_radius", magnetic_radius)))
	var frame: int = int(context.get("stage4_magnetic_frame", _get_current_frame_index())) % MAGNETIC_FIELD_FRAME_COUNT
	canvas.draw_circle(center, radius * 0.98, Color(0.16, 0.76, 1.0, 0.12))
	canvas.draw_circle(center, radius * 0.42, Color(0.62, 1.0, 1.0, 0.18))
	_draw_magnetic_sheet_frame(canvas, center, radius * 2.72, frame, Color(0.82, 1.0, 1.0, 0.86))
	var phase: float = frame_clock * 5.7
	for idx in range(4):
		var ring_radius: float = radius * (0.54 + float(idx) * 0.16)
		var alpha: float = 0.40 - float(idx) * 0.050
		canvas.draw_arc(center, ring_radius, phase + float(idx) * 0.7, phase + float(idx) * 0.7 + PI * 1.45, 56, Color(0.64, 1.0, 1.0, alpha), 3.0, true)
	canvas.draw_circle(center, radius * 0.18, Color(0.80, 1.0, 1.0, 0.34))


func _draw_magnetic_projectile(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var fade_active: bool = bool(context.get("stage4_magnetic_projectile_fade_active", magnetic_projectile_fade_timer_seconds > 0.0))
	var center: Vector2 = _as_vector2(context.get("stage4_magnetic_projectile_pos", magnetic_projectile_pos), magnetic_projectile_pos)
	var radius: float = maxf(12.0, float(context.get("stage4_magnetic_projectile_radius", magnetic_projectile_radius)))
	var alpha_scale := 1.0
	if fade_active and not bool(context.get("stage4_magnetic_projectile_active", magnetic_projectile_active)):
		center = _as_vector2(context.get("stage4_magnetic_projectile_fade_pos", magnetic_projectile_fade_pos), magnetic_projectile_fade_pos)
		radius = maxf(12.0, float(context.get("stage4_magnetic_projectile_fade_radius", magnetic_projectile_fade_radius)))
		alpha_scale = clampf(float(context.get("stage4_magnetic_projectile_fade_timer", magnetic_projectile_fade_timer_seconds)) / MAGNETIC_PROJECTILE_FADE_SECONDS, 0.0, 1.0)
	center += shake_offset
	var frame: int = _get_current_frame_index()
	canvas.draw_circle(center, radius * 0.95, Color(0.24, 0.92, 1.0, 0.16 * alpha_scale))
	_draw_magnetic_sheet_frame(canvas, center, radius * 2.20, frame, Color(0.76, 1.0, 1.0, 0.74 * alpha_scale))
	canvas.draw_circle(center, radius * 0.60, Color(0.92, 0.36, 1.0, 0.20 * alpha_scale))
	canvas.draw_arc(center, radius * 0.72, -frame_clock * 7.0, -frame_clock * 7.0 + PI * 1.7, 48, Color(0.64, 1.0, 1.0, 0.70 * alpha_scale), 3.0, true)


func _draw_magnetic_sheet_frame(canvas: CanvasItem, center: Vector2, draw_size: float, frame: int, modulate: Color) -> void:
	if magnetic_sheet == null:
		canvas.draw_circle(center, draw_size * 0.35, Color(modulate.r, modulate.g, modulate.b, modulate.a * 0.28))
		return
	var sheet_size: Vector2 = magnetic_sheet.get_size()
	var cell_size := Vector2(sheet_size.x / float(MAGNETIC_FIELD_COLS), sheet_size.y / float(MAGNETIC_FIELD_ROWS))
	var col: int = frame % MAGNETIC_FIELD_COLS
	var row: int = int(floor(float(frame) / float(MAGNETIC_FIELD_COLS))) % MAGNETIC_FIELD_ROWS
	canvas.draw_texture_rect_region(
		magnetic_sheet,
		Rect2(center - Vector2(draw_size, draw_size) * 0.5, Vector2(draw_size, draw_size)),
		Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size),
		modulate,
		false,
		true
	)


func _sync_magnetic_fx_host(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, active: bool) -> bool:
	if not active and not _is_valid_magnetic_fx_host():
		return false
	var host: Node = _get_or_create_magnetic_fx_host(canvas)
	if host == null or not host.has_method("sync_state"):
		return false
	var fx_context: Dictionary = _build_magnetic_fx_context(context, shake_offset)
	if host.has_method("can_handle_state") and not bool(host.can_handle_state(fx_context)):
		host.sync_state(fx_context, false)
		return false
	host.sync_state(fx_context, active)
	if not active:
		return false
	if host.has_method("has_runtime_assets") and not bool(host.has_runtime_assets()):
		return false
	return host.get_parent() != null


func _prewarm_fx_hosts(canvas: CanvasItem) -> void:
	if fx_hosts_prewarmed:
		return
	while not prewarm_runtime_hosts_step(canvas):
		pass


func _prewarm_magnetic_fx_host_runtime_nodes() -> void:
	if magnetic_fx_host_runtime_prewarmed:
		return
	if magnetic_fx_host != null and is_instance_valid(magnetic_fx_host) and magnetic_fx_host.has_method("prewarm_runtime_nodes"):
		magnetic_fx_host.call("prewarm_runtime_nodes")
		magnetic_fx_host_runtime_prewarmed = true


func _prewarm_meditation_fx_host_runtime_nodes() -> void:
	if meditation_fx_host_runtime_prewarmed:
		return
	if meditation_fx_host != null and is_instance_valid(meditation_fx_host) and meditation_fx_host.has_method("prewarm_runtime_nodes"):
		meditation_fx_host.call("prewarm_runtime_nodes")
		meditation_fx_host_runtime_prewarmed = true


func _get_or_create_magnetic_fx_host(canvas: CanvasItem) -> Node:
	if _is_valid_magnetic_fx_host():
		_prewarm_magnetic_fx_host_runtime_nodes()
		return magnetic_fx_host
	if not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing: Node = parent.get_node_or_null("PonkMagneticFxHost")
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		magnetic_fx_host = existing
		magnetic_fx_host_add_pending = false
		magnetic_fx_host_runtime_prewarmed = false
		_prewarm_magnetic_fx_host_runtime_nodes()
		return magnetic_fx_host
	magnetic_fx_host = Stage4PonkMagneticFxHost.new()
	magnetic_fx_host.name = "PonkMagneticFxHost"
	magnetic_fx_host.visible = false
	magnetic_fx_host_runtime_prewarmed = false
	_prewarm_magnetic_fx_host_runtime_nodes()
	if not magnetic_fx_host_add_pending:
		magnetic_fx_host_add_pending = true
		parent.call_deferred("add_child", magnetic_fx_host)
	return magnetic_fx_host


func _build_magnetic_fx_context(context: Dictionary, shake_offset: Vector2) -> Dictionary:
	var active: bool = bool(context.get("stage4_magnetic_active", magnetic_active))
	var enraged: bool = bool(context.get("stage4_magnetic_enraged", magnetic_enraged))
	var timer: float = float(context.get("stage4_magnetic_timer", magnetic_timer_frames))
	var total: float = MAGNETIC_ENRAGED_DURATION_FRAMES if enraged else MAGNETIC_DURATION_FRAMES
	var progress: float = clampf(1.0 - maxf(0.0, timer) / maxf(1.0, total), 0.0, 1.0)
	var render_scale: float = float(context.get("render_scale", 0.0))
	if render_scale <= 0.0:
		var game_size: Vector2 = _as_vector2(context.get("game_size", Vector2.ZERO), Vector2.ZERO)
		var width: float = maxf(1.0, float(context.get("width", FIELD_WIDTH)))
		render_scale = game_size.x / width if game_size.x > 0.0 else 1.0
	return {
		"active": active,
		"progress": progress,
		"boss_center": _as_vector2(context.get("stage4_magnetic_center", magnetic_center), _get_boss_center(context)),
		"radius": maxf(24.0, float(context.get("stage4_magnetic_radius", magnetic_radius))),
		"frame": int(context.get("stage4_magnetic_frame", _get_current_frame_index())),
		"elapsed": float(context.get("stage4_effect_clock", frame_clock)),
		"enraged": enraged,
		"projectile_active": bool(context.get("stage4_magnetic_projectile_active", magnetic_projectile_active)),
		"projectile_pos": _as_vector2(context.get("stage4_magnetic_projectile_pos", magnetic_projectile_pos), magnetic_projectile_pos),
		"projectile_radius": maxf(12.0, float(context.get("stage4_magnetic_projectile_radius", magnetic_projectile_radius))),
		"projectile_elapsed": maxf(0.0, float(context.get("stage4_magnetic_projectile_elapsed", magnetic_projectile_elapsed_seconds))),
		"projectile_velocity": _as_vector2(context.get("stage4_magnetic_projectile_velocity", magnetic_projectile_velocity), magnetic_projectile_velocity),
		"projectile_y_speed_multiplier": clampf(float(context.get("stage4_magnetic_projectile_y_speed_multiplier", magnetic_projectile_y_speed_multiplier)), 0.0, 1.0),
		"projectile_fade_active": bool(context.get("stage4_magnetic_projectile_fade_active", magnetic_projectile_fade_timer_seconds > 0.0)),
		"projectile_fade_timer": maxf(0.0, float(context.get("stage4_magnetic_projectile_fade_timer", magnetic_projectile_fade_timer_seconds))),
		"projectile_fade_total": MAGNETIC_PROJECTILE_FADE_SECONDS,
		"projectile_fade_pos": _as_vector2(context.get("stage4_magnetic_projectile_fade_pos", magnetic_projectile_fade_pos), magnetic_projectile_fade_pos),
		"projectile_fade_radius": maxf(12.0, float(context.get("stage4_magnetic_projectile_fade_radius", magnetic_projectile_fade_radius))),
		"projectile_fade_velocity": _as_vector2(context.get("stage4_magnetic_projectile_fade_velocity", magnetic_projectile_fade_velocity), magnetic_projectile_fade_velocity),
		"shake_offset": shake_offset,
		"game_offset": _as_vector2(context.get("game_offset", Vector2.ZERO), Vector2.ZERO),
		"render_scale": render_scale,
	}


func _stop_magnetic_fx_host() -> void:
	if not _is_valid_magnetic_fx_host():
		magnetic_fx_host = null
		magnetic_fx_host_add_pending = false
		magnetic_fx_host_runtime_prewarmed = false
		return
	if magnetic_fx_host.has_method("set_active"):
		magnetic_fx_host.set_active(false)


func _is_valid_magnetic_fx_host() -> bool:
	return magnetic_fx_host != null and is_instance_valid(magnetic_fx_host) and not magnetic_fx_host.is_queued_for_deletion()


func _sync_meditation_fx_host(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, active: bool) -> bool:
	if not active and not _is_valid_meditation_fx_host():
		return false
	var host: Node = _get_or_create_meditation_fx_host(canvas)
	if host == null or not host.has_method("sync_state"):
		return false
	host.sync_state(_build_meditation_fx_context(context, shake_offset), active)
	if not active:
		return false
	return host.get_parent() != null


func _get_or_create_meditation_fx_host(canvas: CanvasItem) -> Node:
	if _is_valid_meditation_fx_host():
		_prewarm_meditation_fx_host_runtime_nodes()
		return meditation_fx_host
	if not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing: Node = parent.get_node_or_null("PonkMeditationFxHost")
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		meditation_fx_host = existing
		meditation_fx_host_add_pending = false
		meditation_fx_host_runtime_prewarmed = false
		_prewarm_meditation_fx_host_runtime_nodes()
		return meditation_fx_host
	meditation_fx_host = Stage4PonkMeditationFxHost.new()
	meditation_fx_host.name = "PonkMeditationFxHost"
	meditation_fx_host.visible = false
	meditation_fx_host_runtime_prewarmed = false
	_prewarm_meditation_fx_host_runtime_nodes()
	if not meditation_fx_host_add_pending:
		meditation_fx_host_add_pending = true
		parent.call_deferred("add_child", meditation_fx_host)
	return meditation_fx_host


func _build_meditation_fx_context(context: Dictionary, shake_offset: Vector2) -> Dictionary:
	var active: bool = bool(context.get("stage4_meditation_active", meditation_active))
	var release_active: bool = bool(context.get("stage4_meditation_release_fx_active", meditation_release_fx_timer_frames > 0.0))
	var timer: float = float(context.get("stage4_meditation_timer", meditation_timer_frames))
	var progress: float = clampf(1.0 - maxf(0.0, timer) / MEDITATION_DURATION_FRAMES, 0.0, 1.0)
	var release_timer: float = float(context.get("stage4_meditation_release_fx_timer", meditation_release_fx_timer_frames))
	var release_progress: float = clampf(1.0 - maxf(0.0, release_timer) / MEDITATION_RELEASE_FX_FRAMES, 0.0, 1.0)
	var render_scale: float = float(context.get("render_scale", 0.0))
	if render_scale <= 0.0:
		var game_size: Vector2 = _as_vector2(context.get("game_size", Vector2.ZERO), Vector2.ZERO)
		var width: float = maxf(1.0, float(context.get("width", FIELD_WIDTH)))
		render_scale = game_size.x / width if game_size.x > 0.0 else 1.0
	var trails: Array = _as_array(context.get("stage4_meditation_trails", meditation_trails))
	if not active and release_active:
		trails = _as_array(context.get("stage4_meditation_release_fx_trails", meditation_release_fx_trails))
	var ball_pos: Vector2 = _as_vector2(context.get("stage4_meditation_ball_pos", meditation_ball_pos), meditation_ball_pos)
	if not active and release_active:
		ball_pos = _as_vector2(context.get("ball_pos", meditation_release_fx_pos), meditation_release_fx_pos)
	return {
		"active": active,
		"release_active": release_active,
		"progress": progress,
		"release_progress": release_progress,
		"boss_center": _get_boss_center(context),
		"ball_pos": ball_pos,
		"trails": trails,
		"shake_offset": shake_offset,
		"game_offset": _as_vector2(context.get("game_offset", Vector2.ZERO), Vector2.ZERO),
		"render_scale": render_scale,
		"release_origin": _as_vector2(context.get("stage4_meditation_release_fx_origin", meditation_release_fx_origin), meditation_release_fx_origin),
		"release_pos": _as_vector2(context.get("stage4_meditation_release_fx_pos", meditation_release_fx_pos), meditation_release_fx_pos),
		"release_velocity": _as_vector2(context.get("stage4_meditation_release_fx_velocity", meditation_release_fx_velocity), meditation_release_fx_velocity),
		"release_id": int(context.get("stage4_meditation_release_fx_id", meditation_release_fx_id)),
	}


func _stop_meditation_fx_host() -> void:
	if not _is_valid_meditation_fx_host():
		meditation_fx_host = null
		meditation_fx_host_add_pending = false
		meditation_fx_host_runtime_prewarmed = false
		return
	if meditation_fx_host.has_method("set_active"):
		meditation_fx_host.set_active(false)


func _is_valid_meditation_fx_host() -> bool:
	return meditation_fx_host != null and is_instance_valid(meditation_fx_host) and not meditation_fx_host.is_queued_for_deletion()


func _reset_meditation_release_fx(reset_id: bool = false) -> void:
	meditation_release_fx_timer_frames = 0.0
	meditation_release_fx_origin = Vector2.ZERO
	meditation_release_fx_pos = Vector2.ZERO
	meditation_release_fx_velocity = Vector2.ZERO
	meditation_release_fx_trails.clear()
	if reset_id:
		meditation_release_fx_id = 0


func _draw_meditation(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var boss_center: Vector2 = _get_boss_center(context) + shake_offset
	for circle_value in _as_array(context.get("stage4_meditation_circles", meditation_circles)):
		if not (circle_value is Dictionary):
			continue
		var circle: Dictionary = circle_value
		var alpha: float = clampf(float(circle.get("life", 0.0)) / 72.0, 0.0, 1.0)
		var center: Vector2 = _as_vector2(circle.get("pos", boss_center - shake_offset), boss_center - shake_offset) + shake_offset
		canvas.draw_arc(center, float(circle.get("radius", 40.0)), 0.0, TAU, 56, Color(1.0, 0.84, 0.42, alpha * 0.48), 2.0, true)
	for trail_value in _as_array(context.get("stage4_meditation_trails", meditation_trails)):
		if not (trail_value is Dictionary):
			continue
		var trail: Dictionary = trail_value
		var alpha: float = clampf(float(trail.get("life", 0.0)) / 34.0, 0.0, 1.0)
		var pos: Vector2 = _as_vector2(trail.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		canvas.draw_circle(pos, maxf(2.0, float(trail.get("radius", 9.0))) * alpha, Color(1.0, 0.78, 0.28, alpha * 0.32))
	for particle_value in _as_array(context.get("stage4_meditation_particles", meditation_particles)):
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var alpha: float = clampf(float(particle.get("life", 0.0)) / 42.0, 0.0, 1.0)
		var pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		canvas.draw_circle(pos, maxf(1.0, float(particle.get("size", 2.5))), Color(0.92, 1.0, 0.78, alpha * 0.72))
	var ball_pos: Vector2 = _as_vector2(context.get("stage4_meditation_ball_pos", meditation_ball_pos), meditation_ball_pos) + shake_offset
	canvas.draw_circle(ball_pos, 25.0, Color(1.0, 0.83, 0.28, 0.18))
	canvas.draw_arc(boss_center, MEDITATION_ORBIT_RADIUS * 1.5, frame_clock * 2.4, frame_clock * 2.4 + PI * 1.2, 48, Color(1.0, 0.86, 0.42, 0.42), 2.0, true)


func _get_current_frame_index() -> int:
	return int(floor(frame_clock / MAGNETIC_FIELD_FRAME_INTERVAL)) % MAGNETIC_FIELD_FRAME_COUNT


func _get_base_ball_speed(context: Dictionary, deps: Dictionary = {}) -> float:
	var physics: Object = deps.get("ball_physics", null)
	if physics != null and physics.has_method("get_minimum_rally_speed"):
		return maxf(1.0, float(physics.get_minimum_rally_speed()))
	if physics != null and physics.get("BALL_BASE_SPEED") != null:
		return maxf(1.0, float(physics.get("BALL_BASE_SPEED")))
	return maxf(1.0, float(context.get("ball_base_speed", BALL_BASE_SPEED_FALLBACK)))


func _get_boss_center(context: Dictionary) -> Vector2:
	var boss_pos: Vector2 = _get_vector2(context, "boss_pos", Vector2(330.0, 55.0))
	var boss_size: Vector2 = _get_vector2(context, "boss_paddle_size", Vector2.ZERO)
	if boss_size == Vector2.ZERO:
		boss_size = Vector2(
			float(context.get("boss_paddle_width", 100.0)),
			float(context.get("boss_hitbox_height", 40.0))
		)
	return boss_pos + boss_size * 0.5


func _get_player_center(context: Dictionary) -> Vector2:
	var player_pos: Vector2 = _get_vector2(context, "player_pos", Vector2(302.5, 690.0))
	var player_size: Vector2 = _get_vector2(
		context,
		"player_paddle_size",
		Vector2(float(context.get("paddle_width", 155.0)), float(context.get("paddle_height", 50.0)))
	)
	return player_pos + player_size * 0.5


func _get_player_rect(context: Dictionary) -> Rect2:
	var player_pos: Vector2 = _get_vector2(context, "player_pos", Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(
		context,
		"player_paddle_size",
		Vector2(float(context.get("paddle_width", 155.0)), float(context.get("paddle_height", 50.0)))
	)
	return Rect2(player_pos, player_size)


func _circle_rect_overlap(circle_center: Vector2, circle_radius: float, rect: Rect2) -> bool:
	var closest := Vector2(
		clampf(circle_center.x, rect.position.x, rect.position.x + rect.size.x),
		clampf(circle_center.y, rect.position.y, rect.position.y + rect.size.y)
	)
	return closest.distance_squared_to(circle_center) <= circle_radius * circle_radius


func _is_enraged(context: Dictionary) -> bool:
	return bool(context.get("enraged_boss_active", context.get("boss_enraged", false)))


func _is_serve_waiting(context: Dictionary) -> bool:
	return (
		bool(context.get("serve_wait_active", false))
		or bool(context.get("scoreboard_active", false))
		or bool(context.get("round_serve_prepare_active", false))
		or not bool(context.get("ball_active", true))
	)


func _is_timing_frozen(context: Dictionary) -> bool:
	return bool(context.get("stopwatch_freeze_active", false)) or bool(context.get("perk_resume_freeze_active", false))


func _is_boss_skill_cooldown_paused(context: Dictionary) -> bool:
	return bool(context.get(
		"active_item_boss_skill_cooldown_paused",
		context.get("active_item_tear_gas_cooldown_pause_active", false)
	))


func _is_inwang_context(context: Dictionary) -> bool:
	if bool(context.get("stage4_is_inwang", false)):
		return true
	for key in ["current_boss_name", "boss_name", "stage4_boss_name", "stage4_current_boss"]:
		var value := str(context.get(key, "")).strip_edges().to_lower()
		if value == "인왕" or value == "inwang":
			return true
	return false


func _is_player_status_immune(deps: Dictionary) -> bool:
	var cleanse_state: Object = deps.get("smasher_cleanse_state", null)
	return cleanse_state != null and cleanse_state.has_method("is_immune") and bool(cleanse_state.is_immune())


func _get_meditation_chance() -> float:
	if _test_meditation_chance >= 0.0:
		return clampf(_test_meditation_chance, 0.0, 1.0)
	return MEDITATION_CHANCE


func _play_magnetic_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage4_magnetic_loop"):
		audio.play_stage4_magnetic_loop()


func _sync_magnetic_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("sync_stage4_magnetic_loop"):
		audio.sync_stage4_magnetic_loop(magnetic_active)


func _stop_magnetic_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("stop_stage4_magnetic_loop"):
		audio.stop_stage4_magnetic_loop()


func _play_meditation_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage4_meditation"):
		audio.play_stage4_meditation()


func _play_meditation_after_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage4_meditation_after"):
		audio.play_stage4_meditation_after()


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return _as_vector2(source.get(key, fallback), fallback)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	return fallback


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
