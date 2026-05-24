extends SceneTree

const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoFirearmSlingshotState := preload("res://scripts/characters/commando_firearm_slingshot_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_slingshot_state()
	_verify_runtime_delegates_slingshot_state()

	if _failures.is_empty():
		print("commando_firearm_slingshot_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_slingshot_state() -> void:
	_expect(CommandoFirearmSlingshotState.get_charge_level(29.0, 30.0, 90.0, 180.0) == 0, "charge-level helper should keep pre-threshold charges at level zero")
	_expect(CommandoFirearmSlingshotState.get_charge_level(30.0, 30.0, 90.0, 180.0) == 1, "charge-level helper should enter level one at threshold one")
	_expect(CommandoFirearmSlingshotState.get_charge_level(90.0, 30.0, 90.0, 180.0) == 2, "charge-level helper should enter level two at threshold two")
	_expect(CommandoFirearmSlingshotState.get_charge_level(180.0, 30.0, 90.0, 180.0) == 3, "charge-level helper should enter level three at threshold three")

	var charged: Dictionary = CommandoFirearmSlingshotState.advance_charge(29.0, 0.0, 100.0, 20.0, 30.0, 30.0, 90.0, 180.0)
	_expect(is_equal_approx(float(charged.get("charge_timer_frames", 0.0)), 30.0), "advance helper should increment charge timer")
	_expect(int(charged.get("charge_level", 0)) == 1, "advance helper should update charge level")
	_expect(is_equal_approx(float(charged.get("special_gauge", 0.0)), 80.0), "advance helper should drain gauge on interval")
	_expect(is_equal_approx(float(charged.get("gauge_spent", 0.0)), 20.0), "advance helper should track spent gauge")

	var forced: Dictionary = CommandoFirearmSlingshotState.advance_charge(59.0, 20.0, 10.0, 20.0, 30.0, 30.0, 90.0, 180.0)
	_expect(bool(forced.get("force_release", false)), "advance helper should force release when interval drain cannot be paid")
	_expect(is_equal_approx(float(forced.get("special_gauge", 0.0)), 10.0), "forced release should preserve insufficient gauge")
	_expect(is_equal_approx(float(forced.get("gauge_spent", 0.0)), 20.0), "forced release should preserve previous spent gauge")

	var charging: Dictionary = CommandoFirearmSlingshotState.build_charging_result("pistol", 45.0, 1, 80.0)
	_expect(bool(charging.get("charging", false)), "charging result should expose charging state")
	_expect(is_equal_approx(float(charging.get("charge_timer_frames", 0.0)), 45.0), "charging result should preserve timer")

	var not_ready: Dictionary = CommandoFirearmSlingshotState.build_not_ready_result("pistol", 10.0)
	_expect(bool(not_ready.get("fire_failed", false)), "not-ready result should expose fire failure")
	_expect(str(not_ready.get("failure_reason", "")) == "slingshot_not_ready", "not-ready result should preserve reason")

	var canceled: Dictionary = CommandoFirearmSlingshotState.build_charge_canceled_result("pistol", 40.0)
	_expect(bool(canceled.get("charge_canceled", false)), "canceled result should expose charge cancellation")

	var cancel_runtime := CommandoFirearmRuntime.new()
	cancel_runtime.slingshot_charging = true
	cancel_runtime.slingshot_charge_timer_frames = 55.0
	cancel_runtime.slingshot_charge_level = 2
	cancel_runtime.slingshot_gauge_spent = 20.0
	CommandoFirearmSlingshotState.apply_canceled_state(cancel_runtime)
	_expect(not cancel_runtime.slingshot_charging, "canceled state helper should clear charging flag")
	_expect(is_equal_approx(cancel_runtime.slingshot_charge_timer_frames, 0.0), "canceled state helper should clear timer")
	_expect(cancel_runtime.slingshot_charge_level == 0, "canceled state helper should clear charge level")
	_expect(is_equal_approx(cancel_runtime.slingshot_gauge_spent, 0.0), "canceled state helper should clear spent gauge")

	var released: Dictionary = CommandoFirearmSlingshotState.build_release_result("pistol", 2, 95.0, 12.0, "released", 60.0)
	_expect(bool(released.get("fired", false)), "release result should expose fired state")
	_expect(int(released.get("charge_level", 0)) == 2, "release result should preserve charge level")
	_expect(str(released.get("release_reason", "")) == "released", "release result should preserve reason")

	var profile: Dictionary = CommandoFirearmSlingshotState.build_fire_profile({}, 3, {1: 18.0, 2: 25.0, 3: 32.0}, 25.0, 6.0)
	_expect(bool(profile.get("slingshot", false)), "fire profile should mark slingshot projectiles")
	_expect(int(profile.get("charge_level", 0)) == 3, "fire profile should clamp and preserve charge level")
	_expect(is_equal_approx(float(profile.get("speed", 0.0)), 32.0), "fire profile should use level-specific speed")
	_expect(is_equal_approx(float(profile.get("radius", 0.0)), 8.0), "fire profile should scale projectile radius by charge level")

	var hit_result := {}
	CommandoFirearmSlingshotState.apply_hit_effects(
		"pistol",
		{"slingshot": true, "charge_level": 3},
		hit_result,
		"pistol",
		{1: 0.7, 2: 1.0, 3: 1.3},
		{1: 0.7, 2: 1.0, 3: 1.5}
	)
	_expect(int(hit_result.get("slingshot_charge_level", 0)) == 3, "hit helper should preserve charge level")
	_expect(is_equal_approx(float(hit_result.get("stun_frames", 0.0)), 23.0), "hit helper should scale stun frames")
	_expect(is_equal_approx(float(hit_result.get("knockback_power", 0.0)), 21.0), "hit helper should scale knockback power")
	_expect(str(hit_result.get("stun_source", "")) == "commando_firearm_slingshot_charge_3", "hit helper should expose charge-specific stun source")

	var ignored_hit_result := {}
	CommandoFirearmSlingshotState.apply_hit_effects("ak47", {"slingshot": true}, ignored_hit_result, "pistol", {}, {})
	_expect(ignored_hit_result.is_empty(), "hit helper should ignore non-base weapons")


func _verify_runtime_delegates_slingshot_state() -> void:
	var runtime := CommandoFirearmRuntime.new()
	runtime.slingshot_charge_timer_frames = 29.0
	var charged: Dictionary = runtime._advance_slingshot_charge(100.0)
	_expect(is_equal_approx(float(charged.get("special_gauge", 0.0)), 80.0), "runtime charge helper should delegate gauge drain")
	_expect(is_equal_approx(runtime.slingshot_charge_timer_frames, 30.0), "runtime charge helper should store timer")
	_expect(runtime.slingshot_charge_level == 1, "runtime charge helper should store charge level")
	_expect(is_equal_approx(runtime.slingshot_gauge_spent, 20.0), "runtime charge helper should store spent gauge")

	runtime.slingshot_charge_level = 2
	runtime.slingshot_charge_timer_frames = 95.0
	var released: Dictionary = runtime._release_slingshot(80.0, {"player_pos": Vector2(100.0, 680.0)}, {}, "released")
	_expect(bool(released.get("fired", false)), "runtime release path should produce a slingshot fire result")
	_expect(runtime.projectiles.size() == 1, "runtime release path should spawn a slingshot projectile")
	var runtime_projectile: Dictionary = runtime.projectiles[0]
	_expect(bool(runtime_projectile.get("slingshot", false)), "runtime release path should build slingshot fire profile")
	_expect(int(runtime_projectile.get("charge_level", 0)) == 2, "runtime release path should preserve charge level")

	var runtime_hit_result: Dictionary = runtime._apply_weapon_hit_result(
		"pistol",
		{"slingshot": true, "charge_level": 2, "pos": Vector2(100.0, 100.0), "velocity": Vector2.UP, "shot_roll": 0.99},
		{"boss_pos": Vector2(330.0, 60.0)},
		{}
	)
	_expect(int(runtime_hit_result.get("slingshot_charge_level", 0)) == 2, "runtime hit path should delegate charge level")
	_expect(is_equal_approx(float(runtime_hit_result.get("stun_frames", 0.0)), 18.0), "runtime hit path should delegate stun scaling")

	runtime.slingshot_charge_level = 0
	runtime.slingshot_charge_timer_frames = 10.0
	var canceled: Dictionary = runtime._release_slingshot(40.0, {}, {}, "released")
	_expect(bool(canceled.get("charge_canceled", false)), "runtime short release should use canceled payload")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	_expect(not runtime_source.contains("func _update_slingshot_input("), "runtime should not keep the removed slingshot input bridge")
	_expect(not runtime_source.contains("func _update_slingshot_charge_level("), "runtime should not keep slingshot charge-level bridge")
	_expect(not runtime_source.contains("func _get_slingshot_fire_profile("), "runtime should not keep slingshot fire-profile bridge")
	_expect(not runtime_source.contains("func _apply_slingshot_hit_effects("), "runtime should not keep slingshot hit-effect bridge")
	_expect(not runtime_source.contains("func _cancel_slingshot_charge("), "runtime should not keep slingshot cancel-state bridge")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
