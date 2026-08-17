extends RefCounted

const STATE_IDLE := "idle"
const STATE_REVIVAL_EVENT := "revival_event"
const STATE_PENALTY := "penalty"
const STATE_DEATH_EVENT := "death_event"

const DEATH_PHASE_PRE_EXPLOSION := "pre_explosion"
const DEATH_PHASE_EXPLOSION := "explosion"
const DEATH_PHASE_DISINTEGRATE := "disintegrate"

# 변신 3.75s = odinchange.wav 타임라인(빌드업 3.0s + dark-burst 45f) 정렬.
# 렌더러 REVIVAL_DURATION_SEC와 반드시 동일해야 한다(불일치 시 safe_progress
# 클램프로 버스트가 동결된다).
const REVIVAL_EVENT_SEC := 3.75
# 사망 4.5s = odindeath.wav(5.07s) 타임라인 정렬: 폭발직전 2.0s(4/9) +
# 폭발 1.0s(→2/3) + 분해 1.5s — 폭발 발화 2.0s가 오디오 BANG(1.92s)과
# 사실상 동시가 되는 원본 배치.
const DEATH_EVENT_SEC := 4.5
const DEATH_PRE_FRAC := 4.0 / 9.0
const DEATH_EXPLODE_FRAC := 2.0 / 3.0
const DEATH_SHAKE_PRE_MAX := 8.0

# 오디오 출력지연 보정 단일 튜너블: 시각 '팡'(플래시·몸 스냅·흔들림 스파이크)
# 을 실제 들리는 소리에 맞춘다. 라이브에서 시각이 여전히 소리보다 앞서면
# 이 값을 올리고, 뒤처지면 내린다 — 파생 상수 2종이 함께 밀린다.
const BANG_LATENCY_SEC := 0.15
# 변신: odinchange.wav BANG=3.20s, dark-burst 창(3.0~3.75s=0.75s) 내 위치.
# 앵커: 3.0 + REVIVAL_BANG_T * 0.75 == 3.20 + BANG_LATENCY_SEC.
const REVIVAL_BANG_T := (0.20 + BANG_LATENCY_SEC) / 0.75
# 사망: odindeath.wav BANG=1.92s가 폭발 발화(2.0s)보다 0.08s 이르므로 차감,
# 폭발 페이즈(1.0s) 내 위치. 앵커: 2.0 + DEATH_BANG_FRAC == 1.92 + 지연.
const DEATH_BANG_FRAC := (BANG_LATENCY_SEC - 0.08) / 1.0
# 변신 화면흔들림(원본 dark_burst screen_shake 계열): 빌드 최대 3 →
# BANG 스파이크 12 → 감쇠. 렌더러의 burst-prep 경계(0.80)와 단일 소스.
const REVIVAL_BURST_PREP_FRAC := 0.80
const REVIVAL_SHAKE_BUILD_MAX := 3.0
const REVIVAL_SHAKE_BANG_SPIKE := 12.0
const DEATH_SHAKE_EXPLOSION_PEAK := 10.0
const DEATH_SHAKE_DISINTEGRATE_START := 5.0
const PENALTY_MOVE_SPEED_MULTIPLIER := 0.5
const PENALTY_DASH_TOKEN_LIMIT := 1
const PENALTY_DASH_DISTANCE_MULTIPLIER := 1.5
const PENALTY_DASH_COOLDOWN_MULTIPLIER := 2.0

var active := false
var state := STATE_IDLE
var revival_used := false
var penalty_active := false
var revival_timer_sec := 0.0
var death_timer_sec := 0.0
var last_loss_type := ""
var last_trigger_roll_pct := -1.0
var last_triggered := false
var revival_finalize_ready := false
var death_finalize_ready := false
var death_explosion_edge_ready := false
var death_disintegration_edge_ready := false
var death_explosion_edge_triggered := false
var death_disintegration_edge_triggered := false
var death_hide_player_paddle := false


func set_equipped(is_equipped: bool) -> void:
	if is_equipped:
		active = true
	else:
		active = false
		_clear_runtime(false, true)


func reset_all() -> void:
	active = false
	_clear_runtime(false, true)


func reset_round() -> void:
	revival_finalize_ready = false
	death_finalize_ready = false
	death_explosion_edge_ready = false
	death_disintegration_edge_ready = false


func on_stage_advance() -> void:
	_clear_runtime(false, true)


func can_revive(equipped: bool) -> bool:
	return (
		equipped
		and active
		and not revival_used
		and not penalty_active
		and not is_revival_animation_active()
		and not is_death_animation_active()
	)


func record_roll(roll_pct: float, triggered: bool) -> void:
	last_trigger_roll_pct = roll_pct
	last_triggered = triggered


func begin_revival(
	loss_type: String = "round",
	event_sec: float = REVIVAL_EVENT_SEC,
	roll_pct: float = -1.0
) -> void:
	revival_used = true
	penalty_active = true
	state = STATE_REVIVAL_EVENT
	revival_timer_sec = max(0.0, event_sec)
	death_timer_sec = 0.0
	last_loss_type = loss_type
	last_trigger_roll_pct = roll_pct
	last_triggered = true
	revival_finalize_ready = false
	death_finalize_ready = false


