extends SceneTree

const MainMenuStartTransitionState := preload("res://scripts/ui/main_menu_start_transition_state.gd")

var failure_count: int = 0


func _init() -> void:
	_verify_main_menu_typed_collaborators()
	var state := MainMenuStartTransitionState.new(1.0)
	_expect(not state.active, "transition clock should start inactive")
	_expect(is_equal_approx(state.get_progress(), 0.0), "transition clock should start at zero progress")

	state.begin()
	_expect(state.active, "begin should activate the transition clock")
	_expect(not state.advance(-0.5), "negative delta should not complete the transition")
	_expect(is_equal_approx(state.get_progress(), 0.0), "negative delta should not rewind or advance progress")
	_expect(not state.advance(0.4), "partial advance should not emit the completion edge")
	_expect(is_equal_approx(state.get_progress(), 0.4), "partial advance should expose normalized progress")
	_expect(state.advance(0.8), "crossing the duration should emit one completion edge")
	_expect(not state.active, "completion should deactivate the transition clock")
	_expect(is_equal_approx(state.get_progress(), 1.0), "completion should clamp progress to one")
	_expect(not state.advance(1.0), "inactive updates should not repeat the completion edge")

	state.begin()
	state.advance(0.25)
	state.cancel()
	_expect(not state.active, "cancel should deactivate the transition clock")
	_expect(is_equal_approx(state.get_progress(), 0.0), "cancel should reset progress")

	var minimum_duration_state := MainMenuStartTransitionState.new(0.0)
	minimum_duration_state.begin()
	_expect(minimum_duration_state.advance(0.001), "zero configuration should clamp to a safe minimum duration")

	if failure_count > 0:
		quit(1)
		return
	print("main_menu_start_transition_state_smoke: ok")
	quit(0)


func _verify_main_menu_typed_collaborators() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/main_menu_scene.gd")
	_expect(source.find("var start_transition_state: MainMenuStartTransitionState") >= 0, "main menu should type its transition state")
	_expect(source.find("var touch_start_prompt: MainMenuTouchStartPrompt") >= 0, "main menu should type its touch prompt")
	_expect(source.find("var character_select_prewarm: CharacterSelectPrewarm") >= 0, "main menu should type its character-select prewarm")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
