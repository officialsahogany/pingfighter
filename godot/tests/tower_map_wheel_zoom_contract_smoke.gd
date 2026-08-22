extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentMapCameraModel := preload(
	"res://scripts/tower_ascent/tower_ascent_map_camera_model.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
const EPSILON := 0.15

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_verify_cover_floor_and_derived_ceiling()
	_verify_cursor_anchor_and_surface_reset()
	_verify_random_zoom_node_hit()
	_verify_modal_wheel_exclusion_negative_leg()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_map_wheel_zoom_contract_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_cover_floor_and_derived_ceiling() -> void:
	var fixture := _new_overlay_fixture("wheel-cover")
	if fixture.is_empty():
		return
	var flow: Object = fixture.flow
	var renderer: Object = fixture.renderer
	var cursor := VIEWPORT_RECT.get_center()
	for _index in range(24):
		flow.handle_input(_wheel(cursor, false))
		fixture.model = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var minimum_model: Dictionary = fixture.model
	var minimum_camera: Dictionary = minimum_model.get("camera", {})
	var expected_minimum := TowerAscentMapCameraModel.minimum_cover_zoom(
		minimum_model.get("camera_view_rect", Rect2()),
		minimum_model.get("camera_world_rect", Rect2())
	)
	_expect(
		is_equal_approx(float(minimum_camera.get("render_zoom_multiplier", 0.0)), expected_minimum),
		"wheel-down must clamp exactly at the S2 minimum_cover_zoom authority"
	)
	_assert_cover(minimum_model, "minimum wheel zoom")
	for _index in range(32):
		flow.handle_input(_wheel(cursor, true))
		fixture.model = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var maximum_camera: Dictionary = (fixture.model as Dictionary).get("camera", {})
	_expect(
		is_equal_approx(
			float(maximum_camera.get("render_zoom_multiplier", 0.0)),
			TowerAscentTuning.TEMP_MAP_CAMERA_ZOOM
				* TowerAscentTuning.TEMP_MAP_CAMERA_INTRO_END_MULTIPLIER
		),
		"wheel-up must clamp at the existing production camera maximum, not a new literal"
	)
	_assert_cover(fixture.model, "maximum wheel zoom")


func _verify_cursor_anchor_and_surface_reset() -> void:
	var fixture := _new_transition_fixture("wheel-anchor")
	if fixture.is_empty():
		return
	var flow: Object = fixture.flow
	var renderer: Object = fixture.renderer
	var before_model: Dictionary = fixture.model
	var before_camera: Dictionary = before_model.get("camera", {})
	var cursor := VIEWPORT_RECT.get_center() + Vector2(113.0, -79.0)
	var before_world := (
		cursor - (before_camera.get("offset", Vector2.ZERO) as Vector2)
	) / float(before_camera.get("render_zoom_multiplier", 1.0))
	flow.handle_input(_wheel(cursor, true))
	var after_model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var after_camera: Dictionary = after_model.get("camera", {})
	var after_world := (
		cursor - (after_camera.get("offset", Vector2.ZERO) as Vector2)
	) / float(after_camera.get("render_zoom_multiplier", 1.0))
	_expect(
		before_world.distance_to(after_world) <= EPSILON,
		"cursor-anchored wheel zoom must preserve the world point below the cursor"
	)
	_expect(bool(flow.has_map_camera_manual_zoom_override()), "walking map must accept wheel zoom")
	flow.call("_complete_map_transition")
	_expect(
		not bool(flow.has_map_camera_manual_zoom_override()),
		"reset_surface must reset pan and user zoom together at the surface boundary"
	)


func _verify_random_zoom_node_hit() -> void:
	var fixture := _new_overlay_fixture("wheel-hit")
	if fixture.is_empty():
		return
	var flow: Object = fixture.flow
	var renderer: Object = fixture.renderer
	for cursor in [
		Vector2(411.0, 348.0),
		Vector2(1488.0, 804.0),
		Vector2(955.0, 577.0),
	]:
		flow.handle_input(_wheel(cursor, true))
		fixture.model = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var probe := _visible_node_probe(fixture.model)
	var node_id := str(probe.get("id", ""))
	var screen_position: Vector2 = probe.get("screen_position", Vector2.INF)
	_expect(not node_id.is_empty(), "arbitrary zoom fixture must keep a visible node probe")
	if node_id.is_empty():
		return
	flow.handle_input(_left_button(screen_position, true))
	flow.handle_input(_left_button(screen_position, false))
	_expect(
		str(flow.get_map_pointer_selected_node_id()) == node_id,
		"GRT-022: arbitrary wheel zoom must use the same transform for draw and node hit testing"
	)


func _verify_modal_wheel_exclusion_negative_leg() -> void:
	var fixture := _new_overlay_fixture("wheel-modal-owner")
	if fixture.is_empty():
		return
	var flow: Object = fixture.flow
	var renderer: Object = fixture.renderer
	flow.handle_input(_wheel(VIEWPORT_RECT.get_center(), true))
	renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var zoom_before := float(flow.get_map_camera_manual_zoom_multiplier())
	# Preserve the manual zoom only as a negative-leg sentinel while switching
	# directly to the opaque modal input owner.
	flow.set("_map_overlay_active", false)
	flow.set("_phase", 1)
	var modal_state: Object = flow.get("_node_modal_state")
	var actions: Array[Dictionary] = []
	for index in range(8):
		actions.append({
			"id": "page_action_%d" % index,
			"label": "행동 %d" % index,
			"enabled": true,
		})
	modal_state.open("modal-wheel-probe", "guardian_spring", {}, actions)
	_expect(int(modal_state.get_page_count()) > 1, "modal negative leg must expose multiple pages")
	flow.handle_input(_wheel(VIEWPORT_RECT.get_center(), false))
	_expect(int(modal_state.get_visible_page()) == 1, "modal wheel-down must advance the modal page")
	_expect(
		is_equal_approx(float(flow.get_map_camera_manual_zoom_multiplier()), zoom_before),
		"GRT-019 negative leg: an open modal must leave map zoom unchanged"
	)


func _new_overlay_fixture(run_id: String) -> Dictionary:
	var flow := _new_flow(run_id)
	if flow == null:
		return {}
	flow.handle_input(_key_event(KEY_M))
	var renderer: Object = flow.get("_renderer")
	var model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	return {"flow": flow, "renderer": renderer, "model": model}


func _new_transition_fixture(run_id: String) -> Dictionary:
	var flow := _new_flow(run_id)
	if flow == null:
		return {}
	var targets: Array[String] = flow.get_route_target_ids()
	if targets.is_empty():
		_expect(false, "transition wheel fixture must expose a target")
		return {}
	flow.call("_resolve_route_target", targets[0])
	var renderer: Object = flow.get("_renderer")
	var model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	return {"flow": flow, "renderer": renderer, "model": model}


func _new_flow(run_id: String) -> Object:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": run_id,
		"map_seed": 83521,
	}), "%s must begin" % run_id)
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
		var position := (node.get("world_position", Vector2.ZERO) as Vector2) * zoom + offset
		if view_rect.grow(-72.0).has_point(position):
			return {"id": str(node.get("id", "")), "screen_position": position}
	return {}


func _assert_cover(model: Dictionary, label: String) -> void:
	var view_rect: Rect2 = model.get("camera_view_rect", Rect2())
	var world_rect: Rect2 = model.get("camera_world_rect", Rect2())
	var camera: Dictionary = model.get("camera", {})
	var zoom := float(camera.get("render_zoom_multiplier", 1.0))
	var offset: Vector2 = camera.get("offset", Vector2.ZERO)
	var projected_world := Rect2(world_rect.position * zoom + offset, world_rect.size * zoom)
	_expect(
		projected_world.grow(EPSILON).encloses(view_rect),
		"%s must leave zero uncovered background pixels on all four edges" % label
	)


func _wheel(position: Vector2, zoom_in: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP if zoom_in else MOUSE_BUTTON_WHEEL_DOWN
	event.position = position
	event.factor = 1.0
	event.pressed = true
	return event


func _left_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	return event


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
