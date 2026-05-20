extends SceneTree

const CommandoFirearmAudioResolver := preload("res://scripts/characters/commando_firearm_audio_resolver.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_audio_resolver()
	_verify_runtime_delegates_audio_resolver()

	if _failures.is_empty():
		print("commando_firearm_audio_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_audio_resolver() -> void:
	_expect(
		CommandoFirearmAudioResolver.get_ball_hit_pulse_kind("pistol", "pistol") == "commando_base_pistol",
		"base pistol pulse kind should keep the legacy base-pistol name"
	)
	_expect(
		CommandoFirearmAudioResolver.get_ball_hit_pulse_kind("ak47", "pistol") == "commando_ak47",
		"non-base pulse kinds should use the commando weapon prefix"
	)

	var fire_expectations := {
		"pistol": ["play_commando_pistol_fire"],
		"commando_pistol": ["play_commando_pistol_fire"],
		"ak47": ["play_commando_ak47_fire"],
		"bazooka": ["play_commando_bazooka_fire"],
		"net_gun": ["play_commando_net_gun_fire"],
		"bowling_trap": ["play_commando_bowling_trap_install"],
		"suicide_drone": ["play_commando_suicide_drone_launch"],
	}
	for weapon_id in fire_expectations.keys():
		_expect_array(
			CommandoFirearmAudioResolver.get_fire_audio_methods(str(weapon_id)),
			fire_expectations[weapon_id],
			"fire audio method mismatch for %s" % weapon_id
		)
	_expect_array(
		CommandoFirearmAudioResolver.get_fire_audio_methods("experimental_firearm"),
		[],
		"unknown fire audio method should fall back to an empty specific-method list"
	)

	var impact_expectations := {
		"pistol": ["play_commando_bullet_impact"],
		"commando_pistol": ["play_commando_bullet_impact"],
		"ak47": ["play_commando_bullet_impact"],
		"bazooka": ["play_commando_bazooka_impact"],
		"net_gun": ["play_commando_net_gun_capture"],
		"fire_support": ["play_commando_fire_support_bomb"],
		"bowling_trap": ["play_commando_bowling_trap_snap"],
		"suicide_drone": ["play_commando_suicide_drone_explosion"],
	}
	for weapon_id in impact_expectations.keys():
		_expect_array(
			CommandoFirearmAudioResolver.get_impact_audio_methods(str(weapon_id)),
			impact_expectations[weapon_id],
			"impact audio method mismatch for %s" % weapon_id
		)
	_expect_array(
		CommandoFirearmAudioResolver.get_impact_audio_methods("experimental_firearm"),
		[],
		"unknown impact audio method should fall back to an empty specific-method list"
	)


func _verify_runtime_delegates_audio_resolver() -> void:
	var runtime := CommandoFirearmRuntime.new()
	_expect(runtime._get_ball_hit_pulse_kind("pistol") == "commando_base_pistol", "runtime pulse wrapper should keep base-pistol behavior")
	_expect(runtime._get_ball_hit_pulse_kind("bazooka") == "commando_bazooka", "runtime pulse wrapper should delegate non-base names")
	_expect_array(runtime._get_fire_audio_methods("net_gun"), ["play_commando_net_gun_fire"], "runtime fire wrapper should delegate")
	_expect_array(runtime._get_fire_audio_methods("experimental_firearm"), [], "runtime fire wrapper should keep unknown fallback")
	_expect_array(runtime._get_impact_audio_methods("fire_support"), ["play_commando_fire_support_bomb"], "runtime impact wrapper should delegate")
	_expect_array(runtime._get_impact_audio_methods("experimental_firearm"), [], "runtime impact wrapper should keep unknown fallback")


func _expect_array(actual: Array, expected: Array, message: String) -> void:
	if actual.size() != expected.size():
		_failures.append("%s: expected %s entries, got %s" % [message, expected.size(), actual.size()])
		return
	for index in range(expected.size()):
		if str(actual[index]) != str(expected[index]):
			_failures.append("%s: index %s expected %s, got %s" % [message, index, expected[index], actual[index]])
			return


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
