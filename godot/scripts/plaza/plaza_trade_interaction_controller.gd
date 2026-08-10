extends RefCounted

const PlazaInteriorLayout := preload("res://scripts/plaza/plaza_interior_layout.gd")
const PlazaTradeActionDispatcher := preload("res://scripts/plaza/plaza_trade_action_dispatcher.gd")
const PlazaTradeDragState := preload("res://scripts/plaza/plaza_trade_drag_state.gd")
const PlazaTradeDropDecision := preload("res://scripts/plaza/plaza_trade_drop_decision.gd")
const PlazaTradeHoverState := preload("res://scripts/plaza/plaza_trade_hover_state.gd")
const PlazaTradeItemPresentation := preload("res://scripts/plaza/plaza_trade_item_presentation.gd")
const PlazaTradeScrollState := preload("res://scripts/plaza/plaza_trade_scroll_state.gd")
const PlazaTradeSellConfirmState := preload("res://scripts/plaza/plaza_trade_sell_confirm_state.gd")

var _hover_state: PlazaTradeHoverState = PlazaTradeHoverState.new()
var _scroll_state: PlazaTradeScrollState = PlazaTradeScrollState.new()
var _drag_state: PlazaTradeDragState = PlazaTradeDragState.new()
var _sell_confirm_state: PlazaTradeSellConfirmState = PlazaTradeSellConfirmState.new()
var _action_dispatcher: PlazaTradeActionDispatcher = PlazaTradeActionDispatcher.new()


func set_action_callback(callback: Callable) -> void:
	_action_dispatcher.set_callback(callback)


func get_status(player_item_count: int, shop_item_count: int) -> Dictionary:
	return {
		"hover_panel": _hover_state.panel,
		"hover_index": _hover_state.index,
		"player_scroll": _scroll_state.get_offset("player", player_item_count),
		"shop_scroll": _scroll_state.get_offset("shop", shop_item_count),
		"drag_active": _drag_state.is_active(),
		"confirm_open": _sell_confirm_state.is_open(),
		"confirm_panel": _sell_confirm_state.panel,
		"confirm_index": _sell_confirm_state.index,
	}


func update_pointer(local_position: Vector2) -> bool:
	if not _drag_state.is_active() or _drag_state.position == local_position:
		return false
	_drag_state.update_position(local_position)
	return true


func update_hover(
	local_position: Vector2,
	game_position: Vector2,
	player_inventory: Array,
	shop_inventory: Array
) -> bool:
	var panel := PlazaInteriorLayout.get_trade_panel_at_pos(game_position)
	var index := _get_cell_index(panel, game_position, player_inventory, shop_inventory)
	return _hover_state.update(panel, index, local_position)


func perform_at(game_position: Vector2, player_inventory: Array, shop_inventory: Array) -> bool:
	var panel := PlazaInteriorLayout.get_trade_panel_at_pos(game_position)
	if panel == "":
		return false
	var index := _get_cell_index(panel, game_position, player_inventory, shop_inventory)
	return _perform_trade(panel, index, player_inventory, shop_inventory)


func scroll_at(
	game_position: Vector2,
	direction: int,
	player_inventory: Array,
	shop_inventory: Array
) -> bool:
	var panel := PlazaInteriorLayout.get_trade_panel_at_pos(game_position)
	var items := get_items(panel, player_inventory, shop_inventory)
	return _scroll_state.scroll_rows(panel, direction, items.size())


func begin_drag(
	game_position: Vector2,
	local_position: Vector2,
	player_inventory: Array,
	shop_inventory: Array
) -> bool:
	var panel := PlazaInteriorLayout.get_trade_panel_at_pos(game_position)
	var index := _get_cell_index(panel, game_position, player_inventory, shop_inventory)
	if index < 0:
		_drag_state.reset()
		return false
	_drag_state.start(panel, index, local_position, get_item(panel, index, player_inventory, shop_inventory))
	return true


func finish_drag(
	game_position: Vector2,
	local_position: Vector2,
	player_inventory: Array,
	shop_inventory: Array
) -> bool:
	if not _drag_state.is_active():
		return false
	var start_panel := _drag_state.panel
	var start_index := _drag_state.index
	var dragged_item := _drag_state.item.duplicate(true)
	var release_panel := PlazaInteriorLayout.get_trade_panel_at_pos(game_position)
	var click_release := _drag_state.is_click_release(local_position)
	var drop_index := -1
	if release_panel == start_panel and not click_release:
		drop_index = _get_drop_index(start_panel, game_position, player_inventory, shop_inventory)
	_drag_state.reset()
	var decision := PlazaTradeDropDecision.resolve(
		start_panel,
		start_index,
		release_panel,
		click_release,
		drop_index,
		PlazaTradeItemPresentation.is_equipped(dragged_item)
	)
	match str(decision.get("action", "")):
		PlazaTradeDropDecision.ACTION_CONFIRM_SELL:
			return _open_sell_confirm(int(decision.get("index", -1)), dragged_item)
		PlazaTradeDropDecision.ACTION_TRADE:
			return _perform_trade(
				str(decision.get("panel", "")),
				int(decision.get("index", -1)),
				player_inventory,
				shop_inventory
			)
		PlazaTradeDropDecision.ACTION_REORDER:
			return _action_dispatcher.dispatch_reorder(
				str(decision.get("panel", "")),
				int(decision.get("from_index", -1)),
				int(decision.get("to_index", -1))
			)
	return false


