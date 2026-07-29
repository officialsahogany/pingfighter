extends SceneTree

const LingpetGuardianRunState := preload("res://scripts/lingpet/lingpet_guardian_run_state.gd")
const LingpetCurrentProfile := preload("res://scripts/lingpet/lingpet_current_profile.gd")
const LingpetHatchStatRollState := preload("res://scripts/lingpet/lingpet_hatch_stat_roll_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_one_roll_per_pet()
	_verify_new_schema_round_trip()
	_verify_legacy_affinity_absorb()
	_verify_guardian_motion_style_contract()

	if _failures.is_empty():
		print("lingpet_hatch_stat_roll_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_one_roll_per_pet() -> void:
	var state := LingpetHatchStatRollState.new()
	state.set_hatch_stat_roll("maribo", 0.25, 0.75)
	var profile := LingpetCurrentProfile.new()
	profile.set_pet_id("maribo")
	var second: Dictionary = state.ensure_roll("maribo", profile, "patrol")
	_expect(not bool(second.get("accepted", false)), "an existing hatch roll must reject a reroll")
	_expect_str(str(second.get("blocked_reason", "")), "already_set", "reroll rejection should name the one-roll gate")
	var preserved: Dictionary = state.get_hatch_stat_roll("maribo")
	_expect_float(float(preserved.get("mobility", 0.0)), 0.25, "rejected reroll must preserve mobility")
	_expect_float(float(preserved.get("defense", 0.0)), 0.75, "rejected reroll must preserve defense")


func _verify_new_schema_round_trip() -> void:
	var source := LingpetHatchStatRollState.new()
	source.set_hatch_stat_roll("maribo", 0.4, 0.6)
	source.set_hatch_stat_roll("rabi", 0.9, 0.0)
	var exported: Dictionary = source.export_run_state()
	_expect(exported.has(LingpetHatchStatRollState.SAVE_KEY), "new save payload should expose the dedicated hatch owner key")
	_expect(not str(exported).contains(LingpetHatchStatRollState.LEGACY_MOBILITY_KEY), "new save payload must not write legacy per-pet hatch keys")

	var restored := LingpetHatchStatRollState.new()
	restored.import_run_state(exported)
	var maribo: Dictionary = restored.get_hatch_stat_roll("maribo")
	var rabi: Dictionary = restored.get_hatch_stat_roll("rabi")
	_expect(bool(maribo.get("has_roll", false)), "new schema restore should keep the patrol roll")
	_expect_float(float(maribo.get("mobility", 0.0)), 0.4, "new schema restore should keep mobility")
	_expect_float(float(maribo.get("defense", 0.0)), 0.6, "new schema restore should keep defense")
	_expect_float(float(rabi.get("mobility", 0.0)), 0.9, "new schema restore should keep another pet independently")


func _verify_legacy_affinity_absorb() -> void:
	var legacy := {
		"pets": {
			"maribo": {
				"pet_id": "maribo",
				LingpetHatchStatRollState.LEGACY_MOBILITY_KEY: 0.35,
				LingpetHatchStatRollState.LEGACY_DEFENSE_KEY: 0.8,
				LingpetHatchStatRollState.LEGACY_SET_KEY: true,
			},
		}
	}
	var owner := LingpetHatchStatRollState.new()
	owner.import_run_state(legacy)
	var absorbed: Dictionary = owner.get_hatch_stat_roll("maribo")
	_expect(bool(absorbed.get("has_roll", false)), "legacy affinity hatch fields should be absorbed by the dedicated owner")
	_expect_float(float(absorbed.get("mobility", 0.0)), 0.35, "legacy mobility should survive absorption")
	_expect_float(float(absorbed.get("defense", 0.0)), 0.8, "legacy defense should survive absorption")

	var affinity := LingpetGuardianRunState.new()
	affinity.import_run_state(legacy)
	var cleaned: Dictionary = affinity.export_run_state()
	_expect(not str(cleaned).contains(LingpetHatchStatRollState.LEGACY_MOBILITY_KEY), "affinity export should discard absorbed mobility keys")
	_expect(not str(cleaned).contains(LingpetHatchStatRollState.LEGACY_DEFENSE_KEY), "affinity export should discard absorbed defense keys")
	_expect(not str(cleaned).contains(LingpetHatchStatRollState.LEGACY_SET_KEY), "affinity export should discard absorbed set flags")


func _verify_guardian_motion_style_contract() -> void:
	var source := FileAccess.get_file_as_string(
		"res://scripts/lingpet/lingpet_hatch_stat_roll_state.gd"
	)
	_expect(
		source.contains('has_method("get_guardian_motion_style")')
		and source.contains("current_profile.get_guardian_motion_style()"),
		"hatch owner must probe and call the same guardian motion-style contract"
	)
	_expect(
		not source.contains('has_method("get_affinity_motion_style")'),
		"retired affinity motion-style probe must not silently zero patrol defense rolls"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_float(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])


func _expect_str(actual: String, expected: String, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
