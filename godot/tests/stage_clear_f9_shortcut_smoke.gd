extends SceneTree

const BattleSceneInputController := preload("res://scripts/core/battle_scene_input_controller.gd")
const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const ScoreboardState := preload("res://scripts/hud/scoreboard_state.gd")
const StageClearResultScreen := preload("res://scripts/core/stage_clear_result_screen.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")
const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")


class FakeOwner:
	extends Node

	var current_stage := 1


class FakeStageTransitionDriver:
	extends RefCounted

	var active := false

	func is_stage_transition_loading_active() -> bool:
		return active


class FakeRegistry:
	extends RefCounted

	var score_state: Object = MatchScoreState.new()
	var scoreboard_state: Object = ScoreboardState.new()
	var result_screen: Object = StageClearResultScreen.new()
	var stage_transition_driver: Object = FakeStageTransitionDriver.new()

	func get_instance(key: String) -> Object:
		match key:
			"match_score_state":
				return score_state
			"scoreboard_state":
				return scoreboard_state
			"stage_clear_result_screen":
				return result_screen
			"battle_scene_match_event_driver":
				return stage_transition_driver
		return null


class ResetSink:
	extends RefCounted

	var reset_calls := 0
	var exit_calls := 0

	func reset_game() -> void:
		reset_calls += 1

	func exit_to_menu() -> void:
		exit_calls += 1


var registry := FakeRegistry.new()


func _init() -> void:
	_verify_f9_forces_player_stage_clear()
	_verify_f9_exit_to_menu_from_visible_scroll()
	_verify_f9_is_blocked_during_stage_transition_loading()
	print("stage_clear_f9_shortcut_smoke: ok")
	quit(0)


func _verify_f9_forces_player_stage_clear() -> void:
	registry = FakeRegistry.new()
	var owner := FakeOwner.new()
	var input := BattleSceneInputController.new()
	var sink := ResetSink.new()
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_F9
	event.physical_keycode = KEY_F9

	input.handle_unhandled_input(
		event,
		owner,
		registry,
		Callable(self, "_get_module"),
		{
			"battle_initialized": true,
			"stage_landing_intro_started": true,
			"mobile_touch_scene_ready": false,
			"reset_game_after_stage_clear": Callable(sink, "reset_game"),
			"exit_to_menu_after_stage_clear": Callable(sink, "exit_to_menu"),
		}
	)

	var score_snapshot: Dictionary = registry.score_state.get_snapshot()
	_expect(int(score_snapshot.get("player_score", 0)) == 5, "F9 should force the player score to 5")
	_expect(int(score_snapshot.get("boss_score", 0)) == 0, "F9 should force the boss score to 0")
	_expect(registry.scoreboard_state.is_active(), "F9 should leave a player-win scoreboard snapshot for reset flow")
	_expect(registry.scoreboard_state.has_pending_game_reset(), "F9 scoreboard snapshot should request game reset")
	_expect(registry.scoreboard_state.get_last_scoring_side() == "player", "F9 should mark the player as the winning scorer")
	_expect(registry.result_screen.is_active(), "F9 should open the stage-clear result screen")
	_ensure_result_scene_spawned(owner)
	_expect(owner.get_child_count() == 1, "F9 should attach the result scene to the battle owner")

	var enter_event := InputEventKey.new()
	enter_event.pressed = true
	enter_event.keycode = KEY_ENTER
	enter_event.physical_keycode = KEY_ENTER

	var box_count: int = int(registry.result_screen.get_reward_plan().get("reward_count", 0))
	_expect(box_count > 0, "F9 5:0 plan should include at least one reward box")
	for _i in range(box_count):
		_expect(
			registry.result_screen.handle_input(enter_event, owner, registry, Vector2(1920.0, 1080.0)),
			"Enter during box phase should be consumed (advance opens next box)"
		)
	_expect(sink.reset_calls == 0, "Enter during box phase must not yet reset the game")

	for _i in range(80):
		registry.result_screen.update(0.05)

	_expect(
		registry.result_screen.handle_input(enter_event, owner, registry, Vector2(1920.0, 1080.0)),
		"Enter on visible scroll should be consumed"
	)
	_expect(sink.reset_calls == 1, "Enter on visible scroll should invoke the provided reset callback once")
	owner.free()


func _verify_f9_exit_to_menu_from_visible_scroll() -> void:
	registry = FakeRegistry.new()
	var owner := FakeOwner.new()
	var input := BattleSceneInputController.new()
	var sink := ResetSink.new()
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_F9
	event.physical_keycode = KEY_F9

	input.handle_unhandled_input(
		event,
		owner,
		registry,
		Callable(self, "_get_module"),
		{
			"battle_initialized": true,
			"stage_landing_intro_started": true,
			"mobile_touch_scene_ready": false,
			"reset_game_after_stage_clear": Callable(sink, "reset_game"),
			"exit_to_menu_after_stage_clear": Callable(sink, "exit_to_menu"),
		}
	)
	_ensure_result_scene_spawned(owner)

	var enter_event := InputEventKey.new()
	enter_event.pressed = true
	enter_event.keycode = KEY_ENTER
	enter_event.physical_keycode = KEY_ENTER
	var box_count: int = int(registry.result_screen.get_reward_plan().get("reward_count", 0))
	for _i in range(box_count):
		registry.result_screen.handle_input(enter_event, owner, registry, Vector2(1920.0, 1080.0))
	for _i in range(80):
		registry.result_screen.update(0.05)

	var escape_event := InputEventKey.new()
	escape_event.pressed = true
	escape_event.keycode = KEY_ESCAPE
	escape_event.physical_keycode = KEY_ESCAPE
	_expect(
		registry.result_screen.handle_input(escape_event, owner, registry, Vector2(1920.0, 1080.0)),
		"ESC on a debug-opened visible scroll should be consumed"
	)
	_expect(sink.exit_calls == 1, "ESC on a debug-opened visible scroll should invoke the exit callback once")
	_expect(sink.reset_calls == 0, "ESC on a debug-opened visible scroll must not reset the game")
	owner.free()


func _verify_f9_is_blocked_during_stage_transition_loading() -> void:
	registry = FakeRegistry.new()
	registry.stage_transition_driver.set("active", true)
	var owner := FakeOwner.new()
	var input := BattleSceneInputController.new()
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_F9
	event.physical_keycode = KEY_F9

	input.handle_unhandled_input(
		event,
		owner,
		registry,
		Callable(self, "_get_module"),
		{
			"battle_initialized": true,
			"stage_landing_intro_started": true,
			"mobile_touch_scene_ready": true,
		}
	)

	var score_snapshot: Dictionary = registry.score_state.get_snapshot()
	_expect(int(score_snapshot.get("player_score", 0)) == 0, "F9 should not force score during stage-transition loading")
	_expect(not registry.scoreboard_state.is_active(), "stage-transition loading should block debug scoreboard snapshots")
	_expect(not registry.result_screen.is_active(), "stage-transition loading should block opening the result screen")
	owner.free()


func _get_module(key: String) -> Object:
	return registry.get_instance(key)


func _ensure_result_scene_spawned(owner: Node) -> void:
	var max_steps: int = StageClearResultAssetLoader.PREWARM_ASSET_STEP_COUNT + 4
	for _i in range(max_steps):
		if owner.get_child_count() > 0:
			return
		registry.result_screen.update(0.016)
	_expect(owner.get_child_count() > 0, "stage-clear debug result scene should attach after staged prewarm")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
