extends RefCounted

# Stage 7 Akamu Rigo state owner.
#
# Slice 1 established lifecycle/collision/AI/draw/HUD boundaries. Slice 2 owns
# boss-paddle gauge gain and shuriken. Slice 3 adds shadow clones, composite
# boss intangibility, and the post-motion auxiliary-paddle collision contract.
# Slice 4 adds Cloud Veil and Stun/Net Escape under the same single scripted-
# position owner and composite ball-intangibility boundary. Slice 5 adds the
# persistent Awakening/Wind Aura layer and Superspeed as one more authored
# position source instead of handing a second writer to the shared boss AI.

const PlayerKnockbackImmunity := preload("res://scripts/stages/common/player_knockback_immunity.gd")

const STAGE_ID := 7
const BOSS_NAME := "아카무 리고"
const LEGACY_FPS := 60.0
const MAX_DELTA_SEC := 0.1
const GAUGE_MAX := 500.0
const ROUND_GAUGE_CARRY_RATIO := 0.7
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0

const BOSS_HIT_GAUGE_GAIN := 80.0
const BOSS_HIT_AWAKENED_GAUGE_GAIN := 90.0
const BOSS_HIT_SUPERSPEED_GAUGE_GAIN := 20.0
const BOSS_ATTACK_ANIM_SEC := 0.20

const AWAKEN_SCORE_THRESHOLD := 3
const AWAKEN_FREEZE_SEC := 3.0
const WIND_AURA_RADIUS := 90.0
const WIND_AURA_MAX_HITS := 5
const WIND_AURA_HIT_COOLDOWN_SEC := 0.30
const WIND_AURA_RIPPLE_SEC := 0.30
const WIND_AURA_RECHARGE_SEC := 10.0
const WIND_AURA_GAUGE_GAIN := 90.0
const WIND_AURA_FREE_SKILL_CHANCE := 0.30
const WIND_AURA_PARTICLE_COUNT := 24
const WIND_BURST_DURATION_SEC := 0.80
const WIND_BURST_PARTICLE_COUNT := 48
const WIND_DISPERSE_PARTICLE_COUNT := 32

const SUPERSPEED_DURATION_SEC := 10.0
const SUPERSPEED_ACTIVATION_FREEZE_SEC := 0.350
const SUPERSPEED_TEXT_SEC := 1.50
const SUPERSPEED_COOLDOWN_SEC := 25.0
const SUPERSPEED_DASH_RECOVERY_FRAMES := 1.0
const SUPERSPEED_AFTERIMAGE_COUNT := 5
const SUPERSPEED_AFTERIMAGE_DELAY_SEC := 0.060
const SUPERSPEED_AFTERIMAGE_FADE_SEC := 0.80
const SUPERSPEED_DARK_PARTICLE_MAX := 200
const SUPERSPEED_TRAIL_MAX := 30
const SUPERSPEED_TRAIL_SPAWN_INTERVAL_FRAMES := 2.0
const SUPERSPEED_TRAIL_ALPHA_FADE_PER_FRAME := 2.0 / 255.0
const SUPERSPEED_DARK_PALETTE := [
	Color(20.0 / 255.0, 10.0 / 255.0, 30.0 / 255.0, 1.0),
	Color(30.0 / 255.0, 5.0 / 255.0, 15.0 / 255.0, 1.0),
	Color(15.0 / 255.0, 15.0 / 255.0, 25.0 / 255.0, 1.0),
	Color(25.0 / 255.0, 5.0 / 255.0, 25.0 / 255.0, 1.0),
	Color(10.0 / 255.0, 10.0 / 255.0, 10.0 / 255.0, 1.0),
	Color(40.0 / 255.0, 10.0 / 255.0, 40.0 / 255.0, 1.0),
	Color(50.0 / 255.0, 15.0 / 255.0, 20.0 / 255.0, 1.0),
]

const CLONE_GAUGE_COST := 100.0
const CLONE_TRIGGER_CHANCE := 0.25
const CLONE_CAST_SEC := 0.50
const CLONE_EMERGE_SEC := 0.60
const CLONE_DURATION_SEC := 10.0
const CLONE_COOLDOWN_SEC := 8.0
const CLONE_INVULN_BUFFER_SEC := 0.60
const CLONE_DEATH_SEC := 0.70
const CLONE_FADE_SEC := 1.50
const CLONE_SIZE := Vector2(110.0, 96.0)
const CLONE_WALL_MARGIN := 10.0
const CLONE_INITIAL_SPEED_MIN_PER_FRAME := 7.5
const CLONE_INITIAL_SPEED_MAX_PER_FRAME := 12.0
const CLONE_SPEED_MAX_PER_FRAME := 15.0
const CLONE_ACCEL_JITTER_PER_FRAME := 0.6
const CLONE_MAX_ENTITIES := 8
const AUXILIARY_BOUNCE_RESULT_KEYS := [
	"ball_pos",
	"ball_vel",
	"ball_impact_boost",
	"ball_boost_decay_rate",
	"ball_min_boost",
	"ball_serve_origin",
	"vertical_bounce_count",
	"ball_spin_strength",
	"ball_spin_direction",
	"drive_speed_increase",
	"rally_speed_cap_bonus",
	"max_ball_speed",
	"impact_boost_max_ball_speed",
	"fire_weather_max_ball_speed",
	"commando_suicide_drone_ball_boost_active",
	"commando_suicide_drone_ball_restore_speed",
	"commando_suicide_drone_ball_boosted_speed",
	"commando_suicide_drone_ball_boost_consumed",
	"commando_suicide_drone_ball_restored_speed",
	"commando_suicide_drone_speed_limit_disabled",
	"lingpet_wild_roar_ball_boost_active",
	"lingpet_wild_roar_ball_restore_speed",
	"lingpet_wild_roar_ball_boost_consumed",
	"lingpet_wild_roar_ball_restored_speed",
	"lingpet_wild_roar_speed_limit_disabled",
	"speed_limit_disabled",
]
const SHURIKEN_GAUGE_COST := 30.0
const CLOUD_GAUGE_COST := 120.0
const SUPERSPEED_GAUGE_COST := 250.0
const COMMON_BOSS_DASH_GAUGE_COST := 50.0

const CLOUD_TRIGGER_CHANCE := 0.35
const CLOUD_PRECAST_SEC := 0.40
const CLOUD_DASH_SEC := 0.316
const CLOUD_EXPAND_SEC := 0.280
const CLOUD_SOLID_SEC := 3.0
const CLOUD_FADE_TO_SEMI_SEC := 2.0
const CLOUD_VISIBLE_SEC := 5.0
const CLOUD_FINAL_FADE_SEC := 3.0
const CLOUD_TOTAL_SEC := CLOUD_EXPAND_SEC + CLOUD_VISIBLE_SEC + CLOUD_FINAL_FADE_SEC
const CLOUD_SEMI_ALPHA := 100.0 / 255.0
const CLOUD_COOLDOWN_MIN_SEC := 20.0
const CLOUD_COOLDOWN_MAX_SEC := 40.0
const CLOUD_INVULN_BUFFER_SEC := 0.180
const CLOUD_LOGICAL_SIZE := Vector2(235.0, 56.0)
const CLOUD_SPAWN_Y_OFFSET := 80.0
const CLOUD_INTANGIBLE_SOURCE := "stage7_cloud_dash"

const ESCAPE_TRIGGER_CHANCE := 0.40
const ESCAPE_NET_DELAY_SEC := 0.30
const ESCAPE_DURATION_SEC := 0.50
const ESCAPE_GAUGE_COST := 30.0
const ESCAPE_HOLOGRAM_FADE_SEC := 0.40
const ESCAPE_GHOST_COUNT := 5
const ESCAPE_GHOST_DELAY_SEC := 0.060
const ESCAPE_MAX_DISTANCE := 260.0
const ESCAPE_SIDE_MIN_SPACE := 80.0
const ESCAPE_WALL_MARGIN := 20.0
const ESCAPE_FALLBACK_MIN_DISTANCE := 50.0
const ESCAPE_INTANGIBLE_SOURCE := "stage7_stun_escape"

const SHURIKEN_CAST_SEC := 0.30
const SHURIKEN_COOLDOWN_MIN_MSEC := 8000
const SHURIKEN_COOLDOWN_MAX_MSEC := 25000
const SHURIKEN_PENDING_DELAY_SEC := 0.20
const SHURIKEN_SPEED_PER_FRAME := 20.0
const SHURIKEN_SIZE := Vector2(18.0, 10.0)
const SHURIKEN_OFFSCREEN_MARGIN := 20.0
const SHURIKEN_SLOW_FRAMES := 120.0
const SHURIKEN_SLOW_MULTIPLIER := 0.20
const SHURIKEN_GAUGE_DRAIN_TICK_FRAMES := 30.0
const SHURIKEN_GAUGE_DRAIN_AMOUNT := 15.0
const SHURIKEN_GAUGE_DRAIN_TICKS := 4
const SHURIKEN_STATUS_SOURCE := "stage7_akamu_shuriken"
const SHURIKEN_MAX_ACTIVE := 8
const SHURIKEN_SPIN_RADIANS_PER_SEC := TAU * 15.0
const SHURIKEN_HIT_PARTICLE_MAX := 32
const SHURIKEN_SMOKE_OPACITY_THRESHOLD := 50.0 / 255.0

var boss_special_gauge: float = 0.0
var awakened := false
var status := "charging"

var _has_score_round_generation := false
var _last_score_round_generation := 0
var _gameplay_freeze_remaining_sec := 0.0
var _gameplay_freeze_reason := ""
var _awakening_trigger_armed := false
var _awakening_intro_pending := false
var _awakening_intro_done := false
var _last_boss_pos := Vector2(330.0, 25.0)
var _last_boss_size := Vector2(100.0, 40.0)
var _last_boss_visual_scale := 1.0
var _boss_ball_intangible := false
var _boss_ball_intangible_sources: Dictionary = {}
var _scripted_motion_active := false
var _scripted_boss_pos := Vector2.ZERO
var _debug_scripted_motion_active := false
var _debug_scripted_boss_pos := Vector2.ZERO
var _boss_attack_remaining_sec := 0.0
var _boss_attack_source := ""
var _boss_attack_target_x := 0.0
var _superspeed_active := false
var _superspeed_remaining_sec := 0.0
var _superspeed_text_remaining_sec := 0.0
var _superspeed_cooldown_remaining_sec := 0.0
var _superspeed_dash_active := false
var _superspeed_dash_timer_frames := 0.0
var _superspeed_dash_duration_frames := 0.0
var _superspeed_dash_direction := 0
var _superspeed_dash_target_center_x := 0.0
var _superspeed_dash_recovery_frames := 0.0
var _superspeed_motion_frame_accumulator := 0.0
var _superspeed_boss_pos := Vector2.ZERO
var _superspeed_boss_size := Vector2(100.0, 40.0)
var _superspeed_visual_scale := 1.0
var _superspeed_trail_spawn_accumulator := 0.0
var _skill_cooldown_paused := false
var _external_scripted_motion_active := false

var _wind_aura_active := false
var _wind_aura_hit_count := 0
var _wind_aura_depleted := false
var _wind_aura_recharge_remaining_sec := 0.0
var _wind_aura_hit_cooldown_remaining_sec := 0.0
var _wind_aura_ripple_remaining_sec := 0.0
var _wind_aura_elapsed_sec := 0.0
var _wind_aura_free_clone_queued := false

var _cloud_dash_active := false
var _cloud_dash_phase := ""
var _cloud_phase_elapsed_sec := 0.0
var _cloud_origin_boss_pos := Vector2.ZERO
var _cloud_target_boss_pos := Vector2.ZERO
var _cloud_home_boss_pos := Vector2.ZERO
var _cloud_boss_size := Vector2(100.0, 40.0)
var _cloud_cooldown_remaining_sec := 0.0
var _cloud_cooldown_total_sec := 0.0
var _cloud_invuln_buffer_remaining_sec := 0.0
var _cloud_field_active := false
var _cloud_field_elapsed_sec := 0.0
var _cloud_field_center := Vector2.ZERO

var _escape_active := false
var _escape_elapsed_sec := 0.0
var _escape_start_boss_pos := Vector2.ZERO
var _escape_target_boss_pos := Vector2.ZERO
var _escape_boss_size := Vector2(100.0, 40.0)
var _escape_visual_scale := 1.0
var _escape_episode_active := false
var _escape_attempted := false
var _escape_ready_remaining_sec := 0.0
var _escape_last_released_net_count := 0
var _hologram_draw_context: Dictionary = {}

var _boss_position_release_pending := false
var _boss_position_release_pos := Vector2.ZERO

var _clone_casting := false
var _clone_cast_elapsed_sec := 0.0
var _clone_cooldown_remaining_sec := 0.0
var _clone_invuln_buffer_remaining_sec := 0.0
var _clone_cast_boss_pos := Vector2.ZERO
# Odin CC window mirrors (synced per effects update from the dark-swamp state):
# the casting position writer yields to the knockback and preserves the stun
# residual on top of the pin; the escape start rewinds this frame's applied
# knockback velocity (Python attempts the escape BEFORE the movement applies).
var _odin_knockback_window_active := false
var _odin_knockback_vel := 0.0
var _odin_stun_residual := 0.0
var _clone_cast_boss_center := Vector2.ZERO
var _clone_cast_free := false
var _clone_cast_source := ""
var _clone_next_id := 1

var _shuriken_scheduler_armed := false
var _shuriken_casting := false
var _shuriken_cast_elapsed_sec := 0.0
var _shuriken_cast_boss_pos := Vector2.ZERO
var _shuriken_cooldown_remaining_sec := 0.0
var _shuriken_cooldown_total_sec := 0.0
var _shuriken_pending_remaining: Array = []
var _shuriken_gauge_ticks_left := 0
var _shuriken_gauge_tick_frames_remaining := 0.0

var _clones: Array = []
var _shurikens: Array = []
var _afterimages: Array = []
var _particles: Array = []
var _wind_aura_particles: Array = []
var _wind_burst_particles: Array = []
var _superspeed_afterimages: Array = []
var _superspeed_dark_particles: Array = []
var _superspeed_trails: Array = []
var _cloud_draw_context: Dictionary = {}
var _aura_draw_context: Dictionary = {}
var _wind_aura_draw_context: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


static func fps_scale(delta: float) -> float:
	return clampf(delta, 0.0, MAX_DELTA_SEC) * LEGACY_FPS


static func legacy_motion_step(pixels_per_frame: float, delta: float) -> float:
	return pixels_per_frame * fps_scale(delta)


func reset() -> void:
	clear_round_transients()
	boss_special_gauge = 0.0
	awakened = false
	_awakening_trigger_armed = false
	_awakening_intro_pending = false
	_awakening_intro_done = false
	_wind_aura_active = false
	_wind_aura_hit_count = 0
	_wind_aura_depleted = false
	_wind_aura_recharge_remaining_sec = 0.0
	_wind_aura_hit_cooldown_remaining_sec = 0.0
	_wind_aura_ripple_remaining_sec = 0.0
	_wind_aura_elapsed_sec = 0.0
	_wind_aura_free_clone_queued = false
	_wind_aura_particles.clear()
	_wind_aura_draw_context.clear()
	_last_boss_pos = Vector2(330.0, 25.0)
	_last_boss_size = Vector2(100.0, 40.0)
	_last_boss_visual_scale = 1.0
	_has_score_round_generation = false
	_last_score_round_generation = 0
	# 스킬 쿨타임은 라운드 간 유지되지만(clear_round_transients), 완전 리셋
	# (새 게임 0-0 / 스테이지 이탈 / result)에서는 0으로 초기화한다.
	_shuriken_scheduler_armed = false
	_shuriken_cooldown_remaining_sec = 0.0
	_shuriken_cooldown_total_sec = 0.0
	_clone_cooldown_remaining_sec = 0.0
	_cloud_cooldown_remaining_sec = 0.0
	_cloud_cooldown_total_sec = 0.0
	_superspeed_cooldown_remaining_sec = 0.0
	status = "charging"


func reset_for_result() -> void:
	reset()


