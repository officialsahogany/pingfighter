extends SceneTree

const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PlayerMovementState := preload("res://scripts/characters/player_movement_state.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var bulletproof_hat_equipped := false
	var bulletproof_hat_stun_resist_pct := 0.0
	var player_stun_resist_pct := 0.0
	var spiked_helmet_equipped := false
	var spiked_helmet_knockback_resist_pct := 0.0
	var player_knockback_resist_pct := 0.0
	var player_knockback_resist_scale := 1.0

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	var player_movement_state: Object = null

	func _init(movement_state: Object) -> void:
		player_movement_state = movement_state

	func get_instance(key: String) -> Object:
		if key == "player_movement_state":
			return player_movement_state
		return null


func _init() -> void:
	var catalog: Object = MythicItemCatalog.new()
	_expect_head_item_catalog(catalog, "bulletproof_hat", "stun_resist_pct", "방탄모자")
	_expect_head_item_catalog(catalog, "spiked_helmet", "knockback_resist_pct", "가시투구")
	_expect_field_spawn_has(catalog, "bulletproof_hat")
	_expect_field_spawn_has(catalog, "spiked_helmet")

	var movement_state: Object = PlayerMovementState.new()
	var registry := FakeRegistry.new(movement_state)
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()

	_expect(runtime.equip_item("bulletproof_hat", owner, registry, {"stun_resist_pct": 20.0}, false), "bulletproof hat should equip")
	_expect(owner.equipment_slots.has("head"), "bulletproof hat should sync into head slot")
	_expect(str(owner.equipment_slots["head"].get("name", "")) == "bulletproof_hat", "bulletproof hat should occupy head slot")
	_expect(owner.bulletproof_hat_equipped, "owner should expose bulletproof hat equipped")
	_expect(is_equal_approx(owner.player_stun_resist_pct, 20.0), "owner should sync bulletproof stun resistance")
	_expect(is_equal_approx(runtime.get_player_stun_resist_pct(), 20.0), "runtime should expose bulletproof stun resistance")
	_expect(is_equal_approx(runtime.get_player_stun_duration_seconds(1.5), 1.2), "20% stun resistance should reduce 1.5s to 1.2s")

	_expect(runtime.equip_item("spiked_helmet", owner, registry, {"knockback_resist_pct": 20.0}, false), "spiked helmet should equip")
	_expect(owner.equipment_slots.has("head"), "spiked helmet should sync into head slot")
	_expect(str(owner.equipment_slots["head"].get("name", "")) == "spiked_helmet", "spiked helmet should replace the head slot item")
	_expect(not owner.bulletproof_hat_equipped, "replaced bulletproof hat should no longer be equipped")
	_expect(owner.spiked_helmet_equipped, "owner should expose spiked helmet equipped")
	_expect(is_equal_approx(owner.player_knockback_resist_pct, 20.0), "owner should sync spiked helmet knockback resistance")
	_expect(is_equal_approx(movement_state.get_knockback_resist_pct(), 20.0), "movement state should receive knockback resistance")
	_expect(is_equal_approx(movement_state.get_knockback_resist_scale(), 0.8), "20% knockback resistance should use 0.8 scale")
	_expect(movement_state.start_knockback(10.0, 18.0, 0.92, true, true), "reduced knockback should still start")
	var knockback_snapshot: Dictionary = movement_state.get_status_snapshot()
	_expect(is_equal_approx(float(knockback_snapshot.get("knockback_vel", 0.0)), 8.0), "spiked helmet should reduce knockback velocity")
	_expect(is_equal_approx(float(knockback_snapshot.get("knockback_resist_scale", 0.0)), 0.8), "snapshot should expose knockback resistance scale")

	_expect(runtime.unequip_item("spiked_helmet", owner, registry), "spiked helmet should unequip")
	_expect(is_equal_approx(movement_state.get_knockback_resist_pct(), 0.0), "movement state resistance should clear after unequip")

	print("head_defense_items_port_smoke: ok")
	quit(0)


func _expect_head_item_catalog(catalog: Object, item_name: String, roll_key: String, display_name: String) -> void:
	var item_data: Dictionary = catalog.build_item_by_name(item_name)
	_expect(not item_data.is_empty(), "%s should build from catalog" % item_name)
	_expect(str(item_data.get("slot", "")) == "head", "%s should use the head slot" % item_name)
	_expect(str(item_data.get("display_name", "")) == display_name, "%s should keep Korean display name" % item_name)
	var icon_path: String = str(item_data.get("icon_path", ""))
	_expect(icon_path != "", "%s should expose an icon path" % item_name)
	_expect(ProjectResourceLoader.load_texture(icon_path) != null, "%s icon should load through ProjectResourceLoader" % item_name)
	var roll_options: Array = catalog.get_roll_options(item_name)
	_expect(roll_options.size() == 1, "%s should have exactly one roll option" % item_name)
	var option: Dictionary = roll_options[0]
	_expect(str(option.get("key", "")) == roll_key, "%s should expose %s roll option" % [item_name, roll_key])
	_expect(is_equal_approx(float(option.get("min", 0.0)), 10.0), "%s roll min should match Python reference" % item_name)
	_expect(is_equal_approx(float(option.get("max", 0.0)), 20.0), "%s roll max should match Python reference" % item_name)


func _expect_field_spawn_has(catalog: Object, item_name: String) -> void:
	for item_value in catalog.get_field_spawn_items():
		var item_data: Dictionary = item_value if item_value is Dictionary else {}
		if str(item_data.get("name", "")) == item_name:
			return
	_expect(false, "%s should be available in the normal field spawn pool" % item_name)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
