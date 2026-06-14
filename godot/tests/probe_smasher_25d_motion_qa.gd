extends Node

# Dynamic-motion pixel probe for the Smasher 2.5D pilot (plan §6.4 / felt-QA pre-pass).
# Boots straight into stage 1 champion battle, then drives scripted input:
#   serve -> walk right -> dash right -> walk left -> dash left -> idle (rally continues)
# while burst-capturing the lower half of the viewport every 0.25s.
# Run:  godot --path godot res://tests/probe_smasher_25d_motion_qa.tscn
# Env:  PROBE_TAG=off|on, PINGFIGHTER_SMASHER_25D=1 for the ON run.


class MotionDriver:
	extends Node

	const OUT_DIR := "d:/tmp/smasher_25d_pilot/ingame_motion"
	const CAPTURE_START := 19.0
	const CAPTURE_END := 34.0
	const CAPTURE_STEP := 0.25
	# [time, action, press(true)/release(false)]
	const INPUT_SCRIPT := [
		[19.0, "ui_accept", true],
		[19.4, "ui_accept", false],
		[20.5, "ui_right", true],
		[23.0, "ui_down", true],
		[23.3, "ui_down", false],
		[24.0, "ui_right", false],
		[24.5, "ui_left", true],
		[26.5, "ui_down", true],
		[26.8, "ui_down", false],
		[27.5, "ui_left", false],
		[29.0, "ui_accept", true],
		[29.4, "ui_accept", false],
	]

	var elapsed := 0.0
	var input_idx := 0
	var next_capture := CAPTURE_START
	var shot_idx := 0
	var tag := "on"

	func _process(delta: float) -> void:
		elapsed += delta
		while input_idx < INPUT_SCRIPT.size() and elapsed >= float(INPUT_SCRIPT[input_idx][0]):
			var entry: Array = INPUT_SCRIPT[input_idx]
			if bool(entry[2]):
				Input.action_press(str(entry[1]))
			else:
				Input.action_release(str(entry[1]))
			input_idx += 1
		if elapsed >= next_capture and elapsed <= CAPTURE_END:
			var img := get_viewport().get_texture().get_image()
			var h := img.get_height()
			var region := img.get_region(Rect2i(0, int(h * 0.45), img.get_width(), int(h * 0.55)))
			region.save_png("%s/m_%s_%03d.png" % [OUT_DIR, tag, shot_idx])
			shot_idx += 1
			next_capture += CAPTURE_STEP
		if elapsed > CAPTURE_END:
			print("motion probe done, %d shots" % shot_idx)
			get_tree().quit()


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("d:/tmp/smasher_25d_pilot/ingame_motion")
	var sel := get_node("/root/GameSelectionState")
	sel.set_stage(1)
	sel.set_league_mode("champion")
	sel.request_skip_battle_logo_once()
	var driver := MotionDriver.new()
	driver.name = "Smasher25DMotionDriver"
	driver.tag = OS.get_environment("PROBE_TAG")
	if driver.tag.is_empty():
		driver.tag = "on"
	get_tree().root.add_child.call_deferred(driver)
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
