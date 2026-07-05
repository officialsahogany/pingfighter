extends SceneTree

const StageClearResultFinishFlowHandler := preload("res://scripts/core/stage_clear_result_finish_flow_handler.gd")

var _failures: Array[String] = []


class FlowSink:
	extends RefCounted

	var grant_calls: int = 0
	var apply_calls: int = 0
	var applied_grant_ap: Array = []
	var mark_inactive_calls: int = 0
	var free_result_calls: int = 0
	var free_plaza_calls: int = 0
	var reset_calls: int = 0
	var exit_calls: int = 0

	func grant_pending_rewards() -> Dictionary:
		grant_calls += 1
		return {"granted": 1}

	func apply_stage_clear_progress(grant_ap: bool) -> Dictionary:
		apply_calls += 1
		applied_grant_ap.append(grant_ap)
		return {"granted_ap": 1 if grant_ap else 0}

	func mark_inactive() -> void:
		mark_inactive_calls += 1

	func free_result_scene() -> void:
		free_result_calls += 1

	func free_plaza_scene() -> void:
		free_plaza_calls += 1

	func reset_game() -> void:
		reset_calls += 1

	func exit_to_menu() -> void:
		exit_calls += 1


class FakeScene:
	extends Control


class FakeRewardGrantHandler:
	extends RefCounted

	var grant_calls: int = 0
	var seen_scene: Control
	var seen_owner: Object
	var seen_registry: Object

	func grant_pending_scene_rewards(scene: Control, owner: Object, registry: Object) -> Dictionary:
		grant_calls += 1
		seen_scene = scene
		seen_owner = owner
		seen_registry = registry
		return {"granted": 1}


class FakePlazaProgressHandler:
	extends RefCounted

	var apply_calls: int = 0
	var seen_grant_ap: bool = false
	var seen_owner: Object
	var seen_save_store: Object
	var seen_stage: int = 0

	func apply_stage_clear_progress_from_callback(
		grant_ap: bool,
		owner: Object,
		plaza_save_store: Object,
		current_stage: int
	) -> Dictionary:
		apply_calls += 1
		seen_grant_ap = grant_ap
		seen_owner = owner
		seen_save_store = plaza_save_store
		seen_stage = current_stage
		return {"granted_ap": 1 if grant_ap else 0}


class FakeScreenStateHandler:
	extends RefCounted

	var mark_finish_calls: int = 0
	var seen_screen: Object

	func mark_finish_inactive(screen: Object) -> void:
		mark_finish_calls += 1
		seen_screen = screen
		if screen != null:
			screen.set("active", false)


class FakePlazaSceneHandler:
	extends RefCounted

	var free_calls: int = 0

	func free_scene() -> void:
		free_calls += 1


