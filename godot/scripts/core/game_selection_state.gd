extends Node

signal selection_changed(selection: Dictionary)

var character_id: String = "ufo_player"
var runtime_character_id: String = "smasher"
var character_name: String = "스매셔"


func set_character(data: Dictionary) -> void:
	character_id = str(data.get("id", character_id))
	runtime_character_id = str(data.get("runtime_id", runtime_character_id))
	character_name = str(data.get("name", character_name))
	selection_changed.emit(get_selection())


func get_selection() -> Dictionary:
	return {
		"character_id": character_id,
		"runtime_character_id": runtime_character_id,
		"character_name": character_name,
	}
