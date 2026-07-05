extends SceneTree

const StageClearResultImmediateRewardFlowHandler := preload("res://scripts/core/stage_clear_result_immediate_reward_flow_handler.gd")
const StageClearResultImmediateRewardFlowData := preload("res://scripts/core/stage_clear_result_immediate_reward_flow_data.gd")
const StageClearResultScreen := preload("res://scripts/core/stage_clear_result_screen.gd")

var _failures: Array[String] = []


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


class FakeRewardGrantHandler:
	extends RefCounted

	var next_result: Dictionary = {"granted": false}
	var received_defer_choice: bool = false
	var grant_calls: int = 0

	func grant_immediate_box_reward(
		_reward: Dictionary,
		_owner: Object,
		_registry: Object,
		defer_starpoint_choice: bool
	) -> Dictionary:
		grant_calls += 1
		received_defer_choice = defer_starpoint_choice
		return next_result.duplicate(true)


class FakeStarpointChoiceHandler:
	extends RefCounted

	var can_defer: bool = true
	var seen_runtime_perk_state: Object
	var seen_runtime_perk_catalog: Object
	var scheduled_scene: Control
	var scheduled_box_index: int = -1
	var scheduled_delay: float = 0.0

	func can_defer_choice(runtime_perk_state: Object, runtime_perk_catalog: Object) -> bool:
		seen_runtime_perk_state = runtime_perk_state
		seen_runtime_perk_catalog = runtime_perk_catalog
		return can_defer

	func schedule_deferred_choice(scene: Control, box_index: int, delay: float) -> void:
		scheduled_scene = scene
		scheduled_box_index = box_index
		scheduled_delay = delay


class FakeMythicAcquisitionHandler:
	extends RefCounted

	var raised_runtime: Object

	func raise_cinematic(mythic_item_runtime: Object) -> void:
		raised_runtime = mythic_item_runtime


