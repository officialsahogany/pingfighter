extends SceneTree

const BallMotionStepper := preload("res://scripts/ball/ball_motion_stepper.gd")
const BallPhysics := preload("res://scripts/ball/ball_physics.gd")
const PaddleBounceState := preload("res://scripts/ball/paddle_bounce_state.gd")
const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const BattleSceneOwnerReader := preload(
	"res://scripts/core/battle_scene_owner_reader.gd"
)
const BattleSceneShell := preload("res://scripts/core/battle_scene_shell.gd")
const BattleScenePlayerControlConfigBuilder := preload(
	"res://scripts/core/battle_scene_player_control_config_builder.gd"
)
const Stage1PillarHudSceneDrawer := preload(
	"res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd"
)
const Stage1PillarUiRenderer := preload(
	"res://scripts/hud/stage1_pillar_ui_renderer.gd"
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
const TowerAscentRouteWindPolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_route_wind_policy.gd"
)
const TowerAscentRoutePickupState := preload(
	"res://scripts/tower_ascent/tower_ascent_route_pickup_state.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const OUTPUT_DIR := "res://.godot/codex_captures/tower_route_wind_and_pickup"
const VIEWPORT_SIZE := Vector2i(2020, 1246)
const PLAYFIELD_SIZE := Vector2(760.0, 750.0)
const LIVE_TARGET_INDEX := 0
const SWEEP_FRAME_COUNT := 12
const SWEEP_COLUMNS := 4
const AIM_MATCH_TOLERANCE_DEGREES := 0.35
const LIVE_FLIGHT_LIMIT := 360
const PIXEL_DIFF_THRESHOLD := 0.06

var _failures: Array[String] = []


class FakeRoundState:
	extends RefCounted

	var waiting := true

	func is_waiting_for_serve() -> bool:
		return waiting

	func set_player_serves(_value: bool) -> void:
		pass

	func reset_round_wait() -> void:
		waiting = true


class FakeBallDriver:
	extends RefCounted

	var round_state: FakeRoundState

	func _init(state: FakeRoundState) -> void:
		round_state = state

	func reset_ball(owner: Object, _registry: Object) -> void:
		round_state.waiting = true
		owner.set("ball_pos", Vector2(380.0, 665.0))
		owner.set("ball_vel", Vector2.ZERO)
		owner.set("ball_active", false)

	func serve_ball(owner: Object, _registry: Object) -> void:
		round_state.waiting = false
		owner.set("ball_pos", Vector2(380.0, 665.0))
		owner.set("ball_vel", Vector2(0.0, -8.7))
		owner.set("ball_active", true)


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Variant:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		return instances.get(key, null)


class FakeUnlockStore:
	extends RefCounted

	func is_unlocked(_content_type: String, _content_id: String) -> bool:
		return true


class FakeInputReader:
	extends RefCounted

	var snapshot := {
		"left_pressed": false,
		"right_pressed": false,
		"direction": 0.0,
		"action_pressed": false,
		"action_just_pressed": false,
		"mouse_left_pressed": false,
		"mouse_left_just_pressed": false,
	}

	func get_snapshot() -> Dictionary:
		return snapshot.duplicate(true)


class FakeMovementState:
	extends RefCounted

	func update_horizontal(
		delta: float,
		player_pos: Vector2,
		_player_speed: float,
		direction: float,
		play_left: float,
		play_right: float,
		paddle_width: float,
		_config: Dictionary = {}
	) -> Dictionary:
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


class RouteCaptureCanvas:
	extends Node2D

	var flow: Object = null
	var battle_owner: Object = null
	var renderer: Object = null

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, PLAYFIELD_SIZE), Color("17120f"), true)
		for row in range(15):
			var alpha := 0.035 if row % 2 == 0 else 0.018
			draw_rect(
				Rect2(0.0, float(row) * 50.0, PLAYFIELD_SIZE.x, 25.0),
				Color(0.88, 0.72, 0.42, alpha),
				true
			)
		# ROUTE_AIM retains the full court, player paddle, and selector ball while
		# suppressing departed stage/boss actors and their detached effects.
		draw_rect(Rect2(Vector2.ZERO, PLAYFIELD_SIZE), Color("b48748"), false, 3.0)
		draw_line(Vector2(0.0, 375.0), Vector2(760.0, 375.0), Color(0.85, 0.72, 0.48, 0.16), 1.0)
		if battle_owner != null:
			var player_pos := BattleSceneOwnerReader.get_vector2(
				battle_owner,
				"player_pos",
				Vector2(302.5, 700.0)
			)
			var paddle_width := float(BattleSceneOwnerReader.get_value(
				battle_owner,
				"player_paddle_width",
				155.0
			))
			draw_rect(
				Rect2(player_pos, Vector2(paddle_width, 50.0)),
				Color("efe0b9"),
				true
			)
			if bool(BattleSceneOwnerReader.get_value(battle_owner, "ball_active", false)):
				draw_circle(
					BattleSceneOwnerReader.get_vector2(battle_owner, "ball_pos", Vector2.ZERO),
					14.3,
					Color("ffcf59")
				)
		if renderer != null and flow != null:
			renderer.draw(self, flow)


