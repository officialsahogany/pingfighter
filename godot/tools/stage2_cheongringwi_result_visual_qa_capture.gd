extends SceneTree

const StageClearResultScene := preload("res://scenes/stage_clear_result.tscn")
const StageClearResultConfigSceneHandler := preload("res://scripts/ui/stage_clear_result_config_scene_handler.gd")
const StageClearResultStatusSceneHandler := preload("res://scripts/ui/stage_clear_result_status_scene_handler.gd")
const StageClearResultUpdateSceneHandler := preload("res://scripts/ui/stage_clear_result_update_scene_handler.gd")

const OUTPUT_DIR := "res://../.tmp/codex_stage2_cheongringwi/captures"
const IDLE_OUTPUT_NAME := "stage2_cheongringwi_result_idle_windowed.png"
const CLICK_OUTPUT_NAME := "stage2_cheongringwi_result_click_windowed.png"
const RETURN_OUTPUT_NAME := "stage2_cheongringwi_result_return_windowed.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("stage2_cheongringwi_result_visual_qa_capture requires a windowed renderer")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 800))
	DisplayServer.window_set_title("Stage 2 Cheongringwi Result Visual QA")
	var result_scene: Control = StageClearResultScene.instantiate()
	StageClearResultConfigSceneHandler.configure(
		result_scene,
		{
			"player_score": 5,
			"boss_score": 0,
			"current_stage": 2,
			"selected_character_type": "smasher",
			"reward_plan": {},
			"stage_reward_snapshot": {},
		},
		Callable()
	)
	get_root().add_child(result_scene)
	result_scene.set("timer", 0.62)
	result_scene.queue_redraw()
	await _settle_frames(12)
	var capture_error := _save_viewport_capture(IDLE_OUTPUT_NAME)
	if capture_error != OK:
		quit(1)
		return
	var status: Dictionary = StageClearResultStatusSceneHandler.get_interaction_status(result_scene, "")
	var click_rect: Rect2 = status.get("stage2_boss_defeat_click_rect", Rect2())
	if click_rect.size.x <= 0.0 or click_rect.size.y <= 0.0:
		push_error("Stage 2 Cheongringwi result click rect was unavailable")
		quit(1)
		return
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = click_rect.get_center()
	result_scene.call(&"_gui_input", click_event)
	StageClearResultUpdateSceneHandler.update_result_scene(result_scene, 1.05)
	result_scene.queue_redraw()
	await _settle_frames(3)
	status = StageClearResultStatusSceneHandler.get_interaction_status(result_scene, "")
	if not bool(status.get("stage2_boss_defeat_click_reaction_active", false)):
		push_error("Stage 2 Cheongringwi result click reaction did not activate")
		quit(1)
		return
	capture_error = _save_viewport_capture(CLICK_OUTPUT_NAME)
	if capture_error != OK:
		quit(1)
		return
	StageClearResultUpdateSceneHandler.update_result_scene(result_scene, 3.0)
	result_scene.queue_redraw()
	await _settle_frames(3)
	status = StageClearResultStatusSceneHandler.get_interaction_status(result_scene, "")
	if bool(status.get("stage2_boss_defeat_click_reaction_active", true)):
		push_error("Stage 2 Cheongringwi result click reaction did not return to idle")
		quit(1)
		return
	capture_error = _save_viewport_capture(RETURN_OUTPUT_NAME)
	if capture_error != OK:
		quit(1)
		return
	print("stage2_cheongringwi_result_visual_qa_capture: ok")
	result_scene.queue_free()
	await process_frame
	quit(0)


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _save_viewport_capture(output_name: String) -> int:
	var image: Image = get_root().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Stage 2 Cheongringwi result QA viewport capture was empty")
		return ERR_CANT_CREATE
	var output_dir_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_dir_absolute)
	var output_path := output_dir_absolute.path_join(output_name)
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("Stage 2 Cheongringwi result QA capture failed (%d): %s" % [save_error, output_path])
		return save_error
	print("stage2_cheongringwi_result_visual_qa_capture: %s" % output_path)
	return OK
