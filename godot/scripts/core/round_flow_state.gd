extends RefCounted

const SERVE_DELAY := 1.0

var round_start_time_msec := 0
var serve_timer := 0.0
var waiting_for_serve := true
var player_serves := true


func reset_game() -> void:
	player_serves = true
	round_start_time_msec = 0
	reset_round_wait()


func reset_round_wait() -> void:
	waiting_for_serve = true
	serve_timer = 0.0


func start_scoreboard_wait() -> void:
	serve_timer = 0.0


func prepare_serve_after_scoreboard() -> void:
	waiting_for_serve = true
	serve_timer = 0.0


func update_waiting(delta: float, target_delay: float = SERVE_DELAY) -> bool:
	if not waiting_for_serve:
		return false
	serve_timer += delta
	return serve_timer >= target_delay


func begin_serve(start_time_msec: int) -> void:
	waiting_for_serve = false
	serve_timer = 0.0
	round_start_time_msec = start_time_msec


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
		"serve_delay": SERVE_DELAY,
	}
