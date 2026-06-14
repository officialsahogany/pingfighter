extends SceneTree

const Stage1DashSideGaugeRenderer := preload("res://scripts/stages/stage1/stage1_dash_side_gauge_renderer.gd")

# Conservative worst-case visible body half-width (game px at scale 1.0) across
# the playable characters, measured from the runtime idle/walk sheets
# (blacksmith ~46.8, smasher idle ~46.5). The bar must stay LEFT of this so it
# never overlaps the character at any paddle scale.
const WIDEST_BODY_HALF_GAME_PX := 47.0
# Base player paddle width; paddle_size.x = 155 * scale in normal play.
const BASE_PADDLE_WIDTH := 155.0

var _failures: Array[String] = []


func _init() -> void:
	_verify_offset_tracks_scale()
	_verify_offset_tracks_shrink()
	_verify_closer_than_old_and_no_body_overlap()
	_verify_center_uses_raw_paddle_width_with_context_scale()
	_verify_viper_pair_shift()
	_verify_shake_is_applied()

	if _failures.is_empty():
		print("stage1_dash_side_gauge_anchor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


# Build a context + paddle geometry for a given sprite scale, with paddle_size.x
# coupled to the scale exactly as the runtime does (width = 155 * scale).
func _geo(scale: float, char_type := "smasher", extra := {}) -> Dictionary:
	var context: Dictionary = {
		"selected_character_type": char_type,
		"player_paddle_scale": scale,
	}
	for key in extra:
		context[key] = extra[key]
	return {
		"context": context,
		"player_pos": Vector2(300.0, 700.0),
		"paddle_size": Vector2(BASE_PADDLE_WIDTH * scale, 50.0),
		"shake": Vector2.ZERO,
	}


func _primary_anchor(renderer: Object, geo: Dictionary) -> float:
	return renderer.get_primary_bar_anchor_x(geo.context, geo.player_pos, geo.paddle_size, geo.shake)


func _dash_anchor(renderer: Object, geo: Dictionary) -> float:
	return renderer.get_bar_anchor_x(geo.context, geo.player_pos, geo.paddle_size, geo.shake)


func _paddle_center_x(geo: Dictionary) -> float:
	return geo.player_pos.x + geo.paddle_size.x * 0.5


# Core fix + regression seal: the bar's distance from the paddle CENTER must be
# proportional to the sprite scale (constant when divided by scale), so the bar
# hugs the body at any paddle size. The OLD paddle-left-edge anchor produced a
# non-constant per-scale ratio (77.5 + 8/scale -> 85.5 at 1x, 81.5 at 2x), so
# this assertion FAILS on the pre-fix formula.
func _verify_offset_tracks_scale() -> void:
	var renderer: Object = Stage1DashSideGaugeRenderer.new()
	var expected: float = float(Stage1DashSideGaugeRenderer.BAR_BODY_CENTER_OFFSET)
	for scale in [1.0, 1.5, 2.0, 3.3]:
		var geo: Dictionary = _geo(scale)
		var ratio: float = (_paddle_center_x(geo) - _primary_anchor(renderer, geo)) / scale
		_expect_approx(
			ratio,
			expected,
			"bar center-offset/scale should be constant (== %.1f) at scale %.2f, got %.3f" % [expected, scale, ratio]
		)


# Shrink tracking (clamp seal): a shrunk paddle (strange_vial 0.5x) must shrink
# the offset too. A max(1.0,...) clamp would freeze the offset at base scale and
# leave a mismatched gap on the half-size sprite, so the ratio would read 124,
# not 62, at scale 0.5.
func _verify_offset_tracks_shrink() -> void:
	var renderer: Object = Stage1DashSideGaugeRenderer.new()
	var expected: float = float(Stage1DashSideGaugeRenderer.BAR_BODY_CENTER_OFFSET)
	var geo: Dictionary = _geo(0.5)
	var ratio: float = (_paddle_center_x(geo) - _primary_anchor(renderer, geo)) / 0.5
	_expect_approx(
		ratio,
		expected,
		"shrunk paddle (scale 0.5) should keep a scale-proportional offset (== %.1f), got %.3f" % [expected, ratio]
	)


# The new anchor must be (a) closer to the body than the old left-edge anchor
# (player_pos.x - 8), and (b) still fully LEFT of the widest character body so
# it never overlaps the sprite at any scale.
func _verify_closer_than_old_and_no_body_overlap() -> void:
	var renderer: Object = Stage1DashSideGaugeRenderer.new()
	var bar_width: float = float(Stage1DashSideGaugeRenderer.BAR_WIDTH)
	for scale in [0.5, 1.0, 2.0]:
		var geo: Dictionary = _geo(scale)
		var bar_x: float = _primary_anchor(renderer, geo)
		var old_bar_x: float = geo.player_pos.x - 8.0
		_expect(
			bar_x > old_bar_x,
			"new anchor should sit closer to the body than the old left-edge anchor at scale %.2f (new %.2f vs old %.2f)" % [scale, bar_x, old_bar_x]
		)
		var body_left_edge: float = _paddle_center_x(geo) - WIDEST_BODY_HALF_GAME_PX * scale
		_expect(
			bar_x + bar_width <= body_left_edge,
			"bar right edge should stay left of the widest body at scale %.2f (bar_right %.2f vs body_left %.2f)" % [scale, bar_x + bar_width, body_left_edge]
		)


# The center must use the RAW paddle_size.x and the offset must use the CONTEXT
# player_paddle_scale, NOT a re-derived paddle_size.x/155. Junior league is the
# divergence case: hitbox width 232.5 (1.5x) but sprite visual scale 1.0. A
# re-derivation would over-shift the bar (62*1.5) away from the 1.0-scale sprite.
func _verify_center_uses_raw_paddle_width_with_context_scale() -> void:
	var renderer: Object = Stage1DashSideGaugeRenderer.new()
	var offset: float = float(Stage1DashSideGaugeRenderer.BAR_BODY_CENTER_OFFSET)
	var context: Dictionary = {
		"selected_character_type": "smasher",
		"player_paddle_scale": 1.0,  # league factor stripped from the sprite scale
	}
	var player_pos := Vector2(300.0, 700.0)
	var paddle_size := Vector2(BASE_PADDLE_WIDTH * 1.5, 50.0)  # hitbox still 1.5x in junior
	var bar_x: float = renderer.get_primary_bar_anchor_x(context, player_pos, paddle_size, Vector2.ZERO)
	var expected: float = (player_pos.x + paddle_size.x * 0.5) - offset * 1.0
	_expect_approx(
		bar_x,
		expected,
		"junior-league anchor should use raw paddle_size.x for center and context scale (1.0) for offset, got %.3f expected %.3f" % [bar_x, expected]
	)


# The dash gauge yields the inner slot to the viper jetpack hold bar: when the
# jetpack bar is visible the dash gauge slides one bar-width + gap left of the
# shared primary anchor; otherwise it sits exactly on it. The two must not
# overlap when both are visible.
func _verify_viper_pair_shift() -> void:
	var renderer: Object = Stage1DashSideGaugeRenderer.new()
	var bar_width: float = float(Stage1DashSideGaugeRenderer.BAR_WIDTH)
	var shift: float = float(Stage1DashSideGaugeRenderer.VIPER_JETPACK_PAIR_SHIFT)

	# Viper holding the jetpack at 0 tokens mid-recharge: both bars visible.
	var paired: Dictionary = _geo(1.0, "viper", {"viper_jetpack_hold_ratio": 0.5})
	var hold_bar_x: float = _primary_anchor(renderer, paired)
	var dash_bar_x: float = _dash_anchor(renderer, paired)
	_expect_approx(
		dash_bar_x,
		hold_bar_x + shift,
		"viper dash gauge should sit one pair-shift left of the hold bar when both are visible (dash %.2f vs hold %.2f shift %.1f)" % [dash_bar_x, hold_bar_x, shift]
	)
	_expect(
		abs(hold_bar_x - dash_bar_x) >= bar_width,
		"the viper dash gauge and hold bar must not overlap when both are visible (gap %.2f < bar width %.1f)" % [abs(hold_bar_x - dash_bar_x), bar_width]
	)

	# Viper with no jetpack hold: the dash gauge takes the primary slot itself.
	var solo: Dictionary = _geo(1.0, "viper")
	_expect_approx(
		_dash_anchor(renderer, solo),
		_primary_anchor(renderer, solo),
		"viper dash gauge with no jetpack hold should sit on the primary anchor (no pair shift)"
	)

	# Non-viper characters never get the pair shift.
	var smasher: Dictionary = _geo(1.0, "smasher", {"viper_jetpack_hold_ratio": 0.5})
	_expect_approx(
		_dash_anchor(renderer, smasher),
		_primary_anchor(renderer, smasher),
		"non-viper dash gauge should never apply the viper jetpack pair shift"
	)


func _verify_shake_is_applied() -> void:
	var renderer: Object = Stage1DashSideGaugeRenderer.new()
	var context: Dictionary = {"selected_character_type": "smasher", "player_paddle_scale": 1.0}
	var player_pos := Vector2(300.0, 700.0)
	var paddle_size := Vector2(155.0, 50.0)
	var no_shake: float = renderer.get_primary_bar_anchor_x(context, player_pos, paddle_size, Vector2.ZERO)
	var shaken: float = renderer.get_primary_bar_anchor_x(context, player_pos, paddle_size, Vector2(12.0, 0.0))
	_expect_approx(
		shaken,
		no_shake + 12.0,
		"shake offset x should be added to the bar anchor (shaken %.2f vs base %.2f)" % [shaken, no_shake]
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_approx(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append(message)
