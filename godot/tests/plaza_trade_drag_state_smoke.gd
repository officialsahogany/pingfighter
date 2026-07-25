extends SceneTree

const PlazaTradeDragState := preload("res://scripts/plaza/plaza_trade_drag_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	var state := PlazaTradeDragState.new()
	_expect(not state.is_active(), "new drag state should be inactive")
	var source_item := {"name": "battery", "nested": {"value": 3}}
	state.start("player", 4, Vector2(100.0, 200.0), source_item)
	_expect(state.is_active(), "start should activate drag state")
	_expect(state.panel == "player" and state.index == 4, "start should capture source identity")
	_expect_vec(state.start_position, Vector2(100.0, 200.0), "start position")
	_expect_vec(state.position, Vector2(100.0, 200.0), "initial current position")
	(source_item["nested"] as Dictionary)["value"] = 99
	_expect(int((state.item.get("nested", {}) as Dictionary).get("value", 0)) == 3, "drag item should be deep-copied")

	state.update_position(Vector2(103.0, 204.0))
	_expect_vec(state.position, Vector2(103.0, 204.0), "current position update")
	_expect_close(state.get_distance_to(Vector2(103.0, 204.0)), 5.0, "drag distance")
	_expect(state.is_click_release(Vector2(103.0, 204.0)), "movement within threshold should remain a click")
	_expect(state.is_click_release(Vector2(106.0, 200.0)), "threshold boundary should remain a click")
	_expect(not state.is_click_release(Vector2(106.01, 200.0)), "movement beyond threshold should become a drag")

	state.reset()
	_expect(not state.is_active(), "reset should deactivate drag state")
	_expect(state.panel == "" and state.index == -1, "reset should clear source identity")
	_expect(state.item.is_empty(), "reset should clear item snapshot")
	_expect_vec(state.start_position, Vector2.ZERO, "reset start position")
	_expect_vec(state.position, Vector2.ZERO, "reset current position")

	if _failures.is_empty():
		print("plaza_trade_drag_state_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _expect_close(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s: expected %.4f, got %.4f" % [label, expected, actual])


func _expect_vec(actual: Vector2, expected: Vector2, label: String) -> void:
	if not actual.is_equal_approx(expected):
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])
