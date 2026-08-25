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

const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
const CLICK_JITTER := Vector2(4.0, 0.0)
const LARGE_DRAG := Vector2(100000.0, 100000.0)
const EPSILON := 0.1

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var contract_probe := TowerAscentFlowOwner.new()
	if not _has_drag_contract(contract_probe):
		_expect(false, "S3 RED: Tower flow must expose the map camera drag contract")
	else:
		_verify_click_slop_selects_without_dragging()
		_verify_threshold_crossing_drags_without_selecting()
		_verify_surround_start_and_cover_counterproof()
		_verify_shared_cover_bounds_clamp_all_directions()
		_verify_manual_camera_priority_and_release_retention()
		_verify_event_route_and_hot_path_contracts()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_map_camera_drag_contract_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _has_drag_contract(flow: Object) -> bool:
	for method_name in [
		"get_map_drag_threshold_screen_px",
		"has_map_camera_manual_override",
		"get_map_camera_manual_offset",
		"reanchor_map_camera_manual_offset",
		"get_map_pointer_selected_node_id",
	]:
		if not flow.has_method(method_name):
			return false
	return true


func _verify_click_slop_selects_without_dragging() -> void:
	var fixture := _new_overlay_fixture("map-drag-click")
	if fixture.is_empty():
		return
	var flow: Object = fixture["flow"]
	var renderer: Object = fixture["renderer"]
	var model: Dictionary = fixture["model"]
	var node_probe := _visible_node_probe(model)
	var node_id := str(node_probe.get("id", ""))
	var node_screen_position: Vector2 = node_probe.get("screen_position", Vector2.INF)
	_expect(not node_id.is_empty(), "click fixture must expose a visible node hit target")
	if node_id.is_empty():
		return
	var threshold := float(flow.get_map_drag_threshold_screen_px())
	_expect(is_equal_approx(threshold, 8.0), "map drag threshold must remain the sealed 8 logical screen pixels")
	_expect(CLICK_JITTER.length() < threshold, "click fixture movement must stay below the drag threshold")
	flow.handle_input(_mouse_button(node_screen_position, true))
	flow.handle_input(_mouse_motion(node_screen_position + CLICK_JITTER))
	flow.handle_input(_mouse_button(node_screen_position + CLICK_JITTER, false))
	_expect(
		str(flow.get_map_pointer_selected_node_id()) == node_id,
		"sub-threshold movement must resolve the pressed map node as a click selection"
	)
	_expect(
		not bool(flow.has_map_camera_manual_override()),
		"sub-threshold movement must not arm manual camera control"
	)
	var selected_model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	_expect(
		str(selected_model.get("pointer_selected_node_id", "")) == node_id,
		"the click-selected node must reach the fullscreen presentation model"
	)
	flow.handle_input(_key_event(KEY_ESCAPE))
	_expect(
		str(flow.get_map_pointer_selected_node_id()).is_empty(),
		"closing the M-key surface must clear pointer-only node focus"
	)


func _verify_threshold_crossing_drags_without_selecting() -> void:
	var fixture := _new_overlay_fixture("map-drag-threshold")
	if fixture.is_empty():
		return
	var flow: Object = fixture["flow"]
	var renderer: Object = fixture["renderer"]
	var model: Dictionary = fixture["model"]
	var camera: Dictionary = model.get("camera", {})
	var start_offset: Vector2 = camera.get("offset", Vector2.ZERO)
	var press_position := VIEWPORT_RECT.get_center()
	var drag_delta := Vector2(0.0, float(flow.get_map_drag_threshold_screen_px()) + 4.0)
	flow.handle_input(_mouse_button(press_position, true))
	flow.handle_input(_mouse_motion(press_position + drag_delta))
	flow.handle_input(_mouse_button(press_position + drag_delta, false))
	var dragged_model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var dragged_offset: Vector2 = (dragged_model.get("camera", {}) as Dictionary).get(
		"offset",
		Vector2.ZERO
	)
	_expect(bool(flow.has_map_camera_manual_override()), "movement beyond 8px must arm manual camera control")
	_expect(
		str(flow.get_map_pointer_selected_node_id()).is_empty(),
		"a threshold-crossing drag must execute zero node selections"
	)
	_expect(
		dragged_offset.distance_to(start_offset) >= drag_delta.length() - EPSILON,
		"M-key drag must move the camera by the pointer delta while bounds permit"
	)


