extends RefCounted

const SmasherPlayerDashController := preload("res://scripts/characters/smasher_player_dash_controller.gd")

var dash_controller: Object = SmasherPlayerDashController.new()


func update(
	delta: float,
	frame_counter: int,
	player_pos: Vector2,
	player_speed: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var fps_scale: float = delta * 60.0
	var next_frame_counter: int = frame_counter + 1
	var next_pos: Vector2 = player_pos
	var next_speed: float = player_speed
	var next_special_gauge: float = float(config.get("special_gauge", 0.0))
	var warp_gate_state: Object = deps.get("smasher_warp_gate_state", null)

	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	var player_control_locked: bool = _is_active_item_control_locked(active_item_runtime) or _is_shared_player_stun_active(deps)
	if player_control_locked:
		var drive_lock_state: Object = deps.get("drive_input_state", null)
		if drive_lock_state != null and drive_lock_state.has_method("update_cooldowns"):
			drive_lock_state.update_cooldowns(fps_scale)
		var lock_motion_config: Dictionary = _build_warp_motion_config(config, warp_gate_state)
		var lock_movement_state: Object = deps.get("movement_state", null)
		if lock_movement_state != null:
			var lock_movement: Dictionary = lock_movement_state.update_horizontal(
				delta,
				next_pos,
				0.0,
				0.0,
				float(lock_motion_config.get("play_left", 0.0)),
				float(lock_motion_config.get("play_right", 0.0)),
				float(lock_motion_config.get("paddle_width", 0.0)),
				lock_motion_config
			)
			var locked_pos: Variant = lock_movement.get("player_pos", next_pos)
			if locked_pos is Vector2:
				next_pos = locked_pos
		var locked_final: Dictionary = _finalize_warp_gate_position(next_pos, next_special_gauge, config, deps)
		return {
			"frame_counter": next_frame_counter,
			"player_pos": locked_final.get("player_pos", next_pos),
			"player_speed": 0.0,
			"special_gauge": float(locked_final.get("special_gauge", next_special_gauge)),
		}

	if active_item_runtime != null and active_item_runtime.has_method("is_aipill_active") and bool(active_item_runtime.is_aipill_active()):
		var drive_aipill_state: Object = deps.get("drive_input_state", null)
		if drive_aipill_state != null and drive_aipill_state.has_method("update_cooldowns"):
			drive_aipill_state.update_cooldowns(fps_scale)
		if active_item_runtime.has_method("apply_aipill_player_control"):
			var aipill_motion_config: Dictionary = _build_warp_motion_config(config, warp_gate_state)
			var aipill_result: Dictionary = active_item_runtime.apply_aipill_player_control(next_pos, next_speed, aipill_motion_config, delta)
			if bool(aipill_result.get("handled", false)):
				var aipill_pos: Variant = aipill_result.get("player_pos", next_pos)
				if aipill_pos is Vector2:
					next_pos = aipill_pos
				next_speed = float(aipill_result.get("player_speed", 0.0))
				var aipill_final: Dictionary = _finalize_warp_gate_position(next_pos, next_special_gauge, config, deps)
				return {
					"frame_counter": next_frame_counter,
					"player_pos": aipill_final.get("player_pos", next_pos),
					"player_speed": next_speed,
					"special_gauge": float(aipill_final.get("special_gauge", next_special_gauge)),
				}

	var input_reader: Object = deps.get("input_reader", null)
	var input_snapshot: Dictionary = input_reader.get_snapshot() if input_reader != null else {}
	# Dash is core movement, not a character skill: read its down trigger from the pre-skill-lock
	# (status-proxied) reader so it survives a 뿔딸기 / 오딘의 눈 transform, whose skill-lock proxy
	# zeroes down_pressed to block down-based skills (warp gate / EMP dive). The transform cinematic
	# still blocks dash because horizontal_input_locked forces direction == 0 (dash requires a
	# direction). Off-transform frames share one reader, so behavior is unchanged there.
	var down_pressed: bool = _read_dash_down_pressed(deps, input_reader, input_snapshot)
	var left_pressed: bool = bool(input_snapshot.get("left_pressed", false))
	var right_pressed: bool = bool(input_snapshot.get("right_pressed", false))
	var action_pressed: bool = bool(input_snapshot.get("action_pressed", false))
	var direction: float = float(input_snapshot.get("direction", 0.0))
	if bool(config.get("horizontal_input_locked", false)):
		left_pressed = false
		right_pressed = false
		direction = 0.0
	var current_msec: int = Time.get_ticks_msec()

	var drive_input_state: Object = deps.get("drive_input_state", null)
	if drive_input_state != null:
		drive_input_state.update_input_and_cooldowns(
			left_pressed,
			right_pressed,
			action_pressed,
			next_frame_counter,
			fps_scale
		)

	var recovery_activated := false
	var recovery_state: Object = deps.get("smasher_recovery_state", null)
	if recovery_state != null and recovery_state.has_method("update_input"):
		var recovery_result: Dictionary = recovery_state.update_input(
			input_snapshot,
			current_msec,
			next_special_gauge,
			next_pos,
			config,
			deps
		)
		next_special_gauge = float(recovery_result.get("special_gauge", next_special_gauge))
		recovery_activated = bool(recovery_result.get("activated", false))

	var cleanse_activated := false
	var cleanse_state: Object = deps.get("smasher_cleanse_state", null)
	if not recovery_activated and cleanse_state != null and cleanse_state.has_method("update_input"):
		var cleanse_result: Dictionary = cleanse_state.update_input(
			input_snapshot,
			current_msec,
			next_special_gauge,
			next_pos,
			config,
			deps
		)
		next_special_gauge = float(cleanse_result.get("special_gauge", next_special_gauge))
		cleanse_activated = bool(cleanse_result.get("activated", false))

	var warp_gate_activated := false
	if not recovery_activated and not cleanse_activated and warp_gate_state != null and warp_gate_state.has_method("update_input"):
		var warp_gate_result: Dictionary = warp_gate_state.update_input(
			input_snapshot,
			current_msec,
			next_special_gauge,
			next_pos,
			config,
			deps
		)
		next_special_gauge = float(warp_gate_result.get("special_gauge", next_special_gauge))
		warp_gate_activated = bool(warp_gate_result.get("activated", false))

	var smasher_wheel_state: Object = deps.get("smasher_wheel_state", null)
	if not recovery_activated and not cleanse_activated and not warp_gate_activated and smasher_wheel_state != null and smasher_wheel_state.has_method("update_input"):
		var wheel_result: Dictionary = smasher_wheel_state.update_input(
			input_snapshot,
			current_msec,
			next_special_gauge,
			next_pos,
			config,
			deps
		)
		next_special_gauge = float(wheel_result.get("special_gauge", next_special_gauge))
		if wheel_result.has("player_speed"):
			next_speed = float(wheel_result.get("player_speed", next_speed))

	var motion_config: Dictionary = _build_warp_motion_config(config, warp_gate_state)
	motion_config["special_gauge"] = next_special_gauge
	var wheel_active: bool = smasher_wheel_state != null and smasher_wheel_state.has_method("is_active") and bool(smasher_wheel_state.is_active())
	if smasher_wheel_state != null and wheel_active:
		if smasher_wheel_state.has_method("get_movement_direction"):
			direction = float(smasher_wheel_state.get_movement_direction(direction))
		if smasher_wheel_state.has_method("apply_movement_config"):
			motion_config = smasher_wheel_state.apply_movement_config(motion_config, next_speed, direction)

	var plasma_state: Object = deps.get("smasher_plasma_state", null)
	if not recovery_activated and not cleanse_activated and not warp_gate_activated and not wheel_active and plasma_state != null and plasma_state.has_method("update_input"):
		var plasma_result: Dictionary = plasma_state.update_input(
			input_snapshot,
			current_msec,
			next_special_gauge,
			next_pos,
			config,
			deps
		)
		next_special_gauge = float(plasma_result.get("special_gauge", next_special_gauge))

	var magnum_grip_state: Object = deps.get("smasher_magnum_grip_state", null)
	var skill_input_locked: bool = bool(config.get("player_skill_input_locked", false))
	if magnum_grip_state != null and skill_input_locked:
		# Transform locks preserve left/right movement, so release left+right skills explicitly.
		if magnum_grip_state.has_method("force_release_for_lock") and bool(magnum_grip_state.force_release_for_lock()):
			var audio = deps.get("audio", null)
			if audio != null and audio.has_method("stop_magnum_grip"):
				audio.stop_magnum_grip()
	elif not wheel_active and magnum_grip_state != null and magnum_grip_state.has_method("update_input"):
		var magnum_result: Dictionary = magnum_grip_state.update_input(
			input_snapshot,
			current_msec,
			next_special_gauge,
			deps
		)
		next_special_gauge = float(magnum_result.get("special_gauge", next_special_gauge))
		if bool(magnum_result.get("activated", false)):
			var audio = deps.get("audio", null)
			if audio != null and audio.has_method("play_magnum_grip"):
				audio.play_magnum_grip()

	var shield_kiting_state: Object = deps.get("smasher_shield_kiting_state", null)
	if not wheel_active and shield_kiting_state != null and shield_kiting_state.has_method("update_input"):
		var shield_result: Dictionary = shield_kiting_state.update_input(
			input_snapshot,
			current_msec,
			next_special_gauge,
			next_pos,
			config,
			deps
		)
		next_special_gauge = float(shield_result.get("special_gauge", next_special_gauge))
		if bool(shield_result.get("movement_locked", false)):
			var locked_x: float = float(shield_result.get("locked_player_x", next_pos.x))
			next_pos.x = clamp(
				locked_x,
				float(motion_config.get("play_left", 0.0)),
				float(motion_config.get("play_right", 0.0)) - float(motion_config.get("paddle_width", 0.0))
			)
			var shield_final: Dictionary = _finalize_warp_gate_position(next_pos, next_special_gauge, config, deps)
			return {
				"frame_counter": next_frame_counter,
				"player_pos": shield_final.get("player_pos", next_pos),
				"player_speed": 0.0,
				"special_gauge": float(shield_final.get("special_gauge", next_special_gauge)),
			}

	var handled_by_dash := false
	if not wheel_active:
		motion_config["special_gauge"] = next_special_gauge
		var sensor_dash: Dictionary = _try_sensor_auto_dash(next_pos, next_speed, motion_config, deps)
		if bool(sensor_dash.get("activated", false)):
			next_speed = float(sensor_dash.get("player_speed", 0.0))
			next_special_gauge = float(sensor_dash.get("special_gauge", next_special_gauge))
			motion_config["special_gauge"] = next_special_gauge
			handled_by_dash = true

	if not wheel_active and not handled_by_dash:
		motion_config["special_gauge"] = next_special_gauge
		var dash_input: Dictionary = dash_controller.handle_dash_input(
			down_pressed,
			direction,
			next_pos,
			next_speed,
			motion_config,
			deps
		)
		next_speed = float(dash_input.get("player_speed", next_speed))
		next_special_gauge = float(dash_input.get("special_gauge", next_special_gauge))
		handled_by_dash = bool(dash_input.get("handled_by_dash", false))

	if not handled_by_dash:
		var movement_state: Object = deps.get("movement_state", null)
		if movement_state != null:
			var movement: Dictionary = movement_state.update_horizontal(
				delta,
				next_pos,
				next_speed,
				direction,
				float(motion_config.get("play_left", 0.0)),
				float(motion_config.get("play_right", 0.0)),
				float(motion_config.get("paddle_width", 0.0)),
				motion_config
			)
			var moved_pos: Variant = movement.get("player_pos", next_pos)
			if moved_pos is Vector2:
				next_pos = moved_pos
			next_speed = float(movement.get("player_speed", next_speed))

	if not wheel_active:
		var dash_update: Dictionary = dash_controller.update_dash_motion(delta, next_pos, next_speed, motion_config, deps)
		var dash_pos: Variant = dash_update.get("player_pos", next_pos)
		if dash_pos is Vector2:
			next_pos = dash_pos
		next_speed = float(dash_update.get("player_speed", next_speed))

	var final_wrap: Dictionary = _finalize_warp_gate_position(next_pos, next_special_gauge, config, deps)
	var final_pos: Variant = final_wrap.get("player_pos", next_pos)
	if final_pos is Vector2:
		next_pos = final_pos
	next_special_gauge = float(final_wrap.get("special_gauge", next_special_gauge))

	return {
		"frame_counter": next_frame_counter,
		"player_pos": next_pos,
		"player_speed": next_speed,
		"special_gauge": next_special_gauge,
	}


func _read_dash_down_pressed(deps: Dictionary, input_reader: Object, input_snapshot: Dictionary) -> bool:
	var dash_input_reader: Object = deps.get("dash_input_reader", null)
	if dash_input_reader == null or dash_input_reader == input_reader or not dash_input_reader.has_method("get_snapshot"):
		return bool(input_snapshot.get("down_pressed", false))
	var dash_value: Variant = dash_input_reader.get_snapshot()
	if dash_value is Dictionary:
		return bool(dash_value.get("down_pressed", false))
	return bool(input_snapshot.get("down_pressed", false))


func _build_warp_motion_config(config: Dictionary, warp_gate_state: Object) -> Dictionary:
	if warp_gate_state == null or not warp_gate_state.has_method("get_movement_bounds"):
		return config
	var motion_bounds: Dictionary = warp_gate_state.get_movement_bounds(
		float(config.get("play_left", 0.0)),
		float(config.get("play_right", 0.0)),
		float(config.get("paddle_width", 0.0))
	)
	var motion_config := config.duplicate()
	motion_config["play_left"] = float(motion_bounds.get("play_left", config.get("play_left", 0.0)))
	motion_config["play_right"] = float(motion_bounds.get("play_right", config.get("play_right", 0.0)))
	return motion_config


func _finalize_warp_gate_position(
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var warp_gate_state: Object = deps.get("smasher_warp_gate_state", null)
	if warp_gate_state == null or not warp_gate_state.has_method("wrap_player_position"):
		return {
			"player_pos": player_pos,
			"special_gauge": special_gauge,
		}
	return warp_gate_state.wrap_player_position(
		player_pos,
		Vector2(
			max(1.0, float(config.get("paddle_width", 155.0))),
			max(1.0, float(config.get("paddle_height", 50.0)))
		),
		special_gauge,
		deps
	)


func _try_sensor_auto_dash(
	player_pos: Vector2,
	player_speed: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var runtime: Object = _get_mythic_item_runtime(deps)
	if runtime == null or not runtime.has_method("build_sensor_auto_dash_request"):
		return {"activated": false, "player_speed": player_speed}
	var request: Dictionary = runtime.build_sensor_auto_dash_request(player_pos, config, deps)
	if not bool(request.get("should_dash", false)):
		return {"activated": false, "player_speed": player_speed}
	var direction: float = float(request.get("direction", 0.0))
	var dash_result: Dictionary = dash_controller.try_start_sensor_dash(direction, player_pos, config, deps)
	if not bool(dash_result.get("started", false)):
		return {"activated": false, "player_speed": player_speed}
	if runtime.has_method("notify_sensor_auto_dash_started"):
		runtime.notify_sensor_auto_dash_started(
			_as_vector2(request.get("player_center", player_pos), player_pos),
			direction,
			deps
		)
	return {
		"activated": true,
		"player_speed": 0.0,
		"special_gauge": _get_owner_special_gauge(deps, float(config.get("special_gauge", 0.0))),
	}


func _is_active_item_control_locked(active_item_runtime: Object) -> bool:
	return (
		active_item_runtime != null
		and active_item_runtime.has_method("is_player_control_locked")
		and bool(active_item_runtime.is_player_control_locked())
	)


func _is_shared_player_stun_active(deps: Dictionary) -> bool:
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state == null:
		return false
	if status_effect_state.has_method("is_player_stun_active") and bool(status_effect_state.is_player_stun_active()):
		return true
	if status_effect_state.has_method("has_status") and bool(status_effect_state.has_status("player", "stun")):
		return true
	if status_effect_state.has_method("get_player_control_context"):
		var context: Variant = status_effect_state.get_player_control_context()
		if context is Dictionary:
			return bool(context.get("player_stun_active", false)) or float(context.get("player_stun_ratio", 0.0)) > 0.0
	return false


func _get_mythic_item_runtime(deps: Dictionary) -> Object:
	var runtime: Object = deps.get("mythic_item_runtime", null)
	if runtime != null:
		return runtime
	var registry: Object = deps.get("registry", null)
	if registry != null and registry.has_method("get_instance"):
		return registry.get_instance("mythic_item_runtime")
	return null


func _get_owner_special_gauge(deps: Dictionary, fallback: float) -> float:
	var owner: Object = deps.get("owner", null)
	if owner == null:
		return fallback
	var value: Variant = owner.get("special_gauge")
	return fallback if value == null else float(value)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
