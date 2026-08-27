extends SceneTree

const QUEUE_STATE_PATH := "res://scripts/characters/commando_supply_drop_payload_queue_state.gd"
const HOST_PATH := "res://scripts/characters/commando_supply_drop_state.gd"

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_begin_and_snapshot_isolation()
	_verify_zero_delay_chain_and_delta_carry()
	_verify_clear_and_restore()

	if _failures.is_empty():
		print("commando_supply_drop_payload_queue_state_refactor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(QUEUE_STATE_PATH), "Commando Supply Drop payload queue should have a focused state owner")
	if not FileAccess.file_exists(QUEUE_STATE_PATH):
		return
	var host_source := FileAccess.get_file_as_string(HOST_PATH)
	var owner_source := FileAccess.get_file_as_string(QUEUE_STATE_PATH)
	_expect(
		host_source.find("const CommandoSupplyDropPayloadQueueState := preload(\"%s\")" % QUEUE_STATE_PATH) >= 0,
		"Supply Drop host should preload the focused payload queue state"
	)
	_expect(
		host_source.find("var _payload_queue_state: Object = CommandoSupplyDropPayloadQueueState.new()") >= 0,
		"Supply Drop host should retain one payload queue state instance"
	)
	for marker in [
		"func reset(",
		"func begin(",
		"func start_flight(",
		"func advance_timer(",
		"func is_ready(",
		"func resolve_ready_drops(",
		"func clear_pending(",
		"func get_snapshot(",
		"func restore(",
	]:
		_expect(owner_source.find(marker) >= 0, "payload queue owner should implement %s" % marker)
	for moved_marker in [
		"var payload_timer :=",
		"var drop_timing_pattern",
		"var pending_drop:",
		"var pending_drops:",
		"var pending_drop_delays:",
		"func _resolve_next_drop(",
		"func _peek_next_drop_delay(",
	]:
		_expect(host_source.find(moved_marker) < 0, "Supply Drop host should not retain payload queue marker %s" % moved_marker)
	_expect(
		host_source.find("_payload_queue_state.begin(deps)") >= 0,
		"activation should delegate queue construction to the focused owner"
	)
	_expect(
		host_source.find("_payload_queue_state.advance_timer(payload_timer_delta)") >= 0,
		"flight update should delegate drop-window time to the focused owner"
	)
	_expect(
		host_source.find("_payload_queue_state.resolve_ready_drops()") >= 0,
		"host dispatch should consume ready payloads from the focused owner"
	)


func _verify_begin_and_snapshot_isolation() -> void:
	var state: Object = _new_state()
	if state == null:
		return
	var forced_payloads := [
		{"type": "rental_weapon", "weapon_id": "net_gun"},
		{"type": "field_item", "item_id": "grenade"},
	]
	state.begin({
		"commando_supply_drop_payload_count": 2,
		"commando_supply_drop_forced_payloads": forced_payloads,
		"commando_supply_drop_timing_pattern": "burst",
		"commando_supply_drop_payload_delays": [0.1, 0.2],
	})
	var snapshot: Dictionary = state.get_snapshot()
	_expect(str(snapshot.get("drop_timing_pattern", "")) == "burst", "queue should retain the normalized timing pattern")
	_expect((snapshot.get("pending_drops", []) as Array).size() == 2, "queue should retain every planned payload")
	_expect((snapshot.get("pending_drop_delays", []) as Array).size() == 2, "queue should retain one delay per payload")
	_expect(str((snapshot.get("pending_drop", {}) as Dictionary).get("weapon_id", "")) == "net_gun", "queue should expose its next payload facade")
	(forced_payloads[0] as Dictionary)["weapon_id"] = "changed"
	_expect(str((state.get_snapshot().get("pending_drop", {}) as Dictionary).get("weapon_id", "")) == "net_gun", "queue should not alias configured payload dictionaries")
	(snapshot.get("pending_drops", []) as Array)[0]["weapon_id"] = "snapshot_changed"
	_expect(str((state.get_snapshot().get("pending_drop", {}) as Dictionary).get("weapon_id", "")) == "net_gun", "queue snapshots should deep-copy mutable payloads")


func _verify_zero_delay_chain_and_delta_carry() -> void:
	var state: Object = _new_state()
	if state == null:
		return
	state.begin({
		"commando_supply_drop_payload_count": 3,
		"commando_supply_drop_forced_payloads": [
			{"type": "field_item", "item_id": "grenade"},
			{"type": "field_item", "item_id": "flare"},
			{"type": "field_item", "item_id": "dynamite"},
		],
		"commando_supply_drop_payload_delays": [0.1, 0.0, 0.2],
	})
	state.start_flight()
	_expect(not state.is_ready(), "initial payload should wait for its configured flight delay")
	state.advance_timer(0.09)
	_expect(not state.is_ready(), "payload should remain pending before the initial delay edge")
	state.advance_timer(0.02)
	_expect(state.is_ready(), "payload should become ready after crossing its initial delay")
	var first_batch: Array = state.resolve_ready_drops()
	_expect(first_batch.size() == 2, "zero-delay second payload should release in the same frame")
	if first_batch.size() >= 1:
		_expect(str((first_batch[0] as Dictionary).get("item_id", "")) == "grenade", "first resolved payload should keep queue order")
	if first_batch.size() >= 2:
		_expect(str((first_batch[1] as Dictionary).get("item_id", "")) == "flare", "zero-delay chained payload should keep queue order")
	var after_first: Dictionary = state.get_snapshot()
	_expect((after_first.get("pending_drops", []) as Array).size() == 1, "chained batch should leave only the final payload")
	_expect(is_equal_approx(float(after_first.get("timer", 0.0)), 0.19), "timer should carry the 0.01-second overshoot into the next delay")
	state.advance_timer(0.18)
	_expect(not state.is_ready(), "final payload should remain pending before carried timer expires")
	state.advance_timer(0.02)
	var final_batch: Array = state.resolve_ready_drops()
	_expect(final_batch.size() == 1, "final payload should resolve once its carried delay expires")
	_expect(state.get_pending_count() == 0, "resolved queue should report no pending payloads")
	_expect((state.get_snapshot().get("pending_drop", {}) as Dictionary).is_empty(), "resolved queue should clear the next-payload facade")


func _verify_clear_and_restore() -> void:
	var state: Object = _new_state()
	if state == null:
		return
	state.begin({
		"commando_supply_drop_payload_count": 1,
		"commando_supply_drop_timing_pattern": "delayed",
		"commando_supply_drop_payload_delays": [0.4],
	})
	state.start_flight()
	state.clear_pending()
	var cleared: Dictionary = state.get_snapshot()
	_expect(is_zero_approx(float(cleared.get("timer", -1.0))), "aircraft loss should clear the payload timer")
	_expect((cleared.get("pending_drops", []) as Array).is_empty(), "aircraft loss should clear pending payloads")
	_expect(str(cleared.get("drop_timing_pattern", "")) == "delayed", "aircraft loss should preserve the selected timing label like the legacy host")

	state.restore({
		"timer": 0.3,
		"drop_timing_pattern": "burst",
		"pending_drop": {"id": 1},
		"pending_drops": [{"id": 1}, {"id": 2}],
		"pending_drop_delays": [0.3, 0.4],
	}, true)
	_expect(is_equal_approx(float(state.get_snapshot().get("timer", 0.0)), 0.3), "spawned-aircraft restore should retain its payload timer")
	_expect(state.get_pending_count() == 2, "restore should retain the pending payload queue")
	state.restore({
		"timer": 0.3,
		"pending_drops": [{"id": 1}],
		"pending_drop_delays": [0.3],
	}, false)
	_expect(is_zero_approx(float(state.get_snapshot().get("timer", -1.0))), "pre-arrival restore should leave payload timing stopped")


func _new_state() -> Object:
	if not FileAccess.file_exists(QUEUE_STATE_PATH):
		return null
	var state_script: Script = load(QUEUE_STATE_PATH)
	return state_script.new()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
