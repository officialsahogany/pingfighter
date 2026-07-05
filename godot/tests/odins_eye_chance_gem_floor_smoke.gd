extends SceneTree

const MatchFlowDriver := preload("res://scripts/core/battle_scene_match_flow_driver.gd")
const MatchScoreEventController := preload("res://scripts/core/match_score_event_controller.gd")
const ScoreboardState := preload("res://scripts/hud/scoreboard_state.gd")

var _failures: Array[String] = []
var _reset_game_calls := 0
var _reset_ball_calls := 0
var _reset_drive_calls := 0


class FakeOwner:
	extends RefCounted

	var current_stage := 1
	var chance_gems_count := 2
	var chance_gems_max := 3
	var ball_pos := Vector2(340.0, 740.0)
	var ball_pos_prev := Vector2(340.0, 720.0)
	var ball_vel := Vector2(0.0, 12.0)
	var ball_active := true
	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class FakeScoreState:
	extends RefCounted

	var score_calls := 0
	var would_finish := true

	func would_score_finish(_side: String) -> bool:
		return would_finish

	func get_snapshot() -> Dictionary:
		return {
			"player_score": 4,
			"boss_score": 4,
			"win_goal": 5,
			"deuce_mode": false,
		}

	func score_for(side: String) -> Dictionary:
		score_calls += 1
		return {
			"player_score": 4,
			"boss_score": 5 if side == "boss" else 4,
			"match_finished": side == "boss",
			"win_goal": 5,
			"next_player_serves": side == "boss",
		}


class FakeScoreboardState:
	extends RefCounted

	var start_calls := 0
	var player_points := 4
	var boss_points := 4
	var win_goal := 5
	var last_scoring_side := ""
	var last_match_finished := false

	func trigger_top_mini_sparkle() -> void:
		pass

	func start(
		next_player_points: int,
		next_boss_points: int,
		match_finished: bool,
		scoring_side: String,
		next_win_goal: int = 5
	) -> void:
		start_calls += 1
		player_points = next_player_points
		boss_points = next_boss_points
		last_match_finished = match_finished
		last_scoring_side = scoring_side
		win_goal = next_win_goal

	func get_player_points() -> int:
		return player_points

	func get_boss_points() -> int:
		return boss_points

	func get_win_goal() -> int:
		return win_goal

	func get_last_scoring_side() -> String:
		return last_scoring_side


class FakeMythicItemRuntime:
	extends RefCounted

	var odins_eye_revival_active := false
	var foul_whistle_calls := 0
	var revival_calls := 0
	var odins_eye_revival_calls := 0
	var odins_eye_death_calls := 0

	func try_trigger_foul_whistle(_loss_type: String, _deps: Dictionary) -> bool:
		foul_whistle_calls += 1
		return false

	func try_trigger_revival(_loss_type: String, _deps: Dictionary) -> bool:
		revival_calls += 1
		return false

	func is_odins_eye_penalty_active() -> bool:
		return false

	func begin_odins_eye_death_sequence(_loss_type: String) -> bool:
		odins_eye_death_calls += 1
		return false

	func try_trigger_odins_eye_revival(_loss_type: String) -> bool:
		odins_eye_revival_calls += 1
		return odins_eye_revival_active


class FakeChanceGemStore:
	extends RefCounted

	var chance_gems := 2
	var consume_calls := 0
	var get_calls := 0

	func get_chance_gems() -> int:
		get_calls += 1
		return chance_gems

	func get_max_chance_gems() -> int:
		return 3

	func consume_chance_gem() -> int:
		consume_calls += 1
		chance_gems = maxi(0, chance_gems - 1)
		return chance_gems


class FakeContextBuilder:
	extends RefCounted

	func build_match_flow_deps(_registry: Object, _current_stage: int) -> Dictionary:
		return {}


class FakeMatchFlowController:
	extends RefCounted

	var reset_for_continue_calls := 0

	func reset_for_stage_transition(_deps: Dictionary, callbacks: Dictionary = {}) -> Dictionary:
		reset_for_continue_calls += 1
		var reset_drive: Callable = callbacks.get("reset_drive_input", Callable())
		if reset_drive.is_valid():
			reset_drive.call()
		var reset_ball: Callable = callbacks.get("reset_ball", Callable())
		if reset_ball.is_valid():
			reset_ball.call()
		return {}


