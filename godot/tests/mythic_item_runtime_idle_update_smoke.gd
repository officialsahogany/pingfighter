extends SceneTree

const MythicItemHelperRegistry := preload("res://scripts/items/mythic_item_helper_registry.gd")
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
	_verify_helper_registry_initializes_runtime()
	_verify_empty_runtime_has_no_field_effects()
	_verify_empty_runtime_skips_owner_sync()
	_verify_static_equipment_skips_owner_sync()
	_verify_transient_effect_keeps_update_path_live()
	_verify_ragnarok_attempt_flag_does_not_force_runtime_sync()
	_verify_ragnarok_transient_uses_light_owner_sync()
	_verify_non_ragnarok_transient_uses_light_owner_sync()

	if _failures.is_empty():
		print("mythic_item_runtime_idle_update_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_registry_initializes_runtime() -> void:
	_expect(MythicItemHelperRegistry.INIT_ORDER.has("catalog"), "helper registry should own the mythic helper init order")
	_expect(MythicItemHelperRegistry.INIT_ORDER.has("roll_editor_runtime"), "helper registry should initialize the mythic roll editor helper")
	_expect(not MythicItemHelperRegistry.INIT_ORDER.has("debug_inventory"), "helper registry should not keep the retired mythic debug inventory helper")
	_expect(
		MythicItemHelperRegistry.get_script_path("catalog").ends_with("mythic_item_catalog.gd"),
		"helper registry should own mythic helper script paths"
	)
	_expect(
		MythicItemHelperRegistry.get_script_path("roll_editor_runtime").ends_with("mythic_item_roll_editor_runtime.gd"),
		"helper registry should route roll editor work to the focused helper"
	)
	_expect(MythicItemHelperRegistry.get_script_path("debug_inventory") == "", "helper registry should not expose a retired mythic debug inventory path")
	var runtime: Object = MythicItemRuntime.new()
	_expect(not runtime.prewarm_initialization_step(false), "first helper prewarm step should initialize one helper")
	_expect(runtime.catalog != null, "helper registry should create the catalog helper on the first prewarm step")
	while not runtime.prewarm_initialization_step(false):
		pass
	for member_name in MythicItemHelperRegistry.INIT_ORDER:
		_expect(runtime.get(str(member_name)) != null, "helper registry should initialize %s" % str(member_name))
	var runtime_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_runtime.gd")
	_expect(runtime_source.find("const HELPER_SCRIPT_PATHS") < 0, "mythic runtime should not keep the helper path registry inline")
	_expect(runtime_source.find("var debug_inventory") < 0, "mythic runtime should not keep the retired debug inventory member")
	_expect(runtime_source.find("roll_editor_runtime") >= 0, "mythic runtime should call the focused roll editor helper")


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


func _verify_ragnarok_attempt_flag_does_not_force_runtime_sync() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	runtime.ragnarok_stun_attempted_this_rally = true

	runtime.update(owner, FakeRegistry.new(), 1.0 / 60.0)

	_expect(owner.set_count == 0, "Ragnarok attempt gate alone should not force per-frame owner sync")


func _verify_ragnarok_transient_uses_light_owner_sync() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	owner.values["mythic_item_state"] = {}
	runtime.ragnarok_boss_stun_timer_frames = 8.0
	runtime.ragnarok_boss_knockback_timer_frames = 8.0
	runtime.ragnarok_boss_knockback_vel = 12.0

	runtime.update(owner, FakeRegistry.new(), 1.0 / 60.0)
	var first_set_count := owner.set_count
	var state: Dictionary = owner.values.get("mythic_item_state", {})
	runtime.update(owner, FakeRegistry.new(), 1.0 / 60.0)

	_expect(first_set_count == 1, "Ragnarok-only transient update should sync only the slim mythic state")
	_expect(owner.set_count == first_set_count, "unchanged Ragnarok transient flags should not resync owner every frame")
	_expect(bool(state.get("ragnarok_hammer_boss_stun_active", false)), "slim sync should preserve Ragnarok boss stun state")


func _verify_non_ragnarok_transient_uses_light_owner_sync() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	owner.values["mythic_item_state"] = {}
	var item_data := {
		"name": "soul_burst",
		"_equipped_slot": "mythic",
	}
	runtime.inventory_items.append(item_data)
	runtime.equipped_items["soul_burst"] = item_data
	runtime.soul_burst_effect_timer_frames = 8.0
	runtime.soul_burst_dash_active = true

	runtime.update(owner, FakeRegistry.new(), 1.0 / 60.0)
	var first_set_count := owner.set_count
	var state: Dictionary = owner.values.get("mythic_item_state", {})
	runtime.update(owner, FakeRegistry.new(), 1.0 / 60.0)

	_expect(first_set_count <= 4, "non-Ragnarok transient sync should avoid full owner equipment sync")
	_expect(owner.set_count <= first_set_count + 2, "non-Ragnarok transient sync should stay slim across frames")
	_expect(not owner.values.has("equipment_slots"), "transient sync should not rebuild equipment slots every frame")
	_expect(bool(state.get("soul_burst_dash_active", false)), "transient sync should preserve Soul Burst dash state")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
