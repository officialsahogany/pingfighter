extends RefCounted

const DRAG_THRESHOLD := 6.0

var panel := ""
var index := -1
var start_position := Vector2.ZERO
var position := Vector2.ZERO
var item: Dictionary = {}


func is_active() -> bool:
	return panel != ""


func start(next_panel: String, next_index: int, local_position: Vector2, item_data: Dictionary) -> void:
	panel = next_panel
	index = next_index
	start_position = local_position
	position = local_position
	item = item_data.duplicate(true)


func update_position(local_position: Vector2) -> void:
	position = local_position


func get_distance_to(local_position: Vector2) -> float:
	return local_position.distance_to(start_position)


func is_click_release(local_position: Vector2) -> bool:
	return get_distance_to(local_position) <= DRAG_THRESHOLD


func reset() -> void:
	panel = ""
	index = -1
	start_position = Vector2.ZERO
	position = Vector2.ZERO
	item.clear()
