extends SceneTree

const ActorResultApplier := preload("res://scripts/core/battle_scene_actor_update_result_applier.gd")
const BlacksmithPlayerController := preload("res://scripts/characters/blacksmith_player_controller.gd")
const BlacksmithThorShieldState := preload("res://scripts/characters/blacksmith_thor_shield_state.gd")
const OptimusEnergyState := preload("res://scripts/characters/optimus_energy_state.gd")
const OptimusPlayerController := preload("res://scripts/characters/optimus_player_controller.gd")
const SmasherPlayerController := preload("res://scripts/characters/smasher_player_controller.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var gameplay_frame_counter := 0
	var selected_character_type := "smasher"
	var player_pos := Vector2(302.5, 700.0)
	var player_speed := 0.0
	var special_gauge := 100.0
	var special_gauge_max := 500.0
	var runtime_paddle_base_width := 155.0
	var runtime_paddle_base_height := 50.0
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var runtime_paddle_scale := 1.0
	var optimus_energy_initialized := true
	var optimus_energy_ratio := 1.0
	var optimus_paddle_scale := 1.0
	var optimus_speed_multiplier := 1.0
	var optimus_charge_active := false
	var optimus_charge_hold_seconds := 0.0
	var optimus_charge_hold_ratio := 0.0
	var optimus_charge_lock_seconds := 0.0
	var optimus_charge_movement_locked := false
	var blacksmith_umbrella_open := false
	var blacksmith_umbrella_anim_timer := 0.0
	var blacksmith_umbrella_retracting := false
	var blacksmith_umbrella_anim_direction := 1
	var blacksmith_umbrella_open_ratio := 0.0
	var blacksmith_thor_shield_open_ratio := 0.0
	var blacksmith_umbrella_raise_amount := 0.0
	var blacksmith_umbrella_shield_open_amount := 0.0
	var blacksmith_umbrella_visual_state := "closed"
	var blacksmith_umbrella_folded := true
	var blacksmith_umbrella_deployed := false
	var blacksmith_umbrella_swing_active := false
	var blacksmith_umbrella_swing_direction := 0
	var blacksmith_umbrella_swing_timer := 0.0
	var blacksmith_umbrella_gauge := 5
	var blacksmith_umbrella_gauge_max := 5
	var blacksmith_umbrella_gauge_gain := 60.0
	var blacksmith_umbrella_damage_flash_timer := 0.0
	var blacksmith_umbrella_hit_pulse_timer := 0.0
	var ball_pos := Vector2.ZERO
	var ball_vel := Vector2.ZERO
	var ball_impact_boost := 1.0
	var player_collision_cooldown := 0.0
	var runtime_perk_gold := 0


class FakeRuntimePerkState:
	extends RefCounted

	var reverb_notifications := 0

	func notify_perk_fusion_skill_used() -> void:
		reverb_notifications += 1


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeInputReader:
	extends RefCounted

	var snapshot: Dictionary = {}

	func get_snapshot() -> Dictionary:
		return snapshot.duplicate(true)


class PassthroughPlayerController:
	extends RefCounted

	func update(
		_delta: float,
		frame_counter: int,
		player_pos: Vector2,
		player_speed: float,
		config: Dictionary,
		_deps: Dictionary
	) -> Dictionary:
		return {
			"frame_counter": frame_counter + 1,
			"player_pos": player_pos,
			"player_speed": player_speed,
			"special_gauge": float(config.get("special_gauge", 0.0)),
		}


class FakePlasmaState:
	extends RefCounted

	var charging := true
	var activated := false
	var spend_per_update := 10.0

	func update_input(
		_input_snapshot: Dictionary,
		_current_msec: int,
		special_gauge: float,
		_player_pos: Vector2,
		_config: Dictionary,
		_deps: Dictionary
	) -> Dictionary:
		return {
			"special_gauge": max(0.0, special_gauge - spend_per_update),
			"charging": charging,
			"activated": activated,
		}


class FakeShieldKitingState:
	extends RefCounted

	func update_input(
		_input_snapshot: Dictionary,
		_current_msec: int,
		special_gauge: float,
		player_pos: Vector2,
		_config: Dictionary,
		_deps: Dictionary
	) -> Dictionary:
		return {
			"special_gauge": special_gauge,
			"movement_locked": true,
			"locked_player_x": player_pos.x,
		}


func _init() -> void:
	_verify_optimus_manual_charge_edge()
	_verify_baltor_thor_shield_edges()
	_verify_plasma_edge_survives_shield_kiting_return()
	if _failures.is_empty():
		print("perk_fusion_character_skill_edge_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_optimus_manual_charge_edge() -> void:
	var owner := FakeOwner.new()
	owner.selected_character_type = "optimus"
	owner.special_gauge = 250.0
	var runtime_perk_state := FakeRuntimePerkState.new()
	var registry := FakeRegistry.new()
	registry.instances["runtime_perk_state"] = runtime_perk_state
	var input_reader := FakeInputReader.new()
	input_reader.snapshot = {"down_pressed": true}
	var energy_state := OptimusEnergyState.new()
	var controller := OptimusPlayerController.new()
	controller.shared_controller = PassthroughPlayerController.new()
	var deps := {
		"input_reader": input_reader,
		"optimus_energy_state": energy_state,
	}
	var applier := ActorResultApplier.new()

	var warmup: Dictionary = controller.update(
		0.25,
		0,
		owner.player_pos,
		owner.player_speed,
		_optimus_config(owner),
		deps
	)
	_expect(not bool(warmup.get("activated", false)), "Optimus charge warmup must not publish a skill edge")
	applier.apply_player_result(owner, registry, warmup)
	_expect(runtime_perk_state.reverb_notifications == 0, "Optimus charge warmup must not start Reverb")

	var started: Dictionary = controller.update(
		0.25,
		1,
		owner.player_pos,
		owner.player_speed,
		_optimus_config(owner),
		deps
	)
	_expect(bool(started.get("activated", false)), "Optimus manual charge threshold should publish an activation edge")
	_expect(str(started.get("activated_skill", "")) == "optimus_manual_charge", "Optimus should publish its canonical manual-charge skill id")
	applier.apply_player_result(owner, registry, started)
	_expect(runtime_perk_state.reverb_notifications == 1, "Optimus manual charge should start Reverb exactly once")

	var held: Dictionary = controller.update(
		0.10,
		2,
		owner.player_pos,
		owner.player_speed,
		_optimus_config(owner),
		deps
	)
	_expect(not bool(held.get("activated", false)), "held Optimus manual charge must not repeat the activation edge")
	applier.apply_player_result(owner, registry, held)
	input_reader.snapshot = {"down_pressed": false}
	var released: Dictionary = controller.update(
		0.016,
		3,
		owner.player_pos,
		owner.player_speed,
		_optimus_config(owner),
		deps
	)
	applier.apply_player_result(owner, registry, released)
	_expect(runtime_perk_state.reverb_notifications == 1, "Optimus held/release/drain frames must not extend Reverb")


func _verify_baltor_thor_shield_edges() -> void:
	var owner := FakeOwner.new()
	owner.selected_character_type = "baltor"
	owner.special_gauge = 90.0
	var runtime_perk_state := FakeRuntimePerkState.new()
	var registry := FakeRegistry.new()
	registry.instances["runtime_perk_state"] = runtime_perk_state
	var input_reader := FakeInputReader.new()
	var shield_state := BlacksmithThorShieldState.new()
	var controller := BlacksmithPlayerController.new()
	controller.shared_controller = PassthroughPlayerController.new()
	var deps := {
		"input_reader": input_reader,
		"blacksmith_thor_shield_state": shield_state,
	}
	var config := _blacksmith_config(owner)
	var applier := ActorResultApplier.new()

	input_reader.snapshot = {
		"up_just_pressed": true,
		"action_just_pressed": false,
		"blacksmith_swing_direction": 0,
	}
	var opened: Dictionary = controller.update(0.0, 0, owner.player_pos, owner.player_speed, config, deps)
	_assert_skill_edge(opened, "thor_shield", "Baltor Thor Shield opening")
	applier.apply_player_result(owner, registry, opened)
	_expect(runtime_perk_state.reverb_notifications == 1, "Baltor Thor Shield opening should start Reverb")

	input_reader.snapshot = {}
	var deployed: Dictionary = controller.update(0.80, 1, owner.player_pos, owner.player_speed, _blacksmith_config(owner), deps)
	_expect(not bool(deployed.get("activated", false)), "Baltor held-open shield frame must not repeat its edge")
	applier.apply_player_result(owner, registry, deployed)
	input_reader.snapshot = {
		"action_just_pressed": true,
		"blacksmith_swing_direction": -1,
	}
	var swung: Dictionary = controller.update(0.0, 2, owner.player_pos, owner.player_speed, _blacksmith_config(owner), deps)
	_assert_skill_edge(swung, "thor_shield", "Baltor Thor Shield swing")
	applier.apply_player_result(owner, registry, swung)
	_expect(runtime_perk_state.reverb_notifications == 2, "Baltor Thor Shield swing should refresh Reverb once")

	input_reader.snapshot = {"up_just_pressed": true}
	var closed: Dictionary = controller.update(0.0, 3, owner.player_pos, owner.player_speed, _blacksmith_config(owner), deps)
	_expect(not bool(closed.get("activated", false)), "closing Thor Shield must not count as another skill use")
	applier.apply_player_result(owner, registry, closed)
	_expect(runtime_perk_state.reverb_notifications == 2, "Baltor held/close frames must not extend Reverb")


func _verify_plasma_edge_survives_shield_kiting_return() -> void:
	var owner := FakeOwner.new()
	owner.selected_character_type = "smasher"
	owner.special_gauge = 100.0
	var runtime_perk_state := FakeRuntimePerkState.new()
	var registry := FakeRegistry.new()
	registry.instances["runtime_perk_state"] = runtime_perk_state
	var input_reader := FakeInputReader.new()
	var plasma_state := FakePlasmaState.new()
	var controller := SmasherPlayerController.new()
	var deps := {
		"input_reader": input_reader,
		"smasher_plasma_state": plasma_state,
		"smasher_shield_kiting_state": FakeShieldKitingState.new(),
	}
	var applier := ActorResultApplier.new()

	var charging_first: Dictionary = controller.update(
		0.016,
		0,
		owner.player_pos,
		owner.player_speed,
		_smasher_config(owner),
		deps
	)
	_expect(bool(charging_first.get("plasma_charging", false)), "Shield Kiting early return must preserve Plasma charging state")
	_expect(not bool(charging_first.get("activated", false)), "Plasma charging must not look like a release edge")
	applier.apply_player_result(owner, registry, charging_first)
	var charging_second: Dictionary = controller.update(
		0.016,
		1,
		owner.player_pos,
		owner.player_speed,
		_smasher_config(owner),
		deps
	)
	applier.apply_player_result(owner, registry, charging_second)
	_expect(runtime_perk_state.reverb_notifications == 0, "continuous Plasma charging behind Shield Kiting must not extend Reverb")

	plasma_state.charging = false
	plasma_state.activated = true
	plasma_state.spend_per_update = 0.0
	var released: Dictionary = controller.update(
		0.016,
		2,
		owner.player_pos,
		owner.player_speed,
		_smasher_config(owner),
		deps
	)
	_assert_skill_edge(released, "plasma", "Plasma release behind Shield Kiting")
	applier.apply_player_result(owner, registry, released)
	_expect(runtime_perk_state.reverb_notifications == 1, "Plasma release behind Shield Kiting should start Reverb once")

	plasma_state.activated = false
	var idle: Dictionary = controller.update(
		0.016,
		3,
		owner.player_pos,
		owner.player_speed,
		_smasher_config(owner),
		deps
	)
	applier.apply_player_result(owner, registry, idle)
	_expect(runtime_perk_state.reverb_notifications == 1, "post-release Plasma frame must not repeat the edge")


func _optimus_config(owner: FakeOwner) -> Dictionary:
	return {
		"selected_character_type": "optimus",
		"special_gauge": owner.special_gauge,
		"gauge_max": owner.special_gauge_max,
		"optimus_paddle_base_scale": 1.0,
	}


func _blacksmith_config(owner: FakeOwner) -> Dictionary:
	return {
		"selected_character_type": "blacksmith",
		"special_gauge": owner.special_gauge,
		"paddle_width": owner.player_paddle_width,
		"paddle_height": owner.player_paddle_height,
		"player_skill_input_locked": false,
	}


func _smasher_config(owner: FakeOwner) -> Dictionary:
	return {
		"selected_character_type": "smasher",
		"special_gauge": owner.special_gauge,
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": owner.player_paddle_width,
		"paddle_height": owner.player_paddle_height,
	}


func _assert_skill_edge(result: Dictionary, skill_id: String, label: String) -> void:
	_expect(bool(result.get("activated", false)), "%s should publish an activation edge" % label)
	_expect(str(result.get("activated_skill", "")) == skill_id, "%s should publish %s" % [label, skill_id])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
