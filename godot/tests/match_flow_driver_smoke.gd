extends SceneTree

const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const MatchFlowDriver := preload("res://scripts/core/battle_scene_match_flow_driver.gd")
const ScoreboardState := preload("res://scripts/hud/scoreboard_state.gd")

var _failures: Array[String] = []
var _drive_reset_calls := 0
var _ball_reset_calls := 0
var _reset_game_callback_calls := 0


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
	var chance_gems_count := 0
	var chance_gems_max := 3


class SchemaGatedChanceOwner:
	extends RefCounted

	var scene_state: Object = BattleSceneState.new()
	var rejected_keys: Array[String] = []

	func _init() -> void:
		scene_state.reset()

	func _get(property: StringName) -> Variant:
		var key := str(property)
		if scene_state.has_key(key):
			return scene_state.get_value(key)
		return null

	func _set(property: StringName, value: Variant) -> bool:
		var key := str(property)
		if not scene_state.has_key(key):
			rejected_keys.append(key)
			return false
		scene_state.set_value(key, value)
		return true

	func value_of(key: String) -> Variant:
		if scene_state.has_key(key):
			return scene_state.get_value(key)
		return null


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
	var player_points := 0
	var boss_points := 0
	var win_goal := 5
	var last_scoring_side := "player"

	func update_scoreboard(_delta: float) -> int:
		update_calls += 1
		return next_result

	func get_player_points() -> int:
		return player_points

	func get_boss_points() -> int:
		return boss_points

	func get_win_goal() -> int:
		return win_goal

	func get_last_scoring_side() -> String:
		return last_scoring_side


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


class FakeChanceGemStore:
	extends RefCounted

	var chance_gems := 0
	var max_chance_gems := 3
	var consume_calls := 0
	var get_calls := 0

	func _init(next_chance_gems: int = 0) -> void:
		chance_gems = max(0, next_chance_gems)

	func get_chance_gems() -> int:
		get_calls += 1
		return chance_gems

	func get_max_chance_gems() -> int:
		return max_chance_gems

	func consume_chance_gem() -> int:
		consume_calls += 1
		chance_gems = max(0, chance_gems - 1)
		return chance_gems


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


class FakeDefeatSettlementScreen:
	extends RefCounted

	var show_calls := 0
	var saw_owner := false
	var saw_registry := false
	var saw_exit_callback := false
	var exit_callback_method := ""

	func show(owner: Object, registry: Object, exit_callback: Callable) -> bool:
		show_calls += 1
		saw_owner = owner != null
		saw_registry = registry != null
		saw_exit_callback = exit_callback.is_valid()
		exit_callback_method = str(exit_callback.get_method())
		return true


class FakeDefeatContinueScreen:
	extends RefCounted

	var show_calls := 0
	var saw_owner := false
	var saw_registry := false
	var saw_continue_callback := false
	var saw_consume_callback := false
	var confirm_calls := 0
	var _continue_callback: Callable = Callable()
	var _consume_callback: Callable = Callable()

	func show(owner: Object, registry: Object, continue_callback: Callable) -> bool:
		show_calls += 1
		saw_owner = owner != null
		saw_registry = registry != null
		saw_continue_callback = continue_callback.is_valid()
		_continue_callback = continue_callback
		return true

	func show_with_consume(owner: Object, registry: Object, continue_callback: Callable, consume_callback: Callable) -> bool:
		show_calls += 1
		saw_owner = owner != null
		saw_registry = registry != null
		saw_continue_callback = continue_callback.is_valid()
		saw_consume_callback = consume_callback.is_valid()
		_continue_callback = continue_callback
		_consume_callback = consume_callback
		return true

	func confirm_continue() -> void:
		confirm_calls += 1
		if _consume_callback.is_valid():
			_consume_callback.call()
		if _continue_callback.is_valid():
			_continue_callback.call()


