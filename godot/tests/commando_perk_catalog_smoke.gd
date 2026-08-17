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
	_expect(_has_choice(choices, "pistol_enhance"), "soldier choices should include pistol_enhance")
	_expect(not _has_choice(choices, "unlock_plasma"), "soldier choices should not include Smasher unlocks")
	_expect(not _has_choice(choices, "kick_enhance"), "soldier choices should not include Viper perks")

	var debug_entries: Array = catalog.get_debug_perk_entries()
	_expect(_has_choice(debug_entries, "soldier_unlock_bazooka"), "debug picker should expose soldier unlocks")
	_expect(_has_choice(debug_entries, "pistol_enhance"), "debug picker should expose pistol_enhance")

	var pistol_enhance_value: Variant = RuntimePerkCatalog.SOLDIER_PERKS.get("pistol_enhance", {})
	var pistol_enhance: Dictionary = pistol_enhance_value if pistol_enhance_value is Dictionary else {}
	var descriptions_value: Variant = pistol_enhance.get("descriptions", {})
	var descriptions: Dictionary = descriptions_value if descriptions_value is Dictionary else {}
	_expect(int(pistol_enhance.get("max_level", 0)) == 5, "pistol_enhance should be a five-level invested perk")
	_expect(not bool(pistol_enhance.get("is_weapon_unlock", false)), "pistol_enhance should not be a weapon unlock")
	_expect(not pistol_enhance.has("weapon_name"), "pistol_enhance should not carry a weapon_name field")
	_expect(not pistol_enhance.has("unlocks_skill"), "pistol_enhance should not unlock a Commando skill orb")
	_expect(str(pistol_enhance.get("character_restriction", "")) == "soldier", "pistol_enhance should stay Soldier-only")
	_expect(str(descriptions.get(3, "")) != str(descriptions.get(1, "")), "pistol_enhance Lv.3 copy should differ from Lv.1")
	_expect(str(descriptions.get(5, "")) != str(descriptions.get(1, "")), "pistol_enhance Lv.5 copy should differ from Lv.1")
	_expect(str(descriptions.get(3, "")).contains("장전") and str(descriptions.get(5, "")).contains("장전"), "pistol_enhance descriptions should mention the load-size lane")
	_expect(str(descriptions.get(1, "")).contains("탄속") and str(descriptions.get(5, "")).contains("+50%"), "pistol_enhance descriptions should mention the bullet-speed lane")
	_expect(str(descriptions.get(1, "")).contains("넉백 +30%") and str(descriptions.get(5, "")).contains("넉백 +150%"), "pistol_enhance descriptions should mention the stronger knockback lane")
	_expect(str(pistol_enhance.get("detail", "")).contains("탄속은 +50%, 넉백은 +150%"), "pistol_enhance detail should document the Lv.6+ bullet-speed and knockback caps")
	for level in range(1, 6):
		_expect(
			_fits_choice_card_description_budget(str(descriptions.get(level, "")), 48, 2),
			"pistol_enhance Lv.%d description should fit the runtime choice-card 2-line budget" % level
		)


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


func _fits_choice_card_description_budget(text: String, max_chars: int, max_lines: int) -> bool:
	var remaining := text.strip_edges()
	var line_count := 0
	while remaining.length() > max_chars and line_count < max_lines:
		line_count += 1
		remaining = remaining.substr(max_chars).strip_edges()
	if remaining != "" and line_count < max_lines:
		line_count += 1
		remaining = ""
	return remaining == "" and line_count <= max_lines


func _has_choice(choices: Array, choice_id: String) -> bool:
	for choice in choices:
		if choice is Dictionary and str((choice as Dictionary).get("id", "")) == choice_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
