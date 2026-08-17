extends SceneTree

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const BattleSceneOwnerReader := preload(
	"res://scripts/core/battle_scene_owner_reader.gd"
)
const MainScene := preload("res://scenes/main.tscn")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)

const OUTPUT_DIR := "res://.godot/codex_captures/tower_route_serve_owner_meta"
const OUTPUT_NAME := "route_aim_live_owner.png"
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

	var initial_player_pos := BattleSceneOwnerReader.get_vector2(
		main_node,
		"player_pos",
		Vector2.ZERO
	)
	Input.action_press("ui_right")
	Input.action_press("ui_accept")
	tower_flow.update_selective(1.0 / 60.0, main_node)
	Input.action_release("ui_accept")
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
	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("tower route-serve live-owner capture was empty")
		return
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("could not create tower route-serve capture directory")
		return
	var output_path := output_dir.path_join(OUTPUT_NAME)
	if image.save_png(output_path) != OK:
		_fail("could not save tower route-serve live-owner capture: %s" % output_path)
		return
	print("[TowerRouteServeOwnerMetaVisualQA] player=%s ball=%s evidence=%s" % [
		moved_player_pos,
		ball_pos,
		output_path,
	])
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


func _release_test_input() -> void:
	for action_name in ["ui_left", "ui_right", "ui_accept"]:
		Input.action_release(action_name)


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
