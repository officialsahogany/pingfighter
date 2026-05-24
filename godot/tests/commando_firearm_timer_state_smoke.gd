extends SceneTree

const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoFirearmTimerState := preload("res://scripts/characters/commando_firearm_timer_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_runtime_timer_owner()
	_verify_pending_pistol_fire_owner()

	if _failures.is_empty():
		print("commando_firearm_timer_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_runtime_timer_owner() -> void:
	var runtime := CommandoFirearmRuntime.new()
	runtime.slingshot_control_lock_frames = 3.0
	runtime.pistol_cooldown_frames = 2.0
	runtime.pistol_control_lock_frames = 4.0
	runtime.ak47_fire_interval_frames = 1.5
	runtime.ak47_recoil_accumulation = 2.0
	runtime.ak47_trigger_held = false
	runtime.bazooka_muzzle_flash_frames = 0.5
	runtime.net_gun_harpoon_flash_frames = 1.0
	runtime.bowling_trap_install_pose_frames = 2.5
	runtime.suicide_drone_cooldown_frames = 6.0
	runtime.pistol_post_fire_animation_frames = 2.0
	runtime.pistol_fire_delay_frames = 9.0
	runtime.weapon_fire_sheet_id = "ak47"
	runtime.weapon_fire_sheet_timer_frames = 0.5
	runtime.weapon_fire_sheet_max_frames = 12.0

	CommandoFirearmTimerState.advance_runtime_timers(runtime, 1.0, 0.25)
	_expect(is_equal_approx(runtime.slingshot_control_lock_frames, 2.0), "timer owner should tick slingshot lock")
	_expect(is_equal_approx(runtime.pistol_cooldown_frames, 1.0), "timer owner should tick pistol cooldown")
	_expect(is_equal_approx(runtime.pistol_control_lock_frames, 3.0), "timer owner should tick pistol lock")
	_expect(is_equal_approx(runtime.ak47_fire_interval_frames, 0.5), "timer owner should tick AK-47 interval")
	_expect(is_equal_approx(runtime.ak47_recoil_accumulation, 1.75), "timer owner should recover AK-47 recoil when trigger is released")
	_expect(is_equal_approx(runtime.bazooka_muzzle_flash_frames, 0.0), "timer owner should clamp bazooka muzzle flash")
	_expect(is_equal_approx(runtime.net_gun_harpoon_flash_frames, 0.0), "timer owner should clamp net-gun harpoon flash")
	_expect(is_equal_approx(runtime.bowling_trap_install_pose_frames, 1.5), "timer owner should tick bowling-trap install pose")
	_expect(is_equal_approx(runtime.suicide_drone_cooldown_frames, 5.0), "timer owner should tick suicide-drone cooldown")
	_expect(is_equal_approx(runtime.pistol_post_fire_animation_frames, 1.0), "timer owner should tick pistol post-fire animation")
	_expect(is_equal_approx(runtime.pistol_fire_delay_frames, 9.0), "timer owner should leave delayed pistol fire timing to the runtime")
	_expect(runtime.weapon_fire_sheet_id == "", "timer owner should clear expired weapon-fire sheet id")
	_expect(is_equal_approx(runtime.weapon_fire_sheet_max_frames, 0.0), "timer owner should clear expired weapon-fire sheet max")

	runtime.ak47_trigger_held = true
	runtime.ak47_recoil_accumulation = 2.0
	CommandoFirearmTimerState.advance_runtime_timers(runtime, 1.0, 0.25)
	_expect(is_equal_approx(runtime.ak47_recoil_accumulation, 2.0), "timer owner should preserve AK-47 recoil while trigger is held")

	runtime.pistol_cooldown_frames = 3.0
	CommandoFirearmTimerState.advance_runtime_timers(runtime, 0.0, 0.25)
	_expect(is_equal_approx(runtime.pistol_cooldown_frames, 3.0), "timer owner should ignore zero-step ticks")


func _verify_pending_pistol_fire_owner() -> void:
	var runtime := CommandoFirearmRuntime.new()
	runtime.pistol_fire_delay_frames = 3.0
	runtime.pistol_control_lock_frames = 4.0
	runtime.pistol_cooldown_frames = 5.0
	runtime.pistol_pending_weapon_id = "commando_pistol"
	runtime.pistol_pending_config = {"player_pos": Vector2(1.0, 2.0)}

	var pending: Dictionary = CommandoFirearmTimerState.advance_pending_pistol_fire(
		runtime,
		{"player_pos": Vector2(10.0, 20.0)},
		1.0,
		["player_pos"],
		CommandoFirearmRuntime.BASE_WEAPON_ID
	)
	_expect(bool(pending.get("pending", false)), "pending pistol fire owner should report active pending state")
	_expect(is_equal_approx(runtime.pistol_fire_delay_frames, 2.0), "pending pistol fire owner should decrement delay")
	_expect(_get_dict(pending.get("result", {})).get("shot_pending", false), "pending pistol fire owner should return pending shot result")
	_expect(runtime.pistol_pending_config.get("player_pos", Vector2.ZERO) == Vector2(10.0, 20.0), "pending pistol fire owner should refresh delayed shot geometry")

	var ready: Dictionary = CommandoFirearmTimerState.advance_pending_pistol_fire(
		runtime,
		{},
		3.0,
		["player_pos"],
		CommandoFirearmRuntime.BASE_WEAPON_ID
	)
	_expect(bool(ready.get("ready", false)), "pending pistol fire owner should report ready shot")
	_expect(str(ready.get("weapon_id", "")) == "commando_pistol", "pending pistol fire owner should preserve weapon id")
	_expect(_get_dict(ready.get("shot_config", {})).get("player_pos", Vector2.ZERO) == Vector2(10.0, 20.0), "pending pistol fire owner should preserve refreshed shot config")
	_expect(_get_dict(ready.get("result", {})).get("fired", false), "pending pistol fire owner should return delayed fire result")
	_expect(is_equal_approx(runtime.pistol_fire_delay_frames, 0.0), "pending pistol fire owner should clear delay after ready")
	_expect(runtime.pistol_pending_weapon_id == "", "pending pistol fire owner should clear pending weapon")
	_expect(runtime.pistol_pending_config.is_empty(), "pending pistol fire owner should clear pending config")


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
