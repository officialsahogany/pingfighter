extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const OUTPUT_DIR := "res://../.tmp/codex_stage2_cheongringwi/captures"
const OUTPUT_IDLE_NAME := "stage2_cheongringwi_idle_windowed.png"
const OUTPUT_LEFT_NAME := "stage2_cheongringwi_walk_left_windowed.png"
const OUTPUT_RIGHT_NAME := "stage2_cheongringwi_walk_right_windowed.png"
const OUTPUT_ATTACK_NAME := "stage2_cheongringwi_attack_impact_windowed.png"
const OUTPUT_QUAKE_NAME := "stage2_cheongringwi_quake_impact_windowed.png"
const OUTPUT_SPEED_DEFENSE_NAME := "stage2_cheongringwi_scale_ward_windowed.png"
const WALK_FRAME_INTERVAL_MS := 70.0
const WALK_FRAME_COUNT := 8
const QUAKE_DURATION_SEC := 80.0 / 60.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("stage2_cheongringwi_visual_qa_capture requires a windowed renderer")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_title("Stage 2 Cheongringwi Visual QA")
	_prepare_selection_state()
	var main_node: Node = MainScene.instantiate()
	get_root().add_child(main_node)
	await process_frame
	await process_frame
	_prepare_battle_scene(main_node)
	var capture_error: int = await _capture_idle(main_node)
	if capture_error != OK:
		quit(1)
		return
	var left_capture_error: int = await _capture_walk_direction(
		main_node,
		-1,
		430.0,
		5,
		OUTPUT_LEFT_NAME
	)
	if left_capture_error != OK:
		quit(1)
		return
	var right_capture_error: int = await _capture_walk_direction(
		main_node,
		1,
		230.0,
		6,
		OUTPUT_RIGHT_NAME
	)
	if right_capture_error != OK:
		quit(1)
		return
	capture_error = await _capture_attack(main_node)
	if capture_error != OK:
		quit(1)
		return
	capture_error = await _capture_quake(main_node)
	if capture_error != OK:
		quit(1)
		return
	capture_error = await _capture_speed_defense(main_node)
	if capture_error != OK:
		quit(1)
		return
	print("stage2_cheongringwi_visual_qa_capture: ok")
	main_node.queue_free()
	await process_frame
	quit(0)


func _capture_idle(main_node: Node) -> int:
	for _frame in range(6):
		_force_idle(main_node)
		await process_frame
	return _save_viewport_capture(OUTPUT_IDLE_NAME)


func _capture_walk_direction(
	main_node: Node,
	direction: int,
	start_x: float,
	target_frame: int,
	output_name: String
) -> int:
	var boss_y := 25.0
	for step in range(42):
		var travel_x := float(direction) * float(step) * 1.2
		_force_walk(main_node, direction, Vector2(start_x + travel_x, boss_y))
		await process_frame
	for _attempt in range(WALK_FRAME_COUNT * 6):
		_force_walk(main_node, direction, main_node.get("boss_pos") as Vector2)
		await process_frame
		if _get_runtime_walk_frame() == target_frame:
			break
	return _save_viewport_capture(output_name)


func _force_walk(main_node: Node, direction: int, boss_position: Vector2) -> void:
	_clear_stage2_skill_overrides(main_node)
	main_node.set("boss_pos", boss_position)
	main_node.set("boss_vel", float(direction) * 3.0)
	var actor_animation_state: Object = _get_module(main_node, "actor_animation_state")
	if actor_animation_state != null:
		var boss_state: Variant = actor_animation_state.get("boss_state")
		if typeof(boss_state) == TYPE_OBJECT and is_instance_valid(boss_state):
			boss_state.set("facing", direction)
			boss_state.set("is_walking", true)
			boss_state.set("hit_active", false)
	if main_node.has_method("queue_redraw"):
		main_node.queue_redraw()


func _capture_attack(main_node: Node) -> int:
	for _frame in range(6):
		_force_attack(main_node)
		await process_frame
	return _save_viewport_capture(OUTPUT_ATTACK_NAME)


func _capture_quake(main_node: Node) -> int:
	for _frame in range(6):
		_force_quake(main_node)
		await process_frame
	return _save_viewport_capture(OUTPUT_QUAKE_NAME)


func _capture_speed_defense(main_node: Node) -> int:
	for _frame in range(6):
		_force_speed_defense(main_node)
		await process_frame
	return _save_viewport_capture(OUTPUT_SPEED_DEFENSE_NAME)


func _force_idle(main_node: Node) -> void:
	_clear_stage2_skill_overrides(main_node)
	main_node.set("boss_pos", Vector2(325.0, 25.0))
	main_node.set("boss_vel", 0.0)
	_set_boss_animation_state(main_node, false, false, 0)
	main_node.queue_redraw()


