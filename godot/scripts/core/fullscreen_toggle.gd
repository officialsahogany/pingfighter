extends Node

const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const FULLSCREEN_TOGGLE_KEY := KEY_F11

var view_layout: Object = BattleViewLayout.new()


func _input(event: InputEvent) -> void:
	if not handle_input_event(event):
		return
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func handle_input_event(event: InputEvent) -> bool:
	if not is_fullscreen_toggle_event(event):
		return false
	if view_layout == null or not view_layout.has_method("toggle_fullscreen"):
		return false
	var window := get_window()
	if window == null:
		return false
	view_layout.toggle_fullscreen(window)
	return true


func is_fullscreen_toggle_event(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode == FULLSCREEN_TOGGLE_KEY or key_event.physical_keycode == FULLSCREEN_TOGGLE_KEY
