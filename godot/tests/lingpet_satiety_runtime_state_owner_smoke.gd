extends SceneTree

const LingpetSatietyRuntimeState := preload(
	"res://scripts/lingpet/lingpet_satiety_runtime_state.gd"
)
const LingpetAffinityState := preload(
	"res://scripts/lingpet/lingpet_affinity_state.gd"
)

var _failures: Array[String] = []


class FakeAffinityState:
	extends RefCounted

	var exhausted := false
	var satiety_pct := 73
	var speed_multiplier := 0.8
	var exhaustion_ratio := 0.45
	var drain_changed := false
	var exhaustion_changed := false
	var drain_calls: Array[Dictionary] = []
	var exhaustion_calls: Array[Dictionary] = []

	func advance_satiety(
		pet_id: String,
		battle_slots: Array,
		delta: float,
		active_drain_multiplier: float,
		rest_recovery_multiplier: float,
		is_active_exhausted: bool
	) -> Dictionary:
		drain_calls.append({
			"pet_id": pet_id,
			"battle_slots": battle_slots,
			"delta": delta,
			"active_drain_multiplier": active_drain_multiplier,
			"rest_recovery_multiplier": rest_recovery_multiplier,
			"is_active_exhausted": is_active_exhausted,
		})
		return {"changed": drain_changed}

	func advance_satiety_exhaustion(
		pet_id: String,
		delta: float,
		telegraph_seconds: float,
		enabled: bool
	) -> Dictionary:
		exhaustion_calls.append({
			"pet_id": pet_id,
			"delta": delta,
			"telegraph_seconds": telegraph_seconds,
			"enabled": enabled,
		})
		return {"changed": exhaustion_changed}

	func is_satiety_exhausted(_pet_id: String) -> bool:
		return exhausted

	func is_duration_resummon_locked() -> bool:
		return exhausted

	func get_satiety_pct(_pet_id: String) -> int:
		return satiety_pct

	func get_duration_pool_pct() -> int:
		return satiety_pct

	func get_satiety_speed_multiplier(_pet_id: String) -> float:
		return speed_multiplier

	func get_satiety_exhaustion_ratio(_pet_id: String, _telegraph_seconds: float) -> float:
		return exhaustion_ratio


class FakeCollectionState:
	extends RefCounted

	var auto_present_league := false
	var exemption_checks := 0

	func is_auto_present_league(_owner: Object) -> bool:
		exemption_checks += 1
		return auto_present_league


