extends RefCounted

const CommandListener := preload("res://scripts/items/horn_strawberry_command_listener.gd")

const STATE_IDLE := "idle"
const STATE_TRANSFORM_EVENT := "transform_event"
const STATE_TRANSFORMED := "transformed"
const STATE_DETRANSFORM_EVENT := "detransform_event"

const TRANSFORM_GAUGE_COST := 500.0
const TRANSFORM_DURATION_SEC := 60.0
const TRANSFORM_START_EVENT_SEC := 4.5
const TRANSFORM_END_EVENT_SEC := 2.0
const TRANSFORM_MOVE_SPEED := 8.0
const TRANSFORM_GAUGE_ON_HIT := 80.0

var active := false
var state := STATE_IDLE
var transform_timer_sec := 0.0
var event_timer_sec := 0.0
var used_this_stage := false
var transform_duration_sec := TRANSFORM_DURATION_SEC
var paddle_size_bonus_pct := 0.0
var eat_paddle_growth_bonus_pct := 0.0
var command_listener: Object = CommandListener.new()


func set_equipped(is_equipped: bool, duration_sec: float = TRANSFORM_DURATION_SEC) -> void:
	if is_equipped:
		active = true
		transform_duration_sec = max(0.1, duration_sec)
	else:
		deactivate_equipment(true)


func deactivate_equipment(preserve_used_stage: bool = true) -> void:
	active = false
	_clear_runtime(preserve_used_stage)


func reset_all() -> void:
	active = false
	_clear_runtime(false)


func reset_round() -> void:
	_clear_runtime(true)


func on_stage_advance() -> void:
	_clear_runtime(false)


func can_listen_command() -> bool:
	return active and state == STATE_IDLE and not used_this_stage


func feed_command_input(input_snapshot: Dictionary, delta: float) -> bool:
	return bool(command_listener.feed_input_snapshot(input_snapshot, delta, can_listen_command()))


func can_transform(current_gauge: float) -> bool:
	return can_listen_command() and current_gauge + 0.001 >= TRANSFORM_GAUGE_COST


func begin_transform() -> void:
	if not active:
		return
	state = STATE_TRANSFORM_EVENT
	event_timer_sec = TRANSFORM_START_EVENT_SEC
	transform_timer_sec = 0.0
	used_this_stage = true
	command_listener.clear_sequence()


func update(delta: float) -> bool:
	var previous_state: String = state
	var safe_delta: float = max(0.0, delta)
	match state:
		STATE_TRANSFORM_EVENT:
			event_timer_sec = max(0.0, event_timer_sec - safe_delta)
			if event_timer_sec <= 0.0:
				state = STATE_TRANSFORMED
				transform_timer_sec = transform_duration_sec
				paddle_size_bonus_pct = 0.0
				eat_paddle_growth_bonus_pct = 0.0
		STATE_TRANSFORMED:
			transform_timer_sec = max(0.0, transform_timer_sec - safe_delta)
			if transform_timer_sec <= 0.0:
				paddle_size_bonus_pct = 0.0
				eat_paddle_growth_bonus_pct = 0.0
				state = STATE_DETRANSFORM_EVENT
				event_timer_sec = TRANSFORM_END_EVENT_SEC
		STATE_DETRANSFORM_EVENT:
			event_timer_sec = max(0.0, event_timer_sec - safe_delta)
			if event_timer_sec <= 0.0:
				state = STATE_IDLE
	return previous_state != state


func is_transformed() -> bool:
	return active and state == STATE_TRANSFORMED


func is_event_playing() -> bool:
	return active and (state == STATE_TRANSFORM_EVENT or state == STATE_DETRANSFORM_EVENT)


func is_skills_locked() -> bool:
	return is_transformed()


func is_control_locked() -> bool:
	return is_event_playing()


func has_runtime_update_work() -> bool:
	return active or state != STATE_IDLE


func get_paddle_size_bonus_pct() -> float:
	if not is_transformed():
		return 0.0
	return paddle_size_bonus_pct + eat_paddle_growth_bonus_pct


func add_eat_paddle_growth_bonus_pct(amount_pct: float = 0.20) -> bool:
	if not is_transformed():
		return false
	eat_paddle_growth_bonus_pct = max(0.0, eat_paddle_growth_bonus_pct + max(0.0, amount_pct))
	return true


func get_move_speed() -> Variant:
	if is_transformed():
		return TRANSFORM_MOVE_SPEED
	return null


func get_gauge_on_hit() -> float:
	return TRANSFORM_GAUGE_ON_HIT if is_transformed() else 0.0


func get_context() -> Dictionary:
	return {
		"equipped": active,
		"active": active,
		"state": state,
		"transformed": is_transformed(),
		"event_playing": is_event_playing(),
		"skills_locked": is_skills_locked(),
		"control_locked": is_control_locked(),
		"used_this_stage": used_this_stage,
		"transform_timer_sec": transform_timer_sec,
		"event_timer_sec": event_timer_sec,
		"transform_duration_sec": transform_duration_sec,
		"gauge_cost": TRANSFORM_GAUGE_COST,
		"move_speed": TRANSFORM_MOVE_SPEED,
		"gauge_on_hit": get_gauge_on_hit(),
		"paddle_size_bonus_pct": get_paddle_size_bonus_pct(),
		"command": command_listener.get_context(),
	}


func _clear_runtime(preserve_used_stage: bool) -> void:
	var previous_used := used_this_stage
	state = STATE_IDLE
	transform_timer_sec = 0.0
	event_timer_sec = 0.0
	paddle_size_bonus_pct = 0.0
	eat_paddle_growth_bonus_pct = 0.0
	command_listener.reset()
	used_this_stage = previous_used if preserve_used_stage else false
