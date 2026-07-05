extends SceneTree

const StageClearResultPlazaSceneHandler := preload("res://scripts/core/stage_clear_result_plaza_scene_handler.gd")
const PlazaScene := preload("res://scripts/plaza/plaza_scene.gd")

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

	func get_summary() -> Dictionary:
		return {"save_path": save_path}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_status_and_background_prewarm_toggle()
	await _verify_spawn_configures_and_frees_plaza_scene()
	_verify_source_boundary()
	await _drain_frames(8)
	PlazaScene.reset_prewarm_assets_for_test()

	if _failures.is_empty():
		print("stage_clear_result_plaza_scene_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


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
	_expect(handler.ensure_assets_ready(1), "plaza scene handler should be able to blocking-prewarm plaza assets")
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


func _verify_source_boundary() -> void:
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var handler_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_plaza_scene_handler.gd")
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
