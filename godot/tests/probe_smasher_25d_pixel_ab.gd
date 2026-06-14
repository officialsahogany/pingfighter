extends Node

# Windowed pixel probe for the Smasher 2.5D sheet toggle (pilot plan §6.3).
# Boots straight into stage 1 battle (champion league, default smasher),
# captures viewport screenshots at fixed times, then quits.
# Run:  godot --path godot res://tests/probe_smasher_25d_pixel_ab.tscn
# Env:  PROBE_TAG=off|on (filename tag), PINGFIGHTER_SMASHER_25D=1 for the ON run.

const SHOT_TIMES := [16.0, 22.0, 28.0, 34.0]
const OUT_DIR := "d:/tmp/smasher_25d_pilot/ingame"


class ShotWatcher:
	extends Node
	var elapsed := 0.0
	var shot_idx := 0
	var tag := "off"

	func _process(delta: float) -> void:
		elapsed += delta
		if shot_idx < SHOT_TIMES.size() and elapsed >= SHOT_TIMES[shot_idx]:
			var img := get_viewport().get_texture().get_image()
			var out := "%s/shot_%s_%d.png" % [OUT_DIR, tag, shot_idx]
			img.save_png(out)
			print("probe saved %s" % out)
			shot_idx += 1
			if shot_idx >= SHOT_TIMES.size():
				get_tree().quit()

	const SHOT_TIMES := [16.0, 22.0, 28.0, 34.0]
	const OUT_DIR := "d:/tmp/smasher_25d_pilot/ingame"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var sel := get_node("/root/GameSelectionState")
	sel.set_stage(1)
	sel.set_league_mode("champion")
	sel.request_skip_battle_logo_once()
	var watcher := ShotWatcher.new()
	watcher.name = "Smasher25DProbeWatcher"
	watcher.tag = OS.get_environment("PROBE_TAG")
	if watcher.tag.is_empty():
		watcher.tag = "off"
	get_tree().root.add_child.call_deferred(watcher)
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
