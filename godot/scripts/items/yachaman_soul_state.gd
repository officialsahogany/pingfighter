extends RefCounted

const STATE_IDLE := "idle"
const STATE_REVIVAL_EVENT := "revival_event"
const STATE_TRANSFORMED := "transformed"

const MOVE_SPEED := 3.0
const PADDLE_SIZE_MULT := 0.70
const GATHER_FRAMES := 60.0
const BURST_FRAMES := 30.0
const TOTAL_FRAMES := GATHER_FRAMES + BURST_FRAMES

var equipped := false
var state := STATE_IDLE
var used_this_round := false
var animation_timer_frames := 0.0
var pending_round_reset := false
var reset_ready := false
var revival_anchor := Vector2.ZERO
var last_loss_type := ""
var last_trigger_roll_pct := -1.0
var last_triggered := false


func set_equipped(is_equipped: bool) -> void:
	equipped = is_equipped
	if not equipped:
		clear_runtime(false)


func can_try_revival() -> bool:
	return equipped and state == STATE_IDLE and not used_this_round


func try_begin_revival(
	chance_pct: float,
	loss_type: String,
	anchor: Vector2,
	roll_pct: float
) -> bool:
	last_trigger_roll_pct = roll_pct
	last_triggered = false
	if not can_try_revival():
		return false
	if chance_pct <= 0.0 or roll_pct > chance_pct:
		return false
	used_this_round = true
	state = STATE_REVIVAL_EVENT
	animation_timer_frames = 0.0
	pending_round_reset = true
	reset_ready = false
	revival_anchor = anchor
	last_loss_type = loss_type
	last_triggered = true
	return true


func on_defeat_in_yachaman() -> bool:
	if state != STATE_TRANSFORMED:
		return false
	state = STATE_IDLE
	animation_timer_frames = 0.0
	pending_round_reset = false
	reset_ready = false
	return true


func update(fps_scale: float) -> bool:
	var previous_state: String = state
	if state == STATE_REVIVAL_EVENT:
		animation_timer_frames = min(TOTAL_FRAMES, animation_timer_frames + max(0.0, fps_scale))
		if animation_timer_frames >= TOTAL_FRAMES:
			state = STATE_TRANSFORMED
			reset_ready = true
	return previous_state != state


func consume_reset_ready() -> bool:
	if not pending_round_reset or not reset_ready:
		return false
	pending_round_reset = false
	reset_ready = false
	return true


func reset_round() -> void:
	# Yachaman is a round-scoped revival form. A real round boundary clears both
	# the once-this-round flag and any transformed body, unlike Horn Strawberry's
	# stage-scoped timed command transform.
	clear_runtime(false)


func clear_runtime(preserve_used_round: bool = false) -> void:
	var previous_used := used_this_round
	state = STATE_IDLE
	animation_timer_frames = 0.0
	pending_round_reset = false
	reset_ready = false
	revival_anchor = Vector2.ZERO
	last_loss_type = ""
	last_trigger_roll_pct = -1.0
	last_triggered = false
	used_this_round = previous_used if preserve_used_round else false


func is_event_playing() -> bool:
	return equipped and state == STATE_REVIVAL_EVENT


func is_transformed() -> bool:
	return equipped and state == STATE_TRANSFORMED


func is_skills_locked() -> bool:
	return is_event_playing() or is_transformed()


func is_control_locked() -> bool:
	return is_event_playing()


func has_runtime_update_work() -> bool:
	return is_event_playing()


func get_animation_progress() -> float:
	if state != STATE_REVIVAL_EVENT:
		return 0.0
	return clampf(animation_timer_frames / TOTAL_FRAMES, 0.0, 1.0)


func get_context() -> Dictionary:
	return {
		"equipped": equipped,
		"active": equipped,
		"state": state,
		"transformed": is_transformed(),
		"event_playing": is_event_playing(),
		"skills_locked": is_skills_locked(),
		"control_locked": is_control_locked(),
		"used_this_round": used_this_round,
		"animation_timer_frames": animation_timer_frames,
		"animation_total_frames": TOTAL_FRAMES,
		"animation_progress": get_animation_progress(),
		"pending_round_reset": pending_round_reset,
		"reset_ready": reset_ready,
		"revival_anchor": revival_anchor,
		"move_speed": MOVE_SPEED,
		"paddle_size_mult": PADDLE_SIZE_MULT,
		"last_loss_type": last_loss_type,
		"last_trigger_roll_pct": last_trigger_roll_pct,
		"last_triggered": last_triggered,
	}
