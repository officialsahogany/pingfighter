extends RefCounted

const NEUTRAL_EXPRESSION := "neutral"
const ALLOWED_EXPRESSIONS := ["neutral", "happy", "sad"]

var current_expression := NEUTRAL_EXPRESSION
var timer := 0.0


func reset() -> void:
	current_expression = NEUTRAL_EXPRESSION
	timer = 0.0


func set_expression(expression_id: String, duration_sec: float) -> void:
	if expression_id not in ALLOWED_EXPRESSIONS:
		expression_id = NEUTRAL_EXPRESSION
	current_expression = expression_id
	timer = max(0.0, duration_sec) if expression_id != NEUTRAL_EXPRESSION else 0.0


func update(delta: float) -> void:
	if timer <= 0.0:
		return
	timer = max(0.0, timer - delta)
	if timer <= 0.0:
		current_expression = NEUTRAL_EXPRESSION


func get_snapshot() -> Dictionary:
	return {
		"expression": current_expression,
		"timer": timer,
		"active": current_expression != NEUTRAL_EXPRESSION,
	}
