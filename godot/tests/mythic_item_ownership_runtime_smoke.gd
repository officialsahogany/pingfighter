extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")


func _init() -> void:
	var runtime := MythicItemRuntime.new()
	_expect(not runtime.has_owned_item_name("lucky_coin"), "fresh runtime should not report Lucky Coin ownership")
	_expect(not runtime.should_skip_one_time_passive_spawn("lucky_coin"), "unowned one-time passive should remain spawnable")

	runtime.inventory_items.append({"name": "lucky_coin"})
	_expect(runtime.has_owned_item_name("lucky_coin"), "ownership helper should find inventory items by name")
	_expect(runtime.should_skip_one_time_passive_spawn("lucky_coin"), "owned one-time passive should be skipped")
	var first_item: Dictionary = runtime.get_inventory_item(0)
	_expect(str(first_item.get("name", "")) == "lucky_coin", "ownership helper should expose inventory items by index")
	first_item["name"] = "mutated"
	_expect(str(runtime.get_inventory_item(0).get("name", "")) == "lucky_coin", "inventory item access should return a duplicate")
	_expect(runtime.get_inventory_item(-1).is_empty(), "inventory item access should guard negative indexes")
	_expect(runtime.get_inventory_item(99).is_empty(), "inventory item access should guard overflow indexes")

	_expect(not runtime.should_skip_one_time_passive_spawn("revival"), "unused and unowned Revival should remain spawnable")
	runtime.revival_state.used = true
	_expect(runtime.should_skip_one_time_passive_spawn("revival"), "used Revival should be skipped even after consumption")

	_expect(not runtime.should_skip_one_time_passive_spawn("speedboots"), "repeatable passive items should not use one-time skip rules")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/items/mythic_item_runtime.gd")
	_expect(
		runtime_source.find("return ownership_runtime.get_inventory_item(self, index)") >= 0,
		"runtime should delegate inventory item reads to ownership runtime"
	)
	_expect(
		runtime_source.find("var item_data: Dictionary = _get_dict(inventory_items[index])") < 0,
		"runtime should not keep inventory item normalization inline"
	)

	print("mythic_item_ownership_runtime_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
