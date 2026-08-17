extends RefCounted

# 2026-07-31 7점제 재보정: 4/5(80%) -> 6/7(86%).
const ILLUSION_UNLOCK_PLAYER_SCORE := 6
const ILLUSION_DURATION_FRAMES := 360.0
const ILLUSION_COOLDOWN_SEC := 70.0
const ILLUSION_FIRST_CAST_DELAY_FRAMES := 180.0
const ILLUSION_AWAKEN_BURST_FRAMES := 90.0
const ILLUSION_AWAKEN_STAGE_LOCKED := 0
const ILLUSION_AWAKEN_STAGE_WAIT_SERVE := 1
const ILLUSION_AWAKEN_STAGE_SERVE_WAIT := 2
const ILLUSION_AWAKEN_STAGE_COUNTDOWN := 3
const ILLUSION_AWAKEN_STAGE_LOOP := 4

# Mutable owner for Ponk's illusion-ripple unlock, first-cast ceremony,
# cooldown loop, active duration, and awaken-aura projection. The runtime
# coordinator keeps frame/reset ordering; FX hosts remain externally owned.

var illusion_unlocked := false
var illusion_awaken_stage := ILLUSION_AWAKEN_STAGE_LOCKED
var illusion_first_cast_delay_frames := 0.0
var illusion_awaken_burst_frames := 0.0
var illusion_awaken_burst_played := false
var illusion_active := false
var illusion_timer_frames := 0.0
var illusion_cooldown_seconds := 0.0
var illusion_aura_enraged := false


func reset() -> void:
	illusion_unlocked = false
	illusion_awaken_stage = ILLUSION_AWAKEN_STAGE_LOCKED
	illusion_first_cast_delay_frames = 0.0
	illusion_awaken_burst_frames = 0.0
	illusion_awaken_burst_played = false
	illusion_active = false
	illusion_timer_frames = 0.0
	illusion_cooldown_seconds = 0.0
	illusion_aura_enraged = false


func reset_round() -> void:
	illusion_active = false
	illusion_timer_frames = 0.0
	illusion_awaken_burst_frames = 0.0


func clear_stage_transients() -> void:
	illusion_active = false
	illusion_timer_frames = 0.0
	illusion_awaken_burst_frames = 0.0
	illusion_aura_enraged = false


func handle_score_event(scoring_side: String, player_score: int) -> void:
	if scoring_side != "player" or illusion_unlocked:
		return
	if player_score < ILLUSION_UNLOCK_PLAYER_SCORE:
		return
	illusion_unlocked = true
	illusion_awaken_stage = ILLUSION_AWAKEN_STAGE_WAIT_SERVE
	illusion_first_cast_delay_frames = 0.0


func set_aura_enraged(value: bool) -> void:
	illusion_aura_enraged = value


func update_cooldown(delta: float) -> void:
	if not illusion_unlocked:
		return
	illusion_cooldown_seconds = maxf(0.0, illusion_cooldown_seconds - maxf(0.0, delta))


func update_awaken_burst(fps_scale: float) -> void:
	if illusion_awaken_burst_frames <= 0.0:
		return
	illusion_awaken_burst_frames = maxf(
		0.0,
		illusion_awaken_burst_frames - maxf(0.0, fps_scale)
	)


func update_awaken_state(fps_scale: float, serve_waiting: bool, cooldown_paused: bool) -> bool:
	if not illusion_unlocked:
		return false
	if illusion_awaken_stage <= ILLUSION_AWAKEN_STAGE_LOCKED or illusion_awaken_stage >= ILLUSION_AWAKEN_STAGE_LOOP:
		return false
	if illusion_awaken_stage == ILLUSION_AWAKEN_STAGE_WAIT_SERVE:
		if serve_waiting:
			illusion_awaken_stage = ILLUSION_AWAKEN_STAGE_SERVE_WAIT
			illusion_first_cast_delay_frames = ILLUSION_FIRST_CAST_DELAY_FRAMES
		return false
	if illusion_awaken_stage == ILLUSION_AWAKEN_STAGE_SERVE_WAIT:
		if serve_waiting or cooldown_paused:
			return false
		illusion_awaken_stage = ILLUSION_AWAKEN_STAGE_COUNTDOWN
		illusion_first_cast_delay_frames = ILLUSION_FIRST_CAST_DELAY_FRAMES
		_arm_awaken_burst()
		return false
	if illusion_awaken_stage != ILLUSION_AWAKEN_STAGE_COUNTDOWN:
		return false
	if serve_waiting:
		illusion_awaken_stage = ILLUSION_AWAKEN_STAGE_SERVE_WAIT
		illusion_first_cast_delay_frames = ILLUSION_FIRST_CAST_DELAY_FRAMES
		return false
	if cooldown_paused or not can_activate(serve_waiting):
		return false
	illusion_first_cast_delay_frames = maxf(
		0.0,
		illusion_first_cast_delay_frames - maxf(0.0, fps_scale)
	)
	if illusion_first_cast_delay_frames > 0.0:
		return false
	activate()
	return true


