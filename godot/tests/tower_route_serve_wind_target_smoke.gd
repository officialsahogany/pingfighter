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
const TowerAscentRouteServeRuntime := preload(
	"res://scripts/tower_ascent/tower_ascent_route_serve_runtime.gd"
)
const TowerAscentRouteWindPolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_route_wind_policy.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

var _failures: Array[String] = []


class FakeRouteDrawFlow:
	extends RefCounted

	var targets: Array[Dictionary] = []

	func get_route_aim_targets() -> Array[Dictionary]:
		return targets

	func get_route_aim_gauge_model() -> Dictionary:
		return {"visible": false}

	func get_route_wind_model() -> Dictionary:
		return TowerAscentRouteWindPolicy.calm_model()


class FakeRouteDrawCanvas:
	extends RefCounted

	var texture_rect_calls := 0
	var drawn_strings: Array[String] = []

	func draw_circle(
		_position: Vector2,
		_radius: float,
		_color: Color,
		_filled: bool = true,
		_width: float = -1.0,
		_antialiased: bool = false
	) -> void:
		pass

	func draw_texture_rect(
		_texture: Texture2D,
		_rect: Rect2,
		_tile: bool,
		_modulate: Color = Color.WHITE,
		_transpose: bool = false
	) -> void:
		texture_rect_calls += 1

	func draw_rect(
		_rect: Rect2,
		_color: Color,
		_filled: bool = true,
		_width: float = -1.0,
		_antialiased: bool = false
	) -> void:
		pass

	func draw_string(
		_font: Font,
		_pos: Vector2,
		_text: String,
		_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
		_width: float = -1.0,
		_font_size: int = 16,
		_modulate: Color = Color.WHITE
	) -> void:
		drawn_strings.append(_text)


func _init() -> void:
	_verify_entry_roll_is_single_and_frame_stable()
	_verify_fixed_seed_distribution()
	_verify_maximum_wind_reachability_and_flight_isolation()
	_verify_route_targets_draw_icons_without_name_strings()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_route_serve_wind_target_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_entry_roll_is_single_and_frame_stable() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	_expect(
		flow.begin_vertical_slice(
			null,
			Callable(),
			{"run_id": "wind-entry-once", "map_seed": 83521}
		),
		"fixture must enter ROUTE_AIM through the production flow owner"
	)
	var wind_at_entry := flow.get_route_wind_model()
	var rng_at_entry: Dictionary = flow.export_snapshot().get("gameplay_rng_state", {})
	_expect(flow.get_route_wind_roll_count() == 1, "route entry must consume one wind roll")
	for _frame in range(180):
		flow.update_selective(1.0 / 60.0)
	_expect(flow.get_route_wind_roll_count() == 1, "180 route frames must not reroll wind")
	_expect(flow.get_route_wind_model() == wind_at_entry, "wind must remain fixed until route selection ends")
	_expect(
		flow.export_snapshot().get("gameplay_rng_state", {}) == rng_at_entry,
		"route frames after entry must not advance the gameplay RNG"
	)
	flow.call("_finish_vertical_slice")


func _verify_fixed_seed_distribution() -> void:
	var rng_state := {"seed": 20260820, "state": 20260820}
	var calm_count := 0
	for _index in range(10000):
		var result := TowerAscentRouteWindPolicy.roll_from_gameplay_state(rng_state)
		rng_state = result.get("gameplay_rng_state", {})
		if not bool((result.get("wind", {}) as Dictionary).get("is_windy", false)):
			calm_count += 1
	var calm_ratio := float(calm_count) / 10000.0
	_expect(
		absf(calm_ratio - TowerAscentRouteWindPolicy.CALM_PROBABILITY) <= 0.02,
		"fixed-seed samples must preserve the declared 60 percent calm interval"
	)
	_expect(
		TowerAscentRouteWindPolicy.is_calm_roll(0.599999)
		and not TowerAscentRouteWindPolicy.is_calm_roll(0.60),
		"the exact 60/40 branch boundary must stay explicit"
	)


