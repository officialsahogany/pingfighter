extends SceneTree

# Verifies the ExhibitionResetHandler autoload owns the F10 booth-reset hotkey,
# tears down any volatile match state on the autoload's `GameSelectionState`
# dependency, and never collides with the battle scene input controller's
# remaining debug-key matrix.

const ExhibitionResetHandler := preload("res://scripts/core/exhibition_reset_handler.gd")
const BattleSceneOverlayInputController := preload("res://scripts/core/battle_scene_overlay_input_controller.gd")

var _failures: Array[String] = []


class FakeSelectionState:
	extends Node

	var stage_id: int = 7
	var league_mode: String = "mythic"
	var skip_battle_logo_once := true
	var stage_calls: int = 0
	var league_calls: int = 0

	func set_stage(stage: int) -> void:
		stage_id = stage
		stage_calls += 1

	func set_league_mode(mode: String) -> void:
		league_mode = mode
		league_calls += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_autoload_consts()
	_verify_event_filter()
	_verify_game_selection_reset_runs()
	_verify_resetting_lock_blocks_reentry()
	_verify_battle_input_controller_no_longer_owns_reset_key()

	await process_frame
	if _failures.is_empty():
		print("exhibition_reset_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_autoload_consts() -> void:
	_expect(ExhibitionResetHandler.RESET_KEY == KEY_F10, "ExhibitionResetHandler should own KEY_F10 as the booth reset hotkey")
	_expect(
		String(ExhibitionResetHandler.TITLE_SCENE_PATH) == "res://scenes/main_menu.tscn",
		"ExhibitionResetHandler should target main_menu.tscn as the title reset destination"
	)
	_expect(
		String(ExhibitionResetHandler.DEFAULT_LEAGUE_MODE) == "junior",
		"ExhibitionResetHandler should reset booth sessions to Junior League"
	)


func _verify_event_filter() -> void:
	var handler := _make_handler()
	_expect(handler.is_exhibition_reset_event(_key_event(KEY_F10, KEY_F10, true, false)), "pressed F10 should request exhibition reset")
	_expect(handler.is_exhibition_reset_event(_key_event(KEY_UNKNOWN, KEY_F10, true, false)), "physical F10 should request exhibition reset")
	_expect(not handler.is_exhibition_reset_event(_key_event(KEY_F10, KEY_F10, false, false)), "released F10 should not request exhibition reset")
	_expect(not handler.is_exhibition_reset_event(_key_event(KEY_F10, KEY_F10, true, true)), "echo F10 should not repeat exhibition reset")
	_expect(not handler.is_exhibition_reset_event(_key_event(KEY_F7, KEY_F7, true, false)), "F7 should remain available for the lingpet debug picker")
	_expect(not handler.is_exhibition_reset_event(_key_event(KEY_F8, KEY_F8, true, false)), "F8 should remain available for runtime perk debug")
	handler.queue_free()


func _verify_game_selection_reset_runs() -> void:
	var handler := _make_handler()
	var selection_state := FakeSelectionState.new()
	# Inject the fake selection state directly so the smoke does not need to
	# bind the autoload to the live SceneTree root (and accidentally trigger a
	# real change_scene during the test run).
	handler._reset_game_selection_state_for_test(selection_state)
	_expect(selection_state.stage_calls == 1, "exhibition reset should reset stage_id exactly once per press")
	_expect(selection_state.league_calls == 1, "exhibition reset should reset league_mode exactly once per press")
	_expect(selection_state.stage_id == ExhibitionResetHandler.DEFAULT_STAGE_ID, "exhibition reset should rewind stage_id to the default")
	_expect(selection_state.league_mode == ExhibitionResetHandler.DEFAULT_LEAGUE_MODE, "exhibition reset should rewind league_mode to the default")
	_expect(not selection_state.skip_battle_logo_once, "exhibition reset should clear one-shot battle-logo skip state")
	selection_state.free()
	handler.queue_free()


func _verify_resetting_lock_blocks_reentry() -> void:
	var handler := _make_handler()
	handler._begin_reset_lock_for_test()
	_expect(handler.is_resetting(), "is_resetting() should report true while the reset lock is held")
	_expect(not handler.request_reset(), "request_reset() should refuse re-entry while the lock is held")
	handler._clear_resetting_lock()
	_expect(not handler.is_resetting(), "is_resetting() should clear after the lock is released")
	handler.queue_free()


func _verify_battle_input_controller_no_longer_owns_reset_key() -> void:
	# The booth reset key (F10) MUST NOT also be claimed by the battle overlay
	# input controller, or pressing F10 in-battle would race a stale debug toggle
	# against the autoload. The lingpet debug picker now lives on F7.
	_expect(
		BattleSceneOverlayInputController.LINGPET_DEBUG_KEY == KEY_F7,
		"battle overlay input should bind the lingpet debug picker to F7"
	)
	_expect(
		BattleSceneOverlayInputController.LINGPET_DEBUG_KEY != ExhibitionResetHandler.RESET_KEY,
		"battle overlay input must not bind any debug key to the booth reset key (F10)"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _make_handler() -> Node:
	var handler := ExhibitionResetHandler.new()
	get_root().add_child(handler)
	return handler


func _key_event(keycode: Key, physical_keycode: Key, pressed: bool, echo: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = physical_keycode
	event.pressed = pressed
	event.echo = echo
	return event
