extends SceneTree

const StageClearResultScreen := preload("res://scripts/core/stage_clear_result_screen.gd")
const StageClearResultUpdateFlowHandler := preload("res://scripts/core/stage_clear_result_update_flow_handler.gd")

var _failures: Array[String] = []


class FakeResultScene:
	extends Control

	var timer: float = 0.0
	var _boxes: Array = []
	var _lid_open_counter: int = 0
	var _hovered_box_index: int = -1
	var _scroll_phase: String = "hidden"
	var _scroll_timer: float = 0.0
	var _scroll_position_offset: Vector2 = Vector2.ZERO
	var _scroll_dragging: bool = false
	var _scroll_drag_grab_offset: Vector2 = Vector2.ZERO
	var _next_stage_button_rect: Rect2 = Rect2()
	var _plaza_button_rect: Rect2 = Rect2()
	var _exit_button_rect: Rect2 = Rect2()
	var _hovered_button: String = "none"
	var _reward_icon_cache: Dictionary = {}
	var _scene_field_name_lookup: Dictionary = {}
	var _dalji_base_timer: float = 0.0
	var _dalji_click_reaction_timer: float = 0.0
	var _player_victory_click_reaction_timer: float = 0.0
	var _stage2_boss_defeat_click_reaction_timer: float = 0.0
	var _stage3_boss_defeat_click_reaction_timer: float = 0.0
	var _stage4_ponk_boss_defeat_click_reaction_timer: float = 0.0
	var _stage5_hongryun_result_click_reaction_timer: float = 0.0
	var _stage6_boss_defeat_click_reaction_timer: float = 0.0
	var _stage7_boss_defeat_click_reaction_timer: float = 0.0
	var _dalji_dialogue_timer: float = 0.0
	var _runtime_perk_state: Object = null
	var _treasure_hunt_runtime: Object = null
	var _mythic_item_runtime: Object = null
	var _starpoint_choice_gate_active: bool = false
	var _starpoint_choice_gate_box_index: int = -1
	var _fx_host_pool: Object = null
	var immediate_reward_callback: Callable = Callable()


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var requested_keys: Array[String] = []

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		var instance: Variant = instances.get(key, null)
		return instance if instance is Object else null


class FakeRuntimeModule:
	extends RefCounted


class FakeOwner:
	extends RefCounted

	var selected_character_type: String = "smasher"


class FakeRuntimeContextHandler:
	extends RefCounted

	var calls: int = 0

	func get_selected_character_type(owner: Object) -> String:
		calls += 1
		if owner == null:
			return "smasher"
		return str(owner.get("selected_character_type"))


class FakePlazaSceneHandler:
	extends RefCounted

	var has_result_scene: bool = false
	var update_calls: int = 0
	var prewarm_calls: int = 0
	var prewarm_stage: int = 0

	func has_scene() -> bool:
		return has_result_scene

	func update(_delta: float) -> void:
		update_calls += 1

	func prewarm_assets_step(stage_id: int) -> bool:
		prewarm_calls += 1
		prewarm_stage = stage_id
		return true


class FakePrewarmFlowHandler:
	extends RefCounted

	var callback_calls: int = 0

	func build_prewarm_assets_step_callback_from_screen(_screen: Object) -> Callable:
		callback_calls += 1
		return Callable(self, "_step")

	func _step() -> bool:
		return true


class FakeSceneSpawnFlowHandler:
	extends RefCounted

	var update_calls: int = 0
	var next_spawn_pending: bool = false
	var seen_screen: Object
	var seen_prewarm_callback: Callable = Callable()
	var seen_delay: float = 0.0
	var seen_reset: Callable = Callable()

	func update_pending_scene_spawn_from_screen(
		screen: Object,
		prewarm_step_callback: Callable,
		starpoint_choice_reward_delay: float,
		reset: Callable
	) -> bool:
		update_calls += 1
		seen_screen = screen
		seen_prewarm_callback = prewarm_step_callback
		seen_delay = starpoint_choice_reward_delay
		seen_reset = reset
		return next_spawn_pending


class FakeMythicAcquisitionHandler:
	extends RefCounted

	var update_calls: int = 0
	var seen_runtime: Object

	func update_cinematic(_delta: float, mythic_item_runtime: Object, _owner: Object, _registry: Object) -> bool:
		update_calls += 1
		seen_runtime = mythic_item_runtime
		return true


