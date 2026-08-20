extends SceneTree

const BallMotionStepper := preload("res://scripts/ball/ball_motion_stepper.gd")
const BallPhysics := preload("res://scripts/ball/ball_physics.gd")
const PaddleBounceState := preload("res://scripts/ball/paddle_bounce_state.gd")
const BattleSceneOwnerReader := preload(
	"res://scripts/core/battle_scene_owner_reader.gd"
)
const BattleSceneShell := preload("res://scripts/core/battle_scene_shell.gd")
const BattleSceneFrameController := preload(
	"res://scripts/core/battle_scene_frame_controller.gd"
)
const BattleScenePlayerControlConfigBuilder := preload(
	"res://scripts/core/battle_scene_player_control_config_builder.gd"
)
const ServeFlowController := preload("res://scripts/core/serve_flow_controller.gd")
const TowerAscentRouteServeRuntime := preload(
	"res://scripts/tower_ascent/tower_ascent_route_serve_runtime.gd"
)
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
const TowerAscentRouteWindPolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_route_wind_policy.gd"
)
const PHYSICS_GATE_COORDINATOR_PATH := (
	"res://scripts/core/battle_physics_gate_coordinator.gd"
)

var _failures: Array[String] = []
var _legacy_serve_calls := 0


class FakeOwner:
	extends Node

	var current_stage := 4
	var selected_character_type := "smasher"
	var player_pos := Vector2(250.0, 700.0)
	var player_speed := 0.0
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var gameplay_frame_counter := 0
	var ball_pos := Vector2(380.0, 665.0)
	var ball_vel := Vector2.ZERO
	var ball_active := false
	var ball_size := 28.6
	var ball_impact_boost := 1.0
	var player_score := 7
	var boss_score := 3
	var boss_ai_ticks := 0
	var combat_rng_state := 44123
	var cooldown_seconds := 2.5
	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class FakeRoundState:
	extends RefCounted

	var waiting := true
	var player_serves := false
	var reset_calls := 0

	func is_waiting_for_serve() -> bool:
		return waiting

	func set_player_serves(value: bool) -> void:
		player_serves = value

	func reset_round_wait() -> void:
		waiting = true
		reset_calls += 1


class FakeServeFlow:
	extends RefCounted

	var sync_calls := 0
	var update_calls := 0
	var trace: Array[String] = []

	func sync_current_input_state() -> void:
		sync_calls += 1

	func update(
		_delta: float,
		_context: Dictionary,
		_deps: Dictionary,
		callbacks: Dictionary
	) -> void:
		update_calls += 1
		trace.append("serve_trigger")
		var serve_callback: Callable = callbacks.get("serve_ball", Callable())
		if serve_callback.is_valid():
			serve_callback.call()


class LegacyAutoRoundState:
	extends RefCounted

	var waiting := true
	var player_serves := true
	var wait_seconds := 0.0

	func is_waiting_for_serve() -> bool:
		return waiting

	func does_player_serve() -> bool:
		return player_serves

	func update_waiting(delta: float, target_delay: float) -> bool:
		wait_seconds += maxf(0.0, delta)
		return wait_seconds >= target_delay


class FakeBallDriver:
	extends RefCounted

	var round_state: FakeRoundState
	var velocities: Array[Vector2] = []
	var reset_calls := 0
	var serve_calls := 0
	var trace: Array[String] = []

	func _init(state: FakeRoundState) -> void:
		round_state = state

	func reset_ball(owner: Object, _registry: Object) -> void:
		reset_calls += 1
		owner.ball_pos = Vector2(380.0, 665.0)
		owner.ball_vel = Vector2.ZERO
		owner.ball_active = false

	func serve_ball(owner: Object, _registry: Object) -> void:
		serve_calls += 1
		trace.append("serve_ball")
		round_state.waiting = false
		owner.ball_pos = Vector2(380.0, 665.0)
		owner.ball_vel = velocities.pop_front() if not velocities.is_empty() else Vector2(0.0, -8.7)
		owner.ball_active = true


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var reads: Array[String] = []

	func get_instance(key: String) -> Variant:
		reads.append(key)
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		return instances.get(key, null)


class FakeInputReader:
	extends RefCounted

	var snapshot := {
		"left_pressed": false,
		"right_pressed": true,
		"direction": 1.0,
		"action_pressed": true,
		"action_just_pressed": true,
		"mouse_left_just_pressed": true,
	}
	var snapshot_calls := 0
	var trace: Array[String] = []
	var derive_mouse_edge_from_pressed := false
	var _previous_mouse_left_pressed := false

	func set_mouse_left_pressed(pressed: bool) -> void:
		snapshot["mouse_left_pressed"] = pressed

	func get_snapshot() -> Dictionary:
		snapshot_calls += 1
		trace.append("input_snapshot")
		var result := snapshot.duplicate(true)
		if derive_mouse_edge_from_pressed:
			var current_pressed := bool(snapshot.get("mouse_left_pressed", false))
			result["mouse_left_just_pressed"] = (
				current_pressed and not _previous_mouse_left_pressed
			)
			_previous_mouse_left_pressed = current_pressed
		return result


class FakeMovementState:
	extends RefCounted

	var update_calls := 0
	var trace: Array[String] = []

	func update_horizontal(
		delta: float,
		player_pos: Vector2,
		player_speed: float,
		direction: float,
		play_left: float,
		play_right: float,
		paddle_width: float,
		_config: Dictionary = {}
	) -> Dictionary:
		update_calls += 1
		trace.append("player_movement")
		var next_speed := direction * 6.0
		var next_pos := player_pos + Vector2(next_speed * delta * 60.0, 0.0)
		next_pos.x = clampf(next_pos.x, play_left, play_right - paddle_width)
		return {"player_pos": next_pos, "player_speed": next_speed}


class FakePlayerControlContext:
	extends RefCounted

	func build_player_control_config(_character_type: String = "smasher") -> Dictionary:
		return {
			"play_left": 0.0,
			"play_right": 760.0,
			"paddle_width": 155.0,
			"paddle_speed": 6.0,
			"paddle_max_speed": 6.0,
			"paddle_accel": 0.5,
			"paddle_decel": 0.5,
			"paddle_turn_decel": 1.0,
		}


class FakeMotionStepper:
	extends RefCounted

	var inner: Object = BallMotionStepper.new()
	var trace: Array[String] = []

	func step(
		ball_pos: Vector2,
		movement: Vector2,
		ball_vel: Vector2,
		context: Dictionary
	) -> Dictionary:
		trace.append("ball_step")
		return inner.step(ball_pos, movement, ball_vel, context)


class FakeModalRuntime:
	extends RefCounted

	func _capture_resume_pre_choice_velocity(_owner: Object) -> void:
		pass

	func _pause_skill_cooldowns_for_choice(_owner: Object, _registry: Object) -> void:
		pass

	func _resume_skill_cooldowns_for_choice() -> void:
		pass

	func _try_arm_resume_safety(_owner: Object, _registry: Object) -> void:
		pass


class FakeReadiness:
	extends RefCounted

	func is_logo_intro_active(_module_getter: Callable) -> bool:
		return false

	func is_boot_warmup_finished(_module_getter: Callable) -> bool:
		return true

	func is_stage_landing_intro_active(_module_getter: Callable) -> bool:
		return false

	func is_ball_spawn_intro_active(_module_getter: Callable) -> bool:
		return false


class FakeTransition:
	extends RefCounted

	func is_stage_transition_loading_active() -> bool:
		return false


class FakeScreen:
	extends RefCounted

	func is_active() -> bool:
		return false

	func blocks_battle_physics() -> bool:
		return false


class FakeGrip:
	extends RefCounted

	func update(
		_delta: float,
		_owner: Object,
		_registry: Object,
		_module_getter: Callable
	) -> bool:
		return false

	func is_active() -> bool:
		return false


