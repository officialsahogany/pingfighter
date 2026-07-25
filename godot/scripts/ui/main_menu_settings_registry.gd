extends RefCounted

# Minimal dependency registry used by PauseMenuOverlay on the main-menu host.

var audio_settings: Object = null
var view_layout: Object = null


func _init(audio: Object, layout: Object) -> void:
	audio_settings = audio
	view_layout = layout


func get_instance(key: String) -> Object:
	match key:
		"game_audio":
			return audio_settings
		"battle_view_layout":
			return view_layout
	return null


func clear_runtime_state() -> void:
	audio_settings = null
	view_layout = null
