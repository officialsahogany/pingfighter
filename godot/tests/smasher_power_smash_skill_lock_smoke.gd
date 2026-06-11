extends SceneTree

const PaddleBounceSkillRouter := preload("res://scripts/ball/paddle_bounce_skill_router.gd")
const PlayerSkillLockInputProxy := preload("res://scripts/characters/player_skill_lock_input_proxy.gd")
const StatusEffectState := preload("res://scripts/status/status_effect_state.gd")

var _failures: Array[String] = []


class FakeInputReader:
	extends RefCounted

	var snapshot: Dictionary = {}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeMythicItemRuntime:
	extends RefCounted

	var horn_skills_locked := false
	var horn_control_locked := false
	var odins_skills_locked := false
	var odins_control_locked := false

	func is_horn_strawberry_skills_locked() -> bool:
		return horn_skills_locked

	func is_horn_strawberry_control_locked() -> bool:
		return horn_control_locked

	func is_odins_eye_skills_locked() -> bool:
		return odins_skills_locked

	func is_odins_eye_control_locked() -> bool:
		return odins_control_locked


class FakeStatusEffectState:
	extends RefCounted

	var stun_active := false
	var stun_ratio := 1.0

	func is_player_stun_active() -> bool:
		return stun_active

	func has_status(target: String, status_id: String) -> bool:
		return stun_active and target == "player" and status_id == "stun"

	func get_player_control_context() -> Dictionary:
		return {
			"player_stun_active": stun_active,
			"player_stun_ratio": stun_ratio if stun_active else 0.0,
		}


class FakePowerActivationController:
	extends RefCounted

	var call_count := 0

	func try_activate(context: Dictionary, _deps: Dictionary, _callbacks: Dictionary) -> Dictionary:
		call_count += 1
		return {
			"activated": true,
			"special_gauge": max(0.0, float(context.get("special_gauge", 0.0)) - 300.0),
		}


class FakeDriveActivationRouter:
	extends RefCounted

	var call_count := 0

	func try_activate(
		_speed: float,
		_angle_rad: float,
		_hit_pos: float,
		_accel_scale: float,
		_ball_pos: Vector2,
		_ball_spin_strength: float,
		_ball_spin_direction: int,
		_drive_speed_increase: float,
		_drive_ball_active: bool,
		_drive_hit_boss: bool,
		_special_gauge: float,
		_drive_text_timer_frames: float,
		_context: Dictionary,
		_deps: Dictionary
	) -> Dictionary:
		call_count += 1
		return {"activated": true}


