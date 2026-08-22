extends RefCounted

const SmasherWarpGatePresentation := preload("res://scripts/characters/smasher_warp_gate_presentation.gd")
const SmasherWarpGateAfterimageState := preload("res://scripts/characters/smasher_warp_gate_afterimage_state.gd")
const RuntimePerkModalTimeShift := preload("res://scripts/core/runtime_perk_modal_time_shift.gd")
const RuntimePerkProgression := preload("res://scripts/characters/runtime_perk_progression.gd")

const PORTAL_MODAL_TIME_KEYS: Array[String] = ["spawn_msec"]

const SKILL_NAME := "warp_gate"
const GAUGE_COST := 100.0
const WRAP_GAUGE_COST := 0.0
const BASE_DURATION_MSEC := 20000
const HOLD_MSEC := 500
const EXTENSION_GEAR_DURATION_BONUS := 0.25
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const DEFAULT_PLAYER_SIZE := Vector2(155.0, 50.0)
const WALL_CENTER_Y_OFFSET := -42.0
const PORTAL_LIFE_MSEC := 620
const MAX_PORTAL_BURSTS := 12
const PORTAL_PHASE_SPEED := 0.08

var active := false
var start_msec := 0
var end_msec := 0
var total_duration_msec := BASE_DURATION_MSEC
var paused_remaining_msec := 0
var hold_start_msec := -1
var hold_consumed := false
var activated_this_frame := false
var phase := 0.0
var portals: Array[Dictionary] = []
var _last_player_pos := Vector2(FIELD_WIDTH * 0.5 - DEFAULT_PLAYER_SIZE.x * 0.5, FIELD_HEIGHT - DEFAULT_PLAYER_SIZE.y)
var _last_player_size := DEFAULT_PLAYER_SIZE
var _presentation: Object = SmasherWarpGatePresentation.new()
var _afterimage_state: Object = SmasherWarpGateAfterimageState.new()
var _runtime_perk_modal_pause_started_msec := -1


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	return bool(_presentation.prewarm_step())


func reset() -> void:
	active = false
	start_msec = 0
	end_msec = 0
	total_duration_msec = BASE_DURATION_MSEC
	paused_remaining_msec = 0
	hold_start_msec = -1
	hold_consumed = false
	activated_this_frame = false
	phase = 0.0
	portals.clear()
	_afterimage_state.reset()
	_runtime_perk_modal_pause_started_msec = -1
	_presentation.hide_node_fx()


func reset_round() -> void:
	pause_between_rounds(Time.get_ticks_msec())


# 퍽 모달 동안 벽시계 앵커 동결. 규칙은 runtime_perk_modal_time_shift.gd 참조.
func pause_runtime_perk_modal_time(current_msec: int) -> void:
	_runtime_perk_modal_pause_started_msec = RuntimePerkModalTimeShift.begin_pause(
		_runtime_perk_modal_pause_started_msec, current_msec
	)


func resume_runtime_perk_modal_time(current_msec: int) -> void:
	if _runtime_perk_modal_pause_started_msec < 0:
		return
	var pause_started_msec: int = _runtime_perk_modal_pause_started_msec
	_runtime_perk_modal_pause_started_msec = -1
	shift_runtime_perk_modal_time(pause_started_msec, current_msec)


func shift_runtime_perk_modal_time(pause_started_msec: int, resumed_msec: int) -> void:
	var delta_msec: int = RuntimePerkModalTimeShift.resolve_paused_duration(pause_started_msec, resumed_msec)
	if delta_msec <= 0:
		return
	if active:
		start_msec = RuntimePerkModalTimeShift.shift_anchor(start_msec, delta_msec)
		end_msec = RuntimePerkModalTimeShift.shift_anchor(end_msec, delta_msec)
	hold_start_msec = RuntimePerkModalTimeShift.shift_anchor(hold_start_msec, delta_msec)
	RuntimePerkModalTimeShift.shift_dict_array_anchors(portals, PORTAL_MODAL_TIME_KEYS, delta_msec)
	_afterimage_state.shift_time(delta_msec)