class FakeModalGate:
	extends RefCounted

	func should_block_battle_physics_with_perf(
		_module_getter: Callable,
		_perf_logger: Object = null
	) -> bool:
		return false


class FakeModalPause:
	extends RefCounted

	var enter_calls := 0

	func enter_modal_block(
		_owner: Object,
		_registry: Object,
		_module_getter: Callable
	) -> void:
		enter_calls += 1

	func leave_modal_block(
		_owner: Object,
		_registry: Object,
		_module_getter: Callable
	) -> void:
		pass


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Variant:
		return modules.get(key, null)


class FakeGaugeFlow:
	extends RefCounted

	var model := {
		"visible": true,
		"origin": Vector2(380.0, 650.0),
		"min_degrees": -55.0,
		"max_degrees": 55.0,
		"angle_degrees": 23.0,
	}

	func get_route_aim_gauge_model() -> Dictionary:
		return model


class FakeGaugeCanvas:
	extends RefCounted

	var texture_rect_calls := 0
	var texture_polygon_calls := 0
	var colored_polygon_calls := 0
	var arc_calls := 0
	var line_calls := 0
	var circle_calls := 0
	var last_uvs := PackedVector2Array()

	func draw_texture_rect(
		_texture: Texture2D,
		_rect: Rect2,
		_tile: bool,
		_modulate: Color = Color.WHITE,
		_transpose: bool = false
	) -> void:
		texture_rect_calls += 1

	func draw_polygon(
		_points: PackedVector2Array,
		_colors: PackedColorArray,
		uvs: PackedVector2Array = PackedVector2Array(),
		texture: Texture2D = null
	) -> void:
		if texture != null:
			texture_polygon_calls += 1
		last_uvs = uvs

	func draw_colored_polygon(
		_points: PackedVector2Array,
		_color: Color,
		_uvs: PackedVector2Array = PackedVector2Array(),
		_texture: Texture2D = null
	) -> void:
		colored_polygon_calls += 1

	func draw_arc(
		_center: Vector2,
		_radius: float,
		_start_angle: float,
		_end_angle: float,
		_point_count: int,
		_color: Color,
		_width: float = -1.0,
		_antialiased: bool = false
	) -> void:
		arc_calls += 1

	func draw_line(
		_from: Vector2,
		_to: Vector2,
		_color: Color,
		_width: float = -1.0,
		_antialiased: bool = false
	) -> void:
		line_calls += 1

	func draw_circle(
		_position: Vector2,
		_radius: float,
		_color: Color,
		_filled: bool = true,
		_width: float = -1.0,
		_antialiased: bool = false
	) -> void:
		circle_calls += 1


class FakeRouteAimFlow:
	extends RefCounted

	var targets: Array[Dictionary] = []

	func get_route_aim_targets() -> Array[Dictionary]:
		return targets

	func get_route_aim_gauge_model() -> Dictionary:
		return {"visible": false}


class FakeRouteAimCanvas:
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


class FakeWindCanvas:
	extends RefCounted

	var rect_calls := 0
	var filled_strength_cells := 0
	var line_calls := 0
	var circle_calls := 0
	var polygon_calls := 0

	func draw_rect(
		_rect: Rect2,
		_color: Color,
		_filled: bool = true,
		_width: float = -1.0,
		_antialiased: bool = false
	) -> void:
		rect_calls += 1
		if _filled and _rect.size == TowerAscentTuning.TEMP_ROUTE_WIND_STRENGTH_CELL_SIZE:
			filled_strength_cells += 1

	func draw_line(
		_from: Vector2,
		_to: Vector2,
		_color: Color,
		_width: float = -1.0,
		_antialiased: bool = false
	) -> void:
		line_calls += 1

	func draw_circle(
		_position: Vector2,
		_radius: float,
		_color: Color,
		_filled: bool = true,
		_width: float = -1.0,
		_antialiased: bool = false
	) -> void:
		circle_calls += 1

	func draw_colored_polygon(
		_points: PackedVector2Array,
		_color: Color,
		_uvs: PackedVector2Array = PackedVector2Array(),
		_texture: Texture2D = null
	) -> void:
		polygon_calls += 1


func _init() -> void:
	_verify_route_target_uses_map_icon_without_name_text()
	_verify_route_wind_probability_and_strength_table()
	_verify_route_wind_indicator_calm_and_directional_states()
	_verify_wind_bias_reachability_and_trajectory_isolation()
	_verify_live_shell_meta_owner_frame_path()
	_verify_physics_gate_frame_path_moves_serves_and_hits()
	_verify_free_movement_while_waiting_and_in_flight()
	_verify_top_wall_and_player_paddle_round_trip()
	_verify_real_serve_owner_and_unlimited_retry()
	_verify_route_wait_never_auto_serves_and_legacy_still_does()
	_verify_entry_arm_discards_held_click_and_preserves_phase()
	_verify_oscillating_gauge_and_mouse_timed_serve()
	_verify_generated_gauge_art_draws_and_fallback()
	_verify_production_owner_fails_closed_without_serve_dependencies()
	_verify_production_source_uses_serve_contract_without_aim_input()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_route_serve_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_route_wind_probability_and_strength_table() -> void:
	_expect(
		TowerAscentRouteWindPolicy.is_calm_roll(0.599999),
		"the calm branch must own the lower 60 percent interval"
	)
	_expect(
		not TowerAscentRouteWindPolicy.is_calm_roll(0.60),
		"the wind branch must begin at the 40 percent interval boundary"
	)
	var strength_table := TowerAscentRouteWindPolicy.get_strength_table()
	_expect(strength_table.size() == 3, "route wind must use three discrete readable strength levels")
	for level in range(1, 4):
		var left := TowerAscentRouteWindPolicy.build_model(-1, level)
		var right := TowerAscentRouteWindPolicy.build_model(1, level)
		_expect(
			int(left.get("strength_level", 0)) == level
			and int(right.get("strength_level", 0)) == level,
			"both wind directions must expose strength level %d" % level
		)
		_expect(
			float(left.get("bias_degrees", 0.0)) < 0.0
			and float(right.get("bias_degrees", 0.0)) > 0.0,
			"wind direction and future gauge bias must agree at strength %d" % level
		)

	var rng_state := {"seed": 20260820, "state": 20260820}
	var calm_count := 0
	var windy_count := 0
	for _index in range(10000):
		var result := TowerAscentRouteWindPolicy.roll_from_gameplay_state(rng_state)
		rng_state = result.get("gameplay_rng_state", {})
		if bool((result.get("wind", {}) as Dictionary).get("is_windy", false)):
			windy_count += 1
		else:
			calm_count += 1
	var calm_ratio := float(calm_count) / 10000.0
	_expect(
		absf(calm_ratio - TowerAscentRouteWindPolicy.CALM_PROBABILITY) <= 0.02,
		"fixed gameplay seed must preserve the declared 60/40 wind distribution"
	)
	_expect(calm_count + windy_count == 10000, "every route entry must resolve exactly one wind state")


func _verify_route_wind_indicator_calm_and_directional_states() -> void:
	var renderer := TowerAscentFlowRenderer.new()
	var calm_canvas := FakeWindCanvas.new()
	renderer.debug_draw_route_wind_indicator(
		calm_canvas,
		Vector2(380.0, 650.0),
		TowerAscentRouteWindPolicy.calm_model()
	)
	_expect(calm_canvas.rect_calls == 8, "calm wind must still draw the panel and six strength cells")
	_expect(calm_canvas.circle_calls == 2, "calm wind must show a centered no-wind ring")
	_expect(calm_canvas.polygon_calls == 0, "calm wind must not invent a direction arrow")

	var left_canvas := FakeWindCanvas.new()
	renderer.debug_draw_route_wind_indicator(
		left_canvas,
		Vector2(380.0, 650.0),
		TowerAscentRouteWindPolicy.build_model(-1, 3)
	)
	_expect(left_canvas.polygon_calls == 1, "wind must draw one procedural direction arrow")
	_expect(left_canvas.filled_strength_cells == 3, "maximum wind must fill all three strength cells")
	_expect(left_canvas.circle_calls == 1, "wind must keep the vane pivot without the calm ring")


