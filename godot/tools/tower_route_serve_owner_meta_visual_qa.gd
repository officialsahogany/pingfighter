extends SceneTree

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const BattleSceneOwnerReader := preload(
	"res://scripts/core/battle_scene_owner_reader.gd"
)
const MainScene := preload("res://scenes/main.tscn")
const Stage1PillarUiRenderer := preload(
	"res://scripts/hud/stage1_pillar_ui_renderer.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)

const OUTPUT_DIR := "res://.godot/codex_captures/tower_route_serve_owner_meta"
const OUTPUT_NAME := "route_aim_live_owner.png"
const ANGLE_GAUGE_OUTPUT_NAME := "route_aim_angle_gauge.png"
const MUHON_HUD_OUTPUT_NAME := "battle_hud_muhon.png"
const TOP_BOUNCE_OUTPUT_NAME := "route_aim_top_wall_bounce.png"
const INITIAL_PLAYER_POS := Vector2(230.0, 680.0)
const ROUTE_FLIGHT_STEPS := 14


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("tower route-serve owner-meta visual QA requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("tower route-serve owner-meta visual QA requires a Vulkan rendering device")
		return
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_release_test_input()
	DisplayServer.window_set_size(Vector2i(1520, 1000))
	DisplayServer.window_set_title("승천탑 ROUTE_AIM 라이브 owner QA")
	if not _prepare_selection_state():
		_fail("GameSelectionState was unavailable for the route-serve live-owner capture")
		return

	var main_node: Node = MainScene.instantiate()
	get_root().add_child(main_node)
	for _frame in range(4):
		await process_frame
	_prepare_battle_scene(main_node)
	main_node.set_process(false)
	main_node.set_physics_process(false)
	for _frame in range(2):
		await process_frame

	var registry: Object = main_node.get("gameplay_modules")
	var tower_flow: Object = _get_module(main_node, "tower_ascent_flow_owner")
	if registry == null or tower_flow == null:
		_fail("live battle scene did not expose the tower flow and gameplay registry")
		return
	if not bool(tower_flow.begin_vertical_slice(
		main_node,
		Callable(),
		{
			"registry": registry,
			"run_id": "owner-meta-visual-qa",
			"current_stage": 4,
			"map_seed": 83521,
		}
	)):
		_fail("live battle scene could not enter ROUTE_AIM")
		return
	if str(tower_flow.get_phase_name()) != "ROUTE_AIM":
		_fail("live battle scene did not remain in ROUTE_AIM")
		return
	var collect_result: Dictionary = tower_flow.collect_muhon(8, main_node)
	if not bool(collect_result.get("accepted", false)):
		_fail("live tower flow could not seed the Muhon HUD evidence")
		return
	var gauge_model: Dictionary = tower_flow.get_route_aim_gauge_model()
	if not bool(gauge_model.get("visible", false)):
		_fail("live ROUTE_AIM did not expose the waiting angle gauge")
		return
	main_node.queue_redraw()
	for _frame in range(10):
		await process_frame
		main_node.queue_redraw()
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("could not create tower route-serve capture directory")
		return
	var gauge_output_path := output_dir.path_join(ANGLE_GAUGE_OUTPUT_NAME)
	var muhon_output_path := output_dir.path_join(MUHON_HUD_OUTPUT_NAME)
	var waiting_image := get_root().get_texture().get_image()
	if (
		waiting_image == null
		or waiting_image.is_empty()
		or waiting_image.save_png(gauge_output_path) != OK
	):
		_fail("could not save live angle-gauge capture: %s" % gauge_output_path)
		return
	var layout_module: Object = _get_module(main_node, "battle_view_layout")
	if layout_module == null or not layout_module.has_method("build_game_layout"):
		_fail("live battle view layout was unavailable for the Muhon-HUD crop")
		return
	var viewport_size: Vector2 = get_root().get_visible_rect().size
	var layout: Dictionary = layout_module.build_game_layout(
		viewport_size,
		BattleSceneConfig.WIDTH,
		BattleSceneConfig.HEIGHT
	)
	var game_offset: Vector2 = layout.get("game_offset", Vector2.ZERO)
	var game_size: Vector2 = layout.get("game_size", Vector2.ZERO)
	var hud_renderer := Stage1PillarUiRenderer.new()
	var hud_context := {"height": BattleSceneConfig.HEIGHT, "gold_hud_amount": 0}
	var gold_rect: Rect2 = hud_renderer.build_gold_hud_rect(game_offset, game_size, hud_context)
	var muhon_rect: Rect2 = hud_renderer.build_muhon_hud_rect(game_offset, game_size, hud_context)
	var capture_scale := Vector2(
		float(waiting_image.get_width()) / maxf(1.0, viewport_size.x),
		float(waiting_image.get_height()) / maxf(1.0, viewport_size.y)
	)
	var hud_rect_in_capture := Rect2(
		gold_rect.merge(muhon_rect).grow(18.0).position * capture_scale,
		gold_rect.merge(muhon_rect).grow(18.0).size * capture_scale
	)
	var hud_crop_rect := Rect2i(
		hud_rect_in_capture.intersection(
			Rect2(Vector2.ZERO, Vector2(waiting_image.get_size()))
		)
	)
	var hud_image := waiting_image.get_region(hud_crop_rect)
	if hud_image == null or hud_image.is_empty() or hud_image.save_png(muhon_output_path) != OK:
		_fail("could not save live Muhon-HUD capture: %s" % muhon_output_path)
		return

	var initial_player_pos := BattleSceneOwnerReader.get_vector2(
		main_node,
		"player_pos",
		Vector2.ZERO
	)
	Input.action_press("ui_right")
	_set_left_mouse_pressed(true)
	await process_frame
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_fail("visual QA could not publish the raw left-mouse pressed state")
		return
	tower_flow.update_selective(1.0 / 60.0, main_node)
	_set_left_mouse_pressed(false)
	for _step in range(ROUTE_FLIGHT_STEPS - 1):
		tower_flow.update_selective(1.0 / 60.0, main_node)
	Input.action_release("ui_right")

	var moved_player_pos := BattleSceneOwnerReader.get_vector2(
		main_node,
		"player_pos",
		Vector2.ZERO
	)
	var ball_pos := BattleSceneOwnerReader.get_vector2(
		main_node,
		"ball_pos",
		Vector2.ZERO
	)
	if moved_player_pos.x <= initial_player_pos.x:
		_fail("live ROUTE_AIM player did not move through the meta-backed owner")
		return
	if moved_player_pos.y < BattleSceneConfig.HEIGHT * 0.72:
		_fail("live ROUTE_AIM player left the lower paddle band: %s" % moved_player_pos)
		return
	if not bool(BattleSceneOwnerReader.get_value(main_node, "ball_active", false)):
		_fail("live ROUTE_AIM serve ball was not active after launch")
		return
	if ball_pos.y >= moved_player_pos.y or ball_pos.y <= BattleSceneConfig.HEIGHT * 0.20:
		_fail("live ROUTE_AIM serve ball was not visibly in flight: %s" % ball_pos)
		return
	if str(tower_flow.get_phase_name()) != "ROUTE_AIM":
		_fail("route selection resolved before the in-flight evidence frame")
		return

	main_node.queue_redraw()
	for _frame in range(10):
		await process_frame
		main_node.queue_redraw()
	var output_path := output_dir.path_join(OUTPUT_NAME)
	if not _save_viewport_capture(output_path):
		_fail("could not save tower route-serve live-owner capture: %s" % output_path)
		return

	# Force only the pre-collision state; the production route runtime and shared
	# ball-motion stepper must own the actual top-wall event and reflected state.
	var ball_radius := float(BattleSceneOwnerReader.get_value(main_node, "ball_size", 28.6)) * 0.5
	main_node.set("ball_pos", Vector2(BattleSceneConfig.WIDTH * 0.5, ball_radius + 1.0))
	main_node.set("ball_vel", Vector2(0.0, -8.0))
	main_node.set("ball_active", true)
	tower_flow.update_selective(1.0 / 60.0, main_node)
	var bounced_position := BattleSceneOwnerReader.get_vector2(main_node, "ball_pos", Vector2.ZERO)
	var bounced_velocity := BattleSceneOwnerReader.get_vector2(main_node, "ball_vel", Vector2.ZERO)
	if bounced_velocity.y <= 0.0 or bounced_position.y < ball_radius - 0.1:
		_fail("live ROUTE_AIM top-wall reflection did not publish the owner snapshot: pos=%s vel=%s" % [bounced_position, bounced_velocity])
		return
	main_node.queue_redraw()
	for _frame in range(4):
		await process_frame
		main_node.queue_redraw()
	var bounce_output_path := output_dir.path_join(TOP_BOUNCE_OUTPUT_NAME)
	if not _save_viewport_capture(bounce_output_path):
		_fail("could not save top-wall bounce capture: %s" % bounce_output_path)
		return
	print("[TowerRouteServeOwnerMetaVisualQA] player=%s ball=%s evidence=%s" % [
		moved_player_pos,
		ball_pos,
		output_path,
	])
	print("[TowerRouteServeOwnerMetaVisualQA] angle_gauge=%s muhon_hud=%s" % [
		gauge_output_path,
		muhon_output_path,
	])
	print("[TowerRouteServeOwnerMetaVisualQA] top_bounce_pos=%s top_bounce_vel=%s evidence=%s" % [
		bounced_position,
		bounced_velocity,
		bounce_output_path,
	])
	print("tower_route_serve_owner_meta_visual_qa: captures=4")
	print("tower_route_serve_owner_meta_visual_qa: ok")
	_cleanup(main_node)
	quit(0)


func _prepare_selection_state() -> bool:
	var selection_state := get_root().get_node_or_null("GameSelectionState")
	if selection_state == null or not selection_state.has_method("set_stage"):
		return false
	if selection_state.has_method("set_character"):
		selection_state.set_character({
			"id": "smasher",
			"runtime_id": "smasher",
			"name": "스매셔",
		})
	selection_state.set_stage(4)
	if selection_state.has_method("set_league_mode"):
		selection_state.set_league_mode("champion")
	if selection_state.has_method("request_skip_battle_logo_once"):
		selection_state.request_skip_battle_logo_once()
	return true


func _prepare_battle_scene(main_node: Node) -> void:
	if main_node.has_method("_initialize_battle"):
		main_node.call("_initialize_battle", false)
	if main_node.has_method("configure_player_character"):
		main_node.call("configure_player_character", "smasher")
	var warmup: Object = _get_module(main_node, "battle_boot_warmup_controller")
	if warmup != null:
		warmup.set("boot_warmup_finished", true)
		warmup.set("boot_warmup_step", 999)
	var logo_intro: Object = _get_module(main_node, "penguin_logo_intro")
	if logo_intro != null:
		logo_intro.set("active", false)
	var battle_flow: Object = _get_module(main_node, "battle_scene_flow_controller")
	if battle_flow != null:
		battle_flow.set("_battle_initialized", true)
		battle_flow.set("_stage_landing_intro_started", true)
		battle_flow.set("_ball_spawn_intro_started", true)
	var landing_intro: Object = _get_module(main_node, "stage_landing_intro")
	if landing_intro != null:
		landing_intro.set("active", false)
	var ball_spawn_intro: Object = _get_module(main_node, "stage_ball_spawn_intro")
	if ball_spawn_intro != null:
		if ball_spawn_intro.has_method("reset"):
			ball_spawn_intro.reset()
		ball_spawn_intro.set("active", false)
		ball_spawn_intro.set("overlay_active", false)
	main_node.set("player_pos", INITIAL_PLAYER_POS)
	main_node.set("player_speed", 0.0)
	main_node.set("ball_pos", Vector2(307.5, 650.0))
	main_node.set("ball_vel", Vector2.ZERO)
	main_node.set("ball_active", false)
	main_node.set("boss_pos", Vector2(325.0, 25.0))
	main_node.queue_redraw()


func _get_module(main_node: Node, key: String) -> Object:
	if main_node == null or not main_node.has_method("_get_module"):
		return null
	var value: Variant = main_node.call("_get_module", key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _save_viewport_capture(output_path: String) -> bool:
	var image := get_root().get_texture().get_image()
	return image != null and not image.is_empty() and image.save_png(output_path) == OK


func _release_test_input() -> void:
	for action_name in ["ui_left", "ui_right", "ui_accept"]:
		Input.action_release(action_name)
	_set_left_mouse_pressed(false)


func _set_left_mouse_pressed(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = Vector2(760.0, 500.0)
	Input.parse_input_event(event)


func _cleanup(main_node: Node) -> void:
	_release_test_input()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if main_node != null and is_instance_valid(main_node):
		main_node.queue_free()


func _fail(message: String) -> void:
	_release_test_input()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	push_error(message)
	quit(1)