func clear_round_transients() -> void:
	# Intentionally idempotent. Generic ball cleanup may reach this more than
	# once for one score boundary, so this method must never alter persistent
	# gauge/awakening state.
	_clones.clear()
	_shurikens.clear()
	_afterimages.clear()
	_particles.clear()
	_wind_burst_particles.clear()
	_superspeed_afterimages.clear()
	_superspeed_dark_particles.clear()
	_superspeed_trails.clear()
	_cloud_draw_context.clear()
	_hologram_draw_context.clear()
	_aura_draw_context.clear()
	_gameplay_freeze_remaining_sec = 0.0
	_gameplay_freeze_reason = ""
	# The accepted score event arms Awakening before the generic ball-reset
	# cleanup runs. Keep that arm across this idempotent transient cleanup; only
	# an already-running intro/freeze is cancelled and retried after serve.
	_awakening_intro_pending = false
	_wind_aura_hit_cooldown_remaining_sec = 0.0
	_wind_aura_ripple_remaining_sec = 0.0
	_wind_aura_free_clone_queued = false
	_boss_ball_intangible = false
	_boss_ball_intangible_sources.clear()
	_scripted_motion_active = false
	_scripted_boss_pos = Vector2.ZERO
	_debug_scripted_motion_active = false
	_debug_scripted_boss_pos = Vector2.ZERO
	_boss_attack_remaining_sec = 0.0
	_boss_attack_source = ""
	_boss_attack_target_x = 0.0
	_superspeed_active = false
	_superspeed_remaining_sec = 0.0
	_superspeed_text_remaining_sec = 0.0
	# 스킬 쿨타임은 라운드 경계를 넘어 유지된다(원본 stage8 파리티: reset_round의
	# stage-8 분기는 승/패 애니메이션만 리셋하고 쿨타임은 wall-clock으로 지속).
	# 완전 리셋(reset())에서만 0으로 초기화한다. 여기서는 진행 중 캐스트/위치/
	# 파티클 같은 transient만 정리한다.
	_superspeed_dash_active = false
	_superspeed_dash_timer_frames = 0.0
	_superspeed_dash_duration_frames = 0.0
	_superspeed_dash_direction = 0
	_superspeed_dash_target_center_x = 0.0
	_superspeed_dash_recovery_frames = 0.0
	_superspeed_motion_frame_accumulator = 0.0
	_superspeed_boss_pos = Vector2.ZERO
	_superspeed_boss_size = Vector2(100.0, 40.0)
	_superspeed_visual_scale = 1.0
	_superspeed_trail_spawn_accumulator = 0.0
	_skill_cooldown_paused = false
	_external_scripted_motion_active = false
	_cloud_dash_active = false
	_cloud_dash_phase = ""
	_cloud_phase_elapsed_sec = 0.0
	_cloud_origin_boss_pos = Vector2.ZERO
	_cloud_target_boss_pos = Vector2.ZERO
	_cloud_home_boss_pos = Vector2.ZERO
	_cloud_boss_size = Vector2(100.0, 40.0)
	_cloud_invuln_buffer_remaining_sec = 0.0
	_cloud_field_active = false
	_cloud_field_elapsed_sec = 0.0
	_cloud_field_center = Vector2.ZERO
	_escape_active = false
	_escape_elapsed_sec = 0.0
	_escape_start_boss_pos = Vector2.ZERO
	_escape_target_boss_pos = Vector2.ZERO
	_escape_boss_size = Vector2(100.0, 40.0)
	_escape_visual_scale = 1.0
	_escape_episode_active = false
	_escape_attempted = false
	_escape_ready_remaining_sec = 0.0
	_escape_last_released_net_count = 0
	_boss_position_release_pending = false
	_boss_position_release_pos = Vector2.ZERO
	_clone_casting = false
	_clone_cast_elapsed_sec = 0.0
	_clone_invuln_buffer_remaining_sec = 0.0
	_clone_cast_boss_pos = Vector2.ZERO
	_clone_cast_boss_center = Vector2.ZERO
	_clone_cast_free = false
	_clone_cast_source = ""
	_clone_next_id = 1
	# _shuriken_scheduler_armed / _shuriken_cooldown_* 는 라운드 간 유지(위 참조).
	_shuriken_casting = false
	_shuriken_cast_elapsed_sec = 0.0
	_shuriken_cast_boss_pos = Vector2.ZERO
	_shuriken_pending_remaining.clear()
	_shuriken_gauge_ticks_left = 0
	_shuriken_gauge_tick_frames_remaining = 0.0
	# Awakening and its durability/recharge state survive normal score cleanup.
	# Rebuild the payload after transient position writers (cloud/Superspeed/etc.)
	# have been cleared so the persistent aura cannot remain pinned to their last
	# authored position during the serve wait.
	_sync_wind_aura_draw_context()
	status = "charging"


func reset_round() -> void:
	# Compatibility alias for older stage cleanup fanouts. Gauge carry belongs
	# exclusively to apply_score_round_carry().
	clear_round_transients()


func apply_score_round_carry(round_generation: int) -> bool:
	# A score event and the later ball-reset path can describe the same round.
	# Accept only a newer generation so the 0.7 carry cannot be applied twice.
	if _has_score_round_generation and round_generation <= _last_score_round_generation:
		return false
	_has_score_round_generation = true
	_last_score_round_generation = round_generation
	boss_special_gauge = float(int(clampf(boss_special_gauge, 0.0, GAUGE_MAX) * ROUND_GAUGE_CARRY_RATIO))
	return true


func handle_score_event(_scoring_side: String, score_result: Dictionary) -> void:
	# Godot's match_score_state.player_score is the live rally-win counter that
	# corresponds to legacy round_wins. Arm here, after an accepted score, but do
	# not start the 3-second freeze under the scoreboard overlay.
	if awakened or _awakening_intro_done:
		return
	if int(score_result.get("player_score", 0)) >= AWAKEN_SCORE_THRESHOLD:
		_awakening_trigger_armed = true


func try_begin_pending_awakening() -> bool:
	if (
		not _awakening_trigger_armed
		or awakened
		or _awakening_intro_done
		or _awakening_intro_pending
		or is_gameplay_freeze_active()
	):
		return false
	_awakening_intro_pending = true
	_gameplay_freeze_reason = "awakening"
	_gameplay_freeze_remaining_sec = AWAKEN_FREEZE_SEC
	status = "awakening_freeze"
	return true


func _sync_awakening_trigger(context: Dictionary) -> void:
	if awakened or _awakening_intro_done or _awakening_trigger_armed:
		return
	if int(context.get("player_score", 0)) < AWAKEN_SCORE_THRESHOLD:
		return
	if bool(context.get("waiting_for_serve", false)) or not bool(context.get("ball_active", true)):
		return
	_awakening_trigger_armed = true


func _complete_awakening(context: Dictionary = {}, deps: Dictionary = {}) -> void:
	if not _awakening_intro_pending:
		return
	_cache_boss_geometry(context)
	_awakening_intro_pending = false
	_awakening_trigger_armed = false
	_awakening_intro_done = true
	awakened = true
	_wind_aura_active = true
	_wind_aura_hit_count = 0
	_wind_aura_depleted = false
	_wind_aura_recharge_remaining_sec = 0.0
	_wind_aura_hit_cooldown_remaining_sec = 0.0
	_wind_aura_ripple_remaining_sec = 0.0
	_init_wind_aura_particles()
	_spawn_wind_burst(_last_boss_pos + _last_boss_size * 0.5, false)
	_sync_wind_aura_draw_context()
	status = "awakened"
	# Legacy checks the ultimate immediately after awakening completion. Chain
	# the 350ms activation freeze here so no player/AI/ball tick leaks between
	# the 3s intro and a gauge-ready Superspeed activation.
	if (
		boss_special_gauge >= SUPERSPEED_GAUGE_COST
		and not _is_boss_skill_cooldown_paused(context, deps)
	):
		_try_start_superspeed(context)


func _sync_odin_cc_window(deps: Dictionary) -> void:
	# Non-instantiating peeks only. Resolution order lets integration smokes
	# inject the swamp state directly.
	_odin_knockback_window_active = false
	_odin_knockback_vel = 0.0
	_odin_stun_residual = 0.0
	var swamp: Object = deps.get("odins_eye_dark_swamp_state", null)
	if swamp == null:
		var mythic: Object = deps.get("mythic_item_runtime", null)
		if mythic != null:
			var swamp_value: Variant = mythic.get("odins_eye_dark_swamp_state")
			if swamp_value is Object:
				swamp = swamp_value
	if swamp == null:
		var registry: Object = deps.get("registry", null)
		if registry != null and registry.has_method("get_cached_instance"):
			var mythic_peek: Object = registry.get_cached_instance("mythic_item_runtime")
			if mythic_peek != null:
				var swamp_peek: Variant = mythic_peek.get("odins_eye_dark_swamp_state")
				if swamp_peek is Object:
					swamp = swamp_peek
	if swamp == null:
		return
	_odin_knockback_window_active = float(swamp.get("boss_knockback_timer_frames")) > 0.0
	if _odin_knockback_window_active:
		_odin_knockback_vel = float(swamp.get("boss_knockback_vel"))
	if float(swamp.get("boss_stun_timer_frames")) > 0.0:
		_odin_stun_residual = float(swamp.get("boss_knockback_vel"))


func _cache_boss_geometry(context: Dictionary) -> void:
	_last_boss_pos = _as_vector2(context.get("boss_pos", _last_boss_pos), _last_boss_pos)
	_last_boss_size = _as_vector2(
		context.get("boss_paddle_size", Vector2(
			float(context.get("boss_paddle_width", _last_boss_size.x)),
			float(context.get("boss_hitbox_height", _last_boss_size.y))
		)),
		_last_boss_size
	)
	_last_boss_visual_scale = clampf(
		float(context.get("boss_paddle_shrink_scale", _last_boss_visual_scale)),
		0.2,
		1.0
	)


