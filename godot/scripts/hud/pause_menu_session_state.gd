extends RefCounted

var active := false
var options_open := false
var options_only := false
var animation_time := 0.0
var selected_index := 0
var dragging_slider := ""
var main_dial_time := 0.0


func open_main() -> void:
	active = true
	options_open = false
	options_only = false
	animation_time = 0.0
	selected_index = 0
	dragging_slider = ""
	main_dial_time = 0.0


func close() -> void:
	active = false
	options_open = false
	options_only = false
	selected_index = 0
	dragging_slider = ""
	main_dial_time = 0.0


func begin_options(direct_options_only: bool) -> void:
	active = true
	options_only = direct_options_only
	animation_time = 0.0


func open_options_page() -> void:
	options_open = true
	selected_index = 0
	dragging_slider = ""


func close_options_page() -> void:
	options_open = false
	selected_index = 0
	dragging_slider = ""


func advance(delta: float, dial_cycle_seconds: float) -> bool:
	if not active:
		return false
	animation_time += delta
	main_dial_time = fposmod(main_dial_time + delta, maxf(dial_cycle_seconds, 0.001))
	return true
