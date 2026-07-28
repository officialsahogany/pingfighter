extends SceneTree

const GuardianEnhanceChoiceState := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_choice_state.gd"
)
const GuardianEnhanceApplier := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_applier.gd"
)

var _failures := 0
var _valid_by_type: Dictionary = {}
var _can_apply_trace: Array[String] = []
var _apply_trace: Array[String] = []
var _fallback_calls := 0


func _init() -> void:
	_verify_selected_candidate_applies()
	_verify_injected_failure_auto_replaces_in_presented_order()
	_verify_all_invalid_uses_uncapped_duration_fallback_and_closes()
	if _failures == 0:
		print("guardian_enhance_choice_revalidate_smoke: ok")
	quit(_failures)


func _verify_selected_candidate_applies() -> void:
	_reset_fixture()
	_valid_by_type = {"active_skill": true, "gauge": true, "mobility": true}
	var state := _started_state()
	state.advance(GuardianEnhanceChoiceState.INPUT_GUARD_SECONDS)
	state.select_index(1)
	var result := GuardianEnhanceApplier.resolve_choice_state(
		state,
		Callable(self, "_can_apply"),
		Callable(self, "_apply"),
		Callable(self, "_fallback")
	)
	_expect(bool(result.get("accepted", false)), "valid selected candidate should apply")
	_expect(int(result.get("applied_index", -1)) == 1, "valid selection must not be replaced")
	_expect(not bool(result.get("auto_replaced", true)), "valid selection must preserve player choice")
	_expect(bool(result.get("modal_closed", false)), "successful application must close the choice modal")


func _verify_injected_failure_auto_replaces_in_presented_order() -> void:
	_reset_fixture()
	var state := _started_state()
	state.advance(GuardianEnhanceChoiceState.INPUT_GUARD_SECONDS)
	state.select_index(2)
	# Failure injection happens AFTER the presented set is captured: the selected
	# mobility candidate becomes invalid, candidate 0 stays valid, candidate 1 is
	# also valid. Presentation order therefore requires candidate 0 as replacement.
	_valid_by_type = {"active_skill": true, "gauge": true, "mobility": false}
	var result := GuardianEnhanceApplier.resolve_choice_state(
		state,
		Callable(self, "_can_apply"),
		Callable(self, "_apply"),
		Callable(self, "_fallback")
	)
	_expect(_can_apply_trace == ["mobility", "active_skill"], "fixture must actually reject the selected candidate before checking the first presented replacement")
	_expect(_apply_trace == ["active_skill"], "only the first valid replacement in presentation order may apply")
	_expect(bool(result.get("auto_replaced", false)), "invalid selected candidate must report automatic replacement")
	_expect(int(result.get("applied_index", -1)) == 0, "replacement must use presentation-order candidate 0")
	_expect(not bool(result.get("fallback_used", true)), "a valid replacement must prevent fallback")
	_expect(bool(result.get("modal_closed", false)), "replacement path must close the modal")


func _verify_all_invalid_uses_uncapped_duration_fallback_and_closes() -> void:
	_reset_fixture()
	var state := _started_state()
	state.advance(GuardianEnhanceChoiceState.INPUT_GUARD_SECONDS)
	_valid_by_type = {"active_skill": false, "gauge": false, "mobility": false}
	var result := GuardianEnhanceApplier.resolve_choice_state(
		state,
		Callable(self, "_can_apply"),
		Callable(self, "_apply"),
		Callable(self, "_fallback")
	)
	_expect(_can_apply_trace == ["active_skill", "gauge", "mobility"], "all-invalid fixture must inject failure into every candidate from the same set")
	_expect(_apply_trace.is_empty(), "invalid candidates must never reach apply")
	_expect(_fallback_calls == 1, "all-invalid chain must apply the +15 second fallback exactly once")
	_expect(bool(result.get("fallback_used", false)), "all-invalid chain must identify the fallback path")
	_expect(bool(result.get("accepted", false)), "guaranteed fallback must preserve the perk reward")
	_expect(bool(result.get("modal_closed", false)), "fallback path must close the modal")


func _started_state() -> Object:
	var state := GuardianEnhanceChoiceState.new()
	var started := state.start("maribo", [
		{"type": "active_skill", "label": "액티브 스킬 +1"},
		{"type": "gauge", "label": "기력 획득량 증가"},
		{"type": "mobility", "label": "이동속도 증가"},
	])
	_expect(started, "choice state fixture must start with three real candidates")
	return state


func _can_apply(candidate: Dictionary) -> bool:
	var reward_type := str(candidate.get("type", ""))
	_can_apply_trace.append(reward_type)
	return bool(_valid_by_type.get(reward_type, false))


func _apply(candidate: Dictionary) -> Dictionary:
	var reward_type := str(candidate.get("type", ""))
	_apply_trace.append(reward_type)
	return {"accepted": true, "type": reward_type}


func _fallback() -> Dictionary:
	_fallback_calls += 1
	return {
		"accepted": true,
		"type": "duration_current_restore",
		"amount": 15.0,
		"pool_max_changed": false,
	}


func _reset_fixture() -> void:
	_valid_by_type.clear()
	_can_apply_trace.clear()
	_apply_trace.clear()
	_fallback_calls = 0


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
