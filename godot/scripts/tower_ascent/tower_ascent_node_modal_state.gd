extends RefCounted

const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)

const ACTION_END_WORK := "end_work"
const BASE_VIEW_SIZE := Vector2(760.0, 750.0)
const MODAL_RECT := Rect2(24.0, 28.0, 712.0, 694.0)
const ACTION_LIST_RECT := Rect2(126.0, 301.0, 508.0, 302.0)
const ACTION_ROW_HEIGHT := 38.0
const ACTION_ROW_GAP := 5.0
const SIX_CARD_NODE_KINDS := ["shop", "training", "fallen_monk"]
const CARD_GRID_RECT := Rect2(43.0, 150.0, 674.0, 438.0)
const CARD_GRID_COLUMNS := 3
const CARD_GRID_ROWS := 2
const GRID_COLUMN_GAP := 12.0
const GRID_ROW_GAP := 14.0
const END_WORK_RECT := Rect2(246.0, 602.0, 268.0, 40.0)

var _node_id := ""
var _node_kind := "common_shell"
var _actions: Array[Dictionary] = []
var _keyboard_selected_index := 0
var _hovered_index := -1
var _pressed_index := -1
var _balances := {"gold": 0, "muhon": 0, "chance_gems": 0}
var _status_text := ""


func open(
	node_id: String,
	node_kind: String,
	balances: Dictionary,
	actions: Array = []
) -> void:
	_node_id = node_id.strip_edges()
	_node_kind = node_kind.strip_edges().to_lower()
	if not TowerAscentNodeModalLocalization.NODE_TITLE_KEYS.has(_node_kind):
		_node_kind = "common_shell"
	_balances = _normalize_balances(balances)
	_replace_actions(actions)
	_keyboard_selected_index = 0
	_hovered_index = -1
	_pressed_index = -1
	_status_text = TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_STATUS_READY
	)


func close() -> void:
	_node_id = ""
	_actions.clear()
	_keyboard_selected_index = 0
	_hovered_index = -1
	_pressed_index = -1
	_status_text = ""


func set_actions(actions: Array) -> void:
	var previous_keyboard_index := _keyboard_selected_index
	var keyboard_action_id := _action_id_at_index(_keyboard_selected_index)
	var hovered_action_id := _action_id_at_index(_hovered_index)
	_replace_actions(actions)
	var restored_keyboard_index := _find_action_index_by_id(keyboard_action_id)
	if restored_keyboard_index >= 0:
		_keyboard_selected_index = restored_keyboard_index
	else:
		_keyboard_selected_index = clampi(previous_keyboard_index, 0, _actions.size() - 1)
	_hovered_index = _find_action_index_by_id(hovered_action_id)
	_pressed_index = -1


func set_balances(balances: Dictionary) -> void:
	_balances = _normalize_balances(balances)


func set_status_text(value: String) -> void:
	_status_text = value.strip_edges()


func move_selection(direction: int) -> void:
	if _actions.is_empty() or direction == 0:
		return
	_keyboard_selected_index = posmod(
		_keyboard_selected_index + signi(direction),
		_actions.size()
	)


func select_index(index: int) -> bool:
	if index < 0 or index >= _actions.size():
		return false
	_keyboard_selected_index = index
	return true


func select_at_position(
	position: Vector2,
	view_size: Vector2 = BASE_VIEW_SIZE
) -> bool:
	return select_index(_action_index_at_position(position, view_size))


func update_hover_at_position(
	position: Vector2,
	view_size: Vector2 = BASE_VIEW_SIZE
) -> bool:
	var next_hovered_index := _action_index_at_position(position, view_size)
	if next_hovered_index == _hovered_index:
		return false
	_hovered_index = next_hovered_index
	return true


func begin_pointer_press(
	position: Vector2,
	view_size: Vector2 = BASE_VIEW_SIZE
) -> bool:
	_pressed_index = _action_index_at_position(position, view_size)
	return _pressed_index >= 0


func release_pointer_at_position(
	position: Vector2,
	view_size: Vector2 = BASE_VIEW_SIZE
) -> Dictionary:
	var armed_index := _pressed_index
	_pressed_index = -1
	if armed_index < 0 or armed_index != _action_index_at_position(position, view_size):
		return {}
	return _action_at_index(armed_index)


func cancel_pointer_press() -> void:
	_pressed_index = -1


func get_keyboard_selected_index() -> int:
	return _keyboard_selected_index


func get_hovered_index() -> int:
	return _hovered_index


func get_pressed_index() -> int:
	return _pressed_index


