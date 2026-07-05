extends RefCounted

const CommonStarpointVisualHost := preload("res://scripts/effects/common_starpoint_visual_host.gd")
const LingpetStarlightTrackingBridge := preload("res://scripts/stages/common/lingpet_starlight_tracking_bridge.gd")
const StarpointBonusDropPolicy := preload("res://scripts/stages/common/starpoint_bonus_drop_policy.gd")
const StarpointCollectionCompaction := preload("res://scripts/stages/common/starpoint_collection_compaction.gd")
const StarpointCollectionRewardPolicy := preload("res://scripts/stages/common/starpoint_collection_reward_policy.gd")
const StarpointDropMotionState := preload("res://scripts/stages/common/starpoint_drop_motion_state.gd")
const StarpointDropOverlapQuery := preload("res://scripts/stages/common/starpoint_drop_overlap_query.gd")
const StarpointParticleState := preload("res://scripts/stages/common/starpoint_particle_state.gd")
const StarpointPayloadFactory := preload("res://scripts/stages/common/starpoint_payload_factory.gd")
const StageActorDrawContextArrays := preload("res://scripts/stages/common/stage_actor_draw_context_arrays.gd")
const StagePlayerInteractionRects := preload("res://scripts/stages/common/stage_player_interaction_rects.gd")
const StagePlayfieldBounds := preload("res://scripts/stages/common/stage_playfield_bounds.gd")
const Stage3BossSkillPayloadFactory := preload("res://scripts/stages/stage3/stage3_boss_skill_payload_factory.gd")
const Stage3KuromiFractureParticles := preload("res://scripts/stages/stage3/stage3_kuromi_fracture_particles.gd")

const STAGE_ID := 3
const WIDTH := 760.0
const HEIGHT := 750.0
const BOSS_GAUGE_MAX := 500.0
const BOSS_GAUGE_GAIN_ON_HIT := 0.0
const TEARS_COOLDOWN_SEC := 25.0
const TEARS_DURATION_SEC := 400.0 / 60.0
const TEARS_MIN_COUNT := 4
const TEARS_MAX_COUNT := 7
const TEARS_ENRAGED_MIN_COUNT := 8
const TEARS_ENRAGED_MAX_COUNT := 14
const TEARS_SLOW_SOURCE := "stage3_tear_shower"
const TEARS_SLOW_DURATION_FRAMES := 130.0
const TEARS_SLOW_STACK_AMOUNT := 0.20
const TEARS_SLOW_STACK_MAX := 0.80
const CURSE_CHEST_COOLDOWN_SEC := 35.0
const CURSE_CHEST_WINDUP_SEC := 0.5
const CURSE_CHEST_THROW_SPEED := 0.04
const CURSE_CHEST_LIFETIME_SEC := 4.0
const CURSE_CHEST_SMOKE_SEC := 3.0
const CURSE_CHEST_SMOKE_FADE_SEC := 2.0
const CURSE_CHEST_SMOKE_RADIUS := 80.0
const CURSE_CHEST_REVERSE_SEC := 2.0
const CURSE_CHEST_EXPLODE_SEC := 0.5
const PSYCHOBALL_COOLDOWN_SEC := 70.0
const PSYCHOBALL_DURATION_SEC := 5.0
const PSYCHOBALL_ENRAGED_DURATION_SEC := 7.5
const PSYCHOBALL_SMOKE_OPACITY_THRESHOLD := 50.0 / 255.0
const PSYCHOBALL_SMOKE_NEUTRALIZE_SPEED := 10.0
const PSYCHOBALL_NEUTRALIZE_PARTICLE_COUNT := 20
const PSYCHOBALL_TRAIL_INITIAL_ALPHA := 200.0 / 255.0
const PSYCHOBALL_TRAIL_FADE_PER_FRAME := 10.0 / 255.0
const PSYCHOBALL_TRAIL_MIN_ALPHA := 10.0 / 255.0
const PSYCHOBALL_HITSTOP_SEC := 0.12
const TAIL_INITIAL_COOLDOWN_SEC := 5.0
const TAIL_COOLDOWN_MIN_SEC := 5.0
const TAIL_COOLDOWN_MAX_SEC := 10.0
const TAIL_DURATION_SEC := 1.0
const TAIL_CURVE_DURATION_SEC := 2.0
const KUROMI_AWAKEN_SCORE := 2
const KUROMI_AWAKENING_SEC := 3.0
const KUROMI_EAT_COOLDOWN_SEC := 20.0
const KUROMI_EAT_CHANCE := 0.06
const KUROMI_EAT_TONGUE_EXTEND_FRAMES := 20.0
const KUROMI_EAT_TONGUE_WRAP_FRAMES := 40.0
const KUROMI_EAT_SWALLOW_FRAMES := 50.0
const KUROMI_EAT_CHEW_FRAMES := 120.0
const KUROMI_EAT_DIRECTION_FRAMES := 180.0
const KUROMI_EAT_RELEASE_FRAMES := 190.0
const KUROMI_SPIT_SOUND_LEAD_FRAMES := 18.0
const KUROMI_SPIT_SPEED_MIN := 8.0
const KUROMI_SPIT_SPEED_MAX := 12.0
const KUROMI_SPIT_SPEED_MULT := 3.0
const KUROMI_SPIT_HORIZONTAL_EXCLUSION := PI * 0.083
const KUROMI_SPIT_ANGLE_LIMIT := PI * 0.7
const TAIL_TRACK_PROGRESS_LIMIT := 0.5
const TAIL_HIT_PROGRESS_MIN := 0.2
const TAIL_HIT_PROGRESS_MAX := 0.8
const TAIL_HIT_RADIUS := 80.0
const TAIL_POINT_COUNT := 24
const TAIL_COLLISION_MID_INDEX_RANGE := 8
const TAIL_BASE_SPEED_MAX := 18.0
const TAIL_HIT_BURST_SEC := 0.55
const MAX_TAIL_HIT_BURSTS := 4
const MAX_OVERDRIVE_TRAILS := 15
const MAX_PSYCHOBALL_NEUTRALIZE_PARTICLES := 60
const MAX_PRISM_PARTICLES := 60
const TAIL_HIT_PRISM_MIN_COUNT := 18
const TAIL_HIT_PRISM_MAX_COUNT := 22
const STARPOINT_DROP_SIZE := 12.0
const STARPOINT_DROP_LIFETIME := 600.0
const STARPOINT_DROP_ACCELERATION := 0.25
const STARPOINT_DROP_MAX_FALL_SPEED := 12.0
const STARPOINT_DROP_BOUNCE_DAMPING := 0.7
const STARPOINT_PARTICLE_COUNT := 20
const STARPOINT_PARTICLE_LIFE := 60.0
const STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES := [-36.0, -24.0, 24.0, 36.0]
const MAX_STAGE3_STARPOINT_DROPS := 10
const MAX_STAGE3_STARPOINT_PARTICLES := 120
const MAX_CURSE_SMOKE_PARTICLES := 240
const MAX_KUROMI_EATING_PARTICLES := 80

var rng := RandomNumberGenerator.new()
var boss_special_gauge := 0.0
var boss_special_ready := false
var boss_red_intensity := 0.0
var status := "charging"
var tears_active := false
var tears_timer := 0.0
var tears_cooldown := TEARS_COOLDOWN_SEC
var falling_tears: Array = []
var curse_phase := "idle"
var curse_cooldown := CURSE_CHEST_COOLDOWN_SEC
var curse_windup_timer := 0.0
var curse_throw_progress := 0.0
var curse_throw_start := Vector2.ZERO
var curse_throw_pos := Vector2.ZERO
var curse_target := Vector2.ZERO
var curse_pos := Vector2.ZERO
var curse_lifetime := 0.0
var curse_open_timer := 0.0
var curse_reverse_timer := 0.0
var curse_smoke: Array = []
var curse_explosion_timer := 0.0
var curse_explosion_particles: Array = []
var curse_nudge_vx := 0.0
var curse_wobble_angle := 0.0
var curse_wobble_vel := 0.0
var overdrive_active := false
var psycho_cooldown := PSYCHOBALL_COOLDOWN_SEC
var overdrive_timer := 0.0
var overdrive_flash_timer := 0.0
var psycho_bg_timer := 0.0
var overdrive_trails: Array = []
var psycho_neutralize_particles: Array = []
var psychoball_hitstop_timer := 0.0
var tail_whip_active := false
var tail_whip_timer := 0.0
var tail_whip_cooldown := TAIL_INITIAL_COOLDOWN_SEC
var tail_hit_ball := false
var tail_curve_active := false
var tail_curve_timer := 0.0
var tail_curve_direction := 0
var tail_whip_target := Vector2(WIDTH * 0.5, HEIGHT * 0.5)
var tail_has_target := false
var tail_points: Array[Vector2] = []
var tail_hit_bursts: Array = []
var kuromi_petrified := true
var kuromi_awakening := false
var kuromi_awakening_timer := 0.0
var kuromi_awakening_explosion_spawned := false
var kuromi_awakened := false
var kuromi_eating_active := false
var kuromi_eating_timer := 0.0
var kuromi_eating_cooldown := 0.0
var kuromi_ball_entered := false
var kuromi_spit_angle := 0.0
var kuromi_has_spit_angle := false
var kuromi_mouth_direction := 0.0
var kuromi_mouth_open := 0.0
var kuromi_chewing_phase := 0.0
var kuromi_tongue_extended := 0.0
var kuromi_tongue_angle := 0.0
var kuromi_tongue_wrap_phase := 0.0
var kuromi_ball_tongue_pos := Vector2.ZERO
var kuromi_ball_on_tongue := false
var kuromi_eat_source_pos := Vector2.ZERO
var kuromi_swallow_sound_played := false
var kuromi_spit_sound_played := false
var kuromi_eating_particles: Array = []
var _kuromi_fracture: Stage3KuromiFractureParticles
var kuromi_spit_trail: Array = []
var kuromi_spit_trail_phase := 0.0
var kuromi_spit_trail_frame := 0.0
var prism_particles: Array = []
var starpoint_drops: Array = []
var starpoint_particles: Array = []


