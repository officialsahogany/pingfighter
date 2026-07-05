extends SceneTree

const StageClearResultInputFlowHandler := preload("res://scripts/core/stage_clear_result_input_flow_handler.gd")
const StageClearResultScreen := preload("res://scripts/core/stage_clear_result_screen.gd")

var _failures: Array[String] = []


class FakeResultScene:
	extends Control

	var _scroll_dragging: bool = false
	var _scroll_phase: String = "hidden"
	var _runtime_perk_state: Object = null
	var _mythic_item_runtime: Object = null
	var _treasure_hunt_runtime: Object = null


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


class FakePlazaSceneHandler:
	extends RefCounted

	var scene_active: bool = false
	var input_calls: int = 0

	func has_scene() -> bool:
		return scene_active

	func handle_input(_event: InputEvent) -> void:
		input_calls += 1


class FakeMythicAcquisitionHandler:
	extends RefCounted

	var consume_input: bool = false
	var input_calls: int = 0
	var seen_runtime: Object

	func handle_input(
		_event: InputEvent,
		mythic_item_runtime: Object,
		_owner: Object,
		_registry: Object,
		_scene: Control
	) -> bool:
		input_calls += 1
		seen_runtime = mythic_item_runtime
		return consume_input


class FakeStarpointChoiceHandler:
	extends RefCounted

	var sync_calls: int = 0
	var seen_runtime_state: Object

	func sync_box_perk_choice_rewards(_scene: Control, runtime_perk_state: Object) -> void:
		sync_calls += 1
		seen_runtime_state = runtime_perk_state


class FakeScreen:
	extends RefCounted

	var active: bool = true
	var _spawn_pending: bool = false
	var _scene_node: Control
	var _pending_owner: Object
	var _pending_registry: Object
	var _plaza_scene_handler: Object
	var _mythic_acquisition_handler: Object
	var _starpoint_choice_handler: Object

	func is_active() -> bool:
		return active

	func _has_result_scene() -> bool:
		return _scene_node != null and is_instance_valid(_scene_node)


