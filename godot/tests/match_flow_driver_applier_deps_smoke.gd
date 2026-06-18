extends SceneTree

const MatchFlowDriver := preload("res://scripts/core/battle_scene_match_flow_driver.gd")

var _failures: Array[String] = []
var _drive_reset_calls := 0
var _ball_reset_calls := 0


class FakeOwner:
	extends RefCounted

	var current_stage := 7
	var applied_marker := false
	var special_gauge := 99.0
	var runtime_perk_levels := {"gold_digger": 2}
	var runtime_perk_gold := 321
	var passive_item_inventory := [{"item_name": "sacred_laurel"}]
	var equipped_passive_items := {"head": {"item_name": "sacred_laurel"}}
	var active_item_slots := [{"item_name": "stopwatch", "cooldown": 42}]
	var mythic_item_state := {"odins_eye_available": true}


class FakeContextBuilder:
	extends RefCounted

	var requested_stage := 0

	func build_match_flow_deps(_registry: Object, current_stage: int = 1) -> Dictionary:
		requested_stage = current_stage
		return {"current_stage": current_stage}


class FakeController:
	extends RefCounted

	var reset_calls := 0
	var reset_for_stage_transition_calls := 0

	func reset_game(deps: Dictionary, callbacks: Dictionary) -> Dictionary:
		reset_calls += 1
		var reset_drive_input_callback: Callable = callbacks.get("reset_drive_input", Callable())
		if reset_drive_input_callback.is_valid():
			reset_drive_input_callback.call()
		var reset_ball_callback: Callable = callbacks.get("reset_ball", Callable())
		if reset_ball_callback.is_valid():
			reset_ball_callback.call()
		return {
			"result_marker": true,
			"current_stage": deps.get("current_stage", 0),
			"runtime_perk_levels": {},
			"runtime_perk_gold": 0,
			"passive_item_inventory": [],
			"equipped_passive_items": {},
			"active_item_slots": [],
			"mythic_item_state": {},
		}

	func reset_for_stage_transition(deps: Dictionary, callbacks: Dictionary) -> Dictionary:
		reset_for_stage_transition_calls += 1
		var reset_drive_input_callback: Callable = callbacks.get("reset_drive_input", Callable())
		if reset_drive_input_callback.is_valid():
			reset_drive_input_callback.call()
		var reset_ball_callback: Callable = callbacks.get("reset_ball", Callable())
		if reset_ball_callback.is_valid():
			reset_ball_callback.call()
		return {
			"special_gauge": 0.0,
			"drive_text_timer_frames": 0.0,
			"optimus_energy_initialized": false,
		}


class FakeApplier:
	extends RefCounted

	var calls := 0
	var applied_stage := 0

	func apply_reset_result(owner: Object, result: Dictionary) -> void:
		calls += 1
		applied_stage = int(result.get("current_stage", 0))
		owner.set("applied_marker", bool(result.get("result_marker", false)))


class FakeRegistry:
	extends RefCounted

	var context_builder: Object
	var controller: Object
	var applier: Object
	var active_item_runtime: Object = null
	var mythic_item_runtime: Object = null

	func _init(
		next_context_builder: Object,
		next_controller: Object,
		next_applier: Object = null,
		next_active_item_runtime: Object = null,
		next_mythic_item_runtime: Object = null
	) -> void:
		context_builder = next_context_builder
		controller = next_controller
		applier = next_applier
		active_item_runtime = next_active_item_runtime
		mythic_item_runtime = next_mythic_item_runtime

	func get_instance(key: String) -> Object:
		match key:
			"battle_update_context":
				return context_builder
			"match_flow_controller":
				return controller
			"battle_scene_match_reset_result_applier":
				return applier
			"active_item_runtime":
				return active_item_runtime
			"mythic_item_runtime":
				return mythic_item_runtime
			_:
				return null


