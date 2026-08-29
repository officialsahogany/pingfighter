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

const Stage7AkamuShurikenState := preload("res://scripts/stages/stage7/stage7_akamu_shuriken_state.gd")
const Stage7AkamuCloneState := preload("res://scripts/stages/stage7/stage7_akamu_clone_state.gd")
const Stage7AkamuCloudState := preload("res://scripts/stages/stage7/stage7_akamu_cloud_state.gd")
const Stage7AkamuEscapeState := preload("res://scripts/stages/stage7/stage7_akamu_escape_state.gd")
const Stage7AkamuSuperspeedState := preload("res://scripts/stages/stage7/stage7_akamu_superspeed_state.gd")
const Stage7AkamuAwakeningState := preload("res://scripts/stages/stage7/stage7_akamu_awakening_state.gd")
const Stage7AkamuGaugeState := preload("res://scripts/stages/stage7/stage7_akamu_gauge_state.gd")
const Stage7AkamuMotionState := preload("res://scripts/stages/stage7/stage7_akamu_motion_state.gd")
const Stage7AkamuPresentationState := preload("res://scripts/stages/stage7/stage7_akamu_presentation_state.gd")
const Stage7AkamuFreezeState := preload("res://scripts/stages/stage7/stage7_akamu_freeze_state.gd")
const Stage7AkamuOdinCcState := preload("res://scripts/stages/stage7/stage7_akamu_odin_cc_state.gd")
const Stage7AkamuHudStateBuilder := preload("res://scripts/stages/stage7/stage7_akamu_hud_state_builder.gd")
const Stage7AkamuContextBuilder := preload("res://scripts/stages/stage7/stage7_akamu_context_builder.gd")
const Stage7AkamuTimingPolicy := preload("res://scripts/stages/stage7/stage7_akamu_timing_policy.gd")
const Stage7AkamuGeometryState := preload("res://scripts/stages/stage7/stage7_akamu_geometry_state.gd")
const Stage7AkamuStarpointState := preload("res://scripts/stages/stage7/stage7_akamu_starpoint_state.gd")

const STAGE_ID := 7
const BOSS_NAME := "아카무 리고"
const LEGACY_FPS := 60.0
const MAX_DELTA_SEC := 0.1
const GAUGE_MAX := Stage7AkamuGaugeState.MAX_VALUE
const ROUND_GAUGE_CARRY_RATIO := Stage7AkamuGaugeState.ROUND_CARRY_RATIO
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0

const BOSS_HIT_GAUGE_GAIN := Stage7AkamuGaugeState.BOSS_HIT_GAIN
const BOSS_HIT_AWAKENED_GAUGE_GAIN := Stage7AkamuGaugeState.AWAKENED_BOSS_HIT_GAIN
const BOSS_HIT_SUPERSPEED_GAUGE_GAIN := Stage7AkamuGaugeState.SUPERSPEED_BOSS_HIT_GAIN
const BOSS_ATTACK_ANIM_SEC := Stage7AkamuPresentationState.BOSS_ATTACK_ANIM_SEC

const AWAKEN_SCORE_THRESHOLD := Stage7AkamuAwakeningState.SCORE_THRESHOLD
const AWAKEN_FREEZE_SEC := Stage7AkamuAwakeningState.FREEZE_SEC

const SUPERSPEED_DURATION_SEC := Stage7AkamuSuperspeedState.DURATION_SEC
const SUPERSPEED_ACTIVATION_FREEZE_SEC := Stage7AkamuSuperspeedState.ACTIVATION_FREEZE_SEC

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
const SUPERSPEED_GAUGE_COST := Stage7AkamuSuperspeedState.GAUGE_COST
const COMMON_BOSS_DASH_GAUGE_COST := Stage7AkamuGaugeState.COMMON_DASH_COST

const CLOUD_INTANGIBLE_SOURCE := Stage7AkamuCloudState.INTANGIBLE_SOURCE

const ESCAPE_INTANGIBLE_SOURCE := Stage7AkamuEscapeState.INTANGIBLE_SOURCE

var _skill_cooldown_paused := false

var _rng := RandomNumberGenerator.new()
var _shuriken_state: Object = Stage7AkamuShurikenState.new()
var _clone_state: Object = Stage7AkamuCloneState.new()
var _starpoint_state: Object = Stage7AkamuStarpointState.new(_rng)
var _cloud_state: Object = Stage7AkamuCloudState.new()
var _escape_state: Object = Stage7AkamuEscapeState.new()
var _superspeed_state: Object = Stage7AkamuSuperspeedState.new()
var _awakening_state: Object = Stage7AkamuAwakeningState.new()
var _gauge_state: Object = Stage7AkamuGaugeState.new()
var _motion_state: Object = Stage7AkamuMotionState.new()
var _presentation_state: Object = Stage7AkamuPresentationState.new()
var _freeze_state: Object = Stage7AkamuFreezeState.new()
var _odin_cc_state: Object = Stage7AkamuOdinCcState.new()
var _hud_state_builder: Object = Stage7AkamuHudStateBuilder.new()
var _context_builder: Object = Stage7AkamuContextBuilder.new()
var _timing_policy: Object = Stage7AkamuTimingPolicy.new()
var _geometry_state: Object = Stage7AkamuGeometryState.new()

# Compatibility properties retained for production integrations and existing
# diagnostics. Raw public writes remain raw; internal mutations use owner APIs.
var boss_special_gauge: float:
	get:
		return _gauge_state.value
	set(value):
		_gauge_state.set_raw(value)

var _has_score_round_generation: bool:
	get:
		return _gauge_state.has_score_round_generation
	set(value):
		_gauge_state.has_score_round_generation = value

var _last_score_round_generation: int:
	get:
		return _gauge_state.last_score_round_generation
	set(value):
		_gauge_state.last_score_round_generation = value

# Compatibility properties retained for production consumers, smoke fixtures,
# and older diagnostics. Mutable position/intangibility ownership lives only in
# Stage7AkamuMotionState.
var _boss_ball_intangible: bool:
	get:
		return _motion_state.boss_ball_intangible
	set(value):
		_motion_state.boss_ball_intangible = value

var _scripted_motion_active: bool:
	get:
		return _motion_state.scripted_motion_active
	set(value):
		_motion_state.scripted_motion_active = value

var _scripted_boss_pos: Vector2:
	get:
		return _motion_state.scripted_boss_pos
	set(value):
		_motion_state.scripted_boss_pos = value

