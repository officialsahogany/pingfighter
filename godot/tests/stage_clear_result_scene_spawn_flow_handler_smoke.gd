extends SceneTree

const StageClearResultSceneSpawnFlowHandler := preload("res://scripts/core/stage_clear_result_scene_spawn_flow_handler.gd")
const StageClearResultScreen := preload("res://scripts/core/stage_clear_result_screen.gd")

var _failures: Array[String] = []


class FakeNodeOwner:
	extends Node2D


class FakeRedrawOwner:
	extends RefCounted

	var redraw_calls: int = 0

	func queue_redraw() -> void:
		redraw_calls += 1


class FakeShellHandler:
	extends RefCounted

	var prewarm_shell_ready: bool = true
	var prewarm_step_done: bool = false
	var spawn_result: Control
	var status: Dictionary = {}
	var prewarm_shell_calls: int = 0
	var prewarm_step_calls: int = 0
	var spawn_calls: int = 0
	var ready_calls: int = 0
	var key_calls: int = 0
	var free_screen_calls: int = 0
	var seen_character: String = ""
	var seen_stage: int = 0
	var seen_threaded: bool = false
	var seen_owner: Object
	var seen_config: Dictionary = {}
	var seen_callbacks: Dictionary = {}
	var seen_free_screen: Object

	func prewarm_scene_shell() -> bool:
		prewarm_shell_calls += 1
		status["result_scene_packed"] = prewarm_shell_ready
		return prewarm_shell_ready

	func prewarm_assets_step(selected_character_type: String, stage_id: int, use_threaded_texture_loads: bool = false) -> bool:
		prewarm_step_calls += 1
		seen_character = selected_character_type
		seen_stage = stage_id
		seen_threaded = use_threaded_texture_loads
		status["selected_character_type"] = selected_character_type
		status["current_stage"] = stage_id
		status["threaded"] = use_threaded_texture_loads
		return prewarm_step_done

	func get_prewarm_status() -> Dictionary:
		return status.duplicate(true)

	func spawn_scene(owner: Object, config: Dictionary, callbacks: Dictionary) -> Control:
		spawn_calls += 1
		seen_owner = owner
		seen_config = config.duplicate(true)
		seen_callbacks = callbacks.duplicate(true)
		return spawn_result

	func build_callbacks(
		next_stage: Callable,
		exit_to_menu: Callable,
		roll_box_reward: Callable,
		grant_immediate_box_reward: Callable,
		enter_plaza: Callable
	) -> Dictionary:
		return {
			"next_stage": next_stage,
			"exit_to_menu": exit_to_menu,
			"roll_box_reward": roll_box_reward,
			"grant_immediate_box_reward": grant_immediate_box_reward,
			"enter_plaza": enter_plaza,
		}

	func are_assets_ready_for_spawn(selected_character_type: String, stage_id: int) -> bool:
		ready_calls += 1
		seen_character = selected_character_type
		seen_stage = stage_id
		return selected_character_type == "viper" and stage_id == 5

	func get_required_scene_asset_keys(stage_id: int) -> Array:
		key_calls += 1
		seen_stage = stage_id
		return ["background_texture", "stage%d_key" % stage_id]

	func free_screen_result_scene(screen: Object) -> void:
		free_screen_calls += 1
		seen_free_screen = screen
		if screen != null:
			screen.set("_scene_node", null)


class FlowSink:
	extends RefCounted

	var prewarm_calls: int = 0
	var spawn_calls: int = 0
	var reset_calls: int = 0
	var free_calls: int = 0
	var prewarm_result: bool = false
	var spawn_result: bool = false

	func prewarm_assets_step(_owner: Object, _registry: Object) -> bool:
		prewarm_calls += 1
		return prewarm_result

	func spawn_result_scene(_owner: Object) -> bool:
		spawn_calls += 1
		return spawn_result

	func reset() -> void:
		reset_calls += 1

	func free_result_scene() -> void:
		free_calls += 1


class FakeSceneConfigBuilder:
	extends RefCounted

	var calls: int = 0
	var seen_player_score: int = 0
	var seen_boss_score: int = 0
	var seen_stage: int = 0
	var seen_character: String = ""
	var seen_reward_plan: Dictionary = {}
	var seen_stage_reward_snapshot: Dictionary = {}
	var seen_owner: Object
	var seen_registry: Object

	func build_config(
		player_score: int,
		boss_score: int,
		current_stage: int,
		selected_character_type: String,
		reward_plan: Dictionary,
		stage_reward_snapshot: Dictionary,
		owner: Object,
		registry: Object
	) -> Dictionary:
		calls += 1
		seen_player_score = player_score
		seen_boss_score = boss_score
		seen_stage = current_stage
		seen_character = selected_character_type
		seen_reward_plan = reward_plan.duplicate(true)
		seen_stage_reward_snapshot = stage_reward_snapshot.duplicate(true)
		seen_owner = owner
		seen_registry = registry
		return {
			"player_score": player_score,
			"boss_score": boss_score,
			"current_stage": current_stage,
			"selected_character_type": selected_character_type,
			"reward_plan": reward_plan.duplicate(true),
			"stage_reward_snapshot": stage_reward_snapshot.duplicate(true),
			"runtime_owner": owner,
			"runtime_registry": registry,
		}


class FakeRuntimeContextHandler:
	extends RefCounted

	var result_character_type: String = "blacksmith"
	var seen_owner: Object

	func get_result_victory_character_type(owner: Object) -> String:
		seen_owner = owner
		return result_character_type


class FakeRewardGrantHandler:
	extends RefCounted

	var roll_calls: int = 0
	var seen_reward: Dictionary = {}
	var seen_owner: Object
	var seen_registry: Object

	func roll_box_reward(reward: Dictionary, owner: Object, registry: Object) -> Dictionary:
		roll_calls += 1
		seen_reward = reward.duplicate(true)
		seen_owner = owner
		seen_registry = registry
		return {"rolled": true}