class FakeActiveItemRuntime:
	extends RefCounted

	var reset_for_stage_transition_calls := 0

	func reset_for_stage_transition(owner: Object, _registry: Object) -> void:
		reset_for_stage_transition_calls += 1
		var slots: Array = owner.get("active_item_slots")
		if slots.size() > 0 and slots[0] is Dictionary:
			var slot: Dictionary = (slots[0] as Dictionary).duplicate(true)
			slot["cooldown"] = 0
			owner.set("active_item_slots", [slot])


class FakeMythicRuntime:
	extends RefCounted

	var stage_advance_calls := 0

	func on_stage_advance(_owner: Object, _registry: Object) -> void:
		stage_advance_calls += 1


func _init() -> void:
	var owner := FakeOwner.new()
	var context_builder := FakeContextBuilder.new()
	var controller := FakeController.new()
	var applier := FakeApplier.new()
	var registry := FakeRegistry.new(context_builder, controller, applier)
	var driver: Object = MatchFlowDriver.new()

	driver.reset_game(
		owner,
		registry,
		Callable(self, "_record_drive_reset"),
		Callable(self, "_record_ball_reset")
	)

	_expect(controller.reset_calls == 1, "reset game should call match flow controller")
	_expect(context_builder.requested_stage == 7, "reset deps should use owner current stage")
	_expect(_drive_reset_calls == 1 and _ball_reset_calls == 1, "reset callbacks should be forwarded")
	_expect(applier.calls == 1 and applier.applied_stage == 7, "registered reset-result applier should be used")
	_expect(owner.applied_marker, "registered applier should mutate owner from reset result")

	_verify_continue_reset_preserves_run_progress()

	if _failures.is_empty():
		print("match_flow_driver_applier_deps_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _record_drive_reset() -> void:
	_drive_reset_calls += 1


func _record_ball_reset() -> void:
	_ball_reset_calls += 1


func _verify_continue_reset_preserves_run_progress() -> void:
	_drive_reset_calls = 0
	_ball_reset_calls = 0
	var owner := FakeOwner.new()
	var context_builder := FakeContextBuilder.new()
	var controller := FakeController.new()
	var active_item_runtime := FakeActiveItemRuntime.new()
	var mythic_item_runtime := FakeMythicRuntime.new()
	var registry := FakeRegistry.new(context_builder, controller, null, active_item_runtime, mythic_item_runtime)
	var driver: Object = MatchFlowDriver.new()

	driver.reset_for_continue(
		owner,
		registry,
		Callable(self, "_record_drive_reset"),
		Callable(self, "_record_ball_reset")
	)

	_expect(controller.reset_for_stage_transition_calls == 1, "continue reset should use the progress-preserving reset")
	_expect(controller.reset_calls == 0, "continue reset must not call full reset_game")
	_expect(context_builder.requested_stage == 7, "continue reset deps should use owner current stage")
	_expect(_drive_reset_calls == 1 and _ball_reset_calls == 1, "continue reset should forward reset callbacks")
	_expect(is_equal_approx(owner.special_gauge, 0.0), "continue reset should still reset match transient gauge")
	_expect(owner.runtime_perk_levels == {"gold_digger": 2}, "continue reset should preserve runtime perk levels")
	_expect(owner.runtime_perk_gold == 321, "continue reset should preserve unbanked runtime perk gold")
	_expect(owner.passive_item_inventory.size() == 1, "continue reset should preserve passive inventory")
	_expect(owner.equipped_passive_items.has("head"), "continue reset should preserve equipped passive items")
	_expect(owner.mythic_item_state.has("odins_eye_available"), "continue reset should preserve mythic state")
	_expect(active_item_runtime.reset_for_stage_transition_calls == 1, "continue reset should refresh active item cooldowns")
	_expect(int((owner.active_item_slots[0] as Dictionary).get("cooldown", -1)) == 0, "continue reset should keep active slot item while clearing cooldown")
	_expect(mythic_item_runtime.stage_advance_calls == 0, "continue reset must not notify mythic stage advance")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
