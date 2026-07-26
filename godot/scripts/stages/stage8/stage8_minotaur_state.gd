extends RefCounted

# Stage 8 미노타우로스 (Minotaur) state owner — SLICE 1 PLACEHOLDER SHELL.
# Ported from stage7_akamu_state.gd: keeps the EXACT public contract the battle
# framework + sibling modules call by name, but every active-skill body is a
# safe no-op. Skills / VFX / clones / projectiles / intangibility land later;
# Slice 5 owns the signature 대지강타 지진 (Earthquake Smash).
# RESERVED-ASSET NOTE: no stage8 boss sheet / pillar / HUD PNG / BGM exists yet,
# so this module wires ZERO res:// paths — the placeholder is drawn code-native.

const PlayerKnockbackImmunity := preload("res://scripts/stages/common/player_knockback_immunity.gd")

const STAGE_ID := 8
const BOSS_NAME := "미노타우로스"
const LEGACY_FPS := 60.0
const MAX_DELTA_SEC := 0.1
const GAUGE_MAX := 500.0
const ROUND_GAUGE_CARRY_RATIO := 0.7
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0

const BOSS_HIT_GAUGE_GAIN := 80.0
const AWAKEN_SCORE_THRESHOLD := 3
const AWAKEN_FREEZE_SEC := 3.0
const COMMON_BOSS_DASH_GAUGE_COST := 50.0

# --- Slice-5 design seed: 대지강타 지진 (Earthquake Smash) ---------------------
# The Minotaur's signature ground-pound earthquake will read boss_special_gauge,
# briefly freeze the ball, and emit a shockwave that CCs the player paddle. Kept
# here only as the gauge cost + an empty seed method so the shell boots without
# any active-skill logic, ball intangibility, or clones.
const EARTHQUAKE_GAUGE_COST := 250.0

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
var _scripted_boss_pos := Vector2.ZERO
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
	_last_boss_pos = Vector2(330.0, 25.0)
	_last_boss_size = Vector2(100.0, 40.0)
	_last_boss_visual_scale = 1.0
	_has_score_round_generation = false
	_last_score_round_generation = 0
	status = "charging"


func reset_for_result() -> void:
	reset()


func clear_round_transients() -> void:
	# Intentionally idempotent. Generic ball cleanup may reach this more than once
	# for one score boundary, so it must never alter persistent gauge/awakening.
	_gameplay_freeze_remaining_sec = 0.0
	_gameplay_freeze_reason = ""
	_awakening_intro_pending = false
	_boss_ball_intangible = false
	_boss_ball_intangible_sources.clear()
	_scripted_boss_pos = Vector2.ZERO
	status = "charging"


func reset_round() -> void:
	# Compatibility alias for older stage cleanup fanouts.
	clear_round_transients()


func apply_score_round_carry(round_generation: int) -> bool:
	# A score event and the later ball-reset path can describe the same round;
	# accept only a newer generation so the 0.7 carry cannot be applied twice.
	if _has_score_round_generation and round_generation <= _last_score_round_generation:
		return false
	_has_score_round_generation = true
	_last_score_round_generation = round_generation
	boss_special_gauge = float(int(clampf(boss_special_gauge, 0.0, GAUGE_MAX) * ROUND_GAUGE_CARRY_RATIO))
	return true


func handle_score_event(_scoring_side: String, _score_result: Dictionary) -> void:
	# Stage 8 does not inherit Stage 7 Akamu's score-three Awakening. The chosen
	# Slice-5 mechanic is Earthquake Smash and remains inactive until implemented.
	pass


func try_begin_pending_awakening() -> bool:
	# Compatibility method only. No Stage 8 Awakening is designed or wired.
	return false


