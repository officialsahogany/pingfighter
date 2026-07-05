extends SceneTree

const StageClearResultScreen := preload("res://scripts/core/stage_clear_result_screen.gd")
const StageClearResultScreenStateHandler := preload("res://scripts/core/stage_clear_result_screen_state_handler.gd")

var _failures: Array[String] = []


class FakeResetHandler:
	extends RefCounted

	var reset_calls: int = 0

	func reset() -> void:
		reset_calls += 1


class FakeStarpointChoiceHandler:
	extends RefCounted

	var reset_calls: int = 0
	var seen_scene: Control

	func reset(scene: Control = null) -> void:
		reset_calls += 1
		seen_scene = scene


class FreeSink:
	extends RefCounted

	var free_calls: int = 0

	func free_scene() -> void:
		free_calls += 1


func _init() -> void:
	_verify_apply_show_state()
	_verify_apply_spawn_state()
	_verify_reset_screen_state()
	_verify_finish_and_spawn_markers()
	_verify_source_boundary()

	if _failures.is_empty():
		print("stage_clear_result_screen_state_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_apply_show_state() -> void:
	var screen := StageClearResultScreen.new()
	var handler := StageClearResultScreenStateHandler.new()
	var owner := RefCounted.new()
	var registry := RefCounted.new()
	var snapshot := {"passive_items": [{"name": "new_passive"}]}
	handler.apply_show_state(screen, {
		"player_score": 5,
		"boss_score": 2,
		"current_stage": 6,
		"pending_reset_callback": Callable(self, "_noop"),
		"pending_exit_callback": Callable(self, "_noop"),
		"pending_owner": owner,
		"pending_registry": registry,
		"last_stage_reward_snapshot": snapshot,
		"active": true,
		"spawn_pending": true,
	})
	_expect(bool(screen.get("active")), "screen state handler should activate the result screen")
	_expect(int(screen.get("player_score")) == 5, "screen state handler should apply player score")
	_expect(int(screen.get("boss_score")) == 2, "screen state handler should apply boss score")
	_expect(int(screen.get("current_stage")) == 6, "screen state handler should apply current stage")
	_expect(screen.get("_pending_owner") == owner, "screen state handler should apply pending owner")
	_expect(screen.get("_pending_registry") == registry, "screen state handler should apply pending registry")
	var copied_snapshot: Dictionary = screen.get("_last_stage_reward_snapshot")
	(copied_snapshot.get("passive_items", []) as Array).append({"name": "mutated"})
	_expect((snapshot.get("passive_items", []) as Array).size() == 1, "screen state handler should deep-copy reward snapshots")
	_expect(bool(screen.get("_spawn_pending")), "screen state handler should apply pending spawn")


func _verify_apply_spawn_state() -> void:
	var screen := StageClearResultScreen.new()
	var handler := StageClearResultScreenStateHandler.new()
	screen.set("_spawn_pending", true)
	_expect(not handler.apply_spawn_state(screen, {"shown": false, "spawn_pending": false}), "spawn state should expose failed show result")
	_expect(not bool(screen.get("_spawn_pending")), "spawn state should clear pending spawn when requested")
	screen.set("_spawn_pending", true)
	_expect(handler.apply_spawn_state(screen, {"shown": true}), "spawn state should default to shown when not specified")
	_expect(bool(screen.get("_spawn_pending")), "spawn state should preserve pending spawn when not specified")


func _verify_reset_screen_state() -> void:
	var screen := StageClearResultScreen.new()
	var handler := StageClearResultScreenStateHandler.new()
	var reward_handler := FakeResetHandler.new()
	var plaza_progress_handler := FakeResetHandler.new()
	var starpoint_handler := FakeStarpointChoiceHandler.new()
	var plaza_scene_handler := FakeResetHandler.new()
	var sink := FreeSink.new()
	var scene := Control.new()
	handler.apply_show_state(screen, {
		"player_score": 7,
		"boss_score": 4,
		"current_stage": 5,
		"pending_owner": RefCounted.new(),
		"pending_registry": RefCounted.new(),
		"last_stage_reward_snapshot": {"items": [1]},
		"active": true,
		"spawn_pending": true,
	})
	handler.reset_screen_state(
		screen,
		reward_handler,
		plaza_progress_handler,
		starpoint_handler,
		scene,
		Callable(sink, "free_scene"),
		plaza_scene_handler
	)
	_expect(not bool(screen.get("active")), "reset state should deactivate the result screen")
	_expect(int(screen.get("player_score")) == 0 and int(screen.get("boss_score")) == 0, "reset state should clear scores")
	_expect(int(screen.get("current_stage")) == 1, "reset state should restore Stage 1 default")
	_expect(screen.get("_pending_owner") == null and screen.get("_pending_registry") == null, "reset state should clear pending runtime refs")
	_expect((screen.get("_last_stage_reward_snapshot") as Dictionary).is_empty(), "reset state should clear stage reward snapshot")
	_expect(reward_handler.reset_calls == 1, "reset state should reset reward grant handler")
	_expect(plaza_progress_handler.reset_calls == 1, "reset state should reset plaza progress handler")
	_expect(starpoint_handler.reset_calls == 1 and starpoint_handler.seen_scene == scene, "reset state should reset starpoint choice handler with the current scene")
	_expect(sink.free_calls == 1, "reset state should free the result scene")
	_expect(plaza_scene_handler.reset_calls == 1, "reset state should reset plaza scene handler")
	scene.free()


func _verify_finish_and_spawn_markers() -> void:
	var screen := StageClearResultScreen.new()
	var handler := StageClearResultScreenStateHandler.new()
	handler.apply_show_state(screen, {
		"pending_reset_callback": Callable(self, "_noop"),
		"pending_exit_callback": Callable(self, "_noop"),
		"pending_owner": RefCounted.new(),
		"pending_registry": RefCounted.new(),
		"active": true,
		"spawn_pending": true,
	})
	handler.mark_spawn_not_pending(screen)
	_expect(not bool(screen.get("_spawn_pending")), "spawn marker should clear pending spawn only")
	_expect(bool(screen.get("active")), "spawn marker should keep the result flow active")
	screen.set("_spawn_pending", true)
	handler.mark_finish_inactive(screen)
	_expect(not bool(screen.get("active")), "finish marker should deactivate the result flow")
	_expect(not bool(screen.get("_spawn_pending")), "finish marker should clear pending spawn")
	_expect(screen.get("_pending_owner") == null and screen.get("_pending_registry") == null, "finish marker should clear pending runtime refs")


func _verify_source_boundary() -> void:
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var registry_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_handler_registry.gd")
	var handler_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen_state_handler.gd")
	_expect(registry_source.find("StageClearResultScreenStateHandler.new()") >= 0, "handler registry should delegate screen state mutation to the state handler")
	_expect(screen_source.find("func _apply_show_flow_state") < 0, "result screen should not keep show-state application inline")
	_expect(screen_source.find("func _mark_finish_flow_inactive") < 0, "result screen should not keep finish marker wrappers")
	_expect(screen_source.find("func _mark_spawn_not_pending") < 0, "result screen should not keep plaza-enter spawn marker wrappers")
	_expect(handler_source.find("func apply_show_state") >= 0, "screen state handler should own show-state field application")
	_expect(handler_source.find("func reset_screen_state") >= 0, "screen state handler should own reset-state field application")
	_expect(handler_source.find("func mark_finish_inactive") >= 0, "screen state handler should own finish-state field application")


func _noop() -> void:
	pass


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