func update(delta: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	_external_scripted_motion_active = bool(context.get("lingpet_puppet_grab_active", false))
	_cache_boss_geometry(context)
	_sync_odin_cc_window(deps)
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		if _has_runtime_state():
			reset()
		return _build_result()

	var clamped_delta := clampf(delta, 0.0, MAX_DELTA_SEC)
	if is_gameplay_freeze_active():
		return advance_gameplay_freeze(clamped_delta, context, deps)
	if _is_timing_frozen(context):
		_skill_cooldown_paused = false
		# Keep persistent draw ownership attached to the live boss while every
		# gameplay/aura timer remains frozen by this early return.
		_sync_wind_aura_draw_context()
		status = "paused"
		return _build_result()
	_sync_awakening_trigger(context)
	if try_begin_pending_awakening():
		return _build_result()

	var result: Dictionary = {}
	# A completed scripted move publishes its exact final position once. Clear
	# the previous frame's delivery before advancing this frame's state.
	_boss_position_release_pending = false
	var frame_scale: float = fps_scale(clamped_delta)
	var skill_cooldown_paused: bool = _is_boss_skill_cooldown_paused(context, deps)
	var superspeed_was_active: bool = _superspeed_active
	_skill_cooldown_paused = skill_cooldown_paused
	_update_boss_attack(clamped_delta)
	_update_particles(clamped_delta)
	_update_wind_effects(frame_scale, clamped_delta, context, skill_cooldown_paused)
	_update_superspeed(frame_scale, clamped_delta, context)
	_update_hologram(clamped_delta)
	_update_shadow_clones(frame_scale, clamped_delta, deps)
	_update_clone_invulnerability(clamped_delta)
	_update_cloud(clamped_delta, deps)
	_update_escape_motion(clamped_delta)
	_update_shuriken_projectiles(frame_scale, clamped_delta, context, deps, result)
	_update_shuriken_gauge_drain(frame_scale, context, result)

	if not skill_cooldown_paused:
		_clone_cooldown_remaining_sec = maxf(0.0, _clone_cooldown_remaining_sec - clamped_delta)
		_cloud_cooldown_remaining_sec = maxf(0.0, _cloud_cooldown_remaining_sec - clamped_delta)
		if not superspeed_was_active:
			_superspeed_cooldown_remaining_sec = maxf(
				0.0,
				_superspeed_cooldown_remaining_sec - clamped_delta
			)
		_update_wind_aura_recharge(clamped_delta)
		if _try_start_superspeed(context):
			_refresh_status(false)
			result.merge(_build_result(), true)
			return result
		_update_wind_aura_free_clone_queue(context)
		_update_escape_trigger(clamped_delta, context, deps)
		_update_pending_shurikens(clamped_delta, context, deps)
		if _clone_casting:
			_update_clone_cast(clamped_delta, deps)
		elif _shuriken_casting:
			_update_shuriken_cast(clamped_delta, context, deps)
		else:
			_update_shuriken_scheduler(clamped_delta, context)

	_refresh_status(skill_cooldown_paused)
	result.merge(_build_result(), true)
	return result


func is_gameplay_freeze_active() -> bool:
	return _gameplay_freeze_remaining_sec > 0.0


func advance_gameplay_freeze(delta: float, context: Dictionary = {}, deps: Dictionary = {}) -> Dictionary:
	_external_scripted_motion_active = bool(context.get("lingpet_puppet_grab_active", false))
	_cache_boss_geometry(context)
	_skill_cooldown_paused = _is_boss_skill_cooldown_paused(context, deps)
	var clamped_delta := clampf(delta, 0.0, MAX_DELTA_SEC)
	var frame_scale: float = fps_scale(clamped_delta)
	_update_wind_aura_visuals(frame_scale, clamped_delta)
	_update_wind_burst_particles(frame_scale, clamped_delta)
	_sync_wind_aura_draw_context()
	if _superspeed_active:
		_superspeed_remaining_sec = maxf(0.0, _superspeed_remaining_sec - clamped_delta)
		_superspeed_text_remaining_sec = maxf(0.0, _superspeed_text_remaining_sec - clamped_delta)
	_gameplay_freeze_remaining_sec = maxf(0.0, _gameplay_freeze_remaining_sec - clamped_delta)
	var completed_reason: String = _gameplay_freeze_reason
	if not is_gameplay_freeze_active():
		_gameplay_freeze_reason = ""
		if completed_reason == "awakening":
			_complete_awakening(context, deps)
	status = (
		_gameplay_freeze_reason + "_freeze"
		if is_gameplay_freeze_active()
		else ("superspeed_active" if _superspeed_active else "charging")
	)
	return _build_result()


func is_boss_ball_intangible() -> bool:
	return _boss_ball_intangible


func set_boss_ball_intangible_source(source: String, active: bool) -> void:
	var normalized_source: String = source.strip_edges()
	if normalized_source == "" or normalized_source == "shadow_clone":
		return
	if active:
		_boss_ball_intangible_sources[normalized_source] = true
	else:
		_boss_ball_intangible_sources.erase(normalized_source)
	_refresh_boss_ball_intangible()


func resolve_wind_aura_collision(
	ball_pos: Vector2,
	ball_vel: Vector2,
	context: Dictionary,
	deps: Dictionary = {}
) -> Dictionary:
	if (
		not awakened
		or not _wind_aura_active
		or _wind_aura_depleted
		or _wind_aura_hit_cooldown_remaining_sec > 0.0
		or bool(context.get("waiting_for_serve", false))
		or not bool(context.get("ball_active", true))
		or not _is_player_owned_ball(context, deps)
		or ball_vel.y >= 0.0
	):
		return {}
	var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", _last_boss_pos), _last_boss_pos)
	var boss_size: Vector2 = _as_vector2(
		context.get("boss_paddle_size", Vector2(
			float(context.get("boss_paddle_width", _last_boss_size.x)),
			float(context.get("boss_hitbox_height", _last_boss_size.y))
		)),
		_last_boss_size
	)
	var boss_center: Vector2 = boss_pos + boss_size * 0.5
	if ball_pos.distance_squared_to(boss_center) > WIND_AURA_RADIUS * WIND_AURA_RADIUS:
		return {}

	_wind_aura_hit_count = mini(WIND_AURA_MAX_HITS, _wind_aura_hit_count + 1)
	_wind_aura_hit_cooldown_remaining_sec = WIND_AURA_HIT_COOLDOWN_SEC
	_wind_aura_ripple_remaining_sec = WIND_AURA_RIPPLE_SEC
	var reflected_velocity := Vector2(
		ball_vel.x + _rng.randf_range(-2.0, 2.0),
		absf(ball_vel.y) * 1.1
	)
	var audio: Object = deps.get("audio", context.get("stage7_akamu_audio", null))
	# Exact legacy ninjashield.wav cue, promoted as the Stage 7 aura-block
	# one-shot. Keep the facade optional for headless and focused state tests.
	if audio != null and audio.has_method("play_stage7_akamu_wind_aura_block"):
		audio.play_stage7_akamu_wind_aura_block()
	var skill_cooldown_paused_now: bool = (
		bool(context.get("lingpet_star_coil_freeze_boss_skill_cd", false))
		or bool(context.get(
			"active_item_boss_skill_cooldown_paused",
			context.get("active_item_tear_gas_cooldown_pause_active", false)
		))
	)
	if not skill_cooldown_paused_now:
		boss_special_gauge = minf(GAUGE_MAX, boss_special_gauge + WIND_AURA_GAUGE_GAIN)

	# The Python clone branch is dead from a missing `global`, and allowing its
	# intended concurrent start would create two authoritative boss-position
	# writers. Restore both independent rolls, but preserve source order: a
	# successful free cloud claims this frame; clone may start only if no writer
	# was claimed. Superspeed suppresses both while it owns movement.
	var cloud_roll := false
	var clone_roll := false
	if not skill_cooldown_paused_now:
		cloud_roll = _rng.randf() < WIND_AURA_FREE_SKILL_CHANCE
		clone_roll = _rng.randf() < WIND_AURA_FREE_SKILL_CHANCE
	if not skill_cooldown_paused_now and not _superspeed_active:
		var free_cloud_started := false
		if cloud_roll:
			free_cloud_started = _try_start_cloud(
				context,
				deps,
				true,
				true,
				"wind_aura",
				true
			)
		if clone_roll and not _clone_casting and not _has_live_clones():
			if free_cloud_started:
				# Preserve the independent 30% clone success without introducing a
				# simultaneous second position writer. It commits as soon as the
				# cloud dash releases that writer (the cloud field may remain).
				_wind_aura_free_clone_queued = true
			else:
				_try_start_clone_cast(context, true, true, "wind_aura", true)

	if _wind_aura_hit_count >= WIND_AURA_MAX_HITS:
		_wind_aura_depleted = true
		_wind_aura_recharge_remaining_sec = WIND_AURA_RECHARGE_SEC
		_spawn_wind_burst(boss_center, true)
	_sync_wind_aura_draw_context(boss_center)
	return {
		"ball_pos": ball_pos,
		"ball_vel": reflected_velocity,
		"stage7_akamu_wind_aura_hit": true,
		"stage7_akamu_wind_aura_hits": _wind_aura_hit_count,
		"stage7_akamu_wind_aura_depleted": _wind_aura_depleted,
		"stage7_akamu_wind_aura_reward_suppressed": skill_cooldown_paused_now,
	}


func query_clone_ball_collision(
	from_pos: Vector2,
	to_pos: Vector2,
	ball_vel: Vector2,
	context: Dictionary,
	deps: Dictionary = {}
) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		return {}
	if bool(context.get("waiting_for_serve", false)) or not bool(context.get("ball_active", true)):
		return {}
	if not _has_live_clones() or not _is_player_owned_ball(context, deps):
		return {}
	# Direction guard is authoritative. It lets an outgoing boss serve/return and
	# the already-committed normal boss bounce pass through without consuming a
	# clone or reflecting twice in one physics frame.
	if ball_vel.y >= 0.0:
		return {}
	var ball_radius: float = maxf(1.0, float(context.get("ball_size", 28.6)) * 0.5)
	return _find_nearest_clone_hit(from_pos, to_pos, ball_radius)


func resolve_ball_collision(scene: Dictionary, context: Dictionary, deps: Dictionary = {}) -> bool:
	var ball_vel: Vector2 = _as_vector2(scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	var ball_pos: Vector2 = _as_vector2(scene.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var previous_ball_pos: Vector2 = _as_vector2(
		scene.get("previous_ball_pos", context.get("ball_pos", ball_pos)),
		ball_pos
	)
	var clone_hit: Dictionary = query_clone_ball_collision(
		previous_ball_pos,
		ball_pos,
		ball_vel,
		context,
		deps
	)
	if clone_hit.is_empty():
		return false
	var clone_index: int = int(clone_hit.get("index", -1))
	if clone_index < 0 or clone_index >= _clones.size():
		return false
	var clone: Dictionary = _clones[clone_index]
	var clone_rect: Rect2 = _clone_rect(clone)
	var contact_point: Vector2 = _as_vector2(clone_hit.get("point", ball_pos), ball_pos)
	_apply_clone_ball_reflection(scene, context, deps, clone_rect, contact_point)
	_register_auxiliary_paddle_hit(deps)
	_begin_clone_dying(clone_index, deps)
	_register_clone_ball_contact(deps)
	return true


func handle_boss_paddle_hit(scene: Dictionary, context: Dictionary, deps: Dictionary = {}) -> void:
	# Called only after a normal boss-paddle reflection has committed. Keep this
	# a pure notification boundary: mutate Stage 7 state, never the shared bounce.
	var ball_pos: Vector2 = _as_vector2(scene.get("ball_pos", context.get("ball_pos", Vector2.ZERO)), Vector2.ZERO)
	_trigger_boss_attack("boss_paddle_hit", ball_pos.x)
	if _is_boss_skill_cooldown_paused(context, deps):
		return
	var gain: float = BOSS_HIT_GAUGE_GAIN
	if _superspeed_active:
		gain = BOSS_HIT_SUPERSPEED_GAUGE_GAIN
	elif awakened:
		gain = BOSS_HIT_AWAKENED_GAUGE_GAIN
	boss_special_gauge = minf(GAUGE_MAX, boss_special_gauge + gain)
	_try_start_clone_cast(context, false, false, "boss_paddle_hit")
	_try_start_cloud(context, deps, false, false, "boss_paddle_hit")


func drain_boss_special_gauge(amount: float) -> void:
	boss_special_gauge = maxf(0.0, boss_special_gauge - maxf(0.0, amount))


func try_commit_common_boss_dash() -> bool:
	# Superspeed uses its own free predictive branch. Every ordinary Stage 7
	# emergency dash commits the legacy 50-gauge cost only after AI geometry and
	# chance gates have accepted the dash.
	if _superspeed_active:
		return true
	if boss_special_gauge < COMMON_BOSS_DASH_GAUGE_COST:
		return false
	boss_special_gauge -= COMMON_BOSS_DASH_GAUGE_COST
	return true


func get_boss_ai_context() -> Dictionary:
	return {
		"stage7_akamu_boss_gauge": boss_special_gauge,
		"stage7_akamu_awakened": awakened,
		"stage7_akamu_gameplay_freeze_active": is_gameplay_freeze_active(),
		"stage7_akamu_gameplay_freeze_reason": _gameplay_freeze_reason,
		"stage7_akamu_boss_ai_frozen": _scripted_motion_active or is_gameplay_freeze_active(),
		"stage7_akamu_scripted_motion_active": _scripted_motion_active,
		"stage7_akamu_scripted_boss_pos": _scripted_boss_pos,
		"stage7_akamu_clone_casting": _clone_casting,
		"stage7_akamu_clone_live_count": _get_live_clone_count(),
		"stage7_akamu_shuriken_casting": _shuriken_casting,
		"stage7_akamu_cloud_dash_active": _cloud_dash_active,
		"stage7_akamu_cloud_dash_phase": _cloud_dash_phase,
		"stage7_akamu_escape_active": _escape_active,
		"stage7_akamu_superspeed_active": _superspeed_active,
		"stage7_akamu_superspeed_remaining": _superspeed_remaining_sec,
		"stage7_akamu_state_owner": self,
	}


func get_actor_draw_context() -> Dictionary:
	# Render payload collections are read-only borrowed references. Do not deep
	# copy hundreds of projectile/particle Dictionaries in the draw hot path;
	# update owns mutation and renderers consume the payload synchronously.
	return {
		"stage7_akamu_boss_gauge": boss_special_gauge,
		"stage7_akamu_awakened": awakened,
		"stage7_akamu_status": status,
		"stage7_akamu_gameplay_freeze_active": is_gameplay_freeze_active(),
		"stage7_akamu_gameplay_freeze_remaining": _gameplay_freeze_remaining_sec,
		"stage7_akamu_gameplay_freeze_reason": _gameplay_freeze_reason,
		"stage7_akamu_awakening_trigger_armed": _awakening_trigger_armed,
		"stage7_akamu_awakening_intro_pending": _awakening_intro_pending,
		"stage7_akamu_awakening_intro_done": _awakening_intro_done,
		"stage7_akamu_boss_ball_intangible": _boss_ball_intangible,
		"stage7_akamu_scripted_motion_active": _scripted_motion_active,
		"stage7_akamu_scripted_boss_pos": _scripted_boss_pos,
		"stage7_akamu_boss_attack_active": _boss_attack_remaining_sec > 0.0,
		"stage7_akamu_boss_attack_remaining": _boss_attack_remaining_sec,
		"stage7_akamu_boss_attack_total": BOSS_ATTACK_ANIM_SEC,
		"stage7_akamu_boss_attack_source": _boss_attack_source,
		"stage7_akamu_boss_attack_target_x": _boss_attack_target_x,
		"stage7_akamu_clone_casting": _clone_casting,
		"stage7_akamu_clone_cast_progress": clampf(
			_clone_cast_elapsed_sec / maxf(0.001, CLONE_CAST_SEC),
			0.0,
			1.0
		),
		"stage7_akamu_clone_cooldown_remaining": _clone_cooldown_remaining_sec,
		"stage7_akamu_clone_live_count": _get_live_clone_count(),
		"stage7_akamu_shuriken_casting": _shuriken_casting,
		"stage7_akamu_shuriken_cooldown_remaining": _shuriken_cooldown_remaining_sec,
		"stage7_akamu_shuriken_drain_ticks_left": _shuriken_gauge_ticks_left,
		"stage7_akamu_cloud_dash_active": _cloud_dash_active,
		"stage7_akamu_cloud_dash_phase": _cloud_dash_phase,
		"stage7_akamu_cloud_phase_progress": _get_cloud_phase_progress(),
		"stage7_akamu_cloud_field_active": _cloud_field_active,
		"stage7_akamu_cloud_cooldown_remaining": _cloud_cooldown_remaining_sec,
		"stage7_akamu_escape_active": _escape_active,
		"stage7_akamu_escape_progress": clampf(
			_escape_elapsed_sec / ESCAPE_DURATION_SEC,
			0.0,
			1.0
		),
		"stage7_akamu_clones": _clones,
		"stage7_akamu_shurikens": _shurikens,
		"stage7_akamu_afterimages": _afterimages,
		"stage7_akamu_particles": _particles,
		"stage7_akamu_wind_burst_particles": _wind_burst_particles,
		"stage7_akamu_superspeed_afterimages": _superspeed_afterimages,
		"stage7_akamu_superspeed_dark_particles": _superspeed_dark_particles,
		"stage7_akamu_superspeed_trails": _superspeed_trails,
		"stage7_akamu_superspeed_active": _superspeed_active,
		"stage7_akamu_superspeed_remaining": _superspeed_remaining_sec,
		"stage7_akamu_superspeed_duration": SUPERSPEED_DURATION_SEC,
		"stage7_akamu_superspeed_text_remaining": _superspeed_text_remaining_sec,
		"stage7_akamu_superspeed_cooldown_remaining": _superspeed_cooldown_remaining_sec,
		"stage7_akamu_superspeed_dash_active": _superspeed_dash_active,
		"stage7_akamu_superspeed_dash_direction": _superspeed_dash_direction,
		"stage7_akamu_cloud": _cloud_draw_context,
		"stage7_akamu_hologram": _hologram_draw_context,
		"stage7_akamu_aura": _aura_draw_context,
		"stage7_akamu_wind_aura": _wind_aura_draw_context,
	}


func get_hud_context(_stage_background: Object = null, _context: Dictionary = {}) -> Dictionary:
	return {
		"stage7_boss_skill_hud_active": true,
		"stage7_boss_skill_hud_boss_name": BOSS_NAME,
		"stage7_boss_skill_hud_status": status,
		"stage7_boss_skill_hud_gauge": boss_special_gauge,
		"stage7_boss_skill_hud_gauge_max": GAUGE_MAX,
		"stage7_boss_skill_hud_awakened": awakened,
		"stage7_boss_skill_hud_skills": _build_hud_skills(),
	}


func should_skip_ball_motion_step() -> bool:
	return false


func get_status() -> String:
	return status


func _build_hud_skills() -> Array:
	return [
		_build_clone_hud_skill(),
		_build_shuriken_hud_skill(),
		_build_cloud_hud_skill(),
		_build_superspeed_hud_skill(),
	]


func _placeholder_hud_skill(skill_id: String, skill_name: String, color: Color, cost: float, unlocked: bool = true) -> Dictionary:
	return {
		"id": skill_id,
		"name": skill_name,
		"color": color,
		"cost": cost,
		"progress": clampf(boss_special_gauge / maxf(1.0, cost), 0.0, 1.0),
		"cooldown_remaining": 0.0,
		"cooldown_total": 1.0,
		"next_activation_remaining": maxf(0.0, cost - boss_special_gauge),
		"ready": false,
		"active": false,
		"implemented": false,
		"status": "paused" if unlocked else "locked",
	}


func _build_shuriken_hud_skill() -> Dictionary:
	var cooldown_total: float = maxf(0.001, _shuriken_cooldown_total_sec)
	var live_projectiles: bool = not _shurikens.is_empty()
	var skill_paused: bool = _skill_cooldown_paused or status == "paused"
	var cooldown_progress: float = 0.0
	if _shuriken_scheduler_armed:
		cooldown_progress = clampf(1.0 - _shuriken_cooldown_remaining_sec / cooldown_total, 0.0, 1.0)
	var ready: bool = (
		not skill_paused
		and _shuriken_scheduler_armed
		and _shuriken_cooldown_remaining_sec <= 0.0
		and boss_special_gauge >= SHURIKEN_GAUGE_COST
		and not _shuriken_casting
		and not _clone_casting
		and not _has_live_clones()
		and not _cloud_dash_active
		and not _escape_active
		and not _superspeed_active
	)
	var shuriken_status := "charging"
	if live_projectiles:
		shuriken_status = "active"
	elif skill_paused:
		shuriken_status = "paused"
	elif _shuriken_casting:
		shuriken_status = "casting"
	elif ready:
		shuriken_status = "ready"
	return {
		"id": "stage7_shuriken",
		"name": "표창",
		"color": Color(0.72, 0.78, 0.88),
		"cost": SHURIKEN_GAUGE_COST,
		"progress": cooldown_progress,
		"cooldown_remaining": _shuriken_cooldown_remaining_sec,
		"cooldown_total": cooldown_total,
		"next_activation_remaining": maxf(
			_shuriken_cooldown_remaining_sec,
			maxf(0.0, SHURIKEN_GAUGE_COST - boss_special_gauge)
		),
		"ready": ready,
		"active": live_projectiles or (_shuriken_casting and not skill_paused),
		"implemented": true,
		"status": shuriken_status,
	}


func _build_clone_hud_skill() -> Dictionary:
	var live_count: int = _get_live_clone_count()
	var skill_paused: bool = _skill_cooldown_paused or status == "paused"
	var ready: bool = (
		not skill_paused
		and _clone_cooldown_remaining_sec <= 0.0
		and boss_special_gauge >= CLONE_GAUGE_COST
		and not _clone_casting
		and live_count == 0
		and not _shuriken_casting
		and not _cloud_dash_active
		and not _escape_active
		and not _superspeed_active
	)
	var next_activation_remaining: float = maxf(
		_clone_cooldown_remaining_sec,
		maxf(
			_max_live_clone_remaining_sec(),
			maxf(0.0, CLONE_GAUGE_COST - boss_special_gauge)
		)
	)
	var clone_status := "charging"
	if live_count > 0:
		clone_status = "active"
	elif skill_paused:
		clone_status = "paused"
	elif _clone_casting:
		clone_status = "casting"
	elif ready:
		clone_status = "ready"
	return {
		"id": "stage7_clone",
		"name": "그림자분신",
		"color": Color(0.56, 0.48, 0.86),
		"cost": CLONE_GAUGE_COST,
		"progress": clampf(1.0 - _clone_cooldown_remaining_sec / CLONE_COOLDOWN_SEC, 0.0, 1.0),
		"cooldown_remaining": _clone_cooldown_remaining_sec,
		"cooldown_total": CLONE_COOLDOWN_SEC,
		"next_activation_remaining": next_activation_remaining,
		"ready": ready,
		"active": live_count > 0 or (_clone_casting and not skill_paused),
		"active_count": live_count,
		"implemented": true,
		"status": clone_status,
	}


func _build_cloud_hud_skill() -> Dictionary:
	var active: bool = _cloud_dash_active or _cloud_field_active
	var skill_paused: bool = _skill_cooldown_paused or status == "paused"
	var cooldown_total: float = maxf(0.001, _cloud_cooldown_total_sec)
	var ready: bool = (
		not skill_paused
		and _cloud_cooldown_remaining_sec <= 0.0
		and boss_special_gauge >= CLOUD_GAUGE_COST
		and not active
		and not _has_scripted_skill_conflict("cloud")
		and not _superspeed_active
	)
	var cloud_status := "charging"
	if active:
		cloud_status = "active"
	elif skill_paused:
		cloud_status = "paused"
	elif ready:
		cloud_status = "ready"
	var field_remaining: float = (
		maxf(0.0, CLOUD_TOTAL_SEC - _cloud_field_elapsed_sec)
		if _cloud_field_active
		else 0.0
	)
	return {
		"id": "stage7_cloud",
		"name": "구름장막",
		"color": Color(0.42, 0.66, 0.72),
		"cost": CLOUD_GAUGE_COST,
		"progress": clampf(
			1.0 - _cloud_cooldown_remaining_sec / cooldown_total,
			0.0,
			1.0
		),
		"cooldown_remaining": _cloud_cooldown_remaining_sec,
		"cooldown_total": cooldown_total,
		"next_activation_remaining": maxf(
			_cloud_cooldown_remaining_sec,
			maxf(field_remaining, maxf(0.0, CLOUD_GAUGE_COST - boss_special_gauge))
		),
		"ready": ready,
		"active": active,
		"implemented": true,
		"status": cloud_status,
		"phase": _cloud_dash_phase if _cloud_dash_active else ("field" if _cloud_field_active else ""),
	}


func _build_superspeed_hud_skill() -> Dictionary:
	var skill_paused: bool = _skill_cooldown_paused or status == "paused"
	var ready: bool = (
		awakened
		and not skill_paused
		and not _superspeed_active
		and _superspeed_cooldown_remaining_sec <= 0.0
		and boss_special_gauge >= SUPERSPEED_GAUGE_COST
		and not _escape_active
		and not _external_scripted_motion_active
	)
	var superspeed_status := "locked"
	if _superspeed_active:
		superspeed_status = "active"
	elif not awakened:
		superspeed_status = "locked"
	elif skill_paused:
		superspeed_status = "paused"
	elif ready:
		superspeed_status = "ready"
	else:
		superspeed_status = "charging"
	var progress: float = 0.0
	if _superspeed_active:
		progress = clampf(_superspeed_remaining_sec / SUPERSPEED_DURATION_SEC, 0.0, 1.0)
	elif _superspeed_cooldown_remaining_sec > 0.0:
		progress = clampf(
			1.0 - _superspeed_cooldown_remaining_sec / SUPERSPEED_COOLDOWN_SEC,
			0.0,
			1.0
		)
	else:
		progress = clampf(boss_special_gauge / SUPERSPEED_GAUGE_COST, 0.0, 1.0)
	return {
		"id": "stage7_superspeed",
		"name": "극정호신",
		"color": Color(0.96, 0.46, 0.18),
		"cost": SUPERSPEED_GAUGE_COST,
		"progress": progress,
		"cooldown_remaining": _superspeed_cooldown_remaining_sec,
		"cooldown_total": SUPERSPEED_COOLDOWN_SEC,
		"duration_remaining": _superspeed_remaining_sec,
		"duration_total": SUPERSPEED_DURATION_SEC,
		"next_activation_remaining": maxf(
			_superspeed_cooldown_remaining_sec,
			maxf(
				_superspeed_remaining_sec,
				maxf(0.0, SUPERSPEED_GAUGE_COST - boss_special_gauge)
			)
		),
		"ready": ready,
		"active": _superspeed_active,
		"implemented": true,
		"status": superspeed_status,
	}


func _build_result() -> Dictionary:
	# Do not emit a false ownership flag: effects results can be merged with an
	# unrelated ball-owning feature, where `skip_ball_motion_step = false` would
	# silently release that feature's ball. Stage 7 freeze is queried directly.
	if _scripted_motion_active:
		# Odin CC parity during 분신/표창 casting (mythic → BossAI → THIS
		# writer runs last, so an unconditional pin write would erase the CC
		# movement the AI just applied). Python's casting pin block sits BELOW
		# the knockback branch and does not return before the stun branch:
		# - Knockback window: yield position ownership entirely. The pin VALUE
		#   is NOT touched — Python captures it once at cast start and never
		#   refreshes it, so a clone cast that outlives the knockback snaps the
		#   boss back to the original pin for its remaining frames, while a
		#   shuriken cast that ends inside the knockback keeps the full travel.
		# - Stun tail: keep the pin but preserve the AI-applied residual on top
		#   (Python pins first, then the stun branch adds the residual).
		var casting_pin_active: bool = (
			(_clone_casting or _shuriken_casting)
			and not _escape_active
			and not _cloud_dash_active
		)
		if casting_pin_active and _odin_knockback_window_active:
			return {}
		if casting_pin_active and absf(_odin_stun_residual) > 0.0:
			return {
				"boss_pos": _scripted_boss_pos + Vector2(_odin_stun_residual, 0.0),
				"boss_vel": 0.0,
			}
		return {
			"boss_pos": _scripted_boss_pos,
			"boss_vel": 0.0,
		}
	if _boss_position_release_pending:
		return {
			"boss_pos": _boss_position_release_pos,
			"boss_vel": 0.0,
		}
	return {}


func _is_timing_frozen(context: Dictionary) -> bool:
	return not bool(context.get("ball_active", true)) \
		or bool(context.get("waiting_for_serve", false)) \
		or bool(context.get("gameplay_timing_frozen", false)) \
		or bool(context.get("stopwatch_freeze_active", false)) \
		or bool(context.get("active_item_stopwatch_freeze_active", false)) \
		or bool(context.get("perk_resume_freeze_active", false)) \
		or bool(context.get("power_smashing_freeze_active", false)) \
		or bool(context.get("viper_dmk_freeze_active", false)) \
		or bool(context.get("viper_nerve_strike_freeze_active", false))


func _has_runtime_state() -> bool:
	return _has_score_round_generation \
		or boss_special_gauge > 0.0 \
		or awakened \
		or _awakening_trigger_armed \
		or _awakening_intro_pending \
		or _awakening_intro_done \
		or is_gameplay_freeze_active() \
		or _boss_ball_intangible \
		or _scripted_motion_active \
		or _boss_attack_remaining_sec > 0.0 \
		or _superspeed_active \
		or _superspeed_cooldown_remaining_sec > 0.0 \
		or _wind_aura_active \
		or _wind_aura_depleted \
		or _wind_aura_free_clone_queued \
		or _external_scripted_motion_active \
		or _cloud_dash_active \
		or _cloud_cooldown_remaining_sec > 0.0 \
		or _cloud_invuln_buffer_remaining_sec > 0.0 \
		or _cloud_field_active \
		or _escape_active \
		or _escape_episode_active \
		or not _hologram_draw_context.is_empty() \
		or _boss_position_release_pending \
		or _clone_casting \
		or _clone_cooldown_remaining_sec > 0.0 \
		or _clone_invuln_buffer_remaining_sec > 0.0 \
		or _shuriken_scheduler_armed \
		or _shuriken_casting \
		or not _shuriken_pending_remaining.is_empty() \
		or _shuriken_gauge_ticks_left > 0 \
		or not _clones.is_empty() \
		or not _shurikens.is_empty() \
		or not _afterimages.is_empty() \
		or not _particles.is_empty() \
		or not _wind_burst_particles.is_empty() \
		or not _superspeed_afterimages.is_empty() \
		or not _superspeed_dark_particles.is_empty() \
		or not _superspeed_trails.is_empty() \
		or not _cloud_draw_context.is_empty() \
		or not _aura_draw_context.is_empty() \
		or not _wind_aura_draw_context.is_empty()


func debug_set_gauge(value: float) -> void:
	boss_special_gauge = clampf(value, 0.0, GAUGE_MAX)


func debug_get_gauge() -> float:
	return boss_special_gauge


func debug_set_awakened(value: bool) -> void:
	awakened = value


func debug_is_awakened() -> bool:
	return awakened


func debug_begin_gameplay_freeze(duration_sec: float) -> void:
	_gameplay_freeze_remaining_sec = maxf(0.0, duration_sec)
	_gameplay_freeze_reason = "awakening" if _gameplay_freeze_remaining_sec > 0.0 else ""


func debug_set_boss_ball_intangible(value: bool) -> void:
	set_boss_ball_intangible_source("debug", value)


func debug_set_scripted_boss_position(active: bool, pos: Vector2 = Vector2.ZERO) -> void:
	_debug_scripted_motion_active = active
	_debug_scripted_boss_pos = pos if active else Vector2.ZERO
	_refresh_scripted_motion()


func debug_seed_rng(seed_value: int) -> void:
	_rng.seed = seed_value


func debug_set_superspeed_active(value: bool) -> void:
	_superspeed_active = value
	if value:
		_superspeed_remaining_sec = maxf(_superspeed_remaining_sec, SUPERSPEED_DURATION_SEC)
	else:
		_superspeed_remaining_sec = 0.0
		_superspeed_text_remaining_sec = 0.0
		_superspeed_dash_active = false


func debug_force_complete_awakening(
	boss_pos: Vector2 = Vector2(330.0, 25.0),
	boss_size: Vector2 = Vector2(100.0, 40.0)
) -> void:
	_last_boss_pos = boss_pos
	_last_boss_size = boss_size
	_awakening_trigger_armed = true
	_awakening_intro_pending = true
	_complete_awakening()


func debug_get_wind_aura_snapshot() -> Dictionary:
	return {
		"active": _wind_aura_active,
		"hit_count": _wind_aura_hit_count,
		"max_hits": WIND_AURA_MAX_HITS,
		"depleted": _wind_aura_depleted,
		"recharge_remaining_sec": _wind_aura_recharge_remaining_sec,
		"hit_cooldown_remaining_sec": _wind_aura_hit_cooldown_remaining_sec,
		"ripple_remaining_sec": _wind_aura_ripple_remaining_sec,
		"free_clone_queued": _wind_aura_free_clone_queued,
		"particle_count": _wind_aura_particles.size(),
		"burst_particle_count": _wind_burst_particles.size(),
	}


func debug_clear_wind_aura_hit_cooldown() -> void:
	_wind_aura_hit_cooldown_remaining_sec = 0.0


func debug_start_superspeed(context: Dictionary) -> bool:
	return _try_start_superspeed(context)


func debug_set_superspeed_cooldown_remaining(value: float) -> void:
	_superspeed_cooldown_remaining_sec = maxf(0.0, value)


func debug_get_superspeed_snapshot() -> Dictionary:
	return {
		"active": _superspeed_active,
		"remaining_sec": _superspeed_remaining_sec,
		"text_remaining_sec": _superspeed_text_remaining_sec,
		"cooldown_remaining_sec": _superspeed_cooldown_remaining_sec,
		"dash_active": _superspeed_dash_active,
		"dash_direction": _superspeed_dash_direction,
		"dash_target_center_x": _superspeed_dash_target_center_x,
		"afterimage_count": _superspeed_afterimages.size(),
		"dark_particle_count": _superspeed_dark_particles.size(),
		"trail_count": _superspeed_trails.size(),
	}


func debug_start_clone_cast(
	context: Dictionary,
	free_cast: bool = false,
	bypass_cooldown: bool = false
) -> bool:
	return _try_start_clone_cast(context, true, free_cast, "debug", bypass_cooldown)


func debug_spawn_shadow_clones(center: Vector2, awakened_override: bool = false) -> void:
	_spawn_shadow_clones(center, awakened_override)
	_clone_cooldown_remaining_sec = CLONE_COOLDOWN_SEC


func debug_set_clone_cooldown_remaining(value: float) -> void:
	_clone_cooldown_remaining_sec = maxf(0.0, value)


func debug_get_clone_snapshot() -> Dictionary:
	return {
		"trigger_chance": CLONE_TRIGGER_CHANCE,
		"casting": _clone_casting,
		"cast_elapsed_sec": _clone_cast_elapsed_sec,
		"cast_free": _clone_cast_free,
		"cast_source": _clone_cast_source,
		"cooldown_remaining_sec": _clone_cooldown_remaining_sec,
		"invuln_buffer_remaining_sec": _clone_invuln_buffer_remaining_sec,
		"live_count": _get_live_clone_count(),
		"dying_count": _get_dying_clone_count(),
		"entity_count": _clones.size(),
	}


func debug_set_shuriken_cooldown_remaining(value: float, total: float = -1.0) -> void:
	_shuriken_scheduler_armed = true
	_shuriken_cooldown_remaining_sec = maxf(0.0, value)
	_shuriken_cooldown_total_sec = maxf(
		0.001,
		total if total >= 0.0 else maxf(value, float(SHURIKEN_COOLDOWN_MIN_MSEC) / 1000.0)
	)


func debug_spawn_shuriken(origin: Vector2, target: Vector2, from_pending: bool = false) -> void:
	_append_shuriken(origin, target, from_pending)


func debug_get_shuriken_snapshot() -> Dictionary:
	return {
		"scheduler_armed": _shuriken_scheduler_armed,
		"casting": _shuriken_casting,
		"cast_elapsed_sec": _shuriken_cast_elapsed_sec,
		"cooldown_remaining_sec": _shuriken_cooldown_remaining_sec,
		"cooldown_total_sec": _shuriken_cooldown_total_sec,
		"pending_count": _shuriken_pending_remaining.size(),
		"projectile_count": _shurikens.size(),
		"gauge_ticks_left": _shuriken_gauge_ticks_left,
		"gauge_tick_frames_remaining": _shuriken_gauge_tick_frames_remaining,
	}


func debug_start_cloud(
	context: Dictionary,
	deps: Dictionary = {},
	free_cast: bool = false,
	bypass_cooldown: bool = true
) -> bool:
	return _try_start_cloud(context, deps, true, free_cast, "debug", bypass_cooldown)


func debug_set_cloud_cooldown_remaining(value: float, total: float = -1.0) -> void:
	_cloud_cooldown_remaining_sec = maxf(0.0, value)
	_cloud_cooldown_total_sec = maxf(
		0.001,
		total if total >= 0.0 else maxf(value, CLOUD_COOLDOWN_MIN_SEC)
	)


func debug_get_cloud_snapshot() -> Dictionary:
	return {
		"trigger_chance": CLOUD_TRIGGER_CHANCE,
		"dash_active": _cloud_dash_active,
		"phase": _cloud_dash_phase,
		"phase_elapsed_sec": _cloud_phase_elapsed_sec,
		"phase_progress": _get_cloud_phase_progress(),
		"boss_pos": _get_cloud_boss_pos() if _cloud_dash_active else _cloud_home_boss_pos,
		"origin_boss_pos": _cloud_origin_boss_pos,
		"target_boss_pos": _cloud_target_boss_pos,
		"home_boss_pos": _cloud_home_boss_pos,
		"cooldown_remaining_sec": _cloud_cooldown_remaining_sec,
		"cooldown_total_sec": _cloud_cooldown_total_sec,
		"invuln_buffer_remaining_sec": _cloud_invuln_buffer_remaining_sec,
		"field_active": _cloud_field_active,
		"field_elapsed_sec": _cloud_field_elapsed_sec,
		"field_center": _cloud_field_center,
		"field_alpha": _get_cloud_field_alpha(),
	}


func debug_start_escape(
	context: Dictionary,
	deps: Dictionary = {},
	stun_remaining_sec: float = 0.0,
	free_cast: bool = true
) -> bool:
	return _start_escape(context, deps, {
		"stun_active": stun_remaining_sec > 0.0,
		"stun_remaining_sec": maxf(0.0, stun_remaining_sec),
		"net_trapped": false,
		"net_count": 0,
	}, free_cast)


func debug_get_escape_snapshot() -> Dictionary:
	return {
		"trigger_chance": ESCAPE_TRIGGER_CHANCE,
		"active": _escape_active,
		"elapsed_sec": _escape_elapsed_sec,
		"progress": clampf(_escape_elapsed_sec / ESCAPE_DURATION_SEC, 0.0, 1.0),
		"start_boss_pos": _escape_start_boss_pos,
		"target_boss_pos": _escape_target_boss_pos,
		"boss_pos": _get_escape_boss_pos(),
		"visual_scale": _escape_visual_scale,
		"episode_active": _escape_episode_active,
		"attempted": _escape_attempted,
		"ready_remaining_sec": _escape_ready_remaining_sec,
		"released_net_count": _escape_last_released_net_count,
		"afterimage_count": _afterimages.size(),
		"hologram_active": not _hologram_draw_context.is_empty(),
		"hologram": _hologram_draw_context.duplicate(true),
	}


func _try_start_cloud(
	context: Dictionary,
	_deps: Dictionary,
	force_roll: bool,
	free_cast: bool,
	source: String,
	bypass_cooldown: bool = false
) -> bool:
	if (
		_cloud_dash_active
		or _cloud_field_active
		or _superspeed_active
		or _has_scripted_skill_conflict("cloud")
		or bool(context.get("lingpet_puppet_grab_active", false))
		or (not bypass_cooldown and _cloud_cooldown_remaining_sec > 0.0)
		or (not free_cast and boss_special_gauge < CLOUD_GAUGE_COST)
	):
		return false
	if not force_roll and _rng.randf() > CLOUD_TRIGGER_CHANCE:
		return false

	var boss_pos: Vector2 = _as_vector2(
		context.get("boss_pos", Vector2(330.0, 25.0)),
		Vector2(330.0, 25.0)
	)
	var boss_size: Vector2 = _as_vector2(
		context.get("boss_paddle_size", Vector2(
			float(context.get("boss_paddle_width", 100.0)),
			float(context.get("boss_hitbox_height", 40.0))
		)),
		Vector2(100.0, 40.0)
	)
	var player_rect: Rect2 = _get_player_rect(context)
	var field_width: float = float(context.get("width", FIELD_WIDTH))
	var field_height: float = float(context.get("height", FIELD_HEIGHT))
	var center_x: float = field_width * 0.5
	var origin_center_y: float = boss_pos.y + boss_size.y * 0.5
	var target_center_y: float = maxf(origin_center_y, player_rect.get_center().y - 40.0)
	target_center_y = minf(field_height - boss_size.y * 0.5, target_center_y)

	_cloud_boss_size = boss_size
	_cloud_origin_boss_pos = Vector2(center_x - boss_size.x * 0.5, boss_pos.y)
	_cloud_home_boss_pos = _cloud_origin_boss_pos
	_cloud_target_boss_pos = Vector2(
		center_x - boss_size.x * 0.5,
		target_center_y - boss_size.y * 0.5
	)
	_cloud_dash_active = true
	_cloud_dash_phase = "pre"
	_cloud_phase_elapsed_sec = 0.0
	_cloud_invuln_buffer_remaining_sec = 0.0
	_cloud_cooldown_total_sec = float(_rng.randi_range(
		int(CLOUD_COOLDOWN_MIN_SEC * 1000.0),
		int(CLOUD_COOLDOWN_MAX_SEC * 1000.0)
	)) / 1000.0
	_cloud_cooldown_remaining_sec = _cloud_cooldown_total_sec
	_cloud_draw_context.clear()
	_sync_cloud_precast_aura()
	if not free_cast:
		boss_special_gauge = maxf(0.0, boss_special_gauge - CLOUD_GAUGE_COST)
	set_boss_ball_intangible_source(CLOUD_INTANGIBLE_SOURCE, true)
	_refresh_scripted_motion()
	_trigger_boss_attack("cloud_" + source, center_x)
	return true


func _update_cloud(delta: float, deps: Dictionary) -> void:
	_update_cloud_field(delta)
	if not _cloud_dash_active:
		if _cloud_invuln_buffer_remaining_sec > 0.0:
			_cloud_invuln_buffer_remaining_sec = maxf(
				0.0,
				_cloud_invuln_buffer_remaining_sec - delta
			)
			if _cloud_invuln_buffer_remaining_sec <= 0.000001:
				_cloud_invuln_buffer_remaining_sec = 0.0
				set_boss_ball_intangible_source(CLOUD_INTANGIBLE_SOURCE, false)
		return

	_cloud_phase_elapsed_sec += delta
	# 원본 파리티: 차크라 집중 오라는 pre뿐 아니라 down/up 대시 중에도 보스
	# 현재 위치를 따라간다 (draw_stage8_cloud의 pre/down/up 분기).
	_sync_cloud_precast_aura()
	match _cloud_dash_phase:
		"pre":
			if _cloud_phase_elapsed_sec + 0.000001 >= CLOUD_PRECAST_SEC:
				_cloud_dash_phase = "down"
				_cloud_phase_elapsed_sec = 0.0
		"down":
			if _cloud_phase_elapsed_sec + 0.000001 >= CLOUD_DASH_SEC:
				_cloud_phase_elapsed_sec = 0.0
				_cloud_dash_phase = "up"
				_start_cloud_field(deps)
		"up":
			if _cloud_phase_elapsed_sec + 0.000001 >= CLOUD_DASH_SEC:
				_cloud_phase_elapsed_sec = 0.0
				_cloud_dash_active = false
				_cloud_dash_phase = ""
				_cloud_invuln_buffer_remaining_sec = CLOUD_INVULN_BUFFER_SEC
				_boss_position_release_pending = true
				_boss_position_release_pos = _cloud_home_boss_pos
				_aura_draw_context.clear()
	_refresh_scripted_motion()


func _start_cloud_field(deps: Dictionary) -> void:
	_cloud_field_active = true
	_cloud_field_elapsed_sec = 0.0
	_cloud_field_center = _cloud_target_boss_pos + _cloud_boss_size * 0.5 \
		+ Vector2(0.0, CLOUD_SPAWN_Y_OFFSET)
	_sync_cloud_draw_context()
	var audio: Object = deps.get("audio", null)
	# Exact legacy ninjacloud.wav cue at the landing commit. smokebomb.wav is a
	# separate shared item cue and must never substitute for this boundary.
	if audio != null and audio.has_method("play_stage7_akamu_cloud"):
		audio.play_stage7_akamu_cloud()


func _update_cloud_field(delta: float) -> void:
	if not _cloud_field_active:
		return
	_cloud_field_elapsed_sec += delta
	if _cloud_field_elapsed_sec + 0.000001 >= CLOUD_TOTAL_SEC:
		_cloud_field_active = false
		_cloud_field_elapsed_sec = 0.0
		_cloud_field_center = Vector2.ZERO
		_cloud_draw_context.clear()
		return
	_sync_cloud_draw_context()


func _sync_cloud_draw_context() -> void:
	if not _cloud_field_active:
		_cloud_draw_context.clear()
		return
	_cloud_draw_context = {
		"active": true,
		"center": _cloud_field_center,
		"logical_size": CLOUD_LOGICAL_SIZE,
		"alpha": _get_cloud_field_alpha(),
		"expand_progress": clampf(_cloud_field_elapsed_sec / CLOUD_EXPAND_SEC, 0.0, 1.0),
		"elapsed_sec": _cloud_field_elapsed_sec,
	}


func _sync_cloud_precast_aura() -> void:
	if not _cloud_dash_active or not (_cloud_dash_phase in ["pre", "down", "up"]):
		_aura_draw_context.clear()
		return
	var progress: float = _get_cloud_phase_progress()
	# 펄스 클록: pre→down→up 연속 시간(원본 now*0.025 진동의 delta 환산).
	var pulse_sec: float = _cloud_phase_elapsed_sec
	match _cloud_dash_phase:
		"down":
			pulse_sec += CLOUD_PRECAST_SEC
		"up":
			pulse_sec += CLOUD_PRECAST_SEC + CLOUD_DASH_SEC
	_aura_draw_context = {
		"active": true,
		"kind": "cloud_precast",
		"center": _get_cloud_boss_pos() + _cloud_boss_size * 0.5,
		"radius": 54.0 + 18.0 * progress,
		"alpha": 0.34 + 0.30 * progress,
		"progress": progress,
		"pulse_sec": pulse_sec,
	}


func _get_cloud_field_alpha() -> float:
	if not _cloud_field_active:
		return 0.0
	var elapsed: float = _cloud_field_elapsed_sec
	if elapsed <= CLOUD_SOLID_SEC:
		return 1.0
	if elapsed <= CLOUD_VISIBLE_SEC:
		return lerpf(
			1.0,
			CLOUD_SEMI_ALPHA,
			(elapsed - CLOUD_SOLID_SEC) / CLOUD_FADE_TO_SEMI_SEC
		)
	var final_fade_start: float = CLOUD_VISIBLE_SEC + CLOUD_EXPAND_SEC
	if elapsed <= final_fade_start:
		return CLOUD_SEMI_ALPHA
	return CLOUD_SEMI_ALPHA * clampf(
		1.0 - (elapsed - final_fade_start) / CLOUD_FINAL_FADE_SEC,
		0.0,
		1.0
	)


func _get_cloud_phase_progress() -> float:
	match _cloud_dash_phase:
		"pre":
			return clampf(_cloud_phase_elapsed_sec / CLOUD_PRECAST_SEC, 0.0, 1.0)
		"down", "up":
			return clampf(_cloud_phase_elapsed_sec / CLOUD_DASH_SEC, 0.0, 1.0)
	return 0.0


func _get_cloud_boss_pos() -> Vector2:
	match _cloud_dash_phase:
		"pre":
			return _cloud_origin_boss_pos
		"down":
			return _cloud_origin_boss_pos.lerp(
				_cloud_target_boss_pos,
				_get_cloud_phase_progress()
			)
		"up":
			return _cloud_target_boss_pos.lerp(
				_cloud_home_boss_pos,
				_get_cloud_phase_progress()
			)
	return _cloud_home_boss_pos


func _update_escape_trigger(delta: float, context: Dictionary, deps: Dictionary) -> void:
	if _escape_active:
		return
	var disable_context: Dictionary = _get_escape_disable_context(deps)
	var stun_active: bool = bool(disable_context.get("stun_active", false))
	var net_trapped: bool = bool(disable_context.get("net_trapped", false))
	if not stun_active and not net_trapped:
		_escape_episode_active = false
		_escape_attempted = false
		_escape_ready_remaining_sec = 0.0
		return
	if not _escape_episode_active:
		_escape_episode_active = true
		_escape_attempted = false
		_escape_ready_remaining_sec = ESCAPE_NET_DELAY_SEC if net_trapped and not stun_active else 0.0
	elif _escape_ready_remaining_sec > 0.0:
		_escape_ready_remaining_sec = maxf(0.0, _escape_ready_remaining_sec - delta)
	if _escape_ready_remaining_sec > 0.000001 or _escape_attempted:
		return
	if (
		boss_special_gauge < ESCAPE_GAUGE_COST
		or _superspeed_active
		or _has_scripted_skill_conflict("escape")
		or bool(context.get("lingpet_puppet_grab_active", false))
	):
		return
	_escape_attempted = true
	if _rng.randf() > ESCAPE_TRIGGER_CHANCE:
		return
	_start_escape(context, deps, disable_context, false)


func _get_escape_disable_context(deps: Dictionary) -> Dictionary:
	var stun_active := false
	var stun_remaining_frames := 0.0
	var status_state: Object = deps.get("status_effect_state", null)
	if status_state != null and status_state.has_method("get_status"):
		var status_stun: Variant = status_state.get_status("boss", "stun")
		if status_stun is Dictionary and not (status_stun as Dictionary).is_empty():
			stun_active = true
			stun_remaining_frames = maxf(
				stun_remaining_frames,
				float((status_stun as Dictionary).get("remaining_frames", 0.0))
			)
	for runtime_key in ["active_item_runtime", "mythic_item_runtime"]:
		var runtime: Object = deps.get(runtime_key, null)
		if runtime == null or not runtime.has_method("get_boss_disable_context"):
			continue
		var runtime_context: Variant = runtime.get_boss_disable_context()
		if runtime_context is Dictionary and bool((runtime_context as Dictionary).get("stun_active", false)):
			stun_active = true
			stun_remaining_frames = maxf(
				stun_remaining_frames,
				float((runtime_context as Dictionary).get("stun_remaining_frames", 0.0))
			)
	var net_count := 0
	var commando_runtime: Object = deps.get("commando_firearm_runtime", null)
	if commando_runtime != null and commando_runtime.has_method("get_boss_net_trap_context"):
		var net_context: Variant = commando_runtime.get_boss_net_trap_context()
		if net_context is Dictionary:
			net_count = max(0, int((net_context as Dictionary).get(
				"trapped_count",
				(net_context as Dictionary).get("count", 0)
			)))
			if bool((net_context as Dictionary).get("boss_trapped", false)):
				net_count = maxi(1, net_count)
	return {
		"stun_active": stun_active,
		"stun_remaining_sec": stun_remaining_frames / LEGACY_FPS,
		"net_trapped": net_count > 0,
		"net_count": net_count,
	}


func _start_escape(
	context: Dictionary,
	deps: Dictionary,
	disable_context: Dictionary,
	free_cast: bool
) -> bool:
	if (
		_escape_active
		or _superspeed_active
		or _has_scripted_skill_conflict("escape")
		or bool(context.get("lingpet_puppet_grab_active", false))
		or (not free_cast and boss_special_gauge < ESCAPE_GAUGE_COST)
	):
		return false
	var boss_pos: Vector2 = _as_vector2(
		context.get("boss_pos", Vector2(330.0, 25.0)),
		Vector2(330.0, 25.0)
	)
	# Python attempts the escape INSIDE the knockback branch BEFORE the
	# movement applies (pingfighter.py:178180), but this trigger runs in the
	# effects phase AFTER the boss AI already applied this frame's knockback —
	# rewind it so a successful escape starts from the pre-knockback position.
	if _odin_knockback_window_active:
		boss_pos.x -= _odin_knockback_vel
	var boss_size: Vector2 = _as_vector2(
		context.get("boss_paddle_size", Vector2(
			float(context.get("boss_paddle_width", 100.0)),
			float(context.get("boss_hitbox_height", 40.0))
		)),
		Vector2(100.0, 40.0)
	)
	var ball_pos: Vector2 = _as_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	# Godot's shared ball_pos is already the ball center (unlike paddle pos,
	# which is top-left). Compare center-to-center exactly as the legacy Rect did.
	var ball_center_x: float = ball_pos.x
	var boss_center_x: float = boss_pos.x + boss_size.x * 0.5
	var play_left: float = float(context.get("play_left", 0.0))
	var play_right: float = float(context.get("play_right", context.get("width", FIELD_WIDTH)))
	var left_space: float = maxf(0.0, boss_pos.x - play_left)
	var right_space: float = maxf(0.0, play_right - (boss_pos.x + boss_size.x))
	var direction := -1.0 if ball_center_x >= boss_center_x else 1.0
	var chosen_space: float = left_space if direction < 0.0 else right_space
	if chosen_space < ESCAPE_SIDE_MIN_SPACE:
		direction = -1.0 if left_space > right_space else 1.0
		chosen_space = left_space if direction < 0.0 else right_space
	var distance: float = (
		minf(ESCAPE_MAX_DISTANCE, chosen_space - ESCAPE_WALL_MARGIN)
		if chosen_space > ESCAPE_WALL_MARGIN * 2.0
		else chosen_space
	)
	if distance < ESCAPE_SIDE_MIN_SPACE:
		distance = maxf(ESCAPE_FALLBACK_MIN_DISTANCE, chosen_space * 0.7)
	var target_x: float = clampf(
		boss_pos.x + direction * distance,
		play_left,
		play_right - boss_size.x
	)

	_escape_active = true
	_escape_elapsed_sec = 0.0
	_escape_start_boss_pos = boss_pos
	_escape_target_boss_pos = Vector2(target_x, boss_pos.y)
	_escape_boss_size = boss_size
	# Capture the launch-time dwarf-magic scale. Ghosts and the fixed hologram
	# must not pop back to full size if that external buff expires mid-escape.
	_escape_visual_scale = clampf(
		float(context.get("boss_paddle_shrink_scale", 1.0)),
		0.2,
		1.0
	)
	_escape_episode_active = true
	_escape_attempted = true
	_escape_ready_remaining_sec = 0.0
	var stun_remaining_sec: float = maxf(
		0.0,
		float(disable_context.get("stun_remaining_sec", 0.0))
	)
	var hologram_total_sec: float = stun_remaining_sec + ESCAPE_HOLOGRAM_FADE_SEC
	_hologram_draw_context = {
		"active": true,
		"center": boss_pos + boss_size * 0.5,
		"size": boss_size,
		"visual_scale": _escape_visual_scale,
		"alpha": 180.0 / 255.0,
		"remaining_sec": hologram_total_sec,
		"total_sec": hologram_total_sec,
	}
	_refresh_escape_afterimages()
	_escape_last_released_net_count = _clear_escape_disable_effects(deps)
	if not free_cast:
		boss_special_gauge = maxf(0.0, boss_special_gauge - ESCAPE_GAUGE_COST)
	set_boss_ball_intangible_source(ESCAPE_INTANGIBLE_SOURCE, true)
	_refresh_scripted_motion()
	_trigger_boss_attack("escape", _escape_target_boss_pos.x + boss_size.x * 0.5)
	return true


func _clear_escape_disable_effects(deps: Dictionary) -> int:
	var status_state: Object = deps.get("status_effect_state", null)
	if status_state != null and status_state.has_method("clear_status"):
		status_state.clear_status("boss", "stun")
	var active_runtime: Object = deps.get("active_item_runtime", null)
	if active_runtime != null and active_runtime.has_method("clear_boss_disable_effects"):
		active_runtime.clear_boss_disable_effects()
	var mythic_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_runtime != null and mythic_runtime.has_method("clear_boss_disable_effects_for_escape"):
		# Escape-specific clear (Python 영체탈주 parity): the Odin stun and its
		# residual velocity are consumed, but the knockback WINDOW is preserved
		# and stays frozen behind the escape.
		mythic_runtime.clear_boss_disable_effects_for_escape(deps.get("registry", null))
	elif mythic_runtime != null and mythic_runtime.has_method("clear_boss_disable_effects"):
		mythic_runtime.clear_boss_disable_effects(deps.get("registry", null))
	var commando_runtime: Object = deps.get("commando_firearm_runtime", null)
	if commando_runtime != null and commando_runtime.has_method("release_boss_net_traps"):
		return max(0, int(commando_runtime.release_boss_net_traps()))
	return 0


func _update_escape_motion(delta: float) -> void:
	if not _escape_active:
		return
	_escape_elapsed_sec = minf(ESCAPE_DURATION_SEC, _escape_elapsed_sec + delta)
	_refresh_escape_afterimages()
	_refresh_scripted_motion()
	if _escape_elapsed_sec + 0.000001 < ESCAPE_DURATION_SEC:
		return
	_escape_active = false
	_escape_elapsed_sec = ESCAPE_DURATION_SEC
	_afterimages.clear()
	_boss_position_release_pending = true
	_boss_position_release_pos = _escape_target_boss_pos
	_escape_episode_active = false
	_escape_attempted = false
	_escape_ready_remaining_sec = 0.0
	set_boss_ball_intangible_source(ESCAPE_INTANGIBLE_SOURCE, false)
	_refresh_scripted_motion()


func _get_escape_boss_pos() -> Vector2:
	var progress: float = clampf(_escape_elapsed_sec / ESCAPE_DURATION_SEC, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - progress, 2.0)
	return _escape_start_boss_pos.lerp(_escape_target_boss_pos, eased)


func _refresh_escape_afterimages() -> void:
	_afterimages.clear()
	if not _escape_active:
		return
	for index in range(ESCAPE_GHOST_COUNT):
		var delay_sec: float = float(index) * ESCAPE_GHOST_DELAY_SEC
		var local_elapsed: float = _escape_elapsed_sec - delay_sec
		if local_elapsed < 0.0:
			continue
		var duration_sec: float = maxf(0.001, ESCAPE_DURATION_SEC - delay_sec)
		var progress: float = clampf(local_elapsed / duration_sec, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - progress, 2.0)
		var alpha: float = float(255 - index * 40) / 255.0
		if progress > 0.70:
			alpha *= clampf((1.0 - progress) / 0.30, 0.0, 1.0)
		var ghost_pos: Vector2 = _escape_start_boss_pos.lerp(_escape_target_boss_pos, eased)
		_afterimages.append({
			"kind": "escape",
			"index": index,
			"center": ghost_pos + _escape_boss_size * 0.5,
			"size": _escape_boss_size,
			"visual_scale": _escape_visual_scale,
			"alpha": alpha,
			"progress": progress,
		})


func _update_hologram(delta: float) -> void:
	if _hologram_draw_context.is_empty():
		return
	var remaining_sec: float = maxf(
		0.0,
		float(_hologram_draw_context.get("remaining_sec", 0.0)) - delta
	)
	if remaining_sec <= 0.000001:
		_hologram_draw_context.clear()
		return
	_hologram_draw_context["remaining_sec"] = remaining_sec
	var fade_ratio: float = 1.0
	if remaining_sec <= ESCAPE_HOLOGRAM_FADE_SEC:
		fade_ratio = remaining_sec / ESCAPE_HOLOGRAM_FADE_SEC
	_hologram_draw_context["alpha"] = (180.0 / 255.0) * clampf(fade_ratio, 0.0, 1.0)


func _has_scripted_skill_conflict(requester: String) -> bool:
	if _external_scripted_motion_active or _boss_position_release_pending:
		return true
	if requester != "escape" and _escape_active:
		return true
	if requester != "cloud" and _cloud_dash_active:
		return true
	if requester != "superspeed" and _superspeed_active:
		return true
	if requester != "clone" and _clone_casting:
		return true
	if requester != "shuriken" and _shuriken_casting:
		return true
	return _debug_scripted_motion_active


func _try_start_clone_cast(
	context: Dictionary,
	force_roll: bool,
	free_cast: bool,
	source: String,
	bypass_cooldown: bool = false
) -> bool:
	if (
		_clone_casting
		or _has_live_clones()
		or _superspeed_active
		or _shuriken_casting
		or _cloud_dash_active
		or _escape_active
		or _external_scripted_motion_active
		or bool(context.get("lingpet_puppet_grab_active", false))
		or (not bypass_cooldown and _clone_cooldown_remaining_sec > 0.0)
		or (not free_cast and boss_special_gauge < CLONE_GAUGE_COST)
	):
		return false
	if not force_roll and _rng.randf() > CLONE_TRIGGER_CHANCE:
		return false
	var boss_pos: Vector2 = _as_vector2(
		context.get("boss_pos", Vector2(330.0, 25.0)),
		Vector2(330.0, 25.0)
	)
	var boss_size: Vector2 = _as_vector2(
		context.get("boss_paddle_size", Vector2(
			float(context.get("boss_paddle_width", 100.0)),
			float(context.get("boss_hitbox_height", 40.0))
		)),
		Vector2(100.0, 40.0)
	)
	_clone_casting = true
	_clone_cast_elapsed_sec = 0.0
	_clone_cast_boss_pos = boss_pos
	_clone_cast_boss_center = boss_pos + boss_size * 0.5
	_clone_cast_free = free_cast
	_clone_cast_source = source
	_clone_invuln_buffer_remaining_sec = 0.0
	_refresh_scripted_motion()
	_refresh_boss_ball_intangible()
	return true


func _update_clone_cast(delta: float, deps: Dictionary) -> void:
	_clone_cast_elapsed_sec += delta
	if _clone_cast_elapsed_sec + 0.000001 < CLONE_CAST_SEC:
		return
	# Legacy spawned for free when an external drain pushed gauge below 100
	# during the cast. Revalidate at commit so a paid cast is transactional.
	if not _clone_cast_free and boss_special_gauge < CLONE_GAUGE_COST:
		_cancel_clone_cast()
		return
	if not _clone_cast_free:
		boss_special_gauge = maxf(0.0, boss_special_gauge - CLONE_GAUGE_COST)
	var spawn_center: Vector2 = _clone_cast_boss_center
	var spawn_awakened: bool = awakened
	_clone_casting = false
	_clone_cast_elapsed_sec = 0.0
	_clone_cast_boss_pos = Vector2.ZERO
	_clone_cast_boss_center = Vector2.ZERO
	_clone_cast_free = false
	_clone_cast_source = ""
	_spawn_shadow_clones(spawn_center, spawn_awakened)
	_play_stage7_audio(deps, &"play_stage7_akamu_clone_spawn")
	_clone_cooldown_remaining_sec = CLONE_COOLDOWN_SEC
	_clone_invuln_buffer_remaining_sec = CLONE_INVULN_BUFFER_SEC
	_refresh_scripted_motion()
	_refresh_boss_ball_intangible()


func _cancel_clone_cast() -> void:
	_clone_casting = false
	_clone_cast_elapsed_sec = 0.0
	_clone_cast_boss_pos = Vector2.ZERO
	_clone_cast_boss_center = Vector2.ZERO
	_clone_cast_free = false
	_clone_cast_source = ""
	_clone_invuln_buffer_remaining_sec = 0.0
	_refresh_scripted_motion()
	_refresh_boss_ball_intangible()


func _spawn_shadow_clones(center: Vector2, spawn_awakened: bool) -> void:
	var offsets: Array = (
		[-120.0, -60.0, 60.0, 120.0]
		if spawn_awakened
		else [-90.0, 90.0]
	)
	while _clones.size() + offsets.size() > CLONE_MAX_ENTITIES:
		var removable_index := -1
		for index in range(_clones.size()):
			if str((_clones[index] as Dictionary).get("phase", "")) == "dying":
				removable_index = index
				break
		if removable_index < 0:
			break
		_clones.remove_at(removable_index)
	for offset in offsets:
		if _clones.size() >= CLONE_MAX_ENTITIES:
			break
		var direction: float = -1.0 if offset < 0.0 else 1.0
		var clone_id: int = _clone_next_id
		_clone_next_id += 1
		_clones.append({
			"id": clone_id,
			"center": center,
			"spawn_center": center,
			"size": CLONE_SIZE,
			"offset_x": offset,
			"direction": direction,
			"velocity_x": _rng.randf_range(
				CLONE_INITIAL_SPEED_MIN_PER_FRAME,
				CLONE_INITIAL_SPEED_MAX_PER_FRAME
			) * direction,
			"motion_noise_state": _rng.randi_range(1, 2147483646),
			"motion_frame_accumulator": 0.0,
			"age_sec": 0.0,
			"death_elapsed_sec": 0.0,
			"phase": "emerging",
			"emerge_progress": 0.0,
			"death_progress": 0.0,
			"alpha": 0.0,
			"hop_offset": 0.0,
		})


func _update_shadow_clones(frame_scale: float, delta: float, deps: Dictionary) -> void:
	if _clones.is_empty():
		return
	var write_index := 0
	for read_index in range(_clones.size()):
		var clone: Dictionary = _clones[read_index]
		if str(clone.get("phase", "")) == "dying":
			var death_elapsed: float = float(clone.get("death_elapsed_sec", 0.0)) + delta
			if death_elapsed >= CLONE_DEATH_SEC:
				continue
			var death_progress: float = clampf(death_elapsed / CLONE_DEATH_SEC, 0.0, 1.0)
			clone["death_elapsed_sec"] = death_elapsed
			clone["death_progress"] = death_progress
			clone["alpha"] = 0.78 * (1.0 - death_progress)
			_clones[write_index] = clone
			write_index += 1
			continue

		var previous_age: float = float(clone.get("age_sec", 0.0))
		var age: float = previous_age + delta
		if age >= CLONE_DURATION_SEC:
			# Source parity: natural expiry uses its final 1.5s alpha fade, then
			# disappears immediately. Each expired clone emits the same out cue as
			# the legacy loop. Only ball hits enter the 0.7s dying phase.
			_play_stage7_audio(deps, &"play_stage7_akamu_clone_out")
			continue
		clone["age_sec"] = age
		var emerge_progress: float = clampf(age / CLONE_EMERGE_SEC, 0.0, 1.0)
		clone["emerge_progress"] = emerge_progress
		var spawn_center: Vector2 = _as_vector2(clone.get("spawn_center", Vector2.ZERO), Vector2.ZERO)
		var offset_x: float = float(clone.get("offset_x", 0.0))
		if age < CLONE_EMERGE_SEC:
			clone["phase"] = "emerging"
			clone["center"] = spawn_center + Vector2(offset_x * emerge_progress, 0.0)
		else:
			clone["phase"] = "active"
			if previous_age < CLONE_EMERGE_SEC:
				clone["center"] = spawn_center + Vector2(offset_x, 0.0)
			var active_frames: float = (
				frame_scale
				if previous_age >= CLONE_EMERGE_SEC
				else maxf(0.0, age - CLONE_EMERGE_SEC) * LEGACY_FPS
			)
			var accumulator: float = float(clone.get("motion_frame_accumulator", 0.0)) + active_frames
			while accumulator + 0.000001 >= 1.0:
				_advance_clone_motion_tick(clone)
				accumulator -= 1.0
			clone["motion_frame_accumulator"] = maxf(0.0, accumulator)
		var remaining: float = CLONE_DURATION_SEC - age
		var fade: float = clampf(remaining / CLONE_FADE_SEC, 0.0, 1.0)
		clone["alpha"] = 0.78 * emerge_progress * fade
		clone["hop_offset"] = sin(age * 12.0 + float(int(clone.get("id", 0))) * 0.37) * 6.0
		_clones[write_index] = clone
		write_index += 1
	if write_index < _clones.size():
		_clones.resize(write_index)


func _advance_clone_motion_tick(clone: Dictionary) -> void:
	var center: Vector2 = _as_vector2(clone.get("center", Vector2.ZERO), Vector2.ZERO)
	var size: Vector2 = _as_vector2(clone.get("size", CLONE_SIZE), CLONE_SIZE)
	var velocity_x: float = float(clone.get("velocity_x", 0.0))
	center.x += velocity_x
	var min_center_x: float = CLONE_WALL_MARGIN + size.x * 0.5
	var max_center_x: float = FIELD_WIDTH - CLONE_WALL_MARGIN - size.x * 0.5
	if center.x < min_center_x:
		center.x = min_center_x
		velocity_x = absf(velocity_x)
	elif center.x > max_center_x:
		center.x = max_center_x
		velocity_x = -absf(velocity_x)
	var noise_state: int = int(clone.get("motion_noise_state", 1))
	noise_state = int((1103515245 * noise_state + 12345) % 2147483647)
	var noise_unit: float = float(noise_state) / 2147483647.0
	velocity_x += lerpf(
		-CLONE_ACCEL_JITTER_PER_FRAME,
		CLONE_ACCEL_JITTER_PER_FRAME,
		noise_unit
	)
	velocity_x = clampf(velocity_x, -CLONE_SPEED_MAX_PER_FRAME, CLONE_SPEED_MAX_PER_FRAME)
	clone["center"] = center
	clone["velocity_x"] = velocity_x
	clone["motion_noise_state"] = noise_state


func _update_clone_invulnerability(delta: float) -> void:
	if not _clone_casting:
		_clone_invuln_buffer_remaining_sec = maxf(
			0.0,
			_clone_invuln_buffer_remaining_sec - delta
		)
		if _clone_invuln_buffer_remaining_sec <= 0.000001:
			_clone_invuln_buffer_remaining_sec = 0.0
	_refresh_boss_ball_intangible()


func _refresh_boss_ball_intangible() -> void:
	_boss_ball_intangible = (
		_clone_casting
		or _clone_invuln_buffer_remaining_sec > 0.0
		or not _boss_ball_intangible_sources.is_empty()
	)


func _refresh_scripted_motion() -> void:
	if _escape_active:
		_scripted_motion_active = true
		_scripted_boss_pos = _get_escape_boss_pos()
	elif _cloud_dash_active:
		_scripted_motion_active = true
		_scripted_boss_pos = _get_cloud_boss_pos()
	elif _clone_casting:
		_scripted_motion_active = true
		_scripted_boss_pos = _clone_cast_boss_pos
	elif _shuriken_casting:
		_scripted_motion_active = true
		_scripted_boss_pos = _shuriken_cast_boss_pos
	elif _debug_scripted_motion_active:
		_scripted_motion_active = true
		_scripted_boss_pos = _debug_scripted_boss_pos
	else:
		_scripted_motion_active = false
		_scripted_boss_pos = Vector2.ZERO


func _has_live_clones() -> bool:
	return _get_live_clone_count() > 0


func _get_live_clone_count() -> int:
	var count := 0
	for clone_value in _clones:
		if clone_value is Dictionary and str((clone_value as Dictionary).get("phase", "")) != "dying":
			count += 1
	return count


func _get_dying_clone_count() -> int:
	var count := 0
	for clone_value in _clones:
		if clone_value is Dictionary and str((clone_value as Dictionary).get("phase", "")) == "dying":
			count += 1
	return count


func _max_live_clone_remaining_sec() -> float:
	var remaining := 0.0
	for clone_value in _clones:
		if not (clone_value is Dictionary):
			continue
		var clone: Dictionary = clone_value
		if str(clone.get("phase", "")) == "dying":
			continue
		remaining = maxf(remaining, CLONE_DURATION_SEC - float(clone.get("age_sec", 0.0)))
	return remaining


func _find_nearest_clone_hit(from_pos: Vector2, to_pos: Vector2, ball_radius: float) -> Dictionary:
	var nearest_index := -1
	var nearest_point := Vector2.ZERO
	var nearest_distance_squared := INF
	for index in range(_clones.size()):
		var clone: Dictionary = _clones[index]
		if str(clone.get("phase", "")) == "dying":
			continue
		var expanded_rect: Rect2 = _clone_rect(clone).grow(ball_radius)
		var hit_point: Variant = _get_segment_rect_hit_point(from_pos, to_pos, expanded_rect)
		if hit_point == null:
			continue
		var point: Vector2 = hit_point as Vector2
		var distance_squared: float = from_pos.distance_squared_to(point)
		if nearest_index < 0 or distance_squared < nearest_distance_squared:
			nearest_index = index
			nearest_point = point
			nearest_distance_squared = distance_squared
	if nearest_index < 0:
		return {}
	return {"index": nearest_index, "point": nearest_point}


func _get_segment_rect_hit_point(from_pos: Vector2, to_pos: Vector2, rect: Rect2) -> Variant:
	if rect.has_point(from_pos):
		return from_pos
	var endpoint_inside: bool = rect.has_point(to_pos)
	var corners: Array[Vector2] = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	var closest_point := Vector2.ZERO
	var closest_distance_squared := INF
	var found := false
	for index in range(corners.size()):
		var intersection: Variant = Geometry2D.segment_intersects_segment(
			from_pos,
			to_pos,
			corners[index],
			corners[(index + 1) % corners.size()]
		)
		if intersection == null:
			continue
		var point: Vector2 = intersection as Vector2
		var distance_squared: float = from_pos.distance_squared_to(point)
		if not found or distance_squared < closest_distance_squared:
			closest_point = point
			closest_distance_squared = distance_squared
			found = true
	if found:
		return closest_point
	# Degenerate/numerically marginal outside-to-inside segments should still
	# collide, but the endpoint is only a fallback after every boundary edge was
	# checked for the true first contact.
	return to_pos if endpoint_inside else null


func _clone_rect(clone: Dictionary) -> Rect2:
	var center: Vector2 = _as_vector2(clone.get("center", Vector2.ZERO), Vector2.ZERO)
	var size: Vector2 = _as_vector2(clone.get("size", CLONE_SIZE), CLONE_SIZE)
	return Rect2(center - size * 0.5, size)


func _apply_clone_ball_reflection(
	scene: Dictionary,
	context: Dictionary,
	deps: Dictionary,
	clone_rect: Rect2,
	contact_point: Vector2
) -> void:
	var bounce_context: Dictionary = context.duplicate()
	bounce_context.merge(scene, true)
	# Swept collision may end well beyond the clone. Use the first contact point
	# for the shared angle calculation and separation, not the frame endpoint.
	bounce_context["ball_pos"] = contact_point
	var bounce_result: Dictionary = {}
	var controller: Object = deps.get("paddle_bounce_controller", null)
	if controller != null and controller.has_method("bounce_auxiliary_boss_paddle"):
		var result_value: Variant = controller.bounce_auxiliary_boss_paddle(
			clone_rect,
			bounce_context,
			deps
		)
		if result_value is Dictionary:
			bounce_result = result_value
	var reflected_velocity: Vector2 = _as_vector2(
		bounce_result.get("ball_vel", Vector2.ZERO),
		Vector2.ZERO
	)
	if bounce_result.is_empty() or reflected_velocity.y <= 0.0:
		_apply_clone_ball_reflection_fallback(scene, context, clone_rect, contact_point)
		return
	for key in AUXILIARY_BOUNCE_RESULT_KEYS:
		if bounce_result.has(key):
			scene[key] = bounce_result[key]


func _apply_clone_ball_reflection_fallback(
	scene: Dictionary,
	context: Dictionary,
	clone_rect: Rect2,
	contact_point: Vector2
) -> void:
	var ball_vel: Vector2 = _as_vector2(scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	var speed: float = maxf(2.0, ball_vel.length())
	ball_vel.y = maxf(absf(ball_vel.y), maxf(2.0, speed * 0.30))
	var ball_pos: Vector2 = contact_point
	var radius: float = maxf(1.0, float(context.get("ball_size", 28.6)) * 0.5)
	ball_pos.y = maxf(ball_pos.y, clone_rect.end.y + radius + 1.0)
	scene["ball_pos"] = ball_pos
	scene["ball_vel"] = ball_vel


func _begin_clone_dying(index: int, deps: Dictionary) -> void:
	if index < 0 or index >= _clones.size():
		return
	var clone: Dictionary = _clones[index]
	clone["phase"] = "dying"
	clone["death_elapsed_sec"] = 0.0
	clone["death_progress"] = 0.0
	clone["motion_frame_accumulator"] = 0.0
	clone["velocity_x"] = 0.0
	_clones[index] = clone
	_play_stage7_audio(deps, &"play_stage7_akamu_clone_out")


func _register_clone_ball_contact(deps: Dictionary) -> void:
	var ball_intensity: Object = deps.get("ball_intensity", null)
	if ball_intensity == null:
		return
	if ball_intensity.has_method("register_contact"):
		ball_intensity.register_contact(
			"stage7_akamu_clone",
			"boss",
			{"auxiliary_paddle": true}
		)
	elif ball_intensity.has_method("register_hit"):
		ball_intensity.register_hit("boss")


func _register_auxiliary_paddle_hit(deps: Dictionary) -> void:
	# The shared wall-stall guard treats any paddle contact as the end of one
	# alternating-wall sequence. Clone reflections bypass the normal paddle
	# event processor, so mirror that small physics-state reset explicitly.
	var wall_controller: Object = deps.get("wall_bounce_controller", null)
	if wall_controller != null and wall_controller.has_method("register_paddle_hit"):
		wall_controller.register_paddle_hit()


func _is_player_owned_ball(context: Dictionary, deps: Dictionary) -> bool:
	var last_hit_by: String = str(context.get("last_hit_by", "")).strip_edges().to_lower()
	if last_hit_by == "":
		var ball_intensity: Object = deps.get("ball_intensity", null)
		if ball_intensity != null and ball_intensity.has_method("get_last_hit_by"):
			last_hit_by = str(ball_intensity.get_last_hit_by()).strip_edges().to_lower()
	return last_hit_by == "" or last_hit_by == "player"


func _play_stage7_audio(deps: Dictionary, method_name: StringName) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method(method_name):
		audio.call(method_name)


func _update_shuriken_scheduler(delta: float, context: Dictionary) -> void:
	if not _shuriken_scheduler_armed:
		_arm_shuriken_cooldown()
		return
	_shuriken_cooldown_remaining_sec = maxf(0.0, _shuriken_cooldown_remaining_sec - delta)
	if _shuriken_cooldown_remaining_sec > 0.0:
		return
	if (
		boss_special_gauge < SHURIKEN_GAUGE_COST
		or _superspeed_active
		or _clone_casting
		or _has_live_clones()
		or _cloud_dash_active
		or _escape_active
		or _external_scripted_motion_active
		or bool(context.get("lingpet_puppet_grab_active", false))
	):
		return
	_start_shuriken_cast(context)


func _start_shuriken_cast(context: Dictionary) -> void:
	boss_special_gauge = maxf(0.0, boss_special_gauge - SHURIKEN_GAUGE_COST)
	_shuriken_casting = true
	_shuriken_cast_elapsed_sec = 0.0
	_shuriken_cast_boss_pos = _as_vector2(
		context.get("boss_pos", Vector2(330.0, 25.0)),
		Vector2(330.0, 25.0)
	)
	_refresh_scripted_motion()


func _update_shuriken_cast(delta: float, context: Dictionary, deps: Dictionary) -> void:
	_shuriken_cast_elapsed_sec += delta
	if _shuriken_cast_elapsed_sec + 0.000001 < SHURIKEN_CAST_SEC:
		return
	_shuriken_casting = false
	_shuriken_cast_elapsed_sec = 0.0
	_shuriken_cast_boss_pos = Vector2.ZERO
	_refresh_scripted_motion()
	_spawn_shuriken_from_context(context, false, deps)
	_arm_shuriken_cooldown()
	if awakened:
		_shuriken_pending_remaining.append(SHURIKEN_PENDING_DELAY_SEC)


func _update_pending_shurikens(delta: float, context: Dictionary, deps: Dictionary) -> void:
	if _shuriken_pending_remaining.is_empty():
		return
	var write_index := 0
	for read_index in range(_shuriken_pending_remaining.size()):
		var remaining: float = float(_shuriken_pending_remaining[read_index]) - delta
		if remaining <= 0.000001:
			# Intentional cleanup correction: a pending bonus shot does not reroll
			# the primary volley cooldown or cancel another cast.
			_spawn_shuriken_from_context(context, true, deps)
			continue
		_shuriken_pending_remaining[write_index] = remaining
		write_index += 1
	if write_index < _shuriken_pending_remaining.size():
		_shuriken_pending_remaining.resize(write_index)


func _spawn_shuriken_from_context(
	context: Dictionary,
	from_pending: bool,
	deps: Dictionary
) -> void:
	var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2(330.0, 25.0)), Vector2(330.0, 25.0))
	var boss_size := Vector2(
		maxf(1.0, float(context.get("boss_paddle_width", 100.0))),
		maxf(1.0, float(context.get("boss_hitbox_height", 40.0)))
	)
	var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2(302.5, 690.0)), Vector2(302.5, 690.0))
	var player_size: Vector2 = _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	var origin: Vector2 = boss_pos + boss_size * 0.5
	var target: Vector2 = player_pos + player_size * 0.5
	_append_shuriken(origin, target, from_pending)
	_play_stage7_audio(deps, &"play_stage7_akamu_shuriken_shoot")
	_trigger_boss_attack("shuriken", target.x)


