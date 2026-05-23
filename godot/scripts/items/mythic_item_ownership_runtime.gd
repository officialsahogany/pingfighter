extends RefCounted

const ITEM_REVIVAL := "revival"
const ITEM_SACRED_LAUREL := "sacred_laurel"


func has_owned_item_name(runtime: Object, item_name: String) -> bool:
	for item_value in runtime.inventory_items:
		var item_data: Dictionary = runtime._get_dict(item_value)
		if str(item_data.get("name", "")) == item_name:
			return true
	return false


func should_skip_one_time_passive_spawn(runtime: Object, item_name: String) -> bool:
	var normalized_name := str(item_name)
	match normalized_name:
		ITEM_REVIVAL:
			return runtime.revival_runtime.has_used(runtime) or has_owned_item_name(runtime, normalized_name)
		"lucky_coin", "rainbow_fur_glove", "star_detector", ITEM_SACRED_LAUREL:
			return has_owned_item_name(runtime, normalized_name)
		_:
			return false
