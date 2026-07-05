extends SceneTree

# Seals the active-item slot reorder / discard APIs that back the character-info
# active-slot drag reorder and trash-drop. Reverse-verify by breaking the swap
# or remove_at branch in active_item_runtime.gd.

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")


class FakeOwner:
	var active_item_slots: Array = []
	var redraw_calls: int = 0

	func queue_redraw() -> void:
		redraw_calls += 1


class FakeBattleOwner:
	var active_item_slots: Array = []
	var queue_calls: int = 0
	var request_calls: int = 0

	func request_battle_redraw() -> void:
		request_calls += 1

	func queue_redraw() -> void:
		queue_calls += 1


class FakeHudState:
	var selected := 0

	func get_selected_index() -> int:
		return selected

	func set_selected_index(index: int) -> void:
		selected = index


class FakeRegistry:
	var hud_state: Object

	func get_instance(key: String) -> Object:
		if key == "active_item_hud_state":
			return hud_state
		return null


func _init() -> void:
	_verify_reorder_swaps_two_slots()
	_verify_reorder_rejects_out_of_range()
	_verify_discard_removes_slot()
	_verify_discard_rejects_out_of_range()
	_verify_discard_decrements_selection_before_it()
	_verify_discard_keeps_selection_after_it()
	_verify_discard_clamps_selection_at_end()
	_verify_battle_owner_prefers_redraw_request()
	print("active_item_slot_reorder_smoke: ok")
	quit(0)


func _verify_reorder_swaps_two_slots() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	var owner := FakeOwner.new()
	owner.active_item_slots = [
		{"name": "dash_boost"},
		{"name": "gauge_charge"},
		{"name": "brick_wall"},
	]
	_expect(runtime.reorder_active_slots(0, 2, owner), "reorder of two occupied slots should succeed")
	_expect(str(owner.active_item_slots[0].get("name", "")) == "brick_wall", "slot 0 should now hold the item dragged from slot 2")
	_expect(str(owner.active_item_slots[2].get("name", "")) == "dash_boost", "slot 2 should now hold the item dragged from slot 0")
	_expect(str(owner.active_item_slots[1].get("name", "")) == "gauge_charge", "the untouched slot should be unchanged")
	_expect(owner.redraw_calls >= 1, "a successful reorder should request a redraw")


func _verify_reorder_rejects_out_of_range() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	var owner := FakeOwner.new()
	owner.active_item_slots = [{"name": "dash_boost"}]
	_expect(not runtime.reorder_active_slots(0, 3, owner), "dropping onto an empty (out-of-range) slot must be a no-op")
	_expect(not runtime.reorder_active_slots(0, 0, owner), "reorder onto the same slot must be a no-op")
	_expect(str(owner.active_item_slots[0].get("name", "")) == "dash_boost", "a rejected reorder must not change the slots")


func _verify_discard_removes_slot() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	var owner := FakeOwner.new()
	owner.active_item_slots = [
		{"name": "dash_boost"},
		{"name": "gauge_charge"},
	]
	_expect(runtime.discard_active_slot(0, owner), "discarding an occupied slot should succeed")
	_expect(owner.active_item_slots.size() == 1, "discard should shrink the slot array")
	_expect(str(owner.active_item_slots[0].get("name", "")) == "gauge_charge", "the surviving item should shift down")
	_expect(owner.redraw_calls >= 1, "a successful discard should request a redraw")


func _verify_discard_rejects_out_of_range() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	var owner := FakeOwner.new()
	owner.active_item_slots = [{"name": "dash_boost"}]
	_expect(not runtime.discard_active_slot(5, owner), "discarding an out-of-range slot must be a no-op")
	_expect(owner.active_item_slots.size() == 1, "a rejected discard must not change the slots")


func _verify_discard_decrements_selection_before_it() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	var owner := FakeOwner.new()
	owner.active_item_slots = [{"name": "a"}, {"name": "b"}, {"name": "c"}]
	var hud := FakeHudState.new()
	hud.selected = 2
	var registry := FakeRegistry.new()
	registry.hud_state = hud
	_expect(runtime.discard_active_slot(0, owner, registry), "discard should succeed")
	_expect(hud.selected == 1, "discarding before the selection should decrement the selected index")
	_expect(str(owner.active_item_slots[1].get("name", "")) == "c", "the selection should still track the same item after the shift")


func _verify_discard_keeps_selection_after_it() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	var owner := FakeOwner.new()
	owner.active_item_slots = [{"name": "a"}, {"name": "b"}, {"name": "c"}]
	var hud := FakeHudState.new()
	hud.selected = 0
	var registry := FakeRegistry.new()
	registry.hud_state = hud
	_expect(runtime.discard_active_slot(1, owner, registry), "discard should succeed")
	_expect(hud.selected == 0, "discarding after the selection should leave the selected index unchanged")


func _verify_discard_clamps_selection_at_end() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	var owner := FakeOwner.new()
	owner.active_item_slots = [{"name": "a"}, {"name": "b"}, {"name": "c"}]
	var hud := FakeHudState.new()
	hud.selected = 2
	var registry := FakeRegistry.new()
	registry.hud_state = hud
	_expect(runtime.discard_active_slot(2, owner, registry), "discard should succeed")
	_expect(hud.selected == 1, "discarding the last selected slot should clamp the selection into bounds")


func _verify_battle_owner_prefers_redraw_request() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	var owner := FakeBattleOwner.new()
	owner.active_item_slots = [{"name": "a"}, {"name": "b"}]
	_expect(runtime.reorder_active_slots(0, 1, owner), "battle owner reorder should still succeed")
	_expect(owner.request_calls == 1, "battle owner reorder should use request_battle_redraw")
	_expect(owner.queue_calls == 0, "battle owner reorder must not call queue_redraw directly")
	_expect(runtime.discard_active_slot(0, owner), "battle owner discard should still succeed")
	_expect(owner.request_calls == 2, "battle owner discard should use request_battle_redraw")
	_expect(owner.queue_calls == 0, "battle owner discard must not call queue_redraw directly")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
