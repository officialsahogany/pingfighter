extends SceneTree

const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var data: Dictionary = {
		"selected_character_type": "soldier",
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
		"player_pos": Vector2(300.0, 700.0),
	}

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		data[str(property)] = value
		return true


class FakeRegistry:
	extends RefCounted

	var config: Object
	var weapon_controller: Object

	func _init(next_config: Object, next_weapon_controller: Object) -> void:
		config = next_config
		weapon_controller = next_weapon_controller

	func get_instance(key: String) -> Object:
		match key:
			"commando_skill_config":
				return config
			"commando_weapon_controller":
				return weapon_controller
		return null


func _init() -> void:
	_verify_catalog_choices()
	_verify_unlock_side_effects()
	_verify_full_slot_unlock_starts_swap_without_dirty_state()
	_verify_full_slot_swap_confirm_cleans_replaced_unlock()

	if _failures.is_empty():
		print("commando_perk_catalog_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_choices() -> void:
	var catalog := RuntimePerkCatalog.new()
	var choices: Array = catalog.get_choices("soldier", {}, true, 200)
	_expect(_has_choice(choices, "soldier_unlock_net_gun"), "soldier choices should include net gun unlock")
	_expect(_has_choice(choices, "soldier_pistol_perk"), "soldier choices should include Commando pistol unlock")
	_expect(not _has_choice(choices, "unlock_plasma"), "soldier choices should not include Smasher unlocks")
	_expect(not _has_choice(choices, "kick_enhance"), "soldier choices should not include Viper perks")

	var debug_entries: Array = catalog.get_debug_perk_entries()
	_expect(_has_choice(debug_entries, "soldier_unlock_bazooka"), "debug picker should expose soldier unlocks")


func _verify_unlock_side_effects() -> void:
	var catalog := RuntimePerkCatalog.new()
	var state := RuntimePerkState.new()
	var config := CommandoSkillConfig.new()
	var weapon_controller := CommandoWeaponController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(config, weapon_controller)

	var choice: Dictionary = catalog.get_perk_data("soldier_unlock_net_gun")
	choice["id"] = "soldier_unlock_net_gun"
	_expect(state.apply_choice(choice, owner, registry), "runtime perk state should apply soldier unlock")
	_expect(config.get_equipped_skills().has("net_gun"), "soldier unlock should equip the Commando skill config")
	_expect(weapon_controller.get_weapons().has("net_gun"), "soldier unlock should register the permanent weapon controller")
	_expect(str(owner.data.get("selected_character_type", "")) == "soldier", "owner should remain soldier after perk sync")


func _verify_full_slot_unlock_starts_swap_without_dirty_state() -> void:
	var setup: Dictionary = _setup_full_commando_slots()
	var catalog: Object = setup.get("catalog", null)
	var state: Object = setup.get("state", null)
	var config: Object = setup.get("config", null)
	var weapon_controller: Object = setup.get("weapon_controller", null)
	var owner: Object = setup.get("owner", null)
	var registry: Object = setup.get("registry", null)

	var choices: Array = catalog.get_choices("soldier", state.runtime_skill_levels, true, 200)
	_expect(_has_choice(choices, "soldier_unlock_ak47"), "soldier full-slot choices should keep unlock cards so swap can start")

	var ak_choice: Dictionary = _choice(catalog, "soldier_unlock_ak47")
	_expect(not state.apply_choice(ak_choice, owner, registry), "full shared slots should defer AK-47 unlock into swap flow")
	_expect(state.has_pending_unlock_swap(), "full shared slots should expose a pending unlock swap")
	_expect(not state.runtime_skill_levels.has("soldier_unlock_ak47"), "pending swap should not dirty runtime unlock level")
	_expect(not config.get_equipped_skills().has("ak47"), "pending swap should not equip the new firearm")
	_expect(not weapon_controller.get_weapons().has("ak47"), "pending swap should not register the new weapon controller entry")

	_expect(state.cancel_pending_unlock_swap(), "pending Commando swap should be cancelable")
	_expect(not state.has_pending_unlock_swap(), "cancel should clear the pending swap")
	_expect(not state.runtime_skill_levels.has("soldier_unlock_ak47"), "cancel should leave runtime unlock level untouched")
	_expect(config.get_equipped_skills() == ["supply_drop", "emergency_supply", "net_gun", "bazooka", "commando_pistol"], "cancel should leave equipped Commando slots untouched")
	_expect(weapon_controller.get_weapons() == ["pistol", "net_gun", "bazooka", "commando_pistol"], "cancel should leave weapon controller inventory untouched")


func _verify_full_slot_swap_confirm_cleans_replaced_unlock() -> void:
	var setup: Dictionary = _setup_full_commando_slots()
	var catalog: Object = setup.get("catalog", null)
	var state: Object = setup.get("state", null)
	var config: Object = setup.get("config", null)
	var weapon_controller: Object = setup.get("weapon_controller", null)
	var owner: Object = setup.get("owner", null)
	var registry: Object = setup.get("registry", null)

	var ak_choice: Dictionary = _choice(catalog, "soldier_unlock_ak47")
	_expect(not state.apply_choice(ak_choice, owner, registry), "full shared slots should wait for swap confirmation")
	_expect(state.confirm_pending_unlock_swap(owner, registry), "confirming the pending swap should commit the new unlock")
	_expect(config.get_equipped_skills() == ["supply_drop", "emergency_supply", "ak47", "bazooka", "commando_pistol"], "confirmed swap should replace the selected old Commando firearm")
	_expect(not state.runtime_skill_levels.has("soldier_unlock_net_gun"), "confirmed swap should clean the replaced unlock perk id")
	_expect(state.runtime_skill_levels.has("soldier_unlock_ak47"), "confirmed swap should commit the new unlock perk id")
	_expect(not weapon_controller.get_weapons().has("net_gun"), "confirmed swap should remove replaced permanent weapon from controller")
	_expect(weapon_controller.get_weapons().has("ak47"), "confirmed swap should add the new permanent weapon to controller")


func _setup_full_commando_slots() -> Dictionary:
	var catalog := RuntimePerkCatalog.new()
	var state := RuntimePerkState.new()
	var config := CommandoSkillConfig.new()
	var weapon_controller := CommandoWeaponController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(config, weapon_controller)
	for choice_id in ["soldier_unlock_net_gun", "soldier_unlock_bazooka", "soldier_pistol_perk"]:
		var choice: Dictionary = _choice(catalog, choice_id)
		_expect(state.apply_choice(choice, owner, registry), "%s should fill a Commando shared slot" % choice_id)
	return {
		"catalog": catalog,
		"state": state,
		"config": config,
		"weapon_controller": weapon_controller,
		"owner": owner,
		"registry": registry,
	}


func _choice(catalog: Object, choice_id: String) -> Dictionary:
	var choice: Dictionary = catalog.get_perk_data(choice_id)
	choice["id"] = choice_id
	return choice


func _has_choice(choices: Array, choice_id: String) -> bool:
	for choice in choices:
		if choice is Dictionary and str((choice as Dictionary).get("id", "")) == choice_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
