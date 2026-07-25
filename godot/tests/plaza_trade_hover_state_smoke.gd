extends SceneTree

const PlazaTradeHoverState := preload("res://scripts/plaza/plaza_trade_hover_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	var state := PlazaTradeHoverState.new()
	_expect(not state.has_item(), "new hover state should not select an item")
	_expect(not state.update("", -1, Vector2(12.0, 18.0)), "pointer-only movement should not report a selection change")
	_expect_vec(state.local_position, Vector2(12.0, 18.0), "pointer-only movement")

	_expect(state.update("shop", 8, Vector2(420.0, 260.0)), "new hovered item should report a change")
	_expect(state.has_item(), "valid panel and index should select an item")
	_expect(state.panel == "shop" and state.index == 8, "hover identity")
	_expect(not state.update("shop", 8, Vector2(430.0, 270.0)), "movement inside one cell should preserve selection")
	_expect_vec(state.local_position, Vector2(430.0, 270.0), "same-cell pointer update")

	_expect(state.update("player", 3, Vector2(140.0, 280.0)), "cross-panel hover should report a change")
	_expect(state.panel == "player" and state.index == 3, "cross-panel identity")
	_expect(state.update("", -1, Vector2(20.0, 20.0)), "leaving panels should report a change")
	_expect(not state.has_item(), "leaving panels should clear item selection")

	state.reset()
	_expect(state.panel == "" and state.index == -1, "reset identity")
	_expect_vec(state.local_position, Vector2.ZERO, "reset pointer")

	if _failures.is_empty():
		print("plaza_trade_hover_state_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _expect_vec(actual: Vector2, expected: Vector2, label: String) -> void:
	if not actual.is_equal_approx(expected):
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])
