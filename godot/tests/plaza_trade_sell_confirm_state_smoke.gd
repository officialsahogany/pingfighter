extends SceneTree

const PlazaTradeSellConfirmState := preload("res://scripts/plaza/plaza_trade_sell_confirm_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	var state := PlazaTradeSellConfirmState.new()
	_expect(not state.is_open(), "new state should be closed")
	_expect(not state.open("", 2, {"id": "ring"}), "blank panel should be rejected")
	_expect(not state.open("player", -1, {"id": "ring"}), "negative index should be rejected")
	_expect(not state.open("player", 2, {}), "empty item should be rejected")

	var source_item := {"id": "ring", "rolls": {"power": 3}}
	_expect(state.open("player", 2, source_item), "valid sell request should open")
	_expect(state.is_open(), "opened state should report open")
	_expect(state.panel == "player" and state.index == 2, "open should retain request identity")
	(source_item["rolls"] as Dictionary)["power"] = 99
	_expect(int((state.item.get("rolls", {}) as Dictionary).get("power", 0)) == 3, "item snapshot should be deep-copied")

	var request := state.consume_request()
	_expect(str(request.get("panel", "")) == "player", "consume should return panel")
	_expect(int(request.get("index", -1)) == 2, "consume should return index")
	_expect(not state.is_open(), "consume should close state")
	_expect(state.item.is_empty(), "consume should clear item snapshot")
	_expect(state.consume_request().is_empty(), "closed state should not emit a request")

	_expect(state.open("player", 4, {"id": "shield"}), "state should reopen after consume")
	state.reset()
	_expect(not state.is_open() and state.index == -1, "reset should clear request identity")

	if _failures.is_empty():
		print("plaza_trade_sell_confirm_state_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
