extends SceneTree

const StageClearResultPlazaSceneHandler := preload("res://scripts/core/stage_clear_result_plaza_scene_handler.gd")
const PlazaScene := preload("res://scripts/plaza/plaza_scene.gd")
const BattlePsoPrewarmer := preload("res://scripts/core/battle_pso_prewarmer.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends Node2D

	var current_stage := 1
	var selected_character_type := "viper"


class CallbackSink:
	extends RefCounted

	var finish_calls := 0

	func finish() -> void:
		finish_calls += 1


class FakePlazaSaveStore:
	extends RefCounted

	var save_path: String = ""
	var stage_seed := 4444

	func get_summary() -> Dictionary:
		return {"save_path": save_path, "tavern_active_quest": {}}

	func get_or_create_stage_map_seed(_stage_id: int) -> int:
		return stage_seed


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_r3d_config_and_boundary()
	_verify_source_boundary()

	if _failures.is_empty():
		print("stage_clear_result_plaza_scene_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_r3d_config_and_boundary() -> void:
	var owner := FakeOwner.new()
	var handler := StageClearResultPlazaSceneHandler.new()
	var store := FakePlazaSaveStore.new()
	store.save_path = _smoke_save_path("r3d_config")
	var config := handler.build_scene_config(4, store, owner, null, "viper", true)
	_expect(bool(config.get("r3_production", false)), "R3-D config should select the production 2D exterior")
	_expect(int(config.get("stage_id", 0)) == 4, "R3-D config should preserve the cleared stage")
	_expect(int(config.get("map_seed", 0)) == 4444, "R3-D config should consume the persisted stage_map_seed")
	_expect(config.get("runtime_owner", null) == owner, "R3-D config should preserve the runtime owner")
	_expect(str(config.get("selected_character_type", "")) == "viper", "R3-D config should preserve the selected character")
	_expect(config.get("render_size", Vector2.ZERO) is Vector2, "R3-D config should publish the render contract")
	_expect(config.get("safe_insets", null) is Dictionary, "R3-D config should publish safe insets")
	_expect(config.get("minimap_rect", null) is Rect2, "R3-D config should publish a two-axis minimap rect")
	_expect(not handler.has_scene(), "building the config must not expose an exterior")
	_expect(not handler.is_entry_transition_active(), "building the config must not begin transition work")
	_expect(handler.prewarm_assets_step(4, owner), "legacy background hook should be a no-work compatibility success")
	owner.free()


func _verify_status_and_background_prewarm_toggle() -> void:
	var handler := StageClearResultPlazaSceneHandler.new()
	var status: Dictionary = handler.get_status()
	_expect(str(status.get("plaza_scene_path", "")) == "res://scenes/plaza.tscn", "plaza scene handler should expose the plaza scene path")
	_expect(not bool(status.get("plaza_active", true)), "plaza scene handler should start inactive")
	_expect(int(status.get("plaza_prewarm_stage", 0)) == -1, "plaza scene handler should start without a prewarm stage")
	handler.set_background_prewarm_enabled(false)
	_expect(not handler.prewarm_assets_step(1), "disabled background prewarm should not start plaza prewarm work")
	status = handler.get_status()
	_expect(not bool(status.get("plaza_prewarm_complete", true)), "disabled background prewarm should clear prewarm completion")
	_expect(int(status.get("plaza_prewarm_stage", 0)) == -1, "disabled background prewarm should clear the prewarm stage")


func _verify_spawn_configures_and_frees_plaza_scene() -> void:
	var owner := FakeOwner.new()
	root.add_child(owner)
	var sink := CallbackSink.new()
	var handler := StageClearResultPlazaSceneHandler.new()
	BattlePsoPrewarmer.reset_hwangyeok_gpu_prewarm_for_test()
	_expect(not handler.ensure_assets_ready(1, owner), "cache-only plaza prewarm should remain gated on the frame-driven GPU draw")
	await process_frame
	var gpu_prewarmer := owner.get_node_or_null(BattlePsoPrewarmer.HWANGYEOK_ONLY_NODE_NAME)
	_expect(gpu_prewarmer != null, "plaza readiness should attach the Hwangyeok-only GPU prewarmer to its production owner")
	if gpu_prewarmer != null:
		gpu_prewarmer.call("_process", 0.0)
		var instance_status: Dictionary = gpu_prewarmer.call("get_hwangyeok_instance_status")
		for _flush_idx in range(
			int(instance_status.get("post_draw_flush_count", 0)),
			BattlePsoPrewarmer.POST_WARMUP_FLUSH_FRAMES
		):
			gpu_prewarmer.call("_on_hwangyeok_frame_post_draw")
	await process_frame
	_expect(handler.ensure_assets_ready(1, owner), "plaza scene handler should report ready after the retained GPU prewarm")
	var save_store := FakePlazaSaveStore.new()
	save_store.save_path = _smoke_save_path("scene_handler")
	var config: Dictionary = handler.build_scene_config(
		1,
		save_store,
		owner,
		null,
		"viper",
		true
	)
	_expect(str(config.get("plaza_save_path", "")) == save_store.save_path, "plaza scene handler should build the plaza save path into scene config")
	_expect(config.get("runtime_owner", null) == owner, "plaza scene handler should build the runtime owner into scene config")
	_expect(str(config.get("selected_character_type", "")) == "viper", "plaza scene handler should build the selected character into scene config")
	_expect(bool(config.get("play_arrival_transition", false)), "plaza scene handler should build the arrival transition flag into scene config")
	var spawned := handler.spawn_scene(owner, config, Callable(sink, "finish"))
	_expect(spawned, "plaza scene handler should spawn the plaza scene")
	_expect(handler.has_scene(), "plaza scene handler should report an active scene after spawn")
	_expect(owner.get_node_or_null("PlazaScene") != null, "plaza scene handler should attach PlazaScene to the owner")
	var status: Dictionary = handler.get_status()
	_expect(bool(status.get("plaza_active", false)), "spawned plaza scene should appear in handler status")
	var plaza_status: Dictionary = status.get("plaza_status", {}) if status.get("plaza_status", {}) is Dictionary else {}
	_expect(str(plaza_status.get("selected_character_type", "")) == "viper", "plaza scene handler should pass selected character through configure")
	_expect(bool(plaza_status.get("plaza_warp_active", false)), "plaza scene handler should enable the arrival warp configure flag")
	handler.update(0.016)
	var input_event := InputEventAction.new()
	input_event.action = "ui_accept"
	handler.handle_input(input_event)
	handler.free_scene()
	await _drain_frames(2)
	_expect(not handler.has_scene(), "plaza scene handler should clear its scene reference after free")
	owner.queue_free()


func _verify_forced_entry_click_never_strands_on_notice() -> void:
	var owner := FakeOwner.new()
	root.add_child(owner)
	var sink := CallbackSink.new()

	# Counterproof first: a fresh handler with an incomplete GPU prewarm and no
	# forced entry must keep rejecting cache-only spawn readiness.
	PlazaScene.reset_prewarm_assets_for_test()
	BattlePsoPrewarmer.reset_hwangyeok_gpu_prewarm_for_test()
	var gated_handler := StageClearResultPlazaSceneHandler.new()
	var save_store := FakePlazaSaveStore.new()
	save_store.save_path = _smoke_save_path("forced_entry")
	var config: Dictionary = gated_handler.build_scene_config(1, save_store, owner, null, "viper", true)
	_expect(
		not gated_handler.spawn_scene(owner, config, Callable(sink, "finish")),
		"non-forced spawn should stay gated on the retained GPU prewarm"
	)

	# The entry click drains the bounded texture pipeline and forces entry even
	# though the retained GPU flush has not happened yet.
	PlazaScene.reset_prewarm_assets_for_test()
	BattlePsoPrewarmer.reset_hwangyeok_gpu_prewarm_for_test()
	var handler := StageClearResultPlazaSceneHandler.new()
	handler.set_background_prewarm_enabled(true)
	_expect(handler.advance_entry_readiness(1, owner), "entry click should force readiness through the bounded drain")
	var status: Dictionary = handler.get_status()
	_expect(bool(status.get("plaza_prewarm_complete", false)), "forced entry should complete the texture cache stage")
	_expect(str(status.get("plaza_readiness_rejection_reason", "x")) == "", "forced entry should clear the readiness rejection reason")
	_expect(
		not BattlePsoPrewarmer.is_hwangyeok_gpu_prewarm_complete(),
		"forced-entry leg requires the GPU prewarm to still be incomplete to be non-vacuous"
	)
	_expect(
		handler.spawn_scene(owner, config, Callable(sink, "finish")),
		"forced entry should bypass the GPU spawn gate instead of rerouting past the plaza"
	)
	_expect(handler.has_scene(), "forced entry spawn should attach a live plaza scene")
	handler.free_scene()
	await _drain_frames(2)
	owner.queue_free()


func _verify_source_boundary() -> void:
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var handler_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_plaza_scene_handler.gd")
	var enter_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_plaza_enter_flow_handler.gd")
	var prewarm_state_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_plaza_scene_prewarm_state.gd")
	_expect(screen_source.find("StageClearResultPlazaProgressHandler.get_plaza_save_path") < 0, "result screen should not build plaza save paths directly")
	_expect(screen_source.find("\"play_arrival_transition\"") < 0, "result screen should not own plaza scene configure keys directly")
	_expect(handler_source.find("func build_scene_config") >= 0, "plaza scene handler should own plaza scene config assembly")
	_expect(handler_source.find("StageClearResultPlazaProgressHandler.get_plaza_save_path") >= 0, "plaza scene handler should own plaza save path lookup")
	_expect(handler_source.find("PlazaScene.prewarm_assets_threaded_step") < 0, "plaza scene handler should delegate threaded prewarm details")
	_expect(handler_source.find("PlazaScene.prewarm_assets_blocking_step") < 0, "plaza scene handler should delegate blocking prewarm details")
	_expect(handler_source.find("var _background_prewarm_enabled") < 0, "plaza scene handler should not own background prewarm toggle state directly")
	_expect(handler_source.find("StageClearResultPlazaScenePrewarmState.new()") >= 0, "plaza scene handler should compose the prewarm state")
	_expect(prewarm_state_source.find("PlazaScene.prewarm_assets_threaded_step") >= 0, "plaza prewarm state should own threaded plaza prewarm")
	_expect(prewarm_state_source.find("PlazaScene.prewarm_assets_blocking_step") >= 0, "plaza prewarm state should own blocking plaza prewarm")
	_expect(prewarm_state_source.find("_background_prewarm_enabled") >= 0, "plaza prewarm state should own background prewarm toggles")
	_expect(handler_source.find("func begin_r3_entry_transition") >= 0, "plaza scene handler should own the R3-D transition")
	_expect(handler_source.find("finish_atomic_reveal") >= 0, "plaza scene handler should own the atomic reveal boundary")
	_expect(enter_source.find("_call(finish_plaza_and_continue)") < 0, "live entry must not silently route past R3 failure")


func _drain_frames(frame_count: int) -> void:
	for _i in range(frame_count):
		await process_frame


func _smoke_save_path(slug: String) -> String:
	return "res://.tmp/stage_clear_result_plaza_scene_handler_smoke_%s_%d_%d.cfg" % [
		slug,
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
