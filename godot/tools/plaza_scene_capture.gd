extends SceneTree

# One-off visual QA harness for the S4 side-scroll plaza shell.
# Renders plaza_scene onto a SubViewport at several player positions and saves
# PNGs so the layering / parallax / building scale can be eyeballed without a
# full battle. Run WITHOUT --headless (dummy driver returns a blank image).
# Not a smoke test -- safe to delete.

const PlazaScene := preload("res://scripts/plaza/plaza_scene.gd")

const VIEW := Vector2i(1488, 918)
const OUT_DIR := "d:/tmp/plaza_s4"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("plaza_scene_capture must run WITHOUT --headless")
		quit(1)
		return
	var dir := DirAccess.open("d:/tmp")
	if dir != null and not dir.dir_exists("plaza_s4"):
		dir.make_dir("plaza_s4")

	var viewport := SubViewport.new()
	viewport.size = VIEW
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var plaza: Control = PlazaScene.new()
	plaza.set("_driven_by_controller", true)
	viewport.add_child(plaza)
	plaza.configure({"current_stage": 1}, Callable(), true)
	plaza.call("_sync_game_rect")

	# Sweep several camera positions across the 3040px street.
	var shots := {
		"spawn_left": 120.0,
		"buildings_a": 760.0,
		"buildings_b": 1520.0,
		"buildings_c": 2280.0,
		"exit_right": 2980.0,
	}
	for tag in shots.keys():
		plaza.call("set_player_pos_for_test", Vector2(float(shots[tag]), 666.0))
		plaza.queue_redraw()
		await process_frame
		await process_frame
		var image: Image = viewport.get_texture().get_image()
		var out_path := "%s/plaza_stage1_%s.png" % [OUT_DIR, str(tag)]
		image.save_png(out_path)
		print("[PlazaCapture] %s (player_x=%s) -> %s" % [str(tag), str(shots[tag]), out_path])

	plaza.call("set_player_pos_for_test", Vector2(1520.0, 666.0))
	plaza.queue_redraw()
	await process_frame
	var flicker_a: Image = viewport.get_texture().get_image()
	var flicker_a_path := "%s/plaza_stage1_flicker_tick_a.png" % OUT_DIR
	flicker_a.save_png(flicker_a_path)
	await process_frame
	await process_frame
	await process_frame
	plaza.queue_redraw()
	await process_frame
	var flicker_b: Image = viewport.get_texture().get_image()
	var flicker_b_path := "%s/plaza_stage1_flicker_tick_b.png" % OUT_DIR
	flicker_b.save_png(flicker_b_path)
	print("[PlazaCapture] flicker ticks -> %s / %s" % [flicker_a_path, flicker_b_path])

	plaza.call("set_player_pos_for_test", Vector2(360.0, 666.0))
	plaza.call("trigger_interaction_for_test")
	plaza.queue_redraw()
	await process_frame
	await process_frame
	var menu_image: Image = viewport.get_texture().get_image()
	var menu_path := "%s/plaza_stage1_menu_shop.png" % OUT_DIR
	menu_image.save_png(menu_path)
	print("[PlazaCapture] menu_shop -> %s" % menu_path)

	print("[PlazaCapture] done")
	quit(0)