var _debug_scripted_motion_active: bool:
	get:
		return _motion_state.debug_scripted_motion_active
	set(value):
		_motion_state.debug_scripted_motion_active = value

var _debug_scripted_boss_pos: Vector2:
	get:
		return _motion_state.debug_scripted_boss_pos
	set(value):
		_motion_state.debug_scripted_boss_pos = value

var _external_scripted_motion_active: bool:
	get:
		return _motion_state.external_scripted_motion_active
	set(value):
		_motion_state.external_scripted_motion_active = value

var _boss_position_release_pending: bool:
	get:
		return _motion_state.release_pending
	set(value):
		_motion_state.release_pending = value

var _boss_position_release_pos: Vector2:
	get:
		return _motion_state.release_pos
	set(value):
		_motion_state.release_pos = value

# Compatibility properties retained for actor/HUD consumers and diagnostics.
# Mutable attack-pose/status ownership lives only in the presentation owner.
var status: String:
	get:
		return _presentation_state.status
	set(value):
		_presentation_state.set_status(value)

# Compatibility properties retained for production consumers, smoke fixtures,
# and older diagnostics. Mutable ownership lives only in the focused owner.
var awakened: bool:
	get:
		return _awakening_state.awakened
	set(value):
		_awakening_state.awakened = value

var _awakening_trigger_armed: bool:
	get:
		return _awakening_state.trigger_armed
	set(value):
		_awakening_state.trigger_armed = value

var _awakening_intro_pending: bool:
	get:
		return _awakening_state.intro_pending
	set(value):
		_awakening_state.intro_pending = value

var _awakening_intro_done: bool:
	get:
		return _awakening_state.intro_done
	set(value):
		_awakening_state.intro_done = value

var _wind_aura_active: bool:
	get:
		return _awakening_state.active
	set(value):
		_awakening_state.active = value

var _wind_aura_hit_count: int:
	get:
		return _awakening_state.hit_count
	set(value):
		_awakening_state.hit_count = value

var _wind_aura_depleted: bool:
	get:
		return _awakening_state.depleted
	set(value):
		_awakening_state.depleted = value

var _wind_aura_recharge_remaining_sec: float:
	get:
		return _awakening_state.recharge_remaining_sec
	set(value):
		_awakening_state.recharge_remaining_sec = value

var _wind_aura_hit_cooldown_remaining_sec: float:
	get:
		return _awakening_state.hit_cooldown_remaining_sec
	set(value):
		_awakening_state.hit_cooldown_remaining_sec = value

var _wind_aura_ripple_remaining_sec: float:
	get:
		return _awakening_state.ripple_remaining_sec
	set(value):
		_awakening_state.ripple_remaining_sec = value

var _wind_aura_elapsed_sec: float:
	get:
		return _awakening_state.elapsed_sec
	set(value):
		_awakening_state.elapsed_sec = value

var _wind_aura_free_clone_queued: bool:
	get:
		return _awakening_state.free_clone_queued
	set(value):
		_awakening_state.free_clone_queued = value

var _wind_aura_particles: Array:
	get:
		return _awakening_state.particles
	set(value):
		_awakening_state.particles = value

var _wind_burst_particles: Array:
	get:
		return _awakening_state.burst_particles
	set(value):
		_awakening_state.burst_particles = value

var _wind_aura_draw_context: Dictionary:
	get:
		return _awakening_state.draw_context
	set(value):
		_awakening_state.draw_context = value

# Compatibility properties retained for production consumers, smoke fixtures,
# and older diagnostics. Mutable ownership lives only in the focused owner.
var _superspeed_active: bool:
	get:
		return _superspeed_state.active
	set(value):
		_superspeed_state.active = value

var _superspeed_remaining_sec: float:
	get:
		return _superspeed_state.remaining_sec
	set(value):
		_superspeed_state.remaining_sec = value

var _superspeed_text_remaining_sec: float:
	get:
		return _superspeed_state.text_remaining_sec
	set(value):
		_superspeed_state.text_remaining_sec = value

var _superspeed_cooldown_remaining_sec: float:
	get:
		return _superspeed_state.cooldown_remaining_sec
	set(value):
		_superspeed_state.cooldown_remaining_sec = value

var _superspeed_dash_active: bool:
	get:
		return _superspeed_state.dash_active
	set(value):
		_superspeed_state.dash_active = value

var _superspeed_dash_timer_frames: float:
	get:
		return _superspeed_state.dash_timer_frames
	set(value):
		_superspeed_state.dash_timer_frames = value

var _superspeed_dash_duration_frames: float:
	get:
		return _superspeed_state.dash_duration_frames
	set(value):
		_superspeed_state.dash_duration_frames = value

var _superspeed_dash_direction: int:
	get:
		return _superspeed_state.dash_direction
	set(value):
		_superspeed_state.dash_direction = value

var _superspeed_dash_target_center_x: float:
	get:
		return _superspeed_state.dash_target_center_x
	set(value):
		_superspeed_state.dash_target_center_x = value

var _superspeed_dash_recovery_frames: float:
	get:
		return _superspeed_state.dash_recovery_frames
	set(value):
		_superspeed_state.dash_recovery_frames = value

var _superspeed_motion_frame_accumulator: float:
	get:
		return _superspeed_state.motion_frame_accumulator
	set(value):
		_superspeed_state.motion_frame_accumulator = value

var _superspeed_boss_pos: Vector2:
	get:
		return _superspeed_state.boss_pos
	set(value):
		_superspeed_state.boss_pos = value

var _superspeed_boss_size: Vector2:
	get:
		return _superspeed_state.boss_size
	set(value):
		_superspeed_state.boss_size = value

var _superspeed_visual_scale: float:
	get:
		return _superspeed_state.visual_scale
	set(value):
		_superspeed_state.visual_scale = value

var _superspeed_trail_spawn_accumulator: float:
	get:
		return _superspeed_state.trail_spawn_accumulator
	set(value):
		_superspeed_state.trail_spawn_accumulator = value

var _superspeed_afterimages: Array:
	get:
		return _superspeed_state.afterimages
	set(value):
		_superspeed_state.afterimages = value

var _superspeed_dark_particles: Array:
	get:
		return _superspeed_state.dark_particles
	set(value):
		_superspeed_state.dark_particles = value

var _superspeed_trails: Array:
	get:
		return _superspeed_state.trails
	set(value):
		_superspeed_state.trails = value

# Compatibility properties retained for smoke fixtures and older diagnostics.
# Mutable ownership lives only in Stage7AkamuCloudState.
var _cloud_draw_context: Dictionary:
	get:
		return _cloud_state.draw_context
	set(value):
		_cloud_state.draw_context = value

