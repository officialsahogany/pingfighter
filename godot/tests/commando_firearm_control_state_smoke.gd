extends SceneTree

const CommandoFirearmControlState := preload("res://scripts/characters/commando_firearm_control_state.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


class FakeRoundState:
	extends RefCounted

	var waiting_for_serve := false

	func is_waiting_for_serve() -> bool:
		return waiting_for_serve


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

	_expect(is_equal_approx(CommandoFirearmControlState.get_movement_speed_multiplier(false, false, false, 0.5, 0.7), 1.0), "movement multiplier should default neutral")
	_expect(is_equal_approx(CommandoFirearmControlState.get_movement_speed_multiplier(false, true, false, 0.5, 0.7), 0.5), "movement multiplier should read AK-47 hold slow")
	_expect(is_equal_approx(CommandoFirearmControlState.get_movement_speed_multiplier(false, false, true, 0.5, 0.7), 1.0), "movement multiplier should ignore hooked-net state")
	_expect(is_equal_approx(CommandoFirearmControlState.get_movement_speed_multiplier(false, true, true, 0.5, 0.7), 0.5), "movement multiplier should keep AK-47 hold slow while ignoring hooked-net state")
	_expect(is_equal_approx(CommandoFirearmControlState.get_movement_speed_multiplier(true, false, false, 0.5, 0.7), 0.0), "movement multiplier should lock during active suicide drone")

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


func _verify_runtime_delegates_control_state() -> void:
	var runtime := CommandoFirearmRuntime.new()
	_expect(not runtime.needs_effect_update(), "runtime effect update gate should default false")
	runtime.pending_boss_damage_units = 1
	_expect(runtime.needs_effect_update(), "runtime effect update gate should read pending damage")
	runtime.pending_boss_damage_units = 0
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
