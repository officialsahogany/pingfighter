extends RefCounted

const SHADOW_STEP := "shadow_step"
const SHADOW_STEP_DASH_GRACE_FRAMES := 36.0
const SHADOW_STEP_READY_FRAMES := 60.0

var previous_down_pressed := false
var previous_dash_active := false
var previous_dash_recovering := false
var dash_origin_pos := Vector2.ZERO
var dash_origin_valid := false
var dash_grace_frames := 0.0
var shadow_step_ready_frames := 0.0
var shadow_step_activation_msec := -100000


func reset() -> void:
	reset_round()


func reset_round() -> void:
	previous_down_pressed = false
	previous_dash_active = false
	previous_dash_recovering = false
	dash_origin_pos = Vector2.ZERO
	dash_origin_valid = false
	dash_grace_frames = 0.0
	shadow_step_ready_frames = 0.0
	shadow_step_activation_msec = -100000


func try_activate_before_movement(
	delta: float,
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var input_reader: Object = deps.get("input_reader", null)
	var input_snapshot: Dictionary = input_reader.get_snapshot() if input_reader != null else {}
	var down_pressed: bool = bool(input_snapshot.get("down_pressed", false))
	var pressed_edge: bool = down_pressed and not previous_down_pressed
	previous_down_pressed = down_pressed

	shadow_step_ready_frames = max(0.0, shadow_step_ready_frames - delta * 60.0)
	if not pressed_edge or not _can_shadow_step(special_gauge, deps):
		return {"activated": false, "special_gauge": special_gauge}

	var target_pos: Vector2 = _clamp_player_pos(
		dash_origin_pos,
		float(config.get("play_left", 0.0)),
		float(config.get("play_right", 760.0)),
		float(config.get("paddle_width", 155.0))
	)
	var next_gauge: float = max(0.0, special_gauge - _get_skill_cost(deps.get("skill_config", null), SHADOW_STEP))
	var now_msec: int = Time.get_ticks_msec()
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null and skill_state.has_method("trigger_configured_cooldown"):
		skill_state.trigger_configured_cooldown(SHADOW_STEP, now_msec, deps.get("skill_config", null))
	var orb_hud_state: Object = deps.get("orb_hud_state", null)
	if orb_hud_state != null and orb_hud_state.has_method("trigger_gauge_spin"):
		orb_hud_state.trigger_gauge_spin(now_msec)
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(0.10, 5.0)
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_dash_start"):
		audio.play_dash_start(true)
	_cancel_dash_until_key_release(deps.get("dash_state", null))

	dash_origin_valid = false
	dash_grace_frames = 0.0
	previous_dash_active = false
	previous_dash_recovering = false
	shadow_step_ready_frames = SHADOW_STEP_READY_FRAMES
	shadow_step_activation_msec = now_msec
	return {
		"activated": true,
		"player_pos": target_pos,
		"player_speed": 0.0,
		"special_gauge": next_gauge,
		"skill_name": SHADOW_STEP,
	}


func observe_after_movement(delta: float, before_player_pos: Vector2, _after_player_pos: Vector2, deps: Dictionary) -> void:
	var dash_snapshot: Dictionary = _get_dash_snapshot(deps.get("dash_state", null))
	var dash_active: bool = bool(dash_snapshot.get("active", false))
	var dash_recovering: bool = bool(dash_snapshot.get("recovering", false))
	if dash_active and not previous_dash_active:
		dash_origin_pos = before_player_pos
		dash_origin_valid = true
	if dash_active or dash_recovering:
		dash_grace_frames = SHADOW_STEP_DASH_GRACE_FRAMES
	else:
		dash_grace_frames = max(0.0, dash_grace_frames - delta * 60.0)
		if dash_grace_frames <= 0.0:
			dash_origin_valid = false
	previous_dash_active = dash_active
	previous_dash_recovering = dash_recovering


func get_snapshot() -> Dictionary:
	return {
		"dash_origin_valid": dash_origin_valid,
		"dash_origin_pos": dash_origin_pos,
		"dash_grace_frames": dash_grace_frames,
		"shadow_step_ready_frames": shadow_step_ready_frames,
		"shadow_step_activation_msec": shadow_step_activation_msec,
		"dash_active": previous_dash_active,
		"dash_recovering": previous_dash_recovering,
	}


func _can_shadow_step(special_gauge: float, deps: Dictionary) -> bool:
	if not dash_origin_valid or dash_grace_frames <= 0.0:
		return false
	if _is_control_locked(deps):
		return false
	var skill_config: Object = deps.get("skill_config", null)
	if not _is_skill_equipped(skill_config, SHADOW_STEP):
		return false
	if special_gauge < _get_skill_cost(skill_config, SHADOW_STEP):
		return false
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null and skill_state.has_method("get_configured_cooldown_remaining"):
		return skill_state.get_configured_cooldown_remaining(
			SHADOW_STEP,
			Time.get_ticks_msec(),
			skill_config
		) <= 0.0
	return true


func _is_control_locked(deps: Dictionary) -> bool:
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("is_player_control_locked"):
		return bool(active_item_runtime.is_player_control_locked())
	return false


func _is_skill_equipped(skill_config: Object, skill_name: String) -> bool:
	if skill_config != null and skill_config.has_method("is_skill_equipped"):
		return bool(skill_config.is_skill_equipped(skill_name))
	return false


func _get_skill_cost(skill_config: Object, skill_name: String) -> float:
	if skill_config != null and skill_config.has_method("get_skill_cost"):
		return float(skill_config.get_skill_cost(skill_name))
	if skill_config != null and skill_config.has_method("get_snapshot"):
		var snapshot: Variant = skill_config.get_snapshot()
		if snapshot is Dictionary:
			var costs: Variant = snapshot.get("skill_costs", {})
			if costs is Dictionary:
				return float(costs.get(skill_name, 0.0))
	return 0.0


func _get_dash_snapshot(dash_state: Object) -> Dictionary:
	if dash_state != null and dash_state.has_method("get_snapshot"):
		var snapshot: Variant = dash_state.get_snapshot()
		if snapshot is Dictionary:
			return snapshot
	return {}


func _cancel_dash_until_key_release(dash_state: Object) -> void:
	if dash_state == null:
		return
	if dash_state.has_method("cancel_until_key_release"):
		dash_state.cancel_until_key_release()
	elif dash_state.has_method("reset_round"):
		dash_state.reset_round()


func _clamp_player_pos(pos: Vector2, play_left: float, play_right: float, paddle_width: float) -> Vector2:
	var half_width: float = max(1.0, paddle_width) * 0.5
	var min_x: float = play_left + half_width
	var max_x: float = play_right - half_width
	if max_x < min_x:
		return Vector2((play_left + play_right) * 0.5, pos.y)
	return Vector2(clamp(pos.x, min_x, max_x), pos.y)