var _aura_draw_context: Dictionary:
	get:
		return _cloud_state.aura_draw_context
	set(value):
		_cloud_state.aura_draw_context = value

var _escape_active: bool:
	get:
		return _escape_state.active
	set(value):
		_escape_state.active = value

var _escape_elapsed_sec: float:
	get:
		return _escape_state.elapsed_sec
	set(value):
		_escape_state.elapsed_sec = value

var _escape_start_boss_pos: Vector2:
	get:
		return _escape_state.start_boss_pos
	set(value):
		_escape_state.start_boss_pos = value

var _escape_target_boss_pos: Vector2:
	get:
		return _escape_state.target_boss_pos
	set(value):
		_escape_state.target_boss_pos = value

var _escape_boss_size: Vector2:
	get:
		return _escape_state.boss_size
	set(value):
		_escape_state.boss_size = value

var _escape_visual_scale: float:
	get:
		return _escape_state.visual_scale
	set(value):
		_escape_state.visual_scale = value

var _escape_episode_active: bool:
	get:
		return _escape_state.episode_active
	set(value):
		_escape_state.episode_active = value

var _escape_attempted: bool:
	get:
		return _escape_state.attempted
	set(value):
		_escape_state.attempted = value

var _escape_ready_remaining_sec: float:
	get:
		return _escape_state.ready_remaining_sec
	set(value):
		_escape_state.ready_remaining_sec = value

var _escape_last_released_net_count: int:
	get:
		return _escape_state.last_released_net_count
	set(value):
		_escape_state.last_released_net_count = value

var _afterimages: Array:
	get:
		return _escape_state.afterimages
	set(value):
		_escape_state.afterimages = value

var _hologram_draw_context: Dictionary:
	get:
		return _escape_state.hologram_draw_context
	set(value):
		_escape_state.hologram_draw_context = value

# Compatibility property retained for smoke fixtures and older diagnostics.
# Mutable ownership lives only in Stage7AkamuCloneState.
var _clones: Array:
	get:
		return _clone_state.entities
	set(value):
		_clone_state.entities = value

var _clone_casting: bool:
	get:
		return bool(_clone_state.casting)
	set(value):
		_clone_state.casting = value

# Compatibility properties retained for smoke fixtures and older diagnostics.
# Mutable ownership lives only in Stage7AkamuShurikenState.
var _shurikens: Array:
	get:
		return _shuriken_state.projectiles
	set(value):
		_shuriken_state.projectiles = value

var _shuriken_casting: bool:
	get:
		return bool(_shuriken_state.casting)
	set(value):
		_shuriken_state.casting = value

var _particles: Array:
	get:
		return _shuriken_state.hit_particles
	set(value):
		_shuriken_state.hit_particles = value

var _shuriken_pending_remaining: Array:
	get:
		return _shuriken_state.pending_remaining
	set(value):
		_shuriken_state.pending_remaining = value

var _shuriken_gauge_ticks_left: int:
	get:
		return int(_shuriken_state.gauge_ticks_left)
	set(value):
		_shuriken_state.gauge_ticks_left = value

var _shuriken_gauge_tick_frames_remaining: float:
	get:
		return float(_shuriken_state.gauge_tick_frames_remaining)
	set(value):
		_shuriken_state.gauge_tick_frames_remaining = value


func _init() -> void:
	_rng.randomize()


static func fps_scale(delta: float) -> float:
	return clampf(delta, 0.0, MAX_DELTA_SEC) * LEGACY_FPS


static func legacy_motion_step(pixels_per_frame: float, delta: float) -> float:
	return pixels_per_frame * fps_scale(delta)


func reset() -> void:
	clear_round_transients()
	_geometry_state.reset()
	# 스킬 쿨타임은 라운드 간 유지된다(clear_round_transients). 완전 리셋
	# (새 게임 0-0 / 스테이지 이탈 / result)은 각 owner의 명시적 초기 대기로
	# 되돌린다. 분신/구름은 즉시-ready가 아니며 수리검은 첫 live tick에 arm된다.
	_shuriken_state.reset_full()
	_clone_state.reset_full()
	_cloud_state.reset_full()
	_escape_state.reset_full()
	_superspeed_state.reset_full()
	_awakening_state.reset_full()
	_gauge_state.reset_full()
	_motion_state.reset_full()
	_presentation_state.reset_full()
	_freeze_state.reset_full()
	_odin_cc_state.reset_full()


func reset_for_result() -> void:
	reset()


func clear_round_transients() -> void:
	# Intentionally idempotent. Generic ball cleanup may reach this more than
	# once for one score boundary, so this method must never alter persistent
	# gauge/awakening state.
	_awakening_state.clear_round_transients()
	_superspeed_state.clear_round_transients()
	_freeze_state.clear_round_transients()
	_odin_cc_state.clear_snapshot()
	# The accepted score event arms Awakening before the generic ball-reset
	# cleanup runs. Keep that arm across this idempotent transient cleanup; only
	# an already-running intro/freeze is cancelled and retried after serve.
	_motion_state.clear_round_transients()
	_presentation_state.clear_round_transients()
	# 스킬 쿨타임은 라운드 경계를 넘어 유지된다(원본 stage8 파리티: reset_round의
	# stage-8 분기는 승/패 애니메이션만 리셋하고 쿨타임은 wall-clock으로 지속).
	# 완전 리셋(reset())에서만 0으로 초기화한다. 여기서는 진행 중 캐스트/위치/
	# 파티클 같은 transient만 정리한다.
	_skill_cooldown_paused = false
	_cloud_state.clear_round_transients()
	_escape_state.clear_round_transients()
	_clone_state.clear_round_transients()
	_starpoint_state.clear()
	# 수리검 스케줄러/쿨다운은 라운드 간 유지하고 전투 중 상태만 정리한다.
	_shuriken_state.clear_round_transients()
	# Awakening and its durability/recharge state survive normal score cleanup.
	# Rebuild the payload after transient position writers (cloud/Superspeed/etc.)
	# have been cleared so the persistent aura cannot remain pinned to their last
	# authored position during the serve wait.
	_sync_awakening_draw_context()


func reset_round() -> void:
	# Compatibility alias for older stage cleanup fanouts. Gauge carry belongs
	# exclusively to apply_score_round_carry().
	clear_round_transients()