class PillarCaptureCanvas:
	extends Node2D

	var registry: Object = null
	var scene_drawer: Object = Stage1PillarHudSceneDrawer.new()
	var game_offset := Vector2.ZERO
	var game_size := Vector2.ZERO

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE)), Color("090706"), true)
		scene_drawer.call(
			"_draw_gold_hud",
			self,
			{"height": PLAYFIELD_SIZE.y, "current_stage": 4},
			registry,
			game_offset,
			game_size
		)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("route wind visual QA requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("route wind visual QA requires a Vulkan rendering device")
		return
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	DisplayServer.window_set_title("Tower route wind and target QA")
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)

	var owner: Object = BattleSceneShell.new()
	_prepare_owner(owner)
	var input_reader := FakeInputReader.new()
	var round_state := FakeRoundState.new()
	var flow := TowerAscentFlowOwner.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"tower_ascent_flow_owner": flow,
		"tower_ascent_unlock_store": FakeUnlockStore.new(),
		"stage1_pillar_ui_renderer": Stage1PillarUiRenderer.new(),
		"runtime_perk_state": FakeModalRuntime.new(),
		"round_flow_state": round_state,
		"battle_scene_ball_update_driver": FakeBallDriver.new(round_state),
		"ball_motion_stepper": BallMotionStepper.new(),
		"paddle_bounce_state": PaddleBounceState.new(),
		"ball_physics": BallPhysics.new(),
		"smasher_input_reader": input_reader,
		"player_movement_state": FakeMovementState.new(),
		"battle_update_context": FakePlayerControlContext.new(),
		"battle_scene_player_control_config_builder": BattleScenePlayerControlConfigBuilder.new(),
	}
	var flow_context := {
		"registry": registry,
		"run_id": "route-wind-target-visual-qa",
		"current_stage": 4,
		"map_seed": 83521,
		"run_state": {"gold": 10, "muhon": 20},
	}
	if not flow.prepare_vertical_slice_combat(owner, flow_context):
		_fail("production flow could not prepare the ROUTE_AIM battle resolution")
		owner.free()
		return
	# Choose an input RNG state whose one production entry roll is strong wind.
	# The roll itself still happens only inside _enter_route_aim.
	var live_rng_state := {"seed": 20260820, "state": 20260820}
	var live_entry_rng_state: Dictionary = {}
	for _index in range(256):
		var candidate_input := live_rng_state.duplicate(true)
		var candidate_roll := TowerAscentRouteWindPolicy.roll_from_gameplay_state(
			candidate_input
		)
		live_rng_state = candidate_roll.get("gameplay_rng_state", {})
		var candidate_wind: Dictionary = candidate_roll.get("wind", {})
		if (
			bool(candidate_wind.get("is_windy", false))
			and int(candidate_wind.get("strength_level", 0)) == 3
		):
			live_entry_rng_state = candidate_input
			break
	if live_entry_rng_state.is_empty():
		_fail("visual QA could not find a deterministic strong-wind entry seed")
		owner.free()
		return
	flow.set("_gameplay_rng_state", live_entry_rng_state)
	if not flow.begin_vertical_slice(
		owner,
		Callable(),
		flow_context
	):
		_fail("production flow could not enter ROUTE_AIM")
		owner.free()
		return
	if flow.get_phase_name() != "ROUTE_AIM":
		_fail("production flow did not remain in ROUTE_AIM")
		owner.free()
		return
	var targets: Array[Dictionary] = flow.get_route_aim_targets()
	if targets.size() < 2:
		_fail("visual QA requires both route targets")
		owner.free()
		return
	for target in targets:
		var icon_presentation: Dictionary = target.get("icon_presentation", {})
		if not (icon_presentation.get("icon_texture", null) is Texture2D):
			_fail("route target did not load its shared map icon: %s" % target)
			owner.free()
			return

	var canvas := RouteCaptureCanvas.new()
	canvas.flow = flow
	canvas.battle_owner = owner
	canvas.renderer = TowerAscentFlowRenderer.new()
	var scale_factor := minf(
		float(VIEWPORT_SIZE.x) / PLAYFIELD_SIZE.x,
		float(VIEWPORT_SIZE.y) / PLAYFIELD_SIZE.y
	)
	canvas.scale = Vector2.ONE * scale_factor
	canvas.position = Vector2(
		(float(VIEWPORT_SIZE.x) - PLAYFIELD_SIZE.x * scale_factor) * 0.5,
		(float(VIEWPORT_SIZE.y) - PLAYFIELD_SIZE.y * scale_factor) * 0.5
	)
	var pillar_canvas := PillarCaptureCanvas.new()
	pillar_canvas.registry = registry
	pillar_canvas.game_offset = canvas.position
	pillar_canvas.game_size = PLAYFIELD_SIZE * scale_factor
	get_root().add_child(pillar_canvas)
	get_root().add_child(canvas)
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("could not create route wind capture directory")
		owner.free()
		return

	var route_runtime: Object = flow.get("_route_serve_runtime")
	if route_runtime == null:
		_fail("production flow did not expose its route serve runtime")
		owner.free()
		return
	var initial_pickups: Array[Dictionary] = flow.get_route_pickups()
	var gold_pickup := _first_pickup_of_kind(
		initial_pickups,
		TowerAscentRoutePickupState.KIND_GOLD
	)
	var muhon_pickup := _first_pickup_of_kind(
		initial_pickups,
		TowerAscentRoutePickupState.KIND_MUHON
	)
	if (
		_count_pickup_kind(initial_pickups, TowerAscentRoutePickupState.KIND_GOLD) < 2
		or _count_pickup_kind(initial_pickups, TowerAscentRoutePickupState.KIND_GOLD) > 5
		or _count_pickup_kind(initial_pickups, TowerAscentRoutePickupState.KIND_MUHON) < 2
		or _count_pickup_kind(initial_pickups, TowerAscentRoutePickupState.KIND_MUHON) > 5
		or _count_pickup_kind(initial_pickups, TowerAscentRoutePickupState.KIND_ACTIVE_ITEM) != 1
		or gold_pickup.is_empty()
		or muhon_pickup.is_empty()
	):
		_fail("production ROUTE_AIM did not expose the required 2-5/2-5/1 pickup set")
		owner.free()
		return
	var actual_entry_wind: Dictionary = flow.get_route_wind_model()
	var capture_models := [
		{
			"name": "route_wind_calm.png",
			"model": TowerAscentRouteWindPolicy.calm_model(),
		},
		{
			"name": "route_wind_max_left.png",
			"model": TowerAscentRouteWindPolicy.build_model(-1, 3),
		},
		{
			"name": "route_wind_max_right.png",
			"model": TowerAscentRouteWindPolicy.build_model(1, 3),
		},
	]
	var full_images: Array[Image] = []
	for capture_model in capture_models:
		_set_runtime_wind(route_runtime, capture_model["model"], 0.0)
		canvas.queue_redraw()
		for _frame in range(3):
			await process_frame
		var image := get_root().get_texture().get_image()
		var output_path := output_dir.path_join(str(capture_model["name"]))
		if image == null or image.is_empty() or image.save_png(output_path) != OK:
			_fail("could not save route wind capture: %s" % output_path)
			owner.free()
			return
		full_images.append(image)
	if full_images.size() != 3:
		_fail("route wind captures did not materialize all calm/left/right frames")
		owner.free()
		return
	var pickup_before_output := output_dir.path_join(
		"route_pickups_before_collect_2020x1246.png"
	)
	if full_images[2].save_png(pickup_before_output) != OK:
		_fail("could not save route pickup-before capture")
		owner.free()
		return
	var wind_origin: Vector2 = flow.get_route_aim_gauge_model().get(
		"origin",
		Vector2(380.0, 600.0)
	)
	var calm_wind_crop := _capture_region(
		full_images[0],
		canvas,
		_wind_panel_rect(wind_origin)
	)
	var windy_wind_crop := _capture_region(
		full_images[2],
		canvas,
		_wind_panel_rect(wind_origin)
	)
	if (
		calm_wind_crop == null
		or windy_wind_crop == null
		or _count_changed_pixels(calm_wind_crop, windy_wind_crop) < 80
	):
		_fail("calm/windy Vulkan crops did not prove the wind indicator visibility delta")
		owner.free()
		return

	var target_crop := _capture_region(
		full_images[0],
		canvas,
		Rect2(70.0, 75.0, 620.0, 205.0)
	)
	var target_output := output_dir.path_join("route_target_icons.png")
	if target_crop == null or target_crop.is_empty() or target_crop.save_png(target_output) != OK:
		_fail("could not save route target icon crop")
		owner.free()
		return

	var sweep_images: Array[Image] = []
	var sweep_hashes: Dictionary = {}
	var sweep_period := TowerAscentTuning.TEMP_ROUTE_AIM_SWEEP_PERIOD_SECONDS
	for frame_index in range(SWEEP_FRAME_COUNT):
		_set_runtime_wind(
			route_runtime,
			TowerAscentRouteWindPolicy.build_model(1, 3),
			sweep_period * float(frame_index) / float(SWEEP_FRAME_COUNT)
		)
		canvas.queue_redraw()
		await process_frame
		var frame_image := get_root().get_texture().get_image()
		var gauge_crop := _capture_region(
			frame_image,
			canvas,
			Rect2(215.0, 495.0, 435.0, 205.0)
		)
		if gauge_crop == null or gauge_crop.is_empty():
			_fail("could not crop sweep frame %d" % frame_index)
			owner.free()
			return
		sweep_images.append(gauge_crop)
		sweep_hashes[hash(gauge_crop.get_data())] = true
	# A sampled sine cycle has five mirrored pairs plus both extrema and center,
	# so twelve evenly spaced frames are expected to contain seven raster states.
	if sweep_hashes.size() < 7:
		_fail("continuous sweep strip did not preserve enough distinct frames: %d" % sweep_hashes.size())
		owner.free()
		return
	var strip := _build_strip(sweep_images, SWEEP_COLUMNS)
	var strip_output := output_dir.path_join("route_wind_sweep_strip.png")
	if strip == null or strip.is_empty() or strip.save_png(strip_output) != OK:
		_fail("could not save continuous sweep strip")
		owner.free()
		return

	var economy_before: Dictionary = flow.get_run_state_snapshot()
	if not _drive_ball_through_pickup(flow, owner, round_state, gold_pickup):
		_fail("production route ball did not collect the selected gold pickup")
		owner.free()
		return
	if not _drive_ball_through_pickup(flow, owner, round_state, muhon_pickup):
		_fail("production route ball did not collect the selected Muhon pickup")
		owner.free()
		return
	var economy_after: Dictionary = flow.get_run_state_snapshot()
	if (
		int(economy_after.get("gold", -1)) != int(economy_before.get("gold", -1)) + 1
		or int(economy_after.get("muhon", -1)) != int(economy_before.get("muhon", -1)) + 1
	):
		_fail("route currency pickup did not update the production Tower economy immediately")
		owner.free()
		return
	_set_runtime_wind(
		route_runtime,
		TowerAscentRouteWindPolicy.build_model(1, 3),
		0.0
	)
	pillar_canvas.queue_redraw()
	canvas.queue_redraw()
	for _frame in range(3):
		await process_frame
	var pickup_after_image := get_root().get_texture().get_image()
	var pickup_after_output := output_dir.path_join(
		"route_pickups_after_currency_2020x1246.png"
	)
	if (
		pickup_after_image == null
		or pickup_after_image.is_empty()
		or pickup_after_image.save_png(pickup_after_output) != OK
	):
		_fail("could not save route pickup-after capture")
		owner.free()
		return
	for collected_pickup in [gold_pickup, muhon_pickup]:
		var pickup_position: Vector2 = collected_pickup.get("position", Vector2.ZERO)
		var pickup_rect := Rect2(pickup_position - Vector2(28.0, 28.0), Vector2(56.0, 56.0))
		var before_crop := _capture_region(full_images[2], canvas, pickup_rect)
		var after_crop := _capture_region(pickup_after_image, canvas, pickup_rect)
		if (
			before_crop == null
			or after_crop == null
			or _count_changed_pixels(before_crop, after_crop) < 80
		):
			_fail("collected route pickup did not disappear visibly: %s" % collected_pickup)
			owner.free()
			return
	var pillar_renderer: Object = registry.instances.get("stage1_pillar_ui_renderer", null)
	var hud_layout: Dictionary = pillar_renderer.build_currency_hud_layout(
		canvas.position,
		PLAYFIELD_SIZE * scale_factor,
		{
			"height": PLAYFIELD_SIZE.y,
			"gold_hud_amount": int(economy_after.get("gold", 0)),
			"tower_muhon_hud_visible": true,
			"tower_muhon_hud_amount": int(economy_after.get("muhon", 0)),
		}
	)
	for hud_rect_key in ["gold_rect", "muhon_rect"]:
		var hud_rect: Rect2 = hud_layout.get(hud_rect_key, Rect2())
		var hud_before := _capture_absolute_region(full_images[2], hud_rect)
		var hud_after := _capture_absolute_region(pickup_after_image, hud_rect)
		if (
			hud_before == null
			or hud_after == null
			or _count_changed_pixels(hud_before, hud_after) < 8
		):
			_fail("route pickup did not visibly refresh the %s pillar HUD" % hud_rect_key)
			owner.free()
			return

	# Live compensated shot: restore the actual entry roll, observe it, wait for
	# the desired physical angle, and let the production route runtime resolve
	# the target. No debug_serve helper participates in this leg.
	_set_runtime_wind(route_runtime, actual_entry_wind, 0.0)
	input_reader.snapshot["mouse_left_just_pressed"] = false
	flow.update_selective(TowerAscentTuning.TEMP_ROUTE_AIM_ENTRY_ARM_SECONDS)
	var desired_target: Dictionary = targets[LIVE_TARGET_INDEX]
	var desired_target_id := str(desired_target.get("id", ""))
	var desired_position: Vector2 = desired_target.get("position", Vector2.ZERO)
	var ball_origin := BattleSceneOwnerReader.get_vector2(
		owner,
		"ball_pos",
		Vector2(380.0, 665.0)
	)
	var desired_angle := rad_to_deg(atan2(
		desired_position.x - ball_origin.x,
		ball_origin.y - desired_position.y
	))
	var angle_matched := false
	for _frame in range(960):
		var gauge_model: Dictionary = flow.get_route_aim_gauge_model()
		if absf(float(gauge_model.get("angle_degrees", 0.0)) - desired_angle) <= AIM_MATCH_TOLERANCE_DEGREES:
			angle_matched = true
			break
		flow.update_selective(1.0 / 240.0)
	if not angle_matched:
		_fail("live compensated shot could not traverse desired angle %.3f" % desired_angle)
		owner.free()
		return
	canvas.queue_redraw()
	for _frame in range(3):
		await process_frame
	var live_image := get_root().get_texture().get_image()
	var live_output := output_dir.path_join("route_live_compensated_aim.png")
	if live_image == null or live_image.is_empty() or live_image.save_png(live_output) != OK:
		_fail("could not save live compensated-aim capture")
		owner.free()
		return
	input_reader.snapshot["mouse_left_pressed"] = true
	input_reader.snapshot["mouse_left_just_pressed"] = true
	flow.update_selective(1.0 / 240.0)
	input_reader.snapshot["mouse_left_pressed"] = false
	input_reader.snapshot["mouse_left_just_pressed"] = false
	if not bool(BattleSceneOwnerReader.get_value(owner, "ball_active", false)):
		_fail("live compensated shot did not launch the production route ball")
		owner.free()
		return
	canvas.queue_redraw()
	for _frame in range(2):
		await process_frame
	var live_ball_image := get_root().get_texture().get_image()
	var live_ball_output := output_dir.path_join(
		"route_live_ball_in_flight_2020x1246.png"
	)
	if (
		live_ball_image == null
		or live_ball_image.is_empty()
		or live_ball_image.save_png(live_ball_output) != OK
	):
		_fail("could not save live route-ball capture")
		owner.free()
		return
	for _frame in range(LIVE_FLIGHT_LIMIT):
		if flow.get_phase_name() != "ROUTE_AIM":
			break
		flow.update_selective(1.0 / 60.0)
	if flow.get_phase_name() != "MAP_TRANSITION":
		_fail("live compensated shot did not reach a physical route target")
		owner.free()
		return
	if flow.get_selected_target_id() != desired_target_id:
		_fail(
			"live compensated shot selected %s instead of %s"
			% [flow.get_selected_target_id(), desired_target_id]
		)
		owner.free()
		return
	if not flow.get_route_pickups().is_empty():
		_fail("route target resolution did not clear all remaining pickups")
		owner.free()
		return
	pillar_canvas.queue_redraw()
	canvas.queue_redraw()
	for _frame in range(3):
		await process_frame
	var cleanup_image := get_root().get_texture().get_image()
	var cleanup_output := output_dir.path_join(
		"route_cleanup_after_target_2020x1246.png"
	)
	if (
		cleanup_image == null
		or cleanup_image.is_empty()
		or cleanup_image.save_png(cleanup_output) != OK
	):
		_fail("could not save route cleanup capture")
		owner.free()
		return

	print(
		"tower_route_serve_wind_target_visual_qa: ok "
		+ "wind=%s desired=%s angle=%.3f gold=%d muhon=%d pickups=%d captures=%d"
		% [
			actual_entry_wind,
			desired_target_id,
			desired_angle,
			int(economy_after.get("gold", -1)),
			int(economy_after.get("muhon", -1)),
			initial_pickups.size(),
			10,
		]
	)
	flow.call("_finish_vertical_slice")
	owner.free()
	quit(0)


