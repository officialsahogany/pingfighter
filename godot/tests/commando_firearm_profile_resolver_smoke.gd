extends SceneTree

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const CommandoFirearmProfileResolver := preload("res://scripts/characters/commando_firearm_profile_resolver.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_profile_resolution()
	_verify_runtime_delegates_profile_resolution()

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


func _verify_runtime_delegates_profile_resolution() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var pistol: Dictionary = runtime._get_weapon_profile("unknown_weapon")
	_expect(str(pistol.get("kind", "")) == "bullet", "runtime weapon profile wrapper should keep pistol fallback")
	pistol["kind"] = "mutated"
	_expect(str(runtime._get_weapon_profile("unknown_weapon").get("kind", "")) == "bullet", "runtime weapon profiles should remain duplicated")

	var fire_support_weapon: Dictionary = runtime._get_weapon_profile(" FIRE_SUPPORT ")
	_expect(is_equal_approx(float(fire_support_weapon.get("explosion_radius", 0.0)), float(ActiveItemThrowController.GRENADE_EXPLOSION_RADIUS)), "fire support weapon profile should keep grenade explosion radius override")

	var fire_support_feedback: Dictionary = runtime._get_hit_feedback_profile("fire_support")
	_expect(is_equal_approx(float(fire_support_feedback.get("shake_amount", 0.0)), 0.24), "fire support feedback should keep its shake amount override")
	_expect(is_equal_approx(float(fire_support_feedback.get("shake_intensity", 0.0)), 7.0), "fire support feedback should keep its shake intensity override")

	var fire_support_result: Dictionary = runtime._get_hit_result_profile("fire_support")
	_expect(is_equal_approx(float(fire_support_result.get("stun_frames", 0.0)), float(ActiveItemThrowController.GRENADE_BOSS_STUN_FRAMES)), "fire support hit result should keep grenade stun override")
	_expect(is_equal_approx(float(fire_support_result.get("knockback_power", 0.0)), float(ActiveItemThrowController.GRENADE_BOSS_KNOCKBACK_POWER)), "fire support hit result should keep grenade knockback override")
	_expect(is_equal_approx(float(fire_support_result.get("knockback_frames", 0.0)), float(ActiveItemThrowController.GRENADE_BOSS_KNOCKBACK_FRAMES)), "fire support hit result should keep grenade knockback frame override")
	_expect(is_equal_approx(float(fire_support_result.get("knockback_decay_per_frame", 0.0)), float(ActiveItemThrowController.GRENADE_BOSS_KNOCKBACK_DECAY)), "fire support hit result should keep grenade decay override")

	var net_lingering: Dictionary = runtime._get_lingering_effect_profile(" NET_GUN ")
	_expect(str(net_lingering.get("kind", "")) == "net_field", "runtime lingering profile wrapper should normalize ids")
	_expect(runtime._get_lingering_effect_profile("pistol").is_empty(), "runtime lingering profile wrapper should not use pistol fallback")


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
