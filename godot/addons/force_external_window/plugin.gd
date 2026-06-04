@tool
extends EditorPlugin


const GAME_EMBED_MODE_DISABLED := -1
const GAME_EMBED_MODE_SETTING := "run/window_placement/game_embed_mode"


func _enter_tree() -> void:
	var settings := EditorInterface.get_editor_settings()
	if settings == null:
		return
	if not settings.has_setting(GAME_EMBED_MODE_SETTING):
		return
	var current: int = int(settings.get_setting(GAME_EMBED_MODE_SETTING))
	if current == GAME_EMBED_MODE_DISABLED:
		print("[force_external_window] game_embed_mode already -1 (Disabled / external game window)")
		return
	settings.set_setting(GAME_EMBED_MODE_SETTING, GAME_EMBED_MODE_DISABLED)
	print("[force_external_window] game_embed_mode changed from %d to -1 (Disabled / external game window)" % current)
