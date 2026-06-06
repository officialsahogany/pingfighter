extends SceneTree

const MatchFlowDriver := preload("res://scripts/core/battle_scene_match_flow_driver.gd")
const ScoreboardState := preload("res://scripts/hud/scoreboard_state.gd")

var _failures: Array[String] = []
var _drive_reset_calls := 0
var _ball_reset_calls := 0


class FakeOwner:
	extends RefCounted

	var current_stage := 4
	var ai_mode := "junior"
	var starting_dash_tokens := 2
	var special_gauge := 99.0
	var special_gauge_max := 900.0
	var drive_text_timer_frames := 44.0
	var player_paddle_width := 222.0
	var player_paddle_height := 66.0
	var player_paddle_scale := 2.0
	var runtime_paddle_scale := 2.0
	var runtime_perk_levels := {"old": 1}
	var runtime_perk_pending_choices := 5
	var runtime_perk_starpoints := 7
	var runtime_perk_gold := 11
	var runtime_perk_choice_active := true
	var runtime_accessory_slot_bonus := 3
	var active_item_slots := [{"item_id": "old_item"}]
	var equipment_slots := {"head": "old_hat"}
	var passive_item_inventory := ["old_passive"]
	var passive_item_slots := {"belt": "old_belt"}
	var equipped_passive_items := {"belt": "old_belt"}
	var mythic_item_state := {"old": true}
	var megingjord_equipped := true


class FakeContextBuilder:
	extends RefCounted

	var requested_stage := 0
	var build_calls := 0
	var extra_deps: Dictionary = {}

	func build_match_flow_deps(_registry: Object, current_stage: int = 1) -> Dictionary:
		build_calls += 1
		requested_stage = current_stage
		var deps := {"current_stage": current_stage}
		deps.merge(extra_deps, true)
		return deps


class FakeController:
	extends RefCounted

	var reset_calls := 0
	var stage_transition_reset_calls := 0
	var reset_starting_dash_tokens := -1
	var stage_transition_starting_dash_tokens := -1
	var reset_league_player_paddle_scale := 0.0
	var saw_owner_in_reset := false
	var result := {
		"special_gauge": 0.0,
		"special_gauge_max": 500.0,
		"drive_text_timer_frames": 0.0,
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
		"player_paddle_scale": 1.0,
		"runtime_paddle_scale": 1.0,
		"runtime_perk_levels": {"reset_marker": 2},
		"runtime_perk_pending_choices": 0,
		"runtime_perk_starpoints": 0,
		"runtime_perk_gold": 0,
		"runtime_perk_choice_active": false,
		"runtime_accessory_slot_bonus": 0,
		"active_item_slots": [{"item_id": "starter_ball"}],
		"equipment_slots": {"head": null, "belt": null},
		"passive_item_inventory": ["starter_charm"],
		"passive_item_slots": {"head": null},
		"equipped_passive_items": {"head": null},
		"mythic_item_state": {"reset": true},
		"megingjord_equipped": false,
	}

	func reset_game(deps: Dictionary, callbacks: Dictionary) -> Dictionary:
		reset_calls += 1
		reset_starting_dash_tokens = int(deps.get("starting_dash_tokens", -1))
		reset_league_player_paddle_scale = float(deps.get("league_player_paddle_scale", 0.0))
		saw_owner_in_reset = deps.get("owner", null) != null
		if int(deps.get("current_stage", 0)) != 4:
			return {}
		var reset_drive_input_callback: Callable = callbacks.get("reset_drive_input", Callable())
		if reset_drive_input_callback.is_valid():
			reset_drive_input_callback.call()
		var reset_ball_callback: Callable = callbacks.get("reset_ball", Callable())
		if reset_ball_callback.is_valid():
			reset_ball_callback.call()
		return result

	func reset_for_stage_transition(_deps: Dictionary, callbacks: Dictionary) -> Dictionary:
		stage_transition_reset_calls += 1
		stage_transition_starting_dash_tokens = int(_deps.get("starting_dash_tokens", -1))
		var reset_drive_input_callback: Callable = callbacks.get("reset_drive_input", Callable())
		if reset_drive_input_callback.is_valid():
			reset_drive_input_callback.call()
		var reset_ball_callback: Callable = callbacks.get("reset_ball", Callable())
		if reset_ball_callback.is_valid():
			reset_ball_callback.call()
		return {
			"special_gauge": 0.0,
			"drive_text_timer_frames": 0.0,
		}


