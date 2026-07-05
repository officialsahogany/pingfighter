extends SceneTree

const StageClearResultScreen := preload("res://scripts/core/stage_clear_result_screen.gd")
const StageClearResultShowFlowHandler := preload("res://scripts/core/stage_clear_result_show_flow_handler.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted


class FakeRegistry:
	extends RefCounted


class FakeRuntimeContextHandler:
	extends RefCounted

	var player_score: int = 5
	var boss_score: int = 0
	var current_stage: int = 4
	var score_calls: int = 0
	var stage_calls: int = 0
	var reset_stage_calls: int = 0
	var reset_registry: Object
	var reset_stage: int = 0

	func get_score_snapshot(_registry: Object) -> Dictionary:
		score_calls += 1
		return {
			"player_score": player_score,
			"boss_score": boss_score,
		}

	func get_current_stage(_owner: Object) -> int:
		stage_calls += 1
		return current_stage

	func reset_stage_for_result(registry: Object, stage_id: int) -> void:
		reset_stage_calls += 1
		reset_registry = registry
		reset_stage = stage_id


class FakeStageSnapshotBuilder:
	extends RefCounted

	var build_calls: int = 0
	var seen_start_snapshot: Dictionary = {}

	func build_stage_reward_snapshot(_owner: Object, _registry: Object, current_stage: int, stage_start_snapshot: Dictionary) -> Dictionary:
		build_calls += 1
		seen_start_snapshot = stage_start_snapshot.duplicate(true)
		return {
			"stage": current_stage,
			"start_gold": int(stage_start_snapshot.get("runtime_gold", 0)),
		}


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


class FakeScreenStateHandler:
	extends RefCounted

	var show_calls: int = 0
	var spawn_calls: int = 0
	var applied_show_state: Dictionary = {}
	var applied_spawn_state: Dictionary = {}

	func apply_show_state(_screen: Object, show_state: Dictionary) -> void:
		show_calls += 1
		applied_show_state = show_state.duplicate(true)

	func apply_spawn_state(_screen: Object, spawn_state: Dictionary) -> bool:
		spawn_calls += 1
		applied_spawn_state = spawn_state.duplicate(true)
		return bool(spawn_state.get("shown", false))


class FakeSceneSpawnFlowHandler:
	extends RefCounted

	var start_calls: int = 0
	var seen_screen: Object
	var seen_owner: Object
	var seen_delay: float = 0.0
	var seen_reset: Callable = Callable()
	var spawn_state: Dictionary = {"shown": true, "spawn_pending": false}

	func start_show_scene_spawn_from_screen(
		screen: Object,
		owner: Object,
		starpoint_choice_reward_delay: float,
		reset: Callable
	) -> Dictionary:
		start_calls += 1
		seen_screen = screen
		seen_owner = owner
		seen_delay = starpoint_choice_reward_delay
		seen_reset = reset
		return spawn_state.duplicate(true)


class FakeScreen:
	extends RefCounted

	var _stage_start_snapshot: Dictionary = {"runtime_gold": 17}
	var _scene_node: Control
	var _runtime_context_handler: Object
	var _stage_snapshot_builder: Object
	var _reward_grant_handler: Object
	var _plaza_progress_handler: Object
	var _starpoint_choice_handler: Object
	var _screen_state_handler: Object
	var _scene_spawn_flow_handler: Object
	var reset_calls: int = 0

	func reset() -> void:
		reset_calls += 1


class CallbackSink:
	extends RefCounted

	var reset_calls: int = 0
	var exit_calls: int = 0

	func reset_game() -> void:
		reset_calls += 1

	func exit_to_menu() -> void:
		exit_calls += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_player_win_builds_show_state()
	_verify_screen_adapter_applies_show_and_spawn_state()
	_verify_screen_adapter_ignores_boss_wins()
	_verify_boss_win_is_ignored()
	_verify_source_boundary()

	if _failures.is_empty():
		print("stage_clear_result_show_flow_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_player_win_builds_show_state() -> void:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var scene := Control.new()
	var runtime := FakeRuntimeContextHandler.new()
	var snapshot_builder := FakeStageSnapshotBuilder.new()
	var reward_handler := FakeResetHandler.new()
	var plaza_handler := FakeResetHandler.new()
	var starpoint_handler := FakeStarpointChoiceHandler.new()
	var callbacks := CallbackSink.new()
	var state: Dictionary = StageClearResultShowFlowHandler.new().build_show_state(
		owner,
		registry,
		Callable(callbacks, "reset_game"),
		Callable(callbacks, "exit_to_menu"),
		{"runtime_gold": 11},
		scene,
		runtime,
		snapshot_builder,
		reward_handler,
		plaza_handler,
		starpoint_handler
	)
	_expect(bool(state.get("shown", false)), "show flow should open for a player win")
	_expect(int(state.get("player_score", 0)) == 5, "show flow should expose player score")
	_expect(int(state.get("boss_score", -1)) == 0, "show flow should expose boss score")
	_expect(int(state.get("current_stage", 0)) == 4, "show flow should expose current stage")
	_expect(state.get("pending_owner", null) == owner, "show flow should preserve pending owner")
	_expect(state.get("pending_registry", null) == registry, "show flow should preserve pending registry")
	_expect(state.get("pending_reset_callback", Callable()) is Callable, "show flow should preserve reset callback")
	_expect(state.get("pending_exit_callback", Callable()) is Callable, "show flow should preserve exit callback")
	_expect(int((state.get("last_stage_reward_snapshot", {}) as Dictionary).get("stage", 0)) == 4, "show flow should build stage reward snapshot")
	_expect(int((state.get("last_stage_reward_snapshot", {}) as Dictionary).get("start_gold", 0)) == 11, "show flow should pass stage-start snapshot")
	_expect(bool(state.get("active", false)), "show flow should activate the result screen")
	_expect(bool(state.get("spawn_pending", false)), "show flow should begin in pending-spawn state")
	_expect(runtime.score_calls == 1 and runtime.stage_calls == 1, "show flow should query score and stage through runtime context")
	_expect(runtime.reset_stage_calls == 1 and runtime.reset_stage == 4 and runtime.reset_registry == registry, "show flow should reset stage-specific result state")
	_expect(snapshot_builder.build_calls == 1, "show flow should build one stage reward snapshot")
	_expect(reward_handler.reset_calls == 1, "show flow should reset reward grant state")
	_expect(plaza_handler.reset_calls == 1, "show flow should reset plaza progress state")
	_expect(starpoint_handler.reset_calls == 1 and starpoint_handler.seen_scene == scene, "show flow should reset starpoint choice state")
	starpoint_handler.seen_scene = null
	state.clear()
	scene.free()


func _verify_screen_adapter_applies_show_and_spawn_state() -> void:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var scene := Control.new()
	var runtime := FakeRuntimeContextHandler.new()
	runtime.current_stage = 6
	var snapshot_builder := FakeStageSnapshotBuilder.new()
	var reward_handler := FakeResetHandler.new()
	var plaza_handler := FakeResetHandler.new()
	var starpoint_handler := FakeStarpointChoiceHandler.new()
	var screen_state := FakeScreenStateHandler.new()
	var scene_spawn := FakeSceneSpawnFlowHandler.new()
	var screen := FakeScreen.new()
	screen._scene_node = scene
	screen._runtime_context_handler = runtime
	screen._stage_snapshot_builder = snapshot_builder
	screen._reward_grant_handler = reward_handler
	screen._plaza_progress_handler = plaza_handler
	screen._starpoint_choice_handler = starpoint_handler
	screen._screen_state_handler = screen_state
	screen._scene_spawn_flow_handler = scene_spawn

	var callbacks := CallbackSink.new()
	var shown: bool = StageClearResultShowFlowHandler.new().show_from_screen(
		screen,
		owner,
		registry,
		Callable(callbacks, "reset_game"),
		Callable(callbacks, "exit_to_menu"),
		0.65
	)
	_expect(shown, "screen show adapter should return applied spawn state")
	_expect(screen_state.show_calls == 1, "screen show adapter should apply show state through the screen state handler")
	_expect(screen_state.spawn_calls == 1, "screen show adapter should apply spawn state through the screen state handler")
	_expect(int(screen_state.applied_show_state.get("current_stage", 0)) == 6, "screen show adapter should pass current stage into show state")
	_expect(int((screen_state.applied_show_state.get("last_stage_reward_snapshot", {}) as Dictionary).get("start_gold", 0)) == 17, "screen show adapter should pass stage-start snapshot into show state")
	_expect(scene_spawn.start_calls == 1 and scene_spawn.seen_screen == screen and scene_spawn.seen_owner == owner, "screen show adapter should start scene spawn from the screen")
	_expect(is_equal_approx(scene_spawn.seen_delay, 0.65), "screen show adapter should pass starpoint reward delay to spawn flow")
	_expect(scene_spawn.seen_reset.is_valid(), "screen show adapter should pass the screen reset callback to spawn flow")
	_expect(reward_handler.reset_calls == 1 and plaza_handler.reset_calls == 1, "screen show adapter should reset show-time handlers")
	_expect(starpoint_handler.reset_calls == 1 and starpoint_handler.seen_scene == scene, "screen show adapter should reset starpoint state with the current scene")
	starpoint_handler.seen_scene = null
	scene_spawn.seen_screen = null
	scene_spawn.seen_owner = null
	scene_spawn.seen_reset = Callable()
	screen_state.applied_show_state.clear()
	screen_state.applied_spawn_state.clear()
	screen._scene_node = null
	screen._runtime_context_handler = null
	screen._stage_snapshot_builder = null
	screen._reward_grant_handler = null
	screen._plaza_progress_handler = null
	screen._starpoint_choice_handler = null
	screen._screen_state_handler = null
	screen._scene_spawn_flow_handler = null
	scene.free()


func _verify_screen_adapter_ignores_boss_wins() -> void:
	var runtime := FakeRuntimeContextHandler.new()
	runtime.player_score = 0
	runtime.boss_score = 5
	var screen_state := FakeScreenStateHandler.new()
	var scene_spawn := FakeSceneSpawnFlowHandler.new()
	var screen := FakeScreen.new()
	screen._runtime_context_handler = runtime
	screen._stage_snapshot_builder = FakeStageSnapshotBuilder.new()
	screen._reward_grant_handler = FakeResetHandler.new()
	screen._plaza_progress_handler = FakeResetHandler.new()
	screen._starpoint_choice_handler = FakeStarpointChoiceHandler.new()
	screen._screen_state_handler = screen_state
	screen._scene_spawn_flow_handler = scene_spawn
	var shown: bool = StageClearResultShowFlowHandler.new().show_from_screen(
		screen,
		FakeOwner.new(),
		FakeRegistry.new(),
		Callable(),
		Callable(),
		0.65
	)
	_expect(not shown, "screen show adapter should ignore boss wins")
	_expect(screen_state.show_calls == 0 and screen_state.spawn_calls == 0, "ignored boss wins should not apply screen state")
	_expect(scene_spawn.start_calls == 0, "ignored boss wins should not start scene spawn")


func _verify_boss_win_is_ignored() -> void:
	var runtime := FakeRuntimeContextHandler.new()
	runtime.player_score = 1
	runtime.boss_score = 5
	var reward_handler := FakeResetHandler.new()
	var state: Dictionary = StageClearResultShowFlowHandler.new().build_show_state(
		FakeOwner.new(),
		FakeRegistry.new(),
		Callable(),
		Callable(),
		{},
		null,
		runtime,
		FakeStageSnapshotBuilder.new(),
		reward_handler,
		FakeResetHandler.new(),
		FakeStarpointChoiceHandler.new()
	)
	_expect(not bool(state.get("shown", true)), "show flow should ignore boss wins")
	_expect(reward_handler.reset_calls == 0, "ignored boss wins should not reset reward state")
	_expect(runtime.reset_stage_calls == 0, "ignored boss wins should not reset stage state")


func _verify_source_boundary() -> void:
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var registry_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_handler_registry.gd")
	var handler_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_show_flow_handler.gd")
	var state_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_show_state_data.gd")
	var screen_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_show_screen_data.gd")
	_expect(registry_source.find("StageClearResultShowFlowHandler.new()") >= 0, "handler registry should delegate show flow setup")
	_expect(screen_source.find("build_show_state(") < 0, "result screen should not pass show-flow dependencies directly")
	_expect(screen_source.find("apply_show_state") < 0, "result screen should not apply show state directly")
	_expect(screen_source.find("start_show_scene_spawn_from_screen") < 0, "result screen should not start show-spawn flow directly")
	_expect(screen_source.find("reset_stage_for_result(registry, current_stage)") < 0, "result screen should not own show-time stage reset")
	_expect(screen_source.find("_stage_snapshot_builder.build_stage_reward_snapshot") < 0, "result screen should not build show-time reward snapshots directly")
	_expect(handler_source.find("func build_show_state") >= 0, "show flow handler should expose show state assembly")
	_expect(handler_source.find("StageClearResultShowStateData.build_show_state") >= 0, "show flow handler should delegate show state assembly")
	_expect(handler_source.find("func show_from_screen") >= 0, "show flow handler should own screen show adapters")
	_expect(handler_source.find("StageClearResultShowScreenData.build_show_state_from_screen") >= 0, "show flow handler should delegate screen show-state context assembly")
	_expect(handler_source.find("StageClearResultShowScreenData.apply_show_state_and_spawn_from_screen") >= 0, "show flow handler should delegate screen show-state apply and spawn wiring")
	_expect(handler_source.find("func _get_score_snapshot") < 0, "show flow handler should not keep runtime score readers")
	_expect(handler_source.find("func _get_current_stage") < 0, "show flow handler should not keep runtime stage readers")
	_expect(handler_source.find("func _reset_handler") < 0, "show flow handler should not keep show-time reset internals")
	_expect(handler_source.find("func _get_screen_object") < 0, "show flow handler should not keep screen object readers")
	_expect(handler_source.find("func _get_screen_dictionary") < 0, "show flow handler should not keep screen dictionary readers")
	_expect(state_data_source.find("static func build_show_state") >= 0, "show state data should own show-state assembly")
	_expect(state_data_source.find("reset_stage_for_result") >= 0, "show state data should own show-time stage reset")
	_expect(state_data_source.find("build_stage_reward_snapshot") >= 0, "show state data should own show-time stage reward snapshot")
	_expect(state_data_source.find("get_score_snapshot") >= 0, "show state data should own score snapshot reads")
	_expect(state_data_source.find("get_current_stage") >= 0, "show state data should own current-stage reads")
	_expect(screen_data_source.find("static func build_show_state_from_screen") >= 0, "show screen data should own screen-backed show-state context assembly")
	_expect(screen_data_source.find("show_flow_handler.build_show_state") >= 0, "show screen data should route show-state schema assembly through the show flow handler")
	_expect(screen_data_source.find("apply_show_state") >= 0, "show screen data should apply screen show state")
	_expect(screen_data_source.find("start_show_scene_spawn_from_screen") >= 0, "show screen data should start screen scene spawn")
	var screen := StageClearResultScreen.new()
	_expect(screen != null, "result screen should instantiate with the show flow handler")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