func _verify_shared_cover_bounds_clamp_all_directions() -> void:
	var fixture := _new_transition_fixture(
		"map-drag-bounds",
		TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
	)
	if fixture.is_empty():
		return
	var flow: Object = fixture["flow"]
	var renderer: Object = fixture["renderer"]
	var model: Dictionary = fixture["model"]
	var camera: Dictionary = model.get("camera", {})
	_expect(
		float(camera.get("minimum_offset_x", 0.0)) < float(camera.get("maximum_offset_x", 0.0)),
		"walking closeup must expose horizontal drag range"
	)
	_expect(
		float(camera.get("minimum_offset_y", 0.0)) < float(camera.get("maximum_offset_y", 0.0)),
		"walking closeup must expose vertical drag range"
	)
	_assert_bounds_come_from_cover_art(model, "initial walking closeup")
	var press_position := VIEWPORT_RECT.get_center()
	flow.handle_input(_mouse_button(press_position, true))
	flow.handle_input(_mouse_motion(press_position + LARGE_DRAG))
	var maximum_model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var maximum_camera: Dictionary = maximum_model.get("camera", {})
	_expect(bool(maximum_camera.get("at_left_boundary", false)), "dragging content right must stop at the shared left camera boundary")
	_expect(bool(maximum_camera.get("at_upper_boundary", false)), "dragging content down must stop at the shared upper camera boundary")
	_assert_cover(maximum_model, "left/upper drag boundary")

	flow.handle_input(_mouse_motion(press_position - LARGE_DRAG))
	var minimum_model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var minimum_camera: Dictionary = minimum_model.get("camera", {})
	_expect(bool(minimum_camera.get("at_right_boundary", false)), "dragging content left must stop at the shared right camera boundary")
	_expect(bool(minimum_camera.get("at_lower_boundary", false)), "dragging content up must stop at the shared lower camera boundary")
	_assert_cover(minimum_model, "right/lower drag boundary")
	flow.handle_input(_mouse_button(press_position - LARGE_DRAG, false))
	var cache_state: Dictionary = renderer.get_render_cache_debug_state()
	_expect(int(cache_state.get("fullscreen_build_count", 0)) == 1, "drag ticks must reuse one static fullscreen projection")
	_expect(int(cache_state.get("path_build_count", 0)) == 1, "drag ticks must not rebuild dotted routes")
	_expect(
		int(cache_state.get("path_draw_call_budget", 0)) <= TowerAscentTuning.TEMP_MAP_PATH_DRAW_CALL_BUDGET,
		"drag visibility must stay inside the complete dotted-path draw budget"
	)


func _verify_surround_start_and_cover_counterproof() -> void:
	var fixture := _new_transition_fixture("map-drag-surround-start", 0.0)
	if fixture.is_empty():
		return
	var flow: Object = fixture["flow"]
	var renderer: Object = fixture["renderer"]
	var model: Dictionary = fixture["model"]
	var camera: Dictionary = model.get("camera", {})
	var view_rect: Rect2 = camera.get("view_rect", Rect2())
	var world_rect: Rect2 = camera.get("world_rect", Rect2())
	var zoom := float(camera.get("render_zoom_multiplier", 1.0))
	_expect(
		bool(model.get("subcover_active", false)),
		"travel start must retain the four-notch-out surround"
	)
	_expect(
		bool(camera.get("horizontal_world_fits", false)),
		"travel-start surround must fit the world horizontally"
	)
	_expect(
		is_equal_approx(
			float((camera.get("offset", Vector2.ZERO) as Vector2).x),
			view_rect.get_center().x - world_rect.get_center().x * zoom
		),
		"travel-start surround must pin the horizontally fitted world to center"
	)
	_expect(
		float(camera.get("minimum_offset_y", 0.0))
			< float(camera.get("maximum_offset_y", 0.0)),
		"travel-start surround must retain a vertical clamp range"
	)
	var press_position := VIEWPORT_RECT.get_center()
	flow.handle_input(_mouse_button(press_position, true))
	flow.handle_input(_mouse_motion(press_position + Vector2(0.0, LARGE_DRAG.y)))
	var clamped_model: Dictionary = renderer.build_fullscreen_map_model(
		flow,
		VIEWPORT_RECT
	)
	var clamped_camera: Dictionary = clamped_model.get("camera", {})
	_expect(
		bool(clamped_camera.get("at_upper_boundary", false)),
		"travel-start vertical drag must stop at its upper boundary"
	)
	_expect(
		is_equal_approx(
			float((clamped_camera.get("offset", Vector2.ZERO) as Vector2).x),
			view_rect.get_center().x - world_rect.get_center().x * zoom
		),
		"vertical dragging must leave the fitted horizontal axis center-pinned"
	)
	flow.handle_input(_mouse_button(
		press_position + Vector2(0.0, LARGE_DRAG.y),
		false
	))

	var cover_fixture := _new_transition_fixture(
		"map-drag-cover-counterproof",
		TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
	)
	if cover_fixture.is_empty():
		return
	var cover_camera: Dictionary = (cover_fixture["model"] as Dictionary).get(
		"camera",
		{}
	)
	_expect(
		float(cover_camera.get("minimum_offset_x", 0.0))
			< float(cover_camera.get("maximum_offset_x", 0.0)),
		"forcing the production model to cover zoom must reopen horizontal drag range"
	)