func _prepare_owner(owner: Object) -> void:
	owner.set("current_stage", 4)
	owner.set("selected_character_type", "smasher")
	owner.set("player_pos", Vector2(302.5, 700.0))
	owner.set("player_speed", 0.0)
	owner.set("player_paddle_width", 155.0)
	owner.set("player_paddle_height", 50.0)
	owner.set("gameplay_frame_counter", 0)
	owner.set("ball_pos", Vector2(380.0, 665.0))
	owner.set("ball_vel", Vector2.ZERO)
	owner.set("ball_active", false)
	owner.set("ball_size", 28.6)
	owner.set("ball_impact_boost", 1.0)


func _set_runtime_wind(runtime: Object, model: Dictionary, elapsed: float) -> void:
	runtime.set("_wind_model", TowerAscentRouteWindPolicy.normalize_model(model))
	runtime.set("_aim_elapsed_seconds", elapsed)
	runtime.call("_update_aim_oscillator", 0.0)


func _first_pickup_of_kind(pickups: Array[Dictionary], kind: String) -> Dictionary:
	for pickup in pickups:
		if str(pickup.get("kind", "")) == kind:
			return pickup
	return {}


func _count_pickup_kind(pickups: Array[Dictionary], kind: String) -> int:
	var count := 0
	for pickup in pickups:
		if str(pickup.get("kind", "")) == kind:
			count += 1
	return count


