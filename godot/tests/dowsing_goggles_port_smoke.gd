extends SceneTree

const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var megingjord_equipped := false
	var dowsing_pendulum_equipped := false
	var dowsing_pendulum_range := 0.0
	var dowsing_pendulum_context: Dictionary = {}
	var dowsing_goggles_equipped := false
	var dowsing_goggles_active := false
	var dowsing_goggles_bonus_perk_chance := 0.0
	var dowsing_goggles_bonus_triggered := false
	var accessory_slot_count := 2
	var runtime_accessory_slot_bonus := 0
	var runtime_perk_levels: Dictionary = {}
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_pos := Vector2(300.0, 700.0)

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	var mythic_item_runtime: Object
	var runtime_perk_state: Object

	func _init(item_runtime: Object, perk_state: Object) -> void:
		mythic_item_runtime = item_runtime
		runtime_perk_state = perk_state

	func get_instance(key: String) -> Object:
		match key:
			"mythic_item_runtime":
				return mythic_item_runtime
			"runtime_perk_state":
				return runtime_perk_state
		return null


func _init() -> void:
	var item_catalog := MythicItemCatalog.new()
	var item_data: Dictionary = item_catalog.build_item_by_name("dowsing_goggles")
	_expect(not item_data.is_empty(), "Dowsing Goggles should be registered in the passive catalog")
	_expect(str(item_data.get("slot", "")) == "head", "Dowsing Goggles should use the head slot")
	_expect(str(item_data.get("type", "")) == "passive", "Dowsing Goggles should be a passive item")
	_expect(_array_has_item(item_catalog.get_field_spawn_items(), "dowsing_goggles"), "Dowsing Goggles should be in the field-spawn passive pool")
	_expect(_array_has_item(item_catalog.get_debug_items(), "dowsing_goggles"), "Dowsing Goggles should be in the passive debug item list")
	var chance_option: Dictionary = _find_roll_option(item_data, "bonus_perk_chance")
	_expect(is_equal_approx(float(chance_option.get("min", 0.0)), 30.0), "Dowsing Goggles chance roll should start at 30%")
	_expect(is_equal_approx(float(chance_option.get("max", 0.0)), 60.0), "Dowsing Goggles chance roll should cap at 60%")
	_expect(is_equal_approx(float(chance_option.get("default", 0.0)), 30.0), "Dowsing Goggles default chance should match Python")
	_expect(ProjectResourceLoader.load_texture("res://assets/sprites/items/dowsing_goggles.png") != null, "Dowsing Goggles icon should load from Godot assets")

	var runtime := MythicItemRuntime.new()
	var perk_catalog := RuntimePerkCatalog.new()
	var perk_state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime, perk_state)
	var field_spawn_pool := ActiveItemFieldSpawnPool.new()
	_expect(
		field_spawn_pool.get_field_spawn_candidate_names(registry, owner).has("dowsing_goggles"),
		"shared field-spawn pool should expose Dowsing Goggles"
	)
	_expect(
		runtime.equip_item("dowsing_goggles", owner, registry, {"bonus_perk_chance": 100.0}, false),
		"Dowsing Goggles should equip through mythic_item_runtime"
	)
	_expect(owner.dowsing_goggles_equipped, "owner sync should expose Dowsing Goggles equipped state")
	_expect(is_equal_approx(owner.dowsing_goggles_bonus_perk_chance, 100.0), "owner sync should expose the rolled bonus chance")
	_expect(is_equal_approx(runtime.get_dowsing_goggles_bonus_perk_chance_pct(), 100.0), "runtime should expose the rolled bonus chance")

	perk_state.pending_skill_choices = 1
	perk_state.open_next_choice("smasher", perk_catalog, false, owner, registry)
	var bonus_snapshot: Dictionary = perk_state.get_snapshot()
	var bonus_choices: Array = bonus_snapshot.get("current_choices", [])
	_expect(bonus_choices.size() == 4, "100% Dowsing Goggles should add one protected perk card")
	_expect(bool(_get_choice(bonus_choices, 3).get("is_dowsing_goggles_bonus", false)), "the added card should be marked for Dowsing Goggles UI feedback")
	_expect(runtime.was_dowsing_goggles_bonus_triggered(), "runtime should remember the latest Dowsing Goggles trigger")

	_expect(runtime.unequip_item("dowsing_goggles", owner, registry), "Dowsing Goggles should unequip")
	var normal_state := RuntimePerkState.new()
	registry.runtime_perk_state = normal_state
	normal_state.pending_skill_choices = 1
	normal_state.open_next_choice("smasher", perk_catalog, false, owner, registry)
	var normal_choices: Array = normal_state.get_snapshot().get("current_choices", [])
	_expect(normal_choices.size() == 3, "unequipped Dowsing Goggles should leave the normal three perks")
	_expect(not runtime.was_dowsing_goggles_bonus_triggered(), "unequip should clear the latest Dowsing Goggles trigger")

	var polish_state := RuntimePerkState.new()
	polish_state.runtime_skill_levels["item_polish"] = 2
	var polish_runtime := MythicItemRuntime.new()
	var polish_owner := FakeOwner.new()
	var polish_registry := FakeRegistry.new(polish_runtime, polish_state)
	_expect(
		polish_runtime.equip_item("dowsing_goggles", polish_owner, polish_registry, {"bonus_perk_chance": 50.0}, false),
		"Dowsing Goggles should equip in the polish scaling path"
	)
	_expect_close(
		polish_runtime.get_dowsing_goggles_bonus_perk_chance_pct(),
		67.4,
		"Polish should boost Dowsing Goggles bonus-perk chance through the canonical Lv.2 roll multiplier"
	)

	PerkConversionFlags.debug_set_enabled(true)
	var converted_state := RuntimePerkState.new()
	converted_state.runtime_skill_levels = {"item_polish": 2, "dowsing_goggles": 1}
	var converted_runtime := MythicItemRuntime.new()
	converted_runtime.runtime_perk_state_ref = converted_state
	_expect_close(
		converted_runtime.get_dowsing_goggles_bonus_perk_chance_pct(),
		45.8,
		"live converted Tianan Art chance should receive the canonical Lv.2 14.5% Polish multiplier"
	)
	PerkConversionFlags.debug_set_enabled(false)

	print("dowsing_goggles_port_smoke: ok")
	quit(0)


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			return true
	return false


func _find_roll_option(item_data: Dictionary, key: String) -> Dictionary:
	for option_value in item_data.get("roll_options", []):
		if option_value is Dictionary and str(option_value.get("key", "")) == key:
			return option_value
	return {}


func _get_choice(choices: Array, index: int) -> Dictionary:
	if index < 0 or index >= choices.size():
		return {}
	var value: Variant = choices[index]
	if value is Dictionary:
		return value
	return {}


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