func _append_shuriken(origin: Vector2, target: Vector2, from_pending: bool) -> void:
	var direction: Vector2 = target - origin
	if direction.length_squared() <= 0.000001:
		direction = Vector2.DOWN
	while _shurikens.size() >= SHURIKEN_MAX_ACTIVE:
		_shurikens.pop_front()
	_shurikens.append({
		"center": origin,
		"prev_center": origin,
		"velocity": direction.normalized() * SHURIKEN_SPEED_PER_FRAME,
		"size": SHURIKEN_SIZE,
		# Legacy collision is 18x10, while the four-blade procedural visual is
		# roughly 39px square. Keep those two surfaces intentionally separate.
		"radius": 18.0,
		"angle": 0.0,
		"from_pending": from_pending,
	})


func _arm_shuriken_cooldown() -> void:
	_shuriken_scheduler_armed = true
	_shuriken_cooldown_total_sec = float(_rng.randi_range(
		SHURIKEN_COOLDOWN_MIN_MSEC,
		SHURIKEN_COOLDOWN_MAX_MSEC
	)) / 1000.0
	_shuriken_cooldown_remaining_sec = _shuriken_cooldown_total_sec


func _update_shuriken_projectiles(
	frame_scale: float,
	delta: float,
	context: Dictionary,
	deps: Dictionary,
	result: Dictionary
) -> void:
	if _shurikens.is_empty():
		return
	var player_rect := _get_player_rect(context)
	var player_center: Vector2 = player_rect.get_center()
	var write_index := 0
	for read_index in range(_shurikens.size()):
		var shuriken: Dictionary = _shurikens[read_index]
		var previous: Vector2 = _as_vector2(shuriken.get("center", Vector2.ZERO), Vector2.ZERO)
		var velocity: Vector2 = _as_vector2(shuriken.get("velocity", Vector2.DOWN * SHURIKEN_SPEED_PER_FRAME), Vector2.DOWN * SHURIKEN_SPEED_PER_FRAME)
		var center: Vector2 = previous + velocity * frame_scale
		shuriken["prev_center"] = previous
		shuriken["center"] = center
		shuriken["angle"] = fposmod(float(shuriken.get("angle", 0.0)) + SHURIKEN_SPIN_RADIANS_PER_SEC * delta, TAU)
		var player_hit_point: Variant = _get_shuriken_player_hit_point(previous, center, player_rect)
		if player_hit_point != null:
			if _is_player_in_smoke(player_center, context, deps):
				result["stage7_akamu_shuriken_smoke_absorbed"] = true
				continue
			_register_shuriken_hit(player_hit_point as Vector2, velocity, context, deps, result)
			continue
		# Cull after swept collision. A clamped hitch frame (delta=0.1) can move
		# the center beyond the bottom margin while its segment crosses the player.
		if _is_shuriken_out_of_bounds(center):
			continue
		_shurikens[write_index] = shuriken
		write_index += 1
	if write_index < _shurikens.size():
		_shurikens.resize(write_index)