func _verify_manual_camera_priority_and_release_retention() -> void:
	var fixture := _new_transition_fixture(
		"map-drag-priority",
		TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC * 0.25
	)
	if fixture.is_empty():
		return
	var flow: Object = fixture["flow"]
	var renderer: Object = fixture["renderer"]
	var model: Dictionary = fixture["model"]
	var press_position := VIEWPORT_RECT.get_center()
	var drag_position := press_position + Vector2(48.0, 72.0)
	flow.handle_input(_mouse_button(press_position, true))
	flow.handle_input(_mouse_motion(drag_position))
	flow.handle_input(_mouse_button(drag_position, false))
	var released_model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var released_camera: Dictionary = released_model.get("camera", {})
	var released_offset: Vector2 = released_camera.get("offset", Vector2.ZERO)
	var released_world_anchor := (
		(released_camera.get("visible_world_rect", Rect2()) as Rect2).get_center()
	)
	var released_focus: Vector2 = released_camera.get("focus_world_position", Vector2.ZERO)

	var later_elapsed := (
		_zoom_end_elapsed_sec()
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC * 0.75
	)
	flow.set_transition_progress_for_qa(later_elapsed / _transition_duration_sec())
	var later_model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var later_camera: Dictionary = later_model.get("camera", {})
	_expect(
		(later_camera.get("focus_world_position", Vector2.ZERO) as Vector2) != released_focus,
		"walking animation must continue advancing while the camera is manually parked"
	)
	var later_offset: Vector2 = later_camera.get("offset", Vector2.INF)
	var later_world_anchor := (
		(later_camera.get("visible_world_rect", Rect2()) as Rect2).get_center()
	)
	_expect(
		later_world_anchor.is_equal_approx(released_world_anchor),
		"manual drag must preserve its released world anchor across automatic zoom"
	)
	_expect(
		not later_offset.is_equal_approx(released_offset),
		"automatic zoom must rewrite the raw offset while preserving its world anchor"
	)
	_expect(bool(flow.has_map_camera_manual_override()), "release must retain manual camera ownership until the surface ends")
	flow.call("_complete_map_transition")
	_expect(
		not bool(flow.has_map_camera_manual_override()),
		"transition completion must restore automatic tracking for the next map surface"
	)


func _verify_event_route_and_hot_path_contracts() -> void:
	var runtime_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_runtime.gd"
	)
	var drag_state_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_map_drag_state.gd"
	)
	_expect(runtime_source.find("InputEventMouseMotion") >= 0, "production Tower flow must consume routed pointer events")
	_expect(runtime_source.find("get_snapshot") < 0, "GRT-019: S3 must not add a shared input snapshot consumer")
	_expect(drag_state_source.find("get_snapshot") < 0, "GRT-019: drag state must stay event-driven")
	_expect(drag_state_source.find("duplicate(") < 0, "GRT-003: pointer motion must not deep-copy state")
	_expect(drag_state_source.find("func _draw") < 0, "GRT-003: drag state must not create a draw-time owner")