class FakeStageTransitionActiveItemRuntime:
	extends RefCounted

	var reset_for_stage_transition_calls := 0
	var saw_registry := false

	func reset_for_stage_transition(owner: Object, registry: Object) -> void:
		reset_for_stage_transition_calls += 1
		saw_registry = registry != null
		if owner == null:
			return
		var slots_value: Variant = owner.get("active_item_slots")
		if not (slots_value is Array):
			return
		var slots: Array = (slots_value as Array).duplicate(true)
		for i in range(slots.size()):
			var item_value: Variant = slots[i]
			if item_value is Dictionary:
				var item_data: Dictionary = item_value
				item_data["last_use_msec"] = -1
				slots[i] = item_data
		owner.set("active_item_slots", slots)


class FakeScoreboardState:
	extends RefCounted

	var update_calls := 0
	var next_result := ScoreboardState.UPDATE_NONE

	func update_scoreboard(_delta: float) -> int:
		update_calls += 1
		return next_result


class FakeRoundState:
	extends RefCounted

	var prepare_calls := 0

	func prepare_serve_after_scoreboard() -> void:
		prepare_calls += 1


class FakeMythicItemRuntime:
	extends RefCounted

	var pending_calls := 0
	var saw_owner := false
	var saw_registry := false

	func start_pending_pandora_legacy_selection(owner: Object, registry: Object) -> void:
		pending_calls += 1
		saw_owner = owner != null
		saw_registry = registry != null


class FakeStage4MapState:
	extends RefCounted

	var prepare_calls := 0
	var saw_current_stage := false
	var saw_audio := false
	var saw_event := false

	func handle_scoreboard_serve_prepare(deps: Dictionary) -> void:
		prepare_calls += 1
		saw_current_stage = int(deps.get("current_stage", 0)) == 4
		saw_audio = deps.get("audio", null) != null
		saw_event = deps.get("stage4_temple_destruction_event", null) != null


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []

	func begin_sample() -> int:
		return Time.get_ticks_usec()

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)

	func has_label(label: String) -> bool:
		return labels.has(label)


class FakeRegistry:
	extends RefCounted

	var context_builder: Object
	var controller: Object
	var scoreboard_state: Object = null
	var active_item_runtime: Object = null
	var round_state: Object = null
	var mythic_item_runtime: Object = null
	var stage4_map_state: Object = null
	var stage4_temple_destruction_event: Object = null
	var game_audio: Object = null
	var battle_perf_logger: Object = null

	func _init(next_context_builder: Object, next_controller: Object) -> void:
		context_builder = next_context_builder
		controller = next_controller

	func get_instance(key: String) -> Object:
		match key:
			"battle_update_context":
				return context_builder
			"match_flow_controller":
				return controller
			"scoreboard_state":
				return scoreboard_state
			"active_item_runtime":
				return active_item_runtime
			"round_flow_state":
				return round_state
			"mythic_item_runtime":
				return mythic_item_runtime
			"stage4_map_state":
				return stage4_map_state
			"stage4_temple_destruction_event":
				return stage4_temple_destruction_event
			"game_audio":
				return game_audio
			"battle_perf_logger":
				return battle_perf_logger
			_:
				return null


