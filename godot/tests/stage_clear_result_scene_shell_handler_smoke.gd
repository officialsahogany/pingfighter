extends SceneTree

const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")
const StageClearResultConfigSceneHandler := preload("res://scripts/ui/stage_clear_result_config_scene_handler.gd")
const StageClearResultSceneShellHandler := preload("res://scripts/core/stage_clear_result_scene_shell_handler.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends Node2D


class CallbackSink:
	extends RefCounted

	var next_calls: int = 0
	var exit_calls: int = 0
	var plaza_calls: int = 0

	func next_stage() -> void:
		next_calls += 1

	func exit_to_menu() -> void:
		exit_calls += 1

	func enter_plaza() -> void:
		plaza_calls += 1

	func roll_box_reward(_box_kind: String) -> Dictionary:
		return {"type": "starpoint", "amount": 1}

	func grant_immediate_box_reward(_reward: Dictionary, _box_index: int) -> bool:
		return true


class FakeScreen:
	extends RefCounted

	var _scene_node: Control


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_prewarm_and_required_keys()
	await _verify_spawn_configures_scene()
	await _verify_screen_result_scene_free_adapter()
	_verify_source_boundary()

	StageClearResultConfigSceneHandler.reset_prewarm_assets_for_test()

	if _failures.is_empty():
		print("stage_clear_result_scene_shell_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_prewarm_and_required_keys() -> void:
	StageClearResultConfigSceneHandler.reset_prewarm_assets_for_test()
	var handler := StageClearResultSceneShellHandler.new()
	_expect(handler.get_scene_path() == "res://scenes/stage_clear_result.tscn", "scene shell handler should expose the result scene path")
	_expect(handler.prewarm_scene_shell(), "scene shell handler should load the packed scene shell")
	var status: Dictionary = handler.get_prewarm_status()
	_expect(bool(status.get("result_scene_packed", false)), "scene shell prewarm should mark the packed scene ready")
	_expect(not status.has("background_texture"), "scene shell prewarm should not load heavy result textures")

	var calls := 0
	while not bool(handler.prewarm_assets_step("smasher", 1)):
		calls += 1
		_expect(calls <= StageClearResultAssetLoader.PREWARM_ASSET_STEP_COUNT + 1, "scene shell staged prewarm should finish within the declared budget")
	calls += 1
	_expect(
		calls == StageClearResultAssetLoader.PREWARM_ASSET_STEP_COUNT + 1,
		"scene shell should keep the packed-scene prewarm as its own stage"
	)
	status = handler.get_prewarm_status()
	_expect(str(status.get("selected_character_type", "")) == "smasher", "scene shell prewarm should remember the selected character")
	_expect(int(status.get("current_stage", 0)) == 1, "scene shell prewarm should remember the stage")
	_expect(bool(status.get("background_texture", false)), "scene shell staged prewarm should load the result background")
	_expect(bool(status.get("dalji_defeat_sheet", false)), "Stage 1 shell prewarm should load Dalji result sheets")

	var stage5_keys: Array[String] = handler.get_required_scene_asset_keys(5)
	_expect(stage5_keys.has("stage5_hongryun_result_sheet"), "Stage 5 shell readiness should require the Hongryun result sheet")
	_expect(not stage5_keys.has("stage6_boss_defeat_sheet"), "Stage 5 shell readiness should not require the Stage 6 defeat sheet")
	var stage4_keys: Array[String] = handler.get_required_scene_asset_keys(4)
	_expect(stage4_keys.has("stage4_ponk_boss_defeat_live2d_sheet"), "Stage 4 shell readiness should require the Ponk Live2D defeat sheet")
	_expect(stage4_keys.has("stage4_ponk_boss_defeat_click_reaction_sheet"), "Stage 4 shell readiness should require the Ponk Live2D click sheet")
	_expect(not stage4_keys.has("stage4_ponk_result_sheet"), "Stage 4 shell readiness should not require the old Ponk fallback sheet")
	_expect(handler.are_assets_ready_for_spawn("smasher", 1), "scene shell should report readiness once required Stage 1 assets are prewarmed")
	_expect(not handler.are_assets_ready_for_spawn("smasher", 5), "scene shell should reject readiness for a different stage")


func _verify_spawn_configures_scene() -> void:
	StageClearResultConfigSceneHandler.reset_prewarm_assets_for_test()
	var handler := StageClearResultSceneShellHandler.new()
	while not bool(handler.prewarm_assets_step("smasher", 1)):
		pass
	var owner := FakeOwner.new()
	var sink := CallbackSink.new()
	root.add_child(owner)
	var scene: Control = handler.spawn_scene(
		owner,
		{
			"player_score": 5,
			"boss_score": 1,
			"current_stage": 1,
			"selected_character_type": "smasher",
			"reward_plan": {"reward_count": 1},
			"stage_reward_snapshot": {"gold": 10},
		},
		handler.build_callbacks(
			Callable(sink, "next_stage"),
			Callable(sink, "exit_to_menu"),
			Callable(sink, "roll_box_reward"),
			Callable(sink, "grant_immediate_box_reward"),
			Callable(sink, "enter_plaza")
		)
	)
	_expect(scene != null, "scene shell handler should spawn the result scene")
	_expect(owner.get_child_count() == 1, "scene shell handler should attach the result scene to the owner")
	_expect(scene.name == "StageClearResultScene", "scene shell handler should name the result scene")
	_expect(scene.process_mode == Node.PROCESS_MODE_ALWAYS, "scene shell handler should keep the result scene processing over modal flow")
	_expect(scene.z_index == 1200, "scene shell handler should set the result scene z layer")
	_expect(scene.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "scene shell handler should set result scene texture filtering")
	_expect(int(scene.get("player_score")) == 5, "scene shell handler should configure player score")
	_expect(int(scene.get("boss_score")) == 1, "scene shell handler should configure boss score")
	_expect(int(scene.get("current_stage")) == 1, "scene shell handler should configure current stage")
	handler.free_scene(scene)
	await process_frame
	_expect(owner.get_child_count() == 0, "scene shell handler should free the result scene")
	owner.queue_free()


func _verify_screen_result_scene_free_adapter() -> void:
	StageClearResultConfigSceneHandler.reset_prewarm_assets_for_test()
	var handler := StageClearResultSceneShellHandler.new()
	while not bool(handler.prewarm_assets_step("smasher", 1)):
		pass
	var owner := FakeOwner.new()
	var sink := CallbackSink.new()
	root.add_child(owner)
	var scene: Control = handler.spawn_scene(
		owner,
		{
			"player_score": 5,
			"boss_score": 1,
			"current_stage": 1,
			"selected_character_type": "smasher",
			"reward_plan": {"reward_count": 1},
			"stage_reward_snapshot": {"gold": 10},
		},
		handler.build_callbacks(
			Callable(sink, "next_stage"),
			Callable(sink, "exit_to_menu"),
			Callable(sink, "roll_box_reward"),
			Callable(sink, "grant_immediate_box_reward"),
			Callable(sink, "enter_plaza")
		)
	)
	var screen := FakeScreen.new()
	screen._scene_node = scene
	handler.free_screen_result_scene(screen)
	_expect(screen._scene_node == null, "scene shell screen-free adapter should clear the screen scene reference")
	await process_frame
	_expect(owner.get_child_count() == 0, "scene shell screen-free adapter should free the result scene node")
	owner.queue_free()


func _verify_source_boundary() -> void:
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var registry_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_handler_registry.gd")
	var handler_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_scene_shell_handler.gd")
	var prewarm_state_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_scene_shell_prewarm_state.gd")
	var scene_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_scene_shell_scene_data.gd")
	_expect(registry_source.find("StageClearResultSceneShellHandler.new()") >= 0, "handler registry should delegate scene shell work to the shell handler")
	_expect(screen_source.find("StageClearResultConfigSceneHandler") < 0, "result screen should not call config scene glue directly")
	_expect(screen_source.find("\"next_stage\"") < 0, "result screen should not own result-scene callback schema keys directly")
	_expect(screen_source.find("\"grant_immediate_box_reward\"") < 0, "result screen should not own result-scene reward callback schema keys directly")
	_expect(screen_source.find("func _free_result_scene") < 0, "result screen should not keep result scene free wrappers")
	_expect(screen_source.find("_result_scene_packed") < 0, "result screen should not own the packed scene cache")
	_expect(screen_source.find("_prewarm_assets_step_index") < 0, "result screen should not own staged prewarm step state")
	_expect(handler_source.find("func build_callbacks") >= 0, "scene shell handler should expose result scene callback schema assembly")
	_expect(handler_source.find("StageClearResultSceneShellSceneData.build_callbacks") >= 0, "scene shell handler should delegate callback schema assembly")
	_expect(handler_source.find("StageClearResultSceneShellPrewarmState.new()") >= 0, "scene shell handler should delegate prewarm state to the prewarm helper")
	_expect(handler_source.find("StageClearResultConfigSceneHandler.prewarm_assets_step") < 0, "scene shell handler should not own config prewarm delegation directly")
	_expect(handler_source.find("StageClearResultConfigSceneHandler.configure") < 0, "scene shell handler should not own config scene spawn glue directly")
	_expect(handler_source.find("StageClearResultConfigSceneHandler.clear_runtime_references") < 0, "scene shell handler should not own result scene free cleanup directly")
	_expect(handler_source.find("func _get_callback") < 0, "scene shell handler should not own callback dictionary reads")
	_expect(handler_source.find("func _get_screen_control") < 0, "scene shell handler should not own screen scene-node reads")
	_expect(handler_source.find("var _prewarm_assets_step_index") < 0, "scene shell handler should not own staged prewarm index state")
	_expect(handler_source.find("var _prewarm_assets_status") < 0, "scene shell handler should not own staged prewarm status storage")
	_expect(prewarm_state_source.find("func prewarm_assets_step") >= 0, "scene shell prewarm state should own staged asset prewarm")
	_expect(prewarm_state_source.find("StageClearResultConfigSceneHandler.prewarm_assets_step") >= 0, "scene shell prewarm state should own config prewarm delegation")
	_expect(prewarm_state_source.find("func are_assets_ready_for_spawn") >= 0, "scene shell prewarm state should own result asset readiness checks")
	_expect(prewarm_state_source.find("func get_required_scene_asset_keys") >= 0, "scene shell prewarm state should own required result asset keys")
	_expect(scene_data_source.find("StageClearResultConfigSceneHandler.configure") >= 0, "scene shell scene data should own config scene spawn glue")
	_expect(scene_data_source.find("StageClearResultConfigSceneHandler.clear_runtime_references") >= 0, "scene shell scene data should own result scene free cleanup")
	_expect(scene_data_source.find("static func free_screen_result_scene") >= 0, "scene shell scene data should own screen result scene free adapters")
	_expect(handler_source.find("func free_screen_result_scene") >= 0, "scene shell handler should expose screen result scene free adapters")
	_expect(handler_source.find("_prewarm_state.get_required_scene_asset_keys") >= 0, "scene shell handler should expose required keys through the prewarm helper")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