func can_activate(serve_waiting: bool) -> bool:
	return illusion_unlocked and not illusion_active and not serve_waiting


func can_auto_activate(serve_waiting: bool) -> bool:
	return (
		illusion_unlocked
		and illusion_awaken_stage >= ILLUSION_AWAKEN_STAGE_LOOP
		and illusion_cooldown_seconds <= 0.0
		and can_activate(serve_waiting)
	)


func force_activate() -> bool:
	activate()
	return illusion_active


func activate() -> void:
	illusion_unlocked = true
	illusion_awaken_stage = ILLUSION_AWAKEN_STAGE_LOOP
	illusion_first_cast_delay_frames = 0.0
	illusion_active = true
	illusion_timer_frames = ILLUSION_DURATION_FRAMES
	illusion_cooldown_seconds = ILLUSION_COOLDOWN_SEC


func consume_parried() -> void:
	illusion_unlocked = true
	illusion_awaken_stage = ILLUSION_AWAKEN_STAGE_LOOP
	illusion_first_cast_delay_frames = 0.0
	illusion_active = false
	illusion_timer_frames = 0.0
	illusion_cooldown_seconds = ILLUSION_COOLDOWN_SEC


func update_active(fps_scale: float) -> void:
	if not illusion_active:
		return
	illusion_timer_frames = maxf(0.0, illusion_timer_frames - maxf(0.0, fps_scale))
	if illusion_timer_frames <= 0.0:
		illusion_active = false


func get_awaken_aura_intensity(context: Dictionary = {}) -> float:
	if bool(context.get("stage4_illusion_active", illusion_active)):
		return 1.0
	if not bool(context.get("stage4_illusion_unlocked", illusion_unlocked)):
		return 0.0
	var awaken_stage := int(context.get("stage4_illusion_awaken_stage", illusion_awaken_stage))
	if awaken_stage < ILLUSION_AWAKEN_STAGE_SERVE_WAIT:
		return 0.0
	if awaken_stage == ILLUSION_AWAKEN_STAGE_SERVE_WAIT:
		return 0.42
	if awaken_stage == ILLUSION_AWAKEN_STAGE_COUNTDOWN:
		var total: float = maxf(1.0, float(context.get(
			"stage4_illusion_first_cast_delay_total",
			ILLUSION_FIRST_CAST_DELAY_FRAMES
		)))
		var remaining: float = clampf(float(context.get(
			"stage4_illusion_first_cast_delay",
			illusion_first_cast_delay_frames
		)), 0.0, total)
		return clampf(0.34 + (1.0 - remaining / total) * 0.66, 0.0, 1.0)
	return 0.55


func get_snapshot() -> Dictionary:
	return {
		"illusion_unlocked": illusion_unlocked,
		"illusion_awaken_stage": illusion_awaken_stage,
		"illusion_first_cast_delay_frames": illusion_first_cast_delay_frames,
		"illusion_awaken_burst_frames": illusion_awaken_burst_frames,
		"illusion_awaken_burst_played": illusion_awaken_burst_played,
		"illusion_active": illusion_active,
		"illusion_timer_frames": illusion_timer_frames,
		"illusion_cooldown_seconds": illusion_cooldown_seconds,
		"illusion_aura_enraged": illusion_aura_enraged,
	}


func get_actor_draw_context(modular_ready: bool) -> Dictionary:
	return {
		"stage4_illusion_unlocked": illusion_unlocked,
		"stage4_illusion_awaken_stage": illusion_awaken_stage,
		"stage4_illusion_first_cast_delay": illusion_first_cast_delay_frames,
		"stage4_illusion_first_cast_delay_total": ILLUSION_FIRST_CAST_DELAY_FRAMES,
		"stage4_illusion_awaken_burst": illusion_awaken_burst_frames,
		"stage4_illusion_awaken_burst_total": ILLUSION_AWAKEN_BURST_FRAMES,
		"stage4_illusion_active": illusion_active,
		"stage4_illusion_timer": illusion_timer_frames,
		"stage4_illusion_duration_total": ILLUSION_DURATION_FRAMES,
		"stage4_illusion_cooldown_remaining": illusion_cooldown_seconds,
		"stage4_illusion_cooldown_total": ILLUSION_COOLDOWN_SEC,
		"stage4_illusion_awaken_aura_intensity": get_awaken_aura_intensity(),
		"stage4_illusion_awaken_aura_enraged": illusion_aura_enraged,
		"stage4_illusion_awaken_aura_modular_ready": modular_ready,
	}


func _arm_awaken_burst() -> void:
	if illusion_awaken_burst_played:
		return
	illusion_awaken_burst_frames = ILLUSION_AWAKEN_BURST_FRAMES
	illusion_awaken_burst_played = true
