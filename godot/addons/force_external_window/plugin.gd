@tool
extends EditorPlugin


func _enter_tree() -> void:
	var settings := EditorInterface.get_editor_settings()
	if settings == null:
		return
	var current: int = settings.get_setting("run/window_placement/game_embed_mode")
	if current != 2:
		settings.set_setting("run/window_placement/game_embed_mode", 2)
		print("[force_external_window] game_embed_mode changed from %d to 2 (Always External Window)" % current)
	else:
		print("[force_external_window] game_embed_mode already 2 (Always External Window)")
