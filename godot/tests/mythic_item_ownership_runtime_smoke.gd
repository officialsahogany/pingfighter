extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")


func _init() -> void:
	var runtime := MythicItemRuntime.new()
	_expect(not runtime.has_owned_item_name("lucky_coin"), "fresh runtime should not report Lucky Coin ownership")
	_expect(not runtime.should_skip_one_time_passive_spawn("lucky_coin"), "unowned one-time passive should remain spawnable")

	runtime.inventory_items.append({"name": "lucky_coin"})
	_expect(runtime.has_owned_item_name("lucky_coin"), "ownership helper should find inventory items by name")
	_expect(runtime.should_skip_one_time_passive_spawn("lucky_coin"), "owned one-time passive should be skipped")
	_expect(int(runtime.get_debug_item_counts().get("lucky_coin", 0)) == 1, "ownership helper should count one inventory item")
	var first_item: Dictionary = runtime.get_inventory_item(0)
	_expect(str(first_item.get("name", "")) == "lucky_coin", "ownership helper should expose inventory items by index")
	_expect(str(runtime.debug_get_inventory_item(0).get("name", "")) == "lucky_coin", "debug inventory item reads should use the ownership snapshot")
	first_item["name"] = "mutated"
	_expect(str(runtime.get_inventory_item(0).get("name", "")) == "lucky_coin", "inventory item access should return a duplicate")
	_expect(runtime.get_inventory_item(-1).is_empty(), "inventory item access should guard negative indexes")
	_expect(runtime.get_inventory_item(99).is_empty(), "inventory item access should guard overflow indexes")
	runtime.inventory_items.append({"name": "lucky_coin"})
	runtime.inventory_items.append({"name": ""})
	_expect(int(runtime.get_debug_item_counts().get("lucky_coin", 0)) == 2, "ownership helper should count duplicate item names")
	_expect(not runtime.get_debug_item_counts().has(""), "ownership helper should skip blank item names")
	var item_count_before_ensure: int = runtime.inventory_items.size()
	_expect(
		runtime.debug_ensure_item_for_roll_editor("", null, null) == -1,
		"roll editor inventory ensure should reject blank item names"
	)
	_expect(
		runtime.debug_ensure_item_for_roll_editor("lucky_coin", null, null) == 0,
		"roll editor inventory ensure should return the first owned matching item"
	)
	_expect(
		runtime.inventory_items.size() == item_count_before_ensure,
		"roll editor inventory ensure should not duplicate an owned item"
	)
	var speedboots_index: int = runtime.debug_ensure_item_for_roll_editor("speedboots", null, null)
	_expect(speedboots_index >= item_count_before_ensure, "roll editor inventory ensure should acquire missing valid items")
	_expect(runtime.has_owned_item_name("speedboots"), "roll editor inventory ensure should add the acquired item to ownership")
	var debug_toggle_runtime := MythicItemRuntime.new()
	_expect(
		not debug_toggle_runtime.debug_toggle_item("", null, null),
		"debug inventory toggle should reject blank item names"
	)
	_expect(
		debug_toggle_runtime.debug_toggle_item("speedboots", null, null),
		"debug inventory toggle should acquire missing valid items"
	)
	_expect(debug_toggle_runtime.has_owned_item_name("speedboots"), "debug inventory toggle should add missing items to ownership")
	_expect(debug_toggle_runtime.is_equipped("speedboots"), "debug inventory toggle should auto-equip acquired items")
	_expect(
		debug_toggle_runtime.debug_toggle_item("speedboots", null, null),
		"debug inventory toggle should toggle owned items"
	)
	_expect(not debug_toggle_runtime.is_equipped("speedboots"), "debug inventory toggle should unequip an equipped item")
	var debug_add_runtime := MythicItemRuntime.new()
	_expect(
		not debug_add_runtime.debug_add_item_to_inventory("", null, null),
		"debug inventory add should reject blank item names"
	)
	_expect(
		debug_add_runtime.debug_add_item_to_inventory("lucky_coin", null, null, {"double_spawn_pct": 5.0}),
		"debug inventory add should acquire valid items"
	)
	_expect(debug_add_runtime.has_owned_item_name("lucky_coin"), "debug inventory add should store acquired items")
	var debug_added_item: Dictionary = debug_add_runtime.get_inventory_item(0)
	var debug_added_rolls: Dictionary = debug_add_runtime._get_dict(debug_added_item.get("rolls", {}))
	_expect(
		is_equal_approx(float(debug_added_rolls.get("double_spawn_pct", 0.0)), 5.0),
		"debug inventory add should preserve roll overrides"
	)

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
		runtime_source.find("return debug_inventory.debug_get_inventory_item(self, index)") < 0,
		"runtime should not route debug inventory item reads through debug inventory"
	)
	_expect(
		runtime_source.find("return ownership_runtime.get_inventory_item_counts(self)") >= 0,
		"runtime should delegate inventory item counts to ownership runtime"
	)
	_expect(
		runtime_source.find("return ownership_runtime.ensure_inventory_item_for_roll_editor(self, item_name, owner, registry)") >= 0,
		"runtime should delegate roll editor inventory ensure to ownership runtime"
	)
	_expect(
		runtime_source.find("ownership_runtime.toggle_inventory_item_by_name") >= 0,
		"runtime should delegate debug inventory toggles to ownership runtime"
	)
	_expect(
		runtime_source.find("ownership_runtime.add_inventory_item_for_debug") >= 0,
		"runtime should delegate debug inventory add to ownership runtime"
	)
	_expect(
		runtime_source.find("debug_inventory.debug_ensure_item_for_roll_editor") < 0,
		"runtime should not route roll editor inventory ensure through debug inventory"
	)
	_expect(
		runtime_source.find("debug_inventory.debug_toggle_item") < 0,
		"runtime should not route debug inventory toggles through debug inventory"
	)
	_expect(
		runtime_source.find("debug_inventory.debug_add_item_to_inventory") < 0,
		"runtime should not route debug inventory add through debug inventory"
	)
	_expect(
		runtime_source.find("var item_data: Dictionary = _get_dict(inventory_items[index])") < 0,
		"runtime should not keep inventory item normalization inline"
	)
	var debug_source: String = FileAccess.get_file_as_string("res://scripts/items/mythic_item_debug_inventory.gd")
	_expect(debug_source.find("func get_debug_item_counts(") < 0, "debug inventory should not duplicate ownership item count logic")
	_expect(debug_source.find("func debug_get_inventory_item(") < 0, "debug inventory should not duplicate ownership item read logic")
	_expect(debug_source.find("func debug_ensure_item_for_roll_editor(") < 0, "debug inventory should not duplicate roll editor inventory ensure logic")
	_expect(debug_source.find("func debug_toggle_item(") < 0, "debug inventory should not duplicate ownership toggle logic")
	_expect(debug_source.find("func debug_add_item_to_inventory(") < 0, "debug inventory should not duplicate ownership add logic")

	print("mythic_item_ownership_runtime_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