func _init() -> void:
	rng.seed = 3303
	_kuromi_fracture = Stage3KuromiFractureParticles.new(rng)


func reset() -> void:
	boss_special_gauge = 0.0
	boss_special_ready = false
	boss_red_intensity = 0.0
	psycho_cooldown = PSYCHOBALL_COOLDOWN_SEC
	tears_cooldown = TEARS_COOLDOWN_SEC
	curse_cooldown = CURSE_CHEST_COOLDOWN_SEC
	status = "charging"
	_reset_round_effects()
	tail_whip_cooldown = TAIL_INITIAL_COOLDOWN_SEC
	kuromi_petrified = true
	kuromi_awakening = false
	kuromi_awakening_timer = 0.0
	kuromi_awakening_explosion_spawned = false
	kuromi_awakened = false
	_kuromi_fracture.clear()


func reset_round() -> void:
	boss_special_gauge = 0.0
	boss_special_ready = false
	boss_red_intensity = _get_red_target()
	_reset_round_effects()
	tail_whip_cooldown = _roll_tail_cooldown()


func update(delta: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		var had_starpoints := not starpoint_drops.is_empty() or not starpoint_particles.is_empty()
		reset()
		if had_starpoints:
			CommonStarpointVisualHost.hide_all_existing_hosts()
		return {}

	var result: Dictionary = {}
	var clamped_delta: float = clamp(delta, 0.0, 0.05)
	if bool(context.get("stage3_kuromi_awakened", false)) or bool(context.get("enraged_boss_active", false)):
		force_kuromi_awake()
	_maybe_start_kuromi_awakening(int(context.get("player_score", 0)), deps)
	_update_kuromi_awakening(clamped_delta, deps)
	_update_tail_hit_bursts(clamped_delta)
	_update_starpoint_drops(clamped_delta * 60.0, context, deps)
	_update_starpoint_particles(clamped_delta * 60.0)
	if is_psychoball_hitstop_active():
		_update_psychoball_hitstop(clamped_delta)
		_update_psychoball_neutralize_particles(clamped_delta)
		_sync_audio(deps)
		status = _get_status()
		return result
	var boss_skill_cooldown_paused: bool = _is_boss_skill_cooldown_paused(context)
	if not boss_skill_cooldown_paused:
		_update_cooldowns(clamped_delta)
	_update_red_intensity(clamped_delta)
	_update_tears(clamped_delta, context, deps)
	_update_curse_chest(clamped_delta, context, deps)
	_update_kuromi(clamped_delta, context, deps, result)
	_update_tail_whip(clamped_delta, context, deps, result)
	_update_overdrive(clamped_delta, context, deps, result)
	_update_psychoball_neutralize_particles(clamped_delta)
	_update_prism_particles(clamped_delta)
	if not boss_skill_cooldown_paused:
		_maybe_activate_skills(context, deps)
	_sync_audio(deps)
	status = _get_status()
	if boss_skill_cooldown_paused and status == "charging":
		status = "paused"
	return result


func register_boss_hit(_ball_vel: Vector2, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		return {}
	var triggered := false
	if _can_trigger_psychoball_on_hit(context):
		_activate_overdrive(context, deps)
		triggered = true
	return {
		"stage3_boss_gauge": boss_special_gauge,
		"stage3_boss_gauge_gain": BOSS_GAUGE_GAIN_ON_HIT,
		"stage3_psychoball_hit_triggered": triggered,
	}


func handle_score_event(scoring_side: String, score_result: Dictionary, deps: Dictionary = {}) -> void:
	if scoring_side != "player":
		return
	_maybe_start_kuromi_awakening(int(score_result.get("player_score", 0)), deps)


func is_kuromi_awakening_active() -> bool:
	return kuromi_awakening


func is_kuromi_ball_hidden() -> bool:
	return kuromi_eating_active


func force_kuromi_awake() -> void:
	kuromi_petrified = false
	kuromi_awakening = false
	kuromi_awakening_timer = 0.0
	kuromi_awakening_explosion_spawned = true
	kuromi_awakened = true
	_kuromi_fracture.clear_pending()


func get_hud_context(_stage_background: Object = null, _context: Dictionary = {}) -> Dictionary:
	return {
		"stage3_boss_skill_hud_active": true,
		"stage3_boss_skill_hud_boss_name": "멘헤라걸",
		"stage3_boss_skill_hud_status": status,
		"stage3_boss_skill_hud_boss_gauge": boss_special_gauge,
		"stage3_boss_skill_hud_boss_gauge_max": BOSS_GAUGE_MAX,
		"stage3_boss_skill_hud_boss_gauge_progress": get_boss_gauge_progress(),
		"stage3_boss_skill_hud_show_boss_gauge": false,
		"stage3_boss_skill_hud_skills": [
			_get_tears_hud_skill(),
			_get_curse_hud_skill(),
			_get_psychoball_hud_skill(),
		],
	}


func get_actor_draw_context(copy_arrays: bool = false) -> Dictionary:
	return {
		"stage3_boss_special_gauge": boss_special_gauge,
		"stage3_boss_special_ready": boss_special_ready,
		"stage3_boss_red_ratio": clamp(boss_red_intensity / 220.0, 0.0, 1.0),
		"stage3_emotional_overdrive_active": overdrive_active,
		"stage3_emotional_overdrive_ratio": overdrive_timer / max(0.001, PSYCHOBALL_ENRAGED_DURATION_SEC),
		"stage3_psycho_bg_timer": psycho_bg_timer,
		"stage3_psychoball_hitstop_active": is_psychoball_hitstop_active(),
		"stage3_psychoball_hitstop_ratio": psychoball_hitstop_timer / max(0.001, PSYCHOBALL_HITSTOP_SEC),
		"stage3_overdrive_trails": _draw_array(overdrive_trails, copy_arrays, true),
		"stage3_psychoball_neutralize_particles": _draw_array(psycho_neutralize_particles, copy_arrays, true),
		"stage3_tears_active": tears_active,
		"stage3_falling_tears": _draw_array(falling_tears, copy_arrays, true),
		"stage3_curse_chest_phase": curse_phase,
		"stage3_curse_chest_windup_progress": 1.0 - curse_windup_timer / max(0.001, CURSE_CHEST_WINDUP_SEC),
		"stage3_curse_chest_throw_progress": curse_throw_progress,
		"stage3_curse_chest_throw_pos": curse_throw_pos,
		"stage3_curse_chest_throw_start": curse_throw_start,
		"stage3_curse_chest_target": curse_target,
		"stage3_curse_chest_pos": curse_pos,
		"stage3_curse_chest_wobble": curse_wobble_angle,
		"stage3_curse_chest_lifetime_ratio": curse_lifetime / max(0.001, CURSE_CHEST_LIFETIME_SEC),
		"stage3_curse_chest_smoke": _draw_array(curse_smoke, copy_arrays, false),
		"stage3_curse_reverse_active": is_curse_reverse_active(),
		"stage3_curse_reverse_ratio": curse_reverse_timer / max(0.001, CURSE_CHEST_REVERSE_SEC),
		"stage3_curse_chest_explosion_particles": _draw_array(curse_explosion_particles, copy_arrays, true),
		"stage3_tail_whip_active": tail_whip_active,
		"stage3_tail_whip_progress": 1.0 - tail_whip_timer / max(0.001, TAIL_DURATION_SEC),
		"stage3_tail_whip_target": tail_whip_target,
		"stage3_tail_points": _draw_array(tail_points, copy_arrays, true),
		"stage3_tail_curve_active": tail_curve_active,
		"stage3_tail_hit_bursts": _draw_array(tail_hit_bursts, copy_arrays, true),
		"stage3_kuromi_petrified": kuromi_petrified,
		"stage3_kuromi_awakening": kuromi_awakening,
		"stage3_kuromi_awakening_progress": _get_kuromi_awakening_progress(),
		"stage3_kuromi_awakening_timer": kuromi_awakening_timer,
		"stage3_kuromi_awakened": kuromi_awakened,
		"stage3_kuromi_eating_active": kuromi_eating_active,
		"stage3_kuromi_ball_hidden": is_kuromi_ball_hidden(),
		"stage3_kuromi_eating_timer": kuromi_eating_timer,
		"stage3_kuromi_eating_progress": clamp(kuromi_eating_timer / KUROMI_EAT_RELEASE_FRAMES, 0.0, 1.0),
		"stage3_kuromi_mouth_open": kuromi_mouth_open,
		"stage3_kuromi_mouth_direction": kuromi_mouth_direction,
		"stage3_kuromi_chewing_phase": kuromi_chewing_phase,
		"stage3_kuromi_tongue_extended": kuromi_tongue_extended,
		"stage3_kuromi_tongue_angle": kuromi_tongue_angle,
		"stage3_kuromi_tongue_wrap_phase": kuromi_tongue_wrap_phase,
		"stage3_kuromi_ball_tongue_pos": kuromi_ball_tongue_pos,
		"stage3_kuromi_ball_on_tongue": kuromi_ball_on_tongue,
		"stage3_kuromi_eating_particles": _draw_array(kuromi_eating_particles, copy_arrays, true),
		"stage3_kuromi_crack_particles": _draw_array(_kuromi_fracture.particles, copy_arrays, false),
		"stage3_kuromi_crack_particles_draw_order": _draw_array(_kuromi_fracture.particles_draw_order, copy_arrays, false),
		"stage3_kuromi_spit_trail": _draw_array(kuromi_spit_trail, copy_arrays, true),
		"stage3_kuromi_spit_trail_phase": kuromi_spit_trail_phase,
		"stage3_prism_particles": _draw_array(prism_particles, copy_arrays, true),
		"stage3_starpoint_drops": _draw_array(starpoint_drops, copy_arrays, true),
		"stage3_starpoint_particles": _draw_array(starpoint_particles, copy_arrays, true),
	}


func _draw_array(source: Array, copy_arrays: bool, deep: bool) -> Array:
	return StageActorDrawContextArrays.snapshot(source, copy_arrays, deep)


func get_boss_gauge_progress() -> float:
	return clamp(boss_special_gauge / BOSS_GAUGE_MAX, 0.0, 1.0)


func is_curse_reverse_active() -> bool:
	return curse_reverse_timer > 0.0


func is_psychoball_hitstop_active() -> bool:
	return psychoball_hitstop_timer > 0.0


func get_snapshot() -> Dictionary:
	var snapshot: Dictionary = get_actor_draw_context(true)
	snapshot["status"] = status
	snapshot["boss_special_gauge"] = boss_special_gauge
	snapshot["boss_special_ready"] = boss_special_ready
	snapshot["psycho_cooldown"] = psycho_cooldown
	snapshot["psychoball_hitstop_timer"] = psychoball_hitstop_timer
	snapshot["tears_cooldown"] = tears_cooldown
	snapshot["curse_cooldown"] = curse_cooldown
	snapshot["tail_cooldown"] = tail_whip_cooldown
	return snapshot


func _maybe_start_kuromi_awakening(player_score: int, deps: Dictionary = {}) -> void:
	if player_score < KUROMI_AWAKEN_SCORE:
		return
	if not kuromi_petrified or kuromi_awakening or kuromi_awakened:
		return
	kuromi_awakening = true
	kuromi_awakening_timer = KUROMI_AWAKENING_SEC
	kuromi_awakening_explosion_spawned = false
	_kuromi_fracture.clear()
	_play_audio(deps, "play_stage3_kuromi_awake")


func _update_kuromi_awakening(delta: float, deps: Dictionary) -> void:
	_kuromi_fracture.update(delta)
	if not kuromi_awakening:
		return
	kuromi_awakening_timer = max(0.0, kuromi_awakening_timer - delta)
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("max_screen_shake"):
		var progress: float = _get_kuromi_awakening_progress()
		feedback.max_screen_shake(0.10 + progress * 0.12, 7.0 + progress * 8.0)
	if not kuromi_awakening_explosion_spawned and kuromi_awakening_timer <= delta:
		_spawn_kuromi_awakening_fragments()
		_play_audio(deps, "play_stage3_kuromi_stonebreak")
		if feedback != null and feedback.has_method("set_screen_shake"):
			feedback.set_screen_shake(0.35, 15.0)
	if kuromi_awakening_timer <= 0.0:
		kuromi_awakening = false
		kuromi_petrified = false
		kuromi_awakened = true


func _get_kuromi_awakening_progress() -> float:
	if not kuromi_awakening and kuromi_awakened:
		return 1.0
	return clamp(1.0 - kuromi_awakening_timer / KUROMI_AWAKENING_SEC, 0.0, 1.0)


func _spawn_kuromi_awakening_fragments() -> void:
	if kuromi_awakening_explosion_spawned:
		return
	kuromi_awakening_explosion_spawned = true
	_kuromi_fracture.spawn_explosion()


func _trim_array_from_front(source: Array, max_size: int) -> void:
	var overflow: int = source.size() - max_size
	if overflow <= 0:
		return
	var write_idx: int = 0
	for read_idx in range(overflow, source.size()):
		source[write_idx] = source[read_idx]
		write_idx += 1
	source.resize(write_idx)


func _reset_round_effects() -> void:
	tears_active = false
	tears_timer = 0.0
	falling_tears.clear()
	curse_phase = "idle"
	curse_windup_timer = 0.0
	curse_throw_progress = 0.0
	curse_smoke.clear()
	curse_explosion_particles.clear()
	curse_reverse_timer = 0.0
	curse_nudge_vx = 0.0
	curse_wobble_angle = 0.0
	curse_wobble_vel = 0.0
	overdrive_active = false
	overdrive_timer = 0.0
	overdrive_flash_timer = 0.0
	psycho_bg_timer = 0.0
	overdrive_trails.clear()
	psycho_neutralize_particles.clear()
	psychoball_hitstop_timer = 0.0
	tail_whip_active = false
	tail_whip_timer = 0.0
	tail_hit_ball = false
	tail_curve_active = false
	tail_curve_timer = 0.0
	tail_curve_direction = 0
	tail_has_target = false
	tail_points.clear()
	tail_hit_bursts.clear()
	kuromi_eating_active = false
	kuromi_eating_timer = 0.0
	kuromi_eating_cooldown = 0.0
	kuromi_ball_entered = false
	kuromi_has_spit_angle = false
	kuromi_mouth_direction = 0.0
	kuromi_mouth_open = 0.0
	kuromi_chewing_phase = 0.0
	kuromi_tongue_extended = 0.0
	kuromi_tongue_angle = 0.0
	kuromi_tongue_wrap_phase = 0.0
	kuromi_ball_tongue_pos = Vector2.ZERO
	kuromi_ball_on_tongue = false
	kuromi_eat_source_pos = Vector2.ZERO
	kuromi_swallow_sound_played = false
	kuromi_spit_sound_played = false
	kuromi_eating_particles.clear()
	_kuromi_fracture.clear_pending()
	kuromi_spit_trail.clear()
	kuromi_spit_trail_phase = 0.0
	kuromi_spit_trail_frame = 0.0
	prism_particles.clear()
	starpoint_drops.clear()
	starpoint_particles.clear()


func _update_cooldowns(delta: float) -> void:
	psycho_cooldown = max(0.0, psycho_cooldown - delta)
	tears_cooldown = max(0.0, tears_cooldown - delta)
	curse_cooldown = max(0.0, curse_cooldown - delta)
	if not tail_whip_active and kuromi_awakened and not overdrive_active:
		tail_whip_cooldown = max(0.0, tail_whip_cooldown - delta)
	if kuromi_eating_cooldown > 0.0:
		kuromi_eating_cooldown = max(0.0, kuromi_eating_cooldown - delta)


func _is_boss_skill_cooldown_paused(context: Dictionary) -> bool:
	return bool(context.get(
		"active_item_boss_skill_cooldown_paused",
		context.get("active_item_tear_gas_cooldown_pause_active", false)
	))


func _update_red_intensity(delta: float) -> void:
	var target: float = _get_red_target()
	var lerp_ratio: float = min(1.0, delta * 6.0)
	boss_red_intensity = lerp(boss_red_intensity, target, lerp_ratio)


func _get_red_target() -> float:
	return 0.0


func _maybe_activate_skills(context: Dictionary, deps: Dictionary) -> void:
	if kuromi_awakening:
		return
	if bool(context.get("waiting_for_serve", false)) or not bool(context.get("ball_active", false)):
		return
	if tears_cooldown <= 0.0 and not tears_active and not overdrive_active:
		_activate_tears(context, deps)
		return
	if curse_cooldown <= 0.0 and curse_phase == "idle" and not overdrive_active:
		_activate_curse_chest(context, deps)
		return
	if kuromi_awakened and tail_whip_cooldown <= 0.0 and not tail_whip_active and not overdrive_active:
		_activate_tail_whip(_as_vector2(context.get("ball_pos", Vector2(WIDTH * 0.5, HEIGHT * 0.5)), Vector2(WIDTH * 0.5, HEIGHT * 0.5)))


func _can_trigger_psychoball_on_hit(context: Dictionary) -> bool:
	return (
		psycho_cooldown <= 0.0
		and not overdrive_active
		and not kuromi_awakening
		and int(context.get("current_stage", STAGE_ID)) == STAGE_ID
		and bool(context.get("ball_active", true))
		and not bool(context.get("waiting_for_serve", false))
	)


func _activate_tears(context: Dictionary, deps: Dictionary) -> void:
	tears_active = true
	tears_timer = TEARS_DURATION_SEC
	tears_cooldown = TEARS_COOLDOWN_SEC
	falling_tears.clear()
	var count_min := TEARS_ENRAGED_MIN_COUNT if bool(context.get("enraged_boss_active", false)) else TEARS_MIN_COUNT
	var count_max := TEARS_ENRAGED_MAX_COUNT if bool(context.get("enraged_boss_active", false)) else TEARS_MAX_COUNT
	for _idx in range(rng.randi_range(count_min, count_max)):
		falling_tears.append(Stage3BossSkillPayloadFactory.build_falling_tear(WIDTH, rng))
	_play_audio(deps, "play_stage3_tears")


func _update_tears(delta: float, context: Dictionary, deps: Dictionary) -> void:
	if not tears_active:
		return
	tears_timer -= delta
	if tears_timer <= 0.0:
		tears_active = false
		falling_tears.clear()
		return
	var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size: Vector2 = _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	var player_rect := Rect2(player_pos, player_size)
	for idx in range(falling_tears.size() - 1, -1, -1):
		var tear: Dictionary = falling_tears[idx]
		tear["prev_y"] = float(tear.get("y", 0.0))
		tear["y"] = float(tear.get("y", 0.0)) + float(tear.get("speed", 3.0)) * delta * 60.0
		if float(tear.get("y", 0.0)) > HEIGHT + 50.0:
			tear["x"] = rng.randf_range(0.0, WIDTH - 20.0)
			tear["y"] = rng.randf_range(-100.0, -20.0)
			tear["prev_y"] = tear["y"]
			tear["speed"] = rng.randf_range(2.0, 5.0)
		if player_rect.intersects(Rect2(Vector2(float(tear["x"]) - 5.0, float(tear["y"]) - 5.0), Vector2(10.0, 10.0))):
			falling_tears.remove_at(idx)
			_apply_tears_player_slow(deps)
			_play_audio(deps, "play_stage3_tears")
		else:
			falling_tears[idx] = tear


func _apply_tears_player_slow(deps: Dictionary) -> void:
	if _is_player_cleanse_immune(deps):
		return
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state == null or not status_effect_state.has_method("apply_status"):
		return
	var current_multiplier := 1.0
	if status_effect_state.has_method("get_status_source"):
		var current_tears_slow: Dictionary = status_effect_state.get_status_source("player", "slow", TEARS_SLOW_SOURCE)
		if not current_tears_slow.is_empty():
			current_multiplier = clamp(float(current_tears_slow.get("multiplier", current_multiplier)), 0.0, 1.0)
	var minimum_multiplier: float = 1.0 - TEARS_SLOW_STACK_MAX
	var next_multiplier: float = max(minimum_multiplier, current_multiplier - TEARS_SLOW_STACK_AMOUNT)
	status_effect_state.apply_status("player", "slow", TEARS_SLOW_DURATION_FRAMES, {
		"multiplier": next_multiplier,
		"cleansable": true,
		"visual_variant": "tears",
		"label": "눈물샤워",
	}, TEARS_SLOW_SOURCE)


func _is_player_cleanse_immune(deps: Dictionary) -> bool:
	var cleanse_state: Object = deps.get("smasher_cleanse_state", null)
	return cleanse_state != null and cleanse_state.has_method("is_immune") and bool(cleanse_state.is_immune())


func _activate_curse_chest(_context: Dictionary, deps: Dictionary) -> void:
	curse_phase = "windup"
	curse_windup_timer = CURSE_CHEST_WINDUP_SEC
	curse_target = Vector2(rng.randf_range(60.0, WIDTH - 60.0), rng.randf_range(700.0, 730.0))
	curse_cooldown = CURSE_CHEST_COOLDOWN_SEC
	_play_audio(deps, "play_stage3_dollcurse")


func _update_curse_chest(delta: float, context: Dictionary, deps: Dictionary) -> void:
	if curse_reverse_timer > 0.0:
		curse_reverse_timer = max(0.0, curse_reverse_timer - delta)
	match curse_phase:
		"idle":
			return
		"windup":
			curse_windup_timer -= delta
			if curse_windup_timer <= 0.0:
				var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2(330.0, 25.0)), Vector2(330.0, 25.0))
				var boss_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)), Vector2(100.0, 40.0))
				curse_throw_start = boss_pos + Vector2(boss_size.x * 0.5, boss_size.y + 10.0)
				curse_throw_pos = curse_throw_start
				curse_throw_progress = 0.0
				curse_phase = "throwing"
		"throwing":
			curse_throw_progress = min(1.0, curse_throw_progress + CURSE_CHEST_THROW_SPEED * delta * 60.0)
			var t: float = curse_throw_progress
			curse_throw_pos = curse_throw_start.lerp(curse_target, t)
			curse_throw_pos.y += -180.0 * (4.0 * t * (1.0 - t))
			if curse_throw_progress >= 1.0:
				curse_pos = curse_target
				curse_lifetime = 0.0
				curse_open_timer = 0.0
				curse_smoke.clear()
				curse_phase = "closed"
				_play_audio(deps, "play_stage3_chest_land")
		"closed":
			_update_closed_chest(delta, context)
			if curse_lifetime >= CURSE_CHEST_LIFETIME_SEC:
				_trigger_curse_explosion(deps)
		"open":
			_update_open_chest(delta, context)
		"exploding":
			_update_curse_explosion(delta)