func _verify_wind_bias_reachability_and_trajectory_isolation() -> void:
	var route_origin := Vector2(380.0, 665.0)
	var target_positions := [
		Vector2(TowerAscentTuning.TEMP_ROUTE_TARGET_LEFT_X, TowerAscentTuning.TEMP_ROUTE_TARGET_Y),
		Vector2(TowerAscentTuning.TEMP_ROUTE_TARGET_RIGHT_X, TowerAscentTuning.TEMP_ROUTE_TARGET_Y),
	]
	for direction in [-1, 1]:
		var runtime := TowerAscentRouteServeRuntime.new()
		var maximum_wind := TowerAscentRouteWindPolicy.build_model(int(direction), 3)
		_expect(
			bool(runtime.begin(null, null, maximum_wind).get("accepted", false)),
			"maximum-wind reachability fixture must enter route aim"
		)
		var gauge_model := runtime.get_aim_gauge_model()
		var minimum_angle := float(gauge_model.get("min_degrees", 0.0))
		var maximum_angle := float(gauge_model.get("max_degrees", 0.0))
		var expected_bias := float(maximum_wind.get("bias_degrees", 0.0))
		_expect(
			is_equal_approx(
				float(gauge_model.get("wind_bias_degrees", 0.0)),
				expected_bias
			),
			"the displayed gauge bounds and wind state must expose the same bias"
		)
		_expect(
			is_equal_approx(
				minimum_angle,
				TowerAscentTuning.TEMP_ROUTE_AIM_MIN_DEGREES + expected_bias
			)
			and is_equal_approx(
				maximum_angle,
				TowerAscentTuning.TEMP_ROUTE_AIM_MAX_DEGREES + expected_bias
			),
			"wind must shift the whole visible sweep range instead of changing dwell time"
		)
		_expect(
			is_equal_approx(
				maximum_angle - minimum_angle,
				TowerAscentTuning.TEMP_ROUTE_AIM_MAX_DEGREES
				- TowerAscentTuning.TEMP_ROUTE_AIM_MIN_DEGREES
			),
			"wind center shift must preserve the original sweep width"
		)
		for target_position in target_positions:
			var target_angle := rad_to_deg(atan2(
				(target_position as Vector2).x - route_origin.x,
				route_origin.y - (target_position as Vector2).y
			))
			_expect(
				target_angle >= minimum_angle and target_angle <= maximum_angle,
				"maximum wind must keep every route target inside the visible sweep range"
			)
		runtime.cancel()

	var calm_runtime := TowerAscentRouteServeRuntime.new()
	var windy_runtime := TowerAscentRouteServeRuntime.new()
	calm_runtime.begin(null, null, TowerAscentRouteWindPolicy.calm_model())
	windy_runtime.begin(null, null, TowerAscentRouteWindPolicy.build_model(1, 3))
	var same_aim_point := Vector2(452.0, 120.0)
	calm_runtime.debug_serve_toward(same_aim_point)
	windy_runtime.debug_serve_toward(same_aim_point)
	var empty_targets: Array[Dictionary] = []
	calm_runtime.update(0.25, empty_targets)
	windy_runtime.update(0.25, empty_targets)
	_expect(
		calm_runtime.get_ball_position().is_equal_approx(windy_runtime.get_ball_position()),
		"wind must not bend equal-angle route ball trajectories after launch"
	)
	_expect(
		Vector2(calm_runtime.get("_fixture_ball_velocity")).is_equal_approx(
			Vector2(windy_runtime.get("_fixture_ball_velocity"))
		),
		"wind must not mutate equal-angle route ball velocity after launch"
	)
	calm_runtime.cancel()
	windy_runtime.cancel()


func _verify_route_target_uses_map_icon_without_name_text() -> void:
	var renderer := TowerAscentFlowRenderer.new()
	var node := {
		"id": "fixture-spring",
		"kind": "guardian_spring",
		"label": "수호의 샘터",
	}
	var presentation: Dictionary = renderer.build_map_icon_presentation(node)
	_expect(
		presentation.get("icon_texture", null) is Texture2D,
		"route target must reuse the map iconography owner's loaded node texture"
	)
	var flow := FakeRouteAimFlow.new()
	flow.targets = [{
		"id": "fixture-spring",
		"label": "수호의 샘터",
		"kind": "guardian_spring",
		"position": Vector2(220.0, 165.0),
		"draw_radius": TowerAscentTuning.TEMP_ROUTE_TARGET_DRAW_RADIUS,
		"icon_presentation": presentation,
	}]
	var canvas := FakeRouteAimCanvas.new()
	renderer.debug_draw_route_aim(canvas, flow)
	_expect(canvas.texture_rect_calls == 1, "route target must draw the shared map icon")
	_expect(
		not canvas.drawn_strings.has("수호의 샘터"),
		"an available route icon must suppress the target name string"
	)

	flow.targets[0]["icon_presentation"] = {
		"icon_texture": null,
		"fallback_label": "수호의 샘터",
	}
	var fallback_canvas := FakeRouteAimCanvas.new()
	renderer.debug_draw_route_aim(fallback_canvas, flow)
	_expect(
		fallback_canvas.drawn_strings.has("수호의 샘터"),
		"a missing shared icon must preserve the iconography owner's text fallback"
	)


