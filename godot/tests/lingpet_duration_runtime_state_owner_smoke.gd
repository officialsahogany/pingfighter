extends SceneTree

const LingpetDurationRuntimeState := preload(
	"res://scripts/lingpet/lingpet_duration_runtime_state.gd"
)

var _failures: Array[String] = []


class FakeAffinityState:
	extends RefCounted

	var pool_pct := 73
	var drain_exempt := false
	var last_advance: Dictionary = {}

	func clear_duration_drain_exempt_latch() -> void:
		drain_exempt = false

	func latch_duration_drain_exempt(owner: Object, collection_state: Object) -> bool:
		drain_exempt = bool(collection_state.is_auto_present_league(owner))
		return drain_exempt

	func is_duration_drain_exempt_latched() -> bool:
		return drain_exempt

	func advance_duration_pool(
		delta: float,
		summoned: bool,
		drain_multiplier: float,
		recovery_multiplier: float
	) -> Dictionary:
		last_advance = {
			"delta": delta,
			"summoned": summoned,
			"drain_multiplier": drain_multiplier,
			"recovery_multiplier": recovery_multiplier,
		}
		return {"changed": true, "expired": false}

	func get_duration_pool_pct() -> int:
		return pool_pct


class FakeCollectionState:
	extends RefCounted

	func is_auto_present_league(owner: Object) -> bool:
		return bool(owner.get("auto_present"))


class FakeOwner:
	extends RefCounted

	var auto_present := false


func _init() -> void:
	_verify_duration_advance_and_light_eater()
	_verify_drain_exemption_lifecycle()
	_verify_runtime_ownership()

	if _failures.is_empty():
		print("lingpet_duration_runtime_state_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_duration_advance_and_light_eater() -> void:
	var state := LingpetDurationRuntimeState.new()
	var affinity := FakeAffinityState.new()
	var owner := FakeOwner.new()
	var collection := FakeCollectionState.new()
	var result: Dictionary = state.advance_duration(
		2.5,
		affinity,
		owner,
		collection,
		[
			{"id": "lingpet_light_eater", "level": 3},
			{"id": "custom_duration_passive", "duration_drain_reduction_pct": 12.0},
		],
		true
	)
	_expect(bool(result.get("changed", false)), "duration owner should forward mutation results")
	_expect(bool(affinity.last_advance.get("summoned", false)), "summoned state should reach the pool owner")
	_expect_float(float(affinity.last_advance.get("drain_multiplier", 0.0)), 0.64, "light eater and custom reductions should combine")
	_expect_eq(state.get_active_duration_pct(true, affinity), 73, "active guardian should expose the shared duration percent")
	_expect_eq(state.get_active_duration_pct(false, affinity), 0, "missing guardian should hide duration percent")
	_expect_float(
		state.get_duration_drain_multiplier([
			{"id": "lingpet_light_eater", "level": 5},
			{"id": "custom_duration_passive", "duration_drain_reduction_pct": 40.0},
		]),
		0.4,
		"combined drain reduction should retain the approved 60 percent cap"
	)


func _verify_drain_exemption_lifecycle() -> void:
	var state := LingpetDurationRuntimeState.new()
	var affinity := FakeAffinityState.new()
	var owner := FakeOwner.new()
	var collection := FakeCollectionState.new()
	owner.auto_present = true
	_expect(state.latch_drain_exempt(owner, collection, affinity), "auto-present league should latch duration drain exemption")
	_expect(affinity.drain_exempt, "affinity duration owner should receive the exemption latch")
	state.advance_inactive(affinity)
	_expect(not affinity.drain_exempt, "inactive advance should clear the run latch")


func _verify_runtime_ownership() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var state_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_duration_runtime_state.gd")
	_expect(runtime_source.contains("const LingpetDurationRuntimeState := preload("), "egg runtime should preload the duration runtime owner")
	_expect(runtime_source.contains("var _duration_runtime_state: Object = LingpetDurationRuntimeState.new()"), "egg runtime should compose one duration runtime owner")
	_expect(runtime_source.contains("_duration_runtime_state.advance_duration("), "egg runtime should delegate duration ticks")
	_expect(not runtime_source.contains("sati" + "ety"), "egg runtime must not retain the retired rail vocabulary")
	_expect(state_source.contains("LingpetDurationState.get_drain_reduction_pct_for_level"), "duration owner should consume the shared light-eater table")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])


func _expect_float(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])