func apply_score_round_carry(round_generation: int) -> bool:
	# A score event and the later ball-reset path can describe the same round.
	# Accept only a newer generation so the 0.7 carry cannot be applied twice.
	return _gauge_state.apply_score_round_carry(round_generation)


func handle_score_event(_scoring_side: String, score_result: Dictionary) -> void:
	# Godot's match_score_state.player_score is the live rally-win counter that
	# corresponds to legacy round_wins. Arm here, after an accepted score, but do
	# not start the 3-second freeze under the scoreboard overlay.
	_awakening_state.handle_score_event(score_result)


func try_begin_pending_awakening() -> bool:
	if not _awakening_state.try_begin_intro(is_gameplay_freeze_active()):
		return false
	_freeze_state.begin("awakening", AWAKEN_FREEZE_SEC)
	status = "awakening_freeze"
	return true


func _sync_awakening_trigger(context: Dictionary) -> void:
	_awakening_state.sync_trigger(context)


func _complete_awakening(context: Dictionary = {}, _deps: Dictionary = {}) -> void:
	if not _awakening_intro_pending:
		return
	_geometry_state.sync(context)
	_awakening_state.complete_awakening(
		_geometry_state.boss_pos + _geometry_state.boss_size * 0.5,
		_rng,
		_superspeed_active
	)
	status = "awakened"
	# R5 intentionally departs from legacy here. Legacy checked a gauge-ready
	# ultimate immediately and used 25 seconds only after a completed cast. The
	# unlock now arms the same 50-second owner cooldown used after every cast, so
	# the first activation cannot chain directly out of the Awakening freeze.
	_superspeed_state.set_cooldown_remaining(Stage7AkamuSuperspeedState.COOLDOWN_SEC)


