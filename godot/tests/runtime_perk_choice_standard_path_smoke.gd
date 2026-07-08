extends SceneTree

const RuntimePerkChoiceStandardPath := preload("res://scripts/characters/runtime_perk_choice_standard_path.gd")

var _failures: Array[String] = []
var _feedback_apply_calls := 0
var _feedback_choice_id := ""
var _feedback_text := ""
var _feedback_timer := 0.0
var _level_update_calls := 0
var _bookkeeping_choice_calls := 0
var _bookkeeping_update_calls := 0


func _init() -> void:
	_verify_bookkeeping_path()
	_verify_unlock_and_level_paths()
	_verify_level_state_update()
	_verify_state_applications()
	_verify_state_source_contract()

	if _failures.is_empty():
		print("runtime_perk_choice_standard_path_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_bookkeeping_path() -> void:
	var helper := RuntimePerkChoiceStandardPath.new()
	var path: Dictionary = helper.build_path(
		{"id": "common_refresh"},
		{
			"handled": true,
			"accepted": true,
			"next_pending_skill_choices": 3,
			"next_starpoint_for_skills": 1,
			"feedback_result": {"accepted": true, "feedback_text": "refresh"},
		}
	)
	_expect(str(path.get("path", "")) == RuntimePerkChoiceStandardPath.PATH_BOOKKEEPING, "handled bookkeeping update should select bookkeeping path")
	_expect(bool(path.get("accepted", false)), "bookkeeping path should preserve accepted flag")
	_expect(int(path.get("next_pending_skill_choices", 0)) == 3, "bookkeeping path should expose next pending choices")
	_expect(int(path.get("next_starpoint_for_skills", 0)) == 1, "bookkeeping path should expose next starpoints")
	_expect(is_equal_approx(float(path.get("fallback_timer", 0.0)), RuntimePerkChoiceStandardPath.BOOKKEEPING_FEEDBACK_TIMER), "bookkeeping path should own fallback timer")
	var feedback: Dictionary = _as_dict(path.get("feedback_result", {}))
	feedback["feedback_text"] = "mutated"
	_expect(str(_as_dict(path.get("feedback_result", {})).get("feedback_text", "")) == "mutated", "bookkeeping path exposes its own mutable payload")

	var rejected: Dictionary = helper.build_path(
		{"id": "common_refresh"},
		{
			"handled": true,
			"accepted": false,
		}
	)
	_expect(str(rejected.get("path", "")) == RuntimePerkChoiceStandardPath.PATH_BOOKKEEPING, "rejected bookkeeping update should still select bookkeeping path")
	_expect(not bool(rejected.get("accepted", true)), "rejected bookkeeping path should preserve rejected flag")
	_bookkeeping_choice_calls = 0
	_bookkeeping_update_calls = 0
	var built_path: Dictionary = helper.build_path_from_bookkeeping_choice(
		{"id": "common_refresh"},
		2,
		1,
		5,
		Callable(self, "_apply_bookkeeping_choice"),
		Callable(self, "_build_bookkeeping_update")
	)
	_expect(str(built_path.get("path", "")) == RuntimePerkChoiceStandardPath.PATH_BOOKKEEPING, "bookkeeping path builder should select bookkeeping path from callbacks")
	_expect(bool(built_path.get("accepted", false)), "bookkeeping path builder should preserve accepted bookkeeping update")
	_expect(_bookkeeping_choice_calls == 1, "bookkeeping path builder should call bookkeeping choice callback once")
	_expect(_bookkeeping_update_calls == 1, "bookkeeping path builder should call bookkeeping update callback once")
	_expect(int(built_path.get("next_pending_skill_choices", 0)) == 3, "bookkeeping path builder should expose callback pending choices")
	_expect(str(_as_dict(built_path.get("bookkeeping_result", {})).get("feedback_text", "")) == "refresh cb", "bookkeeping path builder should carry raw bookkeeping result")
	var ordinary_path: Dictionary = helper.build_path_from_bookkeeping_choice(
		{"id": "common_focus"},
		2,
		1,
		5,
		Callable(self, "_apply_bookkeeping_choice"),
		Callable(self, "_build_bookkeeping_update")
	)
	_expect(str(ordinary_path.get("path", "")) == RuntimePerkChoiceStandardPath.PATH_LEVEL, "bookkeeping path builder should fall through to level path when callbacks do not handle")
	_expect(not bool(helper.build_path_from_bookkeeping_choice({"id": "common_focus"}, 2, 1, 5, Callable(), Callable(self, "_build_bookkeeping_update")).get("accepted", true)), "bookkeeping path builder should reject missing choice callback")


func _verify_unlock_and_level_paths() -> void:
	var helper := RuntimePerkChoiceStandardPath.new()
	var unlock_path: Dictionary = helper.build_path(
		{"id": "unlock_plasma", "unlocks_skill": "plasma"},
		{"handled": false}
	)
	_expect(str(unlock_path.get("path", "")) == RuntimePerkChoiceStandardPath.PATH_UNLOCK, "unlock choices should select unlock path after bookkeeping misses")
	_expect(bool(unlock_path.get("accepted", false)), "unlock path should be accepted")

	var level_path: Dictionary = helper.build_path(
		{"id": "common_swiftness"},
		{"handled": false}
	)
	_expect(str(level_path.get("path", "")) == RuntimePerkChoiceStandardPath.PATH_LEVEL, "ordinary choices should select level path after bookkeeping misses")
	_expect(bool(level_path.get("accepted", false)), "level path should be accepted")


func _verify_level_state_update() -> void:
	var helper := RuntimePerkChoiceStandardPath.new()
	var update: Dictionary = helper.build_level_state_update(
		{"accepted": true, "next_level": 4, "feedback_text": "level"},
		"common_swiftness",
		3
	)
	_expect(bool(update.get("accepted", false)), "level state update should accept accepted level payloads")
	_expect(str(update.get("choice_id", "")) == "common_swiftness", "level state update should preserve choice id")
	_expect(int(update.get("next_level", 0)) == 4, "level state update should preserve helper next level")
	_expect(str(_as_dict(update.get("feedback_result", {})).get("feedback_text", "")) == "level", "level state update should preserve feedback result")

	var fallback_update: Dictionary = helper.build_level_state_update({"accepted": true}, "common_training", 2)
	_expect(int(fallback_update.get("next_level", 0)) == 3, "level state update should own fallback next-level increment")
	var rejected: Dictionary = helper.build_level_state_update({"accepted": false}, "common_training", 2)
	_expect(not bool(rejected.get("accepted", true)), "level state update should reject rejected level payloads")


func _verify_state_applications() -> void:
	var helper := RuntimePerkChoiceStandardPath.new()
	var bookkeeping_application: Dictionary = helper.build_bookkeeping_state_application(
		{
			"accepted": true,
			"next_pending_skill_choices": 4,
			"next_starpoint_for_skills": 2,
			"feedback_result": {"accepted": true, "feedback_text": "refresh"},
		},
		1,
		0
	)
	_expect(bool(bookkeeping_application.get("accepted", false)), "bookkeeping application should accept accepted standard path payloads")
	_expect(int(bookkeeping_application.get("pending_skill_choices", 0)) == 4, "bookkeeping application should expose pending choice state")
	_expect(int(bookkeeping_application.get("starpoint_for_skills", 0)) == 2, "bookkeeping application should expose starpoint state")
	_expect(is_equal_approx(float(bookkeeping_application.get("fallback_timer", 0.0)), RuntimePerkChoiceStandardPath.BOOKKEEPING_FEEDBACK_TIMER), "bookkeeping application should carry fallback timer")
	var bookkeeping_feedback: Dictionary = _as_dict(bookkeeping_application.get("feedback_result", {}))
	bookkeeping_feedback["feedback_text"] = "mutated"
	_expect(str(_as_dict(bookkeeping_application.get("feedback_result", {})).get("feedback_text", "")) == "mutated", "bookkeeping application should own its copied feedback payload")

	var fallback_application: Dictionary = helper.build_bookkeeping_state_application(
		{"accepted": true},
		5,
		3
	)
	_expect(int(fallback_application.get("pending_skill_choices", 0)) == 5, "bookkeeping application should preserve current pending fallback")
	_expect(int(fallback_application.get("starpoint_for_skills", 0)) == 3, "bookkeeping application should preserve current starpoint fallback")
	_expect(not bool(helper.build_bookkeeping_state_application({"accepted": false}, 1, 0).get("accepted", true)), "bookkeeping application should reject rejected path payloads")

	var level_application: Dictionary = helper.build_level_state_application(
		{
			"accepted": true,
			"choice_id": "common_swiftness",
			"next_level": 5,
			"feedback_result": {"accepted": true, "feedback_text": "level"},
		}
	)
	_expect(bool(level_application.get("accepted", false)), "level application should accept accepted level state updates")
	_expect(int(_as_dict(level_application.get("runtime_skill_level_patch", {})).get("common_swiftness", 0)) == 5, "level application should carry runtime level patch")
	_expect(str(_as_dict(level_application.get("feedback_result", {})).get("feedback_text", "")) == "level", "level application should carry feedback")
	_expect(not bool(helper.build_level_state_application({"accepted": true, "choice_id": ""}).get("accepted", true)), "level application should reject empty choice ids")

	var runtime_levels: Dictionary = {"common_swiftness": 4}
	var applied: Dictionary = helper.apply_state_update(level_application, runtime_levels, 7, 2)
	_expect(bool(applied.get("accepted", false)), "state application should accept accepted payloads")
	_expect(int(runtime_levels.get("common_swiftness", 0)) == 5, "state application should apply runtime level patch")
	_expect(int(applied.get("pending_skill_choices", 0)) == 7, "state application should preserve current pending fallback")
	_expect(int(applied.get("starpoint_for_skills", 0)) == 2, "state application should preserve current starpoint fallback")
	_expect(str(_as_dict(applied.get("feedback_result", {})).get("feedback_text", "")) == "level", "state application should expose feedback copy")
	_expect(not bool(helper.apply_state_update({"accepted": false}, runtime_levels, 1, 0).get("accepted", true)), "state application should reject rejected payloads")

	var runtime_state := FakeRuntimeState.new()
	var live_apply: Dictionary = helper.apply_result_to_runtime_state(
		runtime_state,
		{
			"accepted": true,
			"pending_skill_choices": 9,
			"starpoint_for_skills": 4,
			"feedback_result": {"accepted": true, "feedback_text": "live"},
			"fallback_timer": 1.5,
		}
	)
	_expect(bool(live_apply.get("accepted", false)), "live state application should accept accepted apply results")
	_expect(runtime_state.pending_skill_choices == 9, "live state application should write pending choices")
	_expect(runtime_state.starpoint_for_skills == 4, "live state application should write starpoints")
	_expect(str(_as_dict(live_apply.get("feedback_result", {})).get("feedback_text", "")) == "live", "live state application should preserve feedback")
	_expect(is_equal_approx(float(live_apply.get("fallback_timer", 0.0)), 1.5), "live state application should preserve fallback timer")
	_expect(not bool(helper.apply_result_to_runtime_state(null, live_apply).get("accepted", true)), "live state application should reject missing state")
	_expect(not bool(helper.apply_result_to_runtime_state(runtime_state, {"accepted": false}).get("accepted", true)), "live state application should reject rejected apply results")

	var bookkeeping_runtime_levels: Dictionary = {}
	var bookkeeping_result: Dictionary = helper.apply_bookkeeping_path(
		{
			"accepted": true,
			"next_pending_skill_choices": 6,
			"next_starpoint_for_skills": 1,
			"feedback_result": {"accepted": true, "feedback_text": "book"},
		},
		bookkeeping_runtime_levels,
		2,
		0
	)
	_expect(bool(bookkeeping_result.get("accepted", false)), "bookkeeping wrapper should accept accepted path payloads")
	_expect(int(bookkeeping_result.get("pending_skill_choices", 0)) == 6, "bookkeeping wrapper should expose pending state")
	_expect(str(_as_dict(bookkeeping_result.get("feedback_result", {})).get("feedback_text", "")) == "book", "bookkeeping wrapper should expose feedback")
	_feedback_apply_calls = 0
	_feedback_choice_id = ""
	_feedback_text = ""
	_feedback_timer = 0.0
	var bookkeeping_runtime_state := FakeRuntimeState.new()
	var bookkeeping_live_result: Dictionary = helper.apply_bookkeeping_path_to_runtime_state(
		{
			"accepted": true,
			"next_pending_skill_choices": 8,
			"next_starpoint_for_skills": 3,
			"feedback_result": {"accepted": true, "feedback_text": "book live"},
		},
		bookkeeping_runtime_state,
		{},
		2,
		0,
		{"id": "common_refresh"},
		Callable(self, "_apply_feedback")
	)
	_expect(bool(bookkeeping_live_result.get("accepted", false)), "bookkeeping live wrapper should accept accepted path payloads")
	_expect(bookkeeping_runtime_state.pending_skill_choices == 8, "bookkeeping live wrapper should write pending choices")
	_expect(bookkeeping_runtime_state.starpoint_for_skills == 3, "bookkeeping live wrapper should write starpoints")
	_expect(_feedback_apply_calls == 1, "bookkeeping live wrapper should call feedback callback once")
	_expect(_feedback_choice_id == "common_refresh", "bookkeeping live wrapper should pass choice payload")
	_expect(_feedback_text == "book live", "bookkeeping live wrapper should pass feedback payload")
	_expect(is_equal_approx(_feedback_timer, RuntimePerkChoiceStandardPath.BOOKKEEPING_FEEDBACK_TIMER), "bookkeeping live wrapper should pass fallback timer")
	_expect(not bool(helper.apply_bookkeeping_path_to_runtime_state({"accepted": true}, bookkeeping_runtime_state, {}, 0, 0, {"id": "bad"}, Callable()).get("accepted", true)), "bookkeeping live wrapper should reject missing feedback callback")

	var wrapped_runtime_levels: Dictionary = {"common_training": 2}
	var level_result: Dictionary = helper.apply_level_path(
		{"accepted": true, "next_level": 3, "feedback_text": "level"},
		"common_training",
		2,
		wrapped_runtime_levels,
		1,
		0
	)
	_expect(bool(level_result.get("accepted", false)), "level wrapper should accept accepted level payloads")
	_expect(int(wrapped_runtime_levels.get("common_training", 0)) == 3, "level wrapper should apply runtime level patch")
	_expect(str(_as_dict(level_result.get("feedback_result", {})).get("feedback_text", "")) == "level", "level wrapper should expose feedback")
	var level_runtime_state := FakeRuntimeState.new()
	var live_level_levels: Dictionary = {"common_focus": 1}
	var live_level_result: Dictionary = helper.apply_level_path_to_runtime_state(
		{"accepted": true, "next_level": 2, "feedback_text": "live level"},
		"common_focus",
		1,
		level_runtime_state,
		live_level_levels,
		4,
		2
	)
	_expect(bool(live_level_result.get("accepted", false)), "level live wrapper should accept accepted level payloads")
	_expect(int(live_level_levels.get("common_focus", 0)) == 2, "level live wrapper should apply runtime level patch")
	_expect(level_runtime_state.pending_skill_choices == 4, "level live wrapper should preserve pending choice state")
	_expect(level_runtime_state.starpoint_for_skills == 2, "level live wrapper should preserve starpoints")
	_expect(str(_as_dict(live_level_result.get("feedback_result", {})).get("feedback_text", "")) == "live level", "level live wrapper should preserve feedback")
	_expect(not bool(helper.apply_level_path_to_runtime_state({"accepted": false}, "common_focus", 1, level_runtime_state, live_level_levels, 4, 2).get("accepted", true)), "level live wrapper should reject rejected level payloads")
	_level_update_calls = 0
	var choice_level_state := FakeRuntimeState.new()
	var choice_level_levels: Dictionary = {"common_focus": 2}
	var choice_level_result: Dictionary = helper.apply_level_choice_to_runtime_state(
		{"id": "common_focus"},
		"common_focus",
		choice_level_state,
		choice_level_levels,
		5,
		1,
		Callable(self, "_build_level_update")
	)
	_expect(bool(choice_level_result.get("accepted", false)), "level choice live wrapper should accept callback level payloads")
	_expect(_level_update_calls == 1, "level choice live wrapper should call level-update callback once")
	_expect(int(choice_level_levels.get("common_focus", 0)) == 3, "level choice live wrapper should apply callback next level")
	_expect(choice_level_state.pending_skill_choices == 5, "level choice live wrapper should preserve pending choices")
	_expect(choice_level_state.starpoint_for_skills == 1, "level choice live wrapper should preserve starpoints")
	_expect(str(_as_dict(choice_level_result.get("feedback_result", {})).get("feedback_text", "")) == "level cb", "level choice live wrapper should preserve callback feedback")
	_expect(not bool(helper.apply_level_choice_to_runtime_state({"id": "common_focus"}, "common_focus", choice_level_state, choice_level_levels, 5, 1, Callable()).get("accepted", true)), "level choice live wrapper should reject missing level-update callback")
	_feedback_apply_calls = 0
	_feedback_choice_id = ""
	_feedback_text = ""
	_feedback_timer = 0.0
	var level_feedback_result: Dictionary = helper.apply_level_feedback_result(
		{
			"accepted": true,
			"feedback_result": {"accepted": true, "feedback_text": "level feedback"},
			"fallback_timer": 1.75,
		},
		{"id": "common_focus"},
		Callable(self, "_apply_feedback"),
		1.2
	)
	_expect(bool(level_feedback_result.get("accepted", false)), "level feedback wrapper should accept valid feedback payloads")
	_expect(_feedback_apply_calls == 1, "level feedback wrapper should call feedback callback once")
	_expect(_feedback_choice_id == "common_focus", "level feedback wrapper should pass choice payload")
	_expect(_feedback_text == "level feedback", "level feedback wrapper should pass feedback payload")
	_expect(is_equal_approx(_feedback_timer, 1.75), "level feedback wrapper should prefer state-result fallback timer")
	_expect(not bool(helper.apply_level_feedback_result({"accepted": true}, {"id": "bad"}, Callable(), 1.2).get("accepted", true)), "level feedback wrapper should reject missing feedback callbacks")
	_expect(not bool(helper.apply_level_feedback_result({"accepted": false}, {"id": "bad"}, Callable(self, "_apply_feedback"), 1.2).get("accepted", true)), "level feedback wrapper should reject rejected level state results")


func _verify_state_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var apply_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_apply_flow.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_standard_path.gd")
	_expect(state_source.find("RuntimePerkChoiceStandardPath") >= 0, "state should preload standard path helper")
	_expect(state_source.find("RuntimePerkChoiceApplyFlow") >= 0, "state should preload choice apply-flow helper")
	_expect(state_source.find("_choice_apply_flow.apply_choice") >= 0, "state should route standard path through apply-flow helper")
	_expect(apply_flow_source.find("build_path") >= 0, "apply-flow helper should consume helper-owned standard path payloads")
	_expect(apply_flow_source.find("build_path_from_bookkeeping_choice") >= 0, "apply-flow helper should delegate bookkeeping choice path building")
	_expect(apply_flow_source.find("apply_bookkeeping_path_to_runtime_state") >= 0, "apply-flow helper should delegate bookkeeping live path completion")
	_expect(apply_flow_source.find("apply_level_choice_to_runtime_state") >= 0, "apply-flow helper should delegate level update/live state application")
	_expect(apply_flow_source.find("apply_level_feedback_result") >= 0, "apply-flow helper should delegate level feedback result application")
	_expect(helper_source.find("func apply_level_path(") >= 0, "helper should own raw level path application")
	_expect(helper_source.find("func apply_level_path_to_runtime_state(") >= 0, "helper should own raw level live-state application")
	_expect(helper_source.find("apply_result_to_runtime_state(runtime_state, apply_result)") >= 0, "helper should own live standard-path state application")
	var apply_body: String = _function_body(apply_flow_source, "func apply_choice(")
	_expect(apply_body.find("_instant_rewards.apply_bookkeeping_choice") < 0, "apply_choice should not call bookkeeping choice helper inline")
	_expect(apply_body.find("_instant_rewards.build_bookkeeping_state_update") < 0, "apply_choice should not build bookkeeping updates inline")
	_expect(apply_body.find("var bookkeeping_instant") < 0, "apply_choice should not retain bookkeeping instant payload inline")
	_expect(apply_body.find("var bookkeeping_update") < 0, "apply_choice should not retain bookkeeping update payload inline")
	_expect(apply_body.find("if bool(bookkeeping_update.get(\"handled\", false))") < 0, "apply_choice should not own bookkeeping handled branch inline")
	_expect(apply_body.find("if str(choice.get(\"unlocks_skill\", \"\"))") < 0, "apply_choice should not own unlock path branch inline")
	_expect(apply_body.find("var next_level := int(level_update.get(\"next_level\"") < 0, "apply_choice should not own level next-value fallback inline")
	_expect(apply_body.find("_level_side_effects.build_level_choice_update") < 0, "apply_choice should not build level update inline")
	_expect(apply_body.find("runtime_skill_levels.get(choice_id") < 0, "apply_choice should not read current level inline")
	_expect(apply_body.find("pending_skill_choices = int(standard_path.get") < 0, "apply_choice should not apply bookkeeping state inline")
	_expect(apply_body.find("pending_skill_choices = int(bookkeeping_apply_result.get") < 0, "apply_choice should not apply bookkeeping result state inline")
	_expect(apply_body.find("bookkeeping_state_result") < 0, "apply_choice should not retain bookkeeping live state payload inline")
	_expect(apply_body.find("RuntimePerkChoiceStandardPath.BOOKKEEPING_FEEDBACK_TIMER") < 0, "apply_choice should not own bookkeeping feedback timer inline")
	_expect(apply_body.find("pending_skill_choices = int(level_apply_result.get") < 0, "apply_choice should not apply level result state inline")
	_expect(apply_body.find("level_apply_result") < 0, "apply_choice should not retain level apply payload inline")
	_expect(apply_body.find("level_state_result.get(\"feedback_result\"") < 0, "apply_choice should not read level feedback payload inline")
	_expect(apply_body.find("level_state_result.get(\"fallback_timer\"") < 0, "apply_choice should not read level feedback timer inline")
	_expect(apply_body.find("starpoint_for_skills = int(bookkeeping_apply_result.get") < 0, "apply_choice should not apply bookkeeping starpoint state inline")
	_expect(apply_body.find("starpoint_for_skills = int(level_apply_result.get") < 0, "apply_choice should not apply level starpoint state inline")
	_expect(apply_body.find("runtime_skill_levels[choice_id]") < 0, "apply_choice should not apply level state inline")
	_expect(apply_body.find("runtime_skill_levels[perk_id]") < 0, "apply_choice should not apply runtime level patches inline")
	_expect(apply_body.find("build_bookkeeping_state_application") < 0, "apply_choice should not build bookkeeping application inline")
	_expect(apply_body.find("build_level_state_application") < 0, "apply_choice should not build level application inline")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _apply_feedback(result: Dictionary, choice: Dictionary, fallback_timer: float) -> bool:
	_feedback_apply_calls += 1
	_feedback_choice_id = str(choice.get("id", ""))
	_feedback_text = str(result.get("feedback_text", ""))
	_feedback_timer = fallback_timer
	return bool(result.get("accepted", false))


func _apply_bookkeeping_choice(
	choice: Dictionary,
	pending_skill_choices: int,
	starpoint_for_skills: int,
	_starpoint_per_choice: int
) -> Dictionary:
	_bookkeeping_choice_calls += 1
	if str(choice.get("id", "")) == "common_refresh":
		return {
			"handled": true,
			"accepted": true,
			"pending_skill_choices": pending_skill_choices + 1,
			"starpoint_for_skills": starpoint_for_skills,
			"feedback_text": "refresh cb",
		}
	return {"handled": false}


func _build_bookkeeping_update(
	result: Dictionary,
	current_pending_skill_choices: int,
	current_starpoint_for_skills: int
) -> Dictionary:
	_bookkeeping_update_calls += 1
	return {
		"handled": bool(result.get("handled", false)),
		"accepted": bool(result.get("accepted", false)),
		"next_pending_skill_choices": int(result.get("pending_skill_choices", current_pending_skill_choices)),
		"next_starpoint_for_skills": int(result.get("starpoint_for_skills", current_starpoint_for_skills)),
		"feedback_result": result,
	}


func _build_level_update(choice: Dictionary, runtime_skill_levels: Dictionary) -> Dictionary:
	_level_update_calls += 1
	var choice_id := str(choice.get("id", ""))
	return {
		"accepted": true,
		"next_level": int(runtime_skill_levels.get(choice_id, 0)) + 1,
		"feedback_text": "level cb",
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeRuntimeState:
	var pending_skill_choices := 1
	var starpoint_for_skills := 0
