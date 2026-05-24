extends SceneTree

const CommandoFirearmPistolReloadState := preload("res://scripts/characters/commando_firearm_pistol_reload_state.gd")

var _failures: Array[String] = []


class FakeAudio:
	extends RefCounted

	var reload_start_calls := 0

	func play_commando_pistol_reload_start() -> void:
		reload_start_calls += 1


class FakeWeaponController:
	extends RefCounted

	var can_start := true
	var start_calls := 0
	var weapon_data := {
		"ammo_current": 0,
		"ammo_max": 4,
		"reload_display_ammo": 0,
		"reload_timer_frames": 24.0,
	}

	func start_weapon_reload(_weapon_id: String) -> bool:
		start_calls += 1
		return can_start

	func get_current_weapon_data() -> Dictionary:
		return weapon_data.duplicate(true)


func _init() -> void:
	_verify_direct_pistol_reload_state()
	_verify_runtime_delegates_pistol_reload_state()

	if _failures.is_empty():
		print("commando_firearm_pistol_reload_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_pistol_reload_state() -> void:
	var insufficient: Dictionary = CommandoFirearmPistolReloadState.start_base_empty_reload(
		149.0,
		{},
		"pistol",
		3.0,
		4.0,
		5.0,
		4,
		24.0,
		150.0
	)
	_expect(str(insufficient.get("failure_reason", "")) == "pistol_reload_gauge_insufficient", "pistol reload owner should reject insufficient gauge")
	_expect(is_equal_approx(float(insufficient.get("fire_delay_frames", 0.0)), 5.0), "pistol reload owner should preserve failure timer fields")

	var unavailable: Dictionary = CommandoFirearmPistolReloadState.start_base_empty_reload(
		150.0,
		{},
		"pistol",
		3.0,
		4.0,
		5.0,
		4,
		24.0,
		150.0
	)
	_expect(str(unavailable.get("failure_reason", "")) == "pistol_reload_unavailable", "pistol reload owner should reject missing weapon controller")

	var controller := FakeWeaponController.new()
	controller.can_start = false
	var blocked: Dictionary = CommandoFirearmPistolReloadState.start_base_empty_reload(
		150.0,
		{"commando_weapon_controller": controller},
		"pistol",
		0.0,
		0.0,
		0.0,
		4,
		24.0,
		150.0
	)
	_expect(str(blocked.get("failure_reason", "")) == "pistol_reload_unavailable", "pistol reload owner should reject controller reload denial")
	_expect(controller.start_calls == 1, "pistol reload owner should ask the controller to start reload")

	controller.can_start = true
	var audio := FakeAudio.new()
	var started: Dictionary = CommandoFirearmPistolReloadState.start_base_empty_reload(
		180.0,
		{"commando_weapon_controller": controller, "audio": audio},
		"pistol",
		0.0,
		0.0,
		0.0,
		4,
		24.0,
		150.0
	)
	_expect(bool(started.get("reload_started", false)), "pistol reload owner should expose reload-started state")
	_expect(is_equal_approx(float(started.get("special_gauge", 0.0)), 30.0), "pistol reload owner should spend configured gauge")
	_expect(int(started.get("ammo_max", 0)) == 4, "pistol reload owner should preserve updated weapon data")
	_expect(audio.reload_start_calls == 1, "pistol reload owner should play reload start audio")


func _verify_runtime_delegates_pistol_reload_state() -> void:
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	var input_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_pistol_input_state.gd")
	_expect(runtime_source.find("func _reload_base_pistol_from_fire_input(") == -1, "runtime should not keep base pistol reload bridge")
	_expect(runtime_source.find("CommandoFirearmPistolInputState.update_runtime_input(") >= 0, "runtime should delegate pistol input orchestration to the pistol input owner")
	_expect(input_source.find("CommandoFirearmPistolReloadState.start_base_empty_reload(") >= 0, "pistol input owner should delegate empty base pistol reloads to the reload owner")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
