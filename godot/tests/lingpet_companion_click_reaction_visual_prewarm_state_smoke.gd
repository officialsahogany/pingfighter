extends SceneTree

const LingpetCompanionClickReactionVisualPrewarmState := preload("res://scripts/lingpet/lingpet_companion_click_reaction_visual_prewarm_state.gd")

var _failures: Array[String] = []


class FakeProfile:
	extends RefCounted

	var done_after_by_key: Dictionary = {}
	var counts: Dictionary = {}
	var calls: Array[String] = []
	var last_max_msec := 0
	var last_max_polls := 0

	func prewarm_visual_key_threaded_step(visual_key: String, max_msec: int, max_polls: int) -> bool:
		calls.append(visual_key)
		last_max_msec = max_msec
		last_max_polls = max_polls
		counts[visual_key] = int(counts.get(visual_key, 0)) + 1
		return int(counts[visual_key]) >= int(done_after_by_key.get(visual_key, 1))


func _init() -> void:
	_verify_queue_and_step_state()
	_verify_runtime_delegates_click_reaction_prewarm_state()

	if _failures.is_empty():
		print("lingpet_companion_click_reaction_visual_prewarm_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_queue_and_step_state() -> void:
	var state := LingpetCompanionClickReactionVisualPrewarmState.new()
	var profile := FakeProfile.new()
	profile.done_after_by_key = {"companion_click": 1, "voice_popup": 2}
	var keys := ["companion_click", "voice_popup"]

	state.queue_if_companion(false, "maribo")
	_expect(state.queued_pet_id == "", "queue should ignore non-companion state")
	_expect(state.prewarm_step(false, "maribo", profile, keys, 123, 7), "non-companion step should be complete")
	_expect(profile.calls.is_empty(), "non-companion step should not touch the visual cache")

	state.queue_if_companion(true, "maribo")
	_expect(state.queued_pet_id == "maribo", "companion queue should remember the current pet")
	_expect(not state.prewarm_step(true, "maribo", profile, keys, 123, 7), "step should keep running until every key reports done")
	_expect(state.queued_pet_id == "maribo", "unfinished step should keep the queued pet id")
	_expect(state.done_for_pet_id == "", "unfinished step should not mark the pet complete")
	_expect(profile.calls.size() == 2, "unfinished first pass should visit keys until the first pending key")
	_expect(profile.last_max_msec == 123 and profile.last_max_polls == 7, "step should forward the runtime threaded prewarm guard")

	_expect(state.prewarm_step(true, "maribo", profile, keys, 123, 7), "second pass should complete once delayed keys are cached")
	_expect(state.queued_pet_id == "", "finished step should clear the queued pet id")
	_expect(state.done_for_pet_id == "maribo", "finished step should remember the completed pet")
	var call_count_after_done := profile.calls.size()
	_expect(state.prewarm_step(true, "maribo", profile, keys, 123, 7), "done pet should short-circuit as complete")
	_expect(profile.calls.size() == call_count_after_done, "done pet should not re-drive the visual cache")

	state.reset()
	_expect(state.queued_pet_id == "" and state.done_for_pet_id == "", "reset should clear queued and done pet ids")


func _verify_runtime_delegates_click_reaction_prewarm_state() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_click_reaction_visual_prewarm_state.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_current_visual_prewarm_coordinator.gd")
	var click_reaction_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_click_reaction_state.gd")
	_expect(runtime_source.find("LingpetCompanionClickReactionVisualPrewarmState") >= 0, "egg runtime should preload the click-reaction visual prewarm owner")
	_expect(runtime_source.find("LingpetCurrentVisualPrewarmCoordinator") >= 0, "egg runtime should preload the current visual prewarm coordinator")
	_expect(coordinator_source.find("click_reaction_visual_prewarm_state.queue_if_companion") >= 0, "current visual prewarm coordinator should queue click-reaction visual prewarm through the owner")
	_expect(runtime_source.find("_companion_click_reaction_visual_prewarm_state.prewarm_step") >= 0, "prewarm step should delegate to the prewarm owner")
	_expect(click_reaction_source.find("PANEL_VISUAL_KEY := \"click_reaction_anim\"") >= 0 and click_reaction_source.find("PREWARM_VISUAL_KEYS := [RUNTIME_VISUAL_KEY, PANEL_VISUAL_KEY]") >= 0, "companion-state prewarm should also thread-warm the character-info panel click sheet after hatch")
	_expect(runtime_source.find("var _click_reaction_visual_prewarm_pet_id") < 0, "runtime should not keep click-reaction queued pet state locally")
	_expect(runtime_source.find("var _click_reaction_visual_prewarm_done_for") < 0, "runtime should not keep click-reaction done pet state locally")
	_expect(owner_source.find("queued_pet_id") >= 0 and owner_source.find("done_for_pet_id") >= 0, "prewarm owner should own queued/done bookkeeping")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