func _update_closed_chest(delta: float, context: Dictionary) -> void:
	curse_lifetime += delta
	var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size: Vector2 = _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	var player_center := player_pos + player_size * 0.5
	var prox: Vector2 = player_center - curse_pos
	var dist: float = prox.length()
	if dist < 55.0 and dist > 1.0:
		var push_strength: float = (1.0 - dist / 55.0) * 1.8
		curse_nudge_vx += (-prox.x / dist) * push_strength
		curse_wobble_vel += (-prox.x / dist) * push_strength * 3.0
	if abs(curse_nudge_vx) > 0.05:
		curse_pos.x = clamp(curse_pos.x + curse_nudge_vx, 20.0, WIDTH - 20.0)
		curse_nudge_vx *= 0.85
	else:
		curse_nudge_vx = 0.0
	curse_wobble_vel += -curse_wobble_angle * 0.25
	curse_wobble_vel *= 0.88
	curse_wobble_angle = clamp(curse_wobble_angle + curse_wobble_vel, -18.0, 18.0)
	var dash_snapshot: Dictionary = _as_dict(context.get("dash_snapshot", {}))
	if bool(dash_snapshot.get("active", false)) and dist < 56.0:
		curse_phase = "open"
		curse_open_timer = 0.0


func _update_open_chest(delta: float, context: Dictionary) -> void:
	curse_open_timer += delta
	if curse_open_timer <= CURSE_CHEST_SMOKE_SEC:
		for _idx in range(3):
			curse_smoke.append(Stage3BossSkillPayloadFactory.build_curse_smoke_particle(curse_pos, rng))
		if curse_smoke.size() > MAX_CURSE_SMOKE_PARTICLES:
			_trim_array_from_front(curse_smoke, MAX_CURSE_SMOKE_PARTICLES)
	var write_idx: int = 0
	for idx in range(curse_smoke.size()):
		var p: Dictionary = curse_smoke[idx]
		p["x"] = float(p["x"]) + float(p["vx"]) * delta * 60.0
		p["y"] = float(p["y"]) + float(p["vy"]) * delta * 60.0
		p["vy"] = float(p["vy"]) - 0.01 * delta * 60.0
		p["vx"] = float(p["vx"]) * pow(0.98, delta * 60.0)
		p["life"] = float(p["life"]) - delta
		p["size"] = float(p["size"]) + 0.05 * delta * 60.0
		if curse_open_timer > CURSE_CHEST_SMOKE_SEC:
			var fade_progress: float = (curse_open_timer - CURSE_CHEST_SMOKE_SEC) / CURSE_CHEST_SMOKE_FADE_SEC
			p["alpha"] = max(0.0, 1.0 - fade_progress)
		if float(p["life"]) <= 0.0 or float(p["alpha"]) <= 0.02:
			continue
		curse_smoke[write_idx] = p
		write_idx += 1
	if write_idx < curse_smoke.size():
		curse_smoke.resize(write_idx)
	if curse_open_timer <= CURSE_CHEST_SMOKE_SEC and curse_reverse_timer <= 0.0:
		var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
		var player_size: Vector2 = _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
		if (player_pos + player_size * 0.5).distance_to(curse_pos) < CURSE_CHEST_SMOKE_RADIUS:
			curse_reverse_timer = CURSE_CHEST_REVERSE_SEC
	if curse_open_timer >= CURSE_CHEST_SMOKE_SEC + CURSE_CHEST_SMOKE_FADE_SEC and curse_smoke.is_empty():
		curse_phase = "idle"


