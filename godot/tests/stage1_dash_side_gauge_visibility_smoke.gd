extends SceneTree

const Stage1DashSideGaugeRenderer := preload("res://scripts/stages/stage1/stage1_dash_side_gauge_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_token_visibility_gate()
	_verify_charge_timer_guard()
	_verify_optimus_excluded()

	if _failures.is_empty():
		print("stage1_dash_side_gauge_visibility_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _base_context(tokens: int) -> Dictionary:
	# Smasher with 3 max dash tokens and an active recharge in progress.
	return {
		"selected_character_type": "smasher",
		"dash_max_tokens": 3,
		"dash_tokens": tokens,
		"dash_charge_timer": 120.0,
		"dash_recharge_frames": 300.0,
	}


func _verify_token_visibility_gate() -> void:
	var renderer: Object = Stage1DashSideGaugeRenderer.new()
	# Requested behavior: with 3 max tokens, hide the side gauge whenever ANY
	# token remains (3 / 2 / 1), and only show it when the player is at 0 tokens.
	# The 2/3 and 1/3 cases are the regression seal: the previous gate only
	# hid the gauge at full tokens and showed it during any partial recharge.
	_expect(
		not renderer.is_gauge_visible(_base_context(3)),
		"full dash tokens (3/3) should hide the side gauge"
	)
	_expect(
		not renderer.is_gauge_visible(_base_context(2)),
		"2 of 3 dash tokens should hide the side gauge while a token recharges"
	)
	_expect(
		not renderer.is_gauge_visible(_base_context(1)),
		"1 of 3 dash tokens should hide the side gauge while a token recharges"
	)
	_expect(
		renderer.is_gauge_visible(_base_context(0)),
		"0 dash tokens with an active recharge should show the side gauge"
	)


func _verify_charge_timer_guard() -> void:
	var renderer: Object = Stage1DashSideGaugeRenderer.new()
	# 0 tokens but nothing recharging (charge_timer == 0) keeps the gauge hidden,
	# matching the original guard because there is no recharge progress to display.
	var context: Dictionary = _base_context(0)
	context["dash_charge_timer"] = 0.0
	_expect(
		not renderer.is_gauge_visible(context),
		"0 dash tokens with no active recharge should keep the side gauge hidden"
	)


func _verify_optimus_excluded() -> void:
	var renderer: Object = Stage1DashSideGaugeRenderer.new()
	var context: Dictionary = _base_context(0)
	context["selected_character_type"] = "optimus"
	_expect(
		not renderer.is_gauge_visible(context),
		"optimus uses a separate cooldown model and never shows the dash side gauge"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