func _force_attack(main_node: Node) -> void:
	_clear_stage2_skill_overrides(main_node)
	main_node.set("boss_pos", Vector2(325.0, 25.0))
	main_node.set("boss_vel", 0.0)
	_set_boss_animation_state(main_node, false, true, 4)
	main_node.queue_redraw()


func _force_quake(main_node: Node) -> void:
	_clear_stage2_skill_overrides(main_node)
	main_node.set("boss_pos", Vector2(325.0, 25.0))
	main_node.set("boss_vel", 0.0)
	_set_boss_animation_state(main_node, false, false, 0)
	var background: Object = _get_module(main_node, "stage2_pillar_background")
	if background != null:
		background.set("quake_duration", QUAKE_DURATION_SEC)
		background.set("quake_timer", QUAKE_DURATION_SEC * 0.5)
	main_node.queue_redraw()


func _force_speed_defense(main_node: Node) -> void:
	_clear_stage2_skill_overrides(main_node)
	main_node.set("boss_pos", Vector2(325.0, 25.0))
	main_node.set("boss_vel", 0.0)
	_set_boss_animation_state(main_node, false, false, 0)
	var skill_state: Object = _get_module(main_node, "stage2_boss_skill_state")
	if skill_state != null:
		skill_state.set("speed_defense_active", true)
		skill_state.set("speed_defense_timer", 1.0)
		skill_state.set("speed_defense_trails", [])
	main_node.queue_redraw()


func _clear_stage2_skill_overrides(main_node: Node) -> void:
	var background: Object = _get_module(main_node, "stage2_pillar_background")
	if background != null:
		background.set("quake_timer", 0.0)
	var skill_state: Object = _get_module(main_node, "stage2_boss_skill_state")
	if skill_state != null:
		skill_state.set("speed_defense_active", false)
		skill_state.set("speed_defense_timer", 0.0)
		skill_state.set("speed_defense_trails", [])


func _set_boss_animation_state(main_node: Node, walking: bool, hit_active: bool, hit_frame: int) -> void:
	var actor_animation_state: Object = _get_module(main_node, "actor_animation_state")
	if actor_animation_state == null:
		return
	var boss_state: Variant = actor_animation_state.get("boss_state")
	if typeof(boss_state) != TYPE_OBJECT or not is_instance_valid(boss_state):
		return
	boss_state.set("facing", 1)
	boss_state.set("is_walking", walking)
	boss_state.set("hit_active", hit_active)
	boss_state.set("hit_frame", hit_frame)


func _get_runtime_walk_frame() -> int:
	return int(floor(float(Time.get_ticks_msec()) / WALK_FRAME_INTERVAL_MS)) % WALK_FRAME_COUNT


func _save_viewport_capture(output_name: String) -> int:
	var image: Image = get_root().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Stage 2 Cheongringwi QA viewport capture was empty")
		return ERR_CANT_CREATE
	var output_dir_abs := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_dir_abs)
	var output_path := output_dir_abs.path_join(output_name)
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("Stage 2 Cheongringwi QA capture save failed (%d): %s" % [save_error, output_path])
		return save_error
	print("stage2_cheongringwi_visual_qa_capture: %s" % output_path)
	return OK


func _prepare_selection_state() -> void:
	var selection_state := get_root().get_node_or_null("GameSelectionState")
	if selection_state == null:
		return
	if selection_state.has_method("set_character"):
		selection_state.set_character({
			"id": "smasher",
			"runtime_id": "smasher",
			"name": "스매셔",
		})
	if selection_state.has_method("set_stage"):
		selection_state.set_stage(2)
	if selection_state.has_method("set_league_mode"):
		selection_state.set_league_mode("champion")
	if selection_state.has_method("request_skip_battle_logo_once"):
		selection_state.request_skip_battle_logo_once()


func _prepare_battle_scene(main_node: Node) -> void:
	main_node.set("current_stage", 2)
	main_node.set("selected_character_type", "smasher")
	main_node.set("selected_runtime_character_id", "smasher")
	main_node.set("selected_character_id", "smasher")
	main_node.set("selected_character_name", "스매셔")
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
	var round_state: Object = _get_module(main_node, "round_flow_state")
	if round_state != null and round_state.has_method("begin_serve"):
		round_state.begin_serve(Time.get_ticks_msec())
	# Keep the ball inactive in this composition probe. The production battle
	# resource boot is intentionally bypassed above, so this capture only owns
	# the Stage 2 map, boss, player, frame, and HUD surfaces.
	main_node.set("ball_active", false)
	main_node.set("boss_pos", Vector2(325.0, 25.0))
	main_node.set("player_pos", Vector2(310.0, 650.0))
	main_node.queue_redraw()


func _get_module(main_node: Node, key: String) -> Object:
	if main_node == null or not main_node.has_method("_get_module"):
		return null
	var value: Variant = main_node.call("_get_module", key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null
