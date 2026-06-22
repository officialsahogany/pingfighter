extends SceneTree

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const CommandoFirearmProfileResolver := preload("res://scripts/characters/commando_firearm_profile_resolver.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_profile_resolution()
	_verify_spawn_profile_state()
	_verify_runtime_profile_constants()
	_verify_removed_runtime_profile_bridges()

	if _failures.is_empty():
		print("commando_firearm_profile_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_profile_resolution() -> void:
	var profiles := {
		"pistol": {
			"kind": "bullet",
			"nested": {"value": 1},
		},
		"rocket": {
			"kind": "rocket",
			"speed": 3.0,
		},
		"broken": "not_a_profile",
	}
	var overrides := {
		"rocket": {
			"speed": 9.0,
			"blast": 40.0,
		},
	}

	_expect(CommandoFirearmProfileResolver.normalize_weapon_id("  RoCkEt  ") == "rocket", "weapon ids should normalize by trim/lowercase")
	var rocket: Dictionary = CommandoFirearmProfileResolver.get_profile(profiles, " ROCKET ", "pistol", overrides)
	_expect(str(rocket.get("kind", "")) == "rocket", "profile resolver should find normalized ids")
	_expect(is_equal_approx(float(rocket.get("speed", 0.0)), 9.0), "profile overrides should replace existing values")
	_expect(is_equal_approx(float(rocket.get("blast", 0.0)), 40.0), "profile overrides should add new values")

	var fallback: Dictionary = CommandoFirearmProfileResolver.get_profile(profiles, "unknown", "pistol")
	_expect(str(fallback.get("kind", "")) == "bullet", "unknown profiles should fall back to pistol")

	var broken: Dictionary = CommandoFirearmProfileResolver.get_profile(profiles, "broken", "pistol")
	_expect(str(broken.get("kind", "")) == "bullet", "non-dictionary profiles should fall back safely")

	fallback["nested"]["value"] = 99
	var second_fallback: Dictionary = CommandoFirearmProfileResolver.get_profile(profiles, "unknown", "pistol")
	_expect(int(_get_dict(second_fallback.get("nested", {})).get("value", 0)) == 1, "profile resolver should deep-duplicate fallback profiles")

	var lingering: Dictionary = CommandoFirearmProfileResolver.get_lingering_effect_profile(" Net_Gun ", {
		"net_gun": {"kind": "net_field"},
	})
	_expect(str(lingering.get("kind", "")) == "net_field", "lingering resolver should normalize ids")
	_expect(CommandoFirearmProfileResolver.get_lingering_effect_profile("missing", {}).is_empty(), "unknown lingering profiles should stay empty")

	var ak47_fire_profile: Dictionary = CommandoFirearmProfileResolver.build_ak47_fire_profile(
		{
			"pistol": {"kind": "bullet"},
			"ak47": {"kind": "bullet", "speed": 16.0},
		},
		{},
		0.03,
		0.15
	)
	_expect(str(ak47_fire_profile.get("kind", "")) == "bullet", "AK-47 fire profile should preserve base profile fields")
	_expect(is_equal_approx(float(ak47_fire_profile.get("recoil_accumulation", 0.0)), 0.03), "AK-47 fire profile should expose recoil accumulation")
	_expect(absf(float(ak47_fire_profile.get("angle_offset", 99.0))) <= 0.18, "AK-47 fire profile should clamp random spread to recoil range")


func _verify_spawn_profile_state() -> void:
	var weapon_profiles := {
		"pistol": {
			"kind": "bullet",
			"speed": 25.0,
		},
		"commando_pistol": {
			"kind": "bullet",
			"speed": 30.0,
		},
	}
	var doped_state: Dictionary = CommandoFirearmProfileResolver.build_spawn_profile_state(
		"commando_pistol",
		{},
		weapon_profiles,
		{},
		{"active": true, "pistol_speed_multiplier": 1.5},
		{"pistol_speed_multiplier": 1.2},
		"pistol",
		25.0,
		1.2,
		PI / 12.0,
		(PI / 12.0) * 0.70
	)
	var doped_profile: Dictionary = _get_dict(doped_state.get("profile", {}))
	var doping_context: Dictionary = _get_dict(doped_state.get("doping_context", {}))
	_expect(bool(doping_context.get("active", false)), "spawn profile state should normalize active doping context")
	_expect(is_equal_approx(float(doped_profile.get("speed", 0.0)), 45.0), "doped commando pistol spawn profile should apply speed multiplier")
	_expect(doped_profile.get("color", Color.BLACK) == Color(1.0, 0.47, 0.24), "doped commando pistol spawn profile should apply warm primary color")
	_expect(doped_profile.get("secondary", Color.BLACK) == Color(1.0, 0.78, 0.22), "doped commando pistol spawn profile should apply warm secondary color")
	_expect(doped_profile.has("angle_offset"), "pistol spawn profile should add spread angle when missing")
	_expect(absf(float(doped_profile.get("angle_offset", 99.0))) <= (PI / 12.0) * 0.70, "commando pistol spawn profile should use beretta spread")

	var override_state: Dictionary = CommandoFirearmProfileResolver.build_spawn_profile_state(
		"pistol",
		{"kind": "bullet", "angle_offset": 0.25},
		weapon_profiles,
		{},
		{},
		{},
		"pistol",
		25.0,
		1.2,
		PI / 12.0,
		(PI / 12.0) * 0.70
	)
	var override_profile: Dictionary = _get_dict(override_state.get("profile", {}))
	_expect(is_equal_approx(float(override_profile.get("angle_offset", 0.0)), 0.25), "spawn profile should preserve explicit angle offsets")

	var enhanced_base_state: Dictionary = CommandoFirearmProfileResolver.build_spawn_profile_state(
		"pistol",
		{},
		weapon_profiles,
		{},
		{},
		{},
		"pistol",
		25.0,
		1.2,
		PI / 12.0,
		(PI / 12.0) * 0.70,
		1.5
	)
	var enhanced_base_profile: Dictionary = _get_dict(enhanced_base_state.get("profile", {}))
	_expect(is_equal_approx(float(enhanced_base_profile.get("speed", 0.0)), 37.5), "base pistol spawn profile should apply pistol_enhance speed multiplier")

	var slingshot_state: Dictionary = CommandoFirearmProfileResolver.build_spawn_profile_state(
		"pistol",
		{"kind": "bullet", "speed": 18.0, "slingshot": true},
		weapon_profiles,
		{},
		{},
		{},
		"pistol",
		25.0,
		1.2,
		PI / 12.0,
		(PI / 12.0) * 0.70,
		1.5
	)
	var slingshot_profile: Dictionary = _get_dict(slingshot_state.get("profile", {}))
	_expect(is_equal_approx(float(slingshot_profile.get("speed", 0.0)), 18.0), "slingshot override should ignore pistol_enhance speed multiplier")

	var unchanged_beretta_state: Dictionary = CommandoFirearmProfileResolver.build_spawn_profile_state(
		"commando_pistol",
		{},
		weapon_profiles,
		{},
		{},
		{},
		"pistol",
		25.0,
		1.2,
		PI / 12.0,
		(PI / 12.0) * 0.70,
		1.5
	)
	var unchanged_beretta_profile: Dictionary = _get_dict(unchanged_beretta_state.get("profile", {}))
	_expect(is_equal_approx(float(unchanged_beretta_profile.get("speed", 0.0)), 30.0), "Beretta spawn profile should ignore pistol_enhance speed multiplier")

	var base_spread: float = deg_to_rad(15.0)
	var beretta_spread: float = deg_to_rad(10.5)
	seed(930105)
	var beretta_max_offset: float = _sample_max_abs_spawn_angle(
		"commando_pistol",
		weapon_profiles,
		base_spread,
		beretta_spread
	)
	_expect(beretta_max_offset <= beretta_spread, "Commando pistol should draw spread from the Beretta band, not the base pistol band")
	_expect(beretta_max_offset > deg_to_rad(1.0), "seeded Beretta spread samples should prove the band is wider than the enhanced base pistol cap")

	var tight_base_spread: float = deg_to_rad(1.0)
	seed(930105)
	var base_max_offset: float = _sample_max_abs_spawn_angle(
		"pistol",
		weapon_profiles,
		tight_base_spread,
		beretta_spread
	)
	_expect(base_max_offset <= tight_base_spread, "base pistol should honor the supplied tight enhanced spread band")


func _verify_runtime_profile_constants() -> void:
	_expect(
		is_equal_approx(CommandoFirearmRuntime.BERETTA_SPREAD_RADIANS, CommandoFirearmRuntime.PISTOL_SPREAD_RADIANS * 0.70),
		"Beretta spread should stay derived from the base pistol constant"
	)
	var pistol: Dictionary = _get_runtime_weapon_profile("unknown_weapon")
	_expect(str(pistol.get("kind", "")) == "bullet", "runtime weapon profile constants should keep pistol fallback")
	pistol["kind"] = "mutated"
	_expect(str(_get_runtime_weapon_profile("unknown_weapon").get("kind", "")) == "bullet", "runtime weapon profiles should remain duplicated")

	var fire_support_weapon: Dictionary = _get_runtime_weapon_profile(" FIRE_SUPPORT ")
	_expect(is_equal_approx(float(fire_support_weapon.get("explosion_radius", 0.0)), float(ActiveItemThrowController.GRENADE_EXPLOSION_RADIUS)), "fire support weapon profile should keep grenade explosion radius override")

	var fire_support_feedback: Dictionary = _get_runtime_hit_feedback_profile("fire_support")
	_expect(is_equal_approx(float(fire_support_feedback.get("shake_amount", 0.0)), 0.24), "fire support feedback should keep its shake amount override")
	_expect(is_equal_approx(float(fire_support_feedback.get("shake_intensity", 0.0)), 7.0), "fire support feedback should keep its shake intensity override")

	var fire_support_result: Dictionary = _get_runtime_hit_result_profile("fire_support")
	_expect(is_equal_approx(float(fire_support_result.get("stun_frames", 0.0)), float(ActiveItemThrowController.GRENADE_BOSS_STUN_FRAMES)), "fire support hit result should keep grenade stun override")
	_expect(is_equal_approx(float(fire_support_result.get("knockback_power", 0.0)), float(ActiveItemThrowController.GRENADE_BOSS_KNOCKBACK_POWER)), "fire support hit result should keep grenade knockback override")
	_expect(is_equal_approx(float(fire_support_result.get("knockback_frames", 0.0)), float(ActiveItemThrowController.GRENADE_BOSS_KNOCKBACK_FRAMES)), "fire support hit result should keep grenade knockback frame override")
	_expect(is_equal_approx(float(fire_support_result.get("knockback_decay_per_frame", 0.0)), float(ActiveItemThrowController.GRENADE_BOSS_KNOCKBACK_DECAY)), "fire support hit result should keep grenade decay override")

	var net_lingering: Dictionary = _get_runtime_lingering_effect_profile(" NET_GUN ")
	_expect(str(net_lingering.get("kind", "")) == "net_field", "runtime lingering profile constants should normalize ids")
	_expect(_get_runtime_lingering_effect_profile("pistol").is_empty(), "runtime lingering profile constants should not use pistol fallback")


func _verify_removed_runtime_profile_bridges() -> void:
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	var fire_spawn_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_fire_spawn_state.gd")
	for bridge_name in [
		"_get_weapon_profile",
		"_get_hit_feedback_profile",
		"_get_hit_result_profile",
		"_get_lingering_effect_profile",
		"_get_ak47_fire_profile",
		"_get_bazooka_fire_profile",
		"_get_net_gun_fire_profile",
	]:
		_expect(runtime_source.find("func %s(" % bridge_name) == -1, "runtime should not keep profile bridge %s" % bridge_name)
	_expect(
		runtime_source.find("CommandoFirearmFireSpawnState.spawn_runtime_firearm_effect") >= 0,
		"runtime should delegate firearm spawning to the fire-spawn owner"
	)
	_expect(
		fire_spawn_source.find("CommandoFirearmProfileResolver.build_spawn_profile_state") >= 0,
		"fire-spawn owner should delegate spawn profile preparation to the profile resolver"
	)


func _sample_max_abs_spawn_angle(
	weapon_id: String,
	weapon_profiles: Dictionary,
	pistol_spread_radians: float,
	beretta_spread_radians: float
) -> float:
	var max_offset := 0.0
	for _index in range(96):
		var state: Dictionary = CommandoFirearmProfileResolver.build_spawn_profile_state(
			weapon_id,
			{},
			weapon_profiles,
			{},
			{},
			{},
			"pistol",
			25.0,
			1.2,
			pistol_spread_radians,
			beretta_spread_radians
		)
		var profile: Dictionary = _get_dict(state.get("profile", {}))
		_expect(profile.has("angle_offset"), "%s spawn profile should emit an angle_offset sample" % weapon_id)
		max_offset = maxf(max_offset, absf(float(profile.get("angle_offset", 0.0))))
	return max_offset


func _get_runtime_weapon_profile(weapon_id: String) -> Dictionary:
	return CommandoFirearmProfileResolver.get_weapon_profile(
		weapon_id,
		CommandoFirearmRuntime.WEAPON_PROFILES,
		CommandoFirearmRuntime.WEAPON_PROFILE_OVERRIDES
	)


func _get_runtime_hit_feedback_profile(weapon_id: String) -> Dictionary:
	return CommandoFirearmProfileResolver.get_hit_feedback_profile(
		weapon_id,
		CommandoFirearmRuntime.WEAPON_HIT_FEEDBACK,
		CommandoFirearmRuntime.HIT_FEEDBACK_PROFILE_OVERRIDES
	)


func _get_runtime_hit_result_profile(weapon_id: String) -> Dictionary:
	return CommandoFirearmProfileResolver.get_hit_result_profile(
		weapon_id,
		CommandoFirearmRuntime.WEAPON_HIT_RESULTS,
		CommandoFirearmRuntime.HIT_RESULT_PROFILE_OVERRIDES
	)


func _get_runtime_lingering_effect_profile(weapon_id: String) -> Dictionary:
	return CommandoFirearmProfileResolver.get_lingering_effect_profile(
		weapon_id,
		CommandoFirearmRuntime.WEAPON_LINGERING_EFFECTS
	)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