func _new_overlay_fixture(run_id: String) -> Dictionary:
	var flow := _new_flow(run_id)
	if flow == null:
		return {}
	flow.handle_input(_key_event(KEY_M))
	_expect(flow.get_phase_name() == "MAP_OVERLAY", "%s must open the M-key map" % run_id)
	var renderer: Object = flow.get("_renderer")
	var model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	return {"flow": flow, "renderer": renderer, "model": model}


func _new_transition_fixture(run_id: String, travel_elapsed_sec: float) -> Dictionary:
	var flow := _new_flow(run_id)
	if flow == null:
		return {}
	var targets: Array[String] = flow.get_route_target_ids()
	_expect(not targets.is_empty(), "%s must expose a route target" % run_id)
	if targets.is_empty():
		return {}
	flow.call("_resolve_route_target", targets[0])
	flow.set_transition_progress_for_qa(
		(_zoom_end_elapsed_sec() + travel_elapsed_sec) / _transition_duration_sec()
	)
	var renderer: Object = flow.get("_renderer")
	var model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	return {"flow": flow, "renderer": renderer, "model": model}


func _new_flow(run_id: String) -> Object:
	var flow := TowerAscentFlowOwner.new()
	_expect(
		flow.begin_vertical_slice(null, Callable(), {
			"run_id": run_id,
			"map_seed": 83521,
		}),
		"%s fixture must begin" % run_id
	)
	return flow


func _visible_node_probe(model: Dictionary) -> Dictionary:
	var camera: Dictionary = model.get("camera", {})
	var zoom := float(camera.get("render_zoom_multiplier", 1.0))
	var offset: Vector2 = camera.get("offset", Vector2.ZERO)
	var view_rect: Rect2 = model.get("camera_view_rect", Rect2())
	for node_variant in model.get("nodes", []):
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		var screen_position := (node.get("world_position", Vector2.ZERO) as Vector2) * zoom + offset
		if view_rect.grow(-80.0).has_point(screen_position):
			return {
				"id": str(node.get("id", "")),
				"screen_position": screen_position,
			}
	return {}


func _assert_bounds_come_from_cover_art(model: Dictionary, label: String) -> void:
	var view_rect: Rect2 = model.get("camera_view_rect", Rect2())
	var world_rect: Rect2 = model.get("camera_world_rect", Rect2())
	var camera: Dictionary = model.get("camera", {})
	var zoom := float(camera.get("render_zoom_multiplier", 1.0))
	_expect(
		is_equal_approx(float(camera.get("minimum_offset_x", INF)), view_rect.end.x - world_rect.end.x * zoom)
			and is_equal_approx(float(camera.get("maximum_offset_x", INF)), view_rect.position.x - world_rect.position.x * zoom)
			and is_equal_approx(float(camera.get("minimum_offset_y", INF)), view_rect.end.y - world_rect.end.y * zoom)
			and is_equal_approx(float(camera.get("maximum_offset_y", INF)), view_rect.position.y - world_rect.position.y * zoom),
		"%s must reuse S2 camera_view_rect/camera_world_rect bounds without a second boundary model" % label
	)


func _assert_cover(model: Dictionary, label: String) -> void:
	var view_rect: Rect2 = model.get("camera_view_rect", Rect2())
	var world_rect: Rect2 = model.get("camera_world_rect", Rect2())
	var camera: Dictionary = model.get("camera", {})
	var zoom := float(camera.get("render_zoom_multiplier", 1.0))
	var offset: Vector2 = camera.get("offset", Vector2.ZERO)
	var projected_world := Rect2(world_rect.position * zoom + offset, world_rect.size * zoom)
	_expect(projected_world.grow(EPSILON).encloses(view_rect), "%s must preserve S2 cover at the drag clamp" % label)
	_assert_bounds_come_from_cover_art(model, label)


func _zoom_end_elapsed_sec() -> float:
	return (
		TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC
	)


func _transition_duration_sec() -> float:
	return (
		_zoom_end_elapsed_sec()
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC
	)


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	return event


func _mouse_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	return event


func _mouse_motion(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
