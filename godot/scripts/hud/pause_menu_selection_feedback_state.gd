extends RefCounted

const SLIDE_DURATION := 0.09
const POP_DURATION := 0.12
const POP_SCALE := 0.045

var scope := "main"
var from_index := 0
var to_index := 0
var slide_time := SLIDE_DURATION
var pop_time := POP_DURATION
var last_hover_scope := ""
var last_hover_index := -1


func begin(next_scope: String, previous_index: int, next_index: int) -> void:
	scope = next_scope
	from_index = previous_index
	to_index = next_index
	slide_time = 0.0
	pop_time = 0.0


func reset(next_scope: String, index: int) -> void:
	scope = next_scope
	from_index = index
	to_index = index
	slide_time = SLIDE_DURATION
	pop_time = POP_DURATION


func advance(delta: float) -> void:
	slide_time = minf(SLIDE_DURATION, slide_time + delta)
	pop_time = minf(POP_DURATION, pop_time + delta)


func reset_hover_tracking() -> void:
	last_hover_scope = ""
	last_hover_index = -1


func consume_hover_change(next_scope: String, next_hover_index: int) -> bool:
	if next_scope == last_hover_scope and next_hover_index == last_hover_index:
		return false
	last_hover_scope = next_scope
	last_hover_index = next_hover_index
	return true


func get_snapshot() -> Dictionary:
	return {
		"scope": scope,
		"from_index": from_index,
		"to_index": to_index,
		"slide_time": slide_time,
		"pop_time": pop_time,
		"last_hover_scope": last_hover_scope,
		"last_hover_index": last_hover_index,
	}


func build_slide_projection(requested_scope: String) -> Dictionary:
	if scope != requested_scope or slide_time >= SLIDE_DURATION:
		return {"active": false}
	var progress := clampf(slide_time / SLIDE_DURATION, 0.0, 1.0)
	return {
		"active": true,
		"from_index": from_index,
		"to_index": to_index,
		"weight": _ease_out_back(progress),
	}


func build_pop_projection(requested_scope: String, flash_peak: float) -> Dictionary:
	if scope != requested_scope or pop_time >= POP_DURATION:
		return {
			"pop_amount": 0.0,
			"flash_alpha": 0.0,
		}
	var progress := clampf(pop_time / POP_DURATION, 0.0, 1.0)
	return {
		"pop_amount": sin(progress * PI) * POP_SCALE,
		"flash_alpha": flash_peak * (1.0 - progress),
	}


static func _ease_out_back(value: float) -> float:
	var clamped_value := clampf(value, 0.0, 1.0)
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(clamped_value - 1.0, 3.0) + c1 * pow(clamped_value - 1.0, 2.0)
