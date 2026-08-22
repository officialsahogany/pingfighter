extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentMapCameraModel := preload(
	"res://scripts/tower_ascent/tower_ascent_map_camera_model.gd"
)
const TowerAscentScreenSpaceSurfacePolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_screen_space_surface_policy.gd"
)
const TowerAscentTransitionFadeState := preload(
	"res://scripts/tower_ascent/tower_ascent_transition_fade_state.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const PHYSICS_HZ := 72
const PHYSICS_DELTA_SEC := 1.0 / float(PHYSICS_HZ)
const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
const ZOOM_BOUNDARY_SCALE_EPSILON := 0.0002
const ZOOM_BOUNDARY_CENTER_EPSILON_PX := 0.25

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_verify_exact_physics_tick_window()
	_verify_monotonic_transition_clock()
	_verify_intro_owns_screen_space_map_pass()
	_verify_production_zoom_handoff()
	_verify_zoomed_top_boundary()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_map_walker_zoom_intro_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_exact_physics_tick_window() -> void:
	_expect(
		is_equal_approx(
			TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC,
			60.0 / 60.0
		),
		"intro duration must keep the repository's 60.0 / 60.0 authoring convention"
	)
	var timeline := TowerAscentTransitionFadeState.new()
	timeline.begin_map_transition()
	var total := timeline.get_map_transition_duration_sec()
	timeline.set_map_transition_progress_for_qa(_zoom_start_elapsed_sec() / total)
	_expect(
		str(timeline.get_map_transition_visual_model().get("segment", ""))
			== TowerAscentTransitionFadeState.SEGMENT_CAMERA_ZOOM_IN,
		"zoom tick fixture must begin at the 2-b segment boundary"
	)
	var zoom_ticks := 0
	while (
		str(timeline.get_map_transition_visual_model().get("segment", ""))
			== TowerAscentTransitionFadeState.SEGMENT_CAMERA_ZOOM_IN
		and zoom_ticks < PHYSICS_HZ + 2
	):
		timeline.update_map_transition(PHYSICS_DELTA_SEC)
		zoom_ticks += 1
	_expect(zoom_ticks == PHYSICS_HZ, "one authored second must occupy exactly 72 production physics ticks")
	var handoff_model: Dictionary = timeline.get_map_transition_visual_model()
	_expect(str(handoff_model.get("segment", "")) == TowerAscentTransitionFadeState.SEGMENT_TRAVEL, "tick 72 must hand the intro directly to walker travel")
	_expect(is_zero_approx(float(handoff_model.get("travel_progress", -1.0))), "tick-72 handoff must begin travel at zero path progress")


func _verify_monotonic_transition_clock() -> void:
	var timeline := TowerAscentTransitionFadeState.new()
	timeline.begin_map_transition()
	var previous_progress := timeline.get_map_transition_progress()
	var previous_segment_order := -1
	var physics_ticks := 0
	while physics_ticks < 400:
		var finished := timeline.update_map_transition(PHYSICS_DELTA_SEC)
		physics_ticks += 1
		var model: Dictionary = timeline.get_map_transition_visual_model()
		var progress := float(model.get("progress", -1.0))
		var segment_order := _segment_order(str(model.get("segment", "")))
		_expect(progress + 0.0000001 >= previous_progress, "overall MAP_TRANSITION progress must never reverse")
		_expect(segment_order >= previous_segment_order, "the six visual beats plus 2-b must remain ordered")
		previous_progress = progress
		previous_segment_order = segment_order
		if finished:
			break
	var expected_ticks := ceili(timeline.get_map_transition_duration_sec() * float(PHYSICS_HZ))
	_expect(physics_ticks == expected_ticks, "the additive transition must complete on the first 72 Hz tick at or beyond 3.73 seconds")
	_expect(is_equal_approx(previous_progress, 1.0), "the monotonic clock must finish at progress 1")


func _verify_intro_owns_screen_space_map_pass() -> void:
	var visual_model := {"segment": TowerAscentTransitionFadeState.SEGMENT_CAMERA_ZOOM_IN}
	_expect(
		TowerAscentScreenSpaceSurfacePolicy.uses_screen_space_flow_phase(
			"MAP_TRANSITION",
			visual_model
		),
		"camera intro must draw the fullscreen map instead of falling back to battle"
	)
	_expect(
		not TowerAscentScreenSpaceSurfacePolicy.uses_playfield_flow_phase(
			"MAP_TRANSITION",
			visual_model
		),
		"camera intro must not double-render in the transformed playfield pass"
	)
	_expect(
		not TowerAscentScreenSpaceSurfacePolicy.transition_keeps_battle_visible(
			"MAP_TRANSITION",
			visual_model
		),
		"only battle fade-out may keep the battle surface visible"
	)


func _verify_production_zoom_handoff() -> void:
	var flow := _new_flow("walker-zoom-production", 83521)
	var renderer := TowerAscentFlowRenderer.new()
	var static_model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	_expect(is_equal_approx(float((static_model.get("camera", {}) as Dictionary).get("zoom_multiplier", 0.0)), 1.0), "non-transition map viewing must preserve the v1.13 camera crop")
	var targets: Array[String] = flow.get_route_target_ids()
	_expect(not targets.is_empty(), "production intro fixture must expose a route target")
	if targets.is_empty():
		return
	var target_id := targets[0]
	flow.call("_resolve_route_target", target_id)
	var total := _transition_duration_sec()
	var zoom_end := _zoom_start_elapsed_sec() + TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC
	var last_zoom := _model_at_elapsed(flow, renderer, zoom_end - PHYSICS_DELTA_SEC, total)
	var boundary := _model_at_elapsed(flow, renderer, zoom_end, total)
	var first_travel := _model_at_elapsed(flow, renderer, zoom_end + PHYSICS_DELTA_SEC, total)
	var last_camera: Dictionary = last_zoom.get("camera", {})
	var boundary_camera: Dictionary = boundary.get("camera", {})
	var first_camera: Dictionary = first_travel.get("camera", {})
	_expect(is_equal_approx(float(boundary_camera.get("zoom_multiplier", 0.0)), TowerAscentTuning.TEMP_MAP_CAMERA_INTRO_END_MULTIPLIER), "travel must inherit the final 1.18x intro multiplier")
	_expect(absf(float(boundary_camera.get("zoom_multiplier", 0.0)) - float(last_camera.get("zoom_multiplier", 0.0))) <= ZOOM_BOUNDARY_SCALE_EPSILON, "last intro frame and travel boundary must be scale-continuous")
	var last_focus: Vector2 = last_camera.get("focus_screen_position", Vector2.ZERO)
	var boundary_focus: Vector2 = boundary_camera.get("focus_screen_position", Vector2.ZERO)
	var first_focus: Vector2 = first_camera.get("focus_screen_position", Vector2.ZERO)
	_expect(last_focus.distance_to(boundary_focus) <= ZOOM_BOUNDARY_CENTER_EPSILON_PX, "last intro frame and travel boundary must be center-continuous")
	_expect(boundary_focus.distance_to(first_focus) <= ZOOM_BOUNDARY_CENTER_EPSILON_PX, "first walker tick must inherit the intro camera center")
	var boundary_marker: Dictionary = boundary.get("transition_marker", {})
	var first_marker: Dictionary = first_travel.get("transition_marker", {})
	var transition_path_build_count := int(
		renderer.get_render_cache_debug_state().get("path_build_count", 0)
	)
	_expect(is_zero_approx(float(boundary_marker.get("progress", -1.0))) and float(first_marker.get("progress", 0.0)) > 0.0, "walker motion must begin strictly after intro completion")
	_expect((boundary_marker.get("world_position", Vector2.ZERO) as Vector2).is_equal_approx(boundary_camera.get("focus_world_position", Vector2.ONE)), "zoom boundary camera must focus the stationary walker")
	_expect((first_marker.get("world_position", Vector2.ZERO) as Vector2).is_equal_approx(first_camera.get("focus_world_position", Vector2.ONE)), "travel camera must follow the same curve sample as the walker")
	var target_position: Vector2 = (boundary.get("position_by_id", {}) as Dictionary).get(target_id, Vector2.INF)
	_expect((boundary_camera.get("visible_world_rect", Rect2()) as Rect2).has_point(target_position), "the 2.537x effective crop must retain the next destination")
	_expect((boundary.get("content_rect", Rect2()) as Rect2).grow(-1.0).has_point(boundary_focus), "lower-boundary walker must remain on screen after intro zoom")
	_expect(bool(boundary_camera.get("at_lower_boundary", false)), "intro zoom must retain the bottom-floor clamp")
	_model_at_elapsed(
		flow,
		renderer,
		zoom_end + PHYSICS_DELTA_SEC * 2.0,
		total
	)
	_expect(int(renderer.get_render_cache_debug_state().get("path_build_count", 0)) == transition_path_build_count, "intro and travel ticks must not rebuild cached dotted paths")


func _verify_zoomed_top_boundary() -> void:
	var flow := _new_flow("walker-zoom-top", 83521)
	var top_id := _node_id_for_floor(flow, 9)
	var route_targets: Array[String] = flow.get_route_target_ids()
	if not route_targets.is_empty():
		flow.call("_resolve_route_target", route_targets[0])
	flow.set("_current_node_id", top_id)
	var renderer := TowerAscentFlowRenderer.new()
	var model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var focus: Vector2 = (model.get("position_by_id", {}) as Dictionary).get(top_id, Vector2.ZERO)
	var camera := TowerAscentMapCameraModel.build(
		model.get("content_rect", Rect2()),
		model.get("world_rect", Rect2()),
		focus,
		float(model.get("art_size", 0.0)) * TowerAscentTuning.TEMP_MAP_CAMERA_BOUNDARY_ART_PADDING_RATIO,
		TowerAscentTuning.TEMP_MAP_CAMERA_FOCUS_Y_RATIO,
		TowerAscentTuning.TEMP_MAP_CAMERA_INTRO_END_MULTIPLIER,
		1.0
	)
	_expect(bool(camera.get("at_upper_boundary", false)), "zoomed camera must retain the top-floor clamp")
	_expect((model.get("content_rect", Rect2()) as Rect2).grow(-1.0).has_point(camera.get("focus_screen_position", Vector2.ZERO)), "zoomed top-floor walker must remain on screen")


func _model_at_elapsed(
	flow: Object,
	renderer: Object,
	elapsed_sec: float,
	total_sec: float
) -> Dictionary:
	flow.set_transition_progress_for_qa(elapsed_sec / total_sec)
	return renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)


func _new_flow(run_id: String, map_seed: int) -> Object:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": run_id,
		"map_seed": map_seed,
	}), "%s fixture must begin" % run_id)
	return flow


func _node_id_for_floor(flow: Object, floor_number: int) -> String:
	for node_variant in flow.get_graph_nodes():
		if node_variant is Dictionary and int((node_variant as Dictionary).get("floor", 0)) == floor_number:
			return str((node_variant as Dictionary).get("id", ""))
	return ""


func _zoom_start_elapsed_sec() -> float:
	return (
		TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
	)


func _transition_duration_sec() -> float:
	return (
		_zoom_start_elapsed_sec()
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC
	)


func _segment_order(segment: String) -> int:
	return [
		TowerAscentTransitionFadeState.SEGMENT_BATTLE_FADE_OUT,
		TowerAscentTransitionFadeState.SEGMENT_MAP_FADE_IN,
		TowerAscentTransitionFadeState.SEGMENT_CAMERA_ZOOM_IN,
		TowerAscentTransitionFadeState.SEGMENT_TRAVEL,
		TowerAscentTransitionFadeState.SEGMENT_ARRIVE_VANISH,
		TowerAscentTransitionFadeState.SEGMENT_MAP_FADE_OUT,
	].find(segment)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
