extends SceneTree

# Throwaway visual-QA harness for the Slice D bright editorial pause MAIN menu.
# Renders PauseMenuOverlay.draw() onto a SubViewport at the real project view size
# so the editorial re-skin can be eyeballed (state smokes can't judge "looks right").
# Run WITHOUT --headless (dummy driver returns a blank image). Safe to delete.
#
#   godot --path godot -s res://tools/pause_menu_editorial_capture.gd

const PauseMenuOverlay := preload("res://scripts/hud/pause_menu_overlay.gd")
const OUT_DIR := "d:/tmp/bosspong_ui_panel_capture/pause_slice_d"
const VIEW := Vector2(2020, 1246)


class MenuDrawer:
	extends Node2D

	var overlay: Object
	var view: Vector2

	func _draw() -> void:
		overlay.draw(self, null, null, view)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("pause_menu_editorial_capture must run WITHOUT --headless")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(VIEW)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var shots := [
		{"idx": 0, "name": "resume"},
		{"idx": 1, "name": "status"},
		{"idx": 2, "name": "settings"},
	]
	for shot in shots:
		var overlay: Object = PauseMenuOverlay.new()
		overlay.open()
		overlay.animation_time = 1.0
		overlay.selected_index = int(shot["idx"])
		var drawer := MenuDrawer.new()
		drawer.overlay = overlay
		drawer.view = VIEW
		viewport.add_child(drawer)
		drawer.queue_redraw()
		await process_frame
		await process_frame
		var img: Image = viewport.get_texture().get_image()
		img.save_png("%s/pause_main_%s.png" % [OUT_DIR, str(shot["name"])])
		print("[PauseEditorialCapture] %s saved" % str(shot["name"]))
		viewport.remove_child(drawer)
		drawer.queue_free()

	var opt_shots := [
		{"tab": "sound", "name": "options_sound"},
		{"tab": "display", "name": "options_display"},
		{"tab": "controls", "name": "options_controls"},
		{"tab": "language", "name": "options_language"},
	]
	for shot in opt_shots:
		var overlay: Object = PauseMenuOverlay.new()
		overlay.open()
		overlay.active = true
		overlay.options_open = true
		overlay.options_tab = str(shot["tab"])
		overlay.animation_time = 1.0
		overlay.options_focus = 0
		var drawer := MenuDrawer.new()
		drawer.overlay = overlay
		drawer.view = VIEW
		viewport.add_child(drawer)
		drawer.queue_redraw()
		await process_frame
		await process_frame
		var img: Image = viewport.get_texture().get_image()
		img.save_png("%s/pause_%s.png" % [OUT_DIR, str(shot["name"])])
		print("[PauseEditorialCapture] %s saved" % str(shot["name"]))
		viewport.remove_child(drawer)
		drawer.queue_free()

	var opt_open_shots := [0.05, 0.11, 0.20]
	for t in opt_open_shots:
		var overlay: Object = PauseMenuOverlay.new()
		overlay.open()
		overlay.active = true
		overlay.options_open = true
		overlay.options_tab = "sound"
		overlay.options_focus = 0
		overlay.animation_time = float(t)
		var drawer := MenuDrawer.new()
		drawer.overlay = overlay
		drawer.view = VIEW
		viewport.add_child(drawer)
		drawer.queue_redraw()
		await process_frame
		await process_frame
		var img: Image = viewport.get_texture().get_image()
		img.save_png("%s/pause_options_open_%03d.png" % [OUT_DIR, int(round(float(t) * 100.0))])
		print("[PauseEditorialCapture] options_open_%03d saved" % int(round(float(t) * 100.0)))
		viewport.remove_child(drawer)
		drawer.queue_free()

	var open_shots := [0.05, 0.11, 0.20]
	for t in open_shots:
		var overlay: Object = PauseMenuOverlay.new()
		overlay.open()
		overlay.selected_index = 0
		overlay.animation_time = float(t)
		var drawer := MenuDrawer.new()
		drawer.overlay = overlay
		drawer.view = VIEW
		viewport.add_child(drawer)
		drawer.queue_redraw()
		await process_frame
		await process_frame
		var img: Image = viewport.get_texture().get_image()
		img.save_png("%s/pause_open_%03d.png" % [OUT_DIR, int(round(float(t) * 100.0))])
		print("[PauseEditorialCapture] open_%03d saved" % int(round(float(t) * 100.0)))
		viewport.remove_child(drawer)
		drawer.queue_free()
	quit(0)