func _drive_ball_through_pickup(
	flow: Object,
	owner: Object,
	round_state: FakeRoundState,
	pickup: Dictionary
) -> bool:
	var pickup_id := str(pickup.get("id", ""))
	var pickup_position: Vector2 = pickup.get("position", Vector2.ZERO)
	if pickup_id.is_empty() or pickup_position == Vector2.ZERO:
		return false
	round_state.waiting = false
	owner.set("ball_pos", pickup_position + Vector2(0.0, 52.0))
	owner.set("ball_vel", Vector2(0.0, -8.7))
	owner.set("ball_active", true)
	for _frame in range(24):
		flow.update_selective(1.0 / 60.0)
		if not _pickup_list_has_id(flow.get_route_pickups(), pickup_id):
			_reset_visual_route_ball(owner, round_state)
			return true
	_reset_visual_route_ball(owner, round_state)
	return false


func _pickup_list_has_id(pickups: Array[Dictionary], pickup_id: String) -> bool:
	for pickup in pickups:
		if str(pickup.get("id", "")) == pickup_id:
			return true
	return false


func _reset_visual_route_ball(owner: Object, round_state: FakeRoundState) -> void:
	round_state.waiting = true
	owner.set("ball_pos", Vector2(380.0, 665.0))
	owner.set("ball_vel", Vector2.ZERO)
	owner.set("ball_active", false)


