extends RefCounted

const SmasherPlayerController := preload("res://scripts/characters/smasher_player_controller.gd")

var shared_controller: Object = SmasherPlayerController.new()


func update(
	delta: float,
	frame_counter: int,
	player_pos: Vector2,
	player_speed: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var viper_config: Dictionary = config.duplicate(true)
	viper_config["paddle_speed"] = float(viper_config.get("paddle_speed", 4.0))
	viper_config["paddle_max_speed"] = float(viper_config.get("paddle_max_speed", 4.0))
	viper_config["paddle_accel"] = float(viper_config.get("paddle_accel", 0.38))
	viper_config["paddle_decel"] = float(viper_config.get("paddle_decel", 0.38))
	viper_config["paddle_turn_decel"] = float(viper_config.get("paddle_turn_decel", 1.0))
	viper_config["player_speed"] = player_speed
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	var aipill_active: bool = (
		active_item_runtime != null
		and active_item_runtime.has_method("is_aipill_active")
		and bool(active_item_runtime.is_aipill_active())
	)
	# 묵린변신 (D15): like the AIPill autopilot, the transform must win over viper
	# skill early-returns — otherwise a viper-owned skill frame preempts the shared
	# controller and the automation never runs. Same predicate definition as the
	# smasher block (single source; drift here = "viper만 자동조작 무시" 회귀).
	var mokrin_transform_active: bool = SmasherPlayerController.is_mokrin_transform_engaged(deps)
	var skill_runtime: Object = deps.get("viper_skill_runtime", null)
	if not aipill_active and not mokrin_transform_active and skill_runtime != null and skill_runtime.has_method("try_activate_before_movement"):
		var skill_result: Dictionary = skill_runtime.try_activate_before_movement(
			delta,
			player_pos,
			float(viper_config.get("special_gauge", 0.0)),
			viper_config,
			deps
		)
		if bool(skill_result.get("handled", false)) or bool(skill_result.get("activated", false)):
			skill_result = _try_apply_chaos_jetpack_overlay(delta, skill_result, player_pos, viper_config, deps)
			var blade_dash_result: Dictionary = _try_apply_blade_dash_overlay(
				delta,
				frame_counter,
				player_pos,
				skill_result,
				viper_config,
				deps,
				skill_runtime
			)
			if not blade_dash_result.is_empty():
				return blade_dash_result
			return _build_skill_control_result(frame_counter, skill_result, player_pos, viper_config)
	var jetpack_result: Dictionary = _apply_jetpack_update(delta, {"player_pos": player_pos}, player_pos, viper_config, deps)
	var movement_start_pos: Vector2 = jetpack_result.get("player_pos", player_pos)
	var movement_config: Dictionary = _get_jetpack_movement_config(viper_config, deps.get("viper_jetpack_state", null))
	var result: Dictionary = shared_controller.update(delta, frame_counter, movement_start_pos, player_speed, movement_config, deps)
	_merge_jetpack_result_metadata(result, jetpack_result)
	if skill_runtime != null and skill_runtime.has_method("observe_after_movement"):
		var next_pos: Variant = result.get("player_pos", player_pos)
		skill_runtime.observe_after_movement(
			delta,
			player_pos,
			next_pos if next_pos is Vector2 else player_pos,
			deps
		)
	return result


func _try_apply_chaos_jetpack_overlay(
	delta: float,
	skill_result: Dictionary,
	fallback_player_pos: Vector2,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	if not bool(skill_result.get("allow_jetpack_overlay", false)):
		return skill_result
	var jetpack_state: Object = deps.get("viper_jetpack_state", null)
	if jetpack_state == null or not jetpack_state.has_method("update"):
		return skill_result
	var locked_x: float = float(skill_result.get("locked_player_x", _as_vector2(skill_result.get("player_pos", fallback_player_pos), fallback_player_pos).x))
	var base_pos: Vector2 = _as_vector2(skill_result.get("player_pos", fallback_player_pos), fallback_player_pos)
	var perf_logger: Object = deps.get("perf_logger", null)
	var sample_start: int = _perf_begin(perf_logger)
	var jetpack_result: Dictionary = jetpack_state.update(delta, base_pos, config, deps)
	_perf_end(perf_logger, "physics.viper.jetpack_update", sample_start)
	var next_pos: Vector2 = _as_vector2(jetpack_result.get("player_pos", base_pos), base_pos)
	next_pos.x = locked_x
	var overlaid_result: Dictionary = skill_result.duplicate(true)
	overlaid_result["player_pos"] = next_pos
	overlaid_result["player_speed"] = 0.0
	_merge_jetpack_result_metadata(overlaid_result, jetpack_result)
	return overlaid_result


func _try_apply_blade_dash_overlay(
	delta: float,
	frame_counter: int,
	before_player_pos: Vector2,
	skill_result: Dictionary,
	config: Dictionary,
	deps: Dictionary,
	skill_runtime: Object
) -> Dictionary:
	if skill_runtime == null or not skill_runtime.has_method("is_air_blade_dash_window_open"):
		return {}
	if not bool(skill_runtime.is_air_blade_dash_window_open(deps)):
		return {}
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state == null:
		return {}
	var dash_snapshot: Dictionary = _get_dash_snapshot(dash_state)
	var dash_busy: bool = bool(dash_snapshot.get("active", false)) or bool(dash_snapshot.get("recovering", false))
	var input_snapshot: Dictionary = _get_input_snapshot(deps)
	var down_pressed: bool = bool(input_snapshot.get("down_pressed", false))
	var direction: float = float(input_snapshot.get("direction", 0.0))
	if not dash_busy and (not down_pressed or abs(direction) <= 0.01):
		return {}
	var dash_controller: Object = _get_shared_dash_controller()
	if dash_controller == null:
		return {}

	var next_pos: Vector2 = _as_vector2(skill_result.get("player_pos", before_player_pos), before_player_pos)
	var next_speed: float = float(skill_result.get("player_speed", config.get("player_speed", 0.0)))
	var next_special_gauge: float = float(skill_result.get("special_gauge", config.get("special_gauge", 0.0)))
	var dash_config: Dictionary = config.duplicate(true)
	dash_config["player_speed"] = next_speed
	dash_config["special_gauge"] = next_special_gauge
	var dash_input: Dictionary = dash_controller.handle_dash_input(
		down_pressed,
		direction,
		next_pos,
		next_speed,
		dash_config,
		deps
	)
	next_speed = float(dash_input.get("player_speed", next_speed))
	next_special_gauge = float(dash_input.get("special_gauge", next_special_gauge))
	var handled_by_dash: bool = bool(dash_input.get("handled_by_dash", false))
	dash_snapshot = _get_dash_snapshot(dash_state)
	dash_busy = bool(dash_snapshot.get("active", false)) or bool(dash_snapshot.get("recovering", false))
	if not handled_by_dash and not dash_busy:
		return {}

	var dash_update: Dictionary = dash_controller.update_dash_motion(delta, next_pos, next_speed, dash_config, deps)
	next_pos = _as_vector2(dash_update.get("player_pos", next_pos), next_pos)
	next_speed = float(dash_update.get("player_speed", next_speed))

	if skill_runtime.has_method("sync_blade_motion_position"):
		skill_runtime.sync_blade_motion_position(next_pos)
	if skill_runtime.has_method("observe_after_movement"):
		skill_runtime.observe_after_movement(delta, before_player_pos, next_pos, deps)
	var result: Dictionary = _build_skill_control_result(frame_counter, skill_result, before_player_pos, config)
	result["player_pos"] = next_pos
	result["player_speed"] = next_speed
	result["special_gauge"] = next_special_gauge
	return result


func _build_skill_control_result(
	frame_counter: int,
	skill_result: Dictionary,
	fallback_player_pos: Vector2,
	config: Dictionary
) -> Dictionary:
	var result := {
		"frame_counter": frame_counter + 1,
		"player_pos": skill_result.get("player_pos", fallback_player_pos),
		"player_speed": float(skill_result.get("player_speed", 0.0)),
		"special_gauge": float(skill_result.get("special_gauge", config.get("special_gauge", 0.0))),
		"skill_name": skill_result.get("skill_name", ""),
		"activated": bool(skill_result.get("activated", false)),
		"ball_pos": skill_result.get("ball_pos", config.get("ball_pos", Vector2.ZERO)),
		"ball_vel": skill_result.get("ball_vel", config.get("ball_vel", Vector2.ZERO)),
		"ball_impact_boost": skill_result.get("ball_impact_boost", config.get("ball_impact_boost", 1.0)),
		"skill_gold_award": skill_result.get("skill_gold_award", 0),
		"runtime_perk_gold": skill_result.get("runtime_perk_gold", -1),
	}
	if skill_result.has("player_collision_cooldown"):
		result["player_collision_cooldown"] = float(
			skill_result.get(
				"player_collision_cooldown",
				config.get("player_collision_cooldown", 0.0)
			)
		)
	for key in skill_result.keys():
		var key_name := str(key)
		if key_name.begins_with("viper_jetpack_"):
			result[key] = skill_result[key]
	return result


func _apply_jetpack_update(
	delta: float,
	result: Dictionary,
	fallback_player_pos: Vector2,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var jetpack_state: Object = deps.get("viper_jetpack_state", null)
	if jetpack_state == null or not jetpack_state.has_method("update"):
		return result
	var next_pos: Variant = result.get("player_pos", fallback_player_pos)
	var perf_logger: Object = deps.get("perf_logger", null)
	var sample_start: int = _perf_begin(perf_logger)
	var jetpack_result: Dictionary = jetpack_state.update(
		delta,
		next_pos if next_pos is Vector2 else fallback_player_pos,
		config,
		deps
	)
	_perf_end(perf_logger, "physics.viper.jetpack_update", sample_start)
	result.merge(jetpack_result, true)
	return result


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _get_jetpack_movement_config(config: Dictionary, jetpack_state: Object) -> Dictionary:
	if bool(config.get("horn_strawberry_transformed", false)):
		return config
	if jetpack_state == null or not jetpack_state.has_method("get_movement_bonus_multiplier"):
		return config
	var multiplier: float = max(1.0, float(jetpack_state.get_movement_bonus_multiplier()))
	if multiplier <= 1.001:
		return config
	var movement_config: Dictionary = config.duplicate(true)
	for key in ["paddle_speed", "paddle_max_speed", "paddle_accel"]:
		if movement_config.has(key):
			movement_config[key] = float(movement_config[key]) * multiplier
	return movement_config


func _merge_jetpack_result_metadata(result: Dictionary, jetpack_result: Dictionary) -> void:
	for key in jetpack_result.keys():
		if key == "player_pos":
			continue
		result[key] = jetpack_result[key]


func _get_input_snapshot(deps: Dictionary) -> Dictionary:
	var input_reader: Object = deps.get("input_reader", null)
	if input_reader != null and input_reader.has_method("get_snapshot"):
		var snapshot: Variant = input_reader.get_snapshot()
		if snapshot is Dictionary:
			return snapshot
	return {}


func _get_dash_snapshot(dash_state: Object) -> Dictionary:
	if dash_state != null and dash_state.has_method("get_snapshot"):
		var snapshot: Variant = dash_state.get_snapshot()
		if snapshot is Dictionary:
			return snapshot
	return {}


func _get_shared_dash_controller() -> Object:
	if shared_controller == null:
		return null
	return shared_controller.get("dash_controller")


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
