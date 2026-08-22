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
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const FULLSCREEN_RECT := Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
const REVERSE_RECT := Rect2(Vector2.ZERO, Vector2(760.0, 750.0))
const EPSILON := 0.1

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_verify_m_key_cover_and_r10_width_contract()
	_verify_walking_minimum_and_closeup_cover()
	_verify_reverse_viewport_derives_a_distinct_floor()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_fullscreen_map_cover_contract_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_m_key_cover_and_r10_width_contract() -> void:
	var flow := _new_flow("cover-m-key")
	var model: Dictionary = TowerAscentFlowRenderer.new().build_fullscreen_map_model(
		flow,
		FULLSCREEN_RECT
	)
	_expect(
		is_equal_approx(
			float((model.get("world_rect", Rect2()) as Rect2).size.x),
			float((model.get("content_rect", Rect2()) as Rect2).size.x)
		),
		"R10-2: M-key scroll world must retain its content-width scaling"
	)
	_assert_cover(model, FULLSCREEN_RECT, "M-key minimum zoom")


func _verify_walking_minimum_and_closeup_cover() -> void:
	var flow := _new_flow("cover-walking")
	var targets: Array[String] = flow.get_route_target_ids()
	_expect(not targets.is_empty(), "walking cover fixture must expose a route target")
	if targets.is_empty():
		return
	flow.call("_resolve_route_target", targets[0])
	var renderer := TowerAscentFlowRenderer.new()
	var zoom_start_elapsed := (
		TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
	)
	var zoom_end_elapsed := (
		zoom_start_elapsed + TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC
	)
	var total := _transition_duration_sec()
	flow.set_transition_progress_for_qa(zoom_start_elapsed / total)
	var minimum_model: Dictionary = renderer.build_fullscreen_map_model(flow, FULLSCREEN_RECT)
	_assert_cover(minimum_model, FULLSCREEN_RECT, "walking minimum zoom")
	flow.set_transition_progress_for_qa(zoom_end_elapsed / total)
	var closeup_model: Dictionary = renderer.build_fullscreen_map_model(flow, FULLSCREEN_RECT)
	_assert_cover(closeup_model, FULLSCREEN_RECT, "walking closeup zoom")
	var minimum_camera: Dictionary = minimum_model.get("camera", {})
	var closeup_camera: Dictionary = closeup_model.get("camera", {})
	_expect(
		float(closeup_camera.get("render_zoom_multiplier", 0.0))
			> float(minimum_camera.get("render_zoom_multiplier", INF)),
		"walking maximum zoom must be a closeup relative to the cover floor"
	)


func _verify_reverse_viewport_derives_a_distinct_floor() -> void:
	var flow := _new_flow("cover-reverse")
	var renderer := TowerAscentFlowRenderer.new()
	var fullscreen_model := renderer.build_fullscreen_map_model(flow, FULLSCREEN_RECT)
	var reverse_model := renderer.build_fullscreen_map_model(flow, REVERSE_RECT)
	_assert_cover(reverse_model, REVERSE_RECT, "reverse viewport")
	_expect(
		not is_equal_approx(
			float(fullscreen_model.get("minimum_cover_zoom", 0.0)),
			float(reverse_model.get("minimum_cover_zoom", 0.0))
		),
		"cover floor must be derived from each viewport instead of a fixed literal"
	)


func _assert_cover(model: Dictionary, expected_view: Rect2, label: String) -> void:
	var camera_view_rect: Rect2 = model.get("camera_view_rect", Rect2())
	var camera_world_rect: Rect2 = model.get("camera_world_rect", Rect2())
	var camera: Dictionary = model.get("camera", {})
	var zoom := float(camera.get("render_zoom_multiplier", 0.0))
	var offset: Vector2 = camera.get("offset", Vector2.INF)
	var expected_floor := maxf(
		expected_view.size.x / maxf(0.001, camera_world_rect.size.x),
		expected_view.size.y / maxf(0.001, camera_world_rect.size.y)
	)
	var projected_world := Rect2(
		camera_world_rect.position * zoom + offset,
		camera_world_rect.size * zoom
	)
	_expect(camera_view_rect == expected_view, "%s must target the full screen rect" % label)
	_expect(
		is_equal_approx(float(model.get("minimum_cover_zoom", 0.0)), expected_floor),
		"%s must derive its floor with max(view/world) cover math" % label
	)
	_expect(zoom + EPSILON >= expected_floor, "%s must never fall below its cover floor" % label)
	_expect(
		projected_world.grow(EPSILON).encloses(expected_view),
		"%s must project map art across every screen edge" % label
	)


func _new_flow(run_id: String) -> Object:
	var flow := TowerAscentFlowOwner.new()
	_expect(
		flow.begin_vertical_slice(null, Callable(), {
			"run_id": run_id,
			"map_seed": 83521,
		}),
		"%s fixture must enter the production Tower flow" % run_id
	)
	return flow


func _transition_duration_sec() -> float:
	return (
		TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
