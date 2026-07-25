extends RefCounted

var selected_object_id := ""
var clicked_object_id := ""
var panel_open := false


func open_panel(object_id: String) -> bool:
	if object_id == "":
		return false
	selected_object_id = object_id
	clicked_object_id = object_id
	panel_open = true
	return true


func start_click(object_id: String) -> bool:
	if object_id == "":
		return false
	selected_object_id = object_id
	clicked_object_id = object_id
	panel_open = false
	return true


func hide_panel() -> void:
	panel_open = false


func cancel_panel() -> void:
	panel_open = false
	selected_object_id = ""


func reset() -> void:
	selected_object_id = ""
	clicked_object_id = ""
	panel_open = false