class BoolSequence:
	extends RefCounted

	var values: Array = []
	var calls: int = 0

	func _init(new_values: Array) -> void:
		values = new_values.duplicate()

	func value() -> bool:
		if values.is_empty():
			calls += 1
			return false
		var index: int = mini(calls, values.size() - 1)
		calls += 1
		return bool(values[index])


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_inactive_input_is_ignored()
	_verify_plaza_input_takes_priority()
	_verify_spawn_pending_consumes_without_scene_routing()
	_verify_mythic_input_takes_priority()
	_verify_result_input_syncs_starpoint_choice_rewards()
	_verify_screen_adapter_routes_input_context()
	_verify_post_input_inactive_skips_starpoint_sync()
	_verify_post_input_missing_scene_skips_starpoint_sync()
	_verify_source_boundary()

	if _failures.is_empty():
		print("stage_clear_result_input_flow_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_inactive_input_is_ignored() -> void:
	var plaza := FakePlazaSceneHandler.new()
	plaza.scene_active = true
	var active := BoolSequence.new([false])
	var has_scene := BoolSequence.new([false])
	var handled: bool = StageClearResultInputFlowHandler.new().handle_input(
		_joy_consume_event(),
		false,
		null,
		null,
		null,
		plaza,
		FakeMythicAcquisitionHandler.new(),
		FakeStarpointChoiceHandler.new(),
		1.0,
		Callable(active, "value"),
		Callable(has_scene, "value")
	)
	_expect(not handled, "inactive result input should not be consumed")
	_expect(plaza.input_calls == 0, "inactive input should not reach plaza routing")


func _verify_plaza_input_takes_priority() -> void:
	var plaza := FakePlazaSceneHandler.new()
	plaza.scene_active = true
	var mythic := FakeMythicAcquisitionHandler.new()
	var starpoint := FakeStarpointChoiceHandler.new()
	var active := BoolSequence.new([true])
	var has_scene := BoolSequence.new([false])
	var handled: bool = StageClearResultInputFlowHandler.new().handle_input(
		_joy_consume_event(),
		false,
		null,
		null,
		null,
		plaza,
		mythic,
		starpoint,
		1.0,
		Callable(active, "value"),
		Callable(has_scene, "value")
	)
	_expect(handled, "plaza result input should be consumed")
	_expect(plaza.input_calls == 1, "plaza input should be routed to the plaza scene handler")
	_expect(mythic.input_calls == 0, "plaza input should not reach mythic routing")
	_expect(starpoint.sync_calls == 0, "plaza input should not sync starpoint choices")


func _verify_spawn_pending_consumes_without_scene_routing() -> void:
	var plaza := FakePlazaSceneHandler.new()
	var mythic := FakeMythicAcquisitionHandler.new()
	var starpoint := FakeStarpointChoiceHandler.new()
	var active := BoolSequence.new([true])
	var has_scene := BoolSequence.new([false])
	var handled: bool = StageClearResultInputFlowHandler.new().handle_input(
		_joy_consume_event(),
		true,
		null,
		null,
		null,
		plaza,
		mythic,
		starpoint,
		1.0,
		Callable(active, "value"),
		Callable(has_scene, "value")
	)
	_expect(handled, "pending scene spawn input should be consumed")
	_expect(has_scene.calls == 0, "spawn-pending input should not require a result scene check")
	_expect(mythic.input_calls == 0, "spawn-pending input should not reach mythic routing")
	_expect(starpoint.sync_calls == 0, "spawn-pending input should not sync starpoint choices")


func _verify_mythic_input_takes_priority() -> void:
	var scene := FakeResultScene.new()
	root.add_child(scene)
	var registry := FakeRegistry.new()
	registry.instances["mythic_item_runtime"] = FakeRuntimeModule.new()
	var mythic := FakeMythicAcquisitionHandler.new()
	mythic.consume_input = true
	var starpoint := FakeStarpointChoiceHandler.new()
	var active := BoolSequence.new([true])
	var has_scene := BoolSequence.new([true])
	var handled: bool = StageClearResultInputFlowHandler.new().handle_input(
		_joy_consume_event(),
		false,
		scene,
		null,
		registry,
		FakePlazaSceneHandler.new(),
		mythic,
		starpoint,
		1.0,
		Callable(active, "value"),
		Callable(has_scene, "value")
	)
	_expect(handled, "mythic acquisition input should be consumed")
	_expect(mythic.input_calls == 1, "mythic acquisition should receive input before result scene routing")
	_expect(mythic.seen_runtime == registry.instances["mythic_item_runtime"], "mythic routing should use the registry runtime")
	_expect(starpoint.sync_calls == 0, "consumed mythic input should not sync starpoint choices")
	scene.queue_free()


func _verify_result_input_syncs_starpoint_choice_rewards() -> void:
	var scene := FakeResultScene.new()
	root.add_child(scene)
	var registry := FakeRegistry.new()
	registry.instances["runtime_perk_state"] = FakeRuntimeModule.new()
	var mythic := FakeMythicAcquisitionHandler.new()
	var starpoint := FakeStarpointChoiceHandler.new()
	var active := BoolSequence.new([true, true])
	var has_scene := BoolSequence.new([true, true])
	var handled: bool = StageClearResultInputFlowHandler.new().handle_input(
		_joy_consume_event(),
		false,
		scene,
		null,
		registry,
		FakePlazaSceneHandler.new(),
		mythic,
		starpoint,
		1.0,
		Callable(active, "value"),
		Callable(has_scene, "value")
	)
	_expect(handled, "result scene input should be consumed")
	_expect(mythic.input_calls == 1, "result input should still check mythic acquisition before normal routing")
	_expect(starpoint.sync_calls == 1, "result input should sync selected starpoint choices after scene routing")
	_expect(starpoint.seen_runtime_state == registry.instances["runtime_perk_state"], "starpoint sync should use the registry runtime state")
	scene.queue_free()


func _verify_screen_adapter_routes_input_context() -> void:
	var scene := FakeResultScene.new()
	root.add_child(scene)
	var registry := FakeRegistry.new()
	registry.instances["runtime_perk_state"] = FakeRuntimeModule.new()
	registry.instances["mythic_item_runtime"] = FakeRuntimeModule.new()
	var mythic := FakeMythicAcquisitionHandler.new()
	var starpoint := FakeStarpointChoiceHandler.new()
	var screen := FakeScreen.new()
	screen._scene_node = scene
	screen._pending_registry = registry
	screen._plaza_scene_handler = FakePlazaSceneHandler.new()
	screen._mythic_acquisition_handler = mythic
	screen._starpoint_choice_handler = starpoint

	var handled: bool = StageClearResultInputFlowHandler.new().handle_input_from_screen(
		screen,
		_joy_consume_event()
	)
	_expect(handled, "screen input adapter should consume active result scene input")
	_expect(mythic.input_calls == 1, "screen input adapter should route mythic input from screen state")
	_expect(mythic.seen_runtime == registry.instances["mythic_item_runtime"], "screen input adapter should pass mythic runtime from registry")
	_expect(starpoint.sync_calls == 1, "screen input adapter should sync starpoint choices after scene routing")
	_expect(starpoint.seen_runtime_state == registry.instances["runtime_perk_state"], "screen input adapter should pass runtime perk state")
	scene.queue_free()

	screen = FakeScreen.new()
	screen.active = false
	handled = StageClearResultInputFlowHandler.new().handle_input_from_screen(
		screen,
		_joy_consume_event()
	)
	_expect(not handled, "screen input adapter should preserve inactive-screen behavior")


func _verify_post_input_inactive_skips_starpoint_sync() -> void:
	var scene := FakeResultScene.new()
	root.add_child(scene)
	var starpoint := FakeStarpointChoiceHandler.new()
	var active := BoolSequence.new([true, false])
	var has_scene := BoolSequence.new([true])
	StageClearResultInputFlowHandler.new().handle_input(
		_joy_consume_event(),
		false,
		scene,
		null,
		FakeRegistry.new(),
		FakePlazaSceneHandler.new(),
		FakeMythicAcquisitionHandler.new(),
		starpoint,
		1.0,
		Callable(active, "value"),
		Callable(has_scene, "value")
	)
	_expect(starpoint.sync_calls == 0, "input flow should skip starpoint sync when the screen became inactive")
	scene.queue_free()


func _verify_post_input_missing_scene_skips_starpoint_sync() -> void:
	var scene := FakeResultScene.new()
	root.add_child(scene)
	var starpoint := FakeStarpointChoiceHandler.new()
	var active := BoolSequence.new([true, true])
	var has_scene := BoolSequence.new([true, false])
	StageClearResultInputFlowHandler.new().handle_input(
		_joy_consume_event(),
		false,
		scene,
		null,
		FakeRegistry.new(),
		FakePlazaSceneHandler.new(),
		FakeMythicAcquisitionHandler.new(),
		starpoint,
		1.0,
		Callable(active, "value"),
		Callable(has_scene, "value")
	)
	_expect(starpoint.sync_calls == 0, "input flow should skip starpoint sync when the result scene was closed")
	scene.queue_free()


func _verify_source_boundary() -> void:
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var registry_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_handler_registry.gd")
	var handler_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_input_flow_handler.gd")
	var input_screen_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_input_screen_data.gd")
	_expect(registry_source.find("StageClearResultInputFlowHandler.new()") >= 0, "handler registry should delegate input flow")
	_expect(screen_source.find("StageClearResultInputSceneHandler") < 0, "result screen should not route result-scene input directly")
	_expect(screen_source.find("res://scripts/ui/stage_clear_result_scene.gd") < 0, "result screen should not keep result-scene script preloads for input constants")
	_expect(screen_source.find("sync_box_perk_choice_rewards") < 0, "result screen should not sync starpoint choice rewards directly")
	_expect(screen_source.find("Callable(self, \"_has_result_scene\")") < 0, "result screen should not assemble input callbacks directly")
	_expect(screen_source.find("DALJI_CLICK_DIALOGUE_DURATION") < 0, "result screen should not pass input-scene dialogue timing directly")
	_expect(handler_source.find("StageClearResultInputSceneHandler.handle_result_input") >= 0, "input flow handler should own result scene input fanout")
	_expect(handler_source.find("sync_box_perk_choice_rewards") >= 0, "input flow handler should own post-input starpoint sync")
	_expect(handler_source.find("func handle_input_from_screen") >= 0, "input flow handler should expose the screen input adapter surface")
	_expect(handler_source.find("func _get_screen_object") < 0, "input flow handler should not own screen property readers")
	_expect(handler_source.find("DALJI_CLICK_DIALOGUE_DURATION") < 0, "input flow handler should delegate input constant lookup")
	_expect(handler_source.find("StageClearResultInputScreenData.build_input_context_from_screen") >= 0, "input flow handler should delegate screen context assembly")
	_expect(input_screen_data_source.find("DALJI_CLICK_DIALOGUE_DURATION") >= 0, "input screen data should own result-scene input timing lookup")
	_expect(input_screen_data_source.find("Callable(screen, \"_has_result_scene\")") >= 0, "input screen data should own screen callback wiring")
	var screen := StageClearResultScreen.new()
	_expect(screen != null, "result screen should instantiate with the input flow handler")


func _joy_consume_event() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_RIGHT_SHOULDER
	event.pressed = true
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
