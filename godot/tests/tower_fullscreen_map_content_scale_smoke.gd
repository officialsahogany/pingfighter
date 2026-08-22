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

const REPORTED_VIEWPORT := Rect2(Vector2.ZERO, Vector2(3839.0, 2160.0))
const SOURCE_TILE_SIZE := Vector2(692.0, 320.0)
const SOURCE_ART_SIZE := 32.0
const SOURCE_ROUTE_WIDTH := 18.0
const SOURCE_PLAQUE_SIZE := Vector2(184.0, 24.0)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_verify_m_key_content_scale_and_walking_zoom_reverse_leg()
	await _verify_live_viewport_wins_over_fallback()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_fullscreen_map_content_scale_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_m_key_content_scale_and_walking_zoom_reverse_leg() -> void:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "fullscreen-map-content-scale",
		"map_seed": 83521,
	}), "fullscreen-map scale fixture must enter the production Tower flow")
	var renderer := TowerAscentFlowRenderer.new()
	var map_model := renderer.build_fullscreen_map_model(flow, REPORTED_VIEWPORT)
	var content_rect: Rect2 = map_model.get("content_rect", Rect2())
	var world_rect: Rect2 = map_model.get("world_rect", Rect2())
	var map_scale := float(map_model.get("map_scale", 0.0))
	var expected_scale := content_rect.size.x / SOURCE_TILE_SIZE.x
	_expect(is_equal_approx(map_scale, expected_scale), "M-key map must derive one uniform scale from the live content width")
	_expect(is_equal_approx(world_rect.size.x, content_rect.size.x), "M-key scroll world must span the fullscreen content rect instead of staying 692px")
	_expect(is_equal_approx(world_rect.position.x, content_rect.position.x), "scaled M-key scroll world must remain aligned to the content rect")
	_expect((map_model.get("camera", {}) as Dictionary).get("render_zoom_multiplier", 0.0) == 1.0, "M-key overview must keep its separate 1.0 camera path")
	var plaque_size: Vector2 = map_model.get("plaque_size", Vector2.ZERO)
	_expect(plaque_size.is_equal_approx(SOURCE_PLAQUE_SIZE * expected_scale), "floor plaques must follow the same fullscreen map scale")
	_expect(is_equal_approx(float(map_model.get("art_size", 0.0)), SOURCE_ART_SIZE * expected_scale), "node icons must follow the same fullscreen map scale")

	var floor_bands: Array = map_model.get("floor_bands", [])
	_expect(not floor_bands.is_empty(), "scaled map must retain its production floor bands")
	if not floor_bands.is_empty():
		var band_rect: Rect2 = (floor_bands[0] as Dictionary).get("rect", Rect2())
		_expect(band_rect.size.is_equal_approx(SOURCE_TILE_SIZE * expected_scale), "scroll art tiles must preserve their 692:320 aspect ratio under fullscreen scale")
	var brush_width := _first_route_brush_width(map_model.get("edges", []))
	_expect(is_equal_approx(brush_width, SOURCE_ROUTE_WIDTH * expected_scale), "route brush thickness must follow the same fullscreen map scale")

	var target_ids: Array[String] = flow.get_route_target_ids()
	_expect(not target_ids.is_empty(), "walking reverse leg must expose a route target")
	if target_ids.is_empty():
		return
	flow.call("_resolve_route_target", target_ids[0])
	var total := (
		TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC
	)
	flow.set_transition_progress_for_qa(
		(
			TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
			+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
		) / total
	)
	var walking_model := renderer.build_fullscreen_map_model(flow, REPORTED_VIEWPORT)
	var walking_camera: Dictionary = walking_model.get("camera", {})
	_expect(is_equal_approx(float(walking_model.get("map_scale", 0.0)), 1.0), "walking path must retain the approved source-art coordinate scale instead of inheriting M-key expansion")
	_expect(is_equal_approx(float((walking_model.get("world_rect", Rect2()) as Rect2).size.x), SOURCE_TILE_SIZE.x), "walking path must retain the approved 692px source band before camera zoom")
	_expect(is_equal_approx(float(walking_camera.get("render_zoom_multiplier", 0.0)), TowerAscentTuning.TEMP_MAP_CAMERA_ZOOM), "walking transition must preserve its separate 2.15x camera zoom")
	_expect(is_equal_approx(float(walking_model.get("art_size", 0.0)) * TowerAscentTuning.TEMP_MAP_CAMERA_ZOOM, SOURCE_ART_SIZE * TowerAscentTuning.TEMP_MAP_CAMERA_ZOOM), "walking icon scale must preserve the established source-art times 2.15x contract")


func _verify_live_viewport_wins_over_fallback() -> void:
	var canvas := Node2D.new()
	get_root().add_child(canvas)
	await process_frame
	var fallback := Rect2(Vector2.ZERO, Vector2(760.0, 750.0))
	var resolved := TowerAscentFlowRenderer.new().resolve_fullscreen_rect(canvas, fallback)
	_expect(resolved == canvas.get_viewport_rect(), "GRT-044: in-tree fullscreen map must use canvas.get_viewport_rect()")
	_expect(resolved != fallback, "GRT-044: live viewport must not degrade to the playfield fallback")
	get_root().remove_child(canvas)
	canvas.free()


func _first_route_brush_width(edges_value: Variant) -> float:
	var edges: Array = edges_value if edges_value is Array else []
	for edge_value in edges:
		if not (edge_value is Dictionary):
			continue
		var quads: Array = (edge_value as Dictionary).get("brush_quads", [])
		if not quads.is_empty() and quads[0] is Dictionary:
			return float((quads[0] as Dictionary).get("target_width", 0.0))
	return 0.0


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
