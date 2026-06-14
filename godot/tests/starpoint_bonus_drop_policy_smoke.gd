extends SceneTree

const StarpointBonusDropPolicy := preload("res://scripts/stages/common/starpoint_bonus_drop_policy.gd")

var _failures: Array[String] = []


class FakeMythicRuntime:
	extends RefCounted

	var result := 1
	var roll_calls := 0

	func roll_star_detector_bonus_drop_count() -> int:
		roll_calls += 1
		return result


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value if value is Object else null


func _init() -> void:
	_verify_direct_runtime_roll()
	_verify_registry_runtime_lookup()
	_verify_missing_or_negative_roll()
	_verify_stage_sources_delegate_bonus_policy()

	if _failures.is_empty():
		print("starpoint_bonus_drop_policy_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_runtime_roll() -> void:
	var runtime := FakeMythicRuntime.new()
	runtime.result = 2
	var bonus_count: int = StarpointBonusDropPolicy.roll_star_detector_bonus_drop_count({"mythic_item_runtime": runtime}, {})
	_expect(bonus_count == 2, "starpoint bonus policy should roll through direct deps runtime")
	_expect(runtime.roll_calls == 1, "starpoint bonus policy should call the runtime once")
	_expect(StarpointBonusDropPolicy.get_mythic_item_runtime({"mythic_item_runtime": runtime}, {}) == runtime, "starpoint bonus policy should expose direct runtime lookup")


func _verify_registry_runtime_lookup() -> void:
	var runtime := FakeMythicRuntime.new()
	var registry := FakeRegistry.new()
	registry.instances["mythic_item_runtime"] = runtime
	_expect(StarpointBonusDropPolicy.get_mythic_item_runtime({}, {"registry": registry}) == runtime, "starpoint bonus policy should read context registry")
	_expect(StarpointBonusDropPolicy.get_mythic_item_runtime({"registry": registry}, {}) == runtime, "starpoint bonus policy should fall back to deps registry")
	_expect(StarpointBonusDropPolicy.roll_star_detector_bonus_drop_count({}, {"registry": registry}) == 1, "starpoint bonus policy should roll through registry runtime")


func _verify_missing_or_negative_roll() -> void:
	_expect(StarpointBonusDropPolicy.roll_star_detector_bonus_drop_count({}, {}) == 0, "starpoint bonus policy should ignore missing runtime")
	var runtime := FakeMythicRuntime.new()
	runtime.result = -3
	_expect(StarpointBonusDropPolicy.roll_star_detector_bonus_drop_count({"mythic_item_runtime": runtime}, {}) == 0, "starpoint bonus policy should clamp negative rolls")


func _verify_stage_sources_delegate_bonus_policy() -> void:
	var paths := [
		"res://scripts/stages/stage1/stage1_balloon_event.gd",
		"res://scripts/stages/stage2/stage2_pillar_background.gd",
		"res://scripts/stages/stage3/stage3_boss_skill_state.gd",
		"res://scripts/stages/stage4/stage4_bird_event.gd",
	]
	for path in paths:
		var source: String = FileAccess.get_file_as_string(path)
		_expect(source.find("StarpointBonusDropPolicy.roll_star_detector_bonus_drop_count") >= 0, "%s should delegate Star Detector bonus rolls" % path)
		_expect(source.find("func _roll_star_detector_bonus_drop_count") < 0, "%s should not keep a private Star Detector roll wrapper" % path)
		_expect(source.find("func _get_mythic_item_runtime") < 0, "%s should not keep private mythic runtime lookup" % path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
