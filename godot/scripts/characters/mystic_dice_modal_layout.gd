extends RefCounted

const MysticDiceModalFlow := preload("res://scripts/characters/mystic_dice_modal_flow.gd")

const BUTTON_SIZE := Vector2(176.0, 48.0)
const BUTTON_GAP := 18.0
const HORIZONTAL_MARGIN := 14.0


func get_action_rects(snapshot: Dictionary, view_size: Vector2) -> Dictionary:
	if str(snapshot.get("phase", "")) != MysticDiceModalFlow.PHASE_RESULT:
		return {}
	var safe_view := Vector2(maxf(1.0, view_size.x), maxf(1.0, view_size.y))
	var button_height: float = clampf(safe_view.y * 0.075, 38.0, BUTTON_SIZE.y)
	var two_button_width: float = minf(
		BUTTON_SIZE.x,
		maxf(96.0, (safe_view.x - HORIZONTAL_MARGIN * 2.0 - BUTTON_GAP) * 0.5)
	)
	var button_size := Vector2(two_button_width, button_height)
	var button_y: float = minf(safe_view.y * 0.76, safe_view.y - button_height - 46.0)
	button_y = maxf(8.0, button_y)
	if int(snapshot.get("rerolls_remaining", 0)) <= 0:
		return {
			"confirm": Rect2(Vector2((safe_view.x - button_size.x) * 0.5, button_y), button_size),
		}
	var total_width := button_size.x * 2.0 + BUTTON_GAP
	var start_x := (safe_view.x - total_width) * 0.5
	return {
		"reroll": Rect2(Vector2(start_x, button_y), button_size),
		"confirm": Rect2(Vector2(start_x + button_size.x + BUTTON_GAP, button_y), button_size),
	}


func get_action_index_at(snapshot: Dictionary, position: Vector2, view_size: Vector2) -> int:
	match get_action_at(snapshot, position, view_size):
		"reroll":
			return MysticDiceModalFlow.ACTION_REROLL
		"confirm":
			return MysticDiceModalFlow.ACTION_CONFIRM
	return -1


func get_action_at(snapshot: Dictionary, position: Vector2, view_size: Vector2) -> String:
	var rects := get_action_rects(snapshot, view_size)
	for action_name: String in ["reroll", "confirm"]:
		var rect_value: Variant = rects.get(action_name)
		if rect_value is Rect2 and (rect_value as Rect2).has_point(position):
			return action_name
	return ""