func _verify_live_shell_meta_owner_frame_path() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var owner: Object = BattleSceneShell.new()
	owner.set("current_stage", 4)
	owner.set("selected_character_type", "smasher")
	owner.set("player_pos", Vector2(250.0, 700.0))
	owner.set("player_speed", 0.0)
	owner.set("player_paddle_width", 155.0)
	owner.set("player_paddle_height", 50.0)
	owner.set("gameplay_frame_counter", 0)
	owner.set("ball_pos", Vector2(380.0, 665.0))
	owner.set("ball_vel", Vector2.ZERO)
	owner.set("ball_active", false)
	owner.set("ball_size", 28.6)
	owner.set("ball_impact_boost", 1.0)

	var property_names: Dictionary = {}
	for property_value in owner.get_property_list():
		if property_value is Dictionary:
			property_names[str((property_value as Dictionary).get("name", ""))] = true
	_expect(
		not property_names.has("player_pos") and not property_names.has("ball_active"),
		"live BattleSceneShell route keys must stay meta-only instead of leaking into the property list"
	)

	var input_reader := FakeInputReader.new()
	var movement_state := FakeMovementState.new()
	var round_state := FakeRoundState.new()
	var ball_driver := FakeBallDriver.new(round_state)
	var motion_stepper := FakeMotionStepper.new()
	var flow := TowerAscentFlowOwner.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"tower_ascent_flow_owner": flow,
		"runtime_perk_state": FakeModalRuntime.new(),
		"round_flow_state": round_state,
		"battle_scene_ball_update_driver": ball_driver,
		"ball_motion_stepper": motion_stepper,
		"paddle_bounce_state": PaddleBounceState.new(),
		"ball_physics": BallPhysics.new(),
		"smasher_input_reader": input_reader,
		"player_movement_state": movement_state,
		"battle_update_context": FakePlayerControlContext.new(),
		"battle_scene_player_control_config_builder": BattleScenePlayerControlConfigBuilder.new(),
	}
	_expect(
		flow.begin_vertical_slice(
			owner,
			Callable(),
			{"registry": registry, "run_id": "live-shell-meta-route"}
		),
		"live BattleSceneShell route fixture must enter ROUTE_AIM"
	)
	var targets: Array[Dictionary] = flow.get_route_aim_targets()
	_expect(targets.size() >= 1, "live shell ROUTE_AIM must expose a physical target")
	if targets.is_empty():
		flow.call("_finish_vertical_slice")
		owner.free()
		return
	var target_position: Vector2 = targets[0].get("position", Vector2.ZERO)
	input_reader.snapshot["direction"] = 0.0
	input_reader.snapshot["mouse_left_just_pressed"] = false
	_prime_flow_aim_to_target(flow, input_reader, target_position, Vector2(380.0, 665.0))
	input_reader.snapshot_calls = 0
	movement_state.update_calls = 0
	input_reader.snapshot["direction"] = 1.0
	input_reader.snapshot["mouse_left_just_pressed"] = true
	var holder := ModuleHolder.new()
	holder.modules = {
		"battle_scene_readiness_controller": FakeReadiness.new(),
		"battle_scene_match_event_driver": FakeTransition.new(),
		"stage_clear_result_screen": FakeScreen.new(),
		"defeat_chance_gems_continue_screen": FakeScreen.new(),
		"defeat_settlement_screen": FakeScreen.new(),
		"grip_style_selection_overlay": FakeGrip.new(),
		"battle_scene_modal_gate_controller": FakeModalGate.new(),
	}
	var initial_player_pos := BattleSceneOwnerReader.get_vector2(
		owner,
		"player_pos",
		Vector2.ZERO
	)
	var blocked := _run_physics_gate_frame(
		1.0 / 60.0,
		owner,
		registry,
		holder,
		FakeModalPause.new()
	)
	_expect(blocked, "live shell ROUTE_AIM frame must stay inside the tower physics gate")
	_expect(
		BattleSceneOwnerReader.get_vector2(owner, "player_pos", Vector2.ZERO).x
			> initial_player_pos.x,
		"live shell meta player_pos must accept the selective movement write"
	)
	_expect(ball_driver.serve_calls == 1, "live shell meta ball_active must preserve the actual serve")
	_expect(flow.get_phase_name() == "ROUTE_AIM", "the launch frame must keep a physical route ball in flight")
	input_reader.snapshot["direction"] = 0.0
	input_reader.snapshot["mouse_left_just_pressed"] = false
	flow.update_selective(1.2)
	_expect(
		flow.get_phase_name() == "MAP_TRANSITION",
		"live shell meta ball state must reach the swept target instead of re-serve looping"
	)
	flow.call("_finish_vertical_slice")
	owner.free()


func _verify_physics_gate_frame_path_moves_serves_and_hits() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var owner := FakeOwner.new()
	var frame_trace: Array[String] = []
	var input_reader := FakeInputReader.new()
	var movement_state := FakeMovementState.new()
	var round_state := FakeRoundState.new()
	var ball_driver := FakeBallDriver.new(round_state)
	var motion_stepper := FakeMotionStepper.new()
	input_reader.trace = frame_trace
	movement_state.trace = frame_trace
	ball_driver.trace = frame_trace
	motion_stepper.trace = frame_trace
	var flow := TowerAscentFlowOwner.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"tower_ascent_flow_owner": flow,
		"runtime_perk_state": FakeModalRuntime.new(),
		"round_flow_state": round_state,
		"battle_scene_ball_update_driver": ball_driver,
		"ball_motion_stepper": motion_stepper,
		"paddle_bounce_state": PaddleBounceState.new(),
		"ball_physics": BallPhysics.new(),
		"smasher_input_reader": input_reader,
		"player_movement_state": movement_state,
		"battle_update_context": FakePlayerControlContext.new(),
		"battle_scene_player_control_config_builder": BattleScenePlayerControlConfigBuilder.new(),
	}
	_expect(
		flow.begin_vertical_slice(owner, Callable(), {"registry": registry, "run_id": "gate-frame-route"}),
		"production route fixture must enter ROUTE_AIM"
	)
	var entry_wind := flow.get_route_wind_model()
	var entry_rng_state: Dictionary = flow.export_snapshot().get("gameplay_rng_state", {})
	_expect(flow.get_route_wind_roll_count() == 1, "ROUTE_AIM entry must roll wind exactly once")
	input_reader.snapshot["direction"] = 0.0
	input_reader.snapshot["mouse_left_just_pressed"] = false
	for _frame in range(24):
		flow.update_selective(1.0 / 60.0)
	_expect(
		flow.get_route_wind_roll_count() == 1,
		"multiple ROUTE_AIM frames must not reroll the entry wind"
	)
	_expect(flow.get_route_wind_model() == entry_wind, "entry wind must stay fixed through the serve")
	_expect(
		flow.export_snapshot().get("gameplay_rng_state", {}) == entry_rng_state,
		"per-frame route updates must not consume gameplay RNG after the entry roll"
	)
	var targets: Array[Dictionary] = flow.get_route_aim_targets()
	_expect(targets.size() >= 1, "generated ROUTE_AIM must expose a physical target")
	if targets.is_empty():
		flow.call("_finish_vertical_slice")
		owner.free()
		return
	var target_position: Vector2 = targets[0].get("position", Vector2.ZERO)
	input_reader.snapshot["direction"] = 0.0
	input_reader.snapshot["mouse_left_just_pressed"] = false
	_prime_flow_aim_to_target(flow, input_reader, target_position, Vector2(380.0, 665.0))
	input_reader.snapshot_calls = 0
	movement_state.update_calls = 0
	frame_trace.clear()
	input_reader.snapshot["direction"] = 1.0
	input_reader.snapshot["mouse_left_just_pressed"] = true
	var holder := ModuleHolder.new()
	holder.modules = {
		"battle_scene_readiness_controller": FakeReadiness.new(),
		"battle_scene_match_event_driver": FakeTransition.new(),
		"stage_clear_result_screen": FakeScreen.new(),
		"defeat_chance_gems_continue_screen": FakeScreen.new(),
		"defeat_settlement_screen": FakeScreen.new(),
		"grip_style_selection_overlay": FakeGrip.new(),
		"battle_scene_modal_gate_controller": FakeModalGate.new(),
	}
	var pause := FakeModalPause.new()
	var initial_player_pos := owner.player_pos
	var initial_scores := Vector2i(owner.player_score, owner.boss_score)
	var initial_cooldown := owner.cooldown_seconds
	var uses_extracted_gate := ResourceLoader.exists(PHYSICS_GATE_COORDINATOR_PATH)
	var blocked := _run_physics_gate_frame(
		1.0 / 60.0,
		owner,
		registry,
		holder,
		pause
	)
	_expect(blocked, "ROUTE_AIM frame must stay inside the tower physics gate")
	_expect(owner.player_pos.x > initial_player_pos.x, "the coordinator frame path must tick player movement")
	_expect(input_reader.snapshot_calls == 1, "one ROUTE_AIM frame must acquire one idempotent input snapshot")
	_expect(movement_state.update_calls == 1, "one ROUTE_AIM frame must tick player movement once")
	_expect(ball_driver.serve_calls == 1, "the same coordinator frame must trigger the existing serve producer")
	_expect(frame_trace.count("ball_step") == 1, "the same coordinator frame must step the served ball once")
	_expect(flow.get_phase_name() == "ROUTE_AIM" and flow.is_selector_launched(), "the same coordinator frame must launch the timed route serve")
	_expect(
		frame_trace == ["input_snapshot", "player_movement", "serve_ball", "ball_step"],
		"ROUTE_AIM selective order must be snapshot -> movement -> serve -> ball step before hit transition"
	)
	_expect(
		Vector2i(owner.player_score, owner.boss_score) == initial_scores,
		"the selective frame must keep combat score processing frozen"
	)
	_expect(is_equal_approx(owner.cooldown_seconds, initial_cooldown), "the selective frame must keep combat cooldowns frozen")
	if uses_extracted_gate:
		_expect(pause.enter_calls == 1, "the extracted physics gate must retain the modal pause fanout")
	input_reader.snapshot["direction"] = 0.0
	input_reader.snapshot["mouse_left_just_pressed"] = false
	flow.update_selective(1.2)
	_expect(flow.get_phase_name() == "MAP_TRANSITION", "the timed physical trajectory must resolve the swept target hit")
	flow.call("_finish_vertical_slice")
	owner.free()


