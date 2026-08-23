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
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
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
const SURROUND_COLOR_EPSILON := 0.012

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
	var renderer: Object = flow.get("_renderer")
	var default_model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	if not _save_and_assert_subcover(
		initial_image,
		output_dir.path_join("map_default.png"),
		"map_default",
		default_model
	):
		return
	var cursor := VIEWPORT_RECT.get_center()
	var floor_one_model: Dictionary = default_model
	for _index in range(24):
		if _floor_one_route_is_visible(floor_one_model):
			break
		flow.handle_input(_wheel(cursor, false))
		canvas.queue_redraw()
		await process_frame
		floor_one_model = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	if not _floor_one_route_is_visible(floor_one_model):
		_fail("expanded first-floor route did not fit inside the Vulkan viewport")
		return
	var floor_one_image: Image = await _capture(canvas, viewport)
	if not _save(floor_one_image, output_dir.path_join("floor_one_expanded.png")):
		_fail("expanded first-floor route capture failed")
		return
	print(
		"[TowerMapZoomCloudVisualQA] floor_one_expanded zoom=%.6f rows=%d"
		% [
			float((floor_one_model.get("camera", {}) as Dictionary).get(
				"render_zoom_multiplier",
				0.0
			)),
			_count_floor_one_rows(floor_one_model),
		]
	)
	for _index in range(24):
		flow.handle_input(_wheel(cursor, false))
		canvas.queue_redraw()
		await process_frame
	var fit_all_model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var minimum_image: Image = await _capture(canvas, viewport)
	if not _save_and_assert_subcover(
		minimum_image,
		output_dir.path_join("zoom_fit_all.png"),
		"fit_all",
		fit_all_model
	):
		return
	var fit_all_zoom := float((fit_all_model.get("camera", {}) as Dictionary).get(
		"render_zoom_multiplier",
		0.0
	))
	var cover_zoom := float(fit_all_model.get("minimum_cover_zoom", 0.0))
	var middle_target := lerpf(fit_all_zoom, cover_zoom, 0.5)
	for _index in range(24):
		flow.handle_input(_wheel(cursor, true))
		canvas.queue_redraw()
		await process_frame
		var candidate_model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
		if float((candidate_model.get("camera", {}) as Dictionary).get(
			"render_zoom_multiplier",
			0.0
		)) >= middle_target:
			break
	var middle_model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var middle_image: Image = await _capture(canvas, viewport)
	if not _save_and_assert_subcover(
		middle_image,
		output_dir.path_join("zoom_middle.png"),
		"middle",
		middle_model
	):
		return
	for _index in range(32):
		flow.handle_input(_wheel(cursor, true))
		canvas.queue_redraw()
		await process_frame
	var maximum_image: Image = await _capture(canvas, viewport)
	if not _save_and_assert_cover(maximum_image, output_dir.path_join("zoom_maximum.png"), "maximum"):
		return
	var budget: Dictionary = renderer.get_render_cache_debug_state()
	if int(budget.get("total_map_draw_call_budget", 0)) > TowerAscentTuning.TEMP_MAP_PATH_DRAW_CALL_BUDGET:
		_fail("sub-cover overview exceeded the established dotted/cloud draw-call budget")
		return
	print(
		"[TowerMapZoomCloudVisualQA] fit_all=%.6f cover=%.6f maximum=%.6f world=%s floors=%d draw_calls=%d"
		% [
			fit_all_zoom,
			cover_zoom,
			float(((renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT) as Dictionary).get(
				"camera",
				{}
			) as Dictionary).get("render_zoom_multiplier", 0.0)),
			fit_all_model.get("camera_world_rect", Rect2()),
			(fit_all_model.get("floor_bands", []) as Array).size(),
			int(budget.get("total_map_draw_call_budget", 0)),
		]
	)
	flow.close_map_overlay()
	# Capture the exact production transition states requested by feedback 3:
	# the start of walker travel and the midpoint where the preferred base zoom
	# has been restored halfway by the authoritative transition clock.
	flow = TowerAscentFlowOwner.new()
	canvas.flow = flow
	if not flow.begin_vertical_slice(null, Callable(), {
		"run_id": "tower-map-default-zoom-walk-vulkan",
		"map_seed": 83521,
	}):
		_fail("could not enter walking map for transition zoom captures")
		return
	var motion_targets: Array[String] = flow.get_route_target_ids()
	if motion_targets.is_empty():
		_fail("transition zoom capture fixture has no route target")
		return
	flow.call("_resolve_route_target", motion_targets[0])
	var travel_start_elapsed := (
		TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC
	)
	flow.set_transition_progress_for_qa(travel_start_elapsed / _transition_duration_sec())
	var motion_renderer: Object = flow.get("_renderer")
	var travel_start_model: Dictionary = motion_renderer.build_fullscreen_map_model(
		flow,
		VIEWPORT_RECT
	)
	var travel_start_image: Image = await _capture(canvas, viewport)
	if not _save_and_assert_subcover(
		travel_start_image,
		output_dir.path_join("travel_start.png"),
		"travel_start",
		travel_start_model,
		false
	):
		return
	flow.set_transition_progress_for_qa(
		(travel_start_elapsed + TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC * 0.5)
			/ _transition_duration_sec()
	)
	var travel_mid_model: Dictionary = motion_renderer.build_fullscreen_map_model(
		flow,
		VIEWPORT_RECT
	)
	var travel_mid_image: Image = await _capture(canvas, viewport)
	if not _save_and_assert_subcover(
		travel_mid_image,
		output_dir.path_join("travel_mid.png"),
		"travel_mid",
		travel_mid_model,
		false
	):
		return
	var travel_start_zoom := float((travel_start_model.get("camera", {}) as Dictionary).get(
		"render_zoom_multiplier",
		0.0
	))
	var travel_mid_zoom := float((travel_mid_model.get("camera", {}) as Dictionary).get(
		"render_zoom_multiplier",
		0.0
	))
	if travel_mid_zoom <= travel_start_zoom:
		_fail("travel midpoint must be visibly more zoomed in than travel start")
		return
	print(
		"[TowerMapZoomCloudVisualQA] travel_start=%.6f travel_mid=%.6f"
		% [travel_start_zoom, travel_mid_zoom]
	)
	flow.call("_finish_vertical_slice")
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
	var walking_renderer: Object = flow.get("_renderer")
	var walking_cursor := VIEWPORT_RECT.get_center()
	for _index in range(24):
		flow.handle_input(_wheel(walking_cursor, false))
		canvas.queue_redraw()
		await process_frame
	var walking_subcover_model: Dictionary = walking_renderer.build_fullscreen_map_model(
		flow,
		VIEWPORT_RECT
	)
	var walking_subcover_image: Image = await _capture(canvas, viewport)
	if not _save_and_assert_subcover(
		walking_subcover_image,
		output_dir.path_join("walker_cloud_subcover.png"),
		"walker_cloud_subcover",
		walking_subcover_model,
		false
	):
		return
	# Restore the established walking presentation before recording the existing
	# reveal-to-travel strip. This QA-only reset does not alter runtime ownership.
	(flow.get("_map_drag_state") as Object).reset_surface()
	canvas.queue_redraw()
	await process_frame
	var drift_hashes: Dictionary = {}
	for drift_frame_index in range(8):
		var drift_image: Image = await _capture(canvas, viewport)
		var drift_path := output_dir.path_join(
			"cloud_drift_%02d.png" % drift_frame_index
		)
		if not _save(drift_image, drift_path):
			_fail("continuous cloud drift frame %d failed" % drift_frame_index)
			return
		drift_hashes[FileAccess.get_sha256(drift_path)] = true
		flow.update_selective(0.125, canvas)
	if drift_hashes.size() != 8:
		_fail("all eight continuous drift frames must differ before the reveal completes")
		return
	if not bool(flow.is_floor_reveal_pending()):
		_fail("the eight-frame drift strip must remain inside the two-second reveal")
		return
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
	print("[TowerMapZoomCloudVisualQA] output=%s drift_frames=8 sequence_frames=18" % output_dir)
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