func _wind_panel_rect(origin: Vector2) -> Rect2:
	var panel_size := TowerAscentTuning.TEMP_ROUTE_WIND_PANEL_SIZE
	var panel_x := (
		origin.x
		+ TowerAscentTuning.TEMP_ROUTE_AIM_GAUGE_RADIUS
		+ TowerAscentTuning.TEMP_ROUTE_WIND_PANEL_GAP
	)
	if panel_x + panel_size.x > PLAYFIELD_SIZE.x - 12.0:
		panel_x = (
			origin.x
			- TowerAscentTuning.TEMP_ROUTE_AIM_GAUGE_RADIUS
			- TowerAscentTuning.TEMP_ROUTE_WIND_PANEL_GAP
			- panel_size.x
		)
	return Rect2(Vector2(panel_x, origin.y - panel_size.y * 0.5), panel_size)


func _capture_region(image: Image, canvas: Node2D, canvas_rect: Rect2) -> Image:
	if image == null or image.is_empty():
		return null
	var capture_rect := Rect2(
		canvas.position + canvas_rect.position * canvas.scale,
		canvas_rect.size * canvas.scale
	).intersection(Rect2(Vector2.ZERO, Vector2(image.get_size())))
	if capture_rect.size.x < 1.0 or capture_rect.size.y < 1.0:
		return null
	return image.get_region(Rect2i(capture_rect))


