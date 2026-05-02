extends RefCounted

const DASH_TOKEN_FRAME_SPIN_DURATION_MS := 620
const DASH_TOKEN_FRAME_SPIN_DEGREES := 720.0
const GAUGE_ORB_FRAME_SPIN_DURATION_MS := 580
const GAUGE_ORB_FRAME_SPIN_DEGREES := 720.0
const GAUGE_ORB_FRAME_SPIN_TRIGGER_MIN_DROP := 20
const GAUGE_ORB_FRAME_SPIN_RETRIGGER_MS := 520

var gauge_orb_frame_spin_start_msec := -100000
var gauge_orb_frame_spin_last_trigger_msec := -100000
var gauge_orb_frame_spin_last_value := -1
var dash_token_frame_spin_start_msec := -100000
var dash_token_frame_spin_last_charges := -1


func reset_gauge(current_value: int = 0) -> void:
	gauge_orb_frame_spin_last_value = current_value
	gauge_orb_frame_spin_start_msec = -100000
	gauge_orb_frame_spin_last_trigger_msec = -100000


func reset_dash_tokens(current_charges: int) -> void:
	dash_token_frame_spin_last_charges = max(0, current_charges)
	dash_token_frame_spin_start_msec = -100000


func trigger_gauge_spin(now_msec: int) -> void:
	gauge_orb_frame_spin_start_msec = now_msec
	gauge_orb_frame_spin_last_trigger_msec = now_msec


func sync_gauge_spin(current_value: int, now_msec: int) -> void:
	var clamped_value: int = max(0, current_value)
	if gauge_orb_frame_spin_last_value < 0:
		gauge_orb_frame_spin_last_value = clamped_value
		return

	var gauge_drop: int = gauge_orb_frame_spin_last_value - clamped_value
	if gauge_drop >= GAUGE_ORB_FRAME_SPIN_TRIGGER_MIN_DROP:
		if now_msec - gauge_orb_frame_spin_last_trigger_msec >= GAUGE_ORB_FRAME_SPIN_RETRIGGER_MS:
			trigger_gauge_spin(now_msec)
	gauge_orb_frame_spin_last_value = clamped_value


func get_gauge_spin_angle(now_msec: int) -> float:
	var elapsed_msec: int = max(0, now_msec - gauge_orb_frame_spin_start_msec)
	if elapsed_msec >= GAUGE_ORB_FRAME_SPIN_DURATION_MS:
		return 0.0

	var progress: float = float(elapsed_msec) / float(GAUGE_ORB_FRAME_SPIN_DURATION_MS)
	var eased: float = 1.0 - pow(1.0 - progress, 3.0)
	return fmod(GAUGE_ORB_FRAME_SPIN_DEGREES * eased, 360.0)


func trigger_dash_token_spin(now_msec: int) -> void:
	dash_token_frame_spin_start_msec = now_msec


func sync_dash_token_spin(current_charges: int, now_msec: int) -> void:
	var clamped_charges: int = max(0, current_charges)
	if dash_token_frame_spin_last_charges < 0:
		dash_token_frame_spin_last_charges = clamped_charges
		return

	if clamped_charges < dash_token_frame_spin_last_charges:
		trigger_dash_token_spin(now_msec)
	dash_token_frame_spin_last_charges = clamped_charges


func get_dash_token_spin_angle(now_msec: int) -> float:
	var elapsed_msec: int = max(0, now_msec - dash_token_frame_spin_start_msec)
	if elapsed_msec >= DASH_TOKEN_FRAME_SPIN_DURATION_MS:
		return 0.0

	var progress: float = float(elapsed_msec) / float(DASH_TOKEN_FRAME_SPIN_DURATION_MS)
	var eased: float = 1.0 - pow(1.0 - progress, 3.0)
	return fmod(DASH_TOKEN_FRAME_SPIN_DEGREES * eased, 360.0)


func get_gauge_spin_start_msec() -> int:
	return gauge_orb_frame_spin_start_msec


func get_gauge_spin_last_trigger_msec() -> int:
	return gauge_orb_frame_spin_last_trigger_msec


func get_gauge_spin_last_value() -> int:
	return gauge_orb_frame_spin_last_value


func get_dash_token_spin_start_msec() -> int:
	return dash_token_frame_spin_start_msec


func get_dash_token_spin_last_charges() -> int:
	return dash_token_frame_spin_last_charges
