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

	var pistol_failed: Dictionary = CommandoFirearmFireResultState.build_pistol_fire_failed_result(
		"commando_pistol",
		500.0,
		"pistol_busy",
		3.0,
		4.0,
		5.0
	)
	_expect(str(pistol_failed.get("weapon_id", "")) == "commando_pistol", "pistol failed result should preserve weapon id")
	_expect(str(pistol_failed.get("failure_reason", "")) == "pistol_busy", "pistol failed result should preserve reason")
	_expect(is_equal_approx(float(pistol_failed.get("fire_delay_frames", 0.0)), 5.0), "pistol failed result should preserve fire delay")

	var bazooka_fields: Dictionary = CommandoFirearmFireResultState.build_bazooka_timing_fields(1.0, 2.0, 3.0, 4.0, 5.0)
	_expect(is_equal_approx(float(bazooka_fields.get("muzzle_flash_frames", 0.0)), 5.0), "bazooka timing fields should preserve muzzle flash frames")
	var net_gun_fields: Dictionary = CommandoFirearmFireResultState.build_net_gun_timing_fields(6.0, 7.0, 8.0, 9.0)
	_expect(is_equal_approx(float(net_gun_fields.get("harpoon_flash_frames", 0.0)), 9.0), "net-gun timing fields should preserve harpoon flash frames")
	var bowling_fields: Dictionary = CommandoFirearmFireResultState.build_bowling_trap_timing_fields(10.0, 11.0, 12.0, true, 0.25)
	_expect(is_equal_approx(float(bowling_fields.get("install_pose_frames", 0.0)), 12.0), "bowling timing fields should preserve install pose frames")
	_expect(is_equal_approx(float(bowling_fields.get("install_progress", 0.0)), 0.25), "bowling timing fields should preserve optional install progress")

	var pending: Dictionary = CommandoFirearmFireResultState.build_pistol_shot_pending_result("commando_pistol", 12.0, 4.0)
	_expect(bool(pending.get("shot_pending", false)), "pending pistol result should expose shot-pending state")
	_expect(is_equal_approx(float(pending.get("fire_delay_frames", 0.0)), 12.0), "pending pistol result should preserve fire delay")

	var delayed_fire: Dictionary = CommandoFirearmFireResultState.build_pistol_delayed_fire_result("commando_pistol", 30.0, 9.0)
	_expect(bool(delayed_fire.get("fired", false)), "delayed pistol result should expose fired state")
	_expect(is_equal_approx(float(delayed_fire.get("fire_delay_frames", -1.0)), 0.0), "delayed pistol result should clear fire delay")
	_expect(int(delayed_fire.get("skill_gold_award", -1)) == 0, "delayed pistol result should keep zero skill gold")

	var reload: Dictionary = CommandoFirearmFireResultState.build_pistol_reload_started_result("pistol", 240.0, "pistol_reload_started")
	_expect(bool(reload.get("reload_started", false)), "pistol reload result should expose reload-started state")
	_expect(str(reload.get("failure_reason", "")) == "pistol_reload_started", "pistol reload result should preserve reason")

	var base_reload: Dictionary = CommandoFirearmFireResultState.build_base_pistol_reload_started_result(
		"pistol",
		350.0,
		{
			"ammo_current": 0,
			"ammo_max": 4,
			"reload_display_ammo": 2,
			"reload_timer_frames": 18.0,
		},
		4,
		24.0,
		150.0
	)
	_expect(str(base_reload.get("failure_reason", "")) == "base_pistol_empty_reload_started", "base pistol reload result should preserve reason")
	_expect(int(base_reload.get("reload_display_ammo", -1)) == 2, "base pistol reload result should preserve display ammo")
	_expect(is_equal_approx(float(base_reload.get("commando_pistol_reload_gauge_cost", 0.0)), 150.0), "base pistol reload result should preserve gauge cost")

	var queued: Dictionary = CommandoFirearmFireResultState.build_pistol_shot_queued_result(
		"commando_pistol",
		{
			"ammo_current": 7,
			"ammo_max": 8,
			"magazines_current": 0,
			"magazines_max": 0,
		},
		7,
		8,
		0,
		30.0,
		9.0,
		24.0,
		{
			"head_leg_multiplier": 2.0,
			"pistol_speed_multiplier": 1.2,
		},
		true,
		500.0
	)
	_expect(bool(queued.get("shot_queued", false)), "queued pistol result should expose shot-queued state")
	_expect(int(queued.get("ammo_current", -1)) == 7, "queued pistol result should preserve updated ammo")
	_expect(bool(queued.get("doping_potion_active", false)), "queued pistol result should preserve doping state")
	_expect(is_equal_approx(float(queued.get("doping_potion_head_leg_multiplier", 0.0)), 2.0), "queued pistol result should preserve doping multiplier")

	var ak47_holding: Dictionary = CommandoFirearmFireResultState.build_ak47_holding_result(400.0, 6.0, 1, 0.5)
	_expect(bool(ak47_holding.get("holding", false)), "AK-47 holding result should expose holding state")
	_expect(is_equal_approx(float(ak47_holding.get("movement_speed_multiplier", 0.0)), 0.5), "AK-47 holding result should preserve movement multiplier")

	var ak47_fired: Dictionary = CommandoFirearmFireResultState.build_ak47_fired_result(
		12,
		60,
		{
			"duration_frames": 120.0,
			"duration_max_frames": 180.0,
		},
		1800.0,
		6.0,
		0,
		0.06,
		0.5,
		400.0
	)
	_expect(bool(ak47_fired.get("fired", false)), "AK-47 fired result should expose fired state")
	_expect(int(ak47_fired.get("ammo_current", -1)) == 12, "AK-47 fired result should preserve remaining ammo")
	_expect(is_equal_approx(float(ak47_fired.get("duration_frames", 0.0)), 120.0), "AK-47 fired result should preserve duration")

	var ammo_weapon: Dictionary = CommandoFirearmFireResultState.build_ammo_weapon_fired_result(
		"bazooka",
		{
			"ammo_current": 3,
			"ammo_max": 4,
		},
		2,
		4,
		350.0,
		{"muzzle_flash_frames": 5.0}
	)
	_expect(str(ammo_weapon.get("weapon_id", "")) == "bazooka", "ammo weapon fired result should preserve weapon id")
	_expect(int(ammo_weapon.get("ammo_current", -1)) == 3, "ammo weapon fired result should preserve ammo")
	_expect(is_equal_approx(float(ammo_weapon.get("muzzle_flash_frames", 0.0)), 5.0), "ammo weapon fired result should merge weapon timer fields")


