extends SceneTree

const ActorUpdateDriver := preload("res://scripts/core/battle_scene_actor_update_driver.gd")
const BattleUpdateContext := preload("res://scripts/core/battle_update_context.gd")
const OptimusEnergyState := preload("res://scripts/characters/optimus_energy_state.gd")
const OptimusPlayerController := preload("res://scripts/characters/optimus_player_controller.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const PlayerMovementState := preload("res://scripts/characters/player_movement_state.gd")

var _failures: Array[String] = []


class FakeInputReader:
	extends RefCounted

	var snapshot := {
		"direction": 1.0,
		"left_pressed": false,
		"right_pressed": true,
		"down_pressed": false,
		"action_pressed": false,
	}

	func get_snapshot() -> Dictionary:
		return snapshot.duplicate(true)


class FakeOwner:
	extends RefCounted

	var gameplay_frame_counter := 0
	var player_pos := Vector2(200.0, 700.0)
	var player_speed := 0.0
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var runtime_paddle_base_width := 155.0
	var runtime_paddle_base_height := 50.0
	var runtime_paddle_scale := 1.0
	var selected_character_type := "optimus"
	var selected_runtime_character_id := "optimus"
	var special_gauge := 250.0
	var special_gauge_max := 500.0
	var optimus_energy_initialized := true
	var optimus_energy_ratio := 0.5
	var optimus_paddle_scale := 1.0
	var optimus_speed_multiplier := 1.0
	var optimus_charge_active := false
	var optimus_charge_hold_seconds := 0.0
	var optimus_charge_hold_ratio := 0.0
	var optimus_charge_lock_seconds := 0.0
	var optimus_charge_movement_locked := false
	var ball_active := true
	var ball_pos := Vector2(380.0, 360.0)
	var ball_vel := Vector2.ZERO
	var ball_impact_boost := 1.0
	var boss_pos := Vector2(330.0, 40.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var player_collision_cooldown := 0.0
	var current_stage := 1


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_runtime_routing()
	_verify_energy_state_math()
	_verify_actor_update_applies_optimus_energy()
	_verify_actor_update_manual_charge()

	if _failures.is_empty():
		print("optimus_core_mechanic_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_runtime_routing() -> void:
	var runtime: Object = PlayerCharacterRuntime.new()
	_expect(runtime.normalize("io") == "optimus", "Io alias should normalize to Optimus runtime")
	_expect(runtime.get_player_controller_key("optimus") == "optimus_player_controller", "Optimus should route to its player controller")
	_expect(runtime.get_skill_config_key("optimus") == "", "Optimus v1 should not expose Smasher skill config")
	_expect(runtime.get_combo_state_key("optimus") == "", "Optimus v1 should not expose Smasher combo state")


func _verify_energy_state_math() -> void:
	var owner := FakeOwner.new()
	owner.optimus_energy_initialized = false
	owner.special_gauge = 0.0
	var state: Object = OptimusEnergyState.new()
	var prepared: Dictionary = state.prepare_owner_for_optimus(owner)
	_expect(owner.optimus_energy_initialized, "prepare should mark Optimus energy initialized")
	_expect(is_equal_approx(owner.special_gauge, 500.0), "prepare should fill Optimus battery")
	_expect(is_equal_approx(float(prepared.get("player_paddle_width", 0.0)), 296.0), "full battery should use the large Optimus paddle")
	_expect(is_equal_approx(float(prepared.get("runtime_paddle_base_width", 0.0)), 296.0), "full battery should publish Optimus runtime paddle base width")

	var drained: Dictionary = state.update_energy(10.0, 500.0)
	_expect(is_equal_approx(float(drained.get("special_gauge", 0.0)), 430.0), "Optimus should drain 7 gauge per second")
	var drained_base_width: float = float(drained.get("runtime_paddle_base_width", 0.0))
	_expect(drained_base_width < 296.0, "drained battery should shrink the runtime paddle base width")
	_expect(drained_base_width > 240.0, "partially drained battery should stay above minimum base width")
	_expect(not drained.has("player_paddle_width"), "per-tick energy updates should leave final paddle width to shared composition")

	var empty: Dictionary = state.build_scale_snapshot(0.0)
	_expect(is_equal_approx(float(empty.get("player_paddle_width", 0.0)), 240.0), "empty battery should clamp to minimum paddle width")
	_expect(is_equal_approx(float(empty.get("optimus_speed_multiplier", 0.0)), 0.25), "empty battery should clamp movement penalty")

	var warming: Dictionary = state.update_manual_charge(0.25, true, 250.0)
	_expect(not bool(warming.get("optimus_charge_active", true)), "short hold should not start Optimus manual charge")
	_expect(is_equal_approx(float(warming.get("optimus_charge_hold_ratio", 0.0)), 0.5), "manual charge should expose hold progress")
	var charging: Dictionary = state.update_manual_charge(0.25, true, 250.0)
	_expect(bool(charging.get("optimus_charge_active", false)), "hold threshold should start Optimus manual charge")
	_expect(is_equal_approx(float(charging.get("special_gauge", 0.0)), 265.0), "manual charge should recover 60 gauge per second once active")
	var paused_drain: Dictionary = state.update_energy(1.0, float(charging.get("special_gauge", 0.0)), state.is_manual_charge_active())
	_expect(is_equal_approx(float(paused_drain.get("special_gauge", 0.0)), 265.0), "active manual charge should pause natural drain")
	var released: Dictionary = state.update_manual_charge(0.016, false, 265.0)
	_expect(not bool(released.get("optimus_charge_active", true)), "manual charge release should clear active flag")
	_expect(bool(released.get("optimus_charge_movement_locked", false)), "manual charge release should briefly lock movement")
	_expect(float(released.get("optimus_charge_lock_seconds", 0.0)) > 0.45, "manual charge release lock should use the 0.5 second legacy window")


func _verify_actor_update_applies_optimus_energy() -> void:
	var owner := FakeOwner.new()
	owner.player_paddle_width = 333.0
	owner.player_paddle_height = 165.0
	owner.player_paddle_scale = owner.player_paddle_width / 155.0
	owner.player_pos = Vector2(213.5, 585.0)
	var preserved_paddle_size := Vector2(owner.player_paddle_width, owner.player_paddle_height)
	var preserved_paddle_scale: float = owner.player_paddle_scale
	var preserved_paddle_y: float = owner.player_pos.y
	var registry := FakeRegistry.new()
	registry.instances = {
		"battle_update_context": BattleUpdateContext.new(),
		"optimus_player_controller": OptimusPlayerController.new(),
		"optimus_energy_state": OptimusEnergyState.new(),
		"smasher_input_reader": FakeInputReader.new(),
		"player_movement_state": PlayerMovementState.new(),
	}
	var driver: Object = ActorUpdateDriver.new()
	driver.update_player_control(owner, registry, 1.0)

	_expect(owner.gameplay_frame_counter == 1, "Optimus update should advance gameplay frame")
	_expect(is_equal_approx(owner.special_gauge, 243.0), "Optimus update should drain battery through the player controller")
	_expect(owner.runtime_paddle_base_width < 296.0 and owner.runtime_paddle_base_width > 240.0, "Optimus owner should publish the battery-derived runtime base width")
	_expect(
		Vector2(owner.player_paddle_width, owner.player_paddle_height).is_equal_approx(preserved_paddle_size),
		"Optimus actor update should not overwrite a composed final paddle size"
	)
	_expect(is_equal_approx(owner.player_paddle_scale, preserved_paddle_scale), "Optimus actor update should not overwrite final paddle draw scale")
	_expect(is_equal_approx(owner.player_pos.y, preserved_paddle_y), "Optimus actor update should not shift the composed paddle vertically")
	_expect(owner.player_speed <= 2.01, "half battery should cut Optimus max movement speed roughly in half")
	_expect(owner.optimus_energy_ratio < 0.5, "owner should publish the post-drain battery ratio")


func _verify_actor_update_manual_charge() -> void:
	var owner := FakeOwner.new()
	owner.special_gauge = 200.0
	owner.player_pos = Vector2(200.0, 603.0)
	owner.player_paddle_width = 296.0
	owner.player_paddle_height = 147.0
	var input_reader := FakeInputReader.new()
	input_reader.snapshot = {
		"direction": 0.0,
		"left_pressed": false,
		"right_pressed": false,
		"down_pressed": true,
		"action_pressed": false,
	}
	var registry := FakeRegistry.new()
	registry.instances = {
		"battle_update_context": BattleUpdateContext.new(),
		"optimus_player_controller": OptimusPlayerController.new(),
		"optimus_energy_state": OptimusEnergyState.new(),
		"smasher_input_reader": input_reader,
		"player_movement_state": PlayerMovementState.new(),
	}
	var driver: Object = ActorUpdateDriver.new()
	driver.update_player_control(owner, registry, 0.6)

	_expect(owner.optimus_charge_active, "Optimus actor update should start manual charge after a 0.5 second hold")
	_expect(owner.optimus_charge_movement_locked, "active manual charge should lock Optimus movement")
	_expect(is_equal_approx(owner.special_gauge, 236.0), "manual charge should add 60 gauge per second and pause drain")
	_expect(is_equal_approx(owner.player_speed, 0.0), "active manual charge should zero movement speed")

	input_reader.snapshot["down_pressed"] = false
	driver.update_player_control(owner, registry, 0.1)
	_expect(not owner.optimus_charge_active, "releasing down should stop manual charge")
	_expect(owner.optimus_charge_movement_locked, "manual charge release should keep the short movement lock")
	_expect(owner.optimus_charge_lock_seconds > 0.45, "manual charge release should publish lock time")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
