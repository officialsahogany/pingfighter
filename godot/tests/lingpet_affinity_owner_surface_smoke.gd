extends SceneTree

const LingpetAffinityOwnerSurface := preload("res://scripts/lingpet/lingpet_affinity_owner_surface.gd")

var _failures: Array[String] = []


class FakeAffinityState:
	extends RefCounted

	var level := 2
	var points := 17.5
	var next_requirement := 50.0
	var next_reward: Dictionary = {"label": "다음 카드"}

	func get_level(_pet_id: String) -> int:
		return level

	func get_points(_pet_id: String) -> float:
		return points

	func get_next_requirement(_pet_id: String) -> float:
		return next_requirement

	func get_next_reward(_pet_id: String) -> Dictionary:
		return next_reward.duplicate(true)


class FakeContextCoordinator:
	extends RefCounted

	var configure_count := 0
	var last_pet_id := ""

	func configure(
		pet_id: String,
		_current_pet_id: String,
		_current_profile: Object,
		_loadout_state: Object,
		_affinity_state: Object,
		_loadout: Dictionary = {}
	) -> Dictionary:
		configure_count += 1
		last_pet_id = pet_id
		return {}


class FakeProfile:
	extends RefCounted

	var affinity_reward_signature := "0|0|0|0|0|0"


class FakeSnapshotBuilder:
	extends RefCounted

	var calls: Array[Dictionary] = []
	var values: Dictionary = {}

	func set_owner_pair_gated(_owner: Object, lingpet_key: String, ringpet_key: String, value: Variant) -> void:
		calls.append({
			"lingpet_key": lingpet_key,
			"ringpet_key": ringpet_key,
			"value": value,
		})
		values[lingpet_key] = value
		values[ringpet_key] = value


func _init() -> void:
	_run()


