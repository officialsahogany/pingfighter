extends RefCounted

var is_open := false
var building_type := ""
var title := ""
var subtitle := ""
var actions: Array[String] = []
var last_message := ""
var visit_ap_consumed := false


func open_menu(next_building_type: String, next_title: String, next_subtitle: String, next_actions: Variant) -> void:
	is_open = true
	building_type = next_building_type
	title = next_title
	subtitle = next_subtitle
	set_actions(next_actions)
	last_message = ""
	visit_ap_consumed = false


func set_actions(next_actions: Variant) -> void:
	actions.clear()
	if next_actions is Array:
		for action in next_actions as Array:
			actions.append(str(action))


func set_message(message: String) -> void:
	last_message = message


func mark_visit_ap_consumed() -> void:
	visit_ap_consumed = true


func needs_visit_ap() -> bool:
	return not visit_ap_consumed


func reset() -> void:
	is_open = false
	building_type = ""
	title = ""
	subtitle = ""
	actions.clear()
	last_message = ""
	visit_ap_consumed = false
