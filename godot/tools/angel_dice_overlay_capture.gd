extends SceneTree

# Repeatable WINDOWED pixel-QA harness for the 천사의 주사위 3-piece dice VFX.
# Run WITHOUT --headless so the SubViewport uses the real canvas renderer and the
# writhe-ember ADD shader + GPUParticles2D actually rasterize:
#   godot --path godot -s res://tools/angel_dice_overlay_capture.gd
#
# One fresh host per shot guarantees a clean particle state so burst frames are
# not contaminated by a previous shot's still-flying motes.

const AngelBlessingRollOverlayHost := preload("res://scripts/hud/angel_blessing_roll_overlay_host.gd")
const OUT_DIR := "d:/tmp/bosspong_ui_panel_capture/angel_dice"
const GAME_SIZE := Vector2(760.0, 750.0)


class BackgroundDrawer:
	extends Node2D

	func _draw() -> void:
		# Mid-tone split so the modal's own dim + panel read against something,
		# and a thin magenta frame so any non-transparent texture margin bleeding
		# past a layer rect is obvious at the canvas edge.
		draw_rect(Rect2(Vector2.ZERO, GAME_SIZE), Color(0.10, 0.12, 0.17))
		draw_rect(Rect2(GAME_SIZE.x * 0.5, 0.0, GAME_SIZE.x * 0.5, GAME_SIZE.y), Color(0.16, 0.14, 0.20))
		draw_rect(Rect2(Vector2.ZERO, GAME_SIZE), Color(1.0, 0.0, 1.0, 0.9), false, 2.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("angel_dice_overlay_capture must run WITHOUT --headless (needs the real renderer)")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	AngelBlessingRollOverlayHost.prewarm_assets()

	# Each shot: a short elapsed timeline that lands on the target phase with the
	# correct entry edge fired, then a few settle frames for the particle bloom.
	# [name, [drive elapsed sequence...], settle_frames]
	var shots := [
		["p1_descent", [0.0, 0.20, 0.42], 3],
		["p2_rolling_burst", [0.30, 0.72, 0.86], 5],
		["p3_rolling_mid", [0.72, 1.15, 1.60], 4],
		["p4_settle_pop", [1.60, 2.10, 2.42], 5],
		["p5_highlight", [2.30, 2.62, 2.86], 4],
		["p6_wait_confirm", [2.86, 3.10, 3.40], 4],
	]
	for shot_value: Variant in shots:
		var shot: Array = shot_value as Array
		await _capture_modal(str(shot[0]), shot[1] as Array, int(shot[2]))

	# Post-confirm absorption tail (three trajectories toward the paddle).
	await _capture_absorption("p7_absorption")
	quit(0)


func _capture_modal(shot_name: String, elapsed_seq: Array, settle_frames: int) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(GAME_SIZE.x), int(GAME_SIZE.y))
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var bg := BackgroundDrawer.new()
	viewport.add_child(bg)
	bg.queue_redraw()

	var host: Node2D = AngelBlessingRollOverlayHost.new()
	viewport.add_child(host)
	host.prepare()

	for elapsed_value: Variant in elapsed_seq:
		host.sync_state(_modal_snapshot(float(elapsed_value)), Vector2(380.0, 690.0), _layout())
		await process_frame
	for _i: int in range(maxi(1, settle_frames)):
		await process_frame

	var image: Image = viewport.get_texture().get_image()
	var output_path := "%s/%s.png" % [OUT_DIR, shot_name]
	image.save_png(output_path)
	print("[AngelDiceCapture] %s" % output_path)

	get_root().remove_child(viewport)
	viewport.queue_free()
	await process_frame


func _capture_absorption(shot_name: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(GAME_SIZE.x), int(GAME_SIZE.y))
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var bg := BackgroundDrawer.new()
	viewport.add_child(bg)
	bg.queue_redraw()

	var host: Node2D = AngelBlessingRollOverlayHost.new()
	viewport.add_child(host)
	host.prepare()

	var trajectories: Array = []
	var buff_ids := ["paddle_size", "gauge_max", "move_speed"]
	for index: int in range(3):
		trajectories.append({
			"index": index,
			"buff_id": buff_ids[index],
			"delay": float(index) * 0.22,
			"travel_duration": 1.8,
			"arrival_time": 1.8 + float(index) * 0.22,
		})
	host.sync_state({
		"modal_active": false,
		"absorption": {
			"active": true,
			"elapsed": 0.90,
			"glow_duration": 0.35,
			"trajectories": trajectories,
		},
	}, Vector2(410.0, 690.0), _layout())
	for _i: int in range(6):
		await process_frame

	var image: Image = viewport.get_texture().get_image()
	var output_path := "%s/%s.png" % [OUT_DIR, shot_name]
	image.save_png(output_path)
	print("[AngelDiceCapture] %s" % output_path)

	get_root().remove_child(viewport)
	viewport.queue_free()
	await process_frame


func _modal_snapshot(elapsed: float) -> Dictionary:
	return {
		"modal_active": true,
		"modal_elapsed": elapsed,
		"active_modal": {
			"roll_result": {
				"rolled": true,
				"active_stage": 3,
				"roll_face": 3,
				"active_buff_ids": ["paddle_size", "gauge_max", "move_speed"],
			},
		},
		"absorption": {"active": false},
	}


func _layout() -> Dictionary:
	return {
		"game_offset": Vector2.ZERO,
		"render_scale": 1.0,
		"game_size": GAME_SIZE,
	}