func _register_shuriken_hit(
	center: Vector2,
	velocity: Vector2,
	context: Dictionary,
	deps: Dictionary,
	result: Dictionary
) -> void:
	result["stage7_akamu_shuriken_hit"] = true
	result["stage7_akamu_shuriken_hit_count"] = int(result.get("stage7_akamu_shuriken_hit_count", 0)) + 1
	_spawn_shuriken_hit_particles(center, velocity)
	# Smoke absorption is filtered before this commit. A cleanse-immune player
	# still made physical contact in the legacy runtime, so the hit cue precedes
	# the status-immunity early return.
	_play_stage7_audio(deps, &"play_stage7_akamu_shuriken_hit")
	if PlayerKnockbackImmunity.is_cleanse_immune(deps, context):
		result["stage7_akamu_shuriken_cleansed"] = true
		return
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state != null and status_effect_state.has_method("apply_status"):
		status_effect_state.apply_status(
			"player",
			"slow",
			SHURIKEN_SLOW_FRAMES,
			{
				"multiplier": SHURIKEN_SLOW_MULTIPLIER,
				"cleansable": true,
				"visual_variant": "stage7_akamu_shuriken",
				"label": "표창",
			},
			SHURIKEN_STATUS_SOURCE
		)
	var working_speed: float = float(result.get("player_speed", context.get("player_speed", 0.0)))
	result["player_speed"] = working_speed * SHURIKEN_SLOW_MULTIPLIER
	result["stage7_akamu_shuriken_slow_applied"] = true
	_shuriken_gauge_ticks_left = SHURIKEN_GAUGE_DRAIN_TICKS
	_shuriken_gauge_tick_frames_remaining = SHURIKEN_GAUGE_DRAIN_TICK_FRAMES