func handle_confirm_mouse(
	game_position: Vector2,
	button_index: MouseButton,
	pressed: bool,
	player_inventory: Array,
	shop_inventory: Array
) -> bool:
	if not _sell_confirm_state.is_open():
		return false
	if button_index == MOUSE_BUTTON_LEFT and pressed:
		if PlazaInteriorLayout.SHOP_TRADE_CONFIRM_SELL_RECT.has_point(game_position):
			confirm_sell(player_inventory, shop_inventory)
		elif (
			PlazaInteriorLayout.SHOP_TRADE_CONFIRM_CANCEL_RECT.has_point(game_position)
			or not PlazaInteriorLayout.SHOP_TRADE_CONFIRM_RECT.has_point(game_position)
		):
			clear_confirm()
		return true
	if button_index == MOUSE_BUTTON_RIGHT and pressed:
		clear_confirm()
		return true
	return true


func confirm_sell(player_inventory: Array, shop_inventory: Array) -> bool:
	var request := _sell_confirm_state.consume_request()
	if request.is_empty():
		return false
	return _perform_trade(
		str(request.get("panel", "")),
		int(request.get("index", -1)),
		player_inventory,
		shop_inventory,
		true
	)


func clear_confirm() -> bool:
	var was_open := _sell_confirm_state.is_open()
	_sell_confirm_state.reset()
	return was_open


func reset_drag() -> bool:
	var was_active := _drag_state.is_active()
	_drag_state.reset()
	return was_active


func clamp_scroll_offsets(player_item_count: int, shop_item_count: int) -> void:
	_scroll_state.clamp_inventories(player_item_count, shop_item_count)


func get_panel_rect(panel: String) -> Rect2:
	return PlazaInteriorLayout.get_trade_panel_rect(panel)


func get_cell_center(
	panel: String,
	index: int,
	player_inventory: Array,
	shop_inventory: Array
) -> Vector2:
	var items := get_items(panel, player_inventory, shop_inventory)
	var scroll_offset := _scroll_state.get_offset(panel, items.size())
	return PlazaInteriorLayout.get_trade_cell_center(panel, index, items.size(), scroll_offset)


func get_items(panel: String, player_inventory: Array, shop_inventory: Array) -> Array:
	if panel == "player":
		return player_inventory
	if panel == "shop":
		return shop_inventory
	return []


func get_item(panel: String, index: int, player_inventory: Array, shop_inventory: Array) -> Dictionary:
	var items := get_items(panel, player_inventory, shop_inventory)
	if index < 0 or index >= items.size():
		return {}
	return _get_dict(items[index])


func get_scroll_offset(panel: String, item_count: int) -> int:
	return _scroll_state.get_offset(panel, item_count)


func get_hover_panel() -> String:
	return _hover_state.panel


func get_hover_index() -> int:
	return _hover_state.index


func get_hover_local_position() -> Vector2:
	return _hover_state.local_position


func has_hover_item() -> bool:
	return _hover_state.has_item()


func is_drag_active() -> bool:
	return _drag_state.is_active()


func get_drag_position() -> Vector2:
	return _drag_state.position


func get_drag_item() -> Dictionary:
	return _drag_state.item


func is_confirm_open() -> bool:
	return _sell_confirm_state.is_open()


func get_confirm_item() -> Dictionary:
	return _sell_confirm_state.item


func _perform_trade(
	panel: String,
	index: int,
	player_inventory: Array,
	shop_inventory: Array,
	bypass_confirm: bool = false
) -> bool:
	if panel == "" or index < 0:
		return false
	if panel == "player" and not bypass_confirm:
		var item_data := get_item(panel, index, player_inventory, shop_inventory)
		if PlazaTradeItemPresentation.is_equipped(item_data):
			return _open_sell_confirm(index, item_data)
	return _action_dispatcher.dispatch_trade(panel, index)


func _open_sell_confirm(index: int, item_data: Dictionary) -> bool:
	if item_data.is_empty():
		return false
	if not _sell_confirm_state.open("player", index, item_data):
		return false
	_drag_state.reset()
	return true


func _get_cell_index(
	panel: String,
	game_position: Vector2,
	player_inventory: Array,
	shop_inventory: Array
) -> int:
	var panel_rect := PlazaInteriorLayout.get_trade_panel_rect(panel)
	var items := get_items(panel, player_inventory, shop_inventory)
	var scroll_offset := _scroll_state.get_offset(panel, items.size())
	return PlazaInteriorLayout.get_trade_cell_index_at_pos(
		panel_rect,
		items.size(),
		scroll_offset,
		game_position
	)


func _get_drop_index(
	panel: String,
	game_position: Vector2,
	player_inventory: Array,
	shop_inventory: Array
) -> int:
	var items := get_items(panel, player_inventory, shop_inventory)
	var scroll_offset := _scroll_state.get_offset(panel, items.size())
	return PlazaInteriorLayout.get_trade_drop_index_at_pos(
		panel,
		items.size(),
		scroll_offset,
		game_position
	)


static func _get_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
