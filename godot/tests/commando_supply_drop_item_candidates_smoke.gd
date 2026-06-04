extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const CommandoFirearmPistolHitState := preload("res://scripts/characters/commando_firearm_pistol_hit_state.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoSkillState := preload("res://scripts/characters/commando_skill_state.gd")
const CommandoSupplyDropState := preload("res://scripts/characters/commando_supply_drop_state.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0


class FakeRegistry:
	extends RefCounted

	var weapon_controller: Object
	var active_item_runtime: Object

	func _init(controller: Object = null, runtime: Object = null) -> void:
		weapon_controller = controller
		active_item_runtime = runtime

	func get_instance(key: String) -> Object:
		if key == "commando_weapon_controller":
			return weapon_controller
		if key == "active_item_runtime":
			return active_item_runtime
		return null


func _init() -> void:
	_verify_catalog_builds_supply_only_items()
	_verify_supply_drop_filters_python_item_candidates()
	_verify_ammo_box_refills_owned_permanent_only()
	_verify_doping_potion_uses_base_pistol_access()
	_verify_doping_potion_enhances_commando_pistol()
	_verify_doping_potion_speeds_ak47_and_bazooka()

	if _failures.is_empty():
		print("commando_supply_drop_item_candidates_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_builds_supply_only_items() -> void:
	var catalog: Object = ActiveItemCatalog.new()
	var ammo_box: Dictionary = catalog.build_item_by_name("ammo_box")
	var doping_potion: Dictionary = catalog.build_item_by_name("doping_potion")
	_expect(str(ammo_box.get("display_name", "")) == "탄약상자", "ammo_box catalog entry should use Korean display text")
	_expect(str(ammo_box.get("icon_path", "")).ends_with("ammo_box.png"), "ammo_box should expose its copied Godot icon path")
	_expect(load(str(ammo_box.get("icon_path", ""))) != null, "ammo_box icon should load as a Godot texture")
	_expect(bool(ammo_box.get("supply_drop_only", false)), "ammo_box should be supply-drop only, not normal field-spawn")
	_expect(str(doping_potion.get("display_name", "")) == "도핑주사기", "doping_potion catalog entry should use Korean display text")
	_expect(load(str(doping_potion.get("icon_path", ""))) != null, "doping_potion icon should load as a Godot texture")
	_expect(int(doping_potion.get("duration", 0)) == 480, "doping_potion should preserve the Python 8-second duration")
	_expect(not ActiveItemCatalog.FIELD_SPAWN_ORDER.has("ammo_box"), "ammo_box should not enter the ordinary field spawn order")
	_expect(not ActiveItemCatalog.FIELD_SPAWN_ORDER.has("doping_potion"), "doping_potion should not enter the ordinary field spawn order")


func _verify_supply_drop_filters_python_item_candidates() -> void:
	var supply_state: Object = CommandoSupplyDropState.new()
	var controller: Object = CommandoWeaponController.new()
	var deps := {"commando_weapon_controller": controller}
	var ids_without_permanent: Array = _candidate_ids(supply_state._get_field_item_drop_candidates(deps))
	_expect(ids_without_permanent.has("ammo_box"), "ammo_box should be eligible even before permanent firearms are owned")
	_expect(ids_without_permanent.has("doping_potion"), "doping_potion should be eligible because the base pistol is always available")

	controller.unlock_permanent_weapon("ak47", true)
	var ids_with_ak: Array = _candidate_ids(supply_state._get_field_item_drop_candidates(deps))
	_expect(ids_with_ak.has("ammo_box"), "ammo_box should become eligible once any permanent firearm exists")
	_expect(ids_with_ak.has("doping_potion"), "doping_potion should stay eligible with only the base pistol")

	controller.unlock_permanent_weapon("commando_pistol", true)
	var ids_with_pistol: Array = _candidate_ids(supply_state._get_field_item_drop_candidates(deps))
	_expect(ids_with_pistol.has("ammo_box"), "ammo_box should remain eligible with the pistol unlocked")
	_expect(ids_with_pistol.has("doping_potion"), "doping_potion should become eligible when commando_pistol is permanent")


func _verify_ammo_box_refills_owned_permanent_only() -> void:
	var catalog: Object = ActiveItemCatalog.new()
	var active_runtime: Object = ActiveItemRuntime.new()
	var controller: Object = CommandoWeaponController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(controller, active_runtime)

	controller.unlock_permanent_weapon("ak47", true)
	controller.set_current_weapon("ak47")
	controller.consume_current_weapon_ammo(12)
	controller.consume_current_weapon_duration(240.0)
	controller.unlock_permanent_weapon("commando_pistol", true)
	controller.set_current_weapon("commando_pistol")
	controller.consume_current_weapon_ammo(2)
	controller.add_rental_weapon("bazooka", 1, 1)

	var used: bool = bool(active_runtime._apply_item_effect(catalog.build_item_by_name("ammo_box"), owner, registry))
	_expect(used, "ammo_box should use successfully when at least one permanent firearm is below max")
	var ak47: Dictionary = controller.get_weapon_data("ak47")
	var pistol: Dictionary = controller.get_weapon_data("commando_pistol")
	var rental: Dictionary = controller.get_weapon_data("bazooka")
	_expect(int(ak47.get("ammo_current", 0)) == 90, "ammo_box should refill AK-47 ammo")
	_expect(is_equal_approx(float(ak47.get("duration_frames", 0.0)), 1800.0), "ammo_box should refill AK-47 duration")
	_expect(int(pistol.get("ammo_current", 0)) == 12, "ammo_box should refill commando_pistol ammo to 12")
	_expect(int(pistol.get("magazines_current", -1)) == 0, "ammo_box should not create Beretta spare magazines")
	_expect(not bool(pistol.get("reloading", false)), "ammo_box should keep Beretta out of magazine reload state")
	_expect(str(rental.get("kind", "")) == "rental" and int(rental.get("ammo_current", 0)) == 1, "ammo_box should not refill rental firearms")


func _verify_doping_potion_uses_base_pistol_access() -> void:
	var catalog: Object = ActiveItemCatalog.new()
	var active_runtime: Object = ActiveItemRuntime.new()
	var controller: Object = CommandoWeaponController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(controller, active_runtime)
	var activated: bool = bool(active_runtime._apply_item_effect(catalog.build_item_by_name("doping_potion"), owner, registry))
	_expect(activated, "doping_potion should activate with the always-available base pistol")
	var firearm_runtime: Object = CommandoFirearmRuntime.new()
	var fire_result: Dictionary = firearm_runtime.update_input(
		{"action_pressed": true, "action_just_pressed": true},
		500.0,
		_fire_config(),
		{
			"commando_weapon_controller": controller,
			"active_item_runtime": active_runtime,
		}
	)
	_expect(str(fire_result.get("weapon_id", "")) == "pistol", "doped base pistol fire should keep the base pistol id")
	_expect(bool(fire_result.get("shot_queued", false)), "doped base pistol input should queue the delayed shot")
	_expect(is_equal_approx(float(fire_result.get("cooldown_frames", 0.0)), 30.0), "base pistol doping should use the Python 30-frame cooldown")
	_expect(is_equal_approx(float(fire_result.get("control_lock_frames", 0.0)), 9.0), "base pistol doping should use the Python 9-frame control lock")
	_expect(bool(fire_result.get("doping_potion_active", false)), "base pistol fire result should expose the active doping flag")


func _verify_doping_potion_enhances_commando_pistol() -> void:
	var catalog: Object = ActiveItemCatalog.new()
	var active_runtime: Object = ActiveItemRuntime.new()
	var controller: Object = CommandoWeaponController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(controller, active_runtime)
	controller.unlock_permanent_weapon("commando_pistol", true)
	controller.set_current_weapon("commando_pistol")

	var activated: bool = bool(active_runtime._apply_item_effect(catalog.build_item_by_name("doping_potion"), owner, registry))
	_expect(activated, "doping_potion should activate when commando_pistol is permanent")
	var context: Dictionary = active_runtime.get_doping_potion_context()
	_expect(bool(context.get("active", false)), "doping context should become active")
	_expect(is_equal_approx(float(context.get("timer_frames", 0.0)), 480.0), "doping timer should start at Python 480 frames")
	_expect(is_equal_approx(float(context.get("head_leg_multiplier", 0.0)), 2.0), "doping should double head/leg chances")
	var draw_context: Dictionary = active_runtime.effect_controller.get_field_effect_draw_context()
	var timer_context: Dictionary = _get_context_dictionary(draw_context, "doping_potion_timer_context")
	_expect(bool(timer_context.get("active", false)), "doping timer context should be available for the right-bottom HUD gauge")
	_expect(is_equal_approx(float(timer_context.get("initial_timer_frames", 0.0)), 480.0), "doping HUD timer should preserve the full initial duration")

	var firearm_runtime: Object = CommandoFirearmRuntime.new()
	var fire_result: Dictionary = firearm_runtime.update_input(
		{"action_pressed": true, "action_just_pressed": true},
		500.0,
		_fire_config(),
		{
			"commando_weapon_controller": controller,
			"active_item_runtime": active_runtime,
		}
	)
	_expect(bool(fire_result.get("fired", false)), "doped commando_pistol input should fire immediately")
	_expect(not bool(fire_result.get("shot_queued", false)), "doped commando_pistol input should not queue a ready shot")
	_expect(is_equal_approx(float(fire_result.get("cooldown_frames", 0.0)), 15.0), "doping should cut Beretta cooldown below its normal 30-frame cadence")
	_expect(is_equal_approx(float(fire_result.get("control_lock_frames", -1.0)), 0.0), "doping should not restore Beretta ready-motion lock")
	_expect(bool(fire_result.get("doping_potion_active", false)), "fire result should expose the active doping flag")
	var pistol_draw_state: Dictionary = firearm_runtime.get_actor_draw_context().get("commando_firearm_pistol_state", {})
	_expect(is_equal_approx(float(pistol_draw_state.get("cooldown_max_frames", 0.0)), 15.0), "doped Beretta HUD state should use the 15-frame cooldown max")
	_expect(is_equal_approx(float(pistol_draw_state.get("control_lock_max_frames", -1.0)), 0.0), "doped Beretta HUD state should keep the instant-fire lock max at zero")

	var hit_result: Dictionary = {}
	var hit_feedbacks: Array = []
	CommandoFirearmPistolHitState.apply_runtime_hit_effects(
		"commando_pistol",
		{
			"active_item_doping_potion_active": true,
			"active_item_doping_potion_head_leg_multiplier": 2.0,
		},
		{"commando_pistol_shot_roll": 0.21},
		hit_result,
		0,
		hit_feedbacks,
		CommandoFirearmRuntime.BASE_WEAPON_ID,
		2.0,
		CommandoFirearmRuntime.PISTOL_HEAD_SHOT_CHANCE,
		CommandoFirearmRuntime.PISTOL_LEG_SHOT_CHANCE,
		CommandoFirearmRuntime.PISTOL_HIT_TUNING,
		760.0,
		750.0,
		CommandoFirearmRuntime.PISTOL_HIT_TEXT_TIMER_FRAMES,
		"HEAD",
		"LEG",
		4
	)
	_expect(str(hit_result.get("pistol_hit_kind", "")) == "legshot", "doping should turn a 0.21 roll into a legshot")
	_expect(is_equal_approx(float(hit_result.get("pistol_head_chance", 0.0)), 0.20), "doping should double headshot chance")
	_expect(is_equal_approx(float(hit_result.get("pistol_leg_chance", 0.0)), 0.24), "doping should double legshot chance")

	active_runtime.update(owner, registry, 8.1)
	_expect(not active_runtime.is_doping_potion_active(), "doping should expire after its timer elapses")


func _verify_doping_potion_speeds_ak47_and_bazooka() -> void:
	var catalog: Object = ActiveItemCatalog.new()
	var active_runtime: Object = ActiveItemRuntime.new()
	var controller: Object = CommandoWeaponController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(controller, active_runtime)
	var skill_config := CommandoSkillConfig.new()
	var skill_state := CommandoSkillState.new()

	controller.unlock_permanent_weapon("ak47", true)
	controller.unlock_permanent_weapon("bazooka", true)
	var activated: bool = bool(active_runtime._apply_item_effect(catalog.build_item_by_name("doping_potion"), owner, registry))
	_expect(activated, "doping_potion should activate before rapid-fire firearm checks")
	var context: Dictionary = active_runtime.get_doping_potion_context()
	_expect(is_equal_approx(float(context.get("fire_rate_multiplier", 0.0)), 0.5), "doping context should expose a half-cooldown fire-rate multiplier")
	_expect(is_equal_approx(float(context.get("ak47_fire_interval_frames", 0.0)), 3.0), "doping context should expose the AK-47 rapid-fire interval")
	_expect(is_equal_approx(float(context.get("bazooka_cooldown_frames", 0.0)), 60.0), "doping context should expose the bazooka rapid-fire cooldown")

	controller.set_current_weapon("ak47")
	var ak_runtime: Object = CommandoFirearmRuntime.new()
	var deps := {
		"commando_weapon_controller": controller,
		"active_item_runtime": active_runtime,
		"skill_config": skill_config,
		"skill_state": skill_state,
	}
	var ak_result: Dictionary = ak_runtime.update_input(
		{"action_pressed": true, "action_just_pressed": true},
		500.0,
		_fire_config(),
		deps
	)
	_expect(bool(ak_result.get("fired", false)), "doped AK-47 input should fire")
	_expect(is_equal_approx(float(ak_result.get("fire_interval_frames", 0.0)), 3.0), "doping should halve AK-47 fire interval from 6 to 3 frames")
	var ak_draw_state: Dictionary = ak_runtime.get_actor_draw_context().get("commando_firearm_ak47_state", {})
	_expect(is_equal_approx(float(ak_draw_state.get("fire_interval_max_frames", 0.0)), 3.0), "AK-47 draw state should expose the doped interval max")
	var ak_cooldown: Dictionary = skill_state.get_cooldowns().get("ak47", {})
	_expect(int(ak_cooldown.get("cooldown_msec", 0)) == 50, "AK-47 orb cooldown should match the doped 0.05-second cadence")

	controller.set_current_weapon("bazooka")
	var bazooka_runtime: Object = CommandoFirearmRuntime.new()
	var bazooka_result: Dictionary = bazooka_runtime.update_input(
		{"action_pressed": true, "action_just_pressed": true},
		500.0,
		_fire_config(),
		deps
	)
	_expect(bool(bazooka_result.get("fired", false)), "doped bazooka input should fire")
	_expect(is_equal_approx(float(bazooka_result.get("cooldown_frames", 0.0)), 60.0), "doping should halve bazooka cooldown from 120 to 60 frames")
	_expect(is_equal_approx(float(bazooka_result.get("control_lock_frames", 0.0)), 15.0), "doping should halve bazooka control lock from 30 to 15 frames")
	var bazooka_draw_state: Dictionary = bazooka_runtime.get_actor_draw_context().get("commando_firearm_bazooka_state", {})
	_expect(is_equal_approx(float(bazooka_draw_state.get("cooldown_max_frames", 0.0)), 60.0), "bazooka draw state should expose the doped cooldown max")
	_expect(is_equal_approx(float(bazooka_draw_state.get("control_lock_max_frames", 0.0)), 15.0), "bazooka draw state should expose the doped lock max")
	var bazooka_cooldown: Dictionary = skill_state.get_cooldowns().get("bazooka", {})
	_expect(int(bazooka_cooldown.get("cooldown_msec", 0)) == 1000, "bazooka orb cooldown should match the doped 1-second cadence")


func _candidate_ids(candidates: Array) -> Array:
	var ids: Array = []
	for candidate_value in candidates:
		var candidate: Dictionary = candidate_value if candidate_value is Dictionary else {}
		ids.append(str(candidate.get("item_id", "")))
	return ids


func _get_context_dictionary(context: Dictionary, key: String) -> Dictionary:
	var value: Variant = context.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _fire_config() -> Dictionary:
	return {
		"player_pos": Vector2(350.0, 700.0),
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"boss_pos": Vector2(380.0, 110.0),
		"boss_size": Vector2(120.0, 80.0),
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