func _trigger_curse_explosion(deps: Dictionary) -> void:
	curse_phase = "exploding"
	curse_explosion_timer = CURSE_CHEST_EXPLODE_SEC
	curse_explosion_particles.clear()
	curse_explosion_particles.append_array(Stage3BossSkillPayloadFactory.build_curse_explosion_particles(curse_pos, 15, rng))
	_play_audio(deps, "play_stage3_curse_explode")


func _update_curse_explosion(delta: float) -> void:
	curse_explosion_timer = max(0.0, curse_explosion_timer - delta)
	for idx in range(curse_explosion_particles.size() - 1, -1, -1):
		var p: Dictionary = curse_explosion_particles[idx]
		p["x"] = float(p["x"]) + float(p["vx"]) * delta * 60.0
		p["y"] = float(p["y"]) + float(p["vy"]) * delta * 60.0
		p["vy"] = float(p["vy"]) + 0.1 * delta * 60.0
		p["life"] = float(p["life"]) - delta
		p["life_ratio"] = clamp(float(p["life"]) / max(0.001, float(p.get("max_life", 0.67))), 0.0, 1.0)
		if float(p["life"]) <= 0.0:
			curse_explosion_particles.remove_at(idx)
		else:
			curse_explosion_particles[idx] = p
	if curse_explosion_timer <= 0.0 and curse_explosion_particles.is_empty():
		curse_phase = "idle"


func _activate_overdrive(context: Dictionary, deps: Dictionary) -> void:
	overdrive_active = true
	psycho_cooldown = PSYCHOBALL_COOLDOWN_SEC
	overdrive_timer = PSYCHOBALL_ENRAGED_DURATION_SEC if bool(context.get("enraged_boss_active", false)) else PSYCHOBALL_DURATION_SEC
	overdrive_flash_timer = 0.5
	psycho_bg_timer = 0.0
	psychoball_hitstop_timer = PSYCHOBALL_HITSTOP_SEC
	overdrive_trails.clear()
	boss_special_ready = false
	boss_special_gauge = 0.0
	boss_red_intensity = 0.0
	_play_audio(deps, "play_stage3_psychoball_loop")
	_trigger_psychoball_hitstop_feedback(deps)


func _update_psychoball_hitstop(delta: float) -> void:
	psychoball_hitstop_timer = max(0.0, psychoball_hitstop_timer - delta)


