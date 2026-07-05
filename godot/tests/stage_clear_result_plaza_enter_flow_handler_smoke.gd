extends SceneTree

const StageClearResultPlazaEnterFlowHandler := preload("res://scripts/core/stage_clear_result_plaza_enter_flow_handler.gd")
const StageClearResultScreen := preload("res://scripts/core/stage_clear_result_screen.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraw_calls: int = 0

	func queue_redraw() -> void:
		redraw_calls += 1


class FakeScene:
	extends Control


class FakePlazaSaveStore:
	extends RefCounted


class FakeRegistry:
	extends RefCounted


class FakeRuntimeContextHandler:
	extends RefCounted

	var selected_character_type: String = "blacksmith"
	var seen_owner: Object

	func get_selected_character_type(owner: Object) -> String:
		seen_owner = owner
		return selected_character_type


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

	var mark_spawn_calls: int = 0
	var seen_screen: Object

	func mark_spawn_not_pending(screen: Object) -> void:
		mark_spawn_calls += 1
		seen_screen = screen
		if screen != null:
			screen.set("_spawn_pending", false)


class FakePlazaSceneHandler:
	extends RefCounted

	var assets_ready: bool = true
	var spawn_result: bool = true
	var ensure_calls: int = 0
	var build_calls: int = 0
	var spawn_calls: int = 0
	var seen_stage: int = 0
	var seen_config: Dictionary = {}
	var seen_finish_callback: Callable = Callable()

	func ensure_assets_ready(stage_id: int) -> bool:
		ensure_calls += 1
		seen_stage = stage_id
		return assets_ready

	func build_scene_config(
		current_stage: int,
		plaza_save_store: Object,
		owner: Object,
		registry: Object,
		selected_character_type: String,
		play_arrival_transition: bool = true
	) -> Dictionary:
		build_calls += 1
		return {
			"current_stage": current_stage,
			"plaza_save_store": plaza_save_store,
			"runtime_owner": owner,
			"runtime_registry": registry,
			"selected_character_type": selected_character_type,
			"play_arrival_transition": play_arrival_transition,
		}

	func spawn_scene(_owner: Object, config: Dictionary, finish_callback: Callable) -> bool:
		spawn_calls += 1
		seen_config = config.duplicate(true)
		seen_finish_callback = finish_callback
		return spawn_result


class FakeStarpointChoiceHandler:
	extends RefCounted

	var reset_calls: int = 0
	var seen_scene: Control

	func reset(scene: Control = null) -> void:
		reset_calls += 1
		seen_scene = scene


class FlowSink:
	extends RefCounted

	var grant_calls: int = 0
	var apply_calls: int = 0
	var applied_grant_ap: Array = []
	var mark_spawn_calls: int = 0
	var free_result_calls: int = 0
	var finish_continue_calls: int = 0

	func grant_pending_rewards() -> Dictionary:
		grant_calls += 1
		return {"granted": 1}

	func apply_stage_clear_progress(grant_ap: bool) -> Dictionary:
		apply_calls += 1
		applied_grant_ap.append(grant_ap)
		return {"granted_ap": 1 if grant_ap else 0}

	func mark_spawn_not_pending() -> void:
		mark_spawn_calls += 1

	func free_result_scene() -> void:
		free_result_calls += 1

	func finish_plaza_and_continue() -> void:
		finish_continue_calls += 1


class FakeScreen:
	extends RefCounted

	var active: bool = true
	var current_stage: int = 1
	var _spawn_pending: bool = false
	var _pending_owner: Object
	var _pending_registry: Object
	var _scene_node: Control
	var _plaza_save_store: Object
	var _runtime_context_handler: Object
	var _plaza_scene_handler: Object
	var _starpoint_choice_handler: Object
	var _reward_grant_handler: Object
	var _plaza_progress_handler: Object
	var _screen_state_handler: Object


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_inactive_flow_is_ignored()
	_verify_successful_plaza_entry_flow()
	_verify_asset_failure_falls_back_to_continue()
	_verify_spawn_failure_falls_back_to_continue()
	_verify_missing_plaza_handler_falls_back_to_continue()
	_verify_screen_plaza_entry_adapter()
	_verify_source_boundary()

	if _failures.is_empty():
		print("stage_clear_result_plaza_enter_flow_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_inactive_flow_is_ignored() -> void:
	var sink := FlowSink.new()
	var plaza := FakePlazaSceneHandler.new()
	StageClearResultPlazaEnterFlowHandler.new().finish_enter_plaza(
		false,
		5,
		FakePlazaSaveStore.new(),
		FakeOwner.new(),
		FakeRegistry.new(),
		"viper",
		null,
		plaza,
		FakeStarpointChoiceHandler.new(),
		Callable(sink, "grant_pending_rewards"),
		Callable(sink, "apply_stage_clear_progress"),
		Callable(sink, "mark_spawn_not_pending"),
		Callable(sink, "free_result_scene"),
		Callable(sink, "finish_plaza_and_continue")
	)
	_expect(sink.grant_calls == 0, "inactive plaza entry should not grant pending rewards")
	_expect(plaza.ensure_calls == 0, "inactive plaza entry should not prewarm plaza assets")


func _verify_successful_plaza_entry_flow() -> void:
	var sink := FlowSink.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var save_store := FakePlazaSaveStore.new()
	var scene := FakeScene.new()
	var plaza := FakePlazaSceneHandler.new()
	var starpoint := FakeStarpointChoiceHandler.new()
	StageClearResultPlazaEnterFlowHandler.new().finish_enter_plaza(
		true,
		5,
		save_store,
		owner,
		registry,
		"viper",
		scene,
		plaza,
		starpoint,
		Callable(sink, "grant_pending_rewards"),
		Callable(sink, "apply_stage_clear_progress"),
		Callable(sink, "mark_spawn_not_pending"),
		Callable(sink, "free_result_scene"),
		Callable(sink, "finish_plaza_and_continue")
	)
	_expect(sink.grant_calls == 1, "successful plaza entry should grant pending rewards")
	_expect(sink.apply_calls == 1 and bool(sink.applied_grant_ap[0]), "successful plaza entry should apply stage progress with AP")
	_expect(starpoint.reset_calls == 1 and starpoint.seen_scene == scene, "successful plaza entry should reset starpoint choice state for the result scene")
	_expect(sink.mark_spawn_calls == 1, "successful plaza entry should clear pending spawn state")
	_expect(sink.free_result_calls == 1, "successful plaza entry should free the result scene before spawning plaza")
	_expect(plaza.ensure_calls == 1 and plaza.seen_stage == 5, "successful plaza entry should blocking-prewarm the plaza stage")
	_expect(plaza.build_calls == 1, "successful plaza entry should build plaza scene config")
	_expect(plaza.spawn_calls == 1, "successful plaza entry should spawn the plaza scene")
	_expect(plaza.seen_config.get("runtime_owner", null) == owner, "plaza entry config should preserve owner")
	_expect(plaza.seen_config.get("runtime_registry", null) == registry, "plaza entry config should preserve registry")
	_expect(str(plaza.seen_config.get("selected_character_type", "")) == "viper", "plaza entry config should preserve selected character")
	_expect(bool(plaza.seen_config.get("play_arrival_transition", false)), "plaza entry config should request the arrival transition")
	_expect(plaza.seen_finish_callback.is_valid(), "plaza entry should pass the plaza continuation callback to spawn")
	_expect(sink.finish_continue_calls == 0, "successful plaza entry should not immediately continue")
	_expect(owner.redraw_calls == 1, "successful plaza entry should request a redraw on the owner")
	scene.free()


func _verify_asset_failure_falls_back_to_continue() -> void:
	var sink := FlowSink.new()
	var plaza := FakePlazaSceneHandler.new()
	plaza.assets_ready = false
	StageClearResultPlazaEnterFlowHandler.new().finish_enter_plaza(
		true,
		6,
		FakePlazaSaveStore.new(),
		FakeOwner.new(),
		FakeRegistry.new(),
		"smasher",
		null,
		plaza,
		FakeStarpointChoiceHandler.new(),
		Callable(sink, "grant_pending_rewards"),
		Callable(sink, "apply_stage_clear_progress"),
		Callable(sink, "mark_spawn_not_pending"),
		Callable(sink, "free_result_scene"),
		Callable(sink, "finish_plaza_and_continue")
	)
	_expect(sink.grant_calls == 1 and sink.apply_calls == 1, "asset failure should still settle rewards and stage progress")
	_expect(sink.mark_spawn_calls == 1 and sink.free_result_calls == 1, "asset failure should still leave the result scene path")
	_expect(plaza.ensure_calls == 1, "asset failure should attempt plaza asset readiness")
	_expect(plaza.spawn_calls == 0, "asset failure should not spawn plaza scene")
	_expect(sink.finish_continue_calls == 1, "asset failure should fall back to plaza continuation")


func _verify_spawn_failure_falls_back_to_continue() -> void:
	var sink := FlowSink.new()
	var plaza := FakePlazaSceneHandler.new()
	plaza.spawn_result = false
	StageClearResultPlazaEnterFlowHandler.new().finish_enter_plaza(
		true,
		2,
		FakePlazaSaveStore.new(),
		FakeOwner.new(),
		FakeRegistry.new(),
		"commando",
		null,
		plaza,
		FakeStarpointChoiceHandler.new(),
		Callable(sink, "grant_pending_rewards"),
		Callable(sink, "apply_stage_clear_progress"),
		Callable(sink, "mark_spawn_not_pending"),
		Callable(sink, "free_result_scene"),
		Callable(sink, "finish_plaza_and_continue")
	)
	_expect(plaza.ensure_calls == 1 and plaza.spawn_calls == 1, "spawn failure should happen after plaza assets are ready")
	_expect(sink.finish_continue_calls == 1, "spawn failure should fall back to plaza continuation")


func _verify_missing_plaza_handler_falls_back_to_continue() -> void:
	var sink := FlowSink.new()
	StageClearResultPlazaEnterFlowHandler.new().finish_enter_plaza(
		true,
		1,
		FakePlazaSaveStore.new(),
		FakeOwner.new(),
		FakeRegistry.new(),
		"smasher",
		null,
		null,
		FakeStarpointChoiceHandler.new(),
		Callable(sink, "grant_pending_rewards"),
		Callable(sink, "apply_stage_clear_progress"),
		Callable(sink, "mark_spawn_not_pending"),
		Callable(sink, "free_result_scene"),
		Callable(sink, "finish_plaza_and_continue")
	)
	_expect(sink.grant_calls == 1 and sink.apply_calls == 1, "missing plaza handler should still settle rewards and stage progress")
	_expect(sink.finish_continue_calls == 1, "missing plaza handler should fall back to plaza continuation")


func _verify_screen_plaza_entry_adapter() -> void:
	var sink := FlowSink.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var save_store := FakePlazaSaveStore.new()
	var scene := FakeScene.new()
	var runtime_context := FakeRuntimeContextHandler.new()
	var plaza := FakePlazaSceneHandler.new()
	var starpoint := FakeStarpointChoiceHandler.new()
	var reward_grant := FakeRewardGrantHandler.new()
	var plaza_progress := FakePlazaProgressHandler.new()
	var screen_state := FakeScreenStateHandler.new()
	var screen := FakeScreen.new()
	screen.active = true
	screen.current_stage = 6
	screen._spawn_pending = true
	screen._pending_owner = owner
	screen._pending_registry = registry
	screen._scene_node = scene
	screen._plaza_save_store = save_store
	screen._runtime_context_handler = runtime_context
	screen._plaza_scene_handler = plaza
	screen._starpoint_choice_handler = starpoint
	screen._reward_grant_handler = reward_grant
	screen._plaza_progress_handler = plaza_progress
	screen._screen_state_handler = screen_state

	StageClearResultPlazaEnterFlowHandler.new().finish_enter_plaza_from_screen(
		screen,
		Callable(sink, "free_result_scene"),
		Callable(sink, "finish_plaza_and_continue")
	)
	_expect(reward_grant.grant_calls == 1, "screen plaza adapter should grant pending rewards")
	_expect(reward_grant.seen_scene == scene and reward_grant.seen_owner == owner and reward_grant.seen_registry == registry, "screen plaza adapter should bind scene owner and registry into reward grants")
	_expect(plaza_progress.apply_calls == 1 and plaza_progress.seen_grant_ap, "screen plaza adapter should apply stage progress with AP")
	_expect(plaza_progress.seen_owner == owner and plaza_progress.seen_save_store == save_store and plaza_progress.seen_stage == 6, "screen plaza adapter should bind owner save store and stage into progress grants")
	_expect(starpoint.reset_calls == 1 and starpoint.seen_scene == scene, "screen plaza adapter should reset starpoint choice state")
	_expect(screen_state.mark_spawn_calls == 1 and screen_state.seen_screen == screen and not screen._spawn_pending, "screen plaza adapter should delegate pending-spawn mutation")
	_expect(sink.free_result_calls == 1, "screen plaza adapter should free the result scene")
	_expect(plaza.ensure_calls == 1 and plaza.seen_stage == 6, "screen plaza adapter should ensure plaza assets for the current stage")
	_expect(plaza.spawn_calls == 1, "screen plaza adapter should spawn the plaza scene")
	_expect(plaza.seen_config.get("runtime_owner", null) == owner, "screen plaza adapter should preserve owner in plaza config")
	_expect(plaza.seen_config.get("runtime_registry", null) == registry, "screen plaza adapter should preserve registry in plaza config")
	_expect(str(plaza.seen_config.get("selected_character_type", "")) == "blacksmith", "screen plaza adapter should use runtime context selected character")
	_expect(owner.redraw_calls == 1, "screen plaza adapter should request a redraw after spawning plaza")
	screen._pending_owner = null
	screen._pending_registry = null
	screen._scene_node = null
	screen._plaza_save_store = null
	screen._runtime_context_handler = null
	screen._plaza_scene_handler = null
	screen._starpoint_choice_handler = null
	screen._reward_grant_handler = null
	screen._plaza_progress_handler = null
	screen._screen_state_handler = null
	reward_grant.seen_scene = null
	reward_grant.seen_owner = null
	reward_grant.seen_registry = null
	plaza_progress.seen_owner = null
	plaza_progress.seen_save_store = null
	runtime_context.seen_owner = null
	screen_state.seen_screen = null
	scene.free()


func _verify_source_boundary() -> void:
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var registry_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_handler_registry.gd")
	var handler_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_plaza_enter_flow_handler.gd")
	var screen_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_plaza_enter_screen_data.gd")
	var callback_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_scene_spawn_callback_data.gd")
	var screen_spawn_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_scene_spawn_screen_data.gd")
	_expect(registry_source.find("StageClearResultPlazaEnterFlowHandler.new()") >= 0, "handler registry should delegate plaza entry flow")
	_expect(screen_source.find("_plaza_scene_handler.ensure_assets_ready") < 0, "result screen should not own plaza entry asset readiness")
	_expect(screen_source.find("_plaza_scene_handler.build_scene_config") < 0, "result screen should not own plaza entry config assembly")
	_expect(screen_source.find("_plaza_scene_handler.spawn_scene") < 0, "result screen should not own plaza entry scene spawn")
	_expect(screen_source.find("finish_enter_plaza_from_screen") < 0, "result screen should not wire plaza-entry screen adapters directly")
	_expect(screen_source.find("func _finish_enter_plaza") < 0, "result screen should not keep plaza-entry callback wrappers")
	_expect(screen_source.find("grant_pending_scene_rewards") < 0, "result screen should not wire plaza-entry reward callbacks directly")
	_expect(screen_source.find("apply_stage_clear_progress_from_callback") < 0, "result screen should not wire plaza-entry progress callbacks directly")
	_expect(handler_source.find("func finish_enter_plaza") >= 0, "plaza enter flow handler should own plaza entry flow")
	_expect(handler_source.find("func finish_enter_plaza_from_screen") >= 0, "plaza enter flow handler should expose screen plaza-entry adapters")
	_expect(handler_source.find("StageClearResultPlazaEnterScreenData.build_plaza_enter_context_from_screen") >= 0, "plaza enter flow handler should delegate screen plaza-entry context assembly")
	_expect(handler_source.find("func _build_grant_pending_rewards_callback") < 0, "plaza enter flow handler should not keep reward callback screen wiring")
	_expect(handler_source.find("func _build_apply_stage_clear_progress_callback") < 0, "plaza enter flow handler should not keep progress callback screen wiring")
	_expect(handler_source.find("func _get_screen_object") < 0, "plaza enter flow handler should not keep screen object readers")
	_expect(screen_data_source.find("static func build_plaza_enter_context_from_screen") >= 0, "plaza enter screen data should own screen plaza-entry context assembly")
	_expect(screen_data_source.find("grant_pending_scene_rewards") >= 0, "plaza enter screen data should wire pending reward grants")
	_expect(screen_data_source.find("apply_stage_clear_progress_from_callback") >= 0, "plaza enter screen data should wire plaza progress grants")
	_expect(screen_data_source.find("mark_spawn_not_pending") >= 0, "plaza enter screen data should wire pending-spawn mutation")
	_expect(callback_source.find("finish_enter_plaza_from_screen") >= 0, "spawn callback data should wire result-scene plaza callbacks to the plaza adapter")
	_expect(screen_spawn_source.find("StageClearResultSceneSpawnCallbackData.build_enter_plaza_callback") >= 0, "spawn screen data should build plaza callbacks through callback data")
	_expect(handler_source.find("ensure_assets_ready") >= 0, "plaza enter flow handler should own plaza asset readiness timing")
	_expect(handler_source.find("build_scene_config") >= 0, "plaza enter flow handler should own plaza config timing")
	_expect(handler_source.find("spawn_scene") >= 0, "plaza enter flow handler should own plaza spawn timing")
	var screen := StageClearResultScreen.new()
	_expect(screen != null, "result screen should instantiate with the plaza enter flow handler")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