func _run_physics_gate_frame(
	delta: float,
	owner: Object,
	registry: Object,
	holder: ModuleHolder,
	pause: FakeModalPause
) -> bool:
	if ResourceLoader.exists(PHYSICS_GATE_COORDINATOR_PATH):
		var gate_script := load(PHYSICS_GATE_COORDINATOR_PATH) as Script
		return bool(gate_script.new().should_block(
			delta,
			owner,
			registry,
			Callable(holder, "get_module"),
			{
				"is_battle_initialized": Callable(self, "_true_callback"),
				"is_stage_landing_intro_started": Callable(self, "_true_callback"),
			},
			pause
		))
	return bool(BattleSceneFrameController.new().call(
		"_process_tower_ascent_flow",
		delta,
		owner,
		registry
	))


func _true_callback() -> bool:
	return true


func _prime_flow_aim_to_target(
	flow: Object,
	input_reader: FakeInputReader,
	target_position: Vector2,
	ball_origin: Vector2
) -> void:
	var desired_angle := rad_to_deg(atan2(
		target_position.x - ball_origin.x,
		ball_origin.y - target_position.y
	))
	for _frame in range(720):
		var model: Dictionary = flow.get_route_aim_gauge_model()
		if absf(float(model.get("angle_degrees", 0.0)) - desired_angle) <= 0.35:
			return
		input_reader.snapshot["mouse_left_just_pressed"] = false
		flow.update_selective(1.0 / 240.0)
	_expect(false, "route aim oscillator must traverse the physical target angle")


func _prime_runtime_aim_to_target(
	runtime: Object,
	input_reader: FakeInputReader,
	target_position: Vector2,
	ball_origin: Vector2
) -> void:
	var desired_angle := rad_to_deg(atan2(
		target_position.x - ball_origin.x,
		ball_origin.y - target_position.y
	))
	var empty_targets: Array[Dictionary] = []
	for _frame in range(720):
		var model: Dictionary = runtime.get_aim_gauge_model()
		if absf(float(model.get("angle_degrees", 0.0)) - desired_angle) <= 0.35:
			return
		input_reader.snapshot["mouse_left_just_pressed"] = false
		runtime.update(1.0 / 240.0, empty_targets)
	_expect(false, "runtime angle oscillator must traverse the physical target angle")


func _verify_free_movement_while_waiting_and_in_flight() -> void:
	var owner := FakeOwner.new()
	var round_state := FakeRoundState.new()
	var ball_driver := FakeBallDriver.new(round_state)
	var input_reader := FakeInputReader.new()
	input_reader.snapshot["action_pressed"] = false
	input_reader.snapshot["action_just_pressed"] = false
	input_reader.snapshot["mouse_left_just_pressed"] = false
	input_reader.snapshot["direction"] = 1.0
	var movement_state := FakeMovementState.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"round_flow_state": round_state,
		"battle_scene_ball_update_driver": ball_driver,
		"ball_motion_stepper": BallMotionStepper.new(),
		"paddle_bounce_state": PaddleBounceState.new(),
		"ball_physics": BallPhysics.new(),
		"smasher_input_reader": input_reader,
		"player_movement_state": movement_state,
		"battle_update_context": FakePlayerControlContext.new(),
		"battle_scene_player_control_config_builder": BattleScenePlayerControlConfigBuilder.new(),
	}
	var runtime := TowerAscentRouteServeRuntime.new()
	_expect(bool(runtime.begin(owner, registry).get("accepted", false)), "free-movement fixture must acquire the production route dependencies")
	var waiting_start_x: float = owner.player_pos.x
	var waiting_result: Dictionary = runtime.update(
		TowerAscentTuning.TEMP_ROUTE_AIM_ENTRY_ARM_SECONDS,
		[]
	)
	_expect(str(waiting_result.get("status", "")) == TowerAscentRouteServeRuntime.STATUS_WAITING, "movement-only route frame must remain in manual serve wait")
	_expect(owner.player_pos.x > waiting_start_x, "player must move freely while the route serve is waiting")

	input_reader.snapshot["action_pressed"] = true
	input_reader.snapshot["action_just_pressed"] = true
	input_reader.snapshot["mouse_left_just_pressed"] = true
	runtime.update(1.0 / 60.0, [])
	_expect(owner.ball_active and not round_state.waiting, "manual serve must enter flight for the movement seal")
	input_reader.snapshot["action_pressed"] = false
	input_reader.snapshot["action_just_pressed"] = false
	input_reader.snapshot["mouse_left_just_pressed"] = false
	input_reader.snapshot["direction"] = -1.0
	var flight_start_x: float = owner.player_pos.x
	var flight_result: Dictionary = runtime.update(1.0 / 60.0, [])
	_expect(str(flight_result.get("status", "")) == TowerAscentRouteServeRuntime.STATUS_FLIGHT, "flight movement frame must keep the route ball in flight")
	_expect(owner.player_pos.x < flight_start_x, "player must keep moving freely while the route ball is in flight")
	_expect(movement_state.update_calls == 3, "waiting, serve, and flight frames must each tick movement exactly once")
	runtime.cancel()
	owner.free()