func _floor_one_route_is_visible(model: Dictionary) -> bool:
	var camera: Dictionary = model.get("camera", {})
	var zoom := float(camera.get("render_zoom_multiplier", 0.0))
	var offset: Vector2 = camera.get("offset", Vector2.ZERO)
	var inset_view := VIEWPORT_RECT.grow(-24.0)
	var saw_floor_one := false
	var saw_floor_two_gate := false
	for node_variant in model.get("overview_nodes", model.get("nodes", [])):
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		var belongs_to_route := int(node.get("segment_floor", 0)) == 1
		var is_floor_two_gate := (
			int(node.get("floor", 0)) == 2
			and bool(node.get("gatekeeper", false))
		)
		if not belongs_to_route and not is_floor_two_gate:
			continue
		var screen_position := (
			(node.get("world_position", Vector2.ZERO) as Vector2) * zoom + offset
		)
		if not inset_view.has_point(screen_position):
			return false
		saw_floor_one = saw_floor_one or belongs_to_route
		saw_floor_two_gate = saw_floor_two_gate or is_floor_two_gate
	return saw_floor_one and saw_floor_two_gate


func _count_floor_one_rows(model: Dictionary) -> int:
	var rows: Dictionary = {}
	for node_variant in model.get("overview_nodes", model.get("nodes", [])):
		if node_variant is Dictionary and int(
			(node_variant as Dictionary).get("segment_floor", 0)
		) == 1:
			rows[int((node_variant as Dictionary).get("global_row", -1))] = true
	return rows.size()


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


