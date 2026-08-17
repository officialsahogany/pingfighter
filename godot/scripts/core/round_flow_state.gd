extends RefCounted

const RuntimePerkModalTimeShift := preload("res://scripts/core/runtime_perk_modal_time_shift.gd")
const MatchScoreState := preload("res://scripts/core/match_score_state.gd")

const SERVE_DELAY := 1.0
const SERVE_BANNER_DURATION := 0.85
const ROUND_RESTART_NOTICE_DURATION := 1.0
const DEUCE_ENTRY_ANNOUNCEMENT_DURATION := 1.55
const DEUCE_ENTRY_DISMISS_LOCK_DURATION := 1.0

var round_start_time_msec := 0
var serve_timer := 0.0
var serve_target_delay := SERVE_DELAY
var waiting_for_serve := true
var player_serves := true
var serve_banner_timer := 0.0
var round_restart_notice_timer := 0.0
var deuce_entry_announcement_timer := 0.0
var deuce_entry_announcement_elapsed := 0.0
var deuce_entry_goal := MatchScoreState.DEUCE_GOAL_BASE
var _deuce_entry_announcement_active := false
var _deuce_entry_announcement_pending := false
var _runtime_perk_modal_pause_started_msec := -1


func reset_game() -> void:
	player_serves = true
	round_start_time_msec = 0
	_runtime_perk_modal_pause_started_msec = -1
	reset_round_wait()


# 퍽 모달 동안 벽시계 앵커 동결. 라운드 시작 시각은 초반 잠금 / 경과 판정의
# 공용 기준점이라, 밀지 않으면 모달을 연 만큼 라운드가 늙어 보인다.
# 규칙은 runtime_perk_modal_time_shift.gd 참조.
func pause_runtime_perk_modal_time(current_msec: int) -> void:
	_runtime_perk_modal_pause_started_msec = RuntimePerkModalTimeShift.begin_pause(
		_runtime_perk_modal_pause_started_msec, current_msec
	)


func resume_runtime_perk_modal_time(current_msec: int) -> void:
	if _runtime_perk_modal_pause_started_msec < 0:
		return
	var pause_started_msec: int = _runtime_perk_modal_pause_started_msec
	_runtime_perk_modal_pause_started_msec = -1
	shift_runtime_perk_modal_time(pause_started_msec, current_msec)


func shift_runtime_perk_modal_time(pause_started_msec: int, resumed_msec: int) -> void:
	var delta_msec: int = RuntimePerkModalTimeShift.resolve_paused_duration(pause_started_msec, resumed_msec)
	if delta_msec <= 0:
		return
	round_start_time_msec = RuntimePerkModalTimeShift.shift_anchor(round_start_time_msec, delta_msec)


func reset_round_wait() -> void:
	waiting_for_serve = true
	serve_timer = 0.0
	serve_target_delay = SERVE_DELAY
	serve_banner_timer = 0.0
	round_restart_notice_timer = 0.0
	deuce_entry_announcement_timer = 0.0
	deuce_entry_announcement_elapsed = 0.0
	deuce_entry_goal = MatchScoreState.DEUCE_GOAL_BASE
	_deuce_entry_announcement_active = false
	_deuce_entry_announcement_pending = false


func start_scoreboard_wait() -> void:
	serve_timer = 0.0
	serve_target_delay = SERVE_DELAY


func prepare_serve_after_scoreboard() -> void:
	waiting_for_serve = true
	serve_timer = 0.0
	serve_target_delay = SERVE_DELAY
	if _deuce_entry_announcement_pending:
		_deuce_entry_announcement_pending = false
		_deuce_entry_announcement_active = true
		deuce_entry_announcement_timer = DEUCE_ENTRY_ANNOUNCEMENT_DURATION
		deuce_entry_announcement_elapsed = 0.0
		serve_banner_timer = 0.0
	else:
		_deuce_entry_announcement_active = false
		deuce_entry_announcement_timer = 0.0
		deuce_entry_announcement_elapsed = 0.0
		serve_banner_timer = SERVE_BANNER_DURATION


func queue_deuce_entry_announcement(current_goal: int = MatchScoreState.DEUCE_GOAL_BASE) -> void:
	_deuce_entry_announcement_pending = true
	deuce_entry_goal = clampi(
		current_goal,
		MatchScoreState.DEUCE_GOAL_BASE,
		MatchScoreState.DEUCE_GOAL_MAX
	)


func pause_serve_for_intro() -> void:
	waiting_for_serve = false
	serve_timer = 0.0
	serve_target_delay = SERVE_DELAY
	serve_banner_timer = 0.0
	round_restart_notice_timer = 0.0
	deuce_entry_announcement_timer = 0.0
	deuce_entry_announcement_elapsed = 0.0
	_deuce_entry_announcement_active = false
	_deuce_entry_announcement_pending = false


func prepare_serve_after_intro() -> void:
	waiting_for_serve = true
	serve_timer = 0.0
	serve_target_delay = SERVE_DELAY