func _verify_top_wall_and_player_paddle_round_trip() -> void:
	var owner := FakeOwner.new()
	owner.player_pos = Vector2(302.5, 700.0)
	var round_state := FakeRoundState.new()
	var ball_driver := FakeBallDriver.new(round_state)
	ball_driver.velocities = [Vector2(0.0, -8.7)]
	var input_reader := FakeInputReader.new()
	input_reader.snapshot["direction"] = 0.0
	input_reader.snapshot["action_pressed"] = false
	input_reader.snapshot["action_just_pressed"] = false
	input_reader.snapshot["mouse_left_just_pressed"] = false
	var registry := FakeRegistry.new()
	registry.instances = {
		"round_flow_state": round_state,
		"battle_scene_ball_update_driver": ball_driver,
		"ball_motion_stepper": BallMotionStepper.new(),
		"paddle_bounce_state": PaddleBounceState.new(),
		"ball_physics": BallPhysics.new(),
		"smasher_input_reader": input_reader,
		"player_movement_state": FakeMovementState.new(),
		"battle_update_context": FakePlayerControlContext.new(),
		"battle_scene_player_control_config_builder": BattleScenePlayerControlConfigBuilder.new(),
	}
	var runtime := TowerAscentRouteServeRuntime.new()
	_expect(bool(runtime.begin(owner, registry).get("accepted", false)), "route wall fixture must acquire production ball and paddle physics")
	# This leg isolates wall and paddle reflection. Physical target hits are
	# covered separately and may legitimately end the attempt before a complete
	# round trip, which would make this physics assertion timing-dependent.
	var empty_targets: Array[Dictionary] = []
	runtime.update(TowerAscentTuning.TEMP_ROUTE_AIM_SWEEP_PERIOD_SECONDS, empty_targets)
	input_reader.snapshot["mouse_left_just_pressed"] = true
	runtime.update(0.0, empty_targets)
	input_reader.snapshot["action_pressed"] = false
	input_reader.snapshot["action_just_pressed"] = false
	input_reader.snapshot["mouse_left_just_pressed"] = false
	var reset_count_after_serve := ball_driver.reset_calls
	var top_bounced := false
	for _frame in range(100):
		var before_velocity := owner.ball_vel
		var result: Dictionary = runtime.update(1.0 / 60.0, empty_targets)
		if before_velocity.y < 0.0 and owner.ball_vel.y > 0.0:
			top_bounced = true
			_expect(str(result.get("status", "")) == TowerAscentRouteServeRuntime.STATUS_FLIGHT, "the top boundary must reflect without completing a miss")
			_expect(owner.ball_pos.y >= owner.ball_size * 0.5, "the top reflection must write a clamped owner ball position in the same frame")
			break
	_expect(top_bounced, "the route ball must reflect from the top wall")
	_expect(ball_driver.reset_calls == reset_count_after_serve and owner.ball_active, "top reflection must preserve the active route attempt")

	var paddle_bounced := false
	for _frame in range(100):
		var before_velocity := owner.ball_vel
		var result: Dictionary = runtime.update(1.0 / 60.0, empty_targets)
		if owner.ball_pos.y > 600.0 and before_velocity.y > 0.0 and owner.ball_vel.y < 0.0:
			paddle_bounced = true
			_expect(str(result.get("status", "")) == TowerAscentRouteServeRuntime.STATUS_FLIGHT, "the player paddle must reflect without completing a miss")
			break
	_expect(paddle_bounced, "the returning route ball must reuse player paddle reflection physics")
	_expect(ball_driver.reset_calls == reset_count_after_serve and owner.ball_active, "player paddle reflection must preserve the active route attempt")

	var second_top_bounce := false
	# Production paddle physics may curve the return down to its permitted
	# minimum vertical component. Allow the full playfield crossing at that
	# shallow angle instead of assuming the near-vertical launch cadence.
	for _frame in range(240):
		var before_velocity := owner.ball_vel
		runtime.update(1.0 / 60.0, empty_targets)
		if before_velocity.y < 0.0 and owner.ball_vel.y > 0.0:
			second_top_bounce = true
			break
	_expect(second_top_bounce, "the paddle return must travel back to and reflect from the top wall")
	owner.player_pos.x = 0.0
	owner.ball_pos = Vector2(380.0, 740.0)
	owner.ball_vel = Vector2(0.0, 8.7)
	var miss_result: Dictionary = {}
	for _frame in range(120):
		miss_result = runtime.update(1.0 / 60.0, empty_targets)
		if str(miss_result.get("status", "")) == TowerAscentRouteServeRuntime.STATUS_MISS:
			break
	_expect(str(miss_result.get("status", "")) == TowerAscentRouteServeRuntime.STATUS_MISS, "only a bottom-out after missing the player paddle may rearm the route serve")
	_expect(round_state.waiting and ball_driver.reset_calls == reset_count_after_serve + 1, "bottom-out must return to manual re-serve exactly once")
	runtime.cancel()
	owner.free()


func _verify_real_serve_owner_and_unlimited_retry() -> void:
	var owner := FakeOwner.new()
	var round_state := FakeRoundState.new()
	var ball_driver := FakeBallDriver.new(round_state)
	var left_target := Vector2(
		TowerAscentTuning.TEMP_ROUTE_TARGET_LEFT_X,
		TowerAscentTuning.TEMP_ROUTE_TARGET_Y
	)
	ball_driver.velocities = [
		Vector2(0.0, -8.7),
		(left_target - Vector2(380.0, 665.0)).normalized() * 8.7,
	]
	var registry := FakeRegistry.new()
	var input_reader := FakeInputReader.new()
	input_reader.snapshot["direction"] = 0.0
	input_reader.snapshot["action_pressed"] = false
	input_reader.snapshot["action_just_pressed"] = false
	input_reader.snapshot["mouse_left_just_pressed"] = false
	registry.instances = {
		"round_flow_state": round_state,
		"battle_scene_ball_update_driver": ball_driver,
		"ball_motion_stepper": BallMotionStepper.new(),
		"paddle_bounce_state": PaddleBounceState.new(),
		"ball_physics": BallPhysics.new(),
		"smasher_input_reader": input_reader,
		"player_movement_state": FakeMovementState.new(),
		"battle_update_context": FakePlayerControlContext.new(),
		"battle_scene_player_control_config_builder": BattleScenePlayerControlConfigBuilder.new(),
	}
	var runtime := TowerAscentRouteServeRuntime.new()
	var begin_result: Dictionary = runtime.begin(owner, registry)
	_expect(bool(begin_result.get("accepted", false)), "route serve must acquire the production serve dependencies")
	_expect(round_state.player_serves, "route serve must assign the existing player serve owner")
	_expect(ball_driver.reset_calls == 1, "route entry must park the live ball for manual serve")
	var targets: Array[Dictionary] = [
		{"id": "left", "position": left_target, "hit_radius": TowerAscentTuning.TEMP_ROUTE_TARGET_HIT_RADIUS},
		{"id": "right", "position": Vector2(TowerAscentTuning.TEMP_ROUTE_TARGET_RIGHT_X, TowerAscentTuning.TEMP_ROUTE_TARGET_Y), "hit_radius": TowerAscentTuning.TEMP_ROUTE_TARGET_HIT_RADIUS},
	]
	runtime.update(TowerAscentTuning.TEMP_ROUTE_AIM_ENTRY_ARM_SECONDS, targets)
	input_reader.snapshot["mouse_left_just_pressed"] = true
	runtime.update(0.016, targets)
	_expect(ball_driver.serve_calls == 1 and owner.ball_active, "serve flow must launch the live owner ball through the existing ball driver")
	owner.player_pos.x = 0.0
	owner.ball_pos = Vector2(380.0, 740.0)
	owner.ball_vel = Vector2(0.0, 8.7)
	input_reader.snapshot["action_pressed"] = false
	input_reader.snapshot["action_just_pressed"] = false
	input_reader.snapshot["mouse_left_just_pressed"] = false
	var miss_result: Dictionary = runtime.update(0.1, targets)
	_expect(str(miss_result.get("status", "")) == TowerAscentRouteServeRuntime.STATUS_MISS, "a serve that misses both targets must rearm instead of selecting")
	_expect(round_state.waiting and ball_driver.reset_calls == 2, "a miss must return to unlimited player re-serve")
	input_reader.snapshot["action_pressed"] = false
	input_reader.snapshot["action_just_pressed"] = false
	input_reader.snapshot["mouse_left_just_pressed"] = false
	_prime_runtime_aim_to_target(runtime, input_reader, left_target, Vector2(380.0, 665.0))
	input_reader.snapshot["mouse_left_just_pressed"] = true
	runtime.update(0.0, targets)
	var hit_result: Dictionary = runtime.update(1.5, targets)
	_expect(str(hit_result.get("status", "")) == TowerAscentRouteServeRuntime.STATUS_HIT, "the real serve trajectory must resolve a swept target hit")
	_expect(str(hit_result.get("target_id", "")) == "left", "the physical hit, not an aim choice, must select the node")
	_expect(runtime.get_serve_attempt_count() == 2, "miss and retry must count two actual serve launches")
	_expect(not owner.ball_active and owner.ball_vel == Vector2.ZERO, "target resolution must release and hide the route-owned ball")
	_expect(owner.player_score == 7 and owner.boss_score == 3, "route ball ownership must not emit combat score events")
	_expect(owner.boss_ai_ticks == 0 and owner.combat_rng_state == 44123, "route ball ownership must not tick boss AI or combat RNG")
	_expect(is_equal_approx(owner.cooldown_seconds, 2.5), "route ball ownership must not tick combat cooldowns")
	_expect(not registry.reads.has("game_audio") and not registry.reads.has("boss_ai"), "selective route simulation must not acquire loop audio or boss AI")
	runtime.cancel()
	owner.free()


