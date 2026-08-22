extends RefCounted

const RELEASE_NONE := 0
const RELEASE_CLICK := 1
const RELEASE_DRAG := 2
# Eight logical screen pixels absorb normal mouse hand jitter without making a
# deliberate short pull feel unresponsive. Screen space keeps the slop stable
# across both the minimum-cover overview and the walking closeup zoom.
const DRAG_THRESHOLD_SCREEN_PX := 8.0
const DRAG_THRESHOLD_SCREEN_PX_SQUARED := (
	DRAG_THRESHOLD_SCREEN_PX * DRAG_THRESHOLD_SCREEN_PX
)

var _press_active := false
var _dragging := false
var _press_screen_position := Vector2.ZERO
var _press_camera_offset := Vector2.ZERO
var _manual_camera_offset := Vector2.ZERO
var _manual_override_active := false
var _selected_node_id := ""


func reset_surface() -> void:
	_press_active = false
	_dragging = false
	_press_screen_position = Vector2.ZERO
	_press_camera_offset = Vector2.ZERO
	_manual_camera_offset = Vector2.ZERO
	_manual_override_active = false
	_selected_node_id = ""


func cancel_press() -> void:
	_press_active = false
	_dragging = false


func begin_press(screen_position: Vector2, camera_offset: Vector2) -> void:
	_press_active = true
	_dragging = false
	_press_screen_position = screen_position
	_press_camera_offset = camera_offset


func update_pointer(screen_position: Vector2) -> bool:
	if not _press_active:
		return false
	var displacement := screen_position - _press_screen_position
	if (
		not _dragging
		and displacement.length_squared() > DRAG_THRESHOLD_SCREEN_PX_SQUARED
	):
		_dragging = true
	if not _dragging:
		return false
	_manual_camera_offset = _press_camera_offset + displacement
	# Manual ownership deliberately survives button-up. Snapping back to the
	# moving walker on release would fight the user's completed camera choice;
	# the owning surface reset restores automatic tracking on the next surface.
	_manual_override_active = true
	return true


func release(screen_position: Vector2) -> int:
	if not _press_active:
		return RELEASE_NONE
	update_pointer(screen_position)
	var release_kind := RELEASE_DRAG if _dragging else RELEASE_CLICK
	_press_active = false
	_dragging = false
	return release_kind


func get_threshold_screen_px() -> float:
	return DRAG_THRESHOLD_SCREEN_PX


func is_press_active() -> bool:
	return _press_active


func is_dragging() -> bool:
	return _dragging


func has_manual_camera_override() -> bool:
	return _manual_override_active


func get_manual_camera_offset() -> Vector2:
	return _manual_camera_offset


func select_node(node_id: String) -> void:
	_selected_node_id = node_id


func get_selected_node_id() -> String:
	return _selected_node_id