func _update_overdrive(delta: float, context: Dictionary, deps: Dictionary, result: Dictionary) -> void:
	if not overdrive_active:
		return
	var ball_pos: Vector2 = _as_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	if _is_ball_in_dense_smoke(ball_pos, context, deps):
		_neutralize_overdrive_with_smoke(ball_pos, context, deps, result)
		return
	overdrive_timer -= delta
	if overdrive_timer <= 0.0:
		overdrive_active = false
		overdrive_trails.clear()
		psycho_bg_timer = 0.0
		_play_audio(deps, "stop_stage3_psychoball_loop")
		return
	psycho_bg_timer += delta * 60.0
	var ball_vel: Vector2 = _as_vector2(context.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	var curve: float = sin(float(Time.get_ticks_msec()) / 80.0) * 3.0
	ball_vel.x += curve * rng.randf_range(0.5, 1.2) * delta * 60.0
	if rng.randf() < 0.01 * delta * 60.0:
		ball_pos = Vector2(rng.randf_range(50.0, WIDTH - 50.0), rng.randf_range(150.0, HEIGHT - 150.0))
	result["ball_vel"] = ball_vel
	result["ball_pos"] = ball_pos
	var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2(330.0, 25.0)), Vector2(330.0, 25.0))
	var boss_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)), Vector2(100.0, 40.0))
	overdrive_trails.push_front({
		"center": boss_pos + Vector2(boss_size.x * 0.5, boss_size.y * 0.5 + 31.0),
		"alpha": PSYCHOBALL_TRAIL_INITIAL_ALPHA,
	})
	var trail_fade := PSYCHOBALL_TRAIL_FADE_PER_FRAME * delta * 60.0
	for idx in range(overdrive_trails.size() - 1, -1, -1):
		var trail: Dictionary = overdrive_trails[idx]
		trail["alpha"] = float(trail.get("alpha", 0.0)) - trail_fade
		if float(trail["alpha"]) < PSYCHOBALL_TRAIL_MIN_ALPHA:
			overdrive_trails.remove_at(idx)
		else:
			overdrive_trails[idx] = trail
	if overdrive_trails.size() > MAX_OVERDRIVE_TRAILS:
		overdrive_trails.resize(MAX_OVERDRIVE_TRAILS)


func _neutralize_overdrive_with_smoke(ball_pos: Vector2, context: Dictionary, deps: Dictionary, result: Dictionary) -> void:
	overdrive_active = false
	overdrive_timer = 0.0
	overdrive_trails.clear()
	psycho_bg_timer = 0.0
	psychoball_hitstop_timer = 0.0
	_play_audio(deps, "stop_stage3_psychoball_loop")
	_play_psychoball_neutralize_audio(deps)

	var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2(WIDTH * 0.5 - 50.0, 25.0)), Vector2(WIDTH * 0.5 - 50.0, 25.0))
	var boss_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)), Vector2(100.0, 40.0))
	var boss_height: float = max(1.0, float(context.get("boss_hitbox_height", boss_size.y)))
	var boss_center := boss_pos + Vector2(boss_size.x * 0.5, boss_height * 0.5)
	var direction := boss_center - ball_pos
	var ball_vel := Vector2(0.0, -PSYCHOBALL_SMOKE_NEUTRALIZE_SPEED)
	if direction.length() > 0.001:
		ball_vel = direction.normalized() * PSYCHOBALL_SMOKE_NEUTRALIZE_SPEED
	result["ball_vel"] = ball_vel
	result["ball_pos"] = ball_pos
	result["stage3_psychoball_smoke_neutralized"] = true
	_spawn_psychoball_neutralize_particles(ball_pos)


func _is_ball_in_dense_smoke(ball_pos: Vector2, context: Dictionary, deps: Dictionary) -> bool:
	for value in _get_smoke_zones(context, deps):
		var zone: Dictionary = _as_dict(value)
		if zone.is_empty():
			continue
		var opacity: float = float(zone.get("opacity", 0.0))
		var threshold := 50.0 if opacity > 1.0 else PSYCHOBALL_SMOKE_OPACITY_THRESHOLD
		if opacity <= threshold:
			continue
		var center: Vector2 = _get_smoke_zone_center(zone)
		var radius_y: float = float(zone.get("radius", 0.0))
		var radius_x: float = float(zone.get("radius_x", radius_y))
		if radius_x <= 0.0 or radius_y <= 0.0:
			continue
		var dx: float = (ball_pos.x - center.x) / radius_x
		var dy: float = (ball_pos.y - center.y) / radius_y
		if dx * dx + dy * dy <= 1.0:
			return true
	return false


func _get_smoke_zones(context: Dictionary, deps: Dictionary) -> Array:
	for key in ["stage3_smoke_zones", "smoke_zones", "active_item_tear_gas_zones", "tear_gas_zones"]:
		var context_zones := _as_array(context.get(key, []))
		if not context_zones.is_empty():
			return context_zones
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null:
		if active_item_runtime.has_method("get_tear_gas_zones"):
			var runtime_zones := _as_array(active_item_runtime.get_tear_gas_zones())
			if not runtime_zones.is_empty():
				return runtime_zones
		var throw_controller: Object = active_item_runtime.get("throw_controller")
		if throw_controller != null and throw_controller.has_method("get_tear_gas_zones"):
			var controller_zones := _as_array(throw_controller.get_tear_gas_zones())
			if not controller_zones.is_empty():
				return controller_zones
	return []


func _get_smoke_zone_center(zone: Dictionary) -> Vector2:
	if zone.get("position", null) is Vector2:
		return zone.get("position")
	return Vector2(float(zone.get("x", 0.0)), float(zone.get("y", 0.0)))


func _play_psychoball_neutralize_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		return
	if audio.has_method("play_stage3_smoke_neutralize"):
		audio.play_stage3_smoke_neutralize()
	elif audio.has_method("play_paddle_hit"):
		audio.play_paddle_hit()


func _trigger_psychoball_hitstop_feedback(deps: Dictionary) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback != null:
		if feedback.has_method("max_screen_shake"):
			feedback.max_screen_shake(0.12, 7.0)
		elif feedback.has_method("set_screen_shake"):
			feedback.set_screen_shake(0.12, 7.0)


func _spawn_psychoball_neutralize_particles(center: Vector2) -> void:
	psycho_neutralize_particles.append_array(Stage3BossSkillPayloadFactory.build_psychoball_neutralize_particles(
		center,
		PSYCHOBALL_NEUTRALIZE_PARTICLE_COUNT,
		rng
	))
	if psycho_neutralize_particles.size() > MAX_PSYCHOBALL_NEUTRALIZE_PARTICLES:
		_trim_array_from_front(psycho_neutralize_particles, MAX_PSYCHOBALL_NEUTRALIZE_PARTICLES)


func _update_psychoball_neutralize_particles(delta: float) -> void:
	if psycho_neutralize_particles.is_empty():
		return
	var fps_scale := delta * 60.0
	var damping := pow(0.95, fps_scale)
	var write_idx: int = 0
	for idx in range(psycho_neutralize_particles.size()):
		var particle: Dictionary = psycho_neutralize_particles[idx]
		particle["x"] = float(particle.get("x", 0.0)) + float(particle.get("vx", 0.0)) * fps_scale
		particle["y"] = float(particle.get("y", 0.0)) + float(particle.get("vy", 0.0)) * fps_scale
		particle["vx"] = float(particle.get("vx", 0.0)) * damping
		particle["vy"] = float(particle.get("vy", 0.0)) * damping
		particle["life_frames"] = float(particle.get("life_frames", 0.0)) - fps_scale
		if float(particle.get("life_frames", 0.0)) <= 0.0:
			continue
		psycho_neutralize_particles[write_idx] = particle
		write_idx += 1
	if write_idx < psycho_neutralize_particles.size():
		psycho_neutralize_particles.resize(write_idx)


func _activate_tail_whip(target: Vector2) -> void:
	tail_whip_active = true
	tail_whip_timer = TAIL_DURATION_SEC
	tail_hit_ball = false
	tail_whip_target = target
	tail_has_target = true
	tail_points = _build_tail_points(0.0, tail_whip_target)


func _update_tail_whip(delta: float, context: Dictionary, deps: Dictionary, result: Dictionary) -> void:
	if tail_curve_active:
		tail_curve_timer = max(0.0, tail_curve_timer - delta)
		var ball_vel: Vector2 = _as_vector2(result.get("ball_vel", context.get("ball_vel", Vector2.ZERO)), Vector2.ZERO)
		var curve_strength: float = 0.3 * (tail_curve_timer / TAIL_CURVE_DURATION_SEC)
		ball_vel.x += float(tail_curve_direction) * curve_strength * delta * 60.0
		if ball_vel.length() > TAIL_BASE_SPEED_MAX:
			ball_vel = ball_vel.normalized() * TAIL_BASE_SPEED_MAX
		result["ball_vel"] = ball_vel
		if tail_curve_timer <= 0.0:
			tail_curve_active = false
	if not tail_whip_active:
		tail_points.clear()
		return
	tail_whip_timer = max(0.0, tail_whip_timer - delta)
	var progress: float = 1.0 - tail_whip_timer / max(0.001, TAIL_DURATION_SEC)
	if progress < TAIL_TRACK_PROGRESS_LIMIT:
		tail_whip_target = _as_vector2(result.get("ball_pos", context.get("ball_pos", tail_whip_target)), tail_whip_target)
	tail_points = _build_tail_points(progress, tail_whip_target)
	if not tail_hit_ball and _tail_hits_ball(progress, _as_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)):
		_apply_tail_hit(context, deps, result)
	if tail_whip_timer <= 0.0:
		tail_whip_active = false
		tail_whip_cooldown = _roll_tail_cooldown()
		tail_has_target = false
		tail_points.clear()


func _tail_hits_ball(progress: float, ball_pos: Vector2) -> bool:
	if progress < TAIL_HIT_PROGRESS_MIN or progress > TAIL_HIT_PROGRESS_MAX:
		return false
	if tail_points.size() < 2:
		return false
	@warning_ignore("integer_division")
	var mid_index: int = int(tail_points.size() / 2)
	var start_index: int = max(0, mid_index - TAIL_COLLISION_MID_INDEX_RANGE)
	var end_index: int = min(tail_points.size(), mid_index + TAIL_COLLISION_MID_INDEX_RANGE)
	for idx in range(start_index, end_index):
		if ball_pos.distance_to(tail_points[idx]) < TAIL_HIT_RADIUS:
			return true
	return false