func _update_shuriken_gauge_drain(frame_scale: float, context: Dictionary, result: Dictionary) -> void:
	if _shuriken_gauge_ticks_left <= 0:
		return
	_shuriken_gauge_tick_frames_remaining -= frame_scale
	while _shuriken_gauge_ticks_left > 0 and _shuriken_gauge_tick_frames_remaining <= 0.0:
		var gauge: float = maxf(0.0, float(result.get("special_gauge", context.get("special_gauge", 0.0))))
		var drain: float = minf(SHURIKEN_GAUGE_DRAIN_AMOUNT, gauge)
		if drain > 0.0:
			result["special_gauge"] = gauge - drain
		_shuriken_gauge_ticks_left -= 1
		if _shuriken_gauge_ticks_left > 0:
			_shuriken_gauge_tick_frames_remaining += SHURIKEN_GAUGE_DRAIN_TICK_FRAMES
		else:
			_shuriken_gauge_tick_frames_remaining = 0.0


func _get_shuriken_player_hit_point(from_pos: Vector2, to_pos: Vector2, player_rect: Rect2) -> Variant:
	var expanded: Rect2 = player_rect.grow_individual(
		SHURIKEN_SIZE.x * 0.5,
		SHURIKEN_SIZE.y * 0.5,
		SHURIKEN_SIZE.x * 0.5,
		SHURIKEN_SIZE.y * 0.5
	)
	if expanded.has_point(from_pos):
		return from_pos
	if expanded.has_point(to_pos):
		return to_pos
	var corners: Array[Vector2] = [
		expanded.position,
		Vector2(expanded.end.x, expanded.position.y),
		expanded.end,
		Vector2(expanded.position.x, expanded.end.y),
	]
	var closest_hit := Vector2.ZERO
	var closest_distance_squared := INF
	var found_hit := false
	for index in range(corners.size()):
		var next_index: int = (index + 1) % corners.size()
		var intersection: Variant = Geometry2D.segment_intersects_segment(
			from_pos,
			to_pos,
			corners[index],
			corners[next_index]
		)
		if intersection == null:
			continue
		var hit_point: Vector2 = intersection as Vector2
		var distance_squared: float = from_pos.distance_squared_to(hit_point)
		if not found_hit or distance_squared < closest_distance_squared:
			closest_hit = hit_point
			closest_distance_squared = distance_squared
			found_hit = true
	return closest_hit if found_hit else null


