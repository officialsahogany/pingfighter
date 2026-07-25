extends RefCounted

const ACTION_CONFIRM_SELL := "confirm_sell"
const ACTION_TRADE := "trade"
const ACTION_REORDER := "reorder"


static func resolve(
	start_panel: String,
	start_index: int,
	release_panel: String,
	click_release: bool,
	drop_index: int,
	is_equipped: bool
) -> Dictionary:
	if start_panel == "" or start_index < 0:
		return {}
	if release_panel != "" and release_panel != start_panel:
		return _build_trade_decision(start_panel, start_index, is_equipped)
	if release_panel == start_panel and not click_release:
		if drop_index < 0:
			return {}
		return {
			"action": ACTION_REORDER,
			"panel": start_panel,
			"from_index": start_index,
			"to_index": drop_index,
		}
	if click_release:
		return _build_trade_decision(start_panel, start_index, is_equipped)
	return {}


static func _build_trade_decision(panel: String, index: int, is_equipped: bool) -> Dictionary:
	return {
		"action": ACTION_CONFIRM_SELL if panel == "player" and is_equipped else ACTION_TRADE,
		"panel": panel,
		"index": index,
	}
