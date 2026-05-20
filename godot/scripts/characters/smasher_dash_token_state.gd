extends RefCounted

const DASH_TOKEN_RECHARGE_FRAMES := 300.0
const BOOST_CHARGING_VISUAL_FRAMES := 30.0
const BOOST_CHARGING_EFFECT_FRAMES := 12.0
const BOOST_CHARGING_RECHARGE_REMAINING_MULTIPLIER := 0.10

var dash_tokens := 1
var dash_tokens_max := 1
var dash_charge_timer := 0.0
var dash_charge_timer_max := DASH_TOKEN_RECHARGE_FRAMES
var dash_consecutive_count := 0
var boost_charging_pending_dash_refund := false
var boost_charging_active := false
var boost_charging_timer := 0.0
var boost_charging_effect_timer := 0.0
var boost_charging_token_index := -1
var last_consumed_token_index := -1


func reset_full(max_tokens: int = 1) -> void:
	dash_tokens_max = max(1, max_tokens)
	dash_tokens = dash_tokens_max
	dash_charge_timer = 0.0
	dash_charge_timer_max = DASH_TOKEN_RECHARGE_FRAMES
	dash_consecutive_count = 0
	reset_round_transients()


func set_max_tokens(max_tokens: int, fill_new_tokens: bool = true) -> bool:
	var next_max: int = max(1, max_tokens)
	if next_max == dash_tokens_max:
		return false
	var previous_max: int = dash_tokens_max
	dash_tokens_max = next_max
	if next_max > previous_max and fill_new_tokens:
		dash_tokens = min(dash_tokens_max, dash_tokens + (next_max - previous_max))
	else:
		dash_tokens = min(dash_tokens, dash_tokens_max)
	if dash_tokens >= dash_tokens_max:
		dash_charge_timer = 0.0
		boost_charging_token_index = -1
	elif dash_charge_timer <= 0.0:
		dash_charge_timer = dash_charge_timer_max
	if boost_charging_token_index >= dash_tokens_max:
		boost_charging_token_index = -1
	if last_consumed_token_index >= dash_tokens_max:
		last_consumed_token_index = -1
	return true


func reset_round_transients() -> void:
	boost_charging_pending_dash_refund = false
	boost_charging_active = false
	boost_charging_timer = 0.0
	boost_charging_effect_timer = 0.0
	boost_charging_token_index = -1
	last_consumed_token_index = -1


func refill_tokens() -> void:
	dash_tokens = dash_tokens_max
	dash_charge_timer = 0.0
	dash_consecutive_count = 0
	boost_charging_token_index = -1
	last_consumed_token_index = -1


func has_full_dash_token() -> bool:
	return dash_tokens > 0 or boost_charging_pending_dash_refund


func has_chain_dash_token() -> bool:
	return (dash_tokens_max > 1 and dash_tokens > 0) or boost_charging_pending_dash_refund


func has_boost_charging_pending_dash_refund() -> bool:
	return boost_charging_pending_dash_refund


func consume_boost_charging_pending_dash_refund() -> bool:
	if not boost_charging_pending_dash_refund:
		return false
	boost_charging_pending_dash_refund = false
	boost_charging_token_index = -1
	return true


func reset_boost_charging_pending_dash_refund() -> void:
	boost_charging_pending_dash_refund = false
	boost_charging_token_index = -1


func consume_full_dash_token(recharge_frames: float = DASH_TOKEN_RECHARGE_FRAMES) -> bool:
	last_consumed_token_index = -1
	if consume_boost_charging_pending_dash_refund():
		dash_consecutive_count += 1
		return false
	var was_recharging_token: bool = dash_charge_timer > 0.0 and dash_tokens < dash_tokens_max
	var previous_tokens: int = dash_tokens
	dash_tokens = max(0, dash_tokens - 1)
	if dash_tokens < previous_tokens:
		last_consumed_token_index = clamp(dash_tokens, 0, dash_tokens_max - 1)
	dash_charge_timer_max = max(1.0, recharge_frames)
	if dash_tokens >= dash_tokens_max:
		dash_charge_timer = 0.0
	elif not was_recharging_token:
		dash_charge_timer = dash_charge_timer_max
	dash_consecutive_count += 1
	return true