func update(delta: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	_cache_boss_geometry(context)
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		if _has_runtime_state():
			reset()
		return _build_result()
	var clamped_delta := clampf(delta, 0.0, MAX_DELTA_SEC)
	if is_gameplay_freeze_active():
		return advance_gameplay_freeze(clamped_delta, context, deps)
	if _is_timing_frozen(context):
		status = "paused"
		return _build_result()
	# Slice 1: boss gauge is the only live scaffold; no active-skill ticking yet.
	status = "awakened" if awakened else "charging"
	return _build_result()


func is_gameplay_freeze_active() -> bool:
	return _gameplay_freeze_remaining_sec > 0.0


func advance_gameplay_freeze(delta: float, context: Dictionary = {}, deps: Dictionary = {}) -> Dictionary:
	_cache_boss_geometry(context)
	var clamped_delta := clampf(delta, 0.0, MAX_DELTA_SEC)
	_gameplay_freeze_remaining_sec = maxf(0.0, _gameplay_freeze_remaining_sec - clamped_delta)
	var completed_reason: String = _gameplay_freeze_reason
	if not is_gameplay_freeze_active():
		_gameplay_freeze_reason = ""
		if completed_reason == "awakening":
			_complete_awakening(context, deps)
	status = (
		_gameplay_freeze_reason + "_freeze"
		if is_gameplay_freeze_active()
		else ("awakened" if awakened else "charging")
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
	_boss_ball_intangible = not _boss_ball_intangible_sources.is_empty()


func resolve_wind_aura_collision(_ball_pos: Vector2, _ball_vel: Vector2, _context: Dictionary, _deps: Dictionary = {}) -> Dictionary:
	# Slice 1: awakened wind-aura block is not implemented yet.
	return {}


func query_clone_ball_collision(_from_pos: Vector2, _to_pos: Vector2, _ball_vel: Vector2, _context: Dictionary, _deps: Dictionary = {}) -> Dictionary:
	# Slice 1: no shadow clones.
	return {}


func resolve_ball_collision(_scene: Dictionary, _context: Dictionary, _deps: Dictionary = {}) -> bool:
	# Slice 1: no clone / auxiliary-paddle collision path.
	return false


func handle_boss_paddle_hit(_scene: Dictionary, context: Dictionary, deps: Dictionary = {}) -> void:
	# Pure notification boundary. Slice 1 keeps only the gauge scaffold; the
	# 대지강타 earthquake skill start lands in Slice 5.
	if _is_boss_skill_cooldown_paused(context, deps):
		return
	boss_special_gauge = minf(GAUGE_MAX, boss_special_gauge + BOSS_HIT_GAUGE_GAIN)


func drain_boss_special_gauge(amount: float) -> void:
	boss_special_gauge = maxf(0.0, boss_special_gauge - maxf(0.0, amount))


func try_commit_common_boss_dash() -> bool:
	if boss_special_gauge < COMMON_BOSS_DASH_GAUGE_COST:
		return false
	boss_special_gauge -= COMMON_BOSS_DASH_GAUGE_COST
	return true


func get_boss_ai_context() -> Dictionary:
	return {
		"stage8_minotaur_boss_gauge": boss_special_gauge,
		"stage8_minotaur_awakened": awakened,
		"stage8_minotaur_gameplay_freeze_active": is_gameplay_freeze_active(),
		"stage8_minotaur_gameplay_freeze_reason": _gameplay_freeze_reason,
		"stage8_minotaur_boss_ai_frozen": is_gameplay_freeze_active(),
		"stage8_minotaur_scripted_motion_active": false,
		"stage8_minotaur_scripted_boss_pos": _scripted_boss_pos,
		"stage8_minotaur_superspeed_active": false,
		"stage8_minotaur_state_owner": self,
	}


func get_actor_draw_context() -> Dictionary:
	# Minimal placeholder payload. The code-native renderer reads boss geometry
	# from the shared context and only needs these scalars for tint / status.
	return {
		"stage8_minotaur_boss_gauge": boss_special_gauge,
		"stage8_minotaur_awakened": awakened,
		"stage8_minotaur_status": status,
		"stage8_minotaur_gameplay_freeze_active": is_gameplay_freeze_active(),
		"stage8_minotaur_awakening_intro_done": _awakening_intro_done,
		"stage8_minotaur_boss_ball_intangible": _boss_ball_intangible,
		"stage8_minotaur_scripted_motion_active": false,
	}


func get_hud_context(_stage_background: Object = null, _context: Dictionary = {}) -> Dictionary:
	return {
		"stage8_boss_skill_hud_active": true,
		"stage8_boss_skill_hud_boss_name": BOSS_NAME,
		"stage8_boss_skill_hud_status": status,
		"stage8_boss_skill_hud_gauge": boss_special_gauge,
		"stage8_boss_skill_hud_gauge_max": GAUGE_MAX,
		"stage8_boss_skill_hud_awakened": awakened,
		"stage8_boss_skill_hud_skills": _build_hud_skills(),
	}


func should_skip_ball_motion_step() -> bool:
	return false


func get_status() -> String:
	return status


func notify_superspeed_dash_started(_boss_pos: Vector2, _boss_size: Vector2, _direction: int, _target_center_x: float, _duration_frames: float) -> void:
	# Slice 1: Superspeed is a Slice-5 mechanic; no dash bookkeeping yet.
	pass


func notify_superspeed_dash_finished(_boss_pos: Vector2) -> void:
	pass


# --- internals ---------------------------------------------------------------


func _try_start_earthquake(_context: Dictionary, _deps: Dictionary = {}) -> bool:
	# SLICE-5 SEED — 대지강타 지진. No active skill logic in the placeholder shell.
	# Future body: gate on boss_special_gauge >= EARTHQUAKE_GAUGE_COST + cooldown,
	# spend the gauge, freeze the ball, and emit the shockwave CC.
	return false


func _build_hud_skills() -> Array:
	return [
		_placeholder_hud_skill("stage8_earthquake", "대지강타", Color(0.72, 0.52, 0.30), EARTHQUAKE_GAUGE_COST),
	]


func _placeholder_hud_skill(skill_id: String, skill_name: String, color: Color, cost: float) -> Dictionary:
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
		"status": "paused",
	}


func _build_result() -> Dictionary:
	# Slice 1 never scripts the boss position (no clone / cloud / escape /
	# superspeed), so the shell always yields ownership to the shared boss AI and
	# never emits a false skip_ball_motion_step ownership flag.
	return {}


func _sync_awakening_trigger(context: Dictionary) -> void:
	if awakened or _awakening_intro_done or _awakening_trigger_armed:
		return
	if int(context.get("player_score", 0)) < AWAKEN_SCORE_THRESHOLD:
		return
	if bool(context.get("waiting_for_serve", false)) or not bool(context.get("ball_active", true)):
		return
	_awakening_trigger_armed = true


func _complete_awakening(context: Dictionary = {}, _deps: Dictionary = {}) -> void:
	if not _awakening_intro_pending:
		return
	_cache_boss_geometry(context)
	_awakening_intro_pending = false
	_awakening_trigger_armed = false
	_awakening_intro_done = true
	awakened = true
	status = "awakened"


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
		or _boss_ball_intangible


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


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