func begin_death_sequence(loss_type: String = "round", event_sec: float = DEATH_EVENT_SEC) -> void:
	state = STATE_DEATH_EVENT
	death_timer_sec = max(0.0, event_sec)
	revival_timer_sec = 0.0
	last_loss_type = loss_type
	death_finalize_ready = false
	death_explosion_edge_ready = false
	death_disintegration_edge_ready = false
	death_explosion_edge_triggered = false
	death_disintegration_edge_triggered = false
	death_hide_player_paddle = false


func update(delta_sec: float) -> bool:
	var changed := false
	var safe_delta: float = max(0.0, delta_sec)
	if state == STATE_REVIVAL_EVENT:
		revival_timer_sec = max(0.0, revival_timer_sec - safe_delta)
		if revival_timer_sec <= 0.0:
			state = STATE_PENALTY if penalty_active else STATE_IDLE
			revival_finalize_ready = true
			changed = true
	elif state == STATE_DEATH_EVENT:
		var previous_progress: float = get_death_overall_progress()
		death_timer_sec = max(0.0, death_timer_sec - safe_delta)
		var next_progress: float = get_death_overall_progress()
		if not death_explosion_edge_triggered and previous_progress < DEATH_PRE_FRAC and next_progress >= DEATH_PRE_FRAC:
			death_explosion_edge_ready = true
			death_explosion_edge_triggered = true
			changed = true
		if not death_disintegration_edge_triggered and previous_progress < DEATH_EXPLODE_FRAC and next_progress >= DEATH_EXPLODE_FRAC:
			death_disintegration_edge_ready = true
			death_disintegration_edge_triggered = true
			changed = true
		if get_death_phase() == DEATH_PHASE_DISINTEGRATE and get_death_phase_progress() > 0.6:
			death_hide_player_paddle = true
		if death_timer_sec <= 0.0:
			state = STATE_IDLE
			penalty_active = false
			death_finalize_ready = true
			changed = true
	return changed


func consume_revival_finalize_ready() -> bool:
	if not revival_finalize_ready:
		return false
	revival_finalize_ready = false
	return true


func consume_death_finalize_ready() -> bool:
	if not death_finalize_ready:
		return false
	death_finalize_ready = false
	return true


func consume_death_explosion_edge() -> bool:
	if not death_explosion_edge_ready:
		return false
	death_explosion_edge_ready = false
	return true


func consume_disintegration_edge() -> bool:
	if not death_disintegration_edge_ready:
		return false
	death_disintegration_edge_ready = false
	return true


func clear_after_victory() -> void:
	_clear_runtime(false, true)


func clear_after_death() -> void:
	_clear_runtime(false, true)


func is_revival_animation_active() -> bool:
	return active and state == STATE_REVIVAL_EVENT


# 변신 화면흔들림 강도: 빌드(0→3) → BANG 스파이크(12) → 감쇠(→0).
# BANG 위치는 REVIVAL_BURST_PREP_FRAC + REVIVAL_BANG_T 파생 — BANG_LATENCY_SEC
# 하나로 플래시·몸 스냅·흔들림이 함께 밀린다.
func get_revival_shake_intensity() -> float:
	if not is_revival_animation_active():
		return 0.0
	var progress: float = clampf(1.0 - revival_timer_sec / REVIVAL_EVENT_SEC, 0.0, 1.0)
	var bang_progress: float = REVIVAL_BURST_PREP_FRAC + REVIVAL_BANG_T * (1.0 - REVIVAL_BURST_PREP_FRAC)
	if progress < REVIVAL_BURST_PREP_FRAC:
		return REVIVAL_SHAKE_BUILD_MAX * (progress / REVIVAL_BURST_PREP_FRAC)
	if progress <= bang_progress:
		var ramp: float = (progress - REVIVAL_BURST_PREP_FRAC) / maxf(0.0001, bang_progress - REVIVAL_BURST_PREP_FRAC)
		return lerpf(REVIVAL_SHAKE_BUILD_MAX, REVIVAL_SHAKE_BANG_SPIKE, ramp)
	var decay: float = (progress - bang_progress) / maxf(0.0001, 1.0 - bang_progress)
	return lerpf(REVIVAL_SHAKE_BANG_SPIKE, 0.0, decay)


func is_death_animation_active() -> bool:
	return active and state == STATE_DEATH_EVENT


func is_effect_active() -> bool:
	return is_revival_animation_active() or is_death_animation_active()


func is_transformed() -> bool:
	return active and penalty_active


func is_skills_locked() -> bool:
	return active and (penalty_active or is_revival_animation_active() or is_death_animation_active())


func is_control_locked() -> bool:
	return is_revival_animation_active() or is_death_animation_active()


func get_move_speed_multiplier() -> float:
	return PENALTY_MOVE_SPEED_MULTIPLIER if is_transformed() else 1.0


func get_dash_token_limit_override() -> Variant:
	if not is_transformed():
		return null
	return PENALTY_DASH_TOKEN_LIMIT


