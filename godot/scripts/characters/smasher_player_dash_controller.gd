extends RefCounted


func handle_dash_input(
	down_pressed: bool,
	direction: float,
	player_pos: Vector2,
	player_speed: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var next_speed: float = player_speed
	var next_special_gauge: float = float(config.get("special_gauge", 0.0))
	var handled_by_dash: bool = false
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state != null:
		dash_state.update_key_release(down_pressed)

	if dash_state != null and dash_state.is_active():
		var use_soul_burst: bool = _should_use_soul_burst_for_chain(dash_state, next_special_gauge, deps)
		if dash_state.can_chain_dash(down_pressed, direction, use_soul_burst):
			var start_result: Dictionary = _start_dash(direction, false, player_pos, config, deps, use_soul_burst)
			if bool(start_result.get("started", false)):
				next_special_gauge = float(start_result.get("special_gauge", next_special_gauge))
				next_speed = 0.0
		handled_by_dash = true
	elif dash_state != null and dash_state.is_recovering():
		var use_soul_burst: bool = _should_use_soul_burst_for_chain(dash_state, next_special_gauge, deps)
		if dash_state.can_chain_dash_from_recovery(down_pressed, direction, use_soul_burst):
			var start_result: Dictionary = _start_dash(direction, false, player_pos, config, deps, use_soul_burst)
			if bool(start_result.get("started", false)):
				next_special_gauge = float(start_result.get("special_gauge", next_special_gauge))
				next_speed = 0.0
		next_speed = 0.0
		handled_by_dash = true
	elif dash_state != null and dash_state.can_start_from_input(down_pressed, direction):
		if dash_state.has_full_dash_token():
			var start_result: Dictionary = _start_dash(direction, false, player_pos, config, deps, false)
			if bool(start_result.get("started", false)):
				next_special_gauge = float(start_result.get("special_gauge", next_special_gauge))
				next_speed = 0.0
		elif _can_soul_burst_dash(next_special_gauge, deps):
			var start_result: Dictionary = _start_dash(direction, false, player_pos, config, deps, true)
			if bool(start_result.get("started", false)):
				next_special_gauge = float(start_result.get("special_gauge", next_special_gauge))
				next_speed = 0.0
		else:
			var start_result: Dictionary = _start_dash(direction, true, player_pos, config, deps, false)
			if bool(start_result.get("started", false)):
				next_special_gauge = float(start_result.get("special_gauge", next_special_gauge))
				next_speed = 0.0
		handled_by_dash = true

	return {
		"player_speed": next_speed,
		"handled_by_dash": handled_by_dash,
		"special_gauge": next_special_gauge,
	}


func try_start_sensor_dash(
	direction: float,
	_player_pos: Vector2,
	_config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state == null or abs(direction) <= 0.01:
		return {"started": false}
	var registry: Object = deps.get("registry", null)
	if not dash_state.start(
		sign(direction),
		false,
		deps.get("runtime_perk_state", null),
		registry,
		false,
		true
	):
		return {"started": false}

	var audio: Object = deps.get("audio", null)
	if audio != null:
		if audio.has_method("stop_dash_delay"):
			audio.stop_dash_delay()
		if audio.has_method("play_dash_start"):
			audio.play_dash_start(false)

	var feedback: Object = deps.get("feedback", null)
	if feedback != null:
		feedback.set_screen_shake(0.12, 4.0)

	return {
		"started": true,
		"player_speed": 0.0,
	}


func update_dash_motion(
	delta: float,
	player_pos: Vector2,
	player_speed: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state == null:
		return {
			"player_pos": player_pos,
			"player_speed": player_speed,
		}

	var result: Dictionary = dash_state.update(
		delta,
		player_pos,
		float(config.get("play_left", 0.0)),
		float(config.get("play_right", 0.0)),
		float(config.get("paddle_width", 0.0)),
		deps.get("runtime_perk_state", null),
		deps.get("registry", null)
	)
	var next_pos: Vector2 = player_pos
	var updated_pos: Variant = result.get("player_pos", player_pos)
	if updated_pos is Vector2:
		next_pos = updated_pos
	var next_speed: float = player_speed
	if bool(result.get("player_speed_zero", false)):
		next_speed = 0.0
	var audio: Object = deps.get("audio", null)
	if bool(result.get("recharge_completed", false)):
		var feedback: Object = deps.get("feedback", null)
		if feedback != null:
			feedback.trigger_dash_flash()
		if audio != null and audio.has_method("play_dash_charge"):
			audio.play_dash_charge()
	if audio != null:
		if bool(result.get("recovery_started", false)) and audio.has_method("play_dash_delay"):
			audio.play_dash_delay()
		elif bool(result.get("recovery_ended", false)) and audio.has_method("stop_dash_delay"):
			audio.stop_dash_delay()

	return {
		"player_pos": next_pos,
		"player_speed": next_speed,
	}


func _start_dash(
	direction: float,
	is_half: bool,
	player_pos: Vector2,
	config: Dictionary,
	deps: Dictionary,
	use_soul_burst: bool = false
) -> Dictionary:
	var dash_state: Object = deps.get("dash_state", null)
	var next_special_gauge: float = float(config.get("special_gauge", 0.0))
	var registry: Object = deps.get("registry", null)
	if use_soul_burst and not _can_soul_burst_dash(next_special_gauge, deps):
		return {"started": false, "special_gauge": next_special_gauge}
	if (
		dash_state == null
		or not dash_state.start(
			direction,
			is_half,
			deps.get("runtime_perk_state", null),
			registry,
			not use_soul_burst
		)
	):
		return {"started": false, "special_gauge": next_special_gauge}
	_try_spawn_dash_spirit(direction, is_half, player_pos, config, deps, dash_state)

	if use_soul_burst:
		var mythic_item_runtime: Object = _get_mythic_item_runtime(deps)
		if mythic_item_runtime != null and mythic_item_runtime.has_method("try_consume_soul_burst_dash"):
			var consume_result: Dictionary = mythic_item_runtime.try_consume_soul_burst_dash(
				next_special_gauge,
				_get_player_center(player_pos, config),
				direction,
				registry
			)
			if not bool(consume_result.get("activated", false)):
				_cancel_started_soul_burst_dash(dash_state)
				return {"started": false, "special_gauge": next_special_gauge}
			next_special_gauge = float(consume_result.get("special_gauge", next_special_gauge))

	var combo_state: Object = deps.get("combo_state", null)
	if combo_state != null:
		combo_state.start_dash_combo_grace()
		combo_state.clear_effects()

	var orb_hud_state: Object = deps.get("orb_hud_state", null)
	if orb_hud_state != null:
		if use_soul_burst and orb_hud_state.has_method("trigger_gauge_spin"):
			orb_hud_state.trigger_gauge_spin(Time.get_ticks_msec())
		elif orb_hud_state.has_method("trigger_dash_token_spin"):
			orb_hud_state.trigger_dash_token_spin(Time.get_ticks_msec())

	var audio: Object = deps.get("audio", null)
	if audio != null:
		if audio.has_method("stop_dash_delay"):
			audio.stop_dash_delay()
		if not use_soul_burst:
			if (
				not is_half
				and dash_state.has_method("is_dash_acceleration_active")
				and bool(dash_state.is_dash_acceleration_active())
				and audio.has_method("play_burst_up_dash")
			):
				audio.play_burst_up_dash()
			elif audio.has_method("play_dash_start"):
				audio.play_dash_start(is_half)

	var feedback: Object = deps.get("feedback", null)
	if feedback != null:
		feedback.set_screen_shake(0.12, 4.0)
	return {
		"started": true,
		"special_gauge": next_special_gauge,
		"soul_burst_dash": use_soul_burst,
	}


func _should_use_soul_burst_for_chain(dash_state: Object, special_gauge: float, deps: Dictionary) -> bool:
	if dash_state == null:
		return false
	if dash_state.has_method("has_chain_dash_token") and bool(dash_state.has_chain_dash_token()):
		return false
	return _can_soul_burst_dash(special_gauge, deps)


func _can_soul_burst_dash(special_gauge: float, deps: Dictionary) -> bool:
	var mythic_item_runtime: Object = _get_mythic_item_runtime(deps)
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("can_soul_burst_dash"):
		return false
	return bool(mythic_item_runtime.can_soul_burst_dash(special_gauge))


func _get_mythic_item_runtime(deps: Dictionary) -> Object:
	var runtime: Object = deps.get("mythic_item_runtime", null)
	if runtime != null:
		return runtime
	var registry: Object = deps.get("registry", null)
	if registry != null and registry.has_method("get_instance"):
		return registry.get_instance("mythic_item_runtime")
	return null


func _cancel_started_soul_burst_dash(dash_state: Object) -> void:
	if dash_state == null:
		return
	if dash_state.has_method("cancel_active_without_recovery"):
		dash_state.cancel_active_without_recovery()
	if dash_state.has_method("consume_next_rally_gold_multiplier"):
		dash_state.consume_next_rally_gold_multiplier()


func _get_player_center(player_pos: Vector2, config: Dictionary) -> Vector2:
	var paddle_size := Vector2(
		max(1.0, float(config.get("paddle_width", 155.0))),
		max(1.0, float(config.get("paddle_height", 50.0)))
	)
	return player_pos + paddle_size * 0.5


func _try_spawn_dash_spirit(
	direction: float,
	is_half: bool,
	player_pos: Vector2,
	config: Dictionary,
	deps: Dictionary,
	dash_state: Object
) -> void:
	var dash_spirit_state: Object = deps.get("smasher_dash_spirit_state", null)
	if dash_spirit_state == null or not dash_spirit_state.has_method("try_spawn_from_dash"):
		return
	var dash_frames: float = 0.0
	var dash_distance_multiplier: float = 1.0
	if dash_state != null and dash_state.has_method("get_snapshot"):
		var snapshot: Dictionary = dash_state.get_snapshot()
		dash_frames = float(snapshot.get("timer", 0.0))
		# 방금 시작한 실 대쉬의 스냅샷 배율(신비의 주사위 dash_distance)을
		# 그대로 물려받아 레이저 길이가 실 이동 거리와 일치하게 한다.
		dash_distance_multiplier = maxf(0.0, float(snapshot.get("dash_distance_multiplier", 1.0)))
	var paddle_size := Vector2(
		max(1.0, float(config.get("paddle_width", 155.0))),
		max(1.0, float(config.get("paddle_height", 50.0)))
	)
	dash_spirit_state.try_spawn_from_dash(direction, is_half, player_pos, paddle_size, deps, dash_frames, dash_distance_multiplier)
