extends SceneTree

const PlazaTradeScrollState := preload("res://scripts/plaza/plaza_trade_scroll_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	var state := PlazaTradeScrollState.new()
	_expect_offset(state, "player", 40, 0, "player initial offset")
	_expect_offset(state, "shop", 40, 0, "shop initial offset")
	_expect(not state.scroll_rows("unknown", 1, 40), "unknown panel should not scroll")
	_expect(not state.scroll_rows("player", 1, 30), "a full visible page should not scroll")
	_expect(not state.scroll_rows("player", 0, 40), "zero direction should not scroll")

	_expect(state.scroll_rows("player", 1, 31), "31 items should scroll one row")
	_expect_offset(state, "player", 31, 5, "31-item max offset")
	_expect(not state.scroll_rows("player", 1, 31), "31 items should stop at one-row max")
	_expect_offset(state, "shop", 36, 0, "panel offsets should remain independent")

	_expect(state.scroll_rows("shop", 1, 36), "shop should scroll to first overflow row")
	_expect(state.scroll_rows("shop", 1, 36), "shop should scroll to second overflow row")
	_expect_offset(state, "shop", 36, 10, "36-item max offset")
	_expect(state.scroll_rows("shop", -1, 36), "negative direction should scroll upward")
	_expect_offset(state, "shop", 36, 5, "shop upward offset")

	state.clamp_inventories(30, 31)
	_expect_offset(state, "player", 30, 0, "player shrink clamp")
	_expect_offset(state, "shop", 31, 5, "shop shrink clamp")
	state.reset()
	_expect_offset(state, "player", 50, 0, "player reset")
	_expect_offset(state, "shop", 50, 0, "shop reset")

	if _failures.is_empty():
		print("plaza_trade_scroll_state_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect_offset(state: Object, panel: String, item_count: int, expected: int, label: String) -> void:
	var actual: int = state.get_offset(panel, item_count)
	if actual != expected:
		_failures.append("%s: expected %d, got %d" % [label, expected, actual])


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
