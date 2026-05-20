extends SceneTree

const DashSnapshotBuilder := preload("res://scripts/core/battle_update_dash_snapshot_builder.gd")
const BattleUpdateEffectsContext := preload("res://scripts/core/battle_update_effects_context.gd")

var _failures: Array[String] = []


class FakeDashState:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {
			"tokens": 2,
			"max_tokens": 3,
			"active": true,
			"direction": -1.0,
			"boost_charging_pending_dash_refund": true,
			"boost_charging_token_index": 1,
		}


class FakeBadDashState:
	extends RefCounted

	func get_snapshot() -> Variant:
		return "bad"


class FakeOwner:
	extends RefCounted

	var data: Dictionary = {}

	func _init(initial_data: Dictionary) -> void:
		data = initial_data.duplicate(true)

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances.duplicate()

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	var builder: Object = DashSnapshotBuilder.new()

	var live_registry := FakeRegistry.new({"smasher_dash_state": FakeDashState.new()})
	var live_snapshot: Dictionary = builder.build_snapshot(live_registry)
	_expect(int(live_snapshot.get("tokens", 0)) == 2, "builder should return live dash tokens")
	_expect(int(live_snapshot.get("max_tokens", 0)) == 3, "builder should return live max tokens")
	_expect(bool(live_snapshot.get("active", false)), "builder should return live active state")
	_expect(float(live_snapshot.get("direction", 0.0)) == -1.0, "builder should return live dash direction")
	_expect(bool(live_snapshot.get("boost_charging_pending_dash_refund", false)), "builder should preserve live Boost Charging refund")
	_expect(int(live_snapshot.get("boost_charging_token_index", -1)) == 1, "builder should preserve live Boost Charging token index")

	_verify_default_snapshot(builder.build_snapshot(FakeRegistry.new()), "missing dash state")
	_verify_default_snapshot(builder.build_snapshot(FakeRegistry.new({"smasher_dash_state": FakeBadDashState.new()})), "bad dash state")
	_verify_default_snapshot(builder.build_snapshot(null), "null registry")

	var effects_context: Dictionary = BattleUpdateEffectsContext.new().build_context(
		FakeOwner.new({
			"selected_character_type": "smasher",
			"battle_textures": {},
		}),
		live_registry
	)
	var context_snapshot: Dictionary = effects_context.get("dash_snapshot", {})
	_expect(int(context_snapshot.get("tokens", 0)) == 2, "effects context should merge live dash snapshot")
	_expect(bool(context_snapshot.get("boost_charging_pending_dash_refund", false)), "effects context should preserve Boost Charging refund")

	if _failures.is_empty():
		print("dash_snapshot_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_default_snapshot(snapshot: Dictionary, label: String) -> void:
	_expect(int(snapshot.get("tokens", -1)) == 0, "%s default should have zero tokens" % label)
	_expect(int(snapshot.get("max_tokens", 0)) == 1, "%s default should have one max token" % label)
	_expect(not bool(snapshot.get("active", true)), "%s default should be inactive" % label)
	_expect(not bool(snapshot.get("recovering", true)), "%s default should not recover" % label)
	_expect(float(snapshot.get("recovery_progress", 0.0)) == 1.0, "%s default should be fully recovered" % label)
	_expect(float(snapshot.get("recharge_frames", 0.0)) == 300.0, "%s default should keep 300 recharge frames" % label)
	_expect(not bool(snapshot.get("boost_charging_pending_dash_refund", true)), "%s default should not have Boost Charging refund" % label)
	_expect(not bool(snapshot.get("boost_charging_active", true)), "%s default should not have active Boost Charging visual" % label)
	_expect(float(snapshot.get("boost_charging_effect_duration", 0.0)) == 12.0, "%s default should keep Boost Charging effect duration" % label)
	_expect(int(snapshot.get("boost_charging_token_index", 0)) == -1, "%s default should not mark a Boost Charging token" % label)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
