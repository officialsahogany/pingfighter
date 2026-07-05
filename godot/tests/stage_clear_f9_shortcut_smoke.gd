extends SceneTree

const BattleSceneInputController := preload("res://scripts/core/battle_scene_input_controller.gd")
const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const ScoreboardState := preload("res://scripts/hud/scoreboard_state.gd")
const StageClearResultFinishFlowHandler := preload("res://scripts/core/stage_clear_result_finish_flow_handler.gd")
const StageClearResultScreen := preload("res://scripts/core/stage_clear_result_screen.gd")
const StageClearResultConfigSceneHandler := preload("res://scripts/ui/stage_clear_result_config_scene_handler.gd")
const PlazaScene := preload("res://scripts/plaza/plaza_scene.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


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


var registry := FakeRegistry.new()
var reset_calls := 0
var exit_calls := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_f9_forces_player_stage_clear()
	await _verify_f9_exit_to_menu_from_visible_scroll()
	await _verify_f9_is_blocked_during_stage_transition_loading()
	registry = null
	StageClearResultConfigSceneHandler.reset_prewarm_assets_for_test()
	PlazaScene.reset_prewarm_assets_for_test()
	ProjectResourceLoader.clear_caches()
	for _i in range(20):
		await process_frame
	print("stage_clear_f9_shortcut_smoke: ok")
	call_deferred("_quit_success")


func _quit_success() -> void:
	quit(0)


func _verify_f9_forces_player_stage_clear() -> void:
	registry = FakeRegistry.new()
	var owner := FakeOwner.new()
	var input := BattleSceneInputController.new()
	reset_calls = 0
	exit_calls = 0
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
			"reset_game_after_stage_clear": Callable(self, "_reset_game"),
			"exit_to_menu_after_stage_clear": Callable(self, "_exit_to_menu"),
		}
	)

	var score_snapshot: Dictionary = registry.score_state.get_snapshot()
	_expect(int(score_snapshot.get("player_score", 0)) == 5, "F9 should force the player score to 5")
	_expect(int(score_snapshot.get("boss_score", 0)) == 0, "F9 should force the boss score to 0")
	_expect(registry.scoreboard_state.is_active(), "F9 should leave a player-win scoreboard snapshot for reset flow")
	_expect(registry.scoreboard_state.has_pending_game_reset(), "F9 scoreboard snapshot should request game reset")
	_expect(registry.scoreboard_state.get_last_scoring_side() == "player", "F9 should mark the player as the winning scorer")
	_expect(registry.result_screen.is_active(), "F9 should open the stage-clear result screen")
	var result_status: Dictionary = registry.result_screen.get_status()
	_expect(bool(result_status.get("spawn_pending", false)), "F9 result screen should stage the heavy result scene instead of blocking input")

	var box_count: int = int(registry.result_screen.get_reward_plan().get("reward_count", 0))
	_expect(box_count > 0, "F9 5:0 plan should include at least one reward box")
	_finish_result_screen(StageClearResultFinishFlowHandler.ACTION_NEXT_STAGE)
	_expect(reset_calls == 1, "F9 result screen should keep the provided reset callback")
	event = null
	input = null
	await _cleanup_owner(owner)


func _verify_f9_exit_to_menu_from_visible_scroll() -> void:
	registry = FakeRegistry.new()
	var owner := FakeOwner.new()
	var input := BattleSceneInputController.new()
	reset_calls = 0
	exit_calls = 0
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
			"reset_game_after_stage_clear": Callable(self, "_reset_game"),
			"exit_to_menu_after_stage_clear": Callable(self, "_exit_to_menu"),
		}
	)
	var box_count: int = int(registry.result_screen.get_reward_plan().get("reward_count", 0))
	_expect(box_count > 0, "F9 5:0 plan should include at least one reward box before exit")
	_finish_result_screen(StageClearResultFinishFlowHandler.ACTION_EXIT_TO_MENU)
	_expect(exit_calls == 1, "F9 result screen should keep the provided exit callback")
	_expect(reset_calls == 0, "F9 exit callback path must not reset the game")
	event = null
	input = null
	await _cleanup_owner(owner)


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
	event = null
	input = null
	await _cleanup_owner(owner)


func _get_module(key: String) -> Object:
	return registry.get_instance(key)


func _finish_result_screen(action: String) -> void:
	var screen: Object = registry.result_screen
	var finish_handler: Object = screen.get("_finish_flow_handler")
	var scene_shell_handler: Object = screen.get("_scene_shell_handler")
	finish_handler.finish_action_from_screen(
		action,
		screen,
		Callable(scene_shell_handler, "free_screen_result_scene").bind(screen)
	)


func _reset_game() -> void:
	reset_calls += 1


func _exit_to_menu() -> void:
	exit_calls += 1


func _cleanup_owner(owner: Node) -> void:
	if registry != null and registry.result_screen != null and registry.result_screen.has_method("reset"):
		registry.result_screen.reset()
		for _i in range(4):
			await process_frame
	if owner != null and is_instance_valid(owner):
		owner.free()
	if registry != null:
		registry.score_state = null
		registry.scoreboard_state = null
		registry.result_screen = null
		registry.stage_transition_driver = null
	registry = null
	StageClearResultConfigSceneHandler.reset_prewarm_assets_for_test()
	PlazaScene.reset_prewarm_assets_for_test()
	ProjectResourceLoader.clear_caches()
	for _i in range(20):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
