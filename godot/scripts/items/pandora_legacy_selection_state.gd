extends RefCounted

const CARD_COUNT := 3

var pending_choices: Array = []
var active := false
var items: Array = []
var selected_index := 0
var timer_frames := 0.0
var last_trigger_roll_pct := -1.0
var last_triggered := false


func clear_runtime() -> void:
	clear_selection(true)
	reset_trigger_result()


func reset_trigger_result() -> void:
	last_trigger_roll_pct = -1.0
	last_triggered = false


func set_trigger_roll(roll_pct: float) -> void:
	last_trigger_roll_pct = roll_pct


func queue_choices(choices: Array) -> void:
	pending_choices = _duplicate_choices(choices)
	last_triggered = true


func has_pending() -> bool:
	return not pending_choices.is_empty()


func start_pending() -> bool:
	if pending_choices.size() < CARD_COUNT:
		return false
	return start(pending_choices)


func start(choices: Array) -> bool:
	if choices.size() < CARD_COUNT:
		return false
	items.clear()
	for i in range(CARD_COUNT):
		var choice: Dictionary = _get_dict(choices[i])
		if not choice.is_empty():
			items.append(choice.duplicate(true))
	if items.size() < CARD_COUNT:
		clear_selection(true)
		return false
	pending_choices.clear()
	active = true
	selected_index = 0
	timer_frames = 0.0
	return true


func is_active() -> bool:
	return active


func get_selected_item(index: int) -> Dictionary:
	if not active or items.is_empty():
		return {}
	var clamped_index: int = int(clamp(index, 0, items.size() - 1))
	return _get_dict(items[clamped_index]).duplicate(true)


func clear_selection(clear_pending: bool = true) -> void:
	active = false
	items.clear()
	selected_index = 0
	timer_frames = 0.0
	if clear_pending:
		pending_choices.clear()


func advance_timer(fps_scale: float) -> void:
	timer_frames += max(0.0, fps_scale)


func set_selected_index(index: int) -> void:
	selected_index = int(clamp(index, 0, CARD_COUNT - 1))


func move_selected(delta: int) -> void:
	selected_index = posmod(selected_index + delta, CARD_COUNT)


func get_items() -> Array:
	return _duplicate_choices(items)


func get_snapshot() -> Dictionary:
	return {
		"pending": has_pending(),
		"selection_active": active,
		"selection_items": get_items(),
		"selected_index": selected_index,
		"selection_timer_frames": timer_frames,
		"last_trigger_roll_pct": last_trigger_roll_pct,
		"last_triggered": last_triggered,
	}


func _duplicate_choices(source: Array) -> Array:
	var result: Array = []
	for value in source:
		var item: Dictionary = _get_dict(value)
		if not item.is_empty():
			result.append(item.duplicate(true))
	return result


func _get_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
