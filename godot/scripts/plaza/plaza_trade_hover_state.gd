extends RefCounted

var panel := ""
var index := -1
var local_position := Vector2.ZERO


func has_item() -> bool:
	return panel != "" and index >= 0


func update(next_panel: String, next_index: int, next_local_position: Vector2) -> bool:
	local_position = next_local_position
	if panel == next_panel and index == next_index:
		return false
	panel = next_panel
	index = next_index
	return true


func reset() -> void:
	panel = ""
	index = -1
	local_position = Vector2.ZERO
