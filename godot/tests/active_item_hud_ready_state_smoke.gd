extends SceneTree

const ActiveItemHudLayout := preload("res://scripts/hud/active_item_hud_layout.gd")
const ActiveItemHudSlotRenderer := preload("res://scripts/hud/active_item_hud_slot_renderer.gd")
const ActiveItemHudState := preload("res://scripts/hud/active_item_hud_state.gd")


func _init() -> void:
	_verify_ready_predicate()
	_verify_pickup_pop_lifecycle()
	_verify_pickup_pop_ignores_shifted_slots()
	_verify_layout_unchanged()
	print("active_item_hud_ready_state_smoke: ok")
	quit(0)


func _verify_ready_predicate() -> void:
	_expect(
		ActiveItemHudSlotRenderer.is_slot_ready({"name": "banana"}, {"cooldown_remaining_ratio": 0.0, "throw_lock_remaining_seconds": 0}),
		"active item slot with an item and no cooldown or throw-lock should be ready"
	)
	_expect(
		not ActiveItemHudSlotRenderer.is_slot_ready({}, {"cooldown_remaining_ratio": 0.0, "throw_lock_remaining_seconds": 0}),
		"empty active item slot should not be ready"
	)
	_expect(
		not ActiveItemHudSlotRenderer.is_slot_ready({"name": "banana"}, {"cooldown_remaining_ratio": 0.1, "throw_lock_remaining_seconds": 0}),
		"active item slot on cooldown should not be ready"
	)
	_expect(
		not ActiveItemHudSlotRenderer.is_slot_ready({"name": "banana"}, {"cooldown_remaining_ratio": 0.0, "throw_lock_remaining_seconds": 1}),
		"active item slot with throw-lock should not be ready"
	)


func _verify_pickup_pop_lifecycle() -> void:
	var hud_state := ActiveItemHudState.new()
	var item := {"name": "banana", "last_use_msec": -1}
	var first_status: Dictionary = hud_state.get_slot_status(0, item, 1000, 5000)
	_expect(
		is_equal_approx(float(first_status.get("pickup_pop_pulse", -1.0)), 0.0),
		"newly observed active item should start its pickup pop envelope at zero"
	)
	var mid_status: Dictionary = hud_state.get_slot_status(0, item, 1070, 5070)
	_expect(
		float(mid_status.get("pickup_pop_pulse", 0.0)) > 0.0,
		"newly observed active item should expose a pickup pop pulse inside the envelope"
	)
	var expired_status: Dictionary = hud_state.get_slot_status(0, item, 1400, 5400)
	_expect(
		is_equal_approx(float(expired_status.get("pickup_pop_pulse", -1.0)), 0.0),
		"same active item should stop popping after the pickup pop duration"
	)
	var same_item_status: Dictionary = hud_state.get_slot_status(0, item, 1450, 5450)
	_expect(
		is_equal_approx(float(same_item_status.get("pickup_pop_pulse", -1.0)), 0.0),
		"same active item should not retrigger pickup pop after expiry"
	)
	hud_state.get_slot_status(0, {}, 1480, 5480)
	var same_name_repickup_status: Dictionary = hud_state.get_slot_status(0, item, 1500, 5500)
	_expect(
		is_equal_approx(float(same_name_repickup_status.get("pickup_pop_pulse", -1.0)), 0.0),
		"same-name active item should start a fresh pickup pop after the slot was empty"
	)
	var same_name_repickup_mid_status: Dictionary = hud_state.get_slot_status(0, item, 1570, 5570)
	_expect(
		float(same_name_repickup_mid_status.get("pickup_pop_pulse", 0.0)) > 0.0,
		"same-name active item should pulse after an empty-to-filled transition"
	)
	var replacement_status: Dictionary = hud_state.get_slot_status(0, {"name": "soap", "last_use_msec": -1}, 1600, 5600)
	_expect(
		is_equal_approx(float(replacement_status.get("pickup_pop_pulse", -1.0)), 0.0),
		"in-place replacement should not start a fresh pickup pop envelope"
	)
	var replacement_mid_status: Dictionary = hud_state.get_slot_status(0, {"name": "soap", "last_use_msec": -1}, 1670, 5670)
	_expect(
		is_equal_approx(float(replacement_mid_status.get("pickup_pop_pulse", -1.0)), 0.0),
		"in-place replacement should remain pickup-pop suppressed"
	)
	hud_state.reset()
	var reset_status: Dictionary = hud_state.get_slot_status(0, {"name": "soap", "last_use_msec": -1}, 2000, 6000)
	_expect(
		is_equal_approx(float(reset_status.get("pickup_pop_pulse", -1.0)), 0.0),
		"HUD reset should clear pickup pop state"
	)
	_expect(
		hud_state.get_pickup_pop().has(0),
		"HUD reset should allow a newly observed item to register a fresh pop entry"
	)


func _verify_pickup_pop_ignores_shifted_slots() -> void:
	var hud_state := ActiveItemHudState.new()
	var banana := {"name": "banana", "last_use_msec": -1}
	var soap := {"name": "soap", "last_use_msec": -1}
	var wall := {"name": "wall", "last_use_msec": -1}

	hud_state.get_slot_status(0, banana, 1000, 5000)
	hud_state.get_slot_status(1, soap, 1000, 5000)
	hud_state.get_slot_status(2, wall, 1000, 5000)
	hud_state.get_slot_status(0, banana, 1400, 5400)
	hud_state.get_slot_status(1, soap, 1400, 5400)
	hud_state.get_slot_status(2, wall, 1400, 5400)

	var shifted_soap_status: Dictionary = hud_state.get_slot_status(0, soap, 1500, 5500)
	var shifted_wall_status: Dictionary = hud_state.get_slot_status(1, wall, 1500, 5500)
	_expect(
		is_equal_approx(float(shifted_soap_status.get("pickup_pop_pulse", -1.0)), 0.0),
		"array-compacted active item should not pop as a fresh pickup"
	)
	_expect(
		is_equal_approx(float(shifted_wall_status.get("pickup_pop_pulse", -1.0)), 0.0),
		"second array-compacted active item should not pop as a fresh pickup"
	)

	var shifted_soap_later_status: Dictionary = hud_state.get_slot_status(0, soap, 1570, 5570)
	var shifted_wall_later_status: Dictionary = hud_state.get_slot_status(1, wall, 1570, 5570)
	_expect(
		is_equal_approx(float(shifted_soap_later_status.get("pickup_pop_pulse", -1.0)), 0.0),
		"array-compacted active item should stay pickup-pop suppressed"
	)
	_expect(
		is_equal_approx(float(shifted_wall_later_status.get("pickup_pop_pulse", -1.0)), 0.0),
		"second array-compacted active item should stay pickup-pop suppressed"
	)


func _verify_layout_unchanged() -> void:
	_expect(
		is_equal_approx(float(ActiveItemHudLayout.ACTIVE_ITEM_SLOT_BASE_SIZE), 42.0),
		"active item HUD prominence slice should not raise slot size"
	)
	var layout_builder := ActiveItemHudLayout.new()
	var layout: Dictionary = layout_builder.build_layout(
		Vector2(1280.0, 900.0),
		Vector2(260.0, 60.0),
		Vector2(760.0, 750.0),
		760.0,
		3,
		3
	)
	_expect(bool(layout.get("visible", false)), "active item HUD should remain visible in the desktop bottom letterbox")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
