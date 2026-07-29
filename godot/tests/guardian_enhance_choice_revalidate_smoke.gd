extends SceneTree

const GuardianEnhanceApplier := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_applier.gd"
)
const GuardianEnhanceOfferEngine := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_offer_engine.gd"
)

var _failures := 0
var _valid_by_type: Dictionary = {}
var _can_apply_trace: Array[String] = []
var _apply_trace: Array[String] = []
var _fallback_calls := 0


func _init() -> void:
	_verify_seeded_roll_is_deterministic_and_modal_free()
	_verify_injected_failure_rerolls_remaining_pool()
	_verify_all_invalid_uses_uncapped_duration_fallback()
	_verify_result_copy_has_all_seven_languages()
	if _failures == 0:
		print("guardian_enhance_choice_revalidate_smoke: ok")
	quit(_failures)


func _verify_seeded_roll_is_deterministic_and_modal_free() -> void:
	_reset_fixture()
	_valid_by_type = {"active_skill": true, "gauge": true, "mobility": true}
	var first := GuardianEnhanceApplier.resolve_random_roll(
		_candidates(),
		Callable(self, "_can_apply"),
		Callable(self, "_apply"),
		Callable(self, "_fallback"),
		_seeded_rng()
	)
	var first_order: Array = first.get("roll_order", []) as Array
	_reset_fixture()
	_valid_by_type = {"active_skill": true, "gauge": true, "mobility": true}
	var second := GuardianEnhanceApplier.resolve_random_roll(
		_candidates(),
		Callable(self, "_can_apply"),
		Callable(self, "_apply"),
		Callable(self, "_fallback"),
		_seeded_rng()
	)
	_expect(bool(first.get("accepted", false)), "a valid random candidate must apply immediately")
	_expect(first_order == (second.get("roll_order", []) as Array), "the injected RNG must make the automatic roll deterministic")
	_expect(not bool(first.get("modal_started", true)), "automatic enhancement must never open a secondary choice modal")


func _verify_injected_failure_rerolls_remaining_pool() -> void:
	_reset_fixture()
	# The high-weight first roll is invalidated after offer construction. The
	# resolver must remove it, draw again from the remaining pool, and apply once.
	_valid_by_type = {"active_skill": false, "gauge": true, "mobility": true}
	var result := GuardianEnhanceApplier.resolve_random_roll(
		_candidates(),
		Callable(self, "_can_apply"),
		Callable(self, "_apply"),
		Callable(self, "_fallback"),
		_seeded_rng()
	)
	_expect(_can_apply_trace.size() == 2 and _can_apply_trace[0] == "active_skill", "fixture must reject the deterministic first roll before rerolling")
	_expect(_apply_trace.size() == 1 and _apply_trace[0] != "active_skill", "only the valid rerolled candidate may apply")
	_expect(bool(result.get("rerolled", false)), "invalid first roll must report a reroll")
	_expect(not bool(result.get("fallback_used", true)), "a valid replacement must prevent fallback")
	_expect(not bool(result.get("modal_started", true)), "reroll must remain modal-free")
	var detail: Dictionary = result.get("result_detail", {}) as Dictionary
	_expect(str(detail.get("reward_type", "")) == str(_apply_trace[0]), "presentation payload must describe the final rerolled apply result, not the rejected first roll")


func _verify_all_invalid_uses_uncapped_duration_fallback() -> void:
	_reset_fixture()
	_valid_by_type = {"active_skill": false, "gauge": false, "mobility": false}
	var result := GuardianEnhanceApplier.resolve_random_roll(
		_candidates(),
		Callable(self, "_can_apply"),
		Callable(self, "_apply"),
		Callable(self, "_fallback"),
		_seeded_rng()
	)
	_expect(_can_apply_trace.size() == 3, "all-invalid fixture must inject failure into every candidate in the roll pool")
	_expect(_apply_trace.is_empty(), "invalid candidates must never reach apply")
	_expect(_fallback_calls == 1, "all-invalid chain must apply the +15 second fallback exactly once")
	_expect(bool(result.get("fallback_used", false)), "all-invalid chain must identify the fallback path")
	_expect(bool(result.get("accepted", false)), "guaranteed fallback must preserve the perk reward")
	_expect(not bool(result.get("modal_started", true)), "fallback path must remain modal-free")


func _verify_result_copy_has_all_seven_languages() -> void:
	for language in ["ko", "en", "zh", "ja", "es", "pt-BR", "ru"]:
		var copy := GuardianEnhanceOfferEngine.get_result_copy_for_language_for_tests(language)
		for key in ["result_level", "result_unlock", "result_amount", "result_acquired", "result_fallback", "unit_seconds"]:
			_expect(str(copy.get(key, "")).strip_edges() != "", "%s result copy must define %s" % [language, key])


func _candidates() -> Array:
	return [
		{"type": "active_skill", "label": "액티브 스킬 +1", "weight": 1000.0},
		{"type": "gauge", "label": "기력 획득량 증가", "weight": 1.0},
		{"type": "mobility", "label": "이동속도 증가", "weight": 1.0},
	]


func _seeded_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260728
	return rng


func _can_apply(candidate: Dictionary) -> bool:
	var reward_type := str(candidate.get("type", ""))
	_can_apply_trace.append(reward_type)
	return bool(_valid_by_type.get(reward_type, false))


func _apply(candidate: Dictionary) -> Dictionary:
	var reward_type := str(candidate.get("type", ""))
	_apply_trace.append(reward_type)
	return {
		"accepted": true,
		"type": reward_type,
		"result_detail": {
			"kind": "stat",
			"reward_type": reward_type,
			"stat_amount": 5.0,
			"stat_unit": "points",
		},
	}


func _fallback() -> Dictionary:
	_fallback_calls += 1
	return {
		"accepted": true,
		"type": "duration_current_restore",
		"amount": 15.0,
		"pool_max_changed": false,
		"result_detail": {
			"kind": "stat",
			"reward_type": "duration_fallback",
			"stat_amount": 15.0,
			"stat_unit": "seconds",
		},
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
