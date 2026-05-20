extends RefCounted

const SERVE_DELAY := 1.0
const SERVE_BANNER_DURATION := 0.85
const ROUND_RESTART_NOTICE_DURATION := 1.0

var round_start_time_msec := 0
var serve_timer := 0.0
var serve_target_delay := SERVE_DELAY
var waiting_for_serve := true
var player_serves := true
var serve_banner_timer := 0.0
var round_restart_notice_timer := 0.0


func reset_game() -> void:
	player_serves = true
	round_start_time_msec = 0
	reset_round_wait()


func reset_round_wait() -> void:
	waiting_for_serve = true
	serve_timer = 0.0
	serve_target_delay = SERVE_DELAY
	serve_banner_timer = 0.0
	round_restart_notice_timer = 0.0


func start_scoreboard_wait() -> void:
	serve_timer = 0.0
	serve_target_delay = SERVE_DELAY


func prepare_serve_after_scoreboard() -> void:
	waiting_for_serve = true
	serve_timer = 0.0
	serve_target_delay = SERVE_DELAY
	serve_banner_timer = SERVE_BANNER_DURATION


func pause_serve_for_intro() -> void:
	waiting_for_serve = false
	serve_timer = 0.0
	serve_target_delay = SERVE_DELAY
	serve_banner_timer = 0.0
	round_restart_notice_timer = 0.0


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
	round_start_time_msec = start_time_msec


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
	}
