extends SceneTree

# Seals the "fly into the empty slot" active-item acquisition animation state machine
# in ActiveItemHudState:
#   - a registered flight reports incoming ONLY inside its travel window and ONLY for
#     its own slot,
#   - the destination slot exposes flight_incoming so the renderer draws it empty until
#     landing,
#   - the pickup pop is DEFERRED to the landing frame (0 while airborne, pulses after),
#   - get_active_slot_flights returns travelling flights with progress and prunes landed
#     ones,
#   - reset() clears flights.
const ActiveItemHudState := preload("res://scripts/hud/active_item_hud_state.gd")

const DURATION := ActiveItemHudState.SLOT_FLIGHT_DURATION_MS
const POP := ActiveItemHudState.PICKUP_POP_DURATION_MS


func _init() -> void:
	_verify_incoming_window()
	_verify_status_flag_and_deferred_pop()
	_verify_active_flights_progress_and_prune()
	_verify_color_default()
	_verify_reset_clears_flights()
	print("active_item_slot_flight_smoke: ok")
	quit(0)


func _verify_incoming_window() -> void:
	var hud_state := ActiveItemHudState.new()
	var item := {"name": "banana", "last_use_msec": -1}
	hud_state.register_slot_flight(item, 0, Vector2(300.0, 600.0), 1000)

	_expect(hud_state.is_slot_flight_incoming(0, 1000), "flight should be incoming on the takeoff frame")
	_expect(hud_state.is_slot_flight_incoming(0, 1000 + DURATION - 1), "flight should stay incoming just before landing")
	_expect(not hud_state.is_slot_flight_incoming(0, 1000 + DURATION), "flight should stop being incoming once it lands")
	_expect(not hud_state.is_slot_flight_incoming(1, 1000), "flight targeting slot 0 must not mark a different slot incoming")


func _verify_status_flag_and_deferred_pop() -> void:
	var hud_state := ActiveItemHudState.new()
	var item := {"name": "banana", "last_use_msec": -1}
	hud_state.register_slot_flight(item, 0, Vector2(300.0, 600.0), 1000)

	var takeoff: Dictionary = hud_state.get_slot_status(0, item, 1000, 5000)
	_expect(bool(takeoff.get("flight_incoming", false)), "destination slot status should report flight_incoming on takeoff")
	_expect(
		is_equal_approx(float(takeoff.get("pickup_pop_pulse", -1.0)), 0.0),
		"pickup pop must stay silent while the item is still flying in"
	)

	var mid: Dictionary = hud_state.get_slot_status(0, item, 1200, 5200)
	_expect(bool(mid.get("flight_incoming", false)), "slot should remain flight_incoming mid-travel")
	_expect(
		is_equal_approx(float(mid.get("pickup_pop_pulse", -1.0)), 0.0),
		"pickup pop must remain deferred while airborne"
	)

	var landed: Dictionary = hud_state.get_slot_status(0, item, 1000 + DURATION, 5000 + DURATION)
	_expect(not bool(landed.get("flight_incoming", true)), "slot should no longer be flight_incoming after landing")

	var settling: Dictionary = hud_state.get_slot_status(0, item, 1000 + DURATION + 40, 5000 + DURATION + 40)
	_expect(
		float(settling.get("pickup_pop_pulse", 0.0)) > 0.0,
		"pickup pop should fire once the flight lands (deferred landing pop)"
	)

	var faded: Dictionary = hud_state.get_slot_status(0, item, 1000 + DURATION + POP + 10, 5000 + DURATION + POP + 10)
	_expect(
		is_equal_approx(float(faded.get("pickup_pop_pulse", -1.0)), 0.0),
		"pickup pop should end after its post-landing envelope"
	)

	var empty_status: Dictionary = hud_state.get_slot_status(0, {}, 1050, 5050)
	_expect(not bool(empty_status.get("flight_incoming", true)), "an empty slot must never report flight_incoming")


func _verify_active_flights_progress_and_prune() -> void:
	var hud_state := ActiveItemHudState.new()
	var item := {"name": "banana", "last_use_msec": -1, "color": Color(1.0, 0.0, 0.0)}
	hud_state.register_slot_flight(item, 2, Vector2(120.0, 400.0), 1000)

	var mid_flights: Array = hud_state.get_active_slot_flights(1000 + DURATION / 2)
	_expect(mid_flights.size() == 1, "one travelling flight should be active mid-window")
	var flight: Dictionary = mid_flights[0]
	_expect(int(flight.get("slot_index", -1)) == 2, "active flight should carry its destination slot index")
	_expect(
		abs(float(flight.get("progress", -1.0)) - 0.5) < 0.05,
		"active flight progress should track the elapsed travel fraction"
	)
	_expect(
		Vector2(flight.get("source_field_pos", Vector2.ZERO)).is_equal_approx(Vector2(120.0, 400.0)),
		"active flight should carry the field pickup position"
	)

	var landed_flights: Array = hud_state.get_active_slot_flights(1000 + DURATION)
	_expect(landed_flights.is_empty(), "landed flights should be returned as empty")
	_expect(hud_state.get_slot_flights().is_empty(), "get_active_slot_flights should prune landed flights from state")


func _verify_color_default() -> void:
	var hud_state := ActiveItemHudState.new()
	hud_state.register_slot_flight({"name": "soap", "last_use_msec": -1}, 0, Vector2(200.0, 500.0), 1000)
	var flights: Array = hud_state.get_active_slot_flights(1100)
	_expect(flights.size() == 1, "colorless item should still register a flight")
	var color: Color = flights[0].get("color", Color.BLACK)
	_expect(
		color.is_equal_approx(ActiveItemHudState.DEFAULT_FLIGHT_COLOR),
		"a flight for an item without a color should fall back to the default flight color"
	)


func _verify_reset_clears_flights() -> void:
	var hud_state := ActiveItemHudState.new()
	hud_state.register_slot_flight({"name": "banana", "last_use_msec": -1}, 0, Vector2(300.0, 600.0), 1000)
	_expect(not hud_state.get_slot_flights().is_empty(), "flight should register before reset")
	hud_state.reset()
	_expect(hud_state.get_slot_flights().is_empty(), "reset should clear in-flight acquisition animations")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