func _apply_tail_hit(context: Dictionary, deps: Dictionary, result: Dictionary) -> void:
	tail_hit_ball = true
	tail_curve_active = true
	tail_curve_timer = TAIL_CURVE_DURATION_SEC
	var ball_pos: Vector2 = _as_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var ball_vel: Vector2 = _as_vector2(result.get("ball_vel", context.get("ball_vel", Vector2.ZERO)), Vector2.ZERO)
	var center := Vector2(WIDTH * 0.5, HEIGHT * 0.5)
	var direction: Vector2 = center - ball_pos
	if direction.length() > 0.0:
		direction = direction.normalized()
	var speed: float = ball_vel.length() * 0.85
	var redirected_vel: Vector2 = direction * speed
	result["ball_vel"] = redirected_vel
	result["ball_impact_boost"] = 1.0
	tail_curve_direction = 1 if ball_pos.x < center.x else -1
	_create_tail_hit_burst(ball_pos, redirected_vel)
	_create_prism_burst(ball_pos, true)
	_create_ball_impact_effect(ball_pos, deps)
	_spawn_tail_starpoint_drop(ball_pos, deps, context)
	_play_audio(deps, "play_stage3_tail")


func _build_tail_points(progress: float, target: Vector2) -> Array[Vector2]:
	var center := Vector2(WIDTH * 0.5, HEIGHT * 0.5)
	var angle_to_target: float = atan2(target.y - center.y, target.x - center.x)
	var distance_to_target: float = center.distance_to(target)
	var angle_to_ball: float = angle_to_target
	if progress < 0.3:
		angle_to_ball = angle_to_target + PI
	var tail_base_angle: float = angle_to_ball
	var tail_base := center
	var frame_time: float = float(Time.get_ticks_msec()) * 0.06
	var points: Array[Vector2] = []
	for idx in range(TAIL_POINT_COUNT):
		var t: float = float(idx) / float(TAIL_POINT_COUNT - 1)
		var wave: float = 0.0
		var distance: float = 0.0
		var depth_offset: float = 0.0
		if progress < 0.3:
			var spiral: float = t * PI * 4.0
			var wave_amplitude: float = 30.0 * (1.0 - t * 0.5)
			wave = sin(spiral - progress * PI * 3.0) * wave_amplitude
			distance = 25.0 * t * t * (1.0 - progress * 2.0)
		elif progress < 0.6:
			var whip_power: float = (progress - 0.3) / 0.3
			distance = distance_to_target * t * whip_power
			var wave_amplitude: float = 5.0 * (1.0 - t) * (1.0 - whip_power)
			wave = sin(t * PI * 2.0) * wave_amplitude
		else:
			var recovery: float = (progress - 0.6) / 0.4
			var spiral: float = t * PI * 2.0
			var wave_amplitude: float = 15.0 * (1.0 - t * 0.5) * recovery
			wave = sin(spiral + frame_time * 0.01) * wave_amplitude
			distance = 35.0 * t * t * (0.5 + recovery * 0.5)
			depth_offset = cos(frame_time * 0.008 + t * 3.0) * 8.0 * (1.0 - t) * recovery
		var tail_angle: float = tail_base_angle + wave * 0.02
		points.append(tail_base + Vector2(
			distance * cos(tail_angle) + depth_offset * sin(tail_angle),
			distance * sin(tail_angle) - depth_offset * cos(tail_angle)
		))
	return points


func _update_kuromi(delta: float, context: Dictionary, deps: Dictionary, result: Dictionary) -> void:
	var ball_pos: Vector2 = _as_vector2(result.get("ball_pos", context.get("ball_pos", Vector2.ZERO)), Vector2.ZERO)
	_update_kuromi_spit_trail(delta, ball_pos)
	_update_kuromi_eating_particles(delta)
	if kuromi_eating_active:
		_update_kuromi_eating(delta, deps, result)
		return
	result["stage3_kuromi_ball_hidden"] = false
	if kuromi_petrified or kuromi_awakening or not kuromi_awakened or overdrive_active or kuromi_eating_cooldown > 0.0:
		return
	var kuromi_rect := Rect2(Vector2(WIDTH * 0.5 - 60.0, HEIGHT * 0.5 - 60.0), Vector2(120.0, 120.0))
	var ball_size: float = max(1.0, float(context.get("ball_size", 28.6)))
	var ball_rect := Rect2(ball_pos - Vector2(ball_size * 0.5, ball_size * 0.5), Vector2(ball_size, ball_size))
	var ball_in_area: bool = kuromi_rect.intersects(ball_rect)
	if ball_in_area and not kuromi_ball_entered and rng.randf() < KUROMI_EAT_CHANCE:
		if _should_defer_kuromi_eating_for_ball_owner(context, result, deps):
			kuromi_ball_entered = ball_in_area
			return
		_start_kuromi_eating(ball_pos, deps)
		result["stage3_kuromi_ball_hidden"] = true
	kuromi_ball_entered = ball_in_area


func _should_defer_kuromi_eating_for_ball_owner(context: Dictionary, result: Dictionary, deps: Dictionary) -> bool:
	if bool(result.get("skip_ball_motion_step", context.get("skip_ball_motion_step", false))):
		return true
	var viper_skill_runtime: Object = deps.get("viper_skill_runtime", null)
	if viper_skill_runtime == null or not viper_skill_runtime.has_method("get_snapshot"):
		return false
	var viper_snapshot: Dictionary = viper_skill_runtime.get_snapshot()
	var chaos_state: String = str(viper_snapshot.get("chaos_state", "idle"))
	return chaos_state != "" and chaos_state != "idle"


func _start_kuromi_eating(ball_pos: Vector2, deps: Dictionary) -> void:
	var center := Vector2(WIDTH * 0.5, HEIGHT * 0.5)
	kuromi_eating_active = true
	kuromi_eating_timer = 0.0
	kuromi_eating_cooldown = KUROMI_EAT_COOLDOWN_SEC
	kuromi_has_spit_angle = false
	kuromi_spit_angle = 0.0
	kuromi_mouth_direction = 0.0
	kuromi_mouth_open = 0.0
	kuromi_chewing_phase = 0.0
	kuromi_tongue_extended = 0.0
	kuromi_tongue_wrap_phase = 0.0
	kuromi_ball_on_tongue = true
	kuromi_eat_source_pos = ball_pos
	kuromi_ball_tongue_pos = ball_pos
	kuromi_tongue_angle = atan2(ball_pos.y - center.y, ball_pos.x - center.x)
	kuromi_swallow_sound_played = false
	kuromi_spit_sound_played = false
	kuromi_eating_particles.clear()
	_play_audio(deps, "play_stage3_kuromi_tongue")


func _update_kuromi_eating(delta: float, deps: Dictionary, result: Dictionary) -> void:
	var fps_scale: float = delta * 60.0
	kuromi_eating_timer += fps_scale
	result["stage3_kuromi_ball_hidden"] = true
	if not kuromi_spit_sound_played and kuromi_eating_timer >= KUROMI_EAT_RELEASE_FRAMES - KUROMI_SPIT_SOUND_LEAD_FRAMES:
		kuromi_spit_sound_played = true
		_play_audio(deps, "play_stage3_kuromi_spit")
	if kuromi_eating_timer < KUROMI_EAT_TONGUE_EXTEND_FRAMES:
		kuromi_tongue_extended = _ease_out_elastic(kuromi_eating_timer / KUROMI_EAT_TONGUE_EXTEND_FRAMES)
		kuromi_tongue_wrap_phase = 0.0
		kuromi_mouth_open = (kuromi_eating_timer / KUROMI_EAT_TONGUE_EXTEND_FRAMES) * 0.6
		kuromi_ball_on_tongue = true
		kuromi_ball_tongue_pos = kuromi_eat_source_pos
	elif kuromi_eating_timer < KUROMI_EAT_TONGUE_WRAP_FRAMES:
		var grab_progress: float = (kuromi_eating_timer - KUROMI_EAT_TONGUE_EXTEND_FRAMES) / (KUROMI_EAT_TONGUE_WRAP_FRAMES - KUROMI_EAT_TONGUE_EXTEND_FRAMES)
		kuromi_tongue_extended = 1.0 - grab_progress * 0.9
		kuromi_tongue_wrap_phase = grab_progress
		kuromi_mouth_open = 0.6 + grab_progress * 0.4
		kuromi_ball_on_tongue = true
		kuromi_ball_tongue_pos = kuromi_eat_source_pos.lerp(Vector2(WIDTH * 0.5, HEIGHT * 0.5 + 20.0), grab_progress)
	elif kuromi_eating_timer < KUROMI_EAT_SWALLOW_FRAMES:
		var swallow_progress: float = (kuromi_eating_timer - KUROMI_EAT_TONGUE_WRAP_FRAMES) / (KUROMI_EAT_SWALLOW_FRAMES - KUROMI_EAT_TONGUE_WRAP_FRAMES)
		if not kuromi_swallow_sound_played:
			kuromi_swallow_sound_played = true
			_play_audio(deps, "play_stage3_kuromi_swallow")
		kuromi_tongue_extended = max(0.0, 0.1 - swallow_progress * 0.1)
		kuromi_tongue_wrap_phase = 1.0
		if swallow_progress < 0.5:
			kuromi_mouth_open = 1.0
		else:
			kuromi_mouth_open = 1.0 - (swallow_progress - 0.5) * 1.6
		kuromi_ball_on_tongue = false
		if rng.randf() < min(1.0, 0.6 * fps_scale):
			for _idx in range(3):
				_spawn_kuromi_mouth_particle(Vector2(WIDTH * 0.5, HEIGHT * 0.5 + 25.0), false)
	elif kuromi_eating_timer < KUROMI_EAT_CHEW_FRAMES:
		var chew_progress: float = (kuromi_eating_timer - KUROMI_EAT_SWALLOW_FRAMES) / (KUROMI_EAT_CHEW_FRAMES - KUROMI_EAT_SWALLOW_FRAMES)
		kuromi_tongue_extended = 0.0
		kuromi_ball_on_tongue = false
		kuromi_chewing_phase = chew_progress
		var chew_cycle: float = sin(chew_progress * PI * 8.0)
		kuromi_mouth_open = 0.15 + absf(chew_cycle) * 0.35
		if rng.randf() < min(1.0, 0.3 * fps_scale):
			_spawn_kuromi_mouth_particle(Vector2(WIDTH * 0.5, HEIGHT * 0.5 + 20.0), false)
	elif kuromi_eating_timer < KUROMI_EAT_DIRECTION_FRAMES:
		if not kuromi_has_spit_angle:
			kuromi_spit_angle = _roll_kuromi_spit_angle()
			kuromi_has_spit_angle = true
		kuromi_mouth_direction = kuromi_spit_angle
		var buildup: float = (kuromi_eating_timer - KUROMI_EAT_CHEW_FRAMES) / (KUROMI_EAT_DIRECTION_FRAMES - KUROMI_EAT_CHEW_FRAMES)
		kuromi_mouth_open = 0.2 + buildup * 0.4
		kuromi_chewing_phase = 0.0
		if rng.randf() < min(1.0, 0.8 * fps_scale):
			_spawn_kuromi_mouth_particle(Vector2(WIDTH * 0.5, HEIGHT * 0.5), true)
	elif kuromi_eating_timer < KUROMI_EAT_RELEASE_FRAMES:
		if not kuromi_has_spit_angle:
			kuromi_spit_angle = _roll_kuromi_spit_angle()
			kuromi_has_spit_angle = true
		kuromi_mouth_direction = kuromi_spit_angle
		var pressure_progress: float = (kuromi_eating_timer - KUROMI_EAT_DIRECTION_FRAMES) / (KUROMI_EAT_RELEASE_FRAMES - KUROMI_EAT_DIRECTION_FRAMES)
		kuromi_mouth_open = 0.6 + 0.4 * pressure_progress
		kuromi_chewing_phase = 0.0
		if rng.randf() < min(1.0, 0.9 * fps_scale):
			_spawn_kuromi_mouth_particle(Vector2(WIDTH * 0.5, HEIGHT * 0.5), true)
	else:
		_finish_kuromi_eating(result, deps)


