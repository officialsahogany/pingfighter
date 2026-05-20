extends SceneTree

const SmasherDashTokenState := preload("res://scripts/characters/smasher_dash_token_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_recharge_rescales_in_flight_timer_when_max_shrinks()
	_verify_recharge_rescales_in_flight_timer_when_max_grows()
	_verify_unchanged_max_keeps_timer()
	_verify_zero_timer_just_updates_max()

	if _failures.is_empty():
		print("smasher_dash_token_state_recharge_rescale_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_recharge_rescales_in_flight_timer_when_max_shrinks() -> void:
	# Mid-charge: 150/300 = 50% charged visually
	# Dash boost activates -> recharge_frames drops to 3
	# The fraction must stay ~50%, not snap to empty.
	var token_state := SmasherDashTokenState.new()
	token_state.dash_tokens_max = 1
	token_state.dash_tokens = 0
	token_state.dash_charge_timer = 150.0
	token_state.dash_charge_timer_max = 300.0

	token_state.update_recharge(0.0, 3.0)

	_expect(is_equal_approx(token_state.dash_charge_timer_max, 3.0), "max should adopt new recharge frames")
	# 50% of 3 = 1.5
	_expect(is_equal_approx(token_state.dash_charge_timer, 1.5),
		"in-flight timer should rescale to preserve charge fraction (got %f, expected 1.5)" % token_state.dash_charge_timer)
	var fraction: float = token_state.dash_charge_timer / token_state.dash_charge_timer_max
	_expect(is_equal_approx(fraction, 0.5), "charge fraction must remain ~0.5 across rescale")


func _verify_recharge_rescales_in_flight_timer_when_max_grows() -> void:
	# Mid-charge under boost: 1.5/3 = 50%, then boost ends -> recharge_frames returns to 300.
	var token_state := SmasherDashTokenState.new()
	token_state.dash_tokens_max = 1
	token_state.dash_tokens = 0
	token_state.dash_charge_timer = 1.5
	token_state.dash_charge_timer_max = 3.0

	token_state.update_recharge(0.0, 300.0)

	_expect(is_equal_approx(token_state.dash_charge_timer_max, 300.0), "max should grow to base recharge")
	_expect(is_equal_approx(token_state.dash_charge_timer, 150.0),
		"in-flight timer should rescale up to preserve fraction (got %f, expected 150.0)" % token_state.dash_charge_timer)


func _verify_unchanged_max_keeps_timer() -> void:
	# When recharge_frames does not change, only the normal fps_scale tick happens.
	var token_state := SmasherDashTokenState.new()
	token_state.dash_tokens_max = 1
	token_state.dash_tokens = 0
	token_state.dash_charge_timer = 200.0
	token_state.dash_charge_timer_max = 300.0

	token_state.update_recharge(1.0, 300.0)

	_expect(is_equal_approx(token_state.dash_charge_timer, 199.0),
		"steady-state recharge should just tick the timer once (got %f)" % token_state.dash_charge_timer)


func _verify_zero_timer_just_updates_max() -> void:
	# Token already ready (timer at 0): nothing to rescale, max simply updates.
	var token_state := SmasherDashTokenState.new()
	token_state.dash_tokens_max = 1
	token_state.dash_tokens = 1
	token_state.dash_charge_timer = 0.0
	token_state.dash_charge_timer_max = 300.0

	token_state.update_recharge(1.0, 3.0)

	_expect(is_equal_approx(token_state.dash_charge_timer, 0.0), "ready token must keep timer at 0")
	_expect(is_equal_approx(token_state.dash_charge_timer_max, 3.0), "max should update even when timer is zero")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