func update_recharge(fps_scale: float, recharge_frames: float = DASH_TOKEN_RECHARGE_FRAMES) -> bool:
	_update_boost_charging(fps_scale)
	var next_max: float = max(1.0, recharge_frames)
	# Why: dash_boost (and any other recharge-frames discount) can shrink
	# `recharge_frames` mid-charge. Without rescaling the in-flight timer the
	# HUD ratio (timer/max) breaks — a 50%-charged token reads as fully empty
	# the moment max drops far below timer, then snaps to ready a frame later.
	# Preserve the charge fraction across the transition.
	if dash_charge_timer > 0.0 and dash_charge_timer_max > 0.0 and not is_equal_approx(next_max, dash_charge_timer_max):
		var charge_fraction: float = clamp(dash_charge_timer / dash_charge_timer_max, 0.0, 1.0)
		dash_charge_timer = clamp(charge_fraction * next_max, 0.0, next_max)
	dash_charge_timer_max = next_max
	if dash_charge_timer <= 0.0:
		return false
	dash_charge_timer = max(0.0, dash_charge_timer - fps_scale)
	if dash_charge_timer > 0.0 or dash_tokens >= dash_tokens_max:
		return false
	var completed_token_index: int = dash_tokens
	dash_tokens = min(dash_tokens_max, dash_tokens + 1)
	if boost_charging_token_index == completed_token_index:
		boost_charging_token_index = -1
	if dash_tokens >= dash_tokens_max:
		dash_consecutive_count = 0
		boost_charging_token_index = -1
	else:
		dash_charge_timer = dash_charge_timer_max
	return true


func try_arm_boost_charging(chance_pct: float, token_index: int = -1) -> bool:
	if chance_pct <= 0.0:
		return false
	if randf() >= chance_pct / 100.0:
		return false
	boost_charging_pending_dash_refund = true
	boost_charging_active = true
	boost_charging_timer = BOOST_CHARGING_VISUAL_FRAMES
	boost_charging_effect_timer = BOOST_CHARGING_EFFECT_FRAMES
	boost_charging_token_index = _resolve_boost_charging_token_index(token_index)
	_apply_boost_charging_recharge_discount()
	return true


func get_last_consumed_token_index() -> int:
	return last_consumed_token_index


func get_snapshot() -> Dictionary:
	return {
		"tokens": dash_tokens,
		"max_tokens": dash_tokens_max,
		"charge_timer": dash_charge_timer,
		"consecutive_count": dash_consecutive_count,
		"recharge_frames": dash_charge_timer_max,
		"boost_charging_pending_dash_refund": boost_charging_pending_dash_refund,
		"boost_charging_active": boost_charging_active,
		"boost_charging_timer": boost_charging_timer,
		"boost_charging_visual_frames": BOOST_CHARGING_VISUAL_FRAMES,
		"boost_charging_effect_timer": boost_charging_effect_timer,
		"boost_charging_effect_duration": BOOST_CHARGING_EFFECT_FRAMES,
		"boost_charging_token_index": boost_charging_token_index,
	}


func _update_boost_charging(fps_scale: float) -> void:
	if boost_charging_effect_timer > 0.0:
		boost_charging_effect_timer = max(0.0, boost_charging_effect_timer - fps_scale)
	if boost_charging_timer <= 0.0:
		boost_charging_active = false
		boost_charging_timer = 0.0
		return
	boost_charging_timer = max(0.0, boost_charging_timer - fps_scale)
	if boost_charging_timer <= 0.0:
		boost_charging_active = false


func _resolve_boost_charging_token_index(token_index: int) -> int:
	var resolved_index: int = token_index
	if resolved_index < 0:
		resolved_index = last_consumed_token_index
	if resolved_index < 0 and dash_tokens < dash_tokens_max:
		resolved_index = dash_tokens
	if resolved_index < 0:
		return -1
	return clamp(resolved_index, 0, dash_tokens_max - 1)


func _apply_boost_charging_recharge_discount() -> void:
	if dash_tokens >= dash_tokens_max or dash_charge_timer <= 0.0:
		return
	dash_charge_timer = max(0.0, dash_charge_timer * BOOST_CHARGING_RECHARGE_REMAINING_MULTIPLIER)
