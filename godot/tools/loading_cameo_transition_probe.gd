extends SceneTree

# Temporary diagnostic probe: reproduces the character_select -> main.tscn
# transition and, via RenderingServer.frame_post_draw, atomically pairs each
# drawn frame's screenshot with the exact node/transform state that produced
# it, to root-cause the "cameo appears at screen center on the first battle
# loading frame" report.

const OUT_DIR := "res://.tmp/cameo_probe2"
const CHAR_SELECT_SETTLE_FRAMES := 45
const BATTLE_CAPTURE_FRAMES := 12

var _frame := 0
var _phase := "char_select"
var _battle_frame := 0
var _lines: PackedStringArray = []
var _out_dir_abs := ""


func _init() -> void:
	call_deferred("_start")


func _start() -> void:
	_out_dir_abs = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(_out_dir_abs)
	var LoadingCameoHostScript := load("res://scripts/core/loading_cameo_host.gd")
	LoadingCameoHostScript.prewarm_assets()
	var BattleViewLayoutScript := load("res://scripts/core/battle_view_layout.gd")
	var view_layout: Object = BattleViewLayoutScript.new()
	view_layout.configure_window(root)
	var selection := root.get_node_or_null("GameSelectionState")
	if selection != null and selection.has_method("request_skip_battle_logo_once"):
		selection.request_skip_battle_logo_once()
	var err := change_scene_to_file("res://scenes/character_select.tscn")
	_log("change_scene character_select err=%d" % err)
	process_frame.connect(_on_frame)
	RenderingServer.frame_post_draw.connect(_on_post_draw)


func _on_frame() -> void:
	_frame += 1
	if _phase == "char_select":
		if _frame >= CHAR_SELECT_SETTLE_FRAMES:
			_phase = "battle"
			_log("[t=%d] SWITCH -> main.tscn" % Time.get_ticks_msec())
			var err := change_scene_to_file("res://scenes/main.tscn")
			_log("change_scene main err=%d" % err)


func _on_post_draw() -> void:
	if _phase != "battle":
		return
	_battle_frame += 1
	if _battle_frame > BATTLE_CAPTURE_FRAMES:
		_finish()
		return
	_dump_drawn_frame_state()
	_save_shot("postdraw_%02d" % _battle_frame)


func _dump_drawn_frame_state() -> void:
	var scene: Node = current_scene
	var scene_name := str(scene.name) if scene != null else "<null>"
	var final_xform := root.get_final_transform()
	var canvas_xform := root.canvas_transform
	var line := "[t=%d pd=%02d] scene=%s vis_rect=%s win=%s final_xform_scale=%s canvas_xform_scale=%s canvas_xform_origin=%s" % [
		Time.get_ticks_msec(),
		_battle_frame,
		scene_name,
		str(root.get_visible_rect().size),
		str(root.size),
		str(final_xform.get_scale()),
		str(canvas_xform.get_scale()),
		str(canvas_xform.origin),
	]
	if scene != null:
		var host := scene.find_child("LoadingCameoHost", true, false)
		if host != null and host is Node2D:
			var host_2d := host as Node2D
			var sprite := host_2d.get_node_or_null("Cameo")
			if sprite != null and sprite is Sprite2D:
				var sprite_2d := sprite as Sprite2D
				var with_canvas := sprite_2d.get_global_transform_with_canvas()
				line += " | cameo_local=%s cameo_with_canvas=%s cameo_scale=%s frame=%d visible=%s screen_xform_origin=%s" % [
					str(sprite_2d.position),
					str(with_canvas.origin),
					str(sprite_2d.scale),
					sprite_2d.frame,
					str(sprite_2d.visible and host_2d.visible),
					str(sprite_2d.get_screen_transform().origin),
				]
		else:
			line += " | host=none"
		var cameras := scene.find_children("*", "Camera2D", true, false)
		if not cameras.is_empty():
			var camera := cameras[0] as Camera2D
			line += " | camera2d=%s pos=%s enabled=%s" % [str(camera.name), str(camera.global_position), str(camera.enabled)]
	_log(line)


func _save_shot(tag: String) -> void:
	var texture := root.get_texture()
	if texture == null:
		return
	var image := texture.get_image()
	if image == null:
		return
	image.save_png(_out_dir_abs.path_join("%s.png" % tag))


func _log(line: String) -> void:
	_lines.append(line)


func _finish() -> void:
	var file := FileAccess.open(_out_dir_abs.path_join("probe_log.txt"), FileAccess.WRITE)
	if file != null:
		for line in _lines:
			file.store_line(line)
		file.close()
	print("cameo_probe2_done dir=%s" % _out_dir_abs)
	quit(0)
