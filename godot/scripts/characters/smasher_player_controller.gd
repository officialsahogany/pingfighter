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
	var player_control_locked: bool = (
		_is_active_item_control_locked(active_item_runtime)
		or _is_shared_player_stun_active(deps)
		or _is_void_phantom_charge_control_locked(deps)
	)
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
	var lingpet_mount_active := bool(config.get("lingpet_mount_active", deps.get("lingpet_mount_active", false)))
	if lingpet_mount_active:
		down_pressed = false
		var mounted_dash_state: Object = deps.get("dash_state", null)
		if mounted_dash_state != null:
			if mounted_dash_state.has_method("cancel_active_without_recovery"):
				mounted_dash_state.cancel_active_without_recovery()
			if mounted_dash_state.has_method("update_key_release"):
				mounted_dash_state.update_key_release(false)
	# Vision-exclusive snapshots split translation from command input. Only the
	# base player/dash movement owner opts into these fields; skill runtimes keep
	# reading the ordinary zeroed command lanes.
	var left_pressed: bool = bool(input_snapshot.get(
		"movement_left_pressed",
		input_snapshot.get("left_pressed", false)
	))
	var right_pressed: bool = bool(input_snapshot.get(
		"movement_right_pressed",
		input_snapshot.get("right_pressed", false)
	))
	var action_pressed: bool = bool(input_snapshot.get("action_pressed", false))
	var direction: float = float(input_snapshot.get(
		"movement_direction",
		input_snapshot.get("direction", 0.0)
	))
	if bool(config.get("horizontal_input_locked", false)):
		left_pressed = false
		right_pressed = false
		direction = 0.0
	var current_msec: int = Time.get_ticks_msec()

	var drive_input_state: Object = deps.get("drive_input_state", null)
	if drive_input_state != null:
		if (
			bool(config.get("vision_input_exclusive", false))
			and drive_input_state.has_method("discard_current_inputs")
		):
			# GRT-050: Vision movement directions must not seed the delayed
			# Drive command buffer. Synchronize
			# raw levels so a held direction does not become a fresh edge when
			# Shift is released.
			var vision_raw_snapshot: Dictionary = deps.get("vision_exclusive_raw_snapshot", {})
			drive_input_state.discard_current_inputs(
				bool(vision_raw_snapshot.get("left_pressed", false)),
				bool(vision_raw_snapshot.get("right_pressed", false)),
				bool(vision_raw_snapshot.get("action_pressed", false))
			)
			drive_input_state.update_cooldowns(fps_scale)
		else:
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

	# 벽력유성은 여기서 "무장"만 한다(우클릭 홀드 + 발동 조건 충족). 실제 발사는
	# 플레이어 패들 접촉 프레임에 볼-패스에서 일어나므로(파워스매싱과 동일한
	# 접촉-시점 계약) 이 경로는 활성화 에지를 발행하지 않는다 — 융합 스킬-사용
	# 훅은 발사 지점(ball_motion_event_processor._try_launch_smasher_overdrive)이
	# 직접 통지한다.
	var overdrive_state: Object = deps.get("smasher_overdrive_state", null)
	var overdrive_active: bool = overdrive_state != null and overdrive_state.has_method("is_active") and bool(overdrive_state.is_active())
	if overdrive_state != null and overdrive_state.has_method("update_input") and (overdrive_active or (not recovery_activated and not cleanse_activated)):
		var overdrive_result: Dictionary = overdrive_state.update_input(
			input_snapshot, current_msec, next_special_gauge, next_pos, config, deps
		)
		next_special_gauge = float(overdrive_result.get("special_gauge", next_special_gauge))
	var overdrive_live: bool = overdrive_state != null and overdrive_state.has_method("is_active") and bool(overdrive_state.is_active())

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
	if not recovery_activated and not cleanse_activated and not overdrive_live and not warp_gate_activated and smasher_wheel_state != null and smasher_wheel_state.has_method("update_input"):
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

	var plasma_charging := false
	var plasma_activated := false
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
		plasma_charging = bool(plasma_result.get("charging", false))
		plasma_activated = bool(plasma_result.get("activated", false))

	var magnum_activated := false
	var magnum_grip_state: Object = deps.get("smasher_magnum_grip_state", null)
	var skill_input_locked: bool = bool(config.get("player_skill_input_locked", false))
	if magnum_grip_state != null and skill_input_locked:
		# Transform locks preserve left/right movement, so release left+right skills explicitly.
		if magnum_grip_state.has_method("force_release_for_lock") and bool(magnum_grip_state.force_release_for_lock()):
			var audio = deps.get("audio", null)
			if audio != null and audio.has_method("stop_magnum_grip"):
				audio.stop_magnum_grip()
	elif not wheel_active and not overdrive_live and magnum_grip_state != null and magnum_grip_state.has_method("update_input"):
		var magnum_result: Dictionary = magnum_grip_state.update_input(
			input_snapshot,
			current_msec,
			next_special_gauge,
			deps
		)
		next_special_gauge = float(magnum_result.get("special_gauge", next_special_gauge))
		magnum_activated = bool(magnum_result.get("activated", false))
		if magnum_activated:
			var audio = deps.get("audio", null)
			if audio != null and audio.has_method("play_magnum_grip"):
				audio.play_magnum_grip()

	# 융합 스킬-사용 에지: 이 프레임에 발동한 원샷 스킬 1개(컨트롤러의
	# 상호배제 게이트 순서 그대로 first-wins). 대시는 스킬이 아니라 별도
	# 대시 훅으로 흐른다.
	var fusion_skill_edge := ""
	if recovery_activated:
		fusion_skill_edge = "recovery"
	elif cleanse_activated:
		fusion_skill_edge = "cleanse"
	elif warp_gate_activated:
		fusion_skill_edge = "warp_gate"
	elif magnum_activated:
		fusion_skill_edge = "magnum_grip"
	elif plasma_activated:
		fusion_skill_edge = "plasma"

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
			# 실드 카이팅 조기 반환도 같은 프레임의 플라즈마 차징/스킬 에지를
			# 보존해야 한다 — 여기서 유실되면 카이팅 중 플라즈마가 죽는다.
			return _apply_smasher_skill_result_fields({
				"frame_counter": next_frame_counter,
				"player_pos": shield_final.get("player_pos", next_pos),
				"player_speed": 0.0,
				"special_gauge": float(shield_final.get("special_gauge", next_special_gauge)),
			}, plasma_charging, fusion_skill_edge)

	var handled_by_dash := false
	if not wheel_active and not lingpet_mount_active:
		motion_config["special_gauge"] = next_special_gauge
		var sensor_dash: Dictionary = _try_sensor_auto_dash(next_pos, next_speed, motion_config, deps)
		if bool(sensor_dash.get("activated", false)):
			next_speed = float(sensor_dash.get("player_speed", 0.0))
			next_special_gauge = float(sensor_dash.get("special_gauge", next_special_gauge))
			motion_config["special_gauge"] = next_special_gauge
			handled_by_dash = true

	# 벽력유성은 더 이상 S+우클릭 단발 발동이 아니므로 대시와 입력이 겹치지 않는다
	# (무장은 우클릭 홀드, 대시는 S+방향). 활주 차단 게이트를 유지할 이유가 없다.
	if not wheel_active and not lingpet_mount_active and not handled_by_dash:
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

	if not wheel_active and not lingpet_mount_active:
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

	return _apply_smasher_skill_result_fields({
		"frame_counter": next_frame_counter,
		"player_pos": next_pos,
		"player_speed": next_speed,
		"special_gauge": next_special_gauge,
	}, plasma_charging, fusion_skill_edge)


func _apply_smasher_skill_result_fields(
	result: Dictionary,
	plasma_charging: bool,
	fusion_skill_edge: String
) -> Dictionary:
	if plasma_charging:
		result["plasma_charging"] = true
	if not fusion_skill_edge.is_empty():
		result["activated"] = true
		result["activated_skill"] = fusion_skill_edge
	return result


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


func _is_void_phantom_charge_control_locked(deps: Dictionary) -> bool:
	var void_phantom_state: Object = deps.get("smasher_void_phantom_state", null)
	return (
		void_phantom_state != null
		and void_phantom_state.has_method("is_player_control_locked")
		and bool(void_phantom_state.is_player_control_locked())
	)


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
