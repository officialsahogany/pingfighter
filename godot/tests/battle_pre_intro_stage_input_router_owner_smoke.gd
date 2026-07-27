extends SceneTree

# expect-zero-object-leaks
const BattlePreIntroStageInputRouter := preload(
	"res://scripts/core/battle_pre_intro_stage_input_router.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1


class FakeScoreState:
	extends RefCounted

	var force_calls: Array[Vector2i] = []

	func force_score(player_score: int, boss_score: int) -> void:
		force_calls.append(Vector2i(player_score, boss_score))


class FakeScoreboardState:
	extends RefCounted

	var start_calls: Array[Array] = []

	func start(
		player_score: int,
		boss_score: int,
		pending_reset: bool,
		last_scoring_side: String
	) -> void:
		start_calls.append([
			player_score,
			boss_score,
			pending_reset,
			last_scoring_side,
		])


class FakeResultScreen:
	extends RefCounted

	var active := false
	var show_count := 0
	var last_owner: Object = null
	var last_registry: Object = null
	var saw_reset_callback := false
	var saw_exit_callback := false

	func is_active() -> bool:
		return active

	func show_from_scoreboard(
		owner: Object,
		registry: Object,
		reset_callback: Callable,
		exit_callback: Callable
	) -> void:
		show_count += 1
		last_owner = owner
		last_registry = registry
		saw_reset_callback = reset_callback.is_valid()
		saw_exit_callback = exit_callback.is_valid()


class FakePresentation:
	extends RefCounted

	var active := false
	var accept_input := true
	var handle_count := 0

	func is_active() -> bool:
		return active

	func handle_input(
		_event: InputEvent,
		_owner: Object,
		_registry: Object
	) -> bool:
		handle_count += 1
		return accept_input


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		return value as Object if value is Object else null


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value as Object if value is Object else null


class CallbackProbe:
	extends RefCounted

	func reset_game() -> void:
		pass

	func exit_to_menu() -> void:
		pass


func _init() -> void:
	_verify_f9_has_priority_over_stage7_video()
	_verify_active_result_consumes_f9_without_reopening()
	_verify_invalid_f9_falls_through_to_stage7_video()
	_verify_stage7_consumption_and_success_redraw()
	_verify_source_ownership_and_order()
	call_deferred("_finish")


func _finish() -> void:
	if _failures.is_empty():
		print("battle_pre_intro_stage_input_router_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_f9_has_priority_over_stage7_video() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var registry: FakeRegistry = fixture["registry"]
	var score: FakeScoreState = fixture["score"]
	var scoreboard: FakeScoreboardState = fixture["scoreboard"]
	var result: FakeResultScreen = fixture["result"]
	var presentation: FakePresentation = fixture["presentation"]
	var probe: CallbackProbe = fixture["probe"]
	var owner := FakeOwner.new()
	presentation.active = true
	_expect(
		BattlePreIntroStageInputRouter.new().handle_input(
			_key_event(KEY_F9),
			owner,
			registry,
			Callable(holder, "get_module"),
			_ready_context(probe)
		),
		"ready F9 must consume before Stage 7 video input"
	)
	_expect(score.force_calls == [Vector2i(5, 0)], "F9 must force the 5:0 player score")
	_expect(scoreboard.start_calls == [[5, 0, true, "player"]], "F9 must create the player-win scoreboard snapshot")
	_expect(result.show_count == 1, "F9 must open the stage-clear result once")
	_expect(result.last_owner == owner and result.last_registry == registry, "F9 result must receive live owner and registry")
	_expect(result.saw_reset_callback and result.saw_exit_callback, "F9 result must preserve both completion callbacks")
	_expect(presentation.handle_count == 0, "ready F9 must stop Stage 7 input routing")
	_expect(owner.redraw_count == 1, "successful F9 route must redraw once")
	_clear_fixture(fixture)


func _verify_active_result_consumes_f9_without_reopening() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var registry: FakeRegistry = fixture["registry"]
	var score: FakeScoreState = fixture["score"]
	var scoreboard: FakeScoreboardState = fixture["scoreboard"]
	var result: FakeResultScreen = fixture["result"]
	var probe: CallbackProbe = fixture["probe"]
	var owner := FakeOwner.new()
	result.active = true
	_expect(
		BattlePreIntroStageInputRouter.new().handle_input(
			_key_event(KEY_F9), owner, registry, Callable(holder, "get_module"), _ready_context(probe)
		),
		"active result screen must swallow repeated F9"
	)
	_expect(score.force_calls.is_empty() and scoreboard.start_calls.is_empty(), "repeated F9 must not rewrite score state")
	_expect(result.show_count == 0, "repeated F9 must not reopen the active result")
	_expect(owner.redraw_count == 0, "active-result F9 swallow must preserve no-redraw behavior")
	_clear_fixture(fixture)


func _verify_invalid_f9_falls_through_to_stage7_video() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var registry: FakeRegistry = fixture["registry"]
	var presentation: FakePresentation = fixture["presentation"]
	var owner := FakeOwner.new()
	presentation.active = true
	_expect(
		BattlePreIntroStageInputRouter.new().handle_input(
			_key_event(KEY_F9), owner, registry, Callable(holder, "get_module"), {}
		),
		"not-ready F9 must fall through to active Stage 7 video"
	)
	_expect(presentation.handle_count == 1, "Stage 7 presentation must receive not-ready F9 fallthrough")
	_expect(owner.redraw_count == 1, "accepted Stage 7 fallthrough must redraw once")
	_clear_fixture(fixture)


func _verify_stage7_consumption_and_success_redraw() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var registry: FakeRegistry = fixture["registry"]
	var presentation: FakePresentation = fixture["presentation"]
	var owner := FakeOwner.new()
	presentation.active = true
	presentation.accept_input = false
	_expect(
		BattlePreIntroStageInputRouter.new().handle_input(
			_key_event(KEY_SPACE), owner, registry, Callable(holder, "get_module"), {}
		),
		"active Stage 7 video must consume even when local input is ignored"
	)
	_expect(owner.redraw_count == 0, "ignored Stage 7 local input must not redraw")
	presentation.accept_input = true
	_expect(
		BattlePreIntroStageInputRouter.new().handle_input(
			_key_event(KEY_SPACE), owner, registry, Callable(holder, "get_module"), {}
		),
		"accepted Stage 7 skip must consume"
	)
	_expect(owner.redraw_count == 1, "accepted Stage 7 skip must redraw once")
	_clear_fixture(fixture)


func _verify_source_ownership_and_order() -> void:
	var router_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_pre_intro_stage_input_router.gd"
	)
	var input_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_input_controller.gd"
	)
	_expect(router_source.find("_handle_force_stage_clear_shortcut") < router_source.find("_handle_stage7_prebattle_input"), "F9 force-clear must precede Stage 7 video input")
	_expect(router_source.contains("FORCE_STAGE_CLEAR_PLAYER_SCORE := 5"), "stage router must own the debug player score")
	_expect(router_source.contains("show_from_scoreboard"), "stage router must own result-screen debug handoff")
	_expect(router_source.contains("stage7_akamu_prebattle_presentation"), "stage router must own Stage 7 presentation resolution")
	_expect(input_source.contains("BattlePreIntroStageInputRouter.new()"), "scene input controller must compose pre-intro stage router")
	_expect(input_source.contains("_pre_intro_stage_input_router.handle_input("), "scene input controller must delegate pre-intro stage input once")
	_expect(input_source.find("_is_stage_transition_loading_active(") < input_source.find("_pre_intro_stage_input_router.handle_input("), "transition loading must stay above pre-intro stage input")
	_expect(input_source.find("_pre_intro_stage_input_router.handle_input(") < input_source.find("_is_intro_or_warmup_blocking("), "pre-intro stage input must stay above readiness blocking")
	_expect(not input_source.contains("func _handle_force_stage_clear_shortcut"), "scene input controller must not retain F9 policy")
	_expect(not input_source.contains("func _handle_stage7_prebattle_input"), "scene input controller must not retain Stage 7 input policy")
	_expect(not input_source.contains("func _force_player_stage_clear_score"), "scene input controller must not retain debug score mutation")
	_expect(not input_source.contains("func _start_debug_scoreboard_snapshot"), "scene input controller must not retain debug scoreboard mutation")


