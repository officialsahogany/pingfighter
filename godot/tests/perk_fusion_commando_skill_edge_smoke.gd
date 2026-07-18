extends SceneTree

const CommandoPlayerController := preload("res://scripts/characters/commando_player_controller.gd")

var _failures: Array[String] = []


class FakeInputReader:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {}


class FakeSharedController:
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
			"shared_marker": "preserved",
		}


class FakeEmergencyState:
	extends RefCounted

	var activated := false

	func update_input(
		_input_snapshot: Dictionary,
		_current_msec: int,
		special_gauge: float,
		_deps: Dictionary
	) -> Dictionary:
		return {
			"activated": activated,
			"special_gauge": special_gauge,
		}


class FakeSupplyState:
	extends RefCounted

	var activated := false

	func update_input(
		_input_snapshot: Dictionary,
		_delta: float,
		_special_gauge: float,
		_skill_config: Object,
		_skill_state: Object,
		_deps: Dictionary
	) -> Dictionary:
		return {
			"activated": activated,
			"special_gauge_delta": 0.0,
		}

	func cancel_transient() -> void:
		activated = false


class FakeFirearmRuntime:
	extends RefCounted

	var fired := false
	var weapon_id := "ak47"

	func update_input(
		_input_snapshot: Dictionary,
		special_gauge: float,
		_config: Dictionary,
		_deps: Dictionary
	) -> Dictionary:
		return {
			"fired": fired,
			"weapon_id": weapon_id,
			"special_gauge": special_gauge,
		}

	func is_player_control_locked() -> bool:
		return false

	func get_movement_speed_multiplier() -> float:
		return 1.0


func _init() -> void:
	_verify_commando_activation_edges()
	if _failures.is_empty():
		print("perk_fusion_commando_skill_edge_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_commando_activation_edges() -> void:
	var controller := CommandoPlayerController.new()
	controller.shared_controller = FakeSharedController.new()
	var emergency_state := FakeEmergencyState.new()
	var supply_state := FakeSupplyState.new()
	var firearm_runtime := FakeFirearmRuntime.new()
	var deps := {
		"input_reader": FakeInputReader.new(),
		"commando_emergency_supply_state": emergency_state,
		"commando_supply_drop_state": supply_state,
		"commando_firearm_runtime": firearm_runtime,
	}
	var config := {
		"special_gauge": 500.0,
		"current_msec": 1000,
		"current_stage": 1,
		"selected_character_type": "soldier",
	}

	emergency_state.activated = true
	_assert_edge(controller.update(0.1, 0, Vector2.ZERO, 0.0, config, deps), "emergency_supply")
	emergency_state.activated = false
	_assert_no_edge(controller.update(0.1, 1, Vector2.ZERO, 0.0, config, deps), "emergency supply release")

	supply_state.activated = true
	_assert_edge(controller.update(0.1, 2, Vector2.ZERO, 0.0, config, deps), "supply_drop")
	supply_state.activated = false
	_assert_no_edge(controller.update(0.1, 3, Vector2.ZERO, 0.0, config, deps), "supply drop release")

	firearm_runtime.fired = true
	_assert_edge(controller.update(0.1, 4, Vector2.ZERO, 0.0, config, deps), "ak47")
	firearm_runtime.fired = false
	_assert_no_edge(controller.update(0.1, 5, Vector2.ZERO, 0.0, config, deps), "firearm idle frame")
	firearm_runtime.fired = true
	firearm_runtime.weapon_id = ""
	_assert_edge(controller.update(0.1, 6, Vector2.ZERO, 0.0, config, deps), "commando_firearm")

	# If two Commando runtimes report on the same physics frame, publish one
	# deterministic primary edge instead of multiplying the boolean event.
	firearm_runtime.weapon_id = "ak47"
	supply_state.activated = true
	firearm_runtime.fired = true
	_assert_edge(controller.update(0.1, 7, Vector2.ZERO, 0.0, config, deps), "supply_drop")


func _assert_edge(result: Dictionary, expected_skill: String) -> void:
	_expect(bool(result.get("activated", false)), "%s should publish an activation edge" % expected_skill)
	_expect(str(result.get("activated_skill", "")) == expected_skill, "%s should be the canonical activated skill" % expected_skill)
	_expect(str(result.get("shared_marker", "")) == "preserved", "Commando activation should preserve shared-controller result fields")


func _assert_no_edge(result: Dictionary, frame_name: String) -> void:
	_expect(not bool(result.get("activated", false)), "%s should not repeat the prior activation edge" % frame_name)
	_expect(str(result.get("activated_skill", "")).is_empty(), "%s should not retain the prior activated skill" % frame_name)
	_expect(str(result.get("shared_marker", "")) == "preserved", "%s should preserve shared-controller result fields" % frame_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