func _finish_kuromi_eating(result: Dictionary, deps: Dictionary = {}) -> void:
	var center := Vector2(WIDTH * 0.5, HEIGHT * 0.5)
	kuromi_eating_active = false
	kuromi_eating_timer = 0.0
	kuromi_mouth_open = 0.0
	kuromi_chewing_phase = 0.0
	kuromi_tongue_extended = 0.0
	kuromi_tongue_wrap_phase = 0.0
	kuromi_ball_on_tongue = false
	result["stage3_kuromi_ball_hidden"] = false
	result["ball_pos"] = center
	result["ball_vel"] = _get_kuromi_spit_velocity()
	result["skip_ball_motion_step"] = false
	result["ball_impact_boost"] = 1.0
	_release_external_ball_owner_for_kuromi_spit(result, deps)
	kuromi_spit_trail.clear()
	kuromi_spit_trail_phase = 0.0
	kuromi_spit_trail_frame = 0.0
	kuromi_spit_trail.append(Stage3BossSkillPayloadFactory.build_kuromi_spit_trail_point(center, 18.0))
	for _idx in range(25):
		_spawn_kuromi_mouth_particle(center, true)
	_create_prism_burst(center)


func _release_external_ball_owner_for_kuromi_spit(result: Dictionary, deps: Dictionary) -> void:
	var viper_skill_runtime: Object = deps.get("viper_skill_runtime", null)
	if viper_skill_runtime == null or not viper_skill_runtime.has_method("release_chaos_blackhole_from_hit"):
		return
	var release_context := {
		"ball_pos": _as_vector2(result.get("ball_pos", Vector2(WIDTH * 0.5, HEIGHT * 0.5)), Vector2(WIDTH * 0.5, HEIGHT * 0.5)),
		"ball_vel": _as_vector2(result.get("ball_vel", Vector2.ZERO), Vector2.ZERO),
	}
	if bool(viper_skill_runtime.release_chaos_blackhole_from_hit(deps, release_context)):
		result["skip_ball_motion_step"] = false


