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

	runtime.slingshot_charge_timer_frames = 180.0
	runtime._update_slingshot_charge_level()
	_expect(runtime.slingshot_charge_level == 3, "runtime charge-level wrapper should delegate")

	var fire_profile: Dictionary = runtime._get_slingshot_fire_profile(2)
	_expect(bool(fire_profile.get("slingshot", false)), "runtime fire profile wrapper should delegate")
	_expect(int(fire_profile.get("charge_level", 0)) == 2, "runtime fire profile wrapper should preserve charge level")

	var runtime_hit_result := {}
	runtime._apply_slingshot_hit_effects("pistol", {"slingshot": true, "charge_level": 2}, runtime_hit_result)
	_expect(int(runtime_hit_result.get("slingshot_charge_level", 0)) == 2, "runtime hit wrapper should delegate charge level")
	_expect(is_equal_approx(float(runtime_hit_result.get("stun_frames", 0.0)), 18.0), "runtime hit wrapper should delegate stun scaling")

	runtime.slingshot_charge_level = 0
	runtime.slingshot_charge_timer_frames = 10.0
	var canceled: Dictionary = runtime._release_slingshot(40.0, {}, {}, "released")
	_expect(bool(canceled.get("charge_canceled", false)), "runtime short release should use canceled payload")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