func get_action_rects(view_size: Vector2 = BASE_VIEW_SIZE) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var layout := build_screen_layout(view_size)
	var content_scale := float(layout.get("content_scale", 1.0))
	var content_offset: Vector2 = layout.get("content_offset", Vector2.ZERO)
	if _node_kind in SIX_CARD_NODE_KINDS:
		var column_width := (
			CARD_GRID_RECT.size.x - GRID_COLUMN_GAP * float(CARD_GRID_COLUMNS - 1)
		) / float(CARD_GRID_COLUMNS)
		var row_height := (
			CARD_GRID_RECT.size.y - GRID_ROW_GAP * float(CARD_GRID_ROWS - 1)
		) / float(CARD_GRID_ROWS)
		var card_index := 0
		for index in range(_actions.size()):
			if str(_actions[index].get("id", "")) == ACTION_END_WORK:
				result.append(_scale_rect(END_WORK_RECT, content_scale, content_offset))
				continue
			var column := card_index % CARD_GRID_COLUMNS
			var row := card_index / CARD_GRID_COLUMNS
			result.append(_scale_rect(Rect2(
				CARD_GRID_RECT.position + Vector2(
					float(column) * (column_width + GRID_COLUMN_GAP),
					float(row) * (row_height + GRID_ROW_GAP)
				),
				Vector2(column_width, row_height)
			), content_scale, content_offset))
			card_index += 1
		return result
	for index in range(_actions.size()):
		result.append(_scale_rect(Rect2(
			ACTION_LIST_RECT.position + Vector2(0.0, float(index) * (ACTION_ROW_HEIGHT + ACTION_ROW_GAP)),
			Vector2(ACTION_LIST_RECT.size.x, ACTION_ROW_HEIGHT)
		), content_scale, content_offset))
	return result


func get_selected_action() -> Dictionary:
	return _action_at_index(_keyboard_selected_index)


func build_view_model(view_size: Vector2 = BASE_VIEW_SIZE) -> Dictionary:
	var layout := build_screen_layout(view_size)
	return {
		"node_id": _node_id,
		"node_kind": _node_kind,
		"title": TowerAscentNodeModalLocalization.node_title(_node_kind),
		"description": TowerAscentNodeModalLocalization.node_description(_node_kind),
		"balances": _balances.duplicate(true),
		"muhon_text": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_BALANCE_MUHON,
			{"amount": int(_balances.get("muhon", 0))}
		),
		"gold_text": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_BALANCE_GOLD,
			{"amount": int(_balances.get("gold", 0))}
		),
		"actions": _actions.duplicate(true),
		"action_rects": get_action_rects(view_size),
		"selected_index": _keyboard_selected_index,
		"keyboard_selected_index": _keyboard_selected_index,
		"hovered_index": _hovered_index,
		"pressed_index": _pressed_index,
		"status_text": _status_text,
		"view_size": view_size,
		"modal_rect": layout.get("modal_rect", MODAL_RECT),
		"content_scale": layout.get("content_scale", 1.0),
		"content_offset": layout.get("content_offset", Vector2.ZERO),
	}


func build_screen_layout(view_size: Vector2) -> Dictionary:
	var safe_view_size := Vector2(
		maxf(1.0, view_size.x),
		maxf(1.0, view_size.y)
	)
	var content_scale := minf(
		safe_view_size.x / BASE_VIEW_SIZE.x,
		safe_view_size.y / BASE_VIEW_SIZE.y
	)
	var content_offset := (safe_view_size - BASE_VIEW_SIZE * content_scale) * 0.5
	return {
		"content_scale": content_scale,
		"content_offset": content_offset,
		"modal_rect": _scale_rect(MODAL_RECT, content_scale, content_offset),
	}


func _scale_rect(rect: Rect2, scale_value: float, offset: Vector2) -> Rect2:
	return Rect2(offset + rect.position * scale_value, rect.size * scale_value)


func _action_index_at_position(position: Vector2, view_size: Vector2) -> int:
	var rects := get_action_rects(view_size)
	# Reverse iteration makes a future overlap deterministic and agrees with the
	# visual topmost-card rule instead of accepting row-gap clicks.
	for index in range(rects.size() - 1, -1, -1):
		if (rects[index] as Rect2).has_point(position):
			return index
	return -1


func _action_at_index(index: int) -> Dictionary:
	if index < 0 or index >= _actions.size():
		return {}
	return _actions[index].duplicate(true)


func _action_id_at_index(index: int) -> String:
	if index < 0 or index >= _actions.size():
		return ""
	return str(_actions[index].get("id", ""))


func _find_action_index_by_id(action_id: String) -> int:
	if action_id.is_empty():
		return -1
	for index in range(_actions.size()):
		if str(_actions[index].get("id", "")) == action_id:
			return index
	return -1


func _replace_actions(actions: Array) -> void:
	_actions.clear()
	for action_value in actions:
		if action_value is Dictionary:
			_actions.append(_normalize_action(action_value as Dictionary))
	_actions.append(_normalize_action({
		"id": ACTION_END_WORK,
		"label": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_END_WORK
		),
		"enabled": true,
	}))


func _normalize_action(source: Dictionary) -> Dictionary:
	var enabled := bool(source.get("enabled", true))
	return {
		"id": str(source.get("id", "")).strip_edges(),
		"label": str(source.get("label", "")).strip_edges(),
		"cost_text": str(source.get("cost_text", "")).strip_edges(),
		"enabled": enabled,
		"disabled_reason": str(source.get("disabled_reason", "")).strip_edges(),
		"unavailable_reason": str(source.get(
			"unavailable_reason",
			"" if enabled else TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_STATUS_DISABLED
			)
		)).strip_edges(),
		"payload": (
			(source.get("payload", {}) as Dictionary).duplicate(true)
			if source.get("payload", {}) is Dictionary
			else {}
		),
	}


func _normalize_balances(source: Dictionary) -> Dictionary:
	return {
		"gold": maxi(0, int(source.get("gold", 0))),
		"muhon": maxi(0, int(source.get("muhon", 0))),
		"chance_gems": maxi(0, int(source.get("chance_gems", 0))),
	}
