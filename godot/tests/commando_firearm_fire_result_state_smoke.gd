extends SceneTree

const CommandoFirearmFireResultState := preload("res://scripts/characters/commando_firearm_fire_result_state.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_fire_result_state()
	_verify_runtime_delegates_fire_result_state()

	if _failures.is_empty():
		print("commando_firearm_fire_result_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_fire_result_state() -> void:
	var result: Dictionary = CommandoFirearmFireResultState.build_fire_failed_result(
		"bazooka",
		500.0,
		"bazooka_cooldown",
		{"cooldown_frames": 12.0}
	)
	_expect(bool(result.get("handled", false)), "fire failed result should mark input handled")
	_expect(str(result.get("weapon_id", "")) == "bazooka", "fire failed result should preserve weapon id")
	_expect(bool(result.get("fire_failed", false)), "fire failed result should expose failure flag")
	_expect(str(result.get("failure_reason", "")) == "bazooka_cooldown", "fire failed result should preserve reason")
	_expect(is_equal_approx(float(result.get("special_gauge", 0.0)), 500.0), "fire failed result should preserve gauge")
	_expect(is_equal_approx(float(result.get("cooldown_frames", 0.0)), 12.0), "fire failed result should merge extra fields")


func _verify_runtime_delegates_fire_result_state() -> void:
	var runtime := CommandoFirearmRuntime.new()
	runtime.pistol_cooldown_frames = 3.0
	runtime.pistol_control_lock_frames = 4.0
	runtime.pistol_fire_delay_frames = 5.0
	var pistol: Dictionary = runtime._pistol_fire_failed(500.0, "pistol_busy", "commando_pistol")
	_expect(str(pistol.get("weapon_id", "")) == "commando_pistol", "runtime pistol failed wrapper should delegate weapon id")
	_expect(is_equal_approx(float(pistol.get("fire_delay_frames", 0.0)), 5.0), "runtime pistol failed wrapper should preserve fire delay")

	runtime.ak47_fire_interval_frames = 6.0
	runtime.ak47_burst_shots_remaining = 1
	var ak47: Dictionary = runtime._ak47_fire_failed(500.0, "ak47_empty")
	_expect(str(ak47.get("weapon_id", "")) == "ak47", "runtime AK-47 failed wrapper should delegate")
	_expect(int(ak47.get("burst_shots_remaining", -1)) == 1, "runtime AK-47 failed wrapper should preserve burst count")

	runtime.bazooka_cooldown_frames = 7.0
	runtime.bazooka_control_lock_frames = 8.0
	runtime.bazooka_fire_animation_frames = 9.0
	runtime.bazooka_firing_pose_frames = 10.0
	runtime.bazooka_muzzle_flash_frames = 11.0
	var bazooka: Dictionary = runtime._bazooka_fire_failed(500.0, "bazooka_cooldown")
	_expect(is_equal_approx(float(bazooka.get("muzzle_flash_frames", 0.0)), 11.0), "runtime bazooka failed wrapper should preserve muzzle flash timer")

	runtime.net_gun_cooldown_frames = 12.0
	runtime.net_gun_control_lock_frames = 13.0
	runtime.net_gun_throw_pose_frames = 14.0
	runtime.net_gun_harpoon_flash_frames = 15.0
	var net_gun: Dictionary = runtime._net_gun_fire_failed(500.0, "net_gun_cooldown")
	_expect(is_equal_approx(float(net_gun.get("harpoon_flash_frames", 0.0)), 15.0), "runtime net-gun failed wrapper should preserve harpoon flash timer")

	runtime.bowling_trap_cooldown_frames = 16.0
	runtime.bowling_trap_control_lock_frames = 17.0
	runtime.bowling_trap_install_pose_frames = 18.0
	var bowling: Dictionary = runtime._bowling_trap_fire_failed(500.0, "bowling_trap_cooldown")
	_expect(is_equal_approx(float(bowling.get("install_pose_frames", 0.0)), 18.0), "runtime bowling-trap failed wrapper should preserve install pose timer")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
