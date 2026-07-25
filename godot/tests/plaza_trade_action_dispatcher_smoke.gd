extends SceneTree

const PlazaTradeActionDispatcher := preload("res://scripts/plaza/plaza_trade_action_dispatcher.gd")

var _failures: Array[String] = []


class CallbackSink:
	extends RefCounted

	var requests: Array[Dictionary] = []
	var accept := true

	func receive(request: Dictionary) -> bool:
		requests.append(request.duplicate(true))
		return accept


func _init() -> void:
	var dispatcher := PlazaTradeActionDispatcher.new()
	_expect(not dispatcher.dispatch_trade("shop", 2), "missing callback should reject trade")
	_expect(not dispatcher.dispatch_reorder("shop", 2, 3), "missing callback should reject reorder")

	var sink := CallbackSink.new()
	dispatcher.set_callback(Callable(sink, "receive"))
	_expect(not dispatcher.dispatch_trade("", 2), "blank trade panel")
	_expect(not dispatcher.dispatch_trade("shop", -1), "negative trade index")
	_expect(sink.requests.is_empty(), "invalid trades should not call callback")
	_expect(dispatcher.dispatch_trade("shop", 8), "accepted trade should succeed")
	_expect(sink.requests.size() == 1, "trade callback count")
	if sink.requests.size() == 1:
		var request := sink.requests[0]
		_expect(str(request.get("type", "")) == "shop_trade", "trade request type")
		_expect(str(request.get("panel", "")) == "shop" and int(request.get("index", -1)) == 8, "trade request identity")

	_expect(not dispatcher.dispatch_reorder("shop", 2, 2), "same-index reorder")
	_expect(not dispatcher.dispatch_reorder("", 2, 3), "blank reorder panel")
	_expect(dispatcher.dispatch_reorder("player", 3, 7), "accepted reorder should succeed")
	_expect(sink.requests.size() == 2, "reorder callback count")
	if sink.requests.size() == 2:
		var request := sink.requests[1]
		_expect(str(request.get("type", "")) == "shop_trade_reorder", "reorder request type")
		_expect(int(request.get("from_index", -1)) == 3 and int(request.get("to_index", -1)) == 7, "reorder indices")

	sink.accept = false
	_expect(not dispatcher.dispatch_trade("player", 0), "callback rejection should propagate")
	_expect(sink.requests.size() == 3, "rejected valid request should still reach callback once")
	dispatcher.set_callback(Callable())
	_expect(not dispatcher.dispatch_trade("shop", 1), "cleared callback should reject")

	if _failures.is_empty():
		print("plaza_trade_action_dispatcher_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
