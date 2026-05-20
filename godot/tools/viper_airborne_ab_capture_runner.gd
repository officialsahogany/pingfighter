extends SceneTree

const CaptureDriver := preload("res://tools/viper_airborne_ab_capture_driver.gd")
const MainScene := preload("res://scenes/main.tscn")

const CAPTURE_STAGE_ENV := "PINGFIGHTER_VIPER_AB_STAGE"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var capture_stage := _get_capture_stage()
	OS.set_environment("PINGFIGHTER_BATTLE_PERF_LOG", "1")
	OS.set_environment("PINGFIGHTER_BATTLE_PERF_DETAIL", "0")
	OS.set_environment("PINGFIGHTER_BATTLE_PERF_SAMPLES", "0")
	OS.set_environment("PINGFIGHTER_BATTLE_PERF_GAP_MSEC", "0")
	print("[ViperAB] capture stage=%d env=%s" % [capture_stage, CAPTURE_STAGE_ENV])
	_prepare_selection_state(capture_stage)
	_prepare_window(capture_stage)
	var main_node: Node = MainScene.instantiate()
	get_root().add_child(main_node)
	await process_frame
	await process_frame
	_prepare_battle_scene(main_node, capture_stage)
	var driver: Node = CaptureDriver.new()
	driver.configure(main_node, capture_stage)
	get_root().add_child(driver)
	var summaries: Array[Dictionary] = await driver.capture_finished
	_print_comparison(summaries)
	main_node.queue_free()
	await process_frame
	quit(0)


func _get_capture_stage() -> int:
	var raw_value := OS.get_environment(CAPTURE_STAGE_ENV).strip_edges()
	if raw_value == "" or not raw_value.is_valid_int():
		return 1
	return max(1, int(raw_value))


func _prepare_selection_state(capture_stage: int) -> void:
	var selection_state := get_root().get_node_or_null("GameSelectionState")
	if selection_state == null:
		return
	if selection_state.has_method("set_character"):
		selection_state.set_character({
			"id": "viper",
			"runtime_id": "viper",
			"name": "세린",
		})
	if selection_state.has_method("set_stage"):
		selection_state.set_stage(capture_stage)
	if selection_state.has_method("set_league_mode"):
		selection_state.set_league_mode("champion")
	if selection_state.has_method("request_skip_battle_logo_once"):
		selection_state.request_skip_battle_logo_once()


func _prepare_window(capture_stage: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_title("Viper Airborne A/B Capture - Stage %d" % capture_stage)


func _prepare_battle_scene(main_node: Node, capture_stage: int) -> void:
	if main_node == null:
		return
	main_node.set("current_stage", capture_stage)
	main_node.set("selected_character_type", "viper")
	main_node.set("selected_runtime_character_id", "viper")
	main_node.set("selected_character_id", "viper")
	main_node.set("selected_character_name", "세린")
	if main_node.has_method("_initialize_battle"):
		main_node.call("_initialize_battle", false)
	if main_node.has_method("configure_player_character"):
		main_node.call("configure_player_character", "viper")
	_force_warmup_finished(main_node)
	_force_intro_finished(main_node)
	_force_round_active(main_node)
	if main_node.has_method("queue_redraw"):
		main_node.queue_redraw()


func _force_warmup_finished(main_node: Node) -> void:
	var warmup: Object = _get_module(main_node, "battle_boot_warmup_controller")
	if warmup == null:
		return
	warmup.set("boot_warmup_finished", true)
	warmup.set("boot_warmup_step", 999)


func _force_intro_finished(main_node: Node) -> void:
	var logo_intro: Object = _get_module(main_node, "penguin_logo_intro")
	if logo_intro != null:
		logo_intro.set("active", false)
	var flow: Object = _get_module(main_node, "battle_scene_flow_controller")
	if flow != null:
		flow.set("_battle_initialized", true)
		flow.set("_stage_landing_intro_started", true)
		flow.set("_ball_spawn_intro_started", true)
	var landing_intro: Object = _get_module(main_node, "stage_landing_intro")
	if landing_intro != null:
		landing_intro.set("active", false)
	var ball_spawn_intro: Object = _get_module(main_node, "stage_ball_spawn_intro")
	if ball_spawn_intro != null:
		if ball_spawn_intro.has_method("reset"):
			ball_spawn_intro.reset()
		ball_spawn_intro.set("active", false)
		ball_spawn_intro.set("overlay_active", false)


func _force_round_active(main_node: Node) -> void:
	var round_state: Object = _get_module(main_node, "round_flow_state")
	if round_state != null and round_state.has_method("begin_serve"):
		round_state.begin_serve(Time.get_ticks_msec())


func _get_module(main_node: Node, key: String) -> Object:
	if main_node == null or not main_node.has_method("_get_module"):
		return null
	var value: Variant = main_node.call("_get_module", key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _print_comparison(summaries: Array[Dictionary]) -> void:
	print("[ViperAB] complete summaries=%d" % summaries.size())
	if summaries.is_empty():
		return
	var baseline: Dictionary = summaries[0]
	var baseline_calls: float = float(baseline.get("calls_avg", 0.0))
	var baseline_prims: float = float(baseline.get("prims_avg", 0.0))
	var baseline_delta: float = float(baseline.get("delta_max_ms", 0.0))
	for summary in summaries:
		var mode_id := str(summary.get("id", ""))
		var calls_avg := float(summary.get("calls_avg", 0.0))
		var prims_avg := float(summary.get("prims_avg", 0.0))
		var delta_max := float(summary.get("delta_max_ms", 0.0))
		print(
			"[ViperAB-Compare] mode=%s calls_delta=%+.1f prims_delta=%+.1f delta_max_delta=%+.2fms"
			% [
				mode_id,
				calls_avg - baseline_calls,
				prims_avg - baseline_prims,
				delta_max - baseline_delta,
			]
		)