func get_dash_distance_multiplier() -> float:
	return PENALTY_DASH_DISTANCE_MULTIPLIER if is_transformed() else 1.0


func get_dash_cooldown_multiplier() -> float:
	return PENALTY_DASH_COOLDOWN_MULTIPLIER if is_transformed() else 1.0


func get_death_phase() -> String:
	if not is_death_animation_active():
		return ""
	var progress: float = get_death_overall_progress()
	if progress < DEATH_PRE_FRAC:
		return DEATH_PHASE_PRE_EXPLOSION
	if progress < DEATH_EXPLODE_FRAC:
		return DEATH_PHASE_EXPLOSION
	return DEATH_PHASE_DISINTEGRATE


func get_death_overall_progress() -> float:
	if death_finalize_ready:
		return 1.0
	if death_timer_sec <= 0.0:
		return 0.0
	return clamp(1.0 - death_timer_sec / max(0.001, DEATH_EVENT_SEC), 0.0, 1.0)


func get_death_phase_progress() -> float:
	var progress: float = get_death_overall_progress()
	var phase: String = get_death_phase()
	if phase == DEATH_PHASE_PRE_EXPLOSION:
		return clamp(progress / DEATH_PRE_FRAC, 0.0, 1.0)
	if phase == DEATH_PHASE_EXPLOSION:
		return _normalize_range(progress, DEATH_PRE_FRAC, DEATH_EXPLODE_FRAC)
	if phase == DEATH_PHASE_DISINTEGRATE:
		return _normalize_range(progress, DEATH_EXPLODE_FRAC, 1.0)
	return 0.0


func get_death_energy_buildup() -> float:
	if is_death_animation_active():
		if get_death_phase() == DEATH_PHASE_PRE_EXPLOSION:
			return pow(get_death_phase_progress(), 1.5)
		return 1.0
	return 1.0 if death_finalize_ready else 0.0


func get_death_disintegrate_progress() -> float:
	if death_finalize_ready:
		return 1.0
	if get_death_phase() != DEATH_PHASE_DISINTEGRATE:
		return 0.0
	return get_death_phase_progress()


func get_death_shake_intensity() -> float:
	var phase: String = get_death_phase()
	if phase == DEATH_PHASE_PRE_EXPLOSION:
		return DEATH_SHAKE_PRE_MAX * get_death_energy_buildup()
	if phase == DEATH_PHASE_EXPLOSION:
		return lerp(DEATH_SHAKE_EXPLOSION_PEAK, DEATH_SHAKE_DISINTEGRATE_START, get_death_phase_progress())
	if phase == DEATH_PHASE_DISINTEGRATE:
		return lerp(DEATH_SHAKE_DISINTEGRATE_START, 0.0, get_death_phase_progress())
	return 0.0


func should_hide_player_paddle() -> bool:
	return death_hide_player_paddle and (is_death_animation_active() or death_finalize_ready)


func get_context() -> Dictionary:
	return {
		"equipped": active,
		"active": active,
		"state": state,
		"revival_used": revival_used,
		"available": can_revive(active),
		"penalty_active": penalty_active,
		"transformed": is_transformed(),
		"skills_locked": is_skills_locked(),
		"control_locked": is_control_locked(),
		"revival_animation_active": is_revival_animation_active(),
		"death_animation_active": is_death_animation_active(),
		"revival_timer_sec": revival_timer_sec,
		"death_timer_sec": death_timer_sec,
		"death_phase": get_death_phase(),
		"death_overall_progress": get_death_overall_progress(),
		"death_phase_progress": get_death_phase_progress(),
		"death_energy_buildup": get_death_energy_buildup(),
		"death_disintegrate_progress": get_death_disintegrate_progress(),
		"death_shake_intensity": get_death_shake_intensity(),
		"death_explosion_edge_ready": death_explosion_edge_ready,
		"death_disintegration_edge_ready": death_disintegration_edge_ready,
		"hide_player_paddle": should_hide_player_paddle(),
		"last_loss_type": last_loss_type,
		"last_trigger_roll_pct": last_trigger_roll_pct,
		"last_triggered": last_triggered,
		"move_speed_multiplier": get_move_speed_multiplier(),
		"dash_token_limit": get_dash_token_limit_override(),
		"dash_distance_multiplier": get_dash_distance_multiplier(),
		"dash_cooldown_multiplier": get_dash_cooldown_multiplier(),
	}


func _clear_runtime(preserve_used: bool, clear_penalty: bool) -> void:
	var previous_used := revival_used
	state = STATE_IDLE
	revival_timer_sec = 0.0
	death_timer_sec = 0.0
	last_loss_type = ""
	last_trigger_roll_pct = -1.0
	last_triggered = false
	revival_finalize_ready = false
	death_finalize_ready = false
	death_explosion_edge_ready = false
	death_disintegration_edge_ready = false
	death_explosion_edge_triggered = false
	death_disintegration_edge_triggered = false
	death_hide_player_paddle = false
	revival_used = previous_used if preserve_used else false
	if clear_penalty:
		penalty_active = false


func _normalize_range(value: float, start: float, end: float) -> float:
	return clamp((value - start) / max(0.001, end - start), 0.0, 1.0)
