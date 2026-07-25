extends SceneTree

const SnapshotCodec := preload("res://scripts/characters/commando_supply_drop_snapshot_codec.gd")
const CommandoSupplyDropState := preload("res://scripts/characters/commando_supply_drop_state.gd")

var failure_count := 0


func _init() -> void:
	_verify_save_snapshot_isolation()
	_verify_restore_normalization()
	_verify_crash_audio_gate()
	_verify_state_facade_contract()

	if failure_count > 0:
		quit(1)
		return
	print("commando_supply_drop_snapshot_codec_smoke: ok")
	quit(0)


func _verify_save_snapshot_isolation() -> void:
	var runtime_snapshot := {
		"pending_drops": [{"type": "field_item", "item_id": "ammo_box"}],
	}
	var saved := SnapshotCodec.build_save_snapshot(runtime_snapshot)
	_expect(int(saved.get("version", 0)) == SnapshotCodec.SAVE_SNAPSHOT_VERSION, "save codec should stamp the public snapshot version")
	(saved["pending_drops"] as Array)[0]["item_id"] = "changed"
	_expect(str(runtime_snapshot["pending_drops"][0].get("item_id", "")) == "ammo_box", "save codec should deep-copy mutable runtime data")


func _verify_restore_normalization() -> void:
	var source_pending_drops := [{"id": 1}, "invalid", {"id": 2}]
	var normalized := SnapshotCodec.normalize_for_restore(
		{
			"active": true,
			"aircraft_audio_active": true,
			"flight_elapsed": 0.25,
			"aircraft_direction": "invalid",
			"hold_time": -2.0,
			"flight_duration": 0.5,
			"drop_timing_pattern": "invalid",
			"pending_drops": source_pending_drops,
			"pending_drop_delays": [-1.0],
		},
		{
			"radio_duration": 0.35,
			"aircraft_pos": Vector2(-360.0, 56.0),
			"aircraft_crash_target_pos": Vector2.ZERO,
		},
		12.0,
		0.28
	)
	_expect(bool(normalized.get("aircraft_spawned", false)), "legacy snapshot should infer a spawned aircraft from active flight state")
	_expect(bool(normalized.get("aircraft_audio_active", false)), "active inferred aircraft should restore its loop gate")
	_expect(float(normalized.get("hold_time", -1.0)) == 0.0, "negative timers should clamp to zero")
	_expect(float(normalized.get("flight_duration", 0.0)) == 12.0, "flight duration should keep the runtime travel minimum")
	_expect(str(normalized.get("aircraft_direction", "")) == "left_to_right", "unknown direction should normalize to the default lane")
	_expect(str(normalized.get("drop_timing_pattern", "")) == "normal", "unknown payload timing should normalize through the resolver policy")
	var drops: Array = normalized.get("pending_drops", [])
	var delays: Array = normalized.get("pending_drop_delays", [])
	_expect(drops.size() == 2, "restore codec should filter non-dictionary payload entries")
	_expect(delays.size() == drops.size(), "restore codec should pad missing payload delays")
	_expect(float(delays[0]) == 0.0 and is_equal_approx(float(delays[1]), 0.28), "payload delays should clamp and pad with the shared interval")

	(source_pending_drops[0] as Dictionary)["id"] = 99
	_expect(int((normalized.get("pending_drops", []) as Array)[0].get("id", 0)) == 1, "restore codec should deep-copy payload dictionaries from the source snapshot")


func _verify_crash_audio_gate() -> void:
	var normalized := SnapshotCodec.normalize_for_restore(
		{
			"active": true,
			"aircraft_spawned": true,
			"aircraft_audio_active": true,
			"aircraft_crashing": true,
		},
		{},
		1.0,
		0.28
	)
	_expect(not bool(normalized.get("aircraft_audio_active", true)), "crashing aircraft must not restart the flight loop")


func _verify_state_facade_contract() -> void:
	var state: Object = CommandoSupplyDropState.new()
	var snapshot: Dictionary = state.get_save_snapshot()
	_expect(int(snapshot.get("version", 0)) == CommandoSupplyDropState.SAVE_SNAPSHOT_VERSION, "state facade should preserve its public save version alias")
	var empty_result: Dictionary = state.apply_save_snapshot({})
	_expect(not bool(empty_result.get("restored", true)), "state facade should still reject empty snapshots")
	_expect(str(empty_result.get("reason", "")) == "empty_snapshot", "empty snapshot rejection reason should remain stable")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