class FakeStageClearResultScreen:
	extends RefCounted

	var show_calls := 0
	var saw_owner := false
	var saw_registry := false
	var saw_reset_callback := false
	var saw_exit_callback := false
	var exit_callback_method := ""

	func show_from_scoreboard(
		owner: Object,
		registry: Object,
		reset_game_callback: Callable,
		exit_callback: Callable
	) -> bool:
		show_calls += 1
		saw_owner = owner != null
		saw_registry = registry != null
		saw_reset_callback = reset_game_callback.is_valid()
		saw_exit_callback = exit_callback.is_valid()
		exit_callback_method = str(exit_callback.get_method())
		return true


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
	var defeat_settlement_screen: Object = null
	var defeat_continue_screen: Object = null
	var stage_clear_result_screen: Object = null
	var plaza_save_store: Object = null

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
			"defeat_settlement_screen":
				return defeat_settlement_screen
			"defeat_chance_gems_continue_screen":
				return defeat_continue_screen
			"stage_clear_result_screen":
				return stage_clear_result_screen
			"plaza_save_store":
				return plaza_save_store
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

	_expect(BattleSceneState.DEFAULT_VALUES.has("chance_gems_count"), "chance gem count must be declared in the owner schema")
	_expect(BattleSceneState.DEFAULT_VALUES.has("chance_gems_max"), "chance gem max must be declared in the owner schema")
	var continue_owner := SchemaGatedChanceOwner.new()
	var chance_store := FakeChanceGemStore.new(2)
	var continue_screen := FakeDefeatContinueScreen.new()
	registry.plaza_save_store = chance_store
	registry.defeat_continue_screen = continue_screen
	scoreboard.next_result = ScoreboardState.UPDATE_RESET_GAME
	scoreboard.player_points = 1
	scoreboard.boss_points = 5
	scoreboard.win_goal = 5
	scoreboard.last_scoring_side = "boss"
	var transition_resets_before: int = controller.stage_transition_reset_calls
	var drive_resets_before: int = _drive_reset_calls
	ball_resets_before = _ball_reset_calls
	_reset_game_callback_calls = 0
	driver.update_scoreboard(
		registry,
		2.0,
		Callable(self, "_record_reset_game_callback"),
		Callable(self, "_record_ball_reset"),
		continue_owner,
		Callable(self, "_record_drive_reset")
	)
	_expect(chance_store.get_calls > 0, "defeat resolver should read chance gems from the plaza save store")
	_expect(chance_store.consume_calls == 0 and chance_store.chance_gems == 2, "defeat resolver should not consume a chance gem before the continue screen confirmation")
	_expect(int(continue_owner.value_of("chance_gems_count")) == 2, "defeat resolver should mirror pre-confirm chance gems to the owner")
	_expect(int(continue_owner.value_of("chance_gems_max")) == 3, "defeat resolver should mirror chance gem capacity to the owner")
	_expect(
		continue_owner.rejected_keys.is_empty(),
		"schema-gated owner should accept chance gem mirrors; rejected=%s" % ", ".join(continue_owner.rejected_keys)
	)
	_expect(continue_screen.show_calls == 1 and continue_screen.saw_owner and continue_screen.saw_registry, "defeat resolver should open the chance gem continue screen")
	_expect(continue_screen.saw_continue_callback, "chance gem continue screen should receive the preserving reset callback")
	_expect(continue_screen.saw_consume_callback, "chance gem continue screen should receive the confirm-time consume callback")
	_expect(controller.stage_transition_reset_calls == transition_resets_before, "defeat resolver must wait for confirmation before continuing")
	_expect(_drive_reset_calls == drive_resets_before and _ball_reset_calls == ball_resets_before, "chance gem screen should delay drive and ball reset until confirm")
	_expect(_reset_game_callback_calls == 0, "defeat continue must not call the full reset callback")
	continue_screen.confirm_continue()
	_expect(continue_screen.confirm_calls == 1, "test setup should confirm the chance gem screen once")
	_expect(chance_store.consume_calls == 1 and chance_store.chance_gems == 1, "defeat confirmation should consume exactly one chance gem through the store")
	_expect(int(continue_owner.value_of("chance_gems_count")) == 1, "defeat confirmation should mirror remaining chance gems to the owner")
	_expect(controller.stage_transition_reset_calls == transition_resets_before + 1, "defeat confirmation should continue through the preserving reset")
	_expect(_drive_reset_calls == drive_resets_before + 1 and _ball_reset_calls == ball_resets_before + 1, "defeat confirmation should reset drive and ball")
	_expect(_reset_game_callback_calls == 0, "defeat confirmation must not call the full reset callback")

	var win_owner := FakeOwner.new()
	win_owner.chance_gems_count = 2
	registry.plaza_save_store = null
	registry.defeat_continue_screen = FakeDefeatContinueScreen.new()
	var win_defeat_settlement_screen := FakeDefeatSettlementScreen.new()
	var stage_clear_screen := FakeStageClearResultScreen.new()
	registry.defeat_settlement_screen = win_defeat_settlement_screen
	registry.stage_clear_result_screen = stage_clear_screen
	transition_resets_before = controller.stage_transition_reset_calls
	_reset_game_callback_calls = 0
	scoreboard.next_result = ScoreboardState.UPDATE_RESET_GAME
	scoreboard.player_points = 5
	scoreboard.boss_points = 3
	scoreboard.win_goal = 5
	scoreboard.last_scoring_side = "player"
	driver.update_scoreboard(
		registry,
		2.0,
		Callable(self, "_record_reset_game_callback"),
		Callable(self, "_record_ball_reset"),
		win_owner,
		Callable(self, "_record_drive_reset")
	)
	_expect(int(win_owner.chance_gems_count) == 2, "match win must not consume a chance gem")
	_expect(controller.stage_transition_reset_calls == transition_resets_before, "match win must not run continue reset")
	_expect((registry.defeat_continue_screen as FakeDefeatContinueScreen).show_calls == 0, "match win must not open chance gem continue")
	_expect(win_defeat_settlement_screen.show_calls == 0, "match win must not open defeat settlement")
	_expect(stage_clear_screen.show_calls == 1 and stage_clear_screen.saw_owner and stage_clear_screen.saw_registry, "match win should continue into stage-clear result")
	_expect(stage_clear_screen.saw_reset_callback and stage_clear_screen.saw_exit_callback, "stage-clear result should receive reset and exit callbacks")
	_expect(stage_clear_screen.exit_callback_method == "_exit_to_character_select", "stage-clear result should exit to character select, not the main menu")
	_expect(_reset_game_callback_calls == 0, "stage-clear result should block the full reset fallback while open")
	registry.defeat_continue_screen = null
	registry.stage_clear_result_screen = null

	var settlement_screen := FakeDefeatSettlementScreen.new()
	var final_defeat_owner := FakeOwner.new()
	final_defeat_owner.chance_gems_count = 2
	registry.plaza_save_store = FakeChanceGemStore.new(0)
	registry.defeat_settlement_screen = settlement_screen
	transition_resets_before = controller.stage_transition_reset_calls
	_reset_game_callback_calls = 0
	scoreboard.next_result = ScoreboardState.UPDATE_RESET_GAME
	scoreboard.player_points = 1
	scoreboard.boss_points = 5
	scoreboard.win_goal = 5
	scoreboard.last_scoring_side = "boss"
	driver.update_scoreboard(
		registry,
		2.0,
		Callable(self, "_record_reset_game_callback"),
		Callable(self, "_record_ball_reset"),
		final_defeat_owner,
		Callable(self, "_record_drive_reset")
	)
	_expect(int(final_defeat_owner.chance_gems_count) == 0, "final defeat should mirror store-empty chance gems to the owner")
	_expect(controller.stage_transition_reset_calls == transition_resets_before, "final defeat without gems should not continue reset")
	_expect(settlement_screen.show_calls == 1 and settlement_screen.saw_owner and settlement_screen.saw_registry, "final defeat should open the settlement screen when it is registered")
	_expect(settlement_screen.saw_exit_callback, "final defeat settlement should receive an exit callback")
	_expect(settlement_screen.exit_callback_method == "_exit_to_main_menu", "final defeat settlement should exit to the real main menu")
	_expect(_reset_game_callback_calls == 0, "final defeat settlement should block the full reset callback")

	var flow_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_match_flow_driver.gd")
	_expect(
		flow_source.find("_change_to_scene(owner, \"res://scenes/main_menu.tscn\")") >= 0,
		"final defeat _exit_to_main_menu should target main_menu.tscn"
	)
	_expect(
		flow_source.find("_change_to_scene(owner, \"res://scenes/character_select.tscn\")") >= 0,
		"stage-clear _exit_to_character_select should target character_select.tscn"
	)

	registry.defeat_settlement_screen = null
	registry.plaza_save_store = null
	_reset_game_callback_calls = 0
	driver.update_scoreboard(
		registry,
		2.0,
		Callable(self, "_record_reset_game_callback"),
		Callable(self, "_record_ball_reset"),
		final_defeat_owner,
		Callable(self, "_record_drive_reset")
	)
	_expect(_reset_game_callback_calls == 1, "final defeat without a settlement screen should fall through to the existing reset path")

	var active_item_runtime := FakeStageTransitionActiveItemRuntime.new()
	registry.active_item_runtime = active_item_runtime
	owner.active_item_slots = [{"item_id": "reward_item", "last_use_msec": 45678}]
	transition_resets_before = controller.stage_transition_reset_calls
	drive_resets_before = _drive_reset_calls
	ball_resets_before = _ball_reset_calls
	driver.reset_for_stage_transition(
		owner,
		registry,
		Callable(self, "_record_drive_reset"),
		Callable(self, "_record_ball_reset")
	)
	_expect(controller.stage_transition_reset_calls == transition_resets_before + 1, "stage transition should use the preserving reset path")
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


func _record_reset_game_callback() -> void:
	_reset_game_callback_calls += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