class FakeContinueScreen:
	extends RefCounted

	var show_calls := 0
	var saw_continue_callback := false
	var saw_consume_callback := false
	var confirm_calls := 0
	var _consume_callback: Callable = Callable()
	var _continue_callback: Callable = Callable()

	func show(_owner: Object, _registry: Object, continue_callback: Callable) -> bool:
		show_calls += 1
		saw_continue_callback = continue_callback.is_valid()
		_continue_callback = continue_callback
		return true

	func show_with_consume(_owner: Object, _registry: Object, continue_callback: Callable, consume_callback: Callable) -> bool:
		show_calls += 1
		saw_continue_callback = continue_callback.is_valid()
		saw_consume_callback = consume_callback.is_valid()
		_consume_callback = consume_callback
		_continue_callback = continue_callback
		return true

	func confirm_continue() -> void:
		confirm_calls += 1
		if _consume_callback.is_valid():
			_consume_callback.call()
		if _continue_callback.is_valid():
			_continue_callback.call()

	func clear_callbacks() -> void:
		_consume_callback = Callable()
		_continue_callback = Callable()


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_odins_eye_revive_is_free_then_death_finalize_consumes_one_gem()
	await _drain_frames(12)

	if _failures.is_empty():
		print("odins_eye_chance_gem_floor_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_odins_eye_revive_is_free_then_death_finalize_consumes_one_gem() -> void:
	var owner := FakeOwner.new()
	var score_state := FakeScoreState.new()
	var scoreboard_state := FakeScoreboardState.new()
	var mythic_runtime := FakeMythicItemRuntime.new()
	var chance_store := FakeChanceGemStore.new()
	var context_builder := FakeContextBuilder.new()
	var match_flow_controller := FakeMatchFlowController.new()
	var continue_screen := FakeContinueScreen.new()
	var registry := FakeRegistry.new({
		"scoreboard_state": scoreboard_state,
		"plaza_save_store": chance_store,
		"defeat_chance_gems_continue_screen": continue_screen,
		"battle_update_context": context_builder,
		"match_flow_controller": match_flow_controller,
	})
	var deps := {
		"owner": owner,
		"registry": registry,
		"score_state": score_state,
		"scoreboard_state": scoreboard_state,
		"mythic_item_runtime": mythic_runtime,
	}
	var score_controller := MatchScoreEventController.new()
	var flow_driver := MatchFlowDriver.new()

	mythic_runtime.odins_eye_revival_active = true
	score_controller.handle_score_event("boss", deps, {})

	_expect(mythic_runtime.odins_eye_revival_calls == 1, "Odin revive should be queried on the lethal boss score")
	_expect(score_state.score_calls == 0, "Odin revive should early-return before committing the lethal score")
	_expect(scoreboard_state.start_calls == 0, "Odin revive should not start a defeat scoreboard")
	_expect(chance_store.consume_calls == 0 and chance_store.chance_gems == 2, "Odin revive should not consume a chance gem")
	_expect(not owner.ball_active and owner.ball_pos == Vector2(-100.0, -100.0), "Odin revive should hide the ball while the revival sequence plays")

	mythic_runtime.odins_eye_revival_active = false
	deps["odins_eye_death_finalize_score"] = true
	score_controller.handle_score_event("boss", deps, {})

	_expect(score_state.score_calls == 1, "Odin death finalize should commit the terminal boss score")
	_expect(scoreboard_state.start_calls == 1, "Odin death finalize should start the scoreboard once")
	_expect(scoreboard_state.last_match_finished, "Odin death finalize should produce a finished match")
	_expect(scoreboard_state.get_boss_points() == 5 and scoreboard_state.get_last_scoring_side() == "boss", "Odin death finalize should expose a boss-scored defeat to match flow")
	_expect(chance_store.consume_calls == 0 and chance_store.chance_gems == 2, "score commit alone should not consume a chance gem before match-flow resolves defeat")

	flow_driver.apply_scoreboard_update_result(
		ScoreboardState.UPDATE_RESET_GAME,
		registry,
		owner,
		Callable(self, "_record_reset_game"),
		Callable(self, "_record_reset_ball"),
		Callable(self, "_record_reset_drive")
	)

	_expect(chance_store.get_calls > 0, "match-flow defeat resolver should read the persisted chance gem count")
	_expect(chance_store.consume_calls == 0 and chance_store.chance_gems == 2, "Odin death finalize should not consume a chance gem before the continue confirmation")
	_expect(owner.chance_gems_count == 2 and owner.chance_gems_max == 3, "defeat resolver should mirror the pre-confirm chance gem count to the owner")
	_expect(continue_screen.show_calls == 1 and continue_screen.saw_continue_callback and continue_screen.saw_consume_callback, "Odin death finalize should open the chance-gem continue screen with consume and continue callbacks")
	_expect(_reset_game_calls == 0, "Odin death finalize continue path must not fall through to the full reset callback")
	_expect(_reset_ball_calls == 0 and _reset_drive_calls == 0, "continue reset should wait for the player confirmation")

	continue_screen.confirm_continue()
	_expect(continue_screen.confirm_calls == 1, "test setup should confirm the chance gem continue screen once")
	_expect(chance_store.consume_calls == 1 and chance_store.chance_gems == 1, "Odin continue confirmation should consume exactly one chance gem")
	_expect(owner.chance_gems_count == 1 and owner.chance_gems_max == 3, "continue confirmation should mirror the remaining chance gem count to the owner")
	_expect(match_flow_controller.reset_for_continue_calls == 1, "Odin continue confirmation should enter the preserving continue reset once")
	_expect(_reset_game_calls == 0, "Odin continue confirmation must not call the full reset callback")
	_expect(_reset_ball_calls == 1 and _reset_drive_calls == 1, "Odin continue confirmation should run the preserving reset callbacks once")
	continue_screen.clear_callbacks()
	registry.instances.clear()
	deps.clear()


func _drain_frames(frame_count: int) -> void:
	for _i in range(frame_count):
		await process_frame


func _record_reset_game() -> void:
	_reset_game_calls += 1


func _record_reset_ball() -> void:
	_reset_ball_calls += 1


func _record_reset_drive() -> void:
	_reset_drive_calls += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