func _verify_route_wait_never_auto_serves_and_legacy_still_does() -> void:
	var owner := FakeOwner.new()
	var round_state := FakeRoundState.new()
	var ball_driver := FakeBallDriver.new(round_state)
	var input_reader := FakeInputReader.new()
	input_reader.snapshot = {
		"left_pressed": false,
		"right_pressed": false,
		"direction": 0.0,
		"action_pressed": false,
		"action_just_pressed": false,
		"mouse_left_just_pressed": false,
	}
	var registry := FakeRegistry.new()
	registry.instances = {
		"round_flow_state": round_state,
		"battle_scene_ball_update_driver": ball_driver,
		"ball_motion_stepper": BallMotionStepper.new(),
		"paddle_bounce_state": PaddleBounceState.new(),
		"ball_physics": BallPhysics.new(),
		"smasher_input_reader": input_reader,
		"player_movement_state": FakeMovementState.new(),
		"battle_update_context": FakePlayerControlContext.new(),
		"battle_scene_player_control_config_builder": BattleScenePlayerControlConfigBuilder.new(),
	}
	var runtime := TowerAscentRouteServeRuntime.new()
	_expect(bool(runtime.begin(owner, registry).get("accepted", false)), "manual-only route fixture must acquire its production dependencies")
	var waiting_result: Dictionary = runtime.update(30.0, [])
	_expect(str(waiting_result.get("status", "")) == TowerAscentRouteServeRuntime.STATUS_WAITING, "thirty seconds without input must keep ROUTE_AIM waiting")
	_expect(ball_driver.serve_calls == 0 and runtime.get_serve_attempt_count() == 0, "ROUTE_AIM elapsed time must never auto-serve")
	input_reader.snapshot["action_pressed"] = true
	input_reader.snapshot["action_just_pressed"] = true
	input_reader.snapshot["mouse_left_just_pressed"] = true
	runtime.update(0.016, [])
	_expect(ball_driver.serve_calls == 1 and runtime.get_serve_attempt_count() == 1, "a left-click edge must still launch the route ball")
	runtime.cancel()
	owner.free()

	Input.action_release("ui_accept")
	_legacy_serve_calls = 0
	var legacy_round := LegacyAutoRoundState.new()
	var legacy_serve := ServeFlowController.new()
	legacy_serve.sync_current_input_state()
	legacy_serve.update(
		ServeFlowController.PLAYER_AUTO_SERVE_DELAY + 0.01,
		{"current_stage": 1},
		{"round_state": legacy_round},
		{"serve_ball": Callable(self, "_record_legacy_serve")}
	)
	_expect(_legacy_serve_calls == 1, "ordinary combat must retain its three-second auto-serve")


func _record_legacy_serve() -> void:
	_legacy_serve_calls += 1


func _verify_entry_arm_discards_held_click_and_preserves_phase() -> void:
	var owner := FakeOwner.new()
	var round_state := FakeRoundState.new()
	var ball_driver := FakeBallDriver.new(round_state)
	var input_reader := FakeInputReader.new()
	input_reader.derive_mouse_edge_from_pressed = true
	input_reader.snapshot = {
		"direction": 1.0,
		"action_pressed": false,
		"action_just_pressed": false,
		"mouse_left_pressed": true,
	}
	var movement_state := FakeMovementState.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"round_flow_state": round_state,
		"battle_scene_ball_update_driver": ball_driver,
		"ball_motion_stepper": BallMotionStepper.new(),
		"paddle_bounce_state": PaddleBounceState.new(),
		"ball_physics": BallPhysics.new(),
		"smasher_input_reader": input_reader,
		"player_movement_state": movement_state,
		"battle_update_context": FakePlayerControlContext.new(),
		"battle_scene_player_control_config_builder": BattleScenePlayerControlConfigBuilder.new(),
	}
	var runtime := TowerAscentRouteServeRuntime.new()
	_expect(bool(runtime.begin(owner, registry).get("accepted", false)), "entry-arm fixture must acquire route dependencies")
	var entry_angle := float(runtime.get_aim_gauge_model().get("angle_degrees", 0.0))
	var entry_x := owner.player_pos.x
	runtime.update(0.10, [])
	var armed_angle := float(runtime.get_aim_gauge_model().get("angle_degrees", 0.0))
	_expect(ball_driver.serve_calls == 0, "a held click entering ROUTE_AIM must be discarded during the arm window")
	_expect(owner.player_pos.x > entry_x, "the player must keep moving during the route-entry arm window")
	_expect(not is_equal_approx(entry_angle, armed_angle), "the timing gauge must keep sweeping during the route-entry arm window")
	runtime.update(TowerAscentTuning.TEMP_ROUTE_AIM_ENTRY_ARM_SECONDS, [])
	_expect(ball_driver.serve_calls == 0, "the same held click must not fire when the arm timer expires")
	input_reader.set_mouse_left_pressed(false)
	runtime.update(0.0, [])
	input_reader.set_mouse_left_pressed(true)
	runtime.update(0.0, [])
	_expect(ball_driver.serve_calls == 1, "release followed by a fresh left-click edge must launch exactly once")
	var carried_angle := float(runtime.get_aim_gauge_model().get("angle_degrees", 0.0))
	runtime.cancel()
	input_reader.set_mouse_left_pressed(false)
	input_reader.get_snapshot()
	_expect(bool(runtime.begin(owner, registry).get("accepted", false)), "successive route entry must restart without resetting the oscillator")
	var next_entry_angle := float(runtime.get_aim_gauge_model().get("angle_degrees", 0.0))
	_expect(is_equal_approx(next_entry_angle, carried_angle), "successive ROUTE_AIM entries must carry the oscillator phase")
	runtime.update(0.17, [])
	var later_angle := float(runtime.get_aim_gauge_model().get("angle_degrees", 0.0))
	runtime.cancel()
	_expect(bool(runtime.begin(owner, registry).get("accepted", false)), "a later route entry must remain available")
	_expect(
		not is_equal_approx(
			float(runtime.get_aim_gauge_model().get("angle_degrees", 0.0)),
			next_entry_angle
		),
		"different residence times must produce different successive entry angles"
	)
	_expect(not is_equal_approx(later_angle, next_entry_angle), "the preserved oscillator must advance between successive entries")
	runtime.cancel()
	owner.free()


