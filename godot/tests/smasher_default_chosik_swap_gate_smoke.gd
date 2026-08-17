extends SceneTree

const RuntimePerkUnlockSwapFlow := preload("res://scripts/characters/runtime_perk_unlock_swap_flow.gd")
const SmasherDriveActivationController := preload("res://scripts/characters/smasher_drive_activation_controller.gd")
const SmasherDriveBounceState := preload("res://scripts/characters/smasher_drive_bounce_state.gd")
const SmasherPowerSmashActivationController := preload("res://scripts/characters/smasher_power_smash_activation_controller.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")

var _failures: Array[String] = []


class FakeActiveRoundState:
	extends RefCounted

	func is_waiting_for_serve() -> bool:
		return false


class FakeDriveInputState:
	extends RefCounted

	func consume_direction(_gameplay_frame: int) -> int:
		return 1

	func is_frame_cooldown_blocked() -> bool:
		return false

	func trigger_frame_cooldowns(_perfect_frames: float, _global_frames: float) -> void:
		pass


class FakeComboState:
	extends RefCounted

	func get_effective_combo() -> int:
		return 0

	func reset_combo(_reason: String = "") -> void:
		pass


class FakePowerInputReader:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {
			"action_pressed": true,
			"power_smash_direction": 1,
		}


class FakePowerState:
	extends RefCounted

	var begin_count := 0

	func can_activate(
		waiting_for_serve: bool,
		ball_active: bool,
		special_gauge: float,
		gauge_cost: float,
		frame_cooldown_blocked: bool,
		cooldown_remaining: float
	) -> bool:
		return (
			not waiting_for_serve
			and ball_active
			and special_gauge >= gauge_cost
			and not frame_cooldown_blocked
			and cooldown_remaining <= 0.0
		)

	func begin_activation(
		_direction: int,
		_arc_strength: float,
		_combo_consumed: int,
		_text_duration_frames: float,
		_is_ghost_shot: bool,
		_current_msec: int,
		_freeze_duration: float
	) -> void:
		begin_count += 1


func _init() -> void:
	_verify_drive_swap_disables_activation()
	_verify_power_smashing_swap_disables_activation()

	if _failures.is_empty():
		print("smasher_default_chosik_swap_gate_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_drive_swap_disables_activation() -> void:
	var config: Object = _full_config()
	_expect(bool(_try_drive(config).get("activated", false)), "equipped default drive Chosik should activate before replacement")

	var swap_result: Dictionary = _swap_out(config, "drive")
	_expect(bool(swap_result.get("ok", false)), "full-slot swap should replace the selected default drive Chosik")
	_expect(not config.is_skill_equipped("drive"), "drive must be absent from equipped slots after replacement")
	_expect(config.is_skill_equipped("magnum_grip"), "replacement Chosik must occupy the freed drive slot")

	var blocked: Dictionary = _try_drive(config)
	_expect(not bool(blocked.get("activated", false)), "removed default drive Chosik must not activate")
	_expect(is_equal_approx(float(blocked.get("special_gauge", 500.0)), 500.0), "blocked drive must not spend vigor")


func _verify_power_smashing_swap_disables_activation() -> void:
	var config: Object = _full_config()
	var baseline: Dictionary = _try_power_smashing(config)
	_expect(bool(baseline.get("activated", false)), "equipped default power-smashing Chosik should activate before replacement")

	var swap_result: Dictionary = _swap_out(config, "power_smashing")
	_expect(bool(swap_result.get("ok", false)), "full-slot swap should replace the selected default power-smashing Chosik")
	_expect(not config.is_skill_equipped("power_smashing"), "power_smashing must be absent from equipped slots after replacement")
	_expect(config.is_skill_equipped("magnum_grip"), "replacement Chosik must occupy the freed power-smashing slot")

	var blocked: Dictionary = _try_power_smashing(config)
	_expect(not bool(blocked.get("activated", false)), "removed default power-smashing Chosik must not activate")
	_expect(is_equal_approx(float(blocked.get("special_gauge", 500.0)), 500.0), "blocked power smashing must not spend vigor")


func _full_config() -> Object:
	var config: Object = SmasherSkillConfig.new()
	config.equipped_skills = ["drive", "power_smashing", "plasma", "recovery", "cleanse"]
	return config


func _swap_out(config: Object, removed_skill: String) -> Dictionary:
	var flow: Object = RuntimePerkUnlockSwapFlow.new()
	return flow.apply_selected_swap(
		{
			"choice": {
				"id": "unlock_magnum_grip",
				"unlocks_skill": "magnum_grip",
			},
			"choice_id": "unlock_magnum_grip",
			"unlocks_skill": "magnum_grip",
			"candidates": [{"skill_id": removed_skill}],
		},
		0,
		config
	)


func _try_drive(config: Object) -> Dictionary:
	var controller: Object = SmasherDriveActivationController.new()
	return controller.try_activate(
		10.0,
		0.0,
		0.25,
		1.0,
		100,
		{
			"ball_active": true,
			"ball_pos": Vector2(380.0, 650.0),
			"special_gauge": 500.0,
			"gauge_cost": 150.0,
			"current_msec": 1000,
		},
		{
			"round_state": FakeActiveRoundState.new(),
			"drive_input_state": FakeDriveInputState.new(),
			"drive_bounce_state": SmasherDriveBounceState.new(),
			"combo_state": FakeComboState.new(),
			"skill_config": config,
		}
	)


func _try_power_smashing(config: Object) -> Dictionary:
	var power_state := FakePowerState.new()
	var controller: Object = SmasherPowerSmashActivationController.new()
	var result: Dictionary = controller.try_activate(
		{
			"ball_active": true,
			"special_gauge": 500.0,
			"gauge_cost": 300.0,
			"current_msec": 1000,
		},
		{
			"input_reader": FakePowerInputReader.new(),
			"power_state": power_state,
			"round_state": FakeActiveRoundState.new(),
			"skill_config": config,
		},
		{}
	)
	result["begin_count"] = power_state.begin_count
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
