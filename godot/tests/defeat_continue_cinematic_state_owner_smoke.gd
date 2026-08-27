extends SceneTree

# expect-zero-object-leaks
const STATE_PATH := "res://scripts/core/defeat_continue_cinematic_state.gd"
const SCREEN_PATH := "res://scripts/core/defeat_chance_gems_continue_screen.gd"

const EVENT_NONE := 0
const EVENT_CONSUME_REQUEST := 1
const EVENT_SHATTER_SFX := 2
const EVENT_CONTINUE_RESET := 4

var _failures: Array[String] = []


func _init() -> void:
	_verify_source_ownership()
	if FileAccess.file_exists(STATE_PATH):
		_verify_event_timeline()
		_verify_large_delta_guard()
	if _failures.is_empty():
		print("defeat_continue_cinematic_state_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_source_ownership() -> void:
	_expect(FileAccess.file_exists(STATE_PATH), "cinematic state module must exist")
	var state_source := FileAccess.get_file_as_string(STATE_PATH)
	var screen_source := FileAccess.get_file_as_string(SCREEN_PATH)
	_expect(state_source.contains("EVENT_CONSUME_REQUEST"), "cinematic state must expose the one-shot consume event")
	_expect(state_source.contains("EVENT_SHATTER_SFX"), "cinematic state must expose the one-shot shatter-sfx event")
	_expect(state_source.contains("EVENT_CONTINUE_RESET"), "cinematic state must expose the one-shot hidden-reset event")
	_expect(state_source.contains("func begin_consuming"), "cinematic state must own the PRESENT-to-CONSUMING transition")
	_expect(state_source.contains("func advance"), "cinematic state must own confirm-clock advancement")
	_expect(state_source.contains("func should_update_revival"), "cinematic state must preserve the reset-frame revival-tick guard")
	_expect(state_source.contains("func should_close"), "cinematic state must own fadeback completion policy")
	_expect(not state_source.contains("Dictionary"), "cinematic state must not allocate event dictionaries")
	_expect(not state_source.contains("Callable"), "cinematic state must not own gameplay callbacks")
	_expect(not state_source.contains("Node"), "cinematic state must remain tree-independent")
	_expect(not state_source.contains("func _process"), "cinematic state must remain caller-clocked")
	_expect(screen_source.contains("DefeatContinueCinematicState"), "continue screen must compose the cinematic state owner")
	_expect(not screen_source.contains("enum ContinuePhase"), "continue screen must not retain the phase enum")
	_expect(not screen_source.contains("var _consume_fired"), "continue screen must not retain the consume one-shot flag")
	_expect(not screen_source.contains("var _continue_reset_fired"), "continue screen must not retain the reset one-shot flag")
	_expect(not screen_source.contains("var _shatter_sfx_fired"), "continue screen must not retain the shatter-sfx one-shot flag")
	_expect(not screen_source.contains("func _fire_consume_once"), "continue screen must consume only emitted state events")
	_expect(not screen_source.contains("func _fire_shatter_sfx_if_ready"), "continue screen must not poll its own shatter one-shot")
	_expect(not screen_source.contains("func _fire_continue_reset_if_ready"), "continue screen must not poll its own reset one-shot")
	_expect(screen_source.contains("_cinematic_state.advance"), "continue screen must advance the focused state")
	_expect(screen_source.contains("EVENT_CONSUME_REQUEST"), "continue screen must execute the emitted consume request")
	_expect(screen_source.contains("EVENT_SHATTER_SFX"), "continue screen must execute the emitted shatter sound")
	_expect(screen_source.contains("EVENT_CONTINUE_RESET"), "continue screen must execute the emitted hidden reset")


func _verify_event_timeline() -> void:
	var state := _new_state()
	if state == null:
		return
	state.reset(2)
	_expect(not state.is_consuming(), "reset state must begin in PRESENT")
	_expect(is_zero_approx(float(state.confirm_elapsed)), "reset must clear the confirm clock")
	_expect(int(state.post_consume_remaining_gems) == 1, "reset must prepare the one-gem fallback")
	_expect(int(state.begin_consuming()) == EVENT_CONSUME_REQUEST, "first confirm must emit one consume request")
	_expect(int(state.begin_consuming()) == EVENT_NONE, "repeated confirm must not emit another consume request")
	_expect(state.is_consuming(), "first confirm must enter CONSUMING")
	_expect(int(state.advance(1.99)) == EVENT_NONE, "pre-shatter advance must not emit early events")
	var shatter_events := int(state.advance(0.02))
	_expect((shatter_events & EVENT_SHATTER_SFX) != 0, "crossing shatter start must emit the sound event")
	_expect((int(state.advance(0.20)) & EVENT_SHATTER_SFX) == 0, "shatter sound event must be one-shot")
	state.set_post_consume_remaining(0, 3)
	_expect(int(state.post_consume_remaining_gems) == 0, "consume callback result must replace the fallback")
	var to_reset := 2.91 - float(state.confirm_elapsed)
	var reset_events := int(state.advance(to_reset))
	_expect((reset_events & EVENT_CONTINUE_RESET) != 0, "crossing reset time must emit the hidden-reset event")
	_expect(is_equal_approx(float(state.confirm_elapsed), 2.90), "reset crossing must clamp to one peak-white frame")
	_expect(state.has_reset_fired(), "hidden-reset event must latch reset state")
	_expect(not state.should_update_revival(), "revival clock must not advance on the reset-crossing frame")
	_expect(not state.should_close(false), "reset-crossing frame must not close even if the beat is initially inactive")
	_expect(int(state.advance(0.10)) == EVENT_NONE, "post-reset clock must not repeat one-shot events")
	_expect(state.should_update_revival(), "post-reset frames must advance the revival beat")
	state.advance(0.50)
	_expect(not state.should_close(true), "active revival beat must hold the screen past fadeback")
	_expect(state.should_close(false), "inactive revival beat must release the screen after fadeback")
	_expect(int(state.get_visual_remaining_gems(2)) == 0, "post-shatter visual count must use the consumed callback result")
	_expect(int(state.get_breaking_gem_index(3, 2)) == -1, "reset state must stop projecting a breaking slot")


func _verify_large_delta_guard() -> void:
	var state := _new_state()
	if state == null:
		return
	state.reset(3)
	state.begin_consuming()
	var events := int(state.advance(10.0))
	_expect((events & EVENT_SHATTER_SFX) != 0, "large delta must not skip the shatter-sfx event")
	_expect((events & EVENT_CONTINUE_RESET) != 0, "large delta must not skip the hidden-reset event")
	_expect(is_equal_approx(float(state.confirm_elapsed), 2.90), "large delta must still preserve a peak-white frame")
	_expect(not state.should_update_revival(), "large-delta reset frame must not advance the revival beat")
	_expect(not state.should_close(false), "large-delta reset frame must not close immediately")
	state.advance(0.60)
	_expect(state.should_close(false), "later inactive fadeback frame must close normally")
	var before := float(state.confirm_elapsed)
	state.advance(-10.0)
	_expect(is_equal_approx(float(state.confirm_elapsed), before), "negative delta must not rewind the cinematic")


func _new_state() -> Object:
	var state_script: Variant = load(STATE_PATH)
	_expect(state_script != null, "cinematic state script must load")
	if state_script == null:
		return null
	return state_script.new()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
