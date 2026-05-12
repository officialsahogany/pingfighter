extends RefCounted

var active_order: Array[String] = []
var seen_this_frame: Dictionary = {}
var frame_open := false


func reset() -> void:
	active_order.clear()
	seen_this_frame.clear()
	frame_open = false


func begin_frame() -> void:
	seen_this_frame.clear()
	frame_open = true


func claim(key: String, active: bool = true) -> int:
	if key == "":
		return -1
	if not active:
		deactivate(key)
		return -1
	if frame_open:
		seen_this_frame[key] = true
	if not active_order.has(key):
		active_order.append(key)
	return active_order.find(key)


func deactivate(key: String) -> void:
	var index: int = active_order.find(key)
	if index >= 0:
		active_order.remove_at(index)
	seen_this_frame.erase(key)


func end_frame() -> void:
	if not frame_open:
		return
	for index in range(active_order.size() - 1, -1, -1):
		var key: String = active_order[index]
		if not seen_this_frame.has(key):
			active_order.remove_at(index)
	seen_this_frame.clear()
	frame_open = false


func get_index(key: String) -> int:
	return active_order.find(key)


func get_active_order() -> Array[String]:
	var snapshot: Array[String] = []
	snapshot.append_array(active_order)
	return snapshot
