extends RefCounted

const DASH_TOKEN_RECHARGE_FRAMES := 90.0

var dash_tokens := 1
var dash_tokens_max := 1
var dash_charge_timer := 0.0
var dash_consecutive_count := 0


func reset_full(max_tokens: int = 1) -> void:
	dash_tokens_max = max(1, max_tokens)
	dash_tokens = dash_tokens_max
	dash_charge_timer = 0.0
	dash_consecutive_count = 0


func has_full_dash_token() -> bool:
	return dash_tokens > 0


func consume_full_dash_token() -> void:
	dash_tokens = max(0, dash_tokens - 1)
	dash_charge_timer = DASH_TOKEN_RECHARGE_FRAMES
	dash_consecutive_count += 1


func update_recharge(fps_scale: float) -> bool:
	if dash_charge_timer <= 0.0:
		return false
	dash_charge_timer = max(0.0, dash_charge_timer - fps_scale)
	if dash_charge_timer > 0.0 or dash_tokens >= dash_tokens_max:
		return false
	dash_tokens = dash_tokens_max
	dash_consecutive_count = 0
	return true


func get_snapshot() -> Dictionary:
	return {
		"tokens": dash_tokens,
		"max_tokens": dash_tokens_max,
		"charge_timer": dash_charge_timer,
		"consecutive_count": dash_consecutive_count,
		"recharge_frames": DASH_TOKEN_RECHARGE_FRAMES,
	}
