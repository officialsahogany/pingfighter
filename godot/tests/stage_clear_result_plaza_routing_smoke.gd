extends SceneTree

const StageClearResultInteractionState := preload("res://scripts/ui/stage_clear_result_interaction_state.gd")
const StageClearResultNavigationActionHandler := preload("res://scripts/ui/stage_clear_result_navigation_action_handler.gd")
const StageClearResultNavigationSceneHandler := preload("res://scripts/ui/stage_clear_result_navigation_scene_handler.gd")
const StageClearResultScrollInputHandler := preload("res://scripts/ui/stage_clear_result_scroll_input_handler.gd")
const StageClearResultViewportSceneHandler := preload("res://scripts/ui/stage_clear_result_viewport_scene_handler.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")
const StageClearResultFinishFlowHandler := preload("res://scripts/core/stage_clear_result_finish_flow_handler.gd")
const StageClearResultSceneSpawnCallbackData := preload("res://scripts/core/stage_clear_result_scene_spawn_callback_data.gd")
const StageClearResultRuntimeContextHandler := preload("res://scripts/core/stage_clear_result_runtime_context_handler.gd")
const StageClearResultScreen := preload("res://scripts/core/stage_clear_result_screen.gd")
const BattlePsoPrewarmer := preload("res://scripts/core/battle_pso_prewarmer.gd")
const PlazaScene := preload("res://scripts/plaza/plaza_scene.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends Node2D

	var current_stage := 1
	var selected_character_type := "smasher"
	var runtime_perk_gold := 0


class CallbackSink:
	extends RefCounted

	var reset_calls := 0

	func reset_game() -> void:
		reset_calls += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_three_button_action_route()
	_verify_result_character_type_normalization()
	await _verify_plaza_delays_result_reset_callback()
	await _drain_frames(12)

	if _failures.is_empty():
		print("stage_clear_result_plaza_routing_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_three_button_action_route() -> void:
	var layout: Dictionary = StageClearResultInteractionState.get_scroll_button_layout(
		Rect2(Vector2(100.0, 200.0), Vector2(700.0, 400.0)),
		1.0
	)
	var plaza_rect: Rect2 = layout.get("plaza_rect", Rect2())
	_expect(plaza_rect.size.x > 0.0 and plaza_rect.size.y > 0.0, "scroll button layout should expose a plaza button rect")
	var clicked: String = StageClearResultInteractionState.get_clicked_button(
		plaza_rect.get_center(),
		layout.get("next_stage_rect", Rect2()),
		plaza_rect,
		layout.get("exit_rect", Rect2()),
		StageClearResultInteractionState.PHASE_VISIBLE
	)
	_expect(clicked == StageClearResultInteractionState.BUTTON_PLAZA, "clicking the middle result button should identify the plaza route")
	_expect(
		StageClearResultNavigationActionHandler.get_scroll_button_action(clicked) == StageClearResultNavigationActionHandler.ACTION_ENTER_PLAZA,
		"plaza result button should map to the active production entry action"
	)


func _verify_result_character_type_normalization() -> void:
	var owner := FakeOwner.new()
	var runtime_context := StageClearResultRuntimeContextHandler.new()
	owner.selected_character_type = " IO "
	_expect(runtime_context.get_selected_character_type(owner) == "optimus", "runtime context should normalize Optimus aliases")
	_expect(runtime_context.get_result_victory_character_type(owner) == "smasher", "Optimus should keep the shared Smasher victory result fallback")
	owner.selected_character_type = " Commando "
	_expect(runtime_context.get_selected_character_type(owner) == "soldier", "runtime context should normalize Commando aliases")
	_expect(runtime_context.get_result_victory_character_type(owner) == "soldier", "Commando should keep its dedicated victory result assets")
	owner.selected_character_type = " Kohaku "
	_expect(runtime_context.get_selected_character_type(owner) == "blacksmith", "runtime context should normalize Blacksmith aliases")
	_expect(runtime_context.get_result_victory_character_type(owner) == "blacksmith", "Blacksmith should keep its dedicated victory result assets")
	owner.free()


func _verify_plaza_delays_result_reset_callback() -> void:
	ProjectResourceLoader.clear_caches()
	PlazaScene.reset_prewarm_assets_for_test()
	BattlePsoPrewarmer.reset_hwangyeok_gpu_prewarm_for_test()
	var owner := FakeOwner.new()
	owner.runtime_perk_gold = 321
	owner.selected_character_type = "viper"
	root.add_child(owner)
	var sink := CallbackSink.new()
	var screen := StageClearResultScreen.new()
	var save_path := _smoke_save_path("routing")
	_cleanup_save(save_path)
	screen.set_plaza_save_path_for_test(save_path)
	var result_scene := StageClearResultScene.new()
	result_scene.set("_driven_by_controller", true)
	owner.add_child(result_scene)
	screen.set("active", true)
	screen.set("current_stage", 1)
	screen.set("_pending_owner", owner)
	screen.set("_pending_reset_callback", Callable(sink, "reset_game"))
	screen.set("_scene_node", result_scene)
	result_scene.set("_scroll_phase", StageClearResultInteractionState.PHASE_VISIBLE)
	result_scene.set("timer", 5.0)
	result_scene.set("_plaza_notice_until", -1.0)
	result_scene.enter_plaza_callback = StageClearResultSceneSpawnCallbackData.build_enter_plaza_callback(screen)

	_expect(_click_plaza_button(result_scene), "the real result-scroll plaza button should handle the first click")
	_expect(result_scene.enter_plaza_callback.is_valid(), "an incomplete first prewarm click must restore the production plaza callback")
	_expect(screen.is_scene_ready(), "an incomplete first prewarm click must keep the result scene alive")
	_expect(owner.get_node_or_null("PlazaScene") == null, "an incomplete first prewarm click must not spawn a cache-only plaza")
	_expect(owner.runtime_perk_gold == 321, "an incomplete first prewarm click must not settle volatile gold early")
	_expect(float(result_scene.get("_plaza_notice_until")) > float(result_scene.get("timer")), "an incomplete active plaza click must show preparation feedback")
	_expect(_click_plaza_button(result_scene), "an immediate repeated plaza click should remain handled")
	_expect(result_scene.enter_plaza_callback.is_valid(), "an immediate repeated click must keep the production callback retryable")
	_expect(owner.runtime_perk_gold == 321, "an immediate repeated click must not settle volatile gold")

	var gpu_prewarmer: Node = null
	for _step in range(512):
		screen.update(1.0 / 60.0)
		await process_frame
		gpu_prewarmer = owner.get_node_or_null(BattlePsoPrewarmer.HWANGYEOK_ONLY_NODE_NAME)
		if gpu_prewarmer != null:
			break
	_expect(gpu_prewarmer != null, "the first production button click should attach the composed GPU prewarmer")
	_expect(_count_named_children(owner, BattlePsoPrewarmer.HWANGYEOK_ONLY_NODE_NAME) == 1, "repeated readiness clicks must attach exactly one composed GPU prewarmer")
	if gpu_prewarmer != null:
		gpu_prewarmer.call("_process", 0.0)
		var prewarmer_status: Dictionary = gpu_prewarmer.call("get_hwangyeok_instance_status")
		_expect(bool(prewarmer_status.get("retained_draw_issued", false)), "the retry fixture should reach the real retained SubViewport draw setup")
		_expect(int(prewarmer_status.get("in_bounds_layer_count", 0)) == 21, "the retry fixture should place all 21 layers inside the GPU target")
		for _flush_idx in range(
			int(prewarmer_status.get("post_draw_flush_count", 0)),
			BattlePsoPrewarmer.POST_WARMUP_FLUSH_FRAMES
		):
			gpu_prewarmer.call("_on_hwangyeok_frame_post_draw")
	await process_frame
	_expect(BattlePsoPrewarmer.is_hwangyeok_gpu_prewarm_complete(), "the retry fixture should complete composed GPU readiness before its second click")
	_expect(_click_plaza_button(result_scene), "the real result-scroll plaza button should handle the ready retry")
	_expect(not result_scene.enter_plaza_callback.is_valid(), "the ready second click should consume the production callback")
	_expect(screen.is_active(), "entering the plaza should keep the result screen controller active as an input gate")
	_expect(sink.reset_calls == 0, "plaza entry must not invoke the next-stage reset callback immediately")
	var status: Dictionary = screen.get_status()
	var progress_summary: Dictionary = status.get("last_plaza_progress_summary", {}) if status.get("last_plaza_progress_summary", {}) is Dictionary else {}
	var save_summary: Dictionary = screen.get_plaza_save_summary()
	_expect(int(progress_summary.get("transferred_gold", 0)) == 321, "plaza entry should transfer runtime perk gold exactly once")
	_expect(int(progress_summary.get("granted_ap", 0)) == 1, "plaza entry should grant the stage-clear AP once")
	_expect(owner.runtime_perk_gold == 0, "plaza entry should consume the volatile runtime perk gold")
	_expect(int(save_summary.get("plaza_gold", 0)) == 321, "plaza save should persist transferred gold")
	_expect(int(save_summary.get("ap_current", 0)) == 4, "plaza save should persist the granted AP")
	var progress_handler: Object = screen.get("_plaza_progress_handler")
	var plaza_save_store: Object = screen.get("_plaza_save_store")
	progress_handler.apply_stage_clear_progress_once(owner, plaza_save_store, int(screen.get("current_stage")), true)
	save_summary = screen.get_plaza_save_summary()
	_expect(int(save_summary.get("plaza_gold", 0)) == 321, "re-entering the plaza edge should not duplicate transferred gold")
	_expect(int(save_summary.get("ap_current", 0)) == 4, "re-entering the plaza edge should not duplicate AP")
	_expect(bool(status.get("plaza_active", false)), "plaza entry should spawn the plaza child scene")
	_expect(owner.get_node_or_null("PlazaScene") != null, "plaza entry should attach a PlazaScene child to the owner")
	var plaza_status: Dictionary = status.get("plaza_status", {}) if status.get("plaza_status", {}) is Dictionary else {}
	_expect(int(plaza_status.get("plaza_gold", 0)) == 321, "spawned plaza should read the same plaza save gold")
	_expect(int(plaza_status.get("ap_current", 0)) == 4, "spawned plaza should read the same plaza save AP")
	_expect(str(plaza_status.get("selected_character_type", "")) == "viper", "result-screen plaza route should pass the selected character through to the plaza")
	_expect(bool(plaza_status.get("player_sprite_loaded", false)), "result-screen plaza route should load the selected character plaza sheet")
	_expect(bool(plaza_status.get("plaza_warp_active", false)), "result-screen plaza route should start the arrival light-pillar phase")
	_expect(str(plaza_status.get("plaza_warp_phase", "")) == "arrive", "result-screen plaza route should mark the arrival light-pillar phase")

	_finish_result_screen(screen, StageClearResultFinishFlowHandler.ACTION_PLAZA_CONTINUE)
	_expect(not screen.is_active(), "leaving the plaza should close the result screen controller")
	_expect(sink.reset_calls == 1, "leaving the plaza should invoke the delayed next-stage reset callback exactly once")
	owner.queue_free()
	_cleanup_save(save_path)


func _drain_frames(frame_count: int) -> void:
	for _i in range(frame_count):
		await process_frame


func _click_plaza_button(scene: Control) -> bool:
	var view_size := StageClearResultViewportSceneHandler.get_current_view_size(scene)
	var layout_scale := StageClearResultViewportSceneHandler.get_layout_scale(view_size)
	var layout := StageClearResultScrollInputHandler.get_button_layout(
		StageClearResultInteractionState.PHASE_VISIBLE,
		layout_scale,
		Vector2.ZERO
	)
	var plaza_rect: Rect2 = layout.get("plaza_rect", Rect2())
	_expect(plaza_rect.has_area(), "production result layout should expose a clickable plaza rect")
	return StageClearResultNavigationSceneHandler.handle_button_click(scene, plaza_rect.get_center())


func _count_named_children(owner: Node, child_name: String) -> int:
	var count := 0
	for child in owner.get_children():
		if str(child.name) == child_name:
			count += 1
	return count


func _finish_result_screen(screen: Object, action: String) -> void:
	var finish_handler: Object = screen.get("_finish_flow_handler")
	var scene_shell_handler: Object = screen.get("_scene_shell_handler")
	finish_handler.finish_action_from_screen(
		action,
		screen,
		Callable(scene_shell_handler, "free_screen_result_scene").bind(screen)
	)


func _cleanup_save(path: String) -> void:
	var backup_path := path.trim_suffix(".cfg") + ".last_good.cfg"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))


func _smoke_save_path(slug: String) -> String:
	return "res://.tmp/stage_clear_result_plaza_routing_smoke_%s_%d_%d.cfg" % [
		slug,
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
