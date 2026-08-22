extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const GAME_SIZE := Vector2i(2020, 1246)
const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(GAME_SIZE))
const OUTPUT_DIR := "res://.godot/codex_captures/tower_map_zoom_cloud"
const PANEL_BLANK_COLORS := [
	Color("f1dfb8"),
	Color("63241f"),
	Color("bd8c35"),
]
const PANEL_BLANK_COLOR_EPSILON := 0.002

var _failure := ""


class MapCanvas:
	extends Node2D

	var flow: Object

	func _init(flow_owner: Object) -> void:
		flow = flow_owner

	func _draw() -> void:
		flow.draw_fullscreen_map(
			self,
			Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0)),
			{}
		)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("tower_map_zoom_cloud_visual_qa requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("tower_map_zoom_cloud_visual_qa requires Vulkan")
		return
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("could not create visual QA output directory")
		return
	var flow := TowerAscentFlowOwner.new()
	var viewport := SubViewport.new()
	viewport.size = GAME_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := MapCanvas.new(flow)
	viewport.add_child(canvas)
	if not flow.open_map_overlay(canvas, null, {
		"run_id": "tower-map-zoom-cloud-vulkan",
		"map_seed": 83521,
	}):
		_fail("could not open production map overlay")
		return
	flow.set_map_overlay_fade_progress_for_qa(1.0)
	var initial_image: Image = await _capture(canvas, viewport)
	if initial_image == null:
		_fail("initial map capture failed")
		return
	var cursor := VIEWPORT_RECT.get_center()
	for _index in range(24):
		flow.handle_input(_wheel(cursor, false))
		canvas.queue_redraw()
		await process_frame
	var minimum_image: Image = await _capture(canvas, viewport)
	if not _save_and_assert_cover(minimum_image, output_dir.path_join("zoom_minimum.png"), "minimum"):
		return
	for _index in range(3):
		flow.handle_input(_wheel(cursor, true))
		canvas.queue_redraw()
		await process_frame
	var middle_image: Image = await _capture(canvas, viewport)
	if not _save_and_assert_cover(middle_image, output_dir.path_join("zoom_middle.png"), "middle"):
		return
	for _index in range(32):
		flow.handle_input(_wheel(cursor, true))
		canvas.queue_redraw()
		await process_frame
	var maximum_image: Image = await _capture(canvas, viewport)
	if not _save_and_assert_cover(maximum_image, output_dir.path_join("zoom_maximum.png"), "maximum"):
		return
	flow.close_map_overlay()
	# The screen capture owner intentionally has no gameplay registry. Start the
	# walking fixture through the same null-owner path as the focused production
	# smokes so route pickup setup cannot depend on unrelated live inventory.
	flow = TowerAscentFlowOwner.new()
	canvas.flow = flow
	if not flow.begin_vertical_slice(null, Callable(), {
		"run_id": "tower-map-cloud-walk-vulkan",
		"map_seed": 83521,
	}):
		_fail("could not enter walking map after overlay capture")
		return
	var revealed_floor := int(flow.export_snapshot().get("run_progress", {}).get("revealed_floor", 0))
	var target_id := _promote_first_target_to_next_floor(flow, revealed_floor)
	if target_id.is_empty():
		_fail("could not prepare a crossing-floor reveal target")
		return
	flow.call("_resolve_route_target", target_id)
	var reveal_start_elapsed := (
		TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
	)
	flow.set_transition_progress_for_qa(reveal_start_elapsed / _transition_duration_sec())
	flow.update_selective(0.0, canvas)
	if not bool(flow.get_floor_reveal_visual_model().get("active", false)):
		_fail("cloud reveal did not take ownership at the visible-map boundary")
		return
	var covered_image: Image = await _capture(canvas, viewport)
	if not _save(covered_image, output_dir.path_join("cloud_covered.png")):
		_fail("covered cloud capture failed")
		return
	flow.update_selective(1.0, canvas)
	var revealing_image: Image = await _capture(canvas, viewport)
	if not _save(revealing_image, output_dir.path_join("cloud_revealing.png")):
		_fail("revealing cloud capture failed")
		return
	flow.update_selective(0.7, canvas)
	var revealed_capture_saved := false
	var travel_seen := false
	for frame_index in range(18):
		var sequence_image: Image = await _capture(canvas, viewport)
		if not _save(
			sequence_image,
			output_dir.path_join("cloud_to_walk_%02d.png" % frame_index)
		):
			_fail("continuous reveal-to-walk frame %d failed" % frame_index)
			return
		if (
			not revealed_capture_saved
			and not bool(flow.is_floor_reveal_pending())
		):
			if not _save(sequence_image, output_dir.path_join("cloud_revealed.png")):
				_fail("revealed cloud capture failed")
				return
			revealed_capture_saved = true
		travel_seen = travel_seen or float(
			flow.get_map_transition_visual_model().get("travel_progress", 0.0)
		) > 0.0
		flow.update_selective(0.1, canvas)
	if not revealed_capture_saved:
		_fail("continuous sequence never reached the fully revealed state")
		return
	if not travel_seen:
		_fail("continuous sequence never reached walker movement after reveal")
		return
	print("[TowerMapZoomCloudVisualQA] output=%s sequence_frames=18" % output_dir)
	print("tower_map_zoom_cloud_visual_qa: ok")
	flow.call("_finish_vertical_slice")
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	get_root().remove_child(viewport)
	viewport.free()
	canvas = null
	flow = null
	await process_frame
	await process_frame
	quit(0)


func _capture(canvas: CanvasItem, viewport: SubViewport) -> Image:
	canvas.queue_redraw()
	for _frame_index in range(3):
		await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != GAME_SIZE:
		return null
	return image


func _save_and_assert_cover(image: Image, path: String, label: String) -> bool:
	if not _save(image, path):
		_fail("%s zoom capture failed" % label)
		return false
	var counts := _blank_edge_counts(image)
	print(
		"[TowerMapZoomCloudVisualQA] zoom=%s blank_top=%d blank_bottom=%d blank_left=%d blank_right=%d"
		% [label, counts.top, counts.bottom, counts.left, counts.right]
	)
	if int(counts.top) > 0 or int(counts.bottom) > 0 or int(counts.left) > 0 or int(counts.right) > 0:
		_fail("%s zoom exposes paper/border background pixels: %s" % [label, counts])
		return false
	return true


func _blank_edge_counts(image: Image) -> Dictionary:
	var counts := {"top": 0, "bottom": 0, "left": 0, "right": 0}
	for x in range(GAME_SIZE.x):
		if _is_panel_blank(image.get_pixel(x, 0)):
			counts.top = int(counts.top) + 1
		if _is_panel_blank(image.get_pixel(x, GAME_SIZE.y - 1)):
			counts.bottom = int(counts.bottom) + 1
	for y in range(GAME_SIZE.y):
		if _is_panel_blank(image.get_pixel(0, y)):
			counts.left = int(counts.left) + 1
		if _is_panel_blank(image.get_pixel(GAME_SIZE.x - 1, y)):
			counts.right = int(counts.right) + 1
	return counts


func _is_panel_blank(pixel: Color) -> bool:
	for blank_color in PANEL_BLANK_COLORS:
		if (
			absf(pixel.r - blank_color.r) <= PANEL_BLANK_COLOR_EPSILON
			and absf(pixel.g - blank_color.g) <= PANEL_BLANK_COLOR_EPSILON
			and absf(pixel.b - blank_color.b) <= PANEL_BLANK_COLOR_EPSILON
		):
			return true
	return false


func _promote_first_target_to_next_floor(flow: Object, revealed_floor: int) -> String:
	var targets: Array[String] = flow.get_route_target_ids()
	if targets.is_empty():
		return ""
	var target_id := targets[0]
	var node_by_id: Dictionary = flow.get("_graph_node_by_id")
	var node_value: Variant = node_by_id.get(target_id, null)
	if not (node_value is Dictionary):
		return ""
	(node_value as Dictionary)["segment_floor"] = revealed_floor + 1
	return target_id


func _wheel(position: Vector2, zoom_in: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP if zoom_in else MOUSE_BUTTON_WHEEL_DOWN
	event.position = position
	event.factor = 1.0
	event.pressed = true
	return event


func _transition_duration_sec() -> float:
	return (
		TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC
	)


func _save(image: Image, path: String) -> bool:
	return (
		image != null
		and not image.is_empty()
		and image.get_size() == GAME_SIZE
		and image.save_png(path) == OK
	)


func _fail(message: String) -> void:
	if _failure.is_empty():
		_failure = message
	push_error(message)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	quit(1)
