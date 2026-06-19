extends SceneTree

# Throwaway visual-QA harness for the in-battle gold HUD. Renders
# Stage1PillarUiRenderer.draw_gold_hud onto a SubViewport so the shadow / outline
# treatment can be eyeballed before/after a cleanup. Run WITHOUT --headless
# (dummy driver returns a blank image). Not a smoke test -- safe to delete.
#
#   godot --path godot -s res://tools/gold_hud_capture.gd -- --tag=before

const Renderer := preload("res://scripts/hud/stage1_pillar_ui_renderer.gd")
const OUT_DIR := "d:/tmp/goldhud"
const VIEW := Vector2(960, 220)


class GoldHudDrawer:
	extends Node2D

	var renderer: Object
	var view: Vector2
	var game_offset: Vector2
	var game_size: Vector2
	var ctx: Dictionary

	func _draw() -> void:
		# Dark backdrop like the pillar letterbox the gold HUD sits over.
		draw_rect(Rect2(Vector2.ZERO, view), Color(0.07, 0.08, 0.11, 1.0), true)
		renderer.draw_gold_hud(self, game_offset, game_size, ctx)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("gold_hud_capture must run WITHOUT --headless")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var tag := "after"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			tag = arg.substr(6)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(VIEW)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var shots := [
		{"amount": 1234, "scale_y": 1680.0, "name": "detail_1234"},
		{"amount": 1250000, "scale_y": 1680.0, "name": "detail_big"},
		{"amount": 1234, "scale_y": 900.0, "name": "real_1234"},
	]
	for shot in shots:
		var drawer := GoldHudDrawer.new()
		drawer.renderer = Renderer.new()
		drawer.view = VIEW
		drawer.game_size = Vector2(1500.0, float(shot["scale_y"]))
		drawer.game_offset = Vector2(820.0, 40.0)
		drawer.ctx = {"gold_hud_amount": int(shot["amount"]), "height": 750.0}
		viewport.add_child(drawer)
		drawer.queue_redraw()
		await process_frame
		await process_frame
		var img: Image = viewport.get_texture().get_image()
		img.save_png("%s/gold_hud_%s_%s.png" % [OUT_DIR, tag, str(shot["name"])])
		print("[GoldHudCapture] %s_%s saved" % [tag, str(shot["name"])])
		viewport.remove_child(drawer)
		drawer.queue_free()
	quit(0)