func _verify_oscillating_gauge_and_mouse_timed_serve() -> void:
	var owner := FakeOwner.new()
	var round_state := FakeRoundState.new()
	var ball_driver := FakeBallDriver.new(round_state)
	var input_reader := FakeInputReader.new()
	input_reader.snapshot = {
		"direction": 0.0,
		"action_pressed": false,
		"action_just_pressed": false,
		"mouse_left_just_pressed": false,
	}
	var registry := FakeRegistry.new()
	registry.instances = {
		"round_flow_state": round_state,
		"battle_scene_ball_update_driver": ball_driver,
		"ball_motion_stepper": BallMotionStepper.new(),
		"paddle_bounce_state": PaddleBounceState.new(),
		"ball_physics": BallPhysics.new(),
		"smasher_input_reader": input_reader,
		"player_movement_state": FakeMovementState.new(),
		"battle_update_context": FakePlayerControlContext.new(),
		"battle_scene_player_control_config_builder": BattleScenePlayerControlConfigBuilder.new(),
	}
	var runtime := TowerAscentRouteServeRuntime.new()
	_expect(bool(runtime.begin(owner, registry).get("accepted", false)), "angle-gauge fixture must acquire route dependencies")
	var initial_model := runtime.get_aim_gauge_model()
	_expect(bool(initial_model.get("visible", false)), "angle gauge must be visible while waiting for serve")
	var initial_origin: Variant = initial_model.get("origin", Vector2.ZERO)
	_expect(
		initial_origin is Vector2
		and is_equal_approx(
			(initial_origin as Vector2).x,
			owner.player_pos.x + owner.player_paddle_width * 0.5
		),
		"angle gauge must stay centered immediately above the moving player"
	)
	_expect(
		(initial_origin as Vector2).y
			<= owner.player_pos.y - TowerAscentTuning.TEMP_ROUTE_AIM_GAUGE_PLAYER_GAP,
		"angle gauge must remain above the legacy serve indicator and player art"
	)
	runtime.update(TowerAscentTuning.TEMP_ROUTE_AIM_SWEEP_PERIOD_SECONDS * 0.25, [])
	var right_model := runtime.get_aim_gauge_model()
	_expect(
		is_equal_approx(
			float(right_model.get("angle_degrees", 0.0)),
			TowerAscentTuning.TEMP_ROUTE_AIM_MAX_DEGREES
		),
		"quarter-period physics time must reach the right angle bound"
	)
	runtime.update(TowerAscentTuning.TEMP_ROUTE_AIM_SWEEP_PERIOD_SECONDS * 0.5, [])
	var left_model := runtime.get_aim_gauge_model()
	_expect(
		is_equal_approx(
			float(left_model.get("angle_degrees", 0.0)),
			TowerAscentTuning.TEMP_ROUTE_AIM_MIN_DEGREES
		),
		"another half-period of physics time must reach the left angle bound"
	)
	input_reader.snapshot["action_pressed"] = true
	input_reader.snapshot["action_just_pressed"] = true
	runtime.update(0.0, [])
	_expect(ball_driver.serve_calls == 0, "keyboard action must not replace the timing gauge's left-click edge")
	input_reader.snapshot["mouse_left_just_pressed"] = true
	runtime.update(0.0, [])
	var launch_angle := deg_to_rad(float(left_model.get("angle_degrees", 0.0)))
	var expected_direction := Vector2(sin(launch_angle), -cos(launch_angle)).normalized()
	var expected_speed := TowerAscentTuning.TEMP_ROUTE_AIM_SERVE_SPEED_PER_SECOND / 60.0
	_expect(ball_driver.serve_calls == 1, "left-click edge must launch through the existing serve producer")
	_expect(owner.ball_vel.is_equal_approx(expected_direction * expected_speed), "left-click must launch at the gauge angle and TEMP serve speed")
	_expect(not bool(runtime.get_aim_gauge_model().get("visible", true)), "angle gauge must hide while the route ball is in flight")
	_expect(input_reader.snapshot_calls == 4, "each physics update must acquire exactly one shared idempotent snapshot")
	runtime.cancel()
	owner.free()


func _verify_generated_gauge_art_draws_and_fallback() -> void:
	var renderer := TowerAscentFlowRenderer.new()
	var asset_paths: PackedStringArray = renderer.get_route_aim_gauge_asset_paths()
	_expect(asset_paths.size() == 2, "the generated route gauge must expose both texture paths")
	for asset_path in asset_paths:
		_expect(FileAccess.file_exists(asset_path), "route gauge texture must exist: %s" % asset_path)
		_expect(FileAccess.file_exists(asset_path + ".import"), "route gauge import sidecar must exist: %s" % asset_path)
	if asset_paths.size() != 2:
		return
	var fan_texture := ResourceLoader.load(asset_paths[0]) as Texture2D
	var arrow_texture := ResourceLoader.load(asset_paths[1]) as Texture2D
	_expect(fan_texture != null, "generated route gauge fan must load as Texture2D")
	_expect(arrow_texture != null, "generated route gauge arrow must load as Texture2D")
	if fan_texture == null or arrow_texture == null:
		return
	_expect(fan_texture.get_size() == Vector2(256.0, 192.0), "generated fan must preserve the 256x192 pivot canvas")
	_expect(arrow_texture.get_size() == Vector2(128.0, 128.0), "generated arrow must preserve the 128x128 rotation canvas")

	var flow := FakeGaugeFlow.new()
	var generated_canvas := FakeGaugeCanvas.new()
	renderer.debug_draw_route_aim_gauge_with_textures(
		generated_canvas,
		flow,
		fan_texture,
		arrow_texture
	)
	_expect(generated_canvas.texture_rect_calls == 1, "production gauge draw must reach the generated fan texture call")
	_expect(generated_canvas.texture_polygon_calls == 1, "production gauge draw must reach the rotated arrow texture call")
	_expect(generated_canvas.colored_polygon_calls == 0, "generated textures must suppress the procedural fan")
	var expected_uvs := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0),
	])
	_expect(generated_canvas.last_uvs == expected_uvs, "rotated arrow quad must use normalized UV corners")

	var fallback_canvas := FakeGaugeCanvas.new()
	renderer.debug_draw_route_aim_gauge_with_textures(
		fallback_canvas,
		flow,
		fan_texture,
		null
	)
	_expect(fallback_canvas.texture_rect_calls == 0, "one missing gauge texture must suppress both generated surfaces")
	_expect(fallback_canvas.texture_polygon_calls == 0, "one missing gauge texture must not draw a partial generated arrow")
	_expect(fallback_canvas.colored_polygon_calls == 3, "one missing gauge texture must restore both fan fills and the procedural arrow head")
	_expect(fallback_canvas.arc_calls == 2, "the null-texture fallback must restore both procedural arcs")
	_expect(fallback_canvas.line_calls == 9, "the null-texture fallback must restore seven ticks and two arrow lines")


func _verify_production_owner_fails_closed_without_serve_dependencies() -> void:
	var owner := FakeOwner.new()
	var runtime := TowerAscentRouteServeRuntime.new()
	var result: Dictionary = runtime.begin(owner, FakeRegistry.new())
	_expect(not bool(result.get("accepted", true)), "a production Node owner must fail closed without the real serve dependency set")
	_expect(not owner.ball_active and owner.ball_vel == Vector2.ZERO, "failed acquisition must not invent or launch a fallback selector ball")
	owner.free()


func _verify_production_source_uses_serve_contract_without_aim_input() -> void:
	var route_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_route_serve_runtime.gd"
	)
	var flow_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_runtime.gd"
	)
	for required_key in [
		"battle_scene_ball_update_driver",
		"ball_motion_stepper",
		"paddle_bounce_state",
		"ball_physics",
		"get_input_reader_key",
		"player_movement_state",
		"battle_update_context",
		"battle_scene_player_control_config_builder",
	]:
		_expect(route_source.find(required_key) >= 0, "route serve must use production dependency: %s" % required_key)
	_expect(route_source.find("_serve_flow.update") < 0, "ROUTE_AIM must not call the auto-serve controller")
	_expect(route_source.find("mouse_left_just_pressed") >= 0, "ROUTE_AIM must launch only from the shared left-click edge")
	_expect(route_source.find("input_snapshot.get(\"action_just_pressed\"") < 0, "keyboard accept must not bypass the timing gauge")
	_expect(route_source.find("TEMP_ROUTE_AIM_SWEEP_PERIOD_SECONDS") >= 0, "the oscillation period must remain an explicit TEMP tuning")
	_expect(route_source.find("TEMP_ROUTE_AIM_SERVE_SPEED_PER_SECOND") >= 0, "the route serve speed must remain an explicit TEMP tuning")
	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	_expect(renderer_source.find("_draw_route_aim_gauge") >= 0, "ROUTE_AIM must render its player-local angle gauge")
	var legacy_serve_source := FileAccess.get_file_as_string(
		"res://scripts/core/serve_flow_controller.gd"
	)
	_expect(legacy_serve_source.find("PLAYER_AUTO_SERVE_DELAY") >= 0, "ordinary combat auto-serve timing must remain intact")
	for retired_aim_input in ["KEY_LEFT", "KEY_RIGHT", "InputEventMouseMotion", "_launch_selector"]:
		_expect(flow_source.find(retired_aim_input) < 0, "ROUTE_AIM must not retain deterministic aim input: %s" % retired_aim_input)
	_expect(route_source.find("RandomNumberGenerator") < 0, "route flow must consume the serve producer's randomness instead of owning another RNG")
	_expect(
		route_source.find("BattleSceneOwnerReader.get_value") >= 0,
		"route serve must read meta-backed BattleSceneShell keys through the shared owner reader"
	)
	_expect(
		route_source.find("_collect_property_names") < 0,
		"route serve must not reintroduce a property-list gate for meta-backed owner keys"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
