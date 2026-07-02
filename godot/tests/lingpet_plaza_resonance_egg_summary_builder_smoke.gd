extends SceneTree

const LingpetPlazaResonanceEggSummaryBuilder := preload("res://scripts/lingpet/lingpet_plaza_resonance_egg_summary_builder.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted


func _init() -> void:
	_verify_offer_reason_priority()
	_verify_result_payload_shape()
	_verify_runtime_delegates_plaza_resonance_summary_builder()

	if _failures.is_empty():
		print("lingpet_plaza_resonance_egg_summary_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_offer_reason_priority() -> void:
	var builder := LingpetPlazaResonanceEggSummaryBuilder.new()
	var missing_owner: Dictionary = builder.build_offer(null, "none", true, 0, 1)
	_expect(not bool(missing_owner.get("can_spawn", true)), "missing owner should block plaza egg offers")
	_expect_eq(str(missing_owner.get("reason", "")), "missing_owner", "missing owner should report missing_owner")

	var active_egg: Dictionary = builder.build_offer(FakeOwner.new(), "egg", true, 1, 3)
	_expect(not bool(active_egg.get("can_spawn", true)), "active egg should block plaza egg offers")
	_expect_eq(str(active_egg.get("reason", "")), "egg_already_active", "active egg should report egg_already_active")
	_expect_eq(int(active_egg.get("hatch_hits", -1)), 1, "active egg summary should preserve hatch hits")
	_expect_eq(int(active_egg.get("required_hits", -1)), 3, "active egg summary should preserve required hits")

	var no_candidates: Dictionary = builder.build_offer(FakeOwner.new(), "none", false, 0, 1)
	_expect(not bool(no_candidates.get("can_spawn", true)), "no candidates should block plaza egg offers")
	_expect_eq(str(no_candidates.get("reason", "")), "no_hatch_candidates", "no candidates should report no_hatch_candidates")

	var ok: Dictionary = builder.build_offer(FakeOwner.new(), "none", true, 0, 1)
	_expect(bool(ok.get("can_spawn", false)), "candidate-ready offer should be spawnable")
	_expect(bool(ok.get("changed", false)), "ok spawnable offer should mark changed")
	_expect_eq(str(ok.get("reason", "")), "ok", "candidate-ready offer should report ok")


func _verify_result_payload_shape() -> void:
	var builder := LingpetPlazaResonanceEggSummaryBuilder.new()
	var blocked: Dictionary = builder.build_result(false, "no_hatch_candidates", "companion", 2, 5)
	_expect(not bool(blocked.get("can_spawn", true)), "blocked result should not be spawnable")
	_expect(bool(blocked.get("handled", false)), "plaza summary should always mark handled")
	_expect(not bool(blocked.get("changed", true)), "blocked result should not mark changed")
	_expect_eq(str(blocked.get("state", "")), "companion", "summary should preserve runtime state")
	_expect_eq(int(blocked.get("hatch_hits", -1)), 2, "summary should preserve hatch hits")
	_expect_eq(int(blocked.get("required_hits", -1)), 5, "summary should preserve required hits")


func _verify_runtime_delegates_plaza_resonance_summary_builder() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var builder_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_plaza_resonance_egg_summary_builder.gd")
	_expect(runtime_source.find("LingpetPlazaResonanceEggSummaryBuilder") >= 0, "egg runtime should preload the plaza resonance summary builder")
	_expect(runtime_source.find("_plaza_resonance_egg_summary_builder.build_offer") >= 0, "runtime plaza offer API should delegate summary construction")
	_expect(runtime_source.find("_plaza_resonance_egg_summary_builder.build_result") >= 0, "runtime plaza spawn API should delegate result construction")
	_expect(runtime_source.find("func _build_plaza_resonance_egg_summary") < 0, "runtime should not keep a private plaza summary builder")
	_expect(builder_source.find("\"can_spawn\"") >= 0 and builder_source.find("\"changed\"") >= 0, "builder should own the plaza summary payload keys")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