func _init() -> void:
	var owner := FakeOwner.new()
	var context_builder := FakeContextBuilder.new()
	var controller := FakeController.new()
	var registry := FakeRegistry.new(context_builder, controller)
	var driver: Object = MatchFlowDriver.new()

	driver.reset_game(
		owner,
		registry,
		Callable(self, "_record_drive_reset"),
		Callable(self, "_record_ball_reset")
	)

	_expect(controller.reset_calls == 1, "reset game should call match flow controller")
	_expect(context_builder.requested_stage == 4, "reset deps should use owner current stage")
	_expect(controller.saw_owner_in_reset and controller.reset_starting_dash_tokens == 2, "reset deps should include Junior League starting dash tokens")
	_expect(is_equal_approx(controller.reset_league_player_paddle_scale, 1.5), "reset deps should include Junior League paddle scale")
	_expect(_drive_reset_calls == 1 and _ball_reset_calls == 1, "reset callbacks should be forwarded")
	_expect(owner.special_gauge == 0.0 and owner.special_gauge_max == 500.0, "gauge values should reset")
	_expect(owner.player_paddle_width == 155.0 and owner.player_paddle_scale == 1.0, "paddle values should reset")
	_expect(owner.runtime_perk_levels.get("reset_marker", 0) == 2, "runtime perk levels should apply")
	_expect(owner.runtime_perk_pending_choices == 0 and owner.runtime_perk_gold == 0, "runtime perk counters should reset")
	_expect(not owner.runtime_perk_choice_active, "runtime perk choice modal state should reset")
	_expect(owner.runtime_accessory_slot_bonus == 0, "runtime accessory bonus should reset")
	_expect(owner.active_item_slots.size() == 1 and owner.active_item_slots[0].get("item_id", "") == "starter_ball", "active item slots should refresh")
	_expect(owner.passive_item_inventory == ["starter_charm"], "passive inventory should refresh")
	_expect(owner.mythic_item_state.get("reset", false), "mythic item state should refresh")
	_expect(not owner.megingjord_equipped, "megingjord equip flag should reset")

	controller.result["active_item_slots"][0]["item_id"] = "mutated"
	controller.result["runtime_perk_levels"]["reset_marker"] = 99
	_expect(owner.active_item_slots[0].get("item_id", "") == "starter_ball", "array reset results should be duplicated")
	_expect(owner.runtime_perk_levels.get("reset_marker", 0) == 2, "dictionary reset results should be duplicated")

	var scoreboard := FakeScoreboardState.new()
	var round_state := FakeRoundState.new()
	var mythic_runtime := FakeMythicItemRuntime.new()
	var stage4_map := FakeStage4MapState.new()
	var perf_logger := FakePerfLogger.new()
	context_builder.build_calls = 0
	registry.scoreboard_state = scoreboard
	registry.round_state = round_state
	registry.mythic_item_runtime = mythic_runtime
	registry.stage4_map_state = stage4_map
	registry.stage4_temple_destruction_event = RefCounted.new()
	registry.game_audio = RefCounted.new()
	registry.battle_perf_logger = perf_logger

	scoreboard.next_result = ScoreboardState.UPDATE_NONE
	driver.update_scoreboard(
		registry,
		0.125,
		Callable(self, "_record_drive_reset"),
		Callable(self, "_record_ball_reset"),
		owner
	)
	_expect(scoreboard.update_calls == 1, "scoreboard fast path should tick the overlay state")
	_expect(context_builder.build_calls == 0, "scoreboard fast path should avoid full deps while the overlay is still holding")

	var ball_resets_before: int = _ball_reset_calls
	scoreboard.next_result = ScoreboardState.UPDATE_START_SERVE
	driver.update_scoreboard(
		registry,
		2.0,
		Callable(self, "_record_drive_reset"),
		Callable(self, "_record_ball_reset"),
		owner
	)
	_expect(scoreboard.update_calls == 2, "scoreboard fast path should tick completion")
	_expect(context_builder.build_calls == 0, "scoreboard completion should avoid full match-flow deps")
	_expect(_ball_reset_calls == ball_resets_before + 1, "scoreboard completion should start the next serve")
	_expect(round_state.prepare_calls == 1, "scoreboard completion should prepare serve state")
	_expect(stage4_map.prepare_calls == 1 and stage4_map.saw_current_stage and stage4_map.saw_audio and stage4_map.saw_event, "scoreboard completion should preserve stage 4 serve-prepare routing")
	_expect(mythic_runtime.pending_calls == 1 and mythic_runtime.saw_owner and mythic_runtime.saw_registry, "scoreboard completion should preserve pending mythic selection routing")
	_expect(perf_logger.has_label("physics.scoreboard_result.build_light_deps"), "scoreboard completion should profile light deps")
	_expect(perf_logger.has_label("physics.scoreboard_result.stage4_prepare"), "scoreboard completion should profile stage 4 prepare separately")
	_expect(perf_logger.has_label("physics.scoreboard_result.total"), "scoreboard completion should profile total result handling")

	var active_item_runtime := FakeStageTransitionActiveItemRuntime.new()
	registry.active_item_runtime = active_item_runtime
	owner.active_item_slots = [{"item_id": "reward_item", "last_use_msec": 45678}]
	var drive_resets_before: int = _drive_reset_calls
	ball_resets_before = _ball_reset_calls
	driver.reset_for_stage_transition(
		owner,
		registry,
		Callable(self, "_record_drive_reset"),
		Callable(self, "_record_ball_reset")
	)
	_expect(controller.stage_transition_reset_calls == 1, "stage transition should use the preserving reset path")
	_expect(controller.stage_transition_starting_dash_tokens == 2, "stage transition deps should keep Junior League starting dash tokens")
	_expect(_drive_reset_calls == drive_resets_before + 1 and _ball_reset_calls == ball_resets_before + 1, "stage transition should forward reset callbacks")
	_expect(active_item_runtime.reset_for_stage_transition_calls == 1 and active_item_runtime.saw_registry, "stage transition should reset active item transient runtime state")
	_expect(owner.active_item_slots.size() == 1, "stage transition should preserve active item slots")
	_expect(str(owner.active_item_slots[0].get("item_id", "")) == "reward_item", "stage transition should keep active item identity")
	_expect(int(owner.active_item_slots[0].get("last_use_msec", 0)) < 0, "stage transition should clear active item cooldown fields")

	if _failures.is_empty():
		print("match_flow_driver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _record_drive_reset() -> void:
	_drive_reset_calls += 1


func _record_ball_reset() -> void:
	_ball_reset_calls += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
