extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")


func _init() -> void:
	var runtime := MythicItemRuntime.new()
	_expect(not runtime.has_owned_item_name("lucky_coin"), "fresh runtime should not report Lucky Coin ownership")
	_expect(not runtime.should_skip_one_time_passive_spawn("lucky_coin"), "unowned one-time passive should remain spawnable")

	runtime.inventory_items.append({"name": "lucky_coin"})
	_expect(runtime.has_owned_item_name("lucky_coin"), "ownership helper should find inventory items by name")
	_expect(runtime.should_skip_one_time_passive_spawn("lucky_coin"), "owned one-time passive should be skipped")

	_expect(not runtime.should_skip_one_time_passive_spawn("revival"), "unused and unowned Revival should remain spawnable")
	runtime.revival_state.used = true
	_expect(runtime.should_skip_one_time_passive_spawn("revival"), "used Revival should be skipped even after consumption")

	_expect(not runtime.should_skip_one_time_passive_spawn("speedboots"), "repeatable passive items should not use one-time skip rules")

	print("mythic_item_ownership_runtime_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