class FakeImmediateRewardFlowHandler:
	extends RefCounted

	var grant_calls: int = 0
	var seen_reward: Dictionary = {}
	var seen_box_index: int = -1
	var seen_screen: Object
	var seen_owner: Object
	var seen_registry: Object
	var seen_reward_grant_handler: Object
	var seen_starpoint_choice_handler: Object
	var seen_mythic_acquisition_handler: Object
	var seen_delay: float = 0.0

	func grant_immediate_box_reward_from_screen(
		reward: Dictionary,
		box_index: int,
		screen: Object,
		owner: Object,
		registry: Object,
		reward_grant_handler: Object,
		starpoint_choice_handler: Object,
		mythic_acquisition_handler: Object,
		delay: float
	) -> bool:
		grant_calls += 1
		seen_reward = reward.duplicate(true)
		seen_box_index = box_index
		seen_screen = screen
		seen_owner = owner
		seen_registry = registry
		seen_reward_grant_handler = reward_grant_handler
		seen_starpoint_choice_handler = starpoint_choice_handler
		seen_mythic_acquisition_handler = mythic_acquisition_handler
		seen_delay = delay
		return true


class FakeFinishFlowHandler:
	extends RefCounted

	var finish_calls: int = 0
	var seen_action: String = ""
	var seen_screen: Object
	var seen_free_result_scene: Callable = Callable()

	func finish_action_from_screen(action: String, screen: Object, free_result_scene: Callable) -> void:
		finish_calls += 1
		seen_action = action
		seen_screen = screen
		seen_free_result_scene = free_result_scene


class FakePlazaEnterFlowHandler:
	extends RefCounted

	var enter_calls: int = 0
	var seen_screen: Object
	var seen_free_result_scene: Callable = Callable()
	var seen_finish_plaza_and_continue: Callable = Callable()

	func finish_enter_plaza_from_screen(
		screen: Object,
		free_result_scene: Callable,
		finish_plaza_and_continue: Callable
	) -> void:
		enter_calls += 1
		seen_screen = screen
		seen_free_result_scene = free_result_scene
		seen_finish_plaza_and_continue = finish_plaza_and_continue


