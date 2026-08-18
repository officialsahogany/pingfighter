extends RefCounted

const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)

const ACTION_END_WORK := "end_work"
const ACTION_LIST_RECT := Rect2(126.0, 301.0, 508.0, 302.0)
const ACTION_ROW_HEIGHT := 38.0
const ACTION_ROW_GAP := 5.0
const SIX_CARD_NODE_KINDS := ["training", "fallen_monk"]
const GRID_COLUMN_GAP := 8.0
const GRID_ROW_GAP := 8.0
const GRID_ROW_HEIGHT := 68.0

var _node_id := ""
var _node_kind := "common_shell"
var _actions: Array[Dictionary] = []
var _selected_index := 0
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
	_selected_index = 0
	_status_text = TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_STATUS_READY
	)


func close() -> void:
	_node_id = ""
	_actions.clear()
	_selected_index = 0
	_status_text = ""


func set_actions(actions: Array) -> void:
	open(_node_id, _node_kind, _balances, actions)


func set_balances(balances: Dictionary) -> void:
	_balances = _normalize_balances(balances)


func set_status_text(value: String) -> void:
	_status_text = value.strip_edges()


func move_selection(direction: int) -> void:
	if _actions.is_empty() or direction == 0:
		return
	_selected_index = posmod(_selected_index + signi(direction), _actions.size())


func select_index(index: int) -> bool:
	if index < 0 or index >= _actions.size():
		return false
	_selected_index = index
	return true


func select_at_position(position: Vector2) -> bool:
	var rects := get_action_rects()
	# Reverse iteration makes a future overlap deterministic and agrees with the
	# visual topmost-card rule instead of accepting row-gap clicks.
	for index in range(rects.size() - 1, -1, -1):
		if (rects[index] as Rect2).has_point(position):
			return select_index(index)
	return false


func get_action_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	if _node_kind in SIX_CARD_NODE_KINDS:
		var column_width := (ACTION_LIST_RECT.size.x - GRID_COLUMN_GAP) * 0.5
		for index in range(_actions.size()):
			var column := index % 2
			var row := index / 2
			result.append(Rect2(
				ACTION_LIST_RECT.position + Vector2(
					float(column) * (column_width + GRID_COLUMN_GAP),
					float(row) * (GRID_ROW_HEIGHT + GRID_ROW_GAP)
				),
				Vector2(column_width, GRID_ROW_HEIGHT)
			))
		return result
	for index in range(_actions.size()):
		result.append(Rect2(
			ACTION_LIST_RECT.position + Vector2(0.0, float(index) * (ACTION_ROW_HEIGHT + ACTION_ROW_GAP)),
			Vector2(ACTION_LIST_RECT.size.x, ACTION_ROW_HEIGHT)
		))
	return result


func get_selected_action() -> Dictionary:
	if _selected_index < 0 or _selected_index >= _actions.size():
		return {}
	return _actions[_selected_index].duplicate(true)


func build_view_model() -> Dictionary:
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
		"action_rects": get_action_rects(),
		"selected_index": _selected_index,
		"status_text": _status_text,
	}


func _normalize_action(source: Dictionary) -> Dictionary:
	var enabled := bool(source.get("enabled", true))
	return {
		"id": str(source.get("id", "")).strip_edges(),
		"label": str(source.get("label", "")).strip_edges(),
		"cost_text": str(source.get("cost_text", "")).strip_edges(),
		"enabled": enabled,
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
