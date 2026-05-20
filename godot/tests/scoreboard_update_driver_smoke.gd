extends SceneTree

const ScoreboardUpdateDriver := preload("res://scripts/core/battle_scene_scoreboard_update_driver.gd")

var _failures: Array[String] = []
var _overlay_update_count := 0
var _overlay_redraw_count := 0
var _last_overlay_delta := 0.0
var _scoreboard_result_count := 0
var _last_scoreboard_result := 0


class FakeOwner:
	extends RefCounted

	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1


class FakeScoreboardState:
	extends RefCounted

	var active := false
	var sparkle_timer := 0.0
	var last_sparkle_delta := 0.0
	var update_count := 0
	var last_update_delta := 0.0
	var update_result := 0

	func is_active() -> bool:
		return active

	func update_scoreboard(delta: float) -> int:
		update_count += 1
		last_update_delta = delta
		if update_result != 0:
			active = false
		return update_result

	func get_top_mini_score_sparkle_timer() -> float:
		return sparkle_timer

	func update_top_mini_sparkle(delta: float) -> void:
		last_sparkle_delta = delta
		sparkle_timer = max(0.0, sparkle_timer - delta)


class FakeMatchScoreState:
	extends RefCounted

	var deuce_mode := false

	func get_snapshot() -> Dictionary:
		return {"deuce_mode": deuce_mode}


class FakeRegistry:
	extends RefCounted

	var scoreboard_state: Object
	var match_score_state: Object

	func _init(scoreboard: Object, match_score: Object) -> void:
		scoreboard_state = scoreboard
		match_score_state = match_score

	func get_instance(key: String) -> Object:
		match key:
			"scoreboard_state":
				return scoreboard_state
			"match_score_state":
				return match_score_state
			_:
				return null


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []
	var _next_start := 100

	func begin_sample() -> int:
		_next_start += 1
		return _next_start

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)

	func has_label(label: String) -> bool:
		return labels.has(label)


func _init() -> void:
	var driver: Object = ScoreboardUpdateDriver.new()
	var owner := FakeOwner.new()
	var scoreboard := FakeScoreboardState.new()
	var match_score := FakeMatchScoreState.new()
	var registry := FakeRegistry.new(scoreboard, match_score)

	scoreboard.active = true
	driver.update_scoreboard_overlay(owner, registry, 0.125, {
		"update_scoreboard": Callable(self, "_record_overlay_update"),
		"handle_scoreboard_update_result": Callable(self, "_record_scoreboard_result"),
		"queue_redraw": Callable(self, "_record_overlay_redraw"),
	})
	_expect(_overlay_update_count == 0, "active scoreboard overlay should use direct state update when available")
	_expect(scoreboard.update_count == 1, "active scoreboard overlay should tick state once")
	_expect(abs(scoreboard.last_update_delta - 0.125) <= 0.001, "overlay driver should forward delta to scoreboard state")
	_expect(_overlay_redraw_count == 1, "active scoreboard overlay should request redraw callback")

	scoreboard.active = false
	driver.update_scoreboard_overlay(owner, registry, 0.25, {
		"update_scoreboard": Callable(self, "_record_overlay_update"),
		"queue_redraw": Callable(self, "_record_overlay_redraw"),
	})
	_expect(_overlay_update_count == 0, "inactive scoreboard overlay should not use legacy callback")
	_expect(_overlay_redraw_count == 1, "inactive scoreboard overlay should not redraw")

	scoreboard.active = true
	scoreboard.update_result = 2
	var perf_logger := FakePerfLogger.new()
	driver.update_scoreboard_overlay(owner, registry, 0.25, {
		"update_scoreboard": Callable(self, "_record_overlay_update"),
		"handle_scoreboard_update_result": Callable(self, "_record_scoreboard_result"),
		"queue_redraw": Callable(self, "_record_overlay_redraw"),
	}, perf_logger)
	_expect(_scoreboard_result_count == 1, "scoreboard completion should dispatch result callback")
	_expect(_last_scoreboard_result == 2, "scoreboard completion should forward result code")
	_expect(_overlay_redraw_count == 2, "scoreboard completion should redraw the final overlay frame")
	_expect(perf_logger.has_label("process.scoreboard_overlay.active_check"), "overlay driver should profile active checks")
	_expect(perf_logger.has_label("process.scoreboard_overlay.state_update"), "overlay driver should profile scoreboard state updates")
	_expect(perf_logger.has_label("process.scoreboard_overlay.result_callback"), "overlay driver should profile result callbacks separately")
	_expect(perf_logger.has_label("process.scoreboard_overlay.queue_redraw"), "overlay driver should profile redraw callbacks")

	scoreboard.sparkle_timer = 0.5
	driver.update_scoreboard_visuals(owner, registry, 0.1)
	_expect(abs(scoreboard.last_sparkle_delta - 0.1) <= 0.001, "top mini sparkle should tick during idle visuals")
	_expect(owner.redraw_count == 1, "top mini sparkle should queue owner redraw")

	match_score.deuce_mode = true
	driver.update_scoreboard_visuals(owner, registry, 0.1)
	_expect(owner.redraw_count == 2, "deuce top mini mode should keep owner redraws alive")

	if _failures.is_empty():
		print("scoreboard_update_driver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _record_overlay_update(delta: float) -> void:
	_overlay_update_count += 1
	_last_overlay_delta = delta


func _record_overlay_redraw() -> void:
	_overlay_redraw_count += 1


func _record_scoreboard_result(update_result: int) -> void:
	_scoreboard_result_count += 1
	_last_scoreboard_result = update_result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
