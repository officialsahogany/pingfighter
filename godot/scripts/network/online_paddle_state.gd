extends RefCounted

const PlayerMovementState := preload("res://scripts/characters/player_movement_state.gd")
const SmasherDashState := preload("res://scripts/characters/smasher_dash_state.gd")

const FIELD_WIDTH := 760.0
const PADDLE_WIDTH := 155.0
const PADDLE_HEIGHT := 50.0
const HOST_Y := 700.0
const CLIENT_Y := 0.0

var side := "host"
var position := Vector2.ZERO
var velocity_x := 0.0
var movement_state: Object = PlayerMovementState.new()
var dash_state: Object = SmasherDashState.new()


func reset(next_side: String) -> void:
	side = "host" if next_side == "host" else "client"
	position = Vector2(
		(FIELD_WIDTH - PADDLE_WIDTH) * 0.5,
		HOST_Y if side == "host" else CLIENT_Y
	)
	velocity_x = 0.0
	movement_state.reset()
	dash_state.reset_full(1)


func reset_round() -> void:
	position.x = (FIELD_WIDTH - PADDLE_WIDTH) * 0.5
	position.y = HOST_Y if side == "host" else CLIENT_Y
	velocity_x = 0.0
	movement_state.reset()
	dash_state.reset_round()


func step(delta: float, input_frame: Dictionary) -> Dictionary:
	var direction := float(clampi(int(input_frame.get("move_dir", 0)), -1, 1))
	var dash_edge := bool(input_frame.get("dash_edge", false))
	var handled_by_dash: bool = bool(dash_state.is_active()) or bool(dash_state.is_recovering())
	var dash_started := false
	var half_dash := false

	# InputFrame already carries a de-bounced edge. Marking release here keeps the
	# shared Smasher dash state reusable without polling Input a second time.
	dash_state.update_key_release(false)
	if not handled_by_dash and dash_edge and dash_state.can_start_from_input(true, direction):
		half_dash = not dash_state.has_full_dash_token()
		dash_started = bool(dash_state.start(
			direction,
			half_dash,
			null,
			null,
			true,
			false
		))
		if dash_started:
			velocity_x = 0.0
			handled_by_dash = true

	if not handled_by_dash:
		var movement: Dictionary = movement_state.update_horizontal(
			delta,
			position,
			velocity_x,
			direction,
			0.0,
			FIELD_WIDTH,
			PADDLE_WIDTH
		)
		var next_position: Variant = movement.get("player_pos", position)
		if next_position is Vector2:
			position = next_position
		velocity_x = float(movement.get("player_speed", velocity_x))

	var dash_update: Dictionary = dash_state.update(
		delta,
		position,
		0.0,
		FIELD_WIDTH,
		PADDLE_WIDTH,
		null,
		null
	)
	var dash_position: Variant = dash_update.get("player_pos", position)
	if dash_position is Vector2:
		position = dash_position
	if bool(dash_update.get("player_speed_zero", false)):
		velocity_x = 0.0
	position.x = clampf(position.x, 0.0, FIELD_WIDTH - PADDLE_WIDTH)
	position.y = HOST_Y if side == "host" else CLIENT_Y
	return {
		"dash_started": dash_started,
		"half_dash": half_dash,
		"recharge_completed": bool(dash_update.get("recharge_completed", false)),
	}


func get_snapshot() -> Dictionary:
	return {
		"paddle_x": position.x,
		"paddle_vel": velocity_x,
		"dash_state": dash_state.get_snapshot(),
	}


func apply_snapshot(snapshot: Dictionary) -> void:
	position.x = clampf(float(snapshot.get("paddle_x", position.x)), 0.0, FIELD_WIDTH - PADDLE_WIDTH)
	position.y = HOST_Y if side == "host" else CLIENT_Y
	velocity_x = clampf(float(snapshot.get("paddle_vel", velocity_x)), -100.0, 100.0)
	var dash_value: Variant = snapshot.get("dash_state", {})
	if dash_value is Dictionary:
		_apply_dash_snapshot(dash_value)


func _apply_dash_snapshot(snapshot: Dictionary) -> void:
	var motion: Object = dash_state.motion_state
	if motion != null:
		motion.set("dash_active", bool(snapshot.get("active", false)))
		motion.set("dash_timer", float(snapshot.get("timer", 0.0)))
		motion.set("dash_direction", float(snapshot.get("direction", 0.0)))
		motion.set("dash_is_half", bool(snapshot.get("is_half", false)))
		motion.set("dash_stun_timer", float(snapshot.get("stun_timer", 0.0)))
		motion.set("dash_recovery_total_frames", float(snapshot.get("recovery_total_frames", 0.0)))
		motion.set("dash_available_timer", float(snapshot.get("available_timer", 0.0)))
		motion.set("dash_elapsed_frames", float(snapshot.get("elapsed_frames", 0.0)))
		motion.set("dash_distance_multiplier", float(snapshot.get("dash_distance_multiplier", 1.0)))
		motion.set("dash_acceleration_bonus", 0.0)
		motion.set("dash_acceleration_width_bonus", 0.0)
		motion.set("dash_acceleration_height_bonus", 0.0)
		motion.set("dash_acceleration_skill_level", 0)
		motion.set("dash_skip_recovery", false)
	var token: Object = dash_state.token_state
	if token != null:
		token.set("dash_tokens_max", 1)
		token.set("dash_tokens", clampi(int(snapshot.get("tokens", 1)), 0, 1))
		token.set("dash_charge_timer", float(snapshot.get("charge_timer", 0.0)))
		token.set("dash_charge_timer_max", maxf(1.0, float(snapshot.get("recharge_frames", 300.0))))
		token.set("dash_consecutive_count", maxi(0, int(snapshot.get("consecutive_count", 0))))
	dash_state.dash_key_released_since_last = bool(snapshot.get("key_released_since_last", true))
	dash_state.next_rally_gold_multiplier_armed = false
