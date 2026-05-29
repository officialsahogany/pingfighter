extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemPickupFeedback := preload("res://scripts/items/active_item_pickup_feedback.gd")
const ActiveItemPickupRouter := preload("res://scripts/items/active_item_pickup_router.gd")
const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")

var _failures: Array[String] = []
var _last_pickup_field_item: Dictionary = {}


class FakeOwner:
	extends Node

	var active_item_slots: Array = []


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null


func _init() -> void:
	_verify_active_pickup_use_hint()
	_verify_router_collect_preserves_slot_key_hint()
	_verify_passive_pickup_keeps_notice_fallback()

	if _failures.is_empty():
		print("active_item_pickup_use_hint_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_active_pickup_use_hint() -> void:
	var feedback := ActiveItemPickupFeedback.new()
	var controller := ActiveItemEffectController.new()
	var catalog := ActiveItemCatalog.new()
	var slot_controller := ActiveItemSlotController.new()
	var active_item_slots: Array = [
		catalog.build_item_by_name("boomerang"),
		catalog.build_item_by_name("soap"),
	]
	var field_item := {
		"item_data": catalog.build_item_by_name("banana"),
		"position": Vector2(220.0, 310.0),
	}

	_expect(slot_controller.store_active_item(field_item, active_item_slots, null, Callable()), "active pickup should store into an active slot")
	feedback.trigger_pickup_effect(field_item, controller, null)

	_expect(controller.has_pickup_effect(), "active pickup should create a pickup popup")
	_expect(controller.pickup_effect.get("use_hint_text", "") == "3번 키로 사용", "active pickup should display the stored slot key")
	_expect(field_item.get("pickup_use_hint_text", "") == "3번 키로 사용", "active pickup should annotate the field item use hint")


func _verify_router_collect_preserves_slot_key_hint() -> void:
	var catalog := ActiveItemCatalog.new()
	var router := ActiveItemPickupRouter.new()
	var slot_controller := ActiveItemSlotController.new()
	var effect_controller := ActiveItemEffectController.new()
	var feedback := ActiveItemPickupFeedback.new()
	var popup_controller := ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	owner.active_item_slots = [catalog.build_item_by_name("boomerang")]
	var field_item := {
		"item_data": catalog.build_item_by_name("soap"),
		"position": Vector2(230.0, 300.0),
	}

	_expect(router.collect_field_item_to_owner_slots(
		field_item,
		owner,
		FakeRegistry.new(),
		slot_controller,
		effect_controller,
		Callable(self, "_record_pickup_feedback")
	), "router should collect active items into owner slots")
	_expect(int(field_item.get("stored_active_slot_index", -1)) == 1, "router should annotate the collected active slot index")
	_expect(int(_last_pickup_field_item.get("stored_active_slot_index", -1)) == 1, "router pickup callback should receive the collected active slot index")

	feedback.trigger_pickup_effect(_last_pickup_field_item, popup_controller, null)
	_expect(popup_controller.pickup_effect.get("use_hint_text", "") == "2번 키로 사용", "router-collected active pickup should display the stored slot key")
	owner.free()


func _verify_passive_pickup_keeps_notice_fallback() -> void:
	var feedback := ActiveItemPickupFeedback.new()
	var controller := ActiveItemEffectController.new()
	var field_item := {
		"item_data": {"name": "passive_test_item", "type": "passive", "display_name": "패시브 테스트"},
		"position": Vector2(240.0, 320.0),
		"stored_active_slot_index": 0,
	}

	feedback.trigger_pickup_effect(field_item, controller, null)

	_expect(controller.has_pickup_effect(), "passive pickup should still create a pickup popup")
	_expect(str(controller.pickup_effect.get("use_hint_text", "")) == "", "passive pickup should not display an active-item key hint")
	_expect(str(field_item.get("pickup_use_hint_text", "")) == "", "passive pickup should clear any active-item key hint")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _record_pickup_feedback(field_item: Dictionary, _registry: Object) -> void:
	_last_pickup_field_item = field_item.duplicate(true)
