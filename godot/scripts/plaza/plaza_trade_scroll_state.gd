extends RefCounted

const PlazaInteriorLayout := preload("res://scripts/plaza/plaza_interior_layout.gd")

const PLAYER_PANEL := "player"
const SHOP_PANEL := "shop"

var _offsets := {
	PLAYER_PANEL: 0,
	SHOP_PANEL: 0,
}


func get_offset(panel: String, item_count: int) -> int:
	if not _offsets.has(panel):
		return 0
	var offset := PlazaInteriorLayout.clamp_trade_scroll_offset(
		int(_offsets.get(panel, 0)),
		item_count
	)
	_offsets[panel] = offset
	return offset


func scroll_rows(panel: String, direction: int, item_count: int) -> bool:
	if not _offsets.has(panel) or direction == 0:
		return false
	var current := get_offset(panel, item_count)
	var max_offset := PlazaInteriorLayout.get_trade_max_scroll_offset(item_count)
	if max_offset == 0:
		return false
	var next := clampi(
		current + direction * PlazaInteriorLayout.SHOP_TRADE_COLUMNS,
		0,
		max_offset
	)
	@warning_ignore("integer_division")
	next = int(next / PlazaInteriorLayout.SHOP_TRADE_COLUMNS) * PlazaInteriorLayout.SHOP_TRADE_COLUMNS
	if next == current:
		return false
	_offsets[panel] = next
	return true


func clamp_inventories(player_item_count: int, shop_item_count: int) -> void:
	get_offset(PLAYER_PANEL, player_item_count)
	get_offset(SHOP_PANEL, shop_item_count)


func reset() -> void:
	_offsets[PLAYER_PANEL] = 0
	_offsets[SHOP_PANEL] = 0