func _verify_runtime_delegates_fire_result_state() -> void:
	var runtime := CommandoFirearmRuntime.new()
	runtime.pistol_cooldown_frames = 3.0
	runtime.pistol_control_lock_frames = 4.0
	runtime.pistol_fire_delay_frames = 5.0
	var pistol: Dictionary = runtime._update_pistol_input(
		{"action_pressed": true},
		500.0,
		{},
		{},
		{"weapon_id": "commando_pistol", "ammo_current": 1, "can_fire": true},
		0
	)
	_expect(str(pistol.get("weapon_id", "")) == "commando_pistol", "runtime pistol failed path should preserve weapon id")
	_expect(str(pistol.get("failure_reason", "")) == "pistol_animation_busy", "runtime pistol failed path should preserve failure reason")
	_expect(is_equal_approx(float(pistol.get("fire_delay_frames", 0.0)), 5.0), "runtime pistol failed path should preserve fire delay")

	runtime.ak47_fire_interval_frames = 6.0
	runtime.ak47_last_action_pressed = true
	runtime.ak47_trigger_held = true
	runtime.ak47_burst_shots_remaining = 1
	var ak47: Dictionary = runtime._update_ak47_input(
		{"action_pressed": true},
		500.0,
		{},
		{},
		{"weapon_id": "ak47", "ammo_current": 0, "can_fire": true},
		0
	)
	_expect(str(ak47.get("weapon_id", "")) == "ak47", "runtime AK-47 failed path should preserve weapon id")
	_expect(str(ak47.get("failure_reason", "")) == "ak47_empty", "runtime AK-47 failed path should preserve failure reason")
	_expect(is_equal_approx(float(ak47.get("fire_interval_frames", 0.0)), 6.0), "runtime AK-47 failed path should preserve interval timer")
	_expect(int(ak47.get("burst_shots_remaining", -1)) == 0, "runtime AK-47 failed path should clear burst count")

	runtime.bazooka_cooldown_frames = 7.0
	runtime.bazooka_control_lock_frames = 8.0
	runtime.bazooka_fire_animation_frames = 9.0
	runtime.bazooka_firing_pose_frames = 10.0
	runtime.bazooka_muzzle_flash_frames = 11.0
	var bazooka: Dictionary = runtime._update_bazooka_input(
		{"action_pressed": true, "action_just_pressed": true},
		500.0,
		{},
		{},
		{"weapon_id": "bazooka", "ammo_current": 1, "can_fire": true},
		0
	)
	_expect(str(bazooka.get("failure_reason", "")) == "bazooka_control_lock", "runtime bazooka failed path should preserve failure reason")
	_expect(is_equal_approx(float(bazooka.get("muzzle_flash_frames", 0.0)), 11.0), "runtime bazooka failed path should preserve muzzle flash timer")

	runtime.net_gun_cooldown_frames = 12.0
	runtime.net_gun_control_lock_frames = 13.0
	runtime.net_gun_throw_pose_frames = 14.0
	runtime.net_gun_harpoon_flash_frames = 15.0
	var net_gun: Dictionary = runtime._update_net_gun_input(
		{"action_pressed": true, "action_just_pressed": true},
		500.0,
		{},
		{},
		{"weapon_id": "net_gun", "ammo_current": 1, "can_fire": true},
		0
	)
	_expect(str(net_gun.get("failure_reason", "")) == "net_gun_control_lock", "runtime net-gun failed path should preserve failure reason")
	_expect(is_equal_approx(float(net_gun.get("harpoon_flash_frames", 0.0)), 15.0), "runtime net-gun failed path should preserve harpoon flash timer")

	runtime.bowling_trap_cooldown_frames = 16.0
	runtime.bowling_trap_control_lock_frames = 17.0
	runtime.bowling_trap_install_pose_frames = 18.0
	var bowling: Dictionary = runtime._update_bowling_trap_input(
		{"action_pressed": true, "action_just_pressed": true},
		500.0,
		{},
		{},
		{"weapon_id": "bowling_trap", "ammo_current": 1, "can_fire": true},
		0
	)
	_expect(str(bowling.get("failure_reason", "")) == "bowling_trap_control_lock", "runtime bowling-trap failed path should preserve failure reason")
	_expect(is_equal_approx(float(bowling.get("install_pose_frames", 0.0)), 18.0), "runtime bowling-trap failed path should preserve install pose timer")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	_expect(runtime_source.find("func _bazooka_fire_failed(") == -1, "runtime should not keep the bazooka fire-failed bridge")
	_expect(runtime_source.find("func _net_gun_fire_failed(") == -1, "runtime should not keep the net-gun fire-failed bridge")
	_expect(runtime_source.find("func _bowling_trap_fire_failed(") == -1, "runtime should not keep the bowling-trap fire-failed bridge")
	_expect(runtime_source.find("func _ak47_fire_failed(") == -1, "runtime should not keep the AK-47 fire-failed bridge")
	_expect(runtime_source.find("func _pistol_fire_failed(") == -1, "runtime should not keep the pistol fire-failed bridge")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
