extends SceneTree

const CommandoFirearmDrawStateResolver := preload("res://scripts/characters/commando_firearm_draw_state_resolver.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_slingshot_state()
	_verify_direct_pistol_state()
	_verify_direct_weapon_fire_sheet_state()
	_verify_direct_weapon_draw_states()
	_verify_runtime_delegates_draw_state()

	if _failures.is_empty():
		print("commando_firearm_draw_state_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_slingshot_state() -> void:
	var state: Dictionary = CommandoFirearmDrawStateResolver.build_slingshot_state(
		true,
		45.0,
		2,
		180.0,
		30.0,
		5.0,
		30.0,
		90.0,
		6.0,
		18.0
	)
	_expect(bool(state.get("charging", false)), "slingshot state should preserve charging flag")
	_expect(is_equal_approx(float(state.get("charge_ratio", 0.0)), 0.25), "slingshot state should compute charge ratio")
	_expect(is_equal_approx(float(state.get("charge_tick_ratio", 0.0)), 0.5), "slingshot state should compute charge tick ratio")
	_expect(int(state.get("charge_level", 0)) == 2, "slingshot state should preserve charge level")


func _verify_direct_pistol_state() -> void:
	var pending: Dictionary = CommandoFirearmDrawStateResolver.build_pistol_state(
		2.0,
		60.0,
		3.0,
		18.0,
		12.0,
		24.0,
		0.0,
		18.0
	)
	_expect(bool(pending.get("shot_pending", false)), "pistol state should mark pending shot during fire delay")
	_expect(bool(pending.get("animation_active", false)), "pistol state should mark animation active during fire delay")

	var post_fire: Dictionary = CommandoFirearmDrawStateResolver.build_pistol_state(
		0.0,
		60.0,
		0.0,
		18.0,
		0.0,
		24.0,
		3.0,
		18.0
	)
	_expect(not bool(post_fire.get("shot_pending", true)), "pistol state should clear pending shot after fire delay")
	_expect(bool(post_fire.get("animation_active", false)), "pistol state should keep animation active during post-fire pose")


func _verify_direct_weapon_fire_sheet_state() -> void:
	var active: Dictionary = CommandoFirearmDrawStateResolver.build_weapon_fire_sheet_state("ak47", 20.0, 40.0, 8)
	_expect(bool(active.get("active", false)), "weapon-fire sheet should be active when timer and id are present")
	_expect(str(active.get("weapon_id", "")) == "ak47", "weapon-fire sheet should preserve weapon id")
	_expect(int(active.get("frame_count", 0)) == 8, "weapon-fire sheet should preserve frame count")

	var missing_id: Dictionary = CommandoFirearmDrawStateResolver.build_weapon_fire_sheet_state("", 20.0, 40.0, 8)
	_expect(not bool(missing_id.get("active", true)), "weapon-fire sheet should be inactive without weapon id")


func _verify_direct_weapon_draw_states() -> void:
	var ak47: Dictionary = CommandoFirearmDrawStateResolver.build_ak47_state(true, 2.0, 6.0, 1, 0.4, 0.5)
	_expect(bool(ak47.get("trigger_held", false)), "AK-47 state should preserve trigger flag")
	_expect(is_equal_approx(float(ak47.get("movement_speed_multiplier", 0.0)), 0.5), "AK-47 state should preserve movement multiplier")

	var bazooka: Dictionary = CommandoFirearmDrawStateResolver.build_bazooka_state(
		7.0,
		120.0,
		8.0,
		30.0,
		9.0,
		48.0,
		10.0,
		24.0,
		11.0,
		12.0
	)
	_expect(bool(bazooka.get("firing_pose", false)), "bazooka state should expose firing pose while pose timer is active")
	_expect(is_equal_approx(float(bazooka.get("muzzle_flash_frames", 0.0)), 11.0), "bazooka state should preserve muzzle flash timer")

	var net_gun: Dictionary = CommandoFirearmDrawStateResolver.build_net_gun_state(
		12.0,
		120.0,
		13.0,
		30.0,
		14.0,
		30.0,
		15.0,
		12.0,
		0.7,
		true
	)
	_expect(bool(net_gun.get("throw_pose", false)), "net-gun state should expose throw pose while pose timer is active")
	_expect(bool(net_gun.get("hooked_net_active", false)), "net-gun state should preserve hooked-net flag")

	var bowling: Dictionary = CommandoFirearmDrawStateResolver.build_bowling_trap_state(16.0, 120.0, 17.0, 30.0, 18.0, 48.0, true, 0.4)
	_expect(bool(bowling.get("installing", false)), "bowling-trap state should preserve installing flag")
	_expect(is_equal_approx(float(bowling.get("install_progress", 0.0)), 0.4), "bowling-trap state should preserve install progress")

	var suicide_drone: Dictionary = CommandoFirearmDrawStateResolver.build_suicide_drone_state(true, 19.0, 90.0, 6.0, Vector2(10.0, 20.0), Vector2(1.0, -2.0))
	_expect(bool(suicide_drone.get("active", false)), "suicide-drone state should preserve active flag")
	_expect(_vector_close(suicide_drone.get("pos", Vector2.ZERO), Vector2(10.0, 20.0)), "suicide-drone state should preserve position")


func _verify_runtime_delegates_draw_state() -> void:
	var runtime := CommandoFirearmRuntime.new()
	runtime.slingshot_charging = true
	runtime.slingshot_charge_timer_frames = 45.0
	runtime.slingshot_charge_level = 2
	runtime.slingshot_gauge_spent = 90.0
	runtime.slingshot_cooldown_frames = 5.0
	runtime.slingshot_control_lock_frames = 6.0
	var slingshot: Dictionary = runtime._get_slingshot_draw_state()
	_expect(bool(slingshot.get("charging", false)), "runtime slingshot draw wrapper should preserve charging flag")
	_expect(is_equal_approx(float(slingshot.get("charge_ratio", 0.0)), 0.25), "runtime slingshot draw wrapper should compute charge ratio")

	runtime.pistol_cooldown_frames = 2.0
	runtime.pistol_cooldown_max_frames = 60.0
	runtime.pistol_control_lock_frames = 3.0
	runtime.pistol_control_lock_max_frames = 18.0
	runtime.pistol_fire_delay_frames = 4.0
	runtime.pistol_post_fire_animation_frames = 5.0

	var pistol: Dictionary = runtime._get_pistol_draw_state()
	_expect(is_equal_approx(float(pistol.get("cooldown_frames", 0.0)), 2.0), "runtime pistol draw wrapper should preserve cooldown")
	_expect(is_equal_approx(float(pistol.get("control_lock_frames", 0.0)), 3.0), "runtime pistol draw wrapper should preserve control lock")
	_expect(is_equal_approx(float(pistol.get("fire_delay_frames", 0.0)), 4.0), "runtime pistol draw wrapper should preserve fire delay")
	_expect(is_equal_approx(float(pistol.get("post_fire_animation_frames", 0.0)), 5.0), "runtime pistol draw wrapper should preserve post-fire timer")
	_expect(bool(pistol.get("shot_pending", false)), "runtime pistol draw wrapper should expose pending shot")
	_expect(bool(pistol.get("animation_active", false)), "runtime pistol draw wrapper should expose active animation")

	runtime.weapon_fire_sheet_id = "ak47"
	runtime.weapon_fire_sheet_timer_frames = 20.0
	runtime.weapon_fire_sheet_max_frames = 40.0
	var fire_sheet: Dictionary = runtime._get_weapon_fire_sheet_draw_state()
	_expect(bool(fire_sheet.get("active", false)), "runtime weapon-fire sheet wrapper should expose active state")
	_expect(str(fire_sheet.get("weapon_id", "")) == "ak47", "runtime weapon-fire sheet wrapper should preserve id")
	_expect(int(fire_sheet.get("frame_count", 0)) == CommandoFirearmRuntime.COMMANDO_WEAPON_FIRE_SHEET_FRAME_COUNT, "runtime weapon-fire sheet wrapper should preserve frame count")

	runtime.ak47_trigger_held = true
	runtime.ak47_fire_interval_frames = 2.0
	runtime.ak47_burst_shots_remaining = 1
	runtime.ak47_recoil_accumulation = 0.4
	var ak47: Dictionary = runtime._get_ak47_draw_state()
	_expect(bool(ak47.get("trigger_held", false)), "runtime AK-47 draw wrapper should preserve trigger flag")
	_expect(int(ak47.get("burst_shots_remaining", 0)) == 1, "runtime AK-47 draw wrapper should preserve burst count")

	runtime.bazooka_cooldown_frames = 7.0
	runtime.bazooka_control_lock_frames = 8.0
	runtime.bazooka_fire_animation_frames = 9.0
	runtime.bazooka_firing_pose_frames = 10.0
	runtime.bazooka_muzzle_flash_frames = 11.0
	var bazooka: Dictionary = runtime._get_bazooka_draw_state()
	_expect(bool(bazooka.get("firing_pose", false)), "runtime bazooka draw wrapper should expose firing pose")
	_expect(is_equal_approx(float(bazooka.get("muzzle_flash_frames", 0.0)), 11.0), "runtime bazooka draw wrapper should preserve muzzle flash")

	runtime.net_gun_cooldown_frames = 12.0
	runtime.net_gun_control_lock_frames = 13.0
	runtime.net_gun_throw_pose_frames = 14.0
	runtime.net_gun_harpoon_flash_frames = 15.0
	var net_gun: Dictionary = runtime._get_net_gun_draw_state()
	_expect(bool(net_gun.get("throw_pose", false)), "runtime net-gun draw wrapper should expose throw pose")
	_expect(is_equal_approx(float(net_gun.get("harpoon_flash_frames", 0.0)), 15.0), "runtime net-gun draw wrapper should preserve harpoon flash")

	runtime.bowling_traps = [{
		"state": "installing",
		"install_progress": 0.4,
	}]
	runtime.bowling_trap_cooldown_frames = 16.0
	runtime.bowling_trap_control_lock_frames = 17.0
	runtime.bowling_trap_install_pose_frames = 18.0
	var bowling: Dictionary = runtime._get_bowling_trap_draw_state()
	_expect(bool(bowling.get("installing", false)), "runtime bowling-trap draw wrapper should expose installing flag")
	_expect(is_equal_approx(float(bowling.get("install_progress", 0.0)), 0.4), "runtime bowling-trap draw wrapper should preserve install progress")

	runtime.projectiles = [{
		"weapon_id": "suicide_drone",
		"kind": "drone",
		"grace_timer_frames": 6.0,
		"pos": Vector2(10.0, 20.0),
		"velocity": Vector2(1.0, -2.0),
	}]
	runtime.suicide_drone_cooldown_frames = 19.0
	var suicide_drone: Dictionary = runtime._get_suicide_drone_draw_state()
	_expect(bool(suicide_drone.get("active", false)), "runtime suicide-drone draw wrapper should expose active flag")
	_expect(is_equal_approx(float(suicide_drone.get("grace_frames", 0.0)), 6.0), "runtime suicide-drone draw wrapper should preserve grace timer")
	_expect(_vector_close(suicide_drone.get("velocity", Vector2.ZERO), Vector2(1.0, -2.0)), "runtime suicide-drone draw wrapper should preserve velocity")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _vector_close(value: Variant, expected: Vector2) -> bool:
	if not value is Vector2:
		return false
	var vector_value: Vector2 = value
	return vector_value.distance_to(expected) <= 0.001
