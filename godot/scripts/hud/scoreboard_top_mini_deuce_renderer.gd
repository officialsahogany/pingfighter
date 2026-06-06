extends RefCounted

const ScoreboardTopMiniDeuceEffectRenderer := preload("res://scripts/hud/scoreboard_top_mini_deuce_effect_renderer.gd")
const ScoreboardTopMiniTextRenderer := preload("res://scripts/hud/scoreboard_top_mini_text_renderer.gd")

const DEUCE_DEFAULT_DIGIT_COLOR := Color(1.0, 1.0, 230.0 / 255.0)
const DEUCE_DEFAULT_GLOW_COLOR := Color(1.0, 100.0 / 255.0, 0.0)
const OPPORTUNITY_SCORE_COLOR := Color(1.0, 230.0 / 255.0, 92.0 / 255.0)
const OPPORTUNITY_GLOW_COLOR := Color(1.0, 180.0 / 255.0, 28.0 / 255.0)
# Danger digit must stay LEGIBLE on the red/orange deuce ember background --
# a dark saturated red digit reads as red-on-red and disappears. Keep the digit
# fill bright (luminance matched to the gold opportunity digit) and carry the
# "danger" urgency through the deep-red glow below, not the digit fill.
const DANGER_SCORE_COLOR := Color(1.0, 150.0 / 255.0, 130.0 / 255.0)
const DANGER_GLOW_COLOR := Color(1.0, 32.0 / 255.0, 24.0 / 255.0)

var effect_renderer: Object = ScoreboardTopMiniDeuceEffectRenderer.new()
var text_renderer: Object = ScoreboardTopMiniTextRenderer.new()


func draw(
	canvas: Node2D,
	rect: Rect2,
	scale_factor: float,
	t: float,
	sparkle_intensity: float,
	player_score: int,
	boss_score: int,
	quality_scale: float = 1.0,
	stakes: Dictionary = {}
) -> void:
	var lod_active: bool = quality_scale < 0.85
	var pulse: float = effect_renderer.draw(canvas, rect, scale_factor, t, quality_scale, stakes)

	var deuce_label_y: float = max(10.0 * scale_factor, rect.position.y - 12.0 * scale_factor)
	text_renderer.draw_score_text(
		canvas,
		Vector2(rect.get_center().x, deuce_label_y),
		"DEUCE!",
		max(10, int(11.0 * scale_factor)),
		Color(1.0, 1.0, 230.0 / 255.0),
		Color(100.0 / 255.0, 30.0 / 255.0, 5.0 / 255.0, 0.95),
		Color(1.0, 100.0 / 255.0, 0.0),
		pulse if not lod_active else 0.0
	)

	var center_pos := rect.get_center() + Vector2(sin(t * 20.0), cos(t * 25.0) * 0.5) * scale_factor * _get_stakes_jitter_multiplier(stakes, quality_scale)
	var score_center_pos := center_pos + Vector2(0.0, max(2.0, 3.0 * scale_factor))
	var layout: Dictionary = _get_score_layout(rect, scale_factor, score_center_pos)
	var digit_height: float = _get_digit_height(
		layout.get("player_rect", Rect2()),
		layout.get("boss_rect", Rect2()),
		player_score,
		boss_score
	)
	var glow_strength: float = max(0.7, pulse + sparkle_intensity * 0.4 + _get_stakes_glow_bonus(stakes))
	text_renderer.draw_segment_number(
		canvas,
		layout.get("player_rect", Rect2()).get_center(),
		player_score,
		digit_height,
		_get_player_score_color(stakes),
		_get_player_glow_color(stakes),
		glow_strength,
		1.0
	)
	text_renderer.draw_segment_colon(
		canvas,
		layout.get("colon_center", center_pos),
		digit_height,
		Color(1.0, 220.0 / 255.0, 150.0 / 255.0),
		_get_colon_glow_color(stakes),
		glow_strength,
		1.0
	)
	text_renderer.draw_segment_number(
		canvas,
		layout.get("boss_rect", Rect2()).get_center(),
		boss_score,
		digit_height,
		_get_boss_score_color(stakes),
		_get_boss_glow_color(stakes),
		glow_strength,
		1.0
	)


