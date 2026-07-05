extends SceneTree

# Throwaway visual-QA harness for the Slice A editorial chrome reskin of the
# character select screen. Renders the REAL scene (LivePreview + negative-z
# backdrop VFX host included) so the hole-punch and chrome can be eyeballed
# (state smokes cannot judge "looks right"). Run WITHOUT --headless.
#
#   godot --path godot -s res://tools/character_select_slice_a_capture.gd

const OUT_DIR := "d:/tmp/bosspong_ui_panel_capture/char_select_slice_a"
const SCENE_PATH := "res://scenes/character_select.tscn"
const WARM_FRAMES := 40


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("character_select_slice_a_capture must run WITHOUT --headless")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		push_error("failed to load %s" % SCENE_PATH)
		quit(1)
		return
	var shots := [
		{"size": Vector2i(1920, 1080), "name": "desktop_1920"},
		{"size": Vector2i(900, 700), "name": "mobile_900"},
		{"size": Vector2i(900, 1200), "name": "mobile_tall_900"},
		{"size": Vector2i(560, 900), "name": "narrow_560"},
		{"size": Vector2i(420, 700), "name": "narrow_short_420"},
	]
	for shot in shots:
		var viewport := SubViewport.new()
		viewport.size = shot["size"]
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		get_root().add_child(viewport)
		var screen: Control = packed.instantiate()
		viewport.add_child(screen)
		screen.size = Vector2(shot["size"])
		for i in range(WARM_FRAMES):
			screen.queue_redraw()
			await process_frame
		var img: Image = viewport.get_texture().get_image()
		img.save_png("%s/char_select_%s.png" % [OUT_DIR, str(shot["name"])])
		print("[CharSelectSliceACapture] %s saved" % str(shot["name"]))
		# Slice I: per-character themed backdrops — capture every roster
		# selection at the desktop size only.
		if str(shot["name"]) == "desktop_1920":
			var visible_indices: Array = screen.get("visible_indices")
			for pos in range(visible_indices.size()):
				var index := int(visible_indices[pos])
				screen.call("_select_index", index)
				for i in range(24):
					screen.queue_redraw()
					await process_frame
				var char_img: Image = viewport.get_texture().get_image()
				char_img.save_png("%s/char_select_desktop_char_%02d.png" % [OUT_DIR, index])
				print("[CharSelectSliceACapture] desktop_char_%02d saved" % index)
		viewport.remove_child(screen)
		screen.free()
		get_root().remove_child(viewport)
		viewport.queue_free()
	quit(0)