class FakeScreen:
	extends RefCounted

	var player_score: int = 0
	var boss_score: int = 0
	var current_stage: int = 1
	var _pending_owner: Object
	var _pending_registry: Object
	var _scene_node: Control
	var _spawn_pending: bool = false
	var _scene_shell_handler: Object
	var _scene_config_builder: Object
	var _runtime_context_handler: Object
	var _reward_grant_handler: Object
	var _finish_flow_handler: Object
	var _plaza_enter_flow_handler: Object
	var _immediate_reward_flow_handler: Object
	var _starpoint_choice_handler: Object
	var _mythic_acquisition_handler: Object
	var _last_stage_reward_snapshot: Dictionary = {}
	var reward_plan: Dictionary = {}

	func get_reward_plan() -> Dictionary:
		return reward_plan.duplicate(true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_shell_prewarm_result()
	_verify_asset_prewarm_result()
	_verify_spawn_result_scene()
	_verify_spawn_configured_result_scene()
	_verify_screen_spawn_adapter()
	_verify_show_scene_spawn_flow()
	_verify_pending_spawn_flow()
	_verify_screen_show_and_pending_adapters()
	_verify_screen_pending_adapter_uses_internal_spawn_callback()
	_verify_readiness_and_required_key_delegation()
	_verify_source_boundary()

	if _failures.is_empty():
		print("stage_clear_result_scene_spawn_flow_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_shell_prewarm_result() -> void:
	var shell := FakeShellHandler.new()
	var result: Dictionary = StageClearResultSceneSpawnFlowHandler.new().prewarm_scene_shell(shell)
	_expect(shell.prewarm_shell_calls == 1, "spawn flow should delegate shell prewarm")
	_expect(bool(result.get("ready", false)), "spawn flow should expose shell prewarm readiness")
	_expect(bool((result.get("status", {}) as Dictionary).get("result_scene_packed", false)), "spawn flow should return shell prewarm status")


func _verify_asset_prewarm_result() -> void:
	var shell := FakeShellHandler.new()
	shell.prewarm_step_done = true
	var result: Dictionary = StageClearResultSceneSpawnFlowHandler.new().prewarm_assets_step(
		shell,
		"viper",
		5,
		true
	)
	_expect(shell.prewarm_step_calls == 1, "spawn flow should delegate staged asset prewarm")
	_expect(shell.seen_character == "viper", "spawn flow should pass selected character to shell prewarm")
	_expect(shell.seen_stage == 5, "spawn flow should pass stage id to shell prewarm")
	_expect(shell.seen_threaded, "spawn flow should pass threaded prewarm mode")
	_expect(bool(result.get("done", false)), "spawn flow should expose staged prewarm completion")
	_expect(str((result.get("status", {}) as Dictionary).get("selected_character_type", "")) == "viper", "spawn flow should return staged prewarm status")


func _verify_spawn_result_scene() -> void:
	var handler := StageClearResultSceneSpawnFlowHandler.new()
	var shell := FakeShellHandler.new()
	var spawned_scene := Control.new()
	shell.spawn_result = spawned_scene
	var current_scene := Control.new()
	var sink := FlowSink.new()
	var owner := FakeNodeOwner.new()
	root.add_child(owner)
	var scene: Control = handler.spawn_result_scene(
		owner,
		current_scene,
		shell,
		{"player_score": 5},
		{"next_stage": Callable()},
		Callable(sink, "free_result_scene")
	)
	_expect(sink.free_calls == 1, "spawn flow should free an existing result scene before respawn")
	_expect(shell.spawn_calls == 1, "spawn flow should delegate result scene spawning")
	_expect(shell.seen_owner == owner, "spawn flow should pass owner to scene shell")
	_expect(int(shell.seen_config.get("player_score", 0)) == 5, "spawn flow should pass scene config")
	_expect(shell.seen_callbacks.has("next_stage"), "spawn flow should pass scene callbacks")
	_expect(scene == spawned_scene, "spawn flow should return the spawned result scene")
	current_scene.free()
	spawned_scene.free()
	owner.queue_free()


func _verify_spawn_configured_result_scene() -> void:
	var handler := StageClearResultSceneSpawnFlowHandler.new()
	var shell := FakeShellHandler.new()
	var config_builder := FakeSceneConfigBuilder.new()
	var spawned_scene := Control.new()
	shell.spawn_result = spawned_scene
	var current_scene := Control.new()
	var sink := FlowSink.new()
	var owner := FakeNodeOwner.new()
	var registry := RefCounted.new()
	root.add_child(owner)
	var scene: Control = handler.spawn_configured_result_scene(
		owner,
		current_scene,
		shell,
		config_builder,
		7,
		2,
		6,
		"blacksmith",
		{"reward_count": 2},
		{"passive_items": [{"name": "new_passive"}]},
		owner,
		registry,
		Callable(sink, "reset"),
		Callable(sink, "reset"),
		Callable(sink, "reset"),
		Callable(sink, "reset"),
		Callable(sink, "reset"),
		Callable(sink, "free_result_scene")
	)
	_expect(config_builder.calls == 1, "spawn flow should delegate configured scene payload assembly to the scene config builder")
	_expect(config_builder.seen_player_score == 7 and config_builder.seen_boss_score == 2, "configured spawn should pass result scores to the config builder")
	_expect(config_builder.seen_stage == 6 and config_builder.seen_character == "blacksmith", "configured spawn should pass stage and character to the config builder")
	_expect(config_builder.seen_owner == owner and config_builder.seen_registry == registry, "configured spawn should pass runtime owner and registry to the config builder")
	_expect(sink.free_calls == 1, "configured spawn should free an existing result scene before respawn")
	_expect(shell.spawn_calls == 1, "configured spawn should delegate scene creation to the shell")
	_expect(int(shell.seen_config.get("player_score", 0)) == 7, "configured spawn should pass built scene config to the shell")
	_expect(shell.seen_callbacks.has("grant_immediate_box_reward"), "configured spawn should pass built callback schema to the shell")
	_expect(scene == spawned_scene, "configured spawn should return the spawned result scene")
	current_scene.free()
	spawned_scene.free()
	owner.queue_free()


func _verify_screen_spawn_adapter() -> void:
	var handler := StageClearResultSceneSpawnFlowHandler.new()
	var shell := FakeShellHandler.new()
	var config_builder := FakeSceneConfigBuilder.new()
	var runtime_context := FakeRuntimeContextHandler.new()
	var reward_grant := FakeRewardGrantHandler.new()
	var finish_flow := FakeFinishFlowHandler.new()
	var plaza_enter := FakePlazaEnterFlowHandler.new()
	var immediate_reward := FakeImmediateRewardFlowHandler.new()
	var starpoint_handler := RefCounted.new()
	var mythic_handler := RefCounted.new()
	var screen := FakeScreen.new()
	var current_scene := Control.new()
	var spawned_scene := Control.new()
	var owner := FakeNodeOwner.new()
	var registry := RefCounted.new()
	root.add_child(owner)
	shell.spawn_result = spawned_scene
	screen.player_score = 8
	screen.boss_score = 3
	screen.current_stage = 6
	screen._pending_owner = owner
	screen._pending_registry = registry
	screen._scene_node = current_scene
	screen._scene_shell_handler = shell
	screen._scene_config_builder = config_builder
	screen._runtime_context_handler = runtime_context
	screen._reward_grant_handler = reward_grant
	screen._finish_flow_handler = finish_flow
	screen._plaza_enter_flow_handler = plaza_enter
	screen._immediate_reward_flow_handler = immediate_reward
	screen._starpoint_choice_handler = starpoint_handler
	screen._mythic_acquisition_handler = mythic_handler
	screen._last_stage_reward_snapshot = {"stage_clear_gold": 42}
	screen.reward_plan = {"reward_count": 2}

	var spawned: bool = handler.spawn_result_scene_from_screen(
		owner,
		screen,
		0.65
	)
	_expect(spawned, "screen spawn adapter should report a successful configured spawn")
	_expect(screen._scene_node == spawned_scene, "screen spawn adapter should update the screen scene node")
	_expect(shell.free_screen_calls == 1 and shell.seen_free_screen == screen, "screen spawn adapter should free the previous result scene through the shell screen adapter")
	_expect(config_builder.calls == 1, "screen spawn adapter should build scene config")
	_expect(config_builder.seen_player_score == 8 and config_builder.seen_boss_score == 3, "screen spawn adapter should read result scores from the screen")
	_expect(config_builder.seen_stage == 6 and config_builder.seen_character == "blacksmith", "screen spawn adapter should read stage and result character from screen context")
	_expect(config_builder.seen_reward_plan == {"reward_count": 2}, "screen spawn adapter should pass the screen reward plan")
	_expect(config_builder.seen_stage_reward_snapshot == {"stage_clear_gold": 42}, "screen spawn adapter should pass the stage reward snapshot")
	_expect(shell.spawn_calls == 1 and shell.seen_owner == owner, "screen spawn adapter should delegate scene spawn to the shell")

	var next_value: Variant = shell.seen_callbacks.get("next_stage", Callable())
	var next_callback: Callable = next_value if next_value is Callable else Callable()
	next_callback.call()
	_expect(finish_flow.finish_calls == 1, "screen spawn adapter should build next-stage finish callbacks")
	_expect(finish_flow.seen_action == "next_stage", "next-stage callback should bind the next-stage finish action")
	_expect(finish_flow.seen_screen == screen and finish_flow.seen_free_result_scene.is_valid(), "next-stage callback should bind the screen and free callback")

	var exit_value: Variant = shell.seen_callbacks.get("exit_to_menu", Callable())
	var exit_callback: Callable = exit_value if exit_value is Callable else Callable()
	exit_callback.call()
	_expect(finish_flow.finish_calls == 2, "screen spawn adapter should build exit finish callbacks")
	_expect(finish_flow.seen_action == "exit_to_menu", "exit callback should bind the exit finish action")

	var plaza_value: Variant = shell.seen_callbacks.get("enter_plaza", Callable())
	var plaza_callback: Callable = plaza_value if plaza_value is Callable else Callable()
	plaza_callback.call()
	_expect(plaza_enter.enter_calls == 1, "screen spawn adapter should build plaza entry callbacks")
	_expect(plaza_enter.seen_screen == screen, "plaza entry callback should bind the screen")
	_expect(plaza_enter.seen_free_result_scene.is_valid(), "plaza entry callback should bind the free result callback")
	_expect(plaza_enter.seen_finish_plaza_and_continue.is_valid(), "plaza entry callback should bind plaza continuation")
	plaza_enter.seen_finish_plaza_and_continue.call()
	_expect(finish_flow.finish_calls == 3, "plaza continuation callback should route through the finish handler")
	_expect(finish_flow.seen_action == "plaza_continue", "plaza continuation callback should bind the plaza continuation action")

	var roll_value: Variant = shell.seen_callbacks.get("roll_box_reward", Callable())
	var roll_callback: Callable = roll_value if roll_value is Callable else Callable()
	roll_callback.call({"id": "box_reward"})
	_expect(reward_grant.roll_calls == 1, "screen spawn adapter should build a roll reward callback")
	_expect(reward_grant.seen_owner == owner and reward_grant.seen_registry == registry, "roll reward callback should bind runtime owner and registry")
	_expect(str(reward_grant.seen_reward.get("id", "")) == "box_reward", "roll reward callback should preserve the reward argument")

	var grant_value: Variant = shell.seen_callbacks.get("grant_immediate_box_reward", Callable())
	var grant_callback: Callable = grant_value if grant_value is Callable else Callable()
	grant_callback.call({"type": "starpoint"}, 4)
	_expect(immediate_reward.grant_calls == 1, "screen spawn adapter should build an immediate reward callback")
	_expect(immediate_reward.seen_screen == screen, "immediate reward callback should bind the result screen")
	_expect(immediate_reward.seen_owner == owner and immediate_reward.seen_registry == registry, "immediate reward callback should bind runtime owner and registry")
	_expect(immediate_reward.seen_reward_grant_handler == reward_grant, "immediate reward callback should bind the grant handler")
	_expect(immediate_reward.seen_starpoint_choice_handler == starpoint_handler, "immediate reward callback should bind the starpoint handler")
	_expect(immediate_reward.seen_mythic_acquisition_handler == mythic_handler, "immediate reward callback should bind the mythic handler")
	_expect(immediate_reward.seen_box_index == 4 and is_equal_approx(immediate_reward.seen_delay, 0.65), "immediate reward callback should preserve call-time box index and bound delay")
	shell.seen_callbacks.clear()
	shell.spawn_result = null
	config_builder.seen_owner = null
	config_builder.seen_registry = null
	reward_grant.seen_owner = null
	reward_grant.seen_registry = null
	finish_flow.seen_screen = null
	finish_flow.seen_free_result_scene = Callable()
	plaza_enter.seen_screen = null
	plaza_enter.seen_free_result_scene = Callable()
	plaza_enter.seen_finish_plaza_and_continue = Callable()
	immediate_reward.seen_screen = null
	immediate_reward.seen_owner = null
	immediate_reward.seen_registry = null
	immediate_reward.seen_reward_grant_handler = null
	immediate_reward.seen_starpoint_choice_handler = null
	immediate_reward.seen_mythic_acquisition_handler = null
	screen._pending_owner = null
	screen._pending_registry = null
	screen._scene_node = null
	screen._scene_shell_handler = null
	screen._scene_config_builder = null
	screen._runtime_context_handler = null
	screen._reward_grant_handler = null
	screen._finish_flow_handler = null
	screen._plaza_enter_flow_handler = null
	screen._immediate_reward_flow_handler = null
	screen._starpoint_choice_handler = null
	screen._mythic_acquisition_handler = null
	current_scene.free()
	spawned_scene.free()
	owner.free()


func _verify_pending_spawn_flow() -> void:
	var handler := StageClearResultSceneSpawnFlowHandler.new()
	var sink := FlowSink.new()
	var owner := FakeRedrawOwner.new()
	_expect(
		not handler.update_pending_scene_spawn(false, owner, null, Callable(sink, "prewarm_assets_step"), Callable(sink, "spawn_result_scene"), Callable(sink, "reset")),
		"spawn flow should ignore inactive pending state"
	)
	_expect(sink.prewarm_calls == 0, "inactive pending state should not prewarm")

	sink = FlowSink.new()
	owner = FakeRedrawOwner.new()
	sink.prewarm_result = false
	_expect(
		handler.update_pending_scene_spawn(true, owner, null, Callable(sink, "prewarm_assets_step"), Callable(sink, "spawn_result_scene"), Callable(sink, "reset")),
		"incomplete prewarm should keep spawn pending"
	)
	_expect(sink.prewarm_calls == 1, "pending spawn should advance prewarm")
	_expect(sink.spawn_calls == 0, "incomplete prewarm should not spawn")
	_expect(owner.redraw_calls == 1, "incomplete prewarm should request owner redraw")

	sink = FlowSink.new()
	owner = FakeRedrawOwner.new()
	sink.prewarm_result = true
	sink.spawn_result = false
	_expect(
		not handler.update_pending_scene_spawn(true, owner, null, Callable(sink, "prewarm_assets_step"), Callable(sink, "spawn_result_scene"), Callable(sink, "reset")),
		"failed spawn should clear pending state through reset"
	)
	_expect(sink.spawn_calls == 1 and sink.reset_calls == 1, "failed spawn should reset the result screen")

	sink = FlowSink.new()
	owner = FakeRedrawOwner.new()
	sink.prewarm_result = true
	sink.spawn_result = true
	_expect(
		not handler.update_pending_scene_spawn(true, owner, null, Callable(sink, "prewarm_assets_step"), Callable(sink, "spawn_result_scene"), Callable(sink, "reset")),
		"successful spawn should clear pending state"
	)
	_expect(sink.spawn_calls == 1 and sink.reset_calls == 0, "successful spawn should not reset")
	_expect(owner.redraw_calls == 1, "successful spawn should request owner redraw")


func _verify_screen_pending_adapter_uses_internal_spawn_callback() -> void:
	var handler := StageClearResultSceneSpawnFlowHandler.new()
	var shell := FakeShellHandler.new()
	var config_builder := FakeSceneConfigBuilder.new()
	var runtime_context := FakeRuntimeContextHandler.new()
	var reward_grant := FakeRewardGrantHandler.new()
	var finish_flow := FakeFinishFlowHandler.new()
	var plaza_enter := FakePlazaEnterFlowHandler.new()
	var immediate_reward := FakeImmediateRewardFlowHandler.new()
	var screen := FakeScreen.new()
	var spawned_scene := Control.new()
	var owner := FakeNodeOwner.new()
	var registry := RefCounted.new()
	var sink := FlowSink.new()
	root.add_child(owner)
	shell.spawn_result = spawned_scene
	screen._spawn_pending = true
	screen.player_score = 8
	screen.boss_score = 3
	screen.current_stage = 6
	screen._pending_owner = owner
	screen._pending_registry = registry
	screen._scene_shell_handler = shell
	screen._scene_config_builder = config_builder
	screen._runtime_context_handler = runtime_context
	screen._reward_grant_handler = reward_grant
	screen._finish_flow_handler = finish_flow
	screen._plaza_enter_flow_handler = plaza_enter
	screen._immediate_reward_flow_handler = immediate_reward
	screen._starpoint_choice_handler = RefCounted.new()
	screen._mythic_acquisition_handler = RefCounted.new()
	screen.reward_plan = {"reward_count": 2}

	sink.prewarm_result = true
	var still_pending: bool = handler.update_pending_scene_spawn_from_screen(
		screen,
		Callable(sink, "prewarm_assets_step"),
		0.65,
		Callable(sink, "reset")
	)
	_expect(not still_pending, "screen pending adapter should clear pending spawn after a successful spawn")
	_expect(sink.prewarm_calls == 1 and sink.spawn_calls == 0, "screen pending adapter should own spawn callback construction instead of using a supplied spawn sink")
	_expect(screen._scene_node == spawned_scene, "screen pending adapter should spawn the result scene through its internal callback")
	_expect(config_builder.calls == 1, "screen pending adapter should build scene config through its internal spawn callback")
	shell.spawn_result = null
	config_builder.seen_owner = null
	config_builder.seen_registry = null
	screen._pending_owner = null
	screen._pending_registry = null
	screen._scene_node = null
	screen._scene_shell_handler = null
	screen._scene_config_builder = null
	screen._runtime_context_handler = null
	screen._reward_grant_handler = null
	screen._finish_flow_handler = null
	screen._plaza_enter_flow_handler = null
	screen._immediate_reward_flow_handler = null
	screen._starpoint_choice_handler = null
	screen._mythic_acquisition_handler = null
	spawned_scene.free()
	owner.free()


func _verify_screen_show_and_pending_adapters() -> void:
	var handler := StageClearResultSceneSpawnFlowHandler.new()
	var shell := FakeShellHandler.new()
	var runtime_context := FakeRuntimeContextHandler.new()
	runtime_context.result_character_type = "viper"
	var screen := FakeScreen.new()
	var owner := FakeRedrawOwner.new()
	var registry := RefCounted.new()
	var sink := FlowSink.new()
	screen.current_stage = 5
	screen._pending_owner = owner
	screen._pending_registry = registry
	screen._scene_shell_handler = shell
	screen._runtime_context_handler = runtime_context
	var result: Dictionary = handler.start_show_scene_spawn_from_screen(
		screen,
		owner,
		0.65,
		Callable(sink, "reset")
	)
	_expect(not bool(result.get("shown", true)), "screen show adapter should report spawn failure when required screen spawn dependencies are absent")
	_expect(not bool(result.get("spawn_pending", true)), "screen show adapter should clear pending spawn after a failed ready spawn")
	_expect(sink.reset_calls == 1, "screen show adapter should use the supplied reset callback when its internal spawn callback fails")
	_expect(shell.ready_calls == 1 and shell.seen_character == "viper", "screen show adapter should read result character through runtime context")
	screen._pending_owner = null
	screen._pending_registry = null
	screen._scene_shell_handler = null
	screen._runtime_context_handler = null


func _verify_show_scene_spawn_flow() -> void:
	var handler := StageClearResultSceneSpawnFlowHandler.new()
	var shell := FakeShellHandler.new()
	var sink := FlowSink.new()
	var owner := FakeRedrawOwner.new()
	var result: Dictionary = handler.start_show_scene_spawn(
		owner,
		shell,
		"smasher",
		1,
		Callable(sink, "spawn_result_scene"),
		Callable(sink, "reset")
	)
	_expect(bool(result.get("shown", false)), "unready show spawn should keep the result flow visible")
	_expect(bool(result.get("spawn_pending", false)), "unready show spawn should keep scene spawn pending")
	_expect(sink.spawn_calls == 0, "unready show spawn should not spawn immediately")
	_expect(owner.redraw_calls == 1, "unready show spawn should request owner redraw")

	shell = FakeShellHandler.new()
	sink = FlowSink.new()
	owner = FakeRedrawOwner.new()
	sink.spawn_result = true
	result = handler.start_show_scene_spawn(
		owner,
		shell,
		"viper",
		5,
		Callable(sink, "spawn_result_scene"),
		Callable(sink, "reset")
	)
	_expect(bool(result.get("shown", false)), "ready show spawn should keep the result flow visible")
	_expect(not bool(result.get("spawn_pending", true)), "ready show spawn should clear scene spawn pending")
	_expect(sink.spawn_calls == 1 and sink.reset_calls == 0, "ready show spawn should spawn immediately without reset")
	_expect(owner.redraw_calls == 0, "ready show spawn should not request pending redraw")

	shell = FakeShellHandler.new()
	sink = FlowSink.new()
	owner = FakeRedrawOwner.new()
	sink.spawn_result = false
	result = handler.start_show_scene_spawn(
		owner,
		shell,
		"viper",
		5,
		Callable(sink, "spawn_result_scene"),
		Callable(sink, "reset")
	)
	_expect(not bool(result.get("shown", true)), "failed ready show spawn should report the result flow as not shown")
	_expect(not bool(result.get("spawn_pending", true)), "failed ready show spawn should clear scene spawn pending")
	_expect(sink.spawn_calls == 1 and sink.reset_calls == 1, "failed ready show spawn should reset the result screen")


func _verify_readiness_and_required_key_delegation() -> void:
	var shell := FakeShellHandler.new()
	var handler := StageClearResultSceneSpawnFlowHandler.new()
	_expect(handler.are_assets_ready_for_spawn(shell, "viper", 5), "spawn flow should delegate asset readiness")
	_expect(shell.ready_calls == 1, "spawn flow should call readiness on scene shell")
	var keys: Array[String] = handler.get_required_scene_asset_keys(shell, 6)
	_expect(keys.has("background_texture"), "spawn flow should preserve required result asset keys")
	_expect(keys.has("stage6_key"), "spawn flow should preserve stage-specific required asset keys")
	_expect(shell.key_calls == 1 and shell.seen_stage == 6, "spawn flow should pass stage id to required-key lookup")


func _verify_source_boundary() -> void:
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var registry_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_handler_registry.gd")
	var callback_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_scene_spawn_callback_data.gd")
	var config_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_scene_spawn_config_data.gd")
	var core_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_scene_spawn_core_data.gd")
	var handler_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_scene_spawn_flow_handler.gd")
	var pending_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_scene_spawn_pending_data.gd")
	var screen_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_scene_spawn_screen_data.gd")
	var screen_pending_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_scene_spawn_screen_pending_data.gd")
	var shell_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_scene_spawn_shell_data.gd")
	_expect(registry_source.find("StageClearResultSceneSpawnFlowHandler.new()") >= 0, "handler registry should delegate result scene spawn flow")
	_expect(screen_source.find("_scene_shell_handler.prewarm_assets_step") < 0, "result screen should not directly advance scene-shell prewarm")
	_expect(screen_source.find("_scene_shell_handler.spawn_scene") < 0, "result screen should not directly spawn the result scene")
	_expect(screen_source.find("_scene_shell_handler.are_assets_ready_for_spawn") < 0, "result screen should not directly inspect scene-shell readiness")
	_expect(screen_source.find("if not prewarm_assets_step(_pending_owner, _pending_registry)") < 0, "result screen should not own pending-spawn prewarm branch")
	_expect(screen_source.find("func _are_scene_assets_ready_for_spawn") < 0, "result screen should not keep show-time scene readiness branching")
	_expect(screen_source.find("owner.queue_redraw()") < 0, "result screen should not own show-time pending redraw")
	_expect(screen_source.find("func _build_result_scene_config") < 0, "result screen should not keep result-scene config assembly wrappers")
	_expect(screen_source.find("func _build_result_scene_callbacks") < 0, "result screen should not keep result-scene callback assembly wrappers")
	_expect(screen_source.find("spawn_configured_result_scene(") < 0, "result screen should not call configured result scene spawn directly")
	_expect(screen_source.find("spawn_result_scene_from_screen") < 0, "result screen should not wire result-scene spawn callbacks directly")
	_expect(screen_source.find("Callable(_scene_spawn_flow_handler") < 0, "result screen should not build scene-spawn handler callbacks directly")
	_expect(screen_source.find("func _apply_show_spawn_flow") < 0, "result screen should not keep show-spawn wrapper helpers")
	_expect(screen_source.find("func _update_pending_scene_spawn") < 0, "result screen should not keep pending-spawn wrapper helpers")
	_expect(screen_source.find("func _spawn_result_scene") < 0, "result screen should not keep result-scene spawn wrapper helpers")
	_expect(screen_source.find("func _finish_enter_plaza") < 0, "result screen should not keep result-scene plaza callback wrappers")
	_expect(screen_source.find("func _finish_with_action") < 0, "result screen should not keep result-scene finish callback wrappers")
	_expect(screen_source.find("func _free_result_scene") < 0, "result screen should not keep result-scene free wrappers")
	_expect(handler_source.find("func spawn_configured_result_scene") >= 0, "spawn flow handler should expose configured result scene spawn orchestration")
	_expect(handler_source.find("func spawn_result_scene_from_screen") >= 0, "spawn flow handler should expose screen result scene spawn adapters")
	_expect(handler_source.find("func _build_result_scene_config") < 0, "spawn flow handler should not keep config wrapper shells")
	_expect(handler_source.find("func _build_result_scene_callbacks") < 0, "spawn flow handler should not keep callback schema wrapper shells")
	_expect(handler_source.find("func _build_spawn_result_scene_callback") < 0, "spawn flow handler should not keep screen spawn callback wrappers")
	_expect(handler_source.find("func _build_finish_action_callback") < 0, "spawn flow handler should not keep finish callback wrappers")
	_expect(handler_source.find("func _build_enter_plaza_callback") < 0, "spawn flow handler should not keep plaza callback wrappers")
	_expect(handler_source.find("func _build_roll_box_reward_callback") < 0, "spawn flow handler should not keep roll callback wrappers")
	_expect(handler_source.find("func _build_immediate_reward_callback") < 0, "spawn flow handler should not keep immediate reward callback wrappers")
	_expect(handler_source.find("func _build_free_result_scene_callback") < 0, "spawn flow handler should not keep free-scene callback wrappers")
	_expect(handler_source.find("func _get_result_victory_character_type") < 0, "spawn flow handler should not keep result-character wrapper shells")
	_expect(handler_source.find("func _get_screen_reward_plan") < 0, "spawn flow handler should not keep reward-plan wrapper shells")
	_expect(handler_source.find("func _get_screen_dictionary") < 0, "spawn flow handler should not keep dictionary-read wrapper shells")
	_expect(handler_source.find("func _get_screen_int") < 0, "spawn flow handler should not keep int-read wrapper shells")
	_expect(handler_source.find("func _get_screen_control") < 0, "spawn flow handler should not keep control-read wrapper shells")
	_expect(handler_source.find("func _get_screen_object") < 0, "spawn flow handler should not keep object-read wrapper shells")
	_expect(callback_data_source.find("static func build_result_scene_callbacks") >= 0, "spawn callback data should own result scene callback schema delegation")
	_expect(callback_data_source.find("static func build_spawn_result_scene_callback") >= 0, "spawn callback data should own screen result scene spawn callback wiring")
	_expect(callback_data_source.find("static func build_finish_action_callback") >= 0, "spawn callback data should own result scene finish callback wiring")
	_expect(callback_data_source.find("static func build_enter_plaza_callback") >= 0, "spawn callback data should own result scene plaza callback wiring")
	_expect(callback_data_source.find("static func build_roll_box_reward_callback") >= 0, "spawn callback data should own roll reward callback wiring")
	_expect(callback_data_source.find("static func build_immediate_reward_callback") >= 0, "spawn callback data should own immediate reward callback wiring")
	_expect(callback_data_source.find("static func build_free_result_scene_callback") >= 0, "spawn callback data should own free-result-scene callback wiring")
	_expect(config_data_source.find("static func build_result_scene_config") >= 0, "spawn config data should own result-scene config assembly")
	_expect(config_data_source.find("scene_config_builder.build_config") >= 0, "spawn config data should delegate to the scene config builder")
	_expect(config_data_source.find("static func get_result_victory_character_type") >= 0, "spawn config data should own result character lookup")
	_expect(config_data_source.find("static func get_screen_reward_plan") >= 0, "spawn config data should own screen reward-plan copying")
	_expect(config_data_source.find("static func get_screen_dictionary") >= 0, "spawn config data should own screen dictionary copying")
	_expect(config_data_source.find("static func get_screen_int") >= 0, "spawn config data should own screen integer reads")
	_expect(config_data_source.find("static func get_screen_control") >= 0, "spawn config data should own screen control reads")
	_expect(config_data_source.find("static func get_screen_object") >= 0, "spawn config data should own screen object reads")
	_expect(handler_source.find("StageClearResultSceneSpawnCallbackData") < 0, "spawn flow handler should not preload callback helpers after wrapper cleanup")
	_expect(handler_source.find("StageClearResultSceneSpawnConfigData") < 0, "spawn flow handler should not preload config helpers after wrapper cleanup")
	_expect(handler_source.find("scene_config_builder.build_config") < 0, "spawn flow handler should not directly build scene config payloads")
	_expect(handler_source.find("runtime_context_handler.get_result_victory_character_type") < 0, "spawn flow handler should not directly query runtime-context character type")
	_expect(core_data_source.find("static func spawn_result_scene") >= 0, "spawn core data should own raw result scene spawn")
	_expect(core_data_source.find("static func spawn_configured_result_scene") >= 0, "spawn core data should own configured result scene spawn")
	_expect(core_data_source.find("scene_shell_handler.spawn_scene") >= 0, "spawn core data should delegate scene creation to the shell")
	_expect(core_data_source.find("_call(free_result_scene)") >= 0, "spawn core data should free existing result scenes before respawn")
	_expect(core_data_source.find("StageClearResultSceneSpawnConfigData.build_result_scene_config") >= 0, "spawn core data should build configured scene payloads")
	_expect(core_data_source.find("StageClearResultSceneSpawnCallbackData.build_result_scene_callbacks") >= 0, "spawn core data should build configured scene callbacks")
	_expect(handler_source.find("StageClearResultSceneSpawnCoreData.spawn_result_scene") >= 0, "spawn flow handler should delegate raw result scene spawn")
	_expect(handler_source.find("StageClearResultSceneSpawnCoreData.spawn_configured_result_scene") >= 0, "spawn flow handler should delegate configured result scene spawn")
	_expect(handler_source.find("scene_shell_handler.spawn_scene") < 0, "spawn flow handler should not directly spawn scenes through the shell")
	_expect(handler_source.find("_call(free_result_scene)") < 0, "spawn flow handler should not directly free existing result scenes")
	_expect(screen_data_source.find("static func spawn_result_scene_from_screen") >= 0, "spawn screen data should own screen-backed result scene spawn assembly")
	_expect(screen_data_source.find("static func start_show_scene_spawn_from_screen") >= 0, "spawn screen data should expose screen-backed show-spawn assembly")
	_expect(screen_data_source.find("static func update_pending_scene_spawn_from_screen") >= 0, "spawn screen data should expose screen-backed pending-spawn assembly")
	_expect(screen_data_source.find("spawn_flow_handler.spawn_configured_result_scene") >= 0, "spawn screen data should invoke configured scene spawn")
	_expect(screen_data_source.find("StageClearResultSceneSpawnConfigData.get_screen_object(screen, \"_pending_owner\")") >= 0, "spawn screen data should read pending owner from screen")
	_expect(screen_data_source.find("StageClearResultSceneSpawnCallbackData.build_finish_action_callback") >= 0, "spawn screen data should build finish callbacks")
	_expect(screen_data_source.find("screen.set(\"_scene_node\", scene)") >= 0, "spawn screen data should update the screen scene node")
	_expect(screen_data_source.find("StageClearResultSceneSpawnScreenPendingData.start_show_scene_spawn_from_screen") >= 0, "spawn screen data should delegate screen show-spawn assembly")
	_expect(screen_data_source.find("StageClearResultSceneSpawnScreenPendingData.update_pending_scene_spawn_from_screen") >= 0, "spawn screen data should delegate screen pending-spawn assembly")
	_expect(screen_data_source.find("spawn_flow_handler.start_show_scene_spawn(") < 0, "spawn screen data should not directly assemble show-spawn calls")
	_expect(screen_data_source.find("spawn_flow_handler.update_pending_scene_spawn(") < 0, "spawn screen data should not directly assemble pending-spawn calls")
	_expect(screen_pending_data_source.find("static func start_show_scene_spawn_from_screen") >= 0, "spawn screen pending data should own screen-backed show-spawn assembly")
	_expect(screen_pending_data_source.find("static func update_pending_scene_spawn_from_screen") >= 0, "spawn screen pending data should own screen-backed pending-spawn assembly")
	_expect(screen_pending_data_source.find("spawn_flow_handler.start_show_scene_spawn") >= 0, "spawn screen pending data should invoke show-spawn through the flow surface")
	_expect(screen_pending_data_source.find("spawn_flow_handler.update_pending_scene_spawn") >= 0, "spawn screen pending data should invoke pending-spawn through the flow surface")
	_expect(screen_pending_data_source.find("StageClearResultSceneSpawnCallbackData.build_spawn_result_scene_callback") >= 0, "spawn screen pending data should build screen spawn callbacks")
	_expect(screen_pending_data_source.find("StageClearResultSceneSpawnConfigData.get_result_victory_character_type") >= 0, "spawn screen pending data should resolve result victory character type")
	_expect(handler_source.find("StageClearResultSceneSpawnScreenData.spawn_result_scene_from_screen") >= 0, "spawn flow handler should delegate screen spawn assembly")
	_expect(handler_source.find("StageClearResultSceneSpawnScreenData.start_show_scene_spawn_from_screen") >= 0, "spawn flow handler should delegate screen show-spawn assembly")
	_expect(handler_source.find("StageClearResultSceneSpawnScreenData.update_pending_scene_spawn_from_screen") >= 0, "spawn flow handler should delegate screen pending-spawn assembly")
	_expect(handler_source.find("screen.set(\"_scene_node\"") < 0, "spawn flow handler should not directly mutate the screen scene node")
	_expect(handler_source.find("_get_screen_object(screen, \"_pending_owner\")") < 0, "spawn flow handler should not directly assemble screen-backed runtime owner data")
	_expect(pending_data_source.find("static func start_show_scene_spawn") >= 0, "spawn pending data should own show-time spawn branching")
	_expect(pending_data_source.find("static func update_pending_scene_spawn") >= 0, "spawn pending data should own pending-spawn advancement")
	_expect(pending_data_source.find("StageClearResultSceneSpawnShellData.are_assets_ready_for_spawn") >= 0, "spawn pending data should check shell asset readiness")
	_expect(pending_data_source.find("prewarm_assets_step.call(owner, registry)") >= 0, "spawn pending data should advance staged prewarm callbacks")
	_expect(pending_data_source.find("spawn_result_scene.call(owner)") >= 0, "spawn pending data should call the result-scene spawn callback")
	_expect(pending_data_source.find("owner.queue_redraw()") >= 0, "spawn pending data should own pending redraw requests")
	_expect(handler_source.find("func start_show_scene_spawn_from_screen") >= 0, "spawn flow handler should own screen show-spawn adapters")
	_expect(handler_source.find("func update_pending_scene_spawn_from_screen") >= 0, "spawn flow handler should own screen pending-spawn adapters")
	_expect(handler_source.find("func start_show_scene_spawn") >= 0, "spawn flow handler should expose show-time scene spawn branching")
	_expect(handler_source.find("func update_pending_scene_spawn") >= 0, "spawn flow handler should expose pending-spawn branching")
	_expect(handler_source.find("StageClearResultSceneSpawnPendingData.start_show_scene_spawn") >= 0, "spawn flow handler should delegate show-time scene spawn branching")
	_expect(handler_source.find("StageClearResultSceneSpawnPendingData.update_pending_scene_spawn") >= 0, "spawn flow handler should delegate pending-spawn branching")
	_expect(handler_source.find("prewarm_assets_step.call(owner, registry)") < 0, "spawn flow handler should not directly advance pending prewarm callbacks")
	_expect(handler_source.find("spawn_result_scene.call(owner)") < 0, "spawn flow handler should not directly call pending spawn callbacks")
	_expect(handler_source.find("owner.queue_redraw()") < 0, "spawn flow handler should not directly own pending redraw requests")
	_expect(handler_source.find("func spawn_result_scene") >= 0, "spawn flow handler should expose result scene spawn orchestration")
	_expect(shell_data_source.find("static func prewarm_scene_shell") >= 0, "spawn shell data should own shell prewarm delegation")
	_expect(shell_data_source.find("static func prewarm_assets_step") >= 0, "spawn shell data should own staged asset prewarm delegation")
	_expect(shell_data_source.find("static func are_assets_ready_for_spawn") >= 0, "spawn shell data should own asset readiness delegation")
	_expect(shell_data_source.find("static func get_required_scene_asset_keys") >= 0, "spawn shell data should own required asset-key delegation")
	_expect(shell_data_source.find("static func get_prewarm_status") >= 0, "spawn shell data should own prewarm status copying")
	_expect(handler_source.find("StageClearResultSceneSpawnShellData.prewarm_scene_shell") >= 0, "spawn flow handler should delegate shell prewarm")
	_expect(handler_source.find("StageClearResultSceneSpawnShellData.prewarm_assets_step") >= 0, "spawn flow handler should delegate staged prewarm")
	_expect(handler_source.find("StageClearResultSceneSpawnShellData.are_assets_ready_for_spawn") >= 0, "spawn flow handler should delegate asset readiness")
	_expect(handler_source.find("StageClearResultSceneSpawnShellData.get_required_scene_asset_keys") >= 0, "spawn flow handler should delegate required asset keys")
	var screen := StageClearResultScreen.new()
	_expect(screen != null, "result screen should instantiate with the spawn flow handler")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