func _is_shuriken_out_of_bounds(center: Vector2) -> bool:
	var half_size: Vector2 = SHURIKEN_SIZE * 0.5
	return (
		center.x + half_size.x < -SHURIKEN_OFFSCREEN_MARGIN
		or center.x - half_size.x > FIELD_WIDTH + SHURIKEN_OFFSCREEN_MARGIN
		or center.y + half_size.y < -SHURIKEN_OFFSCREEN_MARGIN
		or center.y - half_size.y > FIELD_HEIGHT + SHURIKEN_OFFSCREEN_MARGIN
	)


func _is_player_in_smoke(player_center: Vector2, context: Dictionary, deps: Dictionary) -> bool:
	if bool(context.get("player_in_smoke", false)):
		return true
	for value in _get_smoke_zones(context, deps):
		if not (value is Dictionary):
			continue
		var zone: Dictionary = value
		var opacity: float = float(zone.get("opacity", 0.0))
		var threshold: float = 50.0 if opacity > 1.0 else SHURIKEN_SMOKE_OPACITY_THRESHOLD
		if opacity <= threshold:
			continue
		var center: Vector2 = _as_vector2(zone.get("position", Vector2.ZERO), Vector2(
			float(zone.get("x", 0.0)),
			float(zone.get("y", 0.0))
		))
		var radius_y: float = maxf(0.0, float(zone.get("radius", 0.0)))
		var radius_x: float = maxf(0.0, float(zone.get("radius_x", radius_y)))
		if radius_x <= 0.0 or radius_y <= 0.0:
			continue
		var dx: float = (player_center.x - center.x) / radius_x
		var dy: float = (player_center.y - center.y) / radius_y
		if dx * dx + dy * dy <= 1.0:
			return true
	return false


func _get_smoke_zones(context: Dictionary, deps: Dictionary) -> Array:
	for key in ["stage3_smoke_zones", "smoke_zones", "active_item_tear_gas_zones", "tear_gas_zones"]:
		var context_value: Variant = context.get(key, [])
		if context_value is Array and not (context_value as Array).is_empty():
			return context_value
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null:
		if active_item_runtime.has_method("get_tear_gas_zones"):
			var runtime_zones: Variant = active_item_runtime.get_tear_gas_zones()
			if runtime_zones is Array and not (runtime_zones as Array).is_empty():
				return runtime_zones
		var throw_controller: Object = active_item_runtime.get("throw_controller")
		if throw_controller != null and throw_controller.has_method("get_tear_gas_zones"):
			var controller_zones: Variant = throw_controller.get_tear_gas_zones()
			if controller_zones is Array and not (controller_zones as Array).is_empty():
				return controller_zones
	return []


func _spawn_shuriken_hit_particles(center: Vector2, velocity: Vector2) -> void:
	# 원본 create_blood_particles 파리티: 탄 반대 방향 ±60도 원뿔, 속도 3~12
	# px/frame + 상향킥 2~5, 크기 2~5, 수명 20~40프레임, 중력 0.3~0.6의
	# 포물선 혈흔. 스폰 지터 ±5px, 시작 알파 1.0.
	var bullet_angle: float = velocity.angle() if velocity.length_squared() > 0.000001 else PI * 0.5
	var count: int = _rng.randi_range(8, 12)
	for _index in range(count):
		while _particles.size() >= SHURIKEN_HIT_PARTICLE_MAX:
			_particles.pop_front()
		var spread_angle: float = bullet_angle + PI + _rng.randf_range(-PI / 3.0, PI / 3.0)
		var speed: float = _rng.randf_range(3.0, 12.0)
		var life: float = float(_rng.randi_range(20, 40)) / LEGACY_FPS
		_particles.append({
			"pos": center + Vector2(_rng.randf_range(-5.0, 5.0), _rng.randf_range(-5.0, 5.0)),
			"vel": Vector2(
				cos(spread_angle) * speed,
				sin(spread_angle) * speed - _rng.randf_range(2.0, 5.0)
			),
			"life": life,
			"max_life": life,
			"radius": _rng.randf_range(2.0, 5.0),
			"gravity_per_frame": _rng.randf_range(0.3, 0.6),
			"base_alpha": 1.0,
			"color": Color(0.72, 0.05, 0.10, 1.0),
		})


func _update_wind_effects(
	frame_scale: float,
	delta: float,
	_context: Dictionary,
	_skill_cooldown_paused_now: bool
) -> void:
	_wind_aura_hit_cooldown_remaining_sec = maxf(
		0.0,
		_wind_aura_hit_cooldown_remaining_sec - delta
	)
	_wind_aura_ripple_remaining_sec = maxf(
		0.0,
		_wind_aura_ripple_remaining_sec - delta
	)
	_update_wind_aura_visuals(frame_scale, delta)
	_update_wind_burst_particles(frame_scale, delta)
	_sync_wind_aura_draw_context()


func _update_wind_aura_visuals(frame_scale: float, delta: float) -> void:
	if not _wind_aura_active or not awakened:
		return
	_wind_aura_elapsed_sec += delta
	for value in _wind_aura_particles:
		if not (value is Dictionary):
			continue
		var particle: Dictionary = value
		particle["angle"] = float(particle.get("angle", 0.0)) \
			+ float(particle.get("speed", 0.03)) * frame_scale
		particle["radius"] = float(particle.get("base_radius", 64.0)) \
			+ sin(_wind_aura_elapsed_sec * 3.0 + float(particle.get("phase", 0.0))) * 10.0


func _init_wind_aura_particles() -> void:
	_wind_aura_particles.clear()
	var palette := [
		Color(100.0 / 255.0, 220.0 / 255.0, 1.0, 150.0 / 255.0),
		Color(150.0 / 255.0, 1.0, 200.0 / 255.0, 130.0 / 255.0),
		Color(200.0 / 255.0, 240.0 / 255.0, 1.0, 140.0 / 255.0),
		Color(80.0 / 255.0, 200.0 / 255.0, 230.0 / 255.0, 160.0 / 255.0),
	]
	for index in range(WIND_AURA_PARTICLE_COUNT):
		var base_radius: float = _rng.randf_range(50.0, 80.0)
		_wind_aura_particles.append({
			"angle": float(index) / float(WIND_AURA_PARTICLE_COUNT) * TAU,
			"radius": base_radius,
			"base_radius": base_radius,
			"size": float(_rng.randi_range(3, 8)),
			"speed": _rng.randf_range(0.02, 0.05),
			"color": palette[_rng.randi_range(0, palette.size() - 1)],
			"phase": _rng.randf_range(0.0, TAU),
		})


func _spawn_wind_burst(center: Vector2, disperse: bool) -> void:
	_wind_burst_particles.clear()
	var count := WIND_DISPERSE_PARTICLE_COUNT if disperse else WIND_BURST_PARTICLE_COUNT
	var palette := [
		Color(100.0 / 255.0, 220.0 / 255.0, 1.0, 1.0),
		Color(150.0 / 255.0, 1.0, 200.0 / 255.0, 1.0),
		Color(200.0 / 255.0, 240.0 / 255.0, 1.0, 1.0),
		Color(80.0 / 255.0, 200.0 / 255.0, 230.0 / 255.0, 1.0),
		Color(120.0 / 255.0, 180.0 / 255.0, 1.0, 1.0),
	]
	for _index in range(count):
		var angle: float = _rng.randf_range(0.0, TAU)
		var speed: float = _rng.randf_range(5.0, 15.0) if disperse else _rng.randf_range(8.0, 25.0)
		var spawn_pos := center
		if disperse:
			spawn_pos += Vector2.RIGHT.rotated(angle) * _rng.randf_range(30.0, WIND_AURA_RADIUS)
		# 원본 quirk 행동 파리티: disperse의 알파 시드 180은 공용 업데이터가
		# 매 프레임 255 기준 페이드로 덮는다 — 실효 시작 알파는 양쪽 다 1.0.
		var initial_alpha := 1.0
		_wind_burst_particles.append({
			"pos": spawn_pos,
			"vel": Vector2.RIGHT.rotated(angle) * speed,
			"size": float(_rng.randi_range(2, 6) if disperse else _rng.randi_range(4, 12)),
			"rotation": _rng.randf_range(0.0, TAU),
			"rotation_speed": _rng.randf_range(-0.17, 0.17) if disperse else _rng.randf_range(-0.26, 0.26),
			"color": palette[_rng.randi_range(0, (2 if disperse else palette.size() - 1))],
			"initial_alpha": initial_alpha,
			"alpha": initial_alpha,
			"age_sec": 0.0,
			"duration_sec": WIND_BURST_DURATION_SEC,
			"kind": "disperse" if disperse else "awakening",
		})


func _update_wind_burst_particles(frame_scale: float, delta: float) -> void:
	if _wind_burst_particles.is_empty():
		return
	var write_index := 0
	for read_index in range(_wind_burst_particles.size()):
		var particle: Dictionary = _wind_burst_particles[read_index]
		var age_sec: float = float(particle.get("age_sec", 0.0)) + delta
		var duration_sec: float = maxf(0.001, float(particle.get("duration_sec", WIND_BURST_DURATION_SEC)))
		if age_sec >= duration_sec:
			continue
		var velocity: Vector2 = _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO)
		velocity *= pow(0.94, frame_scale)
		particle["pos"] = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) \
			+ velocity * frame_scale
		particle["vel"] = velocity
		particle["size"] = maxf(1.0, float(particle.get("size", 1.0)) * pow(0.98, frame_scale))
		particle["rotation"] = float(particle.get("rotation", 0.0)) \
			+ float(particle.get("rotation_speed", 0.0)) * frame_scale
		particle["age_sec"] = age_sec
		particle["alpha"] = float(particle.get("initial_alpha", 1.0)) \
			* (1.0 - age_sec / duration_sec)
		_wind_burst_particles[write_index] = particle
		write_index += 1
	if write_index < _wind_burst_particles.size():
		_wind_burst_particles.resize(write_index)


func _update_wind_aura_recharge(delta: float) -> void:
	if not _wind_aura_depleted:
		return
	_wind_aura_recharge_remaining_sec = maxf(
		0.0,
		_wind_aura_recharge_remaining_sec - delta
	)
	if _wind_aura_recharge_remaining_sec > 0.0:
		_sync_wind_aura_draw_context()
		return
	_wind_aura_depleted = false
	_wind_aura_hit_count = 0
	_wind_aura_ripple_remaining_sec = 0.0
	_init_wind_aura_particles()
	_sync_wind_aura_draw_context()


func _update_wind_aura_free_clone_queue(context: Dictionary) -> void:
	if not _wind_aura_free_clone_queued:
		return
	if _superspeed_active:
		_wind_aura_free_clone_queued = false
		return
	if _cloud_dash_active or _has_scripted_skill_conflict("clone"):
		return
	_wind_aura_free_clone_queued = false
	_try_start_clone_cast(context, true, true, "wind_aura_queued", true)


func _sync_wind_aura_draw_context(center_override: Variant = null) -> void:
	if not awakened or not _wind_aura_active:
		_wind_aura_draw_context.clear()
		return
	var center: Vector2 = _get_effect_boss_pos() + _last_boss_size * 0.5
	if center_override is Vector2:
		center = center_override as Vector2
	var strength: float = 0.0
	if not _wind_aura_depleted:
		strength = float(WIND_AURA_MAX_HITS - _wind_aura_hit_count) \
			/ float(WIND_AURA_MAX_HITS)
	_wind_aura_draw_context["active"] = true
	_wind_aura_draw_context["center"] = center
	_wind_aura_draw_context["radius"] = WIND_AURA_RADIUS
	_wind_aura_draw_context["strength"] = clampf(strength, 0.0, 1.0)
	_wind_aura_draw_context["hit_count"] = _wind_aura_hit_count
	_wind_aura_draw_context["max_hits"] = WIND_AURA_MAX_HITS
	_wind_aura_draw_context["remaining_hits"] = maxi(0, WIND_AURA_MAX_HITS - _wind_aura_hit_count)
	_wind_aura_draw_context["depleted"] = _wind_aura_depleted
	_wind_aura_draw_context["recharge_remaining"] = _wind_aura_recharge_remaining_sec
	_wind_aura_draw_context["recharge_total"] = WIND_AURA_RECHARGE_SEC
	_wind_aura_draw_context["ripple_intensity"] = _get_wind_aura_ripple_intensity()
	_wind_aura_draw_context["superspeed"] = _superspeed_active
	_wind_aura_draw_context["elapsed_sec"] = _wind_aura_elapsed_sec
	_wind_aura_draw_context["particles"] = _wind_aura_particles


