extends RefCounted

const SmasherPlayerController := preload("res://scripts/characters/smasher_player_controller.gd")

var shared_controller: Object = SmasherPlayerController.new()


class SnapshotInputReader:
	extends RefCounted

	var snapshot: Dictionary = {}

	func configure(next_snapshot: Dictionary) -> Object:
		snapshot = next_snapshot.duplicate(true)
		return self

	func get_snapshot() -> Dictionary:
		return snapshot.duplicate(true)


func update(
	delta: float,
	frame_counter: int,
	player_pos: Vector2,
	player_speed: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var energy_state: Object = deps.get("optimus_energy_state", null)
	var input_snapshot: Dictionary = _get_input_snapshot(deps)
	var manual_charge_result: Dictionary = {}
	var manual_charge_locked := false
	var manual_charge_active := false
	var working_gauge: float = float(config.get("special_gauge", 500.0))
	var working_gauge_max: float = maxf(1.0, float(config.get("gauge_max", 500.0)))
	var working_paddle_base_scale: float = maxf(
		0.1,
		float(config.get("optimus_paddle_base_scale", 1.0))
	)
	if energy_state != null and energy_state.has_method("update_manual_charge"):
		manual_charge_result = energy_state.update_manual_charge(
			delta,
			bool(input_snapshot.get("down_pressed", false)),
			working_gauge,
			_is_manual_charge_blocked(deps),
			working_gauge_max,
			working_paddle_base_scale
		)
		working_gauge = float(manual_charge_result.get("special_gauge", working_gauge))
		manual_charge_locked = bool(manual_charge_result.get("optimus_charge_movement_locked", false))
		manual_charge_active = bool(manual_charge_result.get("optimus_charge_active", false))

	var optimus_config: Dictionary = config.duplicate(true)
	optimus_config["special_gauge"] = working_gauge
	optimus_config["paddle_speed"] = float(optimus_config.get("paddle_speed", 4.0))
	optimus_config["paddle_max_speed"] = float(optimus_config.get("paddle_max_speed", 4.0))
	optimus_config["paddle_accel"] = float(optimus_config.get("paddle_accel", 0.5))
	optimus_config["paddle_decel"] = float(optimus_config.get("paddle_decel", 0.25))
	optimus_config["paddle_turn_decel"] = float(optimus_config.get("paddle_turn_decel", 0.2))
	if manual_charge_locked:
		optimus_config["horizontal_input_locked"] = true
	if (
		energy_state != null
		and energy_state.has_method("apply_movement_config")
		and not bool(optimus_config.get("horn_strawberry_transformed", false))
	):
		optimus_config = energy_state.apply_movement_config(
			optimus_config,
			working_gauge,
			working_gauge_max
		)

	var movement_deps: Dictionary = _build_movement_deps(deps, input_snapshot, manual_charge_locked)
	var result: Dictionary = shared_controller.update(
		delta,
		frame_counter,
		player_pos,
		0.0 if manual_charge_locked else player_speed,
		optimus_config,
		movement_deps
	)
	if not manual_charge_result.is_empty():
		result.merge(manual_charge_result, true)
	if manual_charge_locked:
		result["player_speed"] = 0.0
	if energy_state != null and energy_state.has_method("update_energy"):
		var energy_result: Dictionary = energy_state.update_energy(
			delta,
			float(result.get("special_gauge", optimus_config.get("special_gauge", 500.0))),
			manual_charge_active or bool(optimus_config.get("optimus_energy_paused", false)),
			working_gauge_max,
			working_paddle_base_scale
		)
		result.merge(energy_result, true)
	return result


func _get_input_snapshot(deps: Dictionary) -> Dictionary:
	var input_reader: Object = deps.get("input_reader", null)
	if input_reader == null or not input_reader.has_method("get_snapshot"):
		return {}
	var value: Variant = input_reader.get_snapshot()
	if value is Dictionary:
		return value
	return {}


func _build_movement_deps(deps: Dictionary, input_snapshot: Dictionary, locked: bool) -> Dictionary:
	if not locked:
		return deps
	var next_deps: Dictionary = deps.duplicate()
	var locked_snapshot: Dictionary = input_snapshot.duplicate(true)
	locked_snapshot["left_pressed"] = false
	locked_snapshot["right_pressed"] = false
	locked_snapshot["down_pressed"] = false
	locked_snapshot["action_pressed"] = false
	locked_snapshot["direction"] = 0.0
	next_deps["input_reader"] = SnapshotInputReader.new().configure(locked_snapshot)
	return next_deps


func _is_manual_charge_blocked(deps: Dictionary) -> bool:
	if bool(deps.get("player_skill_input_locked", false)):
		return true
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("is_player_control_locked"):
		if bool(active_item_runtime.is_player_control_locked()):
			return true
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if (
		mythic_item_runtime != null
		and mythic_item_runtime.has_method("is_horn_strawberry_skills_locked")
		and bool(mythic_item_runtime.is_horn_strawberry_skills_locked())
	):
		return true
	if (
		mythic_item_runtime != null
		and mythic_item_runtime.has_method("is_horn_strawberry_control_locked")
		and bool(mythic_item_runtime.is_horn_strawberry_control_locked())
	):
		return true
	var round_state: Object = deps.get("round_state", null)
	if round_state != null and round_state.has_method("is_waiting_for_serve"):
		if bool(round_state.is_waiting_for_serve()):
			return true
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state != null:
		if dash_state.has_method("is_active") and bool(dash_state.is_active()):
			return true
		if dash_state.has_method("is_recovering") and bool(dash_state.is_recovering()):
			return true
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state != null and status_effect_state.has_method("has_status"):
		if bool(status_effect_state.has_status("player", "stun")):
			return true
	return false
