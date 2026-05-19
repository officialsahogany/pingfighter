extends RefCounted

const BASE_PILLAR_WIDTH := 80.0
const CARD_WIDTH_BASE := 33.6
const CARD_HEIGHT_BASE := 9.0
const CARD_GAP_BASE := 2.0
const CARD_RIGHT_MARGIN_BASE := 3.0
const CARD_MIN_SIZE := Vector2(24.0, 10.0)
const LEFT_PILLAR_Y_MARGIN_BASE := 5.0


static func get_scale_factor(pillar_width: float) -> float:
	return maxf(0.0, pillar_width) / BASE_PILLAR_WIDTH


static func get_card_size(scale_factor: float) -> Vector2:
	return Vector2(
		maxf(CARD_MIN_SIZE.x, round(CARD_WIDTH_BASE * scale_factor)),
		maxf(CARD_MIN_SIZE.y, round(CARD_HEIGHT_BASE * scale_factor))
	)


static func get_card_gap(scale_factor: float) -> float:
	return maxf(1.0, round(CARD_GAP_BASE * scale_factor))


static func get_right_margin(scale_factor: float) -> float:
	return maxf(1.0, round(CARD_RIGHT_MARGIN_BASE * scale_factor))


static func get_left_pillar_y_margin(scale_factor: float) -> float:
	return maxf(2.0, round(LEFT_PILLAR_Y_MARGIN_BASE * scale_factor))


static func get_card_metrics(pillar_width: float) -> Dictionary:
	var scale_factor: float = get_scale_factor(pillar_width)
	return {
		"scale_factor": scale_factor,
		"card_size": get_card_size(scale_factor),
		"card_gap": get_card_gap(scale_factor),
		"margin_x": get_right_margin(scale_factor),
		"margin_y": get_left_pillar_y_margin(scale_factor),
	}