class FakeStarpointChoiceHandler:
	extends RefCounted

	var runtime_update_calls: int = 0
	var pending_update_calls: int = 0
	var seen_runtime_state: Object
	var seen_catalog: Object
	var seen_audio: Object
	var seen_character_type: String = ""

	func update_runtime_choice(
		_delta: float,
		_scene: Control,
		runtime_perk_state: Object,
		_owner: Object,
		_registry: Object
	) -> void:
		runtime_update_calls += 1
		seen_runtime_state = runtime_perk_state

	func update_pending_choice(
		_delta: float,
		_scene: Control,
		runtime_perk_state: Object,
		runtime_perk_catalog: Object,
		selected_character_type: String,
		_owner: Object,
		_registry: Object,
		game_audio: Object
	) -> void:
		pending_update_calls += 1
		seen_runtime_state = runtime_perk_state
		seen_catalog = runtime_perk_catalog
		seen_character_type = selected_character_type
		seen_audio = game_audio


class FakeScreen:
	extends RefCounted

	var active: bool = true
	var current_stage: int = 1
	var _scene_node: Control
	var _spawn_pending: bool = false
	var _pending_owner: Object
	var _pending_registry: Object
	var _runtime_context_handler: Object
	var _prewarm_flow_handler: Object
	var _scene_spawn_flow_handler: Object
	var _plaza_scene_handler: Object
	var _mythic_acquisition_handler: Object
	var _starpoint_choice_handler: Object
	var reset_calls: int = 0

	func reset() -> void:
		reset_calls += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_update_flow_routes_runtime_work()
	_verify_screen_adapter_routes_runtime_work()
	_verify_screen_update_routes_plaza_scene_first()
	_verify_screen_update_finishes_pending_spawn_before_scene_update()
	_verify_null_scene_is_ignored()
	_verify_source_boundary()

	if _failures.is_empty():
		print("stage_clear_result_update_flow_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_update_flow_routes_runtime_work() -> void:
	var scene := FakeResultScene.new()
	scene.size = Vector2(760.0, 750.0)
	scene.visible = false
	root.add_child(scene)
	var registry := FakeRegistry.new()
	registry.instances["mythic_item_runtime"] = FakeRuntimeModule.new()
	registry.instances["runtime_perk_state"] = FakeRuntimeModule.new()
	registry.instances["runtime_perk_catalog"] = FakeRuntimeModule.new()
	registry.instances["game_audio"] = FakeRuntimeModule.new()
	var plaza := FakePlazaSceneHandler.new()
	var mythic := FakeMythicAcquisitionHandler.new()
	var starpoint := FakeStarpointChoiceHandler.new()

	StageClearResultUpdateFlowHandler.new().update_result_flow(
		0.25,
		scene,
		5,
		null,
		registry,
		"viper",
		plaza,
		mythic,
		starpoint
	)
	_expect(scene.visible, "update flow should sync result scene visibility first")
	_expect(scene.timer > 0.0, "update flow should tick the result scene")
	_expect(plaza.prewarm_calls == 1 and plaza.prewarm_stage == 5, "update flow should advance plaza background prewarm")
	_expect(mythic.update_calls == 1, "update flow should update mythic acquisition cinematic state")
	_expect(mythic.seen_runtime == registry.instances["mythic_item_runtime"], "update flow should pass mythic runtime from registry")
	_expect(starpoint.runtime_update_calls == 1, "update flow should update runtime perk choices")
	_expect(starpoint.pending_update_calls == 1, "update flow should update pending starpoint choices")
	_expect(starpoint.seen_runtime_state == registry.instances["runtime_perk_state"], "update flow should pass runtime perk state")
	_expect(starpoint.seen_catalog == registry.instances["runtime_perk_catalog"], "update flow should pass runtime perk catalog")
	_expect(starpoint.seen_audio == registry.instances["game_audio"], "update flow should pass game audio")
	_expect(starpoint.seen_character_type == "viper", "update flow should preserve selected character type")
	scene.queue_free()


func _verify_screen_adapter_routes_runtime_work() -> void:
	var scene := FakeResultScene.new()
	scene.size = Vector2(760.0, 750.0)
	scene.visible = false
	root.add_child(scene)
	var registry := FakeRegistry.new()
	registry.instances["mythic_item_runtime"] = FakeRuntimeModule.new()
	registry.instances["runtime_perk_state"] = FakeRuntimeModule.new()
	registry.instances["runtime_perk_catalog"] = FakeRuntimeModule.new()
	registry.instances["game_audio"] = FakeRuntimeModule.new()
	var owner := FakeOwner.new()
	owner.selected_character_type = "soldier"
	var runtime_context := FakeRuntimeContextHandler.new()
	var plaza := FakePlazaSceneHandler.new()
	var mythic := FakeMythicAcquisitionHandler.new()
	var starpoint := FakeStarpointChoiceHandler.new()
	var screen := FakeScreen.new()
	screen.current_stage = 6
	screen._scene_node = scene
	screen._pending_owner = owner
	screen._pending_registry = registry
	screen._runtime_context_handler = runtime_context
	screen._plaza_scene_handler = plaza
	screen._mythic_acquisition_handler = mythic
	screen._starpoint_choice_handler = starpoint

	StageClearResultUpdateFlowHandler.new().update_result_flow_from_screen(screen, 0.2)
	_expect(scene.visible, "screen update adapter should sync result scene visibility")
	_expect(scene.timer > 0.0, "screen update adapter should tick the result scene")
	_expect(plaza.prewarm_calls == 1 and plaza.prewarm_stage == 6, "screen update adapter should pass current stage to plaza prewarm")
	_expect(mythic.update_calls == 1, "screen update adapter should update mythic cinematic state")
	_expect(starpoint.pending_update_calls == 1, "screen update adapter should update pending starpoint choices")
	_expect(runtime_context.calls == 1, "screen update adapter should resolve selected character through runtime context")
	_expect(starpoint.seen_character_type == "soldier", "screen update adapter should pass selected character type")
	scene.queue_free()


func _verify_screen_update_routes_plaza_scene_first() -> void:
	var scene := FakeResultScene.new()
	scene.size = Vector2(760.0, 750.0)
	scene.visible = false
	root.add_child(scene)
	var plaza := FakePlazaSceneHandler.new()
	plaza.has_result_scene = true
	var screen := FakeScreen.new()
	screen._scene_node = scene
	screen._plaza_scene_handler = plaza

	StageClearResultUpdateFlowHandler.new().update_screen_flow_from_screen(screen, 0.2, 0.65)
	_expect(plaza.update_calls == 1, "screen update flow should route active plaza scenes before result scene work")
	_expect(scene.timer == 0.0, "screen update flow should not tick the result scene while plaza scene is active")
	scene.queue_free()


func _verify_screen_update_finishes_pending_spawn_before_scene_update() -> void:
	var scene := FakeResultScene.new()
	scene.size = Vector2(760.0, 750.0)
	scene.visible = false
	root.add_child(scene)
	var registry := FakeRegistry.new()
	registry.instances["mythic_item_runtime"] = FakeRuntimeModule.new()
	registry.instances["runtime_perk_state"] = FakeRuntimeModule.new()
	registry.instances["runtime_perk_catalog"] = FakeRuntimeModule.new()
	registry.instances["game_audio"] = FakeRuntimeModule.new()
	var owner := FakeOwner.new()
	owner.selected_character_type = "serabi"
	var runtime_context := FakeRuntimeContextHandler.new()
	var prewarm := FakePrewarmFlowHandler.new()
	var scene_spawn := FakeSceneSpawnFlowHandler.new()
	var plaza := FakePlazaSceneHandler.new()
	var mythic := FakeMythicAcquisitionHandler.new()
	var starpoint := FakeStarpointChoiceHandler.new()
	var screen := FakeScreen.new()
	screen.current_stage = 5
	screen._scene_node = scene
	screen._spawn_pending = true
	screen._pending_owner = owner
	screen._pending_registry = registry
	screen._runtime_context_handler = runtime_context
	screen._prewarm_flow_handler = prewarm
	screen._scene_spawn_flow_handler = scene_spawn
	screen._plaza_scene_handler = plaza
	screen._mythic_acquisition_handler = mythic
	screen._starpoint_choice_handler = starpoint

	StageClearResultUpdateFlowHandler.new().update_screen_flow_from_screen(screen, 0.2, 0.65)
	_expect(not screen._spawn_pending, "screen update flow should store the next pending-spawn state")
	_expect(scene_spawn.update_calls == 1 and scene_spawn.seen_screen == screen, "screen update flow should advance pending scene spawn")
	_expect(scene_spawn.seen_prewarm_callback.is_valid(), "screen update flow should pass a prewarm-step callback to scene spawn")
	_expect(is_equal_approx(scene_spawn.seen_delay, 0.65), "screen update flow should pass starpoint reward delay to scene spawn")
	_expect(scene_spawn.seen_reset.is_valid(), "screen update flow should pass the screen reset callback to scene spawn")
	_expect(prewarm.callback_calls == 1, "screen update flow should build the prewarm-step callback from the screen")
	_expect(scene.visible and scene.timer > 0.0, "screen update flow should tick the result scene after pending spawn resolves")
	_expect(mythic.update_calls == 1, "screen update flow should continue into mythic cinematic updates")
	_expect(starpoint.seen_character_type == "serabi", "screen update flow should preserve selected character after spawn resolves")
	scene_spawn.seen_screen = null
	scene_spawn.seen_prewarm_callback = Callable()
	scene_spawn.seen_reset = Callable()
	screen._scene_spawn_flow_handler = null
	screen._prewarm_flow_handler = null
	screen._plaza_scene_handler = null
	screen._mythic_acquisition_handler = null
	screen._starpoint_choice_handler = null
	scene.queue_free()


func _verify_null_scene_is_ignored() -> void:
	var plaza := FakePlazaSceneHandler.new()
	var mythic := FakeMythicAcquisitionHandler.new()
	var starpoint := FakeStarpointChoiceHandler.new()
	StageClearResultUpdateFlowHandler.new().update_result_flow(
		0.25,
		null,
		1,
		null,
		null,
		"smasher",
		plaza,
		mythic,
		starpoint
	)
	_expect(plaza.prewarm_calls == 0, "missing result scenes should not advance plaza prewarm")
	_expect(mythic.update_calls == 0, "missing result scenes should not update mythic cinematics")
	_expect(starpoint.runtime_update_calls == 0, "missing result scenes should not update runtime choices")
	_expect(starpoint.pending_update_calls == 0, "missing result scenes should not update pending choices")


func _verify_source_boundary() -> void:
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var registry_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_handler_registry.gd")
	var handler_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_update_flow_handler.gd")
	var screen_context_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_update_screen_context_data.gd")
	_expect(registry_source.find("StageClearResultUpdateFlowHandler.new()") >= 0, "handler registry should delegate result update flow")
	_expect(screen_source.find("StageClearResultUpdateSceneHandler") < 0, "result screen should not call result scene update glue directly")
	_expect(screen_source.find("update_pending_choice(") < 0, "result screen should not drive pending starpoint choice update directly")
	_expect(screen_source.find("_sync_result_scene_visibility") < 0, "result screen should not keep result scene visibility wrappers")
	_expect(screen_source.find("get_selected_character_type(_pending_owner)") < 0, "result screen should not assemble update selected-character context directly")
	_expect(screen_source.find("update_result_flow(") < 0, "result screen should not pass update-flow dependencies directly")
	_expect(screen_source.find("update_pending_scene_spawn_from_screen") < 0, "result screen should not update pending result-scene spawns directly")
	_expect(screen_source.find("_plaza_scene_handler.update(delta)") < 0, "result screen should not update plaza result scenes directly")
	_expect(handler_source.find("func update_screen_flow_from_screen") >= 0, "update flow handler should own screen-level update routing")
	_expect(handler_source.find("StageClearResultUpdateSceneHandler.update_result_scene") >= 0, "update flow handler should own result scene update glue")
	_expect(handler_source.find("StageClearResultUpdateScreenContextData.update_pending_scene_spawn_from_screen") >= 0, "update flow handler should delegate pending result-scene spawn screen context")
	_expect(handler_source.find("StageClearResultUpdateScreenContextData.build_result_flow_context") >= 0, "update flow handler should delegate screen update-flow context assembly")
	_expect(handler_source.find("func _update_pending_scene_spawn_from_screen") < 0, "update flow handler should not keep pending spawn screen adapters")
	_expect(handler_source.find("func _build_prewarm_assets_step_callback_from_screen") < 0, "update flow handler should not keep prewarm callback screen adapters")
	_expect(handler_source.find("func _get_selected_character_type") < 0, "update flow handler should not keep selected-character screen context reads")
	_expect(handler_source.find("func _get_screen_object") < 0, "update flow handler should not keep screen object readers")
	_expect(screen_context_source.find("static func update_pending_scene_spawn_from_screen") >= 0, "update screen context data should own pending spawn screen adapters")
	_expect(screen_context_source.find("static func build_result_flow_context") >= 0, "update screen context data should own screen update-flow context assembly")
	_expect(screen_context_source.find("build_prewarm_assets_step_callback_from_screen") >= 0, "update screen context data should wire prewarm callbacks for pending spawn")
	_expect(screen_context_source.find("get_selected_character_type") >= 0, "update screen context data should resolve selected-character context")
	_expect(handler_source.find("update_pending_choice(") >= 0, "update flow handler should own pending starpoint update glue")
	_expect(handler_source.find("func update_result_flow_from_screen") >= 0, "update flow handler should own screen update-flow adapters")
	var screen := StageClearResultScreen.new()
	_expect(screen != null, "result screen should still instantiate with the update flow handler")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
