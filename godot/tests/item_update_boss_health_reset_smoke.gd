extends SceneTree

const BattleSceneItemUpdateDriver := preload("res://scripts/core/battle_scene_item_update_driver.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var data: Dictionary = {
		"current_stage": 11,
		"gameplay_frame_counter": 10,
		"boss_max_health": 15,
		"boss_current_health": 3,
		"boss_health_damage_units": 12,
		"boss_defeated_by_health": true,
	}

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		data[str(property)] = value
		return true


class FakeMythicRuntime:
	extends RefCounted

	var update_calls := 0
	var reset_ready := true

	func update(_owner: Object, _registry: Object, _delta: float) -> void:
		update_calls += 1

	func consume_foul_whistle_reset_ready() -> bool:
		var was_ready := reset_ready
		reset_ready = false
		return was_ready


class FakeBallDriver:
	extends RefCounted

	var reset_calls := 0

	func reset_ball(_owner: Object, _registry: Object) -> void:
		reset_calls += 1


class FakeRoundState:
	extends RefCounted

	var player_serves := false
	var reset_wait_calls := 0

	func set_player_serves(value: bool) -> void:
		player_serves = value

	func reset_round_wait() -> void:
		reset_wait_calls += 1


class FakeBossHealthFlow:
	extends RefCounted

	var reset_calls := 0

	func reset_round_health(owner: Object) -> void:
		reset_calls += 1
		owner.set("boss_current_health", owner.get("boss_max_health"))
		owner.set("boss_health_damage_units", 0)
		owner.set("boss_defeated_by_health", false)


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_mythic_update_once_when_owner_frame_changes()
	_verify_mythic_update_signature_check_is_cached()

	var owner := FakeOwner.new()
	var mythic := FakeMythicRuntime.new()
	var ball := FakeBallDriver.new()
	var round_state := FakeRoundState.new()
	var boss_health := FakeBossHealthFlow.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": mythic,
		"battle_scene_ball_update_driver": ball,
		"round_flow_state": round_state,
		"battle_scene_boss_health_flow": boss_health,
	})

	BattleSceneItemUpdateDriver.new().update_items(owner, registry, 1.0 / 60.0)
	_expect(mythic.update_calls == 1, "item update should update the mythic runtime")
	_expect(ball.reset_calls == 1, "foul-whistle ready state should reset the ball")
	_expect(boss_health.reset_calls == 1, "foul-whistle ready state should reset boss health with the ball")
	_expect(int(owner.data.get("boss_current_health", 0)) == 15, "boss health should refill after foul-whistle delayed reset")
	_expect(int(owner.data.get("boss_health_damage_units", -1)) == 0, "boss damage units should clear after foul-whistle delayed reset")
	_expect(not bool(owner.data.get("boss_defeated_by_health", true)), "pending boss-health defeat should clear after foul-whistle delayed reset")
	_expect(round_state.player_serves and round_state.reset_wait_calls == 1, "foul-whistle reset should return to player serve wait")

	if _failures.is_empty():
		print("item_update_boss_health_reset_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_mythic_update_once_when_owner_frame_changes() -> void:
	var owner := FakeOwner.new()
	var mythic := FakeMythicRuntime.new()
	mythic.reset_ready = false
	var registry := FakeRegistry.new({
		"mythic_item_runtime": mythic,
	})
	var driver := BattleSceneItemUpdateDriver.new()

	driver.update_mythic_items(owner, registry, 1.0 / 60.0)
	owner.set("gameplay_frame_counter", int(owner.get("gameplay_frame_counter")) + 1)
	driver.update_items(owner, registry, 1.0 / 60.0)

	_expect(mythic.update_calls == 1, "mythic runtime should update once per physics tick even if owner gameplay_frame_counter changes mid-flow")


func _verify_mythic_update_signature_check_is_cached() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_item_update_driver.gd")
	_expect(
		source.find("_get_method_argument_count(mythic_item_runtime, \"update\") >= 4") >= 0,
		"mythic update signature check should use the cached method-argument helper"
	)
	_expect(
		source.find("_method_accepts_argument_count(mythic_item_runtime, \"update\", 4)") < 0,
		"mythic update must not scan get_method_list every physics tick"
	)
	_expect(
		source.find("func _method_accepts_argument_count") < 0,
		"item update driver should keep hot-path method signature checks on the cached helper"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
