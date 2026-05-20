extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")

class FakeOwner:
	extends RefCounted

	var values: Dictionary = {}
	var set_count := 0

	func _get(property: StringName) -> Variant:
		return values.get(String(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[String(property)] = value
		set_count += 1
		return true


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null


var _failures: Array[String] = []


func _init() -> void:
	_verify_empty_runtime_has_no_field_effects()
	_verify_empty_runtime_skips_owner_sync()
	_verify_static_equipment_skips_owner_sync()
	_verify_transient_effect_keeps_update_path_live()

	if _failures.is_empty():
		print("mythic_item_runtime_idle_update_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_empty_runtime_has_no_field_effects() -> void:
	var runtime: Object = MythicItemRuntime.new()
	_expect(not bool(runtime.has_visible_field_effects()), "empty mythic runtime should not expose visible field effects")
	runtime.ragnarok_boss_stun_timer_frames = 1.0
	_expect(bool(runtime.has_visible_field_effects()), "active mythic field state should expose visible field effects")


func _verify_empty_runtime_skips_owner_sync() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()

	runtime.update(owner, FakeRegistry.new(), 1.0 / 60.0)

	_expect(owner.set_count == 0, "empty mythic runtime should not sync owner every frame")


func _verify_static_equipment_skips_owner_sync() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	runtime.inventory_items.append({
		"name": "speedboots",
		"_equipped_slot": "boots",
	})
	runtime.equipped_items["speedboots"] = runtime.inventory_items[0]

	runtime.update(owner, FakeRegistry.new(), 1.0 / 60.0)

	_expect(owner.set_count == 0, "static equipped mythic item should not resync owner every frame")


func _verify_transient_effect_keeps_update_path_live() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	runtime.activation_started_msec = Time.get_ticks_msec()

	runtime.update(owner, FakeRegistry.new(), 1.0 / 60.0)

	_expect(owner.set_count > 0, "active mythic transient effect should still run the normal update path")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