func update(delta: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	_motion_state.set_external_scripted_motion_active(bool(context.get("lingpet_puppet_grab_active", false)))
	_geometry_state.sync(context)
	_odin_cc_state.sync_from_deps(deps)
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		if _has_runtime_state():
			reset()
		return _build_result()

	var clamped_delta := clampf(delta, 0.0, MAX_DELTA_SEC)
	if is_gameplay_freeze_active():
		return advance_gameplay_freeze(clamped_delta, context, deps)
	var frame_scale: float = fps_scale(clamped_delta)
	# Match the established Stage 5 reward policy: already-falling Muhon keeps
	# moving through serve wait and ordinary timing pauses, but the explicit
	# Awakening gameplay freeze above still freezes it.
	_starpoint_state.update(frame_scale, context, deps)
	if _timing_policy.is_gameplay_timing_frozen(context):
		_skill_cooldown_paused = false
		# Keep persistent draw ownership attached to the live boss while every
		# gameplay/aura timer remains frozen by this early return.
		_sync_awakening_draw_context()
		status = "paused"
		return _build_result()
	_sync_awakening_trigger(context)
	if try_begin_pending_awakening():
		return _build_result()

	var result: Dictionary = {}
	# A completed scripted move publishes its exact final position once. Clear
	# the previous frame's delivery before advancing this frame's state.
	_motion_state.begin_frame()
	var skill_cooldown_paused: bool = _timing_policy.is_boss_skill_cooldown_paused(context, deps)
	var superspeed_was_active: bool = _superspeed_active
	_skill_cooldown_paused = skill_cooldown_paused
	_presentation_state.update_boss_attack(clamped_delta)
	_update_particles(clamped_delta)
	_update_wind_effects(frame_scale, clamped_delta, context, skill_cooldown_paused)
	_update_superspeed(frame_scale, clamped_delta, context)
	_escape_state.update_hologram(clamped_delta)
	_update_shadow_clones(frame_scale, clamped_delta, deps)
	_update_clone_invulnerability(clamped_delta)
	_update_cloud(clamped_delta, deps)
	_update_escape_motion(clamped_delta)
	_update_shuriken_projectiles(frame_scale, clamped_delta, context, deps, result)
	_update_shuriken_gauge_drain(frame_scale, context, result)

	if not skill_cooldown_paused:
		_clone_state.tick_cooldown(clamped_delta)
		_cloud_state.tick_cooldown(clamped_delta)
		if not superspeed_was_active:
			_superspeed_state.tick_cooldown(clamped_delta)
		_awakening_state.tick_recharge(
			clamped_delta,
			_rng,
			_get_effect_boss_pos() + _geometry_state.boss_size * 0.5,
			_superspeed_active
		)
		if _try_start_superspeed(context):
			_sync_presentation_status(false)
			result.merge(_build_result(), true)
			return result
		_update_wind_aura_free_clone_queue(context)
		_update_escape_trigger(clamped_delta, context, deps)
		_update_pending_shurikens(clamped_delta, context, deps)
		if _clone_state.casting:
			_update_clone_cast(clamped_delta, deps)
		elif _shuriken_state.casting:
			_update_shuriken_cast(clamped_delta, context, deps)
		else:
			_update_shuriken_scheduler(clamped_delta, context)

	_sync_presentation_status(skill_cooldown_paused)
	result.merge(_build_result(), true)
	return result


func is_gameplay_freeze_active() -> bool:
	return _freeze_state.is_active()


func advance_gameplay_freeze(delta: float, context: Dictionary = {}, deps: Dictionary = {}) -> Dictionary:
	_motion_state.set_external_scripted_motion_active(bool(context.get("lingpet_puppet_grab_active", false)))
	_geometry_state.sync(context)
	_skill_cooldown_paused = _timing_policy.is_boss_skill_cooldown_paused(context, deps)
	var clamped_delta := clampf(delta, 0.0, MAX_DELTA_SEC)
	var frame_scale: float = fps_scale(clamped_delta)
	_awakening_state.advance_freeze_visuals(
		frame_scale,
		clamped_delta,
		_get_effect_boss_pos() + _geometry_state.boss_size * 0.5,
		_superspeed_active
	)
	_superspeed_state.advance_freeze(clamped_delta)
	var completed_reason: String = _freeze_state.advance(clamped_delta)
	if completed_reason == "awakening":
		_complete_awakening(context, deps)
	status = (
		_freeze_state.reason + "_freeze"
		if is_gameplay_freeze_active()
		else ("superspeed_active" if _superspeed_active else "charging")
	)
	return _build_result()


func is_boss_ball_intangible() -> bool:
	return _motion_state.boss_ball_intangible


func set_boss_ball_intangible_source(source: String, active: bool) -> void:
	_motion_state.set_boss_ball_intangible_source(
		source,
		active,
		_clone_state.is_boss_intangible()
	)


func resolve_wind_aura_collision(
	ball_pos: Vector2,
	ball_vel: Vector2,
	context: Dictionary,
	deps: Dictionary = {}
) -> Dictionary:
	var boss_pos: Vector2 = _geometry_state.resolve_position(context)
	var boss_size: Vector2 = _geometry_state.resolve_size(context)
	var boss_center: Vector2 = boss_pos + boss_size * 0.5
	var skill_cooldown_paused_now: bool = _timing_policy.is_context_boss_skill_cooldown_paused(context)
	var collision_allowed: bool = (
		not bool(context.get("waiting_for_serve", false))
		and bool(context.get("ball_active", true))
		and _is_player_owned_ball(context, deps)
	)
	var result: Dictionary = _awakening_state.resolve_collision(
		ball_pos,
		ball_vel,
		boss_center,
		collision_allowed,
		skill_cooldown_paused_now,
		_superspeed_active,
		_rng
	)
	if result.is_empty():
		return result
	var audio: Object = deps.get("audio", context.get("stage7_akamu_audio", null))
	# Exact legacy ninjashield.wav cue, promoted as the Stage 7 aura-block
	# one-shot. Keep the facade optional for headless and focused state tests.
	if audio != null and audio.has_method("play_stage7_akamu_wind_aura_block"):
		audio.play_stage7_akamu_wind_aura_block()
	_gauge_state.add(float(result.get("_wind_aura_gauge_gain", 0.0)))

	# The Python clone branch is dead from a missing `global`, and allowing its
	# intended concurrent start would create two authoritative boss-position
	# writers. Restore both independent rolls, but preserve source order: a
	# successful free cloud claims this frame; clone may start only if no writer
	# was claimed. Superspeed suppresses both while it owns movement.
	var cloud_roll: bool = bool(result.get("_wind_aura_cloud_roll", false))
	var clone_roll: bool = bool(result.get("_wind_aura_clone_roll", false))
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
		if clone_roll and not _clone_state.casting and not _has_live_clones():
			if free_cloud_started:
				# Preserve the independent 30% clone success without introducing a
				# simultaneous second position writer. It commits as soon as the
				# cloud dash releases that writer (the cloud field may remain).
				_awakening_state.queue_free_clone()
			else:
				_try_start_clone_cast(context, true, true, "wind_aura", true)
	if bool(result.get("_wind_aura_disperse_burst_pending", false)):
		_awakening_state.spawn_depletion_burst(boss_center, _rng, _superspeed_active)
	result.erase("_wind_aura_gauge_gain")
	result.erase("_wind_aura_cloud_roll")
	result.erase("_wind_aura_clone_roll")
	result.erase("_wind_aura_disperse_burst_pending")
	return result


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
	return _clone_state.query_ball_collision(from_pos, to_pos, ball_radius)


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
	if clone_index < 0 or clone_index >= _clone_state.entities.size():
		return false
	# Capture reward data from the collision result before begin_dying mutates
	# the entity. Never re-index the mutable array for golden/position state.
	var clone_rect_value: Variant = clone_hit.get("clone_rect", Rect2())
	var clone_rect: Rect2 = (
		clone_rect_value
		if clone_rect_value is Rect2
		else _clone_state.rect_for_index(clone_index)
	)
	var clone_center: Vector2 = _as_vector2(
		clone_hit.get("clone_center", clone_rect.get_center()),
		clone_rect.get_center()
	)
	var golden: bool = bool(clone_hit.get("golden", false))
	var contact_point: Vector2 = _as_vector2(clone_hit.get("point", ball_pos), ball_pos)
	_apply_clone_ball_reflection(scene, context, deps, clone_rect, contact_point)
	_register_auxiliary_paddle_hit(deps)
	if golden:
		for _drop_index in range(Stage7AkamuCloneState.TEMP_GOLDEN_MUHON_DROPS):
			_starpoint_state.spawn(clone_center)
	_clone_state.begin_dying(clone_index, deps)
	_register_clone_ball_contact(deps)
	return true


func handle_boss_paddle_hit(scene: Dictionary, context: Dictionary, deps: Dictionary = {}) -> void:
	# Called only after a normal boss-paddle reflection has committed. Keep this
	# a pure notification boundary: mutate Stage 7 state, never the shared bounce.
	var ball_pos: Vector2 = _as_vector2(scene.get("ball_pos", context.get("ball_pos", Vector2.ZERO)), Vector2.ZERO)
	_presentation_state.trigger_boss_attack("boss_paddle_hit", ball_pos.x)
	if _timing_policy.is_boss_skill_cooldown_paused(context, deps):
		return
	_gauge_state.add_boss_hit(awakened, _superspeed_active)
	_try_start_clone_cast(context, false, false, "boss_paddle_hit")
	_try_start_cloud(context, deps, false, false, "boss_paddle_hit")


func drain_boss_special_gauge(amount: float) -> void:
	_gauge_state.drain(amount)


func try_commit_common_boss_dash() -> bool:
	# Superspeed uses its own free predictive branch. Every ordinary Stage 7
	# emergency dash commits the legacy 50-gauge cost only after AI geometry and
	# chance gates have accepted the dash.
	return _gauge_state.try_commit_common_dash(_superspeed_active)


func get_boss_ai_context() -> Dictionary:
	return _context_builder.build_boss_ai_context(
		boss_special_gauge,
		awakened,
		_freeze_state,
		_motion_state,
		_clone_state,
		_shuriken_state,
		_cloud_state,
		_escape_state,
		_superspeed_state,
		self
	)


func get_actor_draw_context() -> Dictionary:
	return _context_builder.build_actor_draw_context(
		boss_special_gauge,
		awakened,
		status,
		BOSS_ATTACK_ANIM_SEC,
		SUPERSPEED_DURATION_SEC,
		_freeze_state,
		_motion_state,
		_presentation_state,
		_awakening_state,
		_clone_state,
		_starpoint_state,
		_shuriken_state,
		_cloud_state,
		_escape_state,
		_superspeed_state
	)


func get_hud_context(_stage_background: Object = null, _context: Dictionary = {}) -> Dictionary:
	return {
		"stage7_boss_skill_hud_active": true,
		"stage7_boss_skill_hud_boss_name": BOSS_NAME,
		"stage7_boss_skill_hud_status": status,
		"stage7_boss_skill_hud_gauge": boss_special_gauge,
		"stage7_boss_skill_hud_gauge_max": GAUGE_MAX,
		"stage7_boss_skill_hud_awakened": awakened,
		"stage7_boss_skill_hud_skills": _hud_state_builder.build_skills(
			boss_special_gauge,
			awakened,
			status,
			_skill_cooldown_paused,
			_clone_state,
			_shuriken_state,
			_cloud_state,
			_escape_state,
			_superspeed_state,
			_motion_state
		),
	}


func should_skip_ball_motion_step() -> bool:
	return false


func get_status() -> String:
	return status


func _build_result() -> Dictionary:
	# Do not emit a false ownership flag: effects results can be merged with an
	# unrelated ball-owning feature, where `skip_ball_motion_step = false` would
	# silently release that feature's ball. Stage 7 freeze is queried directly.
	return _motion_state.build_position_result(
		_odin_cc_state.knockback_window_active,
		_odin_cc_state.stun_residual
	)


func _has_runtime_state() -> bool:
	return _gauge_state.has_runtime_state() \
		or _awakening_state.has_runtime_state() \
		or _freeze_state.has_runtime_state() \
		or _motion_state.has_runtime_state() \
		or _presentation_state.has_runtime_state() \
		or _superspeed_state.has_runtime_state() \
		or _cloud_state.has_runtime_state() \
		or _escape_state.has_runtime_state() \
		or _clone_state.has_runtime_state() \
		or _starpoint_state.has_runtime_state() \
		or _shuriken_state.has_runtime_state() \
		or not _clones.is_empty()


func debug_set_gauge(value: float) -> void:
	_gauge_state.set_clamped(value)


func debug_get_gauge() -> float:
	return _gauge_state.value


func debug_set_awakened(value: bool) -> void:
	_awakening_state.set_debug_awakened(value)


func debug_is_awakened() -> bool:
	return awakened


func debug_begin_gameplay_freeze(duration_sec: float) -> void:
	_freeze_state.begin("awakening", duration_sec)


func debug_set_boss_ball_intangible(value: bool) -> void:
	set_boss_ball_intangible_source("debug", value)


func debug_set_scripted_boss_position(active: bool, pos: Vector2 = Vector2.ZERO) -> void:
	_motion_state.set_debug_scripted_position(active, pos)
	_sync_scripted_motion()


func debug_seed_rng(seed_value: int) -> void:
	_rng.seed = seed_value


func debug_set_superspeed_active(value: bool) -> void:
	_superspeed_state.set_debug_active(value)


func debug_force_complete_awakening(
	boss_pos: Vector2 = Vector2(330.0, 25.0),
	boss_size: Vector2 = Vector2(100.0, 40.0)
) -> void:
	_geometry_state.set_snapshot(boss_pos, boss_size)
	_awakening_trigger_armed = true
	_awakening_intro_pending = true
	_complete_awakening()


func debug_get_wind_aura_snapshot() -> Dictionary:
	return _awakening_state.get_snapshot()


func debug_clear_wind_aura_hit_cooldown() -> void:
	_awakening_state.clear_hit_cooldown()


func debug_start_superspeed(context: Dictionary) -> bool:
	return _try_start_superspeed(context)


func debug_set_superspeed_cooldown_remaining(value: float) -> void:
	_superspeed_state.set_cooldown_remaining(value)


func debug_get_superspeed_snapshot() -> Dictionary:
	return _superspeed_state.get_snapshot()


func debug_start_clone_cast(
	context: Dictionary,
	free_cast: bool = false,
	# Behavior fixtures should not inherit the production reset rail by
	# accident. Cooldown-specific tests pass this argument explicitly.
	bypass_cooldown: bool = true
) -> bool:
	return _try_start_clone_cast(context, true, free_cast, "debug", bypass_cooldown)


func debug_spawn_shadow_clones(center: Vector2, awakened_override: bool = false) -> void:
	_spawn_shadow_clones(center, awakened_override)
	_clone_state.set_cooldown_remaining(Stage7AkamuCloneState.COOLDOWN_SEC)


func debug_set_clone_cooldown_remaining(value: float) -> void:
	_clone_state.set_cooldown_remaining(value)


func debug_get_clone_snapshot() -> Dictionary:
	return _clone_state.get_snapshot()


func debug_set_clone_golden(index: int, value: bool) -> bool:
	return _clone_state.debug_set_golden(index, value)


func debug_spawn_starpoint_drop_at(pos: Vector2) -> void:
	_starpoint_state.spawn(pos)


func debug_patch_starpoint_drop(index: int, values: Dictionary) -> bool:
	return _starpoint_state.debug_patch_drop(index, values)


func debug_get_starpoint_snapshot() -> Dictionary:
	return _starpoint_state.get_snapshot()


func debug_has_runtime_state() -> bool:
	return _has_runtime_state()


func debug_set_shuriken_cooldown_remaining(value: float, total: float = -1.0) -> void:
	_shuriken_state.set_cooldown_remaining(value, total)


func debug_spawn_shuriken(origin: Vector2, target: Vector2, from_pending: bool = false) -> void:
	_append_shuriken(origin, target, from_pending)


func debug_get_shuriken_snapshot() -> Dictionary:
	return _shuriken_state.get_snapshot()


func debug_start_cloud(
	context: Dictionary,
	deps: Dictionary = {},
	free_cast: bool = false,
	bypass_cooldown: bool = true
) -> bool:
	return _try_start_cloud(context, deps, true, free_cast, "debug", bypass_cooldown)


func debug_set_cloud_cooldown_remaining(value: float, total: float = -1.0) -> void:
	_cloud_state.set_cooldown_remaining(value, total)


func debug_get_cloud_snapshot() -> Dictionary:
	return _cloud_state.get_snapshot()


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
	return _escape_state.get_snapshot()


func _try_start_cloud(
	context: Dictionary,
	_deps: Dictionary,
	force_roll: bool,
	free_cast: bool,
	source: String,
	bypass_cooldown: bool = false
) -> bool:
	var blocked_by_other_skill: bool = (
		_superspeed_active
		or _has_scripted_skill_conflict("cloud")
	)
	var result: Dictionary = _cloud_state.try_start(
		context,
		boss_special_gauge,
		force_roll,
		free_cast,
		bypass_cooldown,
		blocked_by_other_skill,
		_rng
	)
	if result.is_empty():
		return false
	_gauge_state.commit_result(result)
	set_boss_ball_intangible_source(CLOUD_INTANGIBLE_SOURCE, true)
	_sync_scripted_motion()
	_presentation_state.trigger_boss_attack(
		"cloud_" + source,
		float(result.get("attack_target_x", 0.0))
	)
	return true


func _update_cloud(delta: float, deps: Dictionary) -> void:
	var was_dash_active: bool = _cloud_state.dash_active
	var events: Dictionary = _cloud_state.advance(delta, deps)
	if bool(events.get("intangibility_expired", false)):
		set_boss_ball_intangible_source(CLOUD_INTANGIBLE_SOURCE, false)
	if bool(events.get("released", false)):
		_motion_state.publish_release(events.get("release_pos", Vector2.ZERO) as Vector2)
	if was_dash_active:
		_sync_scripted_motion()


func _update_escape_trigger(delta: float, context: Dictionary, deps: Dictionary) -> void:
	var blocked_by_other_skill: bool = (
		_superspeed_active
		or _has_scripted_skill_conflict("escape")
	)
	var start_result: Dictionary = _escape_state.update_trigger(
		delta,
		context,
		deps,
		boss_special_gauge,
		blocked_by_other_skill,
		_odin_cc_state.get_escape_rewind_x(),
		_rng
	)
	_apply_escape_start_result(start_result)


func _start_escape(
	context: Dictionary,
	deps: Dictionary,
	disable_context: Dictionary,
	free_cast: bool
) -> bool:
	var blocked_by_other_skill: bool = (
		_superspeed_active
		or _has_scripted_skill_conflict("escape")
	)
	var start_result: Dictionary = _escape_state.try_start(
		context,
		deps,
		disable_context,
		free_cast,
		boss_special_gauge,
		blocked_by_other_skill,
		_odin_cc_state.get_escape_rewind_x()
	)
	return _apply_escape_start_result(start_result)


func _apply_escape_start_result(start_result: Dictionary) -> bool:
	if not bool(start_result.get("started", false)):
		return false
	_gauge_state.commit_result(start_result)
	set_boss_ball_intangible_source(ESCAPE_INTANGIBLE_SOURCE, true)
	_sync_scripted_motion()
	_presentation_state.trigger_boss_attack(
		"escape",
		float(start_result.get("attack_target_x", 0.0))
	)
	return true


func _update_escape_motion(delta: float) -> void:
	if not _escape_state.active:
		return
	var events: Dictionary = _escape_state.advance(delta)
	if bool(events.get("released", false)):
		_motion_state.publish_release(events.get("release_pos", Vector2.ZERO) as Vector2)
		set_boss_ball_intangible_source(ESCAPE_INTANGIBLE_SOURCE, false)
	_sync_scripted_motion()


func _has_scripted_skill_conflict(requester: String) -> bool:
	return _motion_state.has_scripted_skill_conflict_fields(
		requester,
		_escape_state.active,
		_cloud_state.dash_active,
		_superspeed_active,
		_clone_state.casting,
		_shuriken_state.casting
	)


func _try_start_clone_cast(
	context: Dictionary,
	force_roll: bool,
	free_cast: bool,
	source: String,
	bypass_cooldown: bool = false
) -> bool:
	var blocked_by_other_skill: bool = (
		_has_scripted_skill_conflict("clone")
		or bool(context.get("lingpet_puppet_grab_active", false))
	)
	if not _clone_state.try_start_cast(
		context,
		boss_special_gauge,
		force_roll,
		free_cast,
		source,
		bypass_cooldown,
		blocked_by_other_skill,
		_rng
	):
		return false
	_sync_scripted_motion()
	_sync_boss_ball_intangible()
	return true


func _update_clone_cast(delta: float, deps: Dictionary) -> void:
	var result: Dictionary = _clone_state.advance_cast(
		delta,
		boss_special_gauge,
		awakened,
		_rng,
		deps
	)
	if result.is_empty():
		return
	_gauge_state.commit_result(result)
	_sync_scripted_motion()
	_sync_boss_ball_intangible()


func _cancel_clone_cast() -> void:
	_clone_state.cancel_cast()
	_sync_scripted_motion()
	_sync_boss_ball_intangible()


func _spawn_shadow_clones(center: Vector2, spawn_awakened: bool) -> void:
	_clone_state.spawn_entities(center, spawn_awakened, _rng)


func _update_shadow_clones(frame_scale: float, delta: float, deps: Dictionary) -> void:
	_clone_state.update_entities(frame_scale, delta, deps)


func _update_clone_invulnerability(delta: float) -> void:
	_clone_state.update_invulnerability(delta)
	_sync_boss_ball_intangible()


func _sync_boss_ball_intangible() -> void:
	_motion_state.refresh_boss_ball_intangible(_clone_state.is_boss_intangible())


func _sync_scripted_motion() -> void:
	_motion_state.refresh_scripted_motion(_get_scripted_motion_sources())


func _get_scripted_motion_sources() -> Dictionary:
	return {
		"escape_active": _escape_state.active,
		"escape_pos": _escape_state.get_boss_pos(),
		"cloud_active": _cloud_state.dash_active,
		"cloud_pos": _cloud_state.get_boss_pos(),
		"clone_active": _clone_state.casting,
		"clone_pos": _clone_state.cast_boss_pos,
		"shuriken_active": _shuriken_state.casting,
		"shuriken_pos": _shuriken_state.cast_boss_pos,
	}


func _has_live_clones() -> bool:
	return _get_live_clone_count() > 0


func _get_live_clone_count() -> int:
	return _clone_state.get_live_count()


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
	var blocked_by_other_skill: bool = (
		_superspeed_active
		or _clone_state.casting
		or _has_live_clones()
		or _cloud_state.dash_active
		or _escape_state.active
		or _external_scripted_motion_active
		or bool(context.get("lingpet_puppet_grab_active", false))
	)
	if _shuriken_state.should_start_cast(
		delta,
		boss_special_gauge,
		blocked_by_other_skill,
		_rng
	):
		_start_shuriken_cast(context)


func _start_shuriken_cast(context: Dictionary) -> void:
	_gauge_state.set_raw(_shuriken_state.start_cast(context, boss_special_gauge))
	_sync_scripted_motion()


func _update_shuriken_cast(delta: float, context: Dictionary, deps: Dictionary) -> void:
	if not _shuriken_state.advance_cast(delta):
		return
	_sync_scripted_motion()
	_spawn_shuriken_from_context(context, false, deps)
	_arm_shuriken_cooldown()
	if awakened:
		_shuriken_state.queue_awakened_bonus()


func _update_pending_shurikens(delta: float, context: Dictionary, deps: Dictionary) -> void:
	var due_count: int = _shuriken_state.advance_pending(delta)
	for _index in range(due_count):
		# A pending bonus shot does not reroll the primary volley cooldown or
		# cancel another cast.
		_spawn_shuriken_from_context(context, true, deps)


func _spawn_shuriken_from_context(
	context: Dictionary,
	from_pending: bool,
	deps: Dictionary
) -> void:
	var target: Vector2 = _shuriken_state.spawn_from_context(context, from_pending, deps)
	_presentation_state.trigger_boss_attack("shuriken", target.x)


func _append_shuriken(origin: Vector2, target: Vector2, from_pending: bool) -> void:
	_shuriken_state.append_shuriken(origin, target, from_pending)


func _arm_shuriken_cooldown() -> void:
	_shuriken_state.arm_cooldown(_rng)


func _update_shuriken_projectiles(
	frame_scale: float,
	delta: float,
	context: Dictionary,
	deps: Dictionary,
	result: Dictionary
) -> void:
	_shuriken_state.update_projectiles(frame_scale, delta, context, deps, result, _rng)


func _update_shuriken_gauge_drain(frame_scale: float, context: Dictionary, result: Dictionary) -> void:
	_shuriken_state.update_gauge_drain(frame_scale, context, result)


func _spawn_shuriken_hit_particles(center: Vector2, velocity: Vector2) -> void:
	_shuriken_state.spawn_hit_particles(center, velocity, _rng)


func _update_wind_effects(
	frame_scale: float,
	delta: float,
	_context: Dictionary,
	_skill_cooldown_paused_now: bool
) -> void:
	_awakening_state.advance_runtime(
		frame_scale,
		delta,
		_get_effect_boss_pos() + _geometry_state.boss_size * 0.5,
		_superspeed_active
	)


func _update_wind_aura_free_clone_queue(context: Dictionary) -> void:
	if not _awakening_state.free_clone_queued:
		return
	if _superspeed_active:
		_awakening_state.clear_free_clone_queue()
		return
	if _cloud_state.dash_active or _has_scripted_skill_conflict("clone"):
		return
	_awakening_state.take_free_clone_queue()
	_try_start_clone_cast(context, true, true, "wind_aura_queued", true)


func _sync_awakening_draw_context(center_override: Variant = null) -> void:
	var center: Vector2 = _get_effect_boss_pos() + _geometry_state.boss_size * 0.5
	if center_override is Vector2:
		center = center_override as Vector2
	_awakening_state.sync_draw_context(center, _superspeed_active)


func _get_effect_boss_pos() -> Vector2:
	if _superspeed_active:
		return _superspeed_boss_pos
	if _escape_state.active:
		return _escape_state.get_boss_pos()
	if _cloud_state.dash_active:
		return _cloud_state.get_boss_pos()
	if _clone_state.casting:
		return _clone_state.cast_boss_pos
	if _shuriken_state.casting:
		return _shuriken_state.cast_boss_pos
	return _geometry_state.boss_pos


func _try_start_superspeed(context: Dictionary) -> bool:
	# Cloud owns a vertical scripted excursion. Superspeed cancellation must
	# normalize to the captured home band before the tangible predictive dash
	# begins; keeping the down/up position would strand the paddle mid-field.
	var start_pos: Vector2 = _cloud_state.home_boss_pos if _cloud_state.dash_active else _get_effect_boss_pos()
	var blocked: bool = (
		_escape_state.active
		or _external_scripted_motion_active
		or bool(context.get("lingpet_puppet_grab_active", false))
		or is_gameplay_freeze_active()
	)
	var start_result: Dictionary = _superspeed_state.try_start(
		context,
		boss_special_gauge,
		awakened,
		blocked,
		start_pos,
		_geometry_state.boss_size
	)
	if not bool(start_result.get("started", false)):
		return false
	_gauge_state.commit_result(start_result)
	_cancel_skills_for_superspeed()
	_freeze_state.begin("superspeed", SUPERSPEED_ACTIVATION_FREEZE_SEC)
	_sync_awakening_draw_context()
	status = "superspeed_freeze"
	return true


func _cancel_skills_for_superspeed() -> void:
	_awakening_state.clear_free_clone_queue()
	var cloud_cancel: Dictionary = _cloud_state.cancel_for_superspeed()
	if _clone_state.casting:
		_cancel_clone_cast()
	_shuriken_state.cancel_cast_and_pending()
	set_boss_ball_intangible_source(CLOUD_INTANGIBLE_SOURCE, false)
	if bool(cloud_cancel.get("interrupted_dash", false)):
		_motion_state.publish_release(cloud_cancel.get("release_pos", Vector2.ZERO) as Vector2)
	_sync_scripted_motion()
	_sync_boss_ball_intangible()


func _update_superspeed(frame_scale: float, delta: float, context: Dictionary) -> void:
	var was_active: bool = _superspeed_state.active
	var runtime_result: Dictionary = _superspeed_state.advance_runtime(
		frame_scale,
		delta,
		context,
		_rng,
		_get_effect_boss_pos(),
		_geometry_state.boss_size
	)
	if bool(runtime_result.get("ended", false)):
		_freeze_state.cancel_if_reason("superspeed")
	if was_active:
		_sync_awakening_draw_context()


func notify_superspeed_dash_started(
	boss_pos: Vector2,
	boss_size: Vector2,
	direction: int,
	target_center_x: float,
	duration_frames: float
) -> void:
	_superspeed_state.notify_dash_started(
		boss_pos,
		boss_size,
		direction,
		target_center_x,
		duration_frames
	)


func notify_superspeed_dash_finished(boss_pos: Vector2) -> void:
	_superspeed_state.notify_dash_finished(boss_pos)


func _update_particles(delta: float) -> void:
	_shuriken_state.update_hit_particles(delta)


func _sync_presentation_status(skill_cooldown_paused: bool) -> void:
	_presentation_state.refresh_status_fields(
		is_gameplay_freeze_active(),
		_freeze_state.reason,
		_escape_state.active,
		_cloud_state.dash_active,
		_cloud_state.dash_phase,
		_superspeed_active,
		skill_cooldown_paused,
		_clone_state.casting,
		_shuriken_state.casting,
		_has_live_clones(),
		not _shuriken_state.projectiles.is_empty(),
		_shuriken_state.gauge_ticks_left,
		_cloud_state.field_active,
		_wind_aura_depleted,
		awakened
	)


func _get_player_rect(context: Dictionary) -> Rect2:
	var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2(302.5, 690.0)), Vector2(302.5, 690.0))
	var player_size: Vector2 = _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	return Rect2(player_pos, player_size)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
