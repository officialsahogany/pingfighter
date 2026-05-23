extends RefCounted

const MYTHIC_ICON_FRAME_COUNT := 32
const MYTHIC_ICON_FRAME_MSEC := 33


func with_mythic_icon_sheet(item_data: Dictionary, icon_sheet_path: String) -> Dictionary:
	item_data["icon_sheet_path"] = icon_sheet_path
	item_data["icon_frame_count"] = MYTHIC_ICON_FRAME_COUNT
	item_data["icon_frame_msec"] = MYTHIC_ICON_FRAME_MSEC
	item_data["icon_source_inset"] = 0.0
	item_data["icon_fill_slot"] = true
	item_data["icon_target_pad"] = 5.0
	return item_data
