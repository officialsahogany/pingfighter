extends SceneTree

const ActiveItemHudLayout := preload("res://scripts/hud/active_item_hud_layout.gd")
const ActiveItemHudSlotIconRenderer := preload("res://scripts/hud/active_item_hud_slot_icon_renderer.gd")
const ActiveItemHudSlotStatusRenderer := preload("res://scripts/hud/active_item_hud_slot_status_renderer.gd")
const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")


class FakeRegistry:
	var runtime_perk_state: Object

	func _init(perk_state: Object) -> void:
		runtime_perk_state = perk_state

	func get_instance(key: String) -> Object:
		if key == "runtime_perk_state":
			return runtime_perk_state
		return null


class StorePolicy:
	func can_store_item(_item_name: String) -> bool:
		return true


func _init() -> void:
	_expect(ActiveItemHudSlotStatusRenderer.ROUNDED_RECT_SAMPLES <= 1, "active-item HUD cooldown frame should keep a coarse rounded-rect budget")
	_expect(ActiveItemHudSlotIconRenderer.MEGINGJORD_FALLBACK_RING_SEGMENTS <= 20, "Megingjord fallback icon ring should keep a tightened arc budget")
	var status_source := FileAccess.get_file_as_string("res://scripts/hud/active_item_hud_slot_status_renderer.gd")
	var icon_source := FileAccess.get_file_as_string("res://scripts/hud/active_item_hud_slot_icon_renderer.gd")
	_expect(status_source.find("_frame_segment_lengths_cache") >= 0, "active-item HUD cooldown frame should cache segment lengths")
	_expect(status_source.find("_rebuild_frame_segment_cache(points)") >= 0, "active-item HUD cooldown frame should rebuild segment lengths only with the point cache")
	_expect(icon_source.find("MEGINGJORD_FALLBACK_RING_SEGMENTS") >= 0, "Megingjord fallback icon ring should use the budget constant")
	_expect(icon_source.find("Rect2(slot_rect.position.x + pad, slot_rect.position.y + pad, slot_rect.size.x - pad * 2.0, slot_rect.size.y - pad * 2.0)") >= 0, "active-item icon draw should build padded icon rects without temporary Vector2 values")
	_expect(icon_source.find("func _grow_rect_xy(rect: Rect2, amount: float) -> Rect2:") >= 0, "active-item icon draw should use a scalar grow helper")
	_expect(icon_source.find("return slot_rect.grow(") < 0, "active-item icon target rects should avoid slot_rect.grow allocations")
	_expect(icon_source.find("belt_rect.grow(") < 0, "Megingjord fallback icon should avoid belt rect grow allocations")
	_expect(icon_source.find("Vector2(pad, pad)") < 0, "active-item icon draw should avoid temporary pad vectors")

	var perk_state: Object = RuntimePerkState.new()
	_expect(
		perk_state.grant_tower_bag_expansion(2),
		"the reward-only bag contract must accept a two-slot run bonus"
	)
	_expect(
		not perk_state.runtime_skill_levels.has("tower_bag_expansion")
		and not perk_state.runtime_skill_levels.has("item_bag_expansion"),
		"bag expansion must remain outside both current and retired Mugong level maps"
	)
	var capacity: int = int(perk_state.get_active_item_slot_capacity(3))
	_expect(capacity == 5, "two Tower bag expansions should raise active item capacity to five")

	var layout_builder: Object = ActiveItemHudLayout.new()
	var empty_layout: Dictionary = layout_builder.build_layout(
		Vector2(1280.0, 900.0),
		Vector2(260.0, 60.0),
		Vector2(760.0, 750.0),
		760.0,
		0,
		capacity
	)
	_expect(bool(empty_layout.get("visible", false)), "expanded active item HUD should remain visible with no items")
	_expect(int(empty_layout.get("max_slots", 0)) == 5, "expanded HUD layout should expose five main slots")
	_expect(_array_size(empty_layout.get("slot_rects", [])) == 5, "expanded HUD should draw five empty slot rects")
	var empty_box_rect: Rect2 = empty_layout.get("main_box_rect", Rect2())
	var bottom_pillar_y: float = 60.0 + 750.0
	_expect(empty_box_rect.position.y >= bottom_pillar_y + 34.0, "active item HUD should sit lower in the bottom pillar")
	_expect(empty_box_rect.end.y <= 898.0, "lowered active item HUD should stay inside the viewport")

	var filled_layout: Dictionary = layout_builder.build_layout(
		Vector2(1280.0, 900.0),
		Vector2(260.0, 60.0),
		Vector2(760.0, 750.0),
		760.0,
		4,
		capacity
	)
	_expect(int(filled_layout.get("overflow_count", -1)) == 0, "four items should fit inside Tower-bag-expanded main slots")
	_expect(_array_size(filled_layout.get("slot_rects", [])) == 5, "one expanded empty slot should stay visible after four items")

	var overflow_layout: Dictionary = layout_builder.build_layout(
		Vector2(1280.0, 900.0),
		Vector2(260.0, 60.0),
		Vector2(760.0, 750.0),
		760.0,
		6,
		capacity
	)
	_expect(int(overflow_layout.get("overflow_count", -1)) == 1, "overflow should start only past the expanded capacity")
	_expect(_array_size(overflow_layout.get("slot_rects", [])) == 6, "overflow layout should still expose the extra item rect")

	var slot_controller: Object = ActiveItemSlotController.new()
	var registry := FakeRegistry.new(perk_state)
	var policy := StorePolicy.new()
	var active_slots: Array = [
		{"name": "banana"},
		{"name": "soap"},
		{"name": "grenade"},
	]
	_expect(
		slot_controller.store_active_item(
			{"item_data": {"name": "flare"}},
			active_slots,
			registry,
			Callable(policy, "can_store_item")
		),
		"slot controller should accept a fourth item after Tower bag expansion"
	)
	_expect(active_slots.size() == 4, "fourth item should be stored in the expanded slot")

	_expect(
		slot_controller.store_active_item(
			{"item_data": {"name": "soap"}},
			active_slots,
			registry,
			Callable(policy, "can_store_item")
		),
		"slot controller should accept a fifth item when Tower bag expansion exposes five slots"
	)
	_expect(active_slots.size() == 5, "fifth item should fill the last expanded slot")
	_expect(str(active_slots[4].get("name", "")) == "soap", "fifth item should occupy the last expanded slot")

	var placeholder_slots: Array = [
		{"name": "banana"},
		{"name": "soap"},
		{"name": "grenade"},
		{"name": "flare"},
		{},
	]
	_expect(
		slot_controller.store_active_item(
			{"item_data": {"name": "wall"}},
			placeholder_slots,
			registry,
			Callable(policy, "can_store_item")
		),
		"slot controller should count real items, not blank placeholder entries, before pickup"
	)
	_expect(placeholder_slots.size() == 5, "blank placeholder should be compacted before storing the pickup")
	_expect(str(placeholder_slots[4].get("name", "")) == "wall", "pickup should fill the compacted empty expanded slot")

	print("active_item_bag_expansion_smoke: ok")
	quit(0)


func _array_size(value: Variant) -> int:
	if value is Array:
		return value.size()
	return 0


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