func update_waiting(delta: float, target_delay: float = SERVE_DELAY) -> bool:
	if not waiting_for_serve:
		return false
	serve_target_delay = max(0.0, target_delay)
	serve_timer += delta
	return serve_timer >= serve_target_delay


func begin_serve(start_time_msec: int) -> void:
	waiting_for_serve = false
	serve_timer = 0.0
	serve_target_delay = SERVE_DELAY
	serve_banner_timer = 0.0
	round_restart_notice_timer = 0.0
	deuce_entry_announcement_timer = 0.0
	deuce_entry_announcement_elapsed = 0.0
	_deuce_entry_announcement_active = false
	_deuce_entry_announcement_pending = false
	round_start_time_msec = start_time_msec


func update_deuce_entry_announcement(delta: float) -> bool:
	if not _deuce_entry_announcement_active:
		return false
	deuce_entry_announcement_elapsed += max(0.0, delta)
	# The timer remains positive as a compatibility-active marker. Unlike the
	# ordinary banners, this presentation has no automatic expiry: only a new
	# dismissal click may hand control to the serve banner.
	deuce_entry_announcement_timer = DEUCE_ENTRY_ANNOUNCEMENT_DURATION
	return true


func dismiss_deuce_entry_announcement() -> bool:
	if not can_dismiss_deuce_entry_announcement():
		return false
	_deuce_entry_announcement_active = false
	deuce_entry_announcement_timer = 0.0
	deuce_entry_announcement_elapsed = 0.0
	serve_banner_timer = SERVE_BANNER_DURATION
	return true


func is_deuce_entry_announcement_active() -> bool:
	return _deuce_entry_announcement_active


func can_dismiss_deuce_entry_announcement() -> bool:
	return (
		_deuce_entry_announcement_active
		and deuce_entry_announcement_elapsed >= DEUCE_ENTRY_DISMISS_LOCK_DURATION
	)


func get_deuce_entry_announcement_timer() -> float:
	return deuce_entry_announcement_timer


func get_deuce_entry_announcement_elapsed() -> float:
	return deuce_entry_announcement_elapsed


func get_deuce_entry_announcement_duration() -> float:
	return DEUCE_ENTRY_ANNOUNCEMENT_DURATION


func get_deuce_entry_dismiss_lock_duration() -> float:
	return DEUCE_ENTRY_DISMISS_LOCK_DURATION


func has_pending_deuce_entry_announcement() -> bool:
	return _deuce_entry_announcement_pending


func update_serve_banner(delta: float) -> bool:
	if serve_banner_timer <= 0.0:
		return false
	serve_banner_timer = max(0.0, serve_banner_timer - max(0.0, delta))
	return serve_banner_timer > 0.0


func start_round_restart_notice() -> void:
	round_restart_notice_timer = ROUND_RESTART_NOTICE_DURATION
	serve_timer = 0.0


func update_round_restart_notice(delta: float) -> bool:
	if round_restart_notice_timer <= 0.0:
		return false
	round_restart_notice_timer = max(0.0, round_restart_notice_timer - max(0.0, delta))
	return round_restart_notice_timer > 0.0


func is_round_restart_notice_active() -> bool:
	return round_restart_notice_timer > 0.0


func get_round_restart_notice_timer() -> float:
	return round_restart_notice_timer


func get_round_restart_notice_duration() -> float:
	return ROUND_RESTART_NOTICE_DURATION


func is_serve_banner_active() -> bool:
	return serve_banner_timer > 0.0


func get_serve_banner_timer() -> float:
	return serve_banner_timer


func get_serve_banner_duration() -> float:
	return SERVE_BANNER_DURATION


func set_player_serves(value: bool) -> void:
	player_serves = value


func is_waiting_for_serve() -> bool:
	return waiting_for_serve


func does_player_serve() -> bool:
	return player_serves


func get_round_start_time_msec() -> int:
	return round_start_time_msec


func get_snapshot() -> Dictionary:
	return {
		"round_start_time_msec": round_start_time_msec,
		"serve_timer": serve_timer,
		"waiting_for_serve": waiting_for_serve,
		"player_serves": player_serves,
		"serve_delay": serve_target_delay,
		"serve_banner_timer": serve_banner_timer,
		"serve_banner_duration": SERVE_BANNER_DURATION,
		"round_restart_notice_timer": round_restart_notice_timer,
		"round_restart_notice_duration": ROUND_RESTART_NOTICE_DURATION,
		"deuce_entry_announcement_timer": deuce_entry_announcement_timer,
		"deuce_entry_announcement_elapsed": deuce_entry_announcement_elapsed,
		"deuce_entry_announcement_duration": DEUCE_ENTRY_ANNOUNCEMENT_DURATION,
		"deuce_entry_dismiss_lock_duration": DEUCE_ENTRY_DISMISS_LOCK_DURATION,
		"deuce_entry_can_dismiss": can_dismiss_deuce_entry_announcement(),
		"deuce_entry_announcement_active": _deuce_entry_announcement_active,
		"deuce_entry_announcement_pending": _deuce_entry_announcement_pending,
		"deuce_entry_goal": deuce_entry_goal,
	}