func _build_fixture() -> Dictionary:
	var holder := ModuleHolder.new()
	var registry := FakeRegistry.new()
	var score := FakeScoreState.new()
	var scoreboard := FakeScoreboardState.new()
	var result := FakeResultScreen.new()
	var presentation := FakePresentation.new()
	var probe := CallbackProbe.new()
	holder.modules = {
		"match_score_state": score,
		"scoreboard_state": scoreboard,
		"stage_clear_result_screen": result,
		"stage7_akamu_prebattle_presentation": presentation,
	}
	return {
		"holder": holder,
		"registry": registry,
		"score": score,
		"scoreboard": scoreboard,
		"result": result,
		"presentation": presentation,
		"probe": probe,
	}


func _ready_context(probe: CallbackProbe) -> Dictionary:
	return {
		"battle_initialized": true,
		"stage_landing_intro_started": true,
		"reset_game_after_stage_clear": Callable(probe, "reset_game"),
		"exit_to_menu_after_stage_clear": Callable(probe, "exit_to_menu"),
	}


func _clear_fixture(fixture: Dictionary) -> void:
	var holder: ModuleHolder = fixture["holder"]
	holder.modules.clear()
	var registry: FakeRegistry = fixture["registry"]
	registry.instances.clear()
	fixture.clear()


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