func _get_score_layout(rect: Rect2, scale_factor: float, center_pos: Vector2) -> Dictionary:
	var side_pad: float = max(8.0, 9.0 * scale_factor)
	var top_pad: float = max(5.0, 5.0 * scale_factor)
	var center_gap: float = max(28.0, 28.0 * scale_factor)
	var score_width: float = (rect.size.x - side_pad * 2.0 - center_gap) * 0.5
	var score_height: float = rect.size.y - top_pad * 2.0
	var player_rect := Rect2(rect.position.x + side_pad, rect.position.y + top_pad, score_width, score_height)
	var boss_rect := Rect2(rect.end.x - side_pad - score_width, rect.position.y + top_pad, score_width, score_height)
	return {
		"player_rect": Rect2(player_rect.position + center_pos - rect.get_center(), player_rect.size),
		"boss_rect": Rect2(boss_rect.position + center_pos - rect.get_center(), boss_rect.size),
		"colon_center": center_pos,
	}


func _get_digit_height(player_rect: Rect2, boss_rect: Rect2, player_score: int, boss_score: int) -> float:
	var digit_height: float = min(player_rect.size.y * 0.78, boss_rect.size.y * 0.78)
	var min_digit_height: float = max(18.0, min(player_rect.size.y, boss_rect.size.y) * 0.54)
	while digit_height > min_digit_height:
		var player_size: Vector2 = text_renderer.get_segment_number_size(player_score, digit_height)
		var boss_size: Vector2 = text_renderer.get_segment_number_size(boss_score, digit_height)
		if player_size.x <= player_rect.size.x * 0.88 and boss_size.x <= boss_rect.size.x * 0.88:
			break
		digit_height -= 1.0
	return digit_height


func _get_player_score_color(stakes: Dictionary) -> Color:
	return OPPORTUNITY_SCORE_COLOR if _get_player_stakes_strength(stakes) > 0.0 else DEUCE_DEFAULT_DIGIT_COLOR


func _get_player_glow_color(stakes: Dictionary) -> Color:
	return OPPORTUNITY_GLOW_COLOR if _get_player_stakes_strength(stakes) > 0.0 else DEUCE_DEFAULT_GLOW_COLOR


func _get_boss_score_color(stakes: Dictionary) -> Color:
	return DANGER_SCORE_COLOR if _get_boss_stakes_strength(stakes) > 0.0 else DEUCE_DEFAULT_DIGIT_COLOR


func _get_boss_glow_color(stakes: Dictionary) -> Color:
	return DANGER_GLOW_COLOR if _get_boss_stakes_strength(stakes) > 0.0 else DEUCE_DEFAULT_GLOW_COLOR


func _get_colon_glow_color(stakes: Dictionary) -> Color:
	if _get_player_stakes_strength(stakes) > 0.0:
		return OPPORTUNITY_GLOW_COLOR
	if _get_boss_stakes_strength(stakes) > 0.0:
		return DANGER_GLOW_COLOR
	return Color(1.0, 160.0 / 255.0, 30.0 / 255.0)


func _get_stakes_glow_bonus(stakes: Dictionary) -> float:
	var player_strength: float = _get_player_stakes_strength(stakes)
	var boss_strength: float = _get_boss_stakes_strength(stakes)
	return player_strength * 0.22 + boss_strength * 0.12 + player_strength * boss_strength * 0.12


func _get_stakes_jitter_multiplier(stakes: Dictionary, quality_scale: float = 1.0) -> float:
	return 1.0 + _get_stakes_peak_strength(stakes) * 0.18 * clampf(quality_scale, 0.0, 1.0)


func _get_player_stakes_strength(stakes: Dictionary) -> float:
	return 1.0 if bool(stakes.get("player_can_win", false)) else 0.0


func _get_boss_stakes_strength(stakes: Dictionary) -> float:
	return 1.0 if bool(stakes.get("boss_can_win", false)) else 0.0


func _get_stakes_peak_strength(stakes: Dictionary) -> float:
	var player_strength: float = _get_player_stakes_strength(stakes)
	var boss_strength: float = _get_boss_stakes_strength(stakes)
	if player_strength > 0.0 and boss_strength > 0.0:
		return 1.0
	return max(player_strength * 0.72, boss_strength * 0.42)
