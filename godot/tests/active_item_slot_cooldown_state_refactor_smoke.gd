extends SceneTree

const CONTROLLER_PATH := "res://scripts/items/active_item_slot_controller.gd"
const COOLDOWN_STATE_PATH := "res://scripts/items/active_item_slot_cooldown_state.gd"
const ActiveItemSlotController := preload(CONTROLLER_PATH)

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	if FileAccess.file_exists(COOLDOWN_STATE_PATH):
		_verify_cooldown_state_behavior()
		_verify_controller_compatibility_surface()

	if _failures.is_empty():
		print("active_item_slot_cooldown_state_refactor_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_owner_boundary() -> void:
	_expect(
		FileAccess.file_exists(COOLDOWN_STATE_PATH),
		"active-item slot cooldown timing should have a focused state owner"
	)
	if not FileAccess.file_exists(COOLDOWN_STATE_PATH):
		return
	var controller_source := FileAccess.get_file_as_string(CONTROLLER_PATH)
	var state_source := FileAccess.get_file_as_string(COOLDOWN_STATE_PATH)
	_expect(
		controller_source.find("const ActiveItemSlotCooldownState := preload(\"%s\")" % COOLDOWN_STATE_PATH) >= 0,
		"slot controller should preload the focused cooldown state owner"
	)
	_expect(
		controller_source.find("var _cooldown_state: Object = ActiveItemSlotCooldownState.new()") >= 0,
		"slot controller should retain exactly one cooldown state owner"
	)
	_expect(
		controller_source.find("var last_item_use_msec: int = -1000000") < 0
		and controller_source.find("var cooldown_pause_started_msec := -1") < 0,
		"slot controller should not retain duplicate cooldown storage"
	)
	_expect(
		controller_source.find("[AIDBG]") < 0 and controller_source.find("_aidbg_") < 0,
		"retired active-item diagnostic branches should not remain in the runtime hot path"
	)
	for marker in [
		"func reset() -> void:",
		"func reset_for_stage_transition(active_item_slots: Array) -> Array:",
		"func pause(time_now: int) -> void:",
		"func resume(time_now: int, active_item_slots: Array = []) -> Array:",
		"func is_item_ready(",
		"func start_global_cooldown(now_msec: int) -> void:",
		"func propagate_global_cooldown(active_item_slots: Array, now_msec: int) -> void:",
	]:
		_expect(state_source.find(marker) >= 0, "focused cooldown state should implement %s" % marker)


func _verify_cooldown_state_behavior() -> void:
	var state_script := load(COOLDOWN_STATE_PATH) as Script
	_expect(state_script != null, "focused cooldown state script should load")
	if state_script == null:
		return
	var state: Object = state_script.new()
	state.last_item_use_msec = 1000
	state.pause(3000)
	var source_slots: Array = [
		{"name": "dash_boost", "last_use_msec": 2000, "rolls": {"value": 1}},
	]
	var resumed_slots: Array = state.resume(8000, source_slots)
	_expect(int(state.last_item_use_msec) == 6000, "pause resume should shift the global cooldown anchor")
	_expect(int(resumed_slots[0].get("last_use_msec", 0)) == 7000, "pause resume should shift per-item cooldown anchors")
	_expect(int(source_slots[0].get("last_use_msec", 0)) == 2000, "pause resume should not mutate caller slot data")

	state.last_item_use_msec = 9000
	_expect(
		not bool(state.is_item_ready({"last_use_msec": -1}, 10000, 2000, true)),
		"global cooldown should block a fresh individual item"
	)
	_expect(
		bool(state.is_item_ready({"last_use_msec": -1}, 10000, 2000, false)),
		"no-global-cooldown items should ignore the shared anchor"
	)
	_expect(
		not bool(state.is_item_ready({"last_use_msec": 9500}, 10000, 2000, false)),
		"per-item cooldown should remain authoritative without a global cooldown"
	)

	var manual_slots: Array = [
		{"name": "banana", "last_use_msec": -1},
		{"name": "brick_wall", "last_use": -1},
	]
	state.start_global_cooldown(12000)
	state.propagate_global_cooldown(manual_slots, 12000)
	_expect(int(state.last_item_use_msec) == 12000, "manual use should advance the global anchor")
	_expect(
		int(manual_slots[0].get("last_use_msec", -1)) == 12000
		and int(manual_slots[1].get("last_use_msec", -1)) == 12000,
		"manual use should propagate the shared timestamp to every remaining slot"
	)

	var transition_source: Array = [
		{"item_id": "long_boost", "last_use_msec": 5000, "rolls": {"value": 2}},
		null,
	]
	var cleaned: Array = state.reset_for_stage_transition(transition_source)
	_expect(int(state.last_item_use_msec) == -1000000, "stage transition should clear the focused global anchor")
	_expect(str(cleaned[0].get("name", "")) == "long_boost", "stage transition should preserve item-id normalization")
	_expect(int(cleaned[0].get("last_use_msec", 0)) == -1, "stage transition should clear per-item cooldown")
	_expect(int(transition_source[0].get("last_use_msec", 0)) == 5000, "stage reset should deep-copy caller slot data")


func _verify_controller_compatibility_surface() -> void:
	var controller: Object = ActiveItemSlotController.new()
	var state: Object = controller.get("_cooldown_state")
	_expect(state != null, "slot controller should expose its focused cooldown owner for diagnostics")
	if state == null:
		return
	controller.last_item_use_msec = 3210
	_expect(int(state.last_item_use_msec) == 3210, "legacy global-anchor writes should forward to the focused owner")
	controller.cooldown_pause_started_msec = 4560
	_expect(
		int(state.cooldown_pause_started_msec) == 4560,
		"legacy pause-marker writes should forward to the focused owner"
	)
	controller.reset()
	_expect(
		int(state.last_item_use_msec) == -1000000
		and int(state.cooldown_pause_started_msec) == -1,
		"controller reset should reset the focused cooldown owner"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