func _verify_maximum_wind_reachability_and_flight_isolation() -> void:
	var origin := Vector2(380.0, 665.0)
	var targets := [
		Vector2(TowerAscentTuning.TEMP_ROUTE_TARGET_LEFT_X, TowerAscentTuning.TEMP_ROUTE_TARGET_Y),
		Vector2(TowerAscentTuning.TEMP_ROUTE_TARGET_RIGHT_X, TowerAscentTuning.TEMP_ROUTE_TARGET_Y),
	]
	for direction in [-1, 1]:
		var runtime := TowerAscentRouteServeRuntime.new()
		var maximum_wind := TowerAscentRouteWindPolicy.build_model(int(direction), 3)
		runtime.begin(null, null, maximum_wind)
		var model := runtime.get_aim_gauge_model()
		var minimum_angle := float(model.get("min_degrees", 0.0))
		var maximum_angle := float(model.get("max_degrees", 0.0))
		for target_variant in targets:
			var target := target_variant as Vector2
			var required_angle := rad_to_deg(atan2(
				target.x - origin.x,
				origin.y - target.y
			))
			_expect(
				required_angle >= minimum_angle and required_angle <= maximum_angle,
				"maximum wind must leave both targets inside the shifted sweep"
			)
		runtime.cancel()

	var calm_runtime := TowerAscentRouteServeRuntime.new()
	var windy_runtime := TowerAscentRouteServeRuntime.new()
	calm_runtime.begin(null, null, TowerAscentRouteWindPolicy.calm_model())
	windy_runtime.begin(null, null, TowerAscentRouteWindPolicy.build_model(-1, 3))
	var fixed_aim_point := Vector2(452.0, 120.0)
	calm_runtime.debug_serve_toward(fixed_aim_point)
	windy_runtime.debug_serve_toward(fixed_aim_point)
	var empty_targets: Array[Dictionary] = []
	calm_runtime.update(0.25, empty_targets)
	windy_runtime.update(0.25, empty_targets)
	_expect(
		calm_runtime.get_ball_position().is_equal_approx(windy_runtime.get_ball_position()),
		"equal launch angles must produce identical post-launch positions in wind"
	)
	_expect(
		Vector2(calm_runtime.get("_fixture_ball_velocity")).is_equal_approx(
			Vector2(windy_runtime.get("_fixture_ball_velocity"))
		),
		"equal launch angles must produce identical post-launch velocities in wind"
	)
	calm_runtime.cancel()
	windy_runtime.cancel()


func _verify_route_targets_draw_icons_without_name_strings() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	_expect(
		flow.begin_vertical_slice(
			null,
			Callable(),
			{"run_id": "wind-target-icons", "map_seed": 83521}
		),
		"icon fixture must enter the generated production route"
	)
	var icon_targets: Array[Dictionary] = []
	var icon_labels: Array[String] = []
	for target_variant in flow.get_route_aim_targets():
		var target := target_variant as Dictionary
		var presentation: Dictionary = target.get("icon_presentation", {})
		if presentation.get("icon_texture", null) is Texture2D:
			icon_targets.append(target)
			icon_labels.append(str(target.get("label", "")))
	_expect(not icon_targets.is_empty(), "generated route targets must resolve shared map icons")
	var draw_flow := FakeRouteDrawFlow.new()
	draw_flow.targets = icon_targets
	var canvas := FakeRouteDrawCanvas.new()
	TowerAscentFlowRenderer.new().debug_draw_route_aim(canvas, draw_flow)
	_expect(
		canvas.texture_rect_calls == icon_targets.size(),
		"every icon-backed route target must draw its shared map icon"
	)
	for label in icon_labels:
		_expect(
			not canvas.drawn_strings.has(label),
			"icon-backed route targets must not draw node-name text"
		)
	flow.call("_finish_vertical_slice")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