func _run() -> void:
	_verify_snapshot_shape_and_title_fallback()
	_verify_stable_key_gating_and_owner_rebase()
	_verify_source_ownership()

	if _failures.is_empty():
		print("lingpet_affinity_owner_surface_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_snapshot_shape_and_title_fallback() -> void:
	var surface := LingpetAffinityOwnerSurface.new()
	var affinity_state := FakeAffinityState.new()
	var context := FakeContextCoordinator.new()
	var profile := FakeProfile.new()
	var snapshot: Dictionary = surface.build_snapshot(
		"companion",
		"companion",
		"maribo",
		affinity_state,
		context,
		profile,
		null
	)
	_expect_eq(int(snapshot.get("level", 0)), 2, "companion snapshot should expose affinity level")
	_expect_float(float(snapshot.get("points", 0.0)), 17.5, "companion snapshot should expose affinity points")
	_expect_float(float(snapshot.get("next_requirement", 0.0)), 50.0, "companion snapshot should expose the next requirement")
	_expect_str(str(snapshot.get("next_label", "")), "다음 카드", "companion snapshot should expose the next reward label")
	_expect(not snapshot.has("ring_core_tier"), "companion snapshot should omit the retired ring-core tier")
	_expect(not snapshot.has("chip_count"), "companion snapshot should omit retired enhancement chips")
	_expect(not snapshot.has("bond_points"), "v5 owner surface should not expose the removed permanent bond axis")
	_expect(not snapshot.has("bond_title"), "v5 owner surface should not expose the removed permanent bond title")
	_expect_eq(context.configure_count, 1, "snapshot build should configure reward context exactly once")
	_expect_str(context.last_pet_id, "maribo", "snapshot context should target the active pet")

	affinity_state.next_reward = {"title": "하트 공명", "label": "무시될 라벨"}
	var title_snapshot: Dictionary = surface.build_snapshot(
		"companion",
		"companion",
		"maribo",
		affinity_state,
		context,
		profile,
		null
	)
	_expect_str(str(title_snapshot.get("next_label", "")), "하트 공명", "title rewards should win over the ordinary label")

	var none_snapshot: Dictionary = surface.build_snapshot(
		"none",
		"companion",
		"maribo",
		affinity_state,
		context,
		profile,
		null
	)
	_expect_eq(int(none_snapshot.get("level", -1)), 0, "non-companion snapshot should clear affinity level")
	_expect_float(float(none_snapshot.get("points", -1.0)), 0.0, "non-companion snapshot should clear affinity points")
	_expect_eq(context.configure_count, 2, "non-companion snapshots should not configure reward context")


func _verify_stable_key_gating_and_owner_rebase() -> void:
	var surface := LingpetAffinityOwnerSurface.new()
	var affinity_state := FakeAffinityState.new()
	var context := FakeContextCoordinator.new()
	var profile := FakeProfile.new()
	var builder := FakeSnapshotBuilder.new()
	var owner_a := RefCounted.new()
	var owner_b := RefCounted.new()

	_expect(surface.sync_owner_if_changed(owner_a, builder, "companion", "companion", "maribo", affinity_state, context, profile, null), "first owner sync should build the affinity surface")
	_expect_eq(builder.calls.size(), 4, "one affinity surface build should push the four live affinity compatibility pairs")
	_expect_eq(surface.get_build_count_for_tests(), 1, "first owner sync should increment the build counter")
	_expect_eq(context.configure_count, 1, "first owner sync should build one snapshot")
	_expect_eq(int(builder.values.get("lingpet_affinity_level", 0)), 2, "lingpet affinity level key should receive the snapshot value")
	_expect_eq(int(builder.values.get("ringpet_affinity_level", 0)), 2, "ringpet affinity level mirror should receive the same value")
	_expect(not builder.values.has("lingpet_bond_points"), "R3b owner surface should not write removed lingpet_bond_points")
	_expect(not builder.values.has("ringpet_bond_points"), "R3b owner surface should not write removed ringpet_bond_points")
	_expect(not builder.values.has("lingpet_bond_title"), "R3b owner surface should not write removed lingpet_bond_title")
	_expect(not builder.values.has("ringpet_bond_title"), "R3b owner surface should not write removed ringpet_bond_title")

	_expect(not surface.sync_owner_if_changed(owner_a, builder, "companion", "companion", "maribo", affinity_state, context, profile, null), "stable same-owner sync should skip the affinity surface")
	_expect_eq(builder.calls.size(), 4, "stable skip should not issue more owner-pair pushes")
	_expect_eq(surface.get_build_count_for_tests(), 1, "stable skip should not increment the build counter")
	_expect_eq(context.configure_count, 1, "stable skip should avoid rebuilding the snapshot")

	affinity_state.points = 22.5
	_expect(surface.sync_owner_if_changed(owner_a, builder, "companion", "companion", "maribo", affinity_state, context, profile, null), "changed points should invalidate the affinity surface key")
	_expect_float(float(builder.values.get("lingpet_affinity_points", 0.0)), 22.5, "changed points should reach the owner surface")
	_expect_eq(surface.get_build_count_for_tests(), 2, "changed points should rebuild exactly once")

	_expect(surface.sync_owner_if_changed(owner_b, builder, "companion", "companion", "maribo", affinity_state, context, profile, null), "a new owner instance should rebase the affinity surface cache")
	_expect_eq(surface.get_build_count_for_tests(), 3, "owner rebase should rebuild exactly once")

	profile.affinity_reward_signature = "1|0|0|0|0|0"
	_expect(surface.sync_owner_if_changed(owner_b, builder, "companion", "companion", "maribo", affinity_state, context, profile, null), "reward-signature changes should invalidate the affinity surface key")
	_expect_eq(surface.get_build_count_for_tests(), 4, "reward-signature change should rebuild exactly once")

	surface.reset_build_counter_for_tests()
	_expect_eq(surface.get_build_count_for_tests(), 0, "test counter reset should preserve compatibility instrumentation")


func _verify_source_ownership() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var surface_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_affinity_owner_surface.gd")
	_expect(runtime_source.find("LingpetAffinityOwnerSurface") >= 0, "egg runtime should delegate affinity owner surface ownership")
	_expect(runtime_source.find("_owner_affinity_surface_owner_id") < 0 and runtime_source.find("_owner_affinity_surface_key") < 0, "egg runtime should not retain affinity owner cache fields")
	_expect(runtime_source.find("func _build_affinity_owner_snapshot") < 0 and runtime_source.find("func _should_sync_affinity_owner_surface") < 0, "egg runtime should not retain affinity snapshot or gating details")
	_expect(surface_source.find("set_owner_pair_gated") >= 0, "affinity owner surface should own compatibility-pair publication")
	_expect(surface_source.find("affinity_reward_signature") >= 0, "affinity owner surface key should retain reward-signature invalidation")
	_expect(surface_source.find("lingpet_bond_") < 0 and surface_source.find("ringpet_bond_") < 0, "R3b owner surface must not publish removed permanent bond owner keys")
	_expect(surface_source.find("bond_points") < 0 and surface_source.find("bond_title") < 0, "R3b owner surface snapshot must not keep removed bond fields")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])


func _expect_float(actual: float, expected: float, message: String) -> void:
	if absf(actual - expected) > 0.001:
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])


func _expect_str(actual: String, expected: String, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