func _capture_absolute_region(image: Image, screen_rect: Rect2) -> Image:
	if image == null or image.is_empty():
		return null
	var capture_rect := screen_rect.intersection(
		Rect2(Vector2.ZERO, Vector2(image.get_size()))
	)
	if capture_rect.size.x < 1.0 or capture_rect.size.y < 1.0:
		return null
	return image.get_region(Rect2i(capture_rect))


func _count_changed_pixels(first: Image, second: Image) -> int:
	if (
		first == null
		or second == null
		or first.is_empty()
		or second.is_empty()
		or first.get_size() != second.get_size()
	):
		return 0
	var changed := 0
	for y in range(first.get_height()):
		for x in range(first.get_width()):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) >= PIXEL_DIFF_THRESHOLD:
				changed += 1
	return changed


func _build_strip(images: Array[Image], columns: int) -> Image:
	if images.is_empty() or columns <= 0:
		return null
	var cell_size := images[0].get_size()
	var rows := ceili(float(images.size()) / float(columns))
	var strip := Image.create(
		cell_size.x * columns,
		cell_size.y * rows,
		false,
		images[0].get_format()
	)
	strip.fill(Color("090706"))
	for index in range(images.size()):
		strip.blit_rect(
			images[index],
			Rect2i(Vector2i.ZERO, cell_size),
			Vector2i(index % columns, index / columns) * cell_size
		)
	return strip


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)
	quit(1)