class FakeScreen:
	extends RefCounted

	var active: bool = true
	var current_stage: int = 1
	var _pending_reset_callback: Callable = Callable()
	var _pending_exit_callback: Callable = Callable()
	var _pending_owner: Object
	var _pending_registry: Object
	var _scene_node: Control
	var _reward_grant_handler: Object
	var _plaza_progress_handler: Object
	var _screen_state_handler: Object
	var _plaza_scene_handler: Object
	var _plaza_save_store: Object


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_build_context_schema()
	_verify_next_stage_finish()
	_verify_plaza_continue_finish()
	_verify_exit_to_menu_finish()
	_verify_finish_action_dispatch()
	_verify_screen_finish_action_adapter()
	_verify_inactive_context_is_ignored()
	_verify_source_boundary()

	if _failures.is_empty():
		print("stage_clear_result_finish_flow_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_build_context_schema() -> void:
	var sink := FlowSink.new()
	var handler := StageClearResultFinishFlowHandler.new()
	var context: Dictionary = handler.build_context(
		true,
		Callable(sink, "reset_game"),
		Callable(sink, "exit_to_menu"),
		Callable(sink, "grant_pending_rewards"),
		Callable(sink, "apply_stage_clear_progress"),
		Callable(sink, "mark_inactive"),
		Callable(sink, "free_result_scene"),
		Callable(sink, "free_plaza_scene")
	)
	for key in [
		"active",
		"reset_callback",
		"exit_callback",
		"grant_pending_rewards",
		"apply_stage_clear_progress",
		"mark_inactive",
		"free_result_scene",
		"free_plaza_scene",
	]:
		_expect(context.has(key), "finish flow context builder should include %s" % key)
	_expect(bool(context.get("active", false)), "finish flow context builder should preserve active state")
	handler.finish_plaza_and_continue(context)
	_expect(sink.reset_calls == 1, "built finish flow context should be executable by the handler")


func _verify_next_stage_finish() -> void:
	var sink := FlowSink.new()
	var handler := StageClearResultFinishFlowHandler.new()
	handler.finish_next_stage(_context(sink, true, true))
	_expect(sink.grant_calls == 1, "next-stage finish should grant pending rewards")
	_expect(sink.apply_calls == 1 and bool(sink.applied_grant_ap[0]), "next-stage finish should apply stage progress with AP")
	_expect(sink.mark_inactive_calls == 1, "next-stage finish should mark the controller inactive")
	_expect(sink.free_result_calls == 1, "next-stage finish should free the result scene")
	_expect(sink.free_plaza_calls == 1, "next-stage finish should free any plaza scene")
	_expect(sink.reset_calls == 1, "next-stage finish should call the reset callback")
	_expect(sink.exit_calls == 0, "next-stage finish should not call the exit callback")


func _verify_plaza_continue_finish() -> void:
	var sink := FlowSink.new()
	var handler := StageClearResultFinishFlowHandler.new()
	handler.finish_plaza_and_continue(_context(sink, true, true))
	_expect(sink.grant_calls == 0, "plaza continue finish should not re-grant rewards")
	_expect(sink.apply_calls == 0, "plaza continue finish should not re-apply stage progress")
	_expect(sink.mark_inactive_calls == 1, "plaza continue finish should mark the controller inactive")
	_expect(sink.free_result_calls == 1, "plaza continue finish should free the result scene")
	_expect(sink.free_plaza_calls == 1, "plaza continue finish should free the plaza scene")
	_expect(sink.reset_calls == 1, "plaza continue finish should call the delayed reset callback")
	_expect(sink.exit_calls == 0, "plaza continue finish should not call the exit callback")


func _verify_exit_to_menu_finish() -> void:
	var sink := FlowSink.new()
	var handler := StageClearResultFinishFlowHandler.new()
	handler.finish_exit_to_menu(_context(sink, true, true))
	_expect(sink.grant_calls == 1, "exit finish should grant pending rewards")
	_expect(sink.apply_calls == 1 and not bool(sink.applied_grant_ap[0]), "exit finish should apply stage progress without AP")
	_expect(sink.mark_inactive_calls == 1, "exit finish should mark the controller inactive")
	_expect(sink.free_result_calls == 1, "exit finish should free the result scene")
	_expect(sink.free_plaza_calls == 1, "exit finish should free any plaza scene")
	_expect(sink.exit_calls == 1, "exit finish should prefer the exit callback")
	_expect(sink.reset_calls == 0, "exit finish should not also call reset when exit callback exists")

	var fallback_sink := FlowSink.new()
	handler.finish_exit_to_menu(_context(fallback_sink, true, false))
	_expect(fallback_sink.exit_calls == 0, "exit fallback should not call a missing exit callback")
	_expect(fallback_sink.reset_calls == 1, "exit fallback should call reset when no exit callback exists")


func _verify_finish_action_dispatch() -> void:
	var handler := StageClearResultFinishFlowHandler.new()

	var next_sink := FlowSink.new()
	handler.finish_action(
		StageClearResultFinishFlowHandler.ACTION_NEXT_STAGE,
		true,
		Callable(next_sink, "reset_game"),
		Callable(next_sink, "exit_to_menu"),
		Callable(next_sink, "grant_pending_rewards"),
		Callable(next_sink, "apply_stage_clear_progress"),
		Callable(next_sink, "mark_inactive"),
		Callable(next_sink, "free_result_scene"),
		Callable(next_sink, "free_plaza_scene")
	)
	_expect(next_sink.grant_calls == 1 and next_sink.reset_calls == 1, "finish action should dispatch next-stage completion")

	var plaza_sink := FlowSink.new()
	handler.finish_action(
		StageClearResultFinishFlowHandler.ACTION_PLAZA_CONTINUE,
		true,
		Callable(plaza_sink, "reset_game"),
		Callable(plaza_sink, "exit_to_menu"),
		Callable(plaza_sink, "grant_pending_rewards"),
		Callable(plaza_sink, "apply_stage_clear_progress"),
		Callable(plaza_sink, "mark_inactive"),
		Callable(plaza_sink, "free_result_scene"),
		Callable(plaza_sink, "free_plaza_scene")
	)
	_expect(plaza_sink.grant_calls == 0 and plaza_sink.reset_calls == 1, "finish action should dispatch plaza continuation")

	var exit_sink := FlowSink.new()
	handler.finish_action(
		StageClearResultFinishFlowHandler.ACTION_EXIT_TO_MENU,
		true,
		Callable(exit_sink, "reset_game"),
		Callable(exit_sink, "exit_to_menu"),
		Callable(exit_sink, "grant_pending_rewards"),
		Callable(exit_sink, "apply_stage_clear_progress"),
		Callable(exit_sink, "mark_inactive"),
		Callable(exit_sink, "free_result_scene"),
		Callable(exit_sink, "free_plaza_scene")
	)
	_expect(exit_sink.grant_calls == 1 and exit_sink.exit_calls == 1 and exit_sink.reset_calls == 0, "finish action should dispatch exit completion")

	var ignored_sink := FlowSink.new()
	handler.finish_action(
		"missing_action",
		true,
		Callable(ignored_sink, "reset_game"),
		Callable(ignored_sink, "exit_to_menu"),
		Callable(ignored_sink, "grant_pending_rewards"),
		Callable(ignored_sink, "apply_stage_clear_progress"),
		Callable(ignored_sink, "mark_inactive"),
		Callable(ignored_sink, "free_result_scene"),
		Callable(ignored_sink, "free_plaza_scene")
	)
	_expect(ignored_sink.grant_calls == 0 and ignored_sink.reset_calls == 0 and ignored_sink.exit_calls == 0, "unknown finish action should be ignored")


func _verify_screen_finish_action_adapter() -> void:
	var handler := StageClearResultFinishFlowHandler.new()
	var sink := FlowSink.new()
	var owner := RefCounted.new()
	var registry := RefCounted.new()
	var save_store := RefCounted.new()
	var scene := FakeScene.new()
	var reward_grant := FakeRewardGrantHandler.new()
	var plaza_progress := FakePlazaProgressHandler.new()
	var screen_state := FakeScreenStateHandler.new()
	var plaza_scene := FakePlazaSceneHandler.new()
	var screen := FakeScreen.new()
	screen.active = true
	screen.current_stage = 5
	screen._pending_reset_callback = Callable(sink, "reset_game")
	screen._pending_exit_callback = Callable(sink, "exit_to_menu")
	screen._pending_owner = owner
	screen._pending_registry = registry
	screen._scene_node = scene
	screen._reward_grant_handler = reward_grant
	screen._plaza_progress_handler = plaza_progress
	screen._screen_state_handler = screen_state
	screen._plaza_scene_handler = plaza_scene
	screen._plaza_save_store = save_store

	handler.finish_action_from_screen(
		StageClearResultFinishFlowHandler.ACTION_NEXT_STAGE,
		screen,
		Callable(sink, "free_result_scene")
	)
	_expect(reward_grant.grant_calls == 1, "screen finish adapter should grant pending rewards for next-stage finish")
	_expect(reward_grant.seen_scene == scene and reward_grant.seen_owner == owner and reward_grant.seen_registry == registry, "screen finish adapter should bind scene owner and registry into reward grants")
	_expect(plaza_progress.apply_calls == 1 and plaza_progress.seen_grant_ap, "screen finish adapter should apply stage progress with AP for next-stage finish")
	_expect(plaza_progress.seen_owner == owner and plaza_progress.seen_save_store == save_store and plaza_progress.seen_stage == 5, "screen finish adapter should bind owner save store and stage into progress grants")
	_expect(screen_state.mark_finish_calls == 1 and screen_state.seen_screen == screen, "screen finish adapter should delegate inactive-state mutation")
	_expect(sink.free_result_calls == 1 and plaza_scene.free_calls == 1, "screen finish adapter should free result and plaza scenes")
	_expect(sink.reset_calls == 1 and sink.exit_calls == 0, "screen finish adapter should call reset for next-stage finish")

	var exit_sink := FlowSink.new()
	var exit_progress := FakePlazaProgressHandler.new()
	var exit_screen_state := FakeScreenStateHandler.new()
	var exit_screen := FakeScreen.new()
	exit_screen.active = true
	exit_screen.current_stage = 6
	exit_screen._pending_reset_callback = Callable(exit_sink, "reset_game")
	exit_screen._pending_exit_callback = Callable(exit_sink, "exit_to_menu")
	exit_screen._pending_owner = owner
	exit_screen._pending_registry = registry
	exit_screen._scene_node = scene
	exit_screen._reward_grant_handler = FakeRewardGrantHandler.new()
	exit_screen._plaza_progress_handler = exit_progress
	exit_screen._screen_state_handler = exit_screen_state
	exit_screen._plaza_scene_handler = FakePlazaSceneHandler.new()
	exit_screen._plaza_save_store = save_store
	handler.finish_action_from_screen(
		StageClearResultFinishFlowHandler.ACTION_EXIT_TO_MENU,
		exit_screen,
		Callable(exit_sink, "free_result_scene")
	)
	_expect(exit_progress.apply_calls == 1 and not exit_progress.seen_grant_ap, "screen finish adapter should apply stage progress without AP for exit")
	_expect(exit_sink.exit_calls == 1 and exit_sink.reset_calls == 0, "screen finish adapter should prefer the exit callback")
	screen._pending_owner = null
	screen._pending_registry = null
	screen._scene_node = null
	screen._reward_grant_handler = null
	screen._plaza_progress_handler = null
	screen._screen_state_handler = null
	screen._plaza_scene_handler = null
	screen._plaza_save_store = null
	exit_screen._pending_owner = null
	exit_screen._pending_registry = null
	exit_screen._scene_node = null
	exit_screen._reward_grant_handler = null
	exit_screen._plaza_progress_handler = null
	exit_screen._screen_state_handler = null
	exit_screen._plaza_scene_handler = null
	exit_screen._plaza_save_store = null
	scene.free()


func _verify_inactive_context_is_ignored() -> void:
	var sink := FlowSink.new()
	var handler := StageClearResultFinishFlowHandler.new()
	handler.finish_next_stage(_context(sink, false, true))
	handler.finish_plaza_and_continue(_context(sink, false, true))
	handler.finish_exit_to_menu(_context(sink, false, true))
	_expect(sink.grant_calls == 0, "inactive finish context should not grant rewards")
	_expect(sink.apply_calls == 0, "inactive finish context should not apply progress")
	_expect(sink.mark_inactive_calls == 0, "inactive finish context should not mutate controller state")
	_expect(sink.reset_calls == 0 and sink.exit_calls == 0, "inactive finish context should not call callbacks")


func _verify_source_boundary() -> void:
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var registry_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_handler_registry.gd")
	var handler_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_finish_flow_handler.gd")
	var action_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_finish_action_data.gd")
	var screen_context_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_finish_screen_context_data.gd")
	var callback_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_scene_spawn_callback_data.gd")
	var screen_spawn_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_scene_spawn_screen_data.gd")
	_expect(registry_source.find("StageClearResultFinishFlowHandler.new()") >= 0, "handler registry should delegate completion flow to the finish handler")
	_expect(screen_source.find("func _finish_next_stage") < 0, "result screen should not keep next-stage completion wrappers")
	_expect(screen_source.find("func _finish_plaza_and_continue") < 0, "result screen should not keep plaza-continuation completion wrappers")
	_expect(screen_source.find("func _finish_exit_to_menu") < 0, "result screen should not keep exit completion wrappers")
	_expect(screen_source.find("func _mark_finish_flow_inactive") < 0, "result screen should delegate finish-state mutation callbacks to the state handler")
	_expect(screen_source.find(".build_context(") < 0, "result screen should not assemble finish-flow context directly")
	_expect(screen_source.find("func _finish_with_action") < 0, "result screen should not keep result-scene finish callback wrappers")
	_expect(screen_source.find("finish_action_from_screen") < 0, "result screen should not wire finish screen adapters directly")
	_expect(screen_source.find("\"grant_pending_rewards\"") < 0, "result screen should not own finish-flow context schema keys directly")
	_expect(screen_source.find("grant_pending_scene_rewards") < 0, "result screen should not wire pending reward callbacks directly")
	_expect(screen_source.find("apply_stage_clear_progress_from_callback") < 0, "result screen should not wire stage-progress callbacks directly")
	_expect(handler_source.find("func build_context") >= 0, "finish handler should expose finish-flow context schema assembly")
	_expect(handler_source.find("StageClearResultFinishActionData.build_context") >= 0, "finish handler should delegate finish-flow context schema assembly")
	_expect(handler_source.find("func finish_action") >= 0, "finish handler should expose finish action dispatch")
	_expect(handler_source.find("StageClearResultFinishActionData.finish_context_action") >= 0, "finish handler should delegate finish action dispatch")
	_expect(handler_source.find("func finish_action_from_screen") >= 0, "finish handler should expose screen finish adapters")
	_expect(handler_source.find("StageClearResultFinishScreenContextData.build_context_from_screen") >= 0, "finish handler should delegate screen context callback assembly")
	_expect(handler_source.find("func _build_grant_pending_rewards_callback") < 0, "finish handler should not own screen reward-grant callback wiring")
	_expect(handler_source.find("func _build_apply_stage_clear_progress_callback") < 0, "finish handler should not own screen progress callback wiring")
	_expect(handler_source.find("func _get_screen_object") < 0, "finish handler should not keep screen property readers")
	_expect(handler_source.find("func _finish_with_callback") < 0, "finish handler should not keep finish callback ordering internals")
	_expect(handler_source.find("func _get_callable") < 0, "finish handler should not keep finish context readers")
	_expect(action_data_source.find("static func build_context") >= 0, "finish action data should own finish-flow context schema")
	_expect(action_data_source.find("static func finish_context_action") >= 0, "finish action data should own action dispatch internals")
	_expect(action_data_source.find("static func _finish_with_callback") >= 0, "finish action data should own finish callback ordering")
	_expect(screen_context_source.find("static func build_context_from_screen") >= 0, "finish screen context data should own screen context assembly")
	_expect(screen_context_source.find("finish_flow_handler.build_context") >= 0, "finish screen context data should route schema assembly through the finish handler")
	_expect(screen_context_source.find("grant_pending_scene_rewards") >= 0, "finish screen context data should wire pending reward callbacks")
	_expect(screen_context_source.find("apply_stage_clear_progress_from_callback") >= 0, "finish screen context data should wire stage-progress callbacks")
	_expect(callback_source.find("finish_action_from_screen") >= 0, "spawn callback data should wire result-scene finish callbacks to the finish adapter")
	_expect(screen_spawn_source.find("StageClearResultSceneSpawnCallbackData.build_finish_action_callback") >= 0, "spawn screen data should build finish callbacks through callback data")
	_expect(handler_source.find("func finish_next_stage") >= 0, "finish handler should expose next-stage completion flow")
	_expect(handler_source.find("func finish_plaza_and_continue") >= 0, "finish handler should expose plaza continuation flow")
	_expect(handler_source.find("func finish_exit_to_menu") >= 0, "finish handler should expose exit completion flow")
	_expect(action_data_source.find("static func finish_next_stage") >= 0, "finish action data should own next-stage completion flow")
	_expect(action_data_source.find("static func finish_plaza_and_continue") >= 0, "finish action data should own plaza continuation flow")
	_expect(action_data_source.find("static func finish_exit_to_menu") >= 0, "finish action data should own exit completion flow")
	_expect(action_data_source.find("grant_pending_rewards") >= 0, "finish action data should own reward-grant timing")
	_expect(action_data_source.find("apply_stage_clear_progress") >= 0, "finish action data should own progress-apply timing")


func _context(sink: FlowSink, active: bool, include_exit: bool) -> Dictionary:
	return {
		"active": active,
		"reset_callback": Callable(sink, "reset_game"),
		"exit_callback": Callable(sink, "exit_to_menu") if include_exit else Callable(),
		"grant_pending_rewards": Callable(sink, "grant_pending_rewards"),
		"apply_stage_clear_progress": Callable(sink, "apply_stage_clear_progress"),
		"mark_inactive": Callable(sink, "mark_inactive"),
		"free_result_scene": Callable(sink, "free_result_scene"),
		"free_plaza_scene": Callable(sink, "free_plaza_scene"),
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