func _init() -> void:
	_verify_active_advance_and_drain_contract()
	_verify_exemption_and_query_contract()
	_verify_runtime_delegates_satiety_policy()

	if _failures.is_empty():
		print("lingpet_satiety_runtime_state_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_active_advance_and_drain_contract() -> void:
	var state: Object = LingpetSatietyRuntimeState.new()
	var affinity := FakeAffinityState.new()
	var collection := FakeCollectionState.new()
	var owner := RefCounted.new()
	var battle_slots: Array = ["maribo", "lunabi", ""]
	var passive_skills: Array = [
		{"id": "lingpet_light_eater", "level": 3},
		{"id": "custom_satiety_passive", "satiety_drain_reduction_pct": 12.0},
	]
	var expected_reduction := (
		LingpetAffinityState.get_satiety_drain_reduction_pct_for_level(3) + 12.0
	)
	affinity.drain_changed = true
	state.latch_penalty_exempt(owner, collection)
	_expect(
		state.advance_active(
			"maribo",
			battle_slots,
			2.5,
			affinity,
			owner,
			collection,
			passive_skills,
			1.75
		),
		"either satiety mutation should invalidate the runtime snapshot"
	)
	_expect_eq(affinity.drain_calls.size(), 1, "active advance should issue one drain/recovery update")
	_expect_eq(affinity.exhaustion_calls.size(), 0, "shared duration advance should not retain a separate exhaustion timer update")
	_expect_eq(collection.exemption_checks, 2, "active tick should preserve latch-then-KO exemption read order")
	var drain_call: Dictionary = affinity.drain_calls[0]
	_expect_str(str(drain_call.get("pet_id", "")), "maribo", "advance should preserve the active pet id")
	_expect(drain_call.get("battle_slots", []) == battle_slots, "advance should preserve the current battle-slot order")
	_expect_float(float(drain_call.get("delta", 0.0)), 2.5, "advance should preserve delta")
	_expect_float(
		float(drain_call.get("active_drain_multiplier", 0.0)),
		1.0 - expected_reduction / 100.0,
		"light eater and generic passive reductions should combine"
	)
	_expect_float(float(drain_call.get("rest_recovery_multiplier", 0.0)), 1.0, "bench recovery multiplier should stay unchanged")
	_expect(not bool(drain_call.get("is_active_exhausted", true)), "non-exhausted active companion should drain instead of rest")
	var clamped_passives: Array = [
		{"id": "lingpet_light_eater", "level": 5},
		{"id": "custom_satiety_passive", "satiety_drain_reduction_pct": 40.0},
	]
	_expect_float(state.get_satiety_drain_multiplier(clamped_passives), 0.4, "combined drain reduction should retain the 60 percent cap")


func _verify_exemption_and_query_contract() -> void:
	var state: Object = LingpetSatietyRuntimeState.new()
	var affinity := FakeAffinityState.new()
	var collection := FakeCollectionState.new()
	var owner := RefCounted.new()
	collection.auto_present_league = true
	affinity.exhausted = true
	var no_passives: Array = []
	var slots: Array = ["maribo"]
	state.latch_penalty_exempt(owner, collection)
	state.advance_active(
		"maribo",
		slots,
		0.5,
		affinity,
		owner,
		collection,
		no_passives,
		1.75
	)
	_expect(state.is_penalty_exempt(null, collection), "null-owner reads should reuse the exemption latched by the active tick")
	_expect(not bool(affinity.drain_calls[0].get("is_active_exhausted", true)), "exempt leagues should not route the active pet through KO rest")
	_expect_eq(affinity.exhaustion_calls.size(), 0, "exempt leagues should not resurrect the removed exhaustion timer")
	_expect(not state.is_companion_exhausted(true, "maribo", affinity, owner, collection), "exempt companion should not publish KO")
	_expect_float(state.get_speed_scale(true, "maribo", affinity, owner, collection), 1.0, "exempt companion should retain full speed")
	_expect_float(state.get_exhaustion_ratio(true, "maribo", affinity, owner, collection, 1.75), 0.0, "exempt companion should hide the exhaustion telegraph")

	collection.auto_present_league = false
	_expect(state.is_companion_exhausted(true, "maribo", affinity, owner, collection), "non-exempt exhausted companion should publish KO")
	_expect_float(state.get_speed_scale(true, "maribo", affinity, owner, collection), 1.0, "duration expiry should stow instead of applying a speed penalty")
	affinity.exhausted = false
	_expect_float(state.get_speed_scale(true, "maribo", affinity, owner, collection), 1.0, "remaining duration should not scale guardian movement speed")
	_expect_eq(state.get_active_satiety_pct(true, "maribo", affinity), 73, "active snapshot should expose affinity satiety percent")
	_expect_eq(state.get_active_satiety_pct(false, "maribo", affinity), 0, "inactive snapshot should clear satiety percent")
	_expect_float(state.get_exhaustion_ratio(true, "maribo", affinity, owner, collection, 1.75), 0.45, "normal companion should expose affinity exhaustion progress")

	state.advance_inactive()
	_expect(not state.is_penalty_exempt(null, collection), "inactive advance should clear the latched league exemption")
	_expect_float(state.get_speed_scale(false, "maribo", affinity, owner, collection), 1.0, "inactive companion should always use neutral speed")


func _verify_runtime_delegates_satiety_policy() -> void:
	var runtime_source := FileAccess.get_file_as_string(
		"res://scripts/lingpet/lingpet_egg_runtime.gd"
	)
	var state_source := FileAccess.get_file_as_string(
		"res://scripts/lingpet/lingpet_satiety_runtime_state.gd"
	)
	_expect(runtime_source.find("const LingpetSatietyRuntimeState := preload(") >= 0, "egg runtime should preload the focused satiety owner")
	_expect(runtime_source.find("var _satiety_runtime_state: Object = LingpetSatietyRuntimeState.new()") >= 0, "egg runtime should compose one satiety owner")
	_expect(runtime_source.find("var _satiety_penalty_exempt :=") < 0, "egg runtime should not retain the exemption backing field")
	_expect(runtime_source.find("_affinity_state.advance_satiety(") < 0, "egg runtime should not directly mutate satiety progression")
	_expect(runtime_source.find("_affinity_state.advance_satiety_exhaustion(") < 0, "egg runtime should not directly mutate exhaustion progression")
	_expect(runtime_source.find("_satiety_runtime_state.advance_duration(") >= 0, "egg runtime active tick should delegate to the focused duration owner")
	_expect(runtime_source.find("func _get_satiety_drain_multiplier()") < 0, "egg runtime should not retain passive drain policy")
	_expect(state_source.find("LingpetAffinityState.get_satiety_drain_reduction_pct_for_level") >= 0, "satiety owner should retain the light-eater reduction table route")
	_expect(state_source.find("MAX_DRAIN_REDUCTION_PCT := 60.0") >= 0, "satiety owner should retain the 60 percent reduction cap")
	_expect(state_source.find("clampf(reduction_pct, 0.0, MAX_DRAIN_REDUCTION_PCT)") >= 0, "satiety owner should apply the named drain-reduction cap")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])


func _expect_float(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])


func _expect_str(actual: String, expected: String, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