func _save_and_assert_subcover(
	image: Image,
	path: String,
	label: String,
	model: Dictionary,
	require_all_floors: bool = true
) -> bool:
	if not _save(image, path):
		_fail("%s zoom capture failed" % label)
		return false
	var camera: Dictionary = model.get("camera", {})
	var zoom := float(camera.get("render_zoom_multiplier", 0.0))
	var offset: Vector2 = camera.get("offset", Vector2.ZERO)
	var world_rect: Rect2 = model.get("camera_world_rect", Rect2())
	var projected_world := Rect2(world_rect.position * zoom + offset, world_rect.size * zoom)
	var floor_numbers: Dictionary = {}
	for floor_variant in model.get("floor_bands", []):
		if floor_variant is Dictionary:
			floor_numbers[int((floor_variant as Dictionary).get("floor", 0))] = true
	if require_all_floors and floor_numbers.size() != 12:
		_fail("%s capture does not contain all 12 floor bands" % label)
		return false
	var expected_surround := TowerAscentFlowRenderer.surround_color_for_realm(
		str(model.get("realm_kind", "human_realm"))
	)
	var counts := _outside_edge_counts(image, projected_world, expected_surround)
	print(
		"[TowerMapZoomCloudVisualQA] zoom=%s outside_paper=%d surround_mismatch=%d projected=%s"
		% [label, counts.paper, counts.surround_mismatch, projected_world]
	)
	if int(counts.paper) > 0:
		_fail("%s zoom exposes PAPER-band pixels outside the scroll: %s" % [label, counts])
		return false
	if int(counts.surround_mismatch) > 0:
		_fail("%s zoom outside edge is not the procedural ink surround: %s" % [label, counts])
		return false
	return true


func _outside_edge_counts(
	image: Image,
	projected_world: Rect2,
	expected_surround: Color
) -> Dictionary:
	var counts := {"paper": 0, "surround_mismatch": 0}
	var exposed_edges: Array[Dictionary] = []
	if projected_world.position.x > 0.5:
		exposed_edges.append({"vertical": true, "coordinate": 0})
	if projected_world.end.x < float(GAME_SIZE.x) - 0.5:
		exposed_edges.append({"vertical": true, "coordinate": GAME_SIZE.x - 1})
	if projected_world.position.y > 0.5:
		exposed_edges.append({"vertical": false, "coordinate": 0})
	if projected_world.end.y < float(GAME_SIZE.y) - 0.5:
		exposed_edges.append({"vertical": false, "coordinate": GAME_SIZE.y - 1})
	for edge in exposed_edges:
		var sample_count := GAME_SIZE.y if bool(edge.vertical) else GAME_SIZE.x
		for sample_index in range(sample_count):
			var pixel := (
				image.get_pixel(int(edge.coordinate), sample_index)
				if bool(edge.vertical)
				else image.get_pixel(sample_index, int(edge.coordinate))
			)
			if _is_paper_band(pixel):
				counts.paper = int(counts.paper) + 1
			if not _colors_near(pixel, expected_surround, SURROUND_COLOR_EPSILON):
				counts.surround_mismatch = int(counts.surround_mismatch) + 1
	return counts


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


func _is_paper_band(pixel: Color) -> bool:
	return (
		pixel.r >= 0.82
		and pixel.r <= 0.96
		and pixel.g >= 0.69
		and pixel.g <= 0.90
		and pixel.b >= 0.48
		and pixel.b <= 0.76
	)


func _colors_near(left: Color, right: Color, epsilon: float) -> bool:
	return (
		absf(left.r - right.r) <= epsilon
		and absf(left.g - right.g) <= epsilon
		and absf(left.b - right.b) <= epsilon
	)


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
