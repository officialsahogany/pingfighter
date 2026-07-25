extends RefCounted

var _callback: Callable = Callable()


func set_callback(next_callback: Callable) -> void:
	_callback = next_callback


func dispatch_trade(panel: String, index: int) -> bool:
	if panel == "" or index < 0 or not _callback.is_valid():
		return false
	return bool(_callback.call({
		"type": "shop_trade",
		"panel": panel,
		"index": index,
	}))


func dispatch_reorder(panel: String, from_index: int, to_index: int) -> bool:
	if panel == "" or from_index < 0 or to_index < 0 or from_index == to_index:
		return false
	if not _callback.is_valid():
		return false
	return bool(_callback.call({
		"type": "shop_trade_reorder",
		"panel": panel,
		"from_index": from_index,
		"to_index": to_index,
	}))
