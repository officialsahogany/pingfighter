extends SceneTree

const CommandoFirearmControlState := preload("res://scripts/characters/commando_firearm_control_state.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


class FakeRoundState:
	extends RefCounted

	var waiting_for_serve := false

	func is_waiting_for_serve() -> bool:
		return waiting_for_serve


class FakeSelectWeaponController:
	extends RefCounted

	var weapon_id := "ak47"
	var can_select := true
	var select_calls := 0
	var last_now_msec := -1

	func get_current_weapon_data() -> Dictionary:
		return {"weapon_id": weapon_id}

	func select_base_weapon(now_msec: int = -1) -> bool:
		select_calls += 1
		last_now_msec = now_msec
		if can_select:
			weapon_id = "pistol"
		return can_select


class FakeSetOnlyWeaponController:
	extends RefCounted

	var weapon_id := "bazooka"
	var set_calls := 0

	func get_current_weapon_data() -> Dictionary:
		return {"weapon_id": weapon_id}

	func set_current_weapon(next_weapon_id: String) -> bool:
		set_calls += 1
		weapon_id = next_weapon_id
		return true


func _init() -> void:
	_verify_direct_control_state()
	_verify_runtime_delegates_control_state()

	if _failures.is_empty():
		print("commando_firearm_control_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_control_state() -> void:
	_expect(not CommandoFirearmControlState.needs_effect_update(false, 0, 0.0), "effect update gate should default false")
	_expect(CommandoFirearmControlState.needs_effect_update(true, 0, 0.0), "effect update gate should read visible effects")
	_expect(CommandoFirearmControlState.needs_effect_update(false, 1, 0.0), "effect update gate should read pending damage")
	_expect(CommandoFirearmControlState.needs_effect_update(false, 0, 1.0), "effect update gate should read pending gauge")

	_expect(not CommandoFirearmControlState.is_player_control_locked([0.0, 0.0], false, false), "control lock gate should default false")
	_expect(CommandoFirearmControlState.is_player_control_locked([0.0, 1.0], false, false), "control lock gate should read active timers")
	_expect(CommandoFirearmControlState.is_player_control_locked([0.0], true, false), "control lock gate should read support-call lock")
	_expect(CommandoFirearmControlState.is_player_control_locked([0.0], false, true), "control lock gate should read active drone lock")
	var lock_runtime := CommandoFirearmRuntime.new()
	lock_runtime.net_gun_control_lock_frames = 2.0
	_expect(CommandoFirearmControlState.is_runtime_player_control_locked(lock_runtime, false, false), "runtime control lock owner should read runtime timers")
	lock_runtime.net_gun_control_lock_frames = 0.0
	_expect(CommandoFirearmControlState.is_runtime_player_control_locked(lock_runtime, true, false), "runtime control lock owner should read support-call lock")

	_expect(is_equal_approx(CommandoFirearmControlState.get_movement_speed_multiplier(false, false, false, 0.5, 0.7), 1.0), "movement multiplier should default neutral")
	_expect(is_equal_approx(CommandoFirearmControlState.get_movement_speed_multiplier(false, true, false, 0.5, 0.7), 0.5), "movement multiplier should read AK-47 hold slow")
	_expect(is_equal_approx(CommandoFirearmControlState.get_movement_speed_multiplier(false, false, true, 0.5, 0.7), 1.0), "movement multiplier should ignore hooked-net state")
	_expect(is_equal_approx(CommandoFirearmControlState.get_movement_speed_multiplier(false, true, true, 0.5, 0.7), 0.5), "movement multiplier should keep AK-47 hold slow while ignoring hooked-net state")
	_expect(is_equal_approx(CommandoFirearmControlState.get_movement_speed_multiplier(true, false, false, 0.5, 0.7), 0.0), "movement multiplier should lock during active suicide drone")
	lock_runtime.ak47_trigger_held = true
	_expect(is_equal_approx(CommandoFirearmControlState.get_runtime_movement_speed_multiplier(lock_runtime, false, false, 0.5, 0.7), 0.5), "runtime movement owner should read AK-47 trigger hold")

	var clear_runtime := CommandoFirearmRuntime.new()
	clear_runtime.ak47_trigger_held = true
	clear_runtime.ak47_burst_shots_remaining = 2
	CommandoFirearmControlState.apply_ak47_trigger_cleared(clear_runtime)
	_expect(not clear_runtime.ak47_trigger_held, "AK-47 trigger clear owner should release trigger hold")
	_expect(clear_runtime.ak47_burst_shots_remaining == 0, "AK-47 trigger clear owner should clear burst state")

	var round_state := FakeRoundState.new()
	round_state.waiting_for_serve = true
	_expect(CommandoFirearmControlState.get_waiting_for_serve({}, {"round_state": round_state}), "serve-wait helper should prefer round state")
	_expect(CommandoFirearmControlState.get_waiting_for_serve({"waiting_for_serve": true}, {}), "serve-wait helper should read config fallback")
	_expect(not CommandoFirearmControlState.get_waiting_for_serve({}, {}), "serve-wait helper should default false without round state or config")
	var waiting_pressed: Dictionary = CommandoFirearmControlState.get_serve_wait_fire_suppression(
		{"action_pressed": true},
		{},
		{"round_state": round_state},
		false
	)
	_expect(bool(waiting_pressed.get("suppressed", false)), "serve-wait helper should suppress while waiting")
	_expect(bool(waiting_pressed.get("clear_input_state", false)), "serve-wait helper should request input clear while waiting")
	_expect(bool(waiting_pressed.get("suppressed_until_release", false)), "serve-wait helper should latch pressed input until release")
	round_state.waiting_for_serve = false
	var held_after_wait: Dictionary = CommandoFirearmControlState.get_serve_wait_fire_suppression(
		{"action_pressed": true},
		{},
		{"round_state": round_state},
		true
	)
	_expect(bool(held_after_wait.get("suppressed", false)), "serve-wait helper should keep held fire suppressed after wait ends")
	var released_after_wait: Dictionary = CommandoFirearmControlState.get_serve_wait_fire_suppression(
		{"action_pressed": false},
		{},
		{"round_state": round_state},
		true
	)
	_expect(not bool(released_after_wait.get("suppressed", true)), "serve-wait helper should release suppression after input release")
	_expect(not bool(released_after_wait.get("suppressed_until_release", true)), "serve-wait helper should clear release latch after input release")
	var serve_clear_runtime := CommandoFirearmRuntime.new()
	serve_clear_runtime.ak47_trigger_held = true
	serve_clear_runtime.ak47_burst_shots_remaining = 2
	serve_clear_runtime.ak47_last_action_pressed = true
	serve_clear_runtime.bowling_trap_last_action_pressed = true
	serve_clear_runtime.suicide_drone_last_action_pressed = true
	serve_clear_runtime.slingshot_charging = true
	serve_clear_runtime.slingshot_charge_timer_frames = 18.0
	serve_clear_runtime.slingshot_charge_level = 2
	serve_clear_runtime.slingshot_gauge_spent = 20.0
	serve_clear_runtime.slingshot_last_action_pressed = true
	serve_clear_runtime.slingshot_control_lock_frames = 9.0
	serve_clear_runtime.pistol_fire_delay_frames = 11.0
	serve_clear_runtime.pistol_control_lock_frames = 12.0
	serve_clear_runtime.pistol_pending_config = {"weapon_id": "pistol"}
	serve_clear_runtime.pistol_pending_weapon_id = "pistol"
	CommandoFirearmControlState.apply_serve_wait_firearm_input_cleared(serve_clear_runtime)
	_expect(not serve_clear_runtime.ak47_trigger_held, "serve-wait clear owner should clear AK-47 trigger hold")
	_expect(serve_clear_runtime.ak47_burst_shots_remaining == 0, "serve-wait clear owner should clear AK-47 burst state")
	_expect(not serve_clear_runtime.ak47_last_action_pressed, "serve-wait clear owner should clear AK-47 action edge")
	_expect(not serve_clear_runtime.bowling_trap_last_action_pressed, "serve-wait clear owner should clear bowling-trap action edge")
	_expect(not serve_clear_runtime.suicide_drone_last_action_pressed, "serve-wait clear owner should clear suicide-drone action edge")
	_expect(not serve_clear_runtime.slingshot_charging, "serve-wait clear owner should cancel slingshot charge")
	_expect(is_equal_approx(serve_clear_runtime.slingshot_charge_timer_frames, 0.0), "serve-wait clear owner should clear slingshot timer")
	_expect(serve_clear_runtime.slingshot_charge_level == 0, "serve-wait clear owner should clear slingshot charge level")
	_expect(is_equal_approx(serve_clear_runtime.slingshot_gauge_spent, 0.0), "serve-wait clear owner should clear slingshot spent gauge")
	_expect(not serve_clear_runtime.slingshot_last_action_pressed, "serve-wait clear owner should clear slingshot action edge")
	_expect(is_equal_approx(serve_clear_runtime.slingshot_control_lock_frames, 0.0), "serve-wait clear owner should clear slingshot lock")
	_expect(is_equal_approx(serve_clear_runtime.pistol_fire_delay_frames, 0.0), "serve-wait clear owner should clear pending pistol fire delay")
	_expect(is_equal_approx(serve_clear_runtime.pistol_control_lock_frames, 0.0), "serve-wait clear owner should clear pending pistol lock")
	_expect(serve_clear_runtime.pistol_pending_config.is_empty(), "serve-wait clear owner should clear pending pistol config")
	_expect(serve_clear_runtime.pistol_pending_weapon_id == "", "serve-wait clear owner should clear pending pistol weapon id")

	_expect(
		CommandoFirearmControlState.handle_firearm_reset_input({}, 10.0, FakeSelectWeaponController.new(), 123, clear_runtime, "pistol").is_empty(),
		"firearm reset owner should ignore snapshots without reset input"
	)
	_expect(
		CommandoFirearmControlState.handle_firearm_reset_input({"firearm_reset_just_pressed": true}, 10.0, null, 123, clear_runtime, "pistol").is_empty(),
		"firearm reset owner should ignore missing weapon controller"
	)
	var reset_runtime := CommandoFirearmRuntime.new()
	reset_runtime.ak47_trigger_held = true
	reset_runtime.ak47_burst_shots_remaining = 3
	reset_runtime.slingshot_charging = true
	reset_runtime.slingshot_charge_timer_frames = 21.0
	reset_runtime.slingshot_charge_level = 2
	reset_runtime.slingshot_gauge_spent = 30.0
	var select_controller := FakeSelectWeaponController.new()
	var reset_result: Dictionary = CommandoFirearmControlState.handle_firearm_reset_input(
		{"firearm_reset_just_pressed": true},
		77.0,
		select_controller,
		4567,
		reset_runtime,
		"pistol"
	)
	_expect(bool(reset_result.get("firearm_reset", false)), "firearm reset owner should expose reset result")
	_expect(str(reset_result.get("previous_weapon_id", "")) == "ak47", "firearm reset owner should report previous weapon")
	_expect(str(reset_result.get("current_weapon_id", "")) == "pistol", "firearm reset owner should report base weapon")
	_expect(bool(reset_result.get("weapon_switched", false)), "firearm reset owner should mark real weapon switches")
	_expect(is_equal_approx(float(reset_result.get("special_gauge", 0.0)), 77.0), "firearm reset owner should preserve special gauge")
	_expect(select_controller.select_calls == 1 and select_controller.last_now_msec == 4567, "firearm reset owner should use select_base_weapon with timing")
	_expect(not reset_runtime.ak47_trigger_held, "firearm reset owner should clear AK-47 trigger hold")
	_expect(reset_runtime.ak47_burst_shots_remaining == 0, "firearm reset owner should clear AK-47 burst state")
	_expect(not reset_runtime.slingshot_charging, "firearm reset owner should cancel active slingshot charge")
	var blocked_controller := FakeSelectWeaponController.new()
	blocked_controller.can_select = false
	var blocked_runtime := CommandoFirearmRuntime.new()
	blocked_runtime.ak47_trigger_held = true
	_expect(
		CommandoFirearmControlState.handle_firearm_reset_input({"firearm_reset_just_pressed": true}, 10.0, blocked_controller, 123, blocked_runtime, "pistol").is_empty(),
		"firearm reset owner should return empty when controller refuses reset"
	)
	_expect(blocked_runtime.ak47_trigger_held, "firearm reset owner should not clear runtime state when reset is refused")
	var set_only_controller := FakeSetOnlyWeaponController.new()
	var fallback_result: Dictionary = CommandoFirearmControlState.handle_firearm_reset_input(
		{"mouse_middle_just_pressed": true},
		12.0,
		set_only_controller,
		222,
		CommandoFirearmRuntime.new(),
		"pistol"
	)
	_expect(bool(fallback_result.get("firearm_reset", false)), "firearm reset owner should support set_current_weapon fallback")
	_expect(set_only_controller.set_calls == 1 and set_only_controller.weapon_id == "pistol", "firearm reset owner should set the base weapon through fallback")


func _verify_runtime_delegates_control_state() -> void:
	var runtime := CommandoFirearmRuntime.new()
	_expect(not CommandoFirearmControlState.needs_runtime_effect_update(null, false), "runtime effect owner should tolerate null inactive targets")
	_expect(CommandoFirearmControlState.needs_runtime_effect_update(null, true), "runtime effect owner should preserve explicit visible effects")
	_expect(not runtime.needs_effect_update(), "runtime effect update gate should default false")
	runtime.pending_boss_damage_units = 1
	_expect(runtime.needs_effect_update(), "runtime effect update gate should read pending damage")
	runtime.pending_boss_damage_units = 0
	runtime.pending_special_gauge_gain = 0.5
	_expect(runtime.needs_effect_update(), "runtime effect update gate should read pending gauge gain")
	runtime.pending_special_gauge_gain = 0.0
	runtime.pistol_control_lock_frames = 1.0
	_expect(runtime.is_player_control_locked(), "runtime control lock gate should read lock timers")
	runtime.pistol_control_lock_frames = 0.0
	runtime.ak47_trigger_held = true
	_expect(is_equal_approx(runtime.get_movement_speed_multiplier(), 0.5), "runtime movement multiplier should read AK-47 hold slow")
	runtime.ak47_trigger_held = false
	runtime.projectiles = [{"weapon_id": "suicide_drone", "kind": "drone"}]
	_expect(is_equal_approx(runtime.get_movement_speed_multiplier(), 0.0), "runtime movement multiplier should read active drone lock")
	var source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	_expect(source.find("func _clear_ak47_trigger_state(") == -1, "runtime should not keep AK-47 trigger-clear bridge")
	_expect(source.find("func _should_suppress_fire_input_for_serve_wait(") == -1, "runtime should not keep serve-wait suppression bridge")
	_expect(source.find("func _clear_serve_wait_firearm_input_state(") == -1, "runtime should not keep serve-wait input-clear bridge")
	_expect(source.find("func _handle_firearm_reset_input(") == -1, "runtime should not keep firearm-reset bridge")
	_expect(source.find("CommandoFirearmControlState.needs_effect_update(") == -1, "runtime should use the target-level effect-update owner")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