func _ease_out_elastic(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0
	var period := 0.3
	var shift := period / 4.0
	return pow(2.0, -10.0 * t) * sin((t - shift) * TAU / period) + 1.0


func _roll_kuromi_spit_angle() -> float:
	if rng.randf() < 0.5:
		return rng.randf_range(-KUROMI_SPIT_ANGLE_LIMIT, -KUROMI_SPIT_HORIZONTAL_EXCLUSION)
	return rng.randf_range(KUROMI_SPIT_HORIZONTAL_EXCLUSION, KUROMI_SPIT_ANGLE_LIMIT)


func _get_kuromi_spit_velocity() -> Vector2:
	if not kuromi_has_spit_angle:
		kuromi_spit_angle = _roll_kuromi_spit_angle()
		kuromi_has_spit_angle = true
	var speed: float = rng.randf_range(KUROMI_SPIT_SPEED_MIN, KUROMI_SPIT_SPEED_MAX) * KUROMI_SPIT_SPEED_MULT
	return Vector2(cos(kuromi_spit_angle), sin(kuromi_spit_angle)) * speed


func _update_kuromi_spit_trail(delta: float, ball_pos: Vector2) -> void:
	if kuromi_spit_trail.size() <= 0:
		return
	var fps_scale: float = delta * 60.0
	kuromi_spit_trail_frame += fps_scale
	kuromi_spit_trail_phase = fposmod(kuromi_spit_trail_phase + 0.1 * fps_scale, 1.0)
	if int(floor(kuromi_spit_trail_frame)) % 3 == 0:
		kuromi_spit_trail.append(Stage3BossSkillPayloadFactory.build_kuromi_spit_trail_point(ball_pos, 15.0))
	var write_idx: int = 0
	for idx in range(kuromi_spit_trail.size()):
		var p: Dictionary = kuromi_spit_trail[idx]
		p["life"] = float(p["life"]) - 0.02 * fps_scale
		p["size"] = float(p["size"]) * pow(0.98, fps_scale)
		if float(p["life"]) <= 0.0:
			continue
		kuromi_spit_trail[write_idx] = p
		write_idx += 1
	if write_idx < kuromi_spit_trail.size():
		kuromi_spit_trail.resize(write_idx)
	if kuromi_spit_trail.size() > 30:
		_trim_array_from_front(kuromi_spit_trail, 30)


func _spawn_kuromi_mouth_particle(center: Vector2, directional: bool) -> void:
	kuromi_eating_particles.append(Stage3BossSkillPayloadFactory.build_kuromi_mouth_particle(
		center,
		kuromi_mouth_direction,
		directional,
		rng
	))
	if kuromi_eating_particles.size() > MAX_KUROMI_EATING_PARTICLES:
		_trim_array_from_front(kuromi_eating_particles, MAX_KUROMI_EATING_PARTICLES)


func _update_kuromi_eating_particles(delta: float) -> void:
	var write_idx: int = 0
	for idx in range(kuromi_eating_particles.size()):
		var p: Dictionary = kuromi_eating_particles[idx]
		p["x"] = float(p.get("x", 0.0)) + float(p.get("vx", 0.0)) * delta * 60.0
		p["y"] = float(p.get("y", 0.0)) + float(p.get("vy", 0.0)) * delta * 60.0
		p["vy"] = float(p.get("vy", 0.0)) + 0.03 * delta * 60.0
		p["life"] = float(p.get("life", 0.0)) - delta
		if float(p.get("life", 0.0)) <= 0.0:
			continue
		kuromi_eating_particles[write_idx] = p
		write_idx += 1
	if write_idx < kuromi_eating_particles.size():
		kuromi_eating_particles.resize(write_idx)


func _update_tail_hit_bursts(delta: float) -> void:
	var write_idx: int = 0
	for idx in range(tail_hit_bursts.size()):
		var burst: Dictionary = tail_hit_bursts[idx]
		burst["life"] = float(burst.get("life", 0.0)) - delta
		if float(burst.get("life", 0.0)) <= 0.0:
			continue
		tail_hit_bursts[write_idx] = burst
		write_idx += 1
	if write_idx < tail_hit_bursts.size():
		tail_hit_bursts.resize(write_idx)


func _create_tail_hit_burst(pos: Vector2, redirected_vel: Vector2) -> void:
	tail_hit_bursts.append(Stage3BossSkillPayloadFactory.build_tail_hit_burst(
		pos,
		redirected_vel,
		TAIL_HIT_BURST_SEC,
		rng
	))
	if tail_hit_bursts.size() > MAX_TAIL_HIT_BURSTS:
		_trim_array_from_front(tail_hit_bursts, MAX_TAIL_HIT_BURSTS)


func _spawn_tail_starpoint_drop(ball_pos: Vector2, deps: Dictionary, context: Dictionary) -> void:
	var drop_pos := Vector2(
		clamp(
			ball_pos.x + float(rng.randi_range(-30, 30)),
			StagePlayfieldBounds.get_left(context) + STARPOINT_DROP_SIZE,
			StagePlayfieldBounds.get_right(context, WIDTH) - STARPOINT_DROP_SIZE
		),
		clamp(
			ball_pos.y + float(rng.randi_range(-30, 30)),
			STARPOINT_DROP_SIZE,
			StagePlayfieldBounds.get_height(context, HEIGHT) - STARPOINT_DROP_SIZE
		)
	)
	_spawn_starpoint_drop_at(drop_pos, deps, context, true, false, "menhera_tail")


func _spawn_starpoint_drop_at(
	pos: Vector2,
	deps: Dictionary = {},
	context: Dictionary = {},
	allow_star_detector_bonus: bool = true,
	star_detector_bonus: bool = false,
	source_type: String = "menhera_tail"
) -> void:
	starpoint_drops.append(StarpointPayloadFactory.build_drop(
		pos,
		rng,
		star_detector_bonus,
		STARPOINT_DROP_SIZE,
		STARPOINT_DROP_LIFETIME,
		0.05,
		0.1,
		source_type
	))
	if starpoint_drops.size() > MAX_STAGE3_STARPOINT_DROPS:
		_trim_array_from_front(starpoint_drops, MAX_STAGE3_STARPOINT_DROPS)
	_spawn_starpoint_particles(pos, STARPOINT_PARTICLE_COUNT + (6 if star_detector_bonus else 0), 1.2 if star_detector_bonus else 1.0)
	if allow_star_detector_bonus:
		_spawn_star_detector_bonus_drops(pos, deps, context)


func _spawn_star_detector_bonus_drops(pos: Vector2, deps: Dictionary, context: Dictionary) -> void:
	var bonus_count: int = StarpointBonusDropPolicy.roll_star_detector_bonus_drop_count(deps, context)
	for _idx in range(bonus_count):
		var bonus_pos := Vector2(
			clamp(
				pos.x + float(STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES[rng.randi_range(0, STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES.size() - 1)]),
				StagePlayfieldBounds.get_left(context) + STARPOINT_DROP_SIZE,
				StagePlayfieldBounds.get_right(context, WIDTH) - STARPOINT_DROP_SIZE
			),
			clamp(
				pos.y + float(STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES[rng.randi_range(0, STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES.size() - 1)]),
				STARPOINT_DROP_SIZE,
				StagePlayfieldBounds.get_height(context, HEIGHT) - STARPOINT_DROP_SIZE
			)
		)
		_spawn_starpoint_drop_at(bonus_pos, deps, context, false, true, "menhera_tail")


func _update_starpoint_drops(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	if starpoint_drops.is_empty():
		return
	var player_rect := Rect2(
		_as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO),
		_as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	)
	var player_rects: Array[Rect2] = StagePlayerInteractionRects.get_player_interaction_rects(player_rect, deps)
	var play_left: float = StagePlayfieldBounds.get_left(context)
	var play_right: float = StagePlayfieldBounds.get_right(context, WIDTH)
	var play_height: float = StagePlayfieldBounds.get_height(context, HEIGHT)
	var drop_count := starpoint_drops.size()
	var next_drops: Array = []
	for index in range(drop_count):
		var drop_value: Variant = starpoint_drops[index]
		var d: Dictionary = drop_value if drop_value is Dictionary else {}
		if not StarpointDropMotionState.update_drop(
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
				starpoint_drops = StarpointCollectionCompaction.build_preserved_after_modal(starpoint_drops, next_drops, index, drop_count)
				return
			if starpoint_drops.size() < drop_count:
				return
			continue
		if bool(starlight_tracking_result.get("claimed", false)):
			next_drops.append(d)
			continue

		if StarpointDropOverlapQuery.overlaps_any_circle_player(d, player_rects, STARPOINT_DROP_SIZE):
			if _collect_starpoint_drop(d, context, deps):
				starpoint_drops = StarpointCollectionCompaction.build_preserved_after_modal(starpoint_drops, next_drops, index, drop_count)
				return
			if starpoint_drops.size() < drop_count:
				return
			continue
		next_drops.append(d)
	starpoint_drops = next_drops


func _collect_starpoint_drop(drop: Dictionary, context: Dictionary, deps: Dictionary) -> bool:
	var opened_choice: bool = StarpointCollectionRewardPolicy.collect_starpoint_reward(context, deps)
	var pos: Vector2 = _as_vector2(drop.get("pos", Vector2.ZERO), Vector2.ZERO)
	_spawn_starpoint_particles(pos, STARPOINT_PARTICLE_COUNT + 10, 1.4)
	_play_starpoint_collect_sound(deps)
	StarpointCollectionRewardPolicy.request_owner_redraw(context)
	return opened_choice


func _spawn_starpoint_particles(pos: Vector2, count: int, intensity: float) -> void:
	starpoint_particles.append_array(StarpointPayloadFactory.build_particles(
		pos,
		count,
		intensity,
		rng,
		STARPOINT_PARTICLE_LIFE
	))
	if starpoint_particles.size() > MAX_STAGE3_STARPOINT_PARTICLES:
		_trim_array_from_front(starpoint_particles, MAX_STAGE3_STARPOINT_PARTICLES)


func _update_starpoint_particles(fps_scale: float) -> void:
	StarpointParticleState.update_particles(starpoint_particles, fps_scale)


func _play_starpoint_collect_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_starpoint_collect"):
		audio.play_starpoint_collect()


func _update_prism_particles(delta: float) -> void:
	var fps_scale: float = delta * 60.0
	var damping: float = pow(0.98, fps_scale)
	var write_idx: int = 0
	for idx in range(prism_particles.size()):
		var p: Dictionary = prism_particles[idx]
		p["x"] = float(p["x"]) + float(p["vx"]) * fps_scale
		p["y"] = float(p["y"]) + float(p["vy"]) * fps_scale
		p["vy"] = (float(p["vy"]) + 0.10 * fps_scale) * damping
		p["vx"] = float(p["vx"]) * damping
		p["sparkle"] = float(p.get("sparkle", 0.0)) + 0.30 * fps_scale
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			continue
		prism_particles[write_idx] = p
		write_idx += 1
	if write_idx < prism_particles.size():
		prism_particles.resize(write_idx)


func _create_prism_burst(center: Vector2, strong: bool = false) -> void:
	var particle_count: int = rng.randi_range(TAIL_HIT_PRISM_MIN_COUNT, TAIL_HIT_PRISM_MAX_COUNT) if strong else 18
	prism_particles.append_array(Stage3BossSkillPayloadFactory.build_prism_particles(
		center,
		particle_count,
		strong,
		rng
	))
	if prism_particles.size() > MAX_PRISM_PARTICLES:
		_trim_array_from_front(prism_particles, MAX_PRISM_PARTICLES)


func _create_ball_impact_effect(pos: Vector2, deps: Dictionary) -> void:
	var impact_effects: Object = deps.get("impact_effects", null)
	if impact_effects != null and impact_effects.has_method("create_energy_explosion"):
		impact_effects.create_energy_explosion(pos, 1.0, 1.0)


func _sync_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("sync_stage3_psychoball_loop"):
		audio.sync_stage3_psychoball_loop(overdrive_active)


func _play_audio(deps: Dictionary, method: String) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method(method):
		audio.call(method)


func _get_status() -> String:
	if kuromi_awakening:
		return "kuromi_awakening"
	if kuromi_eating_active:
		return "kuromi_eating"
	if overdrive_active:
		return "psycho_ball"
	if tail_whip_active:
		return "tail_whip"
	if curse_phase != "idle":
		return "curse_chest"
	if tears_active:
		return "tears"
	return "charging"


func _get_tears_hud_skill() -> Dictionary:
	return _build_cooldown_skill("tear_shower", "눈물샤워", tears_active, tears_cooldown, TEARS_COOLDOWN_SEC, Color(0.55, 0.82, 1.0, 1.0))


func _get_curse_hud_skill() -> Dictionary:
	return _build_cooldown_skill("curse_chest", "저주상자", curse_phase != "idle", curse_cooldown, CURSE_CHEST_COOLDOWN_SEC, Color(1.0, 0.38, 0.68, 1.0))


func _get_psychoball_hud_skill() -> Dictionary:
	return {
		"id": "psycho_ball",
		"label": "사이코볼",
		"status": "casting" if overdrive_active else ("ready" if psycho_cooldown <= 0.0 else "charging"),
		"cooldown_remaining": psycho_cooldown,
		"cooldown_total": PSYCHOBALL_COOLDOWN_SEC,
		"progress": 1.0 if overdrive_active else _cooldown_progress(psycho_cooldown, PSYCHOBALL_COOLDOWN_SEC),
		"ready": not overdrive_active and psycho_cooldown <= 0.0,
		"trigger_type": "hit",
		"color": Color(0.86, 0.20, 1.0, 1.0),
	}


func _build_cooldown_skill(id: String, label: String, active: bool, cooldown: float, total: float, color: Color) -> Dictionary:
	var status_text := "casting" if active else ("ready" if cooldown <= 0.0 else "charging")
	return {
		"id": id,
		"label": label,
		"status": status_text,
		"cooldown_remaining": cooldown,
		"cooldown_total": total,
		"progress": 1.0 if active else _cooldown_progress(cooldown, total),
		"ready": status_text == "ready",
		"trigger_type": "auto",
		"color": color,
	}


func _cooldown_progress(remaining: float, total: float) -> float:
	return clamp(1.0 - max(0.0, remaining) / max(0.001, total), 0.0, 1.0)


func _roll_tail_cooldown() -> float:
	return rng.randf_range(TAIL_COOLDOWN_MIN_SEC, TAIL_COOLDOWN_MAX_SEC)


func _quadratic(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a * pow(1.0 - t, 2.0) + b * (2.0 * (1.0 - t) * t) + c * pow(t, 2.0)


func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq <= 0.001:
		return p.distance_to(a)
	var t: float = clamp((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