func _get_wind_aura_ripple_intensity() -> float:
	if _wind_aura_ripple_remaining_sec <= 0.0:
		return 0.0
	var progress: float = 1.0 - _wind_aura_ripple_remaining_sec / WIND_AURA_RIPPLE_SEC
	return sin(clampf(progress, 0.0, 1.0) * PI) * (1.0 - progress * 0.5)


func _get_effect_boss_pos() -> Vector2:
	if _superspeed_active:
		return _superspeed_boss_pos
	if _escape_active:
		return _get_escape_boss_pos()
	if _cloud_dash_active:
		return _get_cloud_boss_pos()
	if _clone_casting:
		return _clone_cast_boss_pos
	if _shuriken_casting:
		return _shuriken_cast_boss_pos
	return _last_boss_pos


func _try_start_superspeed(context: Dictionary) -> bool:
	if (
		_superspeed_active
		or not awakened
		or _superspeed_cooldown_remaining_sec > 0.0
		or boss_special_gauge < SUPERSPEED_GAUGE_COST
		or _escape_active
		or _external_scripted_motion_active
		or bool(context.get("lingpet_puppet_grab_active", false))
		or is_gameplay_freeze_active()
	):
		return false
	# Cloud owns a vertical scripted excursion. Superspeed cancellation must
	# normalize to the captured home band before the tangible predictive dash
	# begins; keeping the down/up position would strand the paddle mid-field.
	var start_pos: Vector2 = _cloud_home_boss_pos if _cloud_dash_active else _get_effect_boss_pos()
	_superspeed_boss_size = _as_vector2(
		context.get("boss_paddle_size", Vector2(
			float(context.get("boss_paddle_width", _last_boss_size.x)),
			float(context.get("boss_hitbox_height", _last_boss_size.y))
		)),
		_last_boss_size
	)
	_superspeed_visual_scale = clampf(float(context.get("boss_paddle_shrink_scale", 1.0)), 0.2, 1.0)
	boss_special_gauge = maxf(0.0, boss_special_gauge - SUPERSPEED_GAUGE_COST)
	_superspeed_active = true
	_superspeed_remaining_sec = SUPERSPEED_DURATION_SEC
	_superspeed_text_remaining_sec = SUPERSPEED_TEXT_SEC
	_superspeed_cooldown_remaining_sec = 0.0
	_superspeed_dash_active = false
	_superspeed_dash_timer_frames = 0.0
	_superspeed_dash_duration_frames = 0.0
	_superspeed_dash_direction = 0
	_superspeed_dash_target_center_x = 0.0
	_superspeed_dash_recovery_frames = 0.0
	_superspeed_motion_frame_accumulator = 0.0
	_superspeed_boss_pos = start_pos
	_superspeed_trail_spawn_accumulator = 0.0
	_superspeed_afterimages.clear()
	_superspeed_dark_particles.clear()
	_superspeed_trails.clear()
	_cancel_skills_for_superspeed()
	_gameplay_freeze_reason = "superspeed"
	_gameplay_freeze_remaining_sec = SUPERSPEED_ACTIVATION_FREEZE_SEC
	_sync_wind_aura_draw_context()
	status = "superspeed_freeze"
	return true


func _cancel_skills_for_superspeed() -> void:
	_wind_aura_free_clone_queued = false
	var interrupted_cloud_dash: bool = _cloud_dash_active
	var cloud_release_pos: Vector2 = _cloud_home_boss_pos
	if _clone_casting:
		_cancel_clone_cast()
	_shuriken_casting = false
	_shuriken_cast_elapsed_sec = 0.0
	_shuriken_cast_boss_pos = Vector2.ZERO
	_shuriken_pending_remaining.clear()
	_cloud_dash_active = false
	_cloud_dash_phase = ""
	_cloud_phase_elapsed_sec = 0.0
	_cloud_invuln_buffer_remaining_sec = 0.0
	_cloud_field_active = false
	_cloud_field_elapsed_sec = 0.0
	_cloud_field_center = Vector2.ZERO
	_cloud_draw_context.clear()
	_aura_draw_context.clear()
	set_boss_ball_intangible_source(CLOUD_INTANGIBLE_SOURCE, false)
	if interrupted_cloud_dash:
		_boss_position_release_pending = true
		_boss_position_release_pos = cloud_release_pos
	_refresh_scripted_motion()
	_refresh_boss_ball_intangible()


func _update_superspeed(frame_scale: float, delta: float, context: Dictionary) -> void:
	_superspeed_boss_pos = _as_vector2(
		context.get("boss_pos", _superspeed_boss_pos),
		_superspeed_boss_pos
	)
	_superspeed_boss_size = _as_vector2(
		context.get("boss_paddle_size", Vector2(
			float(context.get("boss_paddle_width", _superspeed_boss_size.x)),
			float(context.get("boss_hitbox_height", _superspeed_boss_size.y))
		)),
		_superspeed_boss_size
	)
	_update_superspeed_afterimages(frame_scale, delta)
	if not _superspeed_active:
		return
	_superspeed_remaining_sec = maxf(0.0, _superspeed_remaining_sec - delta)
	_superspeed_text_remaining_sec = maxf(0.0, _superspeed_text_remaining_sec - delta)
	if _superspeed_remaining_sec <= 0.0:
		_end_superspeed()
		return
	# Movement is advanced in boss_ai_state before ball physics. This fixed-tick
	# accumulator owns only render payloads so particle density is FPS-stable.
	_superspeed_motion_frame_accumulator += frame_scale
	while _superspeed_motion_frame_accumulator + 0.000001 >= 1.0:
		_spawn_superspeed_dark_particles()
		_advance_superspeed_dark_particles_tick()
		_superspeed_trail_spawn_accumulator += 1.0
		if _superspeed_trail_spawn_accumulator + 0.000001 >= SUPERSPEED_TRAIL_SPAWN_INTERVAL_FRAMES:
			_superspeed_trail_spawn_accumulator = 0.0
			_spawn_superspeed_trail()
		_advance_superspeed_trails_tick()
		_superspeed_motion_frame_accumulator -= 1.0
	_sync_wind_aura_draw_context()


func _finish_superspeed_dash() -> void:
	_superspeed_dash_active = false
	_superspeed_dash_timer_frames = 0.0
	_superspeed_dash_duration_frames = 0.0
	_superspeed_dash_direction = 0
	_superspeed_dash_target_center_x = 0.0
	_superspeed_dash_recovery_frames = SUPERSPEED_DASH_RECOVERY_FRAMES


func _end_superspeed() -> void:
	if not _superspeed_active:
		return
	_superspeed_active = false
	_superspeed_remaining_sec = 0.0
	_superspeed_text_remaining_sec = 0.0
	_superspeed_cooldown_remaining_sec = SUPERSPEED_COOLDOWN_SEC
	_finish_superspeed_dash()
	_superspeed_dash_recovery_frames = 0.0
	_superspeed_motion_frame_accumulator = 0.0
	_superspeed_dark_particles.clear()
	_superspeed_trails.clear()
	_superspeed_trail_spawn_accumulator = 0.0
	if _gameplay_freeze_reason == "superspeed":
		_gameplay_freeze_reason = ""
		_gameplay_freeze_remaining_sec = 0.0
	_sync_wind_aura_draw_context()


func notify_superspeed_dash_started(
	boss_pos: Vector2,
	boss_size: Vector2,
	direction: int,
	target_center_x: float,
	duration_frames: float
) -> void:
	if not _superspeed_active:
		return
	_superspeed_boss_pos = boss_pos
	_superspeed_boss_size = boss_size
	_superspeed_dash_active = true
	_superspeed_dash_direction = direction
	_superspeed_dash_target_center_x = target_center_x
	_superspeed_dash_duration_frames = duration_frames
	_superspeed_dash_timer_frames = duration_frames
	_spawn_superspeed_afterimages(boss_pos + boss_size * 0.5)


func notify_superspeed_dash_finished(boss_pos: Vector2) -> void:
	_superspeed_boss_pos = boss_pos
	_superspeed_dash_active = false
	_superspeed_dash_direction = 0
	_superspeed_dash_target_center_x = 0.0
	_superspeed_dash_duration_frames = 0.0
	_superspeed_dash_timer_frames = 0.0


func _spawn_superspeed_afterimages(center: Vector2) -> void:
	for index in range(SUPERSPEED_AFTERIMAGE_COUNT):
		_superspeed_afterimages.append({
			"kind": "superspeed_ghost",
			"center": center,
			"size": _superspeed_boss_size,
			"visual_scale": _superspeed_visual_scale,
			"delay_remaining_sec": float(index) * SUPERSPEED_AFTERIMAGE_DELAY_SEC,
			"age_sec": 0.0,
			"base_alpha": float(180 - index * 25) / 255.0,
			"alpha": float(180 - index * 25) / 255.0,
			"follow_speed": maxf(0.02, 0.08 - float(index) * 0.012),
			"index": index,
		})


func _update_superspeed_afterimages(frame_scale: float, delta: float) -> void:
	if _superspeed_afterimages.is_empty():
		return
	var target_center: Vector2 = _get_effect_boss_pos() + _last_boss_size * 0.5
	var write_index := 0
	for read_index in range(_superspeed_afterimages.size()):
		var ghost: Dictionary = _superspeed_afterimages[read_index]
		var previous_delay: float = maxf(0.0, float(ghost.get("delay_remaining_sec", 0.0)))
		var delay_remaining: float = maxf(0.0, previous_delay - delta)
		ghost["delay_remaining_sec"] = delay_remaining
		if delay_remaining > 0.0:
			_superspeed_afterimages[write_index] = ghost
			write_index += 1
			continue
		var active_delta: float = delta if previous_delay <= 0.0 else maxf(0.0, delta - previous_delay)
		var age_sec: float = float(ghost.get("age_sec", 0.0)) + active_delta
		if age_sec >= SUPERSPEED_AFTERIMAGE_FADE_SEC:
			continue
		var follow_speed: float = clampf(float(ghost.get("follow_speed", 0.05)), 0.0, 1.0)
		var active_frame_scale: float = frame_scale if previous_delay <= 0.0 else active_delta * LEGACY_FPS
		var follow_blend: float = 1.0 - pow(1.0 - follow_speed, active_frame_scale)
		ghost["center"] = _as_vector2(ghost.get("center", target_center), target_center).lerp(
			target_center,
			follow_blend
		)
		ghost["age_sec"] = age_sec
		ghost["alpha"] = float(ghost.get("base_alpha", 0.5)) \
			* (1.0 - age_sec / SUPERSPEED_AFTERIMAGE_FADE_SEC)
		_superspeed_afterimages[write_index] = ghost
		write_index += 1
	if write_index < _superspeed_afterimages.size():
		_superspeed_afterimages.resize(write_index)


func _spawn_superspeed_dark_particles() -> void:
	var count: int = _rng.randi_range(3, 5)
	for _index in range(count):
		var life_frames: float = float(_rng.randi_range(30, 60))
		_superspeed_dark_particles.append({
			"pos": Vector2(
				_rng.randf_range(_superspeed_boss_pos.x - 20.0, _superspeed_boss_pos.x + _superspeed_boss_size.x + 20.0),
				_rng.randf_range(_superspeed_boss_pos.y - 15.0, _superspeed_boss_pos.y + _superspeed_boss_size.y + 10.0)
			),
			"vel": Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-2.5, -0.8)),
			"radius": _rng.randf_range(3.0, 8.0),
			"life_frames": life_frames,
			"max_life_frames": life_frames,
			"color": SUPERSPEED_DARK_PALETTE[
				_rng.randi_range(0, SUPERSPEED_DARK_PALETTE.size() - 1)
			],
		})
	while _superspeed_dark_particles.size() > SUPERSPEED_DARK_PARTICLE_MAX:
		_superspeed_dark_particles.pop_front()


func _advance_superspeed_dark_particles_tick() -> void:
	var write_index := 0
	for read_index in range(_superspeed_dark_particles.size()):
		var particle: Dictionary = _superspeed_dark_particles[read_index]
		particle["pos"] = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) \
			+ _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO)
		var velocity: Vector2 = _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO)
		velocity.x *= 0.98
		velocity.y *= 0.95
		particle["vel"] = velocity
		particle["radius"] = float(particle.get("radius", 1.0)) * 0.97
		particle["life_frames"] = float(particle.get("life_frames", 0.0)) - 1.0
		if float(particle.get("life_frames", 0.0)) <= 0.0 or float(particle.get("radius", 0.0)) < 1.0:
			continue
		_superspeed_dark_particles[write_index] = particle
		write_index += 1
	if write_index < _superspeed_dark_particles.size():
		_superspeed_dark_particles.resize(write_index)


func _spawn_superspeed_trail() -> void:
	_superspeed_trails.append({
		"kind": "superspeed_trail",
		"center": _superspeed_boss_pos + _superspeed_boss_size * 0.5,
		"size": _superspeed_boss_size,
		"visual_scale": _superspeed_visual_scale,
		"alpha": 180.0 / 255.0,
	})
	while _superspeed_trails.size() > SUPERSPEED_TRAIL_MAX:
		_superspeed_trails.pop_front()


func _advance_superspeed_trails_tick() -> void:
	var write_index := 0
	for read_index in range(_superspeed_trails.size()):
		var trail: Dictionary = _superspeed_trails[read_index]
		var alpha: float = float(trail.get("alpha", 0.0)) \
			- SUPERSPEED_TRAIL_ALPHA_FADE_PER_FRAME
		if alpha <= 0.0:
			continue
		trail["alpha"] = alpha
		_superspeed_trails[write_index] = trail
		write_index += 1
	if write_index < _superspeed_trails.size():
		_superspeed_trails.resize(write_index)


func _update_particles(delta: float) -> void:
	if _particles.is_empty():
		return
	var frame_scale: float = fps_scale(delta)
	var write_index := 0
	for read_index in range(_particles.size()):
		var particle: Dictionary = _particles[read_index]
		if not particle.has("life"):
			_particles[write_index] = particle
			write_index += 1
			continue
		var life: float = float(particle.get("life", 0.0)) - delta
		if life <= 0.0:
			continue
		var pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO)
		var vel: Vector2 = _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO)
		pos += vel * frame_scale
		particle["pos"] = pos
		# 원본 혈흔은 중력 포물선(마찰 없음), 그 외 파티클은 기존 마찰 감쇠.
		if particle.has("gravity_per_frame"):
			vel.y += float(particle.get("gravity_per_frame", 0.0)) * frame_scale
			particle["vel"] = vel
		else:
			particle["vel"] = vel * pow(0.92, frame_scale)
		particle["life"] = life
		var color: Color = particle.get("color", Color(0.72, 0.05, 0.10, 0.82))
		color.a = float(particle.get("base_alpha", 0.82)) \
			* clampf(life / maxf(0.001, float(particle.get("max_life", life))), 0.0, 1.0)
		particle["color"] = color
		_particles[write_index] = particle
		write_index += 1
	if write_index < _particles.size():
		_particles.resize(write_index)


func _trigger_boss_attack(source: String, target_x: float) -> void:
	_boss_attack_remaining_sec = BOSS_ATTACK_ANIM_SEC
	_boss_attack_source = source
	_boss_attack_target_x = target_x


func _update_boss_attack(delta: float) -> void:
	_boss_attack_remaining_sec = maxf(0.0, _boss_attack_remaining_sec - delta)
	if _boss_attack_remaining_sec <= 0.0:
		_boss_attack_source = ""


func _refresh_status(skill_cooldown_paused: bool) -> void:
	if is_gameplay_freeze_active():
		status = _gameplay_freeze_reason + "_freeze"
	elif _escape_active:
		status = "escape_active"
	elif _cloud_dash_active:
		status = "cloud_" + _cloud_dash_phase
	elif _superspeed_active:
		status = "superspeed_active"
	elif skill_cooldown_paused:
		status = "paused"
	elif _clone_casting:
		status = "clone_casting"
	elif _shuriken_casting:
		status = "shuriken_casting"
	elif _boss_attack_remaining_sec > 0.0 and _boss_attack_source == "boss_paddle_hit":
		status = "boss_hit"
	elif _has_live_clones():
		status = "clone_active"
	elif not _shurikens.is_empty():
		status = "shuriken_active"
	elif _shuriken_gauge_ticks_left > 0:
		status = "shuriken_debuff"
	elif _cloud_field_active:
		status = "cloud_active"
	elif _wind_aura_depleted:
		status = "wind_aura_recharging"
	elif awakened:
		status = "awakened"
	else:
		status = "charging"


func _is_boss_skill_cooldown_paused(context: Dictionary, deps: Dictionary = {}) -> bool:
	if bool(context.get("lingpet_star_coil_freeze_boss_skill_cd", false)):
		return true
	if bool(context.get(
		"active_item_boss_skill_cooldown_paused",
		context.get("active_item_tear_gas_cooldown_pause_active", false)
	)):
		return true
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime == null or not active_item_runtime.has_method("get_boss_ai_context"):
		return false
	var boss_context: Dictionary = active_item_runtime.get_boss_ai_context()
	return bool(boss_context.get(
		"active_item_boss_skill_cooldown_paused",
		boss_context.get("active_item_tear_gas_cooldown_pause_active", false)
	))


func _get_player_rect(context: Dictionary) -> Rect2:
	var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2(302.5, 690.0)), Vector2(302.5, 690.0))
	var player_size: Vector2 = _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	return Rect2(player_pos, player_size)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