func _init() -> void:
	_test_odins_eye_lock_masks_skill_input_proxy()
	_test_unlocked_skill_input_proxy_passes_through()
	_test_power_smash_router_blocks_odins_eye_skill_lock()
	_test_power_smash_router_blocks_odins_eye_control_lock()
	_test_power_smash_router_blocks_shared_player_stun()
	_test_power_smash_router_blocks_real_status_stun()
	_test_power_smash_router_passes_when_unlocked()
	_test_drive_router_blocks_odins_eye_skill_lock()
	_test_drive_router_blocks_shared_player_stun()

	if _failures.is_empty():
		print("smasher_power_smash_skill_lock_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_odins_eye_lock_masks_skill_input_proxy() -> void:
	var raw_reader := FakeInputReader.new()
	raw_reader.snapshot = {
		"left_pressed": true,
		"right_pressed": false,
		"direction": -1.0,
		"up_pressed": true,
		"down_pressed": true,
		"action_pressed": true,
		"action_just_pressed": true,
		"jetpack_pressed": true,
		"supply_drop_hold_pressed": true,
		"commando_supply_drop_hold_pressed": true,
		"power_smash_direction": -1,
	}
	var runtime := FakeMythicItemRuntime.new()
	runtime.odins_skills_locked = true
	var proxy: Object = PlayerSkillLockInputProxy.new().configure(raw_reader, runtime)
	var snapshot: Dictionary = proxy.get_snapshot()

	_expect(bool(snapshot.get("left_pressed", false)), "Odin skill lock should preserve horizontal movement")
	_expect(is_equal_approx(float(snapshot.get("direction", 0.0)), -1.0), "Odin skill lock should preserve movement direction")
	_expect(not bool(snapshot.get("up_pressed", true)), "Odin skill lock should clear up skill input")
	_expect(not bool(snapshot.get("down_pressed", true)), "Odin skill lock should clear down skill input")
	_expect(not bool(snapshot.get("action_pressed", true)), "Odin skill lock should clear action skill input")
	_expect(not bool(snapshot.get("jetpack_pressed", true)), "Odin skill lock should clear Viper jetpack input")
	_expect(not bool(snapshot.get("supply_drop_hold_pressed", true)), "Odin skill lock should clear Commando supply input")
	_expect(int(snapshot.get("power_smash_direction", 1)) == 0, "Odin skill lock should clear power-smash direction")


func _test_unlocked_skill_input_proxy_passes_through() -> void:
	var raw_reader := FakeInputReader.new()
	raw_reader.snapshot = {
		"action_pressed": true,
		"power_smash_direction": -1,
	}
	var proxy: Object = PlayerSkillLockInputProxy.new().configure(raw_reader, FakeMythicItemRuntime.new())
	var snapshot: Dictionary = proxy.get_snapshot()

	_expect(bool(snapshot.get("action_pressed", false)), "unlocked skill proxy should preserve action input")
	_expect(int(snapshot.get("power_smash_direction", 0)) == -1, "unlocked skill proxy should preserve power-smash direction")


func _test_power_smash_router_blocks_odins_eye_skill_lock() -> void:
	var runtime := FakeMythicItemRuntime.new()
	runtime.odins_skills_locked = true
	var controller := FakePowerActivationController.new()
	var result: Dictionary = _try_power_router(controller, {
		"mythic_item_runtime": runtime,
	})

	_expect(not bool(result.get("activated", true)), "Odin skill lock should block power-smash activation")
	_expect(controller.call_count == 0, "Odin skill lock should block before reaching the activation controller")


func _test_power_smash_router_blocks_odins_eye_control_lock() -> void:
	var runtime := FakeMythicItemRuntime.new()
	runtime.odins_control_locked = true
	var controller := FakePowerActivationController.new()
	var result: Dictionary = _try_power_router(controller, {
		"mythic_item_runtime": runtime,
	})

	_expect(not bool(result.get("activated", true)), "Odin control-only lock should block power-smash activation")
	_expect(controller.call_count == 0, "Odin control-only lock should block before reaching the activation controller")


func _test_power_smash_router_blocks_shared_player_stun() -> void:
	var status_state := FakeStatusEffectState.new()
	status_state.stun_active = true
	var controller := FakePowerActivationController.new()
	var result: Dictionary = _try_power_router(controller, {
		"status_effect_state": status_state,
	})

	_expect(not bool(result.get("activated", true)), "shared player stun should block power-smash activation")
	_expect(controller.call_count == 0, "shared player stun should block before reaching the activation controller")


func _test_power_smash_router_blocks_real_status_stun() -> void:
	var status_state: Object = StatusEffectState.new()
	status_state.apply_status("player", "stun", 48.0, {}, "power_smash_skill_lock_smoke")
	var controller := FakePowerActivationController.new()
	var result: Dictionary = _try_power_router(controller, {
		"status_effect_state": status_state,
	})

	_expect(not bool(result.get("activated", true)), "real StatusEffectState player stun should block power-smash activation")
	_expect(controller.call_count == 0, "real StatusEffectState player stun should block before reaching the activation controller")


func _test_power_smash_router_passes_when_unlocked() -> void:
	var controller := FakePowerActivationController.new()
	var result: Dictionary = _try_power_router(controller, {})

	_expect(bool(result.get("activated", false)), "unlocked power-smash route should still reach the activation controller")
	_expect(controller.call_count == 1, "unlocked power-smash route should call the activation controller once")


func _test_drive_router_blocks_odins_eye_skill_lock() -> void:
	var runtime := FakeMythicItemRuntime.new()
	runtime.odins_skills_locked = true
	var drive_router := FakeDriveActivationRouter.new()
	var result: Dictionary = _try_drive_router(drive_router, {
		"mythic_item_runtime": runtime,
	})

	_expect(not bool(result.get("activated", true)), "Odin skill lock should block drive activation")
	_expect(drive_router.call_count == 0, "Odin skill lock should block drive before reaching the drive router")


func _test_drive_router_blocks_shared_player_stun() -> void:
	var status_state: Object = StatusEffectState.new()
	status_state.apply_status("player", "stun", 48.0, {}, "drive_skill_lock_smoke")
	var drive_router := FakeDriveActivationRouter.new()
	var result: Dictionary = _try_drive_router(drive_router, {
		"status_effect_state": status_state,
	})

	_expect(not bool(result.get("activated", true)), "shared player stun should block drive activation")
	_expect(drive_router.call_count == 0, "shared player stun should block drive before reaching the drive router")


func _try_power_router(controller: Object, extra_deps: Dictionary) -> Dictionary:
	var router: Object = PaddleBounceSkillRouter.new()
	var deps: Dictionary = {
		"power_activation_controller": controller,
		"input_reader": FakeInputReader.new(),
	}
	deps.merge(extra_deps, true)
	return router.try_activate_power_smashing(
		Vector2(380.0, 690.0),
		true,
		500.0,
		{
			"power_smash_gauge_cost": 300.0,
			"power_smash_text_duration_frames": 48.0,
			"power_smash_freeze_duration": 1.65,
			"ball_active": true,
		},
		deps,
		{}
	)


func _try_drive_router(drive_router: Object, extra_deps: Dictionary) -> Dictionary:
	var router: Object = PaddleBounceSkillRouter.new()
	router.drive_activation_router = drive_router
	var deps: Dictionary = {
		"input_reader": FakeInputReader.new(),
	}
	deps.merge(extra_deps, true)
	return router.try_activate_drive(
		12.0,
		0.15,
		0.0,
		1.0,
		Vector2(380.0, 690.0),
		0.0,
		0,
		0.0,
		false,
		false,
		500.0,
		0.0,
		{
			"ball_active": true,
			"drive_gauge_cost": 80.0,
			"drive_text_duration_frames": 30.0,
			"gameplay_frame_counter": 10,
		},
		deps
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
