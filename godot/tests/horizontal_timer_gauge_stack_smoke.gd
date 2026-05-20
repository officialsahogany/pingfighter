extends SceneTree

const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const HorizontalTimerGaugeStack := preload("res://scripts/hud/horizontal_timer_gauge_stack.gd")


func _init() -> void:
	var registry: Object = GameplayModuleRegistry.new()
	var registry_stack: Object = registry.get_instance("horizontal_timer_gauge_stack")
	_expect(registry_stack != null, "horizontal timer gauge stack should load from the HUD catalog")
	_expect(registry_stack.has_method("claim"), "horizontal timer gauge stack should expose claim()")

	var stack: Object = HorizontalTimerGaugeStack.new()
	_expect(int(stack.claim("long_boost", true)) == 0, "first active timer should own the bottom row")

	stack.begin_frame()
	_expect(int(stack.claim("recovery_boost", true)) == 1, "newer recovery timer should stack above an already-active item timer")
	_expect(int(stack.claim("long_boost", true)) == 0, "older item timer should keep the bottom row even if drawn later")
	stack.end_frame()
	_expect(_order_string(stack) == "long_boost,recovery_boost", "shared stack should preserve activation order")

	stack.begin_frame()
	_expect(int(stack.claim("recovery_boost", true)) == 1, "stale lower rows should be stable during the current draw frame")
	stack.end_frame()
	_expect(int(stack.get_index("recovery_boost")) == 0, "deactivated lower timers should compact the stack after the draw frame")

	stack.begin_frame()
	_expect(int(stack.claim("recovery_boost", true)) == 0, "remaining timer should draw on the bottom row after compaction")
	_expect(int(stack.claim("long_boost", true)) == 1, "new item timer should draw above the older recovery timer")
	stack.end_frame()
	_expect(_order_string(stack) == "recovery_boost,long_boost", "reactivated item should be appended as the newest row")

	stack.deactivate("recovery_boost")
	_expect(int(stack.get_index("long_boost")) == 0, "manual deactivation should compact remaining rows immediately")

	print("horizontal_timer_gauge_stack_smoke: ok")
	quit(0)


func _order_string(stack: Object) -> String:
	var order: Array = stack.get_active_order()
	var parts := PackedStringArray()
	for value in order:
		parts.append(str(value))
	return ",".join(parts)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
