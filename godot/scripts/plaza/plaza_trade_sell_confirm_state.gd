extends RefCounted

var panel := ""
var index := -1
var item: Dictionary = {}


func is_open() -> bool:
	return panel != ""


func open(next_panel: String, next_index: int, item_data: Dictionary) -> bool:
	if next_panel == "" or next_index < 0 or item_data.is_empty():
		return false
	panel = next_panel
	index = next_index
	item = item_data.duplicate(true)
	return true


func consume_request() -> Dictionary:
	if not is_open() or index < 0:
		return {}
	var request := {
		"panel": panel,
		"index": index,
	}
	reset()
	return request


func reset() -> void:
	panel = ""
	index = -1
	item.clear()