class FakeScreen:
	extends RefCounted

	var active: bool = true
	var _scene_node: Control


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_starpoint_deferred_choice_flow()
	_verify_mythic_acquisition_raise_flow()
	_verify_failed_grant_stops_followup()
	_verify_screen_callback_adapter()
	_verify_source_boundary()

	if _failures.is_empty():
		print("stage_clear_result_immediate_reward_flow_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_starpoint_deferred_choice_flow() -> void:
	var registry := _registry_with_runtime_modules()
	var scene := Control.new()
	var reward_grant := FakeRewardGrantHandler.new()
	reward_grant.next_result = {"granted": true, "defer_starpoint_choice": true}
	var starpoint := FakeStarpointChoiceHandler.new()
	var mythic := FakeMythicAcquisitionHandler.new()
	scene.visible = false

	var granted: bool = StageClearResultImmediateRewardFlowHandler.new().grant_immediate_box_reward(
		{"type": "starpoint"},
		3,
		null,
		registry,
		scene,
		reward_grant,
		starpoint,
		mythic,
		0.65
	)
	_expect(granted, "immediate reward flow should report granted starpoint rewards")
	_expect(reward_grant.received_defer_choice, "immediate reward flow should pass defer-choice availability into the grant handler")
	_expect(starpoint.seen_runtime_perk_state == registry.instances["runtime_perk_state"], "immediate reward flow should read runtime perk state for defer checks")
	_expect(starpoint.seen_runtime_perk_catalog == registry.instances["runtime_perk_catalog"], "immediate reward flow should read runtime perk catalog for defer checks")
	_expect(starpoint.scheduled_scene == scene, "immediate reward flow should schedule the deferred choice on the result scene")
	_expect(starpoint.scheduled_box_index == 3, "immediate reward flow should preserve the reward box index")
	_expect(is_equal_approx(starpoint.scheduled_delay, 0.65), "immediate reward flow should preserve the deferred choice delay")
	_expect(mythic.raised_runtime == null, "starpoint flow should not raise mythic acquisition cinematics")
	_expect(scene.visible, "immediate reward flow should resync result scene visibility after a successful grant")
	scene.free()


func _verify_mythic_acquisition_raise_flow() -> void:
	var registry := _registry_with_runtime_modules()
	var reward_grant := FakeRewardGrantHandler.new()
	reward_grant.next_result = {"granted": true, "raise_mythic_acquisition_cinematic": true}
	var starpoint := FakeStarpointChoiceHandler.new()
	starpoint.can_defer = false
	var mythic := FakeMythicAcquisitionHandler.new()

	var granted: bool = StageClearResultImmediateRewardFlowHandler.new().grant_immediate_box_reward(
		{"type": "mythic"},
		0,
		null,
		registry,
		null,
		reward_grant,
		starpoint,
		mythic,
		0.65
	)
	_expect(granted, "immediate reward flow should report granted mythic rewards")
	_expect(not reward_grant.received_defer_choice, "mythic flow should pass the actual defer-choice availability")
	_expect(mythic.raised_runtime == registry.instances["mythic_item_runtime"], "immediate reward flow should raise the mythic acquisition cinematic with the runtime")


func _verify_failed_grant_stops_followup() -> void:
	var registry := _registry_with_runtime_modules()
	var reward_grant := FakeRewardGrantHandler.new()
	reward_grant.next_result = {"granted": false, "defer_starpoint_choice": true, "raise_mythic_acquisition_cinematic": true}
	var starpoint := FakeStarpointChoiceHandler.new()
	var mythic := FakeMythicAcquisitionHandler.new()
	var scene := Control.new()
	scene.visible = false

	var granted: bool = StageClearResultImmediateRewardFlowHandler.new().grant_immediate_box_reward(
		{"type": "starpoint"},
		1,
		null,
		registry,
		scene,
		reward_grant,
		starpoint,
		mythic,
		0.65
	)
	_expect(not granted, "immediate reward flow should report failed grants")
	_expect(starpoint.scheduled_box_index == -1, "failed immediate grants should not schedule starpoint choices")
	_expect(mythic.raised_runtime == null, "failed immediate grants should not raise mythic cinematics")
	_expect(not scene.visible, "failed immediate grants should not resync result scene visibility")
	scene.free()


func _verify_screen_callback_adapter() -> void:
	var registry := _registry_with_runtime_modules()
	var scene := Control.new()
	scene.visible = false
	var screen := FakeScreen.new()
	screen._scene_node = scene
	var reward_grant := FakeRewardGrantHandler.new()
	reward_grant.next_result = {"granted": true}
	var granted: bool = StageClearResultImmediateRewardFlowHandler.new().grant_immediate_box_reward_from_screen(
		{"type": "starpoint"},
		2,
		screen,
		null,
		registry,
		reward_grant,
		FakeStarpointChoiceHandler.new(),
		FakeMythicAcquisitionHandler.new(),
		0.65
	)
	_expect(granted, "immediate reward flow screen adapter should grant through the current screen scene")
	_expect(scene.visible, "immediate reward flow screen adapter should sync the current screen scene visibility")
	screen.active = false
	scene.visible = false
	granted = StageClearResultImmediateRewardFlowHandler.new().grant_immediate_box_reward_from_screen(
		{"type": "starpoint"},
		2,
		screen,
		null,
		registry,
		reward_grant,
		FakeStarpointChoiceHandler.new(),
		FakeMythicAcquisitionHandler.new(),
		0.65
	)
	_expect(not granted, "immediate reward flow screen adapter should ignore inactive result screens")
	_expect(not scene.visible, "inactive screen adapter should not resync scene visibility")
	scene.free()


func _verify_source_boundary() -> void:
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var registry_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_handler_registry.gd")
	var handler_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_immediate_reward_flow_handler.gd")
	var flow_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_immediate_reward_flow_data.gd")
	_expect(registry_source.find("StageClearResultImmediateRewardFlowHandler.new()") >= 0, "handler registry should delegate immediate reward followup flow")
	_expect(screen_source.find("func _grant_immediate_box_reward") < 0, "result screen should not keep immediate reward pass-through helpers")
	_expect(screen_source.find("func _sync_result_scene_visibility") < 0, "result screen should not keep result-scene visibility pass-through helpers")
	_expect(screen_source.find("\"defer_starpoint_choice\"") < 0, "result screen should not branch on deferred starpoint reward result keys directly")
	_expect(screen_source.find("\"raise_mythic_acquisition_cinematic\"") < 0, "result screen should not branch on mythic cinematic reward result keys directly")
	_expect(handler_source.find("func grant_immediate_box_reward_from_screen") >= 0, "immediate reward flow handler should own the screen callback adapter")
	_expect(handler_source.find("StageClearResultImmediateRewardFlowData.grant_immediate_box_reward") >= 0, "immediate reward flow handler should delegate direct grants to flow data")
	_expect(handler_source.find("StageClearResultImmediateRewardFlowData.grant_immediate_box_reward_from_screen") >= 0, "immediate reward flow handler should delegate screen grants to flow data")
	_expect(handler_source.find("\"defer_starpoint_choice\"") < 0, "immediate reward flow handler should not own deferred starpoint result handling")
	_expect(handler_source.find("\"raise_mythic_acquisition_cinematic\"") < 0, "immediate reward flow handler should not own mythic cinematic result handling")
	_expect(flow_data_source.find("\"defer_starpoint_choice\"") >= 0, "immediate reward flow data should own deferred starpoint result handling")
	_expect(flow_data_source.find("\"raise_mythic_acquisition_cinematic\"") >= 0, "immediate reward flow data should own mythic cinematic result handling")
	_expect(flow_data_source.find("runtime_perk_catalog") >= 0, "immediate reward flow data should own defer-choice registry reads")
	_expect(flow_data_source.find("raise_cinematic") >= 0, "immediate reward flow data should own mythic cinematic dispatch")
	_expect(StageClearResultImmediateRewardFlowData != null, "immediate reward flow data should preload for source-boundary coverage")
	var screen := StageClearResultScreen.new()
	_expect(screen != null, "result screen should still instantiate with the immediate reward flow handler")


func _registry_with_runtime_modules() -> FakeRegistry:
	var registry := FakeRegistry.new()
	registry.instances["runtime_perk_state"] = FakeRuntimeModule.new()
	registry.instances["runtime_perk_catalog"] = FakeRuntimeModule.new()
	registry.instances["mythic_item_runtime"] = FakeRuntimeModule.new()
	return registry


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