func pause_between_rounds(current_msec: int) -> void:
	if active:
		paused_remaining_msec = max(0, end_msec - current_msec)
	active = false
	start_msec = 0
	end_msec = 0
	hold_start_msec = -1
	hold_consumed = false
	activated_this_frame = false
	portals.clear()
	_afterimage_state.reset()
	# 라운드 경계에서 앵커가 전부 지워지므로 정지 마커도 같이 버린다.
	_runtime_perk_modal_pause_started_msec = -1
	_presentation.hide_node_fx()


func update_input(
	input_snapshot: Dictionary,
	current_msec: int,
	special_gauge: float,
	player_pos: Vector2,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	_last_player_pos = player_pos
	_last_player_size = _get_player_size(config)
	activated_this_frame = false
	var result := {
		"special_gauge": special_gauge,
		"activated": false,
	}

	var down_pressed: bool = bool(input_snapshot.get("down_pressed", false))
	# 허공환영(↓/S + 좌클릭)이 같은 ↓ 키를 커맨드 토큰으로 쓴다. 좌클릭이 함께
	# 눌린 홀드는 건곤환문이 아니라 허공환영 입력이므로 홀드 타이머를 리셋한다.
	# ⚠️단, 소유권은 허공환영이 **실제로 발동 가능할 때만** 성립한다 —
	# 미장착 / 기력 부족 / 쿨타임 중 / 이미 환영 비행 중 / 입력락이면
	# 그 입력의 임자가 아니므로 건곤환문이 정상 무장돼야 한다. 장착 여부만
	# 보면 기력 100~349 구간이나 70초 쿨 내내 건곤환문이 영구 봉인된다.
	if down_pressed and _is_void_phantom_command_claimed(input_snapshot, current_msec, special_gauge, config, deps):
		hold_start_msec = -1
		hold_consumed = false
		return result
	if not down_pressed:
		hold_start_msec = -1
		hold_consumed = false
		return result

	if hold_start_msec < 0:
		hold_start_msec = current_msec

	if hold_consumed:
		return result
	if current_msec - hold_start_msec < HOLD_MSEC:
		return result
	if not _can_activate(current_msec, special_gauge, config, deps):
		return result

	var next_gauge: float = max(0.0, special_gauge - _get_skill_cost(deps.get("skill_config", null)))
	_activate(current_msec, player_pos, config, deps)
	_trigger_cooldown(current_msec, deps)
	hold_consumed = true
	activated_this_frame = true

	result["special_gauge"] = next_gauge
	result["activated"] = true
	return result


func _is_void_phantom_command_claimed(
	input_snapshot: Dictionary,
	current_msec: int,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary
) -> bool:
	if not bool(input_snapshot.get("action_pressed", false)):
		return false
	var void_phantom_state: Object = deps.get("smasher_void_phantom_state", null)
	if void_phantom_state == null or not void_phantom_state.has_method("is_command_armable"):
		# 모듈이 없으면(비-스매셔 / 구 deps) 소유권 주장도 없다 — 기존 동작 유지.
		return false
	return bool(void_phantom_state.is_command_armable(current_msec, special_gauge, config, deps))


func update_effects(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	var current_msec: int = int(context.get("current_msec", Time.get_ticks_msec()))
	phase += PORTAL_PHASE_SPEED * max(0.0, fps_scale)
	var next_player_pos: Vector2 = _get_vector2(context, "player_pos", _last_player_pos)
	var next_player_size: Vector2 = _get_vector2(context, "player_paddle_size", _last_player_size)
	_afterimage_state.update(current_msec, next_player_pos, next_player_size, context.get("dash_snapshot", {}))
	_last_player_pos = next_player_pos
	_last_player_size = next_player_size
	if _should_resume(context):
		_resume(current_msec, deps)
	if active and current_msec >= end_msec:
		_deactivate(true, current_msec, deps)
	_update_portals(current_msec)
	if not active and portals.is_empty():
		_presentation.hide_node_fx()
	_sync_audio(deps)


func draw(
	canvas: CanvasItem,
	shake_offset: Vector2 = Vector2.ZERO,
	node_fx_layout: Dictionary = {},
	timer_stack: Object = null
) -> void:
	if canvas == null:
		return
	var visual_msec: int = Time.get_ticks_msec()
	_presentation.draw(
		canvas,
		shake_offset,
		node_fx_layout,
		timer_stack,
		visual_msec,
		active,
		start_msec,
		end_msec,
		total_duration_msec,
		phase,
		_last_player_pos,
		_last_player_size,
		portals,
		_afterimage_state.get_smoke_puffs()
	)


func is_active() -> bool:
	return active


func has_visible_effects() -> bool:
	return active or not portals.is_empty() or _afterimage_state.has_visible_effects()


func needs_effect_update() -> bool:
	return active or paused_remaining_msec > 0 or not portals.is_empty() or _afterimage_state.needs_update()


func was_activated_this_frame() -> bool:
	return activated_this_frame


func get_remaining_ratio(current_msec: int = -1) -> float:
	if not active or total_duration_msec <= 0:
		return 0.0
	var now_msec: int = current_msec if current_msec >= 0 else Time.get_ticks_msec()
	return clamp(float(end_msec - now_msec) / float(total_duration_msec), 0.0, 1.0)


func get_movement_bounds(play_left: float, play_right: float, paddle_width: float) -> Dictionary:
	if not active:
		return {
			"play_left": play_left,
			"play_right": play_right,
		}
	return {
		"play_left": -max(1.0, paddle_width),
		"play_right": FIELD_WIDTH + max(1.0, paddle_width),
	}


func wrap_player_position(
	player_pos: Vector2,
	paddle_size: Vector2,
	special_gauge: float,
	deps: Dictionary = {}
) -> Dictionary:
	if not active:
		player_pos.x = clamp(player_pos.x, 0.0, FIELD_WIDTH - max(1.0, paddle_size.x))
		return {
			"player_pos": player_pos,
			"special_gauge": special_gauge,
			"wrapped": false,
		}
	var next_gauge: float = special_gauge
	var wrapped := false
	var paddle_width: float = max(1.0, paddle_size.x)
	if player_pos.x < 0.0:
		_spawn_wall_portal_pair("exit_left", 0.0, "enter_right", FIELD_WIDTH)
		player_pos.x += max(1.0, FIELD_WIDTH - paddle_width)
		next_gauge = max(0.0, next_gauge - WRAP_GAUGE_COST)
		wrapped = true
	elif player_pos.x + paddle_width > FIELD_WIDTH:
		_spawn_wall_portal_pair("exit_right", FIELD_WIDTH, "enter_left", 0.0)
		player_pos.x -= max(1.0, FIELD_WIDTH - paddle_width)
		next_gauge = max(0.0, next_gauge - WRAP_GAUGE_COST)
		wrapped = true

	if wrapped:
		var afterimage_msec: int = int(deps.get("current_msec", Time.get_ticks_msec()))
		_afterimage_state.start_from_wrap(afterimage_msec, player_pos, paddle_size, _last_player_pos, FIELD_WIDTH, deps)
		_trigger_wrap_feedback(deps)
	return {
		"player_pos": player_pos,
		"special_gauge": next_gauge,
		"wrapped": wrapped,
	}


func get_mirror_offset_x(player_pos: Vector2, paddle_width: float) -> float:
	if not active:
		return 0.0
	var center_x: float = player_pos.x + paddle_width * 0.5
	if center_x < 0.0:
		return FIELD_WIDTH
	if center_x > FIELD_WIDTH:
		return -FIELD_WIDTH
	return 0.0


func get_ball_collision_context(player_pos: Vector2, paddle_size: Vector2) -> Dictionary:
	var context := {
		"warp_gate_active": active,
		"player_paddle_mirror_offset_x": get_mirror_offset_x(player_pos, paddle_size.x),
	}
	context.merge(_afterimage_state.get_ball_collision_context(), true)
	return context


func get_actor_draw_context(player_pos: Vector2, paddle_size: Vector2) -> Dictionary:
	var mirror_offset_x: float = get_mirror_offset_x(player_pos, paddle_size.x)
	var context := {
		"warp_gate_active": active,
		"warp_gate_mirror_offset_x": mirror_offset_x,
		"warp_gate_player_visual_offset_x": mirror_offset_x,
	}
	context.merge(_afterimage_state.get_actor_draw_context(), true)
	return context


func consume_afterimage_hit(sample_id: int, impact_pos: Vector2, current_msec: int) -> bool:
	return bool(_afterimage_state.consume_hit(sample_id, impact_pos, current_msec))


func get_afterimage_state_for_tests() -> Object:
	return _afterimage_state


func get_status_context() -> Dictionary:
	return {
		"active": active,
		"remaining_ratio": get_remaining_ratio(),
		"remaining_msec": max(0, end_msec - Time.get_ticks_msec()) if active else 0,
		"total_duration_msec": total_duration_msec,
		"paused_remaining_msec": paused_remaining_msec,
	}


func _activate(current_msec: int, player_pos: Vector2, config: Dictionary, deps: Dictionary) -> void:
	_last_player_pos = player_pos
	_last_player_size = _get_player_size(config)
	total_duration_msec = _get_duration_msec(deps)
	start_msec = current_msec
	end_msec = current_msec + total_duration_msec
	paused_remaining_msec = 0
	active = true
	portals.clear()
	_spawn_wall_portal_pair("open_left", 0.0, "open_right", FIELD_WIDTH)
	_play_audio(deps)
	_trigger_activation_feedback(deps)


func _resume(current_msec: int, deps: Dictionary) -> void:
	var preserved_total_msec: int = max(total_duration_msec, BASE_DURATION_MSEC, paused_remaining_msec)
	total_duration_msec = preserved_total_msec
	start_msec = current_msec - max(0, total_duration_msec - paused_remaining_msec)
	end_msec = current_msec + paused_remaining_msec
	paused_remaining_msec = 0
	active = true
	_spawn_wall_portal_pair("resume_left", 0.0, "resume_right", FIELD_WIDTH)
	_play_audio(deps)


func _deactivate(spawn_fade: bool, _current_msec: int, deps: Dictionary) -> void:
	if spawn_fade:
		_spawn_wall_portal_pair("fade_left", 0.0, "fade_right", FIELD_WIDTH)
	active = false
	start_msec = 0
	end_msec = 0
	hold_start_msec = -1
	hold_consumed = false
	paused_remaining_msec = 0
	_stop_audio(deps)


func _should_resume(context: Dictionary) -> bool:
	if active or paused_remaining_msec <= 0:
		return false
	if not bool(context.get("ball_active", false)):
		return false
	var ball_vel: Vector2 = _get_vector2(context, "ball_vel", Vector2.ZERO)
	return ball_vel.length_squared() > 0.01


func _can_activate(current_msec: int, special_gauge: float, config: Dictionary, deps: Dictionary) -> bool:
	if active:
		return false
	if _is_input_blocked(config, deps):
		return false
	if not _is_skill_equipped(deps.get("skill_config", null)):
		return false
	if special_gauge < _get_skill_cost(deps.get("skill_config", null)):
		return false
	if _get_cooldown_remaining(current_msec, deps) > 0.0:
		return false
	return true


func _is_input_blocked(config: Dictionary, deps: Dictionary) -> bool:
	var power_state: Object = deps.get("power_state", null)
	if power_state != null:
		if power_state.has_method("is_freeze_active") and bool(power_state.is_freeze_active()):
			return true
		if power_state.has_method("is_parabola_active") and bool(power_state.is_parabola_active()):
			return true
	var plasma_state: Object = deps.get("smasher_plasma_state", null)
	if plasma_state != null and plasma_state.has_method("is_charging") and bool(plasma_state.is_charging()):
		return true
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("is_player_control_locked"):
		if bool(active_item_runtime.is_player_control_locked()):
			return true
	return bool(config.get("player_skill_input_locked", false))


func _get_duration_msec(deps: Dictionary) -> int:
	var extension_level: int = _get_runtime_skill_level(deps, "extension_gear")
	return int(round(float(BASE_DURATION_MSEC) * (1.0 + RuntimePerkProgression.get_value("extension_gear", "duration_bonus", extension_level))))


func _get_runtime_skill_level(deps: Dictionary, skill_id: String) -> int:
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	if runtime_perk_state != null and runtime_perk_state.has_method("get_runtime_skill_level"):
		return int(runtime_perk_state.get_runtime_skill_level(skill_id))
	return 0


func _get_cooldown_remaining(current_msec: int, deps: Dictionary) -> float:
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state == null or not skill_state.has_method("get_configured_cooldown_remaining"):
		return 0.0
	return float(skill_state.get_configured_cooldown_remaining(SKILL_NAME, current_msec, deps.get("skill_config", null)))


func _trigger_cooldown(current_msec: int, deps: Dictionary) -> void:
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null and skill_state.has_method("trigger_configured_cooldown"):
		skill_state.trigger_configured_cooldown(SKILL_NAME, current_msec, deps.get("skill_config", null))


func _get_skill_cost(skill_config: Object) -> float:
	if skill_config != null and skill_config.has_method("get_skill_cost"):
		return float(skill_config.get_skill_cost(SKILL_NAME))
	if skill_config != null and skill_config.has_method("get_snapshot"):
		var snapshot: Variant = skill_config.get_snapshot()
		if snapshot is Dictionary:
			var costs: Variant = snapshot.get("skill_costs", {})
			if costs is Dictionary:
				return float(costs.get(SKILL_NAME, GAUGE_COST))
	return GAUGE_COST


func _is_skill_equipped(skill_config: Object) -> bool:
	if skill_config != null and skill_config.has_method("is_skill_equipped"):
		return bool(skill_config.is_skill_equipped(SKILL_NAME))
	if skill_config != null and skill_config.has_method("get_snapshot"):
		var snapshot: Variant = skill_config.get_snapshot()
		if snapshot is Dictionary:
			var equipped: Variant = snapshot.get("equipped_skills", [])
			if equipped is Array:
				return equipped.has(SKILL_NAME)
	return false


func _spawn_wall_portal_pair(left_kind: String, left_x: float, right_kind: String, right_x: float) -> void:
	var y: float = clamp(_last_player_pos.y + _last_player_size.y * 0.5 + WALL_CENTER_Y_OFFSET, 92.0, FIELD_HEIGHT - 92.0)
	_spawn_portal(left_kind, Vector2(left_x, y), -1, true)
	_spawn_portal(right_kind, Vector2(right_x, y), 1, true)


func _spawn_portal(kind: String, center: Vector2, side: int, wall_anchor: bool = false) -> void:
	portals.append({
		"kind": kind,
		"center": center,
		"side": side,
		"wall_anchor": wall_anchor,
		"spawn_msec": Time.get_ticks_msec(),
		"life_msec": PORTAL_LIFE_MSEC,
	})
	while portals.size() > MAX_PORTAL_BURSTS:
		portals.pop_front()


func _update_portals(current_msec: int) -> void:
	var write_index := 0
	for read_index in range(portals.size()):
		var portal: Dictionary = portals[read_index]
		var life_msec: int = int(portal.get("life_msec", PORTAL_LIFE_MSEC))
		var spawn_msec: int = int(portal.get("spawn_msec", current_msec))
		if current_msec - spawn_msec <= life_msec:
			portals[write_index] = portal
			write_index += 1
	if write_index < portals.size():
		portals.resize(write_index)


func _play_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_warp_gate_loop"):
		audio.play_warp_gate_loop()


func _stop_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("stop_warp_gate_loop"):
		audio.stop_warp_gate_loop()


func _sync_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("sync_warp_gate_loop"):
		audio.sync_warp_gate_loop(active)


func _trigger_activation_feedback(deps: Dictionary) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback == null:
		return
	if feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(0.12, 4.0)
	if feedback.has_method("trigger_gauge_flash"):
		feedback.trigger_gauge_flash()


func _trigger_wrap_feedback(deps: Dictionary) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback == null:
		return
	if feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(0.06, 2.0)
	if feedback.has_method("trigger_gauge_flash"):
		feedback.trigger_gauge_flash()


func _get_player_size(config: Dictionary) -> Vector2:
	return Vector2(
		max(1.0, float(config.get("paddle_width", DEFAULT_PLAYER_SIZE.x))),
		max(1.0, float(config.get("paddle_height", DEFAULT_PLAYER_SIZE.y)))
	)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return _as_vector2(source.get(key, fallback), fallback)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
